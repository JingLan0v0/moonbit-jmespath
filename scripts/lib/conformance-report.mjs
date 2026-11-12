import fs from 'node:fs';
import path from 'node:path';
import { revision } from './conformance-vectors.mjs';

export function runConformanceCheck(run, { mode, artifact, reportPath }) {
  function readCounts(expectedStatus) {
    try {
      const summary = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
      if (summary?.status !== expectedStatus || summary.mode !== mode || summary.revision !== revision) {
        throw new Error(`Expected status ${expectedStatus}, mode ${mode}, and revision ${revision}`);
      }
      const { total, passed } = summary;
      const hasTotal = Number.isSafeInteger(total) && total >= 0;
      if ((total !== null && !hasTotal) ||
          (passed !== null && (!hasTotal || !Number.isSafeInteger(passed) || passed < 0 || passed > total))) {
        throw new Error('Invalid case counts');
      }
      return { total, passed, revision };
    } catch (error) {
      throw new Error(`Invalid conformance report ${path.basename(reportPath)}: ${error.message}`, { cause: error });
    }
  }

  try {
    process.stdout.write(run(process.execPath, ['scripts/conformance.mjs', '--cli', artifact,
      ...(mode === 'release' ? ['--release'] : [])]));
  } catch (error) {
    try {
      error.details = readCounts(error.exitCode === 3 ? 'network_blocked' : 'failed');
    } catch (reportError) {
      throw new Error(error.message + '\n' + reportError.message, { cause: error });
    }
    throw error;
  }
  const counts = readCounts('passed');
  if (counts.total !== 892 || counts.passed !== counts.total) throw new Error('Invalid conformance counts');
  return counts;
}
