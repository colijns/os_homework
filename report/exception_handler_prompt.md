# Lab3 exception_handler 提示词记录

## 功能模块：`exception_handler`

**负责人**：2411276 林靖然
**文件**：`kern/trap/trap.c`

### 最终提示词

以下是本任务使用的最终提示词：

````markdown

[PROMPT]

你需要帮助我完成ucore实验。根据code文件夹下的代码，严格按照下面的要求，完成`kern/trap/trap.c`里`exception_handler`函数的编写。

**任务**：实现 `void exception_handler(struct trapframe *tf)`，对 Trap 入口传递过来的异常进行具体分类和处理。

`exception_handler()` 负责处理实验要求的异常，其中非法指令异常和断点异常需要输出规定格式的信息，并根据对应指令的长度正确更新 `tf->epc`，使 Trap 返回以后不会重复执行已经触发异常的指令；其他未要求具体处理的异常则使用已有的 `print_trapframe(tf)` 作为兜底处理。这个模块完成后，系统应能够对实验要求的时钟中断、非法指令异常和断点异常进行正确识别和处理。

这里你只负责`exception_handler()`函数，不要修改`interrupt_handler()`，因为这是其他人负责的。

不得修改 `interrupt_handler()`、`trap_dispatch()`、`trap()`、`print_trapframe()`、`struct trapframe` 和 `trapentry.S`。

**操作要求**：
- 只修改 `kern/trap/trap.c` 中 `exception_handler()` 的函数体；不得改动函数签名、`struct trapframe`、`trapentry.S` 中的 `SAVE_ALL`/`RESTORE_ALL`/`__alltraps`，也不得改动 `interrupt_handler()`、`trap_dispatch()`、`trap()`。
- 保留已有代码、注释、缩进和命名风格；不要新增无关文件或全局状态。
- 保留 `lab3` 注释，把关于`exception_handler()`的类似 `//lab3 function2 YOUR CODE` 中的 `YOUR CODE` 替换为 `2411276 林靖然`。注意，只替换`exception_handler()`部分，其他部分的注释不要也给替换了，因为这并不是我负责的。

**输出要求**：直接进行文件操作，以实际代码为准；完成后简要说明修改点。

[RELY]

先阅读并严格以当前源码为准：

- `kern/trap/trap.c`：`exception_handler()` 的待实现位置、`print_trapframe()` 的输出格式、`trap_dispatch()` 的正负号分派。
- `kern/trap/trap.h`：`struct trapframe` 和 `struct pushregs` 的字段布局。
- `kern/trap/trapentry.S`：`SAVE_ALL`/`RESTORE_ALL` 如何保存和恢复 `epc`、`cause`，以及 `sret` 的返回地址来源。
- `libs/riscv.h`：`CAUSE_ILLEGAL_INSTRUCTION`、`CAUSE_BREAKPOINT` 以及中断/异常原因编码。
- `tools/test_lab3.c`、`tools/test_lab3_context.S`、`tools/grade.sh`：验收输出和测试构造方式。

这个模块主要依赖 `struct trapframe`、`trap_dispatch()`、`interrupt_handler()`、`exception_handler()`、`print_trapframe()`、`clock_set_next_event()`、`ticks`、`TICK_NUM、SHUTDOWN_AFTER`、`IRQ_S_TIMER`、`CAUSE_ILLEGAL_INSTRUCTION`、`CAUSE_BREAKPOINT` 以及 `libs/sbi.h` 中提供的关机相关接口。

其中 `tf->cause` 用于判断当前 Trap 类型，`tf->epc` 用于记录和调整 Trap 返回后的执行位置，`ticks` 用于记录时钟中断次数。具体接口和宏均以实验框架中已有定义为准。


[GUARANTEE]

必须实现或修改的接口：
```c
void exception_handler(struct trapframe *tf);
```
- 不得改变函数签名、返回类型和调用关系；`trap_dispatch()` 仍按 `(intptr_t)tf->cause < 0` 分派。
- 允许添加函数内局部变量和仅本文件使用的 `static` 辅助函数；不得新增全局变量，不得修改 `struct trapframe`、`print_trapframe()`、`interrupt_handler()`。
- 不得修改测试、评分代码和 `trapentry.S`。

````
