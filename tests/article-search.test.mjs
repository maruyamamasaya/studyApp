import test from 'node:test';
import assert from 'node:assert/strict';
import { matchesArticleFilter, normalizeSearchText } from '../app/src/domain/article-search.mjs';

const article = {
  type: 'study',
  searchText: '数値計算の誤差 応用情報 丸め誤差'
};

test('検索文字列を全角・半角と大文字・小文字をまたいで正規化する', () => {
  assert.equal(normalizeSearchText('ＡＷＳ Security'), 'aws security');
});

test('空白区切りの検索語をすべて含む記事だけに一致する', () => {
  assert.equal(matchesArticleFilter(article, '数値 誤差'), true);
  assert.equal(matchesArticleFilter(article, '数値 AWS'), false);
});

test('studyとwikiを記事種別で絞り込む', () => {
  assert.equal(matchesArticleFilter(article, '', 'all'), true);
  assert.equal(matchesArticleFilter(article, '', 'study'), true);
  assert.equal(matchesArticleFilter(article, '', 'wiki'), false);
});

