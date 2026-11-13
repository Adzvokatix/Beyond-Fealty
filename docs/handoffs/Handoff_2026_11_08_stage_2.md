# Castle Game handoff (2026-11-08: stage 2, forester and porter; done in Claude Code in the terminal)

- Code: castle_game_stage2.zip (git archive of the terminal repo, commit b7a4c4b; no bin/obj;
  builds clean from scratch). The working copy is CASTLE_GAME/GAME_alpha_1_3/compiled, now a git repo
  (main). GAME_alpha_1_3/source and castle_game_latest.zip are still alpha 1.3, untouched.
- Build and checks as before (gprbuild -P castle.gpr -XCASTLE_MODE=debug|release). All pass in debug:
  water_sim_check, edit_check, ui_check (27), dynamics_check, serf_check, path_check, colony_check
  (~2 s now). Still exactly the 6 known warnings (unused formals in water_sim_check).
- README is current (colony section: felling, logs, fetching, standing orders, saves; options; checks).
  CLAUDE.md in the repo holds the build/test notes and the agreed rules below for future sessions.

## Rules agreed with John on 2026-11-08 (they replace the first draft of stage 2)
- Porters never carry wood. Idle hands don't haul either.
- A forester carries every log of the tree it felled home before felling the next. The pile is that
  forester's own; no one else takes from it. (If its forester is given another job, the next forester
  to come for wood takes the pile over. A pile its forester can't reach is left a minute, so one out of
  reach can't stop the felling.)
- Porters fetch in a fixed order: straw first (for the thatched roofs) up to the straw reserve, then stone.
- Stone is fetched on demand, not to a reserve: Castle.Colony.Want (Stone, N) asks for more; a colony
  starts wanting Stone_Quota = 20 (paving the paths, once there are masons). Paving will ask with Want
  and take stone away as it uses it.
- No water fetching until something uses water and there are barrels. (The fetching code can find and
  draw water, two buckets where it can be waded; it is just not asked for. No buckets in stockpile cells.)

## Felling
- Trees come from the generator: the game hands the colony Flora.Tree_At and Flora.Tree_Blocks
  (Castle.Colony.Set_Trees); colony_check hands it a test source. Trees are found per stack as the colony
  looks through its ground; a tree whose first block above the stump is gone counts as down.
- Choice: the standing tree with the lowest (distance + 0.5 x distance from the stake), within 60 m of the
  stake, reserved; apple trees skipped while Spare apples is on.
- Chop: 12 s for a slim trunk, 24 s for a thick one; two-handed swing, wound up over the dominant shoulder,
  struck into the trunk at waist height, the bit held in the wood a moment (Castle.Serfs, Motion Chop).
- Fell: Flora.Tree_Blocks draws the tree alone into a scratch stack; every block of it above the stump that
  the world still holds as that material becomes air, through the edit path (saved like the player's
  edits). A stump one block tall stays, with the roots. Logs (1 to 8: a metre each, one per 2 m of trunk
  per block of trunk width) lie stacked a metre past the stump, along the way the tree fell.
- Logs: one at a time, fore and aft on the off shoulder beside the head, the off hand up on it; to the
  nearest cell holding wood with room, or an empty one (20 a cell, stacked in rows of four).

## Fetching (porters)
- Straw: tall grass cut a block at a time (0.8 s, 6 a load, 40 a cell), crouching to it. Drawn as sheaves.
- Stone: prised off boulders a block at a time (2 s, 4 a load, in the porter's sack, 40 a cell). The
  porter stands on the ground beside the rock (Stand_Beside), never on it. Only blocks that stand out of
  the ground on some side are taken: what is under the grass stays, so no pits.
- Each stack the colony looks through is noted for tall grass, boulders and shallow water; a search scans
  only noted stacks, nearest first, and clears a note when a stack has none left. A kind not found or not
  reachable is left a minute ("no straw in reach"); with nothing wanted: "the stocks are full".

## Standing orders (band panel, one line each)
- Spare apples (on by default); wood reserve in steps of 10 (no limit by default: once met, the
  foresters stop and say so); straw reserve in steps of 10 (20 by default); stone shown as had / wanted.

## Saves
- Game save format unchanged (5). The colony blob's own version is now 4: 2 trees, log piles, orders;
  3 porters' fetching, reserves, the stacks' source notes; 4 pile owners, what is wanted. Versions 1-3
  still load: a version 1 colony finds the trees of the stacks it had already looked through once its
  ground is in (tested by loading an alpha 1.3 save); before 4 piles are nobody's and the old stone
  reserve becomes the stone wanted. colony_check: save -> load -> save is byte-identical mid-felling and
  mid-fetch, and the colony carries on exactly.

## Options (game)
- --foresters N, --porters N (after --gatherers N), --wood-reserve N, --reserve straw N, --fell-apples.
- --float: a window that can't be resized, so Sway floats it at exactly --size (app id "castle" for
  window rules). Note for headless work on this machine (Garuda, Sway): GLFW 3.4+ goes to Wayland when
  WAYLAND_DISPLAY is set, so xvfb-run still opens a real window on the desktop; use --float, or
  env -u WAYLAND_DISPLAY xvfb-run for a hidden window (software GL, slow).
- The "colony:" log line now also gives trees felled, logs stored and lying, straw and stone stored.
- --record frames are uncompressed PNGs of the full framebuffer (~2.5 MB each): a few thousand fill /tmp.

## Bugs found and fixed on the way
- Water drawn through a wall (route allowed to end 1 m off; now 0.6 m, and only wadeable water is sought).
- A porter stuck retrying unreachable water every 4 s (a kind that can't be reached is now left a minute).
- Boulders mined below the grass, leaving pits (only blocks standing out of the ground are taken).
- Porters standing on low boulders and prising the block under their feet (now routed beside the rock).
- Version 1 colonies never finding trees after a load (stacks already looked through are searched once).
- The band panel growing off screen (orders compacted to one line each).

## Known limits
- Trees don't topple: the crown and trunk go at once. Trees, tall grass and boulders don't grow back.
- The shoulder load sits at a fixed offset from the shoulder joint (fine for adults; not tuned for children).
- Up to 1,024 figures a frame: past that, props (logs, sheaves, stones) are dropped, never people.
- Intermittent, cause not found: in ~25 headless loads of one stage-2 save (15k edits), the colony started
  very late twice and once not at all within 600 frames (its ground never all loaded); no worker errors
  were printed; 18 runs after that were all normal. Worth watching; Colony_Ground_Ready in castle_game.adb
  is where it waits.
- Hunters still have no work.

## Routes (after stage 2, from the nav review of Gemini's notes and the Desktop design talk)
- Inflated estimate: Castle.Nav.Heuristic_Weight = 1.15. Measured on seed 1 (200 routes up to 170 m):
  2.4x quicker searches (2.45 -> ~1.0 ms mean), routes 0.3 % slower on the whole and never more than 15 %.
  At 1.3 a footpath worth a short detour stops being taken, so it stays at 1.15.
- Pieces of ground: each stack's floors labelled into pieces (joined by a step either way), linked
  across stack edges, refreshed by version. Before a search they prove a goal out of reach when the
  start's or the goal's side is wholly known; the route then goes straight to the nearest reachable floor
  (the same partial route as before, without searching everything). A room with no door: known at once.
  A goal cut off by water: a full search the first time (it maps the ground), ~0.6 ms after (was 26 ms).
- Not taken from the review: uniform per-trip multipliers (they can't change which route is quickest;
  only terrain- or slope-dependent ones can), Tobler's function (0.25 m block steps make per-step slope
  meaningless; the seconds-per-metre climb model fits better), exact refraction at road edges (string
  pulling bends within a cell of it). Next for routes, when stage 3 needs it: a coarse graph over stacks
  (the pieces and their links are its start) with bridges and doors as waypoints.

## Next: stage 3, deer and the hunter (large), per the production plan.
