import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TtsState { stopped, playing, paused }

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

  final FlutterTts _tts = FlutterTts();
  SharedPreferences? _prefs;

  TtsState _state = TtsState.stopped;
  TtsProfile _profile = TtsProfile.instructor;
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
    text = text.replaceAll(RegExp(r'[→←↗↳✓❌⚠️·⚡📋🛡️🔴🏗️🎯🏆🎧🧠🔍]'), ' ');

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
    return text.trim();
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
      await _tts.speak(chunk);
    } catch (_) {
      _state = TtsState.stopped;
      notifyListeners();
    }
  }

  /// Oynatma sırasında hız veya profil değiştirildiğinde, durdurup başlatmaya gerek kalmadan
  /// anında ve kesintisiz olarak yeni hızla okumaya devam eden sıcak yeniden başlatıcı (Hot Restart)
  Future<void> _restartPlaybackWithNewSettings() async {
    if (!isPlaying || _chunks.isEmpty || _chunkIndex >= _chunks.length) return;
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
      await _tts.pause();
      _state = TtsState.paused;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> resume() async {
    if (!isPaused || _chunks.isEmpty) return;
    try {
      _state = TtsState.playing;
      notifyListeners();
      await _speakCurrentChunk();
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
