# Releasing maidr to CRAN

The steps of a CRAN release, for a maintainer or an agent working on the
maintainer's machine. CRAN has no submission API, and every submission
must be confirmed by the maintainer from an emailed link, so releases are
not automated; this list is what makes them quick. Each step says what
went wrong before, so it does not go wrong again.

## Before you start

- **Cadence.** CRAN asks for updates "no more than every 1–2 months" once
  a package is established. The date of the release on CRAN is `Published`
  in `tools::CRAN_package_db()`, or on <https://cran.r-project.org/package=maidr>.
- **The check page is clean.** Every flavour on
  <https://cran.r-project.org/web/checks/check_results_maidr.html> should
  say OK, for the version on CRAN, with no additional issues. The
  confirmation page asks the maintainer to affirm that every problem there
  is fixed.
- **Something changed for users.** `git log --oneline vX.Y.Z..main` (the
  last tag) should show a `feat`, `fix` or `perf` commit, or a bundle
  refresh (`chore: update MAIDR bundle to ...`).

## 1. Choose the version

Any `feat` since the last tag raises the minor version; otherwise the
patch version goes up. A breaking change counts as `feat` below 1.0.0. A
resubmission after a rejection gets a new version as well: CRAN's policy
says increasing it "is preferred even when a previous submission was not
accepted".

## 2. Prepare the release pull request

On a branch `chore/release-X.Y.Z`:

- `DESCRIPTION`: `Version: X.Y.Z` (from the development version
  `X.Y.Z.9000` of the previous release).
- `NEWS.md`: rename `# maidr (development version)` to `# maidr X.Y.Z`.
  Pull requests write their own entries, but the automated bundle refreshes
  do not: when `inst/htmlwidgets/lib/maidr-*/` changed since the last tag,
  add `* Bundled MAIDR.js updated from A to B.` under `## Enhancements`.
- `cran-comments.md`: the check results from step 3, and anything CRAN
  will want explained (a NOTE, a maintainer change, a resubmission and
  what changed since).
- Commit as `chore(release): maidr X.Y.Z`.

## 3. Check

Run the r-devel workflow on the branch:

```sh
gh workflow run r-devel-check.yaml --ref chore/release-X.Y.Z
```

It runs `R CMD check --as-cran` with r-devel on Windows and Linux, set up
like CRAN's incoming checks, with the tests run as on CRAN. Its summary
shows the status, what each non-OK check said, and the test time. Aim for
0 errors | 0 warnings | 0 notes, and tests under 300 s on Windows (the
0.5.0 pretest took 266 s there). CRAN allows the whole check about ten
minutes: 0.5.0 was archived once for a 16-minute check, 13 of them in the
tests. If the tests have grown, call `skip_slow_file_on_cran()` at the top
of the slowest files (`tests/testthat/helper.R`, #340).

The workflow exists because the alternatives failed for 0.5.0:
win-builder's R-devel queue answers by email and sent nothing, twice; and
the R-devel installer can be blocked on a managed Windows machine.
Optional extra checks whose results do not depend on email:

- mac-builder: `curl -H "Accept: application/json" -F pkgfile=@maidr_X.Y.Z.tar.gz -F rflavor=r-release https://mac.r-project.org/macbuilder/v1/submit`
  returns the URL of the results.
- win-builder R-release: `curl -T maidr_X.Y.Z.tar.gz ftp://win-builder.r-project.org/R-release/`
  runs on the machines CRAN's Windows pretest uses; the result comes by
  email.

A local `R CMD check --as-cran` on Windows works, but endpoint scanning
made its tests about 1.8 times slower than win-builder's, so do not judge
the time budget from it.

## 4. Merge and submit

1. Merge the release pull request, then build from `main`:
   `R CMD build .` (vignettes need pandoc).
2. Upload with `devtools::submit_cran()`, or without its prompts with
   `devtools:::upload_cran(".", "maidr_X.Y.Z.tar.gz")` followed by
   `devtools:::flag_release(devtools::as.package("."))`, which writes
   `CRAN-SUBMISSION` (gitignored) with the commit's SHA.
3. CRAN emails the maintainer from `root-xmpalantir@xmbombadil.wu.ac.at`:
   "CRAN Submission of maidr X.Y.Z - Confirmation Link". It has arrived ten
   seconds after the upload, and more than three hours after. The link
   opens a page that asks the maintainer to affirm three statements (the
   CRAN policies are read; the package was checked with `--as-cran` on a
   current r-devel; every problem on the check page is fixed) before
   "Upload the Package to CRAN". Affirm them only when they are true. If
   two links arrive, after a second upload, use one.
4. Start the next development version at once, so that pull requests
   merged meanwhile put their NEWS entries under the right heading:
   `Version: X.Y.Z.9000` and a new `# maidr (development version)` at the
   top of `NEWS.md`, as #342 did.

## 5. Follow the submission

Watch the queues rather than waiting for email:

- <https://cran.r-project.org/incoming/> and its folders (`pretest/`,
  `waiting/`, `pending/`, `inspect/`, `newbies/`, `publish/`, `archive/`).
  An upload appears there only once the confirmation link is accepted.
- <https://win-builder.r-project.org/incoming_pretest/>, where a folder
  `maidr_X.Y.Z_<timestamp>/` appears with the Windows and Debian logs of
  the pretest.

The tag in the pretest email's subject says what follows.
`[CRAN-pretest-archived]` means rejected: fix the problem and resubmit
with a new version, or reply-all if the problem is a false positive.
`[CRAN-pretest-waiting]` means CRAN waits for something, such as a
confirmation from the previous maintainer's address when the maintainer
changes. These emails set `Reply-To: CRAN-submissions@R-project.org`;
keep that address on every reply.

## 6. After CRAN publishes

1. Tag the submitted commit, the SHA in `CRAN-SUBMISSION`:
   `git tag -a vX.Y.Z <sha> -m "maidr X.Y.Z"` and
   `git push origin vX.Y.Z`.
2. Release on GitHub with that version's NEWS section as the notes. NEWS is
   hard-wrapped, and GitHub shows every line break, so unwrap it:

   ```sh
   git show vX.Y.Z:NEWS.md | awk 'NR == 1 && /^# maidr/ {next} /^# maidr / {exit} {print}' > notes.md
   printf '\n**Now on CRAN:** `install.packages("maidr")`\n' >> notes.md
   pandoc -f gfm -t gfm --wrap=none notes.md -o notes-unwrapped.md
   gh release create vX.Y.Z --verify-tag --title "maidr X.Y.Z" --notes-file notes-unwrapped.md --latest
   ```

   Publishing the release deploys the pkgdown site. A release made with a
   workflow's `GITHUB_TOKEN` starts no workflow; then run
   `gh workflow run pkgdown.yaml --ref vX.Y.Z`.
3. Delete `CRAN-SUBMISSION`.

## Also worth knowing

- `r-lib/actions/setup-r` exports `NOT_CRAN=true`, so every CI job runs
  the whole test suite. CRAN-mode test times come only from
  `r-devel-check.yaml`, win-builder, or a local run with `NOT_CRAN` unset.
- The minimal TinyTeX on GitHub runners lacks `courier` and `makeindex`;
  without them the PDF manual check fails. `r-devel-check.yaml` installs
  them.
- A maintainer change needs the previous maintainer to confirm it in
  writing to CRAN-submissions@R-project.org, as Niranjan Kalaiselvan did
  for 0.5.0 on 2026-07-11.
