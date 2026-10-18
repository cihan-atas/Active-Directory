import 'package:flutter/material.dart';
import '../models/content_models.dart';
import '../services/content_service.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import 'article_screen.dart';
import 'pillar_screen.dart';
import 'search_screen.dart';
import 'bookmarks_screen.dart';
import 'flashcards_screen.dart';
import 'scenarios_screen.dart';
import 'glossary_screen.dart';
import 'ai_setup_screen.dart';
import 'checklist_screen.dart';
import 'command_generator_screen.dart';
import 'quiz_screen.dart';
import 'scratchpad_screen.dart';
import '../services/command_service.dart';
import '../services/scratchpad_service.dart';
import '../widgets/tts_bar.dart';

class HomeScreen extends StatelessWidget {
  final ContentService contentService = ContentService();
  final AppState appState = AppState();

  HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final redTeamPillar = contentService.getPillarById('red_team');
    final blueTeamPillar = contentService.getPillarById('blue_team');
    final sysAdminPillar = contentService.getPillarById('sistem_yoneticisi');

    return ListenableBuilder(
      listenable: Listenable.merge([appState, ScratchpadService()]),
      builder: (context, _) {
        final totalArticles = contentService.searchIndex.length;
        final readCount = appState.readCount;
        final progressPercent = totalArticles > 0 ? (readCount / totalArticles) : 0.0;
        final cmdCount = CommandService().allCommands.length;
        final cmdLabel = cmdCount > 0
            ? '${cmdCount >= 1000 ? '${cmdCount ~/ 1000}.${(cmdCount % 1000).toString().padLeft(3, '0')}' : '$cmdCount'}+'
            : '3.300+';
        final lootCount = ScratchpadService().items.length;

        // Deterministik Günün Odak Noktaları
        final todaySeed = DateTime.now().day + DateTime.now().month * 31;
        final allArticles = contentService.searchIndex;
        final dailyArticle = allArticles.isNotEmpty
            ? allArticles[todaySeed % allArticles.length]
            : null;

        return Scaffold(
          backgroundColor: AppTheme.bgDark,
          appBar: AppBar(
            title: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.blueTeam.withAlpha(120), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.blueTeam.withAlpha(30),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 30,
                      height: 30,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Active Directory Hub',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.bookmark_outline, color: AppTheme.toolsAmber),
                tooltip: 'Yer İmleri',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BookmarksScreen()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'Arama',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  );
                },
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
                tooltip: 'Hızlı Araçlar',
                onSelected: (val) {
                  if (val == 'generator') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CommandGeneratorScreen()),
                    );
                  } else if (val == 'checklist') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChecklistScreen()),
                    );
                  } else if (val == 'scratchpad') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ScratchpadScreen()),
                    );
                  } else if (val == 'quiz') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QuizScreen()),
                    );
                  } else if (val == 'glossary') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GlossaryScreen()),
                    );
                  } else if (val == 'ai') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AiSetupScreen()),
                    );
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'generator',
                    child: Row(
                      children: [
                        Icon(Icons.terminal, color: AppTheme.redTeam, size: 18),
                        SizedBox(width: 10),
                        Text('Komut Oluşturucu'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'scratchpad',
                    child: Row(
                      children: [
                        Icon(Icons.shield_outlined, color: AppTheme.toolsAmber, size: 18),
                        SizedBox(width: 10),
                        Text('Ganimet & Karalama Defteri'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'checklist',
                    child: Row(
                      children: [
                        Icon(Icons.fact_check_outlined, color: AppTheme.sysAdmin, size: 18),
                        SizedBox(width: 10),
                        Text('Denetim & Pentest Listesi'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'quiz',
                    child: Row(
                      children: [
                        Icon(Icons.quiz_outlined, color: AppTheme.toolsAmber, size: 18),
                        SizedBox(width: 10),
                        Text('AD Lab & Sınav Simülatörü'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'glossary',
                    child: Row(
                      children: [
                        Icon(Icons.menu_book, color: AppTheme.blueTeam, size: 18),
                        SizedBox(width: 10),
                        Text('AD Sözlüğü'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'ai',
                    child: Row(
                      children: [
                        Icon(Icons.vpn_key_outlined, color: AppTheme.toolsAmber, size: 18),
                        SizedBox(width: 10),
                        Text('AI Asistanı & Anahtarlar'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          bottomNavigationBar: const TtsPlayerBar(),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Arama Çubuğu
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderHighlight),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.search, color: AppTheme.textMuted, size: 22),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Araç, teknik veya Event ID ara... (Çevrimdışı)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                          ),
                        ),
                        Icon(Icons.tune, color: AppTheme.redTeam, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Hero Continue / Kurs İlerleme Kartı
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E2838), Color(0xFF111827)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.blueTeam.withAlpha(90), width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.trending_up, color: AppTheme.blueTeam, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'ÖĞRENME VE OKUMA İLERLEMESİ',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.blueTeam,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '%${(progressPercent * 100).toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progressPercent > 0 ? progressPercent : 0.02,
                          minHeight: 8,
                          backgroundColor: AppTheme.bgDark,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.blueTeam),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$readCount / $totalArticles Konu Tamamlandı',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                          if (appState.lastReadId != null)
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ArticleScreen(
                                      articleId: appState.lastReadId!,
                                      initialTitle: appState.lastReadTitle,
                                    ),
                                  ),
                                );
                              },
                              child: Row(
                                children: const [
                                  Text(
                                    'Kaldığın Yerden Devam Et',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.blueTeam,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.arrow_forward, size: 14, color: AppTheme.blueTeam),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 4 Cyber Metrik Sayacı
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricItem('$readCount', 'Okunan', AppTheme.blueTeam),
                      _buildMetricDivider(),
                      _buildMetricItem('146', 'Araç', AppTheme.redTeam),
                      _buildMetricDivider(),
                      _buildMetricItem('${appState.masteredCardsCount}', 'Usta Kart', AppTheme.sysAdmin),
                      _buildMetricDivider(),
                      _buildMetricItem('${appState.bookmarkedCount}', 'Yer İmi', AppTheme.toolsAmber),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ⚡ İnteraktif Komut Oluşturucu (Generator) Banner
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CommandGeneratorScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2D1217), Color(0xFF131A26)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.redTeam.withAlpha(160), width: 1.2),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.redTeam.withAlpha(40),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.redTeam),
                          ),
                          child: const Icon(Icons.terminal, color: AppTheme.redTeam, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      '⚡ KOMUT OLUŞTURUCU',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: AppTheme.redTeam,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(cmdLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'Dinamik Yer Tutucular · Topluluk Paketleri · Özel Komutlarım',
                                style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppTheme.redTeam),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 📋 Sızma Testi & Denetim Kontrol Listesi Banner
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChecklistScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F2B26), Color(0xFF131A26)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.sysAdmin.withAlpha(160), width: 1.2),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.sysAdmin.withAlpha(40),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.sysAdmin),
                          ),
                          child: const Icon(Icons.fact_check_outlined, color: AppTheme.sysAdmin, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      '📋 SIZMA TESTİ & DENETİM',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: AppTheme.sysAdmin,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('CRTP / OSCP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                '8 Faz · 45+ Madde · Hedef Notları · Rapor Dışa Aktar',
                                style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppTheme.sysAdmin),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ⚔️ Operasyonel Ganimet & Karalama Defteri (Loot Manager) Banner
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ScratchpadScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF261D12), Color(0xFF131A26)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.toolsAmber.withAlpha(160), width: 1.2),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.toolsAmber.withAlpha(40),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.toolsAmber),
                          ),
                          child: const Icon(Icons.shield_outlined, color: AppTheme.toolsAmber, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      '⚔️ GANİMET & LOOT DEFTERİ',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: AppTheme.toolsAmber,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '$lootCount Loot',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'Kimlikler · Hash\'ler · IP\'ler · Tek Tıkla Komut Motoruna Aktar',
                                style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppTheme.toolsAmber),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // 4-Way Cyber Action Hub (Hızlı Erişim Grid'i)
                const Text(
                  'CYBER EYLEM VE ÇALIŞMA MERKEZİ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMuted,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 10),

                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.35,
                  children: [
                    // 1. Cephanelik (Modül 11)
                    _buildHubTile(
                      context: context,
                      title: 'Saldırı Cephaneliği',
                      subtitle: '18 Kategori · 146 Araç',
                      icon: Icons.flash_on,
                      color: AppTheme.redTeam,
                      onTap: () {
                        if (redTeamPillar != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PillarScreen(pillar: redTeamPillar),
                            ),
                          );
                        }
                      },
                    ),
                    // 2. AD Flashcards (SRS)
                    _buildHubTile(
                      context: context,
                      title: 'AD Akıllı Kartlar',
                      subtitle: 'Leitner 3D Çevirmeli',
                      icon: Icons.style,
                      color: AppTheme.toolsAmber,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FlashcardsScreen(),
                          ),
                        );
                      },
                    ),
                    // 3. Sınav Simülatörü (CRTP/OSCP)
                    _buildHubTile(
                      context: context,
                      title: 'Sınav Simülatörü',
                      subtitle: '100+ CRTP/OSCP Sorusu',
                      icon: Icons.quiz,
                      color: AppTheme.redTeam,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const QuizScreen(),
                          ),
                        );
                      },
                    ),
                    // 4. Saldırı Senaryoları (Kill Chain)
                    _buildHubTile(
                      context: context,
                      title: 'Saldırı Senaryoları',
                      subtitle: 'Kill Chain Yolları',
                      icon: Icons.timeline,
                      color: AppTheme.blueTeam,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ScenariosScreen(),
                          ),
                        );
                      },
                    ),
                    // 5. Karar Ağaçları & Lab
                    _buildHubTile(
                      context: context,
                      title: 'Karar Ağaçları & Lab',
                      subtitle: 'Operasyonel Simülatör',
                      icon: Icons.account_tree,
                      color: const Color(0xFF10B981),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const QuizScreen(),
                          ),
                        );
                      },
                    ),
                    // 6. Terimler Sözlüğü (Glossary)
                    _buildHubTile(
                      context: context,
                      title: 'AD Sözlüğü',
                      subtitle: 'Protokol & Kavramlar',
                      icon: Icons.menu_book,
                      color: AppTheme.sysAdmin,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const GlossaryScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // AI Asistan & Anahtar Yönetimi Hızlı Erişim Kartı
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AiSetupScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131A26),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.toolsAmber.withAlpha(90)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.toolsAmber.withAlpha(25),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.vpn_key, color: AppTheme.toolsAmber, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'AI Siber Asistan & Anahtar Yönetimi',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Gemini, Groq, OpenRouter API anahtarlarınızı yönetin',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 13, color: AppTheme.toolsAmber),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Günün Odak Noktası (Daily Spotlight)
                if (dailyArticle != null) ...[
                  const Text(
                    'GÜNÜN ODAK NOKTASI',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMuted,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    color: const Color(0xFF161F2E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFF23354E), width: 1.2),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ArticleScreen(
                              articleId: dailyArticle.id,
                              initialTitle: dailyArticle.title,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.blueTeam.withAlpha(30),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.wb_sunny, color: AppTheme.blueTeam, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dailyArticle.category.isNotEmpty
                                        ? dailyArticle.category
                                        : 'Günün Konusu',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.blueTeam,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    dailyArticle.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Ana Sütunlar
                const Text(
                  'ANA MODÜL SÜTUNLARI',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMuted,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),

                // 1. Red Team
                if (redTeamPillar != null)
                  _buildPillarCard(
                    context: context,
                    pillar: redTeamPillar,
                    icon: Icons.security,
                    badge: '11 Modül',
                    highlightColor: AppTheme.redTeam,
                    description: 'Keşif, Kerberos, RBCD, ACL/GPO İstismarı, DCSync, Domain Hakimiyeti & Modül 11 Araç Cephaneliği.',
                  ),
                const SizedBox(height: 12),

                // 2. Blue Team
                if (blueTeamPillar != null)
                  _buildPillarCard(
                    context: context,
                    pillar: blueTeamPillar,
                    icon: Icons.shield,
                    badge: '10 Modül',
                    highlightColor: AppTheme.blueTeam,
                    description: 'Görünürlük, SIEM, Tespit Mühendisliği, Kerberos Sertleştirme, Protokol Koruma & DFIR.',
                  ),
                const SizedBox(height: 12),

                // 3. Sistem Yöneticisi
                if (sysAdminPillar != null)
                  _buildPillarCard(
                    context: context,
                    pillar: sysAdminPillar,
                    icon: Icons.dns,
                    badge: '10 Modül',
                    highlightColor: AppTheme.sysAdmin,
                    description: 'Active Directory Temelleri, Fiziksel Altyapı, Replikasyon, GPO, DNS, PKI ve Hibrit Kimlik.',
                  ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricItem(String val, String label, Color col) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: col)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
      ],
    );
  }

  Widget _buildMetricDivider() {
    return Container(height: 20, width: 1, color: AppTheme.border);
  }

  Widget _buildHubTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      color: AppTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillarCard({
    required BuildContext context,
    required Pillar pillar,
    required IconData icon,
    required String badge,
    required Color highlightColor,
    required String description,
  }) {
    return Card(
      color: AppTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PillarScreen(pillar: pillar),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: highlightColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: highlightColor.withAlpha(60), width: 1),
                    ),
                    child: Icon(icon, color: highlightColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pillar.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          pillar.subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: highlightColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: highlightColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
