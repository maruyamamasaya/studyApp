import { createHash } from 'node:crypto';

export const APP_CATALOG_FILE = 'app-articles.v1.json';
const HASH_PATTERN = /^[a-f0-9]{64}$/u;

// Git checkout may change CRLF to LF. Hash the complete Markdown after
// newline normalization, including Frontmatter and trailing whitespace.
export function articleContentHash(markdown) {
  return createHash('sha256').update(markdown.replaceAll('\r\n', '\n'), 'utf8').digest('hex');
}

function validPath(value) {
  return typeof value === 'string' && /^(study|wiki)\/.+\.md$/u.test(value) &&
    !/[\\\u0000-\u001f\u007f]/u.test(value) &&
    value.split('/').every((segment) => segment && segment !== '.' && segment !== '..');
}

export function buildAppCatalog(entries) {
  const articles = entries.map(({ article, source, markdown }) => ({
    id: article.id,
    title: article.displayTitle,
    path: source,
    type: article.type,
    tags: [...article.tags],
    aliases: [...article.aliases],
    created: article.created,
    contentHash: articleContentHash(markdown)
  })).sort((a, b) => a.id < b.id ? -1 : a.id > b.id ? 1 : 0);
  const catalog = {
    schemaVersion: 1,
    revision: createHash('sha256').update(JSON.stringify(articles), 'utf8').digest('hex'),
    articles
  };
  validateAppCatalog(catalog);
  return catalog;
}

export function validateAppCatalog(catalog) {
  if (!catalog || catalog.schemaVersion !== 1 || !HASH_PATTERN.test(catalog.revision) || !Array.isArray(catalog.articles)) {
    throw new Error('アプリ記事一覧の形式またはschemaVersionが未対応です');
  }
  const ids = new Set();
  const paths = new Set();
  for (const article of catalog.articles) {
    if (!article || typeof article.id !== 'string' || !/^\d{8}-\d{6}$/u.test(article.id) ||
        typeof article.title !== 'string' || !article.title.trim() ||
        !validPath(article.path) || typeof article.type !== 'string' ||
        !HASH_PATTERN.test(article.contentHash) || typeof article.created !== 'string' ||
        !/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/u.test(article.created) ||
        ![article.tags, article.aliases].every((values) => Array.isArray(values) && values.every((value) => typeof value === 'string'))) {
      throw new Error(`アプリ記事の項目が不正です: ${article?.id ?? 'IDなし'}`);
    }
    if (ids.has(article.id) || paths.has(article.path.toLocaleLowerCase('ja-JP'))) {
      throw new Error(`アプリ記事のIDまたはpathが重複しています: ${article.id}`);
    }
    ids.add(article.id);
    paths.add(article.path.toLocaleLowerCase('ja-JP'));
  }
  return catalog;
}

export function articleURL(baseURL, articlePath) {
  if (!validPath(articlePath)) throw new Error('記事pathが不正です');
  return new URL(articlePath.split('/').map(encodeURIComponent).join('/'), baseURL);
}
