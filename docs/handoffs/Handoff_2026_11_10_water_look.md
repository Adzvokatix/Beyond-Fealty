# Castle Game handoff (2026-11-10: the water's look, between stages 5c and 6; closed, accepted as built; Claude Code)

- **Closed 2026-11-10.** John, after trying the build: "looks spectacular". The first values stand, his to
  tune. `water-look` is merged into `main`; the zip is made from `main`.

- Code: GAME_alpha_1_3/compiled, branch `water-look` from `main` at 89b7de3 (the water stage, closed and
  merged that day), three code commits: 251ceed (deeper hues), f3657c2 (reflections) and 1c16adc (the hit
  test, the mirror's strength, the mirror in weather). Not merged.
  Zip: CASTLE_GAME/releases/castle_game_water_look.zip. Stills: releases/water_look_before_after.png
  (six views; the top two rows before, the bottom two after).
- Checks: all nine pass in debug at 1c16adc, the last code commit, with the six known warnings;
  `tools/reference_check.sh` passes; the debug game was run once. Nothing of the simulation, the generator
  or a save changed: no version moved (Generator_Version 12, save format 6, colony blob 13).

## What John sees on first launch
1. **All water looks different.** Deep water is dark blue and hides its bed; the shallows are as they
   were. The mountain lake no longer shows its floor 39 m down.
2. **Water mirrors the land**, the trees and the people as well as the sky, most at a low view.
   `--noreflect` switches that off (the sky is still mirrored).
3. From above the water has more sheen than before: the mirror is stronger than glass's would be, so that
   it shows from the usual view. `--noreflect` does not bring the old sheen back: the sky's reflection goes
   by the same strength.

## Rules agreed with John (2026-11-10)
His words on accepting the water: "it's clear we need deeper hues for deeper depths, and surface
reflections, then I think we are at a good place for the water." Built from that with first values of
mine; his to change.

## Built
- **Deeper hues** (251ceed). Each column of open water passes its depth to the shader. Colour: Storm Blue,
  to Royal Indigo over `Water_Hue_M` (2 m), to Abyss Blue (derived: Royal Indigo halved, in Castle.Colors)
  over `Water_Abyss_M` (12 m), before the light falls on it. Opacity by the water looked through (depth
  over the cosine of the view): `Water_Thin_Alpha` 0.62 (what all water had) to `Water_Deep_Alpha` 0.97
  over `Water_Clear_M` (2.5 m). Water laid as blocks in a tunnel counts as a metre deep.
- **Reflections** (f3657c2). The picture so far (land and people) is resolved into a colour and a depth
  texture before the marks, the sky and the water; each pixel of open water's top face walks its reflected
  ray out through those depths in thirty growing strides and takes the colour of what it meets, the sky's
  where it meets nothing. A hit counts only if the picture's depth is nearer than the ray's point by no
  more than the ray went deeper over that stride (a crown between the eye and the water is not mirrored for
  hiding the ray). The mirror fades with fog and with the weather's haze. `Water_Mirror` 0.12,
  `Water_Glance` 2.5 (3.5 and 2.5 were compared over the six views; 2.5 shows the land more at a low view
  and leaves the deep dark from above). `Castle.Render.Reflections`, `--noreflect`. The constants are at
  the top of castle-render.ads.
- Castle.Math has the camera's near and far planes (`Near_M`, `Far_M`); `glDeleteTextures` is bound.

## Measured (RX 6900 XT, 1280 x 720, the mountain lake filling two thirds of the view, 4x MSAA)
- GPU a frame: 0.65 ms with `--noreflect`, 0.92 ms with reflections (two runs each, within 0.03 ms).
- `--msaa 0`: runs, no reflection of the land (there is no target to read back), 0.36 ms.

## Options
`--noreflect`.

## Known limits
- A mountain taller than the view is cut off in the water: what is above the picture is not known, and the
  mirror fades to the sky's there. Past the picture's sides the ray carries on along the edge column.
- Water does not mirror other water (the copy is taken before any is drawn): a pool below a higher lake
  would show that lake's bed.
- Stepped water's risers and falls are not mirrors (top faces only); ice is not.
- Looked at in stills (six views before and after, a cut, the trench, a fall, winter, dawn, the sheet,
  `--msaa 0`, a storm, five people on a stream's bank, a window the compositor sized itself, the debug
  build) and in two recordings of 120 frames with the camera gliding (the lake at a low view, along the
  lowland stream: four frames in a row of each show the mirror holding still but for the ripples). Not in
  play. Tunnel water was run (the tunnel of water.md, no error) but is out of sight in that view.

## Not done
- No demo video; the stills stand in for it.

## Next
- Stage 6, habitation. Water is where John wants it ("then I think we are at a good place for the water").
