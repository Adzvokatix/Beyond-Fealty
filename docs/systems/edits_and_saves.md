# Editing and saves

- Packages: Castle.Edits, World_Blocks, Saves
- Check: edit_check
- Saves: the game save, format 6
- Stage: phase A

## Editing and saves

The world is always the generator's output with the player's edits written
over it; the generated world is never stored.  Editing is a developer tool
for now (dig, place); later the colony gives the orders and the same calls
carry them out.

* **Edit store** (`Castle.Edits`).  One ordered map of single-block edits
  and one of whole-brick edits (a 1 m brick in one entry: the 1 m and 2 m
  brushes cost 64 times less).  Keys put the stack in the high bits, so a
  stack's edits come out as one sorted run and a save has a fixed order.
  Bricks apply first, then blocks; a new brick edit drops the older block
  edits inside it.  The main thread writes; workers read a stack's edits
  under a lock when they rebuild it.
* **Rebuilds.**  Every edit advances its stack's generation, and its
  neighbours' when it lies on their shared edge (their faces and corner
  shading look across it).  The edited stacks are queued ahead of all
  streaming; a worker regenerates the stack, applies the edits and meshes
  it, about 4-6 ms.  A result older than the stack's latest edit is shown
  and rebuilt once more.
* **Laid-open ground** (`Castle.Chunks.Deepen`).  Below the 2 m skin nothing
  is generated.  An edit pulls the skin down to one block below itself in
  its brick column and the eight round it, and that band is generated the
  way the skin is, block by block: a pit's walls show the real strata, the
  water table and any vein it cuts.
* **Lookups** (`Castle.World_Blocks`).  Each loaded stack keeps the packed
  copy of its blocks from its last build (about 34 KB); stacks edited since
  then also consult the edit store.  `Block_At` answers what is where;
  `Cast` walks a ray block by block for picking.  Ground not yet laid open
  reads as `Deep` (solid).
* **Saves** (`Castle.Saves`).  Written to `PATH.tmp` and renamed over the old
  save, so a crash mid-save can't break it.  Loading refuses a damaged or
  cut-off file, a save from another world (start it with `--load`), and one
  made by another `Generator_Version` (its edits would land on a different
  world).  Little-endian layout: `CASTLSV1`, u32 format (6), u32 generator
  version, u64 seed, f64 clock (game hours), f64 climate time, 3 x f32 snow
  depth, f32 ice, f32 wet, 5 x f32 camera (x, y, yaw, tilt, distance), u64
  edit count, then per edit u64 key, u8 material, u8 state, u8 kind (1 =
  brick); then (format 2) u32 count of water stacks, each u16 cx, u16 cy,
  u8 awake and, for its 32 x 32 columns, u8 stretches (plus 128 where the
  water is source water, format 3; plus 64 where the column has been dug
  or built in, format 6), then for source water u32 the level it rests at
  (depth units from the bottom of the world, format 6), and per stretch
  u16 floor, u16 ceiling, u32 depth;
  then (format 4) u32 count of lake levels, always 0 now (lakes are locked
  sources); then (format 5) u32 length of the colony's blob and the blob
  (0: no colony; see colony.md); and last a u64 FNV-1a of everything before
  it. Format 1 to 5 saves still load.  11 bytes an edit:
  the 18 x 22 x 68 m notch above is 26,928 edits, 296 KB.

`./bin/edit_check` tests all of this without a window (24 checks).

## What the block store remembers of its edits (2026-11-11)

`Castle.World_Blocks` keeps, for each stack edited since it was last
kept, which of its columns were edited (a bit a column) and the last 48
of them with the ground version each gave the stack. Two things use it.
`Block_At` asks the edit store only about a column that was edited: it
used to ask about every block of a stack with an edit anywhere in it (or
in a column beside its edge), a protected call each, which was a fifth
to a quarter of the colony's time. And `Changes_Since (stack, version)`
tells a cache what changed since it looked, so `Castle.Nav` mends one
cell instead of reading 256 (`routes.md`). A stack edited while it was
being rebuilt, and every stack after a load, is taken as edited
everywhere, as before. Nothing of this is saved.
