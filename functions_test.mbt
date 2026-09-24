///|
test "numeric and collection functions" {
  let data = @json.parse("{\"nums\":[3,-2,8],\"empty\":[]}")
  assert_eq(search("abs(nums[1])", data), @json.parse("2"))
  assert_eq(search("avg(nums)", data), @json.parse("3"))
  assert_eq(search("sum(nums)", data), @json.parse("9"))
  assert_eq(search("max(nums)", data), @json.parse("8"))
  assert_eq(search("min(nums)", data), @json.parse("-2"))
  assert_eq(search("avg(empty)", data), Json::null())
  assert_eq(search("sort(nums)", data), @json.parse("[-2,3,8]"))
}

///|
test "string, conversion, object, and variadic functions" {
  let data = @json.parse(
    "{\"word\":\"moonbit\",\"parts\":[\"a\",\"b\"],\"a\":{\"x\":1},\"b\":{\"y\":2}}",
  )
  assert_eq(search("contains(word, 'bit')", data), Json::boolean(true))
  assert_eq(search("starts_with(word, 'moon')", data), Json::boolean(true))
  assert_eq(search("ends_with(word, 'bit')", data), Json::boolean(true))
  assert_eq(search("join('-', parts)", data), Json::string("a-b"))
  assert_eq(search("length(word)", data), @json.parse("7"))
  assert_eq(search("merge(a, b)", data), @json.parse("{\"x\":1,\"y\":2}"))
  assert_eq(search("to_number('12.5')", data), @json.parse("12.5"))
  assert_eq(search("type(parts)", data), Json::string("array"))
}

///|
test "function errors are classified" {
  let invalid_type = try {
    search("sum('no')", Json::null()) |> ignore
    false
  } catch {
    _ => true
  }
  let invalid_arity = try {
    search("length()", Json::null()) |> ignore
    false
  } catch {
    _ => true
  }
  let unknown = try {
    search("missing_function(@)", Json::null()) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(invalid_type && invalid_arity && unknown)
}
