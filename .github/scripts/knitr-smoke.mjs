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
//   * every chart is drawn at its chunk's fig.width and fig.height: its svg
//     is that many inches at 72 pixels each, in its width, height and
//     viewBox, nothing it draws reaches outside its viewBox, and the tick
//     labels of each axis stand apart;
//   * for each chart in turn -- its tab opened first when it is hidden --
//     one Tab from the last tab stop before it lands on the chart, and that
//     stop is outside the chart, and is the chart before it when one comes
//     just before, so no stray tab stop sits between them; Right Arrow
//     announces that chart's own first value, inside the chart, and draws
//     its highlight inside that chart's own svg and viewBox, and Shift+Tab
//     leaves it;
//   * maidr's help, opened from a chart on this Bootstrap 3 page, whose
//     root font size is 10px, shows its text at its own size, within the
//     window.
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
// Right Arrow reads a value. `size` is the chunk's fig.width and fig.height,
// html_document's 7 x 5 unless the chunk sets them.
const charts = [
  { name: 'GG bar chart', announces: /\balpha\b.*\b11\b/ },
  { name: 'GG facet chart', announces: /\b21\b/, subplots: true },
  { name: 'Loop chart 1', announces: /\bloop1a\b.*\b40\b/ },
  { name: 'Loop chart 2', announces: /\bloop2a\b.*\b50\b/ },
  { name: 'Lattice bar chart', announces: /\blat1\b.*\b61\b/ },
  { name: 'Base bar chart', announces: /\bbase1\b.*\b71\b/ },
  { name: 'Base line chart', announces: /\b81\b/ },
  { name: 'Wide bar chart', announces: /\bwide1\b.*\b101\b/, size: [10, 4] },
  { name: 'Tall bar chart', announces: /\btall1\b.*\b111\b/, size: [5, 8] },
  { name: 'Base grid chart', announces: /\b121\b/, subplots: true, size: [10, 4] },
  { name: 'Hidden tab chart', announces: /\bhid1\b.*\b91\b/ },
].map(chart => ({ size: [7, 5], ...chart }));

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

// A box on the page, in the user units of the svg it is drawn in: the page
// may show a chart smaller than its own size.
await page.addInitScript(() => {
  window.__maidrSmokeUserBox = (svg, box) => {
    const page = svg.getBoundingClientRect();
    const scale = page.width / svg.viewBox.baseVal.width;
    return {
      left: (box.left - page.left) / scale,
      top: (box.top - page.top) / scale,
      right: (box.right - page.left) / scale,
      bottom: (box.bottom - page.top) / scale,
    };
  };
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

// Chart i's size, what it draws outside its viewBox, and the tick labels of
// an axis that overlap one another. A shape's box is cut to the clip path
// it is drawn under, as the shape is. A tick label is a text of an axis
// group: ggplot2's axis-l/b/t/r, Base R's -axis-labels-, lattice's
// .ticklabels.; inline ids carry the chart's prefix before them.
const geometry = i => page.evaluate(i => {
  const toUser = window.__maidrSmokeUserBox;
  const svg = document.querySelectorAll('.maidr-knitr')[i].querySelector('svg');
  const view = svg.viewBox.baseVal;
  const clipOf = element => {
    let box = null;
    for (let at = element; at && at !== svg; at = at.parentElement) {
      const url = at.getAttribute('clip-path');
      const clip = url && document.getElementById(url.replace(/^url\(#?|\)$/g, ''));
      const shape = clip && clip.querySelector('rect, path, polygon');
      if (shape) {
        const c = toUser(svg, shape.getBoundingClientRect());
        box = box ? {
          left: Math.max(box.left, c.left), top: Math.max(box.top, c.top),
          right: Math.min(box.right, c.right), bottom: Math.min(box.bottom, c.bottom),
        } : c;
      }
    }
    return box;
  };
  const outside = [];
  const shapes = svg.querySelectorAll('rect, circle, ellipse, line, polyline, polygon, path, text, use, image');
  for (const shape of shapes) {
    if (shape.closest('defs, clipPath, symbol, mask, pattern')) {
      continue;
    }
    const drawn = shape.getBoundingClientRect();
    if (drawn.width === 0 && drawn.height === 0) {
      continue;
    }
    let box = toUser(svg, drawn);
    const clip = clipOf(shape);
    if (clip) {
      box = {
        left: Math.max(box.left, clip.left), top: Math.max(box.top, clip.top),
        right: Math.min(box.right, clip.right), bottom: Math.min(box.bottom, clip.bottom),
      };
    }
    if (box.right <= box.left || box.bottom <= box.top) {
      continue;
    }
    if (box.left < -1 || box.top < -1 || box.right > view.width + 1 || box.bottom > view.height + 1) {
      outside.push(`${shape.tagName} ${shape.id || shape.textContent}`);
    }
  }
  const axis = /(^|-)(axis-[lbrt](-\d+-\d+)?\.[\d-]+\.\d+|graphics-plot-\d+-[a-z]+-axis-labels-\d+\.\d+|maidr\.ticklabels\.[a-z]+\.panel\.\d+\.\d+\.\d+)$/;
  const labels = new Map();
  for (const text of svg.querySelectorAll('text')) {
    let group = text.parentElement;
    while (group && group !== svg && !axis.test(group.id)) {
      group = group.parentElement;
    }
    if (!group || group === svg || !text.textContent.trim()) {
      continue;
    }
    labels.set(group, [...(labels.get(group) || []), text]);
  }
  const overlaps = [];
  for (const texts of labels.values()) {
    const boxes = texts.map(text => toUser(svg, text.getBoundingClientRect()));
    for (let a = 0; a < boxes.length; a++) {
      for (let b = a + 1; b < boxes.length; b++) {
        const across = Math.min(boxes[a].right, boxes[b].right) - Math.max(boxes[a].left, boxes[b].left);
        const down = Math.min(boxes[a].bottom, boxes[b].bottom) - Math.max(boxes[a].top, boxes[b].top);
        if (across > 0.5 && down > 0.5) {
          overlaps.push(`"${texts[a].textContent}" and "${texts[b].textContent}"`);
        }
      }
    }
  }
  return {
    size: [svg.getAttribute('width'), svg.getAttribute('height'), svg.getAttribute('viewBox')],
    outside,
    axes: labels.size,
    overlaps,
  };
}, i);

// What chart i says and shows after a key press.
const reading = i => page.evaluate(i => {
  const toUser = window.__maidrSmokeUserBox;
  const wrapper = document.querySelectorAll('.maidr-knitr')[i];
  const svg = wrapper.querySelector('svg');
  const text = document.querySelector('#maidr-text-container');
  const owned = Array.from(document.querySelectorAll('[data-maidr-owned]'));
  const view = svg.viewBox.baseVal;
  const inView = element => {
    const box = toUser(svg, element.getBoundingClientRect());
    return box.left >= -1 && box.top >= -1 && box.right <= view.width + 1 && box.bottom <= view.height + 1;
  };
  return {
    text: text ? text.textContent.trim() : '',
    textInChart: Boolean(text) && wrapper.contains(text),
    owned: owned.length,
    ownedInChart: owned.filter(element => svg && svg.contains(element) && inView(element)).length,
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

  const drawn = await geometry(i);
  const [width, height] = chart.size.map(inches => inches * 72);
  check(
    JSON.stringify(drawn.size) === JSON.stringify([`${width}px`, `${height}px`, `0 0 ${width} ${height}`]),
    `${chart.name}: drawn at its chunk's ${chart.size.join(' x ')} in (${drawn.size.join(', ')})`,
  );
  check(
    drawn.outside.length === 0,
    `${chart.name}: draws nothing outside its viewBox${drawn.outside.length ? ': ' + drawn.outside.slice(0, 5).join(', ') : ''}`,
  );
  check(
    drawn.axes > 0 && drawn.overlaps.length === 0,
    `${chart.name}: the tick labels of its ${drawn.axes} axes stand apart${drawn.overlaps.length ? ': ' + drawn.overlaps.slice(0, 5).join(', ') : ''}`,
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
    `${chart.name}: the highlight is drawn inside its own svg and viewBox (${seen.ownedInChart} of ${seen.owned} clone(s))`,
  );

  await page.keyboard.press('Shift+Tab');
  await page.waitForTimeout(settle);
  check(!(await focus(i)).inChart, `${chart.name}: Shift+Tab leaves the chart`);
}

// maidr's help, from the first chart. Its text is sized in rem, which this
// Bootstrap 3 page makes 10px rather than 16px; knitr-inline.js zooms it
// back. A line of 14px text is about 16px high; one of 8.75px, 10px.
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
  const text = Array.from(paper.querySelectorAll('td, p, li')).find(e => e.textContent.trim());
  const range = document.createRange();
  range.selectNodeContents(text);
  const box = paper.getBoundingClientRect();
  return {
    root: getComputedStyle(document.documentElement).fontSize,
    line: Math.round(range.getClientRects()[0].height),
    top: Math.round(box.top),
    bottom: Math.round(box.bottom),
    height: window.innerHeight,
  };
});
check(
  help !== null && help.line >= 14 && help.top >= 0 && help.bottom <= help.height,
  'maidr\'s help shows its text at its own size, within the window'
    + (help ? ` (root ${help.root}, a line ${help.line}px high, ${help.top}-${help.bottom} of ${help.height})` : ': not opened'),
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
