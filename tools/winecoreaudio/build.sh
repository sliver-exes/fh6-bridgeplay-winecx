#!/bin/sh
# Rebuild bin/winecoreaudio-MGF-x64.so: the x86-64 macOS winecoreaudio.so of the MGF runner.
#   = upstream Wine 11.17 dlls/winecoreaudio.drv + Highball patch 0057 (spatial mixer for surround beds).
# This is the dialogue fix for the Rosetta route: Forza Horizon 6 opens a 12-channel (7.1.4) spatial-audio
# bed; stock Wine on macOS leaves the centre channel (voices, dialogue) silent. Patch 0057 mixes the bed down
# through Apple's AUSpatialMixer.
#
# Usage: sh tools/winecoreaudio/build.sh WORKDIR [RUNNER_NTDLL_SO]
#   WORKDIR          scratch folder (created); the result is WORKDIR/winecoreaudio.so
#   RUNNER_NTDLL_SO  the runner's x86_64-unix/ntdll.so to link against
#                    (default: the MGF runner's, in your Bridgeplay folder)
# Needs: Apple clang (xcode-select --install), curl, tar, patch, shasum, codesign. Builds with no installs.
# Expected result: sha256 6af37a791598d081... (see bin/SHA256SUMS). Other clang versions may differ by a few
# bytes; both load the same way.
#
# Credits: Wine (WineHQ, LGPL-2.1+, https://www.winehq.org/), tarball wine-11.17.tar.xz;
#   patch 0057 by TxCsOffc, from Highball (Gauthier Piarrette), gauthierpiarrette/highball-engine
#   patches-arm64/0057, carried from highball PR #313 (LGPL-2.1); both unmodified.
#   Ours: shim/*.h, hand-written stand-ins for the widl-generated audioclient.h and mmdeviceapi.h
#   (only enum and constant values that Windows defines; widl is not installed on a normal Mac), and this script.
# Part of fh6-mac-fix (sliver-exes, GPL-3.0); see bin/CREDITS.md.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
W=${1:?usage: build.sh WORKDIR [RUNNER_NTDLL_SO]}
NT=${2:-$HOME/Library/Application Support/bridgeplay/runners/crossover-MGF-winecx-11.17/CrossOver/lib/wine/x86_64-unix/ntdll.so}
WINE_TAR=wine-11.17.tar.xz
WINE_URL=https://dl.winehq.org/wine/source/11.x/$WINE_TAR
# sha256 of the tarball this was built and tested with (compare with the WineHQ-published file).
WINE_SHA=8e752e29bba2901ad9f915139345c6ee67184b099d425704d915971ca5c055fc

[ -f "$NT" ] || { echo "runner ntdll.so not found: $NT" >&2; exit 1; }
mkdir -p "$W"
if [ ! -f "$W/$WINE_TAR" ]; then curl -fL --progress-bar -o "$W/$WINE_TAR" "$WINE_URL"; fi
[ "$(shasum -a 256 "$W/$WINE_TAR" | cut -d' ' -f1)" = "$WINE_SHA" ] || { echo "sha256 mismatch for $WINE_TAR" >&2; exit 1; }

rm -rf "$W/src"; mkdir "$W/src"
tar -xJf "$W/$WINE_TAR" -C "$W/src" --strip-components=1 wine-11.17/include wine-11.17/dlls/winecoreaudio.drv wine-11.17/dlls/mmdevapi
(cd "$W/src" && patch -p1 < "$HERE/0057-winecoreaudio-spatial-mixer-for-surround-beds.patch")

B="$W/obj"; rm -rf "$B"; mkdir -p "$B"; : > "$B/config.h"
cd "$W/src/dlls/winecoreaudio.drv"
for f in coreaudio coremidi; do
  clang -arch x86_64 -mmacosx-version-min=13.0 -O2 -g0 -fvisibility=hidden -fno-strict-aliasing -fPIC \
    -D__WINESRC__ -DWINE_UNIX_LIB -D_REENTRANT -D_FILE_OFFSET_BITS=64 -I. -I"$HERE/shim" -I../../include -I"$B" \
    -Wno-pragma-pack -Wno-deprecated-declarations -c "$f.c" -o "$B/$f.o"
done
cd "$W"
clang -arch x86_64 -mmacosx-version-min=13.0 -dynamiclib -o winecoreaudio.so "$B/coreaudio.o" "$B/coremidi.o" "$NT" \
  -Wl,-install_name,@rpath/winecoreaudio.so -Wl,-rpath,@loader_path/ \
  -framework CoreFoundation -framework CoreAudio -framework AudioUnit -framework AudioToolbox -framework CoreMIDI
codesign -s - -f winecoreaudio.so
shasum -a 256 winecoreaudio.so
