///|
priv enum JsonFrame {
  Value(Json, Int)
  Items(Iter[Json], Int)
  Members(Iter[(String, Json)], Int)
}

///|
priv struct JsonBudget {
  mut nodes : Int
  mut units : Int
}

///|
fn JsonBudget::add(self : JsonBudget, count : Int) -> Unit raise JmesPathError {
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
  // Reject large strings before walking them; count escaped strings without
  // first allocating a serialization. Slash escaping is conservatively counted.
  if text.length() > 16777216 - self.units {
    fail("limit_exceeded", 0, "JSON string exceeds size budget")
  }
  self.add(2)
  for c in text.iter() {
    let code = c.to_int()
    self.add(
      if code < 32 {
        6
      } else if c == '"' || c == '\\' || c == '/' {
        2
      } else if code > 65535 {
        2
      } else {
        1
      },
    )
  }
}

///|
// Walk one child at a time. Stack space depends on nesting, not array width.
// Shared subtrees are counted once per occurrence, exactly as JSON output
// expands them; cycles supplied by callers hit the depth limit as well.
fn measure_json(
  value : Json,
  pretty : Bool,
  initial_depth? : Int = 0,
) -> JsonBudget raise JmesPathError {
  let budget = { nodes: 0, units: 0, }
  let stack : Array[JsonFrame] = [Value(value, initial_depth)]
  while !stack.is_empty() {
    guard stack.pop() is Some(frame) else { break }
    match frame {
      Value(value, depth) => {
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
        match value {
          Array(items) => {
            budget.add(2)
            if pretty {
              budget.add(2 * depth + 2)
            }
            stack.push(Items(items.iter(), depth + 1))
          }
          Object(entries) => {
            budget.add(2)
            if pretty {
              budget.add(2 * depth + 2)
            }
            stack.push(Members(entries.iter(), depth + 1))
          }
          String(text) => budget.string(text)
          Number(number, repr~) => {
            if number.is_nan() || number.is_inf() {
              fail(
                "invalid_value", 0, "non-finite numbers cannot be represented as JSON",
              )
            }
            budget.add(
              match repr {
                Some(text) => text.length()
                None => 32
              },
            )
          }
          _ => budget.add(5)
        }
      }
      Items(items, depth) =>
        match items.next() {
          None => ()
          Some(item) => {
            budget.add(1)
            stack.push(Items(items, depth))
            stack.push(Value(item, depth))
          }
        }
      Members(entries, depth) =>
        match entries.next() {
          None => ()
          Some((key, item)) => {
            budget.string(key)
            budget.add(3)
            stack.push(Members(entries, depth))
            stack.push(Value(item, depth))
          }
        }
    }
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
  pretty? : Bool = false,
) -> String raise JmesPathError {
  check_json_size(value, pretty)
  value.stringify(indent=if pretty { 2 } else { 0 })
}
