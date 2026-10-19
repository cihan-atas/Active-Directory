import 'package:flutter/material.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';

class TtsPlayerBar extends StatelessWidget {
  const TtsPlayerBar({super.key});

  void _showMediaSheet(BuildContext context, TtsService tts) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _TtsMediaSheet(tts: tts),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tts = TtsService();

    return ListenableBuilder(
      listenable: tts,
      builder: (context, _) {
        if (tts.isStopped) return const SizedBox.shrink();

        final speedText = '${tts.speedMultiplier.toStringAsFixed(1)}x';

        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF131A29),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.blueTeam.withAlpha(150), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(160),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Ses İkonu
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.blueTeam.withAlpha(35),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    tts.isPlaying ? Icons.volume_up : Icons.volume_mute,
                    size: 20,
                    color: AppTheme.blueTeam,
                  ),
                ),
                const SizedBox(width: 10),

                // Okunan Makale & Parça Bilgisi (Dokunulduğunda tam paneli açar)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showMediaSheet(context, tts),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'SESLİ OKUMA',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.blueTeam,
                                letterSpacing: 0.8,
                              ),
                            ),
                            if (tts.totalChunks > 1) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.border,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${tts.currentChunkIndex + 1}/${tts.totalChunks}',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tts.currentTitle ?? 'Doküman',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Doğrudan Tıklanabilir Hız Rozeti
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => tts.cycleSpeed(),
                  onLongPress: () => _showMediaSheet(context, tts),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCardHover,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.blueTeam.withAlpha(90)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.speed, size: 14, color: AppTheme.blueTeam),
                        const SizedBox(width: 4),
                        Text(
                          speedText,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 2),

                // Oynat / Duraklat Butonu
                IconButton(
                  icon: Icon(
                    tts.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    size: 30,
                    color: AppTheme.blueTeam,
                  ),
                  tooltip: tts.isPlaying ? 'Duraklat' : 'Devam Et',
                  onPressed: () {
                    if (tts.isPlaying) {
                      tts.pause();
                    } else {
                      tts.resume();
                    }
                  },
                ),

                // Kapat Butonu
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: AppTheme.textMuted),
                  tooltip: 'Durdur',
                  onPressed: () => tts.stop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Gelişmiş Ses Medya Sayfası (Hız, Parça Atlama, Ses Profilleri, Perde Ayarı)
class _TtsMediaSheet extends StatelessWidget {
  final TtsService tts;
  const _TtsMediaSheet({required this.tts});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: tts,
      builder: (context, _) {
        final speedMult = tts.speedMultiplier;

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Üst Başlık & Alt Başlık
                Text(
                  tts.currentTitle ?? 'Sesli Okuma',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (tts.currentSubtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      tts.currentSubtitle!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),

                // Parça İlerleme Çubuğu ve Slider (Çoklu parça varsa)
                if (tts.totalChunks > 1) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Parça ${tts.currentChunkIndex + 1} / ${tts.totalChunks}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.blueTeam,
                        ),
                      ),
                      Text(
                        '%${((tts.currentChunkIndex + 1) / tts.totalChunks * 100).toInt()}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppTheme.blueTeam,
                      inactiveTrackColor: AppTheme.border,
                      thumbColor: AppTheme.blueTeam,
                      overlayColor: AppTheme.blueTeam.withAlpha(40),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: tts.currentChunkIndex.toDouble(),
                      min: 0,
                      max: (tts.totalChunks - 1).toDouble(),
                      divisions: tts.totalChunks - 1,
                      onChanged: (val) {
                        tts.seekToChunk(val.round());
                      },
                    ),
                  ),
                ],

                // Oynatıcı Kontrolleri (Önceki - Oynat/Duraklat - Sonraki - Durdur)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filledTonal(
                      iconSize: 22,
                      tooltip: 'Önceki Parça',
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.bgCardHover,
                        foregroundColor: AppTheme.textPrimary,
                      ),
                      icon: const Icon(Icons.skip_previous),
                      onPressed: tts.totalChunks > 1 && tts.currentChunkIndex > 0
                          ? tts.previousChunk
                          : null,
                    ),
                    const SizedBox(width: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.blueTeam,
                        foregroundColor: Colors.black,
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(16),
                      ),
                      onPressed: tts.isPlaying ? tts.pause : tts.resume,
                      child: Icon(
                        tts.isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton.filledTonal(
                      iconSize: 22,
                      tooltip: 'Sonraki Parça',
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.bgCardHover,
                        foregroundColor: AppTheme.textPrimary,
                      ),
                      icon: const Icon(Icons.skip_next),
                      onPressed: tts.totalChunks > 1 &&
                              tts.currentChunkIndex + 1 < tts.totalChunks
                          ? tts.nextChunk
                          : null,
                    ),
                    const SizedBox(width: 16),
                    IconButton.outlined(
                      iconSize: 22,
                      tooltip: 'Tamamen Durdur',
                      style: IconButton.styleFrom(
                        side: const BorderSide(color: AppTheme.border),
                        foregroundColor: AppTheme.textMuted,
                      ),
                      icon: const Icon(Icons.stop),
                      onPressed: () {
                        tts.stop();
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppTheme.border),

                // ⚡ Okuma Hızı Bölümü
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.speed, size: 18, color: AppTheme.blueTeam),
                      const SizedBox(width: 8),
                      const Text(
                        'Okuma Hızı',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.blueTeam.withAlpha(30),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.blueTeam.withAlpha(100)),
                        ),
                        child: Text(
                          '${speedMult.toStringAsFixed(2)}x',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.blueTeam,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Hızlı Seçim Butonları (0.5x'ten 2.5x'e zengin seçenekler)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5].map((mult) {
                    final isSel = (speedMult - mult).abs() < 0.06;
                    return InkWell(
                      onTap: () => tts.setSpeedMultiplier(mult),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel ? AppTheme.blueTeam : AppTheme.bgCardHover,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSel ? AppTheme.blueTeam : AppTheme.border,
                          ),
                        ),
                        child: Text(
                          '${mult.toStringAsFixed(mult == mult.roundToDouble() ? 1 : 2)}x',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSel ? Colors.black : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 6),

                // Hassas Hız Kaydırıcısı (Slider)
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppTheme.blueTeam,
                    inactiveTrackColor: AppTheme.border,
                    thumbColor: AppTheme.blueTeam,
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: tts.speechRate.clamp(0.20, 1.00),
                    min: 0.20,
                    max: 1.00,
                    divisions: 16,
                    label: '${(tts.speechRate * 2.0).toStringAsFixed(2)}x',
                    onChanged: (val) {
                      tts.setSpeechRate(val);
                    },
                  ),
                ),

                const Divider(color: AppTheme.border),

                // 🎭 Ses Profilleri (Persona Seçimi)
                const Padding(
                  padding: EdgeInsets.only(top: 6, bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.record_voice_over_outlined, size: 18, color: AppTheme.toolsAmber),
                      SizedBox(width: 8),
                      Text(
                        'Ses Profilleri',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Profil Listesi Kartları
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: TtsProfile.values.map((prof) {
                      final isSel = tts.profile == prof;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: Icon(
                            prof.icon,
                            size: 16,
                            color: isSel ? Colors.black : AppTheme.toolsAmber,
                          ),
                          label: Text(prof.label),
                          selected: isSel,
                          selectedColor: AppTheme.toolsAmber,
                          backgroundColor: AppTheme.bgCardHover,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            color: isSel ? Colors.black : AppTheme.textPrimary,
                          ),
                          side: BorderSide(
                            color: isSel ? AppTheme.toolsAmber : AppTheme.border,
                          ),
                          onSelected: (selected) {
                            if (selected) tts.setProfile(prof);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Seçilen profil açıklaması
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 6),
                  child: Text(
                    tts.profile.description,
                    style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),

                // Ses Tonu / Perde (Pitch) Ayarı
                Row(
                  children: [
                    const Text(
                      'Ses Tonu (Perde):',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const Spacer(),
                    Text(
                      tts.pitch.toStringAsFixed(2),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.toolsAmber,
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppTheme.toolsAmber,
                    inactiveTrackColor: AppTheme.border,
                    thumbColor: AppTheme.toolsAmber,
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: tts.pitch.clamp(0.60, 1.40),
                    min: 0.60,
                    max: 1.40,
                    divisions: 16,
                    label: tts.pitch.toStringAsFixed(2),
                    onChanged: (val) {
                      tts.setPitch(val);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
