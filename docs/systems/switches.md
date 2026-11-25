# The switches

- Made by: `tools/switch_census.py --md` (run it again and replace the table and the lists below it whenever a
  switch is added; it reads the sources and the gate's scripts and changes nothing)
- Stage: the structural inspection of 2026-11-22; made again the same day after his playtest notes (`Set_Walk_Off`), and on 2026-11-23 after his notes of that day (ten more: `Set_Reach_Out`, `Set_Zigzag`, `Set_Paths_Meet`, `Set_Door_Meet`, `Set_Kill_Home`, `Set_Place_Level`, `Set_Cart_Room`, `Set_Full_Truss`, `Set_Build_Help`, `Set_Step_At_Edge`), and later that day after his answer on the stockpile (`Set_Pile_Flat`), then `Set_Steep_Refuse` in the afternoon, when `Set_Pile_Flat` went off by default

Every rule of the game that came after another has a switch that gives the game as it was before it: a
`procedure Set_NAME (On : Boolean)` in a specification, an option that calls it, and often a line in
`colony_check`'s `Reset` that holds it off so that the older sections of the check stay as they were written.
This page is the list of them, and what each part of the gate runs. It is the on-or-off switches alone: what
is set by a number (the pace, the band's size, the storehouse's size, the stockpile's least side, how far the
band looks) is not in it.

How to read a row: **Default** is what the game runs when nothing is said. **Option** is what turns it the
other way. **Reference runs** is how many of the eight kept logs (`tools/reference_check.sh`) say that option:
8 means no kept log is ever run with the rule on. The four columns after it say whether `tools/stress.sh`,
`tools/stockyard_sites.sh`, `tools/turned_streets.sh` and `tools/square_sites.sh` say the option anywhere.
The last column is `colony_check`: what its `Reset` holds the switch at, and how many times the check sets it
True, False, or by a variable (on 2026-11-22 each such call was read: a loop over both ways, or a call with
the other value).

A switch whose row says 0 reference runs is run *on* in every kept log, but that does not mean a kept log ever
comes to it: none of the eight founds a square, puts down a stockyard or turns a building. Those rules are
proved by the three site scripts (on real ground, by what must be true at the end: the storehouse stands,
nobody starved, no pit) and by the check's own sections, not line for line.

Since 2026-11-22 there is a ninth kept log, of the game with every switch at its default (`tools/today_run.sh`:
thirteen with jobs on a square, a stockpile and the stockyard put down whole, housing pulled; 41 days), checked
line for line and to its state by `tools/today_check.sh`, in the gate. A new rule on by default makes it fail:
it is shown to pass with the new rule's switch off, then recorded again in the rule's own commit.

**Not in the table: the switches of the drawing alone**, which are plain variables (the table is the `Set_`
procedures of the specifications and the variables of `Castle.Actions`). Those of 2026-11-22:
`Castle.Serfs.Hands_Before_Chest` (`--no-chest-hands`), `Castle.Animals.Whole_Back` (`--no-whole-back`),
`Castle.Bodies.More_Form` (`--no-form`) and the game's `Cloak_Fit` (`--no-cloak-fit`), beside the older
`--no-cloth`; of 2026-11-23 (the voxel people, merged 2026-11-24), `Castle.Bodies.Reference_Body` (`--no-reference-body`)
and `Castle.Bodies.Voxels.Voxel_People` (`--no-voxel`); of 2026-11-24, `Castle.Bodies.Head_Shape`
(`--no-head-shape`: the reference body's head before his eight characters, proved to the bit by a hash, by
hand, on 85511a1) and `Castle.Serfs.Rest_Arms` (`--no-rest-arms`: the reference body's arms at rest as they
were). `deer_check` runs `Whole_Back` both ways and
`serf_check` `More_Form` and `Reference_Body`; the rest are run both ways by hand alone, since no part of
the gate opens a window. `Castle.Herds.Set_Walk_Off` is run the
other way by `colony_check` and by `tools/herd_places.sh`, a part of the gate the table has no column for.

| Switch | Default | Option (the value it gives) | Reference runs that say it (of 8) | stress | yard | turned | square | colony_check: Reset holds it; set True / False / by a variable, in all |
|---|---|---|---|---|---|---|---|---|
| `Castle.Actions.Housing_Pull` | on | `--no-housing-pull` (off) | 0 |  |  |  |  | False; 1 / 2 / 0 |
| `Castle.Actions.Path_Snap` | on | `--no-path-snap` (off) | 0 |  | says |  |  | False; 0 / 1 / 0 |
| `Castle.Actions.Square_Stake` | on | `--no-square` (off) | 0 |  |  |  |  | False; 1 / 2 / 0 |
| `Castle.Actions.Dev_Jobs` | on | `--no-dev-jobs` (off) | 0 |  |  |  |  | False; 2 / 3 / 0 |
| `Castle.Colony.Set_Line_Ground` | on | `--no-line-ground` (off) | 0 |  |  |  |  | not held; 1 / 0 / 1 |
| `Castle.Colony.Set_Path_Through` | on | `--no-path-through` (off) | 0 |  |  |  |  | False; 2 / 2 / 0 |
| `Castle.Colony.Set_Metre_Ground` | on | `--no-metre-ground` (off) | 0 |  |  |  |  | not held; 1 / 0 / 1 |
| `Castle.Colony.Set_Path_Holes` | on | `--no-path-holes` (off) | 7 |  |  |  |  | False; 0 / 1 / 1 |
| `Castle.Colony.Set_Path_Level` | on | `--no-path-level` (off) | 8 | says |  |  |  | False; 8 / 1 / 1 |
| `Castle.Colony.Set_Roof_Timbers` | on | `--no-roof-timbers` (off) | 8 | says |  |  |  | False; 2 / 1 / 0 |
| `Castle.Colony.Set_Full_Truss` | on | `--no-full-truss` (off) | 0 |  |  |  |  | False; 1 / 1 / 0 |
| `Castle.Colony.Set_Window_Timber` | on | `--no-window-timber` (off) | 8 | says |  |  |  | False; 2 / 1 / 0 |
| `Castle.Colony.Set_Paths_Meet` | on | `--no-paths-meet` (off) | 8 | says |  |  |  | False; 0 / 1 / 3 |
| `Castle.Colony.Set_Door_Meet` | on | `--no-door-meet` (off) | 8 | says |  |  |  | False; 0 / 1 / 1 |
| `Castle.Colony.Set_Stretches` | on | `--all-hands` (off) | 2 |  |  |  |  | not held; 1 / 2 / 0 |
| `Castle.Colony.Set_Place_Level` | on | `--no-place-level` (off) | 8 | says |  |  |  | False; 5 / 1 / 2 |
| `Castle.Colony.Set_Overflow` | off | `--no-overflow` (off), `--overflow` (on) | 0 |  |  |  |  | False; 2 / 1 / 0 |
| `Castle.Colony.Set_Yard_Box` | on | `--no-yard-box` (off) | 0 |  |  |  |  | False; 5 / 5 / 0 |
| `Castle.Colony.Set_Yard_Turn` | on | `--no-yard-turn` (off) | 0 |  | says |  |  | not held; 1 / 1 / 1 |
| `Castle.Colony.Set_Smooth_Covers` | on | `--no-smooth-covers` (off) | 0 |  |  |  |  | not held; 1 / 1 / 1 |
| `Castle.Colony.Set_Fence_Pieces` | on | `--no-fence-pieces` (off) | 0 |  |  |  |  | not held; 1 / 1 / 1 |
| `Castle.Colony.Set_Yard_Level` | on | `--no-yard-level` (off) | 0 |  |  |  |  | not held; 1 / 0 / 2 |
| `Castle.Colony.Set_Ladder_Stay` | on | none |  |  |  |  |  | not held; 0 / 0 / 1 |
| `Castle.Colony.Set_Make_Way` | on | `--no-make-way` (off) | 0 |  |  |  |  | not held; 0 / 1 / 1 |
| `Castle.Colony.Set_Stores_Move` | off | `--stockpile-stays` (off), `--stores-move` (on) | 0 |  |  |  |  | True; 2 / 0 / 0 |
| `Castle.Colony.Set_Storehouse` | on | `--no-storehouse` (off) | 8 | says |  |  |  | False; 13 / 5 / 1 |
| `Castle.Colony.Set_Store_Stacks` | on | `--no-store-stacks` (off) | 0 |  |  |  |  | False; 0 / 3 / 1 |
| `Castle.Colony.Set_Yard_Stair_Corner` | on | `--yard-stair-middle` (off) | 0 |  |  |  |  | False; 1 / 5 / 1 |
| `Castle.Colony.Set_Yard_Floor_Low` | on | `--yard-floor-by-land` (off) | 0 |  |  |  |  | False; 0 / 3 / 1 |
| `Castle.Colony.Set_Stockman` | on | `--no-stockman` (off) | 0 |  |  |  |  | not held; 4 / 0 / 1 |
| `Castle.Colony.Set_Cart_Search` | on | `--one-cart-place` (off) | 0 |  |  |  |  | False; 2 / 3 / 0 |
| `Castle.Colony.Set_Carpenter` | on | `--no-carpenter` (off) | 0 |  |  |  |  | not held; 4 / 0 / 1 |
| `Castle.Colony.Set_Water` | on | `--no-water` (off) | 0 |  |  |  |  | not held; 0 / 0 / 1 |
| `Castle.Colony.Set_Top_Cut` | on | `--no-top-cut` (off) | 1 |  |  |  |  | False; 0 / 1 / 1 |
| `Castle.Colony.Set_Bush_Sharing` | on | `--one-to-a-bush` (off) | 8 | says |  |  |  | False; 0 / 1 / 1 |
| `Castle.Colony.Set_Wood_Reach` | on | `--no-wood-reach` (off) | 8 | says |  |  |  | False; 5 / 2 / 0 |
| `Castle.Colony.Set_Protect_Apples` | on | none |  |  |  |  |  | not held; 0 / 1 / 0 |
| `Castle.Colony.Set_Cook_Hold` | on | `--no-cook-hold` (off) | 7 |  |  |  |  | False; 0 / 1 / 1 |
| `Castle.Colony.Set_Source_Memos` | on | `--no-memos` (off) | 0 | says |  |  |  | not held; 0 / 0 / 0 |
| `Castle.Colony.Set_House_Memos` | on | `--no-memos` (off) | 0 | says |  |  |  | not held; 0 / 0 / 0 |
| `Castle.Colony.Set_Needs` | on | `--no-needs` (off), `--skills-at` (off) | 0 | says |  |  |  | not held; 5 / 35 / 1 |
| `Castle.Colony.Set_Labour` | on | `--instant-camp` (off), `--no-labour` (off) | 3 |  |  |  |  | not held; 18 / 20 / 4 |
| `Castle.Colony.Set_Levelling` | on | `--no-level` (off) | 2 |  |  |  |  | not held; 0 / 1 / 0 |
| `Castle.Colony.Set_Skills` | on | `--no-skills` (off) | 1 |  |  |  |  | not held; 1 / 42 / 1 |
| `Castle.Colony.Set_One_Stockpile` | off | `--one-stockpile` (on) | 0 |  |  |  |  | False; 2 / 1 / 0 |
| `Castle.Colony.Set_Box_Place` | on | `--no-box-place` (off) | 0 |  |  |  |  | False; 17 / 6 / 0 |
| `Castle.Colony.Set_Box_Fell` | on | `--no-box-fell` (off) | 0 |  |  |  |  | True; 2 / 1 / 0 |
| `Castle.Colony.Set_Square_Fell` | on | `--no-square-fell` (off) | 0 |  |  |  | says | True; 2 / 2 / 0 |
| `Castle.Colony.Set_Fire_Ground` | on | `--no-fire-ground` (off) | 0 |  |  |  |  | not held; 2 / 0 / 2 |
| `Castle.Colony.Set_Square_Wide` | on | `--square-10` (off) | 0 |  |  |  | says | False; 2 / 1 / 1 |
| `Castle.Colony.Set_Square_Outside` | on | `--square-walls-inside` (off) | 0 |  |  |  | says | False; 2 / 2 / 1 |
| `Castle.Colony.Set_Square_Walls` | on | `--no-square-walls` (off) | 0 |  |  |  |  | False; 1 / 1 / 1 |
| `Castle.Colony.Set_Square_Stair_Corner` | off | `--square-stair-corner` (on), `--square-stair-middle` (off) | 0 |  |  |  | says | not held; 0 / 0 / 1 |
| `Castle.Colony.Set_Path_Steps` | on | `--no-path-steps` (off) | 0 |  |  |  |  | False; 10 / 2 / 1 |
| `Castle.Colony.Set_Strip_Wait` | on | `--no-strip-wait` (off) | 0 |  |  |  |  | False; 0 / 2 / 2 |
| `Castle.Colony.Set_Corner_Whole` | on | `--no-corner-whole` (off) | 0 |  |  |  |  | False; 3 / 3 / 2 |
| `Castle.Colony.Set_Corner_Steps` | on | `--no-corner-steps` (off) | 0 |  |  |  | says | False; 2 / 3 / 2 |
| `Castle.Colony.Set_Build_Help` | on | `--no-build-help` (off) | 8 | says |  |  |  | False; 0 / 1 / 1 |
| `Castle.Colony.Set_Reach_Out` | on | `--no-reach-out` (off) | 8 | says |  |  |  | False; 0 / 1 / 1 |
| `Castle.Colony.Set_Zigzag` | on | `--no-zigzag` (off) | 8 | says |  |  |  | False; 0 / 1 / 1 |
| `Castle.Colony.Set_Ladders` | on | `--no-ladders` (off) | 0 |  |  |  |  | False; 5 / 1 / 1 |
| `Castle.Colony.Set_House_Turn` | on | `--no-house-turn` (off) | 8 | says |  |  |  | False; 2 / 1 / 1 |
| `Castle.Colony.Set_Turn_Ground` | on | `--no-turn-ground` (off) | 0 |  |  |  |  | not held; 2 / 3 / 0 |
| `Castle.Colony.Set_Keep_Off` | on | `--no-keep-off` (off) | 0 |  |  |  |  | not held; 2 / 3 / 0 |
| `Castle.Colony.Set_Hovel_Walk` | on | `--no-hovel-walk` (off) | 0 |  |  | says |  | not held; 0 / 1 / 1 |
| `Castle.Colony.Set_Turn_Fall` | off | `--turn-fall` (on) | 0 |  |  |  |  | not held; 0 / 0 / 1 |
| `Castle.Colony.Set_Ways_Told` | on | `--no-ways-told` (off) | 0 |  |  |  |  | not held; 0 / 1 / 1 |
| `Castle.Colony.Set_Beds` | on | `--no-beds` (off) | 7 |  |  |  |  | not held; 2 / 35 / 1 |
| `Castle.Colony.Set_Demand_Chain` | on | `--no-demand` (off) | 2 | says |  |  |  | not held; 12 / 34 / 1 |
| `Castle.Colony.Set_Curing` | on | `--no-curing` (off) | 7 |  |  |  |  | False; 3 / 8 / 1 |
| `Castle.Colony.Set_Cart_Pull` | on | `--no-cart-pull` (off) | 0 |  |  |  |  | False; 1 / 1 / 1 |
| `Castle.Colony.Set_Cart_Room` | on | `--no-cart-room` (off) | 8 | says |  |  |  | False; 0 / 1 / 1 |
| `Castle.Colony.Set_Step_At_Edge` | on | `--no-step-at-edge` (off) | 8 | says |  |  |  | False; 0 / 1 / 1 |
| `Castle.Colony.Set_Steep_Refuse` | on | `--no-steep-refuse` (off) | 8 | says |  |  |  | False; 0 / 1 / 1 |
| `Castle.Colony.Set_Pile_Flat` | off | `--pile-flat` (on) | 0 |  |  |  | says | False; 4 / 1 / 3 |
| `Castle.Colony.Set_Spare_Deer` | off | none |  |  |  |  |  | not held; 1 / 0 / 0 |
| `Castle.Colony.Set_Kill_Home` | on | `--no-kill-home` (off) | 0 |  |  |  |  | False; 0 / 1 / 1 |
| `Castle.Falls.Set_On` | on | `--nofalls` (off) | 0 |  |  |  |  | not held; 0 / 0 / 0 |
| `Castle.Herds.Set_Scatter` | off | `--deer-scatter` (on) | 6 |  |  |  |  | not held; 31 / 0 / 1 |
| `Castle.Herds.Set_Walk_Off` | on | `--herds-anywhere` (off) | 0 |  |  |  |  | not held; 1 / 0 / 1 |
| `Castle.Nav.Set_Spent_Memos` | on | `--no-memos` (off) | 0 | says |  |  |  | not held; 0 / 0 / 0 |
| `Castle.Render.Set_Turn_Floor` | on | `--no-turn-floor` (off) | 0 |  |  |  |  | not held; 0 / 0 / 0 |
| `Castle.Render.Set_Flow_Debug` | off | `--flowmap` (on) | 0 |  |  |  |  | not held; 0 / 0 / 0 |
| `Castle.Water.Set_Leak` | off | none |  |  |  |  |  | not held; 0 / 0 / 0 |

## What the table says

84 switches: 74 on by default, 10 off.

**On by default, and every one of the 8 reference runs says its option, so no line-for-line log is run with the rule on (16):** `Set_Path_Level`, `Set_Roof_Timbers`, `Set_Window_Timber`, `Set_Paths_Meet`, `Set_Door_Meet`, `Set_Place_Level`, `Set_Storehouse`, `Set_Bush_Sharing`, `Set_Wood_Reach`, `Set_Build_Help`, `Set_Reach_Out`, `Set_Zigzag`, `Set_House_Turn`, `Set_Cart_Room`, `Set_Step_At_Edge`, `Set_Steep_Refuse`

**On by default, on in some reference runs and off in others (10):** Set_Path_Holes (off in 7), Set_Stretches (off in 2), Set_Top_Cut (off in 1), Set_Cook_Hold (off in 7), Set_Labour (off in 3), Set_Levelling (off in 2), Set_Skills (off in 1), Set_Beds (off in 7), Set_Demand_Chain (off in 2), Set_Curing (off in 7)

**On by default, and no reference run says its option: each log is run with the rule on, whether or not the run ever comes to it (46):** `Housing_Pull`, `Path_Snap`, `Square_Stake`, `Dev_Jobs`, `Set_Line_Ground`, `Set_Path_Through`, `Set_Metre_Ground`, `Set_Full_Truss`, `Set_Yard_Box`, `Set_Yard_Turn`, `Set_Smooth_Covers`, `Set_Fence_Pieces`, `Set_Yard_Level`, `Set_Make_Way`, `Set_Store_Stacks`, `Set_Yard_Stair_Corner`, `Set_Yard_Floor_Low`, `Set_Stockman`, `Set_Cart_Search`, `Set_Carpenter`, `Set_Water`, `Set_Source_Memos`, `Set_House_Memos`, `Set_Needs`, `Set_Box_Place`, `Set_Box_Fell`, `Set_Square_Fell`, `Set_Fire_Ground`, `Set_Square_Wide`, `Set_Square_Outside`, `Set_Square_Walls`, `Set_Path_Steps`, `Set_Strip_Wait`, `Set_Corner_Whole`, `Set_Corner_Steps`, `Set_Ladders`, `Set_Turn_Ground`, `Set_Keep_Off`, `Set_Hovel_Walk`, `Set_Ways_Told`, `Set_Cart_Pull`, `Set_Kill_Home`, `Set_On`, `Set_Walk_Off`, `Set_Spent_Memos`, `Set_Turn_Floor`

**The other way (the value that is not the default) is run by nothing in the gate (4):** Set_On (--nofalls), Set_Turn_Floor (--no-turn-floor), Set_Flow_Debug (--flowmap), Set_Leak (no option)

**No option reaches it (4):** `Set_Ladder_Stay`, `Set_Protect_Apples`, `Set_Spare_Deer`, `Set_Leak`
