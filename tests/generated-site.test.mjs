import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';

async function page(id) {
  return fs.readFile(new URL(`../dist/articles/${id}/index.html`, import.meta.url), 'utf8');
}

test('ホーム、研修、全記事の静的 route を生成する', async () => {
  await fs.access(new URL('../dist/index.html', import.meta.url));
  await fs.access(new URL('../dist/training/index.html', import.meta.url));
  const master = JSON.parse(await fs.readFile(new URL('../generated/article-master.json', import.meta.url), 'utf8'));
  assert.ok(master.articles.length >= 7);
  for (const article of master.articles) await fs.access(new URL(`../dist/articles/${article.id}/index.html`, import.meta.url));
});

test('Wiki Link の別名と見出しを解決し、未解決を別記事へ結び付けない', async () => {
  const html = await page('20260929-121503');
  assert.match(html, /href="\/articles\/20260929-121502\/#%E7%89%B9%E3%81%AB%E9%87%8D%E8%A6%81%E3%81%AA%E5%AF%BE%E6%AF%94"/u);
  assert.match(html, /数値計算の記事<\/a>/u);
  assert.match(html, /href="\/articles\/20260929-121500\/">🌟AWS基礎について/u);
  assert.match(html, /まだ移行していない記事（リンク未解決）/u);
  assert.match(html, /href="\/training\/"/u);
  assert.match(html, /href="\/articles\/20260929-121502\/#%E7%89%B9%E3%81%AB%E9%87%8D%E8%A6%81%E3%81%AA%E5%AF%BE%E6%AF%94">数値計算の記事（標準相対リンク）/u);
});

test('HTML 例を実行可能な要素にせず、コードフェンスも保持する', async () => {
  const html = await page('20260929-121504');
  assert.doesNotMatch(html, /<script>window\.__unsafeArticleExecuted/u);
  assert.doesNotMatch(html, /<img src="x" onerror=/u);
  assert.match(html, /&#x3C;script>window\.__unsafeArticleExecuted/u);
  assert.match(html, /onclick/u);
});

test('task list と重複見出しを安全に出力する', async () => {
  const taskHtml = await page('20260929-121501');
  assert.match(taskHtml, /type="checkbox"/u);
  assert.match(taskHtml, /checked/u);
  const headingHtml = await page('20260929-121502');
  const ids = [...headingHtml.matchAll(/<h[1-6] id="([^"]+)"/gu)].map((match) => match[1]);
  assert.equal(ids.length, new Set(ids).size);
  assert.ok(ids.some((id) => /例-1$/u.test(id)), `重複見出しの suffix がありません: ${ids.join(', ')}`);
});

test('5種類の表示テーマを選択でき、選択を保存する', async () => {
  const html = await fs.readFile(new URL('../dist/index.html', import.meta.url), 'utf8');
  const themeValues = [...html.matchAll(/<option value="([^"]+)"/gu)].map((match) => match[1]);
  assert.deepEqual(themeValues, ['standard', 'wiki', 'living-aurora', 'blue-cosmos', 'pulse-neon']);
  assert.match(html, /data-theme-picker/u);
  assert.match(html, /localStorage\.getItem\('study-app:theme'\)/u);
  assert.match(html, /localStorage\.setItem\('study-app:theme'/u);
});

test('ホームは説明文を置かず、1列の記事一覧と階層ナビゲーションを出力する', async () => {
  const html = await fs.readFile(new URL('../dist/index.html', import.meta.url), 'utf8');
  assert.doesNotMatch(html, /Markdown knowledge base/u);
  assert.doesNotMatch(html, /Obsidian Vault を正本として同期した記事/u);
  assert.match(html, /<details class="sidebar-drawer" open>/u);
  assert.match(html, /<details class="page-tree" open>/u);
  assert.match(html, /<summary>ページツリー<\/summary>/u);
  assert.match(html, /matchMedia\('\(max-width: 640px\)'\)/u);
  assert.match(html, /anken001/u);
  assert.match(html, /class="article-grid"/u);
});

test('Wiki 記事だけコンパクトなタイトル用クラスを出力する', async () => {
  const wikiHtml = await page('20260929-121504');
  const studyHtml = await page('20260929-121502');
  assert.match(wikiHtml, /class="article-header article-header--wiki"/u);
  assert.doesNotMatch(studyHtml, /article-header--wiki/u);
});

test('記事単位の学習状態とバックアップ導線を出力する', async () => {
  const articleHtml = await page('20260929-121502');
  const homeHtml = await fs.readFile(new URL('../dist/index.html', import.meta.url), 'utf8');
  assert.match(articleHtml, /data-study-progress/u);
  assert.match(articleHtml, /data-article-id="20260929-121502"/u);
  assert.match(articleHtml, /data-progress-completion/u);
  assert.match(homeHtml, /data-learning-tools/u);
  assert.match(homeHtml, /data-learning-export/u);
  assert.match(homeHtml, /data-learning-import/u);
});
