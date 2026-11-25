# Castle Game handoff (2026-11-22, later: the corners of the square's path, and the faults found on the way)

Read after `Handoff_2026_11_22_stockyard_floor_and_stone_steps.md`, whose three calls this answers.
Branch `stockpile`, nothing merged.

## His words of 2026-11-22, later (whole), in answer to the three calls of the report on the floor and the steps

> 1. that is fine, 2. leave the cart doing whatever it's doing right now, we are going to work on
> the logistics soon. 3. stick with whatever you think is best, Mend the issues you found.

The three calls as they were put to him, and each answer read against its number:

| | the call | his answer | read as |
|---|---|---|---|
| 1 | what the floor's rule costs (81 more stairs, half as much stone again) | "that is fine" | the rule stands as built; nothing to do |
| 2 | the lord's cart where the outer edge of the staging before the storehouse is a wall: left in the stockpile (built), stood by the level corner, or its bed let stand against a wall | "leave the cart doing whatever it's doing right now, we are going to work on the logistics soon" | **nothing of the cart is touched**, this call's and anything else of it, until the logistics are worked on |
| 3 | the corners of the square's path (37 of the 50 jumps left); my default: the corner's square metre made one thing first, then the steps run into it | "stick with whatever you think is best" | the default is built |
| | the four things found on the way and not mended | "Mend the issues you found" | the two that are not the cart's are mended; the two that are the cart's fall under his 2 (below) |

**The four found on the way, each against his 2**:

- a path's end under a tree given the crown's height: mended (below);
- a corner of the strip kept for a square's wall, walled before the other side's path is laid:
  mended (below);
- the cart's towing set down short and staying short: **left**, it is what the cart does now;
- the square at 1258 1058 at 45 degrees, where the colony gets no cart at all: the cause was never
  looked into, so it could not be said whose fault it is. **Looked into, and left** (below): it is
  where the cart is put, at three squares and not one, and that is the cart's.

The older debts in the handoff before this one ("Owed ... from before") were not in the list he
was shown and are not taken up.

## The square metre where two sides' paths cross, laid as one (his 3; the first half of the default)

**What it was**: the path round a square is laid a metre of a stretch at a time, and brought to the
floor's level a quarter metre of that stretch's length at a time, whole, where all of that quarter
metre lies within half a metre of the level. In the square metre where two sides' paths cross a
block column is of a quarter metre of each side: it was level or not by whichever side's metre
reached it first. Laid last metre first, 41 quarter metres on 35 sides of 26 of the 323 squares
stood otherwise, every one by a side's end (counted 2026-11-21); and the two ways tried of
stepping the corners both followed that (47 and 62 quarter metres for 41).

**The rule as built** (`Set_Corner_Whole`, `--no-corner-whole` is as it was; not saved; held off
in `colony_check`'s `Reset`; only of a square whose walls stand outside its floor; `Lay_Metre`'s
`Lay_Crossing`, `Cross_Of`):

- The square metre where two sides' paths cross (every block column of the square's path that
  lies on the band of one of sides 1 and 2 and on that of one of sides 3 and 4) is laid **all at
  once**, when the first metre that has a column of it is laid, whichever stretch's that is.
- **Brought to the floor's level whole**, where every column of it lies within half a metre of that
  level (its own top, as it lies then; nothing through water; none of it a zone's); **else left
  whole as its ground lies**, each column at its own top.
- By its own columns alone: nothing beside it is read, no hollow filled by what lies round it.
- **Every column a stretch finds to lay in it is laid**, whatever the corner's own reading of it
  says. The first form of the rule read each column from the floor's level and left one it could
  not read so (ground nine blocks over the level, a block past that reading's reach and the last a
  stretch at the floor's level finds): at the square at 1146 1110 two such columns stayed grass,
  their two metres were counted as left each second, and somebody was sent to lay them 411 times in
  three days. `tools/square_sites.sh` found it before any commit: its square saved half built ran
  on to another state than the straight run (a load counts the metres left at once, a straight run
  a second later). A check holds it now and fails with the line cut.
- The few columns at its outer corner that no stretch reaches (one squarely: further than half a
  metre from both stretches' ends) are laid with it. Until now they were never laid: a tuft of
  grass in the corner of the path.

**Counted at the ten places** (323 squares made on the spot, `colony_run --square-scan 100 20
--square-path`; one reader for every figure):

| | before (`--no-corner-whole`) | laid as one |
|---|---|---|
| sides that stand otherwise with the paths laid last metre first | 35, of 26 squares (41 quarter metres) | **0** |
| squares whose ground within eleven metres stands otherwise so | 26 | **0** |
| quarter metres at the floor's level, of 63,127 | 57,540 | 57,497 |
| the path two blocks or more off the next quarter metre | 50 | 55 |
| of them at a levelled stretch's end, where two sides' paths cross | 25 | 35 |
| quarter metres with a tread of stone | 460 | 459 |

So the rule by itself costs 43 level quarter metres and five more jumps: a corner with one column
out of the level's reach is left whole as the land lies, where a quarter metre or two of it used
to be brought level. That is what the steps then run into (the next section).

- **The floors and the stairs are what they were**: the floor's own block columns the same at 323
  of 323, the 55 stairs at the same middles. The ground beyond the path reads otherwise at one
  square of 323 in the scan (880 940): made alone, that square's ground beyond its path is the
  same with the rule and without (2496771715649477742 both); in the scan it reads the corner of
  the square made before it 20 m off, which the rule changed (an aslant square's corner reaches
  10.4 m, the hash 11).
- **With the switch off, gate 85's build**: the ten scans line for line (but for the spaces between
  the stairs' names, which the runner of the earlier scan printed without); the 23 squares with a
  stockpile and the band, twelve days, end in gate 85's states, 23 of 23 (run with the first form
  of the rule, before the laying of every found column; **run again with the head and all four of
  the day's switches off: gate 85's states, 23 of 23**).
- **The band, twelve days, 23 squares** with the rule on: all 23 end with thirteen living, no pit,
  nothing of the walls left to lay; 18 of the 23 end in another state than gate 85's (the corner
  columns no stretch reached are path now, at every square); 232 member-hours with an empty belly
  for 227; 11 jumps in their paths at the end for 13. Seconds somebody stood still more than half
  a metre over the ground of its own block column: 638 for 344, of two and a half million. Looked
  into: 289 of them are at one square (832 964), three people idle or eating at one spot on the
  outer edge of the north side's path beside the stockpile, where the walking map's floor is three
  blocks over their own column (the land's own bank, there in gate 85's build too, where nobody
  happened to stand); 216 are one hunter idle on a hillside fifty metres from the square at 1320
  1000. Neither is at a corner.
- **The band's path against one made on the spot** (`$S/pstep.sh`: the same 23 squares, six days):
  the same at **20 of 23 for 17**. The three that still differ do so in gate 85's build too, line
  for line: 1238 1058 and 1200 720 by a side's end, 1186 1068 along the middle of a side. With
  the strips' mend below the first of them is the same as made on the spot (21 of 23); the other
  two were not looked into.

**Checks** (two, with the steps' checks): squarely and aslant on level ground with the land beyond
one corner of the floor a block higher and one block column of that corner's square metre three
blocks higher: laid a quarter metre of each side's at a time the square stands otherwise at 4 and 3
block columns with its path laid last metre first (so the land shows the fault), laid as one at
none; of its four corners three lie all at the floor's level and one all as the land lay, none
partly, every column of them path; and with the land beyond that corner two and a quarter metres
up it is laid where it lies and no metre is left to lay (2 and 3 are, for ever, with the line cut).
`colony_check` 1047 at this commit.

**`tools/square_sites.sh`** makes the scans of two of the ten places again with the paths laid
last metre first (800 900 and 1178 1078: 98 squares, 17 of the 26 that stood otherwise) and fails
if any square's ground differs.

**A correction to the handoff before this one**, found reading these runs: it says of the band at
the 23 squares "nobody said to be starving". One was: at the square at 950 1290, in one hourly
line, the cook's state is worded "starving: fetching wood for the fire". It is so in gate 84's
build and in gate 85's with the steps off, the same line (the count of dead-or-starving lines is 2
in every arm: that `who:` line and the herd's line that quotes it). That square is one of the two
of the 23 where the colony gets no cart (below).

## The steps run into the corners and through them (his 3; the second half of the default)

**The rule as built** (`Set_Corner_Steps`, `--no-corner-steps` is as it was; not saved; held off
in `colony_check`'s `Reset`; with the corners laid as one, and not where a square's stair stands
in a corner of its floor; `Plan_Steps`):

- The square metre where two sides' paths cross is **one step of a flight: a landing**, all its
  columns at one row, each a tread of stone.
- A flight that comes to it along one side **goes on from it along the other**. So the path round
  the square is one round of quarter metres and four landings, and a flight runs along it from
  each level one, either way, a block a step and six steps at the most, by the rules a flight
  along a side went by (the first that does not fit ends it; none before a stair; before the
  middle of a side with no stair only steps of one and two blocks).
- A corner brought level whole is a level one of the round, as a quarter metre is: flights run
  out from it along both sides.
- Planned from the laid path and nothing else, each time, as every step is. A landing half made
  reads as the same landing; made, as itself.

**Counted at the ten places** (323 squares made on the spot; one reader):

| | gate 85's build | the corners laid as one | and stepped |
|---|---|---|---|
| the path two blocks or more off the next quarter metre | 50 | 55 | **16** (15 of two blocks, 1 of three) |
| at a levelled stretch's end | 31 | 41 | **7** |
| of those: where two sides' paths cross | 25 | 35 | **0** |
| before a stair | 2 | 2 | 2 |
| a column with no laid path to read (a boulder, every one: below) | 4 | 4 | 5 |
| by a side's end, neither quarter metre level | 12 | 7 | 2 |
| the land's own, along a side | 7 | 7 | 7 |
| quarter metres with a tread of stone | 460 | 459 | 691 (2,684 treads), each all of stone at one row |
| quarter metres at the floor's level | 57,540 | 57,497 | 57,497 |
| sides that stand otherwise laid last metre first | 35 | 0 | **0** |
| squares whose ground stands otherwise so | 26 | 0 | **0** |

Of the 272 jumps counted on 2026-11-21, 16 are left: 2 before a stair (a step there would take
the stair's bank from under it), 5 at a boulder, 2 by a side's end and 7 the land's own along a
side no quarter metre of which is level. **The five, named by a run** (a scratch runner of the
head that prints what stands on each column the plan cannot read): thirteen block columns, every
one a boulder, none of them a column a stretch will come to lay; at the squares at 1118 1138 (side
4), 1200 720 (side 1), 740 880 (sides 1 and 4) as before, and the fifth a corner's square metre at
800 980 with a boulder on one of its sixteen columns: no landing is made of a corner that cannot
all be read.

**The landings, counted** (a scratch runner of the head that prints each corner as it is first
planned a landing; the ten places): **35 corners of the 1,292** are made landings. 27 of them a
block off the floor's level (15 up, 12 down), 5 two blocks off, 3 three (the second and third
steps of a flight that turns the corner). 27 had a jump of two blocks or more beside them
before; the 8 that had none are those of two and three blocks, steps of a flight the land already
went gently by. At 20 one of the two sides comes to the corner level, at 8 neither; **at 7 both
do: there the corner is a landing one block up or down between two level stretches**, where
before it lay half a metre and more off them (all 7 had the jump). The other 232 quarter metres
newly stepped are those landings read from each side (two quarter metres a side) and the flights
that go on from them.

- **Floors and stairs as they were**: the floors' own block columns the same at 323 of 323, the 55
  stairs at the same middles. The ground beyond the path reads otherwise at 6 squares in the scan:
  each of the six made alone has the very ground beyond its path that gate 85's build gives it; in
  the scan they read a neighbouring square's corner.
- **With `--no-corner-steps`** the ten scans' squares are the first commit's, 323 of 323.
- **The band, twelve days, 23 squares**: thirteen living at all 23, no pit, nothing of the walls
  left to lay; 4 jumps in their paths at the end for 11 (13 in gate 85's build), none of them at a
  levelled stretch's end; 186 quarter metres stepped for 139; 236 member-hours with an empty belly
  (232 with the corners laid as one and not stepped, 227 in gate 85's build). The 18 squares with
  no landing to make end in the states they end in without the corners' steps.
- **The band's path against one made on the spot**: the same at 20 of 23, the three as before.

**Checks** (nine; `colony_check` 1056 at this commit): four lands (squarely and aslant: the land
beyond one corner of the floor three blocks up, so that both sides' levelled stretches run up to
a corner that is not level; and all the land beyond one side three blocks up, so that a flight
turns the corner), each with the jumps there without the rule and none with it, the landing every
column of stone at one row, the floor and the stairs as they were, the square the same laid last
metre first and a stone at a time, and a landing saved half made (the same bytes, the same steps
still to make); and the band building a landing with its walls (a way to the fire for each of the
six every second, no pit).

**`tools/square_sites.sh`** fails now on a jump said to be where two sides' paths cross, and on
fewer than 600 quarter metres stepped.

**A sheet**: `~/CASTLE_GAME/releases/square_path_corners_stepped.png` (the south-east corner of
the square at 1320 1000 after twelve days with the band, in gate 85's build and now, from two
sides).

## A strip's column waits for the path it is planned against (found on the way; "Mend the issues you found")

**What it was**: where the strips kept for two sides' walls meet beyond a corner of the floor, a
column is of both strips and is planned by what both sides' laid paths say. Planned while one of
those paths was still to lay, it was walled by the other alone; when the second path came the
stone stood, where that side's quarter metre would have been laid level strip and all, or higher
than both sides ask together. Nothing takes laid stone up. With their walls built when half their
paths' metres are laid, 25 of the 323 squares stood otherwise than built in order (24 in gate
85's build and with the corners laid as one; 23 of those with no steps of stone at all).

**Mending it, a second cause showed**: three squares still differed, by one block column each: a
strip's column beside a quarter metre of path that was laid, while one within a flight's reach of
it was not. It was capped at the path's row there, and stood a block over the step that quarter
metre became when the rest was laid.

**The rule as built** (`Set_Strip_Wait`, `--no-strip-wait` is as it was; not saved; held off in
`colony_check`'s `Reset`; `Plan_Walls`, `Column_To_Lay`):

- A strip's column has **nothing planned, and is counted as nothing left**, while a path it is
  planned against is still to lay: the path column it reads, straight out, on either of its two
  sides; or any quarter metre (or corner) within six along the round of the one it reads.
- "Still to lay" is the very test a stretch finds its columns by (`Column_To_Lay`: some stretch
  will come to turn it to path). **The first form waited on any path column still grass, and that
  held walls up for ever**: ground no stretch ever comes to (further up or down than a metre of
  path is looked for) is grass for good, and eight squares built in order stood otherwise for it.
  A boulder in a path's line still gives the reading beside it, as before.

**Counted at the ten places**: their walls built when half their paths are laid, **0 of 323**
squares stand otherwise than built in order (25). Built in order every square is the square it
was, with the switch on and with it off.

**That the walls are still whole** (a column that waits is counted as nothing left, so "nothing
left to lay" would say nothing by itself): at the 23 squares with the band, twelve days, 0 m of
path is left at every one, and their walls are 2,720 block columns at the end, the very count
without the mend, none of them with a path still unlaid beside it. Fewer blocks are counted when
the walls are first wanted (7,058 for 8,064 over the 23), the rest as their paths are laid.
**What it costs** (the 23 squares run with this commit's build and the one before it): at one of
the 23 (1172 1092 squarely) the walls were ended 8.5 game hours later (after 23.1 hours for 14.6:
the next morning); at the other squares within half an hour of where they were. Six of the 23
end in another state than without the mend; 234 member-hours with an empty belly for 236. The
band's path stands as one made on the spot at 21 of 23 for 20.

**Checks** (one; `colony_check` 1057 at this commit): walls built between, some block columns
differ with the switch off, none with it on; built in order the square is the same either way.
`tools/square_sites.sh` scans its two places a third time with `--walls-between` and fails on a
square that differs (14 of the 25 stood at those two places).

## A planned line's end under a tree (found on the way; "Mend the issues you found")

**What it was**: `Line_Point` gave a planned line's point the height `Castle.Nav.Surface_Z` says,
the walking map's first floor, which is its highest: under a tree, a bough. A stretch whose end
had that height looks for the ground of its metres by that end four and five metres up, where a
metre of path is looked for no further than four metres under the stretch's own height: none
found, never counted, never laid.

**The rule as built** (`Set_Line_Ground`, `--no-line-ground` is as it was; not saved): where what
is stood on at the point is no ground (nothing of its cell's four block columns is ground at that
row), the point has the height of the highest ground under it, read as a site's is (`Top_By`);
beside a trunk's foot, the ground beside it. Of every planned line: the path tool's
(`Path_Line_Start`, `Path_Line_End`, which still give a point back as it is), a zone's put down
whole, housing's pulled with its path.

**Counted at the ten places** (stockyards put down whole against the 1,292 sides of 323 squares,
`colony_run --square-scan 100 20 --yard-census`): **0 parts of their own paths find nothing to
lay, for 4**; nothing else of the census moves (839 taken, every count the same); with the switch
off its ten logs are the build before's, the lines that time a plan aside. The four, named by a
scratch runner: the stockyards at 840 916.75 (north of the square at 840 900), 856.75 940 (east of
840 940), 1116.5 1000 (east of 1100 1000) and 1156.5 1040 (east of 1140 1040), each a part 3.75
or 4 m long by a corner of the stockyard.

**With a band at one of the four** (840 900, the stockyard to its north, ten days): 59 m of path
to lay at the start for 56, none left at the end; thirteen living; the slowest route asked 81 ms
for 100, none ran out of its budget. **The eight reference logs hold**, none recorded again.
The 23 squares with a stockpile and the band end in the states they end in without this mend,
23 of 23.

**Checks** (two; `colony_check` 1059): a line ending under a bough 4.75 m up has its end at the
ground's height and every one of its 192 block columns laid, and the end given back to the line
is the end it was; with the switch off the end is the bough's top, 40 columns by it are never
laid and none of them is counted as left.

## The colony with no cart: looked into, and left (his 2)

**The cause, named by a run** (a scratch runner that says why each place refuses): the lord's cart
is put down at the colony's first step, at the first of 204 places that takes it: a metre apart
from 4 m to 20 m from the fire on twelve bearings, its long side to the fire. A place takes it
where the ground under its bed and half a metre round lies level within a block, is grass or
earth, no zone's, with no path by and nothing over it. At three squares none does:

| | no ground read (over 2 m up or 4 m down from the fire) | a zone's | by a path | more than a block off level | something over it |
|---|---|---|---|---|---|
| 1258 1058 at 45 degrees, with a stockyard and a stockpile | 47 | 82 | 21 | 45 | 9 |
| 890 1290 at 45 degrees, with a stockpile | 46 | 32 | 28 | 89 | 8 |
| 950 1290 squarely, with a stockpile | 46 | 32 | 23 | 98 | 5 |

All three are hillsides. (1258 1058 with a stockpile alone has a cart; with the stockyard too, 82
of its 204 places are a zone's.) The two with a stockpile alone have none in gate 84's build and
gate 85's either: 2 of the 23 squares run with a band, 1 of the 8 run with a stockyard. With no
cart there is no salt and a quarter of each deer is kept (508 lb and 519 lb of meat lost in twelve
days at the two, 688 lb in eighteen at the third), and the cook at 950 1290 is the one worded
"starving" for an hour (above). **The last report said "at one square": it is three.**

**Left as it is.** His second answer is "leave the cart doing whatever it's doing right now, we
are going to work on the logistics soon", and where the cart is put is the cart's. A mend was
written and tried in a scratch tree before that was weighed again (where none of the 204 takes
it, looked for again every half metre out to 40 m and every ten degrees, its long side to the
fire and then across; a colony whose cart found one of the 204 is the colony it was): at the
three squares the cart then stands 20 m, 9.6 m and 15.2 m from the fire, and a check passed on
made-up ridged ground. **It is not in the build**: it is a patch against 6b78a47,
`~/CASTLE_GAME/releases/wip/lords_cart_looked_for_further.patch` (its switch, its two checks and a
count in the squares' scan with it). His call.

The cart's towing set down short is left too, unread.

## A save of his build, run on by this one (the advisor's point: it is what he does when `bin/` changes)

`$S/old85.sh`: saves taken with gate 85's runner (the build in his `bin/` until this gate) at four
squares that get landings (1320 1000, 1146 1110 and 950 1290 squarely, 816 964 at 45 degrees; a
stockpile against each; the band of thirteen), at seven moments each: after 90 colony seconds, 3,
6 and 9 game hours, and a quarter, a half and three quarters of the way through the hours its
walls are laid in. So with all its path still to lay (17 saves), with the path part laid and the
walls begun (10 m of path and 381 blocks of wall left; 17 m and 164; 43 m and 36), and with the
path laid and the walls half built (8 saves: 195 to 732 blocks left). Each run on to three days:

- **by the head with the day's four switches off: his build's own state, 28 of 28** (and his
  build run on from its own save ends in its straight run's state at all 28: the measure holds);
- **by the head as it is**: thirteen living at all 28, no pit, no metre of path left, nothing of
  the walls left, nothing raised; a scratch runner of the head that says each metre it lays lays
  none twice (0 of 842 laid in all). At 950 1290 the saves of the first nine hours have the hour
  in which the cook is worded "starving", as his build's straight run has.
- **The head's own saves at every hour its walls are laid in** (4, 6, 13 and 4 hours at the four
  squares: 27 saves), run on to three days: the straight run's state, 27 of 27.

## Found on the way, not mended

- **A column of a square's path more than 2.25 m over its floor's level, or 4 m under it, is never
  laid**: the square's four stretches lie at the floor's level, and a stretch finds its columns
  sixteen rows under to eight over the row above its own. Such a column stays grass and no
  stretch counts it. (It is what made the first form of the strips' wait hold walls up; nothing
  waits on it now.) Not counted over the ten places.
- **Idle hands stand on the outer edge of a path on a bank**, where the walking map's floor is the
  higher two of the cell's four block columns and their own column lies three blocks lower: the
  runner counts them as standing in the air (289 seconds of three people at one spot beside the
  stockpile at 832 964; in every build, wherever somebody happens to stand).
- **The band's path at 1200 720 and at 1186 1068 stands otherwise than one made on the spot**, in
  gate 85's build and now, line for line (the first by a side's end, a levelled stretch two
  quarter metres longer; the second a flight along the middle of a side that begins a quarter
  metre later). Not looked into.
- **His design document changed in the working copy while this was built**
  (`docs/design/detailed_mechanics.json`, 06:25 on 2026-11-22: version 0.6 to 0.14, 280 lines added
  and 85 taken out). It is his: left as it is, not committed, not in the zip of the head.

## Where it stands (2026-11-22, later)

Branch `stockpile`, **nothing merged** (`main` is 537176c; he has given no merge word). On top of
gate 85's code (773ae92) and its documents: his words (69d454c), **the corners laid as one**
(67e44ff), **the steps run into and through them** (37b4ecc), **a strip's column waits**
(a330eea), **a line's end under a tree** (6b78a47: the code's head), and this handoff with the
documents.

**Gate 86** (6b78a47, from a clean copy, `$S/rungate86.sh`): **passed.** Both builds from nothing
(the six known warnings and no other); the nine checks in debug, `colony_check` 1059; the
reference logs line for line, all eight, none recorded again; the stockyard's seventeen sites and
the turned streets in release and debug; the square's sites in both, word for word the same (323
squares, 55 stairs each at the middle of its side; 691 quarter metres of their paths stepped,
each all of stone at one row; 16 jumps left, 7 at a levelled stretch's end and the runner saying
why of each: none where two sides' paths cross, 2 before a stair, 5 with a column it cannot
read; of 98 squares at two of the places none stands otherwise with its path laid last metre
first, nor with its walls built when half its paths are laid; 39 member-hours with an empty
belly at the fourteen awkward sites, as at gate 85; the sloping square saved half built and run
on, 0769cea3d9826d36); the stress runner's fifteen states gate 85's, every one; flora
5676219328934879273. `bin/` holds gate 86's build, release and debug (copied from the gate's own
clean copy with `pgrep -x castle_game` empty, four files compared after).

**Each earlier commit alone**, from a clean copy of it (`$S/verify_one.sh`: both builds from
nothing, `colony_check` in debug, the reference check, the square's sites and the stockyard's
sites in release): 67e44ff (the corners laid as one): 1047 checks, 55 jumps and 459 quarter
metres stepped, every script passed; 37b4ecc (the corners stepped): 1056 checks, 16 jumps and
691 stepped, every script passed; a330eea (the strips' wait): 1057 checks, every script passed
(of 98 squares none stands otherwise with its walls built when half its paths are laid).

**With all four of the day's switches off**: the ten scans' logs are gate 85's line for line (the
stairs' names' spacing aside, which the earlier scan's runner printed without), and 28 saves of
gate 85's build run on to gate 85's own states (above).

**The stockyards under the debug build's checks** (the gate's debug half does not scan them, and
the line's mend touches every stockyard's own path): the census of the 1,292 sides with the
head's debug runner ends ten scans of ten with exit 0, line for line the release's (839 taken, no
part of a path with nothing to lay, the plan and the click agreeing at all).

**The windowed game** was not played on this build. The gate's `castle_game`, release and debug,
loaded a save of gate 85's build with its square's path and walls half laid (1146 1110) and ran
it for a minute and a half and two minutes of the colony's time, laying as it went, with nothing
raised. Nothing of this round has a click of its own. The stills of the sheet are of saves made
by the runner, drawn by a game of an older build (a save is its blocks).

**His calls open** (each written out; each stands at what is built):

1. **The colony with no cart** (three hillside squares of those run with a band: 1258 1058 at 45
   degrees with a stockyard, 890 1290 at 45 degrees, 950 1290 squarely; the last two in gate 84's
   build too): none of the 204 places within 20 m of the fire takes the cart, so there is no
   salt and a quarter of each deer is kept. Left as it is by his "leave the cart doing whatever
   it's doing right now". A mend is written and not in the build: where none of the 204 takes
   it, the cart is looked for again, closer set and out to 40 m (it then stands 20 m, 9.6 m and
   15.2 m from the fire at those three; every other colony is the colony it was). His to say:
   left until the logistics, or put in now.
2. Open from the report of 2026-11-21, noon, which he has not answered (written out, not
   re-asked): the hearth built before the whole floor is level; what should fail a gate (a death
   or a state worded "starving", as now, or an empty belly beyond some count); the stockyard's
   own retaining walls left where they stand or moved outside; the storehouse at 8 by 12 with the
   yard as deep as before, 3.5 m from a path at 45 degrees, baskets three high and barrels two
   (all built).

Answered and closed by his words of this handoff: what the floor's rule costs ("that is fine");
the cart where the staging's outer edge is a wall (left in the stockpile, as built); the corners
of the square's path (built).

**Owed**: the three things found on the way that are not mended (above); the cart's towing set
down short (his 2: left); from before: a route that ends short planned anew after a load; the
holder of a bush two are picking; the advisor's note for an older save's stockyard; tall grass
drawn in another pose in two saves; the 20 sides with no way from their path's middle to the
fire.

**Kept**: the sheet `~/CASTLE_GAME/releases/square_path_corners_stepped.png`; the cart's mend,
`~/CASTLE_GAME/releases/wip/lords_cart_looked_for_further.patch`; the scratch runner that names
unread columns and laid metres, `wip/path_unread_columns_and_laid_metres_named_on_6b78a47.patch`;
the day's scripts in `releases/wip/scripts/` (`batch_k2.sh`, `secn.sh`, `verify_one.sh`,
`old85.sh`, `rodiff.py`, `rungate86.sh`, and the scripts each rule was proved in a scratch tree
by before it was applied: `apply_step2_check.py`, `apply_step2_misc.py`, `apply_strip.py`,
`apply_strip2.py`, `apply_line.py`, `apply_cart.py`).

## His closing words, and where the next session begins

> Ok let's wrap up here, get ready for a clear, I like what we got so far and I can playtest
> through what we have and polish it later. So do what you need to do

Read as: the round is closed as it stands; he playtests the build in `bin/` (gate 86's, the day's
six rules on) and brings what he finds; polish comes after. **No merge word** ("I like what we
got so far" is praise): `stockpile` stays unmerged, `main` at 537176c. **The cart's call is not
answered**: it stands at "left" (the patch outside the build), and nothing of the cart is touched
until the logistics are worked on.

For whoever reads this next:

- Wait for his playtest notes; build nothing of the cart, and none of the logistics network's
  later passes, before he says so.
- `docs/design/detailed_mechanics.json` is changed in the working copy and uncommitted (his, version
  0.14 against the head's 0.6): read it before designing anything of the economy; do not commit
  it for him unasked, and do not add `docs/` as a directory.
- The scratch directory of this session is gone after a clear or a reboot. What a later session
  needs of it is outside it: the scripts in `~/CASTLE_GAME/releases/wip/scripts/`, the patches in
  `~/CASTLE_GAME/releases/wip/`, the gate's and the verifications' logs in
  `~/CASTLE_GAME/releases/wip/logs_2026_11_22_gate86/`. The kept runners (gate 85's and the rest)
  are not: gate 85's is rebuilt from 773ae92, gate 86's is `bin/`.

## His word to merge, and the cart (2026-11-22, the last of the session)

Asked what was open for merge and what the cart's patch is, and told, he said:

> Ok that is fine we are going to fix that, because the next part is adding the horses for the
> cart and how the colony arrives, they will be pulling the cart to the spot with the horses, it
> won't be magically popping in with the people, so we will fix that after the clear. For now
> merge everything, and we will work with that state.

- **"For now merge everything": merged.** `main` is brought up to `stockpile`: everything from
  2026-11-17 to gate 86 (the stockpile in passes and the storehouse; his playtest notes and the
  next pass; buildings drawn turned; zones put down whole with their paths; the square with its
  walls, stairs and stepped path; the stockyard twenty metres square, its floor and stair; the
  day's corners and mends), 147 commits and this one. A fast-forward: nothing else was on `main`.
  The build is gate 86's (6b78a47's code; only documents after it); `bin/` holds it.
- **The colony with no cart: closed as a call.** It is mended with the next part, **the horses
  for the cart and how the colony arrives** (the band comes pulling the cart to its spot with
  horses; it does not appear with the people), after the clear. The patch in
  `~/CASTLE_GAME/releases/wip/lords_cart_looked_for_further.patch` is not put in; it is there to
  read (what a place must be to take the cart, and the three hillside squares to try the arrival
  at: 1258 1058 at 45 degrees with a stockyard, 890 1290 at 45 degrees, 950 1290 squarely).
- The next session begins from `main` at this state, on a new branch for that part; his design
  document is still changed and uncommitted in the working copy.
