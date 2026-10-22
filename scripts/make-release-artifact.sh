#!/bin/bash
# Builds the release artifact for a git tag: ad-hoc signed app bundle packed
# into a tar.gz (tar carries no quarantine xattr, so Homebrew cask installs
# never trigger Gatekeeper — see ADR 0002 and the distribution spec).
#
# Usage: make-release-artifact.sh <git-tag>     e.g. v0.1.0 or v0.1.0-rc1
# Stdout: "artifact=<path>" and "sha256=<hash>" lines for CI to parse.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ $# -ne 1 ]; then
  echo "usage: $0 <git-tag>" >&2
  exit 1
fi

version="${1#v}"
if [[ ! "$version" =~ ^[A-Za-z0-9.+-]+$ ]]; then
  echo "error: '$1' is not a valid version tag" >&2
  exit 1
fi

ARTIFACT="build/ShiftHappens-v${version}-arm64.tar.gz"

KS_SIGN_IDENTITY=- KS_APP_VERSION="$version" ./scripts/make-app.sh

rm -f "$ARTIFACT"
tar --exclude '.DS_Store' -czf "$ARTIFACT" -C build ShiftHappens.app
HASH=$(shasum -a 256 "$ARTIFACT" | awk '{print $1}')

echo "artifact=$ARTIFACT"
echo "sha256=$HASH"
