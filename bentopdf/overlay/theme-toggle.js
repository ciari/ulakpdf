/*
 * Theme toggle for BentoPDF overlay.
 *
 * - The early-paint script in <head> already set <html class="theme-light">
 *   if appropriate, so this file only handles the user-facing toggle button.
 * - Persists choice in localStorage under "spdf-theme" ("light" | "dark").
 * - Inserts a button into the page; tries the navbar first, falls back to a
 *   floating button if BentoPDF's DOM doesn't expose a navbar.
 */
(function () {
    'use strict';

    var STORAGE_KEY = 'spdf-theme';

    function readPref() {
        try { return localStorage.getItem(STORAGE_KEY); } catch (_) { return null; }
    }
    function writePref(v) {
        try { localStorage.setItem(STORAGE_KEY, v); } catch (_) {}
    }

    function currentTheme() {
        return document.documentElement.classList.contains('theme-light') ? 'light' : 'dark';
    }
    function applyTheme(t) {
        var html = document.documentElement;
        if (t === 'light') html.classList.add('theme-light');
        else               html.classList.remove('theme-light');
    }

    function buildButton() {
        var btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'spdf-theme-toggle';
        btn.title = 'Tema değiştir';
        btn.setAttribute('aria-label', 'Tema değiştir');

        // Inline SVGs (sun + moon) — no icon-font dependency.
        var dark = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
        dark.setAttribute('viewBox', '0 0 24 24');
        dark.setAttribute('fill', 'none');
        dark.setAttribute('stroke', 'currentColor');
        dark.setAttribute('stroke-width', '2');
        dark.setAttribute('stroke-linecap', 'round');
        dark.setAttribute('stroke-linejoin', 'round');
        dark.classList.add('icon-dark');
        var moon = document.createElementNS('http://www.w3.org/2000/svg', 'path');
        moon.setAttribute('d', 'M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z');
        dark.appendChild(moon);

        var light = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
        light.setAttribute('viewBox', '0 0 24 24');
        light.setAttribute('fill', 'none');
        light.setAttribute('stroke', 'currentColor');
        light.setAttribute('stroke-width', '2');
        light.setAttribute('stroke-linecap', 'round');
        light.setAttribute('stroke-linejoin', 'round');
        light.classList.add('icon-light');
        var sun = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
        sun.setAttribute('cx', '12'); sun.setAttribute('cy', '12'); sun.setAttribute('r', '4');
        light.appendChild(sun);
        ['M12 2v2', 'M12 20v2', 'M4.93 4.93l1.41 1.41', 'M17.66 17.66l1.41 1.41',
         'M2 12h2', 'M20 12h2', 'M4.93 19.07l1.41-1.41', 'M17.66 6.34l1.41-1.41'].forEach(function (d) {
            var p = document.createElementNS('http://www.w3.org/2000/svg', 'path');
            p.setAttribute('d', d);
            light.appendChild(p);
        });

        btn.appendChild(dark);
        btn.appendChild(light);

        btn.addEventListener('click', function () {
            var next = currentTheme() === 'light' ? 'dark' : 'light';
            applyTheme(next);
            writePref(next);
        });
        return btn;
    }

    function readCookie(name) {
        var pairs = document.cookie ? document.cookie.split(/;\s*/) : [];
        for (var i = 0; i < pairs.length; i++) {
            var eq = pairs[i].indexOf('=');
            if (eq > 0 && pairs[i].slice(0, eq) === name) {
                return decodeURIComponent(pairs[i].slice(eq + 1));
            }
        }
        return null;
    }

    function buildUserMenu() {
        // Built only when the spdf-user cookie is present (nginx sets it on
        // Shib-authenticated responses). Shows "user@domain · Çıkış".
        var user = readCookie('spdf-user');
        if (!user) return null;

        var wrap = document.createElement('div');
        wrap.className = 'spdf-user-menu';
        wrap.style.display = 'inline-flex';
        wrap.style.alignItems = 'center';
        wrap.style.gap = '10px';
        wrap.style.marginLeft = '12px';
        wrap.style.fontSize = '13px';

        var name = document.createElement('span');
        name.textContent = user;
        name.title = user;
        name.style.maxWidth = '220px';
        name.style.overflow = 'hidden';
        name.style.textOverflow = 'ellipsis';
        name.style.whiteSpace = 'nowrap';
        name.style.color = 'inherit';
        name.style.opacity = '0.85';

        var logout = document.createElement('a');
        logout.href = '/logout';
        logout.textContent = 'Çıkış';
        logout.title = 'Oturumu kapat';
        logout.className = 'spdf-logout';
        logout.style.color = 'inherit';
        logout.style.textDecoration = 'none';
        logout.style.padding = '6px 12px';
        logout.style.border = '1px solid currentColor';
        logout.style.borderColor = 'rgba(148, 163, 184, 0.4)';
        logout.style.borderRadius = '8px';
        logout.style.fontWeight = '500';
        logout.style.transition = 'background-color 120ms';
        logout.addEventListener('mouseenter', function () {
            logout.style.background = 'rgba(148, 163, 184, 0.15)';
        });
        logout.addEventListener('mouseleave', function () {
            logout.style.background = 'transparent';
        });

        wrap.appendChild(name);
        wrap.appendChild(logout);
        return wrap;
    }

    function placeButton(btn, userMenu) {
        // Inject toggle (always) and user menu (if present) into the right
        // side of BentoPDF's navbar. Strategy below is robust to the two
        // navbar variants (simple-mode = logo only, full-mode = logo + own
        // right-side actions).
        var nav = document.querySelector('nav[data-simple-nav], nav.bg-gray-800, nav');
        if (!nav) {
            floatingFallback(btn);
            if (userMenu) document.body.appendChild(userMenu);
            return;
        }

        var logo = nav.querySelector('#nav-logo, .flex-shrink-0 img');
        var row = logo ? logo.closest('.flex') : nav.querySelector('.flex');
        while (row && row.parentElement && row.parentElement !== nav.querySelector('.container, .max-w-7xl, .px-4') &&
               row.parentElement.classList && row.parentElement.classList.contains('flex')) {
            row = row.parentElement;
        }
        if (!row) {
            floatingFallback(btn);
            return;
        }

        var explicitRight = row.querySelector(':scope > .ml-auto, :scope > [class*="justify-end"]');
        var target;
        if (explicitRight) {
            target = explicitRight;
        } else {
            target = document.createElement('div');
            target.className = 'ml-auto flex items-center';
            row.appendChild(target);
        }
        target.appendChild(btn);
        if (userMenu) target.appendChild(userMenu);
    }

    function floatingFallback(btn) {
        btn.style.position = 'fixed';
        btn.style.right = '16px';
        btn.style.bottom = '16px';
        btn.style.zIndex = '9999';
        btn.style.background = 'rgba(15, 23, 42, 0.6)';
        btn.style.color = '#fff';
        document.body.appendChild(btn);
    }

    function init() {
        // Re-apply once more in case the early script didn't run (paranoid).
        // Default to light: BentoPDF originally defaulted dark, but UlakPDF's
        // brand palette and most institutional usage works better in light.
        // Users can toggle and the choice persists in localStorage.
        applyTheme(readPref() || 'light');
        var btn = buildButton();
        var menu = buildUserMenu();
        placeButton(btn, menu);
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
