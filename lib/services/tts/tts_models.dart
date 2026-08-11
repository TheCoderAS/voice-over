/// Which cloud TTS backend to use.
enum TtsProviderType { elevenLabs, azure }

extension TtsProviderTypeX on TtsProviderType {
  String get label => switch (this) {
    TtsProviderType.elevenLabs => 'ElevenLabs',
    TtsProviderType.azure => 'Azure Neural',
  };

  String get id => switch (this) {
    TtsProviderType.elevenLabs => 'elevenlabs',
    TtsProviderType.azure => 'azure',
  };

  static TtsProviderType fromId(String? id) => TtsProviderType.values
      .firstWhere((p) => p.id == id, orElse: () => TtsProviderType.elevenLabs);
}

/// A selectable voice from a provider's catalogue.
class TtsVoice {
  const TtsVoice({
    required this.id,
    required this.name,
    required this.description,
    this.language = '',
  });

  /// Provider voice id (ElevenLabs voice_id, or Azure ShortName).
  final String id;
  final String name;
  final String description;
  final String language;
}

/// Emotional tone / delivery style. Applied per provider (ElevenLabs voice
/// settings; Azure `<mstts:express-as>` style where available).
enum TtsTone { sweet, polite, friendly, professional, storyteller, calm }

extension TtsToneX on TtsTone {
  String get label => switch (this) {
    TtsTone.sweet => 'Sweet',
    TtsTone.polite => 'Polite',
    TtsTone.friendly => 'Friendly',
    TtsTone.professional => 'Professional',
    TtsTone.storyteller => 'Storyteller',
    TtsTone.calm => 'Calm',
  };

  /// Azure `<mstts:express-as style="...">` value (empty = no style tag).
  String get azureStyle => switch (this) {
    TtsTone.sweet => 'gentle',
    TtsTone.polite => 'gentle',
    TtsTone.friendly => 'friendly',
    TtsTone.professional => 'newscast',
    TtsTone.storyteller => 'narration-professional',
    TtsTone.calm => 'calm',
  };

  /// ElevenLabs voice settings tuning for this tone: (stability, style).
  ({double stability, double style}) get elevenSettings => switch (this) {
    TtsTone.sweet => (stability: 0.45, style: 0.35),
    TtsTone.polite => (stability: 0.55, style: 0.2),
    TtsTone.friendly => (stability: 0.4, style: 0.45),
    TtsTone.professional => (stability: 0.7, style: 0.1),
    TtsTone.storyteller => (stability: 0.35, style: 0.6),
    TtsTone.calm => (stability: 0.75, style: 0.15),
  };
}

/// A synthesis request.
class TtsRequest {
  const TtsRequest({
    required this.text,
    required this.voice,
    required this.tone,
    this.language = '',
  });

  final String text;
  final TtsVoice voice;
  final TtsTone tone;
  final String language;
}

/// Thrown when synthesis fails; [message] is safe to show to the user.
class TtsException implements Exception {
  TtsException(this.message);
  final String message;
  @override
  String toString() => 'TtsException: $message';
}
