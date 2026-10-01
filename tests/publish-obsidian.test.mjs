import test from 'node:test';
import assert from 'node:assert/strict';
import { publish } from '../scripts/publish-obsidian.mjs';

const successful = { status: 'succeeded', project_id: 'study-project', deployment_id: 'deployment', version_id: 'version', url: 'https://example.chatgpt.site' };
function reader(result) { return Object.assign(async () => result, { schema: 'schema', output: 'output', prompt: 'publish' }); }

test('同期と差分チェックの後で公開し、成功URLを返す', async () => {
  const calls = [];
  const result = await publish({ projectId: 'study-project', vault: 'vault', codexEntry: 'codex.js', run: async (...args) => calls.push(args), readResult: reader(successful) });
  assert.equal(calls.length, 3);
  assert.match(calls[0][1][0], /prepare-obsidian-content\.mjs$/u);
  assert.deepEqual(calls[1][1], ['diff', '--check']);
  assert.ok(calls[2][1].includes('--approve-for-me'));
  assert.equal(calls[2][1][calls[2][1].indexOf('--model') + 1], 'gpt-6-sol');
  assert.equal(result.url, successful.url);
});

test('公開用モデルの明示指定をCLIへ渡す', async () => {
  const calls = [];
  await publish({ model: 'custom-model', projectId: 'study-project', vault: 'vault', codexEntry: 'codex.js', run: async (...args) => calls.push(args), readResult: reader(successful) });
  assert.equal(calls[2][1][calls[2][1].indexOf('--model') + 1], 'custom-model');
});

test('同期または差分チェックが失敗したら公開を呼ばない', async () => {
  for (const failureAt of [1, 2]) {
    let calls = 0;
    await assert.rejects(publish({ projectId: 'study-project', vault: 'vault', codexEntry: 'codex.js', run: async () => { if (++calls === failureAt) throw new Error('failed'); }, readResult: reader(successful) }), /failed/u);
    assert.equal(calls, failureAt);
  }
});

test('failed、ID欠落、別project、別ドメインを公開成功と扱わない', async () => {
  for (const result of [{ ...successful, status: 'failed' }, { ...successful, deployment_id: '' }, { ...successful, project_id: 'other-project' }, { ...successful, url: 'https://example.com' }]) {
    await assert.rejects(publish({ projectId: 'study-project', vault: 'vault', codexEntry: 'codex.js', run: async () => {}, readResult: reader(result) }), /公開成功/u);
  }
});
