import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatting.dart';
import '../../data/recording_store.dart';
import '../../models/recording.dart';
import 'player_screen.dart';

/// Lists every recording in the library and offers import from device storage.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  Future<void> _import(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final store = context.read<RecordingStore>();
    try {
      final result = await FilePicker.pickFiles(type: FileType.audio);
      final path = result?.files.single.path;
      if (path == null) return;
      final rec = await store.importFrom(path);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Imported "${rec.displayName}"')),
        );
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Could not import: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Import audio',
            onPressed: () => _import(context),
          ),
        ],
      ),
      body: Consumer<RecordingStore>(
        builder: (context, store, _) {
          if (store.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (store.recordings.isEmpty) {
            return _EmptyState(onImport: () => _import(context));
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: store.recordings.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              final rec = store.recordings[index];
              return _RecordingTile(recording: rec);
            },
          );
        },
      ),
    );
  }
}

class _RecordingTile extends StatelessWidget {
  const _RecordingTile({required this.recording});

  final Recording recording;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleParts = <String>[
      if (recording.durationMs > 0) formatDuration(recording.duration),
      formatTimestamp(recording.createdAt),
    ];
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        child: const Icon(Icons.graphic_eq),
      ),
      title: Text(
        recording.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(subtitleParts.join('  •  ')),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PlayerScreen(recording: recording)),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.library_music_outlined,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('No recordings yet', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Record from the Record tab, or import an audio file from your '
              'device.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('Import audio'),
            ),
          ],
        ),
      ),
    );
  }
}
