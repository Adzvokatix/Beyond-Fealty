# Castle Game handoff (2026-11-10: water, between stages 5c and 6; closed, accepted as built; Claude Code)

- **Closed 2026-11-10.** John, after trying the build: "Everything is working as it should, I am not seeing any room for improvement right now, I am happy with the state of water, all my tests achive the desired result."
  And: "We scrapped dams and rerouting, maybe something we can do later, but it's not the purpose of this
  game, besides I see ways of using the current state to get dams if I wanted to." So the rules stand as
  built (first values, his to tune), dams and rerouting are dropped, and reach is no longer owed (he asks
  for nothing more of the simulation). `water-drawdown` is merged into `main`. Next for water, his words:
  "deeper hues for deeper depths, and surface reflections".
- Code: GAME_alpha_1_3/compiled, branch `water-drawdown` from `main` at f08b22b (tag `pre-water-drawdown`),
  eight code commits (2709956 to the one this handoff is in) and the documents with them. Not merged: `main`
  is still stage 5c. All nine checks and the reference check pass in debug from a clean unzip of 2bfb99a,
  the last code commit (the zip is the commit after it, this handoff's wording only); the demo was recorded
  with it.
  Zip: CASTLE_GAME/releases/castle_game_water_drawdown.zip. Demo: water_drawdown.mp4 (tools/demo_water.sh).
- Checks: all nine pass in debug; six known warnings. water_sim_check 77 (was 33), about 3.5 minutes in debug.
  `tools/reference_check.sh` passes (both runs).
- Versions: Generator_Version 12 (tarns; saves made by 11 are refused). Save format 6 (the level source
  water rests at, and which columns have been dug or built in; formats 1 to 5 still load). Colony blob 13,
  unchanged.

## What John sees on first launch
1. **His saves from before are refused**: the generator changed (tarns).
2. **Water is drawn stepped**, an eighth of a block a step, not as one smooth sheet. Still water looks as it
   did; a sloping stream has risers across it; a fall is a curtain. `--watersteps 0` is the sheet of before.
3. **Eight tarns in the mountains** of seed 1 where there were flats, the dry lake bed at 1311, 1465 among them.
4. **A cut into a lake or a stream draws it down** round the cut, and much more water comes through than
   before (what the cut's size allows, not a trickle through a wall).

## Rules agreed with John (2026-11-10)
Accepted as built (above). His message of that day is the brief (docs/systems/water.md, "John's rules", has his words
and what stands for each), with two more sent while the work was on: momentum "by simply allowing the water
to move further in relation to the column of water moving forward", and "rippling by stepping the water
instead of smoothing". Built from them with first values of mine; his to change.

## Built
- **A block placed in water takes its place** (2709956). `Ground_Changed` keeps water in the rows still open;
  rows now solid lose theirs. (It was lifted into the stretch above: the spikes on the planks.)
- **Source water that drops and comes back** (78f59d7). `Column.Rest`, the level it holds; awake, the flow
  between two source columns goes by the difference of their drops, and a dropped column is refilled
  (`Set_Recharge`; the game's `Source_Refill`). Resting source water wakes past `Wake_Drop`. Filled in to its
  level it is source water no longer. `About_To_Change` before an edit, `Ground_Changed` after.
- **The world as made holds its water** (78f59d7). `Column.Touched`; source water goes out to other ground
  only across a face one of whose columns has been dug or built in.
- **Tarns** (147ad0c). `Tarn_Min_Depth` 4 m, `Tarn_Min_Area` 500 m^2 in castle-hydrology.ads.
- **A flow established sleeps** (265852e, and the commit after the documents: only a flow that is fed
  counts, so a pond that is only levelling is not put to sleep as running water and kept from drying).
  `Steady_Seconds`, `Steady_Within`, `Steady_Sum`; `Is_Running`.
- **Source water rests at its drawn level** (19e98aa). `Castle.Geology.Water_Level` (the game's `Wet_Level`,
  moved), carried in the stack summary in depth units.
- **Stepped drawing** (e64adb8). `Castle.Render.Set_Water_Steps`, `--watersteps N`.
- A scripted run ends with one line on the live water (`Report_Water` in the game). `--record` with no
  colony and no figures asked for starts once the view has filled (it waited for people and never began),
  and in a recording the water steps with the frames (it ran at the pace the machine wrote them).

## Measured
- water_sim_check, a lake 3 m deep behind a cut 1 m wide and 1.5 m deep, refill 256: the water stands 0.95
  blocks (24 cm) down at the cut, 0.28 blocks 2 m in, at its level 10 m in; no step from one column to the
  next over 0.53 blocks (the wall was the whole 6); 11 stacks awake; about 1.6 m^3/s through the cut; the
  lake 16 m off never woke. The cut closed: back at its level to the unit, all asleep in 26 s.
- The same on a stream 0.75 m deep on a 1 in 8 hill: 0.66 blocks down at the cut, nowhere over its level,
  at its level 20 m up and down the hill, 8 stacks awake.
- Seed 1, the mountain lake at its west rim, a cut 2 m wide (`--dig 1186 1373 85.5 1206 1375 94 --late`):
  after 15 s 535 columns wet outside the lake, 22 m^3; the lake at most 18 cm down, at the cut; 10 stacks
  awake. Planks in the cut (`--load` then `--fill 1202 1373 85.5 1204 1375 88.5`): nothing on them, the lake
  at its level again.
- The same cut after 10 simulated minutes (`--simticks 6000`): 14 stacks awake, 1,972 columns wet, 30 m^3,
  the lake 13 cm down at the cut. A cut over the steep slope at 1394 (`--dig 1194 1393 85.5 1210 1395 96`):
  16 awake, 2,414 columns, 34.5 m^3; the frame's CPU at most 3.2 ms over 30 s of play. Neither came near
  the 48 stacks allowed; both stay awake (the water tumbles down a slope).
- The lowland stream at 1160, 1019, a ditch 1 m wide and 13 m long dug off it
  (`--dig 1159 1021 14.5 1160 1034 17`): after 10 simulated minutes full to the stream's level (1.25 m), no
  source water below its level, nothing awake.
- Six falls of seed 1 (`fall_find`), one block dug 9 m from each, 600 ticks: the old build kept 1 to 4
  stacks awake for good at every one (a leak beside the fall); none now.
- Tarns: 13 lakes on seed 1 (5 and 8 tarns). The survey checksum is 8421323592241916501 with any worker
  count. The nearest tarn is 250 m from the reference stake; the reference run is unchanged.
- A stream cut onto level ground: the flow established and everything asleep 39 s after the cut (5 stacks
  kept as running water); the cut closed, all awake, run out and asleep for good in 12 s.

## Saves
Format 6: the column byte's 64 says the column has been dug or built in; source water has a u32, the level
it rests at, before its stretches. An older save: source water rests where it lay, every column counts as
dug or built in. Running water is saved as awake.

## Options
`--watersteps N` (default 8; 0 the sheet). The water line at the end of a scripted run.

## Bugs found and fixed (all in the build John tested)
- Water lifted onto blocks placed in it (his first picture).
- The first column of an edit under water that had never woken was left a dry shaft through the lake: the
  simulation first saw it after its water blocks were dug away.
- A woken river dried: `Dry_Out` took seep and evaporation off locked source columns, and nothing filled a
  locked column again (a metre a game day on gravel).
- Any stack woken near a fall leaked beside it for good, the colony's own edits included.
- A woken stack stood up to half a block off the resting water round it: a bright line round what had woken.
- `water_sim_check` exited 0 when checks failed.

## Known limits
- Water running down a steep slope comes in pulses and never counts as established: it stays awake.
- A cut passes far more water than before; the leak and the sheet's soak were not retuned for it.
- Beyond the awake water a river runs on at its level: no dams, no rerouting, no stream run dry below a cut.
- Settled water is not source water: a pond filled from a cut holds only what it has.
- The stepped drawing was looked at in a dozen stills (a lake, a cut, a fall, a lowland stream), not in play.

## Not done
- **Reach, John's rule for momentum** ("allowing the water to move further in relation to the column of
  water moving forward"): owed. What stands is the pipes' momentum, which gives speed by the column behind
  but never more than one column a step; there is no jetting fall.
- The framework's close list: this is not closed. Merge `water-drawdown` into `main` when John accepts it.

## Next
- John's word on the rules and the look (stepped or sheet; how big a step). Then reach, and with it the
  pulses, since water that may move more than a column a step may not need to pile up and let go.
- Then stage 6, habitation, as before.
