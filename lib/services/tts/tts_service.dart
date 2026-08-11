import 'tts_models.dart';
import 'tts_providers.dart';
import 'tts_settings.dart';

/// Facade that builds the configured provider and runs synthesis / voice
/// listing. Constructed on demand from the current [TtsSettings].
class TtsService {
  const TtsService(this.settings);

  final TtsSettings settings;

  TtsProvider _provider() => switch (settings.provider) {
    TtsProviderType.elevenLabs => ElevenLabsProvider(settings.elevenLabsKey),
    TtsProviderType.azure => AzureProvider(
      apiKey: settings.azureKey,
      region: settings.azureRegion,
    ),
  };

  List<TtsVoice> get defaultVoices => _provider().defaultVoices;

  Future<List<TtsVoice>> listVoices() {
    if (!settings.isConfigured) {
      throw TtsException('Add your ${settings.provider.label} API key first.');
    }
    return _provider().listVoices();
  }

  Future<void> synthesizeToFile(TtsRequest request, String outputPath) {
    if (!settings.isConfigured) {
      throw TtsException('Add your ${settings.provider.label} API key first.');
    }
    if (request.text.trim().isEmpty) {
      throw TtsException('Enter some text to speak.');
    }
    return _provider().synthesizeToFile(request, outputPath);
  }
}
