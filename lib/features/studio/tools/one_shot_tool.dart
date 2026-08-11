import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/recording_store.dart';
import '../../../models/recording.dart';
import '../../../services/audio_editor.dart';
import '../widgets/tool_feedback.dart';
import '../widgets/tool_scaffold.dart';

/// A one-tap processing tool: describe the effect, tap apply, save the result.
/// Used for operations with no parameters (denoise, normalize).
class OneShotTool extends StatefulWidget {
  const OneShotTool({
    super.key,
    required this.recording,
    required this.title,
    required this.description,
    required this.busyLabel,
    required this.buttonLabel,
    required this.icon,
    required this.suffix,
    required this.run,
  });

  final Recording recording;
  final String title;
  final String description;
  final String busyLabel;
  final String buttonLabel;
  final IconData icon;

  /// Suffix for the saved clip's name and its file prefix.
  final String suffix;

  /// Runs the operation, returning the output path.
  final Future<String> Function(
    AudioEditor editor,
    String inputPath,
    String outputPath,
  )
  run;

  @override
  State<OneShotTool> createState() => _OneShotToolState();
}

class _OneShotToolState extends State<OneShotTool> {
  bool _busy = false;

  Future<void> _apply() async {
    final store = context.read<RecordingStore>();
    setState(() => _busy = true);
    try {
      final out = await store.newOutputPath(
        extension: 'm4a',
        prefix: widget.suffix,
      );
      await widget.run(const AudioEditor(), widget.recording.path, out);
      final rec = await store.addProcessedFile(
        path: out,
        displayName: '${widget.recording.displayName} (${widget.suffix})',
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
      title: widget.title,
      busy: _busy,
      busyLabel: widget.busyLabel,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.recording.displayName,
              style: theme.textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 32),
            Icon(widget.icon, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              widget.description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _apply,
              icon: Icon(widget.icon),
              label: Text(widget.buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
