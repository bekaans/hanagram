#!/usr/bin/env bash
# Hanagram — ajan teslimatı kabul kapısı
#
# Üç şeyi denetler:
#   1. Sözleşme dosyaları değişmiş mi (başlıklar + testler)  → değiştiyse RED
#   2. Çekirdek sıfır uyarıyla derleniyor mu
#   3. Testlerin tamamı geçiyor mu
#
# Kullanım:  tools/kabul.sh          (denetle)
#            tools/kabul.sh --kilitle (mevcut sözleşmeyi referans al)
set -uo pipefail
cd "$(dirname "$0")/.."
export PATH="/opt/homebrew/bin:$PATH"

KILIT="tools/.sozlesme.sha"
SOZLESME=(
  core/include/hanagram/hanagram.h
  core/src/domain/social/messaging.hpp
  core/src/domain/identity/invite.hpp
  core/src/kernel/runtime.hpp
  core/src/kernel/store.hpp
  core/src/algo/ranker.hpp
  core/src/algo/interest.hpp
  core/src/algo/learner.hpp
  core/CMakeLists.txt
)

hashla() {
  { for f in "${SOZLESME[@]}"; do
      [ -f "$f" ] && shasum -a 256 "$f"
    done
    find core/tests -name '*.cpp' -o -name '*.hpp' | sort | xargs shasum -a 256
  } | shasum -a 256 | cut -d' ' -f1
}

if [ "${1:-}" = "--kilitle" ]; then
  hashla > "$KILIT"
  echo "Sözleşme kilitlendi: $(cat "$KILIT")"
  exit 0
fi

echo "── 1/3  Sözleşme bütünlüğü"
if [ -f "$KILIT" ]; then
  BEKLENEN=$(cat "$KILIT")
  SIMDI=$(hashla)
  if [ "$BEKLENEN" != "$SIMDI" ]; then
    echo "   ✗ RED — sözleşme veya testler değiştirilmiş."
    echo "     Ajan yalnızca .cpp/.dart yazmalıydı. Teslimatı geri çevir."
    exit 1
  fi
  echo "   ✓ değişmemiş"
else
  echo "   ! kilit yok — 'tools/kabul.sh --kilitle' ile referans al"
fi

echo "── 2/3  Derleme (sıfır uyarı zorunlu)"
CIKTI=$(cmake --build core/build 2>&1)
DURUM=$?
UYARI=$(echo "$CIKTI" | grep -c "warning:")
if [ $DURUM -ne 0 ]; then
  echo "   ✗ DERLEME BAŞARISIZ"
  echo "$CIKTI" | grep -E "error:" | head -20
  exit 1
fi
if [ "$UYARI" -gt 0 ]; then
  echo "   ✗ RED — $UYARI uyarı var"
  echo "$CIKTI" | grep "warning:" | head -10
  exit 1
fi
echo "   ✓ temiz"

echo "── 3/3  Testler"
SONUC=$(./core/build/hanagram_tests 2>&1)
if echo "$SONUC" | grep -q "TUMU GECTI"; then
  echo "   ✓ $(echo "$SONUC" | grep 'TUMU GECTI')"
  echo
  echo "KABUL EDİLDİ"
  exit 0
fi
echo "   ✗ RED — testler kaldı"
echo "$SONUC" | grep -A3 "✗" | head -30
exit 1
