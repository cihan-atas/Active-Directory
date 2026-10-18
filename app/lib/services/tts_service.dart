import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TtsState { stopped, playing, paused }

enum TtsProfile {
  instructor('Eğitmen (Net & Dengeli)', 0.50, 1.05),
  analyst('SOC Analisti (Sakin & Tok)', 0.44, 0.85),
  redTeam('Hızlı Okuyucu (Tempolu)', 0.62, 1.10),
  custom('Özel Ayar', 0.50, 1.00);

  final String label;
  final double defaultRate;
  final double defaultPitch;

  const TtsProfile(this.label, this.defaultRate, this.defaultPitch);
}

class TtsService extends ChangeNotifier {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _tts = FlutterTts();
  SharedPreferences? _prefs;

  TtsState _state = TtsState.stopped;
  TtsProfile _profile = TtsProfile.instructor;
  String? _currentId;
  String? _currentTitle;
  String? _currentSubtitle;
  double _speechRate = 0.5;
  double _pitch = 1.0;
  List<String> _chunks = [];
  int _chunkIndex = 0;
  bool _userStopped = false;
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
  int get currentChunkIndex => _chunkIndex;
  int get totalChunks => _chunks.length;

  Future<void> init() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();

    final savedRate = _prefs?.getDouble('ad_tts_rate');
    _speechRate = savedRate ?? _profile.defaultRate;
    _pitch = _prefs?.getDouble('ad_tts_pitch') ?? _profile.defaultPitch;

    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('tr-TR');
      await _tts.setSpeechRate(_speechRate);
      await _tts.setPitch(_pitch);
      await _tts.setVolume(1.0);
    } catch (_) {}

    _tts.setStartHandler(() {
      _state = TtsState.playing;
      notifyListeners();
    });

    _tts.setCompletionHandler(() async {
      if (_state == TtsState.playing && !_userStopped) {
        if (_chunkIndex + 1 < _chunks.length) {
          _chunkIndex++;
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
      notifyListeners();
    });

    _tts.setCancelHandler(() {
      if (_userStopped) {
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
      _state = TtsState.stopped;
      notifyListeners();
    });

    _isInitialized = true;
  }

  /// Uzun metinleri Android TTS motorunun karakter sınırına takılmaması için parçalar
  static List<String> splitIntoSpeechChunks(String text, {int maxChunkLength = 900}) {
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
          if (current.isNotEmpty) current.write(' ');
          current.write(s);
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

  /// Markdown etiketlerini pürüzsüz seslendirme için temizler
  static String cleanMarkdown(String raw) {
    var text = raw;

    // Kod bloklarını atla veya sadeleştir
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), ' Kod bloğu atlandı. ');
    // Satır içi kodları temizle `kod` -> kod
    text = text.replaceAll(RegExp(r'`([^`]+)`'), r'$1');
    // Başlık işaretlerini kaldır (# Başlık -> Başlık)
    text = text.replaceAll(RegExp(r'^#+\s*', multiLine: true), '');
    // Markdown linklerini sadece metne çevir [metin](link) -> metin
    text = text.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), (m) => m.group(1) ?? '');
    // Kalın ve italik işaretlerini kaldır (*bold*, **bold**, _italic_)
    text = text.replaceAll(RegExp(r'[*_]{1,3}'), '');
    // Alıntı işaretlerini kaldır (>)
    text = text.replaceAll(RegExp(r'^\s*>\s*', multiLine: true), '');
    // Sembolleri temizle
    text = text.replaceAll(RegExp(r'[→←↗↳✓❌⚠️·⚡📋]'), ' ');

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

    // Fazla boşlukları temizle
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
      await _tts.speak(chunk);
    } catch (_) {
      _state = TtsState.stopped;
      notifyListeners();
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

  /// "Buradan İtibaren Oku" (Long-press desteği)
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
      subtitle: sectionTitle != null ? 'Buradan itibaren: $sectionTitle' : 'Buradan itibaren',
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
    try {
      await _tts.stop();
    } catch (_) {}
    _state = TtsState.stopped;
    _currentId = null;
    _currentTitle = null;
    _currentSubtitle = null;
    notifyListeners();
  }

  Future<void> setRate(double rate) async {
    _speechRate = rate;
    await _prefs?.setDouble('ad_tts_rate', rate);
    await _tts.setSpeechRate(rate);
    notifyListeners();
  }

  Future<void> setProfile(TtsProfile prof) async {
    _profile = prof;
    _speechRate = prof.defaultRate;
    _pitch = prof.defaultPitch;
    await _prefs?.setDouble('ad_tts_rate', _speechRate);
    await _prefs?.setDouble('ad_tts_pitch', _pitch);
    await _tts.setSpeechRate(_speechRate);
    await _tts.setPitch(_pitch);
    notifyListeners();
  }
}
