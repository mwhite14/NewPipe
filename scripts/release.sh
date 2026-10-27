#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 <version>" >&2
    echo "Example: $0 0.29.1-fork.2" >&2
    exit 1
}

[[ $# -eq 1 ]] || usage

VERSION="${1#v}"
if [[ ! "$VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(-fork\.([0-9]+))?$ ]]; then
    echo "Version must look like 0.29.1 or 0.29.1-fork.1" >&2
    exit 1
fi

MAJOR=$((10#${BASH_REMATCH[1]}))
MINOR=$((10#${BASH_REMATCH[2]}))
PATCH=$((10#${BASH_REMATCH[3]}))
FORK_REVISION=$((10#${BASH_REMATCH[5]:-0}))
if (( MAJOR > 999 || MINOR > 99 || PATCH > 99 || FORK_REVISION > 99 )); then
    echo "Version components are too large for the version code scheme" >&2
    exit 1
fi
APP_VERSION="$MAJOR.$MINOR.$PATCH"
VERSION_CODE=$((MAJOR * 1000000 + MINOR * 10000 + PATCH * 100 + FORK_REVISION))
TAG="v$VERSION"
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

if [[ -n "$(git status --porcelain)" ]]; then
    echo "Working tree is not clean. Commit or stash changes first." >&2
    exit 1
fi

CURRENT_CODE="$(sed -n 's/^const val NEWPIPE_VERSION_CODE = \([0-9][0-9]*\)$/\1/p' \
    buildSrc/src/main/kotlin/ProjectConfig.kt)"
if [[ -z "$CURRENT_CODE" ]]; then
    echo "Could not read NEWPIPE_VERSION_CODE from ProjectConfig.kt" >&2
    exit 1
fi
if (( VERSION_CODE <= CURRENT_CODE )); then
    echo "Version code $VERSION_CODE must be greater than current $CURRENT_CODE" >&2
    exit 1
fi

git fetch origin --tags
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    echo "Tag $TAG already exists" >&2
    exit 1
fi

python3 - "$APP_VERSION" "$VERSION_CODE" <<'PY'
import re
import sys
from pathlib import Path

version, code = sys.argv[1], sys.argv[2]
path = Path("buildSrc/src/main/kotlin/ProjectConfig.kt")
text = path.read_text()
text, name_count = re.subn(
    r'^const val NEWPIPE_VERSION_NAME = ".*"$',
    f'const val NEWPIPE_VERSION_NAME = "{version}"',
    text,
    flags=re.MULTILINE,
)
text, code_count = re.subn(
    r'^const val NEWPIPE_VERSION_CODE = [0-9]+$',
    f'const val NEWPIPE_VERSION_CODE = {code}',
    text,
    flags=re.MULTILINE,
)
if name_count != 1 or code_count != 1:
    raise SystemExit("Could not update version constants")
path.write_text(text)
PY

BRANCH="$(git symbolic-ref --short HEAD)"
git add buildSrc/src/main/kotlin/ProjectConfig.kt
git commit -m "chore(release): $VERSION"
git tag -a "$TAG" -m "NewPipe $VERSION"
git push origin "$BRANCH"
git push origin "$TAG"

echo "Pushed $TAG. Release: https://github.com/mwhite14/NewPipe/releases/tag/$TAG"
