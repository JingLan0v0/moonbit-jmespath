///|
extern "js" fn arguments() -> FixedArray[String] =
  #|() => process.argv.slice(2)

///|
extern "js" fn write_stdout(text : String) -> Unit =
  #|(text) => process.stdout.write(text)

///|
extern "js" fn write_stderr(text : String) -> Unit =
  #|(text) => process.stderr.write(text)

///|
extern "js" fn set_exit(code : Int) -> Unit =
  #|(code) => { process.exitCode = code; }

///|
extern "js" fn read_utf8(path : String) -> FixedArray[String] =
  #|(path) => {
  #|  const fs = require('node:fs');
  #|  const limit = 16 * 1024 * 1024;
  #|  try {
  #|    const data = path === '-' ? fs.readFileSync(0) : fs.readFileSync(path);
  #|    if (data.length > limit) return ['input exceeds 16 MiB', ''];
  #|    const text = new TextDecoder('utf-8', { fatal: true, ignoreBOM: true }).decode(data);
  #|    return ['', text];
  #|  } catch (error) {
  #|    return [String(error.code || error.message || 'read failed'), ''];
  #|  }
  #|}
