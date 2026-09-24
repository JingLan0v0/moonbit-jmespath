///|
test "lexer recognizes identifiers, operators, literals, and raw strings" {
  let tokens = lex("items[?price >= `10`].name || 'none'", default_limits())
  assert_eq(tokens.length(), 12)
  assert_true(tokens[0].kind is Identifier("items"))
  assert_true(tokens[3].kind is Identifier("price"))
  assert_true(tokens[4].kind is GeToken)
  assert_true(tokens[5].kind is LiteralToken(Number(10.0, ..)))
  assert_true(tokens[10].kind is RawString("none"))
}

///|
test "lexer rejects malformed input with an offset" {
  let error = try {
    lex("foo = bar", default_limits()) |> ignore
    None
  } catch {
    JmesPathError(d) => Some(d)
  }
  assert_eq(error, Some({ code: "syntax", offset: 4, message: "expected ==", }))
}
