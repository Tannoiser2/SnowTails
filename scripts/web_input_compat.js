/* Some TV/remote browsers activate the canvas with click only. Godot listens to
 * mousedown/up. Keep normal mouse/touch sequences untouched and let Godot do
 * hit testing, modal blocking, disabled checks and signal dispatch. */
(() => {
    if (new URLSearchParams(location.search).get('tv_click') === '0') return;
    const canvas = document.getElementById('canvas');
    if (!canvas || canvas.dataset.snowtailsClickCompat) return;
    canvas.dataset.snowtailsClickCompat = '1';
    let last = null;
    const remember = event => {
        if (!event.changedTouches && event.button !== 0) return;
        const point = event.changedTouches ? event.changedTouches[0] : event;
        if (!point) return;
        last = {x: point.clientX, y: point.clientY, time: performance.now()};
    };
    for (const type of ['mousedown', 'mouseup', 'touchstart', 'touchend']) {
        canvas.addEventListener(type, remember, {capture: true, passive: true});
    }
    canvas.addEventListener('click', event => {
        if (event.target !== canvas || event.button !== 0) return;
        const paired = last && performance.now() - last.time < 1500 &&
            Math.hypot(event.clientX - last.x, event.clientY - last.y) < 25;
        last = null;
        if (paired) return;
        // Keyboard/accessibility activation with no pointer location is not a tap.
        if (event.detail === 0 && event.clientX === 0 && event.clientY === 0) return;
        if (window.snowtailsInput) window.snowtailsInput.log('COMPAT click-only -> mouse down/up');
        const options = {
            bubbles: true, cancelable: true, view: window,
            clientX: event.clientX, clientY: event.clientY,
            screenX: event.screenX, screenY: event.screenY,
            button: 0, ctrlKey: event.ctrlKey, shiftKey: event.shiftKey,
            altKey: event.altKey, metaKey: event.metaKey
        };
        canvas.dispatchEvent(new MouseEvent('mousedown', {...options, buttons: 1}));
        canvas.dispatchEvent(new MouseEvent('mouseup', {...options, buttons: 0}));
        last = null;
    });
})();
