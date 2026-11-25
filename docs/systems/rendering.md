# Rendering

- Packages: Castle.Streaming, Mesher, Textures, Render, Camera, Colors, Currents, Cutaway, Lod, Far (and, of
  the figures' layer, Castle.Fire, which is described here with the light it gives)
- Check: camera_check (needs a window); `tools/shadow_still.sh` measures whether the shadows hold still
- Saves: nothing saved but the camera
- Stage: phase A; the palette on 2026-11-08 (Handoff_2026_11_08_world_look.md); shadows and
  the fire on 2026-11-10 (Handoff_2026_11_10_shadows_and_fire.md); soft foliage, the fringe,
  rounded figures and grass on 2026-11-11 (Handoff_2026_11_11_models_pass.md)

How the view works: worker tasks generate each 8 x 8 m stack and greedy-mesh
it into packed 8-byte quads, nearest stacks first.  The main thread uploads
at most 48 meshes a frame into one 256 MB quad buffer and draws everything
with two multi-draw-indirect calls (solid, then water), pulling vertices
from the buffer in the shader.  The meshes of stacks that leave the view
radius are freed (two stacks of hysteresis; their blocks are held, since
2026-11-14: `world.md`, "The whole map held"), except the colony's ground,
whose meshes stay loaded and are simply not drawn past the view's edge.
Past that edge the land is drawn from tiles of coarser blocks, to the map's
edge ("The far view" below).
Textures are 5 x 5 texels per
face, four variants per material, generated at start-up.

What is kept by place for the stacks in view must allow for stacks kept
loaded outside it. The colony's ground is never unloaded, so anything
addressed by a stack's place modulo a size (the water's surface texture is:
`water.md`, "Drawing") can be shared by a kept stack and a far one: such a
thing has one owner at a time, the stack inside the window round the
camera, and is written again when the window comes back
(`Castle.Render.Set_Surface_Focus`). `--pan DX DY --pan-back` is the
scripted there-and-back that shows it.

Colours come from the designer's palette (`color_palette.txt` beside the
game folder), kept in `Castle.Colors` as named hex codes: `Ash_Stone`,
`Forest_Gold_Green`, `Heraldic_Crimson` and the rest. Muted environmental
colours are for the world, rich contrasting ones for what should stand
out. Each material's colour (`Castle.Blocks.Base_Hex`), the apples, berries
and grain ears painted into the textures, and the autumn colours in the
shader name a palette entry, so the look is retuned in one place. Three
colours have no entry and are derived by hand from named ones, with the
sum in a comment: `Sand_Tan`, `Salt_Pale` and `Grass_Seed`. Water is
`Storm_Blue`, not `River_Slate`: that read as a grey road from a distance.

Light and sky, kept cheap on purpose:

- The sun follows the time of day: up in the east at 6, 60 degrees in the
  south at noon, down at 18. Sunlight, the sky's colours and the light from
  the sky above and the ground below all follow it, warm at a low sun and a
  readable moonlit blue at night. `Castle.Render.Set_Look` (the `Day` and `Hour` of its record).
- The sky is drawn into whatever the world left empty: a gradient, the sun
  and the moon, and the clouds over them, drifting on the wind (see "The
  sky" below). Distant ground fades into the sky's own colour for that
  direction, so the edge of the loaded world meets the horizon instead of
  a wall of fog. (With `--far` it is 45 % haze there and all haze 1,100 m
  from the focus: "The far land" below, off unless asked for.)
- Shadows from the sun: see "Shadows" below. Grass casts none; a quarter
  of the leaf blocks let light through for dappled shade. The same clouds
  also cast drifting shadows on the ground.
- Water reflects the sky (clouds and sun glint included) more strongly the
  flatter it is seen, ripples with two drifting scales of noise, loses its
  glint in shade, and shows pale streaks where it falls.
- Water mirrors the world too (John, 2026-11-10: "surface reflections"):
  the land, the trees and the people in the picture. Just before the sky
  and the water are drawn, the picture so far is resolved out of the
  multisampled target into two textures, colour and depth. For each pixel
  of open water's top face the reflected ray is walked out from the
  surface in thirty growing strides (to about 450 m); where the picture's
  own depth is nearer than the ray's point, the ray has gone into
  something, the place is narrowed down by halving and its colour taken.
  A ray that meets nothing mirrors the sky as before. Rays that leave by
  the picture's sides carry on along its edge; toward its top the mirror
  fades into the sky's, since what stands above the picture is not known
  (a mountain taller than the view is cut off in the water). The ripples
  tilt the ray, so the mirror breaks up with them. How much shows is
  `Water_Mirror` (0.12 looking straight down) rising to all of it at a
  glancing view by the power `Water_Glance` (2.5): more than glass would
  (0.04 and 5), so that it shows from the usual view above. The sky's
  reflection goes by the same two, so with `--noreflect` the water still
  has more sheen than it had before. First values,
  at the top of `castle-render.ads`. `--noreflect` switches it off
  (`Castle.Render.Reflections`), and so does `--msaa 0`, where there is no
  target to read back: the water then mirrors the sky alone. It costs
  about 0.3 ms of GPU a frame with a lake filling two thirds of a 1280 x
  720 view (0.65 to 0.92 ms, RX 6900 XT). Not mirrored: other water (the
  copy is taken before any is drawn), the developer's marks, falling rain.
- Falls (John, 2026-11-11; what is thrown and how far is `Castle.Falls`,
  in `docs/systems/water.md`). The surface texture's fourth value, `Air`,
  is the sheet of a fall passing over a column: its top in sixteenths of
  a block, times 1024, plus its thickness in sixteenths (0: none). A
  stack that a sheet stands over is meshed with a second cell to each
  column (a quad with z = 1 beside the surface cell's: six faces, the
  underside too, since the water pass culls back faces and a fall is
  looked up at from its pool), and the vertex shader makes it that slab,
  its top and underside taken to the step as the water's levels are. A
  side toward a column with no sheet is the slab's own edge; toward one
  whose sheet is lower or higher it runs from the one top to the other,
  drawn by both, so the slabs of an arch are one curtain from the front
  and from behind. Under a sheet that falls free a column's own water is
  not drawn if it is thinner than a block, and no column draws a riser
  down a side by which a sheet leaves. A sheet is lit alike on every face
  (its slabs are one body, not boxes), takes the hue of a metre of water,
  mirrors nothing, and is whitened by `Fall_White` (0.16) and by streaks
  that run down and over it (`Fall_Streak`, 0.46), at `Fall_Alpha` (0.80);
  in frost it freezes with the water round it. First values, at the top
  of `castle-render.ads`. Only stacks under a sheet carry the second
  cells (a stack is meshed again when a sheet first comes over it, once,
  and keeps them until it is unloaded: a
  band's ground is simulated wherever it has dug, with no water near, and
  6,144 collapsed quads a stack there cost 0.06 ms in the rain view). The
  fixed views read what `main` read, back to back (lake 0.83 ms, meadow
  1.73, rain 2.31, horizon 1.24); a cut fall in the view is 0.03 to 0.06
  ms more than the curtain was. `Castle.Falls.Follow` takes 0.5 ms of a
  water tick with fifteen stacks awake, where the water's own step takes
  6. `--nofalls` draws falls as they were.
- Deeper water, deeper hue (John, 2026-11-10: "deeper hues for deeper
  depths"). Each column of open water takes its colour from its own depth:
  Storm Blue in the shallows, Royal Indigo by about 2 m (`Water_Hue_M`),
  Abyss Blue (Royal Indigo halved, a derived colour) by about 12 m
  (`Water_Abyss_M`), lit by the day like everything else. It hides its bed
  by how much water is looked through, the depth over the cosine of the
  view: no clearer than it ever was where it is thin (`Water_Thin_Alpha`,
  0.62: a film on a fall and the sheet out of a cut still read as water),
  all but opaque (`Water_Deep_Alpha`) once about 2.5 m lie in the way
  (`Water_Clear_M`). The constants are at the top of `castle-render.ads`.
  (A lake 39 m deep used to show its whole bed through 38 % clear water.)

## The sky

John, 2026-11-11: "Volumetric clouds, no moon, black sun in winter when
snowing". First values, at the top of `castle-render.ads`.

One order everywhere the sky is drawn or mirrored: the gradient from the
horizon's colour to the zenith's, then the sun and the moon, then the
clouds over both.

- **The sun's disc was dark under cloud** ("black sun in winter when
  snowing"). It was mixed into the sky at the colour of the sun's light on
  the land, and overcast takes nine tenths of that light: a disc at 0.41
  grey on a sky at 0.65. A low sun did the same at every sunset (its light
  is ramped down as it nears the horizon). He saw it in winter because the
  winter sun never climbs out of the view: from the lowest tilt the camera
  sees the sky up to about 20 degrees, and the winter noon sun stands at
  19.6. The disc now has a colour of its own (`Daylight.Sun_Disc`: white
  by day, orange low down), and a disc only ever adds light to what is
  behind it (`orbs` in the shared sky source).
- **The moon** (round two, the same day; John, on being asked: "Moonlight
  on the land, phases, stars. Sounds great"). It goes round from the sun
  by its phase (`Castle.Climate.Moon_Phase`, from the clock: ten days from
  one full moon to the next, `Moon_Days`, six moons to the year; full on
  day 20.5, so the default start's first night has one). New, it is with
  the sun and unseen; full, it stands where the sun is not, rising as the
  sun sets, 66 degrees up at a winter midnight and 20 at a summer one;
  between, it is up for part of the day and part of the night. Its disc is
  the sun's size, with its seas (from the noise), a ball lit from where
  the sun is, so a quarter moon is a half disc and its lit side faces the
  sun; warm as it comes up out of the haze; a pale thing in the blue by
  day (by night the face stands in the sky's place; by day the sky is
  made whiter by how bright the face is: the face's own colour laid over
  the blue came out lilac). Clouds pass in front of it and open water
  mirrors it.
- **Moonlight.** Once the sun's light has left the land (the sun 0.03
  under the horizon, by its sine) the moon's falls on it: cool, 0.30 at
  the full, high in a clear sky, where the sun's is 0.72 (`Moonlight`);
  by the lit share of its face to the power 1.3, so a quarter moon gives
  two fifths of that; nothing at the new moon or while it is down;
  overcast takes nine tenths, as of the sun's. The one light is nothing
  where the other takes over. The night's own light under it is as it
  was: a night with no moon is the night there was, and nothing is
  darker than it used to be.
- **The moon casts shadows** through the sun's own held maps: what lights
  the land is one direction and one colour (`u_lamp`, `u_lamp_col`;
  `Lamp_At` in `castle-render.adb`, which the daylight and the shadows'
  held directions both go by), the sun's or the moon's. `tools/shadow_still.sh`
  reads 0.00 % under a winter full moon at one game minute a second and
  at three, under a low summer one, and through the dusk where the lamp
  changes over. The maps are not drawn for a light fainter than
  `Shadow_Least` (a thin moon low down).
- **The sun's two jobs are two names now.** `u_sun` is where the sun is
  (its disc, its glow, the moon's lit side); `u_lamp` is what lights the
  land. One name for both is what drew the sun's disc dark.
- **Stars.** The sky is six faces of a cube that turns about the pole
  with the clock, once a day and once more in a year; each face is ruled
  into 56 x 56 squares and three squares in ten have a star, placed and
  made bright by a hash of the square (`Star_Cells`, `Star_Share`,
  `Star_Size`): about 2,800 over the horizon, few bright and many faint,
  a little warm or a little blue. They come out as the day goes, are
  fewer by a bright moon, fade toward the horizon, and clouds and mist
  hide them. Only the sky pass draws them (`stars`, in the sky's fragment
  source): water does not mirror them. They move as the sky turns, so a
  starry sky is not still: at a game minute a second one pixel in eight
  hundred steps by more than six levels between two frames, at three a
  second one in a hundred and thirty; the land under them reads 0.00 %.
  `--nostars` (`Castle.Render.Stars`) leaves them out; `--moon PHASE`
  holds the moon at a phase (0 new, 0.5 full).
- **The clouds are walked through** (`Cloud_Source`, `clouds`). They are a
  slab of air 650 to 1,250 m up (`Cloud_Lo_M`, `Cloud_Hi_M`). Where a
  cloud stands in it is the weather's own map, the one the clouds'
  shadows on the ground have always gone by, so a shadow lies under its
  cloud: flat underneath, domed, as tall as the place is deep into the
  map (`cloud_body`), its edges bitten into billows by a 64 x 64 x 64
  tiling noise of lumps (`Puff_Tex`, made at start-up). A pass of its own
  walks a ray of the sky for every pixel of a picture half the window's
  size each way (`Cloud_Program`, a 16-bit float target): in strides of up
  to 260 m through clear air, by how far the map says the nearest cloud
  is, and in steps of 14 to 70 m in cloud (0.8 % of the distance), at most
  128 to a ray; at each step in cloud it looks three times toward the sun
  (the moon by night) for how much cloud is in the light's way. The sky
  pass lays that picture over the gradient and the discs, each pixel the
  mean of the nine round it. Clouds fade into the horizon's colour with
  distance and are not walked past 15 km (`Cloud_Far_M`). A sun under the
  horizon still lights them from below.
- **Only that pass walks.** The land's and the figures' shaders (the
  clouds' shadows, the haze) and the water's mirror of the sky still take
  the flat map, a tap or two a fragment, as they did. `--flatclouds`
  (`Castle.Render.Volumetric`) draws the sky with the flat layer too, as
  it was.
- **A still view is still.** Each ray starts its walk a little further on
  by the pixel it is for, always the same for that pixel (a 4 x 4 ordered
  pattern), so nothing in the sky changes from frame to frame but the
  clouds' own drift: a cloudy sky recorded for two seconds has no pixel
  stepping by more than six levels between two frames
  (`tools/frame_change.py`), as with the flat layer.
- **The drawn time is stepped in a recording**: the clouds' drift, the
  water's ripples and the falling rain went by the wall clock, so a
  recording's clouds moved at whatever pace the machine wrote its frames.
  They go a thirtieth of a second a frame there now, as the fire's flames
  do (the game's `Sky_T`).

What it costs (RX 6900 XT, 1280 x 720, GPU a frame). The clouds: nothing
at the default tilt, where no sky above the horizon is in the view and
the pass is not run; 0.05 to 0.08 ms from the lowest tilt (the forest's
edge 1.18 to 1.25 ms, a lake under a mountain 0.76 to 0.84, the same
forest at night 0.95 to 1.00), 0.06 to 0.10 ms with the sky filling the
top third of the picture (2.24 to 2.32). The stars: 0.01 ms. Moonlight:
nothing by day or at the new moon; under a full moon a night costs what
a day does, because the sun's maps are drawn for it: the camp at night
with its fire 1.46 ms to 2.05, the forest's edge at night 0.98 to 1.18,
the meadow from the default tilt 1.14 to 1.68 (by day it is 1.72).

Not there: the moon's light on the mist round it; an eclipse; the moon
anywhere but where its phase puts it (it has no orbit of its own); a
Milky Way, planets, shooting stars; cloud kinds other than the heaps (a
high thin layer, a storm's anvil); clouds the eye can fly through (the
eye is always under them); light shafts.

## The far view (2026-11-15; accepted and on `main`; a second round on his answer, 2026-11-16)

John, having tried the far land and set it aside (whole in
`docs/handoffs/Handoff_2026_11_15_far_view.md`): "the LOD levels pop, so we
have to fix that ... if we are going to rework rendering let's go all the
way, let's figure out how to get everything in view", with a list of
techniques from his research: "I don't know what combination of those works
or not, and what we can use for our project so consider them, and let's see
if we cannot crack this." The handoff answers his list item by item. What
is built is the part of it that fits this renderer best and that the counts
bore out: **the world itself at coarser blocks, in rings, cross-faded.**
First values of mine throughout. He tried it and accepted it the same day
("ok looking good, great performance, we are headed in the right direction
... Merge it, and on by default"), and with the acceptance asked for more
by name: the white dots at the rings, the sun's shadows and the water's
mirror past the view's edge, a haze on the ground and at the map's rim, the
old far land out. Those are the bullets below that quote him
(`docs/handoffs/Handoff_2026_11_16_far_view_haze_and_shadows.md` has his
message whole, and the three things he left to me, none of them built, with
what was measured of each).

**Measured first** (`./bin/lod_stats`, kept): a tile of the world at cells
of 0.5, 1, 2 and 4 m comes to about 2,100 quads at the first three levels
and 1,400 at the fourth (a stack at full detail is 3,800, and a tile of
level 1 covers four), and a worker makes one in 4, 14, 56 and 223 ms. The
whole world in rings about the reference stake: 6.1 million quads beside
the view's own 4.7 million.

- **`Castle.Lod`** makes a tile: at level L a cell is 2^L blocks a side and
  a tile 32 x 32 cells (16, 32, 64, 128 m). Its stacks are generated as the
  game generates them, the edits laid on, and reduced by halves, eight
  cells to one: water on top stays water; half full is something, named by
  what is on top; two of a thing thin by nature (a trunk, a wall, a roof)
  keep it, so a tree keeps its trunk and a hovel its walls; grass, grain
  and wild vegetables are nothing. Then meshed, greedy, into the mesher's
  own 8-byte quads with its corner occlusion. A tile does not know its
  neighbours: past its edge the ground stands as the generator has it, and
  the top three cells of every edge column show their outward face (a
  skirt, for where two levels meet). **So the far view is the world: its
  own trees, and whatever has been dug or built.**
- **The renderer draws a tile with the land's own shader**: the per-draw
  origin's fourth number is the level and the vertex is placed at 2^level
  times the size; nothing else of the vertex pulling changed. Tiles are in
  no water's surface texture (and were in no light's depth map until the
  far shadows, below).
- **Rings about the focus**: the stacks' own meshes to the fog distance
  (the view radius), level 1 to twice that, each level after to twice as
  far again, level 4 to the map's edge. A cell so keeps about the size on
  the screen that a block has at the view's edge (2.3 pixels down to 1.2
  across each ring at 720 lines, 3.5 to 1.8 at 1,080).
- **Which level a pixel shows is decided in the fragment shader** (the top
  of the land's `main`): the level whose ring the place is in, or, while
  that is not loaded there, the finest coarser one that is, so nothing is a
  hole while tiles come in. What is loaded where is a texture of 128 x 128
  texels (one for every 16 m, a byte a level) and the stacks' own flags.
- **No line where the detail steps**: over the last `Far_Fade` of a ring
  (0.15 of a doubling: 144 to 160 m, 288 to 320 ...) both levels are drawn
  and each pixel takes one or the other by a fixed 4 x 4 pattern, the share
  going over; and a tile that has just come in takes its pixels over
  `Far_Arrive_Frames` (20) by the same pattern. The pattern is by the pixel
  and never by the frame: a still view is still (measured: once the far
  view is whole, 0.01 % of pixels step by more than 6 levels from frame to
  frame, as on `main`; from the very first frame, never more than 0.23 %
  after the thirteenth).
- **No pixel given up by both levels** (John, 2026-11-15, having tried it:
  "the white dot dithering for the LOD rings, if we can do something about
  the white dot dithering, even just making them dark grey would be cool
  too"). The dots were holes: 108 pixels of the sky's own colour along the
  first ring in one forest view. The two levels' surfaces do not lie in one
  place (a cell is as high as its upper half is full), so the two fragments
  of one pixel stand a little apart on the ground and read the cross-fade a
  little apart, and here and there both gave the pixel up. Now the coarser
  level has all its pixels `Far_Lap` (0.075 of a doubling) before the finer
  has given up its last, and where both keep one the nearer is seen: 108
  became 3, and those 3 are not the far view's (cracks a pixel wide between
  two quads of one mesh, which `main` has too and the old haze hid by being
  the sky's colour).
- **A floor under the land** (`Ground_Floor`; `--no-floor`): where the land
  leaves a pixel open below the horizon, over the map, the sky's pass draws
  dark ground (Charcoal, lit by the day) with the air between, not the sky:
  the line of sight is walked across the map in 24 even strides until it is
  3 m under the land's level thereabouts (the mean over 80 m that the mist
  lies on), so a line that leaves the map over the land is still the sky's. It is what shows through those cracks,
  and through the gaps beside a coarse tile standing in for ground that has
  not come in (on a slope, in a fast pan, up to 1 % of the picture for half
  a second: counted with the floor off, 9,338 pixels at worst in a pan of
  360 m; none of the sky's colour once everything is in, still or moving).
- **The sun's shadows past the view's edge** (`Far_Shadows`;
  `--no-far-shadows`; John, 2026-11-15: "Keep the shadows pst the view's
  edge it doesn't seem too expensive and it keeps other issues from arising
  with visuals, sometimes you can see shadows when you can't see what is
  making them and then shaddows start popping"). Two things:
  - *Two more depth maps*, one for each held direction of the sun, over the
    whole map (4,096 texels a side, 0.72 m each, 16 bits: 64 MB of the
    card's memory, made when first wanted). Into them go the stacks' own
    meshes and every tile of the far view that lies in its own ring (the
    ring's rule with no cross-fade, `Cast_Tiles` in `Draw`: one place for
    it). A map is drawn again when its direction moves (as the near maps
    are: every two seconds or so at the game's pace), and otherwise not more
    often than every 20 frames while tiles come and go (a third of a second
    at sixty a second: as long as a tile takes to come in), 300 for a change to
    the stacks alone; one far map in a frame at most. Ground past the fog
    distance reads them alone, four filtered taps each, an edge 2 m wide (with
    one tap the edge crept as the sun went from one held direction to the
    next, the two maps' texels not lying alike on the ground:
    `tools/shadow_still.sh` at twenty times the clock read 0.94 % and 1.11 %,
    and 0.00 % three times running with four; it no longer asks the
    near maps anything, which it used to do only to be told it was outside
    them); ground inside 0.85 of it the near maps, as ever; between, the one
    goes over to the other, by the place and never by the level, so the
    rings' cross-fade does not speckle it.
  - *The near maps hold more*: they reach as far up the light as the map
    goes (1,470 m each way; it was 500) and the tiles that stand in the
    light's way are drawn into them with the stacks. So a mountain past the
    view's edge shades the meadow in the view, and a shadow no longer comes
    into being as what casts it comes into the view. (They are drawn again
    for that when tiles have come or gone, not more often than every 20
    frames; and a tile is left out of them whose top is too low to shade
    the view from where it stands, by the light's slope: at noon next to
    none past the view's edge is drawn into them.)
  - Measured: little a frame in dry weather (meadow 2.10 ms for 2.07
    without, the lake 2.03 for 2.02, the forest from 140 m back 5.66 for
    5.54: what far ground pays for its taps it mostly saves on the near
    maps'), **0.18 ms in rain and storm** (meadow 2.55 for 2.37; the wet
    weather's program pays more for the far taps than the dry one does: why
    was not found, and asking them of every pixel with no branch was dearer
    in both); a frame that draws a far map is 2 to 2.5 ms
    longer (8.7 ms for 6.8 at the heaviest view tried). `tools/shadow_still.sh`
    reads 0.00 % at its three settings, and pulled back to 200 m what steps
    (0.18 %: the river's ripples) is the same with the far shadows and
    without. The first version read the far maps on every pixel of the view
    as well, to find what casts from beyond the near maps: 0.4 to 0.9 ms a
    frame; drawing those casters into the near maps does it for nothing.
- **Far water mirrors the world** (`Far_Reflections`; `--no-far-mirror`;
  John, of the shadows: "If we can do the same with the water mirror that
  would be nice"): the walk through the picture that water in the view
  makes, in strides as many times longer as the tile's cells are larger
  than a block (so it reaches as many cells as it does blocks close by: 900
  m at level 1). Looking across a mountain lake that lies part in the view
  and part past it, the far part was a pale band of sky and is now the
  mountain, as the near part is. Cost at that view: none measured (4.72 ms
  for 4.76 without).
- **A tile's faces that look away from the eye are not sent** (its quads
  come face by face; of his list, back-face chunk culling): about half the
  quads. It saves 0.00 to 0.06 ms: the cost is not in the vertices
  (`--no-far-cull` sends all).
- **The game streams the tiles** (`Far_Stream` in `game/castle_game.adb`):
  the last level over the whole map, always, so that something is under
  everything from the first seconds; the others by their rings, asked for a
  little before they show (1.1 and 0.9 of the ring) and kept a little after
  (1.3 and 0.75), the nearest first. The workers make them after all the
  view asks and before what is only held (`Castle.Streaming.Request_Far`).
  A tile whose stacks are edited is made again once it shows, not more
  often than every 2, 4, 8 and 16 s by its level.
- **The haze**: with the far view the land has no haze within the view and
  is all haze 3,600 m from the focus (`Far_Haze_M`); it was all haze at the
  view's edge. The camera's far plane is 4,800 m (it was 1,600; a variable
  now, `Castle.Render.Far_Plane`, handed to `Castle.Camera.View_Proj` and
  to the water's mirror as a uniform).
- **The ground haze** (`Ground_Haze`; `--no-ground-haze`, `--haze X`,
  `--rim M`; John, 2026-11-15: "Haze, let's cover the ground around the
  camera in a haze 1m or so the trees poke above, transparent but enough to
  cover loading at a distance and the white dot dithering for the LOD rings
  ... Let's do an opaque boundary haze so the edges of the map, ramping
  from the transparent to the opaque in a 12m ring around the map, can we
  have the haze follow the terrain of the mountains so the tops are still
  visible but look natural, like the mist is climbing the mountains with
  fingers between the saddles and ridges?"). First values but for his two
  figures (1 m, 12 m). In `air`, the one routine for what lies between the
  eye and a thing, so the land, the people, the water and the floor all
  take it:
  - *How deep it lies* is worked out once, from the generator's map, a
    number for every 2 m (a texture of 1,024 x 1,024, 2 MB): 1 m on level
    ground and on open water; less the steeper the land thereabouts is (its
    mean over 65 m: all of it up to a rise of 0.20 in one, none from 0.55);
    and **none in the mountains** (the generator's mountain mask: all of it
    under 0.1, none from 0.2, the foot of the mountains as the boulders
    have it), open water excepted. (The third round, John, 2026-11-16, his
    words whole in the handoff: "let's remove the fingers and haze off the
    mountains". The first build filled every gully to the land's mean round
    it, 8 m deep at most, so it ran up the mountains in white fingers; that
    filling is gone, and the mountains are clear.)
  - *A thing is in it* by how far it stands over the land as it was made
    (the height texture the land's shader already had): a trunk's foot is,
    its crown is not; a house stands in it as a tree does; a pit is no
    deeper in it than its rim. A tile of the far view is forgiven half its
    cell (its tops stand up to that much over the ground they stand for:
    without it far land was striped, a band to every cell of height, and
    the rings' cross-fade speckled).
  - *How thick it is* goes by the ground distance from the focus, or from
    under the eye if that is nearer: a metre of it is 2.9 % haze at the
    focus, 21.5 % at 0.85 of the fog distance (before the grass ends and
    the first ring's cross-fade begins) and 38.4 % from three fog distances
    on (`--haze X` scales all three); deeper haze hides more by the same
    rule. Those are what the water's was in the second round (a third of a
    metre deep at 8 %, 50 % and 75 % a metre: John, 2026-11-16, "the 85% as
    as snow, the subtle mist above the far water was better"): far land now
    lies under the mist far water had, and the water is as it was (the
    lake, pixel for pixel against the second round: unchanged but at the
    shore, where the texture of 2 m mixes the two). It is not thicker for being looked
    along, so a low camera still sees the ground at its feet.
  - *The map's rim*: over the last 12 m (his figure; `--rim M`) everything
    goes into the haze, the ground and what stands on it, and past the edge
    the sky's pass has the same colour.
  - It takes the sky's colour at the horizon, as the old haze did. The
    haze by distance (none in the view, all at 3,600 m) is as it was, over
    it.
  - Cost: +0.03 to +0.08 ms at the usual views, +0.20 at the heaviest tried
    (the forest from 140 m back, 5.5 ms): two taps and an exponential on
    every pixel. Off, nothing measured.
- **The sun and the moon go down behind the map's edge** (`Low_Horizon`;
  `--no-low-horizon`; the third round, John, 2026-11-16: "let's lower the
  line of the horizon below the edge of the map, so it it's harsh edge with
  the sun and moon can't be seen as easily from a high view angle or
  vantage point"). From high up the map's edge lies under eye level (from
  440 m back over the middle of the map, about 4 degrees under it); the
  sky's pass draws the haze between the two, and the sun and the moon were
  cut off on it by a straight line at eye level, well over the land. Under
  eye level the sky is still the haze (the land and its rim go into that
  colour, and it stays where it was), but the sun and the moon are drawn on
  it down to where the map's edge is in that direction (the land's height
  where the line of sight leaves the map, less 10 m, `Horizon_Under_M`, so
  the land's own edge stands over it), fading out over the last 0.03 under
  eye level (`Sun_Gone`, the 1.7 degrees under the horizon over which the
  sun's light on the land goes and the moon's takes over). **So from low
  down the land cuts the sun off** (200 m back at the lowest tilt, the eye
  some 25 m up: the sun goes down behind the trees at the map's edge, where
  it was sliced off in mid-air over them); **from high up it fades out in
  the haze above the land** (440 m back the edge is 4 degrees down and the
  fade is done by 1.7), with no line, and the last of it is seen for its
  own breadth after its light has left the land (a sun low over land in
  dusk, as from a mountain). Over eye level nothing is changed: a view with neither in it is the same to the
  pixel with it on and off (0 of 518,400 pixels; looking into the sunset,
  261 under the sun). Only the pixels within 0.03 under eye level look up
  the map's edge, one tap each.
- `--no-lod` (`Castle.Render.Far_View` off): none of it; **the picture is
  `main`'s to the pixel** (two still views with `--no-whole-map`, 0 of
  518,400 pixels differ) and costs what `main`'s does.

**What it costs** (`tools/look_cost.sh --hold-wait --far-wait --settle
2500`: the twelve views, averaged over 2,500 frames after everything is
in; 1,280 x 720, multisampled):

| view | `--no-lod` | far view | |
|---|---|---|---|
| meadow, camp, rain (looking down) | 1.82, 2.04, 2.34 ms | 1.97, 2.17, 2.50 | +0.13 to +0.16 |
| forest (close, steep) | 0.51 | 0.51 | +0.00 |
| horizon (day, dusk, night), overcast, rain low | 1.00 to 1.47 | 1.50 to 1.97 | +0.47 to +0.50 |
| snow low | 0.96 | 1.35 | +0.39 |
| the lake, looking across to the mountains | 0.86 | 1.92 | +1.06 |

The cost is in the fragments, not the vertices: at the lake 916 tiles are
drawn and 1.1 million quads sent, and without multisampling the far view's
+1.06 ms is +0.52. Memory: 8.1 million quads, 62 MB of the 256 MB quad
buffer; the process holds 22 MB more (1,510 MB for 1,488). The main thread:
0.34 ms a frame for 0.19 once settled.

**With the second round** (the far shadows, the far mirror, the ground
haze, the floor; the build before it and after, back to back, 2026-11-16):

| view | no far view | far view before the round | now |
|---|---|---|---|
| meadow | 1.82 ms | 1.96 | 2.11 |
| forest (close, steep) | 0.52 | 0.51 | 0.55 |
| camp by day, by night | 2.05, 2.17 | 2.18, 2.28 | 2.32, 2.42 |
| horizon by day, at dusk, by night | 1.31, 0.99, 1.25 | 1.80, 1.50, 1.74 | 1.86, 1.53, 1.79 |
| the lake, looking across | 0.86 | 1.93 | 2.01 |
| rain, rain from low | 2.31, 1.45 | 2.53, 1.97 | 2.78, 2.17 |
| snow from low | 0.96 | 1.35 | 1.39 |
| overcast (storm) | 1.40 | 1.92 | 2.08 |

The round is +0.03 to +0.25 ms (the most in wet weather, where the far
shadows cost 0.18 of it), and the far view with all of it +0.03 to +1.15
over no far view. **A cheaper shader for the far levels would not buy
much**: with every far fragment drawn one flat colour the lake's frame is
1.70 ms for 1.99 (of the far view's 1.13 there, 0.83 is not shading), the
horizon's 1.76 for 1.84. Drawing the far tiles nearest first: nothing.

**How long it takes to come in** (the default view, from the first frame):
on this machine's 31 workers the far view is whole in 6.6 s, coarsest
first, and the whole map is held in 18.3 s (12.0 without the far view: it
comes after). On three workers (a machine of four cores, emulated with
`--workers 3`): 46.6 s and 67.6 s (23.8 without). The tiles cost 193 s of
worker time in all, nearly all of it generating stacks a second time
(0.75 ms each): making them from the same pass that holds the map would
halve the whole.

**Limits, and his to say** (the handoff has them as his calls):

- The rings go by the focus, not by the eye: with the camera pulled far
  back and low, the ground by the eye is cells of 1 or 2 m seen from 100 m.
- Grass, grain and wild vegetables are not in the far view: a meadow's
  yellow patches end at the view's edge, under half haze in the second
  round (John: "The vegetation is solved by the haze") and a fifth since
  the third. Thin things are kept fat:
  a bare winter forest far off is trunks as thick as its cells.
- The ground haze goes by the land as it was made: what is dug or levelled
  does not move it (a pit is no deeper in it than its rim; a floor raised a
  metre stands out of it). There is none of it, and no far shadow, without
  the far view.
- A far shadow is soft (an edge 2 m wide), and the shadow of a tile that
  has just come in comes up to a third of a second after it at sixty frames
  a second. In rain and storm the far shadows cost 0.18 ms where in dry
  weather they cost 0.01 to 0.03: cause not found.
- While a fast pan comes in, the floor shows as dark wedges beside coarse
  tiles standing in on slopes.
- A stack's own mesh that comes late does not fade in as a tile does (the
  tile standing in for it gives way at once).
- An edit shows far off 2 to 16 s after it is made; live water (a lake let
  out) not at all: a tile has the water the world was made with.
- Depth: the far plane is three times further with the same 24-bit buffer.
  Nothing was seen to flicker in the stills; reversed depth is the mend if
  it shows.

## The far land (2026-11-14; out of the game since 2026-11-15)

**Out of the game.** John, with the far view accepted (2026-11-15): "remove
the old far land, but keep the functionality just comment it out or
something, just in case". So: the game's `--far` is commented out (two
lines in `game/castle_game.adb`, marked, which bring it back), and nothing
of the far land is made at the start unless `Castle.Render.Far_Land` is set
before `Init` (its program, its two textures, a fifth of a second). All of
its code is still there and still compiled, and `edit_check` still proves
`Castle.Far`, which is what keeps it from going stale as text commented out
would. Brought back in a scratch copy on the day it was taken out, with
`--no-lod`: it draws as it did. It was never tried together with the far
view. Everything below is as it was written while `--far` worked.

**John tried it and set it aside** (2026-11-15, his words whole in
`docs/handoffs/Handoff_2026_11_15_whole_map.md`): "we got what we came for,
the whole map is loaded, let's bring back the haze, --no-far the default",
and: "far is ugly with the flat terrain and popping assets, the fog works
better in that state." So `Castle.Render.Far_Land` is off, the picture and
the haze are what they were, and `--far` draws what is described below. It
is kept as the first try at a far view and as a place to measure from; what
is to replace it is his sidetrack of the same day ("let's figure out how to
get everything in view": the far-view work, on a branch of its own). What
he named: the terrain is flat (a forest is coloured cells), and things pop
where a stack's mesh takes over from the sheet. Below, "is drawn" means
with `--far`.

John, with the whole map held: "what would it cost to cover the entire
world with one mesh and draw locally over it, like a dark grey, if we load
the whole map, then far mountains need a texture, they don't need detail,
but something has to be there?", and then: "ok build it".

**The whole world is drawn as one coarse sheet, seen wherever no stack's
own mesh is drawn**: past the edge of what is streamed in, and under a
view that is still coming in. Built from his message with first values of
mine.

- **`Castle.Far`** (pure, no window) works it out once from the
  generator's map, no stack made: a height for every corner of a grid of 4
  m cells, and for every cell what is seen on it: the average colour of the
  ground block at its middle (the block textures' own third level), and
  whether it is bare, turf, a broadleaf's crown, an aspen's, a conifer's,
  or open water. A cell is one of the generator's tree cells, so a cell
  with a tree in it is that tree's crown: 99,220 of the 262,144 cells on
  seed 1, and a forest comes out as its own trees. 0.23 s on one thread at
  start-up (1.2 s on the debug build).
- **The sheet lies under the land as it was made, everywhere on dry
  ground.** A corner stands half a metre under the lowest of the map's
  heights (or open water's levels) that any block column of the four cells
  meeting at it is made from, so the flat triangles between corners are
  under every block column they span: by 0.31 m at the least over 957,440
  block columns of 3,740 dry cells (`edit_check`, 36 checks now: the
  corners, the columns between them, the cells by what is on them, the
  time; with a corner looking only at the two metres round it, as the
  first build had it, the sheet stands 0.75 m over the land between
  corners and the check fails).
- **So a stack's own mesh hides it, and no hole is cut in it for one.**
  The renderer (`castle-render.adb`, `Far_Program`) draws the grid with no
  buffer: six vertices a cell, the corner's height from a texture (513 x
  513), the cell from another (512 x 512); a third (256 x 256) says of each
  stack whether a mesh of its own is loaded and whether the stack has been
  edited (`Upload (..., Edited)`: the game says, from the edits'
  generation), kept by `Upload` and `Unload`. A fragment is dropped only
  under a mesh that is drawn (the test `Draw` makes of each stack) **and**
  where the land is no longer as it was made (an edited stack: a pit would
  show the sheet) or the cell stands at open water's level (a cell that is
  wet: the water's own surface is drawn over its bed, and the sheet would
  lie between). **The first build cut the sheet out wherever a mesh was
  drawn**, and from outside the view, looking in over steep ground, the sky
  showed under the mesh's edge (a mesh has no side where its stack ends):
  white patches on a mountainside, seen in the frames of a pan.
- Toward the map's edge the sheet goes into the haze over its last 200 m
  (`Far_Rim_M`), so that the world's end is not a straight line against
  the sky.
- **It takes the day as the land does, at a tap or two**: the lamp's light
  and the sky's by the lie of the land (the map's height field, as the
  land's own far lighting), the clouds' shadows, snow by height on what
  looks up, the autumn (a broadleaf's crown turns and is gone tree by tree,
  and the ground shows under its boughs), a meadow's drifts and its drying,
  the wet, ice on water, and the air (haze, murk, mist). Water is its hue
  and the sky in it. **It casts no shadow and takes none, has no place in
  the sun's maps (`Draw_Casters`), and is drawn after the land and the
  people and before the picture the water mirrors**, so far hills stand in
  a lake.
- **The haze has two legs** (`air` in the shared sky source, `u_far`): the
  land is `Far_Haze` (0.45) haze at the edge of what is streamed in, where
  it was all haze, and all haze `Far_Whole_M` (1,100 m) from the focus.
  That is the one change to a picture he had accepted: the last trees of
  the view no longer dissolve whole. **1,100 m is inside the camera's far
  plane (`Castle.Math.Far_M`, 1,600 m) from as far out as the camera zooms
  (450 m): change the one with the other.** The stacks past the fog
  distance are still not drawn, the sun's maps and the lights are still
  sized by it: `Fog_Distance` itself is untouched.
- Without `--far` (`Castle.Render.Far_Land` off, the default): nothing
  drawn past the loaded land and the haze whole at its edge. (`--no-far`
  is still taken.)

**What it costs** (`tools/look_cost.sh`, the twelve views, main built
beside it and run back to back, the whole map's coming-in out of the way):
0.00 to 0.07 ms of GPU a frame (the lake most; forest and horizon 0.03);
1.57 million vertices a frame, drawn whatever the view (not culled to the
view: not needed at this cost). Memory: 3 MB of textures. Once the whole
map is held a frame costs what `main`'s does to a hundredth (0.50 for
0.50, 0.84 for 0.85, 1.28 for 1.29 ms without the far land); while it is
coming in, the first twelve seconds, the GPU's time reads 0.03 to 0.35 ms
more (the workers have the processors).

**Without it, and with `--no-whole-map`, the picture is `main`'s to the
pixel** (a still view recorded with the clock stopped and no shadows: 0 of
518,400 pixels differ), and the haze's new sum with nothing far is the old
line to the pixel too (built both ways: 0 differ). With the whole map held the
picture differs from `main`'s in some 870 scattered pixels, most by under
5 levels; **`main` differs from itself by the same pixels when the
processors are busy in its first seconds** (run beside 28 busy processes:
870 differ from `main` on a quiet machine, 2 from this build): the game's
own dependence on how long its first frames take, older than this and not
looked into. The shadows hold still as they did (`tools/shadow_still.sh`:
0.00 % with the clock running, fast, at dusk; nothing at all with it
stopped).

**Limits, his to say**: it shows the world as it was made, so nothing
dug, laid or built (a village seen from a kilometre off is its meadow; the
colony's own ground, loaded but past the view's edge, is drawn so too). It
is flat: a forest is coloured cells, not trees, and the hand-over at the
view's edge shows (detail to none, at 45 % haze). Seen close, in front of
a camera pulled far back, a cell is a 4 m square. An edited stack in view
has no sheet under it: at the view's edge, from outside, the sky can still
show under its mesh on steep ground (the colony's own ground is such
stacks). The far plane cuts the sheet 1,600 m from the eye, where it is
all haze or nearly. Nothing of it is streamed or refreshed. **Seen and not
mended**: in a fast pan a few white slivers show for a frame or two at
brooks, where stacks are still coming in (cause not found; without the far
land the same frames show whole white squares there, the sky through
ground not yet meshed).

## Mist

John, 2026-11-11: "Mist/fog?". Yes: first values, at the top of
`castle-render.ads` (how it is drawn) and of `castle-climate.ads` (when
there is any: `climate.md`, "Mist").

- A layer lying on the land. It is thickest at the land's own level
  thereabouts, which is the mean level over about 80 m, the water's where
  there is open water (a 128 x 128 map made at start-up, `Base_Tex`), and
  thins upward by e for every 5 m (`Mist_Height_M`). So it pools in
  hollows and over lakes, a rise stands out of it, and from a hilltop the
  forest's crowns stand out of a white floor. By open water it is half
  as thick again as far from any (the map's second channel, from the
  world's distance to water).
- At its thickest (`Look.Mist` 1) a metre of it at its floor stops 4.5 %
  of the light (`Mist_Thick`): from a man's height a tree 30 m off is half
  gone and one 80 m off is a shadow.
- **Looked down on steeply it is drawn thinner than it is**, by up to half
  (`Mist_From_Above`): from the usual tilt the thickest mist takes about a
  quarter of the ground's colour, and the band and its camp stay readable
  through it.
- Its colour is the sky's it lies under (the horizon's colour and the
  sky's light on the land): pale by day, warm at dawn, a faint blue at
  night, brighter toward the sun.
- No pass and no march: the layer's thickness is summed exactly along the
  line from the eye to each fragment (`mist_through`), in `air`, the one
  routine of the shared sky source that also hazes the edge of the loaded
  world and the weather's murk (the land's and the figures' shaders each
  had their own copy of those two). The sky's own pixels take it by the
  layer looked up through from the eye (`sky_mist`). With none about
  (`u_mist` 0) it costs nothing; with it, a tap and two exponentials a
  fragment, which the timer does not show (1.74 ms against 1.75 at the
  default view).
- `--mist AMOUNT` forces it (0 to 1); `--nomist` (`Castle.Render.Mists`)
  draws none; a forced sky (`--weather`, `--clouds`) has none unless
  `--mist` says so, so that a still is what it was asked for.

Not there: the fire's light in the mist round it; light shafts through
the trees (a march through the sun's maps: not cheap); mist that drifts
or thickens and thins in patches (it is as even as the land is level);
anything of it the colony knows (a hunter sees as far as ever).

## Wet surfaces

John, 2026-11-11: "wet surfaces". Wet ground was only 22 % darker, all
of it alike. First values, at the top of `castle-render.ads`.

- **How wet.** `Look.Wet`: the climate's own count of it (it fills over an
  hour or two of rain and dries with the sun over half a day), or 1.3
  times the rain falling now if that is more, so the ground is wet as
  soon as it rains. What a roof or a crown shelters is 35 % as wet
  (`Wet_Sheltered`; the map that looks straight down, which the snow goes
  by, is kept drawn while anything is wet). Snow covers it.
- **Darker and richer.** Earth, sand, gravel, clay, paths and bark soak
  it up and go 36 % darker (`Wet_Soak`); everything else 16 %
  (`Wet_Dark`); colours a fifth richer (`Wet_Rich`).
- **It shines.** A wet face mirrors the sky's tone, the more the flatter
  it is seen: rock and planks 85 % of what glass would
  (`Wet_Shine_Hard`), turf, leaves and earth 30 % (`Wet_Shine_Soft`).
  Rock and planks glint where the sun comes off them (`Wet_Glint`).
  Looked down on, a meadow shows almost none of it; from a low view
  toward the light it glistens.
- **Water stands in pools** on level bare earth, clay, paths and rock
  under the open sky: by place, on a noise, so the same pools form after
  every rain and a path has its own; hardly any until the ground is half
  wet, growing to about a third of level bare ground at its wettest
  (`Pool_None`, `Pool_Most`); none on ground that slopes
  more than one in five by the 1 m height field (`Pool_Slope`: the
  generator's ground, so a floor the band has levelled on a hillside
  still counts as the slope it was). A pool is the ground darker still
  with the sky in it as open water has it, clouds, sun and moon
  (`Water_Mirror`, `Water_Glance`), texel by texel close up and a share
  of the pixel far off. It does not mirror the land.
- **Rain rings** on pools and on open water while it rains: a drop to
  every third of a metre, each in its own time, and the ring that widens
  from it.
- All in the land's own shader, no pass and no texture. **The land's
  program is built twice**, without the wet look and with it
  (`World_Fragment`, `Use_World`: `#ifdef WET`), and the one with it is
  used only while something is wet: left in the one shader behind a test,
  the wet look cost 0.1 ms in dry weather too, never run. A second look
  that is only sometimes there can be built the same way.
- `--wet AMOUNT` forces how wet (0 to 1; `--weather clear --wet 1` is sun
  after rain); `--nowet` (`Castle.Render.Wetness`) draws nothing wet.

What it costs (RX 6900 XT, 1280 x 720, GPU a frame): nothing while it is
dry (the open meadow 1.75 ms against 1.74 on `main`); with everything
wet, 0.3 ms at the default view (2.04 against 1.75; in rain 2.35 against
1.98) and 0.25 from a low one. Taken apart at the default view: the
darkening 0.05 ms, the shelter lookup 0.07, and the block that holds the
sheen and the pools 0.2, of which the mirror itself is 0.05 and the
pools nothing. Why that block costs the rest was not found: passing it
over for the fragments that cannot show a sheen (most of what is looked
down on) saved nothing, and the same block cost 0.1 ms in dry weather,
never run, while it sat behind a test.

Not there: wet people, deer and props (the figures' shader has none of
it); pools that mirror the land (the picture is not there to read while
the land is being drawn); mud; pools that follow the ground the band has
dug or levelled (they go by the generator's slope); drips under trees;
the snow's melt wetting the ground.

## Shadows

What casts. Two things are drawn into a light's depth map, by one routine
(`Draw_Casters` in `castle-render.adb`): the land, which is every stack's
solid quads, and the figures, which is every box `Castle.Figures` was given
this frame (people, deer, props, whatever they carry). So a new block, a
new prop or a new animal casts a shadow from the sun, and from the fire,
with nothing more to do. Three things cast nothing, on purpose: grass,
grain and wild vegetables (a material in the `u_plants` set: it would only
speckle the meadows); a box that glows (`Castle.Bodies.Box.Glow`: a flame is
a light); a look made with `Castle.Figures.New_Look (..., Casts => False)`
(smoke). A new way of drawing solid things, one that goes through neither
the stacks nor `Castle.Figures`, gets its depth pass in `Draw_Casters`,
once, and then casts from every light.

The sun's maps. The land's is 4096 x 4096 over everything loaded (9 cm
texels at the default view of 160 m), the figures' a second map of the same
size round the focus, 24 m each way with the eye close in (1.2 cm texels:
an arm is 10 cm wide), doubled until it reaches three times as far as the
eye is from the focus (`Figure_Shadow_M`, `Figure_Shadow_By`: at a low tilt
the view reaches about that far), drawn every frame. A point is lit if both say so.
Each lookup is nine filtered taps a texel apart, a soft edge four texels
wide.

Why they don't flicker. They did (John, 2026-11-10: "they flicker"): the
sun moves every frame the clock runs, the map was drawn again for each new
direction, and its texel grid turned with the sun, so every shadow in the
view was sampled anew each frame. Measured on a still view of the meadow by
the reference stake (1190 1085), over sixty frames a thirtieth of a second
apart: one pixel in seventeen stepped by more than six levels of 255
between two frames running at least once in those two seconds; with the
clock stopped, none. So the maps are no longer drawn for
where the sun is. They are drawn for two held directions, one the sun has
passed and one it is coming to, and the shade is mixed from the two by how
far along the sun is. Between two steps nothing is drawn again and nothing
changes but the mix; at a step the direction passed is dropped, the one
reached becomes the one passed, and one map is drawn for the next. The
next direction is taken where shadows will have moved `Shadow_Hold` (1 cm
for each metre of what casts them: a 10 m tree's shadow, 10 cm), and never
nearer than the sun goes in `Shadow_Min_Frames` (12) frames, so a low sun
or a fast clock takes longer steps instead of more of them. A jump of the
clock, or the clock run back, starts again from where the sun is. The same
view after: no pixel does at a game minute a second, at three, or at
eighteen (`tools/shadow_still.sh` is the measurement).

The land's map follows the focus `Shadow_Snap` (64) texels at a time, so
panning draws it again only every 5 m or so, and always onto the same
texels. It is also drawn again when a mesh changes. What was 1.14 ms of GPU a
frame at the default view with the clock running (the whole land into the
map every frame; the timer used to start after it, and showed 0.25) is
0.3 ms.

At dusk and dawn. Shadows used to switch off with the sun still at over
half its strength. Now they are cast for as long as the sun gives light,
never from lower than 4 degrees (`Shadow_Low_Sun`), so they keep that
length and fade out with the light.

The disc under a figure (`Castle.Figures.Add_Shadow`) is drawn only where
no sun casts the figure's own shadow: at night and under heavy cloud
(`Contact_Shade`). With `--noshadows` it is as it always was.

The fire's shadows. Of the lights in the view (`Castle.Render.Add_Light`:
"Lights", below) the one nearest the focus casts
too: the land within its reach and every figure are drawn into the six
faces of a 512 x 512 cube of depth maps about the light, every frame, by
the same `Draw_Casters`. Nothing within `Fire_Near_M` (0.6 m) of the light
casts: the fire's own stones and bed, and the pot hung just over it, which
would darken everything above a man's waist. What is in a shadow or turned
from the fire keeps `Fire_Fill` (a quarter) of its light. One light
casts; the others shine through what stands in their way. `--noshadows` switches these off with the sun's. The sun's
shadows are held still on purpose; the fire's stir, because its light does
(below).

The constants are at the top of `castle-render.ads`, first values.

What it costs (RX 6900 XT, 1280 x 720, the default view of 160 m, the camp
in sight): 0.30 ms of GPU a frame at night with the fire casting, 0.36 ms
by day with the sun's maps and the fire's, 0.24 ms with `--noshadows`.
While the view streams in, both of the land's maps are drawn again on
every frame a mesh arrives: 0.83 ms a frame on average over a glide of
360 m at the screen's rate.

Not there: shadows from more than one fire; a figure's shadow further from the focus
than its map reaches (three times the eye's distance); softer shadows
further from what casts them.

## The fire

John, 2026-11-10: "The current fire animations, the turning bouncing red
blocks, is cute, but it feels unnatural". They were six tall glowing boxes
that turned, leaned and stretched where they stood.

`Castle.Fire` draws a fire now, through `Castle.Props` and
`Castle.Figures` like any prop: `Castle.Fire.Show (bed, heat, time, wind)`
for the flames, `Light_At` and `Light_Strength` for
`Castle.Render.Add_Light`. A second fire (a hearth, a torch) is one more
call of `Show` and one more of `Add_Light` ("Lights", below).

- Flames: up to 72 small glowing pieces (`Flames`), none of which turns or
  bobs in place. Each is born on the bed, rises, slowly at first and then
  faster, draws in toward the middle, shrinks, and cools from pale yellow
  through gold and orange to a dull red before it is gone (five looks,
  `Castle.Props.Flame_Bit`, from the palette's Flame Core, Aged Gold, Flame
  Edge and Ember Glow). The ones born in the middle are the largest and
  hottest and climb highest (`Flame_Tall`, 0.62 m at full heat), so the
  fire stands as a pointed body, pale at its heart and red at its tips and
  rim. The whole of it wanders a little and leans on the wind
  (`Wind_Lean`), more the higher up.
- Sparks (`Sparks`, ten at most): now and then one flies up to a metre and
  a half, slowing, and winks out.
- Smoke (`Smokes`, 24 puffs): pale, half seen through, rising 3.5 m off the
  flames' top, spreading, going with the wind (`Smoke_Drift`) and thinning
  away. It casts no shadow. (A look can be made thin,
  `Castle.Figures.New_Look (..., Thin => True)`: half the samples of each
  pixel under MSAA, every other pixel without it.)
- The bed: glowing coals while the fire burns, grey ash and charred sticks
  when it is out (`Castle.Props.Ashes`); it used to glow either way.
- Heat (`Castle.Colony.Camp_State.Heat`): the fire burns at its full
  through a log's eight hours but the last, when its flames sink to 45 %
  (`Fire_Sink_Hours`, `Ember_Heat`), and on down to nothing through the
  three hours it then dies down in (John, 2026-11-10: "fire life needs to
  be extended to about 8hours with a 3 hour diedown for restoking";
  `docs/systems/needs.md`, "The cook"). Dying down (`Show`'s `Dying`, 0 to
  1) there are fewer and lower flames, till a tenth of them a fifth as
  high are left over the coals, hardly a spark, less smoke (`Die_Flames`,
  `Die_Tall`, `Die_Smoke`); its light fades with its heat. The bed glows
  till it is out. With `Dying` 0 the fire is drawn exactly as it was.
- The light: from the flames' heart, about 0.4 m up (`Light_Up`; the lower
  it sits, the longer the shadow of every step in the ground), wandering a
  few centimetres (`Light_Roam`) and wavering in strength on smooth noise
  (it was two sine waves), so the shadows it casts stir. By day only `Fire_By_Day` (0.35) of
  it shows, in any weather (it goes by how high the sun is, not by how
  bright): the fire lights its own stones and little else at noon, and all
  of the camp at night.

Marks on the ground at night. A mark that is of the ground
(`Castle.Marks.Strip (..., Of_Ground => True)`: a zone filled in) is drawn
at `Marks_By_Night` (0.22) of its colour at night and comes up with the
day, so a zone does not glow in the dark; the developer's marks (routes,
the walking map), a lot being planned and the zone under the cursor keep
their colour.

Everything is a function of the fire's place, its heat and the drawn time
(the game's `Flame_T`, which a recording steps a thirtieth of a second a
frame): nothing is kept from frame to frame and nothing is saved. The
constants are at the top of `castle-fire.ads`, first values.

Not there: flames that take the shape of what burns (logs laid on the
fire are not drawn); smoke that a roof stops; a fire's light on its own
smoke beyond what every figure has; wind that changes how fast it burns.

## Lights

John, 2026-11-11: "deferred lighting techniques if not already implemented
or not effective". It was not implemented, and as a G-buffer it would not
be effective here; what it is for is, and that is built. First values.

- **What the renderer is.** A forward one: every fragment is lit as it is
  drawn, into a multisampled target, and leaves, grass tufts and smoke
  are cut out by coverage (alpha-to-coverage), which is what keeps far
  foliage at its true density and thin smoke half seen through. Deferred
  lighting draws the scene's surfaces into buffers first and lights them
  afterwards, once a pixel. Multisampling and cut-outs by coverage are
  what that gives up (or pays for with buffers several times the size),
  and water and smoke, being seen through, would still be drawn forward.
- **What deferred lighting buys** is many lights at a cost that does not
  grow with their number. Until now one fire lit the world
  (`Set_Fire`), and stage 6's first hearth was to be the second.
- **What is built: a table of lights with a grid over the world**
  (clustered forward lighting, in two dimensions, which is what a colony
  on the ground wants). The game gives each frame's lights
  (`Castle.Render.Clear_Lights`, then `Add_Light (place, strength, reach,
  colour)`; up to 512). Of those whose reach comes into the view the 64
  nearest the focus (`Max_Lights`) go to the shaders as a table, and for
  every 16 m of the world the renderer writes which of them reach it, a
  bit a light (`Place_Lights`: a 128 x 128 texture of two words a cell,
  written each frame there are lights). A fragment reads its cell and
  sums only those (`firelight`, `one_light`, in the shared sky source, so
  the land and the figures alike). Away from any light it costs one
  fetch; with none in the view, nothing.
- **One casts**: the nearest to the focus, through the cube of depth maps
  as before ("The fire's shadows", above). The others shine through
  walls and trees. That is the thing to settle when the first hovel has
  a hearth in it: a light that does not move could keep a cube of the
  land round it, drawn again only when a mesh there changes, and only
  the figures would want drawing each frame for the nearest; not built.
- `--lights N` scatters N fires round where the view began, about seven
  metres apart on a spiral (the first twelve drawn as fires), to see and
  to cost many at once.

What it costs (RX 6900 XT, 1280 x 720, the default view of the meadow at
night, GPU a frame): no lights 1.18 ms (as `main`); one, casting, 1.26;
eight 1.35; thirty-two 1.46; sixty-four 1.57 (twelve of them fires of a
hundred pieces each). By day, sixty-four cost 0.49 ms (1.74 to 2.23).
One fire at the camp is drawn as it was, to the pixel but for the flames'
own flicker.

Not there: shadows from more than one light; a light's reach beyond its
cell's neighbours being culled by what hides it; lights that are not
round (a window's, a lantern's cone); more than 64 in a view (the
furthest are dropped, with no fade).

## Foliage drawn soft

John, 2026-11-11: foliage "needs a bit more organic feel to it". Trees and
bushes are blocks of leaves, as the generator makes them, but they are not
drawn as cubes. (This was built on the crowns of generator 12, boxes with
their corners cut off; the same day he said "we can rewrite the trees",
and generator 13 grows them as lumpy domes: `world.md`, "Trees". On those
nearly every face lies along an edge, so the fraying was turned down and
the gaps filled, below.) First values, at the top of `castle-render.ads`.

- The mesher (`Castle.Mesher`, "Soft quads") gives a face of leaves, of
  needles or of a bush that lies along an edge or at a corner of its clump
  a quad of its own, and with it, for each of its four corners, which way
  the foliage lies from that corner of the block grid (from the eight
  blocks that meet there; ground and wood count as foliage, so leaves
  hug a trunk). The vertex shader moves such a corner: cut back 0.3 of a
  block along each axis it is open on (`Foliage_Cut`), and astray by up
  to 0.14 of a block by where it is (`Foliage_Jitter`). Every face that
  meets a corner moves it the same way, in the picture and in every
  light's depth map, so nothing gapes and a crown's shadow is the
  crown's. A clump's edges and corners are rounded off and no two alike.
- The light's normal turns over a cut edge (`Foliage_Bend`) and by a
  little from block to block (`Foliage_Ruffle`); the crown is lighter and
  darker in masses a metre or so across (`Foliage_Mass`); what stands out
  of a clump is a little lighter (`Foliage_Lift`) and frays: up to 22 % of
  the texels at a clump's very corner are open (`Foliage_Ragged`; it was
  half, on the boxes), none on a flat side. Far off the same share comes
  off the coverage, so a crown does not change as it nears.
- The gaps painted between the leaves (22 % of a leaf block's texels) are
  no longer holes: they are the dark inside of the crown, the leaf's own
  colour at 0.42 (`Foliage_Deep`). Only the back of the crown's far side
  is behind a gap, and backs are not drawn, so a round crown, which is a
  shell, stood against the sky like a veil. The light that falls through
  a crown onto the ground is the depth pass's own (a quarter of the leaf
  blocks let it through) and is as it was.
- The texels are as they were, laid on the block grid before it is moved
  (the shaders take the block and the texel from `v_grid`, not from where
  the vertex was drawn). Nothing moves with time: the sun's shadows are
  held still, and `tools/shadow_still.sh` reads 0.00 % as before.
- A flat side of a clump stays where it is and is meshed and merged as
  ever. (Moving those too, on a slow noise, made 43 % more quads over the
  whole view for little that showed; as built it is 15 %.) A corner on a
  stack's edge is not moved either: the neighbour stack's trees are not
  known to the mesher, and the two stacks must agree where a corner goes.

Not there: leaves that stir in the wind (the shadows would have to stir
with them); trunks drawn round (a trunk is a square column one or two
blocks wide); a bush shaped anew (it is the lump it was).

## Boulders drawn round

John, 2026-11-16 (the far view's third round, his words whole in
`Handoff_2026_11_16_haze_horizon_boulders.md`): "Let's smooth the
boulders." A boulder is the lump of blocks the generator makes it
(`world.md`, "Boulders"), stepped like everything else; it is drawn round
on the soft quads foliage is drawn on (`Castle.Mesher.Round_Boulders`,
`Castle.Render.Boulder_Cut`; `--no-round-boulders`: in steps, as it was).
First values.

- A boulder's face along an edge or at a corner of it is a quad of its
  own, and the vertex shader moves its corners half a block along each
  axis (`Boulder_Cut`, 0.5): an edge or corner open on two axes or three
  is drawn in, and a hollow in the rock itself (a corner with rock on five
  sides or more and nothing else) drawn out toward the open, so a step of
  one block becomes one slope and a notch is filled to one. No straying
  (foliage strays; rock is not to look ragged). The light at a moved
  corner goes by the way out of the rock there, the same for every face
  that meets it, so the rock is lit as a round thing and not by its
  facets.
- Its body is what is solid about it: grass round its foot, or a bush,
  is not counted. Ground is: so where it sits in the ground its foot stays
  where it was and no gap opens there.
- **On a stack's edge** (foliage's corners stay put there) a boulder's
  corners are moved as well, by what the stacks on both sides of it work
  out alike from the generator alone: the ground as it was made and the
  boulders' shapes as they were made (`Castle.Flora.In_Rock`, the test
  the generator draws one by). So the two stacks never disagree and no
  slit opens between them; an edit there is not seen (a corner may lean
  toward a stone taken away). 2,386 of the map's 4,477 boulders cross a
  stack's edge. (These two came first, for steps a close still showed on
  a boulder across a stack's edge; they changed it little. What took the
  steps away was the hollows drawn out, which came after: the steps were
  the rock's own notches, not the edge or the grass.)
- A face of anything solid that looks at a block of boulder is meshed,
  though the boulder hides it while it is whole: a corner drawn in would
  otherwise leave a slit where the ground under it should show (the
  ground's own corners stay where they are). Five close views and a low
  pan of 240 frames over the boulders by the stake, with no floor and no
  ground haze: no pixel of sky through, rounding on or off. The sun's
  shadows hold still as before (`tools/shadow_still.sh --timescale 0.05`,
  three runs: 0.00 %).
- **Its foot** (`Castle.Mesher.Boulder_Feet`, `--no-boulder-feet`; John,
  2026-11-16, of the boulders drawn round: "make the base of the boulders,
  so they don't look like balls plopped everywhere, they need extend into
  the ground"): where a boulder meets level ground (rock over the corner on
  one side, the open on the other, nothing but solid under it and ground
  among that), the corner is drawn out from the rock 0.75 of a block
  (`Foot_Out`) and down 0.4 (`Foot_Down`), marked with z code 3 in its six
  bits, so the lowest face leans out and goes under the ground a little way
  out; its light leans out and up (`Foot_Lean`). Never up and never over a
  step (the ground's own corners stay put); the same function of the
  generator's ground and rock on a stack's edge. Alone it is a quarter of a
  metre at most and did not show from 60 m: the rest is the generator's
  (generator 15, `world.md`, "A boulder goes into the ground"), which it
  finishes where rock meets ground.
- **Each quad cut along the diagonal that folds it least** (2026-11-17;
  John: "There is some flickering around some of the surface textures for
  the rock ... it looks like overlapping meshes to me"). A boulder's soft
  quad has four corners moved different ways, so it is not flat, and it
  was always cut into its two triangles along the same diagonal: where
  that diagonal was the wrong one, the two folded back across the faces
  round them and fought them for the pixel (hatched stripes, a few pixels
  at a time, as the camera moved). The vertex shader now works out where
  all four corners go (`rock_corner`) and cuts along the diagonal whose two
  triangles lie flattest. A slow pan past a boulder on a slope: 868 pixels
  stepping and stepping back over 120 frames, 30 now (the boulder drawn in
  steps: 67); past the one on a stack's edge 1,269 to 1,119 (in steps 978,
  the rest the grass). No frame cost seen. The rock of the mountains
  shimmers when the camera moves as well (its fine dark-and-light texels
  and one-block pits): that is older than the rounding (the second round's
  build the same) and was not changed.
- What the boulders are made of was untouched by the rounding (the flora's
  hash as it was, a serf prising off the same stone); the generator's
  change that came after it is in `world.md`. Quads in a view +0.4 %; a
  stack's meshing as long as it was; no frame cost seen (the view of a
  meadow strewn with them 1.77 and 1.79 ms, on and off; close up 0.53 and
  0.54). The far view's tiles draw boulders as they were, in their own
  coarse cells. With the feet and generator 15: quads in that view +0.6 %
  over the rounding alone (4,133,931 to 4,159,707), a stack's meshing 8.9
  ms of a worker (8.6 to 8.8 before; the corners on a stack's edge keep the
  last sixteen columns they worked out), the frame 1.79 to 1.82 ms; five
  close views and the low pan: no pixel of sky through; the shadows' still
  view 0.00 % in eight runs of ten and 0.01 % in two (the build before the
  rounding: 0.01 % in one of six).

Not there: a boulder's crags made rounder in the making (they are the
generator's noise; its foot was changed in the making, its round was not);
a stone a serf is carrying or has laid (fieldstone) drawn round.

## A dressed roof

John, 2026-11-12: "the roofs, are to be smoothed, but not rendered smooth
instantly, the builders smooth the roofs so they don't step, rounded edges
around the peremeter". A roof is laid in steps of thatch and then trimmed
by its builder, block by block (`habitation.md`, "The roof trimmed"). What
is drawn smooth is each block that has been trimmed, no sooner:

* **A block says it is dressed in its state** (`Castle.Blocks.Dressed`,
  with the way its top falls and whether it is at the eave, the ridge's
  one middle block, the end of its row, or the lower of two): the first
  use of a block's state byte. It is saved with the block, as every edit
  is.
* **The mesher** gives each face of a dressed block that shows a quad of
  its own, as it does a soft quad of foliage, marked with bit 31 as well
  (`Castle.Mesher`, "A dressed roof"; `Slope_Code`). The quad's corner
  bits then say exactly how far each corner is moved: the top edge on the
  side the block falls to a whole block down (so the steps of a roof are
  one slope), half a block at the eave (a blunt edge) and to either side
  of a ridge's middle block (a low cap), a quarter in at the roof's two
  ends. Where the roof hangs out past a gable or lies on one, the lower
  block's underside and the top of the gable's daub under it are brought
  up to the same slope, so a gable end is a clean triangle under a band of
  thatch.
* **The moves are the block's own, by its state alone**: nothing of them
  depends on what stands beside it, so a roof across a stack's edge is
  whole (foliage's corners on a stack's edge are left alone because they
  go by their neighbours; these do not). A face of anything that looks
  along a roof's row at a dressed block is shown, so a roof half trimmed
  has no hole where the trimmed part ends (within a stack: across a
  stack's edge the mesher does not know its neighbour's state, and a
  triangle may be open there until the row is trimmed through).
* **One shader decodes quads** (`Vertex_Source`, shared by the land's two
  programs and the sun's depth pass), so the shadow of a trimmed roof is a
  trimmed roof's. The light goes by the face as it lies: the vertex shader
  works out the moved face's normal and hands the turn to the fragment
  shader in `v_bend`, which foliage and tufts already use for theirs.
  Texels and the block a fragment belongs to still come from `v_grid`,
  where the vertex was on the block grid.
* What it costs is in `habitation.md`, "What it costs": the two branches
  are in the land's shaders whether or not a roof is in the view (0.02 to
  0.05 ms at the fixed views with the most land in them), and a dressed
  roof is a quad to a block face (7,300 quads a hovel against 6,000).
  `tools/shadow_still.sh` reads 0.00 % as before.

Not there: the roof's underside inside the house (in steps still); a
pitch other than one to one; a ray that meets the slope and not the block
it was.

### Fuller, with ragged edges (2026-11-19)

John, 2026-11-17: "Make the tatched roofs thicker when smoothing, fuller and add charecter of straw
to the edges of the roof". Trimmed, the slope lay in the hollows of the roof's steps: the nose of
every step was cut away, and the eave's edge was half a block thick. With `Castle.Mesher.Full_Thatch`
(the default) the slope lies over the noses instead: each block's inner top edge is drawn a block up
and its outer edge where it is, so the roof is a block thicker measured upright, of the same blocks;
the eave's edge is a whole block and is drawn out a little; a ridge's one middle block lies level. The
corners along the eaves and at the verges are marked (a slope quad's bits 20 to 23, one a corner),
and the renderer lets each hang up to `Thatch_Rag_Drop` (0.4 of a block) and draws it in or out by
0.2 to 1.8 of its quarter block, by a hash of the place the corner is moved to, so every face that
meets there agrees. `--no-full-thatch`: as it was drawn. Nothing but the drawing: the blocks, the
walking map and the pointer's ray are as they were. `Castle.Cutaway.Eave_M` is 0.4 since (a ragged
eave reaches 0.36 m past its wall).

### The whole of its top ragged (2026-11-19, his answer)

"The thatch looks great now, can you do that ragged look to the entire surface of the roof, you
nailed it on the ends, exactly what I wanted." Every corner of a dressed roof's top is marked too
(`Castle.Mesher.Ragged_Surface`) and hangs up to `Thatch_Surface_Drop` (0.4 of a block), by the same
hash of the place it is moved to, so the faces that meet there agree, the step faces hidden under the
slope among them. The renderer tells a top corner with no pull along the ground from an edge's, so
the eaves and verges keep `Thatch_Rag_Drop`. **The edges are a measure, to the pixel**: with the
surface's amount at zero, and with `--no-ragged-roof`, a still of four roofs is the still of 234818c
(compared above the camp fire, whose sparks differ between any two stills).

## A roof's timbers cleared with it (2026-11-19)

A house begun since 2026-11-19 has tie beams, and a storehouse king posts, rafters and a ridge beam,
inside its walls. They clear with the roof, by their place: timber inside a cleared house's walls,
`Timber_Up_M` (1.9 m) or more over its floor, is drawn as the thatch over it is (a share by the walls,
nothing `Taper_M` in). `Castle.Cutaway.Timber_Cover`, the same sum in the land's shader
(`timber_cover`), and the pointer's ray passes them then (`Castle.Rays.Stops`). The trusses in the
gable ends are of the walls and clear with those; plank is among what a wall can be made of since (a
window's jambs).

## Doors and the cart's wheels (2026-11-19)

Props, drawn only. A door's leaf (`Castle.Props.Door_Leaf`: upright planks, two ledges inside, iron
straps and a latch outside; a mirrored one for a leaf hung from the other jamb) is put in each
doorway the colony names (`Doorway_At`), swung toward the inside over 0.45 s while anyone is within
1.3 m; not drawn where its wall is cleared for the eye. `--no-doors`; `--doors-open` for stills
(`--no-window-trim`: no trim drawn round a window). The
cart's wheels are turned about their axles by as far as the cart has gone along its shafts since the
frame before (`Put_Cart`'s `Roll`). `--no-wheel-roll`; `--wheel-turn R` for stills.

## A building drawn turned (2026-11-19: the first step, the draw)

John: "can't we just \"detatch\" the entire building and rotate it?" (`docs/production/briefs/Stage_6_brief.md`,
"Buildings at 45 degrees", has the steps). `Castle.Render.Set_Turns` takes up to `Max_Turns` (48) turns:
a box on the map, a height, a point and an angle. In the land's vertex shader every quad of timber,
daub, thatch or plank whose block is in a box, from that height up, has its corners turned about the
point (`u_turn_box`, `u_turn_how`, `u_turn_z`); the ground in the box, and what grows on it, is left.
The same vertex shader draws the land into the sun's maps and the fire's, so a turned building casts
turned. The fragment shader lights it by the face as it is turned (`nw`, from `v_turn`), and still goes
by the face on the grid (`n`) and the place on the grid (`v_grid`) for texels and corners; what clears
a roof or a wall goes by where the house stands on the grid (`v_home`).

**The ground a turned building stands on loses the mesher's shading** (since the ground of step
three): the mesher darkens the ground along a wall's foot, and those walls are drawn elsewhere, which
left the outline of a house that is not there. A top face that is not of a building's stuff, in a
turn's box at its pad's level, is drawn unshaded (`v_ao` set whole; `u_turn_all`, the box all the
turns' boxes lie in, is tried first). The plan of a house being built, its door's mark and the
outline of the house pointed at go by `House_View.Drawn` and `Drawn_Door`.

**A turned house's floor is stepped by the texel** (his question of the same day: "The textures are
5x5 on the face of each block right, can't we step the texture so it falls under the wall of the
house?"; `Set_Turn_Floor`, the game's `--no-turn-floor`). The floor is laid in blocks under the house
as drawn, and at 45 degrees a block's corner stood past the wall at every step. In the fragment
shader the texel (a fifth of a block, 5 cm) is found first; for a top face at a turned house's pad
its middle is taken back through the turn and tried against the walls' outer faces as they stand
(`u_turn_walls`): inside it is drawn as floor whatever its block is, a floor block's texel just
outside as turf, and the turf fringe is kept off both. `f_mat` is what the texel is drawn as from
there on; `v_mat` stays what the block is. With no turn set nothing is asked.
Each turn has its own floor (`Turn.Floor`, `u_turn_mat`, since 2026-11-20): a hovel's beaten earth, a
storehouse's plank. **A storehouse on a stockyard along a path at 45 degrees is a turn too**
(`habitation.md`): about the point the colony keeps (`House_View.Pivot`), its box its walls' outer
faces and 0.25 m (its eaves, to the block: what of its yard stands a block further off is not turned).

**The far view draws a turned house turned** (2026-11-20). A tile's cells of a building's stuff go
through the same turn in the vertex shader (a cell is asked by its middle and its top; one that
holds the ground under a wall with the wall's foot stays, as turf at the pad's level), and
`Castle.Lod`'s mesher draws the top of whatever a building's cell stands on, so the ground a turned
house stands on is whole there. A floor block's texel past a turned wall is drawn as the ground
beside it (turf where the mesher marked turf beside the block, else bare earth).

Drawing only. The blocks are where they were for the walking map, the builder and the save. **The pointer and the cleared roof go by where the house is
drawn** (the fourth step, the same day): `Castle.Pick.Look`, given the caster, walks the ray taken back
through a turned house's turn into the blocks again (`interface.md`); `Castle.Cutaway.Roof` carries
the turn, and the eye, what it looks at and what the pointer is on are taken back through it (`Home`)
before its tests, the shader being given the eye as each cleared house stands (`u_roof_e`) for which
walls face it. With no turns set the picture is as
before (three views, the proof's options: 6 to 19 pixels of 1,024,000 differ from the build before,
which differs from itself by 7 to 32). One view with three hovels turned cost 0.76 ms of the card where
it cost 0.78 unturned (one short run each).

`--turn-houses` (the game's, for looking): every hovel turned 45 degrees about the middle of its
doorway. **What is inside is drawn through the same turn** (the second step, the same day): a serf
within the walls (`Castle.Serfs.Turn_About`: its bones turned at `Submit`, after it is animated where
it stands on the map; `Frames_Home` is that place, `Frames_Of` and the other accessors the turned
one), its cloak (`Castle.Props.Put_Cloth` with a point and an angle: the cloth is still worked out on
the map), and the house's own props (the game's `Put_In_House`: the pallet, the door's leaf, the
trim). `--clock-add H` moves a loaded save's clock on with the colony left as saved, for a still of
sleepers by daylight.

**Since the third step a hovel carries its own turn** (`Castle.Colony.House_View.Turn`: an eighth of a
turn for one placed beside a path at 45 degrees) and the game draws by that; `--turn-houses` still
turns every hovel. Its builder within three metres of it and the ladder at its eave go through the
turn; `Castle.Serfs` brings a turn on and off over a moment (`Turn_Want`), so nobody jumps.

## A roof cleared on the camera's ray

John, 2026-11-13: "ok I guess it is time, and we should have planned for
this and i forgot, semi-transparent roofs on the ray of the camera, It
would be nice to have a tapering transparency with full transparency in
the middle and semi-trasnparency along the edges wher the roof meets the
walls". Built with first values of mine (`Castle.Cutaway`, at the top of
`castle-cutaway.ads`); drawing and pointing only: the roof is still there
(it casts its shadow, a sleeper is under it), nothing of it is saved and
the colony knows nothing of it. `--no-cutaway` is the roofs as they were.
His answer to the first build, the same day: "For the roof let's run it to
the mouse and the camera, along with an option to have all roofs
transparent, we can do the same with multi-level buildings, instead of
slicing the environment by elevation, you can add feedback on that if you
have a better idea." So the pointer's ray clears a roof as the camera's
line does, and one key clears every roof (below); of buildings of more
than one floor nothing is built (there are none yet: the handoff has what
was said back).

* **Which roof**: a house that the line from the eye to the focus (the
  point the camera circles), run on `Past_M` (1.5 m) past it, passes
  through; **and a house the pointer's ray passes through** on its way to
  whatever it lands on (the game's `Follow_Roofs`: where the ray landed a
  frame ago and 0.3 m on, so the answer is the same with the roof whole,
  the ray on its thatch, and cleared, the ray gone on to the floor or out
  by the door). "Through" is `Crosses`: under the roof's two slopes (a
  ridge along the longer walls, pitched one to one from the ridge's height,
  half a metre over them still counting), within the walls and eaves, from
  the floor up. Not the box round the house: a ray that only passes over
  the ridge to the ground behind clears nothing. The whole house, not the
  roof alone: at the default tilt the line to a hovel's middle comes in
  through its near wall under the eave. While the pointer is on the
  interface, or a menu is open, the house it last pointed at stays cleared
  (a roof does not close over what its menu is about). Only houses with
  thatch on them are offered (roofing, trimming, standing).
* **Three views** (John, 2026-11-13: "We can have the H k toggle through,
  dynamic transparency, full trasnparency, or no transparency"):
  `Castle.Cutaway.View` is `Dynamic` (the houses the eye's line and the
  pointer's ray cross), `Full` (every house offered) or `None`. The H key
  (`Open_Roofs` in `Castle.Input.Bindings`, a row of the help panel) goes
  through them in that order and says which in a note (the first and the
  last look alike until something is pointed at); `--all-roofs` and
  `--no-cutaway` are the second and the third for a scripted run. A load
  leaves the view as it is. Forty-eight houses at once at most
  (`Max_Roofs`, every house a colony can have: the shader's arrays are
  that long).
* **The walls on the eye's side** (John, the same message, asked whether
  walls should be cut down and light let in: "Let's cut down the walls
  in-line with the camera too, the transparency is there so the player can
  just see through them, as far as the game is concerned the walls are
  still there to block light"): of a house whose roof is cleared, a wall
  whose outward side faces the eye is cleared with it, whole of it: panel,
  timber and gable. **By its place, never by what it is made of** (the
  frame's timber is a trunk's material): within `Wall_M` (0.27 m) of the
  walls' outer line, above the floor; the shader asks it only of what a
  wall can be made of (`u_walls`: daub, timber) inside one box round every
  cleared house. How squarely a wall faces the eye is the cosine, level,
  between its outward side and the way to the eye: whole edge-on
  (`Face_Lo`, 0.05), clear from `Face_Hi` (0.30), a smoothstep between,
  dithered by the pixel as the roof is. The walls beyond stand and are
  seen from inside. `wall_cover` in the shader is the same sum as
  `Castle.Cutaway.Wall_Cover`. Light is as it was: the sun's maps are not
  touched, the walls and the roof cast their shadows, and the inside is in
  them.
* **The ground a wall stands on is drawn** (`Castle.Mesher`,
  `Under_Wall`): the top of the ground under daub or timber, which the
  wall hides, would be a slit into nothing under a cleared one. It is
  under every tree's trunk as well (the same timber): 2,274 quads more of
  5.0 million at the forest's fixed view, 1,847 at the camp's.
* **How much of it**: drawn at `Edge_Cover` (half) over its walls and its
  eaves, thinning inward to nothing over `Taper_M` (1.25 m, a smoothstep):
  its middle is open, its outline stays. It clears over `Fade_S` (a quarter
  of a second of drawn time) and comes back the same way when the line has
  left the house; a roof no longer offered is whole at once, and a load
  makes every roof whole. Of the roof only thatch is cleared (the walls
  on the eye's side: below).
* **Drawn in the land's shader**, both programs (with and without the wet
  look): a thatch fragment inside a cleared house's box asks `roof_cover`
  (the same sum as `Castle.Cutaway.Cover`) and, under multisampling, covers
  that share of the pixel's samples through alpha to coverage, dithered
  between whole samples by a 4 x 4 pattern fixed to the pixel (four samples
  are five steps; never by the frame). With `--msaa 0` it is a dithered
  discard: a screen door. The sun's maps are drawn as before
  (`Draw_Casters` is untouched): the roof's shadow stays on what is under
  it.
* **The faces a roof hid are drawn** (`Castle.Mesher`, `Under_Roof`): a
  face of a wall, a gable or the frame that thatch lies on, which a whole
  roof hides, would leave the wall's top open under a cleared one; it is
  meshed (with no occlusion of its own) and hidden by depth while the roof
  is whole. Six hovels gain 86 quads all told.
* **The pointer goes through what is not drawn**: `Castle.Rays.Stops`
  passes a roof's thatch where it is drawn at less than half, and
  whatever stands in a cleared wall's place (`interface.md`, "Pointing at
  things").
* What it costs: with no house in the view nothing measurable (the camp's
  fixed view 2.03, 2.01 and 2.04 ms against 2.01, 2.00 and 1.99 for the
  branch before it, back to back; the meadow 1.79 against 1.77); six
  hovels close up with one cleared 0.41 ms, with `--no-cutaway` 0.41, the
  build before it 0.40. With the pointer's ray and every roof (three
  streets, 26 hovels and a band of forty in view, 1280 x 720, twice each
  way): 1.45 and 1.47 ms of GPU and 0.63 of CPU as it stands, 1.44 and 1.48
  and 0.63 to 0.64 with every roof cleared, 1.43 and 1.47 switched off,
  1.45 and 1.46 and 0.63 for the build before: nothing measurable, the
  house views asked every frame included. With the walls (the same view,
  twice each way): every house open 1.52 and 1.52 ms against 1.48 and 1.51
  before the walls; as it stands 1.49 and 1.50; none 1.49; CPU 0.63 to
  0.64 throughout. The forest's fixed view 0.49 ms against 0.50, the
  camp's 2.05 and 2.00 against 2.03. `tools/shadow_still.sh` reads 0.00 %
  (its view has no house in it: it says the land's shader was not
  disturbed, nothing of a cleared house). Looked at from close and low,
  under the eaves (tilt 0.15, 6 m off, two sides): the room is seen
  through the near walls and no slit shows where the roof lay on the
  cleared beam (the roof over it is cleared too). The fade through
  edge-on was seen in stills at several turns, not with the camera
  turning: there is no scripted turn.

Not there: light let in where a house is open (his word: the walls and
the roof still block it); anything for a building of more than one floor;
a wait before a house opens under the pointer. With a house open under
the pointer the dig brush reaches the floor, not the thatch or the near
wall: the H key's third view (none) is the way to them. Through a cleared roof, the far slope's underside shows (in steps)
within the taper by the walls, and the top block of each gable shows as a
small pale square at the ridge's ends.

## Grass

John, 2026-11-11: "grass can get a slight overhaul". A tuft of grass, of
grain or of wild vegetables was a block with blades painted on its four
sides and a striped lid, lit as four walls: the two sides away from the sun
were nearly black, so a meadow was a field of dark bars, and the risers of
its steps were black too. First values, at the top of `castle-render.ads`.

- The mesher (`Castle.Mesher`, "Tufts") gives each plant standing on the
  ground quads of its own: four sides as high as the plant and a top, never
  merged with the tuft beside it, a side wherever no solid block stands
  against it. So every tuft is whole by itself, and the vertex shader moves
  its top by the column it stands in: leaning up to 0.24 of a block any way
  (`Tuft_Lean`), drawn in by 0.16 of a block on every side (`Tuft_Taper`),
  standing between 0.55 and 1.3 of its height (`Tuft_Low`, `Tuft_High`).
  No two tufts are alike and none is a cube. Nothing moves with time.
  A plant more than a block high (long grass, grain) is stalks below its
  top block, whole from foot to top, with its tips or its ears at the top
  only (they used to repeat block by block up it). Tufts come last among
  a stack's quads and every light's depth map is drawn without them
  (`Castle.Mesher.Mesh.Cast`): they cast nothing, and used to be drawn
  into each map and thrown away texel by texel.
- A tuft takes the light as the turf it stands in does: its sides' normals
  are turned three quarters of the way up (`Tuft_Up`), it carries no
  occlusion, it is darker at the root and lighter at the tip (`Tuft_Root`,
  `Tuft_Tip`). Seen from above it is the tips of its blades, a third of the
  texels of its top (`Tuft_Tips`; grain's ears two fifths, `Grain_Tips`),
  not a lid; wild vegetables keep their painted rosette. It still casts no
  shadow and is still buried by snow.
- The side of a block of turf, the riser of a step in a meadow, is a bank
  of grass: its normal is turned up by 0.6 (`Turf_Up`) and it takes the
  sun's shadow from just above its own top edge, so a step is not in its
  own shade; what a tree or a hill casts falls on it as before, and its
  foot keeps the mesher's occlusion. Earth and rock are lit as they were.
- A meadow is lighter and darker in drifts, on a noise about ten metres
  across and one of thirty (`Meadow_Tone`, 14 % either way), and yellower
  here and there (`Meadow_Sere`); the tufts in it go by the same. Where
  the tufts themselves stand is the generator's (`world.md`, "Tall
  grass": in drifts, some of it two blocks high).

Not there: grass that stirs in the wind (the shadows are held still, and a
tuft casts none, so it could: it was not asked for); flowers; grass worn
by where the band walks, beyond the fringe of a laid path.

## The fringe between turf and bare earth

John, 2026-11-11: "it would be nice if the edges around the paths and
compacted areas had some charecter too it". Nothing of the ground
changed (no block, no save): it is drawn. First values, at the top of
`castle-render.ads`.

- The mesher marks, on every top face of turf (Grass) and of bare earth
  (Footpath, Dirt), which of the eight blocks round it are the other kind,
  within a block of its height (`Castle.Mesher`, "Fringe"; eight bits a
  quad, part of what faces must share to merge). Across a stack's edge it
  knows the neighbour's ground by the generator's column and by the
  edits, so a path that crosses from stack to stack has its fringe on
  both sides.
- Along the marked sides, texel by texel: grass creeps onto the earth,
  85 % of the texels at the very edge (`Fringe_Grass_Share`), thinning out
  over a width that wanders along the edge between 0.15 and 0.95 of a
  block on a noise five metres across; the turf beside the earth is worn
  through to it the same way (65 % at the edge, over 0.35 to 1.3 blocks);
  the grass left by the edge, and the grass that crept in, is trodden,
  duller and yellowed (`Fringe_Trodden`); and about one texel in sixteen
  at the edge is a pebble (`Fringe_Pebbles`, Warm Gray lightened). So a
  path's edge is ragged and no two metres of it alike, and the trodden
  ground round a fire has no stair-stepped rim.
- Far off, where a texel is under a pixel, the two kinds are blended by
  the same share instead, so the fringe does not shimmer. A texel of
  grass on a path dries with the season as grass does.

Not there: a fringe wider than the one block either side that knows its
neighbour; one against sand, gravel or rock; wheel ruts, puddles.

## Rounded figures

Every box of every figure is drawn rounded and tapered (`people.md`,
"Rounded boxes"): six faces of nine cells, 324 vertices a box where it was
36, in the picture and in each light's depth map (`Box_Face_Source`,
shared by the two shaders, so a figure's shadow is the figure's).

What the looks of 2026-11-11 cost together (soft foliage, the fringe,
rounded figures, grass, and the trees and tall grass of generator 13; RX
6900 XT, 1280 x 720, the default view of 160 m, GPU a frame, now against
`main` before any of it): the open meadow 1.71 ms against 1.30; looking
down on the forest from 26 m, 0.46 against 0.38; the reference band at
its camp by day 2.05 against 1.48, and at night with the fire casting
1.45 against 0.93. Quads resident over the view 4.60 million against
3.71. (After the first three alone, on the trees and grass of generator
12, it was 1.66, 0.45, 1.96 and 1.35 ms and 4.26 million quads: the
tufts drawn one by one made it 4.81 million and 1.96 ms on the meadow,
the round crowns 5.22 million and 2.03, and standing the tall grass in
drifts, half as many tufts, brought it back.)

## Serfs of voxel parts (2026-11-23, merged 2026-11-24)

A serf is drawn as voxel parts (`people.md`, "Voxel parts"; `--no-voxel`: as
boxes). `Castle.Figures` keeps each voxel look's drawn quads on the CPU and, on
the GPU, a slot of its own in one buffer (`Vox_Data`, binding 14): its palette,
its part table (each bone's part: where its bytes begin, its size, its corner
in voxels of the bone's frame) and its voxels' bytes, four to a word. Each
frame a voxel figure's bones go into the bone buffer with the box figures', and
its quads into one list (`Vox_List`, binding 13: the quad's two words, its
figure's first bone, its look). `Vox_Vertex_Source` pulls each quad's corner
by the vertex number, six a quad: from its part's corner and its own, through
its bone, wound counter-clockwise seen from outside, and a hair (0.004 of a
voxel) past its edges so that no crack shows where quads of different sizes
meet. `Vox_Fragment_Source` reads the face's colour where it is drawn (the
voxel under the point, its byte, that entry of the palette) and lights it as a
box figure is lit. `Vox_Caster_Vertex_Source` draws the same quads into the
sun's figure maps and the fire's six faces. One draw a pass. The slots take
17 MB of the GPU's memory whatever is in them, the list 2 MB.

What it costs (RX 6900 XT, 1920 x 1080, seed 1, release; a run of 600 frames
each way, twice): sixty serfs in a row 14 m off, 2.41 and 2.41 ms of the GPU a
frame as voxel parts (1,557 triangles a serf; 1,582 with the smaller head of
2026-11-24 and 1,762 at the merge, on 22551f9: neither timed again), 2.35 and 2.39 as boxes. Their
looks made in one frame when they arrive, some 4 to 6 ms each there (221 and
338 ms for the sixty); the band of the reference stake dressing for winter at
the night's turn, one serf a frame, 4 to 8 ms of figures in each of thirteen
frames (measured on the first try of the reference body, 447 triangles a
serf). The CPU took 1.53 and 1.89 ms a frame as voxel parts over the run after
the view had filled, 1.04 and 1.22 as boxes, the sixty looks' making among it
(a gate was running beside these two runs).

## What multisampling costs

John, 2026-11-11, watching the stress test: "I think our deferred lighting
and MSAA 4x is getting expensive", with a note from the design side on
dropping multisampling: a single-sample G-buffer, SMAA 1x on the lit
picture with edges found from depth, and for foliage either distant leaf
blocks drawn whole in their mean colour or a fixed screen-space dither,
never hashed alpha. Measured before anything was changed; nothing of the
note is built. His call.

- **There is no deferred lighting.** The renderer is a forward one
  ("Lights", above), and stays one in this work.
- **4x multisampling is half of the GPU's frame** (RX 6900 XT, GPU a
  frame, `tools/look_cost.sh --msaa N`):

  | view, 1280 x 720 | none | 2x | 4x (the default) | 8x |
  |---|---|---|---|---|
  | open meadow | 0.85 ms | 1.31 | 1.71 | 2.10 |
  | looking down on the forest | 0.31 | 0.43 | 0.47 | 0.53 |
  | the band at its camp by day | 0.97 | 1.51 | 1.94 | 2.33 |
  | the same at night, the fire casting | 0.79 | 1.14 | 1.47 | 1.72 |
  | the forest's edge from the lowest tilt | 0.79 | 1.07 | 1.23 | 1.43 |
  | the camp in rain | 1.12 | 1.78 | 2.30 | 2.77 |

  The camp by day at the default window of 1600 x 900: 1.12, 1.69,
  2.11; at 2560 x 1440: 1.62, 2.41, 2.91. (With the screen's rate held,
  as in play, the timer reads about half as much again: 3.3 ms at
  1600 x 900.) It is dear here because the land is millions of small
  quads, and every pixel a quad's edge crosses is shaded once for each
  quad that touches it.
- **It is a millisecond of a frame that has sixteen.** At 2560 x 1440
  with 4x the GPU's frame is under 3 ms. The frames he saw drop were the
  CPU's, the colony's steps at 240 times speed (`Stress_test.md`).
- **`--msaa 2` is there today** and takes a quarter off the frame;
  `--msaa 0` shows the picture with none (already built to hold: a
  crown's frayed corners and a tuft's tips are whole far off without
  coverage to thin them, and the gaps between leaves have been the
  crown's dark inside, not holes, since generator 13, so most of the
  note's fix for foliage is in place).
- **What the note's way would want here that it does not say.** Edges
  found from depth alone miss a crease: where a block's lit top meets
  its shaded side the depth runs on unbroken, and those creases, every
  step of a terraced meadow, are most of the edges in a world of blocks.
  The pass would have to find edges from the faces' normals as well
  (six of them, so it is exact), which wants them in the picture. And
  an edge smoothed after the fact is only as stable as the pixels are:
  trunks, limbs and tufts a pixel wide crawl as the camera moves, where
  multisampling holds them, and there is nothing temporal here to hide
  it (by rule: a still view is still).
- **The land is drawn nearest first** since this work
  (`Castle.Render.Near_First`; `--loadorder` for as it was): what is
  hidden is thrown out by its depth before it is shaded, which is the
  half of what a deferred pass saves that a forward one can have for
  nothing. From the default tilt, where little hides anything, it is
  0.03 to 0.06 ms (2 to 3 %); from the lowest tilt across the forest,
  where the land stands in rows behind itself, 2.33 ms to 1.98 (15 %),
  and 2.76 to 2.31 in a storm. One counting pass over the stacks in
  view, by how far their middles are from the eye. The picture is the
  same to within a level: one pixel in eleven differs by one or two of
  255 between the two orders, where two runs in the same order differ in
  one pixel in twenty (the coverage's own dither), and some thirty
  pixels by more.

Against shimmer: detail fades as it shrinks below a pixel, measured per
fragment from screen-space derivatives.  Texels fade to their block's
average colour, then per-block variants fade to the material's average.
Once whole blocks are under a pixel, ground is lit from the smooth 1 m
height field instead of its block faces, so terrace steps can't beat
against the pixel grid.  The world is drawn into the renderer's own
multisampled target and resolved to the window, so MSAA never depends on
the window system; cut-outs (leaves, grass) use alpha-to-coverage there,
which keeps distant foliage at its true density.

## A stockyard's pieces (2026-11-20)

What of a stockyard is drawn as its design has it rather than as its blocks are laid: a covering's
roof once smoothed, and along a path at 45 degrees the fence's rails and the planks over its
gateways (`habitation.md`, "Turned hovels walked where they are drawn; a stockyard's pieces"). **Their
blocks stay in the world** with the state `Castle.Blocks.Piece` (log, plank or thatch, never
dressed), and what draws the land leaves them out: `Castle.Blocks.Seen_Mat` is what a block is drawn
as, read by `Castle.Mesher` (`Mat`, the band's top, a face's material) and `Castle.Lod` (a cell's
eight blocks). So no stepped shadow is cast and the far view has none of them. The pieces are
props (`Castle.Props.Rail`, `Thatch_Tile`, `Thatch_Roll`; the game's `Show_Yard_Pieces` from
`Castle.Colony.Yard_Pieces`), lit and shadowed as the props are, drawn at any distance. A covering's
roof is one box the size of the roof (3 m by 2.1 m, 20 cm thick): tiles of a metre showed a dark seam
at every edge from twenty metres off, where the sampler took in what lies round a face in its skin.
A frame for a piece must stay right-handed (its X, its top's normal, its slope): turned inside out
it draws the box's insides.
