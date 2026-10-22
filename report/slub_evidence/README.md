# SLUB 验证记录

记录日期为 2026-10-22，环境为 WSL2 Ubuntu 22.04、RISC-V GCC 15.1.0、QEMU 4.1.1、单 hart。报告中的测试结果来自这些原始记录。

| 目录 | 验证对象 | 结果 |
| --- | --- | --- |
| [baseline](baseline/results.json) | A/B 原提交 `458450e` 的 Buddy 自检 | 通过 `check_alloc_page()`，尚未包含 SLUB |
| [qemu128M](qemu128M/results.json) | SLUB 分别使用 Buddy、Best-Fit、First-Fit，128 MiB | 每种后端 8/8 组，空闲页均为 31928 → 31928 |
| [qemu64M](qemu64M/results.json) | SLUB 使用 Buddy，64 MiB | 8/8 组，空闲页为 15704 → 15704 |

每个配置保存 `.build.log` 和 `.qemu.log`；`results.json` 保存实际命令、版本、镜像摘要与判定结果。SLUB 两组结果还保存构建前工作目录源码的 SHA-256。测试时只在临时副本切换 `pmm_manager`，仓库默认值始终为 Buddy。

这些测试在源码提交前执行，因此 JSON 的 `base_commit` 是开发基础 `458450e`，`baseline_from_committed_tree=false` 表示测试包含当时工作目录新增的 SLUB 源码。随后提交的代码为 [`c0e3fc2`](https://github.com/colijns/os_homework/commit/c0e3fc2cde2ff6438d9bc8fc81b821d126b38be5)；报告整合时已核对当前源码与记录中的摘要一致。不能仅凭 `base_commit` 将这些结果误认为原始 A/B 内核的 SLUB 输出。

基线的 `baseline_from_committed_tree=true` 表示它构建的是原提交本身。基线与 SLUB 版本的代码及静态数据占用不同，页泄漏检查使用同一次运行的前后计数。

内核完成检查后进入 `while (1)`。验证器收到完整成功行后结束 QEMU；日志末尾的终止提示是主动收尾。构建失败、内核断言失败和超时均不会被判为通过。上述记录不包含本轮 `make grade` 或双重 GDB 调试，相关 A/B 结果见团队报告。
