const { spawnSync } = require('node:child_process');

const args = JSON.parse(process.env.MOONJMES_LEGACY_ARGS);
delete process.env.MOONJMES_LEGACY_ARGS;
const result = spawnSync(process.argv[2], args, { stdio: 'inherit' });
if (result.error) console.error(result.error.message);
process.exitCode = result.status ?? 1;
