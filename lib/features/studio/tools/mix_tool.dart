import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/recording_store.dart';
import '../../../models/recording.dart';
import '../../../services/audio_editor.dart';
import '../widgets/recording_picker.dart';
import '../widgets/tool_feedback.dart';
import '../widgets/tool_scaffold.dart';

/// Layers a background track under a voice recording, with independent
/// background volume. The output matches the voice track's length.
class MixTool extends StatefulWidget {
  const MixTool({super.key, required this.voice});

  final Recording voice;

  @override
  State<MixTool> createState() => _MixToolState();
}

class _MixToolState extends State<MixTool> {
  Recording? _background;
  double _backgroundVolume = 0.4;
  bool _busy = false;

  Future<void> _pickBackground() async {
    final pick = await pickRecording(
      context,
      title: 'Choose a background track',
      enabledWhere: (r) => r.fileName != widget.voice.fileName,
    );
    if (pick != null) setState(() => _background = pick);
  }

  Future<void> _apply() async {
    final background = _background;
    if (background == null) return;
    final store = context.read<RecordingStore>();
    setState(() => _busy = true);
    try {
      final out = await store.newOutputPath(extension: 'm4a', prefix: 'mix');
      await const AudioEditor().mixBackground(
        voicePath: widget.voice.path,
        backgroundPath: background.path,
        backgroundVolume: _backgroundVolume,
        outputPath: out,
      );
      final rec = await store.addProcessedFile(
        path: out,
        displayName: '${widget.voice.displayName} (mix)',
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
      title: 'Mix background',
      busy: _busy,
      busyLabel: 'Mixing…',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TrackRow(
              label: 'Voice',
              name: widget.voice.displayName,
              icon: Icons.mic,
            ),
            const SizedBox(height: 12),
            _TrackRow(
              label: 'Background',
              name: _background?.displayName ?? 'Tap to choose',
              icon: Icons.music_note,
              onTap: _pickBackground,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Background volume', style: theme.textTheme.titleSmall),
                Text('${(_backgroundVolume * 100).round()}%'),
              ],
            ),
            Slider(
              value: _backgroundVolume,
              max: 1.5,
              divisions: 30,
              label: '${(_backgroundVolume * 100).round()}%',
              onChanged: (v) => setState(() => _backgroundVolume = v),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _background != null ? _apply : null,
              icon: const Icon(Icons.layers),
              label: const Text('Mix & save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.label,
    required this.name,
    required this.icon,
    this.onTap,
  });

  final String label;
  final String name;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.labelMedium),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
