## Submission

This is a small update of the CRAN package 'maidr', from 0.4.0 to 0.4.1.
The primary purpose of this release is to change the package maintainer.

## Maintainer change

This release changes the maintainer of the package from Niranjan
Kalaiselvan (nk46@illinois.edu) to JooYoung Seo (jseo1005@illinois.edu),
who is an existing co-author of the package. The outgoing maintainer
(Niranjan) has emailed CRAN-submissions@R-project.org confirming this
transfer in writing, per CRAN policy.

## Other changes

* Updated the bundled MAIDR JavaScript/CSS from v3.69.0 to v3.72.1.

## R CMD check results

Local: <platform, R version>, `R CMD check --as-cran`:

    0 errors | 0 warnings | 1 note

The single local NOTE ("checking HTML version of manual ... 'tidy' doesn't
look like recent enough HTML Tidy") reflects an outdated local HTML Tidy
tool and does not occur on CRAN's check infrastructure.

The win-builder CRAN-incoming-feasibility check flags one possibly
misspelled word in DESCRIPTION: "OHLC". This is a standard financial
abbreviation (Open-High-Low-Close) used to describe candlestick charts,
and is not a misspelling.

## Test environments

* local: <platform, R version>
* win-builder (R-devel and R-release): <add results before submitting>
* mac-builder (R-release): <add results before submitting>

## Downstream dependencies

There are no reverse dependencies for this package.
