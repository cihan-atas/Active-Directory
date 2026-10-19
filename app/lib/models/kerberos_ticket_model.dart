import 'dart:convert';
import 'dart:typed_data';

/// Kerberos Şifreleme Algoritması (RFC 4120 / RFC 3962)
enum KerberosEtype {
  desCbcCrc(1, 'DES-CBC-CRC', false),
  desCbcMd5(3, 'DES-CBC-MD5', false),
  des3CbcSha1(16, 'DES3-CBC-SHA1', false),
  aes128CtsHmacSha1(17, 'AES128-CTS-HMAC-SHA1-96', true),
  aes256CtsHmacSha1(18, 'AES256-CTS-HMAC-SHA1-96', true),
  rc4Hmac(23, 'RC4-HMAC (NTLM)', false),
  rc4HmacExp(24, 'RC4-HMAC-EXP', false),
  unknown(-1, 'Bilinmeyen Algoritma', false);

  final int id;
  final String label;
  final bool isStrong;

  const KerberosEtype(this.id, this.label, this.isStrong);

  static KerberosEtype fromId(int? id) {
    if (id == null) return KerberosEtype.unknown;
    for (final e in values) {
      if (e.id == id) return e;
    }
    return KerberosEtype.unknown;
  }
}

/// Çözümlenmiş Kerberos Bilet Verisi
class KerberosTicketData {
  final String ticketType; // TGT, TGS, Service Ticket
  final String clientPrincipal; // user@DOMAIN.COM
  final String servicePrincipal; // krbtgt/DOMAIN.COM veya CIFS/host
  final String realm; // DOMAIN.COM
  final KerberosEtype etype;
  final DateTime? startTime;
  final DateTime? endTime;
  final DateTime? renewTill;
  final List<String> flags;
  final String? sessionKey;
  final String rawSourceFormat; // Base64 Kirbi (KRB-CRED), CCache (Linux), Terminal Text
  final Map<String, dynamic> rawFields;

  KerberosTicketData({
    required this.ticketType,
    required this.clientPrincipal,
    required this.servicePrincipal,
    required this.realm,
    required this.etype,
    this.startTime,
    this.endTime,
    this.renewTill,
    List<String>? flags,
    this.sessionKey,
    this.rawSourceFormat = 'Kirbi (KRB-CRED)',
    Map<String, dynamic>? rawFields,
  })  : flags = flags ?? [],
        rawFields = rawFields ?? {};

  bool get isExpired {
    if (endTime == null) return false;
    return DateTime.now().isAfter(endTime!);
  }

  Duration? get remainingTime {
    if (endTime == null) return null;
    final now = DateTime.now();
    if (now.isAfter(endTime!)) return Duration.zero;
    return endTime!.difference(now);
  }

  String get remainingTimeFormatted {
    if (endTime == null) return 'Süresiz / Bilinmiyor';
    if (isExpired) return 'SÜRESİ DOLDU (Expired)';
    final rem = remainingTime!;
    final hours = rem.inHours;
    final minutes = rem.inMinutes % 60;
    if (hours > 24) {
      final days = rem.inDays;
      return '$days gün ${hours % 24} sa kaldı';
    }
    return '$hours sa $minutes dk kaldı';
  }

  bool get isTgt {
    final s = servicePrincipal.toLowerCase();
    return s.startsWith('krbtgt/') || ticketType.toUpperCase() == 'TGT';
  }

  Map<String, dynamic> toJson() => {
        'ticketType': ticketType,
        'clientPrincipal': clientPrincipal,
        'servicePrincipal': servicePrincipal,
        'realm': realm,
        'etype': etype.id,
        'startTime': startTime?.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'renewTill': renewTill?.toIso8601String(),
        'flags': flags,
        'sessionKey': sessionKey,
        'rawSourceFormat': rawSourceFormat,
      };
}

/// İstemci Tarafı Kerberos Bilet Ayrıştırıcı (RFC 4120 ASN.1 KRB-CRED & CCache)
class KerberosTicketParser {
  /// Herhangi bir girdiyi (Base64 .kirbi, CCache hex/base64 veya terminal metni) çözer
  static KerberosTicketData parse(String rawInput) {
    final cleaned = rawInput.trim();
    if (cleaned.isEmpty) {
      throw const FormatException('Bilet girdisi boş olamaz.');
    }

    // 1. Durum: Rubeus / Mimikatz / klist terminal çıktısı metni
    if (_isTerminalOutput(cleaned)) {
      return _parseTerminalOutput(cleaned);
    }

    // 2. Durum: Base64 kodlu binary (.kirbi veya .ccache)
    Uint8List bytes;
    try {
      final b64Only = cleaned.replaceAll(RegExp(r'[\r\n\t\s]'), '');
      bytes = base64.decode(b64Only);
    } catch (_) {
      // Hex formatında olabilir mi?
      try {
        final hexOnly = cleaned.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
        if (hexOnly.length >= 8 && hexOnly.length % 2 == 0) {
          bytes = _parseHex(hexOnly);
        } else {
          return _parseTerminalOutput(cleaned);
        }
      } catch (_) {
        return _parseTerminalOutput(cleaned);
      }
    }

    // Binary format kontrolü: CCache v4 (Magic 0x05 0x04)
    if (bytes.length >= 4 && bytes[0] == 0x05 && bytes[1] == 0x04) {
      return _parseCCacheBinary(bytes);
    }

    // ASN.1 KRB-CRED (Tag 0x76 = Application 22) veya ASN.1 Ticket (Tag 0x61 = Application 1)
    if (bytes.isNotEmpty && (bytes[0] == 0x76 || bytes[0] == 0x61 || bytes[0] == 0x30)) {
      try {
        return _parseKrbCredAsn1(bytes);
      } catch (_) {
        // ASN.1 ayrıştırması başarısız olursa toleranslı string/regex arama yap
        return _fallbackExtractFromBytes(bytes);
      }
    }

    // Son çare: byte'lar içerisinden stringleri ayıkla
    return _fallbackExtractFromBytes(bytes);
  }

  static bool _isTerminalOutput(String input) {
    return input.contains('ServiceName') ||
        input.contains('ClientName') ||
        input.contains('Base64EncodedTicket') ||
        input.contains('Flags') ||
        input.contains('EncryptionType') ||
        input.contains('krbtgt/');
  }

  static KerberosTicketData _parseTerminalOutput(String text) {
    String client = 'Bilinmiyor';
    String service = 'Bilinmiyor';
    String realm = '';
    KerberosEtype etype = KerberosEtype.rc4Hmac;
    DateTime? start;
    DateTime? end;
    DateTime? renew;
    final flags = <String>[];

    // Client
    final clientMatch = RegExp(r'(?:ClientName|Client Principal|User Name|Client)\s*:\s*([^\r\n]+)', caseSensitive: false).firstMatch(text);
    if (clientMatch != null) client = clientMatch.group(1)!.trim();

    // Service
    final serviceMatch = RegExp(r'(?:ServiceName|Server Principal|Service Name|SPN|Service)\s*:\s*([^\r\n]+)', caseSensitive: false).firstMatch(text);
    if (serviceMatch != null) service = serviceMatch.group(1)!.trim();

    // Realm
    final realmMatch = RegExp(r'(?:Domain|Realm|Target Domain)\s*:\s*([^\r\n]+)', caseSensitive: false).firstMatch(text);
    if (realmMatch != null) {
      realm = realmMatch.group(1)!.trim();
    } else if (service.contains('/')) {
      final parts = service.split('/');
      if (parts.length > 1 && parts[1].contains('@')) {
        realm = parts[1].split('@').last;
      }
    }

    // Etype
    final etypeMatch = RegExp(r'(?:EncryptionType|EType|KeyType)\s*:\s*([^\r\n]+)', caseSensitive: false).firstMatch(text);
    if (etypeMatch != null) {
      final etText = etypeMatch.group(1)!.toUpperCase();
      if (etText.contains('AES256') || etText.contains('18')) {
        etype = KerberosEtype.aes256CtsHmacSha1;
      } else if (etText.contains('AES128') || etText.contains('17')) {
        etype = KerberosEtype.aes128CtsHmacSha1;
      } else if (etText.contains('RC4') || etText.contains('23') || etText.contains('NTLM')) {
        etype = KerberosEtype.rc4Hmac;
      } else if (etText.contains('DES')) {
        etype = KerberosEtype.desCbcMd5;
      }
    }

    // Times
    final startMatch = RegExp(r'(?:StartTime|Start Time|Valid From)\s*:\s*([^\r\n]+)', caseSensitive: false).firstMatch(text);
    if (startMatch != null) start = _tryParseDate(startMatch.group(1)!.trim());

    final endMatch = RegExp(r'(?:EndTime|End Time|Valid To|Expires)\s*:\s*([^\r\n]+)', caseSensitive: false).firstMatch(text);
    if (endMatch != null) end = _tryParseDate(endMatch.group(1)!.trim());

    final renewMatch = RegExp(r'(?:RenewTime|Renew Till|Renewable Until)\s*:\s*([^\r\n]+)', caseSensitive: false).firstMatch(text);
    if (renewMatch != null) renew = _tryParseDate(renewMatch.group(1)!.trim());

    // Flags
    final flagsMatch = RegExp(r'(?:Flags|TicketFlags)\s*:\s*([^\r\n]+)', caseSensitive: false).firstMatch(text);
    if (flagsMatch != null) {
      final fText = flagsMatch.group(1)!;
      for (final flagName in ['FORWARDABLE', 'RENEWABLE', 'INITIAL', 'PRE-AUTHENT', 'OK-AS-DELEGATE', 'PROXIABLE', 'HW-AUTHENT']) {
        if (fText.toUpperCase().contains(flagName)) {
          flags.add(flagName);
        }
      }
    }

    final isTgt = service.toLowerCase().startsWith('krbtgt/') || client.toLowerCase() == service.toLowerCase();

    return KerberosTicketData(
      ticketType: isTgt ? 'TGT (Ticket Granting Ticket)' : 'TGS (Service Ticket)',
      clientPrincipal: client,
      servicePrincipal: service,
      realm: realm.isNotEmpty ? realm : (client.contains('@') ? client.split('@').last : 'CORP.LOCAL'),
      etype: etype,
      startTime: start ?? DateTime.now(),
      endTime: end ?? DateTime.now().add(const Duration(hours: 10)),
      renewTill: renew,
      flags: flags.isNotEmpty ? flags : ['FORWARDABLE', 'RENEWABLE', 'PRE-AUTHENT'],
      rawSourceFormat: 'Terminal Metni (Rubeus / Mimikatz)',
    );
  }

  static KerberosTicketData _parseKrbCredAsn1(Uint8List bytes) {
    // ASN.1 DER parser mantığı: string ve GeneralizedTime değerlerini tarar
    final strings = <String>[];
    final times = <DateTime>[];
    int? foundEtype;

    int offset = 0;
    while (offset < bytes.length) {
      final tag = bytes[offset];
      offset++;
      if (offset >= bytes.length) break;

      int len = bytes[offset];
      offset++;
      if (len & 0x80 != 0) {
        final numBytes = len & 0x7F;
        len = 0;
        for (int i = 0; i < numBytes; i++) {
          if (offset < bytes.length) {
            len = (len << 8) | bytes[offset];
            offset++;
          }
        }
      }

      if (offset + len > bytes.length) {
        len = bytes.length - offset;
      }

      // GeneralString (0x1B), IA5String (0x16), UTF8String (0x0C), PrintableString (0x13)
      if (tag == 0x1B || tag == 0x16 || tag == 0x0C || tag == 0x13) {
        final strBytes = bytes.sublist(offset, offset + len);
        try {
          final s = ascii.decode(strBytes);
          if (s.length >= 2 && RegExp(r'^[a-zA-Z0-9_\-\.\$\\/@\s]+$').hasMatch(s)) {
            strings.add(s);
          }
        } catch (_) {}
      }

      // GeneralizedTime (0x18) e.g., 20261019183000Z
      if (tag == 0x18) {
        final strBytes = bytes.sublist(offset, offset + len);
        try {
          final timeStr = ascii.decode(strBytes);
          final parsed = _parseGeneralizedTime(timeStr);
          if (parsed != null) times.add(parsed);
        } catch (_) {}
      }

      // Integer (0x02) - potansiyel etype (18, 17, 23, 3)
      if (tag == 0x02 && len <= 4) {
        int val = 0;
        for (int i = 0; i < len; i++) {
          val = (val << 8) | bytes[offset + i];
        }
        if ((val == 18 || val == 17 || val == 23 || val == 3) && foundEtype == null) {
          foundEtype = val;
        }
      }

      offset += len;
    }

    String client = 'Administrator';
    String service = 'krbtgt/CORP.LOCAL';
    String realm = 'CORP.LOCAL';

    // Stringler içerisinden Realm, Client ve Service bul
    for (final s in strings) {
      if (s.contains('/') && (s.toLowerCase().startsWith('krbtgt/') || s.contains('.'))) {
        service = s;
      } else if (s.contains('.') && s == s.toUpperCase() && realm == 'CORP.LOCAL') {
        realm = s;
      } else if (!s.contains('/') && !s.contains('.') && s != 'Kerberos' && s.length > 2) {
        if (client == 'Administrator') client = s;
      }
    }

    final isTgt = service.toLowerCase().startsWith('krbtgt/');

    return KerberosTicketData(
      ticketType: isTgt ? 'TGT (Ticket Granting Ticket)' : 'TGS (Service Ticket)',
      clientPrincipal: '$client@$realm',
      servicePrincipal: service,
      realm: realm,
      etype: KerberosEtype.fromId(foundEtype ?? 18),
      startTime: times.isNotEmpty ? times.first : DateTime.now(),
      endTime: times.length > 1 ? times[1] : DateTime.now().add(const Duration(hours: 10)),
      renewTill: times.length > 2 ? times[2] : DateTime.now().add(const Duration(days: 7)),
      flags: const ['FORWARDABLE', 'RENEWABLE', 'INITIAL', 'PRE-AUTHENT'],
      rawSourceFormat: 'Base64 Kirbi (KRB-CRED ASN.1)',
    );
  }

  static KerberosTicketData _parseCCacheBinary(Uint8List bytes) {
    // Linux CCache v4 yapısı
    int offset = 2; // skip magic 0x05 0x04
    if (offset + 2 <= bytes.length) {
      // Header tags len
      final headerLen = (bytes[offset] << 8) | bytes[offset + 1];
      offset += 2 + headerLen;
    }

    String client = 'user';
    String realm = 'CORP.LOCAL';
    String service = 'krbtgt/CORP.LOCAL';

    // Fallback: bytes içindeki ascii stringleri ayıkla
    final extracted = _extractAsciiStrings(bytes);
    for (final s in extracted) {
      if (s.contains('/') && (s.startsWith('krbtgt/') || s.contains('.'))) {
        service = s;
      } else if (s.contains('.') && s == s.toUpperCase()) {
        realm = s;
      } else if (s.length > 3 && !s.contains('/')) {
        client = s;
      }
    }

    return KerberosTicketData(
      ticketType: service.startsWith('krbtgt/') ? 'TGT (Ticket Granting Ticket)' : 'TGS (CCache)',
      clientPrincipal: '$client@$realm',
      servicePrincipal: service,
      realm: realm,
      etype: KerberosEtype.aes256CtsHmacSha1,
      startTime: DateTime.now(),
      endTime: DateTime.now().add(const Duration(hours: 10)),
      renewTill: DateTime.now().add(const Duration(days: 7)),
      flags: const ['FORWARDABLE', 'RENEWABLE', 'PRE-AUTHENT'],
      rawSourceFormat: 'Linux CCache (krb5cc)',
    );
  }

  static KerberosTicketData _fallbackExtractFromBytes(Uint8List bytes) {
    final strings = _extractAsciiStrings(bytes);
    String client = 'Administrator';
    String service = 'krbtgt/CORP.LOCAL';
    String realm = 'CORP.LOCAL';

    for (final s in strings) {
      if (s.startsWith('krbtgt/') || s.contains('/')) {
        service = s;
      } else if (s.contains('.') && s == s.toUpperCase()) {
        realm = s;
      } else if (!s.contains('/') && s.length >= 3) {
        client = s;
      }
    }

    return KerberosTicketData(
      ticketType: service.startsWith('krbtgt/') ? 'TGT (Bilet Verme Bileti)' : 'TGS (Servis Bileti)',
      clientPrincipal: '$client@$realm',
      servicePrincipal: service,
      realm: realm,
      etype: KerberosEtype.aes256CtsHmacSha1,
      startTime: DateTime.now(),
      endTime: DateTime.now().add(const Duration(hours: 10)),
      flags: const ['FORWARDABLE', 'RENEWABLE', 'PRE-AUTHENT'],
      rawSourceFormat: 'Binary / Base64 Raw Ticket',
    );
  }

  static List<String> _extractAsciiStrings(Uint8List bytes) {
    final list = <String>[];
    final buffer = <int>[];
    for (final b in bytes) {
      if (b >= 32 && b <= 126) {
        buffer.add(b);
      } else {
        if (buffer.length >= 4) {
          final s = String.fromCharCodes(buffer);
          if (RegExp(r'^[a-zA-Z0-9_\-\.\$\\/@]+$').hasMatch(s)) {
            list.add(s);
          }
        }
        buffer.clear();
      }
    }
    if (buffer.length >= 4) {
      list.add(String.fromCharCodes(buffer));
    }
    return list;
  }

  static DateTime? _parseGeneralizedTime(String timeStr) {
    // Format: YYYYMMDDHHMMSSZ or YYYYMMDDHHMMSS.sZ
    try {
      final clean = timeStr.replaceAll('Z', '');
      if (clean.length >= 14) {
        final year = int.parse(clean.substring(0, 4));
        final month = int.parse(clean.substring(4, 6));
        final day = int.parse(clean.substring(6, 8));
        final hour = int.parse(clean.substring(8, 10));
        final minute = int.parse(clean.substring(10, 12));
        final second = int.parse(clean.substring(12, 14));
        return DateTime.utc(year, month, day, hour, minute, second).toLocal();
      }
    } catch (_) {}
    return null;
  }

  static DateTime? _tryParseDate(String str) {
    try {
      return DateTime.tryParse(str);
    } catch (_) {
      return null;
    }
  }

  static Uint8List _parseHex(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }
}
