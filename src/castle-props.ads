with Castle.Figures;
with Castle.Poses;
with Castle.Math; use Castle.Math;

--  Things lying about, drawn the way people are (Castle.Figures: boxes on
--  the 5 cm pixel grid with a painted skin): the basket of berries, a
--  gatherer's load, the log, a forester's, and a porter's sheaves, stones
--  and buckets; they are how a stockpile cell shows what it holds.
package Castle.Props is

   function Basket return Castle.Figures.Look_Id;
   --  A wicker basket 30 cm across, heaped with berries; made the first time.
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

   procedure Put (L : Castle.Figures.Look_Id; Ground : Vec3; Turn : Float);
   --  One prop standing on Ground this frame, turned Turn radians.  After
   --  Castle.Serfs.Submit (which begins the frame's figures).
   procedure Put_Scaled (L : Castle.Figures.Look_Id; Ground : Vec3; Turn : Float; Wide, Tall, Lean_X : Float);
   --  The same, stretched Wide across and Tall up, its top leaned Lean_X
   --  (metres per metre of height) along its X: flames.

end Castle.Props;
