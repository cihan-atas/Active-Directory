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
  static const String _customQuestionsKey = 'ad_vault_quiz_custom_questions_v1';

  final List<QuizQuestion> _allQuestions = kDefaultQuizQuestions;
  final List<QuizQuestion> _customQuestions = <QuizQuestion>[];
  final List<DecisionTreeScenario> _allScenarios = kDefaultDecisionScenarios;

  final Set<String> _wrongQuestionIds = <String>{};
  final Set<String> _bookmarkedQuestionIds = <String>{};
  final Map<String, int> _userAnswers = <String, int>{}; // questionId -> chosenIndex

  int _totalAnswered = 0;
  int _totalCorrect = 0;
  bool _isInitialized = false;

  List<QuizQuestion> get allQuestions => List.unmodifiable([..._allQuestions, ..._customQuestions]);
  List<QuizQuestion> get staticQuestions => List.unmodifiable(_allQuestions);
  List<QuizQuestion> get customQuestions => List.unmodifiable(_customQuestions);
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
      
      // Özel / AI tarafından üretilmiş soruları yükle
      final customRaw = prefs.getString(_customQuestionsKey);
      if (customRaw != null && customRaw.trim().isNotEmpty) {
        final List<dynamic> list = jsonDecode(customRaw);
        _customQuestions.clear();
        for (final item in list) {
          try {
            _customQuestions.add(QuizQuestion.fromJson(item as Map<String, dynamic>));
          } catch (_) {}
        }
      }

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
    return allQuestions.where((q) => _wrongQuestionIds.contains(q.id)).toList();
  }

  /// Yer imlerine eklenen soruları listeler
  List<QuizQuestion> getBookmarkedQuestions() {
    return allQuestions.where((q) => _bookmarkedQuestionIds.contains(q.id)).toList();
  }

  /// Kategoriye göre soruları getirir
  List<QuizQuestion> getQuestionsByCategory(QuizCategory category) {
    return allQuestions.where((q) => q.category == category).toList();
  }

  /// Zorluğa göre soruları getirir
  List<QuizQuestion> getQuestionsByDifficulty(QuizDifficulty difficulty) {
    return allQuestions.where((q) => q.difficulty == difficulty).toList();
  }

  /// Rastgele sınav seti oluşturur (Örn: 20 soru)
  List<QuizQuestion> getRandomExamSet({int count = 20}) {
    final list = List<QuizQuestion>.from(allQuestions)..shuffle();
    return list.take(count).toList();
  }

  /// Yeni üretilen AI / Özel soruları ekler ve kaydeder
  Future<void> addCustomQuestions(List<QuizQuestion> questions) async {
    for (final q in questions) {
      if (!_customQuestions.any((existing) => existing.id == q.id)) {
        _customQuestions.add(q);
      }
    }
    await _saveCustomQuestions();
    notifyListeners();
  }

  /// Özel soruyu siler
  Future<void> removeCustomQuestion(String id) async {
    _customQuestions.removeWhere((q) => q.id == id);
    _wrongQuestionIds.remove(id);
    _bookmarkedQuestionIds.remove(id);
    _userAnswers.remove(id);
    await _saveCustomQuestions();
    await _save();
    notifyListeners();
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

  /// Tüm kategoriler için yetenek ve açık analizi (Skill Gap Analysis) hesaplar
  List<CategorySkillStats> getSkillGapAnalysis() {
    final list = <CategorySkillStats>[];
    for (final cat in QuizCategory.values) {
      final catQuestions = allQuestions.where((q) => q.category == cat).toList();
      final total = catQuestions.length;
      int answered = 0;
      int correct = 0;
      int wrong = 0;

      for (final q in catQuestions) {
        if (_userAnswers.containsKey(q.id)) {
          answered++;
          if (_userAnswers[q.id] == q.correctIndex) {
            correct++;
          } else {
            wrong++;
          }
        }
      }

      final percent = answered > 0 ? ((correct / answered) * 100.0) : 0.0;
      list.add(
        CategorySkillStats(
          category: cat,
          totalQuestions: total,
          answeredCount: answered,
          correctCount: correct,
          wrongCount: wrong,
          scorePercent: percent,
        ),
      );
    }
    return list;
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

  Future<void> _saveCustomQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _customQuestions.map((q) => q.toJson()).toList();
    await prefs.setString(_customQuestionsKey, jsonEncode(list));
  }
}

/// Kategori Yetenek ve Açık Analizi Modeli (Skill Gap Stats)
class CategorySkillStats {
  final QuizCategory category;
  final int totalQuestions;
  final int answeredCount;
  final int correctCount;
  final int wrongCount;
  final double scorePercent;

  CategorySkillStats({
    required this.category,
    required this.totalQuestions,
    required this.answeredCount,
    required this.correctCount,
    required this.wrongCount,
    required this.scorePercent,
  });

  bool get hasAttempted => answeredCount > 0;
  bool get isWeak => hasAttempted ? scorePercent < 60.0 : true;
  bool get isMaster => hasAttempted && scorePercent >= 80.0;
}
