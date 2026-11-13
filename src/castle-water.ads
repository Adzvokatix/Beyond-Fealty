with Interfaces;
with Castle.Chunks; use Castle.Chunks;
with Castle.Dims;   use Castle.Dims;

--  Live water on block columns: a heightfield of "virtual pipes", with
--  more than one stretch of water to a column.
--
--  A stretch is a run of open rows in a column, lying on a solid block and
--  under a solid block (or open sky).  Water lies in it from its floor up
--  and never rises above its ceiling: a river on its bed is one stretch, a
--  tunnel under the bed another.  Water passes between neighbouring columns
--  wherever two of their stretches overlap; each such opening is a pipe
--  whose flow keeps part of its momentum from step to step, so water runs,
--  sloshes and settles flat.  Depths are integers (Unit to a block), and
--  every unit that leaves one stretch arrives in another or is entered in
--  the ledger, so water is never made or lost.
--
--  Only awake stacks (8 x 8 m) are simulated; everything else rests, and is
--  a fixed-level edge: water runs in from it and out to it at the level it
--  holds, so a woken stretch of river keeps flowing.  An awake stack sleeps
--  when nothing visible has moved in it for a while; water running onto
--  resting dry ground wakes that ground.  Main thread, Tick at 10 Hz; the
--  order work is done in cannot change the outcome.
--
--  Source water (the generated rivers, streams and lakes) has a level it
--  holds at rest, and what is simulated of it is how far it stands from
--  that level.  Asleep it holds it, and gives what it has to whatever
--  opens beside it.  Awake it is water like any other, but for two things.
--  Between two columns of source water the flow goes by the difference in
--  how far each has dropped, not by their heights: a stream lies down its
--  hill as it was made, however much of it is awake, and the water higher
--  up does not come down on the water below.  And a column that has
--  dropped is filled again from what the river carries or the lake holds
--  (Recharge).  So where a bank is opened the water beside the cut drops
--  and runs out through it, the drop fading with distance into the water
--  still at its level; where the drop reaches resting source water, that
--  wakes too; and closed again, the water comes back to its level and
--  sleeps.
--
--  The world as it was made holds its water.  Where source water stands
--  over lower ground beside it in the generated world (the lip of a fall,
--  the dry rock of a fall's face), nothing runs out: source water goes
--  out to other ground only across a face one of whose two columns has
--  been dug or built in.  (Without this every fall, once woken, emptied
--  the stream above it down its own face.)
package Castle.Water is

   Unit         : constant := 65_536;         --  depth units to a block (0.25 m)
   Tick_Seconds : constant := 0.1;
   Max_Stretch  : constant := 4;              --  to a column, highest first
   Max_Awake    : constant := 48;             --  stacks simulated at once, at most

   --  Source water (first values).
   Refill_Seconds : constant := 2.0;          --  a dropped source column regains its level at about this pace
   Wake_Drop      : constant := Unit / 8;     --  drawn this far below resting source water (3 cm), that wakes
   Settle_Within  : constant := Unit / 32;    --  going to sleep this close to its level (8 mm), it is put on it

   --  Water that runs on without changing sleeps too (first values).  When
   --  water has come in from source water over Steady_Seconds (it is a flow
   --  that is fed, not a pond levelling), and for that long no awake stack
   --  with water on the move has had a
   --  column deeper than a sheet stand more than Steady_Within from where
   --  it stood, nor gained or lost more than Steady_Sum of water in all,
   --  the flow is established: every awake stack sleeps as it lies, and
   --  those still running are kept as running water (their currents drawn,
   --  nothing dried off them, since what feeds them still does).  They wake
   --  together, as any resting water does, when something beside them
   --  changes.  Water tumbling down a steep slope comes in pulses and never
   --  stands that still: it stays awake.
   Steady_Seconds : constant := 10.0;
   Steady_Within  : constant := Unit / 32;    --  8 mm
   Steady_Sum     : constant := Unit;         --  a block of water in one column (16 litres) to a stack

   type Stretch is record
      Floor : Integer := 0;                   --  the first open row (on the solid below)
      Ceil  : Integer := 0;                   --  the first solid row above (Height_B: open sky)
      Water : Integer := 0;                   --  ground: water blocks; simulation, saves: depth (units)
   end record;
   type Stretch_Array is array (1 .. Max_Stretch) of Stretch;
   type Column is record
      N       : Natural := 0;
      S       : Stretch_Array;
      Flowing : Boolean := False;              --  made as source water (river, stream or lake)
      Rest    : Integer := 0;                  --  the level it holds at rest, in units from the bottom of
                                               --  the world; 0 from the ground: it rests where it lies
      Touched : Boolean := False;              --  simulation: dug or built in since it was made
   end record;
   type Stack_Columns is array (0 .. 31, 0 .. 31) of Column;

   --  Where water lies as the blocks have it (Water in blocks).  Known
   --  False: not loaded.  The game reads its blocks; tests make a world.
   type Ground_Source is access procedure (Bx, By : Integer; C : out Column; Known : out Boolean);
   procedure Set_Ground (Source : Ground_Source);

   procedure Wake (CX, CY : Integer);
   --  Simulate the stack from now on (taking its water from the ground the first time).

   procedure About_To_Change (Bx, By : Integer);
   --  The column's blocks are about to change (the ground source still has
   --  it as it was): the stacks round it wake, so the simulation has seen
   --  the ground as it lay before the edit.

   procedure Ground_Changed (Bx, By : Integer);
   --  The column's blocks changed (the ground source has it already): its
   --  stretches are read again and its water kept in the rows still open
   --  (water on a dug-out floor falls into what lies below, water in rows
   --  a placed block took is gone), and the stacks round it wake.

   procedure Tick;

   --  Drawing.  A stack's view: its columns and the ring round it, with the
   --  water blocks the simulation has for each stretch (where it has any).
   type View_Column is record
      Sim : Boolean := False;
      C   : Column;                            --  Water: blocks to draw
   end record;
   type View_Grid is array (-1 .. 32, -1 .. 32) of View_Column;
   type View_Access is access View_Grid;
   function View_Of (CX, CY : Integer) return View_Access;   --  null: no live water touches it
   procedure Free (V : in out View_Access);
   procedure Apply (V : View_Grid; Work : in out Stack_Work);
   --  Worker: lay the simulation's water into a freshly built stack.

   --  Where each column's water lies after a build (Water in blocks),
   --  kept small: rows fit in 16 bits.
   type Short_Stretch is record
      Floor, Ceil, Water : Interfaces.Integer_16 := 0;
   end record;
   type Short_Stretches is array (1 .. Max_Stretch) of Short_Stretch;
   type Short_Column is record
      N       : Interfaces.Unsigned_8 := 0;
      Flowing : Boolean := False;
      Rest    : Interfaces.Integer_32 := 0;    --  units: the level of the generated water
      S       : Short_Stretches;
   end record;
   type Ground_Summary is array (0 .. 31, 0 .. 31) of Short_Column;
   type Summary_Access is access Ground_Summary;
   function To_Column (S : Short_Column) return Column;
   function To_Short (C : Column) return Short_Column;
   procedure Summarize (Work : Stack_Work; S : out Ground_Summary);
   procedure Free (S : in out Summary_Access);

   --  The stretches of rows Bottom .. Top of a column, highest first (rows
   --  above Top are open to the sky, rows below Bottom solid).
   generic
      with function Solid (Z : Integer) return Boolean;
      with function Wet (Z : Integer) return Boolean;
   procedure Scan (Top, Bottom : Integer; C : out Column);

   type Stack_Ref is record
      CX, CY : Integer := 0;
   end record;
   type Stack_List is array (Positive range <>) of Stack_Ref;
   function Take_Changed return Stack_List;
   function Version (CX, CY : Integer) return Natural;

   --  Saves: every simulated stack (Water in units), in a fixed order.
   procedure Each_Stack (Visit : not null access procedure (CX, CY : Integer; Awake : Boolean;
                                                            C : Stack_Columns));
   procedure Restore (CX, CY : Integer; Awake : Boolean; C : Stack_Columns);

   --  The ledger: Total + Went_Out - Came_In never changes.
   function Total return Long_Long_Integer;
   function Came_In return Long_Long_Integer;
   function Went_Out return Long_Long_Integer;
   function Awake_Count return Natural;
   function Capped return Boolean;            --  a stack was left asleep for Max_Awake
   function Simulated_Count return Natural;
   function Is_Awake (CX, CY : Integer) return Boolean;
   function Is_Running (CX, CY : Integer) return Boolean;        --  asleep with its flow established
   function Depth (Bx, By : Integer) return Integer;             --  all its stretches; -1: not simulated

   --  The open-sky water of a simulated stack, for the renderer: each
   --  column's top stretch (its floor and water level, in blocks, rows
   --  from the bottom of the world) and the current through it in m/s.
   --  Only the top stretch is drawn this way; water in tunnels and under
   --  overhangs is still laid as blocks and meshed.
   type Surface_Cell is record
      Floor, Level : Float := Float (Height_B);
      Vx, Vy       : Float := 0.0;
      Source       : Boolean := False;        --  source water: the current is what it adds to the river's own
   end record;
   type Surface_Grid is array (0 .. 31, 0 .. 31) of Surface_Cell;
   procedure Surface (CX, CY : Integer; G : out Surface_Grid; Have : out Boolean);

   --  What leaves a column's open-sky water through each of its four
   --  faces (east, west, north, south), for drawing falls: how fast it
   --  goes (m/s: the share of the water over the sill that moves on a
   --  step, a column a step being 10 m/s) and how deep it stands over the
   --  sill it leaves by (blocks).  Nothing leaving: 0 and 0; and nothing
   --  between source water and source water (a stream's own fall has no
   --  simulated flow: woken, what moves down it is only how far each column
   --  has dropped from its level).  Of a stack
   --  awake or asleep with its flow established; the simulation's own
   --  flows, read and not changed.  (Surface's Vx and Vy are the net of
   --  opposite faces, held to 3 m/s for the ripples, and nothing for a
   --  column with more than one stretch.)
   type Outflow is record
      Speed, Over : Float := 0.0;
   end record;
   type Outflow_Faces is array (0 .. 3) of Outflow;
   type Outflow_Grid is array (0 .. 31, 0 .. 31) of Outflow_Faces;
   procedure Outflows (CX, CY : Integer; G : out Outflow_Grid; Have : out Boolean);

   --  Source water.  The generated rivers and lakes are where water comes
   --  from, and they give only what they have.
   --
   --  A resting river column gives at most its share of the river's
   --  discharge a step (Supply: units a step through one face); cutting
   --  into a river draws what it carries, no more.  Water may always run
   --  back into it.
   --
   --  An awake source column below its level is filled again, a share of
   --  what it lacks each step (all of it over about Refill_Seconds) and at
   --  most Recharge units a step: what a river brings past, what a lake
   --  has behind it.  One above its level runs off as fast.  With no
   --  Recharge set (the tests' exact books) neither happens, and awake
   --  source water is fed only from the source water still at rest.
   type Supply_Source is access function (Bx, By : Integer) return Natural;
   procedure Set_Supply (Source : Supply_Source);
   procedure Set_Recharge (Source : Supply_Source);
   function Rest_Level (Bx, By : Integer) return Integer;
   --  Units; 0: no source water there (none made, built over, or not simulated).
   function Drop (Bx, By : Integer) return Integer;
   --  How far source water stands below its level, in units (negative: over it); 0: none there.

   --  Drying: water that nothing feeds goes in the end.  Every simulated
   --  column loses what its floor soaks up and, under the open sky, what
   --  evaporates (water still joined to a river or a lake loses it too,
   --  and is fed again).  Seep gives the floor's rate in mm a game hour;
   --  Dry_Out takes the game hours since the last call.  Stacks at rest
   --  whose water changed are listed for redrawing.
   type Seep_Source is access function (Bx, By, Row : Integer) return Float;
   procedure Set_Seep (Source : Seep_Source);
   procedure Dry_Out (Hours, Evaporation_Mm, Seep_Scale : Float);
   procedure Pour (Bx, By : Integer; Units : Natural);   --  tests: water into a column's top stretch (wakes it)
   function Take_Dried return Stack_List;
   function Dried return Long_Long_Integer;     --  units gone into the air and the ground

   --  Water let off a source runs out in the end.  A column that is not
   --  source water keeps 1/256 of what it passes on, and a thin sheet on
   --  the move (under 1/16 m) soaks away at about 1 cm a second.  Water let
   --  out of a river or a lake spreads round the breach and stops there, or
   --  runs some tens of metres down a channel dug for it, and never floods a
   --  valley; a source gives at most its supply a face, so how far depends
   --  on what it carries.  Still water keeps its own (it passes nothing on)
   --  and dries only as Dry_Out says.  Rivers and lakes, woken or at rest,
   --  keep theirs.  Off (the default) water is kept, for the tests' exact
   --  books; what runs out is counted in Dried.
   procedure Set_Leak (On : Boolean);
   function Is_Simulated (CX, CY : Integer) return Boolean;
   function Awake_List return Stack_List;
   function Depth_At (Bx, By, Row : Integer) return Integer;     --  the stretch holding Row; -1: none
   procedure Reset;

end Castle.Water;
