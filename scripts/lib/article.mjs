import path from 'node:path';
import { parse } from 'yaml';

export const ARTICLE_ID_PATTERN = /^\d{8}-\d{6}$/u;
export const CREATED_PATTERN = /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/u;
export const KNOWN_TYPES = new Set(['study', 'wiki']);

export function normalizePath(value) {
  return value.replaceAll('\\', '/').split('/').filter((segment) => segment && segment !== '.').reduce((parts, segment) => {
    if (segment === '..') parts.pop();
    else parts.push(segment.normalize('NFC'));
    return parts;
  }, []).join('/');
}

export function normalizeStringList(value, field, source) {
  if (!Array.isArray(value)) throw new Error(`${source}: ${field} は配列で指定してください`);
  const normalized = [];
  for (const item of value) {
    if (typeof item !== 'string') throw new Error(`${source}: ${field} の要素は文字列で指定してください`);
    const trimmed = item.trim();
    if (trimmed && !normalized.includes(trimmed)) normalized.push(trimmed);
  }
  return normalized;
}

export function parseFrontmatter(markdown, source = '<memory>') {
  if (!markdown.startsWith('---\n') && !markdown.startsWith('---\r\n')) {
    throw new Error(`${source}: Frontmatter がありません`);
  }
  const normalized = markdown.replaceAll('\r\n', '\n');
  const end = normalized.indexOf('\n---\n', 4);
  if (end < 0) throw new Error(`${source}: Frontmatter の終端がありません`);
  let data;
  try {
    data = parse(normalized.slice(4, end));
  } catch (error) {
    throw new Error(`${source}: Frontmatter を解析できません: ${error.message}`);
  }
  if (!data || typeof data !== 'object' || Array.isArray(data)) throw new Error(`${source}: Frontmatter は object で指定してください`);
  return { data, body: normalized.slice(end + 5) };
}

function isRealLocalDateTime(value) {
  if (!CREATED_PATTERN.test(value)) return false;
  const [datePart, timePart] = value.split(' ');
  const [year, month, day] = datePart.split('-').map(Number);
  const [hour, minute, second] = timePart.split(':').map(Number);
  const date = new Date(Date.UTC(year, month - 1, day, hour, minute, second));
  return date.getUTCFullYear() === year && date.getUTCMonth() === month - 1 && date.getUTCDate() === day && hour < 24 && minute < 60 && second < 60;
}

export function normalizeArticle(data, filePath) {
  const sourcePath = normalizePath(filePath);
  const filename = path.posix.basename(sourcePath);
  const stem = filename.replace(/\.md$/iu, '');
  const errors = [];
  const warnings = [];

  if (typeof data.id !== 'string' || !ARTICLE_ID_PATTERN.test(data.id)) errors.push('id は YYYYMMDD-HHmmss 形式の必須文字列です');
  if (data.id !== stem) errors.push(`id ${String(data.id)} と filename ${filename} が一致しません`);

  const title = typeof data.title === 'string' && data.title.trim() ? data.title.trim() : null;
  if (typeof data.type !== 'string' || !data.type.trim()) errors.push('type は必須文字列です');
  const type = typeof data.type === 'string' ? data.type.trim() : '';
  if (type && !KNOWN_TYPES.has(type)) warnings.push(`未知の type "${type}" を拡張値として扱います`);

  let tags = [];
  let aliases = [];
  try { tags = normalizeStringList(data.tags, 'tags', sourcePath); } catch (error) { errors.push(error.message.replace(`${sourcePath}: `, '')); }
  try { aliases = data.aliases == null ? [] : normalizeStringList(data.aliases, 'aliases', sourcePath); } catch (error) { errors.push(error.message.replace(`${sourcePath}: `, '')); }
  aliases = aliases.filter((alias) => alias !== title);
  if (typeof data.created !== 'string' || !isRealLocalDateTime(data.created)) errors.push('created は実在する YYYY-MM-DD HH:mm:ss 形式で指定してください');

  if (errors.length) throw new Error(`${sourcePath}: ${errors.join('; ')}`);
  return {
    article: {
      id: data.id,
      path: sourcePath,
      filename,
      title,
      displayTitle: title ?? '未設定',
      internalLabel: title ?? aliases[0] ?? stem ?? data.id,
      type,
      tags,
      aliases,
      created: data.created
    },
    warnings
  };
}

export function validateArticleSet(records) {
  const seenIds = new Map();
  const seenPaths = new Map();
  for (const record of records) {
    const priorId = seenIds.get(record.id);
    if (priorId) throw new Error(`duplicate id ${record.id}: ${priorId} / ${record.path}`);
    seenIds.set(record.id, record.path);
    const normalizedPath = normalizePath(record.path).toLocaleLowerCase('ja-JP');
    const priorPath = seenPaths.get(normalizedPath);
    if (priorPath) throw new Error(`duplicate path after normalization: ${priorPath} / ${record.path}`);
    seenPaths.set(normalizedPath, record.path);
  }
}

export function buildLinkIndex(records) {
  const index = {};
  const add = (key, candidate) => {
    const normalized = key?.trim().normalize('NFC');
    if (!normalized) return;
    index[normalized] ??= [];
    if (!index[normalized].some((item) => item.id === candidate.id && item.matchedBy === candidate.matchedBy)) index[normalized].push(candidate);
  };
  for (const article of records) {
    const base = { id: article.id, path: article.path };
    add(article.path.replace(/\.md$/iu, ''), { ...base, matchedBy: 'path' });
    add(article.title, { ...base, matchedBy: 'title' });
    for (const alias of article.aliases) add(alias, { ...base, matchedBy: 'alias' });
    add(article.filename.replace(/\.md$/iu, ''), { ...base, matchedBy: 'filename' });
  }
  return Object.fromEntries(Object.entries(index).sort(([a], [b]) => a.localeCompare(b, 'ja')));
}
