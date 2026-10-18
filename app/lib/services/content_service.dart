import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/content_models.dart';

class ContentService {
  static final ContentService _instance = ContentService._internal();
  factory ContentService() => _instance;
  ContentService._internal();

  List<Pillar> _pillars = [];
  List<SearchIndexItem> _searchIndex = [];
  Map<String, dynamic>? _rawArticlesMap;
  final Map<String, ArticleDetail> _articleCache = {};
  Set<String> _bookmarkedIds = {};
  Map<String, dynamic> _stats = {};
  bool _isInitialized = false;

  List<Pillar> get pillars => _pillars;
  List<SearchIndexItem> get searchIndex => _searchIndex;
  Set<String> get bookmarkedIds => _bookmarkedIds;
  Map<String, dynamic> get stats => _stats;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // 1. Hiyerarşiyi Yükle
      final hierarchyStr = await rootBundle.loadString('assets/data/hierarchy.json');
      final List<dynamic> hierarchyJson = json.decode(hierarchyStr);
      _pillars = hierarchyJson.map((p) => Pillar.fromJson(p)).toList();

      // 2. Arama İndeksini Yükle
      final searchStr = await rootBundle.loadString('assets/data/search_index.json');
      final List<dynamic> searchJson = json.decode(searchStr);
      _searchIndex = searchJson.map((s) => SearchIndexItem.fromJson(s)).toList();

      // 3. İstatistikleri Yükle
      try {
        final statsStr = await rootBundle.loadString('assets/data/stats.json');
        _stats = json.decode(statsStr);
      } catch (_) {}

      // 4. Yer İmlerini Yükle
      final prefs = await SharedPreferences.getInstance();
      final savedBookmarks = prefs.getStringList('saved_bookmarks') ?? [];
      _bookmarkedIds = savedBookmarks.toSet();

      _isInitialized = true;
    } catch (e) {
      // ignore: avoid_print
      print('ContentService init hatası: $e');
    }
  }

  SearchIndexItem? findArticleItem({String? path, String? tool, String? keyword}) {
    if ((path == null || path.trim().isEmpty) &&
        (tool == null || tool.trim().isEmpty) &&
        (keyword == null || keyword.trim().isEmpty)) {
      return null;
    }

    final pNorm = path?.replaceAll('\\', '/').toLowerCase().trim() ?? '';
    final toolNorm = tool?.toLowerCase().trim() ?? '';
    final kwNorm = keyword?.toLowerCase().trim() ?? '';

    // 1. Tam yol veya endsWith eşleşmesi
    if (pNorm.isNotEmpty) {
      for (final item in _searchIndex) {
        final ip = item.path.toLowerCase();
        if (ip == pNorm || ip.endsWith(pNorm) || pNorm.endsWith(ip)) {
          return item;
        }
      }

      // 2. Dosya adı eşleşmesi (örn. Snaffler.md veya enum4linux-ng.md)
      final fname = pNorm.split('/').last;
      if (fname.isNotEmpty) {
        for (final item in _searchIndex) {
          final ifname = item.path.split('/').last.toLowerCase();
          if (ifname == fname) {
            return item;
          }
        }
      }

      // 3. Modül Numarası Öneki (örn. 01.1_ veya 07.2_)
      final prefixMatch = RegExp(r'(\d+\.\d+)').firstMatch(pNorm);
      if (prefixMatch != null) {
        final prefix = prefixMatch.group(1)!;
        for (final item in _searchIndex) {
          final ip = item.path.toLowerCase();
          if (ip.contains('/${prefix}_') || ip.contains('/$prefix.')) {
            return item;
          }
        }
      }
    }

    // 4. Araç adına göre arama (örn. mimikatz, certipy, rubeus)
    if (toolNorm.isNotEmpty) {
      final cleanTool = toolNorm.split(' ').first.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '');
      if (cleanTool.isNotEmpty) {
        for (final item in _searchIndex) {
          final ifname = item.path.split('/').last.toLowerCase();
          if (ifname == '$cleanTool.md' || ifname.startsWith('$cleanTool.')) {
            return item;
          }
        }
        for (final item in _searchIndex) {
          if (item.title.toLowerCase() == toolNorm || item.title.toLowerCase().startsWith(cleanTool)) {
            return item;
          }
        }
      }
    }

    // 5. Başlık veya anahtar kelime eşleşmesi
    if (kwNorm.isNotEmpty) {
      final words = RegExp(r'\w{4,}').allMatches(kwNorm).map((m) => m.group(0)!).toList();
      if (words.isNotEmpty) {
        for (final item in _searchIndex) {
          final combined = '${item.title} ${item.path}'.toLowerCase();
          if (words.any((w) => combined.contains(w))) {
            return item;
          }
        }
      }
    }

    return null;
  }

  Future<ArticleDetail?> getArticle(String id, {String? fallbackTitle}) async {
    if (_articleCache.containsKey(id)) {
      return _articleCache[id];
    }

    if (_rawArticlesMap == null) {
      final articlesStr = await rootBundle.loadString('assets/data/articles.json');
      _rawArticlesMap = json.decode(articlesStr) as Map<String, dynamic>;
    }

    if (_rawArticlesMap != null) {
      if (_rawArticlesMap!.containsKey(id)) {
        final detail = ArticleDetail.fromJson(_rawArticlesMap![id]);
        _articleCache[id] = detail;
        return detail;
      }

      // Yol veya dosya adı ile arama
      final normalizedId = id.replaceAll('\\', '/').toLowerCase();
      for (final entry in _rawArticlesMap!.values) {
        if (entry is Map<String, dynamic>) {
          final path = (entry['path'] as String? ?? '').replaceAll('\\', '/').toLowerCase();
          final filename = (entry['filename'] as String? ?? '').toLowerCase();
          final entryId = (entry['id'] as String? ?? '').toLowerCase();

          if (path == normalizedId ||
              path.endsWith('/$normalizedId') ||
              entryId == normalizedId ||
              (normalizedId.endsWith('.md') && path.endsWith(normalizedId)) ||
              filename == normalizedId) {
            final detail = ArticleDetail.fromJson(entry);
            _articleCache[id] = detail;
            return detail;
          }
        }
      }

      // Eğer hala bulunamadıysa akıllı fallback aramasını devreye sok
      final matchedItem = findArticleItem(path: id, tool: fallbackTitle, keyword: fallbackTitle);
      if (matchedItem != null && _rawArticlesMap!.containsKey(matchedItem.id)) {
        final detail = ArticleDetail.fromJson(_rawArticlesMap![matchedItem.id]);
        _articleCache[id] = detail;
        _articleCache[matchedItem.id] = detail;
        return detail;
      }
    }

    return null;
  }

  Future<void> toggleBookmark(String id) async {
    if (_bookmarkedIds.contains(id)) {
      _bookmarkedIds.remove(id);
    } else {
      _bookmarkedIds.add(id);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_bookmarks', _bookmarkedIds.toList());
  }

  bool isBookmarked(String id) => _bookmarkedIds.contains(id);

  List<SearchIndexItem> search(String query, {String? pillarFilter}) {
    if (query.trim().isEmpty) return [];

    final cleanQuery = query.trim().toLowerCase();
    final tokens = cleanQuery.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    return _searchIndex.where((item) {
      if (pillarFilter != null && pillarFilter != 'all') {
        if (pillarFilter == 'modul_11') {
          if (!item.moduleId.contains('Modul_11')) return false;
        } else if (item.pillarId != pillarFilter) {
          return false;
        }
      }

      // Tüm kelimelerin eşleşmesi aranır
      final text = '${item.title} ${item.description} ${item.category} ${item.path}'.toLowerCase();
      for (final token in tokens) {
        if (!text.contains(token)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        // Tam başlık eşleşmelerine öncelik ver
        final aTitle = a.title.toLowerCase();
        final bTitle = b.title.toLowerCase();
        final aExact = aTitle.contains(cleanQuery);
        final bExact = bTitle.contains(cleanQuery);
        if (aExact && !bExact) return -1;
        if (!aExact && bExact) return 1;
        return 0;
      });
  }

  List<SearchIndexItem> getBookmarkedItems() {
    return _searchIndex.where((item) => _bookmarkedIds.contains(item.id)).toList();
  }

  Pillar? getPillarById(String id) {
    try {
      return _pillars.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  ModuleItem? getModuleById(String id) {
    for (final pillar in _pillars) {
      for (final mod in pillar.modules) {
        if (mod.id == id) return mod;
      }
    }
    return null;
  }
}
