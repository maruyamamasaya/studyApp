import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { articleContentHash } from '../scripts/lib/app-articles.mjs';
import { applyObsidianSync, planObsidianSync } from '../scripts/sync-obsidian-content.mjs';

async function fixture() {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'study-app-sync-'));
  const vaultRoot = path.join(root, 'vault');
  const repositoryRoot = path.join(root, 'repository');
  await Promise.all([
    fs.mkdir(path.join(vaultRoot, '.obsidian'), { recursive: true }),
    fs.mkdir(path.join(vaultRoot, 'study'), { recursive: true }),
    fs.mkdir(path.join(vaultRoot, 'wiki'), { recursive: true }),
    fs.mkdir(path.join(repositoryRoot, 'generated'), { recursive: true })
  ]);
  return { root, vaultRoot, repositoryRoot };
}

const note = (id, type) => `---\nid: ${id}\ntitle:\ntype: ${type}\ntags: []\ncreated: "2026-09-29 12:00:00"\nupdated:\naliases: []\n---\n\n本文\n`;

test('wiki / study を相対パスを保って同期し、空の下書きを除外する', async (t) => {
  const paths = await fixture();
  t.after(() => fs.rm(paths.root, { recursive: true, force: true }));
  await fs.mkdir(path.join(paths.vaultRoot, 'wiki', 'nested'));
  await fs.writeFile(path.join(paths.vaultRoot, 'wiki', 'nested', '20260929-120000.md'), note('20260929-120000', 'wiki'));
  await fs.writeFile(path.join(paths.vaultRoot, 'study', 'draft.md'), '');

  const plan = await planObsidianSync(paths);
  assert.equal(plan.entries.length, 1);
  assert.equal(plan.skipped.length, 1);
  assert.equal(plan.entries[0].destination, 'docs/wiki/nested/20260929-120000.md');
  await applyObsidianSync(plan);
  assert.equal(await fs.readFile(path.join(paths.repositoryRoot, plan.entries[0].destination), 'utf8'), plan.entries[0].markdown);
});

test('配置フォルダと記事種別を分離し、wiki 内の study を研修一覧に含める', async (t) => {
  const paths = await fixture();
  t.after(() => fs.rm(paths.root, { recursive: true, force: true }));
  await fs.writeFile(path.join(paths.vaultRoot, 'wiki', '20260929-120000.md'), note('20260929-120000', 'study'));
  const plan = await planObsidianSync(paths);
  assert.equal(plan.entries[0].article.type, 'study');
  assert.equal(plan.entries[0].destination, 'docs/wiki/20260929-120000.md');
  await applyObsidianSync(plan);
  assert.match(await fs.readFile(path.join(paths.repositoryRoot, 'docs/training/README.md'), 'utf8'), /wiki\/20260929-120000/u);
  assert.equal(await fs.readFile(path.join(paths.repositoryRoot, plan.entries[0].destination), 'utf8'), note('20260929-120000', 'study'));
  const appCatalog = JSON.parse(await fs.readFile(path.join(paths.repositoryRoot, 'docs/app-articles.v1.json'), 'utf8'));
  assert.equal(appCatalog.articles[0].id, '20260929-120000');
  assert.equal(appCatalog.articles[0].path, 'wiki/20260929-120000.md');
  assert.equal(appCatalog.articles[0].contentHash, articleContentHash(note('20260929-120000', 'study')));
});

test('未対応の記事種別を拒否する', async (t) => {
  const paths = await fixture();
  t.after(() => fs.rm(paths.root, { recursive: true, force: true }));
  await fs.writeFile(path.join(paths.vaultRoot, 'wiki', '20260929-120000.md'), note('20260929-120000', 'other'));
  await assert.rejects(() => planObsidianSync(paths), /type は study または wiki/u);
});

test('同期管理外の既存ファイルを上書きしない', async (t) => {
  const paths = await fixture();
  t.after(() => fs.rm(paths.root, { recursive: true, force: true }));
  const relative = path.join('wiki', '20260929-120000.md');
  await fs.writeFile(path.join(paths.vaultRoot, relative), note('20260929-120000', 'wiki'));
  const destination = path.join(paths.repositoryRoot, 'docs', relative);
  await fs.mkdir(path.dirname(destination), { recursive: true });
  await fs.writeFile(destination, '既存の別内容');
  await assert.rejects(() => planObsidianSync(paths), /同期管理外の既存ファイル/u);
});

test('Vault に存在しない docs の記事を拒否する', async (t) => {
  const paths = await fixture();
  t.after(() => fs.rm(paths.root, { recursive: true, force: true }));
  const destination = path.join(paths.repositoryRoot, 'docs', 'study', '20260929-120001.md');
  await fs.mkdir(path.dirname(destination), { recursive: true });
  await fs.writeFile(destination, note('20260929-120001', 'study'));
  await assert.rejects(() => planObsidianSync(paths), /Vault の生成ミラー/u);
});

test('前回同期済みで未変更の記事だけを prune できる', async (t) => {
  const paths = await fixture();
  t.after(() => fs.rm(paths.root, { recursive: true, force: true }));
  const source = path.join(paths.vaultRoot, 'study', '20260929-120000.md');
  await fs.writeFile(source, note('20260929-120000', 'study'));
  const firstPlan = await planObsidianSync(paths);
  await applyObsidianSync(firstPlan);
  const destination = path.join(paths.repositoryRoot, firstPlan.entries[0].destination);

  await fs.unlink(source);
  const prunePlan = await planObsidianSync(paths);
  assert.equal(prunePlan.stale.length, 1);
  await applyObsidianSync(prunePlan, { prune: true });
  await assert.rejects(() => fs.access(destination), /ENOENT/u);
  assert.deepEqual(JSON.parse(await fs.readFile(path.join(paths.repositoryRoot, 'docs/app-articles.v1.json'), 'utf8')).articles, []);
});
