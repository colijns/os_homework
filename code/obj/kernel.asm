
bin/kernel:     file format elf64-littleriscv


Disassembly of section .text:

ffffffffc0200000 <kern_entry>:
    .globl kern_entry
kern_entry:
    # a0: hartid
    # a1: dtb physical address
    # save hartid and dtb address
    la t0, boot_hartid
ffffffffc0200000:	00005297          	auipc	t0,0x5
ffffffffc0200004:	00028293          	mv	t0,t0
    sd a0, 0(t0)
ffffffffc0200008:	00a2b023          	sd	a0,0(t0) # ffffffffc0205000 <boot_hartid>
    la t0, boot_dtb
ffffffffc020000c:	00005297          	auipc	t0,0x5
ffffffffc0200010:	ffc28293          	addi	t0,t0,-4 # ffffffffc0205008 <boot_dtb>
    sd a1, 0(t0)
ffffffffc0200014:	00b2b023          	sd	a1,0(t0)

    # t0 := 三级页表的虚拟地址
    lui     t0, %hi(boot_page_table_sv39)
ffffffffc0200018:	c02042b7          	lui	t0,0xc0204
    # t1 := 0xffffffff40000000 即虚实映射偏移量
    li      t1, 0xffffffffc0000000 - 0x80000000
ffffffffc020001c:	ffd0031b          	addiw	t1,zero,-3
ffffffffc0200020:	037a                	slli	t1,t1,0x1e
    # t0 减去虚实映射偏移量 0xffffffff40000000，变为三级页表的物理地址
    sub     t0, t0, t1
ffffffffc0200022:	406282b3          	sub	t0,t0,t1
    # t0 >>= 12，变为三级页表的物理页号
    srli    t0, t0, 12
ffffffffc0200026:	00c2d293          	srli	t0,t0,0xc

    # t1 := 8 << 60，设置 satp 的 MODE 字段为 Sv39
    li      t1, 8 << 60
ffffffffc020002a:	fff0031b          	addiw	t1,zero,-1
ffffffffc020002e:	137e                	slli	t1,t1,0x3f
    # 将刚才计算出的预设三级页表物理页号附加到 satp 中
    or      t0, t0, t1
ffffffffc0200030:	0062e2b3          	or	t0,t0,t1
    # 将算出的 t0(即新的MODE|页表基址物理页号) 覆盖到 satp 中
    csrw    satp, t0
ffffffffc0200034:	18029073          	csrw	satp,t0
    # 使用 sfence.vma 指令刷新 TLB
    sfence.vma
ffffffffc0200038:	12000073          	sfence.vma
    # 从此，我们给内核搭建出了一个完美的虚拟内存空间！
    #nop # 可能映射的位置有些bug。。插入一个nop
    
    # 我们在虚拟内存空间中：随意将 sp 设置为虚拟地址！
    lui sp, %hi(bootstacktop)
ffffffffc020003c:	c0204137          	lui	sp,0xc0204

    # 我们在虚拟内存空间中：随意跳转到虚拟地址！
    # 跳转到 kern_init
    lui t0, %hi(kern_init)
ffffffffc0200040:	c02002b7          	lui	t0,0xc0200
    addi t0, t0, %lo(kern_init)
ffffffffc0200044:	0d828293          	addi	t0,t0,216 # ffffffffc02000d8 <kern_init>
    jr t0
ffffffffc0200048:	8282                	jr	t0

ffffffffc020004a <print_kerninfo>:
/* *
 * print_kerninfo - print the information about kernel, including the location
 * of kernel entry, the start addresses of data and text segements, the start
 * address of free memory and how many memory that kernel has used.
 * */
void print_kerninfo(void) {
ffffffffc020004a:	1141                	addi	sp,sp,-16
    extern char etext[], edata[], end[];
    cprintf("Special kernel symbols:\n");
ffffffffc020004c:	00001517          	auipc	a0,0x1
ffffffffc0200050:	47c50513          	addi	a0,a0,1148 # ffffffffc02014c8 <etext+0x2>
void print_kerninfo(void) {
ffffffffc0200054:	e406                	sd	ra,8(sp)
    cprintf("Special kernel symbols:\n");
ffffffffc0200056:	0f6000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  entry  0x%016lx (virtual)\n", (uintptr_t)kern_init);
ffffffffc020005a:	00000597          	auipc	a1,0x0
ffffffffc020005e:	07e58593          	addi	a1,a1,126 # ffffffffc02000d8 <kern_init>
ffffffffc0200062:	00001517          	auipc	a0,0x1
ffffffffc0200066:	48650513          	addi	a0,a0,1158 # ffffffffc02014e8 <etext+0x22>
ffffffffc020006a:	0e2000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  etext  0x%016lx (virtual)\n", etext);
ffffffffc020006e:	00001597          	auipc	a1,0x1
ffffffffc0200072:	45858593          	addi	a1,a1,1112 # ffffffffc02014c6 <etext>
ffffffffc0200076:	00001517          	auipc	a0,0x1
ffffffffc020007a:	49250513          	addi	a0,a0,1170 # ffffffffc0201508 <etext+0x42>
ffffffffc020007e:	0ce000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  edata  0x%016lx (virtual)\n", edata);
ffffffffc0200082:	00005597          	auipc	a1,0x5
ffffffffc0200086:	f9658593          	addi	a1,a1,-106 # ffffffffc0205018 <free_area>
ffffffffc020008a:	00001517          	auipc	a0,0x1
ffffffffc020008e:	49e50513          	addi	a0,a0,1182 # ffffffffc0201528 <etext+0x62>
ffffffffc0200092:	0ba000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("  end    0x%016lx (virtual)\n", end);
ffffffffc0200096:	00005597          	auipc	a1,0x5
ffffffffc020009a:	1b258593          	addi	a1,a1,434 # ffffffffc0205248 <end>
ffffffffc020009e:	00001517          	auipc	a0,0x1
ffffffffc02000a2:	4aa50513          	addi	a0,a0,1194 # ffffffffc0201548 <etext+0x82>
ffffffffc02000a6:	0a6000ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("Kernel executable memory footprint: %dKB\n",
            (end - (char*)kern_init + 1023) / 1024);
ffffffffc02000aa:	00005597          	auipc	a1,0x5
ffffffffc02000ae:	59d58593          	addi	a1,a1,1437 # ffffffffc0205647 <end+0x3ff>
ffffffffc02000b2:	00000797          	auipc	a5,0x0
ffffffffc02000b6:	02678793          	addi	a5,a5,38 # ffffffffc02000d8 <kern_init>
ffffffffc02000ba:	40f587b3          	sub	a5,a1,a5
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000be:	43f7d593          	srai	a1,a5,0x3f
}
ffffffffc02000c2:	60a2                	ld	ra,8(sp)
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000c4:	3ff5f593          	andi	a1,a1,1023
ffffffffc02000c8:	95be                	add	a1,a1,a5
ffffffffc02000ca:	85a9                	srai	a1,a1,0xa
ffffffffc02000cc:	00001517          	auipc	a0,0x1
ffffffffc02000d0:	49c50513          	addi	a0,a0,1180 # ffffffffc0201568 <etext+0xa2>
}
ffffffffc02000d4:	0141                	addi	sp,sp,16
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02000d6:	a89d                	j	ffffffffc020014c <cprintf>

ffffffffc02000d8 <kern_init>:

int kern_init(void) {
    extern char edata[], end[];
    memset(edata, 0, end - edata);
ffffffffc02000d8:	00005517          	auipc	a0,0x5
ffffffffc02000dc:	f4050513          	addi	a0,a0,-192 # ffffffffc0205018 <free_area>
ffffffffc02000e0:	00005617          	auipc	a2,0x5
ffffffffc02000e4:	16860613          	addi	a2,a2,360 # ffffffffc0205248 <end>
int kern_init(void) {
ffffffffc02000e8:	1141                	addi	sp,sp,-16
    memset(edata, 0, end - edata);
ffffffffc02000ea:	8e09                	sub	a2,a2,a0
ffffffffc02000ec:	4581                	li	a1,0
int kern_init(void) {
ffffffffc02000ee:	e406                	sd	ra,8(sp)
    memset(edata, 0, end - edata);
ffffffffc02000f0:	3c4010ef          	jal	ra,ffffffffc02014b4 <memset>
    dtb_init();
ffffffffc02000f4:	12c000ef          	jal	ra,ffffffffc0200220 <dtb_init>
    cons_init();  // init the console
ffffffffc02000f8:	11e000ef          	jal	ra,ffffffffc0200216 <cons_init>
    const char *message = "(THU.CST) os is loading ...\0";
    //cprintf("%s\n\n", message);
    cputs(message);
ffffffffc02000fc:	00001517          	auipc	a0,0x1
ffffffffc0200100:	49c50513          	addi	a0,a0,1180 # ffffffffc0201598 <etext+0xd2>
ffffffffc0200104:	07e000ef          	jal	ra,ffffffffc0200182 <cputs>

    print_kerninfo();
ffffffffc0200108:	f43ff0ef          	jal	ra,ffffffffc020004a <print_kerninfo>

    // grade_backtrace();
    pmm_init();  // init physical memory management
ffffffffc020010c:	511000ef          	jal	ra,ffffffffc0200e1c <pmm_init>

    /* do nothing */
    while (1)
ffffffffc0200110:	a001                	j	ffffffffc0200110 <kern_init+0x38>

ffffffffc0200112 <cputch>:
/* *
 * cputch - writes a single character @c to stdout, and it will
 * increace the value of counter pointed by @cnt.
 * */
static void
cputch(int c, int *cnt) {
ffffffffc0200112:	1141                	addi	sp,sp,-16
ffffffffc0200114:	e022                	sd	s0,0(sp)
ffffffffc0200116:	e406                	sd	ra,8(sp)
ffffffffc0200118:	842e                	mv	s0,a1
    cons_putc(c);
ffffffffc020011a:	0fe000ef          	jal	ra,ffffffffc0200218 <cons_putc>
    (*cnt) ++;
ffffffffc020011e:	401c                	lw	a5,0(s0)
}
ffffffffc0200120:	60a2                	ld	ra,8(sp)
    (*cnt) ++;
ffffffffc0200122:	2785                	addiw	a5,a5,1
ffffffffc0200124:	c01c                	sw	a5,0(s0)
}
ffffffffc0200126:	6402                	ld	s0,0(sp)
ffffffffc0200128:	0141                	addi	sp,sp,16
ffffffffc020012a:	8082                	ret

ffffffffc020012c <vcprintf>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want cprintf() instead.
 * */
int
vcprintf(const char *fmt, va_list ap) {
ffffffffc020012c:	1101                	addi	sp,sp,-32
ffffffffc020012e:	862a                	mv	a2,a0
ffffffffc0200130:	86ae                	mv	a3,a1
    int cnt = 0;
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc0200132:	00000517          	auipc	a0,0x0
ffffffffc0200136:	fe050513          	addi	a0,a0,-32 # ffffffffc0200112 <cputch>
ffffffffc020013a:	006c                	addi	a1,sp,12
vcprintf(const char *fmt, va_list ap) {
ffffffffc020013c:	ec06                	sd	ra,24(sp)
    int cnt = 0;
ffffffffc020013e:	c602                	sw	zero,12(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc0200140:	75f000ef          	jal	ra,ffffffffc020109e <vprintfmt>
    return cnt;
}
ffffffffc0200144:	60e2                	ld	ra,24(sp)
ffffffffc0200146:	4532                	lw	a0,12(sp)
ffffffffc0200148:	6105                	addi	sp,sp,32
ffffffffc020014a:	8082                	ret

ffffffffc020014c <cprintf>:
 *
 * The return value is the number of characters which would be
 * written to stdout.
 * */
int
cprintf(const char *fmt, ...) {
ffffffffc020014c:	711d                	addi	sp,sp,-96
    va_list ap;
    int cnt;
    va_start(ap, fmt);
ffffffffc020014e:	02810313          	addi	t1,sp,40 # ffffffffc0204028 <boot_page_table_sv39+0x28>
cprintf(const char *fmt, ...) {
ffffffffc0200152:	8e2a                	mv	t3,a0
ffffffffc0200154:	f42e                	sd	a1,40(sp)
ffffffffc0200156:	f832                	sd	a2,48(sp)
ffffffffc0200158:	fc36                	sd	a3,56(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc020015a:	00000517          	auipc	a0,0x0
ffffffffc020015e:	fb850513          	addi	a0,a0,-72 # ffffffffc0200112 <cputch>
ffffffffc0200162:	004c                	addi	a1,sp,4
ffffffffc0200164:	869a                	mv	a3,t1
ffffffffc0200166:	8672                	mv	a2,t3
cprintf(const char *fmt, ...) {
ffffffffc0200168:	ec06                	sd	ra,24(sp)
ffffffffc020016a:	e0ba                	sd	a4,64(sp)
ffffffffc020016c:	e4be                	sd	a5,72(sp)
ffffffffc020016e:	e8c2                	sd	a6,80(sp)
ffffffffc0200170:	ecc6                	sd	a7,88(sp)
    va_start(ap, fmt);
ffffffffc0200172:	e41a                	sd	t1,8(sp)
    int cnt = 0;
ffffffffc0200174:	c202                	sw	zero,4(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc0200176:	729000ef          	jal	ra,ffffffffc020109e <vprintfmt>
    cnt = vcprintf(fmt, ap);
    va_end(ap);
    return cnt;
}
ffffffffc020017a:	60e2                	ld	ra,24(sp)
ffffffffc020017c:	4512                	lw	a0,4(sp)
ffffffffc020017e:	6125                	addi	sp,sp,96
ffffffffc0200180:	8082                	ret

ffffffffc0200182 <cputs>:
/* *
 * cputs- writes the string pointed by @str to stdout and
 * appends a newline character.
 * */
int
cputs(const char *str) {
ffffffffc0200182:	1101                	addi	sp,sp,-32
ffffffffc0200184:	e822                	sd	s0,16(sp)
ffffffffc0200186:	ec06                	sd	ra,24(sp)
ffffffffc0200188:	e426                	sd	s1,8(sp)
ffffffffc020018a:	842a                	mv	s0,a0
    int cnt = 0;
    char c;
    while ((c = *str ++) != '\0') {
ffffffffc020018c:	00054503          	lbu	a0,0(a0)
ffffffffc0200190:	c51d                	beqz	a0,ffffffffc02001be <cputs+0x3c>
ffffffffc0200192:	0405                	addi	s0,s0,1
ffffffffc0200194:	4485                	li	s1,1
ffffffffc0200196:	9c81                	subw	s1,s1,s0
    cons_putc(c);
ffffffffc0200198:	080000ef          	jal	ra,ffffffffc0200218 <cons_putc>
    while ((c = *str ++) != '\0') {
ffffffffc020019c:	00044503          	lbu	a0,0(s0)
ffffffffc02001a0:	008487bb          	addw	a5,s1,s0
ffffffffc02001a4:	0405                	addi	s0,s0,1
ffffffffc02001a6:	f96d                	bnez	a0,ffffffffc0200198 <cputs+0x16>
    (*cnt) ++;
ffffffffc02001a8:	0017841b          	addiw	s0,a5,1
    cons_putc(c);
ffffffffc02001ac:	4529                	li	a0,10
ffffffffc02001ae:	06a000ef          	jal	ra,ffffffffc0200218 <cons_putc>
        cputch(c, &cnt);
    }
    cputch('\n', &cnt);
    return cnt;
}
ffffffffc02001b2:	60e2                	ld	ra,24(sp)
ffffffffc02001b4:	8522                	mv	a0,s0
ffffffffc02001b6:	6442                	ld	s0,16(sp)
ffffffffc02001b8:	64a2                	ld	s1,8(sp)
ffffffffc02001ba:	6105                	addi	sp,sp,32
ffffffffc02001bc:	8082                	ret
    while ((c = *str ++) != '\0') {
ffffffffc02001be:	4405                	li	s0,1
ffffffffc02001c0:	b7f5                	j	ffffffffc02001ac <cputs+0x2a>

ffffffffc02001c2 <__panic>:
 * __panic - __panic is called on unresolvable fatal errors. it prints
 * "panic: 'message'", and then enters the kernel monitor.
 * */
void
__panic(const char *file, int line, const char *fmt, ...) {
    if (is_panic) {
ffffffffc02001c2:	00005317          	auipc	t1,0x5
ffffffffc02001c6:	03630313          	addi	t1,t1,54 # ffffffffc02051f8 <is_panic>
ffffffffc02001ca:	00032e03          	lw	t3,0(t1)
__panic(const char *file, int line, const char *fmt, ...) {
ffffffffc02001ce:	715d                	addi	sp,sp,-80
ffffffffc02001d0:	ec06                	sd	ra,24(sp)
ffffffffc02001d2:	e822                	sd	s0,16(sp)
ffffffffc02001d4:	f436                	sd	a3,40(sp)
ffffffffc02001d6:	f83a                	sd	a4,48(sp)
ffffffffc02001d8:	fc3e                	sd	a5,56(sp)
ffffffffc02001da:	e0c2                	sd	a6,64(sp)
ffffffffc02001dc:	e4c6                	sd	a7,72(sp)
    if (is_panic) {
ffffffffc02001de:	000e0363          	beqz	t3,ffffffffc02001e4 <__panic+0x22>
    vcprintf(fmt, ap);
    cprintf("\n");
    va_end(ap);

panic_dead:
    while (1) {
ffffffffc02001e2:	a001                	j	ffffffffc02001e2 <__panic+0x20>
    is_panic = 1;
ffffffffc02001e4:	4785                	li	a5,1
ffffffffc02001e6:	00f32023          	sw	a5,0(t1)
    va_start(ap, fmt);
ffffffffc02001ea:	8432                	mv	s0,a2
ffffffffc02001ec:	103c                	addi	a5,sp,40
    cprintf("kernel panic at %s:%d:\n    ", file, line);
ffffffffc02001ee:	862e                	mv	a2,a1
ffffffffc02001f0:	85aa                	mv	a1,a0
ffffffffc02001f2:	00001517          	auipc	a0,0x1
ffffffffc02001f6:	3c650513          	addi	a0,a0,966 # ffffffffc02015b8 <etext+0xf2>
    va_start(ap, fmt);
ffffffffc02001fa:	e43e                	sd	a5,8(sp)
    cprintf("kernel panic at %s:%d:\n    ", file, line);
ffffffffc02001fc:	f51ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    vcprintf(fmt, ap);
ffffffffc0200200:	65a2                	ld	a1,8(sp)
ffffffffc0200202:	8522                	mv	a0,s0
ffffffffc0200204:	f29ff0ef          	jal	ra,ffffffffc020012c <vcprintf>
    cprintf("\n");
ffffffffc0200208:	00001517          	auipc	a0,0x1
ffffffffc020020c:	38850513          	addi	a0,a0,904 # ffffffffc0201590 <etext+0xca>
ffffffffc0200210:	f3dff0ef          	jal	ra,ffffffffc020014c <cprintf>
ffffffffc0200214:	b7f9                	j	ffffffffc02001e2 <__panic+0x20>

ffffffffc0200216 <cons_init>:

/* serial_intr - try to feed input characters from serial port */
void serial_intr(void) {}

/* cons_init - initializes the console devices */
void cons_init(void) {}
ffffffffc0200216:	8082                	ret

ffffffffc0200218 <cons_putc>:

/* cons_putc - print a single character @c to console devices */
void cons_putc(int c) { sbi_console_putchar((unsigned char)c); }
ffffffffc0200218:	0ff57513          	zext.b	a0,a0
ffffffffc020021c:	2040106f          	j	ffffffffc0201420 <sbi_console_putchar>

ffffffffc0200220 <dtb_init>:

// 保存解析出的系统物理内存信息
static uint64_t memory_base = 0;
static uint64_t memory_size = 0;

void dtb_init(void) {
ffffffffc0200220:	7119                	addi	sp,sp,-128
    cprintf("DTB Init\n");
ffffffffc0200222:	00001517          	auipc	a0,0x1
ffffffffc0200226:	3b650513          	addi	a0,a0,950 # ffffffffc02015d8 <etext+0x112>
void dtb_init(void) {
ffffffffc020022a:	fc86                	sd	ra,120(sp)
ffffffffc020022c:	f8a2                	sd	s0,112(sp)
ffffffffc020022e:	e8d2                	sd	s4,80(sp)
ffffffffc0200230:	f4a6                	sd	s1,104(sp)
ffffffffc0200232:	f0ca                	sd	s2,96(sp)
ffffffffc0200234:	ecce                	sd	s3,88(sp)
ffffffffc0200236:	e4d6                	sd	s5,72(sp)
ffffffffc0200238:	e0da                	sd	s6,64(sp)
ffffffffc020023a:	fc5e                	sd	s7,56(sp)
ffffffffc020023c:	f862                	sd	s8,48(sp)
ffffffffc020023e:	f466                	sd	s9,40(sp)
ffffffffc0200240:	f06a                	sd	s10,32(sp)
ffffffffc0200242:	ec6e                	sd	s11,24(sp)
    cprintf("DTB Init\n");
ffffffffc0200244:	f09ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("HartID: %ld\n", boot_hartid);
ffffffffc0200248:	00005597          	auipc	a1,0x5
ffffffffc020024c:	db85b583          	ld	a1,-584(a1) # ffffffffc0205000 <boot_hartid>
ffffffffc0200250:	00001517          	auipc	a0,0x1
ffffffffc0200254:	39850513          	addi	a0,a0,920 # ffffffffc02015e8 <etext+0x122>
ffffffffc0200258:	ef5ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("DTB Address: 0x%lx\n", boot_dtb);
ffffffffc020025c:	00005417          	auipc	s0,0x5
ffffffffc0200260:	dac40413          	addi	s0,s0,-596 # ffffffffc0205008 <boot_dtb>
ffffffffc0200264:	600c                	ld	a1,0(s0)
ffffffffc0200266:	00001517          	auipc	a0,0x1
ffffffffc020026a:	39250513          	addi	a0,a0,914 # ffffffffc02015f8 <etext+0x132>
ffffffffc020026e:	edfff0ef          	jal	ra,ffffffffc020014c <cprintf>
    
    if (boot_dtb == 0) {
ffffffffc0200272:	00043a03          	ld	s4,0(s0)
        cprintf("Error: DTB address is null\n");
ffffffffc0200276:	00001517          	auipc	a0,0x1
ffffffffc020027a:	39a50513          	addi	a0,a0,922 # ffffffffc0201610 <etext+0x14a>
    if (boot_dtb == 0) {
ffffffffc020027e:	120a0463          	beqz	s4,ffffffffc02003a6 <dtb_init+0x186>
        return;
    }
    
    // 转换为虚拟地址
    uintptr_t dtb_vaddr = boot_dtb + PHYSICAL_MEMORY_OFFSET;
ffffffffc0200282:	57f5                	li	a5,-3
ffffffffc0200284:	07fa                	slli	a5,a5,0x1e
ffffffffc0200286:	00fa0733          	add	a4,s4,a5
    const struct fdt_header *header = (const struct fdt_header *)dtb_vaddr;
    
    // 验证DTB
    uint32_t magic = fdt32_to_cpu(header->magic);
ffffffffc020028a:	431c                	lw	a5,0(a4)
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020028c:	00ff0637          	lui	a2,0xff0
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200290:	6b41                	lui	s6,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200292:	0087d59b          	srliw	a1,a5,0x8
ffffffffc0200296:	0187969b          	slliw	a3,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020029a:	0187d51b          	srliw	a0,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020029e:	0105959b          	slliw	a1,a1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002a2:	0107d79b          	srliw	a5,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002a6:	8df1                	and	a1,a1,a2
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002a8:	8ec9                	or	a3,a3,a0
ffffffffc02002aa:	0087979b          	slliw	a5,a5,0x8
ffffffffc02002ae:	1b7d                	addi	s6,s6,-1
ffffffffc02002b0:	0167f7b3          	and	a5,a5,s6
ffffffffc02002b4:	8dd5                	or	a1,a1,a3
ffffffffc02002b6:	8ddd                	or	a1,a1,a5
    if (magic != 0xd00dfeed) {
ffffffffc02002b8:	d00e07b7          	lui	a5,0xd00e0
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002bc:	2581                	sext.w	a1,a1
    if (magic != 0xd00dfeed) {
ffffffffc02002be:	eed78793          	addi	a5,a5,-275 # ffffffffd00dfeed <end+0xfedaca5>
ffffffffc02002c2:	10f59163          	bne	a1,a5,ffffffffc02003c4 <dtb_init+0x1a4>
        return;
    }
    
    // 提取内存信息
    uint64_t mem_base, mem_size;
    if (extract_memory_info(dtb_vaddr, header, &mem_base, &mem_size) == 0) {
ffffffffc02002c6:	471c                	lw	a5,8(a4)
ffffffffc02002c8:	4754                	lw	a3,12(a4)
    int in_memory_node = 0;
ffffffffc02002ca:	4c81                	li	s9,0
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002cc:	0087d59b          	srliw	a1,a5,0x8
ffffffffc02002d0:	0086d51b          	srliw	a0,a3,0x8
ffffffffc02002d4:	0186941b          	slliw	s0,a3,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002d8:	0186d89b          	srliw	a7,a3,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002dc:	01879a1b          	slliw	s4,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002e0:	0187d81b          	srliw	a6,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002e4:	0105151b          	slliw	a0,a0,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002e8:	0106d69b          	srliw	a3,a3,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002ec:	0105959b          	slliw	a1,a1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002f0:	0107d79b          	srliw	a5,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02002f4:	8d71                	and	a0,a0,a2
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02002f6:	01146433          	or	s0,s0,a7
ffffffffc02002fa:	0086969b          	slliw	a3,a3,0x8
ffffffffc02002fe:	010a6a33          	or	s4,s4,a6
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200302:	8e6d                	and	a2,a2,a1
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200304:	0087979b          	slliw	a5,a5,0x8
ffffffffc0200308:	8c49                	or	s0,s0,a0
ffffffffc020030a:	0166f6b3          	and	a3,a3,s6
ffffffffc020030e:	00ca6a33          	or	s4,s4,a2
ffffffffc0200312:	0167f7b3          	and	a5,a5,s6
ffffffffc0200316:	8c55                	or	s0,s0,a3
ffffffffc0200318:	00fa6a33          	or	s4,s4,a5
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc020031c:	1402                	slli	s0,s0,0x20
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc020031e:	1a02                	slli	s4,s4,0x20
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc0200320:	9001                	srli	s0,s0,0x20
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc0200322:	020a5a13          	srli	s4,s4,0x20
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc0200326:	943a                	add	s0,s0,a4
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc0200328:	9a3a                	add	s4,s4,a4
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020032a:	00ff0c37          	lui	s8,0xff0
        switch (token) {
ffffffffc020032e:	4b8d                	li	s7,3
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc0200330:	00001917          	auipc	s2,0x1
ffffffffc0200334:	33090913          	addi	s2,s2,816 # ffffffffc0201660 <etext+0x19a>
ffffffffc0200338:	49bd                	li	s3,15
        switch (token) {
ffffffffc020033a:	4d91                	li	s11,4
ffffffffc020033c:	4d05                	li	s10,1
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc020033e:	00001497          	auipc	s1,0x1
ffffffffc0200342:	31a48493          	addi	s1,s1,794 # ffffffffc0201658 <etext+0x192>
        uint32_t token = fdt32_to_cpu(*struct_ptr++);
ffffffffc0200346:	000a2703          	lw	a4,0(s4)
ffffffffc020034a:	004a0a93          	addi	s5,s4,4
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020034e:	0087569b          	srliw	a3,a4,0x8
ffffffffc0200352:	0187179b          	slliw	a5,a4,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200356:	0187561b          	srliw	a2,a4,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020035a:	0106969b          	slliw	a3,a3,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020035e:	0107571b          	srliw	a4,a4,0x10
ffffffffc0200362:	8fd1                	or	a5,a5,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200364:	0186f6b3          	and	a3,a3,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200368:	0087171b          	slliw	a4,a4,0x8
ffffffffc020036c:	8fd5                	or	a5,a5,a3
ffffffffc020036e:	00eb7733          	and	a4,s6,a4
ffffffffc0200372:	8fd9                	or	a5,a5,a4
ffffffffc0200374:	2781                	sext.w	a5,a5
        switch (token) {
ffffffffc0200376:	09778c63          	beq	a5,s7,ffffffffc020040e <dtb_init+0x1ee>
ffffffffc020037a:	00fbea63          	bltu	s7,a5,ffffffffc020038e <dtb_init+0x16e>
ffffffffc020037e:	07a78663          	beq	a5,s10,ffffffffc02003ea <dtb_init+0x1ca>
ffffffffc0200382:	4709                	li	a4,2
ffffffffc0200384:	00e79763          	bne	a5,a4,ffffffffc0200392 <dtb_init+0x172>
ffffffffc0200388:	4c81                	li	s9,0
ffffffffc020038a:	8a56                	mv	s4,s5
ffffffffc020038c:	bf6d                	j	ffffffffc0200346 <dtb_init+0x126>
ffffffffc020038e:	ffb78ee3          	beq	a5,s11,ffffffffc020038a <dtb_init+0x16a>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
        // 保存到全局变量，供 PMM 查询
        memory_base = mem_base;
        memory_size = mem_size;
    } else {
        cprintf("Warning: Could not extract memory info from DTB\n");
ffffffffc0200392:	00001517          	auipc	a0,0x1
ffffffffc0200396:	34650513          	addi	a0,a0,838 # ffffffffc02016d8 <etext+0x212>
ffffffffc020039a:	db3ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    }
    cprintf("DTB init completed\n");
ffffffffc020039e:	00001517          	auipc	a0,0x1
ffffffffc02003a2:	37250513          	addi	a0,a0,882 # ffffffffc0201710 <etext+0x24a>
}
ffffffffc02003a6:	7446                	ld	s0,112(sp)
ffffffffc02003a8:	70e6                	ld	ra,120(sp)
ffffffffc02003aa:	74a6                	ld	s1,104(sp)
ffffffffc02003ac:	7906                	ld	s2,96(sp)
ffffffffc02003ae:	69e6                	ld	s3,88(sp)
ffffffffc02003b0:	6a46                	ld	s4,80(sp)
ffffffffc02003b2:	6aa6                	ld	s5,72(sp)
ffffffffc02003b4:	6b06                	ld	s6,64(sp)
ffffffffc02003b6:	7be2                	ld	s7,56(sp)
ffffffffc02003b8:	7c42                	ld	s8,48(sp)
ffffffffc02003ba:	7ca2                	ld	s9,40(sp)
ffffffffc02003bc:	7d02                	ld	s10,32(sp)
ffffffffc02003be:	6de2                	ld	s11,24(sp)
ffffffffc02003c0:	6109                	addi	sp,sp,128
    cprintf("DTB init completed\n");
ffffffffc02003c2:	b369                	j	ffffffffc020014c <cprintf>
}
ffffffffc02003c4:	7446                	ld	s0,112(sp)
ffffffffc02003c6:	70e6                	ld	ra,120(sp)
ffffffffc02003c8:	74a6                	ld	s1,104(sp)
ffffffffc02003ca:	7906                	ld	s2,96(sp)
ffffffffc02003cc:	69e6                	ld	s3,88(sp)
ffffffffc02003ce:	6a46                	ld	s4,80(sp)
ffffffffc02003d0:	6aa6                	ld	s5,72(sp)
ffffffffc02003d2:	6b06                	ld	s6,64(sp)
ffffffffc02003d4:	7be2                	ld	s7,56(sp)
ffffffffc02003d6:	7c42                	ld	s8,48(sp)
ffffffffc02003d8:	7ca2                	ld	s9,40(sp)
ffffffffc02003da:	7d02                	ld	s10,32(sp)
ffffffffc02003dc:	6de2                	ld	s11,24(sp)
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc02003de:	00001517          	auipc	a0,0x1
ffffffffc02003e2:	25250513          	addi	a0,a0,594 # ffffffffc0201630 <etext+0x16a>
}
ffffffffc02003e6:	6109                	addi	sp,sp,128
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc02003e8:	b395                	j	ffffffffc020014c <cprintf>
                int name_len = strlen(name);
ffffffffc02003ea:	8556                	mv	a0,s5
ffffffffc02003ec:	04e010ef          	jal	ra,ffffffffc020143a <strlen>
ffffffffc02003f0:	8a2a                	mv	s4,a0
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc02003f2:	4619                	li	a2,6
ffffffffc02003f4:	85a6                	mv	a1,s1
ffffffffc02003f6:	8556                	mv	a0,s5
                int name_len = strlen(name);
ffffffffc02003f8:	2a01                	sext.w	s4,s4
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc02003fa:	094010ef          	jal	ra,ffffffffc020148e <strncmp>
ffffffffc02003fe:	e111                	bnez	a0,ffffffffc0200402 <dtb_init+0x1e2>
                    in_memory_node = 1;
ffffffffc0200400:	4c85                	li	s9,1
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + name_len + 4) & ~3);
ffffffffc0200402:	0a91                	addi	s5,s5,4
ffffffffc0200404:	9ad2                	add	s5,s5,s4
ffffffffc0200406:	ffcafa93          	andi	s5,s5,-4
        switch (token) {
ffffffffc020040a:	8a56                	mv	s4,s5
ffffffffc020040c:	bf2d                	j	ffffffffc0200346 <dtb_init+0x126>
                uint32_t prop_len = fdt32_to_cpu(*struct_ptr++);
ffffffffc020040e:	004a2783          	lw	a5,4(s4)
                uint32_t prop_nameoff = fdt32_to_cpu(*struct_ptr++);
ffffffffc0200412:	00ca0693          	addi	a3,s4,12
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200416:	0087d71b          	srliw	a4,a5,0x8
ffffffffc020041a:	01879a9b          	slliw	s5,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020041e:	0187d61b          	srliw	a2,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200422:	0107171b          	slliw	a4,a4,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200426:	0107d79b          	srliw	a5,a5,0x10
ffffffffc020042a:	00caeab3          	or	s5,s5,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020042e:	01877733          	and	a4,a4,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200432:	0087979b          	slliw	a5,a5,0x8
ffffffffc0200436:	00eaeab3          	or	s5,s5,a4
ffffffffc020043a:	00fb77b3          	and	a5,s6,a5
ffffffffc020043e:	00faeab3          	or	s5,s5,a5
ffffffffc0200442:	2a81                	sext.w	s5,s5
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc0200444:	000c9c63          	bnez	s9,ffffffffc020045c <dtb_init+0x23c>
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + prop_len + 3) & ~3);
ffffffffc0200448:	1a82                	slli	s5,s5,0x20
ffffffffc020044a:	00368793          	addi	a5,a3,3
ffffffffc020044e:	020ada93          	srli	s5,s5,0x20
ffffffffc0200452:	9abe                	add	s5,s5,a5
ffffffffc0200454:	ffcafa93          	andi	s5,s5,-4
        switch (token) {
ffffffffc0200458:	8a56                	mv	s4,s5
ffffffffc020045a:	b5f5                	j	ffffffffc0200346 <dtb_init+0x126>
                uint32_t prop_nameoff = fdt32_to_cpu(*struct_ptr++);
ffffffffc020045c:	008a2783          	lw	a5,8(s4)
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc0200460:	85ca                	mv	a1,s2
ffffffffc0200462:	e436                	sd	a3,8(sp)
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200464:	0087d51b          	srliw	a0,a5,0x8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200468:	0187d61b          	srliw	a2,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020046c:	0187971b          	slliw	a4,a5,0x18
ffffffffc0200470:	0105151b          	slliw	a0,a0,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200474:	0107d79b          	srliw	a5,a5,0x10
ffffffffc0200478:	8f51                	or	a4,a4,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020047a:	01857533          	and	a0,a0,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020047e:	0087979b          	slliw	a5,a5,0x8
ffffffffc0200482:	8d59                	or	a0,a0,a4
ffffffffc0200484:	00fb77b3          	and	a5,s6,a5
ffffffffc0200488:	8d5d                	or	a0,a0,a5
                const char *prop_name = strings_base + prop_nameoff;
ffffffffc020048a:	1502                	slli	a0,a0,0x20
ffffffffc020048c:	9101                	srli	a0,a0,0x20
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc020048e:	9522                	add	a0,a0,s0
ffffffffc0200490:	7e1000ef          	jal	ra,ffffffffc0201470 <strcmp>
ffffffffc0200494:	66a2                	ld	a3,8(sp)
ffffffffc0200496:	f94d                	bnez	a0,ffffffffc0200448 <dtb_init+0x228>
ffffffffc0200498:	fb59f8e3          	bgeu	s3,s5,ffffffffc0200448 <dtb_init+0x228>
                    *mem_base = fdt64_to_cpu(reg_data[0]);
ffffffffc020049c:	00ca3783          	ld	a5,12(s4)
                    *mem_size = fdt64_to_cpu(reg_data[1]);
ffffffffc02004a0:	014a3703          	ld	a4,20(s4)
        cprintf("Physical Memory from DTB:\n");
ffffffffc02004a4:	00001517          	auipc	a0,0x1
ffffffffc02004a8:	1c450513          	addi	a0,a0,452 # ffffffffc0201668 <etext+0x1a2>
           fdt32_to_cpu(x >> 32);
ffffffffc02004ac:	4207d613          	srai	a2,a5,0x20
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004b0:	0087d31b          	srliw	t1,a5,0x8
           fdt32_to_cpu(x >> 32);
ffffffffc02004b4:	42075593          	srai	a1,a4,0x20
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004b8:	0187de1b          	srliw	t3,a5,0x18
ffffffffc02004bc:	0186581b          	srliw	a6,a2,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004c0:	0187941b          	slliw	s0,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004c4:	0107d89b          	srliw	a7,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004c8:	0187d693          	srli	a3,a5,0x18
ffffffffc02004cc:	01861f1b          	slliw	t5,a2,0x18
ffffffffc02004d0:	0087579b          	srliw	a5,a4,0x8
ffffffffc02004d4:	0103131b          	slliw	t1,t1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004d8:	0106561b          	srliw	a2,a2,0x10
ffffffffc02004dc:	010f6f33          	or	t5,t5,a6
ffffffffc02004e0:	0187529b          	srliw	t0,a4,0x18
ffffffffc02004e4:	0185df9b          	srliw	t6,a1,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004e8:	01837333          	and	t1,t1,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004ec:	01c46433          	or	s0,s0,t3
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004f0:	0186f6b3          	and	a3,a3,s8
ffffffffc02004f4:	01859e1b          	slliw	t3,a1,0x18
ffffffffc02004f8:	01871e9b          	slliw	t4,a4,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004fc:	0107581b          	srliw	a6,a4,0x10
ffffffffc0200500:	0086161b          	slliw	a2,a2,0x8
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200504:	8361                	srli	a4,a4,0x18
ffffffffc0200506:	0107979b          	slliw	a5,a5,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020050a:	0105d59b          	srliw	a1,a1,0x10
ffffffffc020050e:	01e6e6b3          	or	a3,a3,t5
ffffffffc0200512:	00cb7633          	and	a2,s6,a2
ffffffffc0200516:	0088181b          	slliw	a6,a6,0x8
ffffffffc020051a:	0085959b          	slliw	a1,a1,0x8
ffffffffc020051e:	00646433          	or	s0,s0,t1
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200522:	0187f7b3          	and	a5,a5,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200526:	01fe6333          	or	t1,t3,t6
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020052a:	01877c33          	and	s8,a4,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020052e:	0088989b          	slliw	a7,a7,0x8
ffffffffc0200532:	011b78b3          	and	a7,s6,a7
ffffffffc0200536:	005eeeb3          	or	t4,t4,t0
ffffffffc020053a:	00c6e733          	or	a4,a3,a2
ffffffffc020053e:	006c6c33          	or	s8,s8,t1
ffffffffc0200542:	010b76b3          	and	a3,s6,a6
ffffffffc0200546:	00bb7b33          	and	s6,s6,a1
ffffffffc020054a:	01d7e7b3          	or	a5,a5,t4
ffffffffc020054e:	016c6b33          	or	s6,s8,s6
ffffffffc0200552:	01146433          	or	s0,s0,a7
ffffffffc0200556:	8fd5                	or	a5,a5,a3
           fdt32_to_cpu(x >> 32);
ffffffffc0200558:	1702                	slli	a4,a4,0x20
ffffffffc020055a:	1b02                	slli	s6,s6,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc020055c:	1782                	slli	a5,a5,0x20
           fdt32_to_cpu(x >> 32);
ffffffffc020055e:	9301                	srli	a4,a4,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc0200560:	1402                	slli	s0,s0,0x20
           fdt32_to_cpu(x >> 32);
ffffffffc0200562:	020b5b13          	srli	s6,s6,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc0200566:	0167eb33          	or	s6,a5,s6
ffffffffc020056a:	8c59                	or	s0,s0,a4
        cprintf("Physical Memory from DTB:\n");
ffffffffc020056c:	be1ff0ef          	jal	ra,ffffffffc020014c <cprintf>
        cprintf("  Base: 0x%016lx\n", mem_base);
ffffffffc0200570:	85a2                	mv	a1,s0
ffffffffc0200572:	00001517          	auipc	a0,0x1
ffffffffc0200576:	11650513          	addi	a0,a0,278 # ffffffffc0201688 <etext+0x1c2>
ffffffffc020057a:	bd3ff0ef          	jal	ra,ffffffffc020014c <cprintf>
        cprintf("  Size: 0x%016lx (%ld MB)\n", mem_size, mem_size / (1024 * 1024));
ffffffffc020057e:	014b5613          	srli	a2,s6,0x14
ffffffffc0200582:	85da                	mv	a1,s6
ffffffffc0200584:	00001517          	auipc	a0,0x1
ffffffffc0200588:	11c50513          	addi	a0,a0,284 # ffffffffc02016a0 <etext+0x1da>
ffffffffc020058c:	bc1ff0ef          	jal	ra,ffffffffc020014c <cprintf>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
ffffffffc0200590:	008b05b3          	add	a1,s6,s0
ffffffffc0200594:	15fd                	addi	a1,a1,-1
ffffffffc0200596:	00001517          	auipc	a0,0x1
ffffffffc020059a:	12a50513          	addi	a0,a0,298 # ffffffffc02016c0 <etext+0x1fa>
ffffffffc020059e:	bafff0ef          	jal	ra,ffffffffc020014c <cprintf>
    cprintf("DTB init completed\n");
ffffffffc02005a2:	00001517          	auipc	a0,0x1
ffffffffc02005a6:	16e50513          	addi	a0,a0,366 # ffffffffc0201710 <etext+0x24a>
        memory_base = mem_base;
ffffffffc02005aa:	00005797          	auipc	a5,0x5
ffffffffc02005ae:	c487bb23          	sd	s0,-938(a5) # ffffffffc0205200 <memory_base>
        memory_size = mem_size;
ffffffffc02005b2:	00005797          	auipc	a5,0x5
ffffffffc02005b6:	c567bb23          	sd	s6,-938(a5) # ffffffffc0205208 <memory_size>
    cprintf("DTB init completed\n");
ffffffffc02005ba:	b3f5                	j	ffffffffc02003a6 <dtb_init+0x186>

ffffffffc02005bc <get_memory_base>:

uint64_t get_memory_base(void) {
    return memory_base;
}
ffffffffc02005bc:	00005517          	auipc	a0,0x5
ffffffffc02005c0:	c4453503          	ld	a0,-956(a0) # ffffffffc0205200 <memory_base>
ffffffffc02005c4:	8082                	ret

ffffffffc02005c6 <get_memory_size>:

uint64_t get_memory_size(void) {
    return memory_size;
ffffffffc02005c6:	00005517          	auipc	a0,0x5
ffffffffc02005ca:	c4253503          	ld	a0,-958(a0) # ffffffffc0205208 <memory_size>
ffffffffc02005ce:	8082                	ret

ffffffffc02005d0 <buddy_init>:
    nr_free -= order_size(order);
}

static void
buddy_init(void) {
    for (int i = 0; i < BUDDY_MAX_ORDER; i ++) {
ffffffffc02005d0:	00005797          	auipc	a5,0x5
ffffffffc02005d4:	a4878793          	addi	a5,a5,-1464 # ffffffffc0205018 <free_area>
ffffffffc02005d8:	00005717          	auipc	a4,0x5
ffffffffc02005dc:	c2070713          	addi	a4,a4,-992 # ffffffffc02051f8 <is_panic>
 * list_init - initialize a new entry
 * @elm:        new entry to be initialized
 * */
static inline void
list_init(list_entry_t *elm) {
    elm->prev = elm->next = elm;
ffffffffc02005e0:	e79c                	sd	a5,8(a5)
ffffffffc02005e2:	e39c                	sd	a5,0(a5)
        list_init(&(free_area[i].free_list));
        free_area[i].nr_free = 0;
ffffffffc02005e4:	0007a823          	sw	zero,16(a5)
    for (int i = 0; i < BUDDY_MAX_ORDER; i ++) {
ffffffffc02005e8:	07e1                	addi	a5,a5,24
ffffffffc02005ea:	fee79be3          	bne	a5,a4,ffffffffc02005e0 <buddy_init+0x10>
    }
    nr_free = 0;
ffffffffc02005ee:	00005797          	auipc	a5,0x5
ffffffffc02005f2:	c207b123          	sd	zero,-990(a5) # ffffffffc0205210 <nr_free>
}
ffffffffc02005f6:	8082                	ret

ffffffffc02005f8 <buddy_nr_free_pages>:
}

static size_t
buddy_nr_free_pages(void) {
    return nr_free;
}
ffffffffc02005f8:	00005517          	auipc	a0,0x5
ffffffffc02005fc:	c1853503          	ld	a0,-1000(a0) # ffffffffc0205210 <nr_free>
ffffffffc0200600:	8082                	ret

ffffffffc0200602 <buddy_remove_block>:
buddy_remove_block(struct Page *page, int order) {
ffffffffc0200602:	1141                	addi	sp,sp,-16
ffffffffc0200604:	e406                	sd	ra,8(sp)
    assert(order >= 0 && order < BUDDY_MAX_ORDER);
ffffffffc0200606:	47cd                	li	a5,19
ffffffffc0200608:	08b7e063          	bltu	a5,a1,ffffffffc0200688 <buddy_remove_block+0x86>
    assert(PageProperty(page) && page->property == order_size(order));
ffffffffc020060c:	6518                	ld	a4,8(a0)
ffffffffc020060e:	00277793          	andi	a5,a4,2
ffffffffc0200612:	cfa1                	beqz	a5,ffffffffc020066a <buddy_remove_block+0x68>
ffffffffc0200614:	01056683          	lwu	a3,16(a0)
    return (size_t)1 << order;
ffffffffc0200618:	4785                	li	a5,1
ffffffffc020061a:	00b797b3          	sll	a5,a5,a1
    assert(PageProperty(page) && page->property == order_size(order));
ffffffffc020061e:	04f69663          	bne	a3,a5,ffffffffc020066a <buddy_remove_block+0x68>
    free_area[order].nr_free -= order_size(order);
ffffffffc0200622:	00159793          	slli	a5,a1,0x1
ffffffffc0200626:	95be                	add	a1,a1,a5
 * Note: list_empty() on @listelm does not return true after this, the entry is
 * in an undefined state.
 * */
static inline void
list_del(list_entry_t *listelm) {
    __list_del(listelm->prev, listelm->next);
ffffffffc0200628:	01853303          	ld	t1,24(a0)
ffffffffc020062c:	02053883          	ld	a7,32(a0)
ffffffffc0200630:	00005797          	auipc	a5,0x5
ffffffffc0200634:	9e878793          	addi	a5,a5,-1560 # ffffffffc0205018 <free_area>
ffffffffc0200638:	058e                	slli	a1,a1,0x3
ffffffffc020063a:	95be                	add	a1,a1,a5
    nr_free -= order_size(order);
ffffffffc020063c:	00005817          	auipc	a6,0x5
ffffffffc0200640:	bd480813          	addi	a6,a6,-1068 # ffffffffc0205210 <nr_free>
    free_area[order].nr_free -= order_size(order);
ffffffffc0200644:	4990                	lw	a2,16(a1)
    nr_free -= order_size(order);
ffffffffc0200646:	00083783          	ld	a5,0(a6)
 * This is only for internal list manipulation where we know
 * the prev/next entries already!
 * */
static inline void
__list_del(list_entry_t *prev, list_entry_t *next) {
    prev->next = next;
ffffffffc020064a:	01133423          	sd	a7,8(t1)
    next->prev = prev;
ffffffffc020064e:	0068b023          	sd	t1,0(a7)
}
ffffffffc0200652:	60a2                	ld	ra,8(sp)
    ClearPageProperty(page);
ffffffffc0200654:	9b75                	andi	a4,a4,-3
ffffffffc0200656:	e518                	sd	a4,8(a0)
    free_area[order].nr_free -= order_size(order);
ffffffffc0200658:	40d6073b          	subw	a4,a2,a3
    nr_free -= order_size(order);
ffffffffc020065c:	40d786b3          	sub	a3,a5,a3
    free_area[order].nr_free -= order_size(order);
ffffffffc0200660:	c998                	sw	a4,16(a1)
    nr_free -= order_size(order);
ffffffffc0200662:	00d83023          	sd	a3,0(a6)
}
ffffffffc0200666:	0141                	addi	sp,sp,16
ffffffffc0200668:	8082                	ret
    assert(PageProperty(page) && page->property == order_size(order));
ffffffffc020066a:	00001697          	auipc	a3,0x1
ffffffffc020066e:	11668693          	addi	a3,a3,278 # ffffffffc0201780 <etext+0x2ba>
ffffffffc0200672:	00001617          	auipc	a2,0x1
ffffffffc0200676:	0de60613          	addi	a2,a2,222 # ffffffffc0201750 <etext+0x28a>
ffffffffc020067a:	45fd                	li	a1,31
ffffffffc020067c:	00001517          	auipc	a0,0x1
ffffffffc0200680:	0ec50513          	addi	a0,a0,236 # ffffffffc0201768 <etext+0x2a2>
ffffffffc0200684:	b3fff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(order >= 0 && order < BUDDY_MAX_ORDER);
ffffffffc0200688:	00001697          	auipc	a3,0x1
ffffffffc020068c:	0a068693          	addi	a3,a3,160 # ffffffffc0201728 <etext+0x262>
ffffffffc0200690:	00001617          	auipc	a2,0x1
ffffffffc0200694:	0c060613          	addi	a2,a2,192 # ffffffffc0201750 <etext+0x28a>
ffffffffc0200698:	45f9                	li	a1,30
ffffffffc020069a:	00001517          	auipc	a0,0x1
ffffffffc020069e:	0ce50513          	addi	a0,a0,206 # ffffffffc0201768 <etext+0x2a2>
ffffffffc02006a2:	b21ff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc02006a6 <buddy_check>:

static void
buddy_check(void) {
ffffffffc02006a6:	db010113          	addi	sp,sp,-592
ffffffffc02006aa:	23413023          	sd	s4,544(sp)
    size_t nr_free_store = nr_free;
ffffffffc02006ae:	00005a17          	auipc	s4,0x5
ffffffffc02006b2:	b62a0a13          	addi	s4,s4,-1182 # ffffffffc0205210 <nr_free>
buddy_check(void) {
ffffffffc02006b6:	23313423          	sd	s3,552(sp)
    size_t nr_free_store = nr_free;
ffffffffc02006ba:	000a3983          	ld	s3,0(s4)
    cprintf("buddy_check begin: nr_free = %u\n", nr_free);
ffffffffc02006be:	00001517          	auipc	a0,0x1
ffffffffc02006c2:	10250513          	addi	a0,a0,258 # ffffffffc02017c0 <etext+0x2fa>
buddy_check(void) {
ffffffffc02006c6:	24113423          	sd	ra,584(sp)
    cprintf("buddy_check begin: nr_free = %u\n", nr_free);
ffffffffc02006ca:	85ce                	mv	a1,s3
buddy_check(void) {
ffffffffc02006cc:	24813023          	sd	s0,576(sp)
ffffffffc02006d0:	22913c23          	sd	s1,568(sp)
ffffffffc02006d4:	23213823          	sd	s2,560(sp)
ffffffffc02006d8:	21513c23          	sd	s5,536(sp)
ffffffffc02006dc:	21613823          	sd	s6,528(sp)
ffffffffc02006e0:	21713423          	sd	s7,520(sp)
    cprintf("buddy_check begin: nr_free = %u\n", nr_free);
ffffffffc02006e4:	a69ff0ef          	jal	ra,ffffffffc020014c <cprintf>

    struct Page *p0, *p1, *p2;
    assert((p0 = alloc_pages(1)) != NULL);
ffffffffc02006e8:	4505                	li	a0,1
ffffffffc02006ea:	71a000ef          	jal	ra,ffffffffc0200e04 <alloc_pages>
ffffffffc02006ee:	28050a63          	beqz	a0,ffffffffc0200982 <buddy_check+0x2dc>
ffffffffc02006f2:	8aaa                	mv	s5,a0
    assert((p1 = alloc_pages(1)) != NULL);
ffffffffc02006f4:	4505                	li	a0,1
ffffffffc02006f6:	70e000ef          	jal	ra,ffffffffc0200e04 <alloc_pages>
ffffffffc02006fa:	8baa                	mv	s7,a0
ffffffffc02006fc:	2c050363          	beqz	a0,ffffffffc02009c2 <buddy_check+0x31c>
    assert((p2 = alloc_pages(1)) != NULL);
ffffffffc0200700:	4505                	li	a0,1
ffffffffc0200702:	702000ef          	jal	ra,ffffffffc0200e04 <alloc_pages>
ffffffffc0200706:	8b2a                	mv	s6,a0
ffffffffc0200708:	28050d63          	beqz	a0,ffffffffc02009a2 <buddy_check+0x2fc>
    assert(p0 != p1 && p0 != p2 && p1 != p2);
ffffffffc020070c:	337a8b63          	beq	s5,s7,ffffffffc0200a42 <buddy_check+0x39c>
ffffffffc0200710:	32aa8963          	beq	s5,a0,ffffffffc0200a42 <buddy_check+0x39c>
ffffffffc0200714:	32ab8763          	beq	s7,a0,ffffffffc0200a42 <buddy_check+0x39c>
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
ffffffffc0200718:	000aa783          	lw	a5,0(s5)
ffffffffc020071c:	30079363          	bnez	a5,ffffffffc0200a22 <buddy_check+0x37c>
ffffffffc0200720:	000ba783          	lw	a5,0(s7)
ffffffffc0200724:	2e079f63          	bnez	a5,ffffffffc0200a22 <buddy_check+0x37c>
ffffffffc0200728:	411c                	lw	a5,0(a0)
ffffffffc020072a:	2e079c63          	bnez	a5,ffffffffc0200a22 <buddy_check+0x37c>
extern struct Page *pages;
extern size_t npage;
extern const size_t nbase;
extern uint64_t va_pa_offset;

static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc020072e:	00005917          	auipc	s2,0x5
ffffffffc0200732:	af290913          	addi	s2,s2,-1294 # ffffffffc0205220 <pages>
ffffffffc0200736:	00093783          	ld	a5,0(s2)
ffffffffc020073a:	00001497          	auipc	s1,0x1
ffffffffc020073e:	6c64b483          	ld	s1,1734(s1) # ffffffffc0201e00 <error_string+0x38>
ffffffffc0200742:	00001417          	auipc	s0,0x1
ffffffffc0200746:	6ce43403          	ld	s0,1742(s0) # ffffffffc0201e10 <nbase>
ffffffffc020074a:	40fa87b3          	sub	a5,s5,a5
ffffffffc020074e:	878d                	srai	a5,a5,0x3
ffffffffc0200750:	029787b3          	mul	a5,a5,s1
    assert(page2pa(p0) < npage * PGSIZE);
ffffffffc0200754:	00005717          	auipc	a4,0x5
ffffffffc0200758:	ac473703          	ld	a4,-1340(a4) # ffffffffc0205218 <npage>
ffffffffc020075c:	0732                	slli	a4,a4,0xc
ffffffffc020075e:	97a2                	add	a5,a5,s0

static inline uintptr_t page2pa(struct Page *page) {
    return page2ppn(page) << PGSHIFT;
ffffffffc0200760:	07b2                	slli	a5,a5,0xc
ffffffffc0200762:	2ae7f063          	bgeu	a5,a4,ffffffffc0200a02 <buddy_check+0x35c>
    free_pages(p0, 1);
ffffffffc0200766:	4585                	li	a1,1
ffffffffc0200768:	8556                	mv	a0,s5
ffffffffc020076a:	6a6000ef          	jal	ra,ffffffffc0200e10 <free_pages>
    free_pages(p1, 1);
ffffffffc020076e:	4585                	li	a1,1
ffffffffc0200770:	855e                	mv	a0,s7
ffffffffc0200772:	69e000ef          	jal	ra,ffffffffc0200e10 <free_pages>
    free_pages(p2, 1);
ffffffffc0200776:	4585                	li	a1,1
ffffffffc0200778:	855a                	mv	a0,s6
ffffffffc020077a:	696000ef          	jal	ra,ffffffffc0200e10 <free_pages>
    assert(nr_free == nr_free_store);
ffffffffc020077e:	000a3783          	ld	a5,0(s4)
ffffffffc0200782:	27379063          	bne	a5,s3,ffffffffc02009e2 <buddy_check+0x33c>

    struct Page *p3;
    assert((p3 = alloc_pages(5)) != NULL);
ffffffffc0200786:	4515                	li	a0,5
ffffffffc0200788:	67c000ef          	jal	ra,ffffffffc0200e04 <alloc_pages>
ffffffffc020078c:	1a050b63          	beqz	a0,ffffffffc0200942 <buddy_check+0x29c>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200790:	00093783          	ld	a5,0(s2)
ffffffffc0200794:	40f507b3          	sub	a5,a0,a5
ffffffffc0200798:	878d                	srai	a5,a5,0x3
ffffffffc020079a:	029787b3          	mul	a5,a5,s1
ffffffffc020079e:	97a2                	add	a5,a5,s0
    assert((page2ppn(p3) & (8 - 1)) == 0);
ffffffffc02007a0:	8b9d                	andi	a5,a5,7
ffffffffc02007a2:	18079063          	bnez	a5,ffffffffc0200922 <buddy_check+0x27c>
    assert(!PageProperty(p3));
ffffffffc02007a6:	651c                	ld	a5,8(a0)
ffffffffc02007a8:	8b89                	andi	a5,a5,2
ffffffffc02007aa:	14079c63          	bnez	a5,ffffffffc0200902 <buddy_check+0x25c>
    free_pages(p3, 5);
ffffffffc02007ae:	4595                	li	a1,5
ffffffffc02007b0:	660000ef          	jal	ra,ffffffffc0200e10 <free_pages>
    assert(nr_free == nr_free_store);
ffffffffc02007b4:	000a3783          	ld	a5,0(s4)
ffffffffc02007b8:	13379563          	bne	a5,s3,ffffffffc02008e2 <buddy_check+0x23c>

    struct Page *p4;
    assert((p4 = alloc_pages(64)) != NULL);
ffffffffc02007bc:	04000513          	li	a0,64
ffffffffc02007c0:	644000ef          	jal	ra,ffffffffc0200e04 <alloc_pages>
ffffffffc02007c4:	8aaa                	mv	s5,a0
ffffffffc02007c6:	0e050e63          	beqz	a0,ffffffffc02008c2 <buddy_check+0x21c>
ffffffffc02007ca:	00093783          	ld	a5,0(s2)
ffffffffc02007ce:	40f507b3          	sub	a5,a0,a5
ffffffffc02007d2:	878d                	srai	a5,a5,0x3
ffffffffc02007d4:	029787b3          	mul	a5,a5,s1
ffffffffc02007d8:	97a2                	add	a5,a5,s0
    assert((page2ppn(p4) & (64 - 1)) == 0);
ffffffffc02007da:	03f7f793          	andi	a5,a5,63
ffffffffc02007de:	e3f1                	bnez	a5,ffffffffc02008a2 <buddy_check+0x1fc>
    free_pages(p4, 32);
ffffffffc02007e0:	02000593          	li	a1,32
ffffffffc02007e4:	62c000ef          	jal	ra,ffffffffc0200e10 <free_pages>
    free_pages(p4 + 32, 32);
ffffffffc02007e8:	02000593          	li	a1,32
ffffffffc02007ec:	500a8513          	addi	a0,s5,1280
ffffffffc02007f0:	620000ef          	jal	ra,ffffffffc0200e10 <free_pages>
    assert(nr_free == nr_free_store);
ffffffffc02007f4:	000a3783          	ld	a5,0(s4)
ffffffffc02007f8:	17379563          	bne	a5,s3,ffffffffc0200962 <buddy_check+0x2bc>
ffffffffc02007fc:	848a                	mv	s1,sp
ffffffffc02007fe:	20010913          	addi	s2,sp,512
ffffffffc0200802:	8426                	mv	s0,s1
ffffffffc0200804:	a021                	j	ffffffffc020080c <buddy_check+0x166>

    struct Page *stress[64];
    int count = 0;
    while (count < 64 && (stress[count] = alloc_pages(1)) != NULL) {
ffffffffc0200806:	0421                	addi	s0,s0,8
ffffffffc0200808:	03240763          	beq	s0,s2,ffffffffc0200836 <buddy_check+0x190>
ffffffffc020080c:	4505                	li	a0,1
ffffffffc020080e:	5f6000ef          	jal	ra,ffffffffc0200e04 <alloc_pages>
ffffffffc0200812:	e008                	sd	a0,0(s0)
ffffffffc0200814:	f96d                	bnez	a0,ffffffffc0200806 <buddy_check+0x160>
        count ++;
    }
    assert(count == 64);
ffffffffc0200816:	00001697          	auipc	a3,0x1
ffffffffc020081a:	18a68693          	addi	a3,a3,394 # ffffffffc02019a0 <etext+0x4da>
ffffffffc020081e:	00001617          	auipc	a2,0x1
ffffffffc0200822:	f3260613          	addi	a2,a2,-206 # ffffffffc0201750 <etext+0x28a>
ffffffffc0200826:	0bf00593          	li	a1,191
ffffffffc020082a:	00001517          	auipc	a0,0x1
ffffffffc020082e:	f3e50513          	addi	a0,a0,-194 # ffffffffc0201768 <etext+0x2a2>
ffffffffc0200832:	991ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
ffffffffc0200836:	1ba0                	addi	s0,sp,504
    while (count > 0) {
        free_pages(stress[--count], 1);
ffffffffc0200838:	6008                	ld	a0,0(s0)
ffffffffc020083a:	4585                	li	a1,1
ffffffffc020083c:	5d4000ef          	jal	ra,ffffffffc0200e10 <free_pages>
    while (count > 0) {
ffffffffc0200840:	87a2                	mv	a5,s0
ffffffffc0200842:	1461                	addi	s0,s0,-8
ffffffffc0200844:	fef49ae3          	bne	s1,a5,ffffffffc0200838 <buddy_check+0x192>
    }
    assert(nr_free == nr_free_store);
ffffffffc0200848:	000a3783          	ld	a5,0(s4)
ffffffffc020084c:	03379b63          	bne	a5,s3,ffffffffc0200882 <buddy_check+0x1dc>

    cprintf("buddy_check succeeded!\n");
}
ffffffffc0200850:	24013403          	ld	s0,576(sp)
ffffffffc0200854:	24813083          	ld	ra,584(sp)
ffffffffc0200858:	23813483          	ld	s1,568(sp)
ffffffffc020085c:	23013903          	ld	s2,560(sp)
ffffffffc0200860:	22813983          	ld	s3,552(sp)
ffffffffc0200864:	22013a03          	ld	s4,544(sp)
ffffffffc0200868:	21813a83          	ld	s5,536(sp)
ffffffffc020086c:	21013b03          	ld	s6,528(sp)
ffffffffc0200870:	20813b83          	ld	s7,520(sp)
    cprintf("buddy_check succeeded!\n");
ffffffffc0200874:	00001517          	auipc	a0,0x1
ffffffffc0200878:	11450513          	addi	a0,a0,276 # ffffffffc0201988 <etext+0x4c2>
}
ffffffffc020087c:	25010113          	addi	sp,sp,592
    cprintf("buddy_check succeeded!\n");
ffffffffc0200880:	b0f1                	j	ffffffffc020014c <cprintf>
    assert(nr_free == nr_free_store);
ffffffffc0200882:	00001697          	auipc	a3,0x1
ffffffffc0200886:	04e68693          	addi	a3,a3,78 # ffffffffc02018d0 <etext+0x40a>
ffffffffc020088a:	00001617          	auipc	a2,0x1
ffffffffc020088e:	ec660613          	addi	a2,a2,-314 # ffffffffc0201750 <etext+0x28a>
ffffffffc0200892:	0c300593          	li	a1,195
ffffffffc0200896:	00001517          	auipc	a0,0x1
ffffffffc020089a:	ed250513          	addi	a0,a0,-302 # ffffffffc0201768 <etext+0x2a2>
ffffffffc020089e:	925ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((page2ppn(p4) & (64 - 1)) == 0);
ffffffffc02008a2:	00001697          	auipc	a3,0x1
ffffffffc02008a6:	0c668693          	addi	a3,a3,198 # ffffffffc0201968 <etext+0x4a2>
ffffffffc02008aa:	00001617          	auipc	a2,0x1
ffffffffc02008ae:	ea660613          	addi	a2,a2,-346 # ffffffffc0201750 <etext+0x28a>
ffffffffc02008b2:	0b500593          	li	a1,181
ffffffffc02008b6:	00001517          	auipc	a0,0x1
ffffffffc02008ba:	eb250513          	addi	a0,a0,-334 # ffffffffc0201768 <etext+0x2a2>
ffffffffc02008be:	905ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p4 = alloc_pages(64)) != NULL);
ffffffffc02008c2:	00001697          	auipc	a3,0x1
ffffffffc02008c6:	08668693          	addi	a3,a3,134 # ffffffffc0201948 <etext+0x482>
ffffffffc02008ca:	00001617          	auipc	a2,0x1
ffffffffc02008ce:	e8660613          	addi	a2,a2,-378 # ffffffffc0201750 <etext+0x28a>
ffffffffc02008d2:	0b400593          	li	a1,180
ffffffffc02008d6:	00001517          	auipc	a0,0x1
ffffffffc02008da:	e9250513          	addi	a0,a0,-366 # ffffffffc0201768 <etext+0x2a2>
ffffffffc02008de:	8e5ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(nr_free == nr_free_store);
ffffffffc02008e2:	00001697          	auipc	a3,0x1
ffffffffc02008e6:	fee68693          	addi	a3,a3,-18 # ffffffffc02018d0 <etext+0x40a>
ffffffffc02008ea:	00001617          	auipc	a2,0x1
ffffffffc02008ee:	e6660613          	addi	a2,a2,-410 # ffffffffc0201750 <etext+0x28a>
ffffffffc02008f2:	0b100593          	li	a1,177
ffffffffc02008f6:	00001517          	auipc	a0,0x1
ffffffffc02008fa:	e7250513          	addi	a0,a0,-398 # ffffffffc0201768 <etext+0x2a2>
ffffffffc02008fe:	8c5ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(!PageProperty(p3));
ffffffffc0200902:	00001697          	auipc	a3,0x1
ffffffffc0200906:	02e68693          	addi	a3,a3,46 # ffffffffc0201930 <etext+0x46a>
ffffffffc020090a:	00001617          	auipc	a2,0x1
ffffffffc020090e:	e4660613          	addi	a2,a2,-442 # ffffffffc0201750 <etext+0x28a>
ffffffffc0200912:	0af00593          	li	a1,175
ffffffffc0200916:	00001517          	auipc	a0,0x1
ffffffffc020091a:	e5250513          	addi	a0,a0,-430 # ffffffffc0201768 <etext+0x2a2>
ffffffffc020091e:	8a5ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((page2ppn(p3) & (8 - 1)) == 0);
ffffffffc0200922:	00001697          	auipc	a3,0x1
ffffffffc0200926:	fee68693          	addi	a3,a3,-18 # ffffffffc0201910 <etext+0x44a>
ffffffffc020092a:	00001617          	auipc	a2,0x1
ffffffffc020092e:	e2660613          	addi	a2,a2,-474 # ffffffffc0201750 <etext+0x28a>
ffffffffc0200932:	0ae00593          	li	a1,174
ffffffffc0200936:	00001517          	auipc	a0,0x1
ffffffffc020093a:	e3250513          	addi	a0,a0,-462 # ffffffffc0201768 <etext+0x2a2>
ffffffffc020093e:	885ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p3 = alloc_pages(5)) != NULL);
ffffffffc0200942:	00001697          	auipc	a3,0x1
ffffffffc0200946:	fae68693          	addi	a3,a3,-82 # ffffffffc02018f0 <etext+0x42a>
ffffffffc020094a:	00001617          	auipc	a2,0x1
ffffffffc020094e:	e0660613          	addi	a2,a2,-506 # ffffffffc0201750 <etext+0x28a>
ffffffffc0200952:	0ad00593          	li	a1,173
ffffffffc0200956:	00001517          	auipc	a0,0x1
ffffffffc020095a:	e1250513          	addi	a0,a0,-494 # ffffffffc0201768 <etext+0x2a2>
ffffffffc020095e:	865ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(nr_free == nr_free_store);
ffffffffc0200962:	00001697          	auipc	a3,0x1
ffffffffc0200966:	f6e68693          	addi	a3,a3,-146 # ffffffffc02018d0 <etext+0x40a>
ffffffffc020096a:	00001617          	auipc	a2,0x1
ffffffffc020096e:	de660613          	addi	a2,a2,-538 # ffffffffc0201750 <etext+0x28a>
ffffffffc0200972:	0b800593          	li	a1,184
ffffffffc0200976:	00001517          	auipc	a0,0x1
ffffffffc020097a:	df250513          	addi	a0,a0,-526 # ffffffffc0201768 <etext+0x2a2>
ffffffffc020097e:	845ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p0 = alloc_pages(1)) != NULL);
ffffffffc0200982:	00001697          	auipc	a3,0x1
ffffffffc0200986:	e6668693          	addi	a3,a3,-410 # ffffffffc02017e8 <etext+0x322>
ffffffffc020098a:	00001617          	auipc	a2,0x1
ffffffffc020098e:	dc660613          	addi	a2,a2,-570 # ffffffffc0201750 <etext+0x28a>
ffffffffc0200992:	0a100593          	li	a1,161
ffffffffc0200996:	00001517          	auipc	a0,0x1
ffffffffc020099a:	dd250513          	addi	a0,a0,-558 # ffffffffc0201768 <etext+0x2a2>
ffffffffc020099e:	825ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p2 = alloc_pages(1)) != NULL);
ffffffffc02009a2:	00001697          	auipc	a3,0x1
ffffffffc02009a6:	e8668693          	addi	a3,a3,-378 # ffffffffc0201828 <etext+0x362>
ffffffffc02009aa:	00001617          	auipc	a2,0x1
ffffffffc02009ae:	da660613          	addi	a2,a2,-602 # ffffffffc0201750 <etext+0x28a>
ffffffffc02009b2:	0a300593          	li	a1,163
ffffffffc02009b6:	00001517          	auipc	a0,0x1
ffffffffc02009ba:	db250513          	addi	a0,a0,-590 # ffffffffc0201768 <etext+0x2a2>
ffffffffc02009be:	805ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert((p1 = alloc_pages(1)) != NULL);
ffffffffc02009c2:	00001697          	auipc	a3,0x1
ffffffffc02009c6:	e4668693          	addi	a3,a3,-442 # ffffffffc0201808 <etext+0x342>
ffffffffc02009ca:	00001617          	auipc	a2,0x1
ffffffffc02009ce:	d8660613          	addi	a2,a2,-634 # ffffffffc0201750 <etext+0x28a>
ffffffffc02009d2:	0a200593          	li	a1,162
ffffffffc02009d6:	00001517          	auipc	a0,0x1
ffffffffc02009da:	d9250513          	addi	a0,a0,-622 # ffffffffc0201768 <etext+0x2a2>
ffffffffc02009de:	fe4ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(nr_free == nr_free_store);
ffffffffc02009e2:	00001697          	auipc	a3,0x1
ffffffffc02009e6:	eee68693          	addi	a3,a3,-274 # ffffffffc02018d0 <etext+0x40a>
ffffffffc02009ea:	00001617          	auipc	a2,0x1
ffffffffc02009ee:	d6660613          	addi	a2,a2,-666 # ffffffffc0201750 <etext+0x28a>
ffffffffc02009f2:	0aa00593          	li	a1,170
ffffffffc02009f6:	00001517          	auipc	a0,0x1
ffffffffc02009fa:	d7250513          	addi	a0,a0,-654 # ffffffffc0201768 <etext+0x2a2>
ffffffffc02009fe:	fc4ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(page2pa(p0) < npage * PGSIZE);
ffffffffc0200a02:	00001697          	auipc	a3,0x1
ffffffffc0200a06:	eae68693          	addi	a3,a3,-338 # ffffffffc02018b0 <etext+0x3ea>
ffffffffc0200a0a:	00001617          	auipc	a2,0x1
ffffffffc0200a0e:	d4660613          	addi	a2,a2,-698 # ffffffffc0201750 <etext+0x28a>
ffffffffc0200a12:	0a600593          	li	a1,166
ffffffffc0200a16:	00001517          	auipc	a0,0x1
ffffffffc0200a1a:	d5250513          	addi	a0,a0,-686 # ffffffffc0201768 <etext+0x2a2>
ffffffffc0200a1e:	fa4ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
ffffffffc0200a22:	00001697          	auipc	a3,0x1
ffffffffc0200a26:	e4e68693          	addi	a3,a3,-434 # ffffffffc0201870 <etext+0x3aa>
ffffffffc0200a2a:	00001617          	auipc	a2,0x1
ffffffffc0200a2e:	d2660613          	addi	a2,a2,-730 # ffffffffc0201750 <etext+0x28a>
ffffffffc0200a32:	0a500593          	li	a1,165
ffffffffc0200a36:	00001517          	auipc	a0,0x1
ffffffffc0200a3a:	d3250513          	addi	a0,a0,-718 # ffffffffc0201768 <etext+0x2a2>
ffffffffc0200a3e:	f84ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(p0 != p1 && p0 != p2 && p1 != p2);
ffffffffc0200a42:	00001697          	auipc	a3,0x1
ffffffffc0200a46:	e0668693          	addi	a3,a3,-506 # ffffffffc0201848 <etext+0x382>
ffffffffc0200a4a:	00001617          	auipc	a2,0x1
ffffffffc0200a4e:	d0660613          	addi	a2,a2,-762 # ffffffffc0201750 <etext+0x28a>
ffffffffc0200a52:	0a400593          	li	a1,164
ffffffffc0200a56:	00001517          	auipc	a0,0x1
ffffffffc0200a5a:	d1250513          	addi	a0,a0,-750 # ffffffffc0201768 <etext+0x2a2>
ffffffffc0200a5e:	f64ff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0200a62 <buddy_add_block>:
    assert(order >= 0 && order < BUDDY_MAX_ORDER);
ffffffffc0200a62:	47cd                	li	a5,19
ffffffffc0200a64:	04b7ef63          	bltu	a5,a1,ffffffffc0200ac2 <buddy_add_block+0x60>
    __list_add(elm, listelm, listelm->next);
ffffffffc0200a68:	00159793          	slli	a5,a1,0x1
ffffffffc0200a6c:	97ae                	add	a5,a5,a1
    SetPageProperty(base);
ffffffffc0200a6e:	6510                	ld	a2,8(a0)
ffffffffc0200a70:	00379713          	slli	a4,a5,0x3
ffffffffc0200a74:	00004797          	auipc	a5,0x4
ffffffffc0200a78:	5a478793          	addi	a5,a5,1444 # ffffffffc0205018 <free_area>
ffffffffc0200a7c:	97ba                	add	a5,a5,a4
    return (size_t)1 << order;
ffffffffc0200a7e:	4705                	li	a4,1
ffffffffc0200a80:	0087b303          	ld	t1,8(a5)
ffffffffc0200a84:	00b715b3          	sll	a1,a4,a1
    base->property = order_size(order);
ffffffffc0200a88:	0005889b          	sext.w	a7,a1
    SetPageProperty(base);
ffffffffc0200a8c:	00266713          	ori	a4,a2,2
    nr_free += order_size(order);
ffffffffc0200a90:	00004817          	auipc	a6,0x4
ffffffffc0200a94:	78080813          	addi	a6,a6,1920 # ffffffffc0205210 <nr_free>
    free_area[order].nr_free += order_size(order);
ffffffffc0200a98:	4b94                	lw	a3,16(a5)
    SetPageProperty(base);
ffffffffc0200a9a:	e518                	sd	a4,8(a0)
    base->property = order_size(order);
ffffffffc0200a9c:	01152823          	sw	a7,16(a0)
    nr_free += order_size(order);
ffffffffc0200aa0:	00083703          	ld	a4,0(a6)
    list_add(&(free_area[order].free_list), &(base->page_link));
ffffffffc0200aa4:	01850613          	addi	a2,a0,24
    prev->next = next->prev = elm;
ffffffffc0200aa8:	00c33023          	sd	a2,0(t1)
ffffffffc0200aac:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc0200aae:	02653023          	sd	t1,32(a0)
    elm->prev = prev;
ffffffffc0200ab2:	ed1c                	sd	a5,24(a0)
    free_area[order].nr_free += order_size(order);
ffffffffc0200ab4:	011686bb          	addw	a3,a3,a7
    nr_free += order_size(order);
ffffffffc0200ab8:	95ba                	add	a1,a1,a4
    free_area[order].nr_free += order_size(order);
ffffffffc0200aba:	cb94                	sw	a3,16(a5)
    nr_free += order_size(order);
ffffffffc0200abc:	00b83023          	sd	a1,0(a6)
ffffffffc0200ac0:	8082                	ret
buddy_add_block(struct Page *base, int order) {
ffffffffc0200ac2:	1141                	addi	sp,sp,-16
    assert(order >= 0 && order < BUDDY_MAX_ORDER);
ffffffffc0200ac4:	00001697          	auipc	a3,0x1
ffffffffc0200ac8:	c6468693          	addi	a3,a3,-924 # ffffffffc0201728 <etext+0x262>
ffffffffc0200acc:	00001617          	auipc	a2,0x1
ffffffffc0200ad0:	c8460613          	addi	a2,a2,-892 # ffffffffc0201750 <etext+0x28a>
ffffffffc0200ad4:	45cd                	li	a1,19
ffffffffc0200ad6:	00001517          	auipc	a0,0x1
ffffffffc0200ada:	c9250513          	addi	a0,a0,-878 # ffffffffc0201768 <etext+0x2a2>
buddy_add_block(struct Page *base, int order) {
ffffffffc0200ade:	e406                	sd	ra,8(sp)
    assert(order >= 0 && order < BUDDY_MAX_ORDER);
ffffffffc0200ae0:	ee2ff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0200ae4 <buddy_free_pages>:
buddy_free_pages(struct Page *base, size_t n) {
ffffffffc0200ae4:	715d                	addi	sp,sp,-80
ffffffffc0200ae6:	e486                	sd	ra,72(sp)
ffffffffc0200ae8:	e0a2                	sd	s0,64(sp)
ffffffffc0200aea:	fc26                	sd	s1,56(sp)
ffffffffc0200aec:	f84a                	sd	s2,48(sp)
ffffffffc0200aee:	f44e                	sd	s3,40(sp)
ffffffffc0200af0:	f052                	sd	s4,32(sp)
ffffffffc0200af2:	ec56                	sd	s5,24(sp)
ffffffffc0200af4:	e85a                	sd	s6,16(sp)
ffffffffc0200af6:	e45e                	sd	s7,8(sp)
ffffffffc0200af8:	e062                	sd	s8,0(sp)
    assert(n > 0);
ffffffffc0200afa:	10058b63          	beqz	a1,ffffffffc0200c10 <buddy_free_pages+0x12c>
    for (; p != base + n; p ++) {
ffffffffc0200afe:	00259693          	slli	a3,a1,0x2
ffffffffc0200b02:	96ae                	add	a3,a3,a1
ffffffffc0200b04:	068e                	slli	a3,a3,0x3
ffffffffc0200b06:	96aa                	add	a3,a3,a0
ffffffffc0200b08:	8aaa                	mv	s5,a0
ffffffffc0200b0a:	87aa                	mv	a5,a0
ffffffffc0200b0c:	00d50f63          	beq	a0,a3,ffffffffc0200b2a <buddy_free_pages+0x46>
        assert(!PageReserved(p) && !PageProperty(p));   // 防止重复释放/释放保留页
ffffffffc0200b10:	6798                	ld	a4,8(a5)
ffffffffc0200b12:	8b0d                	andi	a4,a4,3
ffffffffc0200b14:	ef71                	bnez	a4,ffffffffc0200bf0 <buddy_free_pages+0x10c>
        p->flags = p->property = 0;
ffffffffc0200b16:	0007a823          	sw	zero,16(a5)
ffffffffc0200b1a:	0007b423          	sd	zero,8(a5)



static inline int page_ref(struct Page *page) { return page->ref; }

static inline void set_page_ref(struct Page *page, int val) { page->ref = val; }
ffffffffc0200b1e:	0007a023          	sw	zero,0(a5)
    for (; p != base + n; p ++) {
ffffffffc0200b22:	02878793          	addi	a5,a5,40
ffffffffc0200b26:	fed795e3          	bne	a5,a3,ffffffffc0200b10 <buddy_free_pages+0x2c>
    int order = 0;
ffffffffc0200b2a:	4481                	li	s1,0
    return (size_t)1 << order;
ffffffffc0200b2c:	4785                	li	a5,1
    while (order + 1 < BUDDY_MAX_ORDER && order_size(order) < n) {
ffffffffc0200b2e:	474d                	li	a4,19
ffffffffc0200b30:	a021                	j	ffffffffc0200b38 <buddy_free_pages+0x54>
        order ++;
ffffffffc0200b32:	2485                	addiw	s1,s1,1
    while (order + 1 < BUDDY_MAX_ORDER && order_size(order) < n) {
ffffffffc0200b34:	0ae48063          	beq	s1,a4,ffffffffc0200bd4 <buddy_free_pages+0xf0>
    return (size_t)1 << order;
ffffffffc0200b38:	009796b3          	sll	a3,a5,s1
    while (order + 1 < BUDDY_MAX_ORDER && order_size(order) < n) {
ffffffffc0200b3c:	feb6ebe3          	bltu	a3,a1,ffffffffc0200b32 <buddy_free_pages+0x4e>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200b40:	00004b97          	auipc	s7,0x4
ffffffffc0200b44:	6e0b8b93          	addi	s7,s7,1760 # ffffffffc0205220 <pages>
ffffffffc0200b48:	000bb783          	ld	a5,0(s7)
ffffffffc0200b4c:	00001417          	auipc	s0,0x1
ffffffffc0200b50:	2b443403          	ld	s0,692(s0) # ffffffffc0201e00 <error_string+0x38>
ffffffffc0200b54:	00001b17          	auipc	s6,0x1
ffffffffc0200b58:	2bcb3b03          	ld	s6,700(s6) # ffffffffc0201e10 <nbase>
ffffffffc0200b5c:	40fa87b3          	sub	a5,s5,a5
ffffffffc0200b60:	878d                	srai	a5,a5,0x3
ffffffffc0200b62:	028787b3          	mul	a5,a5,s0
ffffffffc0200b66:	97da                	add	a5,a5,s6
        size_t buddy_pfn = pfn ^ order_size(order);
ffffffffc0200b68:	8fb5                	xor	a5,a5,a3
        if (buddy_pfn < nbase || buddy_pfn >= npage) {
ffffffffc0200b6a:	0767e563          	bltu	a5,s6,ffffffffc0200bd4 <buddy_free_pages+0xf0>
ffffffffc0200b6e:	00004c17          	auipc	s8,0x4
ffffffffc0200b72:	6aac0c13          	addi	s8,s8,1706 # ffffffffc0205218 <npage>
    while (order + 1 < BUDDY_MAX_ORDER) {
ffffffffc0200b76:	49cd                	li	s3,19
    return (size_t)1 << order;
ffffffffc0200b78:	4a05                	li	s4,1
ffffffffc0200b7a:	a889                	j	ffffffffc0200bcc <buddy_free_pages+0xe8>
        struct Page *buddy = pages + (buddy_pfn - nbase);
ffffffffc0200b7c:	416787b3          	sub	a5,a5,s6
ffffffffc0200b80:	000bb903          	ld	s2,0(s7)
ffffffffc0200b84:	00279713          	slli	a4,a5,0x2
ffffffffc0200b88:	97ba                	add	a5,a5,a4
ffffffffc0200b8a:	078e                	slli	a5,a5,0x3
ffffffffc0200b8c:	993e                	add	s2,s2,a5
        if (!PageProperty(buddy) || buddy->property != order_size(order)) {
ffffffffc0200b8e:	00893783          	ld	a5,8(s2)
ffffffffc0200b92:	8b89                	andi	a5,a5,2
ffffffffc0200b94:	c3a1                	beqz	a5,ffffffffc0200bd4 <buddy_free_pages+0xf0>
ffffffffc0200b96:	01096783          	lwu	a5,16(s2)
ffffffffc0200b9a:	02f69d63          	bne	a3,a5,ffffffffc0200bd4 <buddy_free_pages+0xf0>
        buddy_remove_block(buddy, order);
ffffffffc0200b9e:	85a6                	mv	a1,s1
ffffffffc0200ba0:	854a                	mv	a0,s2
ffffffffc0200ba2:	a61ff0ef          	jal	ra,ffffffffc0200602 <buddy_remove_block>
        if (buddy < page) {
ffffffffc0200ba6:	01597363          	bgeu	s2,s5,ffffffffc0200bac <buddy_free_pages+0xc8>
ffffffffc0200baa:	8aca                	mv	s5,s2
ffffffffc0200bac:	000bb783          	ld	a5,0(s7)
        order ++;
ffffffffc0200bb0:	2485                	addiw	s1,s1,1
ffffffffc0200bb2:	40fa87b3          	sub	a5,s5,a5
ffffffffc0200bb6:	878d                	srai	a5,a5,0x3
ffffffffc0200bb8:	028787b3          	mul	a5,a5,s0
ffffffffc0200bbc:	97da                	add	a5,a5,s6
    while (order + 1 < BUDDY_MAX_ORDER) {
ffffffffc0200bbe:	01348b63          	beq	s1,s3,ffffffffc0200bd4 <buddy_free_pages+0xf0>
    return (size_t)1 << order;
ffffffffc0200bc2:	009a16b3          	sll	a3,s4,s1
        size_t buddy_pfn = pfn ^ order_size(order);
ffffffffc0200bc6:	8fb5                	xor	a5,a5,a3
        if (buddy_pfn < nbase || buddy_pfn >= npage) {
ffffffffc0200bc8:	0167e663          	bltu	a5,s6,ffffffffc0200bd4 <buddy_free_pages+0xf0>
ffffffffc0200bcc:	000c3703          	ld	a4,0(s8)
ffffffffc0200bd0:	fae7e6e3          	bltu	a5,a4,ffffffffc0200b7c <buddy_free_pages+0x98>
}
ffffffffc0200bd4:	6406                	ld	s0,64(sp)
ffffffffc0200bd6:	60a6                	ld	ra,72(sp)
ffffffffc0200bd8:	7942                	ld	s2,48(sp)
ffffffffc0200bda:	79a2                	ld	s3,40(sp)
ffffffffc0200bdc:	7a02                	ld	s4,32(sp)
ffffffffc0200bde:	6b42                	ld	s6,16(sp)
ffffffffc0200be0:	6ba2                	ld	s7,8(sp)
ffffffffc0200be2:	6c02                	ld	s8,0(sp)
    buddy_add_block(page, order);
ffffffffc0200be4:	85a6                	mv	a1,s1
ffffffffc0200be6:	8556                	mv	a0,s5
}
ffffffffc0200be8:	74e2                	ld	s1,56(sp)
ffffffffc0200bea:	6ae2                	ld	s5,24(sp)
ffffffffc0200bec:	6161                	addi	sp,sp,80
    buddy_add_block(page, order);
ffffffffc0200bee:	bd95                	j	ffffffffc0200a62 <buddy_add_block>
        assert(!PageReserved(p) && !PageProperty(p));   // 防止重复释放/释放保留页
ffffffffc0200bf0:	00001697          	auipc	a3,0x1
ffffffffc0200bf4:	dc868693          	addi	a3,a3,-568 # ffffffffc02019b8 <etext+0x4f2>
ffffffffc0200bf8:	00001617          	auipc	a2,0x1
ffffffffc0200bfc:	b5860613          	addi	a2,a2,-1192 # ffffffffc0201750 <etext+0x28a>
ffffffffc0200c00:	07100593          	li	a1,113
ffffffffc0200c04:	00001517          	auipc	a0,0x1
ffffffffc0200c08:	b6450513          	addi	a0,a0,-1180 # ffffffffc0201768 <etext+0x2a2>
ffffffffc0200c0c:	db6ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(n > 0);
ffffffffc0200c10:	00001697          	auipc	a3,0x1
ffffffffc0200c14:	da068693          	addi	a3,a3,-608 # ffffffffc02019b0 <etext+0x4ea>
ffffffffc0200c18:	00001617          	auipc	a2,0x1
ffffffffc0200c1c:	b3860613          	addi	a2,a2,-1224 # ffffffffc0201750 <etext+0x28a>
ffffffffc0200c20:	06e00593          	li	a1,110
ffffffffc0200c24:	00001517          	auipc	a0,0x1
ffffffffc0200c28:	b4450513          	addi	a0,a0,-1212 # ffffffffc0201768 <etext+0x2a2>
ffffffffc0200c2c:	d96ff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0200c30 <buddy_alloc_pages>:
buddy_alloc_pages(size_t n) {
ffffffffc0200c30:	7179                	addi	sp,sp,-48
ffffffffc0200c32:	f406                	sd	ra,40(sp)
ffffffffc0200c34:	f022                	sd	s0,32(sp)
ffffffffc0200c36:	ec26                	sd	s1,24(sp)
ffffffffc0200c38:	e84a                	sd	s2,16(sp)
ffffffffc0200c3a:	e44e                	sd	s3,8(sp)
ffffffffc0200c3c:	e052                	sd	s4,0(sp)
    assert(n > 0);
ffffffffc0200c3e:	cd51                	beqz	a0,ffffffffc0200cda <buddy_alloc_pages+0xaa>
    if (n > nr_free) {
ffffffffc0200c40:	00004797          	auipc	a5,0x4
ffffffffc0200c44:	5d07b783          	ld	a5,1488(a5) # ffffffffc0205210 <nr_free>
ffffffffc0200c48:	04a7e163          	bltu	a5,a0,ffffffffc0200c8a <buddy_alloc_pages+0x5a>
    int order = 0;
ffffffffc0200c4c:	4481                	li	s1,0
    return (size_t)1 << order;
ffffffffc0200c4e:	4705                	li	a4,1
    while (order + 1 < BUDDY_MAX_ORDER && order_size(order) < n) {
ffffffffc0200c50:	46cd                	li	a3,19
ffffffffc0200c52:	a021                	j	ffffffffc0200c5a <buddy_alloc_pages+0x2a>
        order ++;
ffffffffc0200c54:	2485                	addiw	s1,s1,1
    while (order + 1 < BUDDY_MAX_ORDER && order_size(order) < n) {
ffffffffc0200c56:	06d48c63          	beq	s1,a3,ffffffffc0200cce <buddy_alloc_pages+0x9e>
    return (size_t)1 << order;
ffffffffc0200c5a:	009717b3          	sll	a5,a4,s1
    while (order + 1 < BUDDY_MAX_ORDER && order_size(order) < n) {
ffffffffc0200c5e:	fea7ebe3          	bltu	a5,a0,ffffffffc0200c54 <buddy_alloc_pages+0x24>
ffffffffc0200c62:	00149793          	slli	a5,s1,0x1
ffffffffc0200c66:	97a6                	add	a5,a5,s1
ffffffffc0200c68:	00379713          	slli	a4,a5,0x3
ffffffffc0200c6c:	00004797          	auipc	a5,0x4
ffffffffc0200c70:	3ac78793          	addi	a5,a5,940 # ffffffffc0205018 <free_area>
ffffffffc0200c74:	97ba                	add	a5,a5,a4
    int order = 0;
ffffffffc0200c76:	8426                	mv	s0,s1
    while (cur < BUDDY_MAX_ORDER && list_empty(&(free_area[cur].free_list))) {
ffffffffc0200c78:	4751                	li	a4,20
    return list->next == list;
ffffffffc0200c7a:	0087b903          	ld	s2,8(a5)
ffffffffc0200c7e:	03279063          	bne	a5,s2,ffffffffc0200c9e <buddy_alloc_pages+0x6e>
        cur ++;
ffffffffc0200c82:	2405                	addiw	s0,s0,1
    while (cur < BUDDY_MAX_ORDER && list_empty(&(free_area[cur].free_list))) {
ffffffffc0200c84:	07e1                	addi	a5,a5,24
ffffffffc0200c86:	fee41ae3          	bne	s0,a4,ffffffffc0200c7a <buddy_alloc_pages+0x4a>
        return NULL;
ffffffffc0200c8a:	4981                	li	s3,0
}
ffffffffc0200c8c:	70a2                	ld	ra,40(sp)
ffffffffc0200c8e:	7402                	ld	s0,32(sp)
ffffffffc0200c90:	64e2                	ld	s1,24(sp)
ffffffffc0200c92:	6942                	ld	s2,16(sp)
ffffffffc0200c94:	6a02                	ld	s4,0(sp)
ffffffffc0200c96:	854e                	mv	a0,s3
ffffffffc0200c98:	69a2                	ld	s3,8(sp)
ffffffffc0200c9a:	6145                	addi	sp,sp,48
ffffffffc0200c9c:	8082                	ret
    struct Page *page = le2page(le, page_link);
ffffffffc0200c9e:	fe890993          	addi	s3,s2,-24
    buddy_remove_block(page, cur);
ffffffffc0200ca2:	85a2                	mv	a1,s0
ffffffffc0200ca4:	854e                	mv	a0,s3
ffffffffc0200ca6:	95dff0ef          	jal	ra,ffffffffc0200602 <buddy_remove_block>
        struct Page *half = page + order_size(cur);
ffffffffc0200caa:	02800a13          	li	s4,40
    while (cur > order) {
ffffffffc0200cae:	0084db63          	bge	s1,s0,ffffffffc0200cc4 <buddy_alloc_pages+0x94>
        cur --;
ffffffffc0200cb2:	347d                	addiw	s0,s0,-1
        struct Page *half = page + order_size(cur);
ffffffffc0200cb4:	008a1533          	sll	a0,s4,s0
        buddy_add_block(half, cur);
ffffffffc0200cb8:	85a2                	mv	a1,s0
ffffffffc0200cba:	954e                	add	a0,a0,s3
ffffffffc0200cbc:	da7ff0ef          	jal	ra,ffffffffc0200a62 <buddy_add_block>
    while (cur > order) {
ffffffffc0200cc0:	fe8499e3          	bne	s1,s0,ffffffffc0200cb2 <buddy_alloc_pages+0x82>
    page->property = 0;
ffffffffc0200cc4:	fe092c23          	sw	zero,-8(s2)
static inline void set_page_ref(struct Page *page, int val) { page->ref = val; }
ffffffffc0200cc8:	fe092423          	sw	zero,-24(s2)
    return page;
ffffffffc0200ccc:	b7c1                	j	ffffffffc0200c8c <buddy_alloc_pages+0x5c>
    if (order_size(order) < n) {
ffffffffc0200cce:	000807b7          	lui	a5,0x80
        return NULL;
ffffffffc0200cd2:	4981                	li	s3,0
    if (order_size(order) < n) {
ffffffffc0200cd4:	f8a7f7e3          	bgeu	a5,a0,ffffffffc0200c62 <buddy_alloc_pages+0x32>
ffffffffc0200cd8:	bf55                	j	ffffffffc0200c8c <buddy_alloc_pages+0x5c>
    assert(n > 0);
ffffffffc0200cda:	00001697          	auipc	a3,0x1
ffffffffc0200cde:	cd668693          	addi	a3,a3,-810 # ffffffffc02019b0 <etext+0x4ea>
ffffffffc0200ce2:	00001617          	auipc	a2,0x1
ffffffffc0200ce6:	a6e60613          	addi	a2,a2,-1426 # ffffffffc0201750 <etext+0x28a>
ffffffffc0200cea:	04900593          	li	a1,73
ffffffffc0200cee:	00001517          	auipc	a0,0x1
ffffffffc0200cf2:	a7a50513          	addi	a0,a0,-1414 # ffffffffc0201768 <etext+0x2a2>
ffffffffc0200cf6:	cccff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0200cfa <buddy_init_memmap>:
buddy_init_memmap(struct Page *base, size_t n) {
ffffffffc0200cfa:	7139                	addi	sp,sp,-64
ffffffffc0200cfc:	fc06                	sd	ra,56(sp)
ffffffffc0200cfe:	f822                	sd	s0,48(sp)
ffffffffc0200d00:	f426                	sd	s1,40(sp)
ffffffffc0200d02:	f04a                	sd	s2,32(sp)
ffffffffc0200d04:	ec4e                	sd	s3,24(sp)
ffffffffc0200d06:	e852                	sd	s4,16(sp)
ffffffffc0200d08:	e456                	sd	s5,8(sp)
    assert(n > 0);
ffffffffc0200d0a:	cde9                	beqz	a1,ffffffffc0200de4 <buddy_init_memmap+0xea>
    for (; p != base + n; p ++) {
ffffffffc0200d0c:	00259613          	slli	a2,a1,0x2
ffffffffc0200d10:	962e                	add	a2,a2,a1
ffffffffc0200d12:	060e                	slli	a2,a2,0x3
ffffffffc0200d14:	962a                	add	a2,a2,a0
ffffffffc0200d16:	87aa                	mv	a5,a0
ffffffffc0200d18:	872a                	mv	a4,a0
ffffffffc0200d1a:	00c50f63          	beq	a0,a2,ffffffffc0200d38 <buddy_init_memmap+0x3e>
        assert(PageReserved(p));
ffffffffc0200d1e:	6714                	ld	a3,8(a4)
ffffffffc0200d20:	8a85                	andi	a3,a3,1
ffffffffc0200d22:	c2cd                	beqz	a3,ffffffffc0200dc4 <buddy_init_memmap+0xca>
        p->flags = p->property = 0;
ffffffffc0200d24:	00072823          	sw	zero,16(a4)
ffffffffc0200d28:	00073423          	sd	zero,8(a4)
ffffffffc0200d2c:	00072023          	sw	zero,0(a4)
    for (; p != base + n; p ++) {
ffffffffc0200d30:	02870713          	addi	a4,a4,40
ffffffffc0200d34:	fec715e3          	bne	a4,a2,ffffffffc0200d1e <buddy_init_memmap+0x24>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200d38:	00004917          	auipc	s2,0x4
ffffffffc0200d3c:	4e890913          	addi	s2,s2,1256 # ffffffffc0205220 <pages>
ffffffffc0200d40:	00093503          	ld	a0,0(s2)
ffffffffc0200d44:	00001497          	auipc	s1,0x1
ffffffffc0200d48:	0cc4b483          	ld	s1,204(s1) # ffffffffc0201e10 <nbase>
    return (size_t)1 << order;
ffffffffc0200d4c:	4a05                	li	s4,1
ffffffffc0200d4e:	40a78433          	sub	s0,a5,a0
ffffffffc0200d52:	840d                	srai	s0,s0,0x3
ffffffffc0200d54:	00001797          	auipc	a5,0x1
ffffffffc0200d58:	0ac7b783          	ld	a5,172(a5) # ffffffffc0201e00 <error_string+0x38>
ffffffffc0200d5c:	02f40433          	mul	s0,s0,a5
        while (order + 1 < BUDDY_MAX_ORDER
ffffffffc0200d60:	4acd                	li	s5,19
ffffffffc0200d62:	9426                	add	s0,s0,s1
    size_t end = pfn + n;
ffffffffc0200d64:	008589b3          	add	s3,a1,s0
    while (pfn < end) {
ffffffffc0200d68:	05347163          	bgeu	s0,s3,ffffffffc0200daa <buddy_init_memmap+0xb0>
        int order = 0;
ffffffffc0200d6c:	4581                	li	a1,0
ffffffffc0200d6e:	86ae                	mv	a3,a1
               && (pfn & (order_size(order + 1) - 1)) == 0   // 起始 pfn 按 2^(order+1) 对齐
ffffffffc0200d70:	2585                	addiw	a1,a1,1
    return (size_t)1 << order;
ffffffffc0200d72:	00ba17b3          	sll	a5,s4,a1
               && (pfn & (order_size(order + 1) - 1)) == 0   // 起始 pfn 按 2^(order+1) 对齐
ffffffffc0200d76:	fff78713          	addi	a4,a5,-1
ffffffffc0200d7a:	8f61                	and	a4,a4,s0
ffffffffc0200d7c:	e321                	bnez	a4,ffffffffc0200dbc <buddy_init_memmap+0xc2>
               && pfn + order_size(order + 1) <= end) {       
ffffffffc0200d7e:	97a2                	add	a5,a5,s0
ffffffffc0200d80:	02f9ee63          	bltu	s3,a5,ffffffffc0200dbc <buddy_init_memmap+0xc2>
        while (order + 1 < BUDDY_MAX_ORDER
ffffffffc0200d84:	ff5595e3          	bne	a1,s5,ffffffffc0200d6e <buddy_init_memmap+0x74>
ffffffffc0200d88:	00080637          	lui	a2,0x80
        buddy_add_block(pages + (pfn - nbase), order);
ffffffffc0200d8c:	40940733          	sub	a4,s0,s1
ffffffffc0200d90:	00271793          	slli	a5,a4,0x2
ffffffffc0200d94:	97ba                	add	a5,a5,a4
ffffffffc0200d96:	078e                	slli	a5,a5,0x3
        pfn += order_size(order);
ffffffffc0200d98:	9432                	add	s0,s0,a2
        buddy_add_block(pages + (pfn - nbase), order);
ffffffffc0200d9a:	953e                	add	a0,a0,a5
ffffffffc0200d9c:	cc7ff0ef          	jal	ra,ffffffffc0200a62 <buddy_add_block>
    while (pfn < end) {
ffffffffc0200da0:	01347563          	bgeu	s0,s3,ffffffffc0200daa <buddy_init_memmap+0xb0>
        buddy_add_block(pages + (pfn - nbase), order);
ffffffffc0200da4:	00093503          	ld	a0,0(s2)
ffffffffc0200da8:	b7d1                	j	ffffffffc0200d6c <buddy_init_memmap+0x72>
}
ffffffffc0200daa:	70e2                	ld	ra,56(sp)
ffffffffc0200dac:	7442                	ld	s0,48(sp)
ffffffffc0200dae:	74a2                	ld	s1,40(sp)
ffffffffc0200db0:	7902                	ld	s2,32(sp)
ffffffffc0200db2:	69e2                	ld	s3,24(sp)
ffffffffc0200db4:	6a42                	ld	s4,16(sp)
ffffffffc0200db6:	6aa2                	ld	s5,8(sp)
ffffffffc0200db8:	6121                	addi	sp,sp,64
ffffffffc0200dba:	8082                	ret
    return (size_t)1 << order;
ffffffffc0200dbc:	00da1633          	sll	a2,s4,a3
ffffffffc0200dc0:	85b6                	mv	a1,a3
ffffffffc0200dc2:	b7e9                	j	ffffffffc0200d8c <buddy_init_memmap+0x92>
        assert(PageReserved(p));
ffffffffc0200dc4:	00001697          	auipc	a3,0x1
ffffffffc0200dc8:	c1c68693          	addi	a3,a3,-996 # ffffffffc02019e0 <etext+0x51a>
ffffffffc0200dcc:	00001617          	auipc	a2,0x1
ffffffffc0200dd0:	98460613          	addi	a2,a2,-1660 # ffffffffc0201750 <etext+0x28a>
ffffffffc0200dd4:	03400593          	li	a1,52
ffffffffc0200dd8:	00001517          	auipc	a0,0x1
ffffffffc0200ddc:	99050513          	addi	a0,a0,-1648 # ffffffffc0201768 <etext+0x2a2>
ffffffffc0200de0:	be2ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    assert(n > 0);
ffffffffc0200de4:	00001697          	auipc	a3,0x1
ffffffffc0200de8:	bcc68693          	addi	a3,a3,-1076 # ffffffffc02019b0 <etext+0x4ea>
ffffffffc0200dec:	00001617          	auipc	a2,0x1
ffffffffc0200df0:	96460613          	addi	a2,a2,-1692 # ffffffffc0201750 <etext+0x28a>
ffffffffc0200df4:	03100593          	li	a1,49
ffffffffc0200df8:	00001517          	auipc	a0,0x1
ffffffffc0200dfc:	97050513          	addi	a0,a0,-1680 # ffffffffc0201768 <etext+0x2a2>
ffffffffc0200e00:	bc2ff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0200e04 <alloc_pages>:
}

// alloc_pages - call pmm->alloc_pages to allocate a continuous n*PAGESIZE
// memory
struct Page *alloc_pages(size_t n) {
    return pmm_manager->alloc_pages(n);
ffffffffc0200e04:	00004797          	auipc	a5,0x4
ffffffffc0200e08:	4247b783          	ld	a5,1060(a5) # ffffffffc0205228 <pmm_manager>
ffffffffc0200e0c:	6f9c                	ld	a5,24(a5)
ffffffffc0200e0e:	8782                	jr	a5

ffffffffc0200e10 <free_pages>:
}

// free_pages - call pmm->free_pages to free a continuous n*PAGESIZE memory
void free_pages(struct Page *base, size_t n) {
    pmm_manager->free_pages(base, n);
ffffffffc0200e10:	00004797          	auipc	a5,0x4
ffffffffc0200e14:	4187b783          	ld	a5,1048(a5) # ffffffffc0205228 <pmm_manager>
ffffffffc0200e18:	739c                	ld	a5,32(a5)
ffffffffc0200e1a:	8782                	jr	a5

ffffffffc0200e1c <pmm_init>:
    pmm_manager = &buddy_fit_pmm_manager;
ffffffffc0200e1c:	00001797          	auipc	a5,0x1
ffffffffc0200e20:	bec78793          	addi	a5,a5,-1044 # ffffffffc0201a08 <buddy_fit_pmm_manager>
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc0200e24:	638c                	ld	a1,0(a5)
    }
    init_memmap(pages + (PPN(free_pa) - nbase), (maxpa - free_pa) / PGSIZE);
}

/* pmm_init - initialize the physical memory management */
void pmm_init(void) {
ffffffffc0200e26:	1101                	addi	sp,sp,-32
ffffffffc0200e28:	e822                	sd	s0,16(sp)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc0200e2a:	00001517          	auipc	a0,0x1
ffffffffc0200e2e:	c1650513          	addi	a0,a0,-1002 # ffffffffc0201a40 <buddy_fit_pmm_manager+0x38>
    pmm_manager = &buddy_fit_pmm_manager;
ffffffffc0200e32:	00004417          	auipc	s0,0x4
ffffffffc0200e36:	3f640413          	addi	s0,s0,1014 # ffffffffc0205228 <pmm_manager>
void pmm_init(void) {
ffffffffc0200e3a:	ec06                	sd	ra,24(sp)
ffffffffc0200e3c:	e04a                	sd	s2,0(sp)
    pmm_manager = &buddy_fit_pmm_manager;
ffffffffc0200e3e:	e01c                	sd	a5,0(s0)
void pmm_init(void) {
ffffffffc0200e40:	e426                	sd	s1,8(sp)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc0200e42:	b0aff0ef          	jal	ra,ffffffffc020014c <cprintf>
    pmm_manager->init();
ffffffffc0200e46:	601c                	ld	a5,0(s0)
ffffffffc0200e48:	679c                	ld	a5,8(a5)
ffffffffc0200e4a:	9782                	jalr	a5
    uint64_t mem_base = get_memory_base();
ffffffffc0200e4c:	f70ff0ef          	jal	ra,ffffffffc02005bc <get_memory_base>
ffffffffc0200e50:	892a                	mv	s2,a0
    uint64_t mem_size = get_memory_size();
ffffffffc0200e52:	f74ff0ef          	jal	ra,ffffffffc02005c6 <get_memory_size>
    if (mem_base != DRAM_BASE || mem_size == 0 ||
ffffffffc0200e56:	4785                	li	a5,1
ffffffffc0200e58:	07fe                	slli	a5,a5,0x1f
ffffffffc0200e5a:	14f91363          	bne	s2,a5,ffffffffc0200fa0 <pmm_init+0x184>
ffffffffc0200e5e:	14050163          	beqz	a0,ffffffffc0200fa0 <pmm_init+0x184>
ffffffffc0200e62:	800007b7          	lui	a5,0x80000
        mem_base + mem_size < mem_base) {
ffffffffc0200e66:	012504b3          	add	s1,a0,s2
    if (mem_base != DRAM_BASE || mem_size == 0 ||
ffffffffc0200e6a:	fff7c793          	not	a5,a5
ffffffffc0200e6e:	1297f963          	bgeu	a5,s1,ffffffffc0200fa0 <pmm_init+0x184>
    cprintf("physical memory: [0x%016lx, 0x%016lx)\n", mem_base, mem_end);
ffffffffc0200e72:	8626                	mv	a2,s1
ffffffffc0200e74:	85ca                	mv	a1,s2
ffffffffc0200e76:	00001517          	auipc	a0,0x1
ffffffffc0200e7a:	c1a50513          	addi	a0,a0,-998 # ffffffffc0201a90 <buddy_fit_pmm_manager+0x88>
ffffffffc0200e7e:	aceff0ef          	jal	ra,ffffffffc020014c <cprintf>
    uint64_t maxpa = mem_end < PHYSICAL_MEMORY_END ? mem_end : PHYSICAL_MEMORY_END;
ffffffffc0200e82:	47c5                	li	a5,17
ffffffffc0200e84:	07ee                	slli	a5,a5,0x1b
ffffffffc0200e86:	1097eb63          	bltu	a5,s1,ffffffffc0200f9c <pmm_init+0x180>
    maxpa = ROUNDDOWN(maxpa, PGSIZE);
ffffffffc0200e8a:	77fd                	lui	a5,0xfffff
    if (maxpa <= KERNEL_BEGIN_PADDR) {
ffffffffc0200e8c:	40100713          	li	a4,1025
    maxpa = ROUNDDOWN(maxpa, PGSIZE);
ffffffffc0200e90:	00f4f5b3          	and	a1,s1,a5
    if (maxpa <= KERNEL_BEGIN_PADDR) {
ffffffffc0200e94:	0756                	slli	a4,a4,0x15
ffffffffc0200e96:	14b77963          	bgeu	a4,a1,ffffffffc0200fe8 <pmm_init+0x1cc>
    pages = (struct Page *)ROUNDUP((uintptr_t)end, PGSIZE);
ffffffffc0200e9a:	00005697          	auipc	a3,0x5
ffffffffc0200e9e:	3ad68693          	addi	a3,a3,941 # ffffffffc0206247 <end+0xfff>
ffffffffc0200ea2:	8efd                	and	a3,a3,a5
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc0200ea4:	5675                	li	a2,-3
    npage = PPN(maxpa);
ffffffffc0200ea6:	00c5d313          	srli	t1,a1,0xc
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc0200eaa:	00004497          	auipc	s1,0x4
ffffffffc0200eae:	39648493          	addi	s1,s1,918 # ffffffffc0205240 <va_pa_offset>
ffffffffc0200eb2:	067a                	slli	a2,a2,0x1e
    npage = PPN(maxpa);
ffffffffc0200eb4:	00004717          	auipc	a4,0x4
ffffffffc0200eb8:	36673223          	sd	t1,868(a4) # ffffffffc0205218 <npage>
    pages = (struct Page *)ROUNDUP((uintptr_t)end, PGSIZE);
ffffffffc0200ebc:	00004717          	auipc	a4,0x4
ffffffffc0200ec0:	36d73223          	sd	a3,868(a4) # ffffffffc0205220 <pages>
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc0200ec4:	e090                	sd	a2,0(s1)
    uintptr_t pages_pa = PADDR(pages);
ffffffffc0200ec6:	c0200737          	lui	a4,0xc0200
    pages = (struct Page *)ROUNDUP((uintptr_t)end, PGSIZE);
ffffffffc0200eca:	8536                	mv	a0,a3
    uintptr_t pages_pa = PADDR(pages);
ffffffffc0200ecc:	12e6ea63          	bltu	a3,a4,ffffffffc0201000 <pmm_init+0x1e4>
ffffffffc0200ed0:	488d                	li	a7,3
ffffffffc0200ed2:	08fa                	slli	a7,a7,0x1e
    size_t page_count = npage - nbase;
ffffffffc0200ed4:	fff80737          	lui	a4,0xfff80
    uintptr_t pages_pa = PADDR(pages);
ffffffffc0200ed8:	98b6                	add	a7,a7,a3
    size_t page_count = npage - nbase;
ffffffffc0200eda:	00e30833          	add	a6,t1,a4
    if (pages_pa < KERNEL_BEGIN_PADDR || pages_pa >= maxpa ||
ffffffffc0200ede:	0cb8fd63          	bgeu	a7,a1,ffffffffc0200fb8 <pmm_init+0x19c>
        page_count > (maxpa - pages_pa) / sizeof(struct Page)) {
ffffffffc0200ee2:	8e15                	sub	a2,a2,a3
ffffffffc0200ee4:	962e                	add	a2,a2,a1
ffffffffc0200ee6:	02800713          	li	a4,40
ffffffffc0200eea:	02e65633          	divu	a2,a2,a4
    if (pages_pa < KERNEL_BEGIN_PADDR || pages_pa >= maxpa ||
ffffffffc0200eee:	0d066563          	bltu	a2,a6,ffffffffc0200fb8 <pmm_init+0x19c>
    uintptr_t free_pa = ROUNDUP(pages_pa + page_count * sizeof(struct Page), PGSIZE);
ffffffffc0200ef2:	00281713          	slli	a4,a6,0x2
ffffffffc0200ef6:	9742                	add	a4,a4,a6
ffffffffc0200ef8:	00001617          	auipc	a2,0x1
ffffffffc0200efc:	f1063603          	ld	a2,-240(a2) # ffffffffc0201e08 <error_string+0x40>
ffffffffc0200f00:	070e                	slli	a4,a4,0x3
ffffffffc0200f02:	9636                	add	a2,a2,a3
ffffffffc0200f04:	9732                	add	a4,a4,a2
ffffffffc0200f06:	8f7d                	and	a4,a4,a5
    if (free_pa >= maxpa) {
ffffffffc0200f08:	0cb77463          	bgeu	a4,a1,ffffffffc0200fd0 <pmm_init+0x1b4>
ffffffffc0200f0c:	00231793          	slli	a5,t1,0x2
ffffffffc0200f10:	979a                	add	a5,a5,t1
ffffffffc0200f12:	fec00637          	lui	a2,0xfec00
ffffffffc0200f16:	9636                	add	a2,a2,a3
ffffffffc0200f18:	078e                	slli	a5,a5,0x3
ffffffffc0200f1a:	97b2                	add	a5,a5,a2
        SetPageReserved(&pages[i]);
ffffffffc0200f1c:	4605                	li	a2,1
ffffffffc0200f1e:	e690                	sd	a2,8(a3)
        pages[i].property = 0;
ffffffffc0200f20:	0006a823          	sw	zero,16(a3)
static inline void set_page_ref(struct Page *page, int val) { page->ref = val; }
ffffffffc0200f24:	0006a023          	sw	zero,0(a3)
    for (size_t i = 0; i < page_count; i ++) {
ffffffffc0200f28:	02868693          	addi	a3,a3,40
ffffffffc0200f2c:	fed799e3          	bne	a5,a3,ffffffffc0200f1e <pmm_init+0x102>
    pmm_manager->init_memmap(base, n);
ffffffffc0200f30:	6014                	ld	a3,0(s0)
    init_memmap(pages + (PPN(free_pa) - nbase), (maxpa - free_pa) / PGSIZE);
ffffffffc0200f32:	00c75613          	srli	a2,a4,0xc
ffffffffc0200f36:	00a75793          	srli	a5,a4,0xa
ffffffffc0200f3a:	97b2                	add	a5,a5,a2
    pmm_manager->init_memmap(base, n);
ffffffffc0200f3c:	6a94                	ld	a3,16(a3)
    init_memmap(pages + (PPN(free_pa) - nbase), (maxpa - free_pa) / PGSIZE);
ffffffffc0200f3e:	8d99                	sub	a1,a1,a4
ffffffffc0200f40:	078e                	slli	a5,a5,0x3
ffffffffc0200f42:	fec00737          	lui	a4,0xfec00
ffffffffc0200f46:	97ba                	add	a5,a5,a4
    pmm_manager->init_memmap(base, n);
ffffffffc0200f48:	81b1                	srli	a1,a1,0xc
ffffffffc0200f4a:	953e                	add	a0,a0,a5
ffffffffc0200f4c:	9682                	jalr	a3
    satp_physical = PADDR(satp_virtual);
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
}

static void check_alloc_page(void) {
    pmm_manager->check();
ffffffffc0200f4e:	601c                	ld	a5,0(s0)
ffffffffc0200f50:	7b9c                	ld	a5,48(a5)
ffffffffc0200f52:	9782                	jalr	a5
    cprintf("check_alloc_page() succeeded!\n");
ffffffffc0200f54:	00001517          	auipc	a0,0x1
ffffffffc0200f58:	c0450513          	addi	a0,a0,-1020 # ffffffffc0201b58 <buddy_fit_pmm_manager+0x150>
ffffffffc0200f5c:	9f0ff0ef          	jal	ra,ffffffffc020014c <cprintf>
    satp_virtual = (pte_t*)boot_page_table_sv39;
ffffffffc0200f60:	00003597          	auipc	a1,0x3
ffffffffc0200f64:	0a058593          	addi	a1,a1,160 # ffffffffc0204000 <boot_page_table_sv39>
ffffffffc0200f68:	00004797          	auipc	a5,0x4
ffffffffc0200f6c:	2cb7b823          	sd	a1,720(a5) # ffffffffc0205238 <satp_virtual>
    satp_physical = PADDR(satp_virtual);
ffffffffc0200f70:	c02007b7          	lui	a5,0xc0200
ffffffffc0200f74:	0af5e263          	bltu	a1,a5,ffffffffc0201018 <pmm_init+0x1fc>
ffffffffc0200f78:	6090                	ld	a2,0(s1)
}
ffffffffc0200f7a:	6442                	ld	s0,16(sp)
ffffffffc0200f7c:	60e2                	ld	ra,24(sp)
ffffffffc0200f7e:	64a2                	ld	s1,8(sp)
ffffffffc0200f80:	6902                	ld	s2,0(sp)
    satp_physical = PADDR(satp_virtual);
ffffffffc0200f82:	40c58633          	sub	a2,a1,a2
ffffffffc0200f86:	00004797          	auipc	a5,0x4
ffffffffc0200f8a:	2ac7b523          	sd	a2,682(a5) # ffffffffc0205230 <satp_physical>
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc0200f8e:	00001517          	auipc	a0,0x1
ffffffffc0200f92:	bea50513          	addi	a0,a0,-1046 # ffffffffc0201b78 <buddy_fit_pmm_manager+0x170>
}
ffffffffc0200f96:	6105                	addi	sp,sp,32
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc0200f98:	9b4ff06f          	j	ffffffffc020014c <cprintf>
    uint64_t maxpa = mem_end < PHYSICAL_MEMORY_END ? mem_end : PHYSICAL_MEMORY_END;
ffffffffc0200f9c:	84be                	mv	s1,a5
ffffffffc0200f9e:	b5f5                	j	ffffffffc0200e8a <pmm_init+0x6e>
        panic("invalid physical memory from DTB");
ffffffffc0200fa0:	00001617          	auipc	a2,0x1
ffffffffc0200fa4:	ab860613          	addi	a2,a2,-1352 # ffffffffc0201a58 <buddy_fit_pmm_manager+0x50>
ffffffffc0200fa8:	04800593          	li	a1,72
ffffffffc0200fac:	00001517          	auipc	a0,0x1
ffffffffc0200fb0:	ad450513          	addi	a0,a0,-1324 # ffffffffc0201a80 <buddy_fit_pmm_manager+0x78>
ffffffffc0200fb4:	a0eff0ef          	jal	ra,ffffffffc02001c2 <__panic>
        panic("page descriptor array does not fit in physical memory");
ffffffffc0200fb8:	00001617          	auipc	a2,0x1
ffffffffc0200fbc:	b4860613          	addi	a2,a2,-1208 # ffffffffc0201b00 <buddy_fit_pmm_manager+0xf8>
ffffffffc0200fc0:	05b00593          	li	a1,91
ffffffffc0200fc4:	00001517          	auipc	a0,0x1
ffffffffc0200fc8:	abc50513          	addi	a0,a0,-1348 # ffffffffc0201a80 <buddy_fit_pmm_manager+0x78>
ffffffffc0200fcc:	9f6ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
        panic("no complete free physical page");
ffffffffc0200fd0:	00001617          	auipc	a2,0x1
ffffffffc0200fd4:	b6860613          	addi	a2,a2,-1176 # ffffffffc0201b38 <buddy_fit_pmm_manager+0x130>
ffffffffc0200fd8:	06000593          	li	a1,96
ffffffffc0200fdc:	00001517          	auipc	a0,0x1
ffffffffc0200fe0:	aa450513          	addi	a0,a0,-1372 # ffffffffc0201a80 <buddy_fit_pmm_manager+0x78>
ffffffffc0200fe4:	9deff0ef          	jal	ra,ffffffffc02001c2 <__panic>
        panic("no manageable physical memory");
ffffffffc0200fe8:	00001617          	auipc	a2,0x1
ffffffffc0200fec:	ad060613          	addi	a2,a2,-1328 # ffffffffc0201ab8 <buddy_fit_pmm_manager+0xb0>
ffffffffc0200ff0:	05100593          	li	a1,81
ffffffffc0200ff4:	00001517          	auipc	a0,0x1
ffffffffc0200ff8:	a8c50513          	addi	a0,a0,-1396 # ffffffffc0201a80 <buddy_fit_pmm_manager+0x78>
ffffffffc0200ffc:	9c6ff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    uintptr_t pages_pa = PADDR(pages);
ffffffffc0201000:	00001617          	auipc	a2,0x1
ffffffffc0201004:	ad860613          	addi	a2,a2,-1320 # ffffffffc0201ad8 <buddy_fit_pmm_manager+0xd0>
ffffffffc0201008:	05700593          	li	a1,87
ffffffffc020100c:	00001517          	auipc	a0,0x1
ffffffffc0201010:	a7450513          	addi	a0,a0,-1420 # ffffffffc0201a80 <buddy_fit_pmm_manager+0x78>
ffffffffc0201014:	9aeff0ef          	jal	ra,ffffffffc02001c2 <__panic>
    satp_physical = PADDR(satp_virtual);
ffffffffc0201018:	86ae                	mv	a3,a1
ffffffffc020101a:	00001617          	auipc	a2,0x1
ffffffffc020101e:	abe60613          	addi	a2,a2,-1346 # ffffffffc0201ad8 <buddy_fit_pmm_manager+0xd0>
ffffffffc0201022:	07e00593          	li	a1,126
ffffffffc0201026:	00001517          	auipc	a0,0x1
ffffffffc020102a:	a5a50513          	addi	a0,a0,-1446 # ffffffffc0201a80 <buddy_fit_pmm_manager+0x78>
ffffffffc020102e:	994ff0ef          	jal	ra,ffffffffc02001c2 <__panic>

ffffffffc0201032 <printnum>:
 * */
static void
printnum(void (*putch)(int, void*), void *putdat,
        unsigned long long num, unsigned base, int width, int padc) {
    unsigned long long result = num;
    unsigned mod = do_div(result, base);
ffffffffc0201032:	02069813          	slli	a6,a3,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc0201036:	7179                	addi	sp,sp,-48
    unsigned mod = do_div(result, base);
ffffffffc0201038:	02085813          	srli	a6,a6,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc020103c:	e052                	sd	s4,0(sp)
    unsigned mod = do_div(result, base);
ffffffffc020103e:	03067a33          	remu	s4,a2,a6
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc0201042:	f022                	sd	s0,32(sp)
ffffffffc0201044:	ec26                	sd	s1,24(sp)
ffffffffc0201046:	e84a                	sd	s2,16(sp)
ffffffffc0201048:	f406                	sd	ra,40(sp)
ffffffffc020104a:	e44e                	sd	s3,8(sp)
ffffffffc020104c:	84aa                	mv	s1,a0
ffffffffc020104e:	892e                	mv	s2,a1
    // first recursively print all preceding (more significant) digits
    if (num >= base) {
        printnum(putch, putdat, result, base, width - 1, padc);
    } else {
        // print any needed pad characters before first digit
        while (-- width > 0)
ffffffffc0201050:	fff7041b          	addiw	s0,a4,-1
    unsigned mod = do_div(result, base);
ffffffffc0201054:	2a01                	sext.w	s4,s4
    if (num >= base) {
ffffffffc0201056:	03067e63          	bgeu	a2,a6,ffffffffc0201092 <printnum+0x60>
ffffffffc020105a:	89be                	mv	s3,a5
        while (-- width > 0)
ffffffffc020105c:	00805763          	blez	s0,ffffffffc020106a <printnum+0x38>
ffffffffc0201060:	347d                	addiw	s0,s0,-1
            putch(padc, putdat);
ffffffffc0201062:	85ca                	mv	a1,s2
ffffffffc0201064:	854e                	mv	a0,s3
ffffffffc0201066:	9482                	jalr	s1
        while (-- width > 0)
ffffffffc0201068:	fc65                	bnez	s0,ffffffffc0201060 <printnum+0x2e>
    }
    // then print this (the least significant) digit
    putch("0123456789abcdef"[mod], putdat);
ffffffffc020106a:	1a02                	slli	s4,s4,0x20
ffffffffc020106c:	00001797          	auipc	a5,0x1
ffffffffc0201070:	b4c78793          	addi	a5,a5,-1204 # ffffffffc0201bb8 <buddy_fit_pmm_manager+0x1b0>
ffffffffc0201074:	020a5a13          	srli	s4,s4,0x20
ffffffffc0201078:	9a3e                	add	s4,s4,a5
}
ffffffffc020107a:	7402                	ld	s0,32(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc020107c:	000a4503          	lbu	a0,0(s4)
}
ffffffffc0201080:	70a2                	ld	ra,40(sp)
ffffffffc0201082:	69a2                	ld	s3,8(sp)
ffffffffc0201084:	6a02                	ld	s4,0(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0201086:	85ca                	mv	a1,s2
ffffffffc0201088:	87a6                	mv	a5,s1
}
ffffffffc020108a:	6942                	ld	s2,16(sp)
ffffffffc020108c:	64e2                	ld	s1,24(sp)
ffffffffc020108e:	6145                	addi	sp,sp,48
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0201090:	8782                	jr	a5
        printnum(putch, putdat, result, base, width - 1, padc);
ffffffffc0201092:	03065633          	divu	a2,a2,a6
ffffffffc0201096:	8722                	mv	a4,s0
ffffffffc0201098:	f9bff0ef          	jal	ra,ffffffffc0201032 <printnum>
ffffffffc020109c:	b7f9                	j	ffffffffc020106a <printnum+0x38>

ffffffffc020109e <vprintfmt>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want printfmt() instead.
 * */
void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap) {
ffffffffc020109e:	7119                	addi	sp,sp,-128
ffffffffc02010a0:	f4a6                	sd	s1,104(sp)
ffffffffc02010a2:	f0ca                	sd	s2,96(sp)
ffffffffc02010a4:	ecce                	sd	s3,88(sp)
ffffffffc02010a6:	e8d2                	sd	s4,80(sp)
ffffffffc02010a8:	e4d6                	sd	s5,72(sp)
ffffffffc02010aa:	e0da                	sd	s6,64(sp)
ffffffffc02010ac:	fc5e                	sd	s7,56(sp)
ffffffffc02010ae:	f06a                	sd	s10,32(sp)
ffffffffc02010b0:	fc86                	sd	ra,120(sp)
ffffffffc02010b2:	f8a2                	sd	s0,112(sp)
ffffffffc02010b4:	f862                	sd	s8,48(sp)
ffffffffc02010b6:	f466                	sd	s9,40(sp)
ffffffffc02010b8:	ec6e                	sd	s11,24(sp)
ffffffffc02010ba:	892a                	mv	s2,a0
ffffffffc02010bc:	84ae                	mv	s1,a1
ffffffffc02010be:	8d32                	mv	s10,a2
ffffffffc02010c0:	8a36                	mv	s4,a3
    register int ch, err;
    unsigned long long num;
    int base, width, precision, lflag, altflag;

    while (1) {
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc02010c2:	02500993          	li	s3,37
            putch(ch, putdat);
        }

        // Process a %-escape sequence
        char padc = ' ';
        width = precision = -1;
ffffffffc02010c6:	5b7d                	li	s6,-1
ffffffffc02010c8:	00001a97          	auipc	s5,0x1
ffffffffc02010cc:	b24a8a93          	addi	s5,s5,-1244 # ffffffffc0201bec <buddy_fit_pmm_manager+0x1e4>
        case 'e':
            err = va_arg(ap, int);
            if (err < 0) {
                err = -err;
            }
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc02010d0:	00001b97          	auipc	s7,0x1
ffffffffc02010d4:	cf8b8b93          	addi	s7,s7,-776 # ffffffffc0201dc8 <error_string>
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc02010d8:	000d4503          	lbu	a0,0(s10)
ffffffffc02010dc:	001d0413          	addi	s0,s10,1
ffffffffc02010e0:	01350a63          	beq	a0,s3,ffffffffc02010f4 <vprintfmt+0x56>
            if (ch == '\0') {
ffffffffc02010e4:	c121                	beqz	a0,ffffffffc0201124 <vprintfmt+0x86>
            putch(ch, putdat);
ffffffffc02010e6:	85a6                	mv	a1,s1
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc02010e8:	0405                	addi	s0,s0,1
            putch(ch, putdat);
ffffffffc02010ea:	9902                	jalr	s2
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc02010ec:	fff44503          	lbu	a0,-1(s0)
ffffffffc02010f0:	ff351ae3          	bne	a0,s3,ffffffffc02010e4 <vprintfmt+0x46>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02010f4:	00044603          	lbu	a2,0(s0)
        char padc = ' ';
ffffffffc02010f8:	02000793          	li	a5,32
        lflag = altflag = 0;
ffffffffc02010fc:	4c81                	li	s9,0
ffffffffc02010fe:	4881                	li	a7,0
        width = precision = -1;
ffffffffc0201100:	5c7d                	li	s8,-1
ffffffffc0201102:	5dfd                	li	s11,-1
ffffffffc0201104:	05500513          	li	a0,85
                if (ch < '0' || ch > '9') {
ffffffffc0201108:	4825                	li	a6,9
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020110a:	fdd6059b          	addiw	a1,a2,-35
ffffffffc020110e:	0ff5f593          	zext.b	a1,a1
ffffffffc0201112:	00140d13          	addi	s10,s0,1
ffffffffc0201116:	04b56263          	bltu	a0,a1,ffffffffc020115a <vprintfmt+0xbc>
ffffffffc020111a:	058a                	slli	a1,a1,0x2
ffffffffc020111c:	95d6                	add	a1,a1,s5
ffffffffc020111e:	4194                	lw	a3,0(a1)
ffffffffc0201120:	96d6                	add	a3,a3,s5
ffffffffc0201122:	8682                	jr	a3
            for (fmt --; fmt[-1] != '%'; fmt --)
                /* do nothing */;
            break;
        }
    }
}
ffffffffc0201124:	70e6                	ld	ra,120(sp)
ffffffffc0201126:	7446                	ld	s0,112(sp)
ffffffffc0201128:	74a6                	ld	s1,104(sp)
ffffffffc020112a:	7906                	ld	s2,96(sp)
ffffffffc020112c:	69e6                	ld	s3,88(sp)
ffffffffc020112e:	6a46                	ld	s4,80(sp)
ffffffffc0201130:	6aa6                	ld	s5,72(sp)
ffffffffc0201132:	6b06                	ld	s6,64(sp)
ffffffffc0201134:	7be2                	ld	s7,56(sp)
ffffffffc0201136:	7c42                	ld	s8,48(sp)
ffffffffc0201138:	7ca2                	ld	s9,40(sp)
ffffffffc020113a:	7d02                	ld	s10,32(sp)
ffffffffc020113c:	6de2                	ld	s11,24(sp)
ffffffffc020113e:	6109                	addi	sp,sp,128
ffffffffc0201140:	8082                	ret
            padc = '0';
ffffffffc0201142:	87b2                	mv	a5,a2
            goto reswitch;
ffffffffc0201144:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201148:	846a                	mv	s0,s10
ffffffffc020114a:	00140d13          	addi	s10,s0,1
ffffffffc020114e:	fdd6059b          	addiw	a1,a2,-35
ffffffffc0201152:	0ff5f593          	zext.b	a1,a1
ffffffffc0201156:	fcb572e3          	bgeu	a0,a1,ffffffffc020111a <vprintfmt+0x7c>
            putch('%', putdat);
ffffffffc020115a:	85a6                	mv	a1,s1
ffffffffc020115c:	02500513          	li	a0,37
ffffffffc0201160:	9902                	jalr	s2
            for (fmt --; fmt[-1] != '%'; fmt --)
ffffffffc0201162:	fff44783          	lbu	a5,-1(s0)
ffffffffc0201166:	8d22                	mv	s10,s0
ffffffffc0201168:	f73788e3          	beq	a5,s3,ffffffffc02010d8 <vprintfmt+0x3a>
ffffffffc020116c:	ffed4783          	lbu	a5,-2(s10)
ffffffffc0201170:	1d7d                	addi	s10,s10,-1
ffffffffc0201172:	ff379de3          	bne	a5,s3,ffffffffc020116c <vprintfmt+0xce>
ffffffffc0201176:	b78d                	j	ffffffffc02010d8 <vprintfmt+0x3a>
                precision = precision * 10 + ch - '0';
ffffffffc0201178:	fd060c1b          	addiw	s8,a2,-48
                ch = *fmt;
ffffffffc020117c:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201180:	846a                	mv	s0,s10
                if (ch < '0' || ch > '9') {
ffffffffc0201182:	fd06069b          	addiw	a3,a2,-48
                ch = *fmt;
ffffffffc0201186:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc020118a:	02d86463          	bltu	a6,a3,ffffffffc02011b2 <vprintfmt+0x114>
                ch = *fmt;
ffffffffc020118e:	00144603          	lbu	a2,1(s0)
                precision = precision * 10 + ch - '0';
ffffffffc0201192:	002c169b          	slliw	a3,s8,0x2
ffffffffc0201196:	0186873b          	addw	a4,a3,s8
ffffffffc020119a:	0017171b          	slliw	a4,a4,0x1
ffffffffc020119e:	9f2d                	addw	a4,a4,a1
                if (ch < '0' || ch > '9') {
ffffffffc02011a0:	fd06069b          	addiw	a3,a2,-48
            for (precision = 0; ; ++ fmt) {
ffffffffc02011a4:	0405                	addi	s0,s0,1
                precision = precision * 10 + ch - '0';
ffffffffc02011a6:	fd070c1b          	addiw	s8,a4,-48
                ch = *fmt;
ffffffffc02011aa:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc02011ae:	fed870e3          	bgeu	a6,a3,ffffffffc020118e <vprintfmt+0xf0>
            if (width < 0)
ffffffffc02011b2:	f40ddce3          	bgez	s11,ffffffffc020110a <vprintfmt+0x6c>
                width = precision, precision = -1;
ffffffffc02011b6:	8de2                	mv	s11,s8
ffffffffc02011b8:	5c7d                	li	s8,-1
ffffffffc02011ba:	bf81                	j	ffffffffc020110a <vprintfmt+0x6c>
            if (width < 0)
ffffffffc02011bc:	fffdc693          	not	a3,s11
ffffffffc02011c0:	96fd                	srai	a3,a3,0x3f
ffffffffc02011c2:	00ddfdb3          	and	s11,s11,a3
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02011c6:	00144603          	lbu	a2,1(s0)
ffffffffc02011ca:	2d81                	sext.w	s11,s11
ffffffffc02011cc:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc02011ce:	bf35                	j	ffffffffc020110a <vprintfmt+0x6c>
            precision = va_arg(ap, int);
ffffffffc02011d0:	000a2c03          	lw	s8,0(s4)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02011d4:	00144603          	lbu	a2,1(s0)
            precision = va_arg(ap, int);
ffffffffc02011d8:	0a21                	addi	s4,s4,8
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc02011da:	846a                	mv	s0,s10
            goto process_precision;
ffffffffc02011dc:	bfd9                	j	ffffffffc02011b2 <vprintfmt+0x114>
    if (lflag >= 2) {
ffffffffc02011de:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc02011e0:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc02011e4:	01174463          	blt	a4,a7,ffffffffc02011ec <vprintfmt+0x14e>
    else if (lflag) {
ffffffffc02011e8:	1a088e63          	beqz	a7,ffffffffc02013a4 <vprintfmt+0x306>
        return va_arg(*ap, unsigned long);
ffffffffc02011ec:	000a3603          	ld	a2,0(s4)
ffffffffc02011f0:	46c1                	li	a3,16
ffffffffc02011f2:	8a2e                	mv	s4,a1
            printnum(putch, putdat, num, base, width, padc);
ffffffffc02011f4:	2781                	sext.w	a5,a5
ffffffffc02011f6:	876e                	mv	a4,s11
ffffffffc02011f8:	85a6                	mv	a1,s1
ffffffffc02011fa:	854a                	mv	a0,s2
ffffffffc02011fc:	e37ff0ef          	jal	ra,ffffffffc0201032 <printnum>
            break;
ffffffffc0201200:	bde1                	j	ffffffffc02010d8 <vprintfmt+0x3a>
            putch(va_arg(ap, int), putdat);
ffffffffc0201202:	000a2503          	lw	a0,0(s4)
ffffffffc0201206:	85a6                	mv	a1,s1
ffffffffc0201208:	0a21                	addi	s4,s4,8
ffffffffc020120a:	9902                	jalr	s2
            break;
ffffffffc020120c:	b5f1                	j	ffffffffc02010d8 <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc020120e:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201210:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc0201214:	01174463          	blt	a4,a7,ffffffffc020121c <vprintfmt+0x17e>
    else if (lflag) {
ffffffffc0201218:	18088163          	beqz	a7,ffffffffc020139a <vprintfmt+0x2fc>
        return va_arg(*ap, unsigned long);
ffffffffc020121c:	000a3603          	ld	a2,0(s4)
ffffffffc0201220:	46a9                	li	a3,10
ffffffffc0201222:	8a2e                	mv	s4,a1
ffffffffc0201224:	bfc1                	j	ffffffffc02011f4 <vprintfmt+0x156>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201226:	00144603          	lbu	a2,1(s0)
            altflag = 1;
ffffffffc020122a:	4c85                	li	s9,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020122c:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc020122e:	bdf1                	j	ffffffffc020110a <vprintfmt+0x6c>
            putch(ch, putdat);
ffffffffc0201230:	85a6                	mv	a1,s1
ffffffffc0201232:	02500513          	li	a0,37
ffffffffc0201236:	9902                	jalr	s2
            break;
ffffffffc0201238:	b545                	j	ffffffffc02010d8 <vprintfmt+0x3a>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc020123a:	00144603          	lbu	a2,1(s0)
            lflag ++;
ffffffffc020123e:	2885                	addiw	a7,a7,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201240:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc0201242:	b5e1                	j	ffffffffc020110a <vprintfmt+0x6c>
    if (lflag >= 2) {
ffffffffc0201244:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201246:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc020124a:	01174463          	blt	a4,a7,ffffffffc0201252 <vprintfmt+0x1b4>
    else if (lflag) {
ffffffffc020124e:	14088163          	beqz	a7,ffffffffc0201390 <vprintfmt+0x2f2>
        return va_arg(*ap, unsigned long);
ffffffffc0201252:	000a3603          	ld	a2,0(s4)
ffffffffc0201256:	46a1                	li	a3,8
ffffffffc0201258:	8a2e                	mv	s4,a1
ffffffffc020125a:	bf69                	j	ffffffffc02011f4 <vprintfmt+0x156>
            putch('0', putdat);
ffffffffc020125c:	03000513          	li	a0,48
ffffffffc0201260:	85a6                	mv	a1,s1
ffffffffc0201262:	e03e                	sd	a5,0(sp)
ffffffffc0201264:	9902                	jalr	s2
            putch('x', putdat);
ffffffffc0201266:	85a6                	mv	a1,s1
ffffffffc0201268:	07800513          	li	a0,120
ffffffffc020126c:	9902                	jalr	s2
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc020126e:	0a21                	addi	s4,s4,8
            goto number;
ffffffffc0201270:	6782                	ld	a5,0(sp)
ffffffffc0201272:	46c1                	li	a3,16
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc0201274:	ff8a3603          	ld	a2,-8(s4)
            goto number;
ffffffffc0201278:	bfb5                	j	ffffffffc02011f4 <vprintfmt+0x156>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc020127a:	000a3403          	ld	s0,0(s4)
ffffffffc020127e:	008a0713          	addi	a4,s4,8
ffffffffc0201282:	e03a                	sd	a4,0(sp)
ffffffffc0201284:	14040263          	beqz	s0,ffffffffc02013c8 <vprintfmt+0x32a>
            if (width > 0 && padc != '-') {
ffffffffc0201288:	0fb05763          	blez	s11,ffffffffc0201376 <vprintfmt+0x2d8>
ffffffffc020128c:	02d00693          	li	a3,45
ffffffffc0201290:	0cd79163          	bne	a5,a3,ffffffffc0201352 <vprintfmt+0x2b4>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201294:	00044783          	lbu	a5,0(s0)
ffffffffc0201298:	0007851b          	sext.w	a0,a5
ffffffffc020129c:	cf85                	beqz	a5,ffffffffc02012d4 <vprintfmt+0x236>
ffffffffc020129e:	00140a13          	addi	s4,s0,1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc02012a2:	05e00413          	li	s0,94
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc02012a6:	000c4563          	bltz	s8,ffffffffc02012b0 <vprintfmt+0x212>
ffffffffc02012aa:	3c7d                	addiw	s8,s8,-1
ffffffffc02012ac:	036c0263          	beq	s8,s6,ffffffffc02012d0 <vprintfmt+0x232>
                    putch('?', putdat);
ffffffffc02012b0:	85a6                	mv	a1,s1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc02012b2:	0e0c8e63          	beqz	s9,ffffffffc02013ae <vprintfmt+0x310>
ffffffffc02012b6:	3781                	addiw	a5,a5,-32
ffffffffc02012b8:	0ef47b63          	bgeu	s0,a5,ffffffffc02013ae <vprintfmt+0x310>
                    putch('?', putdat);
ffffffffc02012bc:	03f00513          	li	a0,63
ffffffffc02012c0:	9902                	jalr	s2
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc02012c2:	000a4783          	lbu	a5,0(s4)
ffffffffc02012c6:	3dfd                	addiw	s11,s11,-1
ffffffffc02012c8:	0a05                	addi	s4,s4,1
ffffffffc02012ca:	0007851b          	sext.w	a0,a5
ffffffffc02012ce:	ffe1                	bnez	a5,ffffffffc02012a6 <vprintfmt+0x208>
            for (; width > 0; width --) {
ffffffffc02012d0:	01b05963          	blez	s11,ffffffffc02012e2 <vprintfmt+0x244>
ffffffffc02012d4:	3dfd                	addiw	s11,s11,-1
                putch(' ', putdat);
ffffffffc02012d6:	85a6                	mv	a1,s1
ffffffffc02012d8:	02000513          	li	a0,32
ffffffffc02012dc:	9902                	jalr	s2
            for (; width > 0; width --) {
ffffffffc02012de:	fe0d9be3          	bnez	s11,ffffffffc02012d4 <vprintfmt+0x236>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc02012e2:	6a02                	ld	s4,0(sp)
ffffffffc02012e4:	bbd5                	j	ffffffffc02010d8 <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc02012e6:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc02012e8:	008a0c93          	addi	s9,s4,8
    if (lflag >= 2) {
ffffffffc02012ec:	01174463          	blt	a4,a7,ffffffffc02012f4 <vprintfmt+0x256>
    else if (lflag) {
ffffffffc02012f0:	08088d63          	beqz	a7,ffffffffc020138a <vprintfmt+0x2ec>
        return va_arg(*ap, long);
ffffffffc02012f4:	000a3403          	ld	s0,0(s4)
            if ((long long)num < 0) {
ffffffffc02012f8:	0a044d63          	bltz	s0,ffffffffc02013b2 <vprintfmt+0x314>
            num = getint(&ap, lflag);
ffffffffc02012fc:	8622                	mv	a2,s0
ffffffffc02012fe:	8a66                	mv	s4,s9
ffffffffc0201300:	46a9                	li	a3,10
ffffffffc0201302:	bdcd                	j	ffffffffc02011f4 <vprintfmt+0x156>
            err = va_arg(ap, int);
ffffffffc0201304:	000a2783          	lw	a5,0(s4)
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0201308:	4719                	li	a4,6
            err = va_arg(ap, int);
ffffffffc020130a:	0a21                	addi	s4,s4,8
            if (err < 0) {
ffffffffc020130c:	41f7d69b          	sraiw	a3,a5,0x1f
ffffffffc0201310:	8fb5                	xor	a5,a5,a3
ffffffffc0201312:	40d786bb          	subw	a3,a5,a3
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0201316:	02d74163          	blt	a4,a3,ffffffffc0201338 <vprintfmt+0x29a>
ffffffffc020131a:	00369793          	slli	a5,a3,0x3
ffffffffc020131e:	97de                	add	a5,a5,s7
ffffffffc0201320:	639c                	ld	a5,0(a5)
ffffffffc0201322:	cb99                	beqz	a5,ffffffffc0201338 <vprintfmt+0x29a>
                printfmt(putch, putdat, "%s", p);
ffffffffc0201324:	86be                	mv	a3,a5
ffffffffc0201326:	00001617          	auipc	a2,0x1
ffffffffc020132a:	8c260613          	addi	a2,a2,-1854 # ffffffffc0201be8 <buddy_fit_pmm_manager+0x1e0>
ffffffffc020132e:	85a6                	mv	a1,s1
ffffffffc0201330:	854a                	mv	a0,s2
ffffffffc0201332:	0ce000ef          	jal	ra,ffffffffc0201400 <printfmt>
ffffffffc0201336:	b34d                	j	ffffffffc02010d8 <vprintfmt+0x3a>
                printfmt(putch, putdat, "error %d", err);
ffffffffc0201338:	00001617          	auipc	a2,0x1
ffffffffc020133c:	8a060613          	addi	a2,a2,-1888 # ffffffffc0201bd8 <buddy_fit_pmm_manager+0x1d0>
ffffffffc0201340:	85a6                	mv	a1,s1
ffffffffc0201342:	854a                	mv	a0,s2
ffffffffc0201344:	0bc000ef          	jal	ra,ffffffffc0201400 <printfmt>
ffffffffc0201348:	bb41                	j	ffffffffc02010d8 <vprintfmt+0x3a>
                p = "(null)";
ffffffffc020134a:	00001417          	auipc	s0,0x1
ffffffffc020134e:	88640413          	addi	s0,s0,-1914 # ffffffffc0201bd0 <buddy_fit_pmm_manager+0x1c8>
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc0201352:	85e2                	mv	a1,s8
ffffffffc0201354:	8522                	mv	a0,s0
ffffffffc0201356:	e43e                	sd	a5,8(sp)
ffffffffc0201358:	0fc000ef          	jal	ra,ffffffffc0201454 <strnlen>
ffffffffc020135c:	40ad8dbb          	subw	s11,s11,a0
ffffffffc0201360:	01b05b63          	blez	s11,ffffffffc0201376 <vprintfmt+0x2d8>
                    putch(padc, putdat);
ffffffffc0201364:	67a2                	ld	a5,8(sp)
ffffffffc0201366:	00078a1b          	sext.w	s4,a5
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc020136a:	3dfd                	addiw	s11,s11,-1
                    putch(padc, putdat);
ffffffffc020136c:	85a6                	mv	a1,s1
ffffffffc020136e:	8552                	mv	a0,s4
ffffffffc0201370:	9902                	jalr	s2
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc0201372:	fe0d9ce3          	bnez	s11,ffffffffc020136a <vprintfmt+0x2cc>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201376:	00044783          	lbu	a5,0(s0)
ffffffffc020137a:	00140a13          	addi	s4,s0,1
ffffffffc020137e:	0007851b          	sext.w	a0,a5
ffffffffc0201382:	d3a5                	beqz	a5,ffffffffc02012e2 <vprintfmt+0x244>
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0201384:	05e00413          	li	s0,94
ffffffffc0201388:	bf39                	j	ffffffffc02012a6 <vprintfmt+0x208>
        return va_arg(*ap, int);
ffffffffc020138a:	000a2403          	lw	s0,0(s4)
ffffffffc020138e:	b7ad                	j	ffffffffc02012f8 <vprintfmt+0x25a>
        return va_arg(*ap, unsigned int);
ffffffffc0201390:	000a6603          	lwu	a2,0(s4)
ffffffffc0201394:	46a1                	li	a3,8
ffffffffc0201396:	8a2e                	mv	s4,a1
ffffffffc0201398:	bdb1                	j	ffffffffc02011f4 <vprintfmt+0x156>
ffffffffc020139a:	000a6603          	lwu	a2,0(s4)
ffffffffc020139e:	46a9                	li	a3,10
ffffffffc02013a0:	8a2e                	mv	s4,a1
ffffffffc02013a2:	bd89                	j	ffffffffc02011f4 <vprintfmt+0x156>
ffffffffc02013a4:	000a6603          	lwu	a2,0(s4)
ffffffffc02013a8:	46c1                	li	a3,16
ffffffffc02013aa:	8a2e                	mv	s4,a1
ffffffffc02013ac:	b5a1                	j	ffffffffc02011f4 <vprintfmt+0x156>
                    putch(ch, putdat);
ffffffffc02013ae:	9902                	jalr	s2
ffffffffc02013b0:	bf09                	j	ffffffffc02012c2 <vprintfmt+0x224>
                putch('-', putdat);
ffffffffc02013b2:	85a6                	mv	a1,s1
ffffffffc02013b4:	02d00513          	li	a0,45
ffffffffc02013b8:	e03e                	sd	a5,0(sp)
ffffffffc02013ba:	9902                	jalr	s2
                num = -(long long)num;
ffffffffc02013bc:	6782                	ld	a5,0(sp)
ffffffffc02013be:	8a66                	mv	s4,s9
ffffffffc02013c0:	40800633          	neg	a2,s0
ffffffffc02013c4:	46a9                	li	a3,10
ffffffffc02013c6:	b53d                	j	ffffffffc02011f4 <vprintfmt+0x156>
            if (width > 0 && padc != '-') {
ffffffffc02013c8:	03b05163          	blez	s11,ffffffffc02013ea <vprintfmt+0x34c>
ffffffffc02013cc:	02d00693          	li	a3,45
ffffffffc02013d0:	f6d79de3          	bne	a5,a3,ffffffffc020134a <vprintfmt+0x2ac>
                p = "(null)";
ffffffffc02013d4:	00000417          	auipc	s0,0x0
ffffffffc02013d8:	7fc40413          	addi	s0,s0,2044 # ffffffffc0201bd0 <buddy_fit_pmm_manager+0x1c8>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc02013dc:	02800793          	li	a5,40
ffffffffc02013e0:	02800513          	li	a0,40
ffffffffc02013e4:	00140a13          	addi	s4,s0,1
ffffffffc02013e8:	bd6d                	j	ffffffffc02012a2 <vprintfmt+0x204>
ffffffffc02013ea:	00000a17          	auipc	s4,0x0
ffffffffc02013ee:	7e7a0a13          	addi	s4,s4,2023 # ffffffffc0201bd1 <buddy_fit_pmm_manager+0x1c9>
ffffffffc02013f2:	02800513          	li	a0,40
ffffffffc02013f6:	02800793          	li	a5,40
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc02013fa:	05e00413          	li	s0,94
ffffffffc02013fe:	b565                	j	ffffffffc02012a6 <vprintfmt+0x208>

ffffffffc0201400 <printfmt>:
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0201400:	715d                	addi	sp,sp,-80
    va_start(ap, fmt);
ffffffffc0201402:	02810313          	addi	t1,sp,40
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0201406:	f436                	sd	a3,40(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc0201408:	869a                	mv	a3,t1
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc020140a:	ec06                	sd	ra,24(sp)
ffffffffc020140c:	f83a                	sd	a4,48(sp)
ffffffffc020140e:	fc3e                	sd	a5,56(sp)
ffffffffc0201410:	e0c2                	sd	a6,64(sp)
ffffffffc0201412:	e4c6                	sd	a7,72(sp)
    va_start(ap, fmt);
ffffffffc0201414:	e41a                	sd	t1,8(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc0201416:	c89ff0ef          	jal	ra,ffffffffc020109e <vprintfmt>
}
ffffffffc020141a:	60e2                	ld	ra,24(sp)
ffffffffc020141c:	6161                	addi	sp,sp,80
ffffffffc020141e:	8082                	ret

ffffffffc0201420 <sbi_console_putchar>:
uint64_t SBI_REMOTE_SFENCE_VMA_ASID = 7;
uint64_t SBI_SHUTDOWN = 8;

uint64_t sbi_call(uint64_t sbi_type, uint64_t arg0, uint64_t arg1, uint64_t arg2) {
    uint64_t ret_val;
    __asm__ volatile (
ffffffffc0201420:	4781                	li	a5,0
ffffffffc0201422:	00004717          	auipc	a4,0x4
ffffffffc0201426:	bee73703          	ld	a4,-1042(a4) # ffffffffc0205010 <SBI_CONSOLE_PUTCHAR>
ffffffffc020142a:	88ba                	mv	a7,a4
ffffffffc020142c:	852a                	mv	a0,a0
ffffffffc020142e:	85be                	mv	a1,a5
ffffffffc0201430:	863e                	mv	a2,a5
ffffffffc0201432:	00000073          	ecall
ffffffffc0201436:	87aa                	mv	a5,a0
    return ret_val;
}

void sbi_console_putchar(unsigned char ch) {
    sbi_call(SBI_CONSOLE_PUTCHAR, ch, 0, 0);
}
ffffffffc0201438:	8082                	ret

ffffffffc020143a <strlen>:
 * The strlen() function returns the length of string @s.
 * */
size_t
strlen(const char *s) {
    size_t cnt = 0;
    while (*s ++ != '\0') {
ffffffffc020143a:	00054783          	lbu	a5,0(a0)
strlen(const char *s) {
ffffffffc020143e:	872a                	mv	a4,a0
    size_t cnt = 0;
ffffffffc0201440:	4501                	li	a0,0
    while (*s ++ != '\0') {
ffffffffc0201442:	cb81                	beqz	a5,ffffffffc0201452 <strlen+0x18>
        cnt ++;
ffffffffc0201444:	0505                	addi	a0,a0,1
    while (*s ++ != '\0') {
ffffffffc0201446:	00a707b3          	add	a5,a4,a0
ffffffffc020144a:	0007c783          	lbu	a5,0(a5)
ffffffffc020144e:	fbfd                	bnez	a5,ffffffffc0201444 <strlen+0xa>
ffffffffc0201450:	8082                	ret
    }
    return cnt;
}
ffffffffc0201452:	8082                	ret

ffffffffc0201454 <strnlen>:
 * @len if there is no '\0' character among the first @len characters
 * pointed by @s.
 * */
size_t
strnlen(const char *s, size_t len) {
    size_t cnt = 0;
ffffffffc0201454:	4781                	li	a5,0
    while (cnt < len && *s ++ != '\0') {
ffffffffc0201456:	e589                	bnez	a1,ffffffffc0201460 <strnlen+0xc>
ffffffffc0201458:	a811                	j	ffffffffc020146c <strnlen+0x18>
        cnt ++;
ffffffffc020145a:	0785                	addi	a5,a5,1
    while (cnt < len && *s ++ != '\0') {
ffffffffc020145c:	00f58863          	beq	a1,a5,ffffffffc020146c <strnlen+0x18>
ffffffffc0201460:	00f50733          	add	a4,a0,a5
ffffffffc0201464:	00074703          	lbu	a4,0(a4)
ffffffffc0201468:	fb6d                	bnez	a4,ffffffffc020145a <strnlen+0x6>
ffffffffc020146a:	85be                	mv	a1,a5
    }
    return cnt;
}
ffffffffc020146c:	852e                	mv	a0,a1
ffffffffc020146e:	8082                	ret

ffffffffc0201470 <strcmp>:
int
strcmp(const char *s1, const char *s2) {
#ifdef __HAVE_ARCH_STRCMP
    return __strcmp(s1, s2);
#else
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc0201470:	00054783          	lbu	a5,0(a0)
        s1 ++, s2 ++;
    }
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201474:	0005c703          	lbu	a4,0(a1)
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc0201478:	cb89                	beqz	a5,ffffffffc020148a <strcmp+0x1a>
        s1 ++, s2 ++;
ffffffffc020147a:	0505                	addi	a0,a0,1
ffffffffc020147c:	0585                	addi	a1,a1,1
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc020147e:	fee789e3          	beq	a5,a4,ffffffffc0201470 <strcmp>
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201482:	0007851b          	sext.w	a0,a5
#endif /* __HAVE_ARCH_STRCMP */
}
ffffffffc0201486:	9d19                	subw	a0,a0,a4
ffffffffc0201488:	8082                	ret
ffffffffc020148a:	4501                	li	a0,0
ffffffffc020148c:	bfed                	j	ffffffffc0201486 <strcmp+0x16>

ffffffffc020148e <strncmp>:
 * the characters differ, until a terminating null-character is reached, or
 * until @n characters match in both strings, whichever happens first.
 * */
int
strncmp(const char *s1, const char *s2, size_t n) {
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc020148e:	c20d                	beqz	a2,ffffffffc02014b0 <strncmp+0x22>
ffffffffc0201490:	962e                	add	a2,a2,a1
ffffffffc0201492:	a031                	j	ffffffffc020149e <strncmp+0x10>
        n --, s1 ++, s2 ++;
ffffffffc0201494:	0505                	addi	a0,a0,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc0201496:	00e79a63          	bne	a5,a4,ffffffffc02014aa <strncmp+0x1c>
ffffffffc020149a:	00b60b63          	beq	a2,a1,ffffffffc02014b0 <strncmp+0x22>
ffffffffc020149e:	00054783          	lbu	a5,0(a0)
        n --, s1 ++, s2 ++;
ffffffffc02014a2:	0585                	addi	a1,a1,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc02014a4:	fff5c703          	lbu	a4,-1(a1)
ffffffffc02014a8:	f7f5                	bnez	a5,ffffffffc0201494 <strncmp+0x6>
    }
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc02014aa:	40e7853b          	subw	a0,a5,a4
}
ffffffffc02014ae:	8082                	ret
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc02014b0:	4501                	li	a0,0
ffffffffc02014b2:	8082                	ret

ffffffffc02014b4 <memset>:
memset(void *s, char c, size_t n) {
#ifdef __HAVE_ARCH_MEMSET
    return __memset(s, c, n);
#else
    char *p = s;
    while (n -- > 0) {
ffffffffc02014b4:	ca01                	beqz	a2,ffffffffc02014c4 <memset+0x10>
ffffffffc02014b6:	962a                	add	a2,a2,a0
    char *p = s;
ffffffffc02014b8:	87aa                	mv	a5,a0
        *p ++ = c;
ffffffffc02014ba:	0785                	addi	a5,a5,1
ffffffffc02014bc:	feb78fa3          	sb	a1,-1(a5)
    while (n -- > 0) {
ffffffffc02014c0:	fec79de3          	bne	a5,a2,ffffffffc02014ba <memset+0x6>
    }
    return s;
#endif /* __HAVE_ARCH_MEMSET */
}
ffffffffc02014c4:	8082                	ret
