#!/usr/bin/env bash
# ==============================================================================
# Active Directory Vault - Master Derleme Arayüzü
# ==============================================================================

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
    cat << "EOF"
================================================================================
  🛡️  ACTIVE DIRECTORY VAULT — DERLEME VE YÖNETİM YARDIMI
================================================================================

Kullanım:
  ./build.sh [SEÇENEK]

Seçenekler:
  --apk             Android APK derler (Varsayılan).
                    Orijinal Markdown dosyalarını tarar, indeksler ve 
                    'dist/ActiveDirectory_Handbook.apk' dosyasını üretir.

  --web             Web sürümünü derler.
                    Statik HTML5/CanvasKit web sitesi oluşturur ve 
                    'dist/web/' klasörüne kopyalar.

  --all             Hem Android APK hem de Web sürümünü sırayla derler.

  --sync-only       Yalnızca Markdown içeriklerini tarar ve çevrimdışı JSON
                    verilerini günceller (APK veya Web derlemesi yapmaz).

  -h, --help, help  Bu yardım ve kullanım kılavuzunu görüntüler.

Örnekler:
  ./build.sh                  # Varsayılan: Çevrimdışı Android APK derler
  ./build.sh --apk            # Android APK derler
  ./build.sh --web            # Web platformunu derler
  ./build.sh --all            # Tüm hedefleri (APK + Web) derler
  ./build.sh --sync-only      # Sadece doküman indeksini senkronize eder

Web Sitesini Yerel Başlatma:
  python3 -m http.server -d dist/web 8080

Android Cihaza Yükleme:
  adb install -r dist/ActiveDirectory_Handbook.apk
================================================================================
EOF
}

case "$1" in
    -h|--help|help)
        show_help
        exit 0
        ;;
    --web)
        "$PROJECT_DIR/build_web.sh"
        ;;
    --all)
        "$PROJECT_DIR/build_apk.sh"
        echo ""
        "$PROJECT_DIR/build_web.sh"
        ;;
    --sync-only)
        echo "📚 Markdown Konuları ve Cephanelik Taranıyor..."
        python3 "$PROJECT_DIR/scripts/build_content.py" "$PROJECT_DIR/app/assets/data"
        python3 "$PROJECT_DIR/scripts/extract_commands.py"
        ;;
    --apk|"")
        "$PROJECT_DIR/build_apk.sh"
        ;;
    *)
        echo "❌ Geçersiz seçenek: '$1'"
        echo ""
        show_help
        exit 1
        ;;
esac
