with Castle.Cloth;
with Castle.Bodies;
with Castle.Figures;
with Castle.Hash;
with Castle.Poses;
with Castle.Math; use Castle.Math;

--  Things lying about, drawn the way people are (Castle.Figures: boxes on
--  the 5 cm pixel grid with a painted skin): the basket of berries, a
--  gatherer's load, the log, a forester's, and a porter's sheaves, stones
--  and buckets; they are how a stockpile cell shows what it holds.
package Castle.Props is

   function Basket return Castle.Figures.Look_Id;
   --  A wicker basket 30 cm across, heaped with berries; made the first time.
   Basket_Tall : constant := 0.2;    --  m: its wicker, to the rim (the heap stands 5 cm over it): what a
                                     --  basket stood on another is lifted by
   type Heap_Kind is (Berry_Heap, Vegetable_Heap, Apple_Heap, Grain_Heap);
   function Basket_Of (Heap : Heap_Kind) return Castle.Figures.Look_Id;
   --  The same basket heaped with berries, roots and greens, or apples.

   function Log return Castle.Figures.Look_Id;
   --  A bucked log 1 m long and 20 cm thick, lying along the prop's own X
   --  (the Turn direction), its underside at the ground point: bark along
   --  it, pale end grain with rings at both ends.

   function Sheaf return Castle.Figures.Look_Id;
   --  A sheaf of straw 80 cm long, tied round the middle, lying along X.
   function Stone return Castle.Figures.Look_Id;
   --  A fieldstone 20 x 15 x 15 cm.
   function Clod return Castle.Figures.Look_Id;
   --  A clod of earth 25 x 25 x 20 cm: a heap of them is earth in store.
   function Cloak_Folded (C : Castle.Bodies.RGB) return Castle.Figures.Look_Id;
   --  A cloak of that colour folded and set down: 45 x 30 x 8 cm, its
   --  middle at the origin.
   function Cloak_Spread (C : Castle.Bodies.RGB) return Castle.Figures.Look_Id;
   procedure Put_Cloth (C : Castle.Cloth.Cloth_Id; Colour : Castle.Bodies.RGB;
                        Pivot : Vec3 := (0.0, 0.0, 0.0); Radians : Float := 0.0);
   --  (Radians /= 0: drawn turned about the upright through Pivot: a sheet
   --  lying in a building that is drawn turned)
   --  A sheet of cloth as it lies now (Castle.Cloth), in that wool: a thin
   --  panel of it between each four points, each panel a box on a bone of
   --  its own (two figures; the bow's way), sharp-edged so that they meet.
   --  After Castle.Serfs.Submit, like Put.
   --  The same cloak spread over a sleeper who lies on its side: a low mound
   --  along the prop's X, highest over the shoulders (toward +X) and lower
   --  over the legs, for someone 1.7 m tall (Put_In it in a frame scaled for
   --  the rest); the origin is on the ground under the middle of the sleeper
   --  at its hips.  The head lies out of it, past its +X end.
   function Pallet return Castle.Figures.Look_Id;
   --  A bed of straw: loose straw trodden flat, 1.9 m long (along the
   --  prop's X) and 0.8 m across, a hand deep; its middle at the origin.
   function Bucket return Castle.Figures.Look_Id;
   --  A stave bucket 25 cm across and tall, two iron bands, full of water;
   --  its base at the ground point.

   function Joint return Castle.Figures.Look_Id;
   --  A joint of venison, 20 x 15 x 15 cm.
   function Hide return Castle.Figures.Look_Id;
   --  A deer hide folded flat, 40 x 30 x 5 cm.
   function Arrow return Castle.Figures.Look_Id;
   --  An arrow 70 cm long along the prop's Y, fletched at the back, the
   --  point at its origin's far end (Y + 35 cm).

   --  Tools.  Castle.Serfs carries them: stowed while their owner goes
   --  about, in the hand while it works with them.
   Axe_Head_M : constant := 0.48;   --  from the end of the haft to the middle of the head
   function Axe return Castle.Figures.Look_Id;
   --  A felling axe 55 cm long along the prop's Z, the end of its haft at
   --  the origin, the head at the far end, its bit toward the prop's Y.
   --  Place it with Put_In.
   procedure Put_In (L : Castle.Figures.Look_Id; F : Castle.Poses.Frame);
   --  One prop in frame F this frame: its origin and its axes, which need
   --  not be upright.

   Bow_Brace_M : constant := 0.15;  --  the string behind the grip, at rest (about)
   Bow_Draw_M  : constant := 0.30;  --  the string drawn this far back is a full draw
   function Bow_Rest (Grip : Castle.Poses.Frame) return Vec3;
   --  Where the middle of the string is with the bow at rest.
   procedure Put_Bow (Grip : Castle.Poses.Frame; Held : Boolean := False; Nock : Vec3 := (0.0, 0.0, 0.0));
   --  The hunter's short bow, a little over a metre of curved stave and its
   --  string: the middle of its grip at Grip.O, its length along Grip.Z,
   --  its back toward Grip.Y, the string behind it (toward the archer).
   --  Each limb is four pieces on bones of their own, so the stave is a
   --  curve and can bend: Held, the middle of the string is at Nock, and
   --  the further that is behind where it rests, the more the limbs bend
   --  (a full draw at Bow_Draw_M).

   Quiver_Mouth_M : constant := 0.40;   --  from the quiver's foot to its mouth
   function Quiver return Castle.Figures.Look_Id;
   --  A hunter's belt quiver: a leather tube 40 cm long along the
   --  prop's Z, its foot at the origin, a darker band round its mouth and
   --  the fletched ends of four arrows standing out of it.  Place it with
   --  Put_In.

   --  The camp:
   function Seat return Castle.Figures.Look_Id;
   --  A seat log 1 m long and 35 cm thick, lying along X, its underside at
   --  the ground point.
   function Crossbar return Castle.Figures.Look_Id;
   --  Two forked posts 1.5 m apart along X and a bar across their tops at
   --  1.2 m, a hook hanging from its middle: the pot's, over the fire.
   function Pot (Full : Boolean) return Castle.Figures.Look_Id;
   --  The iron pot the band brought, 35 cm across and 30 cm deep, its
   --  bail up to the hook; its base at the ground point.  Full: stew in it.
   function Embers return Castle.Figures.Look_Id;
   --  The fire's bed: charred sticks and glowing coals, 45 cm across, low.
   function Ashes return Castle.Figures.Look_Id;
   --  The same bed with the fire out: the sticks charred, on grey ash.

   --  What a fire is drawn from (Castle.Fire), many at a time, each scaled
   --  (Put_Scaled): a cube Bit_M on a side, its foot at its origin.
   Bit_M : constant := 0.10;
   type Flame_Heat is range 1 .. 5;
   function Flame_Bit (Heat : Flame_Heat) return Castle.Figures.Look_Id;
   --  A piece of flame: 1 the pale yellow of the fire's heart, then gold,
   --  orange and red, 5 the dull red of a tip going out.  It glows (its box
   --  is drawn unlit and casts no shadow).
   type Smoke_Shade is range 1 .. 3;
   function Smoke_Bit (Shade : Smoke_Shade) return Castle.Figures.Look_Id;
   --  A puff of smoke: 1 grey, fresh off the fire, 3 pale, thinning.  Lit
   --  like anything else, half seen through, and it casts no shadow.

   --  The lord's cart (the colony stands its bed in the world as a slab of
   --  timber, 2 m by 1 m, its top 0.75 m over the ground: this is drawn
   --  round that).
   procedure Put_Cart (Ground : Vec3; Turn : Float; Sacks : Natural; Towed : Boolean := False; Roll : Float := 0.0);
   --  A four-wheeled cart along Turn, its middle over Ground: boards over
   --  the bed and round it (their tops at 1.05 m), a post at each corner,
   --  two axles and four wheels under it, two shafts out of its front end
   --  resting on a prop, and Sacks sacks lying in it (six at most).  After
   --  Castle.Serfs.Submit, like Put.  Towed: its shafts held up, the prop
   --  they rest on not under them.  Roll: its wheels turned that far about
   --  their axles (radians; as far as it has gone over Wheel_Hub_M: John,
   --  2026-11-17, "Add cart wheel animations").
   Cart_Axle_M  : constant := 0.65;     --  the axles are this far before and behind its middle,
   Cart_Track_M : constant := 0.62;     --  the wheels this far either side of it,
   Cart_Bed_M   : constant := 0.77;     --  and its bed's top this far over the ground
   Wheel_Hub_M  : constant := 0.45;     --  a wheel's hub over the ground
   function Wheel return Castle.Figures.Look_Id;
   --  A cart wheel 90 cm across and 10 cm thick, standing on the ground
   --  point in the plane of the prop's X and Z: an iron tyre, wooden
   --  felloes, eight spokes and a hub.
   function Door_Leaf (Mirrored : Boolean := False) return Castle.Figures.Look_Id;
   --  A door's leaf, 1 m wide and 2 m tall, of upright planks 6 cm thick:
   --  its hinge edge at the prop's ground point, the leaf along its X; iron
   --  straps and a latch on its -Y side (the outside), two ledges on the
   --  other.  Mirrored: the straps on +Y and the ledges on -Y (a leaf hung
   --  from the other jamb).  A doorway 2 m wide has two.
   function Gate_Leaf (Mirrored : Boolean := False) return Castle.Figures.Look_Id;
   --  A gateway's leaf, 1 m wide and 1 m tall: three stiles and three rails
   --  (on its -Y side; Mirrored: on +Y), its hinge edge at the prop's ground
   --  point, the leaf along its X.  A gateway 2 m wide has two.
   --  Pieces of a stockyard drawn as its design has them rather than as its
   --  blocks are laid (Castle.Colony.Yard_Pieces; 2026-11-20).  Each is a
   --  block thick and a metre long or square, painted as the block it stands
   --  for is (its colour, its texels a block's: 5 cm), and is put in a frame
   --  whose axes stretch it to its length (Put_In).
   function Rail (Plank : Boolean := False) return Castle.Figures.Look_Id;
   --  A rail of timber (Plank: a plank, as over a gateway) from the origin
   --  a metre along X, its middle on the X axis: 25 cm square across.
   function Thatch_Tile return Castle.Figures.Look_Id;
   --  A covering's roof of straw smoothed, 20 cm thick: from the origin 3 m
   --  along X (along its courses) and 2.1 m along Z (down its slope), its
   --  top at Y = 0 and its thickness toward -Y; its edges square (a rounded
   --  edge is laid along them: Thatch_Roll).  Put in a frame whose X, Y and
   --  Z are its length, its top's normal and its slope, each as long as it
   --  is to be (a frame turned inside out draws its insides).
   function Thatch_Roll (Inner : Boolean := False) return Castle.Figures.Look_Id;
   --  The rounded edge of such a roof, a metre of it along X from the
   --  origin, its middle on the X axis, 30 cm across: laid along a roof's
   --  edges ("rounded edges around the peremeter").
   --
   --  Cover_Thatch (John, 2026-11-20: "connect the rounded edges together
   --  along the length, and texture the roof of the outdoor storage the same
   --  as all the other roofs, that is the defult for all thatch roofs").
   --  The roof's texels are the land's own for a block of thatch
   --  (Castle.Textures: the same picture every other thatch roof is drawn
   --  with, a variant a block, a dark line where one course overlaps the
   --  next), and a piece of the rounded edge reaches Roll_Lap_M past each
   --  end of its metre, so that laid end to end the pieces run into one
   --  another and the edge is one roll from corner to corner.  Two of the
   --  same width lapped so would show now one and now the other where they
   --  lie in each other, so every second piece is Inner: half a centimetre
   --  narrower, and hidden wherever its neighbour is whole.  At a corner the
   --  two edges' last pieces end in one rounded knuckle.  False (the game's
   --  --no-cover-thatch): as it was drawn before (texels of its own, a
   --  metre of edge at a time; Inner the same look).  Set before a covering
   --  is first drawn.
   Cover_Thatch : Boolean := True;
   Roll_Lap_M   : constant := 0.15;
   procedure Set_Texel_Seed (Seed : Castle.Hash.U64);
   --  The seed the land's texels are made from (the world's: Castle.Render
   --  makes them from it), told before a covering is first drawn; 1 until
   --  told.
   function Window_Trim (Tall : Boolean) return Castle.Figures.Look_Id;
   --  The trim round a window half a metre wide (Tall: 75 cm high, else 50):
   --  a strip of plank Trim_W wide up each side of the opening and across
   --  its top, none under it, lying on the wall's face on the prop's -Y
   --  side (a wall a block thick, its middle on the prop's X axis); the
   --  opening's lower corner at the prop's ground point, the opening along
   --  its X.
   Trim_W : constant := 1.6;      --  pixels: 8 cm ("the first fraction of blocks around the window")
   function Sack return Castle.Figures.Look_Id;
   --  A sack of salt, 60 x 35 x 25 cm, lying along X, tied at one end; its
   --  underside at the ground point.

   Barrel_Tall : constant := 0.8;    --  m: what a barrel stood on another is lifted by
   function Barrel (Water : Boolean) return Castle.Figures.Look_Id;
   --  A barrel 55 cm across and 80 cm tall, of staves with three iron
   --  hoops, standing on the ground point: shut with a lid (meat packed in
   --  salt), or open and full of water.
   function Shelf return Castle.Figures.Look_Id;
   --  A metre of shelving against a wall: four posts 1.5 m tall and three
   --  boards 40 cm deep, at 20, 70 and 120 cm.  Along the prop's X, its
   --  back on the ground point's line, its front toward +Y.
   Shelf_Boards : constant array (1 .. 3) of Float := [0.25, 0.75, 1.25];   --  each board's top, metres

   function Ladder return Castle.Figures.Look_Id;
   --  A ladder 3.4 m long and 40 cm wide lying along the prop's X, its
   --  middle at the origin: two rails and ten rungs.
   procedure Put_Ladder (Foot, Top : Vec3);
   --  One leaning from Foot, on the ground, against Top (an eave): it
   --  stands out past Top by what is left of its length.
   procedure Put_Ladder_Stood (Ground : Vec3; Turn : Float; Nth : Positive := 1);
   --  One put by in a stockpile's place: stood all but upright against a
   --  pole, the two an A 80 cm across along Turn over the middle of the
   --  place (lying, its 3.4 m ran through the goods of the places beside
   --  it).  Nth: a second in the same place leans beside the first.

   procedure Put (L : Castle.Figures.Look_Id; Ground : Vec3; Turn : Float);
   --  One prop standing on Ground this frame, turned Turn radians.  After
   --  Castle.Serfs.Submit (which begins the frame's figures).
   procedure Put_Scaled (L : Castle.Figures.Look_Id; Ground : Vec3; Turn : Float; Wide, Tall, Lean_X : Float);
   --  The same, stretched Wide across and Tall up, its top leaned Lean_X
   --  (metres per metre of height) along its X: flames.

end Castle.Props;
