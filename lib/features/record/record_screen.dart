import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;
import 'package:provider/provider.dart';

import '../../core/formatting.dart';
import '../../core/permissions.dart';
import '../../data/recording_store.dart';

/// Full-featured voice recorder: live waveform, running timer, and
/// pause / resume / stop, saving straight into the library.
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final RecorderController _controller = RecorderController();

  // AAC-LC in an .m4a container at 44.1 kHz / 128 kbps — a solid,
  // widely-compatible default for voice.
  static const RecorderSettings _settings = RecorderSettings(
    androidEncoderSettings: AndroidEncoderSettings(
      androidEncoder: AndroidEncoder.aacLc,
    ),
    sampleRate: 44100,
    bitRate: 128000,
  );

  String? _currentPath;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  RecorderState get _state => _controller.recorderState;

  Future<void> _startOrResume() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // Resuming a paused session keeps the same file.
      if (_state == RecorderState.paused) {
        await _controller.record(recorderSettings: _settings);
        return;
      }

      final result = await requestMicPermission();
      if (!mounted) return;
      if (result != MicPermissionResult.granted) {
        _showPermissionMessage(result);
        return;
      }

      final store = context.read<RecordingStore>();
      final path = await store.newRecordingPath(extension: 'm4a');
      _currentPath = path;
      await _controller.record(path: path, recorderSettings: _settings);
    } catch (e) {
      _snack('Could not start recording: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pause() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _controller.pause();
    } catch (e) {
      _snack('Could not pause: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stopAndSave() async {
    if (_busy) return;
    setState(() => _busy = true);
    final duration = _controller.elapsedDuration;
    try {
      final path = await _controller.stop();
      final savedPath = path ?? _currentPath;
      if (savedPath == null) {
        _snack('Nothing was recorded.');
        return;
      }
      if (!mounted) return;
      final store = context.read<RecordingStore>();
      final rec = await store.addRecordedFile(
        path: savedPath,
        duration: duration,
      );
      _currentPath = null;
      if (!mounted) return;
      _snack('Saved "${rec.displayName}"');
    } catch (e) {
      _snack('Could not save recording: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _discard() async {
    if (_busy) return;
    // Capture the store before any await so we don't touch context across gaps.
    final store = context.read<RecordingStore>();
    setState(() => _busy = true);
    try {
      if (_state != RecorderState.stopped) {
        await _controller.stop();
      }
      // Remove the abandoned file if it was created but never added to the
      // library.
      final path = _currentPath;
      _currentPath = null;
      if (path != null) {
        await store.deleteOrphanFile(path);
      }
      _controller.reset();
    } catch (_) {
      // best effort
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showPermissionMessage(MicPermissionResult result) {
    if (result == MicPermissionResult.permanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Microphone access is blocked in settings.'),
          action: SnackBarAction(
            label: 'Open settings',
            onPressed: openAppSettings,
          ),
        ),
      );
    } else {
      _snack('Microphone permission is needed to record.');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = _state == RecorderState.recording;
    final isPaused = _state == RecorderState.paused;
    final hasSession = isActive || isPaused;

    return Scaffold(
      appBar: AppBar(title: const Text('Record')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            children: [
              const Spacer(),
              // Live timer.
              StreamBuilder<Duration>(
                stream: _controller.onCurrentDuration,
                initialData: Duration.zero,
                builder: (context, snapshot) {
                  final elapsed = hasSession
                      ? (snapshot.data ?? Duration.zero)
                      : Duration.zero;
                  return Text(
                    formatDuration(elapsed),
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                isActive
                    ? 'Recording…'
                    : isPaused
                    ? 'Paused'
                    : 'Ready to record',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              // Live waveform.
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: AudioWaveforms(
                  size: Size(MediaQuery.sizeOf(context).width - 64, 120),
                  recorderController: _controller,
                  waveStyle: WaveStyle(
                    waveColor: theme.colorScheme.primary,
                    middleLineColor: theme.colorScheme.outlineVariant,
                    extendWaveform: true,
                    showMiddleLine: true,
                    waveThickness: 3,
                    spacing: 6,
                  ),
                ),
              ),
              const Spacer(),
              _buildControls(theme, isActive, isPaused, hasSession),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls(
    ThemeData theme,
    bool isActive,
    bool isPaused,
    bool hasSession,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Discard (only while a session exists).
        _CircleAction(
          icon: Icons.delete_outline,
          tooltip: 'Discard',
          enabled: hasSession && !_busy,
          onPressed: _discard,
          background: theme.colorScheme.surfaceContainerHighest,
          foreground: theme.colorScheme.onSurfaceVariant,
        ),
        // Primary record / pause button.
        GestureDetector(
          onTap: _busy
              ? null
              : isActive
              ? _pause
              : _startOrResume,
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              isActive ? Icons.pause : Icons.mic,
              size: 40,
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ),
        // Stop & save.
        _CircleAction(
          icon: Icons.stop,
          tooltip: 'Stop & save',
          enabled: hasSession && !_busy,
          onPressed: _stopAndSave,
          background: theme.colorScheme.errorContainer,
          foreground: theme.colorScheme.onErrorContainer,
        ),
      ],
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onPressed;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: background,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              width: 60,
              height: 60,
              child: Icon(icon, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}
