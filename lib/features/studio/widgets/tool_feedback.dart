import 'package:flutter/material.dart';

import '../../../services/audio_editor.dart';

/// Shows a snackbar for a failed FFmpeg operation, keeping the message short.
void showToolError(BuildContext context, Object error) {
  final message = error is AudioEditorException
      ? 'Failed: ${error.message.split('\n').last}'
      : 'Something went wrong: $error';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Shows a confirmation snackbar after a result is saved to the library.
void showSavedSnack(BuildContext context, String name) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('Saved "$name" to Library')));
}
