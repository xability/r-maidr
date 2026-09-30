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
await webR.installPackages(['maidr', 'testthat', 'withr'], {
  repos: [repo, 'https://repo.r-wasm.org/'],
  quiet: true,
});
await webR.FS.writeFile('/tmp/test-webr-support.R', new TextEncoder().encode(readFileSync(testFile, 'utf8')));

const result = await webR.evalR(`
  suppressPackageStartupMessages(library(testthat))
  res <- as.data.frame(test_file("/tmp/test-webr-support.R", reporter = "silent"))
  c(
    paste0("passed ", sum(res$passed), ", failed ", sum(res$failed),
           ", errors ", sum(res$error), ", skipped ", sum(res$skipped)),
    res$test[res$failed > 0 | res$error]
  )
`);
const [summary, ...bad] = (await result.toJs()).values;
console.log(summary);
for (const name of bad) {
  console.error(`FAIL ${name}`);
}
const passed = Number(/passed (\d+)/.exec(summary)[1]);

server.close();
await webR.close();
if (bad.length > 0 || passed === 0) {
  process.exit(1);
}
process.exit(0);
