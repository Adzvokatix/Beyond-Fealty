with Interfaces;
with Castle.Bodies; use Castle.Bodies;
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

end Castle.Figures;
