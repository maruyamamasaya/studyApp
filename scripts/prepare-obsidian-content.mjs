import { spawnSync } from 'node:child_process';
import process from 'node:process';
import { applyObsidianSync, planObsidianSync } from './sync-obsidian-content.mjs';

const vaultRoot = process.argv[2] ?? process.env.STUDY_APP_VAULT;
if (!vaultRoot) {
  console.error('Vault path が必要です。例: npm run vault:prepare -- "C:\\path\\to\\Vault"');
  process.exit(1);
}

try {
  const plan = await planObsidianSync({ vaultRoot });
  for (const item of plan.skipped) console.warn(`SKIP ${item.source}: ${item.reason}`);
  for (const change of plan.changes) console.log(`${change.action.toUpperCase()} ${change.source} -> ${change.destination}`);
  for (const stale of plan.stale) console.warn(`PRUNE ${stale.destination}`);
  await applyObsidianSync(plan, { prune: true });

  const npmCli = process.env.npm_execpath;
  const command = npmCli ? process.execPath : process.platform === 'win32' ? 'npm.cmd' : 'npm';
  const args = npmCli ? [npmCli, 'run', 'check'] : ['run', 'check'];
  const result = spawnSync(command, args, { cwd: plan.repositoryRoot, stdio: 'inherit' });
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
