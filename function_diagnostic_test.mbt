///|
test "function diagnostics use the function name's Unicode scalar offset" {
  let cases = [
    ("'月😀' | length(`1`)", "invalid_type", 7),
    ("\"月😀\".length()", "invalid_arity", 5),
    ("'月😀' | no_such_function()", "unknown_function", 7),
    ("'月😀' | length(reverse(`1`))", "invalid_type", 14),
    ("map(&length(@), `[1]`)", "invalid_type", 5),
    ("length()", "invalid_arity", 0),
  ]
  for item in cases {
    let (expression, code, offset) = item
    let actual = try {
      @jmespath.search(expression, Json::null()) |> ignore
      None
    } catch {
      @jmespath.JmesPathError(d) => Some((d.code, d.offset))
    }
    assert_eq(actual, Some((code, offset)))
  }
}

///|
test "nested function work errors keep the inner function location" {
  let limits = { ..@jmespath.default_limits(), max_steps: 5, }
  let actual = try {
    @jmespath.search("'月😀' | length(reverse(@))", Json::null(), limits~)
    |> ignore
    None
  } catch {
    @jmespath.JmesPathError(d) => Some((d.code, d.offset))
  }
  assert_eq(actual, Some(("limit_exceeded", 14)))
}
