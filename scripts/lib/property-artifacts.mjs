import fs from 'node:fs';
import path from 'node:path';

export function propertyArtifactPaths(root, suite, mode, replayPath) {
  const stem = `${suite}-${mode}`;
  const build = path.join(root, '_build');
  const parent = replayPath ? path.join(build, 'replays') : build;
  fs.mkdirSync(parent, { recursive: true });
  const directory = replayPath ? fs.mkdtempSync(path.join(parent, stem + '-')) : parent;
  return {
    report: path.join(directory, stem + '-summary.json'),
    failure: path.join(directory, stem + '-failure.json'),
  };
}
