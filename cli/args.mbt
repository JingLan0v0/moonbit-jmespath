///|
pub(all) enum Command {
  Help
  Version
  Query(expression~ : String, path~ : String, compact~ : Bool)
} derive(Eq, Debug)

///|
pub(all) suberror CliError {
  CliError(String)
}

///|
fn usage_error(message : String) -> Unit raise CliError {
  raise CliError(message)
}

///|
pub fn parse_args(args : Array[String]) -> Command raise CliError {
  if args == ["--help"] || args == ["-h"] {
    return Help
  }
  if args == ["--version"] {
    return Version
  }
  let positional : Array[String] = []
  let mut compact = false
  let mut options = true
  for arg in args {
    if options && arg == "--" {
      options = false
    } else if options && arg == "--compact" {
      if compact {
        usage_error("--compact may only appear once")
      }
      compact = true
    } else if options && arg.has_prefix("-") && arg != "-" {
      usage_error("unknown option: " + arg)
    } else {
      positional.push(arg)
    }
  }
  if positional.length() < 1 || positional.length() > 2 {
    usage_error("provide EXPRESSION and optionally FILE")
  }
  Query(
    expression=positional[0],
    path=if positional.length() == 2 { positional[1] } else { "-" },
    compact~,
  )
}

///|
pub fn help() -> String {
  "moon-jmes \{@lib.version()} - query JSON with JMESPath\n\nUsage:\n  moon-jmes [--compact] EXPRESSION [FILE]\n\nArguments:\n  EXPRESSION       JMESPath expression\n  FILE             UTF-8 JSON file; omit or use - for stdin\n\nOptions:\n  --compact        Emit compact JSON instead of indented JSON\n  --help, -h       Show this help\n  --version        Show the version\n\nExit codes: 0 success, 2 invalid expression/input or I/O error.\n"
}
