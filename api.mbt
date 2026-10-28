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
  check_json_size(data, false)
  let state = { limits: self.limits, steps: 0, results: 0, depth: 0, }
  let result = evaluate(self.expr, data, state)
  check_json_size(result, false)
  result
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
  if json_text.length() > 16777216 {
    fail("limit_exceeded", 0, "JSON text exceeds 16 Mi UTF-16 units")
  }
  let data = @json.parse(json_text) catch {
    @json.DepthLimitExceeded =>
      fail("limit_exceeded", 0, "JSON nesting exceeds parser limit")
    _ => fail("invalid_json", 0, "input is not valid JSON")
  }
  search(expression, data, limits~)
}

///|
fn batch_error(diagnostic : Diagnostic) -> Json {
  let message = if diagnostic.message.length() > 128 {
    diagnostic.message[:128].to_owned() + "..."
  } else {
    diagnostic.message
  }
  Json::object(
    Map([
      ("ok", Json::boolean(false)),
      (
        "error",
        Json::object(
          Map([
            ("code", Json::string(diagnostic.code)),
            ("offset", Json::number(diagnostic.offset.to_double())),
            ("message", Json::string(message)),
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
  let mut response_nodes = 0
  let mut response_units = 0
  for item in items {
    let response = match item {
      Object(request) =>
        match (request.get("expression"), request.get("data")) {
          (Some(String(expression)), Some(data)) =>
            try {
              let response = Json::object(
                Map([
                  ("ok", Json::boolean(true)),
                  ("result", search(expression, data, limits~)),
                ]),
              )
              // Reserve space for up to 10,000 small error responses. Successful
              // replies share a budget; a large item must not prevent later small
              // requests from running. Account for the outer array's indentation.
              let size = measure_json(response, true, initial_depth=1)
              let units = size.units
              if size.nodes > 500000 - response_nodes ||
                units > 8388608 - response_units {
                fail("limit_exceeded", 0, "batch response budget exhausted")
              }
              response_nodes += size.nodes
              response_units += units
              response
            } catch {
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
