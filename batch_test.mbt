///|
test "batch queries isolate successes and structured errors" {
  let requests = @json.parse(
    "[{\"expression\":\"name\",\"data\":{\"name\":\"Ada\"}},{\"expression\":\"length()\",\"data\":null}]",
  )
  let result = @jmespath.search_batch(requests)
  guard result is Array(items) else { fail("expected array") }
  assert_eq(items.length(), 2)
  assert_eq(items[0], @json.parse("{\"ok\":true,\"result\":\"Ada\"}"))
  guard items[1] is Object(error) else { fail("expected object") }
  assert_eq(error.get("ok"), Some(Json::boolean(false)))
}

///|
test "malformed batch entries do not discard later requests" {
  let requests = @json.parse(
    "[{\"expression\":\"name\",\"data\":{\"name\":\"first\"}},{\"expression\":4,\"data\":null},{\"expression\":\"name\",\"data\":{\"name\":\"last\"}}]",
  )
  guard @jmespath.search_batch(requests) is Array(items) else {
    assert_true(false)
    return
  }
  assert_eq(items.length(), 3)
  assert_eq(items[0], @json.parse("{\"ok\":true,\"result\":\"first\"}"))
  guard items[1] is Object(error) else {
    assert_true(false)
    return
  }
  guard error.get("error") is Some(Object(detail)) else {
    assert_true(false)
    return
  }
  assert_eq(detail.get("code"), Some(Json::string("invalid_batch")))
  assert_eq(items[2], @json.parse("{\"ok\":true,\"result\":\"last\"}"))
}

///|
test "batch rejects invalid limits even when it has no requests" {
  let limits = { ..@jmespath.default_limits(), max_steps: 0, }
  let rejected = try {
    @jmespath.search_batch(@json.parse("[]"), limits~) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "reused batch expressions keep independent input and work budgets" {
  let requests = @json.parse(
    "[{\"expression\":\"length(@)\",\"data\":[1,2]},{\"expression\":\"length(@)\",\"data\":\"too long\"},{\"expression\":\"length(@)\",\"data\":[3]},{\"expression\":\"length(@)\",\"data\":null},{\"expression\":\"length(@)\",\"data\":[]}]",
  )
  let limits = { ..@jmespath.default_limits(), max_steps: 2, }
  guard @jmespath.search_batch(requests, limits~) is Array(items) else {
    fail("expected batch array")
  }
  assert_eq(items[0], @json.parse("{\"ok\":true,\"result\":2}"))
  assert_eq(
    @jmespath.search("error.code", items[1]),
    Json::string("limit_exceeded"),
  )
  assert_eq(items[2], @json.parse("{\"ok\":true,\"result\":1}"))
  assert_eq(
    @jmespath.search("error.code", items[3]),
    Json::string("invalid_type"),
  )
  assert_eq(items[4], @json.parse("{\"ok\":true,\"result\":0}"))

  let stricter = { ..limits, max_steps: 1, }
  guard @jmespath.search_batch(requests, limits=stricter) is Array(items) else {
    fail("expected batch array")
  }
  assert_eq(
    @jmespath.search("error.code", items[0]),
    Json::string("limit_exceeded"),
  )
}

///|
test "batch reuse isolates mutable literal results" {
  let request = @json.parse("{\"expression\":\"`[1]`\",\"data\":null}")
  guard @jmespath.search_batch(Json::array([request, request])) is Array(items) else {
    fail("expected batch array")
  }
  guard @jmespath.search("result", items[0]) is Array(values) else {
    fail("expected literal array")
  }
  values.push(Json::number(2.0))
  assert_eq(items[0], @json.parse("{\"ok\":true,\"result\":[1,2]}"))
  assert_eq(items[1], @json.parse("{\"ok\":true,\"result\":[1]}"))
}

///|
test "long expressions still work when excluded from batch reuse" {
  let data = @json.parse("{\"name\":\"Ada\"}")
  let source = " ".repeat(1024) + "name"
  let request = Json::object(
    Map([("expression", Json::string(source)), ("data", data)]),
  )
  let short = @json.parse(
    "{\"expression\":\"name\",\"data\":{\"name\":\"next\"}}",
  )
  let requests = Json::array([request, request, short])
  assert_eq(
    @jmespath.search_batch(requests),
    @json.parse(
      "[{\"ok\":true,\"result\":\"Ada\"},{\"ok\":true,\"result\":\"Ada\"},{\"ok\":true,\"result\":\"next\"}]",
    ),
  )
}
