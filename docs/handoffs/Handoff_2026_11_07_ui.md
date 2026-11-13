# Castle Game handoff (2026-11-07: UI, water sheet, people, routes, aquifer, colony stage 1)

- Ada 2022 + OpenGL 4.5. World 2048 m square, 0.25 m blocks. Code: castle_game_latest.zip (git archive of
  the session repo; no bin/obj; builds clean from scratch).
- Build: gprbuild -P castle.gpr -XCASTLE_MODE=debug (or release). Debug -> bin/debug/, release -> bin/.
  Ubuntu 24.04 toolchain: apt install gnat gprbuild libglfw3-dev libgl1-mesa-dev xvfb (GNAT 13.3).
- Checks (run in debug): water_sim_check (~2 min), edit_check, ui_check (27), dynamics_check (18),
  serf_check (~8 s), path_check (~40 s with seed-1 terrain; --real 0 skips it), colony_check (~1 min).
  All pass.
- README is current: live water, UI, People, Routes, Colony sections; layout; keys; build/test options.
- Plan: claude/production-plan.md (stages 0-6; 0 and 1 done; stage 2 forester + porter is next).

## Colony, stage 1 (done): the berry loop
- Castle.Colony owns the colony; Castle.Serfs only draws it. Fixed clock: 20 ticks per colony second.
  The game passes one step per frame (frame time clamped to 0.1 s, a 30th of a second in --record) times
  the speed (Space pauses; 1/2/3; status-panel buttons) to the sky clock, the colony and the serfs alike.
  (Before: the sky used real frame time and ran 3x ahead of the colony in slow recordings.)
- Tools panel: Homestake (once; a 1.75 m log post, band of 6 with one elder, all unassigned), then Path
  (click along; 1 m footpath from the last click, grass/grain cut; right click ends) and Stockpile (two
  corners; 1 m cells; must come within 1 m of a path; Clear_Cell cuts grass/grain on each cell and leaves
  out cells with a bush, a log (stump, trunk, the stake) or > 0.5 m off level).
- Band panel (Tab), top right under the tools: stockpile total; per member a name button (follow), job
  buttons Idle / Gath / Wood / Hunt / Port and a status line. Only gatherers work yet.
- Gatherer: lowest (distance to it + 0.5 x distance to the stake) ripe bush within 60 m of the stake,
  reserved; Castle.Nav route; a handful per 1.5 s (the ripe block nearest the hands -> Bare_Bush, through
  the game's edit path); basket of 30; to the nearest stockpile cell with room (room reserved); puts down
  standing at the cell's edge (Walk stops within 0.55 m). Fail memo 60 s. Reasons: nothing ripe in reach,
  nowhere to put berries, can't get there. Regrow 6 game days, never in winter.
- The colony's ground: stacks within Colony_R = 60/8 + 3 = 10 stacks (80 m) of the stake's are requested
  and never unloaded while there is a colony; the colony doesn't advance until all of them are loaded
  (Colony_Ground_Ready), so nothing is misread for want of blocks. The main draw skips stacks wholly
  past Fog_Distance from the focus (they'd be all haze). Pan test: camera 400 m away, the colony still
  stores berries; draws 147 = the no-colony baseline.
- Drawn: picking pose (face the bush, hands circling), put-down pose (bend, reach), baskets on stockpile
  cells (Castle.Props, one per 30 handfuls, max 4 per cell), stockpile outlines (Castle.Marks), F6 routes.
- Saves: format 5 adds a colony blob (Castle.Colony.Save/Load, its own Save_Version 1): members incl.
  routes, jobs, loads, reservations, fail memo, bushes, paths, cells. Game logs "colony: ..." at every
  save and load; a load reproduces the saved line exactly. --save also fires at the end of --record.
- Bugs found in the game and fixed: Arctan (0, 0) when a storer stood exactly on its spot (now
  Castle.Math.Heading_Of with a fallback, used in Serfs and the lineup); baskets hidden inside tall grass
  (Clear_Cell); the sky clock ahead of the colony in recordings; far colony stacks drawn though all haze.
  --frames with a colony no longer waits for remeshes before its shot (the band edits all the time).
  Headless note: under llvmpipe a frame takes 0.2-0.7 s, so --frames N runs take minutes.
- Options: --stake X Y, --path X0 Y0 X1 Y1 (<= 16), --stockpile X0 Y0 X1 Y1 (<= 8), --gatherers N,
  --band N, --speed N. Demo: colony_stage1_berries.mp4 (1500 frames at 3x, camera --at 1179 1072.5
  --cam 2.5 0.8 15; 180 berries stored in 150 s of colony time).
- Held back on purpose (agreed with John): hunger, the player's own character, standing orders.
- Known limits: work within 60 m of the stake only; serfs work through the night (sleep comes with
  needs); one kind per cell; nothing lies loose on the ground; the shadow map redraws on any mesh change
  (now more frequent, the band edits bushes) - fine on a real GPU, slow under llvmpipe.

## Aquifer (stage 0, done; Generator_Version 9, older saves refused)
- No Aquifer blocks: wet strata are their own rock. Geology.Water_Bearing + Needs_Shoring (Wet) keep
  the field's meaning. F8 / --wellmap: aquifer heat map. Material slot reused for Bare_Bush.

## Routes (done)
- Castle.Nav: 0.5 m cells, up to 4 floors each (from World_Blocks column stretches + blocks); steps up
  <= 0.5 m, down <= 1 m; cost is travel time (footpath/plank 1.15 ... bog 0.6; brush and wading slow);
  A* (2^20 hash, binary heap, 300k budget), two-pass string pulling; routes carry stack-version stamps,
  re-planned when the ground under them changes. F6 routes, F7 walking map. path_check: synthetic cases +
  seed-1 timing (mean 3.3 ms, max 33 ms per route in release).
- Known limits: an unreachable goal floods all that is reachable (region labels would fix); no coarse
  graph for long routes; snow doesn't slow; ladders, doors, swimming, crowding.

## People (done)
- Castle.Second_Order filters; Castle.Bodies (5 cm body pixel, genome + outfit -> rig, boxes, 128 x 64
  skin); Castle.Poses (two-bone IK); Castle.Figures + render (one draw for all boxes); Castle.Serfs
  (kkrieger-style stepper; now also driven by the colony: Spawn_Driven / Drive / Restyle / Clear).
- The forester's axe: held at the END of the haft, head down by the shin, turned so the bit faces BACK
  (John's "axe2": the blade's edge in line with the arm's swing).

## Water sheet, UI (done)
- One joined water surface sheet (Generator_Version 8 change). Castle.Font / UI / HUD: immediate-mode
  panels in one draw; not yet: text input, scroll lists, drag, tooltips, rebinding.

## Next: stage 2, forester and porter
- Chop (two-handed swing, the axe as built); trees come down through the edit path (trunk and crown
  removed, stump left, logs dropped); logs on the shoulder; Wood in stockpiles.
- Porters: stone from surface rock, water in buckets, straw from tall grass; idle hands haul.
- Standing orders arrive here (reserve levels, protections).
