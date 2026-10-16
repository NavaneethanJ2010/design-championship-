import 'dart:io';

/// Platform-aware endpoint configuration for LM Studio.
class LmStudioConfig {
  /// Base host or IP for Windows desktop (LM Studio running on the same machine)
  final String desktopHost;

  /// Android target LAN IP (e.g. '192.168.1.100' or '10.0.2.2' for emulator)
  final String androidHost;

  /// LM Studio default listening port (typically 1234)
  final int port;

  /// Custom model ID loaded in LM Studio (e.g. 'qwen2.5-7b-instruct', 'qwen2-7b-instruct')
  final String modelName;

  /// Request timeout duration
  final Duration timeout;

  /// Max characters per transcript chunk to fit Qwen's context window safely
  final int maxChunkChars;

  /// Character overlap between adjacent chunks to prevent cutting context across boundaries
  final int chunkOverlapChars;

  const LmStudioConfig({
    this.desktopHost = '127.0.0.1',
    this.androidHost = '10.0.2.2', // Standard emulator loopback to host; change to LAN IP on physical device
    this.port = 1234,
    this.modelName = 'qwen2.5-7b-instruct',
    this.timeout = const Duration(seconds: 120),
    this.maxChunkChars = 8000,
    this.chunkOverlapChars = 800,
  });

  /// Dynamically resolves the base URL according to the current platform.
  /// Never defaults Android to '127.0.0.1' or 'localhost'.
  String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://$androidHost:$port';
    } else {
      // Windows, macOS, Linux desktop
      return 'http://$desktopHost:$port';
    }
  }

  /// Full endpoint for OpenAI-compatible chat completions
  Uri get chatCompletionsUri => Uri.parse('$baseUrl/v1/chat/completions');

  /// Health check / models list endpoint
  Uri get modelsUri => Uri.parse('$baseUrl/v1/models');

  LmStudioConfig copyWith({
    String? desktopHost,
    String? androidHost,
    int? port,
    String? modelName,
    Duration? timeout,
    int? maxChunkChars,
    int? chunkOverlapChars,
  }) {
    return LmStudioConfig(
      desktopHost: desktopHost ?? this.desktopHost,
      androidHost: androidHost ?? this.androidHost,
      port: port ?? this.port,
      modelName: modelName ?? this.modelName,
      timeout: timeout ?? this.timeout,
      maxChunkChars: maxChunkChars ?? this.maxChunkChars,
      chunkOverlapChars: chunkOverlapChars ?? this.chunkOverlapChars,
    );
  }
}
