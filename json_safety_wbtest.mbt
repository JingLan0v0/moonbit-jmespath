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
