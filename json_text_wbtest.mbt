///|
test "text preflight string source limit is inclusive and escape-aware" {
  preflight_json_text("\"" + "a".repeat(8388608) + "\"")
  let code = try {
    preflight_json_text("\"" + "a".repeat(8388609) + "\"")
    None
  } catch {
    JmesPathError(d) => Some(d.code)
  }
  assert_eq(code, Some("limit_exceeded"))
  preflight_json_text("\"" + "[".repeat(2000) + "\"")
  preflight_json_text("\"" + "\\\"".repeat(2000) + "\"")
}

///|
test "text preflight counts duplicate keys and inclusive token boundary" {
  preflight_json_text("[" + "0,".repeat(999998) + "0]")
  let code = try {
    preflight_json_text("{" + "\"x\":0,".repeat(500000) + "\"x\":0}")
    None
  } catch {
    JmesPathError(d) => Some(d.code)
  }
  assert_eq(code, Some("limit_exceeded"))
}
