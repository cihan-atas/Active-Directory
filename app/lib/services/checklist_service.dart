import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/checklist_models.dart';

class ChecklistService extends ChangeNotifier {
  static final ChecklistService _instance = ChecklistService._internal();
  factory ChecklistService() => _instance;
  ChecklistService._internal();

  List<ChecklistProfile> _profiles = [];
  String _activeProfileId = 'prof_default';
  bool _isInitialized = false;

  List<ChecklistProfile> get profiles => List.unmodifiable(_profiles);
  String get activeProfileId => _activeProfileId;
  bool get isInitialized => _isInitialized;

  ChecklistProfile get activeProfile {
    if (_profiles.isEmpty) {
      final def = ChecklistProfile(
        id: 'prof_default',
        name: 'Kurumsal AD Pentest Operasyonu',
        targetDomain: 'corp.local',
        targetDcIp: '192.168.1.10',
        createdAt: DateTime.now(),
      );
      _profiles.add(def);
      return def;
    }
    return _profiles.firstWhere(
      (p) => p.id == _activeProfileId,
      orElse: () => _profiles.first,
    );
  }

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('saved_checklist_profiles_json');
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> list = json.decode(raw);
        _profiles = list.map((item) => ChecklistProfile.fromJson(item)).toList();
      }

      final activeId = prefs.getString('active_checklist_profile_id');
      if (activeId != null && activeId.isNotEmpty) {
        _activeProfileId = activeId;
      }

      if (_profiles.isEmpty) {
        _profiles.add(ChecklistProfile(
          id: 'prof_default',
          name: 'Kurumsal AD Pentest Operasyonu',
          targetDomain: 'corp.local',
          targetDcIp: '192.168.1.10',
          createdAt: DateTime.now(),
        ));
      }
    } catch (_) {}
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = json.encode(_profiles.map((p) => p.toJson()).toList());
      await prefs.setString('saved_checklist_profiles_json', raw);
      await prefs.setString('active_checklist_profile_id', _activeProfileId);
    } catch (_) {}
  }

  Future<void> createProfile({
    required String name,
    required String targetDomain,
    required String targetDcIp,
  }) async {
    final newProf = ChecklistProfile(
      id: 'prof_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim().isNotEmpty ? name.trim() : 'Yeni Operasyon',
      targetDomain: targetDomain.trim().isNotEmpty ? targetDomain.trim() : 'corp.local',
      targetDcIp: targetDcIp.trim().isNotEmpty ? targetDcIp.trim() : '192.168.1.10',
      createdAt: DateTime.now(),
    );
    _profiles.insert(0, newProf);
    _activeProfileId = newProf.id;
    await _persist();
    notifyListeners();
  }

  Future<void> updateActiveProfile({
    required String name,
    required String targetDomain,
    required String targetDcIp,
  }) async {
    final p = activeProfile;
    p.name = name.trim();
    p.targetDomain = targetDomain.trim();
    p.targetDcIp = targetDcIp.trim();
    await _persist();
    notifyListeners();
  }

  Future<void> setActiveProfile(String id) async {
    _activeProfileId = id;
    await _persist();
    notifyListeners();
  }

  Future<void> deleteProfile(String id) async {
    if (_profiles.length <= 1) return; // En az bir profil kalmalı
    _profiles.removeWhere((p) => p.id == id);
    if (_activeProfileId == id) {
      _activeProfileId = _profiles.first.id;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> setItemStatus(String itemId, ChecklistStatus status) async {
    activeProfile.setStatus(itemId, status);
    await _persist();
    notifyListeners();
  }

  Future<void> cycleItemStatus(String itemId) async {
    final current = activeProfile.getStatus(itemId);
    ChecklistStatus next;
    switch (current) {
      case ChecklistStatus.pending:
        next = ChecklistStatus.completed;
        break;
      case ChecklistStatus.completed:
        next = ChecklistStatus.failed;
        break;
      case ChecklistStatus.failed:
        next = ChecklistStatus.na;
        break;
      case ChecklistStatus.na:
        next = ChecklistStatus.pending;
        break;
    }
    await setItemStatus(itemId, next);
  }

  Future<void> setItemNote(String itemId, String note) async {
    activeProfile.setNote(itemId, note);
    await _persist();
    notifyListeners();
  }

  Future<void> resetActiveProfile() async {
    activeProfile.itemStatuses.clear();
    activeProfile.itemNotes.clear();
    await _persist();
    notifyListeners();
  }

  // İstatistikler
  int get totalItemsCount => kDefaultChecklistItems.length;

  int get completedCount => kDefaultChecklistItems
      .where((item) => activeProfile.getStatus(item.id) == ChecklistStatus.completed)
      .length;

  int get failedCount => kDefaultChecklistItems
      .where((item) => activeProfile.getStatus(item.id) == ChecklistStatus.failed)
      .length;

  int get naCount => kDefaultChecklistItems
      .where((item) => activeProfile.getStatus(item.id) == ChecklistStatus.na)
      .length;

  int get pendingCount => totalItemsCount - (completedCount + failedCount + naCount);

  double get progressRatio =>
      totalItemsCount > 0 ? (completedCount / totalItemsCount) : 0.0;

  // Markdown Raporu Oluşturucu
  String exportReportMarkdown() {
    final p = activeProfile;
    final now = DateTime.now();
    final buffer = StringBuffer();

    buffer.writeln('# 🛡️ Active Directory Sızma Testi ve Denetim Raporu');
    buffer.writeln('');
    buffer.writeln('> **Operasyon:** ${p.name}');
    buffer.writeln('> **Hedef Etki Alanı:** `${p.targetDomain}` · **DC IP:** `${p.targetDcIp}`');
    buffer.writeln('> **Tarih:** ${now.day}.${now.month}.${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}');
    buffer.writeln('> **İlerleme / Tamamlanma:** %${(progressRatio * 100).toStringAsFixed(1)} ($completedCount / $totalItemsCount Madde)');
    buffer.writeln('');
    buffer.writeln('---');
    buffer.writeln('');
    buffer.writeln('## 📊 1. Özet İstatistikler');
    buffer.writeln('');
    buffer.writeln('| Durum | Madde Sayısı | Yüzde |');
    buffer.writeln('|-------|--------------|-------|');
    buffer.writeln('| 🟢 Başarılı / Zafiyet Bulundu | $completedCount | %${((completedCount / totalItemsCount) * 100).toStringAsFixed(1)} |');
    buffer.writeln('| 🔴 Başarısız / Koruma Mevcut | $failedCount | %${((failedCount / totalItemsCount) * 100).toStringAsFixed(1)} |');
    buffer.writeln('| 🟡 Kapsam Dışı / Uygulanamaz | $naCount | %${((naCount / totalItemsCount) * 100).toStringAsFixed(1)} |');
    buffer.writeln('| ⚪ Denenmedi / Bekliyor | $pendingCount | %${((pendingCount / totalItemsCount) * 100).toStringAsFixed(1)} |');
    buffer.writeln('');
    buffer.writeln('---');
    buffer.writeln('');
    buffer.writeln('## 🎯 2. Faz Bazlı Operasyonel Bulgular ve Denetim Notları');
    buffer.writeln('');

    final phases = <String, List<ChecklistItem>>{};
    for (final item in kDefaultChecklistItems) {
      phases.putIfAbsent(item.phaseTitle, () => []).add(item);
    }

    for (final entry in phases.entries) {
      buffer.writeln('### ${entry.key}');
      buffer.writeln('');

      for (final item in entry.value) {
        final status = p.getStatus(item.id);
        String icon;
        switch (status) {
          case ChecklistStatus.completed:
            icon = '[✓]';
            break;
          case ChecklistStatus.failed:
            icon = '[X]';
            break;
          case ChecklistStatus.na:
            icon = '[-]';
            break;
          case ChecklistStatus.pending:
            icon = '[ ]';
            break;
        }

        buffer.writeln('- $icon **${item.title}** (`${item.mitreTechnique ?? "AD"}`)');
        buffer.writeln('  - **Açıklama:** ${item.description}');
        if (item.recommendedTool != null) {
          buffer.writeln('  - **Önerilen Araç:** `${item.recommendedTool}`');
        }
        if (item.exampleCommand != null) {
          buffer.writeln('  - **Örnek Komut:** `${item.exampleCommand}`');
        }
        final note = p.getNote(item.id);
        if (note.isNotEmpty) {
          buffer.writeln('  - **📝 Operasyonel Not / Bulgu:** $note');
        }
        buffer.writeln('');
      }
    }

    buffer.writeln('---');
    buffer.writeln('');
    buffer.writeln('*Bu rapor Active Directory Vault Çevrimdışı Sızma Testi ve Denetim Cephaneliği ile oluşturulmuştur.*');

    return buffer.toString();
  }
}
