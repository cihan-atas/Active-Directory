import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quiz_data.dart';
import '../models/quiz_models.dart';

/// Test ve Sınav İlerleme Servisi (Quiz & Lab Service)
class QuizService extends ChangeNotifier {
  static final QuizService _instance = QuizService._internal();
  factory QuizService() => _instance;
  QuizService._internal();

  static const String _storageKey = 'ad_vault_quiz_state_v1';

  final List<QuizQuestion> _allQuestions = kDefaultQuizQuestions;
  final List<DecisionTreeScenario> _allScenarios = kDefaultDecisionScenarios;

  final Set<String> _wrongQuestionIds = <String>{};
  final Set<String> _bookmarkedQuestionIds = <String>{};
  final Map<String, int> _userAnswers = <String, int>{}; // questionId -> chosenIndex

  int _totalAnswered = 0;
  int _totalCorrect = 0;
  bool _isInitialized = false;

  List<QuizQuestion> get allQuestions => List.unmodifiable(_allQuestions);
  List<DecisionTreeScenario> get allScenarios => List.unmodifiable(_allScenarios);
  int get totalAnswered => _totalAnswered;
  int get totalCorrect => _totalCorrect;
  double get successRate => _totalAnswered > 0 ? (_totalCorrect / _totalAnswered) : 0.0;
  int get wrongCount => _wrongQuestionIds.length;
  int get bookmarkedCount => _bookmarkedQuestionIds.length;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(raw);
        _totalAnswered = data['totalAnswered'] as int? ?? 0;
        _totalCorrect = data['totalCorrect'] as int? ?? 0;

        final wrongList = (data['wrongQuestionIds'] as List<dynamic>?)?.map((e) => e.toString()) ?? [];
        _wrongQuestionIds.addAll(wrongList);

        final bookmarkList = (data['bookmarkedQuestionIds'] as List<dynamic>?)?.map((e) => e.toString()) ?? [];
        _bookmarkedQuestionIds.addAll(bookmarkList);

        final answersMap = (data['userAnswers'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as int)) ?? {};
        _userAnswers.addAll(answersMap);
      }
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('QuizService init hatası: $e');
      _isInitialized = true;
    }
  }

  /// Bir soruya verilen cevabı kaydeder
  Future<void> recordAnswer(String questionId, int chosenIndex, bool isCorrect) async {
    _userAnswers[questionId] = chosenIndex;
    _totalAnswered++;
    if (isCorrect) {
      _totalCorrect++;
      _wrongQuestionIds.remove(questionId); // Önceden yanlışsa temizle
    } else {
      _wrongQuestionIds.add(questionId);
    }
    await _save();
    notifyListeners();
  }

  /// Soruyu yer imlerine ekler veya çıkarır
  Future<void> toggleBookmark(String questionId) async {
    if (_bookmarkedQuestionIds.contains(questionId)) {
      _bookmarkedQuestionIds.remove(questionId);
    } else {
      _bookmarkedQuestionIds.add(questionId);
    }
    await _save();
    notifyListeners();
  }

  bool isBookmarked(String questionId) => _bookmarkedQuestionIds.contains(questionId);

  int? getRecordedAnswer(String questionId) => _userAnswers[questionId];

  /// Yanlış yapılan soruları listeler
  List<QuizQuestion> getWrongQuestions() {
    return _allQuestions.where((q) => _wrongQuestionIds.contains(q.id)).toList();
  }

  /// Yer imlerine eklenen soruları listeler
  List<QuizQuestion> getBookmarkedQuestions() {
    return _allQuestions.where((q) => _bookmarkedQuestionIds.contains(q.id)).toList();
  }

  /// Kategoriye göre soruları getirir
  List<QuizQuestion> getQuestionsByCategory(QuizCategory category) {
    return _allQuestions.where((q) => q.category == category).toList();
  }

  /// Zorluğa göre soruları getirir
  List<QuizQuestion> getQuestionsByDifficulty(QuizDifficulty difficulty) {
    return _allQuestions.where((q) => q.difficulty == difficulty).toList();
  }

  /// Rastgele sınav seti oluşturur (Örn: 20 soru)
  List<QuizQuestion> getRandomExamSet({int count = 20}) {
    final list = List<QuizQuestion>.from(_allQuestions)..shuffle();
    return list.take(count).toList();
  }

  /// Tüm istatistikleri sıfırlar
  Future<void> resetStats() async {
    _totalAnswered = 0;
    _totalCorrect = 0;
    _wrongQuestionIds.clear();
    _userAnswers.clear();
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'totalAnswered': _totalAnswered,
      'totalCorrect': _totalCorrect,
      'wrongQuestionIds': _wrongQuestionIds.toList(),
      'bookmarkedQuestionIds': _bookmarkedQuestionIds.toList(),
      'userAnswers': _userAnswers,
    };
    await prefs.setString(_storageKey, jsonEncode(data));
  }
}
