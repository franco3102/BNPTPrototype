/**
 * Very small client-side permission enforcement DEMO.
 * Real enforcement always happens on the backend (NestJS PermissionGuard) -
 * this only hides/disables buttons in the UI so users don't see actions
 * they aren't allowed to use. Replace CURRENT_USER_PERMISSIONS with
 * whatever the backend returns after login (e.g. decoded from the JWT).
 */
(function () {
  // DEMO: pretend the logged-in user is a "Maker" - swap this once real
  // login/session wiring exists.
  window.CURRENT_USER_PERMISSIONS = [
    'dashboard.view',
    'whitelist.view', 'whitelist.create',
    'change-mgmt.view', 'change-mgmt.create',
    'processing.view',
    'sftp.view'
  ];

  function applyPermissions() {
    document.querySelectorAll('[data-permission]').forEach(function (el) {
      var required = el.getAttribute('data-permission');
      if (window.CURRENT_USER_PERMISSIONS.indexOf(required) === -1) {
        el.classList.add('d-none');
      }
    });
  }

  document.addEventListener('bnpt:layout-ready', applyPermissions);
  if (document.readyState !== 'loading') applyPermissions();
})();
