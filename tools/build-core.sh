#!/usr/bin/env bash
# Hanagram — çekirdek derleme hattı (beş platform)
#
# Kullanım:
#   tools/build-core.sh           → tüm platformlar
#   tools/build-core.sh macos     → yalnızca macOS
#   tools/build-core.sh android   → yalnızca Android
#   tools/build-core.sh ios       → yalnızca iOS
#   tools/build-core.sh windows   → yalnızca Windows
#   tools/build-core.sh linux     → yalnızca Linux
#
# Gereklilikler:
#   - CMake 3.20+
#   - macOS/iOS: Xcode komut satırı araçları (xcrun)
#   - Android: NDK (ANDROID_NDK_HOME ayarlı)
#   - Windows: Visual Studio veya MinGW
#   - Linux: GCC veya Clang
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="$ROOT/core"

# Testleri çalıştırıp çalıştırmayacak — 0=çalıştır, 1=atla
SKIP_TESTS="${SKIP_TESTS:-0}"

echo "=== Hanagram çekirdek derleme hattı ==="
echo ""

build_host() {
  echo "[macOS/Linux/Windows] Host makinesi derleniyor..."
  mkdir -p "$CORE/build"
  cd "$CORE/build"
  cmake .. -DCMAKE_BUILD_TYPE=Release 2>&1
  cmake --build . -j$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4) 2>&1
  echo "✓ Host derlemesi tamamlandı → $CORE/build/"
}

run_tests() {
  if [ "$SKIP_TESTS" = "1" ]; then
    echo "⏭  Testler atlandı (SKIP_TESTS=1)"
    return
  fi
  echo ""
  echo "── Testler çalıştırılıyor ──"
  cd "$CORE/build"
  if ./hanagram_tests; then
    echo "✓ Tüm testler geçti"
  else
    echo "✗ Testler başarısız — derleme durduruldu"
    exit 1
  fi
}

build_macos() {
  echo ""
  echo "[macOS] Universal binary (arm64 + x86_64) derleniyor..."
  mkdir -p "$CORE/build-macos"
  cd "$CORE/build-macos"
  cmake "$CORE" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
    -DCMAKE_CXX_FLAGS="-fvisibility=hidden" 2>&1
  cmake --build . -j$(sysctl -n hw.ncpu) 2>&1
  # libhanagram.dylib → hem Xcode Frameworks hem geliştirme yolu
  if [ -f libhanagram.dylib ]; then
    cp libhanagram.dylib "$ROOT/app/macos/Runner/libhanagram.dylib" 2>/dev/null || true
    echo "✓ macOS: libhanagram.dylib derlendi (universal)"
  fi
}

build_ios() {
  echo ""
  echo "[iOS] Universal derleniyor (arm64, cihaz + simülatör)..."
  mkdir -p "$CORE/build-ios-device"
  cd "$CORE/build-ios-device"
  cmake "$CORE" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=16.0 \
    -DCMAKE_CXX_FLAGS="-fvisibility=hidden" \
    -DBUILD_SHARED_LIBS=OFF 2>&1
  cmake --build . -j$(sysctl -n hw.ncpu) 2>&1

  # iOS simülatörü (arm64 Apple Silicon)
  mkdir -p "$CORE/build-ios-sim"
  cd "$CORE/build-ios-sim"
  cmake "$CORE" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT=iphonesimulator \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=16.0 \
    -DCMAKE_CXX_FLAGS="-fvisibility=hidden" \
    -DBUILD_SHARED_LIBS=OFF 2>&1
  cmake --build . -j$(sysctl -n hw.ncpu) 2>&1
  echo "✓ iOS: statik kütüphane derlendi (cihaz + simülatör)"
}

build_android() {
  echo ""
  echo "[Android] NDK ile derleniyor..."

  if [ -z "${ANDROID_NDK_HOME:-}" ]; then
    echo "✗ ANDROID_NDK_HOME ayarlı değil — Android derlemesi atlandı"
    return
  fi

  for ABI in arm64-v8a armeabi-v7a x86_64; do
    mkdir -p "$CORE/build-android-$ABI"
    cd "$CORE/build-android-$ABI"
    cmake "$CORE" \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
      -DANDROID_ABI="$ABI" \
      -DANDROID_PLATFORM=android-24 \
      -DCMAKE_CXX_FLAGS="-fvisibility=hidden" \
      -DBUILD_SHARED_LIBS=ON 2>&1
    cmake --build . -j$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4) 2>&1
    echo "  ✓ $ABI derlendi"
  done

  # .so dosyalarını Flutter android/jniLibs'e kopyala
  JNIDIR="$ROOT/app/android/app/src/main/jniLibs"
  for ABI in arm64-v8a armeabi-v7a x86_64; do
    mkdir -p "$JNIDIR/$ABI"
    cp "$CORE/build-android-$ABI/libhanagram.so" "$JNIDIR/$ABI/" 2>/dev/null || true
  done
  echo "✓ Android: .so dosyaları jniLibs'e kopyalandı"
}

build_linux() {
  echo ""
  echo "[Linux] .so derleniyor..."
  mkdir -p "$CORE/build-linux"
  cd "$CORE/build-linux"
  cmake "$CORE" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DCMAKE_CXX_FLAGS="-fvisibility=hidden" 2>&1
  cmake --build . -j$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4) 2>&1
  echo "✓ Linux: libhanagram.so derlendi"
}

build_windows() {
  echo ""
  echo "[Windows] .dll derleniyor (varsayılan derleyici ile)..."
  echo "  Not: Windows derlemesi native ortamda (PowerShell/Developer Command Prompt) yapılmalıdır."
  echo "  Komut: cmake --preset release && cmake --build --preset release"
  echo ""
}

# Ana akış
PLATFORM="${1:-all}"

case "$PLATFORM" in
  all)
    build_host
    run_tests
    build_macos
    build_ios
    build_android
    build_linux
    echo ""
    echo "=== Tamamlandı: $CORE/build-*/ ==="
    ;;
  host)
    build_host
    run_tests
    ;;
  macos)
    build_host
    build_macos
    ;;
  ios)
    build_host
    build_ios
    ;;
  android)
    build_host
    build_android
    ;;
  linux)
    build_host
    build_linux
    ;;
  windows)
    build_host
    build_windows
    ;;
  tests)
    build_host
    run_tests
    ;;
  *)
    echo "Kullanım: $0 [all|host|macos|ios|android|linux|windows|tests]"
    exit 1
    ;;
esac