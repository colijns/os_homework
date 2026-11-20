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