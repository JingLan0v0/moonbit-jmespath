const { spawnSync } = require('node:child_process');

const args = JSON.parse(process.env.MOONJMES_FORWARDED_ARGS);
delete process.env.MOONJMES_FORWARDED_ARGS;
const stdin = process.argv[3] === '--close-stdin' ? 'ignore' : 'inherit';
const result = spawnSync(process.argv[2], args, { stdio: [stdin, 'inherit', 'inherit'] });
if (result.error) console.error(result.error.message);
process.exitCode = result.status ?? 1;
