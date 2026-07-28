#!/usr/bin/env bash
# Hanagram — kalite kapısı
#
# Doğruluk kapısı (derleme + test) geçtikten SONRA çalışır. İnsan gözden
# geçirmesinin yerine geçer.
#
# Borç dondurma: mevcut ihlaller tools/.review-muafiyet dosyasında kayıtlıdır.
# Kapı YENİ ihlal eklenmesini engeller; eski borç ayrı ayrı ödenir. Böylece kural
# bugünden itibaren geçerli olur ve proje durmaz.
set -uo pipefail
cd "$(dirname "$0")/.."
MUAF="tools/.review-muafiyet"
touch "$MUAF"
fail=0
note() { echo "  ✗ $*"; fail=1; }
muaf() { grep -qxF "$1" "$MUAF"; }

# ── Hata ayıklama kalıntısı (biçimlendirme çağrıları hariç)
hits=$(grep -rn "std::cout\|std::cerr\|debugPrint(" --include="*.cpp" --include="*.dart" \
       core/src app/lib admin/lib 2>/dev/null | grep -v "/tests/" || true)
[ -n "$hits" ] && { echo "$hits"; note "hata ayıklama çıktısı bırakılmış"; }

# ── Bırakılmış işaretler
hits=$(grep -rn "FIXME\|XXX:" --include="*.cpp" --include="*.hpp" --include="*.dart" \
       core/src app/lib admin/lib 2>/dev/null || true)
[ -n "$hits" ] && { echo "$hits"; note "bırakılmış FIXME"; }

# ── Tasarım sistemi kaçağı
hits=$(grep -rnE "Color\(0x" --include="*.dart" app/lib admin/lib 2>/dev/null \
       | grep -v "design/tokens.dart" || true)
[ -n "$hits" ] && { echo "$hits"; note "ham renk kodu — HgTheme.of(context) kullanılmalı"; }

# ── Gömülü sır: uzun ve rastgele görünen değerler
hits=$(grep -rnE "(api[_-]?key|apiKey|secret|password)[[:space:]]*[:=][[:space:]]*[\"'][A-Za-z0-9_/+=-]{20,}" \
       --include="*.cpp" --include="*.dart" --include="*.json" \
       core/src app/lib admin/lib 2>/dev/null || true)
[ -n "$hits" ] && { echo "$hits"; note "gömülü sır"; }

# ── Dosya boyutu — yeni ihlal yasak, eski borç muafiyette
#
# Sınır dile göre ayrılır. 300 satır bir ARAYÜZ dosyası için doğru ölçüdür:
# widget ağacı derinleşince okunmaz olur, bölünmesi de kolaydır. Bir C++
# uygulama dosyası ise tek başlığın sözleşmesini karşılar; 20+ fonksiyon artı
# JSON serileştirmesi doğal olarak daha uzun sürer ve mekanik ikiye bölmek
# okunurluğu artırmaz, iki dosyayı birlikte okumaya zorlar. Bu yüzden C++ sınırı
# 400'dür — muafiyet değil, farklı işin farklı ölçüsü.
while IFS= read -r f; do
  n=$(wc -l < "$f" | tr -d ' ')
  case "$f" in
    *.dart) limit=300 ;;
    *)      limit=400 ;;
  esac
  if [ "$n" -gt "$limit" ] && ! muaf "$f"; then
    note "$f: $n satır — $limit üstü bölünmeli"
  fi
done < <(find core/src app/lib admin/lib \( -name "*.cpp" -o -name "*.hpp" -o -name "*.dart" \) 2>/dev/null)

# ── Çekirdek saflığı: platform bilgisi bridge katmanına aittir
hits=$(grep -rn "#ifdef __APPLE__\|#ifdef _WIN32\|#include <flutter" core/src 2>/dev/null || true)
[ -n "$hits" ] && { echo "$hits"; note "çekirdekte platform sızıntısı"; }

# ── Çekirdek bağımlılığı sıfır olmalı
if [ -d core/third_party ] && [ -n "$(ls -A core/third_party 2>/dev/null)" ]; then
  note "core/third_party dolu — çekirdek sıfır bağımlılık olmalı"
fi

[ $fail -eq 0 ] && echo "kalite: temiz"
exit $fail
