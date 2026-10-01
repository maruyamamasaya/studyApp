import { createHash } from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';
import { normalizeArticle, normalizePath, parseFrontmatter, validateArticleSet } from './lib/article.mjs';

const DEFAULT_SOURCE_FOLDERS = ['study', 'wiki'];
const projectRoot = path.resolve(fileURLToPath(new URL('..', import.meta.url)));

export async function planObsidianSync({ vaultRoot, repositoryRoot = projectRoot }) {
  const resolvedVault = path.resolve(vaultRoot);
  await requireDirectory(path.join(resolvedVault, '.obsidian'), 'Obsidian Vault ではありません（.obsidian がありません）');

  const entries = [];
  const skipped = [];
  for (const sourceFolder of DEFAULT_SOURCE_FOLDERS) {
    const folderRoot = path.join(resolvedVault, sourceFolder);
    await requireDirectory(folderRoot, `同期元フォルダがありません: ${sourceFolder}`);
    for (const source of await walkMarkdown(folderRoot)) {
      const markdown = await fs.readFile(source, 'utf8');
      const sourceRelative = normalizePath(path.relative(resolvedVault, source));
      if (!markdown.trim()) {
        skipped.push({ source: sourceRelative, reason: '空ファイルのため下書きとして除外' });
        continue;
      }

      const destinationRelative = normalizePath(path.join('docs', sourceRelative));
      const { data } = parseFrontmatter(markdown, sourceRelative);
      const { article } = normalizeArticle(data, sourceRelative);
      if (article.type !== sourceFolder) {
        throw new Error(`${sourceRelative}: type は配置フォルダに合わせて ${sourceFolder} を指定してください（現在 ${article.type}）`);
      }
      entries.push({
        id: article.id,
        article,
        source: sourceRelative,
        destination: destinationRelative,
        sha256: digest(markdown),
        markdown
      });
    }
  }
  validateArticleSet(entries.map((entry) => ({ id: entry.id, path: entry.destination })));

  const manifestPath = path.join(repositoryRoot, 'obsidian-sync-manifest.json');
  let previous = { entries: [] };
  try {
    previous = JSON.parse(await fs.readFile(manifestPath, 'utf8'));
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
  }
  const previousByDestination = new Map(previous.entries.map((entry) => [entry.destination, entry]));
  const previouslyManagedDestinations = new Set(previous.entries.map((entry) => entry.destination));

  const changes = [];
  for (const entry of entries) {
    const destination = path.join(repositoryRoot, entry.destination);
    let current = null;
    try { current = await fs.readFile(destination, 'utf8'); } catch (error) { if (error.code !== 'ENOENT') throw error; }
    if (current === entry.markdown) continue;
    if (current !== null && !previousByDestination.has(entry.destination)) {
      throw new Error(`${entry.destination}: 同期管理外の既存ファイルは上書きしません`);
    }
    if (current !== null && digest(current) !== previousByDestination.get(entry.destination)?.sha256) {
      throw new Error(`${entry.destination}: 同期先を直接変更しているため上書きしません`);
    }
    changes.push({ action: current === null ? 'add' : 'update', ...entry });
  }

  const currentDestinations = new Set(entries.map((entry) => entry.destination));
  const stale = previous.entries.filter((entry) => !currentDestinations.has(entry.destination));
  for (const entry of stale) {
    if (!/^docs\/(study|wiki)\//u.test(entry.destination) || entry.destination.includes('..') || entry.destination.includes('\\')) throw new Error('同期manifestの削除pathが不正です');
    try {
      const current = await fs.readFile(path.join(repositoryRoot, entry.destination), 'utf8');
      if (digest(current) !== entry.sha256) throw new Error(`${entry.destination}: 同期後に変更されているため削除しません`);
    } catch (error) { if (error.code !== 'ENOENT') throw error; }
  }
  const mirrorRoot = path.join(repositoryRoot, 'docs');
  let mirrorFiles = [];
  try {
    for (const folder of DEFAULT_SOURCE_FOLDERS) {
      const directory = path.join(mirrorRoot, folder);
      try { mirrorFiles.push(...await walkMarkdown(directory)); } catch (error) { if (error.code !== 'ENOENT') throw error; }
    }
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
  }
  const unmanaged = mirrorFiles
    .map((file) => normalizePath(path.relative(repositoryRoot, file)))
    .filter((destination) => !currentDestinations.has(destination) && !previouslyManagedDestinations.has(destination));
  if (unmanaged.length) {
    throw new Error(`docs/study と docs/wiki は Vault の生成ミラーです。同期元にない記事があります: ${unmanaged.join(', ')}`);
  }
  return { repositoryRoot, manifestPath, entries, skipped, changes, stale };
}

export async function applyObsidianSync(plan, { prune = false } = {}) {
  for (const change of plan.changes) {
    const destination = path.join(plan.repositoryRoot, change.destination);
    await fs.mkdir(path.dirname(destination), { recursive: true });
    await fs.writeFile(destination, change.markdown);
  }

  const pruned = [];
  if (prune) {
    for (const stale of plan.stale) {
      const destination = path.join(plan.repositoryRoot, stale.destination);
      let current;
      try { current = await fs.readFile(destination, 'utf8'); } catch (error) { if (error.code === 'ENOENT') continue; throw error; }
      if (digest(current) !== stale.sha256) {
        throw new Error(`${stale.destination}: 同期後に変更されているため削除しません`);
      }
      await fs.unlink(destination);
      pruned.push(stale.destination);
    }
  }

  await fs.mkdir(path.dirname(plan.manifestPath), { recursive: true });
  await fs.writeFile(plan.manifestPath, `${JSON.stringify({
    version: 1,
    sourceFolders: DEFAULT_SOURCE_FOLDERS,
    entries: plan.entries.map(({ markdown, ...entry }) => entry),
    skipped: plan.skipped
  }, null, 2)}\n`);
  await fs.mkdir(path.join(plan.repositoryRoot, 'docs'), { recursive: true });
  await fs.writeFile(path.join(plan.repositoryRoot, 'docs/_article-metadata.json'), JSON.stringify(plan.entries.map((entry) => entry.article), null, 2) + '\n');
  const label = (value) => value.replace(/[\\`*_[\]<>#]/gu, '\\$&').replace(/[\r\n]/gu, ' ');
  const links = plan.entries.map((entry) => `- [${label(entry.article.displayTitle)}](${entry.source.split('/').map(encodeURIComponent).join('/')})`);
  await fs.writeFile(path.join(plan.repositoryRoot, 'docs/README.md'), '# Study Notes\n\n' + links.join('\n') + '\n');
  await fs.writeFile(path.join(plan.repositoryRoot, 'docs/_sidebar.md'), '[ホーム](/)\n\n' + links.join('\n') + '\n');
  await fs.mkdir(path.join(plan.repositoryRoot, 'docs/training'), { recursive: true });
  const studyLinks = plan.entries.filter((entry) => entry.article.type === 'study').map((entry) => `- [${label(entry.article.displayTitle)}](../#/${entry.source.replace(/\.md$/u, '').split('/').map(encodeURIComponent).join('/')})`);
  await fs.writeFile(path.join(plan.repositoryRoot, 'docs/training/README.md'), '# 研修資料\n\n' + (studyLinks.join('\n') || '学習記事はまだありません。') + '\n');
  return { pruned };
}

async function walkMarkdown(directory) {
  const entries = await fs.readdir(directory, { withFileTypes: true });
  const files = await Promise.all(entries.map(async (entry) => {
    if (entry.isSymbolicLink()) throw new Error(`同期対象のsymlinkは使用できません: ${entry.name}`);
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) return walkMarkdown(absolute);
    return entry.isFile() && entry.name.toLowerCase().endsWith('.md') ? [absolute] : [];
  }));
  return files.flat().sort((a, b) => a.localeCompare(b, 'ja'));
}

async function requireDirectory(directory, message) {
  try {
    if ((await fs.stat(directory)).isDirectory()) return;
  } catch {
    // Use the shared actionable error below.
  }
  throw new Error(`${message}: ${directory}`);
}

function digest(value) {
  return createHash('sha256').update(value).digest('hex');
}

async function main() {
  const args = process.argv.slice(2);
  const checkOnly = args.includes('--check');
  const prune = args.includes('--prune');
  const vaultArgument = args.find((arg) => !arg.startsWith('--')) ?? process.env.STUDY_APP_VAULT;
  if (!vaultArgument) {
    throw new Error('Vault path が必要です。例: npm run vault:sync -- "C:\\path\\to\\Vault"');
  }
  const plan = await planObsidianSync({ vaultRoot: vaultArgument });
  for (const item of plan.skipped) console.warn(`SKIP ${item.source}: ${item.reason}`);
  for (const change of plan.changes) console.log(`${checkOnly ? 'PENDING' : change.action.toUpperCase()} ${change.source} -> ${change.destination}`);
  for (const stale of plan.stale) console.warn(`${prune ? 'PRUNE' : 'STALE'} ${stale.destination}`);
  if (!checkOnly) await applyObsidianSync(plan, { prune });
  console.log(`${plan.entries.length} 件を検証、${plan.changes.length} 件の差分、${plan.skipped.length} 件の下書きを除外しました。`);
  if (checkOnly && (plan.changes.length || plan.stale.length)) process.exitCode = 2;
}

if (path.resolve(process.argv[1] ?? '') === fileURLToPath(import.meta.url)) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
