import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/formatting.dart';
import '../../../data/recording_store.dart';
import '../../../models/recording.dart';
import '../../../services/audio_editor.dart';
import '../widgets/tool_feedback.dart';
import '../widgets/tool_scaffold.dart';

/// Joins two or more recordings, in a user-defined order, into one clip.
class MergeTool extends StatefulWidget {
  const MergeTool({super.key});

  @override
  State<MergeTool> createState() => _MergeToolState();
}

class _MergeToolState extends State<MergeTool> {
  final List<Recording> _selected = [];
  bool _busy = false;

  void _toggle(Recording rec) {
    setState(() {
      final index = _selected.indexWhere((r) => r.fileName == rec.fileName);
      if (index == -1) {
        _selected.add(rec);
      } else {
        _selected.removeAt(index);
      }
    });
  }

  Future<void> _apply() async {
    final store = context.read<RecordingStore>();
    setState(() => _busy = true);
    try {
      final out = await store.newOutputPath(extension: 'm4a', prefix: 'merge');
      await const AudioEditor().merge(
        inputPaths: _selected.map((r) => r.path).toList(),
        outputPath: out,
      );
      final rec = await store.addProcessedFile(
        path: out,
        displayName: 'Merged (${_selected.length} clips)',
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
    final recordings = context.watch<RecordingStore>().recordings;

    return ToolScaffold(
      title: 'Merge',
      busy: _busy,
      busyLabel: 'Merging…',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              'Tap clips in the order you want them joined.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: recordings.length,
              itemBuilder: (context, index) {
                final rec = recordings[index];
                final order = _selected.indexWhere(
                  (r) => r.fileName == rec.fileName,
                );
                final isSelected = order != -1;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    foregroundColor: isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                    child: Text(isSelected ? '${order + 1}' : '—'),
                  ),
                  title: Text(
                    rec.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    rec.durationMs > 0
                        ? formatDuration(rec.duration)
                        : rec.extension,
                  ),
                  trailing: Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isSelected ? theme.colorScheme.primary : null,
                  ),
                  onTap: () => _toggle(rec),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton.icon(
                onPressed: _selected.length >= 2 ? _apply : null,
                icon: const Icon(Icons.merge),
                label: Text(
                  _selected.length >= 2
                      ? 'Merge ${_selected.length} clips'
                      : 'Select at least 2 clips',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
