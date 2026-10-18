import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';
import 'model_picker_sheet.dart';

class AiSetupScreen extends StatefulWidget {
  const AiSetupScreen({super.key});

  @override
  State<AiSetupScreen> createState() => _AiSetupScreenState();
}

class _AiSetupScreenState extends State<AiSetupScreen> {
  final AiService _ai = AiService();
  final TextEditingController _keyController = TextEditingController();
  bool _isValidating = false;
  String? _errorMessage;
  String? _successMessage;

  Color _getProviderColor(AiProvider p) {
    switch (p) {
      case AiProvider.gemini:
        return AppTheme.blueTeam;
      case AiProvider.groq:
        return AppTheme.toolsAmber;
      case AiProvider.openRouter:
        return AppTheme.sysAdmin;
      default:
        return AppTheme.textMuted;
    }
  }

  Future<void> _addKey() async {
    final text = _keyController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isValidating = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final err = await _ai.addAndValidateKey(text);

    if (mounted) {
      setState(() {
        _isValidating = false;
        if (err == null) {
          _successMessage = 'API Anahtarı başarıyla doğrulandı ve kaydedildi!';
          _keyController.clear();
        } else {
          _errorMessage = err;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ai,
      builder: (context, _) {
        final savedKeys = _ai.keys;
        final activeKey = _ai.activeKey;

        return Scaffold(
          backgroundColor: AppTheme.bgDark,
          appBar: AppBar(
            title: Row(
              children: const [
                Icon(Icons.vpn_key, color: AppTheme.toolsAmber, size: 20),
                SizedBox(width: 8),
                Text('AI Anahtar Yönetimi & Ayarlar'),
              ],
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Bilgilendirme Kartı
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Row(
                        children: [
                          Icon(Icons.shield_outlined, color: AppTheme.sysAdmin, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Gizlilik ve %100 Çevrimdışı Güvencesi',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Active Directory Vault tamamen çevrimdışıdır. Anahtarlarınız telefonunuzun güvenli donanım deposunda (Android Keystore) saklanır. Yalnızca siz AI butonuna bastığınızda seçili sağlayıcıya bağlanır.',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Yeni Anahtar Ekleme Kutusu
                Card(
                  color: AppTheme.bgCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppTheme.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'YENİ API ANAHTARI EKLE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textMuted,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _keyController,
                          obscureText: true,
                          style: const TextStyle(fontSize: 13, color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Anahtarı yapıştırın (AIza..., gsk_..., sk-or-...)',
                            hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            prefixIcon: const Icon(Icons.key, color: AppTheme.textMuted, size: 20),
                            filled: true,
                            fillColor: AppTheme.bgDark,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppTheme.border),
                            ),
                          ),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(fontSize: 12, color: AppTheme.redTeam),
                          ),
                        ],
                        if (_successMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _successMessage!,
                            style: const TextStyle(fontSize: 12, color: AppTheme.sysAdmin),
                          ),
                        ],
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.blueTeam,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: _isValidating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : const Icon(Icons.add_task, size: 18),
                          label: Text(
                            _isValidating ? 'Doğrulanıyor...' : 'Doğrula ve Listeye Ekle',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          onPressed: _isValidating ? null : _addKey,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Kayıtlı Anahtarlar Listesi
                const Text(
                  'KAYITLI ANAHTARLARINIZ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMuted,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 10),

                if (savedKeys.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Center(
                      child: Column(
                        children: const [
                          Icon(Icons.vpn_key_off_outlined, color: AppTheme.textMuted, size: 40),
                          SizedBox(height: 10),
                          Text(
                            'Henüz kayıtlı bir API anahtarınız yok.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: savedKeys.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = savedKeys[index];
                      final isActive = activeKey?.id == item.id;
                      final pColor = _getProviderColor(item.provider);

                      return Card(
                        color: isActive ? const Color(0xFF162030) : AppTheme.bgCard,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isActive ? AppTheme.blueTeam : AppTheme.border,
                            width: isActive ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: pColor.withAlpha(25),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.key, color: pColor, size: 18),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    item.provider.label,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (isActive) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.blueTeam.withAlpha(30),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'AKTİF',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.blueTeam,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                '${item.masked} · ${item.models.length} model mevcut',
                                style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isActive)
                                    TextButton(
                                      child: const Text('Aktif Yap', style: TextStyle(fontSize: 12)),
                                      onPressed: () => _ai.setActiveKey(item.id),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.refresh, size: 18, color: AppTheme.blueTeam),
                                    tooltip: 'Modelleri Yenile',
                                    onPressed: () async {
                                      final count = await _ai.refreshModelsForKey(item.id);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('$count model hazır!')),
                                        );
                                        setState(() {});
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.textMuted),
                                    tooltip: 'Sil',
                                    onPressed: () => _ai.removeKey(item.id),
                                  ),
                                ],
                              ),
                            ),
                            // Model Seçici Butonu
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () async {
                                  await showModelPickerSheet(context, keyObj: item);
                                  setState(() {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.bgDark,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.borderHighlight),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.smart_toy_outlined, size: 14, color: AppTheme.blueTeam),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Model: ${item.activeModel}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontFamily: 'monospace',
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'Model Değiştir ▾',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.blueTeam,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 24),

                // Ücretsiz Anahtar Alma Rehberi
                const Text(
                  'ÜCRETSİZ ANAHTAR ALMA REHBERİ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMuted,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                _buildProviderGuideCard(
                  title: 'Google Gemini (Önerilen)',
                  prefix: 'AIza...',
                  desc: 'Google AI Studio üzerinden tamamen ücretsiz Gemini 2.0 Flash anahtarı alabilirsiniz.',
                  url: 'aistudio.google.com/app/apikey',
                ),
                const SizedBox(height: 8),
                _buildProviderGuideCard(
                  title: 'Groq Cloud',
                  prefix: 'gsk_...',
                  desc: 'Groq Console üzerinden ultra hızlı ve ücretsiz Llama 3.3 anahtarı oluşturabilirsiniz.',
                  url: 'console.groq.com/keys',
                ),
                const SizedBox(height: 8),
                _buildProviderGuideCard(
                  title: 'OpenRouter',
                  prefix: 'sk-or-...',
                  desc: 'Ücretsiz Llama ve DeepSeek açık kaynak modelleri için anahtar oluşturabilirsiniz.',
                  url: 'openrouter.ai/keys',
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProviderGuideCard({
    required String title,
    required String prefix,
    required String desc,
    required String url,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                'Önek: $prefix',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppTheme.toolsAmber),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, height: 1.35)),
          const SizedBox(height: 4),
          Text(url, style: const TextStyle(fontSize: 11, color: AppTheme.blueTeam)),
        ],
      ),
    );
  }
}
