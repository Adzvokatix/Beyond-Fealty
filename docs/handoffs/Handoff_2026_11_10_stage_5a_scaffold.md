# Castle Game handoff (2026-11-10: stage 5a, the scaffold; Claude Code)

- Code: GAME_alpha_1_3/compiled, branch stage-5a from main at 892a63a (tag pre-stage-5a), fast-forwarded
  into main at the close (`git reset --hard pre-stage-5a` on main is the way back). A commit a feature.
  Zip: CASTLE_GAME/releases/castle_game_stage5a.zip, a git archive of the branch's last commit.
- Checks: all nine pass in debug, from a clean unzip of the zip too (pick_check is new); six known
  warnings, none new. ui_check 59 checks (was 27), colony_check 206 (was 151), pick_check 31.
- Versions: Generator_Version 11 and save format 5, unchanged. Colony blob 11: the zones (kind, borders,
  cell count), the zone of every stockpile cell, the camp's zone, each member's director.

## Rules agreed with John (2026-11-10)
The brief's five, as written:
1. A right click on the ground opens a context menu (zone here, path from here) instead of ending a
   path line; a line is ended from the menu or with Esc.
2. In the development view the tooltip shows everything in a person's view, moods included; the view
   marks which fields the player's character could know.
3. One stockpile zoning is one zone; two that touch stay two.
4. Deer are pickable and get a tooltip (class, herd size, calm or alarmed) but no actions yet.
5. The development panels stay on Tab and the F-keys; nothing of the game's interface depends on them.

## Built
- **Zones as things** (Castle.Colony). A zone record: kind (Stockpile_Zone, Camp_Zone), borders, the cells
  it owns. One Zone_Stockpile call is one zone; the camp is one. Zone_At gathers what is inside: what it
  holds by kind, what is coming and going (the reservations that were already there), cells in use, the
  living inside its borders. Zone_On (X, Y) gives the zone of a point of ground. Nothing reads zones to
  decide anything: cells are found and filled as before.
- **Who directs whom.** Castle.Colony.Actor (the player, no one, or a member); each member's director is
  whoever gave it its job. Set_Job (I, J, By). Nothing reads it yet.
- **The action table** (Castle.Actions). Ten rows: raise the stake, lay a path, zone a stockpile, zone
  the camp, give a job, follow, set a reserve, set the winter store, spare apples, spare deer; each with
  what it is done to and the lowest rank that may. One door, Perform (Order), returning done, a count and
  why not (not permitted; no such target; not now; the ground refused, in words). Menu_For (actor, thing)
  is the context menu's contents. The panels, the menus, the game's clicks and Castle.Scenario all go
  through Perform; none calls a colony setter.
- **Data views** (Castle.Views). A person, a zone or a deer as a sheet: title, note, named rows with a
  value, a tone, perhaps a bar, and whether the player's character could know it. Known_Only is for the
  game's own tooltips later. Castle.Colony.Person and Zone_At are the typed data underneath.
- **Picking** (Castle.Pick, Castle.Rays). The block walk is a generic (the game's world and the check's
  are walked by the same code); a hit carries its distance. Look: a person or a deer in front of the
  ground (capsules, as drawn; never behind a wall), else a zone by its goods or its ground, else the
  block; nothing beyond Reach (no limit from above; Reach_M 6 m named for stage 7); six pixels of slack;
  whoever was pointed at a moment ago is kept while the ray is still on them.
- **Widgets** (Castle.UI): tabs, scroll lists (wheel, a bar that takes clicks and drags, whole rows),
  tooltips (0.3 s, by the cursor, never off the screen, no clicks), popups (over everything, nothing
  pressed through them), Beside, Pointer. Begin_Frame is told the wheel, the held button and the seconds.
- **In the game** (Castle.HUD, game/castle_game.adb). A tooltip on what the cursor rests on; a context
  menu on a right click (a person: jobs and follow; a stockpile: reserves and the winter store; the
  ground: stake, path, stockpile, camp, and to-here or end for a line half drawn). Esc cancels before it
  quits. A click away from a menu closes it and digs nothing; a click on a person digs nothing. A note at
  the foot of the screen says what an order came to. The thing pointed at is ringed or outlined.
- **The band panel**: food and confidence, then tabs. Band: a scroll list (name: follow; job: its menu;
  status; a line's tooltip is the person's). Stores and Camp show the same sheets the tooltips show;
  Orders lays out the same choices the menus do.
- **A scripted pointer** (`--pointer`): move, rel, member, deer, ground, click, rclick, wheel, esc at
  given frames; an arrow drawn where it is. `--hud noband`, `--hud stores|camp|orders`.

## Changed from the brief
- A director is whoever gave the job, so the unassigned and the cook who chose itself have none; the
  brief had every member of an older save directed by the player. Older blobs load the same way (a job:
  the player's; none: nobody's). **For John to confirm**; it is an open decision in the framework.
- The action table and the views are packages of their own (Castle.Actions, Castle.Views), not children
  of the colony; Castle.Rays was added. The table has rows for the winter store and the protections too.
- Added: the note line, the scripted pointer, keeping the pointed-at person in a crowd.
- The camp and a deer have no menu (nothing to do to them yet); a right click on the camp's ground gives
  the ground's menu.

## Measured (seed 1, the reference setup, colony_run)
- No behaviour changed. With the blob written in the version 10 layout, the reference runs give the
  states they gave before the stage: 3 days 384f3e0921552152, 41 days (--winter-store 10 --reserve meat
  60) 62d6f6a8b154dc57. Proved after the zones and directors went in, again after the scripted setup
  went through the action table, and again after the naming fix.
- The states now (blob 11): 3 days 9609e60367c60fff (138,497 bytes; the same in debug and with 3
  workers); 41 days d3f9abae3bb7efce (139,295 bytes).
- docs/production/reference_runs/reference_run_stage5a.txt is line for line stage 4's log, but for the
  state hash.

## Saves
- Blob 11 appends: zone count; each zone's kind, two corners and cell count; each cell's zone; the camp's
  zone; each member's director (a byte: 0 the player, 1 no one, then the members).
- Before 11: a stockpile zone for each group of cells that touch side to side, in the order of each
  group's first cell (two zonings that touched load as one: how they were zoned is not known any more),
  then the camp's; a job means the player gave it.
- tools/colony_v10.bin is a version 10 blob written by the old code on the check's meadow (three
  stockpile zonings, two of them touching, a camp, a gatherer mid-carry). colony_check loads it and the
  version 7 one.

## Options
- `--pointer "FRAME:COMMAND, ..."`, `--hud noband`, `--hud stores|camp|orders` (the game).
- Nothing new in colony_run. `--reserve` still takes straw or meat only.

## Bugs found and fixed
- A band of sixteen had two of one name: a name moved on from a clash could land on one already passed.
  Each now takes the next free name of its twenty. Bands with no such clash, the reference band among
  them, are named as before.
- The wheel over a panel also zoomed the camera. It is the panel's now (a list scrolls).

## Known limits
- **Nothing here was tried with a real mouse.** Every tooltip, menu, tab and scroll was checked through
  ui_check, pick_check and the scripted pointer (screenshots and the demo). The real-input path
  (Castle.Input: a right click as the button let go without a drag, the left button held on a scroll
  bar, the wheel and a touchpad's part-steps over a list, Esc) has not been run by hand. John to try.
- Reach is unlimited (the view is from above); Castle.Pick.Reach_M is checked but unused in the game.
- Tooltips show everything (the development view); Known_Only is checked but unused in the game.
- A zone's borders are the box round its cells: for an L of cells (an older save's group) the outline
  drawn when it is pointed at covers ground that is not its own. Picking goes by cells, so it is right.
- A menu opens where it was clicked and stays there while its person walks on.
- The scroll list scrolls by whole rows; there is no clipping in the UI layer.
- The band panel is wide (300 px at scale 1) and at 1280 x 720 shows 11 rows, not 12.
- Reserves are the colony's: every stockpile's menu sets the same numbers.
- Two interfaces' worth of state lives in Castle.HUD (the open menu) and its Tool_State.

## Not done
- Draggable windows and text input (out of scope). Menus for the camp and for deer. The game's own
  interface proper (a reticle, reach, Known_Only): stage 7.
- The upload to the Project is John's step (/send-to-project).

## Next
- Stage 5b, skills: proficiency, aptitude, skill by use, job tiers; the placeholder Cooking_Of becomes a
  skill. A skill is a row added to the person's sheet (Castle.Views.Person): the tooltip and the list
  show it with no new code. Work rate becomes condition x skill x direction (the hook the framework
  lists), and the short work times get names.
- Then 5c, the demand chain: a zone's Coming and Going become its demand rows; Set_Reserve is already the
  action that sets a required surplus.
