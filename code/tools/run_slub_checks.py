#!/usr/bin/env python3
"""Build and boot the real RV64 kernel in QEMU; run from Linux/WSL.

Builds happen in a temporary COPY. The all-manager matrix changes only that
copy's pmm_manager selection. Original A/B code and tracked bin/obj stay intact.
--baseline boots the exact committed HEAD:code tree without working-tree edits.
"""

import argparse
import datetime
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import selectors
import shutil
import subprocess
import tarfile
import tempfile
import time


CODE = Path(__file__).resolve().parents[1]
MANAGERS = {
    "buddy": "buddy_fit_pmm_manager",
    "best": "best_fit_pmm_manager",
    "first": "default_pmm_manager",
}


def git_output(*arguments):
    # Explicit work tree also supports a Windows-created checkout used in WSL.
    return subprocess.check_output(
        ["git", "-C", str(CODE.parent), "--work-tree=" + str(CODE.parent), *arguments]
    )


def version(command):
    result = subprocess.run(command, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, timeout=10)
    if result.returncode:
        raise RuntimeError(f"Cannot run {command[0]}: {result.stdout}")
    return result.stdout.splitlines()[0]


def copy_code(destination, baseline):
    if not baseline:
        shutil.copytree(CODE, destination,
                        ignore=shutil.ignore_patterns("bin", "obj", "__pycache__"))
        return
    archive = git_output("archive", "--format=tar", "HEAD:code")
    destination.mkdir()
    with tarfile.open(fileobj=io.BytesIO(archive)) as source:
        for entry in source.getmembers():
            relative = PurePosixPath(entry.name)
            if relative.is_absolute() or ".." in relative.parts:
                raise RuntimeError("Unsafe archive path")
            if not entry.isfile() or relative.parts[0] in {"obj", "bin"}:
                continue
            target = destination / str(relative)
            target.parent.mkdir(parents=True, exist_ok=True)
            with source.extractfile(entry) as data, target.open("wb") as output:
                shutil.copyfileobj(data, output)


def boot(command, marker, timeout, log):
    start = time.monotonic()
    output = bytearray()
    reason = "timeout"
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    try:
        with selectors.DefaultSelector() as selector:
            selector.register(process.stdout, selectors.EVENT_READ)
            while time.monotonic() - start < timeout:
                events = selector.select(min(0.2, max(0, timeout - (time.monotonic() - start))))
                for key, _ in events:
                    chunk = os.read(key.fileobj.fileno(), 65536)
                    if not chunk:
                        reason = "process_exited_before_success"
                        break
                    output.extend(chunk)
                else:
                    decoded = output.decode("utf-8", errors="replace")
                    if "kernel panic" in decoded or "assertion failed" in decoded:
                        reason = "kernel_panic"
                        break
                    if marker in decoded and "\n" in decoded[decoded.index(marker):]:
                        reason = "success_marker"
                        break
                    if process.poll() is not None:
                        reason = "process_exited_before_success"
                        break
                    continue
                break
    finally:
        # uCore intentionally ends in while(1). Stop QEMU AFTER observing the
        # success marker; a timeout is never accepted as a passing test.
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
        remaining = process.communicate(timeout=3)[0]
        if remaining:
            output.extend(remaining)
        log.write_bytes(output)
    text = output.decode("utf-8", errors="replace")
    positive = reason == "success_marker"
    if "kernel panic" in text or "assertion failed" in text:
        positive = False
    return {
        "passed": positive,
        "stop_reason": reason,
        "qemu_exit_code_after_stop": process.returncode,
        "duration_seconds": round(time.monotonic() - start, 3),
        "success_marker": marker,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manager", choices=[*MANAGERS, "all"], default="buddy")
    parser.add_argument("--memory", default="128M")
    parser.add_argument("--qemu", default="qemu-system-riscv64")
    parser.add_argument("--gcc-prefix", default="riscv64-unknown-elf-")
    parser.add_argument("--timeout", type=float, default=40)
    parser.add_argument("--baseline", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if os.name != "posix":
        parser.error("Run this script inside Linux/WSL, where the RV64 toolchain is installed.")
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    if not re.fullmatch(r"[1-9][0-9]*[MG]", args.memory):
        parser.error("--memory must be a QEMU size such as 64M or 128M")
    stamp = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).strftime("%Y%m%dT%H%M%S")
    output = (args.output or CODE.parent / "report" / "slub_evidence" / stamp).resolve()
    output.mkdir(parents=True, exist_ok=False)
    compiler = shutil.which(args.gcc_prefix + "gcc")
    qemu = shutil.which(args.qemu)
    if compiler is None or qemu is None:
        parser.error("Cannot find compiler or QEMU; set --gcc-prefix /absolute/prefix- and --qemu /absolute/qemu.")
    selected = list(MANAGERS) if args.manager == "all" else [args.manager]
    summary = {
        "recorded_at_asia_singapore": stamp,
        "base_commit": git_output("rev-parse", "HEAD").decode().strip(),
        "baseline_from_committed_tree": args.baseline,
        "compiler": version([compiler, "--version"]),
        "qemu": version([qemu, "--version"]),
        "qemu_path": qemu,
        "memory": args.memory,
        "source_hashes": {},
        "cases": [],
    }
    if not args.baseline:
        for subdir in ("kern", "libs", "tools"):
            for path in sorted((CODE / subdir).rglob("*")):
                if path.is_file() and path.suffix in {".c", ".h", ".S", ".ld", ".mk", ".py"}:
                    summary["source_hashes"][str(path.relative_to(CODE))] = hashlib.sha256(path.read_bytes()).hexdigest()
        summary["source_hashes"]["Makefile"] = hashlib.sha256((CODE / "Makefile").read_bytes()).hexdigest()
    for manager in selected:
        label = f'{"baseline" if args.baseline else "slub"}-{manager}-{args.memory}'
        case = {"name": label, "manager": MANAGERS[manager], "passed": False}
        summary["cases"].append(case)
        with tempfile.TemporaryDirectory(prefix="ucore-slub-") as scratch:
            project = Path(scratch) / "code"
            copy_code(project, args.baseline)
            pmm = project / "kern" / "mm" / "pmm.c"
            text = pmm.read_text()
            text, count = re.subn(r"pmm_manager\s*=\s*&\w+_pmm_manager\s*;",
                                  "pmm_manager = &" + MANAGERS[manager] + ";", text)
            if count != 1:
                raise RuntimeError(f"Expected one manager selection, found {count}")
            pmm.write_text(text)
            command = ["make", "-j2", "GCCPREFIX=" + args.gcc_prefix]
            case["build_command"] = command
            try:
                with (output / (label + ".build.log")).open("wb") as log:
                    build = subprocess.run(command, cwd=project, stdout=log,
                                           stderr=subprocess.STDOUT, timeout=120)
                case["build_exit_code"] = build.returncode
                if build.returncode:
                    case["stop_reason"] = "build_failed"
                else:
                    image = project / "bin" / "ucore.img"
                    case["image_sha256"] = hashlib.sha256(image.read_bytes()).hexdigest()
                    marker = "check_alloc_page() succeeded!" if args.baseline else "slub_check succeeded! 8/8 groups;"
                    command = [qemu, "-machine", "virt", "-m", args.memory, "-smp", "1",
                               "-nographic", "-bios", "default", "-device",
                               "loader,file=" + str(image) + ",addr=0x80200000"]
                    case["boot_command"] = command
                    case.update(boot(command, marker, args.timeout,
                                     output / (label + ".qemu.log")))
                    if case["passed"] and not args.baseline:
                        boot_text = (output / (label + ".qemu.log")).read_text()
                        groups = re.findall(r"^\[SLUB ([1-8])/8\].*: PASS$", boot_text, re.MULTILINE)
                        balance = re.search(r"slub_check succeeded! 8/8 groups; free_pages=(\d+) -> (\d+)", boot_text)
                        case["groups_passed"] = len(groups)
                        case["passed"] = sorted(groups) == list("12345678") and balance is not None
                        if balance is not None:
                            case["free_pages_before"] = int(balance[1])
                            case["free_pages_after"] = int(balance[2])
                            case["passed"] = case["passed"] and balance[1] == balance[2]
            except (subprocess.TimeoutExpired, OSError) as error:
                case["stop_reason"] = str(error)
        (output / "results.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
        print(f'{"PASS" if case["passed"] else "FAIL"}: {label} ({case.get("stop_reason")})', flush=True)
        if not case["passed"]:
            print("Evidence: " + str(output), flush=True)
            return 1
    print("Evidence: " + str(output), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
