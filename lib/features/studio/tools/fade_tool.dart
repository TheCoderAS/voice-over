import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/recording_store.dart';
import '../../../models/recording.dart';
import '../../../services/audio_editor.dart';
import '../widgets/tool_feedback.dart';
import '../widgets/tool_scaffold.dart';

/// Applies a fade-in and/or fade-out to a recording.
class FadeTool extends StatefulWidget {
  const FadeTool({super.key, required this.recording});

  final Recording recording;

  @override
  State<FadeTool> createState() => _FadeToolState();
}

class _FadeToolState extends State<FadeTool> {
  double _fadeInSec = 1;
  double _fadeOutSec = 1;
  bool _busy = false;

  double get _maxFade {
    final half = widget.recording.durationMs / 2000.0;
    if (half.isNaN || half < 0.5) return 0.5;
    return half.clamp(0.5, 10).toDouble();
  }

  Future<void> _apply() async {
    final store = context.read<RecordingStore>();
    setState(() => _busy = true);
    try {
      final out = await store.newOutputPath(extension: 'm4a', prefix: 'fade');
      await const AudioEditor().fade(
        inputPath: widget.recording.path,
        totalDuration: widget.recording.duration,
        fadeIn: Duration(milliseconds: (_fadeInSec * 1000).round()),
        fadeOut: Duration(milliseconds: (_fadeOutSec * 1000).round()),
        outputPath: out,
      );
      final rec = await store.addProcessedFile(
        path: out,
        displayName: '${widget.recording.displayName} (fade)',
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
    final canApply = _fadeInSec > 0 || _fadeOutSec > 0;

    return ToolScaffold(
      title: 'Fade in / out',
      busy: _busy,
      busyLabel: 'Applying fades…',
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
            _SliderRow(
              label: 'Fade in',
              value: _fadeInSec,
              max: _maxFade,
              onChanged: (v) => setState(() => _fadeInSec = v),
            ),
            const SizedBox(height: 16),
            _SliderRow(
              label: 'Fade out',
              value: _fadeOutSec,
              max: _maxFade,
              onChanged: (v) => setState(() => _fadeOutSec = v),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: canApply ? _apply : null,
              icon: const Icon(Icons.gradient),
              label: const Text('Apply & save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleSmall),
            Text('${value.toStringAsFixed(1)} s'),
          ],
        ),
        Slider(
          value: value.clamp(0, max),
          min: 0,
          max: max,
          divisions: (max * 2).round().clamp(1, 40),
          label: '${value.toStringAsFixed(1)} s',
          onChanged: onChanged,
        ),
      ],
    );
  }
}
