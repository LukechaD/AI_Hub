class LLMFamily {
  final String name;
  final String icon;
  final List<LLMModel> models;
  LLMFamily({required this.name, required this.icon, required this.models});
}

class LLMModel {
  final String id;
  final String displayName;
  final String family;
  LLMModel({required this.id, required this.displayName, required this.family});
}

final List<LLMFamily> LLM_FAMILIES = [
  LLMFamily(
    name: 'Google',
    icon: 'G',
    models: [
      LLMModel(
          id: 'gemini-3-pro-preview',
          displayName: 'Gemini 3 Pro',
          family: 'Google'),
      LLMModel(
          id: 'gemini-2.5-pro',
          displayName: 'Gemini 2.5 Pro',
          family: 'Google'),
      LLMModel(
          id: 'gemini-2.5-flash',
          displayName: 'Gemini 2.5 Flash',
          family: 'Google'),
    ],
  ),
  LLMFamily(
    name: 'OpenAI',
    icon: 'O',
    models: [
      LLMModel(id: 'gpt-5.2-pro', displayName: 'GPT-5.2 Pro', family: 'OpenAI'),
      LLMModel(id: 'gpt-5.2', displayName: 'GPT-5.2', family: 'OpenAI'),
      LLMModel(id: 'gpt-4o', displayName: 'GPT-4o', family: 'OpenAI'),
    ],
  ),
  LLMFamily(
    name: 'Claude',
    icon: 'C',
    models: [
      LLMModel(
          id: 'claude-3-5-sonnet-20241022',
          displayName: 'Claude 3.5 Sonnet',
          family: 'Claude'),
    ],
  ),
];

class ChatMessage {
  final String id;
  String text;
  final bool isUser;
  final String? imagePath;
  bool isFinal;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    this.imagePath,
    this.isFinal = true,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'isUser': isUser,
        'imagePath': imagePath,
        'isFinal': isFinal,
        'timestamp': timestamp.toIso8601String()
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
      id: json['id'],
      text: json['text'],
      isUser: json['isUser'],
      imagePath: json['imagePath'],
      isFinal: json['isFinal'] ?? true,
      timestamp: DateTime.parse(json['timestamp']));
}

class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final String modelUsed;
  final List<ChatMessage> messages;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.modelUsed,
    List<ChatMessage>? messages,
  }) : messages = messages ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'modelUsed': modelUsed,
        'messages': messages.map((m) => m.toJson()).toList()
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
      id: json['id'],
      title: json['title'],
      createdAt: DateTime.parse(json['createdAt']),
      modelUsed: json['modelUsed'],
      messages: (json['messages'] as List? ?? [])
          .map((m) => ChatMessage.fromJson(m))
          .toList());
}

class APIConfig {
  final String provider;
  final String apiKey;
  APIConfig({required this.provider, required this.apiKey});
  Map<String, dynamic> toJson() => {'provider': provider, 'apiKey': apiKey};
  factory APIConfig.fromJson(Map<String, dynamic> json) =>
      APIConfig(provider: json['provider'], apiKey: json['apiKey']);
}
