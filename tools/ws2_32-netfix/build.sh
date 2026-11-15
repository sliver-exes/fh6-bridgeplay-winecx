#!/usr/bin/env bash
# Build the FH6 ws2_32 proxy (x64 PE) against the runner's ARM64X ws2_32.dll.
#   build-fh6-netfix.sh <runner ws2_32.dll> [output]
# Export names/ordinals come from pe.py (host python3); compile runs in Docker
# (mstorsjo/llvm-mingw). Adapted from MacGameFix fixes/build-fh5-netfix.sh
# (MathiasKowoll/MacGameFix, GPL-3.0). Change: Docker compile, fh6 source.
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$(cd "$HERE/../../src" && pwd)"
REFERENCE="${1:?usage: tools/ws2_32-netfix/build.sh <ws2_32.dll> [output]}"
OUTPUT="${2:-$HERE/build/ws2_32-fh6.dll}"
mkdir -p "$(dirname "$OUTPUT")"
IMAGE="${IMAGE:-mstorsjo/llvm-mingw}"
[ -f "$REFERENCE" ] || { echo "no such file: $REFERENCE" >&2; exit 1; }
DEF="$HERE/ws2_32.def"
{
  echo "LIBRARY ws2_32.dll"; echo "EXPORTS"
  python3 "$HERE/pe.py" exports "$REFERENCE" --ordinals | while read -r ordinal symbol; do
    case "$symbol" in
      socket|WSASocketW|WSASocketA|WSAIoctl|setsockopt|closesocket)
        printf '    %s=wrap_%s @%s\n' "$symbol" "$symbol" "$ordinal" ;;
      *) printf '    %s=ws2_o.%s @%s\n' "$symbol" "$symbol" "$ordinal" ;;
    esac
  done
} > "$DEF"
count=$(($(wc -l < "$DEF") - 2)); [ "$count" -gt 0 ] || { echo "no exports" >&2; exit 1; }
# Mount the tool folder (the .def) and the sources; the DLL is written next to the .def, then moved.
docker run --rm -v "$HERE":/tool -v "$SRC":/src:ro -w /tool "$IMAGE" x86_64-w64-mingw32-clang -O2 -fno-builtin \
  -fno-stack-protector -Wall -Wextra -Wno-cast-function-type -shared -nostdlib -Wl,-e,DllMain \
  -o "/tool/.out.dll" /src/fh6-netfix.c /tool/ws2_32.def -lkernel32
mv "$HERE/.out.dll" "$OUTPUT"
got=$(python3 "$HERE/pe.py" exports "$OUTPUT" | wc -l | tr -d ' ')
[ "$got" = "$count" ] || { echo "proxy exports $got, expected $count" >&2; exit 1; }
echo "built $OUTPUT; $count exports matched to $(basename "$REFERENCE")"
echo "sha256 $(shasum -a 256 "$OUTPUT" | cut -d' ' -f1)"
