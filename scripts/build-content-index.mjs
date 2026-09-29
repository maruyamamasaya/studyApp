import fs from 'node:fs/promises';
import path from 'node:path';
import { buildLinkIndex, normalizeArticle, normalizePath, parseFrontmatter, validateArticleSet } from '../app/src/domain/article.mjs';

const root = process.cwd();
const notesRoot = path.join(root, 'content', 'notes');
const generatedRoot = path.join(root, 'generated');
const migrationPath = path.join(root, 'migration', 'phase1-samples.json');

async function walk(directory) {
  const entries = await fs.readdir(directory, { withFileTypes: true });
  const nested = await Promise.all(entries.map(async (entry) => {
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) return walk(absolute);
    return entry.isFile() && entry.name.endsWith('.md') ? [absolute] : [];
  }));
  return nested.flat();
}

const files = (await walk(notesRoot)).sort((a, b) => a.localeCompare(b, 'ja'));
if (files.length < 5 || files.length > 10) throw new Error(`Phase 1 の記事数は 5〜10 件です（現在 ${files.length} 件）`);

const warnings = [];
const articles = [];
const bodies = new Map();
for (const absolute of files) {
  const relative = normalizePath(path.relative(path.join(root, 'content'), absolute));
  const markdown = await fs.readFile(absolute, 'utf8');
  const { data, body } = parseFrontmatter(markdown, relative);
  const normalized = normalizeArticle(data, relative);
  articles.push(normalized.article);
  bodies.set(normalized.article.id, body);
  warnings.push(...normalized.warnings.map((message) => ({ path: relative, message })));
}
validateArticleSet(articles);

const migration = JSON.parse(await fs.readFile(migrationPath, 'utf8'));
const migrationIds = new Set(migration.entries.map((entry) => entry.id));
for (const article of articles) {
  if (!migrationIds.has(article.id)) throw new Error(`${article.path}: migration/phase1-samples.json に対応関係がありません`);
}

const linkIndex = buildLinkIndex(articles);
const migrationById = new Map(migration.entries.map((entry) => [entry.id, entry]));
const articleMaster = articles.map(({ displayTitle, internalLabel, filename, ...article }) => ({
  ...article,
  ...(migrationById.get(article.id)?.legacyId ? { legacyId: migrationById.get(article.id).legacyId } : {}),
  ...(migrationById.get(article.id)?.legacyPath ? { legacyPath: migrationById.get(article.id).legacyPath } : {})
}));
const searchIndex = articles.map((article) => ({
  id: article.id,
  title: article.title,
  tags: article.tags,
  aliases: article.aliases,
  type: article.type,
  created: article.created,
  path: article.path,
  text: bodies.get(article.id).replace(/```[\s\S]*?```/gu, ' ').replace(/[#>*_`\[\]()|-]/gu, ' ').replace(/\s+/gu, ' ').trim()
}));

await fs.mkdir(generatedRoot, { recursive: true });
await Promise.all([
  fs.writeFile(path.join(generatedRoot, 'article-master.json'), `${JSON.stringify({ version: 2, articles: articleMaster }, null, 2)}\n`),
  fs.writeFile(path.join(generatedRoot, 'link-index.json'), `${JSON.stringify(linkIndex, null, 2)}\n`),
  fs.writeFile(path.join(generatedRoot, 'search-index.json'), `${JSON.stringify(searchIndex, null, 2)}\n`),
  fs.writeFile(path.join(generatedRoot, 'build-warnings.json'), `${JSON.stringify(warnings, null, 2)}\n`)
]);

console.log(`Validated ${articles.length} articles (${warnings.length} warnings).`);
