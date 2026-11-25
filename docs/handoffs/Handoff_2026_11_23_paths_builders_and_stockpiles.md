# Castle Game handoff (2026-11-23: where paths meet what is built, the builders, the stockpiles)

Read after `Handoff_2026_11_22_playtest_notes.md`, whose report this answers. Branch
`playtest-notes-2`, made from `playtest-notes` (which is not merged: he gave no word on it), so that
the build he tries has both rounds in it and either can be taken without the other's being lost.
Nothing merged.

## His words of 2026-11-23 (whole), with fourteen pictures

> [six pictures], ok a couple of issues, we need to figure out a way to handle how paths and zone
> buildings meet up, we have blocks that aren't knocked down as you can see in some of the photos,
> we have the .5m jumps where a path is extended from square, the builder is standing on the blocks
> their placing and when the place them they fall through, maybe extend their reach a little bit,
> on top of that they walk back and fourth like a typewriter instead of a zigzag, let's also have
> builders who finish their project help finish larger projects together, lastly, the stockpile
> zones just disappeared at some point, let the player remove them if they want to, [eight
> pictures], these screenshots show some different issues, can we extend the truss to the end of
> the wall? make it symmetrical, either add another support if the length is even?, some clipping
> issues where the cart or goods are placed on top of each other, and the straw half in the ground
> and half outside, I don't know what the solution for that is, we might have to flatten
> stockpiles. There was an issue where a hunter placed the deer in the stockpile without quatering
> it, I have only seen it happen once, and I don't know what caused it.

The pictures, in his order (`~/CASTLE_GAME/TEST SCREENSHOTS/`):

| | file | what it shows |
|---|---|---|
| 8 | `swappy-20261123-005357.png` | a stair of stone where a hovel's way meets a path, the path a step over it, a corner of the square beside |
| 9 | `swappy-20261123-005354.png` | a hovel's frame beside the square's path: a strip of turf one block wide left standing between its door's landing and the path; the path beyond it a step up |
| 10 | `swappy-20261123-005353.png` | the same kind of strip at another door |
| 11 | `swappy-20261123-005351.png` | a wide floor of earth being filled, its front stepped aslant, and a serf's head showing out of the earth |
| 12 | `swappy-20261123-005349.png` | that front again |
| 13 | `swappy-20261123-005346.png` | the whole place: the square, three hovels, housing pulled north and east, a stockyard's ground being made to the west; south of the square the goods of a stockpile lie in their places with no zone drawn round them, and more goods lie by the cart to the east with none either |
| 14 | `swappy-20261119-101012.png` | night: a whole deer at the edge of a stockpile that lies aslant |
| 15, 16 | `swappy-20261119-101010.png`, `...101008.png` (one picture twice) | a frame from its end: the roof's truss narrower than the wall under it, its post off the middle |
| 17 | `swappy-20261119-101005.png` | a row of stacks, logs and sheaves, one stack through another |
| 18, 19 | `swappy-20261118-224236.png`, `...224234.png` | a stockpile on a gentle slope: sheaves half under the turf of the next block up |
| 20, 21 | `swappy-20261118-224228.png`, `...224227.png` (one picture twice) | a sack lying under the cart's wheel |

The six of the 23rd were taken with the build of `playtest-notes` (put in `bin/` at 23:17 on the
22nd); the eight others are of the 18th and 19th, before five later rounds: **each is made to
happen in today's build before anything is said of it**.

## The reading, clause by clause

| his words | read as | what is done on it |
|---|---|---|
| "ok a couple of issues" | no word on the four calls of the last report (the merge of `playtest-notes`, the builder in the pocket, the new look, deer on ledges) | none is acted on or asked again; the branch stays unmerged |
| "we need to figure out a way to handle how paths and zone buildings meet up, we have blocks that aren't knocked down as you can see in some of the photos" | a fault with a design question in it: ground left standing between a path and what is built beside it | made to happen and counted first; then a rule of mine behind a switch, put to him as a call |
| "we have the .5m jumps where a path is extended from square" | a fault: a step of half a metre where a path goes on from the square's own path | the same |
| "the builder is standing on the blocks their placing and when the place them they fall through, maybe extend their reach a little bit" | a fault, and his way of mending it: a builder works ground from beside it | his way, behind a switch |
| "on top of that they walk back and fourth like a typewriter instead of a zigzag" | the order a builder works in: each row from where the last one ended | behind a switch |
| "let's also have builders who finish their project help finish larger projects together" | a new rule | built last, in commits of its own; every number of it is mine and is listed as his call |
| "lastly, the stockpile zones just disappeared at some point" | a fault | the cause looked for and proved by a run before anything is mended |
| "let the player remove them if they want to" | a new order of the player's; and nothing but the player removes one | built; what becomes of the goods is his call, with a default |
| "can we extend the truss to the end of the wall? make it symmetrical, either add another support if the length is even?" | a can-we inside a list of faults: built behind a switch, shown old beside new | |
| "some clipping issues where the cart or goods are placed on top of each other" | faults: the sack under the wheel, a stack through a stack | **his word of 2026-11-22 on the cart stands** ("leave the cart doing whatever it's doing right now"): where the cart goes and stands is not touched; only which places near it take goods |
| "and the straw half in the ground and half outside, I don't know what the solution for that is, we might have to flatten stockpiles" | a fault whose mending he leaves to me, with his own guess | counted first; the smallest thing that mends it built behind a switch, the whole stockpile flattened put to him beside it with what each costs |
| "There was an issue where a hunter placed the deer in the stockpile without quatering it, I have only seen it happen once, and I don't know what caused it." | a fault seen once | every way a whole deer is laid down counted over long runs; said plainly if it is not made to happen |

## 1. "the stockpile zones just disappeared at some point" (73654c5)

**The cause, shown by a run.** The ground of every zone is kept as strips in one list. A zone whose
ground is read again (the square once its floor is made; a housing zone once a pad is ready) or has
some taken out has its strips put last in that list. When housing was pulled on to housing that was
there, every zone's strips were packed again in the zones' order, in place: a zone whose strips lay
last was written over the strips of the zones after it before those were moved. Each of those was
left with another zone's ground for its own. Its places and what lay in them stayed (as in his
picture 13); the ground under them was nobody's, and nothing was drawn round it.

Made to happen in one run of the game as it is played, four days, with a second pull of housing on
the third day joined to the first (`tools/today_run.sh 4 --later 72 housing-pull 1284 1058 1300 1058
2 `): the stockpile's box went from 1,598 block columns its ground to 0, the stockyard's from 6,400
to 0. Packed from a copy of the list: 1,598 and 6,400, after the order and at the end.

A save puts the strips back in the zones' order, so a run loaded from one does not show it; and a
colony founded with everything ordered at once never joins housing after a zone's ground is read
again. That is why no kept log had it. **`colony_run --later HOURS ORDER ...`** gives an order of the
player's that many game hours into a run, through the action table (housing-pull, path,
stockpile-box, job, remove-stockpile).

`colony_check`: "zones keep their ground when housing is joined to housing" (3 checks; 2 fail with
the packing in place put back).

**Not ruled out**: that the marks of a frame can also run out. A frame draws 32,768 marks at the
most and drops the rest without a word (`Castle.Marks.Strip`); zones are drawn in their order after
the planned paths. Not counted in a game with as many zones as his.

## 2. "the builder is standing on the blocks their placing ... maybe extend their reach a little bit"

**What it was.** A builder went to the middle of the work in a square metre of its site and stood
there while the square metre was made ready, all sixteen block columns at once: the earth filled in
closed over its feet, the earth dug off left it in the air.

**Counted** (`colony_run --builder-stats`: every colony second, whoever stands still with a block in
its own block column at the row of its feet or the row over it; a slope shows one block of it for
anyone standing at a bush, so the figure to read is the part "making a site's ground ready"): in the
game as it is played, eighteen days, 102 serf-seconds so, one and two blocks deep; at five other
stockyards 0, 0, 1, 5 and 11. Three blocks deep at the most (the square at 820 960; the count's "nine blocks" at the square
at 840 840 are builders standing where the turned storehouse's blocks stand unturned: section 9).
**His picture shows a head out of the earth, five blocks or more: not made to happen at any site
I ran.**

**The rule as built** (`Set_Reach_Out`, `--no-reach-out`; not saved; `Go_Beside`): his way. A square
metre is worked from a place of the walking map within 1.75 m of the middle of the work
(`Site_Reach_M`: mine), none of whose block columns that bout writes; for choice one with no work
left in it, and of those the nearest to where the builder stands; **and only one with a way back to
the stake**. The three best are tried; with none, on the square metre as before, and whoever is then
left with earth or stone over its feet is stood on it. **The builder goes all the way to that
place** (`Goes_Beside`; mended late on the 23rd: it stopped within half a metre of it, as a builder
stops short of any work, and half a metre short is another place; and a way found again on the way
could end two and a half metres off). With the rule, in the build as it is gated: 0 serf-seconds in
the ground making a site's ground ready in the game as it is played and at all five other
stockyards; once in those six runs someone was stood on earth just filled in round it.

(Two of the six stockyards are the hillside's, run with no stockpile: their bands go hungry and
the stockyard's ground is not finished in eighteen days, with the rules as without. They are in
these counts for the walking alone.)

## 3. "they walk back and fourth like a typewriter instead of a zigzag"

**What it was.** A storehouse's ground is made ready outward from the foot of its way in, by how far
each square metre is to walk from there. Square metres equally far were taken in the order of their
numbers: every row from the same end, and the builder walked the row's length back to begin the
next. Where each was worked from, written out (`--builder-track`), shows it line by line.

**Counted at six stockyards, eighteen days each**, the storehouse's ground alone, in the build as
it is gated (each builder's square metre against its own one before):

| | as it was | there and back, one builder | there and back, with help (section 8) |
|---|---|---|---|
| one square metre from the one before, on the average | 3.2 to 6.3 m | 1.4 to 1.8 m | 1.7 to 2.9 m |
| of them more than 3 m off | 77 of 418 to 194 of 291 | 13 of 384 to 25 of 262 | 33 of 411 to 157 of 458 |
| walked to a square metre | 3.7 to 6.5 m | 1.8 to 2.5 m | 1.9 to 3.1 m |

**The rule as built** (`Set_Zigzag`, `--no-zigzag`; not saved): the rows are a metre of that order
deep, and within a row the square metre nearest to where its builder stands is next. The order of the
rows is as it was (what is dug has its way out). A hovel's ground was worked so already (1.4 m on the
average, 1.2 with the builder standing beside its work).

**With three at one floor each walks further between its own square metres** (the third column:
at five of the six stockyards three build the storehouse's ground from the first day). All three
take the nearest of the same row, so each steps past the two others. Having each take first what it
stands nearest to was tried and measured: no better (2.4 to 2.8 m), and dropped.

**The builder in the pocket of ground** (found 2026-11-22, his to open, not opened): she stood on the
square metre she dug at her lot's corner, with ground she never came to make between her and the
rest. With these two rules alone (d8b9255) the same 41 days of the game as it is played ended with
thirteen living, no line of anyone starving, and a way out of that place on the morning she was
first seen in it (`--try-plan`); the log kept with the gated build has thirteen living and no such
line either. **Those runs say so and no more**: the save with her already in the pocket, run on,
still ended with her dead, and nothing proves that no pit is left anywhere.

## 4. "we need to figure out a way to handle how paths and zone buildings meet up"

**What was made to happen, and what was not.**

- **"the .5m jumps where a path is extended from square"**: made to happen at once. A path ordered
  north from the north-west corner of the square of the game as it is played
  (`--later 96 path 1231.5 1064.5 1231.5 1090`): the square's path lies at its floor's level,
  18.25 m, and the first quarter metre of the new path at 18.75 m, across all four of its block
  columns. Likewise a path at 45 degrees from another corner, and at a second square (860 880): up to
  three blocks there.
- **A door's way half a metre off its path**: found by the same count, not named by him: three pairs
  of block columns in the game as it is played once its hovels stand.
- **"blocks that aren't knocked down" (his pictures 9 and 10: a strip a block wide and a metre long
  between a door's landing and the path, a block over both): not made to happen.** A count of
  columns of earth standing over trodden ground on one side and trodden ground or a hovel's lot on
  the other found none at eight layouts, counted every two days of sixteen. Read from the pictures:
  the strip lies inside the pale square the game draws for the door's way, at its end, where the
  square's path steps down beside it: a step of the way planned against the path's ground as it
  lay when the hovel was placed, left standing when the path came to lie lower. **That is a reading,
  not a finding.**

**Why they do not meet.** Each is planned by itself and at another time. A hovel's way is planned
when the hovel is placed, against the ground where it will meet its path. The path is laid later: a
metre at a time, each brought to the path's own line (the middle height across its width, smoothed
over a metre before and behind) where that is within half a metre; the square's own path to its
floor's level, a quarter metre of its length at a time, whole or not at all. Nothing looks at what
the other came to.

**The two rules as built** (both mine, each with its switch, neither saved):

- **A path is stepped where it meets trodden ground** (`Set_Paths_Meet`, `--no-paths-meet`). When a
  metre is laid, the columns of path within two metres of it are looked at again: one two blocks or
  more over trodden ground beside it has a block cut off it; one two blocks or more under ground
  that is never moved has a block of earth put under it; until none does, or it has been moved two
  blocks. A jump of half a metre becomes two steps a quarter metre apart. Never moved: the square's
  own path, the strips kept for its walls, any zone's ground.
- **A door's way is made again to its path as it lies** (`Set_Door_Meet`, `--no-door-meet`). When a
  hovel's ground is ready, and again when it stands, the columns of its way past the landing are
  made again between the landing's level and the laid path's top, a block a column; where the way
  has not columns enough, the path's edge before it is stepped (never the square's own).

**Counted at eight layouts**, sixteen days each (`colony_run --seam-stats`; pairs of block columns
side by side, both trodden, two blocks or more apart, at the end):

| layout | these two rules off (the round's others on) | both rules |
|---|---|---|
| the game as it is played (housing pulled east) | 3 | 0 |
| the same square, hovels along its own path east and west | 0 | 0 |
| the same square, housing pulled off two of its corners | 14 | 0 |
| a square at 860 880, hovels along its own path | 8 | 4 |
| the same, housing pulled off two corners | 8 (up to three blocks) | 4 (two blocks) |
| a square at 45 degrees at 840 840, housing pulled east | 0 | 0 |
| a square at 820 960, hovels along its own path (none built in sixteen days) | 0 | 0 |
| a square at 950 1290, housing pulled east | 0 | 0 |

(With every rule of the round off the first layout counts 0 on its sixteenth day: six of its eight
hovels stand by then, and the three pairs are at the two that do not.)

**Left, and counted**: the eight pairs that stay are two hovels that front the square's own path
where that path was brought to the floor's level, two and three blocks over the hovels' floors,
after they were placed. Their ways have one column for a step. Mending it means placing a hovel
against the square's path as it will lie, which is known when the square is founded: not built.

`colony_check`: "a path stepped where it meets trodden ground, and a door's way made again to its
path" (5 checks: each rule fails its count without it on made-up ground).

## 7. "a hunter placed the deer in the stockpile without quatering it, I have only seen it happen once"

**Every way a whole deer is laid down, counted.** There are three in the code: its carrier is given
another job; there is nowhere to butcher it (no room, or no way there) and its carrier is hungry or
night has come; its carrier dies. A count was put on each, and on whether it happened on a
stockpile's ground (`Castle.Colony.Carcasses_Dropped`; `colony_run --carcass-stats`, which also says
every whole deer that comes to lie on a stockpile's ground and for how long).

- **By the band's own doing: not once.** Six runs of 41 days (the game as it is played, with and
  without a storehouse, three other squares, five hunters for three; the gated build): 187 deer
  killed, none laid down unbutchered, none ever lying on a stockpile's ground.
- **By the player's: made to happen.** Each of the three hunters given another job at every quarter
  hour of the first three days, a run each (855 runs; the gated build with this rule off): in 18 the
  hunter had a deer on its shoulders and put it down where it stood; in 4 of those that was on a
  stockpile's ground, where it lay 12 to 28 colony seconds until another hunter took it up (at the
  rule's own commit: 19 and 2, there 40 and 48 seconds). **With no other hunter it lies there for good** (only a
  hunter fetches a deer that lies). **With the rule: in none of the 855.**

Whether that is what he saw I cannot tell: his picture (night, the 19th) shows the deer and nothing
of who put it there. The development entries of a person's menu arrived that day.

**The rule as built** (`Set_Kill_Home`, `--no-kill-home`; not saved): a deer is butchered by whoever
carries it home. Given another job with a deer on its shoulders, it brings the deer home and
butchers it first, then takes up the job; only with nowhere to butcher it does it put it down, as
before. `colony_check`: "a deer is butchered by whoever carries it home" (2 checks: a lone hunter
made a porter with its kill, both ways). No kept log has a job given mid-run, so none moves.

## 6. "the straw half in the ground and half outside ... we might have to flatten stockpiles"; "the cart or goods are placed on top of each other"

**What it was.** A stockpile's place is a square metre, sixteen block columns. What lies on it is
drawn at one height, that of the place's middle (the highest of the four columns round it). The
ground under a stockpile is left as it lies: where it steps under a place, the columns a block
higher stand through whatever lies there (his sheaves, pictures 17 to 19) and those a block lower
leave it over air.

**Counted** (`colony_run --place-stats`; the gated build with this one rule off): in the game as it
is played, of the 47 places that held something at the end of the third day 21 had a column over
the place's level and the other 26 one under it (two blocks at the most); of the 13 at the end of 41
days, 5 and 8. Every one.

**The rule as built** (`Set_Place_Level`, `--no-place-level`; not saved): from the moment a place
holds something or has something on its way, its block columns are brought to the place's own
level, three blocks at the most, their tops as they were. Each place by itself: a stockpile on a
slope becomes steps a metre square, and nothing is moved under a place nothing is put on. With it:
none of 51 places off its level at the end of the third day, none of 11 at the end of the 41.

**His own guess, not built: the stockpile flattened whole.** One level under all hundred places
would on that ground mean cutting and filling up to a metre at its ends and a wall of stone where
the land beside stands more than a block off it, as the square and the stockyard have; and somebody
to do it before the first load is put down. Put to him as a call.

**The cart.** Nothing was put on the two places under its bed; but it is drawn with a wheel to
either side of the bed and its shafts before it, over the places beside and before those two (his
sack, pictures 20 and 21). Nothing is put on those either now (`Set_Cart_Room`, `--no-cart-room`;
not saved): six places more. Where the cart goes and stands is untouched, by his word of 2026-11-22.

**"goods placed on top of each other": read, not counted.** In picture 17 one stack stands through
another and baskets seem to sit on a stack of logs: the stockpile rises toward the back of the
picture, a metre a row, and the camera is low, so the row behind shows over and through the row in
front; the one thing in it that is in the ground is a stack cut by the step it lies across (the
first rule). The props fit their square metre (a log stack 84 cm across). No count was made of one
thing lying in another.

`colony_check`: "a stockpile's place made level when something is put on it, and room round the
cart" (4 checks, each both ways).

## 5. "can we extend the truss to the end of the wall? make it symmetrical"

**What it was** (drawn block by block from the blueprint, `truss_dump.adb` among the one-off
scripts): a gable's rafters, two blocks deep, came down to the wall's top beam three blocks in from
either corner, so the triangle was six blocks narrower than its wall; and its king post stood at the
lower of the two middle places where the span is an even number of blocks (188 of four hundred
hovels; the storehouse, 20 and 32 blocks across).

**As built** (`CB.House.Full`; `Set_Full_Truss`, `--no-full-truss`; a house keeps how it was begun,
saved: blob 45):

- the line of each rafter goes on down through the wall's top corner to its corner post: three
  blocks of timber where there was daub, at either end of each gable;
- an even span has two king posts side by side, in its gables and on a storehouse's tie beams, and
  two ridge beams: his "another support".

Twelve blocks of timber more for an odd span, 41 to 47 for an even one (a log makes 96), 84 for the
storehouse of 40 by 20. A house begun before keeps the truss it has. `colony_check`: "the truss to
the ends of its wall, the same either side of its middle" (8 checks, two of them a hovel saved
and loaded: at its frame, and standing).

**Not done**: the rafters on a storehouse's tie beams are one block deep and begin two blocks in
from the wall; they stand on the tie beam, which runs to the wall, and were left.

## 1b. "let the player remove them if they want to"

**The order as built** (`Castle.Colony.Remove_Stockpile`; the action `Remove_Stockpile`, on a
stockpile's own menu: "Remove this stockpile", and then "Keep this stockpile"; saved: blob 46).
Nothing but this order takes a stockpile away.

- **What becomes of what lies on it: carried off first** (mine: his words do not say). Its places
  are closed from that moment: nothing more is put there, what lies there is taken from first by
  whoever takes from the stores, and a porter with empty hands carries a load of it to a place with
  room elsewhere before anything else of its work. When nothing lies there and nothing is on its
  way, the stockpile is gone: its ground is no zone's, its places are no more. An empty one is gone
  at the next colony second.
- **With no room anywhere else** what lies there stays, and so does the stockpile, closed, until
  there is room or the order is taken back. **So the only stockpile, removed with none put down
  in its place, leaves the band nowhere to store and it starves** ("Found, not mended", below).
- **The order taken back** opens its places again.
- **Never the stockyard** (refused: its storehouse is built on it).
- **The cart** standing on it is left where it stands; the band then pulls it to another stockpile,
  as it pulls it to any (nothing of the cart was changed).

**Run** (the gated build): the game as it is played with no storehouse, a second stockpile put down
after two days and the first ordered removed after three (`--later 48 stockpile-box 1225.6 1058 2
--later 72 remove-stockpile 2`): 66 sheaves among what lay on it; gone 23.3 game hours later;
thirteen living at the end of eight days; the cart on the other stockpile.

`colony_check`: "the player removes a stockpile" (8 checks: through the action table, the menu's
row, a save half way, a porter carrying it over, taken back, an empty one).

**Not done**: the order is on the menu only. No tool draws a box round stockpiles to remove them, as
the housing's does; and what is being removed is drawn as any stockpile is (the yellow frame), with
nothing to say it is going but its menu and that nothing is put on it.

## 8. "let's also have builders who finish their project help finish larger projects together"

**The rule as built** (`Set_Build_Help`, `--no-build-help`; not saved). Every number in it is mine.

- **Who**: a forester that could take a house (the best free at building, while fewer than four
  build) and finds no house without a builder.
- **Where**: a larger house that is being built: one whose blueprint is more than 6,000 blocks
  (`Help_Over_B`: a hovel's is some 3,400, the storehouse's some 15,000, so today the storehouse),
  the one with the most still to lay, where no more than three build already (`Help_Most`).
- **What it does there**: all a builder does. It makes ready a square metre of the ground that
  nobody else is at, fetches what the house is short of, lays the next blocks of its blueprint.
- **When it leaves**: a house has no builder (it takes that one); the roof is being thatched (one
  ladder, one thatcher: it comes back for the yard). Else it stays until the house stands.
- Helpers count among the four builders of his word of 2026-11-17.

**Measured** (`colony_run --builder-stats`, "helping"):

| | one builder a house | with help |
|---|---|---|
| the game as it is played (eight hovels to build): the storehouse stands after | 17.26 days | 16.04 days |
| help given there | none | 4,859 serf-seconds, three builders at it at the most |
| the same with two hovels to build: the storehouse stands after | 15.21 days | 9.97 days |
| three other squares with a stockyard and no hovels to build: after | 15.35, 13.29 and 13.46 days | 8.44, 8.24 and 8.07 days |

(The gated build.) In the game as it is played the three foresters are at hovels until the
fourteenth day, so help comes only for the storehouse's roof timbers and yard. Nobody died in any
of those runs.

`colony_check`: "builders with no house of their own help at a larger one" (2 checks: three
foresters and a storehouse on the meadow, both ways; each had a way back to the stake at every look).

**Not done**: a helper does not take the ladder or thatch; two builders of one house may both fetch
the last load it is short of (one lies there over).

## 9. Not in his words: people standing with their feet in the ground

**Found when every figure above was measured again in the last build.** `colony_run
--builder-stats` counts every colony second someone stands still with a block of the ground in its
own block column at its feet. I had read only the part of it that is a builder making ground ready.
The whole of it, in eighteen days of the game as it is played:

| | serf-seconds so | where |
|---|---|---|
| the game before this round (every rule of it off) | 517, in 79 times, the longest 196 s | 102 a builder in its own fill; the rest mostly round the square and the stockpile |
| with this round's other rules | 2,540, in 118 times, the longest 342 s | nearly all at the stockpile, eating or looking for work, a block deep |
| with the rule below | 3, in 3 times, a second each | at the stockpile, looking for work |

**So this round had made it five times worse.** With the places made level alone taken out
(section 6: a place made level is a step a metre from the next, and people stand at its edge) the
count is 703; with that and the room round the cart taken out, 238. Single runs, each a game
that goes another way from its first hour: they say which rules the count hangs on, not by how
much each.

**The cause, which is older than the round.** A way is a line of points, one wherever the height
changes; that point is put the first eighth of a metre inside the next place of the walking map.
Between two points a walker kept the height of the one it had left: for that eighth it walked in
the step it was climbing. And a walker stops as soon as its work is within reach: the same few
centimetres past the same edge every time. Whoever stopped there stood in the step until it next
walked. (Watched second by second with `colony_run --watch MEMBER S0 S1`: a builder stopped five
centimetres into earth it had filled in seven seconds before, its feet half a metre under the top.)

**The rule as built** (`Set_Step_At_Edge`, `--no-step-at-edge`; nothing to save;
`castle-colony-walk.adb`): a walker has the next point's height from where it enters that point's
place of the walking map. It is on for everyone who walks. Held off in the reference runs, the
stress runs and `colony_check`'s `Reset`, as the round's other rules are.

`colony_check`: "a walker at the height of the place it steps into as it steps into it" (2 checks:
on a meadow made a block higher past a line, fourteen bushes a picker's reach past it: 51 of 652
serf-seconds standing there were in the step; none with the rule).

**The feet against the walking map's floor** (`--feet-stats`, the older measure, the same eighteen
days): 56 serf-seconds more than a block off it with every rule, 558 with this one off.

**Left**: those three serf-seconds (why was not looked into). And at a
square at 45 degrees the count has builders standing where the turned storehouse's blocks stand
unturned (22 serf-seconds "nine blocks deep" at the square at 840 840: they are where the
storehouse is drawn. That nothing of it shows in the picture is a reading of how a turned
storehouse is walked: no still was taken of it).

## Found on the way, and what became of each

**Mended, each in a commit of its own or said in one:**

- **Every save in which a hovel with the fuller truss stood was refused by the build that made
  it** ("no colony in that save": the world loaded, the band and all it owns did not). From the
  truss's commit (c7981c0) to 217ece1, five commits, one of them through a gate that passed;
  **none of those builds was put in `bin/`**, which held 3333aa2 throughout. A load held what was laid of each house
  against its blueprint before it had read which truss the house has: a hovel that stands with the
  fuller truss has 3,440 blocks laid, the blueprint of before 3,418. The first mend of the load
  (893848a, "measured before its truss was known") measured the house again and left that test
  where it was. Found by a save of the game as it is played on its fifth day, made to try a
  stockpile removed and gone; no check and no script of the gate had ever saved a colony with a
  hovel of the new truss standing. (An hour before, I had loaded such a save into the game for a
  still: it showed the storehouse and its yard and nobody in them, and I did not see that.) Mended (the test is made once the truss is read), with a check
  that fails without it, and **the gate now saves the game as it is played on its twentieth day,
  loads it and runs it on to the straight run's state** (`tools/today_check.sh`; with the build of
  217ece1 it fails: "load failed: no colony in that save").
- **People standing with their feet in a step** (section 9): older than the round, made five times
  worse by it, and not seen by me until every figure was taken again from the last build. A walker
  is at the height of the place it steps into.
- **A builder half a metre short of the place chosen beside its work** (section 2): the place was
  chosen because the bout writes none of its block columns, and the builder stopped before it. It
  goes all the way there.
- **Someone in a wall of a turned hovel as it is drawn** (009fd32). `tools/turned_streets.sh` failed
  at one of its three sites once this round's rules had moved who walks where: a gatherer went
  through the corner of a turned hovel's wall, seventeen game minutes after its roof was finished.
  When a house comes to be walked as it is drawn, every way being walked was looked over step by
  step, and a leg across the new wall was taken for good still. The way is found again outright
  now. With the band varied eight ways at that street: 0 of 8 runs with the round's rules off, 3 of
  8 with them on, 2 of 8 with only the builder beside its work off; 0 of 16 with the mend. None of
  the round's rules put anyone in a wall.
- **A loaded house measured before its truss was known** (the review before the gate). Blob 45
  writes which houses have the fuller truss at the end; a load measured each house (its blueprint's
  count, its stages) before reading that, so a half-built hovel loaded with the count of the other
  blueprint: 3,418 blocks for its 3,440. "The same bytes" could not show it (the count is not
  saved). Measured again once read; a check fails with that cut.
- **The truss's commit (c7981c0) left fifteen checks of `colony_check` failing** (not run whole
  before it was committed): the checks that make an older blob by cutting bytes off the end of a new
  one. Mended in the commit after (a59d223).
- **Helpers at hovels** (the review). The rule as first committed (0ac662c) counted any house whose
  ground was not ready as larger than the threshold, and I had a hovel at 2,100 blocks where it is
  some 3,400: helpers went to hovels' ground while the documents said "the storehouse". The rule is
  by the blueprint's size now (more than 6,000 blocks), and the figures above are of that.
- **A path's column moved at the edge of what was looked at** (the review): it could be put further
  off ground outside that. Edge columns are left alone; the eight layouts count as before.
- **A removed stockpile still counted as one** (the review): `Stockpile_Count`, a stockpile's
  number and the Stores tab pass over its emptied zone now.

**Found, not mended:**

- **A band whose only stockpile is ordered removed, with none put down in its place, starves.**
  The game as it is played, its one stockpile ordered removed on the third day and nothing else
  done (`tools/today_run.sh 41 --later 72 remove-stockpile 2`; the stockyard is closed until its
  storehouse stands): the stockpile is closed and never goes (there is nowhere to carry what lies
  on it); the band eats what lies there, and from the seventh day everyone is hungry ("the stocks
  are full": nothing can be put down, the foresters stop building, the storehouse is never
  begun); **all thirteen die of hunger on the twenty-seventh and twenty-eighth days**. It is the
  game's own rule for a band with no stockpile, come back by the new order; and the message on the
  click ("what lies on it is carried off first") says nothing of it. The order taken back ("Keep
  this stockpile") opens it again. **His call (3, below), found after the gate: nothing was changed.**
- **At the square at 950 1290 all thirteen die of hunger within 41 days**, with every rule of this
  round off as with them on (the first on the second day's count; "no cart", 24 and 26 deer
  unsalted). It is one of the three squares known since 2026-11-22 to get no cart (his word: mended
  with the arrival); that the band dies there had not been said.
- **A stockpile's place on a steep bit can keep columns far off its level** (the rule moves three
  blocks at the most): with a second stockpile put down west of the
  square after two days, of 68 places that held something at the end of eight days 4 had a column
  under the place's level, up to five blocks (57 of 71 with the rule off). Beside none of 51 and
  none of 11 at the first stockpile.
- **The camp's floor is made ready from on it too** (the square's floor: one case of someone two
  blocks in the ground in eighteen days). The rule of section 2 is of a house's site alone.
- **The strip of turf of his pictures 9 and 10** was not made to happen (section 4).
- **Whether a frame's marks run out** (section 1) was not counted.
- **Two bands with a stockyard and no stockpile go hungry** (the hillside's box stockyards as I ran
  them for the builders' counts: all thirteen hungry by the eighteenth day, the stockyard's ground
  not finished, with this round's rules as without). Not looked into: a stockyard put down with no
  stockpile is not how the game as it is played begins.
- **Three builders at one floor walk round one another** (section 3): measured, one mend tried and
  dropped.

## What was run, and what could not show

- **Every figure above is of the code of 217ece1** (the gated commit after it changes how a save
  is read and nothing a run does), taken again from it by one script
  (`measure.sh`, among the round's scripts in `~/CASTLE_GAME/releases/wip/scripts/`), but where a
  line says "at the rule's own commit". Taking them again moved six of them and showed section 9.
- **With all ten switches off** (`--no-reach-out --no-zigzag --no-paths-meet --no-door-meet
  --no-kill-home --no-place-level --no-cart-room --no-full-truss --no-build-help
  --no-step-at-edge`) the game as it is played, 41 days, is the log kept before the round, line
  for line (its state is another: the blob's version). The eight reference logs, which hold the
  rules off, are line for line.
- **A save of the build he has** (`bin/` of 3333aa2, the sixth day of the game as it is played: a
  stockpile with goods on ground that steps, hovels half built with the truss of before, the
  storehouse's ground half made), loaded into the gated build and run on twenty days: nobody died,
  eight hovels and the storehouse stand, none of 15 places off its level.
- **Saved and loaded**: the game as it is played saved on its tenth and on its twentieth day and
  run on to the forty-first: the straight run's state, both times (the twentieth is in the gate
  now). **A stockpile removed and gone**: saved half a day after it was gone, and again after a new
  stockpile was put down on the freed ground (99 places, not refused), each loaded and run on to
  the eighth day: the straight run's state. A stockpile being removed and a hovel at its frame and
  standing with the fuller truss (the checks); the squares and stockpiles of
  `tools/square_sites.sh`. **Not** swept: a save in the tick a stockpile's place is made level, or
  a builder half way to the place beside its work (both are told from what a save holds; no run
  was made of it).
- **The only stockpile removed**, with a second put down first (sections 1b and above: carried
  over, gone in a day, nobody hungry) and with none (thirteen dead: "Found, not mended").
- **The player's own gesture**: "Remove this stockpile" was clicked in the game (release, a save of
  the third day) by the scripted pointer: the row at the foot of the stockpile's menu, the message
  ("the stockpile is to go: what lies on it is carried off first"), "Keep this stockpile" on the
  menu opened again (sheet 5). No mouse was moved, and the debug game was not clicked.
- **In the game's window** (release, his game not running): the sheets are of the gated code
  (2 and 4 taken again with the gate's own programs; 1 and 5 with the build of the commit before,
  which differs in how a save is read alone), but the truss's (the build of a59d223: the truss has
  not changed since); each
  of the four saves left for him loaded in the gated runner, and the last of them in the gated game
  with its log read (the band is there). The debug game was not walked through by hand this round:
  the gate runs the three site scripts in debug, and the game as it is played, 41 days, ends in the
  same state in the debug build as in the release build (d5bb6e2fdd00202f).
- **What no run showed**: his picture 11's builder, a head out of the earth (one and two blocks in
  every count); the strip of turf of pictures 9 and 10; who laid his deer down. **A still of
  section 9's fault was tried and dropped**: at a step's edge a figure a block deep reads, at any
  angle I took, as someone standing against the step.

## The gate

Three, each from a clean copy by `tools/gate.sh`; their summaries are kept in
`~/CASTLE_GAME/releases/wip/logs_2026_11_23_paths_builders_stockpiles/`.

- **On 893848a** (nine rules and the first review's four mends): "gate done: passed", 55 minutes.
  **It passed a build that could not load a save of its own with a new hovel standing**: nothing in
  the gate tried one.
- **On 217ece1** (the walkers' height, the builder's walk): stopped by me after its nine checks,
  when the refused saves were found.
- **On a3046d7** (the mended load, the gate's new part): **passed**, 54 minutes. Both builds from
  nothing with the six known warnings and no other. The nine checks in debug: `water_sim_check` 77,
  `edit_check` 41, `ui_check` 112, `dynamics_check` 18, `serf_check` 21, `path_check` 88,
  `colony_check` 1,110 (1,073 at the last round's gate), `deer_check` 19, `pick_check` 78. The eight
  reference logs line for line. The game as it is played line for line and to its state
  (d5bb6e2fdd00202f), **and saved on its twentieth day, loaded and run on to the straight run's
  state** (new). The stockyards (17 lines), the turned streets (3) and the squares (10), in release
  and in debug: nobody died or was said to be starving at any. The herds' places as at the last
  round's gate (800 herds at 400 stakes, none on a tree's trunk, none where a deer cannot walk off).
  The stress runner: nothing died, nothing dropped, every state as in the gate on 893848a (its
  runs hold the round's rules off). The flora hash the same in both builds.
- Set beside the gate on 893848a, sorted, timings aside, 77 of its 118 lines differ: the site
  lines (their runs have the round's last two rules in them), `colony_check`'s count and the
  played game's two lines. No stress state and no hash.
- After a3046d7: documents alone (this handoff's close, the state page).
- **Not every commit of the round was built and checked alone.** c7981c0 fails fifteen checks of
  `colony_check` by itself (above); c7981c0, a59d223, 0ac662c, 893848a and 217ece1 cannot load
  their own saves with a new hovel standing. Whoever bisects through this branch starts from
  a3046d7.

## What he might take for a fault

- **Removing the only stockpile without putting another down first starves the band** (found,
  above; call 3).
- **Two builders on the very same spot.** Helpers lay the same next blocks of the storehouse from
  the same place: in eighteen days of the game as it is played, 52 seconds with two of the three
  foresters standing still within 30 cm of each other at work on the storehouse (trimming its
  thatch, smoothing its coverings), beside 53 eating, picking or idle so. With every rule of the
  round off: none at the storehouse, 2 at a hovel, 43 eating, picking or idle. It is in the save
  `three_at_the_storehouse_day_35_noon`. And making its ground ready,
  for the four or five seconds of a square metre: 8 times in the 2,524 square metres of the six
  stockyards' runs (each walks to the middle of the place it chose, and a place another is still
  walking to is not yet taken).
- **A stockpile he has removed leaves its steps behind**: the places made level stay as they were
  made.
- **A removed stockpile's zone keeps its number, empty**; the next stockpile takes a new one (256
  zones in all).
- **Three builders at the storehouse's floor walk round one another** (section 3).
- **A stockpile on a slope is steps a metre square** under what lies on it (the turf is kept
  on them). Only places that have held something are moved, so a half-used stockpile is
  part stepped and part as the land lies.
- **A stockpile ordered removed looks like any other** until it is gone (a day in the run above):
  its menu says "Keep this stockpile", and nothing more is put on it.
- **Houses that stand keep the truss they have.** Only a house begun from now on has the fuller
  one; a street begun before and finished after is mixed.
- **A hunter given another job goes on carrying its deer home** and butchers it before it takes
  the job up.
- **Helpers leave the storehouse while its roof is thatched** (at two noons of the game as it is
  played one was looking for work and one carrying a log to the stockpile), then come back for the
  trimming and the yard.
- **At the square's own path, where it was raised after a hovel was placed in front of it**, the
  hovel's way still ends half a metre under it (section 4: eight pairs at two layouts).

## What it costs

The 41 days of the game as it is played run in 20 s with every rule on, 22 s with the walkers'
height at a step as it was, and 170 s with every rule of the round off (twice each, a quiet
machine; where the 150 s go was not looked into: that run is the one with the builder shut in her
pocket). The stress runs and `tools/look_cost.sh` hold the round's rules off, so the gate times
none of them. A stockpile removed, and one then put back on its ground: twelve days of the game
as it is played with no storehouse in 8.1 and 8.0 s for 8.0 without, the ground widened once in
each. Memory was not measured.

## His calls

Nothing here is done on silence. The four of 2026-11-22 (the merge of `playtest-notes`, the builder
in the pocket, the new look, the deer on ledges) had no word from him and are not asked again.

1. **Merge `playtest-notes-2`?** It stands on `playtest-notes`: merging it takes both rounds.
2. **A stockpile flattened whole, or each place by itself?** Built: each place, when something is
   first put on it, three blocks at the most. His own guess was the whole stockpile at one level:
   that is cutting and filling up to a metre at its ends on the ground of the game as it is played,
   walls of stone where the land beside stands more than a block off it, and somebody to do it
   before the first load. Default: as built.
3. **What becomes of what lies on a stockpile he removes, and what when it is the only one.**
   Built: carried to another stockpile first, and the stockpile stays, closed, while there is no
   room elsewhere; **with no other stockpile that is for good, and the band starves** (found,
   above). The other ways: (a) the order refused, with a line saying why, while there is no other
   stockpile with room (what I would build); (b) the stockpile kept open until what lies on it
   has somewhere to go; (c) gone at once, what lies on it left on the ground where it lies. On no
   word: as built, and the report says not to remove the only one.
4. **Who helps, where and how many.** Built: a forester with no house of its own to build, at a
   house of more than 6,000 blocks (today the storehouse alone), three at the most, none at the
   thatching. His words were "larger projects": hovels are not helped at. Default: as built.

Numbers of mine, his to tune: a builder's reach beside its work 1.75 m (`Site_Reach_M`); a path
looked at again within 2 m and moved two blocks at the most (`Meet_Reach_B`, `Meet_Most_B`); a
place moved three blocks at the most (`Place_Level_B`); the six places round the cart
(`Cart_Reaches`); the helping's 6,000 blocks and three (`Help_Over_B`, `Help_Most`).

## His answers (2026-11-23, to the four calls above)

> 1. merge 2. flatten the stockpile, let's just make this easy for ourselves. 3. just leave the
> stockpile for the moment, we can get to that when we do the horses and carts, 4. as built

| his words | the call | what is done on it |
|---|---|---|
| "1. merge" | merge `playtest-notes-2` | `main` fast-forwarded from da7c7b9 to fa3f1b3 (25 commits: both rounds). To undo: `git checkout main && git reset --hard da7c7b9`. |
| "2. flatten the stockpile, let's just make this easy for ourselves." | a stockpile flattened whole | a new piece, on a branch of its own from `main` (`stockpile-flat`), behind a switch; each place by itself stays as the switch's other way. **A figure of mine he chose on was wrong**: I wrote "up to a metre at its ends"; the tops of the ground of the stockpile of the game as it is played lie sixteen blocks apart, four metres (19.50 to 23.50 m; `colony_run --flat-scan`). As built (`Handoff_2026_11_23_a_stockpile_is_one_level.md`) its floor lies at the level of its path side: a cut of four metres at its far corner and a fill of half a metre at its front. (This row first said "some two metres of cutting at one corner and of filling at the other": that was of a level at the middle of its ground, which is not the one built.) Nor were the "walls of stone" and the "somebody to do it" of that call built. Said first in the next report. |
| "3. just leave the stockpile for the moment, we can get to that when we do the horses and carts" | what when the only stockpile is removed | left as built; on hold in his words, with the horses and carts (`State.md`). The band still starves if its only stockpile is removed and none put down. |
| "4. as built" | who helps, where and how many | stands as built. |

## Not done

- The horses for the cart and how the colony arrives: his to open, with its four calls (`State.md`).
- The cart, the logistics passes, the design document's mechanics: on hold, in his words.
- No tool draws a box round stockpiles to remove them; a stockpile being removed is drawn as any.
- Builders of one house keep no distance from one another (above).
- A hovel placed against the square's path as it will lie (section 4's eight pairs).
- A storehouse's tie-beam rafters (section 5).
- The camp's floor is still made ready from on it (found, above).

## Next

His word on the calls; else the arrival, when he opens it. A session starts at
`docs/production/State.md`.
