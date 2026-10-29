///|
// Constant-extra-space lexical preflight, not a second JSON parser. Count keys and
// values alike, including duplicate keys that the parser would later discard.
// Keep string escape state so punctuation inside strings cannot affect depth.
fn preflight_json_text(text : String) -> Unit raise JmesPathError {
  if text.length() > 16777216 {
    fail("limit_exceeded", 0, "JSON text exceeds 16 Mi UTF-16 units")
  }
  let mut quoted = false
  let mut escaped = false
  let mut atom = false
  let mut depth = 0
  let mut tokens = 0
  let mut units = 0
  for c in text.iter() {
    if quoted {
      if !escaped && c == '"' {
        quoted = false
        continue
      }
      units += if c.to_int() > 65535 { 2 } else { 1 }
      if units > 8388608 {
        fail("limit_exceeded", 0, "JSON string token exceeds 8 Mi source units")
      }
      if escaped {
        escaped = false
      } else if c == '\\' {
        escaped = true
      }
      continue
    }
    if is_space(c) || c == ',' || c == ':' {
      atom = false
      continue
    }
    if c == ']' || c == '}' {
      depth -= 1
      atom = false
      // Leave exact grammar diagnostics to the parser, but do not allow an
      // invalid closing prefix to offset excessive later nesting.
      if depth < 0 {
        fail("invalid_json", 0, "unmatched JSON closing delimiter")
      }
      continue
    }
    if c == '"' || c == '[' || c == '{' || !atom {
      tokens += 1
      if tokens > 1000000 {
        fail("limit_exceeded", 0, "JSON text exceeds 1000000 lexical tokens")
      }
    }
    if c == '"' {
      quoted = true
      escaped = false
      units = 0
      atom = false
    } else if c == '[' || c == '{' {
      depth += 1
      if depth > 1024 {
        fail("limit_exceeded", 0, "JSON text exceeds nesting 1024")
      }
      atom = false
    } else {
      atom = true
    }
  }
}

///|
/// Preflight text allocation budgets, then parse JSON. This does not impose
/// per-query JSON shape limits; batch callers retain independent item checks.
pub fn parse_json_bounded(text : String) -> Json raise JmesPathError {
  preflight_json_text(text)
  @json.parse(text) catch {
    @json.DepthLimitExceeded =>
      fail("limit_exceeded", 0, "JSON nesting exceeds parser limit")
    _ => fail("invalid_json", 0, "input is not valid JSON")
  }
}
