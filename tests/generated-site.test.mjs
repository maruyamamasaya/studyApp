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

test('Wiki Link の別名と見出しを解決し、曖昧・未解決はリンクにしない', async () => {
  const html = await page('20260929-121503');
  assert.match(html, /href="\/articles\/20260929-121502\/#%E7%89%B9%E3%81%AB%E9%87%8D%E8%A6%81%E3%81%AA%E5%AF%BE%E6%AF%94"/u);
  assert.match(html, /数値計算の記事<\/a>/u);
  assert.match(html, /🌟AWS基礎について（リンク曖昧）/u);
  assert.match(html, /まだ移行していない記事（リンク未解決）/u);
  assert.match(html, /href="\/training\/"/u);
  assert.match(html, /href="\/articles\/20260929-121502\/#%E7%89%B9%E3%81%AB%E9%87%8D%E8%A6%81%E3%81%AA%E5%AF%BE%E6%AF%94">数値計算の記事（標準相対リンク）/u);
});

test('Obsidian の ID filename 付き Wiki Link を同期先 path で解決する', async () => {
  const html = await page('20260929-121459');
  assert.match(html, /href="\/articles\/20260929-133348\/"/u);
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
