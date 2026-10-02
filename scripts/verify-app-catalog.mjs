import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { APP_CATALOG_FILE, articleContentHash, articleURL, validateAppCatalog } from './lib/app-articles.mjs';

export async function verifyAppCatalog(baseValue, { fetchImpl = fetch } = {}) {
  const base = new URL(baseValue);
  const localHTTP = base.protocol === 'http:' && ['localhost', '127.0.0.1', '[::1]'].includes(base.hostname);
  if ((base.protocol !== 'https:' && !localHTTP) || base.username || base.password || base.search || base.hash) {
    throw new Error('配信元はHTTPS URL（ローカル検証のみHTTP可）で指定してください');
  }
  if (!base.pathname.endsWith('/')) base.pathname += '/';
  const get = async (url) => {
    const response = await fetchImpl(url, { redirect: 'error', signal: AbortSignal.timeout(15000), cache: 'no-cache' });
    if (!response.ok) throw new Error(`記事配信のHTTPエラー ${response.status}: ${url}`);
    return response;
  };
  const catalog = validateAppCatalog(await (await get(new URL(APP_CATALOG_FILE, base))).json());
  for (const article of catalog.articles) {
    const url = articleURL(base, article.path);
    const markdown = await (await get(url)).text();
    if (articleContentHash(markdown) !== article.contentHash) {
      throw new Error(`本文hashが一致しません: ${article.id} (${url})`);
    }
  }
  return { count: catalog.articles.length, revision: catalog.revision };
}

if (path.resolve(process.argv[1] ?? '') === fileURLToPath(import.meta.url)) {
  try {
    const result = await verifyAppCatalog(process.argv[2] ?? 'http://127.0.0.1:8000/');
    console.log(`アプリ記事配信の検証成功: ${result.count}記事。HTTP取得・一覧形式・本文hash一致。`);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
