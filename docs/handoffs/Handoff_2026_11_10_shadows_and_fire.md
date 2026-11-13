# Castle Game handoff (2026-11-10: shadows and the fire, between stages 5c and 6; closed, accepted as built; Claude Code)

- **Closed 2026-11-10.** John, after trying the build: "Tested and passed, everything works great". The
  first values stand, his to tune. The ten rules were put to him as "agree, or change any" and that was his
  whole answer: they are accepted as the build has them, not ruled on one by one. One he was told was his
  call and did not take up stands by default: grass, grain and wild vegetables cast no shadow.
  `shadows-fire` is merged into `main`; the zip is made from `main`.
- Code: GAME_alpha_1_3/compiled, branch `shadows-fire` from `main` at ddaeadd (the water's look, closed), seven
  code commits: 962d991 (the GPU timer), c7b6c68 (the sun's shadows held; figures cast), 5c46665 (the fire
  casts), 434d966 (the fire's look, `--stoke`), 36a6348 (the figures' map's reach, the fire on ground it
  grazes, the demo's script), f7ea334 (the light's height named), 3029983 (the fire by day goes by how high
  the sun is; the disc with `--noshadows`). The zip is the closing commit, documents only after 3029983.
  Zip: CASTLE_GAME/releases/castle_game_shadows_fire.zip. Demo: shadows_and_fire.mp4
  (tools/demo_shadows_fire.sh). Stills: shadows_fire_before_after.png (the top row before, the bottom after).
- Checks: all nine pass in debug from a clean copy (`git archive`) of 3029983, the last code commit, built from
  nothing, with the six known warnings; `tools/reference_check.sh` passes there (both runs). None of them looks at a picture: what is below was measured
  and looked at in recordings.
- Versions: none moved (Generator_Version 12, save format 6, colony blob 13). Nothing of the simulation, the
  generator or a save changed; `Castle.Colony.Stoke` is new and only a scripted start calls it.

## What John sees on first launch
1. **Shadows hold still.** With the clock running nothing in a still view flickers any more: not the
   trees' dapple, not the small shadows of the terraces.
2. **People, deer and everything set down or carried cast shadows**: the stake, baskets, logs, the pot and
   its crossbar, a deer across a hunter's shoulders. The dark disc under each figure is gone in sunshine
   (the shadow replaces it) and still there at night and under heavy cloud.
3. **Shadows are softer at their edges, and at dusk and dawn they fade** with the light where they used to
   switch off all at once.
4. **The fire is new**: many small pieces of flame that rise, draw in and cool from pale yellow to red,
   a spark now and then, pale smoke going with the wind. With the fire out its bed is grey ash (it used to
   glow always).
5. **The fire casts shadows**: at night the people round it, the posts of the crossbar and the steps of
   the ground throw long shadows away from it, and they stir with the flames.
6. **By day the fire lights much less of the ground round it** than it did (its own stones, little else).
7. The GPU time in the debug panel (F3) now counts the shadow passes; it reads about what it read before
   only because they cost a third of what they did.

## Rules put to John (2026-11-10; accepted as built, above)
His message is the brief: "shadows need work, they flicker, and not everything has shadows yet, we need to
get that handled so we can streem line shadowing new assets. The current fire animations, the turning
bouncing red blocks, is cute, but it feels unnatural, also ties into shadows as a light source so I think we
can handle both in a session." Built from that with first values of mine, his to change:

1. Everything solid casts: the land, and whatever is drawn as a figure (people, animals, props, loads).
   Grass, grain and wild vegetables cast nothing (as before); flames and sparks cast nothing (they are the
   light); smoke casts nothing.
2. The sun's shadows hold still but for the sun's own slow travel. The fire's stir, because its light does.
3. Shadows are cast for as long as the sun gives light, never longer than a sun 4 degrees up makes them,
   and fade with it.
4. The disc under a figure is drawn only where no sun casts its shadow.
5. What is within 0.6 m of the fire's light (its stones, its bed, the pot over it) casts no shadow from it.
6. What the fire cannot see, or is turned from it, keeps a quarter of its light.
7. By day 35 % of the fire's light shows, in sunshine and under cloud alike; all of it at night.
8. Flames: small pieces that rise, narrow and cool; none turns or bobs in place. 0.62 m tall at full heat,
   half that as the wood runs out. Sparks to 1.6 m. Smoke to 3.5 m, pale, half seen through. The light
   comes from 0.4 m over the bed and wanders 3 cm each way.
9. One fire lights the world and casts.

(In the report to him these were ten: the first as three, with grass and its kind apart as the one that
was his call, and the fourth among what he sees on first launch.)

## Built
- **One routine draws what casts** (c7b6c68): `Draw_Casters` in castle-render.adb, the stacks' solid quads
  and every box `Castle.Figures` was given, into any light's depth map. A new block, prop or animal casts
  from the sun and from the fire with nothing more to do. Not casting: a material in `u_plants`, a box with
  `Glow`, a look made with `New_Look (..., Casts => False)`.
- **The sun's maps are held** (c7b6c68). Two directions, one the sun has passed and one it is coming to,
  each with a 4096 x 4096 map of the land and one of the figures; the shade is the two mixed by how far
  along the sun is (`Hold_Sun`). The next direction lies where shadows will have moved `Shadow_Hold` (1 cm a
  metre of height) and no nearer than the sun goes in `Shadow_Min_Frames` (12). A jump of the clock, or the
  clock run back, starts again from where the sun is. The land's map follows the focus `Shadow_Snap` (64)
  texels at a time. Nine taps a lookup (it was four).
- **The figures' map** (c7b6c68, 36a6348): round the focus, every frame, 24 m each way at its smallest
  (1.2 cm texels) and doubled until it reaches three times the eye's distance.
- **Dusk and dawn** (c7b6c68): `Shadow_Low_Sun`; the maps are live while the sun's colour is not black.
- **The fire's shadows** (5c46665, 36a6348): six 512 x 512 faces of a cube map about the light, the land
  within 12 m and every figure, every frame. `Fire_Near_M`, `Fire_Fill`, `Fire_Reach_M`.
- **Castle.Fire** (434d966, f7ea334): `Show (bed, heat, time, wind)`, `Light_At`, `Light_Strength`. A pure
  function of place, heat and the drawn time: no state, nothing saved. Its tunables are at the top of
  castle-fire.ads (`Flames`, `Flame_Tall`, `Flame_Size`, `Bed_R`, `Wind_Lean`, `Sparks`, `Spark_Tall`,
  `Smokes`, `Smoke_Tall`, `Smoke_Size`, `Smoke_Drift`, `Light_Up`, `Light_Roam`). Looks in Castle.Props: `Flame_Bit` (five heats),
  `Smoke_Bit` (three shades, thin, not casting), `Ashes`. `Castle.Props.Flame` (the old tongue) is gone.
- **A thin look** (434d966): `New_Look (..., Thin => True)` is half seen through (alpha to coverage; every
  other pixel without MSAA). Smoke is the one user.
- **`Fire_By_Day`** (434d966): the fire's strength as the eye has it.
- `Castle.Figures.Max_Figures` 2,048 (a fire is about a hundred figures of one box each).
- Tools: `tools/shadow_still.sh` and `tools/frame_change.py` (do the shadows hold still), 
  `tools/demo_shadows_fire.sh`.

## Measured (RX 6900 XT, Mesa 26.2, 1280 x 720, 4x MSAA, seed 1)
`tools/shadow_still.sh`: a still view of the meadow at 1190 1085, clear, 9 in the morning, 200 frames a
thirtieth of a second apart, the last 60 compared one to the next. "Stepping": the share of pixels that
change by more than 6 levels of 255 between two frames running, at least once in the 60.

| The clock | Before (ddaeadd): mean step, stepping | After: mean step, stepping |
|---|---|---|
| a game minute a second (the default) | 0.30, 5.8 % | 0.017, none |
| three (`--timescale 0.05`) | 0.25, 5.1 % | 0.040, none |
| three, at 17:12 | 0.18, 2.1 % | 0.052, none |
| three, at 18:30 (dusk) | 0.50, 7.2 % | 0.092, none |
| eighteen (`--timescale 0.3`) | 0.18, 4.5 % | 0.065, none |
| stopped (`--timescale 0`) | 0.000, none | 0.000, none |
| no shadows (`--noshadows`) | 0.006, none | 0.006, none |

- The cause, measured before anything was built: with the clock stopped the old build's picture did not
  change at all; with the sun's direction rounded to whole degrees it changed only on the frame the
  direction stepped (0.32 on that frame, 0.01 between).
- The camp's still props close up (the crossbar, the pot, the stones), the clock at one and at three: the
  only pixels that change are the people walking in.
- GPU a frame at the default view of 160 m (1,257 stacks, 3.9 million quads): before, 1.14 ms with the
  clock running, of which the timer showed 0.25 (it started after the shadow pass); after, 0.34 ms by day,
  0.30 to 0.38 ms at night with the fire casting, 0.36 ms by day with the fire, 0.24 ms with `--noshadows`.
  At `--view 320`, 2.3 ms. While the view streams in both of the land's maps are drawn again on any frame a
  mesh arrives: 0.83 ms a frame on average over a 360 m glide at the screen's rate.
- The default view (the eye 70 m off, 1600 x 900): a person is 15 pixels tall and the figures' map has
  grown to the land's 9 cm a texel, about a limb's width. Twelve frames running of the band setting out,
  magnified: a soft shadow under each that moves with them; nothing pops.
- A camera gliding 14 m with the clock stopped, old build against new: the picture's second difference in
  time is 2.95 against 3.02, where two runs of the same build differ by more (3.55 and 3.38 with no
  shadows). No difference that this can show.

## Options
`--stoke HOURS`: the camp's fire burning from the start (with `--camp`). `--at` and `--cam` given with
`--load` now stand over the save's view. `--noshadows` switches off the fire's shadows too.

## Bugs found and fixed
- The sun's map was drawn again every frame the clock ran, on a grid that turned with the sun about the
  world's origin: at the reference stake the grid slid nearly three texels a frame. The flicker.
- `GPU_Millis` left the shadow and snow passes out.
- Shadows switched off with the sun 1 degree up and still at 58 % of its strength.
- `--cam` and `--at` were ignored with `--load`.
- The fire's bed glowed with the fire out.
- (Mine, in this work, in no build John has had: ground the fire only grazes was dimmed as if turned
  from it; the fire's dimming by day went by the sun's brightness, so in rain it was at full strength at
  noon.)

## Known limits
- A figure further from the focus than three times the eye's distance casts no shadow, and in sunshine has
  no disc either.
- At a step from one held direction to the next the shade is a mix of two maps: the far tip of a very long
  shadow (a tall tree's, the sun low) is for a moment two faint tips a little apart.
- The land's map is 9 cm a texel at the default view and coarser at a wider one (17 cm at `--view 320`).
- Flames and smoke go through the pot and through anything over the fire; a roof will not stop smoke.
- One fire. A second `Castle.Fire.Show` would draw, and give no light.
- The fire's light sits low (0.4 m), so every 25 cm step in the ground throws a long shadow away from it
  and on terraced ground whole sectors beyond a step down are in shadow (a quarter of the light). `Light_Up`
  raises it.
- Once an hour of play (`Flame_T` wraps) every piece of the fire is dealt a new place in one frame.
- Looked at in stills, contact sheets and recordings only: the meadow at twelve hours from dawn to dusk
  (the same as the old build but for softer edges), the band by day and at dusk, the fire close up by
  night and by day, snow under cloud, deer and a lineup, `--msaa 0`, `--noshadows`, `--view 320`, the clock
  at three game hours a second, the debug build. Not in play: the [ and ] keys, a quickload, a window
  resized while shadows are live were not exercised.

## Not done
- Shadows from the moon. More than one fire's light. Flames shaped by what burns.

## Next
- Stage 6, habitation. A hovel's hearth is the first second fire: the light then becomes a small table
  (`Set_Fire` takes one today), and the nearest fires cast.
