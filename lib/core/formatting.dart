import 'package:intl/intl.dart';

/// Small formatting helpers shared across screens.

/// Formats a [Duration] as `m:ss`, or `h:mm:ss` once it passes an hour.
String formatDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  final seconds = d.inSeconds.remainder(60);
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    final mm = minutes.toString().padLeft(2, '0');
    return '$hours:$mm:$ss';
  }
  return '$minutes:$ss';
}

/// Formats a byte count as a short human-readable size (e.g. `1.4 MB`).
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB'];
  var size = bytes / 1024;
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  return '${size.toStringAsFixed(size >= 10 ? 0 : 1)} ${units[unit]}';
}

/// Formats a timestamp for list subtitles (e.g. `11 Aug 2026, 4:52 PM`).
String formatTimestamp(DateTime dt) =>
    DateFormat('d MMM yyyy, h:mm a').format(dt);
