# Is a manifest's file path one that stays put?

Each path is joined onto the download directory to decide where a
fetched file is written, so a manifest could otherwise name `../../..`
and write wherever it liked. Nothing user-authored reaches this today –
the manifest is committed and only a maintainer regenerates it – but the
download is the one place this package writes files it did not name, and
a check costs nothing.

## Usage

``` r
maidr_dotpad_path_is_safe(path)
```

## Arguments

- path:

  One key of the manifest's `files`.

## Value

`TRUE` when the path is relative and stays inside its directory.
