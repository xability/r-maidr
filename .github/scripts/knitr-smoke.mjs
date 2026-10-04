#!/usr/bin/env node
// Use every chart of a knitted R Markdown page from the keyboard.
//
// `knitr-smoke.R` renders the page: charts of every system shown inline,
// several to the page and to a chunk, one of them in a tab hidden when the
// page loads, and a figure maidr does not read. Here it is loaded in
// headless Chromium and checked the way a reader would find it:
//
//   * the page raises no error, runs maidr.js once, and holds no iframe;
//   * every chart is bound by maidr.js, in the order the document draws
//     them, and no id is used twice before anything has the focus;
//   * the figure maidr does not read is knitr's own svglite image;
//   * for each chart in turn -- its tab opened first when it is hidden --
//     Tab from the element before it lands on the chart, Right Arrow
//     announces that chart's own first value, inside the chart, and draws
//     its highlight inside that chart's own svg, and Shift+Tab leaves it.
//
// A chart whose ids clashed with another's, or that was bound to another's
// data, announces or highlights the wrong chart; a page that loaded the
// bundle once per chart runs maidr.js more than once.
//
//     node .github/scripts/knitr-smoke.mjs <dir-with-charts.html>
//
// Needs the `playwright` package and its Chromium; `MAIDR_SMOKE_CHROMIUM`
// names an executable to use instead of the one Playwright installed.

import { chromium } from 'playwright';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const dir = process.argv[2];
if (!dir) {
  console.error('usage: knitr-smoke.mjs <dir-with-charts.html>');
  process.exit(2);
}
const file = path.resolve(dir, 'charts.html');
const html = readFileSync(file, 'utf8');

// The charts of knitr-smoke.R, in the order it draws them, and the first
// value each announces: a value no other chart on the page has. A chart of
// several subplots opens on the subplot chooser, and wants Enter before
// Right Arrow reads a value.
const charts = [
  { name: 'GG bar chart', announces: /\balpha\b.*\b11\b/ },
  { name: 'GG facet chart', announces: /\b21\b/, subplots: true },
  { name: 'Loop chart 1', announces: /\bloop1a\b.*\b40\b/ },
  { name: 'Loop chart 2', announces: /\bloop2a\b.*\b50\b/ },
  { name: 'Lattice bar chart', announces: /\blat1\b.*\b61\b/ },
  { name: 'Base bar chart', announces: /\bbase1\b.*\b71\b/ },
  { name: 'Base line chart', announces: /\b81\b/ },
  { name: 'Hidden tab chart', announces: /\bhid1\b.*\b91\b/ },
];

const settle = 400;
const failures = [];
const check = (ok, what) => {
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${what}`);
  if (!ok) {
    failures.push(what);
  }
};

// The names the charts carry until maidr.js binds them, read from the file:
// the order they are on the page in.
const names = Array.from(html.matchAll(/<svg\b[^>]*\bmaidr-knitr-svg\b[^>]*>/g), match => {
  const label = /\baria-label="([^"]*)"/.exec(match[0]);
  return label ? label[1] : '';
});
check(
  JSON.stringify(names) === JSON.stringify(charts.map(chart => chart.name)),
  `the page holds the ${charts.length} charts in the order the document draws them (${names.join(', ')})`,
);

const launch = {};
if (process.env.MAIDR_SMOKE_CHROMIUM) {
  launch.executablePath = process.env.MAIDR_SMOKE_CHROMIUM;
}
const browser = await chromium.launch(launch);
const page = await browser.newPage({ viewport: { width: 1200, height: 900 } });
const errors = [];
page.on('pageerror', error => errors.push(String(error)));

// maidr.js sets window.maidrLive as it runs: count how often that happens.
await page.addInitScript(() => {
  let live;
  window.__maidrRuns = 0;
  Object.defineProperty(window, 'maidrLive', {
    configurable: true,
    get: () => live,
    set: value => {
      window.__maidrRuns += 1;
      live = value;
    },
  });
});

await page.goto('file://' + file, { waitUntil: 'load' });
await page.waitForFunction(count => {
  const wrappers = document.querySelectorAll('.maidr-knitr');
  return wrappers.length === count
    && Array.from(wrappers).every(w => w.querySelector('article[id^="maidr-article-"]'));
}, charts.length, { timeout: 15000 }).catch(() => {});
await page.waitForTimeout(settle * 2);

const state = await page.evaluate(() => {
  const ids = Array.from(document.querySelectorAll('[id]'), element => element.id);
  const circle = document.querySelector('img[alt="A plain grey circle"]');
  return {
    runs: window.__maidrRuns,
    iframes: document.querySelectorAll('iframe').length,
    wrappers: document.querySelectorAll('.maidr-knitr').length,
    bound: Array.from(document.querySelectorAll('.maidr-knitr'))
      .filter(w => w.querySelector('article[id^="maidr-article-"]')).length,
    pending: document.querySelectorAll('[data-maidr-knitr]').length,
    duplicates: ids.filter((id, i) => ids.indexOf(id) !== i),
    circle: circle
      ? {
        src: (circle.getAttribute('src') || '').slice(0, 30),
        inChart: Boolean(circle.closest('.maidr-knitr')),
      }
      : null,
  };
});
check(state.runs === 1, `maidr.js runs once (${state.runs} time(s))`);
check(state.iframes === 0, `no iframe on the page (${state.iframes})`);
check(
  state.wrappers === charts.length && state.bound === charts.length && state.pending === 0,
  `every chart is bound (${state.bound} of ${state.wrappers} on the page, ${charts.length} drawn)`,
);
check(
  state.duplicates.length === 0,
  'no id is used twice before anything has the focus'
    + (state.duplicates.length ? ': ' + state.duplicates.slice(0, 5).join(', ') : ''),
);
check(
  state.circle !== null && state.circle.src.startsWith('data:image/svg+xml') && !state.circle.inChart,
  `the drawing maidr does not read is knitr's svglite image (${state.circle ? state.circle.src : 'not found'})`,
);

// Show chart i -- open the tab that hides it -- and put the focus on the
// element before it, so that the next Tab is the one a reader presses.
const approach = i => page.evaluate(i => {
  const wrapper = document.querySelectorAll('.maidr-knitr')[i];
  for (let element = wrapper.parentElement; element; element = element.parentElement) {
    if (element.id && element.getClientRects().length === 0) {
      const tab = document.querySelector(`a[href="#${CSS.escape(element.id)}"]`);
      if (tab) {
        tab.click();
      }
    }
  }
  wrapper.scrollIntoView({ block: 'center' });
  let before = wrapper.previousElementSibling || wrapper.parentElement;
  while (before && before.getClientRects().length === 0) {
    before = before.parentElement;
  }
  const tabindex = before.getAttribute('tabindex');
  before.setAttribute('tabindex', '-1');
  before.focus({ preventScroll: true });
  if (tabindex === null) {
    before.removeAttribute('tabindex');
  } else {
    before.setAttribute('tabindex', tabindex);
  }
}, i);

// Where the focus is, relative to chart i.
const focus = i => page.evaluate(i => {
  const wrapper = document.querySelectorAll('.maidr-knitr')[i];
  const plot = wrapper.querySelector('figure[id^="maidr-figure"] > [tabindex="0"]');
  const active = document.activeElement;
  return { onChart: Boolean(plot) && active === plot, inChart: wrapper.contains(active) };
}, i);

// What chart i says and shows after a key press.
const reading = i => page.evaluate(i => {
  const wrapper = document.querySelectorAll('.maidr-knitr')[i];
  const svg = wrapper.querySelector('svg');
  const text = document.querySelector('#maidr-text-container');
  const owned = Array.from(document.querySelectorAll('[data-maidr-owned]'));
  return {
    text: text ? text.textContent.trim() : '',
    textInChart: Boolean(text) && wrapper.contains(text),
    owned: owned.length,
    ownedInChart: owned.filter(element => svg && svg.contains(element)).length,
  };
}, i);

for (const [i, chart] of charts.entries()) {
  if (i >= state.wrappers) {
    check(false, `${chart.name}: not on the page`);
    continue;
  }
  await approach(i);
  await page.waitForTimeout(settle);

  let presses = 0;
  while (!(await focus(i)).onChart && presses < 5) {
    await page.keyboard.press('Tab');
    await page.waitForTimeout(100);
    presses += 1;
  }
  const reached = (await focus(i)).onChart;
  check(reached, `${chart.name}: Tab from the element before it reaches the chart (${presses} press(es))`);
  if (!reached) {
    continue;
  }

  if (chart.subplots) {
    await page.keyboard.press('Enter');
    await page.waitForTimeout(settle);
  }
  await page.keyboard.press('ArrowRight');
  await page.waitForTimeout(settle);
  const seen = await reading(i);
  check(
    chart.announces.test(seen.text) && seen.textInChart,
    `${chart.name}: Right Arrow announces its own value, inside the chart ("${seen.text}")`,
  );
  check(
    seen.owned > 0 && seen.owned === seen.ownedInChart,
    `${chart.name}: the highlight is drawn inside its own svg (${seen.ownedInChart} of ${seen.owned} clone(s))`,
  );

  await page.keyboard.press('Shift+Tab');
  await page.waitForTimeout(settle);
  check(!(await focus(i)).inChart, `${chart.name}: Shift+Tab leaves the chart`);
}

check(errors.length === 0, `no page errors${errors.length ? ': ' + errors.join(' | ') : ''}`);

await browser.close();
if (failures.length > 0) {
  console.error(`${failures.length} check(s) failed`);
  process.exit(1);
}
console.log(`${charts.length} inline chart(s) bound by one maidr.js, each announced and highlighted on its own`);
