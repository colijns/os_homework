# Lab2 提示词记录

## 阅读索引

- 本文件保留 A 的 `page_init()` 和 B 的 Buddy 提示词记录。
- C 的两份完整提示词（实现、独立测试）见 [SLUB 提示词与接口约定](slub_prompt.md)，对应 [实验报告 4.2.4 节](report.md#424-challenge任意大小的内存单元-slub-分配算法)。C 文件明确区分规范化整理与历史原文。

## 四段式提示词模板

````markdown
[PROMPT]
**任务**：修改文件 <file_path>（可以是多个文件），实现或修改 <function_name> 函数。

**操作要求**：你必须在项目中修改实际文件，而不是仅展示代码。完成函数的实现或修改，包括但不限于：函数主体、辅助函数、内部使用的静态变量等。（示例，可根据实际情况调整表述）

**输出要求**：直接进行文件操作。保留文件中的现有代码。实现或修改的代码应插入或更新到相应的位置。（示例，可根据实际情况调整表述）

[RELY]
// 宏定义
<relevant_macros>

// 数据结构
<relevant_structs>

// 可用函数
<available_functions>

[GUARANTEE]
必须实现或修改的接口：
```c
<function_signature>
```

你可以根据需要添加：
- 辅助函数（建议设为static）
- 内部使用的宏定义
- 模块内部的静态变量

[SPECIFICATION]
## <function_name>
**Pre-Condition**: 
- <前置条件>

**Post-Condition**: 
- <后置条件>

  **Case 1**:
  - <一段话描述：触发条件、执行行为和最终状态>

  **Case 2**:
  - <一段话描述：触发条件、执行行为和最终状态>

  **Case 3**:
  - <一段话描述：触发条件、执行行为和最终状态>

**Requirements**: 
- <额外的系统约束>
````

## 功能模块：`page_init()`

**负责人**：2411276 林靖然
**文件**：`kern/mm/pmm.c`

### 最终提示词

以下是本任务使用的最终提示词（以 `[Test 1] Page Init: PASS` 为定稿标准）：

````markdown

[PROMPT]

你需要帮助我完成ucore实验。根据code文件夹下的代码，严格按照下面的要求，完成`kern/mm/pmm.c`里`page_init()`函数的编写。

**任务**：根据设备树提供的物理内存信息建立可管理物理页的描述符布局，并把排除 OpenSBI、内核镜像和描述符数组占用空间后的完整空闲页面交给当前`pmm_manager`管理，为后续页面分配提供正确的初始状态。`page_init()`不接收参数也不返回结果，由`pmm_init()`调用；成功返回时应正确设置`va_pa_offset`、`npage`和`pages`，输出探测到的物理内存范围，并完成当前物理内存管理器初始空闲区的注册。

**操作要求**：
- 必须在项目中修改实际文件。
- test2的best fit属于另外一个任务，不需要完成。你只需要完成test1的page init。
- 保留已有代码、注释、缩进和命名风格；不要新增无关文件或全局状态。
- 保留 `lab2` 注释，并将该标记中的 `YOUR CODE` 替换为负责人 `2411276林靖然`；不要改动其他注释。
- 完成后执行构建和测试，并如实反馈结果。测试方法：
```
   cd ~/os_homework/code
   make grade
```
只看： [Test 1] Page Init: PASS。整体退出码可能仍是失败，因为 [Test 2] Best-Fit 本来就不需要你完成，不用管。

**输出要求**：直接进行文件操作，以实际代码为准，不要引入无关功能。完成后简要说明修改点、实际执行的验证命令和输出。

[RELY]

先阅读并严格以当前源码为准：

- `kern/mm/pmm.c`、`kern/mm/pmm.h`、`kern/mm/memlayout.h`、`kern/mm/mmu.h`
- `kern/driver/dtb.h`、`kern/driver/dtb.c`
- `kern/mm/default_pmm.c`，重点看 `default_init_memmap()` 对 `PageReserved` 的前置断言
- `kern/init/init.c`，确认 `dtb_init()` 和 `pmm_init()` 的调用顺序
- `tools/test_lab2.c`，确认 `test_page_init()` 的验收条件
- `tools/kernel.ld` 中的 `end` 符号，以及 `libs/defs.h` 中的 `ROUNDUP` / `ROUNDDOWN`

可用定义与接口：

- 函数：`get_memory_base()`、`get_memory_size()`、`panic()`、`cprintf()`、`init_memmap()`、`page2pa()`、`set_page_ref()`等
- 链接符号end、struct Page及相关全局变量
- 使用框架提供的内存上界、地址转换、页面对齐和页面状态宏完成初始化
- 链接符号：`extern char end[]`，它是内核镜像末尾的虚拟地址，不是物理地址

关键地址关系：

- `pages` 是描述符数组的虚拟地址；`PADDR(pages)` 才是描述符数组实际占用的物理地址。
- 数组中第一个描述符所描述的是 `DRAM_BASE` 对应的物理页，不是描述符数组自身的存储位置；两者不能混用。
- `PADDR` 依赖 `va_pa_offset`，必须先设置映射偏移再转换地址；`KADDR` 在本工程中不可用。
- `init_memmap(base, n)` 的 `base` 是 `struct Page *`，`n` 是页数，不是字节数。

[GUARANTEE]

必须实现或修改的接口：

```c
static void page_init(void);
```

- 位置：`kern/mm/pmm.c` 中 `//lab2 function1 YOUR CODE` 处，函数定义应位于 `pmm_init()` 之前，或补充 `static` 前向声明。
- 不得改变函数签名、返回类型和调用关系。
- 允许添加完成该函数所必需的局部变量、内部宏和 `static` 辅助函数；不得新增全局变量，不得修改 `struct Page` 或 `pmm_manager` 接口。
- 严禁修改测试和评分相关代码。

[SPECIFICATION]

## page_init

DTB 无效→`panic()`
数组放不下或无完整页→`panic()` 不登记
末端不对齐→向下取整

**Requirements**:区分虚拟地址、物理地址、物理页号和Page描述符地址，正确处理可管理上界和页面对齐，并确保内核及描述符数组不会进入空闲区；设备树信息无效时应终止初始化，没有可用完整页面时不得调用init_memmap()。

````
## 功能模块：`buddy_fit_pmm.c`
**负责人**：2411294 王烨
**文件**：`kern/mm/buddy_fit_pmm.c`

### 最终提示词

以下是本任务使用的最终提示词（以 `[Test 2] buddy_check: succeeded` 为定稿标准）：
由于best_fit_pmm.c，best_fit_pmm.h和buddy_fit_pmm.h为完全人工实现，此处无提示词撰写。
````markdown

[PROMPT]

你需要帮助我完成ucore实验。根据code文件夹下的代码，严格按照下面的要求，完成`kern/mm/buddy_fit_pmm.c`的功能完善。

**任务**：修改文件 kern/mm/buddy_fit_pmm.c，实现伙伴系统（Buddy System）页面分配算法，即完善 `buddy_fit_pmm_manager` 的全部六个成员函数：`init`、`init_memmap`、`alloc_pages`、`free_pages`、`nr_free_pages`、`check`。当前已实现了`init`、`free_pages`和`nr_free_pages`三个函数的实现，如果存在实现不严谨或者错误的部分，做出修改，如果没有则不做修改。

**操作要求**：
- 必须在项目中修改实际文件。
- 保留已有代码、注释、缩进和命名风格；不要新增无关文件或全局状态。
- 完成后执行构建和测试，并如实反馈结果。测试方法：
```
   cd ~/project/os_homework/code
   make
   make qemu
```
观察到： buddy_check succeeded! check_alloc_page() succeeded! 即代表实现正确。

**输出要求**：直接进行文件操作，以实际代码为准，不要引入无关功能。完成后简要说明修改点、实际执行的验证命令和输出。

[RELY]

先阅读并严格以当前源码为准：

- `kern/mm/pmm.c`、`kern/mm/pmm.h`、`kern/mm/memlayout.h`、`kern/mm/mmu.h`
- `kern/mm/default_pmm.c`，重点看 `default_init_memmap()` 对 `PageReserved` 的前置断言
- `kern/init/init.c`，确认 `dtb_init()` 和 `pmm_init()` 的调用顺序
- `tools/test_lab2.c`，确认 `test_page_init()` 的验收条件

可用定义与接口：

- 函数：`get_memory_base()`、`get_memory_size()`、`panic()`、`cprintf()`、`init_memmap()`、`page2pa()`、`set_page_ref()`等
- 链接符号end、struct Page及相关全局变量
- 使用框架提供的内存上界、地址转换、页面对齐和页面状态宏完成初始化
- 链接符号：`extern char end[]`，它是内核镜像末尾的虚拟地址，不是物理地址

关键地址关系：

- 伙伴的定位必须基于物理页号：order 级伙伴 `pfn’ = pfn ^ (1 << order)`；数组下标（page - pages）不等于物理页号，两者不能混用。
- 空闲块以"块头页"标识：PG_property 置 1 且 `property = 2^order`；块内其余页的 flags / property 必须为 0，这是判断"伙伴是否为同阶空闲块头"的唯一依据。
- `alloc_pages(n)` 返回连续 `2^k` 页的首个 Page（`2^k` 为不小于 n 的最小 2 的幂），`free_pages(base, n)` 按同样的取整规则归还，二者必须对称。
[GUARANTEE]

必须实现或修改的接口：

```c
static void buddy_init_memmap(struct Page *base, size_t n);
static void buddy_alloc_pages(size_t n);
static void buddy_check(void);
```

- 位置：`kern/mm/buddy_fit_pmm.c` 中。
- 不得改变函数签名、返回类型和调用关系。
- 允许添加完成该函数所必需的局部变量、内部宏和 `static` 辅助函数；不得新增全局变量，不得修改 `struct Page` 或 `pmm_manager` 接口。
- 严禁修改测试和评分相关代码。

[SPECIFICATION]

## buddy_fit_pmm_manager
n ≤ 0→断言拦截
init_memmap 收到未 Reserved 的页→断言拦截
空闲页不足或无足够大的连续块→返回 NULL，不改变任何状态
init_memmap(base, n)→按物理页号自然对齐贪心切分为若干 2^order 块入对应分级链表，nr_free 累计为 n
alloc_pages(n)→n 向上取整到 2^k，自 k 级向上找第一个非空链表摘块并逐级二分，右半块挂回低一级链表，返回左半块，nr_free 减 2^k
free_pages(base, n)→同一向上取整规则，pfn XOR 2^order 定位伙伴，伙伴为同阶空闲块头则摘下合并升级（块头取地址低者），直至不可合并后入链，nr_free 增 2^k

**Requirements**:check 必须覆盖指导书"比较充分的测试用例"的要求：至少包含单页分配/释放、非 2 幂请求的向上取整与块对齐断言、大块分裂后分两半释放的完全合并、连续多页分配后逆序释放的页数守恒；测试逻辑全部收在 buddy_fit_pmm.c 内部，通过 .check 成员触发。

````
