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
