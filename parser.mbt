///|
priv struct Parser {
  tokens : Array[Token]
  mut pos : Int
}

///|
fn Parser::peek(self : Parser) -> Token {
  self.tokens[self.pos]
}

///|
fn Parser::advance(self : Parser) -> Token {
  let token = self.tokens[self.pos]
  self.pos += 1
  token
}

///|
fn Parser::accept(self : Parser, expected : TokenKind) -> Bool {
  if self.peek().kind == expected {
    self.pos += 1
    true
  } else {
    false
  }
}

///|
fn Parser::expect(
  self : Parser,
  expected : TokenKind,
  label : String,
) -> Unit raise JmesPathError {
  if !self.accept(expected) {
    fail("syntax", self.peek().offset, "expected " + label)
  }
}

///|
fn precedence(kind : TokenKind) -> Int {
  match kind {
    PipeToken => 1
    OrToken => 2
    AndToken => 3
    EqToken | NeToken | LtToken | LeToken | GtToken | GeToken => 4
    _ => 0
  }
}

///|
fn attach_projection(expr : Expr, rhs : Expr) -> Expr {
  match expr {
    Projection(source, tail) => Projection(source, Subexpression(tail, rhs))
    _ => Subexpression(expr, rhs)
  }
}

///|
fn Parser::parse_function(
  self : Parser,
  name : String,
) -> Expr raise JmesPathError {
  self.expect(LParen, "(")
  let args : Array[Expr] = []
  if self.accept(RParen) {
    return Function(name, args)
  }
  while true {
    args.push(self.parse_expression(1))
    if self.accept(RParen) {
      break
    }
    self.expect(Comma, ",")
  }
  Function(name, args)
}

///|
fn Parser::parse_multi_list(self : Parser) -> Expr raise JmesPathError {
  let items : Array[Expr] = []
  if self.accept(RBracket) {
    fail("syntax", self.peek().offset, "empty multi-select list is not allowed")
  }
  while true {
    items.push(self.parse_expression(1))
    if self.accept(RBracket) {
      break
    }
    self.expect(Comma, ",")
  }
  MultiList(items)
}

///|
fn Parser::parse_multi_hash(self : Parser) -> Expr raise JmesPathError {
  let entries : Array[(String, Expr)] = []
  if self.accept(RBrace) {
    fail("syntax", self.peek().offset, "empty multi-select hash is not allowed")
  }
  while true {
    let key = match self.advance() {
      { kind: Identifier(value), .. } | { kind: QuotedIdentifier(value), .. } =>
        value
      token => fail("syntax", token.offset, "expected object key")
    }
    self.expect(Colon, ":")
    entries.push((key, self.parse_expression(1)))
    if self.accept(RBrace) {
      break
    }
    self.expect(Comma, ",")
  }
  MultiHash(entries)
}

///|
fn Parser::parse_slice_or_index(
  self : Parser,
  base : Expr,
) -> Expr raise JmesPathError {
  let mut start : Int? = None
  if self.peek().kind is NumberToken(value) {
    start = Some(value)
    self.advance() |> ignore
    if self.accept(RBracket) {
      return Index(base, value)
    }
  }
  self.expect(Colon, ":")
  let mut stop : Int? = None
  let mut step : Int? = None
  if self.peek().kind is NumberToken(value) {
    stop = Some(value)
    self.advance() |> ignore
  }
  if self.accept(Colon) {
    if self.peek().kind is NumberToken(value) {
      step = Some(value)
      self.advance() |> ignore
    }
  }
  self.expect(RBracket, "]")
  Projection(Slice(base, start, stop, step), Current)
}

///|
fn Parser::parse_bracket_postfix(
  self : Parser,
  base : Expr,
) -> Expr raise JmesPathError {
  if self.accept(RBracket) {
    return Projection(Flatten(base), Current)
  }
  if self.accept(Star) {
    self.expect(RBracket, "]")
    return Projection(ListWildcard(base), Current)
  }
  if self.accept(Question) {
    let condition = self.parse_expression(1)
    self.expect(RBracket, "]")
    return Projection(Filter(base, condition), Current)
  }
  self.parse_slice_or_index(base)
}

///|
fn Parser::parse_prefix(self : Parser) -> Expr raise JmesPathError {
  let token = self.advance()
  match token.kind {
    Identifier(name) =>
      if self.peek().kind is LParen {
        self.parse_function(name)
      } else {
        Field(name)
      }
    QuotedIdentifier(name) => Field(name)
    RawString(value) => Literal(Json::string(value))
    LiteralToken(value) => Literal(value)
    CurrentToken => Current
    Star => Projection(ObjectWildcard(Current), Current)
    NotToken => Not(self.parse_expression(5))
    Ampersand => ExpressionRef(self.parse_expression(5))
    LParen => {
      let expr = self.parse_expression(1)
      self.expect(RParen, ")")
      expr
    }
    LBrace => self.parse_multi_hash()
    LBracket =>
      if self.accept(Star) {
        self.expect(RBracket, "]")
        Projection(ListWildcard(Current), Current)
      } else if self.accept(Question) {
        let condition = self.parse_expression(1)
        self.expect(RBracket, "]")
        Projection(Filter(Current, condition), Current)
      } else if self.peek().kind is NumberToken(_) || self.peek().kind is Colon {
        self.parse_slice_or_index(Current)
      } else {
        self.parse_multi_list()
      }
    _ => fail("syntax", token.offset, "expected expression")
  }
}

///|
fn Parser::parse_dot_rhs(self : Parser) -> Expr raise JmesPathError {
  let token = self.advance()
  match token.kind {
    Identifier(name) =>
      if self.peek().kind is LParen {
        self.parse_function(name)
      } else {
        Field(name)
      }
    QuotedIdentifier(name) => Field(name)
    Star => Projection(ObjectWildcard(Current), Current)
    LBracket => self.parse_multi_list()
    LBrace => self.parse_multi_hash()
    _ =>
      fail(
        "syntax",
        token.offset,
        "expected field, wildcard, function, or multi-select",
      )
  }
}

///|
fn Parser::parse_expression(
  self : Parser,
  min_precedence : Int,
) -> Expr raise JmesPathError {
  let mut left = self.parse_prefix()
  while true {
    if self.accept(Dot) {
      left = attach_projection(left, self.parse_dot_rhs())
      continue
    }
    if self.accept(LBracket) {
      left = match left {
        Projection(source, tail) =>
          Projection(source, self.parse_bracket_postfix(tail))
        _ => self.parse_bracket_postfix(left)
      }
      continue
    }
    let p = precedence(self.peek().kind)
    if p < min_precedence || p == 0 {
      break
    }
    let operator = self.advance()
    let right = self.parse_expression(p + 1)
    left = match operator.kind {
      PipeToken => Pipe(left, right)
      OrToken => Or(left, right)
      AndToken => And(left, right)
      EqToken => Compare(Eq, left, right)
      NeToken => Compare(Ne, left, right)
      LtToken => Compare(Lt, left, right)
      LeToken => Compare(Le, left, right)
      GtToken => Compare(Gt, left, right)
      GeToken => Compare(Ge, left, right)
      _ => fail("syntax", operator.offset, "invalid operator")
    }
  }
  left
}

///|
fn expr_depth(expr : Expr) -> Int {
  match expr {
    Current | Field(_) | Literal(_) => 1
    Not(a)
    | ExpressionRef(a)
    | Index(a, _)
    | Slice(a, _, _, _)
    | ListWildcard(a)
    | ObjectWildcard(a)
    | Flatten(a) => 1 + expr_depth(a)
    Subexpression(a, b)
    | Projection(a, b)
    | Filter(a, b)
    | Pipe(a, b)
    | Or(a, b)
    | And(a, b)
    | Compare(_, a, b) => 1 + Int::max(expr_depth(a), expr_depth(b))
    MultiList(items) | Function(_, items) => {
      let mut depth = 1
      for item in items {
        depth = Int::max(depth, 1 + expr_depth(item))
      }
      depth
    }
    MultiHash(entries) => {
      let mut depth = 1
      for entry in entries {
        let (_, item) = entry
        depth = Int::max(depth, 1 + expr_depth(item))
      }
      depth
    }
  }
}

///|
fn parse(source : String, limits : Limits) -> Expr raise JmesPathError {
  let parser = { tokens: lex(source, limits), pos: 0, }
  let expr = parser.parse_expression(1)
  if !(parser.peek().kind is Eof) {
    fail("syntax", parser.peek().offset, "unexpected token after expression")
  }
  if expr_depth(expr) > limits.max_ast_depth {
    fail("limit_exceeded", 0, "expression exceeds max_ast_depth")
  }
  expr
}
