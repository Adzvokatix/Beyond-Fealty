#!/usr/bin/env python3
"""Read gcov's files after tools/gate_coverage.sh and say what the gate never ran.

    tools/coverage_report.py OBJDIR          (the directory gcov wrote its *.gcov files in)

For each source file of src/ and game/: the lines that can run, how many were never run, and
the subprograms that were never entered.  The tools' own sources are left out (a check is not
there to be checked).
"""
import glob
import os
import re
import sys
from collections import defaultdict

objdir = sys.argv[1]
per_file = {}
never_called = defaultdict(list)
called = defaultdict(int)
for g in sorted(glob.glob(os.path.join(objdir, "*.gcov"))):
    src = None
    lines = open(g, errors="replace").read().split("\n")
    can = missed = 0
    pending = []
    funcs = []                 # (first line, name, times called)
    ran = {}                   # line -> it ran (only lines that can run)
    for ln in lines:
        m = re.match(r"\s*([^:]+):\s*(\d+):(.*)$", ln)
        if m:
            count, no, text = m.group(1).strip(), int(m.group(2)), m.group(3)
            if no == 0:
                if text.startswith("Source:"):
                    src = text[len("Source:"):].strip()
                continue
            for name, n in pending:
                funcs.append((no, name, n))
            pending = []
            # gcov writes a line once for each copy the compiler made of the subprogram it is in
            # (a nested one set inline at several calls): the line ran if any copy of it ran
            if count in ("#####", "====="):
                ran.setdefault(no, False)
            elif count != "-":
                ran[no] = True
            continue
        f = re.match(r"function (\S+) called (\d+)", ln)
        if f:
            pending.append((f.group(1), int(f.group(2))))
    # A subprogram is "never run" only if none of its own lines ran: one the compiler put inline
    # where it is called shows as called 0 times while its lines are counted.
    funcs.sort()
    for k, (first, name, n) in enumerate(funcs):
        last = funcs[k + 1][0] - 1 if k + 1 < len(funcs) and funcs[k + 1][0] > first else first
        own = [ran[x] for x in range(first, last + 1) if x in ran]
        if n == 0 and own and not any(own):
            never_called[src].append((first, name))
        else:
            called[src] += 1
    if src:
        key = os.path.normpath(src)
        can = len(ran)
        missed = sum(1 for v in ran.values() if not v)
        a, b = per_file.get(key, (0, 0))
        per_file[key] = (a + can, b + missed)


def ours(path):
    base = os.path.basename(path)
    return any(os.path.exists(os.path.join(d, base)) for d in ("src", "game"))


rows = sorted(((os.path.basename(p), can, missed) for p, (can, missed) in per_file.items() if ours(p) and can),
              key=lambda r: -r[2])
total_can = sum(r[1] for r in rows)
total_missed = sum(r[2] for r in rows)
print(f"Lines of src/ and game/ that can run: {total_can}; never run by the gate's parts: {total_missed} "
      f"({100.0 * total_missed / max(1, total_can):.1f} %)")
print("\nBy file, the most never run first (file: lines that can run, never run, share never run):")
for name, can, missed in rows:
    if missed:
        print(f"  {name:40s} {can:6d} {missed:6d}  {100.0 * missed / can:5.1f} %")
full = [r[0] for r in rows if r[2] == 0]
print(f"\nEvery line run: {len(full)} files" + (": " + ", ".join(full) if full else ""))


def plain(name):
    """castle__colony__place_cart.1234 -> Castle.Colony.Place_Cart"""
    name = re.sub(r"\.\d+$", "", name)
    name = re.sub(r"__(\d+)$", "", name)
    return ".".join(p.capitalize() if not p[:1].isupper() else p for p in name.split("__"))


n_never = sum(len(v) for p, v in never_called.items() if ours(p))
n_called = sum(v for p, v in called.items() if ours(p))
print(f"\nSubprograms of which no line ran: {n_never} of {n_never + n_called}")
for p in sorted(never_called, key=lambda p: -len(never_called[p])):
    if not ours(p):
        continue
    names = sorted(set(plain(n).split(".")[-1] + f" ({no})" for no, n in never_called[p]))
    print(f"  {os.path.basename(p)}: {len(names)}: " + ", ".join(names))
