#!/usr/bin/env python3
"""Build, simulate, synthesize and lint programs in this repository.

Usage examples
--------------
  python3 scripts/run.py 017                      # run one program (by number)
  python3 scripts/run.py 01-basic-gates/017-and-gate
  python3 scripts/run.py 017 018 --update-docs    # also refresh README + status
  python3 scripts/run.py --all -j 4 --update-docs # full regression
  python3 scripts/run.py --category 04 -j 4        # one category

For every program directory the script:
  1. compiles every src/**/*.v file together with each top-level testbench
     tb/**/tb_*.v (other .v files under tb/ are treated as helper modules),
  2. runs the simulation with vvp from inside the program directory,
  3. decides PASS/FAIL (exit code 0, "TEST PASSED" printed, no "TEST FAILED"
     and no line starting with "ERROR"),
  4. runs Yosys generic synthesis on src/ (unless SYNTH=no in program.conf),
     rejecting unintended latches and failing `check -assert`,
  5. runs a Verilator lint pass on src/ (unless LINT=no in program.conf).

Optional per-program configuration lives in <program>/program.conf using
KEY=VALUE lines:
  TOP=<module>            synthesis/lint top (default: every module in src/)
  SYNTH=yes|no            run Yosys synthesis (default yes)
  SYNTH_NOTE=<text>       reason shown when SYNTH=no
  ALLOW_LATCH=yes|no      latches are intentional (default no)
  LINT=yes|no             run Verilator lint (default yes)
  LINT_FLAGS=<flags>      extra Verilator flags (e.g. -Wno-UNOPTFLAT)
  IVERILOG_FLAGS=<flags>  language flags (default -g2005)
  SIM_ARGS=<args>         extra vvp plusargs
"""

import argparse
import concurrent.futures
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RESULTS_FILE = ROOT / "regression" / "results.json"
STATUS_FILE = ROOT / "PROJECT_STATUS.md"
CATALOG_FILE = ROOT / "PROGRAM_CATALOG.md"
PROGRAM_RE = re.compile(r"^(\d{3})-[a-z0-9-]+$")
CATEGORY_RE = re.compile(r"^(\d{2})-[a-z0-9-]+$")

SIM_BEGIN, SIM_END = "<!-- SIM-RESULTS:BEGIN -->", "<!-- SIM-RESULTS:END -->"
ST_BEGIN, ST_END = "<!-- STATUS:BEGIN -->", "<!-- STATUS:END -->"
REG_BEGIN, REG_END = "<!-- REGRESSION:BEGIN -->", "<!-- REGRESSION:END -->"

SIM_TIMEOUT_S = 900
LOG_HEAD, LOG_TAIL, LOG_MAX = 45, 25, 80


def tool_version(cmd, pattern):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True)
    except FileNotFoundError:
        return None
    out = r.stdout + r.stderr
    m = re.search(pattern, out)
    return m.group(1) if m else "unknown"


IVERILOG_VER = tool_version(["iverilog", "-V"], r"Icarus Verilog version (\S+)")
YOSYS_VER = tool_version(["yosys", "-V"], r"Yosys (\S+)")
VERILATOR_VER = tool_version(["verilator", "--version"], r"Verilator (\S+)")


# --------------------------------------------------------------------------
# Program discovery
# --------------------------------------------------------------------------
def all_programs():
    progs = []
    for cat in sorted(ROOT.iterdir()):
        if not (cat.is_dir() and CATEGORY_RE.match(cat.name)):
            continue
        for p in sorted(cat.iterdir()):
            if p.is_dir() and PROGRAM_RE.match(p.name) and (p / "src").is_dir():
                progs.append(p)
    return progs


def resolve(arg):
    p = (ROOT / arg).resolve()
    if p.is_dir() and (p / "src").is_dir():
        return p
    for prog in all_programs():
        if prog.name.split("-")[0] == arg.zfill(3) or prog.name == arg:
            return prog
    sys.exit(f"error: cannot resolve program '{arg}'")


def load_conf(prog):
    conf = {"SYNTH": "yes", "ALLOW_LATCH": "no", "LINT": "yes",
            "IVERILOG_FLAGS": "-g2005", "SIM_ARGS": "", "TOP": "",
            "SYNTH_NOTE": "", "LINT_FLAGS": ""}
    f = prog / "program.conf"
    if f.exists():
        for line in f.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            conf[k.strip()] = v.strip().strip('"')
    return conf


def rel(prog, files):
    return [str(f.relative_to(prog)) for f in files]


# --------------------------------------------------------------------------
# Steps
# --------------------------------------------------------------------------
def run_cmd(cmd, cwd, timeout=None):
    try:
        r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True,
                           timeout=timeout)
        return r.returncode, r.stdout + r.stderr
    except subprocess.TimeoutExpired as e:
        out = (e.stdout or b"")
        if isinstance(out, bytes):
            out = out.decode(errors="replace")
        return -1, out + "\nTEST FAILED: simulator wall-clock timeout\n"


def include_dirs(prog):
    dirs = {"src", "tb"}
    for f in list(prog.glob("src/**/*.vh")) + list(prog.glob("tb/**/*.vh")):
        dirs.add(str(f.parent.relative_to(prog)))
    return [f"-I{d}" for d in sorted(dirs) if (prog / d).is_dir()]


def simulate(prog, conf, build):
    src = sorted(prog.glob("src/**/*.v"))
    tb_all = sorted(prog.glob("tb/**/*.v"))
    tops = [f for f in tb_all if f.name.startswith("tb_")]
    helpers = [f for f in tb_all if not f.name.startswith("tb_")]
    results = []
    if not tops:
        return [{"tb": None, "status": "FAIL", "log": "no tb/tb_*.v found",
                 "warnings": 0}]
    for tb in tops:
        name = tb.stem
        vvp = build / f"{name}.vvp"
        cmd = (["iverilog"] + conf["IVERILOG_FLAGS"].split() + ["-Wall"]
               + include_dirs(prog) + ["-s", name, "-o", str(vvp)]
               + rel(prog, src) + rel(prog, helpers) + [str(tb.relative_to(prog))])
        rc, out = run_cmd(cmd, prog)
        warnings = len(re.findall(r"warning", out, re.I))
        if rc != 0:
            results.append({"tb": name, "status": "COMPILE-FAIL",
                            "log": out, "warnings": warnings})
            continue
        sim_cmd = ["vvp", "-n", str(vvp)] + conf["SIM_ARGS"].split()
        rc, log = run_cmd(sim_cmd, prog, timeout=SIM_TIMEOUT_S)
        (build / f"{name}.log").write_text(log)
        ok = (rc == 0 and "TEST PASSED" in log and "TEST FAILED" not in log
              and not re.search(r"^\s*ERROR", log, re.M))
        results.append({"tb": name, "status": "PASS" if ok else "FAIL",
                        "log": log, "compile_log": out, "warnings": warnings})
    return results


def find_top(prog):
    """Return the single root module of src/ (not instantiated elsewhere),
    or None when there are zero or several roots."""
    text = ""
    for f in sorted(prog.glob("src/**/*.v")):
        code = re.sub(r"/\*.*?\*/", "", f.read_text(), flags=re.S)
        text += re.sub(r"//.*", "", code) + "\n"
    modules = re.findall(r"^\s*module\s+(\w+)", text, re.M)
    roots = [m for m in modules
             if not re.search(r"^\s*" + m + r"\s*(#\s*\(|\w+\s*\()", text, re.M)]
    return roots[0] if len(roots) == 1 else None


def synthesize(prog, conf, build):
    if conf["SYNTH"].lower() != "yes":
        return {"status": "N/A", "note": conf["SYNTH_NOTE"] or "not synthesizable by intent"}
    src = rel(prog, sorted(prog.glob("src/**/*.v")))
    top_name = conf["TOP"] or find_top(prog)
    top = f"-top {top_name}" if top_name else ""
    incs = " ".join(include_dirs(prog))
    script = (f"read_verilog -D SYNTHESIS {incs} {' '.join(src)}; "
              f"synth {top}; check -assert; stat {top}")
    logf = build / "synth.log"
    rc, out = run_cmd(["yosys", "-q", "-l", str(logf), "-p", script], prog,
                      timeout=SIM_TIMEOUT_S)
    log = logf.read_text() if logf.exists() else out
    latches = re.findall(r"Latch inferred for signal `([^']+)'", log)
    stat = log[log.rfind("Printing statistics"):] if "Printing statistics" in log else log
    cells = [int(c) for c in re.findall(r"Number of cells:\s+(\d+)", stat)]
    if top_name:        # hierarchy total is printed last
        ncells = cells[-1] if cells else None
    else:               # several independent top modules: sum them
        ncells = sum(cells) if cells else None
    res = {"status": "PASS", "cells": ncells, "top": top_name}
    if rc != 0:
        err = [l for l in (out + log).splitlines() if "ERROR" in l]
        res.update(status="FAIL", note=(err[-1] if err else out[-400:]))
    elif latches and conf["ALLOW_LATCH"].lower() != "yes":
        res.update(status="FAIL", note="unintended latch: " + ", ".join(latches))
    elif latches:
        res["note"] = f"{len(latches)} intentional latch(es)"
    return res


def lint(prog, conf, build):
    if conf["LINT"].lower() != "yes" or not VERILATOR_VER:
        return {"status": "N/A"}
    src = rel(prog, sorted(prog.glob("src/**/*.v")))
    cmd = (["verilator", "--lint-only", "-Wno-fatal", "-Wno-MULTITOP",
            "-Wno-DECLFILENAME"] + conf["LINT_FLAGS"].split()
           + include_dirs(prog) + src)
    if conf["TOP"]:
        cmd += ["--top-module", conf["TOP"]]
    rc, out = run_cmd(cmd, prog, timeout=SIM_TIMEOUT_S)
    (build / "lint.log").write_text(out)
    warns = re.findall(r"^%Warning-(\S+?):", out, re.M)
    errs = re.findall(r"^%Error", out, re.M)
    if errs:
        return {"status": "FAIL", "note": out.strip().splitlines()[0]}
    if warns:
        return {"status": "WARN", "note": ", ".join(sorted(set(warns)))}
    return {"status": "CLEAN"}


def run_program(prog, do_synth=True, do_lint=True):
    conf = load_conf(prog)
    build = prog / "build"
    shutil.rmtree(build, ignore_errors=True)
    build.mkdir()
    sims = simulate(prog, conf, build)
    syn = synthesize(prog, conf, build) if do_synth else {"status": "SKIPPED"}
    lnt = lint(prog, conf, build) if do_lint else {"status": "SKIPPED"}
    sim_ok = all(s["status"] == "PASS" for s in sims)
    return {"prog": prog, "conf": conf, "sims": sims, "synth": syn,
            "lint": lnt, "sim_ok": sim_ok}


# --------------------------------------------------------------------------
# Reporting
# --------------------------------------------------------------------------
def trim_log(log):
    lines = [l.rstrip() for l in log.strip().splitlines()]
    lines = [l for l in lines if not l.startswith("VCD info:")]
    if len(lines) > LOG_MAX:
        omitted = len(lines) - LOG_HEAD - LOG_TAIL
        lines = (lines[:LOG_HEAD] + [f"... ({omitted} lines omitted) ..."]
                 + lines[-LOG_TAIL:])
    return "\n".join(lines)


def prog_id(prog):
    return f"{prog.parent.name}/{prog.name}"


def status_line(res):
    sim = "SIMULATION VERIFIED" if res["sim_ok"] else "SIMULATION FAILING"
    s = res["synth"]["status"]
    syn = {"PASS": "SYNTHESIS VERIFIED (Yosys generic synthesis)",
           "FAIL": "SYNTHESIS FAILING",
           "N/A": "Synthesis: not applicable",
           "SKIPPED": "Synthesis: not run"}[s]
    return f"**Status:** {sim} · {syn} · FPGA hardware: not tested"


def sim_block(res):
    prog = res["prog"]
    out = [f"Command: `python3 scripts/run.py {prog.name[:3]}` "
           f"(Icarus Verilog {IVERILOG_VER}, "
           f"`iverilog {res['conf']['IVERILOG_FLAGS']} -Wall`)", ""]
    for s in res["sims"]:
        out.append(f"Testbench `{s['tb']}` — **{s['status']}**")
        out.append("")
        out.append("```text")
        out.append(trim_log(s["log"]))
        out.append("```")
        out.append("")
    syn = res["synth"]
    if syn["status"] == "PASS":
        n = syn.get("cells")
        cells = f", {n} cell{'s' if n != 1 else ''}" if n is not None else ""
        note = f" ({syn['note']})" if syn.get("note") else ""
        out.append(f"Synthesis (Yosys {YOSYS_VER}, generic `synth`): "
                   f"**PASS**{cells}{note}")
    elif syn["status"] == "N/A":
        out.append(f"Synthesis: not applicable — {syn.get('note', '')}")
    else:
        out.append(f"Synthesis: **{syn['status']}** {syn.get('note', '')}")
    ln = res["lint"]
    if ln["status"] == "CLEAN":
        out.append(f"Lint (Verilator {VERILATOR_VER} `--lint-only`): **clean**")
    elif ln["status"] == "WARN":
        out.append(f"Lint (Verilator {VERILATOR_VER} `--lint-only`): "
                   f"warnings — {ln['note']}")
    elif ln["status"] == "N/A":
        pass
    else:
        out.append(f"Lint: **{ln['status']}** {ln.get('note', '')}")
    return "\n".join(out)


def replace_block(text, begin, end, body):
    pat = re.compile(re.escape(begin) + r".*?" + re.escape(end), re.S)
    if not pat.search(text):
        return text, False
    return pat.sub(lambda _: f"{begin}\n{body}\n{end}", text), True


def update_readme(res):
    readme = res["prog"] / "README.md"
    if not readme.exists():
        print(f"  ! {prog_id(res['prog'])}: README.md missing")
        return
    text = readme.read_text()
    text, ok1 = replace_block(text, SIM_BEGIN, SIM_END, sim_block(res))
    text, ok2 = replace_block(text, ST_BEGIN, ST_END, status_line(res))
    if not (ok1 and ok2):
        print(f"  ! {prog_id(res['prog'])}: README missing result markers")
    readme.write_text(text)


def load_results():
    if RESULTS_FILE.exists():
        return json.loads(RESULTS_FILE.read_text())
    return {}


def save_results(results):
    RESULTS_FILE.parent.mkdir(exist_ok=True)
    RESULTS_FILE.write_text(json.dumps(results, indent=1, sort_keys=True) + "\n")


def parse_catalog():
    """Return list of (number, name, category) from PROGRAM_CATALOG.md."""
    rows, cat = [], None
    if not CATALOG_FILE.exists():
        return rows
    for line in CATALOG_FILE.read_text().splitlines():
        m = re.match(r"^##\s+(\d{2}-[a-z0-9-]+)", line)
        if m:
            cat = m.group(1)
            continue
        m = re.match(r"^\|\s*(\d{3})\s*\|\s*`?([a-z0-9-]+)`?\s*\|", line)
        if m and cat:
            rows.append((m.group(1), m.group(2), cat))
    return rows


def update_status(results):
    if not STATUS_FILE.exists():
        return
    catalog = parse_catalog()
    by_num = {k.split("/")[1][:3]: (k, v) for k, v in results.items()}
    lines = []
    cats = {}
    for num, name, cat in catalog:
        cats.setdefault(cat, [0, 0, 0])
        cats[cat][0] += 1
        if num in by_num:
            cats[cat][1] += 1
            if by_num[num][1]["sim"] == "PASS":
                cats[cat][2] += 1
    total = [sum(v[i] for v in cats.values()) for i in range(3)]
    lines.append(f"Planned: **{total[0]}** · Implemented: **{total[1]}** · "
                 f"Simulation verified: **{total[2]}** · "
                 f"Not yet implemented: **{total[0] - total[1]}**")
    lines.append("")
    lines.append("| Category | Planned | Implemented | Simulation verified |")
    lines.append("|---|---:|---:|---:|")
    for cat, (p, i, v) in cats.items():
        lines.append(f"| {cat} | {p} | {i} | {v} |")
    lines.append("")
    lines.append("### Implemented programs")
    lines.append("")
    lines.append("| No. | Program | Testbenches | Simulation | Synthesis (Yosys) | Lint (Verilator) |")
    lines.append("|---|---|---|---|---|---|")
    for key in sorted(results, key=lambda k: k.split("/")[1]):
        r = results[key]
        num = key.split("/")[1][:3]
        cells = f" ({r['cells']} cells)" if r.get("cells") is not None else ""
        lines.append(f"| {num} | [{key.split('/')[1][4:]}]({key}/) | "
                     f"{r['testbenches']} | {r['sim']} | {r['synth']}{cells} | "
                     f"{r['lint']} |")
    lines.append("")
    pending = [(n, nm, c) for n, nm, c in catalog if n not in by_num]
    lines.append(f"### Not yet implemented ({len(pending)})")
    lines.append("")
    if pending:
        lines.append(", ".join(f"{n} {nm}" for n, nm, _ in pending))
    body = "\n".join(lines)
    text = STATUS_FILE.read_text()
    text, ok = replace_block(text, REG_BEGIN, REG_END, body)
    if ok:
        STATUS_FILE.write_text(text)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("programs", nargs="*")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--category", help="two-digit category prefix, e.g. 04")
    ap.add_argument("--update-docs", action="store_true",
                    help="write results into README.md files and PROJECT_STATUS.md")
    ap.add_argument("--no-synth", action="store_true")
    ap.add_argument("--no-lint", action="store_true")
    ap.add_argument("-j", "--jobs", type=int, default=1)
    ap.add_argument("-v", "--verbose", action="store_true",
                    help="print full simulation logs")
    args = ap.parse_args()

    if not IVERILOG_VER:
        sys.exit("error: iverilog not found (apt-get install iverilog)")

    if args.all:
        progs = all_programs()
    elif args.category:
        progs = [p for p in all_programs() if p.parent.name.startswith(args.category)]
    else:
        progs = [resolve(a) for a in args.programs]
    if not progs:
        sys.exit("nothing to run")

    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as ex:
        runs = list(ex.map(lambda p: run_program(p, not args.no_synth,
                                                 not args.no_lint), progs))

    results = load_results()
    failed = 0
    for res in runs:
        pid = prog_id(res["prog"])
        sims = ", ".join(f"{s['tb']}={s['status']}" for s in res["sims"])
        syn = res["synth"]
        print(f"{'PASS' if res['sim_ok'] else 'FAIL'}  {pid}\n"
              f"      sim: {sims}\n"
              f"      synth: {syn['status']} {syn.get('note', '')}"
              f"{' cells=' + str(syn['cells']) if syn.get('cells') is not None else ''}\n"
              f"      lint: {res['lint']['status']} {res['lint'].get('note', '')}")
        for s in res["sims"]:
            if args.verbose or s["status"] != "PASS":
                print(f"----- {s['tb']} ({s['status']}) -----")
                if s.get("compile_log"):
                    print(s["compile_log"].rstrip())
                print(s["log"].rstrip())
            elif s.get("compile_log", "").strip():
                print(f"      compile messages ({s['tb']}):\n" +
                      "\n".join("        " + l for l in s["compile_log"].strip().splitlines()))
        if not res["sim_ok"] or syn["status"] == "FAIL":
            failed += 1
        if args.update_docs:
            update_readme(res)
            results[pid] = {
                "testbenches": len(res["sims"]),
                "sim": "PASS" if res["sim_ok"] else "FAIL",
                "synth": syn["status"],
                "cells": syn.get("cells"),
                "lint": res["lint"]["status"],
            }
    if args.update_docs:
        save_results(results)
        update_status(results)
    print(f"\n{len(runs) - failed}/{len(runs)} programs passed "
          f"(simulation + synthesis where applicable)")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
