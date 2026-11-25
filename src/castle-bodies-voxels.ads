with Castle.Voxel_Mesh;

--  A serf's look as voxel parts (docs/design/Voxel_people_brief.md; John,
--  2026-11-23: "I don't want to import the models, I want to recreate the
--  procedural generation in the same form").
--
--  **Step 1 of the brief, the parity**: nothing new in shape or colour.
--  Each box Castle.Bodies.Build makes is filled with voxels of 2.5 cm
--  (Castle.Voxel_Mesh.Vx): the voxels whose centre lies inside the box as
--  the figure shader draws it, its edges rounded by Rounding and narrowed
--  by its Taper.  One grid a bone, in the bone's frame.  A voxel that lies
--  in several boxes of its bone is the one it lies shallowest in (the
--  tunic's skirt over the hips, the hair's cap over the head; the later box
--  on a tie).  Its colour is the skin's texel at the nearest point of that
--  box's nearest face (Face_Rect); where that texel is see-through (a
--  hood's face opening) the voxel is not that box's.  The colours of a
--  look are gathered into a palette of 255 at the most; past that a colour
--  goes to the nearest there is, and how often is counted.  Each part is
--  meshed (Castle.Voxel_Mesh.Mesh).  The same rig and skin give the same
--  voxels, palette and quads: integer voxel centres, one distance
--  function, no state.
--
--  **Drawn** (2026-11-23, evening: step 1's draw).  Drawn holds each
--  part's open faces merged into rectangles whatever their colour, and
--  Bytes each part's voxels' palette indices, x fastest, then y, then z,
--  from its own Offset (Parts); Castle.Figures keeps them and Castle.Render
--  draws them, the colour read voxel by voxel where a face is drawn.  This
--  departs from the brief, whose quads carry their colour (Quads, N: the
--  brief's mesh, counted, not drawn): merged by colour a look is five times
--  the triangles the brief allows, since the skin's grain is a shade a
--  texel (John was asked on 2026-11-23 and gave no word; how it is built,
--  the picture the same either way).
package Castle.Bodies.Voxels is

   package VM renames Castle.Voxel_Mesh;

   --  Serfs are drawn as voxel parts (the game's --no-voxel: as boxes, as they were).
   Voxel_People : Boolean := True;

   Max_Quads : constant := 12_000;
   Max_Drawn : constant := 4_096;          --  the drawn quads of a look, at the most (2,048 until the oval
                                           --  hair of 2026-11-24, whose most look is 1,038)
   Max_Bytes : constant := 65_536;         --  the voxels of a look's parts, at the most

   type Byte_Array is array (Natural range <>) of Interfaces.Unsigned_8;
   type Part_Place is record
      Offset     : Natural := 0;           --  into Bytes
      Ox, Oy, Oz : Integer := 0;           --  its grid's corner, voxels of its bone's frame
      Nx, Ny, Nz : Natural := 0;           --  its grid's size (0: the bone has no part)
   end record;
   type Part_Places is array (Bone) of Part_Place;

   type Int3 is record
      X, Y, Z : Integer := 0;
   end record;
   type Origins is array (Bone) of Int3;
   type Bone_Counts is array (Bone) of Natural;
   type Palette is array (0 .. 255) of Interfaces.Unsigned_32;      --  RGBA as the skin's; entry 0 is air

   type Voxel_Look is record
      Quads    : VM.Quad_Array (1 .. Max_Quads);
      N        : Natural := 0;              --  quads in all (two triangles each)
      Per_Bone : Bone_Counts := [others => 0];
      Origin   : Origins;                   --  each part's grid corner, voxels of its bone's frame
      Size     : Origins;                   --  each part's extent, voxels
      Pal      : Palette := [others => 0];
      Colours  : Natural := 0;              --  palette entries used
      Merged   : Natural := 0;              --  voxels whose colour went to the nearest for want of room
      Solid    : Natural := 0;              --  voxels in all
      Surface  : Natural := 0;              --  of them, with a side open
      Empty    : Natural := 0;              --  boxes that took no voxel (thinner than one)
      Drawn    : VM.Quad_Array (1 .. Max_Drawn);   --  merged whatever the colour: what is drawn
      Drawn_N  : Natural := 0;
      Bytes    : Byte_Array (0 .. Max_Bytes - 1);
      Bytes_N  : Natural := 0;
      Parts    : Part_Places;
   end record;
   type Look_Access is access Voxel_Look;

   procedure Build (R : Rig; Skin : Skin_Pixels; L : out Voxel_Look; Brief_Mesh : Boolean := True);
   --  Raises Constraint_Error if a part is more than Voxel_Mesh.Side voxels
   --  a side or the quads or the voxels do not fit.  Brief_Mesh False: the
   --  quads merged by colour (Quads, N, Per_Bone) are not made (the game,
   --  which draws Drawn).

   --  For the checks and for pictures: bone B's part as the last Build left
   --  it (the grids are kept by this package and written again by the next).
   function Part_Of (B : Bone) return VM.Part;

   --  How far the point P (body pixels, its bone's frame) lies outside box
   --  K as it is drawn: negative inside.
   function Outside (K : Box; P : Vec3) return Float;

end Castle.Bodies.Voxels;
