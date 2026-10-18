import 'package:flutter/material.dart';
import '../services/tts_service.dart';
import '../theme/app_theme.dart';

class TtsPlayerBar extends StatelessWidget {
  const TtsPlayerBar({super.key});

  void _showSpeedSheet(BuildContext context, TtsService tts) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Sesli Okuma Hızı',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [0.35, 0.45, 0.50, 0.60].map((rate) {
                    final label = rate == 0.35
                        ? '0.75x'
                        : (rate == 0.45 ? '0.9x' : (rate == 0.50 ? '1.0x' : '1.25x'));
                    final isSelected = (tts.speechRate - rate).abs() < 0.04;
                    return InkWell(
                      onTap: () {
                        tts.setRate(rate);
                        Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.blueTeam : AppTheme.bgCardHover,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? AppTheme.blueTeam : AppTheme.border,
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.black : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tts = TtsService();

    return ListenableBuilder(
      listenable: tts,
      builder: (context, _) {
        if (tts.isStopped) return const SizedBox.shrink();

        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF161F30),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.blueTeam.withAlpha(140), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(120),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Ses İkonu
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.blueTeam.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    tts.isPlaying ? Icons.volume_up : Icons.volume_mute,
                    size: 20,
                    color: AppTheme.blueTeam,
                  ),
                ),
                const SizedBox(width: 10),
                // Okunan Makale Başlığı
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'SESLİ OKUNUYOR',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.blueTeam,
                          letterSpacing: 0.8,
                        ),
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
                // Hız Ayar Butonu
                IconButton(
                  icon: const Icon(Icons.speed, size: 20, color: AppTheme.textSecondary),
                  tooltip: 'Okuma Hızı',
                  onPressed: () => _showSpeedSheet(context, tts),
                ),
                // Oynat / Duraklat Butonu
                IconButton(
                  icon: Icon(
                    tts.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                    size: 28,
                    color: AppTheme.blueTeam,
                  ),
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
