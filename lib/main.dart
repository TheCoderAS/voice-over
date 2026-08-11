import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/recording_store.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const VoiceOverApp());
}

class VoiceOverApp extends StatelessWidget {
  const VoiceOverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RecordingStore()..init(),
      child: MaterialApp(
        title: 'Voice Over',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const HomeShell(),
      ),
    );
  }
}
