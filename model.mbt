///|
pub(all) struct Diagnostic {
  code : String
  offset : Int
  message : String
} derive(Eq, Debug)

///|
pub(all) suberror JmesPathError {
  JmesPathError(Diagnostic)
}

///|
fn[T] fail(
  code : String,
  offset : Int,
  message : String,
) -> T raise JmesPathError {
  raise JmesPathError({ code, offset, message, })
}

///|
pub(all) struct Limits {
  max_expression_chars : Int
  max_ast_depth : Int
  max_steps : Int
  max_results : Int
} derive(Eq, Debug)

///|
pub fn default_limits() -> Limits {
  {
    max_expression_chars: 16384,
    max_ast_depth: 256,
    max_steps: 1000000,
    max_results: 100000,
  }
}

///|
enum CompareOp {
  Eq
  Ne
  Lt
  Le
  Gt
  Ge
} derive(Eq, Debug)

///|
enum Expr {
  Current
  Field(String)
  Literal(Json)
  Subexpression(Expr, Expr)
  Index(Expr, Int)
  Slice(Expr, Int?, Int?, Int?)
  ListWildcard(Expr)
  ObjectWildcard(Expr)
  Flatten(Expr)
  Projection(Expr, Expr)
  Filter(Expr, Expr)
  Pipe(Expr, Expr)
  Or(Expr, Expr)
  And(Expr, Expr)
  Not(Expr)
  Compare(CompareOp, Expr, Expr)
  MultiList(Array[Expr])
  MultiHash(Array[(String, Expr)])
  Function(String, Array[Expr])
  ExpressionRef(Expr)
} derive(Eq, Debug)

///|
pub(all) struct Compiled {
  source : String
  expr : Expr
  limits : Limits
}

///|
pub fn Compiled::source(self : Compiled) -> String {
  self.source
}

///|
pub fn version() -> String {
  "0.1.0"
}
