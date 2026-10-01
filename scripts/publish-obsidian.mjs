import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = fileURLToPath(new URL('../', import.meta.url));
function git(args, capture = false) {
  const result = spawnSync('git', args, { cwd: root, encoding: 'utf8', stdio: capture ? 'pipe' : 'inherit', shell: false });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error('Git処理が失敗しました。公開成功とは扱いません。');
  return result.stdout?.trim();
}
try {
  if (git(['branch', '--show-current'], true) !== 'main') throw new Error('公開はmainブランチで実行してください。');
  if (git(['diff', '--cached', '--name-only'], true)) throw new Error('ステージ済みの変更があります。先に整理してください。');
  const remote = git(['remote', 'get-url', 'origin'], true);
  if (!/^(https:\/\/github\.com\/maruyamamasaya\/studyApp(?:\.git)?|git@github\.com:maruyamamasaya\/studyApp(?:\.git)?)$/u.test(remote)) throw new Error('originが想定のstudyAppではありません。');
  const result = spawnSync(process.execPath, [path.join(root, 'scripts/prepare-obsidian-content.mjs'), ...process.argv.slice(2)], { cwd: root, stdio: 'inherit', shell: false });
  if (result.error || result.status !== 0) throw new Error('同期・検証に失敗したためpushしません。');
  git(['add', '--', 'docs', 'obsidian-sync-manifest.json']);
  if (git(['diff', '--cached', '--name-only'], true)) git(['commit', '-m', 'Sync Obsidian notes']);
  git(['push', 'origin', 'HEAD:main']);
  console.log('GitHubへの送信が完了しました。Pagesの公開結果はGitHub Actionsで確認してください。');
  console.log('https://github.com/maruyamamasaya/studyApp/actions');
} catch (error) { console.error(error.message); process.exitCode = 1; }
