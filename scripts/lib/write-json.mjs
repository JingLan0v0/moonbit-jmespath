import fs from 'node:fs';
import { randomUUID } from 'node:crypto';

export function writeJsonAtomically(destination, value) {
  const json = JSON.stringify(value, null, 2) + '\n';
  const temporary = `${destination}.${randomUUID()}.tmp`;
  try {
    fs.writeFileSync(temporary, json);
    fs.renameSync(temporary, destination);
  } catch (error) {
    try {
      fs.rmSync(temporary, { force: true });
    } catch (cleanupError) {
      throw new AggregateError([error, cleanupError],
        `Cannot write ${destination}: ${error.message}; temporary file cleanup failed: ${cleanupError.message}`);
    }
    throw error;
  }
}
