#!/usr/bin/env bash
# ==============================================================================
# Active Directory Handbook & Arsenal - Web Derleme Betiği
# ==============================================================================
# Bu betik:
# 1. '1-Sistem_Yoneticisi', '2-Blue_Team' ve '3-Red_Team' klasörlerini tarar.
# 2. Tüm Markdown konularını çevrimdışı web varlıklarına dönüştürür.
# 3. Flutter Web sürümünü derler.
# 4. Derlenen statik web sitesini 'dist/web' konumuna kopyalar.
# ==============================================================================

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$PROJECT_DIR/app"
DIST_DIR="$PROJECT_DIR/dist/web"

echo "================================================================="
echo "  🌐 ACTIVE DIRECTORY VAULT - WEB DERLEME SİSTEMİ"
echo "================================================================="

if [ -d "/usr/lib/jvm/java-17-openjdk-amd64" ]; then
    export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
elif [ -d "/usr/lib/jvm/java-21-openjdk-amd64" ]; then
    export JAVA_HOME="/usr/lib/jvm/java-21-openjdk-amd64"
fi

export PATH="$JAVA_HOME/bin:/home/zeus/development/flutter/bin:$PATH"

echo "[1/3] 📚 Markdown Konuları ve Cephanelik Taranıyor..."
python3 "$PROJECT_DIR/scripts/build_content.py" "$APP_DIR/assets/data"
python3 "$PROJECT_DIR/scripts/extract_commands.py"

echo ""
echo "[2/3] ⚙️  Web Sürümü Derleniyor (HTML5 / CanvasKit / WASM)..."
cd "$APP_DIR"
flutter build web --release

echo ""
echo "[3/3] 📦 Statik Web Dosyaları Hazırlanıyor..."
mkdir -p "$DIST_DIR"
rm -rf "$DIST_DIR"/*
cp -r "$APP_DIR/build/web"/* "$DIST_DIR/"

echo ""
echo "================================================================="
echo "  ✅ WEB DERLEMESİ BAŞARIYLA TAMAMLANDI!"
echo "================================================================="
echo "  🌐 Web Dizini: $DIST_DIR"
echo "  💡 Yerel Olarak Başlatmak İçin:"
echo "     python3 -m http.server -d dist/web 8080"
echo "================================================================="
