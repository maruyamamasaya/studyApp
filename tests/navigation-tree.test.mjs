import test from 'node:test';
import assert from 'node:assert/strict';
import { buildNavigationTree } from '../app/src/domain/navigation-tree.mjs';

const entries = [
  { collectionId: 'study/20260929-120000', articleId: '20260929-120000', title: '学習記事' },
  { collectionId: 'wiki/project/20260929-120001', articleId: '20260929-120001', title: 'Wiki記事' }
];

test('記事pathからフォルダ階層を構築する', () => {
  const tree = buildNavigationTree(entries, '/', { study: '学習ノート', wiki: 'Wiki' });
  assert.equal(tree[0].label, '学習ノート');
  assert.equal(tree[1].children[0].label, 'project');
  assert.equal(tree[1].children[0].children[0].label, 'Wiki記事');
});

test('現在の記事と親フォルダをactiveにする', () => {
  const tree = buildNavigationTree(entries, '/articles/20260929-120001/', { study: '学習ノート', wiki: 'Wiki' });
  const wiki = tree[1];
  assert.equal(wiki.containsActive, true);
  assert.equal(wiki.children[0].containsActive, true);
  assert.equal(wiki.children[0].children[0].active, true);
  assert.equal(tree[0].containsActive, false);
});

