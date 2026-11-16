#!/usr/bin/env python3
"""Compile A's real C functions with a host-side physical-memory/TLB model.

Run with Python 3 and GCC on Windows or Linux. This checks C logic and failure
paths; it does not emulate RISC-V instructions or replace a QEMU kernel run.
"""

import argparse
import os
from pathlib import Path
import re
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]


def braced(source, pattern, semicolon=False):
    match = re.search(pattern, source, re.MULTILINE)
    if match is None:
        raise ValueError("Source definition not found: " + pattern)
    start = source.index("{", match.start())
    # Ignore braces inside comments and literals when locating the definition.
    token = re.compile(r'/\*.*?\*/|//[^\n]*|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|[{}]', re.DOTALL)
    depth = 0
    for item in token.finditer(source, start):
        if item.group() == "{":
            depth += 1
        elif item.group() == "}":
            depth -= 1
            if depth == 0:
                end = item.end()
                if semicolon:
                    end = source.index(";", end) + 1
                return source[match.start():end] + "\n"
    raise ValueError("Unclosed definition")


def function(source, name):
    return braced(source, r'^(?:(?:static|inline)\s+)*(?:struct\s+\w+|\w+)\s+\**\s*' + re.escape(name) + r'\s*\([^;{}]*\)\s*\{')


def read(relative):
    return (ROOT / relative).read_text(encoding="utf-8")


def generate(directory):
    pmm, proc = read("kern/mm/pmm.c"), read("kern/process/proc.c")
    ph, mh, prh = read("kern/mm/pmm.h"), read("kern/mm/memlayout.h"), read("kern/process/proc.h")
    types = [read("kern/mm/mmu.h").replace("#include <defs.h>", ""), read("libs/list.h").replace("#include <defs.h>", "")]
    types.extend(re.findall(r'^typedef uintptr_t (?:pte_t|pde_t);', mh, re.MULTILINE))
    types.append(braced(mh, r'^struct Page\s*\{', True))
    types.append(braced(mh, r'^typedef struct\s*\{\s*\n\s*list_entry_t free_list;', True))
    types.append(braced(prh, r'^enum proc_state\s*\{', True))
    types.append(braced(prh, r'^struct context\s*\{', True))
    types.append(re.search(r'^#define PROC_NAME_LEN .*$', prh, re.MULTILINE).group())
    types.append(braced(prh, r'^struct proc_struct\s*\{', True))
    (directory / "a_types.h").write_text("\n".join(types), encoding="utf-8")
    helper_names = ["page2ppn", "page2pa", "pa2page", "pte2page", "page_ref", "set_page_ref", "page_ref_inc", "page_ref_dec", "pte_create"]
    (directory / "a_helpers.h").write_text("\n".join(function(ph, name) for name in helper_names), encoding="utf-8")
    functions = [function(pmm, name) for name in ["get_pte", "page_remove_pte", "page_remove", "page_insert"]]
    functions.append(function(proc, "alloc_proc"))
    (directory / "a_functions.h").write_text("\n".join(functions), encoding="utf-8")
    best = read("kern/mm/best_fit_pmm.c")
    (directory / "a_bestfit.h").write_text("\n".join(function(best, name) for name in ["best_fit_init", "best_fit_init_memmap", "best_fit_alloc_pages", "best_fit_free_pages", "best_fit_nr_free_pages"]), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cc", default="gcc", help="Host C compiler")
    parser.add_argument("--build-parent", type=Path, default=ROOT / "obj", help="Writable parent for temporary build files")
    args = parser.parse_args()
    build_parent = args.build_parent.resolve()
    build_parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="lab4-a-checks-", dir=build_parent) as temp:
        directory = Path(temp).resolve()
        if directory.parent != build_parent:
            raise ValueError("Temporary build escaped its selected parent")
        generate(directory)
        executable = directory / "lab4_a_checks.exe"
        command = [args.cc, "-std=gnu99", "-O2", "-Wall", "-Wextra", "-Werror", "-Wno-unused-function", "-Wno-unused-parameter", "-I", str(directory), str(ROOT / "tools/lab4_a_host.c"), "-o", str(executable)]
        environment = dict(os.environ, TMP=str(directory), TEMP=str(directory), TMPDIR=str(directory))
        includes = ["libs", "kern/debug", "kern/driver", "kern/trap", "kern/mm", "kern/sync", "kern/fs", "kern/process", "kern/schedule"]
        syntax = [args.cc, "-std=gnu99", "-fsyntax-only", "-fno-builtin", "-nostdinc", "-Wall", "-Werror", "-Wno-unused", "-D__riscv=1", "-D__riscv_xlen=64"]
        syntax.extend("-I" + str(ROOT / name) for name in includes)
        syntax.extend(str(ROOT / name) for name in ["kern/mm/pmm.c", "kern/mm/best_fit_pmm.c", "kern/process/proc.c"])
        subprocess.run(syntax, check=True, env=environment)
        print("Source/header syntax checks passed.", flush=True)
        subprocess.run(command, check=True, env=environment)
        subprocess.run([str(executable)], check=True, timeout=10)
    print("Host C checks passed. RISC-V/QEMU execution is a separate check.")


if __name__ == "__main__":
    main()
