#!/usr/bin/env python3
"""John's design document against itself and against the build.

    tools/mechanics_check.py [-v] [--doc PATH] [--map PATH]

Run it from the repository's root, whenever docs/design/detailed_mechanics.json comes with a new
version and whenever an enumeration it names in the code grows.  It changes nothing.

1. The document against itself: every id unique in its section, every cross-reference an id that
   exists (a recipe's job, place, inputs, outputs and source; a job's class, skills, kit and the
   jobs it rises from; a building's zone and jobs; and so on), the calendar's own arithmetic.
   What it finds is printed for John: the document is his and nothing here changes it.

2. The document against the code, through tools/mechanics_map.json: for each enumeration of the
   code that holds content (jobs, trades, skills, things carried, zones, buildings, materials,
   deposits), which id of the document each literal is, or that it has none and why.  The map is
   kept by hand.  A literal the map does not know, a literal the map names that is gone, or an id
   the map points at that the document no longer has makes this script fail (exit 1): the map is
   then brought up to date, and the crosswalk (docs/design/Mechanics_crosswalk.md) with it.

3. Numbers both sides state (the calendar, how many arrive): printed side by side.  A difference
   is a line for John, not a failure.

-v lists every id of the document with no counterpart in the build, section by section.
"""
import json
import re
import sys
from collections import Counter

DOC = "docs/design/detailed_mechanics.json"
MAP = "tools/mechanics_map.json"
verbose = False
args = sys.argv[1:]
while args:
    a = args.pop(0)
    if a == "-v":
        verbose = True
    elif a == "--doc":
        DOC = args.pop(0)
    elif a == "--map":
        MAP = args.pop(0)
    else:
        sys.exit(__doc__)

d = json.load(open(DOC))
print(f"{d['meta']['name']}, version {d['meta']['version']}, dated {d['meta']['date']}")

# ---------------------------------------------------------------- 1. the document against itself

problems = []


def problem(where, what):
    problems.append(f"  {where}: {what}")


def ids(section, key="id"):
    seen = Counter(x[key] for x in section)
    return seen


sections = ["classes", "skills", "construction_tiers", "zones", "buildings", "jobs", "resources",
            "flora", "fauna", "deposits", "recipes"]
have = {}
for s in sections:
    c = ids(d[s])
    for k, n in c.items():
        if n > 1:
            problem(f"{s}.{k}", f"the id is used {n} times")
    have[s] = set(c)
have["needs"] = set(x["id"] for x in d["mechanics"]["needs"])
have["wants"] = set(x["id"] for x in d["mechanics"]["wants"]["list"])
have["grades"] = set(x["id"] for x in d["mechanics"]["quality"]["grades"])
have["livestock"] = set(x["id"] for x in d["resources"] if x["category"] == "livestock")
have["sources"] = have["flora"] | have["fauna"] | have["deposits"]
used = {s: set() for s in have}          # what something refers to, for "never referred to" below


n_refs = 0


def ref(where, value, kind, also=()):
    """value (an id, a list of ids, or None) must be of section kind (or one of the words in also)."""
    global n_refs
    if value is None:
        return
    for v in (value if isinstance(value, (list, tuple, set)) else [value]):
        n_refs += 1
        if v in also:
            continue
        kinds = kind if isinstance(kind, (list, tuple)) else [kind]
        if any(v in have[k] for k in kinds):
            for k in kinds:
                if v in have[k]:
                    used[k].add(v)
        else:
            problem(where, f"'{v}' is no id of {' or '.join(kinds)}")


def slots(where, table, kind):
    """A recipe's {"a|b": n}: every alternative must be an id."""
    for slot in (table or {}):
        for v in slot.split("|"):
            ref(where, v, kind)


for c in d["classes"]:
    w = f"classes.{c['id']}"
    ref(w + ".housing", c.get("housing"), "buildings")
    ref(w + ".needs", c.get("needs"), "needs")
    ref(w + ".wants", c.get("wants"), "wants")
    ref(w + ".want_grade", c.get("want_grade"), "grades")
for n in d["mechanics"]["needs"]:
    w = f"mechanics.needs.{n['id']}"
    ref(w + ".satisfied_by", n.get("satisfied_by"), "resources")
    ref(w + ".provided_from", n.get("provided_from"), "buildings")
    ref(w + ".satisfied_by_job", n.get("satisfied_by_job"), "jobs")
for x in d["mechanics"]["wants"]["list"]:
    w = f"mechanics.wants.{x['id']}"
    ref(w + ".item", x.get("item"), "resources")
    ref(w + ".satisfied_by_building", x.get("satisfied_by_building"), "buildings")
for g in d["mechanics"]["quality"]["grades"]:
    ref(f"mechanics.quality.{g['id']}.expected_by", g.get("expected_by"), "classes")
for s in d["skills"]:
    ref(f"skills.{s['id']}.spillover", list(s.get("spillover", {})), "skills")
for t in d["construction_tiers"]:
    w = f"construction_tiers.{t['id']}"
    ref(w + ".materials", t.get("materials"), "resources")
    ref(w + ".built_by", t.get("built_by"), "jobs")
    ref(w + ".for", t.get("for"), "classes")
for z in d["zones"]:
    w = f"zones.{z['id']}"
    ref(w + ".buildings", z.get("buildings"), "buildings")
    ref(w + ".upgrade_materials", z.get("upgrade_materials"), "resources")
    for st in z.get("depth_stages", []):
        ref(w + f".depth_stages.{st['stage']}.requires", st.get("requires"), "jobs")
        ref(w + f".depth_stages.{st['stage']}.consumes", st.get("consumes"), "resources")
for b in d["buildings"]:
    w = f"buildings.{b['id']}"
    ref(w + ".zone", b.get("zone"), "zones")
    ref(w + ".also_in", b.get("also_in"), "zones")
    ref(w + ".jobs", b.get("jobs"), "jobs")
    ref(w + ".furniture", b.get("furniture"), "resources")
    ref(w + ".furnishing_slots", b.get("furnishing_slots"), "resources")
    ref(w + ".houses_livestock", b.get("houses_livestock"), "livestock")
    ref(w + ".occupants", b.get("occupants"), "classes", also=("player",))
    ref(w + ".built_by", b.get("built_by"), "jobs")
    ref(w + ".materials", b.get("materials"), "resources")
for j in d["jobs"]:
    w = f"jobs.{j['id']}"
    ref(w + ".class", j.get("class"), "classes")
    ref(w + ".from", j.get("from"), "jobs")
    ref(w + ".reverts_to", j.get("reverts_to"), "jobs")
    ref(w + ".works_at.zone", (j.get("works_at") or {}).get("zone"), "zones")
    ref(w + ".works_at.building", (j.get("works_at") or {}).get("building"), "buildings")
    ref(w + ".alt_works_at", j.get("alt_works_at"), "buildings")
    ref(w + ".requires", list(j.get("requires") or {}), "skills")
    ref(w + ".trains", j.get("trains"), "skills")
    ref(w + ".kit", j.get("kit"), "resources")
    ref(w + ".max_grade", j.get("max_grade"), "grades")
for r in d["resources"]:
    ref(f"resources.{r['id']}.stored_in", r.get("stored_in"), ["buildings", "zones"], also=("none",))
for x in d["flora"]:
    ref(f"flora.{x['id']}.yields", x.get("yields"), "resources")
    ref(f"flora.{x['id']}.worked_by", x.get("worked_by"), "jobs")
for x in d["fauna"]:
    ref(f"fauna.{x['id']}.yields", x.get("yields"), "resources")
    ref(f"fauna.{x['id']}.domesticates_to", x.get("domesticates_to"), "livestock")
for x in d["livestock_products"]:
    w = f"livestock_products.{x['livestock']}"
    ref(w, x["livestock"], "livestock")
    ref(w + ".yields", x.get("yields"), "resources")
    ref(w + ".slaughter", x.get("slaughter"), "resources")
    ref(w + ".housed_in", x.get("housed_in"), "buildings")
for x in d["deposits"]:
    w = f"deposits.{x['id']}"
    ref(w + ".yields", x.get("yields"), "resources")
    ref(w + ".worked_by", x.get("worked_by"), "jobs")
    ref(w + ".zone", x.get("zone"), "zones")
    ref(w + ".follows", x.get("follows"), "deposits")
made = set()
for r in d["recipes"]:
    w = f"recipes.{r['id']}"
    ref(w + ".job", r.get("job"), "jobs", also=("self",))
    ref(w + ".at", r.get("at"), "buildings")
    ref(w + ".source", r.get("source"), "sources")
    slots(w + ".inputs", r.get("inputs"), "resources")
    slots(w + ".outputs", r.get("outputs"), "resources")
    slots(w + ".optional_inputs", r.get("optional_inputs"), "resources")
    slots(w + ".requires", r.get("requires"), "resources")
    ref(w + ".grade", r.get("grade"), "grades")
    made |= set(r.get("outputs") or {})
gs = d["game_start"]
for c in gs["colonists"]:
    ref("game_start.colonists.job", c.get("job"), "jobs")
for person, kit in gs["personal_kit"].items():
    if isinstance(kit, dict):
        ref(f"game_start.personal_kit.{person}", list(kit), "resources")
for cart in gs["provisions"]["carts"]:
    ref(f"game_start.provisions.carts.{cart['name']}", list(cart["contents"]), "resources")

# A zone lists its buildings and a building names its zone: both ways.
for b in d["buildings"]:
    for z in [b["zone"]] + b.get("also_in", []):
        zone = next((x for x in d["zones"] if x["id"] == z), None)
        if zone is not None and b["id"] not in zone["buildings"]:
            problem(f"buildings.{b['id']}", f"its zone '{z}' does not list it")
for z in d["zones"]:
    for bid in z["buildings"]:
        b = next((x for x in d["buildings"] if x["id"] == bid), None)
        if b is not None and z["id"] != b["zone"] and z["id"] not in b.get("also_in", []):
            problem(f"zones.{z['id']}", f"lists '{bid}', whose zone is '{b['zone']}'")
# A building lists its jobs and a job names its building: both ways.
for j in d["jobs"]:
    places = [(j.get("works_at") or {}).get("building")] + j.get("alt_works_at", [])
    for bid in [p for p in places if p]:
        b = next((x for x in d["buildings"] if x["id"] == bid), None)
        if b is not None and j["id"] not in b.get("jobs", []):
            problem(f"jobs.{j['id']}", f"works at '{bid}', which does not list it")
# The calendar's own arithmetic.
cal = d["meta"]["calendar"]
if cal["days_per_season"] * cal["seasons_per_year"] != cal["days_per_year"]:
    problem("meta.calendar", "days_per_season times seasons_per_year is not days_per_year")
left = cal["days_per_season"] - cal["start"]["day"] + 1          # days of the starting season, the first counted
note = cal["start"]["note"]
m = re.search(r"Autumn begins day (\d+), winter day (\d+), spring \(the thaw\) day (\d+)", note)
if m:
    want = (left, left + cal["days_per_season"], left + 2 * cal["days_per_season"])
    got = tuple(int(x) for x in m.groups())
    if got != want:
        problem("meta.calendar.start.note", f"says days {got}; day {cal['start']['day']} of a season of "
                f"{cal['days_per_season']} gives {want}")
    thaw = d["mechanics"]["colony_indices"]["tuning"].get("thaw_day")
    if thaw is not None and thaw != got[2]:
        problem("mechanics.colony_indices.tuning.thaw_day", f"{thaw}, the calendar's note says {got[2]}")

print(f"\n1. The document against itself ({n_refs} cross-references followed): {len(problems)} to look at")
for p in problems:
    print(p)

# Not faults, but worth his eye: what nothing makes, and what nothing refers to.
yielded = set()
for sec in ("flora", "fauna", "deposits"):
    for x in d[sec]:
        yielded |= set(x.get("yields") or [])
for x in d["livestock_products"]:
    yielded |= set(x.get("yields") or []) | set(x.get("slaughter") or [])
start_stock = set()
for cart in gs["provisions"]["carts"]:
    start_stock |= set(cart["contents"])
no_source = sorted(r["id"] for r in d["resources"]
                   if r["id"] not in made and r["id"] not in yielded
                   and r["category"] not in ("livestock",))
print(f"   resources no recipe makes and nothing yields: {len(no_source)}"
      + (": " + ", ".join(f"{x}{' (comes on a cart)' if x in start_stock else ''}" for x in no_source) if no_source else ""))
consumed = set()
for r in d["recipes"]:
    for t in ("inputs", "optional_inputs", "requires"):
        for slot in (r.get(t) or {}):
            consumed |= set(slot.split("|"))
unused = sorted(have["resources"] - used["resources"])
print(f"   resources nothing in the document refers to: {len(unused)}" + (": " + ", ".join(unused) if unused else ""))
jobless = sorted(j["id"] for j in d["jobs"]
                 if not any(r["job"] == j["id"] for r in d["recipes"]) and not j.get("services")
                 and not j.get("appointed"))
print(f"   jobs with no recipe and no service, not appointed: {len(jobless)}" + (": " + ", ".join(jobless) if jobless else ""))
research = Counter()
for sec in ("jobs", "recipes", "resources", "buildings"):
    for x in d[sec]:
        if x.get("research"):
            research[x["research"]] += 1
for s in d["skills"]:
    if s.get("master_needs"):
        research[s["master_needs"]] += 1
print(f"   research named, with no section of its own: {len(research)} topics ({', '.join(sorted(research))})")

# ---------------------------------------------------------------- 2. the document against the code

m = json.load(open(MAP))
stale = []


def enumeration(path, name):
    text = re.sub(r"--[^\n]*", "", open(path).read())
    mm = re.search(r"\btype\s+" + re.escape(name) + r"\s+is\s*\(([^;()]*?)\)\s*(?:with\b[^;]*)?;", text, re.S)
    if not mm:
        return None
    return [x.strip() for x in mm.group(1).replace("\n", " ").split(",")]


print(f"\n2. The document against the code ({MAP}, written against version {m['document_version']})")
if m["document_version"] != d["meta"]["version"]:
    print(f"  the map was written against version {m['document_version']} and the document is "
          f"{d['meta']['version']}: read its changelog, bring the map and the crosswalk up to date, "
          f"then set document_version")
    stale.append("version")
built = {s: set() for s in have}
world = {s: set() for s in have}         # made by the generator, used by nothing in the colony yet ('~')


def count(sec, tid, where):
    only_world = tid.startswith("~")
    tid = tid.lstrip("~")
    if tid not in have[sec]:
        print(f"  {where}: the map says '{tid}', and the document has no such id of {sec}")
        stale.append(where)
        return False
    (world if only_world else built)[sec].add(tid)
    return True


for e in m["enumerations"]:
    lits = enumeration(e["file"], e["type"])
    if lits is None:
        print(f"  {e['code']}: not found in {e['file']}")
        stale.append(e["code"])
        continue
    n_mapped = 0
    for lit in lits:
        if lit not in e["map"]:
            print(f"  {e['code']}: the literal {lit} is not in the map (say which id of '{e['section']}' it is, or null and why)")
            stale.append(f"{e['code']}.{lit}")
            continue
        target = e["map"][lit]
        for t in ([] if target is None else target if isinstance(target, list) else [target]):
            sec, _, tid = t.rpartition(":")
            if count(sec or e["section"], tid, f"{e['code']}.{lit}"):
                n_mapped += 1
    for lit in e["map"]:
        if lit not in lits:
            print(f"  {e['code']}: the map names {lit}, which the code no longer has")
            stale.append(f"{e['code']}.{lit}")
    code_only = [lit for lit in lits if e["map"].get(lit, 0) is None]
    print(f"  {e['code']}: {len(lits)} literals, {len(lits) - len(code_only)} with an id of the document"
          + (f"; the build's own: {', '.join(code_only)}" if code_only else ""))
for sec, tid_list in m.get("built_otherwise", {}).items():
    if isinstance(tid_list, list):
        for tid in tid_list:
            count(sec, tid, f"built_otherwise.{sec}")

print("\n   How much of each section has a counterpart in the build (a counterpart is a thing of the same")
print("   kind in the code; it says nothing of whether the build's rules for it are the document's):")
for sec in ("jobs", "skills", "resources", "zones", "buildings", "flora", "fauna", "deposits", "recipes"):
    total = len(have[sec])
    only = world[sec] - built[sec]
    print(f"     {sec:10s} {len(built[sec]):3d} of {total:3d}"
          + (f"   and {len(only)} more that the generator makes and the colony does not use yet"
             f" ({', '.join(sorted(only))})" if only else ""))
    if verbose:
        rest = sorted(have[sec] - built[sec] - only)
        if rest:
            print("        not in the build: " + ", ".join(rest))

# ---------------------------------------------------------------- 3. numbers both sides state


def at(path):
    v = d
    for k in path.split("."):
        v = v[int(k)] if isinstance(v, list) else v[k]
    return v


print("\n3. Numbers both sides state")
for c in m["numbers"]:
    text = re.sub(r"--[^\n]*", "", open(c["file"]).read())
    mm = re.search(c["pattern"], text)
    code_value = mm.group(1) if mm else None
    if code_value is None:
        print(f"  {c['what']}: the pattern finds nothing in {c['file']}")
        stale.append(c["what"])
        continue
    if c.get("doc_calc") == "start_day_of_year":      # read from the document, not typed into the map
        cal = d["meta"]["calendar"]
        doc_value = cal["seasons"].index(cal["start"]["season"]) * cal["days_per_season"] + cal["start"]["day"] - 1
    else:
        doc_value = c["doc_value"] if "doc_value" in c else at(c["doc"])
    same = None
    try:
        same = abs(float(code_value) - float(doc_value)) < 1e-9
    except (TypeError, ValueError):
        pass
    mark = "the same" if same else "DIFFERENT" if same is False else "see the crosswalk"
    if c.get("units_differ"):
        mark = "not comparable as they stand: " + c["units_differ"]
    print(f"  {c['what']}: the document {doc_value}, the code {code_value} ({c['code']}): {mark}")

if stale:
    print(f"\nThe map is out of date at {len(stale)} place(s): bring tools/mechanics_map.json and "
          f"docs/design/Mechanics_crosswalk.md up to date.")
    sys.exit(1)
print("\nThe map is up to date with the code and the document.")
