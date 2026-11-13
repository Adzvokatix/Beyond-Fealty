with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Ada.Unchecked_Conversion;
with Ada.Unchecked_Deallocation;
with Ada.Containers.Hashed_Maps;
with Castle.Blocks; use Castle.Blocks;
with Castle.Buildings;
with Castle.Climate;
with Castle.Dims;   use Castle.Dims;
with Castle.Herds;

package body Castle.Colony is

   use Interfaces;
   use type Castle.Nav.Outcome;
   use type Castle.Bodies.Sex_Kind;
   subtype U64 is Castle.Hash.U64;

   Read_Src    : Block_Reader;
   Write_Src   : Block_Writer;
   Version_Src : Version_Reader;

   procedure Forget_Sources;             --  (below, with what it forgets)

   procedure Set_World (Read : Block_Reader; Write : Block_Writer; Version : Version_Reader) is
   begin
      Read_Src := Read;
      Write_Src := Write;
      Version_Src := Version;
      Forget_Sources;                    --  (another world: its versions are its own)
   end Set_World;

   Find_Src  : Tree_Finder;
   Shape_Src : Tree_Shaper;

   procedure Set_Trees (Find : Tree_Finder; Shape : Tree_Shaper) is
   begin
      Find_Src := Find;
      Shape_Src := Shape;
   end Set_Trees;

   function Mat (Bx, By, Bz : Integer) return Material is (Read_Src (Bx, By, Bz).Mat);

   function Flat_Dist (A, B : Vec3) return Float is (Sqrt ((A.X - B.X) ** 2 + (A.Y - B.Y) ** 2));
   type Integer_Pair is array (1 .. 2) of Integer;

   ------------------------------------------------------------------ state

   Tick_N    : Natural := 0;
   Left_Over : Float := 0.0;
   Now_Hours : Long_Float := 0.0;

   Stake_Set : Boolean := False;
   Stake_At  : Vec3 := (0.0, 0.0, 0.0);
   Band_Seed : U64 := 1;

   --  A stretch of path, as planned: where it runs, and which of its
   --  metres are still to lay (bit K - 1 for metre K from A), as last
   --  counted from the ground.  Known: that count was made on ground that
   --  was in; until it is, every metre is taken to be still to lay.  (The
   --  count is not saved: it is made again from the ground.)
   type Path_Seg is record
      A, B  : Vec3 := (0.0, 0.0, 0.0);
      Todo  : Unsigned_64 := 0;
      Known : Boolean := False;
   end record;
   Path_List : array (1 .. Max_Paths) of Path_Seg;
   N_Paths   : Natural := 0;
   Paths_Left_M : Natural := 0;    --  metres of path still to lay, all told (as last counted)
   Path_Far     : Float := 0.0;    --  how far from the stake the furthest stretch with any to lay reaches
   Path_Turn    : Natural := 0;    --  the stretch last looked at again for anything dug up
   Paths_Stale  : Boolean := True; --  every stretch is to be counted at the next step (a colony just loaded; not saved)
   Stretches_On : Boolean := True; --  a path is laid a stretch to a serf (off: a metre at a time, as it was)

   --  How far from the stake the band is looking for what its camp's
   --  building takes (0: no further than its work), and how far its ground
   --  was in when this Advance began (the band looks no further than one
   --  ring past ground that is in).
   Far_Reach : Float := 0.0;
   Ground_In : Float := 0.0;
   Stone_From : Float := 0.0;      --  (a measuring start: the camp's stone is taken no nearer the stake than this)

   type Cell is record
      Centre   : Vec3;
      Kind     : Item_Kind := Nothing;
      Count    : Natural := 0;
      Incoming : Natural := 0;   --  on its way there, reserved
      Outgoing : Natural := 0;   --  set aside for someone coming to eat it
      Zone     : Natural := 0;   --  the stockpile zone that owns it
      Turn     : Float := 0.0;   --  the way its lot lies (its zone's; not saved)
   end record;
   Cells   : array (1 .. Max_Cells) of Cell;
   N_Cells : Natural := 0;

   --  Zones: the ground the player has marked, each a thing of its own.  A
   --  stockpile's cells name their zone; the camp's own state is below.
   type Zone_Rec is record
      Kind   : Zone_Kind := Stockpile_Zone;
      Lo, Hi : Vec3 := (0.0, 0.0, 0.0);
      Cells  : Natural := 0;     --  the stockpile cells it owns
      Turn   : Float := 0.0;     --  the way its lot lies
      Along, Across : Float := 0.0;   --  its ground's reach that way and across it (worked out from its ground)
      Blocks : Natural := 0;     --  its ground, in block columns
      Built  : Boolean := True;  --  what is built on it stands (the camp's hearth; a stockpile has nothing to build)
      Got    : Per_Kind := [others => 0];   --  delivered for its building, of Build_Takes
      First  : Natural := 0;     --  its ground: Runs (First + 1 .. First + N)
      N      : Natural := 0;
      Bx0, Bx1, By0, By1 : Integer := 0;   --  the block columns its ground lies within
   end record;
   Zones     : array (1 .. Max_Zones) of Zone_Rec;
   N_Zones   : Natural := 0;
   Camp_Zone_N : Natural := 0;   --  the camp's zone (0: no camp)

   --  The zones' ground: strips of block columns, a zone's own together,
   --  rows south to north and west to east within a row.
   type Run_Rec is record
      Y, X0, X1, Z : Integer_16 := 0;
   end record;
   type Run_List is array (Positive range <>) of Run_Rec;
   type Run_Array is array (1 .. Max_Zone_Runs) of Run_Rec;
   type Run_Array_Access is access Run_Array;
   Runs      : constant Run_Array_Access := new Run_Array;
   N_Runs    : Natural := 0;
   Zones_Ver : Natural := 0;     --  moves on whenever any zone's ground does (not saved)

   --  Houses: each one's zone, its frame (how it is made, Castle.Buildings'
   --  Design of its seed, and where it stands), whose it is and how far it
   --  is built.  How many blocks it has, and what they take, are counted
   --  from its blueprint (not saved).
   type House_Rec is record
      Zone     : Natural := 0;
      Seed     : U64 := 0;
      F        : Castle.Buildings.House;
      Owner    : Natural := 0;               --  the member whose it is (0: nobody's just now)
      Pad_Done : Boolean := False;           --  its ground is ready
      Placed   : Natural := 0;               --  blocks of its blueprint laid, in its order
      Built    : Boolean := False;           --  it stands
      Got      : Per_Kind := [others => 0];  --  carried to it: logs, sheaves
      Lying    : Per_Kind := [others => 0];  --  of those, what is not yet laid, in blocks' worth
      Total    : Natural := 0;               --  (its blueprint's blocks,
      Floor_N  : Natural := 0;               --  the last of them that is floor,
      Frame_N  : Natural := 0;               --  the last that is of its frame,
      Walls_N  : Natural := 0;               --  the last that is wall or gable,
      Wood_N   : Natural := 0;               --  the last that is of wood (what takes straw comes after),
      Takes    : Per_Kind := [others => 0];  --  and what they take: logs, sheaves)
   end record;
   Houses       : array (1 .. Max_Houses) of House_Rec;
   N_Houses     : Natural := 0;
   House_Serial : Natural := 0;       --  houses ever begun (the next one's seed is made from it)
   N_Housing    : Natural := 0;       --  housing zones (counted, not saved)
   Lots_Full    : Boolean := False;   --  someone is without a home and no lot was found for one, as things
   Lots_Zones   : Natural := 0;       --  stood then: the zones' version, how many paths and how many houses
   Lots_Paths   : Natural := 0;       --  (none of it saved: only kept to save looking again)
   Lots_Houses  : Natural := 0;
   House_Memos_On : Boolean := True;  --  (off: nothing of housing is kept to save work)
   Housing_Far  : Float := 0.0;       --  how far from the stake the furthest housing zone reaches (counted, not saved)

   type Block_Pos is record
      X, Y, Z : Integer_16 := 0;
   end record;
   type Block_List is array (1 .. Max_Bush_Blocks) of Block_Pos;
   type Bush is record
      Centre      : Vec3;               --  the middle of its blocks, at the ground under it
      Radius      : Float := 0.0;       --  horizontally, middle to the furthest block's edge
      N           : Natural := 0;
      Blocks      : Block_List;
      Ripe        : Natural := 0;       --  blocks still bearing berries (a handful each)
      Reserved_By : Natural := 0;
      Regrow_At   : Long_Float := -1.0; --  game hours; negative: nothing picked
   end record;
   type Bush_Array is array (1 .. Max_Bushes) of Bush;
   type Bush_Array_Access is access Bush_Array;
   Bushes   : constant Bush_Array_Access := new Bush_Array;
   N_Bushes : Natural := 0;

   type Tree_Rec is record
      I, J        : Integer := 0;           --  its cell
      Info        : Tree_Info;
      Down        : Boolean := False;       --  felled (or its trunk gone some other way)
      Reserved_By : Natural := 0;
      Apples      : Natural := 0;           --  apple trees: left on it, in Apple_Year
      Apple_Year  : Integer := -1;          --  the year it was last picked (-1: never)
   end record;
   type Tree_Array is array (1 .. Max_Trees) of Tree_Rec;
   type Tree_Array_Access is access Tree_Array;
   Trees     : constant Tree_Array_Access := new Tree_Array;
   N_Trees   : Natural := 0;
   N_Felled  : Natural := 0;
   Trees_Pending : Boolean := False;   --  a save from before trees: find them once the ground is in

   type Pile is record
      Centre  : Vec3 := (0.0, 0.0, 0.0);
      Turn    : Float := 0.0;
      Count   : Natural := 0;
      Claimed : Natural := 0;               --  its forester is on the way for one
      Owner   : Natural := 0;               --  the forester who felled it; 0: nobody's
   end record;
   Piles   : array (1 .. Max_Piles) of Pile;
   N_Piles : Natural := 0;

   Apples_Safe : Boolean := True;
   Deer_Safe   : Boolean := False;

   type Carcass_Rec is record
      Used   : Boolean := False;
      Centre : Vec3 := (0.0, 0.0, 0.0);
      Turn   : Float := 0.0;
      Class  : Castle.Deer.Class := Castle.Deer.Doe;
      Lying  : Boolean := True;
      Holder : Natural := 0;            --  carrying it
      Owner  : Natural := 0;            --  the hunter who brought it down
   end record;
   Carcasses : array (1 .. Max_Carcasses) of Carcass_Rec;
   N_Carcasses : Natural := 0;
   N_Kills, N_Shots : Natural := 0;
   Needs_On : Boolean := True;    --  the band eats and sleeps
   N_Eaten  : Natural := 0;       --  food points eaten
   N_Deaths : Natural := 0;

   --  the camp: the fire in the middle of its square, the pot over it
   Camp_Set    : Boolean := False;
   Camp_At     : Vec3 := (0.0, 0.0, 0.0);
   Camp_Level  : Integer := -1;   --  the row its floor's top is brought to (-1: the floor is left as it lies)
   Level_On    : Boolean := True; --  a camp's floor is levelled by the band (off: as before it was)
   Seats_Laid  : Natural := 0;
   Fire_Logs   : Natural := 0;    --  stacked by the fire
   Fuel_H      : Float := 0.0;    --  hours of burning left on the fire
   Ember_H     : Float := 0.0;    --  burnt out: hours of its dying down left (0: burning, or out)
   Labour_On : Boolean := True;   --  the camp takes the band's labour (off: as it was before it did)
   Pot_Stew    : Natural := 0;    --  points of stew ready
   Pot_Out     : Natural := 0;    --  of those, set aside for people on their way
   Pot_Raw     : Natural := 0;    --  points (as stew) of what is in the pot, not yet cooked
   Pot_Meat    : Natural := 0;    --  of those, from meat
   Cook_Chosen : Boolean := False;   --  the band has had a cook (the first chooses itself)
   N_Cooked    : Natural := 0;    --  points of stew made
   N_Burnt     : Natural := 0;    --  logs the fire has taken
   In_Pot_N    : array (Item_Kind) of Natural := [others => 0];   --  things put in the pot, all told
   Raw_Eaten_N : array (Item_Kind) of Natural := [others => 0];   --  things eaten raw, all told

   --  arrows in flight or in the ground: for drawing only (not saved)
   type Arrow_Rec is record
      From, To : Vec3 := (0.0, 0.0, 0.0);
      T0       : Natural := 0;          --  the tick it was loosed
      Ticks    : Positive := 1;         --  its flight
      Stuck    : Boolean := False;
      Gone_At  : Natural := 0;          --  the tick it is no longer drawn
   end record;
   Arrows   : array (1 .. Max_Arrows) of Arrow_Rec;
   N_Arrows : Natural := 0;
   Demand      : Per_Kind := [others => 0];   --  wanted for a use (stone: paving)
   Reserves    : Per_Kind := Default_Reserve;   --  the surpluses asked for (with the chain off, Wood: 0 is no limit)

   --  The demand chain: on or off, and whether each good is being asked
   --  for (it is asked for from its low level until its high one).
   Chain_On    : Boolean := True;
   Asking      : array (Item_Kind) of Boolean := [others => False];
   Food_Asking : Boolean := False;
   Stock_Stale : Boolean := True;    --  stock is to be taken at the next step (a colony just loaded from before the chain; not saved)

   --  What each stack looked through holds that porters fetch or gatherers
   --  pull: tall grass, boulders, shallow water, wild vegetables (bits 1, 2,
   --  4, 8).  Set when it is looked through (and when a vegetable grows
   --  back), cleared for a kind when a search finds none of it left there.
   type Source_Grid is array (0 .. Chunks_XY - 1, 0 .. Chunks_XY - 1) of Unsigned_8;
   type Source_Access is access Source_Grid;
   Sources : constant Source_Access := new Source_Grid'[others => [others => 0]];
   function Source_Bit (K : Item_Kind) return Unsigned_8 is
     (case K is when Straw => 1, when Stone => 2, when Water => 4, when Vegetables => 8, when others => 0);

   --  What a search found in a stack, kept until the stack's ground changes
   --  (Find_Source): where each source of a kind is, in the order the
   --  search comes to them.  A search used to read every cell's floors and
   --  blocks anew, every time anyone looked for the nearest of anything:
   --  with forty-eight looking, more than a third of the colony's time.
   --  Kept by the ground versions of the stack and of the four beside it (a
   --  boulder is a source only while a block beside it is open, which may
   --  be the next stack's).  Never saved, and nothing is decided by whether
   --  it is there: the same places come out in the same order.
   type Source_List is array (Positive range <>) of Block_Pos;
   type Source_List_Access is access Source_List;
   procedure Free is new Ada.Unchecked_Deallocation (Source_List, Source_List_Access);
   type Source_Memo is record
      V, VE, VW, VN, VS : Natural := 0;       --  as read (V 0: never)
      L                 : Source_List_Access; --  null: none
   end record;
   subtype Memo_Slot is Integer range 0 .. 3;  --  straw, stone, water, vegetables
   type Stack_Memos is array (Memo_Slot) of Source_Memo;
   type Stack_Memos_Access is access Stack_Memos;
   procedure Free is new Ada.Unchecked_Deallocation (Stack_Memos, Stack_Memos_Access);
   type Memo_Grid is array (0 .. Chunks_XY - 1, 0 .. Chunks_XY - 1) of Stack_Memos_Access;
   type Memo_Grid_Access is access Memo_Grid;
   Memos : constant Memo_Grid_Access := new Memo_Grid'[others => [others => null]];
   Memos_On : Boolean := True;                 --  (off: every search reads the ground, as it did)

   procedure Forget_Sources is
   begin
      for M of Memos.all loop
         if M /= null then
            for S of M.all loop
               Free (S.L);
            end loop;
            Free (M);
         end if;
      end loop;
   end Forget_Sources;

   procedure Set_Source_Memos (On : Boolean) is
   begin
      Memos_On := On;
      Forget_Sources;
   end Set_Source_Memos;

   --  Fail memos hold bushes as themselves, and the rest past them.
   Cell_Base : constant := Max_Bushes;
   Tree_Base_Id : constant := 8_192;
   Pile_Base_Id : constant := 16_384;

   type Indexed_Grid is array (0 .. Chunks_XY - 1, 0 .. Chunks_XY - 1) of Boolean with Pack;
   type Indexed_Access is access Indexed_Grid;
   Indexed : constant Indexed_Access := new Indexed_Grid'[others => [others => False]];

   type Task_State is (Idle, To_Bush, Picking, To_Store, Storing, Strolling,
                       To_Tree, Chopping, To_Pile, Lifting, To_Source, Gathering,
                       Stalking, Aiming, Recovering, To_Carcass, Lifting_Carcass, To_Butcher, Butchering,
                       To_Eat, Eating, To_Bed, Sleeping,
                       To_Take, Taking, To_Camp, Putting_In, Cooking, To_Seat,
                       Stoking, To_Patch, Tamping,
                       To_Site, Raising);
   --  (To_Site, Raising: a builder going to its house's site, and at work there)
   --  (saved by position: new states go on the end, as below)
   type Why_Idle is (Nothing_Yet, No_Bush, No_Room, No_Way, No_Tree, Enough_Wood, Nothing_To_Haul,
                     No_Source, Stocks_Full, No_Prey, Enough_Meat, Deer_Spared,
                     No_Camp, Pot_Full, Nothing_To_Cook, Winter_Bare, Enough_Food, Camp_Unbuilt,
                     No_Timber, No_Thatch);
   --  (No_Timber, No_Thatch: a builder with no wood, or no straw, to build with)
   --  what the cook is bringing to the camp (For_Store: nothing, its load is for a stockpile)
   --  (For_Stoke: no load at all: it goes to put a log from the stack on
   --  the fire.  For_Ring, For_Frame: stone and wood to build the hearth with,
   --  which anyone may be bringing, as a seat log.)
   --  (For_Floor: earth, for a hollow of the camp's floor.)
   --  (For_House: wood or straw, for the house it is building.)
   type Camp_Use is (For_Store, For_Pot, For_Fire, For_Seat, For_Stoke, For_Ring, For_Frame, For_Floor, For_House);
   type Fail_Memo is record
      Bush  : Natural := 0;
      Until_Tick : Natural := 0;
   end record;
   type Fail_List is array (1 .. 8) of Fail_Memo;

   --  Levels are kept finer than they are shown: a step's practice is a
   --  millionth of a level, and a Float would lose the small fractions that
   --  go to the skills beside the work's own.
   type Level_List is array (Skill_Kind) of Long_Float;

   type Member is record
      Seed     : U64 := 0;
      Child, Elder : Boolean := False;
      G        : Castle.Bodies.Genome;
      Name     : Natural := 0;
      Job      : Job_Kind := Unassigned;
      Pos, Prev : Vec3 := (0.0, 0.0, 0.0);
      State    : Task_State := Idle;
      Why      : Why_Idle := Nothing_Yet;
      Route    : aliased Castle.Nav.Route;
      Leg      : Positive := 1;
      Along    : Float := 0.0;
      Pace     : Float := 0.0;
      Speed    : Float := 1.3;          --  its own pace on grass
      Check_Tick : Natural := 0;
      Replan   : Boolean := False;      --  loaded mid-walk: find the way again
      Bush     : Natural := 0;
      Cell     : Natural := 0;
      Tree     : Natural := 0;
      Pile     : Natural := 0;
      Fetch    : Item_Kind := Nothing;   --  porters: what it is out for
      Tgt      : Block_Pos;              --  and the block it is getting it from
      Prey     : Natural := 0;           --  hunters: the deer (Castle.Herds) it is after
      Prize    : Natural := 0;           --  the carcass it is going for or carrying
      Cell2    : Natural := 0;           --  butchering: the cell for the hide (Cell: the meat's)
      Goal     : Vec3 := (0.0, 0.0, 0.0);
      Carry    : Item_Kind := Nothing;
      Carried  : Natural := 0;
      Work     : Float := 0.0;
      Wait     : Float := 0.0;
      Spot     : Vec3 := (0.0, 0.0, 0.0);
      Fails    : Fail_List;
      Thoughts : Natural := 0;
      Fed      : Float := 1.0;           --  of a full belly
      Ration   : Natural := 0;           --  food points it is going for, or eating
      From_Pot : Boolean := False;       --  that meal is stew from the pot
      Seat     : Natural := 0;           --  eating stew: its place at the fire (0: standing at the pot)
      Had_Stew : Boolean := False;       --  its last meal was stew
      Due      : Natural := 0;           --  things set aside for it in Cell, to take
      Use_For  : Camp_Use := For_Store;  --  the cook: what its load is for
      Grain    : Natural := 0;           --  handfuls of grain carried with its straw
      Fends    : Boolean := False;       --  gathering for itself, its job left
      Mood     : Float := Mood_Start;
      Empty_H  : Float := 0.0;           --  game hours its belly has been empty, in winter
      Is_Dead  : Boolean := False;
      Director : Actor := No_One;        --  who gave it its job (no one: unassigned, or its own choice)
      Patch    : Natural := 0;           --  the patch of the camp's ground it is going to make ready, or is at
      Site_Seg : Natural := 0;           --  or the stretch of path it has to lay (its own, till it leaves it),
      Site_M   : Natural := 0;           --  the metre of it it is going to, or is at (0: between two),
      Site_Laid : Natural := 0;          --  and the metres it has laid since it was given a stretch
      Site     : Natural := 0;           --  a builder: the house it is building (its own, till it stands)
      Site_Patch : Natural := 0;         --  and the patch of that house's ground it is going to, or is at (0: laying blocks)
      Skill    : Level_List := [others => 0.0];   --  its level in each skill, 0 .. 1
      Apt      : Shares := [others => 1.0];       --  its aptitude for each (from its seed: not saved)
   end record;
   type Member_Array is array (1 .. Max_Members) of aliased Member;
   type Member_Array_Access is access Member_Array;
   Band      : constant Member_Array_Access := new Member_Array;
   N_Members : Natural := 0;

   Men_Names : constant array (0 .. 19) of access constant String :=
     [new String'("Aldric"), new String'("Bertram"), new String'("Cedric"), new String'("Edmund"),
      new String'("Godric"), new String'("Hugh"), new String'("Osric"), new String'("Wat"),
      new String'("Piers"), new String'("Roger"), new String'("Walter"), new String'("Gilbert"),
      new String'("Ralf"), new String'("Simon"), new String'("Thomas"), new String'("Geoffrey"),
      new String'("Alan"), new String'("Hamo"), new String'("Odo"), new String'("Robin")];
   Women_Names : constant array (0 .. 19) of access constant String :=
     [new String'("Agnes"), new String'("Alys"), new String'("Beatrice"), new String'("Cecily"),
      new String'("Edith"), new String'("Emma"), new String'("Isabel"), new String'("Joan"),
      new String'("Matilda"), new String'("Margery"), new String'("Rose"), new String'("Sibyl"),
      new String'("Alice"), new String'("Mabel"), new String'("Juliana"), new String'("Avice"),
      new String'("Gunnild"), new String'("Hawise"), new String'("Lettice"), new String'("Maud")];

   ------------------------------------------------------------------ small things

   function Name (K : Item_Kind) return String is
     (case K is
         when Nothing => "nothing", when Berries => "berries", when Wood => "wood",
         when Stone => "stone", when Water => "water", when Straw => "straw",
         when Meat => "meat", when Hide => "hides", when Carcass => "a deer",
         when Vegetables => "vegetables", when Apples => "apples", when Sticks => "sticks",
         when Grain => "grain",
         when Earth => "earth");

   function Ticks return Natural is (Tick_N);

   function Meat_Of (C : Castle.Deer.Class) return Positive is
     (case C is when Castle.Deer.Fawn => 3, when Castle.Deer.Doe => 8, when Castle.Deer.Young_Stag => 6,
                when Castle.Deer.Stag => 10);
   function Hit_Chance (Metres : Float) return Float is
     (Float'Max (0.25, Float'Min (0.85, 0.95 - 0.03 * Metres)));
   procedure Set_Spare_Deer (On : Boolean) is
   begin
      Deer_Safe := On;
   end Set_Spare_Deer;
   function Spare_Deer return Boolean is (Deer_Safe);
   function Carcass_Count return Natural is (N_Carcasses);
   function Carcass_Used (K : Positive) return Boolean is (Carcasses (K).Used);
   function Kills return Natural is (N_Kills);
   function Shots return Natural is (N_Shots);
   function Arrow_Count return Natural is (N_Arrows);
   function Arrow_At (K : Positive) return Arrow_View is
     ((From => Arrows (K).From, To => Arrows (K).To,
       Flight => Float'Min (1.0, Float (Tick_N - Arrows (K).T0) / Float (Arrows (K).Ticks)),
       Stuck => Arrows (K).Stuck));
   function Blend return Float is (Float'Min (1.0, Left_Over / Tick_S));
   function Has_Stake return Boolean is (Stake_Set);
   function Stake return Vec3 is (Stake_At);
   function Members return Natural is (N_Members);
   function Genome_Of (I : Positive) return Castle.Bodies.Genome is (Band (I).G);
   function Name_Of (I : Positive) return String is
     (if Band (I).G.Sex = Castle.Bodies.Male then Men_Names (Band (I).Name).all
      else Women_Names (Band (I).Name).all);
   function Job_Of (I : Positive) return Job_Kind is (Band (I).Job);
   function Director_Of (I : Positive) return Actor is (Band (I).Director);
   function Carrying (I : Positive) return Item_Kind is (Band (I).Carry);
   function Carried (I : Positive) return Natural is (Band (I).Carried);
   function Route_Of (I : Positive) return Route_View is (Band (I).Route'Access);
   function Leg_Of (I : Positive) return Positive is (Band (I).Leg);
   function Work_Spot (I : Positive) return Vec3 is (Band (I).Spot);

   function Where (I : Positive) return Vec3 is
      M : Member renames Band (I);
      T : constant Float := Blend;
   begin
      return (M.Prev.X + (M.Pos.X - M.Prev.X) * T, M.Prev.Y + (M.Pos.Y - M.Prev.Y) * T,
              M.Prev.Z + (M.Pos.Z - M.Prev.Z) * T);
   end Where;

   --  A hunter close enough to its deer to be creeping up on it.
   function Sneaking_Now (I : Positive) return Boolean is
     (Band (I).State = Stalking and then Band (I).Prey > 0 and then Castle.Herds.Alive (Band (I).Prey)
      and then Flat_Dist (Band (I).Pos, Castle.Herds.Where (Band (I).Prey)) <= Close_M);

   function Carcass_At (K : Positive) return Carcass_View is
      C : Carcass_Rec renames Carcasses (K);
   begin
      return (Centre => (if not C.Lying and then C.Holder in 1 .. N_Members then Band (C.Holder).Pos else C.Centre),
              Turn => C.Turn, Class => C.Class, Lying => C.Lying, Holder => C.Holder);
   end Carcass_At;

   function Doing (I : Positive) return Act is
     (if Band (I).Is_Dead then Dead else
     (case Band (I).State is
         when To_Bush | To_Store | Strolling | To_Tree | To_Pile | To_Source =>
           (if Band (I).Route.N >= 2 and then Band (I).Leg < Band (I).Route.N then Walking else Standing),
         when Picking => Picking,
         when Storing | Lifting => Putting_Down,
         when Chopping => Chopping,
         when Gathering => (if Band (I).Fetch in Straw | Vegetables | Apples then Picking else Putting_Down),
         when Stalking | To_Carcass | To_Butcher =>
           (if Band (I).Route.N >= 2 and then Band (I).Leg < Band (I).Route.N
            then (if Band (I).State = Stalking and then Sneaking_Now (I) then Sneaking else Walking)
            else Standing),
         when Aiming => Aiming,
         when Lifting_Carcass | Butchering => Putting_Down,
         when To_Eat | To_Bed | To_Take | To_Camp | To_Seat | To_Patch | To_Site =>
           (if Band (I).Route.N >= 2 and then Band (I).Leg < Band (I).Route.N then Walking else Standing),
         when Tamping | Raising => Picking,
         when Eating =>
           (if Band (I).From_Pot and then Band (I).Seat > 0 and then (Band (I).Seat + 1) / 2 <= Seats_Laid
            then Eating_Seated else Eating),
         when Sleeping => Sleeping,
         when Taking | Putting_In | Stoking => Putting_Down,
         when Cooking => Stirring,
         when Recovering | Idle => Standing));

   function Status (I : Positive) return String is separate;

   function Hash01 (M : Member; K : Natural) return Float is
     (Castle.Hash.Unit (Castle.Hash.Hash_2 (M.Seed, K, M.Thoughts)));

   ------------------------------------------------------------------ needs: the measures


   function Size_Of (M : Member) return Float is
     (if M.Child then 0.6 elsif M.Elder then 0.8 else 1.0);

   function Belly_Points (M : Member) return Float is
     (Float (Day_Food) * Belly_Hours / 24.0 * Size_Of (M));

   --  Points to fill it up (at least one).
   function Want_Points (M : Member) return Positive is
     (Positive'Max (1, Natural (Float'Ceiling ((1.0 - M.Fed) * Belly_Points (M)))));

   function Hour_Of_Day return Float is
     (Float (Now_Hours - 24.0 * Long_Float'Floor (Now_Hours / 24.0)));

   --  Its night: Bed_Hour to Wake_Hour, children an hour and elders half an
   --  hour earlier to bed, give or take a little for each (from its seed).
   function Bedtime (M : Member) return Boolean is
      J    : constant Float := 0.8 * (Castle.Hash.Unit (Castle.Hash.Mix (M.Seed + 77)) - 0.5);
      Bed  : constant Float := Bed_Hour + J - (if M.Child then 1.0 elsif M.Elder then 0.5 else 0.0);
      Wake : constant Float := Wake_Hour + 0.5 * J;
      H    : constant Float := Hour_Of_Day;
   begin
      return Needs_On and then (H >= Bed or else H < Wake);
   end Bedtime;

   function Winter_Now return Boolean is
     (Castle.Climate."=" (Castle.Climate.Season_Of (Castle.Climate.Day_Of_Year (Now_Hours)), Castle.Climate.Winter));

   Store_Days : Natural := 0;   --  the winter store order
   function Held_Days return Float;

   --  How fast it walks and works: slower with an empty belly.  (Its
   --  condition: the first factor of every work rate.)
   function Vigour (M : Member) return Float is
     (if Needs_On and then M.Fed <= 0.0 then Starving_Pace else 1.0);

   ------------------------------------------------------------------ skills

   Skills_On : Boolean := True;

   function Name (S : Skill_Kind) return String is
     (case S is
         when Gathering => "gathering", when Forestry => "forestry", when Hunting => "hunting",
         when Portering => "portering", when Cooking => "cooking", when Building => "building",
         when Carpentry => "carpentry", when Stonework => "stonework", when Farming => "farming",
         when Tanning => "tanning", when Taming => "taming");

   --  Aptitudes and start levels come from the member's seed, each skill by
   --  a number of its own.  Cooking's is the one Cooking_Of always used.
   Apt_Salt : constant array (Skill_Kind) of U64 :=
     [Cooking => 4_051, Gathering => 4_057, Forestry => 4_073, Hunting => 4_079, Portering => 4_091,
      Building => 4_093, Carpentry => 4_099, Stonework => 4_111, Farming => 4_127, Tanning => 4_129,
      Taming => 4_133];

   function Aptitude_From (Seed : U64; S : Skill_Kind) return Float is
     (Aptitude_Lo + (Aptitude_Hi - Aptitude_Lo) * Castle.Hash.Unit (Castle.Hash.Mix (Seed + Apt_Salt (S))));

   function Start_Level (M : Member; S : Skill_Kind) return Long_Float is
      U : constant Float := Castle.Hash.Unit (Castle.Hash.Mix (M.Seed + Apt_Salt (S) + 1_000));
      Young : constant Float := (if M.Child then Child_Start else 1.0);
   begin
      if S in Working_Skill then
         return Long_Float
           (Float'Min (1.0, (Start_Lo + (Start_Hi - Start_Lo) * U + (if M.Elder then Elder_Start else 0.0)) * Young));
      end if;
      return Long_Float (Trade_Start * U * Young);
   end Start_Level;

   --  What it arrives with (and what a save from before skills gives it).
   procedure Give_Skills (M : in out Member) is
   begin
      for S in Skill_Kind loop
         M.Apt (S) := Aptitude_From (M.Seed, S);
         M.Skill (S) := Start_Level (M, S);
      end loop;
   end Give_Skills;

   --  The skill factor of a work rate: 1 for what has no skill in it, and
   --  for everything with skills off.
   function Skill_Factor (M : Member; W : Work_Kind) return Float is
     (if not Skills_On or else W = Handling then 1.0
      else Novice_Rate + (Master_Rate - Novice_Rate) * Float (M.Skill (Own_Skill (W))));

   --  What whoever directs it adds: nothing yet (a trade that directs
   --  helpers will answer here by the director's skill).
   function Direction (M : Member) return Float is
      pragma Unreferenced (M);
   begin
      return 1.0;
   end Direction;

   --  rate = condition x skill x direction: every work timer goes by this.
   function Work_Rate (M : Member; W : Work_Kind) return Float is
     (Vigour (M) * Skill_Factor (M, W) * Direction (M));

   --  The work that getting or carrying K is.
   function Work_For (K : Item_Kind) return Work_Kind is
     (case K is
         when Berries | Vegetables | Apples => Picking,
         when Wood                          => Felling,
         when Straw | Grain                 => Reaping,
         when Stone                         => Quarrying,
         when Water                         => Drawing_Water,
         when Sticks                        => Camp_Keeping,
         when Meat | Hide | Carcass         => Butchering,
         when Earth                         => Site_Work,
         when Nothing                       => Handling);

   --  One step of practice at work W: its own skill in full, the skills
   --  beside it by their shares, each closing on mastery by its aptitude.
   procedure Practise (M : in out Member; W : Work_Kind) is
      Hours : constant Long_Float := Long_Float (Tick_S / 60.0 * Vigour (M));
   begin
      if W = Handling then
         return;
      end if;
      for S in Skill_Kind loop
         if Learns (W) (S) > 0.0 then
            M.Skill (S) := M.Skill (S)
              + Hours * Long_Float (Learns (W) (S) * M.Apt (S)) / Long_Float (Learn_Hours) * (1.0 - M.Skill (S));
         end if;
      end loop;
   end Practise;

   --  What it is at, for its practice: the whole trip is the work (going
   --  out, the work itself, carrying it home), by what is being got or
   --  carried, whatever its job.
   function Work_Now (M : Member) return Work_Kind is
     (case M.State is
         when To_Bush | Picking                                   => Picking,
         when To_Source | Gathering                               => Work_For (M.Fetch),
         when To_Store | Storing                                  => (if M.Carried > 0 then Work_For (M.Carry)
                                                                      else Handling),
         when To_Tree | Chopping | To_Pile | Lifting              => Felling,
         when Stalking | Aiming | Recovering                      => Stalking_Game,
         when To_Carcass | Lifting_Carcass | To_Butcher | Butchering => Butchering,
         when To_Take | Taking | To_Camp | Putting_In | Cooking | Stoking =>
           (if M.Use_For in For_Ring | For_Frame then Site_Work
            elsif M.Use_For = For_House then House_Raising else Camp_Keeping),
         when To_Patch | Tamping                                  => Site_Work,
         when To_Site | Raising                                   =>
           (if M.Site_Patch > 0 then Site_Work else House_Raising),
         when Idle | Strolling | To_Eat | Eating | To_Bed | Sleeping | To_Seat => Handling);

   procedure Set_Skills (On : Boolean) is
   begin
      Skills_On := On;
   end Set_Skills;
   function Skills return Boolean is (Skills_On);
   function Skill_Of (I : Positive; S : Skill_Kind) return Float is (Float (Band (I).Skill (S)));
   function Aptitude_Of (I : Positive; S : Skill_Kind) return Float is (Band (I).Apt (S));
   procedure Set_Skill (I : Positive; S : Skill_Kind; Level : Float) is
   begin
      Band (I).Skill (S) := Long_Float (Float'Max (0.0, Float'Min (1.0, Level)));
   end Set_Skill;
   function Has_Skill (J : Job_Kind) return Boolean is (J /= Unassigned);
   function Job_Skill (J : Job_Kind) return Skill_Kind is
     (case J is
         when Gatherer => Gathering, when Forester => Forestry, when Hunter => Hunting,
         when Porter => Portering, when Cook | Unassigned => Cooking);
   function Work_Of (I : Positive) return Work_Kind is
     (if Band (I).Is_Dead then Handling else Work_Now (Band (I)));
   function Work_Rate_Of (I : Positive; W : Work_Kind) return Float is (Work_Rate (Band (I), W));
   function Direction_Of (I : Positive) return Float is (Direction (Band (I)));
   function Hit_Chance_Of (I : Positive; Metres : Float) return Float is
     (if not Skills_On then Hit_Chance (Metres)
      else Float'Min (Best_Aim, Hit_Chance (Metres)
                                * (Novice_Aim + (Master_Aim - Novice_Aim) * Float (Band (I).Skill (Hunting)))));
   function Pot_Yield_Of (I : Positive) return Float is
     (if not Skills_On then 0.9 + 0.2 * Cooking_Of (I)
      else Novice_Pot + (Master_Pot - Novice_Pot) * Float (Band (I).Skill (Cooking)));

   ------------------------------------------------------------------ the ground

   --  The top of the ground at block column (Bx, By) near row Near: the
   --  first solid block, scanning down from 2 m above, with open rows over
   --  it.  -1 if none within 6 m.
   function Ground_Row (Bx, By, Near : Integer) return Integer is
   begin
      for Z in reverse Integer'Max (1, Near - 16) .. Near + 8 loop
         if Class_Of (Mat (Bx, By, Z)) = Solid and then Class_Of (Mat (Bx, By, Z + 1)) /= Solid then
            return Z;
         end if;
      end loop;
      return -1;
   end Ground_Row;

   function B (M : Float) return Integer is (Integer (Float'Floor (M * 4.0)));

   function In_A_House (Bx, By, Bz : Integer) return Boolean;     --  (its body is with the houses, below)

   ------------------------------------------------------------------ bushes

   function Bush_Slots return Natural is (N_Bushes);
   function Bush_Alive (K : Positive) return Boolean is (Bushes (K).N > 0);

   function Bush_Count return Natural is
      N : Natural := 0;
   begin
      for K in 1 .. N_Bushes loop
         if Bushes (K).N > 0 then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Bush_Count;

   function Ripe_Bushes return Natural is
      N : Natural := 0;
   begin
      for K in 1 .. N_Bushes loop
         if Bushes (K).Ripe > 0 then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Ripe_Bushes;

   function Bush_Centre (K : Positive) return Vec3 is (Bushes (K).Centre);
   function Bush_Radius (K : Positive) return Float is (Bushes (K).Radius);
   function Bush_Ripe (K : Positive) return Natural is (Bushes (K).Ripe);
   function Bush_Reserved_By (K : Positive) return Natural is (Bushes (K).Reserved_By);

   function Berries_Left return Natural is
      N : Natural := 0;
   begin
      for K in 1 .. N_Bushes loop
         N := N + Bushes (K).Ripe;
      end loop;
      return N;
   end Berries_Left;

   ------------------------------------------------------------------ trees and logs

   function Chop_S (T : Tree_Info) return Float is
     (if T.Trunk_W >= 2 then 24.0 else 12.0);
   function Logs_Of (T : Tree_Info) return Positive is
     (Integer'Max (1, Integer'Min (8, (T.Trunk_H * T.Trunk_W) / 8)));
   function Tree_Count return Natural is (N_Trees);
   function Tree_At (K : Positive) return Tree_Info is (Trees (K).Info);
   function Tree_Base (K : Positive) return Vec3 is
     ((Float (Trees (K).Info.Bx) + Float (Trees (K).Info.Trunk_W) * 0.5) * 0.25,
      (Float (Trees (K).Info.By) + Float (Trees (K).Info.Trunk_W) * 0.5) * 0.25,
      Float (Trees (K).Info.Bz) * 0.25);
   function Tree_Down (K : Positive) return Boolean is (Trees (K).Down);
   function Tree_Reserved_By (K : Positive) return Natural is (Trees (K).Reserved_By);
   function Trees_Felled return Natural is (N_Felled);
   function Half_W (K : Positive) return Float is (Float (Trees (K).Info.Trunk_W) * 0.125);

   --  Apples: on the trees from summer's tenth day to the end of autumn,
   --  about Apple_Yield to a tree each year (a tree not yet picked this
   --  year bears its full crop).
   function Year_Now return Integer is
     (Integer (Long_Float'Floor (Now_Hours / (24.0 * Long_Float (Castle.Climate.Days_Per_Year)))));
   function Apple_Season return Boolean is
     (Castle.Climate.Day_Of_Year (Now_Hours) >= Apples_From_Day
      and then Castle.Climate.Day_Of_Year (Now_Hours) < Apples_To_Day);
   function Yield_Of (K : Positive) return Natural is
     (Apple_Yield - 10 + Natural (Float'Floor (20.0 * Castle.Hash.Unit_2 (91, Trees (K).I, Trees (K).J))));
   function Apples_On (K : Positive) return Natural is
     (if Trees (K).Info.Kind /= Apple or else Trees (K).Down or else not Apple_Season then 0
      elsif Trees (K).Apple_Year /= Year_Now then Yield_Of (K) else Trees (K).Apples);
   procedure Pick_Apple (K : Positive) is
   begin
      if Trees (K).Apple_Year /= Year_Now then
         Trees (K).Apple_Year := Year_Now;
         Trees (K).Apples := Yield_Of (K);
      end if;
      if Trees (K).Apples > 0 then
         Trees (K).Apples := Trees (K).Apples - 1;
      end if;
   end Pick_Apple;

   function Pile_Count return Natural is (N_Piles);
   function Pile_At (K : Positive) return Pile_View is
     ((Piles (K).Centre, Piles (K).Turn, Piles (K).Count, Piles (K).Owner));
   function Logs_Lying return Natural is
      N : Natural := 0;
   begin
      for K in 1 .. N_Piles loop
         N := N + Piles (K).Count;
      end loop;
      return N;
   end Logs_Lying;


   procedure Set_Protect_Apples (On : Boolean) is
   begin
      Apples_Safe := On;
   end Set_Protect_Apples;
   function Protect_Apples return Boolean is (Apples_Safe);
   procedure Set_Wood_Reserve (Logs : Natural) is
   begin
      Reserves (Wood) := Logs;
   end Set_Wood_Reserve;
   function Wood_Reserve return Natural is (Reserves (Wood));
   procedure Set_Reserve (K : Item_Kind; N : Natural) is
   begin
      Reserves (K) := N;
   end Set_Reserve;
   function Reserve_Of (K : Item_Kind) return Natural is (Reserves (K));

   function Key_Of (X, Y, Z : Integer) return U64 is
     (U64 (X) * 2 ** 32 + U64 (Y) * 2 ** 12 + U64 (Z));
   function Hash_Key (K : U64) return Ada.Containers.Hash_Type is
     (Ada.Containers.Hash_Type (Castle.Hash.Mix (K) and 16#FFFF_FFFF#));
   package Block_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type => U64, Element_Type => Positive, Hash => Hash_Key, Equivalent_Keys => "=");

   Bush_Of : Block_Maps.Map;   --  every indexed bush block: which bush it is in
   Tree_Of : Block_Maps.Map;   --  every indexed tree, by its cell (Key_Of (I, J, 0))

   --  The trees whose trunks stand in stack (CX, CY); one already felled
   --  (its first block above the stump gone) is taken as down.
   procedure Index_Trees (CX, CY : Integer) is separate;

   --  Middle, reach, and ripe blocks again, from a bush's block list.
   procedure Refresh (K : Positive) is separate;

   --  Find the bushes in stack (CX, CY): every berry bush block (ripe or
   --  picked) within 3 m above the floors a serf can stand on there, taken
   --  apart into bushes by touching blocks.  A bush reaching across into a
   --  stack already looked through is joined to the bush found there (unless
   --  someone is on the way to pick that one: then it stays apart).
   --  Far: past where anyone gathers: its boulders and trees are noted, its bushes are not.
   procedure Index_Stack (CX, CY : Integer; Far : Boolean := False) is separate;

   --  Stacks within reach of the stake not looked through yet, nearest
   --  first; up to Budget of them now.
   procedure Index_Some (Budget : Natural) is separate;

   procedure Index_All is
   begin
      Index_Some (Natural'Last);
   end Index_All;

   --  Wild vegetables pulled, to grow back: where, and when.
   type Pulled_Rec is record
      P    : Block_Pos;
      At_H : Long_Float := 0.0;
   end record;
   Pulled   : array (1 .. Max_Pulled) of Pulled_Rec;
   N_Pulled : Natural := 0;
   N_Pulled_All : Natural := 0;   --  all told

   procedure Remember_Pulled (P : Block_Pos) is
      Oldest : Positive := 1;
   begin
      N_Pulled_All := N_Pulled_All + 1;
      if N_Pulled < Max_Pulled then
         N_Pulled := N_Pulled + 1;
         Pulled (N_Pulled) := (P, Now_Hours);
         return;
      end if;
      for K in 2 .. N_Pulled loop                  --  full: the oldest gives way
         if Pulled (K).At_H < Pulled (Oldest).At_H then
            Oldest := K;
         end if;
      end loop;
      Pulled (Oldest) := (P, Now_Hours);
   end Remember_Pulled;

   function Vegetables_Pulled return Natural is (N_Pulled_All);

   --  Bushes picked long enough ago bear again, and vegetables pulled grow
   --  back where there is still open ground for them, except in winter.
   procedure Regrow is separate;

   ------------------------------------------------------------------ walking

   function Failed (M : Member; Bush : Natural) return Boolean is
   begin
      for F of M.Fails loop
         if F.Bush = Bush and then Tick_N < F.Until_Tick then
            return True;
         end if;
      end loop;
      return False;
   end Failed;

   procedure Remember_Failure (M : in out Member; Bush : Natural; Seconds : Positive := 60) is
      Oldest : Positive := 1;
   begin
      for K in M.Fails'Range loop
         if M.Fails (K).Until_Tick < M.Fails (Oldest).Until_Tick then
            Oldest := K;
         end if;
      end loop;
      M.Fails (Oldest) := (Bush => Bush, Until_Tick => Tick_N + Seconds * Tick_Hz);
   end Remember_Failure;

   --  A route from where M stands to Goal; True if it gets there (or, for
   --  Near > 0, ends within Near metres of it).
   function Route_To (M : in out Member; Goal : Vec3; Near : Float := 0.0) return Boolean is
   begin
      M.Route := Castle.Nav.Plan (M.Pos, Goal);
      M.Leg := 1;
      M.Along := 0.0;
      M.Check_Tick := Tick_N + Tick_Hz / 2;
      M.Goal := Goal;
      if M.Route.N < 2 then
         M.Route.N := 0;
         return M.Route.Result = Castle.Nav.Found and then Flat_Dist (M.Pos, Goal) <= Float'Max (0.3, Near);
      end if;
      return M.Route.Result = Castle.Nav.Found
        or else (Near > 0.0 and then Flat_Dist (M.Route.Pts (M.Route.N).P, Goal) <= Near);
   end Route_To;

   --  One step along the route; True once at its end (or, Stop_Within > 0,
   --  that close to Stop_At).
   function Walk (M : in out Member; Stop_At : Vec3; Stop_Within : Float; Scale : Float := 1.0) return Boolean is separate;

   --  Walk, to the end of the route it planned (M.Goal).
   function Walk_On (M : in out Member; Within : Float) return Boolean is
      Goal : constant Vec3 := M.Goal;
   begin
      return Walk (M, Goal, Within);
   end Walk_On;

   --  Twice a second: whether the ground under the rest of the route has
   --  changed so that it can't be walked; then the way is found again.
   --  How near the goal a route may end for the work M is going to.
   function Near_Of (M : Member) return Float is
     (case M.State is
         when To_Bush => (if M.Bush > 0 then Bushes (M.Bush).Radius + 0.7 else 0.0),
         when To_Tree => (if M.Tree > 0 then Half_W (M.Tree) + 0.9 else 0.0),
         when To_Pile => 1.0,
         when To_Patch => (if M.Site_Seg > 0 then 0.7 else Patch_Reach_M),
         when To_Site => Build_Reach_M,
         when To_Source => (if M.Fetch in Sticks | Apples then 1.2 else 0.0),
         when others  => 0.0);

   procedure Keep_Route_Good (M : in out Member; Ok : out Boolean) is separate;

   ------------------------------------------------------------------ deciding

   procedure Release (M : in out Member; I : Positive) is separate;

   --  The nearest ripe bush nobody else is after, weighed toward the stake
   --  (half the distance from the stake counts too), that a route reaches.
   function Go_Pick (I : Positive) return Boolean is separate;

   --  The nearest stockpile cell that takes what M carries: one already
   --  holding it with room, else an empty one.
   function Go_Store (I : Positive) return Boolean is separate;

   function Wood_Total return Natural is
      N : Natural := Stored (Wood) + Logs_Lying;
   begin
      for I in 1 .. N_Members loop
         if Band (I).Carry = Wood then
            N := N + Band (I).Carried;
         end if;
      end loop;
      return N;
   end Wood_Total;

   function Room_For (K : Item_Kind) return Boolean is
   begin
      for C in 1 .. N_Cells loop
         if (Cells (C).Kind = K and then Cells (C).Count + Cells (C).Incoming + 1 <= Cell_Limit (K))
           or else (Cells (C).Kind = Nothing and then Cells (C).Incoming = 0)
         then
            return True;
         end if;
      end loop;
      return False;
   end Room_For;

   --  The nearest standing tree nobody else is felling, weighed toward the
   --  stake as bushes are, that may be felled (apple trees are kept while
   --  that order stands) and that a route reaches.
   function Go_Fell (I : Positive) return Boolean is separate;

   --  Whether forester I may carry from pile K: its own, or one whose
   --  forester has gone to other work (it takes that one over).
   function Its_Pile (K : Positive; I : Positive) return Boolean is
     (Piles (K).Owner = I
      or else Piles (K).Owner not in 1 .. N_Members
      or else Band (Piles (K).Owner).Job /= Forester);

   --  Its logs still to carry home; a pile it lately couldn't get to is
   --  left out a while, so one out of reach doesn't stop the felling.
   function Own_Logs (I : Positive) return Natural is
      N : Natural := 0;
   begin
      for K in 1 .. N_Piles loop
         if Its_Pile (K, I) and then not Failed (Band (I), Pile_Base_Id + K) then
            N := N + (Piles (K).Count - Piles (K).Claimed);
         end if;
      end loop;
      return N;
   end Own_Logs;

   --  A forester's next log home: the nearest of its own lying, if a
   --  stockpile has room for it.
   function Go_Haul (I : Positive) return Boolean is separate;

   --  Tree K comes down, away from From: its trunk above the stump,
   --  branches and crown taken out (block edits, as the player's), and its
   --  logs left lying a little past the stump, along the way it fell.
   procedure Fell (K : Positive; From : Vec3; By : Positive) is separate;

   ------------------------------------------------------------------ fetching

   function Have (K : Item_Kind) return Natural is
      N : Natural := Stored (K);
   begin
      for I in 1 .. N_Members loop
         if Band (I).Carry = K then
            N := N + Band (I).Carried;
         end if;
      end loop;
      return N;
   end Have;

   --  As Have, counting a full load for each porter already out for K.
   function Have_Or_Coming (K : Item_Kind) return Natural is
      N : Natural := Stored (K);
   begin
      for I in 1 .. N_Members loop
         if Band (I).State in To_Source | Gathering and then Band (I).Fetch = K then
            N := N + Carry_Limit (K);
         elsif Band (I).Carry = K then
            N := N + Band (I).Carried;
         end if;
      end loop;
      return N;
   end Have_Or_Coming;

   Source_Fail_Base : constant := 32_768;
   function Source_Id (P : Block_Pos) return Natural is
     (Source_Fail_Base + (Integer (P.X) * 7_919 + Integer (P.Y) * 104_729 + Integer (P.Z)) mod 2 ** 28);
   function Kind_Id (K : Item_Kind) return Natural is (Pile_Base_Id + Max_Piles + Item_Kind'Pos (K));

   function Centre_Of (P : Block_Pos) return Vec3 is
     ((Float (P.X) + 0.5) * 0.25, (Float (P.Y) + 0.5) * 0.25, (Float (P.Z) + 0.5) * 0.25);

   --  Someone else is out for K at (or right by) P; water is never used up,
   --  so any number may draw it at one place.
   function Taken (K : Item_Kind; P : Block_Pos; Self : Positive) return Boolean is
   begin
      if K = Water then
         return False;
      end if;
      for I in 1 .. N_Members loop
         if I /= Self and then Band (I).State in To_Source | Gathering and then Band (I).Fetch = K
           and then abs (Integer (Band (I).Tgt.X) - Integer (P.X)) <= 2
           and then abs (Integer (Band (I).Tgt.Y) - Integer (P.Y)) <= 2
         then
            return True;
         end if;
      end loop;
      return False;
   end Taken;

   --  Whether block P is still something to get K from: a tuft of tall
   --  grass, the exposed top of a boulder, water over a floor.  A boulder
   --  block counts only while it stands out of the ground on some side:
   --  boulders lie half buried, and what is under the grass stays, so taking
   --  one away never leaves a pit.
   function Source_At (K : Item_Kind; P : Block_Pos) return Boolean is
      X : constant Integer := Integer (P.X);
      Y : constant Integer := Integer (P.Y);
      Z : constant Integer := Integer (P.Z);
      function Open (Bx, By : Integer) return Boolean is (Class_Of (Mat (Bx, By, Z)) /= Solid);
   begin
      case K is
         when Straw => return Mat (X, Y, Z) in Tall_Grass | Wild_Grain;
         when Stone =>
            return Mat (X, Y, Z) = Boulder and then Class_Of (Mat (X, Y, Z + 1)) /= Solid
              and then (Open (X - 1, Y) or else Open (X + 1, Y) or else Open (X, Y - 1) or else Open (X, Y + 1));
         when Water => return Mat (X, Y, Z) = Water;
         when Sticks | Apples => return Mat (X, Y, Z) in Trunk;      --  the foot of a standing tree
         when Vegetables => return Mat (X, Y, Z) = Wild_Vegetables;
         when others => return False;
      end case;
   end Source_At;

   --  The nearest place to get K from, from From, within reach of the
   --  stake: the stacks flagged for it, nearest first; a stack found to have
   --  none left loses its flag.
   --  Reach_M, Least_M: no further from the stake than that, and no nearer than this.
   procedure Find_Source (K : Item_Kind; From : Vec3; Self : Positive; Tgt : out Block_Pos; Found : out Boolean;
                          Reach_M : Float := Work_Radius_M; Least_M : Float := 0.0) is separate;

   --  Where to stand to prise stone off block P: the floor nearest it, on
   --  the ground beside the boulder rather than on top of it, from which
   --  the block is in reach (no more than 1.75 m up, half a metre down).
   function Stand_Beside (P : Block_Pos; Where : out Vec3) return Boolean is separate;

   function Apples_Left return Natural is
      N : Natural := 0;
   begin
      for K in 1 .. N_Trees loop
         if Flat_Dist (Tree_Base (K), Stake_At) <= Work_Radius_M then
            N := N + Apples_On (K);
         end if;
      end loop;
      return N;
   end Apples_Left;

   --  Out for K: to the nearest place to get it.
   function Go_Fetch (I : Positive; K : Item_Kind; Reach_M : Float := Work_Radius_M; Least_M : Float := 0.0)
                      return Boolean is separate;

   --  The ripe bush a gatherer would go for (0: none): the nearest nobody
   --  else is after, weighed toward the stake.
   function Best_Bush (I : Positive) return Natural is separate;

   --  The apple tree in fruit a gatherer would go for (0: none), the same way.
   function Best_Apple_Tree (I : Positive) return Natural is separate;

   function Go_Apples (I : Positive; K : Positive) return Boolean is
      M : Member renames Band (I);
   begin
      if Route_To (M, Tree_Base (K), Half_W (K) + 1.0) then
         Release (M, I);
         M.Tree := K;
         Trees (K).Reserved_By := I;
         M.Fetch := Apples;
         M.Tgt := (Integer_16 (Trees (K).Info.Bx), Integer_16 (Trees (K).Info.By), Integer_16 (Trees (K).Info.Bz));
         M.State := To_Source;
         return True;
      end if;
      Remember_Failure (M, Tree_Base_Id + K);
      return False;
   end Go_Apples;

   --  A gatherer's next errand: of the ripe bush, the wild vegetable and
   --  the apple tree in fruit it would go for, the best by their scores
   --  (see the spec), the others in turn if there is no way to it.  Only:
   --  that kind alone (filling a basket part full of it).
   function Go_Forage (I : Positive; Only : Item_Kind := Nothing; Asked_Only : Boolean := False) return Boolean
     is separate;


   --  What porters fetch, first things first: straw (the thatch) up to its
   --  reserve, then stone as it is wanted.  (Water waits for a use and for
   --  barrels; the fetching works for it, it is just not asked for.)

   procedure Want (K : Item_Kind; N : Natural) is
   begin
      Demand (K) := Demand (K) + N;
   end Want;
   function Wanted_Of (K : Item_Kind) return Natural is (Demand (K));

   --  The first kind in that order the colony is short of, that a
   --  stockpile has room for and that M has not lately failed to find.
   function Wanted (M : Member) return Item_Kind is
   begin
      for K of Fetch_Order loop
         if Asked_For (K) and then Room_For (K) and then not Failed (M, Kind_Id (K)) then
            return K;
         end if;
      end loop;
      return Nothing;
   end Wanted;

   --  Within reach of where M stands, another block to get the same from.
   function Next_Near (M : in out Member) return Boolean is separate;

   ------------------------------------------------------------------ hunting

   --  Meat on its way: in the carcasses lying and carried.
   function Meat_Coming return Natural is
      N : Natural := 0;
   begin
      for K in 1 .. N_Carcasses loop
         if Carcasses (K).Used then
            N := N + Meat_Of (Carcasses (K).Class);
         end if;
      end loop;
      return N;
   end Meat_Coming;

   --  Nothing solid (and no leaves) between a bow at From and a deer at To.
   function Clear_Shot (From, To : Vec3) return Boolean is
      A : constant Vec3 := From + (0.0, 0.0, 1.35);
      Z : constant Vec3 := To + (0.0, 0.0, 0.7);
      L : constant Float := Sqrt (Dot (Z - A, Z - A));
      N : constant Natural := Natural (L / 0.125);
   begin
      for K in 1 .. N loop
         declare
            T : constant Float := Float (K) / Float (N);
            P : constant Vec3 := A + (Z - A) * T;
         begin
            if T * L > 0.4 and then (1.0 - T) * L > 0.5 then
               declare
                  M : constant Material := Mat (B (P.X), B (P.Y), B (P.Z));
               begin
                  if Class_Of (M) = Solid or else M in Crown then
                     return False;
                  end if;
               end;
            end if;
         end;
      end loop;
      return True;
   end Clear_Shot;

   --  A deer worth hunting: alive, grown, its herd larger than Spare_Last.
   function Fair_Game (K : Positive) return Boolean is
     (Castle.Herds.Alive (K) and then Castle.Deer."/=" (Castle.Herds.Class_Of (K), Castle.Deer.Fawn)
      and then Castle.Herds.Herd_Of (K) > 0
      and then Castle.Herds.In_Herd (Castle.Herds.Herd_Of (K)) > Spare_Last);

   Prey_Base_Id : constant := 40_000;

   --  The nearest deer worth hunting, within reach of the stake.
   function Go_Hunt (I : Positive) return Boolean is separate;

   --  Where to make for, to shoot deer K: Shoot_M less a little from it,
   --  on the hunter's side.
   function Stand_For (M : Member; K : Positive) return Vec3 is
      D  : constant Vec3 := Castle.Herds.Where (K);
      Dx : constant Float := M.Pos.X - D.X;
      Dy : constant Float := M.Pos.Y - D.Y;
      L  : constant Float := Float'Max (0.01, Sqrt (Dx * Dx + Dy * Dy));
      R  : constant Float := Float'Min (L, Shoot_M - 3.0);
   begin
      return (D.X + Dx / L * R, D.Y + Dy / L * R, M.Pos.Z);
   end Stand_For;

   --  A carcass for hunter I to fetch: its own, or one nobody's hunter is after.
   function Its_Carcass (K : Positive; I : Positive) return Boolean is
     (Carcasses (K).Used and then Carcasses (K).Lying
      and then (Carcasses (K).Owner = I or else Carcasses (K).Owner not in 1 .. N_Members
                or else Band (Carcasses (K).Owner).Job /= Hunter));

   function Go_Carcass (I : Positive) return Boolean is
      M : Member renames Band (I);
   begin
      for K in 1 .. N_Carcasses loop
         if Its_Carcass (K, I) and then not Failed (M, Prey_Base_Id + 1_000 + K) then
            if Route_To (M, Carcasses (K).Centre, 0.9) then
               Carcasses (K).Owner := I;
               M.Prize := K;
               M.State := To_Carcass;
               return True;
            end if;
            Remember_Failure (M, Prey_Base_Id + 1_000 + K);
         end if;
      end loop;
      return False;
   end Go_Carcass;

   --  Home with the carcass it carries: a cell for its meat and another for
   --  its hide, reserved, and the way to the meat's.
   function Go_Butcher (I : Positive) return Boolean is separate;

   --  Give back what a butchering trip had reserved.
   procedure Unreserve_Butcher (M : in out Member) is
   begin
      if M.Cell > 0 and then M.Prize > 0 then
         Cells (M.Cell).Incoming := Cells (M.Cell).Incoming - Meat_Of (Carcasses (M.Prize).Class);
         if Cells (M.Cell).Count = 0 and then Cells (M.Cell).Incoming = 0 then
            Cells (M.Cell).Kind := Nothing;
         end if;
      end if;
      if M.Cell2 > 0 then
         Cells (M.Cell2).Incoming := Cells (M.Cell2).Incoming - 1;
         if Cells (M.Cell2).Count = 0 and then Cells (M.Cell2).Incoming = 0 then
            Cells (M.Cell2).Kind := Nothing;
         end if;
      end if;
      M.Cell := 0;
      M.Cell2 := 0;
   end Unreserve_Butcher;

   --  Put down the carcass it carries where it stands, for any hunter.
   procedure Drop_Carcass (M : in out Member) is
   begin
      if M.Prize > 0 then
         Carcasses (M.Prize).Lying := True;
         Carcasses (M.Prize).Holder := 0;
         Carcasses (M.Prize).Owner := 0;
         Carcasses (M.Prize).Centre := M.Pos;
      end if;
      M.Prize := 0;
      M.Carry := Nothing;
      M.Carried := 0;
   end Drop_Carcass;

   procedure New_Arrow (From, To : Vec3; Stuck : Boolean) is
      K : Positive := 1;
      L : constant Float := Sqrt (Dot (To - From, To - From));
      T : constant Positive := Positive'Max (1, Integer (L / 40.0 * Float (Tick_Hz)));   --  40 m/s
   begin
      if N_Arrows < Max_Arrows then
         N_Arrows := N_Arrows + 1;
         K := N_Arrows;
      else
         for J in 2 .. Max_Arrows loop                   --  the oldest gives way
            if Arrows (J).T0 < Arrows (K).T0 then
               K := J;
            end if;
         end loop;
      end if;
      Arrows (K) := (From => From, To => To, T0 => Tick_N, Ticks => T, Stuck => Stuck,
                     Gone_At => Tick_N + T + (if Stuck then 60 * Tick_Hz else 0));
   end New_Arrow;

   procedure Age_Arrows is
      K : Positive := 1;
   begin
      while K <= N_Arrows loop
         if Tick_N >= Arrows (K).Gone_At then
            Arrows (K) := Arrows (N_Arrows);
            N_Arrows := N_Arrows - 1;
         else
            K := K + 1;
         end if;
      end loop;
   end Age_Arrows;

   --  Nothing to do: a few steps round the stake now and then.
   procedure Stroll (I : Positive; Round : Vec3) is
      M : Member renames Band (I);
      A : constant Float := 2.0 * Ada.Numerics.Pi * Hash01 (M, 1);
      R : constant Float := 1.5 + 4.0 * Hash01 (M, 2);
      Goal : constant Vec3 := (Round.X + R * Cos (A), Round.Y + R * Sin (A), Round.Z);
   begin
      M.Wait := 8.0 + 20.0 * Hash01 (M, 3);
      if Route_To (M, Goal, 1.5) then
         M.State := Strolling;
      else
         M.State := Idle;
      end if;
   end Stroll;

   procedure Stroll (I : Positive) is
   begin
      Stroll (I, Stake_At);
   end Stroll;

   ------------------------------------------------------------------ the camp: its places

   function Has_Camp return Boolean is (Camp_Set);
   function Camp return Vec3 is (Camp_At);
   function Cooked return Natural is (N_Cooked);
   function Put_In_Pot (K : Item_Kind) return Natural is (In_Pot_N (K));
   function Eaten_Raw (K : Item_Kind) return Natural is (Raw_Eaten_N (K));
   function Cooking_Of (I : Positive) return Float is (Castle.Hash.Unit (Castle.Hash.Mix (Band (I).Seed + 4_051)));

   Fend_Id : constant := 31_001;   --  a fail memo: nothing to gather for itself in reach
   Camp_Id   : constant := 31_000;               --  a fail memo: no way to the pot
   Stack_Off : constant Vec3 := (2.75, -2.75, 0.0);   --  the firewood, in the south-east corner

   --  The ground at (X, Y), or the camp's when there is none to be found.
   function On_Ground (X, Y : Float) return Vec3 is
      Z : constant Float := Castle.Nav.Surface_Z (X, Y);
   begin
      --  (on the camp's floor, once it is built and level: at its level,
      --  whatever the ground just beyond its edge does to the way across)
      if Camp_Level >= 0 and then Camp_Zone_N > 0 and then Zones (Camp_Zone_N).Built
        and then (X - Camp_At.X) ** 2 + (Y - Camp_At.Y) ** 2 <= Hearth_Ground_M ** 2
      then
         return (X, Y, Float (Camp_Level + 1) * 0.25);
      end if;
      return (X, Y, (if Z >= 0.0 then Z else Camp_At.Z));
   end On_Ground;

   --  The camp lies the way its zone does (east and north, unless a path
   --  passes within reach of its square): a place in it, Dx east and Dy
   --  north of the fire as the camp lies.
   function Camp_Turn return Float is (if Camp_Zone_N > 0 then Zones (Camp_Zone_N).Turn else 0.0);
   function Camp_Off (Dx, Dy : Float) return Vec3 is
      C : constant Float := Cos (Camp_Turn);
      S : constant Float := Sin (Camp_Turn);
   begin
      return (Dx * C - Dy * S, Dx * S + Dy * C, 0.0);
   end Camp_Off;

   --  Seat log K lies across the way out from the fire, a quarter turn
   --  from the next, the first to the camp's east.
   function Seat_Angle (K : Positive) return Float is (Ada.Numerics.Pi / 2.0 * Float (K - 1) + Camp_Turn);
   function Seat_Log (K : Positive) return Vec3 is
     (On_Ground (Camp_At.X + Seat_R * Cos (Seat_Angle (K)), Camp_At.Y + Seat_R * Sin (Seat_Angle (K))));
   function Seat_Turn (K : Positive) return Float is (Seat_Angle (K) + Ada.Numerics.Pi / 2.0);

   --  Two places on each log.
   function Seat_Place (K : Positive) return Vec3 is
      L     : constant Positive := (K + 1) / 2;
      Along : constant Float := (if K mod 2 = 1 then -0.3 else 0.3);
      T     : constant Float := Seat_Turn (L);
   begin
      return On_Ground (Seat_Log (L).X + Along * Cos (T), Seat_Log (L).Y + Along * Sin (T));
   end Seat_Place;

   --  Beside the pot, on the side toward Toward.
   function Pot_Side (Toward : Vec3) return Vec3 is
      Dx : constant Float := Toward.X - Camp_At.X;
      Dy : constant Float := Toward.Y - Camp_At.Y;
      L  : constant Float := Sqrt (Dx * Dx + Dy * Dy);
   begin
      if L < 0.01 then
         return On_Ground (Camp_At.X, Camp_At.Y - 0.95);
      end if;
      return On_Ground (Camp_At.X + 0.95 * Dx / L, Camp_At.Y + 0.95 * Dy / L);
   end Pot_Side;

   --  Where the cook stands: south of the fire, to stir the pot or feed the fire.
   function Cook_Side return Vec3 is (Pot_Side (Camp_At + Camp_Off (0.0, -1.0)));

   --  The stack of firewood: in the camp's south-east corner.
   function Firewood_Place return Vec3 is
      R : constant Vec3 := Camp_Off (Stack_Off.X, Stack_Off.Y);
   begin
      return On_Ground (Camp_At.X + R.X, Camp_At.Y + R.Y);
   end Firewood_Place;

   ------------------------------------------------------------------ how far the band looks

   function Seg_Dist (P : Vec3; S : Path_Seg) return Float;       --  (its body is with the paths, below)
   function Zone_Of_Block (Bx, By : Integer) return Natural;      --  (and its with the zones)

   function Camp_Built return Boolean is (Camp_Set and then Camp_Zone_N > 0 and then Zones (Camp_Zone_N).Built);

   function Search_Reach return Float is (Float'Max (Work_Radius_M, Far_Reach));
   function Looking_M return Float is (Far_Reach);
   procedure Set_Stone_From (Metres : Float) is
   begin
      Stone_From := Float'Max (0.0, Metres);
   end Set_Stone_From;
   --  (and as far as any housing reaches: people build there, and live there)
   function Ground_Reach_M return Float is (Float'Max (Float'Max (Search_Reach, Path_Far), Housing_Far));

   --  Every stack within Reach of the stake's that is in has been looked
   --  through.  (The host has all of the colony's ground in before a step,
   --  so within Ground_In that is every stack there is.)
   function Looked_Through (Reach : Float) return Boolean is
      SX : constant Integer := Integer (Float'Floor (Stake_At.X / 8.0));
      SY : constant Integer := Integer (Float'Floor (Stake_At.Y / 8.0));
      R  : constant Integer := Integer (Reach / 8.0) + 1;
   begin
      for DX in -R .. R loop
         for DY in -R .. R loop
            if DX * DX + DY * DY <= R * R
              and then SX + DX in Indexed_Grid'Range (1) and then SY + DY in Indexed_Grid'Range (2)
              and then not Indexed (SX + DX, SY + DY) and then Version_Src (SX + DX, SY + DY) > 0
            then
               return False;
            end if;
         end loop;
      end loop;
      return True;
   end Looked_Through;

   --  Nothing to be had within reach for the camp's building: once all the
   --  ground that near is in and looked through, the band looks a ring further.
   procedure Look_Further is
   begin
      if Search_Reach < Far_Reach_Max_M and then Search_Reach <= Ground_In and then Looked_Through (Search_Reach) then
         Far_Reach := Float'Min (Far_Reach_Max_M, Search_Reach + Reach_Step_M);
      end if;
   end Look_Further;

   --  The camp standing (or none) and everyone back within reach of the
   --  stake: the band looks no further than its work again.
   procedure Look_Near_Again is
   begin
      if Far_Reach > 0.0 and then (not Camp_Set or else Camp_Built)
        and then (for all I in 1 .. N_Members =>
                    Band (I).Is_Dead or else Flat_Dist (Band (I).Pos, Stake_At) <= Work_Radius_M + Reach_Step_M)
      then
         Far_Reach := 0.0;
      end if;
   end Look_Near_Again;

   ------------------------------------------------------------------ paths: laying them

   Path_Fail : constant := 31_300;      --  fail memos: no way to that metre of that stretch (to 32_699)

   function Path_Metres (S : Path_Seg) return Natural is (Natural (Float'Ceiling (Flat_Dist (S.A, S.B))));
   function All_Metres (S : Path_Seg) return Unsigned_64 is
     (if Path_Metres (S) >= 64 then Unsigned_64'Last else Shift_Left (Unsigned_64'(1), Path_Metres (S)) - 1);

   --  The ground a stretch lies on is in: every stack under it is loaded.
   function Stretch_In (S : Path_Seg) return Boolean is
      Half : constant Float := Path_Width_M / 2.0;
   begin
      for CX in Integer (Float'Floor ((Float'Min (S.A.X, S.B.X) - Half) / 8.0))
        .. Integer (Float'Floor ((Float'Max (S.A.X, S.B.X) + Half) / 8.0))
      loop
         for CY in Integer (Float'Floor ((Float'Min (S.A.Y, S.B.Y) - Half) / 8.0))
           .. Integer (Float'Floor ((Float'Max (S.A.Y, S.B.Y) + Half) / 8.0))
         loop
            if CX in Indexed_Grid'Range (1) and then CY in Indexed_Grid'Range (2) and then Version_Src (CX, CY) = 0 then
               return False;
            end if;
         end loop;
      end loop;
      return True;
   end Stretch_In;

   --  Every block column of a stretch that is still to be turned to
   --  footpath: within its width, no zone's, its top one of the kinds of
   --  ground a path is laid on.  Zr: the row of that top; Metre: which metre
   --  of the stretch it is in, from A.
   procedure For_Path_Work
     (S : Path_Seg; Visit : not null access procedure (X, Y, Zr, Metre : Integer))
   is
      Half : constant Float := Path_Width_M / 2.0;
      L    : constant Float := Flat_Dist (S.A, S.B);
      N    : constant Natural := Path_Metres (S);
   begin
      if L < 0.25 then
         return;
      end if;
      for X in B (Float'Min (S.A.X, S.B.X) - Half) .. B (Float'Max (S.A.X, S.B.X) + Half) loop
         for Y in B (Float'Min (S.A.Y, S.B.Y) - Half) .. B (Float'Max (S.A.Y, S.B.Y) + Half) loop
            declare
               C : constant Vec3 := ((Float (X) + 0.5) * 0.25, (Float (Y) + 0.5) * 0.25, 0.0);
            begin
               if Seg_Dist (C, S) <= Half and then (N_Zones = 0 or else Zone_Of_Block (X, Y) = 0) then
                  declare
                     T  : constant Float :=
                       Float'Max (0.0, Float'Min (1.0, ((C.X - S.A.X) * (S.B.X - S.A.X)
                                                         + (C.Y - S.A.Y) * (S.B.Y - S.A.Y)) / (L * L)));
                     Zr : constant Integer := Ground_Row (X, Y, B (S.A.Z + (S.B.Z - S.A.Z) * T));
                  begin
                     if Zr >= 0 and then Mat (X, Y, Zr) in Grass | Dirt | Sand | Gravel | Clay | Placer_Gravel | Bog_Iron
                     then
                        Visit (X, Y, Zr, Integer'Min (N, Integer (Float'Floor (T * L)) + 1));
                     end if;
                  end;
               end if;
            end;
         end loop;
      end loop;
   end For_Path_Work;

   --  The middle of metre Metre of a stretch, on the ground.
   function Metre_Middle (S : Path_Seg; Metre : Positive) return Vec3 is
      L : constant Float := Flat_Dist (S.A, S.B);
      D : constant Float := Float'Min (L, (Float (Metre - 1) + Float'Min (Float (Metre), L)) / 2.0);
      T : constant Float := (if L > 0.0 then D / L else 0.0);
   begin
      return On_Ground (S.A.X + (S.B.X - S.A.X) * T, S.A.Y + (S.B.Y - S.A.Y) * T);
   end Metre_Middle;

   --  What is left to lay, all told, and how far out it reaches.
   procedure Count_Paths is
   begin
      Paths_Left_M := 0;
      Path_Far := 0.0;
      for K in 1 .. N_Paths loop
         if Path_List (K).Todo /= 0 then
            for Bit in 0 .. Integer'Min (63, Path_Metres (Path_List (K)) - 1) loop
               if (Path_List (K).Todo and Shift_Left (Unsigned_64'(1), Bit)) /= 0 then
                  Paths_Left_M := Paths_Left_M + 1;
               end if;
            end loop;
            Path_Far := Float'Max (Path_Far, Float'Max (Flat_Dist (Path_List (K).A, Stake_At),
                                                         Flat_Dist (Path_List (K).B, Stake_At)));
         end if;
      end loop;
   end Count_Paths;

   --  Stretch K's metres still to lay, read from the ground (every one of
   --  them, while its ground is not in).
   procedure Refresh_Path (K : Positive) is
      S    : Path_Seg renames Path_List (K);
      Mask : Unsigned_64 := 0;
      procedure Note (X, Y, Zr, Metre : Integer) is
         pragma Unreferenced (X, Y, Zr);
      begin
         Mask := Mask or Shift_Left (Unsigned_64'(1), Integer'Min (63, Metre - 1));
      end Note;
      --  An end planned on ground that was not in has no height yet: the
      --  ground's there now, else the other end's.
      procedure Settle (P : in out Vec3; Other : Vec3) is
         Z : constant Float := Castle.Nav.Surface_Z (P.X, P.Y);
      begin
         if P.Z < 0.0 then
            P.Z := (if Z >= 0.0 then Z else Other.Z);
         end if;
      end Settle;
   begin
      if not Stretch_In (S) then
         S.Known := False;
         S.Todo := All_Metres (S);
      else
         Settle (S.A, S.B);
         Settle (S.B, S.A);
         if S.A.Z >= 0.0 and then S.B.Z >= 0.0 then
            For_Path_Work (S, Note'Access);
         end if;                              --  (else there is no ground at either end: nothing of it to lay)
         S.Known := True;
         S.Todo := Mask;
      end if;
   end Refresh_Path;

   --  Once a colony second: the stretches with any to lay are counted again
   --  from the ground, and one of the others in turn (a stretch dug up is
   --  laid again).
   procedure Refresh_Paths is
   begin
      if N_Paths = 0 then
         Paths_Stale := False;
         return;
      end if;
      Path_Turn := Path_Turn mod N_Paths + 1;
      for K in 1 .. N_Paths loop
         if Paths_Stale or else K = Path_Turn or else not Path_List (K).Known or else Path_List (K).Todo /= 0 then
            Refresh_Path (K);
         end if;
      end loop;
      Paths_Stale := False;
      Count_Paths;
   end Refresh_Paths;

   --  Metre Metre of stretch K laid: what grows on it cut, the top of the
   --  ground turned to footpath, all of it at once.
   procedure Lay_Metre (K : Positive; Metre : Positive) is
      procedure Turn (X, Y, Zr, M : Integer) is
      begin
         --  (the 64th stands for whatever lies beyond it, in a stretch of before there were pieces)
         if M = Metre or else (Metre = 64 and then M > 64) then
            Write_Src (X, Y, Zr, (Mat => Footpath, State => 0));
            for Up in 1 .. 3 loop
               exit when Mat (X, Y, Zr + Up) not in Tall_Grass | Wild_Grain | Wild_Vegetables;
               Write_Src (X, Y, Zr + Up, Air_Block);
            end loop;
         end if;
      end Turn;
   begin
      For_Path_Work (Path_List (K), Turn'Access);
      Path_List (K).Todo := Path_List (K).Todo and not Shift_Left (Unsigned_64'(1), Integer'Min (63, Metre - 1));
      Count_Paths;
   end Lay_Metre;

   function Paths_To_Lay return Natural is (Paths_Left_M);
   function Stretch_Of (I : Positive) return Natural is (if Stretches_On then Band (I).Site_Seg else 0);
   function Laid_By (I : Positive) return Natural is (Band (I).Site_Laid);
   function Stretches return Boolean is (Stretches_On);
   procedure Set_Stretches (On : Boolean) is
   begin
      Stretches_On := On;
   end Set_Stretches;
   function Levelling return Boolean is (Level_On);
   procedure Set_Levelling (On : Boolean) is
   begin
      Level_On := On;
   end Set_Levelling;

   --  It leaves its stretch (for anything else: it is given another when
   --  it next turns to the paths).
   procedure Drop_Stretch (M : in out Member) is
   begin
      M.Site_Seg := 0;
      M.Site_M := 0;
      M.Site_Laid := 0;
   end Drop_Stretch;
   function Path_Todo (K : Positive; Metre : Positive) return Boolean is
     (K <= N_Paths and then Metre <= 64
      and then (Path_List (K).Todo and Shift_Left (Unsigned_64'(1), Metre - 1)) /= 0);

   procedure Build_Paths_Now is
   begin
      for K in 1 .. N_Paths loop
         Refresh_Path (K);
         if Path_List (K).Known then
            for Metre in 1 .. Path_Metres (Path_List (K)) loop
               if Path_Todo (K, Metre) then
                  Lay_Metre (K, Metre);
               end if;
            end loop;
         end if;
      end loop;
      Count_Paths;
   end Build_Paths_Now;

   ------------------------------------------------------------------ the camp: building it

   --  The camp's ground is made ready a square metre at a time: patches,
   --  numbered by where they lie from the fire, as the camp lies.
   Max_Patch  : constant := 4 * Patch_Span * Patch_Span;
   Patch_Fail : constant := 31_100;                    --  a fail memo: no way to that patch
   Hollow_Fail : constant := 31_099;                   --  a fail memo: earth in hand and no hollow it could get to

   function Patch_Of (Bx, By : Integer) return Natural is
      Dx : constant Float := (Float (Bx) + 0.5) * 0.25 - Camp_At.X;
      Dy : constant Float := (Float (By) + 0.5) * 0.25 - Camp_At.Y;
      C  : constant Float := Cos (Camp_Turn);
      S  : constant Float := Sin (Camp_Turn);
      I  : constant Integer := Integer (Float'Floor (Dx * C + Dy * S)) + Patch_Span;
      J  : constant Integer := Integer (Float'Floor (Dy * C - Dx * S)) + Patch_Span;
   begin
      return (if I in 0 .. 2 * Patch_Span - 1 and then J in 0 .. 2 * Patch_Span - 1
              then I * 2 * Patch_Span + J + 1 else 0);
   end Patch_Of;

   procedure Measure_Zone (Z : Positive);                         --  (its body is with the zones, below)
   function Free_Stock (K : Item_Kind) return Natural;            --  (and its with the camp's own)

   --  The camp's floor: its ground within Hearth_Ground_M of the fire.  It
   --  is made level, at Camp_Level (the row of its top; -1: left as it
   --  lies), and trodden to bare earth.
   function Near_Fire (Bx, By : Integer) return Boolean is
     (Flat_Dist (((Float (Bx) + 0.5) * 0.25, (Float (By) + 0.5) * 0.25, 0.0), Camp_At) <= Hearth_Ground_M);

   --  What can be dug with the hands and a stick: earth, not rock.
   function Is_Earth (M : Material) return Boolean is
     (M in Grass | Dirt | Sand | Gravel | Clay | Placer_Gravel | Bog_Iron);

   --  Blocks of earth to dig off a column of the floor (its top at row Zr)
   --  to bring it down to Level, as far as it is earth; and blocks to fill
   --  one that lies below it.
   function Cut_In (Bx, By, Zr, Level : Integer) return Natural is
      N : Natural := 0;
   begin
      for Z in reverse Level + 1 .. Zr loop
         exit when not Is_Earth (Mat (Bx, By, Z));
         N := N + 1;
      end loop;
      return N;
   end Cut_In;
   function Fill_In (Zr, Level : Integer) return Natural is (if Zr < Level then Level - Zr else 0);

   --  Turf cut off the floor and lying on it, in block columns' worth
   --  (Sod_Share of them make a block of earth): once nothing is left to
   --  dig off the floor, whoever is at it fills its hollows with it.  It is
   --  never carried off.
   Sod_Bits : Natural := 0;

   --  The level the camp's floor is brought to: the highest at which what
   --  is dug off, with the turf cut off the rest, is at least what the
   --  hollows take, so that the earth for them is always there (-1: no
   --  floor, or its ground is not in).
   function Choose_Level return Integer is
      Lo : Integer := Integer'Last;
      Hi : Integer := Integer'First;
   begin
      if Camp_Zone_N = 0 then
         return -1;
      end if;
      for K in Zones (Camp_Zone_N).First + 1 .. Zones (Camp_Zone_N).First + Zones (Camp_Zone_N).N loop
         for X in Integer (Runs (K).X0) .. Integer (Runs (K).X1) loop
            if Near_Fire (X, Integer (Runs (K).Y)) then
               Lo := Integer'Min (Lo, Integer (Runs (K).Z));
               Hi := Integer'Max (Hi, Integer (Runs (K).Z));
            end if;
         end loop;
      end loop;
      if Lo > Hi then
         return -1;
      end if;
      for Level in reverse Lo .. Hi loop
         declare
            Cut, Fill, Turf : Natural := 0;
         begin
            for K in Zones (Camp_Zone_N).First + 1 .. Zones (Camp_Zone_N).First + Zones (Camp_Zone_N).N loop
               for X in Integer (Runs (K).X0) .. Integer (Runs (K).X1) loop
                  if Near_Fire (X, Integer (Runs (K).Y)) then
                     Cut := Cut + Cut_In (X, Integer (Runs (K).Y), Integer (Runs (K).Z), Level);
                     Fill := Fill + Fill_In (Integer (Runs (K).Z), Level);
                     if Integer (Runs (K).Z) <= Level and then Mat (X, Integer (Runs (K).Y), Integer (Runs (K).Z)) = Grass
                     then
                        Turf := Turf + 1;
                     end if;
                  end if;
               end loop;
            end loop;
            --  (the last block of the turf's earth is not counted on)
            if Cut + Natural'Max (1, Turf / Sod_Share) - 1 >= Fill then
               return Level;
            end if;
         end;
      end loop;
      return Lo;
   end Choose_Level;

   ------------------------------------------------------------------ housing: where a house stands

   package CB renames Castle.Buildings;
   use type CB.Stage;

   Site_Fail       : constant := 20_000;   --  fail memos: no way to work at that house (to 20_048),
   Site_Patch_Fail : constant := 20_100;   --  and no way to that patch of its ground (to 20_260)
   --  (clear of the others': bushes, cells, trees and piles below 17_000, the
   --  camp's and the paths' from 31_000, a source's from 32_768 up)

   --  A house's own frame: U along its front wall, V from the front wall
   --  into it, in blocks; and back.
   function H_X (F : CB.House; U, V : Integer) return Integer is (F.Fx + U * F.Ux + V * F.Vx);
   function H_Y (F : CB.House; U, V : Integer) return Integer is (F.Fy + U * F.Uy + V * F.Vy);
   function H_U (F : CB.House; Bx, By : Integer) return Integer is ((Bx - F.Fx) * F.Ux + (By - F.Fy) * F.Uy);
   function H_V (F : CB.House; Bx, By : Integer) return Integer is ((Bx - F.Fx) * F.Vx + (By - F.Fy) * F.Vy);
   function Pad_Z (F : CB.House) return Float is (Float (F.Pad) * 0.25);

   --  The middle of block (U, V) of a house's frame (fractions of a block
   --  allowed), on the ground at its pad's level: metres.
   function H_Point (F : CB.House; U, V : Float) return Vec3 is
     ((Float (F.Fx) + 0.5 + U * Float (F.Ux) + V * Float (F.Vx)) * 0.25,
      (Float (F.Fy) + 0.5 + U * Float (F.Uy) + V * Float (F.Vy)) * 0.25,
      Pad_Z (F));

   --  The lot kept for a house: Lot_B along its front with the house in the
   --  middle of it, and Lot_B back from the bank in front of its front wall.
   function Lot_Left (F : CB.House) return Integer is ((CB.Lot_B - F.W) / 2);
   function Lot_Right (F : CB.House) return Integer is (CB.Lot_B - F.W - Lot_Left (F));
   --  The bank round its pad keeps within its lot to either side; before
   --  its front wall it is Apron_Front_B wide, behind its back wall Apron_B.
   function Apron_U (F : CB.House) return Integer is (Integer'Min (CB.Apron_B, Lot_Left (F)));
   V_Lo : constant := -CB.Apron_Front_B;
   function V_Hi (F : CB.House) return Integer is (F.D - 1 + CB.Apron_B);
   --  How far back its lot reaches (its bank's end, if that is further).
   function Lot_Back (F : CB.House) return Integer is (Integer'Max (CB.Lot_B + V_Lo - 1, V_Hi (F)));

   --  A column of the way out from a house's door to its path.
   function In_Door_Way (F : CB.House; U, V : Integer) return Boolean is
     (V < 0 and then -V <= F.Door_Run
      and then U in F.Openings (1).Offset .. F.Openings (1).Offset + F.Openings (1).Width - 1);

   --  How many blocks the path's ground may lie above or below a house's
   --  pad for its door to be got to: a block where the path is hard by, a
   --  block for each column of the way past its landing otherwise.
   function Door_Steps (F : CB.House) return Natural is
     (Integer'Max (1, F.Door_Run - CB.Door_Landing_B));

   --  The ground a house's builder makes ready: under its walls, the bank
   --  round them, and the way out from its door.
   function Site_V_Lo (F : CB.House) return Integer is (-Integer'Max (CB.Apron_Front_B, F.Door_Run));
   function In_Site (F : CB.House; U, V : Integer) return Boolean is
     ((V in V_Lo .. V_Hi (F) and then U in -Apron_U (F) .. F.W - 1 + Apron_U (F)) or else In_Door_Way (F, U, V));

   --  The row the top of the ground at (U, V) of a house's frame is brought
   --  to (Old: its row now): the pad's under the walls; on the way out from
   --  its door, a landing at the pad's level and then a stair between the
   --  pad and the ground where that way meets the path (a block to a block
   --  at most: Place_House sees to it, by Door_Steps); within
   --  the bank, no further off the pad's than it is from the walls; beyond,
   --  as it lies.
   function Target_Row (F : CB.House; U, V, Old : Integer) return Integer is
      Du  : constant Integer := (if U < 0 then -U elsif U >= F.W then U - F.W + 1 else 0);
      Dv  : constant Integer := (if V < 0 then -V elsif V >= F.D then V - F.D + 1 else 0);
      D   : constant Integer := Integer'Max (Du, Dv);
      Pad : constant Integer := F.Pad - 1;
   begin
      if D = 0 then
         return Pad;
      elsif In_Door_Way (F, U, V) then
         return (if -V <= CB.Door_Landing_B then Pad
                 else Pad + (F.Door_Row - Pad) * (-V - CB.Door_Landing_B) / (F.Door_Run - CB.Door_Landing_B));
      elsif Du > Apron_U (F) or else V < V_Lo or else V > V_Hi (F) then
         return Old;
      else
         return Integer'Max (Pad - D, Integer'Min (Pad + D, Old));
      end if;
   end Target_Row;

   function House_Count return Natural is (N_Houses);

   --  The house whose walls stand (or are to stand) round a block column.
   function House_On_Block (Bx, By : Integer) return Natural is
   begin
      for H in 1 .. N_Houses loop
         if H_U (Houses (H).F, Bx, By) in 0 .. Houses (H).F.W - 1
           and then H_V (Houses (H).F, Bx, By) in 0 .. Houses (H).F.D - 1
         then
            return H;
         end if;
      end loop;
      return 0;
   end House_On_Block;

   --  (for whatever points at a house: its eaves are of it too)
   function House_On (X, Y : Float) return Natural is
   begin
      for H in 1 .. N_Houses loop
         if H_U (Houses (H).F, B (X), B (Y)) in -1 .. Houses (H).F.W
           and then H_V (Houses (H).F, B (X), B (Y)) in -1 .. Houses (H).F.D
         then
            return H;
         end if;
      end loop;
      return 0;
   end House_On;

   --  The row a zone's ground is at under a house whose ground is ready:
   --  its pad, whatever has been built on it since (-1: no such house there).
   function House_Row (Bx, By : Integer) return Integer is
      H : constant Natural := (if N_Houses = 0 then 0 else House_On_Block (Bx, By));
   begin
      return (if H > 0 and then Houses (H).Pad_Done then Houses (H).F.Pad - 1 else -1);
   end House_Row;

   --  A block column just outside the walls of a house whose ground is
   --  ready: its eaves may hang over it (the ground under them is as it was
   --  when the ground was made ready).
   function Under_Eaves (Bx, By : Integer) return Boolean is
   begin
      for H in 1 .. N_Houses loop
         if Houses (H).Pad_Done
           and then H_U (Houses (H).F, Bx, By) in -1 .. Houses (H).F.W
           and then H_V (Houses (H).F, Bx, By) in -1 .. Houses (H).F.D
         then
            return True;
         end if;
      end loop;
      return False;
   end Under_Eaves;

   --  A place within a house that is begun or stands: between its eaves,
   --  from its pad up.  What is there is the house's, whatever tree once
   --  reached into it.
   function In_A_House (Bx, By, Bz : Integer) return Boolean is
   begin
      for H in 1 .. N_Houses loop
         if H_U (Houses (H).F, Bx, By) in -1 .. Houses (H).F.W
           and then H_V (Houses (H).F, Bx, By) in -1 .. Houses (H).F.D
           and then Bz >= Houses (H).F.Pad - 1
         then
            return True;
         end if;
      end loop;
      return False;
   end In_A_House;

   function Home_Of (I : Positive) return Natural is
   begin
      for H in 1 .. N_Houses loop
         if Houses (H).Owner = I then
            return H;
         end if;
      end loop;
      return 0;
   end Home_Of;

   function Housed (I : Positive) return Boolean is (Home_Of (I) > 0 and then Houses (Home_Of (I)).Built);

   --  Where a house's owner sleeps: in its back corner, a metre off the walls.
   function Bed_Place (H : Positive) return Vec3 is
     (H_Point (Houses (H).F, Float (Bed_In_B), Float (Houses (H).F.D - 1 - Bed_In_B)));

   function At_Home (I : Positive) return Boolean is
     (N_Houses > 0 and then not Band (I).Is_Dead and then Housed (I)
      and then Flat_Dist (Band (I).Pos, Bed_Place (Home_Of (I))) <= Home_M);

   function Site_Of (I : Positive) return Natural is
     (if Band (I).Is_Dead or else Band (I).Job /= Forester then 0 else Band (I).Site);
   function Trade_Of (I : Positive) return Trade_Kind is (if Site_Of (I) > 0 then Builder else No_Trade);

   function Builder_Of (H : Positive) return Natural is
   begin
      for I in 1 .. N_Members loop
         if Site_Of (I) = H then
            return I;
         end if;
      end loop;
      return 0;
   end Builder_Of;

   function Homeless return Natural is
      N : Natural := 0;
   begin
      for I in 1 .. N_Members loop
         if not Band (I).Is_Dead and then not Housed (I) then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Homeless;

   --  A zone's ground as it lies now: each of its block columns' top read
   --  again from the world (where the ground is in), its strips made again
   --  from them.  After anything is dug off it or filled in.  (Under a
   --  house whose ground is ready it is the house's pad.)
   procedure Read_Zone_Ground (Z0 : Natural) is
   begin
      if Z0 = 0 or else Zones (Z0).N = 0 then
         return;
      end if;
      declare
         Old   : constant Run_List (1 .. Zones (Z0).N) :=
           Run_List (Runs (Zones (Z0).First + 1 .. Zones (Z0).First + Zones (Z0).N));
         Fresh : Run_List (1 .. Zones (Z0).Blocks + 1);
         N     : Natural := 0;
         Moved : Boolean := False;
      begin
         for R of Old loop
            for X in Integer (R.X0) .. Integer (R.X1) loop
               declare
                  Pad : constant Integer := House_Row (X, Integer (R.Y));
                  Top : constant Integer :=
                    (if Pad >= 0 then Pad
                     elsif N_Houses > 0 and then Under_Eaves (X, Integer (R.Y)) then Integer (R.Z)
                     else Ground_Row (X, Integer (R.Y), Integer (R.Z)));
                  Zr  : constant Integer_16 := (if Top >= 0 then Integer_16 (Top) else R.Z);
               begin
                  Moved := Moved or else Zr /= R.Z;
                  if N > 0 and then Fresh (N).Y = R.Y and then Fresh (N).Z = Zr and then Integer (Fresh (N).X1) + 1 = X
                  then
                     Fresh (N).X1 := Integer_16 (X);
                  else
                     N := N + 1;
                     Fresh (N) := (Y => R.Y, X0 => Integer_16 (X), X1 => Integer_16 (X), Z => Zr);
                  end if;
               end;
            end loop;
         end loop;
         if not Moved or else N_Runs - Old'Length + N > Max_Zone_Runs then
            return;
         end if;
         --  its old strips out of the list, the new ones on the end
         for K in Zones (Z0).First + Old'Length + 1 .. N_Runs loop
            Runs (K - Old'Length) := Runs (K);
         end loop;
         for Z in 1 .. N_Zones loop
            if Zones (Z).First > Zones (Z0).First then
               Zones (Z).First := Zones (Z).First - Old'Length;
            end if;
         end loop;
         N_Runs := N_Runs - Old'Length;
         Zones (Z0).First := N_Runs;
         Zones (Z0).N := N;
         for K in 1 .. N loop
            Runs (N_Runs + K) := Fresh (K);
         end loop;
         N_Runs := N_Runs + N;
         Measure_Zone (Z0);
         Zones_Ver := Zones_Ver + 1;
      end;
   end Read_Zone_Ground;

   procedure Read_Camp_Ground is
   begin
      Read_Zone_Ground (Camp_Zone_N);
   end Read_Camp_Ground;

   --  A block column of the camp's ground (its top at row Zr) has work in
   --  it for empty hands: something growing on it to cut; on the floor,
   --  earth to dig off down to its level, or turf to tread to bare earth.
   --  And for hands with earth in them: a hollow of the floor to fill.
   function Wants_Work (Bx, By, Zr : Integer) return Boolean is
     (Mat (Bx, By, Zr + 1) in Tall_Grass | Wild_Grain | Wild_Vegetables
      or else (Near_Fire (Bx, By)
               and then (if Camp_Level >= 0 and then Zr > Camp_Level then Is_Earth (Mat (Bx, By, Zr))
                         else Mat (Bx, By, Zr) = Grass)));
   function Wants_Earth (Bx, By, Zr : Integer) return Boolean is
     (Camp_Level >= 0 and then Zr < Camp_Level and then Near_Fire (Bx, By));

   type Patch_Flags is array (1 .. Max_Patch) of Boolean;
   type Patch_Sums is array (1 .. Max_Patch) of Vec3;

   --  Which patches still have work in them (for empty hands; To_Fill: for
   --  hands with earth in them), and for each the sum of where that work is
   --  (X, Y) and how many block columns of it (Z).
   procedure Patches_Wanting (Wants : out Patch_Flags; Sum : out Patch_Sums; To_Fill : Boolean := False) is
   begin
      Wants := [others => False];
      Sum := [others => (0.0, 0.0, 0.0)];
      if Camp_Zone_N = 0 then
         return;
      end if;
      for K in Zones (Camp_Zone_N).First + 1 .. Zones (Camp_Zone_N).First + Zones (Camp_Zone_N).N loop
         for X in Integer (Runs (K).X0) .. Integer (Runs (K).X1) loop
            declare
               Y : constant Integer := Integer (Runs (K).Y);
               P : constant Natural := Patch_Of (X, Y);
            begin
               if P > 0 and then (if To_Fill then Wants_Earth (X, Y, Integer (Runs (K).Z))
                                  else Wants_Work (X, Y, Integer (Runs (K).Z)))
               then
                  Wants (P) := True;
                  Sum (P) := Sum (P) + ((Float (X) + 0.5) * 0.25, (Float (Y) + 0.5) * 0.25, 1.0);
               end if;
            end;
         end loop;
      end loop;
   end Patches_Wanting;

   --  Square metres of the camp's ground still to be made ready, and blocks
   --  of its floor still to dig off and to fill, as last counted (once a
   --  colony second while it is building, and whenever a patch is done).
   Ground_Left_N : Natural := 0;
   Cut_Left_N    : Natural := 0;
   Fill_Left_N   : Natural := 0;

   --  Earth for a hollow is to be had: some still to dig off, some in
   --  someone's hands, some in store.
   function Earth_To_Be_Had return Boolean is
     (Cut_Left_N > 0 or else Free_Stock (Earth) > 0 or else Sod_Bits >= Sod_Share
      or else (for some I in 1 .. N_Members =>
                 not Band (I).Is_Dead and then Band (I).Carry = Earth and then Band (I).Carried > 0));

   procedure Count_Level is
   begin
      Cut_Left_N := 0;
      Fill_Left_N := 0;
      if Camp_Zone_N = 0 or else Camp_Level < 0 then
         return;
      end if;
      for K in Zones (Camp_Zone_N).First + 1 .. Zones (Camp_Zone_N).First + Zones (Camp_Zone_N).N loop
         for X in Integer (Runs (K).X0) .. Integer (Runs (K).X1) loop
            if Near_Fire (X, Integer (Runs (K).Y)) then
               Cut_Left_N := Cut_Left_N + Cut_In (X, Integer (Runs (K).Y), Integer (Runs (K).Z), Camp_Level);
               Fill_Left_N := Fill_Left_N + Fill_In (Integer (Runs (K).Z), Camp_Level);
            end if;
         end loop;
      end loop;
   end Count_Level;

   --  (A hollow counts as ground to make ready only while there is earth to
   --  be had for it: with none anywhere it is left, and the camp is built
   --  round it.)
   function Count_Ground_Left return Natural is
      Wants, Hollow : Patch_Flags;
      Sum   : Patch_Sums;
      N     : Natural := 0;
   begin
      Patches_Wanting (Wants, Sum);
      Count_Level;
      if Fill_Left_N > 0 and then Earth_To_Be_Had then
         Patches_Wanting (Hollow, Sum, To_Fill => True);
      else
         Hollow := [others => False];
      end if;
      for P in Wants'Range loop
         if Wants (P) or else Hollow (P) then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Count_Ground_Left;

   --  The fire's place follows its ground (the floor may have been brought
   --  up or down under it), and anyone standing on the floor stands on it
   --  as it is now.
   procedure Settle_On_Floor is
      Z : constant Float := Castle.Nav.Surface_Z (Camp_At.X, Camp_At.Y);
   begin
      if Z >= 0.0 then
         Camp_At.Z := Z;
      end if;
      for I in 1 .. N_Members loop
         if not Band (I).Is_Dead and then Flat_Dist (Band (I).Pos, Camp_At) <= Hearth_Ground_M + 0.5 then
            declare
               Zm : constant Float := Castle.Nav.Surface_Z (Band (I).Pos.X, Band (I).Pos.Y);
            begin
               if Zm >= 0.0 and then abs (Zm - Band (I).Pos.Z) <= 1.5 then
                  Band (I).Pos.Z := Zm;
                  Band (I).Prev.Z := Zm;
               end if;
            end;
         end if;
      end loop;
   end Settle_On_Floor;

   --  The hearth stands once its ground is ready and all it takes is there.
   procedure Check_Built is
   begin
      if not Camp_Set or else Camp_Zone_N = 0 or else Zones (Camp_Zone_N).Built then
         return;
      end if;
      --  (a camp marked before its floor was levelled, or on ground that was
      --  not in: its level is chosen now)
      if Camp_Level < 0 and then Labour_On and then Level_On then
         Read_Camp_Ground;
         Camp_Level := Choose_Level;
      end if;
      if Camp_Level >= 0 then
         Read_Camp_Ground;                    --  (its ground as it lies now: someone may have dug in it)
      end if;
      Ground_Left_N := Count_Ground_Left;
      if Ground_Left_N = 0
        and then (for all K in Item_Kind => Zones (Camp_Zone_N).Got (K) >= Build_Takes (Camp_Zone) (K))
      then
         Zones (Camp_Zone_N).Built := True;
         Sod_Bits := 0;                       --  (what turf is left lying is trodden in)
         Settle_On_Floor;
      end if;
   end Check_Built;

   --  Patch P made ready by member I (0: on the spot, by nobody): what
   --  grows on it is cut; on the floor, earth is dug off down to its level
   --  (into I's hands, as much as they hold), the turf is cut off (its
   --  earth left lying, Sod_Bits), and the hollows are filled with what
   --  earth I has and then with what turf lies there.  All of its blocks at
   --  once, so the ground round it is worked out again once and not block
   --  by block.
   procedure Make_Ready (P : Positive; I : Natural := 0) is
      Limit : constant Natural := Carry_Limit (Earth);
      --  the earth in its hands, and how much more they hold
      Has   : constant Natural := (if I > 0 and then Band (I).Carry = Earth then Band (I).Carried else 0);
      Room  : constant Natural :=
        (if I = 0 then Natural'Last
         elsif Band (I).Carried = 0 or else Band (I).Carry = Earth then Limit - Natural'Min (Limit, Has)
         else 0);
      Moved : Boolean := False;
      Dug, Tipped : Natural := 0;       --  into its hands, and out of them
      type Pass is range 1 .. 3;         --  what is cut and dug off; the turf; the hollows
   begin
      if Camp_Zone_N = 0 then
         return;
      end if;
      for Now in Pass loop
         for K in Zones (Camp_Zone_N).First + 1 .. Zones (Camp_Zone_N).First + Zones (Camp_Zone_N).N loop
            for X in Integer (Runs (K).X0) .. Integer (Runs (K).X1) loop
               declare
                  Y   : constant Integer := Integer (Runs (K).Y);
                  Top : Integer := Ground_Row (X, Y, Integer (Runs (K).Z));
               begin
                  if Patch_Of (X, Y) = P and then Top >= 0 then
                     if Now = 1 then
                        for Up in 1 .. 3 loop
                           exit when Mat (X, Y, Top + Up) not in Tall_Grass | Wild_Grain | Wild_Vegetables;
                           Write_Src (X, Y, Top + Up, Air_Block);
                        end loop;
                        if Camp_Level >= 0 and then Near_Fire (X, Y) then
                           while Top > Camp_Level and then Is_Earth (Mat (X, Y, Top)) and then Dug < Room loop
                              Write_Src (X, Y, Top, Air_Block);
                              Top := Top - 1;
                              Dug := Dug + 1;
                              Moved := True;
                           end loop;
                        end if;
                     elsif Now = 2 then
                        if Near_Fire (X, Y) and then Mat (X, Y, Top) = Grass
                          and then (Camp_Level < 0 or else Top <= Camp_Level)
                        then
                           Write_Src (X, Y, Top, (Mat => Dirt, State => 0));
                           if Camp_Level >= 0 and then I > 0 then
                              Sod_Bits := Sod_Bits + 1;
                           end if;
                        end if;
                     elsif Camp_Level >= 0 and then Near_Fire (X, Y) then
                        --  (the turf's earth only once nothing is left to dig off the floor)
                        while Top < Camp_Level
                          and then (I = 0 or else Tipped < Has + Dug
                                    or else (Cut_Left_N = 0 and then Sod_Bits >= Sod_Share))
                        loop
                           Top := Top + 1;
                           Write_Src (X, Y, Top, (Mat => Dirt, State => 0));
                           Moved := True;
                           if I > 0 and then Tipped < Has + Dug then
                              Tipped := Tipped + 1;
                           elsif I > 0 then
                              Sod_Bits := Sod_Bits - Sod_Share;
                           end if;
                        end loop;
                     end if;
                  end if;
               end;
            end loop;
         end loop;
      end loop;
      if I > 0 and then (Band (I).Carried = 0 or else Band (I).Carry = Earth) then
         Band (I).Carried := Has + Dug - Tipped;
         Band (I).Carry := (if Band (I).Carried > 0 then Earth else Nothing);
      end if;
      if Moved then
         Read_Camp_Ground;
         Settle_On_Floor;
      end if;
   end Make_Ready;

   --  The camp built on the spot: its ground ready (its floor level, the
   --  earth from nowhere and to nowhere), its hearth standing.  (A scripted
   --  fire.)  Tread False: the camp's labour off, where it stands as it
   --  lies, its floor left alone.
   procedure Finish_Camp (Tread : Boolean) is
   begin
      if Camp_Zone_N = 0 then
         return;
      end if;
      if Tread then
         if Camp_Level < 0 and then Level_On then
            Read_Camp_Ground;
            Camp_Level := Choose_Level;
         end if;
         for P in 1 .. Max_Patch loop
            Make_Ready (P);
         end loop;
      end if;
      Zones (Camp_Zone_N).Got := Build_Takes (Camp_Zone);
      Zones (Camp_Zone_N).Built := True;
      Ground_Left_N := 0;
      Cut_Left_N := 0;
      Fill_Left_N := 0;
      Sod_Bits := 0;
      Settle_On_Floor;
   end Finish_Camp;

   --  Loads on their way to the camp for use U: promised from a stockpile
   --  cell, being fetched (a full load counted), or carried.  For_Ring in
   --  stones; the others in pieces, one a load.
   function Build_Coming (U : Camp_Use) return Natural is
      N : Natural := 0;
   begin
      for I in 1 .. N_Members loop
         declare
            M : Member renames Band (I);
         begin
            if not M.Is_Dead and then M.Use_For = U then
               if M.State in To_Take | Taking then
                  N := N + M.Due;
               elsif M.State in To_Source | Gathering then
                  N := N + (if U = For_Ring then Carry_Limit (Stone) else 1);
               elsif M.Carried > 0 then
                  N := N + (if U = For_Ring then M.Carried else 1);
               end if;
            end if;
         end;
      end loop;
      return N;
   end Build_Coming;

   --  What the hearth is still short of, counting nothing on its way.
   function Hearth_Short (K : Item_Kind) return Natural is
     (if Camp_Set and then Camp_Zone_N > 0 and then not Zones (Camp_Zone_N).Built
        and then Zones (Camp_Zone_N).Got (K) < Build_Takes (Camp_Zone) (K)
      then Build_Takes (Camp_Zone) (K) - Zones (Camp_Zone_N).Got (K) else 0);

   ------------------------------------------------------------------ extra tasks: how many hands

   Hands_Set : Natural := 0;        --  the limit, as set (0: one in Extra_Share of the living)

   function Extra_Hands return Natural is
      N : Natural := 0;
   begin
      if Hands_Set > 0 then
         return Hands_Set;
      end if;
      for I in 1 .. N_Members loop
         if not Band (I).Is_Dead then
            N := N + 1;
         end if;
      end loop;
      return Natural'Max (1, N / Extra_Share);
   end Extra_Hands;

   procedure Set_Extra_Hands (N : Natural) is
   begin
      Hands_Set := Natural'Min (N, Max_Members);
   end Set_Extra_Hands;

   --  A hand at an extra task now: at a patch of the camp's ground or a
   --  metre of path (or on its way to one), or on an errand for the camp's
   --  building with its hands to it (not eating or asleep on the way).  The
   --  cook at its own camp's building is not one.
   function At_Extra_Task (J : Positive) return Boolean is
     (not Band (J).Is_Dead and then not (Band (J).Job = Cook and then Band (J).Site_Seg = 0)
      and then (Band (J).State in To_Patch | Tamping
                or else (Band (J).Site_Seg > 0 and then Band (J).State = Idle)      --  (between two metres)
                or else (Band (J).Use_For in For_Ring | For_Frame | For_Seat | For_Floor
                         and then (Band (J).State in To_Source | Gathering | To_Take | Taking | To_Camp | Putting_In
                                   or else (Band (J).State = Idle and then Band (J).Carried > 0)))
                or else (Band (J).Carry = Earth and then Band (J).Carried > 0           --  (earth off the camp's floor)
                         and then Band (J).State in Idle | To_Store | Storing)));

   function At_Extra return Natural is
      N : Natural := 0;
   begin
      for J in 1 .. N_Members loop
         if At_Extra_Task (J) then
            N := N + 1;
         end if;
      end loop;
      return N;
   end At_Extra;

   --  Where the cook takes its load: the pot, the fire (sticks), the stack
   --  of firewood (logs), the next seat.
   function Camp_Spot (M : Member) return Vec3 is
   begin
      case M.Use_For is
         when For_Fire =>
            if M.Carry = Sticks then
               return Cook_Side;
            end if;
            declare
               R : constant Vec3 := Camp_Off (Stack_Off.X, Stack_Off.Y);
               E : constant Vec3 := Camp_Off (1.0, 0.0);
            begin
               return On_Ground (Camp_At.X + R.X - 0.7 * E.X, Camp_At.Y + R.Y - 0.7 * E.Y);
            end;
         when For_Seat =>
            declare
               L : constant Positive := Integer'Min (Seat_Logs, Seats_Laid + 1);
               A : constant Float := Seat_Angle (L);
            begin
               return On_Ground (Seat_Log (L).X + 0.6 * Cos (A), Seat_Log (L).Y + 0.6 * Sin (A));
            end;
         when For_Pot | For_Store | For_Stoke =>
            return Cook_Side;
         when For_Ring | For_Frame | For_Floor | For_House =>
            return Pot_Side (M.Pos);          --  to the fire's place, from the side it comes
      end case;
   end Camp_Spot;

   --  Its own place to sleep: round the fire, feet to it, the firewood's
   --  corner left clear; round the stake while there is no camp.
   function Bed_Spot (I : Positive) return Vec3 is
      N : constant Positive := Integer'Max (1, N_Members);
   begin
      if N_Houses > 0 and then Housed (I) then
         return Bed_Place (Home_Of (I));           --  (under its own roof)
      end if;
      if Camp_Set then
         declare
            Per_Ring : constant := 10;
            Ring     : constant Natural := (I - 1) / Per_Ring;
            In_Ring  : constant Positive := Integer'Max (1, Integer'Min (Per_Ring, N - Ring * Per_Ring));
            K        : constant Natural := (I - 1) mod Per_Ring;
            A : constant Float :=
              (-25.0 + 320.0 * (Float (K) + 0.5) / Float (In_Ring)) * Ada.Numerics.Pi / 180.0 + Camp_Turn;
            R : constant Float := 2.7 + 2.0 * Float (Ring);
         begin
            return On_Ground (Camp_At.X + R * Cos (A), Camp_At.Y + R * Sin (A));
         end;
      end if;
      declare
         A : constant Float := 2.0 * Ada.Numerics.Pi * Float (I - 1) / Float (N) + 0.4;
         R : constant Float := 3.0 + 1.2 * Float ((I - 1) mod 2);
      begin
         return (Stake_At.X + R * Cos (A), Stake_At.Y + R * Sin (A), Stake_At.Z);
      end;
   end Bed_Spot;

   --  What a sleeper lies with its feet toward: the fire (the stake, with
   --  no camp); under its own roof, its house's back wall, so that it lies
   --  along the house and clear of its walls.
   function Bed_Facing (I : Positive) return Vec3 is
     (if At_Home (I)
      then Bed_Place (Home_Of (I)) + (Float (Houses (Home_Of (I)).F.Vx), Float (Houses (Home_Of (I)).F.Vy), 0.0)
      elsif Camp_Set then Camp_At else Stake_At);

   procedure Build_Camp_Now is
   begin
      if Camp_Set and then not Camp_Built then
         Finish_Camp (Tread => True);
      end if;
   end Build_Camp_Now;

   procedure Stoke (Hours : Float) is
   begin
      if Camp_Set then
         Build_Camp_Now;
         Fuel_H := Fuel_H + Float'Max (0.0, Hours);
         if Fuel_H > 0.0 then
            Ember_H := 0.0;
         end if;
      end if;
   end Stoke;

   --  The fire: a log's burning, whether it gives warmth (burning, or
   --  dying down on its embers), and how well it burns: full until its last
   --  Fire_Sink_Hours of wood, sinking through those to Ember_Heat, and
   --  through the die-down to nothing.
   function Log_Burns return Float is (if Labour_On then Log_Hours else Instant_Log_Hours);
   function Fire_Warm return Boolean is (Fuel_H > 0.0 or else Ember_H > 0.0);
   function Fire_Heat return Float is
     (if Fuel_H > 0.0 then Float'Min (1.0, Ember_Heat + (1.0 - Ember_Heat) * Fuel_H / Fire_Sink_Hours)
      elsif Ember_H > 0.0 then Ember_Heat * Float'Min (1.0, Ember_H / Die_Down_Hours)
      else 0.0);

   procedure Set_Labour (On : Boolean) is
   begin
      Labour_On := On;
   end Set_Labour;
   function Labour return Boolean is (Labour_On);

   function Camp_State return Camp_View is
     ((Built => Camp_Built, Ground_Left => (if Camp_Built then 0 else Ground_Left_N),
       Stones => (if Camp_Zone_N > 0 then Zones (Camp_Zone_N).Got (Stone) else 0),
       Frame => (if Camp_Zone_N > 0 then Zones (Camp_Zone_N).Got (Wood) else 0),
       Looking => Far_Reach,
       To_Dig => (if Camp_Built then 0 else Cut_Left_N), To_Fill => (if Camp_Built then 0 else Fill_Left_N),
       Floor_Z => (if Camp_Level >= 0 then Float (Camp_Level + 1) * 0.25 else -1.0),
       Seats => Seats_Laid, Logs => Fire_Logs, Fuel_H => Fuel_H, Burning => Fuel_H > 0.0,
       Dying => Fuel_H <= 0.0 and then Ember_H > 0.0, Ember_H => Ember_H, Heat => Fire_Heat,
       Stew => Pot_Stew, In_Pot => Pot_Raw,
       Stirring => (for some I in 1 .. N_Members => Band (I).State = Cooking), Burnt => N_Burnt,
       Set_Aside => Pot_Out));

   ------------------------------------------------------------------ food: what there is

   --  Stew in the pot not set aside for anyone.
   function Stew_Free return Natural is (if Pot_Stew > Pot_Out then Pot_Stew - Pot_Out else 0);

   --  Of K in the stockpiles, not set aside for anyone.
   function Free_Stock (K : Item_Kind) return Natural is
      N : Natural := 0;
   begin
      for C in 1 .. N_Cells loop
         if Cells (C).Kind = K and then Cells (C).Count > Cells (C).Outgoing then
            N := N + Cells (C).Count - Cells (C).Outgoing;
         end if;
      end loop;
      return N;
   end Free_Stock;

   --  The winter store: of each kind, how many are held back now (none in
   --  winter): the order's days of the band's food, taken from what is
   --  stored, the kinds that keep first.

   function Day_Need return Float is
      N : Float := 0.0;
   begin
      for I in 1 .. N_Members loop
         if not Band (I).Is_Dead then
            N := N + Float (Day_Food) * Size_Of (Band (I));
         end if;
      end loop;
      return N;
   end Day_Need;

   function Held (K : Item_Kind) return Natural is separate;

   function Usable (K : Item_Kind) return Natural is (Free_Stock (K) - Natural'Min (Free_Stock (K), Held (K)));

   function Held_Days return Float is
      P : Natural := 0;
      D : constant Float := Day_Need;
   begin
      for J of Keep_Order loop
         P := P + Held (J) * Stew_Food (J);
      end loop;
      return (if D > 0.0 then Float (P) / D else 0.0);
   end Held_Days;

   function Store_Held_Days return Float is (Held_Days);
   function Winter_Store return Natural is (Store_Days);
   procedure Set_Winter_Store (Days : Natural) is
   begin
      Store_Days := Natural'Min (Days, 60);
   end Set_Winter_Store;

   --  Food to be had: stew, or raw food in the stockpiles, not set aside
   --  or held back.
   function Food_In_Store return Boolean is
   begin
      if Stew_Free > 0 then
         return True;
      end if;
      for K of Keep_Order loop
         if Raw_Food (K) > 0 and then Usable (K) > 0 then
            return True;
         end if;
      end loop;
      return False;
   end Food_In_Store;

   --  What the stockpiles hold that the cook could put in the pot, in
   --  points of stew (before the bonus), not set aside.
   function Stew_Stock return Natural is
      N : Natural := 0;
   begin
      for K of Keep_Order loop
         N := N + Usable (K) * Stew_Food (K);
      end loop;
      return N;
   end Stew_Stock;

   function Has_Cook return Boolean is
     (for some I in 1 .. N_Members => Band (I).Job = Cook and then not Band (I).Is_Dead);

   ------------------------------------------------------------------ needs: eating and sleeping

   --  Items of food at Per points each that fill Points (rounded up).
   function Items_For (Points : Natural; Per : Positive) return Natural is ((Points + Per - 1) / Per);

   procedure Start_Eating (M : in out Member; Points : Natural) is
   begin
      M.Ration := Points;
      M.Had_Stew := M.From_Pot;
      N_Eaten := N_Eaten + Points;
      M.State := Eating;
      M.Work := 0.0;
      M.Route.N := 0;
      M.Pace := 0.0;
   end Start_Eating;

   --  It eats what it carries, if that is food it may eat raw (not what
   --  the cook is taking to the pot).
   function Eat_Carried (M : in out Member) return Boolean is
   begin
      if M.Carried = 0 or else Raw_Food (M.Carry) = 0 or else M.Use_For /= For_Store then
         return False;
      end if;
      declare
         Per : constant Positive := Raw_Food (M.Carry);
         N   : constant Natural := Natural'Min (M.Carried, Items_For (Want_Points (M), Per));
      begin
         Raw_Eaten_N (M.Carry) := Raw_Eaten_N (M.Carry) + N;
         M.Carried := M.Carried - N;
         if M.Carried = 0 then
            M.Carry := Nothing;
         end if;
         M.From_Pot := False;
         Start_Eating (M, N * Per);
      end;
      return True;
   end Eat_Carried;

   --  What it set aside, given back: stew in the pot (a bowl it carries
   --  goes back in), or what it was to eat at a stockpile cell.
   procedure Unreserve_Food (M : in out Member) is
   begin
      if M.From_Pot then
         if M.State = To_Eat then
            Pot_Out := Pot_Out - Natural'Min (Pot_Out, M.Ration);
         elsif M.State = To_Seat then
            Pot_Stew := Pot_Stew + M.Ration;
         end if;
      elsif M.Cell in 1 .. N_Cells then
         declare
            C : Cell renames Cells (M.Cell);
            Due : constant Natural := Items_For (M.Ration, Positive'Max (1, Raw_Food (C.Kind)));
         begin
            C.Outgoing := C.Outgoing - Natural'Min (C.Outgoing, Due);
            if C.Count = 0 and then C.Incoming = 0 and then C.Outgoing = 0 then
               C.Kind := Nothing;
            end if;
         end;
      end if;
      M.Cell := 0;
      M.Ration := 0;
      M.From_Pot := False;
      M.Seat := 0;
   end Unreserve_Food;

   --  The free place at the fire nearest M (0: none).
   function Free_Seat (I : Positive) return Natural is
      M      : Member renames Band (I);
      Best   : Natural := 0;
      Best_D : Float := Float'Last;
   begin
      for K in 1 .. 2 * Seat_Logs loop
         if (for all J in 1 .. N_Members =>
               J = I or else Band (J).Seat /= K or else not Band (J).From_Pot
               or else Band (J).State not in To_Eat | To_Seat | Eating)
         then
            declare
               D : constant Float := Flat_Dist (M.Pos, Seat_Place (K));
            begin
               if D < Best_D then
                  Best_D := D;
                  Best := K;
               end if;
            end;
         end if;
      end loop;
      return Best;
   end Free_Seat;

   --  To the pot for a bowl of stew, set aside for it on the way; it eats
   --  it at a free place at the fire (standing by the pot when there is none).
   function Go_Eat_Stew (I : Positive) return Boolean is
      M : Member renames Band (I);
   begin
      if not Camp_Set or else Stew_Free = 0 or else Failed (M, Camp_Id) then
         return False;
      end if;
      declare
         Seat : constant Natural := Free_Seat (I);
         Side : constant Vec3 := Pot_Side (if Seat > 0 then Seat_Place (Seat) else M.Pos);
      begin
         if Route_To (M, Side, 0.6) then
            M.From_Pot := True;
            M.Seat := Seat;
            M.Ration := Natural'Min (Stew_Free, Want_Points (M));
            Pot_Out := Pot_Out + M.Ration;
            M.Cell := 0;
            M.State := To_Eat;
            return True;
         end if;
         Remember_Failure (M, Camp_Id);
      end;
      return False;
   end Go_Eat_Stew;

   --  Raw, from a stockpile: apples first, then berries, then vegetables
   --  (the cook's best greens last); the nearest cell of the first of
   --  those there is, setting aside what it will eat there.

   function Go_Eat (I : Positive) return Boolean is separate;

   function Go_Bed (I : Positive) return Boolean is
      M : Member renames Band (I);
   begin
      M.Fends := False;
      if Flat_Dist (M.Pos, Bed_Spot (I)) <= 0.8 then
         M.Route.N := 0;
         M.Pace := 0.0;
         M.State := Sleeping;
         M.Spot := Bed_Facing (I);
         return True;
      end if;
      if Route_To (M, Bed_Spot (I), 0.8)
        or else (Camp_Set and then Route_To (M, Camp_At, 3.0))
        or else Route_To (M, Stake_At, 2.5)
      then
         M.State := To_Bed;
         return True;
      end if;
      return False;
   end Go_Bed;

   --  It leaves what it is at (it will come back to it): what it had
   --  reserved is let go.  Not for a load in its arms, a butchering, a shot
   --  or a pot on the fire: those are finished first.  (To_Site is both: on
   --  its way to a house's ground with empty hands, which is left off, and
   --  with a load for the house, which Step_Member lets it deliver.)
   function Interruptible (S : Task_State) return Boolean is
     (S in Strolling | To_Bush | Picking | To_Tree | To_Pile | To_Source | Gathering | Stalking | To_Carcass
         | To_Take | To_Patch | Tamping | To_Site | Raising);

   procedure Interrupt (M : in out Member; I : Positive) is
   begin
      Release (M, I);
      M.Prey := 0;
      M.Route.N := 0;
      M.State := Idle;
      M.Wait := 0.0;
   end Interrupt;

   ------------------------------------------------------------------ fending for itself


   --  Fending: it holds enough raw food to fill up.
   function Has_Its_Fill (M : Member) return Boolean is
     (M.Fends and then M.Carried > 0 and then M.Carried * Raw_Food (M.Carry) >= Want_Points (M));

   --  Its job left, out to gather for itself what a gatherer would.
   function Go_Fend (I : Positive) return Boolean is
      M : Member renames Band (I);
      Was : constant Boolean := M.Fends;
   begin
      M.Fends := True;
      M.Use_For := For_Store;
      if Go_Forage (I) then
         if not Was then
            M.Mood := Float'Max (0.0, M.Mood - Mood_Fend);
         end if;
         return True;
      end if;
      M.Fends := False;
      return False;
   end Go_Fend;

   ------------------------------------------------------------------ the cook

   --  (the camp's labour off: there is wood, on the fire or its stack, to see a pot through)
   function Fuel_Ok return Boolean is (Fuel_H + Float (Fire_Logs) * Log_Burns >= Cook_Hours);

   --  The fire tended by hand: it wants wood put on it now.  For cooking,
   --  when what is on it will not see a pot through; for the night, from
   --  Stoke_Ahead_Hours before bedtime, when what is on it and its dying
   --  down after will not last till waking; in winter, once it has begun to
   --  die down.
   function Fire_Wants (Cooking : Boolean) return Boolean is
      H : constant Float := Hour_Of_Day;
      To_Wake : constant Float :=
        (if H >= Bed_Hour - Stoke_Ahead_Hours then 24.0 - H + Wake_Hour elsif H < Wake_Hour then Wake_Hour - H
         else 0.0);
   begin
      return (Cooking and then Fuel_H < Cook_Hours)
        or else (To_Wake > 0.0 and then Fuel_H < To_Wake - Die_Down_Hours)
        or else (Winter_Now and then Fuel_H <= 0.0);
   end Fire_Wants;

   --  Wood on the fire: a log (or an armful of sticks) is burning, and
   --  whatever dying down there was is over.
   --  (Nothing burns where no hearth stands.)
   procedure Feed_Fire (Hours : Float) is
   begin
      if Camp_Built then
         Fuel_H := Fuel_H + Hours;
         Ember_H := 0.0;
      end if;
   end Feed_Fire;

   --  What the pot wants next: meat for up to half of it, the rest greens
   --  (vegetables, else berries, else apples); all meat or all greens when
   --  that is all there is.  Nothing once it is full, or there is nothing.

   function Greens return Item_Kind is
   begin
      for K of Greens_Order loop
         if Usable (K) > 0 then
            return K;
         end if;
      end loop;
      return Nothing;
   end Greens;

   function Pot_Room return Natural is (Integer'Max (0, Pot_Points - Integer (Pot_Stew) - Integer (Pot_Raw)));
   function Pot_Goal return Natural is (Integer'Max (0, Pot_Points - Integer (Pot_Stew)));   --  to fill it

   function Next_Ingredient return Item_Kind is
      G : constant Item_Kind := Greens;
   begin
      if Pot_Room = 0 then
         return Nothing;
      end if;
      if Usable (Meat) > 0 and then (2 * Pot_Meat < Pot_Goal or else G = Nothing) then
         return Meat;
      end if;
      return G;
   end Next_Ingredient;

   --  How many of K to bring: to fill the pot (meat: its half of it, while
   --  there are greens too), a load at most.
   function Ingredient_Count (K : Item_Kind) return Positive is
      Want : Natural := Pot_Room;
   begin
      if K = Meat and then Greens /= Nothing then
         Want := Natural'Min (Want, Integer'Max (0, Pot_Goal / 2 - Integer (Pot_Meat)));
      end if;
      return Positive'Max (1, Natural'Min (Carry_Limit (K), Items_For (Want, Stew_Food (K))));
   end Ingredient_Count;

   --  To the nearest stockpile cell with K not set aside, setting aside up
   --  to N of it, for For_Use at the camp.
   function Go_Take (I : Positive; K : Item_Kind; N : Positive; For_Use : Camp_Use) return Boolean is separate;

   --  To the camp with what it carries.
   function Go_Camp (I : Positive) return Boolean is
      M : Member renames Band (I);
   begin
      if Failed (M, Camp_Id) then
         return False;
      end if;
      if Route_To (M, Camp_Spot (M), 0.6) then
         M.State := To_Camp;
         return True;
      end if;
      Remember_Failure (M, Camp_Id);
      return False;
   end Go_Camp;

   --  To the pot, to stir what is in it over the fire.
   function Go_Stir (I : Positive) return Boolean is
      M : Member renames Band (I);
   begin
      M.Use_For := For_Pot;
      if Go_Camp (I) then
         return True;
      end if;
      M.Use_For := For_Store;
      return False;
   end Go_Stir;

   --  To the nearest standing tree in reach, for an armful of dead sticks
   --  from under it.
   --  For_Use: the fire's (the cook's), or the crossbar's (For_Frame).
   --  Reach_M: how far from the stake a tree may stand.
   function Go_Sticks (I : Positive; For_Use : Camp_Use := For_Fire; Reach_M : Float := Work_Radius_M) return Boolean
     is separate;

   --  To the fire, to put a log from its stack on it.
   function Go_Stoke (I : Positive) return Boolean is
      M : Member renames Band (I);
   begin
      M.Use_For := For_Stoke;
      if Go_Camp (I) then
         return True;
      end if;
      M.Use_For := For_Store;
      return False;
   end Go_Stoke;

   --  The cook sees to a fire that wants wood: a log off its stack; with
   --  none stacked, one from the stockpile; with none stored and a pot to
   --  cook, sticks from under a tree.  False: nothing it can do now.
   function Tend_By_Hand (I : Positive; Cooking : Boolean) return Boolean is
     ((Fire_Logs > 0 and then Go_Stoke (I))
      or else (Fire_Logs = 0 and then Free_Stock (Wood) > 0 and then Go_Take (I, Wood, 1, For_Fire))
      or else (Fire_Logs = 0 and then Cooking and then Go_Sticks (I)));

   ------------------------------------------------------------------ housing: blueprints, lots, the ground

   --  A house's blueprint, block by block in its order (air left out):
   --  made when asked for, and kept for the house last asked about.
   type BP_Block is record
      X, Y, Z : Integer_16 := 0;
      M       : Material := Air;
      S       : CB.Stage := CB.Floor;
   end record;
   Max_BP : constant := Max_House_Blocks;
   type BP_Array is array (1 .. Max_BP) of BP_Block;
   type BP_Access is access BP_Array;
   BP    : constant BP_Access := new BP_Array;
   BP_N  : Natural := 0;
   BP_Of : Natural := 0;             --  the house it is of (0: none)

   procedure Blueprint_Of (H : Positive) is
      procedure Note (Bx, By, Bz : Integer; M : Material; S : CB.Stage) is
      begin
         if M /= Air and then BP_N < Max_BP then
            BP_N := BP_N + 1;
            BP (BP_N) := (Integer_16 (Bx), Integer_16 (By), Integer_16 (Bz), M, S);
         end if;
      end Note;
      procedure Draw is new CB.Blueprint (Note);
   begin
      if BP_Of /= H or else not House_Memos_On then
         BP_N := 0;
         Draw (Houses (H).F);
         BP_Of := H;
      end if;
   end Blueprint_Of;

   procedure Set_House_Memos (On : Boolean) is
   begin
      House_Memos_On := On;
      BP_Of := 0;
      Lots_Full := False;
   end Set_House_Memos;

   --  What a block is made from, and how many blocks one of that makes.
   --  Timber is of logs; thatch is straw, and so is daub (the straw in it:
   --  its earth is the site's own, its wattle what was cut there); a floor
   --  of beaten earth and the air of a door or a window take nothing
   --  (Nothing: work alone, never carried, never counted in what a house
   --  takes or has).
   function Kind_Of_Block (M : Material) return Item_Kind is
     (case M is when Thatch | Daub => Straw, when Log | Plank => Wood, when others => Nothing);
   function Blocks_Per (K : Item_Kind) return Positive is (if K = Straw then Thatch_Per_Sheaf else Planks_Per_Log);

   --  What house H's blueprint comes to: its blocks, where its floor, its
   --  frame and its walls end, and the logs and sheaves they take.
   procedure Measure_House (H : Positive) is
      Hs : House_Rec renames Houses (H);
      N  : Per_Kind := [others => 0];
   begin
      BP_Of := 0;
      Blueprint_Of (H);
      Hs.Total := BP_N;
      Hs.Floor_N := 0;
      Hs.Frame_N := 0;
      Hs.Walls_N := 0;
      Hs.Wood_N := 0;
      for K in 1 .. BP_N loop
         N (Kind_Of_Block (BP (K).M)) := N (Kind_Of_Block (BP (K).M)) + 1;
         if Kind_Of_Block (BP (K).M) = Wood then
            Hs.Wood_N := K;
         end if;
         if BP (K).S = CB.Floor then
            Hs.Floor_N := K;
         end if;
         if BP (K).S in CB.Floor | CB.Trim then
            Hs.Frame_N := K;
         end if;
         if BP (K).S in CB.Floor | CB.Trim | CB.Walls | CB.Gables then
            Hs.Walls_N := K;
         end if;
      end loop;
      Hs.Takes := [others => 0];
      for K in Item_Kind loop
         if K /= Nothing and then N (K) > 0 then
            Hs.Takes (K) := (N (K) + Blocks_Per (K) - 1) / Blocks_Per (K);
         end if;
      end loop;
   end Measure_House;

   --  What a house still takes that has not been carried to it; and that
   --  of a zone's houses, and of all of them.
   function House_Short (H : Positive; K : Item_Kind) return Natural is
     (if Houses (H).Built or else Houses (H).Got (K) >= Houses (H).Takes (K) then 0
      else Houses (H).Takes (K) - Houses (H).Got (K));

   function Zone_Short (Z : Positive; K : Item_Kind) return Natural is
      N : Natural := 0;
   begin
      for H in 1 .. N_Houses loop
         if Houses (H).Zone = Z then
            N := N + House_Short (H, K);
         end if;
      end loop;
      return N;
   end Zone_Short;

   function Houses_Short (K : Item_Kind) return Natural is
      N : Natural := 0;
   begin
      for H in 1 .. N_Houses loop
         N := N + House_Short (H, K);
      end loop;
      return N;
   end Houses_Short;

   --  Where a house can go is worked out on a grid of block columns: 0, not
   --  the zone's ground; above, the row of its ground's top and one; Lot_Taken,
   --  a house's lot.
   type Lot_Grid is array (0 .. Max_Plan_B - 1, 0 .. Max_Plan_B - 1) of Integer_16;
   type Lot_Grid_Access is access Lot_Grid;
   Lot_G     : constant Lot_Grid_Access := new Lot_Grid;
   Lot_X0    : Integer := 0;
   Lot_Y0    : Integer := 0;
   Lot_NX    : Natural := 0;
   Lot_NY    : Natural := 0;
   Lot_Taken : constant := -1;

   procedure Lot_Open (Bx0, By0, Bx1, By1 : Integer) is
   begin
      Lot_X0 := Bx0;
      Lot_Y0 := By0;
      Lot_NX := Integer'Min (Max_Plan_B, Integer'Max (0, Bx1 - Bx0 + 1));
      Lot_NY := Integer'Min (Max_Plan_B, Integer'Max (0, By1 - By0 + 1));
      for X in 0 .. Lot_NX - 1 loop
         for Y in 0 .. Lot_NY - 1 loop
            Lot_G (X, Y) := 0;
         end loop;
      end loop;
   end Lot_Open;

   function Lot_Cell (Bx, By : Integer) return Integer is
     (if Bx - Lot_X0 in 0 .. Lot_NX - 1 and then By - Lot_Y0 in 0 .. Lot_NY - 1
      then Integer (Lot_G (Bx - Lot_X0, By - Lot_Y0)) else 0);

   procedure Lot_Run (R : Run_Rec) is
   begin
      for X in Integer (R.X0) .. Integer (R.X1) loop
         if X - Lot_X0 in 0 .. Lot_NX - 1 and then Integer (R.Y) - Lot_Y0 in 0 .. Lot_NY - 1 then
            Lot_G (X - Lot_X0, Integer (R.Y) - Lot_Y0) := R.Z + 1;
         end if;
      end loop;
   end Lot_Run;

   --  A house's lot is taken.
   procedure Lot_Take (F : CB.House) is
   begin
      for V in V_Lo .. Lot_Back (F) loop
         for U in -Lot_Left (F) .. F.W - 1 + Lot_Right (F) loop
            declare
               X : constant Integer := H_X (F, U, V) - Lot_X0;
               Y : constant Integer := H_Y (F, U, V) - Lot_Y0;
            begin
               if X in 0 .. Lot_NX - 1 and then Y in 0 .. Lot_NY - 1 then
                  Lot_G (X, Y) := Lot_Taken;
               end if;
            end;
         end loop;
      end loop;
   end Lot_Take;

   --  The grid of zone Z as things stand: its ground, less every lot taken.
   procedure Lot_Grid_Of_Zone (Z : Positive) is
      R : Zone_Rec renames Zones (Z);
   begin
      Lot_Open (R.Bx0, R.By0, R.Bx1, R.By1);
      for K in R.First + 1 .. R.First + R.N loop
         Lot_Run (Runs (K));
      end loop;
      for H in 1 .. N_Houses loop
         Lot_Take (Houses (H).F);
      end loop;
   end Lot_Grid_Of_Zone;

   --  A house as placed: its walls and the bank round them wholly on the
   --  zone's free ground, on ground that falls no more than Max_Step_B, its
   --  lot crossing no other.  On_A_Path: a path's own ground is in the way
   --  (on a slanting path it steps further back).
   type Lot_Verdict is (Clear, On_A_Path, Blocked);

   function Check_Lot (F : CB.House) return Lot_Verdict is
      Lo : Integer := Integer'Last;
      Hi : Integer := Integer'First;
      Au : constant Integer := Apron_U (F);
      On_Path_Seen, Bad : Boolean := False;
   begin
      for V in V_Lo .. Lot_Back (F) loop
         for U in -Lot_Left (F) .. F.W - 1 + Lot_Right (F) loop
            declare
               X : constant Integer := H_X (F, U, V);
               Y : constant Integer := H_Y (F, U, V);
               C : constant Integer := Lot_Cell (X, Y);
            begin
               if C = Lot_Taken then
                  return Blocked;
               end if;
               if U in -Au .. F.W - 1 + Au and then V <= V_Hi (F) then
                  if C = 0 then
                     if Near_Path ((Float (X) + 0.5) * 0.25, (Float (Y) + 0.5) * 0.25, 0.0) then
                        On_Path_Seen := True;
                     else
                        Bad := True;
                     end if;
                  elsif U in 0 .. F.W - 1 and then V in 0 .. F.D - 1 then
                     Lo := Integer'Min (Lo, C - 1);
                     Hi := Integer'Max (Hi, C - 1);
                  end if;
               end if;
            end;
         end loop;
      end loop;
      return (if On_Path_Seen then On_A_Path elsif Bad or else Hi - Lo > CB.Max_Step_B then Blocked else Clear);
   end Check_Lot;

   --  The level of its pad: the highest at which the earth dug off what
   --  stands above it is at least what the hollows below it take (so that
   --  the earth for them is always there, as for the camp's floor).
   procedure Choose_Pad (F : in out CB.House) is
      Lo : Integer := Integer'Last;
      Hi : Integer := Integer'First;
      Au : constant Integer := Apron_U (F);
   begin
      for V in 0 .. F.D - 1 loop
         for U in 0 .. F.W - 1 loop
            Lo := Integer'Min (Lo, Lot_Cell (H_X (F, U, V), H_Y (F, U, V)) - 1);
            Hi := Integer'Max (Hi, Lot_Cell (H_X (F, U, V), H_Y (F, U, V)) - 1);
         end loop;
      end loop;
      for Level in reverse Lo .. Hi loop
         F.Pad := Level + 1;
         declare
            Cut, Fill : Natural := 0;
         begin
            for V in V_Lo .. V_Hi (F) loop
               for U in -Au .. F.W - 1 + Au loop
                  declare
                     Old : constant Integer := Lot_Cell (H_X (F, U, V), H_Y (F, U, V)) - 1;
                     T   : constant Integer := Target_Row (F, U, V, Old);
                  begin
                     if Old > T then
                        Cut := Cut + Old - T;
                     else
                        Fill := Fill + T - Old;
                     end if;
                  end;
               end loop;
            end loop;
            exit when Cut >= Fill;
         end;
      end loop;
   end Choose_Pad;

   --  The way out from a house's door to its path, on the grid: how many
   --  block columns of the zone's free ground lie between its front wall
   --  and the path's ground (the least, of its door's columns), and the row
   --  of the ground where that way meets the path.  None (0): something
   --  that is not a path lies across it, or no path is come to.
   procedure Door_Way (F : in out CB.House) is
      Door : CB.Opening renames F.Openings (1);
      Most : constant := CB.Max_Push_B + CB.Setback_Max_B + 6;
      Run  : Natural := Most + 1;
      Row  : Integer := F.Pad - 1;
   begin
      F.Door_Run := 0;
      F.Door_Row := F.Pad - 1;
      for U in Door.Offset .. Door.Offset + Door.Width - 1 loop
         declare
            N : Natural := 0;
         begin
            while N < Most and then Lot_Cell (H_X (F, U, -(N + 1)), H_Y (F, U, -(N + 1))) > 0 loop
               N := N + 1;
            end loop;
            if N = 0 or else N = Most
              or else not Near_Path ((Float (H_X (F, U, -(N + 1))) + 0.5) * 0.25,
                                     (Float (H_Y (F, U, -(N + 1))) + 0.5) * 0.25, 0.0)
            then
               return;
            end if;
            if N < Run then
               Run := N;
               Row := Lot_Cell (H_X (F, U, -N), H_Y (F, U, -N)) - 1;
            end if;
         end;
      end loop;
      F.Door_Run := Run;
      F.Door_Row := Row;
   end Door_Way;

   --  The places a house could front a path: a point of a path's middle
   --  every metre, to either side, where the zone's ground lies beside it.
   type Front_Rec is record
      P      : Vec3 := (0.0, 0.0, 0.0);
      Nx, Ny : Float := 0.0;          --  the way from the path to that side of it
      Key    : Float := 0.0;          --  how far it is from the homestake
   end record;
   type Front_Array is array (1 .. Max_Fronts) of Front_Rec;
   type Front_Access is access Front_Array;
   Fronts : constant Front_Access := new Front_Array;

   function House_Seed (Serial : Positive) return U64 is (Castle.Hash.Hash_2 (Band_Seed, 6_001, Serial));

   --  Where on the grid, as it is filled, the house of that serial goes:
   --  the free frontage nearest the homestake.  Its front wall stands a
   --  setback off the path's edge, the house square to the block grid and
   --  facing the path; where a path's ground is in the way (the path runs
   --  aslant) it steps back, Max_Push_B at most.
   procedure Place_House (Serial : Positive; F : out CB.House; Key : out Float; Ok : out Boolean) is
      Seed : constant U64 := House_Seed (Serial);
      Half : constant Float := Path_Width_M / 2.0;
      N    : Natural := 0;
   begin
      Ok := False;
      Key := Float'Last;
      F := CB.Design (Seed);
      for K in 1 .. N_Paths loop
         declare
            S : Path_Seg renames Path_List (K);
            L : constant Float := Flat_Dist (S.A, S.B);
            T : Float := 0.5;
         begin
            if L > 0.5 then
               while T < L loop
                  for Side in -1 .. 1 loop
                     if Side /= 0 and then N < Max_Fronts then
                        declare
                           Tx : constant Float := (S.B.X - S.A.X) / L;
                           Ty : constant Float := (S.B.Y - S.A.Y) / L;
                           P  : constant Vec3 := (S.A.X + Tx * T, S.A.Y + Ty * T, 0.0);
                           Nx : constant Float := -Ty * Float (Side);
                           Ny : constant Float := Tx * Float (Side);
                        begin
                           if Lot_Cell (B (P.X + Nx * (Half + 1.5)), B (P.Y + Ny * (Half + 1.5))) > 0 then
                              N := N + 1;
                              Fronts (N) := (P => P, Nx => Nx, Ny => Ny, Key => Flat_Dist (P, Stake_At));
                           end if;
                        end;
                     end if;
                  end loop;
                  T := T + 1.0;
               end loop;
            end if;
         end;
      end loop;
      for I in 2 .. N loop              --  nearest the stake first
         declare
            A : constant Front_Rec := Fronts (I);
            J : Natural := I - 1;
         begin
            while J >= 1 and then Fronts (J).Key > A.Key loop
               Fronts (J + 1) := Fronts (J);
               J := J - 1;
            end loop;
            Fronts (J + 1) := A;
         end;
      end loop;
      for K in 1 .. N loop
         declare
            A : Front_Rec renames Fronts (K);
            G : CB.House := F;
         begin
            if abs A.Nx >= abs A.Ny then
               G.Vx := (if A.Nx > 0.0 then 1 else -1);
               G.Vy := 0;
               G.Ux := 0;
               G.Uy := 1;
            else
               G.Vx := 0;
               G.Vy := (if A.Ny > 0.0 then 1 else -1);
               G.Ux := 1;
               G.Uy := 0;
            end if;
            declare
               Off : constant Integer :=
                 Integer (Float'Ceiling (Half * 4.0)) + CB.Setback_Min_B
                 + Integer (Shift_Right (Seed, 16) mod U64 (CB.Setback_Max_B - CB.Setback_Min_B + 1))
                 + (if G.Vx + G.Vy < 0 then 1 else 0);
            begin
               for Push in 0 .. CB.Max_Push_B loop
                  G.Fx := B (A.P.X) + G.Vx * (Off + Push) - G.Ux * (G.W / 2);
                  G.Fy := B (A.P.Y) + G.Vy * (Off + Push) - G.Uy * (G.W / 2);
                  G.Door_Run := 0;
                  case Check_Lot (G) is
                     when Clear =>
                        Choose_Pad (G);
                        Door_Way (G);
                        --  its door has to be got to from the path: a pad that
                        --  would stand higher over the path's ground than its
                        --  door's way can step down is cut deeper; one that
                        --  would lie further below it steps back for a longer
                        --  way, if there is room
                        if G.Door_Run > 0 and then G.Pad - 1 > G.Door_Row + Door_Steps (G) then
                           G.Pad := G.Door_Row + Door_Steps (G) + 1;
                        end if;
                        if G.Door_Run > 0 and then G.Pad - 1 >= G.Door_Row - Door_Steps (G) then
                           F := G;
                           Key := A.Key;
                           Ok := True;
                           return;
                        end if;
                     when On_A_Path =>
                        null;
                     when Blocked =>
                        exit;
                  end case;
               end loop;
            end;
         end;
      end loop;
   end Place_House;

   --  A house begun for Owner (0: for nobody yet), on the lot nearest the
   --  homestake that any housing zone has.  Ok False: there is no lot.
   procedure New_House (Owner : Natural; Ok : out Boolean) is
      Best     : CB.House;
      Best_Key : Float := Float'Last;
      Best_Z   : Natural := 0;
      F        : CB.House;
      Key      : Float;
      Fits     : Boolean;
   begin
      Ok := False;
      if N_Houses >= Max_Houses then
         return;
      end if;
      for Z in 1 .. N_Zones loop
         if Zones (Z).Kind = Habitation_Zone and then Zones (Z).N > 0 then
            Lot_Grid_Of_Zone (Z);
            Place_House (House_Serial + 1, F, Key, Fits);
            if Fits and then Key < Best_Key then
               Best := F;
               Best_Key := Key;
               Best_Z := Z;
            end if;
         end if;
      end loop;
      if Best_Z = 0 then
         return;
      end if;
      House_Serial := House_Serial + 1;
      N_Houses := N_Houses + 1;
      Houses (N_Houses) :=
        (Zone => Best_Z, Seed => House_Seed (House_Serial), F => Best, Owner => Owner, others => <>);
      Measure_House (N_Houses);
      Zones_Ver := Zones_Ver + 1;          --  (whatever shows the zones shows its lot)
      Ok := True;
   end New_House;

   --  Nothing a lot is found by has changed since none was found.
   function Lots_As_They_Were return Boolean is
     (Lots_Zones = Zones_Ver and then Lots_Paths = N_Paths and then Lots_Houses = N_Houses);
   procedure Note_Lots_Full is
   begin
      Lots_Full := True;
      Lots_Zones := Zones_Ver;
      Lots_Paths := N_Paths;
      Lots_Houses := N_Houses;
   end Note_Lots_Full;

   --  Once a colony second: a house whose owner has died goes to the first
   --  without one; and a house is begun for whoever has none, as many at
   --  once as there are foresters to build them (one, with none).
   procedure Begin_Houses is
      Open, Foresters : Natural := 0;
      Ok : Boolean;
   begin
      if N_Housing = 0 then
         return;
      end if;
      for H in 1 .. N_Houses loop
         if Houses (H).Owner > 0 and then Band (Houses (H).Owner).Is_Dead then
            Houses (H).Owner := 0;
         end if;
      end loop;
      for H in 1 .. N_Houses loop
         if Houses (H).Owner = 0 then
            for I in 1 .. N_Members loop
               if not Band (I).Is_Dead and then Home_Of (I) = 0 then
                  Houses (H).Owner := I;
                  exit;
               end if;
            end loop;
         end if;
         if not Houses (H).Built then
            Open := Open + 1;
         end if;
      end loop;
      for I in 1 .. N_Members loop
         if not Band (I).Is_Dead and then Band (I).Job = Forester then
            Foresters := Foresters + 1;
         end if;
      end loop;
      for I in 1 .. N_Members loop
         exit when Open >= Natural'Max (1, Foresters);
         if not Band (I).Is_Dead and then Home_Of (I) = 0 then
            if House_Memos_On and then Lots_Full and then Lots_As_They_Were then
               return;                     --  (no lot, and nothing has changed since)
            end if;
            New_House (I, Ok);
            if not Ok then
               Note_Lots_Full;
               return;
            end if;
            Lots_Full := False;
            Open := Open + 1;
         end if;
      end loop;
   end Begin_Houses;

   --  A house's ground is made ready a square metre at a time: patches of
   --  its pad and the bank round it, numbered by where they lie in its frame.
   Max_Site_Patch : constant := Max_Site_Patches;
   type Site_Flags is array (1 .. Max_Site_Patch) of Boolean;
   type Site_Sums is array (1 .. Max_Site_Patch) of Vec3;

   function Site_Patch_At (U, V : Integer) return Positive is
     (((U + CB.Apron_B) / 4) * 16 + (V + 24) / 4 + 1);   --  (V from -22, where a door's way can begin)

   --  The row over a house's ridge: as high as anything of it is built.
   function House_Top (F : CB.House) return Integer is
     (F.Pad + F.Wall_H + (if F.Ridge_Along_U then (F.D + 1) / 2 else (F.W + 1) / 2));

   --  A column of a house's ground has work in it: something growing on it
   --  to cut, its top not where it is to be, or (where the house and its
   --  eaves will be) a neighbouring tree's leaves or boughs hanging in the
   --  way.
   function Column_Wants (F : CB.House; U, V : Integer) return Boolean is
      X   : constant Integer := H_X (F, U, V);
      Y   : constant Integer := H_Y (F, U, V);
      Top : constant Integer := Ground_Row (X, Y, F.Pad - 1);
   begin
      return Top >= 0
        and then (Mat (X, Y, Top + 1) in Tall_Grass | Wild_Grain | Wild_Vegetables
                  or else Top /= Target_Row (F, U, V, Top)
                  or else (U in -1 .. F.W and then V in -1 .. F.D
                           and then (for some Z in F.Pad .. House_Top (F) =>
                                       Mat (X, Y, Z) in Crown or else Mat (X, Y, Z) in Trunk)));
   end Column_Wants;

   --  Which patches of house H's ground still have work in them, and for
   --  each the sum of where that work is (X, Y) and how many columns (Z).
   procedure Site_Patches (H : Positive; Wants : out Site_Flags; Sum : out Site_Sums) is
      F  : CB.House renames Houses (H).F;
      Au : constant Integer := Apron_U (F);
   begin
      Wants := [others => False];
      Sum := [others => (0.0, 0.0, 0.0)];
      for V in Site_V_Lo (F) .. V_Hi (F) loop
         for U in -Au .. F.W - 1 + Au loop
            if In_Site (F, U, V) and then Column_Wants (F, U, V) then
               declare
                  P : constant Positive := Site_Patch_At (U, V);
                  C : constant Vec3 := H_Point (F, Float (U), Float (V));
               begin
                  Wants (P) := True;
                  Sum (P) := Sum (P) + (C.X, C.Y, 1.0);
               end;
            end if;
         end loop;
      end loop;
   end Site_Patches;

   --  A column of a house's ground brought to where it is to be: what grows
   --  on it cut, what stands above its level dug off, a hollow filled.  (The
   --  earth is the site's own: what is dug off fills the hollows, and what
   --  is over is thrown aside on the lot.)
   procedure Level_Column (F : CB.House; U, V : Integer) is
      X   : constant Integer := H_X (F, U, V);
      Y   : constant Integer := H_Y (F, U, V);
      Top : constant Integer := Ground_Row (X, Y, F.Pad - 1);
   begin
      if Top < 0 then
         return;
      end if;
      for Up in 1 .. 3 loop
         exit when Mat (X, Y, Top + Up) not in Tall_Grass | Wild_Grain | Wild_Vegetables;
         Write_Src (X, Y, Top + Up, Air_Block);
      end loop;
      declare
         T : constant Integer := Target_Row (F, U, V, Top);
      begin
         for Z in reverse T + 1 .. Top loop
            Write_Src (X, Y, Z, Air_Block);
         end loop;
         for Z in Top + 1 .. T loop
            Write_Src (X, Y, Z, (Mat => Dirt, State => 0));
         end loop;
      end;
      --  where the house and its eaves will be, what hangs there of a tree
      --  standing by is lopped
      if U in -1 .. F.W and then V in -1 .. F.D then
         for Z in F.Pad .. House_Top (F) loop
            if Mat (X, Y, Z) in Crown or else Mat (X, Y, Z) in Trunk then
               Write_Src (X, Y, Z, Air_Block);
            end if;
         end loop;
      end if;
   end Level_Column;

   --  Patch P of house H's ground made ready (0: all of it).
   procedure Level_Patch (H : Positive; P : Natural) is
      F  : CB.House renames Houses (H).F;
      Au : constant Integer := Apron_U (F);
   begin
      for V in Site_V_Lo (F) .. V_Hi (F) loop
         for U in -Au .. F.W - 1 + Au loop
            if In_Site (F, U, V) and then (P = 0 or else Site_Patch_At (U, V) = P) then
               Level_Column (F, U, V);
            end if;
         end loop;
      end loop;
   end Level_Patch;

   --  Someone other than its builder stands where block (X, Y, Z) is to go.
   --  (The builder stands clear of what it lays; where it could find no
   --  such place, the block is laid all the same and it steps out of it.)
   function Someone_At (X, Y, Z : Integer; But : Natural) return Boolean is
     (for some J in 1 .. N_Members =>
        J /= But and then not Band (J).Is_Dead and then B (Band (J).Pos.X) = X and then B (Band (J).Pos.Y) = Y
        and then Z in B (Band (J).Pos.Z) .. B (Band (J).Pos.Z) + Castle.Nav.Head_B - 1);

   --  The footpath from a house's door to the path it fronts: the top of
   --  the ground of its door's way (made a stair with the rest of its
   --  ground) turned to footpath, and what grows on it cut.
   procedure Lay_Door_Path (H : Positive) is
      F    : CB.House renames Houses (H).F;
      Door : CB.Opening renames F.Openings (1);
   begin
      for U in Door.Offset .. Door.Offset + Door.Width - 1 loop
         for T in 1 .. F.Door_Run loop
            declare
               X   : constant Integer := H_X (F, U, -T);
               Y   : constant Integer := H_Y (F, U, -T);
               Top : constant Integer := Ground_Row (X, Y, Target_Row (F, U, -T, F.Pad - 1));
            begin
               if Top >= 0 and then Is_Earth (Mat (X, Y, Top)) and then Zone_Of_Block (X, Y) = Houses (H).Zone then
                  Write_Src (X, Y, Top, (Mat => Footpath, State => 0));
                  for Up in 1 .. 3 loop
                     exit when Mat (X, Y, Top + Up) not in Tall_Grass | Wild_Grain | Wild_Vegetables;
                     Write_Src (X, Y, Top + Up, Air_Block);
                  end loop;
               end if;
            end;
         end loop;
      end loop;
   end Lay_Door_Path;

   --  House H stands: its door's path is laid, its builder is free, and
   --  what was left of the last log and sheaf is offcuts.
   procedure Finish_House (H : Positive) is
      Hs : House_Rec renames Houses (H);
   begin
      Hs.Built := True;
      Hs.Pad_Done := True;
      Hs.Lying := [others => 0];
      Lay_Door_Path (H);
      for I in 1 .. N_Members loop
         if Band (I).Site = H then
            Band (I).Site := 0;
            Band (I).Site_Patch := 0;
         end if;
      end loop;
      Read_Zone_Ground (Hs.Zone);
      Zones_Ver := Zones_Ver + 1;
   end Finish_House;

   --  House H built on the spot, nothing taken from anywhere.
   procedure Raise_Now (H : Positive) is
      Hs : House_Rec renames Houses (H);
   begin
      if not Hs.Pad_Done then
         Level_Patch (H, 0);
         Read_Zone_Ground (Hs.Zone);          --  (its ground as it is made ready, before anything stands on it)
         Hs.Pad_Done := True;
      end if;
      Blueprint_Of (H);
      for K in Hs.Placed + 1 .. BP_N loop
         Write_Src (Integer (BP (K).X), Integer (BP (K).Y), Integer (BP (K).Z), (Mat => BP (K).M, State => 0));
      end loop;
      Hs.Placed := BP_N;
      Hs.Got := Hs.Takes;
      Finish_House (H);
   end Raise_Now;

   procedure Build_Homes_Now is
      Ok : Boolean;
   begin
      Begin_Houses;                        --  (houses nobody's now to those without)
      for I in 1 .. N_Members loop
         if not Band (I).Is_Dead and then Home_Of (I) = 0 then
            New_House (I, Ok);
            exit when not Ok;
         end if;
      end loop;
      for H in 1 .. N_Houses loop
         if not Houses (H).Built then
            Raise_Now (H);
         end if;
      end loop;
   end Build_Homes_Now;

   ------------------------------------------------------------------ demand

   function Demand_Chain return Boolean is (Chain_On);

   --  What the fire burns in a day, as the camp asks for it: all day in
   --  winter; else the night's logs (from an hour before bedtime to waking)
   --  and one for the day's cooking.
   --  (Tended by hand, the night's are fewer by what its dying down covers.)
   function Fire_Day_Logs return Natural is
     (if not Labour_On
      then (if Winter_Now then Natural (Float'Ceiling (24.0 / Instant_Log_Hours))
            else Natural (Float'Ceiling ((Wake_Hour + 24.0 - (Bed_Hour - 1.0)) / Instant_Log_Hours)) + 1)
      elsif Winter_Now then Natural (Float'Ceiling (24.0 / Log_Hours))
      else Natural (Float'Ceiling
                      (Float'Max (0.0, Wake_Hour + 24.0 - (Bed_Hour - Stoke_Ahead_Hours) - Die_Down_Hours) / Log_Hours))
           + 1);

   --  A food that is hunted or gathered, and that the band can eat as
   --  things stand (meat only with a cook and a camp: it is never eaten raw).
   function Feeds (K : Item_Kind) return Boolean is
     ((K = Meat or else (for some G of Gathered => G = K))
      and then (if Camp_Set and then Has_Cook then Stew_Food (K) else Raw_Food (K)) > 0);

   --  The jobs that bring a kind in.
   function Brings (J : Job_Kind; K : Item_Kind) return Boolean is
     (case J is
         when Gatherer => (for some G of Gathered => G = K),
         when Hunter   => K in Meat | Hide,
         when Forester => K = Wood,
         when Porter   => K = Grain or else (for some F of Fetch_Order => F = K),
         when Cook | Unassigned => False);

   function Food_A_Day return Natural is (if Needs_On then Natural (Day_Need) else 0);

   --  Food in store and in the pot, in points, as Food_Days counts it.
   function Food_Points return Natural is
      Cooks : constant Boolean := Camp_Set and then Has_Cook;
      N     : Natural := Pot_Stew + Pot_Raw;
   begin
      for C in 1 .. N_Cells loop
         N := N + Cells (C).Count * (if Cooks then Stew_Food (Cells (C).Kind) else Raw_Food (Cells (C).Kind));
      end loop;
      return N;
   end Food_Points;

   --  The winter store is asked for all year: in winter only the hold on
   --  it lifts (it is eaten), and whoever can still bring food in goes on.
   function Food_Surplus return Natural is (Store_Days * Food_A_Day);
   function Food_Level (Days : Float) return Natural is
     (Food_Surplus + Natural (Float'Ceiling (Float (Food_A_Day) * Days)));

   --  A kind, by its own count: what there is of it (with what is on its
   --  way), what its users take in a day, what is wanted once.
   function Kind_Have (K : Item_Kind) return Natural is
     (case K is
         when Wood   => Wood_Total,
         when Meat   => Have_Or_Coming (Meat) + Meat_Coming,
         when others => Have_Or_Coming (K));
   function Kind_A_Day (K : Item_Kind) return Natural is
     (if K = Wood and then Camp_Set then Fire_Day_Logs else 0);
   function Kind_Once (K : Item_Kind) return Natural is
     (Demand (K) + (if K = Wood and then Camp_Set and then Seats_Laid < Seat_Logs then Seat_Logs - Seats_Laid else 0)
      + Hearth_Short (K) + (if N_Houses > 0 then Houses_Short (K) else 0));
   function Kind_Level (K : Item_Kind; Days : Float) return Natural is
     (Reserves (K) + Kind_Once (K) + Natural (Float'Ceiling (Float (Kind_A_Day (K)) * Days)));

   --  The one question a producer puts.  Off, the answers of before the
   --  chain: nothing has two levels, wood with no reserve has no limit, and
   --  what gatherers bring in is always wanted.
   function Asked_For (K : Item_Kind) return Boolean is
     (if Chain_On then Asking (K) or else (Food_Asking and then Feeds (K))
      else (case K is
               when Wood  => Reserves (Wood) = 0 or else Wood_Total < Reserves (Wood),
               when Meat  => Have_Or_Coming (Meat) + Meat_Coming < Reserves (Meat),
               when Straw => Have_Or_Coming (Straw) < Reserves (Straw),
               when Stone | Water => Have_Or_Coming (K) < Demand (K),
               when others => True));

   --  The stores take stock: each good is asked for from its low level
   --  until its high one.
   procedure Take_Stock is
      procedure Latch (Asked : in out Boolean; Have, Low, High : Natural) is
      begin
         if Have < Low then
            Asked := True;
         elsif Have >= High then
            Asked := False;
         end if;
      end Latch;
   begin
      if not Chain_On then
         return;
      end if;
      Latch (Food_Asking, Food_Points, Food_Level (Ask_Below_Days), Food_Level (Ask_Until_Days));
      for K in Item_Kind loop
         if Cell_Limit (K) > 0 then
            Latch (Asking (K), Kind_Have (K), Kind_Level (K, Ask_Below_Days), Kind_Level (K, Ask_Until_Days));
         end if;
      end loop;
   end Take_Stock;

   procedure Set_Demand_Chain (On : Boolean) is
   begin
      Chain_On := On;
      Reserves (Wood) := (if On then Default_Reserve (Wood) else 0);   --  what each way of working starts with
      Take_Stock;
   end Set_Demand_Chain;

   function Makers_Of (K : Item_Kind) return Natural is
      N : Natural := 0;
   begin
      for I in 1 .. N_Members loop
         if not Band (I).Is_Dead and then Brings (Band (I).Job, K) then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Makers_Of;

   function Demand_For (K : Item_Kind) return Good_View is
     ((Have => Kind_Have (K), A_Day => Kind_A_Day (K), Once => Kind_Once (K), Surplus => Reserves (K),
       Low => Kind_Level (K, Ask_Below_Days), High => Kind_Level (K, Ask_Until_Days),
       Asked => (if Chain_On then Asking (K) else Asked_For (K)), Makers => Makers_Of (K)));

   function Food_Demand return Good_View is
      N : Natural := 0;
   begin
      for I in 1 .. N_Members loop
         if not Band (I).Is_Dead and then (for some K in Item_Kind => Feeds (K) and then Brings (Band (I).Job, K)) then
            N := N + 1;
         end if;
      end loop;
      return (Have => Food_Points, A_Day => Food_A_Day, Once => 0, Surplus => Food_Surplus,
              Low => Food_Level (Ask_Below_Days), High => Food_Level (Ask_Until_Days),
              Asked => (if Chain_On then Food_Asking else Food_A_Day > 0), Makers => N);
   end Food_Demand;

   --  The table: every row asked, as things stand.
   type Demand_List is array (1 .. Max_Demand_Rows) of Demand_Row;
   procedure Build_Rows (R : out Demand_List; N : out Natural) is
      procedure Add (Row : Demand_Row) is
      begin
         if Row.Amount > 0 and then N < Max_Demand_Rows then
            N := N + 1;
            R (N) := Row;
         end if;
      end Add;
   begin
      N := 0;
      R := [others => <>];
      Add ((Who => The_People, Kind => By_The_Day, Food => True, Amount => Food_A_Day, others => <>));
      if Camp_Set then
         Add ((Who => A_Zone, Zone => Camp_Zone, Kind => By_The_Day, What => Wood, Amount => Fire_Day_Logs, others => <>));
         Add ((Who => A_Zone, Zone => Camp_Zone, Kind => Once, What => Wood,
               Amount => (if Seats_Laid < Seat_Logs then Seat_Logs - Seats_Laid else 0) + Hearth_Short (Wood),
               others => <>));
         for K in Item_Kind loop           --  what its hearth is still to be built with
            if K /= Wood then
               Add ((Who => A_Zone, Zone => Camp_Zone, Kind => Once, What => K, Amount => Hearth_Short (K),
                     others => <>));
            end if;
         end loop;
      end if;
      if N_Houses > 0 then              --  what each housing zone's houses are still to be built with
         for Z in 1 .. N_Zones loop
            if Zones (Z).Kind = Habitation_Zone then
               for K in Item_Kind loop
                  Add ((Who => A_Zone, Zone => Z, Kind => Once, What => K, Amount => Zone_Short (Z, K), others => <>));
               end loop;
            end if;
         end loop;
      end if;
      for K in Item_Kind loop           --  wanted for a use: only the paths' stone, so far
         Add ((Who => The_Paths, Kind => Once, What => K, Amount => Demand (K), others => <>));
      end loop;
      Add ((Who => An_Order, By => The_Player, Kind => Surplus, Food => True, Amount => Food_Surplus, others => <>));
      for K in Item_Kind loop
         Add ((Who => An_Order, By => The_Player, Kind => Surplus, What => K, Amount => Reserves (K), others => <>));
      end loop;
   end Build_Rows;

   function Demand_Rows return Natural is
      R : Demand_List;
      N : Natural;
   begin
      Build_Rows (R, N);
      return N;
   end Demand_Rows;

   function Demand_Row_At (K : Positive) return Demand_Row is
      R : Demand_List;
      N : Natural;
   begin
      Build_Rows (R, N);
      return R (K);
   end Demand_Row_At;

   --  With nothing asked of it: about the camp (the stake, with no camp) till
   --  there is.  (Off: it stands where it is, as it did.)
   procedure Rest (I : Positive) is
      M : Member renames Band (I);
   begin
      if Chain_On then
         Stroll (I, (if Camp_Set then Camp_At else Stake_At));
      else
         M.Wait := 4.0;
         M.State := Idle;
      end if;
   end Rest;

   ------------------------------------------------------------------ housing: the builder

   --  What building may take of K from the stores: all that is free, but
   --  never the logs the camp's fire burns in a day, nor those its seats
   --  and its hearth still want.
   function Free_For_Building (K : Item_Kind) return Natural is
      Free : constant Natural := Free_Stock (K);
      Keep : constant Natural :=
        (if K = Wood and then Camp_Set
         then Fire_Day_Logs + (if Seats_Laid < Seat_Logs then Seat_Logs - Seats_Laid else 0) + Hearth_Short (Wood)
         else 0);
   begin
      return (if Free > Keep then Free - Keep else 0);
   end Free_For_Building;

   --  What house H next has to have carried to it (its timber is all laid
   --  before anything of straw: colony_check holds every blueprint to it).
   function Next_Kind (H : Positive) return Item_Kind is
     (if Houses (H).Placed < Houses (H).Wood_N then Wood else Straw);

   function House_At (K : Positive) return House_View is
      Hs   : House_Rec renames Houses (K);
      F    : CB.House renames Hs.F;
      Bd   : constant Natural := Builder_Of (K);
      Door : CB.Opening renames F.Openings (1);
      Next : constant Item_Kind := (if Hs.Built then Wood else Next_Kind (K));
      Bringing : constant Boolean :=
        Bd > 0 and then Band (Bd).Use_For = For_House and then Band (Bd).State in To_Take | Taking | To_Site | Idle;
   begin
      return
        (Zone => Hs.Zone, Owner => Hs.Owner, Builder => Bd,
         Phase => (if Hs.Built then Standing elsif not Hs.Pad_Done then Ground
                   elsif Hs.Placed < Hs.Floor_N then Flooring elsif Hs.Placed < Hs.Frame_N then Framing
                   elsif Hs.Placed < Hs.Walls_N then Walling else Roofing),
         Blocks => Hs.Total, Placed => Hs.Placed, Takes => Hs.Takes, Got => Hs.Got,
         Waits => (if Hs.Built then Not_Waiting
                   elsif Bd = 0 then For_A_Builder
                   elsif Failed (Band (Bd), Site_Fail + K) then For_A_Way
                   elsif Hs.Pad_Done and then Hs.Placed >= Hs.Floor_N and then Hs.Lying (Next) = 0 and then not Bringing
                     and then Free_For_Building (Next) = 0
                   then (if Next = Straw then For_Straw else For_Wood)
                   else Not_Waiting),
         Corner => [H_Point (F, -0.5, -0.5), H_Point (F, Float (F.W) - 0.5, -0.5),
                    H_Point (F, Float (F.W) - 0.5, Float (F.D) - 0.5), H_Point (F, -0.5, Float (F.D) - 0.5)],
         Door => H_Point (F, Float (Door.Offset) + Float (Door.Width) / 2.0 - 0.5, -2.5),
         Way => F.Door_Run, Rise => (if F.Door_Run > 0 then F.Pad - 1 - F.Door_Row else 0),
         Bed => Bed_Place (K),
         Top_Z => Float (F.Pad + F.Wall_H + (if F.Ridge_Along_U then (F.D + 1) / 2 else (F.W + 1) / 2)) * 0.25);
   end House_At;

   --  A builder at its house: a load for it carried there; its ground made
   --  ready; then its blueprint laid from what lies there, and more fetched
   --  from the stores when that runs out.  False: nothing of it for M to do
   --  now (no house wants a builder, or there is nothing to build with: it
   --  goes on as the forester it is).
   function Think_House (I : Positive) return Boolean is separate;

   --  A step of a builder's work (To_Site, Raising).
   procedure Step_House (I : Positive) is separate;

   --  Gathering, as a gatherer does (and a cook with nothing to cook).
   --  Asked_Only: only the kinds that are asked for (a gatherer's errand; a
   --  cook with nothing to cook goes for anything).
   procedure Think_Gather (I : Positive; Topping_Up : Boolean; Asked_Only : Boolean := False) is separate;

   --  The cook: the fire, then the pot, then the camp's comforts; with
   --  nothing to cook, out gathering.
   procedure Think_Cook (I : Positive; Topping_Up : Boolean) is separate;

   --  The band builds what the player has marked: with empty hands (or a
   --  load for the camp) M turns to it before its job.  The camp first: its
   --  ground, stone for the ring, wood for the crossbar, a seat log.  Then a
   --  metre of path.  False: nothing of it for M to do now.
   function Think_Build (I : Positive) return Boolean is separate;

   procedure Think (I : Positive) is separate;

   ------------------------------------------------------------------ one step

   --  It dies where it is: what it had set aside or claimed is let go, what
   --  it carried is lost with it (a deer it carried is put down), and the
   --  rest grieve.
   procedure Die (I : Positive) is separate;

   --  A step of eating and sleeping (To_Eat, Eating, To_Seat, To_Bed, Sleeping).
   procedure Step_Needs (I : Positive) is separate;
   --  A step of the cook at the camp: taking from the stockpile, the fire, the pot (To_Take, Taking, To_Camp, Putting_In, Cooking).
   procedure Step_Camp (I : Positive) is separate;
   --  A step of picking berries, and putting any load away (To_Bush, Picking, To_Store, Storing).
   procedure Step_Gather (I : Positive) is separate;
   --  A step of felling, and lifting logs (To_Tree, Chopping, To_Pile, Lifting).
   procedure Step_Wood (I : Positive) is separate;
   --  A step of straw, stone, vegetables, apples, sticks: going for them and getting them (To_Source, Gathering).
   procedure Step_Fetch (I : Positive) is separate;
   --  A step of the hunt, the kill and the butchering (Stalking, Aiming, Recovering, To_Carcass, Lifting_Carcass, To_Butcher, Butchering).
   procedure Step_Hunt (I : Positive) is separate;

   --  A step of making the camp's ground ready, or laying a metre of path (To_Patch, Tamping).
   procedure Step_Build (I : Positive) is separate;

   --  One member, one step: its needs tick, then the step of what it is at.
   procedure Step_Member (I : Positive) is separate;

   --  The fire burns down, and burnt out it dies down on its embers until
   --  it is out; nothing goes on it but what someone puts there.  (The
   --  camp's labour off, as it was: while it is wanted (cooking to do, or
   --  from an hour before bedtime through the night) it takes a log off its
   --  stack whenever it burns out, and there is no dying down.)
   procedure Tend_Fire is
      H : constant Float := Hour_Of_Day;
   begin
      if not Camp_Set then
         return;
      end if;
      if Fuel_H > 0.0 then
         Fuel_H := Float'Max (0.0, Fuel_H - Tick_S / 60.0);
         if Fuel_H <= 0.0 and then Labour_On then
            Ember_H := Die_Down_Hours;
         end if;
      elsif Ember_H > 0.0 then
         Ember_H := Float'Max (0.0, Ember_H - Tick_S / 60.0);
      end if;
      if not Labour_On and then Fuel_H <= 0.0 and then Fire_Logs > 0
        and then (Pot_Raw > 0 or else H >= Bed_Hour - 1.0 or else H < Wake_Hour or else Winter_Now)
      then
         Fire_Logs := Fire_Logs - 1;
         N_Burnt := N_Burnt + 1;
         Fuel_H := Instant_Log_Hours;
      end if;
   end Tend_Fire;

   --  The band's first cook chooses itself: once there is a camp and
   --  something to cook, and nobody has ever cooked, the best cook in it.
   procedure Choose_Cook is separate;

   procedure Advance (Seconds : Float; Hours : Long_Float) is separate;

   ------------------------------------------------------------------ needs: what is seen

   procedure Set_Needs (On : Boolean) is separate;

   function Needs return Boolean is (Needs_On);
   function Fed_Of (I : Positive) return Float is (Band (I).Fed);
   function Hungry (I : Positive) return Boolean is
     (Needs_On and then Band (I).Fed < Hungry_At and then not Band (I).Is_Dead);
   function Asleep (I : Positive) return Boolean is (Band (I).State = Sleeping and then not Band (I).Is_Dead);
   function Fending (I : Positive) return Boolean is (Band (I).Fends);
   function Cold (I : Positive) return Boolean is
     (Needs_On and then Winter_Now and then Band (I).State = Sleeping and then not Band (I).Is_Dead
      and then not (Camp_Set and then Fire_Warm and then Flat_Dist (Band (I).Pos, Camp_At) <= 6.0)
      and then not At_Home (I));                   --  (a roof keeps the cold off)
   function Grain_Carried (I : Positive) return Natural is (Band (I).Grain);
   function Mood_Of (I : Positive) return Float is (Band (I).Mood);
   function Dead (I : Positive) return Boolean is (Band (I).Is_Dead);
   function Deaths return Natural is (N_Deaths);

   function Living return Natural is
      N : Natural := 0;
   begin
      for I in 1 .. N_Members loop
         if not Band (I).Is_Dead then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Living;

   function Confidence return Float is
      Sum : Float := 0.0;
      N   : Natural := 0;
   begin
      for I in 1 .. N_Members loop
         if not Band (I).Is_Dead then
            Sum := Sum + Band (I).Mood;
            N := N + 1;
         end if;
      end loop;
      return (if N = 0 then 0.0 else Sum / Float (N));
   end Confidence;
   function Eaten return Natural is (N_Eaten);

   function Food_Days return Float is
      Cooks   : constant Boolean := Camp_Set and then Has_Cook;
      Points  : Float := Float (Pot_Stew + Pot_Raw);
      Per_Day : Float := 0.0;
   begin
      for K in 1 .. N_Cells loop
         Points := Points + Float (Cells (K).Count * (if Cooks then Stew_Food (Cells (K).Kind)
                                                       else Raw_Food (Cells (K).Kind)));
      end loop;
      for I in 1 .. N_Members loop
         if not Band (I).Is_Dead then
            Per_Day := Per_Day + Float (Day_Food) * Size_Of (Band (I));
         end if;
      end loop;
      return (if Per_Day > 0.0 then Points / Per_Day else 0.0);
   end Food_Days;

   ------------------------------------------------------------------ jobs

   procedure Set_Job (I : Positive; J : Job_Kind; By : Actor := The_Player) is
      M : Member renames Band (I);
   begin
      if M.Is_Dead then
         return;
      end if;
      M.Director := (if J = Unassigned then No_One else By);
      if M.Job = J then
         return;
      end if;
      M.Fends := False;
      M.Job := J;
      M.Site := 0;              --  (a house it was building wants another builder)
      M.Site_Patch := 0;
      M.Use_For := For_Store;   --  what it carries is for a stockpile now
      --  drop what it was doing (not what it carries: that goes to store;
      --  nor eating or sleeping, its own business)
      if M.State in To_Eat | Eating | To_Bed | Sleeping | To_Seat then
         return;
      end if;
      Release (M, I);
      if M.State = To_Store or else M.State = Storing then
         return;                                    --  finish putting it away
      end if;
      M.State := Idle;
      M.Wait := 0.0;
      M.Route.N := 0;
   end Set_Job;

   ------------------------------------------------------------------ the stake and the band

   procedure Place_Stake (Ground : Vec3; Band_Size : Positive; Seed : U64) is separate;

   ------------------------------------------------------------------ paths

   function Path_Count return Natural is (N_Paths);
   function Path_End (K : Positive; Second : Boolean) return Vec3 is
     (if Second then Path_List (K).B else Path_List (K).A);

   function Seg_Dist (P : Vec3; S : Path_Seg) return Float is
      Dx : constant Float := S.B.X - S.A.X;
      Dy : constant Float := S.B.Y - S.A.Y;
      L2 : constant Float := Dx * Dx + Dy * Dy;
      T  : constant Float :=
        (if L2 > 0.0 then Float'Max (0.0, Float'Min (1.0, ((P.X - S.A.X) * Dx + (P.Y - S.A.Y) * Dy) / L2)) else 0.0);
   begin
      return Flat_Dist (P, (S.A.X + Dx * T, S.A.Y + Dy * T, 0.0));
   end Seg_Dist;

   function Near_Path (X, Y, Within_M : Float) return Boolean is
   begin
      for K in 1 .. N_Paths loop
         if Seg_Dist ((X, Y, 0.0), Path_List (K)) <= Within_M + Path_Width_M / 2.0 then
            return True;
         end if;
      end loop;
      return False;
   end Near_Path;

   ------------------------------------------------------------------ zones: their ground

   function Zone_Count return Natural is (N_Zones);
   function Zone_Of_Cell (K : Positive) return Natural is (Cells (K).Zone);
   function Camp_Zone return Natural is (Camp_Zone_N);
   function Zones_Version return Natural is (Zones_Ver);
   function Zone_Runs (Z : Positive) return Natural is (Zones (Z).N);
   function Zone_Run_At (Z, K : Positive) return Zone_Run is
      R : Run_Rec renames Runs (Zones (Z).First + K);
   begin
      return (Y => Integer (R.Y), X0 => Integer (R.X0), X1 => Integer (R.X1), Z => Integer (R.Z));
   end Zone_Run_At;

   --  The one lookup of whose a block column is: the zone it is in (0:
   --  none) and the row of its ground's top there.  Every zoning, every
   --  path laid and everything shown of a zone asks this.
   procedure Zone_Of_Block (Bx, By : Integer; Zone : out Natural; Row : out Integer) is
   begin
      for Z in 1 .. N_Zones loop
         declare
            R : Zone_Rec renames Zones (Z);
         begin
            if R.N > 0 and then Bx in R.Bx0 .. R.Bx1 and then By in R.By0 .. R.By1 then
               for K in R.First + 1 .. R.First + R.N loop
                  if Integer (Runs (K).Y) = By and then Bx in Integer (Runs (K).X0) .. Integer (Runs (K).X1) then
                     Zone := Z;
                     Row := Integer (Runs (K).Z);
                     return;
                  end if;
               end loop;
            end if;
         end;
      end loop;
      Zone := 0;
      Row := -1;
   end Zone_Of_Block;

   function Zone_Of_Block (Bx, By : Integer) return Natural is
      Z : Natural;
      R : Integer;
   begin
      Zone_Of_Block (Bx, By, Z, R);
      return Z;
   end Zone_Of_Block;

   function Zone_On (X, Y : Float) return Natural is (Zone_Of_Block (B (X), B (Y)));

   --  A path's own ground: within its width, and no zone's (where a path
   --  brushes a zone the zone keeps its ground).
   function On_Path (X, Y : Float) return Boolean is (Near_Path (X, Y, 0.0) and then Zone_On (X, Y) = 0);

   function Zone_Top (X, Y : Float) return Float is
      Z : Natural;
      R : Integer;
   begin
      Zone_Of_Block (B (X), B (Y), Z, R);
      return (if Z = 0 then -1.0 else Float (R + 1) * 0.25);
   end Zone_Top;

   --  Zone Z's box, its size and how far it reaches along its own way and
   --  across it, from its ground.
   procedure Measure_Zone (Z : Positive) is separate;

   --  The ground of zones that came from a save from before zones had
   --  ground of their own (version 13 and older): a stockpile's is the
   --  square metre under each of its cells, the camp's its square, each at
   --  the level its cell or its fire was at.  They load as they were, on a
   --  path or not.
   procedure Ground_From_Cells is separate;

   ------------------------------------------------------------------ paths: laying one

   type Path_Refused is (Laid_Some, Nothing_There, Through_Zone, No_More);
   Path_Refused_For : Path_Refused := Laid_Some;

   function Path_Refusal return String is
     (case Path_Refused_For is
         when Laid_Some     => "",
         when Nothing_There => "there is no ground there to lay a path on",
         when Through_Zone  => "a zone is in the way: paths go round zones",
         when No_More       => "there are as many paths as there can be");

   procedure Lay_Path (From, To : Vec3; Laid : out Natural) is separate;

   ------------------------------------------------------------------ zones: laying out a lot

   --  A lot as planned: the ground it would fill and, for a stockpile, the
   --  places it would get.  Worked out by Plan_Lot, with nothing changed;
   --  a zoning takes the plan it has just made.
   type Lot_Refusal is (Lot_Ok, Off_Path, No_Ground, Too_Large, No_Room);
   type Plan_Runs_Array is array (1 .. Max_Plan_Runs) of Run_Rec;
   type Plan_Cells_Array is array (1 .. Max_Cells) of Vec3;
   Plan_Run     : Plan_Runs_Array;
   Plan_N       : Natural := 0;
   Plan_Blocks  : Natural := 0;
   Plan_Cell    : Plan_Cells_Array;
   Plan_Cells_N : Natural := 0;
   type Plan_Blocks_Array is array (1 .. 24 * Max_Cells) of Block_Pos;
   Plan_Under   : Plan_Blocks_Array;      --  the ground under those places, block by block
   Plan_Under_N : Natural := 0;
   Plan_At_Path : Boolean := False;       --  its ground comes right up to a path somewhere
   Plan_Turn    : Float := 0.0;
   Plan_Corner  : Lot_Corners := [others => (0.0, 0.0, 0.0)];
   Plan_Refused : Lot_Refusal := Lot_Ok;

   --  (what Plan_Lot works on: each block column of the lot, and the fill's queue)
   type Plan_Grid is array (0 .. Max_Plan_B - 1, 0 .. Max_Plan_B - 1) of Integer_16;
   type Plan_Grid_Access is access Plan_Grid;
   Plan_G : constant Plan_Grid_Access := new Plan_Grid;
   type Plan_Spot is record
      X, Y : Integer_16;
   end record;
   type Plan_Spots is array (1 .. Max_Plan_B * Max_Plan_B) of Plan_Spot;
   type Plan_Spots_Access is access Plan_Spots;
   Plan_Q : constant Plan_Spots_Access := new Plan_Spots;

   function Planned_Runs return Natural is (Plan_N);
   function Planned_Run_At (K : Positive) return Zone_Run is
     ((Y => Integer (Plan_Run (K).Y), X0 => Integer (Plan_Run (K).X0), X1 => Integer (Plan_Run (K).X1),
       Z => Integer (Plan_Run (K).Z)));

   function Stockpile_Refusal return String is
     (case Plan_Refused is
         when Lot_Ok    => "",
         when Off_Path  => "a stockpile has to come within a metre of a path",
         when No_Ground => "there is no clear ground there to put things on",
         when Too_Large => "it is too large (" & Integer'Image (Integer (Max_Lot_M)) & " m a side at most)",
         when No_Room   => "there is no room for another");

   --  The way the path nearest the line from A to C runs, as a unit vector
   --  within 45 degrees of east (a lot lies along its path, and which end
   --  is which does not matter); east itself with no path.  Dist: how far
   --  off that path's middle is (Float'Last with none).
   procedure Way_Of_Path (A, C : Vec3; Ex, Ey : out Float; Dist : out Float) is separate;

   --  The ground of a lot: the rectangle Ra0 .. Ra1 by Rb0 .. Rb1 along and
   --  across the way (Ex, Ey), drawn out to any path within Snap_M of a
   --  side, filled from the free block nearest Seed without crossing a
   --  path, a zone, a ledge higher than Step_B blocks or anything standing.
   --  With Places, a stockpile's: places 1 m square on the whole numbers
   --  Ia0 .. Ia1 by Ib0 .. Ib1 of that rectangle, each wholly on the filled
   --  ground and within half a metre of level.  Into the plan.
   procedure Plan_Lot
     (Ex, Ey             : Float;
      Ra0, Ra1, Rb0, Rb1 : Float;
      Seed               : Vec3;
      Step_B             : Natural;
      Places             : Boolean;
      Ia0, Ia1, Ib0, Ib1 : Integer := 0) is separate;

   --  The camp's zone has a place kept for it: stockpiles take all but one.
   function Zone_Room return Boolean is (N_Zones < Max_Zones - (if Camp_Set then 0 else 1));

   --  The plan for a stockpile between two corners (X0, Y0: where it was begun).
   procedure Plan_Stockpile_Lot (X0, Y0, X1, Y1 : Float) is separate;

   function Plan_View return Lot_Plan is
     ((Ok => Plan_Refused = Lot_Ok, Corner => Plan_Corner, Turn => Plan_Turn, Cells => Plan_Cells_N,
       Blocks => Plan_Blocks));

   function Plan_Stockpile (X0, Y0, X1, Y1 : Float) return Lot_Plan is
   begin
      Plan_Stockpile_Lot (X0, Y0, X1, Y1);
      return Plan_View;
   end Plan_Stockpile;

   --  Zone Z takes the planned ground for its own.
   procedure Take_Plan (Z : Positive) is
   begin
      Zones (Z).First := N_Runs;
      Zones (Z).N := Plan_N;
      Zones (Z).Turn := Plan_Turn;
      for K in 1 .. Plan_N loop
         Runs (N_Runs + K) := Plan_Run (K);
      end loop;
      N_Runs := N_Runs + Plan_N;
      Measure_Zone (Z);
      Zones_Ver := Zones_Ver + 1;
   end Take_Plan;

   --  Whatever grows on the planned ground is cut (grass, grain, wild
   --  vegetables: nothing else can be on it).
   procedure Clear_Plan is
   begin
      for K in 1 .. Plan_N loop
         for X in Integer (Plan_Run (K).X0) .. Integer (Plan_Run (K).X1) loop
            if Mat (X, Integer (Plan_Run (K).Y), Integer (Plan_Run (K).Z) + 1) /= Air then
               Write_Src (X, Integer (Plan_Run (K).Y), Integer (Plan_Run (K).Z) + 1, Air_Block);
            end if;
         end loop;
      end loop;
   end Clear_Plan;

   --  What grows on the planned places is cut, so what is put there can be
   --  seen; the rest of a stockpile's ground keeps its grass.
   procedure Clear_Places is
   begin
      for K in 1 .. Plan_Under_N loop
         declare
            P : Block_Pos renames Plan_Under (K);
         begin
            if Mat (Integer (P.X), Integer (P.Y), Integer (P.Z) + 1) /= Air then
               Write_Src (Integer (P.X), Integer (P.Y), Integer (P.Z) + 1, Air_Block);
            end if;
         end;
      end loop;
   end Clear_Places;

   ------------------------------------------------------------------ stockpiles

   --  A new stockpile zone for cells From .. N_Cells: they are its own, and
   --  its ground is the plan's.
   procedure New_Stockpile_Zone (From : Positive) is separate;

   --  A new zone for the camp, its ground still to be given.
   procedure New_Camp_Zone is
   begin
      N_Zones := N_Zones + 1;
      Zones (N_Zones) := (Kind => Camp_Zone, others => <>);
      Camp_Zone_N := N_Zones;
   end New_Camp_Zone;

   --  For a save from before zones: a stockpile zone for every group of
   --  cells that touch side to side (nobody knows any more how they were
   --  zoned), in the order of each group's first cell; then the camp's.
   procedure Zones_From_Cells is separate;

   procedure Zone_Stockpile (X0, Y0, X1, Y1 : Float; Cells : out Natural) is separate;

   ------------------------------------------------------------------ the camp: zoning

   type Refusal is (Taken_None, Already, No_Stake_Yet, Too_Steep, In_The_Way, Over_Stockpile, Path_Near,
                    No_Free_Ground, Out_Of_Room);
   Refused_For : Refusal := Taken_None;
   In_Way_At   : Vec3 := (0.0, 0.0, 0.0);
   Fall_Cm     : Natural := 0;            --  how far the ground fell or rose from the middle

   function Camp_Refusal return String is
     (case Refused_For is
         when Taken_None     => "",
         when Already        => "there is a camp already",
         when No_Stake_Yet   => "raise the homestake first",
         when Too_Steep      => "the ground is not level enough (it is" & Natural'Image (Fall_Cm)
                                & " cm off the middle's; a metre at most)",
         when In_The_Way     => "something stands in the way (a tree, a bush, a stone, water) at"
                                & Integer'Image (Integer (In_Way_At.X)) & "," & Integer'Image (Integer (In_Way_At.Y)),
         when Over_Stockpile => "a stockpile is in the way",
         when Path_Near      => "a path runs too near the fire (keep it" & Integer'Image (Integer (Camp_Clear_M))
                                & " m off)",
         when No_Free_Ground => "there is no free ground there for it",
         when Out_Of_Room    => "there is no room for another zone");

   --  The plan for the camp with its fire at Centre: whether it would be
   --  taken (Refused_For), and its ground.  Nothing is changed.  The fire's
   --  block corner and the row of the ground there come back with it.
   procedure Plan_Camp_Lot (Centre : Vec3; Cx, Cy, Zc : out Integer) is separate;

   function Plan_Camp (Centre : Vec3) return Lot_Plan is
      Cx, Cy, Zc : Integer;
      V : Lot_Plan;
   begin
      Plan_Camp_Lot (Centre, Cx, Cy, Zc);
      V := Plan_View;
      V.Ok := Refused_For = Taken_None;
      return V;
   end Plan_Camp;

   procedure Zone_Camp (Centre : Vec3; Ok : out Boolean) is separate;

   function Stored (K : Item_Kind) return Natural is
      N : Natural := 0;
   begin
      for C in 1 .. N_Cells loop
         if Cells (C).Kind = K then
            N := N + Cells (C).Count;
         end if;
      end loop;
      return N;
   end Stored;

   procedure Supply (K : Item_Kind; N : Natural; Placed : out Natural) is separate;

   function Cell_Count return Natural is (N_Cells);
   function Cell_At (K : Positive) return Cell_View is
     ((Cells (K).Centre, Cells (K).Kind, Cells (K).Count, Cells (K).Turn));

   ------------------------------------------------------------------ housing: zoning

   Housing_No_Hovel : Boolean := False;    --  the last lot planned for housing would hold not one hovel
   Housing_Too_Far  : Boolean := False;    --  or reaches further from the stake than ground can be kept in
   Plan_Hovels      : Natural := 0;        --  how many it would hold

   --  How far from the stake a box of block columns reaches, and a margin
   --  for the banks and the door paths of what is built at its edge.
   function Far_Of (Bx0, By0, Bx1, By1 : Integer) return Float is
      D : Float := 0.0;
   begin
      for X of Integer_Pair'(Bx0, Bx1 + 1) loop
         for Y of Integer_Pair'(By0, By1 + 1) loop
            D := Float'Max (D, Flat_Dist ((Float (X) * 0.25, Float (Y) * 0.25, 0.0), Stake_At));
         end loop;
      end loop;
      return D + 4.0;
   end Far_Of;

   --  The colony's ground reaches as far as its housing does.
   procedure Count_Housing is
   begin
      N_Housing := 0;
      Housing_Far := 0.0;
      for Z in 1 .. N_Zones loop
         if Zones (Z).Kind = Habitation_Zone then
            N_Housing := N_Housing + 1;
            if Zones (Z).N > 0 then
               Housing_Far := Float'Max (Housing_Far, Far_Of (Zones (Z).Bx0, Zones (Z).By0, Zones (Z).Bx1, Zones (Z).By1));
            end if;
         end if;
      end loop;
   end Count_Housing;

   --  How many hovels the planned ground would hold, as things stand: each
   --  placed as the band would place it, one after another.
   function Planned_Hovels return Natural is
      Bx0, By0 : Integer := Integer'Last;
      Bx1, By1 : Integer := Integer'First;
      F   : CB.House;
      Key : Float;
      Ok  : Boolean;
      N   : Natural := 0;
   begin
      if Plan_N = 0 then
         return 0;
      end if;
      for K in 1 .. Plan_N loop
         Bx0 := Integer'Min (Bx0, Integer (Plan_Run (K).X0));
         Bx1 := Integer'Max (Bx1, Integer (Plan_Run (K).X1));
         By0 := Integer'Min (By0, Integer (Plan_Run (K).Y));
         By1 := Integer'Max (By1, Integer (Plan_Run (K).Y));
      end loop;
      Housing_Too_Far := Far_Of (Bx0, By0, Bx1, By1) > Far_Reach_Max_M;
      if Housing_Too_Far then
         return 0;
      end if;
      Lot_Open (Bx0, By0, Bx1, By1);
      for K in 1 .. Plan_N loop
         Lot_Run (Plan_Run (K));
      end loop;
      for H in 1 .. N_Houses loop
         Lot_Take (Houses (H).F);
      end loop;
      while N_Houses + N < Max_Houses loop
         Place_House (House_Serial + N + 1, F, Key, Ok);
         exit when not Ok;
         Lot_Take (F);
         N := N + 1;
      end loop;
      return N;
   end Planned_Hovels;

   --  The plan for a housing zone between two corners (X0, Y0: where it was begun).
   procedure Plan_Housing_Lot (X0, Y0, X1, Y1 : Float) is
      Ex, Ey, Gap : Float;
   begin
      Housing_No_Hovel := False;
      Housing_Too_Far := False;
      Plan_Hovels := 0;
      Way_Of_Path ((X0, Y0, 0.0), (X1, Y1, 0.0), Ex, Ey, Gap);
      declare
         A0 : constant Float := X0 * Ex + Y0 * Ey;
         A1 : constant Float := X1 * Ex + Y1 * Ey;
         B0 : constant Float := Y0 * Ex - X0 * Ey;
         B1 : constant Float := Y1 * Ex - X1 * Ey;
      begin
         Plan_Lot (Ex, Ey, Float'Floor (Float'Min (A0, A1)), Float'Ceiling (Float'Max (A0, A1)),
                   Float'Floor (Float'Min (B0, B1)), Float'Ceiling (Float'Max (B0, B1)),
                   Seed => (X0, Y0, 0.0), Step_B => Integer (Zone_Step_M * 4.0), Places => False);
         if Plan_Refused = Too_Large then
            return;
         end if;
         --  it has to come within a metre of a path (and is then drawn out to it)
         if not Plan_At_Path then
            Plan_Refused := Off_Path;
         elsif Plan_Refused = Lot_Ok and then not Zone_Room then
            Plan_Refused := No_Room;
         end if;
         if Plan_Refused = Lot_Ok then
            Plan_Hovels := Planned_Hovels;
            Housing_No_Hovel := Plan_Hovels = 0;
         end if;
         if Plan_Refused /= Lot_Ok or else Housing_No_Hovel then   --  nothing to show of a lot that is refused
            Plan_N := 0;
            Plan_Blocks := 0;
         end if;
      end;
   end Plan_Housing_Lot;

   function Housing_Refusal return String is
     (if Housing_Too_Far
      then "it is too far from the homestake (the band's ground reaches" & Integer'Image (Integer (Far_Reach_Max_M))
           & " m at most)"
      elsif Housing_No_Hovel
      then "there is no room there for a hovel (it takes" & Integer'Image (Integer (Lot_M)) & " m along a path and"
           & Integer'Image (Integer (Lot_M)) & " m back from it)"
      else (case Plan_Refused is
               when Lot_Ok    => "",
               when Off_Path  => "housing has to come within a metre of a path",
               when No_Ground => "there is no clear ground there to build on",
               when Too_Large => "it is too large (" & Integer'Image (Integer (Max_Lot_M)) & " m a side at most)",
               when No_Room   => "there is no room for another zone"));

   function Plan_Housing (X0, Y0, X1, Y1 : Float) return Lot_Plan is
      V : Lot_Plan;
   begin
      Plan_Housing_Lot (X0, Y0, X1, Y1);
      V := Plan_View;
      V.Ok := Plan_Refused = Lot_Ok and then not Housing_No_Hovel;
      V.Cells := Plan_Hovels;
      return V;
   end Plan_Housing;

   procedure Zone_Housing (X0, Y0, X1, Y1 : Float; Lots : out Natural) is
   begin
      Lots := 0;
      Plan_Housing_Lot (X0, Y0, X1, Y1);
      if Plan_Refused /= Lot_Ok or else Housing_No_Hovel then
         return;
      end if;
      N_Zones := N_Zones + 1;
      Zones (N_Zones) := (Kind => Habitation_Zone, others => <>);
      Take_Plan (N_Zones);
      Count_Housing;
      Lots_Full := False;
      Lots := Plan_Hovels;
   end Zone_Housing;

   ------------------------------------------------------------------ zones

   function Zone_At (Z : Positive) return Zone_View is separate;

   ------------------------------------------------------------------ a person, as data

   function Person (I : Positive) return Person_View is
      M : Member renames Band (I);
   begin
      return (Job => M.Job, Director => M.Director, Doing => Doing (I), Child => M.Child, Elder => M.Elder,
              Fed => Float'Max (0.0, Float'Min (1.0, M.Fed)), Mood => M.Mood,
              Hungry => Hungry (I), Starving => Needs_On and then M.Fed <= 0.0 and then not M.Is_Dead,
              Asleep => Asleep (I), Fending => M.Fends, Cold => Cold (I), Dead => M.Is_Dead,
              Carrying => M.Carry, Carried => M.Carried, Grain => M.Grain,
              Zone => (if M.Is_Dead then 0 else Zone_On (M.Pos.X, M.Pos.Y)),
              Level => [for S in Skill_Kind => Float (M.Skill (S))], Aptitude => M.Apt,
              Work => Work_Of (I),
              Resting => not M.Is_Dead and then M.Job /= Unassigned and then M.State in Idle | Strolling
                         and then M.Why in Enough_Wood | Enough_Meat | Enough_Food | Stocks_Full,
              Trade => Trade_Of (I), Site => Site_Of (I), Home => Home_Of (I), Housed => Housed (I));
   end Person;

   ------------------------------------------------------------------ saves

   Save_Version : constant := 19;   --  19: housing: the houses, and the house each builder is at (18 was its
                                    --  first layout, on the stage's branch only: refused)
   --  17: nothing of the colony's own: the herds' blob is its version 2
   --  (whether the herds scatter as they were, each deer's start)
   --  16: extra tasks' hands and stretches; the camp's floor levelled; earth
   --  14: each zone's ground (the way its lot lies, its strips of block columns), what is built on it, the
   --  camp's labour, the fire's dying down, each member's patch of the camp's ground
   --  13: the demand chain (the switch, and whether each good is being asked for)
   --  12: skills (the switch, how many skills, each member's level in each)
   --  11: zones (each one's kind and borders, the zone of each stockpile cell) and each member's director
   --  10: the winter store order; 9: grain (what is wanted and kept of it, the grain each carries)
   --  2: trees, log piles, standing orders; 3: porters' fetching; 4: piles'
   --  owners, what is wanted; 5: the herds (Castle.Herds' own blob); 6:
   --  hunting (prey, carcasses, the meat reserve, spare deer); 7: needs
   --  (the switch, food eaten, each one's belly and the meal it is after);
   --  8: the camp and the cook (the fire, the pot, the seats, what went into
   --  the pot and what was eaten raw, each one's bowl and place at the fire)
   V3_Kinds : constant array (1 .. 3) of Item_Kind := [Water, Straw, Stone];   --  version 3's reserves
   subtype V4_Kinds is Item_Kind range Nothing .. Carcass;                     --  the kinds there were by 4
   subtype V8_Kinds is Item_Kind range Vegetables .. Sticks;                   --  those 8 added
   subtype To_V8_Kinds is Item_Kind range Nothing .. Sticks;
   subtype V9_Kinds is Item_Kind range Grain .. Grain;                         --  and 9
   subtype V16_Kinds is Item_Kind range Earth .. Item_Kind'Last;               --  and 16 (the next kind closes this range)

   function F32_Bits is new Ada.Unchecked_Conversion (Float, Unsigned_32);
   function Bits_F32 is new Ada.Unchecked_Conversion (Unsigned_32, Float);
   function F64_Bits is new Ada.Unchecked_Conversion (Long_Float, Unsigned_64);
   function Bits_F64 is new Ada.Unchecked_Conversion (Unsigned_64, Long_Float);

   type Bytes_Access is access Bytes;
   procedure Free is new Ada.Unchecked_Deallocation (Bytes, Bytes_Access);

   function Save return Bytes is separate;

   procedure Reset is separate;

   Bad_Save : exception;

   procedure Load (B : Bytes; Ok : out Boolean) is separate;

end Castle.Colony;
