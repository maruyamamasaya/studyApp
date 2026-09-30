export function buildNavigationTree(entries, currentPath, rootLabels = {}) {
  const nodes = [];

  for (const entry of entries) {
    const folders = entry.collectionId.split('/').slice(0, -1);
    let children = nodes;
    const keyParts = [];

    folders.forEach((folder, depth) => {
      keyParts.push(folder);
      const key = keyParts.join('/');
      let node = children.find((candidate) => candidate.kind === 'folder' && candidate.key === key);
      if (!node) {
        node = {
          kind: 'folder',
          key,
          label: depth === 0 ? (rootLabels[folder] ?? folder) : folder,
          depth,
          containsActive: false,
          children: []
        };
        children.push(node);
      }
      children = node.children;
    });

    const href = `/articles/${entry.articleId}/`;
    children.push({
      kind: 'article',
      key: entry.articleId,
      label: entry.title ?? '未設定',
      href,
      active: currentPath === href
    });
  }

  const markActiveBranches = (items) => items.some((item) => {
    if (item.kind === 'article') return item.active;
    item.containsActive = markActiveBranches(item.children);
    return item.containsActive;
  });
  markActiveBranches(nodes);
  return nodes;
}

