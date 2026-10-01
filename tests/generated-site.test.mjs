import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import { unified } from '@astrojs/markdown-remark';
import { remarkWikiLinks } from '../app/src/markdown/remark-wiki-links.mjs';
import { rehypeEscapeRawHtml } from '../app/src/markdown/rehype-escape-raw-html.mjs';

const read = (relative) => fs.readFile(new URL(relative, import.meta.url), 'utf8');
const master = JSON.parse(await read('../generated/article-master.json'));
const home = await read('../dist/index.html');

test('現在の全記事だけを静的 route と一覧に出力する', async () => {
  await read('../dist/training/index.html');
  const routes = await fs.readdir(new URL('../dist/articles/', import.meta.url));
  assert.deepEqual(routes.sort(), master.articles.map((article) => article.id).sort());
  for (const article of master.articles) {
    const html = await read(`../dist/articles/${article.id}/index.html`);
    assert.ok(home.includes(`/articles/${article.id}/`));
    assert.ok(html.includes(`data-article-id="${article.id}"`));
    assert.match(html, /data-study-progress/u);
    assert.match(html, /aria-current="page"/u);
    assert.match(html, /data-active-branch="true"/u);
    assert.equal(html.includes('article-header--wiki'), article.type === 'wiki');
    assert.match(html, /data-article-toc/u);
    const ids = [...html.matchAll(/<h[1-6] id="([^"]+)"/gu)].map((match) => match[1]);
    assert.equal(ids.length, new Set(ids).size);
  }
});

test('テーマ、階層 navigation、検索、backup を出力する', () => {
  const themes = [...home.matchAll(/<option value="([^"]+)"/gu)].map((match) => match[1]);
  assert.deepEqual(themes, ['standard', 'wiki', 'living-aurora', 'blue-cosmos', 'pulse-neon']);
  for (const marker of ['data-theme-picker', 'study-app:theme', 'study-app:page-tree-open', 'data-article-explorer', 'タイトル・タグ・本文を検索', '該当する記事がありません。', 'data-learning-export', 'data-learning-import']) assert.ok(home.includes(marker), marker);
  const multipleTypes = new Set(master.articles.map((article) => article.type)).size > 1;
  assert.equal(home.includes('data-article-type-filter="study"'), multipleTypes);
  assert.equal(home.includes('data-article-type-filter="wiki"'), multipleTypes);
});

test('独立したMarkdown fixtureでHTML安全化、task、重複見出しを検証する', async () => {
  const renderer = await unified({ remarkPlugins: [remarkWikiLinks], rehypePlugins: [rehypeEscapeRawHtml] }).createRenderer({});
  const { code } = await renderer.render('# 例\n\n# 例\n\n- [x] 完了\n- [ ] 未完了\n\n<script>window.__unsafeArticleExecuted = true</script>\n\n<img src="x" onerror="alert(1)">\n\n```html\n<button onclick="alert(1)">例</button>\n```');
  assert.doesNotMatch(code, /<script>window\.__unsafeArticleExecuted|<img src="x" onerror=/u);
  assert.match(code, /&#x3C;script>/u);
  assert.match(code, /type="checkbox"/u);
  assert.match(code, /checked/u);
  assert.match(code, /onclick/u);
  const ids = [...code.matchAll(/<h[1-6] id="([^"]+)"/gu)].map((match) => match[1]);
  assert.equal(ids.length, 2);
  assert.equal(new Set(ids).size, 2);
});

test('現在の索引を使ってWiki Linkを解決し、存在しない記事を未解決にする', async () => {
  const renderer = await unified({ remarkPlugins: [remarkWikiLinks] }).createRenderer({});
  const article = master.articles[0];
  const target = article.path.replace(/^notes\//u, '').replace(/\.md$/u, '');
  const { code } = await renderer.render(`[[${target}#対象見出し|別名]]\n\n[[missing-test-article]]`);
  assert.ok(code.includes(`/articles/${article.id}/#`));
  assert.match(code, /別名<\/a>/u);
  assert.match(code, /missing-test-article（リンク未解決）/u);
});
