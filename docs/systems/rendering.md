# Rendering

- Packages: Castle.Streaming, Mesher, Textures, Render, Camera, Colors, Currents (and, of the figures'
  layer, Castle.Fire, which is described here with the light it gives)
- Check: camera_check (needs a window); `tools/shadow_still.sh` measures whether the shadows hold still
- Saves: nothing saved but the camera
- Stage: phase A; the palette on 2026-11-08 (Handoff_2026_11_08_world_look.md); shadows and
  the fire on 2026-11-10 (Handoff_2026_11_10_shadows_and_fire.md); soft foliage, the fringe,
  rounded figures and grass on 2026-11-11 (Handoff_2026_11_11_models_pass.md)

How the view works: worker tasks generate each 8 x 8 m stack and greedy-mesh
it into packed 8-byte quads, nearest stacks first.  The main thread uploads
at most 48 meshes a frame into one 256 MB quad buffer and draws everything
with two multi-draw-indirect calls (solid, then water), pulling vertices
from the buffer in the shader.  Stacks that leave the view radius are freed
(two stacks of hysteresis), except the colony's ground, which stays loaded
and is simply not drawn past the haze.  Textures are 5 x 5 texels per face, four
variants per material, generated at start-up.

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
  readable moonlit blue at night. `Castle.Render.Set_Time`.
- The sky is drawn into whatever the world left empty: a gradient, the sun
  and the moon, and the clouds over them, drifting on the wind (see "The
  sky" below). Distant ground fades into the sky's own colour for that
  direction, so the edge of the loaded world meets the horizon instead of
  a wall of fog.
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
