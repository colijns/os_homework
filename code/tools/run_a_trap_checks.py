#!/usr/bin/env python3
"""Verify only Lab3 A using disposable kernels; never fill B/C in the source tree."""

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import tempfile
import time
from pathlib import Path


CODE = Path(__file__).resolve().parents[1]
REPO = CODE.parent
ENTRY = "kern/trap/trapentry.S"
PASS = "A_TRAP_ALL_PASS cases=4 traps=259"
SEED = 0x1122334455667700
REPLACEMENT = 0x8877665544332211
DEFAULT_BASE_COMMIT = "af2c81071525e4cc38b3a68b1cb959d1a0f23467"


PROBE_C = r'''
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
'''


def probe_asm():
    # The public probe functions obey the C ABI even though the test poisons
    # every GPR except sp inside its private trap recipient.
    preserved = [1, 3, 4, 8, 9] + list(range(18, 28))
    save = ["    addi sp, sp, -128"]
    save += [f"    sd x{reg}, {i * 8}(sp)" for i, reg in enumerate(preserved)]
    save += ["    la t0, a_expected", "    sd sp, 16(t0)",
             "    sd gp, 24(t0)", "    sd tp, 32(t0)"]
    save += [f"    li x{reg}, 0x{SEED + reg:016x}" for reg in range(1, 32)
             if reg not in (2, 3, 4)]
    lines = ["/* TEST ONLY: private GPR poisoner and register snapshots. */",
             "#include <riscv.h>", "    .text", "    .option push", "    .option norelax"]
    for bits in (32, 16):
        lines += ["    .balign 4", f"    .globl a_probe{bits}", f"a_probe{bits}:"]
        lines += save
        lines += [f"    .globl a_break{bits}", f"a_break{bits}:",
                  "    .word 0x00100073" if bits == 32 else "    .2byte 0x9002",
                  f"    .globl a_resume{bits}", f"a_resume{bits}:", "    j .Lcapture"]
        if bits == 32:
            lines += ["    .globl a_redirect32", "a_redirect32:", "    j .Lcapture"]
    lines += [".Lcapture:", "    csrw sscratch, t0", "    la t0, a_observed"]
    lines += [f"    sd x{reg}, {reg * 8}(t0)" for reg in range(32) if reg != 5]
    lines += ["    csrr t1, sscratch", "    sd t1, 40(t0)", "    csrw sscratch, zero"]
    for csr, symbol in (("sstatus", "a_after_status"), ("sepc", "a_after_epc"),
                        ("sscratch", "a_after_scratch")):
        lines += [f"    csrr t1, {csr}", f"    la t0, {symbol}", "    sd t1, 0(t0)"]
    lines += [f"    ld x{reg}, {i * 8}(sp)" for i, reg in enumerate(preserved)]
    lines += ["    addi sp, sp, 128", "    ret", "    .balign 4", "    .globl trap", "trap:",
              "    addi sp, sp, -16", "    sd ra, 0(sp)", "    call a_probe_handle",
              "    ld ra, 0(sp)", "    addi sp, sp, 16", "    csrw sscratch, ra"]
    lines += [f"    li x{reg}, 0x{0xDECAFBAD00000000 + reg:016x}" for reg in range(1, 31)
              if reg != 2]
    lines += ["    csrr t6, sscratch", "    csrw sscratch, zero", "    jr t6", "    .option pop"]
    return "\n".join(lines) + "\n"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def snapshot():
    return {str(p.relative_to(CODE)): sha(p) for p in CODE.rglob("*") if p.is_file()}


def execute(command, directory, logfile, timeout=60):
    start = time.monotonic()
    process = subprocess.Popen(command, cwd=directory, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, start_new_session=True)
    timed_out = False
    try:
        data, _ = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        timed_out = True
        process.terminate()
        data, _ = process.communicate(timeout=5)
    logfile.write_bytes(data)
    return {"command": command, "cwd": str(directory), "log": str(logfile),
            "exit_code": process.returncode, "timed_out": timed_out,
            "seconds": round(time.monotonic() - start, 3)}, data.decode("utf-8", "replace")


def make_copy(root, name):
    target = root / name
    shutil.copytree(CODE, target, ignore=shutil.ignore_patterns("obj", "bin", "__pycache__"))
    return target


def add_probe(tree):
    # Preserve the real initialization/helpers but remove the incomplete B/C
    # dispatcher only in this disposable copy. The public trap ABI is unchanged.
    trap = tree / "kern/trap/trap.c"
    text = trap.read_text()
    assert text.count("//lab3 function2 YOUR CODE") == 1
    trap.write_text(text.split("//lab3 function2 YOUR CODE")[0])
    (tree / "kern/trap/a_probe.c").write_text(PROBE_C)
    (tree / "kern/trap/a_probe_entry.S").write_text(probe_asm())
    init = tree / "kern/init/init.c"
    text = init.read_text()
    text, count = re.subn(r"\bclock_init\(\);", "a_probe_run();\n    clock_init();", text)
    assert count == 1
    text, count = re.subn(r"\bpmm_init\(\);", "/* A-only probe: unfinished PMM is not exercised. */", text)
    assert count == 1
    text = text.replace("int kern_init(void)", "void a_probe_run(void);\n\nint kern_init(void)", 1)
    init.write_text(text)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--gcc-prefix", required=True)
    parser.add_argument("--qemu", required=True)
    parser.add_argument("--bios", default="default", help="Firmware path or QEMU's default firmware")
    parser.add_argument("--base-commit", default=DEFAULT_BASE_COMMIT,
                        help="Original unfilled Lab3 baseline; independent of the current HEAD")
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        parser.error("Choose a new output directory; existing evidence is never overwritten")
    output.mkdir(parents=True)
    initial = snapshot()
    result = {"scope": "Lab3 A only; test C recipients are not B/C implementations",
              "source_root": str(CODE), "source_sha256": initial,
              "base_commit": subprocess.check_output(
                  ["git", "rev-parse", "--verify", args.base_commit + "^{commit}"],
                  cwd=REPO, text=True).strip(),
              "probe_configuration": {
                  "bios": args.bios,
                  "bios_sha256": sha(Path(args.bios)) if Path(args.bios).is_file() else None,
                  "expected_sret_SPIE": 1,
                  "PMM": "Unfinished PMM source files excluded only in disposable probe builds",
                  "C_recipient": "Test-only frame checks and fixed breakpoint return targets; not B/C implementations",
              },
              "checks": {}, "commands": [], "all_passed": False}
    def run(command, cwd, log, timeout=60):
        record, text = execute(command, cwd, output / log, timeout)
        result["commands"].append(record)
        return record, text
    def build(tree, log, target=None, probe=False):
        command = ["make", "-j2", "GCCPREFIX=" + args.gcc_prefix]
        if probe:
            command.append("KSRCDIR=kern/init kern/libs kern/debug kern/driver kern/trap")
        if target:
            command.append(target)
        return run(command, tree, log)
    try:
        for name, command in (("gcc", [args.gcc_prefix + "gcc", "--version"]),
                              ("qemu", [args.qemu, "--version"])):
            record, _ = run(command, CODE, name + "_version.txt")
            assert record["exit_code"] == 0, name
        baseline_entry = subprocess.check_output(
            ["git", "show", result["base_commit"] + ":code/" + ENTRY], cwd=REPO)
        baseline_text = baseline_entry.decode()
        current_text = (CODE / ENTRY).read_text()
        save_macro = lambda text: re.search(r"    \.macro SAVE_ALL\b.*?    \.endm", text, re.S).group()
        assert save_macro(baseline_text) == save_macro(current_text)
        result["checks"]["existing_SAVE_ALL_unchanged"] = True

        with tempfile.TemporaryDirectory(prefix="lab3-a-checks-") as temporary:
            root = Path(temporary)
            baseline = make_copy(root, "baseline")
            (baseline / ENTRY).write_bytes(baseline_entry)
            record, text = build(baseline, "baseline_full_build.log")
            result["baseline_full_build"] = record
            assert record["exit_code"] != 0 and all(
                word in text for word in ("interrupt_handler", "exception_handler"))
            result["checks"]["baseline_B_C_handlers_missing"] = True
            record, text = build(baseline, "baseline_pmm_object_build.log", "obj/kern/mm/best_fit_pmm.o")
            assert record["exit_code"] != 0 and all(word in text for word in ("free_list", "nr_free"))
            result["baseline_PMM_build_blocker"] = record

            current = make_copy(root, "a_source")
            record, text = build(current, "a_object_build.log", "obj/kern/trap/trapentry.o")
            assert record["exit_code"] == 0 and not record["timed_out"], text[-3000:]
            result["checks"]["A_assembly_object_build"] = True
            obj = current / "obj/kern/trap/trapentry.o"
            shutil.copy2(obj, output / "trapentry.o")
            run([args.gcc_prefix + "objdump", "-dr", str(obj)], current, "trapentry_disassembly.txt")
            record, text = build(current, "a_full_build_without_B_C.log")
            result["a_full_build_without_B_C"] = record
            assert record["exit_code"] != 0 and all(
                word in text for word in ("interrupt_handler", "exception_handler"))
            result["checks"]["full_build_blocked_by_B_C_as_expected"] = True
            print("A object compiled; original full build requires B/C handlers", flush=True)

            positive = make_copy(root, "runtime_probe")
            add_probe(positive)
            record, text = build(positive, "probe_kernel_build.log", probe=True)
            assert record["exit_code"] == 0 and not record["timed_out"], text[-5000:]
            result["checks"]["isolated_probe_kernel_build"] = True
            for source, dest in (("kern/trap/a_probe.c", "test_only_recipient.c"),
                                 ("kern/trap/a_probe_entry.S", "test_only_probe.S"),
                                 ("bin/kernel", "probe_kernel.elf"),
                                 ("bin/ucore.img", "probe_ucore.img")):
                shutil.copy2(positive / source, output / dest)
            result["probe_image_sha256"] = sha(positive / "bin/ucore.img")

            def boot(tree, log, timeout):
                return run([args.qemu, "-machine", "virt", "-m", "128M", "-smp", "1",
                            "-nographic", "-bios", args.bios, "-device",
                            "loader,file=bin/ucore.img,addr=0x80200000", "-monitor", "none",
                            "-no-reboot"], tree, log, timeout)
            record, text = boot(positive, "probe_qemu.log", 15)
            assert record["exit_code"] == 0 and not record["timed_out"] and PASS in text, text[-5000:]
            assert "A_TRAP_FAIL" not in text
            for number in range(1, 5):
                assert f"A_TRAP_CASE{number} PASS" in text
                result["checks"][f"runtime_case_{number}"] = True
            print(PASS, flush=True)

            # Prove the probe rejects the unfilled entry and a wrong a0 offset.
            negative_records = []
            compatible_unfilled = (current_text.split("    .macro SAVE_ALL", 1)[0]
                                   + "    .macro SAVE_ALL" + baseline_text.split("    .macro SAVE_ALL", 1)[1])
            for name, entry_text in (("unfilled_A", compatible_unfilled),
                    ("wrong_a0_offset", current_text.replace(
                        "LOAD x10, 10*REGBYTES(sp)", "LOAD x10, 11*REGBYTES(sp)", 1))):
                negative = make_copy(root, name)
                add_probe(negative)
                (negative / ENTRY).write_text(entry_text)
                record, text = build(negative, name + "_build.log", probe=True)
                assert record["exit_code"] == 0 and not record["timed_out"], text[-3000:]
                record, text = boot(negative, name + "_qemu.log", 4)
                detected = PASS not in text and (
                    "A_TRAP_FAIL" in text or record["timed_out"] or record["exit_code"] != 0)
                assert detected, name
                negative_records.append({"name": name, "detected": detected, **record})
                result["checks"]["negative_control_" + name] = True
                print("Rejected negative control: " + name, flush=True)
            result["negative_controls"] = negative_records
        assert snapshot() == initial, "Validation modified the source tree"
        result["checks"]["source_tree_unchanged_by_validation"] = True
        result["all_passed"] = True
    finally:
        result["source_tree_unchanged"] = snapshot() == initial
        (output / "results.json").write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n")
    print("Evidence: " + str(output), flush=True)


if __name__ == "__main__":
    main()
