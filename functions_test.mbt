///|
test "string ordering uses Unicode code points across supplementary planes" {
  let data = @json.parse(
    "[\"\\uE000\",\"\\uD800\\uDC00\",\"😀\",\"\\uFFFF\"]",
  )
  let sorted = @json.parse(
    "[\"\\uE000\",\"\\uFFFF\",\"\\uD800\\uDC00\",\"😀\"]",
  )
  assert_eq(@jmespath.search("sort(@)", data), sorted)
  assert_eq(@jmespath.search("min(@)", data), @json.parse("\"\\uE000\""))
  assert_eq(@jmespath.search("max(@)", data), Json::string("😀"))
  assert_eq(@jmespath.search("sort(@)", data), sorted)
  assert_eq(
    data,
    @json.parse("[\"\\uE000\",\"\\uD800\\uDC00\",\"😀\",\"\\uFFFF\"]"),
  )
}

///|
test "expression-reference ordering shares Unicode comparison and preserves ties" {
  let data = @json.parse(
    "[{\"id\":1,\"k\":\"😀\"},{\"id\":2,\"k\":\"\\uE000\"},{\"id\":3,\"k\":\"😀\"}]",
  )
  assert_eq(
    @jmespath.search("sort_by(@, &k)[*].id", data),
    @json.parse("[2,1,3]"),
  )
  assert_eq(@jmespath.search("min_by(@, &k).id", data), Json::number(2.0))
  assert_eq(@jmespath.search("max_by(@, &k).id", data), Json::number(1.0))
}

///|
test "Unicode ordering is prefix-aware and performs no locale normalization" {
  let data = @json.parse(
    "[\"😀x\",\"😀\",\"é\",\"é\",\"a\",\"\",\"A\",\"月\"]",
  )
  assert_eq(
    @jmespath.search("sort(@)", data),
    @json.parse("[\"\",\"A\",\"a\",\"é\",\"é\",\"月\",\"😀\",\"😀x\"]"),
  )
  assert_eq(
    @jmespath.search_json("length(@)", "\"a😀月\""),
    Json::number(3.0),
  )
  assert_eq(
    @jmespath.search_json("reverse(@)", "\"a😀月\""),
    Json::string("月😀a"),
  )
}

///|
test "numeric and collection functions" {
  let data = @json.parse("{\"nums\":[3,-2,8],\"empty\":[]}")
  assert_eq(@jmespath.search("abs(nums[1])", data), @json.parse("2"))
  assert_eq(@jmespath.search("avg(nums)", data), @json.parse("3"))
  assert_eq(@jmespath.search("sum(nums)", data), @json.parse("9"))
  assert_eq(@jmespath.search("max(nums)", data), @json.parse("8"))
  assert_eq(@jmespath.search("min(nums)", data), @json.parse("-2"))
  assert_eq(@jmespath.search("avg(empty)", data), Json::null())
  assert_eq(@jmespath.search("sort(nums)", data), @json.parse("[-2,3,8]"))
}

///|
test "string, conversion, object, and variadic functions" {
  let data = @json.parse(
    "{\"word\":\"moonbit\",\"parts\":[\"a\",\"b\"],\"a\":{\"x\":1},\"b\":{\"y\":2}}",
  )
  assert_eq(
    @jmespath.search("contains(word, 'bit')", data),
    Json::boolean(true),
  )
  assert_eq(
    @jmespath.search("starts_with(word, 'moon')", data),
    Json::boolean(true),
  )
  assert_eq(
    @jmespath.search("ends_with(word, 'bit')", data),
    Json::boolean(true),
  )
  assert_eq(@jmespath.search("join('-', parts)", data), Json::string("a-b"))
  assert_eq(@jmespath.search("length(word)", data), @json.parse("7"))
  assert_eq(
    @jmespath.search("merge(a, b)", data),
    @json.parse("{\"x\":1,\"y\":2}"),
  )
  assert_eq(@jmespath.search("to_number('12.5')", data), @json.parse("12.5"))
  assert_eq(@jmespath.search("type(parts)", data), Json::string("array"))
}

///|
test "number conversion validates scalar grammar and preserves whitespace compatibility" {
  for
    text in [
      "[1,2]", "{\"x\":1}", "\"123\"", "true", "null", "", "+1", "01", "1e", "1 2",
      ".5", "NaN", "Infinity", "0x10",
    ] {
    assert_eq(
      @jmespath.search("to_number(@)", Json::string(text)),
      Json::null(),
    )
  }
  for text in ["125", "1.25e2", "125.0", " 125\r\n\t"] {
    assert_eq(
      @jmespath.search("to_number(@)", Json::string(text)),
      Json::number(125.0),
    )
  }
  assert_eq(
    @jmespath.search("to_number(@)", Json::string("-1.25e-2")),
    Json::number(-0.0125),
  )
}

///|
test "number conversion consumes the work budget before parsing long numeric strings" {
  let limits = { ..@jmespath.default_limits(), max_steps: 8, }
  let code = try {
    @jmespath.search("to_number(@)", Json::string("1".repeat(100)), limits~)
    |> ignore
    None
  } catch {
    @jmespath.JmesPathError(d) => Some(d.code)
  }
  assert_eq(code, Some("limit_exceeded"))
  assert_eq(
    @jmespath.search("to_number(@)", Json::number(12.0), limits~),
    Json::number(12.0),
  )
}

///|
test "function errors are classified" {
  let invalid_type = try {
    @jmespath.search("sum('no')", Json::null()) |> ignore
    false
  } catch {
    _ => true
  }
  let invalid_arity = try {
    @jmespath.search("length()", Json::null()) |> ignore
    false
  } catch {
    _ => true
  }
  let unknown = try {
    @jmespath.search("missing_function(@)", Json::null()) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(invalid_type && invalid_arity && unknown)
}

///|
test "expression-reference functions map, sort, and select records" {
  let data = @json.parse(
    "{\"people\":[{\"name\":\"Ada\",\"age\":36},{\"name\":\"Lin\",\"age\":28},{\"name\":\"Sam\",\"age\":41}]}",
  )
  assert_eq(
    @jmespath.search("map(&name, people)", data),
    @json.parse("[\"Ada\",\"Lin\",\"Sam\"]"),
  )
  assert_eq(
    @jmespath.search("sort_by(people, &age)[*].name", data),
    @json.parse("[\"Lin\",\"Ada\",\"Sam\"]"),
  )
  assert_eq(
    @jmespath.search("max_by(people, &age).name", data),
    Json::string("Sam"),
  )
  assert_eq(
    @jmespath.search("min_by(people, &age).name", data),
    Json::string("Lin"),
  )
}
