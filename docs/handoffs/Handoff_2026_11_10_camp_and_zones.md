# Castle Game handoff (2026-11-10: zones' ground, the fire's life, the camp built; between stages 5c and 6; closed, accepted as built; Claude Code)

- **Closed 2026-11-10.** John, after trying the build: "Don't place a distance limit on initial gathering, if
  they have to walk 200m to get stone they walk 200m, they don't have to eat just stew, if they are hungry
  they can forrage themselves if the storage is depleated or reserved, eat raw forrage from the stockpile if
  it's availible, etc, that is the opprotunity cost for not having a stockpile or food cooking, same with
  eating raw forrage cooked recovers hunger more efficiently than raw, raw meat won't be consumed that must be
  prepared, other than that everything you have works wonderfully, it is starting to take shape, the path
  should work the same way, the player plans it the serfs build it."
  - **Accepted as built**: "everything you have works wonderfully". The first values stand, his to tune.
  - **Answered, of the calls put to him** ("His calls", below): the first day's cost stands, as the
    opportunity cost of having no stockpile or cooking yet; "no boulder, no camp" is overruled: no distance
    limit on what the camp's building takes (the work that follows this one).
  - **Restated, not changed**: the eating rules of stage 4 (stew is not the only food: raw from the stockpile
    where there is any, fending for oneself when the store is empty or held, cooked food going further than
    raw, meat never eaten raw). Checked against day one of the reference run: whenever raw food lay free in
    the stockpile the hungry ate it, down to nothing. The thresholds are as they were (eating at the next
    break below 40 %, leaving work to eat or to fend below 15 %).
  - **Shown and not taken up, so standing as built by default**: logs carried only by the cook and a
    forester; the unassigned building too; only a stockpile's places having their grass cut; eight hours being
    a log's, not a stoking's; no cost to lighting a cold fire; the flames sinking through a fire's last hour;
    a lot taken within a metre of a path's edge; a camp refused within 3 m of a path; no un-zoning.
  - **New, from the same message**: paths planned by the player and built by the serfs, as the camp is. That
    and the distance limit are the next work (branch `paths-and-reach`).
  `camp-and-zones` is merged into `main`; the zip is remade from `main`. `tools/colony_v14.bin` was written by
  this code before the next format.
- Built from John's message of the day, with first rules and values of mine, and put to him with the build.
- Code: GAME_alpha_1_3/compiled, branch `camp-and-zones` from `main` at bd5186a (shadows and the fire, closed).
  Four code commits: d4303d2 (zones' ground), 1707752 (the fire's life), 95d4a4a (the camp built), 03ece9c
  (a stall of the cook's at an unbuilt camp, who carries logs, tunables to the spec). The zip is the closing
  commit, documents and `tools/colony_v14.bin` only after 03ece9c: CASTLE_GAME/releases/castle_game_camp_zones.zip.
  Demo: camp_and_zones.mp4 (tools/demo_camp_zones.sh), 63 s.
- Checks: all nine pass in debug from a clean copy (`git archive`) of 03ece9c, built from nothing, with the
  six known warnings; `tools/reference_check.sh` passes there, all four runs. colony_check 282 -> 337,
  pick_check 31 -> 32.
- Versions: Generator_Version 12 and save format 6 as they were. Colony blob 13 -> 14 (each zone's ground and
  what is built on it, the camp's labour, the fire's dying down, the patch of the camp's ground each member
  is at). Older blobs load; `tools/colony_v13.bin` was written by `main` before the format moved.

## John's words (2026-11-10)
"this session we are working on a handful of small tasks, stockpile dynamics, fire life, zone fill instead of
squares, and snapping to pathways, preventing overlap and campfire dynamics as well. So fire life needs to be
extended to about 8hours with a 3 hour diedown for restoking, a campfire needs to be dynamic now, same as a
zone, the fire just doesn't magically appear, they build it, the current model comes into existent after they
deliver stone and wood to build it, then the one of the few exceptions in this game the pot can magically
appear, I have also noticed a lag in laying the logs for the seating, they also need to prepare the ground,
compacting the earth around the campfire grass disappears. Then the stockpile zone, same with all zones, fill,
snap, terminate at the path, so it can be at diagonals and whatnot, how this all fits together will make sense,
when you realize they will eventually start upgrading the stockpile, build a storehouse, warehouse, fences and
outdoor storage will get coverings, paths and and zone need to not overlap, paths remove the possibility of
that area becoming a zone."

## What John sees on first launch
1. **Zones are filled shapes, not squares.** A stockpile and the camp are each a see-through fill with a line
   round the edge. The per-cell squares are gone; what lies in a stockpile lies turned the way its lot is.
2. **A stockpile lies along its path, at any angle.** Two corners as before, but the lot turns to the nearest
   path and is drawn out to the path's edge. While the second corner is chosen the tool shows the lot exactly
   as it would be taken; where it would be refused it shows the outline in red, and the click says why.
3. **A lot stops at a path.** Drawn across one, it keeps to the side the first corner was on.
4. **A path cannot be drawn through a zone.** The note says "a zone is in the way: paths go round zones", and
   the line carries on from where it had got to.
5. **The camp is not there when it is zoned.** The band walks over and builds it: they tread the ground round
   the fire's place to bare earth and cut the grass on the rest, bring ten stones and three pieces of wood, and
   then the ring, the crossbar and the pot appear. On the reference site that takes about two and a quarter
   game hours, before anyone goes about its job: the first day starts later, all six are hungry by one in the
   afternoon, and the first stew is cooked that evening.
6. **The patch of bare earth round the fire stays.**
7. **The seats come early**: as soon as there are logs in the stockpile the cook and the forester lay them,
   before anything else of their own.
8. **The fire lasts.** A log burns eight game hours. Through its last hour the flames sink; then it glows and
   dwindles for three more, and the camp's sheet says "dying down, 2.1 h left to restoke it". The cook puts a
   log on when it is wanted (you will see "stoking the fire"). It burns about half the wood it did.
9. **Zones do not glow at night** (a fill is drawn at a fifth of its colour in the dark); the one under the
   cursor still lights up.
10. **A camp too near a path is refused** (3 m from the fire), and one whose square comes within a metre of a
    path turns to lie along it.
11. Old saves load: their camp stands as it stood.

## His calls (what I decided that he may want otherwise)
- **Day one.** The whole band builds the camp before working (the unassigned too). It costs the first morning.
- **Who carries wood.** Logs for the crossbar and the seats are carried from the stockpile only by the cook
  and a forester (the decision of 2026-11-08, "no idle hands hauling", kept). Everyone else, porters excepted,
  brings deadwood for the crossbar when there are no logs. With everyone carrying seat logs they were laid in
  139 game minutes on the check's meadow; with the cook alone, 253. One line changes it (`Carries_Logs`).
- **Who builds at all.** The unassigned tread ground, prise stone and pick up deadwood for the camp. That is
  idle hands working, though not hauling for another's job.
- **Grass in a stockpile.** Only the places where things are put have their grass cut; the rest of a zone's
  ground (the strip drawn out to the path, a place left out for a bush) keeps its grass. I chose that so that
  old lots give exactly the old colony (cutting it moved the reference logs), not for the look.
- **No boulder, no camp.** A site with no boulder within 60 m of the stake never gets its ring of stones, so
  never a hearth. The camp's sheet says "Short of 10 stone". Nothing else can stand in for stone yet.
- **Eight hours is a log**, not a stoking: two logs on the fire are sixteen hours.
- **Lighting a cold fire costs nothing more** than stoking one on its embers. The die-down is when the cook is
  prompted to restoke, the embers warm the sleepers, and the fire is seen to sink; it has no other effect.
- **The fire's look.** The flames now sink through the last hour of a burning fire (to 45 %), where they sank
  in its last quarter hour (to 30 %): a change to a look he had accepted, made so the die-down follows on.
- **A lot is taken within a metre of a path's edge** (it was half a metre: a metre of its middle).
- **A zone cannot be removed or reshaped**, as before.

## Rules as built (first values, his to tune)
Zones (`docs/systems/colony.md`, "Zones"):
1. A zone is the ground it fills, kept block column by block column. No block column is in two zones, or in a
   zone and a path.
2. Fill: every free block column of its lot that can be reached from where it was begun without crossing a
   path, a zone, a ledge higher than half a metre, or anything standing (it flows round a tree).
3. Snap: the lot is a rectangle turned to the path nearest the line between its corners; a side within a
   metre of a path's edge, and facing it, is drawn out to the edge.
4. Terminate: ground a path lies on is never zoned; a lot across a path keeps to the first corner's side.
5. Storage places are 1 m square, in rows along the lot. A place partly off the lot's ground, on anything
   standing, or more than half a metre off level is left out.
6. A path whose line runs through a zone is refused whole; one that brushes a zone leaves the zone its ground.
7. The camp is a zone like the rest: its 7 m square, turned to a path within a metre of it, refused with a
   path or a zone within 3 m of the fire.

The fire (`docs/systems/needs.md`, "The fire"):
8. A log burns 8 hours; then 3 hours of dying down, in which a log put on takes at once; then it is out.
9. Nothing goes on the fire by itself. The cook stokes it when it is wanted and low: enough for a pot; enough
   for the night, from two hours before bedtime; in winter as soon as it begins to die down.
10. A fire dying down still warms those asleep round it. It does not cook.
11. With no logs the cook picks up sticks (an hour and a half), for cooking only, as before.

The camp (`docs/systems/needs.md`, "Building it"):
12. Zoning marks it. Anyone with empty hands and nothing more pressing builds before its job.
13. The ground: a square metre at a time (4 s), from the fire outward; what grows on the camp is cut, and the
    turf within 2.6 m of the fire trodden to bare earth.
14. Ten stones: from the stockpile, else prised off the nearest boulder by whoever goes.
15. Three pieces of wood: logs by the cook or a forester, else deadwood from under a tree; never a porter.
16. Ground, stone and wood together and the hearth stands, the pot with it.
17. The seats: laid by the cook and a forester as soon as there are logs, before their own work.
18. What the building still takes is asked of the stores too (the camp's rows of the demand table).

## Built
- **A zone's ground** (d4303d2): strips of block columns on the zone record (`Zone_Run_At`), one lookup of
  whose a block column is (`Zone_Of_Block`; `Zone_On`, `Zone_Top`, `On_Path`), one routine that lays out a lot
  (`Plan_Lot`: the fill, the snap, the places), and plans that change nothing (`Plan_Stockpile`, `Plan_Camp`)
  for the tools to show. `Castle.Zone_Marks` draws a zone or a plan as marks; a mark of the ground dims at
  night (`Castle.Marks.Strip (..., Of_Ground => True)`, `Marks_By_Night`). `Lay_Path` refuses a line through a
  zone (`Path_Refusal`); `Stockpile_Refusal` and `Camp_Refusal` say why a lot was not taken. The camp's seats,
  beds and firewood turn with it (`Camp_Turn`).
- **The fire** (1707752): `Ember_H` beside `Fuel_H`; `Fire_Wants`, `Tend_By_Hand`, `Go_Stoke`, the `Stoking`
  state, `Feed_Fire`; `Camp_State.Dying`, `.Ember_H`, `.Heat`; `Castle.Fire.Show (..., Dying)`.
- **The camp built** (95d4a4a, 03ece9c): `Built` and `Got` on the zone record against `Build_Takes`;
  `Think_Build` (before anyone's job), `Step_Build` (`To_Patch`, `Tamping`), `For_Ring` and `For_Frame` loads
  through the camp's own carrying states; `Site_Work` (a `Work_Kind`, teaching building); the hearth's rows in
  `Build_Rows`; `Build_Camp_Now`.
- **The switch**: `Set_Camp_Labour (False)` / `--instant-camp` is the camp as it was (it stands when zoned,
  its fire feeds itself, four hours a log). The older sections of colony_check and the three older reference
  logs run with it.

## Measured (seed 1, the reference setup, colony_run; and the check's meadow)
- `tools/reference_check.sh`, four runs of 41 game days, each line for line against its kept log: everything
  on (reference_run_camp_zones.txt, new), `--instant-camp` (stage 5c's), `--instant-camp --no-demand` (5b's),
  `--instant-camp --no-demand --no-skills` (5a's). The zone change alone left all three older logs as they
  were with no switch: a stockpile on whole metres beside a path that runs east gets the 48 places it always
  got, in the same order.
- The run with everything on gives the same state hash with any number of workers (6861dbb3be6d2af4).
- Building the camp. Meadow, six with nothing stored: the ground ready in 56 game minutes, the stone by 88,
  the deadwood by 102, built at 103. Reference site: 64 square metres of long grass on the camp, the ground
  ready in an hour and three quarters, built two and a quarter hours after the start; nothing cooked till
  evening (1,117 points by eight), all six hungry at one, the hungriest at 9 % at eight in the evening.
- The fire. 2 to 3 logs a day outside winter (2.3 on average over 25 days; it was 4), 3 a day in winter (it
  was 6); nobody cold at midnight on any winter night until the band is starving at the winter's end (the
  cook among the dying, and nobody else stokes).
- The first winter moved, as it will with anything: three of six die in its last days in this run, where
  four did in stage 5c's. Not tuned.
- Laying out a lot (release, the check's meadow): 0.24 ms for 14 x 14 m, 0.8 ms for 38 x 37 m, 0.07 ms for
  the camp. The tools plan one every frame while a lot is being chosen.

## Saves
Colony blob 14: after the demand chain's section, each zone's turn and strips; the camp's labour (a byte) and
the fire's dying down (f32); for each zone whether what is built on it stands, how many kinds, and what has
been delivered of each (u16); each member's patch (u16). A blob before 14 loads with a zone's ground made from
the square metre under each of its cells and the camp's square (whether or not a path runs over them), the
camp standing, the camp's labour on and what was on its fire burning on.

## Options
`--instant-camp` (the camp as it was), `--camp-built` (the camp built on the spot), `--stoke HOURS` (builds it
too). `path refused: ...` and `stockpile refused: ...` say why in the log. The food line of `--log-hours` ends
with "camp to build: ground N, stone N, wood N" while the camp is being built.

## Bugs found and fixed
- (Mine, in this work, in no build John has had.) A cook at a camp not yet built took a log for the night's
  fire, found nothing to put it on, carried it back, and did so all night; and took a seat log and stored it
  again. Found by review, not by a check; colony_check now runs the no-stone camp with logs stored through a
  night.
- (Mine.) A zone filled in glowed at night, being drawn unlit.
- Loading zones from a blob did not clear a zone record's other fields first (harmless until this work gave
  it more).

## Known limits
- A zone's ground does not follow the ground if it is dug; a zone cannot be removed or reshaped.
- A lot is a rectangle. A path that bends away from one leaves the far end of the lot short of the path.
- On a path at an angle a zone's edge is stepped, a block column at a time, as the path's own edge is.
- The camp's hearth needs a boulder within reach of the stake.
- Wild grain two blocks tall on a storage place has only its lower block cut (as before this work).
- The older demo scripts (`demo_stage5a.sh`, `demo_stage5b.sh`, `demo_shadows_fire.sh`) now ask for
  `--camp-built`, and their fires are the eight-hour fire: they no longer reproduce their videos frame for
  frame.
- Driven only by a scripted pointer: the stockpile tool's preview and the camp tool's (taken, and refused in
  red beside a path), a path refused through a zone and the line carrying on. The real mouse (a drag, the
  wheel, Esc mid-line) was not exercised.
- Looked at in stills and recordings only: zones by day, in rain, at night, at the default view (the eye 70 m
  off, 1600 x 900); the camp being built; the fire burning out and dying down at night.

## Not done
- Building anything on a stockpile (his "storehouse, warehouse, fences ... coverings"): the zone record and
  `Build_Takes` are ready for it, nothing uses them but the camp.
- Un-zoning. A cost to lighting a cold fire. Anyone but the cook tending the fire.

## Next
- John's answer, then the merge (above).
- Stage 6, habitation. A hovel's lot is one more `Zone_Kind` laid out by `Plan_Lot`, its building a row of
  `Build_Takes` and a `Think_Build` of its own; its hearth is the first second fire.
