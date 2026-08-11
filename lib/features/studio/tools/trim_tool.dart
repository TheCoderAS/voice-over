import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/formatting.dart';
import '../../../data/recording_store.dart';
import '../../../models/recording.dart';
import '../../../services/audio_editor.dart';
import '../widgets/tool_feedback.dart';
import '../widgets/tool_scaffold.dart';

/// Trims a recording to a selected [start, end] range.
class TrimTool extends StatefulWidget {
  const TrimTool({super.key, required this.recording});

  final Recording recording;

  @override
  State<TrimTool> createState() => _TrimToolState();
}

class _TrimToolState extends State<TrimTool> {
  final PlayerController _player = PlayerController();
  bool _prepared = false;
  bool _busy = false;
  late double _totalMs;
  late RangeValues _range;

  @override
  void initState() {
    super.initState();
    // Fall back to a nominal length until the waveform reports the real one.
    _totalMs = widget.recording.durationMs > 0
        ? widget.recording.durationMs.toDouble()
        : 1000;
    _range = RangeValues(0, _totalMs);
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      await _player.preparePlayer(
        path: widget.recording.path,
        shouldExtractWaveform: true,
      );
      final maxMs = _player.maxDuration;
      if (!mounted) return;
      setState(() {
        if (maxMs > 0) {
          _totalMs = maxMs.toDouble();
          _range = RangeValues(0, _totalMs);
        }
        _prepared = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _prepared = true);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _playSelection() async {
    if (_player.playerState.isPlaying) {
      await _player.pausePlayer();
      return;
    }
    await _player.seekTo(_range.start.round());
    await _player.startPlayer();
  }

  Future<void> _apply() async {
    final store = context.read<RecordingStore>();
    setState(() => _busy = true);
    try {
      final out = await store.newOutputPath(extension: 'm4a', prefix: 'trim');
      await const AudioEditor().trim(
        inputPath: widget.recording.path,
        start: Duration(milliseconds: _range.start.round()),
        end: Duration(milliseconds: _range.end.round()),
        outputPath: out,
      );
      final rec = await store.addProcessedFile(
        path: out,
        displayName: '${widget.recording.displayName} (trim)',
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
    final start = Duration(milliseconds: _range.start.round());
    final end = Duration(milliseconds: _range.end.round());
    final selected = end - start;

    return ToolScaffold(
      title: 'Trim',
      busy: _busy,
      busyLabel: 'Trimming…',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.recording.displayName,
              style: theme.textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              child: _prepared
                  ? AudioFileWaveforms(
                      size: Size(MediaQuery.sizeOf(context).width - 64, 100),
                      playerController: _player,
                      waveformType: WaveformType.fitWidth,
                      enableSeekGesture: false,
                      playerWaveStyle: PlayerWaveStyle(
                        fixedWaveColor: theme.colorScheme.outlineVariant,
                        liveWaveColor: theme.colorScheme.primary,
                        waveThickness: 3,
                        spacing: 5,
                      ),
                    )
                  : const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    ),
            ),
            const SizedBox(height: 24),
            RangeSlider(
              values: _range,
              min: 0,
              max: _totalMs,
              labels: RangeLabels(formatDuration(start), formatDuration(end)),
              onChanged: (values) {
                // Keep at least 100 ms selected.
                if (values.end - values.start < 100) return;
                setState(() => _range = values);
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Start  ${formatDuration(start)}'),
                Text('End  ${formatDuration(end)}'),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Selection: ${formatDuration(selected)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const Spacer(),
            StreamBuilder<PlayerState>(
              stream: _player.onPlayerStateChanged,
              initialData: _player.playerState,
              builder: (context, snapshot) {
                final playing = snapshot.data?.isPlaying ?? false;
                return OutlinedButton.icon(
                  onPressed: _prepared ? _playSelection : null,
                  icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                  label: Text(playing ? 'Pause' : 'Play from start'),
                );
              },
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _prepared ? _apply : null,
              icon: const Icon(Icons.content_cut),
              label: const Text('Trim & save'),
            ),
          ],
        ),
      ),
    );
  }
}
