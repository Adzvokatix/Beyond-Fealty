# Castle Game handoff (2026-11-08: the palette and the forests, between stages 3 and 4; Claude Code)

- Code: commits 28f6a96 (palette), 3ed81cb (forests and trees), 3deb888 (felling fix) in
  GAME_alpha_1_3/compiled. castle_game_stage3.zip is now behind the code (it stops at 876ae4c).
- All eight checks pass in debug. Still only the 6 known warnings.
- **Generator_Version is now 10. Saves from before this are refused** (the rule whenever generated output
  changes).

## Asked for (John, 2026-11-08)
- Use color_palette.txt for the world, before recolouring gets burdensome.
- Tree variations: bark (aspen's silver), foliage colour and style.
- Thicker forests, a bit more spread out, with an occasional tree dotting the open land: those are the
  fruit trees, since they need more sun.
- About half the berry bushes.

## Palette (Castle.Colors)
- Every colour of color_palette.txt is a named hex code (`Forest_Gold_Green : constant := 16#3D5C2E#`).
  The .txt is the source. The .jpg differs in places ("pine shadow" is drawn blue in it but is a dark
  green, #1A2E26, in the text).
- Materials name their colour in `Castle.Blocks.Base_Hex`:
  - ground: grass Forest Gold-Green, dirt Mudstone, clay Aged Leather, gravel Warm Gray, sandstone
    Copper Brown;
  - rock: granite Stone Gray, limestone Fog Gray, bedrock Ash Stone, boulders Mist Iron;
  - ores and coal: coal Charcoal, iron ore Warm Copper, bog iron Warm Umber, silver ore Silvered Steel,
    gold ore Aged Gold, placer gravel Gilded Amber;
  - bark: broadleaf and spruce Weathered Oak, aspen Silvered Steel, pine Aged Leather;
  - leaves: broadleaf Deep Hunter or Deep Forest, spruce and pine needles Pine Shadow, apple Emerald
    Lift, aspen Aspen Green (derived);
  - other plants: berry bushes Olive Dark, picked bushes Moss Shadow, grain Gilded Amber;
  - built: planks Copper Brown, shingles Dark Bark, footpaths Ashen Brown.
- Painted into the textures and the shader: apples Brightened Crimson, berries Heraldic Crimson, grain
  ears Brightened Gold; autumn turns Aged Gold, Warm Copper, Brightened Crimson or Warm Umber.
- Derived where nothing fits (the sums are in the comments):
  - Sand_Tan: Gilded Amber and Warm Gray, half and half.
  - Salt_Pale: Silvered Steel x 1.6.
  - Grass_Seed (tall grass): Forest Gold-Green 80 %, Gilded Amber 20 %.
  - Aspen_Green: Forest Gold-Green 75 %, Brightened Gold 25 %.
- Water is Storm Blue, not River Slate: River Slate read as a grey road from a distance.
- Not converted yet: serf clothing, deer coats, props and the UI still have their own RGB literals.

## Forests (Castle.Flora)
- Forest patches about 190 m across with sharper edges. A tree cell is 4 m (it was 5), so a forest
  stands up to a tree per cell.
- Open land has lone trees, about one per 900 m^2: apples in the lowlands, spruces up high. There are
  no apples in forests.
- Five kinds:
  - broadleaf: light or dark leaves, three habits;
  - aspen: silver scarred bark, a narrow column of pale leaves; aspens grow in groves and turn gold in
    autumn;
  - spruce: a dark cone;
  - pine: red-brown bark, a bare trunk and a flat crown on top;
  - apple.
- Each crown is also tinted slightly, tree by tree. New blocks: Aspen_Log, Pine_Log, Dark_Leaves,
  Aspen_Leaves (35 materials now; the shaders' material sets went to 64 bits).
- Seed 1, before and after (`./bin/flora_stats`):

  | | Before | After |
  |---|---|---|
  | Forest cover | 35 % | 41.5 % |
  | Trees per hectare in forest | 292 | 503 |
  | Trees per hectare in open land | 9.4 | 10.8 (two thirds apples) |
  | Apples inside forests | 2,904 | 2 |
  | Berry bushes | 49,710 | 25,021 (0.50) |
  | Trees within 60 m of the scripted stake (1178 1078) | 34 | 149 |
  | Bushes within 60 m of that stake | 85 | 84 |

- Cost: the mean stack takes no longer to generate, but the worst stack went from 2.3 to 8.8 ms;
  storage is 13 % higher.
- Felling fix: in a thick forest, a crown drawn on its own can send a branch through a neighbour's
  trunk. Felling now leaves that trunk whole (colony_check covers it).

## Looks to judge (palette taken literally)
- Pine crowns show slate grey under sky light (about 47,59,63 on screen). Swap: give pines a greener
  needle colour.
- Deep Hunter broadleaf reads teal against the yellow-green grass. Swap: Marsh Green or Olive Dark.

## Next: stage 4 (food and needs), per the production plan.
