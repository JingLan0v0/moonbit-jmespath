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

///|
/// Runs independent queries from a JSON array of `{expression, data}` objects.
/// Errors are returned per item, so one invalid query does not abort the batch.
pub fn search_batch(
  requests : Json,
  limits? : Limits = default_limits(),
) -> Json raise JmesPathError {
  guard requests is Array(items) else {
    fail("invalid_batch", 0, "batch input must be a JSON array")
  }
  if items.length() > 10000 {
    fail("limit_exceeded", 0, "batch exceeds 10000 requests")
  }
  let responses : Array[Json] = []
  for item in items {
    guard item is Object(request) &&
      request.get("expression") is Some(String(expression)) &&
      request.get("data") is Some(data) else {
      fail("invalid_batch", 0, "each request needs string expression and data")
    }
    let response = Json::object(
      Map([
        ("ok", Json::boolean(true)),
        ("result", search(expression, data, limits~)),
      ]),
    ) catch {
      JmesPathError(diagnostic) =>
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
    responses.push(response)
  }
  Json::array(responses)
}
