import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:http/http.dart' as http;

// --- КОНСТАНТИ ДИЗАЙНУ ---
const Color kAppBlack = Color(0xFF050505);
const Color kComponentGrey = Color(0xFF1E1E1E);
const double kBorderRadius = 24.0;

// --- ДЕФІНІЦІЇ LLM МОДЕЛЕЙ ---
class LLMFamily {
  final String name;
  final String icon;
  final List<LLMModel> models;

  LLMFamily({
    required this.name,
    required this.icon,
    required this.models,
  });
}

class LLMModel {
  final String id;
  final String displayName;
  final String family;
  final bool isAvailable;
  final String? description;

  LLMModel({
    required this.id,
    required this.displayName,
    required this.family,
    this.isAvailable = true,
    this.description,
  });
}

// АКТУАЛЬНІ МОДЕЛІ (грудень 2025)
final List<LLMFamily> LLM_FAMILIES = [
  LLMFamily(
    name: 'OpenAI',
    icon: '🤖',
    models: [
      LLMModel(
        id: 'gpt-5',
        displayName: 'GPT-5',
        family: 'OpenAI',
        description: 'Найпотужніша модель для кодування та складних завдань',
      ),
      LLMModel(
        id: 'gpt-5-mini',
        displayName: 'GPT-5 Mini',
        family: 'OpenAI',
        description: 'Швидша версія GPT-5, ціною-ефективна',
      ),
      LLMModel(
        id: 'gpt-4o',
        displayName: 'GPT-4o',
        family: 'OpenAI',
        description: 'Мультимодальна модель (текст, картинки, аудіо)',
      ),
      LLMModel(
        id: 'o3-mini',
        displayName: 'O3 Mini',
        family: 'OpenAI',
        description: 'Легка версія з розширеним розумінням',
      ),
    ],
  ),
  LLMFamily(
    name: 'Google Gemini',
    icon: '✨',
    models: [
      LLMModel(
        id: 'gemini-2.5-pro',
        displayName: 'Gemini 2.5 Pro',
        family: 'Google Gemini',
        description: 'Найпотужніша Gemini з Deep Think режимом',
      ),
      LLMModel(
        id: 'gemini-2.5-flash',
        displayName: 'Gemini 2.5 Flash',
        family: 'Google Gemini',
        description: 'Швидка та ефективна модель',
      ),
      LLMModel(
        id: 'gemini-2.5-flash-lite',
        displayName: 'Gemini 2.5 Flash-Lite',
        family: 'Google Gemini',
        description: 'Найлегша версія для швидких завдань',
      ),
    ],
  ),
  LLMFamily(
    name: 'Anthropic Claude',
    icon: '🧠',
    models: [
      LLMModel(
        id: 'claude-3-opus-latest',
        displayName: 'Claude 3 Opus',
        family: 'Anthropic Claude',
        description: 'Найпотужніша Claude для складних завдань',
      ),
      LLMModel(
        id: 'claude-3-sonnet-latest',
        displayName: 'Claude 3 Sonnet',
        family: 'Anthropic Claude',
        description: 'Збалансована модель швидкості та якості',
      ),
      LLMModel(
        id: 'claude-3-haiku-latest',
        displayName: 'Claude 3 Haiku',
        family: 'Anthropic Claude',
        description: 'Найлегша і найшвидша Claude',
      ),
    ],
  ),
];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1200, 750),
      minimumSize: Size(1000, 650),
      center: true,
      backgroundColor: kAppBlack,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: "AI Hub - Multi-LLM",
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setTitle('AI Hub - Multi-LLM');
    });
  }

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ChatProvider())],
      child: const ModernAIApp(),
    ),
  );
}

// --- КЛАС ПОВІДОМЛЕННЯ ---
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'imagePath': imagePath,
      'isFinal': isFinal,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      text: json['text'],
      isUser: json['isUser'],
      imagePath: json['imagePath'],
      isFinal: json['isFinal'] ?? true,
      timestamp:
          DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }
}

// --- КЛАС СЕСІЇ ЧАТУ ---
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
    List<ChatMessage>? messages, // 1. Прибираємо const [] звідси
  }) : messages =
            messages ?? []; // 2. Ініціалізуємо як змінний список, якщо він null

  // ... решта коду (toJson, fromJson) залишається без змін ...

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'modelUsed': modelUsed,
      'messages': messages.map((m) => m.toJson()).toList(),
    };
  }

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    final msgs = (json['messages'] as List? ?? [])
        .map((m) => ChatMessage.fromJson(m))
        .toList(); // toList() створює змінний список, тут все ок
    return ChatSession(
      id: json['id'],
      title: json['title'],
      createdAt: DateTime.parse(json['createdAt']),
      modelUsed: json['modelUsed'],
      messages: msgs,
    );
  }
}

// --- API КОНФІГУРАЦІЇ ---
class APIConfig {
  final String provider; // 'openai', 'gemini', 'claude'
  final String apiKey;
  final DateTime addedAt;

  APIConfig({
    required this.provider,
    required this.apiKey,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'provider': provider,
      'apiKey': apiKey,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  factory APIConfig.fromJson(Map<String, dynamic> json) {
    return APIConfig(
      provider: json['provider'],
      apiKey: json['apiKey'],
      addedAt: DateTime.parse(json['addedAt']),
    );
  }
}

// --- PROVIDER ---
class ChatProvider extends ChangeNotifier {
  final List<ChatSession> _chatSessions = [];
  ChatSession? _currentSession;
  final Map<String, APIConfig> _apiConfigs = {};
  String _selectedModel = 'gemini-2.5-flash';
  bool _isLoading = false;

  final ValueNotifier<String> currentStreamNotifier = ValueNotifier("");
  final StringBuffer _receiveBuffer = StringBuffer();
  String _uiText = "";
  Timer? _flushTimer;

  List<ChatSession> get chatSessions => _chatSessions;
  ChatSession? get currentSession => _currentSession;
  List<ChatMessage> get messages => _currentSession?.messages ?? [];
  String get selectedModel => _selectedModel;
  bool get isLoading => _isLoading;
  bool get hasStarted =>
      _currentSession != null && _currentSession!.messages.isNotEmpty;
  Map<String, APIConfig> get apiConfigs => _apiConfigs;
  String? get currentAPIKey {
    final family = _getModelFamily(_selectedModel);
    return _apiConfigs[family]?.apiKey;
  }

  String? get sessionPreview {
    if (_currentSession?.messages.isEmpty ?? true) return "Новий чат";
    final firstMessage = _currentSession!.messages.last;
    return firstMessage.text.length > 50
        ? "${firstMessage.text.substring(0, 50)}..."
        : firstMessage.text;
  }

  ChatProvider() {
    _loadSettingsAndHistory();
  }

  // --- УПРАВЛІННЯ СЕСІЯМИ ---
  Future<void> _loadSettingsAndHistory() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedModel = prefs.getString('selected_model') ?? 'gemini-2.5-pro';

    // Завантаження API конфігів
    final apiConfigsJson = prefs.getString('api_configs');
    if (apiConfigsJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(apiConfigsJson);
        decoded.forEach((key, value) {
          _apiConfigs[key] = APIConfig.fromJson(value);
        });
      } catch (e) {
        debugPrint("Error loading API configs: $e");
      }
    }

    // Завантаження історії сесій
    final sessionsJson = prefs.getString('chat_sessions');
    if (sessionsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(sessionsJson);
        _chatSessions.clear();
        _chatSessions.addAll(
          decoded.map((e) => ChatSession.fromJson(e)).toList(),
        );
      } catch (e) {
        debugPrint("Error loading sessions: $e");
      }
    }

    notifyListeners();
  }

  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_chatSessions.map((s) => s.toJson()).toList());
    await prefs.setString('chat_sessions', encoded);
  }

  Future<void> _saveAPIConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> toSave = {};
    _apiConfigs.forEach((key, value) {
      toSave[key] = value.toJson();
    });
    await prefs.setString('api_configs', jsonEncode(toSave));
  }

  void startNewChat() async {
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    final title = 'Chat ${_chatSessions.length + 1}';

    _currentSession = ChatSession(
      id: sessionId,
      title: title,
      createdAt: DateTime.now(),
      modelUsed: _selectedModel,
    );

    _chatSessions.insert(0, _currentSession!);
    await _saveSessions();
    notifyListeners();
  }

  Future<void> loadSession(ChatSession session) async {
    _currentSession = session;
    notifyListeners();
  }

  Future<void> deleteSession(String sessionId) async {
    _chatSessions.removeWhere((s) => s.id == sessionId);
    if (_currentSession?.id == sessionId) {
      _currentSession = null;
    }
    await _saveSessions();
    notifyListeners();
  }

  Future<void> renameSession(String sessionId, String newTitle) async {
    final session = _chatSessions.firstWhere((s) => s.id == sessionId);
    final updatedSession = ChatSession(
      id: session.id,
      title: newTitle,
      createdAt: session.createdAt,
      modelUsed: session.modelUsed,
      messages: session.messages,
    );
    final index = _chatSessions.indexWhere((s) => s.id == sessionId);
    _chatSessions[index] = updatedSession;
    if (_currentSession?.id == sessionId) {
      _currentSession = updatedSession;
    }
    await _saveSessions();
    notifyListeners();
  }

  // --- УПРАВЛІННЯ МОДЕЛЯМИ ---
  String _getModelFamily(String modelId) {
    for (final family in LLM_FAMILIES) {
      if (family.models.any((m) => m.id == modelId)) {
        return family.name;
      }
    }
    return 'Google Gemini'; // Default
  }

  void selectModel(String modelId) async {
    _selectedModel = modelId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_model', modelId);
    notifyListeners();
  }

  // --- УПРАВЛІННЯ API КЛЮЧАМИ ---
  void saveAPIKey(String provider, String apiKey) async {
    _apiConfigs[provider] = APIConfig(
      provider: provider,
      apiKey: apiKey,
    );
    await _saveAPIConfigs();
    notifyListeners();
  }

  bool hasAPIKey(String provider) {
    return _apiConfigs.containsKey(provider) &&
        _apiConfigs[provider]!.apiKey.isNotEmpty;
  }

  // --- ВІДПРАВКА ПОВІДОМЛЕННЯ ---
  Future<void> sendMessage(String text, {String? imagePath}) async {
    if (_currentSession == null) {
      startNewChat();
    }

    final apiKey = currentAPIKey;
    if (apiKey == null || apiKey.isEmpty) return;

    _receiveBuffer.clear();
    _uiText = "";
    currentStreamNotifier.value = "";
    _flushTimer?.cancel();

    final userMsg = ChatMessage(
      id: DateTime.now().toString(),
      text: text,
      isUser: true,
      imagePath: imagePath,
    );

    _currentSession!.messages.insert(0, userMsg);
    await _saveSessions();
    notifyListeners();

    _isLoading = true;
    notifyListeners();

    try {
      final aiMessage = ChatMessage(
        id: "ai_${DateTime.now().millisecondsSinceEpoch}",
        text: "",
        isUser: false,
        isFinal: false,
      );
      _currentSession!.messages.insert(0, aiMessage);
      notifyListeners();

      final family = _getModelFamily(_selectedModel);
      String responseText = "";

      if (family == 'Google Gemini') {
        responseText = await _sendGeminiMessage(text, imagePath, apiKey);
      } else if (family == 'OpenAI') {
        responseText = await _sendOpenAIMessage(text, apiKey);
      } else if (family == 'Anthropic Claude') {
        responseText = await _sendClaudeMessage(text, apiKey);
      }

      _simulateStreaming(responseText);
      await Future.delayed(const Duration(milliseconds: 500));

      aiMessage.text = _receiveBuffer.toString();
      aiMessage.isFinal = true;
      await _saveSessions();
    } catch (e) {
      _currentSession!.messages.insert(
        0,
        ChatMessage(id: "error", text: "Помилка: $e", isUser: false),
      );
      await _saveSessions();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _simulateStreaming(String fullText) {
    _receiveBuffer.clear();
    _receiveBuffer.write(fullText);
    _uiText = "";
    currentStreamNotifier.value = "";

    _flushTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (_uiText.length < fullText.length) {
        int chunk = ((fullText.length - _uiText.length) / 3).ceil();
        if (chunk < 1) chunk = 1;

        int nextLen = _uiText.length + chunk;
        if (nextLen > fullText.length) nextLen = fullText.length;

        _uiText = fullText.substring(0, nextLen);
        currentStreamNotifier.value = _uiText;
      } else {
        timer.cancel();
      }
    });
  }

  Future<String> _sendGeminiMessage(
    String text,
    String? imagePath,
    String apiKey,
  ) async {
    try {
      final model = GenerativeModel(
        model: _selectedModel,
        apiKey: apiKey,
        requestOptions: const RequestOptions(apiVersion: 'v1beta'),
      );

      List<Part> parts = [TextPart(text)];

      if (imagePath != null) {
        final file = File(imagePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final mime = imagePath.endsWith('.png') ? 'image/png' : 'image/jpeg';
          parts.add(DataPart(mime, bytes));
        }
      }

      final content = Content.multi(parts);
      final response = await model.generateContent([content]);

      if (response.text == null || response.text!.isEmpty) {
        debugPrint('Empty response from Gemini');
        return "Модель не відповіла. Спробуйте ще раз.";
      }

      return response.text!;
    } catch (e) {
      debugPrint('Gemini помилка: $e');
      throw "Gemini помилка: $e";
    }
  }

  Future<String> _sendOpenAIMessage(String text, String apiKey) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _selectedModel,
          'messages': [
            {'role': 'user', 'content': text}
          ],
          'max_tokens': 2000,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] ?? "Немає відповіді";
      } else {
        throw "OpenAI помилка: ${response.statusCode}";
      }
    } catch (e) {
      throw "OpenAI помилка: $e";
    }
  }

  Future<String> _sendClaudeMessage(String text, String apiKey) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _selectedModel,
          'max_tokens': 2000,
          'messages': [
            {'role': 'user', 'content': text}
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['content'][0]['text'] ?? "Немає відповіді";
      } else {
        throw "Claude помилка: ${response.statusCode}";
      }
    } catch (e) {
      throw "Claude помилка: $e";
    }
  }
}

// --- ГОЛОВНИЙ UI ---
class ModernAIApp extends StatelessWidget {
  const ModernAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Hub - Multi-LLM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kAppBlack,
        fontFamily: 'Roboto',
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          surface: kAppBlack,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _attachedImage;
  bool _sidebarVisible = true;
  String? _selectedFamily;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialRequirements();
    });
  }

  void _checkInitialRequirements() async {
    final provider = context.read<ChatProvider>();
    final family = provider._getModelFamily(provider.selectedModel);
    if (!provider.hasAPIKey(family)) {
      if (mounted) _showAPISettings(context);
    }
  }

  void _showAPISettings(BuildContext context) {
    final provider = context.read<ChatProvider>();
    final keyControllers = <String, TextEditingController>{};

    for (final family in LLM_FAMILIES) {
      final existing = provider.apiConfigs[family.name];
      keyControllers[family.name] =
          TextEditingController(text: existing?.apiKey ?? '');
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (ctx) => AlertDialog(
        backgroundColor: kComponentGrey,
        title: const Text("API Ключі", style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Додайте API ключі для платформ:",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ...LLM_FAMILIES.map((family) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${family.icon} ${family.name}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: keyControllers[family.name],
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "${family.name} API Key",
                          labelStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: Colors.black,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: Text(family.icon),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            child:
                const Text("Скасувати", style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child:
                const Text("Зберегти", style: TextStyle(color: Colors.white)),
            onPressed: () {
              keyControllers.forEach((provider, controller) {
                if (controller.text.trim().isNotEmpty) {
                  context
                      .read<ChatProvider>()
                      .saveAPIKey(provider, controller.text.trim());
                }
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("API ключі збережені"),
                  backgroundColor: kComponentGrey,
                  duration: Duration(seconds: 2),
                ),
              );
            },
          )
        ],
      ),
    );
  }

  Widget _buildModelSelector(BuildContext context, ChatProvider provider) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: kComponentGrey,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedFamily ?? 'Google Gemini',
              dropdownColor: kComponentGrey,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              isDense: true,
              onChanged: (String? newValue) {
                setState(() => _selectedFamily = newValue);
              },
              items: LLM_FAMILIES.map<DropdownMenuItem<String>>((family) {
                return DropdownMenuItem<String>(
                  value: family.name,
                  child: Text("${family.icon} ${family.name}"),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: kComponentGrey,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: provider.selectedModel,
              dropdownColor: kComponentGrey,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              isDense: true,
              onChanged: (String? newValue) {
                if (newValue != null && newValue != provider.selectedModel) {
                  provider.selectModel(newValue);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text("Модель: $newValue"),
                    backgroundColor: kComponentGrey,
                    duration: const Duration(seconds: 1),
                  ));
                }
              },
              items: LLM_FAMILIES
                  .firstWhere(
                      (f) => f.name == (_selectedFamily ?? 'Google Gemini'))
                  .models
                  .map<DropdownMenuItem<String>>((model) {
                return DropdownMenuItem<String>(
                  value: model.id,
                  child: Text(model.displayName),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_attachedImage != null)
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: kComponentGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.image, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                const Text("Картинка додана",
                    style: TextStyle(fontSize: 12, color: Colors.white)),
                IconButton(
                  icon: const Icon(Icons.close, size: 16, color: Colors.white),
                  onPressed: () => setState(() => _attachedImage = null),
                ),
              ],
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: kComponentGrey,
            borderRadius: BorderRadius.circular(kBorderRadius),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.grey),
                onPressed: () {
                  // Додати картинку
                },
                tooltip: "Завантажити картинку",
              ),
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "Запитайте щось...",
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 5),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_upward,
                      color: Colors.white, size: 18),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _sendMessage() async {
    final provider = context.read<ChatProvider>();
    final text = _textController.text.trim();

    if (text.isEmpty && _attachedImage == null) return;

    _textController.clear();
    final imgPath = _attachedImage;
    setState(() => _attachedImage = null);

    _focusNode.requestFocus();
    await provider.sendMessage(text, imagePath: imgPath);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();

    return Scaffold(
      body: Row(
        children: [
          // --- САЙДБАР З ІСТОРІЄЮ (з toggle) ---
          if (_sidebarVisible)
            Container(
              width: 280,
              color: kComponentGrey,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => provider.startNewChat(),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text("Новий",
                                style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.1),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_left,
                              color: Colors.grey, size: 20),
                          onPressed: () =>
                              setState(() => _sidebarVisible = false),
                          tooltip: "Сховати меню",
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: provider.chatSessions.length,
                      itemBuilder: (ctx, index) {
                        final session = provider.chatSessions[index];
                        final isActive =
                            provider.currentSession?.id == session.id;
                        final preview = session.messages.isEmpty
                            ? "Новий чат"
                            : session.messages.last.text.length > 40
                                ? "${session.messages.last.text.substring(0, 40)}..."
                                : session.messages.last.text;
                        return ListTile(
                          selected: isActive,
                          selectedTileColor: Colors.white.withOpacity(0.1),
                          title: Text(
                            session.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isActive ? Colors.white : Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                preview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey),
                              ),
                              Text(
                                session.modelUsed,
                                style: const TextStyle(
                                    fontSize: 9, color: Colors.grey),
                              ),
                            ],
                          ),
                          onTap: () => provider.loadSession(session),
                          trailing: PopupMenuButton(
                            itemBuilder: (ctx) => [
                              PopupMenuItem(
                                child: const Text("Перейменувати"),
                                onTap: () {
                                  final controller = TextEditingController(
                                      text: session.title);
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: kComponentGrey,
                                      title: const Text("Перейменувати чат",
                                          style:
                                              TextStyle(color: Colors.white)),
                                      content: TextField(
                                        controller: controller,
                                        style: const TextStyle(
                                            color: Colors.white),
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: Colors.black,
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text("Скасувати",
                                              style: TextStyle(
                                                  color: Colors.grey)),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            provider.renameSession(
                                              session.id,
                                              controller.text,
                                            );
                                            Navigator.pop(ctx);
                                          },
                                          child: const Text("Зберегти",
                                              style: TextStyle(
                                                  color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              PopupMenuItem(
                                child: const Text("Видалити"),
                                onTap: () => provider.deleteSession(session.id),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          // --- ОСНОВНА ОБЛАСТЬ ---
          Expanded(
            child: Stack(
              children: [
                Positioned(
                  top: -100,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 600,
                      height: 300,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            Colors.blueGrey.withOpacity(0.15),
                            Colors.transparent,
                          ],
                          radius: 0.6,
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        child: Row(
                          children: [
                            if (!_sidebarVisible)
                              IconButton(
                                icon: const Icon(Icons.chevron_right,
                                    color: Colors.grey, size: 20),
                                onPressed: () =>
                                    setState(() => _sidebarVisible = true),
                                tooltip: "Показати меню",
                              ),
                            Expanded(
                              child: _buildModelSelector(context, provider),
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              icon:
                                  const Icon(Icons.vpn_key, color: Colors.grey),
                              onPressed: () => _showAPISettings(context),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: provider.currentSession == null
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.chat_outlined,
                                        color: Colors.grey, size: 64),
                                    SizedBox(height: 20),
                                    Text(
                                      "Почніть новий чат",
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      "Виберіть модель та почніть розмову",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                child: ListView.builder(
                                  reverse: true,
                                  itemCount: provider.messages.length,
                                  itemBuilder: (ctx, index) {
                                    final msg = provider.messages[index];
                                    return MessageBubble(message: msg);
                                  },
                                ),
                              ),
                      ),
                      Container(
                        width: 800,
                        padding: const EdgeInsets.only(
                            left: 20, right: 20, bottom: 30),
                        child: _buildInputField(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- MESSAGE BUBBLE ---
class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser)
            const Padding(
              padding: EdgeInsets.only(right: 12.0, top: 4),
              child: CircleAvatar(
                radius: 12,
                backgroundColor: Colors.grey,
                child: Icon(Icons.smart_toy, size: 14, color: Colors.white),
              ),
            ),
          Flexible(
            child: Container(
              padding: isUser
                  ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                  : EdgeInsets.zero,
              decoration: isUser
                  ? BoxDecoration(
                      color: kComponentGrey,
                      borderRadius: BorderRadius.circular(18),
                    )
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.imagePath != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(message.imagePath!),
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  if (isUser)
                    Text(message.text,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 15))
                  else
                    message.isFinal
                        ? MarkdownBody(
                            data: message.text,
                            selectable: true,
                            styleSheet: MarkdownStyleSheet(
                              p: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                height: 1.5,
                              ),
                              code: const TextStyle(
                                backgroundColor: kComponentGrey,
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                              codeblockDecoration: BoxDecoration(
                                color: kComponentGrey,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                            ),
                          )
                        : StreamingText(text: message.text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StreamingText extends StatelessWidget {
  final String text;
  const StreamingText({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: context.read<ChatProvider>().currentStreamNotifier,
      builder: (context, streamText, child) {
        return BlockSemantics(
          blocking: true,
          child: Text(
            streamText.isEmpty ? "Думаю..." : streamText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        );
      },
    );
  }
}
