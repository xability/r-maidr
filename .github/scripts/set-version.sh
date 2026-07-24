#!/usr/bin/env bash
# Write the version computed by semantic-release into DESCRIPTION.
#
# Invoked by the @semantic-release/exec prepare step (see .releaserc.json)
# so the Version field always matches the Git tag / GitHub release; the
# @semantic-release/git plugin then commits the updated DESCRIPTION back
# to main together with the regenerated NEWS.md.
set -euo pipefail

VERSION="${1:?usage: set-version.sh <version>}"

# R package versions must be plain x.y.z — reject semver prerelease/build
# suffixes (e.g. 1.0.0-rc.1) so a misconfigured release channel can never
# write a version that R CMD check would reject.
if ! [[ "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Refusing to write non x.y.z version '${VERSION}' to DESCRIPTION" >&2
  exit 1
fi

sed -i.bak "s/^Version: .*/Version: ${VERSION}/" DESCRIPTION
rm -f DESCRIPTION.bak

grep -q "^Version: ${VERSION}$" DESCRIPTION
echo "DESCRIPTION Version set to ${VERSION}"
