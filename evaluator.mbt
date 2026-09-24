///|
priv struct EvalState {
  limits : Limits
  mut steps : Int
  mut results : Int
}

///|
fn EvalState::tick(self : EvalState) -> Unit raise JmesPathError {
  self.steps += 1
  if self.steps > self.limits.max_steps {
    fail("limit_exceeded", 0, "evaluation exceeds max_steps")
  }
}

///|
fn EvalState::add_results(
  self : EvalState,
  count : Int,
) -> Unit raise JmesPathError {
  self.results += count
  if self.results > self.limits.max_results {
    fail("limit_exceeded", 0, "evaluation exceeds max_results")
  }
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
fn normalize_positive(value : Int, length : Int, default : Int) -> Int {
  let mut result = value
  if value == 2147483647 {
    result = default
  }
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
) -> Array[Json] raise JmesPathError {
  let stride = step.unwrap_or(1)
  if stride == 0 {
    fail("invalid_value", 0, "slice step cannot be zero")
  }
  let length = items.length()
  let result : Array[Json] = []
  if stride > 0 {
    let first = normalize_positive(start.unwrap_or(2147483647), length, 0)
    let last = normalize_positive(stop.unwrap_or(2147483647), length, length)
    let mut i = first
    while i < last {
      result.push(items[i])
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
      result.push(items[i])
      i += stride
    }
  }
  result
}

///|
fn relation(op : CompareOp, left : Json, right : Json) -> Json {
  match op {
    Eq => json_bool(left == right)
    Ne => json_bool(left != right)
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
  state.tick()
  match expr {
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
        Array(items) => Json::array(slice_array(items, start, stop, step))
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
                  flattened.push(child)
                }
              _ => flattened.push(item)
            }
          }
          state.add_results(flattened.length())
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
              projected.push(value)
            }
          }
          state.add_results(projected.length())
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
              selected.push(item)
            }
          }
          state.add_results(selected.length())
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
      relation(op, evaluate(left, data, state), evaluate(right, data, state))
    MultiList(items) => {
      let values = items.map(item => evaluate(item, data, state))
      state.add_results(values.length())
      Json::array(values)
    }
    MultiHash(entries) => {
      let values : Map[String, Json] = Map([])
      for entry in entries {
        let (key, item) = entry
        values[key] = evaluate(item, data, state)
      }
      state.add_results(values.length())
      Json::object(values)
    }
    Function(name, args) => evaluate_function(name, args, data, state)
    ExpressionRef(_) =>
      fail(
        "invalid_type", 0, "expression references are only valid as function arguments",
      )
  }
}
