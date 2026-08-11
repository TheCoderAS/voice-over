import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/recording_store.dart';
import '../../../models/recording.dart';
import '../../../services/audio_editor.dart';
import '../widgets/tool_feedback.dart';
import '../widgets/tool_scaffold.dart';

/// Applies a voice-changer preset to a recording.
class EffectsTool extends StatefulWidget {
  const EffectsTool({super.key, required this.recording});

  final Recording recording;

  @override
  State<EffectsTool> createState() => _EffectsToolState();
}

class _EffectsToolState extends State<EffectsTool> {
  bool _busy = false;

  static const _icons = {
    VoiceEffect.chipmunk: Icons.pets,
    VoiceEffect.deep: Icons.graphic_eq,
    VoiceEffect.robot: Icons.smart_toy,
    VoiceEffect.alien: Icons.blur_on,
    VoiceEffect.monster: Icons.coronavirus,
    VoiceEffect.echo: Icons.surround_sound,
    VoiceEffect.maleToFemale: Icons.female,
    VoiceEffect.femaleToMale: Icons.male,
  };

  Future<void> _apply(VoiceEffect effect) async {
    final store = context.read<RecordingStore>();
    setState(() => _busy = true);
    try {
      final out = await store.newOutputPath(extension: 'm4a', prefix: 'fx');
      await const AudioEditor().applyEffect(
        inputPath: widget.recording.path,
        effect: effect,
        outputPath: out,
      );
      final rec = await store.addProcessedFile(
        path: out,
        displayName: '${widget.recording.displayName} (${effect.suffix})',
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
      title: 'Voice effects',
      busy: _busy,
      busyLabel: 'Applying effect…',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              widget.recording.displayName,
              style: theme.textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Tap an effect to apply it and save a new clip.',
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
              childAspectRatio: 1.4,
              children: [
                for (final effect in VoiceEffect.values)
                  Card(
                    child: InkWell(
                      onTap: () => _apply(effect),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _icons[effect] ?? Icons.auto_awesome,
                              size: 32,
                              color: theme.colorScheme.primary,
                            ),
                            const Spacer(),
                            Text(
                              effect.label,
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
