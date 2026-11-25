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

   Whole_Back : Boolean := True;
   --  A deer's body is one piece.  Its hips and its withers each stand at
   --  their height over the ground under them, and on steep ground those
   --  two grounds are far apart: the hindquarters and the forequarters
   --  were drawn that far apart too (John, 2026-11-22, with a picture of
   --  one in two halves on a rock face: "deer can split in half when
   --  running up steep terrain").  Now the back is pitched as the ground
   --  under its two ends asks, no steeper than Back_Pitch_Tan, and the ends
   --  stand that much nearer each other across the ground, a back's length
   --  apart along the back (the length they are apart on level ground),
   --  each over the ground there.  On ground steeper than a back is drawn
   --  the higher end stands on its own ground and the lower is held up as
   --  far as the back lets it hang: its legs reach down for their hooves
   --  and fall short.  Whatever is left over a back's length is taken in
   --  about the middle.  The hooves are put down under the joints as they
   --  then are.  False (the game's --no-whole-back): as it was.  Drawing
   --  only.
   Back_Pitch_Tan : constant := 1.0;   --  the steepest a back is drawn: 45 degrees, as steep as a way up may be

   --  How far apart the hips and the withers have been drawn, in backs'
   --  lengths (1: as on level ground): counted over every deer animated
   --  since Clear_Backs, for the game's --deer-stats and the checks.
   Long_Back : constant := 1.1;
   type Back_Count is record
      Frames  : Natural := 0;     --  deer animated, a frame each
      Long    : Natural := 0;     --  of them, drawn more than Long_Back lengths long
      Longest : Float := 0.0;     --  the longest drawn
   end record;
   function Backs return Back_Count;
   procedure Clear_Backs;

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
