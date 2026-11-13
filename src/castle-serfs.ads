with Castle.Hash;   use Castle.Hash;
with Castle.Math;   use Castle.Math;
with Castle.Bodies; use Castle.Bodies;
with Castle.Poses;

--  The serfs on screen and how they move.  For now a lineup to look at and
--  walkers on scripted routes; the colony's simulation will later own where
--  serfs are and what they do, and this layer will only show it.
--
--  Movement is presentation: each frame a serf's body follows where it is
--  meant to be through second-order filters (Castle.Second_Order), and a
--  stepper puts its feet down on the tops of real blocks: a foot stays
--  planted until its turn, then swings on an arc to a spot ahead (lifted
--  higher when stepping up a block), as .kkrieger's walk operator did,
--  adapted for two legs.  The pelvis rides on the feet with a bob and a
--  sway over the standing foot, the arms swing against the legs and lag a
--  little, the head looks into turns.  Each serf's filters take their
--  character from the genome: children quick and bouncy, elders slow and
--  heavily damped.
package Castle.Serfs is

   Max_Serfs : constant := 256;

   --  The tool of a job (John, 2026-11-11: "is there a way to place the bow
   --  on the back, and the axe on the hip when they aren't swinging it"): a
   --  forester's axe hangs behind the hip of its dominant side and is in
   --  its hands while it chops; a hunter's bow is across its back and in
   --  its off hand while it stalks and shoots (with a deer across its
   --  shoulders the bow is let down level across the small of its back).
   --  They are Castle.Props.Axe and Put_Bow, placed from the body's frames;
   --  between the two places a tool goes through a filter, not at once.
   --  Children carry none.
   Axe_Hold_S : constant := 0.8;   --  the axe stays in the hand this long after the last stroke
   Bow_Hold_S : constant := 2.5;   --  and the bow this long after a stalk or a shot
   Cloak_Px   : constant := 1.2;   --  a tool stowed on the back sits this much further out over a winter cloak
   Quiver_Tilt : constant := 0.6;  --  the hunter's quiver leans this far from upright (radians), its mouth to the drawing side
   Quiver_Sat  : constant := 1.35; --  and this far when he sits: along the belt, clear of the seat

   procedure Spawn_Lineup (N : Positive; Centre : Vec3; Facing : Float; Seed : U64; Winter : Boolean);
   --  N generated serfs in a row across Centre (a ground point), facing
   --  Facing, every job and age in turn; seen from in front, the first is
   --  on the left (in the order Describe lists them).

   procedure Spawn_Walker (From, To : Vec3; Seed : U64; Job : Job_Kind; Winter : Boolean;
                           Speed : Float := 1.3);
   --  A serf walking From to To and back, pausing at each end, by routes
   --  planned on the map (Castle.Nav): round what is in the way, at the pace
   --  the ground allows, planned again when an edit cuts the way.  Speed:
   --  its pace on grass (the map's times are scaled by Speed / Walk_Speed).

   procedure Plan_Walkers;
   --  Plan now for walkers that have no route (spawned this frame).
   function Route_Summary (I : Positive) return String;

   procedure Submit_Routes;
   --  The way each walker means to go, as strips over the ground
   --  (Castle.Marks): red when blocked or the goal can't be reached.

   --  Serfs the colony moves (Castle.Colony): each frame the game says where
   --  one is meant to be and what it is doing; the body follows as any serf
   --  does, and works: picking, it crouches a little, leans in and reaches
   --  into the bush with both hands in turn; putting down, it bends to the
   --  ground; chopping, it swings the axe two-handed from over its dominant
   --  shoulder into the trunk at Spot.  The work pose comes and goes through
   --  a filter, not at once.  A serf with a log on its shoulder carries it
   --  on the off side, steadied with the off hand.
   type Motion_Kind is (Stand, Walk, Pick, Put_Down, Chop, Sneak, Aim, Eat, Lie, Stir, Sit_Eat);
   --  Sneak: walking crouched and leaning in (a hunter stalking); Aim: the
   --  bow held out toward Spot, the string drawn back to the cheek; Eat:
   --  food held at the chest in the off hand, the other hand going between
   --  it and the mouth; Lie: lying on its back, asleep, its feet toward Spot
   --  (it lies down and gets up through a filter, tipping back about its
   --  heels); Stir: facing the pot at Spot, the dominant hand going round in
   --  it, the other at its rim; Sit_Eat: eating, sitting on a seat 35 cm
   --  high at Where, facing Spot, the feet out in front.
   function Spawn_Driven (G : Genome; O : Outfit; Where : Vec3; Facing : Float) return Natural;
   --  0: no room for another.
   procedure Drive (I : Positive; Where : Vec3; M : Motion_Kind; Spot : Vec3; Log : Boolean := False;
                    Buckets : Boolean := False);
   --  Where: the feet; Spot: what the hands go to (picking, putting down,
   --  the axe's mark).  Log: a load on the shoulder (a log, a sheaf).
   --  Buckets: one in each hand, so the arms hang a little out from the
   --  body and hardly swing.
   function Log_Rest (I : Positive) return Vec3;
   --  Where the middle of the underside of a shoulder load sits (the top of
   --  the off shoulder, beside the head), as last animated.
   function Hand_At (I : Positive; S : Side) return Vec3;   --  the wrist, as last animated
   function Heading (I : Positive) return Float;   --  the way the body faces, as last animated
   function Shoulders_Top (I : Positive) return Vec3;
   --  The middle of the tops of the shoulders, behind the neck: where a
   --  load across both shoulders rests, as last animated.
   procedure Restyle (I : Positive; O : Outfit);   --  dressed for another job
   procedure Clear;                                --  every serf gone (a save loaded)

   procedure Update (Dt : Float; Eye : Vec3);
   --  Dt seconds of animation (any frame time; the filters are exact).

   procedure Submit;
   --  Every serf into Castle.Figures for this frame.

   function Count return Natural;
   function Describe (I : Positive) return String;
   function Where (I : Positive) return Vec3;   --  the ground point under serf I
   function Posed (I : Positive) return Castle.Poses.Pose;   --  as last animated
   function Rig_Of (I : Positive) return Rig;

   function Ground_At (X, Y, Near_Z : Float) return Float;
   --  The top of the ground under (X, Y) near height Near_Z (metres): the
   --  first solid block, scanning down from a metre above, with room over
   --  it.  Near_Z when nothing is loaded there.

end Castle.Serfs;
