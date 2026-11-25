with Interfaces;
with Castle.Blocks;
with Castle.Water;
with Castle.World_Blocks;
with Castle.Math; use Castle.Math;

--  Where people can walk and how long it takes them: the colony's map of
--  the ground, and routes planned on it.
--
--  The map is kept in cells of 0.5 m, 2 x 2 block columns: about a body's
--  width, so a cell a serf can stand in has room for it, a 1 m door always
--  holds one, and a wall, a trunk or a post closes the cells it stands in.
--  A cell has a floor for each level a serf can stand on there, up to four
--  (the ground, a bridge's deck over the river, a tunnel under the hill, an
--  upper storey), each with its height, the room over it, the water on it
--  and how fast it is to walk on.  They are read from the column stretches
--  the water simulation keeps (Castle.Water) and from the blocks, a stack
--  (8 m) at a time, when a route first needs the stack and again whenever
--  its ground has changed (Castle.World_Blocks.Ground_Version).
--
--  A route is planned on the map, not felt out on the ground: A* over the
--  floors, the cost of a step the time it takes (the surface, the water,
--  the climb), so a footpath is taken where it saves time and a river is
--  crossed at a bridge or a ford.  A step goes up at most 0.5 m and down at
--  most 1 m, with 1.75 m of room overhead, and never cuts a corner past a
--  wall.  The cells found are then pulled straight wherever a straight line
--  is no slower, and what a serf follows is a line of points with the time
--  each is reached.
--
--  The search's estimate of the time left is the straight line at a
--  footpath's speed, times Heuristic_Weight: a little over, so the search
--  heads for the goal instead of fanning out over open country (on seed 1,
--  2.4 times quicker for routes 0.3 % slower; any route is at most that
--  factor slower than the quickest).  Above about 1.3 a footpath worth a
--  short detour is no longer taken, so it stays at 1.15.
--
--  Each stack's floors are also labelled by the pieces of ground they make
--  (floors joined by a step either way), and the pieces are linked across
--  stack edges.  Before searching, the pieces round the start and the goal
--  are looked over: when one of the two is wholly known (it touches no
--  stack that is loaded but not yet mapped) and doesn't hold the other, the
--  goal can't be reached, and the route goes straight to the floor nearest
--  it that can be, instead of searching everything there is first.  The
--  labels only ever prove a goal out of reach (a 1 m drop is a way down
--  only), so a goal they can't rule out is searched for as before.  Main
--  thread only.
package Castle.Nav is

   Cell_B          : constant := 2;      --  blocks to a cell's edge
   Cell_M          : constant := 0.5;
   Cells_Per_Stack : constant := 16;
   Cells_XY        : constant := 4_096;  --  across the world
   Head_B          : constant := 7;      --  room a serf needs overhead (1.75 m)
   Climb_B         : constant := 2;      --  highest step up (0.5 m)
   Drop_B          : constant := 4;      --  deepest step down (1 m)
   Wade_B          : constant := 2;      --  deepest water waded (0.5 m)
   Max_Floors      : constant := 4;

   Walk_Speed      : constant := 1.3;    --  m/s on grass or dirt
   Best_Speed      : constant := 1.15;   --  the quickest surface (a footpath, planks), times Walk_Speed
   Climb_S         : constant := 2.5;    --  seconds a metre climbed, on top of the way across
   Descend_S       : constant := 0.5;    --  seconds a metre stepped down
   Drop_S          : constant := 0.6;    --  more for a step down deeper than a step up can be
   Heuristic_Weight : constant := 1.15;  --  the estimate of the time left, inflated (see above)

   ------------------------------------------------------- the world it reads

   type Column_Reader is access procedure (Bx, By : Integer; C : out Castle.Water.Column; Known : out Boolean);
   type Block_Reader is access function (Bx, By, Bz : Integer) return Castle.Blocks.Material;
   type Version_Reader is access function (CX, CY : Integer) return Natural;
   --  A stack's ground version: changes whenever its blocks do; 0 while it
   --  is not loaded (no one walks there).

   type Changes_Reader is access procedure (CX, CY : Integer; Since : Natural; N : out Natural;
                                            Cols : out Castle.World_Blocks.Changed_List;
                                            All_Of_It : out Boolean);
   --  Which block columns of a stack have changed since its version was
   --  Since (Castle.World_Blocks.Changes_Since), or that it cannot say.

   procedure Set_Source (Columns : Column_Reader; Blocks : Block_Reader; Version : Version_Reader;
                         Changes : Changes_Reader := null);
   --  The game: Castle.World_Blocks.  Tests: a made-up world.  Forgets the map.
   --
   --  With Changes, a stack whose ground has changed is mended: only the
   --  cells over the changed columns are read again (a cell is read from
   --  its own four columns and nothing else), and its pieces of ground are
   --  worked out again only if a cell came out otherwise.  An edit used to
   --  cost the stack's 256 cells and a labelling; it costs one cell, and
   --  most often no labelling (a berry picked changes no floor).  The map
   --  is the same either way: in a build with assertions on, every mended
   --  stack is read whole beside it and compared.  Without Changes (null),
   --  or with Mending off, a changed stack is read whole, as it always was.

   Map_On_The_Way : Boolean := True;
   --  Looking over the pieces of ground for whether a goal can be reached,
   --  a stack that is loaded but not mapped as it is now is mapped (or
   --  mended) then and there.  It used to leave the question open, and an
   --  open question is a search of everything in reach: a gatherer making
   --  for fruit up a tree, with an edit made anywhere in a stack the ground
   --  about it touches since that stack was last looked at, cost 55 ms.
   --  Off: as it was (for measuring).

   Mending : Boolean := True;
   --  Off: every changed stack read whole (for measuring, and for checks
   --  that compare the two).

   Prove_Dry : Boolean := False;
   --  Checks and measuring only (colony_run --prove-dry; slow).  On: every
   --  plan of dry going (Wade under Wade_B) whose pieces of ground say out
   --  of reach is then searched for with the pieces off and no budget, over
   --  all the ground it may go on, and Program_Error is raised if that way
   --  is found (Totals.Proved counts those borne out); and a stack's pieces
   --  for dry going are worked out again beside the kept ones each time
   --  they are used, and must be the same.

   procedure Forget;                          --  every stack's floors
   procedure Forget_Stack (CX, CY : Integer);  --  one stack's (it was unloaded)

   ------------------------------------------------------- the map

   type Floor is record
      Z     : Integer := 0;       --  the row the feet stand on (metres: Z / 4)
      Head  : Natural := 0;       --  open rows over it, up to 255
      Water : Natural := 0;       --  rows of water over it
      Speed : Float   := 0.0;     --  times Walk_Speed; 0: not walked on (a roof, deep water)
   end record;
   type Floor_List is array (1 .. Max_Floors) of Floor;

   procedure Floors_At (Cx, Cy : Integer; N : out Natural; F : out Floor_List);
   --  Cell (Cx, Cy): metres (Cx / 2, Cy / 2) to ((Cx + 1) / 2, (Cy + 1) / 2).
   --  Highest first.

   function Surface_Z (X, Y : Float) return Float;
   --  The height of the highest floor a serf can stand on at (X, Y), metres;
   --  -1.0 if there is none (not loaded, a wall).

   function Ground_Speed (M : Castle.Blocks.Material) return Float;   --  standing on it
   function Brush_Speed (M : Castle.Blocks.Material) return Float;    --  wading through it at the feet

   --  Ground people keep off (a building drawn where it does not stand:
   --  Castle.Colony.Set_Keep_Off): a cell whose middle lies within a list's
   --  four-cornered piece of ground, and in neither of its two boxes, is
   --  walked at Kept_Slow of what its ground gives.  So a way round is taken
   --  wherever there is one, and whoever has business there still gets
   --  there: nothing is shut, and the pieces of ground are what they were.
   --  Set_Kept reads again the stacks the list lies in and those the list
   --  before it lay in; a route planned before goes on as it was planned.
   Max_Kept  : constant := 64;
   Kept_Slow : constant := 0.1;
   type Kept_Box is record
      X0, Y0, X1, Y1 : Float := 0.0;      --  metres (a box of no size holds nothing)
   end record;
   type Kept_Corners is array (1 .. 4) of Vec3;     --  in order round it, either way; Z is not looked at
   type Kept_Ground is record
      Corner       : Kept_Corners := [others => (0.0, 0.0, 0.0)];
      But_A, But_B : Kept_Box;
   end record;
   type Kept_List is array (Positive range <>) of Kept_Ground;
   procedure Set_Kept (K : Kept_List);
   function Kept_Count return Natural;
   function Kept_At (X, Y : Float) return Boolean;   --  (the cell (X, Y) lies in is kept off)

   --  A building walked where it is drawn (Castle.Colony: the storehouse of
   --  a stockyard laid out along a path at 45 degrees, and since 2026-11-20
   --  a hovel placed turned).  Its blocks stand square to the grid and are
   --  drawn turned (Castle.Render.Set_Turns); the feet go by the drawing.
   --  For each of the list: a cell whose square overlaps one of its Wall
   --  pieces (its walls as drawn, each a four-cornered piece, the doorways
   --  left out) has no floor, unless Slow (a hovel's): then its floors are
   --  Wall_Speed, and a step onto or off one is reckoned at Wall_Pace (a way
   --  round is taken wherever there is one, and nobody is ever shut in or
   --  out: shut, on a hillside the ground made round a hovel as drawn, laid
   --  out when its walls were no walls, held pockets a serf could drop into
   --  and not climb out of; the rule of the ground kept off, which slows and
   --  never shuts); and a straight line is reckoned so too when a way is
   --  straightened (Line), or a way planned round a hovel was straightened
   --  through its wall.  Any other
   --  cell that overlaps Box (where its blocks stand, eaves and all) has one
   --  floor, at row Z, at Speed (beaten yard under a storehouse, turf under a
   --  hovel), whatever blocks stand in it; Whole: only a cell wholly in Box
   --  (a hovel's: a cell partly past its eaves is read from the blocks, as
   --  round any house; made level, a cell half on the bank above a hovel on a
   --  hillside was a pit).  Every other cell is read from the blocks as ever:
   --  within its walls as drawn, off Box, that is its floor as it was laid,
   --  and what is dug or built there counts.
   --  **Box is the one place where the map is not read from the blocks**:
   --  the ground under it has to be level at row Z (the colony makes it so),
   --  nothing else may stand in it, and what is dug or built in it is not
   --  walked by.  Set_Drawn reads again the stacks the list lies in and those
   --  the list before it lay in.
   --  **Doorways** (since the hovels came to be walked so): a cell whose
   --  middle lies in one of a building's Door pieces is neither shut nor
   --  slowed by any wall.  A hovel's doorway is a metre wide, and at 45
   --  degrees a cell spans 0.71 m along the wall: where the doorway fell on
   --  the cells decided whether one cleared both jambs, and at some places
   --  none did (path_check: 50 places).  A Door piece is the doorway less a
   --  little at each jamb, out a little to either side of the wall.  Whoever
   --  goes in keeps to cells whose middles are in it.
   --  **Walls are asked of every building before any box**: a cell in one
   --  building's box that touches another's wall as drawn is shut (or
   --  slowed) by it.
   Max_Drawn       : constant := 64;
   Max_Drawn_Walls : constant := 8;
   Max_Drawn_Doors : constant := 2;
   type Drawn_Walls is array (1 .. Max_Drawn_Walls) of Kept_Corners;
   type Drawn_Doors is array (1 .. Max_Drawn_Doors) of Kept_Corners;
   type Drawn_House is record
      Box    : Kept_Box;
      Wall   : Drawn_Walls := [others => [others => (0.0, 0.0, 0.0)]];
      Walls  : Natural := 0;
      Door   : Drawn_Doors := [others => [others => (0.0, 0.0, 0.0)]];
      Doors  : Natural := 0;
      Z      : Integer := 0;
      Speed  : Float := Best_Speed;
      Whole  : Boolean := False;
      Slow   : Boolean := False;
   end record;
   --  A slowed wall's floors (no ground's pace comes near it: the least is
   --  bog iron among bushes, wading, kept off, 0.007), and what a step onto
   --  or off one is reckoned at: a metre of a hovel's wall costs a way as
   --  much as 100 m of turf, and round the longest hovel is some 20 m.  First
   --  value, his to tune.  (A pace multiplied into the floor's own would not
   --  do it: a step's pace is the mean of its two floors', at a twentieth at
   --  the least, and a way planned through a wall so slowed cost less than
   --  going round.)
   Wall_Speed : constant := 1.0E-6;
   Wall_Pace  : constant := 0.01;
   type Drawn_List is array (Positive range <>) of Drawn_House;
   procedure Set_Drawn (D : Drawn_List);
   function Drawn_Count return Natural;

   ------------------------------------------------------- routes

   Max_Points : constant := 1_024;
   type Route_Point is record
      P : Vec3;                   --  metres; Z the height of the feet
      T : Float := 0.0;           --  seconds from the start, at Walk_Speed
      D : Float := 0.0;           --  metres from the start, along the ground
   end record;
   type Point_Array is array (1 .. Max_Points) of Route_Point;

   type Outcome is (Found, Partial, None);
   --  Partial: the goal can't be reached (or not within the budget); the
   --  route ends where it comes nearest.

   Max_Stamps : constant := 96;
   type Stamp is record
      CX, CY  : Interfaces.Integer_16 := 0;
      Version : Natural := 0;
   end record;
   type Stamp_Array is array (1 .. Max_Stamps) of Stamp;

   type Route is record
      Result   : Outcome := None;
      N        : Natural := 0;            --  points; the first is where it starts
      Pts      : Point_Array;
      Stamps   : Stamp_Array;             --  the stacks it crosses, as they were
      N_Stamps : Natural := 0;
      Overflow : Boolean := False;        --  crosses more stacks than it can note
   end record;

   --  Where a plan may go, and nothing else (what is outside is no ground
   --  to it: not stepped on, not looked over): the stacks any part of which
   --  lies within R metres of (X, Y) (Within_M), or the stacks within Stacks
   --  of stack (SX, SY), counted stack to stack (Within_Stacks: the ground a
   --  colony is kept, Castle.Colony.Set_Ground_Stacks).  Neither: everywhere.
   type Region is record
      X, Y   : Float := 0.0;
      R      : Float := 0.0;
      SX, SY : Integer := 0;
      Stacks : Natural := 0;
   end record;
   Everywhere : constant Region := (X => 0.0, Y => 0.0, R => 0.0, SX => 0, SY => 0, Stacks => 0);
   function Within_M (X, Y, R : Float) return Region is ((X => X, Y => Y, R => R, SX => 0, SY => 0, Stacks => 0));
   function Within_Stacks (SX, SY : Integer; Stacks : Positive) return Region is
     ((X => 0.0, Y => 0.0, R => 0.0, SX => SX, SY => SY, Stacks => Stacks));

   function Plan (From, To : Vec3; Budget : Positive := 300_000; Weight : Float := Heuristic_Weight;
                  Wade : Natural := Wade_B; Within : Region := Everywhere; Refuse : Boolean := False)
                  return Route;
   --  From the floor nearest From to the floor nearest To (each looked for
   --  within 3 m if its own cell can't be stood in).  Budget: floors looked
   --  at, at most.  Weight: 1.0 for the quickest route there is (tests).
   --  Wade: no step is taken onto a floor under more rows of water than
   --  this (a herd's way keeps dry: Castle.Herds).
   --
   --  The pieces of ground asked are those of the plan's own going (John,
   --  2026-11-13, of the herds: "let them know that water blocks them"): a
   --  serf's, who wades, for Wade_B; for less, the pieces that can be gone
   --  over no deeper than Wade rows, worked out for a stack when a plan
   --  first asks and again when its floors have changed.  (They were a
   --  serf's whatever the plan, and a herd's way to a place only wading
   --  reaches was searched for over its whole budget every time.)
   --
   --  Within: the plan keeps to that ground, and a goal its pieces do not
   --  join inside it is out of reach, whatever lies beyond or is not
   --  loaded.  (Everywhere, the pieces answer only when one end's are all
   --  known: ground not loaded leaves the question open.)
   --
   --  Refuse: a goal the pieces show to be out of reach is not made for at
   --  all: no search, no route (None, no points; Last_Stats.Out_Of_Reach).
   --  Otherwise the route ends at the floor nearest the goal that can be
   --  got to.

   function Changed (R : Route) return Boolean;
   --  The ground of a stack the route crosses has changed since it was planned.

   function Still_Good (R : Route; From_Point : Positive) return Boolean;
   --  Every step from point From_Point on can still be walked.

   procedure Restamp (R : in out Route);
   --  Take the stacks' present ground as the route's (after Still_Good).

   function Total_Time (R : Route) return Float is (if R.N > 0 then R.Pts (R.N).T else 0.0);
   function Length (R : Route) return Float is (if R.N > 0 then R.Pts (R.N).D else 0.0);

   type Stats is record
      Looked_At : Natural := 0;   --  floors taken from the open list
      Seconds   : Float   := 0.0; --  wall time of the last Plan
      Stacks    : Natural := 0;   --  stacks whose floors were (re)built during it
      Out_Of_Reach : Boolean := False;   --  the labels showed the goal can't be reached
      Cut_Short : Boolean := False;      --  the search stopped (budget, or room) with ground still to look at
   end record;
   function Last_Stats return Stats;

   --  What the map and the routes have cost since the start (or Reset_Totals):
   --  for measuring (colony_run --nav-stats), never for deciding anything.
   type Totals_Rec is record
      Plans         : Natural := 0;      --  calls of Plan
      Plan_Floors   : Long_Integer := 0; --  floors they took from the open list
      Plan_Seconds  : Long_Float := 0.0; --  wall time in them
      Longest_Plan  : Float := 0.0;      --  the slowest, seconds
      Slow_Plans    : Natural := 0;      --  those that took 5 ms or more,
      Slow_Seconds  : Long_Float := 0.0; --  and the time in them
      Spent_Plans   : Natural := 0;      --  those that ran out of budget (or of room) before an end
      Short_Plans   : Natural := 0;      --  those that ended short of the goal (Partial or None)
      Unreached     : Natural := 0;      --  those the pieces of ground showed out of reach, with no search
      Refused       : Natural := 0;      --  of those, the ones not made for at all (Refuse),
      Refused_Seconds : Long_Float := 0.0;   --  and the wall time in them
      Proved        : Natural := 0;      --  with Prove_Dry: answers of out of reach a whole search bore out,
      Unproved      : Natural := 0;      --  and those it could not go all the way through (too much ground)
      Dry_Labellings : Natural := 0;     --  times a stack's pieces for dry going were worked out
      Remembered    : Natural := 0;      --  those answered from the memory of one that ran out of budget
      Stacks_Built  : Natural := 0;      --  stacks whose floors were read anew, whole
      Stacks_Mended : Natural := 0;      --  stacks whose floors were read anew only where the ground changed
      Cells_Built   : Long_Integer := 0; --  cells read, either way
      Labellings    : Natural := 0;      --  times a stack's pieces of ground were worked out
      Map_Seconds   : Long_Float := 0.0; --  wall time reading and labelling, whole or mended
      Rewalks       : Natural := 0;      --  calls of Still_Good
      Rewalk_Steps  : Long_Integer := 0; --  route legs they walked
   end record;
   function Totals return Totals_Rec;
   procedure Reset_Totals;

   --  What the pieces of ground said of a plan before it was searched (for
   --  measuring: why a plan that ran out of budget was searched at all).
   type Label_Answer is
     (Not_Asked,     --  the labels off, nowhere to stand at the goal, or start and goal one floor
      Stale,         --  the start's stack or the goal's not mapped as it is now
      No_Piece,      --  the start's floor or the goal's is of no piece of ground
      Same_Piece,    --  one piece: it can be got to (by the plan's own going: a serf's, or dry)
      Met,           --  the start's pieces join the goal's: it can be got to (by the plan's own going)
      Unknown,       --  neither end's pieces all known (open, or too many)
      Out_Of_Reach); --  known out of reach: headed for the nearest floor instead, or refused
   type Answer_Counts is array (Label_Answer) of Natural;
   function Spent_By return Answer_Counts;
   --  The plans that ran out of budget so far, by that answer.

   --  A plan that ran out of budget (for measuring: colony_run --nav-log).
   type Spent_Plan is record
      From, To  : Vec3 := (0.0, 0.0, 0.0);
      Budget    : Natural := 0;
      Wade      : Natural := 0;            --  rows of water it might go through (less than Wade_B: a herd's dry way)
      Answer    : Label_Answer := Not_Asked;
      Result    : Outcome := None;
      Reached_M : Float := 0.0;            --  how far from To the route ended
      Seconds   : Float := 0.0;
   end record;
   type Spent_Hook is access procedure (P : Spent_Plan);
   procedure On_Spent (Hook : Spent_Hook);
   --  Called for each such plan from now on (null: none).  Measuring only.

   --  The plans that took longest so far, slowest first (for measuring).
   type Slow_Plan is record
      From, To  : Vec3 := (0.0, 0.0, 0.0);
      Seconds   : Float := 0.0;
      Looked_At : Natural := 0;
      Result    : Outcome := None;
      Reached_M : Float := 0.0;      --  how far from To the route ended
   end record;
   type Slow_List is array (1 .. 12) of Slow_Plan;
   function Slowest return Slow_List;

   --  A plan that ran out of budget is remembered (2026-11-13: a herd
   --  frightened by a serf standing by it, with no dry way out, asked the
   --  same way again every three seconds for two days, forty thousand
   --  floors each time): its route, by where it was from and to, its budget,
   --  weight and wade, and by the version of every stack in a box round
   --  everything it read (its cells and the pieces of ground it went by, a
   --  stack more each way).  One the pieces of ground called out of reach
   --  is not remembered: the floor it made for instead was picked from
   --  stacks far round its goal.  Asked again while none of that ground has
   --  moved, it is answered from memory: the same route a search would give.
   --  Kept only to save work: it changes no run, and this switch proves it
   --  (colony_run --no-memos; tools/stress.sh runs the crowd both ways).
   procedure Set_Spent_Memos (On : Boolean);
   function Spent_Memos return Boolean;

   procedure Use_Labels (On : Boolean);
   --  Tests: plan without the pieces of ground (search everything, as
   --  before), to check the labels against it.  On by default.

end Castle.Nav;
