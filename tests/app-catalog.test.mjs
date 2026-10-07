import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import test from 'node:test';
import { articleContentHash, articleURL, buildAppCatalog, validateAppCatalog } from '../scripts/lib/app-articles.mjs';
import { verifyAppCatalog } from '../scripts/verify-app-catalog.mjs';

function entry(id = '20261001-120000', markdown = '---\nid: sample\n---\n\n本文\n') {
  return { source: `wiki/案件 A/${id}.md`, markdown,
    article: { id, displayTitle: '記事', type: 'study', tags: ['RAG'], aliases: ['別名'], created: '2026-10-01 12:00:00' } };
}

test('本文hashはLF/CRLFで一致し、内容と末尾空白の変更を検出する', () => {
  const text = entry().markdown;
  assert.equal(articleContentHash(text), createHash('sha256').update(Buffer.from(text, 'utf8')).digest('hex'));
  assert.equal(articleContentHash(text), articleContentHash(text.replaceAll('\n', '\r\n')));
  assert.notEqual(articleContentHash(text), articleContentHash(text + ' '));
  assert.notEqual(articleContentHash(text), articleContentHash(text.replace('本文', '更新本文')));
});

test('再生成と入力順変更で一覧は変わらず、移動・削除・更新でrevisionが変わる', () => {
  const a = entry(), b = entry('20261001-120001');
  const original = buildAppCatalog([a, b]);
  assert.deepEqual(original, buildAppCatalog([b, a]));
  assert.equal(original.schemaVersion, 1);
  assert.equal(original.articles[0].type, 'study');
  assert.notEqual(original.revision, buildAppCatalog([a]).revision);
  assert.notEqual(original.revision, buildAppCatalog([{ ...a, source: 'study/移動.md' }, b]).revision);
  assert.notEqual(original.revision, buildAppCatalog([{ ...a, markdown: a.markdown + '追加\n' }, b]).revision);
  assert.deepEqual(buildAppCatalog([]).articles, []);
});

test('日本語・空白・記号を含むpathから正しい本文URLを作る', () => {
  const url = articleURL('https://example.com/studyApp/', 'wiki/案件 A/文書#1%.md');
  assert.equal(decodeURIComponent(url.pathname), '/studyApp/wiki/案件 A/文書#1%.md');
  assert.equal(url.hash, '');
  assert.equal(url.search, '');
  assert.equal(url.origin, 'https://example.com');
});

test('任意の種別と空文字列を配信し、文字列以外は拒否する', () => {
  const types = ['study', 'wiki', 'development-log', 'Applied', '自由な分類', ''];
  const entries = types.map((type, index) => {
    const value = entry(`20261005-09365${index}`);
    return { ...value, article: { ...value.article, type } };
  });
  const catalog = buildAppCatalog(entries);
  assert.deepEqual(validateAppCatalog(JSON.parse(JSON.stringify(catalog))).articles.map(a => a.type),
    types);
  for (const type of [null, undefined, 1, false, [], {}]) {
    assert.throws(() => buildAppCatalog([{ ...entries[0], article: { ...entries[0].article, type } }]), /不正/u);
  }
});

test('未対応Schema、ID重複、不正なpathを拒否する', () => {
  const catalog = buildAppCatalog([entry()]);
  assert.throws(() => validateAppCatalog({ ...catalog, schemaVersion: 2 }), /schemaVersion/u);
  assert.throws(() => validateAppCatalog({ ...catalog, articles: [...catalog.articles, ...catalog.articles] }), /重複/u);
  for (const value of ['wiki/../private.md', '/wiki/file.md', 'https://evil.example/file.md', 'wiki//file.md', 'wiki/\\file.md']) {
    assert.throws(() => articleURL('https://example.com/studyApp/', value), /path/u);
  }
});

test('HTTP検証は全本文を取得してhashを照合し、不一致・404・不正配信元を拒否する', async () => {
  const e = entry(), catalog = buildAppCatalog([e]);
  const calls = [];
  const serve = (text = e.markdown, status = 200) => async (url, options) => {
    calls.push(String(url));
    assert.equal(options.redirect, 'error');
    return String(url).endsWith('app-articles.v1.json')
      ? new Response(JSON.stringify(catalog)) : new Response(text, { status });
  };
  const result = await verifyAppCatalog('https://example.com/studyApp', { fetchImpl: serve() });
  assert.equal(result.count, 1);
  assert.equal(calls.length, 2);
  assert.equal(calls[0], 'https://example.com/studyApp/app-articles.v1.json');
  await assert.rejects(verifyAppCatalog('https://example.com/', { fetchImpl: serve('違う本文') }), /hash/u);
  await assert.rejects(verifyAppCatalog('https://example.com/', { fetchImpl: serve('not found', 404) }), /404/u);
  await assert.rejects(verifyAppCatalog('http://example.com/', { fetchImpl: serve() }), /HTTPS/u);
  await assert.rejects(verifyAppCatalog('https://user:pass@example.com/', { fetchImpl: serve() }), /HTTPS/u);
});

 test('記事種別は拡張値・未分類を保持し、文字列以外は拒否する', () => {
  for (const type of ['development-log', 'activity-log', 'Applied', '']) {
    const original = entry();
    const catalog = buildAppCatalog([{ ...original, article: { ...original.article, type } }]);
    assert.equal(catalog.articles[0].type, type);
    assert.throws(() => validateAppCatalog({ ...catalog, articles: [{ ...catalog.articles[0], type: null }] }), /不正/u);
  }
});
