import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'tts_models.dart';

/// Persists the chosen TTS provider and its credentials in encrypted storage,
/// and exposes them to the UI as a [ChangeNotifier].
class TtsSettings extends ChangeNotifier {
  TtsSettings({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kProvider = 'tts_provider';
  static const _kElevenKey = 'tts_elevenlabs_key';
  static const _kAzureKey = 'tts_azure_key';
  static const _kAzureRegion = 'tts_azure_region';

  TtsProviderType _provider = TtsProviderType.elevenLabs;
  String _elevenLabsKey = '';
  String _azureKey = '';
  String _azureRegion = '';
  bool _loaded = false;

  TtsProviderType get provider => _provider;
  String get elevenLabsKey => _elevenLabsKey;
  String get azureKey => _azureKey;
  String get azureRegion => _azureRegion;
  bool get loaded => _loaded;

  /// True when the currently selected provider has the credentials it needs.
  bool get isConfigured => switch (_provider) {
    TtsProviderType.elevenLabs => _elevenLabsKey.isNotEmpty,
    TtsProviderType.azure => _azureKey.isNotEmpty && _azureRegion.isNotEmpty,
  };

  Future<void> load() async {
    try {
      _provider = TtsProviderTypeX.fromId(await _storage.read(key: _kProvider));
      _elevenLabsKey = await _storage.read(key: _kElevenKey) ?? '';
      _azureKey = await _storage.read(key: _kAzureKey) ?? '';
      _azureRegion = await _storage.read(key: _kAzureRegion) ?? '';
    } catch (_) {
      // Secure storage can throw on some devices; fall back to empty config.
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setProvider(TtsProviderType provider) async {
    _provider = provider;
    await _storage.write(key: _kProvider, value: provider.id);
    notifyListeners();
  }

  Future<void> setElevenLabsKey(String key) async {
    _elevenLabsKey = key.trim();
    await _storage.write(key: _kElevenKey, value: _elevenLabsKey);
    notifyListeners();
  }

  Future<void> setAzure({required String key, required String region}) async {
    _azureKey = key.trim();
    _azureRegion = region.trim();
    await _storage.write(key: _kAzureKey, value: _azureKey);
    await _storage.write(key: _kAzureRegion, value: _azureRegion);
    notifyListeners();
  }
}
