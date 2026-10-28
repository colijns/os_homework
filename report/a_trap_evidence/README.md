# Trap 入口验证证据索引

整理日期：2026-10-28。所有“通过”均指 A 的独立验证，不代表完整 Lab3 或课程评分通过。

## 最终可复查结果

目录：[20261028_A_publish](20261028_A_publish/)。

- [results.json](20261028_A_publish/results.json)：基线、所有源码 SHA-256、命令、返回码、超时状态、验证结果、固件和镜像摘要。
- [a_object_build.log](20261028_A_publish/a_object_build.log)：A 汇编对象编译通过。
- [trapentry_disassembly.txt](20261028_A_publish/trapentry_disassembly.txt)：实际对象反汇编。
- [probe_kernel_build.log](20261028_A_publish/probe_kernel_build.log)：临时测试内核编译通过。
- [probe_qemu.log](20261028_A_publish/probe_qemu.log)：四组通过，共 259 次 Trap，正常关机，未超时。
- [unfilled_A_qemu.log](20261028_A_publish/unfilled_A_qemu.log)：空实现没有成功标记，4 秒后由验证器结束。即使 QEMU 响应终止后返回码为 0，仍由 `timed_out=true` 判为故障被检出。
- [wrong_a0_offset_qemu.log](20261028_A_publish/wrong_a0_offset_qemu.log)：第 10 个寄存器从错误槽位恢复，输出 `A_TRAP_FAIL`。故障内核主动关机也可能返回 0，不能只看退出码。
- [baseline_full_build.log](20261028_A_publish/baseline_full_build.log)、[a_full_build_without_B_C.log](20261028_A_publish/a_full_build_without_B_C.log)：正式中断、异常处理函数尚未定义造成的构建失败。
- [baseline_pmm_object_build.log](20261028_A_publish/baseline_pmm_object_build.log)：基线 Best-Fit 的 `free_list`、`nr_free` 未定义。
- [A_trapentry.patch](20261028_A_publish/A_trapentry.patch)：仅生产汇编修改。

`test_only_recipient.c`、`test_only_probe.S`、`probe_kernel.elf`、`probe_ucore.img` 均是 A 的专用验证材料。测试副本跳过 PMM，并替代了未完成的 C 层分发尾部；这些文件不能作为 B/C 的生产实现或完整 Lab3 镜像提交。

最终实测：Ubuntu 22.04、GCC 15.1.0、QEMU 6.2.0、OpenSBI v0.4、RV64、单 hart、128 MiB，raw loader 地址 `0x80200000`。命令行显式指定了固件，而非使用 QEMU 6.2.0 默认固件。

发布前复验固定了原始基线，避免提交后将新的 HEAD 误当成空实现。`20261028_A_final` 是此前首次完整通过的记录；`20261028_A_publish` 是上述脚本调整后的发布前复验，生产汇编内容相同。

## 开发中保留的失败轮次

| 目录 | 实际情况 | 后续处理 |
| --- | --- | --- |
| `20261027_A_01` | A 对象汇编报告不认识旧 CSR 名称 `sbadaddr` | 在生产汇编文件开头使用框架已有编码兼容，保留 `SAVE_ALL` 内容 |
| `20261027_A_02` | 验证脚本的 C/S 同名导致目标冲突；同时暴露原分支 Best-Fit 编译障碍 | 验证文件改名，仅在临时验证内核中跳过 PMM |
| `20261027_A_03` | 临时内核编译并进入 C 接收函数，寄存器检查通过后，按标准检查 SPIE 失败 | 对照 QEMU 版本源码确认 4.1.1 模型差异，最终用 6.2.0 检查标准行为 |

这些轮次未通过完整独立测试，不能与最终通过结果合并计数。目录名是创建时使用的标签，最终验证日期以上述最终记录为准。

## 模拟器和固件诊断

- [qemu62_default_diagnostic.log](qemu62_default_diagnostic.log)：同一测试镜像使用 QEMU 6.2.0 默认固件，打印下一跳地址为 0，6 秒内未进入内核。
- [qemu62_opensbi04_diagnostic.log](qemu62_opensbi04_diagnostic.log)：同一镜像改用已有 OpenSBI v0.4 固件，四组检查全部通过。
- QEMU 4.1.1 的 `helper_sret` 将 SPIE 设为 0，而 6.2.0 将其设为 1。参见 [4.1.1 源码](https://github.com/qemu/qemu/blob/v4.1.1/target/riscv/op_helper.c)、[6.2.0 源码](https://github.com/qemu/qemu/blob/v6.2.0/target/riscv/op_helper.c)；标准行为见 [RISC-V Supervisor ISA](https://docs.riscv.org/reference/isa/v20260120/priv/supervisor.html)。

原始失败与最终验证均如实保留，没有将超时当作正常运行成功，也没有根据版本名称假定固件兼容。
