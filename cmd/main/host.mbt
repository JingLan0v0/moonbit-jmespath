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
  #|    const fd = path === '-' ? 0 : fs.openSync(path, 'r');
  #|    const chunks = [];
  #|    const buffer = Buffer.allocUnsafe(64 * 1024);
  #|    let size = 0;
  #|    try {
  #|      while (size <= limit) {
  #|        const read = fs.readSync(fd, buffer, 0, Math.min(buffer.length, limit + 1 - size), null);
  #|        if (read === 0) break;
  #|        size += read;
  #|        if (size > limit) return ['input exceeds 16 MiB', ''];
  #|        chunks.push(Buffer.from(buffer.subarray(0, read)));
  #|      }
  #|    } finally {
  #|      if (path !== '-') fs.closeSync(fd);
  #|    }
  #|    const data = Buffer.concat(chunks, size);
  #|    const text = new TextDecoder('utf-8', { fatal: true }).decode(data);
  #|    return ['', text];
  #|  } catch (error) {
  #|    return [String(error.code || error.message || 'read failed'), ''];
  #|  }
  #|}
