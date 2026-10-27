# Releasing this fork

Releases are built by GitHub Actions from annotated `v*` tags and attached to a
GitHub release.

## Create a release

Run the release script from a clean checkout:

```bash
./scripts/release.sh 0.29.1-fork.2
```

The script:

1. Converts the version to a monotonically increasing Android version code.
2. Updates `buildSrc/src/main/kotlin/ProjectConfig.kt`.
3. Commits the version bump and creates an annotated tag.
4. Pushes the current branch and the tag.

The tag push triggers `.github/workflows/release-apk.yml`. The workflow runs the
unit tests, builds and signs the release APK, writes a SHA-256 checksum, and
creates the GitHub release with both files attached.

Release tags use upstream NewPipe's numeric version plus a fork revision, for
example `v0.29.1-fork.1`. The Android `versionName` stays numeric (`0.29.1`)
because the desktop Compose packaging rejects suffixes. The release tag, release
title, APK filename, and Android `versionCode` all carry the fork revision.

Increase the fork revision for fork-only changes; move to the new upstream
version when rebasing.

## Signing

The workflow reads the signing key from repository secrets:

- `RELEASE_KEYSTORE_BASE64`
- `RELEASE_KEYSTORE_PASSWORD`
- `RELEASE_KEY_ALIAS`
- `RELEASE_KEY_PASSWORD`

Keep the signing key stable. Android only installs an update in place when the
signing certificate matches.

## Publish to the private app store

The App Store only scans private repositories. This NewPipe repository is a
public fork, so store artifacts are mirrored to the private
`mwhite14/newpipe-store` repository, which holds `index.json` and the store
release. The source code stays public; the APK and manifest stay private.

After a GitHub release is published, copy the APK under the store's expected
base-version filename and run the store publisher from the artifact repo:

```bash
TAG=v0.29.1-fork.1
TMPDIR="$(mktemp -d)"
gh release download "$TAG" --repo mwhite14/NewPipe --pattern '*.apk' --dir "$TMPDIR"
cp "$TMPDIR"/*.apk "$TMPDIR/NewPipe-0.29.1.apk"

cd ~/repo/newpipe-store
git pull --ff-only
~/repo/android_appstore/scripts/publish.sh \
  --apk "$TMPDIR/NewPipe-0.29.1.apk" \
  --description "YouTube frontend with members-only videos hidden by default." \
  --changelog "What changed in this release" \
  --push
```

The APK filename passed to `publish.sh` must be `NewPipe-<app version>.apk`,
where the app version is the numeric `versionName` from `ProjectConfig.kt`.
The store script uses that filename for the release asset, so a fork-suffixed
filename fails its asset lookup.

## Weekly upstream security check

`.github/workflows/upstream-security.yml` runs every Monday at 14:00 UTC
(08:00 in Denver during daylight saving time). It checks the upstream
`TeamNewPipe/NewPipe` `dev` branch for commits, security advisories, and release
notes related to security since this fork's merge base.

If it finds anything, it opens or updates one issue named
`Upstream security watch` with links and a suggested merge action. When the
findings are gone, it closes that issue. The check is a heuristic: a security
fix with no security wording in its commit message or release notes can be
missed.

Run it manually with:

```bash
gh workflow run upstream-security.yml -R mwhite14/NewPipe
```

Preview the report locally without touching issues:

```bash
./scripts/check-upstream-security.sh --dry-run
```
