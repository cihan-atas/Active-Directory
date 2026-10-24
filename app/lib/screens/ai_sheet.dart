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
  String articleId = '',
  String moduleId = '',
  String moduleTitle = '',
}) {
  final resolvedId = articleId.isNotEmpty ? articleId : articleTitle;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _AiAssistantSheet(
      articleId: resolvedId,
      moduleId: moduleId,
      moduleTitle: moduleTitle,
      articleContent: articleContent,
      articleTitle: articleTitle,
    ),
  );
}

class _AiAssistantSheet extends StatefulWidget {
  final String articleId;
  final String moduleId;
  final String moduleTitle;
  final String articleContent;
  final String articleTitle;

  const _AiAssistantSheet({
    required this.articleId,
    required this.moduleId,
    required this.moduleTitle,
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
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  String? _currentPendingPrompt;

  @override
  void initState() {
    super.initState();
    _ai.addListener(_onAiStateChanged);
  }

  @override
  void dispose() {
    _ai.removeListener(_onAiStateChanged);
    _keyController.dispose();
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onAiStateChanged() {
    if (mounted) setState(() {});
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
    if (prompt.trim().isEmpty) return;

    final userMsg = SavedAiChatMessage(
      id: 'msg_${DateTime.now().microsecondsSinceEpoch}',
      isUser: true,
      text: prompt.trim(),
      timestamp: DateTime.now(),
    );

    _ai.addSessionMessage(widget.articleId, userMsg);

    setState(() {
      _isLoading = true;
      _currentPendingPrompt = prompt.trim();
    });
    _scrollToBottom();

    final res = await _ai.askAi(
      prompt: prompt.trim(),
      articleContext: widget.articleContent,
    );

    if (mounted) {
      final aiMsg = SavedAiChatMessage(
        id: 'msg_${DateTime.now().microsecondsSinceEpoch}',
        isUser: false,
        text: res,
        timestamp: DateTime.now(),
      );
      _ai.addSessionMessage(widget.articleId, aiMsg);

      setState(() {
        _isLoading = false;
        _currentPendingPrompt = null;
      });
      _scrollToBottom();
    }
  }

  Future<void> _toggleSaveCurrentChat() async {
    final msgs = _ai.getSession(widget.articleId);
    if (msgs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kaydedilecek bir soru-cevap bulunmuyor.')),
      );
      return;
    }

    final isSaved = await _ai.toggleSaveChat(
      articleId: widget.articleId,
      articleTitle: widget.articleTitle,
      moduleId: widget.moduleId,
      moduleTitle: widget.moduleTitle,
      messages: msgs,
    );

    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSaved
                ? 'Sohbet kaydedildi! "Ayarlar > Soru-Cevap Geçmişi" bölümünden erişebilirsiniz.'
                : 'Sohbet kaydı kaldırıldı.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteMessage(SavedAiChatMessage msg) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Mesajı Sil', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          msg.isUser
              ? 'Sorduğunuz bu soruyu oturumdan silmek istiyor musunuz?'
              : 'AI tarafından verilen bu yanıtı oturumdan silmek istiyor musunuz?',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal', style: TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.redTeam),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _ai.removeSessionMessage(widget.articleId, msg.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _clearSession() async {
    final msgs = _ai.getSession(widget.articleId);
    if (msgs.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Oturumu Temizle', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text(
          'Bu dokümandaki aktif sohbet geçmişini temizlemek istiyor musunuz?',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal', style: TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.redTeam),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Temizle', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _ai.clearSession(widget.articleId);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final messages = _ai.getSession(widget.articleId);
    final isSaved = _ai.isArticleChatSaved(widget.articleId);

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.90,
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==========================================
              // ÜST EYLEM ÇUBUĞU (Başlık + Model + İkonlar)
              // ==========================================
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI Güvenlik Asistanı',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          widget.articleTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),

                  // Toggle Kaydet / Kaldır Butonu
                  IconButton(
                    icon: Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                      size: 22,
                      color: isSaved ? AppTheme.toolsAmber : AppTheme.textMuted,
                    ),
                    tooltip: isSaved ? 'Kayıtlı (Kaldırmak için dokunun)' : 'Sohbeti Kaydet',
                    onPressed: _toggleSaveCurrentChat,
                  ),

                  // Oturumu Temizle
                  if (messages.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20, color: AppTheme.textMuted),
                      tooltip: 'Bu Dokümanın Sohbetini Sıfırla',
                      onPressed: _clearSession,
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

              // Model Seçici Rozeti
              if (_ai.activeKey != null) ...[
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    await showModelPickerSheet(context, keyObj: _ai.activeKey!);
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
              const SizedBox(height: 10),

              // ==========================================
              // ANA GÖVDE: Konfigürasyon veya Sohbet
              // ==========================================
              if (!_ai.isConfigured) ...[
                _buildUnconfiguredView(),
              ] else ...[
                // Hızlı Taktik Soru Çipleri
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
                      _buildQuickAction('🔒 Sertleştirme', 'Bu zafiyeti tamamen kapatmak ve Domain ortamını sertleştirmek için gereken GPO ve yapılandırma adımları nelerdir?'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // ==========================================
                // MULTI-TURN SOHBET LİSTESİ
                // ==========================================
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.bgCode,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: messages.isEmpty && !_isLoading
                        ? _buildEmptyState()
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(12),
                            itemCount: messages.length + (_isLoading ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index < messages.length) {
                                final msg = messages[index];
                                return _buildMessageItem(msg);
                              } else {
                                return _buildLoadingIndicator();
                              }
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 10),

                // ==========================================
                // SERBEST SORU GİRİŞ ALANI
                // ==========================================
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _promptController,
                        style: const TextStyle(fontSize: 13, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Doküman hakkında soru veya komut yazın...',
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.chat_bubble_outline, size: 36, color: AppTheme.textMuted),
            SizedBox(height: 12),
            Text(
              'Bu dokümana özel AI sohbet oturumu hazır.',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 6),
            Text(
              'Yukarıdaki hazır taktiksel butonlara dokunun veya aşağıdan serbest bir soru yazın.\nKonuşmanız bu dokümana özel olarak korunacaktır.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(SavedAiChatMessage msg) {
    if (msg.isUser) {
      // ==========================================
      // KULLANICI SORUSU (Sağa Hizalı Baloncuk)
      // ==========================================
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Silme butonu
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.textMuted),
              tooltip: 'Soruyu Sil',
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              onPressed: () => _deleteMessage(msg),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF192B45),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                    topRight: Radius.circular(2),
                  ),
                  border: Border.all(color: AppTheme.blueTeam.withAlpha(80)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      msg.text,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            const CircleAvatar(
              radius: 12,
              backgroundColor: AppTheme.blueTeam,
              child: Icon(Icons.person, size: 14, color: Colors.black),
            ),
          ],
        ),
      );
    } else {
      // ==========================================
      // AI YANITI (Sola Hizalı Markdown Kartı)
      // ==========================================
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.blueTeam.withAlpha(30),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.auto_awesome, size: 16, color: AppTheme.blueTeam),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF141720),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                    topLeft: Radius.circular(2),
                  ),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Üst Eylemler: Model rozeti + Kopyala + Sil
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'AI YANITI',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.blueTeam,
                              ),
                            ),
                            if (_ai.lastUsedModel != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.sysAdmin.withAlpha(25),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _ai.lastUsedModel!,
                                  style: const TextStyle(
                                    fontSize: 9.5,
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
                            // Kopyala Butonu
                            IconButton(
                              icon: const Icon(Icons.copy, size: 15, color: AppTheme.textMuted),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Yanıtı Kopyala',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: msg.text));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Yanıt panoya kopyalandı!'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 10),
                            // Sil Butonu (İstek 7)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.textMuted),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Yanıtı Sil',
                              onPressed: () => _deleteMessage(msg),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 12, color: AppTheme.border),

                    // Markdown İçeriği
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
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                          height: 1.45,
                        ),
                        h1: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.35,
                        ),
                        h2: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.blueTeam,
                          height: 1.35,
                        ),
                        h3: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.toolsAmber,
                          height: 1.3,
                        ),
                        code: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
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
          ],
        ),
      );
    }
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 32),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF141720),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.blueTeam),
            ),
            const SizedBox(width: 10),
            Text(
              _currentPendingPrompt != null
                  ? '"$_currentPendingPrompt" analiz ediliyor...'
                  : 'AI yanıtı hazırlanıyor...',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnconfiguredView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
      ],
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
