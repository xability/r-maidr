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
  await page.keyboard.press('ArrowRight');
  await page.waitForTimeout(settle);
  await page.keyboard.press('ArrowRight');
  await page.waitForTimeout(settle);

  const seen = await page.evaluate(() => {
    const owned = Array.from(document.querySelectorAll('svg [data-maidr-owned]'));
    const visible = owned.filter(element =>
      getComputedStyle(element).visibility !== 'hidden'
      && element.getAttribute('visibility') !== 'hidden',
    );
    return { subplots: document.querySelectorAll('svg[maidr-data]').length, owned: owned.length, visible: visible.length };
  });

  const ok = errors.length === 0 && seen.subplots > 0 && seen.visible > 0;
  if (!ok) {
    failed += 1;
  }
  console.log(
    `${ok ? 'ok  ' : 'FAIL'} ${file}: ${seen.owned} owned clone(s), ${seen.visible} visible`
    + (errors.length ? `, page errors: ${errors.join(' | ')}` : ''),
  );
  await page.close();
}

await browser.close();

if (failed > 0) {
  console.error(`${failed} of ${files.length} chart(s) drew no highlight`);
  process.exit(1);
}
console.log(`${files.length} chart(s) highlighted`);
