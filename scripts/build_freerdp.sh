#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$ROOT_DIR/vendor/FreeRDP"
BUILD_DIR="$SRC_DIR/build-macos"
INSTALL_DIR="$BUILD_DIR/install"

CONFIGURATION="${CONFIGURATION:-Release}"
ARCHS="${ARCHS:-arm64}"

# Skip rebuild if libraries already exist
if [[ -f "$INSTALL_DIR/lib/libMacFreeRDP-library.dylib" ]] && \
   [[ -f "$INSTALL_DIR/lib/libfreerdp3.3.dylib" ]] && \
   [[ -f "$INSTALL_DIR/lib/libwinpr3.3.dylib" ]]; then
  echo "FreeRDP libraries already exist at $INSTALL_DIR, skipping build."
  exit 0
fi

if [[ ! -d "$SRC_DIR" ]]; then
  echo "FreeRDP source not found at $SRC_DIR" >&2
  exit 1
fi

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH}"

CMAKE_BIN="$(command -v cmake || true)"
if [[ -z "$CMAKE_BIN" && -x "/opt/homebrew/bin/cmake" ]]; then
  CMAKE_BIN="/opt/homebrew/bin/cmake"
fi
if [[ -z "$CMAKE_BIN" && -x "/usr/local/bin/cmake" ]]; then
  CMAKE_BIN="/usr/local/bin/cmake"
fi
if [[ -z "$CMAKE_BIN" ]]; then
  echo "cmake is required to build FreeRDP (install via Homebrew: brew install cmake)" >&2
  exit 1
fi

cmake_args=(
  -UWITH_SWSCALE
  -UWITH_FFMPEG
  -UWITH_DSP_FFMPEG
  -UWITH_OPUS
  -UWITH_CAIRO
  -UCHANNEL_URBDRC
  -UCHANNEL_URBDRC_CLIENT
  -UCHANNEL_URBDRC_SERVER
  -DCMAKE_BUILD_TYPE="$CONFIGURATION"
  -DCMAKE_OSX_ARCHITECTURES="$ARCHS"
  -DCMAKE_SKIP_INSTALL_RPATH=TRUE
  -DCMAKE_SKIP_RPATH=TRUE
  -DCMAKE_BUILD_WITH_INSTALL_RPATH=FALSE
  -DCMAKE_INSTALL_RPATH=""
  -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=FALSE
  -DCMAKE_MACOSX_RPATH=OFF
  -DBUILD_SHARED_LIBS=ON
  -DWITH_CLIENT=ON
  -DWITH_CLIENT_MAC=ON
  -DWITH_COCOA=ON
  -DWITH_SERVER=OFF
  -DWITH_SAMPLE=OFF
  -DWITH_MANPAGES=OFF
  -DWITH_SDL=OFF
  -DWITH_X11=OFF
  -DWITH_WAYLAND=OFF
  -DWITH_PULSE=OFF
  -DWITH_ALSA=OFF
  -DWITH_FFMPEG=OFF
  -DWITH_CAIRO=OFF
  -DWITH_OPUS=OFF
  -DWITH_SWSCALE=OFF
  -DWITH_DSP_FFMPEG=OFF
  -DWITH_URBDRC=OFF
  -DWITH_USB=OFF
  -DCHANNEL_URBDRC=OFF
  -DCHANNEL_URBDRC_CLIENT=OFF
  -DCHANNEL_URBDRC_SERVER=OFF
  -DWITH_GSSAPI=OFF
  -DWITH_PCSC=OFF
  -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR"
)

if command -v brew >/dev/null 2>&1; then
  if brew --prefix openssl@3 >/dev/null 2>&1; then
    OPENSSL_DIR="$(brew --prefix openssl@3)"
    cmake_args+=("-DOPENSSL_ROOT_DIR=$OPENSSL_DIR")
    export PKG_CONFIG_PATH="$OPENSSL_DIR/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
  fi
fi

"$CMAKE_BIN" -S "$SRC_DIR" -B "$BUILD_DIR" "${cmake_args[@]}"
"$CMAKE_BIN" --build "$BUILD_DIR" --config "$CONFIGURATION"
"$CMAKE_BIN" --install "$BUILD_DIR" --config "$CONFIGURATION"

LIB_DIR="$INSTALL_DIR/lib"
if [[ -d "$LIB_DIR" ]]; then
  # Fix any bad self-referential symlinks from earlier runs.
  rm -f "$LIB_DIR/libfreerdp-client.dylib" "$LIB_DIR/libfreerdp.dylib" "$LIB_DIR/libwinpr.dylib"

  target=$(ls "$LIB_DIR"/libfreerdp-client*[0-9].dylib 2>/dev/null | head -n 1 || true)
  if [[ -n "$target" ]]; then
    ln -sf "$(basename "$target")" "$LIB_DIR/libfreerdp-client.dylib"
  fi

  target=$(ls "$LIB_DIR"/libfreerdp[0-9]*.dylib 2>/dev/null | head -n 1 || true)
  if [[ -n "$target" ]]; then
    ln -sf "$(basename "$target")" "$LIB_DIR/libfreerdp.dylib"
  fi

  target=$(ls "$LIB_DIR"/libwinpr[0-9]*.dylib 2>/dev/null | head -n 1 || true)
  if [[ -n "$target" ]]; then
    ln -sf "$(basename "$target")" "$LIB_DIR/libwinpr.dylib"
  fi
fi

if [[ -n "${TARGET_BUILD_DIR:-}" ]]; then
  # Prefer Frameworks folder path from Xcode, fallback to app bundle path.
  if [[ -n "${FRAMEWORKS_FOLDER_PATH:-}" ]]; then
    DEST_DIR="$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH"
  elif [[ -n "${EXECUTABLE_FOLDER_PATH:-}" ]]; then
    DEST_DIR="$TARGET_BUILD_DIR/$EXECUTABLE_FOLDER_PATH/../Frameworks"
  else
    DEST_DIR=""
  fi

  if [[ -n "$DEST_DIR" ]]; then
    mkdir -p "$DEST_DIR"
    if compgen -G "$INSTALL_DIR/lib/*.dylib" >/dev/null; then
      # Use -L to copy the real file instead of symlink loops.
      cp -fL "$INSTALL_DIR/lib/"*.dylib "$DEST_DIR/"
    fi

    # Ensure the MacFreeRDP library has a safe install name for runtime loading.
    if [[ -f "$DEST_DIR/libMacFreeRDP-library.dylib" ]]; then
      install_name_tool -id "@rpath/libMacFreeRDP-library.dylib" "$DEST_DIR/libMacFreeRDP-library.dylib" || true
    fi
  fi

  # Ensure the app binary links against @rpath/libMacFreeRDP-library.dylib.
  if [[ -n "${EXECUTABLE_FOLDER_PATH:-}" ]]; then
    BIN_DIR="$TARGET_BUILD_DIR/$EXECUTABLE_FOLDER_PATH"
    if [[ -d "$BIN_DIR" ]]; then
      for bin in "$BIN_DIR"/*; do
        if [[ -f "$bin" ]]; then
          install_name_tool -change "libMacFreeRDP-library.dylib" "@rpath/libMacFreeRDP-library.dylib" "$bin" 2>/dev/null || true
        fi
      done
    fi
  fi
fi

echo "FreeRDP built and installed to $INSTALL_DIR"
