///|
test "field, index, negative index, and slice evaluation" {
  let data = @json.parse(
    "{\"users\":[{\"name\":\"Ada\"},{\"name\":\"Lin\"},{\"name\":\"Sam\"}]}",
  )
  assert_eq(search("users[0].name", data), Json::string("Ada"))
  assert_eq(search("users[-1].name", data), Json::string("Sam"))
  assert_eq(search("users[0:3:2].name", data), @json.parse("[\"Ada\",\"Sam\"]"))
}

///|
test "wildcard, flatten, filter, and pipe evaluation" {
  let data = @json.parse("{\"groups\":[[{\"v\":1},{\"v\":3}],[{\"v\":2}]]}")
  assert_eq(search("groups[].v", data), @json.parse("[1,3,2]"))
  assert_eq(search("groups[] | [?v >= `2`].v", data), @json.parse("[3,2]"))
}

///|
test "boolean, comparison, fallback, and multi-select evaluation" {
  let data = @json.parse("{\"name\":\"Ada\",\"active\":true,\"score\":12}")
  assert_eq(search("missing || name", data), Json::string("Ada"))
  assert_eq(search("active && score >= `10`", data), Json::boolean(true))
  assert_eq(
    search("{user: name, ok: score >= `10`}", data),
    @json.parse("{\"user\":\"Ada\",\"ok\":true}"),
  )
}

///|
test "compiled expressions are reusable and limits stop expansion" {
  let query = compile("[*]")
  assert_eq(query.search(@json.parse("[1,2]")), @json.parse("[1,2]"))
  let limits = { ..default_limits(), max_results: 1, }
  let stopped = try {
    search("[*]", @json.parse("[1,2]"), limits~) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(stopped)
}
