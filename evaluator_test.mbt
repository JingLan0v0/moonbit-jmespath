///|
test "field, index, negative index, and slice evaluation" {
  let data = @json.parse(
    "{\"users\":[{\"name\":\"Ada\"},{\"name\":\"Lin\"},{\"name\":\"Sam\"}]}",
  )
  assert_eq(@jmespath.search("users[0].name", data), Json::string("Ada"))
  assert_eq(@jmespath.search("users[-1].name", data), Json::string("Sam"))
  assert_eq(
    @jmespath.search("users[0:3:2].name", data),
    @json.parse("[\"Ada\",\"Sam\"]"),
  )
}

///|
test "wildcard, flatten, filter, and pipe evaluation" {
  let data = @json.parse("{\"groups\":[[{\"v\":1},{\"v\":3}],[{\"v\":2}]]}")
  assert_eq(@jmespath.search("groups[].v", data), @json.parse("[1,3,2]"))
  assert_eq(
    @jmespath.search("groups[] | [?v >= `2`].v", data),
    @json.parse("[3,2]"),
  )
}

///|
test "boolean, comparison, fallback, and multi-select evaluation" {
  let data = @json.parse("{\"name\":\"Ada\",\"active\":true,\"score\":12}")
  assert_eq(@jmespath.search("missing || name", data), Json::string("Ada"))
  assert_eq(
    @jmespath.search("active && score >= `10`", data),
    Json::boolean(true),
  )
  assert_eq(
    @jmespath.search("{user: name, ok: score >= `10`}", data),
    @json.parse("{\"user\":\"Ada\",\"ok\":true}"),
  )
}

///|
test "compiled expressions are reusable and limits stop expansion" {
  let query = @jmespath.compile("[*]")
  assert_eq(query.search(@json.parse("[1,2]")), @json.parse("[1,2]"))
  let limits = { ..@jmespath.default_limits(), max_results: 1, }
  let stopped = try {
    @jmespath.search("[*]", @json.parse("[1,2]"), limits~) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(stopped)
}

///|
test "invalid custom limits are rejected before evaluation" {
  for
    limits in [
      { ..@jmespath.default_limits(), max_expression_chars: 0, },
      { ..@jmespath.default_limits(), max_ast_depth: 257, },
      { ..@jmespath.default_limits(), max_steps: 0, },
      { ..@jmespath.default_limits(), max_results: -1, },
    ] {
    let error = try {
      @jmespath.compile("@", limits~) |> ignore
      None
    } catch {
      @jmespath.JmesPathError(d) => Some(d.code)
    }
    assert_eq(error, Some("invalid_value"))
  }
}

///|
test "zero result and small step limits stop expansion" {
  let data = @json.parse("[1,2]")
  let result_limits = { ..@jmespath.default_limits(), max_results: 0, }
  let result_error = try {
    @jmespath.search("[*]", data, limits=result_limits) |> ignore
    None
  } catch {
    @jmespath.JmesPathError(d) => Some(d.code)
  }
  assert_eq(result_error, Some("limit_exceeded"))
  let step_limits = { ..@jmespath.default_limits(), max_steps: 1, }
  let step_error = try {
    @jmespath.search("[0]", data, limits=step_limits) |> ignore
    None
  } catch {
    @jmespath.JmesPathError(d) => Some(d.code)
  }
  assert_eq(step_error, Some("limit_exceeded"))
}

///|
test "large slice endpoints and strides are handled without overflow" {
  let data = @json.parse("[1,2,3]")
  assert_eq(@jmespath.search("[2147483647:]", data), @json.parse("[]"))
  assert_eq(@jmespath.search("[:2147483647]", data), data)
  assert_eq(@jmespath.search("[0:3:2147483647]", data), @json.parse("[1]"))
}

///|
test "array-producing functions observe the result budget" {
  let limits = { ..@jmespath.default_limits(), max_results: 1, }
  for expression in ["sort(@)", "reverse(@)", "values(@)", "keys(@)"] {
    let input = if expression == "values(@)" || expression == "keys(@)" {
      @json.parse("{\"a\":1,\"b\":2}")
    } else {
      @json.parse("[2,1]")
    }
    let error = try {
      @jmespath.search(expression, input, limits~) |> ignore
      None
    } catch {
      @jmespath.JmesPathError(d) => Some(d.code)
    }
    assert_eq(error, Some("limit_exceeded"))
  }
}
