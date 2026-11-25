#!/usr/bin/env python3
"""What a specification declares and nothing uses, from the compiler's own cross-references.

    tools/unused_entities.py [OBJDIR]        (obj/debug unless given: a tree that has been built)

GNAT writes, in every .ali file, each entity a unit sees and every place that unit refers to it.
This script puts all of them together and lists the entities declared in a specification under
src/ that no unit anywhere refers to, but for their own declaration, body and end.  It reads the
.ali files of a finished build and changes nothing.

Three lists:
  never referred to at all          nothing calls it, reads it or names it
  referred to only where declared   used only inside its own package (specification, body or
                                    subunits): it need not be in the specification
  enumeration literals never named  (often on purpose: a value kept for a saved position)

It cannot see a use that is not in a compiled main of castle.gpr, and it does not know which of
these John has said to keep (the old far land: Castle.Far, by his word of 2026-11-16).  A name on
the list is a question, not a verdict.
"""
import glob
import os
import re
import sys
from collections import defaultdict

objdir = sys.argv[1] if len(sys.argv) > 1 else "obj/debug"
alis = sorted(glob.glob(os.path.join(objdir, "*.ali")))
if not alis:
    sys.exit(f"no .ali files in {objdir}: build first (gprbuild -P castle.gpr -XCASTLE_MODE=debug)")

USE = set("rmsRiwdzxo")              # kinds of reference that are a use
decl = {}                            # (file, line, col, name) -> kind char, public?
uses = defaultdict(set)              # entity -> {(file of the use)}
ENT = re.compile(r"^(\d+)([A-Za-z+*])(\d+)(\*?)([^\s{<(\[=]+)")
REF = re.compile(r"(?:(\d+)\|)?(\d+)([A-Za-z])(\d+)")

for ali in alis:
    files = {}
    n = 0
    cur_file = None
    cur = None
    for line in open(ali, errors="replace"):
        if line.startswith("D "):
            n += 1
            files[n] = line.split()[1]
        elif line.startswith("X "):
            parts = line.split()
            cur_file = parts[2]
            cur = None
        elif cur_file and line[:1].isdigit():
            m = ENT.match(line)
            if not m:
                cur = None
                continue
            ln, kind, col, star, name = m.groups()
            cur = (cur_file, int(ln), int(col), name)
            if cur not in decl:
                decl[cur] = (kind, bool(star))
            rest = line[m.end():]
            ref_file = cur_file
            for r in REF.finditer(re.sub(r"\{[^}]*\}|<[^>]*>|\([^)]*\)|\[[^\]]*\]", " ", rest)):
                if r.group(1):
                    ref_file = files.get(int(r.group(1)), "?")
                if r.group(3) in USE:
                    uses[cur].add(ref_file)
        elif cur_file and line.startswith(".") and cur is not None:
            ref_file = None
            for r in REF.finditer(line[1:]):
                if r.group(1):
                    ref_file = files.get(int(r.group(1)), "?")
                if r.group(3) in USE:
                    uses[cur].add(ref_file or cur[0])
        elif not line.strip():
            cur = None


def unit_of(f):
    """castle-colony-think.adb -> castle-colony (a subunit is of its parent's body)."""
    base = re.sub(r"\.ad[sb]$", "", f)
    return base


def same_unit(spec, other):
    a, b = unit_of(spec), unit_of(other)
    return b == a or b.startswith(a + "-") and not os.path.exists(os.path.join("src", b + ".ads"))


ours = sorted(k for k in decl if os.path.exists(os.path.join("src", k[0])) and k[0].endswith(".ads") and decl[k][1])
never, inside, literals = [], [], []
for k in ours:
    kind = decl[k][0]
    where = uses.get(k, set())
    if not where:
        (literals if kind == "n" else never).append(k)
    elif all(same_unit(k[0], f) for f in where) and kind in "UV":
        # a subprogram used only by its own package's body and subunits
        if not any(f == k[0] for f in where):
            inside.append(k)

KIND = {"U": "procedure", "V": "function", "N": "number", "K": "package", "X": "exception", "n": "literal"}


def show(title, items):
    print(f"\n{title}: {len(items)}")
    by_file = defaultdict(list)
    for f, ln, col, name in items:
        k = decl[(f, ln, col, name)][0]
        by_file[f].append(f"{name} ({KIND.get(k, 'type' if k.isupper() else 'object')}, line {ln})")
    for f in sorted(by_file):
        print(f"  {f}: " + "; ".join(by_file[f]))


print(f"{len(alis)} .ali files of {objdir}; {len(ours)} public entities declared in the specifications of src/")
show("Never referred to at all", never)
show("Subprograms referred to only by their own package's body or subunits (they need not be public)", inside)
show("Enumeration literals never named", literals)
