#!/usr/bin/env python3
"""The shape of the code: where it is long, where it repeats itself, and the constructs worth a look.

    tools/code_shape.py [-v]

Run it from the repository's root.  It reads the Ada sources of src/, game/ and tools/ and
changes nothing.  It prints:

  sizes        lines by directory, the largest files
  subprograms  the longest (from "procedure/function NAME ... is" to "end NAME;"), with how deep
               their statements nest
  repeats      runs of twelve or more lines that stand, the same but for spacing, in more than
               one place (comments and blank lines left out)
  constructs   counts, by file, of what a reader should know is there: "when others" in a case,
               handlers that catch everything, checks suppressed, unchecked conversions,
               addresses taken, tasks and protected objects, Put_Line in the engine, and
               comments that say something is owed

-v lists every repeat and every place of every construct; without it, the largest of each.
What it prints is where to read, not what is wrong.
"""
import glob
import hashlib
import os
import re
import sys
from collections import defaultdict

verbose = "-v" in sys.argv
files = sorted(glob.glob("src/*.ad[sb]") + glob.glob("game/*.ad[sb]") + glob.glob("tools/*.ad[sb]"))


def strip_comment(line):
    in_string = False
    for i, ch in enumerate(line):
        if ch == '"':
            in_string = not in_string
        elif ch == "-" and not in_string and line[i:i + 2] == "--":
            return line[:i]
    return line


text = {f: open(f, errors="replace").read().split("\n") for f in files}
code = {f: [strip_comment(ln).rstrip() for ln in lines] for f, lines in text.items()}

# ---------------------------------------------------------------- sizes
print("Sizes")
by_dir = defaultdict(lambda: [0, 0, 0])
for f in files:
    d = f.split("/")[0]
    by_dir[d][0] += 1
    by_dir[d][1] += len(text[f])
    by_dir[d][2] += sum(1 for ln in code[f] if ln.strip())
for d, (n, total, live) in sorted(by_dir.items()):
    print(f"  {d:6s} {n:4d} files {total:7d} lines, {live:7d} of them code")
big = sorted(files, key=lambda f: -len(text[f]))[:12]
print("  the largest: " + "; ".join(f"{os.path.basename(f)} {len(text[f])}" for f in big))

# ---------------------------------------------------------------- subprograms
START = re.compile(r"^(\s*)(?:overriding\s+|not overriding\s+)?(procedure|function)\s+(\"[^\"]+\"|[\w.]+)", re.I)
subs = []
for f in files:
    lines = code[f]
    stack = []
    i = 0
    n = len(lines)
    while i < n:
        m = START.match(lines[i])
        if m:
            # find whether this declaration has a body: scan to the first of ";" or " is" at paren depth 0
            depth = 0
            j = i
            kind = None
            while j < n and kind is None:
                for tok in re.finditer(r"\(|\)|;|\bis\b", lines[j]):
                    t = tok.group(0)
                    if t == "(":
                        depth += 1
                    elif t == ")":
                        depth -= 1
                    elif depth == 0 and t == ";":
                        kind = "decl"
                        break
                    elif depth == 0 and t == "is":
                        rest = lines[j][tok.end():].strip()
                        nxt = rest if rest else (lines[j + 1].strip() if j + 1 < n else "")
                        kind = "decl" if re.match(r"(separate|abstract|null|new\b|\(|<>)", nxt) else "body"
                        break
                j += 1
            if kind == "body":
                stack.append((m.group(3).strip('"'), i, len(m.group(1))))
        e = re.match(r"^(\s*)end\s+(\"[^\"]+\"|[\w.]+)\s*;", lines[i])
        if e and stack:
            name = e.group(2).strip('"')
            for k in range(len(stack) - 1, -1, -1):
                if stack[k][0].lower() == name.lower() and stack[k][2] == len(e.group(1)):
                    nm, start, indent = stack[k]
                    del stack[k:]
                    body = lines[start:i + 1]
                    deepest = max((len(ln) - len(ln.lstrip()) for ln in body if ln.strip()), default=indent)
                    subs.append((i - start + 1, f, nm, start + 1, (deepest - indent) // 3))
                    break
        i += 1
subs.sort(reverse=True)
print(f"\nSubprograms with a body: {len(subs)}; over 200 lines: {sum(1 for s in subs if s[0] > 200)}; "
      f"over 500: {sum(1 for s in subs if s[0] > 500)}; over 1,000: {sum(1 for s in subs if s[0] > 1000)}")
print("  the longest (lines, deepest nesting in steps of three columns):")
for length, f, nm, start, deep in subs[:(60 if verbose else 25)]:
    print(f"    {length:6d}  {deep:3d}  {f}:{start}  {nm}")

# ---------------------------------------------------------------- repeats
N = 12
index = defaultdict(list)
norm = {}
for f in files:
    ls = [(k, re.sub(r"\s+", " ", ln.strip())) for k, ln in enumerate(code[f]) if ln.strip()]
    norm[f] = ls
    for a in range(len(ls) - N + 1):
        window = "\n".join(x[1] for x in ls[a:a + N])
        if sum(len(x[1]) for x in ls[a:a + N]) < 300:        # twelve short lines (begin, end, null;) are no finding
            continue
        index[hashlib.md5(window.encode()).hexdigest()].append((f, a))
# merge windows into maximal runs: follow matching pairs forward
seen = set()
runs = []
for h, places in index.items():
    if len(places) < 2:
        continue
    places = sorted(places)
    for x in range(len(places)):
        for y in range(x + 1, len(places)):
            (f1, a1), (f2, a2) = places[x], places[y]
            if (f1, a1, f2, a2) in seen or (f1 == f2 and abs(a1 - a2) < N):
                continue
            # is this the start of a run (the windows before do not match)?
            if a1 > 0 and a2 > 0 and norm[f1][a1 - 1][1] == norm[f2][a2 - 1][1]:
                continue
            length = 0
            while (a1 + length < len(norm[f1]) and a2 + length < len(norm[f2])
                   and norm[f1][a1 + length][1] == norm[f2][a2 + length][1]):
                length += 1
            for k in range(length - N + 1):
                seen.add((f1, a1 + k, f2, a2 + k))
            runs.append((length, f1, norm[f1][a1][0] + 1, f2, norm[f2][a2][0] + 1))
runs.sort(reverse=True)
print(f"\nRepeats of {N} lines or more: {len(runs)} pairs, {sum(r[0] for r in runs)} lines in all")
pair_files = defaultdict(int)
for length, f1, l1, f2, l2 in runs:
    pair_files[(f1, f2)] += length
print("  by the two files (lines): " + "; ".join(
    f"{os.path.basename(a)} / {os.path.basename(b)} {n}" for (a, b), n in sorted(pair_files.items(), key=lambda kv: -kv[1])[:12]))
for length, f1, l1, f2, l2 in runs[:(len(runs) if verbose else 20)]:
    print(f"    {length:4d} lines  {f1}:{l1}  and  {f2}:{l2}")

# ---------------------------------------------------------------- constructs
CONSTRUCTS = [
    ("'when others' in a case or a handler", re.compile(r"\bwhen\s+others\s*=>", re.I)),
    ("a handler that catches everything and goes on ('when others => null')", re.compile(r"\bwhen\s+others\s*=>\s*null\s*;", re.I)),
    ("checks suppressed in the source (pragma Suppress)", re.compile(r"\bpragma\s+Suppress\b", re.I)),
    ("warnings turned off (pragma Warnings (Off)", re.compile(r"\bpragma\s+Warnings\s*\(\s*Off", re.I)),
    ("unchecked conversion or deallocation", re.compile(r"\bUnchecked_(Conversion|Deallocation)\b", re.I)),
    ("an address taken or laid over ('Address, for X'Address use)", re.compile(r"'Address\b", re.I)),
    ("'Unrestricted_Access or 'Unchecked_Access", re.compile(r"'Un(restricted|checked)_Access\b", re.I)),
    ("a task or a protected object declared", re.compile(r"^\s*(task|protected)\s+(type\s+|body\s+)?\w+", re.I)),
    ("a volatile or atomic object", re.compile(r"\b(Volatile|Atomic)\b", re.I)),
    ("goto", re.compile(r"\bgoto\s+\w+\s*;", re.I)),
]
print("\nConstructs (in src/ and game/; the tools' own are left out)")
for title, pat in CONSTRUCTS:
    hits = defaultdict(list)
    for f in files:
        if f.startswith("tools/"):
            continue
        for k, ln in enumerate(code[f], 1):
            if pat.search(ln):
                hits[f].append(k)
    total = sum(len(v) for v in hits.values())
    top = sorted(hits.items(), key=lambda kv: -len(kv[1]))
    print(f"  {title}: {total}" + (" (" + ", ".join(f"{os.path.basename(f)} {len(v)}" for f, v in top[:8])
                                   + (", ..." if len(top) > 8 else "") + ")" if total else ""))
    if verbose:
        for f, v in top:
            print(f"      {f}: " + " ".join(str(x) for x in v))
put = defaultdict(int)
for f in files:
    if f.startswith("src/"):
        for ln in code[f]:
            if re.search(r"\bPut_Line\b|\bText_IO\.Put\b", ln):
                put[f] += 1
print(f"  Put_Line in the engine (src/): {sum(put.values())} (" + ", ".join(
    f"{os.path.basename(f)} {n}" for f, n in sorted(put.items(), key=lambda kv: -kv[1])[:10]) + ")")
owed = defaultdict(list)
OWED = re.compile(r"--.*\b(TODO|FIXME|XXX|HACK|owed|not mended|not looked into|for now|temporary|stop-gap|until then)\b", re.I)
for f in files:
    for k, ln in enumerate(text[f], 1):
        if OWED.search(ln):
            owed[f].append(k)
print(f"  comments that say something is owed or for now: {sum(len(v) for v in owed.values())} (" + ", ".join(
    f"{os.path.basename(f)} {len(v)}" for f, v in sorted(owed.items(), key=lambda kv: -len(kv[1]))[:10]) + ")")
if verbose:
    for f, v in sorted(owed.items()):
        for k in v:
            print(f"      {f}:{k}: {text[f][k - 1].strip()[:150]}")
