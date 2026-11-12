import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { isDeepStrictEqual } from 'node:util';
import { runDemo } from '../examples/demo.mjs';
import { runConformanceCheck } from './lib/conformance-report.mjs';
import { writeJsonAtomically } from './lib/write-json.mjs';

const root = path.resolve(import.meta.dirname, '..');
const moon = process.env.MOON_BIN || 'moon';
const buildDir = path.join(root, '_build');
const summaryPath = path.join(buildDir, 'verification-summary.json');
const modes = ['debug', 'release'];

function run(command, args, options = {}) {
  const result = spawnSync(command, args, { cwd: root, encoding: 'utf8', timeout: 120000, ...options });
  if (result.error) {
    const excerpts = [];
    for (const stream of ['stdout', 'stderr']) {
      const tail = result[stream]?.trim().slice(-1200);
      if (tail) excerpts.push(stream + ': ' + tail);
    }
    const diagnostic = [result.error.message, ...excerpts].join('\n');
    throw new Error(diagnostic, { cause: result.error });
  }
  if (result.status !== 0) {
    process.stderr.write(result.stdout || '');
    process.stderr.write(result.stderr || '');
    const diagnostic = (result.stderr || result.stdout || '').trim().slice(-1200);
    const error = new Error(`${command} ${args.join(' ')} failed (${result.status ?? result.signal})${diagnostic ? ': ' + diagnostic : ''}`);
    error.exitCode = result.status;
    throw error;
  }
  return result.stdout;
}

function runEquality(env, release = false) {
  const output = run(process.execPath, ['scripts/equality-properties.mjs', ...(release ? ['--release'] : [])], { env });
  process.stdout.write(output);
  const marker = 'EQUALITY_SUMMARY ';
  const lines = output.split(/\r?\n/).filter(line => line.startsWith(marker));
  if (lines.length !== 1) throw new Error('Missing or duplicate equality summary');
  const counts = JSON.parse(lines[0].slice(marker.length));
  if (!Number.isSafeInteger(counts.pairs) || counts.pairs <= 0 ||
      !Number.isSafeInteger(counts.queries) || counts.queries !== counts.pairs * 5) {
    throw new Error('Invalid equality counts');
  }
  return counts;
}

function runComposition(env, release = false) {
  const output = run(process.execPath, ['scripts/composition-properties.mjs', ...(release ? ['--release'] : [])], { env });
  process.stdout.write(output);
  const marker = 'COMPOSITION_SUMMARY ';
  const lines = output.split(/\r?\n/).filter(line => line.startsWith(marker));
  if (lines.length !== 1) throw new Error('Missing or duplicate composition summary');
  const counts = JSON.parse(lines[0].slice(marker.length));
  const coverage = Object.values(counts.coverage || {});
  if (counts.generatedQueries !== 8192 || counts.normativeQueries !== 15 ||
      counts.queries !== counts.generatedQueries + counts.normativeQueries ||
      !Number.isSafeInteger(counts.expressions) || counts.expressions < 1 || counts.expressions > 512 ||
      counts.seed !== 0x20261111 || !/^[a-f0-9]{64}$/.test(counts.corpusHash) ||
      coverage.length !== 14 || coverage.some(n => !Number.isSafeInteger(n) || n <= 0) ||
      coverage.reduce((a, b) => a + b, 0) !== counts.generatedQueries) {
    throw new Error('Invalid composition coverage');
  }
  return counts;
}

function runAdversarial(env) {
  const output = run(process.execPath, ['scripts/adversarial.mjs'], { env });
  process.stdout.write(output);
  const marker = 'ADVERSARIAL_SUMMARY ';
  const summaries = output.split(/\r?\n/).filter(line => line.startsWith(marker));
  if (summaries.length !== 1) throw new Error('Missing or duplicate adversarial summary');
  const counts = JSON.parse(summaries[0].slice(marker.length));
  if (!Number.isSafeInteger(counts.checks) || counts.checks <= 0 ||
      !Number.isSafeInteger(counts.mutations) || counts.mutations <= 0) {
    throw new Error('Invalid adversarial counts');
  }
  return counts;
}

const steps = [];
function add(id, mode, check, { applicable = true, networkAware = false } = {}) {
  steps.push({ receipt: { id, mode, status: applicable ? 'not_run' : 'not_applicable' }, check, networkAware });
}
const report = {
  schemaVersion: 2,
  status: 'running',
  source: null,
  ciCommit: process.env.GITHUB_SHA || null,
  platform: process.platform,
  node: process.version,
  toolchain: null,
  target: 'js',
  modes,
  startedAt: new Date().toISOString(),
};

// Retire evidence from the preceding run even when Git validation fails.
add('prepare-reports', null, () => {
  for (const mode of modes) {
    for (const suite of ['conformance', 'equality', 'composition']) {
      fs.rmSync(path.join(buildDir, `${suite}-${mode}-summary.json`), { force: true });
    }
    for (const suite of ['equality', 'composition']) {
      fs.rmSync(path.join(buildDir, `${suite}-${mode}-failure.json`), { force: true });
    }
  }
  fs.rmSync(path.join(buildDir, 'moon-version.txt'), { force: true });
});
add('source', null, () => {
  if (run('git', ['rev-parse', '--show-prefix']).trim()) {
    throw new Error('Run full verification from a MoonJMES Git checkout');
  }
  report.source = {
    sha: run('git', ['rev-parse', 'HEAD']).trim(),
    dirty: run('git', ['status', '--porcelain', '--untracked-files=normal']).trim() !== '',
  };
});
add('toolchain', null, () => {
  report.toolchain = run(moon, ['version', '--all']).trim();
  if (!report.toolchain) throw new Error('Missing MoonBit version information');
  fs.writeFileSync(path.join(buildDir, 'moon-version.txt'), report.toolchain + '\n');
  console.log(report.toolchain);
});
add('format', null, () => run(moon, ['fmt', '--check']));
add('check', null, () => run(moon, ['check', '--target', 'js', '--deny-warn']));
add('interfaces', null, () => {
  run(moon, ['info', '--target', 'js']);
  run('git', ['diff', '--exit-code', '--', '*.mbti']);
  const untracked = run('git', ['ls-files', '--others', '--exclude-standard', '--', '*.mbti']).trim();
  if (untracked) throw new Error('Untracked generated interfaces: ' + untracked);
});

const artifacts = Object.fromEntries(modes.map(mode => [
  mode, path.join(buildDir, 'js', mode, 'build', 'cmd', 'main', 'main.js'),
]));
const coverage = {};
function testCounts(output, totalPattern, passedPattern) {
  const total = Number(output.match(totalPattern)?.[1]);
  const passed = Number(output.match(passedPattern)?.[1]);
  if (!Number.isSafeInteger(total) || total <= 0 || passed !== total) {
    throw new Error('Missing test counts or some tests did not pass');
  }
  return { total, passed };
}

for (const mode of modes) {
  const release = mode === 'release';
  const flags = release ? ['--release'] : [];
  const cli = artifacts[mode];
  // Always test the artifact built for this mode, even with an inherited override.
  const env = { ...process.env, JMES_CLI_PATH: cli, JMES_REDUCER_TEST_MODE: mode };
  function runHarness(script) {
    const output = run(process.execPath, [`scripts/${script}.mjs`], { env });
    process.stdout.write(output);
    return output;
  }
  add('unit', mode, () => {
    const output = run(moon, ['test', '--target', 'js', '--deny-warn', ...flags]);
    process.stdout.write(output);
    return testCounts(output, /Total tests: (\d+)/, /passed: (\d+)/);
  });
  add('public-api', mode, () => {
    const output = run(moon, ['run', 'examples/library', '--target', 'js', ...flags]);
    if (output.trim().replaceAll('\r', '') !== '["Ada"]\n[]\nerror: invalid_type') {
      throw new Error(`Public API example mismatch: ${output}`);
    }
    return { examples: 1 };
  });
  add('build-cli', mode, () => {
    run(moon, ['build', 'cmd/main', '--target', 'js', ...flags]);
    return { artifact: path.relative(root, cli) };
  });
  add('scenarios', mode, () => runDemo(cli));
  add('cli', mode, () => {
    const output = runHarness('cli-integration');
    const groupingCases = Number(output.match(/PASS projection grouping and unary precedence: (\d+) cases/)?.[1]);
    if (!Number.isSafeInteger(groupingCases) || groupingCases <= 0) throw new Error('Missing CLI grouping count');
    return { groupingCases };
  });
  add('json-roundtrip', mode, () => {
    const output = runHarness('json-roundtrip');
    const counts = {};
    for (const format of ['compact', 'pretty']) {
      const match = output.match(new RegExp(`PASS JSON roundtrip ${format}: (\\d+) key/escape cases and duplicate JSON key case passed`));
      const queries = Number(match?.[1]);
      if (!Number.isSafeInteger(queries) || queries <= 0) throw new Error(`Missing ${format} roundtrip count`);
      counts[format] = { queries, duplicateKeyCases: 1 };
    }
    return counts;
  });
  add('adversarial', mode, () => (coverage[mode] = { adversarial: runAdversarial(env) }).adversarial);
  add('failure-reducer', mode, () => {
    const output = run(process.execPath, ['--test', '--test-reporter=tap', 'scripts/minimize-failure.test.mjs'], { env });
    process.stdout.write(output);
    return testCounts(output, /^# tests (\d+)$/m, /^# pass (\d+)$/m);
  });
  add('equality', mode, () => (coverage[mode].equality = runEquality(env, release)));
  add('composition', mode, () => (coverage[mode].composition = runComposition(env, release)));
}
add('compare-coverage', null, () => {
  if (!isDeepStrictEqual(coverage.debug, coverage.release)) {
    throw new Error('Debug and release exercised different property-test coverage');
  }
});
add('powershell', 'debug', () => {
  process.stdout.write(run('pwsh', ['-NoProfile', '-File', 'scripts/powershell-smoke.ps1'], {
    env: { ...process.env, MOON_BIN: moon },
  }));
}, { applicable: process.platform === 'win32' });

for (const mode of modes) {
  add('conformance', mode, () => runConformanceCheck(run, {
    mode, artifact: artifacts[mode],
    reportPath: path.join(buildDir, `conformance-${mode}-summary.json`),
  }), { networkAware: true });
}

report.steps = steps.map(step => step.receipt);
function writeReport() {
  writeJsonAtomically(summaryPath, report);
}
fs.mkdirSync(buildDir, { recursive: true });
writeReport();
for (const { receipt, check, networkAware } of steps) {
  if (receipt.status === 'not_applicable') continue;
  receipt.status = 'running';
  receipt.startedAt = new Date().toISOString();
  writeReport();
  const label = receipt.mode ? `${receipt.id} (${receipt.mode})` : receipt.id;
  try {
    const details = check();
    if (details && typeof details === 'object') receipt.details = details;
    receipt.status = 'passed';
    console.log(`PASS ${label}`);
  } catch (error) {
    receipt.status = networkAware && error.exitCode === 3 ? 'network_blocked' : 'failed';
    receipt.error = error.message;
    if (error.details) receipt.details = error.details;
    report.status = receipt.status;
    process.exitCode = receipt.status === 'network_blocked' ? 3 : 1;
    console.error(`${receipt.status}: ${label}: ${error.message}`);
  } finally {
    receipt.finishedAt = new Date().toISOString();
    writeReport();
  }
  if (process.exitCode) break;
}
if (report.status === 'running') report.status = 'passed';
report.finishedAt = new Date().toISOString();
writeReport();
console.log(`Verification ${report.status}: ${summaryPath}`);
