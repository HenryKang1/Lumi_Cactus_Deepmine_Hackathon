/// Data model for chat messages in the Lumi app
class ChatMessage {
  final String role; // 'lumi' or 'user'
  final String text;
  final String? source; // 'on-device' or 'cloud'
  final double? latencyMs;
  final double? confidence;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.text,
    this.source,
    this.latencyMs,
    this.confidence,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isLumi => role == 'lumi';
  bool get isUser => role == 'user';
  bool get isOnDevice => source == 'on-device';
  bool get isCloud => source == 'cloud';
}
