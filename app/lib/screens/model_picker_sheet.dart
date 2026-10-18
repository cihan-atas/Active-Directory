import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../theme/app_theme.dart';

Future<String?> showModelPickerSheet(
  BuildContext context, {
  required SavedAiKey keyObj,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppTheme.bgCard,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _ModelPickerView(keyObj: keyObj),
  );
}

class _ModelPickerView extends StatefulWidget {
  final SavedAiKey keyObj;
  const _ModelPickerView({required this.keyObj});

  @override
  State<_ModelPickerView> createState() => _ModelPickerViewState();
}

class _ModelPickerViewState extends State<_ModelPickerView> {
  final AiService _ai = AiService();
  String _searchFilter = '';
  bool _isRefreshing = false;

  Map<String, dynamic> _getModelBadge(String model) {
    final lower = model.toLowerCase();
    if (lower.contains('free')) {
      return {'label': '🎁 Ücretsiz', 'color': const Color(0xFF10B981)};
    }
    if (lower.contains('qwen') || lower.contains('8b') || lower.contains('instant') || lower.contains('lite')) {
      return {'label': '⚡ Hızlı & Yüksek Kota', 'color': AppTheme.sysAdmin};
    }
    if (lower.contains('70b') || lower.contains('72b') || lower.contains('120b') || lower.contains('r1') || lower.contains('pro')) {
      return {'label': '🧠 Derin Muhakeme', 'color': AppTheme.toolsAmber};
    }
    if (lower.contains('mixtral') || lower.contains('32k') || lower.contains('128k')) {
      return {'label': '📚 Geniş Bağlam', 'color': AppTheme.blueTeam};
    }
    return {'label': '💬 Genel Sohbet', 'color': AppTheme.textSecondary};
  }

  void _showAddCustomModelDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Row(
          children: const [
            Icon(Icons.add_circle_outline, color: AppTheme.blueTeam, size: 20),
            SizedBox(width: 8),
            Text('Özel Model Ekle', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.keyObj.provider.label} hesabınızda aktif olan özel veya yeni bir model ID\'si girin:',
              style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'Örn: llama-3.1-70b-versatile',
                hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                filled: true,
                fillColor: AppTheme.bgDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.blueTeam, foregroundColor: Colors.black),
            onPressed: () async {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                Navigator.pop(ctx);
                await _ai.addCustomModelForKey(widget.keyObj.id, val);
                if (mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('"$val" modeli eklendi ve seçildi! ✓')),
                  );
                }
              }
            },
            child: const Text('Ekle & Seç', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshModels() async {
    setState(() => _isRefreshing = true);
    final count = await _ai.refreshModelsForKey(widget.keyObj.id);
    if (mounted) {
      setState(() => _isRefreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count model hazır!'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final allModels = widget.keyObj.models;
    final current = widget.keyObj.activeModel;

    final filtered = allModels.where((m) {
      if (_searchFilter.isEmpty) return true;
      return m.toLowerCase().contains(_searchFilter.toLowerCase());
    }).toList();

    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.78,
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Üst Başlık & Butonlar
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.blueTeam.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.smart_toy_outlined, color: AppTheme.blueTeam, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.keyObj.provider.label} Model Seçimi (${allModels.length} Model)',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Öncelikli kullanılacak modeli seçin. Kota dolarsa alternatif denenir.',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: _isRefreshing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.blueTeam),
                          )
                        : const Icon(Icons.refresh, size: 20, color: AppTheme.blueTeam),
                    tooltip: 'API\'den Modelleri Yenile',
                    onPressed: _isRefreshing ? null : _refreshModels,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Model Arama Filtresi
              TextField(
                onChanged: (val) => setState(() => _searchFilter = val),
                style: const TextStyle(fontSize: 12.5, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Model ara... (Örn: qwen, llama, gemini, free)',
                  hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.bgDark,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Model Listesi
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final m = filtered[index];
                    final isSelected = m == current;
                    final badge = _getModelBadge(m);
                    final bColor = badge['color'] as Color;

                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () async {
                        await _ai.setModelForKey(widget.keyObj.id, m);
                        if (context.mounted) {
                          Navigator.pop(context, m);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Aktif model seçildi: $m ✓'),
                              duration: const Duration(seconds: 1),
                              backgroundColor: AppTheme.bgCard,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF162030) : AppTheme.bgDark,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? AppTheme.blueTeam : AppTheme.border,
                            width: isSelected ? 1.5 : 1,
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
                                m,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontFamily: 'monospace',
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: bColor.withAlpha(25),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: bColor.withAlpha(70)),
                              ),
                              child: Text(
                                badge['label'] as String,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: bColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),

              // Özel Model Ekleme Butonu
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.toolsAmber,
                  side: const BorderSide(color: AppTheme.borderHighlight),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Farklı / Özel Bir Model ID\'si Ekle', style: TextStyle(fontSize: 12)),
                onPressed: _showAddCustomModelDialog,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
