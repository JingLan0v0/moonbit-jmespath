///|
test "execution nesting has an explicit boundary and reusable state" {
  let allowed = "to_array(".repeat(127) + "@" + ")".repeat(127)
  assert_eq(
    @jmespath.search(allowed, Json::null()),
    Json::array([Json::null()]),
  )
  let blocked = "to_array(".repeat(128) + "@" + ")".repeat(128)
  let compiled = @jmespath.compile(blocked)
  for _ in 0..<2 {
    let code = try {
      compiled.search(Json::null()) |> ignore
      "unexpected success"
    } catch {
      @jmespath.JmesPathError(d) => d.code
    }
    assert_eq(code, "limit_exceeded")
  }
}

///|
test "JSON values supplied by library callers are depth checked iteratively" {
  let mut value = Json::null()
  for _ in 0..<256 {
    value = Json::array([value])
  }
  @jmespath.search("@", value) |> ignore
  let code = try {
    @jmespath.search("@", Json::array([value])) |> ignore
    "unexpected success"
  } catch {
    @jmespath.JmesPathError(d) => d.code
  }
  assert_eq(code, "limit_exceeded")
}

///|
test "shared output expansion is bounded before serialization or equality" {
  let expansion = "[@,@]|".repeat(29) + "[@,@]"
  for suffix in ["", "|to_string(@)", "|@ == @", "|contains([@], @)"] {
    let code = try {
      @jmespath.search(expansion + suffix, Json::number(0.0)) |> ignore
      "unexpected success"
    } catch {
      @jmespath.JmesPathError(d) => d.code
    }
    assert_eq(code, "limit_exceeded")
  }
}

///|
test "object producers charge unique keys before insertion" {
  let limits = { ..@jmespath.default_limits(), max_results: 1, }
  assert_eq(
    @jmespath.search("merge(@,@)", @json.parse("{\"a\":1}"), limits~),
    @json.parse("{\"a\":1}"),
  )
  for query in ["merge(@,@)", "{a:a,b:b}"] {
    let data = @json.parse("{\"a\":1,\"b\":2}")
    let code = try {
      @jmespath.search(query, data, limits~) |> ignore
      "unexpected success"
    } catch {
      @jmespath.JmesPathError(d) => d.code
    }
    assert_eq(code, "limit_exceeded")
  }
}

///|
test "collection reductions count work and non-finite outputs fail explicitly" {
  let limits = { ..@jmespath.default_limits(), max_steps: 3, }
  for query in ["sum(@)", "avg(@)", "contains(@, `9`)"] {
    let data = @json.parse("[1,2,3,4]")
    let code = try {
      @jmespath.search(query, data, limits~) |> ignore
      "unexpected success"
    } catch {
      @jmespath.JmesPathError(d) => d.code
    }
    assert_eq(code, "limit_exceeded")
  }
  let code = try {
    @jmespath.search_json("sum(@)", "[1e308,1e308]") |> ignore
    "unexpected success"
  } catch {
    @jmespath.JmesPathError(d) => d.code
  }
  assert_eq(code, "invalid_value")
}

///|
test "non-finite intermediate results cannot be hidden by parent expressions" {
  for
    expression in [
      "type(sum(@))", "sum(@) > `0`", "[sum(@)] | length(@)", "!sum(@)", "sum(@) || `0`",
      "type(avg(@))",
    ] {
    let code = try {
      @jmespath.search_json(expression, "[1e308,1e308]") |> ignore
      None
    } catch {
      @jmespath.JmesPathError(d) => Some(d.code)
    }
    assert_eq(code, Some("invalid_value"))
  }
  for
    expression in [
      "type(to_number(@))", "to_number(@) == to_number(@)", "[to_number(@)] | length(@)",
    ] {
    let code = try {
      @jmespath.search(expression, Json::string("1e999")) |> ignore
      None
    } catch {
      @jmespath.JmesPathError(d) => Some(d.code)
    }
    assert_eq(code, Some("invalid_value"))
  }
}

///|
test "non-finite guard respects unevaluated boolean branches" {
  let data = @json.parse("[1e308,1e308]")
  assert_eq(@jmespath.search("`true` || sum(@)", data), Json::boolean(true))
  assert_eq(@jmespath.search("`false` && sum(@)", data), Json::boolean(false))
  assert_eq(
    @jmespath.search_json("type(sum(@))", "[1e308,-1e308]"),
    Json::string("number"),
  )
}

///|
test "compiled query is reusable after intermediate overflow" {
  let query = @jmespath.compile("type(sum(@))")
  let overflowing = @json.parse("[1e308,1e308]")
  let code = try {
    query.search(overflowing) |> ignore
    None
  } catch {
    @jmespath.JmesPathError(d) => Some(d.code)
  }
  assert_eq(code, Some("invalid_value"))
  assert_eq(query.search(@json.parse("[1,2]")), Json::string("number"))
}

///|
test "ordering scans and comparisons consume configured work limits" {
  let limits = { ..@jmespath.default_limits(), max_steps: 8, }
  let numbers = Json::array(Array::make(32, Json::number(1.0)))
  for
    expression in [
      "sort(@)", "min(@)", "max(@)", "sort_by(@, &@)", "min_by(@, &@)", "max_by(@, &@)",
    ] {
    let code = try {
      @jmespath.search(expression, numbers, limits~) |> ignore
      None
    } catch {
      @jmespath.JmesPathError(d) => Some(d.code)
    }
    assert_eq(code, Some("limit_exceeded"))
  }
}

///|
test "long common prefixes exhaust comparison budget and query recovers" {
  let limits = { ..@jmespath.default_limits(), max_steps: 100, }
  let query = @jmespath.compile("sort(@)", limits~)
  let input = Json::array([
    Json::string("x".repeat(128) + "b"),
    Json::string("x".repeat(128) + "a"),
  ])
  let code = try {
    query.search(input) |> ignore
    None
  } catch {
    @jmespath.JmesPathError(d) => Some(d.code)
  }
  assert_eq(code, Some("limit_exceeded"))
  assert_eq(query.search(@json.parse("[2,1]")), @json.parse("[1,2]"))
  assert_eq(
    @jmespath.search("min(@)", input),
    Json::string("x".repeat(128) + "a"),
  )
}

///|
test "bounded merge ordering is stable and does not mutate inputs" {
  let input = @json.parse(
    "[{\"k\":2,\"id\":0},{\"k\":1,\"id\":1},{\"k\":2,\"id\":2},{\"k\":1,\"id\":3},{\"k\":2,\"id\":4},{\"k\":1,\"id\":5},{\"k\":2,\"id\":6},{\"k\":1,\"id\":7}]",
  )
  assert_eq(
    @jmespath.search("sort_by(@, &k)[*].id", input),
    @json.parse("[1,3,5,7,0,2,4,6]"),
  )
  assert_eq(@jmespath.search("[*].id", input), @json.parse("[0,1,2,3,4,5,6,7]"))
  assert_eq(@jmespath.search_json("sort(@)", "[]"), @json.parse("[]"))
  assert_eq(@jmespath.search_json("sort(@)", "[1]"), @json.parse("[1]"))
}

///|
test "bounded serialization preserves compact and pretty JSON" {
  let value = @json.parse(
    "{\"text\":\"月\\n\\\"\\\\/\",\"items\":[true,null,1]}",
  )
  for pretty in [true, false] {
    assert_eq(@json.parse(@jmespath.stringify_bounded(value, pretty~)), value)
  }
}

///|
test "batch envelopes are counted before accepting a deep result" {
  let mut data = Json::null()
  for _ in 0..<255 {
    data = Json::array([data])
  }
  let requests = Json::array([
    Json::object(Map([("expression", Json::string("@")), ("data", data)])),
    @json.parse("{\"expression\":\"@\",\"data\":42}"),
  ])
  let result = @jmespath.search_batch(requests)
  @jmespath.stringify_bounded(result, pretty=true) |> ignore
  assert_eq(
    @jmespath.search("[0].error.code", result),
    Json::string("limit_exceeded"),
  )
  assert_eq(@jmespath.search("[1].result", result), Json::number(42.0))
}

///|
test "iterative equality compares object members independent of order" {
  assert_eq(
    @jmespath.search_json(
      "a == b", "{\"a\":{\"x\":[1,null],\"y\":true},\"b\":{\"y\":true,\"x\":[1,null]}}",
    ),
    Json::boolean(true),
  )
  assert_eq(
    @jmespath.search_json("a == b", "{\"a\":{\"x\":[1]},\"b\":{\"x\":[2]}}"),
    Json::boolean(false),
  )
  assert_eq(
    @jmespath.search_json("a != b", "{\"a\":[1,2],\"b\":[2,1]}"),
    Json::boolean(true),
  )
}
