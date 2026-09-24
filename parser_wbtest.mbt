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
