#!/usr/bin/env node
// Press Right Arrow on each rendered chart and check that something on it
// changed colour.
//
// The MAIDR payload can be valid, every value can be announced, and the
// chart can still draw no highlight: that is exactly what the 4.0 bundle
// refresh did to bar, point, histogram, dodged, stacked and pie layers
// (#316), and no test in the package could see it, because they all read
// the payload and none of them ran the frontend. This does. It loads each
// document from `highlight-smoke.R` in headless Chromium, enters the chart
// the way a keyboard user does (Tab, then Right Arrow), and asks the DOM
// for the highlight the frontend draws: a clone of the mark that it tags
// `data-maidr-owned` and makes visible. No visible owned clone after two
// presses means the layer lost its highlight, whatever the payload says.
//
// A page error fails the chart too: a selector that does not parse throws
// inside the trace constructor, which is a chart with no navigation at all.
//
// For the charts whose mark is a bar, a visible clone is not enough: a
// segmented layer that declares the wrong `domMapping` outlines a bar, just
// not the one being announced (#316 again, on its second round). So on those
// charts every step is recorded as (announced value, height of the outlined
// mark), and the heights have to rank the same way the values do -- a taller
// bar is a larger number, on every chart here.
//
// For the area charts, a visible clone is not enough either: the frontend
// draws their outline at a point it samples along the band's edge, so a
// sampling bug leaves one outline standing still while the reader moves.
// The outline has to be in more than one place across the steps.
//
//     node .github/scripts/highlight-smoke.mjs <dir-of-html>
//
// Needs the `playwright` package and its Chromium (`npx playwright install
// --with-deps chromium`); `MAIDR_SMOKE_CHROMIUM` names an executable to
// use instead of the one Playwright installed.

import { chromium } from 'playwright';
import { readdirSync } from 'node:fs';
import path from 'node:path';

const dir = process.argv[2];
if (!dir) {
  console.error('usage: highlight-smoke.mjs <dir-of-html>');
  process.exit(2);
}

const files = readdirSync(dir).filter(f => f.endsWith('.html')).sort();
if (files.length === 0) {
  console.error(`no .html documents in ${dir}`);
  process.exit(2);
}

const settle = 400;
const launch = {};
if (process.env.MAIDR_SMOKE_CHROMIUM) {
  launch.executablePath = process.env.MAIDR_SMOKE_CHROMIUM;
}
const browser = await chromium.launch(launch);

let failed = 0;
for (const file of files) {
  const page = await browser.newPage();
  const errors = [];
  page.on('pageerror', error => errors.push(String(error)));

  await page.goto('file://' + path.resolve(dir, file));
  await page.waitForTimeout(settle * 2);

  // Tab reaches the figure. A figure with several subplots opens on the
  // subplot chooser and wants Enter before its arrows walk a chart; the
  // fixtures here are all single-subplot, but reading the payload keeps the
  // script honest if one grows a facet.
  await page.keyboard.press('Tab');
  await page.waitForTimeout(settle);
  const subplots = await page.evaluate(() => {
    const svg = document.querySelector('svg[maidr-data]');
    if (!svg) {
      return 0;
    }
    const data = JSON.parse(svg.getAttribute('maidr-data'));
    return data.subplots.flat().length;
  });
  if (subplots > 1) {
    await page.keyboard.press('Enter');
    await page.waitForTimeout(settle);
  }
  // What the DOM shows after a step: how many clones the frontend owns, how
  // many are visible, and the height of the first visible one alongside the
  // value the announcement ends with.
  const observe = () => page.evaluate(() => {
    const owned = Array.from(document.querySelectorAll('svg [data-maidr-owned]'));
    const visible = owned.filter(element =>
      getComputedStyle(element).visibility !== 'hidden'
      && element.getAttribute('visibility') !== 'hidden',
    );
    const live = document.querySelector('#maidr-text-container, [aria-live]');
    const text = live ? live.textContent.trim() : '';
    const numbers = text.match(/-?\d+(?:\.\d+)?/g);
    const first = visible[0];
    const box = first ? first.getBoundingClientRect() : null;
    return {
      subplots: document.querySelectorAll('svg[maidr-data]').length,
      owned: owned.length,
      visible: visible.length,
      text,
      value: numbers && !/No more data/.test(text) ? Number(numbers[numbers.length - 1]) : null,
      height: first ? first.getBBox().height : null,
      mark: first ? first.previousElementSibling?.id ?? null : null,
      at: box ? `${Math.round(box.x + box.width / 2)},${Math.round(box.y + box.height / 2)}` : null,
    };
  });

  // Right along the first row, then up a row and back along it: on a grid
  // that reads both series, on a single row the second half repeats it.
  const steps = [];
  for (const key of ['ArrowRight', 'ArrowRight', 'ArrowRight', 'ArrowUp', 'ArrowLeft', 'ArrowLeft']) {
    await page.keyboard.press(key);
    await page.waitForTimeout(settle);
    steps.push(await observe());
  }
  const seen = steps[1];
  const anyVisible = steps.some(step => step.visible > 0);

  // The bar-shaped charts: the outlined mark's height has to rank the way
  // the announced values do. Two distinct values outlined with the same
  // mark, or a larger value on a shorter bar, is the wrong bar.
  const ranked = /^(ggplot2-(bar|hist|dodged|stacked|normalized)|base-(barplot|hist|dodged|stacked|lollipop))\.html$/.test(file);
  let misranked = null;
  if (ranked) {
    const byMark = new Map();
    for (const step of steps) {
      if (step.value === null || step.height === null || step.mark === null) {
        continue;
      }
      byMark.set(step.mark, { value: step.value, height: step.height });
    }
    const readings = Array.from(byMark.values()).sort((a, b) => a.value - b.value);
    for (let i = 1; i < readings.length; i++) {
      const lower = readings[i - 1];
      const upper = readings[i];
      const wrong = upper.value > lower.value
        ? upper.height <= lower.height + 0.5
        : Math.abs(upper.height - lower.height) > 0.5;
      if (wrong) {
        misranked = `${lower.value} on a ${lower.height.toFixed(1)}px bar but ${upper.value} on a ${upper.height.toFixed(1)}px bar`;
        break;
      }
    }
    if (readings.length < 2) {
      misranked = 'fewer than two announced values could be paired with a mark';
    }
  }

  // The area charts: the outline has to follow the reader.
  const moving = /^(ggplot2-(area|stacked-area|normalized-area|ribbon|polygon)|base-cdplot)\.html$/.test(file);
  const places = new Set(steps.map(step => step.at).filter(at => at !== null));
  const stuck = moving && places.size < 2;

  const ok = errors.length === 0 && seen.subplots > 0 && anyVisible && misranked === null && !stuck;
  if (!ok) {
    failed += 1;
  }
  console.log(
    `${ok ? 'ok  ' : 'FAIL'} ${file}: ${seen.owned} owned clone(s), ${seen.visible} visible`
    + (ranked ? (misranked ? `, wrong bar: ${misranked}` : ', heights rank with values') : '')
    + (moving ? (stuck ? ', outline stayed put while the reader moved' : ', outline follows the reader') : '')
    + (errors.length ? `, page errors: ${errors.join(' | ')}` : ''),
  );
  await page.close();
}

await browser.close();

if (failed > 0) {
  console.error(`${failed} of ${files.length} chart(s) drew no highlight, outlined the wrong bar, or left the outline behind`);
  process.exit(1);
}
console.log(`${files.length} chart(s) highlighted, the bar-shaped ones on the announced bar, the area ones following the reader`);
