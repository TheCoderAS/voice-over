import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/recording_store.dart';
import '../../../models/recording.dart';
import '../../../services/audio_editor.dart';
import '../widgets/tool_feedback.dart';
import '../widgets/tool_scaffold.dart';

/// Bass/treble shelving EQ with "warmth" adjustments.
class EqualizerTool extends StatefulWidget {
  const EqualizerTool({super.key, required this.recording});

  final Recording recording;

  @override
  State<EqualizerTool> createState() => _EqualizerToolState();
}

class _EqualizerToolState extends State<EqualizerTool> {
  double _bass = 0;
  double _treble = 0;
  bool _busy = false;

  Future<void> _apply() async {
    final store = context.read<RecordingStore>();
    setState(() => _busy = true);
    try {
      final out = await store.newOutputPath(extension: 'm4a', prefix: 'eq');
      await const AudioEditor().equalize(
        inputPath: widget.recording.path,
        bassGain: _bass,
        trebleGain: _treble,
        outputPath: out,
      );
      final rec = await store.addProcessedFile(
        path: out,
        displayName: '${widget.recording.displayName} (eq)',
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
    final canApply = _bass.abs() >= 0.1 || _treble.abs() >= 0.1;

    return ToolScaffold(
      title: 'Equalizer',
      busy: _busy,
      busyLabel: 'Applying EQ…',
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
            const SizedBox(height: 24),
            _GainSlider(
              label: 'Bass (warmth)',
              value: _bass,
              onChanged: (v) => setState(() => _bass = v),
            ),
            const SizedBox(height: 16),
            _GainSlider(
              label: 'Treble (clarity)',
              value: _treble,
              onChanged: (v) => setState(() => _treble = v),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: canApply ? _apply : null,
              icon: const Icon(Icons.equalizer),
              label: const Text('Apply & save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GainSlider extends StatelessWidget {
  const _GainSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final sign = value > 0 ? '+' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            Text('$sign${value.toStringAsFixed(1)} dB'),
          ],
        ),
        Slider(
          value: value,
          min: -15,
          max: 15,
          divisions: 60,
          label: '$sign${value.toStringAsFixed(1)} dB',
          onChanged: onChanged,
        ),
      ],
    );
  }
}
