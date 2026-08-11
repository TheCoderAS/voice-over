import 'dart:convert';
import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/recording.dart';

/// Owns the list of recordings and their on-disk storage.
///
/// Files live in `<app documents>/recordings`. A small `index.json` in that
/// directory persists metadata (display name, duration, timestamps) that can't
/// be recovered from the audio file alone. On load the index is reconciled with
/// the actual files so nothing goes stale if a file is added or removed out of
/// band.
class RecordingStore extends ChangeNotifier {
  RecordingStore();

  final List<Recording> _recordings = [];
  bool _loading = true;
  Directory? _dir;

  /// Recordings, newest first.
  List<Recording> get recordings => List.unmodifiable(_recordings);
  bool get isLoading => _loading;

  static const _supportedExtensions = {
    '.m4a',
    '.aac',
    '.mp3',
    '.wav',
    '.opus',
    '.amr',
  };

  Future<Directory> _ensureDir() async {
    if (_dir != null) return _dir!;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'recordings'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    _dir = dir;
    return dir;
  }

  File _indexFile(Directory dir) => File(p.join(dir.path, 'index.json'));

  /// Directory where a new recording file should be written.
  Future<String> newRecordingPath({String extension = 'm4a'}) async {
    final dir = await _ensureDir();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return p.join(dir.path, 'rec_$stamp.$extension');
  }

  Future<void> init() async {
    final dir = await _ensureDir();

    // Load persisted metadata into a lookup keyed by file name.
    final indexed = <String, Recording>{};
    final indexFile = _indexFile(dir);
    if (indexFile.existsSync()) {
      try {
        final raw = jsonDecode(indexFile.readAsStringSync());
        if (raw is List) {
          for (final entry in raw) {
            if (entry is Map<String, dynamic>) {
              final rec = Recording.fromJson(entry, dir.path);
              indexed[rec.fileName] = rec;
            }
          }
        }
      } catch (_) {
        // Corrupt index is non-fatal: fall back to scanning files.
      }
    }

    // Reconcile against files actually present on disk.
    final result = <Recording>[];
    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      final ext = p.extension(entity.path).toLowerCase();
      if (!_supportedExtensions.contains(ext)) continue;

      final name = p.basename(entity.path);
      final known = indexed[name];
      if (known != null) {
        // Refresh size in case the file changed.
        result.add(known.copyWith(sizeBytes: entity.statSync().size));
      } else {
        result.add(Recording.fromFile(entity));
      }
    }

    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _recordings
      ..clear()
      ..addAll(result);
    _loading = false;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final dir = await _ensureDir();
    final data = _recordings.map((r) => r.toJson()).toList();
    _indexFile(dir).writeAsStringSync(jsonEncode(data));
  }

  /// Registers a freshly recorded file (already written to [path]) with a known
  /// [duration].
  Future<Recording> addRecordedFile({
    required String path,
    required Duration duration,
    String? displayName,
  }) async {
    final file = File(path);
    final rec = Recording.fromFile(
      file,
      displayName: displayName,
      durationMs: duration.inMilliseconds,
    );
    _recordings.insert(0, rec);
    notifyListeners();
    await _persist();
    return rec;
  }

  /// Copies an external audio file into the recordings directory, extracts its
  /// duration, and adds it to the library.
  Future<Recording> importFrom(String sourcePath, {String? displayName}) async {
    final dir = await _ensureDir();
    final ext = p.extension(sourcePath).toLowerCase();
    final safeExt = _supportedExtensions.contains(ext) ? ext : '.m4a';
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final destPath = p.join(dir.path, 'import_$stamp$safeExt');
    await File(sourcePath).copy(destPath);

    final durationMs = await _probeDurationMs(destPath);
    final baseName = displayName ?? p.basenameWithoutExtension(sourcePath);
    final rec = Recording.fromFile(
      File(destPath),
      displayName: baseName,
      durationMs: durationMs,
    );
    _recordings.insert(0, rec);
    notifyListeners();
    await _persist();
    return rec;
  }

  Future<void> rename(Recording recording, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    final index = _recordings.indexWhere(
      (r) => r.fileName == recording.fileName,
    );
    if (index == -1) return;
    _recordings[index] = _recordings[index].copyWith(displayName: trimmed);
    notifyListeners();
    await _persist();
  }

  Future<void> delete(Recording recording) async {
    final file = File(recording.path);
    if (file.existsSync()) {
      try {
        file.deleteSync();
      } catch (_) {
        // Ignore: still remove from the list so the UI stays consistent.
      }
    }
    _recordings.removeWhere((r) => r.fileName == recording.fileName);
    notifyListeners();
    await _persist();
  }

  /// Deletes a file that was written to disk (e.g. a started-then-discarded
  /// recording) but never added to the library. No-op if it's missing.
  Future<void> deleteOrphanFile(String path) async {
    final file = File(path);
    if (file.existsSync()) {
      try {
        file.deleteSync();
      } catch (_) {
        // best effort
      }
    }
  }

  /// Reads a file's duration by briefly preparing a [PlayerController].
  Future<int> _probeDurationMs(String path) async {
    final controller = PlayerController();
    try {
      await controller.preparePlayer(path: path, shouldExtractWaveform: false);
      return controller.maxDuration < 0 ? 0 : controller.maxDuration;
    } catch (_) {
      return 0;
    } finally {
      controller.dispose();
    }
  }
}
