(function () {
  'use strict';

  const READER_CONFIG = window.READER_TOOLS_CONFIG || {};
  const JAPANESE_CHARACTERS_PER_MINUTE = 500;
  const MOBILE_HEADER_BREAKPOINT = 600;
  const SIDEBAR_LAYOUT_BREAKPOINT = 1100;
  const HOMEPAGE_FILE = READER_CONFIG.homepageFile || '📚 Study Notes Hub.md';
  const ARTICLE_MASTER_FILE = READER_CONFIG.articleMasterFile || '_article-master.json';
  const NOTE_INDEX_FILE = READER_CONFIG.noteIndexFile || '_note-index.json';
  const PATH_PREFIX = READER_CONFIG.pathPrefix || '';
  const SHOW_BACKUP_LINK = READER_CONFIG.showBackupLink !== false;
  const ARTICLE_STORAGE_PREFIX = 'study-notes:article:';
  const CHECKLIST_STORAGE_PREFIX = 'study-notes-checklist::';
  const BACKUP_PAGE_FILE = READER_CONFIG.backupPageFile || 'バックアップ・復元.md';
  const BACKUP_FORMAT = 'study-notes-backup';
  const BACKUP_VERSION = 1;
  const THEME_STORAGE_KEY = 'study-notes:theme';
  const SIDEBAR_WIDTH_STORAGE_KEY = 'study-notes:sidebar-width';
  const DESKTOP_SIDEBAR_MIN_WIDTH = 220;
  const DESKTOP_SIDEBAR_MAX_WIDTH = 520;
  const THEME_COUNT = 5;
  const THEME_COLORS = ['#0d1117', '#0d1117', '#0d1117', '#f7f7f5', '#000000'];
  let noteIndexPromise = null;
  let articleMasterPromise = null;
  let activeArticle = null;
  let activeStartedAt = null;
  let articleLoadSequence = 0;
  let desktopSidebarOverride = null;

  function isDesktopLayout() {
    return window.matchMedia('(min-width: ' + (MOBILE_HEADER_BREAKPOINT + 1) + 'px)').matches;
  }

  function isWideSidebarLayout() {
    return window.matchMedia('(min-width: ' + SIDEBAR_LAYOUT_BREAKPOINT + 'px)').matches;
  }

  function getDesktopSidebarWidth() {
    const storedValue = window.localStorage.getItem(SIDEBAR_WIDTH_STORAGE_KEY);
    const storedWidth = Number(storedValue);
    if (storedValue === null || !Number.isFinite(storedWidth)) {
      return 300;
    }
    return Math.min(DESKTOP_SIDEBAR_MAX_WIDTH, Math.max(DESKTOP_SIDEBAR_MIN_WIDTH, storedWidth));
  }

  function applyDesktopSidebarState() {
    const wideSidebarLayout = isWideSidebarLayout();
    const collapsed = desktopSidebarOverride === null
      ? !wideSidebarLayout
      : desktopSidebarOverride;
    document.documentElement.style.setProperty('--desktop-sidebar-width', getDesktopSidebarWidth() + 'px');
    document.body.classList.toggle('sidebar-wide-layout', wideSidebarLayout);
    document.body.classList.toggle('desktop-sidebar-collapsed', collapsed);

    const toggle = document.querySelector('.reader-sidebar-toggle');
    if (toggle) {
      toggle.setAttribute('aria-expanded', String(!collapsed));
      toggle.setAttribute('aria-label', collapsed ? 'サイドバーを表示' : 'サイドバーを非表示');
      toggle.title = collapsed ? 'サイドバーを表示' : 'サイドバーを非表示';
      toggle.textContent = collapsed ? '›' : '‹';
    }
  }

  function createDesktopSidebarControls() {
    if (document.querySelector('.reader-sidebar-toggle')) {
      applyDesktopSidebarState();
      return;
    }

    const sidebar = document.querySelector('.sidebar');
    if (!sidebar) {
      return;
    }

    const toggle = document.createElement('button');
    toggle.className = 'reader-sidebar-toggle';
    toggle.type = 'button';
    toggle.addEventListener('click', function () {
      const isCollapsed = document.body.classList.contains('desktop-sidebar-collapsed');
      desktopSidebarOverride = !isCollapsed;
      applyDesktopSidebarState();
    });
    document.body.appendChild(toggle);

    const resizer = document.createElement('div');
    resizer.className = 'reader-sidebar-resizer';
    resizer.setAttribute('role', 'separator');
    resizer.setAttribute('aria-label', 'サイドバーの幅を調節');
    resizer.setAttribute('aria-orientation', 'vertical');
    resizer.tabIndex = 0;

    function setWidth(width) {
      const nextWidth = Math.min(DESKTOP_SIDEBAR_MAX_WIDTH, Math.max(DESKTOP_SIDEBAR_MIN_WIDTH, width));
      window.localStorage.setItem(SIDEBAR_WIDTH_STORAGE_KEY, String(Math.round(nextWidth)));
      document.documentElement.style.setProperty('--desktop-sidebar-width', nextWidth + 'px');
      resizer.setAttribute('aria-valuenow', String(Math.round(nextWidth)));
    }

    resizer.addEventListener('pointerdown', function (event) {
      if (!isDesktopLayout()) {
        return;
      }
      resizer.setPointerCapture(event.pointerId);
      document.body.classList.add('is-resizing-sidebar');
    });
    resizer.addEventListener('pointermove', function (event) {
      if (resizer.hasPointerCapture(event.pointerId)) {
        setWidth(event.clientX);
      }
    });
    resizer.addEventListener('pointerup', function (event) {
      if (resizer.hasPointerCapture(event.pointerId)) {
        resizer.releasePointerCapture(event.pointerId);
      }
      document.body.classList.remove('is-resizing-sidebar');
    });
    resizer.addEventListener('pointercancel', function () {
      document.body.classList.remove('is-resizing-sidebar');
    });
    resizer.addEventListener('keydown', function (event) {
      if (event.key !== 'ArrowLeft' && event.key !== 'ArrowRight') {
        return;
      }
      event.preventDefault();
      setWidth(getDesktopSidebarWidth() + (event.key === 'ArrowRight' ? 10 : -10));
    });
    sidebar.appendChild(resizer);
    resizer.setAttribute('aria-valuemin', String(DESKTOP_SIDEBAR_MIN_WIDTH));
    resizer.setAttribute('aria-valuemax', String(DESKTOP_SIDEBAR_MAX_WIDTH));
    resizer.setAttribute('aria-valuenow', String(getDesktopSidebarWidth()));

    window.matchMedia('(min-width: ' + (MOBILE_HEADER_BREAKPOINT + 1) + 'px)')
      .addEventListener('change', function () {
        createReaderNavigation();
      });
    window.matchMedia('(min-width: ' + SIDEBAR_LAYOUT_BREAKPOINT + 'px)')
      .addEventListener('change', function () {
        desktopSidebarOverride = null;
        applyDesktopSidebarState();
      });
    applyDesktopSidebarState();
  }

  function getCurrentTheme() {
    const storedTheme = window.localStorage.getItem(THEME_STORAGE_KEY);
    return /^[1-5]$/.test(storedTheme || '') ? Number(storedTheme) : 1;
  }

  function applyTheme(theme) {
    const selectedTheme = theme >= 1 && theme <= THEME_COUNT ? theme : 1;
    document.documentElement.dataset.theme = String(selectedTheme);
    document.querySelector('meta[name="theme-color"]')
      .setAttribute('content', THEME_COLORS[selectedTheme - 1]);

    const button = document.querySelector('.reader-theme');
    if (button) {
      button.querySelector('.reader-theme__number').textContent = String(selectedTheme);
      button.setAttribute(
        'aria-label',
        'テーマ ' + selectedTheme + ' を使用中。押すと次のテーマに変更'
      );
      button.title = 'テーマ ' + selectedTheme + ' / ' + THEME_COUNT;
    }
  }

  function createThemeSwitcher() {
    if (document.querySelector('.reader-theme')) {
      applyTheme(getCurrentTheme());
      return;
    }

    const button = document.createElement('button');
    button.className = 'reader-theme';
    button.type = 'button';
    button.innerHTML =
      '<span class="reader-theme__number" aria-hidden="true"></span>' +
      '<span class="reader-theme__label">テーマ</span>';
    button.addEventListener('click', function () {
      const nextTheme = getCurrentTheme() % THEME_COUNT + 1;
      window.localStorage.setItem(THEME_STORAGE_KEY, String(nextTheme));
      applyTheme(nextTheme);
    });
    document.body.appendChild(button);
    applyTheme(getCurrentTheme());
  }

  function loadNoteIndex() {
    if (!noteIndexPromise) {
      noteIndexPromise = fetch(NOTE_INDEX_FILE)
        .then(function (response) {
          if (!response.ok) {
            throw new Error('ノート一覧を読み込めませんでした');
          }
          return response.json();
        });
    }

    return noteIndexPromise;
  }

  function encodeNotePath(path) {
    return String(path).split('/').map(encodeURIComponent).join('/');
  }

  function getCanonicalNotePath(path) {
    return PATH_PREFIX + path;
  }

  function getLocalNotePath(path) {
    if (!PATH_PREFIX) {
      return path;
    }
    return path.indexOf(PATH_PREFIX) === 0 ? path.slice(PATH_PREFIX.length) : null;
  }

  function loadArticleMaster() {
    if (!articleMasterPromise) {
      articleMasterPromise = fetch(ARTICLE_MASTER_FILE).then(function (response) {
        if (!response.ok) {
          throw new Error('記事マスターを読み込めませんでした');
        }
        return response.json();
      });
    }

    return articleMasterPromise;
  }

  function getArticleStorageKey(articleId) {
    return ARTICLE_STORAGE_PREFIX + articleId;
  }

  function isStudyRecordKey(key) {
    return key.indexOf(ARTICLE_STORAGE_PREFIX) === 0 ||
      key.indexOf(CHECKLIST_STORAGE_PREFIX) === 0;
  }

  function readAllStudyRecords() {
    const records = {};

    for (let index = 0; index < window.localStorage.length; index += 1) {
      const key = window.localStorage.key(index);
      if (key && isStudyRecordKey(key)) {
        records[key] = window.localStorage.getItem(key);
      }
    }

    return records;
  }

  function parseBackupFile(text) {
    const backup = JSON.parse(text);
    if (!backup || backup.format !== BACKUP_FORMAT || backup.version !== BACKUP_VERSION ||
        !backup.records || typeof backup.records !== 'object' || Array.isArray(backup.records)) {
      throw new Error('このサイトのバックアップファイルではありません。');
    }

    const records = {};
    Object.keys(backup.records).forEach(function (key) {
      if (!isStudyRecordKey(key) || typeof backup.records[key] !== 'string') {
        throw new Error('バックアップに不正な学習記録が含まれています。');
      }
      if (key.indexOf(ARTICLE_STORAGE_PREFIX) === 0) {
        const progress = JSON.parse(backup.records[key]);
        const learningSeconds = Number(progress && progress.learningSeconds);
        if (!progress || typeof progress !== 'object' ||
            typeof progress.completed !== 'boolean' ||
            !Number.isFinite(learningSeconds) || learningSeconds < 0) {
          throw new Error('バックアップの記事記録が不正です。');
        }
      } else if (backup.records[key] !== 'true') {
        throw new Error('バックアップのチェック記録が不正です。');
      }
      records[key] = backup.records[key];
    });
    return records;
  }

  function createBackup() {
    flushLearningTime();
    const exportedAt = new Date();
    const backup = {
      format: BACKUP_FORMAT,
      version: BACKUP_VERSION,
      exportedAt: exportedAt.toISOString(),
      records: readAllStudyRecords()
    };
    const timestamp = exportedAt.toISOString().replace(/[:.]/g, '-');
    const link = document.createElement('a');
    link.href = URL.createObjectURL(new Blob([
      JSON.stringify(backup, null, 2)
    ], { type: 'application/json' }));
    link.download = 'study-notes-backup-' + timestamp + '.json';
    document.body.appendChild(link);
    link.click();
    link.remove();
    window.setTimeout(function () {
      URL.revokeObjectURL(link.href);
    }, 0);
    showBackupStatus('バックアップをダウンロードしました。', false);
  }

  function mergeArticleRecord(currentValue, importedValue) {
    const current = JSON.parse(currentValue || '{}');
    const imported = JSON.parse(importedValue);
    if (!current || typeof current !== 'object' || !imported || typeof imported !== 'object') {
      throw new Error('記事の学習記録が不正です。');
    }

    const currentSeconds = Number(current.learningSeconds);
    const importedSeconds = Number(imported.learningSeconds);
    const currentCompletedUpdatedAt = parseTimestamp(current.completedUpdatedAt);
    const importedCompletedUpdatedAt = parseTimestamp(imported.completedUpdatedAt);
    let completed = Boolean(current.completed || imported.completed);
    let completedUpdatedAt = null;

    if (currentCompletedUpdatedAt !== null || importedCompletedUpdatedAt !== null) {
      if (importedCompletedUpdatedAt !== null &&
          (currentCompletedUpdatedAt === null || importedCompletedUpdatedAt > currentCompletedUpdatedAt)) {
        completed = Boolean(imported.completed);
        completedUpdatedAt = imported.completedUpdatedAt;
      } else {
        completed = Boolean(current.completed);
        completedUpdatedAt = current.completedUpdatedAt;
      }
    }
    const latestViewedAt = [current.lastViewedAt, imported.lastViewedAt]
      .filter(function (value) {
        return typeof value === 'string' && !Number.isNaN(Date.parse(value));
      })
      .sort()
      .pop() || null;

    return JSON.stringify({
      version: Math.max(Number(current.version) || 1, Number(imported.version) || 1),
      completed: completed,
      completedUpdatedAt: completedUpdatedAt,
      // Both totals may contain the same study session. Taking the larger total
      // preserves progress without double-counting overlapping backups.
      learningSeconds: Math.max(
        Number.isFinite(currentSeconds) && currentSeconds > 0 ? currentSeconds : 0,
        Number.isFinite(importedSeconds) && importedSeconds > 0 ? importedSeconds : 0
      ),
      lastViewedAt: latestViewedAt
    });
  }

  function parseTimestamp(value) {
    if (typeof value !== 'string') {
      return null;
    }
    const timestamp = Date.parse(value);
    return Number.isNaN(timestamp) ? null : timestamp;
  }

  function applyBackup(records, mode) {
    if (mode === 'overwrite') {
      Object.keys(readAllStudyRecords()).forEach(function (key) {
        window.localStorage.removeItem(key);
      });
      Object.keys(records).forEach(function (key) {
        window.localStorage.setItem(key, records[key]);
      });
      return;
    }

    Object.keys(records).forEach(function (key) {
      const currentValue = window.localStorage.getItem(key);
      if (key.indexOf(ARTICLE_STORAGE_PREFIX) === 0) {
        window.localStorage.setItem(key, mergeArticleRecord(currentValue, records[key]));
      } else if (records[key] === 'true' || currentValue === 'true') {
        window.localStorage.setItem(key, 'true');
      }
    });
  }

  function clearAllStudyRecords() {
    const confirmed = window.confirm(
      '学習記録をすべてクリアします。バックアップは取得済みですか？\n\n' +
      'この操作は取り消せません。問題なければ「OK」を押してください。'
    );
    if (!confirmed) {
      return;
    }

    Object.keys(readAllStudyRecords()).forEach(function (key) {
      window.localStorage.removeItem(key);
    });
    window.alert('この端末の学習記録をクリアしました。');
    window.location.reload();
  }

  function showBackupStatus(message, isError) {
    const status = document.querySelector('.reader-backup__status');
    if (!status) {
      return;
    }
    status.textContent = message;
    status.classList.toggle('is-error', Boolean(isError));
  }

  function chooseBackupFile(mode) {
    const input = document.querySelector('.reader-backup__file');
    input.dataset.mode = mode;
    input.value = '';
    input.click();
  }

  function importSelectedBackup(input) {
    const file = input.files && input.files[0];
    const mode = input.dataset.mode;
    if (!file) {
      return;
    }
    if (mode === 'overwrite' && !window.confirm('現在の記録が上書きされます。復元しますか？')) {
      return;
    }

    file.text().then(function (text) {
      const records = parseBackupFile(text);
      applyBackup(records, mode);
      window.alert(mode === 'overwrite' ? 'バックアップから復元しました。' : '別端末の記録をマージしました。');
      window.location.reload();
    }).catch(function (error) {
      showBackupStatus(error.message || 'バックアップを読み込めませんでした。', true);
    });
  }

  function enableBackupPage() {
    if (getCurrentNotePath() !== BACKUP_PAGE_FILE) {
      return;
    }
    const panel = document.querySelector('.reader-backup');
    if (!panel || panel.dataset.ready) {
      return;
    }
    panel.dataset.ready = 'true';
    panel.querySelector('[data-backup-action="download"]').addEventListener('click', createBackup);
    panel.querySelector('[data-backup-action="overwrite"]').addEventListener('click', function () {
      chooseBackupFile('overwrite');
    });
    panel.querySelector('[data-backup-action="merge"]').addEventListener('click', function () {
      chooseBackupFile('merge');
    });
    panel.querySelector('[data-backup-action="clear"]').addEventListener('click', clearAllStudyRecords);
    panel.querySelector('.reader-backup__file').addEventListener('change', function () {
      importSelectedBackup(this);
    });
  }

  function readArticleProgress(articleId) {
    const defaults = {
      version: 1,
      completed: false,
      completedUpdatedAt: null,
      learningSeconds: 0,
      lastViewedAt: null
    };

    try {
      const saved = JSON.parse(window.localStorage.getItem(getArticleStorageKey(articleId)) || 'null');
      return Object.assign(defaults, saved && typeof saved === 'object' ? saved : {});
    } catch (error) {
      console.warn('[Reader progress] 保存データを読み込めませんでした', error);
      return defaults;
    }
  }

  function writeArticleProgress(articleId, progress) {
    try {
      window.localStorage.setItem(getArticleStorageKey(articleId), JSON.stringify(progress));
    } catch (error) {
      console.warn('[Reader progress] 保存データを書き込めませんでした', error);
    }
  }

  function formatLearningTime(seconds) {
    const totalSeconds = Math.max(0, Math.floor(seconds));
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    const remainder = totalSeconds % 60;

    if (hours) {
      return hours + '時間' + minutes + '分';
    }
    if (minutes) {
      return minutes + '分' + remainder + '秒';
    }
    return remainder + '秒';
  }

  function formatOverallLearningTime(seconds) {
    const totalMinutes = Math.floor(Math.max(0, Number(seconds) || 0) / 60);
    const hours = Math.floor(totalMinutes / 60);
    const minutes = totalMinutes % 60;

    return hours + '時間 ' + minutes + '分';
  }

  function calculateOverallProgress(articles) {
    const articleProgress = articles
      .filter(function (article) {
        return article.path !== HOMEPAGE_FILE && article.path !== BACKUP_PAGE_FILE;
      })
      .map(function (article) {
        return readArticleProgress(article.id);
      });
    const completedCount = articleProgress.filter(function (progress) {
      return progress.completed;
    }).length;
    const totalLearningSeconds = articleProgress.reduce(function (total, progress) {
      const learningSeconds = Number(progress.learningSeconds);
      return total + (Number.isFinite(learningSeconds) && learningSeconds > 0 ? learningSeconds : 0);
    }, 0);
    const completionRate = articleProgress.length
      ? Math.round((completedCount / articleProgress.length) * 100)
      : 0;

    return {
      completedCount: completedCount,
      totalCount: articleProgress.length,
      totalLearningSeconds: totalLearningSeconds,
      completionRate: completionRate
    };
  }

  function renderHomepageProgress(master) {
    if (getCurrentNotePath() !== HOMEPAGE_FILE) {
      return;
    }

    const meta = document.querySelector('.reader-meta');
    if (!meta) {
      return;
    }

    const overallProgress = calculateOverallProgress(master.articles || []);
    meta.innerHTML =
      '<span class="reader-stat">合計時間: ' +
        formatOverallLearningTime(overallProgress.totalLearningSeconds) +
      '</span>' +
      '<span class="reader-stat">読了率 ' + overallProgress.completionRate + '% (' +
        overallProgress.completedCount + '/' + overallProgress.totalCount + ')</span>';
  }

  function renderArticleProgress() {
    const meta = document.querySelector('.reader-meta');
    if (!meta || !activeArticle) {
      return;
    }

    const progress = activeArticle.progress;
    const button = meta.querySelector('.reader-completion');
    const learningTime = meta.querySelector('.reader-learning-time');
    button.classList.toggle('is-completed', progress.completed);
    button.setAttribute('aria-pressed', String(progress.completed));
    button.textContent = progress.completed ? '✓ 読了' : '○ 未読了';
    learningTime.textContent = '学習 ' + formatLearningTime(progress.learningSeconds);
  }

  function createLearningTimeEditor() {
    let dialog = document.querySelector('.reader-time-dialog');
    if (dialog) {
      return dialog;
    }

    dialog = document.createElement('dialog');
    dialog.className = 'reader-time-dialog';
    dialog.setAttribute('aria-labelledby', 'reader-time-dialog-title');
    dialog.innerHTML =
      '<form method="dialog" class="reader-time-dialog__form">' +
        '<h2 id="reader-time-dialog-title">勉強時間を編集</h2>' +
        '<div class="reader-time-dialog__inputs">' +
          '<label><span>時間</span><input name="hours" type="number" min="0" max="9999" required></label>' +
          '<label><span>分</span><input name="minutes" type="number" min="0" max="59" required></label>' +
          '<label><span>秒</span><input name="seconds" type="number" min="0" max="59" required></label>' +
        '</div>' +
        '<p class="reader-time-dialog__error" role="alert" hidden>0以上の時間と、0〜59の分・秒を入力してください。</p>' +
        '<div class="reader-time-dialog__actions">' +
          '<button type="button" value="cancel">キャンセル</button>' +
          '<button type="submit" value="save">保存</button>' +
        '</div>' +
      '</form>';
    document.body.appendChild(dialog);

    dialog.querySelector('[value="cancel"]').addEventListener('click', function () {
      dialog.close();
    });
    dialog.addEventListener('click', function (event) {
      if (event.target === dialog) {
        dialog.close();
      }
    });
    dialog.addEventListener('close', updateLearningTimer);
    dialog.querySelector('form').addEventListener('submit', function (event) {
      event.preventDefault();
      const hours = Number(dialog.querySelector('[name="hours"]').value);
      const minutes = Number(dialog.querySelector('[name="minutes"]').value);
      const seconds = Number(dialog.querySelector('[name="seconds"]').value);
      const isValid = Number.isInteger(hours) && hours >= 0 && hours <= 9999 &&
        Number.isInteger(minutes) && minutes >= 0 && minutes <= 59 &&
        Number.isInteger(seconds) && seconds >= 0 && seconds <= 59;

      dialog.querySelector('.reader-time-dialog__error').hidden = isValid;
      if (!isValid || !activeArticle) {
        return;
      }

      activeArticle.progress.learningSeconds = (hours * 3600) + (minutes * 60) + seconds;
      writeArticleProgress(activeArticle.id, activeArticle.progress);
      renderArticleProgress();
      dialog.close();
      loadArticleMaster().then(renderHomepageProgress).catch(function (error) {
        console.warn('[Reader progress]', error);
      });
      updateLearningTimer();
    });

    return dialog;
  }

  function openLearningTimeEditor() {
    if (!activeArticle) {
      return;
    }

    flushLearningTime();
    activeStartedAt = null;
    const totalSeconds = Math.max(0, Math.floor(activeArticle.progress.learningSeconds));
    const dialog = createLearningTimeEditor();
    dialog.querySelector('[name="hours"]').value = Math.floor(totalSeconds / 3600);
    dialog.querySelector('[name="minutes"]').value = Math.floor((totalSeconds % 3600) / 60);
    dialog.querySelector('[name="seconds"]').value = totalSeconds % 60;
    dialog.querySelector('.reader-time-dialog__error').hidden = true;
    dialog.showModal();
    dialog.querySelector('[name="hours"]').focus();
  }

  function flushLearningTime() {
    if (!activeArticle || activeArticle.progress.completed || activeStartedAt === null) {
      return;
    }

    const elapsedSeconds = Math.floor((Date.now() - activeStartedAt) / 1000);
    if (elapsedSeconds > 0) {
      activeArticle.progress.learningSeconds += elapsedSeconds;
      activeStartedAt += elapsedSeconds * 1000;
      writeArticleProgress(activeArticle.id, activeArticle.progress);
      renderArticleProgress();
    }
  }

  function updateLearningTimer() {
    const shouldCount = activeArticle && !activeArticle.progress.completed &&
      document.visibilityState === 'visible' && document.hasFocus();

    if (shouldCount) {
      if (activeStartedAt === null) {
        activeStartedAt = Date.now();
      }
    } else {
      flushLearningTime();
      activeStartedAt = null;
    }
  }

  function enableLearningTimer() {
    if (window.readerLearningTimer) {
      return;
    }

    document.addEventListener('visibilitychange', updateLearningTimer);
    window.addEventListener('focus', updateLearningTimer);
    window.addEventListener('blur', updateLearningTimer);
    window.addEventListener('pagehide', flushLearningTime);
    window.readerLearningTimer = window.setInterval(flushLearningTime, 1000);
  }

  function initializeArticleProgress() {
    const requestedPath = getCurrentNotePath();
    const sequence = ++articleLoadSequence;
    flushLearningTime();
    activeArticle = null;
    activeStartedAt = null;

    if (requestedPath === BACKUP_PAGE_FILE) {
      return;
    }

    loadArticleMaster().then(function (master) {
      if (sequence !== articleLoadSequence) {
        return;
      }

      const canonicalPath = getCanonicalNotePath(requestedPath);
      const article = (master.articles || []).find(function (candidate) {
        return candidate.path.replace(/\.md$/i, '') === canonicalPath.replace(/\.md$/i, '');
      });
      if (!article) {
        throw new Error('記事マスターに記事がありません: ' + requestedPath);
      }

      const progress = readArticleProgress(article.id);
      progress.lastViewedAt = new Date().toISOString();
      writeArticleProgress(article.id, progress);
      activeArticle = { id: article.id, progress: progress };
      renderArticleProgress();
      renderHomepageProgress(master);
      updateLearningTimer();
    }).catch(function (error) {
      console.warn('[Reader progress]', error);
    });
  }

  function setHeaderLineContent(line, text) {
    line.innerHTML =
      '<span class="reader-header__track">' +
        '<span class="reader-header__text"></span>' +
        '<span class="reader-header__text reader-header__text--copy" aria-hidden="true"></span>' +
      '</span>';

    line.querySelectorAll('.reader-header__text').forEach(function (textElement) {
      textElement.textContent = text;
    });
  }

  function updateHeaderOverflow() {
    const header = document.querySelector('.reader-header');

    if (!header) {
      return;
    }

    header.querySelectorAll('.reader-header__path, .reader-header__title')
      .forEach(function (line) {
        const text = line.querySelector('.reader-header__text');
        const shouldScroll = text && text.scrollWidth > line.clientWidth;

        line.classList.toggle('is-overflowing', shouldScroll);
      });
  }

  function getCurrentNotePath() {
    const route = window.location.hash.replace(/^#\/?/, '').split(/[?#]/)[0];

    if (!route) {
      return HOMEPAGE_FILE;
    }

    try {
      return decodeURIComponent(route);
    } catch (error) {
      return route;
    }
  }

  function updateReaderHeader() {
    let header = document.querySelector('.reader-header');

    if (!header) {
      header = document.createElement('header');
      header.className = 'reader-header';
      header.setAttribute('aria-label', '現在のノート');
      header.innerHTML =
        '<div class="reader-header__inner">' +
          '<p class="reader-header__path"></p>' +
          '<p class="reader-header__title" role="button" tabindex="0"></p>' +
          '<span class="reader-header__copy-status" aria-live="polite"></span>' +
        '</div>';
      const titleElement = header.querySelector('.reader-header__title');
      const copyTitle = function () {
        copyTextToClipboard(titleElement.dataset.copyText || '').then(function () {
          const status = header.querySelector('.reader-header__copy-status');
          titleElement.classList.add('is-copied');
          status.textContent = 'タイトルをコピーしました';
          window.setTimeout(function () {
            titleElement.classList.remove('is-copied');
            status.textContent = '';
          }, 1600);
        }).catch(function () {
          header.querySelector('.reader-header__copy-status').textContent =
            'タイトルをコピーできませんでした';
        });
      };
      titleElement.addEventListener('click', copyTitle);
      titleElement.addEventListener('keydown', function (event) {
        if (event.key === 'Enter' || event.key === ' ') {
          event.preventDefault();
          copyTitle();
        }
      });
      document.body.appendChild(header);
    }

    const notePath = getCurrentNotePath();
    const pathParts = notePath.split('/').filter(Boolean);
    const fileName = pathParts.pop() || HOMEPAGE_FILE;
    const title = fileName.replace(/\.md$/i, '');
    const directory = pathParts.length ? pathParts.join(' / ') : 'トップ';

    setHeaderLineContent(header.querySelector('.reader-header__path'), directory);
    const titleElement = header.querySelector('.reader-header__title');
    setHeaderLineContent(titleElement, title);
    titleElement.dataset.copyText = title;
    titleElement.setAttribute('aria-label', title + '。クリックしてタイトルをコピー');
    window.requestAnimationFrame(updateHeaderOverflow);
  }

  function enableHeaderOverflowUpdates() {
    if (window.readerHeaderResizeHandler) {
      return;
    }

    window.readerHeaderResizeHandler = updateHeaderOverflow;
    window.addEventListener('resize', window.readerHeaderResizeHandler);
  }

  function createReaderMeta(content) {
    if (getCurrentNotePath() === BACKUP_PAGE_FILE) {
      return content;
    }
    const temporaryElement = document.createElement('div');
    temporaryElement.innerHTML = content;

    const text = (temporaryElement.textContent || '')
      .replace(/\s+/g, '')
      .trim();
    const characterCount = text.length;
    const readingMinutes = Math.max(
      1,
      Math.ceil(characterCount / JAPANESE_CHARACTERS_PER_MINUTE)
    );

    return (
      '<nav class="reader-meta" aria-label="記事情報">' +
        '<button class="reader-completion" type="button" aria-pressed="false">○ 未読了</button>' +
        '<span class="reader-stat reader-learning-time-wrap">' +
          '<span class="reader-learning-time">学習 0秒</span>' +
          '<button class="reader-time-edit" type="button" aria-label="勉強時間を編集" title="勉強時間を編集">✎</button>' +
        '</span>' +
        '<span class="reader-stat" title="1分あたり約500文字で計算">' +
          '<span aria-hidden="true">◷</span> 約' + readingMinutes + '分' +
        '</span>' +
        '<span class="reader-stat">' +
          characterCount.toLocaleString('ja-JP') + '文字' +
        '</span>' +
      '</nav>' +
      content
    );
  }

  function createReaderNavigation() {
    const existingNavigation = document.querySelector('.reader-navigation');
    if (existingNavigation) {
      if (existingNavigation.parentElement !== document.body) {
        document.body.appendChild(existingNavigation);
      }
      updateReaderNavigation(existingNavigation);
      createHistoryNavigation();
      return;
    }

    const navigation = document.createElement('nav');
    navigation.className = 'reader-navigation';
    navigation.setAttribute('aria-label', 'ページ操作');
    navigation.innerHTML =
      '<button class="reader-navigation__button reader-toc" type="button">' +
        '<span class="reader-navigation__icon" aria-hidden="true">☰</span>' +
        '<span>目次</span>' +
      '</button>' +
      '<button class="reader-navigation__button reader-search" type="button">' +
        '<span class="reader-navigation__icon" aria-hidden="true">⌕</span>' +
        '<span>検索</span>' +
      '</button>' +
      '<button class="reader-navigation__button reader-back" type="button">' +
        '<span class="reader-navigation__icon" aria-hidden="true">←</span>' +
        '<span>戻る</span>' +
      '</button>' +
      '<a class="reader-navigation__button reader-home" href="#/">' +
        '<span class="reader-navigation__icon" aria-hidden="true">⌂</span>' +
        '<span>ホーム</span>' +
      '</a>' +
      '<button class="reader-navigation__button reader-forward" type="button">' +
        '<span class="reader-navigation__icon" aria-hidden="true">→</span>' +
        '<span>次に進む</span>' +
      '</button>' + (SHOW_BACKUP_LINK ?
      '<a class="reader-navigation__button reader-backup-link" href="#/' +
        encodeNotePath(BACKUP_PAGE_FILE) + '">' +
        '<span class="reader-navigation__icon" aria-hidden="true">⇅</span>' +
        '<span>バックアップ・復元</span>' +
      '</a>' : '');

    // Keep the controls outside the scrollable sidebar. A fixed element inside
    // Docsify's transformed sidebar uses that sidebar as its containing block
    // and consequently moves together with the navigation list.
    document.body.appendChild(navigation);

    navigation.querySelector('.reader-toc').addEventListener('click', function () {
      openTableOfContents();
    });

    navigation.querySelector('.reader-search').addEventListener('click', openSearch);

    navigation.querySelector('.reader-back').addEventListener('click', navigateBack);
    navigation.querySelector('.reader-forward').addEventListener('click', function () {
      window.history.forward();
    });

    updateReaderNavigation(navigation);
    createHistoryNavigation();
  }

  function createHistoryNavigation() {
    const existingNavigation = document.querySelector('.reader-history-navigation');
    if (!isDesktopLayout()) {
      if (existingNavigation) {
        existingNavigation.remove();
      }
      return;
    }
    if (existingNavigation) {
      if (existingNavigation.parentElement !== document.body) {
        document.body.appendChild(existingNavigation);
      }
      return;
    }

    const navigation = document.createElement('nav');
    navigation.className = 'reader-history-navigation';
    navigation.setAttribute('aria-label', '閲覧履歴');
    navigation.innerHTML =
      '<button class="reader-history-navigation__button reader-back" type="button">' +
        '<span aria-hidden="true">←</span>' +
        '<span>戻る</span>' +
      '</button>' +
      '<a class="reader-history-navigation__button reader-history-home" href="#/" aria-label="ホーム" title="ホーム">' +
        '<span aria-hidden="true">⌂</span>' +
      '</a>' +
      '<button class="reader-history-navigation__button reader-forward" type="button">' +
        '<span>次に進む</span>' +
        '<span aria-hidden="true">→</span>' +
      '</button>';
    document.body.appendChild(navigation);

    navigation.querySelector('.reader-back').addEventListener('click', navigateBack);

    navigation.querySelector('.reader-forward').addEventListener('click', function () {
      window.history.forward();
    });
  }

  function navigateBack() {
    if (window.history.length > 1) {
      window.history.back();
      return;
    }

    window.location.hash = '#/';
  }

  function updateReaderNavigation(navigation) {
    const isHomepage = getCurrentNotePath() === HOMEPAGE_FILE;
    const backupLink = navigation.querySelector('.reader-backup-link');
    navigation.classList.toggle('is-homepage', isHomepage);
    navigation.hidden = !isDesktopLayout() && isHomepage && !backupLink;
    if (isDesktopLayout()) {
      navigation.querySelectorAll('.reader-navigation__button').forEach(function (button) {
        button.hidden = !button.classList.contains('reader-home') &&
          !button.classList.contains('reader-search') &&
          !button.classList.contains('reader-backup-link');
      });
      return;
    }
    navigation.querySelectorAll('.reader-navigation__button:not(.reader-backup-link)')
      .forEach(function (button) {
        button.hidden = isHomepage;
      });
    if (backupLink) {
      backupLink.hidden = !isHomepage;
    }
  }

  function closeSearch() {
    const dialog = document.querySelector('.reader-search-dialog');
    if (dialog && dialog.open) {
      dialog.close();
    }
  }

  function renderSearchResults() {
    const dialog = document.querySelector('.reader-search-dialog');
    const query = dialog.querySelector('.reader-search-dialog__input').value.trim().toLocaleLowerCase('ja');
    const results = dialog.querySelector('.reader-search-dialog__results');

    if (!query) {
      results.innerHTML = '<p class="reader-search-dialog__message">検索キーワードを入力してください。</p>';
      return;
    }
    results.innerHTML = '<p class="reader-search-dialog__message">検索中...</p>';
    loadNoteIndex().then(function (index) {
      const matches = [];
      Object.keys(index).forEach(function (title) {
        if (!title.toLocaleLowerCase('ja').includes(query)) {
          return;
        }

        index[title].forEach(function (path) {
          const localPath = getLocalNotePath(path);
          if (localPath !== null) {
            matches.push({ title: title, path: localPath });
          }
        });
      });

      results.innerHTML = '';
      if (!matches.length) {
        results.innerHTML = '<p class="reader-search-dialog__message">一致するノートはありません。</p>';
        return;
      }

      matches.forEach(function (note) {
        const link = document.createElement('a');
        link.className = 'reader-search-result';
        link.href = '#/' + encodeNotePath(note.path);
        link.innerHTML = '<strong></strong><span></span>';
        link.querySelector('strong').textContent = note.title;
        link.querySelector('span').textContent = note.path;
        link.addEventListener('click', closeSearch);
        results.appendChild(link);
      });
    }).catch(function () {
      results.innerHTML = '<p class="reader-search-dialog__message">検索データを読み込めませんでした。</p>';
    });
  }

  function createSearchDialog() {
    if (document.querySelector('.reader-search-dialog')) {
      return;
    }

    const dialog = document.createElement('dialog');
    dialog.className = 'reader-search-dialog';
    dialog.setAttribute('aria-label', 'ノートを検索');
    dialog.innerHTML =
      '<form class="reader-search-dialog__panel" method="dialog">' +
        '<header><strong>ノートを検索</strong><button value="close" aria-label="検索を閉じる">×</button></header>' +
        '<input class="reader-search-dialog__input" type="search" placeholder="タイトルを入力" aria-label="タイトルを検索" autocomplete="off">' +
        '<div class="reader-search-dialog__results" aria-live="polite"></div>' +
      '</form>';
    document.body.appendChild(dialog);

    dialog.querySelector('.reader-search-dialog__input').addEventListener('input', renderSearchResults);
    dialog.addEventListener('click', function (event) {
      if (event.target === dialog) {
        closeSearch();
      }
    });
  }

  function openSearch() {
    createSearchDialog();
    const dialog = document.querySelector('.reader-search-dialog');
    dialog.showModal();
    dialog.querySelector('.reader-search-dialog__input').focus();
  }

  function closeTableOfContents() {
    const drawer = document.querySelector('.reader-toc-drawer');
    const backdrop = document.querySelector('.reader-toc-backdrop');
    const tocButton = document.querySelector('.reader-toc');

    if (!drawer || !backdrop) {
      return;
    }

    drawer.classList.remove('is-open');
    backdrop.classList.remove('is-open');
    drawer.setAttribute('aria-hidden', 'true');
    tocButton.setAttribute('aria-expanded', 'false');
  }

  function openTableOfContents() {
    const drawer = document.querySelector('.reader-toc-drawer');
    const backdrop = document.querySelector('.reader-toc-backdrop');

    if (!drawer || !backdrop) {
      return;
    }

    drawer.classList.add('is-open');
    backdrop.classList.add('is-open');
    drawer.setAttribute('aria-hidden', 'false');
    document.querySelector('.reader-toc').setAttribute('aria-expanded', 'true');
    drawer.querySelector('.reader-toc-drawer__close').focus();
  }

  function updateTableOfContents() {
    let drawer = document.querySelector('.reader-toc-drawer');
    let backdrop = document.querySelector('.reader-toc-backdrop');

    if (!drawer) {
      backdrop = document.createElement('div');
      backdrop.className = 'reader-toc-backdrop';
      backdrop.addEventListener('click', closeTableOfContents);

      drawer = document.createElement('aside');
      drawer.className = 'reader-toc-drawer';
      drawer.setAttribute('aria-hidden', 'true');
      drawer.setAttribute('aria-label', '目次');
      drawer.innerHTML =
        '<div class="reader-toc-drawer__header">' +
          '<strong>目次</strong>' +
          '<button class="reader-toc-drawer__close" type="button" aria-label="目次を閉じる">×</button>' +
        '</div>' +
        '<nav class="reader-toc-drawer__list" aria-label="ページ内の見出し"></nav>';
      drawer.querySelector('.reader-toc-drawer__close')
        .addEventListener('click', closeTableOfContents);

      document.body.appendChild(backdrop);
      document.body.appendChild(drawer);

      document.addEventListener('keydown', function (event) {
        if (event.key === 'Escape') {
          closeTableOfContents();
        }
      });
    }

    const list = drawer.querySelector('.reader-toc-drawer__list');
    const headings = document.querySelectorAll(
      '.markdown-section h1, .markdown-section h2, .markdown-section h3, .markdown-section h4'
    );
    list.innerHTML = '';

    headings.forEach(function (heading) {
      const headingAnchor = heading.querySelector('.anchor');
      const link = document.createElement('a');
      link.className = 'reader-toc-drawer__link reader-toc-drawer__link--' + heading.tagName.toLowerCase();
      link.href = headingAnchor ? headingAnchor.getAttribute('href') : '#' + heading.id;
      link.textContent = heading.textContent;
      link.addEventListener('click', closeTableOfContents);
      list.appendChild(link);
    });

    if (!headings.length) {
      list.innerHTML = '<p class="reader-toc-drawer__empty">このページには見出しがありません。</p>';
    }
  }

  function copyTextToClipboard(text) {
    const copyWithFallback = function () {
      const textArea = document.createElement('textarea');
      textArea.value = text;
      textArea.setAttribute('readonly', '');
      textArea.style.position = 'fixed';
      textArea.style.opacity = '0';
      document.body.appendChild(textArea);
      textArea.select();
      const copied = document.execCommand('copy');
      textArea.remove();

      if (!copied) {
        throw new Error('Copy command was rejected');
      }
    };

    const copyPromise = navigator.clipboard && window.isSecureContext
      ? navigator.clipboard.writeText(text).catch(copyWithFallback)
      : Promise.resolve().then(copyWithFallback);

    return copyPromise;
  }

  function copyCodeBlock(codeBlock) {
    const text = codeBlock.textContent || '';

    return copyTextToClipboard(text).then(function () {
      const codeContainer = codeBlock.parentElement;
      codeContainer.classList.add('is-copied');
      codeContainer.setAttribute('aria-label', 'コピーしました');

      window.setTimeout(function () {
        codeContainer.classList.remove('is-copied');
        codeContainer.setAttribute('aria-label', 'タップしてコードをコピー');
      }, 1600);
    }).catch(function () {
      codeBlock.parentElement.setAttribute(
        'aria-label',
        'コピーできませんでした。テキストを選択してコピーしてください'
      );
    });
  }

  function enableCodeBlockCopying() {
    document.querySelectorAll('.markdown-section pre > code').forEach(function (codeBlock) {
      const codeContainer = codeBlock.parentElement;

      if (codeContainer.classList.contains('is-copyable')) {
        return;
      }

      codeContainer.classList.add('is-copyable');
      codeContainer.setAttribute('role', 'button');
      codeContainer.setAttribute('tabindex', '0');
      codeContainer.setAttribute('aria-label', 'タップしてコードをコピー');
      codeContainer.addEventListener('click', function () {
        copyCodeBlock(codeBlock);
      });
      codeContainer.addEventListener('keydown', function (event) {
        if (event.key === 'Enter' || event.key === ' ') {
          event.preventDefault();
          copyCodeBlock(codeBlock);
        }
      });
    });
  }

  function getChecklistStorageKey(checkbox, occurrence) {
    const item = checkbox.closest('li');
    const itemText = item ? item.textContent.replace(/\s+/g, ' ').trim() : '';

    return [
      'study-notes-checklist',
      getCanonicalNotePath(getCurrentNotePath()),
      itemText,
      occurrence
    ].join('::');
  }

  function enablePersistentChecklists() {
    const occurrences = Object.create(null);

    document.querySelectorAll('.markdown-section input[type="checkbox"]')
      .forEach(function (checkbox) {
        const item = checkbox.closest('li');
        const itemText = item ? item.textContent.replace(/\s+/g, ' ').trim() : '';
        const occurrence = occurrences[itemText] || 0;
        const storageKey = getChecklistStorageKey(checkbox, occurrence);
        occurrences[itemText] = occurrence + 1;

        checkbox.disabled = false;
        checkbox.checked = window.localStorage.getItem(storageKey) === 'true';
        checkbox.setAttribute('aria-label', itemText || 'チェック項目');

        checkbox.addEventListener('change', function () {
          if (checkbox.checked) {
            window.localStorage.setItem(storageKey, 'true');
          } else {
            window.localStorage.removeItem(storageKey);
          }
        });
      });
  }

  function readerToolsPlugin(hook) {
    hook.afterEach(function (html, next) {
      next(createReaderMeta(html));
    });

    hook.doneEach(function () {
      createThemeSwitcher();
      createDesktopSidebarControls();
      updateReaderHeader();
      enableHeaderOverflowUpdates();
      createReaderNavigation();
      createSearchDialog();
      updateTableOfContents();
      enableCodeBlockCopying();
      enablePersistentChecklists();
      enableBackupPage();
      initializeArticleProgress();
      enableLearningTimer();
      closeTableOfContents();
    });
  }

  document.addEventListener('click', function (event) {
    if (event.target.closest('.reader-time-edit')) {
      openLearningTimeEditor();
      return;
    }

    if (!event.target.classList.contains('reader-completion') || !activeArticle) {
      return;
    }

    const willComplete = !activeArticle.progress.completed;
    if (willComplete) {
      flushLearningTime();
    }
    activeArticle.progress.completed = willComplete;
    activeArticle.progress.completedUpdatedAt = new Date().toISOString();
    writeArticleProgress(activeArticle.id, activeArticle.progress);
    renderArticleProgress();
    loadArticleMaster().then(renderHomepageProgress).catch(function (error) {
      console.warn('[Reader progress]', error);
    });
    updateLearningTimer();
  });

  window.$docsify = window.$docsify || {};
  window.$docsify.plugins = (
    window.$docsify.plugins || []
  ).concat(readerToolsPlugin);
})();
