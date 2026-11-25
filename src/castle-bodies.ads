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

   --  More form (John, 2026-11-22: "I had someone play the game and they
   --  suggest that the serfs need a little bit higher detail, a bit more
   --  "form"").  Still boxes on the 5 cm pixel with a painted skin.  With
   --  More_Form a serf has: a neck (Neck_Px of its trunk's height: the head
   --  is where it was, the shoulders and all that hangs from them a pixel
   --  lower); a nose; its hair as a cap over the crown, the back and the
   --  sides of its head, a quarter of a pixel proud of it (a kerchief
   --  likewise); limbs rounded further, all but round, and narrowing more
   --  to the wrist and the ankle, the trunk a little more to the waist, the
   --  head to the jaw.  Three boxes more a serf (two if it is bald), 25 at
   --  the most of Max_Boxes.  First values.  (Tried and left out, as they
   --  looked: a shoulder round the top of each arm, which read as puffed
   --  sleeves; a belt proud of the tunic, a square platter round the waist
   --  of anyone bending; the hair as a cap over the whole crown, a flat
   --  hat.)  False (the game's --no-form): the serfs as they were, to the
   --  box.
   More_Form        : Boolean := True;

   --  **The reference body** (John, 2026-11-23, of the voxel characters he
   --  bought and the voxel people's brief: "the skeleton model is the
   --  refrence bone structure, there are some examples when they are
   --  "fleshed" out, a small button nose is fine, but the nose you have is
   --  too long").  The bought skeleton, read from its own files (its parts
   --  in voxels of its own, 61 to its height): a head 20 tall, 12 wide and
   --  14 deep sitting on the chest, a third of the height; the thighs'
   --  joints 24.5 over the soles (40 %); the chest 11 tall and 14 wide; the
   --  shoulders' joints 40 over the soles; an upper arm of 11, a forearm of
   --  8 and a hand of 4, so that the hands, hanging, end 17 over the soles
   --  (28 %: the middle of the thigh); limbs 3 or 4 thick fleshed out (the
   --  legionary and the knight he sent with it).  Here, on the body pixel
   --  still (the joints too, the brief's first build): the head Ref_Head_Px
   --  tall at Ref_Height_Px and as the square root of the height else (a
   --  tall man's head is not so much bigger), never under Ref_Head_Least,
   --  Ref_Head_W wide and Ref_Head_D deep: a bit smaller than the skeleton's
   --  (John, 2026-11-24, with a chart of a face's proportions: "I mean it's
   --  close, just cut the head down a bit, make it a bit smaller"; it was the
   --  skeleton's, 10 tall there, 6 wide and 7 deep), so that nearly every
   --  adult's head is 9 pixels tall and the face is in thirds as on his
   --  chart, three rows from the brows to the nose's foot and three from
   --  there to the chin, the eyes on the head's middle row; the brows above
   --  them and the hair over the rows above those, the nose under the eyes,
   --  a row of cheek, the mouth, the chin to the head's last row (the face
   --  itself as it was: what goes is a row of the chin or of the crown, or
   --  one of each); the hips' joint at Ref_Leg_Share of the
   --  height under the head (the legs and the trunk take what the head
   --  gives up); no
   --  neck (the head sits on the chest); the chest a pixel deeper; the
   --  shoulders' joints a pixel under the chest's top; the arms as long as
   --  leaves the hands' ends, hanging, at Ref_Hand_Share of the height, the
   --  upper arm Ref_Upper_Of_Arm of the arm above the wrist (the skeleton's
   --  11 of 19); the nose a button, a pixel square and half a pixel proud (a
   --  voxel of the brief); the hair a voxel proud of the head, over the crown
   --  and the forehead to the brows all round, and down the back and the
   --  sides as far as the style is painted there.  The rest of the body as
   --  it was with More_Form, the limbs three pixels thick (a child's two),
   --  rounded and narrowing to the wrist and the ankle, the hands and the
   --  feet as they were; and, so that it shows in voxels of half a pixel, the
   --  waist drawn in by Ref_Waist_Taper and the forearm narrowing by
   --  Ref_Fore_Taper to a wrist narrower than the hand (John, 2026-11-23, of
   --  a first try with straight limbs two pixels thick and the waist
   --  straight: "where are the hands? the slim waists? the shaped arms and
   --  legs?").  First values.
   --  False (the game's --no-reference-body): the serfs as they were before
   --  it, to the box (More_Form and --no-form as they were).
   Reference_Body   : Boolean := True;
   --  On the reference body, the head's shape after the eight voxel characters John sent
   --  (2026-11-24, "I have provided some refrences for the head shape"), and oval (the same morning,
   --  of the first try's tufted masses: "can we make the heads more oval shapped? so the hair doesn't
   --  look like blocks or afros?"): the hair a voxel proud of the head at the temples, narrowing over
   --  the crown by Crown_Taper and down the sides by Side_Taper, as the jaw narrows to the chin; ears
   --  where the hair leaves the sides bare; a full beard round the jaw (Build says how).  False (the
   --  game's --no-head-shape): the head as it was before them.
   Head_Shape       : Boolean := True;
   Crown_Taper      : constant := 0.35;   --  the hair over the crown narrows by this to its top (0.25 until "the top
                                          --  of the head let's round it a bit more", 2026-11-24)
   Side_Taper       : constant := 0.15;   --  and down the sides by this to its foot
   Ref_Height_Px    : constant := 30.5;   --  (1.525 m: the skeleton's 61 voxels of 2.5 cm)
   Ref_Head_Px      : constant := 8.5;    --  the head's height there, body pixels (it was 10: the skeleton's 20 voxels)
   Ref_Head_Least   : constant := 8;      --  and no head less (at 7 a child's mouth would be its head's last row)
   Ref_Crown_Cut    : constant := 1;      --  then its crown cut by this, body pixels, the face kept: 7 or 8 tall
   Ref_Head_W       : constant := 6;      --  its width, body pixels (12 voxels: the skeleton's; the hair a voxel more)
   Ref_Head_D       : constant := 6;      --  its depth (it was 7: the skeleton's 14 voxels)
   Ref_Leg_Share    : constant := 0.575;  --  the hips' joint over the soles, of the height under the head
   Ref_Hand_Share   : constant := 0.28;   --  the hands' ends, hanging, over the soles, of the height
   Ref_Upper_Of_Arm : constant := 0.58;   --  the upper arm, of the arm from the shoulder to the wrist
   Ref_Waist_Taper  : constant := 0.22;   --  the chest and the hips draw in to the waist (a child's half)
   Ref_Fore_Taper   : constant := 0.3;    --  the forearm narrows by this to the wrist (0.5 until "the wrist exposes the
                                          --  bone", 2026-11-24: it came to a voxel)
   Ref_Shoulder_In  : constant := 1.0;    --  the upper arm's inner side this far into the chest's, body pixels (two voxels:
                                          --  one, then "bring the sholders in another square", 2026-11-24)
   Ref_Arm_W        : constant := 2.5;    --  a grown serf's arm across, body pixels (five voxels; it was 3, six)
   Ref_Head_Round   : constant := 1.5;    --  the head's edges rounded by this, body pixels (it was 1.0)
   Ref_Head_Ends    : constant := 2.0;    --  and its chin's and crown's edges by this (voxels only)
   Hair_Strand      : constant := 0.15;   --  hair a voxel fine: a strand's shade, up to this darker or lighter
   Hood_Round       : constant := 2.0;    --  the winter hood's edges rounded by this, body pixels (it was 1.0)
   Neck_Px          : constant := 1;
   Form_Limb_Taper  : constant := 0.26;   --  in the place of Limb_Taper
   Form_Waist_Taper : constant := 0.12;   --  of Waist_Taper
   Form_Jaw_Taper   : constant := 0.16;   --  of Jaw_Taper
   Form_Limb_Round  : constant := 0.38;   --  a limb's rounding, as a share of its width (the rule's is Round_Share)

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
      Round_Ends : Float := 0.0;   --  its top and bottom edges rounded by this where it is more than Round
                                   --  (its upright edges by Round): voxels only, the box path draws Round
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
   Skin_H : constant := 128;   --  (64 until 2026-11-24: the reference body's head and hair are painted a
                               --  voxel fine, two texels a body pixel; the sheet grew in height only, so
                               --  that every other net lies where it lay)
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
