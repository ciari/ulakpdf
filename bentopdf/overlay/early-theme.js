/*
 * Early-paint theme detector for BentoPDF.
 * Loaded as the FIRST <script> in <head> (synchronous, blocking parser)
 * so it runs before any paint and adds the theme-light class to <html>
 * before stylesheets apply. This avoids both the flash-of-wrong-theme
 * and the CSP "inline script" violation we'd hit if we inlined this.
 */
(function () {
    try {
        var t = localStorage.getItem('spdf-theme') || 'light';
        if (t === 'light') {
            document.documentElement.classList.add('theme-light');
        }
    } catch (_) {}
})();
