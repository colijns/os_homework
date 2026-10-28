# Lab3 第一棒交接：Trap 入口与上下文恢复

日期：2026-10-28

负责人学号：2411795

工作目录：`D:\大三上\os\lab3_trap_work`

基线：`lab3`，`af2c81071525e4cc38b3a68b1cb959d1a0f23467`

## 1. 本次完成内容

生产实现位于 [code/kern/trap/trapentry.S](../code/kern/trap/trapentry.S)：

1. `RESTORE_ALL` 从既有 Trap frame 恢复 `sstatus`、`sepc` 和通用寄存器，最后恢复原始 `sp`。
2. `__alltraps` 通过 `a0` 传递 Trap frame 地址，并调用 `trap()`，返回后衔接 `__trapret` 与 `sret`。
3. 两处本人完成位置标记为 `#lab3 function1 2411795`。
4. 文件开头增加旧名称 `sbadaddr` 到框架已有 CSR 编码的映射，以通过本机现代汇编器；`SAVE_ALL` 的内容和布局未改。

正式源码中的 `trap.c`、`trap.h`、初始化、时钟和 PMM 文件均与基线一致。本交接随 A 的实现、验证脚本和证据一同发布到 `lab3` 分支，对应提交以仓库历史为准。

## 2. 下一棒需要保持的接口

- `trap(struct trapframe *tf)` 的参数是保存在当前内核栈上的现场，RV64 下大小为 288 字节。
- `tf->gpr.sp` 保存 Trap 发生前的原始 `sp`；传入的 `tf` 本身等于该值减去 288。
- C 层返回时须遵守调用约定，恢复本函数使用的栈空间；汇编仍使用原 Trap frame 起点进行加载。
- 返回地址取自 `tf->epc`，返回状态取自 `tf->status`。具体异常是否调整 `epc` 由异常处理部分负责，A 的恢复宏不自行增加固定偏移。
- 本轮验证的是 S 模式产生并返回 S 模式的 Trap，未增加用户态换栈、嵌套 Trap 或多 hart 支持。

## 3. 已有验证及边界

[最终结果 JSON](a_trap_evidence/20261028_A_publish/results.json) 中 `scope` 标明只验证 A。`all_passed=true` 表示 A 的独立检查全部通过，不表示完整 Lab3 已通过。

| 验证 | 结果 |
| --- | --- |
| A 汇编对象编译 | 通过 |
| 32 位断点、全部 GPR 保存与恢复、关闭中断后返回 | 通过 |
| 16 位压缩断点、全部 GPR 保存与恢复、开启中断后返回 | 通过 |
| C 层更新 `a0`、`epc`、`SPIE` 后返回 | 通过 |
| 256 次连续 Trap，逐次核对栈和寄存器 | 通过 |
| 空实现、错误恢复偏移两个故障对照 | 均被检出 |

正常运行累计 259 次 Trap，原始输出见 [probe_qemu.log](a_trap_evidence/20261028_A_publish/probe_qemu.log)。这是临时测试接收函数下的验证，未覆盖 B 的实际时钟处理和 C 的实际异常处理，也不是课程评分。

## 4. 接手前需处理的原工程问题

1. `trap.c` 的 `interrupt_handler()`、`exception_handler()` 尚未定义。本轮基线和当前完整编译均在这里失败。B 开始实现前，可与 C 协调编译衔接方式；需要临时接收函数时只放测试副本中，避免将替身当成 C 的正式成果。
2. 原分支的 `best_fit_pmm.c` 还会因 `free_list`、`nr_free` 未定义而编译失败，见 [基线 PMM 编译日志](a_trap_evidence/20261028_A_publish/baseline_pmm_object_build.log)。请由集成人确认如何带入实际已完成的 Lab2 页管理代码；本次没有复制或覆盖其他实验的实现。
3. 本机 QEMU 6.2.0 默认固件配合原 raw loader 参数时，启动信息显示下一跳地址为 0，未进入内核。A 的验证显式使用已有 OpenSBI v0.4 跳转固件。后续运行应明确记录所用固件和装载方式。
4. QEMU 4.1.1 的 `sret` 将 SPIE 清零，与本次标准状态检查不同。不要把该模型差异解释成应修改恢复宏来强制置位。

因此，本次交付状态是 **A 已完成并通过独立运行验证，整机联调仍待接力完成**。B 的持续时钟、计数与关机，以及 C 的异常恢复与最终评分均未在这里提前完成。

## 5. 文件清单与复验

| 文件 | 用途 |
| --- | --- |
| [trapentry.S](../code/kern/trap/trapentry.S) | 生产实现 |
| [A_trapentry.patch](a_trap_evidence/20261028_A_publish/A_trapentry.patch) | 相对上述基线、只含生产汇编修改的补丁 |
| [trap_entry_report.md](trap_entry_report.md) | 本部分的实现说明和报告素材 |
| [trap_entry_spec_prompt.md](trap_entry_spec_prompt.md) | Spec、实际输入和复现提示词 |
| [run_a_trap_checks.py](../code/tools/run_a_trap_checks.py) | 独立验证脚本，仅在临时副本构建 |
| [a_trap_evidence/README.md](a_trap_evidence/README.md) | 成功、失败和兼容性记录索引 |

在本机 WSL 中复验，输出目录必须是一个尚不存在的新目录：

```bash
cd /mnt/d/大三上/os/lab3_trap_work/code
python3 tools/run_a_trap_checks.py \
  --gcc-prefix /home/collin/riscv-elf-toolchains/bin/riscv64-unknown-elf- \
  --qemu /usr/bin/qemu-system-riscv64 \
  --bios /home/collin/opt/qemu-4.1.1/share/qemu/opensbi-riscv64-virt-fw_jump.bin \
  --output /tmp/lab3-a-recheck-20261028
```

脚本的 `--base-commit` 默认固定原始基线 `af2c810`，不依赖当前 HEAD，提交后仍以原始空实现做故障对照。脚本也检查当前工程尚缺 B/C 处理函数和 Best-Fit 定义的已知编译障碍。后续成员完成相应模块后，脚本中的“预期原工程构建失败”断言也需要随集成状态更新，不能原样作为全项目最终评分器使用。

验证脚本按标准行为检查 `sret` 后 SPIE 为 1；本机已验证的组合为 QEMU 6.2.0 与上述固件。它不会改全局 PATH，不运行原树 `make clean` 或 `make grade`，不会填写正式 B/C 源码。
