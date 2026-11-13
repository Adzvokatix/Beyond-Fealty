# Castle Game handoff (2026-11-11: the sky and the weather's look, and a stress test, before stage 6: the sun's dark disc, a moon, the clouds walked through, mist, wet surfaces, a table of lights; then, from John's answer, moonlight, the moon's phases and stars; accepted as built the same day and merged into `main`; Claude Code)

- **Closed: accepted as built.** John, after trying both rounds and the pathing work on top of them:
  "perfect, everything checks out, looks awesome and works great". `sky-and-weather` (from `main` at
  bc0204e) and `pathing` are fast-forwarded into `main`; both branches are kept. Built in two rounds
  with first rules and values of mine: they stand as first values, his to tune. The calls below that
  he did not take up stand by default.
- **His answer to the first round** (the same day): "Moonlight on the land, phases, stars. Sounds great,
  MSAA keep it, no need to save a milisecond, if it becomes an issue later we can deal with it then. Time
  budget we will leave out for now, so we don't interfere with production." It answers three of the four
  calls put to him and names more work; it does not say he ran the build, so nothing is recorded as
  accepted (the same shape as his first answer to the models pass). Round two is the moon, below. The
  rest of his message opened pathing: branch `pathing`, on top of this one, with a handoff of its own
  (Handoff_2026_11_11_pathing.md).
- **Stage 6 (habitation, with stockpile mechanics rolled in) is still his to open.** Nothing of it is
  designed. If he accepts this, fast-forward the branch into `main` and remake the zip from `main`, as the
  last three closes did.
- Code: GAME_alpha_1_3/compiled, branch `sky-and-weather`.
  - 6204b13 the sky (the sun's disc, the moon, the clouds walked through; the drawn time stepped in a
    recording; `tools/look_cost.sh`, `tools/stress.sh`);
  - 03dfccb mist;
  - 1448c49 wet surfaces (and the land's program built twice);
  - 6c68c29 lights (and `--no-needs`);
  - e9a786e the stress test's own changes (dropped work said once, `--hitch`), the documents and the
    demo's script; 9698f6b the land drawn nearest first, and what multisampling costs; documents after.
  - Round two: ccfa65e the moon's phases, moonlight on the land with shadows, stars; fab638c the
    afternoon moon pale and not lilac, and the second demo's script.
  - Zip: CASTLE_GAME/releases/castle_game_sky_weather.zip (a `git archive` of the branch, remade after
    round two). Demos: sky_and_weather.mp4 (tools/demo_sky_weather.sh), 51 s, of round one;
    moon_and_stars.mp4 (tools/demo_moon.sh), 31 s, of round two.
- Checks after round two, from a clean copy of the branch's last commit that changes code (fab638c),
  built from nothing in debug and in release: the six known warnings and no other; all nine checks
  pass in debug; `tools/reference_check.sh` passes, all seven runs against `main`'s logs, line for line
  (nothing of either round touches a step of the colony); `tools/shadow_still.sh` reads 0.00 % by day,
  under a winter full moon, and through the dusk where the lamp changes from the sun to the moon.
- Checks, from a clean copy of the branch's last commit that changes code (9698f6b), built from nothing
  in debug and in release with the six known warnings and no other; all nine checks pass in debug (colony_check 422, water_sim_check 77);
  `tools/reference_check.sh` passes, all seven runs against their kept logs, line for line;
  `tools/shadow_still.sh` reads 0.00 % at one game minute a second, at three, at dusk, with everything
  wet, and in mist; a cloudy sky recorded for two seconds has no pixel stepping by more than six levels;
  `./bin/flora_stats` passes and the two builds hash the trees' shapes alike; `tools/stress.sh` ends
  with nothing died and one thing dropped, the view of 512 m, which `main` drops too
  (docs/production/Stress_test.md); the debug build's game ran nine hundred frames of a storm at dusk
  with mist and sixty-four lights, and a year of weather with the band, with no exception.
- Versions: **none moved.** `Generator_Version` 13, save format 6, colony blob 17. Nothing here changes
  a block, a save or a step of the colony: the reference band's state after a year is `main`'s to the
  bit, in release and in debug.

## John's words (2026-11-11)
"Hello claude, for this session we are doing some final touch-ups and a stress test before we move to
stage 6, Volumetric clouds, no moon, black sun in winter when snowing, wet surfaces, deferred lighting
techniques if not already implemented or not effective, Mist/fog?"

While the stress test's windows were running on his desktop, two more:

"I think our deferred lighting and MSAA 4x is getting expensive", with a pasted note: "Single-sample
G-buffer. No MSAA anywhere in the deferred path. SMAA 1x on the lit image, with depth-based edge
detection. Depth is already in the G-buffer, so edges come from geometry only and the 5 cm texels stay
crisp. Use 1x only: SMAA's T2x and 4x modes are temporal. 1x should land well under a millisecond on a
current card, but measure it. A new fix for foliage. Alpha-to-coverage goes away with MSAA, and a plain
alpha test makes distant canopies thin out and sparkle. There are two non-temporal fixes: Draw distant
leaf blocks solid in their averaged colour once their texels drop below a pixel. Your shader already
computes that colour for its distance fade. Canopies read slightly denser, but they're stable. Use a
fixed screen-space dither on the faded alpha at mid distance. It keeps density, with a faint pattern
while the camera moves. Avoid hashed alpha: it's noisy by design and relies on temporal AA to clean it
up."

And then: "currently on the stress testing I am seeing drops into the 40s on fps, gpu ms is staying in
single digits, CPU is getting wild, but that could be a consequence of acceleration."

How those two were read: the first as a worry with a remedy attached, not an order to rebuild the
renderer; the second as the answer to the first, his own. Measured and written down, nothing of the note
built (his call 9).

How the first message was read:
- "black sun in winter when snowing": a report of something wrong. Found first, before anything was
  changed: in snow the sun was a dark grey disc on a pale sky.
- "no moon": read with it, as a report that there is none in the sky. So a moon was put there: a disc
  and its glow. Nothing else of the night was changed (his call 1).
- "Volumetric clouds", "wet surfaces": asked for; built.
- "deferred lighting techniques if not already implemented or not effective": conditional, so it is
  answered with what was found and a measurement, and with the one thing deferred lighting is for that
  the game was short of (his call 5).
- "Mist/fog?": a question. The answer given is yes, built, with a switch to take it out (`--nomist`).
- "a stress test": written and run on `main` first, then again on the finished branch
  (docs/production/Stress_test.md).

## What John sees on first launch
At the usual view in fair, dry weather, nothing: no sky is in the picture from the default tilt, and a
frame costs what it did. Tilt the camera low, or wait for weather:

1. **Clouds are bodies.** Heaps with flat floors and domed tops, lit on the side toward the sun and grey
   underneath, thinning into the horizon; an overcast is a low ceiling with lighter breaks. At sunset
   they are lit from below after the sun has gone. Their shadows on the ground lie under them, as before.
2. **The sun is never dark.** In snow or rain it is hidden by the cloud, a pale patch at most; among
   broken cloud it is a bright disc; setting, it is orange. It used to be a dark grey disc under any
   heavy cloud and at every sunset.
3. **There is a moon.** It comes up opposite the setting sun, warm at first, with its seas on it; clouds
   pass in front of it; a lake mirrors it. **It is only in the picture when it is low**, because the
   camera's lowest tilt shows the sky to about 20 degrees: through a midsummer night, but in winter for
   about an hour and a half after dusk (on winter's seventh day it clears the trees a little after
   five and is over the top of the picture by six) and the same before dawn. His report was made in
   winter.
4. **Rain wets things.** Earth, paths and bark go dark; rock shines; a meadow seen low toward the light
   glistens. Water stands in pools on the path and the camp's trodden floor, with the sky in them, and
   the rain rings them and the lakes. The ground is wet as soon as it rains and dries over half a day.
   What a tree or a roof shelters stays nearly dry.
5. **Some mornings there is mist.** It gathers in the night, lies thickest before dawn, pools in hollows
   and over water, and the sun burns it off: about one morning in three has some, one in four or five
   a fair one. From above it is a veil the camp can be seen through; from low down the trunks fade
   into it and the crowns stand out. The date line in the window's title says "mist".
6. **Nights are as dark as they were**, moon or no moon (his call 1). *Round two changes this: 7 to 9.*
7. **The moon has phases.** Ten days from one full moon to the next; full on the night the default
   start opens on (day 20), a half moon between two and three nights later, a thin crescent on the fourth, none on the fifth, and so round. Its
   disc is lit from the side the sun is on. A waxing moon is up in the afternoon, pale in the blue.
8. **A moonlit night.** Once the sun's light has gone the moon's falls on the land, cool, with shadows:
   bright on snow under a high winter moon, faint under a low summer one, nothing at the new moon. A
   night with no moon is the night there was; nothing is darker than it used to be.
9. **Stars**, when it is dark and clear: about 2,800 over the horizon, few bright and many faint,
   turning about the pole through the night, fewer by a bright moon.

## His calls (what I decided that he may want otherwise)
1. **The moon** (round one: only a disc, always full, no light on the land; he was asked, and answered
   "Moonlight on the land, phases, stars. Sounds great": round two). What I chose in building them:
   - **a month of ten days**, six moons to the year, the same every year, full on day 20.5 so that the
     default start's first night has one (`Castle.Climate.Moon_Days`, `Moon_Full_Day`);
   - **how bright**: the full moon high in a clear sky gives the land 0.30 where the sun gives 0.72; a
     quarter moon two fifths of that; overcast takes nine tenths (`Moonlight`). A summer full moon
     stands only 20 degrees up, so level ground takes a third of it: summer nights stay dim;
   - **the night's own light is left as it was under it**, so a moonless night is no darker than
     nights have been. If moonless nights should be darker now that there is a moon to make the
     difference, that is one number (`Sky_Amb`'s night value) and his to say;
   - **a moonlit night costs what a day does** (0.2 to 0.6 ms more than a moonless one), because the
     sun's shadow maps are drawn for the moon;
   - **the colony knows nothing of the moon or the dark** (a hunter sees as far at the new moon);
   - **stars are not mirrored in water**, and there is no Milky Way.
2. **Under snow cloud the sun does not show at all**, where he saw a black disc: the cloud is whole.
   With the flat layer (`--flatclouds`) it shows through at a twelfth, as a pale disc.
3. **One kind of cloud**, the heap, in one slab 650 to 1,250 m up; an overcast is the same clouds grown
   together. Their place is the map their shadows already went by, so nothing of where the weather is
   has changed.
4. **How often there is mist, and when** (`Castle.Climate.Mist`): seven named values and a chance that
   turns over every day and a half. It is only seen. **From above it is drawn half as thick as it is**
   so the colony stays readable. A forced sky (`--weather`, `--clouds`) has none unless `--mist` says.
5. **The renderer stays a forward one; the lights became a table.** A G-buffer would cost the
   multisampling and the cut-outs by coverage that the foliage, the grass and the smoke are drawn with,
   for nothing the game needs. What deferred lighting buys is many lights, and that is built another
   way: up to 64 in a view, each fragment summing only those that reach its 16 m of the world. Sixty-four
   fires cost 0.4 ms at night. **Only the nearest casts shadows; the rest shine through walls.** That is
   the thing to settle when a hovel has a hearth in it (rendering.md, "Lights", has the way I would go:
   a kept cube of the land round each light that does not move).
6. **Pools go by place, not by the ground's shape**: the same noise every rain, on level bare earth,
   clay, paths and rock under the open sky. They do not know a hollow from a hump, and they take the
   generator's slope, so a floor levelled on a hillside may have none.
7. **People, deer and props are not drawn wet.**
8. **`--no-needs`** is a new switch of the colony's scenario: nobody eats or sleeps. It is there for
   the stress test's band of forty-eight, which the land cannot feed, to be kept at work.
9. **Multisampling stays, and the note on dropping it is not built** (his answer: "MSAA keep it"). What he saw drop was the CPU: the
   colony's steps at 240 times speed, and for nine minutes the debug build (Stress_test.md). The GPU's
   frame is 2 to 3 ms. The renderer has no deferred lighting to make dear. 4x multisampling is half of
   that frame all the same, about a millisecond (rendering.md, "What multisampling costs", has it by
   view and by window): `--msaa 2` takes a quarter off today, `--msaa 0` shows the picture with none.
   The note's way would save about a millisecond at full screen less what its own pass costs; it would
   need the faces' normals as well as depth (depth alone misses every crease between a block's top and
   its side), and thin things would crawl as the camera moves where they hold now. If he wants it, it
   is a piece of work of its own.

## Built
- **The sky** (6204b13). The shared sky source put in one order: gradient (`sky_back`), the sun and the
  moon (`orbs`: discs that only add light), clouds over them. `Daylight` has the sun's disc colour, the
  moon and what lights the clouds (`Orb`: the sun to nine hundredths under the horizon, then the moon).
  The clouds walked through: `Cloud_Source` (`cloud_map`, `cloud_body`, `cloud_dens`, `clouds`), a pass
  of its own at half size into a 16-bit float picture (`Cloud_Program`, `Prepare_Clouds`), run only when
  sky above the horizon is in the view; a 64-cubed tiling noise of lumps made at start-up (`Puff_Tex`).
  The land, the figures and the water's mirror still take the flat map. `Castle.Render.Volumetric`,
  `--flatclouds`. The game's `Sky_T`: the drawn time, stepped in a recording.
- **Mist** (03dfccb). `air` in the shared sky source: the haze at the edge of the loaded world, the
  weather's murk and mist, once, for the land and the figures (each had a copy of the first two);
  `mist_through`, `mist_mean`, `sky_mist`. `Base_Tex`: the land's level over 80 m and how damp, 128 x
  128. `Castle.Climate.Mist`. `Look.Mist`, `Castle.Render.Mists`, `--mist`, `--nomist`.
  `climate_year` prints and tallies it.
- **Wet surfaces** (1448c49). In the land's fragment shader, between `#ifdef WET` and `#endif`: wetness
  by shelter, darkening by material (`u_soaks`), the sheen (`u_shines`), the pools (`u_pools`),
  `rain_rings` (on open water too). `World_Fragment (Wet)`, `World_Prog`, `Use_World`: the program built
  twice. `Look.Wet` is the climate's or 1.3 times the rain. `Castle.Render.Wetness`, `--wet`, `--nowet`.
- **Lights** (6c68c29). `Clear_Lights`, `Add_Light` (in place of `Set_Fire`), `Place_Lights`, the table
  (`Light_Buf`) and the grid (`Light_Tex`); `firelight` and `one_light` in the shared source.
  `--lights N`.
- **The moon, round two** (ccfa65e). `Castle.Climate.Moon_Phase` (the clock's; nothing saved);
  `Look.Moon`, `Look.Moon_Per_Day`. In the renderer the sun's two jobs are two names: `u_sun` (where it
  is) and `u_lamp`, `u_lamp_col` (what lights the land: `Lamp_At`, which the daylight and the shadows'
  held directions both go by; the sun until its light is gone, then the moon). `Moon_At`, `Moon_Lit`,
  `Moon_Share`; the disc shaded as a ball in `orbs`; `stars` in the sky's fragment source (a cube of
  squares turning about the pole). `Castle.Render.Stars`, `Moonlight`, `Star_*`, `Shadow_Least`.
  `--moon PHASE`, `--nostars`. The window's date line says "full moon" and "new moon".
- **The land drawn nearest first** (`Castle.Render.Near_First`, `--loadorder`): one counting pass over
  the stacks in view. 2 to 3 % of the frame; the picture is the same.
- **The stress test.** `tools/stress.sh`, `tools/look_cost.sh`; `--no-needs` (`Castle.Scenario`);
  `--hitch MS` (the game says where a long frame's time went); the renderer says once when the arena is
  full or the draws run out, and counts (`Stacks_Skipped`).

## Measured (seed 1, RX 6900 XT, 1280 x 720, GPU a frame; `tools/look_cost.sh`, the branch against `main` built beside it and run back to back)

| view | `main` | now | |
|---|---|---|---|
| open meadow | 1.75 ms | 1.71 | the four fixed views: no sky in them, dry |
| looking down on the forest | 0.48 | 0.48 | |
| the band at its camp by day | 1.96 | 1.94 | |
| the same at night, the fire casting | 1.45 | 1.46 | |
| the forest's edge from the lowest tilt, cloudy | 1.18 | 1.22 | the clouds' pass, less what drawing nearest first saves |
| the same at dusk | 0.93 | 0.93 | |
| the same at night | 0.95 | 0.97 | |
| a lake under a mountain | 0.77 | 0.83 | |
| the camp in rain | 1.98 | 2.35 | the wet look |
| the camp in rain from low down | 1.22 | 1.43 | |
| winter, snowing, low | 0.86 | 0.91 | |
| a storm from the lowest tilt | 1.18 | 1.38 | clouds and wet |

Each look by itself, measured as it was built (before the land was drawn nearest first):

- Round two: the stars 0.01 ms. Moonlight nothing by day or at the new moon; under a full moon the
  camp at night with its fire 1.46 ms to 2.05, the forest's edge at night 0.98 to 1.18, the meadow from
  the default tilt in winter 1.14 to 1.68 (by day it is 1.72). `tools/shadow_still.sh`: 0.00 % under a
  winter full moon at one game minute a second and at three, under a low summer moon, and through the
  dusk where the lamp changes from the sun to the moon. A starry sky is not still (the stars turn): one
  pixel in eight hundred steps by more than six levels at a game minute a second.
- Clouds: 0.05 to 0.08 ms where sky is in the view; 0.06 to 0.10 with the sky a third of the picture;
  0.2 at 2560 x 1440 with 8x MSAA. Nothing at the default tilt.
- Mist: not measurable (1.74 against 1.75 with the thickest mist at the default view).
- Wet: nothing while dry; 0.3 ms at the default view with everything wet, 0.36 in rain.
- Lights at night at the default view: none 1.18 ms, one 1.26, eight 1.35, thirty-two 1.46, sixty-four
  1.57.
- Drawing the land nearest first: 2 to 3 % off the frame at the default tilt, 15 % from the lowest tilt
  across the forest (2.33 ms to 1.98; in a storm 2.76 to 2.31).
- Multisampling (rendering.md, "What multisampling costs"): the open meadow 0.85 ms with none, 1.31 at
  2x, 1.71 at 4x, 2.10 at 8x; the camp by day at 2560 x 1440: 1.62, 2.41, 2.91.
- Quads resident and worker time per stack are as they were (nothing is meshed differently).
- The stress test: docs/production/Stress_test.md.

## Saves
Nothing. No version moved; a save made on `main` loads on the branch and the other way.

## Options
In the game: `--flatclouds`, `--mist AMOUNT`, `--nomist`, `--wet AMOUNT`, `--nowet`, `--lights N`,
`--hitch MS`, `--loadorder`, `--moon PHASE`, `--nostars`. In the game and the runner (`Castle.Scenario`): `--no-needs`.

## Bugs found and fixed
Already in `main`:
- **The sun's disc dark under cloud** (his report). It was drawn at the colour of the sun's light on
  the land, which overcast cuts by nine tenths: 0.41 grey on a sky at 0.65.
- **The same disc dark at every sunset**: that light is also ramped to nothing as the sun reaches the
  horizon. Found on reading the cause of the first; he had not reported it.
- **A recording's clouds, ripples and rain went by the wall clock**, so they moved at the pace the
  machine wrote frames (every demo so far). Stepped a thirtieth of a second a frame now.
- **The renderer dropped work without saying how much**: a line for every stack the arena had no room
  for (3,176 lines at a view of 512 m), and no line at all when a frame ran out of draws.

Mine, in this work, in no build John has had:
- Far clouds added their light without taking the sky's behind them away: a white band along the horizon.
- The clouds' sides were pleated: a cloud's body is the weather's map stood on end, and every wrinkle of
  the map ran down its side. The body takes the map without its finest detail now.
- With strides of one length a cloud that stops the light within a stride was drawn in rings. The walk
  takes short steps in cloud and long strides through clear air.
- Wet leaves shone like frost (they were counted with rock and planks).
- **The wet look cost 0.1 ms in dry weather, never run**, while it was one shader behind a test. That is
  why the land's program is built twice. Anything else that is only sometimes there should go the same
  way (CLAUDE.md).
- The climate's own wetness outlasts the rain by hours, so the map that looks straight down (which says
  what is sheltered) had to be kept drawn while anything is wet, not only while something falls.
- Round two: **the afternoon moon was lilac.** Its face, warm near the horizon, was laid over the blue
  and the brighter of the two taken colour by colour: red from the moon, blue from the sky. Found on
  looking over the second demo's frames. By day the sky is now made whiter by how bright the face is.
- Round two: **the nights the stress test measured are moonlit now.** Its two night runs are on day 20,
  a full moon, so their GPU figures in Stress_test.md (64 lights 1.58 ms, forty-eight by night 1.12)
  are round one's; with the moon's shadows drawn they read 2.20 and 1.36. That is the cost of a
  moonlit night as "Measured" has it, met again, and no new cost.

## Known limits
- Seen in stills and recordings only, like every look before it: the clouds from a rise and from the
  forest's edge in fair weather, cloud, rain, snow, a storm, at dusk, at sunset, at night and with
  `--msaa 0`; the moon rising and at midnight in midsummer, behind cloud, and over a lake; mist from the
  default view over the camp, from low down, from the rise, over a lake, at night by the fire and on
  snow; wet ground at the camp in rain and in sun after it, the path and the camp's floor close, wet
  rock; one fire, eight and sixty-four lights from above and low.
- **The sky is only ever seen low.** The camera's lowest tilt shows it up to about 20 degrees. So the
  clouds seen are those two to fifteen kilometres off, and the moon is out of the picture most of the
  night. The on-foot view of stage 7 will show the rest: the clouds have not been looked at from
  underneath, and the walk's steps were chosen for the distance.
- A cloud's body is the map stood on end: it has no overhang, and a tall one is a tower.
- The clouds' picture is half size: a cloud's edge against the sky is two pixels soft. The water mirrors
  the flat layer, not the heaps.
- Pools: his call 6. Rain rings are not seen from the default view (they are a third of a metre).
- Mist is as even as the land is level: no drifting banks. The fire does not light it.
- The lights' grid is two-dimensional: a light reaches its cells at every height.
- `--weather` forces what is seen and not the climate, as before, so `--weather clear` on a day the
  climate has wet still shows wet ground (as it showed it darker before); `--wet 0` dries it.
- Nothing of the pointer's real-input path was touched.

## Not done
- Shadows from more than one light (his call 5).
- Darker moonless nights; the moon's light in mist; anything of the moon the colony knows.
- Light shafts through mist or trees (a march through the sun's maps for every pixel: not cheap).
- A high thin layer of cloud, a storm's anvil, lightning.
- Wet figures; mud; pools that mirror the land; drips under trees.
- A budget for the colony's steps in a frame: left out on his word ("Time budget we will leave out for
  now, so we don't interfere with production"). The pathing work took most of what he saw away by other
  means (Handoff_2026_11_11_pathing.md).
- The single-sample picture of his note: closed by him ("MSAA keep it, no need to save a milisecond, if
  it becomes an issue later we can deal with it then").
- The herds as they were are still in the code behind `--deer-scatter` (the handoff before this one).

## Next
- Accepted and merged (the top of this file). With the acceptance he asked for one change to the
  water's look, falls that arch and stand off the wall: the handoff after this one.
- **Then stage 6**, his to open in a new session, as the two handoffs before this one say. Two things
  from here bear on it: the first hearth in a hovel is one more `Castle.Fire.Show` and one more
  `Castle.Render.Add_Light`, and it will shine through the hovel's walls until lights other than the
  nearest cast (his call 5).
