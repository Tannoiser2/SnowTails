// Prove diagnostics work even when the engine cannot load, and are opt-in.
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
(async () => {
    const browser = await chromium.launch({executablePath: process.env.CHROMIUM || '/usr/bin/chromium', headless: true, args: ['--no-sandbox']});
    try {
        for (const enabled of [true, false]) {
            const page = await browser.newPage();
            await page.route('**/index.js', route => route.abort());
            const url = new URL(process.env.ST_WEB_URL || 'http://127.0.0.1:8060/');
            if (enabled) url.searchParams.set('input_debug', '1');
            await page.goto(url.href, {waitUntil: 'load'});
            assert.equal(await page.evaluate(() => typeof window.snowtailsInput), 'undefined');
            if (enabled) {
                const trace = await page.locator('#startup-trace').textContent();
                assert.match(trace, /RISORSA NON CARICATA: .*index\.js/);
                assert.match(trace, /Browser:/);
                assert.equal(await page.locator('#startup-trace').evaluate(e => getComputedStyle(e).pointerEvents), 'none');
            } else {
                assert.equal(await page.locator('#startup-trace').count(), 0);
                assert.equal(await page.evaluate(() => typeof window.snowtailsStartup), 'undefined');
            }
            await page.close();
        }
        console.log('2/2 pre-engine diagnostic scenarios passed');
    } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exitCode = 1; });
