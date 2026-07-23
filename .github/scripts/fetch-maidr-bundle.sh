#!/usr/bin/env bash
#
# Resolve, download, verify, and install the bundled ``maidr.js`` /
# ``maidr.css`` assets. Shared by the scheduled refresh workflow
# (``update-maidr-bundle.yml``) and the local maintainer tool
# (``tools/update-maidr-assets.R``) so the download + integrity-check +
# install logic lives in exactly one place and cannot drift between the two.
#
# The assets are extracted from the official npm tarball, whose contents are
# verified against the ``dist.integrity`` (SRI) / ``dist.shasum`` hash
# published in the npm registry metadata. This gives a real supply-chain
# guarantee: a tampered CDN/registry response fails the hash check instead of
# being written into the bundle (and, at CRAN submission time, shipped in the
# package).
#
# On success the script installs the assets into
# ``inst/htmlwidgets/lib/maidr-<VERSION>/``, removes any stale
# ``maidr-*`` lib directories, and rewrites the version references in
# ``R/html_dependencies.R`` and ``inst/htmlwidgets/maidr.yaml`` so the
# package always points at the freshly installed bundle.
#
# Usage (from the package root):
#   .github/scripts/fetch-maidr-bundle.sh [VERSION]
#
#   VERSION   maidr npm version to fetch. Resolves the latest published
#             version on npm when empty or omitted.
#
# The resolved version is printed as the final line of stdout so callers can
# capture it, e.g. ``VERSION=$(.github/scripts/fetch-maidr-bundle.sh)``. All
# progress output goes to stderr to keep stdout limited to the version string.
set -euo pipefail

VERSION="${1:-}"

REGISTRY="https://registry.npmjs.org/maidr"
LIB_ROOT="inst/htmlwidgets/lib"
R_VERSION_FILE="R/html_dependencies.R"
YAML_FILE="inst/htmlwidgets/maidr.yaml"

# Fail fast with a clear message when not run from the package root, rather
# than half-updating whatever directory we happen to be in.
if [ ! -f DESCRIPTION ] || [ ! -d "$LIB_ROOT" ]; then
  echo "Run this script from the r-maidr package root" >&2
  exit 1
fi

if [ -z "$VERSION" ]; then
  VERSION=$(curl -sSfL "$REGISTRY/latest" | jq -r '.version')
fi
if [ -z "$VERSION" ] || [ "$VERSION" = "null" ]; then
  echo "Failed to resolve maidr.js version" >&2
  exit 1
fi

# Validate the version shape before splicing it into any URL or file path.
# This rejects malformed or hostile values (e.g. a caller-supplied version)
# so they cannot build an unintended request path or escape the lib dir.
if ! printf '%s' "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+([-+.][0-9A-Za-z.-]+)*$'; then
  echo "Refusing to fetch: '$VERSION' is not a valid maidr version" >&2
  exit 1
fi

DEST_DIR="$LIB_ROOT/maidr-$VERSION"
echo "Fetching bundled maidr.js v${VERSION} into ${DEST_DIR}" >&2

# Fetch the registry metadata for this exact version to get the tarball URL
# and its published integrity hash.
META=$(curl -sSfL "$REGISTRY/$VERSION")
TARBALL=$(printf '%s' "$META" | jq -r '.dist.tarball // empty')
INTEGRITY=$(printf '%s' "$META" | jq -r '.dist.integrity // empty')
SHASUM=$(printf '%s' "$META" | jq -r '.dist.shasum // empty')
if [ -z "$TARBALL" ]; then
  echo "Failed to resolve npm tarball URL for maidr@$VERSION" >&2
  exit 1
fi

WORK=$(mktemp -d)
# shellcheck disable=SC2064  # expand WORK now so the trap removes this dir
trap "rm -rf '$WORK'" EXIT
TGZ="$WORK/maidr.tgz"
curl -sSfL -o "$TGZ" "$TARBALL"

# Verify the tarball against the registry-published hash. Prefer the SRI
# ``integrity`` field (sha512); fall back to the legacy ``shasum`` (sha1).
if [ -n "$INTEGRITY" ]; then
  ALGO=${INTEGRITY%%-*}
  EXPECTED=${INTEGRITY#*-}
  ACTUAL=$(openssl dgst "-${ALGO}" -binary "$TGZ" | openssl base64 -A)
  if [ "$ACTUAL" != "$EXPECTED" ]; then
    echo "Integrity check failed for maidr@$VERSION tarball ($ALGO)" >&2
    exit 1
  fi
  echo "Verified tarball ${ALGO} integrity" >&2
elif [ -n "$SHASUM" ]; then
  # openssl rather than sha1sum: the latter is GNU coreutils and absent on
  # stock macOS, and openssl is already required for the SRI path above.
  ACTUAL=$(openssl dgst -sha1 "$TGZ" | awk '{print $NF}')
  if [ "$ACTUAL" != "$SHASUM" ]; then
    echo "Shasum check failed for maidr@$VERSION tarball" >&2
    exit 1
  fi
  echo "Verified tarball shasum" >&2
else
  echo "No integrity/shasum in registry metadata for maidr@$VERSION" >&2
  exit 1
fi

# Extract the bundled assets from the verified tarball. npm tarballs place
# published files under ``package/``.
tar -xzf "$TGZ" -C "$WORK" package/dist/maidr.js package/dist/maidr.css

# Defense-in-depth sanity checks on the extracted payloads before touching
# the package tree: non-empty, and not an HTML error page masquerading as
# JS / CSS. The check is a positive match: fail when the payload *starts*
# with an HTML marker.
for asset in maidr.js maidr.css; do
  test -s "$WORK/package/dist/${asset}"
  if head -c 128 "$WORK/package/dist/${asset}" | grep -qiE "^[[:space:]]*<!DOCTYPE|^[[:space:]]*<html"; then
    echo "${asset} looks like an HTML error page" >&2
    exit 1
  fi
done

# Install into the versioned lib directory and drop any stale bundles so a
# version bump cannot leave two maidr-* dirs behind.
mkdir -p "$DEST_DIR"
cp "$WORK/package/dist/maidr.js" "$DEST_DIR/maidr.js"
cp "$WORK/package/dist/maidr.css" "$DEST_DIR/maidr.css"
for dir in "$LIB_ROOT"/maidr-*/; do
  [ -d "$dir" ] || continue
  if [ "${dir%/}" != "$DEST_DIR" ]; then
    echo "Removing stale bundle dir ${dir%/}" >&2
    rm -rf "$dir"
  fi
done

# Point the package at the installed bundle: MAIDR_VERSION in the R source
# and the version/src entries in the htmlwidgets dependency manifest.
sed -i.bak -E "s/MAIDR_VERSION <- \"[^\"]*\"/MAIDR_VERSION <- \"$VERSION\"/" "$R_VERSION_FILE"
sed -i.bak -E "s/^([[:space:]]*version:).*/\1 $VERSION/" "$YAML_FILE"
sed -i.bak -E "s|^([[:space:]]*src:) htmlwidgets/lib/maidr-.*|\1 htmlwidgets/lib/maidr-$VERSION|" "$YAML_FILE"
rm -f "$R_VERSION_FILE.bak" "$YAML_FILE.bak"

# The rewrites above are pattern-based; verify they actually landed so a
# drifted source file fails loudly instead of shipping a version mismatch.
grep -qF "MAIDR_VERSION <- \"$VERSION\"" "$R_VERSION_FILE"
grep -qF "version: $VERSION" "$YAML_FILE"
grep -qF "src: htmlwidgets/lib/maidr-$VERSION" "$YAML_FILE"

echo "$VERSION"
