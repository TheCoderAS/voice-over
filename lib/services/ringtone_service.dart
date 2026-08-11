import 'package:flutter/services.dart';

/// Which system sound slot to assign.
enum RingtoneType { ringtone, alarm, notification }

extension RingtoneTypeX on RingtoneType {
  String get id => name; // 'ringtone' | 'alarm' | 'notification'
  String get label => switch (this) {
    RingtoneType.ringtone => 'Ringtone',
    RingtoneType.alarm => 'Alarm',
    RingtoneType.notification => 'Notification',
  };
}

/// Outcome of a set-as request.
enum RingtoneResult { ok, permissionNeeded }

/// Bridges to native Android to publish an audio file to MediaStore and set it
/// as the default ringtone / alarm / notification sound.
class RingtoneService {
  static const _channel = MethodChannel('voice_over/ringtone');

  /// Whether the app currently holds the "modify system settings" permission.
  static Future<bool> canWrite() async {
    final res = await _channel.invokeMethod<bool>('canWrite');
    return res ?? false;
  }

  /// Opens the system screen to grant "modify system settings".
  static Future<void> requestPermission() =>
      _channel.invokeMethod('requestWritePermission');

  /// Sets [path] as the default sound for [type].
  ///
  /// Returns [RingtoneResult.permissionNeeded] (and opens the settings screen)
  /// if the permission is missing; throws [PlatformException] on other errors.
  static Future<RingtoneResult> setAs(String path, RingtoneType type) async {
    final res = await _channel.invokeMethod<String>('setAs', {
      'path': path,
      'type': type.id,
    });
    return res == 'ok' ? RingtoneResult.ok : RingtoneResult.permissionNeeded;
  }
}
