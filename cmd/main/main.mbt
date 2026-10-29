///|
fn render_error(code : String, offset : Int, message : String) -> String {
  "moon-jmes: \{code} at \{offset}: \{message}\n"
}

///|
fn run() -> Int raise {
  let args : Array[String] = []
  for arg in arguments() {
    args.push(arg)
  }
  match @cli.parse_args(args) {
    Help => {
      write_stdout(@cli.help())
      0
    }
    Version => {
      write_stdout(@lib.version() + "\n")
      0
    }
    Query(expression~, path~, compact~) => {
      let read = read_utf8(path)
      if read[0] != "" {
        write_stderr("moon-jmes: io: " + read[0] + "\n")
        return 2
      }
      let result = @lib.search_json(expression, read[1])
      write_stdout(@lib.stringify_bounded(result, pretty=!compact) + "\n")
      0
    }
    Batch(path~, compact~) => {
      let read = read_utf8(path)
      if read[0] != "" {
        write_stderr("moon-jmes: io: " + read[0] + "\n")
        return 2
      }
      let input = @lib.parse_json_bounded(read[1])
      let result = @lib.search_batch(input)
      write_stdout(@lib.stringify_bounded(result, pretty=!compact) + "\n")
      0
    }
  }
}

///|
fn main {
  let code = run() catch {
    @cli.CliError(message) => {
      write_stderr("moon-jmes: usage: " + message + "\n")
      2
    }
    @lib.JmesPathError(diagnostic) => {
      write_stderr(
        render_error(diagnostic.code, diagnostic.offset, diagnostic.message),
      )
      2
    }
    _ => {
      write_stderr("moon-jmes: unexpected error\n")
      2
    }
  }
  set_exit(code)
}
