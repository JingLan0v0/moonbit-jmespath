import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';

export function describeBuiltArtifact(root, filename, label) {
  const artifact = path.relative(root, filename);
  const file = fs.lstatSync(filename, { throwIfNoEntry: false });
  if (!file?.isFile() || file.size === 0) {
    throw new Error(`Build did not produce a nonempty ${label} artifact at ${artifact}`);
  }
  const sha256 = createHash('sha256').update(fs.readFileSync(filename)).digest('hex');
  return { artifact, sha256 };
}
