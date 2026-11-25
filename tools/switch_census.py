#!/usr/bin/env python3
"""Every switch of the game: what it is by default, which option sets it, and which part of the
gate runs it which way.

    tools/switch_census.py [--md]

Run it from the repository's root.  It reads the sources and the gate's scripts and changes
nothing.  A switch here is a `procedure Set_NAME (On : Boolean)` of a specification in src/, or
one of the Boolean variables of Castle.Actions that the scenario sets.

For each it prints:
  default   the value its variable is declared with in the body (what the game runs when nothing is said)
  option    the command-line option(s) whose handler calls it, with the value given
  ref       how many of the eight reference runs (line for line) say the option
  stress, yard, turned, square   whether tools/stress.sh, stockyard_sites.sh, turned_streets.sh,
            square_sites.sh say it anywhere
  check     what colony_check's Reset holds it at, and how often the check sets it True / False / by a
            variable (a loop over both ways, as a rule)

and then what the table is for:
  the rules on by default that no reference log is run with (the logs hold them off)
  the rules whose other way (the value that is not the default) nothing in the gate runs
  the switches no option reaches

--md prints the table as Markdown (for docs/systems/switches.md).
"""
import glob
import re
import sys

md = "--md" in sys.argv


def read(p):
    return open(p, errors="replace").read()


def nocomment(t):
    """The text without its comments (a -- inside a string literal is no comment: the options are such)."""
    out = []
    for line in t.split("\n"):
        in_string = False
        cut = len(line)
        for i, ch in enumerate(line):
            if ch == '"':
                in_string = not in_string
            elif ch == "-" and not in_string and line[i:i + 2] == "--":
                cut = i
                break
        out.append(line[:cut])
    return "\n".join(out)


specs = sorted(glob.glob("src/*.ads"))
bodies = {p: nocomment(read(p)) for p in sorted(glob.glob("src/*.adb"))}
all_bodies = "\n".join(bodies.values())

switches = []          # (package, name, first line of its comment)
for p in specs:
    raw = read(p)
    pkg = re.search(r"package\s+([\w.]+)\s+is", raw)
    pkg = pkg.group(1) if pkg else p
    lines = raw.splitlines()
    for i, line in enumerate(lines):
        m = re.match(r"\s*procedure (Set_\w+)\s*\(\s*(\w+)\s*:\s*Boolean\s*\)\s*;", line)
        if m:
            switches.append((pkg, m.group(1)))
    if pkg == "Castle.Actions":
        for m in re.finditer(r"^\s{3}(\w+)\s*:\s*Boolean\s*:=\s*(True|False)\s*;", raw, re.M):
            switches.append((pkg, m.group(1) + "=" + m.group(2)))


def default_of(name):
    """The declared value of the variable Set_NAME assigns its parameter to."""
    m = re.search(r"procedure " + re.escape(name) + r"\s*\(\s*(\w+)\s*:\s*Boolean\s*\)\s*is\b(.*?)\bend " + re.escape(name) + r"\s*;",
                  all_bodies, re.S)
    if not m:
        return "?"
    par, body = m.group(1), m.group(2)
    vars_ = re.findall(r"(\w+)\s*:=\s*(not\s+)?" + par + r"\s*;", body)
    for var, neg in vars_:
        d = re.search(r"\b" + re.escape(var) + r"\s*:\s*Boolean\s*:=\s*(True|False)\s*;", all_bodies)
        if d:
            v = d.group(1) == "True"
            return "on" if (v != bool(neg)) else "off"
    return "?"


# option handlers: text from an option's literal to the next option's
handlers = {}          # option -> (file, block)
for p in ["src/castle-scenario.adb", "game/castle_game.adb", "tools/colony_run.adb"]:
    t = nocomment(read(p))
    # a condition that names options (A = "--x" or else A = "--y"; A in "--x" | "--y"), then its statements
    conds = [(m.start(), m.end(), re.findall(r'"(--[a-z0-9-]+)"', m.group(0)))
             for m in re.finditer(r'\b(?:els)?if\b[^;]*?"--[a-z0-9-]+"[^;]*?\bthen\b', t, re.S)]
    for k, (start, stop, opts) in enumerate(conds):
        end = conds[k + 1][0] if k + 1 < len(conds) else min(len(t), stop + 1500)
        for opt in opts:
            handlers.setdefault(opt, []).append((p, t[stop:min(end, stop + 2500)]))
# A handler often only sets a variable (S.Field in the scenario, a plain one in the game and the
# runner) and the setter is called with it later: Set_X (V), Set_X (not V), Set_X (A and then not B),
# or "if V then ... Set_X (False) ... end if".  linked: variable -> [(setter, negated)], such that the
# value the setter is given is (the variable's value /= negated).
VAR = r"(?:S\.)?[A-Z]\w*"
linked = {}
for p in ["src/castle-scenario.adb", "game/castle_game.adb", "tools/colony_run.adb"]:
    t = nocomment(read(p))
    for m in re.finditer(r"(?:Castle\.\w+\.)?(Set_\w+)\s*\(\s*(not\s+)?(" + VAR + r")\s*\)", t):
        linked.setdefault((p, m.group(3)), []).append((m.group(1), bool(m.group(2))))
    for m in re.finditer(r"(?:Castle\.\w+\.)?(Set_\w+)\s*\(\s*(" + VAR + r")\s+and then\s+not\s+(" + VAR + r")\s*\)", t):
        linked.setdefault((p, m.group(2)), []).append((m.group(1), False))
        linked.setdefault((p, m.group(3)), []).append((m.group(1), True))
    for m in re.finditer(r"Castle\.Actions\.(\w+)\s*:=\s*(not\s+)?(" + VAR + r")\s*;", t):
        linked.setdefault((p, m.group(3)), []).append((m.group(1), bool(m.group(2))))
    for m in re.finditer(r"\bif\s+(not\s+)?(" + VAR + r")\s+then\b(.*?)\bend if\s*;", t, re.S):
        for c in re.finditer(r"(?:Castle\.\w+\.)?(Set_\w+)\s*\(\s*(True|False)\s*\)", m.group(3)):
            want = c.group(2) == "True"
            linked.setdefault((p, m.group(2)), []).append((c.group(1), want != (not bool(m.group(1)))))

opts_of = {}           # setter or variable -> {(option, value)}
for opt, hs in handlers.items():
    for p, block in hs:
        for m in re.finditer(r"(Set_\w+)\s*\(\s*(True|False)\s*\)", block):
            opts_of.setdefault(m.group(1), set()).add((opt, m.group(2) == "True"))
        for m in re.finditer(r"Castle\.Actions\.(\w+)\s*:=\s*(True|False)\s*;", block):
            opts_of.setdefault(m.group(1), set()).add((opt, m.group(2) == "True"))
        for m in re.finditer(r"(" + VAR + r")\s*:=\s*(True|False)\s*;", block):
            for setter, neg in linked.get((p, m.group(1)), []):
                opts_of.setdefault(setter, set()).add((opt, (m.group(2) == "True") != neg))

ref_base = read("tools/reference_run.sh")
ref_runs = [ln for ln in read("tools/reference_check.sh").splitlines() if ln.startswith("same ")]
script = {k: read(f"tools/{v}") for k, v in
          (("stress", "stress.sh"), ("yard", "stockyard_sites.sh"), ("turned", "turned_streets.sh"), ("square", "square_sites.sh"))}


def says(text, opt):
    return re.search(r"(?<![A-Za-z0-9-])" + re.escape(opt) + r"(?![A-Za-z0-9-])", text) is not None


check = nocomment(read("tools/colony_check.adb"))
m = re.search(r"procedure Reset is\s+begin(.*?)end Reset;", check, re.S)
reset = m.group(1) if m else ""

rows = []
for pkg, name in switches:
    if "=" in name:                                   # a variable of Castle.Actions
        var, val = name.split("=")
        default = "on" if val == "True" else "off"
        key, shown = var, f"{pkg}.{var}"
        held = re.search(r"Castle\.Actions\." + var + r"\s*:=\s*(True|False)", reset)
        n_true = len(re.findall(r"Castle\.Actions\." + var + r"\s*:=\s*True", check))
        n_false = len(re.findall(r"Castle\.Actions\." + var + r"\s*:=\s*False", check))
        n_var = len(re.findall(r"Castle\.Actions\." + var + r"\s*:=\s*(?!True\b|False\b)[A-Za-z]", check))
    else:
        default = default_of(name)
        key, shown = name, f"{pkg}.{name}"
        held = re.search(r"\b" + name + r"\s*\(\s*(True|False)\s*\)", reset)
        n_true = len(re.findall(r"\b" + name + r"\s*\(\s*True\s*\)", check))
        n_false = len(re.findall(r"\b" + name + r"\s*\(\s*False\s*\)", check))
        n_var = len(re.findall(r"\b" + name + r"\s*\(\s*(?!True\b|False\b)[A-Za-z]", check))
    opts = sorted(opts_of.get(key, []))
    off_opts = [o for o, v in opts if (v is False and default == "on") or (v is True and default == "off")]
    n_ref = 0
    for o in off_opts:
        if says(ref_base, o):
            n_ref = len(ref_runs)
        else:
            n_ref = max(n_ref, sum(1 for ln in ref_runs if says(ln, o)))
    in_script = {k: any(says(t, o) for o in off_opts) for k, t in script.items()}
    rows.append(dict(shown=shown, name=key, default=default, opts=opts, off_opts=off_opts, n_ref=n_ref,
                     in_script=in_script, held=(held.group(1) if held else ""), n_true=n_true, n_false=n_false, n_var=n_var))

if md:
    print("| Switch | Default | Option (the value it gives) | Reference runs that say it (of 8) | stress | yard | turned | square | colony_check: Reset holds it; set True / False / by a variable, in all |")
    print("|---|---|---|---|---|---|---|---|---|")
for r in rows:
    opts = ", ".join(f"`{o}` ({'on' if v else 'off'})" for o, v in r["opts"]) or "none"
    cells = [f"`{r['shown']}`", r["default"], opts, str(r["n_ref"]) if r["off_opts"] else "",
             *("says" if r["in_script"][k] else "" for k in ("stress", "yard", "turned", "square")),
             f"{r['held'] or 'not held'}; {r['n_true']} / {r['n_false']} / {r['n_var']}"]
    if md:
        print("| " + " | ".join(cells) + " |")
    else:
        print(f"{r['shown']:52s} {r['default']:3s} {opts[:60]:60s} ref {cells[3]:2s} "
              + " ".join(k if r["in_script"][k] else "-" * len(k) for k in ("stress", "yard", "turned", "square"))
              + f"  check: {cells[8]}")

n_bool = len(rows)
on = [r for r in rows if r["default"] == "on"]


def say(title, items):
    if md:
        print(f"\n**{title}**" + (" " + ", ".join(f"`{x}`" if " " not in x else x for x in items) if items else " none"))
    else:
        print(f"\n{title}")
        print("  " + (", ".join(items) if items else "none"))


if md:
    print("\n## What the table says\n")
print(f"{n_bool} switches: {len(on)} on by default, {sum(1 for r in rows if r['default'] == 'off')} off"
      + (f", {sum(1 for r in rows if r['default'] == '?')} whose default this script could not read."
         if any(r['default'] == '?' for r in rows) else "."))
never_logged = [r for r in on if r["off_opts"] and r["n_ref"] == len(ref_runs)]
say(f"On by default, and every one of the {len(ref_runs)} reference runs says its option, so no line-for-line log is "
    f"run with the rule on ({len(never_logged)}):", [r["name"] for r in never_logged])
partly = [r for r in on if r["off_opts"] and 0 < r["n_ref"] < len(ref_runs)]
say(f"On by default, on in some reference runs and off in others ({len(partly)}):",
    [f"{r['name']} (off in {r['n_ref']})" for r in partly])
unreached = [r for r in on if r["off_opts"] and r["n_ref"] == 0]
say(f"On by default, and no reference run says its option: each log is run with the rule on, whether or not the "
    f"run ever comes to it ({len(unreached)}):", [r["name"] for r in unreached])


def other_way_run(r):
    """Is the value that is not the default run by anything in the gate?"""
    if r["n_ref"] or any(r["in_script"].values()):
        return True
    other = "False" if r["default"] == "on" else "True"
    return (r["n_false"] if other == "False" else r["n_true"]) > 0 or r["n_var"] > 0


unproved = [r for r in rows if r["default"] in ("on", "off") and not other_way_run(r)]
say(f"The other way (the value that is not the default) is run by nothing in the gate ({len(unproved)}):",
    [f"{r['name']} ({'no option' if not r['off_opts'] else ' '.join(r['off_opts'])})" for r in unproved])
no_opt = [r for r in rows if not r["opts"]]
say(f"No option reaches it ({len(no_opt)}):", [r["name"] for r in no_opt])
