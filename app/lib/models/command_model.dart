import 'dart:convert';
import 'package:flutter/material.dart';

/// Operasyonel Komut OPSEC ve Davranış Etiketleri
enum OpsecTag {
  all(id: 'all', label: 'Tüm Komutlar', icon: Icons.all_inclusive, colorHex: 0xFFF59E0B),
  stealth(id: 'stealth', label: '🟢 EDR Sessiz (Stealth)', icon: Icons.visibility_off, colorHex: 0xFF10B981),
  noisy(id: 'noisy', label: '🔴 Gürültülü (Noisy)', icon: Icons.volume_up, colorHex: 0xFFEF4444),
  readOnly(id: 'readonly', label: '🛡️ Parola Değiştirmez', icon: Icons.shield, colorHex: 0xFF3B82F6),
  offline(id: 'offline', label: '⛏️ Offline Kırma', icon: Icons.lock_open, colorHex: 0xFF8B5CF6),
  lateral(id: 'lateral', label: '⚡ Yanal Hareket', icon: Icons.swap_horiz, colorHex: 0xFFEC4899),
  adcs(id: 'adcs', label: '📜 AD CS / Sertifika', icon: Icons.badge, colorHex: 0xFF06B6D4);

  final String id;
  final String label;
  final IconData icon;
  final int colorHex;

  const OpsecTag({
    required this.id,
    required this.label,
    required this.icon,
    required this.colorHex,
  });

  Color get color => Color(colorHex);
}

/// Active Directory Vault Ana Sütunları (Pillars)
enum CommandPillar {
  all(id: 'all', label: 'Tümü', icon: Icons.all_inclusive, colorHex: 0xFFF59E0B),
  redTeam(id: 'red', label: '🔴 Red Team', icon: Icons.security, colorHex: 0xFFEF4444),
  blueTeam(id: 'blue', label: '🔵 Blue Team', icon: Icons.shield, colorHex: 0xFF3B82F6),
  system(id: 'system', label: '🟢 Sistem Yöneticisi', icon: Icons.admin_panel_settings, colorHex: 0xFF10B981);

  final String id;
  final String label;
  final IconData icon;
  final int colorHex;

  const CommandPillar({
    required this.id,
    required this.label,
    required this.icon,
    required this.colorHex,
  });

  Color get color => Color(colorHex);
}

/// Operasyonel Hedef Bağlamı ve Değişkenleri
class TargetContext {
  final String domain;
  final String netbios;
  final String dcIp;
  final String dcHost;
  final String targetIp;
  final String targetHost;
  final String user;
  final String pass;
  final String hash;
  final String ticket;
  final String spn;
  final String caName;
  final String templateName;

  const TargetContext({
    this.domain = 'corp.local',
    this.netbios = 'CORP',
    this.dcIp = '10.10.10.5',
    this.dcHost = 'DC01',
    this.targetIp = '10.10.10.20',
    this.targetHost = 'SRV01.corp.local',
    this.user = 'Administrator',
    this.pass = 'Password123!',
    this.hash = 'e19ccf7504d36cedc34e212d4e6547e0',
    this.ticket = '/tmp/admin.ccache',
    this.spn = 'cifs/SRV01.corp.local',
    this.caName = 'CORP-CA',
    this.templateName = 'ESC1',
  });

  TargetContext copyWith({
    String? domain,
    String? netbios,
    String? dcIp,
    String? dcHost,
    String? targetIp,
    String? targetHost,
    String? user,
    String? pass,
    String? hash,
    String? ticket,
    String? spn,
    String? caName,
    String? templateName,
  }) {
    return TargetContext(
      domain: domain ?? this.domain,
      netbios: netbios ?? this.netbios,
      dcIp: dcIp ?? this.dcIp,
      dcHost: dcHost ?? this.dcHost,
      targetIp: targetIp ?? this.targetIp,
      targetHost: targetHost ?? this.targetHost,
      user: user ?? this.user,
      pass: pass ?? this.pass,
      hash: hash ?? this.hash,
      ticket: ticket ?? this.ticket,
      spn: spn ?? this.spn,
      caName: caName ?? this.caName,
      templateName: templateName ?? this.templateName,
    );
  }

  Map<String, dynamic> toJson() => {
    'domain': domain,
    'netbios': netbios,
    'dcIp': dcIp,
    'dcHost': dcHost,
    'targetIp': targetIp,
    'targetHost': targetHost,
    'user': user,
    'pass': pass,
    'hash': hash,
    'ticket': ticket,
    'spn': spn,
    'caName': caName,
    'templateName': templateName,
  };

  factory TargetContext.fromJson(Map<String, dynamic> json) {
    return TargetContext(
      domain: json['domain'] ?? 'corp.local',
      netbios: json['netbios'] ?? 'CORP',
      dcIp: json['dcIp'] ?? '10.10.10.5',
      dcHost: json['dcHost'] ?? 'DC01',
      targetIp: json['targetIp'] ?? '10.10.10.20',
      targetHost: json['targetHost'] ?? 'SRV01.corp.local',
      user: json['user'] ?? 'Administrator',
      pass: json['pass'] ?? 'Password123!',
      hash: json['hash'] ?? 'e19ccf7504d36cedc34e212d4e6547e0',
      ticket: json['ticket'] ?? '/tmp/admin.ccache',
      spn: json['spn'] ?? 'cifs/SRV01.corp.local',
      caName: json['caName'] ?? 'CORP-CA',
      templateName: json['templateName'] ?? 'ESC1',
    );
  }
}

/// Favori Komut ve Kullanıcı Notu Modeli
class CommandFavorite {
  final String commandId;
  final String note;
  final String category;
  final DateTime addedAt;

  CommandFavorite({
    required this.commandId,
    this.note = '',
    this.category = 'Genel',
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'commandId': commandId,
    'note': note,
    'category': category,
    'addedAt': addedAt.toIso8601String(),
  };

  factory CommandFavorite.fromJson(Map<String, dynamic> json) {
    return CommandFavorite(
      commandId: json['commandId'] as String? ?? '',
      note: json['note'] as String? ?? '',
      category: json['category'] as String? ?? 'Genel',
      addedAt: json['addedAt'] != null
          ? DateTime.tryParse(json['addedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Active Directory Operasyonel Komut Modeli
class VaultCommand {
  final String id;
  final String tool;
  final String category;
  final String platform;
  final String title;
  final String rawCommand;
  final String template;
  final String whatItDoes;
  final String whenToUse;
  final String parameters;
  final String opsec;
  final List<String> eventIds;
  final String? docPath;
  final String? docId;
  final List<Map<String, String>> parameterList;
  final bool isUserCreated;
  bool isFavorite;
  String? userNote;
  String? customCategory;

  /// Performans için önbelleklenmiş küçük harfli arama indeksi
  late final String searchCorpus =
      '$title $tool $rawCommand $template $whatItDoes $whenToUse $parameters ${eventIds.join(" ")}'
          .toLowerCase();

  VaultCommand({
    required this.id,
    required this.tool,
    required this.category,
    required this.platform,
    required this.title,
    required this.rawCommand,
    required this.template,
    required this.whatItDoes,
    required this.whenToUse,
    required this.parameters,
    required this.opsec,
    required this.eventIds,
    this.docPath,
    this.docId,
    this.parameterList = const [],
    this.isUserCreated = false,
    this.isFavorite = false,
    this.userNote,
    this.customCategory,
  });

  /// Şablonu hedef bağlam değişkenleriyle canlı derler
  String interpolate(TargetContext ctx) {
    var result = template.isNotEmpty ? template : rawCommand;

    // Temel yer tutucular
    result = result.replaceAll('{{domain}}', ctx.domain);
    result = result.replaceAll('{{netbios}}', ctx.netbios);
    result = result.replaceAll('{{dc_ip}}', ctx.dcIp);
    result = result.replaceAll('{{dc_host}}', ctx.dcHost);
    result = result.replaceAll('{{target_ip}}', ctx.targetIp);
    result = result.replaceAll('{{target_host}}', ctx.targetHost);
    result = result.replaceAll('{{user}}', ctx.user);
    result = result.replaceAll('{{pass}}', ctx.pass);
    result = result.replaceAll('{{hash}}', ctx.hash);
    result = result.replaceAll('{{ticket}}', ctx.ticket);
    result = result.replaceAll('{{spn}}', ctx.spn);
    result = result.replaceAll('{{ca_name}}', ctx.caName);
    result = result.replaceAll('{{template}}', ctx.templateName);

    return result;
  }

  /// Komutun operasyonel güvenlik (OPSEC) ve davranış etiketlerini dinamik hesaplar
  List<OpsecTag> get opsecTags {
    final tags = <OpsecTag>[];
    final fullText = '${rawCommand.toLowerCase()} ${tool.toLowerCase()} ${opsec.toLowerCase()} ${whatItDoes.toLowerCase()}';

    // 1. EDR Sessiz (Stealth / Low Noise)
    if (fullText.contains('ldapsearch') ||
        fullText.contains('get-domainuser') ||
        fullText.contains('get-domaingroup') ||
        fullText.contains('nltest') ||
        fullText.contains('dsquery') ||
        fullText.contains('certutil -dump') ||
        fullText.contains('sessiz') ||
        fullText.contains('düşük iz') ||
        fullText.contains('read-only')) {
      tags.add(OpsecTag.stealth);
    }

    // 2. Gürültülü (Noisy / Network Scan)
    if (fullText.contains('crackmapexec') ||
        fullText.contains('netexec') ||
        fullText.contains('nmap') ||
        fullText.contains('masscan') ||
        fullText.contains('spray') ||
        fullText.contains('responder') ||
        fullText.contains('mitm6') ||
        fullText.contains('brute') ||
        fullText.contains('kerbrute') ||
        fullText.contains('taram')) {
      tags.add(OpsecTag.noisy);
    }

    // 3. Parola Değiştirmez (Read-Only / Safe)
    if (!fullText.contains('net user /add') &&
        !fullText.contains('set-domainuserpassword') &&
        !fullText.contains('changepassword') &&
        !fullText.contains('delete') &&
        !fullText.contains('remove')) {
      tags.add(OpsecTag.readOnly);
    }

    // 4. Offline Kırma
    if (fullText.contains('hashcat') ||
        fullText.contains('john') ||
        fullText.contains('tgsrepcrack') ||
        fullText.contains('asreproast') ||
        fullText.contains('kirbikator') ||
        fullText.contains('kırma') ||
        fullText.contains('wordlist')) {
      tags.add(OpsecTag.offline);
    }

    // 5. Yanal Hareket
    if (fullText.contains('psexec') ||
        fullText.contains('wmiexec') ||
        fullText.contains('smbexec') ||
        fullText.contains('winrm') ||
        fullText.contains('dcomexec') ||
        fullText.contains('atexec') ||
        fullText.contains('evil-winrm') ||
        fullText.contains('pass-the-hash')) {
      tags.add(OpsecTag.lateral);
    }

    // 6. AD CS / Sertifika
    if (fullText.contains('certipy') ||
        fullText.contains('certify') ||
        fullText.contains('forgecert') ||
        fullText.contains('pkinit') ||
        fullText.contains('gettgtpkinit') ||
        fullText.contains('sertifika')) {
      tags.add(OpsecTag.adcs);
    }

    return tags;
  }

  /// Komutun ait olduğu ana sütun (Pillar: Red Team, Blue Team, Sistem Yöneticisi)
  CommandPillar get pillar {
    if (docPath != null && docPath!.isNotEmpty) {
      final p = docPath!.toLowerCase().replaceAll('\\', '/');
      if (p.startsWith('3-red_team') || p.contains('/red_team') || p.contains('3-red')) {
        return CommandPillar.redTeam;
      }
      if (p.startsWith('2-blue_team') || p.contains('/blue_team') || p.contains('2-blue')) {
        return CommandPillar.blueTeam;
      }
      if (p.startsWith('1-sistem_yoneticisi') || p.contains('/sistem_yoneticisi') || p.contains('1-sistem')) {
        return CommandPillar.system;
      }
    }
    final c = category.toLowerCase();
    if (c.startsWith('red team') || c.contains('red team')) return CommandPillar.redTeam;
    if (c.startsWith('blue team') || c.contains('blue team')) return CommandPillar.blueTeam;
    if (c.startsWith('sistem') || c.contains('sistem yöneticisi') || c.contains('sysadmin')) {
      return CommandPillar.system;
    }
    return CommandPillar.redTeam;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tool': tool,
    'category': category,
    'platform': platform,
    'title': title,
    'rawCommand': rawCommand,
    'template': template,
    'whatItDoes': whatItDoes,
    'whenToUse': whenToUse,
    'parameters': parameters,
    'parameterList': parameterList,
    'opsec': opsec,
    'eventIds': eventIds,
    'docPath': docPath,
    'docId': docId,
    'isUserCreated': isUserCreated,
    'isFavorite': isFavorite,
    'userNote': userNote,
    'customCategory': customCategory,
  };

  factory VaultCommand.fromJson(Map<String, dynamic> json) {
    var rawParams = json['parameterList'] as List<dynamic>? ?? [];
    List<Map<String, String>> parsedParams = [];
    for (var item in rawParams) {
      if (item is Map) {
        parsedParams.add(item.map((k, v) => MapEntry(k.toString(), v.toString())));
      }
    }

    return VaultCommand(
      id: json['id'] as String? ?? 'cmd_${DateTime.now().millisecondsSinceEpoch}',
      tool: json['tool'] as String? ?? 'Genel Araç',
      category: json['category'] as String? ?? 'Genel',
      platform: json['platform'] as String? ?? 'Linux / Cross-Platform',
      title: json['title'] as String? ?? 'Başlıksız Komut',
      rawCommand: json['rawCommand'] as String? ?? '',
      template: json['template'] as String? ?? '',
      whatItDoes: json['whatItDoes'] as String? ?? '',
      whenToUse: json['whenToUse'] as String? ?? '',
      parameters: json['parameters'] as String? ?? '',
      parameterList: parsedParams,
      opsec: json['opsec'] as String? ?? '',
      eventIds: (json['eventIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      docPath: json['docPath'] as String?,
      docId: json['docId'] as String?,
      isUserCreated: json['isUserCreated'] as bool? ?? false,
      isFavorite: json['isFavorite'] as bool? ?? false,
      userNote: json['userNote'] as String?,
      customCategory: json['customCategory'] as String?,
    );
  }
}

/// Topluluk Komut Paketi Modeli
class CommunityCommandPack {
  final String name;
  final String author;
  final String description;
  final String version;
  final List<VaultCommand> commands;

  const CommunityCommandPack({
    required this.name,
    required this.author,
    required this.description,
    required this.version,
    required this.commands,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'author': author,
    'description': description,
    'version': version,
    'commands': commands.map((c) => c.toJson()).toList(),
  };

  factory CommunityCommandPack.fromJson(Map<String, dynamic> json) {
    var rawCmds = json['commands'] as List<dynamic>? ?? [];
    return CommunityCommandPack(
      name: json['name'] as String? ?? 'İsimsiz Paket',
      author: json['author'] as String? ?? 'Anonim',
      description: json['description'] as String? ?? '',
      version: json['version'] as String? ?? '1.0',
      commands: rawCmds.map((c) => VaultCommand.fromJson(c as Map<String, dynamic>)).toList(),
    );
  }

  String toFormattedJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}
