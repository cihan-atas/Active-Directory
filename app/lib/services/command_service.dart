import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/command_model.dart';

class CommandService {
  static final CommandService _instance = CommandService._internal();
  factory CommandService() => _instance;
  CommandService._internal();

  static const String _targetContextKey = 'adv_target_context_v1';
  static const String _customCommandsKey = 'adv_custom_commands_v1';
  static const String _favoriteIdsKey = 'adv_favorite_command_ids_v1';
  static const String _favoriteDetailsKey = 'adv_favorite_details_v2';
  static const String _userCategoriesKey = 'adv_user_categories_v1';

  TargetContext _targetContext = const TargetContext();
  TargetContext get targetContext => _targetContext;

  List<VaultCommand> _allCommands = [];
  List<VaultCommand> get allCommands => _allCommands;

  List<VaultCommand> get customCommands =>
      _allCommands.where((c) => c.isUserCreated).toList();

  List<VaultCommand> get favoriteCommands =>
      _allCommands.where((c) => c.isFavorite).toList();

  Set<String> _favoriteIds = {};
  Map<String, CommandFavorite> _favoritesMap = {};
  List<String> _userCategories = [];
  List<String> get userCategories => _userCategories;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Servisi başlatır ve verileri önbelleğe alır
  Future<void> init() async {
    if (_isInitialized && _allCommands.isNotEmpty) return;
    final prefs = await SharedPreferences.getInstance();

    // 1. Hedef Bağlamını Yükle
    final ctxJson = prefs.getString(_targetContextKey);
    if (ctxJson != null) {
      try {
        _targetContext = TargetContext.fromJson(jsonDecode(ctxJson));
      } catch (_) {}
    }

    // 2. Kullanıcı Kategorilerini Yükle
    _userCategories = prefs.getStringList(_userCategoriesKey) ?? [];

    // 3. Favori Detaylarını ve ID'lerini Yükle
    _favoriteIds = (prefs.getStringList(_favoriteIdsKey) ?? <String>[]).toSet();
    _favoritesMap = {};

    final favsDetailsJson = prefs.getString(_favoriteDetailsKey);
    if (favsDetailsJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(favsDetailsJson);
        for (var entry in decoded.entries) {
          if (entry.value is Map<String, dynamic>) {
            _favoritesMap[entry.key] = CommandFavorite.fromJson(entry.value as Map<String, dynamic>);
            _favoriteIds.add(entry.key);
          }
        }
      } catch (_) {}
    } else {
      // Geriye dönük uyumluluk: Eski favoriteIds'leri Map'e dönüştür
      for (var id in _favoriteIds) {
        _favoritesMap[id] = CommandFavorite(commandId: id);
      }
    }

    // 4. Dahili Komutları Yükle
    List<VaultCommand> builtIn = [];
    try {
      final catalogString = await rootBundle.loadString('assets/data/commands_catalog.json');
      final List<dynamic> jsonList = jsonDecode(catalogString);
      builtIn = jsonList.map((e) => VaultCommand.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      builtIn = [];
    }

    // 5. Kullanıcı Özel Komutlarını Yükle
    List<VaultCommand> userCmds = [];
    final customJson = prefs.getString(_customCommandsKey);
    if (customJson != null) {
      try {
        final List<dynamic> customList = jsonDecode(customJson);
        userCmds = customList.map((e) {
          final cmd = VaultCommand.fromJson(e as Map<String, dynamic>);
          return VaultCommand(
            id: cmd.id,
            tool: cmd.tool,
            category: cmd.category,
            platform: cmd.platform,
            title: cmd.title,
            rawCommand: cmd.rawCommand,
            template: cmd.template,
            whatItDoes: cmd.whatItDoes,
            whenToUse: cmd.whenToUse,
            parameters: cmd.parameters,
            parameterList: cmd.parameterList,
            opsec: cmd.opsec,
            eventIds: cmd.eventIds,
            docPath: cmd.docPath,
            docId: cmd.docId,
            isUserCreated: true,
            isFavorite: cmd.isFavorite,
            userNote: cmd.userNote,
            customCategory: cmd.customCategory,
          );
        }).toList();
      } catch (_) {}
    }

    // 6. Birleştir ve Favori / Not Durumlarını Eşle
    _allCommands = [...userCmds, ...builtIn];
    for (var cmd in _allCommands) {
      if (_favoritesMap.containsKey(cmd.id)) {
        final fav = _favoritesMap[cmd.id]!;
        cmd.isFavorite = true;
        cmd.userNote = fav.note;
        cmd.customCategory = fav.category;
      } else {
        cmd.isFavorite = false;
        cmd.userNote = null;
        cmd.customCategory = null;
      }
    }
    _isInitialized = true;
  }

  /// Hedef bağlamını günceller ve kaydeder
  Future<void> updateTargetContext(TargetContext newContext) async {
    _targetContext = newContext;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_targetContextKey, jsonEncode(newContext.toJson()));
  }

  /// Favori kaydı veya notu var mı?
  CommandFavorite? getFavorite(String cmdId) => _favoritesMap[cmdId];

  /// Favori ekler veya günceller (Özel Not ve Kategori ile)
  Future<void> saveFavorite(String cmdId, {String note = '', String category = 'Genel'}) async {
    final fav = CommandFavorite(
      commandId: cmdId,
      note: note.trim(),
      category: category.trim().isEmpty ? 'Genel' : category.trim(),
    );

    _favoritesMap[cmdId] = fav;
    _favoriteIds.add(cmdId);

    final cmd = _allCommands.firstWhere((c) => c.id == cmdId, orElse: () => _allCommands.first);
    cmd.isFavorite = true;
    cmd.userNote = fav.note;
    cmd.customCategory = fav.category;

    await _persistFavorites();
  }

  /// Favorilerden kaldırır
  Future<void> removeFavorite(String cmdId) async {
    _favoritesMap.remove(cmdId);
    _favoriteIds.remove(cmdId);

    final cmd = _allCommands.firstWhere((c) => c.id == cmdId, orElse: () => _allCommands.first);
    cmd.isFavorite = false;
    cmd.userNote = null;
    cmd.customCategory = null;

    await _persistFavorites();
  }

  /// Hızlı Favori Aç/Kapat (Eski butonlar için)
  Future<void> toggleFavorite(String cmdId) async {
    if (_favoritesMap.containsKey(cmdId)) {
      await removeFavorite(cmdId);
    } else {
      await saveFavorite(cmdId);
    }
  }

  Future<void> _persistFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoriteIdsKey, _favoriteIds.toList());

    final Map<String, dynamic> exportMap = {};
    for (var entry in _favoritesMap.entries) {
      exportMap[entry.key] = entry.value.toJson();
    }
    await prefs.setString(_favoriteDetailsKey, jsonEncode(exportMap));
  }

  /// Yeni kullanıcı kategorisi ekler
  Future<void> addUserCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty && !_userCategories.contains(trimmed)) {
      _userCategories.add(trimmed);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_userCategoriesKey, _userCategories);
    }
  }

  /// Kullanıcı kategorisini siler
  Future<void> deleteUserCategory(String name) async {
    _userCategories.remove(name);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_userCategoriesKey, _userCategories);
  }

  /// Yeni özel komut ekler
  Future<void> addCustomCommand(VaultCommand command) async {
    final customCmd = VaultCommand(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      tool: command.tool.trim().isEmpty ? 'Özel Komut' : command.tool.trim(),
      category: command.category.trim().isEmpty ? 'Özel' : command.category.trim(),
      platform: command.platform,
      title: command.title.trim().isEmpty ? 'Yeni Komut' : command.title.trim(),
      rawCommand: command.rawCommand.trim(),
      template: command.template.trim().isNotEmpty ? command.template.trim() : command.rawCommand.trim(),
      whatItDoes: command.whatItDoes.trim(),
      whenToUse: command.whenToUse.trim(),
      parameters: command.parameters.trim(),
      parameterList: command.parameterList,
      opsec: command.opsec.trim(),
      eventIds: command.eventIds,
      docPath: command.docPath,
      docId: command.docId,
      isUserCreated: true,
      isFavorite: command.isFavorite,
      userNote: command.userNote,
      customCategory: command.customCategory,
    );

    _allCommands.insert(0, customCmd);
    await _saveCustomCommands();
  }

  /// Özel komutu günceller
  Future<void> updateCustomCommand(VaultCommand updated) async {
    final index = _allCommands.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      _allCommands[index] = updated;
      await _saveCustomCommands();
    }
  }

  /// Özel komutu siler
  Future<void> deleteCustomCommand(String cmdId) async {
    _allCommands.removeWhere((c) => c.id == cmdId && c.isUserCreated);
    await removeFavorite(cmdId);
    await _saveCustomCommands();
  }

  Future<void> _saveCustomCommands() async {
    final prefs = await SharedPreferences.getInstance();
    final customList = customCommands.map((c) => c.toJson()).toList();
    await prefs.setString(_customCommandsKey, jsonEncode(customList));
  }

  /// Seçili veya özel komutları Topluluk Paketi (JSON) olarak dışa aktarır
  String exportToCommunityPack({
    required String packName,
    required String author,
    required String description,
    List<VaultCommand>? commands,
  }) {
    final exportList = commands ?? customCommands;
    final pack = CommunityCommandPack(
      name: packName,
      author: author,
      description: description,
      version: '1.0',
      commands: exportList,
    );
    return pack.toFormattedJson();
  }

  /// Dışarıdan gelen JSON formatındaki paketi içe aktarır
  Future<int> importFromCommunityPack(String jsonString) async {
    try {
      final dynamic decoded = jsonDecode(jsonString);
      List<dynamic> rawCommands = [];

      if (decoded is Map<String, dynamic> && decoded.containsKey('commands')) {
        rawCommands = decoded['commands'] as List<dynamic>;
      } else if (decoded is List<dynamic>) {
        rawCommands = decoded;
      } else {
        throw Exception('Geçersiz paket formatı');
      }

      int count = 0;
      for (var item in rawCommands) {
        if (item is Map<String, dynamic>) {
          final parsed = VaultCommand.fromJson(item);
          final customCmd = VaultCommand(
            id: 'imported_${DateTime.now().millisecondsSinceEpoch}_$count',
            tool: parsed.tool,
            category: parsed.category,
            platform: parsed.platform,
            title: parsed.title,
            rawCommand: parsed.rawCommand,
            template: parsed.template.isNotEmpty ? parsed.template : parsed.rawCommand,
            whatItDoes: parsed.whatItDoes,
            whenToUse: parsed.whenToUse,
            parameters: parsed.parameters,
            parameterList: parsed.parameterList,
            opsec: parsed.opsec,
            eventIds: parsed.eventIds,
            docPath: parsed.docPath,
            docId: parsed.docId,
            isUserCreated: true,
            isFavorite: false,
            userNote: parsed.userNote,
            customCategory: parsed.customCategory,
          );
          _allCommands.insert(0, customCmd);
          count++;
        }
      }

      if (count > 0) {
        await _saveCustomCommands();
      }
      return count;
    } catch (e) {
      rethrow;
    }
  }
}
