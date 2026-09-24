///|
enum TokenKind {
  Identifier(String)
  QuotedIdentifier(String)
  RawString(String)
  LiteralToken(Json)
  NumberToken(Int)
  Dot
  Star
  CurrentToken
  LParen
  RParen
  LBracket
  RBracket
  LBrace
  RBrace
  Comma
  Colon
  PipeToken
  OrToken
  AndToken
  NotToken
  EqToken
  NeToken
  LtToken
  LeToken
  GtToken
  GeToken
  Question
  Ampersand
  Eof
} derive(Eq, Debug)

///|
struct Token {
  kind : TokenKind
  offset : Int
} derive(Eq, Debug)

///|
fn is_space(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\r' || c == '\n'
}

///|
fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn is_identifier_start(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
}

///|
fn is_identifier_continue(c : Char) -> Bool {
  is_identifier_start(c) || is_digit(c)
}

///|
fn parse_int_text(text : String, offset : Int) -> Int raise JmesPathError {
  let chars = text.to_array()
  let mut value = 0
  let mut i = 0
  let mut negative = false
  if chars.length() > 0 && chars[0] == '-' {
    negative = true
    i = 1
  }
  while i < chars.length() {
    let digit = chars[i].to_int() - '0'.to_int()
    if value > 214748364 {
      fail("syntax", offset, "integer index is out of range")
    }
    value = value * 10 + digit
    i += 1
  }
  if negative {
    -value
  } else {
    value
  }
}

///|
fn decode_json_string(raw : String, offset : Int) -> String raise JmesPathError {
  let wrapped = "\"" + raw + "\""
  let parsed = @json.parse(wrapped) catch {
    _ => fail("syntax", offset, "invalid quoted identifier escape")
  }
  guard parsed is String(value) else {
    fail("syntax", offset, "invalid quoted identifier")
  }
  value
}

///|
fn lex(source : String, limits : Limits) -> Array[Token] raise JmesPathError {
  let chars = source.to_array()
  if chars.length() > limits.max_expression_chars {
    fail("limit_exceeded", 0, "expression exceeds max_expression_chars")
  }
  let tokens : Array[Token] = []
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if is_space(c) {
      i += 1
      continue
    }
    let start = i
    if is_identifier_start(c) {
      i += 1
      while i < chars.length() && is_identifier_continue(chars[i]) {
        i += 1
      }
      tokens.push({
        kind: Identifier(String::from_array(chars[start:i])),
        offset: start,
      })
      continue
    }
    if is_digit(c) ||
      (c == '-' && i + 1 < chars.length() && is_digit(chars[i + 1])) {
      i += 1
      while i < chars.length() && is_digit(chars[i]) {
        i += 1
      }
      let text = String::from_array(chars[start:i])
      tokens.push({
        kind: NumberToken(parse_int_text(text, start)),
        offset: start,
      })
      continue
    }
    match c {
      '"' => {
        i += 1
        let content_start = i
        let mut escaped = false
        while i < chars.length() {
          if !escaped && chars[i] == '"' {
            break
          }
          if !escaped && chars[i] == '\\' {
            escaped = true
          } else {
            escaped = false
          }
          i += 1
        }
        if i >= chars.length() {
          fail("syntax", start, "unterminated quoted identifier")
        }
        let raw = String::from_array(chars[content_start:i])
        tokens.push({
          kind: QuotedIdentifier(decode_json_string(raw, start)),
          offset: start,
        })
        i += 1
      }
      '\'' => {
        i += 1
        let b = StringBuilder()
        let mut closed = false
        while i < chars.length() {
          if chars[i] == '\'' {
            closed = true
            i += 1
            break
          }
          if chars[i] == '\\' && i + 1 < chars.length() && chars[i + 1] == '\'' {
            b.write_char('\'')
            i += 2
          } else if chars[i] == '\\' &&
            i + 1 < chars.length() &&
            chars[i + 1] == '\\' {
            b.write_char('\\')
            i += 2
          } else {
            b.write_char(chars[i])
            i += 1
          }
        }
        if !closed {
          fail("syntax", start, "unterminated raw string")
        }
        tokens.push({ kind: RawString(b.to_string()), offset: start, })
      }
      '`' => {
        i += 1
        let b = StringBuilder()
        let mut closed = false
        while i < chars.length() {
          if chars[i] == '`' {
            closed = true
            i += 1
            break
          }
          if chars[i] == '\\' && i + 1 < chars.length() && chars[i + 1] == '`' {
            b.write_char('`')
            i += 2
          } else {
            b.write_char(chars[i])
            i += 1
          }
        }
        if !closed {
          fail("syntax", start, "unterminated JSON literal")
        }
        let value = @json.parse(b.to_string()) catch {
          _ => fail("syntax", start, "invalid JSON literal")
        }
        tokens.push({ kind: LiteralToken(value), offset: start, })
      }
      '.' => {
        tokens.push({ kind: Dot, offset: start, })
        i += 1
      }
      '*' => {
        tokens.push({ kind: Star, offset: start, })
        i += 1
      }
      '@' => {
        tokens.push({ kind: CurrentToken, offset: start, })
        i += 1
      }
      '(' => {
        tokens.push({ kind: LParen, offset: start, })
        i += 1
      }
      ')' => {
        tokens.push({ kind: RParen, offset: start, })
        i += 1
      }
      '[' => {
        tokens.push({ kind: LBracket, offset: start, })
        i += 1
      }
      ']' => {
        tokens.push({ kind: RBracket, offset: start, })
        i += 1
      }
      '{' => {
        tokens.push({ kind: LBrace, offset: start, })
        i += 1
      }
      '}' => {
        tokens.push({ kind: RBrace, offset: start, })
        i += 1
      }
      ',' => {
        tokens.push({ kind: Comma, offset: start, })
        i += 1
      }
      ':' => {
        tokens.push({ kind: Colon, offset: start, })
        i += 1
      }
      '?' => {
        tokens.push({ kind: Question, offset: start, })
        i += 1
      }
      '&' =>
        if i + 1 < chars.length() && chars[i + 1] == '&' {
          tokens.push({ kind: AndToken, offset: start, })
          i += 2
        } else {
          tokens.push({ kind: Ampersand, offset: start, })
          i += 1
        }
      '|' =>
        if i + 1 < chars.length() && chars[i + 1] == '|' {
          tokens.push({ kind: OrToken, offset: start, })
          i += 2
        } else {
          tokens.push({ kind: PipeToken, offset: start, })
          i += 1
        }
      '!' =>
        if i + 1 < chars.length() && chars[i + 1] == '=' {
          tokens.push({ kind: NeToken, offset: start, })
          i += 2
        } else {
          tokens.push({ kind: NotToken, offset: start, })
          i += 1
        }
      '=' =>
        if i + 1 < chars.length() && chars[i + 1] == '=' {
          tokens.push({ kind: EqToken, offset: start, })
          i += 2
        } else {
          fail("syntax", start, "expected ==")
        }
      '<' =>
        if i + 1 < chars.length() && chars[i + 1] == '=' {
          tokens.push({ kind: LeToken, offset: start, })
          i += 2
        } else {
          tokens.push({ kind: LtToken, offset: start, })
          i += 1
        }
      '>' =>
        if i + 1 < chars.length() && chars[i + 1] == '=' {
          tokens.push({ kind: GeToken, offset: start, })
          i += 2
        } else {
          tokens.push({ kind: GtToken, offset: start, })
          i += 1
        }
      _ => fail("syntax", start, "unexpected character")
    }
  }
  tokens.push({ kind: Eof, offset: chars.length(), })
  tokens
}
