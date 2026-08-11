import 'dart:math' as math;

import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';

/// Thrown when an FFmpeg operation fails; carries the tail of the FFmpeg log
/// so the UI can surface something actionable.
class AudioEditorException implements Exception {
  AudioEditorException(this.message);
  final String message;
  @override
  String toString() => 'AudioEditorException: $message';
}

/// Voice-changer presets, each mapping to an FFmpeg audio-filter chain.
enum VoiceEffect {
  chipmunk,
  deep,
  robot,
  alien,
  monster,
  echo,
  maleToFemale,
  femaleToMale,
}

extension VoiceEffectX on VoiceEffect {
  String get label => switch (this) {
    VoiceEffect.chipmunk => 'Chipmunk',
    VoiceEffect.deep => 'Deep voice',
    VoiceEffect.robot => 'Robot',
    VoiceEffect.alien => 'Alien',
    VoiceEffect.monster => 'Monster',
    VoiceEffect.echo => 'Echo',
    VoiceEffect.maleToFemale => 'Male → Female',
    VoiceEffect.femaleToMale => 'Female → Male',
  };

  /// Short suffix appended to the output's display name.
  String get suffix => switch (this) {
    VoiceEffect.chipmunk => 'chipmunk',
    VoiceEffect.deep => 'deep',
    VoiceEffect.robot => 'robot',
    VoiceEffect.alien => 'alien',
    VoiceEffect.monster => 'monster',
    VoiceEffect.echo => 'echo',
    VoiceEffect.maleToFemale => 'female',
    VoiceEffect.femaleToMale => 'male',
  };

  /// The FFmpeg `-af` filter chain implementing this effect.
  String get filter => switch (this) {
    VoiceEffect.chipmunk => AudioEditor.pitchFilter(7),
    VoiceEffect.deep => AudioEditor.pitchFilter(-5),
    VoiceEffect.maleToFemale => AudioEditor.pitchFilter(4),
    VoiceEffect.femaleToMale => AudioEditor.pitchFilter(-4),
    VoiceEffect.monster =>
      '${AudioEditor.pitchFilter(-8)},aecho=0.8:0.88:60:0.4',
    VoiceEffect.alien => '${AudioEditor.pitchFilter(4)},vibrato=f=6:d=0.7',
    VoiceEffect.echo => 'aecho=0.8:0.9:1000:0.3',
    // Classic monotone "robot" via spectral magnitude passthrough.
    VoiceEffect.robot =>
      "afftfilt=real='hypot(re,im)*sin(0)':"
          "imag='hypot(re,im)*cos(0)':win_size=512:overlap=0.75",
  };
}

/// Reverb spaces, approximated with echo/delay chains.
enum ReverbPreset { room, studio, hall, cave }

extension ReverbPresetX on ReverbPreset {
  String get label => switch (this) {
    ReverbPreset.room => 'Room',
    ReverbPreset.studio => 'Studio',
    ReverbPreset.hall => 'Hall',
    ReverbPreset.cave => 'Cave',
  };

  String get filter => switch (this) {
    ReverbPreset.room => 'aecho=0.8:0.9:40:0.25',
    ReverbPreset.studio => 'aecho=0.8:0.9:60:0.35',
    ReverbPreset.hall => 'aecho=0.85:0.9:500|700:0.4|0.3',
    ReverbPreset.cave => 'aecho=0.85:0.88:900|1200:0.5|0.4',
  };
}

/// Output audio formats the editor can render to.
enum AudioFormat { m4a, mp3, wav, aac }

extension AudioFormatX on AudioFormat {
  String get fileExtension => switch (this) {
    AudioFormat.m4a => 'm4a',
    AudioFormat.mp3 => 'mp3',
    AudioFormat.wav => 'wav',
    AudioFormat.aac => 'aac',
  };

  String get label => switch (this) {
    AudioFormat.m4a => 'M4A (AAC)',
    AudioFormat.mp3 => 'MP3',
    AudioFormat.wav => 'WAV (lossless)',
    AudioFormat.aac => 'AAC',
  };

  /// FFmpeg encoder for this format.
  String get codec => switch (this) {
    AudioFormat.m4a || AudioFormat.aac => 'aac',
    AudioFormat.mp3 => 'libmp3lame',
    AudioFormat.wav => 'pcm_s16le',
  };

  /// WAV is uncompressed, so a bitrate doesn't apply.
  bool get supportsBitrate => this != AudioFormat.wav;
}

/// On-device audio editing built on FFmpeg. Every method writes to
/// [outputPath] and returns it on success, or throws [AudioEditorException].
///
/// Operations re-encode to AAC (128 kbps) by default so results are accurate
/// (sample-accurate cuts) and uniformly compatible; [export] is the exception
/// where the caller chooses the codec and bitrate.
class AudioEditor {
  const AudioEditor();

  static const _defaultBitrate = '128k';

  Future<String> _run(List<String> args, String outputPath) async {
    final session = await FFmpegKit.executeWithArguments(args);
    final returnCode = await session.getReturnCode();
    if (ReturnCode.isSuccess(returnCode)) {
      return outputPath;
    }
    final logs = await session.getAllLogsAsString();
    final tail = (logs ?? '').trim();
    throw AudioEditorException(
      tail.isEmpty
          ? 'FFmpeg exited with code ${returnCode?.getValue()}'
          : tail.substring(tail.length > 600 ? tail.length - 600 : 0),
    );
  }

  static String _sec(Duration d) =>
      (d.inMilliseconds / 1000.0).toStringAsFixed(3);

  static const _baseSampleRate = 44100;

  /// Filter chain that shifts pitch by [semitones] without changing tempo.
  /// Valid for roughly ±12 semitones (atempo's 0.5–2.0 window).
  static String pitchFilter(double semitones) {
    final factor = math.pow(2, semitones / 12).toDouble();
    final tempo = (1 / factor).toStringAsFixed(6);
    return 'asetrate=${_baseSampleRate * factor},'
        'atempo=$tempo,aresample=$_baseSampleRate';
  }

  /// Decomposes a speed [rate] into a chain of atempo filters, each within the
  /// filter's supported 0.5–2.0 range.
  static String _tempoFilter(double rate) {
    final parts = <String>[];
    var r = rate;
    while (r > 2.0) {
      parts.add('atempo=2.0');
      r /= 2.0;
    }
    while (r < 0.5) {
      parts.add('atempo=0.5');
      r /= 0.5;
    }
    parts.add('atempo=${r.toStringAsFixed(6)}');
    return parts.join(',');
  }

  /// Applies a [VoiceEffect] preset.
  Future<String> applyEffect({
    required String inputPath,
    required VoiceEffect effect,
    required String outputPath,
  }) {
    final args = [
      '-y',
      '-i',
      inputPath,
      '-af',
      effect.filter,
      '-c:a',
      'aac',
      '-b:a',
      _defaultBitrate,
      outputPath,
    ];
    return _run(args, outputPath);
  }

  /// Shifts pitch by [semitones] (−12…+12) while preserving tempo.
  Future<String> pitchShift({
    required String inputPath,
    required double semitones,
    required String outputPath,
  }) {
    final args = [
      '-y',
      '-i',
      inputPath,
      '-af',
      pitchFilter(semitones),
      '-c:a',
      'aac',
      '-b:a',
      _defaultBitrate,
      outputPath,
    ];
    return _run(args, outputPath);
  }

  /// Changes playback speed by [rate] (e.g. 0.5 = half, 2.0 = double) while
  /// preserving pitch.
  Future<String> changeSpeed({
    required String inputPath,
    required double rate,
    required String outputPath,
  }) {
    final args = [
      '-y',
      '-i',
      inputPath,
      '-af',
      _tempoFilter(rate),
      '-c:a',
      'aac',
      '-b:a',
      _defaultBitrate,
      outputPath,
    ];
    return _run(args, outputPath);
  }

  /// Keeps only the audio between [start] and [end].
  Future<String> trim({
    required String inputPath,
    required Duration start,
    required Duration end,
    required String outputPath,
  }) {
    final args = [
      '-y',
      '-i',
      inputPath,
      '-ss',
      _sec(start),
      '-to',
      _sec(end),
      '-c:a',
      'aac',
      '-b:a',
      _defaultBitrate,
      outputPath,
    ];
    return _run(args, outputPath);
  }

  /// Concatenates [inputPaths] (in order) into one clip.
  Future<String> merge({
    required List<String> inputPaths,
    required String outputPath,
  }) {
    if (inputPaths.length < 2) {
      throw AudioEditorException('Merging needs at least two clips.');
    }
    final args = <String>['-y'];
    for (final path in inputPaths) {
      args.addAll(['-i', path]);
    }
    final labels = List.generate(inputPaths.length, (i) => '[$i:a]').join();
    final filter = '${labels}concat=n=${inputPaths.length}:v=0:a=1[out]';
    args.addAll([
      '-filter_complex',
      filter,
      '-map',
      '[out]',
      '-c:a',
      'aac',
      '-b:a',
      _defaultBitrate,
      outputPath,
    ]);
    return _run(args, outputPath);
  }

  /// Applies a fade-in and/or fade-out. [totalDuration] is the clip length,
  /// needed to place the fade-out.
  Future<String> fade({
    required String inputPath,
    required Duration totalDuration,
    required Duration fadeIn,
    required Duration fadeOut,
    required String outputPath,
  }) {
    final filters = <String>[];
    if (fadeIn > Duration.zero) {
      filters.add('afade=t=in:st=0:d=${_sec(fadeIn)}');
    }
    if (fadeOut > Duration.zero) {
      final start = totalDuration - fadeOut;
      final startSec = start.isNegative ? Duration.zero : start;
      filters.add('afade=t=out:st=${_sec(startSec)}:d=${_sec(fadeOut)}');
    }
    if (filters.isEmpty) {
      throw AudioEditorException('Set a fade-in or fade-out first.');
    }
    final args = [
      '-y',
      '-i',
      inputPath,
      '-af',
      filters.join(','),
      '-c:a',
      'aac',
      '-b:a',
      _defaultBitrate,
      outputPath,
    ];
    return _run(args, outputPath);
  }

  /// Scales loudness by [factor] (1.0 = unchanged, 2.0 = +6 dB, 0.5 = -6 dB).
  Future<String> changeVolume({
    required String inputPath,
    required double factor,
    required String outputPath,
  }) {
    final args = [
      '-y',
      '-i',
      inputPath,
      '-af',
      'volume=${factor.toStringAsFixed(3)}',
      '-c:a',
      'aac',
      '-b:a',
      _defaultBitrate,
      outputPath,
    ];
    return _run(args, outputPath);
  }

  /// Mixes [backgroundPath] under [voicePath] at [backgroundVolume]
  /// (0.0–1.0+). The result is trimmed to the voice track's length.
  Future<String> mixBackground({
    required String voicePath,
    required String backgroundPath,
    required double backgroundVolume,
    required String outputPath,
  }) {
    final filter =
        '[1:a]volume=${backgroundVolume.toStringAsFixed(3)}[bg];'
        '[0:a][bg]amix=inputs=2:duration=first:dropout_transition=2[out]';
    final args = [
      '-y',
      '-i',
      voicePath,
      '-i',
      backgroundPath,
      '-filter_complex',
      filter,
      '-map',
      '[out]',
      '-c:a',
      'aac',
      '-b:a',
      _defaultBitrate,
      outputPath,
    ];
    return _run(args, outputPath);
  }

  /// Re-encodes to [format] at the requested [sampleRate] and, for compressed
  /// formats, [bitrate] (e.g. '128k', '320k').
  Future<String> export({
    required String inputPath,
    required AudioFormat format,
    required int sampleRate,
    required String bitrate,
    required String outputPath,
  }) {
    final args = <String>[
      '-y',
      '-i',
      inputPath,
      '-ar',
      '$sampleRate',
      '-c:a',
      format.codec,
    ];
    if (format.supportsBitrate) {
      args.addAll(['-b:a', bitrate]);
    }
    args.add(outputPath);
    return _run(args, outputPath);
  }

  /// Reduces steady background noise (fan, hum, hiss) with an FFT denoiser.
  Future<String> reduceNoise({
    required String inputPath,
    required String outputPath,
  }) {
    final args = [
      '-y',
      '-i',
      inputPath,
      '-af',
      'afftdn=nf=-25',
      '-c:a',
      'aac',
      '-b:a',
      _defaultBitrate,
      outputPath,
    ];
    return _run(args, outputPath);
  }

  /// Normalizes perceived loudness to a broadcast target (EBU R128).
  Future<String> normalize({
    required String inputPath,
    required String outputPath,
  }) {
    final args = [
      '-y',
      '-i',
      inputPath,
      '-af',
      'loudnorm=I=-16:TP=-1.5:LRA=11',
      '-c:a',
      'aac',
      '-b:a',
      _defaultBitrate,
      outputPath,
    ];
    return _run(args, outputPath);
  }

  /// Bass/treble shelving EQ, each gain in dB (roughly -15…+15).
  Future<String> equalize({
    required String inputPath,
    required double bassGain,
    required double trebleGain,
    required String outputPath,
  }) {
    final filters = <String>[];
    if (bassGain.abs() >= 0.1) {
      filters.add('bass=g=${bassGain.toStringAsFixed(1)}');
    }
    if (trebleGain.abs() >= 0.1) {
      filters.add('treble=g=${trebleGain.toStringAsFixed(1)}');
    }
    if (filters.isEmpty) {
      throw AudioEditorException('Set a bass or treble adjustment first.');
    }
    final args = [
      '-y',
      '-i',
      inputPath,
      '-af',
      filters.join(','),
      '-c:a',
      'aac',
      '-b:a',
      _defaultBitrate,
      outputPath,
    ];
    return _run(args, outputPath);
  }

  /// Applies a reverb [preset].
  Future<String> reverb({
    required String inputPath,
    required ReverbPreset preset,
    required String outputPath,
  }) {
    final args = [
      '-y',
      '-i',
      inputPath,
      '-af',
      preset.filter,
      '-c:a',
      'aac',
      '-b:a',
      _defaultBitrate,
      outputPath,
    ];
    return _run(args, outputPath);
  }
}
