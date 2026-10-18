import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../theme/app_theme.dart';

class CodeElementBuilder extends MarkdownElementBuilder {
  final BuildContext context;

  CodeElementBuilder(this.context);

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final textContent = element.textContent;

    // Satır içi kod (inline code): Çok satırlı değilse ve kod bloğu sınıfı/özelliği yoksa
    final isInline = !textContent.contains('\n') &&
        (element.attributes.isEmpty || !element.attributes.containsKey('class'));

    if (isInline) {
      // Satır içi kodların cümle akışını, parantezleri ve noktalama işaretlerini
      // bozmaması için MarkdownStyleSheet.code üzerinden akıcı TextSpan olarak render edilmesini sağlıyoruz.
      return null;
    }

    // Çok satırlı veya blok kod (Code Block)
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgCode,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderHighlight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Üst Başlık ve Kopyala Butonu
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF161B22),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.terminal, size: 14, color: AppTheme.textMuted),
                    SizedBox(width: 6),
                    Text(
                      'KOMUT / KOD',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: textContent.trim()));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: const [
                            Icon(Icons.check_circle, color: AppTheme.sysAdmin, size: 18),
                            SizedBox(width: 8),
                            Text('Komut panoya kopyalandı!'),
                          ],
                        ),
                        duration: const Duration(seconds: 2),
                        backgroundColor: AppTheme.bgCard,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: AppTheme.sysAdmin, width: 1),
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCardHover,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.border, width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.copy, size: 13, color: AppTheme.blueTeam),
                        SizedBox(width: 4),
                        Text(
                          'Kopyala',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.blueTeam,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Kod İçeriği (Yatay kaydırılabilir)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              textContent.trimRight(),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                color: Color(0xFFE2E8F0),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
