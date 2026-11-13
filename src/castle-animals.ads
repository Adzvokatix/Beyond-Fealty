with Castle.Hash;  use Castle.Hash;
with Castle.Math;  use Castle.Math;
with Castle.Deer;

--  Animals on screen and how they move: for now deer (Castle.Deer).  As
--  with serfs, movement is presentation: where an animal is meant to be
--  comes from outside (the herds of Castle.Colony, or a scripted walk), and
--  its body follows through second-order filters.  The legs are a stepper
--  driven by the gait's phase: a hoof stays planted where it landed (it
--  never slides) until its turn in the footfall, then swings on an arc to
--  where it will be needed when it lands, half a stance ahead of its hip.
--  The gait follows the speed: a walk (left hind, left fore, right hind,
--  right fore, three hooves down at a time), a trot (diagonal pairs) and a
--  bound (hind pair then fore pair, all four in the air between).
--  Standing, a deer shifts one hoof at a time when one is out of place.
--  The head is up and turning when it stands alert, down to the grass when
--  it grazes, forward when it runs.  Main thread only.
package Castle.Animals is

   Max_Animals : constant := 128;

   subtype Mode is Castle.Deer.Standing_Mode;   --  what it does when it is not going anywhere
   type Gait is (Stand, Walk, Trot, Bound);

   function Spawn (C : Castle.Deer.Class; Where : Vec3; Facing : Float; Seed : U64; Winter : Boolean)
                   return Natural;
   --  Where: a ground point (the middle of the body, between the legs).
   --  0: no room for another.
   procedure Drive (I : Positive; Where : Vec3; M : Mode);
   --  Where it is meant to be (a ground point); M: what it does standing.
   procedure Set_Winter (I : Positive; Winter : Boolean);   --  its coat
   procedure Restyle (I : Positive; C : Castle.Deer.Class);   --  grown into another class
   procedure Remove (I : Positive);                           --  no longer drawn (its slot stays)
   procedure Clear;

   procedure Spawn_Walker (C : Castle.Deer.Class; From, To : Vec3; Speed : Float; Seed : U64; Winter : Boolean);
   --  Scripted, for looking: a deer going From To and back at Speed (m/s),
   --  by routes on the walking map, pausing at each end.

   function Look (C : Castle.Deer.Class; Winter : Boolean) return Natural;
   --  The look a deer of class C wears (Castle.Figures), made the first
   --  time: for drawing a carcass.

   procedure Update (Dt : Float);
   --  Dt seconds of animation (any frame time: the filters are exact and
   --  the stepper is timed by the gait's phase).
   procedure Submit;
   --  Every animal into Castle.Figures for this frame (after
   --  Castle.Serfs.Submit, which begins the frame's figures).

   --  for checks and the camera
   function Count return Natural;
   function Where (I : Positive) return Vec3;        --  the ground point under the body
   function Speed (I : Positive) return Float;       --  m/s, as the body moves
   function Gait_Of (I : Positive) return Gait;
   function Planted (I : Positive; L : Castle.Deer.Leg) return Boolean;
   function Hoof_At (I : Positive; L : Castle.Deer.Leg) return Vec3;   --  the ground point under the hoof
   function Reached (I : Positive) return Boolean;   --  every planted hoof was reached, last solve
   function Class_Of (I : Positive) return Castle.Deer.Class;
   function Pose_Of (I : Positive) return Castle.Deer.Pose;   --  as last animated

end Castle.Animals;
