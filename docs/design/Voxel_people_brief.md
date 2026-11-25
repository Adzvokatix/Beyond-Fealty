# Voxel people brief: serfs built as voxel parts, not boxes (phase A, before wearable props)

2026-11-23. **Proposed, not built.** Written in the design chat, not by a Claude Code session: what John
agreed is quoted under "His words"; everything else here is a first design and first values, his to
change. Put this file in `docs/production/briefs/` and open it on a new branch from wherever `main` is
when the work starts (`playtest-notes-2` is not merged as this is written). Nothing is merged without his
word, as ever.

- **Goal:** a serf's look is built by the generator as one small voxel volume per bone, coloured voxel by
  voxel and meshed into quads once per look, the form a voxel character editor (VoxEdit) gives: rigid
  parts on the skeleton, flat colour per voxel, a stepped silhouette that reads as rounded at the
  camera's distance. Nothing is imported: the two bought VoxEdit packs were opened only to see that form
  (see "What the reference packs showed").
- **Why now:** wearable props (hats, belts, packs, armour later) will be built on whatever a body is made
  of. Changing the body after they exist means making them twice.

## His words (2026-11-23)

> I don't want to import the models, I want to recreate the procedural generation in the same form

> but look what we do with the items, and tools like the axe and bow, they aren't exact blocks and sizes
> to the world

> yes, if we are going to do this, it needs to be done probably now, before we start creating wearable
> props, color resolution, the attention is on the NPCs so we can add twice the color detail. Triangle
> budget has a lot of overhead, doesn't mean we can go wild, but it doesn't mean we have to sacrifice a
> lot either, coarser mesh at a distance is fine, no reason not to optimize when we can.

So, agreed: **2.5 cm voxels** (half a body pixel); **a colour per voxel**, twice the world's texel detail
on people; **a coarser mesh at a distance**; done **before wearable props**. His point on the props
stands in the code: the axe's haft is 0.9 x 1.1 body pixels, the bow's string 0.3, a cloth panel 0.5
thick, a serf's lower segments 0.2 px thinner than the upper. What the world's rule holds people and
things to is the look of the texel, not the 5 cm geometry grid.

## What the reference packs showed

Opened 2026-11-23 (a CGTrader skeleton pack, royalty free; a free character on the same template). Only
the form is taken, no data:

- **16 rigid parts on a node tree, no skin weights.** Hip at the root; belly, chest, head up the spine;
  upper arm, forearm, hand; thigh, leg, foot. Ours is the same tree but for the belly (15 bones).
- **One colour per voxel.** The textures are palette strips (8 x 128) and per-part tiles of a few
  colours: nothing is painted at finer than a voxel.
- **One quad per exposed voxel face, nothing merged:** the skeleton is 1,268 quads (2,536 triangles,
  5,072 vertices), the dressed character 960 quads (1,920 triangles). About 60 voxels tall.
- **Clothes are voxels in the part they move with.** The dressed character keeps the skeleton's pivots
  and part lengths; its parts are only wider: the head +4 voxels across (hair), the forearm 2 -> 4
  (sleeve and cuff), the thigh 4 -> 8 by 3 -> 8 deep. **The skirt is split in two, half on each thigh,
  so it swings with its leg** and no leg passes through it; the price is a seam between the halves at a
  full stride.

## Where it stands now (read from the code at `playtest-notes-2`)

- `Castle.Bodies.Build`: genome + outfit -> 15 joints, 18 to 25 boxes (`Max_Boxes` 28), a 128 x 64
  skin. With `More_Form` (the default): 18 always (15 body boxes, the skirt, the neck, the nose), the
  hair's cap unless bald, +1 long hair or a bun, +2 braids, +1 the coif's knot, +1 a full beard, +2 in
  winter (cloak, hood), +1 a basket or a sack, +2 the lord's scabbard and guard.
- `Castle.Figures` / `Castle.Render`: every box of every figure in one `Draw_Arrays`, 324 vertices (108
  triangles) a box, the corners pulled from the box record in the vertex shader, rounded and tapered
  there. The same boxes are drawn into the figure depth map (`Figure_Size` 4096 over at least 48 m:
  about 1.2 cm a texel) and the sun's maps (`Draw_Casters`).
- **Cost, counted from `Build` and `Random_Genome`'s odds, not measured** (ages taken as even over
  16-60): about 19.6 boxes a serf in summer, so about 2,120 triangles and 6,350 vertices; 21.6 boxes in
  winter (about 2,330 triangles); 18 to 25 boxes, 1,944 to 2,700 triangles. Shadows draw it all again.
- **Other looks of boxes, not touched by this brief:** the deer (`Castle.Animals`), every prop
  (`Castle.Props`: `One_Box`, `Many_Boxes`, the axe, the bow, the quiver, the bed, the shelf, the
  basket), the fire's flames and smoke (`Castle.Fire`), cloth panels (`Castle.Cloth`). The box path
  stays as it is for all of them. The cloak is cloth since 2026-11-13; the rig's cloak box is what
  `--no-cloth` draws.

## The design

### 1. Units and frames

- `Vx : constant := 0.025;` metres to a voxel, **two to a body pixel**. A part's voxels lie in its
  bone's frame (X right, Y forward, Z up, hanging from the joint), as the boxes do now.
- **The skeleton does not move in the first build.** `Rig.Joint`, the bone lengths and everything
  `Castle.Poses`, `Castle.Serfs` and `serf_check`'s walking checks rely on stay on the body pixel. Joints
  on the voxel (finer heights and builds) are a later call of his (open call 3).

### 2. A part: a voxel grid per bone

- Built, meshed and thrown away inside `Build`; **only the mesh and the palette are kept** with the look.
  Bounds are worked out per bone from what is put in it; a hard limit of 64 voxels on a side (6 bits a
  coordinate in the quad, below) is far more than needed: the largest part is the head in a hood (8 px,
  16 voxels) or the chest with a basket on its back (about 10 px deep, 20 voxels).
- A voxel is one byte, an index into the look's palette; 0 is air.
- **Index the grids from 0** (`how_we_work.md`, 2026-11-22: this compiler misreads two-dimensional arrays
  with negative lower bounds). A part's own origin offset is a separate integer vector.

### 3. The generator's operations

A part is made by a short list of operations, in the kkrieger way (`docs/reference/kkrieger_notes.md`),
written as Ada procedures, not a graph:

| Operation | What it does | Used for |
|---|---|---|
| `Solid` | fill a box with its edges rounded by a radius and narrowed toward one end: the voxels whose centre lies inside the rounded, tapered box (a signed distance test) | every body part: exactly the box `Build` makes now, so the first build keeps every proportion |
| `Shell` | the voxels within N of a part's surface over a region (above a height, behind a plane) | hair cap, hood, sleeve and cuff, leg wraps |
| `Stamp` | a small solid at a point | nose, bun, beard, braid, buckle, basket, sack |
| `Carve` | set voxels to air in a region | the hood's face opening (no `Cutout` alpha any more), a mouth line if wanted |
| `Split` | put a solid's voxels into two bones' grids by a plane | the skirt (below) |
| `Mirror` | the left limb's grid, and its colours, mirrored onto the right | all paired bones, as now |

Then the symmetry is broken on purpose, as `Build` does now (dominant hand, a rolled sleeve, a scar).

- **Voxels are decided by integer centres and one distance function** with `-ffp-contract=off` as the
  build already has: the same genome gives the same voxels bit for bit on every machine.
- **The rounding carries over as steps.** The current `Rounding` radii (`Round_Share`, `Form_Limb_Round`,
  `Head_Round`) become how many voxels are shaved from each edge: at 2.5 cm a limb 3 px wide is 6 voxels
  across with its corners stepped, which is the VoxEdit silhouette.
- **The skirt is split onto the thighs** (the reference packs' answer): the part of the tunic or dress
  below the hip joint goes half into each thigh's grid, cut by the body's middle plane, so it swings with
  the leg. What stays on the pelvis is the belt-to-hip band. A switch keeps it on the pelvis
  (`--no-skirt-split`) to compare. (John's call whether the seam at a full stride is acceptable: open
  call 4.)
- **Joints keep their overlap:** a lower part reaches a body pixel (2 voxels) up into the one above, as
  now, so bending opens no gap. Faces between parts are not culled: the depth test hides the overlap.

### 4. Colour: a palette per look

- Each surface voxel gets a colour by the same rules `Build` paints with now (tunic, hose, jerkin,
  apron, trim, skin, hair, eyes, brows, scar, freckles, the grain by `Hash_3`), at 2.5 cm instead of
  5 cm: **twice the detail on people**, by his word. What it buys first, as first values: eyes and
  brows a voxel each, a mouth, a nostril line, a belt with a buckle, a hem, stitching on the jerkin,
  fingers suggested on a hand.
- The colours are gathered into **a palette of at most 255 entries a look**; voxels hold the index. The
  look's palette is one row of a 256 x `Max_Looks` texture (or an SSBO): **the 128 x 64 skin layers and
  `Pack_Nets` are not needed for voxel looks** (they stay for the box looks).
- Grain (the small per-texel variation the skin has now) becomes per-voxel palette entries: a few shades
  of a cloth, chosen by `Hash_3` of the voxel. That uses palette slots; if a look runs out, the shades
  merge to the nearest and `serf_check` counts how often.

### 5. Meshing: greedy, once a look

- A new small package (`Castle.Voxel_Mesh`, say) rather than `Castle.Mesher`, which is tied to stacks,
  chunks, water and the world's occlusion; the greedy merge is the same idea (`castle-mesher.adb`, "merge
  equal faces into rectangles").
- Per part: a face is emitted where a voxel's neighbour **within the same part** is air; faces merge
  into rectangles across voxels of **the same palette index and facing**. Clothes are mostly flat colour,
  so they merge well; faces and grained cloth merge less.
- **A quad is two 32-bit words**, decoded in the vertex shader as the world's are: x, y, z (6 bits each),
  w-1, h-1 (6 bits each), face (3 bits), palette index (8 bits), bone (4 bits), with bits to spare.
- **Normals are flat per face** (the VoxEdit look; the box path's rounded normals are what "shows at a
  distance" now). Open call 1.

### 6. The coarse mesh

- **The same grid reduced 2 x 2 x 2 to 5 cm** (a coarse voxel is solid if most of its eight are; its
  colour is the commonest of them), meshed again. Kept with the look beside the fine mesh.
- **Which one is drawn** is chosen per figure by its distance from the eye: fine within a first value of
  25 m, coarse beyond (open call 2). One threshold, no blending at first; if the switch pops, a few
  metres of dithered crossover in the fragment shader is the cheap fix.
- **Shadows:** the figure depth map is about 1.2 cm a texel at its tightest and resolves the fine mesh,
  so figures inside it cast with the mesh they are drawn with. The sun's own maps are far coarser:
  figures cast into them with the coarse mesh always.

### 7. Drawing

- One quad buffer holds every resident look's two meshes end to end (`Max_Looks` 256). A look records
  where its fine and coarse quads start and how many there are.
- Per frame, `Castle.Figures` adds a figure as now (its bones), plus which look and which mesh. The
  renderer draws **every voxel figure in one `Multi_Draw_Arrays_Indirect`**, one command per figure
  (6 vertices a quad; the command's base instance is the figure, which gives its bones and its look's
  palette row). The land already draws this way.
- **Box looks keep their own draw**, untouched. So `Figures` holds two kinds of look; voxel looks are
  made by a new `New_Voxel_Look`.
- Thin (half seen through) and glow stay box-only for now: nothing voxel needs them.

### 8. The switch

`--no-voxel` (and a `Castle.Bodies.Voxel_People : Boolean := True`): serfs built and drawn as boxes,
exactly as at the commit before this work, by the house rule that every new rule can be turned off.
`--no-form` keeps its meaning under both.

## Steps

Each step its own commit (or few), gated, shown to John with stills side by side (`--no-voxel` against
the new build, the same seed, stake and frame).

1. **Parity.** Voxelize the boxes `Build` makes now (`Solid` with each box's own rounding and taper),
   colour each surface voxel from the skin as it is painted now (the voxel's face and position on its
   box mapped to the box's net: `Face_Rect`), mesh, draw, cast. Nothing new in shape or colour: what
   changes is only the form. This proves the whole path and gives the triangle count to measure.
2. **Shapes in the voxel's own way.** The skirt split onto the thighs; hair, hood and sleeves as shells;
   the hood's face carved; the stepped rounding tuned by eye.
3. **Colour at 2.5 cm.** Painting moves from the skin to the voxels, with the detail listed in 4.
4. **The coarse mesh** and the distance switch, with shadows as in 6.
5. **Cost measured:** `tools/look_cost.sh`, this build against `--no-voxel`, the two back to back from a
   scratch worktree (`CLAUDE.md`: figures an hour apart differ more than most looks cost); and a crowd:
   the stress runner's crowd drawn, if a view of it can be fixed.

## Budget (estimates: a debt, to be measured in step 1)

| | Now (boxes, counted) | Voxel, fine (estimated) | Voxel, coarse (estimated) |
|---|---|---|---|
| Triangles, average serf | ~2,120 | 2,000 - 2,600 unmerged; less merged | ~650 - 870 unmerged; less merged |
| Vertices drawn | ~6,350 | 6 a quad | 6 a quad |

The estimates scale the reference packs' unmerged quad counts by surface area (about 70 voxels tall
against their 60; 35 against 60 for the coarse). **Target, first value: the fine mesh of an average serf
at or under today's ~2,120 triangles after merging, and the coarse mesh under a third of it.** If the
fine mesh comes out over, the first thing to look at is grain shades breaking merges, not the voxel size.

## Checks

`serf_check` gains (each must be shown to fail with its guarded line taken out, `how_we_work.md`):

- The same genome builds the same voxels, palette and both meshes, bit for bit.
- Every left part's voxels and colours are the mirror of its right part's, but for the asymmetries
  `Build` makes on purpose (the check that does this for skins now, done for voxels).
- No part outside its 64-voxel limit, no palette past 255; how often shades were merged for room.
- **Triangle counts over the thousands of genomes it builds:** mean and most, fine and coarse, by sex,
  child or adult, summer and winter, and by job. Printed every run; it fails if the fine mean passes
  2,600 or the coarse mean 900 (first values).
- Step 1: every voxel of a part lies within half a voxel of its box's surface or inside it, and every
  point of the box's surface within half a voxel of a voxel: the parity is proved, not looked at.
- Children and elders, every hair style, coif and beard, winter, every job: built, meshed, in bounds.

No save changes: a look is still made from its genome (the colony blob is not touched). The reference
logs and `today_check` hold, since nothing the colony does changes; if any moves, it is a fault.

## Open calls for John

1. **Flat normals per face (the VoxEdit look), or smoothed** (normals averaged over a voxel's
   neighbours, which reads softer in the light)? First build: flat.
2. **The distance for the coarse mesh:** 25 m to start, set by eye from his usual camera.
3. **Joints on the voxel instead of the body pixel** (heights and builds in 2.5 cm steps): later, after
   step 3, if the parity proves out; it moves the walking checks.
4. **The skirt split onto the thighs:** the seam between its halves at a full stride, acceptable at his
   camera, or the skirt kept on the pelvis?
5. **Deer and props in voxels** after people (wearable props are made in voxels from the start, so a
   hat is a part on the head's bone): a brief of its own when he opens it.

## Not in this brief

The deer, the props, the fire, cloth; animation (unchanged: `Castle.Poses`); the colony, saves, the
blob; anything wearable (it comes after, on this form).
