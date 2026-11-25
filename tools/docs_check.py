#!/usr/bin/env python3
"""The living documents against the code, and the code against the documents.

    tools/docs_check.py [-v] [--all] [FILE...]

Run it from the repository's root.  It changes nothing and always leaves with 0: what it prints
is a list to read, not a verdict (a name in backticks may be a word of John's, or of a tool that
is not ours).

What a document says in backticks is taken for a name of something:

  an option     --like-this       must be a string in the Ada sources (the game, the runner,
                                  Castle.Scenario) or in one of the tools' scripts
  a path        docs/x.md, tools/y.sh, src/z.ads, bin/colony_run ...  must exist (bin/NAME: a
                                  main of castle.gpr)
  an identifier Like_This, Castle.Like.This, Like_This (args)  must be an identifier somewhere
                                  in the Ada sources
  a scratch script  $S/name       is listed: it is in no repository; it says whether a script of
                                  that name is kept in tools/ or in ~/CASTLE_GAME/releases/wip/scripts/

and the other way: every option the Ada sources take that no living document names, every main
of castle.gpr and every script in tools/ that none names.

The living documents are CLAUDE.md, README.md, docs/systems/, docs/production/ (with its briefs),
docs/conventions/ and docs/design/Mechanics_crosswalk.md.  The handoffs are records of their day
and are not read unless --all is given or a file is named.

-v prints every finding with its line; without it, the first twelve of each kind a document.
"""
import glob
import os
import re
import sys
from collections import defaultdict

verbose = "-v" in sys.argv
everything = "--all" in sys.argv
named = [a for a in sys.argv[1:] if not a.startswith("-")]

ada = sorted(glob.glob("src/*.ad[sb]") + glob.glob("game/*.ad[sb]") + glob.glob("tools/*.ad[sb]"))
scripts = sorted(glob.glob("tools/*.sh") + glob.glob("tools/*.py"))
idents = set()
options = set()
opt_where = defaultdict(set)
for f in ada:
    text = open(f, errors="replace").read()
    idents |= set(w.lower() for w in re.findall(r"[A-Za-z][A-Za-z0-9_]*", text))
    for o in re.findall(r'"(--[a-z0-9][a-z0-9-]*)"', text):
        options.add(o)
        opt_where[o].add(f)
script_text = {f: open(f, errors="replace").read() for f in scripts}
script_options = set()
for f, text in script_text.items():
    script_options |= set(re.findall(r"(?<![A-Za-z0-9-])(--[a-z0-9][a-z0-9-]*)", text))
mains = set(re.findall(r'"(\w+)\.adb"', open("castle.gpr").read()))

if named:
    docs = named
else:
    docs = (["CLAUDE.md", "README.md", "docs/design/Mechanics_crosswalk.md"]
            + sorted(glob.glob("docs/systems/*.md")) + sorted(glob.glob("docs/production/*.md"))
            + sorted(glob.glob("docs/production/briefs/*.md")) + sorted(glob.glob("docs/conventions/*.md")))
    if everything:
        docs += sorted(glob.glob("docs/handoffs/*.md"))

# Words in backticks that are not ours: other programs' options, git's words, shell.
FOREIGN = re.compile(r"^\s*(git|gprbuild|ffmpeg|rsync|perf|magick|compare|xvfb-run|env|timeout|pgrep|pkill|ps|tail|"
                     r"head|grep|command|ls|rm|cp|sed|awk|tar|date|kill|readlink|strings|cmp|claude|python3|bash|zsh)\b")
OTHER_OPTIONS = {"--force", "--check", "--soft", "--cacheinfo", "--call-graph", "--sort", "--tid", "--delete",
                 "--exclude", "--icons", "--channels", "--cached", "--stat", "--short", "--oneline", "--format", "--coverage"}
WIP = os.path.expanduser("~/CASTLE_GAME/releases/wip/scripts")

found = defaultdict(lambda: defaultdict(list))     # doc -> kind -> [(line, text)]
named_options = set()
named_words = set()
for doc in docs:
    if not os.path.exists(doc):
        continue
    for n, line in enumerate(open(doc, errors="replace"), 1):
        named_words |= set(re.findall(r"[A-Za-z_][A-Za-z0-9_.]*", line))
        for span in re.findall(r"`([^`\n]+)`", line):
            foreign = bool(FOREIGN.match(span))
            for o in re.findall(r"(?<![A-Za-z0-9-])(--[a-z0-9][a-z0-9-]*)", span):
                named_options.add(o)
                if o in options or o in OTHER_OPTIONS or foreign:
                    continue
                kind = "an option only a script of tools/ has" if o in script_options else "an option nothing takes"
                found[doc][kind].append((n, f"{o}   in `{span[:70]}`"))
            for s in re.findall(r"\$S/([A-Za-z0-9_./-]+)", span):
                base = os.path.basename(s.rstrip("/"))
                kept = ("tools/" if os.path.exists("tools/" + base)
                        else "releases/wip/scripts/" if os.path.exists(os.path.join(WIP, base)) else "nowhere kept")
                found[doc]["a scratch script"].append((n, f"$S/{s}   ({kept})"))
            if foreign or "$S" in span:
                continue
            for p in re.findall(r"(?<![\w$~/.-])((?:docs|tools|src|game|bin)/[A-Za-z0-9_./*<>-]+)", span):
                p = p.rstrip(".,:;)")
                if "NN" in p or "YYYY" in p:      # a pattern written out, not a path
                    continue
                if any(c in p for c in "*<>") or p.endswith("/"):
                    if not glob.glob(p.replace("<name>", "*").replace("<", "*").replace(">", "*") + ("*" if p.endswith("/") else "")):
                        found[doc]["a path that is not there"].append((n, p))
                    continue
                if p.startswith("bin/"):
                    name = p.split("/")[-1]
                    if name not in mains and "." not in name:
                        found[doc]["a program castle.gpr does not build"].append((n, p))
                    continue
                if not os.path.exists(p):
                    found[doc]["a path that is not there"].append((n, p))
            # identifiers: Like_This, Castle.Like.This, with or without arguments after
            for w in re.findall(r"(?<![\w.$/-])([A-Z][A-Za-z0-9]*(?:[_.][A-Za-z0-9]+)+)(?![\w/])", span):
                if re.search(r"\.(md|sh|py|adb|ads|json|txt|png|bin|gpr|toml|mp4|zip|log|sav|patch)$", w):
                    continue
                if w.upper() == w:                 # CASTLE_MODE, WAYLAND_DISPLAY: the environment's, not the sources'
                    continue
                parts = [x for x in re.split(r"[.]", w) if x]
                missing = [x for x in parts if x.lower() not in idents]
                if missing:
                    found[doc]["an identifier the sources do not have"].append((n, f"{w}   (no {', '.join(missing)})"))

total = 0
for doc in docs:
    if doc not in found:
        continue
    print(f"\n{doc}")
    for kind, items in sorted(found[doc].items()):
        total += len(items)
        print(f"  {kind}: {len(items)}")
        for n, text in (items if verbose else items[:12]):
            print(f"    {n}: {text}")
        if not verbose and len(items) > 12:
            print(f"    ... and {len(items) - 12} more (-v)")

print("\nThe other way")
unnamed = sorted(o for o in options if o not in named_options)
print(f"  options the Ada sources take that no living document names: {len(unnamed)} of {len(options)}")
by_file = defaultdict(list)
for o in unnamed:
    by_file[", ".join(sorted(os.path.basename(f) for f in opt_where[o]))].append(o)
for f, os_ in sorted(by_file.items()):
    print(f"    {f}: {' '.join(os_)}")
quiet_mains = sorted(m for m in mains if m not in named_words)
print(f"  mains of castle.gpr no living document names: {len(quiet_mains)}" + (": " + ", ".join(quiet_mains) if quiet_mains else ""))
quiet_scripts = sorted(os.path.basename(f) for f in scripts
                       if os.path.basename(f) not in " ".join(named_words) and f.split("/")[-1] not in named_words)
print(f"  scripts in tools/ no living document names: {len(quiet_scripts)}" + (": " + ", ".join(quiet_scripts) if quiet_scripts else ""))
stale_script_options = defaultdict(list)
for f, text in script_text.items():
    if not f.endswith(".sh"):
        continue
    for o in sorted(set(re.findall(r"(?<![A-Za-z0-9-])(--[a-z0-9][a-z0-9-]*)", text))):
        if o not in options and o not in OTHER_OPTIONS:
            # an option of another program on the same line is not ours to check
            lines = [ln for ln in text.splitlines() if o in ln]
            if all(re.search(r"\b(ffmpeg|git|gprbuild|mktemp|magick|python3|awk|sed|sort|grep|tail|head|xvfb-run|rsync|tar|date|cut|tr|wc|ls|diff|cmp)\b", ln)
                   and "castle_game" not in ln and "colony_run" not in ln and "$BIN" not in ln and "$GAME" not in ln for ln in lines):
                continue
            if all(ln.lstrip().startswith("#") for ln in lines):
                continue
            if re.search(r'"\$\{?1\}?"\s*=\s*"' + re.escape(o) + '"', text):      # the script's own argument
                continue
            stale_script_options[f].append(o)
print(f"  scripts in tools/ that give a program of ours an option it does not take: {len(stale_script_options)}")
for f, os_ in sorted(stale_script_options.items()):
    print(f"    {f}: {' '.join(os_)}")
print(f"\n{total} to read in {len(docs)} documents; {len(idents)} identifiers and {len(options)} options known from {len(ada)} Ada files.")
