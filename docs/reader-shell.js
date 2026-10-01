(function () {
  'use strict';
  const mobile = window.matchMedia('(max-width: 900px)');
  function closeLibrary() {
    if (!mobile.matches || document.body.classList.contains('desktop-sidebar-collapsed')) return;
    document.querySelector('.reader-sidebar-toggle')?.click();
  }
  window.$docsify = window.$docsify || {};
  window.$docsify.plugins = (window.$docsify.plugins || []).concat(function (hook, vm) {
    hook.doneEach(function () {
      let backdrop = document.querySelector('.library-panel-backdrop');
      if (!backdrop) {
        backdrop = document.createElement('button');
        backdrop.className = 'library-panel-backdrop';
        backdrop.setAttribute('aria-label', '記事パネルを閉じる');
        backdrop.hidden = true;
        backdrop.addEventListener('click', closeLibrary);
        document.body.appendChild(backdrop);
        const update = function () {
          backdrop.hidden = !mobile.matches || document.body.classList.contains('desktop-sidebar-collapsed');
          const sidebar = document.querySelector('.sidebar');
          if (sidebar) sidebar.inert = mobile.matches && document.body.classList.contains('desktop-sidebar-collapsed');
          const toggle = document.querySelector('.reader-sidebar-toggle');
          if (toggle) toggle.textContent = document.body.classList.contains('desktop-sidebar-collapsed') ? '☰' : '×';
        };
        new MutationObserver(update).observe(document.body, { attributes: true, attributeFilter: ['class'] });
        mobile.addEventListener('change', update);
        document.addEventListener('keydown', function (event) { if (event.key === 'Escape') closeLibrary(); });
        document.querySelector('.sidebar')?.addEventListener('click', function (event) {
          if (event.target.closest('a')) closeLibrary();
        });
        update();
      }
      const navigation = document.querySelector('.reader-navigation');
      if (navigation) navigation.hidden = false;
      document.querySelectorAll('.reader-navigation .reader-toc, .reader-navigation .reader-search')
        .forEach(function (button) { button.hidden = false; });
      document.querySelectorAll('.reader-navigation .reader-back, .reader-navigation .reader-forward')
        .forEach(function (button) { button.hidden = true; });
      const section = document.querySelector('.markdown-section');
      const meta = section?.querySelector('.reader-meta');
      const heading = section?.querySelector('h1');
      if (meta && heading) heading.after(meta);
      if (vm.route.path !== '/' || !window.studyArticleMetadata || window.READER_TOOLS_CONFIG?.pathPrefix) return;
      window.studyArticleMetadata.then(function (articles) {
        if (vm.route.path !== '/') return;
        const title = section.querySelector('h1');
        if (title) title.textContent = '記事ライブラリ';
        const intro = document.createElement('p');
        intro.className = 'library-intro';
        intro.textContent = '学びと調査を、ひとつの場所に。フォルダや検索から読みたい記事を探せます。';
        const oldIntro = section.querySelector('.library-intro');
        oldIntro?.remove();
        section.querySelector('.reader-meta')?.after(intro);
        const list = section.querySelector('ul');
        if (!list) return;
        list.replaceChildren();
        articles.forEach(function (article) {
          const row = document.createElement('li');
          const link = document.createElement('a');
          link.href = '#/' + article.path.replace(/\.md$/, '').split('/').map(encodeURIComponent).join('/');
          const folder = document.createElement('span');
          folder.className = 'library-heading';
          folder.textContent = article.path.split('/').slice(0, -1).join(' / ');
          const name = document.createElement('strong');
          name.textContent = article.displayTitle;
          link.append(folder, name);
          if (article.tags.length) {
            const tags = document.createElement('span');
            tags.className = 'library-count';
            tags.textContent = article.tags.map(tag => '#' + tag).join('  ');
            link.appendChild(tags);
          }
          row.appendChild(link);
          list.appendChild(row);
        });
      }).catch(function (error) { console.warn('[Reader shell]', error); });
    });
  });
})();
