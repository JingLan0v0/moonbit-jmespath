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
pub struct Compiled {
  source : String
  expr : Expr
  limits : Limits
}

///|
pub fn Compiled::source(self : Compiled) -> String {
  self.source
}

///|
fn validate_limits(limits : Limits) -> Unit raise JmesPathError {
  if limits.max_expression_chars < 1 ||
    limits.max_ast_depth < 1 ||
    limits.max_ast_depth > 256 ||
    limits.max_steps < 1 ||
    limits.max_results < 0 {
    fail(
      "invalid_value", 0, "expression, depth, and step limits must be positive; AST depth must be at most 256; result limit must be nonnegative",
    )
  }
}

///|
pub fn version() -> String {
  "0.1.7"
}

///|
pub extend Diagnostic with Eq::{equal, not_equal}

///|
pub extend Diagnostic with @debug.Debug::{to_repr}

///|
pub extend Limits with Eq::{equal, not_equal}

///|
pub extend Limits with @debug.Debug::{to_repr}

///|
pub extend CompareOp with Eq::{equal, not_equal}

///|
pub extend CompareOp with @debug.Debug::{to_repr}

///|
pub extend Expr with Eq::{equal, not_equal}

///|
pub extend Expr with @debug.Debug::{to_repr}
