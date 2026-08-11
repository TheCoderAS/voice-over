import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/recording_store.dart';
import '../../../models/recording.dart';
import '../../../services/audio_editor.dart';
import '../widgets/tool_feedback.dart';
import '../widgets/tool_scaffold.dart';

/// Re-encodes a recording to a chosen format, bitrate and sample rate.
class ExportTool extends StatefulWidget {
  const ExportTool({super.key, required this.recording});

  final Recording recording;

  @override
  State<ExportTool> createState() => _ExportToolState();
}

class _ExportToolState extends State<ExportTool> {
  AudioFormat _format = AudioFormat.mp3;
  String _bitrate = '128k';
  int _sampleRate = 44100;
  bool _busy = false;

  static const _bitrates = ['128k', '192k', '256k', '320k'];
  static const _sampleRates = [22050, 44100, 48000];

  Future<void> _apply() async {
    final store = context.read<RecordingStore>();
    setState(() => _busy = true);
    try {
      final out = await store.newOutputPath(
        extension: _format.fileExtension,
        prefix: 'export',
      );
      await const AudioEditor().export(
        inputPath: widget.recording.path,
        format: _format,
        sampleRate: _sampleRate,
        bitrate: _bitrate,
        outputPath: out,
      );
      final rec = await store.addProcessedFile(
        path: out,
        displayName:
            '${widget.recording.displayName} (${_format.fileExtension})',
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
      title: 'Export / convert',
      busy: _busy,
      busyLabel: 'Exporting…',
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
            Text('Format', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final f in AudioFormat.values)
                  ChoiceChip(
                    label: Text(f.label),
                    selected: _format == f,
                    onSelected: (_) => setState(() => _format = f),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            if (_format.supportsBitrate) ...[
              Text('Bitrate', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final b in _bitrates)
                    ChoiceChip(
                      label: Text(b),
                      selected: _bitrate == b,
                      onSelected: (_) => setState(() => _bitrate = b),
                    ),
                ],
              ),
              const SizedBox(height: 24),
            ],
            Text('Sample rate', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final s in _sampleRates)
                  ChoiceChip(
                    label: Text(
                      '${(s / 1000).toStringAsFixed(s % 1000 == 0 ? 0 : 1)} kHz',
                    ),
                    selected: _sampleRate == s,
                    onSelected: (_) => setState(() => _sampleRate = s),
                  ),
              ],
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _apply,
              icon: const Icon(Icons.save_alt),
              label: Text('Export as ${_format.fileExtension.toUpperCase()}'),
            ),
          ],
        ),
      ),
    );
  }
}
