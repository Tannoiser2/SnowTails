/* Runs before Godot/WASM so a TV can report failures before the game starts. */
(function () {
    if (!/(?:^|[?&])input_debug=1(?:&|$)/.test(location.search)) return;
    var lines = [];
    var panel;
    var progress = '';
    function log(message) {
        lines.push(String(message));
        if (lines.length > 8) lines.shift();
        if (panel) panel.textContent = 'AVVIO SNOWTAILS (Release)\n' + lines.join('\n');
    }
    window.snowtailsStartup = log;
    log('Browser: ' + navigator.userAgent);
    log('HTTPS sicuro: ' + window.isSecureContext + ' | WebAssembly: ' + (typeof WebAssembly !== 'undefined'));
    window.addEventListener('error', function (event) {
        if (event.message) log('ERRORE: ' + event.message + ' (' + event.filename + ':' + event.lineno + ')');
        else if (event.target && event.target !== window) log('RISORSA NON CARICATA: ' + (event.target.src || event.target.href || event.target.tagName));
    }, true);
    window.addEventListener('unhandledrejection', function (event) {
        log('PROMESSA FALLITA: ' + String(event.reason));
    });
    var originalError = console.error;
    console.error = function () {
        log('MOTORE: ' + Array.prototype.join.call(arguments, ' '));
        originalError.apply(console, arguments);
    };
    document.addEventListener('DOMContentLoaded', function () {
        panel = document.createElement('pre');
        panel.id = 'startup-trace';
        panel.style.cssText = 'position:fixed;top:0;left:0;right:0;z-index:101;pointer-events:none;white-space:pre-wrap;background:#000d;color:#fff;font:14px monospace;margin:0;padding:6px';
        document.body.appendChild(panel);
        log('Pagina caricata; attendo il motore.');
        var canvas = document.getElementById('canvas');
        if (canvas) canvas.addEventListener('webglcontextlost', function () { log('CONTESTO WEBGL PERSO'); });
        var timer = setInterval(function () {
            var bar = document.getElementById('status-progress');
            if (bar) {
                var next = bar.value + '/' + bar.max;
                if (next !== progress) { progress = next; log('Download motore/dati: ' + next); }
            }
            if (window.snowtailsInput && window.snowtailsInput.controls.some(function (c) { return c.text === 'Regole'; })) {
                log('MENU PRONTO. Ora provare Regole.');
                panel.style.display = 'none';
                clearInterval(timer);
            }
        }, 2000);
        setTimeout(function () {
            if (!window.snowtailsInput) log('Dopo 60s Godot non ha ancora avviato la diagnostica. Fotografare questo riquadro.');
        }, 60000);
    });
})();
