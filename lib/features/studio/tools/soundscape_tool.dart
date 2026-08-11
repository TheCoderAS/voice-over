import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/recording_store.dart';
import '../../../services/audio_editor.dart';
import '../widgets/tool_feedback.dart';
import '../widgets/tool_scaffold.dart';

/// Generates an atmospheric soundscape (rain, ocean, wind, noise) as a new
/// clip that can then be layered under a voice with the Mix tool.
class SoundscapeTool extends StatefulWidget {
  const SoundscapeTool({super.key});

  @override
  State<SoundscapeTool> createState() => _SoundscapeToolState();
}

class _SoundscapeToolState extends State<SoundscapeTool> {
  Ambience _ambience = Ambience.rain;
  int _seconds = 30;
  bool _busy = false;

  static const _durations = [10, 30, 60, 120];
  static const _icons = {
    Ambience.rain: Icons.water_drop,
    Ambience.ocean: Icons.waves,
    Ambience.wind: Icons.air,
    Ambience.whiteNoise: Icons.blur_on,
    Ambience.pinkNoise: Icons.grain,
    Ambience.brownNoise: Icons.spa,
  };

  Future<void> _generate() async {
    final store = context.read<RecordingStore>();
    setState(() => _busy = true);
    try {
      final out = await store.newOutputPath(
        extension: 'm4a',
        prefix: _ambience.suffix,
      );
      await const AudioEditor().generateAmbience(
        ambience: _ambience,
        duration: Duration(seconds: _seconds),
        outputPath: out,
      );
      final rec = await store.addProcessedFile(
        path: out,
        displayName: '${_ambience.label} (${_seconds}s)',
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
      title: 'Soundscape',
      busy: _busy,
      busyLabel: 'Generating…',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              'Generate an ambience, then layer it under a voice with Mix.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(16),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                for (final ambience in Ambience.values)
                  _AmbienceCard(
                    label: ambience.label,
                    icon: _icons[ambience] ?? Icons.graphic_eq,
                    selected: _ambience == ambience,
                    onTap: () => setState(() => _ambience = ambience),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text('Length', style: theme.textTheme.titleSmall),
                const SizedBox(width: 16),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      for (final s in _durations)
                        ChoiceChip(
                          label: Text('${s}s'),
                          selected: _seconds == s,
                          onSelected: (_) => setState(() => _seconds = s),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: FilledButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.graphic_eq),
                label: Text('Generate ${_ambience.label}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbienceCard extends StatelessWidget {
  const _AmbienceCard({
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
          child: Row(
            children: [
              Icon(
                icon,
                color: selected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: selected
                        ? theme.colorScheme.onPrimaryContainer
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
