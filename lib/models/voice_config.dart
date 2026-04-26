class VoiceConfig {
  // Speech-to-text
  final String sttProvider; // openai, custom
  final String sttApiKey;
  final String sttBaseUrl;
  final String sttModel; // whisper-1 for OpenAI

  // Text-to-speech
  final String ttsProvider;
  final String ttsApiKey;
  final String ttsBaseUrl;
  final String ttsModel; // tts-1 for OpenAI
  final String ttsVoice; // alloy, echo, fable, onyx, nova, shimmer

  const VoiceConfig({
    this.sttProvider = 'openai',
    this.sttApiKey = '',
    this.sttBaseUrl = 'https://api.openai.com/v1',
    this.sttModel = 'whisper-1',
    this.ttsProvider = 'openai',
    this.ttsApiKey = '',
    this.ttsBaseUrl = 'https://api.openai.com/v1',
    this.ttsModel = 'tts-1',
    this.ttsVoice = 'alloy',
  });

  VoiceConfig copyWith({
    String? sttProvider,
    String? sttApiKey,
    String? sttBaseUrl,
    String? sttModel,
    String? ttsProvider,
    String? ttsApiKey,
    String? ttsBaseUrl,
    String? ttsModel,
    String? ttsVoice,
  }) =>
      VoiceConfig(
        sttProvider: sttProvider ?? this.sttProvider,
        sttApiKey: sttApiKey ?? this.sttApiKey,
        sttBaseUrl: sttBaseUrl ?? this.sttBaseUrl,
        sttModel: sttModel ?? this.sttModel,
        ttsProvider: ttsProvider ?? this.ttsProvider,
        ttsApiKey: ttsApiKey ?? this.ttsApiKey,
        ttsBaseUrl: ttsBaseUrl ?? this.ttsBaseUrl,
        ttsModel: ttsModel ?? this.ttsModel,
        ttsVoice: ttsVoice ?? this.ttsVoice,
      );
}
