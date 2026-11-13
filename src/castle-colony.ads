with Interfaces;
with Castle.Blocks;
with Castle.Math;   use Castle.Math;
with Castle.Bodies;
with Castle.Hash;
with Castle.Nav;
with Castle.Deer;

--  The colony: the band, what each of them is doing and carrying, the
--  homestake, the paths, the stockpiles and the bushes they pick, on a
--  clock of its own.  It decides; Castle.Serfs only shows it.
--
--  The clock runs in fixed steps, Tick_Hz to a second at normal speed (the
--  game passes real seconds times its speed, nothing when paused), so the
--  same start gives the same colony whatever the frame rate.  Each member
--  is a small machine: think, walk a route (Castle.Nav), work, carry,
--  store.  What two of them could both go for (a bush, room in a stockpile
--  cell) is reserved by the first, and a goal that can't be reached is left
--  alone for a while instead of being tried every step.
--
--  The world is read and changed through the game (Set_World): picking a
--  bush, laying a path and raising the stake are block edits like the
--  player's own, so they are saved, drawn and walked on like any other.
--
--  The player says where (the stake, paths, stockpiles), the jobs say who:
--  a gatherer looks for the ripe bush nearest it, weighed toward the stake
--  (the stake's priority gradient), picks it into its basket, and carries
--  a full basket (or what it has, when nothing ripe is in reach) to the
--  nearest stockpile cell with room.  Picked bushes grow their berries back
--  in Regrow_Days, but not in winter.  Main thread only.
package Castle.Colony is

   ------------------------------------------------------- the world it works in

   type Block_Reader is access function (Bx, By, Bz : Integer) return Castle.Blocks.Block;
   type Block_Writer is access procedure (Bx, By, Bz : Integer; B : Castle.Blocks.Block);
   type Version_Reader is access function (CX, CY : Integer) return Natural;   --  0: not loaded

   procedure Set_World (Read : Block_Reader; Write : Block_Writer; Version : Version_Reader);
   --  The routes come from Castle.Nav, whose source is set apart.

   --  Trees come from the generator (in the game, Castle.Flora): one at
   --  most to each Tree_Cell_B x Tree_Cell_B cell of block columns.  The
   --  colony asks for the trees whose trunks stand in the stacks it looks
   --  through, and for a tree's own blocks when it is felled.
   type Tree_Kind is (Broadleaf, Conifer, Apple);
   type Tree_Info is record
      Valid   : Boolean   := False;
      Kind    : Tree_Kind := Broadleaf;
      Bx, By  : Integer   := 0;   --  the trunk's south-west column (blocks)
      Bz      : Integer   := 0;   --  its first block above the ground
      Trunk_W : Integer   := 1;   --  blocks square
      Trunk_H : Integer   := 0;   --  blocks
   end record;
   Tree_Cell_B : constant := 16;   --  Castle.Flora.Tree_Cell (the game checks they agree)
   type Tree_Finder is access function (I, J : Integer) return Tree_Info;
   type Tree_Shaper is access procedure
     (I, J  : Integer;
      Visit : not null access procedure (Bx, By, Bz : Integer; M : Castle.Blocks.Material));
   --  Every block the tree of cell (I, J) was generated with (trunk,
   --  branches, crown), whatever stands there now.
   procedure Set_Trees (Find : Tree_Finder; Shape : Tree_Shaper);

   ------------------------------------------------------- the clock

   Tick_Hz : constant := 20;
   Tick_S  : constant := 1.0 / Tick_Hz;

   procedure Advance (Seconds : Float; Hours : Long_Float);
   --  Seconds of colony time (real seconds times the game's speed) are run
   --  as whole steps, the rest kept for next time.  Hours: the game clock
   --  now, for what grows back by the day.
   function Ticks return Natural;
   function Blend return Float;   --  how far into the next step (0 .. 1), to draw between steps

   ------------------------------------------------------- things carried and stored

   type Item_Kind is (Nothing, Berries, Wood, Stone, Water, Straw, Meat, Hide, Carcass,
                      Vegetables, Apples, Sticks, Grain, Earth);
   --  Berries are counted in handfuls, wood in logs (a metre long, carried
   --  one at a time on the shoulder), straw in sheaves (a block of tall
   --  grass each), stone in stones (a block of boulder each, carried in the
   --  porter's sack), meat in joints and hides one a deer.  Water is not
   --  fetched yet: it waits for a use and for barrels to keep it in.  A
   --  carcass is carried (across the shoulders), never stored: it is
   --  butchered at the stockpile, into meat and a hide.  Vegetables are
   --  wild roots and greens, one plant pulled each; apples are picked one by
   --  one.  Sticks are an armful of dead wood picked up under a tree, for the
   --  fire: never stored, carried straight to it.  Grain is counted in
   --  handfuls; nobody gathers it for itself: it comes in with the straw
   --  (see Grain_Per_Plant).  Earth is counted in blocks (a basketful is
   --  Carry_Limit of them): what is dug off ground being levelled; it is
   --  heaped in a stockpile, and nobody asks for it but a hollow to fill.
   --  (Saved by position: new kinds go on the end.)

   Carry_Limit : constant array (Item_Kind) of Natural :=
     [Nothing => 0, Berries => 30, Wood => 1, Stone => 4, Water => 2, Straw => 6, Meat => 4, Hide => 2,
      Carcass => 1, Vegetables => 12, Apples => 20, Sticks => 1, Grain => 30, Earth => 16];
   Cell_Limit : constant array (Item_Kind) of Natural :=
     [Nothing => 0, Berries => 120, Wood => 20, Stone => 40, Water => 10, Straw => 40, Meat => 20, Hide => 20,
      Carcass => 0, Vegetables => 60, Apples => 80, Sticks => 0, Grain => 120, Earth => 64];

   function Name (K : Item_Kind) return String;   --  "berries"

   ------------------------------------------------------- the homestake

   procedure Place_Stake (Ground : Vec3; Band_Size : Positive; Seed : Castle.Hash.U64);
   --  Ground: a point on the ground (metres).  Raises the stake there (a
   --  post 1.75 m tall) and the band arrives round it, every one of them
   --  unassigned.  Once per colony.
   function Has_Stake return Boolean;
   function Stake return Vec3;            --  the foot of the post

   ------------------------------------------------------- the band

   Max_Members : constant := 48;
   type Job_Kind is (Unassigned, Gatherer, Forester, Hunter, Porter, Cook);
   --  Gatherers pick berries; a forester fells a tree and carries every
   --  log of it home before felling the next (its logs are its own: no one
   --  else touches them); porters fetch straw first (tall grass cut, for
   --  the thatch) up to its reserve, then stone (prised off boulders) as it
   --  is wanted, and never carry wood; hunters hunt deer (below); the cook
   --  keeps the camp (below).
   type Act is (Standing, Walking, Picking, Putting_Down, Chopping, Sneaking, Aiming, Eating, Sleeping,
                Stirring, Eating_Seated, Dead);
   --  what the body is doing (Eating_Seated: on a seat log at the fire)

   --  Who directs whom.  Everyone who acts on the colony is an actor: the
   --  player, or a member of the band (the player's own character will be
   --  one of those).  Each member records who delegated its work: the actor
   --  who gave it its job, or no one, for the unassigned and for a job it
   --  took up on its own (the band's first cook).  Nothing reads it yet: it
   --  is there for the trades whose holders direct helpers, and for whom a
   --  person answers to.  Delegation runs only downward.
   subtype Actor is Integer range -1 .. Max_Members;
   The_Player : constant Actor := -1;
   No_One     : constant Actor := 0;      --  1 .. Max_Members: that member

   function Members return Natural;
   function Genome_Of (I : Positive) return Castle.Bodies.Genome;
   function Name_Of (I : Positive) return String;
   function Job_Of (I : Positive) return Job_Kind;
   procedure Set_Job (I : Positive; J : Job_Kind; By : Actor := The_Player);
   --  By: who gives it the job (its director from now on; no one, for Unassigned).
   function Director_Of (I : Positive) return Actor;
   function Where (I : Positive) return Vec3;          --  the feet, between steps (Blend)
   function Doing (I : Positive) return Act;
   function Work_Spot (I : Positive) return Vec3;      --  where the hands go, picking or putting down
   function Carrying (I : Positive) return Item_Kind;
   function Carried (I : Positive) return Natural;
   function Status (I : Positive) return String;       --  "picking berries", "taking 30 berries to the stockpile"

   type Route_View is access constant Castle.Nav.Route;
   function Route_Of (I : Positive) return Route_View;
   function Leg_Of (I : Positive) return Positive;     --  walking between route points Leg and Leg + 1

   ------------------------------------------------------- paths

   --  The player plans a path; the band lays it (John, 2026-11-10: "the
   --  path should work the same way, the player plans it the serfs build
   --  it").  Lay_Path marks a path Path_Width_M wide along the ground;
   --  from then on that ground is a path's (no zone takes it, and zones
   --  are laid out along it), though it is grass still.  The band lays it a
   --  metre at a time (Tamp_S a metre: what grows on it cut and the top of
   --  the ground turned to footpath, each metre all at once), as an extra
   --  task, the camp's building first (Extra_Hands).  Which metres are
   --  still to lay is read from the ground itself, so a bit dug up is laid
   --  again.
   --
   --  A path is laid a stretch to a serf (John, 2026-11-11: "when a serf
   --  starts compacting a road they are assigned a stretch, say 20m for
   --  example").  A path is kept as stretches of Path_Stretch_M (the last
   --  what is left; a shorter click is a stretch of its own).  Whoever
   --  starts on a path is given a stretch nobody has, the one with the
   --  least way to it, weighed toward the stake: it is that serf's alone,
   --  and it lays it from end to end.  Then it goes back to its own work
   --  (and may be given another when it next has empty hands and there is a
   --  place for it); only if its stretch was short does it go on to another
   --  nobody has, till it has laid Path_Stretch_M metres.  Leaving for
   --  anything else (to eat, to sleep, for the camp) gives its stretch up.
   --  So a path takes as many serfs at once as it has stretches, and no
   --  more than Extra_Hands allows.
   --
   --  The colony's ground reaches as far as any stretch still to lay
   --  (Ground_Reach_M).  With the band's labour off (Set_Labour) a path is
   --  laid the moment it is marked, as it used to be.
   Path_Width_M   : constant := 1.0;
   Path_Stretch_M : constant := 20.0;
   procedure Lay_Path (From, To : Vec3; Laid : out Natural);
   --  A footpath Path_Width_M wide along the ground from From to To
   --  (metres): planned, for the band to lay (or, with the band's labour
   --  off, laid: the top of the ground turned to footpath and anything
   --  growing on it cut).  Laid: block columns of it there are to turn (0:
   --  nothing there to lay on, or refused: Path_Refusal).
   procedure Build_Paths_Now;
   --  Every stretch planned laid on the spot, as Build_Camp_Now builds the
   --  camp: for scripted starts (--paths-built) and the checks.
   function Paths_To_Lay return Natural;   --  metres of planned path still to lay, as last counted
   function Path_Todo (K : Positive; Metre : Positive) return Boolean;
   --  Metre Metre (from its first end) of stretch K is still to lay, as last
   --  counted: for whatever shows a planned path.
   function Stretch_Of (I : Positive) return Natural;   --  the stretch member I has to lay (0: none)
   function Laid_By (I : Positive) return Natural;      --  metres it has laid since it was given one
   procedure Set_Stretches (On : Boolean);
   --  On (the default): a path is laid a stretch to a serf, as above.  Off:
   --  as it was before stretches, for the older reference logs: anyone at
   --  an extra task lays the metre with the least way to it, one metre at a
   --  time, several to a stretch.  Saved with the colony.
   function Stretches return Boolean;
   --  Paths and zones never share ground.  A path is laid round a zone: one
   --  whose line would run through zoned ground is refused whole, and one
   --  that only brushes a zone leaves the zone's blocks as they are.  (The
   --  other way round, ground a path lies on can never be zoned: see zones.)
   function Path_Refusal return String;   --  why the last Lay_Path laid nothing ("" if it laid some)
   function Path_Count return Natural;
   function Path_End (K : Positive; Second : Boolean) return Vec3;
   function Near_Path (X, Y, Within_M : Float) return Boolean;
   function On_Path (X, Y : Float) return Boolean;   --  that ground is a path's own

   ------------------------------------------------------- stockpiles

   Max_Cells : constant := 1_024;
   procedure Zone_Stockpile (X0, Y0, X1, Y1 : Float; Cells : out Natural);
   --  A stockpile on the lot between two corners (metres, in either order;
   --  the first is the side of a path it is on), and only if it comes
   --  within a metre of a path's edge.  The lot is laid out the way zones are (see
   --  zones): turned to lie along its path, drawn out to the path's edge,
   --  stopping at any path and at any other zone.  Things are put down in
   --  places 1 m square, set out in rows along the lot; a place with
   --  anything standing on it (a bush, a log, a stone), or a top more than
   --  half a metre off level, or part of it off the lot's ground, is left
   --  out.  Grass and grain on the places are cut, so what is put there
   --  can be seen (the rest of its ground keeps its grass).  Cells: how
   --  many places it got (0: refused, and Stockpile_Refusal says why).  One
   --  zoning is one zone.
   function Stockpile_Refusal return String;   --  why the last Zone_Stockpile was refused ("" if it was not)
   function Stored (K : Item_Kind) return Natural;      --  in every stockpile
   procedure Supply (K : Item_Kind; N : Natural; Placed : out Natural);
   --  N of K put straight into the stockpiles (cells already holding K
   --  with room first, then empty ones), as if brought in: for scripted
   --  starts and the checks.  Placed: how many found room.
   function Cell_Count return Natural;
   type Cell_View is record
      Centre : Vec3;
      Kind   : Item_Kind;
      Count  : Natural;
      Turn   : Float;       --  the way its lot lies (radians): what is put there lies the same way
   end record;
   function Cell_At (K : Positive) return Cell_View;

   ------------------------------------------------------- bushes

   Regrow_Days   : constant := 6.0;
   Pick_S        : constant := 1.5;    --  seconds a handful
   Work_Radius_M : constant := 60.0;   --  how far from the stake work is looked for
   function Bush_Count return Natural;                 --  bushes (one across a stack edge is one)
   function Bush_Slots return Natural;                 --  K in 1 .. Bush_Slots for the ones below
   function Bush_Alive (K : Positive) return Boolean;  --  false: joined into another
   function Ripe_Bushes return Natural;
   function Berries_Left return Natural;   --  handfuls on every known bush
   function Bush_Centre (K : Positive) return Vec3;
   function Bush_Radius (K : Positive) return Float;
   function Bush_Ripe (K : Positive) return Natural;
   function Bush_Reserved_By (K : Positive) return Natural;   --  0: nobody
   procedure Index_All;
   --  Look through every loaded stack in reach of the stake for bushes now
   --  (otherwise a few stacks a step, nearest first).

   ------------------------------------------------------- gathering: what, and how far

   --  Gatherers pick berries off bushes, pull wild vegetables (a plant
   --  each, Castle.Blocks.Wild_Vegetables) and, from summer's tenth day to
   --  the end of autumn (Apples_From_Day .. Apples_To_Day), pick apples off
   --  apple trees.  What a gatherer goes for is one score: the way there,
   --  and half the way from the stake, over its pull.  Berries pull 1,
   --  apples Apple_Pull (fruit last).  Vegetables, the cook's best greens,
   --  pull Veg_Pull (a little further is worth it); half as much again when
   --  the band has less than a day's food stored (none of that at two
   --  days), and up to twice that again as the vegetables in store fall
   --  short of their reserve.  Their reach grows the same way, from
   --  Work_Radius_M by up to 10 m for each, to Forage_Reach_M at most.  With
   --  no vegetables in store at all a gatherer goes for nothing else while
   --  there are any in reach.  A basket part full is filled with the same.
   --  A vegetable pulled grows back in Veg_Regrow_Days (not in winter); an
   --  apple tree bears about Apple_Yield apples a year.
   Veg_Pull        : constant := 1.3;
   Apple_Pull      : constant := 0.9;
   Forage_Reach_M  : constant := 80.0;
   Veg_Regrow_Days : constant := 10.0;
   Apples_From_Day : constant := 25.0;
   Apples_To_Day   : constant := 45.0;
   Apple_Yield     : constant := 40;
   function Apples_Left return Natural;     --  on the apple trees in reach, now (0 out of season)
   function Vegetables_Pulled return Natural;   --  all told

   ------------------------------------------------------- trees and logs

   function Chop_S (T : Tree_Info) return Float;   --  seconds of chopping to fell it
   function Logs_Of (T : Tree_Info) return Positive;   --  logs it comes down as
   function Tree_Count return Natural;
   function Tree_At (K : Positive) return Tree_Info;
   function Tree_Base (K : Positive) return Vec3;      --  the middle of the trunk, on the ground
   function Tree_Down (K : Positive) return Boolean;
   function Tree_Reserved_By (K : Positive) return Natural;
   function Trees_Felled return Natural;
   type Pile_View is record
      Centre : Vec3;
      Turn   : Float;      --  the way the logs lie (radians)
      Count  : Natural;
      Owner  : Natural;    --  the forester who felled it (0: nobody's)
   end record;
   function Pile_Count return Natural;
   function Pile_At (K : Positive) return Pile_View;
   function Logs_Lying return Natural;                 --  in every pile, not yet carried off

   ------------------------------------------------------- standing orders

   procedure Set_Protect_Apples (On : Boolean);   --  apple trees are never felled (default on)
   function Protect_Apples return Boolean;
   procedure Set_Wood_Reserve (Logs : Natural);
   --  The surplus of logs to keep (Set_Reserve (Wood, Logs)).  Before the
   --  demand chain, and with it off, 0 was no limit.
   function Wood_Reserve return Natural;
   function Wood_Total return Natural;

   type Per_Kind is array (Item_Kind) of Natural;
   Default_Reserve : constant Per_Kind := [Wood => 20, Straw => 20, Meat => 20, Vegetables => 40, others => 0];
   procedure Set_Reserve (K : Item_Kind; N : Natural);
   --  A surplus to keep in store, on top of what is used: the order's row
   --  of the demand table (see demand).  Counted with what is carried and
   --  on its way (a carcass lying or carried counts its meat; logs lying
   --  count).  Vegetables: below it gatherers also go further for them (see
   --  gathering).  Wood: Set_Wood_Reserve is the same.
   function Reserve_Of (K : Item_Kind) return Natural;
   function Have (K : Item_Kind) return Natural;   --  stored and carried

   --  What is wanted for a use: porters fetch stone, after straw, until
   --  the colony has as much as is wanted.  A colony starts wanting
   --  Stone_Quota (for paving the paths, once there are masons); the work
   --  that uses it (paving) will ask for more with Want and take it away
   --  as it is used.
   Stone_Quota : constant := 20;
   procedure Want (K : Item_Kind; N : Natural);   --  N more of K wanted
   function Wanted_Of (K : Item_Kind) return Natural;

   --  Grain is a by-product of straw: a porter cutting straw cuts wild
   --  grain as readily as tall grass (the whole stalk, to the ground), and
   --  each plant of grain gives, with its sheaf of straw, Grain_Per_Plant
   --  handfuls of grain.  The grain rides home with the straw and goes into
   --  a stockpile cell of its own when the straw is put down (kept by the
   --  porter till there is room).  It is not eaten raw; the cook puts it in
   --  the pot after the vegetables, berries and apples are gone.
   Grain_Per_Plant : constant := 2;
   function Grain_Carried (I : Positive) return Natural;   --  with its straw

   Fetch_S : constant array (Item_Kind) of Float :=   --  seconds to get one
     [Straw => 0.8, Stone => 2.0, Water => 2.0, Vegetables => 2.5, Sticks => 20.0, others => 1.0];

   ------------------------------------------------------- needs: eating and sleeping

   --  Everyone eats and sleeps, on the game clock (the Hours Advance is
   --  given: a game minute to a colony second at the game's normal
   --  timescale).  Food is counted in points.  An adult eats Day_Food
   --  points a game day, a child 60 % of that, an elder 80 %.  Each holds
   --  Belly_Hours of food; once down to Hungry_At of it, at the next break
   --  in its work it eats.  Stew from the pot at the camp comes first (it
   --  takes a bowl and sits at the fire to eat it); without stew it eats
   --  raw: what it carries if that is food, else from the nearest stockpile
   --  cell of food, apples first, then berries, then vegetables (the cook's
   --  best greens are left to last).  What it will eat is set aside for it
   --  on the way.  Raw food fills a belly poorly (Raw_Food); the same food
   --  cooked into stew goes much further (Stew_Food).  Meat is never eaten
   --  raw.  At Very_Hungry it stops what it is doing to eat (never a load
   --  in its arms or a butchering: those are finished first).  With no food
   --  to be had it goes on working, hungry; once its belly is empty it is
   --  starving, and walks and works at Starving_Pace until it has eaten.
   --
   --  At night, from Bed_Hour (children an hour earlier, elders half an
   --  hour) to Wake_Hour, give or take a little for each, everyone puts
   --  down what it carries, eats supper unless it is nearly full
   --  (Supper_At), goes to its own place round the fire (round the stake
   --  while there is no camp) and sleeps.  Asleep, it gets hungry half as
   --  fast.
   Day_Food      : constant := 240;     --  points a game day, an adult (docs/systems/needs.md, "How it was tuned")
   Belly_Hours   : constant := 10.0;    --  hours of food it holds
   Hungry_At     : constant := 0.4;     --  of a full belly: eats at the next break
   Very_Hungry   : constant := 0.15;    --  stops work to eat (if there is food)
   Supper_At     : constant := 0.85;    --  at bedtime it eats first, below this
   Starving_Pace : constant := 0.6;     --  of its pace and work, with an empty belly
   Bed_Hour      : constant := 21.0;
   Wake_Hour     : constant := 5.5;
   Raw_Food  : constant array (Item_Kind) of Natural := [Berries => 1, Vegetables => 3, Apples => 2, others => 0];
   Stew_Food : constant array (Item_Kind) of Natural :=
     [Meat => 30, Vegetables => 8, Berries => 3, Apples => 5, Grain => 4, others => 0];
   --  points an item gives, eaten raw / cooked into stew

   --  Fending for itself: once its belly is down to Very_Hungry with no
   --  stew to be had, no food in the stockpiles and none in its hands, a
   --  member leaves its job and gathers for itself (what a gatherer would
   --  go for), eating it as soon as it has enough, and its own work waits.
   --  In winter, a member whose belly has been empty for Death_Hours dies
   --  of hunger (it lies where it fell).
   --
   --  Mood: each member's eases, over about Mood_Hours, toward how it is
   --  living: Mood_Stew fed on stew, Mood_Raw fed on raw food, Mood_Hungry
   --  hungry, Mood_Starving starving, nothing at all while it has to fend
   --  for itself; and starting to fend takes Mood_Fend off at once.  A
   --  death takes Mood_Grief off everyone.  The band's confidence in the
   --  player is the mean of the living's moods: that is what the player is
   --  shown, not each one's.
   Death_Hours   : constant := 48.0;
   Mood_Hours    : constant := 12.0;
   Mood_Stew     : constant := 0.8;
   Mood_Raw      : constant := 0.55;
   Mood_Hungry   : constant := 0.35;
   Mood_Starving : constant := 0.1;
   Mood_Fend     : constant := 0.1;
   Mood_Grief    : constant := 0.25;
   Mood_Start    : constant := 0.7;

   --  Winter.  Nothing is gathered in winter: the berries are gone and the
   --  roots lie under the snow (hunting goes on).  So the band lives on
   --  what it stored, and the winter store is the order for that: outside
   --  winter, Winter_Store days of the band's food are held back in the
   --  stockpiles, the kinds that keep first (grain, apples, meat, then
   --  vegetables and berries), and neither the cook nor anyone eating raw
   --  touches them; gatherers work as if that food were not there.  The
   --  store is built from surplus: a day's food (the pot and the stockpiles
   --  together) is never held, so ordering a store starves nobody.  Only
   --  someone starving who has found nothing to gather breaks into it.  In
   --  winter the hold lifts by itself.
   --
   --  The fire is kept in all day and night in winter (six logs a day), and
   --  the cook fills its stack before anything else.  Anyone asleep in
   --  winter away from a burning fire is cold: it gets hungry at the waking
   --  rate, not half, and its mood can rise no higher than Mood_Cold.
   Mood_Cold : constant := 0.3;
   --  Orders of preference, and the rest of the needs' tunables.
   type Kind_List is array (Positive range <>) of Item_Kind;
   Raw_Order    : constant Kind_List := [Apples, Berries, Vegetables];        --  eaten raw: first to last
   Greens_Order : constant Kind_List := [Vegetables, Berries, Apples, Grain]; --  the pot's greens: first to last
   Keep_Order   : constant Kind_List := [Grain, Apples, Meat, Vegetables, Berries];   --  held for winter: first to last
   Fetch_Order  : constant Kind_List := [Straw, Stone];                       --  what porters fetch, first things first
   Free_Day        : constant := 1.0;    --  days of food the winter store never holds back
   Eat_Base_S      : constant := 8.0;    --  seconds a meal takes, and
   Eat_Per_Point_S : constant := 0.25;   --  more for each point of food

   --  Fixed capacities (raise them with the population target of a phase).
   Max_Paths       : constant := 256;
   Max_Bushes      : constant := 4_096;
   Max_Bush_Blocks : constant := 160;    --  blocks to a bush
   Max_Trees       : constant := 4_096;
   Max_Piles       : constant := 512;    --  log piles
   Max_Carcasses   : constant := 32;
   Max_Arrows      : constant := 16;
   Max_Pulled      : constant := 4_096;  --  vegetables pulled, waiting to grow back
   Max_Zones       : constant := 256;    --  stockpiles and the camp
   Max_Zone_Runs   : constant := 32_768; --  the strips of ground all the zones are kept as
   Max_Plan_B      : constant := 400;    --  block columns each way a lot is worked out over (Max_Lot_M at any turn)
   Max_Plan_Runs   : constant := 8_192;  --  strips of ground to one lot
   Patch_Span      : constant := 6;      --  metres each way of the fire the camp's ground is made ready in

   procedure Set_Winter_Store (Days : Natural);   --  0 (the default): nothing held back
   function Winter_Store return Natural;
   function Store_Held_Days return Float;         --  held back now, in days of the band's food
   function Cold (I : Positive) return Boolean;

   procedure Set_Source_Memos (On : Boolean);
   --  On (the default): what a search for the nearest straw, stone, water
   --  or wild vegetables found in a stack is kept until that stack's ground
   --  (or the ground just beside it) changes.  Off: every search reads the
   --  ground again, as it always did; the same places are found either way
   --  (for checks and for measuring).  Not saved.

   procedure Set_House_Memos (On : Boolean);
   --  On (the default): a house's blueprint is kept while it is the one
   --  being asked about, and a search for a lot that found none is not made
   --  again until a zone, a path or a house has changed.  Off: both are
   --  worked out every time, as if nothing were kept; the same houses come
   --  out either way (for checks and for measuring).  Not saved.

   procedure Set_Needs (On : Boolean);
   --  On (the default): the band eats and sleeps.  Off: nobody does (for
   --  checks of the work alone).  Saved with the colony.
   function Needs return Boolean;
   function Fed_Of (I : Positive) return Float;     --  0 (starving) .. 1 (full)
   function Hungry (I : Positive) return Boolean;   --  down to Hungry_At or below
   function Asleep (I : Positive) return Boolean;
   function Fending (I : Positive) return Boolean;
   function Mood_Of (I : Positive) return Float;    --  0 .. 1
   function Confidence return Float;                --  0 .. 1: the living's mean mood
   function Dead (I : Positive) return Boolean;
   function Living return Natural;
   function Deaths return Natural;                  --  all told
   function Eaten return Natural;                   --  food points eaten, all told
   function Food_Days return Float;
   --  The food stored and in the pot, in days of what the band eats (0 with
   --  no band): stew as it is, the rest as the cook would make it into stew
   --  while there is a cook and a camp, raw otherwise.

   ------------------------------------------------------- the camp and the cook

   --  The camp is a zone the player marks: a Camp_Size_M square with the
   --  fire in its middle, in a ring of fieldstones, and over it the iron
   --  pot the band brought with them, hung from a crossbar.  Seat logs go
   --  round the fire (Seat_Logs of them, two places each), and the band
   --  sleeps round it.  One camp to a colony.
   --
   --  It is built, not conjured (John, 2026-11-10: "the fire just doesn't
   --  magically appear, they build it, the current model comes into
   --  existent after they deliver stone and wood to build it ... they also
   --  need to prepare the ground, compacting the earth around the campfire
   --  grass disappears").  Zoning it marks where; then the band builds it,
   --  as its own need: anyone with empty hands and nothing more pressing
   --  (eating, sleeping) turns to it before its job.
   --    the ground   made ready a square metre at a time (Tamp_S a visit),
   --                 from the fire outward: what grows on the camp's
   --                 ground is cut, and within Hearth_Ground_M of the fire
   --                 (its floor) the ground is made level and the turf
   --                 trodden to bare earth
   --  The floor is levelled (John, 2026-11-11: "I have tested it on uneven
   --  ground, and it causes some issues with the logs and such, so I think
   --  we need to have them level the terrain at least for the compacted
   --  part, they can move the dirt to the stockpile").  Its level is chosen
   --  when the camp is marked: the highest at which the earth dug off what
   --  stands above it, with the turf cut off the rest (a block of earth for
   --  every Sod_Share block columns of it), is at least what the hollows
   --  below it take, so the earth for them is always there.  Whoever makes
   --  a square metre of it ready digs off what stands above the level, a
   --  basketful a visit (Carry_Limit (Earth) blocks), cuts its turf (which
   --  lies there, for filling: it is never carried off), and fills its
   --  hollows with the earth in its hands.  What earth is left in them it
   --  carries to another hollow of the floor if one wants it, else to the
   --  stockpile, where it is heaped as earth (with nowhere to put it, it
   --  is thrown aside).  Once nothing is left to dig off, the hollows still
   --  there are filled with the turf's earth, and then from the
   --  stockpile's; with none to be had anywhere a hollow is left.  Rock is
   --  not dug: a column of it stands as it is.  The fire's place follows
   --  its ground.
   --    stone        Hearth_Stones for the ring: from the stockpile if it
   --                 holds any, else prised off the nearest boulder by
   --                 whoever goes for it
   --    wood         Hearth_Wood pieces for the crossbar: a log from the
   --                 stockpile, carried by one whose work logs are (the
   --                 cook, a forester); from anyone else, or with none
   --                 stored, an armful of deadwood from under the nearest
   --                 tree (never by a porter: porters carry no wood)
   --  With the ground ready and both delivered the hearth stands: the
   --  ring, the crossbar, and the pot with them (the pot is the band's own
   --  and needs no making).  The seat logs are laid as soon as there are
   --  logs in the stockpile, by the cook and by a forester, before anything
   --  else of their own: the hearth does not wait for them, nor they for
   --  the cook to have nothing else to do.  What
   --  the building still takes is asked of the stores as well (a zone's
   --  rows of the demand table), so porters and foresters bring it in.
   --  With the camp's labour off (Set_Labour) it stands the moment it
   --  is zoned, the grass on it cut, as it used to.
   --
   --  The cook keeps it.  First the fire.  A log on it burns Log_Hours;
   --  then the fire dies down for Die_Down_Hours more, its flames sinking
   --  to embers, and all that while a log put on it takes at once and it is
   --  away again: that is when it is restoked.  After that it is out.  It is
   --  tended by hand: nothing goes on it but what someone puts there.  The
   --  cook sees to it whenever it is wanted and there is not enough on it:
   --  for cooking (enough to see a pot through); for the night, from
   --  Stoke_Ahead_Hours before bedtime (enough that it burns, or at least
   --  glows, till waking: a log at bedtime lasts the night and leaves embers
   --  to restoke in the morning); and in winter, when it is kept in all day,
   --  as soon as it begins to die down.  A fire dying down still warms those
   --  asleep round it; it does not cook.  Logs come from the stockpile and
   --  are stacked by the fire (Fire_Stack), and the cook stokes it from the
   --  stack; with no logs stored it picks up an armful of dead sticks under
   --  the nearest tree instead (Sticks_Hours), for cooking only, so a band
   --  without a forester can still cook.  Then the pot: once the stew in it
   --  is down to Pot_Low, the cook fetches what to make more with from the
   --  stockpile, a load at a time: meat for up to half the pot, the rest
   --  vegetables, or berries when there are no vegetables, or apples after
   --  those; all meat or all greens when that is all there is.  It stirs
   --  it over the fire for Cook_Hours (at its work rate), and the pot holds
   --  Stew_Food points for each thing put in, a quarter more again for a pot
   --  of meat and greens together (Balanced_Bonus), and more or less by how
   --  good a cook it is (Pot_Yield_Of).  Once the fire has wood and the pot stew, it
   --  lays the seat logs (logs from the stockpile).  With nothing to cook
   --  it goes out gathering till there is.
   --
   --  Nobody need be told to cook: once there is a camp and something to
   --  cook, and nobody has ever been the cook, the best cook in the band
   --  takes it up on its own (Cooking_Of; the player can change it after).
   --
   --  (John, 2026-11-10: "fire life needs to be extended to about 8hours
   --  with a 3 hour diedown for restoking".  Before that, and still with the
   --  camp's labour off (Set_Labour), a log burnt Instant_Log_Hours and
   --  the fire took one off its stack by itself whenever it burnt out while
   --  it was wanted.)
   Camp_Size_M    : constant := 7.0;
   Hearth_Stones  : constant := 10;      --  fieldstones for the fire's ring
   Hearth_Wood    : constant := 3;       --  pieces of wood for the crossbar (two posts and the bar)
   Hearth_Ground_M : constant := 2.6;    --  the camp's floor: level, its turf cut off, this far round the fire
   Sod_Share      : constant := 2;       --  block columns of turf cut off the floor that make a block of earth
   Tamp_S         : constant := 4.0;     --  seconds to make a square metre of the camp's ground ready
   Patch_Reach_M  : constant := 1.6;     --  it is worked from this near its middle, if no nearer can be got to
                                         --  (a bank is dug from the foot of it)
   Seat_Logs      : constant := 4;
   Seat_R         : constant := 2.0;     --  seat logs this far from the fire
   Fire_Stack     : constant := 4;       --  logs stacked by the fire, at most
   Log_Hours      : constant := 8.0;     --  a log's burning
   Die_Down_Hours : constant := 3.0;     --  then it dies down this long, and can be restoked on its embers
   Stoke_Ahead_Hours : constant := 2.0;  --  the fire is seen to for the night from this long before bedtime
   Fire_Sink_Hours   : constant := 1.0;  --  its flames sink through its last hour of wood, to
   Ember_Heat        : constant := 0.45; --  this much of its full heat as the die-down begins
   Instant_Log_Hours : constant := 4.0;  --  with the camp's labour off: a log's burning as it was
   Sticks_Hours   : constant := 1.5;
   Cook_Hours     : constant := 1.0;
   Pot_Points     : constant := 900;
   Pot_Low        : constant := 450;
   Balanced_Bonus : constant := 1.25;

   procedure Zone_Camp (Centre : Vec3; Ok : out Boolean);
   --  The camp round Centre (a point on the ground, metres): marked, to be
   --  built by the band.  Refused (Ok False) once there is one, or where
   --  its ground anywhere is more than a metre above or below the middle's,
   --  or anything but grass stands on it (a tree, a bush, a stone, the
   --  stake, water), or a stockpile cell is on it, or a path or a zone
   --  comes within Camp_Clear_M of the fire.
   function Camp_Refusal return String;   --  why the last Zone_Camp was refused ("" if it was not)
   function Has_Camp return Boolean;
   procedure Stoke (Hours : Float);
   --  The camp's fire given Hours more of burning, as if wood had just
   --  gone on it; nothing is taken from any store.  A camp not built yet
   --  is built on the spot for it (its ground made ready, its hearth
   --  standing), as Supply conjures goods.  For scripted starts (--stoke)
   --  and the checks: a fire to look at without waiting for the band.
   --  Nothing without a camp.
   procedure Build_Camp_Now;
   --  The camp built on the spot: its ground ready, its hearth standing,
   --  nothing taken from anywhere.  For scripted starts (--camp-built) and
   --  the checks, as Supply is.  Nothing without a camp, or with one built.
   function Camp return Vec3;             --  the fire, on the ground
   type Camp_View is record
      Built    : Boolean := False; --  its hearth stands (the ring, the crossbar, the pot)
      Ground_Left : Natural := 0;  --  square metres of its ground still to be made ready
      Stones   : Natural := 0;     --  delivered for the ring, of Hearth_Stones
      Frame    : Natural := 0;     --  pieces of wood delivered for the crossbar, of Hearth_Wood
      Looking  : Float   := 0.0;   --  how far the band is looking for those (Looking_M)
      To_Dig   : Natural := 0;     --  blocks of earth still to dig off its floor, to level it
      To_Fill  : Natural := 0;     --  blocks its hollows still take
      Floor_Z  : Float   := -1.0;  --  the height its floor is levelled to (-1: left as it lies)
      Seats    : Natural := 0;     --  seat logs laid
      Logs     : Natural := 0;     --  stacked by the fire
      Fuel_H   : Float   := 0.0;   --  hours the fire burns on what is on it
      Burning  : Boolean := False;
      Dying    : Boolean := False; --  burnt out and dying down: embers, to be restoked
      Ember_H  : Float   := 0.0;   --  hours of the die-down left
      Heat     : Float   := 0.0;   --  how well it burns, 0 (out) .. 1
      Stew     : Natural := 0;     --  points ready in the pot
      In_Pot   : Natural := 0;     --  points of what is in it, not yet cooked
      Stirring : Boolean := False;
      Burnt    : Natural := 0;     --  logs the fire has taken, all told
      Set_Aside : Natural := 0;    --  of the stew, points promised to people on their way for a bowl
   end record;
   function Camp_State return Camp_View;

   procedure Set_Labour (On : Boolean);
   --  On (the default): what the player marks takes the band's labour: the
   --  camp is built and its fire tended by hand, as above, and paths are
   --  laid by the band (see paths).  Off: the colony as it was before any
   --  of that, for the older checks and reference logs: the camp stands
   --  and a path is laid the moment it is marked, and the fire feeds itself
   --  from its stack, a log every Instant_Log_Hours, with no dying down.
   --  Saved with the colony.
   function Labour return Boolean;

   --  Extra tasks: what the band does that is nobody's job (the camp's
   --  building, the paths' laying).  (John, 2026-11-11: "we should limit
   --  the amount of workers that can perform extra tasks".)  At most
   --  Extra_Hands are at them at once: one in Extra_Share of the living, at
   --  least one, unless a number has been set.  Whoever has a job turns to
   --  an extra task only while fewer than that are at them; the rest go on
   --  with their work.  Someone with no job never waits for a place (it has
   --  nothing else to do), but counts as a hand, at a task yet or not: while
   --  the idle are enough, nobody leaves a job.  The camp's building is the cook's own work, not
   --  an extra task for it: the cook neither waits nor counts there (at a
   --  path it is a hand like any other).  A load already in hand for the
   --  camp is always carried there.
   Extra_Share : constant := 3;
   procedure Set_Extra_Hands (N : Natural);
   --  At most N at extra tasks at once (0: by the rule above; Max_Members:
   --  everyone, as it was before there was a limit).  Saved with the colony.
   function Extra_Hands return Natural;   --  the limit now
   procedure Set_Levelling (On : Boolean);
   --  On (the default): a camp marked from now on has its floor levelled by
   --  the band, as above.  Off: its ground is left as it lies, as before
   --  2026-11-11, for the older reference logs.  Saved with the colony.
   function Levelling return Boolean;
   function At_Extra return Natural;      --  how many hands are at extra tasks now (the cook at its camp not counted)

   --  How far the band goes for what its camp's building takes: as far as
   --  it has to (John, 2026-11-10: "Don't place a distance limit on initial
   --  gathering, if they have to walk 200m to get stone they walk 200m").
   --  Its work is looked for within Work_Radius_M of the stake, and so
   --  first are the camp's stone and deadwood.  When all the ground that
   --  near has been looked through and holds none that can be got at, the
   --  band looks further: Reach_Step_M more at a time, each ring looked
   --  through before the next, until there is some or Far_Reach_Max_M is
   --  reached (which is as far as the ground can be kept in: the engine's
   --  limit, not a rule).  Whoever is free goes for it, however far; the
   --  rest go on with their work meanwhile.  Once the camp stands and
   --  everyone is back within reach of the stake, the band looks no further
   --  than its work again.
   --
   --  The colony's ground (the stacks the game keeps loaded for it, and
   --  waits for) follows: Ground_Reach_M is how far from the stake it has
   --  to reach now.  Work_Radius_M as a rule, so that nothing changes while
   --  nobody looks further; wider while the band looks or is afield, and as
   --  far as any stretch of path still to lay.
   Reach_Step_M    : constant := 16.0;
   Far_Reach_Max_M : constant := 256.0;
   function Ground_Reach_M return Float;
   function Looking_M return Float;
   --  How far from the stake the band is looking for what the camp's
   --  building takes (0: no further than its work).
   procedure Set_Stone_From (Metres : Float);
   --  For measurements and the checks, as Supply is: the camp's builders
   --  leave alone any stone nearer the stake than this, as if the nearest
   --  lay that far off (0, the default: none is left).  It sends the band
   --  far afield on ground where stone is never far.  Saved with the colony.
   function Camp_Turn return Float;
   --  The way the camp lies (radians): its zone's, a path's that passes
   --  within reach of its square, else east and north.
   function Firewood_Place return Vec3;              --  where the fire's stack of logs stands
   function Seat_Place (K : Positive) return Vec3;   --  K in 1 .. 2 * Seat_Logs: where one sits
   function Seat_Log (K : Positive) return Vec3;     --  K in 1 .. Seat_Logs: the middle of the log
   function Seat_Turn (K : Positive) return Float;   --  the way it lies (radians)
   function Cooking_Of (I : Positive) return Float;
   --  0 .. 1, from its seed: what made a cook good before there were skills
   --  (and still does with skills off).  Its aptitude for cooking is this
   --  spread over Aptitude_Lo .. Aptitude_Hi, so the band's best cook is who
   --  it always was.
   function Cooked return Natural;                   --  points of stew made, all told
   function Put_In_Pot (K : Item_Kind) return Natural;   --  of K, all told
   function Eaten_Raw (K : Item_Kind) return Natural;    --  of K, all told

   ------------------------------------------------------- skills

   --  People are better at some work than other work, and get better at
   --  what they do.  Each member has a level, 0 (none) .. 1 (mastery), in
   --  each skill, and an aptitude for each, Aptitude_Lo .. Aptitude_Hi, that
   --  says how fast it learns it: its own for life, from its seed.  The
   --  first five are the skills of the work there is; the rest only grow
   --  alongside, for the trades to come.
   --  (Saved by position: new skills go on the end.)
   type Skill_Kind is (Gathering, Forestry, Hunting, Portering, Cooking,
                       Building, Carpentry, Stonework, Farming, Tanning, Taming);
   subtype Working_Skill is Skill_Kind range Gathering .. Cooking;
   function Name (S : Skill_Kind) return String;   --  "forestry"

   --  The work a member can be at.  Handling is what has no skill in it:
   --  carrying, lifting, putting down, taking from a cell.
   --  Site_Work is building: making ground ready, bringing what a building
   --  takes and setting it up (the camp's hearth is the first).
   --  House_Raising is a builder's: laying a house's floor, walls and roof.
   type Work_Kind is (Handling, Picking, Felling, Stalking_Game, Butchering, Reaping, Quarrying, Drawing_Water,
                      Camp_Keeping, Site_Work, House_Raising);
   subtype Skilled_Work is Work_Kind range Picking .. House_Raising;
   Own_Skill : constant array (Skilled_Work) of Skill_Kind :=
     [Picking => Gathering, Felling => Forestry, Stalking_Game => Hunting, Butchering => Hunting,
      Reaping => Portering, Quarrying => Portering, Drawing_Water => Portering, Camp_Keeping => Cooking,
      Site_Work => Building, House_Raising => Building];

   --  A level's worth.  Every timer of skilled work runs at
   --     rate = condition x skill x direction
   --  condition: Starving_Pace with an empty belly, else 1; skill: from
   --  Novice_Rate with none of the work's own skill to Master_Rate at
   --  mastery (1 at a third of the way: the pace before there were skills);
   --  direction: what whoever directs it adds, 1 for everyone until a trade
   --  directs helpers.  Handling goes by condition and direction alone, and
   --  walking by condition.  A hunter's chance to hit is today's times
   --  Novice_Aim .. Master_Aim (never over Best_Aim), and a cook's pot holds
   --  Novice_Pot .. Master_Pot of what went into it.
   Novice_Rate : constant := 0.75;
   Master_Rate : constant := 1.5;
   Novice_Aim  : constant := 0.8;
   Master_Aim  : constant := 1.4;
   Best_Aim    : constant := 0.95;
   Novice_Pot  : constant := 0.9;
   Master_Pot  : constant := 1.2;

   --  Skill by doing.  An hour on a job is an hour of practice: the whole
   --  trip (going out, the work, carrying it home), by the work done, not
   --  the job held (a cook out gathering learns gathering).  It teaches the
   --  work's own skill in full and the skills beside it by the fractions in
   --  Learns.  A level closes on mastery at a rate of its aptitude over
   --  Learn_Hours: fast from nothing, slower the better it is; Learn_Hours
   --  of work at aptitude 1 leave about a third of the gap.  Nothing is
   --  learnt idle, eating or asleep, and nothing is forgotten.
   Learn_Hours : constant := 600.0;
   Aptitude_Lo : constant := 0.5;
   Aptitude_Hi : constant := 1.5;
   type Shares is array (Skill_Kind) of Float;
   Learns : constant array (Work_Kind) of Shares :=
     [Handling      => [others => 0.0],
      Picking       => [Gathering => 1.0, Farming => 0.2, Cooking => 0.1, others => 0.0],
      Felling       => [Forestry => 1.0, Building => 0.15, Carpentry => 0.1, others => 0.0],
      Stalking_Game => [Hunting => 1.0, Taming => 0.1, others => 0.0],
      Butchering    => [Hunting => 1.0, Tanning => 0.3, Cooking => 0.2, others => 0.0],
      Reaping       => [Portering => 1.0, Farming => 0.3, others => 0.0],
      Quarrying     => [Portering => 1.0, Stonework => 0.3, others => 0.0],
      Drawing_Water => [Portering => 1.0, others => 0.0],
      Camp_Keeping  => [Cooking => 1.0, others => 0.0],
      Site_Work     => [Building => 1.0, Stonework => 0.2, others => 0.0],
      House_Raising => [Building => 1.0, Carpentry => 0.3, Forestry => 0.1, others => 0.0]];

   --  What people arrive with: Start_Lo .. Start_Hi in each working skill
   --  (an elder Elder_Start more, a child Child_Start of it), up to
   --  Trade_Start in the others.  A band's mean is about a third: on the
   --  whole it works at the pace it did before there were skills.
   Start_Lo    : constant := 0.15;
   Start_Hi    : constant := 0.5;
   Elder_Start : constant := 0.2;
   Child_Start : constant := 0.5;
   Trade_Start : constant := 0.1;

   --  The short work times (seconds): what has no skill in it.
   Store_S        : constant := 1.0;    --  putting a load down in a stockpile cell
   Lift_Log_S     : constant := 1.2;    --  a log on to the shoulder
   Lift_Carcass_S : constant := 2.5;    --  a deer across the shoulders
   Take_S         : constant := 1.0;    --  taking what was set aside from a cell
   Put_In_S       : constant := 1.0;    --  into the pot, on to the fire or its stack, a seat log laid
   Stalk_Patience_S : constant := 90.0; --  a stalk with no shot in this long is given up for a while

   procedure Set_Skills (On : Boolean);
   --  On (the default): as above.  Off: everyone works at the one pace,
   --  aims and cooks as before there were skills, and learns nothing (the
   --  levels stay).  Saved with the colony.
   function Skills return Boolean;

   function Skill_Of (I : Positive; S : Skill_Kind) return Float;      --  0 .. 1
   function Aptitude_Of (I : Positive; S : Skill_Kind) return Float;   --  Aptitude_Lo .. Aptitude_Hi
   procedure Set_Skill (I : Positive; S : Skill_Kind; Level : Float);
   --  For scripted starts and the checks, as Supply is: nobody's to do.

   function Has_Skill (J : Job_Kind) return Boolean;                   --  every job but Unassigned
   function Job_Skill (J : Job_Kind) return Skill_Kind with Pre => Has_Skill (J);
   --  The skill of a job's own work.

   function Work_Of (I : Positive) return Work_Kind;
   --  What member I is at now, for its practice: Handling when it is at
   --  nothing that teaches (idle, eating, asleep).
   function Work_Rate_Of (I : Positive; W : Work_Kind) return Float;
   --  The rate member I would do work W at now: condition x skill x direction.
   function Direction_Of (I : Positive) return Float;
   --  What its director's direction adds to its work: 1 for everyone, until
   --  a trade directs helpers (then by that director's skill).
   function Hit_Chance_Of (I : Positive; Metres : Float) return Float;   --  hunter I's, at that range
   function Pot_Yield_Of (I : Positive) return Float;
   --  What cook I's pot holds of what went into it (before the bonus for
   --  meat and greens together).

   ------------------------------------------------------- zones

   --  A zone is a piece of ground the player has marked for a use: a thing
   --  of its own, with a kind, borders and what is inside them.  Stockpiles
   --  and the camp are the first two kinds.  One zoning is one zone: a
   --  stockpile zoned in one go owns the cells it got (its borders are the
   --  box round them), and two that touch stay two.  Zones are numbered
   --  from 1 in the order they were made, and keep their numbers.
   --
   --  Information belongs to what is in the world, and a zone is where it
   --  is gathered: what lies inside its borders, what is on its way in and
   --  out, who is there.  That is all anyone is shown of it (Zone_At), and
   --  what is not in a zone nobody keeps count of.
   --
   --  A zone's ground.  A zone is the ground it fills, kept block column by
   --  block column, so it has whatever outline its place gives it:
   --    fill       its ground is every free block column of its lot that
   --               can be reached from where it was begun without crossing
   --               a path, a zone, a ledge higher than Zone_Step_M or
   --               anything standing in the way.  It is shown filled in.
   --    snap       the lot is a rectangle turned to lie along the nearest
   --               path, whatever way that runs; a side that comes within
   --               Snap_M of a path's edge is drawn out to it, so no strip
   --               of no man's land is left between.
   --    terminate  the fill stops at the path: ground a path lies on is
   --               never a zone's, and a lot drawn across a path keeps to
   --               the side it was begun on.
   --  No block column is ever in two zones, or in a zone and a path.
   --  (Zone_Kind is saved by position: new kinds go on the end.)
   Snap_M      : constant := 1.0;    --  a lot's side this near a path's edge is drawn out to it
   Zone_Step_M : constant := 0.5;    --  a zone does not climb a ledge higher than this
   Max_Lot_M   : constant := 64.0;   --  a lot's sides, at most
   Camp_Clear_M : constant := 3.0;   --  the fire is refused nearer a path or a zone than this
   Camp_Step_M  : constant := 2.0;   --  the camp's own ground may step this much (it lies within a metre of its middle)
   Snap_Facing  : constant := 0.64;  --  a side is drawn out to a path it faces to within 50 degrees (the cosine)

   type Zone_Kind is (Stockpile_Zone, Camp_Zone, Habitation_Zone);

   --  What is built on a zone takes materials, delivered to it by the band
   --  (see the camp): by kind of zone.  A stockpile takes nothing yet (its
   --  storehouse, its fences and its coverings will be rows here).  What a
   --  housing zone takes is not a number of its kind's: it is what its
   --  houses' blueprints count up to (see housing), and is asked for the
   --  same way.
   type Build_List is array (Zone_Kind) of Per_Kind;
   Build_Takes : constant Build_List :=
     [Stockpile_Zone  => [others => 0],
      Camp_Zone       => [Stone => Hearth_Stones, Wood => Hearth_Wood, others => 0],
      Habitation_Zone => [others => 0]];

   type Zone_View is record
      Kind   : Zone_Kind := Stockpile_Zone;
      Lo, Hi : Vec3 := (0.0, 0.0, 0.0);      --  opposite corners of the box round its ground (Z: its lowest and highest)
      Turn   : Float := 0.0;                 --  the way its lot lies: its path's, within 45 degrees of east (radians)
      Along, Across : Float := 0.0;          --  how far its ground reaches along that way and across it (metres)
      Blocks : Natural := 0;                 --  its ground, in block columns (sixteen to a square metre)
      Built  : Boolean := True;              --  what is to be built on it stands (a stockpile needs nothing built)
      Got    : Per_Kind := [others => 0];    --  delivered for its building, of Build_Takes
      Cells  : Natural := 0;                 --  a stockpile's places for things (the camp has none)
      In_Use : Natural := 0;                 --  of those, holding something or promised to it
      Holds  : Per_Kind := [others => 0];    --  what lies in it (the camp: its firewood; the pot is in Camp_State)
      Coming : Per_Kind := [others => 0];    --  on its way there, room set aside for it
      Going  : Per_Kind := [others => 0];    --  set aside for someone on the way to take it
      People : Natural := 0;                 --  the living inside its borders
      Homes  : Natural := 0;                 --  housing: the houses begun on it, standing or not,
      Homes_Built : Natural := 0;            --  and those of them that stand
      Short  : Per_Kind := [others => 0];    --  housing: what its houses still take that has not been delivered
      No_Room : Boolean := False;            --  housing: someone is without a home and no lot could be found for one
   end record;
   function Zone_Count return Natural;
   function Zone_At (Z : Positive) return Zone_View;
   function Zone_Of_Cell (K : Positive) return Natural;   --  the zone that owns stockpile cell K
   function Zone_On (X, Y : Float) return Natural;
   --  The zone whose ground (X, Y) is (0: none).
   function Zone_Top (X, Y : Float) return Float;
   --  The top of the zoned ground at (X, Y), metres (below 0: not zoned).
   function Camp_Zone return Natural;                      --  the camp's zone (0: no camp)

   --  A zone's ground, for whatever draws it: strips of block columns
   --  X0 .. X1 in row Y (west to east, rows south to north) whose tops are
   --  the top of block Z.
   type Zone_Run is record
      Y, X0, X1 : Integer := 0;
      Z         : Integer := 0;
   end record;
   function Zone_Runs (Z : Positive) return Natural;
   function Zone_Run_At (Z, K : Positive) return Zone_Run;   --  K in 1 .. Zone_Runs (Z)
   function Zones_Version return Natural;   --  moves on whenever any zone's ground does

   --  What a zoning would give, with nothing changed: for showing a lot
   --  before it is taken.  The plan's ground is Planned_Run_At, until the
   --  next plan or zoning.
   type Lot_Corners is array (1 .. 4) of Vec3;
   type Lot_Plan is record
      Ok     : Boolean := False;      --  it would be taken
      Corner : Lot_Corners := [others => (0.0, 0.0, 0.0)];   --  the lot as drawn, turned to its path
      Turn   : Float := 0.0;
      Cells  : Natural := 0;          --  places for things it would get
      Blocks : Natural := 0;          --  ground it would fill (block columns)
   end record;
   function Plan_Stockpile (X0, Y0, X1, Y1 : Float) return Lot_Plan;
   function Plan_Camp (Centre : Vec3) return Lot_Plan;
   function Planned_Runs return Natural;
   function Planned_Run_At (K : Positive) return Zone_Run;

   ------------------------------------------------------- housing

   --  Housing is a zone the player marks along a path, as a stockpile is
   --  (two corners; fill, snap, terminate).  That is all the player does:
   --  which lot, which house, for whom and when are the band's own.
   --
   --  Everyone without a home asks for one, a hovel each.  A hovel is begun
   --  for a person (it is theirs from its first block), only so many at
   --  once: as many as there are foresters to build them, and one even with
   --  none.  It is given the free frontage nearest the homestake along any
   --  path a housing zone lies on: a lot Lot_M along the path and Lot_M
   --  back, no two overlapping, the house (Castle.Buildings.Design: its
   --  size, door and windows from its own seed) square to the block grid,
   --  its front wall half a metre to a metre off the path's edge and its
   --  door toward the path; on a slanting path it steps back until it is
   --  clear.  Its walls and the bank round them have to lie wholly on the
   --  zone's ground, on ground that falls no more than a metre.
   --
   --  Builders come from the foresters.  A forester takes a house that has
   --  no builder (the best at building first), and is its builder until it
   --  stands: nobody is appointed, and no skill is asked yet.  It makes the
   --  ground ready a square metre at a time (the pad under the walls level,
   --  a bank Apron_B wide feathered round it, what grows there cut; the
   --  earth dug off fills the hollows and the rest is thrown aside on the
   --  lot), then lays the blueprint block by block in its order (the floor,
   --  the walls course by course, the gables, the roof), Lay_Blocks to a
   --  bout of Lay_S seconds, from what it has carried there: a log from the
   --  stockpile makes Planks_Per_Log blocks of plank or timber, a sheaf of
   --  straw Thatch_Per_Sheaf of thatch.  What a house takes is counted from
   --  its blueprint, and what its zone's houses are still short of is asked
   --  of the stores (the zone's rows of the demand table), so foresters
   --  fell and porters cut straw for it.  Building never takes the logs the
   --  camp's fire burns in a day, nor those its seats and hearth still
   --  want.
   --
   --  Reversion: a builder with nothing to build with (no wood in store
   --  that building may take, or no straw when the roof is next) goes on as
   --  the forester it is, and comes back to its house when there is some.
   --  Building is its own work, not an extra task: it counts against no
   --  limit, and the camp's building and the paths come first for it as
   --  for anyone.
   --
   --  When a house stands its owner lives there: it sleeps in it, not by
   --  the fire, and asleep under its own roof it is not cold in winter.  A
   --  house whose owner dies goes to the next without one.
   Lot_M            : constant := 7.0;
   Planks_Per_Log   : constant := 96;     --  blocks of plank or timber a log makes
   Thatch_Per_Sheaf : constant := 64;     --  blocks of thatch a sheaf of straw makes
   Lay_Blocks       : constant := 16;     --  blocks laid in a bout: a square metre
   Lay_S            : constant := 5.0;    --  seconds a bout
   Build_Reach_M    : constant := 2.5;    --  a block is laid from this near, across the ground
   Reach_Slack_M    : constant := 0.5;    --  (and a bout goes on to blocks this much further off)
   Stand_Off_B      : constant := 3.5;    --  a builder stands this many blocks clear of a wall it is laying,
   Stand_In_B       : constant := 3.0;    --  and inside the house only for what is this far in from every wall;
   Stand_Near_M     : constant := 1.2;    --  its way there may end this near the place chosen
   Bed_In_B         : constant := 4;      --  the owner's bed: this many blocks in from the left and the back wall
   Home_M           : constant := 1.5;    --  it is at home within this of its bed
   Max_Houses       : constant := Max_Members;
   Max_House_Blocks : constant := 4_096;  --  blocks to a blueprint
   Max_Fronts       : constant := 2_048;  --  frontages looked at for a lot (a metre of path, either side, each)
   Max_Site_Patches : constant := 160;    --  square metres of a house's pad and bank

   --  A trade is earned, not given: taken up by someone whose job leads to
   --  it (Trade_From) when there is work for it, and left for that job when
   --  there is not.  The builder is the first.  (Saved by position.)
   type Trade_Kind is (No_Trade, Builder);
   Trade_From : constant array (Trade_Kind) of Job_Kind := [No_Trade => Unassigned, Builder => Forester];
   function Trade_Of (I : Positive) return Trade_Kind;   --  Builder: it has a house to build
   function Site_Of (I : Positive) return Natural;       --  the house it is building (0: none)
   function Home_Of (I : Positive) return Natural;       --  its house, standing or not (0: none begun)
   function Housed (I : Positive) return Boolean;        --  its house stands
   function At_Home (I : Positive) return Boolean;       --  and it is inside it
   function Homeless return Natural;                     --  the living whose house does not stand

   procedure Zone_Housing (X0, Y0, X1, Y1 : Float; Lots : out Natural);
   --  A housing zone on the lot between two corners (metres, in either
   --  order; the first is the side of a path it is on), laid out the way
   --  zones are, and only if it comes within a metre of a path's edge and
   --  a hovel would fit in it.  Lots: how many hovels it would hold as
   --  things stand (0: refused, and Housing_Refusal says why).
   function Housing_Refusal return String;   --  why the last Zone_Housing was refused ("" if it was not)
   function Plan_Housing (X0, Y0, X1, Y1 : Float) return Lot_Plan;
   --  What that zoning would give, with nothing changed (Cells: the hovels
   --  it would hold).

   type House_Phase is (Ground, Flooring, Framing, Walling, Roofing, Standing);
   type House_Wait is (Not_Waiting, For_A_Builder, For_Wood, For_Straw, For_A_Way);
   type House_View is record
      Zone    : Natural := 0;
      Owner   : Natural := 0;                 --  whose it is (0: nobody's just now)
      Builder : Natural := 0;                 --  who is building it (0: nobody)
      Phase   : House_Phase := Ground;
      Blocks  : Natural := 0;                 --  its blueprint's blocks,
      Placed  : Natural := 0;                 --  and those laid
      Takes   : Per_Kind := [others => 0];    --  what it takes all told: wood in logs, straw in sheaves
      Got     : Per_Kind := [others => 0];    --  and what has been carried to it
      Waits   : House_Wait := Not_Waiting;    --  what its building waits for
      Corner  : Lot_Corners := [others => (0.0, 0.0, 0.0)];
      --  its walls' outer corners on the ground: front left, front right, back right, back left
      Door    : Vec3 := (0.0, 0.0, 0.0);      --  on the ground just outside its door
      Way     : Natural := 0;                 --  how far its door is from the path it faces (block columns),
      Rise    : Integer := 0;                 --  and how far its floor lies above the path's ground there (rows)
      Bed     : Vec3 := (0.0, 0.0, 0.0);      --  where its owner sleeps
      Top_Z   : Float := 0.0;                 --  the height of its ridge (metres)
   end record;
   function House_Count return Natural;
   function House_At (K : Positive) return House_View;   --  K in 1 .. House_Count
   function House_On (X, Y : Float) return Natural;
   --  The house whose walls stand, or are to stand, round (X, Y) (0: none).
   procedure Build_Homes_Now;
   --  A house for everyone without one, begun and built on the spot, nothing
   --  taken from anywhere, for as many as the housing zones have room for:
   --  for scripted starts (--homes-built) and the checks, as Supply is.

   ------------------------------------------------------- a person, as data

   --  What there is to know of member I, for whatever shows it (a panel, a
   --  tooltip, later a report): its name is Name_Of, what it says it is
   --  doing Status, its looks Genome_Of.
   type Person_View is record
      Job      : Job_Kind := Unassigned;
      Director : Actor := No_One;
      Doing    : Act := Standing;
      Child, Elder : Boolean := False;
      Fed      : Float := 1.0;              --  0 (starving) .. 1 (full)
      Mood     : Float := 0.0;              --  0 .. 1
      Hungry, Starving, Asleep, Fending, Cold, Dead : Boolean := False;
      Carrying : Item_Kind := Nothing;
      Carried  : Natural := 0;
      Grain    : Natural := 0;              --  handfuls with its straw
      Zone     : Natural := 0;              --  the zone it stands in (0: none)
      Level    : Shares := [others => 0.0]; --  its skills, 0 .. 1
      Aptitude : Shares := [others => 1.0]; --  how fast it learns each
      Work     : Work_Kind := Handling;     --  what it is at now, for its practice
      Resting  : Boolean := False;          --  at rest: nothing its job brings in is asked for
      Trade    : Trade_Kind := No_Trade;    --  the trade it is at (a builder: a forester with a house to build)
      Site     : Natural := 0;              --  the house it is building (0: none)
      Home     : Natural := 0;              --  its house (0: none begun),
      Housed   : Boolean := False;          --  and whether it stands
   end record;
   function Person (I : Positive) return Person_View;

   ------------------------------------------------------- demand

   --  Demand starts with the people and runs up the supply chain.  What
   --  is used is asked of the stores (the stockpiles, all of them together);
   --  the player asks for a surplus on top; and what the stores are then
   --  short of is what the band's producers work to bring in.  Nothing else
   --  sets them to work: with what is asked for in store, they stop.
   --
   --  The table has a row for everything asked: who asks, for what, and how
   --  much.  Who asks today:
   --    the people   food: what the band eats in a day (in points; any food
   --                 will do, counted as the pot would make it)
   --    a zone       the camp: logs for its fire, by the day (what it burns
   --                 from an hour before bedtime to waking, and one for the
   --                 cooking; in winter all day), and for its seats, once
   --    the paths    stone, for paving (Stone_Quota, till there are masons
   --                 to ask for it)
   --    an order     a surplus the player wants kept: of wood, straw, meat
   --                 or vegetables (Set_Reserve), and of food, in days (the
   --                 winter store: asked for all year; in winter it is eaten,
   --                 and whoever can still bring food in goes on doing so)
   --  Only an order is set by hand; the rest follow from what is there.
   --
   --  The stores stand at two levels for each good.  One with users is
   --  asked for once the stores are down to its surplus and Ask_Below_Days
   --  of its use, and until they hold the surplus and Ask_Until_Days of it.
   --  One nobody uses by the day is asked for while it is short of what is
   --  wanted (its surplus, and what is wanted once).  Whether each is being
   --  asked for is saved.  Stock is taken once a colony second.
   --
   --  Producers answer what is asked: a forester fells while wood is asked
   --  for, a porter fetches straw and stone while they are, a hunter hunts
   --  while meat is, or food; a gatherer gathers while food is asked for,
   --  or else whichever of its own kinds (Gathered) is, and that alone.
   --  Needs come first as ever: eating, sleeping, fending for oneself and a
   --  cook's gathering when it has nothing to cook ask nobody's leave.
   Ask_Below_Days : constant := 1.0;
   Ask_Until_Days : constant := 2.0;
   Gathered : constant Kind_List := [Vegetables, Berries, Apples];   --  what gatherers bring in

   type Asker is (The_People, A_Zone, The_Paths, An_Order);
   type Ask_Kind is (By_The_Day, Once, Surplus);
   type Demand_Row is record
      Who    : Asker := An_Order;
      Zone   : Natural := 0;           --  A_Zone: which
      By     : Actor := No_One;        --  An_Order: whose (the player's)
      Kind   : Ask_Kind := Surplus;
      Food   : Boolean := False;       --  food of any kind, Amount in points; else What, by its own count
      What   : Item_Kind := Nothing;
      Amount : Natural := 0;           --  By_The_Day: what a day takes
   end record;
   Max_Demand_Rows : constant := 32;
   function Demand_Rows return Natural;
   function Demand_Row_At (K : Positive) return Demand_Row;   --  K in 1 .. Demand_Rows

   --  A good, as the stores stand to it.
   type Good_View is record
      Have    : Natural := 0;       --  stored, carried and on its way (food: points in store and in the pot)
      A_Day   : Natural := 0;       --  what its users take in a day
      Once    : Natural := 0;       --  what is wanted for a use, all told
      Surplus : Natural := 0;       --  what the orders ask kept on top
      Low     : Natural := 0;       --  asked for once the stores are down to this
      High    : Natural := 0;       --  and until they hold this
      Asked   : Boolean := False;   --  it is being asked for now
      Makers  : Natural := 0;       --  the living whose job brings it in
   end record;
   function Demand_For (K : Item_Kind) return Good_View;
   function Food_Demand return Good_View;   --  food as one good, in points
   function Food_A_Day return Natural;      --  points the band eats in a day (0 with needs off)

   function Asked_For (K : Item_Kind) return Boolean;
   --  K is to be brought in now: it is asked for by its own count or, a
   --  food that is hunted or gathered, food is.  This is the one question
   --  every producer puts before it sets out.

   procedure Set_Demand_Chain (On : Boolean);
   --  On (the default): as above.  Off: the colony as it was before there
   --  was a chain, for checks of the work alone and as a baseline: gatherers
   --  never stop, hunters hunt only while meat is short of its reserve, a
   --  wood reserve of none is no limit, and nothing has two levels.  Either
   --  way it sets the wood reserve to what that way of working starts with
   --  (the default surplus on, none off), so it is said before any order for
   --  wood.  Saved with the colony.
   function Demand_Chain return Boolean;

   ------------------------------------------------------- saves

   type Bytes is array (Natural range <>) of Interfaces.Unsigned_8;
   function Save return Bytes;
   procedure Load (B : Bytes; Ok : out Boolean);
   procedure Reset;   --  no colony at all

   ------------------------------------------------------- hunting

   --  A hunter goes for the nearest grown deer of a herd larger than
   --  Spare_Last (so a herd can always breed), while the colony is short
   --  of meat and deer are not spared.  It walks until it is Close_M off,
   --  then stalks (slowly, unseen until it is Castle.Herds.Stalked_M
   --  away) to Shoot_M, and with a clear line draws its short bow (Draw_S)
   --  and looses: a hit is likelier the nearer it is.  Hit or missed, the
   --  herd bolts.  A deer brought down lies where it fell; the hunter
   --  carries it home across its shoulders and butchers it at the
   --  stockpile, its meat and hide going into cells there.
   Spare_Last : constant := 3;
   Close_M    : constant := 30.0;
   Shoot_M    : constant := 18.0;
   Draw_S     : constant := 1.5;
   Butcher_S  : constant := 10.0;
   function Meat_Of (C : Castle.Deer.Class) return Positive;   --  joints of meat a deer gives
   function Hit_Chance (Metres : Float) return Float;

   procedure Set_Spare_Deer (On : Boolean);   --  a protection: deer are not hunted (default off)
   function Spare_Deer return Boolean;

   type Carcass_View is record
      Centre : Vec3;          --  where it lies (or the carrier's feet)
      Turn   : Float;         --  the way its spine lies
      Class  : Castle.Deer.Class;
      Lying  : Boolean;       --  False: carried
      Holder : Natural;       --  carrying it, or 0
   end record;
   function Carcass_Count return Natural;           --  K in 1 .. Carcass_Count
   function Carcass_Used (K : Positive) return Boolean;
   function Carcass_At (K : Positive) return Carcass_View;
   function Kills return Natural;                    --  deer brought down
   function Shots return Natural;                    --  arrows loosed

   type Arrow_View is record
      From, To : Vec3;        --  the bow and where it ends (a deer, or the ground past it)
      Flight   : Float;       --  0 .. 1 along the way; 1: it has landed
      Stuck    : Boolean;     --  missed: it lies in the ground at To
   end record;
   function Arrow_Count return Natural;
   function Arrow_At (K : Positive) return Arrow_View;

end Castle.Colony;
