import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { applyObsidianSync, planObsidianSync } from './sync-obsidian-content.mjs';

const root = fileURLToPath(new URL('../', import.meta.url));
export function run(command, args) {
  const result = spawnSync(command, args, { cwd: root, stdio: 'inherit', shell: false });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${command} が失敗しました (${result.status})`);
}
const vault = process.argv[2] ?? process.env.STUDY_APP_VAULT ?? path.resolve(root, '../Document organization');
try {
  const plan = await planObsidianSync({ vaultRoot: vault });
  await applyObsidianSync(plan, { prune: true });
  console.log(`Docsifyへ${plan.entries.length}記事を同期しました。`);
  const candidates = process.env.STUDY_APP_PYTHON ? [process.env.STUDY_APP_PYTHON] : ['python3', 'python', path.resolve(root, '../../.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe')];
  const python = candidates.find((command) => spawnSync(command, ['--version'], { stdio: 'ignore' }).status === 0);
  if (!python) throw new Error('Python 3が必要です。STUDY_APP_PYTHONで実行ファイルを指定できます。');
  run(python, ['build_note_index.py']);
  run(process.execPath, ['--test', 'tests/content-model.test.mjs', 'tests/obsidian-sync.test.mjs', 'tests/unique-heading-ids.test.js']);
  run('git', ['diff', '--check']);
} catch (error) { console.error(error.message); process.exitCode = 1; }
