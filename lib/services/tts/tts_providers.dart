import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'tts_models.dart';

/// A cloud TTS backend.
abstract class TtsProvider {
  /// Curated voices shown immediately, before (or instead of) a live catalogue.
  List<TtsVoice> get defaultVoices;

  /// Fetches the account's full voice list; falls back to [defaultVoices].
  Future<List<TtsVoice>> listVoices();

  /// Synthesizes [request] and writes the audio to [outputPath].
  Future<void> synthesizeToFile(TtsRequest request, String outputPath);
}

/// ElevenLabs (https://elevenlabs.io) — strong natural, expressive voices.
class ElevenLabsProvider implements TtsProvider {
  ElevenLabsProvider(this.apiKey);

  final String apiKey;
  static const _base = 'https://api.elevenlabs.io/v1';
  static const _model = 'eleven_multilingual_v2';

  @override
  List<TtsVoice> get defaultVoices => const [
    TtsVoice(
      id: 'EXAVITQu4vr4xnSDxMaL',
      name: 'Bella',
      description: 'Sweet female',
    ),
    TtsVoice(
      id: '21m00Tcm4TlvDq8ikWAM',
      name: 'Rachel',
      description: 'Calm female',
    ),
    TtsVoice(
      id: 'MF3mGyEYCl7XYWbV9V6O',
      name: 'Elli',
      description: 'Young female',
    ),
    TtsVoice(
      id: 'ErXwobaYiN019PkySvjV',
      name: 'Antoni',
      description: 'Gentle male',
    ),
    TtsVoice(
      id: 'pNInz6obpgDQGcFmaJgB',
      name: 'Adam',
      description: 'Deep male',
    ),
    TtsVoice(
      id: 'TxGEqnHWrfWFTfGW9XjX',
      name: 'Josh',
      description: 'Warm male',
    ),
  ];

  Map<String, String> get _headers => {
    'xi-api-key': apiKey,
    'accept': 'application/json',
  };

  @override
  Future<List<TtsVoice>> listVoices() async {
    try {
      final res = await http
          .get(Uri.parse('$_base/voices'), headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return defaultVoices;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final voices = (data['voices'] as List?) ?? [];
      final parsed = voices.map((v) {
        final m = v as Map<String, dynamic>;
        final labels = (m['labels'] as Map?) ?? {};
        final desc = [
          labels['gender'],
          labels['accent'],
          labels['description'],
        ].where((e) => e != null && '$e'.isNotEmpty).join(', ');
        return TtsVoice(
          id: m['voice_id'] as String,
          name: (m['name'] as String?) ?? 'Voice',
          description: desc.isEmpty ? 'Voice' : desc,
        );
      }).toList();
      return parsed.isEmpty ? defaultVoices : parsed;
    } catch (_) {
      return defaultVoices;
    }
  }

  @override
  Future<void> synthesizeToFile(TtsRequest request, String outputPath) async {
    final settings = request.tone.elevenSettings;
    final body = jsonEncode({
      'text': request.text,
      'model_id': _model,
      'voice_settings': {
        'stability': settings.stability,
        'similarity_boost': 0.75,
        'style': settings.style,
        'use_speaker_boost': true,
      },
    });
    http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('$_base/text-to-speech/${request.voice.id}'),
            headers: {..._headers, 'content-type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 60));
    } catch (e) {
      throw TtsException('Network error contacting ElevenLabs: $e');
    }
    if (res.statusCode == 401) {
      throw TtsException('ElevenLabs rejected the API key (401).');
    }
    if (res.statusCode != 200) {
      throw TtsException(
        'ElevenLabs error ${res.statusCode}: ${_short(res.body)}',
      );
    }
    await File(outputPath).writeAsBytes(res.bodyBytes);
  }

  static String _short(String s) => s.length > 200 ? s.substring(0, 200) : s;
}

/// Azure Cognitive Services Neural TTS — SSML support, many languages/accents.
class AzureProvider implements TtsProvider {
  AzureProvider({required this.apiKey, required this.region});

  final String apiKey;
  final String region;

  String get _endpoint =>
      'https://$region.tts.speech.microsoft.com/cognitiveservices/v1';
  String get _voicesEndpoint =>
      'https://$region.tts.speech.microsoft.com/cognitiveservices/voices/list';

  @override
  List<TtsVoice> get defaultVoices => const [
    TtsVoice(
      id: 'en-US-JennyNeural',
      name: 'Jenny',
      description: 'US English female',
      language: 'en-US',
    ),
    TtsVoice(
      id: 'en-US-GuyNeural',
      name: 'Guy',
      description: 'US English male',
      language: 'en-US',
    ),
    TtsVoice(
      id: 'en-IN-NeerjaNeural',
      name: 'Neerja',
      description: 'Indian English female',
      language: 'en-IN',
    ),
    TtsVoice(
      id: 'en-IN-PrabhatNeural',
      name: 'Prabhat',
      description: 'Indian English male',
      language: 'en-IN',
    ),
    TtsVoice(
      id: 'en-GB-SoniaNeural',
      name: 'Sonia',
      description: 'UK English female',
      language: 'en-GB',
    ),
    TtsVoice(
      id: 'hi-IN-SwaraNeural',
      name: 'Swara',
      description: 'Hindi female',
      language: 'hi-IN',
    ),
    TtsVoice(
      id: 'hi-IN-MadhurNeural',
      name: 'Madhur',
      description: 'Hindi male',
      language: 'hi-IN',
    ),
  ];

  @override
  Future<List<TtsVoice>> listVoices() async {
    try {
      final res = await http
          .get(
            Uri.parse(_voicesEndpoint),
            headers: {'Ocp-Apim-Subscription-Key': apiKey},
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return defaultVoices;
      final list = (jsonDecode(res.body) as List)
          .whereType<Map<String, dynamic>>()
          // Keep English + Hindi to stay manageable.
          .where((m) {
            final locale = '${m['Locale']}';
            return locale.startsWith('en-') || locale.startsWith('hi-');
          })
          .map(
            (m) => TtsVoice(
              id: '${m['ShortName']}',
              name: '${m['LocalName']}',
              description: '${m['Locale']} ${m['Gender']}',
              language: '${m['Locale']}',
            ),
          )
          .toList();
      return list.isEmpty ? defaultVoices : list;
    } catch (_) {
      return defaultVoices;
    }
  }

  @override
  Future<void> synthesizeToFile(TtsRequest request, String outputPath) async {
    final ssml = _buildSsml(request);
    http.Response res;
    try {
      res = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Ocp-Apim-Subscription-Key': apiKey,
              'Content-Type': 'application/ssml+xml',
              'X-Microsoft-OutputFormat': 'audio-24khz-48kbitrate-mono-mp3',
              'User-Agent': 'VoiceOver',
            },
            body: ssml,
          )
          .timeout(const Duration(seconds: 60));
    } catch (e) {
      throw TtsException('Network error contacting Azure: $e');
    }
    if (res.statusCode == 401) {
      throw TtsException('Azure rejected the key/region (401).');
    }
    if (res.statusCode != 200) {
      throw TtsException('Azure error ${res.statusCode}: ${_short(res.body)}');
    }
    await File(outputPath).writeAsBytes(res.bodyBytes);
  }

  /// Wraps plain text in SSML with the voice and tone style. If the user
  /// already provided full SSML (`<speak>…`), it is sent as-is.
  String _buildSsml(TtsRequest request) {
    final trimmed = request.text.trim();
    if (trimmed.startsWith('<speak')) return trimmed;
    final locale = request.voice.language.isNotEmpty
        ? request.voice.language
        : 'en-US';
    final style = request.tone.azureStyle;
    final escaped = _escape(trimmed);
    final inner = style.isEmpty
        ? escaped
        : '<mstts:express-as style="$style">$escaped</mstts:express-as>';
    return '<speak version="1.0" '
        'xmlns="http://www.w3.org/2001/10/synthesis" '
        'xmlns:mstts="https://www.w3.org/2001/mstts" '
        'xml:lang="$locale">'
        '<voice name="${request.voice.id}">$inner</voice>'
        '</speak>';
  }

  static String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  static String _short(String s) => s.length > 200 ? s.substring(0, 200) : s;
}
