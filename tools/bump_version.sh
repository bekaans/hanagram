#!/bin/bash
# Hanagram — otomatik versiyon artırma + Supabase'e kayıt
#
# Kullanım:
#   ./tools/bump_version.sh [major|minor|patch] [changelog] [is_force]
#
# Örnek:
#   ./tools/bump_version.sh patch "Hata düzeltmeleri" false
#   ./tools/bump_version.sh minor "Yeni özellikler" false
#   ./tools/bump_version.sh major "Büyük güncelleme" true

set -e

# ─── Parametreler ───
BUMP_TYPE="${1:-patch}"
CHANGELOG="${2:-Güncelleme}"
IS_FORCE="${3:-false}"

# ─── Mevcut versiyonu oku ───
PUBSPEC="app/pubspec.yaml"
if [ ! -f "$PUBSPEC" ]; then
  echo "❌ pubspec.yaml bulunamadı: $PUBSPEC"
  exit 1
fi

CURRENT_LINE=$(grep "^version:" "$PUBSPEC")
CURRENT_VERSION=$(echo "$CURRENT_LINE" | sed 's/version: //' | cut -d'+' -f1)
CURRENT_BUILD=$(echo "$CURRENT_LINE" | sed 's/version: //' | cut -d'+' -f2)

echo "📌 Mevcut: v$CURRENT_VERSION+$CURRENT_BUILD"

# ─── Versiyonu artır ───
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

case "$BUMP_TYPE" in
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  patch|*)
    PATCH=$((PATCH + 1))
    ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"
NEW_BUILD=$((CURRENT_BUILD + 1))

echo "🆕 Yeni: v$NEW_VERSION+$NEW_BUILD"

# ─── pubspec.yaml'ı güncelle ───
sed -i '' "s/^version: .*/version: $NEW_VERSION+$NEW_BUILD/" "$PUBSPEC"
echo "✅ pubspec.yaml güncellendi"

# ─── Platform versiyonlarını güncelle (iOS/Android) ───
# iOS INFOPLIST_VERSION
IOS_PLIST="ios/Runner/Info.plist"
if [ -f "$IOS_PLIST" ]; then
  sed -i '' "s/<string>$CURRENT_VERSION<\/string>/<string>$NEW_VERSION<\/string>/" "$IOS_PLIST"
  echo "✅ iOS Info.plist güncellendi"
fi

# Android build.gradle
ANDROID_GRADLE="android/app/build.gradle"
if [ -f "$ANDROID_GRADLE" ]; then
  sed -i '' "s/versionCode $CURRENT_BUILD/versionCode $NEW_BUILD/" "$ANDROID_GRADLE"
  sed -i '' "s/versionName \"$CURRENT_VERSION\"/versionName \"$NEW_VERSION\"/" "$ANDROID_GRADLE"
  echo "✅ Android build.gradle güncellendi"
fi

# ─── SQL migration oluştur ───
MIGRATION_DIR="supabase/migrations"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
MIGRATION_FILE="$MIGRATION_DIR/${TIMESTAMP}_bump_version.sql"

# Platform tespiti
if [[ "$OSTYPE" == "darwin"* ]]; then
  PLATFORM="macos"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  PLATFORM="linux"
else
  PLATFORM="unknown"
fi

mkdir -p "$MIGRATION_DIR"
cat > "$MIGRATION_FILE" << EOF
-- Hanagram versiyon bump: v$NEW_VERSION+$NEW_BUILD
-- Oluşturulma: $(date '+%Y-%m-%d %H:%M:%S')
-- Changelog: $CHANGELOG

INSERT INTO app_versions (version, build_number, platform, changelog, is_force, is_active)
VALUES
  ('v$NEW_VERSION', $NEW_BUILD, 'android', '$CHANGELOG', $IS_FORCE, true),
  ('v$NEW_VERSION', $NEW_BUILD, 'ios', '$CHANGELOG', $IS_FORCE, true),
  ('v$NEW_VERSION', $NEW_BUILD, 'macos', '$CHANGELOG', $IS_FORCE, true),
  ('v$NEW_VERSION', $NEW_BUILD, 'windows', '$CHANGELOG', $IS_FORCE, true),
  ('v$NEW_VERSION', $NEW_BUILD, 'web', '$CHANGELOG', $IS_FORCE, true);
EOF

echo "✅ SQL migration oluşturuldu: $MIGRATION_FILE"

# ─── Özeti göster ───
echo ""
echo "═══════════════════════════════════════"
echo "  v$NEW_VERSION+$NEW_BUILD hazır!"
echo "═══════════════════════════════════════"
echo ""
echo "Sonraki adımlar:"
echo "  1. SQL migration'ı Supabase'e uygula:"
echo "     supabase db push"
echo "     veya Supabase Dashboard > SQL Editor"
echo ""
echo "  2. Build al:"
echo "     flutter build macos --release"
echo "     flutter build apk --release"
echo "     flutter build ios --release"
echo ""
echo "  3. Kullanıcılar uygulamayı açtığında güncelleme görecek"
echo ""
