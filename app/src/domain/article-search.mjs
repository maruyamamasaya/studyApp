export function normalizeSearchText(value) {
  return String(value ?? '').normalize('NFKC').toLocaleLowerCase('ja');
}

export function matchesArticleFilter(article, query = '', type = 'all') {
  if (type !== 'all' && article.type !== type) return false;
  const terms = normalizeSearchText(query).trim().split(/\s+/u).filter(Boolean);
  if (terms.length === 0) return true;
  const haystack = normalizeSearchText(article.searchText);
  return terms.every((term) => haystack.includes(term));
}

