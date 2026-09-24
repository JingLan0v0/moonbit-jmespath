///|
test "CLI accepts stdin, files, compact output, and option terminator" {
  assert_eq(
    parse_args(["foo"]),
    Query(expression="foo", path="-", compact=false),
  )
  assert_eq(
    parse_args(["--compact", "items[*].name", "data.json"]),
    Query(expression="items[*].name", path="data.json", compact=true),
  )
  assert_eq(
    parse_args(["--", "-expression", "data.json"]),
    Query(expression="-expression", path="data.json", compact=false),
  )
}

///|
test "CLI rejects unknown options and extra arguments" {
  let unknown = try {
    parse_args(["--wat", "foo"]) |> ignore
    false
  } catch {
    _ => true
  }
  let extra = try {
    parse_args(["a", "b", "c"]) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(unknown && extra)
}
