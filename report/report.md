# 操作系统实验报告

## 实验基本信息

| 项目 | 内容 |
|------|------|
| 实验名称 | Lab 1: 比麻雀更小的麻雀（最小可执行内核）|
| 小组成员 | 2411795-阎科霖、2411294-王烨、2411276-林靖然 |
| 完成日期 | 2026-10-07 |

---

### 小组分工

练习分工：

| 成员 | 负责的练习/模块 |
|------|----------------|
| 2411795-阎科霖 | [练习或模块名称] |
| 2411294-王烨 | [练习或模块名称] |
| 2411276-林靖然 | [练习或模块名称] |

实验报告分工：[填写：谁负责撰写/校对哪一节]

---

## 一、实验目的

本实验的主要目的是：

1. 使用链接脚本描述内存布局
2. 进行交叉编译生成可执行文件，进而生成内核镜像
3. 使用OpenSBI作为bootloader加载内核镜像，并使用Qemu进行模拟
4. 使用OpenSBI提供的服务，在屏幕上格式化打印字符串用于以后调试

---

## 二、实验环境

### 2.1 实验环境搭建及验证

按照实验指导书lab0的说明，搭建实验环境。本实验基于WSL2 Ubuntu 22.04 LTS开展，从oslab拉取lab1的代码后，我们寄存在目录`os_homework/code`下。

本次实验需要安装RISC-V工具链和模拟器Qemu。**RISC-V 工具链** 用于交叉编译：我们的开发机（Ubuntu）是 x86 架构，而要编写的是运行在 RISC-V 架构上的内核，因此需要一套目标平台为 riscv64 的工具链。**Qemu** 是模拟器，用于运行程序，它用软件模拟了一台 riscv64 计算机。Qemu内置了 **OpenSBI** 固件，负责操作系统运行前的硬件初始化和加载操作系统的功能。

而lab1的代码是 ucore 的麻雀骨架，即一个最小可执行内核。它把完整 ucore 中与本章无关的部分全部削去，只保留跑通启动链路所必需的部件。本章的代码运行起来只做一件事：打印一行 `(THU.CST) os is loading ...`，然后进入死循环。

首先是 RISC-V 工具链的安装。从 https://github.com/sifive/freedom-tools/releases 找到并下载与操作系统匹配的版本，解压后统一放到一个目录中。随后，我们设置RISC-V环境变量：

```bash

mkdir -p ~/riscv
vim ~/.bashrc

#跳转至最后一行
export RISCV=$HOME/riscv
export PATH=$RISCV/bin:$PATH

#保存退出，随后应用
source ~/.bashrc
echo $RISCV

#输出结果正确，环境变量生效
/home/sparkwang/riscv
```
环境变量配置生效后，执行以下命令验证工具链是否可用：
```bash
riscv64-unknown-elf-gcc -v

#输出结果正确，安装完成
gcc version 10.2.0 (SiFive GCC-Metal 10.2.0-2020.12.8)
```
随后从Qemu官方网站获取qemu-4.1.1，解压后执行：
```bash
cd qemu-4.1.1
./configure --target-list=riscv32-softmmu,riscv64-softmmu --extra-cflags="-fcommon"
make -j$(nproc)

#验证版本
qemu-system-riscv64 --version

#输出结果正确，安装完成
QEMU emulator version 4.1.1
Copyright (c) 2003-2019 Fabrice Bellard and the QEMU Project developers
```
至此，实验基本环境搭建完成。

### 2.2 工程编译与运行

这一小节编译内核镜像并在 QEMU 中运行，同时使用命令行调试工具 GDB 进行调试。

将目录切换到工程目录 `os_homework/code` 下，执行：
```bash
make qemu
```
运行结果如下：
![QEMU运行结果](images/01_qemu_run.png)

这说明 QEMU 已模拟出一台 riscv64 机器，内置的 OpenSBI 固件正常启动并加载了我们的内核：屏幕上方的平台信息由 OpenSBI 固件打印，最后一行 `(THU.CST) os is loading ...` 是内核自己的输出，表示内核已开始执行。随后通过 Ctrl+A，松开后执行 X，退出 Qemu。

接下来在终端1执行：
```bash
make debug
```
然后新建终端2执行：
```bash
#在相同工程目录下
make gdb
```
这一阶段用于实现GDB的正常使用和远程连接，输出结果如图所示：
![GDB运行结果](images/02_gdb_run.png)

至此，基本的工程编译运行已经完成。具体机制会在后面的部分进行解释。

---

## 三、实验整体逻辑分析

### 3.1 本章节的逻辑主线

本章围绕一个核心问题展开：**我们自己写的一段代码，怎样才能变成真正在裸机上运行的内核？** 换个说法，就是**CPU 的控制权如何从硬件固件一步步交到操作系统手里**。

要回答这个问题，必须先解决三个互相依赖的子问题：

1. **内核应该被放在内存的哪个位置。** 内核在链接完成后就是"地址相关代码"：机器指令里的访存地址在编译链接阶段就已经写成绝对地址，运行前必须把代码装到那个固定位置才能正确执行。因此内核的第一条指令必须落在固件约定好的物理地址 `0x80200000` 上。
2. **固件认不认我们产出的文件。** OpenSBI 要替我们把内核搬进内存，但它只搬运扁平的镜像，不会去解析复杂的 ELF 格式，所以我们必须先把 ELF 转成 BIN。
3. **内核怎样才能"说得出话"。** 内核里没有任何运行时库，连 `printf` 都没有。想让内核在启动时打印一行信息，只能自己从最底层的 `ecall` 开始，一层层封装出一个可用的 `cprintf`。

所以本章的逻辑主线可以概括成一条交接链：

> **链接脚本规定位置 → objcopy 生成镜像 → OpenSBI 搬运并跳转 → entry.S 建立内核栈 → kern_init 打印信息**

这五步的顺序不是随意的：位置不对，镜像做了也没用；镜像不对，固件搬过去的是垃圾；不能打印，我们无从知道前几步到底有没有成功。本章最终交付的就是这个"能打印一行字符串然后进入死循环"的最小可执行内核。

上面这条链是"把内核造出来"的顺序。真正运行的时候，交接是沿着另一个方向发生的：

> 加电复位 → PC 被置为 `0x1000`（MROM 中的复位代码）→ 跳转到 `0x80000000`（OpenSBI，M 态）→ OpenSBI 完成初始化并把内核放到 `0x80200000` → 执行 `entry.S` 的 `kern_entry` → 调用 `kern_init()` → 打印信息 → 进入死循环

两条链是在 `0x80200000` 这个地址上对接的：链接脚本让内核"长在"这个地址上，OpenSBI 负责把内核"放到"这个地址上；两侧对这个地址的约定一致，交接才能成功。

### 3.2 功能的逐步实现


1. **首先确定内核的内存布局和入口点（`tools/kernel.ld` + `kern/init/entry.S`）**
   → 为什么首先实现这个：它是后面一切工作的前提。链接脚本里 `BASE_ADDRESS = 0x80200000` 并用 `. = BASE_ADDRESS;` 把 `.text` 段钉在这个地址上，再用 `ENTRY(kern_entry)` 指定入口符号，内核的第一条指令才会正好落在固件将要跳转的位置。同时在 `entry.S` 的 `.data` 段里用 `bootstack` / `.space KSTACKSIZE` / `bootstacktop` 预留出一块内核栈（`KSTACKSIZE = KSTACKPAGE * PGSIZE = 2 × 4096 = 8 KiB`）。没有这一步，内核既不会被正确加载，也无法运行 C 代码。

2. **接着把 ELF 转换成 BIN 镜像（Makefile 中的 objcopy 步骤）**
   → 为什么接着实现这个：只有当段的布局已经确定，"把段铺平成一块线性数据"这件事才有意义。ELF 里 `.bss` 这类全零段只需要记录大小和位置，而 BIN 里要真正展开成对应数量的零字节——所以必须先有正确布局，objcopy 的结果才是对的，顺序不能颠倒。

3. **然后自底向上构建输出能力（`libs/sbi.c` → `kern/driver/console.c` → `kern/libs/stdio.c` → `libs/printfmt.c`）**
   → 为什么然后实现这个：前三步都做完之后，内核其实还是"哑"的——跑起来冒出一行字都没有，我们无法判断它究竟有没有成功启动。但内核里没有 libc，这个能力只能自己造。实现方式是一层层封装：`cprintf` → `vcprintf` → `vprintfmt`（负责把格式化串拼出来）→ `cputch` / `cputchar` → `cons_putc` → `sbi_console_putchar` → `sbi_call`（内联汇编把功能号放进 `a7`、参数放进 `a0`~`a2`，再执行 `ecall` 陷入 M 态）。每一层只做一件事：上层不认识 SBI，下层不懂格式化，各管一段，最后拼成一个用起来和标准库 `printf` 差不多的 `cprintf`。

4. **最后把整条链路固化进 Makefile**
   → 为什么最后实现这个：编译、链接、objcopy、启动这一串命令如果每次手工敲，既繁琐又容易出错。链路的每一步都验证可用之后，把它固化成 `make qemu` 一条命令，既是本章的收尾，也为后面几章的实验提供一个稳定的构建基础。

### 3.3 各功能模块与核心函数

下面按"从下到上"的顺序，说明本项目各个功能模块及其核心函数的作用。

**（1）链接脚本 `tools/kernel.ld` —— 决定内核放在哪里**

- `ENTRY(kern_entry)`：指定程序的入口符号是 `kern_entry`，链接器会把它记录在 ELF 文件头里。
- `BASE_ADDRESS = 0x80200000` 与 `SECTIONS` 开头的 `. = BASE_ADDRESS;`：给位置计数器 `.` 赋值，此后放置的段就从这个地址开始，于是 `.text` 正好落在 `0x80200000`。
- `.text` 段里把 `*(.text.kern_entry)` 写在最前面：保证 `kern_entry` 就是内核镜像的第一条指令。OpenSBI 跳过来时执行的必须是入口代码，所以这个顺序不能变。
- `PROVIDE(etext = .)`、`PROVIDE(edata = .)`、`PROVIDE(end = .)`：由链接器额外提供三个符号，分别指向代码段结束、数据段结束和镜像结束。`kern_init` 清 `.bss` 段时用的正是 `edata` 和 `end`。
- `. = ALIGN(0x1000)`：把接下来的 `.data` 段对齐到下一页的起始处。
- `/DISCARD/`：丢弃 `.eh_frame`、`.note.GNU-stack` 这类在裸机上没有用处的段。

**（2）入口汇编 `kern/init/entry.S` —— 搭好 C 的运行环境**

核心符号是 `kern_entry`，只有两条有效指令：

- `la sp, bootstacktop`：把栈指针指向内核栈的栈顶；
- `tail kern_init`：跳转到 C 语言的入口 `kern_init`，并且不保存返回地址。

配套的 `.data` 段里用 `.align PGSHIFT`、`bootstack:`、`.space KSTACKSIZE`、`bootstacktop:` 划出一块长度为 `KSTACKSIZE` 的内核栈，`bootstacktop` 标在它的末尾，也就是空栈时的栈顶位置。（详细分析见练习 1）

**（3）内核初始化 `kern/init/init.c`**

核心函数是 `kern_init()`，声明为 `__attribute__((noreturn))`，因为它的最后是死循环：

- `extern char edata[], end[]; memset(edata, 0, end - edata);` —— 借助链接脚本提供的两个符号，把 `.bss` 段整段清零。内核没有标准库，这里的 `memset` 来自 `libs/string.c`。
- `cprintf("%s\n\n", message);` —— 打印 `(THU.CST) os is loading ...`，这是内核与外界的第一句"对话"。
- `while (1) ;` —— 进入死循环，表示内核已经接管了机器。

**（4）SBI 调用封装 `libs/sbi.c` —— 输出链路的最底层**

- `sbi_call(sbi_type, arg0, arg1, arg2)`：整条链路的物理起点。用内联汇编把功能号放进 `x17`（即 `a7`）、三个参数放进 `x10`~`x12`（即 `a0`~`a2`），执行 `ecall` 陷入 M 态，再从 `x10` 取回返回值。因为 C 语言无法指定"变量放进哪个寄存器"，这一步只能用内联汇编来完成。
- `sbi_console_putchar(ch)`：把通用调用专用化为"输出一个字符"，功能号取 `SBI_CONSOLE_PUTCHAR = 1`。
- 文件中还列出了 `SBI_SET_TIMER`、`SBI_SHUTDOWN` 等功能号，lab1 只用到输出字符这一个。

**（5）控制台驱动 `kern/driver/console.c` —— 隔离具体的输出设备**

- `cons_putc(int c)`：把输出动作从 SBI 的具体接口上摘出来，对上层只暴露 `cons_putc`；日后更换输出设备只需要改这一层。
- `cons_getc()`：通过 `sbi_console_getchar()` 读取一个输入字符。
- `cons_init()`、`kbd_intr()`、`serial_intr()` 在 lab1 中是空实现，属于给后续实验预留的接口。

**（6）格式化输出 `kern/libs/stdio.c` 与 `libs/printfmt.c` —— 让输出"好用"**

- `cputch(c, cnt)` / `cputchar(c)`：把字符交给 `cons_putc`，同时维护已输出字符的计数。
- `vprintfmt(putch, putdat, fmt, ap)`（在 `libs/printfmt.c` 中）：真正解析格式串的地方，逐个处理 `%d`、`%x`、`%s`、`%p` 等转换，每解析出一个字符就回调传进来的 `putch`；内部的 `printnum`、`getint`、`getuint` 负责取数和进制转换。
- `vcprintf(fmt, ap)`：把 `cputch` 作为回调传给 `vprintfmt`。
- `cprintf(fmt, ...)`：把可变参数整理成 `va_list` 后交给 `vcprintf`，是最终对内核其他部分开放的接口。

把这几层接起来，就是一条完整而清晰的链路：

> `cprintf` → `vcprintf` → `vprintfmt` → `cputch` → `cons_putc` → `sbi_console_putchar` → `sbi_call` → `ecall` → OpenSBI 写控制台

每一层只解决一个问题：上层不认识 SBI，下层不懂格式串，中间的 `putch` 回调把两层粘在一起。

**（7）构建脚本 `Makefile` —— 把整条流程固化下来**

- 借助 `tools/function.mk` 提供的函数，自动收集 `libs/` 与 `kern/` 各子目录下的 `.c`、`.S` 文件并生成目标文件，不需要手工维护文件清单。
- 编译选项里的 `-mcmodel=medany` 决定了 `la` 会展开成 `auipc` + `addi` 的 PC 相对寻址形式；`-fno-builtin`、`-nostdinc` 保证不会误用到开发机上的标准库。
- 链接规则用 `-T tools/kernel.ld` 生成 ELF 文件 `bin/kernel`。
- `objcopy --strip-all -O binary` 把 ELF 转成扁平镜像 `bin/ucore.img`。
- `qemu`、`debug`、`gdb` 三个目标分别对应正常运行、带 `-s -S` 挂起等待调试、以及启动 GDB 并连接到 `localhost:1234`。

---

## 四、实验内容与实现

lab1 不涉及代码编写，本章只有两个需要回答的练习。

### 练习1：理解内核启动中的程序入口操作

**负责人：** [学号-姓名]

阅读 `kern/init/entry.S`：

```c
#include <mmu.h>
#include <memlayout.h>

.section .text,"ax",%progbits // 从这里开始，放入.text段，a=可分配，x=可执行
    .globl kern_entry // 把 kern_entry 变成全局符号，让链接器（ld）能看见它
kern_entry:
    la sp, bootstacktop

    tail kern_init

.section .data // 切换到数据段，后面的东西是数据
    # .align 2^12
    .align PGSHIFT // 把下面的数据对齐到页边界（PGSHIFT = 12，是 2^12 = 4096 字节）
    .global bootstack
bootstack:
    .space KSTACKSIZE //  预留 KSTACKSIZE 个字节的空间，但不填内容
    .global bootstacktop
bootstacktop:
```

#### （1）`la sp, bootstacktop` 完成了什么操作，目的是什么？

要理解这两条指令，需要先清楚内核启动的大致流程。CPU 上电复位后，PC 被硬件强制设为复位地址 `0x1000`，开始执行 QEMU 内置的一小段固件（MROM）；这段固件只做最基本的环境准备，随后把控制权交给位于 `0x80000000` 的 OpenSBI 固件。OpenSBI 运行在最高的 M 态（机器态），完成初始化后把我们的内核镜像搬到 `0x80200000`，并跳转过去；从这一刻起，CPU 才开始执行我们自己写的代码，也就是 `kern/init/entry.S` 中的 `kern_entry`，此时处理器处于 S 态（监管态）。`entry.S` 只有两条指令，把执行环境从固件切换到内核。

**完成的操作**：`la` 是汇编伪指令，`la` = load address（装入地址），本身不产生机器码，汇编器会把它展开成两条真正的指令：

```asm
auipc sp, %pcrel_hi(bootstacktop)      # auipc = add upper immediate to PC：把「当前 PC + 高位偏移」放进 sp
addi  sp, sp, %pcrel_lo(bootstacktop)  # 再把低位偏移补上
```

它的作用是把 `bootstacktop` 这个符号的**地址**装入 `sp`（栈指针）寄存器。装入 `sp` 的是地址本身，而不是该地址处的内容。

类比上学期学习的MIPS：MIPS 的 `la` 同样会展开成两条指令（`lui` + `ori`/`addiu`），但拼出来的是绝对地址；RISC-V 这里改用 `auipc`，拼出的是相对于当前 PC 的地址。也就是说，这条指令属于PC 相对寻址。

`bootstacktop` 是在该文件的 `.data` 段中定义的：

```asm
.section .data
    .align PGSHIFT          # 按 2^12 对齐到页边界
    .global bootstack
bootstack:
    .space KSTACKSIZE       # 预留 KSTACKSIZE 字节
    .global bootstacktop
bootstacktop:
```

`bootstack:` 处用 `.space KSTACKSIZE` 预留了 `KSTACKSIZE = KSTACKPAGE * PGSIZE = 2 × 4096 = 8192` 字节的空间；`bootstacktop` 紧跟在它后面，因此 `bootstack` 是这块栈区的**低地址端**，`bootstacktop` 是它的**高地址端**。

相关定义可以在`kern/mm/`里找到：
```c
    #define KSTACKPAGE 2 // 内核栈 = 2 页 (memlayout.h)
    #define PGSIZE     4096 // 一页 4096 字节 (mmu.h)
    #define KSTACKSIZE (KSTACKPAGE * PGSIZE) // = 8192 字节 = 8 KiB
```

RISC-V 的栈是向**低地址方向增长**的，而且"空栈"时 `sp` 应当指向栈区的最高地址处。所以把 `sp` 初始化为 `bootstacktop`，恰好就是"内核栈当前为空"的正确初值；此后每次函数调用压栈，`sp` 会逐渐变小。

**目的：** 为即将执行的 C 代码准备好栈。C 语言的函数调用依赖栈来保存返回地址、局部变量和需要保存的寄存器。在此指令之前，CPU 用的还是 OpenSBI 移交控制权时留下的栈指针，那片内存属于固件、不属于我们的内核。如果直接去调用 C 函数，就会破坏固件的现场，或者写到不属于自己的内存上。因此必须在跳入 C 语言之前，把 `sp` 切换到内核自己的栈上。

#### （2）`tail kern_init` 完成了什么操作，目的是什么？

**完成的操作：** `tail` 是尾调用（tail call）伪指令，会被展开成
```asm
auipc t1, %pcrel_hi(kern_init) # t1 = kern_init 的地址
jalr  x0, t1, %pcrel_lo(kern_init)    # 跳过去，但返回地址写进 x0。x0是零寄存器，写进x0等于扔掉，也就是不保存返回地址。
```

`jalr` = jump and link register（跳转并链接），完整语义是：先把**下一条指令的地址**（PC+4，也就是返回地址）存入 `rd`，然后跳转到 `rs1 + imm`。而这里 `rd` 位置上写的是 `x0`，是零寄存器，任何写进去的值都会被直接丢弃，所以返回地址没有被保存下来。

因此 `tail`指令的作用，就是"跳到 `kern_init` 处、并且不留下返回地址的无条件跳转。

**目的：** 把 CPU 的执行权交给用 C 语言编写的 `kern_init` 函数，同时明确表达这一步交出去就不再收回：`kern_init` 不需要返回，也就不需要为它保存返回地址。这一点在 `kern_init` 自身的声明里也有体现：

```c
int kern_init(void) __attribute__((noreturn));
```

`noreturn` 告诉编译器这个函数不会返回，而函数体最后是 `while (1) ;` 的无限循环。

至此汇编代码的使命完成，内核入口正式进入 C 语言世界。

---

### 练习2：使用 GDB 验证启动流程

**负责人：** 2411276-林靖然

#### （1）调试过程与观察结果

使用两个终端配合调试：终端 1 运行 QEMU 并暂停等待：`make debug`。这条命令展开是：`qemu-system-riscv64 -machine virt -nographic -bios default -device loader,file=bin/ucore.img,addr=0x80200000 -s -S`。其中 `-S` 让虚拟 CPU 一启动就暂停，`-s` 在 1234 端口监听 GDB 连接。
终端 2 启动 GDB 并连接上去:`make gdb`。这条命令依次执行 `file bin/kernel` 加载带调试符号的内核、`set arch riscv:rv64` 指定架构、`target remote localhost:1234` 连接 QEMU 监听的1234端口。

连接成功后 GDB 报告程序停在下述位置：

```
Remote debugging using localhost:1234
0x0000000000001000 in ?? ()
```

CPU 的第一条指令位于物理地址 `0x1000`，这正是该处理器的复位地址。下面的调试按启动流程分为三个阶段。

**阶段一：复位地址处的初始化固件**

在 `0x1000` 处反汇编：

```
(gdb) x/5i $pc
=> 0x1000:      auipc   t0,0x0
   0x1004:      addi    a1,t0,32
   0x1008:      csrr    a0,mhartid
   0x100c:      ld      t0,24(t0)
   0x1010:      jr      t0
```

这几条指令做了取当前地址、读 hart id、从固定偏移处取出一个入口地址并跳转这类最基本的动作，作用是完成最基础的准备工作，并转去执行 OpenSBI。

**阶段二：SBI 主初始化，装载内核**

按提示在 `0x80200000` 处设置观察点：

```
(gdb) watch *0x80200000
Hardware watchpoint 1: *0x80200000
```

**阶段三：跳转到 `0x80200000`，控制权移交内核**

内核镜像是在 QEMU 开始执行任何指令之前就已装入内存的，这个写入不由 CPU 发出，因此硬件观察点不会命中。为看清"SBI 跳转到内核"的瞬间，改在同一地址下断点，再让程序继续运行：

```
(gdb) b *0x80200000
Breakpoint 2 at 0x80200000: file kern/init/entry.S, line 7.
(gdb) c
Continuing.

Breakpoint 2, kern_entry ()
    at kern/init/entry.S:7
7           la sp, bootstacktop
```

程序停在 `kern_entry` 的第一条汇编指令 `la sp, bootstacktop` 上，说明 SBI 已经跳转过来、内核开始执行。此时反汇编 `kern_entry` 附近的代码，并查看栈指针：

```
(gdb) x/5i $pc
=> 0x80200000 <kern_entry>:     auipc   sp,0x3
   0x80200004 <kern_entry+4>:   mv      sp,sp
   0x80200008 <kern_entry+8>:   j       0x8020000a <kern_init>
   0x8020000a <kern_init>:      auipc   a0,0x3
   0x8020000e <kern_init+4>:    addi    a0,a0,-2
(gdb) i r sp
sp             0x8001bd80       0x8001bd80
(gdb) si
0x0000000080200004 in kern_entry ()
    at kern/init/entry.S:7
7           la sp, bootstacktop
(gdb) i r sp
sp             0x80203000       0x80203000
```

单步执行第一条指令的前后，`sp` 由 `0x8001bd80` 变成 `0x80203000`：前者位于 `0x80000000` 区域，是 OpenSBI 自己的栈；后者落在内核栈 `bootstack` 的顶部，与练习 1 中 `la sp, bootstacktop` 的分析一致。

**观察结果小结**

1. 加电后 PC 的初值为 `0x1000`（复位地址），处理器从这里开始执行固化在 MROM 中的复位代码；
2. 复位代码完成最基础的环境准备，然后把控制权交给 OpenSBI；
3. OpenSBI 完成主初始化后跳转到 `0x80200000`，`kern_entry` 开始执行，控制权正式移交给内核。

调试截图：

![GDB运行结果](images/03_gdb_run_2.png)

#### （2）RISC-V 硬件加电后最初执行的几条指令位于什么地址？它们主要完成了哪些功能？

**地址：** 位于 `0x1000`，即该处理器的复位地址。

**主要完成的功能：**

1. **最基础的硬件与环境准备。** 把计算机系统的各个组件（处理器、内存、设备等）置于初始状态，准备好后续程序能够运行的最小环境。MROM 中的代码极其有限，它不具备读取硬盘这类复杂设备的能力。
2. **启动 bootloader。** 复位代码会把作为 bootloader 的 OpenSBI 加载到物理地址 `0x80000000` 开头的区域，并把控制权交给它。OpenSBI 接着在 M 态完成主初始化，再把内核镜像搬到 `0x80200000`，最后跳转过去——至此控制权才真正交到我们编写的内核手上。

---

## 五、实验总结与收获

### 对操作系统的理解

**1. 本实验的重要知识点，及其与 OS 原理中知识点的对应关系**

| 本实验知识点 | 对应的 OS 原理知识点 | 含义、关系与差异 |
|------------|-------------------|----------------|
| 链接脚本与内存布局（`kernel.ld`、内核基址 `0x80200000`） | **地址相关代码与重定位**：可执行文件中的访存地址在编译链接时就已经确定，代码只有被装入指定地址才能运行；装入时必须把程序中所有关于地址的访问统一调整一个偏移量 | 两者回答的是同一个问题——代码和数据应该放在哪里。本实验里指令中的访存地址在编译链接时就被钉死成了**物理地址**，所以内核必须被装到 `0x80200000` 才能运行；真实 OS 中这部分调整工作由 MMU 和页表在运行时完成，lab1 还没有这层机制，只能靠钉死基址来回避。 |
| OpenSBI 作为 bootloader，在 M 态完成初始化后把控制权交给内核 | **引导加载程序（bootloader）与固件**：操作系统自己无法完成"把自己加载进内存"这件事，必须先由一个更早运行的程序把它搬进内存，再把控制权交出来 | 都是"在内核之前运行、负责把内核搬进内存并交出控制权"的程序。实验中是 QEMU 的复位代码 → OpenSBI → 内核，现代 PC 是同构的 UEFI → GRUB → 内核。差异在于真实 PC 的引导链更长，还要完成硬件自检、安全启动等工作。 |
| 内核跑在 S 态、OpenSBI 跑在 M 态 | **处理器和指令的权限管理**：指令分为**普通指令**和**特权指令**，"特权指令只有处于特权模式的（CPU）才可以执行"；CPU 也相应地分为**普通状态**和**特权状态**；RISC-V 设有 S 态、M 态、U 态三个特权等级 | 实验中用 GDB 跟出来的那条链路，正好是这套特权等级的一次实地演练：`0x1000` 的复位代码把 CPU 交给 M 态的 OpenSBI，OpenSBI 再把控制权交给 S 态的内核。差异在于本实验只用到 S 态和 M 态，没有 U 态，也不涉及 hypervisor（管理操作系统的操作系统）。 |
| 内核通过 `ecall` 陷入 M 态，调用 SBI 的控制台服务 | **系统调用（syscall）**：应用程序的一行 printf 里，真正与操作系统打交道的只有一条非常简单的请求指令 syscall；读硬盘、读网络、做闹钟、读键盘这类操作都要执行特权指令，应用程序自己执行不了，只能请操作系统代为执行 | 两者用的是同一套硬件机制，只是所处层次不同。差异在于：系统调用是 U 态程序请求 S 态的操作系统，服务由 OS 自己提供；本实验是 S 态的内核请求 M 态的固件，服务由 OpenSBI 提供。而且 lab1 的内核只实现了"请求方"，还没有实现"被应用程序请求"的那一侧。 |
| 内核栈的初始化 `la sp, bootstacktop`，以及 `tail kern_init` 不保存返回地址 | **上下文（context）与保存现场 / 恢复现场**：控制器和逻辑运算单元本身没有状态，所有的状态都体现在寄存器上；保存上下文就是把寄存器当中的值保存到内存中的一个指定位置上。其中 **RA**（return address）决定了接下来要执行的是哪一行代码——function call 只是一句跳转，return 是另外一句跳转 | 上下文里靠 RA 决定"接下来要执行哪一行"，而 lab1 的 `tail kern_init` 恰恰是不写 RA 的跳转——它根本不打算返回，正好是这条原理的反面例子。差异在于：lab1 只有唯一一个启动栈，没有进程，也就谈不上"存档 / 读档"。 |
| 无 libc 环境下自底向上封装输出（`cprintf` → SBI 控制台） | **操作系统提供的抽象接口与硬件细节的屏蔽**：硬件五花八门、多种多样，操作系统在其上做一个软件层来屏蔽硬件细节，对上只暴露 cout、cin、file 的 open/read/write/close 这类标准接口，上层不必关心底下接的到底是什么设备 | `cprintf` 就是这层"屏蔽硬件细节"的软件层的最小版本：上层只负责把字符串格式化好，底层把字符一个一个交给 SBI 送出去。差异在于：操作系统是**给应用程序**提供接口，而 lab1 的内核自己还只是接口的使用者，中间也没有 syscall 这一层。 |
| ELF 与 BIN 两种文件格式，以及用 `objcopy` 生成扁平镜像 | **程序的装入与可执行文件格式**：程序必须被装入内存才能运行，而"按什么布局装入"由可执行文件的格式来描述 | 两者的区别在于"由谁来解析布局"：ELF 通过 program header 描述各段的布局并携带调试信息，BIN 则是"已按布局铺平"的扁平镜像。有完整 OS 时由加载器解析 ELF 并建立地址空间；本实验因为固件看不懂 ELF，只能事先用 `objcopy` 把布局铺平。 |

**2. 我们认为 OS 原理中很重要、但在本实验中没有对应上的知识点**

- **并发与并行**：并发是宏观上的并行、微观上的顺序使用，两者并不是一回事。本实验全程只有一条指令流在跑，既没有并发，也没有并行。
- **进程**：进程是所有正在运行着的程序的一个抽象体，它所具备的最基础的能力就是保存现场和恢复现场；程序是静态的，进程是动态的，每一个进程都是一个程序的独立运行实体，彼此完全隔离。本实验里只有内核自己一个执行流，没有进程这个概念。
- **系统调用的另一侧**：应用程序通过 syscall 向操作系统提出请求，而本实验的内核正好是提出请求的一方，还没有实现"被应用程序请求"的那一侧，也没有 U 态程序。

---

