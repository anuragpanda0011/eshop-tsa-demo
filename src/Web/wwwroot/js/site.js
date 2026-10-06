// eShopOnWeb – client-side utilities
// All secrets and configuration are server-side only; nothing sensitive is
// embedded here.

(function () {
    'use strict';

    // ---------------------------------------------------------------------------
    // CSRF / antiforgery token helper
    // Reads the hidden __RequestVerificationToken field present in every Razor
    // form and attaches it to fetch() calls that mutate state.
    // ---------------------------------------------------------------------------
    function getAntiForgeryToken() {
        var tokenInput = document.querySelector('input[name="__RequestVerificationToken"]');
        return tokenInput ? tokenInput.value : '';
    }

    // Attach antiforgery token to all non-GET fetch requests automatically.
    var _nativeFetch = window.fetch;
    window.fetch = function (resource, init) {
        init = init || {};
        var method = (init.method || 'GET').toUpperCase();
        if (method !== 'GET' && method !== 'HEAD' && method !== 'OPTIONS') {
            init.headers = init.headers || {};
            // Support both plain-object and Headers instance
            if (typeof init.headers.set === 'function') {
                init.headers.set('RequestVerificationToken', getAntiForgeryToken());
            } else {
                init.headers['RequestVerificationToken'] = getAntiForgeryToken();
            }
        }
        return _nativeFetch.call(this, resource, init);
    };

    // ---------------------------------------------------------------------------
    // Structured client-side logging shim
    // Wraps console methods so that log output includes a timestamp and a
    // correlation ID when one is available (injected by the server into the page
    // as window.__traceId via a <script> block in _Layout.cshtml).
    // ---------------------------------------------------------------------------
    var _traceId = window.__traceId || '';

    function buildPrefix(level) {
        return JSON.stringify({
            ts: new Date().toISOString(),
            level: level,
            traceId: _traceId
        }) + ' ';
    }

    var _origLog   = console.log.bind(console);
    var _origWarn  = console.warn.bind(console);
    var _origError = console.error.bind(console);

    console.log   = function () { _origLog  (buildPrefix('info'),  ...arguments); };
    console.warn  = function () { _origWarn (buildPrefix('warn'),  ...arguments); };
    console.error = function () { _origError(buildPrefix('error'), ...arguments); };

    // ---------------------------------------------------------------------------
    // Basket quantity update helpers (used by basket view)
    // ---------------------------------------------------------------------------
    window.eShop = window.eShop || {};

    window.eShop.updateQuantity = function (itemId, delta) {
        var input = document.getElementById('quantity_' + itemId);
        if (!input) return;
        var current = parseInt(input.value, 10) || 1;
        var next = Math.max(1, current + delta);
        input.value = next;
    };

    // ---------------------------------------------------------------------------
    // Toastr notification defaults
    // ---------------------------------------------------------------------------
    if (window.toastr) {
        toastr.options = {
            closeButton: true,
            progressBar: true,
            positionClass: 'toast-bottom-right',
            timeOut: 4000
        };
    }

    // ---------------------------------------------------------------------------
    // SIGTERM / page-unload telemetry flush
    // Attempt to flush any pending Application Insights telemetry before the
    // browser tears down the page so traces are not lost.
    // ---------------------------------------------------------------------------
    window.addEventListener('beforeunload', function () {
        if (window.appInsights && typeof window.appInsights.flush === 'function') {
            window.appInsights.flush();
        }
    });

})();
