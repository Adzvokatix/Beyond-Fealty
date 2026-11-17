with Castle.Math; use Castle.Math;
with Castle.Rays;

--  What a ray is pointing at: a person, a deer, a zone, or else the block.
--  The ray is the cursor's in the view from above and will be a reticle's
--  on foot; whoever casts it has already walked it into the blocks
--  (Castle.Rays), and gives that hit here.
--
--  A person or a deer the ray passes through, in front of the ground, is
--  what is pointed at (the nearest, if there are several): never one
--  behind a wall or a hill.  Failing that, a zone whose ground or goods the
--  ray meets: a stockpile's cell, the camp's square.  Failing that, the
--  block.  Nothing at all beyond Reach.
package Castle.Pick is

   Reach_M : constant := 6.0;
   --  How far the player's character reaches on foot (stage 7 gives him
   --  feet).  The development view, from above, has no limit.
   No_Limit : constant Float := Float'Last;

   type Thing_Kind is (Nothing, A_Person, A_Deer, A_Zone, A_Block, A_House, A_Cart);
   --  (A_House: a house of the colony's, standing or begun: its walls, its
   --  roof, or the ground its walls are to stand on.  A_Cart: the lord's
   --  cart, where the ray lands on its bed or on the ground under it.)
   type Thing is record
      Kind   : Thing_Kind := Nothing;
      Index  : Natural := 0;               --  the member, the deer, the zone, the house
      Point  : Vec3 := (0.0, 0.0, 0.0);    --  where the ray meets it
      Dist   : Float := 0.0;               --  metres along the ray
      Ground : Castle.Rays.Hit;            --  the block behind it all (not Found: sky)
   end record;

   function Look
     (From, Dir : Vec3;                    --  metres; Dir a unit vector
      Ground    : Castle.Rays.Hit;         --  the ray walked into the blocks
      Reach     : Float := No_Limit;
      Slack     : Float := 0.0;
      Keep      : Thing := (others => <>)) return Thing;
   --  Slack: how far the ray may miss a person or a deer and still mean it,
   --  in metres for each metre away (a few pixels of the screen, so a figure
   --  far off is no harder to point at than one close by).  Something the
   --  ray truly passes through always comes first.
   --  Keep: what was pointed at a moment ago.  If that was a person or a
   --  deer and the ray still passes through it, it is still the one meant,
   --  whoever steps in front: in a crowd the pointer does not flit from one
   --  to the next.

   ------------------------------------------------------- where the bodies are

   --  A person or a deer, for the ray: a rod with round ends.
   type Capsule is record
      A, B : Vec3 := (0.0, 0.0, 0.0);      --  the ends of its axis (a person's feet and crown)
      R    : Float := 0.0;                 --  how thick (0: there is nothing there)
   end record;
   type Shape_Source is access function (I : Positive) return Capsule;

   function Colony_Person (I : Positive) return Capsule;
   function Herd_Deer (K : Positive) return Capsule;
   --  From the colony's and the herds' own positions: standing where they
   --  are; asleep or dead, lying with their feet toward what they lie by.

   procedure Set_Shapes (People, Deer : Shape_Source);
   --  The game gives the shapes as they are drawn (a body eases after its
   --  colony position); the checks leave the two above in place.

   function Lying (Feet : Vec3; Heading, Height : Float) return Capsule;
   --  A person of that height on its back, having faced Heading: its head
   --  lies behind where it stood.
   function Standing (Feet : Vec3; Height : Float) return Capsule;

end Castle.Pick;
