///|
test "batch queries isolate successes and structured errors" {
  let requests = @json.parse(
    "[{\"expression\":\"name\",\"data\":{\"name\":\"Ada\"}},{\"expression\":\"length()\",\"data\":null}]",
  )
  let result = search_batch(requests)
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
  guard search_batch(requests) is Array(items) else {
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
  let limits = { ..default_limits(), max_steps: 0, }
  let rejected = try {
    search_batch(@json.parse("[]"), limits~) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}
