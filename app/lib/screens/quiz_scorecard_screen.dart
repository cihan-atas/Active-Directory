import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/quiz_models.dart';
import '../services/quiz_service.dart';
import '../theme/app_theme.dart';

/// Sınav Karnesi & Yetenek Radar Grafiği (Skill Gap Analysis Screen)
class QuizScorecardScreen extends StatefulWidget {
  final Function(String title, List<QuizQuestion> questions)? onStartCustomExam;

  const QuizScorecardScreen({
    super.key,
    this.onStartCustomExam,
  });

  @override
  State<QuizScorecardScreen> createState() => _QuizScorecardScreenState();
}

class _QuizScorecardScreenState extends State<QuizScorecardScreen> {
  final QuizService _quizService = QuizService();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _quizService,
      builder: (context, _) {
        final stats = _quizService.getSkillGapAnalysis();
        final totalQuestions = _quizService.allQuestions.length;
        final answered = _quizService.totalAnswered;
        final correct = _quizService.totalCorrect;
        final overallRate = answered > 0 ? ((correct / answered) * 100.0) : 0.0;

        // En zayıf ve en güçlü kategorileri bul
        final attempted = stats.where((s) => s.hasAttempted).toList();
        attempted.sort((a, b) => a.scorePercent.compareTo(b.scorePercent));
        final weakest = attempted.isNotEmpty && attempted.first.scorePercent < 60 ? attempted.first : null;
        final strongest = attempted.isNotEmpty && attempted.last.scorePercent >= 70 ? attempted.last : null;

        return Scaffold(
          backgroundColor: AppTheme.bgDark,
          appBar: AppBar(
            title: const Text('📊 Sınav Karnesi & Yetenek Radarı'),
            backgroundColor: AppTheme.bgCard,
            elevation: 0,
            actions: [
              IconButton(
                tooltip: 'İstatistikleri Sıfırla',
                icon: const Icon(Icons.refresh, color: AppTheme.textMuted),
                onPressed: () => _confirmResetStats(),
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 950),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Genel Başarı Kartı
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E2838), Color(0xFF101726)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.blueTeam.withAlpha(120), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          // Başarı Yüzdesi Dairesel İlerleme
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 72,
                                height: 72,
                                child: CircularProgressIndicator(
                                  value: answered > 0 ? (correct / answered) : 0.0,
                                  strokeWidth: 6,
                                  backgroundColor: AppTheme.bgDark,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    overallRate >= 75 ? const Color(0xFF10B981) : (overallRate >= 50 ? AppTheme.toolsAmber : AppTheme.redTeam),
                                  ),
                                ),
                              ),
                              Text(
                                '%${overallRate.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'GENEL HAZIRLIK VE YETENEK DÜZEYİ',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.blueTeam, letterSpacing: 0.8),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getReadinessTitle(overallRate, answered),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$answered / $totalQuestions Soru Çözüldü · $correct Doğru · ${_quizService.wrongCount} Hatalı',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Radar Grafiği Kartı
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.radar, color: AppTheme.toolsAmber, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    '11 KATEGORİ YETENEK RADARI',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.8),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.toolsAmber.withAlpha(20),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Skill Gap Visualizer',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.toolsAmber),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Özel Radar Canvas Grafiği
                          SizedBox(
                            height: 280,
                            child: CustomPaint(
                              painter: RadarChartPainter(stats: stats),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Zayıf / Güçlü Taktik İpucu
                          if (weakest != null) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.redTeam.withAlpha(15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.redTeam.withAlpha(60)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: AppTheme.redTeam, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'En çok açık görülen konu: ${weakest.category.label} (%${weakest.scorePercent.toStringAsFixed(0)}). Bu konuya odaklanmanız önerilir.',
                                      style: const TextStyle(fontSize: 11.5, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (strongest != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withAlpha(15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF10B981).withAlpha(60)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.verified, color: Color(0xFF10B981), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'En güçlü olduğunuz alan: ${strongest.category.label} (%${strongest.scorePercent.toStringAsFixed(0)}). Tebrikler!',
                                      style: const TextStyle(fontSize: 11.5, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Kategori Karneleri ve "Çalış" Butonları
                    const Text(
                      'KATEGORİ BAZLI DETAYLI KARNE & EYLEMLER',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 10),

                    ...stats.map((s) => _buildCategoryScoreCard(s)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _getReadinessTitle(double rate, int answered) {
    if (answered < 10) return 'Başlangıç Aşaması (Daha Fazla Test Çözün)';
    if (rate >= 85) return 'CRTP / OSCP Seviyesinde Üstün Yetenek';
    if (rate >= 70) return 'İyi Düzeyde Operasyonel Bilgi';
    if (rate >= 50) return 'Orta Düzey (Eksik Konular Mevcut)';
    return 'Geliştirilmeli (Açık Analizine Odaklanın)';
  }

  Widget _buildCategoryScoreCard(CategorySkillStats s) {
    final col = s.hasAttempted
        ? (s.scorePercent >= 75 ? const Color(0xFF10B981) : (s.scorePercent >= 50 ? AppTheme.toolsAmber : AppTheme.redTeam))
        : AppTheme.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: col.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(s.category.icon, size: 18, color: col),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.category.label,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.hasAttempted
                          ? '${s.answeredCount} Çözüldü · ${s.correctCount} Doğru · ${s.wrongCount} Yanlış (${s.totalQuestions} Toplam Soru)'
                          : 'Henüz bu kategoriden soru çözülmedi (${s.totalQuestions} Soru Hazır)',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: col.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: col.withAlpha(90)),
                ),
                child: Text(
                  s.hasAttempted ? '%${s.scorePercent.toStringAsFixed(0)}' : 'Çözülmedi',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: col),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // İlerleme Çubuğu
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: s.hasAttempted ? (s.scorePercent / 100.0) : 0.02,
              minHeight: 5,
              backgroundColor: AppTheme.bgDark,
              valueColor: AlwaysStoppedAnimation<Color>(col),
            ),
          ),
          const SizedBox(height: 10),

          // Çalış Butonları
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.toolsAmber.withAlpha(120)),
                  foregroundColor: AppTheme.toolsAmber,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.play_arrow, size: 14),
                label: const Text('Bu Konuyu Çöz', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: () {
                  final catQuestions = _quizService.getQuestionsByCategory(s.category);
                  if (catQuestions.isNotEmpty) {
                    Navigator.pop(context);
                    widget.onStartCustomExam?.call('${s.category.label} Özel Çalışma', catQuestions);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmResetStats() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('İstatistikleri Sıfırla?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Tüm çözülen soru geçmişiniz, doğru/yanlış sayaçlarınız ve karne verileriniz sıfırlanacaktır. Bu işlem geri alınamaz.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.redTeam),
            onPressed: () async {
              Navigator.pop(ctx);
              await _quizService.resetStats();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sınav karnesi ve yetenek istatistikleri sıfırlandı.')),
                );
              }
            },
            child: const Text('Sıfırla', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

/// Özel Radar / Örümcek Grafiği Çizicisi (RadarChartPainter)
class RadarChartPainter extends CustomPainter {
  final List<CategorySkillStats> stats;

  RadarChartPainter({required this.stats});

  @override
  void paint(Canvas canvas, Size size) {
    if (stats.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2.35;
    final numAxes = stats.length;
    final angleStep = (2 * math.pi) / numAxes;

    final gridPaint = Paint()
      ..color = AppTheme.border.withAlpha(160)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final axisPaint = Paint()
      ..color = AppTheme.borderHighlight.withAlpha(100)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 1. Arka Plan Poligon Halkaları (20%, 40%, 60%, 80%, 100%)
    const ringLevels = [0.2, 0.4, 0.6, 0.8, 1.0];
    for (final level in ringLevels) {
      final ringPath = Path();
      for (int i = 0; i < numAxes; i++) {
        final angle = -math.pi / 2 + (i * angleStep);
        final r = radius * level;
        final x = center.dx + r * math.cos(angle);
        final y = center.dy + r * math.sin(angle);
        if (i == 0) {
          ringPath.moveTo(x, y);
        } else {
          ringPath.lineTo(x, y);
        }
      }
      ringPath.close();
      canvas.drawPath(ringPath, gridPaint);
    }

    // 2. Eksen Çizgileri ve Etiketler
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < numAxes; i++) {
      final angle = -math.pi / 2 + (i * angleStep);
      final ex = center.dx + radius * math.cos(angle);
      final ey = center.dy + radius * math.sin(angle);
      canvas.drawLine(center, Offset(ex, ey), axisPaint);

      // Etiket metni
      final label = stats[i].category.label.split(' ').first;
      textPainter.text = TextSpan(
        text: label,
        style: const TextStyle(fontSize: 9, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
      );
      textPainter.layout();
      final lx = center.dx + (radius + 14) * math.cos(angle) - (textPainter.width / 2);
      final ly = center.dy + (radius + 14) * math.sin(angle) - (textPainter.height / 2);
      textPainter.paint(canvas, Offset(lx, ly));
    }

    // 3. Kullanıcı Yetenek Poligonu (User Skill Polygon)
    final skillPath = Path();
    final points = <Offset>[];

    for (int i = 0; i < numAxes; i++) {
      final angle = -math.pi / 2 + (i * angleStep);
      // Eğer hiç çözülmemişse minik %15 referans ver, çözülmüşse başarı yüzdesini kullan
      final score = stats[i].hasAttempted ? (stats[i].scorePercent / 100.0) : 0.12;
      final clamped = math.max(0.1, math.min(1.0, score));
      final r = radius * clamped;
      final px = center.dx + r * math.cos(angle);
      final py = center.dy + r * math.sin(angle);
      points.add(Offset(px, py));

      if (i == 0) {
        skillPath.moveTo(px, py);
      } else {
        skillPath.lineTo(px, py);
      }
    }
    skillPath.close();

    // Dolgu (Fill)
    final fillPaint = Paint()
      ..color = const Color(0xFF10B981).withAlpha(45)
      ..style = PaintingStyle.fill;
    canvas.drawPath(skillPath, fillPaint);

    // Çerçeve (Stroke)
    final strokePaint = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(skillPath, strokePaint);

    // Nokta İmleri (Dots)
    final dotPaint = Paint()..color = AppTheme.toolsAmber;
    for (final pt in points) {
      canvas.drawCircle(pt, 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant RadarChartPainter oldDelegate) {
    return oldDelegate.stats != stats;
  }
}
