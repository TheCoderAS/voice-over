# Voice Over

An Android app for voice editing and voice changing, built with Flutter.

This repository currently contains the project scaffold and CI/release pipeline
only — feature work comes next.

## Project facts

| | |
|---|---|
| Platform | Android only |
| Flutter | 3.44.9 (stable) |
| Dart | 3.12.2 |
| Application ID | `com.unisync.voiceover` |
| Min Android version | 7.0 (API 24) |
| Target / compile SDK | 36 |
| Toolchain | AGP 9.0.1, Gradle 9.1, Kotlin 2.3.20, JDK 21 |

`minSdk` is pinned to 24 because the audio recording and effects plugins in this
space generally require it.

## Getting an installable APK

Every push to `main` publishes a **GitHub Release** with an APK attached — grab
the latest from the [Releases page](../../releases), copy it to an Android
device, and install it. You will likely need to allow "install from unknown
sources" for your browser or file manager.

For a build from a branch or pull request, open the CI run under
[Actions](../../actions) and download the `voice-over-apk` artifact (a zip
containing the APK). Artifacts are kept for 30 days.

> **Signing:** release builds are signed with a fixed **testing keystore**
> committed at `android/keystore/voiceover-testing.jks`. Because every build —
> local and CI — uses the same key, all APKs share one signature and **updates
> install over previous builds without an uninstall**. It is a testing key, not
> the Play upload key; its password is intentionally non-secret.
>
> To sign with a real upload key later, provide these as environment variables
> (e.g. repository secrets wired into the build step) — they override the
> testing key with no code change:
>
> | Variable | Meaning |
> |---|---|
> | `VOICEOVER_STORE_FILE` | path to the keystore |
> | `VOICEOVER_STORE_PASSWORD` | keystore password |
> | `VOICEOVER_KEY_ALIAS` | key alias |
> | `VOICEOVER_KEY_PASSWORD` | key password |
>
> Switching keys changes the signature, so the first install after a key change
> needs a one-time uninstall.

## Local development

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install) and the
Android SDK.

```bash
flutter pub get
flutter run                 # debug build on a connected device or emulator
flutter build apk --release # release APK -> build/app/outputs/flutter-apk/
```

Before pushing, run what CI runs:

```bash
dart format .
flutter analyze
flutter test
```

## CI

`.github/workflows/ci.yml` runs on every pull request, every push to `main`, and
on demand via *Run workflow*.

1. **Analyze & test** — `dart format --set-exit-if-changed`, `flutter analyze`,
   `flutter test`.
2. **Build release APK** — produces
   `voice-over-<version>-<run-number>.apk` and uploads it as a workflow
   artifact. The version name comes from `pubspec.yaml`; the build number (and
   therefore `versionCode`) is the CI run number, so it always increases.
3. **Publish release** — `main` only. Creates a `v<version>-<run-number>` tag
   and GitHub Release with the APK attached.

To cut a new version, bump `version:` in `pubspec.yaml`.

### Auto-merge

`.github/workflows/auto-merge.yml` squash-merges a pull request into `main` as
soon as its CI run is fully green (analyze, test, **and** the APK build). It runs
off the CI workflow completing, so the merge only happens once the whole pipeline
has passed.

- Add the label **`no-auto-merge`** to a PR to hold it for a manual merge.
- Because a merge performed by the built-in `GITHUB_TOKEN` does not re-trigger
  the `push`-to-`main` workflow, the auto-merge job dispatches CI on `main` after
  merging — that run builds and publishes the release. A manual merge you do
  yourself triggers the release the ordinary way, so releases are never
  duplicated.
- Auto-merge takes effect only from the copy of the workflow on `main` (a
  `workflow_run` requirement), so it governs future PRs, not the one that
  introduces it.

## Layout

```
lib/main.dart      app entry point and home screen
test/              widget tests
android/           Android host project (manifest, Gradle, MainActivity)
.github/workflows/ CI and release pipeline
```

## Permissions

Declared in `android/app/src/main/AndroidManifest.xml`:

- `RECORD_AUDIO` — capturing voice
- `READ_MEDIA_AUDIO` (API 33+) / `READ_EXTERNAL_STORAGE` (API ≤ 32) — importing
  existing audio files

These are manifest declarations only; runtime permission prompts still need to
be requested in code once the recording features land.
