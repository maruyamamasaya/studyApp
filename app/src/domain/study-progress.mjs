export const PROGRESS_VERSION = 2;
export const PROGRESS_PREFIX = 'study:v2:progress:';
export const BACKUP_FORMAT = 'study-notes-backup';

export function createDefaultProgress() {
  return {
    version: PROGRESS_VERSION,
    completed: false,
    completedUpdatedAt: null,
    learningSeconds: 0,
    lastViewedAt: null
  };
}

function normalizeTimestamp(value) {
  if (value == null) return null;
  if (typeof value !== 'string' || Number.isNaN(Date.parse(value))) throw new Error('日時が不正です');
  return new Date(value).toISOString();
}

export function normalizeProgress(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('学習状態は object で指定してください');
  if (value.version !== PROGRESS_VERSION) throw new Error(`学習状態 version ${PROGRESS_VERSION} ではありません`);
  if (typeof value.completed !== 'boolean') throw new Error('completed は boolean で指定してください');
  if (!Number.isFinite(value.learningSeconds) || !Number.isInteger(value.learningSeconds) || value.learningSeconds < 0) {
    throw new Error('learningSeconds は0以上の整数で指定してください');
  }
  return {
    version: PROGRESS_VERSION,
    completed: value.completed,
    completedUpdatedAt: normalizeTimestamp(value.completedUpdatedAt),
    learningSeconds: value.learningSeconds,
    lastViewedAt: normalizeTimestamp(value.lastViewedAt)
  };
}

export function progressKey(articleId) {
  if (typeof articleId !== 'string' || !articleId.trim()) throw new Error('articleId がありません');
  return `${PROGRESS_PREFIX}${articleId}`;
}

function newerTimestamp(left, right) {
  const leftTime = left ? Date.parse(left) : Number.NEGATIVE_INFINITY;
  const rightTime = right ? Date.parse(right) : Number.NEGATIVE_INFINITY;
  return rightTime > leftTime ? right : left;
}

export function mergeProgress(currentValue, importedValue) {
  const current = normalizeProgress(currentValue);
  const imported = normalizeProgress(importedValue);
  const importedCompletionIsNewer = Date.parse(imported.completedUpdatedAt ?? '') > Date.parse(current.completedUpdatedAt ?? '');
  const completionHasTimestamp = current.completedUpdatedAt || imported.completedUpdatedAt;
  return {
    version: PROGRESS_VERSION,
    completed: completionHasTimestamp
      ? (importedCompletionIsNewer ? imported.completed : current.completed)
      : current.completed || imported.completed,
    completedUpdatedAt: newerTimestamp(current.completedUpdatedAt, imported.completedUpdatedAt),
    learningSeconds: Math.max(current.learningSeconds, imported.learningSeconds),
    lastViewedAt: newerTimestamp(current.lastViewedAt, imported.lastViewedAt)
  };
}

export function formatLearningTime(seconds) {
  const total = Math.max(0, Math.floor(Number(seconds) || 0));
  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  const remainder = total % 60;
  if (hours) return `${hours}時間${minutes}分`;
  if (minutes) return `${minutes}分${remainder}秒`;
  return `${remainder}秒`;
}

export function createBackup(progressRecords, exportedAt = new Date().toISOString()) {
  const progress = {};
  for (const [articleId, value] of Object.entries(progressRecords)) progress[articleId] = normalizeProgress(value);
  return {
    format: BACKUP_FORMAT,
    version: PROGRESS_VERSION,
    exportedAt: normalizeTimestamp(exportedAt),
    records: { progress, checklists: {} }
  };
}

export function parseBackup(value) {
  const backup = typeof value === 'string' ? JSON.parse(value) : value;
  if (!backup || typeof backup !== 'object' || backup.format !== BACKUP_FORMAT || backup.version !== PROGRESS_VERSION) {
    throw new Error('Study App version 2 のバックアップではありません');
  }
  if (!backup.records || typeof backup.records.progress !== 'object' || Array.isArray(backup.records.progress)) {
    throw new Error('progress records がありません');
  }
  const progress = {};
  for (const [articleId, record] of Object.entries(backup.records.progress)) progress[articleId] = normalizeProgress(record);
  return { ...backup, records: { progress, checklists: backup.records.checklists ?? {} } };
}

export class LocalStudyProgressRepository {
  constructor(storage) {
    this.storage = storage;
  }

  async get(articleId) {
    const raw = this.storage.getItem(progressKey(articleId));
    if (raw == null) return createDefaultProgress();
    try {
      return normalizeProgress(JSON.parse(raw));
    } catch (error) {
      console.warn(`[Study progress] ${articleId} の保存データを読み込めませんでした`, error);
      return createDefaultProgress();
    }
  }

  async save(articleId, progress) {
    const normalized = normalizeProgress(progress);
    this.storage.setItem(progressKey(articleId), JSON.stringify(normalized));
    return normalized;
  }

  async list() {
    const records = {};
    for (let index = 0; index < this.storage.length; index += 1) {
      const key = this.storage.key(index);
      if (!key?.startsWith(PROGRESS_PREFIX)) continue;
      const articleId = key.slice(PROGRESS_PREFIX.length);
      const raw = this.storage.getItem(key);
      try {
        records[articleId] = normalizeProgress(JSON.parse(raw));
      } catch (error) {
        console.warn(`[Study progress] ${articleId} の保存データを一覧から除外しました`, error);
      }
    }
    return records;
  }

  async importBackup(value) {
    const backup = parseBackup(value);
    for (const [articleId, imported] of Object.entries(backup.records.progress)) {
      const current = await this.get(articleId);
      await this.save(articleId, mergeProgress(current, imported));
    }
    return Object.keys(backup.records.progress).length;
  }
}

export function summarizeStudyProgress(studyArticleIds, records) {
  const progress = studyArticleIds.map((id) => records[id] ?? createDefaultProgress());
  return {
    completedCount: progress.filter((item) => item.completed).length,
    totalCount: progress.length,
    learningSeconds: progress.reduce((sum, item) => sum + item.learningSeconds, 0)
  };
}
