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
}
