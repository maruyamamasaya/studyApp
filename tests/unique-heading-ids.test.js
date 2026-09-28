const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const source = fs.readFileSync('docs/unique-heading-ids.js', 'utf8');
const context = { window: { $docsify: {} } };
vm.runInNewContext(source, context);

const plugin = context.window.$docsify.plugins[0];
let transform;
plugin({
  beforeEach(callback) {
    transform = callback;
  },
});

const markdown = [
  '# 1.',
  '### 例',
  '### ポイント',
  '# 2.',
  '### 例',
  '### ポイント',
].join('\n');

assert.equal(
  transform(markdown),
  [
    '# 1.',
    '### 例',
    '### ポイント',
    '# 2.',
    '### 例 :id=heading-2',
    '### ポイント :id=heading-3',
  ].join('\n')
);

assert.equal(
  transform('### 例\n```md\n### 例\n```\n### 例'),
  '### 例\n```md\n### 例\n```\n### 例 :id=heading-2'
);

assert.equal(
  transform('### 例\n### 例-2\n### 例'),
  '### 例\n### 例-2\n### 例 :id=heading-2'
);

assert.equal(
  transform('### 例\n### 例\n### heading-2'),
  '### 例\n### 例 :id=heading-3\n### heading-2'
);

const transformedTocExample = transform(markdown);
const tocLabels = transformedTocExample
  .split('\n')
  .filter((line) => /^#{1,4}\s+/.test(line))
  .map((line) => line.replace(/^#{1,4}\s+/, '').replace(/\s+:id=[A-Za-z0-9_-]+$/, ''));

assert.deepEqual(
  tocLabels,
  ['1.', '例', 'ポイント', '2.', '例', 'ポイント']
);

assert.equal(
  transform('### 例 :id=custom\n### 例 :id=custom-2'),
  '### 例 :id=custom\n### 例 :id=custom-2'
);

console.log('unique heading ID tests passed');
