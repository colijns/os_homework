/* TEST ONLY: private GPR poisoner and register snapshots. */
#include <riscv.h>
    .text
    .option push
    .option norelax
    .balign 4
    .globl a_probe32
a_probe32:
    addi sp, sp, -128
    sd x1, 0(sp)
    sd x3, 8(sp)
    sd x4, 16(sp)
    sd x8, 24(sp)
    sd x9, 32(sp)
    sd x18, 40(sp)
    sd x19, 48(sp)
    sd x20, 56(sp)
    sd x21, 64(sp)
    sd x22, 72(sp)
    sd x23, 80(sp)
    sd x24, 88(sp)
    sd x25, 96(sp)
    sd x26, 104(sp)
    sd x27, 112(sp)
    la t0, a_expected
    sd sp, 16(t0)
    sd gp, 24(t0)
    sd tp, 32(t0)
    li x1, 0x1122334455667701
    li x5, 0x1122334455667705
    li x6, 0x1122334455667706
    li x7, 0x1122334455667707
    li x8, 0x1122334455667708
    li x9, 0x1122334455667709
    li x10, 0x112233445566770a
    li x11, 0x112233445566770b
    li x12, 0x112233445566770c
    li x13, 0x112233445566770d
    li x14, 0x112233445566770e
    li x15, 0x112233445566770f
    li x16, 0x1122334455667710
    li x17, 0x1122334455667711
    li x18, 0x1122334455667712
    li x19, 0x1122334455667713
    li x20, 0x1122334455667714
    li x21, 0x1122334455667715
    li x22, 0x1122334455667716
    li x23, 0x1122334455667717
    li x24, 0x1122334455667718
    li x25, 0x1122334455667719
    li x26, 0x112233445566771a
    li x27, 0x112233445566771b
    li x28, 0x112233445566771c
    li x29, 0x112233445566771d
    li x30, 0x112233445566771e
    li x31, 0x112233445566771f
    .globl a_break32
a_break32:
    .word 0x00100073
    .globl a_resume32
a_resume32:
    j .Lcapture
    .globl a_redirect32
a_redirect32:
    j .Lcapture
    .balign 4
    .globl a_probe16
a_probe16:
    addi sp, sp, -128
    sd x1, 0(sp)
    sd x3, 8(sp)
    sd x4, 16(sp)
    sd x8, 24(sp)
    sd x9, 32(sp)
    sd x18, 40(sp)
    sd x19, 48(sp)
    sd x20, 56(sp)
    sd x21, 64(sp)
    sd x22, 72(sp)
    sd x23, 80(sp)
    sd x24, 88(sp)
    sd x25, 96(sp)
    sd x26, 104(sp)
    sd x27, 112(sp)
    la t0, a_expected
    sd sp, 16(t0)
    sd gp, 24(t0)
    sd tp, 32(t0)
    li x1, 0x1122334455667701
    li x5, 0x1122334455667705
    li x6, 0x1122334455667706
    li x7, 0x1122334455667707
    li x8, 0x1122334455667708
    li x9, 0x1122334455667709
    li x10, 0x112233445566770a
    li x11, 0x112233445566770b
    li x12, 0x112233445566770c
    li x13, 0x112233445566770d
    li x14, 0x112233445566770e
    li x15, 0x112233445566770f
    li x16, 0x1122334455667710
    li x17, 0x1122334455667711
    li x18, 0x1122334455667712
    li x19, 0x1122334455667713
    li x20, 0x1122334455667714
    li x21, 0x1122334455667715
    li x22, 0x1122334455667716
    li x23, 0x1122334455667717
    li x24, 0x1122334455667718
    li x25, 0x1122334455667719
    li x26, 0x112233445566771a
    li x27, 0x112233445566771b
    li x28, 0x112233445566771c
    li x29, 0x112233445566771d
    li x30, 0x112233445566771e
    li x31, 0x112233445566771f
    .globl a_break16
a_break16:
    .2byte 0x9002
    .globl a_resume16
a_resume16:
    j .Lcapture
.Lcapture:
    csrw sscratch, t0
    la t0, a_observed
    sd x0, 0(t0)
    sd x1, 8(t0)
    sd x2, 16(t0)
    sd x3, 24(t0)
    sd x4, 32(t0)
    sd x6, 48(t0)
    sd x7, 56(t0)
    sd x8, 64(t0)
    sd x9, 72(t0)
    sd x10, 80(t0)
    sd x11, 88(t0)
    sd x12, 96(t0)
    sd x13, 104(t0)
    sd x14, 112(t0)
    sd x15, 120(t0)
    sd x16, 128(t0)
    sd x17, 136(t0)
    sd x18, 144(t0)
    sd x19, 152(t0)
    sd x20, 160(t0)
    sd x21, 168(t0)
    sd x22, 176(t0)
    sd x23, 184(t0)
    sd x24, 192(t0)
    sd x25, 200(t0)
    sd x26, 208(t0)
    sd x27, 216(t0)
    sd x28, 224(t0)
    sd x29, 232(t0)
    sd x30, 240(t0)
    sd x31, 248(t0)
    csrr t1, sscratch
    sd t1, 40(t0)
    csrw sscratch, zero
    csrr t1, sstatus
    la t0, a_after_status
    sd t1, 0(t0)
    csrr t1, sepc
    la t0, a_after_epc
    sd t1, 0(t0)
    csrr t1, sscratch
    la t0, a_after_scratch
    sd t1, 0(t0)
    ld x1, 0(sp)
    ld x3, 8(sp)
    ld x4, 16(sp)
    ld x8, 24(sp)
    ld x9, 32(sp)
    ld x18, 40(sp)
    ld x19, 48(sp)
    ld x20, 56(sp)
    ld x21, 64(sp)
    ld x22, 72(sp)
    ld x23, 80(sp)
    ld x24, 88(sp)
    ld x25, 96(sp)
    ld x26, 104(sp)
    ld x27, 112(sp)
    addi sp, sp, 128
    ret
    .balign 4
    .globl trap
trap:
    addi sp, sp, -16
    sd ra, 0(sp)
    call a_probe_handle
    ld ra, 0(sp)
    addi sp, sp, 16
    csrw sscratch, ra
    li x1, 0xdecafbad00000001
    li x3, 0xdecafbad00000003
    li x4, 0xdecafbad00000004
    li x5, 0xdecafbad00000005
    li x6, 0xdecafbad00000006
    li x7, 0xdecafbad00000007
    li x8, 0xdecafbad00000008
    li x9, 0xdecafbad00000009
    li x10, 0xdecafbad0000000a
    li x11, 0xdecafbad0000000b
    li x12, 0xdecafbad0000000c
    li x13, 0xdecafbad0000000d
    li x14, 0xdecafbad0000000e
    li x15, 0xdecafbad0000000f
    li x16, 0xdecafbad00000010
    li x17, 0xdecafbad00000011
    li x18, 0xdecafbad00000012
    li x19, 0xdecafbad00000013
    li x20, 0xdecafbad00000014
    li x21, 0xdecafbad00000015
    li x22, 0xdecafbad00000016
    li x23, 0xdecafbad00000017
    li x24, 0xdecafbad00000018
    li x25, 0xdecafbad00000019
    li x26, 0xdecafbad0000001a
    li x27, 0xdecafbad0000001b
    li x28, 0xdecafbad0000001c
    li x29, 0xdecafbad0000001d
    li x30, 0xdecafbad0000001e
    csrr t6, sscratch
    csrw sscratch, zero
    jr t6
    .option pop
