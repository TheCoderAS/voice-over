import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/tts/tts_models.dart';
import '../../services/tts/tts_settings.dart';

/// Lets the user choose a TTS provider and enter its credentials.
class TtsSettingsScreen extends StatefulWidget {
  const TtsSettingsScreen({super.key});

  @override
  State<TtsSettingsScreen> createState() => _TtsSettingsScreenState();
}

class _TtsSettingsScreenState extends State<TtsSettingsScreen> {
  late TtsProviderType _provider;
  late final TextEditingController _elevenKey;
  late final TextEditingController _azureKey;
  late final TextEditingController _azureRegion;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final settings = context.read<TtsSettings>();
    _provider = settings.provider;
    _elevenKey = TextEditingController(text: settings.elevenLabsKey);
    _azureKey = TextEditingController(text: settings.azureKey);
    _azureRegion = TextEditingController(text: settings.azureRegion);
  }

  @override
  void dispose() {
    _elevenKey.dispose();
    _azureKey.dispose();
    _azureRegion.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final settings = context.read<TtsSettings>();
    await settings.setProvider(_provider);
    await settings.setElevenLabsKey(_elevenKey.text);
    await settings.setAzure(key: _azureKey.text, region: _azureRegion.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('TTS settings saved')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('TTS settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Provider', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<TtsProviderType>(
              segments: [
                for (final p in TtsProviderType.values)
                  ButtonSegment(value: p, label: Text(p.label)),
              ],
              selected: {_provider},
              onSelectionChanged: (s) => setState(() => _provider = s.first),
            ),
            const SizedBox(height: 24),
            if (_provider == TtsProviderType.elevenLabs) ...[
              _KeyField(
                controller: _elevenKey,
                label: 'ElevenLabs API key',
                obscure: _obscure,
                onToggle: () => setState(() => _obscure = !_obscure),
              ),
              const SizedBox(height: 8),
              _Hint(
                text:
                    'Create a key at elevenlabs.io → Profile → API Keys. '
                    'Generation uses your ElevenLabs character quota.',
              ),
            ] else ...[
              _KeyField(
                controller: _azureKey,
                label: 'Azure Speech key',
                obscure: _obscure,
                onToggle: () => setState(() => _obscure = !_obscure),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _azureRegion,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Azure region',
                  hintText: 'e.g. eastus, centralindia',
                ),
              ),
              const SizedBox(height: 8),
              _Hint(
                text:
                    'From the Azure portal → your Speech resource → '
                    'Keys and Endpoint. Region is the resource location.',
              ),
            ],
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
            const SizedBox(height: 16),
            Text(
              'Keys are stored encrypted on this device only and sent directly '
              'to the provider you choose.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyField extends StatelessWidget {
  const _KeyField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: label,
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
          onPressed: onToggle,
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
