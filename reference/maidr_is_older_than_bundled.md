# Is a resolved version older than the bundled one?

Semantic version precedence, as py-maidr's `_is_older_than_bundled`
applies it: MAJOR.MINOR.PATCH compared numerically with
[`numeric_version()`](https://rdrr.io/r/base/numeric_version.html); on a
tie, a pre-release sorts below the release it precedes (`4.9.0-rc.1` \<
`4.9.0`), and two pre-releases compare identifier by identifier, numeric
ones numerically and below alphanumeric ones, alphanumeric ones in ASCII
order, a shorter run below a longer one it begins. Build metadata
(`+build.5`) carries no precedence and is ignored.

## Usage

``` r
maidr_is_older_than_bundled(resolved, bundled = MAIDR_VERSION)
```

## Arguments

- resolved:

  The version the resolver answered with

- bundled:

  The version bundled with this package

## Value

`TRUE` when `resolved` sorts below `bundled`

## Details

A version that cannot be compared is not called older: the resolver's
answer, already checked to be a semantic version, stays in place.
