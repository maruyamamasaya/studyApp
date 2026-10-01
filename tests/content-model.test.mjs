import test from 'node:test';
import assert from 'node:assert/strict';
import { buildLinkIndex, normalizeArticle, normalizePath, parseFrontmatter, validateArticleSet } from '../scripts/lib/article.mjs';

const validData = {
  id: '20260929-120000',
  title: '  テスト記事  ',
  type: 'study',
  tags: [' AWS ', '', 'AWS', 'Security'],
  aliases: [' 別名 ', 'テスト記事', '', '別名'],
  created: '2026-09-29 12:00:00'
};

test('正常な Frontmatter を正規化する', () => {
  const { article } = normalizeArticle(validData, 'notes\\study\\20260929-120000.md');
  assert.equal(article.path, 'notes/study/20260929-120000.md');
  assert.equal(article.title, 'テスト記事');
  assert.equal(article.displayTitle, 'テスト記事');
  assert.deepEqual(article.tags, ['AWS', 'Security']);
  assert.deepEqual(article.aliases, ['別名']);
});

test('欠落・空欄 title は null、表示は未設定にする', () => {
  for (const title of [undefined, '', '   ', null]) {
    const data = { ...validData, title };
    const { article } = normalizeArticle(data, 'notes/study/20260929-120000.md');
    assert.equal(article.title, null);
    assert.equal(article.displayTitle, '未設定');
    assert.equal(article.internalLabel, '別名');
  }
});

test('ID の欠落・形式不正・filename 不一致を拒否する', () => {
  assert.throws(() => normalizeArticle({ ...validData, id: undefined }, 'notes/study/20260929-120000.md'), /id は/);
  assert.throws(() => normalizeArticle({ ...validData, id: 'abc' }, 'notes/study/abc.md'), /YYYYMMDD/);
  assert.throws(() => normalizeArticle(validData, 'notes/study/20260929-120001.md'), /一致しません/);
});

test('未知 type は warning、実在しない created は error にする', () => {
  const { warnings } = normalizeArticle({ ...validData, type: 'reference' }, 'notes/study/20260929-120000.md');
  assert.match(warnings[0], /未知の type/);
  assert.throws(() => normalizeArticle({ ...validData, created: '2026-02-30 12:00:00' }, 'notes/study/20260929-120000.md'), /created は/);
});

test('重複 ID を拒否する', () => {
  assert.throws(() => validateArticleSet([
    { id: '20260929-120000', path: 'notes/a/20260929-120000.md' },
    { id: '20260929-120000', path: 'notes/b/20260929-120000.md' }
  ]), /duplicate id/);
});

test('Windows / POSIX path と Unicode を正規化する', () => {
  assert.equal(normalizePath('notes\\a\\..\\b\\e\u0301.md'), 'notes/b/é.md');
  assert.equal(normalizePath('./notes//study/20260929-120000.md'), 'notes/study/20260929-120000.md');
});

test('Frontmatter の欠落と壊れた YAML を拒否する', () => {
  assert.throws(() => parseFrontmatter('# 本文'), /Frontmatter がありません/);
  assert.throws(() => parseFrontmatter('---\ntags: [\n---\n本文'), /解析できません/);
});

test('同名 title は link index に複数候補を保持する', () => {
  const common = { filename: 'a.md', aliases: [], type: 'study', tags: [], created: '2026-09-29 12:00:00' };
  const index = buildLinkIndex([
    { ...common, id: '20260929-120000', path: 'notes/a.md', title: '同名' },
    { ...common, id: '20260929-120001', path: 'notes/b.md', title: '同名' }
  ]);
  assert.equal(index['同名'].filter((item) => item.matchedBy === 'title').length, 2);
});
