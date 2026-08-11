import 'dart:io';

/// A single audio clip owned by the app (recorded or imported), backed by a
/// file in the app's private recordings directory.
class Recording {
  const Recording({
    required this.fileName,
    required this.displayName,
    required this.path,
    required this.durationMs,
    required this.createdAt,
    required this.sizeBytes,
  });

  /// File name including extension; unique within the recordings directory and
  /// used as the stable id.
  final String fileName;

  /// User-facing name (without extension), editable via rename.
  final String displayName;

  /// Absolute path to the audio file on disk.
  final String path;

  /// Duration in milliseconds. 0 when not yet known.
  final int durationMs;

  final DateTime createdAt;
  final int sizeBytes;

  Duration get duration => Duration(milliseconds: durationMs);

  String get extension {
    final dot = fileName.lastIndexOf('.');
    return dot == -1 ? '' : fileName.substring(dot + 1).toUpperCase();
  }

  Recording copyWith({String? displayName, int? durationMs, int? sizeBytes}) {
    return Recording(
      fileName: fileName,
      displayName: displayName ?? this.displayName,
      path: path,
      durationMs: durationMs ?? this.durationMs,
      createdAt: createdAt,
      sizeBytes: sizeBytes ?? this.sizeBytes,
    );
  }

  Map<String, dynamic> toJson() => {
    'fileName': fileName,
    'displayName': displayName,
    'durationMs': durationMs,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'sizeBytes': sizeBytes,
  };

  /// Rebuilds a [Recording] from an index entry, resolving its path against the
  /// current recordings [directory] (paths are not persisted so the app keeps
  /// working if its sandbox directory changes between installs).
  static Recording fromJson(Map<String, dynamic> json, String directory) {
    final fileName = json['fileName'] as String;
    return Recording(
      fileName: fileName,
      displayName: (json['displayName'] as String?) ?? fileName,
      path: '$directory/$fileName',
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAt'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      ),
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }

  /// Builds a [Recording] by inspecting a file already on disk.
  static Recording fromFile(
    File file, {
    String? displayName,
    int durationMs = 0,
  }) {
    final name = file.uri.pathSegments.last;
    final stat = file.statSync();
    final base = name.contains('.')
        ? name.substring(0, name.lastIndexOf('.'))
        : name;
    return Recording(
      fileName: name,
      displayName: displayName ?? base,
      path: file.path,
      durationMs: durationMs,
      createdAt: stat.modified,
      sizeBytes: stat.size,
    );
  }
}
