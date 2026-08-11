import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/recording_store.dart';
import '../../services/tts/tts_models.dart';
import '../../services/tts/tts_service.dart';
import '../../services/tts/tts_settings.dart';
import 'tts_settings_screen.dart';

/// Text-to-speech screen: type text, pick a voice and tone, generate audio,
/// and save it to the library.
class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> {
  final TextEditingController _text = TextEditingController();
  List<TtsVoice> _voices = const [];
  TtsVoice? _voice;
  TtsTone _tone = TtsTone.sweet;
  bool _loadingVoices = false;
  bool _busy = false;
  String? _lastConfiguredFor;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _syncVoices(TtsSettings settings) {
    // Reload the catalogue when the provider/config changes.
    final key = '${settings.provider.id}:${settings.isConfigured}';
    if (key == _lastConfiguredFor) return;
    _lastConfiguredFor = key;
    final service = TtsService(settings);
    setState(() {
      _voices = service.defaultVoices;
      _voice = _voices.isNotEmpty ? _voices.first : null;
    });
    if (settings.isConfigured) _loadVoices(settings);
  }

  Future<void> _loadVoices(TtsSettings settings) async {
    setState(() => _loadingVoices = true);
    try {
      final voices = await TtsService(settings).listVoices();
      if (!mounted) return;
      setState(() {
        _voices = voices;
        _voice = voices.firstWhere(
          (v) => v.id == _voice?.id,
          orElse: () => voices.first,
        );
      });
    } catch (_) {
      // Keep default voices on failure.
    } finally {
      if (mounted) setState(() => _loadingVoices = false);
    }
  }

  Future<void> _generate(TtsSettings settings) async {
    final voice = _voice;
    if (voice == null) return;
    final store = context.read<RecordingStore>();
    setState(() => _busy = true);
    try {
      final out = await store.newOutputPath(extension: 'mp3', prefix: 'tts');
      await TtsService(settings).synthesizeToFile(
        TtsRequest(
          text: _text.text,
          voice: voice,
          tone: _tone,
          language: voice.language,
        ),
        out,
      );
      final label = _text.text.trim();
      final name = label.length > 24 ? '${label.substring(0, 24)}…' : label;
      final rec = await store.addProcessedFile(
        path: out,
        displayName: name.isEmpty ? 'Voice' : name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Saved "${rec.displayName}" to Library')),
        );
    } catch (e) {
      if (!mounted) return;
      final message = e is TtsException ? e.message : 'Failed: $e';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TtsSettingsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<TtsSettings>();
    _syncVoices(settings);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'TTS settings',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: !settings.isConfigured
            ? _NeedsSetup(provider: settings.provider, onSetup: _openSettings)
            : AbsorbPointer(
                absorbing: _busy,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    TextField(
                      controller: _text,
                      minLines: 4,
                      maxLines: 8,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText:
                            'Type what the voice should say…\n'
                            '(Azure also accepts full <speak> SSML)',
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Voice', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    _VoiceDropdown(
                      voices: _voices,
                      value: _voice,
                      loading: _loadingVoices,
                      onChanged: (v) => setState(() => _voice = v),
                    ),
                    const SizedBox(height: 20),
                    Text('Tone', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tone in TtsTone.values)
                          ChoiceChip(
                            label: Text(tone.label),
                            selected: _tone == tone,
                            onSelected: (_) => setState(() => _tone = tone),
                          ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _generate(settings),
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.graphic_eq),
                      label: Text(_busy ? 'Generating…' : 'Generate voice'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Uses ${settings.provider.label}. Generation runs on their '
                      'servers and may use your account credits.',
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

class _VoiceDropdown extends StatelessWidget {
  const _VoiceDropdown({
    required this.voices,
    required this.value,
    required this.loading,
    required this.onChanged,
  });

  final List<TtsVoice> voices;
  final TtsVoice? value;
  final bool loading;
  final ValueChanged<TtsVoice?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<TtsVoice>(
            initialValue: value,
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: [
              for (final v in voices)
                DropdownMenuItem(
                  value: v,
                  child: Text(
                    '${v.name} · ${v.description}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: onChanged,
          ),
        ),
        if (loading)
          const Padding(
            padding: EdgeInsets.only(left: 12),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }
}

class _NeedsSetup extends StatelessWidget {
  const _NeedsSetup({required this.provider, required this.onSetup});

  final TtsProviderType provider;
  final VoidCallback onSetup;

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
              Icons.record_voice_over,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('Set up realistic TTS', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Add your ${provider.label} API key to generate natural, '
              'human-like speech. You can switch providers in settings.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onSetup,
              icon: const Icon(Icons.key),
              label: const Text('Add API key'),
            ),
          ],
        ),
      ),
    );
  }
}
