import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/article_screen.dart';
import '../screens/pillar_screen.dart';
import '../screens/search_screen.dart';
import '../theme/app_theme.dart';
import 'content_service.dart';

/// Active Directory Vault — Tüm Platformlar (Web & Mobil) İçin Evrensel Bağlantı Yönlendiricisi
/// Markdown içindeki göreceli linkler, çapraz referanslar ve harici web linklerini
/// %100 çevrimdışı öncelikli mimariyle ilgili ekranlara veya tarayıcıya yönlendirir.
class LinkNavigationHelper {
  /// Bir Markdown bağlantısına dokunulduğunda çağrılır.
  /// [href]: Tıklanan bağlantı adresi (örn. `../Modul_11_.../ldapsearch.md`, `https://...`, `#bolum`)
  /// [text]: Bağlantının görünen metni (örn. `ldapsearch Dokümanı`)
  /// [currentArticlePath]: Bağlantının bulunduğu mevcut makalenin dosya yolu
  /// [onLocalAnchorTap]: Makale içi çıpalarda (#bölüm) sayfa içi kaydırmayı tetikler
  static Future<void> handleLinkTap({
    required BuildContext context,
    required String? href,
    String? text,
    String? currentArticlePath,
    void Function(String anchor)? onLocalAnchorTap,
  }) async {
    if (href == null || href.trim().isEmpty) return;

    final trimmed = href.trim();

    // 1. Sayfa İçi Çıpa (#section-slug)
    if (trimmed.startsWith('#')) {
      final anchor = trimmed.substring(1);
      if (onLocalAnchorTap != null) {
        onLocalAnchorTap(anchor);
      }
      return;
    }

    // 2. Dış Web Bağlantısı (http://, https://, mailto:)
    // Kullanıcı tıkladığında doğrudan fırlatmak yerine "Kaynağa Git" ve "Kaynağı Kopyala" seçeneklerini sunar
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('mailto:')) {
      await _handleExternalUrl(context, trimmed, title: text);
      return;
    }

    // 3. İç Markdown Bağlantısı (Göreceli Yol veya Doğrudan Doküman)
    String cleanUrl = trimmed;
    String? targetAnchor;
    if (cleanUrl.contains('#')) {
      final parts = cleanUrl.split('#');
      cleanUrl = parts[0];
      targetAnchor = parts.sublist(1).join('#');
    }

    // Mevcut makalenin dizinine göre göreceli yolu çöz
    String resolvedPath = cleanUrl;
    if (currentArticlePath != null && currentArticlePath.isNotEmpty) {
      resolvedPath = resolveRelativePath(currentArticlePath, cleanUrl);
    }

    final contentService = ContentService();

    // Sütun (Pillar) kök dizini kontrolü (örn. 1-Sistem_Yoneticisi, 2-Blue_Team, 3-Red_Team)
    final pillarId = _mapPathToPillarId(resolvedPath);
    if (pillarId != null) {
      final pillar = contentService.getPillarById(pillarId);
      if (pillar != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PillarScreen(pillar: pillar)),
        );
        return;
      }
    }

    // Dokümanı arama indeksi ve 5 aşamalı akıllı fallback ile bul
    final item = contentService.findArticleItem(
      path: resolvedPath,
      tool: text,
      keyword: text,
    );

    if (item != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArticleScreen(
            articleId: item.id,
            initialTitle: item.title,
            targetSectionAnchor: targetAnchor,
          ),
        ),
      );
      return;
    }

    // Doğrudan eşleşme bulunamadıysa kullanıcıyı arama motoruna yönlendirerek sıfır çıkmaz sokak sağla
    if (context.mounted) {
      final query = (text != null && text.trim().isNotEmpty) ? text.trim() : cleanUrl;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SearchScreen(initialQuery: query),
        ),
      );
    }
  }

  /// Göreceli bir Markdown yolunu mevcut makalenin dosya yoluna göre mutlaklaştırır.
  /// Örnek:
  /// `3-Red_Team/Modul_01_Kesif/01.1_LDAP.md` + `../Modul_11/.../ldapsearch.md`
  /// -> `3-Red_Team/Modul_11/.../ldapsearch.md`
  static String resolveRelativePath(String currentPath, String relativePath) {
    if (relativePath.startsWith('/')) {
      return relativePath.substring(1);
    }

    final curNorm = currentPath.replaceAll('\\', '/');
    final relNorm = relativePath.replaceAll('\\', '/');

    final curSegments = curNorm.split('/');
    if (curSegments.isNotEmpty) {
      curSegments.removeLast(); // Dosya adını çıkar, geçerli dizinde kal
    }

    final relSegments = relNorm.split('/');
    for (final seg in relSegments) {
      if (seg == '' || seg == '.') {
        continue;
      } else if (seg == '..') {
        if (curSegments.isNotEmpty) {
          curSegments.removeLast();
        }
      } else {
        curSegments.add(seg);
      }
    }

    return curSegments.join('/');
  }

  /// Belirtilen yolun bir ana sütun kök dizinine işaret edip etmediğini kontrol eder.
  static String? _mapPathToPillarId(String path) {
    final clean = path.replaceAll('\\', '/').trim().toLowerCase();
    if (clean == '1-sistem_yoneticisi' ||
        clean == '1-sistem_yoneticisi/' ||
        clean == '1-sistem_yoneticisi/readme.md') {
      return 'sistem_yoneticisi';
    }
    if (clean == '2-blue_team' ||
        clean == '2-blue_team/' ||
        clean == '2-blue_team/readme.md') {
      return 'blue_team';
    }
    if (clean == '3-red_team' ||
        clean == '3-red_team/' ||
        clean == '3-red_team/readme.md') {
      return 'red_team';
    }
    return null;
  }

  /// Harici referans ve kaynak bağlantılarına tıklandığında "Kaynağa Git" ve "Kaynağı Kopyala" seçeneklerini sunar.
  static Future<void> _handleExternalUrl(
    BuildContext context,
    String url, {
    String? title,
  }) async {
    final cleanUrl = url.trim();
    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tutamaç / Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.borderHighlight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Başlık & İkon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.blueTeam.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.public, color: AppTheme.blueTeam, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'HARİCİ REFERANS & KAYNAK',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.blueTeam,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (title != null && title.trim().isNotEmpty)
                                ? title.trim()
                                : 'Web Bağlantısı',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // URL Gösterim Kartı
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.bgDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link, color: AppTheme.textMuted, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          cleanUrl,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // Butonlar: Kaynağı Kopyala & Kaynağa Git
                Row(
                  children: [
                    // Kaynağı Kopyala
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: AppTheme.borderHighlight),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.copy, size: 18, color: AppTheme.toolsAmber),
                        label: const Text(
                          'Kaynağı Kopyala',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: cleanUrl));
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Kaynak bağlantısı panoya kopyalandı! 📋\n$cleanUrl'),
                              duration: const Duration(seconds: 2),
                              backgroundColor: AppTheme.bgCard,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Kaynağa Git
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.blueTeam,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.launch, size: 18),
                        label: const Text(
                          'Kaynağa Git',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _openExternalUrl(context, cleanUrl);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Dış web bağlantılarını tarayıcıda veya harici uygulamada açar.
  static Future<void> _openExternalUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showCopyUrlSnackBar(context, url);
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        _showCopyUrlSnackBar(context, url);
      }
    } catch (_) {
      if (context.mounted) {
        _showCopyUrlSnackBar(context, url);
      }
    }
  }

  static void _showCopyUrlSnackBar(BuildContext context, String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Bağlantı panoya kopyalandı:\n$url'),
        duration: const Duration(seconds: 3),
        backgroundColor: AppTheme.bgCard,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
