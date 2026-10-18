import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/flashcard_models.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen>
    with SingleTickerProviderStateMixin {
  final AppState _appState = AppState();
  late AnimationController _animController;
  late Animation<double> _animation;

  String _selectedCategory = 'all';
  int _currentIndex = 0;
  bool _isFlipped = false;
  List<Flashcard> _deck = [];

  final List<String> _categories = ['all', 'Event ID', 'Araç & Komut', 'AD Kavramı'];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _filterDeck();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _filterDeck() {
    setState(() {
      if (_selectedCategory == 'all') {
        _deck = List.from(kDefaultFlashcards);
      } else {
        _deck = kDefaultFlashcards.where((c) => c.category == _selectedCategory).toList();
      }
      _currentIndex = 0;
      _isFlipped = false;
      _animController.reset();
    });
  }

  void _flipCard() {
    if (_isFlipped) {
      _animController.reverse();
    } else {
      _animController.forward();
    }
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  void _nextCard({required bool correct}) async {
    if (_deck.isEmpty) return;
    final card = _deck[_currentIndex];
    await _appState.answerCard(card.id, correct: correct);

    if (_isFlipped) {
      _animController.reverse();
      _isFlipped = false;
    }

    setState(() {
      if (_currentIndex + 1 < _deck.length) {
        _currentIndex++;
      } else {
        _currentIndex = 0;
      }
    });
  }

  Color _getCategoryColor(String cat) {
    switch (cat) {
      case 'Event ID':
        return AppTheme.blueTeam;
      case 'Araç & Komut':
        return AppTheme.redTeam;
      case 'AD Kavramı':
        return AppTheme.sysAdmin;
      default:
        return AppTheme.toolsAmber;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentCard = _deck.isNotEmpty ? _deck[_currentIndex] : null;
    final currentBox = currentCard != null ? _appState.getCardBox(currentCard.id) : 1;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('AD Akıllı Kartlar (SRS)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shuffle),
            tooltip: 'Kartları Karıştır',
            onPressed: () {
              setState(() {
                _deck.shuffle();
                _currentIndex = 0;
                if (_isFlipped) {
                  _animController.reverse();
                  _isFlipped = false;
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Kategori Filtreleri
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                final label = cat == 'all' ? 'Tümü' : cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(label),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                    ),
                    backgroundColor: AppTheme.bgCard,
                    selectedColor: AppTheme.blueTeam.withAlpha(80),
                    side: BorderSide(
                      color: isSelected ? AppTheme.blueTeam : AppTheme.border,
                    ),
                    onSelected: (val) {
                      setState(() => _selectedCategory = cat);
                      _filterDeck();
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // İlerleme ve Kutu Bilgisi
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Kart: ${_deck.isNotEmpty ? _currentIndex + 1 : 0} / ${_deck.length}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Leitner Kutuları (1..5)
                Row(
                  children: [
                    const Text('Seviye: ',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    for (int i = 1; i <= 5; i++)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i <= currentBox
                              ? AppTheme.sysAdmin
                              : AppTheme.borderHighlight,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 3D Çevirmeli Flashcard
          Expanded(
            child: currentCard == null
                ? const Center(child: Text('Kart bulunamadı.'))
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: GestureDetector(
                      onTap: _flipCard,
                      child: AnimatedBuilder(
                        animation: _animation,
                        builder: (context, child) {
                          final angle = _animation.value * math.pi;
                          final isUnder = angle > (math.pi / 2);

                          return Transform(
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001) // 3D Derinlik perspektifi
                              ..rotateY(angle),
                            alignment: Alignment.center,
                            child: isUnder
                                ? Transform(
                                    transform: Matrix4.identity()..rotateY(math.pi),
                                    alignment: Alignment.center,
                                    child: _buildBackCard(currentCard),
                                  )
                                : _buildFrontCard(currentCard),
                          );
                        },
                      ),
                    ),
                  ),
          ),

          // Alt Yanıt Butonları (Biliyorum / Tekrar Et)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C1318),
                      foregroundColor: AppTheme.redTeam,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppTheme.redTeam, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.refresh, size: 20),
                    label: const Text(
                      'Tekrar Et (Kutu 1)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    onPressed: () => _nextCard(correct: false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF132A1F),
                      foregroundColor: AppTheme.sysAdmin,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppTheme.sysAdmin, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    label: const Text(
                      'Biliyorum (+1)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    onPressed: () => _nextCard(correct: true),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrontCard(Flashcard card) {
    final catColor = _getCategoryColor(card.category);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: catColor.withAlpha(100), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: catColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  card.category,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: catColor,
                  ),
                ),
              ),
              const Icon(Icons.touch_app, color: AppTheme.textMuted, size: 20),
            ],
          ),
          const Spacer(),
          Text(
            card.question,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.45,
            ),
          ),
          const Spacer(),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.flip_camera_android, size: 16, color: AppTheme.textMuted),
                SizedBox(width: 6),
                Text(
                  'Cevabı görmek için karta dokunun',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackCard(Flashcard card) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF131926),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.sysAdmin.withAlpha(120), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.sysAdmin.withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'CEVAP VE AÇIKLAMA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.sysAdmin,
                    ),
                  ),
                ),
                const Icon(Icons.check, color: AppTheme.sysAdmin, size: 20),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              card.answer,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              card.explanation,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppTheme.textSecondary,
                height: 1.45,
              ),
            ),
            if (card.commandExample != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.bgCode,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  card.commandExample!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFF38BDF8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
