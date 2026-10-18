import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/loot_model.dart';
import 'command_service.dart';

/// Operasyonel Karalama Defteri ve Ganimet Servisi (Scratchpad Service)
/// Sızma testlerinde elde edilen kullanıcı adları, parolalar, hash'ler,
/// hedef IP'ler ve biletleri yerel olarak saklar ve tek tıkla komut motoruna aktarır.
class ScratchpadService extends ChangeNotifier {
  static final ScratchpadService _instance = ScratchpadService._internal();
  factory ScratchpadService() => _instance;
  ScratchpadService._internal();

  static const String _storageKey = 'ad_vault_operational_loot_v1';

  List<LootItem> _items = [];
  bool _isInitialized = false;

  List<LootItem> get items => List.unmodifiable(_items);
  bool get isInitialized => _isInitialized;

  /// Servisi başlatır ve kayıtlı ganimetleri belleğe yükler
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);

      if (raw != null && raw.trim().isNotEmpty) {
        final List<dynamic> list = jsonDecode(raw);
        _items = list.map((e) => LootItem.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        // İlk kullanımda örnek başlangıç verisi ekle
        _items = _getInitialSampleLoot();
        await _save();
      }
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('ScratchpadService init hatası: $e');
      _items = [];
      _isInitialized = true;
    }
  }

  /// Yeni ganimet ekler
  Future<void> addItem(LootItem item) async {
    _items.insert(0, item);
    await _save();
    notifyListeners();
  }

  /// Mevcut ganimeti günceller
  Future<void> updateItem(LootItem item) async {
    final idx = _items.indexWhere((e) => e.id == item.id);
    if (idx != -1) {
      _items[idx] = item;
      await _save();
      notifyListeners();
    }
  }

  /// Ganimeti siler
  Future<void> deleteItem(String id) async {
    _items.removeWhere((e) => e.id == id);
    await _save();
    notifyListeners();
  }

  /// Tüm ganimet defterini temizler
  Future<void> clearAll() async {
    _items.clear();
    await _save();
    notifyListeners();
  }

  /// Ganimet maddesini Komut Oluşturucu'nun canlı hedef bağlamına (TargetContext) aktarır
  Future<void> sendToCommandContext(LootItem item) async {
    final commandService = CommandService();
    if (!commandService.isInitialized) {
      await commandService.init();
    }

    var ctx = commandService.targetContext;

    switch (item.category) {
      case LootCategory.credential:
        final val = item.primaryValue.trim();
        final user = item.secondaryValue?.trim() ?? item.title.trim();
        final isNtlm = RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(val);

        ctx = ctx.copyWith(
          user: user.isNotEmpty ? user : ctx.user,
          pass: !isNtlm && val.isNotEmpty ? val : ctx.pass,
          hash: isNtlm ? val : ctx.hash,
          domain: item.domain?.trim().isNotEmpty == true ? item.domain!.trim() : ctx.domain,
        );
        break;

      case LootCategory.targetHost:
        final ip = item.primaryValue.trim();
        final host = item.secondaryValue?.trim() ?? item.title.trim();
        final isDc = item.tags.any((t) => t.toUpperCase() == 'DC') ||
            item.title.toUpperCase().contains('DOMAIN CONTROLLER') ||
            item.title.toUpperCase().contains('DC');

        ctx = ctx.copyWith(
          targetIp: ip.isNotEmpty ? ip : ctx.targetIp,
          targetHost: host.isNotEmpty ? host : ctx.targetHost,
          dcIp: isDc && ip.isNotEmpty ? ip : ctx.dcIp,
          dcHost: isDc && host.isNotEmpty ? host : ctx.dcHost,
          domain: item.domain?.trim().isNotEmpty == true ? item.domain!.trim() : ctx.domain,
        );
        break;

      case LootCategory.kerberosTicket:
        final ticketPathOrBase64 = item.primaryValue.trim();
        final spn = item.secondaryValue?.trim();
        ctx = ctx.copyWith(
          ticket: ticketPathOrBase64.isNotEmpty ? ticketPathOrBase64 : ctx.ticket,
          spn: spn != null && spn.isNotEmpty ? spn : ctx.spn,
          domain: item.domain?.trim().isNotEmpty == true ? item.domain!.trim() : ctx.domain,
        );
        break;

      case LootCategory.adArtifact:
        final name = item.primaryValue.trim();
        final isCa = item.tags.any((t) => t.toUpperCase().contains('CA') || t.toUpperCase().contains('ESC')) ||
            item.title.toUpperCase().contains('CA');
        final isTemplate = item.tags.any((t) => t.toUpperCase().contains('TEMPLATE') || t.toUpperCase().contains('ESC'));

        ctx = ctx.copyWith(
          caName: isCa && name.isNotEmpty ? name : ctx.caName,
          templateName: isTemplate && name.isNotEmpty ? name : ctx.templateName,
          domain: item.domain?.trim().isNotEmpty == true ? item.domain!.trim() : ctx.domain,
        );
        break;

      case LootCategory.quickNote:
        if (item.domain?.trim().isNotEmpty == true) {
          ctx = ctx.copyWith(domain: item.domain!.trim());
        }
        break;
    }

    await commandService.updateTargetContext(ctx);
  }

  /// Tüm ganimetleri profesyonel sızma testi Markdown raporu olarak dışa aktarır
  String exportMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('# ⚔️ Active Directory Sızma Testi — Operasyonel Ganimet ve Karalama Defteri (Loot Sheet)');
    buffer.writeln('> **Rapor Tarihi:** ${DateTime.now().toString().split('.')[0]} · **Toplam Madde:** ${_items.length}');
    buffer.writeln('> ⚠️ **Gizlilik:** Çok Gizli / Yalnızca Yetkili Operasyon Ekipleri İçindir.');
    buffer.writeln('');
    buffer.writeln('---');
    buffer.writeln('');

    for (final cat in LootCategory.values) {
      final catItems = _items.where((e) => e.category == cat).toList();
      if (catItems.isEmpty) continue;

      buffer.writeln('## ${cat.label} (${catItems.length})');
      buffer.writeln('');
      buffer.writeln('| Başlık / Nesne | Temel Değer (Parola/Hash/IP) | İkincil Bilgi | Etki Alanı | Notlar |');
      buffer.writeln('| :--- | :--- | :--- | :--- | :--- |');

      for (final it in catItems) {
        final sec = it.secondaryValue ?? '-';
        final dom = it.domain ?? '-';
        final note = (it.notes?.replaceAll('\n', ' ') ?? '-');
        buffer.writeln('| **${it.title}** | `${it.primaryValue}` | $sec | $dom | $note |');
      }
      buffer.writeln('');
    }

    return buffer.toString();
  }

  /// Tüm verileri JSON olarak dışa aktarır
  String exportJson() {
    return const JsonEncoder.withIndent('  ').convert(
      _items.map((e) => e.toJson()).toList(),
    );
  }

  /// JSON verisini ganimet defterine ekler
  Future<int> importJson(String jsonStr) async {
    try {
      final dynamic decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        int added = 0;
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            final parsed = LootItem.fromJson(item);
            if (!_items.any((e) => e.id == parsed.id)) {
              _items.add(parsed);
              added++;
            }
          }
        }
        await _save();
        notifyListeners();
        return added;
      }
    } catch (e) {
      debugPrint('importJson hatası: $e');
    }
    return 0;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_items.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, jsonStr);
  }

  /// İlk açılışta operatöre yol gösteren örnek demo kayıtlar
  List<LootItem> _getInitialSampleLoot() {
    final now = DateTime.now();
    return [
      LootItem(
        id: 'loot_sample_1',
        category: LootCategory.credential,
        title: 'Domain Admin Hesabı (DCSync)',
        primaryValue: 'aad3b435b51404eeaad3b435b51404ee:e19ccf7504d36cedc34e212d4e6547e0',
        secondaryValue: 'Administrator',
        domain: 'corp.local',
        notes: 'DCSync saldırısı ile dc01 üzerinden çıkarıldı. PtH için kullanılabilir.',
        tags: ['Tier-0', 'Domain Admin', 'DCSync'],
        createdAt: now.subtract(const Duration(minutes: 45)),
        isSensitive: true,
      ),
      LootItem(
        id: 'loot_sample_2',
        category: LootCategory.targetHost,
        title: 'Birincil Domain Controller',
        primaryValue: '10.10.10.5',
        secondaryValue: 'DC01.corp.local',
        domain: 'corp.local',
        notes: 'Windows Server 2022. SMB Signing açık, LDAP signing kapalı.',
        tags: ['DC', 'Tier-0', 'Kerberos'],
        createdAt: now.subtract(const Duration(minutes: 90)),
        isSensitive: false,
      ),
      LootItem(
        id: 'loot_sample_3',
        category: LootCategory.credential,
        title: 'Servis Hesabı Parolası (Kerberoasting)',
        primaryValue: 'Winter2024!',
        secondaryValue: 'svc_sql',
        domain: 'corp.local',
        notes: 'SPN: MSSQLSvc/db01.corp.local:1433 üzerinden Hashcat ile kırıldı.',
        tags: ['Kerberoast', 'Service Account'],
        createdAt: now.subtract(const Duration(minutes: 120)),
        isSensitive: true,
      ),
    ];
  }
}
