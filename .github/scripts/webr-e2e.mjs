#!/usr/bin/env node
// Run maidr in a real webR session in a real browser, and show a chart.
//
// Everything else that touches webR stops short of this. The page script is
// run on its own in `webr-embed-smoke.mjs`, and webR in Node has no page. Here
// webR runs the way a user's does: R in a web worker, on a page, with the
// package installed from a repository built for it, and `show()` has to put
// the chart on that page.
//
//     node .github/scripts/webr-e2e.mjs <webr-repo-dir>
//
// `<webr-repo-dir>` is what `rwasm::add_pkg()` writes: a package repository
// with maidr built for webR in it. It is served beside the `webr` package's
// own files, from one origin that sends the headers a page needs for webR's
// shared-memory channel. Needs the `webr` and `playwright` packages and
// Chromium; `MAIDR_SMOKE_CHROMIUM` names an executable to use instead of the
// one Playwright installed.
//
// webR fetches the packages maidr depends on from repo.r-wasm.org, from the
// browser. Where the browser has no route of its own to the internet but node
// has, `WEBR_E2E_FETCH_VIA_NODE=1` has node make those requests instead.

import { chromium } from 'playwright';
import { createServer } from 'node:http';
import { createReadStream, existsSync, statSync } from 'node:fs';
import { createRequire } from 'node:module';
import path from 'node:path';

const repoDir = process.argv[2];
if (!repoDir || !existsSync(repoDir)) {
  console.error('usage: webr-e2e.mjs <webr-repo-dir>');
  process.exit(2);
}
const webrDist = path.join(
  path.dirname(createRequire(import.meta.url).resolve('webr')),
);

const types = {
  '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.wasm': 'application/wasm', '.json': 'application/json', '.map': 'application/json',
  '.gz': 'application/gzip', '.tgz': 'application/gzip', '.data': 'application/octet-stream',
};

const page = `<!doctype html><html lang="en"><head><meta charset="utf-8"><title>webR</title></head>
<body><h1>webR app</h1><button id="before">before</button>
<div id="maidr-output"></div><button id="after">after</button>
<script type="module">
  import { WebR } from '/webr/webr.js';
  const webR = new WebR({ baseUrl: '/webr/' });
  window.webR = webR;
  window.ready = (async () => {
    await webR.init();
    await webR.installPackages(['maidr'], {
      repos: [location.origin + '/repo/', 'https://repo.r-wasm.org/'],
      quiet: true,
    });
    return true;
  })();
</script></body></html>`;

// Serve from under a root, refusing to leave it.
const serveFile = (root, rel, res) => {
  const file = path.join(root, path.normalize(rel));
  const inside = path.relative(root, file);
  if (inside.startsWith('..') || path.isAbsolute(inside)
    || !existsSync(file) || !statSync(file).isFile()) {
    res.writeHead(404).end();
    return;
  }
  res.writeHead(200, { 'content-type': types[path.extname(file)] ?? 'application/octet-stream' });
  createReadStream(file).pipe(res);
};

const server = createServer((req, res) => {
  // What webR's shared-memory channel needs from the page.
  res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
  res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
  res.setHeader('Cross-Origin-Resource-Policy', 'same-origin');
  const url = new URL(req.url, 'http://localhost');
  if (url.pathname === '/') {
    res.writeHead(200, { 'content-type': 'text/html' }).end(page);
  } else if (url.pathname.startsWith('/webr/')) {
    serveFile(webrDist, url.pathname.slice('/webr/'.length), res);
  } else if (url.pathname.startsWith('/repo/')) {
    serveFile(path.resolve(repoDir), url.pathname.slice('/repo/'.length), res);
  } else {
    res.writeHead(404).end();
  }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const origin = `http://127.0.0.1:${server.address().port}`;

const launch = {};
if (process.env.MAIDR_SMOKE_CHROMIUM) {
  launch.executablePath = process.env.MAIDR_SMOKE_CHROMIUM;
}
const browser = await chromium.launch(launch);
const tab = await browser.newPage({ viewport: { width: 900, height: 800 } });
const errors = [];
tab.on('pageerror', error => errors.push(String(error)));

if (process.env.WEBR_E2E_FETCH_VIA_NODE === '1') {
  await tab.route(/^https:\/\/(?!127\.)/, async route => {
    const request = route.request();
    try {
      const response = await fetch(request.url());
      await route.fulfill({
        status: response.status,
        headers: {
          'content-type': response.headers.get('content-type') ?? 'application/octet-stream',
          'access-control-allow-origin': '*',
          'cross-origin-resource-policy': 'cross-origin',
        },
        body: Buffer.from(await response.arrayBuffer()),
      });
    } catch (error) {
      console.error(`  could not fetch ${request.url()}: ${error}`);
      await route.abort();
    }
  });
}

// Wait for something on the page rather than for a while: true once it holds,
// false if it does not within `ms`.
const until = (fn, ms = 30000) =>
  tab.waitForFunction(fn, null, { timeout: ms }).then(() => true, () => false);

const failures = [];
const check = (ok, what) => {
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${what}`);
  if (!ok) {
    failures.push(what);
  }
};

try {
  await tab.goto(origin + '/');
  await tab.evaluate(() => window.ready);
  check(await tab.evaluate(() => crossOriginIsolated), 'the page is cross-origin isolated');

  const loaded = await tab.evaluate(async () => {
    const result = await window.webR.evalR('requireNamespace("maidr", quietly = TRUE)');
    return (await result.toJs()).values[0];
  });
  check(loaded === true, 'maidr installs from the repository and loads in webR');

  // The session's own `show()`, with nothing set up on the page for it.
  const message = await tab.evaluate(async () => {
    const shelter = await new window.webR.Shelter();
    const out = await shelter.captureR(`
      suppressPackageStartupMessages({ library(maidr); library(ggplot2) })
      three <- data.frame(x = c("a", "b", "c"), y = c(3, 5, 2))
      withCallingHandlers(
        show(ggplot(three, aes(x, y)) + geom_col()),
        message = function(m) { cat(conditionMessage(m)); invokeRestart("muffleMessage") }
      )
    `);
    const text = out.output
      .map(line => typeof line.data === 'string' ? line.data : JSON.stringify(line.data))
      .join('\\n');
    await shelter.purge();
    return text;
  });
  console.log(`     R said: ${JSON.stringify(message)}`);
  await until(() => {
    const frame = document.querySelector('#maidr-output > iframe');
    return frame && frame.contentDocument
      && frame.contentDocument.querySelectorAll('svg[maidr-data]').length === 1;
  });

  const framed = await tab.evaluate(() => {
    const frame = document.querySelector('#maidr-output > iframe');
    return {
      inside: Boolean(frame),
      charts: frame ? frame.contentDocument.querySelectorAll('svg[maidr-data]').length : 0,
    };
  });
  check(framed.inside, 'show() adds an iframe to #maidr-output');
  check(framed.charts === 1, 'the chart is drawn in the frame');

  if (framed.inside) {
    await tab.focus('#before');
    await tab.keyboard.press('Tab');
    check(
      await until(() => document.activeElement.tagName === 'IFRAME', 10000),
      'Tab from the button before reaches the chart',
    );
    const frame = tab.frames().find(f => f !== tab.mainFrame());
    // Tab puts the focus on the frame; maidr then takes it to the chart, and
    // the arrow keys are read only once it has.
    check(
      await frame.waitForFunction(
        () => document.activeElement && document.activeElement.getAttribute('role') === 'application',
        null,
        { timeout: 10000 },
      ).then(() => true, () => false),
      'maidr takes the focus into the chart',
    );
    await tab.keyboard.press('ArrowRight');
    const announcement = () => frame.evaluate(() =>
      Array.from(document.querySelectorAll('[aria-live], [role=status], [role=alert]'))
        .map(element => element.textContent.trim()).filter(Boolean).join(' | '));
    await frame.waitForFunction(
      () => Array.from(document.querySelectorAll('[aria-live], [role=status], [role=alert]'))
        .some(element => element.textContent.trim() !== ''),
      null,
      { timeout: 10000 },
    ).then(() => {}, () => {});
    const announced = await announcement();
    check(/x is a, y is 3/.test(announced), `Right Arrow announces a value (${announced})`);
    await tab.keyboard.press('Shift+Tab');
    check(
      await until(() => document.activeElement.id === 'before', 10000),
      'Shift+Tab returns to the button before',
    );
  }

  // A page that defines maidrWebRShow on the main thread gets the document.
  await tab.evaluate(() => {
    window.__received = 0;
    window.maidrWebRShow = html => { window.__received = html.length; };
  });
  const before = await tab.evaluate(() => document.querySelectorAll('iframe').length);
  await tab.evaluate(async () => {
    await window.webR.evalRVoid('show(ggplot(data.frame(x = "a", y = 1), aes(x, y)) + geom_col())');
  });
  check(await until(() => window.__received > 0, 10000), 'a page-defined maidrWebRShow receives the document');
  check(
    (await tab.evaluate(() => document.querySelectorAll('iframe').length)) === before,
    'and no frame is added',
  );
  check(errors.length === 0, `no page errors${errors.length ? ': ' + errors[0] : ''}`);
} catch (error) {
  failures.push(String(error));
  console.error(error);
} finally {
  await browser.close();
  server.close();
}

if (failures.length > 0) {
  console.error(`${failures.length} check(s) failed`);
  process.exit(1);
}
