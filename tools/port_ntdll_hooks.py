#!/usr/bin/env python3
"""Add Bridgeplay's Steam detour and our RtlVirtualUnwind2 NULL-arg fix to MacGameFix's CrossOver 27.0.0.41073 ntdll.dll.

usage: python3 -I port_ntdll_hooks.py MGF_ntdll.dll OUT_ntdll.dll

Why: Bridgeplay's launcher expects the runner's x86_64 ntdll to carry a hook in build_module() that calls
steamclient64.dll's exports over to lsteamclient.dll (the Steam bridge), and our FH runner also carries a fix
that stops RtlVirtualUnwind2 from writing through NULL optional arguments. MacGameFix's ntdll has neither
hook. It does contain the detour function itself (detour_build_module, the same logic as Bridgeplay's cave)
but nothing calls it, so we add only the call site.

Where to get the input: https://github.com/MathiasKowoll/MacGameFix at commit 881f3a96e2b73a18931d67f1f55f8f3d3ac26642,
file engine/modules/27.0.0.41073/x86_64-windows/ntdll.dll (sha256 below; GPL-3.0 repo, LGPL-2.1+ Wine module).
The output is bin/ntdll-MGF-winecx.dll (sha256 840c31cc...bfe7); this script checks both hashes.

Part of fh6-mac-fix (sliver-exes, GPL-3.0); see bin/CREDITS.md.

Credits: detour logic and function table layout from Bridgeplay (raymondchins, GPL-3.0); the RtlVirtualUnwind2 cave is
our patch_unwind_winecx.pl re-targeted; ntdll.dll is MacGameFix's (MathiasKowoll, GPL-3.0, commit 881f3a96) build of
CodeWeavers CrossOver / Wine (LGPL-2.1+) 27.0.0.41073. All RVAs equal file offsets in this image (.text raw = VA = 0x1000).
Both caves live in the 0xCC slack at the end of .text (RVA 0x81715..0x82000); the scratch qword lives in the zero tail
of the last .data page.
"""
import hashlib, struct, sys

IN_SHA = "1705a2489f759893865b1ea45343a066184308eb7826eb830cde56fc148fc02d"
OUT_SHA = "840c31ccda0d036de26e520946c276f1acb9032b93024b6c40b65faf0bbbbfe7"
src, dst = sys.argv[1:3]
d = bytearray(open(src, "rb").read())
if hashlib.sha256(d).hexdigest() != IN_SHA:
    sys.exit("input is not the MacGameFix 41073 ntdll.dll")

# Symbol RVAs from the image's own COFF symbols (symbol value + 0x1000 = RVA) and disassembly
DETOUR   = 0x33f00    # detour_build_module(funcs, wm, load_path)
LDRGET   = 0x36930    # LdrGetDllHandle
LDRLOAD  = 0x34320    # LdrLoadDll
ZWPROT   = 0x5d88c    # ZwProtectVirtualMemory
BM_HOOK  = 0x3c18c    # build_module: mov r14,rax ; mov rax,[rbp+0x90]  (10 bytes) right after alloc_module succeeded
BM_BACK  = 0x3c196
UW_HOOK  = 0x6e3b0    # RtlVirtualUnwind2 entry: push r15 ; push r14 ; push r13
UW_BACK  = 0x6e3b6
CAVE1, CAVE2 = 0x81800, 0x81900
SCRATCH  = 0x26bcf00  # inside .data VirtualSize round-up page tail (.data ends 0x26bce9c, page ends 0x26bd000)

bm_want = bytes.fromhex("4989c6488b8590000000")
uw_want = bytes.fromhex("415741564155")
assert d[BM_HOOK:BM_HOOK+10] == bm_want, "build_module hook site mismatch"
assert d[UW_HOOK:UW_HOOK+6] == uw_want, "RtlVirtualUnwind2 hook site mismatch"
assert set(d[CAVE1:CAVE1+0x100]) == {0xCC} and set(d[CAVE2:CAVE2+0x80]) == {0xCC}, "slack not free"
assert CAVE2 + 0x80 <= 0x82000

def rel(target, next_ip): return struct.pack("<i", target - next_ip)

# --- cave 1: replay mov r14,rax, call detour_build_module(&{LdrGetDllHandle,LdrLoadDll,ZwProtect}, wm, load_path), replay mov rax,[rbp+0x90]
c = bytearray()
def emit(b): c.extend(b)
def lea_rax(target):
    emit(bytes.fromhex("488d05")); emit(rel(target, CAVE1 + len(c) + 4))
emit(bm_want[:3])                                   # mov r14, rax
emit(bytes.fromhex("505152" "4150" "4151" "4152" "4153"))   # push rax,rcx,rdx,r8,r9,r10,r11
emit(bytes.fromhex("4989e2"))                       # mov r10, rsp
emit(bytes.fromhex("4883e4f0"))                     # and rsp, -16
emit(bytes.fromhex("4883ec60"))                     # sub rsp, 0x60
emit(bytes.fromhex("4c89542458"))                   # mov [rsp+0x58], r10
lea_rax(LDRGET);  emit(bytes.fromhex("4889442438")) # mov [rsp+0x38], rax
lea_rax(LDRLOAD); emit(bytes.fromhex("4889442440")) # mov [rsp+0x40], rax
lea_rax(ZWPROT);  emit(bytes.fromhex("4889442448")) # mov [rsp+0x48], rax
emit(bytes.fromhex("488d4c2438"))                   # lea rcx, [rsp+0x38]
emit(bytes.fromhex("4c89f2"))                       # mov rdx, r14        (wm)
emit(bytes.fromhex("4c8b45d8"))                     # mov r8, [rbp-0x28]  (load_path)
emit(b"\xe8"); emit(rel(DETOUR, CAVE1 + len(c) + 4))  # call detour_build_module
emit(bytes.fromhex("488b642458"))                   # mov rsp, [rsp+0x58]
emit(bytes.fromhex("415b" "415a" "4159" "4158" "5a" "59" "58"))  # pop r11,r10,r9,r8,rdx,rcx,rax
emit(bm_want[3:])                                   # mov rax, [rbp+0x90]
emit(b"\xe9"); emit(rel(BM_BACK, CAVE1 + len(c) + 4))  # jmp back
cave1 = bytes(c)

# --- cave 2: replace NULL stack args 6,7,8,12 of RtlVirtualUnwind2 with a private scratch qword, replay 3 pushes
c = bytearray()
emit(bytes.fromhex("4c8d15")); emit(rel(SCRATCH, CAVE2 + len(c) + 4))    # lea r10,[rip+scratch]
for o in (0x30, 0x38, 0x40, 0x60):
    emit(bytes.fromhex("48837c24") + bytes([o, 0]))   # cmp qword [rsp+o], 0
    emit(bytes.fromhex("7505"))                       # jne +5
    emit(bytes.fromhex("4c895424") + bytes([o]))      # mov [rsp+o], r10
emit(uw_want)
emit(b"\xe9"); emit(rel(UW_BACK, CAVE2 + len(c) + 4))
cave2 = bytes(c)
assert len(cave2) == 0x46

pe = struct.unpack_from("<I", d, 0x3c)[0]
# .data scratch must be inside the last .data page and past VirtualSize
nsec = struct.unpack_from("<H", d, pe + 6)[0]; so = struct.unpack_from("<H", d, pe + 20)[0]
for i in range(nsec):
    o = pe + 24 + so + i * 40
    if d[o:o+5] == b".data":
        vs, va = struct.unpack_from("<II", d, o + 8)
        assert va + vs <= SCRATCH and SCRATCH + 8 <= ((va + vs + 0xfff) & ~0xfff), "scratch not in .data tail"

d[CAVE1:CAVE1+len(cave1)] = cave1
d[CAVE2:CAVE2+len(cave2)] = cave2
d[BM_HOOK:BM_HOOK+10] = b"\xe9" + rel(CAVE1, BM_HOOK + 5) + b"\x90" * 5
d[UW_HOOK:UW_HOOK+6] = b"\xe9" + rel(CAVE2, UW_HOOK + 5) + b"\x90"
if hashlib.sha256(d).hexdigest() != OUT_SHA:
    sys.exit("output hash differs from the shipped bin/ntdll-MGF-winecx.dll; nothing written")
open(dst, "wb").write(d)
print("ok", hashlib.sha256(d).hexdigest(), "cave1", len(cave1), "bytes at 0x%x, cave2 %d bytes at 0x%x" % (CAVE1, len(cave2), CAVE2))
