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

function contentPathFor(filePath) {
  const normalizedFilePath = String(filePath ?? '').replaceAll('\\', '/');
  const marker = '/content/';
  const markerIndex = normalizedFilePath.lastIndexOf(marker);
  return markerIndex < 0 ? null : normalizedFilePath.slice(markerIndex + marker.length);
}

function resolveTarget(index, rawTarget, filePath) {
  const [target, ...headingParts] = rawTarget.split('#');
  const heading = headingParts.join('#').trim();
  const normalized = target.trim().replace(/\.md$/iu, '').replaceAll('\\', '/').normalize('NFC');
  const contentPath = contentPathFor(filePath);
  const explicitPaths = [normalized];
  if (/^(study|wiki)\//u.test(normalized)) explicitPaths.push(`notes/${normalized}`);
  if (contentPath) explicitPaths.push(path.posix.normalize(path.posix.join(path.posix.dirname(contentPath), normalized)));
  for (const explicitPath of [...new Set(explicitPaths)]) {
    const pathCandidates = (index[explicitPath] ?? []).filter((candidate) => candidate.matchedBy === 'path');
    if (pathCandidates.length === 1) return { status: 'resolved', href: `/articles/${pathCandidates[0].id}/${heading ? `#${slugHeading(heading)}` : ''}` };
    if (pathCandidates.length > 1) return { status: 'ambiguous', candidates: pathCandidates };
  }
  const basename = path.posix.basename(normalized);
  if (/^\d{8}-\d{6}$/u.test(basename)) {
    const idFilenameCandidates = (index[basename] ?? []).filter((candidate) => candidate.matchedBy === 'filename');
    if (idFilenameCandidates.length === 1) return { status: 'resolved', href: `/articles/${idFilenameCandidates[0].id}/${heading ? `#${slugHeading(heading)}` : ''}` };
    if (idFilenameCandidates.length > 1) return { status: 'ambiguous', candidates: idFilenameCandidates };
  }
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
  const contentPath = contentPathFor(filePath);
  if (!contentPath) return;
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
        const resolved = resolveTarget(linkIndex, match[1], file.path);
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
