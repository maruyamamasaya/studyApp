import fs from 'node:fs';
import path from 'node:path';

const rank = { path: 0, title: 1, alias: 2, filename: 3 };

function walk(node, visitor, parent = null, index = -1) {
  visitor(node, parent, index);
  if (Array.isArray(node.children)) {
    for (let childIndex = 0; childIndex < node.children.length; childIndex += 1) {
      walk(node.children[childIndex], visitor, node, childIndex);
    }
  }
}

function slugHeading(value) {
  return value.trim().toLocaleLowerCase('ja-JP').replace(/[\s]+/gu, '-').replace(/[<>"'`]/gu, '');
}

function loadIndex() {
  try {
    return JSON.parse(fs.readFileSync(new URL('../../../generated/link-index.json', import.meta.url), 'utf8'));
  } catch {
    return {};
  }
}

function resolveTarget(index, rawTarget) {
  const [target, ...headingParts] = rawTarget.split('#');
  const heading = headingParts.join('#').trim();
  const normalized = target.trim().replace(/\.md$/iu, '').replaceAll('\\', '/').normalize('NFC');
  const candidates = index[normalized] ?? [];
  if (!candidates.length) return { status: 'unresolved' };
  const bestRank = Math.min(...candidates.map((candidate) => rank[candidate.matchedBy] ?? 99));
  const best = candidates.filter((candidate) => (rank[candidate.matchedBy] ?? 99) === bestRank);
  if (best.length !== 1) return { status: 'ambiguous', candidates: best };
  return { status: 'resolved', href: `/articles/${best[0].id}/${heading ? `#${slugHeading(heading)}` : ''}` };
}

function rewriteStandardMarkdownLink(node, filePath, index) {
  if (typeof node.url !== 'string' || !/\.md(?:#.*)?$/iu.test(node.url)) return;
  const [rawPath, ...headingParts] = node.url.split('#');
  if (/^[a-z]+:/iu.test(rawPath)) return;
  const normalizedFilePath = String(filePath ?? '').replaceAll('\\', '/');
  const marker = '/content/';
  const markerIndex = normalizedFilePath.lastIndexOf(marker);
  if (markerIndex < 0) return;
  const contentPath = normalizedFilePath.slice(markerIndex + marker.length);
  const resolvedPath = path.posix.normalize(path.posix.join(path.posix.dirname(contentPath), rawPath)).replace(/\.md$/iu, '').normalize('NFC');
  const candidates = (index[resolvedPath] ?? []).filter((candidate) => candidate.matchedBy === 'path');
  if (candidates.length !== 1) return;
  const heading = headingParts.join('#').trim();
  node.url = `/articles/${candidates[0].id}/${heading ? `#${slugHeading(heading)}` : ''}`;
}

export function remarkWikiLinks() {
  const linkIndex = loadIndex();
  return (tree, file) => {
    walk(tree, (node, parent, childIndex) => {
      if (node.type === 'link') rewriteStandardMarkdownLink(node, file.path, linkIndex);
      if (node.type !== 'text' || !parent || ['code', 'inlineCode', 'link'].includes(parent.type)) return;
      const pattern = /\[\[([^\]|]+)(?:\|([^\]]+))?\]\]/gu;
      const matches = [...node.value.matchAll(pattern)];
      if (!matches.length) return;
      const replacement = [];
      let cursor = 0;
      for (const match of matches) {
        if (match.index > cursor) replacement.push({ type: 'text', value: node.value.slice(cursor, match.index) });
        const label = (match[2] ?? match[1].split('#').at(-1)).trim();
        const resolved = resolveTarget(linkIndex, match[1]);
        if (resolved.status === 'resolved') {
          replacement.push({ type: 'link', url: resolved.href, title: null, children: [{ type: 'text', value: label }] });
        } else {
          const suffix = resolved.status === 'ambiguous' ? '曖昧' : '未解決';
          replacement.push({ type: 'text', value: `${label}（リンク${suffix}）` });
        }
        cursor = match.index + match[0].length;
      }
      if (cursor < node.value.length) replacement.push({ type: 'text', value: node.value.slice(cursor) });
      parent.children.splice(childIndex, 1, ...replacement);
    });
  };
}
