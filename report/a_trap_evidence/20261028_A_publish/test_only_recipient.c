
/* TEST ONLY: a minimal C recipient, not B/C's interrupt/exception handlers. */
#include <defs.h>
#include <intr.h>
#include <riscv.h>
#include <sbi.h>
#include <stdio.h>
#include <trap.h>

_Static_assert(sizeof(uintptr_t) == 8, "This probe targets RV64");
_Static_assert(sizeof(struct trapframe) == 288, "Trap frame size");
_Static_assert(__builtin_offsetof(struct trapframe, status) == 256, "status offset");
_Static_assert(__builtin_offsetof(struct trapframe, epc) == 264, "epc offset");
_Static_assert(__builtin_offsetof(struct trapframe, badvaddr) == 272, "badvaddr offset");
_Static_assert(__builtin_offsetof(struct trapframe, cause) == 280, "cause offset");

uintptr_t a_expected[32], a_observed[32];
uintptr_t a_after_status, a_after_epc, a_after_scratch;
static uintptr_t entry_pc, resume_pc;
static unsigned long traps;
static int entry_ie, return_ie, mutate;
extern char a_break32[], a_break16[], a_resume32[], a_resume16[], a_redirect32[];
extern void a_probe32(void), a_probe16(void);

static void fail(const char *what, int reg, uintptr_t expected, uintptr_t actual) {
    intr_disable();
    cprintf("A_TRAP_FAIL %s reg=%d expected=%p actual=%p\n",
            what, reg, (void *)expected, (void *)actual);
    sbi_shutdown();
    while (1) { }
}

void a_probe_handle(struct trapframe *tf) {
    uintptr_t *gpr = (uintptr_t *)&tf->gpr;
    if ((uintptr_t)tf != a_expected[2] - sizeof(*tf) || ((uintptr_t)tf & 15))
        fail("frame pointer/alignment", 2, a_expected[2] - sizeof(*tf), (uintptr_t)tf);
    if (tf->cause != 3 || tf->epc != entry_pc)
        fail("entry cause/epc", -1, entry_pc, tf->epc);
    if (!(tf->status & SSTATUS_SPP) || (tf->status & SSTATUS_SIE) ||
        !!(tf->status & SSTATUS_SPIE) != entry_ie)
        fail("entry status", -1, entry_ie, tf->status);
    for (int i = 0; i < 32; ++i)
        if (gpr[i] != a_expected[i]) fail("saved gpr", i, a_expected[i], gpr[i]);
    ++traps;

    /* Test a caller editing the saved frame, including the return CSRs. */
    tf->epc = resume_pc;
    if (mutate) {
        tf->gpr.a0 = 0x8877665544332211UL;
        tf->status |= SSTATUS_SPIE;
    }
}

static void run_one(int compressed, int enabled, int edit) {
    intr_disable();
    for (int i = 0; i < 32; ++i) a_expected[i] = 0x1122334455667700UL + i;
    a_expected[0] = 0;
    entry_ie = enabled;
    return_ie = enabled || edit;
    mutate = edit;
    entry_pc = (uintptr_t)(compressed ? a_break16 : a_break32);
    resume_pc = (uintptr_t)(edit ? a_redirect32 : (compressed ? a_resume16 : a_resume32));
    unsigned long before = traps;
    if (enabled) intr_enable();
    if (compressed) a_probe16(); else a_probe32();
    intr_disable();
    if (traps != before + 1) fail("trap count", -1, before + 1, traps);
    for (int i = 0; i < 32; ++i) {
        uintptr_t expected = edit && i == 10 ? 0x8877665544332211UL : a_expected[i];
        if (a_observed[i] != expected) fail("restored gpr", i, expected, a_observed[i]);
    }
    if (!!(a_after_status & SSTATUS_SIE) != return_ie ||
        !(a_after_status & SSTATUS_SPIE) || (a_after_status & SSTATUS_SPP))
        fail("sret status", -1, return_ie, a_after_status);
    if (a_after_epc != resume_pc) fail("restored epc", -1, resume_pc, a_after_epc);
    if (a_after_scratch != 0) fail("scratch convention", -1, 0, a_after_scratch);
}

void a_probe_run(void) {
    intr_disable();
    write_csr(sie, 0);
    cprintf("A_TRAP_PROBE test-only C recipient; B/C remain unimplemented\n");
    run_one(0, 0, 0);
    cprintf("A_TRAP_CASE1 PASS 32-bit breakpoint, all GPRs, SIE=0\n");
    run_one(1, 1, 0);
    cprintf("A_TRAP_CASE2 PASS 16-bit breakpoint, all GPRs, SIE=1\n");
    run_one(0, 0, 1);
    cprintf("A_TRAP_CASE3 PASS edited a0, epc redirection, SPIE -> SIE\n");
    for (int i = 0; i < 256; ++i) run_one(i & 1, (i >> 1) & 1, 0);
    cprintf("A_TRAP_CASE4 PASS 256 repeated traps, stable stack\n");
    cprintf("A_TRAP_ALL_PASS cases=4 traps=%d\n", (int)traps);
    sbi_shutdown();
    while (1) { }
}
