///|
// Stable bottom-up merge sort allows the comparator to raise a budget error.
// Core Array::sort_by's comparator cannot raise on this pinned toolchain.
fn[T] bounded_sort(
  items : Array[T],
  compare : (T, T) -> Int raise JmesPathError,
  state : EvalState,
) -> Array[T] raise JmesPathError {
  let length = items.length()
  state.charge(length * 2)
  let mut source = items.copy()
  let mut target = items.copy()
  let mut width = 1
  while width < length {
    let mut start = 0
    while start < length {
      let middle = (start + width).min(length)
      let end = (middle + width).min(length)
      let mut left = start
      let mut right = middle
      for output in start..<end {
        state.tick()
        if left < middle &&
          (right >= end || compare(source[left], source[right]) <= 0) {
          target[output] = source[left]
          left += 1
        } else {
          target[output] = source[right]
          right += 1
        }
      }
      start = end
    }
    let previous = source
    source = target
    target = previous
    width *= 2
  }
  source
}
