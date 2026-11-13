with Interfaces;
with Castle.Math;    use Castle.Math;
with Castle.Hash;
with Castle.Deer;

--  The deer round the colony: a few herds, simulated on the colony's clock
--  (Castle.Colony steps them) so the same start gives the same herds.
--
--  Each herd has a node: where the herd is, which way it travels and how it
--  gets there.  The node grazes a while, then plans a route (Castle.Nav) to
--  another spot 15 to 30 m off and walks it; it keeps at least 32 m from
--  the stake and within 70 m of it (the colony's ground, which stays
--  loaded).  The deer wander round the node: each keeps to a spot of its
--  own a few metres from it, chosen afresh now and then, walks (or trots,
--  if far) to it and grazes, idles or stands alert there.  A deer steps
--  over the walking map itself, a step at a time: up at most a step, down
--  at most a metre, never into water too deep to wade.
--
--  Fear: someone walking within Fear_M of a deer (a hunter stalking within
--  Stalked_M), or an arrow loosed at the herd (Scare), panics it.  The node
--  flees, 30 m or so straight away from the danger, and the herd flees
--  with it (John, 2026-11-11: "when the herd node move away and deer panic
--  they start to rubberband and swing around, they also don't mind
--  submerging themselves in water"; first rules and values, his to tune):
--    1. A deer starts on a heading of its own, away from the danger, for
--       Startle_S or half as long again; then it runs with the herd: for
--       its own place round the node, as fast as it needs to keep that
--       place and no faster than it can run, never back toward the danger
--       to find it (ahead of its place, it runs on slower and is caught up).
--    2. Its flight is over when the node has stopped and it has come to
--       its place (or after Flight_Max_S, whatever happens).
--    3. A herd in flight is not startled again: only someone within
--       Close_M of one of its deer turns it, the node planning a new way
--       and the deer following, none of them starting afresh.
--    4. With nowhere for the node to flee to (cornered at the edge of its
--       range), each deer bolts a second or two by itself and comes back.
--    5. A deer turns at no more than Turn_Rate (Flight_Turn in flight), and
--       the way it turned aside round something is the way it then faces:
--       it does not flick from heading to heading, step to step.
--    6. A deer left more than Trail_M behind its place does not make
--       straight for it (round a pool or a crag that way lies nowhere): it
--       takes the way the node went, the route the node planned, which the
--       herd keeps after the node has arrived, heading for a point of it
--       Trail_Ahead_M past where it is nearest.  Only the node plans.
--    7. A deer keeps out of water: calm, it steps onto no floor under
--       water at all (Deer_Wade_B rows); in flight, a quarter of a metre
--       (Flight_Wade_B).  One that finds itself deeper may step to water no
--       deeper than it stands in, and, calm, makes for the node itself
--       until it is out.  The node's ways are planned dry the same, its
--       grazing and its flight, and herds are placed on dry ground.
--  Set_Scatter (True) is the herds as they were before these: each deer
--  bounding off on a heading of its own for three to six seconds, then back
--  to the node wherever it has got to, startled again every three seconds
--  while someone is near, wading wherever a serf can.  The older reference
--  runs are kept with it (--deer-scatter).
--
--  In spring each grown doe may have a fawn (a herd keeps to Max_In_Herd).
--  Deer grow up by age: a fawn is a doe or a young stag at a year old, a
--  young stag a stag at two.  Main thread only.
package Castle.Herds is

   Max_Herds   : constant := 8;
   Max_Deer    : constant := 64;
   Max_In_Herd : constant := 10;

   Fear_M      : constant := 15.0;   --  someone walking this near a deer startles the herd
   Stalked_M   : constant := 7.0;    --  a hunter stalking, this near
   Near_Stake_M : constant := 32.0;  --  herds keep at least this far from the stake (out of the band's way)
   Range_M     : constant := 70.0;   --  and within this far of it
   Arrive_Days : constant := 3.0;    --  every so often two deer wander in to join a herd under Full_Herd
   Full_Herd   : constant := 5;

   --  the herd's flight together, and water (first values; see above)
   Flee_M        : constant := 30.0;  --  how far the node flees
   Flee_Pace     : constant := 5.0;   --  m/s, the node in flight (as they were: 4, and the deer outran it)
   Startle_S     : constant := 0.6;   --  a deer's start on its own heading (and up to half as long again)
   Flight_Max_S  : constant := 30.0;
   Flight_Slow   : constant := 2.0;   --  m/s: the least a deer ahead of its place runs on at
   Keep_Gain     : constant := 1.0;   --  m/s faster for each metre it is behind its place
   Arrive_M      : constant := 2.5;   --  this near its place, the node stopped, its flight is over
   Trail_M       : constant := 8.0;
   Trail_Ahead_M : constant := 3.0;
   Close_M       : constant := 8.0;
   Settle_S      : constant := 3.0;   --  a herd is not startled within this long of the last time
   Turn_Again_S  : constant := 1.5;   --  nor, in flight, turned again within this long
   Turn_Rate     : constant := 2.5;   --  rad/s
   Flight_Turn   : constant := 4.5;
   Deer_Wade_B   : constant := 0;     --  rows of water (quarter metres)
   Flight_Wade_B : constant := 1;
   Herd_Budget   : constant := 40_000;   --  floors a herd's dry way is searched for over, at most

   procedure Set_Scatter (On : Boolean);
   function Scatter return Boolean;
   --  The herds as they were (see above).  Off unless set; saved.

   type Person is record
      P        : Vec3;
      Stalking : Boolean := False;
   end record;
   type People is array (Positive range <>) of Person;

   procedure Reset;   --  no herds at all

   procedure Found (Stake : Vec3; Seed : Castle.Hash.U64);
   --  A colony was founded at Stake: herds are placed round it on the next
   --  Step (when its ground is in), on walkable ground 30 to 55 m off.

   procedure Step (Dt : Float; Hours : Long_Float; Near : People);
   --  One step of the colony's clock.  Near: everyone who might startle
   --  the deer.  Hours: the game clock (seasons, ages).

   procedure Kill (K : Positive);
   --  Deer K is shot: it is gone from its herd (Castle.Colony keeps the
   --  carcass).

   procedure Scare (Aimed_At, From : Vec3);
   --  Danger at Aimed_At (an arrow loosed), from From (the hunter): the herd
   --  of the deer nearest Aimed_At, within Fear_M, panics away from From.

   ------------------------------------------------------- what there is

   function Herd_Count return Natural;
   function Node (H : Positive) return Vec3;
   function In_Herd (H : Positive) return Natural;
   function Panicked (H : Positive) return Boolean;   --  any of its deer still in panic

   function Deer_Slots return Natural;                --  K in 1 .. Deer_Slots for the ones below
   function Alive (K : Positive) return Boolean;
   function Herd_Of (K : Positive) return Natural;
   function Class_Of (K : Positive) return Castle.Deer.Class;
   function Where (K : Positive; Blend : Float := 1.0) return Vec3;
   --  The ground point under it; Blend: how far from the last step to this
   --  (Castle.Colony.Blend), to draw between steps.
   function Doing (K : Positive) return Castle.Deer.Standing_Mode;   --  when it stands
   function In_Panic (K : Positive) return Boolean;
   function Seed_Of (K : Positive) return Castle.Hash.U64;

   ------------------------------------------------------- saves

   type Bytes is array (Natural range <>) of Interfaces.Unsigned_8;
   function Save return Bytes;
   procedure Load (B : Bytes; Ok : out Boolean);

end Castle.Herds;
