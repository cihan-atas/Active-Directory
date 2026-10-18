class Pillar {
  final String id;
  final String name;
  final String subtitle;
  final String dir;
  final String color;
  final List<ArticleSummary> featuredArticles;
  final List<ModuleItem> modules;

  Pillar({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.dir,
    required this.color,
    this.featuredArticles = const [],
    required this.modules,
  });

  factory Pillar.fromJson(Map<String, dynamic> json) {
    return Pillar(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      subtitle: json['subtitle'] ?? '',
      dir: json['dir'] ?? '',
      color: json['color'] ?? '#3b82f6',
      featuredArticles: (json['featured_articles'] as List<dynamic>? ?? [])
          .map((a) => ArticleSummary.fromJson(a))
          .toList(),
      modules: (json['modules'] as List<dynamic>? ?? [])
          .map((m) => ModuleItem.fromJson(m))
          .toList(),
    );
  }
}

class ModuleItem {
  final String id;
  final String folder;
  final String title;
  final String path;
  final bool hasSubcategories;
  final List<SubCategoryItem> subcategories;
  final List<ArticleSummary> articles;

  ModuleItem({
    required this.id,
    required this.folder,
    required this.title,
    required this.path,
    required this.hasSubcategories,
    required this.subcategories,
    required this.articles,
  });

  factory ModuleItem.fromJson(Map<String, dynamic> json) {
    return ModuleItem(
      id: json['id'] ?? '',
      folder: json['folder'] ?? '',
      title: json['title'] ?? '',
      path: json['path'] ?? '',
      hasSubcategories: json['has_subcategories'] ?? false,
      subcategories: (json['subcategories'] as List<dynamic>? ?? [])
          .map((s) => SubCategoryItem.fromJson(s))
          .toList(),
      articles: (json['articles'] as List<dynamic>? ?? [])
          .map((a) => ArticleSummary.fromJson(a))
          .toList(),
    );
  }
}

class SubCategoryItem {
  final String id;
  final String folder;
  final String title;
  final String path;
  final List<ArticleSummary> articles;

  SubCategoryItem({
    required this.id,
    required this.folder,
    required this.title,
    required this.path,
    required this.articles,
  });

  factory SubCategoryItem.fromJson(Map<String, dynamic> json) {
    return SubCategoryItem(
      id: json['id'] ?? '',
      folder: json['folder'] ?? '',
      title: json['title'] ?? '',
      path: json['path'] ?? '',
      articles: (json['articles'] as List<dynamic>? ?? [])
          .map((a) => ArticleSummary.fromJson(a))
          .toList(),
    );
  }
}

class ArticleSummary {
  final String id;
  final String title;
  final String description;
  final String path;
  final bool isReadme;

  ArticleSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.path,
    required this.isReadme,
  });

  factory ArticleSummary.fromJson(Map<String, dynamic> json) {
    return ArticleSummary(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      path: json['path'] ?? '',
      isReadme: json['is_readme'] ?? false,
    );
  }
}

class ArticleDetail {
  final String id;
  final String title;
  final String description;
  final String path;
  final String filename;
  final String pillarId;
  final String moduleId;
  final String? subcategoryId;
  final String category;
  final String content;
  final String searchText;
  final bool isReadme;

  ArticleDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.path,
    required this.filename,
    required this.pillarId,
    required this.moduleId,
    this.subcategoryId,
    required this.category,
    required this.content,
    required this.searchText,
    required this.isReadme,
  });

  factory ArticleDetail.fromJson(Map<String, dynamic> json) {
    return ArticleDetail(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      path: json['path'] ?? '',
      filename: json['filename'] ?? '',
      pillarId: json['pillar_id'] ?? '',
      moduleId: json['module_id'] ?? '',
      subcategoryId: json['subcategory_id'],
      category: json['category'] ?? '',
      content: json['content'] ?? '',
      searchText: json['search_text'] ?? '',
      isReadme: json['is_readme'] ?? false,
    );
  }
}

class SearchIndexItem {
  final String id;
  final String title;
  final String description;
  final String category;
  final String path;
  final String pillarId;
  final String moduleId;
  final bool isReadme;
  final String searchText;

  SearchIndexItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.path,
    required this.pillarId,
    required this.moduleId,
    required this.isReadme,
    required this.searchText,
  });

  factory SearchIndexItem.fromJson(Map<String, dynamic> json) {
    return SearchIndexItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      path: json['path'] ?? '',
      pillarId: json['pillar_id'] ?? '',
      moduleId: json['module_id'] ?? '',
      isReadme: json['is_readme'] ?? false,
      searchText: json['search_text'] ?? '',
    );
  }
}
