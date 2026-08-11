import 'package:permission_handler/permission_handler.dart';

/// Result of a microphone-permission request, so the UI can react precisely.
enum MicPermissionResult { granted, denied, permanentlyDenied }

/// Requests microphone access and maps the outcome to [MicPermissionResult].
///
/// [permanentlyDenied] means the user ticked "don't ask again" (or denied on
/// a newer Android that treats a second denial as permanent); the caller
/// should offer to open app settings via [openAppSettings].
Future<MicPermissionResult> requestMicPermission() async {
  final status = await Permission.microphone.request();
  if (status.isGranted || status.isLimited) {
    return MicPermissionResult.granted;
  }
  if (status.isPermanentlyDenied) {
    return MicPermissionResult.permanentlyDenied;
  }
  return MicPermissionResult.denied;
}
