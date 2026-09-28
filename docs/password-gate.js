(function () {
  'use strict';

  var SESSION_KEY = 'study-notes:authenticated';
  var PASSWORD = 'maru';
  var body = document.body;
  var screen = document.getElementById('auth-screen');
  var form = document.getElementById('auth-form');
  var password = document.getElementById('auth-password');
  var error = document.getElementById('auth-error');

  function unlock() {
    body.removeAttribute('data-auth-pending');
    screen.remove();
  }

  if (window.sessionStorage.getItem(SESSION_KEY) === 'yes') {
    unlock();
    return;
  }

  form.addEventListener('submit', function (event) {
    event.preventDefault();

    if (password.value !== PASSWORD) {
      error.textContent = 'パスワードが違います。';
      password.value = '';
      password.focus();
      return;
    }

    window.sessionStorage.setItem(SESSION_KEY, 'yes');
    unlock();
  });
})();
