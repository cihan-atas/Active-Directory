import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/quiz_models.dart';
import '../services/content_service.dart';
import '../services/quiz_service.dart';
import '../theme/app_theme.dart';
import 'article_screen.dart';

/// Active Directory Lab Simülatörü ve Test Modu (Interactive Lab & Quiz Engine)
/// CRTP, CRTE ve OSCP sınavlarına hazırlık için 100+ soru, açıklamalı çözüm
/// ve senaryo bazlı karar ağaçlarını sunar.
class QuizScreen extends StatefulWidget {
  final QuizCategory? initialCategory;
  final bool startExamDirectly;

  const QuizScreen({
    super.key,
    this.initialCategory,
    this.startExamDirectly = false,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with SingleTickerProviderStateMixin {
  final QuizService _service = QuizService();
  late TabController _tabController;

  // Sınav / Test Durumu
  List<QuizQuestion> _activeQuestions = [];
  int _currentIndex = 0;
  int? _selectedOptionIndex;
  bool _hasAnsweredCurrent = false;
  int _sessionCorrect = 0;
  bool _isExamFinished = false;

  // Karar Ağacı Durumu
  DecisionTreeScenario? _activeTree;
  DecisionNode? _currentNode;
  DecisionChoice? _selectedChoice;

  // Filtreler
  QuizCategory? _filterCategory;
  QuizDifficulty? _filterDifficulty;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _service.init();
    _service.addListener(_onServiceChanged);

    if (widget.initialCategory != null) {
      _filterCategory = widget.initialCategory;
    }

    if (widget.startExamDirectly) {
      _startNewExam(count: 20);
    } else {
      _loadQuestionsForPractice();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _service.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  void _loadQuestionsForPractice() {
    List<QuizQuestion> list = _service.allQuestions;
    if (_filterCategory != null) {
      list = list.where((q) => q.category == _filterCategory).toList();
    }
    if (_filterDifficulty != null) {
      list = list.where((q) => q.difficulty == _filterDifficulty).toList();
    }

    setState(() {
      _activeQuestions = list;
      _currentIndex = 0;
      _selectedOptionIndex = null;
      _hasAnsweredCurrent = false;
      _isExamFinished = false;
    });
  }

  void _startNewExam({int count = 20}) {
    final list = _service.getRandomExamSet(count: count);
    setState(() {
      _activeQuestions = list;
      _currentIndex = 0;
      _selectedOptionIndex = null;
      _hasAnsweredCurrent = false;
      _sessionCorrect = 0;
      _isExamFinished = false;
      _tabController.index = 0;
    });
  }

  void _startWrongReview() {
    final list = _service.getWrongQuestions();
    setState(() {
      _activeQuestions = list;
      _currentIndex = 0;
      _selectedOptionIndex = null;
      _hasAnsweredCurrent = false;
      _sessionCorrect = 0;
      _isExamFinished = false;
      _tabController.index = 0;
    });
  }

  void _startDecisionTree(DecisionTreeScenario scenario) {
    setState(() {
      _activeTree = scenario;
      _currentNode = scenario.nodes[scenario.startNodeId];
      _selectedChoice = null;
      _tabController.index = 2; // Karar Ağacı Sekmesi
    });
  }

  void _onAnswerSelected(int optionIndex) {
    if (_hasAnsweredCurrent || _activeQuestions.isEmpty) return;

    final question = _activeQuestions[_currentIndex];
    final isCorrect = optionIndex == question.correctIndex;

    setState(() {
      _selectedOptionIndex = optionIndex;
      _hasAnsweredCurrent = true;
      if (isCorrect) _sessionCorrect++;
    });

    _service.recordAnswer(question.id, optionIndex, isCorrect);
    HapticFeedback.lightImpact();
  }

  void _nextQuestion() {
    if (_currentIndex + 1 < _activeQuestions.length) {
      setState(() {
        _currentIndex++;
        _selectedOptionIndex = null;
        _hasAnsweredCurrent = false;
      });
    } else {
      setState(() {
        _isExamFinished = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🎯 AD Lab & Sınav Simülatörü',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '${_service.allQuestions.length} Soru · 4 Karar Ağacı · CRTP / OSCP',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.redTeam,
          labelColor: Colors.white,
          unselectedLabelColor: AppTheme.textMuted,
          labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
          tabs: [
            const Tab(icon: Icon(Icons.quiz_outlined, size: 18), text: 'Test & Sınav'),
            const Tab(icon: Icon(Icons.category_outlined, size: 18), text: 'Konular'),
            Tab(
              icon: const Icon(Icons.account_tree_outlined, size: 18),
              text: 'Karar Ağaçları (${_service.allScenarios.length})',
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
            tooltip: 'Sınav Seçenekleri',
            onSelected: (val) {
              if (val == 'new_exam_20') {
                _startNewExam(count: 20);
              } else if (val == 'new_exam_10') {
                _startNewExam(count: 10);
              } else if (val == 'review_wrongs') {
                _startWrongReview();
              } else if (val == 'reset_stats') {
                _confirmResetStats();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'new_exam_20',
                child: Row(
                  children: [
                    Icon(Icons.bolt, color: AppTheme.redTeam, size: 18),
                    SizedBox(width: 8),
                    Text('Hızlı CRTP Deneme Sınavı (20 Soru)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'new_exam_10',
                child: Row(
                  children: [
                    Icon(Icons.speed, color: AppTheme.toolsAmber, size: 18),
                    SizedBox(width: 8),
                    Text('Mini Test (10 Soru)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'review_wrongs',
                child: Row(
                  children: [
                    const Icon(Icons.replay, color: AppTheme.blueTeam, size: 18),
                    const SizedBox(width: 8),
                    Text('Yanlışları Tekrar Et (${_service.wrongCount})'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'reset_stats',
                child: Row(
                  children: [
                    Icon(Icons.restart_alt, color: AppTheme.textMuted, size: 18),
                    SizedBox(width: 8),
                    Text('İstatistikleri Sıfırla'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Test / Sınav Akış Ekranı
          _isExamFinished ? _buildExamResultView() : _buildQuestionRunnerView(),

          // 2. Konu ve Kategori Bazlı Seçici
          _buildCategoryBrowserView(),

          // 3. Karar Ağaçları ve Lab Simülatörü
          _buildDecisionTreesView(),
        ],
      ),
    );
  }

  // =========================================================================
  // GÖRÜNÜM 1: SORU ÇÖZME AKIŞI
  // =========================================================================
  Widget _buildQuestionRunnerView() {
    if (_activeQuestions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, size: 48, color: AppTheme.sysAdmin),
              const SizedBox(height: 16),
              const Text(
                'Çözülecek Soru Bulunamadı',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Seçili filtrede henüz soru yok veya tüm yanlış soruları düzelttiniz!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.redTeam),
                icon: const Icon(Icons.refresh),
                label: const Text('20 Soruluk Sınav Başlat'),
                onPressed: () => _startNewExam(count: 20),
              ),
            ],
          ),
        ),
      );
    }

    final question = _activeQuestions[_currentIndex];
    final progress = (_currentIndex + 1) / _activeQuestions.length;
    final catColor = Color(question.category.colorHex);
    final diffColor = Color(question.difficulty.colorHex);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Üst İlerleme ve Sayaç Çubuğu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Soru ${_currentIndex + 1} / ${_activeQuestions.length}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: diffColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: diffColor.withAlpha(80)),
                    ),
                    child: Text(
                      question.difficulty.label,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: diffColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      _service.isBookmarked(question.id) ? Icons.bookmark : Icons.bookmark_border,
                      size: 20,
                      color: _service.isBookmarked(question.id) ? AppTheme.toolsAmber : AppTheme.textMuted,
                    ),
                    tooltip: 'Soruyu Kaydet',
                    onPressed: () => _service.toggleBookmark(question.id),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppTheme.bgCard,
              valueColor: AlwaysStoppedAnimation<Color>(catColor),
            ),
          ),
          const SizedBox(height: 14),

          // Kategori Rozeti ve Soru Kartı
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: catColor),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      question.category.label,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: catColor),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppTheme.bgDark,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        question.mitreId,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  question.question,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.white, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Seçenekler Listesi (A, B, C, D)
          ...List.generate(question.options.length, (idx) {
            final optionText = question.options[idx];
            final optionLetter = String.fromCharCode(65 + idx); // A, B, C, D

            Color borderColor = AppTheme.border;
            Color bgColor = AppTheme.bgCard;
            Widget? trailingIcon;

            if (_hasAnsweredCurrent) {
              if (idx == question.correctIndex) {
                // Doğru cevap
                borderColor = AppTheme.sysAdmin;
                bgColor = AppTheme.sysAdmin.withAlpha(30);
                trailingIcon = const Icon(Icons.check_circle, color: AppTheme.sysAdmin, size: 20);
              } else if (idx == _selectedOptionIndex) {
                // Seçilen yanlış cevap
                borderColor = AppTheme.redTeam;
                bgColor = AppTheme.redTeam.withAlpha(30);
                trailingIcon = const Icon(Icons.cancel, color: AppTheme.redTeam, size: 20);
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => _onAnswerSelected(idx),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.bgDark,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(
                          optionLetter,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          optionText,
                          style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.3),
                        ),
                      ),
                      if (trailingIcon != null) ...[
                        const SizedBox(width: 8),
                        trailingIcon,
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),

          // Cevaplandıktan Sonra Açılan Detaylı Teknik Açıklama Kartı
          if (_hasAnsweredCurrent) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF131A26),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.blueTeam.withAlpha(120)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.lightbulb_outline, color: AppTheme.toolsAmber, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Teknik Çözüm ve Operasyonel Analiz',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.toolsAmber),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    question.explanation,
                    style: const TextStyle(fontSize: 12.5, color: AppTheme.textPrimary, height: 1.45),
                  ),
                  if (question.relatedDocPath != null) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => _openRelatedDoc(question.relatedDocPath!),
                      child: Row(
                        children: const [
                          Icon(Icons.menu_book, color: AppTheme.blueTeam, size: 14),
                          SizedBox(width: 6),
                          Text(
                            'İlgili Cephanelik Dokümanını Oku ↗',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.blueTeam,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.blueTeam,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: Icon(_currentIndex + 1 < _activeQuestions.length ? Icons.arrow_forward : Icons.military_tech),
              label: Text(
                _currentIndex + 1 < _activeQuestions.length ? 'Sonraki Soruya Geç' : 'Sınavı Tamamla ve Sonuçları Gör',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              onPressed: _nextQuestion,
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // GÖRÜNÜM 2: KONU VE KATEGORİ SEÇİCİ
  // =========================================================================
  Widget _buildCategoryBrowserView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // İstatistik Özeti
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCol('${_service.totalAnswered}', 'Çözülen', AppTheme.blueTeam),
              _buildStatCol('${_service.totalCorrect}', 'Doğru', AppTheme.sysAdmin),
              _buildStatCol('%${(_service.successRate * 100).toStringAsFixed(0)}', 'Başarı', AppTheme.toolsAmber),
              _buildStatCol('${_service.wrongCount}', 'Hatalı', AppTheme.redTeam),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Text(
          'KATEGORİYE GÖRE ÇALIŞMA SETLERİ',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted, letterSpacing: 0.8),
        ),
        const SizedBox(height: 10),

        ...QuizCategory.values.map((cat) {
          final count = _service.getQuestionsByCategory(cat).length;
          final col = Color(cat.colorHex);

          return Card(
            color: AppTheme.bgCard,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppTheme.border),
            ),
            child: ListTile(
              leading: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: col),
              ),
              title: Text(cat.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: col.withAlpha(25), borderRadius: BorderRadius.circular(6)),
                child: Text('$count Soru', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: col)),
              ),
              onTap: () {
                setState(() {
                  _filterCategory = cat;
                  _activeQuestions = _service.getQuestionsByCategory(cat);
                  _currentIndex = 0;
                  _selectedOptionIndex = null;
                  _hasAnsweredCurrent = false;
                  _isExamFinished = false;
                  _tabController.index = 0;
                });
              },
            ),
          );
        }),
      ],
    );
  }

  // =========================================================================
  // GÖRÜNÜM 3: KARAR AĞAÇLARI (DECISION TREE LAB)
  // =========================================================================
  Widget _buildDecisionTreesView() {
    if (_activeTree == null || _currentNode == null) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _service.allScenarios.length,
        itemBuilder: (context, index) {
          final tree = _service.allScenarios[index];
          return Card(
            color: AppTheme.bgCard,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.redTeam.withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.account_tree, color: AppTheme.redTeam, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tree.title,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tree.targetGoal,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.redTeam,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: const Text('Simülasyonu Başlat'),
                      onPressed: () => _startDecisionTree(tree),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    // Aktif Düğüm Görünümü
    final node = _currentNode!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _activeTree!.title,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.toolsAmber),
              ),
              TextButton(
                child: const Text('Simülasyondan Çık', style: TextStyle(fontSize: 11, color: AppTheme.redTeam)),
                onPressed: () => setState(() => _activeTree = null),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Durum Paneli
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.blueTeam.withAlpha(120)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  node.title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.bgDark,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    node.environmentContext,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppTheme.toolsAmber),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  node.situation,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'BİR SONRAKİ TAKTİKSEL KARARINIZ NEDİR?',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted, letterSpacing: 0.8),
          ),
          const SizedBox(height: 10),

          // Seçenekler
          ...node.choices.map((choice) {
            final isSelected = _selectedChoice == choice;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () {
                  setState(() => _selectedChoice = choice);
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.blueTeam.withAlpha(25) : AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppTheme.blueTeam : AppTheme.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: isSelected ? AppTheme.blueTeam : AppTheme.textMuted,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          choice.choiceText,
                          style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // Seçim Yapıldığında Açılan Sonuç Paneli
          if (_selectedChoice != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _selectedChoice!.isOptimal ? const Color(0xFF0F2B26) : const Color(0xFF2D1217),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _selectedChoice!.isOptimal ? AppTheme.sysAdmin : AppTheme.redTeam,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _selectedChoice!.isOptimal ? Icons.check_circle : Icons.warning_amber,
                        color: _selectedChoice!.isOptimal ? AppTheme.sysAdmin : AppTheme.redTeam,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedChoice!.isOptimal ? 'Optimal Taktiksel Hamle' : 'Yüksek Risk / Hatalı Adım',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: _selectedChoice!.isOptimal ? AppTheme.sysAdmin : AppTheme.redTeam,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _selectedChoice!.outcomeDescription,
                    style: const TextStyle(fontSize: 12.5, color: Colors.white, height: 1.35),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Örnek Komut / İpucu: ${_selectedChoice!.commandTip}',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppTheme.toolsAmber),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (_selectedChoice!.nextNodeId != null)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.blueTeam,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Sonraki Aşamaya İlerle', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  setState(() {
                    _currentNode = _activeTree!.nodes[_selectedChoice!.nextNodeId];
                    _selectedChoice = null;
                  });
                },
              )
            else
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedChoice!.isOptimal ? AppTheme.sysAdmin : AppTheme.redTeam,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.refresh),
                label: Text(
                  _selectedChoice!.isOptimal ? 'Başarıyla Tamamlandı! (Yeniden Başlat)' : 'Senaryoyu Yeniden Başlat',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () => _startDecisionTree(_activeTree!),
              ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // GÖRÜNÜM 4: SINAV BİTİŞ VE SKOR KARTI
  // =========================================================================
  Widget _buildExamResultView() {
    final total = _activeQuestions.length;
    final correct = _sessionCorrect;
    final percent = total > 0 ? (correct / total) * 100 : 0.0;
    final isPassed = percent >= 70.0;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: (isPassed ? AppTheme.sysAdmin : AppTheme.redTeam).withAlpha(25),
                shape: BoxShape.circle,
                border: Border.all(color: isPassed ? AppTheme.sysAdmin : AppTheme.redTeam, width: 2),
              ),
              child: Icon(
                isPassed ? Icons.military_tech : Icons.sentiment_dissatisfied,
                size: 56,
                color: isPassed ? AppTheme.sysAdmin : AppTheme.redTeam,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isPassed ? 'TEBRİKLER! TESTİ BAŞARIYLA GEÇTİNİZ' : 'BİRAZ DAHA ÇALIŞMALISINIZ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isPassed ? AppTheme.sysAdmin : AppTheme.redTeam,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '%${percent.toStringAsFixed(1)} Başarı Oranı ($correct / $total Doğru)',
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.blueTeam,
                    side: const BorderSide(color: AppTheme.blueTeam),
                  ),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Tekrar Dene'),
                  onPressed: () => _startNewExam(count: total),
                ),
                if (_service.wrongCount > 0) ...[
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.redTeam,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.replay, size: 16),
                    label: Text('Yanlışları Çöz (${_service.wrongCount})'),
                    onPressed: _startWrongReview,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCol(String val, String label, Color col) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: col)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
      ],
    );
  }

  void _openRelatedDoc(String docPath) {
    final item = ContentService().findArticleItem(path: docPath);
    if (item != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArticleScreen(articleId: item.id, initialTitle: item.title),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Doküman yolu: $docPath')),
      );
    }
  }

  void _confirmResetStats() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('İstatistikleri Sıfırla', style: TextStyle(color: Colors.white)),
        content: const Text('Tüm test geçmişiniz ve yanlış soru kayıtlarınız silinecek. Onaylıyor musunuz?', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            child: const Text('İptal'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.redTeam),
            child: const Text('Sıfırla', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              Navigator.pop(ctx);
              await _service.resetStats();
            },
          ),
        ],
      ),
    );
  }
}
