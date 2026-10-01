(function () {
  'use strict';
  const config = window.READER_TOOLS_CONFIG || {};
  if (config.pathPrefix) return;
  const storageKey = 'study-notes:open-folders';
  function readOpenFolders() {
    try { return new Set(JSON.parse(localStorage.getItem(storageKey) || '[]')); }
    catch (_) { return new Set(); }
  }
  window.$docsify = window.$docsify || {};
  window.$docsify.plugins = (window.$docsify.plugins || []).concat(function (hook, vm) {
    hook.doneEach(function () {
      const route = decodeURIComponent(vm.route.path).replace(/^\//, '').replace(/\.md$/, '');
      window.studyArticleMetadata.then(function (articles) {
        if (route !== decodeURIComponent(vm.route.path).replace(/^\//, '').replace(/\.md$/, '')) return;
        const sidebar = document.querySelector('.sidebar-nav');
        if (!sidebar) return;
        const openFolders = readOpenFolders();
        const root = { folders: new Map(), articles: [] };
        articles.forEach(function (article) {
          const parts = article.path.split('/');
          parts.pop();
          let node = root;
          parts.forEach(function (part) {
            if (!node.folders.has(part)) node.folders.set(part, { folders: new Map(), articles: [] });
            node = node.folders.get(part);
          });
          node.articles.push(article);
        });
        const tree = document.createElement('nav');
        tree.className = 'wiki-tree';
        tree.setAttribute('aria-label', '記事のフォルダ');
        const heading = document.createElement('div');
        heading.className = 'wiki-tree__heading';
        heading.textContent = 'フォルダ';
        tree.appendChild(heading);
        function render(node, container, parentPath) {
          [...node.folders.entries()].sort(([a], [b]) => a.localeCompare(b, 'ja')).forEach(function ([name, child]) {
            const folderPath = parentPath ? parentPath + '/' + name : name;
            const details = document.createElement('details');
            details.className = 'wiki-tree__folder';
            details.open = route.startsWith(folderPath + '/') || openFolders.has(folderPath)
              || (!parentPath && localStorage.getItem(storageKey) === null);
            const summary = document.createElement('summary');
            summary.textContent = name;
            summary.title = folderPath;
            details.appendChild(summary);
            const children = document.createElement('div');
            children.className = 'wiki-tree__children';
            render(child, children, folderPath);
            details.appendChild(children);
            details.addEventListener('toggle', function () {
              if (details.open) openFolders.add(folderPath);
              else openFolders.delete(folderPath);
              localStorage.setItem(storageKey, JSON.stringify([...openFolders]));
            });
            container.appendChild(details);
          });
          node.articles.sort((a, b) => a.displayTitle.localeCompare(b.displayTitle, 'ja')).forEach(function (article) {
            const link = document.createElement('a');
            const articleRoute = article.path.replace(/\.md$/, '');
            link.className = 'wiki-tree__article';
            link.href = '#/' + articleRoute.split('/').map(encodeURIComponent).join('/');
            link.textContent = article.displayTitle;
            link.title = article.displayTitle;
            if (articleRoute === route) link.setAttribute('aria-current', 'page');
            container.appendChild(link);
          });
        }
        render(root, tree, '');
        sidebar.replaceChildren(tree);
      }).catch(function (error) { console.warn('[Folder navigation]', error); });
    });
  });
})();
