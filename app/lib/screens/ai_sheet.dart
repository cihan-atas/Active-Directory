import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/ai_service.dart';
import '../services/link_navigation_service.dart';
import '../theme/app_theme.dart';
import '../widgets/code_block_builder.dart';
import 'ai_setup_screen.dart';
import 'model_picker_sheet.dart';

void showAiAssistantSheet(
  BuildContext context, {
  required String articleContent,
  required String articleTitle,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _AiAssistantSheet(
      articleContent: articleContent,
      articleTitle: articleTitle,
    ),
  );
}

class _AiAssistantSheet extends StatefulWidget {
  final String articleContent;
  final String articleTitle;

  const _AiAssistantSheet({
    required this.articleContent,
    required this.articleTitle,
  });

  @override
  State<_AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends State<_AiAssistantSheet> {
  final AiService _ai = AiService();
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();
  String? _response;
  bool _isLoading = false;
  String? _activePrompt;
  bool _isSaved = false;

  @override
  void dispose() {
    _keyController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _saveKey() async {
    final success = await _ai.setApiKey(_keyController.text);
    if (!mounted) return;
    if (success) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API Anahtarı başarıyla kaydedildi!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Geçersiz anahtar öneki. AIza... (Gemini), gsk_... (Groq) veya sk-or-... (OpenRouter) girin.',
          ),
        ),
      );
    }
  }

  Future<void> _ask(String prompt) async {
    setState(() {
      _isLoading = true;
      _activePrompt = prompt;
      _response = null;
      _isSaved = false;
    });

    final res = await _ai.askAi(
      prompt: prompt,
      articleContext: widget.articleContent,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _response = res;
      });
    }
  }

  Future<void> _saveCurrentChat() async {
    if (_response == null || _activePrompt == null) return;
    await _ai.saveChat(
      articleTitle: widget.articleTitle,
      prompt: _activePrompt!,
      response: _response!,
    );
    if (mounted) {
      setState(() => _isSaved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sohbet kaydedildi! "Geçmiş" veya "Ayarlar" menüsünden erişebilirsiniz.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showSavedChatsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SavedChatsModal(
        onSelectChat: (chat) {
          Navigator.pop(ctx);
          setState(() {
            _activePrompt = chat.prompt;
            _response = chat.response;
            _isSaved = true;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Üst Başlık & Eylem Çubuğu (1. Satır: Ferah Başlık ve Hızlı Eylemler)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.blueTeam.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome, color: AppTheme.blueTeam, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'AI Güvenlik Asistanı',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // Geçmiş Sohbetler Butonu
                  IconButton(
                    icon: Badge(
                      isLabelVisible: _ai.savedChats.isNotEmpty,
                      label: Text('${_ai.savedChats.length}'),
                      child: const Icon(Icons.history, size: 20, color: AppTheme.textPrimary),
                    ),
                    tooltip: 'Kayıtlı Sohbetler',
                    onPressed: _showSavedChatsSheet,
                  ),
                  // AI Anahtar Yönetimi
                  IconButton(
                    icon: const Icon(Icons.vpn_key_outlined, size: 19, color: AppTheme.toolsAmber),
                    tooltip: 'AI Anahtar Yöneticisi',
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AiSetupScreen()),
                      );
                    },
                  ),
                ],
              ),

              // Model Seçici ve Sağlayıcı Rozeti (2. Satır: Geniş ve Kolay Seçilebilir)
              if (_ai.activeKey != null) ...[
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    await showModelPickerSheet(context, keyObj: _ai.activeKey!);
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131C2A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.blueTeam.withAlpha(100), width: 1),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.blueTeam.withAlpha(40),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _ai.activeKey!.provider.label,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.blueTeam,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _ai.activeKey!.activeModel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Icon(Icons.unfold_more, size: 16, color: AppTheme.blueTeam),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Anahtar Yapılandırması Yoksa
              if (!_ai.isConfigured) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCode,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'İsteğe Bağlı AI Entegrasyonu',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13.5),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Google Gemini (ücretsiz), Groq (süper hızlı/ücretsiz) veya OpenRouter API anahtarınızı yapıştırarak bu doküman üzerinde anlık teknik soru sorabilir veya komut analizi yaptırabilirsiniz.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.vpn_key, size: 16, color: AppTheme.toolsAmber),
                        label: const Text(
                          'Kayıtlı Anahtar Yöneticisini Aç →',
                          style: TextStyle(fontSize: 12, color: AppTheme.toolsAmber, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AiSetupScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _keyController,
                  obscureText: true,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'API Anahtarını Yapıştırın (AIza..., gsk_..., sk-or-...)',
                    hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    filled: true,
                    fillColor: AppTheme.bgDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.blueTeam,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _saveKey,
                  child: const Text('Anahtarı Doğrula ve Kaydet', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ] else ...[
                // Genişletilmiş Hızlı Taktik Soru Butonları
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildQuickAction('💡 Basitçe Açıkla', 'Bu dokümandaki konuyu ve çalışma prensibini yeni başlayan biri için basitçe açıkla.'),
                      const SizedBox(width: 8),
                      _buildQuickAction('⚡ Komut & Saldırı', 'Bu araç/teknikteki kritik CLI komutlarını ve pratik sızma testi senaryolarını detaylandır.'),
                      const SizedBox(width: 8),
                      _buildQuickAction('🛡️ Tespit & EDR', 'Bu saldırıya karşı Windows Event ID\'leri, Sysmon kuralları ve kesin savunma adımlarını listele.'),
                      const SizedBox(width: 8),
                      _buildQuickAction('🎯 AD Saldırı Zinciri', 'Bu tekniğin Active Directory sızma testindeki saldırı zincirindeki (Kill-Chain) yeri nedir? Hangi adımdan önce ve sonra kullanılır?'),
                      const SizedBox(width: 8),
                      _buildQuickAction('🔧 Hata & Sorun Giderme', 'Bu komut veya araç çalışırken en sık karşılaşılan hatalar (Access Denied, Timeout, Dialect Mismatch) ve kesin çözümleri nelerdir?'),
                      const SizedBox(width: 8),
                      _buildQuickAction('🔒 Güvenlik Sertleştirme', 'Bu zafiyeti tamamen kapatmak ve Domain ortamını sertleştirmek için gereken GPO ve yapılandırma adımları nelerdir?'),
                      const SizedBox(width: 8),
                      _buildQuickAction('📋 Yönetici Özeti', 'Bir sızma testi raporu için bu saldırının iş etkisini (Impact), risk seviyesini (CVSS) ve yönetici özetini hazırla.'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Yanıt Alanı (Markdown & Kod Blokları Desteğiyle)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCode,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: _isLoading
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(color: AppTheme.blueTeam),
                                const SizedBox(height: 14),
                                Text(
                                  '"$_activePrompt" yanıtlanıyor...',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          )
                        : _response == null
                            ? const Center(
                                child: Text(
                                  'Yukarıdaki hazır taktiksel butonlara dokunun veya aşağıdan serbest bir soru yazın.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted, height: 1.4),
                                ),
                              )
                            : SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Yanıt Başlığı ve Eylemler
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Text(
                                              'AI YANITI',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.blueTeam,
                                              ),
                                            ),
                                            if (_ai.lastUsedModel != null) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.sysAdmin.withAlpha(25),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  _ai.lastUsedModel!,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontFamily: 'monospace',
                                                    color: AppTheme.sysAdmin,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            // Sohbeti Kaydet Butonu
                                            IconButton(
                                              icon: Icon(
                                                _isSaved ? Icons.bookmark : Icons.bookmark_border,
                                                size: 18,
                                                color: _isSaved ? AppTheme.toolsAmber : AppTheme.textMuted,
                                              ),
                                              tooltip: _isSaved ? 'Kaydedildi' : 'Sohbeti Kaydet',
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: _saveCurrentChat,
                                            ),
                                            const SizedBox(width: 12),
                                            // Kopyala Butonu
                                            IconButton(
                                              icon: const Icon(Icons.copy, size: 16, color: AppTheme.textMuted),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              tooltip: 'Yanıtı Kopyala',
                                              onPressed: () {
                                                Clipboard.setData(ClipboardData(text: _response ?? ''));
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Yanıt panoya kopyalandı!'),
                                                    duration: Duration(seconds: 1),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 14),

                                    // Zengin Markdown Render & Kod Kopyalama
                                    MarkdownBody(
                                      data: _response!,
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
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          height: 1.4,
                                        ),
                                        h2: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.blueTeam,
                                          height: 1.4,
                                        ),
                                        h3: const TextStyle(
                                          fontSize: 14.5,
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
                              ),
                  ),
                ),
                const SizedBox(height: 10),

                // Serbest Soru Girişi
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _promptController,
                        style: const TextStyle(fontSize: 13, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Doküman hakkında detaylı soru yazın...',
                          hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          filled: true,
                          fillColor: AppTheme.bgDark,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.border),
                          ),
                        ),
                        onSubmitted: (val) {
                          if (val.trim().isNotEmpty) {
                            _ask(val.trim());
                            _promptController.clear();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send, color: AppTheme.blueTeam),
                      onPressed: () {
                        if (_promptController.text.trim().isNotEmpty) {
                          _ask(_promptController.text.trim());
                          _promptController.clear();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction(String title, String prompt) {
    return ActionChip(
      label: Text(title),
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      backgroundColor: AppTheme.bgCardHover,
      side: const BorderSide(color: AppTheme.borderHighlight),
      onPressed: () => _ask(prompt),
    );
  }
}

class _SavedChatsModal extends StatefulWidget {
  final ValueChanged<SavedAiChat> onSelectChat;

  const _SavedChatsModal({required this.onSelectChat});

  @override
  State<_SavedChatsModal> createState() => _SavedChatsModalState();
}

class _SavedChatsModalState extends State<_SavedChatsModal> {
  final AiService _ai = AiService();

  @override
  Widget build(BuildContext context) {
    final chats = _ai.savedChats;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
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
                    'Henüz kayıtlı bir AI sohbetiniz yok.\nBir soru sorduktan sonra kaydet simgesine basabilirsiniz.',
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
                        onTap: () => widget.onSelectChat(chat),
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
}
