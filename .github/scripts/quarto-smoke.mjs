#!/usr/bin/env node
// Use the R charts of Quarto pages from the keyboard.
//
// `quarto-smoke.R` renders the pages with the Quarto CLI. Here each is
// loaded in headless Chromium and checked the way a reader would find it:
//
//   * `dash.html`, a dashboard: every chart is in one of its cards. With a
//     card shown full screen, Escape pressed in its chart -- on the chart,
//     or to close maidr's help -- leaves the card full screen, whether the
//     card was shown full screen before the chart had the focus or after,
//     and Escape pressed anywhere else in it takes it back. High contrast,
//     turned on in a chart, paints the chart dark and leaves the page in its
//     own colours, read from what the page shows whatever paints it.
//
//     node .github/scripts/quarto-smoke.mjs <dir-rendered-by-quarto-smoke.R>
//
// Needs the `playwright` package and its Chromium; `MAIDR_SMOKE_CHROMIUM`
// names an executable to use instead of the one Playwright installed.

import { chromium } from 'playwright';
import path from 'node:path';

const dir = process.argv[2];
if (!dir) {
  console.error('usage: quarto-smoke.mjs <dir-rendered-by-quarto-smoke.R>');
  process.exit(2);
}

const settle = 400;
const failures = [];
const check = (ok, what) => {
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${what}`);
  if (!ok) {
    failures.push(what);
  }
};

// The element maidr makes focusable around a chart's svg.
const plotOf = 'figure[id^="maidr-figure"] > [tabindex="0"]';

// The colours a reader sees around a chart: the page's body, and the
// nearest box from the chart's plot out to its wrapper that has a
// background of its own; null when none has.
const coloursScript = () => {
  window.__maidrSmokeColours = wrapper => {
    const body = getComputedStyle(document.body);
    const plot = wrapper.querySelector('figure[id^="maidr-figure"] > [tabindex="0"]');
    let backdrop = null;
    for (let at = plot; at && !backdrop; at = at === wrapper ? null : at.parentElement) {
      const colour = getComputedStyle(at).backgroundColor;
      if (colour !== 'transparent' && !/^rgba\(.*,\s*0\)$/.test(colour)) {
        backdrop = colour;
      }
    }
    return { body: [body.backgroundColor, body.color], backdrop };
  };
};
// A colour no channel of which is lighter than a quarter: maidr's default
// dark colour for high contrast is black.
const dark = colour => Boolean(colour)
  && Math.max(...colour.match(/[\d.]+/g).slice(0, 3).map(Number)) <= 64;
const sameColours = (a, b) => JSON.stringify(a) === JSON.stringify(b);
const coloursOf = (page, selector) => page.evaluate(
  selector => window.__maidrSmokeColours(document.querySelector(selector)),
  selector,
);

const launch = {};
if (process.env.MAIDR_SMOKE_CHROMIUM) {
  launch.executablePath = process.env.MAIDR_SMOKE_CHROMIUM;
}
const browser = await chromium.launch(launch);

// Load one of the pages, once maidr.js has bound `charts` charts on it.
const open = async (name, charts, viewport) => {
  const page = await browser.newPage({ viewport });
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));
  await page.addInitScript(coloursScript);
  await page.goto('file://' + path.resolve(dir, name), { waitUntil: 'load' });
  await page.waitForFunction(count => {
    const wrappers = document.querySelectorAll('.maidr-knitr');
    return wrappers.length === count
      && Array.from(wrappers).every(w => w.querySelector('article[id^="maidr-article-"]'));
  }, charts, { timeout: 15000 }).catch(() => {});
  await page.waitForTimeout(settle * 2);
  const bound = await page.evaluate(plotOf => document.querySelectorAll(`.maidr-knitr ${plotOf}`).length, plotOf);
  check(bound === charts, `${name}: maidr.js binds its ${charts} chart(s) (${bound})`);
  return { page, errors };
};

// --- A dashboard -------------------------------------------------------------

{
  const { page, errors } = await open('dash.html', 2, { width: 1200, height: 900 });
  const inCards = await page.evaluate(() => Array.from(
    document.querySelectorAll('.maidr-knitr'),
    wrapper => Boolean(wrapper.closest('.bslib-card')),
  ));
  check(
    inCards.length === 2 && inCards.every(Boolean),
    `dash.html: every chart is in a card (${JSON.stringify(inCards)})`,
  );

  const fullScreen = () => page.evaluate(
    () => document.querySelector('.maidr-knitr').closest('.bslib-card').getAttribute('data-full-screen'),
  );
  const showFullScreen = () => page.evaluate(() => {
    document.querySelector('.maidr-knitr').closest('.bslib-card')
      .querySelector('.bslib-full-screen-enter').click();
  });
  const helpOpen = () => page.evaluate(() => Boolean(document.querySelector('.maidr-knitr .MuiDialog-paper')));
  // Escape on the card's close button, which bslib shows while the card is
  // full screen: whether the card was full screen, and is not any more.
  const leaveByEscape = async () => {
    const shown = await page.evaluate(() => {
      const close = document.querySelector('.bslib-full-screen-exit');
      if (close) {
        close.focus();
      }
      return Boolean(close);
    });
    if (!shown) {
      return false;
    }
    await page.keyboard.press('Escape');
    await page.waitForTimeout(settle);
    return await fullScreen() === 'false';
  };

  // Shown full screen before the chart has the focus.
  await showFullScreen();
  await page.waitForTimeout(settle);
  check(await fullScreen() === 'true', 'dash.html: the first chart\'s card is shown full screen');
  await page.locator(`.maidr-knitr ${plotOf}`).first().focus();
  await page.waitForTimeout(settle);
  await page.keyboard.press('Escape');
  await page.waitForTimeout(settle);
  check(await fullScreen() === 'true', 'dash.html: Escape pressed in the chart leaves its card full screen');
  await page.keyboard.press('Control+Slash');
  await page.waitForTimeout(settle * 2);
  const opened = await helpOpen();
  await page.keyboard.press('Escape');
  await page.waitForTimeout(settle);
  const state = { opened, closed: !(await helpOpen()), fullScreen: await fullScreen() };
  check(
    state.opened && state.closed && state.fullScreen === 'true',
    `dash.html: Escape closes maidr's help and leaves the card full screen (${JSON.stringify(state)})`,
  );
  check(
    await leaveByEscape(),
    'dash.html: Escape pressed in the card outside the chart takes the card back',
  );

  // Shown full screen while the chart has the focus.
  await page.locator(`.maidr-knitr ${plotOf}`).first().focus();
  await page.waitForTimeout(settle);
  await showFullScreen();
  await page.waitForTimeout(settle);
  await page.locator(`.maidr-knitr ${plotOf}`).first().focus();
  await page.keyboard.press('Escape');
  await page.waitForTimeout(settle);
  check(
    await fullScreen() === 'true',
    'dash.html: Escape pressed in the chart leaves its card full screen when it was shown full screen from the chart',
  );
  check(
    await leaveByEscape(),
    'dash.html: Escape pressed outside the chart then takes the card back',
  );

  // High contrast.
  const plain = await coloursOf(page, '.maidr-knitr');
  await page.locator(`.maidr-knitr ${plotOf}`).first().focus();
  await page.waitForTimeout(settle);
  await page.keyboard.press('c');
  await page.waitForTimeout(settle);
  const contrasted = await coloursOf(page, '.maidr-knitr');
  check(
    sameColours(contrasted.body, plain.body) && dark(contrasted.backdrop),
    'dash.html: high contrast paints the chart dark and leaves the page in its own colours'
      + ` (page ${contrasted.body.join(' on ')}, was ${plain.body.join(' on ')}; chart ${contrasted.backdrop})`,
  );
  await page.keyboard.press('c');
  await page.waitForTimeout(settle);
  const off = await coloursOf(page, '.maidr-knitr');
  check(
    sameColours(off.body, plain.body) && off.backdrop === plain.backdrop,
    `dash.html: high contrast turned off leaves nothing painted (page ${off.body.join(' on ')}; chart ${off.backdrop})`,
  );

  check(errors.length === 0, `dash.html: no page errors${errors.length ? ': ' + errors.join(' | ') : ''}`);
  await page.close();
}

await browser.close();
if (failures.length > 0) {
  console.error(`${failures.length} check(s) failed`);
  process.exit(1);
}
console.log('the R charts of every Quarto page are used from the keyboard as on any other');
