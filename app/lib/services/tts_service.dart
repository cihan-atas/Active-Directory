import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum TtsState { stopped, playing, paused }

enum TtsEngine {
  local('Yerel TTS (Çevrimdışı)', 'Cihaz motoru, tamamen ücretsiz ve sınırsız'),
  edgeNeural('ElevenLabs TTS (Ücretsiz Kota)', 'Aylık 10.000 karakter ücretsiz, kart istemez');

  final String label;
  final String description;
  const TtsEngine(this.label, this.description);
}

enum EdgeVoice {
  ahmet('Adam (Erkek)', 'pNInz6obpgDQGcFmaJgB'),
  emel('Sarah (Kadın)', 'EXAVITQu4vr4xnSDxMaL');

  final String label;
  final String shortName;
  const EdgeVoice(this.label, this.shortName);
}

enum TtsProfile {
  instructor(
    'Eğitmen (Net & Dengeli)',
    'Dengeli tonlama, laboratuvar dersleri ve genel anlatım için ideal',
    Icons.school_outlined,
    0.50,
    1.05,
  ),
  analyst(
    'SOC Analisti (Sakin & Tok)',
    'Derin ve oturaklı ses tonu, uzun teknik okumalar için yormaz',
    Icons.security_outlined,
    0.44,
    0.82,
  ),
  professor(
    'Akademisyen (Resmi & Akıcı)',
    'Açıklayıcı ve akademik telaffuz, kavramsal derinlik',
    Icons.menu_book_outlined,
    0.48,
    0.95,
  ),
  redTeam(
    'Kırmızı Takım / Hızlı (Tempolu)',
    'Hızlı tarama ve pratik operasyonel çalışma için yüksek tempo',
    Icons.bolt_outlined,
    0.65,
    1.10,
  ),
  custom(
    'Özel Ayar',
    'Kendi hız ve perde (ton) tercihleriniz',
    Icons.tune_outlined,
    0.50,
    1.00,
  );

  final String label;
  final String description;
  final IconData icon;
  final double defaultRate;
  final double defaultPitch;

  const TtsProfile(
    this.label,
    this.description,
    this.icon,
    this.defaultRate,
    this.defaultPitch,
  );
}

class TtsService extends ChangeNotifier {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  static const String _kRate = 'ad_tts_rate';
  static const String _kPitch = 'ad_tts_pitch';
  static const String _kProfile = 'ad_tts_profile';
  static const String _kEngine = 'ad_tts_engine';
  static const String _kEdgeVoice = 'ad_tts_edge_voice';
  static const String _kOpenAiKey = 'ad_tts_openai_key';

  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  SharedPreferences? _prefs;
  String? _openAiKey;

  TtsState _state = TtsState.stopped;
  TtsProfile _profile = TtsProfile.instructor;
  TtsEngine _engine = TtsEngine.local;
  EdgeVoice _edgeVoice = EdgeVoice.ahmet;
  String? _lastEdgeError;
  String? _currentId;
  String? _currentTitle;
  String? _currentSubtitle;
  double _speechRate = 0.50; // 0.5 = 1.0x normal hız
  double _pitch = 1.05;
  List<String> _chunks = [];
  int _chunkIndex = 0;
  int _currentChunkOffset = 0;
  int _chunkBaseOffset = 0;
  bool _userStopped = false;
  bool _isHotRestarting = false;
  bool _isInitialized = false;

  TtsState get state => _state;
  TtsProfile get profile => _profile;
  TtsEngine get engine => _engine;
  EdgeVoice get edgeVoice => _edgeVoice;
  String? get lastEdgeError => _lastEdgeError;
  bool get hasOpenAiKey => _openAiKey != null && _openAiKey!.trim().isNotEmpty;
  bool get isPlaying => _state == TtsState.playing;
  bool get isPaused => _state == TtsState.paused;
  bool get isStopped => _state == TtsState.stopped;

  String? get currentId => _currentId;
  String? get currentTitle => _currentTitle;
  String? get currentSubtitle => _currentSubtitle;
  double get speechRate => _speechRate;
  double get pitch => _pitch;
  double get speedMultiplier => _speechRate * 2.0;
  int get currentChunkIndex => _chunkIndex;
  int get totalChunks => _chunks.length;

  Future<void> init() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();

    final profName = _prefs?.getString(_kProfile) ?? 'instructor';
    _profile = TtsProfile.values.firstWhere(
      (p) => p.name == profName,
      orElse: () => TtsProfile.instructor,
    );

    final engName = _prefs?.getString(_kEngine) ?? 'local';
    _engine = TtsEngine.values.firstWhere(
      (e) => e.name == engName,
      orElse: () => TtsEngine.local,
    );

    final voiceName = _prefs?.getString(_kEdgeVoice) ?? 'ahmet';
    _edgeVoice = EdgeVoice.values.firstWhere(
      (v) => v.name == voiceName,
      orElse: () => EdgeVoice.ahmet,
    );

    try {
      _openAiKey = await _secureStorage.read(key: _kOpenAiKey);
    } catch (_) {}

    _speechRate = _prefs?.getDouble(_kRate) ?? _profile.defaultRate;
    _pitch = _prefs?.getDouble(_kPitch) ?? _profile.defaultPitch;

    try {
      await _tts.setLanguage('tr-TR');
      await _tts.setSpeechRate(_speechRate);
      await _tts.setPitch(_pitch);
      await _tts.setVolume(1.0);
    } catch (_) {}

    try {
      // Okunan kelimenin ofsetini dinamik olarak takip et
      _tts.setProgressHandler((String text, int start, int end, String word) {
        _currentChunkOffset = _chunkBaseOffset + start;
      });

      _tts.setStartHandler(() {
        _state = TtsState.playing;
        notifyListeners();
      });

      _tts.setCompletionHandler(() async {
        if (_isHotRestarting) return;
        if (_state == TtsState.playing && !_userStopped) {
          if (_chunkIndex + 1 < _chunks.length) {
            _chunkIndex++;
            _currentChunkOffset = 0;
            _chunkBaseOffset = 0;
            notifyListeners();
            await _speakCurrentChunk();
            return;
          }
        }
        _state = TtsState.stopped;
        _currentId = null;
        _currentTitle = null;
        _currentSubtitle = null;
        _chunks.clear();
        _chunkIndex = 0;
        _currentChunkOffset = 0;
        _chunkBaseOffset = 0;
        notifyListeners();
      });

      _tts.setCancelHandler(() {
        if (_userStopped && !_isHotRestarting) {
          _state = TtsState.stopped;
          notifyListeners();
        }
      });

      _tts.setPauseHandler(() {
        _state = TtsState.paused;
        notifyListeners();
      });

      _tts.setContinueHandler(() {
        _state = TtsState.playing;
        notifyListeners();
      });

      _tts.setErrorHandler((dynamic msg) {
        if (!_isHotRestarting) {
          _state = TtsState.stopped;
          notifyListeners();
        }
      });
    } catch (_) {}

    _audioPlayer.onPlayerComplete.listen((_) async {
      if (_isHotRestarting || _userStopped) return;
      if (_state == TtsState.playing) {
        if (_chunkIndex + 1 < _chunks.length) {
          _chunkIndex++;
          _currentChunkOffset = 0;
          _chunkBaseOffset = 0;
          notifyListeners();
          await _speakCurrentChunk();
          return;
        }
        _state = TtsState.stopped;
        _currentId = null;
        _currentTitle = null;
        _currentSubtitle = null;
        _chunks.clear();
        _chunkIndex = 0;
        notifyListeners();
      }
    });

    _isInitialized = true;
  }

  /// Uzun metinleri Android/Web TTS motorlarının karakter sınırına takılmaması için akıllı parçalar
  static List<String> splitIntoSpeechChunks(String text, {int maxChunkLength = 1000}) {
    if (text.length <= maxChunkLength) return [text];

    final paragraphs = text.split('\n\n');
    final chunks = <String>[];
    final current = StringBuffer();

    for (final p in paragraphs) {
      final trimmed = p.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.length > maxChunkLength) {
        if (current.isNotEmpty) {
          chunks.add(current.toString().trim());
          current.clear();
        }
        final sentences = trimmed.split(RegExp(r'(?<=[.?!])\s+'));
        for (final s in sentences) {
          if (current.length + s.length + 1 > maxChunkLength) {
            if (current.isNotEmpty) {
              chunks.add(current.toString().trim());
              current.clear();
            }
          }
          if (s.length > maxChunkLength) {
            final words = s.split(' ');
            for (final w in words) {
              if (current.length + w.length + 1 > maxChunkLength) {
                if (current.isNotEmpty) {
                  chunks.add(current.toString().trim());
                  current.clear();
                }
              }
              if (current.isNotEmpty) current.write(' ');
              current.write(w);
            }
          } else {
            if (current.isNotEmpty) current.write(' ');
            current.write(s);
          }
        }
      } else {
        if (current.length + trimmed.length + 2 > maxChunkLength) {
          chunks.add(current.toString().trim());
          current.clear();
        }
        if (current.isNotEmpty) current.write('\n\n');
        current.write(trimmed);
      }
    }

    if (current.isNotEmpty) {
      chunks.add(current.toString().trim());
    }

    return chunks.where((c) => c.isNotEmpty).toList();
  }

  /// Markdown ve teknik dokümantasyon etiketlerini pürüzsüz seslendirme için temizler
  static String cleanMarkdown(String raw) {
    var text = raw;

    // Admonition / Bilgi kutuları (> [!NOTE], > [!TIP] vb.)
    text = text.replaceAllMapped(
      RegExp(r'^\s*>\s*\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\s*(.*)', multiLine: true, caseSensitive: false),
      (m) {
        final type = m.group(1)?.toUpperCase();
        final content = m.group(2) ?? '';
        final label = switch (type) {
          'NOTE' => 'Not: ',
          'TIP' => 'İpucu: ',
          'IMPORTANT' => 'Önemli: ',
          'WARNING' => 'Uyarı: ',
          'CAUTION' => 'Dikkat: ',
          _ => '',
        };
        return '\n$label$content\n';
      },
    );

    // Kod bloklarını atla veya sesli olarak belirt
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), ' Kod bloğu atlandı. ');
    // Satır içi kodları temizle `kod` -> kod
    text = text.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m.group(1) ?? '');
    // Başlık işaretlerini kaldır (# Başlık -> Başlık)
    text = text.replaceAll(RegExp(r'^#+\s*', multiLine: true), '');
    // Görselleri kaldır ![alt](url)
    text = text.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]+\)'), '');
    // Markdown linklerini sadece metne çevir [metin](link) -> metin
    text = text.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), (m) => m.group(1) ?? '');
    // Kalın ve italik işaretlerini kaldır (*bold*, **bold**, _italic_)
    text = text.replaceAll(RegExp(r'[*_]{1,3}'), '');
    // Kalan alıntı işaretlerini kaldır (>)
    text = text.replaceAll(RegExp(r'^\s*>\s*', multiLine: true), '');
    // HTML etiketlerini temizle
    text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
    // Yatay çizgileri kaldır
    text = text.replaceAll(RegExp(r'^\s*[-*_]{3,}\s*$', multiLine: true), '');

    // Ses motorunun harf harf okumaması için sembol ve emojileri temizle
    text = text.replaceAll(RegExp(r'[→←↗↳✓❌⚠️·⚡📋🛡️🔴🏗️🎯🏆🎧🧠🔍┌┐└┘├┤┬┴┼─│═║╔╗╚╝╠╣╦╩╬]'), ' ');

    // Tablo satırlarını virgülle ayrılmış akıcı cümleye dönüştür
    final lines = text.split('\n');
    final cleanedLines = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        if (RegExp(r'^\|[\s\-:|]+\|$').hasMatch(trimmed)) continue;
        final cells = trimmed.split('|').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
        if (cells.isNotEmpty) {
          cleanedLines.add(cells.join(', '));
        }
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        cleanedLines.add(trimmed.substring(2));
      } else {
        cleanedLines.add(line);
      }
    }
    text = cleanedLines.join('\n');

    text = text.replaceAll('&nbsp;', ' ').replaceAll('&amp;', '&');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    text = text.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    return applyPhoneticDictionary(text.trim());
  }

  /// Active Directory ve siber güvenlik terimlerini Türkçe TTS motorunun doğru telaffuz etmesi için dönüştürür
  static String applyPhoneticDictionary(String text) {
    const Map<String, String> phoneticMap = {
      'KRBTGT': 'kerbe te ge te',
      'DCSync': 'di si sink',
      'DCShadow': 'di si şedov',
      'LSASS': 'el sas',
      'NTLM': 'en ti el em',
      'sAMAccountName': 'sem ekant neym',
      'userPrincipalName': 'yuzır prinsıpıl neym',
      'BloodHound': 'blad haund',
      'SharpHound': 'şarp haund',
      'Mimikatz': 'mimikats',
      'Rubeus': 'rubiyus',
      'Impacket': 'impekıt',
      'Certipy': 'sörtipay',
      'Certify': 'sörtifay',
      'Kerberoasting': 'kerberosting',
      'AS-REP': 'ey es rep',
      'AS-REQ': 'ey es rek',
      'TGS-REQ': 'ti ci es rek',
      'TGS-REP': 'ti ci es rep',
      'SYSVOL': 'sisvol',
      'NTDS': 'en ti di es',
      'RBCD': 'ar bi si di',
      'AD CS': 'ey di si es',
      'AD FS': 'ey di ef es',
      'LAPS': 'leps',
      'SIEM': 'siyem',
      'SOAR': 'soar',
      'SOC': 'sok',
      'EDR': 'i di ar',
      'XDR': 'iks di ar',
      'MITRE ATT&CK': 'maytır etek',
      'SPN': 'es pi en',
      'TGT': 'ti ci ti',
      'TGS': 'ti ci es',
      'GPO': 'ci pi o',
      'FSMO': 'ef es em o',
      'RODC': 'ar o di si',
      'DPAPI': 'di pi ey pi ay',
      'PetitPotam': 'pöti potam',
      'PrinterBug': 'printır bag',
      'Pass-the-Hash': 'pes dı heş',
      'Pass-the-Ticket': 'pes dı tikıt',
      'Overpass-the-Hash': 'ovırpes dı heş',
      'Golden Ticket': 'goldın tikıt',
      'Silver Ticket': 'silvır tikıt',
      'Shadow Credentials': 'şedov kıredenşıls',
      'Active Directory': 'ektiv dayrektori',
      'Domain Controller': 'domeyn kontrolır',
      'PowerShell': 'pavırşel',
      'PowerView': 'pavırviyv',
      // Protokoller & Ağ
      'LDAP': 'el dap',
      'LDAPS': 'el daps',
      'SMB': 'es em bi',
      'RPC': 'ar pi si',
      'WMI': 'dabıl yu em ay',
      'WinRM': 'vin ar em',
      'DCOM': 'di kom',
      'DRSUAPI': 'di ar es yu ey pi ay',
      'SAMR': 'sem ar',
      'LSARPC': 'el es ey ar pi si',
      'PKINIT': 'pi key init',
      'S4U2Self': 'es for yu tu self',
      'S4U2Proxy': 'es for yu tu proksi',
      'LLMNR': 'el el em en ar',
      'NBT-NS': 'en bi ti en es',
      'mDNS': 'em di en es',
      'WPAD': 'dabıl yu ped',
      'WebDAV': 'veb dav',
      'DNSSEC': 'di en es sek',
      'FQDN': 'ef ku di en',
      'NetBIOS': 'net bayos',
      'Kerberos': 'kerberos',
      'KDC': 'key di si',
      'PAC': 'pek',
      'KrbRelayUp': 'kerb riley ap',
      'DFSCoerce': 'di ef es koörs',
      // Nesne, Yetki & Mimari
      'ACL': 'ey si el',
      'DACL': 'di ey si el',
      'SACL': 'es ey si el',
      'ACE': 'ey si i',
      'SID': 'es ay di',
      'RID': 'ar ay di',
      'GUID': 'gi yu ay di',
      'UPN': 'yu pi en',
      'OU': 'o yu',
      'gMSA': 'ci em es ey',
      'AdminSDHolder': 'edmin es di holdır',
      'AGDLP': 'ey ci di el pi',
      'FGPP': 'ef ci pi pi',
      'USN': 'yu es en',
      'KCC': 'key si si',
      'ISTG': 'ay es ti ci',
      'PDC': 'pi di si',
      'GPMC': 'ci pi em si',
      'RSOP': 'ar es o pi',
      'DFS-R': 'di ef es ar',
      'DFS-N': 'di ef es en',
      'FSRM': 'ef es ar em',
      'CA': 'si ey',
      'CRL': 'si ar el',
      'OCSP': 'o si es pi',
      'EKU': 'i key yu',
      'SAN': 'es ey en',
      'ESC1': 'i es si bir',
      'ESC2': 'i es si iki',
      'ESC3': 'i es si üç',
      'ESC4': 'i es si dört',
      'ESC5': 'i es si beş',
      'ESC6': 'i es si altı',
      'ESC7': 'i es si yedi',
      'ESC8': 'i es si sekiz',
      // Araçlar & Savunma
      'NetExec': 'net ekzek',
      'CrackMapExec': 'krek mep ekzek',
      'Evil-WinRM': 'ivıl vin ar em',
      'PsExec': 'pi es ekzek',
      'Responder': 'rispondır',
      'mitm6': 'mitm altı',
      'ntlmrelayx': 'en ti el em riley iks',
      'secretsdump': 'sikrıts damp',
      'Seatbelt': 'sitbelt',
      'SharpDPAPI': 'şarp di pi ey pi ay',
      'PingCastle': 'ping kesıl',
      'Purple Knight': 'pörpıl nayt',
      'Sysmon': 'sismon',
      'WEF': 'dabıl yu i ef',
      'KQL': 'key ku el',
      'Sigma': 'sigma',
      'Hashcat': 'heşket',
      'Cobalt Strike': 'kobalt strayk',
      'Sliver': 'slayvır',
      'Ligolo': 'ligolo',
      'Chisel': 'çizıl',
      'OPSEC': 'opsek',
      'IOC': 'ay o si',
      'DFIR': 'di ef ay ar',
      'CVE': 'si vi i',
      'SSO': 'es es o',
      'MFA': 'em ef ey',
      'Entra ID': 'entra ay di',
      'Diamond Ticket': 'daymınd tikıt',
      'Sapphire Ticket': 'sefayr tikıt',
      // Tarama sonucu yüksek frekanslı genel teknik terimler
      'Windows': 'vindovs',
      'Domain': 'domeyn',
      'Event': 'ivent',
      'Microsoft': 'maykrosoft',
      'SYSTEM': 'sistım',
      'Administrator': 'edministreytır',
      'Linux': 'linuks',
      'Security': 'seküriti',
      'TCP': 'ti si pi',
      'DNS': 'di en es',
      'Server': 'sörvır',
      'Ticket': 'tikıt',
      'ccache': 'si keş',
      'HTTP': 'eyç ti ti pi',
      'Controller': 'kontrolır',
      'Users': 'yuzırs',
      'Admins': 'edmins',
      'Access': 'ekses',
      'relay': 'riley',
      'Service': 'sörvis',
      'Admin': 'edmin',
      'API': 'ey pi ay',
      'Python': 'paytın',
      'Golden': 'goldın',
      'Hash': 'heş',
      'exe': 'ekze',
      'cmd': 'si em di',
      'bash': 'beş',
      'README': 'ridmi',
      'Blue': 'blu',
      'Red': 'red',
    };

    var result = text;
    phoneticMap.forEach((term, pronunciation) {
      result = result.replaceAll(
        RegExp('\\b${RegExp.escape(term)}\\b', caseSensitive: false),
        pronunciation,
      );
    });

    // Sözlükte olmayan camelCase / PascalCase / alt çizgili teknik terimleri kelimelerine ayır
    // Örn: servicePrincipalName -> service Principal Name, msDS_AllowedToDelegateTo -> ms DS Allowed To Delegate To
    result = result.replaceAll('_', ' ');
    result = result.replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (m) => '${m.group(1)} ${m.group(2)}',
    );
    return result;
  }

  Future<void> _speakCurrentChunk() async {
    if (_chunkIndex >= _chunks.length) {
      _state = TtsState.stopped;
      notifyListeners();
      return;
    }

    try {
      final chunk = _chunks[_chunkIndex];
      _chunkBaseOffset = 0;
      _currentChunkOffset = 0;

      if (_engine == TtsEngine.edgeNeural) {
        _lastEdgeError = null;
        final audioBytes = await _fetchEdgeTtsAudio(chunk);
        if (audioBytes != null && audioBytes.isNotEmpty) {
          _state = TtsState.playing;
          notifyListeners();
          await _audioPlayer.play(BytesSource(audioBytes));
          return;
        }
        _lastEdgeError ??= 'Edge TTS ses verisi alınamadı (yerel TTS kullanılıyor).';
        notifyListeners();
      }

      await _tts.speak(chunk);
    } catch (_) {
      // Edge TTS veya ağ hatası durumunda otomatik yerel TTS'e düş
      try {
        await _tts.speak(_chunks[_chunkIndex]);
      } catch (_) {
        _state = TtsState.stopped;
        notifyListeners();
      }
    }
  }

  Future<void> setEngine(TtsEngine newEngine) async {
    if (_engine == newEngine) return;
    _engine = newEngine;
    await _prefs?.setString(_kEngine, newEngine.name);
    notifyListeners();
    if (_state == TtsState.playing && _chunks.isNotEmpty) {
      _isHotRestarting = true;
      await _tts.stop();
      await _audioPlayer.stop();
      _isHotRestarting = false;
      await _speakCurrentChunk();
    }
  }

  Future<void> setEdgeVoice(EdgeVoice voice) async {
    if (_edgeVoice == voice) return;
    _edgeVoice = voice;
    await _prefs?.setString(_kEdgeVoice, voice.name);
    notifyListeners();
    if (_state == TtsState.playing && _engine == TtsEngine.edgeNeural && _chunks.isNotEmpty) {
      _isHotRestarting = true;
      await _audioPlayer.stop();
      _isHotRestarting = false;
      await _speakCurrentChunk();
    }
  }

  Future<void> setOpenAiKey(String? key) async {
    final trimmed = key?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      _openAiKey = null;
      await _secureStorage.delete(key: _kOpenAiKey);
    } else {
      _openAiKey = trimmed;
      await _secureStorage.write(key: _kOpenAiKey, value: trimmed);
    }
    _lastEdgeError = null;
    notifyListeners();
  }

  /// ElevenLabs (eleven_multilingual_v2) üzerinden ücretsiz kotalı Türkçe MP3 ses akışı alır
  Future<Uint8List?> _fetchEdgeTtsAudio(String text) async {
    if (!hasOpenAiKey) {
      _lastEdgeError = 'ElevenLabs API Key tanımlı değil. Aşağıdan anahtar ekleyin.';
      return null;
    }
    try {
      final resp = await http
          .post(
            Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/${_edgeVoice.shortName}'),
            headers: {
              'xi-api-key': _openAiKey!,
              'Content-Type': 'application/json',
              'Accept': 'audio/mpeg',
            },
            body: jsonEncode({
              'text': text,
              'model_id': 'eleven_multilingual_v2',
              'voice_settings': {
                'stability': 0.5,
                'similarity_boost': 0.75,
              },
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        return resp.bodyBytes;
      }
      _lastEdgeError = 'ElevenLabs HTTP ${resp.statusCode} hatası';
      return null;
    } catch (e) {
      _lastEdgeError = 'ElevenLabs hatası: $e';
      return null;
    }
  }

  /// Oynatma sırasında hız veya profil değiştirildiğinde, durdurup başlatmaya gerek kalmadan
  /// anında ve kesintisiz olarak yeni hızla okumaya devam eden sıcak yeniden başlatıcı (Hot Restart)
  Future<void> _restartPlaybackWithNewSettings() async {
    if (!isPlaying || _chunks.isEmpty || _chunkIndex >= _chunks.length) return;
    if (_engine == TtsEngine.edgeNeural) {
      try {
        await _audioPlayer.setPlaybackRate(speedMultiplier.clamp(0.5, 2.5));
      } catch (_) {}
      return;
    }
    try {
      final fullChunk = _chunks[_chunkIndex];
      int offset = _currentChunkOffset;
      if (offset < 0 || offset >= fullChunk.length) {
        offset = 0;
      }

      // Kalan metni mevcut kelimeden itibaren al
      final remaining = fullChunk.substring(offset).trim();
      _chunkBaseOffset = offset;

      _isHotRestarting = true;
      await _tts.stop();
      _state = TtsState.playing;
      _isHotRestarting = false;

      if (remaining.isNotEmpty) {
        await _tts.speak(remaining);
      } else if (_chunkIndex + 1 < _chunks.length) {
        _chunkIndex++;
        _currentChunkOffset = 0;
        _chunkBaseOffset = 0;
        await _speakCurrentChunk();
      }
    } catch (_) {
      _isHotRestarting = false;
    }
  }

  /// Tüm metni baştan sona oku
  Future<void> speak(
    String markdownOrPlain, {
    String? id,
    String? title,
    String? subtitle,
  }) async {
    await init();
    final cleaned = cleanMarkdown(markdownOrPlain);
    if (cleaned.isEmpty) return;

    _userStopped = false;
    _currentId = id;
    _currentTitle = title;
    _currentSubtitle = subtitle;
    _chunks = splitIntoSpeechChunks(cleaned);
    _chunkIndex = 0;
    _currentChunkOffset = 0;
    _chunkBaseOffset = 0;

    try {
      await _tts.setSpeechRate(_speechRate);
      await _tts.setPitch(_pitch);
      _state = TtsState.playing;
      notifyListeners();
      await _speakCurrentChunk();
    } catch (_) {
      _state = TtsState.stopped;
      notifyListeners();
    }
  }

  /// "Buradan İtibaren Oku" (Bölümden itibaren okuma)
  Future<void> speakFrom(
    String fullMarkdown,
    String fromSectionText, {
    String? id,
    String? title,
    String? sectionTitle,
  }) async {
    final idx = fullMarkdown.indexOf(fromSectionText);
    final remainingText = (idx != -1) ? fullMarkdown.substring(idx) : fromSectionText;

    await speak(
      remainingText,
      id: id,
      title: title,
      subtitle: sectionTitle != null ? 'Bölüm: $sectionTitle' : 'Bölümden itibaren',
    );
  }

  /// Seçili metinden itibaren dokümanın sonuna kadar oku
  Future<void> speakRemainingFromSnippet(
    String fullMarkdown,
    String snippet, {
    String? id,
    String? title,
  }) async {
    final idx = fullMarkdown.indexOf(snippet);
    final remaining = (idx != -1) ? fullMarkdown.substring(idx) : snippet;
    await speak(
      remaining,
      id: id,
      title: title,
      subtitle: 'Seçimden itibaren',
    );
  }

  /// Sadece seçili metin parçasını oku
  Future<void> speakSnippet(
    String snippet, {
    String? id,
    String? title,
  }) async {
    await speak(
      snippet,
      id: id,
      title: title,
      subtitle: 'Seçili metin',
    );
  }

  /// Parçalar arasında doğrudan atlama (seek)
  Future<void> seekToChunk(int index) async {
    if (_chunks.isEmpty || index < 0 || index >= _chunks.length) return;
    _chunkIndex = index;
    _currentChunkOffset = 0;
    _chunkBaseOffset = 0;
    _state = TtsState.playing;
    notifyListeners();
    try {
      _isHotRestarting = true;
      await _tts.stop();
      _isHotRestarting = false;
      await _speakCurrentChunk();
    } catch (_) {
      _isHotRestarting = false;
    }
  }

  /// Sonraki parçaya atla
  Future<void> nextChunk() async {
    if (_chunkIndex + 1 < _chunks.length) {
      await seekToChunk(_chunkIndex + 1);
    }
  }

  /// Önceki parçaya atla
  Future<void> previousChunk() async {
    if (_chunkIndex > 0) {
      await seekToChunk(_chunkIndex - 1);
    }
  }

  Future<void> pause() async {
    if (!isPlaying) return;
    try {
      if (_engine == TtsEngine.edgeNeural) {
        await _audioPlayer.pause();
      } else {
        await _tts.pause();
      }
      _state = TtsState.paused;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> resume() async {
    if (!isPaused || _chunks.isEmpty) return;
    try {
      _state = TtsState.playing;
      notifyListeners();
      if (_engine == TtsEngine.edgeNeural) {
        await _audioPlayer.resume();
      } else {
        await _speakCurrentChunk();
      }
    } catch (_) {}
  }

  Future<void> stop() async {
    _userStopped = true;
    _chunks.clear();
    _chunkIndex = 0;
    _currentChunkOffset = 0;
    _chunkBaseOffset = 0;
    try {
      await _tts.stop();
      await _audioPlayer.stop();
    } catch (_) {}
    _state = TtsState.stopped;
    _currentId = null;
    _currentTitle = null;
    _currentSubtitle = null;
    notifyListeners();
  }

  /// Hızlı tek tıkla döngüsel hız değiştirme (0.75x -> 1.0x -> 1.25x -> 1.5x -> 1.75x -> 2.0x -> 0.75x)
  Future<void> cycleSpeed() async {
    const speeds = [0.375, 0.50, 0.625, 0.75, 0.875, 1.00];
    int nextIdx = 0;
    for (int i = 0; i < speeds.length; i++) {
      if ((_speechRate - speeds[i]).abs() < 0.04) {
        nextIdx = (i + 1) % speeds.length;
        break;
      }
    }
    await setSpeechRate(speeds[nextIdx]);
  }

  /// Çarpan cinsinden hız ayarlama (Örn: 1.0 = normal, 1.5 = 1.5x)
  Future<void> setSpeedMultiplier(double mult) async {
    await setSpeechRate(mult / 2.0);
  }

  /// Okuma hızını ayarla (Flutter TTS motorunda 0.25 - 1.0 arası)
  /// Oynatma sırasındaysa kesintiye uğramadan anında yeni hıza geçer
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.20, 1.00);
    await _prefs?.setDouble(_kRate, _speechRate);
    try {
      await _tts.setSpeechRate(_speechRate);
      if (isPlaying) {
        await _restartPlaybackWithNewSettings();
      }
    } catch (_) {}
    notifyListeners();
  }

  /// Geriye dönük uyumluluk için alias
  Future<void> setRate(double rate) => setSpeechRate(rate);

  /// Ses tonunu (Pitch) ayarla (0.5 - 1.5 arası)
  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.50, 1.50);
    await _prefs?.setDouble(_kPitch, _pitch);
    try {
      await _tts.setPitch(_pitch);
      if (isPlaying) {
        await _restartPlaybackWithNewSettings();
      }
    } catch (_) {}
    notifyListeners();
  }

  /// Ses profili seçimi (Eğitmen, SOC Analisti, Akademisyen, Kırmızı Takım, Özel)
  Future<void> setProfile(TtsProfile prof) async {
    _profile = prof;
    await _prefs?.setString(_kProfile, prof.name);

    if (prof != TtsProfile.custom) {
      _speechRate = prof.defaultRate;
      _pitch = prof.defaultPitch;
      await _prefs?.setDouble(_kRate, _speechRate);
      await _prefs?.setDouble(_kPitch, _pitch);
      try {
        await _tts.setSpeechRate(_speechRate);
        await _tts.setPitch(_pitch);
        if (isPlaying) {
          await _restartPlaybackWithNewSettings();
        }
      } catch (_) {}
    }
    notifyListeners();
  }
}
