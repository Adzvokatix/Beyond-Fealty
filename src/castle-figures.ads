with Interfaces;
with Castle.Bodies; use Castle.Bodies;
with Castle.Bodies.Voxels;
with Castle.Poses;  use Castle.Poses;
with Castle.Math;   use Castle.Math;

--  What the renderer needs to draw people, gathered on the CPU.
--
--  A look is a serf's boxes and painted skin, made once (Castle.Bodies) and
--  kept in a slot: one layer of a texture array on the GPU.  Each frame the
--  game adds the figures it wants drawn, each a look and the world frames
--  of its bones (Castle.Poses), and a soft disc under each for where no
--  light casts its shadow.
--  Castle.Render takes all of it in one upload and draws every box of every
--  figure in one call, pulling the box corners in the vertex shader, which
--  also rounds each box's edges off and narrows it toward one end as the box
--  asks (Castle.Bodies.Box.Round, Taper).
--  Whatever is added here casts a shadow from the sun and from the fire
--  with nothing more to do (the renderer draws the same boxes into each
--  light's depth map), but for a box that glows (Castle.Bodies.Box.Glow: it
--  is a light) and a look made with Casts => False.
--  Main thread only.
package Castle.Figures is

   Max_Looks   : constant := 256;    --  skins resident at once (texture layers)
   Max_Figures : constant := 2_048;  --  drawn in a frame (a fire is about a hundred: Castle.Fire)
   Bones_Each  : constant := Bone'Pos (Bone'Last) + 1;
   Box_Vertices : constant := 324;   --  a box is drawn as six faces of nine cells, two triangles each

   subtype Look_Id is Positive range 1 .. Max_Looks;

   function New_Look (R : Rig; Skin : Skin_Pixels; Casts : Boolean := True; Thin : Boolean := False)
                      return Look_Id;
   --  Raises Program_Error when every slot is taken.  Casts => False: what
   --  is drawn with this look throws no shadow.  Thin: it is half seen
   --  through (smoke: both).
   procedure Free_Look (L : Look_Id);
   function Looks_Used return Natural;

   procedure Begin_Frame;
   procedure Add (L : Look_Id; F : Frames);
   procedure Add_Shadow (Ground : Vec3; Radius : Float);

   --  Voxel looks (the voxel people's brief, step 1: a serf's boxes filled with
   --  voxels of 2.5 cm, Castle.Bodies.Voxels).  A look keeps its drawn quads
   --  here, and on the GPU a slot of Vox_Slot_Words words: its palette, its
   --  part table and its voxels' bytes.  A voxel figure's bones go into
   --  Bones as a box figure's do, and its look's quads into this frame's
   --  Vox_List, each with its figure's first bone and its look; the
   --  renderer draws the list in one call (Castle.Render's voxel programs:
   --  each quad pulled by the vertex number, each face's colour read voxel by
   --  voxel from its part's bytes).  It casts as a box figure does.
   Max_Vox_Looks  : constant := 256;
   Vox_Quads_Each : constant := Castle.Bodies.Voxels.Max_Drawn;
   Vox_Bytes_Each : constant := Castle.Bodies.Voxels.Max_Bytes;
   subtype Vox_Look_Id is Positive range 1 .. Max_Vox_Looks;
   function New_Voxel_Look (V : Castle.Bodies.Voxels.Voxel_Look) return Vox_Look_Id;
   --  Raises Program_Error when every slot is taken.
   procedure Free_Voxel_Look (L : Vox_Look_Id);
   function Voxel_Looks_Used return Natural;
   procedure Add_Voxel (L : Vox_Look_Id; F : Frames);
   --  (left out, and said once, when this frame's list is full)

   ------------------------------------------------------- for the renderer

   subtype F32 is Interfaces.IEEE_Float_32;
   subtype U32 is Interfaces.Unsigned_32;

   type GPU_Bone is record                --  std430: three vec4s
      Xx, Xy, Xz, Ox : F32 := 0.0;        --  the bone's axes, each with one
      Yx, Yy, Yz, Oy : F32 := 0.0;        --  coordinate of its origin in w
      Zx, Zy, Zz, Oz : F32 := 0.0;
   end record with Convention => C;

   type GPU_Box is record                 --  std430: vec4, vec4, uvec4
      Lx, Ly, Lz, Round : F32 := 0.0;     --  near corner, body pixels in the bone's frame; the radius
                                          --  its edges are rounded by (Castle.Bodies.Rounding)
      Sx, Sy, Sz, Taper : F32 := 0.0;     --  size, body pixels; how much narrower at its low end
      Bone_Index : U32 := 0;              --  into this frame's bones
      Layer      : U32 := 0;              --  skin: texture array layer
      Net        : U32 := 0;              --  U | V << 16: the net's corner in the skin
      Dims       : U32 := 0;              --  W | D << 8 | H << 16 (texels) | cutout << 24 | glow << 25
                                          --  | no shadow << 26 | thin << 27
   end record with Convention => C;

   type GPU_Blob is record
      X, Y, Z, Radius : F32 := 0.0;
   end record with Convention => C;

   type Bone_Array is array (Natural range <>) of aliased GPU_Bone with Convention => C;
   type Box_Array is array (Natural range <>) of aliased GPU_Box with Convention => C;
   type Blob_Array is array (Natural range <>) of aliased GPU_Blob with Convention => C;

   Bones  : Bone_Array (0 .. Max_Figures * Bones_Each - 1);
   Boxes  : Box_Array (0 .. Max_Figures * Max_Boxes - 1);
   Blobs  : Blob_Array (0 .. Max_Figures - 1);
   Bone_Count, Box_Count, Blob_Count, Figure_Count : Natural := 0;

   type Skin_Access is access all Skin_Pixels;
   procedure Next_Upload (L : out Look_Id; Skin : out Skin_Access; Found : out Boolean);
   --  A skin made since the renderer last asked; it is now marked uploaded.

   --  The voxel quads of this frame (std430: uvec4 each): the quad's two
   --  words (Castle.Voxel_Mesh.Quad), its figure's first bone in Bones, and
   --  its look less one.
   type GPU_Vox_Quad is record
      A, B, Bone_First, Look : U32 := 0;
   end record with Convention => C;
   type Vox_Quad_Array is array (Natural range <>) of aliased GPU_Vox_Quad with Convention => C;
   Max_Vox_List : constant := 131_072;
   Vox_List : Vox_Quad_Array (0 .. Max_Vox_List - 1);
   Vox_List_Count : Natural := 0;

   --  A look's slot on the GPU, in 32-bit words: its palette (RGBA as the
   --  skin's, entry 0 air); its part table, per bone two uvec4s (the offset
   --  of its first voxel in the slot's bytes, Nx, Ny, Nz; Ox, Oy, Oz each
   --  plus Vox_Bias, 0); its voxels' bytes, four to a word, the first in
   --  the low byte (Castle.Bodies.Voxels.Voxel_Look.Bytes).
   Vox_Bias        : constant := 4_096;
   Vox_Pal_Words   : constant := 256;
   Vox_Parts_Words : constant := 8 * Bones_Each;
   Vox_Bytes_Words : constant := Vox_Bytes_Each / 4;
   Vox_Slot_Words  : constant := Vox_Pal_Words + Vox_Parts_Words + Vox_Bytes_Words;
   type U32_Array is array (Natural range <>) of aliased U32 with Convention => C;
   subtype Vox_Part_Table is U32_Array (0 .. Vox_Parts_Words - 1);
   type Bytes_Access is access all Castle.Bodies.Voxels.Byte_Array;
   type Parts_Access is access all Vox_Part_Table;
   type Pal_Access is access all Castle.Bodies.Voxels.Palette;
   type Vox_Upload is record
      Look    : Vox_Look_Id := 1;
      Pal     : Pal_Access;
      Parts   : Parts_Access;
      Bytes   : Bytes_Access;     --  (0 .. Bytes_N - 1)
      Bytes_N : Natural := 0;
   end record;
   procedure Next_Vox_Upload (U : out Vox_Upload; Found : out Boolean);
   --  A voxel look made since the renderer last asked; it is now marked uploaded.

end Castle.Figures;
