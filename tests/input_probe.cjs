const {chromium} = require('playwright');
const assert = require('node:assert/strict');
(async () => {
 const browser = await chromium.launch({executablePath:process.env.CHROMIUM || '/usr/bin/chromium', headless:true, args:['--no-sandbox']});
 try {
  for (const touch of [false,true]) {
   const context = await browser.newContext({hasTouch:touch,viewport:{width:1280,height:720}});
   const page = await context.newPage(); const errors=[];
   page.on('pageerror',e=>errors.push(e.message));
   await page.goto(new URL('input-probe.html',process.env.ST_WEB_URL || 'http://127.0.0.1:8060/').href);
   for (const id of ['html','canvas','canvas-none']) {
    if(touch) await page.locator('#'+id).tap();
    else await page.locator('#'+id).click();
   }
   assert.deepEqual(await page.evaluate(()=>window.inputProbeCounts),{html:1,canvas:1,'canvas-none':1});
   assert.deepEqual(errors,[]);
   await context.close();
  }
  console.log('2/2 standalone probe scenarios passed');
 } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
