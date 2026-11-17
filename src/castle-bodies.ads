with Interfaces;
with Castle.Hash;  use Castle.Hash;
with Castle.Math;  use Castle.Math;

--  People, built the way the world is: boxes with 5 x 5 pixel textures per
--  0.25 m, so a body pixel is 5 cm, the world's texel.  Box sizes snap to
--  that pixel rather than to the block, which is what lets a serf be tall
--  or short, lean or stocky, a child or an elder, and still sit in the
--  world as if built from it.  A serf is about 35 pixels tall; the head is
--  6 (one block and a pixel: mildly stylised, so faces and hats read from
--  the top-down camera).
--
--  A Genome (seeded, about 40 bytes) and an Outfit (job, season) are all a
--  serf's look needs: Build turns them into a skeleton, a list of boxes on
--  its bones and a painted skin, the same every time.  Saves keep only the
--  genome, as the world keeps only its seed.
--
--  Symmetry: the left limbs are built and painted, and the right ones are
--  their mirror images.  Then it is broken on purpose: the tool goes in the
--  dominant hand (one in ten is left-handed), one sleeve may be rolled, a
--  scar sits on one cheek, a sword hangs on the off side.  (The tool itself,
--  a forester's axe or a hunter's bow, is no longer one of the body's boxes:
--  Castle.Serfs carries it, stowed or in the hand.)
package Castle.Bodies is

   Px : constant := 0.05;   --  metres to a body pixel

   --  Body frame: X to the right, Y forward, Z up.  Each bone's box hangs
   --  from its joint (Z down along the bone).
   type Bone is
     (Pelvis, Chest, Head,
      Upper_Arm_L, Forearm_L, Hand_L,
      Upper_Arm_R, Forearm_R, Hand_R,
      Thigh_L, Shin_L, Foot_L,
      Thigh_R, Shin_R, Foot_R);

   Parent : constant array (Bone) of Bone :=
     [Pelvis => Pelvis, Chest => Pelvis, Head => Chest,
      Upper_Arm_L => Chest, Forearm_L => Upper_Arm_L, Hand_L => Forearm_L,
      Upper_Arm_R => Chest, Forearm_R => Upper_Arm_R, Hand_R => Forearm_R,
      Thigh_L => Pelvis, Shin_L => Thigh_L, Foot_L => Shin_L,
      Thigh_R => Pelvis, Shin_R => Thigh_R, Foot_R => Shin_R];

   Mirror : constant array (Bone) of Bone :=
     [Upper_Arm_L => Upper_Arm_R, Forearm_L => Forearm_R, Hand_L => Hand_R,
      Upper_Arm_R => Upper_Arm_L, Forearm_R => Forearm_L, Hand_R => Hand_L,
      Thigh_L => Thigh_R, Shin_L => Shin_R, Foot_L => Foot_R,
      Thigh_R => Thigh_L, Shin_R => Shin_L, Foot_R => Foot_L,
      others => Pelvis];   --  the middle bones are their own mirror (see Is_Middle)

   function Is_Middle (B : Bone) return Boolean is (B in Pelvis | Chest | Head);

   type Sex_Kind is (Female, Male);
   type Hair_Kind is (Bald, Cropped, Short, Long, Bun, Braids);
   type Beard_Kind is (None, Stubble, Short_Beard, Full_Beard);
   type Side is (Left, Right);

   type RGB is record
      R, G, B : Float := 0.0;   --  0 .. 1, display values like the rest of the game's colours
   end record;

   type Genome is record
      Seed       : U64        := 0;
      Sex        : Sex_Kind   := Male;
      Age        : Float      := 30.0;    --  years
      Height     : Float      := 1.72;    --  metres, standing
      Build      : Float      := 0.0;     --  -1 lean .. 1 stocky
      Skin       : RGB;
      Hair       : RGB;
      Eyes       : RGB;
      Hair_Style : Hair_Kind  := Short;
      Beard      : Beard_Kind := None;
      Hand       : Side       := Right;   --  the dominant one
      Scar       : Boolean    := False;
      Scar_Side  : Side       := Left;
      Freckles   : Boolean    := False;
      Coif       : Boolean    := False;   --  a linen kerchief over the hair (women)
   end record;

   function Random_Genome (Seed : U64; Child : Boolean := False; Elder : Boolean := False) return Genome;
   --  A plausible person: sex, age (16-60, or 6-14 for a child, 60-75 for an
   --  elder), height by sex and age, build, colouring, hair and beard.

   type Job_Kind is (Idle, Forester, Hunter, Gatherer, Porter, Lord);

   type Outfit is record
      Job    : Job_Kind := Idle;
      Winter : Boolean  := False;   --  winter clothes (long sleeves, leg wraps, a hood), and its cloak over them
      Cloak_Off : Boolean := False; --  its cloak is not on its back (asleep, it lies under it)
   end record;
   --  Everyone has a cloak (John, 2026-11-12: "can we add cloaks, they can set
   --  down next to their bed during the summer, wear it during with their
   --  winter clothes in the winter, and use it as a blanket when they
   --  sleep?").  It is worn in winter; the rest of the year it lies folded by
   --  its owner's bed, and asleep its owner lies under it (whatever shows the
   --  band puts it there: Rig.Cloak is its colour, worn or not).

   --  A box is drawn with its edges and corners rounded off and, if asked,
   --  narrowing toward one end: the models are still made of boxes on the
   --  5 cm pixel, but they no longer read as blocks.  (John, 2026-11-11: "a
   --  slight drift away from the voxel block design ... a tiny bit of
   --  smoothing, slightly higher triangle count".)  Each face is nine cells
   --  (108 triangles a box, where it was 12); the skin is laid on as before.
   Auto_Round  : constant := -1.0;   --  Box.Round: by the rule below
   Round_Share : constant := 0.28;   --  the rule: this share of the box's thinnest side,
   Round_Max   : constant := 1.2;    --  and no more than this many body pixels (6 cm)

   --  A serf's shape (Build): shares of a box's width and depth.
   Limb_Taper  : constant := 0.16;   --  a forearm and a shin narrow by this to the wrist and the ankle;
                                     --  an upper arm and a thigh by half of it
   Waist_Taper : constant := 0.10;   --  the chest and the hips draw in to the waist
   Jaw_Taper   : constant := 0.10;   --  the head narrows to the jaw
   Skirt_Flare : constant := 0.14;   --  a dress widens to its hem (a man's tunic by half of it)
   Head_Round  : constant := 1.5;    --  the head's rounding, body pixels (of its 6)

   type Box is record
      On     : Bone    := Pelvis;
      Lo     : Vec3;               --  near corner (body pixels, the bone's frame)
      Size   : Vec3;               --  body pixels; whole but for 0.1 px insets
      W, D, H : Natural := 0;      --  its texels (Size rounded): the net is 2 (W + D) by D + H
      U, V   : Natural := 0;       --  where its net sits in the skin
      Cutout : Boolean := False;   --  has see-through texels (a hood's face opening)
      Glow   : Boolean := False;   --  its own light, drawn unlit (a flame, embers)
      Round  : Float   := Auto_Round;   --  the radius its edges are rounded by, body pixels (0: sharp)
      Taper  : Float   := 0.0;     --  how much narrower it is at its low end (Lo.Z) than at its high end,
                                   --  as a share of its width and depth; negative: narrower at the high end
   end record;

   function Rounding (B : Box) return Float;
   --  The radius box B is drawn with: its own, or by the rule; never more
   --  than 0.45 of its thinnest side.

   Max_Boxes : constant := 28;
   type Box_List is array (1 .. Max_Boxes) of Box;

   type Offsets is array (Bone) of Vec3;

   type Rig is record   --  a serf as built: skeleton and boxes
      Joint     : Offsets;        --  metres from the parent's joint, standing, body frame (the pelvis: from the ground)
      Boxes     : Box_List;       --  (a serf's first two are its hips and its chest)
      Count     : Natural := 0;
      Height    : Float   := 0.0; --  metres, soles to crown
      Hip       : Float   := 0.0; --  pelvis joint above the soles
      Ankle     : Float   := 0.0; --  ankle joint above the soles
      Hip_Half  : Float   := 0.0; --  each hip joint out from the middle
      Thigh, Shin, Upper_Arm, Forearm : Float := 0.0;   --  joint to joint
      Cloak     : RGB;            --  the colour of its cloak (worn or not)
   end record;

   Skin_W : constant := 128;
   Skin_H : constant := 64;
   type Skin_Pixels is array (0 .. Skin_H - 1, 0 .. Skin_W - 1) of Interfaces.Unsigned_32
     with Convention => C;
   --  (row, column), row 0 at the top; RGBA, red in the low byte; alpha 0 is see-through.

   type Face is (Pos_X, Neg_X, Pos_Y, Neg_Y, Pos_Z, Neg_Z);
   --  A box's net (W, D, H its texels):
   --    row 0 (D tall):    +Z at column D, -Z at column D + W (W wide each)
   --    row D (H tall):    +X at 0 (D wide), +Y (front) at D, -X at D + W, -Y at 2 D + W
   --  Along a side face the column runs to the viewer's right and the row
   --  down from the top; along the top and the bottom the column runs right
   --  as seen from the front, and the row from the back toward the front on
   --  the top, from the front toward the back underneath.  (Castle.Render's
   --  figure shader unfolds the same net.)

   procedure Face_Rect (B : Box; F : Face; U0, V0, Wf, Hf : out Natural);

   procedure Pack_Nets (B : in out Rig; Count : Natural; Fits : out Boolean);
   --  Places the nets of boxes 1 .. Count in the skin (their U, V): on
   --  shelves, tallest nets first.  Fits: False if they don't all fit.
   --  Shared by every look made of boxes (serfs, deer).

   procedure Build (G : Genome; O : Outfit; B : out Rig; Skin : out Skin_Pixels);
   --  Raises Program_Error if the boxes don't fit the skin (serf_check
   --  builds thousands to make sure they do).

   function Describe (G : Genome; O : Outfit) return String;
   --  "woman, 34, 1.62 m, gatherer": for logs and the interface.

end Castle.Bodies;
