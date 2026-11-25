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

   Walker_Round_M : constant := 64.0;
   --  A walker's way (and a walking deer's, Castle.Animals) is looked for
   --  on the ground within this of the circle on its two ends: with the
   --  whole map held, an end that cannot be got to would otherwise be looked
   --  for over all of it.
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
   type Motion_Kind is (Stand, Walk, Pick, Put_Down, Chop, Sneak, Aim, Eat, Lie, Stir, Sit_Eat, Sleep);
   --  Sneak: walking crouched and leaning in (a hunter stalking); Aim: the
   --  bow held out toward Spot, the string drawn back to the cheek; Eat:
   --  food held at the chest in the off hand, the other hand going between
   --  it and the mouth; Lie: lying on its back, its feet toward Spot (it lies
   --  down and gets up through a filter, tipping back about its heels: the
   --  dead lie so); Sleep: asleep, lying on its side a little curled up,
   --  its feet toward Spot (it rolls onto its side as it goes down; which
   --  side is its own: John, 2026-11-12, "have serfs sleep on their side"); Stir: facing the pot at Spot, the dominant hand going round in
   --  it, the other at its rim; Sit_Eat: eating, sitting on a seat 35 cm
   --  high at Where, facing Spot, the feet out in front.
   function Spawn_Driven (G : Genome; O : Outfit; Where : Vec3; Facing : Float) return Natural;
   --  0: no room for another.

   type Solid_Reader is access function (Bx, By, Bz : Integer) return Boolean;
   procedure Set_Ground_Source (Solid : Solid_Reader);
   --  For the checks: what Ground_At takes for solid ground (null: the
   --  game's blocks, Castle.World_Blocks, as ever).  The feet of serfs and
   --  the hooves of deer are put down by it.

   Rest_Arms : Boolean := True;
   --  On the reference body, standing at rest: the upper arms Rest_Spread further out from the sides, the
   --  forearms Rest_Fore_In back in toward the body from them, so that the elbows stand out of the line
   --  of the arm, and bent Rest_Elbow more (John, 2026-11-24: "elbows angled away from the body at a
   --  resting state, slight bend at the arms"); gone as it walks (by 0.6 m/s) and as it works.  First
   --  values.  False (the game's --no-rest-arms): the arms at rest as they were.
   Rest_Spread  : constant := 0.18;   --  rad
   Rest_Fore_In : constant := 0.30;
   Rest_Elbow   : constant := 0.17;

   Hands_Before_Chest : Boolean := True;
   --  Eating (Eat, Sit_Eat), the hands are placed before the chest as it
   --  leans and bends (the food held a hand's breadth off its front, the
   --  other hand going between it and the mouth) and the elbows go down by
   --  the ribs.  (John, 2026-11-22, with two pictures of serfs on a seat:
   --  "serfs arms and hands are behind there back when they sit down to
   --  eat".  The hands had been placed 20 cm before the hips, whatever the
   --  trunk did: with the lean and the bend of an eater that is inside the
   --  chest, a hand's breadth from its middle, and an arm solved to there
   --  with its elbow back had the elbow behind the back and the forearm
   --  through the body; standing eaters the same.)  False (the game's
   --  --no-chest-hands): as it was.  Drawing only.
   procedure Drive (I : Positive; Where : Vec3; M : Motion_Kind; Spot : Vec3; Log : Boolean := False;
                    Buckets : Boolean := False);
   --  Where: the feet; Spot: what the hands go to (picking, putting down,
   --  the axe's mark).  Log: a load on the shoulder (a log, a sheaf).
   --  Buckets: one in each hand, so the arms hang a little out from the
   --  body and hardly swing.
   procedure Turn_About (I : Positive; Pivot : Vec3; Radians : Float);
   --  Serf I is drawn turned Radians about the upright through Pivot, all of
   --  it and whatever is placed from it (a building drawn turned, John,
   --  2026-11-19: what is within its walls is drawn through its turn).
   --  Drawing only: where it stands and how it is animated are as they
   --  were (Where is not turned).  Asked each frame as Perch is; 0: not.
   --  It comes on and goes off over a moment, so one walking in at a turned
   --  doorway, or a builder coming to a turned house, does not jump.
   procedure Perch (I : Positive; Up : Float);
   --  Serf I stands Up metres over the ground under it (on a ladder's
   --  rungs): the whole of it is drawn that much higher, eased over a
   --  moment, its hands still going to Spot.  0 (as every serf starts): on
   --  the ground.  No climbing is shown.
   procedure Lie_Facing (I : Positive; On : Boolean; P : Vec3 := (0.0, 0.0, 0.0));
   --  Asleep on its side, serf I turns its face to P (the fire it lies
   --  across the way to): which side it lies on follows from the way it
   --  lies.  Off (as every serf starts): the side that is its own.
   function Log_Rest (I : Positive) return Vec3;
   --  Where the middle of the underside of a shoulder load sits (the top of
   --  the off shoulder, beside the head), as last animated.
   function Hand_At (I : Positive; S : Side) return Vec3;   --  the wrist, as last animated
   function Heading (I : Positive) return Float;   --  the way the body faces, as last animated
   function Shoulders_Top (I : Positive) return Vec3;
   --  The middle of the tops of the shoulders, behind the neck: where a
   --  load across both shoulders rests, as last animated.
   function Cloak_Of (I : Positive) return RGB;    --  the colour of its cloak, worn or not
   function Height_Of (I : Positive) return Float; --  metres, soles to crown
   function Lies (I : Positive) return Float;      --  how far it is lying down, 0 .. 1, as last animated
   procedure Lying_Frame (I : Positive; Hips, Along, Belly : out Vec3);
   --  Lying: the ground point under its hips, the way from its hips to its
   --  head, and the way its belly faces (both level, unit), as last animated:
   --  where a cloak spread over it goes.
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
   function Frames_Of (I : Positive) return Castle.Poses.Frames;   --  its bones in the world, as last submitted
   function Frames_Home (I : Positive) return Castle.Poses.Frames;
   --  The same before any turn (Turn_About): where it stands on the map, for
   --  whatever is worked out there and drawn through the turn afterwards
   --  (its cloak: Castle.Cloth).
   function Rig_Of (I : Positive) return Rig;

   function Ground_At (X, Y, Near_Z : Float) return Float;
   --  The top of the ground under (X, Y) near height Near_Z (metres): the
   --  first solid block, scanning down from a metre above, with room over
   --  it.  Near_Z when nothing is loaded there.

end Castle.Serfs;
