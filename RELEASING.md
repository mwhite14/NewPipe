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
