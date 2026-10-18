import 'package:flutter/material.dart';
import '../models/content_models.dart';
import '../services/content_service.dart';
import '../theme/app_theme.dart';
import 'article_screen.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;

  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ContentService _contentService = ContentService();
  final TextEditingController _controller = TextEditingController();
  List<SearchIndexItem> _results = [];
  String _selectedFilter = 'all';

  final List<Map<String, String>> _filters = [
    {'id': 'all', 'label': 'Tümü'},
    {'id': 'red_team', 'label': 'Red Team'},
    {'id': 'blue_team', 'label': 'Blue Team'},
    {'id': 'sistem_yoneticisi', 'label': 'SysAdmin'},
    {'id': 'modul_11', 'label': 'Modül 11 (Araçlar)'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _controller.text = widget.initialQuery!;
      _performSearch(widget.initialQuery!);
    }
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    final res = _contentService.search(query, pillarFilter: _selectedFilter);
    setState(() => _results = res);
  }

  Color _getPillarColor(String pillarId) {
    switch (pillarId) {
      case 'red_team':
        return AppTheme.redTeam;
      case 'blue_team':
        return AppTheme.blueTeam;
      case 'sistem_yoneticisi':
        return AppTheme.sysAdmin;
      default:
        return AppTheme.redTeam;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('Hızlı Çevrimdışı Arama'),
      ),
      body: Column(
        children: [
          // Arama Girişi
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
              onChanged: _performSearch,
              decoration: InputDecoration(
                hintText: 'Araç, teknik, komut veya Event ID ara... (Örn: mimikatz, 4624, rbcd)',
                hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppTheme.textMuted, size: 20),
                        onPressed: () {
                          _controller.clear();
                          _performSearch('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.bgCard,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: AppTheme.redTeam),
                ),
              ),
            ),
          ),
          // Filtre Butonları (Chips)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: _filters.map((f) {
                final isSelected = _selectedFilter == f['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text(f['label']!),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                    ),
                    backgroundColor: AppTheme.bgCard,
                    selectedColor: AppTheme.redTeam.withAlpha(80),
                    side: BorderSide(
                      color: isSelected ? AppTheme.redTeam : AppTheme.border,
                    ),
                    onSelected: (val) {
                      setState(() => _selectedFilter = f['id']!);
                      _performSearch(_controller.text);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Arama Sonuçları
          Expanded(
            child: _controller.text.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.manage_search, size: 64, color: AppTheme.textMuted),
                        SizedBox(height: 12),
                        Text(
                          '315 doküman ve 146 araç içinde anında arama yapın.',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5),
                        ),
                      ],
                    ),
                  )
                : _results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off, size: 48, color: AppTheme.textMuted),
                            const SizedBox(height: 12),
                            Text(
                              '"${_controller.text}" ile eşleşen sonuç bulunamadı.',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          final pillarColor = _getPillarColor(item.pillarId);

                          return Card(
                            color: AppTheme.bgCard,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(color: AppTheme.border),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ArticleScreen(
                                      articleId: item.id,
                                      initialTitle: item.title,
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(14.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: pillarColor.withAlpha(30),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            item.category.isNotEmpty
                                                ? item.category
                                                : item.pillarId.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: pillarColor,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          item.path.split('/').last,
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 11,
                                            color: AppTheme.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      item.title,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    if (item.description.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        item.description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: AppTheme.textSecondary,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
