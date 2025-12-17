import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart'
    hide ChatSession;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_models.dart';

class ChatProvider extends ChangeNotifier {
  final List<ChatSession> _chatSessions = [];
  ChatSession? _currentSession;
  final Map<String, APIConfig> _apiConfigs = {};
  String _selectedModel = 'gemini-2.5-flash';
  bool _isLoading = false;
  Timer? _flushTimer;

  List<ChatSession> get chatSessions => _chatSessions;
  ChatSession? get currentSession => _currentSession;
  List<ChatMessage> get messages => _currentSession?.messages ?? [];
  String get selectedModel => _selectedModel;
  bool get isLoading => _isLoading;
  Map<String, APIConfig> get apiConfigs => _apiConfigs;

  String? get currentAPIKey {
    final family = _getModelFamily(_selectedModel);
    return _apiConfigs[family]?.apiKey;
  }

  ChatProvider() {
    _loadSettingsAndHistory();
  }

  Future<void> _loadSettingsAndHistory() async {
    final prefs = await SharedPreferences.getInstance();
    String? loadedModel = prefs.getString('selected_model');
    bool modelExists = false;
    if (loadedModel != null) {
      for (var family in LLM_FAMILIES) {
        if (family.models.any((m) => m.id == loadedModel)) {
          modelExists = true;
          break;
        }
      }
    }
    _selectedModel = modelExists ? loadedModel! : LLM_FAMILIES[0].models[2].id;
    final apiConfigsJson = prefs.getString('api_configs');
    if (apiConfigsJson != null) {
      final Map<String, dynamic> decoded = jsonDecode(apiConfigsJson);
      decoded.forEach(
          (key, value) => _apiConfigs[key] = APIConfig.fromJson(value));
    }
    final sessionsJson = prefs.getString('chat_sessions');
    if (sessionsJson != null) {
      final List<dynamic> decoded = jsonDecode(sessionsJson);
      _chatSessions
          .addAll(decoded.map((e) => ChatSession.fromJson(e)).toList());
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
    _apiConfigs.forEach((key, value) => toSave[key] = value.toJson());
    await prefs.setString('api_configs', jsonEncode(toSave));
  }

  void startNewChat() async {
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _currentSession = ChatSession(
        id: sessionId,
        title: 'New Process',
        createdAt: DateTime.now(),
        modelUsed: _selectedModel);
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
    if (_currentSession?.id == sessionId) _currentSession = null;
    await _saveSessions();
    notifyListeners();
  }

  String getModelFamily(String modelId) => _getModelFamily(modelId);

  String _getModelFamily(String modelId) {
    for (final family in LLM_FAMILIES) {
      if (family.models.any((m) => m.id == modelId)) return family.name;
    }
    return 'Google';
  }

  void selectModel(String modelId) async {
    _selectedModel = modelId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_model', modelId);
    notifyListeners();
  }

  void saveAPIKey(String provider, String apiKey) async {
    _apiConfigs[provider] = APIConfig(provider: provider, apiKey: apiKey);
    await _saveAPIConfigs();
    notifyListeners();
  }

  Future<void> sendMessage(String text, {String? imagePath}) async {
    if (_currentSession == null) startNewChat();
    final apiKey = currentAPIKey;
    if (apiKey == null || apiKey.isEmpty) {
      _currentSession!.messages.insert(
          0,
          ChatMessage(
              id: DateTime.now().toString(),
              text:
                  "SYSTEM ERROR: API Key missing for ${_getModelFamily(_selectedModel)}.",
              isUser: false));
      notifyListeners();
      return;
    }

    _flushTimer?.cancel();
    _currentSession!.messages.insert(
        0,
        ChatMessage(
            id: DateTime.now().toString(),
            text: text,
            isUser: true,
            imagePath: imagePath));

    if (_currentSession!.messages.length == 1) {
      final index =
          _chatSessions.indexWhere((s) => s.id == _currentSession!.id);
      if (index != -1) {
        _chatSessions[index] = ChatSession(
            id: _currentSession!.id,
            title: text.length > 30 ? "${text.substring(0, 30)}..." : text,
            createdAt: _currentSession!.createdAt,
            modelUsed: _currentSession!.modelUsed,
            messages: _currentSession!.messages);
        _currentSession = _chatSessions[index];
      }
    }
    await _saveSessions();
    _isLoading = true;
    notifyListeners();

    try {
      final aiMessage = ChatMessage(
          id: "ai_${DateTime.now().millisecondsSinceEpoch}",
          text: "...",
          isUser: false,
          isFinal: false);
      _currentSession!.messages.insert(0, aiMessage);
      notifyListeners();

      final family = _getModelFamily(_selectedModel);
      String responseText = "";
      if (family == 'Google') {
        responseText = await _sendGeminiMessage(text, imagePath, apiKey);
      } else if (family == 'OpenAI') {
        responseText = await _sendOpenAIMessage(text, apiKey);
      } else if (family == 'Claude') {
        responseText = await _sendClaudeMessage(text, apiKey);
      }

      await _animateText(aiMessage, responseText);

      aiMessage.isFinal = true;
      await _saveSessions();
    } catch (e) {
      _currentSession!.messages.insert(
          0, ChatMessage(id: "error", text: "SYSTEM ERROR: $e", isUser: false));
      await _saveSessions();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _animateText(ChatMessage message, String fullText) async {
    message.text = "";
    int index = 0;
    Completer<void> completer = Completer<void>();
    _flushTimer = Timer.periodic(const Duration(milliseconds: 5), (timer) {
      if (index < fullText.length) {
        int chunk = (fullText.length > 500) ? 5 : 2;
        if (index + chunk > fullText.length) chunk = fullText.length - index;
        message.text += fullText.substring(index, index + chunk);
        index += chunk;
        notifyListeners();
      } else {
        timer.cancel();
        completer.complete();
      }
    });
    return completer.future;
  }

  Future<String> _sendGeminiMessage(
      String text, String? imagePath, String apiKey) async {
    final model = GenerativeModel(model: _selectedModel, apiKey: apiKey);
    List<Part> parts = [TextPart(text)];
    if (imagePath != null) {
      final file = File(imagePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        parts.add(DataPart(
            imagePath.toLowerCase().endsWith('.png')
                ? 'image/png'
                : 'image/jpeg',
            bytes));
      }
    }
    final response = await model.generateContent([Content.multi(parts)]);
    return response.text ?? "No data.";
  }

  Future<String> _sendOpenAIMessage(String text, String apiKey) async {
    final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({
          'model': _selectedModel,
          'messages': [
            {'role': 'user', 'content': text}
          ]
        }));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))['choices'][0]
          ['message']['content'];
    }
    throw "Status ${response.statusCode}: ${response.body}";
  }

  Future<String> _sendClaudeMessage(String text, String apiKey) async {
    final response =
        await http.post(Uri.parse('https://api.anthropic.com/v1/messages'),
            headers: {
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
              'Content-Type': 'application/json'
            },
            body: jsonEncode({
              'model': _selectedModel,
              'max_tokens': 4096,
              'messages': [
                {'role': 'user', 'content': text}
              ]
            }));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))['content'][0]['text'];
    }
    throw "Status ${response.statusCode}: ${response.body}";
  }
}
