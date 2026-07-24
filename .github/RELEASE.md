# Release process

r-maidr uses [semantic-release](https://github.com/semantic-release/semantic-release)
to automate version bumps, `NEWS.md` generation, Git tags, and GitHub
releases — the same commit-driven model as the sibling repositories
[py-maidr](https://github.com/xability/py-maidr) (python-semantic-release)
and [maidr](https://github.com/xability/maidr) (semantic-release), adapted
to R package conventions.

## How it works

Every push to `main` runs `.github/workflows/release.yml`:

1. **R-CMD-check (release gate)** — a release is only cut when the package
   checks cleanly on ubuntu / R release.
2. **commit-lint** — the pushed commit must follow
   [conventional commits](https://www.conventionalcommits.org/)
   (config: `.commitlintrc.cjs`, mirroring py-maidr).
3. **Semantic Release** — analyzes all commits since the last `v*` tag:

   | Commit | Effect |
   |---|---|
   | `feat: ...` | minor bump (`0.4.0` → `0.5.0`) |
   | `fix: ...`, `perf: ...` | patch bump (`0.4.0` → `0.4.1`) |
   | `feat!: ...` or `BREAKING CHANGE:` footer | major bump (`0.4.0` → `1.0.0`) |
   | `docs:`, `chore:`, `ci:`, `refactor:`, `style:`, `test:`, `build:` | no release |

   When a release is due, semantic-release (config: `.releaserc.json`):

   - prepends a new section to `NEWS.md`, using R-style `# maidr X.Y.Z`
     headings so pkgdown and `utils::news()` keep parsing it. Visible
     changelog sections are **New Features** (`feat`), **Bug Fixes**
     (`fix`), **Performance Improvements** (`perf`), and
     **Documentation** (`docs`); maintenance commit types are excluded to
     keep the CRAN-facing NEWS readable,
   - rewrites `Version:` in `DESCRIPTION` via
     `.github/scripts/set-version.sh` (which rejects anything that is not
     a plain `x.y.z`, since R does not accept semver prerelease suffixes),
   - commits `DESCRIPTION` + `NEWS.md` back to `main` as
     `chore(release): X.Y.Z [skip ci]`,
   - tags `vX.Y.Z` and publishes a GitHub release with the same notes.

Pushes made with the workflow's `GITHUB_TOKEN` do not re-trigger
workflows, so the release commit cannot start a release loop; the
`[skip ci]` marker is belt-and-suspenders for tokens that do.

## One-time bootstrap

semantic-release derives the current version from Git tags, and this
repository historically had none. Before the first automated release, a
maintainer must seed a baseline tag matching the `Version:` already in
`DESCRIPTION`, placed on the commit that introduced that version:

```sh
git tag v0.4.0 <commit-sha>
git push origin v0.4.0
```

The release job fails with an explicit error until this tag exists —
otherwise semantic-release would treat the next release as the first ever
and publish 1.0.0.

## CRAN releases stay manual

CRAN has no submission API, so this pipeline intentionally stops at the
GitHub release. After any automated release, `main` carries a
submission-ready `Version` and `NEWS.md`; when a CRAN release is wanted,
build and submit from `main` as before (`R CMD build`, update
`cran-comments.md`, submit, confirm). The daily
`update-maidr-bundle.yml` refresh keeps the bundled maidr.js on `main`
current, so whatever is on `main` at submission time is what ships.

## Differences from the sibling repos

- **Changelog file** is `NEWS.md` (R convention), not `CHANGELOG.md`.
- **Changelog contents are curated**: py-maidr includes every commit type
  in its changelog; r-maidr hides maintenance types because `NEWS.md`
  ships to CRAN users.
- **No `major_on_zero=false`**: python-semantic-release keeps py-maidr on
  0.x even for breaking changes; node semantic-release follows semver
  strictly, so a breaking-change commit here moves r-maidr to 1.0.0.
  Avoid `!`/`BREAKING CHANGE` until 1.0.0 is intended.
- **Trigger** is push-to-main (like py-maidr), not weekly cron (like
  maidr).
