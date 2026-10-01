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

///|
test "integer indexes reject overflow without wrapping" {
  for
    expression in [
      "items[2147483648]", "items[-2147483649]", "items[-21474836480]",
    ] {
    let error = try {
      parse(expression, default_limits()) |> ignore
      None
    } catch {
      JmesPathError(d) => Some(d.code)
    }
    assert_eq(error, Some("syntax"))
  }
  match parse("items[-2147483648]", default_limits()) {
    Index(Field("items"), value) => assert_eq(value, -2147483647 - 1)
    _ => assert_true(false)
  }
}
