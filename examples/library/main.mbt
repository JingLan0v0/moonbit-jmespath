///|
fn main raise {
  let limits = { ..@jmespath.default_limits(), max_results: 100, }
  let query = @jmespath.compile("people[?age >= `18`].name", limits~)
  let result = query.search(
    @json.parse("{\"people\":[{\"name\":\"Ada\",\"age\":36}]}"),
  )
  println(@jmespath.stringify_bounded(result))
  // Compiled queries can be reused; each call receives a fresh work budget.
  println(
    @jmespath.stringify_bounded(query.search(@json.parse("{\"people\":[]}"))),
  )
  try @jmespath.search_json("length(@)", "null") |> ignore catch {
    @jmespath.JmesPathError(d) => println("error: " + d.code)
  }
}
