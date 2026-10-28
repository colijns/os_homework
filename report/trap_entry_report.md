# Lab3：Trap 入口与上下文恢复

学号：2411795

整理日期：2026-10-28

源码基线：`af2c81071525e4cc38b3a68b1cb959d1a0f23467`

## 1. 实现目标与整体流程

本部分完成 Trap 处理过程中汇编层的入口和返回功能。处理器发生 Trap 时会记录 `sepc`、`scause` 等状态，但不会自动把所有通用寄存器压入内存。因此，在调用 C 语言处理函数之前，需要先保存被打断程序的寄存器；C 语言处理结束后，再根据保存的现场恢复执行。

框架已经给出了 `SAVE_ALL` 和 `struct trapframe`。本次在 `code/kern/trap/trapentry.S` 中补全 `RESTORE_ALL` 与 `__alltraps`，使执行过程形成以下闭环：

```text
发生 Trap，跳到 stvec 指向的 __alltraps
    → SAVE_ALL 将现场保存到当前栈上的 Trap frame
    → 将 Trap frame 地址作为参数传给 trap()
    → C 层完成处理并返回
    → __trapret 执行 RESTORE_ALL
    → sret 恢复执行位置、特权级和中断使能状态
```

中断类型分发、时钟计数和具体异常处理属于后续部分，本次没有填写 `interrupt_handler()`、`exception_handler()`。

## 2. Trap frame 的实际布局

本工程的 `struct pushregs` 按 `x0` 到 `x31` 的顺序保存通用寄存器，随后是四个与 Trap 有关的状态字段。RV64 环境中 `uintptr_t` 和 `REGBYTES` 都是 8 字节，整个 `struct trapframe` 的大小为 `36 × 8 = 288` 字节。隔离测试通过编译期断言和运行时指针检查核对了这一布局。

| 字段 | 槽位 | 相对 Trap frame 起点的字节偏移 |
| --- | --- | --- |
| `x0` | 0 | 0 |
| `ra` | 1 | 8 |
| 原始 `sp` | 2 | 16 |
| `gp`、`tp` | 3、4 | 24、32 |
| `t0`—`t2` | 5—7 | 40—56 |
| `s0`、`s1` | 8、9 | 64、72 |
| `a0`—`a7` | 10—17 | 80—136 |
| `s2`—`s11` | 18—27 | 144—216 |
| `t3`—`t6` | 28—31 | 224—248 |
| `status`，保存 `sstatus` | 32 | 256 |
| `epc`，保存 `sepc` | 33 | 264 |
| `badvaddr` | 34 | 272 |
| `cause`，保存 `scause` | 35 | 280 |

`sp` 是这里需要特别注意的寄存器。进入 `SAVE_ALL` 后，框架先将原始 `sp` 写入 `sscratch`，再向低地址分配 288 字节，之后将原始 `sp` 保存到第 2 个槽位。因此，恢复 `sp` 时应读取这个槽位，而不能把当前 Trap frame 的起始地址当作原来的栈顶。

## 3. 关键代码与实现说明

### 3.1 将 Trap frame 传给 C 层

入口处的实际修改为：

```asm
__alltraps:
    SAVE_ALL

    #lab3 function1 2411795
    mv a0, sp
    call trap
    # sp must still point to the same trapframe after trap returns.
```

`SAVE_ALL` 执行完成后，`sp` 指向完整的 Trap frame。RISC-V 调用约定使用 `a0` 传递第一个参数，因此通过 `mv a0, sp`，就能让 `trap(struct trapframe *tf)` 接收到当前现场的地址。调用产生的新 `ra` 不会覆盖被打断程序原来的 `ra`，因为旧值已经保存在 Trap frame 的第 1 个槽位中。

`trap()` 返回时，调用约定要求恢复它自己的栈空间，使 `sp` 回到调用前的 Trap frame 起点。执行流随后落入原有的 `__trapret`。

### 3.2 恢复现场

`RESTORE_ALL` 的完整实现为：

```asm
    .macro RESTORE_ALL

    #lab3 function1 2411795
    # Restore the return CSRs before reloading the temporary registers.
    LOAD s0, 32*REGBYTES(sp)
    LOAD s1, 33*REGBYTES(sp)
    csrw sstatus, s0
    csrw sepc, s1

    LOAD x1, 1*REGBYTES(sp)
    LOAD x3, 3*REGBYTES(sp)
    LOAD x4, 4*REGBYTES(sp)
    LOAD x5, 5*REGBYTES(sp)
    LOAD x6, 6*REGBYTES(sp)
    LOAD x7, 7*REGBYTES(sp)
    LOAD x8, 8*REGBYTES(sp)
    LOAD x9, 9*REGBYTES(sp)
    LOAD x10, 10*REGBYTES(sp)
    LOAD x11, 11*REGBYTES(sp)
    LOAD x12, 12*REGBYTES(sp)
    LOAD x13, 13*REGBYTES(sp)
    LOAD x14, 14*REGBYTES(sp)
    LOAD x15, 15*REGBYTES(sp)
    LOAD x16, 16*REGBYTES(sp)
    LOAD x17, 17*REGBYTES(sp)
    LOAD x18, 18*REGBYTES(sp)
    LOAD x19, 19*REGBYTES(sp)
    LOAD x20, 20*REGBYTES(sp)
    LOAD x21, 21*REGBYTES(sp)
    LOAD x22, 22*REGBYTES(sp)
    LOAD x23, 23*REGBYTES(sp)
    LOAD x24, 24*REGBYTES(sp)
    LOAD x25, 25*REGBYTES(sp)
    LOAD x26, 26*REGBYTES(sp)
    LOAD x27, 27*REGBYTES(sp)
    LOAD x28, 28*REGBYTES(sp)
    LOAD x29, 29*REGBYTES(sp)
    LOAD x30, 30*REGBYTES(sp)
    LOAD x31, 31*REGBYTES(sp)

    # Keep the trapframe base until every other register has been restored.
    LOAD x2, 2*REGBYTES(sp)

    .endm
```

先恢复 `sstatus` 和 `sepc`，再恢复通用寄存器，是因为读取 CSR 保存值时使用了 `s0`、`s1` 作为临时寄存器。这两个临时值使用结束后，仍需从第 8、9 个槽位恢复原来的 `s0`、`s1`。

`x0` 的值固定为零，不需要执行恢复写入。`sp` 则最后恢复，保证前面的所有加载都使用同一个 Trap frame 起点。第 34、35 个槽位用于记录异常附加信息和原因，本次没有把它们回写到 CSR；Trap 返回所需的状态来自 `status`、`epc` 和通用寄存器保存区。

最终仍使用框架原有的返回代码：

```asm
__trapret:
    RESTORE_ALL
    # return from supervisor call
    sret
```

`sret` 根据保存的 `SPP` 决定返回的特权级，并将 `sepc` 交给程序计数器。本次测试从 S 模式触发 Trap，验证的是返回 S 模式继续执行，没有把返回目标写死为 U 模式。标准规定 `SIE` 从 `SPIE` 恢复，随后 `SPIE` 置 1、`SPP` 清零。[RISC-V Supervisor ISA](https://docs.riscv.org/reference/isa/v20260120/priv/supervisor.html)

### 3.3 旧 CSR 名称的兼容

首次编译时，本机 GCC 15.1.0 的汇编器提示 `unknown CSR 'sbadaddr'`。这是框架已有 `SAVE_ALL` 使用的旧名称。本工程的 `riscv.h` 已定义 `CSR_SBADADDR = 0x143`，因此在该汇编文件包含头文件后增加：

```c
/* Keep the supplied SAVE_ALL compatible with assemblers using the stval name. */
#define sbadaddr CSR_SBADADDR
```

这样使用框架已有的寄存器编码完成汇编，`SAVE_ALL` 本身的内容、槽位偏移和保存顺序保持不变。

## 4. 编译与运行验证

### 4.1 验证环境

本轮实测环境为 WSL Ubuntu 22.04、RISC-V GCC 15.1.0、QEMU 6.2.0，使用本机已安装的 OpenSBI v0.4 `opensbi-riscv64-virt-fw_jump.bin` 固件，配置为 `virt`、单 hart、128 MiB 内存，raw 镜像加载地址为 `0x80200000`。工具版本、命令和固件摘要保存在 [最终验证记录](a_trap_evidence/20261028_A_publish/results.json) 中。

### 4.2 独立验证方法

原工程的两个处理函数尚未定义；另外，基线 `best_fit_pmm.c` 中的 `free_list`、`nr_free` 也未定义。因此，当前原树不能完整编译。本次先验证 `trapentry.S` 汇编对象能够正常生成，再由 `tools/run_a_trap_checks.py` 在临时副本中构建验证内核。

临时副本保留原启动汇编、页表映射、控制台、实际 `trapentry.S` 和 `trap.h`，跳过尚未完成的 PMM，并用专门的测试入口替代未完成的 C 层分发尾部。该入口只检查保存现场、设置已知的返回地址，并在返回前刻意改写除 `sp` 之外的通用寄存器，使恢复过程必须从 Trap frame 重新加载正确值。用于返回的临时寄存器同样会失去原值，因此也受到恢复检查。

这些测试接收函数只存在于临时副本和证据附件中，不是实际的中断或异常处理实现。正式源码中的 `trap.c`、`trap.h`、初始化和内存管理文件均未修改。

| 检查 | 实际覆盖 | 结果 |
| --- | --- | --- |
| 汇编对象编译 | RV64 汇编、CSR 编码、入口与返回指令 | 通过 |
| 第 1 组 | 32 位断点、全部 GPR 槽位、Trap frame 地址与对齐、`SIE=0` 返回 | 通过 |
| 第 2 组 | 16 位压缩断点、全部 GPR 槽位、`SIE=1` 返回 | 通过 |
| 第 3 组 | 修改保存的 `a0`、重定向 `epc`、修改 `SPIE` 后恢复 `SIE` | 通过 |
| 第 4 组 | 交替执行 256 次断点 Trap，逐次核对寄存器和栈位置 | 通过 |
| 空实现对照 | 保留名称兼容映射，将两处实现还原为空 | 未产生成功标记，4 秒超时，按预期检出 |
| 错误偏移对照 | 故意从第 11 个槽位恢复 `a0` | 报告寄存器 10 恢复错误，按预期检出 |

四组正常运行累计完成 **259 次 Trap**。原始成功日志为：

```text
A_TRAP_CASE1 PASS 32-bit breakpoint, all GPRs, SIE=0
A_TRAP_CASE2 PASS 16-bit breakpoint, all GPRs, SIE=1
A_TRAP_CASE3 PASS edited a0, epc redirection, SPIE -> SIE
A_TRAP_CASE4 PASS 256 repeated traps, stable stack
A_TRAP_ALL_PASS cases=4 traps=259
```

日志中的通过是上述独立检查通过，不是课程评分脚本的分数，也不是完整 Lab3 工程验收通过。原始日志见 [probe_qemu.log](a_trap_evidence/20261028_A_publish/probe_qemu.log)。

### 4.3 验证中遇到的环境差异

旧 QEMU 4.1.1 返回后的 `SPIE` 为 0，使最初按标准行为编写的状态检查失败。查阅该版本的 `helper_sret` 源码，确认它确实将 `SPIE` 清零；QEMU 6.2.0 则将其置 1。最终验证使用后者，没有修改生产汇编来迁就模拟器的旧行为。[QEMU 4.1.1 源码](https://github.com/qemu/qemu/blob/v4.1.1/target/riscv/op_helper.c)，[QEMU 6.2.0 源码](https://github.com/qemu/qemu/blob/v6.2.0/target/riscv/op_helper.c)

本机 QEMU 6.2.0 的默认固件在此次 raw loader 启动方式下报告 `Domain0 Next Address = 0`，6 秒内未进入内核；显式指定已有的 OpenSBI v0.4 跳转固件后进入内核并完成检查。这里记录的是本机这组启动参数的观察结果，不推断所有新版固件都无法启动该实验。

## 5. 结论与后续衔接

本部分完成了现有内核栈上 Trap frame 的传参、恢复和返回。验证说明当前实现能够保存并恢复测试中的通用寄存器，使用 C 层更新后的返回状态，并在重复 Trap 后保持栈位置稳定。

后续需要接入实际中断处理、异常处理，解决继承的 PMM 编译问题，再进行整机验证。本轮没有验证持续时钟中断、非法指令处理、最终关机条件和课程完整评分；也没有验证 U/S 栈切换、浮点或向量现场、多 hart 和嵌套 Trap。

本部分的 [spec 与提示词记录](trap_entry_spec_prompt.md)、[交接说明](A_交接给B.md) 以及 [验证证据索引](a_trap_evidence/README.md) 已单独保存，便于后续汇总。
