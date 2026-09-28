const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const source = fs.readFileSync('docs/password-gate.js', 'utf8');

function createContext(savedValue = null) {
  const listeners = {};
  const storage = new Map(savedValue ? [['study-notes:authenticated', savedValue]] : []);
  const password = { value: '', focused: false, focus() { this.focused = true; } };
  const error = { textContent: '' };
  const screen = { removed: false, remove() { this.removed = true; } };
  const body = {
    unlocked: false,
    removeAttribute(name) {
      if (name === 'data-auth-pending') this.unlocked = true;
    },
  };
  const form = { addEventListener(type, listener) { listeners[type] = listener; } };
  const elements = { 'auth-screen': screen, 'auth-form': form, 'auth-password': password, 'auth-error': error };

  const context = {
    document: { body, getElementById(id) { return elements[id]; } },
    window: {
      sessionStorage: {
        getItem(key) { return storage.get(key) || null; },
        setItem(key, value) { storage.set(key, value); },
      },
    },
  };
  vm.runInNewContext(source, context);
  return { body, error, listeners, password, screen, storage };
}

const rejected = createContext();
rejected.password.value = 'wrong';
rejected.listeners.submit({ preventDefault() {} });
assert.equal(rejected.body.unlocked, false);
assert.equal(rejected.error.textContent, 'パスワードが違います。');

const accepted = createContext();
accepted.password.value = 'maru';
accepted.listeners.submit({ preventDefault() {} });
assert.equal(accepted.body.unlocked, true);
assert.equal(accepted.screen.removed, true);
assert.equal(accepted.storage.get('study-notes:authenticated'), 'yes');

const remembered = createContext('yes');
assert.equal(remembered.body.unlocked, true);
assert.equal(remembered.screen.removed, true);

console.log('password gate tests passed');
