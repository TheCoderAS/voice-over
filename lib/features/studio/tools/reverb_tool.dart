import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/recording_store.dart';
import '../../../models/recording.dart';
import '../../../services/audio_editor.dart';
import '../widgets/tool_feedback.dart';
import '../widgets/tool_scaffold.dart';

/// Applies a reverb space preset.
class ReverbTool extends StatefulWidget {
  const ReverbTool({super.key, required this.recording});

  final Recording recording;

  @override
  State<ReverbTool> createState() => _ReverbToolState();
}

class _ReverbToolState extends State<ReverbTool> {
  ReverbPreset _preset = ReverbPreset.room;
  bool _busy = false;

  static const _icons = {
    ReverbPreset.room: Icons.meeting_room,
    ReverbPreset.studio: Icons.headphones,
    ReverbPreset.hall: Icons.account_balance,
    ReverbPreset.cave: Icons.terrain,
  };

  Future<void> _apply() async {
    final store = context.read<RecordingStore>();
    setState(() => _busy = true);
    try {
      final out = await store.newOutputPath(extension: 'm4a', prefix: 'reverb');
      await const AudioEditor().reverb(
        inputPath: widget.recording.path,
        preset: _preset,
        outputPath: out,
      );
      final rec = await store.addProcessedFile(
        path: out,
        displayName:
            '${widget.recording.displayName} (${_preset.label.toLowerCase()})',
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
      title: 'Reverb',
      busy: _busy,
      busyLabel: 'Applying reverb…',
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
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: [
                  for (final preset in ReverbPreset.values)
                    _PresetCard(
                      label: preset.label,
                      icon: _icons[preset] ?? Icons.graphic_eq,
                      selected: _preset == preset,
                      onTap: () => setState(() => _preset = preset),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _apply,
              icon: const Icon(Icons.surround_sound),
              label: Text('Apply ${_preset.label} & save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 32,
                color: selected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.primary,
              ),
              const Spacer(),
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: selected ? theme.colorScheme.onPrimaryContainer : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
