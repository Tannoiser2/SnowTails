// Run against a Godot Web export served over HTTP. Requires Playwright + Chromium.
// NODE_PATH may point to an existing Playwright installation; no project deps change.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const url = process.env.ST_WEB_URL || 'http://127.0.0.1:8060/';
(async () => {
    const browser = await chromium.launch({
        executablePath: process.env.CHROMIUM || '/usr/bin/chromium',
        args: ['--no-sandbox', '--enable-unsafe-swiftshader'], headless: true
    });
    let passed = 0;
    try {
        for (const scenario of [
            {name: 'baseline click-only', clickOnly: true, baseline: true, expected: 0},
            {name: 'fixed click-only', clickOnly: true, expected: 1},
            {name: 'mouse', expected: 1},
            {name: 'mouse on touch-capable browser', touch: true, expected: 1},
            {name: 'touch', touch: true, tap: true, expected: 1},
            {name: 'scaled portrait click-only', clickOnly: true, portrait: true, expected: 1}
        ]) {
            const context = await browser.newContext({
                viewport: scenario.portrait ? {width: 720, height: 1280} : {width: 1920, height: 1080},
                hasTouch: !!scenario.touch
            });
            const page = await context.newPage();
            const errors = [];
            page.on('pageerror', e => errors.push(e.message));
            page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
            const target = new URL(url);
            target.searchParams.set('input_debug', '1');
            if (scenario.baseline) target.searchParams.set('tv_click', '0');
            await page.goto(target.href);
            await page.waitForFunction(() => window.snowtailsInput?.controls.some(c => c.text === 'Regole'), null, {timeout: 90000});
            await page.waitForTimeout(1000); // allow the modal's deferred fit to settle
            const point = await page.evaluate(() => {
                const control = snowtailsInput.controls.filter(c => c.text === 'Regole').at(-1);
                const canvas = document.querySelector('canvas'), r = canvas.getBoundingClientRect();
                const x = r.x + (control.rect[0] + control.rect[2] / 2) * r.width / canvas.width;
                const y = r.y + (control.rect[1] + control.rect[3] / 2) * r.height / canvas.height;
                return {x, y, target: document.elementFromPoint(x, y).id};
            });
            assert.equal(point.target, 'canvas', 'HTML field must not cover the button');
            if (scenario.clickOnly) {
                await page.evaluate(p => document.querySelector('canvas').dispatchEvent(new MouseEvent('click', {
                    bubbles: true, clientX: p.x, clientY: p.y, button: 0
                })), point);
            } else if (scenario.tap) await page.touchscreen.tap(point.x, point.y);
            else await page.mouse.click(point.x, point.y);
            await page.waitForTimeout(1200);
            const result = await page.evaluate(() => ({
                pressed: snowtailsInput.events.filter(e => e.startsWith('PRESSED')).length,
                compat: snowtailsInput.events.filter(e => e.startsWith('COMPAT')).length,
                help: snowtailsInput.controls.some(c => c.text === 'Chiudi')
            }));
            assert.equal(result.pressed, scenario.expected, scenario.name + ': exactly one activation');
            assert.equal(result.help, scenario.expected === 1, scenario.name + ': help actually opened');
            assert.equal(result.compat, scenario.clickOnly && !scenario.baseline ? 1 : 0, 'no fallback on normal mouse/touch');
            assert.deepEqual(errors, [], scenario.name + ': browser/Godot errors');
            console.log('PASS', scenario.name);
            passed++;
            await context.close();
        }
        console.log(`${passed}/6 browser input scenarios passed`);
    } finally {
        await browser.close();
    }
})().catch(e => { console.error(e); process.exitCode = 1; });
