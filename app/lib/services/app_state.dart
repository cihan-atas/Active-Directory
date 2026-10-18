import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  SharedPreferences? _prefs;

  Set<String> _readIds = {};
  Set<String> _bookmarkedIds = {};
  String? _lastReadId;
  String? _lastReadTitle;
  String? _lastReadCategory;
  final Map<String, int> _cardBoxes = {}; // cardId -> box (1..5)
  bool _isInitialized = false;

  Set<String> get readIds => _readIds;
  Set<String> get bookmarkedIds => _bookmarkedIds;
  String? get lastReadId => _lastReadId;
  String? get lastReadTitle => _lastReadTitle;
  String? get lastReadCategory => _lastReadCategory;
  Map<String, int> get cardBoxes => _cardBoxes;
  bool get isInitialized => _isInitialized;

  int get readCount => _readIds.length;
  int get bookmarkedCount => _bookmarkedIds.length;
  int get masteredCardsCount => _cardBoxes.values.where((b) => b >= 4).length;

  Future<void> init() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();

    final readList = _prefs?.getStringList('ad_read_ids') ?? [];
    _readIds = readList.toSet();

    final bookmarkedList = _prefs?.getStringList('saved_bookmarks') ?? [];
    _bookmarkedIds = bookmarkedList.toSet();

    _lastReadId = _prefs?.getString('ad_last_read_id');
    _lastReadTitle = _prefs?.getString('ad_last_read_title');
    _lastReadCategory = _prefs?.getString('ad_last_read_cat');

    // Kart ilerlemesi
    final cardKeys = _prefs?.getKeys().where((k) => k.startsWith('card_box_')) ?? [];
    for (final k in cardKeys) {
      final cardId = k.replaceFirst('card_box_', '');
      _cardBoxes[cardId] = _prefs?.getInt(k) ?? 1;
    }

    _isInitialized = true;
    notifyListeners();
  }

  bool isRead(String id) => _readIds.contains(id);
  bool isBookmarked(String id) => _bookmarkedIds.contains(id);

  Future<void> toggleRead(String id) async {
    if (_readIds.contains(id)) {
      _readIds.remove(id);
    } else {
      _readIds.add(id);
    }
    await _prefs?.setStringList('ad_read_ids', _readIds.toList());
    notifyListeners();
  }

  Future<void> recordLastRead({
    required String id,
    required String title,
    required String category,
  }) async {
    _lastReadId = id;
    _lastReadTitle = title;
    _lastReadCategory = category;
    await _prefs?.setString('ad_last_read_id', id);
    await _prefs?.setString('ad_last_read_title', title);
    await _prefs?.setString('ad_last_read_cat', category);
    notifyListeners();
  }

  Future<void> toggleBookmark(String id) async {
    if (_bookmarkedIds.contains(id)) {
      _bookmarkedIds.remove(id);
    } else {
      _bookmarkedIds.add(id);
    }
    await _prefs?.setStringList('saved_bookmarks', _bookmarkedIds.toList());
    notifyListeners();
  }

  int getCardBox(String cardId) => _cardBoxes[cardId] ?? 1;

  Future<void> answerCard(String cardId, {required bool correct}) async {
    final currentBox = getCardBox(cardId);
    int newBox;
    if (correct) {
      newBox = (currentBox < 5) ? currentBox + 1 : 5;
    } else {
      newBox = 1; // Hatalı bilinirse 1. kutuya döner (Leitner)
    }
    _cardBoxes[cardId] = newBox;
    await _prefs?.setInt('card_box_$cardId', newBox);
    notifyListeners();
  }
}
