import 'package:flutter/material.dart';
import '../models/content_models.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import 'article_screen.dart';

class SubCategoryScreen extends StatefulWidget {
  final SubCategoryItem subcategory;
  final String pillarId;
  final Color pillarColor;

  const SubCategoryScreen({
    super.key,
    required this.subcategory,
    required this.pillarId,
    required this.pillarColor,
  });

  @override
  State<SubCategoryScreen> createState() => _SubCategoryScreenState();
}

class _SubCategoryScreenState extends State<SubCategoryScreen> {
  final AppState _appState = AppState();
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final filteredArticles = widget.subcategory.articles.where((a) {
      if (_filter.isEmpty) return true;
      final q = _filter.toLowerCase();
      return a.title.toLowerCase().contains(q) || a.description.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Text(widget.subcategory.title),
      ),
      body: Column(
        children: [
          // Arama Filtresi
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (val) => setState(() => _filter = val),
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: '${widget.subcategory.title} içinde filtrele...',
                hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.filter_list, color: AppTheme.textMuted, size: 20),
                filled: true,
                fillColor: AppTheme.bgCard,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  borderSide: BorderSide(color: widget.pillarColor),
                ),
              ),
            ),
          ),
          // Araç/Konu Listesi
          Expanded(
            child: filteredArticles.isEmpty
                ? const Center(
                    child: Text(
                      'Sonuç bulunamadı.',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredArticles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = filteredArticles[index];
                      final isReadme = item.isReadme;
                      final isRead = _appState.isRead(item.id);

                      return Card(
                        color: isReadme ? AppTheme.bgCardHover : AppTheme.bgCard,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isRead
                                ? AppTheme.sysAdmin.withAlpha(90)
                                : (isReadme ? widget.pillarColor.withAlpha(120) : AppTheme.border),
                            width: isRead || isReadme ? 1.2 : 1,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ArticleScreen(
                                  articleId: item.id,
                                  initialTitle: item.title,
                                ),
                              ),
                            );
                            if (mounted) setState(() {});
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isRead
                                        ? AppTheme.sysAdmin.withAlpha(30)
                                        : (isReadme ? widget.pillarColor : AppTheme.blueTeam)
                                            .withAlpha(30),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isRead
                                        ? Icons.check_circle
                                        : (isReadme ? Icons.auto_stories : Icons.terminal),
                                    size: 18,
                                    color: isRead
                                        ? AppTheme.sysAdmin
                                        : (isReadme ? widget.pillarColor : AppTheme.blueTeam),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.bold,
                                          color: isReadme
                                              ? widget.pillarColor
                                              : AppTheme.textPrimary,
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
                                const SizedBox(width: 8),
                                if (isRead) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.sysAdmin.withAlpha(25),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppTheme.sysAdmin.withAlpha(120)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.check_circle, size: 12, color: AppTheme.sysAdmin),
                                        SizedBox(width: 4),
                                        Text(
                                          'Okundu',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: AppTheme.sysAdmin,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                const Icon(
                                  Icons.chevron_right,
                                  color: AppTheme.textMuted,
                                  size: 20,
                                ),
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
