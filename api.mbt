///|
pub fn compile(
  source : String,
  limits? : Limits = default_limits(),
) -> Compiled raise JmesPathError {
  { source, expr: parse(source, limits), limits, }
}

///|
pub fn Compiled::search(
  self : Compiled,
  data : Json,
) -> Json raise JmesPathError {
  let state = { limits: self.limits, steps: 0, results: 0, }
  evaluate(self.expr, data, state)
}

///|
pub fn search(
  expression : String,
  data : Json,
  limits? : Limits = default_limits(),
) -> Json raise JmesPathError {
  compile(expression, limits~).search(data)
}

///|
pub fn search_json(
  expression : String,
  json_text : String,
  limits? : Limits = default_limits(),
) -> Json raise JmesPathError {
  let data = @json.parse(json_text) catch {
    _ => fail("invalid_json", 0, "input is not valid JSON")
  }
  search(expression, data, limits~)
}
