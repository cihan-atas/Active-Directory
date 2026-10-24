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
import 'ticket_inspector_screen.dart';
import 'mitre_matrix_screen.dart';
import 'quiz_scorecard_screen.dart';

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
                  leading: const Icon(Icons.hub, color: AppTheme.redTeam),
                  title: const Text('🗺 MITRE ATT&CK Matris Navigatörü', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                  subtitle: const Text('Isı haritası, araçlar, komutlar ve Blue Team tespit kurallarıyla tüm AD teknikleri', style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MitreMatrixScreen()),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.confirmation_number_outlined, color: AppTheme.toolsAmber),
                  title: const Text('🎟 Kerberos Bilet Çözümleyici (Inspector)', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                  subtitle: const Text('Base64 .kirbi, CCache ve terminal biletlerini istemci tarafında görsel kimlik kartına dönüştürün', style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TicketInspectorScreen()),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.radar, color: Color(0xFF10B981)),
                  title: const Text('📊 Sınav Karnesi & Yetenek Radar Grafiği', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                  subtitle: const Text('11 kategoride eksik olduğunuz konuları radar grafiğinde görün ve zayıf konulara odaklanın', style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QuizScorecardScreen()),
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  SavedAiChat? _viewingChat;

  @override
  void initState() {
    super.initState();
    _ai.addListener(_onAiChanged);
  }

  @override
  void dispose() {
    _ai.removeListener(_onAiChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onAiChanged() {
    if (mounted) {
      if (_viewingChat != null) {
        final updated = _ai.savedChats.where((c) => c.id == _viewingChat!.id).firstOrNull;
        _viewingChat = updated;
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final allChats = _ai.savedChats;

    final filteredChats = allChats.where((chat) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.trim().toLowerCase();
      final inTitle = chat.articleTitle.toLowerCase().contains(q);
      final inMod = chat.moduleTitle.toLowerCase().contains(q);
      final inPrompt = chat.prompt.toLowerCase().contains(q);
      final inMsgs = chat.messages.any((m) => m.text.toLowerCase().contains(q));
      return inTitle || inMod || inPrompt || inMsgs;
    }).toList();

    // Modüller Ana Kategori -> Dokümanlar Alt Kategori Hiyerarşisi
    final Map<String, Map<String, List<SavedAiChat>>> hierarchicalChats = {};
    for (final chat in filteredChats) {
      final modKey = chat.moduleTitle.isNotEmpty ? chat.moduleTitle : 'Diğer / Genel Dokümanlar';
      final docKey = chat.articleTitle.isNotEmpty ? chat.articleTitle : 'İsimsiz Doküman';
      hierarchicalChats.putIfAbsent(modKey, () => {});
      hierarchicalChats[modKey]!.putIfAbsent(docKey, () => []).add(chat);
    }

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: _viewingChat != null
            ? _buildChatDetail(_viewingChat!)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Üst Başlık & Tümünü Temizle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bookmark, color: AppTheme.toolsAmber, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Kayıtlı AI Sohbetleri (${allChats.length})',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      if (allChats.isNotEmpty)
                        TextButton.icon(
                          style: TextButton.styleFrom(foregroundColor: AppTheme.redTeam),
                          icon: const Icon(Icons.delete_sweep, size: 16),
                          label: const Text('Tümünü Temizle', style: TextStyle(fontSize: 12)),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: AppTheme.bgCard,
                                title: const Text('Tüm Kayıtları Temizle', style: TextStyle(color: Colors.white)),
                                content: const Text(
                                  'Tüm modül ve dokümanlara ait kaydedilmiş AI soru-cevap geçmişi silinecek. Emin misiniz?',
                                  style: TextStyle(color: AppTheme.textSecondary),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
                                  TextButton(
                                    style: TextButton.styleFrom(foregroundColor: AppTheme.redTeam),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Tümünü Sil', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await _ai.clearAllChats();
                              setState(() {});
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Arama Çubuğu
                  if (allChats.isNotEmpty) ...[
                    TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Modül, doküman veya soru ara...',
                        hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textMuted),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16, color: AppTheme.textMuted),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppTheme.bgDark,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // İçerik: Boş veya Modüllere Göre Kategorili Liste
                  if (allChats.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Henüz kayıtlı bir AI sohbetiniz yok.\nBir dokümanda AI ile sohbet ettikten sonra yer imi simgesine basarak kaydedebilirsiniz.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.4),
                        ),
                      ),
                    )
                  else if (filteredChats.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Aramanızla eşleşen kayıtlı sohbet bulunamadı.',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: hierarchicalChats.keys.length,
                        itemBuilder: (context, index) {
                          final modTitle = hierarchicalChats.keys.elementAt(index);
                          final docMap = hierarchicalChats[modTitle]!;
                          final totalModChats = docMap.values.fold<int>(0, (sum, list) => sum + list.length);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.bgCard,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                initiallyExpanded: true,
                                tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                leading: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.blueTeam.withAlpha(25),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.folder, color: AppTheme.blueTeam, size: 18),
                                ),
                                title: Text(
                                  modTitle,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                subtitle: Text(
                                  '${docMap.keys.length} doküman · $totalModChats kayıtlı sohbet',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                ),
                                children: [
                                  const Divider(height: 1, color: AppTheme.border),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: docMap.keys.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                                      itemBuilder: (context, dIdx) {
                                        final docTitle = docMap.keys.elementAt(dIdx);
                                        final docChats = docMap[docTitle]!;

                                        return Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF131722),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppTheme.borderHighlight.withAlpha(60)),
                                          ),
                                          child: Theme(
                                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                            child: ExpansionTile(
                                              initiallyExpanded: docMap.keys.length == 1,
                                              tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                              leading: const Icon(Icons.description_outlined, color: AppTheme.toolsAmber, size: 18),
                                              title: Text(
                                                docTitle,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              subtitle: Text(
                                                '${docChats.length} kayıtlı sohbet oturumu',
                                                style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                                              ),
                                              children: [
                                                const Divider(height: 1, color: AppTheme.border),
                                                ListView.separated(
                                                  shrinkWrap: true,
                                                  physics: const NeverScrollableScrollPhysics(),
                                                  padding: const EdgeInsets.all(8),
                                                  itemCount: docChats.length,
                                                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                                                  itemBuilder: (context, cIdx) {
                                                    final chat = docChats[cIdx];
                                                    return Container(
                                                      decoration: BoxDecoration(
                                                        color: AppTheme.bgCode,
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(color: AppTheme.border.withAlpha(50)),
                                                      ),
                                                      child: ListTile(
                                                        dense: true,
                                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                                        title: Text(
                                                          chat.prompt,
                                                          maxLines: 2,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: const TextStyle(
                                                            fontSize: 12.5,
                                                            fontWeight: FontWeight.w600,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                        subtitle: Padding(
                                                          padding: const EdgeInsets.only(top: 4),
                                                          child: Row(
                                                            children: [
                                                              Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                                decoration: BoxDecoration(
                                                                  color: AppTheme.blueTeam.withAlpha(30),
                                                                  borderRadius: BorderRadius.circular(3),
                                                                ),
                                                                child: Text(
                                                                  '${chat.messages.length} mesaj',
                                                                  style: const TextStyle(
                                                                    fontSize: 9.5,
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
                                                        ),
                                                        trailing: IconButton(
                                                          icon: const Icon(Icons.delete_outline, size: 17, color: AppTheme.textMuted),
                                                          tooltip: 'Sohbeti Sil',
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
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
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
        // Üst Eylemler: Geri + Başlık + Kopyala + Sil
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              onPressed: () => setState(() => _viewingChat = null),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat.articleTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  if (chat.moduleTitle.isNotEmpty)
                    Text(
                      chat.moduleTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppTheme.blueTeam),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: AppTheme.textMuted),
              tooltip: 'Tüm Konuşmayı Kopyala',
              onPressed: () {
                final buffer = StringBuffer();
                for (final msg in chat.messages) {
                  buffer.writeln(msg.isUser ? '== KULLANICI SORUSU ==' : '== AI CEVABI ==');
                  buffer.writeln(msg.text);
                  buffer.writeln();
                }
                Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tüm sohbet panoya kopyalandı!')),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.redTeam),
              tooltip: 'Bu Dokümanın Kaydını Sil',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.bgCard,
                    title: const Text('Sohbeti Sil', style: TextStyle(color: Colors.white)),
                    content: const Text(
                      'Bu dokümana ait tüm kayıtlı konuşmalar silinecek. Onaylıyor musunuz?',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: AppTheme.redTeam),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Sil', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _ai.deleteChat(chat.id);
                  setState(() => _viewingChat = null);
                }
              },
            ),
          ],
        ),
        const Divider(height: 12, color: AppTheme.border),

        // Diyalog Listesi (Multi-turn soru & cevaplar)
        Expanded(
          child: chat.messages.isEmpty
              ? const Center(
                  child: Text('Kayıtlı mesaj bulunamadı', style: TextStyle(color: AppTheme.textMuted)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: chat.messages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final msg = chat.messages[index];
                    return _buildMessageItem(chat, msg);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMessageItem(SavedAiChat chat, SavedAiChatMessage msg) {
    if (msg.isUser) {
      // ==========================================
      // KULLANICI SORUSU (Vurgulu Kutu)
      // ==========================================
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF192B45),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.blueTeam.withAlpha(90)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.person, size: 14, color: AppTheme.blueTeam),
                    SizedBox(width: 6),
                    Text(
                      'SORULAN SORU',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.toolsAmber),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                    ),
                    const SizedBox(width: 8),
                    // Tekil mesaj silme (İstek 7)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 15, color: AppTheme.textMuted),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Bu Soruyu Sil',
                      onPressed: () async {
                        _ai.removeSessionMessage(chat.articleId, msg.id);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            SelectableText(
              msg.text,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: Colors.white, height: 1.4),
            ),
          ],
        ),
      );
    } else {
      // ==========================================
      // AI YANITI (Düzeltilmiş Markdown Kartı)
      // ==========================================
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF141720),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 14, color: AppTheme.blueTeam),
                    const SizedBox(width: 6),
                    const Text(
                      'AI YANITI',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.blueTeam),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.sysAdmin.withAlpha(25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        chat.model,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontFamily: 'monospace',
                          color: AppTheme.sysAdmin,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy, size: 15, color: AppTheme.textMuted),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Yanıtı Kopyala',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: msg.text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Yanıt panoya kopyalandı!')),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    // Tekil yanıt silme (İstek 7)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 15, color: AppTheme.textMuted),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Bu Yanıtı Sil',
                      onPressed: () async {
                        _ai.removeSessionMessage(chat.articleId, msg.id);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 14, color: AppTheme.border),
            MarkdownBody(
              data: msg.text,
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
                p: const TextStyle(
                  fontSize: 13.5,
                  color: AppTheme.textPrimary,
                  height: 1.5,
                ),
                h1: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.4,
                ),
                h2: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.blueTeam,
                  height: 1.4,
                ),
                h3: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.toolsAmber,
                  height: 1.3,
                ),
                code: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  color: AppTheme.toolsAmber,
                  backgroundColor: Color(0xFF1E222B),
                ),
                codeblockDecoration: BoxDecoration(
                  color: const Color(0xFF161922),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                listBullet: const TextStyle(color: AppTheme.blueTeam, fontSize: 13),
                blockquote: const TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                blockquoteDecoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(4),
                  border: const Border(left: BorderSide(color: AppTheme.blueTeam, width: 3)),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
}
