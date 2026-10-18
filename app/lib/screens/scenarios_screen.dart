import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/scenario_models.dart';
import '../theme/app_theme.dart';
import '../widgets/tts_bar.dart';

class ScenariosScreen extends StatefulWidget {
  const ScenariosScreen({super.key});

  @override
  State<ScenariosScreen> createState() => _ScenariosScreenState();
}

class _ScenariosScreenState extends State<ScenariosScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'Tümü';
  String _searchQuery = '';

  static const List<String> _categories = [
    'Tümü',
    'Kerberos',
    'NTLM & Relay',
    'Yetki Yükseltme',
    'Delegasyon',
    'AD CS / Sertifika',
    'Kalıcılık & DC',
    'Trust & Hibrit',
    'Kimlik Erişimi',
    'Yanal Hareket',
    'Savunma Atlatma',
  ];

  Color _getDifficultyColor(String diff) {
    switch (diff) {
      case 'Başlangıç':
        return AppTheme.sysAdmin;
      case 'Orta':
        return AppTheme.toolsAmber;
      case 'İleri Seviye':
      case 'İleri':
        return AppTheme.redTeam;
      default:
        return AppTheme.blueTeam;
    }
  }

  List<AttackScenario> _getFilteredScenarios() {
    return kDefaultScenarios.where((sc) {
      final matchesCategory = _selectedCategory == 'Tümü' || sc.category == _selectedCategory;
      if (!matchesCategory) return false;

      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final inTitle = sc.title.toLowerCase().contains(q);
      final inDesc = sc.description.toLowerCase().contains(q);
      final inTags = sc.tags.any((t) => t.toLowerCase().contains(q));
      final inSteps = sc.steps.any((s) =>
          s.title.toLowerCase().contains(q) ||
          s.tool.toLowerCase().contains(q) ||
          s.command.toLowerCase().contains(q) ||
          s.detection.toLowerCase().contains(q));

      return inTitle || inDesc || inTags || inSteps;
    }).toList();
  }

  bool get _isFilterActive =>
      _searchQuery.isNotEmpty || _selectedCategory != 'Tümü';

  Map<String, int> get _categoryCounts {
    final map = <String, int>{};
    for (var s in kDefaultScenarios) {
      map[s.category] = (map[s.category] ?? 0) + 1;
    }
    return map;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredScenarios();
    final totalCount = kDefaultScenarios.length;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.redTeam.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.timeline, color: AppTheme.redTeam, size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Saldırı Zinciri Senaryoları',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const TtsPlayerBar(),
      body: Column(
        children: [
          // Arama Çubuğu
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
              style: const TextStyle(fontSize: 13, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Senaryo, araç, komut veya Event ID ara...',
                hintStyle: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: AppTheme.textMuted),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.bgCard,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.blueTeam),
                ),
              ),
            ),
          ),

          // Kategori Seçici Filtre Çipleri
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = cat == _selectedCategory;
                final count = cat == 'Tümü' ? totalCount : (_categoryCounts[cat] ?? 0);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      '$cat ($count)',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        _selectedCategory = cat;
                      });
                    },
                    backgroundColor: AppTheme.bgCard,
                    selectedColor: AppTheme.redTeam,
                    checkmarkColor: Colors.white,
                    side: BorderSide(
                      color: isSelected ? AppTheme.redTeam : AppTheme.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Sayaç Bilgisi ve Canlı Durum Çubuğu
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isFilterActive ? AppTheme.redTeam.withAlpha(140) : AppTheme.border,
                width: _isFilterActive ? 1.2 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isFilterActive ? AppTheme.redTeam : AppTheme.bgDark,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${filtered.length} / $totalCount',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isFilterActive
                        ? '${filtered.length} senaryo eşleşti ($totalCount senaryodan)'
                        : 'Tüm $totalCount uçtan uca senaryo listeleniyor',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _isFilterActive ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                ),
                if (_isFilterActive)
                  InkWell(
                    onTap: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                        _selectedCategory = 'Tümü';
                      });
                    },
                    child: const Row(
                      children: [
                        Icon(Icons.close, size: 14, color: AppTheme.redTeam),
                        SizedBox(width: 3),
                        Text(
                          'Sıfırla',
                          style: TextStyle(fontSize: 11.5, color: AppTheme.redTeam, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Senaryolar Listesi
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.search_off, size: 40, color: AppTheme.textMuted),
                        SizedBox(height: 10),
                        Text(
                          'Arama kriterlerine uygun senaryo bulunamadı.',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final sc = filtered[index];
                      final diffColor = _getDifficultyColor(sc.difficulty);

                      return Card(
                        color: AppTheme.bgCard,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: AppTheme.border),
                        ),
                        child: ExpansionTile(
                          shape: const Border(),
                          collapsedShape: const Border(),
                          tilePadding: const EdgeInsets.all(14),
                          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.redTeam.withAlpha(25),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.redTeam.withAlpha(80)),
                            ),
                            child: const Icon(Icons.flash_on, color: AppTheme.redTeam, size: 20),
                          ),
                          title: Text(
                            sc.title,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sc.description,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: diffColor.withAlpha(25),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: diffColor.withAlpha(80)),
                                      ),
                                      child: Text(
                                        sc.difficulty,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: diffColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.blueTeam.withAlpha(25),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        sc.category,
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.blueTeam,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${sc.steps.length} Aşama',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textMuted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          children: [
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            ...sc.steps.map((step) => _buildStepItem(context, step)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(BuildContext context, ScenarioStep step) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131A26),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderHighlight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppTheme.redTeam,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${step.stepNumber}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  step.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.blueTeam.withAlpha(25),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  step.tactic,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.blueTeam,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            step.description,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          // Araç ve Komut
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.bgCode,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    step.command,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 14, color: AppTheme.blueTeam),
                  tooltip: 'Komutu Kopyala',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: step.command));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Komut panoya kopyalandı!'),
                        duration: Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Tespit İpucu
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined, size: 14, color: AppTheme.sysAdmin),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tespit: ${step.detection}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.sysAdmin,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
