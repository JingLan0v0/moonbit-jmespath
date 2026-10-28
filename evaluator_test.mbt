///|
test "multi-select preserves null but evaluates other false-like inputs" {
  for expression in ["[foo,bar]", "{a:foo}", "[unknown_function()]"] {
    assert_eq(@jmespath.search(expression, Json::null()), Json::null())
  }
  for input in ["{}", "[]", "false", "0", "\"\""] {
    assert_eq(
      @jmespath.search_json("[foo,bar]", input),
      @json.parse("[null,null]"),
    )
    assert_eq(
      @jmespath.search_json("{a:foo}", input),
      @json.parse("{\"a\":null}"),
    )
  }
}

///|
test "subexpressions evaluate functions after a missing field" {
  assert_eq(
    @jmespath.search_json("missing.to_array(@)", "{}"),
    @json.parse("[null]"),
  )
  assert_eq(
    @jmespath.search_json("missing.not_null(@, 'fallback')", "{}"),
    Json::string("fallback"),
  )
  assert_eq(
    @jmespath.search_json("missing.type(@)", "{}"),
    Json::string("null"),
  )
  assert_eq(@jmespath.search_json("missing.[foo]", "{}"), Json::null())
  let error = try {
    @jmespath.search_json("missing.length(@)", "{}") |> ignore
    None
  } catch {
    @jmespath.JmesPathError(d) => Some(d.code)
  }
  assert_eq(error, Some("invalid_type"))
}

///|
test "null multi-select projection and map keep different cardinalities" {
  let data = @json.parse("[null,{\"x\":1},{}]")
  assert_eq(@jmespath.search("[*].[x]", data), @json.parse("[[1],[null]]"))
  assert_eq(
    @jmespath.search("map(&[x], @)", data),
    @json.parse("[null,[1],[null]]"),
  )
  assert_eq(
    @jmespath.search("[*].{v:x}", data),
    @json.parse("[{\"v\":1},{\"v\":null}]"),
  )
}

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
