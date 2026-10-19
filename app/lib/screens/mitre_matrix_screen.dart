import 'package:flutter/material.dart';
import '../models/mitre_models.dart';
import '../theme/app_theme.dart';
import '../services/content_service.dart';
import 'article_screen.dart';
import 'command_generator_screen.dart';

/// İnteraktif MITRE ATT&CK Matris Navigatörü Ekranı
class MitreMatrixScreen extends StatefulWidget {
  const MitreMatrixScreen({super.key});

  @override
  State<MitreMatrixScreen> createState() => _MitreMatrixScreenState();
}

class _MitreMatrixScreenState extends State<MitreMatrixScreen> {
  final TextEditingController _searchController = TextEditingController();
  MitreTactic? _selectedTactic;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MitreTechnique> get _filteredTechniques {
    return MitreDataRepository.allTechniques.where((t) {
      if (_selectedTactic != null && t.tactic != _selectedTactic) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final inId = t.id.toLowerCase().contains(q);
        final inName = t.name.toLowerCase().contains(q);
        final inDesc = t.description.toLowerCase().contains(q);
        final inTools = t.tools.any((tool) => tool.toLowerCase().contains(q));
        final inEvents = t.eventIds.any((eid) => eid.toString().contains(q));
        return inId || inName || inDesc || inTools || inEvents;
      }
      return true;
    }).toList();
  }

  void _showTechniqueDetails(MitreTechnique tech) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF131A26),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            border: Border(top: BorderSide(color: AppTheme.borderHighlight, width: 1.5)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Üst Sürükleme Çizgisi
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textMuted.withAlpha(100),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Başlık ve ID
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: tech.heatColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tech.heatColor, width: 1.2),
                    ),
                    child: Text(
                      tech.id,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: tech.heatColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tech.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(tech.tactic.icon, size: 14, color: tech.tactic.color),
                            const SizedBox(width: 4),
                            Text(
                              tech.tactic.name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: tech.tactic.color,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: tech.heatColor.withAlpha(25),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '🔥 Isı Skoru: ${tech.heatScore}/5',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: tech.heatColor),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Açıklama
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.bgDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  tech.description,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.45),
                ),
              ),
              const SizedBox(height: 14),

              // İlgili Araçlar ve Doküman Bağlantıları
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '🛠️ KULLANILAN ARAÇLAR VE CEPHANELİK',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted, letterSpacing: 0.8),
                  ),
                  const Text(
                    'Doküman veya komut için tıkla',
                    style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: tech.tools.map((tool) {
                  final article = ContentService().findArticleItem(tool: tool);
                  final hasDoc = article != null;

                  return Tooltip(
                    message: hasDoc
                        ? '📄 Dokümanı Aç: ${article.title}'
                        : '⚡ $tool komutlarını aç',
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        if (hasDoc) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ArticleScreen(
                                articleId: article.path,
                                initialTitle: article.title,
                              ),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CommandGeneratorScreen(
                                initialTool: tool,
                              ),
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: hasDoc
                              ? AppTheme.blueTeam.withAlpha(30)
                              : AppTheme.redTeam.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: hasDoc
                                ? AppTheme.blueTeam.withAlpha(160)
                                : AppTheme.redTeam.withAlpha(120),
                            width: 1.1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasDoc ? Icons.menu_book_rounded : Icons.handyman_rounded,
                              size: 13,
                              color: hasDoc ? AppTheme.blueTeam : AppTheme.toolsAmber,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              tool,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: hasDoc ? Colors.white : AppTheme.redTeam,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              hasDoc ? Icons.open_in_new_rounded : Icons.arrow_forward_rounded,
                              size: 11,
                              color: hasDoc ? AppTheme.blueTeam : AppTheme.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Mavi Takım ve Event ID'ler
              const Text(
                '🚨 MAVİ TAKIM TESPİT KRİTERLERİ VE EVENT ID\'LER',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted, letterSpacing: 0.8),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.blueTeam.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.blueTeam.withAlpha(70)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Kritik Olay Kodları: ', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        ...tech.eventIds.map((eid) {
                          return Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.blueTeam.withAlpha(35),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: AppTheme.blueTeam),
                            ),
                            child: Text(
                              'EID $eid',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'monospace'),
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tech.detectionSummary,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Aksiyon Butonları
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.redTeam,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.terminal, size: 18),
                      label: const Text(
                        'Komutları Oluşturucuda Aç',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        final query = tech.commandQueries.isNotEmpty
                            ? tech.commandQueries.first
                            : tech.name;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CommandGeneratorScreen(
                              initialSearchQuery: query,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (tech.relatedArticlePath != null) ...[
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.blueTeam),
                        foregroundColor: AppTheme.blueTeam,
                        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.menu_book, size: 18),
                      label: const Text('Makaleyi Oku', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ArticleScreen(
                              articleId: tech.relatedArticlePath!,
                              initialTitle: tech.name,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final techniques = _filteredTechniques;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('🗺 MITRE ATT&CK Matris Navigatörü'),
        backgroundColor: AppTheme.bgCard,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Üst Filtre ve Arama Alanı
              Container(
                color: AppTheme.bgCard,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Arama Input
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.bgDark,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: AppTheme.textMuted, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(fontSize: 13, color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: 'Teknik ID, ad (Kerberoasting, LSASS), araç veya Event ID ara...',
                                hintStyle: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val.trim();
                                });
                              },
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18, color: AppTheme.textMuted),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Taktik Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildTacticFilterChip('Tümü (${MitreDataRepository.allTechniques.length})', null),
                          const SizedBox(width: 6),
                          ...MitreTactic.values.map((t) {
                            final count = MitreDataRepository.allTechniques.where((x) => x.tactic == t).length;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: _buildTacticFilterChip('${t.name} ($count)', t),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Isı Haritası Lejantı
                    Row(
                      children: [
                        const Text('Isı Haritası (Kritiklik): ', style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
                        _buildHeatLegendDot('5 (Kritik)', const Color(0xFFEF4444)),
                        const SizedBox(width: 8),
                        _buildHeatLegendDot('4 (Yüksek)', const Color(0xFFF97316)),
                        const SizedBox(width: 8),
                        _buildHeatLegendDot('3 (Orta)', const Color(0xFFF59E0B)),
                        const SizedBox(width: 8),
                        _buildHeatLegendDot('2 (Standart)', const Color(0xFF3B82F6)),
                      ],
                    ),
                  ],
                ),
              ),

              // Matris Grid veya Liste Görünümü
              Expanded(
                child: techniques.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off, size: 48, color: AppTheme.textMuted),
                            const SizedBox(height: 12),
                            Text(
                              '"$_searchQuery" aramasına uygun teknik bulunamadı.',
                              style: const TextStyle(color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 700;
                          return GridView.builder(
                            padding: const EdgeInsets.all(14),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: isWide ? 3 : 1,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: isWide ? 1.6 : 2.5,
                            ),
                            itemCount: techniques.length,
                            itemBuilder: (context, index) {
                              final tech = techniques[index];
                              return _buildTechniqueCard(tech);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTacticFilterChip(String label, MitreTactic? tactic) {
    final isSelected = _selectedTactic == tactic;
    final color = tactic != null ? tactic.color : AppTheme.toolsAmber;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedTactic = tactic;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(40) : AppTheme.bgDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : AppTheme.border,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? color : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildHeatLegendDot(String text, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildTechniqueCard(MitreTechnique tech) {
    return Card(
      color: AppTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: tech.heatColor.withAlpha(tech.heatScore >= 4 ? 180 : 80),
          width: tech.heatScore >= 4 ? 1.4 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showTechniqueDetails(tech),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Üst Satır: ID & Heat Dot & Taktik
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: tech.heatColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      tech.id,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: tech.heatColor,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(tech.tactic.icon, size: 12, color: tech.tactic.color),
                      const SizedBox(width: 4),
                      Text(
                        tech.tactic.name.split(' ').first,
                        style: TextStyle(fontSize: 10, color: tech.tactic.color, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Teknik Adı
              Text(
                tech.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 3),

              // Açıklama Özeti
              Expanded(
                child: Text(
                  tech.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.3),
                ),
              ),
              const SizedBox(height: 6),

              // Alt Araç ve Event ID Rozetleri
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Araçlar: ${tech.tools.take(3).join(', ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                    ),
                  ),
                  if (tech.eventIds.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.blueTeam.withAlpha(20),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'EID ${tech.eventIds.first}',
                        style: const TextStyle(fontSize: 9.5, color: AppTheme.blueTeam, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
