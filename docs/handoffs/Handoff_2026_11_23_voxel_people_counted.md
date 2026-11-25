# Handoff, 2026-11-23 (evening): voxel people, step 1 counted before anything is drawn

Branch `voxel-people`, made from `main` after the stockpile's merge. **In hand: not gated as a piece,
not merged, nothing of it is drawn.** His brief is `docs/design/Voxel_people_brief.md` (his file,
committed as he put it there); this is what a session did on it and what it measured.

## His words (2026-11-23, afternoon)

> /home/bythergig/CASTLE_GAME/GAME_alpha_1_3/compiled/docs/design/Voxel_people_brief.md, I have added
> this and there are model refrences I purchased in the docs/refrences, that is the general shape I
> want to make our serfs, if you need me to install packages so you can see them let me know, if you
> have any questions let me know. then merge

Read as: the piece his brief describes is opened, on a branch of its own, step by step as the brief
has it ("Each step its own commit ..., gated, shown to John with stills side by side"; "Nothing is
merged without his word, as ever"). "then merge" was read of the stockpile's branch, which was merged;
**not** of serfs he has not seen. **Only one of his files was opened: `Character_17_vox.vox`**, the
dressed character (his brief calls it the free one on the bought skeleton's template). It needed no
package: a `.vox` file is read by forty lines of Python, and Python with numpy and Pillow is on the
machine. The skeleton pack (an `.obj` and its textures; it holds no `.vox`), the `.fbx` and the
`.gltf` were not opened.

**The bought packs and the invoice are not in git** (`docs/reference/`: `Character_17_*`,
`Skeleton_*`, `Wednesday_17_glt.*`, `invoice_cgt_*.pdf`; untracked, left where he put them). The
public repository is to hold neither bought models nor an invoice; his to say if they are to be
kept out for good by a line in `.gitignore`. His copy of the brief in `docs/reference/` is likewise
left; the one in `docs/design/` is the one committed.

## What is built: the brief's step 1, as far as the count

Step 1 is "Parity. Voxelize the boxes `Build` makes now ..., colour each surface voxel from the skin
as it is painted now ..., mesh, draw, cast. Nothing new in shape or colour ... This proves the whole
path and gives the triangle count to measure." Built: **voxelize, colour, mesh, count, check**. Not
built: draw, cast.

- `Castle.Voxel_Mesh` (new): a part is a grid of bytes indexed from 0 with its own offset; `Mesh`
  merges a part's open faces into rectangles of one palette index and one facing; a quad is the
  brief's two words. `Quads_Of` and `Halve` count what else a part could be meshed as.
- `Castle.Bodies.Voxels` (new): each box of a rig filled with 2.5 cm voxels, the voxels whose centre
  lies inside the box as the figure shader draws it (its rounding and its taper: the shader's own
  shape, turned into a distance); one grid a bone; a voxel in several boxes of its bone is the one
  it lies shallowest in; its colour the skin's texel at the nearest point of that box's nearest
  face; a see-through texel (the hood's face opening) leaves the voxel to whatever is under it; a
  palette a look.
- `serf_check`, "voxel parts", over 600 genomes, every job, summer and winter (7,200 looks): the
  same rig and skin give the same quads and palette; a voxel is solid where its centre lies inside
  a box of its bone and nowhere else (the parity, counted: 0 and 0); left and right parts are the
  same shape mirrored; no palette past 255. `serf_check --voxels FILE [N [JOB [winter]]]` writes one
  serf's voxels for a picture.
- Nothing else of the game is touched: the reference logs and the game as it is played cannot
  move, and the nine checks are as they were but for these lines.

## What the count says (the brief's budget was "estimates: a debt, to be measured in step 1")

| triangles a serf, mean (the most) | |
|---|---|
| as boxes, today | 2,285 (2,700) |
| **voxel parts, merged by colour as the brief has it** | **6,922 (8,730)** |
| women; men; children | 7,181; 7,000; 5,388 |
| summer; winter | 6,457; 7,388 |
| the same voxels, **merged whatever the colour** (counted over 1,440 looks) | **1,648** |
| not merged at all: a quad an open side | 15,687 |
| at half the fineness (5 cm), merged by colour; whatever the colour | 3,154; 735 |

A look is 11,332 voxels, 5,215 of them with a side open.

- **The brief's first limit is missed three times over**: "it fails if the fine mean passes 2,600";
  it is 6,922. Its target was "at or under today's ~2,120 after merging" (today is 2,285 by this
  count, which builds every job and season for every genome).
- **Why, as the brief foresaw**: "the first thing to look at is grain shades breaking merges". The
  skin is painted with a shade a texel, so neighbouring voxels seldom share a palette index and few
  faces merge. The same grain is why **1,022 of the 7,200 looks have more colours than a palette of
  255 holds** (colours merged to the nearest for room: the brief's second first value, missed).
- **Merged whatever the colour, the same voxels are 1,648 triangles**, under today's boxes, and 735
  at the coarse fineness, under a third of today's: both of the brief's targets. That needs a face's
  colour looked up where it is drawn (each part's voxel colours in a small texture of its look,
  found from where on the quad the pixel lies), not carried by the quad. A colour a voxel, the
  grain, and "twice the colour detail" all stay. **That way is not built and not costed**: 1,648 is
  a count of quads, and what the look-up costs a pixel is not known until a shader does it.

`serf_check` prints the two missed first values as `MISS` and does not fail on them: the figures
are his to rule on, not mine to tune.

## The picture

`~/CASTLE_GAME/releases/voxel_people_2026_11_23/our_serfs_as_voxel_parts_and_the_reference.png`:
three of our serfs as the voxel parts built here (a woman of 1.50 m, a woman of 1.57 m, a gatherer
in winter with his hood and basket), front and side, and the character of `Character_17_vox.vox`
beside them at the same height on the page. It shows a model from his files: for his eyes, not for
posting. Drawn by a script outside the game from `serf_check --voxels`: it is the
voxels, not a frame of the game.

**Ours are the boxes' own proportions** (step 1 changes nothing in shape): a head about a fifth of
the height (12 or 13 voxels of 61 to 69), shoulders as wide as the hem. **That character is a third
head** (20 voxels of 60, 16 wide), a narrow trunk, limbs 3 or 4 voxels thick.

## His calls

1. **"The general shape": the form, or the reference's proportions too?** The brief takes the form
   only ("Nothing is imported ... opened only to see that form"; "the first build keeps every
   proportion"), and that is what is built. The reference itself is a head a third of its height on
   a slight body. If he wants ours moved toward that, it is a change to `Build`'s skeleton and
   boxes (the brief's open call 3 touches it), and the walking checks move with it. Default: the
   brief's, our proportions.
2. **The mesh: colour carried by the quad (the brief), or looked up?** By the quad: 6,922 triangles
   a serf, three times today's, and a palette too small for one look in seven. Looked up: 1,648,
   and no palette limit; what the look-up costs in the shader is not measured. A third way keeps the
   brief's mesh and takes the grain out of the skin (flat colours merge well): not counted, and it
   changes the look. Default, and what I would build next: looked up.
3. **Flat normals, the coarse mesh's distance, the skirt on the thighs**: the brief's own open
   calls 1, 2 and 4, unchanged; none is reached yet.

## Not done, and next

- Draw and cast (the rest of step 1): a second kind of look in `Castle.Figures`, the quads in one
  buffer, a vertex shader that decodes them, every pass that draws figure boxes given the voxel
  figures too (the view, the figures' depth map, the sun's maps, the fire's six faces). Waits on
  call 2, since it decides what a quad carries.
- Proved by breaking what it guards: the parity (a voxel taken where its centre lies 0.3 of a body pixel outside its box: 1,124,928 strays; one voxel of a hand left out: 480 inside a box and air) and the mirror (that hand: 200 unlike). Not proved: the sameness of two builds, which has no state to break.
- Steps 2 to 5 of the brief.

A session starts at `docs/production/State.md`.
