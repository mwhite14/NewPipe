# NewPipe fork — agent rules

Local rules that sit on top of the global `~/.dsh/AGENTS.md`. `RELEASING.md` is the
authoritative release reference; this file records standing decisions.

## Always publish to the private store

Every feature, fix, or other change that ships to the phone ends with a release published
to the private app store. Do not stop at a local build. This applies to every session.

1. Work on a feature branch and commit there. Never commit to `dev` or `main` directly.
2. Merge the feature into `dev` (the integration branch) once it is verified.
3. Run `./scripts/release.sh 0.29.1-fork.<n+1>`. It bumps `NEWPIPE_VERSION_CODE` in
   `buildSrc/src/main/kotlin/ProjectConfig.kt`, commits, tags `v<version>`, and pushes the
   branch and tag. The tag push makes `.github/workflows/release-apk.yml` build and sign the
   APK with the `RELEASE_*` repository secrets and create the GitHub release.
4. Wait for the workflow to finish and confirm the release asset exists.
5. Download the release asset (it is already named `NewPipe-<fork version>.apk`, which is what
   `publish.sh` expects) and run it from `~/repo/newpipe-store`:
   `~/repo/android_appstore/scripts/publish.sh --apk <apk> --changelog "..." --push`.
6. Report the new `versionCode` so the phone can pick it up.

Publishing changes shared state (push, tag, release, store commit). Confirm with Michael
before the push step when the request did not already ask for a publish in this turn; once
he says "publish", carry the whole sequence through without asking again.

## Version numbers

`NEWPIPE_VERSION_NAME` stays numeric (`0.29.1`): the desktop Compose packaging rejects a
suffix. The fork revision is carried by the tag and by `NEWPIPE_VERSION_CODE`
(`0.29.1-fork.2` becomes `290102`); `scripts/release.sh` handles both.

## Build types and the application id

The store APK must keep the application id `org.schabi.newpipe` with no suffix, so every
release installs in place. Do not flip the fork's custom build types to default:
`debug` stays debug-signed with `<id>.debug`, and `continuous` is only for branch previews
(`<id>.debug.<branch>`, Android's 50-character application id limit). Store releases always
come from the `release` build produced by the tag workflow.

## Signing

The release keystore exists only as GitHub repository secrets (`RELEASE_KEYSTORE_BASE64`,
`RELEASE_KEYSTORE_PASSWORD`, `RELEASE_KEY_ALIAS`, `RELEASE_KEY_PASSWORD`). A local build is
debug-signed and will not update the installed release in place. Do not publish a locally
built APK unless Michael explicitly accepts the uninstall-first requirement. Branch preview
builds install alongside the store app because of their suffix.

## Build environment (sandbox-safe)

```bash
export JAVA_HOME=~/repo/.cache/android-tools/jdk-21/Contents/Home
export HOME=~/repo/.cache/android-home
export ANDROID_USER_HOME=~/repo/.cache/android-home/.android
export GRADLE_USER_HOME=~/repo/.cache/gradle
./gradlew --offline :app:testDebugUnitTest :app:assembleDebug
```

JDK 17 fails with a toolchain error: the app requires Java 21 to compile. Checkstyle runs as
part of the build; fix violations rather than suppressing them.
