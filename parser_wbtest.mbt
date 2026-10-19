///|
test "parser builds field, index, slice, and projection nodes" {
  let limits = default_limits()
  assert_true(
    parse("users[0].name", limits)
    is Subexpression(Index(Field("users"), 0), Field("name")),
  )
  assert_true(
    parse("users[*].name", limits)
    is Projection(
      ListWildcard(Field("users")),
      Subexpression(Current, Field("name"))
    ),
  )
  assert_true(
    parse("items[1:5:2]", limits)
    is Projection(Slice(Field("items"), Some(1), Some(5), Some(2)), Current),
  )
}

///|
test "parser handles filters, pipes, functions, and multi-selects" {
  let expr = parse(
    "items[?price >= `10`].{name: name, cost: price} | sort_by(@, &cost)",
    default_limits(),
  )
  assert_true(
    expr
    is Pipe(
      Projection(
        Filter(
          Field("items"),
          Compare(Ge, Field("price"), Literal(Number(10.0, ..)))
        ),
        Subexpression(Current, MultiHash(_))
      ),
      Function("sort_by", _)
    ),
  )
}

///|
test "parser rejects trailing punctuation" {
  let error = try {
    parse("foo.", default_limits()) |> ignore
    None
  } catch {
    JmesPathError(d) => Some(d.code)
  }
  assert_eq(error, Some("syntax"))
}

///|
test "parser rejects deep nesting before the runtime stack overflows" {
  let nested = StringBuilder()
  for i = 0; i < 300; i = i + 1 {
    nested.write_char('(')
  }
  nested.write_char('@')
  for i = 0; i < 300; i = i + 1 {
    nested.write_char(')')
  }
  let error = try {
    parse(nested.to_string(), default_limits()) |> ignore
    None
  } catch {
    JmesPathError(d) => Some(d.code)
  }
  assert_eq(error, Some("limit_exceeded"))
}

///|
test "parser rejects long field chains while constructing the AST" {
  let chain = StringBuilder()
  chain.write_string("root")
  for i = 0; i < 300; i = i + 1 {
    chain.write_string(".field")
  }
  let error = try {
    parse(chain.to_string(), default_limits()) |> ignore
    None
  } catch {
    JmesPathError(d) => Some(d.code)
  }
  assert_eq(error, Some("limit_exceeded"))
}

///|
test "unary nesting accepts the depth boundary and rejects the next level" {
  let valid = StringBuilder()
  for i = 0; i < 255; i = i + 1 {
    valid.write_char('!')
  }
  valid.write_char('@')
  let valid_expression = parse(valid.to_string(), default_limits())
  assert_eq(expr_depth(valid_expression), 256)

  let invalid = StringBuilder()
  for i = 0; i < 256; i = i + 1 {
    invalid.write_char('!')
  }
  invalid.write_char('@')
  let error = try {
    parse(invalid.to_string(), default_limits()) |> ignore
    None
  } catch {
    JmesPathError(d) => Some(d.code)
  }
  assert_eq(error, Some("limit_exceeded"))
}
