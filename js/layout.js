(function () {
  var NAV_ITEMS = [
    { key: 'dashboard',   icon: 'bi-graph-up',        label: 'Dashboard',                       path: 'index.html' },
    { key: 'whitelist',   icon: 'bi-list-check',      label: 'MSISDN Whitelist',     path: 'pages/whitelist.html' },
    { key: 'change-mgmt', icon: 'bi-diagram-3-fill',  label: 'Scheduled Change',     path: 'pages/change-mgmt.html' },
    { key: 'processing',  icon: 'bi-broadcast',       label: 'IPDR Processing',      path: 'pages/processing.html' },
    { key: 'sftp',        icon: 'bi-send-fill',       label: 'SFTP Delivery',        path: 'pages/sftp.html' },
    { key: 'users',       icon: 'bi-people-fill',     label: 'User Management',                 path: 'pages/users.html' }
  ];

  var cfg = window.BNPT_PAGE || { key: 'dashboard', depth: 0 };
  var prefix = cfg.depth > 0 ? '../' : '';

  function hrefForKey(key) {
    var item = NAV_ITEMS.filter(function (i) { return i.key === key; })[0];
    if (!item) return '#';
    if (cfg.depth === 0) return item.path; // from root: "pages/whitelist.html" or "index.html"
    return item.key === 'dashboard' ? '../index.html' : item.path.split('/')[1]; // sibling inside pages/
  }

  function loginHref() {
    return cfg.depth === 0 ? 'pages/login/index.html' : (cfg.depth === 1 ? 'login/index.html' : '../../index.html');
  }

  function buildNavHtml() {
    return NAV_ITEMS.map(function (item) {
      var active = item.key === cfg.key ? ' active' : '';
      return '<li class="nav-item">' +
        '<a href="' + hrefForKey(item.key) + '" class="nav-link' + active + '">' +
        '<i class="nav-icon bi ' + item.icon + '"></i><p>' + item.label + '</p>' +
        '</a></li>';
    }).join('');
  }

  function fetchPartial(name) {
    return fetch(prefix + 'partials/' + name + '.html').then(function (r) { return r.text(); });
  }

  function applyTokens(html) {
    return html
      .replace(/__DASHBOARD_HREF__/g, hrefForKey('dashboard'))
      .replace(/__WHITELIST_HREF__/g, hrefForKey('whitelist'))
      .replace(/__USERS_HREF__/g, hrefForKey('users'))
      .replace(/__LOGIN_HREF__/g, loginHref())
      .replace(/__NAV_ITEMS__/g, buildNavHtml());
  }

  function inject(slotId, html) {
    var slot = document.getElementById(slotId);
    if (slot) slot.outerHTML = applyTokens(html);
  }

  function init() {
    Promise.all([fetchPartial('header'), fetchPartial('sidebar')]).then(function (results) {
      inject('app-header-slot', results[0]);
      inject('app-sidebar-slot', results[1]);
      document.dispatchEvent(new CustomEvent('bnpt:layout-ready'));
    }).catch(function (err) {
      console.error('Failed to load layout partials. Are you opening this via a local server (not file://)?', err);
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
