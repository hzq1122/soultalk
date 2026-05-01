import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum TtsProvider {
  openai('openai', 'OpenAI TTS'),
  azure('azure', 'Azure TTS'),
  edge('edge', 'Edge TTS'),
  elevenlabs('elevenlabs', 'ElevenLabs'),
  custom('custom', '自定义 API');

  final String id;
  final String label;
  const TtsProvider(this.id, this.label);

  String get defaultBaseUrl => switch (this) {
    TtsProvider.openai => 'https://api.openai.com/v1',
    TtsProvider.azure => 'https://REGION.api.cognitive.microsoft.com',
    TtsProvider.edge => '',
    TtsProvider.elevenlabs => 'https://api.elevenlabs.io/v1',
    TtsProvider.custom => '',
  };

  static TtsProvider fromId(String id) {
    return TtsProvider.values.firstWhere(
      (p) => p.id == id,
      orElse: () => TtsProvider.openai,
    );
  }
}

class CustomVoice {
  final String id;
  final String name;
  final String language;
  final String? providerVoiceId;

  const CustomVoice({
    required this.id,
    required this.name,
    required this.language,
    this.providerVoiceId,
  });

  CustomVoice copyWith({
    String? id,
    String? name,
    String? language,
    String? providerVoiceId,
  }) => CustomVoice(
    id: id ?? this.id,
    name: name ?? this.name,
    language: language ?? this.language,
    providerVoiceId: providerVoiceId ?? this.providerVoiceId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'language': language,
    'providerVoiceId': providerVoiceId,
  };

  factory CustomVoice.fromJson(Map<String, dynamic> json) => CustomVoice(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    language: json['language'] as String? ?? 'zh-CN',
    providerVoiceId: json['providerVoiceId'] as String?,
  );
}

class VoiceMapping {
  final String characterId;
  final String characterName;
  final String voiceId;
  final String voiceName;

  const VoiceMapping({
    required this.characterId,
    required this.characterName,
    required this.voiceId,
    required this.voiceName,
  });

  VoiceMapping copyWith({
    String? characterId,
    String? characterName,
    String? voiceId,
    String? voiceName,
  }) => VoiceMapping(
    characterId: characterId ?? this.characterId,
    characterName: characterName ?? this.characterName,
    voiceId: voiceId ?? this.voiceId,
    voiceName: voiceName ?? this.voiceName,
  );

  Map<String, dynamic> toJson() => {
    'characterId': characterId,
    'characterName': characterName,
    'voiceId': voiceId,
    'voiceName': voiceName,
  };

  factory VoiceMapping.fromJson(Map<String, dynamic> json) => VoiceMapping(
    characterId: json['characterId'] as String? ?? '',
    characterName: json['characterName'] as String? ?? '',
    voiceId: json['voiceId'] as String? ?? '',
    voiceName: json['voiceName'] as String? ?? '',
  );
}

class TtsConfig {
  final TtsProvider provider;
  final String apiKey;
  final String baseUrl;
  final String model;
  final String voice;
  final String groupId;
  final String language;
  final double speed;
  final double volume;
  final double pitch;
  final String audioFormat;
  final bool autoPlay;
  final List<CustomVoice> customVoices;
  final List<VoiceMapping> voiceMappings;

  const TtsConfig({
    this.provider = TtsProvider.openai,
    this.apiKey = '',
    this.baseUrl = 'https://api.openai.com/v1',
    this.model = 'tts-1',
    this.voice = 'alloy',
    this.groupId = '',
    this.language = 'zh-CN',
    this.speed = 1.0,
    this.volume = 1.0,
    this.pitch = 1.0,
    this.audioFormat = 'mp3',
    this.autoPlay = false,
    this.customVoices = const [],
    this.voiceMappings = const [],
  });

  TtsConfig copyWith({
    TtsProvider? provider,
    String? apiKey,
    String? baseUrl,
    String? model,
    String? voice,
    String? groupId,
    String? language,
    double? speed,
    double? volume,
    double? pitch,
    String? audioFormat,
    bool? autoPlay,
    List<CustomVoice>? customVoices,
    List<VoiceMapping>? voiceMappings,
  }) => TtsConfig(
    provider: provider ?? this.provider,
    apiKey: apiKey ?? this.apiKey,
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    voice: voice ?? this.voice,
    groupId: groupId ?? this.groupId,
    language: language ?? this.language,
    speed: speed ?? this.speed,
    volume: volume ?? this.volume,
    pitch: pitch ?? this.pitch,
    audioFormat: audioFormat ?? this.audioFormat,
    autoPlay: autoPlay ?? this.autoPlay,
    customVoices: customVoices ?? this.customVoices,
    voiceMappings: voiceMappings ?? this.voiceMappings,
  );

  String get defaultBaseUrl => provider.defaultBaseUrl;

  String? getVoiceForCharacter(String characterId) {
    final mapping = voiceMappings
        .where((m) => m.characterId == characterId)
        .toList();
    if (mapping.isNotEmpty) return mapping.first.voiceId;
    return null;
  }

  Map<String, dynamic> toJson() => {
    'provider': provider.id,
    'apiKey': apiKey,
    'baseUrl': baseUrl,
    'model': model,
    'voice': voice,
    'groupId': groupId,
    'language': language,
    'speed': speed,
    'volume': volume,
    'pitch': pitch,
    'audioFormat': audioFormat,
    'autoPlay': autoPlay,
    'customVoices': customVoices.map((v) => v.toJson()).toList(),
    'voiceMappings': voiceMappings.map((m) => m.toJson()).toList(),
  };

  factory TtsConfig.fromJson(Map<String, dynamic> json) => TtsConfig(
    provider: TtsProvider.fromId(json['provider'] as String? ?? 'openai'),
    apiKey: json['apiKey'] as String? ?? '',
    baseUrl: json['baseUrl'] as String? ?? 'https://api.openai.com/v1',
    model: json['model'] as String? ?? 'tts-1',
    voice: json['voice'] as String? ?? 'alloy',
    groupId: json['groupId'] as String? ?? '',
    language: json['language'] as String? ?? 'zh-CN',
    speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
    volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
    pitch: (json['pitch'] as num?)?.toDouble() ?? 1.0,
    audioFormat: json['audioFormat'] as String? ?? 'mp3',
    autoPlay: json['autoPlay'] as bool? ?? false,
    customVoices:
        (json['customVoices'] as List?)
            ?.map((v) => CustomVoice.fromJson(v as Map<String, dynamic>))
            .toList() ??
        [],
    voiceMappings:
        (json['voiceMappings'] as List?)
            ?.map((m) => VoiceMapping.fromJson(m as Map<String, dynamic>))
            .toList() ??
        [],
  );

  static Future<TtsConfig> load(SharedPreferences prefs) async {
    final jsonStr = prefs.getString('tts_config');
    if (jsonStr != null) {
      try {
        return TtsConfig.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
      } catch (_) {}
    }

    return TtsConfig(
      provider: TtsProvider.fromId(
        prefs.getString('voice_tts_provider') ?? 'openai',
      ),
      apiKey: prefs.getString('voice_tts_api_key') ?? '',
      baseUrl:
          prefs.getString('voice_tts_base_url') ?? 'https://api.openai.com/v1',
      model: prefs.getString('voice_tts_model') ?? 'tts-1',
      voice: prefs.getString('voice_tts_voice') ?? 'alloy',
    );
  }

  Future<void> save(SharedPreferences prefs) async {
    await prefs.setString('tts_config', jsonEncode(toJson()));
  }
}

class SttConfig {
  final String provider;
  final String apiKey;
  final String baseUrl;
  final String model;
  final String language;

  const SttConfig({
    this.provider = 'openai',
    this.apiKey = '',
    this.baseUrl = 'https://api.openai.com/v1',
    this.model = 'whisper-1',
    this.language = 'zh',
  });

  SttConfig copyWith({
    String? provider,
    String? apiKey,
    String? baseUrl,
    String? model,
    String? language,
  }) => SttConfig(
    provider: provider ?? this.provider,
    apiKey: apiKey ?? this.apiKey,
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    language: language ?? this.language,
  );

  static Future<SttConfig> load(SharedPreferences prefs) async {
    final jsonStr = prefs.getString('stt_config');
    if (jsonStr != null) {
      try {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        return SttConfig(
          provider:
              json['provider'] as String? ??
              prefs.getString('voice_stt_provider') ??
              'openai',
          apiKey:
              json['apiKey'] as String? ??
              prefs.getString('voice_stt_api_key') ??
              '',
          baseUrl:
              json['baseUrl'] as String? ??
              prefs.getString('voice_stt_base_url') ??
              'https://api.openai.com/v1',
          model:
              json['model'] as String? ??
              prefs.getString('voice_stt_model') ??
              'whisper-1',
          language: json['language'] as String? ?? 'zh',
        );
      } catch (_) {}
    }

    return SttConfig(
      provider: prefs.getString('voice_stt_provider') ?? 'openai',
      apiKey: prefs.getString('voice_stt_api_key') ?? '',
      baseUrl:
          prefs.getString('voice_stt_base_url') ?? 'https://api.openai.com/v1',
      model: prefs.getString('voice_stt_model') ?? 'whisper-1',
    );
  }

  Map<String, dynamic> toJson() => {
    'provider': provider,
    'apiKey': apiKey,
    'baseUrl': baseUrl,
    'model': model,
    'language': language,
  };

  Future<void> save(SharedPreferences prefs) async {
    await prefs.setString('stt_config', jsonEncode(toJson()));
  }
}
