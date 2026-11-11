import 'dart:convert';
import 'dart:io';

/// Backend-owned model connection settings. The API key is never serialized
/// into a response sent to the browser.
class ProviderSettings {
  const ProviderSettings({
    required this.provider,
    required this.model,
    required this.baseUrl,
    required this.apiKey,
  });

  final String provider;
  final String model;
  final String baseUrl;
  final String apiKey;

  bool get usesApi => provider != 'ollama';
  bool get hasApiKey => apiKey.isNotEmpty;
  String get displayName => switch (provider) {
        'openai' => 'OpenAI',
        'anthropic' => 'Anthropic',
        'gemini' => 'Google Gemini',
        'compatible' => 'OpenAI-compatible API',
        _ => 'Local Ollama',
      };

  Map<String, Object> toPublicJson() => {
        'provider': displayName,
        'providerId': provider,
        'model': model,
        'baseUrl': baseUrl,
        'apiKeyConfigured': hasApiKey,
      };

  static ProviderSettings load({
    required File file,
    required Map<String, String> environment,
  }) {
    Map<String, dynamic> saved = {};
    if (file.existsSync()) {
      try {
        saved = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      } on FormatException {
        throw StateError('Saved provider settings are not valid JSON.');
      }
    }
    final envProvider = environment['MODEL_PROVIDER']?.toLowerCase();
    var provider = (saved['provider'] as String?) ?? envProvider ?? 'ollama';
    if (provider == 'api') {
      provider = environment['API_BASE_URL'] != null ||
              environment['OPENAI_BASE_URL'] != null
          ? 'compatible'
          : 'openai';
    } else if (provider == 'openai-compatible') {
      provider = 'compatible';
    }
    if (!const {'ollama', 'openai', 'anthropic', 'gemini', 'compatible'}
        .contains(provider)) {
      throw StateError(
          'MODEL_PROVIDER must be ollama, openai, anthropic, gemini, or compatible.');
    }
    final usesApi = provider != 'ollama';
    final defaultModel = switch (provider) {
      'anthropic' => 'claude-sonnet-4-5',
      'gemini' => 'gemini-2.5-flash',
      'ollama' => 'qwen2.5:3b',
      _ => 'gpt-4o-mini',
    };
    final defaultUrl = switch (provider) {
      'anthropic' => 'https://api.anthropic.com/v1',
      'gemini' => 'https://generativelanguage.googleapis.com/v1beta',
      'ollama' => 'http://127.0.0.1:11434/v1',
      _ => 'https://api.openai.com/v1',
    };
    final model = (saved['model'] as String?) ??
        (provider == 'ollama'
            ? environment['LOCAL_MODEL_NAME'] ??
                environment['MODEL_NAME'] ??
                defaultModel
            : environment['API_MODEL'] ??
                environment['MODEL_NAME'] ??
                defaultModel);
    final baseUrl = (saved['baseUrl'] as String?) ??
        (provider == 'ollama'
            ? environment['LOCAL_MODEL_BASE_URL'] ?? defaultUrl
            : provider == 'anthropic'
                ? environment['ANTHROPIC_BASE_URL'] ?? defaultUrl
                : provider == 'gemini'
                    ? defaultUrl
                    : environment['API_BASE_URL'] ??
                        environment['OPENAI_BASE_URL'] ??
                        defaultUrl);
    final apiKey =
        (saved['apiKey'] as String?) ?? keyForProvider(environment, provider);
    if (usesApi && apiKey.isEmpty) {
      throw StateError(
          'This API provider requires a key in Lumi Settings or its backend environment variable.');
    }
    return ProviderSettings(
        provider: provider, model: model, baseUrl: baseUrl, apiKey: apiKey);
  }

  static String keyForProvider(
      Map<String, String> environment, String provider) {
    final names = switch (provider) {
      'anthropic' => const ['ANTHROPIC_API_KEY', 'API_KEY'],
      'gemini' => const ['GOOGLE_API_KEY', 'GEMINI_API_KEY', 'API_KEY'],
      'openai' || 'compatible' => const ['OPENAI_API_KEY', 'API_KEY'],
      _ => const <String>[],
    };
    for (final name in names) {
      final value = environment[name];
      if (value != null && value.isNotEmpty) return value;
    }
    return '';
  }

  static Future<void> save({
    required File file,
    required String provider,
    required String model,
    required String baseUrl,
    required String apiKey,
    required String existingApiKey,
  }) async {
    if (!const {'ollama', 'openai', 'anthropic', 'gemini', 'compatible'}
        .contains(provider)) {
      throw const FormatException('Choose a supported provider.');
    }
    final cleanModel = model.trim();
    final cleanUrl = baseUrl.trim();
    if (cleanModel.isEmpty || cleanModel.length > 160) {
      throw const FormatException('Enter a model name (up to 160 characters).');
    }
    final uri = Uri.tryParse(cleanUrl);
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        cleanUrl.length > 2048) {
      throw const FormatException('Enter a valid http or https model URL.');
    }
    final cleanKey = apiKey.trim().isEmpty ? existingApiKey : apiKey.trim();
    if (provider != 'ollama' && cleanKey.isEmpty) {
      throw const FormatException('An API key is required for this provider.');
    }
    if (apiKey.length > 4096) {
      throw const FormatException('API key is too long.');
    }
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.create();
    if (Platform.isLinux || Platform.isMacOS) {
      final permissions = await Process.run('chmod', ['600', temporary.path]);
      if (permissions.exitCode != 0) {
        throw const FileSystemException('Could not secure provider settings.');
      }
    }
    await temporary.writeAsString(
        jsonEncode({
          'provider': provider,
          'model': cleanModel,
          'baseUrl': cleanUrl,
          if (cleanKey.isNotEmpty && provider != 'ollama') 'apiKey': cleanKey,
        }),
        flush: true);
    await temporary.rename(file.path);
  }
}
