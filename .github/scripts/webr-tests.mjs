#!/usr/bin/env node
// Run the tests of the webR display path in webR itself.
//
// Natively, `test-webr-support.R` has to skip what needs webR and fake the
// rest. Here maidr is installed from the repository built for webR, in webR
// under node, and the file runs there: the tests that skip natively run, and
// the ones that mock `is_webr()` run against the real thing.
//
//     node .github/scripts/webr-tests.mjs <webr-repo-dir>
//
// Needs the `webr` package. webR fetches testthat and the other packages it
// needs from repo.r-wasm.org.

import { WebR } from 'webr';
import { createServer } from 'node:http';
import { createReadStream, existsSync, readFileSync, statSync } from 'node:fs';
import path from 'node:path';

const repoDir = process.argv[2];
if (!repoDir || !existsSync(repoDir)) {
  console.error('usage: webr-tests.mjs <webr-repo-dir>');
  process.exit(2);
}
const root = path.resolve(repoDir);
const testFile = new URL('../../tests/testthat/test-webr-support.R', import.meta.url);

const server = createServer((req, res) => {
  const file = path.join(root, path.normalize(new URL(req.url, 'http://localhost').pathname));
  const inside = path.relative(root, file);
  if (inside.startsWith('..') || path.isAbsolute(inside)
    || !existsSync(file) || !statSync(file).isFile()) {
    res.writeHead(404).end();
    return;
  }
  res.writeHead(200);
  createReadStream(file).pipe(res);
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const repo = `http://127.0.0.1:${server.address().port}/`;

const webR = new WebR();
await webR.init();
// The widget packages are what the widget tests draw with; without them those tests would skip.
await webR.installPackages(['maidr', 'testthat', 'withr', 'plotly', 'highcharter', 'echarts4r'], {
  repos: [repo, 'https://repo.r-wasm.org/'],
  quiet: true,
});
await webR.FS.writeFile('/tmp/test-webr-support.R', new TextEncoder().encode(readFileSync(testFile, 'utf8')));

const result = await webR.evalR(`
  suppressPackageStartupMessages(library(testthat))
  res <- test_file("/tmp/test-webr-support.R", reporter = "silent")
  frame <- as.data.frame(res)
  skips <- unlist(lapply(res, function(test) {
    vapply(
      Filter(function(x) inherits(x, "expectation_skip"), test$results),
      conditionMessage, character(1)
    )
  }))
  failing <- frame$test[frame$failed > 0 | frame$error]
  c(
    paste0("passed ", sum(frame$passed), ", failed ", sum(frame$failed),
           ", errors ", sum(frame$error), ", skipped ", sum(frame$skipped)),
    if (length(failing)) paste0("FAIL ", failing),
    if (length(skips)) paste0("SKIPPED ", skips)
  )
`);
const lines = (await result.toJs()).values;
const summary = lines[0];
console.log(summary);

// What may skip in webR: the tests about a native build, and the one that
// needs node. A test that skips for any other reason is one the job was
// meant to run.
const expected = /emscripten|node is not installed/;
const bad = lines.filter(line => line.startsWith('FAIL '));
const unexpected = lines.filter(line => line.startsWith('SKIPPED ') && !expected.test(line));
for (const line of bad) {
  console.error(line);
}
for (const line of unexpected) {
  console.error(`unexpected skip: ${line.slice('SKIPPED '.length)}`);
}
const passed = Number(/passed (\d+)/.exec(summary)[1]);
await webR.close();

// A session that loaded systemfonts before maidr (#388). systemfonts' libxml2
// then answers for xml2's too, and parsing a chart's SVG with xml2 aborts the
// wasm: R's worker dies and the call never returns. show() and save_html()
// must not need xml2 there. A fresh webR, since load order is per session.
const loadOrder = await (async () => {
  const fresh = new WebR();
  await fresh.init();
  await fresh.installPackages(['maidr'], { repos: [repo, 'https://repo.r-wasm.org/'], quiet: true });
  const run = (async () => {
    const shelter = await new fresh.Shelter();
    const out = await shelter.captureR(`
      loadNamespace("systemfonts")
      xml2_first <- isNamespaceLoaded("xml2")
      suppressWarnings(suppressPackageStartupMessages({ library(maidr); library(ggplot2) }))
      shown <- NULL
      options(maidr.webr_display = function(html) shown <<- html)
      show(ggplot(data.frame(x = c("a", "b"), y = c(1, 2)), aes(x, y)) + geom_col())
      file <- tempfile(fileext = ".html")
      save_html(ggplot(data.frame(x = "a", y = 1), aes(x, y)) + geom_col(), file)
      cat(
        "systemfonts first:", !xml2_first,
        "| shown:", grepl("maidr-data=", shown, fixed = TRUE),
        "| saved:", any(grepl("maidr-data=", readLines(file), fixed = TRUE)), "\\n"
      )
    `);
    return out.output.map(line => (typeof line.data === 'string' ? line.data : '')).join('');
  })();
  let timer;
  const expired = new Promise(resolve => {
    timer = setTimeout(() => resolve('no answer from webR within 300s'), 300000);
  });
  const said = await Promise.race([run.catch(error => `webR failed: ${error}`), expired]);
  clearTimeout(timer);
  fresh.close();
  return said;
})();
const loadOrderOk = /systemfonts first: TRUE \| shown: TRUE \| saved: TRUE/.test(loadOrder);
console.log(`${loadOrderOk ? 'ok  ' : 'FAIL'} show() and save_html() with systemfonts loaded first: ${loadOrder.trim()}`);

server.close();
if (bad.length > 0 || unexpected.length > 0 || passed === 0 || !loadOrderOk) {
  process.exit(1);
}
process.exit(0);
