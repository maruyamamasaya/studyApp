import test from 'node:test';
import assert from 'node:assert/strict';
import {
  createBackup,
  createDefaultProgress,
  formatLearningTime,
  LocalStudyProgressRepository,
  mergeProgress,
  parseBackup,
  progressKey,
  summarizeStudyProgress
} from '../app/src/domain/study-progress.mjs';

class MemoryStorage {
  constructor() { this.values = new Map(); }
  get length() { return this.values.size; }
  key(index) { return [...this.values.keys()][index] ?? null; }
  getItem(key) { return this.values.get(key) ?? null; }
  setItem(key, value) { this.values.set(key, String(value)); }
}

test('記事IDごとに version 2 の学習状態を保存する', async () => {
  const storage = new MemoryStorage();
  const repository = new LocalStudyProgressRepository(storage);
  assert.deepEqual(await repository.get('20260929-121500'), createDefaultProgress());
  const progress = { ...createDefaultProgress(), learningSeconds: 42, lastViewedAt: '2026-09-29T05:00:00.000Z' };
  await repository.save('20260929-121500', progress);
  assert.equal(storage.getItem(progressKey('20260929-121500')), JSON.stringify(progress));
  assert.deepEqual(await repository.get('20260929-121500'), progress);
});

test('不正な学習時間を保存しない', async () => {
  const repository = new LocalStudyProgressRepository(new MemoryStorage());
  await assert.rejects(repository.save('20260929-121500', { ...createDefaultProgress(), learningSeconds: -1 }), /0以上の整数/u);
});

test('バックアップを検証し、大きい学習時間と新しい読了状態をマージする', async () => {
  const current = { ...createDefaultProgress(), completed: false, completedUpdatedAt: '2026-09-29T04:00:00.000Z', learningSeconds: 120 };
  const imported = { ...createDefaultProgress(), completed: true, completedUpdatedAt: '2026-09-29T05:00:00.000Z', learningSeconds: 90 };
  assert.deepEqual(mergeProgress(current, imported), { ...imported, learningSeconds: 120 });
  const backup = createBackup({ '20260929-121500': imported }, '2026-09-29T06:00:00.000Z');
  assert.deepEqual(parseBackup(JSON.stringify(backup)), backup);
});

test('study 記事IDだけで読了数と合計時間を集計する', () => {
  const records = {
    study1: { ...createDefaultProgress(), completed: true, learningSeconds: 30 },
    study2: { ...createDefaultProgress(), learningSeconds: 10 },
    wiki1: { ...createDefaultProgress(), completed: true, learningSeconds: 999 }
  };
  assert.deepEqual(summarizeStudyProgress(['study1', 'study2'], records), { completedCount: 1, totalCount: 2, learningSeconds: 40 });
  assert.equal(formatLearningTime(3661), '1時間1分');
});
