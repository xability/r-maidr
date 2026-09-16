# The DotPad SDK maidr.js is pinned to

maidr.js loads the SDK from the vendor's repository at one commit, and
this is that commit, with the size and digests of every file a copy
consists of. It mirrors `src/service/dotPadSdk.json` in the maidr
repository, which is where maidr.js reads its own copy of the pin; keep
the two in step when either moves.

## Usage

``` r
maidr_dotpad_sdk_manifest()
```

## Value

A list: `version`, `repository`, `commit`, `base_url`, `module`,
`asset_dir`, and `files`, a data frame with one row per file (`path`,
`bytes`, `md5`, `sha256`).

## Details

The two are not in step at the moment, deliberately. The maidr.js this
package bundles (see `MAIDR_VERSION`) predates the pin and still falls
back to the earlier commits – the vendor's for the module and a fork's
for the braille engine – when nothing on the page names a copy. That
fallback is exactly what a downloaded copy or a configured URL replaces,
so what a document loads is this commit either way; the bundle catches
up at its next refresh (`tools/update-maidr-assets.R`).

The commit matters beyond immutability. Earlier ones carry a corrupt
`liblouis.data`: the repository's `.gitattributes` said `* text=auto`
and the file is braille-table text with no NUL byte in it, so git
rewrote its line endings on commit. It is an Emscripten package
addressed by absolute byte offsets, so every table after the first
dropped byte was read from the wrong place and the braille line silently
fell back to grade 1. This commit marks `*.data binary` and restores the
bytes.

The liblouis build is LGPL-2.1-or-later. Its licence text and the
sources of the WebAssembly wrapper are listed because the vendor's
README asks anyone who redistributes the SDK to keep them beside the
runtime files, which is the LGPL's relinking requirement.
