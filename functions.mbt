///|
fn require_arity(
  name : String,
  actual : Int,
  expected : Int,
) -> Unit raise JmesPathError {
  if actual != expected {
    fail(
      "invalid_arity",
      0,
      "\{name} expects \{expected} argument(s), got \{actual}",
    )
  }
}

///|
fn require_min_arity(
  name : String,
  actual : Int,
  minimum : Int,
) -> Unit raise JmesPathError {
  if actual < minimum {
    fail(
      "invalid_arity",
      0,
      "\{name} expects at least \{minimum} argument(s), got \{actual}",
    )
  }
}

///|
fn[T] invalid_type(name : String) -> T raise JmesPathError {
  fail("invalid_type", 0, "invalid argument type for " + name)
}

///|
fn evaluate_args(
  args : Array[Expr],
  data : Json,
  state : EvalState,
) -> Array[Json] raise JmesPathError {
  args.map(arg => evaluate(arg, data, state))
}

///|
fn homogeneous_order(
  values : Array[Json],
  name : String,
) -> Int raise JmesPathError {
  if values.is_empty() {
    return 0
  }
  match values[0] {
    Number(_, ..) => {
      for value in values {
        if !(value is Number(_, ..)) {
          invalid_type(name) |> ignore
        }
      }
      1
    }
    String(_) => {
      for value in values {
        if !(value is String(_)) {
          invalid_type(name) |> ignore
        }
      }
      2
    }
    _ => invalid_type(name)
  }
}

///|
fn compare_ordered(left : Json, right : Json, kind : Int) -> Int {
  if kind == 1 {
    guard left is Number(a, ..) && right is Number(b, ..) else { return 0 }
    if a < b {
      -1
    } else if a > b {
      1
    } else {
      0
    }
  } else {
    guard left is String(a) && right is String(b) else { return 0 }
    a.lexical_compare(b)
  }
}

///|
fn function_length(value : Json) -> Json raise JmesPathError {
  match value {
    String(text) => Json::number(text.to_array().length().to_double())
    Array(items) => Json::number(items.length().to_double())
    Object(entries) => Json::number(entries.length().to_double())
    _ => invalid_type("length")
  }
}

///|
fn function_contains(subject : Json, search : Json) -> Json raise JmesPathError {
  match subject {
    String(text) =>
      match search {
        String(needle) => Json::boolean(text.contains(needle))
        _ => invalid_type("contains")
      }
    Array(items) => Json::boolean(items.any(fn(item) { item == search }))
    _ => invalid_type("contains")
  }
}

///|
fn function_numeric_array(
  name : String,
  value : Json,
  average : Bool,
) -> Json raise JmesPathError {
  guard value is Array(items) else { return invalid_type(name) }
  let mut total = 0.0
  for item in items {
    guard item is Number(number, ..) else { return invalid_type(name) }
    total += number
  }
  if average {
    if items.is_empty() {
      Json::null()
    } else {
      Json::number(total / items.length().to_double())
    }
  } else {
    Json::number(total)
  }
}

///|
fn function_extreme(
  name : String,
  value : Json,
  maximum : Bool,
) -> Json raise JmesPathError {
  guard value is Array(items) else { return invalid_type(name) }
  if items.is_empty() {
    return Json::null()
  }
  let kind = homogeneous_order(items, name)
  let mut best = items[0]
  for i = 1; i < items.length(); i = i + 1 {
    let order = compare_ordered(items[i], best, kind)
    if (maximum && order > 0) || (!maximum && order < 0) {
      best = items[i]
    }
  }
  best
}

///|
fn function_sort(value : Json) -> Json raise JmesPathError {
  guard value is Array(items) else { return invalid_type("sort") }
  let result = items.copy()
  let kind = homogeneous_order(result, "sort")
  if kind != 0 {
    result.sort_by(fn(a, b) { compare_ordered(a, b, kind) })
  }
  Json::array(result)
}

///|
fn json_type(value : Json) -> String {
  match value {
    Null => "null"
    True | False => "boolean"
    Number(_, ..) => "number"
    String(_) => "string"
    Array(_) => "array"
    Object(_) => "object"
  }
}

///|
fn evaluate_expref_function(
  name : String,
  args : Array[Expr],
  data : Json,
  state : EvalState,
) -> Json raise JmesPathError {
  require_arity(name, args.length(), 2)
  let (array_expr, reference) = if name == "map" {
    guard args[0] is ExpressionRef(reference) else { return invalid_type(name) }
    (args[1], reference)
  } else {
    guard args[1] is ExpressionRef(reference) else { return invalid_type(name) }
    (args[0], reference)
  }
  guard evaluate(array_expr, data, state) is Array(items) else {
    return invalid_type(name)
  }
  if name == "map" {
    let mapped = items.map(item => evaluate(reference, item, state))
    state.add_results(mapped.length())
    return Json::array(mapped)
  }
  if items.is_empty() {
    return if name == "sort_by" { Json::array([]) } else { Json::null() }
  }
  let pairs : Array[(Json, Json)] = []
  for item in items {
    pairs.push((item, evaluate(reference, item, state)))
  }
  let keys = pairs.map(pair => pair.1)
  let kind = homogeneous_order(keys, name)
  if name == "sort_by" {
    pairs.sort_by(fn(a, b) { compare_ordered(a.1, b.1, kind) })
    return Json::array(pairs.map(pair => pair.0))
  }
  let maximum = name == "max_by"
  let mut best = pairs[0]
  for i = 1; i < pairs.length(); i = i + 1 {
    let order = compare_ordered(pairs[i].1, best.1, kind)
    if (maximum && order > 0) || (!maximum && order < 0) {
      best = pairs[i]
    }
  }
  best.0
}

///|
fn evaluate_function(
  name : String,
  args : Array[Expr],
  data : Json,
  state : EvalState,
) -> Json raise JmesPathError {
  if name == "map" || name == "sort_by" || name == "max_by" || name == "min_by" {
    return evaluate_expref_function(name, args, data, state)
  }
  let values = evaluate_args(args, data, state)
  match name {
    "abs" => {
      require_arity(name, values.length(), 1)
      guard values[0] is Number(value, ..) else { return invalid_type(name) }
      Json::number(value.abs())
    }
    "avg" => {
      require_arity(name, values.length(), 1)
      function_numeric_array(name, values[0], true)
    }
    "ceil" => {
      require_arity(name, values.length(), 1)
      guard values[0] is Number(value, ..) else { return invalid_type(name) }
      Json::number(value.ceil())
    }
    "contains" => {
      require_arity(name, values.length(), 2)
      function_contains(values[0], values[1])
    }
    "ends_with" => {
      require_arity(name, values.length(), 2)
      guard values[0] is String(subject) && values[1] is String(suffix) else {
        return invalid_type(name)
      }
      Json::boolean(subject.has_suffix(suffix))
    }
    "floor" => {
      require_arity(name, values.length(), 1)
      guard values[0] is Number(value, ..) else { return invalid_type(name) }
      Json::number(value.floor())
    }
    "join" => {
      require_arity(name, values.length(), 2)
      guard values[0] is String(separator) && values[1] is Array(items) else {
        return invalid_type(name)
      }
      let strings : Array[String] = []
      for item in items {
        guard item is String(text) else { return invalid_type(name) }
        strings.push(text)
      }
      Json::string(strings.join(separator))
    }
    "keys" => {
      require_arity(name, values.length(), 1)
      guard values[0] is Object(entries) else { return invalid_type(name) }
      let keys : Array[Json] = []
      for entry in entries {
        keys.push(Json::string(entry.0))
      }
      Json::array(keys)
    }
    "length" => {
      require_arity(name, values.length(), 1)
      function_length(values[0])
    }
    "max" => {
      require_arity(name, values.length(), 1)
      function_extreme(name, values[0], true)
    }
    "merge" => {
      require_min_arity(name, values.length(), 1)
      let result : Map[String, Json] = Map([])
      for value in values {
        guard value is Object(entries) else { return invalid_type(name) }
        for entry in entries {
          result[entry.0] = entry.1
        }
      }
      Json::object(result)
    }
    "min" => {
      require_arity(name, values.length(), 1)
      function_extreme(name, values[0], false)
    }
    "not_null" => {
      require_min_arity(name, values.length(), 1)
      for value in values {
        if !(value is Null) {
          return value
        }
      }
      Json::null()
    }
    "reverse" => {
      require_arity(name, values.length(), 1)
      match values[0] {
        Array(items) => Json::array(items.rev())
        String(text) => Json::string(String::from_array(text.to_array().rev()))
        _ => invalid_type(name)
      }
    }
    "sort" => {
      require_arity(name, values.length(), 1)
      function_sort(values[0])
    }
    "starts_with" => {
      require_arity(name, values.length(), 2)
      guard values[0] is String(subject) && values[1] is String(prefix) else {
        return invalid_type(name)
      }
      Json::boolean(subject.has_prefix(prefix))
    }
    "sum" => {
      require_arity(name, values.length(), 1)
      function_numeric_array(name, values[0], false)
    }
    "to_array" => {
      require_arity(name, values.length(), 1)
      match values[0] {
        Array(_) => values[0]
        value => Json::array([value])
      }
    }
    "to_number" => {
      require_arity(name, values.length(), 1)
      match values[0] {
        Number(_, ..) => values[0]
        String(text) => {
          let parsed = @json.parse(text) catch { _ => return Json::null() }
          if parsed is Number(_, ..) {
            parsed
          } else {
            Json::null()
          }
        }
        _ => Json::null()
      }
    }
    "to_string" => {
      require_arity(name, values.length(), 1)
      match values[0] {
        String(_) => values[0]
        value => Json::string(value.stringify())
      }
    }
    "type" => {
      require_arity(name, values.length(), 1)
      Json::string(json_type(values[0]))
    }
    "values" => {
      require_arity(name, values.length(), 1)
      guard values[0] is Object(entries) else { return invalid_type(name) }
      let result : Array[Json] = []
      for entry in entries {
        result.push(entry.1)
      }
      Json::array(result)
    }
    _ => fail("unknown_function", 0, "unknown function: " + name)
  }
}
