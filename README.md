# Voice Over

An Android app for **voice recording, editing, voice changing, and ultra-realistic text-to-speech**, built with Flutter.

## Features

### 🎙️ Record & Library
- High-quality recorder with a **live waveform**, timer, and **pause / resume**.
- **Import** audio files from device storage.
- Library with waveform **playback**, seek, rename, delete.
- **Set as ringtone / alarm / notification** from any clip.

### ✂️ Studio — editing
- **Trim** (waveform range select), **Merge** clips, **Fade** in/out.
- **Volume** (with dB readout), **Mix** a background track under a voice.
- **Export / convert**: MP3 / WAV / AAC / M4A, bitrate + sample-rate options.

### 🎛️ Studio — voice changer & DSP
- **Effects**: Chipmunk, Deep, Robot, Alien, Monster, Echo, Male↔Female.
- **Pitch** shift (±12 semitones, tempo preserved) and **Speed** (0.5–2×, pitch preserved).
- **Denoise**, **Equalizer** (bass/treble), **Reverb** (Room/Studio/Hall/Cave), **Normalize** (EBU R128).
- **Soundscape** generator: rain, ocean, wind, and white/pink/brown noise.

All editing/DSP runs **on-device** via FFmpeg (`ffmpeg_kit_flutter_new_audio`).

### 🗣️ Voice — ultra-realistic TTS
- Natural, human-like speech from text via **ElevenLabs** or **Azure Neural TTS**.
- **Tones**: sweet, polite, friendly, professional, storyteller, calm.
- Voices for **English (US/UK/IN)** and **Hindi**, plus each account's full catalogue.
- **SSML** support (Azure): paste a `<speak>` document for emphasis/pauses/pitch.
- **Bring your own API key** — stored encrypted on-device; nothing bundled.

Generated speech lands in the Library, so it can be edited and effected like any clip.

## Getting an installable APK

Every push to `main` publishes a **GitHub Release** with an APK attached — grab
the latest from the [Releases page](../../releases) and install it on any
Android 7.0 (API 24)+ device (allow "install from unknown sources"). Branch/PR
builds upload a `voice-over-apk` artifact under [Actions](../../actions).

> **Signing:** release builds use a fixed **testing** key committed at
> `android/keystore/voiceover-testing.jks`, so updates install over previous
> builds without an uninstall. Swap in a real Play upload key later via the
> `VOICEOVER_STORE_FILE` / `_STORE_PASSWORD` / `_KEY_ALIAS` / `_KEY_PASSWORD`
> environment variables — no code change.

## Setting up TTS

Open **Voice → ⚙️**, choose a provider, and paste your key:
- **ElevenLabs** — API key from elevenlabs.io → Profile → API Keys.
- **Azure** — Speech resource key + region from the Azure portal.

Generation runs on the provider's servers and uses your account's quota/credits.

## Tech stack

| | |
|---|---|
| Flutter / Dart | 3.44.9 stable / 3.12.2 |
| Application ID | `com.unisync.voiceover` |
| Min Android | 7.0 (API 24) · target/compile SDK 36 |
| Toolchain | AGP 8.11, Gradle 8.13, Kotlin 2.1.20, JDK 21 |
| Audio | `audio_waveforms`, `ffmpeg_kit_flutter_new_audio` |
| TTS / storage | `http`, `flutter_secure_storage` |

## Local development

```bash
flutter pub get
flutter run                 # debug build on a device/emulator
flutter build apk --release # release APK -> build/app/outputs/flutter-apk/
```

Before pushing, run what CI runs:

```bash
dart format .
flutter analyze
flutter test
```

## CI / CD

`.github/workflows/ci.yml` — on every PR and push to `main`:
1. **Analyze & test** — format check, `flutter analyze`, `flutter test`.
2. **Build** — release APK uploaded as an artifact.
3. **Release** — `main` only: tags and publishes a GitHub Release with the APK.

`.github/workflows/auto-merge.yml` squash-merges a PR once its CI is fully green
(label `no-auto-merge` to hold one).

## Known limitations / next steps

- **Real-time preview** while adjusting a filter isn't implemented; tools render
  then let you play the result. Live preview would need streaming DSP.
- **AI voice conversion (RVC)** needs a hosted GPU backend and isn't feasible
  on-device; it's intentionally out of scope until a service is available.
- The **soundscape/SFX** set is FFmpeg-generated ambience plus your own imports;
  a bundled pack of recorded ambiences/SFX would need licensed audio assets.

## Permissions

- `RECORD_AUDIO` — recording
- `READ_MEDIA_AUDIO` / `READ_EXTERNAL_STORAGE` — importing audio
- `INTERNET` — cloud TTS
- `WRITE_SETTINGS` — setting ringtone / alarm / notification
