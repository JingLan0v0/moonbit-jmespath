///|
priv enum EqualityFrame {
  Pair(Json, Json)
  Arrays(Array[Json], Array[Json], Int)
  Objects(Iter[(String, Json)], Map[String, Json])
}

///|
// Explicit depth-first traversal charges repeated references to the query's
// work budget and never puts JSON nesting on the runtime call stack.
fn json_equal(
  left : Json,
  right : Json,
  state : EvalState,
) -> Bool raise JmesPathError {
  let stack : Array[EqualityFrame] = [Pair(left, right)]
  while !stack.is_empty() {
    guard stack.pop() is Some(frame) else { break }
    match frame {
      Pair(a, b) => {
        state.tick()
        match (a, b) {
          (Null, Null) | (True, True) | (False, False) => ()
          (Number(x, ..), Number(y, ..)) => if x != y { return false }
          (String(x), String(y)) => {
            state.charge(Int::max(x.length(), y.length()))
            if x != y {
              return false
            }
          }
          (Array(x), Array(y)) => {
            if x.length() != y.length() {
              return false
            }
            stack.push(Arrays(x, y, 0))
          }
          (Object(x), Object(y)) => {
            if x.length() != y.length() {
              return false
            }
            stack.push(Objects(x.iter(), y))
          }
          _ => return false
        }
      }
      Arrays(a, b, i) =>
        if i < a.length() {
          stack.push(Arrays(a, b, i + 1))
          stack.push(Pair(a[i], b[i]))
        }
      Objects(entries, other) =>
        match entries.next() {
          None => ()
          Some((key, value)) => {
            state.charge(key.length())
            guard other.get(key) is Some(other_value) else { return false }
            stack.push(Objects(entries, other))
            stack.push(Pair(value, other_value))
          }
        }
    }
  }
  true
}
