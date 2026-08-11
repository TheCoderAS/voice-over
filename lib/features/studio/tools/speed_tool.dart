import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/recording_store.dart';
import '../../../models/recording.dart';
import '../../../services/audio_editor.dart';
import '../widgets/tool_feedback.dart';
import '../widgets/tool_scaffold.dart';

/// Changes playback speed without altering pitch (time-stretch).
class SpeedTool extends StatefulWidget {
  const SpeedTool({super.key, required this.recording});

  final Recording recording;

  @override
  State<SpeedTool> createState() => _SpeedToolState();
}

class _SpeedToolState extends State<SpeedTool> {
  double _rate = 1.0;
  bool _busy = false;

  Future<void> _apply() async {
    final store = context.read<RecordingStore>();
    setState(() => _busy = true);
    try {
      final out = await store.newOutputPath(extension: 'm4a', prefix: 'speed');
      await const AudioEditor().changeSpeed(
        inputPath: widget.recording.path,
        rate: _rate,
        outputPath: out,
      );
      final rec = await store.addProcessedFile(
        path: out,
        displayName: '${widget.recording.displayName} (speed)',
      );
      if (!mounted) return;
      showSavedSnack(context, rec.displayName);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToolError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ToolScaffold(
      title: 'Speed',
      busy: _busy,
      busyLabel: 'Changing speed…',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.recording.displayName,
              style: theme.textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                '${_rate.toStringAsFixed(2)}×',
                style: theme.textTheme.displayMedium,
              ),
            ),
            Center(
              child: Text(
                'playback speed (pitch preserved)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Slider(
              value: _rate,
              min: 0.5,
              max: 2.0,
              divisions: 30,
              label: '${_rate.toStringAsFixed(2)}×',
              onChanged: (v) => setState(() => _rate = v),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _rate == 1.0 ? null : _apply,
              icon: const Icon(Icons.speed),
              label: const Text('Apply & save'),
            ),
          ],
        ),
      ),
    );
  }
}
