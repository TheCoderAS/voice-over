import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/recording_store.dart';
import '../../../models/recording.dart';
import '../../../services/audio_editor.dart';
import '../widgets/tool_feedback.dart';
import '../widgets/tool_scaffold.dart';

/// Shifts pitch up or down (in semitones) without changing tempo.
class PitchTool extends StatefulWidget {
  const PitchTool({super.key, required this.recording});

  final Recording recording;

  @override
  State<PitchTool> createState() => _PitchToolState();
}

class _PitchToolState extends State<PitchTool> {
  double _semitones = 0;
  bool _busy = false;

  Future<void> _apply() async {
    final store = context.read<RecordingStore>();
    setState(() => _busy = true);
    try {
      final out = await store.newOutputPath(extension: 'm4a', prefix: 'pitch');
      await const AudioEditor().pitchShift(
        inputPath: widget.recording.path,
        semitones: _semitones,
        outputPath: out,
      );
      final rec = await store.addProcessedFile(
        path: out,
        displayName: '${widget.recording.displayName} (pitch)',
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
    final rounded = _semitones.round();
    final sign = rounded > 0 ? '+' : '';

    return ToolScaffold(
      title: 'Pitch',
      busy: _busy,
      busyLabel: 'Shifting pitch…',
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
                '$sign$rounded',
                style: theme.textTheme.displayMedium,
              ),
            ),
            Center(
              child: Text(
                'semitones',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Slider(
              value: _semitones,
              min: -12,
              max: 12,
              divisions: 24,
              label: '$sign$rounded',
              onChanged: (v) => setState(() => _semitones = v),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: rounded == 0 ? null : _apply,
              icon: const Icon(Icons.tune),
              label: const Text('Apply & save'),
            ),
          ],
        ),
      ),
    );
  }
}
