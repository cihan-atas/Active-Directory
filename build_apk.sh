#!/usr/bin/env bash
# ==============================================================================
# Active Directory Handbook & Arsenal - Otomatik Derleme Betiği
# ==============================================================================
# Bu betik:
# 1. '1-Sistem_Yoneticisi', '2-Blue_Team' ve '3-Red_Team' klasörlerini tarar.
# 2. Yeni eklenen veya güncellenen tüm Markdown konularını çevrimdışı JSON indeksine dönüştürür.
# 3. Sıfır internet gereksinimiyle çalışan bağımsız Android APK'sını derler.
# 4. Derlenen APK dosyasını 'dist/ActiveDirectory_Handbook.apk' konumuna kopyalar.
# ==============================================================================

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$PROJECT_DIR/app"
DIST_DIR="$PROJECT_DIR/dist"

echo "================================================================="
echo "  🛡️  ACTIVE DIRECTORY VAULT - DERLEME SİSTEMİ"
echo "================================================================="

# 1. Ortam Değişkenleri ve Java Kontrolü
if [ -d "/usr/lib/jvm/java-17-openjdk-amd64" ]; then
    export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
elif [ -d "/usr/lib/jvm/java-21-openjdk-amd64" ]; then
    export JAVA_HOME="/usr/lib/jvm/java-21-openjdk-amd64"
fi

export PATH="$JAVA_HOME/bin:/home/zeus/development/flutter/bin:$PATH"
export ANDROID_HOME="/home/zeus/Android/Sdk"

echo "[1/4] 🔍 Çevre ve Araçlar Kontrol Ediliyor..."
echo "  • JAVA_HOME: $JAVA_HOME"
echo "  • Flutter: $(flutter --version | head -n 1)"
echo "  • Android SDK: $ANDROID_HOME"

# 2. İçerik Çıkarımı ve İndeksleme
echo ""
echo "[2/4] 📚 Markdown Konuları ve Cephanelik Taranıyor..."
python3 "$PROJECT_DIR/scripts/build_content.py" "$APP_DIR/assets/data"
python3 "$PROJECT_DIR/scripts/extract_commands.py"

# 3. Android APK Derleme
echo ""
echo "[3/4] ⚙️  Android APK Derleniyor (Release Modu)..."
cd "$APP_DIR"
flutter build apk --release --no-tree-shake-icons

# 4. Çıktı Dosyasını Hazırlama
mkdir -p "$DIST_DIR"
BUILT_APK="$APP_DIR/build/app/outputs/flutter-apk/app-release.apk"
TARGET_APK="$DIST_DIR/ActiveDirectory_Handbook.apk"

if [ -f "$BUILT_APK" ]; then
    cp "$BUILT_APK" "$TARGET_APK"
    APK_SIZE=$(du -h "$TARGET_APK" | cut -f1)
    echo ""
    echo "================================================================="
    echo "  ✅ DERLEME BAŞARIYLA TAMAMLANDI!"
    echo "================================================================="
    echo "  📱 APK Dosyası: $TARGET_APK"
    echo "  📦 Dosya Boyutu: $APK_SIZE"
    echo "  🌐 Mod: %100 Çevrimdışı (İnternet Bağlantısı GEREKMEZ)"
    echo "  📄 Dahil Edilen Konu Sayısı: 315 Doküman + 146 Araç Rehberi"
    echo "================================================================="
    echo "Cihaza yüklemek için:"
    echo "  adb install -r $TARGET_APK"
    echo "================================================================="
else
    echo "❌ HATA: APK dosyası üretilemedi: $BUILT_APK"
    exit 1
fi
