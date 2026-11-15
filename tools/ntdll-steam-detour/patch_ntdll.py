#!/usr/bin/env python3
"""Rebuild bin/ntdll-FH-fex.dll from the stock Highball r3 arm64 ntdll.dll.

usage: python3 -I tools/ntdll-steam-detour/patch_ntdll.py STOCK_NTDLL OUT_NTDLL

Port of Bridgeplay's steamclient64 detour (raymondchins/Bridgeplay, GPL-3.0, "detour64-fex") to the
ARM64EC view of Wine's ntdll (Wine, LGPL-2.1+; engine build by Gauthier Piarrette's highball-engine).
Two edits, both asserted:
  1. 4 bytes at RVA 0x97724: "ldr x8,[sp,#0x60]" -> "b 0x1800e0c00"  (inside EC build_module())
  2. 812 bytes at RVA 0xE0C00 (zero padding at the end of the EC code page): the detour.
The detour source is src/ec_detour.s (assembled with clang --target=aarch64, bytes embedded below).
Only valid for the stock r3 ntdll (sha256 77904aab...1a44); the result must be 52416b5b...7aa.
"""
import hashlib, struct, sys

STOCK = "77904aabc9286200ac48a187e7a7dc2f9a4d1dd9ddeaea2c6ca1a66ec8711a44"
WANT = "52416b5bfa5d6e1c3a895c26cb01fca031dae4084bd4192fcdd7701581d057aa"
DETOUR = bytes.fromhex(
    "ff8303d1e00700a9e20f01a9e41702a9e61f03a9e82704a9ea2f05a9ec3706a9ee3f07a9f04708a901423bd5f20709a9"
    "fe5300f968b6d810098fd710e8270ba9c8d6fd10e86300f9e0c30291e10340f9e20319aa13000094fe5340f9f20749a9"
    "01421bd5f04748a9ee3f47a9ec3746a9ea2f45a9e82744a9e61f43a9e41742a9e20f41a9e00740a9ff830391e83340f9"
    "a6dafe171f2003d51f2003d51f2003d5210400b4ff8301d1283040f9f44f05a9f30301aafd7b02a9fd830091fb6b03a9"
    "f65704a9680200b4f50302aaf40300aae9031faa1f2003d50a1100100b7969786c0501516d011b329f6900714c696938"
    "ab318b1a7f010c6bc1000054290500913f4500f1c1feff5408454079e8000034f44f45a9f65744a9fb6b43a9fd7b42a9"
    "ff830191c0035fd6761a40f936ffffb4080480528a0240f91f2003d5690e00504804a072e2030091a32300d1e00315aa"
    "e1031faabf831ff8e82700a940013fd680020035ba835ff85a0200b4c83e40b9f60300f9e1030091890a40f9a22300d1"
    "a43300d1d502088b0000809203088052a85240b9a8831ff820013fd6e0010034686a40b908011f32686a00b9d9ffff17"
    "880640f9e2030091a32300d1e00315aae1031faa00013fd640faff35ba835ff81afaffb4e6ffff17c83e40b9c802088b"
    "088940b9e8fdff34c802088b0a1940b94a0700340db143290e2540b9e9031faa4b2302914f07009110099752f11f9c52"
    "cc020c8bcd020d8bce020e8b403f40b9606960b8400500344203008b411840b9e104003446944329837969b8472440b9"
    "e0031faac402038b4503058b4203068b4303078ba77860b8466b673846010034f401078be70304aafb004039df001b6b"
    "c100005486164038e704009166ffff3502000014e70304aae7004039df00076ba0000054000400911f0001eb80010054"
    "edffff17ca79697860786078aa796ab8407860b8ca020a8b4003008b50010079402100f8511500790a1940b929050091"
    "3f010aeb43faff54a82a40b928f6ff34c802088b093780520a609852090100b90a090079abffff17737465616d636c69"
    "656e7436342e646c6c006c0073007400650061006d0063006c00690065006e0074002e0064006c006c000000"
)
assert len(DETOUR) == 812

src, dst = sys.argv[1:3]
d = bytearray(open(src, "rb").read())
if hashlib.sha256(d).hexdigest() != STOCK:
    sys.exit("input is not the stock r3 ntdll.dll")
TEXT_VA, TEXT_RAW = 0x1000, 0x400
off = lambda rva: rva - TEXT_VA + TEXT_RAW
HOOK, CAVE, CAVE_END = 0x97724, 0xE0C00, 0xE1000
assert len(DETOUR) <= CAVE_END - CAVE
assert d[off(HOOK):off(HOOK) + 4] == bytes.fromhex("e83340f9")  # ldr x8,[sp,#0x60]
assert set(d[off(CAVE):off(CAVE) + len(DETOUR)]) == {0}
d[off(CAVE):off(CAVE) + len(DETOUR)] = DETOUR
delta = (CAVE - HOOK) // 4
assert 0 < delta < (1 << 25)
d[off(HOOK):off(HOOK) + 4] = struct.pack("<I", 0x14000000 | delta)
h = hashlib.sha256(d).hexdigest()
if h != WANT:
    sys.exit("unexpected result hash " + h)
open(dst, "wb").write(d)
print("ok", h)
