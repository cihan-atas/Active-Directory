import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/ai_service.dart';
import '../services/content_service.dart';
import '../services/link_navigation_service.dart';
import '../theme/app_theme.dart';
import '../widgets/code_block_builder.dart';
import 'ai_setup_screen.dart';
import 'checklist_screen.dart';
import 'command_generator_screen.dart';
import 'flashcards_screen.dart';
import 'glossary_screen.dart';
import 'model_picker_sheet.dart';
import 'bookmarks_screen.dart';
import 'quiz_screen.dart';
import 'scenarios_screen.dart';
import 'scratchpad_screen.dart';
import 'search_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AiService _ai = AiService();
  final ContentService _content = ContentService();

  @override
  void initState() {
    super.initState();
    _ai.addListener(_onAiChanged);
  }

  @override
  void dispose() {
    _ai.removeListener(_onAiChanged);
    super.dispose();
  }

  void _onAiChanged() {
    if (mounted) setState(() {});
  }

  void _showSavedChatsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SavedChatsViewerModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeKey = _ai.activeKey;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.settings, color: AppTheme.toolsAmber, size: 22),
            SizedBox(width: 8),
            Text('Ayarlar ve Cephanelik Merkezi'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // ==========================================
          // 1. AI ENTEGRASYONU VE ANAHTAR DURUMU
          // ==========================================
          _buildSectionHeader('AI GÜVENLİK ASİSTANI YAPILANDIRMASI', Icons.auto_awesome, AppTheme.blueTeam),
          const SizedBox(height: 8),
          Card(
            color: AppTheme.bgCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: (_ai.isConfigured ? AppTheme.blueTeam : AppTheme.textMuted).withAlpha(25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _ai.isConfigured ? Icons.check_circle : Icons.warning_amber_rounded,
                              color: _ai.isConfigured ? AppTheme.blueTeam : AppTheme.textMuted,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _ai.isConfigured ? 'AI Servisi Aktif' : 'AI Yapılandırılmadı',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              Text(
                                _ai.isConfigured
                                    ? '${activeKey?.provider.label} · ${activeKey?.activeModel}'
                                    : 'İsteğe bağlı Gemini, Groq veya OpenRouter anahtarı ekleyin',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.blueTeam,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.vpn_key, size: 16),
                          label: const Text('Anahtar Yöneticisi', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AiSetupScreen()),
                            );
                          },
                        ),
                      ),
                      if (_ai.isConfigured && activeKey != null) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.blueTeam,
                            side: const BorderSide(color: AppTheme.blueTeam),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.smart_toy_outlined, size: 16),
                          label: const Text('Model Seç'),
                          onPressed: () async {
                            await showModelPickerSheet(context, keyObj: activeKey);
                            setState(() {});
                          },
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ==========================================
          // 2. KAYITLI AI SOHBETLERİ
          // ==========================================
          _buildSectionHeader('KAYITLI AI SOHBETLERİ', Icons.bookmark, AppTheme.toolsAmber),
          const SizedBox(height: 8),
          Card(
            color: AppTheme.bgCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.border),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.toolsAmber.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.history, color: AppTheme.toolsAmber, size: 20),
              ),
              title: const Text('Soru-Cevap Geçmişi', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
              subtitle: Text(
                _ai.savedChats.isEmpty
                  ? 'Henüz kaydedilmiş sohbet yok'
                  : '${_ai.savedChats.length} adet kayıtlı analiz ve taktiksel soru',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
              onTap: () => _showSavedChatsSheet(context),
            ),
          ),
          const SizedBox(height: 20),

          // ==========================================
          // 3. HIZLI ARAMA VE EĞİTİM ARAÇLARI
          // ==========================================
          _buildSectionHeader('ARAMA VE ETKİLEŞİMLİ ARAÇLAR', Icons.explore, AppTheme.sysAdmin),
          const SizedBox(height: 8),
          Card(
            color: AppTheme.bgCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.border),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.search, color: AppTheme.toolsAmber),
                  title: const Text('Genel İçerik ve Doküman Arama', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                  subtitle: const Text('Tüm makaleleri, araçları ve sızma testi modüllerini arayın', style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.tune, color: AppTheme.redTeam),
                  title: const Text('İnteraktif Komut Oluşturucu', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                  subtitle: const Text('3.300+ komutu hedef IP ve etki alanı parametreleriyle anında derleyin', style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CommandGeneratorScreen()),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.fact_check_outlined, color: AppTheme.sysAdmin),
                  title: const Text('Sızma Testi ve Denetim Kontrol Listesi', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                  subtitle: const Text('CRTP & OSCP uyumlu 8 taktiksel faz, yerel profil takibi ve raporlama', style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChecklistScreen()),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.shield_outlined, color: AppTheme.redTeam),
                  title: const Text('⚔️ Ganimet ve Karalama Defteri (Loot Manager)', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                  subtitle: const Text('Hedef IP, kullanıcı, parola ve biletleri yerel saklayın; tek tıkla komut motoruna aktarın', style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ScratchpadScreen()),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.style, color: AppTheme.blueTeam),
                  title: const Text('AD Akıllı Kartlar (Flashcards)', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                  subtitle: const Text('Event ID, komutlar ve AD kavramlarını soru-cevap kartlarıyla pekiştirin', style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FlashcardsScreen()),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.quiz_outlined, color: AppTheme.toolsAmber),
                  title: const Text('🎯 AD Lab & Sınav Simülatörü (CRTP/OSCP)', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                  subtitle: const Text('100+ soru, açıklamalı çözümler ve senaryo bazlı karar ağaçları ile kendinizi test edin', style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QuizScreen()),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.menu_book, color: Color(0xFFA855F7)),
                  title: const Text('AD Terimler ve Kavramlar Sözlüğü', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                  subtitle: const Text('50+ Active Directory protokolü ve güvenlik teriminin detaylı açıklamaları', style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GlossaryScreen()),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.hub_outlined, color: AppTheme.redTeam),
                  title: const Text('Operasyonel Senaryolar & Lab', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                  subtitle: const Text('Uçtan uca sızma testi zincirleri, saldırı grafiği ve lab adımları', style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ScenariosScreen()),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.bookmark_outline, color: AppTheme.toolsAmber),
                  title: const Text('Kayıtlı Yer İmleri & Favoriler', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                  subtitle: const Text('Daha sonra incelemek üzere kaydettiğiniz makaleler ve notlar', style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BookmarksScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ==========================================
          // 4. ÇEVRİMD IŞI CEPHANELİK VERİTABANI
          // ==========================================
          _buildSectionHeader('ÇEVRİMD IŞI CEPHANELİK VERİTABANI', Icons.storage, AppTheme.redTeam),
          const SizedBox(height: 8),
          Card(
            color: AppTheme.bgCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn(
                        '${_content.searchIndex.isNotEmpty ? _content.searchIndex.length : (_content.stats['total_articles'] ?? 316)}+',
                        'Doküman',
                        AppTheme.redTeam,
                      ),
                      Container(height: 35, width: 1, color: AppTheme.border),
                      _buildStatColumn('3.333+', 'Komut', AppTheme.blueTeam),
                      Container(height: 35, width: 1, color: AppTheme.border),
                      _buildStatColumn('%100', 'Çevrimdışı', AppTheme.sysAdmin),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    children: const [
                      Icon(Icons.offline_pin, size: 16, color: AppTheme.sysAdmin),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tüm dokümanlar, saldırı playbook\'ları ve komutlar cihazınızda yerel olarak saklanır. İnternet bağlantısı gerektirmez.',
                          style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ==========================================
          // 5. UYGULAMA BİLGİSİ
          // ==========================================
          Center(
            child: Column(
              children: const [
                Text(
                  'Active Directory Vault · Sürüm 2.1.0',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                ),
                SizedBox(height: 4),
                Text(
                  'Kırmızı Takım & Mavi Takım Operasyonel Cephanelik',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatColumn(String val, String label, Color color) {
    return Column(
      children: [
        Text(
          val,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

class _SavedChatsViewerModal extends StatefulWidget {
  @override
  State<_SavedChatsViewerModal> createState() => _SavedChatsViewerModalState();
}

class _SavedChatsViewerModalState extends State<_SavedChatsViewerModal> {
  final AiService _ai = AiService();
  SavedAiChat? _viewingChat;

  @override
  Widget build(BuildContext context) {
    final chats = _ai.savedChats;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(18),
        child: _viewingChat != null
            ? _buildChatDetail(_viewingChat!)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.bookmark, color: AppTheme.toolsAmber, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Kayıtlı AI Sohbetleri',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      if (chats.isNotEmpty)
                        TextButton.icon(
                          style: TextButton.styleFrom(foregroundColor: AppTheme.redTeam),
                          icon: const Icon(Icons.delete_sweep, size: 16),
                          label: const Text('Tümünü Temizle', style: TextStyle(fontSize: 12)),
                          onPressed: () async {
                            await _ai.clearAllChats();
                            setState(() {});
                          },
                        ),
                    ],
                  ),
                  const Divider(height: 16),
                  if (chats.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Henüz kayıtlı bir AI sohbetiniz yok.\nBir makalede soru sorduktan sonra kaydet butonuna dokunabilirsiniz.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.4),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: chats.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final chat = chats[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: AppTheme.bgCode,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: ListTile(
                              title: Text(
                                chat.prompt,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    chat.articleTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: AppTheme.blueTeam.withAlpha(30),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: Text(
                                          chat.model,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontFamily: 'monospace',
                                            color: AppTheme.blueTeam,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${chat.timestamp.day}.${chat.timestamp.month}.${chat.timestamp.year} ${chat.timestamp.hour.toString().padLeft(2, '0')}:${chat.timestamp.minute.toString().padLeft(2, '0')}',
                                        style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.textMuted),
                                onPressed: () async {
                                  await _ai.deleteChat(chat.id);
                                  setState(() {});
                                },
                              ),
                              onTap: () {
                                setState(() => _viewingChat = chat);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildChatDetail(SavedAiChat chat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              onPressed: () => setState(() => _viewingChat = null),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                chat.articleTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: AppTheme.textMuted),
              tooltip: 'Tüm Yanıtı Kopyala',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: 'SORU:\n${chat.prompt}\n\nYANIT:\n${chat.response}'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Soru ve yanıt kopyalandı!')),
                );
              },
            ),
          ],
        ),
        const Divider(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCardHover,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderHighlight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SORULAN SORU',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.toolsAmber),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        chat.prompt,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                MarkdownBody(
                  data: chat.response,
                  selectable: true,
                  builders: {
                    'code': CodeElementBuilder(context),
                  },
                  onTapLink: (text, href, title) {
                    LinkNavigationHelper.handleLinkTap(
                      context: context,
                      href: href,
                      text: text,
                    );
                  },
                  styleSheet: MarkdownStyleSheet(
                    a: const TextStyle(
                      color: AppTheme.blueTeam,
                      decoration: TextDecoration.underline,
                      decorationColor: Color(0x9958A6FF),
                      fontWeight: FontWeight.w600,
                    ),
                    p: const TextStyle(fontSize: 13.5, color: AppTheme.textPrimary, height: 1.5),
                    h1: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, height: 1.4),
                    h2: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.blueTeam, height: 1.4),
                    h3: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppTheme.toolsAmber, height: 1.3),
                    code: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, backgroundColor: Color(0xFF1E222B)),
                    codeblockDecoration: BoxDecoration(
                      color: const Color(0xFF161922),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.border),
                    ),
                    listBullet: const TextStyle(color: AppTheme.blueTeam, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
