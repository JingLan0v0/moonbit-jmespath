///|
test "bounded JSON parsing preserves escaped punctuation and syntax diagnostics" {
  for
    text in [
      "null", "1.2e-3", "[]", "{}", "{\"x\": [true, false, null]}", "\"[{}]\\\"\\\\\"",
      "\"\\u005b\\u005d\"", "\"月😀\"",
    ] {
    assert_eq(@jmespath.parse_json_bounded(text), @json.parse(text))
  }
  for
    text in [
      "][[[", "[}", "{]", "[1,]", "\"unclosed", "true false", "01", "\"\\q\"",
    ] {
    let code = try {
      @jmespath.parse_json_bounded(text) |> ignore
      None
    } catch {
      @jmespath.JmesPathError(d) => Some(d.code)
    }
    assert_eq(code, Some("invalid_json"))
  }
}

///|
test "bounded JSON parsing rejects tokens and depth before decoding" {
  for
    text in [
      "[" + "0,".repeat(1000000) + "0]",
      "[".repeat(1025) + "0" + "]".repeat(1025),
    ] {
    let code = try {
      @jmespath.parse_json_bounded(text) |> ignore
      None
    } catch {
      @jmespath.JmesPathError(d) => Some(d.code)
    }
    assert_eq(code, Some("limit_exceeded"))
  }
  // Parsing alone must not impose the evaluator's depth 256 on all batch data.
  @jmespath.parse_json_bounded("[".repeat(257) + "0" + "]".repeat(257))
  |> ignore
}
