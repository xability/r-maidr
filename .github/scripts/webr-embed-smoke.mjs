#!/usr/bin/env node
// Run the script `show()` sends to the page under webR, on a page, and use
// the chart the way a keyboard user does.
//
// `webr-embed-smoke.R` writes that script. Here it runs in headless Chromium
// on a page with a button either side of an empty `#maidr-output`, and the
// checks are the ones the webR path exists for:
//
//   * the chart is in an iframe inside `#maidr-output`;
//   * the frame settles at a height of its own: sizing it to its content
//     once fed back into the document's `100vh` and grew it without end;
//   * Tab from the button before lands in the chart, Right Arrow announces
//     a value, and Shift+Tab returns to the button;
//   * a page that defines `globalThis.maidrWebRShow` gets the document
//     instead of an iframe.
//
//     node .github/scripts/webr-embed-smoke.mjs <dir-with-show.js>
//
// Needs the `playwright` package and its Chromium; `MAIDR_SMOKE_CHROMIUM`
// names an executable to use instead of the one Playwright installed.

import { chromium } from 'playwright';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const dir = process.argv[2];
if (!dir) {
  console.error('usage: webr-embed-smoke.mjs <dir-with-show.js>');
  process.exit(2);
}
const show = readFileSync(path.join(dir, 'show.js'), 'utf8');

const launch = {};
if (process.env.MAIDR_SMOKE_CHROMIUM) {
  launch.executablePath = process.env.MAIDR_SMOKE_CHROMIUM;
}
const browser = await chromium.launch(launch);

const host = '<!doctype html><html><body><h1>App</h1><button id="before">before</button>'
  + '<div id="maidr-output"></div><button id="after">after</button></body></html>';
const failures = [];
const check = (ok, what) => {
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${what}`);
  if (!ok) {
    failures.push(what);
  }
};

const page = await browser.newPage({ viewport: { width: 900, height: 700 } });
const errors = [];
page.on('pageerror', error => errors.push(String(error)));
await page.setContent(host);

check((await page.evaluate(show)) === true, 'the script reports that it showed the chart');
await page.waitForTimeout(2500);

const framed = await page.evaluate(() => {
  const frame = document.querySelector('#maidr-output > iframe');
  return {
    inside: Boolean(frame),
    charts: frame ? frame.contentDocument.querySelectorAll('svg[maidr-data]').length : 0,
  };
});
check(framed.inside, 'the iframe is inside #maidr-output');
check(framed.charts === 1, 'the chart is drawn in the frame');

const heights = [];
for (let i = 0; i < 3; i++) {
  heights.push(await page.evaluate(() =>
    document.querySelector('#maidr-output > iframe').getBoundingClientRect().height));
  await page.waitForTimeout(400);
}
check(
  heights.every(h => h === heights[0]) && heights[0] > 100 && heights[0] < 900,
  `the frame settles at one height (${heights.join(', ')})`,
);

const live = async () => {
  const frame = page.frames().find(f => f !== page.mainFrame());
  return frame.evaluate(() =>
    Array.from(document.querySelectorAll('[aria-live], [role=status], [role=alert]'))
      .map(element => element.textContent.trim())
      .filter(Boolean)
      .join(' | '));
};
await page.focus('#before');
await page.keyboard.press('Tab');
await page.waitForTimeout(400);
check(
  await page.evaluate(() => document.activeElement.tagName === 'IFRAME'),
  'Tab from the button before reaches the chart',
);
await page.keyboard.press('ArrowRight');
await page.waitForTimeout(600);
const announced = await live();
check(/x is a, y is 3/.test(announced), `Right Arrow announces a value (${announced})`);
await page.keyboard.press('Shift+Tab');
await page.waitForTimeout(600);
check(
  await page.evaluate(() => document.activeElement.id === 'before'),
  'Shift+Tab returns to the button before',
);

await page.evaluate(() => {
  globalThis.__received = 0;
  globalThis.maidrWebRShow = html => { globalThis.__received = html.length; };
});
const before = await page.evaluate(() => document.querySelectorAll('iframe').length);
await page.evaluate(show);
check(
  await page.evaluate(() => globalThis.__received > 0),
  'a page-defined maidrWebRShow receives the document',
);
check(
  (await page.evaluate(() => document.querySelectorAll('iframe').length)) === before,
  'and no frame is added',
);
check(errors.length === 0, `no page errors${errors.length ? ': ' + errors[0] : ''}`);

await browser.close();
if (failures.length > 0) {
  console.error(`${failures.length} check(s) failed`);
  process.exit(1);
}
