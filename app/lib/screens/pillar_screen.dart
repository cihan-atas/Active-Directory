import 'package:flutter/material.dart';
import '../models/content_models.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import 'article_screen.dart';
import 'subcategory_screen.dart';

class PillarScreen extends StatefulWidget {
  final Pillar pillar;

  const PillarScreen({super.key, required this.pillar});

  @override
  State<PillarScreen> createState() => _PillarScreenState();
}

class _PillarScreenState extends State<PillarScreen> {
  final AppState _appState = AppState();

  Color _getColor() {
    switch (widget.pillar.id) {
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
    final pillarColor = _getColor();

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Text(widget.pillar.name),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Öne Çıkan Rehberler ve Oyun Kitapları (Örn: Red Team PLAYBOOK.md)
          if (widget.pillar.featuredArticles.isNotEmpty) ...[
            ...widget.pillar.featuredArticles.map((feat) {
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      pillarColor.withAlpha(35),
                      AppTheme.bgCard,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: pillarColor.withAlpha(120), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: pillarColor.withAlpha(20),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ArticleScreen(
                            articleId: feat.id,
                            initialTitle: feat.title,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: pillarColor.withAlpha(40),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: pillarColor.withAlpha(140), width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.military_tech, color: pillarColor, size: 14),
                                    const SizedBox(width: 5),
                                    Text(
                                      'OPERASYONEL PLAYBOOK',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: pillarColor,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Icon(Icons.arrow_forward_ios, size: 14, color: pillarColor),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            feat.title,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                              height: 1.3,
                            ),
                          ),
                          if (feat.description.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              feat.description,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],

          // 2. Modüller Listesi
          ...widget.pillar.modules.map((mod) {
            final hasSub = mod.hasSubcategories;
            final readInMod = mod.articles.where((a) => _appState.isRead(a.id)).length;
            final totalInMod = mod.articles.length;
            final isAllModRead = totalInMod > 0 && readInMod == totalInMod;

            final itemCount = hasSub
                ? (mod.articles.isNotEmpty ? 'Rehber & ${mod.subcategories.length} Kategori' : '${mod.subcategories.length} Kategori')
                : (readInMod > 0 ? '$readInMod/$totalInMod Tamamlandı' : '$totalInMod Konu');

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                color: AppTheme.bgCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isAllModRead ? AppTheme.blueTeam : AppTheme.border,
                    width: isAllModRead ? 1.5 : 1,
                  ),
                ),
                child: ExpansionTile(
                  shape: const Border(),
                  collapsedShape: const Border(),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: pillarColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      hasSub ? Icons.category : Icons.folder,
                      color: pillarColor,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    mod.title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      itemCount,
                      style: TextStyle(
                        fontSize: 12,
                        color: pillarColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  children: [
                    const Divider(height: 1),
                    if (hasSub) ...[
                      // Modülün kendi README rehberi (Örn: Modül 11 Araç Cephaneliği Genel Bakış)
                      if (mod.articles.isNotEmpty) ...[
                        ...mod.articles.map((art) {
                          return Container(
                            margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                            decoration: BoxDecoration(
                              color: pillarColor.withAlpha(20),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: pillarColor.withAlpha(80), width: 1.2),
                            ),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              leading: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: pillarColor.withAlpha(35),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.auto_stories,
                                  color: pillarColor,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                art.title,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: pillarColor,
                                ),
                              ),
                              subtitle: art.description.isNotEmpty
                                  ? Text(
                                      art.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                                    )
                                  : null,
                              trailing: Icon(Icons.arrow_forward_ios, size: 14, color: pillarColor),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ArticleScreen(
                                      articleId: art.id,
                                      initialTitle: art.title,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        }),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: Row(
                            children: [
                              Expanded(child: Divider(height: 1, color: AppTheme.border)),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  'ARAÇ KATEGORİLERİ',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textMuted,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(height: 1, color: AppTheme.border)),
                            ],
                          ),
                        ),
                      ],
                      // Alt kategoriler (Örn: Modül 11 Kategorileri)
                      ...mod.subcategories.map((subcat) {
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                          leading: const Icon(Icons.subdirectory_arrow_right,
                              color: AppTheme.textMuted, size: 16),
                          title: Text(
                            subcat.title,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.bgCardHover,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${subcat.articles.length} araç',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right, size: 18, color: AppTheme.textMuted),
                            ],
                          ),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SubCategoryScreen(
                                  subcategory: subcat,
                                  pillarId: widget.pillar.id,
                                  pillarColor: pillarColor,
                                ),
                              ),
                            );
                            if (mounted) setState(() {});
                          },
                        );
                      }),
                    ] else ...[
                      // Konular (Modül 01-10)
                      ...mod.articles.map((art) {
                        final isReadme = art.isReadme;
                        final isRead = _appState.isRead(art.id);
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                          leading: Icon(
                            isRead
                                ? Icons.check_circle
                                : (isReadme ? Icons.auto_stories : Icons.article_outlined),
                            color: isRead
                                ? AppTheme.sysAdmin
                                : (isReadme ? pillarColor : AppTheme.blueTeam),
                            size: 16,
                          ),
                          title: Text(
                            art.title,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: isReadme ? FontWeight.bold : FontWeight.w500,
                              color: isReadme ? pillarColor : AppTheme.textPrimary,
                            ),
                          ),
                          subtitle: art.description.isNotEmpty
                              ? Text(
                                  art.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                )
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isRead) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.sysAdmin.withAlpha(25),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: AppTheme.sysAdmin.withAlpha(100)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.check_circle, size: 11, color: AppTheme.sysAdmin),
                                      SizedBox(width: 3),
                                      Text(
                                        'Okundu',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppTheme.sysAdmin,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                              const Icon(Icons.chevron_right, size: 18, color: AppTheme.textMuted),
                            ],
                          ),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ArticleScreen(
                                  articleId: art.id,
                                  initialTitle: art.title,
                                ),
                              ),
                            );
                            if (mounted) setState(() {});
                          },
                        );
                      }),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
