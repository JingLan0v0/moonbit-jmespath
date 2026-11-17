///|
priv struct JsonArrayCursor {
  items : Array[Json]
  mut index : Int32
}

///|
priv enum JsonFrame {
  Items(JsonArrayCursor)
  Members(Iter[(String, Json)])
}

///|
priv struct JsonBudget {
  mut nodes : Int32
  mut units : Int32
}

///|
fn JsonBudget::add(
  self : JsonBudget,
  count : Int32,
) -> Unit raise JmesPathError {
  if count > 16777216 - self.units {
    fail("limit_exceeded", 0, "JSON output estimate exceeds 16 Mi UTF-16 units")
  }
  self.units += count
}

///|
fn JsonBudget::string(
  self : JsonBudget,
  text : String,
) -> Unit raise JmesPathError {
  let length = text.length()
  if length > 16777216 - self.units {
    fail("limit_exceeded", 0, "JSON string exceeds size budget")
  }
  // Count the quotes and existing UTF-16 units up front. Only ASCII
  // escapes add units, so there is no need to decode surrogate pairs.
  self.add(length + 2)
  for i in 0..<length {
    let unit = text[i]
    if unit < 0x20 {
      self.add(5)
    } else if unit == 0x22 || unit == 0x2F || unit == 0x5C {
      // Conservatively count a slash as escaped as well.
      self.add(1)
    }
  }
}

///|
fn validate_number_repr(
  number : Double,
  text : String,
) -> Unit raise JmesPathError {
  // Json::number exposes repr to library callers. The core serializer writes
  // it verbatim, so it must be a numeric scalar agreeing with the stored value.
  // Reject containers/strings before parsing to avoid allocating discarded JSON.
  for c in text {
    if !(is_digit(c) || c == '-' || c == '+' || c == '.' || c == 'e' || c == 'E') {
      fail("invalid_value", 0, "invalid numeric representation")
    }
  }
  let parsed = @json.parse(text) catch {
    _ => fail("invalid_value", 0, "invalid numeric representation")
  }
  guard parsed is Number(value, ..) && value == number else {
    fail("invalid_value", 0, "numeric representation disagrees with value")
  }
}

///|
// Walk one child at a time. Stack space depends on nesting, not array width.
// Shared subtrees are counted once per occurrence, exactly as JSON output
// expands them; cycles supplied by callers hit the depth limit as well.
fn measure_json(
  value : Json,
  pretty : Bool,
  initial_depth~ : Int32 = 0,
) -> JsonBudget raise JmesPathError {
  let budget = { nodes: 0, units: 0, }
  let stack : Array[JsonFrame] = []
  walk~: for current = value {
    let depth = initial_depth + stack.length()
    if depth > 256 {
      fail("limit_exceeded", 0, "JSON value exceeds depth 256")
    }
    if budget.nodes >= 1000000 {
      fail("limit_exceeded", 0, "JSON value exceeds 1000000 expanded nodes")
    }
    budget.nodes += 1
    if pretty {
      budget.add(2 * depth + 2)
    }
    match current {
      Array(items) => {
        budget.add(2)
        if pretty {
          budget.add(2 * depth + 2)
        }
        stack.push(Items({ items, index: 0, }))
      }
      Object(entries) => {
        budget.add(2)
        if pretty {
          budget.add(2 * depth + 2)
        }
        stack.push(Members(entries.iter()))
      }
      String(text) => budget.string(text)
      Number(number, repr~) => {
        if number.is_nan() || number.is_inf() {
          fail(
            "invalid_value", 0, "non-finite numbers cannot be represented as JSON",
          )
        }
        match repr {
          Some(text) => {
            // Charge size before scanning or parsing a caller-supplied repr.
            budget.add(text.length())
            validate_number_repr(number, text)
          }
          None => budget.add(32)
        }
      }
      _ => budget.add(5)
    }
    // Keep one cursor per open container. Moving to a sibling reuses it.
    while !stack.is_empty() {
      match stack[stack.length() - 1] {
        Items(cursor) =>
          if cursor.index < cursor.items.length() {
            budget.add(1)
            let item = cursor.items[cursor.index]
            cursor.index += 1
            continue walk~ item
          }
        Members(members) =>
          if members.next() is Some((key, item)) {
            budget.string(key)
            budget.add(3)
            continue walk~ item
          }
      }
      stack.pop() |> ignore
    }
    break walk~
  }
  budget
}

///|
fn check_json_size(value : Json, pretty : Bool) -> Unit raise JmesPathError {
  measure_json(value, pretty) |> ignore
}

///|
/// Serialize after checking nesting, expanded node count, and a conservative
/// output-size estimate. Pretty output uses two spaces and is also bounded.
pub fn stringify_bounded(
  value : Json,
  pretty~ : Bool = false,
) -> String raise JmesPathError {
  check_json_size(value, pretty)
  value.stringify(indent=if pretty { 2 } else { 0 })
}
