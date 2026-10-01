import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));

export async function publish({ vault, codexEntry, run, readResult, projectId, model = 'gpt-6-sol' }) {
  await run(process.execPath, [path.join(root, 'scripts/prepare-obsidian-content.mjs'), vault]);
  await run('git', ['diff', '--check']);
  await run(process.execPath, [codexEntry, 'exec', '--model', model, '--approve-for-me', '--enable', 'apps', '-C', root,
    '--output-schema', readResult.schema, '--output-last-message', readResult.output, '-'], readResult.prompt);
  const result = await readResult();
  if (result.status !== 'succeeded' || result.project_id !== projectId || !result.deployment_id || !result.version_id ||
      !/^https:\/\/[^/]+\.chatgpt\.site(?:\/|$)/u.test(result.url ?? '')) {
    throw new Error(result.message || 'Sitesでの公開成功を確認できませんでした。');
  }
  return result;
}

async function main() {
  const checkOnly = process.argv.includes('--check-only');
  const model = process.env.STUDY_APP_PUBLISH_MODEL ?? 'gpt-6-sol';
  const vault = process.argv.slice(2).find((arg) => !arg.startsWith('--')) ?? process.env.STUDY_APP_VAULT ?? path.resolve(root, '../Document organization');
  const codexEntry = process.env.STUDY_APP_CODEX_ENTRY ?? path.join(process.env.APPDATA ?? '', 'npm/node_modules/@openai/codex/bin/codex.js');
  await fs.access(codexEntry);
  await fs.access(path.join(vault, 'study'));
  await fs.access(path.join(vault, 'wiki'));
  const npmCli = process.env.npm_execpath ?? path.join(path.dirname(process.execPath), 'node_modules/npm/bin/npm-cli.js');
  await fs.access(npmCli);
  const hosting = JSON.parse(await fs.readFile(path.join(root, '.openai/hosting.json'), 'utf8'));
  if (!hosting.project_id) throw new Error('既存Sites project IDが必要です。');
  const env = { ...process.env, npm_execpath: npmCli, PATH: `C:\\Program Files\\Git\\bin;${process.env.PATH}`, TAR_OPTIONS: '--force-local' };
  const run = (command, args, input) => new Promise((resolve, reject) => {
    const child = spawn(command, args, { cwd: root, env, shell: false, stdio: [input ? 'pipe' : 'inherit', 'inherit', 'inherit'] });
    child.once('error', reject);
    child.once('close', (code) => code === 0 ? resolve() : reject(new Error(`処理が失敗しました（終了コード ${code}）。公開完了とは扱いません。`)));
    if (input) { child.stdin.on('error', () => {}); child.stdin.end(input); }
  });
  await run(process.execPath, [codexEntry, 'login', 'status']);
  if (checkOnly) { console.log('起動前確認に成功しました。同期・公開は実行していません。'); return; }
  const temp = await fs.mkdtemp(path.join(os.tmpdir(), 'study-app-publish-'));
  const output = path.join(temp, 'result.json');
  const schema = path.join(temp, 'schema.json');
  await fs.writeFile(schema, JSON.stringify({ type: 'object', additionalProperties: false,
    properties: { status: { type: 'string', enum: ['succeeded', 'failed'] }, project_id: { type: 'string' }, url: { type: 'string' }, deployment_id: { type: 'string' }, version_id: { type: 'string' }, message: { type: 'string' } },
    required: ['status', 'project_id', 'url', 'deployment_id', 'version_id', 'message'] }));
  const readResult = async () => JSON.parse(await fs.readFile(output, 'utf8'));
  Object.assign(readResult, { schema, output, prompt: `既存Study AppをSitesへ公開してください。ユーザーはこのバッチ起動により同期と公開を承認しています。AGENTS.md、CURRENT.md、ARCHITECTURE.mdとSites hosting skillを読んでください。
Vault同期・npm run check・git diff --checkはこのバッチが直前に成功させています。必要なく再実行しないでください。既存project IDは ${hosting.project_id} です。create_siteは禁止。既存の閲覧範囲を維持してください。
Sites connectorでget_site、短期source credential取得、bundled site-workflowによるopen、publish用source push/package、native save/deploy、status=succeededとURLの確認まで実行してください。Git BashをPATH先頭、TAR_OPTIONS=--force-localで起動してください。credentialはメモリとstdinだけで扱い、出力やファイルへ保存しないでください。archiveは一時ディレクトリへ置いてください。
無関係なソース変更・テストの弱体化・Vault編集・force push・新サイト作成・アクセス範囲変更は禁止。ソース差分は確認し、既存変更を保持してください。historyが分岐している場合は自動で推測mergeせずfailedで返してください。
Sites toolsが利用できない、承認が拒否された、公開が失敗した場合はfailedとして理由を返してください。成功はnative deploymentのsucceeded結果だけで判定し、実際のproject_id、url、deployment_id、version_idを返してください。設定や手順の追加変更は不要です。` });
  try {
    console.log('Obsidian同期・検証後、Codex経由で既存Sitesへ公開します。');
    const result = await publish({ vault, codexEntry, run, readResult, projectId: hosting.project_id, model });
    console.log(`公開完了: ${result.url}`);
  } finally {
    await fs.unlink(output).catch(() => {});
    await fs.unlink(schema).catch(() => {});
    await fs.rmdir(temp).catch(() => {});
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch((error) => { console.error(error.message); process.exitCode = 1; });
}
