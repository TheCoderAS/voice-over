import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/recording_store.dart';
import '../../../models/recording.dart';
import '../../../services/audio_editor.dart';
import '../widgets/tool_feedback.dart';
import '../widgets/tool_scaffold.dart';

/// Adjusts the overall loudness of a recording.
class VolumeTool extends StatefulWidget {
  const VolumeTool({super.key, required this.recording});

  final Recording recording;

  @override
  State<VolumeTool> createState() => _VolumeToolState();
}

class _VolumeToolState extends State<VolumeTool> {
  // 1.0 = unchanged. Range 0.1x … 4x.
  double _factor = 1.0;
  bool _busy = false;

  String get _decibels {
    if (_factor <= 0) return '−∞ dB';
    final db = 20 * (math.log(_factor) / math.ln10);
    final sign = db >= 0 ? '+' : '';
    return '$sign${db.toStringAsFixed(1)} dB';
  }

  Future<void> _apply() async {
    final store = context.read<RecordingStore>();
    setState(() => _busy = true);
    try {
      final out = await store.newOutputPath(extension: 'm4a', prefix: 'vol');
      await const AudioEditor().changeVolume(
        inputPath: widget.recording.path,
        factor: _factor,
        outputPath: out,
      );
      final rec = await store.addProcessedFile(
        path: out,
        displayName: '${widget.recording.displayName} (volume)',
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
      title: 'Volume',
      busy: _busy,
      busyLabel: 'Adjusting volume…',
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
                '${_factor.toStringAsFixed(2)}×',
                style: theme.textTheme.displaySmall,
              ),
            ),
            Center(
              child: Text(
                _decibels,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Slider(
              value: _factor,
              min: 0.1,
              max: 4.0,
              divisions: 39,
              label: '${_factor.toStringAsFixed(2)}×',
              onChanged: (v) => setState(() => _factor = v),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _factor == 1.0 ? null : _apply,
              icon: const Icon(Icons.volume_up),
              label: const Text('Apply & save'),
            ),
          ],
        ),
      ),
    );
  }
}
