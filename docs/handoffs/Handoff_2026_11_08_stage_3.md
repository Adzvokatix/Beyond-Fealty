# Castle Game handoff (2026-11-08: stage 3, deer and the hunter; done in Claude Code in the terminal)

- Code: castle_game_stage3.zip (git archive of the terminal repo, commit 876ae4c; no bin/obj; builds
  clean from scratch). The working copy is still CASTLE_GAME/GAME_alpha_1_3/compiled (git, main).
  castle_game_stage2.zip, castle_game_latest.zip and GAME_alpha_1_3/source are untouched.
- Build and checks as before (gprbuild -P castle.gpr -XCASTLE_MODE=debug|release). All eight pass in debug,
  from a clean unzip of the zip: water_sim_check, edit_check, ui_check, dynamics_check, serf_check,
  path_check, colony_check, and the new deer_check (~1 s). Still exactly the 6 known warnings (unused
  formals in water_sim_check).
- README is current (Deer, Herds, the colony's hunting, standing orders, saves, options, checks).
  CLAUDE.md holds the agreed rules below for future sessions.
- Demo: colony_stage3_hunt.mp4 (63 s): one hunter goes out, stalks, shoots, carries the doe home across
  its shoulders and butchers it at the stockpile. Recorded with
  `--float --size 960 540 --view 60 --novsync --at 1178 1078 --cam 4.07 0.4 7 --follow --hud none
  --stake 1178 1078 --path 1176 1076 1194 1076 --stockpile 1180 1073 1186 1075 --hunters 1 --speed 2
  --record DIR 3000` (it ends "1 killed with 2 arrows, 8 meat, 1 hides stored", the same every run).

## Rules agreed with John on 2026-11-08
- Herds have two layers. A central node joins the deer of a herd: it decides the herd's direction of
  travel and plans its routes. Each deer wanders at random round the node. When the herd is hunted (an
  arrow loosed at it), the node moves away from the hunter and the deer scatter; once the panic wears
  off they settle round the node again.
- The hunter's starting weapon is the short bow. The sling is gone (removed from the design docs too).
- Defaults proposed for the rest and kept: hunting only while meat is short of its reserve; a herd is
  never hunted below three; a Spare deer order; carcasses carried home whole and butchered at the
  stockpile.

## Deer (Castle.Deer, Castle.Animals)
- Four classes (fawn, doe, young stag with spikes, stag with branched antlers), each in a red-brown summer
  and a grey-brown winter coat. Built like serfs: boxes on the 5 cm grid with a painted skin, hung on the
  same fifteen bones (pelvis = hindquarters, chest = forequarters, head = neck and head, arms = forelegs,
  legs = hind legs). One look per class and coat, shared (texture layers are shared with the serfs).
  Castle.Bodies.Pack_Nets is now shared by both.
- Castle.Animals is the four-legged stepper. It is locked to the gait's phase: a hoof stays planted until
  its turn in the footfall, then swings to land half a stance ahead of its hip. Walk under 1.7 m/s (three
  hooves down), trot under 3.4 m/s (diagonal pairs), bound above (all four in the air between strides).
  The body is lowered only as far as the planted hooves need, never below 85 % of standing, both ends
  together. Heads up and turning when alert, down in the grass when grazing.
- deer_check: every class and coat builds and fits; IK reaches; no planted hoof slides; footfall order;
  pairs; suspension; the same stride at 30 and 120 fps; the back within 15 degrees of level.

## Herds (Castle.Herds, stepped on the colony's clock)
- Two herds are placed when a colony is founded (once its ground is in), on walkable ground 30 to 55 m
  from the stake: a stag or a young stag, does, a fawn.
- The node grazes a few minutes, then plans a route (Castle.Nav) to a spot 15 to 30 m off and walks it.
  It stays 32 to 70 m from the stake. Only the node plans routes.
- Each deer keeps to a spot of its own 2 to 7 m from the node (fawns 1 to 3 m), picked afresh now and
  then. It steps over the walking map locally (up at most a step, down at most a metre, only water it can
  wade) and never comes within 22 m of the stake.
- Fear: someone walking within 15 m, a hunter stalking within 7 m, or an arrow. The node flees about 30 m
  straight away from the danger. Each deer bounds off on its own heading for 3 to 6 s, then trots back to
  the node wherever it has got to.
- Fawns: each spring, a 0.6 chance for each grown doe, up to 10 in a herd. Growing up: a fawn becomes a
  doe or a young stag at a year, a young stag becomes a stag at two (a game year is 60 days).

## Hunting (Castle.Colony)
- When: meat is short of its reserve (20 by default, counting carcasses on their way) and Spare deer is
  off. The hunter goes for the nearest grown deer of a herd larger than three.
- Approach: it walks until 30 m off, then stalks crouched toward a spot 15 m from the deer, planning again
  as the herd drifts. A hunter stalking, aiming or recovering counts as stalking for the deer's fear. After
  90 s without a shot (walls, water) it leaves that herd for five minutes.
- Shot: within 18 m, with a clear line (blocks and leaves stop an arrow). It draws the short bow for 1.5 s
  and looses. The hit is decided then: clamp (0.95 - 0.03 x metres, 0.25, 0.85). Hit or miss, the herd
  bolts. Arrows are drawn in flight and stuck in the ground but are not saved.
- After a hit: the kill lies where it fell. The hunter carries it home across its shoulders and butchers
  it at the stockpile for 10 s, into cells reserved first. Meat by class: fawn 3, doe 8, young stag 6,
  stag 10, and one hide.
- Drawn: a sneaking walk, the aiming pose (bow upright in the off hand, the string drawn to the cheek),
  a deer lying or carried, joints and hides on the stockpile, arrows.

## Standing orders (band panel)
- A third line: Spare deer (off by default), then the meat reserve in steps of 10 (20 by default), shown
  as had / reserve.

## Saves
- Game save format unchanged (5). Generator_Version unchanged (9).
- Colony blob version 6:
  - 5 adds the herds (Castle.Herds' own blob, with its own version 1): nodes, routes, every deer's place,
    spot, panic and age.
  - 6 adds the hunt: each hunter's prey, the carcasses (lying or carried), the meat reserve, Spare deer,
    kills and shots.
  - Older blobs still load. A colony from before 5 gets its herds placed once its ground is in.
- colony_check: save, load, save gives the same bytes mid-panic and mid-hunt, and the colony carries on
  exactly.

## Options (game)
- --deer N, --deer-walk X0 Y0 X1 Y1 SPEED, --follow-deer (looking at deer and gaits).
- --hunters N (after gatherers, foresters, porters), --reserve meat N, --spare-deer.
- The "colony:" log line also counts deer, herds, kills, arrows, meat and hides. While the colony waits
  for its ground, the line says how many stacks it is waiting on.

## Bugs found and fixed on the way
- No herds in the game: they were founded before the stake's position was set.
- Gait: long hovering swings (swing time now capped), the body sinking to hooves out of reach (only
  planted hooves count), rearing in the bound (85 % floor, both ends drop together), trot pairs drifting
  out of step (lifting locked to the phase).
- Hunters spooked their own prey while aiming (aiming now counts as stalking).
- Chains of panics set off by the band going about its work (nodes 32 m and deer 22 m from the stake).
- A hunter looping on a herd it could never shoot (the herd is now left five minutes; replanning
  throttled).
- The bow pointed along the arm at the deer when drawn, so it couldn't be seen from the front, and after
  the loose the arms reached toward the deer for a moment. Found on the close-out video and fixed: a
  wrist turn (Castle.Poses Grip), and the work pose now fades out of the last work motion.

## Stage 2 open items, now closed
- The intermittent "colony starts late or never" stall: stray keystrokes reaching a focused test window
  on the desktop (Space pauses the colony). Scripted runs (--frames, --record) now ignore the keyboard and
  mouse (Castle.Input.Ignore). 8 of 8 runs were the same afterwards.
- Hunters have work.

## Known limits
- Arrows aren't saved. There is no supply of arrows, and spent ones aren't picked up.
- Meat and hides pile up with no use until stage 4 (hunger) and a tanner. Meat doesn't spoil.
- Deer don't die of age and there are no predators. Herds don't split or merge, and no new herds come in:
  a herd hunted down to three waits for spring.
- Not there yet on deer: the tail's flag when alarmed, ears turning, lying down.
- Hunters, like everyone, work through the night.
- The bow tilts with the forearm when drawn (it is held square to the arm, as upright as that allows).

## Next: stage 4, food and needs (medium), per the production plan
Hunger and eating from the stockpile give berries and meat a use. Then sleep, the campfire with the best
cook cooking, wild grain and vegetables, apples in autumn, and the first winter.
