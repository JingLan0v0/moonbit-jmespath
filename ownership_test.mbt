///|
test "mutating a nested literal result does not change the compiled expression" {
  let query = @jmespath.compile("`{\"items\":[{\"name\":\"original\"}]}`.items")
  let first = query.search(Json::null())
  guard first is Array(items) && items[0] is Object(entry) else {
    fail("expected array of objects")
  }
  entry["name"] = Json::string("changed")
  items.push(Json::null())
  assert_eq(
    query.search(Json::null()),
    @json.parse("[{\"name\":\"original\"}]"),
  )
}

///|
test "compiled queries see live input and recover after rejecting a cycle" {
  let query = @jmespath.compile("items")
  let items : Array[Json] = [Json::number(1.0)]
  let input = Json::object(Map([("items", Json::array(items))]))
  guard query.search(input) is Array(first) else {
    fail("expected items array")
  }
  first.push(Json::number(2.0))
  assert_eq(query.search(input), @json.parse("[1,2]"))
  items.push(input)
  let code = try {
    query.search(input) |> ignore
    "unexpected success"
  } catch {
    @jmespath.JmesPathError(d) => d.code
  }
  assert_eq(code, "limit_exceeded")
  items.pop() |> ignore
  assert_eq(query.search(input), @json.parse("[1,2]"))
}

///|
test "map copies a container literal once per search within the work budget" {
  // 2 visits for map and @, 32 reference visits, and 3 nodes to copy.
  let limits = { ..@jmespath.default_limits(), max_steps: 37, }
  let query = @jmespath.compile("map(&`[0,1]`, @)", limits~)
  let input = Json::array(Array::make(32, Json::null()))
  for _ in 0..<2 {
    guard query.search(input) is Array(results) && results[0] is Array(first) else {
      fail("expected arrays")
    }
    assert_eq(results.length(), 32)
    assert_eq(results[0], @json.parse("[0,1]"))
    first.push(Json::number(2.0))
  }
  let smaller = { ..limits, max_steps: 36, }
  let retry = @jmespath.compile("map(&`[0,1]`, @)", limits=smaller)
  let code = try {
    retry.search(input) |> ignore
    "unexpected success"
  } catch {
    @jmespath.JmesPathError(d) => d.code
  }
  assert_eq(code, "limit_exceeded")
  assert_eq(retry.search(Json::array([Json::null()])), @json.parse("[[0,1]]"))
}

///|
test "copying a deeply nested literal respects the existing JSON boundary" {
  let source = "[".repeat(256) + "0" + "]".repeat(256)
  let query = @jmespath.compile("`" + source + "`")
  assert_eq(@jmespath.stringify_bounded(query.search(Json::null())), source)
}
