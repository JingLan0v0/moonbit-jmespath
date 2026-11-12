///|
extern "js" fn selected_case() -> String =
  #|() => process.env.MOONJMES_BENCH_CASE ?? ""

///|
extern "js" fn clock_ms() -> Double =
  #|() => performance.now()

///|
extern "js" fn peak_rss_kib() -> Double =
  #|() => process.resourceUsage().maxRSS

///|
priv struct BenchCase {
  input_size : Int32
  input_unit : String
  iterations : Int32
  expected : Int32
  run : () -> Int32 raise
}

///|
let case_names : Array[String] = [
  "compile-small", "compile-large", "compiled-filter", "sort-large", "long-string",
  "serialize-large", "compile-batch", "batch-repeated", "batch-distinct", "batch-large",
]

///|
fn array_count(value : Json) -> Int32 {
  guard value is Array(items) else { panic() }
  items.length()
}

///|
fn batch_expression(index : Int32) -> String {
  let padded = "0000" + index.to_string()
  let field = padded[padded.length() - 4:].to_owned()
  "not_null(missing" + field + ", value)"
}

///|
fn make_batch(size : Int32, distinct : Bool) -> BenchCase raise {
  let data = @json.parse("{\"value\":\"ok\"}")
  let requests = Json::array(
    Array::makei(size, i => {
      let index = if distinct { i } else { 0 }
      Json::object(
        Map([
          ("expression", Json::string(batch_expression(index))),
          ("data", data),
        ]),
      )
    }),
  )
  let result = @jmes.search_batch(requests)
  guard result is Array(items) else { fail("expected batch result array") }
  let expected = @json.parse("{\"ok\":true,\"result\":\"ok\"}")
  assert_eq(items.length(), size)
  for item in items {
    assert_eq(item, expected)
  }
  {
    input_size: size,
    input_unit: "requests",
    iterations: if size > 512 {
      1
    } else {
      4
    },
    expected: size,
    run: () => array_count(@jmes.search_batch(requests)),
  }
}

///|
fn make_case(name : String) -> BenchCase raise {
  let filter = "items[?price >= `10`].name"
  match name {
    "compile-small" | "compile-large" => {
      let source = if name == "compile-small" {
        filter
      } else {
        "[" + Array::make(700, "deep_inventory_record").join(",") + "]"
      }
      {
        input_size: source.length(),
        input_unit: "expression UTF-16 units",
        iterations: if name == "compile-small" {
          1000
        } else {
          20
        },
        expected: source.length(),
        run: () => @jmes.compile(source).source().length(),
      }
    }
    "compiled-filter" => {
      let query = @jmes.compile(filter)
      let data = @json.parse(
        "{\"items\":[{\"price\":8,\"name\":\"A\"},{\"price\":12,\"name\":\"B\"},{\"price\":10,\"name\":\"C\"}]}",
      )
      assert_eq(query.search(data), @json.parse("[\"B\",\"C\"]"))
      {
        input_size: 3,
        input_unit: "records",
        iterations: 1000,
        expected: 2,
        run: () => array_count(query.search(data)),
      }
    }
    "sort-large" => {
      let size = 8192
      let query = @jmes.compile("sort(@)")
      let data = Json::array(
        Array::makei(size, i => Json::number((i * 4051 % size).to_double())),
      )
      guard query.search(data) is Array(sorted) else {
        fail("expected sorted array")
      }
      for i in 0..<size {
        assert_eq(sorted[i], Json::number(i.to_double()))
      }
      {
        input_size: size,
        input_unit: "numbers",
        iterations: 4,
        expected: size,
        run: () => array_count(query.search(data)),
      }
    }
    "long-string" => {
      let input = "月😀x".repeat(131072)
      let data = Json::string(input)
      let query = @jmes.compile("length(@)")
      {
        input_size: input.length(),
        input_unit: "string UTF-16 units",
        iterations: 4,
        expected: 393216,
        run: () => {
          guard query.search(data) is Number(length, ..) else { panic() }
          length.to_int()
        },
      }
    }
    "serialize-large" => {
      let size = 60000
      let text = "moonbit-jmespath-data"
      let data = Json::array(Array::make(size, Json::string(text)))
      {
        input_size: size,
        input_unit: "strings",
        iterations: 3,
        expected: size * (text.length() + 3) + 1,
        run: () => @jmes.stringify_bounded(data).length(),
      }
    }
    "compile-batch" => {
      let size = 512
      let source = batch_expression(0)
      {
        input_size: size,
        input_unit: "compilations",
        iterations: 4,
        expected: size * source.length(),
        run: () => {
          let mut units = 0
          for _ in 0..<size {
            units += @jmes.compile(source).source().length()
          }
          units
        },
      }
    }
    "batch-repeated" => make_batch(512, false)
    "batch-distinct" => make_batch(512, true)
    "batch-large" => make_batch(8192, false)
    _ => fail("unknown benchmark case: " + name)
  }
}

///|
fn main raise {
  let name = selected_case()
  if name == "" {
    println(Json::array(case_names.map(Json::string)).stringify())
    return
  }
  let bench = make_case(name)
  let operation = bench.run
  assert_eq(operation(), bench.expected)
  let samples : Array[Json] = []
  let mut checksum = 0
  for sample in 0..<12 {
    let start = clock_ms()
    for _ in 0..<bench.iterations {
      checksum += operation()
    }
    if sample >= 3 {
      samples.push(
        Json::number((clock_ms() - start) / bench.iterations.to_double()),
      )
    }
  }
  assert_eq(checksum, 12 * bench.iterations * bench.expected)
  println(
    Json::object(
      Map([
        ("inputSize", Json::number(bench.input_size.to_double())),
        ("inputUnit", Json::string(bench.input_unit)),
        ("iterationsPerSample", Json::number(bench.iterations.to_double())),
        ("warmupSamples", Json::number(3.0)),
        ("samplesMsPerOperation", Json::array(samples)),
        ("checksum", Json::number(checksum.to_double())),
        ("peakRssKiB", Json::number(peak_rss_kib())),
      ]),
    ).stringify(),
  )
}
