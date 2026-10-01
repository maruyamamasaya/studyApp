(function () {
  'use strict';
  const config = window.READER_TOOLS_CONFIG || {};
  const metadata = fetch(config.metadataFile || '_article-metadata.json').then(function (response) {
    if (!response.ok) throw new Error('記事情報を読み込めません');
    return response.json();
  });
  window.studyArticleMetadata = metadata;
  window.$docsify = window.$docsify || {};
  window.$docsify.plugins = (window.$docsify.plugins || []).concat(function (hook, vm) {
    hook.beforeEach(function (markdown, next) {
      const body = markdown.replace(/^---\r?\n[\s\S]*?\r?\n---(?:\r?\n|$)/u, '');
      metadata.then(function (articles) {
        let route = decodeURIComponent(vm.route.path).replace(/^\//u, '').replace(/\.md$/u, '');
        if (config.pathPrefix) route = config.pathPrefix + '/' + route;
        const article = articles.find(function (item) { return item.path.replace(/\.md$/u, '') === route; });
        const title = article && (article.title || '未設定');
        next(title ? '# ' + title.replace(/[\\`*_[\]<>#]/gu, '\\$&').replace(/[\r\n]/gu, ' ') + '\n\n' + body : body);
      }).catch(function (error) { console.error(error); next(body); });
    });
    hook.afterEach(function (html) {
      // The renderer may output article HTML. Sanitize before inserting it into the DOM.
      return window.DOMPurify.sanitize(html);
    });
  });
})();
