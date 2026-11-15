    .text
    .globl tramp
    .align 4
tramp:
    sub sp, sp, #0xe0
    stp x0, x1, [sp]
    stp x2, x3, [sp, #0x10]
    stp x4, x5, [sp, #0x20]
    stp x6, x7, [sp, #0x30]
    stp x8, x9, [sp, #0x40]
    stp x10, x11, [sp, #0x50]
    stp x12, x13, [sp, #0x60]
    stp x14, x15, [sp, #0x70]
    stp x16, x17, [sp, #0x80]
    mrs x1, NZCV
    stp x18, x1, [sp, #0x90]
    str x30, [sp, #0xa0]
    adr x8, F_LdrGetDllHandle
    adr x9, F_LdrLoadDll
    stp x8, x9, [sp, #0xb0]
    adr x8, F_NtProtectVirtualMemory
    str x8, [sp, #0xc0]
    add x0, sp, #0xb0
    ldr x1, [sp]
    mov x2, x25
    bl worker
    ldr x30, [sp, #0xa0]
    ldp x18, x1, [sp, #0x90]
    msr NZCV, x1
    ldp x16, x17, [sp, #0x80]
    ldp x14, x15, [sp, #0x70]
    ldp x12, x13, [sp, #0x60]
    ldp x10, x11, [sp, #0x50]
    ldp x8, x9, [sp, #0x40]
    ldp x6, x7, [sp, #0x30]
    ldp x4, x5, [sp, #0x20]
    ldp x2, x3, [sp, #0x10]
    ldp x0, x1, [sp]
    add sp, sp, #0xe0
    ldr x8, [sp, #0x60]
    b RET_SITE
    .align 4
worker:
    cbz	x1, L138
    sub	sp, sp, #0x60
    ldr	x8, [x1, #0x60]
    stp	x20, x19, [sp, #0x50]
    mov	x19, x1
    stp	x29, x30, [sp, #0x20]
    add	x29, sp, #0x20
    stp	x27, x26, [sp, #0x30]
    stp	x22, x21, [sp, #0x40]
    cbz	x8, L124
    mov	x21, x2
    mov	x20, x0
    mov	x9, xzr
    nop
    adr	x10, str_ascii
Lf0:
    ldrh	w11, [x8, x9, lsl #1]
    sub	w12, w11, #0x41
    orr	w13, w11, #0x20
    cmp	w12, #0x1a
    ldrb	w12, [x10, x9]
    csel	w11, w13, w11, lo
    cmp	w11, w12
    b.ne	L124
    add	x9, x9, #0x1
    cmp	x9, #0x11
    b.ne	Lf0
    ldrh	w8, [x8, #0x22]
    cbz	w8, L13c
L124:
    ldp	x20, x19, [sp, #0x50]
    ldp	x22, x21, [sp, #0x40]
    ldp	x27, x26, [sp, #0x30]
    ldp	x29, x30, [sp, #0x20]
    add	sp, sp, #0x60
L138:
    ret
L13c:
    ldr	x22, [x19, #0x30]
    cbz	x22, L124
    mov	w8, #0x20
    ldr	x10, [x20]
    nop
    adr	x9, str_wide
    movk	w8, #0x22, lsl #16
    mov	x2, sp
    sub	x3, x29, #0x8
    mov	x0, x21
    mov	x1, xzr
    stur	xzr, [x29, #-0x8]
    stp	x8, x9, [sp]
    blr	x10
    cbnz	w0, L1c4
    ldur	x26, [x29, #-0x8]
    cbz	x26, L1c4
L180:
    ldr	w8, [x22, #0x3c]
    str	x22, [sp]
    mov	x1, sp
    ldr	x9, [x20, #0x10]
    sub	x2, x29, #0x8
    sub	x4, x29, #0xc
    add	x21, x22, x8
    mov	x0, #-0x1
    mov	w3, #0x40
    ldr	w8, [x21, #0x50]
    stur	x8, [x29, #-0x8]
    blr	x9
    cbz	w0, L1ec
L1b4:
    ldr	w8, [x19, #0x68]
    orr	w8, w8, #0x2
    str	w8, [x19, #0x68]
    b	L124
L1c4:
    ldr	x8, [x20, #0x8]
    mov	x2, sp
    sub	x3, x29, #0x8
    mov	x0, x21
    mov	x1, xzr
    blr	x8
    cbnz	w0, L124
    ldur	x26, [x29, #-0x8]
    cbz	x26, L124
    b	L180
L1ec:
    ldr	w8, [x22, #0x3c]
    add	x8, x22, x8
    ldr	w8, [x8, #0x88]
    cbz	w8, L1b4
    add	x8, x22, x8
    ldr	w10, [x8, #0x18]
    cbz	w10, L2ec
    ldp	w13, w12, [x8, #0x1c]
    ldr	w14, [x8, #0x24]
    mov	x9, xzr
    add	x11, x26, #0x88
    add	x15, x26, #0x1
    mov	w16, #0xb848
    mov	w17, #0xe0ff
    add	x12, x22, x12
    add	x13, x22, x13
    add	x14, x22, x14
L230:
    ldr	w0, [x26, #0x3c]
    ldr	w0, [x11, x0]
    cbz	w0, L2e0
    add	x2, x26, x0
    ldr	w1, [x2, #0x18]
    cbz	w1, L2e0
    ldp	w6, w5, [x2, #0x1c]
    ldr	w3, [x12, x9, lsl #2]
    ldr	w7, [x2, #0x24]
    mov	x0, xzr
    add	x4, x22, x3
    add	x5, x26, x5
    add	x2, x26, x6
    add	x3, x26, x7
L268:
    ldr	w7, [x5, x0, lsl #2]
    ldrb	w6, [x26, x7]
    cbz	w6, L298
    add	x20, x15, x7
    mov	x7, x4
L27c:
    ldrb	w27, [x7]
    cmp	w6, w27
    b.ne	L29c
    ldrb	w6, [x20], #0x1
    add	x7, x7, #0x1
    cbnz	w6, L27c
    b	L29c
L298:
    mov	x7, x4
L29c:
    ldrb	w7, [x7]
    cmp	w6, w7
    b.eq	L2b8
    add	x0, x0, #0x1
    cmp	x0, x1
    b.eq	L2e0
    b	L268
L2b8:
    ldrh	w10, [x14, x9, lsl #1]
    ldrh	w0, [x3, x0, lsl #1]
    ldr	w10, [x13, x10, lsl #2]
    ldr	w0, [x2, x0, lsl #2]
    add	x10, x22, x10
    add	x0, x26, x0
    strh	w16, [x10]
    stur	x0, [x10, #0x2]
    strh	w17, [x10, #0xa]
    ldr	w10, [x8, #0x18]
L2e0:
    add	x9, x9, #0x1
    cmp	x9, x10
    b.lo	L230
L2ec:
    ldr	w8, [x21, #0x28]
    cbz	w8, L1b4
    add	x8, x22, x8
    mov	w9, #0x1b8
    mov	w10, #0xc300
    str	w9, [x8]
    strh	w10, [x8, #0x4]
    b	L1b4

    .align 2
str_ascii:
    .asciz "steamclient64.dll"
    .align 1
str_wide:
    .short 0x6c,0x73,0x74,0x65,0x61,0x6d,0x63,0x6c,0x69,0x65,0x6e,0x74,0x2e,0x64,0x6c,0x6c,0
