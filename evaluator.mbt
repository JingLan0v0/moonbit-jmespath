///|
priv struct EvalState {
  limits : Limits
  mut steps : Int
  mut results : Int
  mut depth : Int
}

///|
fn EvalState::tick(self : EvalState) -> Unit raise JmesPathError {
  self.charge(1)
}

///|
fn EvalState::charge(self : EvalState, count : Int) -> Unit raise JmesPathError {
  if count > self.limits.max_steps - self.steps {
    fail("limit_exceeded", 0, "evaluation exceeds max_steps")
  }
  self.steps += count
}

///|
fn EvalState::add_results(
  self : EvalState,
  count : Int,
) -> Unit raise JmesPathError {
  if count > self.limits.max_results - self.results {
    fail("limit_exceeded", 0, "evaluation exceeds max_results")
  }
  self.results += count
}

///|
fn truthy(value : Json) -> Bool {
  match value {
    Null | False | String("") => false
    Array(items) => !items.is_empty()
    Object(entries) => !entries.is_empty()
    _ => true
  }
}

///|
fn json_bool(value : Bool) -> Json {
  Json::boolean(value)
}

///|
fn normalize_positive(value : Int?, length : Int, default : Int) -> Int {
  let mut result = value.unwrap_or(default)
  if result < 0 {
    result += length
  }
  if result < 0 {
    0
  } else if result > length {
    length
  } else {
    result
  }
}

///|
fn slice_array(
  items : Array[Json],
  start : Int?,
  stop : Int?,
  step : Int?,
  state : EvalState,
) -> Array[Json] raise JmesPathError {
  let stride = step.unwrap_or(1)
  if stride == 0 {
    fail("invalid_value", 0, "slice step cannot be zero")
  }
  let length = items.length()
  let result : Array[Json] = []
  if stride > 0 {
    let first = normalize_positive(start, length, 0)
    let last = normalize_positive(stop, length, length)
    let mut i = first
    while i < last {
      state.add_results(1)
      result.push(items[i])
      if stride > last - 1 - i {
        break
      }
      i += stride
    }
  } else {
    let mut first = match start {
      None => length - 1
      Some(value) => if value < 0 { value + length } else { value }
    }
    let last = match stop {
      None => -1
      Some(value) => if value < 0 { value + length } else { value }
    }
    if first >= length {
      first = length - 1
    }
    if first < -1 {
      first = -1
    }
    let mut end = last
    if end >= length {
      end = length - 1
    }
    if end < -1 {
      end = -1
    }
    let mut i = first
    while i > end {
      state.add_results(1)
      result.push(items[i])
      i += stride
    }
  }
  result
}

///|
fn relation(
  op : CompareOp,
  left : Json,
  right : Json,
  state : EvalState,
) -> Json raise JmesPathError {
  match op {
    Eq => json_bool(json_equal(left, right, state))
    Ne => json_bool(!json_equal(left, right, state))
    Lt | Le | Gt | Ge =>
      match (left, right) {
        (Number(a, ..), Number(b, ..)) =>
          json_bool(
            match op {
              Lt => a < b
              Le => a <= b
              Gt => a > b
              Ge => a >= b
              _ => false
            },
          )
        _ => Json::null()
      }
  }
}

///|
fn evaluate(
  expr : Expr,
  data : Json,
  state : EvalState,
) -> Json raise JmesPathError {
  // An AST node can use several runtime frames (function arguments and
  // expression references in particular). Bound execution before descending.
  if state.depth >= 128 {
    fail("limit_exceeded", 0, "evaluation exceeds call depth 128")
  }
  state.tick()
  state.depth += 1
  let result = match expr {
    Current => data
    Field(name) =>
      match data {
        Object(entries) => entries.get(name).unwrap_or(Json::null())
        _ => Json::null()
      }
    Literal(value) => value
    Subexpression(left, right) => {
      let value = evaluate(left, data, state)
      if value is Null {
        Json::null()
      } else {
        evaluate(right, value, state)
      }
    }
    Index(base, index) =>
      match evaluate(base, data, state) {
        Array(items) => {
          let resolved = if index < 0 { items.length() + index } else { index }
          if resolved < 0 || resolved >= items.length() {
            Json::null()
          } else {
            items[resolved]
          }
        }
        _ => Json::null()
      }
    Slice(base, start, stop, step) =>
      match evaluate(base, data, state) {
        Array(items) =>
          Json::array(slice_array(items, start, stop, step, state))
        _ => Json::null()
      }
    ListWildcard(base) =>
      match evaluate(base, data, state) {
        Array(items) => Json::array(items)
        _ => Json::null()
      }
    ObjectWildcard(base) =>
      match evaluate(base, data, state) {
        Object(entries) => {
          let values : Array[Json] = []
          for entry in entries {
            let (_, value) = entry
            state.add_results(1)
            values.push(value)
          }
          Json::array(values)
        }
        _ => Json::null()
      }
    Flatten(base) =>
      match evaluate(base, data, state) {
        Array(items) => {
          let flattened : Array[Json] = []
          for item in items {
            match item {
              Array(children) =>
                for child in children {
                  state.add_results(1)
                  flattened.push(child)
                }
              _ => {
                state.add_results(1)
                flattened.push(item)
              }
            }
          }
          Json::array(flattened)
        }
        _ => Json::null()
      }
    Projection(source, rhs) =>
      match evaluate(source, data, state) {
        Array(items) => {
          let projected : Array[Json] = []
          for item in items {
            let value = evaluate(rhs, item, state)
            if !(value is Null) {
              state.add_results(1)
              projected.push(value)
            }
          }
          Json::array(projected)
        }
        _ => Json::null()
      }
    Filter(source, condition) =>
      match evaluate(source, data, state) {
        Array(items) => {
          let selected : Array[Json] = []
          for item in items {
            if truthy(evaluate(condition, item, state)) {
              state.add_results(1)
              selected.push(item)
            }
          }
          Json::array(selected)
        }
        _ => Json::null()
      }
    Pipe(left, right) => evaluate(right, evaluate(left, data, state), state)
    Or(left, right) => {
      let value = evaluate(left, data, state)
      if truthy(value) {
        value
      } else {
        evaluate(right, data, state)
      }
    }
    And(left, right) => {
      let value = evaluate(left, data, state)
      if truthy(value) {
        evaluate(right, data, state)
      } else {
        value
      }
    }
    Not(value) => json_bool(!truthy(evaluate(value, data, state)))
    Compare(op, left, right) =>
      relation(
        op,
        evaluate(left, data, state),
        evaluate(right, data, state),
        state,
      )
    MultiList(items) => {
      let values : Array[Json] = []
      for item in items {
        let value = evaluate(item, data, state)
        state.add_results(1)
        values.push(value)
      }
      Json::array(values)
    }
    MultiHash(entries) => {
      let values : Map[String, Json] = Map([])
      for entry in entries {
        let (key, item) = entry
        if !values.contains(key) {
          state.add_results(1)
        }
        values[key] = evaluate(item, data, state)
      }
      Json::object(values)
    }
    Function(name, args) => evaluate_function(name, args, data, state)
    ExpressionRef(_) =>
      fail(
        "invalid_type", 0, "expression references are only valid as function arguments",
      )
  }
  state.depth -= 1
  result
}
