# Castle Game handoff (2026-11-11: falls thrown from the lip: water over a drop drawn as an arch standing off the wall, as a body standing off a slope; built on John's word with the acceptance of the sky and the pathing; accepted as built the same day and merged into `main`; Claude Code)

- **Closed: accepted as built.** John, after playing with it: "That is perfect, I built an aquaduct from the mountain lake to the valley, and got water to the village with ease and was able to build a dam and and run the water into it and build a small resevoir that filled and held next the village, and when the water started getting to the desired level I just cut the flow down and everything leveled out, great job. Everything flows and looks perfect now."
  Branch `falls` (from `main` at 8c1ace5, the commit that records his acceptance of the sky and the
  pathing work) is fast-forwarded into `main` and kept. Built with first values of mine: they stand as
  first values, his to tune. The calls below that he did not take up stand by default.
- **What he did with it** is his own test of the water as a whole, not only of the falls: water taken
  from the mountain lake down to the valley by reservoirs chained one below the other, each held back
  and let out to the next, a dam and a small reservoir beside the village that filled and held, and the
  flow cut down at the source when the level was where he wanted it. None of that was built or measured
  here; it is recorded in water.md beside his rules.
- **And a decision came with it**: that water has to be held back and handed down in stages "is what
  we want we don't want a players computer locking up becuase
  they cut a hole to the bottom of the lake and all the water started gushing into the valley, we could
  let the water travel farther faster later ... you made it so I can tweak the dials when we are ready
  for that". The dials are listed in water.md ("How far released water runs"); none was touched.
- **The session ends here**: "Clearing and setting up for stage 6". This file is where the next
  session starts ("Next", at the end).
- **It is a drawing.** The simulation is untouched: the water still runs down the face, a column a step.
  What changed is how water leaving a column over a drop is drawn. His water rules stand as he accepted
  them, `water_sim_check` passes as it was, nothing is saved, and the colony knows nothing of it.
- Code: GAME_alpha_1_3/compiled, branch `falls`: f4824f7 (the falls), 7726587 (three things found
  on review: his calls and "Bugs found" below), documents after.
  - Zip: CASTLE_GAME/releases/castle_game_falls.zip (a `git archive` of `main`, the closing commit:
    documents only after the code). Demo: falls.mp4
    (tools/demo_falls.sh), 28 s: two cuts out of the mountain lake, each as it was drawn and as it is.
    falls_before_after.png: four frames of it.
- Checks, from the branch's last commit that changes code: debug and release with the six known warnings
  and no other; all nine checks pass in debug (water_sim_check 77: `castle-water.adb` gained an accessor
  and nothing else); `tools/reference_check.sh` holds the seven logs, line for line; `tools/shadow_still.sh`
  reads 0.00 % by day and at dusk; the debug build's game ran a cut fall for 400 water ticks with nothing
  raised (and, one commit earlier, the band working in poured water for 1,500 frames).
- Looked at on: a cut 1 m and 3 m wide out of the mountain lake (1203 1374) onto the hillside as it lies
  (about 36 degrees), onto a stair of one in one cut under it, and onto a cliff 3 m high cut into the
  hillside; from the front, the side, behind and below; asleep with the flow established, after a save
  and a load, in frost, and with `--watersteps 0`; a generated stream at 1186 1466, at rest and woken by
  a cut in its bank. Not on his own cut: I do not have its place.
- Versions: **none moved.** `Generator_Version` 13, save format 6, colony blob 17.

## John's words (2026-11-11)
With the acceptance ("perfect, everything checks out, looks awesome and works great"), and three pictures
of a lake let out through a cut in a ridge and down a hillside into a pool held by a wall of planks: "I
just want to make one minor change to water ..., check thouse out, quite awesome, but look at the big hole
and the almost linear path the water is taking down, can we make it more of a arch, water rollong over
itself, and second can we have the water extend from the wall face so it doesn't become just streams down
the wall face, I think the arch flow dynamic would take care of that but if it doesn't."

How it was read: two things he wants to see (an arch; water standing off the face it comes down), and one
guess at how ("the arch flow dynamic"). The day before he had put that guess as a rule for the simulation
("you can simulate momentum and velocity by simply allowing the water to move further in relation to the
column of water moving forward": water.md, "Reach"), and it was not built because he accepted the water
without it. It was not built now either (his call 1): the arch is drawn from the simulated speed at the
lip, and the simulation is left alone.

## What John sees
1. **Water out of a cut onto a slope is a body of water**, a block or so proud of the slope, blue with
   white streaks running down it, its outline shifting as it goes. It was a film on each step with a
   white line at every riser: the "almost linear path" of his picture.
2. **Over a real drop it leaves the lip and arches into its pool**, standing clear of the wall: about a
   metre and a half out from a fall of three metres. It was a patchy curtain flat against the wall, and
   from the side nothing at all (a curtain has no thickness). The arch can be looked at from the side,
   from behind, and from below.
3. **In his own picture** the ground under the hole is a slope of about one in one, not a wall. I did
   not have his place, so a stair of one in one was cut under a slot 3 m wide at the mountain lake: there
   the water is a body standing off the stair from the mouth to the pool, rounded when it is seen from
   the side, and steady (over five seconds, 0.2 % of the picture of it changes from one frame to the
   next). It does not leave the slope in one free arch: that takes a real drop under the lip.
4. **A fall takes about a second to grow** when the water first comes over, and again after a load (the
   speed drawn is settled over that long, because the flow on a slope pulses).
5. Wherever running water goes down a step of a block, the step is rounded by a slab of it: small
   riffles down a terraced bed.
6. In frost a fall freezes with the water round it: an icefall, stepped.
7. Nothing else: still water, the lake dropping toward a cut, a stream's own generated fall and water
   in a tunnel are as they were.

## His calls (what I decided that he may want otherwise)
1. **Drawn, not simulated.** The water under the arch still goes down the face and reaches the pool at
   the wall's foot; the arch is where it is drawn. Making water land where it is thrown is "reach" in
   the simulation's step: the soak is counted by the column passed, so water thrown over ten columns
   would run further down every steep slope, and the rules of waking and the 77 checks go by
   neighbours. That is a change to what he accepted on 2026-11-10 ("all my tests achive the desired
   result"), so it is his to ask for; the drawing does not stand in its way.
2. **How strongly it is thrown**: at the simulated speed as it is (`Throw` 1), no slower than 0.6 m/s
   and no faster than 3. A cut a metre wide out of the lake has water leaving its lip at 1 to 2 m/s.
   `--throw 1.5` to see more.
3. **Every drop of three quarters of a block or more throws**, however little water there is (down to
   1 cm over the sill). So the slowest dribble stands a column off the wall, and every terrace edge
   under running water has its slab (what he sees, 5).
4. **Stepped, a slab a column**, as the water's surface is (his rule: "rippling by stepping the water
   instead of smoothing"), not a smooth curve.
5. **A body down to the ground where the sheet is near it** (within two blocks: `Join`), a free sheet
   with air under it where it is not.
6. **Under a sheet that falls free, water thinner than a block is not drawn** (it is the same water,
   on its way down the face). A pool a block deep or more under an arch is drawn.
7. **Generated falls are curtains still.** A stream's own fall has no simulated flow to throw. It
   could be thrown from the generated current the same way.
8. The look: `Fall_White` 0.16, `Fall_Streak` 0.46, `Fall_Alpha` 0.80; lit alike on every face.

## Built
- `Castle.Water.Outflows`: what leaves a column's open-sky water through each face, speed and depth
  over the sill (the simulation's flows, read and not changed); nothing between source water and source
  water, so a stream's own fall is drawn the same awake as asleep.
- `Castle.Falls` (src/castle-falls.*): `Follow` after each water tick settles the flows, flies a sheet
  from every face that qualifies (`Fly`: column by column against what lies under it), and says which
  stacks' sheets changed; `Air` is the value the renderer takes. Kept for stacks awake or asleep with
  their flow established; forgotten on a load. Tunables at the top of the spec.
- The renderer: `Surface_Texel.Air` (it was `Spare`); the second cell in the vertex shader (z = 1 of a
  surface cell's quad), the two rules for a column's own water under and beside a sheet; the sheet's
  shading in the fragment shader (`Fall_White`, `Fall_Streak`, `Fall_Alpha`).
- The game: `Castle.Falls.Follow` after every `Castle.Water.Tick`; `Air` written into the texels; the
  second cells meshed for stacks under a sheet (`Air_Wanted`), a stack meshed again, once, when a sheet first
  comes over it; `--nofalls`, `--throw S`; a scripted run reports "falls: sheets over N columns".
- `tools/demo_falls.sh`.

## Measured (seed 1, RX 6900 XT, 1280 x 720)
- Before anything was built, on made-up ground (a reservoir 2 m deep behind a notch, 1 m of head):
  the lip's water leaves at 5.7 m/s, 13 cm deep, steadily (5.2 to 6.2); down a stair of one in one the
  speed of a step is 5 to 7 m/s on average and anything from 0.2 to 10 from one tick to the next. In
  the game, a cut 1 m wide and half a metre deep out of the mountain lake: 1 to 2 m/s at the lip. So
  the speed is settled before it is drawn, and held to 3 m/s.
- The fixed views (`tools/look_cost.sh`), `main` and the branch back to back, twice: lake 0.83 and
  0.83 ms, meadow 1.73 and 1.73, horizon 1.24 and 1.24, rain 2.31 and 2.31. (With the second cells on
  every simulated stack the rain view read 2.38: 25 stacks of the band's ground, no water near. They
  are only where a sheet stands now.)
- A cut fall in the view: 0.03 to 0.06 ms more than the curtain it was (0.88 to 0.91, 0.86 to 0.92).
- `Castle.Falls.Follow`: 0.46 ms a water tick with fifteen stacks awake (the water's own step: 5.9).

## Saves
Nothing new. A loaded game's falls form again with its flows.

## Options
`--nofalls`, `--throw S`.

## Bugs found and fixed
None in what John has. Mine, in this work, in no build he has had:
- Thrown at 0.45 of the speed measured on made-up ground, nothing at all was thrown from a real cut
  (its lip runs at a third of that): the share is 1 and the speed is held to 3 m/s instead.
- A sheet sampled at the middle of each column began in mid-air below the lip when the water was slow.
  A column's slab runs from where the sheet comes in to where it goes out.
- The sheet's slabs looked like boxes of pale glass: each face lit by its own normal and mirroring the
  sky. A sheet is lit alike on every face and mirrors nothing.
- The second cells on every simulated stack cost 0.06 ms wherever a band had dug.
- A generated stream woken beside its own fall threw sheets in patches where it had been drawn down
  (what moves between its columns then is how far each has dropped, not the stream's flow). Source water
  throws nothing onto source water now; the water it gives a cut throws as any does.
- A stack reached only by the tip of a pulsing fall could have been built again on every pulse and
  never got its cells: a stack once under a sheet keeps them until it is unloaded, and is built again
  for them once.
- A sheet was told from other water by a mark a fringe could have had; it has one of its own.

## Known limits
- A sheet flies along the four directions of a column's faces, and there is one sheet to a column:
  two that cross are drawn as one, as thick as both.
- A sheet over a stack that is not simulated has no cells to be drawn with (the stack a fall lands in
  is simulated as soon as its water arrives, a tick or two later).
- Water under a roof is laid as blocks: a fall out of a roofed tunnel is thrown from the first column
  under the open sky, one column out from its mouth.
- A `--frames` run follows real time and thin water pulses: two runs of the same fall differ in the
  shape of it. Compare by eye or over a recording.
- Not tried: a flood wide enough to wake 48 stacks with falls in all of them.

## Not done
- Reach in the simulation (his call 1). Generated falls thrown (his call 7).
- A splash or spray where a fall lands; sound.

## Next
- Accepted and merged (the top of this file). No scratch worktree is left; `main` is checked out.
- **Stage 6 (habitation, with stockpile mechanics rolled in) is his to open in the next session.**
  Nothing of it is designed and there is no brief. Where things stand for it:
  - `main` has everything of 2026-11-11: the models pass, the sky and the weather's look, the moon,
    the pathing work, the falls. Nothing is on a branch waiting; the branches `sky-and-weather`,
    `pathing` and `falls` are kept as they were merged. The latest zip of `main` is
    castle_game_falls.zip.
  - Read, as CLAUDE.md says: the framework, the plan ("Stage 6: habitation"), this file, CLAUDE.md,
    then `docs/systems/habitation.md`, `colony.md`, `routes.md` and `edits_and_saves.md` as the work
    touches them. The four handoffs of 2026-11-11 before this one (hands and level, models pass, sky and
    weather, pathing) each end with what bears on stage 6; in short:
    - stockpile mechanics are rolled into this stage on his word, and earth in store is only a heap
      nobody asks for (hands and level);
    - a hearth in a hovel is one more `Castle.Fire.Show` and one more `Castle.Render.Add_Light`, and it
      shines through the walls until lights other than the nearest cast: an open decision (sky and
      weather);
    - an edit costs the walking map one cell, and a route through a stack being built in is walked
      again, not planned again; the route store and the coarse graph wait for this stage's buildings to
      anchor to, with the numbers in routes.md (pathing);
    - he has taken water to a village and held it there with the water as it is, so a well, a cistern
      or a trough is a matter of what the colony does with water that is there, not of new water
      mechanics; no water fetching is designed (the 2026-11-08 rule: none until there is a use and
      barrels).
  - What a build is checked by: the nine checks in debug, `tools/reference_check.sh` (seven logs),
    `tools/stress.sh runner`, and for a look `tools/look_cost.sh` against `main` built beside it and
    `tools/shadow_still.sh`.
