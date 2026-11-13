# The interface

- Packages: Castle.Font, UI, HUD, Input, Views, Pick, Rays, Settings
- Check: ui_check (112 checks, under a second), pick_check (38 checks, under a second)
- Saves: nothing in a game's save; the interface's scale in `saves/settings.txt`
- Stage: phase A (Handoff_2026_11_07_ui.md); stage 5a, the scaffold (Handoff_2026_11_10_stage_5a_scaffold.md); the Skills tab, stage 5b

## The interface

`Castle.UI` is the 2-D layer over the world, immediate mode: each frame the
game describes what is on screen and the layer collects coloured quads on
the CPU, then draws them in one call over the resolved frame (one buffer,
vertex pulling, like the world). Nothing is kept between frames but where
the panels were, so a click on a panel never digs the ground under it
(`Wants_Mouse`), and bottom-anchored panels are placed by last frame's
height so their buttons are hit where they are drawn.

* **Font** (`Castle.Font`, `Castle.Font_Data`). A proportional pixel font,
  5 x 7 capitals with 2-pixel descenders, drawn as pictures in
  `tools/font_glyphs.py`, which writes `src/castle-font_data.ads` (edit the
  pictures, run it, rebuild). Packed at start-up into a 96 x 60 texture and
  drawn at the UI scale with a one-pixel shadow. Printable ASCII and the
  degree sign; anything else shows as `?`.
* **The scale.** Left alone it is the window height / 450, rounded to a
  whole number (2 at 720p and 1080p, 3 at 1440p, 5 at 2160p), and at a
  whole scale the font is drawn texel for pixel, so it stays sharp. It can
  be set a little larger or smaller: **F10** and **F11** take it down and
  up a quarter at a time (1 to 8), a note says where it is, and it is
  remembered (`saves/settings.txt`, a line `ui_scale 2.25`; the step that
  lands on the window's own scale goes back to following the window).
  `--uiscale S` fixes it for a run (`--uiscale 2.5`) and beats the
  settings. At a scale between whole numbers the layout is still done in
  whole pixels (every box, rim and rule; every line of text; where each
  glyph starts), so nothing is blurred but the glyphs' edges, which take
  as much of each pixel as they cover (`Castle.UI`'s shader; the whole
  scales keep the plain texel fetch and lay out the very quads they did
  before). What shares a line (a run of buttons, the tabs) and whether a
  text is cut are decided at scale 1, so a panel breaks its rows in the
  same places at every scale.
* **Settings** (`Castle.Settings`). What the player has set that belongs
  to no game, in a small text file, a line a setting (`name value`); a
  line it does not know is kept. Only the scale today; the options menu
  will be its other reader. A scripted run (`--frames`, `--record`) reads
  no settings, so a recording does not depend on whose machine made it,
  unless it names the file with `--settings FILE`.
* **Widgets.** Panels (title bar, auto height, anchored to any corner),
  labels, headings, name/value rows, bars with a value, separators,
  buttons and toggles (a run of fixed-width buttons shares a line while
  it fits), and tables (fixed columns, left/centre/right, header rule,
  striped rows, text cut to its column with `..`). The house colours are
  a table at the top of `castle-ui.ads`.
* **Tabs** (`Tab`, `End_Tabs`): a row of tabs each as wide as its name, the
  chosen one lit; which is chosen is the caller's to keep.
* **Scroll lists** (`Begin_List`, `Row`, `End_List`): rows all one height,
  so many on screen at once. The wheel over the list scrolls it two rows a
  step (parts of a step, as a touchpad gives them, add up till they make
  one); when there are more rows than fit, a bar on the right shows where
  one is and takes clicks and drags. It scrolls by whole rows, so nothing
  is ever cut and no clipping is needed. `Row` says whether the cursor is on
  that row (it is lit), for a tooltip or a menu on it. How far it is
  scrolled is the caller's to keep.
* **Tooltips** (`Tip_Due`, `Begin_Tip`, `End_Tip`): a panel by the cursor
  that takes no clicks (it is not counted in `Wants_Mouse`) and keeps on the
  screen: left of the cursor or above it when there is no room. `Tip_Due`
  is asked once a frame with a number naming what the cursor is on, and
  says yes once it has rested on that same thing for `Tip_Delay_S` (0.3 s;
  `Begin_Frame` is told the time).
* **Popups** (`Begin_Popup`, `End_Popup`): a panel opened at a point, for
  context menus: laid out last so it is over everything, kept on the
  screen, and what is under it gets no clicks (a button of a panel beneath
  is not pressed through it). Whether one is open is the caller's to keep;
  `Over_Popup` and `Popup_Shown` say how last frame's lay, so a click away
  can close it.
* `Beside` puts text on the line of a run of buttons; `Column_Text` puts
  text in a column of the current line (cut to the column, set left,
  centred or right, with a box behind it if asked) and `Next_Line` moves
  on: a table whose rows can be a scroll list's; `Pointer` draws an
  arrow where a scripted run's cursor is.
* **The development panels** (`Castle.HUD`; everything is read from the game):
  status top left (season, day, time, sky, temperature at the camera's
  height, wind, snow and ice bars when there are any); tools top right
  (dig or place, brush, material, clickable; Ctrl still places while
  held); the block under the cursor bottom left (what it is, where, how
  high, the well that could be sunk there and its yield, moisture); debug
  bottom right on F3 (frame times, stacks, quads, streaming, edits, water);
  survey on F2 (the ten nearest deposits: distance, bearing, ore, whether
  silver or gold lies in their tips; a developer's view of what the colony
  has not found); keys on F1.
* **The band panel** (Tab), under the tools: the band's food in days and
  its confidence, then five tabs. Band: everyone in a scroll list (12 at
  once, `Band_Rows`, fewer if the window is short): the name (follow), the
  job (its menu) and what it is doing; the cursor on a line shows that
  person's tooltip, a right click its menu. Stores: what is stored of each
  kind against what is to be kept, and each stockpile by its own count.
  Camp: the camp's sheet. Orders: the reserves and the winter store as a
  minus and a plus each, and the protections. Skills: a table of everyone,
  a line each in a scroll list: name, job, and the level in each of the
  five working skills, bright where that person learns the skill fast, dim
  where slowly, boxed where it is the skill of the job it has; a line
  shows the person's tooltip and takes a right click, as in the Band tab.
  The Stores and Camp tabs show the same sheets the tooltips show; the
  Orders tab lays out the same choices the menus do.
* **Headless.** `--hud help,survey,debug,place` opens panels (and place
  mode) at the start, `--hud none` hides them, `--hud noband` the band's
  alone, `--hud stores` (or `camp`, `orders`, `skills`) opens that tab; `--mouse X Y`
  puts the cursor at a pixel so a shot shows what hovering does.

`./bin/debug/ui_check` tests the layer without a window (112 checks: the
font table, measuring and cutting text, the scale, panel sizing and
anchoring, clicks on buttons and off them, keeping clicks off the world,
tables, tabs, lists (the wheel, the bar, the row under the cursor),
tooltips (the wait, by the cursor, never off the screen, no clicks),
popups (over a panel's buttons, a click away, kept on the screen), text
in columns, the quad budget; at 2.25, 2.5 and 2.75: every box on whole
pixels, every glyph starting on one, rims one thickness, a button pressed
exactly where it is drawn, rows and text fitting as at scale 1; the
settings file there and back).

## Pointing at things

`Castle.Pick.Look` says what a ray points at: a person, a deer, a zone, a
house, or else the block. The ray is the cursor's in the view from above and will be
a reticle's on foot; whoever casts it walks it into the blocks first
(`Castle.Rays.Walk`, the Amanatides-Woo walk the edit cursor always used,
now a generic so a check's made-up world can be walked too) and hands that
hit over.

* A person or a deer the ray passes through, in front of the ground, comes
  first (the nearest of several), and never one behind a wall or a hill.
  For the ray each is a capsule: a person standing is its height tall, one
  asleep or dead lies flat behind where it stood; a deer is as tall as its
  shoulders. The game gives the shapes as they are drawn
  (`Set_Shapes`); the checks use the colony's own positions.
* Failing that, a zone: by its goods if the ray goes into them (a heap on
  a stockpile cell, the hearth), else by the ground the ray lands on if
  that is a zone's (`Castle.Colony.Zone_On`, at that zone's own level). So a low look at the pot
  finds the camp though the ray would land far beyond it.
* Failing those goods, a house (`A_House`): what the ray lands on is one
  of the colony's, its walls, its roof or its eaves, or the ground inside
  the outline of one that is begun (`Castle.Colony.House_On`). Its tooltip
  is `Castle.Views.House`; it has no menu of its own yet (a right click
  gives the ground's). The zone it stands on is pointed at beside it.
* Failing that, the block the ray went into.
* Beyond `Reach` there is nothing. The development view has no limit;
  `Reach_M` (6 m) is what the player's character will have on foot.
* `Slack` lets the ray miss a figure by so many metres for each metre away
  and still mean it (the game allows six pixels), so someone far off is no
  harder to point at than someone near; whoever the ray truly passes
  through still comes first.
* `Keep` is what was pointed at a moment ago: a person or a deer the ray
  still passes through stays the one meant, whoever steps in front, so in
  a crowd the pointer (and its tooltip) does not flit from one to the next.

`./bin/debug/pick_check` proves it on the made-up meadow: the person in
front of the zone in front of the block, a wall between, reach, slack,
two in one line of sight, goods, the camp, a deer, a sleeper, a house
begun and one standing (its ground, its roof, its front wall, out of
reach).

## Two interfaces, one layer

The panels are the development interface: dense, complete, for building
the game, on Tab and the F-keys. The player's interface will be what his
character sees and is near: a tooltip on the thing looked at, a context
menu of what he may do with it, and later reports read at a desk. Both are
made here from the same parts, and nothing of the second depends on the
first (hide every panel with F4 and it all still works):

* **Data views** (`Castle.Views`). A person, a zone or a deer as a sheet: a
  title, a note, and named rows each with a value, a tone, perhaps a bar,
  and whether the player's character could know it (by looking, or because
  he ordered it). A sheet is data, not drawing. The information belongs to
  the thing: a person's sheet is its job, who directs it, what it says it
  is doing, what it carries, the zone it stands in, its skills (the skill
  of its job with its level, a bar and how fast it learns it; its best
  three other skills; what it is apt at: all of them the player's to know,
  to give jobs to match) and (development view only) its belly and its
  mood; a zone's is what `Castle.Colony.Zone_At`
  gathers inside its borders. `Known_Only` is what the game's own tooltips
  will show. A line added to a sheet appears in every tooltip and tab.
* **Tooltips.** Rest the cursor on a person, a zone or a deer (0.3 s) and
  its sheet is shown by the cursor; what the character could not know comes
  last, under a rule. It takes no clicks and covers nothing that matters:
  it is never under the cursor. A line of the band's list shows the same
  tooltip as the person in the world.
* **Context menus.** A right click (the button let go without a drag, so
  the right-drag orbit is kept) opens the menu of what is under the cursor:
  a person (a job for each there is, its own lit, each with the person's
  level in that job's skill and how fast it learns it; follow), a stockpile
  (each reserve and the winter store, a step down and up), the ground
  (raise the stake; a path or a stockpile from here, which arms the tool
  with this as its first point; the camp here; and, with a path line or a
  stockpile half drawn, to here, or end it). The contents are
  `Castle.Actions.Menu_For (the player, the thing)`: what the action table
  permits, as things stand. A choice is carried out through
  `Castle.Actions.Perform`; a step leaves the menu open. It closes on a
  choice, on Esc, or on a click away, which goes no further (it digs
  nothing). Nothing pauses, and nothing is covered but the menu's own
  patch of screen. The camp and a deer have no menu yet.
* **Notes.** What an order came to is said at the foot of the screen for
  four seconds and put in the log: a stockpile's cells or why it was refused, a path refused
  and why (a zone in the way), a camp refused and why.
  It is not an alert: it answers something the player just did.
* **Marks.** What the cursor is on, or the open menu is about, is ringed
  on the ground (a person, a deer) or outlined (a zone, along the edge of
  its ground). Every zone is shown filled in, see-through, with a line
  round its edge (`Castle.Zone_Marks`), and the stockpile and camp tools
  show the lot the next click would take, as it would be taken. A path
  planned and not yet laid is a pale strip, as far as it is still to lay
  (`Show_Paths`). The camp's sheet has a row for its floor while it is
  being built ("Floor: 78 blocks of earth to dig off, 106 to fill", then
  "level"), and a stockpile's lists earth with the rest of what it holds;
  earth in store is drawn as a heap of clods (`Castle.Props.Clod`).
* **Esc** cancels what is on the go (the menu, the path line, the
  stockpile half drawn); with nothing to cancel it quits.
* A left click on a person or a deer does nothing (it does not dig the
  block behind them); with a colony tool in hand it is the ground's.

## A scripted pointer

A run with `--frames` or `--record` takes no real input, so
`--pointer "FRAME:COMMAND, ..."` drives the cursor: each command happens
at its frame, counted from the first frame with a colony on loaded ground
(so in a recording, frame N of the script is frame N of the video).

| Command | What it does |
|---|---|
| `move X Y` | glide to a pixel |
| `rel DX DY` | glide that far from where it is aimed (a menu's rows from where it opened) |
| `member I` | glide to member I of the band and keep on them as they walk |
| `deer K` | the same for deer K |
| `ground X Y` | the ground at X, Y (metres) |
| `click`, `rclick`, `wheel N`, `esc` | a left click, a right click, N wheel steps, Esc |

An arrow is drawn where the pointer is (with `--mouse` too). A menu opens
where it is clicked and stays there while its person walks on, so aim at
its rows with `rel` on the frame after the click, before the pointer has
followed the person away: at interface scale 2 a row is 32 px tall, the
first 54 px below the click, and a person's menu 272 px wide (192 with
skills off). For example, the forester's tooltip, then its menu, then make
it a gatherer (the second row):

```sh
./bin/castle_game --float --size 1280 720 --at 1180 1078 --cam 2.5 0.8 30 --stake 1178 1078 \
  --path 1176 1076 1194 1076 --stockpile 1180 1070 1190 1075 --camp 1172 1082 --foresters 1 --hud noband \
  --frames 400 --shot menu.png --pointer "20:member 1, 120:rclick, 121:rel 136 86, 160:click"
```

Not there yet: the player's own interface proper (a reticle on foot, reach
limited to `Castle.Pick.Reach_M`, tooltips cut to `Known_Only`: stage 7);
menus for the camp and for deer; reports at a desk; text input, windows the
player can drag, an options menu (the bindings are one table in
`Castle.Input` and the settings one file, ready for it). At a scale between
whole numbers the pixel font is a little soft at its edges: that is the
price of the step; the whole scales are as sharp as ever.
