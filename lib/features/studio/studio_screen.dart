import 'package:flutter/material.dart';

import '../../models/recording.dart';
import 'tools/effects_tool.dart';
import 'tools/equalizer_tool.dart';
import 'tools/export_tool.dart';
import 'tools/fade_tool.dart';
import 'tools/merge_tool.dart';
import 'tools/mix_tool.dart';
import 'tools/one_shot_tool.dart';
import 'tools/pitch_tool.dart';
import 'tools/reverb_tool.dart';
import 'tools/soundscape_tool.dart';
import 'tools/speed_tool.dart';
import 'tools/trim_tool.dart';
import 'tools/volume_tool.dart';
import 'widgets/recording_picker.dart';

/// Studio landing: a grid of editing tools. Tools that act on one clip prompt
/// for a recording first; Merge selects several inside its own screen.
class StudioScreen extends StatelessWidget {
  const StudioScreen({super.key});

  Future<void> _openForRecording(
    BuildContext context,
    Widget Function(Recording) builder,
  ) async {
    final rec = await pickRecording(context);
    if (rec == null || !context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => builder(rec)));
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final tools = <_ToolCard>[
      _ToolCard(
        icon: Icons.content_cut,
        label: 'Trim',
        description: 'Cut to a selection',
        onTap: () => _openForRecording(context, (r) => TrimTool(recording: r)),
      ),
      _ToolCard(
        icon: Icons.auto_awesome,
        label: 'Effects',
        description: 'Robot, alien, deep…',
        onTap: () =>
            _openForRecording(context, (r) => EffectsTool(recording: r)),
      ),
      _ToolCard(
        icon: Icons.tune,
        label: 'Pitch',
        description: 'Shift up / down',
        onTap: () => _openForRecording(context, (r) => PitchTool(recording: r)),
      ),
      _ToolCard(
        icon: Icons.speed,
        label: 'Speed',
        description: 'Faster / slower',
        onTap: () => _openForRecording(context, (r) => SpeedTool(recording: r)),
      ),
      _ToolCard(
        icon: Icons.merge,
        label: 'Merge',
        description: 'Join clips together',
        onTap: () => _open(context, const MergeTool()),
      ),
      _ToolCard(
        icon: Icons.gradient,
        label: 'Fade',
        description: 'Fade in / out',
        onTap: () => _openForRecording(context, (r) => FadeTool(recording: r)),
      ),
      _ToolCard(
        icon: Icons.layers,
        label: 'Mix',
        description: 'Add background music',
        onTap: () => _openForRecording(context, (r) => MixTool(voice: r)),
      ),
      _ToolCard(
        icon: Icons.volume_up,
        label: 'Volume',
        description: 'Louder or quieter',
        onTap: () =>
            _openForRecording(context, (r) => VolumeTool(recording: r)),
      ),
      _ToolCard(
        icon: Icons.cleaning_services,
        label: 'Denoise',
        description: 'Reduce background noise',
        onTap: () => _openForRecording(
          context,
          (r) => OneShotTool(
            recording: r,
            title: 'Noise reduction',
            description:
                'Removes steady background noise like fan, hum, or hiss.',
            busyLabel: 'Cleaning up…',
            buttonLabel: 'Reduce noise & save',
            icon: Icons.cleaning_services,
            suffix: 'denoise',
            run: (editor, input, output) =>
                editor.reduceNoise(inputPath: input, outputPath: output),
          ),
        ),
      ),
      _ToolCard(
        icon: Icons.equalizer,
        label: 'Equalizer',
        description: 'Bass & treble',
        onTap: () =>
            _openForRecording(context, (r) => EqualizerTool(recording: r)),
      ),
      _ToolCard(
        icon: Icons.surround_sound,
        label: 'Reverb',
        description: 'Room, hall, cave…',
        onTap: () =>
            _openForRecording(context, (r) => ReverbTool(recording: r)),
      ),
      _ToolCard(
        icon: Icons.equalizer_rounded,
        label: 'Normalize',
        description: 'Balance loudness',
        onTap: () => _openForRecording(
          context,
          (r) => OneShotTool(
            recording: r,
            title: 'Normalize',
            description: 'Balances the overall loudness to a consistent level.',
            busyLabel: 'Normalizing…',
            buttonLabel: 'Normalize & save',
            icon: Icons.equalizer_rounded,
            suffix: 'normalized',
            run: (editor, input, output) =>
                editor.normalize(inputPath: input, outputPath: output),
          ),
        ),
      ),
      _ToolCard(
        icon: Icons.landscape,
        label: 'Soundscape',
        description: 'Rain, ocean, wind…',
        onTap: () => _open(context, const SoundscapeTool()),
      ),
      _ToolCard(
        icon: Icons.save_alt,
        label: 'Export',
        description: 'Convert format & quality',
        onTap: () =>
            _openForRecording(context, (r) => ExportTool(recording: r)),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Studio')),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.1,
        children: tools,
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 36, color: theme.colorScheme.primary),
              const Spacer(),
              Text(label, style: theme.textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
