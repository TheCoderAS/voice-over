import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/formatting.dart';
import '../../../data/recording_store.dart';
import '../../../models/recording.dart';

/// Presents a bottom sheet to choose one recording from the library.
/// Returns the selection, or null if dismissed.
Future<Recording?> pickRecording(
  BuildContext context, {
  String title = 'Choose a recording',
  bool Function(Recording)? enabledWhere,
}) {
  return showModalBottomSheet<Recording>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final recordings = context.read<RecordingStore>().recordings;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              Expanded(
                child: recordings.isEmpty
                    ? const Center(child: Text('No recordings yet.'))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: recordings.length,
                        itemBuilder: (context, index) {
                          final rec = recordings[index];
                          final enabled = enabledWhere?.call(rec) ?? true;
                          return ListTile(
                            enabled: enabled,
                            leading: const Icon(Icons.graphic_eq),
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
                            onTap: enabled
                                ? () => Navigator.pop(context, rec)
                                : null,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      );
    },
  );
}
