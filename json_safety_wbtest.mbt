///|
test "JSON string estimates reserve escapes and UTF-16 units at the boundary" {
  let text = "a月😀\u0000\"\\/"
  let exact : JsonBudget = { nodes: 0, units: 16777216 - 18, }
  exact.string(text)
  assert_eq(exact.units, 16777216)
  for
    (remaining, message) in [
      (17, "JSON output estimate exceeds 16 Mi UTF-16 units"),
      (7, "JSON string exceeds size budget"),
    ] {
    let budget : JsonBudget = { nodes: 0, units: 16777216 - remaining, }
    let diagnostic = try {
      budget.string(text)
      None
    } catch {
      JmesPathError(d) => Some((d.code, d.offset, d.message))
    }
    assert_eq(diagnostic, Some(("limit_exceeded", 0, message)))
  }
}

///|
test "JSON accounting counts shared arrays through each container path" {
  let child = Json::array([Json::null(), Json::array([])])
  let root = Json::array([
    child,
    Json::object(Map([("月😀", child)])),
    Json::boolean(true),
  ])
  let compact = measure_json(root, false)
  assert_eq((compact.nodes, compact.units), (9, 42))
  let pretty = measure_json(root, true)
  assert_eq((pretty.nodes, pretty.units), (9, 120))
  let wrapped = measure_json(root, true, initial_depth=1)
  assert_eq((wrapped.nodes, wrapped.units), (9, 150))
}

///|
test "wide shared arrays stop after the inclusive expanded node limit" {
  let child = Json::array(Array::make(499998, Json::null()))
  let items = [child, child, Json::null()]
  let root = Json::array(items)
  assert_eq(measure_json(root, false).nodes, 1000000)
  items.push(Json::null())
  let diagnostic = try {
    measure_json(root, false) |> ignore
    None
  } catch {
    JmesPathError(d) => Some((d.code, d.message))
  }
  assert_eq(
    diagnostic,
    Some(("limit_exceeded", "JSON value exceeds 1000000 expanded nodes")),
  )
}
