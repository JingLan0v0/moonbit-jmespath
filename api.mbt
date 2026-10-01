///|
pub fn compile(
  source : String,
  limits? : Limits = default_limits(),
) -> Compiled raise JmesPathError {
  validate_limits(limits)
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

///|
fn batch_error(diagnostic : Diagnostic) -> Json {
  Json::object(
    Map([
      ("ok", Json::boolean(false)),
      (
        "error",
        Json::object(
          Map([
            ("code", Json::string(diagnostic.code)),
            ("offset", Json::number(diagnostic.offset.to_double())),
            ("message", Json::string(diagnostic.message)),
          ]),
        ),
      ),
    ]),
  )
}

///|
/// Runs independent queries from a JSON array of `{expression, data}` objects.
/// Errors are returned per item, so one invalid query or malformed request does
/// not abort the batch. The top-level input must still be an array.
pub fn search_batch(
  requests : Json,
  limits? : Limits = default_limits(),
) -> Json raise JmesPathError {
  validate_limits(limits)
  guard requests is Array(items) else {
    fail("invalid_batch", 0, "batch input must be a JSON array")
  }
  if items.length() > 10000 {
    fail("limit_exceeded", 0, "batch exceeds 10000 requests")
  }
  let responses : Array[Json] = []
  for item in items {
    let response = match item {
      Object(request) =>
        match (request.get("expression"), request.get("data")) {
          (Some(String(expression)), Some(data)) =>
            Json::object(
              Map([
                ("ok", Json::boolean(true)),
                ("result", search(expression, data, limits~)),
              ]),
            ) catch {
              JmesPathError(diagnostic) => batch_error(diagnostic)
            }
          _ =>
            batch_error({
              code: "invalid_batch",
              offset: 0,
              message: "each request needs string expression and data",
            })
        }
      _ =>
        batch_error({
          code: "invalid_batch",
          offset: 0,
          message: "each request needs string expression and data",
        })
    }
    responses.push(response)
  }
  Json::array(responses)
}
