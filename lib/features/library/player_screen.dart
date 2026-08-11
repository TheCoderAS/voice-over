import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatting.dart';
import '../../data/recording_store.dart';
import '../../models/recording.dart';

/// Playback screen for a single recording: seekable waveform, transport
/// controls, and rename / delete.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.recording});

  final Recording recording;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final PlayerController _controller = PlayerController();
  late Recording _recording;
  bool _prepared = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _recording = widget.recording;
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      await _controller.preparePlayer(
        path: _recording.path,
        shouldExtractWaveform: true,
      );
      // Loop back to the start (stopped) when playback finishes.
      await _controller.setFinishMode(finishMode: FinishMode.pause);
      if (!mounted) return;
      setState(() => _prepared = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (!_prepared) return;
    if (_controller.playerState.isPlaying) {
      await _controller.pausePlayer();
    } else {
      await _controller.startPlayer();
    }
  }

  Future<void> _rename() async {
    final controller = TextEditingController(text: _recording.displayName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename recording'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null || !mounted) return;
    final store = context.read<RecordingStore>();
    await store.rename(_recording, newName);
    if (!mounted) return;
    setState(
      () => _recording = _recording.copyWith(displayName: newName.trim()),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete recording?'),
        content: Text(
          '"${_recording.displayName}" will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final store = context.read<RecordingStore>();
    await store.delete(_recording);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_recording.displayName, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Rename',
            onPressed: _rename,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: _delete,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            children: [
              _MetaRow(recording: _recording),
              const Spacer(),
              if (_error != null)
                _ErrorState(error: _error!)
              else if (!_prepared)
                const Center(child: CircularProgressIndicator())
              else
                _buildWaveformAndControls(theme),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaveformAndControls(ThemeData theme) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.4,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          child: AudioFileWaveforms(
            size: Size(MediaQuery.sizeOf(context).width - 64, 120),
            playerController: _controller,
            waveformType: WaveformType.fitWidth,
            enableSeekGesture: true,
            playerWaveStyle: PlayerWaveStyle(
              fixedWaveColor: theme.colorScheme.outlineVariant,
              liveWaveColor: theme.colorScheme.primary,
              waveThickness: 3,
              spacing: 6,
              showSeekLine: true,
              seekLineColor: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Position / duration readout.
        StreamBuilder<int>(
          stream: _controller.onCurrentDurationChanged,
          initialData: 0,
          builder: (context, snapshot) {
            final posMs = snapshot.data ?? 0;
            final pos = Duration(milliseconds: posMs);
            final total = Duration(milliseconds: _controller.maxDuration);
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(formatDuration(pos)),
                Text(formatDuration(total)),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        // Play / pause.
        StreamBuilder<PlayerState>(
          stream: _controller.onPlayerStateChanged,
          initialData: _controller.playerState,
          builder: (context, snapshot) {
            final playing = snapshot.data?.isPlaying ?? false;
            return FloatingActionButton.large(
              onPressed: _togglePlay,
              child: Icon(playing ? Icons.pause : Icons.play_arrow, size: 40),
            );
          },
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.recording});

  final Recording recording;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = <String>[
      if (recording.extension.isNotEmpty) recording.extension,
      if (recording.durationMs > 0) formatDuration(recording.duration),
      if (recording.sizeBytes > 0) formatBytes(recording.sizeBytes),
      formatTimestamp(recording.createdAt),
    ];
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        parts.join('  •  '),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, color: theme.colorScheme.error, size: 40),
        const SizedBox(height: 12),
        Text('Could not load this audio.', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          error,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
