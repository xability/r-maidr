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
//     one Tab from the last tab stop before it lands on the chart, and that
//     stop is outside the chart, and is the chart before it when one comes
//     just before, so no stray tab stop sits between them; Right Arrow
//     announces that chart's own first value, inside the chart, and draws
//     its highlight inside that chart's own svg, and Shift+Tab leaves it;
//   * maidr's help, opened from a chart on this Bootstrap 3 page, whose
//     root font size is 10px, shows its text and its title at their own
//     sizes, neither shrunk by the page nor enlarged twice, nor sized by
//     the page's rule for its paragraphs, within the window.
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
// the order they are on the page in. A chart is named by the text of the
// elements its aria-labelledby names, or by its aria-label.
const textOf = id => {
  const escaped = id.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const element = new RegExp(`\\bid="${escaped}"[^>]*>([^<]*)<`).exec(html);
  return element ? element[1] : '';
};
const names = Array.from(html.matchAll(/<svg\b[^>]*\bmaidr-knitr-svg\b[^>]*>/g), match => {
  const label = /\baria-label="([^"]*)"/.exec(match[0]);
  const labelledBy = /\baria-labelledby="([^"]*)"/.exec(match[0]);
  if (label) {
    return label[1];
  }
  return labelledBy ? labelledBy[1].split(/\s+/).map(textOf).join(' ') : '';
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
// last tab stop before its plot, so that the next Tab is the one a reader
// presses: the stops in document order (none has a positive tabindex),
// leaving out what is hidden, disabled or inert. Says what that stop is.
const approach = i => page.evaluate(i => {
  const plotOf = wrapper => wrapper.querySelector('figure[id^="maidr-figure"] > [tabindex="0"]');
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
  const stops = Array.from(
    document.querySelectorAll('a[href], button, input, select, textarea, [tabindex]'),
  ).filter(element => element.tabIndex >= 0 && !element.disabled
    && element.getClientRects().length > 0 && !element.closest('[inert]'));
  const at = stops.indexOf(plotOf(wrapper));
  const before = at > 0 ? stops[at - 1] : null;
  const previous = wrapper.previousElementSibling;
  const chartBefore = previous && previous.matches('.maidr-knitr') ? plotOf(previous) : null;
  // The page's start when no stop comes before: the body, focused for once.
  const target = before || document.body;
  const tabindex = target.getAttribute('tabindex');
  if (!before) {
    target.setAttribute('tabindex', '-1');
  }
  target.focus({ preventScroll: true });
  if (!before) {
    if (tabindex === null) {
      target.removeAttribute('tabindex');
    } else {
      target.setAttribute('tabindex', tabindex);
    }
  }
  return {
    found: at >= 0,
    inChart: Boolean(before) && wrapper.contains(before),
    afterChart: chartBefore === null || before === chartBefore,
    what: before ? `${before.tagName.toLowerCase()}${before.closest('.maidr-knitr') ? ' in a chart' : ''}` : 'the page start',
  };
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
  const before = await approach(i);
  await page.waitForTimeout(settle);
  check(
    before.found && !before.inChart && before.afterChart,
    `${chart.name}: the tab stop before it is outside it, and is the chart before it when one comes just before (${before.what})`,
  );

  await page.keyboard.press('Tab');
  await page.waitForTimeout(100);
  const reached = (await focus(i)).onChart;
  check(reached, `${chart.name}: one Tab from the stop before it reaches the chart`);
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

// maidr's help, from the first chart. Its text is sized in rem, which this
// Bootstrap 3 page makes 10px rather than 16px, until maidr.js or
// knitr-inline.js gives it back its size. Its button's text, which
// knitr-inline.js neither measures nor sets a font size on, is then shown at
// 14px and its title at 20px, as on a page that leaves its root alone: not
// 8.75px and 12.5px, nor, given back by both, 22.4px under a 20px title,
// nor, measured off the page's 18px paragraphs, 8.75px under a 25.7px
// title. The size a text is shown at is its font size times the zoom it is
// under.
await page.evaluate(() => {
  document.querySelector('.maidr-knitr figure[id^="maidr-figure"] > [tabindex="0"]').focus();
});
await page.keyboard.press('Control+Slash');
await page.waitForTimeout(settle * 2);
const help = await page.evaluate(() => {
  const paper = document.querySelector('.maidr-knitr .MuiDialog-paper');
  if (!paper) {
    return null;
  }
  const shown = selector => {
    const text = paper.querySelector(selector);
    return text ? Math.round(parseFloat(getComputedStyle(text).fontSize) * text.currentCSSZoom * 10) / 10 : null;
  };
  const box = paper.getBoundingClientRect();
  return {
    root: getComputedStyle(document.documentElement).fontSize,
    button: shown('.MuiButton-root'),
    title: shown('.MuiDialogTitle-root'),
    top: Math.round(box.top),
    bottom: Math.round(box.bottom),
    height: window.innerHeight,
  };
});
check(
  help !== null && Math.abs(help.button - 14) <= 0.5 && Math.abs(help.title - 20) <= 0.5
    && help.top >= 0 && help.bottom <= help.height,
  'maidr\'s help shows its text at its own size, within the window'
    + (help ? ` (root ${help.root}, button ${help.button}px, title ${help.title}px, ${help.top}-${help.bottom} of ${help.height})` : ': not opened'),
);
await page.keyboard.press('Escape');
await page.waitForTimeout(settle);

check(errors.length === 0, `no page errors${errors.length ? ': ' + errors.join(' | ') : ''}`);

await browser.close();
if (failures.length > 0) {
  console.error(`${failures.length} check(s) failed`);
  process.exit(1);
}
console.log(`${charts.length} inline chart(s) bound by one maidr.js, each announced and highlighted on its own`);
