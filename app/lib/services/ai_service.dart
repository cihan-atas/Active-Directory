import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/quiz_models.dart';

enum AiProvider {
  gemini('Google Gemini', 'https://aistudio.google.com/app/apikey', 'AIza / AQ.'),
  groq('Groq Cloud', 'https://console.groq.com/keys', 'gsk_'),
  openRouter('OpenRouter', 'https://openrouter.ai/keys', 'sk-or-'),
  unknown('Bilinmeyen', '', '');

  final String label;
  final String consoleUrl;
  final String prefix;
  const AiProvider(this.label, this.consoleUrl, this.prefix);
}

class SavedAiKey {
  final String id;
  final String key;
  final AiProvider provider;
  final DateTime addedAt;
  List<String> _models;
  String? selectedModel;

  SavedAiKey({
    required this.id,
    required this.key,
    required this.provider,
    required this.addedAt,
    required List<String> models,
    this.selectedModel,
  }) : _models = List<String>.from(models);

  List<String> get models {
    final seeds = AiService.getSeedModels(provider);
    final combined = <String>{..._models, ...seeds}.toList();
    return AiService.rankModels(provider, combined);
  }

  set models(List<String> list) {
    _models = List<String>.from(list);
  }

  String get activeModel {
    if (selectedModel != null && selectedModel!.isNotEmpty && models.contains(selectedModel)) {
      return selectedModel!;
    }
    if (models.isNotEmpty) return models.first;
    switch (provider) {
      case AiProvider.groq:
        return 'qwen/qwen3.8-27b';
      case AiProvider.gemini:
        return 'gemini-2.0-flash';
      case AiProvider.openRouter:
        return 'meta-llama/llama-3.3-70b-instruct:free';
      default:
        return '';
    }
  }

  String get masked {
    if (key.length <= 8) return '****';
    return '${key.substring(0, 5)}...${key.substring(key.length - 4)}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'key': key,
        'provider': provider.name,
        'addedAt': addedAt.toIso8601String(),
        'models': models,
        'selectedModel': selectedModel,
      };

  factory SavedAiKey.fromJson(Map<String, dynamic> json) {
    final pName = json['provider'] as String? ?? 'unknown';
    final p = AiProvider.values.firstWhere(
      (e) => e.name == pName,
      orElse: () => AiProvider.unknown,
    );
    final rawStored = (json['models'] as List<dynamic>? ?? []).cast<String>();
    final seeds = AiService.getSeedModels(p);
    final combined = <String>{...rawStored, ...seeds}.toList();
    final ranked = AiService.rankModels(p, combined);
    return SavedAiKey(
      id: json['id'] as String? ?? 'key_${DateTime.now().millisecondsSinceEpoch}',
      key: json['key'] as String? ?? '',
      provider: p,
      addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
      models: ranked.isNotEmpty ? ranked : seeds,
      selectedModel: json['selectedModel'] as String?,
    );
  }
}

class SavedAiChatMessage {
  final String id;
  final bool isUser;
  final String text;
  final DateTime timestamp;

  SavedAiChatMessage({
    required this.id,
    required this.isUser,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'isUser': isUser,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
  };

  factory SavedAiChatMessage.fromJson(Map<String, dynamic> json) => SavedAiChatMessage(
    id: json['id'] as String? ?? 'msg_${DateTime.now().microsecondsSinceEpoch}',
    isUser: json['isUser'] as bool? ?? false,
    text: json['text'] as String? ?? '',
    timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
  );
}

class SavedAiChat {
  final String id;
  final String articleId;
  final String articleTitle;
  final String moduleId;
  final String moduleTitle;
  final String prompt;
  final String response;
  final String model;
  final String provider;
  final DateTime timestamp;
  final List<SavedAiChatMessage> messages;

  SavedAiChat({
    required this.id,
    this.articleId = '',
    required this.articleTitle,
    this.moduleId = '',
    this.moduleTitle = 'Genel Dokümanlar',
    required this.prompt,
    required this.response,
    required this.model,
    required this.provider,
    required this.timestamp,
    this.messages = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'articleId': articleId,
    'articleTitle': articleTitle,
    'moduleId': moduleId,
    'moduleTitle': moduleTitle,
    'prompt': prompt,
    'response': response,
    'model': model,
    'provider': provider,
    'timestamp': timestamp.toIso8601String(),
    'messages': messages.map((m) => m.toJson()).toList(),
  };

  factory SavedAiChat.fromJson(Map<String, dynamic> json) {
    final rawMsgs = json['messages'] as List<dynamic>?;
    final parsedMsgs = rawMsgs != null
        ? rawMsgs.map((m) => SavedAiChatMessage.fromJson(m as Map<String, dynamic>)).toList()
        : <SavedAiChatMessage>[];

    final promptText = json['prompt'] as String? ?? '';
    final responseText = json['response'] as String? ?? '';

    if (parsedMsgs.isEmpty && (promptText.isNotEmpty || responseText.isNotEmpty)) {
      final t = DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now();
      if (promptText.isNotEmpty) {
        parsedMsgs.add(SavedAiChatMessage(
          id: 'legacy_user_${json['id']}',
          isUser: true,
          text: promptText,
          timestamp: t,
        ));
      }
      if (responseText.isNotEmpty) {
        parsedMsgs.add(SavedAiChatMessage(
          id: 'legacy_ai_${json['id']}',
          isUser: false,
          text: responseText,
          timestamp: t.add(const Duration(seconds: 1)),
        ));
      }
    }

    return SavedAiChat(
      id: json['id'] as String? ?? 'chat_${DateTime.now().millisecondsSinceEpoch}',
      articleId: json['articleId'] as String? ?? '',
      articleTitle: json['articleTitle'] as String? ?? 'Genel Doküman',
      moduleId: json['moduleId'] as String? ?? '',
      moduleTitle: json['moduleTitle'] as String? ?? (json['articleTitle'] as String? ?? 'Genel Modül'),
      prompt: promptText,
      response: responseText,
      model: json['model'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      messages: parsedMsgs,
    );
  }
}

class AiService extends ChangeNotifier {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  List<SavedAiKey> _keys = [];
  List<SavedAiChat> _savedChats = [];
  String? _activeKeyId;
  String? _lastUsedModel;
  bool _isInitialized = false;

  List<SavedAiKey> get keys => _keys;
  List<SavedAiChat> get savedChats => List.unmodifiable(_savedChats);
  bool get hasKeys => _keys.isNotEmpty;
  bool get isConfigured => activeKey != null;
  String? get lastUsedModel => _lastUsedModel;

  SavedAiKey? get activeKey {
    if (_keys.isEmpty) return null;
    if (_activeKeyId != null) {
      try {
        return _keys.firstWhere((k) => k.id == _activeKeyId);
      } catch (_) {}
    }
    return _keys.first;
  }

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      String? raw;
      try {
        raw = await _storage.read(key: 'saved_ai_keys_json');
      } catch (_) {}

      if (raw == null || raw.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        raw = prefs.getString('saved_ai_keys_fallback_json');
      }

      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> list = json.decode(raw);
        _keys = list.map((item) => SavedAiKey.fromJson(item)).toList();
      }
      final prefs = await SharedPreferences.getInstance();
      _activeKeyId = prefs.getString('active_ai_key_id');

      final chatsRaw = prefs.getString('saved_ai_chats_json');
      if (chatsRaw != null && chatsRaw.isNotEmpty) {
        final List<dynamic> cList = json.decode(chatsRaw);
        _savedChats = cList.map((i) => SavedAiChat.fromJson(i)).toList();
      }
    } catch (_) {}
    _isInitialized = true;
    notifyListeners();
  }

  // Doküman bazlı canlı aktif sohbet oturumları (Scoped Session Cache)
  final Map<String, List<SavedAiChatMessage>> _activeSessions = {};

  List<SavedAiChatMessage> getSession(String articleId) {
    if (!_activeSessions.containsKey(articleId)) {
      final saved = _savedChats.where((c) => c.articleId == articleId).firstOrNull;
      if (saved != null && saved.messages.isNotEmpty) {
        _activeSessions[articleId] = List.from(saved.messages);
      } else {
        _activeSessions[articleId] = [];
      }
    }
    return _activeSessions[articleId]!;
  }

  void addSessionMessage(String articleId, SavedAiChatMessage msg) {
    if (!_activeSessions.containsKey(articleId)) {
      _activeSessions[articleId] = [];
    }
    _activeSessions[articleId]!.add(msg);
    final savedIdx = _savedChats.indexWhere((c) => c.articleId == articleId);
    if (savedIdx >= 0) {
      final existing = _savedChats[savedIdx];
      final updatedMsgs = List<SavedAiChatMessage>.from(_activeSessions[articleId]!);
      _savedChats[savedIdx] = SavedAiChat(
        id: existing.id,
        articleId: existing.articleId,
        articleTitle: existing.articleTitle,
        moduleId: existing.moduleId,
        moduleTitle: existing.moduleTitle,
        prompt: updatedMsgs.firstWhere((m) => m.isUser, orElse: () => updatedMsgs.first).text,
        response: updatedMsgs.lastWhere((m) => !m.isUser, orElse: () => updatedMsgs.last).text,
        model: _lastUsedModel ?? existing.model,
        provider: existing.provider,
        timestamp: DateTime.now(),
        messages: updatedMsgs,
      );
      _persistSavedChats();
    }
    notifyListeners();
  }

  void removeSessionMessage(String articleId, String msgId) {
    if (_activeSessions.containsKey(articleId)) {
      _activeSessions[articleId]!.removeWhere((m) => m.id == msgId);
      final savedIdx = _savedChats.indexWhere((c) => c.articleId == articleId);
      if (savedIdx >= 0) {
        final existing = _savedChats[savedIdx];
        final updatedMsgs = List<SavedAiChatMessage>.from(_activeSessions[articleId]!);
        if (updatedMsgs.isEmpty) {
          _savedChats.removeAt(savedIdx);
        } else {
          _savedChats[savedIdx] = SavedAiChat(
            id: existing.id,
            articleId: existing.articleId,
            articleTitle: existing.articleTitle,
            moduleId: existing.moduleId,
            moduleTitle: existing.moduleTitle,
            prompt: updatedMsgs.firstWhere((m) => m.isUser, orElse: () => updatedMsgs.first).text,
            response: updatedMsgs.lastWhere((m) => !m.isUser, orElse: () => updatedMsgs.last).text,
            model: existing.model,
            provider: existing.provider,
            timestamp: existing.timestamp,
            messages: updatedMsgs,
          );
        }
        _persistSavedChats();
      }
      notifyListeners();
    }
  }

  void clearSession(String articleId) {
    _activeSessions[articleId] = [];
    notifyListeners();
  }

  List<SavedAiChat> getSavedChatsForArticle(String articleId) {
    if (articleId.isEmpty) return [];
    return _savedChats.where((c) => c.articleId == articleId).toList();
  }

  /// Sadece ve sadece o dokümana ait kayıtlı sohbetleri döner (Tam Doküman İzolasyonu)
  List<SavedAiChat> getSavedChatsForScope({required String articleId, String moduleId = ''}) {
    if (articleId.isEmpty) return [];
    return _savedChats.where((c) => c.articleId == articleId).toList();
  }

  bool isArticleChatSaved(String articleId) {
    if (articleId.isEmpty) return false;
    return _savedChats.any((c) => c.articleId == articleId);
  }

  Future<void> _persistSavedChats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'saved_ai_chats_json',
      json.encode(_savedChats.map((c) => c.toJson()).toList()),
    );
  }

  /// Toggle Save: Eğer bu doküman zaten kayıtlıysa kaydı siler (false döner), değilse tüm oturumu kaydeder (true döner)
  Future<bool> toggleSaveChat({
    required String articleId,
    required String articleTitle,
    String moduleId = '',
    String moduleTitle = '',
    required List<SavedAiChatMessage> messages,
  }) async {
    final existingIndex = _savedChats.indexWhere((c) => c.articleId == articleId);
    if (existingIndex >= 0) {
      _savedChats.removeAt(existingIndex);
      await _persistSavedChats();
      notifyListeners();
      return false;
    } else {
      if (messages.isEmpty) return false;
      final promptText = messages.firstWhere((m) => m.isUser, orElse: () => messages.first).text;
      final responseText = messages.lastWhere((m) => !m.isUser, orElse: () => messages.last).text;

      final chat = SavedAiChat(
        id: 'chat_${articleId}_${DateTime.now().millisecondsSinceEpoch}',
        articleId: articleId,
        articleTitle: articleTitle,
        moduleId: moduleId,
        moduleTitle: moduleTitle.isNotEmpty ? moduleTitle : articleTitle,
        prompt: promptText,
        response: responseText,
        model: _lastUsedModel ?? activeKey?.activeModel ?? 'AI Modeli',
        provider: activeKey?.provider.label ?? 'AI',
        timestamp: DateTime.now(),
        messages: List.from(messages),
      );
      _savedChats.insert(0, chat);
      await _persistSavedChats();
      notifyListeners();
      return true;
    }
  }

  Future<void> saveChat({
    required String articleTitle,
    required String prompt,
    required String response,
    String articleId = '',
    String moduleId = '',
    String moduleTitle = '',
    List<SavedAiChatMessage>? messages,
  }) async {
    final chatMessages = messages ?? [
      SavedAiChatMessage(id: 'msg_u', isUser: true, text: prompt, timestamp: DateTime.now()),
      SavedAiChatMessage(id: 'msg_a', isUser: false, text: response, timestamp: DateTime.now()),
    ];

    final chat = SavedAiChat(
      id: 'chat_${DateTime.now().millisecondsSinceEpoch}',
      articleId: articleId,
      articleTitle: articleTitle,
      moduleId: moduleId,
      moduleTitle: moduleTitle.isNotEmpty ? moduleTitle : articleTitle,
      prompt: prompt,
      response: response,
      model: _lastUsedModel ?? activeKey?.activeModel ?? 'AI Modeli',
      provider: activeKey?.provider.label ?? 'AI',
      timestamp: DateTime.now(),
      messages: chatMessages,
    );
    _savedChats.insert(0, chat);
    await _persistSavedChats();
    notifyListeners();
  }

  Future<void> deleteChat(String id) async {
    _savedChats.removeWhere((c) => c.id == id);
    await _persistSavedChats();
    notifyListeners();
  }

  Future<void> clearAllChats() async {
    _savedChats.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_ai_chats_json');
    notifyListeners();
  }

  static AiProvider detectProvider(String key) {
    final clean = key.trim();
    if (clean.startsWith('AIza') || clean.startsWith('AQ.')) {
      return AiProvider.gemini;
    } else if (clean.startsWith('gsk_')) {
      return AiProvider.groq;
    } else if (clean.startsWith('sk-or-')) {
      return AiProvider.openRouter;
    }
    return AiProvider.unknown;
  }

  /// Chat destekleyen modelleri filtreler (Ses, embedding ve denetim modellerini eler)
  static bool servesChat(String id) {
    final lower = id.toLowerCase();
    const cannot = [
      'whisper', 'tts', 'text-to-speech', 'embed', 'embedding', 'rerank',
      'moderation', 'guard', 'stable-diffusion', 'sdxl', 'flux', 'imagen',
      'veo-', 'aqa', 'ocr', 'distil-whisper',
    ];
    return !cannot.any(lower.contains);
  }

  static final Map<AiProvider, List<String>> _seed = {
    AiProvider.groq: [
      'qwen/qwen3.8-27b',
      'openai/gpt-oss-120b',
      'openai/gpt-oss-20b',
      'allam-2-7b',
      'canopylabs/orpheus-v1-english',
      'canopylabs/orpheus-arabic-saudi',
      'llama-3.3-70b-versatile',
      'llama-3.1-8b-instant',
      'deepseek-r1-distill-llama-70b',
      'llama-3.2-3b-preview',
      'llama-3.2-1b-preview',
      'llama-3.2-11b-vision-preview',
      'llama-3.2-90b-vision-preview',
      'mixtral-8x7b-32768',
      'gemma2-9b-it',
    ],
    AiProvider.gemini: [
      'gemini-2.0-flash',
      'gemini-2.0-flash-lite',
      'gemini-2.0-flash-thinking-exp-01-21',
      'gemini-2.0-pro-exp-02-05',
      'gemini-1.5-flash',
      'gemini-1.5-flash-8b',
      'gemini-1.5-pro',
      'gemini-exp-1206',
      'learnlm-1.5-pro-experimental',
    ],
    AiProvider.openRouter: [
      'meta-llama/llama-3.3-70b-instruct:free',
      'google/gemini-2.0-flash-exp:free',
      'google/gemini-2.0-flash-thinking-exp:free',
      'deepseek/deepseek-r1:free',
      'deepseek/deepseek-chat:free',
      'qwen/qwen-2.5-72b-instruct:free',
      'qwen/qwen-2.5-coder-32b-instruct:free',
      'mistralai/mistral-7b-instruct:free',
      'microsoft/phi-3-medium-128k-instruct:free',
      'meta-llama/llama-3.1-8b-instruct:free',
      'cognitivecomputations/dolphin3.0-r1-mistral-24b:free',
      'meta-llama/llama-3.2-3b-instruct:free',
      'meta-llama/llama-3-8b-instruct:free',
      'google/gemma-2-9b-it:free',
      'nousresearch/hermes-3-llama-3.1-405b:free',
      'huggingfaceh4/zephyr-7b-beta:free',
      'openrouter/auto',
    ],
  };

  static List<String> getSeedModels(AiProvider provider) {
    return _seed[provider] ?? [];
  }

  /// Modelleri kalite ve performansa göre sıralar
  static List<String> rankModels(AiProvider provider, List<String> ids) {
    final seeds = _seed[provider] ?? [];
    final chatCapable = ids.where(servesChat).toList();

    chatCapable.sort((a, b) {
      final rankA = _seedRank(seeds, a);
      final rankB = _seedRank(seeds, b);
      if (rankA != rankB) return rankA.compareTo(rankB);
      return a.compareTo(b);
    });

    return chatCapable;
  }

  static int _seedRank(List<String> seeds, String id) {
    final lower = id.toLowerCase();
    for (int i = 0; i < seeds.length; i++) {
      if (lower == seeds[i].toLowerCase() || lower.contains(seeds[i].toLowerCase())) return i;
    }
    return seeds.length + 10;
  }

  /// Büyük dokümanların model TPM (tokens per minute) limitini aşmaması için güvenli kırpma
  static String trimContext(String text, {int maxChars = 12000}) {
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars)}\n\n[...Doküman modelin TPM/token sınırını aşmaması için özetlendi...]';
  }

  Future<String?> addAndValidateKey(String rawKey) async {
    final clean = rawKey.trim();
    final p = detectProvider(clean);
    if (p == AiProvider.unknown) {
      return 'Bilinmeyen anahtar öneki. Google Gemini (AIza...), Groq (gsk_...) veya OpenRouter (sk-or-...) anahtarı girin.';
    }

    // Doğrulama ve model listeleme
    final models = await testKey(clean, p);
    if (models == null || models.isEmpty) {
      return 'Anahtar doğrulanamadı veya uygun sohbet modeli bulunamadı. Lütfen anahtarın geçerliliğini ve internet bağlantınızı kontrol edin.';
    }

    final newKey = SavedAiKey(
      id: 'key_${DateTime.now().millisecondsSinceEpoch}',
      key: clean,
      provider: p,
      addedAt: DateTime.now(),
      models: models,
      selectedModel: models.first,
    );

    _keys.add(newKey);
    _activeKeyId = newKey.id;
    await _persistKeys();
    notifyListeners();
    return null; // Başarılı
  }

  /// Kullanıcının anahtar için istediği modeli seçmesi
  Future<void> setModelForKey(String keyId, String modelId) async {
    final idx = _keys.indexWhere((k) => k.id == keyId);
    if (idx != -1) {
      _keys[idx].selectedModel = modelId;
      await _persistKeys();
      notifyListeners();
    }
  }

  /// Kullanıcının manuel olarak özel bir model ID'si eklemesi (örn: fine-tuned veya yeni model)
  Future<void> addCustomModelForKey(String keyId, String customModel) async {
    final clean = customModel.trim();
    if (clean.isEmpty) return;
    final idx = _keys.indexWhere((k) => k.id == keyId);
    if (idx != -1) {
      final currentList = List<String>.from(_keys[idx].models);
      if (!currentList.contains(clean)) {
        currentList.insert(0, clean);
      }
      _keys[idx].models = currentList;
      _keys[idx].selectedModel = clean;
      await _persistKeys();
      notifyListeners();
    }
  }

  /// Anahtarın erişilebilir modellerini API üzerinden canlı olarak tekrar sorgulayıp günceller
  Future<int> refreshModelsForKey(String keyId) async {
    final idx = _keys.indexWhere((k) => k.id == keyId);
    if (idx == -1) return 0;
    final k = _keys[idx];
    final fresh = await testKey(k.key, k.provider);
    if (fresh != null && fresh.isNotEmpty) {
      final combined = <String>{...k.models, ...fresh}.toList();
      _keys[idx].models = rankModels(k.provider, combined);
      await _persistKeys();
      notifyListeners();
      return _keys[idx].models.length;
    }
    return k.models.length;
  }

  /// Tekli anahtar atama kolaylığı (ai_sheet uyumluluğu)
  Future<bool> setApiKey(String rawKey) async {
    final err = await addAndValidateKey(rawKey);
    return err == null;
  }

  /// Aktif anahtarı silme (ai_sheet uyumluluğu)
  Future<void> clearApiKey() async {
    if (activeKey != null) {
      await removeKey(activeKey!.id);
    }
  }

  Future<void> clearAllKeys() async {
    _keys.clear();
    _activeKeyId = null;
    await _persistKeys();
    notifyListeners();
  }

  Future<void> removeKey(String id) async {
    _keys.removeWhere((k) => k.id == id);
    if (_activeKeyId == id) {
      _activeKeyId = _keys.isNotEmpty ? _keys.first.id : null;
    }
    await _persistKeys();
    notifyListeners();
  }

  Future<void> setActiveKey(String id) async {
    _activeKeyId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_ai_key_id', id);
    notifyListeners();
  }

  Future<void> _persistKeys() async {
    final raw = json.encode(_keys.map((k) => k.toJson()).toList());
    try {
      await _storage.write(key: 'saved_ai_keys_json', value: raw);
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_ai_keys_fallback_json', raw);
    if (_activeKeyId != null) {
      await prefs.setString('active_ai_key_id', _activeKeyId!);
    } else {
      await prefs.remove('active_ai_key_id');
    }
  }

  /// Anahtarı canlı olarak test eder ve erişilebilir modelleri döner
  Future<List<String>?> testKey(String key, AiProvider p) async {
    final seeds = _seed[p] ?? [];
    try {
      if (p == AiProvider.gemini) {
        final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$key');
        final res = await http.get(url).timeout(const Duration(seconds: 7));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          final rawList = (data['models'] as List<dynamic>? ?? [])
              .map((m) => (m['name'] as String).replaceFirst('models/', ''))
              .where((name) => servesChat(name))
              .toList();
          final combined = <String>{...rawList, ...seeds}.toList();
          final ranked = rankModels(p, combined);
          return ranked.isNotEmpty ? ranked : List<String>.from(seeds);
        } else if (res.statusCode == 400 || res.statusCode == 401 || res.statusCode == 403) {
          return null; // Yetkisiz anahtar
        }
      } else if (p == AiProvider.groq) {
        final url = Uri.parse('https://api.groq.com/openai/v1/models');
        final res = await http.get(url, headers: {
          'Authorization': 'Bearer $key',
        }).timeout(const Duration(seconds: 7));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          final rawList = (data['data'] as List<dynamic>? ?? [])
              .map((m) => m['id'] as String)
              .where(servesChat)
              .toList();
          final combined = <String>{...rawList, ...seeds}.toList();
          final ranked = rankModels(p, combined);
          return ranked.isNotEmpty ? ranked : List<String>.from(seeds);
        } else if (res.statusCode == 401 || res.statusCode == 403) {
          return null; // Yetkisiz anahtar
        }
      } else if (p == AiProvider.openRouter) {
        final url = Uri.parse('https://openrouter.ai/api/v1/models');
        final res = await http.get(url, headers: {
          'Authorization': 'Bearer $key',
        }).timeout(const Duration(seconds: 7));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          final rawList = <String>[];
          for (final entry in (data['data'] as List<dynamic>? ?? [])) {
            final id = entry['id'] as String?;
            if (id == null) continue;
            final pricing = entry['pricing'];
            if (pricing is Map && (pricing['prompt'] == '0' || id.contains(':free'))) {
              rawList.add(id);
            }
          }
          final combined = <String>{...rawList, ...seeds}.toList();
          final ranked = rankModels(p, combined);
          return ranked.isNotEmpty ? ranked : List<String>.from(seeds);
        } else if (res.statusCode == 401 || res.statusCode == 403) {
          return null;
        }
      }
    } catch (_) {
      // Ağ engeli, CORS veya tarayıcı eklentisi zaman aşımı durumunda:
      // Doğru formatlı anahtarlar için yerleşik zengin model listesiyle devam et
      if (key.length >= 20) {
        return List<String>.from(seeds);
      }
    }

    // HTTP 200/401 harici durumlarda geçerli varsayılan modeller
    if (key.length >= 20) {
      return List<String>.from(seeds);
    }

    return null;
  }

  /// Akıllı Fallback Zinciri ile Soru Sor
  Future<String> askAi({
    required String prompt,
    required String articleContext,
  }) async {
    final keyObj = activeKey;
    if (keyObj == null) {
      return 'Lütfen önce "Ayarlar -> AI Anahtar Yönetimi" menüsünden geçerli bir API anahtarı ekleyin.';
    }

    final trimmedContext = trimContext(articleContext, maxChars: 7500);

    final systemInstruction = '''Sen kıdemli bir Active Directory Siber Güvenlik Uzmanısın (Kırmızı ve Mavi Takım).
Aşağıdaki Active Directory dokümanını temel alarak kullanıcıya net, operasyonel, teknik ve Türkçe cevap ver.
Cevaplarında komut parametrelerini, Windows Event ID'lerini ve OPSEC risklerini net belirt.''';

    // Model sıralaması: Kullanıcının seçtiği model en başta, ardından diğer modeller
    final modelsToTry = <String>[];
    if (keyObj.selectedModel != null && keyObj.models.contains(keyObj.selectedModel)) {
      modelsToTry.add(keyObj.selectedModel!);
    }
    for (final m in keyObj.models) {
      if (!modelsToTry.contains(m)) modelsToTry.add(m);
    }
    if (modelsToTry.isEmpty) {
      modelsToTry.add(keyObj.activeModel);
    }

    String? lastError;

    // Fallback döngüsü: Biri hata verirse (örneğin Groq 429 kota aşımı) sonrakini dener
    for (final model in modelsToTry) {
      try {
        final answer = await _dispatchCall(
          provider: keyObj.provider,
          key: keyObj.key,
          model: model,
          prompt: prompt,
          context: trimmedContext,
          system: systemInstruction,
        );
        _lastUsedModel = model;
        return answer;
      } catch (e) {
        lastError = e.toString();
        // Alternatif modele geç
        continue;
      }
    }

    return 'Sağlayıcıdaki modellerden yanıt alınamadı.\nSon Hata: ${lastError ?? "Bilinmeyen hata"}\n\nİpucu: Model veya kota hatası aldıysanız, "Model Seç" menüsünden hesabınızda aktif olan alternatif modelleri (örneğin "qwen/qwen3.8-27b" veya "openai/gpt-oss-20b") seçebilirsiniz.';
  }

  /// AI ile Dinamik ve Özelleştirilmiş Sınav Soruları Üretir
  Future<List<QuizQuestion>> generateQuizQuestions({
    QuizCategory? category,
    required QuizDifficulty difficulty,
    required int count,
    String? customTopic,
  }) async {
    final keyObj = activeKey;
    if (keyObj == null) {
      throw Exception('Lütfen önce "Ayarlar -> AI Anahtar Yönetimi" menüsünden bir API anahtarı ekleyin.');
    }

    final categoryLabel = category != null ? '${category.label} (${category.name})' : 'Karma Active Directory Konuları (Keşif, Kerberos, AD CS, ACL/GPO, Delegasyon, Yanal Hareket, Mavi Takım, Sistem)';

    final systemInstruction = '''Sen kıdemli bir Active Directory Siber Güvenlik Uzmanısın ve CRTP / CRTE / OSCP sertifikasyonları için baş soru hazırlayıcısısın.
Görevin, belirtilen kriterlere uygun 4 seçenekli sınav soruları üretmektir.
Çıktın SADECE ve SADECE geçerli bir JSON array olmalıdır. Başka hiçbir açıklama, selamlama metni veya markdown yazma.

JSON Şeması:
[
  {
    "category": "kerberos", // veya adcs, recon, aclGpo, credentialAccess, blueTeam vb.
    "question": "Soru metni... (Operasyonel ve senaryo odaklı, gerekiyorsa komut veya çıktı içeren)",
    "options": [
      "A şıkkı metni",
      "B şıkkı metni",
      "C şıkkı metni",
      "D şıkkı metni"
    ],
    "correctIndex": 0,
    "explanation": "Detaylı teknik açıklama: Doğru şıkkın neden doğru olduğu, kullanılan protokol/mekanizma ve yanlış şıkların neden elendiği.",
    "mitreId": "T1558.003"
  }
]
''';

    final prompt = '''Lütfen aşağıdaki kriterlere uygun $count adet 4 seçenekli Active Directory çoktan seçmeli sorusu üret:
- Kategori: $categoryLabel
- Zorluk Seviyesi: ${difficulty.label}
${(customTopic != null && customTopic.trim().isNotEmpty) ? "- Özel Odak / Konu: ${customTopic.trim()}" : "- Odak: Belirtilen kategorinin en kritik operasyonel senaryoları, saldırı teknikleri, EDR/OPSEC sonuçları veya tespit mekanizmaları"}
- Soru Sayısı: $count adet

Kurallar:
1. Sorular gerçek dünya sızma testi veya savunma senaryolarına dayanmalı, pratik ve teknik olmalıdır.
2. Her sorunun tam olarak 4 seçeneği olmalı ve 'correctIndex' 0, 1, 2 veya 3 olmalıdır.
3. 'explanation' alanı öğrenmeyi pekiştirecek derinlikte ve Türkçe olmalıdır.
4. 'mitreId' geçerli bir MITRE ATT&CK tekniği olmalıdır (örn: T1087, T1558, T1078, T1484 vb.).
5. ÇIKTI YALNIZCA VE YALNIZCA GEÇERLİ JSON ARRAY OLMALIDIR.''';

    final modelsToTry = <String>[];
    if (keyObj.selectedModel != null && keyObj.models.contains(keyObj.selectedModel)) {
      modelsToTry.add(keyObj.selectedModel!);
    }
    for (final m in keyObj.models) {
      if (!modelsToTry.contains(m)) modelsToTry.add(m);
    }
    if (modelsToTry.isEmpty) {
      modelsToTry.add(keyObj.activeModel);
    }

    String? lastError;
    for (final model in modelsToTry) {
      try {
        final rawResponse = await _dispatchCall(
          provider: keyObj.provider,
          key: keyObj.key,
          model: model,
          prompt: prompt,
          context: '',
          system: systemInstruction,
        );
        _lastUsedModel = model;

        final cleanedJson = _extractJsonArray(rawResponse);
        final dynamic decoded = json.decode(cleanedJson);
        if (decoded is! List) continue;

        final result = <QuizQuestion>[];
        for (int i = 0; i < decoded.length; i++) {
          final item = decoded[i] as Map<String, dynamic>;
          final opts = (item['options'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
          if (opts.length < 2) continue;

          final cIndex = (item['correctIndex'] as num?)?.toInt() ?? 0;
          final validIndex = (cIndex >= 0 && cIndex < opts.length) ? cIndex : 0;

          final catName = item['category']?.toString().toLowerCase();
          final qCategory = (category != null)
              ? category
              : QuizCategory.values.firstWhere(
                  (c) => c.name.toLowerCase() == catName,
                  orElse: () => QuizCategory.values[i % QuizCategory.values.length],
                );

          result.add(QuizQuestion(
            id: 'q_ai_${DateTime.now().millisecondsSinceEpoch}_$i',
            category: qCategory,
            difficulty: difficulty,
            question: item['question']?.toString() ?? 'Soru yüklenemedi',
            options: opts,
            correctIndex: validIndex,
            explanation: item['explanation']?.toString() ?? 'Açıklama bulunamadı.',
            mitreId: item['mitreId']?.toString() ?? 'T1078',
            relatedDocPath: null,
          ));
        }

        if (result.isNotEmpty) {
          return result;
        }
      } catch (e) {
        lastError = e.toString();
        continue;
      }
    }

    throw Exception(lastError ?? 'AI soru üretimi başarısız oldu.');
  }

  /// Markdown bloklarını temizleyip saf JSON dizisi aralığını yakalar
  String _extractJsonArray(String raw) {
    String text = raw.trim();
    if (text.startsWith('```')) {
      final lines = text.split('\n');
      if (lines.first.startsWith('```')) lines.removeAt(0);
      if (lines.isNotEmpty && lines.last.startsWith('```')) lines.removeLast();
      text = lines.join('\n').trim();
    }
    final firstBracket = text.indexOf('[');
    final lastBracket = text.lastIndexOf(']');
    if (firstBracket != -1 && lastBracket != -1 && lastBracket > firstBracket) {
      return text.substring(firstBracket, lastBracket + 1);
    }
    return text;
  }

  Future<String> _dispatchCall({
    required AiProvider provider,
    required String key,
    required String model,
    required String prompt,
    required String context,
    required String system,
  }) async {
    switch (provider) {
      case AiProvider.gemini:
        return _callGemini(key: key, model: model, prompt: prompt, context: context, system: system);
      case AiProvider.groq:
        return _callGroq(key: key, model: model, prompt: prompt, context: context, system: system);
      case AiProvider.openRouter:
        return _callOpenRouter(key: key, model: model, prompt: prompt, context: context, system: system);
      default:
        throw Exception('Bilinmeyen sağlayıcı.');
    }
  }

  Future<String> _callGemini({
    required String key,
    required String model,
    required String prompt,
    required String context,
    required String system,
  }) async {
    final modelName = model.startsWith('models/') ? model.replaceFirst('models/', '') : model;
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$key',
    );
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': '$system\n\n[DOKÜMAN İÇERİĞİ]:\n$context\n\n[SORU / GÖREV]:\n$prompt'}
            ]
          }
        ],
        'generationConfig': {'temperature': 0.3, 'maxOutputTokens': 3000}
      }),
    ).timeout(const Duration(seconds: 35));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final candidate = data['candidates']?[0];
      final text = candidate?['content']?['parts']?[0]?['text'];
      if (text != null) return text;
      throw Exception('Gemini boş yanıt döndürdü.');
    }

    if (response.statusCode == 429) {
      throw Exception('Gemini Kota Limiti (429): $model için dakikalık istek sınırı aşıldı.');
    }

    throw Exception('Gemini Hatası (${response.statusCode}): ${response.body}');
  }

  Future<String> _callGroq({
    required String key,
    required String model,
    required String prompt,
    required String context,
    required String system,
  }) async {
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $key',
      },
      body: json.encode({
        'model': model,
        'messages': [
          {'role': 'system', 'content': '$system\n\n[DOKÜMAN]:\n$context'},
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.3,
        'max_tokens': 3000,
      }),
    ).timeout(const Duration(seconds: 35));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['choices'][0]['message']['content'] ?? 'Boş yanıt.';
    }

    if (response.statusCode == 429) {
      throw Exception('Groq Kota Limiti (429): $model dakikalık token (TPM) limitine ulaşıldı.');
    }
    if (response.statusCode == 413) {
      throw Exception('Groq İstek Boyutu (413): $model için istek çok büyük.');
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception('Groq Yetki Hatası (401/403): API anahtarı geçersiz.');
    }

    throw Exception('Groq Hatası (${response.statusCode}): ${response.body}');
  }

  Future<String> _callOpenRouter({
    required String key,
    required String model,
    required String prompt,
    required String context,
    required String system,
  }) async {
    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $key',
        'HTTP-Referer': 'https://github.com/active-directory-vault',
        'X-Title': 'Active Directory Vault',
      },
      body: json.encode({
        'model': model,
        'messages': [
          {'role': 'system', 'content': '$system\n\n[DOKÜMAN]:\n$context'},
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.3,
        'max_tokens': 3000,
      }),
    ).timeout(const Duration(seconds: 40));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['choices'][0]['message']['content'] ?? 'Boş yanıt.';
    }

    if (response.statusCode == 429) {
      throw Exception('OpenRouter Kota Limiti (429): $model sınırına ulaşıldı.');
    }

    throw Exception('OpenRouter Hatası (${response.statusCode}): ${response.body}');
  }
}
