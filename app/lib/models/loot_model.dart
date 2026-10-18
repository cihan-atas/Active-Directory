import 'dart:convert';
import 'package:flutter/material.dart';

/// Ganimet ve Karalama Defteri Kategori Türleri
enum LootCategory {
  credential(
    id: 'credential',
    label: 'Kimlik Bilgisi (Hesap & Parola)',
    iconCode: 0xe6e1, // vpn_key_outlined
    badgeColorHex: 0xFFEF4444, // Red
  ),
  targetHost(
    id: 'target_host',
    label: 'Hedef Makine (DC / Sunucu)',
    iconCode: 0xe1e2, // dns_outlined
    badgeColorHex: 0xFF3B82F6, // Blue
  ),
  kerberosTicket(
    id: 'kerberos_ticket',
    label: 'Kerberos Bileti (TGT / TGS)',
    iconCode: 0xe179, // confirmation_number_outlined
    badgeColorHex: 0xFFF59E0B, // Amber
  ),
  adArtifact(
    id: 'ad_artifact',
    label: 'AD Nesnesi / Yetkisi / Grup',
    iconCode: 0xe5bf, // shield_outlined
    badgeColorHex: 0xFF10B981, // Emerald
  ),
  quickNote(
    id: 'quick_note',
    label: 'Operasyonel Not & Loot',
    iconCode: 0xe426, // note_alt_outlined
    badgeColorHex: 0xFF8B5CF6, // Purple
  );

  final String id;
  final String label;
  final int iconCode;
  final int badgeColorHex;

  const LootCategory({
    required this.id,
    required this.label,
    required this.iconCode,
    required this.badgeColorHex,
  });

  IconData get icon {
    switch (this) {
      case LootCategory.credential:
        return Icons.vpn_key_outlined;
      case LootCategory.targetHost:
        return Icons.dns_outlined;
      case LootCategory.kerberosTicket:
        return Icons.confirmation_number_outlined;
      case LootCategory.adArtifact:
        return Icons.shield_outlined;
      case LootCategory.quickNote:
        return Icons.note_alt_outlined;
    }
  }

  static LootCategory fromId(String? id) {
    for (final c in values) {
      if (c.id == id) return c;
    }
    return LootCategory.quickNote;
  }
}

/// Sızma Testi Operasyonel Ganimet ve Karalama Defteri Maddesi
class LootItem {
  final String id;
  final LootCategory category;
  final String title;
  final String primaryValue; // Parola, Hash, IP, Bilet verisi, Nesne Adı
  final String? secondaryValue; // Kullanıcı adı, Host FQDN, SPN
  final String? domain; // corp.local
  final String? notes; // Operasyonel not, makine detayı
  final List<String> tags; // ['Tier-0', 'Domain Admin', 'LAPS', 'Kerberoast']
  final DateTime createdAt;
  final bool isSensitive; // Parola / Hash maskeleme için

  LootItem({
    required this.id,
    required this.category,
    required this.title,
    required this.primaryValue,
    this.secondaryValue,
    this.domain,
    this.notes,
    List<String>? tags,
    DateTime? createdAt,
    this.isSensitive = true,
  })  : tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now();

  LootItem copyWith({
    String? id,
    LootCategory? category,
    String? title,
    String? primaryValue,
    String? secondaryValue,
    String? domain,
    String? notes,
    List<String>? tags,
    DateTime? createdAt,
    bool? isSensitive,
  }) {
    return LootItem(
      id: id ?? this.id,
      category: category ?? this.category,
      title: title ?? this.title,
      primaryValue: primaryValue ?? this.primaryValue,
      secondaryValue: secondaryValue ?? this.secondaryValue,
      domain: domain ?? this.domain,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      isSensitive: isSensitive ?? this.isSensitive,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category.id,
        'title': title,
        'primaryValue': primaryValue,
        'secondaryValue': secondaryValue,
        'domain': domain,
        'notes': notes,
        'tags': tags,
        'createdAt': createdAt.toIso8601String(),
        'isSensitive': isSensitive,
      };

  factory LootItem.fromJson(Map<String, dynamic> json) => LootItem(
        id: json['id'] as String? ?? 'loot_${DateTime.now().millisecondsSinceEpoch}',
        category: LootCategory.fromId(json['category'] as String?),
        title: json['title'] as String? ?? 'İsimsiz Ganimet',
        primaryValue: json['primaryValue'] as String? ?? '',
        secondaryValue: json['secondaryValue'] as String?,
        domain: json['domain'] as String?,
        notes: json['notes'] as String?,
        tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        isSensitive: json['isSensitive'] as bool? ?? true,
      );

  @override
  String toString() => jsonEncode(toJson());
}
