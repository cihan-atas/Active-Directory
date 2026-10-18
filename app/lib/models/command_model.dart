import 'dart:convert';

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
