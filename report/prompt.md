## 功能模块二：核线程的创建与首次运行现场构造
负责人：2411294-王烨
````
[PROMPT] 在 kern/process/proc.c 完成 proc_init、kernel_thread、do_fork、
copy_mm、copy_thread，学号 2411294 王烨。
仅完成本人负责的进程创建与首次运行现场构造部分，
不修改 A 已交付的 alloc_proc 与 page_insert/page_remove，不实现 C 的
cpu_idle/schedule/proc_run/switch_to。
[RELY] 读取 proc.h 中 proc_struct / context / trapframe 的字段约定，
以 A 已实现的 alloc_proc（pgdir 指向 boot 页表物理地址、其余字段清零）
与 alloc_pages/free_pages/page2kva 接口为唯一分配来源，
以框架的 kernel_thread_entry、forkret、forkrets、__trapret 为切换终点。
[GUARANTEE] proc_init 先 list_init(proc_list) 与 hash_list 再创建线程；
idleproc 复用 bootstack、need_resched=1、current=idleproc、nr_process++；
initproc 通过 kernel_thread 创建，失败时 panic("create init_main failed.")，
成功后 find_proc(pid) 反查并命名 "init"，末尾 assert idleproc->pid==0
且 initproc->pid==1。
[SPECIFICATION] kernel_thread 把 fn/arg 写入 s0/s1，
tf.status=(sstatus|SPP|SPIE)&~SIE，tf.epc=kernel_thread_entry，
经 do_fork(clone_flags|CLONE_VM,0,&tf) 进入 fork 流程；
do_fork 按 alloc_proc→setup_kstack→copy_mm→copy_thread→关中断段
(get_pid+hash_proc+list_add+nr_process++)→wakeup_proc 顺序推进，
失败沿 bad_fork_cleanup_* 反向释放；copy_mm 在 CLONE_VM 时共享 mm 并
mm_count_inc；copy_thread 把 tf 置于 kstack+KSTACKSIZE-sizeof(trapframe)、
a0=0、sp=proc->tf、context.ra=forkret、context.sp=proc->tf。
通过 make qemu 验证 alloc_proc() correct! 之后无 panic、无 assert 失败，
initproc 已就绪挂入 proc_list，等待功能模块三接管调度。
````

---

## 功能模块三：进程调度
负责人：2411276-林靖然
````
[PROMPT]
任务：在 kern/process/proc.c、kern/schedule/sched.c、kern/process/switch.S 中完成功能模块三“进程调度”，实现 cpu_idle、schedule、proc_run、switch_to，打通内核线程首次执行链路。
操作要求：在项目中修改实际文件，保留现有代码与 lab4 注释，不修改 A 已交付的 page_insert/page_remove/alloc_proc，也不修改 B 已交付的 proc_init/kernel_thread/do_fork/copy_thread。
输出要求：直接进行文件操作，以工程真实代码为准，不引入无关功能。

[RELY]
数据结构：
struct context { uintptr_t ra; uintptr_t sp; uintptr_t s0..s11; };  // 共 14 个寄存器
struct proc_struct { state, pid, runs, kstack, need_resched, parent, mm, context, tf, pgdir, flags, name, list_link, hash_link };
全局变量与常量：
current、idleproc、initproc、proc_list、nr_process；PROC_RUNNABLE；SATP_MODE_SV39；RISCV_PGSHIFT；SSTATUS_SIE
可用函数与宏：
local_intr_save/local_intr_restore、intr_enable/intr_disable、read_csr/write_csr、list_next、le2proc、flush_tlb、enable_paging 中的 satp 写法（0x8000000000000000 | pgdir >> RISCV_PGSHIFT）
已有链路：
kernel_thread_entry、forkret、forkrets、__trapret；copy_thread 已把新线程 context.ra 设为 forkret、context.sp 设为 tf、tf.epc 设为 kernel_thread_entry
约束：
lsatp() 是 Sv32 遗留，无法表达 Sv39的 satp，本实验中不可用。kern/mm/pmm.c 中的 enable_paging() 为正确写法参照。

[GUARANTEE]
必须实现或修改的接口：
void cpu_idle(void);                                       // kern/process/proc.c
void schedule(void);                                       // kern/schedule/sched.c
void proc_run(struct proc_struct *proc);                   // kern/process/proc.c
void switch_to(struct context *from, struct context *to);  // kern/process/switch.S
不修改其他公开接口；如需要辅助函数，必须是 static，且只在本模块内部使用。

[SPECIFICATION]
cpu_idle
  Pre-Condition：proc_init 已完成，current 指向 idleproc，idleproc->need_resched 为 1。
  Post-Condition：函数永不返回；每次发现 current->need_resched 非 0，调用 schedule() 让出 CPU。
  Case：没有其他就绪线程时，schedule() 回退 idleproc，循环继续。
schedule
  Pre-Condition：current 合法，proc_list 与 hash_list 已初始化。
  Post-Condition：current->need_resched 置 0；选中一个 PROC_RUNNABLE 线程；选中者 runs 加 1；选中者不是 current 时调用 proc_run()。
  Case 1：current 不是 idleproc，从 current->list_link 的下一个节点开始轮转查找。
  Case 2：current 是 idleproc，从 proc_list 链表头开始查找。
  Case 3：遍历一圈没有就绪线程，回退 idleproc 保底。
  Requirements：查找、状态修改和切换在关中断临界区内完成，结束后恢复进入前的中断状态。
proc_run
  Pre-Condition：proc 是合法且可运行的 PCB。
  Post-Condition：proc 与 current 相同时不做任何事；否则 current 指向 proc，satp 指向 proc->pgdir 的页表（Sv39 模式），TLB 失效，CPU 执行现场切换到 proc。
  Case：切换必须在关中断临界区内完成，结束后恢复进入前的中断状态。
  Requirements：pgdir 保存的是页表物理地址；不得使用 lsatp()。
switch_to
  Pre-Condition：from、to 指向两个合法 context，to->ra 已由 copy_thread 设为 forkret。
  Post-Condition：from 保存旧线程的 ra、sp、s0-s11；CPU 从 to 恢复这些寄存器并返回到 to->ra。
  Requirements：只保存和恢复被调用者保存寄存器；a0、a1 作为参数寄存器不保存；偏移与 struct context 布局一致；新线程第一次被切换进来时，应能沿 forkret → forkrets → __trapret → kernel_thread_entry 进入其函数入口。
````