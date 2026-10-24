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
    useSafeArea: true,
    backgroundColor: Colors.transparent,
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

  // Aktif oturum mesajları (Sayfa kapatıldığında kaybolur, eski sistem gibi temiz başlar)
  final List<SavedAiChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isSaved = false;
  bool _isFullScreen = false;
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
          _scrollController.position.maxScrollExtent + 100,
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

    setState(() {
      _messages.add(userMsg);
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

      setState(() {
        _messages.add(aiMsg);
        _isLoading = false;
        _currentPendingPrompt = null;
      });
      _scrollToBottom();

      // Eğer kullanıcı bu oturumu önceden kaydettiyse, yeni mesajları otomatik güncelle
      if (_isSaved) {
        await _ai.toggleSaveChat(
          articleId: widget.articleId,
          articleTitle: widget.articleTitle,
          moduleId: widget.moduleId,
          moduleTitle: widget.moduleTitle,
          messages: _messages,
        );
        // toggleSaveChat kayıtlıysa siler, bu yüzden tek seferlik güncelleme için tekrar kaydedelim:
        if (!_ai.isArticleChatSaved(widget.articleId)) {
          await _ai.toggleSaveChat(
            articleId: widget.articleId,
            articleTitle: widget.articleTitle,
            moduleId: widget.moduleId,
            moduleTitle: widget.moduleTitle,
            messages: _messages,
          );
        }
      }
    }
  }

  Future<void> _toggleSaveCurrentChat() async {
    if (_messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kaydedilecek bir soru-cevap bulunmuyor.')),
      );
      return;
    }

    final saved = await _ai.toggleSaveChat(
      articleId: widget.articleId,
      articleTitle: widget.articleTitle,
      moduleId: widget.moduleId,
      moduleTitle: widget.moduleTitle,
      messages: _messages,
    );

    if (mounted) {
      setState(() {
        _isSaved = saved;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? 'Sohbet kaydedildi! Üstteki "Geçmiş" butonundan veya Ayarlar menüsünden erişebilirsiniz.'
                : 'Sohbet kaydı kaldırıldı.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showScopedHistorySheet() {
    final scopedChats = _ai.getSavedChatsForScope(
      articleId: widget.articleId,
      moduleId: widget.moduleId,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ScopedHistoryModal(
        articleTitle: widget.articleTitle,
        moduleTitle: widget.moduleTitle,
        savedChats: scopedChats,
        onSelectChat: (chat) {
          Navigator.pop(ctx);
          setState(() {
            _messages.clear();
            _messages.addAll(chat.messages);
            _isSaved = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${chat.articleTitle}" kayıtlı sohbeti yüklendi.'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
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
      setState(() {
        _messages.removeWhere((m) => m.id == msg.id);
      });
      if (_isSaved) {
        _ai.removeSessionMessage(widget.articleId, msg.id);
      }
    }
  }

  void _clearCurrentSession() {
    if (_messages.isEmpty) return;
    setState(() {
      _messages.clear();
      _isSaved = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Aktif sohbet temizlendi, yeni oturum başladı.'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final scopedChats = _ai.getSavedChatsForScope(
      articleId: widget.articleId,
      moduleId: widget.moduleId,
    );

    final screenHeight = MediaQuery.of(context).size.height;
    final sheetHeight = _isFullScreen ? screenHeight : screenHeight * 0.88;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      height: sheetHeight,
      margin: EdgeInsets.only(bottom: keyboardHeight),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: _isFullScreen
            ? BorderRadius.zero
            : const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 15, spreadRadius: 2),
        ],
      ),
      child: SafeArea(
        top: _isFullScreen,
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==========================================
              // ÜST EYLEM ÇUBUĞU
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

                  // 1. TAM EKRAN / TAM EKRANDAN ÇIK BUTONU
                  IconButton(
                    icon: Icon(
                      _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                      size: 22,
                      color: _isFullScreen ? AppTheme.toolsAmber : Colors.white,
                    ),
                    tooltip: _isFullScreen ? 'Tam Ekrandan Çık' : 'Tam Ekran Yap',
                    onPressed: () {
                      setState(() {
                        _isFullScreen = !_isFullScreen;
                      });
                    },
                  ),

                  // 2. GEÇMİŞ (SADECE BU MODÜLE / DOKÜMANA ÖZEL)
                  IconButton(
                    icon: Badge(
                      isLabelVisible: scopedChats.isNotEmpty,
                      label: Text('${scopedChats.length}'),
                      child: const Icon(Icons.history, size: 21, color: Colors.white),
                    ),
                    tooltip: 'Bu Dokümanın Kayıtlı Geçmişi',
                    onPressed: _showScopedHistorySheet,
                  ),

                  // 3. TOGGLE KAYDET / KALDIR BUTONU
                  IconButton(
                    icon: Icon(
                      _isSaved ? Icons.bookmark : Icons.bookmark_border,
                      size: 21,
                      color: _isSaved ? AppTheme.toolsAmber : AppTheme.textMuted,
                    ),
                    tooltip: _isSaved ? 'Kaydedildi (Kaldırmak için dokunun)' : 'Sohbeti Kaydet',
                    onPressed: _toggleSaveCurrentChat,
                  ),

                  // 4. TEMİZLE (Yeni Sohbet Başlat)
                  if (_messages.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20, color: AppTheme.textMuted),
                      tooltip: 'Sohbeti Temizle (Yeni Başlat)',
                      onPressed: _clearCurrentSession,
                    ),

                  // 5. AI ANAHTAR YÖNETİMİ
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

              // Model Seçici Rozeti (Sadece tam ekran değilken göster)
              if (!_isFullScreen && _ai.activeKey != null) ...[
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
              SizedBox(height: _isFullScreen ? 4 : 10),

              // ==========================================
              // ANA GÖVDE: Konfigürasyon veya Sohbet
              // ==========================================
              if (!_ai.isConfigured) ...[
                _buildUnconfiguredView(),
              ] else ...[
                // Hızlı Taktik Soru Çipleri (Sadece tam ekran değilken göster; tam ekranda devasa okuma alanı kalsın)
                if (!_isFullScreen) ...[
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
                ],

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
                    child: _messages.isEmpty && !_isLoading
                        ? _buildEmptyState()
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(12),
                            itemCount: _messages.length + (_isLoading ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index < _messages.length) {
                                final msg = _messages[index];
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
              'Yeni AI Sohbet Oturumu Hazır',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 6),
            Text(
              'Yukarıdaki hazır taktiksel butonlara dokunun veya aşağıdan serbest bir soru yazın.\nKaydetmek isterseniz üstteki yer imi simgesine basabilirsiniz.',
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

/// SADECE VE SADECE BU DOKÜMANA / BU MODÜLE AİT KAYITLI GEÇMİŞİ GÖSTEREN MODAL
class _ScopedHistoryModal extends StatelessWidget {
  final String articleTitle;
  final String moduleTitle;
  final List<SavedAiChat> savedChats;
  final ValueChanged<SavedAiChat> onSelectChat;

  const _ScopedHistoryModal({
    required this.articleTitle,
    required this.moduleTitle,
    required this.savedChats,
    required this.onSelectChat,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.70,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: AppTheme.toolsAmber, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bu Dokümanın Kayıtlı Sohbetleri',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        articleTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 16),

            if (savedChats.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'Bu doküman için henüz kayıtlı bir sohbet geçmişi bulunmuyor.\nBir soru sorduktan sonra üstteki yer imi simgesine basarak kaydedebilirsiniz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.4),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: savedChats.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final chat = savedChats[index];
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
                            Row(
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
                                      fontSize: 10,
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
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textMuted),
                        onTap: () => onSelectChat(chat),
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
