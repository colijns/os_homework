//LAB4 function3 2411276-林靖然
/* void switch_to(struct context *from, struct context *to);
 * 将旧线程的被调用者保存寄存器（ra、sp、s0-s11）保存到 from，
 * 从 to 恢复这些寄存器后返回到其保存的 ra（forkret），
 * 寄存器布局与 proc.h 中的 struct context 一致。 */
.text
.globl switch_to
switch_to:
    sd ra,   0(a0)
    sd sp,   8(a0)
    sd s0,  16(a0)
    sd s1,  24(a0)
    sd s2,  32(a0)
    sd s3,  40(a0)
    sd s4,  48(a0)
    sd s5,  56(a0)
    sd s6,  64(a0)
    sd s7,  72(a0)
    sd s8,  80(a0)
    sd s9,  88(a0)
    sd s10, 96(a0)
    sd s11, 104(a0)

    ld ra,   0(a1)
    ld sp,   8(a1)
    ld s0,  16(a1)
    ld s1,  24(a1)
    ld s2,  32(a1)
    ld s3,  40(a1)
    ld s4,  48(a1)
    ld s5,  56(a1)
    ld s6,  64(a1)
    ld s7,  72(a1)
    ld s8,  80(a1)
    ld s9,  88(a1)
    ld s10, 96(a1)
    ld s11, 104(a1)

    ret