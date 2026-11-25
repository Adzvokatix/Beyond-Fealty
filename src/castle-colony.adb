with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Ada.Unchecked_Conversion;
with Ada.Unchecked_Deallocation;
with Ada.Containers.Hashed_Maps;
with Ada.Containers.Generic_Array_Sort;
with Castle.Blocks; use Castle.Blocks;
with Castle.Climate;
with Castle.Dims;   use Castle.Dims;
with Castle.Herds;

package body Castle.Colony is

   use type Castle.Buildings.Building_Kind;

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
   type Vec3_Pair is array (1 .. 2) of Vec3;

   ------------------------------------------------------------------ state

   Tick_N    : Natural := 0;
   Left_Over : Float := 0.0;
   Now_Hours : Long_Float := 0.0;

   Stake_Set : Boolean := False;
   Stake_At  : Vec3 := (0.0, 0.0, 0.0);

   Own_R : Natural := Natural'Last;   --  the colony's own ground, in stacks round the stake's (Set_Ground_Stacks)

   procedure Set_Ground_Stacks (N : Natural) is
   begin
      Own_R := N;
   end Set_Ground_Stacks;

   function Ground_Stacks return Natural is (Own_R);

   --  Stack (CX, CY) is of the colony's own ground (the spec, Set_Ground_Stacks).
   function On_Own (CX, CY : Integer) return Boolean is
     (Own_R = Natural'Last or else not Stake_Set
      or else (abs (CX - Integer (Float'Floor (Stake_At.X / 8.0))) <= Own_R
               and then abs (CY - Integer (Float'Floor (Stake_At.Y / 8.0))) <= Own_R
               and then (CX - Integer (Float'Floor (Stake_At.X / 8.0))) ** 2
                        + (CY - Integer (Float'Floor (Stake_At.Y / 8.0))) ** 2 <= Own_R ** 2));

   --  The ground version of a stack as the band may know it: nothing of
   --  what is not its own ground.  (The one way the band's own doing asks
   --  whether a stack is in.  What the player plans is read from the ground
   --  that is held, Version_Src itself: three places, each says so.)
   function Own_V (CX, CY : Integer) return Natural is (if On_Own (CX, CY) then Version_Src (CX, CY) else 0);

   --  Where the colony's routes may go: its own ground.
   function Own_Region return Castle.Nav.Region is
     (if Own_R = Natural'Last or else Own_R = 0 or else not Stake_Set then Castle.Nav.Everywhere
      else Castle.Nav.Within_Stacks (Integer (Float'Floor (Stake_At.X / 8.0)), Integer (Float'Floor (Stake_At.Y / 8.0)),
                                     Own_R));
   Band_Seed : U64 := 1;

   --  The lord's cart, salt, and meat by the pound (the spec, "The lord's
   --  cart"; off: the band as it was before any of it).
   Curing_On   : Boolean := True;
   Cart_Set    : Boolean := False;            --  it stands
   Cart_Tried  : Boolean := False;            --  a place has been looked for (once, at the first step with a stake)
   Cart_P      : Vec3 := (0.0, 0.0, 0.0);     --  the middle of it, on its ground
   Cart_X      : Boolean := True;             --  it lies along X
   Cart_Salt_N : Natural := Cart_Salt_Lb;     --  pounds of salt in it
   --  Pulled into a stockpile (John, 2026-11-13: "the cart, can they pull
   --  it into the closest stockpile zone?"; the spec, "The lord's cart").
   --  The cart is in one place at every moment: standing (Cart_Set: its bed
   --  in the world) or in tow (Cart_Towed: no bed, drawn behind its puller).
   Pull_On     : Boolean := True;             --  the band pulls it into a stockpile (off: it stays where it stood)
   Builders_Cap : Natural := Most_Builders;   --  at most this many builders at once (0: no limit)
   Least_M      : Float := 0.0;               --  a stockpile's ground at least this along and across (0: any)
   Overflow_On  : Boolean := False;           --  a stockpile gets overflow places, and nobody sets out with no room
   Last_N       : Natural := Last_Places;     --  the stores' last empty places kept for loads in hand (Set_Last_Places)
   Store_On     : Boolean := True;            --  the storehouse asked for on the second morning
   Stake_Day    : Integer := -1;              --  the day the stake was raised on (-1: not yet seen)
   Store_House  : Natural := 0;               --  the storehouse's house (0: none begun)
   Store_Asked  : Boolean := False;           --  the second morning has come: the request is made
   Store_Note_N : Natural := 0;               --  (moves when what the advisor would say does; not saved)
   Cart_Turn   : Float := 0.0;                --  the way its shafts point (radians; standing, a quarter of a turn's)
   Cart_Towed  : Boolean := False;            --  in tow
   Cart_By     : Natural := 0;                --  who pulls it, or is going to take up its shafts
   Cart_Bound  : Boolean := False;            --  a place in a stockpile is held for it
   Goal_P      : Vec3 := (0.0, 0.0, 0.0);     --  where it is to stand there, the middle of its bed on its ground,
   Goal_Turn   : Float := 0.0;                --  and the way its shafts are to point
   Cart_From   : Vec3 := (0.0, 0.0, 0.0);     --  where it was lifted from (where it goes back to, with nowhere else)
   N_Salted, N_Unsalted, N_Meat_Lost : Natural := 0;

   function Carry_Limit (K : Item_Kind) return Natural is
     (if K = Meat and then Curing_On then Meat_Load_Lb else Carry_Table (K));
   function Cell_Limit (K : Item_Kind) return Natural is
     (if K = Meat and then Curing_On then Meat_Cell_Lb else Cell_Table (K));
   function Stew_Food (K : Item_Kind) return Natural is
     (if K = Meat and then Curing_On then Pound_Stew else Stew_Table (K));
   function Curing return Boolean is (Curing_On);
   procedure Set_Curing (On : Boolean) is
   begin
      Curing_On := On;
   end Set_Curing;
   function Salt_For (Lb : Natural) return Natural is ((Lb + Lb_Per_Salt - 1) / Lb_Per_Salt);
   function Kept_Of (Lb, Salt_Lb : Natural) return Natural is
      Salted : constant Natural := Natural'Min (Lb, Salt_Lb * Lb_Per_Salt);
   begin
      return Salted + (Lb - Salted) / Fresh_Div;
   end Kept_Of;
   function Deer_Salted return Natural is (N_Salted);
   function Deer_Unsalted return Natural is (N_Unsalted);
   function Meat_Lost return Natural is (N_Meat_Lost);
   procedure Set_Cart_Salt (Lb : Natural) is
   begin
      Cart_Salt_N := Lb;
   end Set_Cart_Salt;
   function Cart return Cart_View is
     ((Here => Cart_Set or else Cart_Towed, At_P => Cart_P, Along_X => Cart_X,
       Salt => (if Cart_Set or else Cart_Towed then Cart_Salt_N else 0),
       Turn => Cart_Turn, Towed => Cart_Towed, By => (if Cart_Towed then Cart_By else 0)));
   procedure Set_Cart_Pull (On : Boolean) is
   begin
      Pull_On := On;
   end Set_Cart_Pull;
   function Cart_Pull return Boolean is (Pull_On);
   procedure Set_Builders (N : Natural) is
   begin
      Builders_Cap := N;
   end Set_Builders;
   function Builders_Most return Natural is (Builders_Cap);
   procedure Set_Stockpile_Least (Metres : Float) is
   begin
      Least_M := Float'Max (0.0, Metres);
   end Set_Stockpile_Least;
   function Stockpile_Least return Float is (Least_M);
   procedure Set_Overflow (On : Boolean) is
   begin
      Overflow_On := On;
   end Set_Overflow;
   function Overflow return Boolean is (Overflow_On);
   One_Pile_On : Boolean := False;   --  the player places one stockpile, Stockpile_Side_M square (Set_One_Stockpile)
   procedure Set_One_Stockpile (On : Boolean) is
   begin
      One_Pile_On := On;
   end Set_One_Stockpile;
   function One_Stockpile return Boolean is (One_Pile_On);
   Box_On : Boolean := True;         --  the player's stockpile is put down whole, with its path (Set_Box_Place)
   procedure Set_Box_Place (On : Boolean) is
   begin
      Box_On := On;
   end Set_Box_Place;
   function Box_Place return Boolean is (Box_On);
   Yard_Box_On : Boolean := True;    --  the player's stockyard is put down whole, twenty metres (Set_Yard_Box)
   procedure Set_Yard_Box (On : Boolean) is
   begin
      Yard_Box_On := On;
   end Set_Yard_Box;
   function Yard_Box return Boolean is (Yard_Box_On);
   --  (the storehouse begun from now on: its walls and its staging, in blocks: Set_Store_Size)
   Store_W_On     : Positive := Castle.Buildings.Store_W_New_B;
   Store_D_On     : Positive := Castle.Buildings.Store_D_New_B;
   Store_Stage_On : Positive := Castle.Buildings.Store_Yard_New_B;
   procedure Set_Store_Size (Long_B, Deep_B, Staging_B : Positive) is
   begin
      Store_W_On := Long_B;
      Store_D_On := Deep_B;
      Store_Stage_On := Staging_B;
   end Set_Store_Size;
   function Store_Long_B return Positive is (Store_W_On);
   function Store_Deep_B return Positive is (Store_D_On);
   function Store_Staging_B return Positive is (Store_Stage_On);
   Cart_Search_On : Boolean := True;  --  the cart's place before the storehouse is looked for (Set_Cart_Search)
   procedure Set_Cart_Search (On : Boolean) is
   begin
      Cart_Search_On := On;
   end Set_Cart_Search;
   function Cart_Search return Boolean is (Cart_Search_On);
   Yard_Corner_On : Boolean := True;  --  a stockyard's stair stands in a corner of the zone (Set_Yard_Stair_Corner)
   procedure Set_Yard_Stair_Corner (On : Boolean) is
   begin
      Yard_Corner_On := On;
   end Set_Yard_Stair_Corner;
   function Yard_Stair_Corner return Boolean is (Yard_Corner_On);
   Yard_Low_On : Boolean := True;     --  a stockyard's floor at its path's level at the lower corner of its front
   procedure Set_Yard_Floor_Low (On : Boolean) is     --  (Floor_By_Path; only with its stair in a corner)
   begin
      Yard_Low_On := On;
   end Set_Yard_Floor_Low;
   function Yard_Floor_Low return Boolean is (Yard_Low_On);
   Stacks_On : Boolean := True;       --  food and full barrels stacked in the storehouse (Set_Store_Stacks)
   procedure Set_Store_Stacks (On : Boolean) is
   begin
      Stacks_On := On;
   end Set_Store_Stacks;
   function Store_Stacks return Boolean is (Stacks_On);
   Flat_On : Boolean := False;       --  a stockpile is one level (Set_Pile_Flat; its rule is with Level_Places, below)
   Steep_On : Boolean := True;       --  a stockpile is refused on ground too steep (Set_Steep_Refuse; Plan_Lot, Steep_B)
   Box_Fell_On : Boolean := True;    --  the trees that stand in a stockpile put down whole are felled and taken out,
                                     --  and the places under them are its own (Set_Box_Fell; off: a tree leaves
                                     --  places out, as before 2026-11-20's evening)
   procedure Set_Box_Fell (On : Boolean) is
   begin
      Box_Fell_On := On;
   end Set_Box_Fell;
   function Box_Fell return Boolean is (Box_Fell_On);
   Square_Fell_On : Boolean := True; --  the trees that stand on the square a colony is founded on are felled and
                                     --  taken out by the band as it is made (Set_Square_Fell; off: left standing)
   procedure Set_Square_Fell (On : Boolean) is
   begin
      Square_Fell_On := On;
   end Set_Square_Fell;
   function Square_Fell return Boolean is (Square_Fell_On);
   Fire_Ground_On : Boolean := True; --  a square is founded on the ground its plan read under whatever stands
                                     --  over its middle (Set_Fire_Ground; off: the ground looked for near the
                                     --  height of the highest floor there, as it was)
   procedure Set_Fire_Ground (On : Boolean) is
   begin
      Fire_Ground_On := On;
   end Set_Fire_Ground;
   function Fire_Ground return Boolean is (Fire_Ground_On);
   procedure Set_Last_Places (N : Natural) is
   begin
      Last_N := N;
   end Set_Last_Places;
   function Last_Places_Kept return Natural is (Last_N);
   --  whether the band keeps from setting out with no room for what it would bring (the overflow's
   --  rule, and the last places')
   function Room_Gated return Boolean is (Overflow_On or else Last_N > 0);
   procedure Set_Storehouse (On : Boolean) is
   begin
      Store_On := On;
   end Set_Storehouse;
   function Storehouse_On return Boolean is (Store_On);
   function Storehouse return Natural is (Store_House);
   --  (a bed's block columns, its middle at P: Cart_Long_B along its way, Cart_Wide_B across)
   function Bed_X0 (P : Vec3; Along_X : Boolean) return Integer is
     (Integer (Float'Floor (P.X * 4.0)) - (if Along_X then Cart_Long_B else Cart_Wide_B) / 2);
   function Bed_Y0 (P : Vec3; Along_X : Boolean) return Integer is
     (Integer (Float'Floor (P.Y * 4.0)) - (if Along_X then Cart_Wide_B else Cart_Long_B) / 2);
   function Bed_On_Block (P : Vec3; Along_X : Boolean; Bx, By : Integer; Margin : Natural := 0) return Boolean is
     (Bx in Bed_X0 (P, Along_X) - Margin .. Bed_X0 (P, Along_X) + (if Along_X then Cart_Long_B else Cart_Wide_B) - 1 + Margin
      and then By in Bed_Y0 (P, Along_X) - Margin
                  .. Bed_Y0 (P, Along_X) + (if Along_X then Cart_Wide_B else Cart_Long_B) - 1 + Margin);
   function Turn_Along_X (T : Float) return Boolean is (abs Cos (T) > 0.5);
   function Cart_X0 return Integer is (Bed_X0 (Cart_P, Cart_X));
   function Cart_Y0 return Integer is (Bed_Y0 (Cart_P, Cart_X));
   function Cart_On_Block (Bx, By : Integer; Margin : Natural := 0) return Boolean is
     (Cart_Set and then Bed_On_Block (Cart_P, Cart_X, Bx, By, Margin));
   function Cart_On (X, Y : Float) return Boolean is
     (Cart_On_Block (Integer (Float'Floor (X * 4.0)), Integer (Float'Floor (Y * 4.0)), Margin => 1));

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
   --  How far from the stake the foresters look for a tree to fell (0: the
   --  work radius; the spec, Fell_Reach_M), and whether they look further
   --  at all.
   Wood_Reach  : Float := 0.0;
   Wood_Far_On : Boolean := True;
   Wood_From   : Float := 0.0;     --  (a measuring start: no tree is felled nearer the stake than this)
   Food_Reach  : Float := 0.0;     --  how far the gatherers look (0: the work radius), and the porters
   Haul_Reach  : Float := 0.0;
   Stone_From : Float := 0.0;      --  (a measuring start: the camp's stone is taken no nearer the stake than this)

   type Cell is record
      Centre   : Vec3;
      Kind     : Item_Kind := Nothing;
      Count    : Natural := 0;
      Incoming : Natural := 0;   --  on its way there, reserved
      Outgoing : Natural := 0;   --  set aside for someone coming to eat it
      Zone     : Natural := 0;   --  the stockpile zone that owns it
      Turn     : Float := 0.0;   --  the way its lot lies (its zone's; not saved)
      Overflow : Boolean := False;   --  one of its zone's overflow places
      Closed   : Boolean := False;   --  a place no more: under or before the storehouse
      Fit      : Fitting := Ground;  --  what the storehouse's fitting out made it (Fit_Storehouse)
      Made     : Boolean := True;    --  its shelf or barrel stands
      Second   : Boolean := False;   --  a barrel's place: a second barrel stands on the first
      Level_Ok : Boolean := False;   --  its square metre has been looked at and made level (Level_Places; not saved)
   end record;
   Cells   : array (1 .. Max_Cells) of Cell;
   N_Cells : Natural := 0;
   Keep_On     : Boolean := True;    --  a stockman is made (Set_Stockman)
   Keeper_N    : Natural := 0;       --  and who it is
   Carp_On     : Boolean := True;    --  a carpenter is made (Set_Carpenter)
   Carp_N      : Natural := 0;       --  and who it is
   Water_Is_On : Boolean := True;    --  porters bring water to the water barrels (Set_Water)
   Store_Built_By : Natural := 0;    --  who raised the storehouse: the first the carpenter is made of
   procedure Set_Stockman (On : Boolean) is
   begin
      Keep_On := On;
   end Set_Stockman;
   function Stockman_On return Boolean is (Keep_On);
   procedure Set_Carpenter (On : Boolean) is
   begin
      Carp_On := On;
   end Set_Carpenter;
   function Carpenter_On return Boolean is (Carp_On);
   procedure Set_Water (On : Boolean) is
   begin
      Water_Is_On := On;
   end Set_Water;
   function Water_On return Boolean is (Water_Is_On);
   Top_Cut_On : Boolean := True;     --  long grass cut from the top of its tuft (Set_Top_Cut)
   procedure Set_Top_Cut (On : Boolean) is
   begin
      Top_Cut_On := On;
   end Set_Top_Cut;
   function Top_Cut return Boolean is (Top_Cut_On);
   Store_Now : Store_Stats;        --  (a measure: Store_Counts)

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
      Yard   : Boolean := False; --  a stockpile's zone that is the stockyard (Zone_Stockyard): the storehouse's
      Leaving : Boolean := False; --  a stockpile the player has ordered removed (Remove_Stockpile): its places closed,
                                 --  it is gone when the last thing is carried off it
      --  put down whole, with its path (Place_Box): its frame, the grid of its own
      Placed : Boolean := False;
      Fx, Fy : Integer := 0;     --  where its front begins on its path's middle line (a corner of blocks)
      Way    : Way_Index := 0;   --  the way its path runs from there; it lies on the left of that
      Along_B : Natural := 0;    --  blocks of path along its front
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
      Roof_N   : Natural := 0;               --  the last that is roof (its trimming comes after),
      Dress_N  : Natural := 0;               --  the last that is roof or its trimming,
      Wood_N   : Natural := 0;               --  the last that is of wood (what takes straw comes after),
      Bed      : Boolean := False;           --  a bed of straw has been made in it (its owner's, whoever that is)
      Stone_Left : Natural := 0;             --  blocks of its ground's walls and stairs still to lay, as last counted,
      Takes    : Per_Kind := [others => 0];  --  and what they take: logs, sheaves)
      Ladder   : Natural := 0;               --  a ladder stands at it: under which eave (1 front, 2 back, 3 left,
      Ladder_P : Vec3 := (0.0, 0.0, 0.0);    --  4 right; 0: none), and where its foot is
      Ladder_Fells : Natural := 0;           --  trees its builder has gone to fell for want of a log to make one of
      Yard_Wood_N : Natural := 0;            --  (a storehouse's: the last block of its yard that is of wood)
      Cover_N  : Natural := 0;               --  (and the last that is not its coverings' smoothing)
      Raze     : Boolean := False;           --  marked for razing by the player (a label: nothing is taken down yet)
   end record;
   Houses       : array (1 .. Max_Houses) of House_Rec;
   N_Houses     : Natural := 0;
   House_Serial : Natural := 0;       --  houses ever begun (the next one's seed is made from it)
   N_Housing    : Natural := 0;       --  housing zones (counted, not saved)
   --  The lots laid out for the houses still to begin, in the order they
   --  are begun in (Lots (K) is for the house of serial House_Serial + K):
   --  worked out when the player zones housing or lays a path, never while
   --  the band is at its work, and saved.  (John, 2026-11-12: "Don't let the
   --  serfs search for a lot".)  Lots_Short: the next house in turn fits on
   --  none of the housing there is ("Hovels need to fit within the confines
   --  of the zones, if they don't fit the housing deficit stands until the
   --  player designates more area").
   type Lot_Rec is record
      Zone : Natural := 0;
      F    : Castle.Buildings.House;
   end record;
   Lots         : array (1 .. Max_Houses) of Lot_Rec;
   N_Lots       : Natural := 0;
   Lots_Are_Short : Boolean := False;
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
      No_Way_Till : Natural := 0;           --  no forester could get to it: none tries again before this tick
                                            --  (foresters looking further than the work radius: Go_Fell)
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
   Camp_Square : Boolean := False;   --  it is the square the colony was founded on (Place_Square): all of it is floor
   --  The square the colony is founded on (the spec, "the homestake and the
   --  campfire one").  Its path's middle line lies Square_Ring_B blocks
   --  from its middle squarely (6 m: the floor to 5.5 m, the path from 5.5
   --  to 6.5); aslant its corners are Square_Diag_B blocks from the middle
   --  along X and along Y, so that its sides run from corner of blocks to
   --  corner of blocks (the line 6.01 m from the middle, the floor to 5.51).
   --  (John, 2026-11-21: "expand the campfire/homestake square to 13x13m
   --  (with the footpath) so the campfire is in the center".  As it first
   --  was, with Set_Square_Wide off: 22 and 31, the floor 10 m and 9.96.)
   --  **A square keeps the size it was founded with**: it is in its zone's
   --  frame (Along_B: twice its Square_Ring_B squarely, its Square_Diag_B
   --  aslant), which is saved, and whatever asks of a founded square asks
   --  that; only a square still to be founded goes by the size of the day.
   Wide_On : Boolean := True;
   function New_Ring_B return Integer is (if Wide_On then 24 else 22);
   function New_Diag_B return Integer is (if Wide_On then 34 else 31);
   function Square_Ring_B return Integer;      --  (their bodies are with the zones, below)
   function Square_Diag_B return Integer;
   function Square_Is_Wide return Boolean;     --  the square the colony was founded on is of the wider size
   function Square_Side_Now return Float;      --  its floor's side, metres (10 or 11)

   --  A special zone's area is kept whole (the spec, "A special zone's area
   --  is kept whole"): the square's walls stand in strips kept outside its
   --  floor, its path beyond them.
   Outside_On     : Boolean := True;                        --  (Set_Square_Outside: of a square founded from now on)
   Square_Outside : Boolean := False;                       --  this colony's square was founded so (saved)
   Square_Strip   : Square_Strips := [others => 0];         --  the rings kept outside each of its sides (saved)
   --  A square as it lies: its middle, squarely or aslant, how far its floor
   --  reaches along its way and across it, and its strips.  (Half 0.0: none.)
   type Square_Geo is record
      Mx, My : Float := 0.0;
      Aslant : Boolean := False;
      Half   : Float := 0.0;
      Strip  : Square_Strips := [others => 0];
   end record;
   function Ring_Width (G : Square_Geo) return Float is (if G.Aslant then 0.25 / Sqrt (2.0) else 0.25);
   function Geo_Now return Square_Geo;                      --  the founded square's (its body is with the zones, below)
   --  What of it a block column is: its floor, a strip, its path, or none of
   --  it.  Along each of its two ways a column lies within the floor's
   --  reach, in that side's strip, on that side's path, or beyond; beyond
   --  the floor both ways (at a corner) it is path if either says path,
   --  strip if both say strip.  (With no strips: its path is the ring a
   --  path's width wide round its floor, corners and all, as it always was.)
   type Square_Part is (Part_None, Part_Floor, Part_Strip, Part_Path);
   function Part_Of (G : Square_Geo; Bx, By : Integer) return Square_Part is
      Ex : constant Float := (if G.Aslant then 1.0 / Sqrt (2.0) else 1.0);
      Ey : constant Float := (if G.Aslant then 1.0 / Sqrt (2.0) else 0.0);
      Dx : constant Float := (Float (Bx) + 0.5) * 0.25 - G.Mx;
      Dy : constant Float := (Float (By) + 0.5) * 0.25 - G.My;
      U  : constant Float := Dx * Ex + Dy * Ey;
      V  : constant Float := Dy * Ex - Dx * Ey;
      W  : constant Float := Ring_Width (G);
      function Band (C : Float; S : Positive) return Square_Part is
        (if C < G.Half then Part_Floor
         elsif C < G.Half + Float (G.Strip (S)) * W then Part_Strip
         elsif C < G.Half + Float (G.Strip (S)) * W + Path_Width_M then Part_Path
         else Part_None);
   begin
      if G.Half <= 0.0 then
         return Part_None;
      end if;
      declare
         A : constant Square_Part := Band (abs U, (if U >= 0.0 then 1 else 2));
         B : constant Square_Part := Band (abs V, (if V >= 0.0 then 3 else 4));
      begin
         return (if A = Part_Floor then B
                 elsif B = Part_Floor then A
                 elsif A = Part_None or else B = Part_None then Part_None
                 elsif A = Part_Path or else B = Part_Path then Part_Path
                 else Part_Strip);
      end;
   end Part_Of;
   --  The corners of its path's four middle lines (the first to the
   --  south-west squarely, to the west aslant, and on round to the left).
   --  R0: how far the line of a side with no strip lies from its middle,
   --  squarely along X and Y, aslant from corner to middle along them (a
   --  whole number of blocks either way); a strip puts its side's line a
   --  block further out for each ring, squarely straight out and aslant
   --  along X and Y, so that every corner is found without a root: with no
   --  strips they are the corners a square always had, to the bit.
   function Line_Corners (Mx, My : Float; Aslant : Boolean; R0 : Float; Strip : Square_Strips) return Lot_Corners is
      A : array (1 .. 4) of Float;
   begin
      for S in 1 .. 4 loop
         A (S) := R0 + Float (Strip (S)) * 0.25;
      end loop;
      if not Aslant then
         return [(Mx - A (2), My - A (4), 0.0), (Mx + A (1), My - A (4), 0.0),
                 (Mx + A (1), My + A (3), 0.0), (Mx - A (2), My + A (3), 0.0)];
      else
         --  (west: where the south-west side and the north-west one meet; south; east; north)
         return [(Mx + (-A (2) - A (3)) / 2.0, My + (-A (2) + A (3)) / 2.0, 0.0),
                 (Mx + (-A (2) + A (4)) / 2.0, My + (-A (2) - A (4)) / 2.0, 0.0),
                 (Mx + (A (1) + A (4)) / 2.0, My + (A (1) - A (4)) / 2.0, 0.0),
                 (Mx + (A (1) - A (3)) / 2.0, My + (A (1) + A (3)) / 2.0, 0.0)];
      end if;
   end Line_Corners;
   --  Its banks are walled with stone (the spec, "The square's walls and stair"; Set_Square_Walls).
   Places_Lost_N : Natural := 0;       --  (a measure: sleeping places by the fire given up, their ground built on or dug)
   Walls_On    : Boolean := True;
   Steps_On    : Boolean := True;      --  the square's path stepped with stone where it jumps (Set_Path_Steps)
   Corner_On   : Boolean := True;      --  the square metre where two sides' paths cross laid as one (Set_Corner_Whole)
   Strip_Wait_On : Boolean := True;    --  a column of two sides' strips waits for both sides' paths (Set_Strip_Wait)
   Corner_Steps_On : Boolean := True;  --  and the steps of stone run into and through it (Set_Corner_Steps)
   Walls_Stale : Boolean := True;      --  counted again at the next step (whatever moves the ground by the square says so)
   Wall_Left_N : Natural := 0;         --  blocks of stone still to lay in them, as last counted
   Level_On    : Boolean := True; --  a camp's floor is levelled by the band (off: as before it was)
   Seats_Laid  : Natural := 0;
   Fire_Logs   : Natural := 0;    --  stacked by the fire
   Fuel_H      : Float := 0.0;    --  hours of burning left on the fire
   Ember_H     : Float := 0.0;    --  burnt out: hours of its dying down left (0: burning, or out)
   Labour_On : Boolean := True;   --  the camp takes the band's labour (off: as it was before it did)
   Beds_On   : Boolean := True;   --  each makes itself a bed of straw (off: as it was before they did)
   Hold_On   : Boolean := True;   --  the cook keeps a pot's fill of greens from being eaten raw (off: as before it did)
   Ladders_On : Boolean := True;  --  a roof is thatched from a ladder (off: from the ground, as it was)
   Holes_On  : Boolean := True;   --  a hole under a path is filled as it is laid (off: as it was)
   Path_Level_On : Boolean := True;   --  and its columns brought to its own line (off: as before 2026-11-19)
   --  What a house begun from now on is made of (each off: as before 2026-11-19).  A house keeps
   --  how it was begun (CB.House.Truss, Sill: it is saved as a count of its blueprint's blocks laid),
   --  and these are saved with the colony:
   Truss_On       : Boolean := True;  --  its roof's timbers: trusses in its gables, tie beams across, a ridge beam
   Sill_On        : Boolean := True;  --  its windows' sill and lintel run from post to post, its jambs of plank
   Full_On        : Boolean := True;  --  with its roof's timbers: its gables' trusses to the ends of their walls, and
                                      --  the same either side of their middle (CB.House.Full; Set_Full_Truss)
   Smooth_Covers_On : Boolean := True;  --  (a storehouse begun from now on: the spec, Set_Smooth_Covers)
   Fence_Pieces_On  : Boolean := True;  --  (and Set_Fence_Pieces)
   N_Ladders, N_Ladders_Lost : Natural := 0;   --  made, and lost with whoever carried them, all told
   Bed_Sheaves : Natural := 0;    --  sheaves of straw in all the beds made
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
   --  (looked through for trees and sources alone, not for its bushes: Index_Stack's Far)
   Indexed_Far : constant Indexed_Access := new Indexed_Grid'[others => [others => False]];

   type Task_State is (Idle, To_Bush, Picking, To_Store, Storing, Strolling,
                       To_Tree, Chopping, To_Pile, Lifting, To_Source, Gathering,
                       Stalking, Aiming, Recovering, To_Carcass, Lifting_Carcass, To_Butcher, Butchering,
                       To_Eat, Eating, To_Bed, Sleeping,
                       To_Take, Taking, To_Camp, Putting_In, Cooking, To_Seat,
                       Stoking, To_Patch, Tamping,
                       To_Site, Raising,
                       To_Cart, At_Cart,
                       Making, To_Ladder,
                       To_Tow, Towing,
                       To_Fitting, Fitting_Out);
   --  (To_Site, Raising: a builder going to its house's site, and at work there)
   --  (To_Cart, At_Cart: going to the lord's cart for salt, and taking it out)
   --  (Making: a ladder, at the stockpile; To_Ladder: going to where one stands, to take it away)
   --  (To_Fitting, Fitting_Out: the carpenter, with a log, to a shelf's or a barrel's place, and making it)
   --  (saved by position: new states go on the end, as below)
   type Why_Idle is (Nothing_Yet, No_Bush, No_Room, No_Way, No_Tree, Enough_Wood, Nothing_To_Haul,
                     No_Source, Stocks_Full, No_Prey, Enough_Meat, Deer_Spared,
                     No_Camp, Pot_Full, Nothing_To_Cook, Winter_Bare, Enough_Food, Camp_Unbuilt,
                     No_Timber, No_Thatch, No_Stone, Herds_Breeding, Herd_Settling, Nearly_Full,
                     Bushes_Taken, Trees_No_Way, Trees_Taken, Trees_Spared, Trees_Further);
   --  (Trees_No_Way .. Trees_Further, 2026-11-19: why a forester has no tree, said as nearly as it can be:
   --  those in reach cannot be got to, are being felled by others, are apple trees and spared; or it is
   --  looking a ring further off)
   --  (Bushes_Taken: ripe bushes in reach, each with as many pickers as it takes)
   --  (No_Timber, No_Thatch, No_Stone: a builder with no wood, no straw or no stone to build with)
   --  (Herds_Breeding: a hunter with deer in reach, every herd of them down to Spare_Last and left to
   --  breed; Herd_Settling: the only deer in reach of a herd it has just shot at, let settle first)
   --  (Nearly_Full: the stockpile's last places kept for loads already in hand: nothing new brought in)
   --  why one does nothing for want of room
   function Full_Why return Why_Idle is (if Last_N > 0 then Nearly_Full else No_Room);
   --  what the cook is bringing to the camp (For_Store: nothing, its load is for a stockpile)
   --  (For_Stoke: no load at all: it goes to put a log from the stack on
   --  the fire.  For_Ring, For_Frame: stone and wood to build the hearth with,
   --  which anyone may be bringing, as a seat log.)
   --  (For_Floor: earth, for a hollow of the camp's floor.)
   --  (For_House: wood or straw, for the house it is building.)
   --  (For_Bed: straw, for its own bed.)
   --  (For_Ladder: a log, to make a ladder of.)
   type Camp_Use is (For_Store, For_Pot, For_Fire, For_Seat, For_Stoke, For_Ring, For_Frame, For_Floor, For_House,
                     For_Bed, For_Ladder, For_Fitting, For_Wall);
   --  (For_Fitting: a log, for the carpenter's next shelf or barrel.)
   --  (For_Wall: stone, for the walls and stairs of the square the colony was
   --  founded on: carried to the wall itself, never to the fire.)
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
      Ladder_Of : Natural := 0;         --  the house whose ladder it is going for (To_Ladder)
      Build_First : Boolean := False;   --  a forester set to building from the job list (Set_Builder): it takes a
                                        --  house before any forester not so set, whatever their skill
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
      Bed      : Boolean := False;       --  it has made itself a bed of straw at the camp,
      Bed_At   : Vec3 := (0.0, 0.0, 0.0);   --  and where (it stays there when it has a house: John, 2026-11-12,
                                            --  "we will let the old one decay outside when we add decay later")
      Bed_Has  : Natural := 0;           --  the sheaves in it
      Placed   : Boolean := False;       --  it has a place of its own by the fire (Bed_At: where its feet are,
      Bed_Dir  : Float := 0.0;           --  and the way they point as it lies), bed or no bed,
      Bed_Lo   : Integer := -1;          --  the rows of the ground's top under it when it was chosen (-1: it lies
      Bed_Hi   : Integer := -1;          --  on the old ring, whatever the ground)
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
         when Earth => "earth",
         when Salt => "salt",
         when Ladder => "ladders");

   function Ticks return Natural is (Tick_N);

   function Meat_Of (C : Castle.Deer.Class) return Positive is (if Curing_On then Deer_Lb (C) else Deer_Joints (C));
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
         when To_Eat | To_Bed | To_Take | To_Camp | To_Seat | To_Patch | To_Site | To_Cart | To_Ladder
            | To_Tow | Towing | To_Fitting =>
           (if Band (I).Route.N >= 2 and then Band (I).Leg < Band (I).Route.N then Walking else Standing),
         when Tamping | Raising | Making | Fitting_Out => Picking,
         when Eating =>
           (if Band (I).From_Pot and then Band (I).Seat > 0 and then (Band (I).Seat + 1) / 2 <= Seats_Laid
            then Eating_Seated else Eating),
         when Sleeping => Sleeping,
         when Taking | Putting_In | Stoking | At_Cart => Putting_Down,
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
   --  condition: a factor of every work rate.)
   function Vigour (M : Member) return Float is
     (if Needs_On and then M.Fed <= 0.0 then Starving_Pace else 1.0);

   --  The colony's pace: what every work rate and every pace over the
   --  ground is multiplied by (the spec, Serf_Pace).
   Pace_Now : Float := Serf_Pace;
   procedure Set_Pace (To : Float) is
   begin
      Pace_Now := Float'Max (0.1, To);
   end Set_Pace;
   function Pace return Float is (Pace_Now);

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

   --  rate = pace x condition x skill x direction: every work timer goes by this.
   function Work_Rate (M : Member; W : Work_Kind) return Float is
     (Pace_Now * Vigour (M) * Skill_Factor (M, W) * Direction (M));

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
         when Ladder                        => House_Raising,
         when Nothing | Salt                => Handling);

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
         when To_Carcass | Lifting_Carcass | To_Butcher | Butchering | To_Cart | At_Cart => Butchering,
         when To_Take | Taking | To_Camp | Putting_In | Cooking | Stoking =>
           (if M.Use_For in For_Ring | For_Frame | For_Wall then Site_Work
            elsif M.Use_For = For_House then House_Raising
            elsif M.Use_For in For_Bed | For_Fitting then Handling
            --  (taking from the stores to put in another place: the overflow
            --  moved, closed places cleared, the stockman's sorting; the cook
            --  going to stir its pot is For_Store too, and cooks)
            elsif M.Use_For = For_Store and then M.State in To_Take | Taking then Handling
            else Camp_Keeping),
         when To_Patch | Tamping                                  => Site_Work,
         when To_Site | Raising                                   =>
           (if M.Site_Patch > 0 then Site_Work else House_Raising),
         when Making | To_Ladder                                  => House_Raising,
         when Fitting_Out                                         => Joinery,
         when Idle | Strolling | To_Eat | Eating | To_Bed | Sleeping | To_Seat | To_Tow | Towing | To_Fitting
                                                                  => Handling);

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

   --  **What one of the band finds there is no way to, the others are told**
   --  (the spec, Set_Ways_Told): a bush, an apple tree or a place to fetch
   --  from, by the number its own failures are remembered under, and until
   --  when.  One place to a number of the table: a later one that falls on
   --  the same place puts the earlier out, which is then asked again.
   type Told_Rec is record
      Id         : Natural := 0;
      Until_Tick : Natural := 0;
   end record;
   Max_Told : constant := 4_096;
   Told     : array (0 .. Max_Told - 1) of Told_Rec;
   Ways_Told_On : Boolean := True;
   procedure Set_Ways_Told (On : Boolean) is
   begin
      Ways_Told_On := On;
   end Set_Ways_Told;
   function Ways_Told return Boolean is (Ways_Told_On);
   --  (it is of the band's looking further: off with that, as before 2026-11-19)
   function Told_On return Boolean is (Ways_Told_On and then Wood_Far_On);
   function No_Way_Told (Id : Natural) return Boolean is
     (Told_On and then Told (Id mod Max_Told).Id = Id and then Tick_N < Told (Id mod Max_Told).Until_Tick);
   procedure Tell_No_Way (Id : Natural; Seconds : Positive) is
   begin
      Told (Id mod Max_Told) := (Id => Id, Until_Tick => Tick_N + Seconds * Tick_Hz);
   end Tell_No_Way;
   function Ways_Told_Now return Natural is
      N : Natural := 0;
   begin
      for T of Told loop
         if T.Until_Tick > Tick_N then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Ways_Told_Now;

   --  A route from where M stands to Goal; True if it gets there (or, for
   --  Near > 0, ends within Near metres of it).
   --  A goal under the lord's cart has no ground to stand on, and the way to
   --  such a one is searched for as far as the band's ground reaches before
   --  it is given up (57 ms, where a plan is 1: found in the stage 6 run,
   --  whose idle hands strolled there).  So a place on the cart is taken to
   --  mean the nearest place beside it.
   function Off_Cart (P : Vec3) return Vec3 is
      Bx : constant Integer := B (P.X);
      By : constant Integer := B (P.Y);
   begin
      if not Cart_On_Block (Bx, By, Margin => 1) then
         return P;
      end if;
      declare
         X_Lo : constant Float := Float (Cart_X0 - 1) * 0.25 - 0.4;
         X_Hi : constant Float := Float (Cart_X0 + (if Cart_X then Cart_Long_B else Cart_Wide_B) + 1) * 0.25 + 0.4;
         Y_Lo : constant Float := Float (Cart_Y0 - 1) * 0.25 - 0.4;
         Y_Hi : constant Float := Float (Cart_Y0 + (if Cart_X then Cart_Wide_B else Cart_Long_B) + 1) * 0.25 + 0.4;
         D    : constant Float :=
           Float'Min (Float'Min (P.X - X_Lo, X_Hi - P.X), Float'Min (P.Y - Y_Lo, Y_Hi - P.Y));
      begin
         return (if D = P.X - X_Lo then (X_Lo, P.Y, P.Z) elsif D = X_Hi - P.X then (X_Hi, P.Y, P.Z)
                 elsif D = P.Y - Y_Lo then (P.X, Y_Lo, P.Z) else (P.X, Y_Hi, P.Z));
      end;
   end Off_Cart;

   --  Refuse: a goal the walking map's pieces of ground show to be out of
   --  reach is not made for at all (no search: for one who has many places
   --  to choose among, a forester with a wood across a river).
   --  Budget: the floors the search may look at (0: as many as a plan has).
   function Route_To (M : in out Member; Goal_Asked : Vec3; Near : Float := 0.0; Refuse : Boolean := False;
                      Budget : Natural := 0) return Boolean
   is
      Goal : constant Vec3 := (if Cart_Set then Off_Cart (Goal_Asked) else Goal_Asked);
   begin
      M.Route := (if Budget > 0
                  then Castle.Nav.Plan (M.Pos, Goal, Budget => Budget, Within => Own_Region, Refuse => Refuse)
                  else Castle.Nav.Plan (M.Pos, Goal, Within => Own_Region, Refuse => Refuse));
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

   --  A route asked of the walking map's pieces of ground first: not made
   --  for at all where they show it out of reach (no search).  If there is
   --  no way, and M has a way home (one cut off itself says nothing of it),
   --  the others are told: Id is nobody's to try for a day, or ten where a
   --  whole search ran out.  (The search is given all a plan has: with a
   --  forester's short one, 300 floors a metre, ways through the camp and
   --  the housing to vegetables 86 m off ran out, 672 of them in the
   --  reference band's 41 days, and were told as no way.)
   Home_Tick : Integer := -1;                 --  whether there is a way home from Home_From, asked this step
   Home_From : Vec3 := (0.0, 0.0, 0.0);
   Home_Is   : Boolean := False;
   function Route_Asked (M : in out Member; Goal : Vec3; Near : Float; Id : Natural) return Boolean is
      From : constant Vec3 := M.Pos;
   begin
      if Route_To (M, Goal, Near, Refuse => True) then
         return True;
      end if;
      declare
         Round : constant Boolean := Castle.Nav.Last_Stats.Cut_Short;
      begin
         if Home_Tick /= Tick_N or else Home_From /= From then
            Home_Tick := Tick_N;
            Home_From := From;
            Home_Is := Castle.Nav."="
              (Castle.Nav.Plan (From, Stake_At, Within => Own_Region, Refuse => True).Result, Castle.Nav.Found);
         end if;
         if Home_Is then
            Tell_No_Way (Id, (if Round then Tree_Round_S else Tree_No_Way_S));
         end if;
      end;
      return False;
   end Route_Asked;

   --  A walker at the height of the place it steps into as it steps into it (the spec).
   Edge_On : Boolean := True;
   procedure Set_Step_At_Edge (On : Boolean) is
   begin
      Edge_On := On;
   end Set_Step_At_Edge;
   function Step_At_Edge return Boolean is (Edge_On);

   --  One step along the route; True once at its end (or, Stop_Within > 0,
   --  that close to Stop_At).
   function Walk (M : in out Member; Stop_At : Vec3; Stop_Within : Float; Scale : Float := 1.0) return Boolean is separate;

   --  Walk, to the end of the route it planned (M.Goal).
   function Walk_On (M : in out Member; Within : Float) return Boolean is
      Goal : constant Vec3 := M.Goal;
   begin
      return Walk (M, Goal, Within);
   end Walk_On;

   --  A piece of a site's ground is worked from beside it (Set_Reach_Out; the rest of it is before
   --  Stand_On_Fill).  One going to the place chosen for that (Go_Beside: its goal is the place, its
   --  spot the middle of the work) goes all the way to it: the place was chosen because the bout
   --  writes none of its block columns, and half a metre short of it is another place.  (Until
   --  2026-11-23, late, it stopped within half a metre as any builder does, and a way found again
   --  could end two and a half metres off: a builder stopped half way up the step on to earth it had
   --  just filled in, with its feet in it.)  Told from what a save holds: nothing new to save.
   Reach_On      : Boolean := True;
   Beside_Near_M : constant := 0.3;
   function Goes_Beside (M : Member) return Boolean is
     (Reach_On and then M.State = To_Site and then M.Site_Patch > 0 and then Flat_Dist (M.Goal, M.Spot) > 0.05);

   --  Twice a second: whether the ground under the rest of the route has
   --  changed so that it can't be walked; then the way is found again.
   --  How near the goal a route may end for the work M is going to.
   function Near_Of (M : Member) return Float is
     (case M.State is
         when To_Bush => (if M.Bush > 0 then Bushes (M.Bush).Radius + 0.7 else 0.0),
         when To_Tree => (if M.Tree > 0 then Half_W (M.Tree) + 0.9 else 0.0),
         when To_Pile => 1.0,
         when To_Patch => (if M.Site_Seg > 0 then 0.7 else Patch_Reach_M),
         when To_Site => (if Goes_Beside (M) then Beside_Near_M else Build_Reach_M),
         when To_Source => (if M.Fetch in Sticks | Apples then 1.2 else 0.0),
         when To_Tow => 0.5,
         when Towing => 0.3,
         when others  => 0.0);

   procedure Keep_Route_Good (M : in out Member; Ok : out Boolean) is separate;

   ------------------------------------------------------------------ deciding

   --  A bush takes as many pickers as it has basketfuls of ripe berries
   --  (Set_Bush_Sharing; off: one, as it was).  Who else is at bush K, or on
   --  the way to it; and whether I may go to it.
   Share_On : Boolean := True;
   procedure Set_Bush_Sharing (On : Boolean) is
   begin
      Share_On := On;
   end Set_Bush_Sharing;
   function Bush_Sharing return Boolean is (Share_On);
   function Pickers (K : Positive; But : Natural) return Natural is
      N : Natural := 0;
   begin
      for J in 1 .. N_Members loop
         if J /= But and then not Band (J).Is_Dead and then Band (J).Bush = K
           and then Band (J).State in To_Bush | Picking
         then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Pickers;
   function Bush_Free (K : Positive; I : Positive) return Boolean is
     (Bushes (K).Reserved_By = 0 or else Bushes (K).Reserved_By = I
      or else (Share_On
               and then Pickers (K, But => I)
                        < Natural'Max (1, (Bushes (K).Ripe + Carry_Limit (Berries) - 1) / Carry_Limit (Berries))));

   procedure Release (M : in out Member; I : Positive) is separate;

   --  The nearest ripe bush nobody else is after, weighed toward the stake
   --  (half the distance from the stake counts too), that a route reaches.
   --  How much the way home from a bush or a tree counts beside the way
   --  to it, for whoever chooses one: half; nothing for one that fends for
   --  itself (it eats where it picks: the nearest to where it stands).
   function Stake_Weight (M : Member) return Float is (if M.Fends then 0.0 else 0.5);

   function Go_Pick (I : Positive) return Boolean is separate;

   --  A stockpile place under the cart: its bed over the place's middle, as
   --  it stands or where a place is held for it.  Nothing is put there.
   --  **And beside its wheels and under its shafts** (the spec, "Room round the
   --  cart"): the cart as it is drawn reaches past its bed, a wheel to either
   --  side and its shafts before it.  P: the middle of its bed; Turn: the way
   --  its shafts point; C: a place's middle.
   Cart_Room_On : Boolean := True;
   procedure Set_Cart_Room (On : Boolean) is
   begin
      Cart_Room_On := On;
   end Set_Cart_Room;
   function Cart_Room return Boolean is (Cart_Room_On);
   function Cart_Reaches (P : Vec3; Turn : Float; C : Vec3) return Boolean is
      Dx : constant Float := C.X - P.X;
      Dy : constant Float := C.Y - P.Y;
      A  : constant Float := Dx * Cos (Turn) + Dy * Sin (Turn);        --  along its bed, toward its shafts
      S  : constant Float := Dy * Cos (Turn) - Dx * Sin (Turn);        --  across it
   begin
      return (abs S <= 0.6 and then A >= -1.1 and then A <= Cart_Shaft_M + 0.3)
        or else (abs S <= 1.25 and then abs A <= 1.25);
   end Cart_Reaches;
   function Under_Cart (K : Positive) return Boolean is
     (Cart_On_Block (B (Cells (K).Centre.X), B (Cells (K).Centre.Y))
      or else (Cart_Bound
               and then Bed_On_Block (Goal_P, Turn_Along_X (Goal_Turn), B (Cells (K).Centre.X), B (Cells (K).Centre.Y)))
      or else (Cart_Room_On
               and then ((Cart_Set and then not Cart_Towed and then Cart_Reaches (Cart_P, Cart_Turn, Cells (K).Centre))
                         or else (Cart_Bound and then Cart_Reaches (Goal_P, Goal_Turn, Cells (K).Centre)))));

   --  Stockpile place K takes N of kind Kind: one holding that with room for
   --  all of them, or an empty one; never one under the cart.  The one test
   --  of it (Go_Store, Room_For, Can_Store, the butchering's; Supply's empty
   --  places).
   --  The most place K holds of Kind: by what it is fitted out as.
   --  (stacked: baskets of food on the storehouse's floor, Floor_Stack high; a barrel's place with a
   --  second barrel on the first, Barrel_Stack barrels' worth)
   function Place_Limit (K : Positive; Kind : Item_Kind) return Natural is
     (case Cells (K).Fit is
         when Ground         => Cell_Limit (Kind),
         when Floor          => (if Stacks_On and then Kind in Berries | Apples | Vegetables | Grain then Floor_Stack else 1)
                                * Cell_Limit (Kind),
         when Cover          => Cover_Holds * Cell_Limit (Kind),
         when Shelf          => Shelf_Hides,
         when Meat_Barrel    => (if Cells (K).Second then Barrel_Stack else 1)
                                * (if Curing_On then Barrel_Meat_Lb else Cell_Limit (Meat)),
         when Water_Barrel   => (if Cells (K).Second then Barrel_Stack else 1) * Barrel_Pails,
         when Lean           => 1,
         when Kept_Clear     => 0);

   --  What a place fitted out is for (Ground: anything but water, which
   --  is kept only in a barrel).
   function For_Fit (F : Fitting; Kind : Item_Kind) return Boolean is
     (case F is
         when Ground       => Kind /= Water,
         when Floor        => Kind in Berries | Apples | Vegetables | Grain | Salt,
         when Shelf        => Kind = Hide,
         when Meat_Barrel  => Kind = Meat,
         when Water_Barrel => Kind = Water,
         when Cover        => Kind in Wood | Straw | Stone,
         when Lean         => Kind = Ladder,
         when Kept_Clear   => False);

   --  Place K has room for N of Kind: holding that with room for all of
   --  them, or empty; never under the cart, closed, or a shelf or a barrel
   --  not yet made.
   function Room_In (K : Positive; Kind : Item_Kind; N : Natural) return Boolean is
     (((Cells (K).Kind = Kind and then Cells (K).Count + Cells (K).Incoming + N <= Place_Limit (K, Kind))
       or else (Cells (K).Kind = Nothing and then Cells (K).Incoming = 0))
      and then Cells (K).Made and then not Under_Cart (K) and then not Cells (K).Closed);

   --  Whoever brings Kind in may put it in place K: an ordinary place for
   --  anything but water, a water barrel for water.
   function Open_To (K : Positive; Kind : Item_Kind) return Boolean is
     ((Cells (K).Fit = Ground and then Kind /= Water) or else (Cells (K).Fit = Water_Barrel and then Kind = Water));

   function Takes (K : Positive; Kind : Item_Kind; N : Natural) return Boolean is
     (Open_To (K, Kind) and then Room_In (K, Kind, N));

   --  A place fitted out for Kind with room for N of it: where the stockman
   --  puts what it carries.
   function Keeps (K : Positive; Kind : Item_Kind; N : Natural) return Boolean is
     (Cells (K).Fit /= Ground and then For_Fit (Cells (K).Fit, Kind) and then Room_In (K, Kind, N));

   --  (the storehouse stands: until it does nobody is its stockman or its carpenter, one named by
   --  hand before then no more than another: Name_Stockman.  Chosen by skill, the two are only
   --  ever chosen once it stands, so this says nothing new of them.)
   function Store_Stands return Boolean is (Store_House in 1 .. N_Houses and then Houses (Store_House).Built);
   function Is_Keeper (I : Positive) return Boolean is (Keep_On and then Keeper_N = I and then Store_Stands);
   function Is_Carpenter (I : Positive) return Boolean is (Carp_On and then Carp_N = I and then Store_Stands);
   function Stockman return Natural is (if Keep_On and then Store_Stands then Keeper_N else 0);
   function Carpenter return Natural is (if Carp_On and then Store_Stands then Carp_N else 0);
   function Stockman_Named (I : Positive) return Boolean is
     (Keep_On and then Keeper_N = I and then I <= N_Members and then not Band (I).Is_Dead and then Band (I).Job = Porter);
   function Carpenter_Named (I : Positive) return Boolean is
     (Carp_On and then Carp_N = I and then I <= N_Members and then not Band (I).Is_Dead and then Band (I).Job = Forester);

   --  A barrel's place that is to have a second barrel: its first is full (what it holds, not what
   --  is on its way), and no second stands yet.
   function Wants_Second (C : Positive) return Boolean is
     (Stacks_On and then Cells (C).Fit in Meat_Barrel | Water_Barrel and then Cells (C).Made
      and then not Cells (C).Second and then not Cells (C).Closed
      and then Cells (C).Kind = (if Cells (C).Fit = Meat_Barrel then Meat else Water)
      and then Cells (C).Count >= Place_Limit (C, Cells (C).Kind));

   --  The shelves and barrels the carpenter has still to make (logs: one
   --  each), less the logs on their way to them.
   function Fittings_Left return Natural is
      N : Natural := 0;
   begin
      if not Carp_On then
         return 0;
      end if;
      for C in 1 .. N_Cells loop
         if (not Cells (C).Made and then not Cells (C).Closed) or else Wants_Second (C) then
            N := N + 1;
         end if;
      end loop;
      for I in 1 .. N_Members loop
         if Band (I).Use_For = For_Fitting and then Band (I).Carry = Wood then
            N := N - Natural'Min (N, Band (I).Carried);
         end if;
      end loop;
      return N;
   end Fittings_Left;

   --  How much further an overflow place counts than an ordinary one, to
   --  whoever chooses where to put a load (none is taken while an
   --  ordinary place takes it), and how much nearer to whoever takes from
   --  the stores (an overflow place is emptied first).
   Overflow_Last : constant := 1.0e6;

   --  The nearest stockpile cell that takes what M carries: one already
   --  holding it with room, else an empty one; an overflow place last.
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

   --  The overflow holds something, or has something on its way to it:
   --  the band's signal to bring nothing more into the stores until it has
   --  been moved in (John, 2026-11-17: "So the overflow, signals to the
   --  serfs, don't carry anything else to the stockpile").
   function Overflow_Busy return Boolean is
     (Overflow_On
      and then (for some C in 1 .. N_Cells =>
                  Cells (C).Overflow and then (Cells (C).Count > 0 or else Cells (C).Incoming > 0)));

   --  The stores' empty ordinary places, open to anything (the last-places
   --  signal's count: John, 2026-11-17, "use the last 10 blocks as a signal
   --  to the serfs to slow/cease production if the stockpile gets full").
   function Empty_Places return Natural is
      N : Natural := 0;
   begin
      for C in 1 .. N_Cells loop
         if Cells (C).Kind = Nothing and then Cells (C).Incoming = 0 and then Cells (C).Fit = Ground
           and then not Cells (C).Overflow and then not Cells (C).Closed and then Cells (C).Made
           and then not Under_Cart (C)
         then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Empty_Places;

   --  How many of them are kept for loads in hand: Last_N, and no more than
   --  a tenth of the stores' ordinary places (his ten are of a hundred: on a
   --  stockpile of ten places or fewer, ten kept would be all of it, and
   --  nobody would ever set out).
   function Kept_Places return Natural is
      N : Natural := 0;
   begin
      if Last_N = 0 then
         return 0;
      end if;
      for C in 1 .. N_Cells loop
         if Cells (C).Fit = Ground and then not Cells (C).Overflow and then not Cells (C).Closed and then Cells (C).Made then
            N := N + 1;
         end if;
      end loop;
      return Natural'Min (Last_N, N / 10);
   end Kept_Places;

   --  Room to set out for K: an ordinary place that takes a whole load of
   --  it, and the overflow empty (what an overflow place takes is no room
   --  to set out for; with the overflow off, as before it, a place that
   --  takes one more).
   function Room_For (K : Item_Kind) return Boolean is
     (not Overflow_Busy
      and then (for some C in 1 .. N_Cells =>
                  not Cells (C).Overflow
                  and then Takes (C, K, (if Room_Gated then Natural'Max (1, Carry_Limit (K)) else 1))));

   --  The whole loads of K the ordinary places have room for (an empty
   --  place counted for every kind at once).
   function Ordinary_Loads (K : Item_Kind) return Natural is
      Load  : constant Positive := Positive'Max (1, Carry_Limit (K));
      Loads : Natural := 0;
      --  (with the last places kept, only the empty places past them count)
      Spare : Integer := (if Last_N > 0 then Empty_Places - Kept_Places else Integer'Last);
   begin
      for C in 1 .. N_Cells loop
         declare
            Cl : Cell renames Cells (C);
         begin
            if Cl.Overflow or else Cl.Closed or else Under_Cart (C) or else not Open_To (C, K) or else not Cl.Made then
               null;
            elsif Cl.Kind = K then
               Loads := Loads + Integer'Max (0, Place_Limit (C, K) - Cl.Count - Cl.Incoming) / Load;
            elsif Cl.Kind = Nothing and then Cl.Incoming = 0 and then (Cl.Fit /= Ground or else Spare > 0) then
               Loads := Loads + Place_Limit (C, K) / Load;
               if Cl.Fit = Ground then
                  Spare := Spare - 1;
               end if;
            end if;
         end;
      end loop;
      return Loads;
   end Ordinary_Loads;

   --  The loads of K being brought in for the stores and not yet bound for a
   --  place: in hands, at a bush or a source, or being taken out of the
   --  overflow to be put in the stockpile.
   function Loads_Out (K : Item_Kind) return Natural is
      Out_N : Natural := 0;
   begin
      for J in 1 .. N_Members loop
         declare
            O : Member renames Band (J);
         begin
            if not O.Is_Dead and then not O.Fends and then O.Use_For = For_Store
              and then ((O.Carry = K and then O.Carried > 0 and then O.State not in To_Store | Storing)
                        or else (O.Carried = 0
                                 and then ((K = Berries and then O.State in To_Bush | Picking)
                                           or else (O.State in To_Source | Gathering and then O.Fetch = K)
                                           or else (O.State in To_Take | Taking and then O.Cell in 1 .. N_Cells
                                                    and then (Cells (O.Cell).Overflow or else Cells (O.Cell).Closed)
                                                    and then Cells (O.Cell).Kind = K))))
            then
               Out_N := Out_N + 1;
            end if;
         end;
      end loop;
      return Out_N;
   end Loads_Out;

   --  Whether one more may set out to bring K in for the stores, with the
   --  overflow on: the overflow empty, and the whole loads of it the
   --  ordinary places have room for more than the loads of it already being
   --  brought in.  Without the count, four gatherers set out for the last
   --  room and three came home to none.  Off: Room_For, as before.  (A
   --  gatherer's and a porter's.)
   function Room_To_Set_Out (K : Item_Kind) return Boolean is
     (if not Room_Gated then Room_For (K)
      else not Overflow_Busy and then Ordinary_Loads (K) > Loads_Out (K));

   --  A stockpile cell takes the whole of what M carries: Go_Store's own
   --  test (the cells it has lately failed to get to left out).
   function Can_Store (M : Member) return Boolean is
     (for some K in 1 .. N_Cells => Takes (K, M.Carry, M.Carried) and then not Failed (M, Cell_Base + K));

   --  The nearest standing tree nobody else is felling, weighed toward the
   --  stake as bushes are, that may be felled (apple trees are kept while
   --  that order stands) and that a route reaches.
   function Looked_Through (Reach : Float) return Boolean;      --  (its body is with how far the band looks, below)
   procedure Look_Further_For (Food : Boolean);                 --  (and its)
   --  (the trees a forester may try in one thought and what each scores: Go_Fell's own, nothing kept in them)
   Fell_Cand  : array (1 .. Max_Trees) of Natural := [others => 0];
   Fell_Score : array (1 .. Max_Trees) of Float := [others => 0.0];
   function Tree_Spared (K : Positive) return Boolean;          --  (its body is with the square's path, below)
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
   function Tree_On_Square (K : Positive) return Boolean;       --  (their bodies are with the square's path, below)
   procedure Stump_Out (K : Positive);
   function Tree_In_Box (K : Positive) return Natural;
   procedure Box_Tree_Felled (Z : Positive);                    --  (its body is with the stockpile put down whole)
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
   function Go_Fetch (I : Positive; K : Item_Kind; Reach_M : Float := 0.0; Least_M : Float := 0.0)
                      return Boolean is separate;

   --  The ripe bush a gatherer would go for (0: none): the nearest nobody
   --  else is after, weighed toward the stake.
   function Best_Bush (I : Positive) return Natural is separate;

   --  The apple tree in fruit a gatherer would go for (0: none), the same way.
   function Best_Apple_Tree (I : Positive) return Natural is separate;

   function Go_Apples (I : Positive; K : Positive) return Boolean is
      M : Member renames Band (I);
   begin
      if (if Told_On then Route_Asked (M, Tree_Base (K), Half_W (K) + 1.0, Tree_Base_Id + K)
          else Route_To (M, Tree_Base (K), Half_W (K) + 1.0))
      then
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
   --  reserve, then stone as it is wanted, then water while the
   --  storehouse's water barrels have room (Set_Water).

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
         if Asked_For (K) and then Room_To_Set_Out (K) and then not Failed (M, Kind_Id (K)) then
            return K;
         end if;
      end loop;
      --  then water, while a water barrel has room (John, 2026-11-17: "porters
      --  can also begin bringing water to stockhouse")
      if Water_Is_On and then Room_To_Set_Out (Water) and then not Failed (M, Kind_Id (Water)) then
         return Water;
      end if;
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
      if Route_To (M, Goal, 1.5) then            --  (toward the lord's cart: to beside it, Route_To)
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
   Bed_Id  : constant := 31_002;   --  a fail memo: no straw to cut for its bed,
   No_Way_Id : constant := 31_003; --  and: no way to where it is to lie with it
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

   --  The square's size: its own once it is founded (its zone's frame), else the size of the day.
   function Square_Ring_B return Integer is
     (if Camp_Square and then Camp_Zone_N > 0 and then Zones (Camp_Zone_N).Way mod 2 = 0
        and then Zones (Camp_Zone_N).Along_B > 0
      then Zones (Camp_Zone_N).Along_B / 2 else New_Ring_B);
   function Square_Diag_B return Integer is
     (if Camp_Square and then Camp_Zone_N > 0 and then Zones (Camp_Zone_N).Way mod 2 = 1
        and then Zones (Camp_Zone_N).Along_B > 0
      then Zones (Camp_Zone_N).Along_B else New_Diag_B);
   function Square_Is_Wide return Boolean is
     (Camp_Square and then Camp_Zone_N > 0
      and then (if Zones (Camp_Zone_N).Way mod 2 = 0 then Square_Ring_B >= 24 else Square_Diag_B >= 34));
   function Square_Side_Now return Float is (if Square_Is_Wide then 11.0 else 10.0);
   function Geo_Now return Square_Geo is
   begin
      if not Camp_Square or else Camp_Zone_N = 0 then
         return (others => <>);
      end if;
      declare
         Aslant : constant Boolean := Zones (Camp_Zone_N).Way mod 2 = 1;
      begin
         return (Mx => Camp_At.X, My => Camp_At.Y, Aslant => Aslant,
                 Half => (if Aslant then Float (Square_Diag_B) * 0.25 / Sqrt (2.0) else Float (Square_Ring_B) * 0.25)
                         - Path_Width_M / 2.0,
                 Strip => (if Square_Outside then Square_Strip else [others => 0]));
      end;
   end Geo_Now;
   --  A block column of a strip kept for the walls of the square the colony
   --  was founded on: nobody's to zone, as its floor is its zone's and its
   --  path a path's, so that the wall has its ground when it comes.
   --  (Housing pulled along a walled side with a row toward the square took
   --  the strip, eighty block columns of it along ten metres: the strip was
   --  then not laid as path where it should be, and the wall stood on
   --  housing.)
   function Strip_Kept (Bx, By : Integer) return Boolean is
     (Camp_Square and then Square_Outside and then (for some S in 1 .. 4 => Square_Strip (S) > 0)
      and then Part_Of (Geo_Now, Bx, By) = Part_Strip);
   procedure Set_Square_Outside (On : Boolean) is
   begin
      Outside_On := On;
   end Set_Square_Outside;
   function Square_Outside_Rule return Boolean is (Outside_On);
   function Square_Is_Outside return Boolean is (Camp_Square and then Square_Outside);
   function Square_Strips_Now return Square_Strips is
     (if Camp_Square and then Square_Outside then Square_Strip else [others => 0]);
   procedure Set_Square_Wide (On : Boolean) is
   begin
      Wide_On := On;
   end Set_Square_Wide;
   function Square_Wide return Boolean is (Wide_On);

   function Search_Reach return Float is (Float'Max (Work_Radius_M, Far_Reach));
   function Fell_Reach_M return Float is (Float'Max (Work_Radius_M, Wood_Reach));
   procedure Set_Wood_Reach (On : Boolean) is
   begin
      Wood_Far_On := On;
   end Set_Wood_Reach;
   function Wood_Reach_On return Boolean is (Wood_Far_On);
   function Food_Reach_M return Float is (Float'Max (Work_Radius_M, Food_Reach));
   function Haul_Reach_M return Float is (Float'Max (Work_Radius_M, Haul_Reach));
   --  A ring further for the gatherers (Food) or the porters: once all the
   --  ground this near is in and looked through.
   procedure Look_Further_For (Food : Boolean) is
      R : constant Float := (if Food then Food_Reach_M else Haul_Reach_M);
   begin
      if Wood_Far_On and then R < Fell_Reach_Max_M and then R <= Ground_In and then Looked_Through (R) then
         if Food then
            Food_Reach := Float'Min (Fell_Reach_Max_M, R + Reach_Step_M);
         else
            Haul_Reach := Float'Min (Fell_Reach_Max_M, R + Reach_Step_M);
         end if;
      end if;
   end Look_Further_For;
   procedure Set_Wood_From (Metres : Float) is
   begin
      Wood_From := Float'Max (0.0, Metres);
   end Set_Wood_From;
   function Trees_Left_Untried return Natural is
      N : Natural := 0;
   begin
      for K in 1 .. N_Trees loop
         if not Trees (K).Down and then Trees (K).No_Way_Till > Tick_N then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Trees_Left_Untried;
   function Looking_M return Float is (Far_Reach);
   procedure Set_Stone_From (Metres : Float) is
   begin
      Stone_From := Float'Max (0.0, Metres);
   end Set_Stone_From;
   --  How far from the stake the furthest stockpile or camp reaches (with
   --  the margin housing has), of those no further than the band's ground
   --  ever goes.  (Counted when asked: a few zones.)
   function Stores_Far return Float is
      D, F : Float := 0.0;
   begin
      for Z in 1 .. N_Zones loop
         if Zones (Z).Kind /= Habitation_Zone and then Zones (Z).N > 0 then
            F := 0.0;
            for X of Integer_Pair'(Zones (Z).Bx0, Zones (Z).Bx1 + 1) loop
               for Y of Integer_Pair'(Zones (Z).By0, Zones (Z).By1 + 1) loop
                  F := Float'Max (F, Flat_Dist ((Float (X) * 0.25, Float (Y) * 0.25, 0.0), Stake_At));
               end loop;
            end loop;
            if F + 4.0 <= Far_Reach_Max_M then
               D := Float'Max (D, F + 4.0);
            end if;
         end if;
      end loop;
      return D;
   end Stores_Far;

   --  (and as far as any housing reaches: people build there, and live there;
   --  and, since the colony reads its own ground and no other, as far as a
   --  stockpile or the camp: one zoned past the work radius was served only
   --  while the camera kept its ground loaded)
   --  (and as far as the foresters look for a tree)
   function Ground_Reach_M return Float is
     (Float'Max (Float'Max (Float'Max (Float'Max (Float'Max (Search_Reach, Path_Far), Housing_Far), Stores_Far),
                             Wood_Reach), Float'Max (Food_Reach, Haul_Reach)));

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
              and then not Indexed (SX + DX, SY + DY) and then Own_V (SX + DX, SY + DY) > 0
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

   --  A hollow in the ground (John, 2026-11-13: "instead of just filling
   --  the holes"; "fill in holes in the path when they are compacting the
   --  ground"): ground at one level, its block columns side by side, every
   --  one of them closed in on its four sides by ground higher than it or
   --  of the hollow (nothing lower beside it, nothing not known), no more
   --  than Hollow_Most columns.  A pit, a dent, a ditch closed at its ends.
   --  A step of a slope and the inside corner of one are of a terrace that
   --  goes on to lower ground: no hollow.  Fill_Hollows fills each, in a
   --  grid of the tops of a stretch of ground (-1: not known), to the
   --  lowest of the ground round it; Passes times over, so that a hollow in
   --  the bottom of a hollow is filled up to the rest of it, and that to
   --  the ground round it.
   type Top_Grid is array (Integer range <>, Integer range <>) of Integer;
   type Top_Row is array (1 .. 24) of Integer;     --  (the tops across a path, or along a span of it)

   procedure Fill_Hollows (Tops : in out Top_Grid; Passes : Positive := 2) is
      W     : constant Natural := Tops'Length (1) * Tops'Length (2);
      Seen  : array (Tops'Range (1), Tops'Range (2)) of Boolean;
      Qx, Qy : array (1 .. Natural'Max (1, W)) of Integer;
   begin
      for Pass in 1 .. Passes loop
         Seen := [others => [others => False]];
         for X in Tops'Range (1) loop
            for Y in Tops'Range (2) loop
               if Tops (X, Y) >= 0 and then not Seen (X, Y) then
                  declare
                     T      : constant Integer := Tops (X, Y);
                     N, At_Q : Natural := 1;
                     Closed : Boolean := True;
                     Rim    : Integer := Integer'Last;
                     procedure Look (Nx, Ny : Integer) is
                     begin
                        if Nx not in Tops'Range (1) or else Ny not in Tops'Range (2) or else Tops (Nx, Ny) < 0
                          or else Tops (Nx, Ny) < T
                        then
                           Closed := False;
                        elsif Tops (Nx, Ny) > T then
                           Rim := Integer'Min (Rim, Tops (Nx, Ny));
                        elsif not Seen (Nx, Ny) then
                           Seen (Nx, Ny) := True;
                           N := N + 1;
                           Qx (N) := Nx;
                           Qy (N) := Ny;
                        end if;
                     end Look;
                  begin
                     Seen (X, Y) := True;
                     Qx (1) := X;
                     Qy (1) := Y;
                     At_Q := 0;
                     while At_Q < N loop
                        At_Q := At_Q + 1;
                        Look (Qx (At_Q) - 1, Qy (At_Q));
                        Look (Qx (At_Q) + 1, Qy (At_Q));
                        Look (Qx (At_Q), Qy (At_Q) - 1);
                        Look (Qx (At_Q), Qy (At_Q) + 1);
                     end loop;
                     if Closed and then N <= Hollow_Most and then Rim /= Integer'Last then
                        for K in 1 .. N loop
                           Tops (Qx (K), Qy (K)) := Rim;
                        end loop;
                     end if;
                  end;
               end if;
            end loop;
         end loop;
      end loop;
   end Fill_Hollows;

   --  What grows over a column's top cut, whether it stands on it or is
   --  left over a hole dug under it (a plant is never left in the air).
   procedure Cut_Plants (X, Y, Top : Integer) is
   begin
      for Up in 1 .. 4 loop
         if Mat (X, Y, Top + Up) in Tall_Grass | Wild_Grain | Wild_Vegetables then
            Write_Src (X, Y, Top + Up, Air_Block);
         elsif Mat (X, Y, Top + Up) /= Air then
            exit;
         end if;
      end loop;
   end Cut_Plants;
   function Plants_Over (X, Y, Top : Integer) return Boolean is
   begin
      for Up in 1 .. 4 loop
         if Mat (X, Y, Top + Up) in Tall_Grass | Wild_Grain | Wild_Vegetables then
            return True;
         elsif Mat (X, Y, Top + Up) /= Air then
            return False;
         end if;
      end loop;
      return False;
   end Plants_Over;


   Path_Fail : constant := 31_300;      --  fail memos: no way to that metre of that stretch (to 32_699)

   Metre_Ground_On : Boolean := True;   --  (Set_Metre_Ground: a metre of path is gone to on the ground it lies on)
   function Path_Metres (S : Path_Seg) return Natural is (Natural (Float'Ceiling (Flat_Dist (S.A, S.B))));
   function All_Metres (S : Path_Seg) return Unsigned_64 is
     (if Path_Metres (S) >= 64 then Unsigned_64'Last else Shift_Left (Unsigned_64'(1), Path_Metres (S)) - 1);

   --  The ground a stretch lies on is in: every stack under it is the
   --  colony's own and loaded (what the band does goes by this); Held: is
   --  loaded, the colony's own or not (what the player plans is read from
   --  the ground that is held: the line shown, the count of a path marked).
   function Stretch_In (S : Path_Seg; Held : Boolean := False) return Boolean is
      Half : constant Float := Path_Width_M / 2.0;
   begin
      for CX in Integer (Float'Floor ((Float'Min (S.A.X, S.B.X) - Half) / 8.0))
        .. Integer (Float'Floor ((Float'Max (S.A.X, S.B.X) + Half) / 8.0))
      loop
         for CY in Integer (Float'Floor ((Float'Min (S.A.Y, S.B.Y) - Half) / 8.0))
           .. Integer (Float'Floor ((Float'Max (S.A.Y, S.B.Y) + Half) / 8.0))
         loop
            if CX in Indexed_Grid'Range (1) and then CY in Indexed_Grid'Range (2)
              and then (if Held then Version_Src (CX, CY) else Own_V (CX, CY)) = 0
            then
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


   --  Block column (X, Y) is still to be turned to footpath by some stretch (For_Path_Work would
   --  come to it).
   function Column_To_Lay (X, Y : Integer) return Boolean is
      Half : constant Float := Path_Width_M / 2.0;
      C    : constant Vec3 := ((Float (X) + 0.5) * 0.25, (Float (Y) + 0.5) * 0.25, 0.0);
   begin
      if N_Zones > 0 and then Zone_Of_Block (X, Y) /= 0 then
         return False;
      end if;
      for K in 1 .. N_Paths loop
         declare
            S : Path_Seg renames Path_List (K);
            L : constant Float := Flat_Dist (S.A, S.B);
         begin
            if L >= 0.25 and then Seg_Dist (C, S) <= Half then
               declare
                  T  : constant Float :=
                    Float'Max (0.0, Float'Min (1.0, ((C.X - S.A.X) * (S.B.X - S.A.X)
                                                      + (C.Y - S.A.Y) * (S.B.Y - S.A.Y)) / (L * L)));
                  Zr : constant Integer := Ground_Row (X, Y, B (S.A.Z + (S.B.Z - S.A.Z) * T));
               begin
                  if Zr >= 0 and then Mat (X, Y, Zr) in Grass | Dirt | Sand | Gravel | Clay | Placer_Gravel | Bog_Iron then
                     return True;
                  end if;
               end;
            end if;
         end;
      end loop;
      return False;
   end Column_To_Lay;

   --  The middle of metre Metre of a stretch, on the ground: where whoever
   --  lays it goes to.  (Under a bough that can be stood on there is more
   --  than one floor, and the first is the bough: the one nearest the
   --  stretch's own height is the ground the path lies on.  Gone to on the
   --  bough, three metres up a tree that stands beside a square and is not
   --  felled for it, the metre was never laid, and the square's wall, which
   --  waits for its path, had a gap a metre wide there.)
   function Metre_Middle (S : Path_Seg; Metre : Positive) return Vec3 is
      L : constant Float := Flat_Dist (S.A, S.B);
      D : constant Float := Float'Min (L, (Float (Metre - 1) + Float'Min (Float (Metre), L)) / 2.0);
      T : constant Float := (if L > 0.0 then D / L else 0.0);
      P : Vec3 := On_Ground (S.A.X + (S.B.X - S.A.X) * T, S.A.Y + (S.B.Y - S.A.Y) * T);
   begin
      if Metre_Ground_On and then S.A.Z >= 0.0 and then S.B.Z >= 0.0 then
         declare
            Want : constant Float := S.A.Z + (S.B.Z - S.A.Z) * T;
            Fl   : Castle.Nav.Floor_List;
            Fn   : Natural;
            Walked : Natural := 0;
            Best : Float := Float'Last;
            Best_Z : Float := P.Z;
         begin
            Castle.Nav.Floors_At (Integer (Float'Floor (P.X * 2.0)), Integer (Float'Floor (P.Y * 2.0)), Fn, Fl);
            for F in 1 .. Fn loop
               if Fl (F).Speed > 0.0 then
                  Walked := Walked + 1;
                  if abs (Float (Fl (F).Z) * 0.25 - Want) < Best then
                     Best := abs (Float (Fl (F).Z) * 0.25 - Want);
                     Best_Z := Float (Fl (F).Z) * 0.25;
                  end if;
               end if;
            end loop;
            --  (one floor there, as nearly everywhere: where it always was)
            if Walked > 1 and then abs (P.Z - Castle.Nav.Surface_Z (P.X, P.Y)) < 0.01 then
               P.Z := Best_Z;
            end if;
         end;
      end if;
      return P;
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

   --  A block column of the path round the square the colony was founded on
   --  (Part_Of: beyond its strips, where it has any), once its floor's level
   --  is chosen.
   function In_Square_Path (Bx, By : Integer) return Boolean is
     (Camp_Level >= 0 and then Part_Of (Geo_Now, Bx, By) = Part_Path);

   --  A tree stands on that square: any of its foot is on its floor, on a
   --  strip kept for a wall, or on the path round it.
   function Tree_On_Square (K : Positive) return Boolean is
   begin
      if not Camp_Square or else Camp_Zone_N = 0
        or else Flat_Dist (Tree_Base (K), Camp_At) > 2.0 * Square_Side_Now
      then
         return False;
      end if;
      declare
         G : constant Square_Geo := Geo_Now;
      begin
         for X in Trees (K).Info.Bx .. Trees (K).Info.Bx + Trees (K).Info.Trunk_W - 1 loop
            for Y in Trees (K).Info.By .. Trees (K).Info.By + Trees (K).Info.Trunk_W - 1 loop
               if Part_Of (G, X, Y) /= Part_None then
                  return True;
               end if;
            end loop;
         end loop;
      end;
      return False;
   end Tree_On_Square;

   --  A tree the square was founded round: it stands on its floor and its
   --  foot was left out of the square's ground (a square founded with
   --  Set_Square_Fell off, or before trees were felled for one).  No
   --  forester fells it, as none fells an apple tree: felled, its foot
   --  would leave a hole in a floor filled up round it, a block column or
   --  three across and as deep as the floor was filled, which a serf drops
   --  into and cannot climb out of.
   function Tree_Spared (K : Positive) return Boolean is
   begin
      if not Camp_Square or else Camp_Zone_N = 0
        or else Flat_Dist (Tree_Base (K), Camp_At) > 2.0 * Square_Side_Now
      then
         return False;
      end if;
      declare
         G : constant Square_Geo := Geo_Now;
      begin
         for X in Trees (K).Info.Bx .. Trees (K).Info.Bx + Trees (K).Info.Trunk_W - 1 loop
            for Y in Trees (K).Info.By .. Trees (K).Info.By + Trees (K).Info.Trunk_W - 1 loop
               if Part_Of (G, X, Y) = Part_Floor and then Zone_Of_Block (X, Y) /= Camp_Zone_N then
                  return True;
               end if;
            end loop;
         end loop;
      end;
      return False;
   end Tree_Spared;

   --  A tree felled on the square is taken out: what is left of it, its
   --  stump and its roots (a trunk is rooted two blocks into the ground,
   --  and felling leaves its first block standing), is earth, so that the
   --  ground where it stood is ground like the rest: the floor is made
   --  over it, the path is laid over it.
   procedure Stump_Out (K : Positive) is
      T : Tree_Rec renames Trees (K);
   begin
      for X in T.Info.Bx .. T.Info.Bx + T.Info.Trunk_W - 1 loop
         for Y in T.Info.By .. T.Info.By + T.Info.Trunk_W - 1 loop
            for Z in T.Info.Bz - 2 .. T.Info.Bz + 1 loop
               if Mat (X, Y, Z) in Trunk then
                  Write_Src (X, Y, Z, (if Z < T.Info.Bz then (Mat => Dirt, State => 0) else Air_Block));
               end if;
            end loop;
         end loop;
      end loop;
      Walls_Stale := True;      --  (the ground by the square may have moved)
   end Stump_Out;

   --  A tree stands in a stockpile that was put down whole, its foot the
   --  stockpile's ground (John, 2026-11-20: "fell the tree in the
   --  stockpile"): that zone (0: it stands in none; one put down before, or
   --  with Set_Box_Fell off, left its trees' feet out of its ground).
   function Tree_In_Box (K : Positive) return Natural is
      Z : Natural;
   begin
      if N_Zones = 0 then
         return 0;
      end if;
      for X in Trees (K).Info.Bx .. Trees (K).Info.Bx + Trees (K).Info.Trunk_W - 1 loop
         for Y in Trees (K).Info.By .. Trees (K).Info.By + Trees (K).Info.Trunk_W - 1 loop
            Z := Zone_Of_Block (X, Y);
            if Z /= 0 and then Zones (Z).Kind = Stockpile_Zone and then Zones (Z).Placed and then not Zones (Z).Yard then
               return Z;
            end if;
         end loop;
      end loop;
      return 0;
   end Tree_In_Box;

   --  What is left of a tree that was felled before such a stockpile was
   --  put down over it, by a forester at its work: its stump and its roots,
   --  which are taken out as a tree's are (found 2026-11-20: three days in,
   --  the nearest trees are stumps, and the places over them stayed closed
   --  for good).  (Any of them left: a stump dug away leaves the roots.)
   function Box_Stump (K : Positive) return Boolean is
     (Mat (Trees (K).Info.Bx, Trees (K).Info.By, Trees (K).Info.Bz + 1) not in Trunk
      and then (for some Z in Trees (K).Info.Bz - 2 .. Trees (K).Info.Bz =>
                  Mat (Trees (K).Info.Bx, Trees (K).Info.By, Z) in Trunk)
      and then Tree_In_Box (K) /= 0);

   --  How many such trees stand, or have left a stump (counted once a
   --  colony second at the most: it is asked by everyone who thinks, since
   --  one to take out is a reason to turn to the band's building).
   Box_Trees_N  : Natural := 0;
   Box_Trees_At : Natural := Natural'Last;
   function Box_Trees_Standing return Natural is
   begin
      if Tick_N < Box_Trees_At or else Tick_N - Box_Trees_At >= Tick_Hz then
         Box_Trees_At := Tick_N;
         Box_Trees_N := 0;
         declare
            --  (the block columns every such stockpile lies within: a tree outside them is not asked of)
            X0, Y0 : Integer := Integer'Last;
            X1, Y1 : Integer := Integer'First;
         begin
            for Z in 1 .. N_Zones loop
               if Zones (Z).Kind = Stockpile_Zone and then Zones (Z).Placed and then not Zones (Z).Yard then
                  X0 := Integer'Min (X0, Zones (Z).Bx0);
                  X1 := Integer'Max (X1, Zones (Z).Bx1);
                  Y0 := Integer'Min (Y0, Zones (Z).By0);
                  Y1 := Integer'Max (Y1, Zones (Z).By1);
               end if;
            end loop;
            if X0 <= X1 then
               for K in 1 .. N_Trees loop
                  if Trees (K).Info.Bx <= X1 and then Trees (K).Info.Bx + Trees (K).Info.Trunk_W > X0
                    and then Trees (K).Info.By <= Y1 and then Trees (K).Info.By + Trees (K).Info.Trunk_W > Y0
                    and then ((not Trees (K).Down
                               and then Mat (Trees (K).Info.Bx, Trees (K).Info.By, Trees (K).Info.Bz + 1) in Trunk
                               and then Tree_In_Box (K) /= 0)
                              or else Box_Stump (K))
                  then
                     Box_Trees_N := Box_Trees_N + 1;
                  end if;
               end loop;
            end if;
         end;
      end if;
      return Box_Trees_N;
   end Box_Trees_Standing;

   function Box_Trees_Left return Natural is
   begin
      Box_Trees_At := Natural'Last;          --  (asked from outside: counted now)
      return Box_Trees_Standing;
   end Box_Trees_Left;

   --  To the nearest of them that nobody else is at, to fell it.
   function Go_Fell_Box (I : Positive) return Boolean is
      M : Member renames Band (I);
   begin
      for Attempt in 1 .. 3 loop
         declare
            Best   : Natural := 0;
            Best_D : Float := Float'Last;
         begin
            for K in 1 .. N_Trees loop
               declare
                  T : Tree_Rec renames Trees (K);
               begin
                  if not T.Down and then Tree_In_Box (K) /= 0
                    and then Mat (T.Info.Bx, T.Info.By, T.Info.Bz + 1) not in Trunk
                  then
                     T.Down := True;                     --  gone since it was found
                  end if;
                  --  (one that stands, or the stump of one felled before the stockpile was put down)
                  if (if T.Down then Box_Stump (K) else Tree_In_Box (K) /= 0)
                    and then (T.Reserved_By = 0 or else T.Reserved_By = I) and then not Failed (M, Tree_Base_Id + K)
                    and then Flat_Dist (M.Pos, Tree_Base (K)) < Best_D
                  then
                     Best := K;
                     Best_D := Flat_Dist (M.Pos, Tree_Base (K));
                  end if;
               end;
            end loop;
            if Best = 0 then
               return False;
            end if;
            if Route_To (M, Tree_Base (Best), Half_W (Best) + 0.9) then
               Release (M, I);
               M.Tree := Best;
               Trees (Best).Reserved_By := I;
               M.State := To_Tree;
               return True;
            end if;
            Remember_Failure (M, Tree_Base_Id + Best);
         end;
      end loop;
      return False;
   end Go_Fell_Box;

   --  The square's trees still standing that are to be felled for it.
   function Square_Trees_Standing return Natural is
      N : Natural := 0;
   begin
      if not Camp_Square or else not Square_Fell_On then
         return 0;
      end if;
      for K in 1 .. N_Trees loop
         if not Trees (K).Down and then Tree_On_Square (K) and then not Tree_Spared (K)
           and then Mat (Trees (K).Info.Bx, Trees (K).Info.By, Trees (K).Info.Bz + 1) in Trunk
         then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Square_Trees_Standing;

   --  To the nearest of them that nobody else is at, to fell it (as a
   --  builder fells a stockyard's own: Go_Fell_Yard).  Standing: there is
   --  one still, whether or not it could be gone to.
   function Go_Fell_Square (I : Positive; Standing : out Boolean) return Boolean is
      M : Member renames Band (I);
   begin
      Standing := False;
      if not Camp_Square or else not Square_Fell_On then
         return False;
      end if;
      for Attempt in 1 .. 3 loop
         declare
            Best   : Natural := 0;
            Best_D : Float := Float'Last;
         begin
            for K in 1 .. N_Trees loop
               declare
                  T : Tree_Rec renames Trees (K);
               begin
                  if not T.Down and then Tree_On_Square (K) and then not Tree_Spared (K) then
                     if Mat (T.Info.Bx, T.Info.By, T.Info.Bz + 1) not in Trunk then
                        T.Down := True;                  --  gone since it was found
                     else
                        Standing := True;
                        if (T.Reserved_By = 0 or else T.Reserved_By = I) and then not Failed (M, Tree_Base_Id + K)
                          and then Flat_Dist (M.Pos, Tree_Base (K)) < Best_D
                        then
                           Best := K;
                           Best_D := Flat_Dist (M.Pos, Tree_Base (K));
                        end if;
                     end if;
                  end if;
               end;
            end loop;
            if Best = 0 then
               return False;
            end if;
            if Route_To (M, Tree_Base (Best), Half_W (Best) + 0.9) then
               Release (M, I);
               M.Tree := Best;
               Trees (Best).Reserved_By := I;
               M.State := To_Tree;
               return True;
            end if;
            Remember_Failure (M, Tree_Base_Id + Best);
         end;
      end loop;
      return False;
   end Go_Fell_Square;

   --  **The path round the square, cut as each side's own stretch is laid** (Lay_Metre's sections):
   --  a quarter metre of its length at a time from the end the stretch begins at.  A side's own
   --  stretch runs along its line, Off out from the square's middle, from the line of the path of
   --  the side it meets at its low end to that of the one at its high end (sides 1 and 2 run across
   --  the square's way, from side 4's to side 3's; sides 3 and 4 along it, from side 2's to side
   --  1's); From_High: it was laid out from its high end (where no stretch of that side's is
   --  found, the low end).  The one cut for whatever reads the path so: the tools' count
   --  (For_Square_Path_Slices) and the steps of stone (Plan_Walls).
   Path_Cut_Most : constant := 127;
   type Side_Floats is array (1 .. 4) of Float;
   type Side_Flags is array (1 .. 4) of Boolean;
   type Side_Counts is array (1 .. 4) of Natural;
   type Path_Cut is record
      Ok        : Boolean := False;
      Geo       : Square_Geo;
      Ex, Ey    : Float := 0.0;
      Off       : Side_Floats := [others => 0.0];
      From_High : Side_Flags := [others => False];
      Slices    : Side_Counts := [others => 0];
   end record;
   function Cut_Low_Of (Sd : Positive) return Positive is (if Sd <= 2 then 4 else 2);
   function Cut_High_Of (Sd : Positive) return Positive is (if Sd <= 2 then 3 else 1);
   function Cut_Now return Path_Cut is
      C : Path_Cut;
      Half : constant Float := Path_Width_M / 2.0;
      function Out_On (P : Vec3; Sd : Positive) return Float is
         Dx : constant Float := P.X - C.Geo.Mx;
         Dy : constant Float := P.Y - C.Geo.My;
         U  : constant Float := Dx * C.Ex + Dy * C.Ey;
         V  : constant Float := Dy * C.Ex - Dx * C.Ey;
      begin
         return (case Sd is when 1 => U, when 2 => -U, when 3 => V, when others => -V);
      end Out_On;
      function Along_Of (P : Vec3; Sd : Positive) return Float is
         Dx : constant Float := P.X - C.Geo.Mx;
         Dy : constant Float := P.Y - C.Geo.My;
      begin
         return (if Sd <= 2 then Dy * C.Ex - Dx * C.Ey else Dx * C.Ex + Dy * C.Ey);
      end Along_Of;
   begin
      C.Geo := Geo_Now;
      if not Camp_Square or else Camp_Level < 0 or else C.Geo.Half <= 0.0 then
         return C;
      end if;
      C.Ok := True;
      C.Ex := (if C.Geo.Aslant then 1.0 / Sqrt (2.0) else 1.0);
      C.Ey := (if C.Geo.Aslant then 1.0 / Sqrt (2.0) else 0.0);
      for Sd in 1 .. 4 loop
         C.Off (Sd) := C.Geo.Half + Float (C.Geo.Strip (Sd)) * Ring_Width (C.Geo) + Half;
      end loop;
      for Sd in 1 .. 4 loop
         C.Slices (Sd) :=
           Natural'Min (Path_Cut_Most + 1,
                        Integer (Float'Ceiling ((C.Off (Cut_Low_Of (Sd)) + C.Off (Cut_High_Of (Sd))) * 4.0)));
         for K in 1 .. N_Paths loop
            declare
               S : Path_Seg renames Path_List (K);
            begin
               if abs (Out_On (S.A, Sd) - C.Off (Sd)) < 0.01 and then abs (Out_On (S.B, Sd) - C.Off (Sd)) < 0.01
                 and then abs (Along_Of (S.A, Sd) - C.Off (Cut_High_Of (Sd))) < 0.05
                 and then abs (Along_Of (S.B, Sd) + C.Off (Cut_Low_Of (Sd))) < 0.05
               then
                  C.From_High (Sd) := True;
               end if;
            end;
         end loop;
      end loop;
      return C;
   end Cut_Now;
   --  The quarter metre of side Sd's path that block column (X, Y) is of (-1: it does not lie on that
   --  side's path's band, or beyond what is counted).  At a corner a column is of two sides'.
   function Slice_Of (C : Path_Cut; Sd : Positive; X, Y : Integer) return Integer is
      Dx : constant Float := (Float (X) + 0.5) * 0.25 - C.Geo.Mx;
      Dy : constant Float := (Float (Y) + 0.5) * 0.25 - C.Geo.My;
      U  : constant Float := Dx * C.Ex + Dy * C.Ey;
      V  : constant Float := Dy * C.Ex - Dx * C.Ey;
      Out_D : constant Float := (case Sd is when 1 => U, when 2 => -U, when 3 => V, when others => -V);
      Along : constant Float := (if Sd <= 2 then V else U);
   begin
      if not C.Ok or else abs (Out_D - C.Off (Sd)) > Path_Width_M / 2.0 then
         return -1;
      end if;
      declare
         --  (a quarter metre at a time from the end the stretch begins at, which is its high end where
         --  the stretch runs that way)
         Sc : constant Integer :=
           (if C.From_High (Sd) then Integer (Float'Floor ((C.Off (Cut_High_Of (Sd)) - Along) * 4.0))
            else Integer (Float'Floor ((Along + C.Off (Cut_Low_Of (Sd))) * 4.0)));
      begin
         return (if Sc in 0 .. Path_Cut_Most then Sc else -1);
      end;
   end Slice_Of;
   --  The square metre in which two sides' paths cross that block column (X, Y) is of: every column
   --  of the square's path that lies on the band of one of sides 1 and 2 and on that of one of sides
   --  3 and 4, whatever stretch reaches it (1 to 4; 0: none).
   function Cross_Of (C : Path_Cut; X, Y : Integer) return Natural is
      Dx : constant Float := (Float (X) + 0.5) * 0.25 - C.Geo.Mx;
      Dy : constant Float := (Float (Y) + 0.5) * 0.25 - C.Geo.My;
      U  : constant Float := Dx * C.Ex + Dy * C.Ey;
      V  : constant Float := Dy * C.Ex - Dx * C.Ey;
      Half : constant Float := Path_Width_M / 2.0;
      A  : constant Natural := (if abs (U - C.Off (1)) <= Half then 1 elsif abs (-U - C.Off (2)) <= Half then 2 else 0);
      B  : constant Natural := (if abs (V - C.Off (3)) <= Half then 3 elsif abs (-V - C.Off (4)) <= Half then 4 else 0);
   begin
      return (if C.Ok and then A > 0 and then B > 0 and then Part_Of (C.Geo, X, Y) = Part_Path
              then (A - 1) * 2 + B - 2 else 0);
   end Cross_Of;

   procedure Settle_Piles;        --  (its body is with the camp's floor, below)

   --  Paths meet (the spec, "A path is stepped where it meets trodden
   --  ground"): round the block columns X0 .. X1, Y0 .. Y1 just laid, as
   --  far as Meet_Reach_B, no column of a path lies two blocks or more off
   --  the trodden ground beside it where a block moved makes it one.  Near:
   --  a row near their tops.
   Meet_On   : Boolean := True;
   Meet_N    : Natural := 0;
   procedure Set_Paths_Meet (On : Boolean) is
   begin
      Meet_On := On;
   end Set_Paths_Meet;
   function Paths_Meet return Boolean is (Meet_On);
   function Path_Columns_Stepped return Natural is (Meet_N);

   procedure Step_Seams (X0, Y0, X1, Y1, Near : Integer) is
      Ax : constant Integer := X0 - Meet_Reach_B;
      Ay : constant Integer := Y0 - Meet_Reach_B;
      W  : constant Integer := X1 - X0 + 2 * Meet_Reach_B;
      H  : constant Integer := Y1 - Y0 + 2 * Meet_Reach_B;
      --  (indexed from 0: this compiler reads a two-dimensional array with negative bounds wrongly)
      type Grid is array (0 .. W, 0 .. H) of Integer;
      Top   : Grid := [others => [others => -1]];      --  the top of its trodden ground (-1: none)
      Moved : Grid := [others => [others => 0]];       --  blocks it has been moved now: cut off (under 0) or put under
      Geo   : constant Square_Geo := Geo_Now;
      --  (what is never moved: the square's own path and the strips kept for its walls, and any
      --  zone's ground: a floor, a door's way)
      function Held (X, Y : Integer) return Boolean is
        (Zone_Of_Block (X, Y) /= 0
         or else (Camp_Level >= 0 and then Part_Of (Geo, X, Y) /= Part_None));
      function T (I, J : Integer) return Integer is (if I in 0 .. W and then J in 0 .. H then Top (I, J) else -1);
      Changed : Boolean;
   begin
      for I in 0 .. W loop
         for J in 0 .. H loop
            declare
               Z : constant Integer := Ground_Row (Ax + I, Ay + J, Near);
            begin
               if Z >= 0 and then abs (Z - Near) <= 12 and then Mat (Ax + I, Ay + J, Z) = Footpath then
                  Top (I, J) := Z;
               end if;
            end;
         end loop;
      end loop;
      for Pass in 1 .. 2 * Meet_Most_B + 2 loop
         Changed := False;
         --  (never a column at the edge of what was read: what lies beside it out there is not seen,
         --  and a block moved there could put it further off that than it was)
         for I in 1 .. W - 1 loop
            for J in 1 .. H - 1 loop
               if Top (I, J) >= 0 and then abs Moved (I, J) < Meet_Most_B and then not Held (Ax + I, Ay + J) then
                  declare
                     X  : constant Integer := Ax + I;
                     Y  : constant Integer := Ay + J;
                     Z  : constant Integer := Top (I, J);
                     Hi : Integer := Integer'First;                --  the highest trodden beside it,
                     Hi_Firm : Integer := Integer'First;           --  of those never moved, or raised just now,
                     Lo : Integer := Integer'Last;                 --  and the lowest
                     procedure Look (Ni, Nj : Integer) is
                        N : constant Integer := T (Ni, Nj);
                     begin
                        if N >= 0 then
                           Hi := Integer'Max (Hi, N);
                           Lo := Integer'Min (Lo, N);
                           if Held (Ax + Ni, Ay + Nj) or else Moved (Ni, Nj) > 0 then
                              Hi_Firm := Integer'Max (Hi_Firm, N);
                           end if;
                        end if;
                     end Look;
                  begin
                     Look (I - 1, J);
                     Look (I + 1, J);
                     Look (I, J - 1);
                     Look (I, J + 1);
                     if Lo /= Integer'Last and then Z - Lo >= 2 and then Hi - Z < 2 and then Moved (I, J) <= 0 then
                        --  it stands two blocks over trodden ground beside it: a block cut off it
                        Write_Src (X, Y, Z, Air_Block);
                        Write_Src (X, Y, Z - 1, (Mat => Footpath, State => 0));
                        Top (I, J) := Z - 1;
                        Moved (I, J) := Moved (I, J) - 1;
                        Meet_N := Meet_N + 1;
                        Changed := True;
                     elsif Hi_Firm /= Integer'First and then Hi_Firm - Z >= 2 and then Moved (I, J) >= 0
                       and then Class_Of (Mat (X, Y, Z + 1)) not in Solid | Liquid
                       and then Class_Of (Mat (X, Y, Z + 2)) not in Solid | Liquid
                     then
                        --  it lies two blocks under ground that is never moved, or under a column raised to
                        --  such ground just now: a block of earth under it (one two blocks under a path
                        --  that can be cut is left: that one comes down; and one raised is not cut again,
                        --  nor one cut raised)
                        Cut_Plants (X, Y, Z);
                        Write_Src (X, Y, Z, (Mat => Dirt, State => 0));
                        Write_Src (X, Y, Z + 1, (Mat => Footpath, State => 0));
                        Top (I, J) := Z + 1;
                        Moved (I, J) := Moved (I, J) + 1;
                        Meet_N := Meet_N + 1;
                        Changed := True;
                     end if;
                  end;
               end if;
            end loop;
         end loop;
         exit when not Changed;
      end loop;
   end Step_Seams;

   --  Metre Metre of stretch K laid: what grows on it cut, the top of the
   --  ground turned to footpath, all of it at once.
   procedure Lay_Metre (K : Positive; Metre : Positive) is
      --  (the 64th stands for whatever lies beyond it, in a stretch of before there were pieces)
      function This_Metre (M : Integer) return Boolean is (M = Metre or else (Metre = 64 and then M > 64));
      R : constant := Hollow_Reach_B;
      X0, Y0 : Integer := Integer'Last;
      X1, Y1 : Integer := Integer'First;
      Near   : Integer := -1;
      procedure Bound (X, Y, Zr, M : Integer) is
      begin
         if This_Metre (M) then
            X0 := Integer'Min (X0, X);
            X1 := Integer'Max (X1, X);
            Y0 := Integer'Min (Y0, Y);
            Y1 := Integer'Max (Y1, Y);
            Near := (if Near < 0 then Zr else Near);
         end if;
      end Bound;
   begin
      if Holes_On or else Path_Level_On then
         For_Path_Work (Path_List (K), Bound'Access);
      end if;
      declare
         Any : constant Boolean := (Holes_On or else Path_Level_On) and then X0 <= X1;
         --  the ground round the metre, its hollows filled (Fill_Hollows): what each column is laid at
         G : Top_Grid ((if Any then X0 - R else 1) .. (if Any then X1 + R else 0),
                       (if Any then Y0 - R else 1) .. (if Any then Y1 + R else 0));
         Raw : Top_Grid (G'Range (1), G'Range (2));
         --  (a column is raised only where the ground read round the metre is its own top: read from
         --  another height it could be a bough or a hump; and never by more than Hollow_Rise_B)
         --  The path's own line (Path_Level_On): the height of each quarter metre along the stretch
         --  (the middle one of its columns' tops across the path's width, hollows filled), and that
         --  smoothed along it (the middle one of the Path_Level_Span_B before and behind): a slope
         --  keeps its steps, a bump or a dent shorter than the span is gone.  -1: nothing known there.
         S    : Path_Seg renames Path_List (K);
         Len  : constant Float := Flat_Dist (S.A, S.B);
         Half : constant Float := Path_Width_M / 2.0;
         Last_Sec : constant Integer := Integer (Float'Ceiling (Len * 4.0)) + 1;
         Sec, Line : array (0 .. Last_Sec) of Integer := [others => -1];
         --  Of a square whose walls stand outside its floor (the spec, "A special zone's area is kept
         --  whole"): this stretch is the square's own path along side Own_Side (0: it is not, or that
         --  side has no strip), Strip_M of strip between it and the floor.  A slice of it is brought
         --  to the floor's level strip and all, or not at all: where the path lies level with the
         --  floor the strip between them is laid level with both, as path (it is that much wider
         --  there); where it does not the strip is left for the wall (Plan_Walls).
         Geo : constant Square_Geo := Geo_Now;
         function Side_Of_Stretch return Natural is
            Ex : constant Float := (if Geo.Aslant then 1.0 / Sqrt (2.0) else 1.0);
            Ey : constant Float := (if Geo.Aslant then 1.0 / Sqrt (2.0) else 0.0);
            function Out_On (P : Vec3; Sd : Positive) return Float is
               Dx : constant Float := P.X - Geo.Mx;
               Dy : constant Float := P.Y - Geo.My;
               U  : constant Float := Dx * Ex + Dy * Ey;
               V  : constant Float := Dy * Ex - Dx * Ey;
            begin
               return (case Sd is when 1 => U, when 2 => -U, when 3 => V, when others => -V);
            end Out_On;
         begin
            if Geo.Half <= 0.0 or else not Walls_On or else Camp_Level < 0 then
               return 0;
            end if;
            for Sd in 1 .. 4 loop
               if Geo.Strip (Sd) > 0 then
                  declare
                     D : constant Float := Geo.Half + Float (Geo.Strip (Sd)) * Ring_Width (Geo) + Path_Width_M / 2.0;
                  begin
                     if abs (Out_On (S.A, Sd) - D) < 0.01 and then abs (Out_On (S.B, Sd) - D) < 0.01 then
                        return Sd;
                     end if;
                  end;
               end if;
            end loop;
            return 0;
         end Side_Of_Stretch;
         Own_Side : constant Natural := Side_Of_Stretch;
         Strip_M  : constant Float := (if Own_Side > 0 then Float (Geo.Strip (Own_Side)) * Ring_Width (Geo) else 0.0);
         function On_Strip (X, Y : Integer) return Boolean is
           (Own_Side > 0
            and then Seg_Dist (((Float (X) + 0.5) * 0.25, (Float (Y) + 0.5) * 0.25, 0.0), S) <= Half + Strip_M + 0.001
            and then Part_Of (Geo, X, Y) = Part_Strip);
         function Section (X, Y : Integer) return Integer is
            C : constant Vec3 := ((Float (X) + 0.5) * 0.25, (Float (Y) + 0.5) * 0.25, 0.0);
            T : constant Float :=
              Float'Max (0.0, Float'Min (1.0, ((C.X - S.A.X) * (S.B.X - S.A.X)
                                                + (C.Y - S.A.Y) * (S.B.Y - S.A.Y)) / (Len * Len)));
         begin
            return Integer'Min (Last_Sec, Integer (Float'Floor (T * Len * 4.0)));
         end Section;
         function Middle_Of (V : in out Top_Row; N : Natural) return Integer is
         begin
            if N = 0 then
               return -1;
            end if;
            for I in 2 .. N loop                          --  (a few: sorted in place)
               declare
                  X : constant Integer := V (I);
                  J : Natural := I - 1;
               begin
                  while J >= 1 and then V (J) > X loop
                     V (J + 1) := V (J);
                     J := J - 1;
                  end loop;
                  V (J + 1) := X;
               end;
            end loop;
            return V ((N + 1) / 2);
         end Middle_Of;
         procedure Read_Line is
            Tops : array (0 .. Last_Sec) of Top_Row;
            N    : array (0 .. Last_Sec) of Natural := [others => 0];
         begin
            for Gx in G'Range (1) loop
               for Gy in G'Range (2) loop
                  if G (Gx, Gy) >= 0
                    and then Seg_Dist (((Float (Gx) + 0.5) * 0.25, (Float (Gy) + 0.5) * 0.25, 0.0), S) <= Half
                    and then (N_Zones = 0 or else Zone_Of_Block (Gx, Gy) = 0)
                  then
                     declare
                        Sc : constant Integer := Section (Gx, Gy);
                     begin
                        if N (Sc) < Top_Row'Last then
                           N (Sc) := N (Sc) + 1;
                           Tops (Sc) (N (Sc)) := G (Gx, Gy);
                        end if;
                     end;
                  end if;
               end loop;
            end loop;
            for Sc in Sec'Range loop
               Sec (Sc) := Middle_Of (Tops (Sc), N (Sc));
            end loop;
            for Sc in Line'Range loop
               declare
                  V  : Top_Row;
                  Vn : Natural := 0;
               begin
                  for D in -Path_Level_Span_B .. Path_Level_Span_B loop
                     if Sc + D in Sec'Range and then Sec (Sc + D) >= 0 then
                        Vn := Vn + 1;
                        V (Vn) := Sec (Sc + D);
                     end if;
                  end loop;
                  --  (at an end of what is known the span is one-sided, and would pull a slope's last
                  --  steps level: there the section's own height stands)
                  Line (Sc) := (if Vn = 2 * Path_Level_Span_B + 1 then Middle_Of (V, Vn) else Sec (Sc));
               end;
            end loop;
         end Read_Line;
         --  Round the square the colony was founded on, with its banks walled (Walls_On): a slice of
         --  its path, the block columns across its width at one quarter metre along it, is brought to
         --  the floor's level whole or not at all, so that the bank stands at the floor's edge, where
         --  its wall is built, and never along the middle of the path (brought to it column by
         --  column, as it first was, a bank three blocks high ran through the path's width for half
         --  the length of a side).  Whole: every column of the slice lies within Path_Level_B of it.
         Slice_Off : array (0 .. Last_Sec) of Boolean := [others => False];
         procedure Read_Slices is
         begin
            for Gx in G'Range (1) loop
               for Gy in G'Range (2) loop
                  if ((Seg_Dist (((Float (Gx) + 0.5) * 0.25, (Float (Gy) + 0.5) * 0.25, 0.0), S) <= Half
                       and then In_Square_Path (Gx, Gy))
                      or else On_Strip (Gx, Gy))
                    and then (G (Gx, Gy) < 0 or else abs (Camp_Level - G (Gx, Gy)) > Path_Level_B)
                  then
                     Slice_Off (Section (Gx, Gy)) := True;
                  end if;
               end loop;
            end loop;
         end Read_Slices;
         --  **The square metre where two sides' paths cross is laid as one** (Corner_On; the spec, "The
         --  corners of the square's path"): all of it, whichever stretch's columns they are and the
         --  few at its outer corner that no stretch reaches, when the first metre that has a column
         --  of it is laid; brought to the floor's level whole, where every column of it lies within
         --  Path_Level_B of that level, and else left whole as its ground lies, each column at its
         --  own top.  By its own columns alone, read as they lie then: so it is the same square
         --  metre whichever side's metre comes first.  (Laid a quarter metre of each side's at a
         --  time, as the rest of the path is, a column of it was level or not by whichever side
         --  reached it first: 41 quarter metres at 26 of 323 squares stood otherwise with their
         --  paths laid last metre first.)  Only of a square whose walls stand outside its floor.
         Corner_Here : constant Boolean :=
           Corner_On and then Camp_Square and then Square_Outside and then Walls_On and then Camp_Level >= 0
           and then Path_Level_On;
         Cut  : constant Path_Cut := (if Corner_Here then Cut_Now else (others => <>));
         Hit  : array (1 .. 4) of Boolean := [others => False];
         --  (the columns of a crossing that this metre's stretch finds to lay, each with the top it
         --  found: every one of them is laid, whatever the crossing's own reading of it says, or its
         --  metre would be counted as still to lay for ever and somebody sent to it again and again)
         Seen_Most : constant := 96;
         Seen_X, Seen_Y, Seen_Z : array (1 .. Seen_Most) of Integer := [others => 0];
         Seen_N : Natural := 0;
         procedure Lay_Crossing (Cn : Positive) is
            Reach : constant Integer := Integer (Float'Ceiling ((Cut.Geo.Half + 3.0) * 4.0 * (if Cut.Geo.Aslant then 1.5 else 1.0)));
            Bx0 : constant Integer := B (Cut.Geo.Mx);
            By0 : constant Integer := B (Cut.Geo.My);
            Whole : Boolean := True;
            --  (its top as the crossing reads it: near the floor's level, the ground's own; -1: none
            --  read, which leaves the crossing as it lies)
            function Top_Of (X, Y : Integer) return Integer is
               Z : constant Integer := Ground_Row (X, Y, Camp_Level);
            begin
               return (if Z >= 0
                         and then Mat (X, Y, Z) in Grass | Dirt | Sand | Gravel | Clay | Placer_Gravel | Bog_Iron | Footpath
                       then Z else -1);
            end Top_Of;
            --  (and as this metre's stretch found it, where the crossing read none: ground more than
            --  two metres over the floor's level is out of that reading's reach)
            function Top_To_Lay (X, Y : Integer) return Integer is
               Z : constant Integer := Top_Of (X, Y);
            begin
               if Z >= 0 then
                  return Z;
               end if;
               for K in 1 .. Seen_N loop
                  if Seen_X (K) = X and then Seen_Y (K) = Y then
                     return Seen_Z (K);
                  end if;
               end loop;
               return -1;
            end Top_To_Lay;
         begin
            for X in Bx0 - Reach .. Bx0 + Reach loop
               for Y in By0 - Reach .. By0 + Reach loop
                  if Cross_Of (Cut, X, Y) = Cn then
                     declare
                        Z : constant Integer := Top_Of (X, Y);
                     begin
                        if Z < 0 or else abs (Camp_Level - Z) > Path_Level_B
                          or else (N_Zones > 0 and then Zone_Of_Block (X, Y) /= 0)
                          or else (for some R in Z + 1 .. Integer'Max (Camp_Level, Z + 1) => Class_Of (Mat (X, Y, R)) = Liquid)
                        then
                           Whole := False;
                        end if;
                     end;
                  end if;
               end loop;
            end loop;
            for X in Bx0 - Reach .. Bx0 + Reach loop
               for Y in By0 - Reach .. By0 + Reach loop
                  if Cross_Of (Cut, X, Y) = Cn and then (N_Zones = 0 or else Zone_Of_Block (X, Y) = 0) then
                     declare
                        Z   : constant Integer := Top_To_Lay (X, Y);
                        Top : constant Integer := (if Whole then Camp_Level else Z);
                     begin
                        if Z >= 0 and then Mat (X, Y, Z) /= Footpath then
                           Cut_Plants (X, Y, Z);
                           if Top > Z then
                              Cut_Plants (X, Y, Top);
                           end if;
                           for R in Z .. Top - 1 loop
                              Write_Src (X, Y, R, (Mat => Dirt, State => 0));
                           end loop;
                           for R in Top + 1 .. Z loop
                              Write_Src (X, Y, R, Air_Block);
                           end loop;
                           Write_Src (X, Y, Top, (Mat => Footpath, State => 0));
                        end if;
                     end;
                  end if;
               end loop;
            end loop;
         end Lay_Crossing;
         procedure Turn (X, Y, Zr, M : Integer) is
            Own    : constant Boolean := Any and then X in G'Range (1) and then Y in G'Range (2) and then Raw (X, Y) = Zr;
            Filled : constant Integer := (if Own and then G (X, Y) - Zr in 1 .. Hollow_Rise_B then G (X, Y) else Zr);
            --  (round the square the colony was founded on, the square's level: its path lies level
            --  with its floor where the ground is within reach of that)
            Want   : constant Integer :=
              (if not (Own and then Path_Level_On) then -1
               elsif In_Square_Path (X, Y) or else On_Strip (X, Y)
               then (if Walls_On and then Slice_Off (Section (X, Y)) then -1 else Camp_Level)
               else Line (Section (X, Y)));
            --  (brought to the path's line where that is within Path_Level_B of it: further off it is
            --  a bank or a ditch the path goes over as it did)
            Top    : constant Integer :=
              (if Want >= 0 and then abs (Want - Filled) <= Path_Level_B
                 and then (for all Z in Zr + 1 .. Integer'Max (Want, Zr + 1) => Class_Of (Mat (X, Y, Z)) /= Liquid)
               then Want else Filled);        --  (never through water: a ditch that holds any is left as it lies)
         begin
            if This_Metre (M) and then Corner_Here and then Cross_Of (Cut, X, Y) > 0 and then Seen_N < Seen_Most then
               Hit (Cross_Of (Cut, X, Y)) := True;       --  (laid with the whole of its crossing, below)
               Seen_N := Seen_N + 1;
               Seen_X (Seen_N) := X;
               Seen_Y (Seen_N) := Y;
               Seen_Z (Seen_N) := Zr;
            elsif This_Metre (M) then
               Cut_Plants (X, Y, Zr);                    --  what grows on it cut (filled: over what it is filled to too)
               if Top > Zr then
                  Cut_Plants (X, Y, Top);
               end if;
               for Z in Zr .. Top - 1 loop               --  a hole filled with earth
                  Write_Src (X, Y, Z, (Mat => Dirt, State => 0));
               end loop;
               for Z in Top + 1 .. Zr loop               --  a bump cut down
                  Write_Src (X, Y, Z, Air_Block);
               end loop;
               Write_Src (X, Y, Top, (Mat => Footpath, State => 0));
            end if;
         end Turn;
      begin
         if Any then
            for Gx in G'Range (1) loop
               for Gy in G'Range (2) loop
                  declare
                     Z : constant Integer := Ground_Row (Gx, Gy, Near);
                  begin
                     --  (only the ground's own top: under a bough or a log what was read is not known)
                     G (Gx, Gy) := (if Z >= 0 and then abs (Z - Near) <= 8
                                      and then Mat (Gx, Gy, Z) in Grass | Dirt | Sand | Gravel | Clay | Placer_Gravel
                                                                | Bog_Iron | Footpath
                                    then Z else -1);
                  end;
               end loop;
            end loop;
            Raw := G;
            if Holes_On then
               Fill_Hollows (G);
            end if;
            if Path_Level_On and then Len >= 0.25 then
               Read_Line;
               if Camp_Square and then Walls_On and then Camp_Level >= 0 then
                  Read_Slices;
               end if;
            end if;
         end if;
         For_Path_Work (Path_List (K), Turn'Access);
         for Cn in Hit'Range loop
            if Hit (Cn) then
               Lay_Crossing (Cn);
            end if;
         end loop;
         --  (and the strip beside this metre, where its slice is brought level: laid with it)
         if Own_Side > 0 and then Any and then Path_Level_On then
            for Gx in G'Range (1) loop
               for Gy in G'Range (2) loop
                  if On_Strip (Gx, Gy) and then Raw (Gx, Gy) >= 0 and then not Slice_Off (Section (Gx, Gy))
                    and then Zone_Of_Block (Gx, Gy) = 0
                  then
                     Turn (Gx, Gy, Raw (Gx, Gy), Integer'Min (Path_Metres (S), Section (Gx, Gy) / 4 + 1));
                  end if;
               end loop;
            end loop;
         end if;
      end;
      if Meet_On and then X0 <= X1 and then Near >= 0 then
         Step_Seams (X0, Y0, X1, Y1, Near);
      end if;
      Path_List (K).Todo := Path_List (K).Todo and not Shift_Left (Unsigned_64'(1), Integer'Min (63, Metre - 1));
      Count_Paths;
      if Camp_Square then
         Settle_Piles;             --  (logs lying on the square's path lie on it as it is laid)
         Walls_Stale := True;      --  (and a wall may be planned against it now)
      end if;
   end Lay_Metre;

   procedure For_Square_Path_Slices
     (Visit : not null access procedure (Side : Positive; Slice, Slices : Natural; Columns : Positive;
                                         Lowest, Middle, Highest : Integer; Stone : Natural))
   is
      Cut  : constant Path_Cut := Cut_Now;
      Most : constant := Path_Cut_Most;
      type Slice_Tops is array (0 .. Most) of Top_Row;
      type Slice_Ns is array (0 .. Most) of Natural;
      Tops : array (1 .. 4) of Slice_Tops;
      N    : array (1 .. 4) of Slice_Ns := [others => [others => 0]];
      Stones : array (1 .. 4) of Slice_Ns := [others => [others => 0]];
      Reach : constant Integer := Integer (Float'Ceiling ((Cut.Geo.Half + 3.0) * 4.0 * (if Cut.Geo.Aslant then 1.5 else 1.0)));
      X0 : constant Integer := B (Cut.Geo.Mx);
      Y0 : constant Integer := B (Cut.Geo.My);
   begin
      if not Cut.Ok then
         return;
      end if;
      for X in X0 - Reach .. X0 + Reach loop
         for Y in Y0 - Reach .. Y0 + Reach loop
            if In_Square_Path (X, Y) then
               declare
                  Z : constant Integer := Ground_Row (X, Y, Camp_Level);
               begin
                  for Sd in 1 .. 4 loop
                     declare
                        Sc : constant Integer := Slice_Of (Cut, Sd, X, Y);
                     begin
                        if Z >= 0 and then Sc >= 0 and then N (Sd) (Sc) < Top_Row'Last then
                           N (Sd) (Sc) := N (Sd) (Sc) + 1;
                           Tops (Sd) (Sc) (N (Sd) (Sc)) := Z - Camp_Level;
                           if Mat (X, Y, Z) = Fieldstone then
                              Stones (Sd) (Sc) := Stones (Sd) (Sc) + 1;
                           end if;
                        end if;
                     end;
                  end loop;
               end;
            end if;
         end loop;
      end loop;
      for Sd in 1 .. 4 loop
         for Sc in 0 .. Most loop
            if N (Sd) (Sc) > 0 then
               for I in 2 .. N (Sd) (Sc) loop                  --  (a few: sorted in place)
                  declare
                     T : constant Integer := Tops (Sd) (Sc) (I);
                     J : Natural := I - 1;
                  begin
                     while J >= 1 and then Tops (Sd) (Sc) (J) > T loop
                        Tops (Sd) (Sc) (J + 1) := Tops (Sd) (Sc) (J);
                        J := J - 1;
                     end loop;
                     Tops (Sd) (Sc) (J + 1) := T;
                  end;
               end loop;
               Visit (Sd, Sc, Cut.Slices (Sd), N (Sd) (Sc), Tops (Sd) (Sc) (1), Tops (Sd) (Sc) ((N (Sd) (Sc) + 1) / 2),
                      Tops (Sd) (Sc) (N (Sd) (Sc)), Stones (Sd) (Sc));
            end if;
         end loop;
      end loop;
   end For_Square_Path_Slices;

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

   procedure Build_Paths_Now (Backward : Boolean := False; Most : Natural := Natural'Last) is
      Done : Natural := 0;
   begin
      for Kn in 1 .. N_Paths loop
         declare
            K : constant Positive := (if Backward then N_Paths + 1 - Kn else Kn);
         begin
            Refresh_Path (K);
            if Path_List (K).Known then
               for Mn in 1 .. Path_Metres (Path_List (K)) loop
                  declare
                     Metre : constant Positive := (if Backward then Path_Metres (Path_List (K)) + 1 - Mn else Mn);
                  begin
                     if Path_Todo (K, Metre) and then Done < Most then
                        Lay_Metre (K, Metre);
                        Done := Done + 1;
                     end if;
                  end;
               end loop;
            end if;
         end;
      end loop;
      Count_Paths;
   end Build_Paths_Now;

   ------------------------------------------------------------------ the camp: building it

   --  The camp's ground is made ready a square metre at a time: patches,
   --  numbered by where they lie from the fire, as the camp lies.
   Max_Patch  : constant := 4 * Patch_Span * Patch_Span;
   Patch_Span_Was : constant := 6;                     --  (a camp's, and the first square's: Patch_Of)
   Patch_Fail : constant := 31_100;                    --  a fail memo: no way to that patch
   Hollow_Fail : constant := 31_099;                   --  a fail memo: earth in hand and no hollow it could get to

   function Patch_Of (Bx, By : Integer) return Natural is
      Dx : constant Float := (Float (Bx) + 0.5) * 0.25 - Camp_At.X;
      Dy : constant Float := (Float (By) + 0.5) * 0.25 - Camp_At.Y;
      C  : constant Float := Cos (Camp_Turn);
      S  : constant Float := Sin (Camp_Turn);
      --  (On the wider square, eleven metres of floor, the square metres are counted from its edges:
      --  the fire stands in the middle of the middle one, John's "so the campfire is in the center",
      --  and none is cut in half at an edge.  On a camp, and on the square of ten metres, the fire
      --  stands where four of them meet, as it did.)
      Wide : constant Boolean := Camp_Square and then Square_Is_Wide;
      Mid  : constant Float := (if Wide then 0.5 else 0.0);
      --  (and they reach Patch_Span metres each way; on a camp and on the square of ten metres
      --  Patch_Span_Was, numbered as they always were: a member's patch is saved by its number)
      Span : constant Integer := (if Wide then Patch_Span else Patch_Span_Was);
      I  : constant Integer := Integer (Float'Floor (Dx * C + Dy * S + Mid)) + Span;
      J  : constant Integer := Integer (Float'Floor (Dy * C - Dx * S + Mid)) + Span;
   begin
      return (if I in 0 .. 2 * Span - 1 and then J in 0 .. 2 * Span - 1 then I * 2 * Span + J + 1 else 0);
   end Patch_Of;

   --  (the patch a column of the square's walls, strips and path is worked with: Patch_Of's, and of a
   --  column past the last of them the nearest's.  The square metres reach Patch_Span from the fire
   --  less half a metre to the east and the north, and a walled side's path lies to 6.75 m: left
   --  with no patch, a step of the path there was counted as wanted and never gone to.)
   function Patch_Near (Bx, By : Integer) return Natural is
      Dx : constant Float := (Float (Bx) + 0.5) * 0.25 - Camp_At.X;
      Dy : constant Float := (Float (By) + 0.5) * 0.25 - Camp_At.Y;
      C  : constant Float := Cos (Camp_Turn);
      S  : constant Float := Sin (Camp_Turn);
      Wide : constant Boolean := Camp_Square and then Square_Is_Wide;
      Mid  : constant Float := (if Wide then 0.5 else 0.0);
      Span : constant Integer := (if Wide then Patch_Span else Patch_Span_Was);
      I  : constant Integer := Integer (Float'Floor (Dx * C + Dy * S + Mid)) + Span;
      J  : constant Integer := Integer (Float'Floor (Dy * C - Dx * S + Mid)) + Span;
   begin
      return (if I in -2 .. 2 * Span + 1 and then J in -2 .. 2 * Span + 1
              then Integer'Max (0, Integer'Min (2 * Span - 1, I)) * 2 * Span
                   + Integer'Max (0, Integer'Min (2 * Span - 1, J)) + 1
              else 0);
   end Patch_Near;

   procedure Measure_Zone (Z : Positive);                         --  (its body is with the zones, below)
   procedure Remove_House (H : Positive);                         --  (and its with the housing's zoning)
   function Free_Stock (K : Item_Kind) return Natural;            --  (and its with the camp's own)

   --  The camp's floor: its ground within Hearth_Ground_M of the fire.  It
   --  is made level, at Camp_Level (the row of its top; -1: left as it
   --  lies), and trodden to bare earth.
   --  (Of the square the colony was founded on, all of it: asked only of
   --  the camp's own ground.)
   function Near_Fire (Bx, By : Integer) return Boolean is
     (Camp_Square
      or else Flat_Dist (((Float (Bx) + 0.5) * 0.25, (Float (By) + 0.5) * 0.25, 0.0), Camp_At) <= Hearth_Ground_M);

   --  A tree's foot stands on that column of the square's floor (its top at
   --  row Zr): nothing is dug or filled there until the tree is felled and
   --  taken out.
   function Foot_On (Bx, By, Zr : Integer) return Boolean is (Camp_Square and then Mat (Bx, By, Zr + 1) in Trunk);

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

   --  The level a floor of the strips List is brought to: the highest at
   --  which what is dug off, with the turf cut off the rest, is at least
   --  what the hollows take, so that the earth for them is always there
   --  (-1: no floor).  All_Floor: every column of them is floor; else those
   --  by the fire.  With_Feet: of all of them, the ground under a tree's
   --  foot counted too, as Choose_Level counts it when a square is founded
   --  (the level a square's plan must judge its walls' strips against).
   function Level_For (List : Run_List; All_Floor : Boolean; With_Feet : Boolean := False) return Integer is
      Lo : Integer := Integer'Last;
      Hi : Integer := Integer'First;
      function Of_Floor (X, Y : Integer) return Boolean is (All_Floor or else Near_Fire (X, Y));
      --  (a column a tree's foot stands on, of a square's floor: its ground is read under its roots, and
      --  it is made level once the tree is out: not counted)
      function Under_Foot (X : Integer; R : Run_Rec) return Boolean is
        (All_Floor and then not With_Feet and then Mat (X, Integer (R.Y), Integer (R.Z) + 1) in Trunk);
   begin
      for R of List loop
         for X in Integer (R.X0) .. Integer (R.X1) loop
            if Of_Floor (X, Integer (R.Y)) and then not Under_Foot (X, R) then
               Lo := Integer'Min (Lo, Integer (R.Z));
               Hi := Integer'Max (Hi, Integer (R.Z));
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
            for R of List loop
               for X in Integer (R.X0) .. Integer (R.X1) loop
                  if Of_Floor (X, Integer (R.Y)) and then not Under_Foot (X, R) then
                     Cut := Cut + Cut_In (X, Integer (R.Y), Integer (R.Z), Level);
                     Fill := Fill + Fill_In (Integer (R.Z), Level);
                     if Integer (R.Z) <= Level and then Mat (X, Integer (R.Y), Integer (R.Z)) = Grass then
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
   end Level_For;

   --  The level the camp's floor is brought to (-1: no floor, or its ground
   --  is not in).
   function Choose_Level return Integer is
     (if Camp_Zone_N = 0 then -1
      else Level_For (Run_List (Runs (Zones (Camp_Zone_N).First + 1 .. Zones (Camp_Zone_N).First + Zones (Camp_Zone_N).N)),
                      All_Floor => False));

   ------------------------------------------------------------------ housing: where a house stands

   package CB renames Castle.Buildings;
   use type CB.Stage;

   Site_Fail       : constant := 20_000;   --  fail memos: no way to work at that house (to 20_048),
   Site_Patch_Fail : constant := 20_100;   --  and no way to that patch of its ground (to 21_234)
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
   --  (A storehouse's lot is its stockyard.)
   function Is_Store (F : CB.House) return Boolean is (CB."=" (F.Kind, CB.Storehouse));
   function Lot_Left (F : CB.House) return Integer is
     (if Is_Store (F) then -F.Yard_U0 else (CB.Lot_B - F.W) / 2);
   function Lot_Right (F : CB.House) return Integer is
     (if Is_Store (F) then F.Yard_U1 - (F.W - 1) else CB.Lot_B - F.W - Lot_Left (F));
   --  The bank round its pad keeps within its lot to either side; before
   --  its front wall it is Apron_Front_B wide, behind its back wall Apron_B.
   function Apron_U (F : CB.House) return Integer is (Integer'Min (CB.Apron_B, Lot_Left (F)));
   --  The stockyard levelled, same as houses (John, 2026-11-17: "level the
   --  stockyard, same as houses"): a storehouse's ground is all its yard,
   --  from its staging to the back fence, at its floor's level, walled where
   --  the land beside it stands over or under (Set_Yard_Level; off: the
   --  storehouse's own pad and the bank round it, its yard as it lies).
   Yard_Level_On : Boolean := True;
   procedure Set_Yard_Level (On : Boolean) is
   begin
      Yard_Level_On := On;
   end Set_Yard_Level;
   function Yard_Level return Boolean is (Yard_Level_On);
   function Yard_Site (F : CB.House) return Boolean is (Is_Store (F) and then Yard_Level_On);
   --  (and whether the stores move into the stockyard when its storehouse stands: Go_Move_In)
   Move_On : Boolean := False;       --  (off since 2026-11-19: a stockpile stays open beside the stockyard)
   procedure Set_Stores_Move (On : Boolean) is
   begin
      Move_On := On;
   end Set_Stores_Move;
   function Stores_Move return Boolean is (Move_On);
   function Stores_Moved return Boolean is
     (Move_On and then Store_House in 1 .. N_Houses and then Houses (Store_House).Built);
   --  How far its ground reaches past its left wall and its right
   function Apron_L (F : CB.House) return Integer is (if Yard_Site (F) then -F.Yard_U0 else Apron_U (F));
   function Apron_R (F : CB.House) return Integer is
     (if Yard_Site (F) then F.Yard_U1 - (F.W - 1) else Apron_U (F));
   V_Lo : constant := -CB.Apron_Front_B;
   function V_Hi (F : CB.House) return Integer is (if Yard_Site (F) then F.Yard_V1 else F.D - 1 + CB.Apron_B);
   --  How far back its lot reaches (its bank's end, if that is further).
   function Lot_Back (F : CB.House) return Integer is
     (if Is_Store (F) then Integer'Max (F.Yard_V1, V_Hi (F)) else Integer'Max (CB.Lot_B + V_Lo - 1, V_Hi (F)));
   --  The way in from its path: the columns of its front that the way out
   --  from a hovel's door runs along; a storehouse's doors are in its ends,
   --  and its way is the middle of its front, across its staging.
   --  (On the columns of two patches of its ground: Store_Way_U is two more than a multiple of four,
   --  as Site_Patch_At counts them, so that a patch is all of the way or none of it: its stair is dug
   --  by itself, never with the floor beside it.)
   --  (18 for a storehouse of 10 m; a metre on for each two metres it is longer, so that the way
   --  stays about its middle)
   function Store_Way_U (F : CB.House) return Integer is (18 + 4 * (Integer'Max (0, F.W - CB.Store_W_B) / 8));
   --  (the middle of its front: a hovel's door; of a storehouse the two metres where its stockyard's
   --  way in is unless that is at an end of the front: what stands before its front goes by this)
   function Mid_Lo (F : CB.House) return Integer is
     (if Is_Store (F) then Store_Way_U (F) else F.Openings (1).Offset);
   function Mid_Hi (F : CB.House) return Integer is
     (if Is_Store (F) then Store_Way_U (F) + CB.Store_Door_W_B - 1
      else F.Openings (1).Offset + F.Openings (1).Width - 1);
   --  **A stockyard's stair stands in a corner of the zone** (the spec, "The stockyard's stair in a
   --  corner of the zone"; F.Way_End, chosen when the storehouse is begun: Choose_Way_End).  Its way
   --  in is then two metres at an end of its front, a block column in from its side's rim (so that
   --  the rim, walled or not, is the stair's outer flank), and not across the staging at the middle
   --  of the storehouse's front.  End_Way_U: the first of those columns at that end, in its design.
   --  (Whole patches of its ground, as the middle's are: Yard_U0 is the last block column of a place,
   --  one more than a multiple of four, and Patch_Of counts a yard whose way is at its high end from
   --  that end.)
   function End_Way_U (F : CB.House; Way_End : Positive) return Integer is
     (if Way_End = 1 then F.Yard_U0 + 1 else F.Yard_U1 - CB.Store_Door_W_B);
   function At_End (F : CB.House) return Boolean is (Is_Store (F) and then F.Way_End > 0);
   function Way_Lo (F : CB.House) return Integer is
     (if At_End (F) then End_Way_U (F, F.Way_End) else Mid_Lo (F));
   function Way_Hi (F : CB.House) return Integer is
     (if At_End (F) then End_Way_U (F, F.Way_End) + CB.Store_Door_W_B - 1 else Mid_Hi (F));
   --  How far out from a front wall a way to the path, or a front yard, is looked for
   function Front_Most (F : CB.House) return Natural is
     (if Is_Store (F) then 60 else CB.Max_Push_B + CB.Setback_Max_B + 6);

   --  A house as it is drawn turned (Castle.Buildings.Back_Turn; the turn is
   --  about the middle of its doorway in the line of its front wall's middle:
   --  Doorway_At's foot and half its width).
   subtype Frame_Box is CB.Frame_Box;
   function Under_Drawn (F : CB.House; U, V : Float; Margin : Float) return Boolean is
     (CB.Under_Drawn (F, U, V, Margin));
   function Drawn_Box (F : CB.House; Margin : Float) return Frame_Box is (CB.Drawn_Box (F, Margin));
   --  (the middle of block (U, V) of its frame, where it is drawn)
   function Drawn_Point (F : CB.House; U, V : Float) return Vec3 is
      Au, Av : Float;
   begin
      CB.Fore_Turn (F, U, V, Au, Av);
      return H_Point (F, Au, Av);
   end Drawn_Point;

   --  **A storehouse drawn turned has its yard laid out for real along its
   --  path** (Castle.Buildings.Yard_Turned; John, 2026-11-20: "go on with
   --  the second way for the stockyard").  Its own blocks stand in its frame
   --  as ever; its yard, its ground, its lot, its gateways, its coverings
   --  and its places are **designed** in that frame as a square stockyard's
   --  are, and made where the turn puts them.  So of such a house there are
   --  two things to say of a place: the block column of its frame (U, V),
   --  where blocks are; and the place of its design that column is made as
   --  (D_U, D_V).  Of every other house the two are one.
   --    * What is said of a block column of a site (In_Site, Level_Of,
   --      In_Door_Way, Is_Stair, Plan_Of, Work_In, its patch) takes the
   --      frame's column and looks its design up.
   --    * What the design says in so many blocks (Yard_U0 .., Front, the
   --      way in, a gateway, a place's fitting) is of the design.
   --    * Y_Point: where a place of the design is in the world.
   function Yard_Turned (F : CB.House) return Boolean is (CB.Yard_Turned (F));
   function D_U (F : CB.House; U, V : Integer) return Integer is
      Du, Dv : Integer;
   begin
      CB.Design_Of (F, U, V, Du, Dv);
      return Du;
   end D_U;
   function D_V (F : CB.House; U, V : Integer) return Integer is
      Du, Dv : Integer;
   begin
      CB.Design_Of (F, U, V, Du, Dv);
      return Dv;
   end D_V;
   function Y_Point (F : CB.House; U, V : Float) return Vec3 is
     (if Yard_Turned (F) then Drawn_Point (F, U, V) else H_Point (F, U, V));
   --  (the block column a place of the design is made at: one of them, for a line or a spot of
   --  it; a piece of ground is gone over column by column of the frame instead)
   function Y_X (F : CB.House; U, V : Integer) return Integer is
     (if Yard_Turned (F) then B (Drawn_Point (F, Float (U), Float (V)).X) else H_X (F, U, V));
   function Y_Y (F : CB.House; U, V : Integer) return Integer is
     (if Yard_Turned (F) then B (Drawn_Point (F, Float (U), Float (V)).Y) else H_Y (F, U, V));

   --  How many blocks the path's ground may lie above or below a house's
   --  pad for its door to be got to: a block where the path is hard by, a
   --  block for each column of the way past its landing otherwise.
   --  A stockyard's floor lies within Yard_Step_B (2 m, a house's fall) of
   --  its path where its way in meets it, however long the way; and its
   --  ground is dug down the stair from the path and then outward over the
   --  floor from the stair's foot (Go_Level), so that what is dug always
   --  has its way out.  (Found 2026-11-18: dug by rows from the path, as a
   --  hovel's shallow yard is, the far corner of a stockyard's staging was
   --  dug first, 2 m under a path aslant up a hillside, and its builder
   --  starved in it.)
   Yard_Step_B : constant := 8;
   Yard_Fall_B : constant := 12;          --  a stockyard's ground may fall 3 m from end to end, no more
   function Door_Steps (F : CB.House) return Natural is
     (if Is_Store (F) then Integer'Min (Yard_Step_B, Integer'Max (1, F.Door_Run - CB.Door_Landing_B))
      else Integer'Max (1, F.Door_Run - CB.Door_Landing_B));

   --  The ground a house's builder makes ready, its site: under its walls,
   --  a yard round them (Apron_B behind and to either side, as far as its
   --  lot is; before its front wall all the way to its path: Front), the way
   --  out from its door among it.  All of it is brought to the level of its
   --  floor but the door's way where that is a stair, and the walls that
   --  hold it (below).
   --  To either side it reaches further where a house begun before it
   --  stands beside it, as far as that one's ground (John, 2026-11-12: "Yes
   --  extend as one and they, don't need to be extended as a straight line
   --  they can meet and turn into each other, just take the difference
   --  between the two"): Reach_L, Reach_R (Join_Site sets them).
   function Front_Of (F : CB.House; U : Integer) return Integer is
     (if U in F.Front'Range then Integer'Max (CB.Apron_Front_B, F.Front (U)) else CB.Apron_Front_B);

   --  A column of the way out from a house's door to its path: straight
   --  out from the doorway, each of its columns as far as the path's edge
   --  (beside a path that runs aslant they are not all as long: Door_Run is
   --  the shortest, and the stair is made over that; what the longer ones
   --  have past it lies at the level of the stair's foot, not a stub of the
   --  yard's wall across it).
   --  **A way at an end of a stockyard's front** (At_End) has its stair from the path's edge
   --  inward, a block a step, as many steps as there are blocks between the path and the floor
   --  there (End_Steps; none within Retain_Over_B), and a landing of Door_Landing_B columns at its
   --  foot.  Beside the storehouse's end there is no wall across it, so a flight longer than the
   --  staging is deep runs on past the line of the front wall.
   function End_Steps (F : CB.House) return Natural is
     (if abs (F.Door_Row - (F.Pad - 1)) > Retain_Over_B then abs (F.Door_Row - (F.Pad - 1)) else 0);
   function In_Door_Way_D (F : CB.House; U, V : Integer) return Boolean is
     (F.Door_Run > 0
      and then U in Way_Lo (F) .. Way_Hi (F)
      and then -V <= Integer'Max (F.Door_Run, Front_Of (F, U))
      and then (if At_End (F) then V < Integer'Max (0, End_Steps (F) + CB.Door_Landing_B - F.Door_Run) else V < 0));
   function In_Door_Way (F : CB.House; U, V : Integer) return Boolean is
     (if Yard_Turned (F) then In_Door_Way_D (F, D_U (F, U, V), D_V (F, U, V)) else In_Door_Way_D (F, U, V));
   --  **A hovel drawn turned has its ground made where it is drawn too**
   --  (F.Turn_Ground, fixed when it is placed: Set_Turn_Ground): the block
   --  columns under it as drawn, and Turn_Apron_B round them, are of its
   --  site with the square ground it stands on (levelled to its pad, cleared,
   --  walled where the land beside stands over or under), and of its lot.
   --  Site_U_Lo .. Site_U_Hi and Site_V_Lo .. Site_V_Hi are then the box
   --  all of it lies in, not its shape: In_Site says which columns.
   Turn_Apron_B : constant := CB.Apron_B;
   function Under_Turn (F : CB.House; U, V : Integer; Margin : Integer := Turn_Apron_B) return Boolean is
     (F.Turn_Ground and then Under_Drawn (F, Float (U), Float (V), Float (Margin)));
   --  (how far before its front wall its ground reaches at the most, in its design)
   function Front_Deepest (F : CB.House) return Integer is
      M : Integer := CB.Apron_Front_B;
   begin
      for U in -Apron_L (F) - F.Reach_L .. F.W - 1 + Apron_R (F) + F.Reach_R loop
         M := Integer'Max (M, Front_Of (F, U));
      end loop;
      return M;
   end Front_Deepest;
   --  (a storehouse's drawn turned: the columns of its frame all its ground, as it is made, lies within)
   function Design_Box (F : CB.House; U0, U1, V0, V1 : Float) return Frame_Box is
      Lo_U, Lo_V : Float := Float'Last;
      Hi_U, Hi_V : Float := Float'First;
      procedure Corner (U, V : Float) is
         Au, Av : Float;
      begin
         CB.Fore_Turn (F, U, V, Au, Av);
         Lo_U := Float'Min (Lo_U, Au);  Hi_U := Float'Max (Hi_U, Au);
         Lo_V := Float'Min (Lo_V, Av);  Hi_V := Float'Max (Hi_V, Av);
      end Corner;
   begin
      Corner (U0, V0);
      Corner (U1, V0);
      Corner (U1, V1);
      Corner (U0, V1);
      return (U0 => Integer (Float'Floor (Lo_U)), U1 => Integer (Float'Ceiling (Hi_U)),
              V0 => Integer (Float'Floor (Lo_V)), V1 => Integer (Float'Ceiling (Hi_V)));
   end Design_Box;
   function Yard_Box (F : CB.House) return Frame_Box is
     (Design_Box (F, Float (-Apron_L (F)) - 0.5, Float (F.W - 1 + Apron_R (F)) + 0.5,
                  Float (-Front_Deepest (F)) - 0.5, Float (V_Hi (F)) + 0.5));
   function Site_U_Lo (F : CB.House) return Integer is
     (if Yard_Turned (F) then Yard_Box (F).U0
      elsif F.Turn_Ground then Integer'Min (-Apron_L (F) - F.Reach_L, Drawn_Box (F, Float (Turn_Apron_B)).U0)
      else -Apron_L (F) - F.Reach_L);
   function Site_U_Hi (F : CB.House) return Integer is
     (if Yard_Turned (F) then Yard_Box (F).U1
      elsif F.Turn_Ground then Integer'Max (F.W - 1 + Apron_R (F) + F.Reach_R, Drawn_Box (F, Float (Turn_Apron_B)).U1)
      else F.W - 1 + Apron_R (F) + F.Reach_R);
   function Site_V_Lo (F : CB.House) return Integer is
     (if Yard_Turned (F) then Yard_Box (F).V0
      elsif F.Turn_Ground then Integer'Min (-Front_Deepest (F), Drawn_Box (F, Float (Turn_Apron_B)).V0)
      else -Front_Deepest (F));
   function Site_V_Hi (F : CB.House) return Integer is
     (if Yard_Turned (F) then Yard_Box (F).V1
      elsif F.Turn_Ground then Integer'Max (V_Hi (F), Drawn_Box (F, Float (Turn_Apron_B)).V1) else V_Hi (F));
   function In_Site_D (F : CB.House; U, V : Integer) return Boolean is
     (U in -Apron_L (F) - F.Reach_L .. F.W - 1 + Apron_R (F) + F.Reach_R
      and then V <= V_Hi (F) and then V >= -Front_Of (F, U));
   function In_Site (F : CB.House; U, V : Integer) return Boolean is
     (if Yard_Turned (F) then In_Site_D (F, D_U (F, U, V), D_V (F, U, V))
      else In_Site_D (F, U, V) or else Under_Turn (F, U, V));

   --  A column of its door's way that is a step of its stair.  There is a
   --  stair only where the path's ground lies more than a block above or
   --  below its floor (Retain_Over_B, as for a wall): a single block is a
   --  step like any other of the land's, left as earth (John, 2026-11-12,
   --  of a patch of stone before a door: "the stairs were added when the
   --  pathway was pretty much already leavel witht he house path").
   function Is_Stair_D (F : CB.House; U, V : Integer) return Boolean is
     (In_Door_Way_D (F, U, V)
      and then (if At_End (F) then V < End_Steps (F) - F.Door_Run
                else -V > CB.Door_Landing_B or else -V > F.Door_Run)
      and then abs (F.Door_Row - (F.Pad - 1)) > Retain_Over_B);
   function Is_Stair (F : CB.House; U, V : Integer) return Boolean is
     (if Yard_Turned (F) then Is_Stair_D (F, D_U (F, U, V), D_V (F, U, V)) else Is_Stair_D (F, U, V));

   --  The row the top of the ground at (U, V) of a house's site is brought
   --  to, before any wall: its floor's, but on the way out from its door,
   --  past a landing at that level, a stair between it and the ground where
   --  that way meets the path (a block to a block at most: Place_House sees
   --  to it, by Door_Steps).
   function Level_Of_D (F : CB.House; U, V : Integer) return Integer is
      Pad : constant Integer := F.Pad - 1;
   begin
      return (if not In_Door_Way_D (F, U, V) then Pad
              elsif -V > F.Door_Run then F.Door_Row            --  (past the stair's foot, beside a path aslant)
              elsif At_End (F)                                 --  (so many columns in from the path's edge: a block a step)
              then (if V + F.Door_Run >= End_Steps (F) then Pad
                    elsif F.Door_Row > Pad then F.Door_Row - (V + F.Door_Run)
                    else F.Door_Row + (V + F.Door_Run))
              elsif -V > CB.Door_Landing_B
              then Pad + (F.Door_Row - Pad) * (-V - CB.Door_Landing_B) / (F.Door_Run - CB.Door_Landing_B)
              else Pad);
   end Level_Of_D;
   function Level_Of (F : CB.House; U, V : Integer) return Integer is
     (if Yard_Turned (F) then Level_Of_D (F, D_U (F, U, V), D_V (F, U, V)) else Level_Of_D (F, U, V));

   --  What counts as ground beside a site: earth, rock, a path, a wall of
   --  stones; not a tree, and nothing of a house.
   function Is_Ground (M : Material) return Boolean is
     (Class_Of (M) = Solid and then M not in Trunk | Thatch | Daub | Plank | Shingle);

   --  The top of the ground at a block column, found from row Near: up it
   --  while there is ground over ground, else down to the first there is
   --  (-1: none within 6 m).  (An eave or a bough over it is not its top.)
   function Top_By (X, Y, Near : Integer) return Integer is
      Z : Integer := Near;
   begin
      if Is_Ground (Mat (X, Y, Z)) then
         while Z < Near + 24 and then Is_Ground (Mat (X, Y, Z + 1)) loop
            Z := Z + 1;
         end loop;
         return Z;
      end if;
      for Down in 1 .. 24 loop
         if Is_Ground (Mat (X, Y, Near - Down)) then
            return Near - Down;
         end if;
      end loop;
      return -1;
   end Top_By;


   --  What a column of a house's site is made (John, 2026-11-12: "the .25m
   --  next to the path will be reserved for a retaining wall built from
   --  stone in the stockpile, stairs built on the path from stone as it
   --  rises or falls to the door, dirt around the back of a blueprint is dug
   --  away and a retaining wall is built ... same with houses that step
   --  down, retaining walls built between them ... if its over .25m").  Top:
   --  the row its top is brought to.  Stone: the lowest row of it that is
   --  of stone (Top + 1: none of it is).
   --    * Where the ground beside the site stands more than Retain_Over_B
   --      over the column's level, the column is a wall against it: stone
   --      from the level up, its top flush with that ground.  (So the earth
   --      behind a house is dug away to the wall, and what is beyond stays.)
   --    * Where the column's level stands that much over what is beside it
   --      (lower ground outside, the path, a lower step of its own stair),
   --      it is a wall holding the site up: stone from there to its top.
   --    * A step of the door's stair has a tread of stone.
   --  Each house walls its own site, as it finds the ground beside it (the
   --  site is read from the world each time).  **Between two sites there is
   --  one wall, and it is the earlier house's**: where a column of a site
   --  has the site of a house begun after it beside it, it is planned
   --  against that site's level (not against the ground as it lies), and
   --  the later house plans nothing against the earlier one's.  So a house
   --  begun beside another, its ground reaching to the other's, shares one
   --  wall with it where their floors are more than a block apart, and
   --  none where they are not; behind them the two back walls meet, and
   --  where one house is deeper than the other the deeper one's side wall
   --  is the turn between them.
   type Column_Plan is record
      Top   : Integer := 0;
      Stone : Integer := 1;
   end record;

   --  The house, other than But, whose site block column (Bx, By) is of (0: none).
   function Site_Of_Block (Bx, By : Integer; But : Natural) return Natural is
   begin
      for K in 1 .. N_Houses loop
         if K /= But and then In_Site (Houses (K).F, H_U (Houses (K).F, Bx, By), H_V (Houses (K).F, Bx, By)) then
            return K;
         end if;
      end loop;
      return 0;
   end Site_Of_Block;

   function Plan_Of (H : Positive; U, V : Integer) return Column_Plan is
      F   : CB.House renames Houses (H).F;
      Lvl : constant Integer := Level_Of (F, U, V);
      Hi  : Integer := Lvl;       --  the highest ground beside it, outside the site
      Lo  : Integer := Lvl;       --  the lowest level beside it, inside the site or out
      procedure Beside (Nu, Nv : Integer) is
      begin
         if In_Site (F, Nu, Nv) then
            Lo := Integer'Min (Lo, Level_Of (F, Nu, Nv));
         else
            declare
               X : constant Integer := H_X (F, Nu, Nv);
               Y : constant Integer := H_Y (F, Nu, Nv);
               K : constant Natural := (if N_Houses > 1 then Site_Of_Block (X, Y, But => H) else 0);
            begin
               if K > H then
                  --  (a later house's site: its level there, as it will be)
                  declare
                     L : constant Integer := Level_Of (Houses (K).F, H_U (Houses (K).F, X, Y), H_V (Houses (K).F, X, Y));
                  begin
                     Hi := Integer'Max (Hi, L);
                     Lo := Integer'Min (Lo, L);
                  end;
               elsif K = 0 then
                  declare
                     G : constant Integer := Top_By (X, Y, F.Pad - 1);
                  begin
                     if G >= 0 then
                        Hi := Integer'Max (Hi, G);
                        Lo := Integer'Min (Lo, G);
                     end if;
                  end;
               end if;                      --  (an earlier house's site: the wall between them is that one's)
            end;
         end if;
      end Beside;
   begin
      Beside (U + 1, V);
      Beside (U - 1, V);
      Beside (U, V + 1);
      Beside (U, V - 1);
      if Hi - Lvl > Retain_Over_B and then not In_Door_Way (F, U, V) then
         return (Top => Hi, Stone => Lvl + 1);
      elsif Lvl - Lo > Retain_Over_B then
         return (Top => Lvl, Stone => Lo + 1);
      elsif Is_Stair (F, U, V) then
         return (Top => Lvl, Stone => Lvl);
      else
         return (Top => Lvl, Stone => Lvl + 1);
      end if;
   end Plan_Of;

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
         --  (one drawn turned on ground made for it: where it is drawn too, so that nothing
         --  grows back under its floor as it is drawn)
         if Houses (H).F.Turn_Ground and then Bz >= Houses (H).F.Pad - 1
           and then Under_Turn (Houses (H).F, H_U (Houses (H).F, Bx, By), H_V (Houses (H).F, Bx, By), Margin => 1)
         then
            return True;
         end if;
         if CB.Yard_Turned (Houses (H).F) and then Bz >= Houses (H).F.Pad - 1
           and then CB.Under_Drawn (Houses (H).F, Float (H_U (Houses (H).F, Bx, By)), Float (H_V (Houses (H).F, Bx, By)), 1.0)
         then
            return True;
         end if;
      end loop;
      return False;
   end In_A_House;

   --  Builders help at a larger house (the spec, under "Most_Builders").
   Help_On : Boolean := True;
   procedure Set_Build_Help (On : Boolean) is
   begin
      Help_On := On;
   end Set_Build_Help;
   function Build_Help return Boolean is (Help_On);
   function Builders_At (H : Positive) return Natural is
      N : Natural := 0;
   begin
      for J in 1 .. N_Members loop
         if not Band (J).Is_Dead and then Band (J).Site = H then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Builders_At;
   function Helping (I : Positive) return Boolean is
     (I in 1 .. N_Members and then not Band (I).Is_Dead and then Band (I).Site in 1 .. N_Houses
      and then (for some J in 1 .. I - 1 => not Band (J).Is_Dead and then Band (J).Site = Band (I).Site));

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
   --  (of a hovel walked where it is drawn: where that place of it is drawn, and the way into it as drawn)
   function Bed_Place (H : Positive) return Vec3 is
     (if Houses (H).F.Walk
      then Drawn_Point (Houses (H).F, Float (Bed_In_B), Float (Houses (H).F.D - 1 - Bed_In_B))
      else H_Point (Houses (H).F, Float (Bed_In_B), Float (Houses (H).F.D - 1 - Bed_In_B)));
   function House_Inward (H : Positive) return Vec3 is
      F : CB.House renames Houses (H).F;
      D : constant Vec3 := Drawn_Point (F, 0.0, 1.0) - Drawn_Point (F, 0.0, 0.0);
   begin
      return (if F.Walk then (D.X * 4.0, D.Y * 4.0, 0.0) else (Float (F.Vx), Float (F.Vy), 0.0));
   end House_Inward;

   function At_Home (I : Positive) return Boolean is
     (N_Houses > 0 and then not Band (I).Is_Dead and then Housed (I)
      and then Flat_Dist (Band (I).Pos, Bed_Place (Home_Of (I))) <= Home_M);

   function Site_Of (I : Positive) return Natural is
     (if Band (I).Is_Dead or else Band (I).Job /= Forester then 0 else Band (I).Site);
   function Trade_Of (I : Positive) return Trade_Kind is
     (if Site_Of (I) > 0 then Builder
      elsif Is_Keeper (I) then As_Stockman
      elsif Is_Carpenter (I) then As_Carpenter
      else No_Trade);

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
                  Row : constant Integer :=
                    (if Pad >= 0 then Pad
                     elsif N_Houses > 0 and then Under_Eaves (X, Integer (R.Y)) then Integer (R.Z)
                     else Ground_Row (X, Integer (R.Y), Integer (R.Z)));
                  --  (a stockpile made one level: its ground may lie further from where it lay than
                  --  Ground_Row looks, 2 m up and 4 m down: then by Top_By, 6 m either way)
                  Top : constant Integer :=
                    (if Row < 0 and then Pad < 0 and then Flat_On and then Zones (Z0).Kind = Stockpile_Zone
                       and then not Zones (Z0).Yard
                     then Top_By (X, Integer (R.Y), Integer (R.Z)) else Row);
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
      or else (Near_Fire (Bx, By) and then not Foot_On (Bx, By, Zr)
               and then (if Camp_Level >= 0 and then Zr > Camp_Level then Is_Earth (Mat (Bx, By, Zr))
                         else Mat (Bx, By, Zr) = Grass)));
   function Wants_Earth (Bx, By, Zr : Integer) return Boolean is
     (Camp_Level >= 0 and then Zr < Camp_Level and then Near_Fire (Bx, By) and then not Foot_On (Bx, By, Zr));

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
            if Near_Fire (X, Integer (Runs (K).Y)) and then not Foot_On (X, Integer (Runs (K).Y), Integer (Runs (K).Z)) then
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

   --  Where something at P stands or lies once the ground by it has moved:
   --  on the walking map's floor there (Surface, the highest two of its
   --  cell's four block columns), as ever; but, on a square whose banks are
   --  walled, where the ground of its own block column lies more than a
   --  step off that, on that ground.  (At the foot of a wall or of a bank
   --  the cell's floor is the wall's top: set there, one standing in the
   --  quarter metre below was, to the colony, on top of the wall, a metre
   --  and a half over its own feet, and set out from there; drawn, it walked
   --  into the wall.  On ground that steps no more than half a metre the two
   --  are one level to the walking map, and nothing is changed.)
   function Own_Ground (P : Vec3; Surface : Float) return Float is
   begin
      if not (Camp_Square and then Walls_On) or else Surface < 0.0 then
         return Surface;
      end if;
      declare
         G : constant Integer := Top_By (B (P.X), B (P.Y), Integer'Max (1, B (P.Z + 0.05) - 1));
         Z : constant Float := Float (G + 1) * 0.25;
      begin
         --  (and on a tread of stone of the square's path, the tread: the walking map has not seen the
         --  bout that cut it yet, and its floor there is where the path stood; one standing on a
         --  quarter metre cut two blocks down to a step was "settled" half a metre over it)
         return (if G >= 0
                   and then (abs (Z - Surface) > Float (Castle.Nav.Climb_B) * 0.25 + 0.01
                             or else (Steps_On and then Mat (B (P.X), B (P.Y), G) = Fieldstone
                                      and then In_Square_Path (B (P.X), B (P.Y))))
                 then Z else Surface);
      end;
   end Own_Ground;

   --  The logs of a tree felled on the square the colony was founded on lie
   --  on its ground as it is now: its floor is dug and filled under them, and
   --  the path round it is brought to its level.
   procedure Settle_Piles is
   begin
      if not Camp_Square then
         return;
      end if;
      for P in 1 .. N_Piles loop
         if Piles (P).Count > 0 and then Flat_Dist (Piles (P).Centre, Camp_At) <= Square_Side_Now then
            declare
               Zp  : constant Float := Castle.Nav.Surface_Z (Piles (P).Centre.X, Piles (P).Centre.Y);
               Own : constant Float := Own_Ground (Piles (P).Centre, Zp);
            begin
               if Own >= 0.0 and then abs (Own - Piles (P).Centre.Z) <= 2.0 then
                  Piles (P).Centre.Z := Own;
               end if;
            end;
         end if;
      end loop;
   end Settle_Piles;

   --  The fire's place follows its ground (the floor may have been brought
   --  up or down under it), and anyone standing on the floor stands on it
   --  as it is now.  (Of the square the colony was founded on all is floor,
   --  out to its corners: left as it was for a camp, whoever stood more
   --  than 3 m from the fire on ground dug or filled under them stood in it
   --  or over it, by as much as a metre, until they next walked.)
   procedure Settle_On_Floor is
      Z : constant Float := Castle.Nav.Surface_Z (Camp_At.X, Camp_At.Y);
      Reach : constant Float := (if Camp_Square then Square_Side_Now * 0.75 else Hearth_Ground_M + 0.5);
   begin
      if Z >= 0.0 then
         Camp_At.Z := Z;
      end if;
      for I in 1 .. N_Members loop
         if not Band (I).Is_Dead and then Flat_Dist (Band (I).Pos, Camp_At) <= Reach then
            declare
               Zm : constant Float :=
                 Own_Ground (Band (I).Pos, Castle.Nav.Surface_Z (Band (I).Pos.X, Band (I).Pos.Y));
            begin
               if Zm >= 0.0 and then abs (Zm - Band (I).Pos.Z) <= 1.5 then
                  Band (I).Pos.Z := Zm;
                  Band (I).Prev.Z := Zm;
               end if;
            end;
         end if;
      end loop;
      Settle_Piles;
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
      --  (a tree still to fell on the square is ground still to make ready)
      Ground_Left_N := Count_Ground_Left + Square_Trees_Standing;
      if Ground_Left_N = 0
        and then (for all K in Item_Kind => Zones (Camp_Zone_N).Got (K) >= Build_Takes (Camp_Zone) (K))
      then
         Zones (Camp_Zone_N).Built := True;
         Sod_Bits := 0;                       --  (what turf is left lying is trodden in)
         Settle_On_Floor;
         Walls_Stale := True;                 --  (a square's walls are counted from now on)
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
                        Cut_Plants (X, Y, Top);
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
      --  (the square's trees felled on the spot, away from the fire: their logs lie where they fell)
      if Camp_Square and then Square_Fell_On and then N_Members > 0 then
         for K in 1 .. N_Trees loop
            if not Trees (K).Down and then Tree_On_Square (K) and then not Tree_Spared (K)
              and then Mat (Trees (K).Info.Bx, Trees (K).Info.By, Trees (K).Info.Bz + 1) in Trunk
            then
               Fell (K, Camp_At, 1);
            end if;
         end loop;
         Read_Camp_Ground;
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
      Walls_Stale := True;
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
                  N := N + (if U in For_Ring | For_Wall then Carry_Limit (Stone) else 1);
               elsif M.Carried > 0 then
                  N := N + (if U in For_Ring | For_Wall then M.Carried else 1);
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
                or else (Band (J).Use_For in For_Ring | For_Frame | For_Seat | For_Floor | For_Wall
                         and then (Band (J).State in To_Source | Gathering | To_Take | Taking | To_Camp | Putting_In
                                   or else (Band (J).State = Idle and then Band (J).Carried > 0)))
                or else (Band (J).Carry = Earth and then Band (J).Carried > 0           --  (earth off the camp's floor)
                         and then Band (J).State in Idle | To_Store | Storing)
                or else Band (J).State in To_Tow | Towing));                          --  (the lord's cart)

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
         when For_Ring | For_Frame | For_Floor | For_House | For_Bed | For_Ladder | For_Fitting | For_Wall =>
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
      if Band (I).Bed or else Band (I).Placed then
         return Band (I).Bed_At;                   --  (on the bed it made itself, or the place it has chosen for it)
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
   --  (at a place of its own by the fire: the way it chose to lie there, across the way to the fire)
   function Own_Facing (I : Positive) return Vec3 is
     (Band (I).Bed_At + (Cos (Band (I).Bed_Dir), Sin (Band (I).Bed_Dir), 0.0));
   function Bed_Facing (I : Positive) return Vec3 is
     (if At_Home (I)
      then Bed_Place (Home_Of (I)) + House_Inward (Home_Of (I))
      elsif Band (I).Placed and then not (N_Houses > 0 and then Housed (I)) then Own_Facing (I)
      elsif Camp_Set then Camp_At else Stake_At);
   --  (the same for one that is to lie at Feet, wherever it stands now)
   function Bed_Facing_At (I : Positive; Feet : Vec3) return Vec3 is
     (if N_Houses > 0 and then Housed (I)
      then Feet + House_Inward (Home_Of (I))
      elsif Band (I).Placed then Own_Facing (I)
      elsif Camp_Set then Camp_At else Stake_At);

   ------------------------------------------------------------------ beds

   --  A bed of straw (John, 2026-11-12: "when the campground is built have
   --  them pull or collect straw for a bed ... When they get assigned a home
   --  they can build a new straw bed in their house, we will let the old one
   --  decay outside when we add decay later").  Each of the band makes its
   --  own, where it sleeps: by the fire once the camp is built, and again in
   --  its house once one is its own (the house's bed is the house's: whoever
   --  the house falls to next has it).  Its straw is the stockpile's, what
   --  of it the hovels being built do not still want; with none to spare it
   --  cuts its own.  Bed_Straw sheaves, or as many as it could come by (one
   --  at the least).  A bed changes nothing but where its maker is seen to
   --  lie: it is neither warmer nor better rested for it.
   procedure Set_Beds (On : Boolean) is
   begin
      Beds_On := On;
   end Set_Beds;
   function Beds return Boolean is (Beds_On);
   function Straw_In_Beds return Natural is (Bed_Sheaves);

   --  Member I has a bed where it sleeps now; and still has one to make.
   function Has_Bed (I : Positive) return Boolean is
     (if N_Houses > 0 and then Housed (I) then Houses (Home_Of (I)).Bed else Band (I).Bed);
   function Wants_Bed (I : Positive) return Boolean is
     (Beds_On and then not Band (I).Is_Dead and then not Has_Bed (I)
      and then ((N_Houses > 0 and then Housed (I)) or else (Camp_Set and then Camp_Built)));

   function Sleeping_Place (I : Positive) return Bed_View is
     (if I <= N_Members
      then (Made => Has_Bed (I), Feet => Bed_Spot (I), Toward => Bed_Facing_At (I, Bed_Spot (I)),
            By_Fire => Band (I).Placed and then Band (I).Bed_Lo >= 0 and then not (N_Houses > 0 and then Housed (I)))
      else (Made => False, others => <>));

   function Camp_Bed (I : Positive) return Bed_View is
     (if I <= N_Members and then Band (I).Bed
      then (Made => True, Feet => Band (I).Bed_At,
            Toward => (if Band (I).Placed then Own_Facing (I) elsif Camp_Set then Camp_At else Stake_At),
            By_Fire => Band (I).Placed and then Band (I).Bed_Lo >= 0)
      else (Made => False, others => <>));

   --  The ground under one that lies with its middle at C, its feet toward
   --  (Ux, Uy): from a metre before its middle, where it stands to lie down,
   --  to a metre behind, and a block to either side.  Ok: all of it is the
   --  camp's ground or nobody's, no path's, bare but for what grows and can
   --  be cut, with nothing over it; Lo .. Hi: the rows of its top.
   procedure Lie_Ground (C : Vec3; Ux, Uy : Float; Near : Integer; Ok : out Boolean; Lo, Hi : out Integer) is
   begin
      Ok := False;
      Lo := Integer'Last;
      Hi := Integer'First;
      for A in -4 .. 4 loop
         for W in -1 .. 1 loop
            declare
               X  : constant Integer := B (C.X + Ux * 0.25 * Float (A) - Uy * 0.25 * Float (W));
               Y  : constant Integer := B (C.Y + Uy * 0.25 * Float (A) + Ux * 0.25 * Float (W));
               Zn : constant Natural := Zone_Of_Block (X, Y);
               Zr : constant Integer := Ground_Row (X, Y, Near);
            begin
               if Zr < 0 or else (Zn /= 0 and then Zn /= Camp_Zone_N)
                 or else Near_Path ((Float (X) + 0.5) * 0.25, (Float (Y) + 0.5) * 0.25, 0.0)
                 or else Mat (X, Y, Zr) not in Grass | Dirt | Sand | Gravel | Clay | Placer_Gravel | Bog_Iron
                 or else Mat (X, Y, Zr + 1) not in Air | Tall_Grass | Wild_Grain | Wild_Vegetables
                 or else (for some Up in 2 .. 4 => Class_Of (Mat (X, Y, Zr + Up)) = Solid)
               then
                  return;
               end if;
               Lo := Integer'Min (Lo, Zr);
               Hi := Integer'Max (Hi, Zr);
            end;
         end loop;
      end loop;
      Ok := True;
   end Lie_Ground;

   --  How near two sleepers lie: the least way between the lines they lie
   --  along (each from where its feet stand, Feet, 1.85 m back from the way
   --  they point).
   function Lie_Gap (Feet_1 : Vec3; Dir_1 : Float; Feet_2 : Vec3; Dir_2 : Float) return Float is
      Least : Float := Float'Last;
   begin
      for A in 0 .. 8 loop
         for C in 0 .. 8 loop
            declare
               Ta : constant Float := 1.85 * Float (A) / 8.0;
               Tc : constant Float := 1.85 * Float (C) / 8.0;
            begin
               Least := Float'Min
                 (Least, Flat_Dist ((Feet_1.X - Cos (Dir_1) * Ta, Feet_1.Y - Sin (Dir_1) * Ta, 0.0),
                                    (Feet_2.X - Cos (Dir_2) * Tc, Feet_2.Y - Sin (Dir_2) * Tc, 0.0)));
            end;
         end loop;
      end loop;
      return Least;
   end Lie_Gap;

   --  Member I's place by the fire is chosen (see Bed_Near_M): the nearest
   --  to the fire of the places round it, across the way to it, that are
   --  level enough, nobody else's and can be got to; one a block out of
   --  level counted Bed_Step_M further off.  With none, the old ring.
   procedure Place_Bed (I : Positive) is
      M      : Member renames Band (I);
      Turn   : constant Float := (if I mod 2 = 1 then 1.0 else -1.0);   --  (heads and feet turn about round the fire)
      Best   : Float := Float'Last;
      R      : Float := Bed_Near_M;
      Wood_P : constant Vec3 := Firewood_Place;
   begin
      while R <= Bed_Far_M + 0.001 and then Best > R loop
         declare
            N : constant Positive := Positive'Max (8, Integer (2.0 * Ada.Numerics.Pi * R / Bed_Ring_M));
         begin
            for K in 0 .. N - 1 loop
               declare
                  A  : constant Float := Camp_Turn + 2.0 * Ada.Numerics.Pi * (Float (K) + 0.5) / Float (N);
                  C  : constant Vec3 := (Camp_At.X + R * Cos (A), Camp_At.Y + R * Sin (A), 0.0);
                  Ux : constant Float := -Sin (A) * Turn;
                  Uy : constant Float := Cos (A) * Turn;
                  Feet : Vec3 := (C.X + Ux, C.Y + Uy, 0.0);
                  Dir  : constant Float := Arctan (Uy, Ux);
                  Sz : constant Float := Castle.Nav.Surface_Z (C.X, C.Y);
                  Ok : Boolean := Sz >= 0.0 and then Flat_Dist (C, Wood_P) > 1.6;
                  Lo, Hi : Integer := 0;
               begin
                  if Ok then
                     Lie_Ground (C, Ux, Uy, B (Sz) - 1, Ok, Lo, Hi);
                  end if;
                  if Ok and then Hi - Lo <= Bed_Uneven_B and then R + Bed_Step_M * Float (Hi - Lo) < Best then
                     Feet.Z := Float (Hi + 1) * 0.25;
                     for J in 1 .. N_Members loop
                        if J /= I and then (Band (J).Placed or else Band (J).Bed)
                          and then Lie_Gap (Feet, Dir, Band (J).Bed_At, Band (J).Bed_Dir) < Bed_Apart_M
                        then
                           Ok := False;
                        end if;
                     end loop;
                     if Ok then
                        declare
                           Way : constant Castle.Nav.Route := Castle.Nav.Plan (Cook_Side, Feet, Budget => 20_000, Within => Own_Region);
                        begin
                           Ok := Castle.Nav."=" (Way.Result, Castle.Nav.Found) and then Way.N > 0
                             and then Flat_Dist (Way.Pts (Way.N).P, Feet) <= 0.6;
                        end;
                     end if;
                     if Ok then
                        Best := R + Bed_Step_M * Float (Hi - Lo);
                        M.Bed_At := Feet;
                        M.Bed_Dir := Dir;
                        M.Bed_Lo := Lo;
                        M.Bed_Hi := Hi;
                     end if;
                  end if;
               end;
            end loop;
         end;
         R := R + Bed_Ring_M;
      end loop;
      if Best = Float'Last then
         --  (no such place: on the ring, as the band lay before it looked for one)
         M.Bed_At := Bed_Spot (I);
         M.Bed_Dir := Arctan (Camp_At.Y - M.Bed_At.Y, Camp_At.X - M.Bed_At.X);
         M.Bed_Lo := -1;
         M.Bed_Hi := -1;
      end if;
      M.Placed := True;
   end Place_Bed;

   --  Its place by the fire is still as it was chosen: its ground where it
   --  was, no path over it, no house's ground come to it.
   function Bed_Kept (I : Positive) return Boolean is
      M  : Member renames Band (I);
      Ux : constant Float := Cos (M.Bed_Dir);
      Uy : constant Float := Sin (M.Bed_Dir);
   begin
      --  (On the square the colony was founded on, its banks walled, a place of the old ring, taken for
      --  want of any other, is not looked over: it may lie by the square's path for good.  Given up each hour and
      --  taken again, its bed was made again each hour: at one walled square, where a stair and two
      --  lifts left one of thirteen no level place, 188 times in twelve days, and the band went hungry
      --  for it, 424 serf-hours against 262.)
      if Camp_Square and then Walls_On and then M.Bed_Lo < 0 then
         return True;
      end if;
      for A in -4 .. 4 loop
         for W in -1 .. 1 loop
            declare
               X : constant Integer := B (M.Bed_At.X - Ux + Ux * 0.25 * Float (A) - Uy * 0.25 * Float (W));
               Y : constant Integer := B (M.Bed_At.Y - Uy + Uy * 0.25 * Float (A) + Ux * 0.25 * Float (W));
            begin
               if Near_Path ((Float (X) + 0.5) * 0.25, (Float (Y) + 0.5) * 0.25, 0.0)
                 or else (N_Houses > 0 and then Site_Of_Block (X, Y, 0) /= 0)
                 or else (M.Bed_Lo >= 0 and then Ground_Row (X, Y, M.Bed_Hi) not in M.Bed_Lo .. M.Bed_Hi)
               then
                  return False;
               end if;
            end;
         end loop;
      end loop;
      return True;
   end Bed_Kept;

   --  Once a game hour: a place by the fire that something has been built
   --  or dug on is nobody's any more, and a bed made there is gone with its
   --  straw (whoever still sleeps by the fire chooses another, and makes
   --  its bed again).
   procedure Keep_Beds is
   begin
      for I in 1 .. N_Members loop
         if Band (I).Placed and then not Bed_Kept (I) then
            Places_Lost_N := Places_Lost_N + 1;
            Band (I).Placed := False;
            if Band (I).Bed then
               Bed_Sheaves := Bed_Sheaves - Natural'Min (Bed_Sheaves, Band (I).Bed_Has);
               Band (I).Bed := False;
               Band (I).Bed_Has := 0;
            end if;
         end if;
      end loop;
   end Keep_Beds;

   --  The bed is made, of the straw it has brought, where it stands to lie
   --  down: what grows there is cut.  Made False: where it sleeps is no
   --  longer where it has come to (a hovel fell to it on its way to the
   --  fire with its straw), and nothing is laid: it goes there with it.
   procedure Make_Bed (I : Positive; Made : out Boolean) is
      M    : Member renames Band (I);
      Used : constant Natural := Natural'Min (M.Carried, Bed_Straw);
      Feet : constant Vec3 := Bed_Spot (I);
      To   : constant Vec3 := Bed_Facing_At (I, Feet);
      L    : constant Float := Float'Max (0.01, Flat_Dist (Feet, To));
      Dx   : constant Float := (To.X - Feet.X) / L;
      Dy   : constant Float := (To.Y - Feet.Y) / L;
   begin
      Made := False;
      if Used = 0 or else M.Carry /= Straw or else Flat_Dist (M.Pos, Feet) > Home_M then
         return;
      end if;
      Made := True;
      if N_Houses > 0 and then Housed (I) then
         Houses (Home_Of (I)).Bed := True;
      else
         M.Bed := True;
         M.Bed_At := Feet;
         M.Bed_Has := Used;
         if not M.Placed then                      --  (with no place chosen: as the band lay before it looked for one)
            M.Placed := True;
            M.Bed_Dir := Arctan (To.Y - Feet.Y, To.X - Feet.X);
            M.Bed_Lo := -1;
            M.Bed_Hi := -1;
         end if;
         --  (the grass under it: from its feet back along where it lies)
         for Along in 0 .. 8 loop
            for Across in -2 .. 2 loop
               declare
                  X : constant Integer := B (Feet.X - Dx * 0.25 * Float (Along) - Dy * 0.25 * Float (Across));
                  Y : constant Integer := B (Feet.Y - Dy * 0.25 * Float (Along) + Dx * 0.25 * Float (Across));
                  Z : constant Integer := Ground_Row (X, Y, B (Feet.Z) - 1);
               begin
                  if Z >= 0 then
                     Cut_Plants (X, Y, Z);
                  end if;
               end;
            end loop;
         end loop;
      end if;
      Bed_Sheaves := Bed_Sheaves + Used;
      M.Carried := M.Carried - Used;
      if M.Carried = 0 then
         --  the grain that came with straw it cut itself goes to the stores
         if M.Grain > 0 then
            M.Carry := Grain;
            M.Carried := M.Grain;
            M.Grain := 0;
         else
            M.Carry := Nothing;
         end if;
      end if;
   end Make_Bed;

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
         Walls_Stale := True;
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

   function Has_Cook return Boolean is
     (for some I in 1 .. N_Members => Band (I).Job = Cook and then not Band (I).Is_Dead);

   function Pot_Room return Natural is (Integer'Max (0, Pot_Points - Integer (Pot_Stew) - Integer (Pot_Raw)));
   function Pot_Goal return Natural is (Integer'Max (0, Pot_Points - Integer (Pot_Stew)));   --  to fill it

   --  What the cook keeps for the pot, of a kind that can be eaten raw: the
   --  greens of a pot's fill, in the cook's own order, from what the winter
   --  store does not hold (the spec, "What the cook keeps").
   function Cook_Hold (K : Item_Kind) return Natural is
      Left : Integer := Cook_Keeps;
   begin
      if not Hold_On or else Raw_Food (K) = 0 or else not Camp_Built or else not Has_Cook then
         return 0;
      end if;
      if Usable (Meat) > 0 then                --  (meat's half of a pot, while there is meat)
         Left := Left - Integer'Min (Usable (Meat) * Stew_Food (Meat), Cook_Keeps / 2);
      end if;
      for J of Greens_Order loop
         declare
            Take : constant Natural :=
              Natural'Min (Usable (J), (Integer'Max (0, Left) + Stew_Food (J) - 1) / Stew_Food (J));
         begin
            if J = K then
               return Take;
            end if;
            Left := Left - Take * Stew_Food (J);
         end;
      end loop;
      return 0;
   end Cook_Hold;

   --  Of K, what may be eaten raw: not set aside, not held for winter, not
   --  kept for the pot.
   function Raw_Free (K : Item_Kind) return Natural is (Usable (K) - Natural'Min (Usable (K), Cook_Hold (K)));

   procedure Set_Cook_Hold (On : Boolean) is
   begin
      Hold_On := On;
   end Set_Cook_Hold;
   function Cook_Holds return Boolean is (Hold_On);
   function Cook_Held (K : Item_Kind) return Natural is (Cook_Hold (K));

   --  Food to be had: stew, or raw food in the stockpiles, not set aside,
   --  held back or kept for the pot.
   function Food_In_Store return Boolean is
   begin
      if Stew_Free > 0 then
         return True;
      end if;
      for K of Keep_Order loop
         if Raw_Food (K) > 0 and then Raw_Free (K) > 0 then
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

   --  Come to within a step of where it sleeps, it lies down on its bed
   --  if it has one, not beside it.
   procedure Lie_On_Bed (I : Positive) is
      M : Member renames Band (I);
   begin
      if Beds_On and then Flat_Dist (M.Pos, Bed_Spot (I)) <= 0.8
        and then ((Has_Bed (I) and then abs (M.Pos.Z - Bed_Spot (I).Z) < 0.3)
                  --  (at a place of its own by the fire, bed or no bed: the ground it chose, all of it
                  --  level, whatever the walking map makes of the ground beside it)
                  or else (M.Placed and then M.Bed_Lo >= 0 and then not (N_Houses > 0 and then Housed (I))
                           and then abs (M.Pos.Z - Bed_Spot (I).Z) < 0.8))
      then
         M.Pos := Bed_Spot (I);
      end if;
   end Lie_On_Bed;

   function Go_Bed (I : Positive) return Boolean is
      M : Member renames Band (I);
   begin
      M.Fends := False;
      if Flat_Dist (M.Pos, Bed_Spot (I)) <= 0.8 then
         M.Route.N := 0;
         M.Pace := 0.0;
         M.State := Sleeping;
         Lie_On_Bed (I);
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
         | To_Take | To_Patch | Tamping | To_Site | Raising | To_Cart | To_Ladder);
   --  (To_Tow and Towing are not: the cart is taken where it is going, as a load is)

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
         --  (a square's walls are wanted from when its fire is lit: counted at the next step, as a load
         --  counts them at its first; left to the minute's count, a run saved in between ran on otherwise)
         Walls_Stale := True;
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
      St      : Unsigned_8 := 0;     --  the state the block is laid with (a roof's trimming)
   end record;
   Max_BP : constant := Max_House_Blocks;
   type BP_Array is array (1 .. Max_BP) of BP_Block;
   type BP_Access is access BP_Array;
   BP    : constant BP_Access := new BP_Array;
   BP_N  : Natural := 0;
   BP_Of : Natural := 0;             --  the house it is of (0: none)

   procedure Blueprint_Of (H : Positive) is
      procedure Note (Bx, By, Bz : Integer; M : Material; S : CB.Stage; State : Natural) is
      begin
         if M /= Air and then BP_N < Max_BP then
            BP_N := BP_N + 1;
            BP (BP_N) := (Integer_16 (Bx), Integer_16 (By), Integer_16 (Bz), M, S, Unsigned_8 (State));
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
   end Set_House_Memos;

   --  What a block is made from, and how many blocks one of that makes.
   --  Timber is of logs; thatch is straw, and so is daub (the straw in it:
   --  its earth is the site's own, its wattle what was cut there); a floor
   --  of beaten earth and the air of a door or a window take nothing
   --  (Nothing: work alone, never carried, never counted in what a house
   --  takes or has).
   function Kind_Of_Block (M : Material) return Item_Kind is
     (case M is when Thatch | Daub => Straw, when Log | Plank => Wood, when Fieldstone => Stone, when others => Nothing);
   function Blocks_Per (K : Item_Kind) return Positive is
     (if K = Straw then Thatch_Per_Sheaf elsif K = Stone then Wall_Per_Stone else Planks_Per_Log);
   --  (a roof's trimming is its thatch again, as it lies: work alone; and a covering's smoothing)
   function Kind_Of (Bk : BP_Block) return Item_Kind is
     (if Bk.S in CB.Dress | CB.Smooth then Nothing else Kind_Of_Block (Bk.M));

   --  What a house still wants of stone, from the blocks of wall and stair
   --  last counted as still to lay (its site is read, not kept: the count
   --  moves as the ground beside it does) and what lies there not yet laid.
   procedure Note_Stone (H : Positive; Left : Natural) is
      Hs : House_Rec renames Houses (H);
   begin
      Hs.Stone_Left := Left;
      Hs.Takes (Stone) :=
        Hs.Got (Stone) + (if Left > Hs.Lying (Stone) then (Left - Hs.Lying (Stone) + Wall_Per_Stone - 1) / Wall_Per_Stone else 0);
   end Note_Stone;

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
      Hs.Yard_Wood_N := 0;
      Hs.Roof_N := 0;
      Hs.Dress_N := 0;
      Hs.Cover_N := 0;
      for K in 1 .. BP_N loop
         if BP (K).S /= CB.Smooth then
            Hs.Cover_N := K;
         end if;
         N (Kind_Of (BP (K))) := N (Kind_Of (BP (K))) + 1;
         if Kind_Of (BP (K)) = Wood and then BP (K).S <= CB.Dress then
            Hs.Wood_N := K;
         elsif Kind_Of (BP (K)) = Wood then
            Hs.Yard_Wood_N := K;               --  (a storehouse's yard: its fence and coverings' posts)
         end if;
         if BP (K).S < CB.Dress then
            Hs.Roof_N := K;
         end if;
         if BP (K).S <= CB.Dress then
            Hs.Dress_N := K;
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
      Note_Stone (H, Hs.Stone_Left);
      for K in Item_Kind loop
         if K not in Nothing | Stone and then N (K) > 0 then
            Hs.Takes (K) := (N (K) + Blocks_Per (K) - 1) / Blocks_Per (K);
         end if;
      end loop;
   end Measure_House;

   --  What a house still takes that has not been carried to it; and that
   --  of a zone's houses, and of all of them.
   function House_Short (H : Positive; K : Item_Kind) return Natural is
     (if Houses (H).Built or else Houses (H).Raze or else Houses (H).Got (K) >= Houses (H).Takes (K) then 0
      else Houses (H).Takes (K) - Houses (H).Got (K));

   --  A log for a ladder: a house not yet built wants one of the stores
   --  while no ladder stands at it and there is none to be had for it
   --  (stored, standing at a hovel that is built, in somebody's arms or in
   --  the making), the houses begun first before those begun after.  It is
   --  asked with the house's timber, so that it is felled with it; it is not
   --  of the house's own timber, and is never carried to it as a log.
   function Ladder_Short (H : Positive) return Natural is
      Avail, Before : Natural := 0;
   begin
      if not Ladders_On or else Houses (H).Built or else Houses (H).Ladder > 0 then
         return 0;
      end if;
      for C in 1 .. N_Cells loop
         if Cells (C).Kind = Ladder then
            Avail := Avail + Cells (C).Count;
         end if;
      end loop;
      for K in 1 .. N_Houses loop
         if Houses (K).Built and then Houses (K).Ladder > 0 then
            Avail := Avail + 1;
         elsif K < H and then not Houses (K).Built and then Houses (K).Ladder = 0 then
            Before := Before + 1;
         end if;
      end loop;
      for I in 1 .. N_Members loop
         if not Band (I).Is_Dead
           and then ((Band (I).Carry = Ladder and then Band (I).Carried > 0) or else Band (I).State = Making)
         then
            Avail := Avail + 1;
         end if;
      end loop;
      return (if Before >= Avail then Ladder_Wood else 0);
   end Ladder_Short;

   function Zone_Short (Z : Positive; K : Item_Kind) return Natural is
      N : Natural := 0;
   begin
      for H in 1 .. N_Houses loop
         if Houses (H).Zone = Z then
            N := N + House_Short (H, K) + (if K = Wood then Ladder_Short (H) else 0);
         end if;
      end loop;
      return N;
   end Zone_Short;

   function Houses_Short (K : Item_Kind) return Natural is
      N : Natural := 0;
   begin
      for H in 1 .. N_Houses loop
         N := N + House_Short (H, K) + (if K = Wood then Ladder_Short (H) else 0);
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
      if Yard_Turned (F) then               --  (a stockyard along its path: its ground, column by column)
         declare
            Bx : constant Frame_Box := Yard_Box (F);
         begin
            for U in Bx.U0 .. Bx.U1 loop
               for V in Bx.V0 .. Bx.V1 loop
                  if In_Site (F, U, V) then
                     declare
                        X : constant Integer := H_X (F, U, V) - Lot_X0;
                        Y : constant Integer := H_Y (F, U, V) - Lot_Y0;
                     begin
                        if X in 0 .. Lot_NX - 1 and then Y in 0 .. Lot_NY - 1 then
                           Lot_G (X, Y) := Lot_Taken;
                        end if;
                     end;
                  end if;
               end loop;
            end loop;
         end;
         return;
      end if;
      --  (and what it reaches over to a neighbour's)
      for U in Integer'Min (-Lot_Left (F), Site_U_Lo (F)) .. Integer'Max (F.W - 1 + Lot_Right (F), Site_U_Hi (F)) loop
         for V in -Front_Of (F, U) .. Lot_Back (F) loop
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
      if F.Turn_Ground then                       --  (and the ground it is drawn on)
         declare
            Bx : constant Frame_Box := Drawn_Box (F, Float (Turn_Apron_B));
         begin
            for U in Bx.U0 .. Bx.U1 loop
               for V in Bx.V0 .. Bx.V1 loop
                  if Under_Turn (F, U, V) then
                     declare
                        X : constant Integer := H_X (F, U, V) - Lot_X0;
                        Y : constant Integer := H_Y (F, U, V) - Lot_Y0;
                     begin
                        if X in 0 .. Lot_NX - 1 and then Y in 0 .. Lot_NY - 1 then
                           Lot_G (X, Y) := Lot_Taken;
                        end if;
                     end;
                  end if;
               end loop;
            end loop;
         end;
      end if;
   end Lot_Take;

   --  The grid of zone Z as things stand: its ground, less every lot taken
   --  (With_Lots: and less every lot laid out for a house not yet begun).
   procedure Lot_Grid_Of_Zone (Z : Positive; With_Lots : Boolean := True) is
      R : Zone_Rec renames Zones (Z);
   begin
      Lot_Open (R.Bx0, R.By0, R.Bx1, R.By1);
      for K in R.First + 1 .. R.First + R.N loop
         Lot_Run (Runs (K));
      end loop;
      for H in 1 .. N_Houses loop
         Lot_Take (Houses (H).F);
      end loop;
      if With_Lots then
         for K in 1 .. N_Lots loop
            Lot_Take (Lots (K).F);
         end loop;
      end if;
   end Lot_Grid_Of_Zone;

   --  (Whether the fall of the ground is taken under a turned hovel's walls as drawn as well as
   --  under them as they stand: off since John's word of 2026-11-19, "we don't want to limit the
   --  player they need to be able to place diagonals on hillsides if they want to": a turned hovel
   --  is placed wherever a square one would be, and its ground is made however far the land falls
   --  under it as drawn.  Kept to measure against.)
   Turn_Fall_On : Boolean := False;
   procedure Set_Turn_Fall (On : Boolean) is
   begin
      Turn_Fall_On := On;
   end Set_Turn_Fall;
   function Turn_Fall return Boolean is (Turn_Fall_On);

   --  A house as placed: its walls and the bank round them wholly on the
   --  zone's free ground, on ground that falls no more than Max_Step_B, its
   --  lot crossing no other.  On_A_Path: a path's own ground is in the way
   --  (on a slanting path it steps further back).
   type Lot_Verdict is (Clear, On_A_Path, Blocked);

   function Check_Lot (F : CB.House) return Lot_Verdict is
      Lo : Integer := Integer'Last;
      Hi : Integer := Integer'First;
      On_Path_Seen, Bad : Boolean := False;
   begin
      if Yard_Turned (F) then
         --  (a stockyard along its path: every column of its frame whose middle lies in its lot as
         --  designed, from the bank before its front wall back; one within a hair of the lot's edge
         --  is not asked, the zone's ground having been filled by the same edge reckoned another way)
         declare
            Bx : constant Frame_Box :=
              Design_Box (F, Float (-Lot_Left (F)) - 0.5, Float (F.W - 1 + Lot_Right (F)) + 0.5,
                          Float (V_Lo) - 0.5, Float (Lot_Back (F)) + 0.5);
            Hair : constant := 0.05;
         begin
            for U in Bx.U0 .. Bx.U1 loop
               for V in Bx.V0 .. Bx.V1 loop
                  declare
                     Qu, Qv : Float;
                  begin
                     CB.Back_Turn (F, Float (U), Float (V), Qu, Qv);
                     if Qu in Float (-Lot_Left (F)) - 0.5 + Hair .. Float (F.W - 1 + Lot_Right (F)) + 0.5 - Hair
                       and then Qv in Float (V_Lo) - 0.5 + Hair .. Float (Lot_Back (F)) + 0.5 - Hair
                     then
                        declare
                           X : constant Integer := H_X (F, U, V);
                           Y : constant Integer := H_Y (F, U, V);
                           C : constant Integer := Lot_Cell (X, Y);
                        begin
                           if C = Lot_Taken then
                              return Blocked;
                           elsif C = 0 then
                              if Near_Path ((Float (X) + 0.5) * 0.25, (Float (Y) + 0.5) * 0.25, 0.0) then
                                 On_Path_Seen := True;
                              else
                                 Bad := True;
                              end if;
                           else
                              Lo := Integer'Min (Lo, C - 1);
                              Hi := Integer'Max (Hi, C - 1);
                           end if;
                        end;
                     end if;
                  end;
               end loop;
            end loop;
         end;
         return (if On_Path_Seen then On_A_Path elsif Bad or else Hi - Lo > Yard_Fall_B then Blocked else Clear);
      end if;
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
               if U in -Apron_L (F) .. F.W - 1 + Apron_R (F) and then V <= V_Hi (F) then
                  if C = 0 then
                     if Near_Path ((Float (X) + 0.5) * 0.25, (Float (Y) + 0.5) * 0.25, 0.0) then
                        On_Path_Seen := True;
                     else
                        Bad := True;
                     end if;
                  elsif Yard_Site (F) or else (U in 0 .. F.W - 1 and then V in 0 .. F.D - 1) then
                     Lo := Integer'Min (Lo, C - 1);          --  (a hovel's: under its walls; a stockyard's: all of it)
                     Hi := Integer'Max (Hi, C - 1);
                  end if;
               end if;
            end;
         end loop;
      end loop;
      --  (one drawn turned: the ground it is drawn on is its zone's and nobody's, no path's;
      --  and under its walls as drawn the ground falls no more than under them as they stand)
      if F.Turn_Ground then
         declare
            Bx : constant Frame_Box := Drawn_Box (F, Float (Turn_Apron_B));
         begin
            for U in Bx.U0 .. Bx.U1 loop
               for V in Bx.V0 .. Bx.V1 loop
                  if Under_Turn (F, U, V) then
                     declare
                        X : constant Integer := H_X (F, U, V);
                        Y : constant Integer := H_Y (F, U, V);
                        C : constant Integer := Lot_Cell (X, Y);
                     begin
                        if C = Lot_Taken then
                           return Blocked;
                        elsif C = 0 then
                           if Near_Path ((Float (X) + 0.5) * 0.25, (Float (Y) + 0.5) * 0.25, 0.0) then
                              On_Path_Seen := True;
                           else
                              Bad := True;
                           end if;
                        elsif Turn_Fall_On and then Under_Turn (F, U, V, Margin => 0) then
                           Lo := Integer'Min (Lo, C - 1);
                           Hi := Integer'Max (Hi, C - 1);
                        end if;
                     end;
                  end if;
               end loop;
            end loop;
         end;
      end if;
      return (if On_Path_Seen then On_A_Path
              elsif Bad or else Hi - Lo > (if Yard_Site (F) then Yard_Fall_B else CB.Max_Step_B) then Blocked
              else Clear);
   end Check_Lot;

   --  The level of its pad: the highest at which the earth dug off what
   --  stands above it is at least what the hollows below it take (so that
   --  the earth for them is always there, as for the camp's floor),
   --  reckoned as if its hollows were filled: they are, with the turf cut
   --  off its floor (Fill_Hollows).  Reckoned on the ground as it lies, a hole or
   --  two in level ground wanted earth that nothing dug off gave, and the
   --  whole lot was dug down to their bottoms instead (John, 2026-11-13:
   --  "othewise even ground was dug out entirely becuase it had a couple
   --  of holes in it, instead of just filling the holes").  A slope has
   --  no holes: its pad is where it was.
   --  (a storehouse's drawn turned: over its ground as it is made, column by column of its frame)
   procedure Choose_Pad_Yard (F : in out CB.House) is
      Bx   : constant Frame_Box := Yard_Box (F);
      Tops : Top_Grid (Bx.U0 - 1 .. Bx.U1 + 1, Bx.V0 - 1 .. Bx.V1 + 1) := [others => [others => -1]];
      Lo   : Integer := Integer'Last;
      Hi   : Integer := Integer'First;
   begin
      for U in Bx.U0 .. Bx.U1 loop
         for V in Bx.V0 .. Bx.V1 loop
            if In_Site (F, U, V) then
               Tops (U, V) := Lot_Cell (H_X (F, U, V), H_Y (F, U, V)) - 1;
            end if;
         end loop;
      end loop;
      Fill_Hollows (Tops);
      for U in Bx.U0 .. Bx.U1 loop
         for V in Bx.V0 .. Bx.V1 loop
            if Tops (U, V) >= 0 and then CB.Under_Drawn (F, Float (U), Float (V)) then
               Lo := Integer'Min (Lo, Tops (U, V));
               Hi := Integer'Max (Hi, Tops (U, V));
            end if;
         end loop;
      end loop;
      for Level in reverse Lo .. Hi loop
         F.Pad := Level + 1;
         declare
            Cut, Fill : Natural := 0;
         begin
            for U in Bx.U0 .. Bx.U1 loop
               for V in Bx.V0 .. Bx.V1 loop
                  if Tops (U, V) > Level then
                     Cut := Cut + Tops (U, V) - Level;
                  elsif Tops (U, V) >= 0 then
                     Fill := Fill + Level - Tops (U, V);
                  end if;
               end loop;
            end loop;
            exit when Cut >= Fill;
         end;
      end loop;
   end Choose_Pad_Yard;

   procedure Choose_Pad (F : in out CB.House) is
      --  (a hovel's as they always were; a storehouse's yard reaches further)
      --  (one drawn turned: the ground it is drawn on with it)
      Bx   : constant Frame_Box :=
        (if F.Turn_Ground then Drawn_Box (F, Float (Turn_Apron_B)) else (U0 => 0, U1 => 0, V0 => 0, V1 => 0));
      Tops : Top_Grid (Integer'Min (Integer'Min (-CB.Apron_B - 1, -Apron_L (F) - 1), Bx.U0 - 1)
                       .. Integer'Max (Integer'Max (CB.Max_Long_B + CB.Apron_B, F.W + Apron_R (F)), Bx.U1 + 1),
                       Integer'Min (-Front_Most (F) - 1, Bx.V0 - 1)
                       .. Integer'Max (Integer'Max (CB.Max_Long_B + CB.Apron_B, V_Hi (F) + 1), Bx.V1 + 1)) :=
        [others => [others => -1]];                              --  -1: not of its lot
      Lo : Integer := Integer'Last;
      Hi : Integer := Integer'First;
      --  of the ground it is drawn on, what its square ground does not hold already
      function Turned_Only (U, V : Integer) return Boolean is
        (Under_Turn (F, U, V)
         and then not (U in -Apron_L (F) .. F.W - 1 + Apron_R (F) and then V in -Front_Of (F, U) .. V_Hi (F)));
   begin
      if Yard_Turned (F) then
         Choose_Pad_Yard (F);
         return;
      end if;
      for U in -Apron_L (F) .. F.W - 1 + Apron_R (F) loop
         for V in -Front_Of (F, U) .. V_Hi (F) loop
            Tops (U, V) := Lot_Cell (H_X (F, U, V), H_Y (F, U, V)) - 1;
         end loop;
      end loop;
      if F.Turn_Ground then
         for U in Bx.U0 .. Bx.U1 loop
            for V in Bx.V0 .. Bx.V1 loop
               if Turned_Only (U, V) then
                  Tops (U, V) := Lot_Cell (H_X (F, U, V), H_Y (F, U, V)) - 1;
               end if;
            end loop;
         end loop;
      end if;
      Fill_Hollows (Tops);
      for V in 0 .. F.D - 1 loop
         for U in 0 .. F.W - 1 loop
            Lo := Integer'Min (Lo, Tops (U, V));
            Hi := Integer'Max (Hi, Tops (U, V));
         end loop;
      end loop;
      if F.Turn_Ground then
         for U in Bx.U0 .. Bx.U1 loop
            for V in Bx.V0 .. Bx.V1 loop
               if Under_Turn (F, U, V, Margin => 0) and then Tops (U, V) >= 0 then
                  Lo := Integer'Min (Lo, Tops (U, V));
                  Hi := Integer'Max (Hi, Tops (U, V));
               end if;
            end loop;
         end loop;
      end if;
      for Level in reverse Lo .. Hi loop
         F.Pad := Level + 1;
         declare
            Cut, Fill : Natural := 0;
         begin
            for U in -Apron_L (F) .. F.W - 1 + Apron_R (F) loop
               for V in -Front_Of (F, U) .. V_Hi (F) loop
                  declare
                     T : constant Integer := Tops (U, V);
                  begin
                     if T >= 0 and then T > Level then
                        Cut := Cut + T - Level;
                     elsif T >= 0 then
                        Fill := Fill + Level - T;
                     end if;
                  end;
               end loop;
            end loop;
            if F.Turn_Ground then
               for U in Bx.U0 .. Bx.U1 loop
                  for V in Bx.V0 .. Bx.V1 loop
                     if Turned_Only (U, V) and then Tops (U, V) >= 0 then
                        if Tops (U, V) > Level then
                           Cut := Cut + Tops (U, V) - Level;
                        else
                           Fill := Fill + Level - Tops (U, V);
                        end if;
                     end if;
                  end loop;
               end loop;
            end if;
            exit when Cut >= Fill;
         end;
      end loop;
   end Choose_Pad;

   --  A house's front yard as it is placed: at each place along its front,
   --  the free ground of its zone straight out from its front wall's line,
   --  as far as that goes (to its path's edge, as a rule).
   procedure Front_Yard (F : in out CB.House) is
      Most : constant Natural := Front_Most (F);
   begin
      F.Front := [others => 0];
      for U in -Apron_L (F) .. F.W - 1 + Apron_R (F) loop
         declare
            N : Natural := 0;
         begin
            while N < Most and then Lot_Cell (Y_X (F, U, -(N + 1)), Y_Y (F, U, -(N + 1))) > 0 loop
               N := N + 1;
            end loop;
            --  (straight out past the end of its path, or to something else
            --  in the way: no further than the least a yard is)
            if N = Most
              or else not Near_Path ((Float (Y_X (F, U, -(N + 1))) + 0.5) * 0.25,
                                     (Float (Y_Y (F, U, -(N + 1))) + 0.5) * 0.25, 0.0)
            then
               --  (a storehouse's: its staging, at the least: its own, as it was begun)
               N := Natural'Min (N, (if Is_Store (F) then Integer'Max (1, -F.Yard_V0) else CB.Apron_Front_B));
            end if;
            F.Front (U) := N;
         end;
      end loop;
   end Front_Yard;

   --  The way out from a house's door to its path, on the grid: how many
   --  block columns of the zone's free ground lie between its front wall
   --  and the path's ground (the least, of its door's columns), and the row
   --  of the ground where that way meets the path.  None (0): something
   --  that is not a path lies across it, or no path is come to.
   procedure Door_Way (F : in out CB.House) is
      Most : constant Natural := Front_Most (F);
      Run  : Natural := Most + 1;
      Row  : Integer := F.Pad - 1;
      Row_U : Integer := Integer'First / 4;      --  (the column Row was read at)
      Mid_2 : constant Integer := Way_Lo (F) + Way_Hi (F);
   begin
      F.Door_Run := 0;
      F.Door_Row := F.Pad - 1;
      for U in Way_Lo (F) .. Way_Hi (F) loop
         declare
            N : Natural := 0;
         begin
            while N < Most and then Lot_Cell (Y_X (F, U, -(N + 1)), Y_Y (F, U, -(N + 1))) > 0 loop
               N := N + 1;
            end loop;
            if N = 0 or else N = Most
              or else not Near_Path ((Float (Y_X (F, U, -(N + 1))) + 0.5) * 0.25,
                                     (Float (Y_Y (F, U, -(N + 1))) + 0.5) * 0.25, 0.0)
            then
               return;
            end if;
            --  (the shortest; of a way at an end of a stockyard's front, of the shortest the one
            --  nearest its middle, so that the path is read at the same place of either end)
            if N < Run or else (At_End (F) and then N = Run and then abs (2 * U - Mid_2) < abs (2 * Row_U - Mid_2)) then
               Run := N;
               Row := Lot_Cell (Y_X (F, U, -N), Y_Y (F, U, -N)) - 1;
               Row_U := U;
            end if;
         end;
      end loop;
      F.Door_Run := Run;
      F.Door_Row := Row;
   end Door_Way;

   --  **Where a stockyard's stair stands** (the spec, "The stockyard's stair in a corner of the
   --  zone"; John, 2026-11-21: "The path level at one corner is great, move the stair to the
   --  opposite corner instead of the center, if a stair is to be had it's to be at the corner of
   --  the zone", and "I was talking about the stockyard having the stair in the corner rather than
   --  the middle").  G is a storehouse tried where it is to stand, its pad's level chosen and its
   --  way in across the staging at the middle of its front read (Try_Lot): **the floor's level is
   --  judged there as it always was, and is not moved by this.**  Where that way would have steps
   --  (the path more than Retain_Over_B off the floor there), the way in is at an end of the
   --  stockyard's front instead, read at each end as the middle was:
   --    * an end is **level** where the path lies within Retain_Over_B of the floor there, and
   --      **takes a stair** where it lies Retain_Over_B + 1 to Yard_Step_B blocks off it and the
   --      flight has room (clear of the storehouse's own walls and eaves, or ending with its
   --      landing before the line of its front wall);
   --    * one end level and the other taking a stair: the stair at the other, the opposite corner;
   --    * both taking one: the lower bank's (the shorter flight), of two as high the end nearer
   --      the homestake, of two as near the low end;
   --    * one taking a stair and the other neither: the one that takes it;
   --    * a level end and no end that takes a stair: no stair; the way in is the level end (the
   --      nearer the homestake of two);
   --    * neither end level nor taking one (the path does not reach them, or lies over two metres
   --      off at both): the way stays at the middle, with its stair.
   type End_Read is record
      Run   : Natural := 0;       --  block columns from the front wall's line to the path there (0: no way)
      Bank  : Natural := 0;       --  blocks between the path and the floor there
      Level : Boolean := False;
      Takes : Boolean := False;
   end record;
   type End_Reads is array (1 .. 2) of End_Read;
   procedure Choose_Way_End (G : in out CB.House) is
      Mid_Run : constant Natural := G.Door_Run;
      Mid_Row : constant Integer := G.Door_Row;
      E    : End_Reads;
      Row  : array (1 .. 2) of Integer := [others => 0];
      Pick : Natural := 0;
      --  (the end nearer the homestake, by a metre or more; else the low end)
      function Nearer return Positive is
         function Dist (K : Positive) return Float is
           (Flat_Dist (Stake_At, Y_Point (G, Float (End_Way_U (G, K)) + Float (CB.Store_Door_W_B - 1) / 2.0,
                                          -Float (E (K).Run))));
      begin
         return (if Stake_Set and then Dist (2) < Dist (1) - 1.0 then 2 else 1);
      end Nearer;
   begin
      for K in 1 .. 2 loop
         G.Way_End := K;
         Door_Way (G);
         E (K).Run := G.Door_Run;
         Row (K) := G.Door_Row;
         if G.Door_Run > 0 then
            E (K).Bank := abs (G.Door_Row - (G.Pad - 1));
            E (K).Level := E (K).Bank <= Retain_Over_B;
            E (K).Takes := E (K).Bank in Retain_Over_B + 1 .. Yard_Step_B
              and then (Way_Hi (G) <= -3 or else Way_Lo (G) >= G.W + 2
                        or else E (K).Bank + CB.Door_Landing_B <= G.Door_Run);
         end if;
      end loop;
      if E (1).Takes and then E (2).Takes then
         Pick := (if E (1).Bank < E (2).Bank then 1 elsif E (2).Bank < E (1).Bank then 2 else Nearer);
      elsif E (1).Takes then
         Pick := 1;
      elsif E (2).Takes then
         Pick := 2;
      elsif E (1).Level and then E (2).Level then
         Pick := Nearer;
      elsif E (1).Level then
         Pick := 1;
      elsif E (2).Level then
         Pick := 2;
      end if;
      G.Way_End := Pick;
      if Pick = 0 then
         G.Door_Run := Mid_Run;
         G.Door_Row := Mid_Row;
      else
         G.Door_Run := E (Pick).Run;
         G.Door_Row := Row (Pick);
      end if;
   end Choose_Way_End;

   --  **A stockyard's floor at its path's level at the lower corner of its front** (the spec of
   --  that name; John, 2026-11-22: "Set the floors level of the stockyard to the path level at the
   --  lower corner, the higher corner along the path gets the stairs", and "After 2m no stair
   --  built").
   --  Path_At: the path beside the way at an end of a stockyard's front (K = 1, 2: the low end and
   --  the high end of its design) or at the middle of its storehouse's front (0), as Door_Way finds
   --  it.  Run: the block columns of the stockyard's own ground from the front wall's line to the
   --  path there, the least of the way's columns (0: no way there: something that is not a path
   --  lies across one of them, or no path is come to).  Row: the row of **the path's own ground**
   --  beside the way, its nearest block column (the path's top where it is laid; the land's on its
   --  line where it is still to lay), the middle one of the way's columns'.  (The stockyard's own
   --  outermost column, which Door_Way reads, can lie two blocks off a path that was brought level:
   --  a floor set by it would meet such a path with the very step this rule is to take away.  The
   --  middle one of eight: a stone or a hole on the path's edge is not the path's level.)
   procedure Path_At (G : in out CB.House; K : Natural; Its_Line : Boolean; Run : out Natural; Row : out Integer) is
      Most : constant Natural := Front_Most (G);
      Rows : Top_Row;
      N_R  : Natural := 0;
   begin
      G.Way_End := K;
      Run := Most + 1;
      Row := G.Pad - 1;
      for U in Way_Lo (G) .. Way_Hi (G) loop
         declare
            N : Natural := 0;
         begin
            while N < Most and then Lot_Cell (Y_X (G, U, -(N + 1)), Y_Y (G, U, -(N + 1))) > 0 loop
               N := N + 1;
            end loop;
            --  (Its_Line: its stockyard was put down whole, its front the line of its own path: what
            --  lies just beyond its ground there is that line, whether or not a path could be laid on
            --  all of it.  Asked only whether a path is come to, the plan, which takes the whole line
            --  as lying there, said yes of a stockyard whose path was then left unlaid at one corner,
            --  and the click did not.)
            if N = 0 or else N = Most
              or else (not Its_Line
                       and then not Near_Path ((Float (Y_X (G, U, -(N + 1))) + 0.5) * 0.25,
                                               (Float (Y_Y (G, U, -(N + 1))) + 0.5) * 0.25, 0.0))
            then
               Run := 0;
               return;
            end if;
            Run := Natural'Min (Run, N);
            declare
               Own : constant Integer := Lot_Cell (Y_X (G, U, -N), Y_Y (G, U, -N)) - 1;
               P   : constant Integer := Top_By (Y_X (G, U, -(N + 1)), Y_Y (G, U, -(N + 1)), Own);
            begin
               if N_R < Top_Row'Last then
                  N_R := N_R + 1;
                  Rows (N_R) := (if P >= 0 then P else Own);
               end if;
            end;
         end;
      end loop;
      for I in 2 .. N_R loop                          --  (a few: sorted in place)
         declare
            X : constant Integer := Rows (I);
            J : Natural := I - 1;
         begin
            while J >= 1 and then Rows (J) > X loop
               Rows (J + 1) := Rows (J);
               J := J - 1;
            end loop;
            Rows (J + 1) := X;
         end;
      end loop;
      Row := Rows ((N_R + 1) / 2);
   end Path_At;

   --  Floor_By_Path: G, a storehouse tried where it is to stand on a stockyard that is levelled,
   --  its front yard read.  Ok: both ends of the stockyard's front can be read: of a stockyard put
   --  down whole (Its_Line), always, by the line of its own path; of one zoned between two corners,
   --  where a path runs beside both (beside a path that ends short of a corner it is judged as
   --  before: Try_Lot).  Then:
   --    * **its floor's top is the path's row at the lower of the two ends** (of two as low, the
   --      end nearer the homestake by a metre or more, else the end its design counts from), so
   --      that the path comes in level there, whatever the land does under the rest of it (it was
   --      the highest level at which what is dug off the lot fills its hollows, held within the
   --      steps that fit before the storehouse of the path at the middle of its front);
   --    * **the stair stands at the other end, the higher corner along the path**, where the path
   --      lies Retain_Over_B + 1 to Yard_Step_B blocks over the floor there and the flight has room
   --      (Choose_Way_End's test): its way in is that end;
   --    * where the path lies within Retain_Over_B of the floor at the higher end too, and at the
   --      middle of the storehouse's front, there is no stair and the way in is across the staging
   --      at that middle, as it always was on level ground;
   --    * otherwise (the higher end over Yard_Step_B, two metres: his "After 2m no stair built"; or
   --      no room for the flight; or a hump or a dip at the middle alone) there is no stair, and the
   --      way in is the level end.
   --  **One row, read once**: the row left in Door_Row is the row the floor was set against, read
   --  the same way (Path_At), so the flight is as long as the bank (End_Steps); both are kept with
   --  the storehouse and nothing reads the path again.
   procedure Floor_By_Path (G : in out CB.House; Its_Line : Boolean; Ok : out Boolean) is
      Run  : array (0 .. 2) of Natural := [others => 0];
      Row  : array (0 .. 2) of Integer := [others => 0];
      Lo, Hi, Pick : Natural;
      function Nearer return Positive is
         function Dist (K : Positive) return Float is
           (Flat_Dist (Stake_At, Y_Point (G, Float (End_Way_U (G, K)) + Float (CB.Store_Door_W_B - 1) / 2.0,
                                          -Float (Run (K)))));
      begin
         return (if Stake_Set and then Dist (2) < Dist (1) - 1.0 then 2 else 1);
      end Nearer;
   begin
      for K in 0 .. 2 loop
         Path_At (G, K, Its_Line, Run (K), Row (K));
      end loop;
      G.Way_End := 0;
      Ok := Run (1) > 0 and then Run (2) > 0;
      if not Ok then
         return;
      end if;
      Lo := (if Row (1) < Row (2) then 1 elsif Row (2) < Row (1) then 2 else Nearer);
      Hi := 3 - Lo;
      G.Pad := Row (Lo) + 1;
      declare
         Bank : constant Natural := Row (Hi) - Row (Lo);
         Room : Boolean;
      begin
         G.Way_End := Hi;
         Room := Way_Hi (G) <= -3 or else Way_Lo (G) >= G.W + 2 or else Bank + CB.Door_Landing_B <= Run (Hi);
         Pick := (if Bank in Retain_Over_B + 1 .. Yard_Step_B and then Room then Hi
                  elsif Bank <= Retain_Over_B and then Run (0) > 0 and then abs (Row (0) - Row (Lo)) <= Retain_Over_B
                  then 0
                  else Lo);
      end;
      G.Way_End := Pick;
      G.Door_Run := Run (Pick);
      G.Door_Row := Row (Pick);
   end Floor_By_Path;

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

   --  A house where it is put, on the grid as it is filled: its yard to its
   --  path, its pad's level and its door's way worked out.  Verdict: how its
   --  lot lies; Ok: it can stand there, its door got to from its path.
   --  (Fronts_Own: a storehouse's stockyard was put down whole, its front the line of its own path.)
   procedure Try_Lot (G : in out CB.House; Verdict : out Lot_Verdict; Ok : out Boolean; Fronts_Own : Boolean := False) is
   begin
      Ok := False;
      G.Door_Run := 0;
      Verdict := Check_Lot (G);
      if Verdict /= Clear then
         return;
      end if;
      Front_Yard (G);
      --  a stockyard that is levelled, its stair in a corner of the zone: its floor at its path's
      --  level at the lower corner of its front, its stair at the higher (where the path runs beside
      --  both corners; where it does not, as before)
      if Yard_Site (G) and then Yard_Corner_On and then Yard_Low_On then
         Floor_By_Path (G, Fronts_Own, Ok);
         if Ok then
            return;
         end if;
         G.Door_Run := 0;
      end if;
      Choose_Pad (G);
      G.Way_End := 0;                       --  (its floor's level is judged by the middle of its front, as ever)
      Door_Way (G);
      --  its door has to be got to from the path: a pad that would stand
      --  higher over the path's ground than its door's way can step down is
      --  cut deeper; one that would lie further below it steps back for a
      --  longer way, if there is room
      if G.Door_Run > 0 and then G.Pad - 1 > G.Door_Row + Door_Steps (G) then
         G.Pad := G.Door_Row + Door_Steps (G) + 1;
      end if;
      Ok := G.Door_Run > 0 and then G.Pad - 1 >= G.Door_Row - Door_Steps (G);
      --  a stockyard whose way in would have steps there: its stair in a corner of the zone
      --  (a stockyard that is levelled: with Set_Yard_Level off a storehouse's ground is its own pad
      --  and the yard before its front, the ends of its stockyard's front are not its ground to make,
      --  and its way stays where it was)
      if Ok and then Yard_Site (G) and then Yard_Corner_On and then abs (G.Door_Row - (G.Pad - 1)) > Retain_Over_B then
         Choose_Way_End (G);
      end if;
   end Try_Lot;

   --  Where on the grid, as it is filled, the house of that serial goes:
   --  the free frontage nearest the homestake.  Its front wall stands a
   --  setback off the path's edge, the house square to the block grid and
   --  facing the path; where a path's ground is in the way (the path runs
   --  aslant) it steps back, Max_Push_B at most.
   --  The eighth of a turn a hovel placed as F is drawn by (the spec, Set_House_Turn): by the path
   --  nearest the ground before its door.
   procedure Grid_Way (S : Path_Seg; Sx, Sy : out Integer);     --  (its body is with the paths, below)
   Turn_On : Boolean := True;
   procedure Set_House_Turn (On : Boolean) is
   begin
      Turn_On := On;
   end Set_House_Turn;
   function House_Turn_On return Boolean is (Turn_On);
   Turn_Ground_On : Boolean := True;
   procedure Set_Turn_Ground (On : Boolean) is
   begin
      Turn_Ground_On := On;
   end Set_Turn_Ground;
   function Turn_Ground return Boolean is (Turn_Ground_On);
   --  (whether a hovel placed turned from now on is walked where it is drawn: the spec, Set_Hovel_Walk)
   Hovel_Walk_On : Boolean := True;
   procedure Set_Hovel_Walk (On : Boolean) is
   begin
      Hovel_Walk_On := On;
   end Set_Hovel_Walk;
   function Hovel_Walk return Boolean is (Hovel_Walk_On);
   Keep_Off_On : Boolean := True;
   Kept_Key    : Integer := -1;              --  (what the walking map was last told; -1: nothing yet)
   procedure Set_Keep_Off (On : Boolean) is
   begin
      Keep_Off_On := On;
   end Set_Keep_Off;
   function Keep_Off return Boolean is (Keep_Off_On);
   function Turn_For (F : CB.House) return Integer is
      Door   : constant Vec3 := H_Point (F, Float (Way_Lo (F) + Way_Hi (F)) / 2.0, -1.0);
      Best   : Natural := 0;
      Best_D : Float := Float'Last;
      Sx, Sy : Integer;
   begin
      if not Turn_On or else Is_Store (F) then
         return 0;
      end if;
      for K in 1 .. N_Paths loop
         if Seg_Dist (Door, Path_List (K)) < Best_D then
            Best_D := Seg_Dist (Door, Path_List (K));
            Best := K;
         end if;
      end loop;
      if Best = 0 then
         return 0;
      end if;
      Grid_Way (Path_List (Best), Sx, Sy);
      if Sx = 0 or else Sy = 0 then                  --  (straight, or not on the grid: as it stands)
         return 0;
      end if;
      --  its front (Ux, Uy) turned to the left lies along (Ux - Uy, Ux + Uy); to the right, (Ux + Uy, Uy - Ux)
      return (if (F.Ux - F.Uy) * Sy - (F.Ux + F.Uy) * Sx = 0 then 1
              elsif (F.Ux + F.Uy) * Sy - (F.Uy - F.Ux) * Sx = 0 then -1 else 0);
   end Turn_For;

   --  The timbers a house laid out now is to have: what a lot is given when
   --  it is laid out, and given again when it is read from a save.  **A lot
   --  is saved as its place alone, its design made anew from its serial's
   --  seed**: whatever is added to a design after CB.Design must be added
   --  here, or a lot loses it in a save.  (Until 2026-11-21 the loader left
   --  these four as the design alone has them, and every house begun after
   --  a load from a lot laid out before it was built as houses were before
   --  those passes: no trusses, no tie beams, no ridge beam, plank beside
   --  its windows.)
   procedure Give_Timbers (F : in out CB.House) is
   begin
      F.Truss := Truss_On;
      F.Sill := Sill_On;
      F.Jambs := False;
      F.Ridge := True;
      F.Full := Full_On;
   end Give_Timbers;

   procedure Place_House (Serial : Positive; F : out CB.House; Key : out Float; Ok : out Boolean) is
      Seed : constant U64 := House_Seed (Serial);
      Half : constant Float := Path_Width_M / 2.0;
      N    : Natural := 0;
   begin
      Ok := False;
      Key := Float'Last;
      F := CB.Design (Seed);
      Give_Timbers (F);
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
                  declare
                     Verdict : Lot_Verdict;
                     Stands  : Boolean;
                  begin
                     --  (turned to a path at 45 degrees: drawn so; and its lot and its ground
                     --  tried with the ground it is drawn on)
                     G.Turn := Turn_For (G);
                     G.Turn_Ground := Turn_Ground_On and then G.Turn /= 0;
                     G.Walk := Hovel_Walk_On and then G.Turn_Ground;
                     Try_Lot (G, Verdict, Stands);
                     if Stands then
                        F := G;
                        Key := A.Key;
                        Ok := True;
                        return;
                     end if;
                     exit when Verdict = Blocked;
                  end;
               end loop;
            end;
         end;
      end loop;
   end Place_House;

   --  The lots for the houses still to begin, laid out anew: the next house
   --  in turn on the free frontage nearest the homestake that any housing
   --  has, then the one after it with that lot taken, and so on until one
   --  fits nowhere (Lots_Short) or there are as many as there can be houses.
   --  Called when the player zones housing or lays a path, and when a lot
   --  laid out turns out not to hold its house any more.
   procedure Plan_Lots is
      F    : CB.House;
      Key  : Float;
      Fits : Boolean;
   begin
      N_Lots := 0;
      Lots_Are_Short := False;
      if N_Housing = 0 then
         return;
      end if;
      while N_Houses + N_Lots < Max_Houses loop
         declare
            Best     : CB.House;
            Best_Key : Float := Float'Last;
            Best_Z   : Natural := 0;
         begin
            for Z in 1 .. N_Zones loop
               if Zones (Z).Kind = Habitation_Zone and then Zones (Z).N > 0 then
                  Lot_Grid_Of_Zone (Z);
                  Place_House (House_Serial + N_Lots + 1, F, Key, Fits);
                  if Fits and then Key < Best_Key then
                     Best := F;
                     Best_Key := Key;
                     Best_Z := Z;
                  end if;
               end if;
            end loop;
            if Best_Z = 0 then
               Lots_Are_Short := True;
               exit;
            end if;
            N_Lots := N_Lots + 1;
            Lots (N_Lots) := (Zone => Best_Z, F => Best);
         end;
      end loop;
      Zones_Ver := Zones_Ver + 1;
   end Plan_Lots;

   function Lot_Count return Natural is (N_Lots);
   function Lot_At (K : Positive) return Lot_Corners is
      F : CB.House renames Lots (K).F;
   begin
      return [H_Point (F, -0.5, -0.5), H_Point (F, Float (F.W) - 0.5, -0.5),
              H_Point (F, Float (F.W) - 0.5, Float (F.D) - 0.5), H_Point (F, -0.5, Float (F.D) - 0.5)];
   end Lot_At;
   function Lot_Drawn_At (K : Positive) return Lot_Corners is
      F : CB.House renames Lots (K).F;
   begin
      return [Drawn_Point (F, -0.5, -0.5), Drawn_Point (F, Float (F.W) - 0.5, -0.5),
              Drawn_Point (F, Float (F.W) - 0.5, Float (F.D) - 0.5), Drawn_Point (F, -0.5, Float (F.D) - 0.5)];
   end Lot_Drawn_At;
   function Lots_Short return Boolean is (Lots_Are_Short);
   function Lot_Turn (K : Positive) return Integer is (Lots (K).F.Turn);
   function Lot_Design (K : Positive) return CB.House is (Lots (K).F);

   --  A house just begun reaches over to the ground of a house begun before
   --  it that stands beside it along the same path: their fronts the same
   --  way, their walls side by side, and nearer than another lot would fit
   --  between.  The ground between the two is then the new one's to make
   --  ready with its own, to its own level, from its path back to the end of
   --  its own back yard (so two houses stand on one terrace, or on two with
   --  one wall between, and the walls behind them meet).  Only where all of
   --  that ground is its zone's and nobody else's: a tree left standing
   --  between two houses keeps them apart.  (Its ground made ready round a
   --  tree's foot was tried: in a gap a few columns wide the tree's ground,
   --  walled, shuts the back of the gap off, and what lies behind it is a
   --  pit a serf can drop into and not climb out of.)
   procedure Join_Site (H : Positive) is
      Hs   : House_Rec renames Houses (H);
      F    : CB.House renames Hs.F;
      Most : constant := CB.Max_Push_B + CB.Setback_Max_B + 6;
      function Free (U, V : Integer) return Boolean is
        (Zone_Of_Block (H_X (F, U, V), H_Y (F, U, V)) = Hs.Zone
         and then Site_Of_Block (H_X (F, U, V), H_Y (F, U, V), But => H) = 0);
      procedure Reach (Left : Boolean) is
         Best : Natural := Natural'Last;
         function Column (G : Positive) return Integer is
           (if Left then -Apron_U (F) - G else F.W - 1 + Apron_U (F) + G);
      begin
         for K in 1 .. N_Houses loop
            if K /= H then
               declare
                  A  : CB.House renames Houses (K).F;
                  Du : constant Integer := H_U (F, A.Fx, A.Fy);
                  Dv : constant Integer := H_V (F, A.Fx, A.Fy);
                  Gap, Lot_Gap : Integer;
               begin
                  --  (one whose ground is made where it is drawn turned reaches to nobody, and nobody to it)
                  if A.Ux = F.Ux and then A.Uy = F.Uy and then A.Vx = F.Vx and then A.Vy = F.Vy
                    and then Dv <= F.D - 1 and then Dv + A.D - 1 >= 0
                    and then not A.Turn_Ground and then not F.Turn_Ground
                  then
                     if Left then
                        Gap := -Apron_U (F) - (Du + Site_U_Hi (A)) - 1;
                        Lot_Gap := -Lot_Left (F) - (Du + A.W - 1 + Lot_Right (A)) - 1;
                     else
                        Gap := (Du + Site_U_Lo (A)) - (F.W - 1 + Apron_U (F)) - 1;
                        Lot_Gap := (Du - Lot_Left (A)) - (F.W - 1 + Lot_Right (F)) - 1;
                     end if;
                     if Gap >= 0 and then Lot_Gap < CB.Lot_B and then Gap <= CB.Max_Reach_B and then Gap < Best then
                        Best := Gap;
                     end if;
                  end if;
               end;
            end if;
         end loop;
         if Best = Natural'Last or else Best = 0 then
            return;                          --  (nobody beside it; or their grounds touch as they are)
         end if;
         for G in 1 .. Best loop
            for V in -CB.Apron_Front_B .. V_Hi (F) loop
               if not Free (Column (G), V) then
                  return;
               end if;
            end loop;
         end loop;
         --  its yard before each of those columns: to its path, as before its own
         for G in 1 .. Best loop
            declare
               U : constant Integer := Column (G);
               N : Natural := CB.Apron_Front_B;
            begin
               while N < Most and then Free (U, -(N + 1)) loop
                  N := N + 1;
               end loop;
               if N = Most
                 or else not Near_Path ((Float (H_X (F, U, -(N + 1))) + 0.5) * 0.25,
                                        (Float (H_Y (F, U, -(N + 1))) + 0.5) * 0.25, 0.0)
               then
                  N := CB.Apron_Front_B;
               end if;
               F.Front (U) := N;
            end;
         end loop;
         if Left then
            F.Reach_L := Best;
         else
            F.Reach_R := Best;
         end if;
      end Reach;
   begin
      Reach (Left => True);
      Reach (Left => False);
   end Join_Site;

   --  The next house is begun, nobody's, on the first lot laid out.  The
   --  lot alone is looked at again (the ground may have been dug since it
   --  was laid out); if its house can no longer stand there, the lots are
   --  laid out anew, once.  Ok False: there is no lot.
   procedure Begin_Lot (Ok : out Boolean) is
   begin
      Ok := False;
      for Attempt in 1 .. 2 loop
         if N_Lots = 0 or else N_Houses >= Max_Houses then
            return;
         end if;
         declare
            G       : CB.House := Lots (1).F;
            Verdict : Lot_Verdict;
            Stands  : Boolean;
         begin
            Lot_Grid_Of_Zone (Lots (1).Zone, With_Lots => False);
            Try_Lot (G, Verdict, Stands);
            if Stands then
               House_Serial := House_Serial + 1;
               N_Houses := N_Houses + 1;
               Houses (N_Houses) :=
                 (Zone => Lots (1).Zone, Seed => House_Seed (House_Serial), F => G, others => <>);
               N_Lots := N_Lots - 1;
               for K in 1 .. N_Lots loop
                  Lots (K) := Lots (K + 1);
               end loop;
               Join_Site (N_Houses);
               Measure_House (N_Houses);
               Zones_Ver := Zones_Ver + 1;          --  (whatever shows the zones shows its lot)
               Ok := True;
               return;
            end if;
         end;
         exit when Attempt = 2;
         Plan_Lots;
      end loop;
   end Begin_Lot;

   --  (the eight ways a path runs: the placements' own table is below)
   Store_Way_Dx : constant array (Way_Index) of Integer := [1, 1, 0, -1, -1, -1, 0, 1];
   Store_Way_Dy : constant array (Way_Index) of Integer := [0, 1, 1, 1, 0, -1, -1, -1];

   --  The storehouse on stockyard Z (a stockpile's zone marked as the yard),
   --  if its places make a lot at least Stockyard_Least_M each way with
   --  ground for it: in the middle of the lot's front (the side nearest a
   --  path), its length along that side, its front wall Store_Yard_B back
   --  from the lot's front (the staging), its left wall on the last block of
   --  a place so that whole places lie inside it; its yard the lot, fenced
   --  behind it, a gateway beside each end; as many coverings side by side
   --  along the back as there is room for.  All of the lot's places are
   --  closed until it stands (Fit_Storehouse).
   --  (the zone's own storehouse placed, or tried: the tail both ways of laying a stockyard out share)
   procedure Begin_Storehouse (Z : Positive; G : in out CB.House; Ok : out Boolean; Try_Only : Boolean) is
      Verdict : Lot_Verdict;
      Stands  : Boolean;
   begin
      Ok := False;
      Lot_Grid_Of_Zone (Z);
      Try_Lot (G, Verdict, Stands, Fronts_Own => Zones (Z).Placed);
      if Stands and then Try_Only then
         Ok := True;                         --  (it would stand: nothing begun)
      elsif Stands then
         N_Houses := N_Houses + 1;
         Store_House := N_Houses;
         Houses (N_Houses) :=
           (Zone => Z, Seed => Castle.Hash.Hash_2 (Band_Seed, 6_003, Z), F => G, others => <>);
         Measure_House (N_Houses);
         for C in 1 .. N_Cells loop           --  (closed until it stands: zoned so, and said again)
            if Cells (C).Zone = Z then
               Cells (C).Closed := True;
            end if;
         end loop;
         Zones_Ver := Zones_Ver + 1;
         Ok := True;
      end if;
   end Begin_Storehouse;

   --  **On a stockyard laid out along a path at 45 degrees** (its zone's
   --  Turn; Set_Yard_Turn) the storehouse stands square to the grid about
   --  the middle of where it is wanted, and is drawn turned an eighth so
   --  that its front lies along the path; its yard is designed about it as
   --  a square stockyard's is, and made where the turn puts it.  The turn is
   --  about the point that puts its walls, as drawn, on its places' lines:
   --  its left wall on the last block of a place, its front wall
   --  Store_Yard_B back from the lot's front.
   --  (Store_Turned: the storehouse of such a lot, T its turn, A0 .. B1 its
   --  bounds along and across its way, metres.  (Nx, Ny): the way from its
   --  front into it where that is known, a unit (a stockyard put down whole
   --  fronts its own path); (0, 0): its front is the side nearest a path.
   --  Fits: there is room for it, and G can be tried.)
   type Corner_Pair is array (1 .. 2) of Integer;
   procedure Store_Turned (T, A0, A1, B0, B1, Nx, Ny : Float; G : out CB.House; Fits : out Boolean) is
      Ex   : constant Float := Cos (T);
      Ey   : constant Float := Sin (T);
      function Wx (A, Bb : Float) return Float is (A * Ex - Bb * Ey);
      function Wy (A, Bb : Float) return Float is (A * Ey + Bb * Ex);
      function To_Path (A, Bb : Float) return Float is
         P : constant Vec3 := (Wx (A, Bb), Wy (A, Bb), 0.0);
         D : Float := Float'Last;
      begin
         for K in 1 .. N_Paths loop
            D := Float'Min (D, Seg_Dist (P, Path_List (K)));
         end loop;
         return D;
      end To_Path;
      --  its staging: what is wanted, and no less than keeps its own blocks on its own ground.  They
      --  stand square to the grid about its middle and are drawn turned an eighth, so its corner
      --  reaches (W + D) / 2 blocks times the cosine toward the path from that middle, which lies half
      --  its depth behind its front wall as drawn; a block more for its eave.  (For 40 by 20 and for
      --  48 by 32 alike: 14.)
      Reach : constant Float := Float (Store_W_On + Store_D_On) / 2.0 * 0.707_106_78 - Float (Store_D_On) / 2.0;
      Need  : constant Integer := Integer (Float'Ceiling (Reach + 1.0));
      Stage : constant Integer := Integer'Max (Store_Stage_On, 4 * ((Need + 1) / 4) + 2);
   begin
      Fits := False;
      G := CB.Storehouse_Design (Store_W_On, Store_D_On);
      declare
         Am  : constant Float := (A0 + A1) / 2.0;
         Bm  : constant Float := (B0 + B1) / 2.0;
         D_1 : constant Float := To_Path (Am, B0);          --  its side at the least across,
         D_2 : constant Float := To_Path (Am, B1);          --  at the most across,
         D_3 : constant Float := To_Path (A0, Bm);          --  at the least along,
         D_4 : constant Float := To_Path (A1, Bm);          --  at the most along
         Least_D : constant Float := Float'Min (Float'Min (D_1, D_2), Float'Min (D_3, D_4));
         --  the design's two ways in the world: V from the lot's front into it, U along its front
         Vx, Vy, Ux, Uy : Float;
         S0, S1, T0, T1 : Float;                --  the lot along U, and along V from its front
         Given : constant Boolean := Nx /= 0.0 or else Ny /= 0.0;
      begin
         G.Truss := Truss_On;
         G.Sill := Sill_On;
         G.Jambs := False;
         G.Full := Full_On;
         G.Turn := 1;
         G.Smooth_Covers := Smooth_Covers_On;
         G.Fence_Pieces := Fence_Pieces_On;
         if (if Given then -Ey * Nx + Ex * Ny > 0.9 else D_1 = Least_D) then
            Vx := -Ey;  Vy := Ex;   T0 := B0;   T1 := B1;
         elsif (if Given then Ey * Nx - Ex * Ny > 0.9 else D_2 = Least_D) then
            Vx := Ey;   Vy := -Ex;  T0 := -B1;  T1 := -B0;
         elsif (if Given then Ex * Nx + Ey * Ny > 0.9 else D_3 = Least_D) then
            Vx := Ex;   Vy := Ey;   T0 := A0;   T1 := A1;
         else
            Vx := -Ex;  Vy := -Ey;  T0 := -A1;  T1 := -A0;
         end if;
         --  the storehouse as it stands: an eighth of a turn back from the design, its U up the grid
         declare
            C45 : constant Float := 0.707_106_78;
            Rvx : constant Float := C45 * (Vx + Vy);        --  V turned back an eighth (to the right)
            Rvy : constant Float := C45 * (Vy - Vx);
         begin
            G.Vx := Integer (Float'Rounding (Rvx));
            G.Vy := Integer (Float'Rounding (Rvy));
            if abs (Rvx - Float (G.Vx)) > 0.01 or else abs (Rvy - Float (G.Vy)) > 0.01
              or else abs G.Vx + abs G.Vy /= 1
            then
               return;                          --  (its path does not run at 45 degrees)
            end if;
            G.Ux := abs G.Vy;
            G.Uy := abs G.Vx;
            Ux := C45 * (Float (G.Ux) - Float (G.Uy));      --  U turned an eighth to the left: the design's
            Uy := C45 * (Float (G.Ux) + Float (G.Uy));
         end;
         if abs (Ux * Ex + Uy * Ey) > 0.5 then              --  (the lot along the design's U)
            S0 := Float'Min ((Ux * Ex + Uy * Ey) * A0, (Ux * Ex + Uy * Ey) * A1);
            S1 := Float'Max ((Ux * Ex + Uy * Ey) * A0, (Ux * Ex + Uy * Ey) * A1);
         else
            S0 := Float'Min ((Uy * Ex - Ux * Ey) * B0, (Uy * Ex - Ux * Ey) * B1);
            S1 := Float'Max ((Uy * Ex - Ux * Ey) * B0, (Uy * Ex - Ux * Ey) * B1);
         end if;
         declare
            Along   : constant Integer := Integer (Float'Rounding (S1 - S0)) * 4;
            Depth   : constant Integer := Integer (Float'Rounding (T1 - T0)) * 4;
            Place_K : constant Integer := Integer'Max (0, ((Along - G.W) / 2 - 1) / 4);
            Left_B  : constant Integer := 4 * Place_K + 3;          --  its left wall's column, from the lot's side
            --  where the middle of block (0, 0) of the design is, in the world (metres)
            Os : constant Float := S0 + (Float (Left_B) + 0.5) * 0.25;
            Ot : constant Float := T0 + (Float (Stage) + 0.5) * 0.25;
            Mid_U : constant Float := Float (G.W - 1) / 2.0;
            Mid_V : constant Float := Float (G.D - 1) / 2.0;
            --  the middle of the storehouse as it is to be drawn
            Cs : constant Float := Os + Mid_U * 0.25;
            Ct : constant Float := Ot + Mid_V * 0.25;
            Cx : constant Float := Cs * Ux + Ct * Vx;
            Cy : constant Float := Cs * Uy + Ct * Vy;
         begin
            --  as it stands: its middle on the block corner nearest that
            G.Fx := Integer (Float'Rounding (Cx * 4.0 - 0.5 - Mid_U * Float (G.Ux) - Mid_V * Float (G.Vx)));
            G.Fy := Integer (Float'Rounding (Cy * 4.0 - 0.5 - Mid_U * Float (G.Uy) - Mid_V * Float (G.Vy)));
            declare
               Mid : constant Vec3 := H_Point (G, Mid_U, Mid_V);
               --  how far off the wanted middle it stands, in its frame (blocks)
               Du  : constant Float := ((Cx - Mid.X) * Float (G.Ux) + (Cy - Mid.Y) * Float (G.Uy)) * 4.0;
               Dv  : constant Float := ((Cx - Mid.X) * Float (G.Vx) + (Cy - Mid.Y) * Float (G.Vy)) * 4.0;
               C45 : constant Float := 0.707_106_78;
               Sn  : constant Float := Float (G.Turn * (G.Ux * G.Vy - G.Uy * G.Vx)) * C45;
               K   : constant Float := 1.0 / (2.0 * (1.0 - C45));
            begin
               --  the turn's middle: the point that, turned about, carries its middle that far
               G.Piv_U := Mid_U + K * ((1.0 - C45) * Du - Sn * Dv);
               G.Piv_V := Mid_V + K * (Sn * Du + (1.0 - C45) * Dv);
            end;
            G.Yard_V0 := -Stage;
            G.Yard_V1 := -Stage + Depth - 1;
            G.Yard_U0 := -Left_B;
            G.Yard_U1 := Along - 1 - Left_B;
            G.Gate_U := 0;
            declare
               N     : constant Natural := Natural'Min (CB.Max_Covers, Integer'Max (0, Along - 8) / CB.Cover_W_B);
               First : constant Integer := 4 * Integer'Max (1, (Along - N * CB.Cover_W_B) / 8);
            begin
               G.Covers := N;
               for Kc in 1 .. N loop
                  G.Cover_U (Kc) := First + (Kc - 1) * CB.Cover_W_B - Left_B;
               end loop;
            end;
            Fits := G.Yard_U0 <= -CB.Apron_B - 2 and then G.Yard_U1 >= G.W - 1 + CB.Apron_B + 2
              and then G.Yard_V1 >= G.D - 1 + CB.Apron_B + 4 + CB.Cover_D_B
              and then G.Yard_U0 >= G.Front'First and then G.Yard_U1 <= G.Front'Last
              and then CB.Yard_Clashes (G) = 0;         --  (nothing of its yard where its own blocks stand)
            --  and its own blocks, as they stand, all on its stockyard's ground: each corner of them, and
            --  of its eaves a block out, is a place of its yard as designed
            if Fits then
               for Cu of Corner_Pair'(-1, G.W) loop
                  for Cv of Corner_Pair'(-1, G.D) loop
                     declare
                        Du, Dv : Integer;
                     begin
                        CB.Design_Of (G, Cu, Cv, Du, Dv);
                        if Du not in G.Yard_U0 .. G.Yard_U1 or else Dv not in G.Yard_V0 .. G.Yard_V1 then
                           Fits := False;
                        end if;
                     end;
                  end loop;
               end loop;
            end if;
         end;
      end;
   end Store_Turned;

   --  (The way from the front of zone Z into it, if it was put down whole: its own path lies along
   --  its front, and it lies on the left of the way that runs.  Else nought.)
   procedure Front_Of_Zone (Z : Positive; Nx, Ny : out Float) is
      Dx : constant Float := Float (Store_Way_Dx (Zones (Z).Way));
      Dy : constant Float := Float (Store_Way_Dy (Zones (Z).Way));
      L  : constant Float := Sqrt (Dx * Dx + Dy * Dy);
   begin
      if Zones (Z).Placed then
         Nx := -Dy / L;
         Ny := Dx / L;
      else
         Nx := 0.0;
         Ny := 0.0;
      end if;
   end Front_Of_Zone;

   procedure Place_Storehouse_Turned (Z : Positive; Ok : out Boolean; Try_Only : Boolean) is
      T    : constant Float := Zones (Z).Turn;
      Ex   : constant Float := Cos (T);
      Ey   : constant Float := Sin (T);
      A0, B0 : Float := Float'Last;           --  the lot along and across its way: whole metres
      A1, B1 : Float := Float'First;
      Nx, Ny : Float;
      G    : CB.House;
      Fits : Boolean;
   begin
      Ok := False;
      Front_Of_Zone (Z, Nx, Ny);
      for C in 1 .. N_Cells loop
         if Cells (C).Zone = Z and then not Cells (C).Overflow then
            declare
               A  : constant Float := Cells (C).Centre.X * Ex + Cells (C).Centre.Y * Ey;
               Bb : constant Float := Cells (C).Centre.Y * Ex - Cells (C).Centre.X * Ey;
            begin
               if Zones (Z).Placed then
                  --  (put down whole: its metres are its own, counted from its front's beginning)
                  A0 := Float'Min (A0, A - 0.5);
                  A1 := Float'Max (A1, A + 0.5);
                  B0 := Float'Min (B0, Bb - 0.5);
                  B1 := Float'Max (B1, Bb + 0.5);
               else
                  A0 := Float'Min (A0, Float'Rounding (A - 0.5));
                  A1 := Float'Max (A1, Float'Rounding (A + 0.5));
                  B0 := Float'Min (B0, Float'Rounding (Bb - 0.5));
                  B1 := Float'Max (B1, Float'Rounding (Bb + 0.5));
               end if;
            end;
         end if;
      end loop;
      if A0 > A1 or else A1 - A0 < Stockyard_Least_M or else B1 - B0 < Stockyard_Least_M then
         return;
      end if;
      Store_Turned (T, A0, A1, B0, B1, Nx, Ny, G, Fits);
      if Fits then
         Begin_Storehouse (Z, G, Ok, Try_Only);
      end if;
   end Place_Storehouse_Turned;

   --  (Store_Squarely: the storehouse of a lot square to the grid, block columns X0 .. X1 by
   --  Y0 .. Y1.  (Vx, Vy): the way from its front into it where that is known (a stockyard put down
   --  whole); (0, 0): its front is the side whose middle is nearest a path's.  Fits: there is room
   --  for it, and G can be tried.)
   procedure Store_Squarely (X0, Y0, X1, Y1 : Integer; Vx, Vy : Integer; G : out CB.House; Fits : out Boolean) is
      --  which side of the lot its path is: the side whose middle is nearest a path's
      function To_Path (X, Y : Integer) return Float is
         P : constant Vec3 := ((Float (X) + 0.5) * 0.25, (Float (Y) + 0.5) * 0.25, 0.0);
         D : Float := Float'Last;
      begin
         for K in 1 .. N_Paths loop
            D := Float'Min (D, Seg_Dist (P, Path_List (K)));
         end loop;
         return D;
      end To_Path;
      Xm : constant Integer := (X0 + X1) / 2;
      Ym : constant Integer := (Y0 + Y1) / 2;
      D_S : constant Float := To_Path (Xm, Y0);
      D_N : constant Float := To_Path (Xm, Y1);
      D_W : constant Float := To_Path (X0, Ym);
      D_E : constant Float := To_Path (X1, Ym);
      Least_D : constant Float := Float'Min (Float'Min (D_S, D_N), Float'Min (D_W, D_E));
      Given : constant Boolean := Vx /= 0 or else Vy /= 0;
      Along, Depth : Integer;                --  the lot's places, in blocks, along its front and back from it
   begin
      G := CB.Storehouse_Design (Store_W_On, Store_D_On);
      G.Truss := Truss_On;
      G.Full := Full_On;
      G.Sill := Sill_On;
      G.Jambs := False;
      G.Smooth_Covers := Smooth_Covers_On;
      if (if Given then Vy /= 0 else D_S = Least_D or else D_N = Least_D) then
         G.Ux := 1;
         G.Uy := 0;
         G.Vx := 0;
         G.Vy := (if Given then Vy elsif D_S = Least_D then 1 else -1);
         Along := X1 - X0 + 1;
         Depth := Y1 - Y0 + 1;
      else
         G.Ux := 0;
         G.Uy := 1;
         G.Vx := (if Given then Vx elsif D_W = Least_D then 1 else -1);
         G.Vy := 0;
         Along := Y1 - Y0 + 1;
         Depth := X1 - X0 + 1;
      end if;
      declare
         --  the lot's front row and its first column along U, in the world
         Front_Y : constant Integer := (if G.Vy > 0 then Y0 elsif G.Vy < 0 then Y1 else 0);
         Front_X : constant Integer := (if G.Vx > 0 then X0 elsif G.Vx < 0 then X1 else 0);
         U_Start : constant Integer := (if G.Ux = 1 then X0 else Y0);   --  (U runs up the grid)
         --  its left wall's column along U: the last block of a place, as near the middle as that lets it be
         Place_K : constant Integer := Integer'Max (0, ((Along - G.W) / 2 - 1) / 4);
         U0      : constant Integer := U_Start + 4 * Place_K + 3;
      begin
         if G.Vx = 0 then
            G.Fx := U0;
            G.Fy := Front_Y + G.Vy * Store_Stage_On;
         else
            G.Fy := U0;
            G.Fx := Front_X + G.Vx * Store_Stage_On;
         end if;
         G.Yard_V0 := -Store_Stage_On;
         G.Yard_V1 := -Store_Stage_On + Depth - 1;
         G.Yard_U0 := U_Start - U0;
         G.Yard_U1 := U_Start + Along - 1 - U0;
         G.Gate_U := 0;
         --  the coverings: side by side along the back, on the lot's whole metres, a place clear at each side
         declare
            N     : constant Natural := Natural'Min (CB.Max_Covers, Integer'Max (0, Along - 8) / CB.Cover_W_B);
            First : constant Integer := 4 * Integer'Max (1, (Along - N * CB.Cover_W_B) / 8);   --  from the lot's side
         begin
            G.Covers := N;
            for K in 1 .. N loop
               G.Cover_U (K) := U_Start + First + (K - 1) * CB.Cover_W_B - U0;
            end loop;
         end;
         Fits := G.Yard_U0 <= -CB.Apron_B - 2 and then G.Yard_U1 >= G.W - 1 + CB.Apron_B + 2
           and then G.Yard_V1 >= G.D - 1 + CB.Apron_B + 4 + CB.Cover_D_B
           and then G.Yard_U0 >= G.Front'First and then G.Yard_U1 <= G.Front'Last;
      end;
   end Store_Squarely;

   procedure Place_Storehouse (Z : Positive; Ok : out Boolean; Try_Only : Boolean := False) is
      X0, Y0 : Integer := Integer'Last;
      X1, Y1 : Integer := Integer'First;
      Least  : constant Integer := Integer (Stockyard_Least_M) * 4;
      Nx, Ny : Float;
      G      : CB.House;
      Fits   : Boolean;
   begin
      Ok := False;
      if not Zones (Z).Yard or else N_Houses >= Max_Houses then
         return;
      end if;
      if abs Zones (Z).Turn > 0.01 then           --  (laid out along a path at 45 degrees)
         Place_Storehouse_Turned (Z, Ok, Try_Only);
         return;
      end if;
      for C in 1 .. N_Cells loop
         if Cells (C).Zone = Z and then not Cells (C).Overflow then
            X0 := Integer'Min (X0, B (Cells (C).Centre.X - 0.4));
            X1 := Integer'Max (X1, B (Cells (C).Centre.X + 0.4));
            Y0 := Integer'Min (Y0, B (Cells (C).Centre.Y - 0.4));
            Y1 := Integer'Max (Y1, B (Cells (C).Centre.Y + 0.4));
         end if;
      end loop;
      if X0 > X1 or else X1 - X0 + 1 < Least or else Y1 - Y0 + 1 < Least then
         return;
      end if;
      Front_Of_Zone (Z, Nx, Ny);
      Store_Squarely (X0, Y0, X1, Y1, Integer (Nx), Integer (Ny), G, Fits);
      if Fits then
         Begin_Storehouse (Z, G, Ok, Try_Only);
      end if;
   end Place_Storehouse;

   --  The second morning's request (the advisor's, simulated): once asked,
   --  the stockyard, if one is zoned and takes a storehouse, gets it; with
   --  none, asked again every game hour (and when one is zoned).
   procedure Ask_Storehouse is
      Ok : Boolean := False;
   begin
      if not Store_On or else not Stake_Set or else Store_House > 0 then
         return;
      end if;
      if Stake_Day < 0 then
         Stake_Day := Integer (Long_Float'Floor (Now_Hours / 24.0));
      end if;
      if not Store_Asked then
         if Now_Hours < Long_Float (Stake_Day + 1) * 24.0 + Long_Float (Store_Morning_H) then
            return;
         end if;
         Store_Asked := True;
         Store_Note_N := Store_Note_N + 1;
      elsif (Tick_N / Tick_Hz) mod 60 /= 0 then
         return;                                --  (again every game hour: 60 colony seconds; asked
                                                --  once a colony second, so by the second, not the tick)
      end if;
      for Z in 1 .. N_Zones loop
         if Zones (Z).Kind = Stockpile_Zone and then Zones (Z).Yard then
            Place_Storehouse (Z, Ok);
            if Ok then
               Store_Note_N := Store_Note_N + 1;
               return;
            end if;
         end if;
      end loop;
   end Ask_Storehouse;

   function Storehouse_Note_Key return Natural is (Store_Note_N);
   function Stockpile_Number (Z : Positive) return Natural is
      N : Natural := 0;
   begin
      if Z > N_Zones or else Zones (Z).Kind /= Stockpile_Zone then
         return 0;
      end if;
      for K in 1 .. Z loop           --  (one the player has removed is no stockpile: its zone is kept, empty)
         if Zones (K).Kind = Stockpile_Zone and then not Zones (K).Yard and then Zones (K).N > 0 then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Stockpile_Number;
   function Stockyard return Natural is
   begin
      for Z in 1 .. N_Zones loop
         if Zones (Z).Kind = Stockpile_Zone and then Zones (Z).Yard then
            return Z;
         end if;
      end loop;
      return 0;
   end Stockyard;
   function Storehouse_Note return String is
     (if not Store_On or else not Store_Asked then ""
      elsif Store_House > 0
      then "The storehouse goes on the stockyard: the builders will raise it, fence its yard and roof its coverings"
      elsif Stockyard > 0
      then "The stockyard's ground will no longer take a storehouse: it has been dug or built on since it was zoned"
      elsif Yard_Box_On
      then "A storehouse wants a stockyard," & Integer'Image (Integer (Stockyard_Side_M)) & " m by"
           & Integer'Image (Integer (Stockyard_Side_M)) & " m with its path: put one down (Stockyard, in the tools)"
      else "A storehouse wants a stockyard of" & Integer'Image (Integer (Stockyard_Least_M)) & " m by"
           & Integer'Image (Integer (Stockyard_Least_M)) & " m beside a path: zone one (Stockyard, in the tools)");

   --  A house that stands and is nobody's is drawn for by lot among the
   --  living who have none (John, 2026-11-12: "just assign it to them by
   --  lottery, when the construction is complete").  The draw is made from
   --  the house's seed and how many are in it: the same house among the same
   --  people falls to the same one.
   procedure Draw_Owner (H : Positive) is
      N : Natural := 0;
   begin
      if Houses (H).Owner /= 0 or else not Houses (H).Built or else Houses (H).F.Kind /= CB.Hovel
        or else Houses (H).Raze                    --  (one marked for razing is nobody's)
      then
         return;
      end if;
      for I in 1 .. N_Members loop
         if not Band (I).Is_Dead and then Home_Of (I) = 0 then
            N := N + 1;
         end if;
      end loop;
      if N = 0 then
         return;
      end if;
      declare
         Pick : Natural := Natural (Castle.Hash.Hash_2 (Houses (H).Seed, 6_101, N) mod U64 (N)) + 1;
      begin
         for I in 1 .. N_Members loop
            if not Band (I).Is_Dead and then Home_Of (I) = 0 then
               Pick := Pick - 1;
               if Pick = 0 then
                  Houses (H).Owner := I;
                  return;
               end if;
            end if;
         end loop;
      end;
   end Draw_Owner;

   --  The living with no house, and the houses begun that do not stand yet
   --  (each of them will be somebody's).
   function Without_A_House return Natural is
      N : Natural := 0;
   begin
      for I in 1 .. N_Members loop
         if not Band (I).Is_Dead and then Home_Of (I) = 0 then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Without_A_House;

   function Houses_Open return Natural is
      N : Natural := 0;
   begin
      for H in 1 .. N_Houses loop
         if not Houses (H).Built and then Houses (H).F.Kind = CB.Hovel   --  (a storehouse is nobody's home,
           and then not Houses (H).Raze                                  --  nor one being taken down)
         then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Houses_Open;

   --  Someone is without a house, none is being built for them, and there
   --  is no lot to begin one on: more housing is the player's to mark.
   function Room_Short return Boolean is
     (N_Housing > 0 and then N_Lots = 0 and then Without_A_House > Houses_Open);

   --  Once a colony second: a house whose owner has died is nobody's, and
   --  is drawn for again; and while more are without a house than there are
   --  houses being built, another is begun on the next lot, as many at once
   --  as there are foresters to build them (one, with none).
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
         Draw_Owner (H);
      end loop;
      Open := Houses_Open;
      for I in 1 .. N_Members loop
         if not Band (I).Is_Dead and then Band (I).Job = Forester then
            Foresters := Foresters + 1;
         end if;
      end loop;
      if Builders_Cap > 0 then
         Foresters := Natural'Min (Foresters, Builders_Cap);   --  (no more begun than can have builders)
      end if;
      while Open < Without_A_House and then Open < Natural'Max (1, Foresters) loop
         Begin_Lot (Ok);
         exit when not Ok;
         Open := Open + 1;
      end loop;
   end Begin_Houses;

   --  A house's ground is made ready a square metre at a time: patches of
   --  its pad and the bank round it, numbered by where they lie in its frame.
   Max_Site_Patch : constant := Max_Site_Patches;
   type Site_Flags is array (1 .. Max_Site_Patch) of Boolean;
   type Site_Sums is array (1 .. Max_Site_Patch) of Vec3;

   Patch_Bands : constant := 42;          --  (V from -64, as far as a stockyard's staging can reach beside a path
                                          --  aslant, to 103: the back of the largest stockyard)
   function Site_Patch_At (U, V : Integer) return Positive is
     (((U + CB.Apron_B + CB.Max_Reach_B) / 4) * Patch_Bands + (V + 64) / 4 + 1);
   --  (the patch a column of a house's frame is worked with: by where it is in its design)
   --  (a stockyard whose way in is at the high end of its front: counted from that end, so that the
   --  way is whole patches there as it is at the low end)
   function Patch_Of (F : CB.House; U, V : Integer) return Positive is
      Du : constant Integer := (if Yard_Turned (F) then D_U (F, U, V) else U);
      Dv : constant Integer := (if Yard_Turned (F) then D_V (F, U, V) else V);
   begin
      return Site_Patch_At ((if Is_Store (F) and then F.Way_End = 2 then F.Yard_U0 + F.Yard_U1 - Du else Du), Dv);
   end Patch_Of;
   --  (U from as far to its left as its ground can reach: a hovel's reach, a stockyard's side)
   --  (how far back from its path a patch lies: the nearest are worked first)
   function Patch_Band (P : Positive) return Natural is ((P - 1) mod Patch_Bands);

   --  The row over a house's ridge: as high as anything of it is built.
   function House_Top (F : CB.House) return Integer is
     (F.Pad + F.Wall_H + (if F.Ridge_Along_U then (F.D + 1) / 2 else (F.W + 1) / 2));

   --  What is still to do in a column of a house's site: earth to move
   --  (something growing on it to cut; ground standing over where its top
   --  is to be; a hollow under where its earth is to reach; where the house
   --  and its eaves will be, a neighbouring tree's leaves or boughs hanging
   --  in the way), and when that is done stone to lay.  Stone: the blocks
   --  of stone it still wants.  **Earth that stands where stone is to go is
   --  left until the stone is laid in its place**: a wall is never dug out
   --  first and built after, so the ground of a site is whole at every
   --  moment (a builder who had dug the stair to his own door away, with no
   --  stone yet to build it of, starved in the pit).
   type Ground_Work is (All_Done, To_Dig, To_Wall);

   --  Something stands over a column's top, as far up as a stockyard is
   --  cleared: a stump, a trunk, a bush, leaves.
   Yard_Clear_B : constant := 48;
   function Stands_Over (X, Y, Top : Integer) return Boolean is
     (for some Z in Top + 1 .. Top + Yard_Clear_B =>
        Mat (X, Y, Z) in Crown or else Mat (X, Y, Z) in Trunk or else Mat (X, Y, Z) in Berry_Bush | Bare_Bush);

   procedure Work_In (H : Positive; U, V : Integer; Work : out Ground_Work; Stone_N : out Natural) is
      F   : CB.House renames Houses (H).F;
      X   : constant Integer := H_X (F, U, V);
      Y   : constant Integer := H_Y (F, U, V);
      Top : constant Integer := Top_By (X, Y, F.Pad - 1);
   begin
      Work := All_Done;
      Stone_N := 0;
      if Top < 0 then
         return;
      end if;
      declare
         P : constant Column_Plan := Plan_Of (H, U, V);
         E : constant Integer := Integer'Min (P.Stone - 1, P.Top);      --  the top of its earth
      begin
         for Z in P.Stone .. P.Top loop
            if Mat (X, Y, Z) /= Fieldstone then
               Stone_N := Stone_N + 1;
            end if;
         end loop;
         if Plants_Over (X, Y, Top) or else Top > P.Top or else Top < E
           or else (((U in -1 .. F.W and then V in -1 .. F.D) or else Under_Turn (F, U, V, Margin => 1))
                    and then (for some Z in F.Pad .. House_Top (F) =>
                                Mat (X, Y, Z) in Crown or else Mat (X, Y, Z) in Trunk))
           or else (Yard_Site (F) and then Stands_Over (X, Y, P.Top))
         then
            Work := To_Dig;
         elsif Stone_N > 0 then
            Work := To_Wall;
         end if;
      end;
   end Work_In;

   --  The columns house H's builder makes ready: every column of its site;
   --  and, where its site lies against the site of a house begun before it,
   --  that house's columns along it (the wall between the two is the earlier
   --  house's to have, and the later one's to build if the earlier one's
   --  ground is done).  Visit (K, U, V, Pu, Pv): a column, (U, V) in house
   --  K's frame; (Pu, Pv), in H's own frame, says which patch of H's site it
   --  is worked with.
   generic
      with procedure Visit (K : Positive; U, V : Integer; Pu, Pv : Integer);
   procedure For_Site (H : Positive);

   procedure For_Site (H : Positive) is
      F : CB.House renames Houses (H).F;
      --  the first of a column's four neighbours that is of H's site: an
      --  earlier house's column is visited from that one alone
      procedure Other (U, V, Nu, Nv : Integer) is
         X : constant Integer := H_X (F, Nu, Nv);
         Y : constant Integer := H_Y (F, Nu, Nv);
         K : Natural;
         function First_Is_Here return Boolean is
           (if In_Site (F, Nu - 1, Nv) then U = Nu - 1 and then V = Nv
            elsif In_Site (F, Nu + 1, Nv) then U = Nu + 1 and then V = Nv
            elsif In_Site (F, Nu, Nv - 1) then U = Nu and then V = Nv - 1
            else True);
      begin
         if In_Site (F, Nu, Nv) then
            return;
         end if;
         K := Site_Of_Block (X, Y, But => H);
         if K in 1 .. H - 1 and then First_Is_Here then
            Visit (K, H_U (Houses (K).F, X, Y), H_V (Houses (K).F, X, Y), U, V);
         end if;
      end Other;
   begin
      for V in Site_V_Lo (F) .. Site_V_Hi (F) loop
         for U in Site_U_Lo (F) .. Site_U_Hi (F) loop
            if In_Site (F, U, V) then
               Visit (H, U, V, U, V);
               if H > 1 then
                  Other (U, V, U - 1, V);
                  Other (U, V, U + 1, V);
                  Other (U, V, U, V - 1);
                  Other (U, V, U, V + 1);
               end if;
            end if;
         end loop;
      end loop;
   end For_Site;

   --  Which patches of house H's site still have earth to move (Dig) and
   --  which stone to lay with none left to move (Wall), for each the sum of
   --  where that work is (X, Y) and how many columns (Z); and the blocks of
   --  stone the whole site still wants.
   procedure Site_Patches (H : Positive; Dig, Wall : out Site_Flags; Sum : out Site_Sums; Stone_N : out Natural) is
      Earth_Sum, Stone_Sum : Site_Sums := [others => (0.0, 0.0, 0.0)];
      Stones : Natural := 0;
      procedure Look (K : Positive; U, V : Integer; Pu, Pv : Integer) is
         Work : Ground_Work;
         N    : Natural;
         P    : constant Positive := Patch_Of (Houses (H).F, Pu, Pv);
         C    : constant Vec3 := H_Point (Houses (K).F, Float (U), Float (V));
      begin
         Work_In (K, U, V, Work, N);
         Stones := Stones + N;
         if Work = To_Dig then
            Dig (P) := True;
            Earth_Sum (P) := Earth_Sum (P) + (C.X, C.Y, 1.0);
         elsif Work = To_Wall then
            Wall (P) := True;
            Stone_Sum (P) := Stone_Sum (P) + (C.X, C.Y, 1.0);
         end if;
      end Look;
      procedure Look_All is new For_Site (Look);
   begin
      Dig := [others => False];
      Wall := [others => False];
      Look_All (H);
      Stone_N := Stones;
      for P in Dig'Range loop
         if Dig (P) then
            Wall (P) := False;                 --  (its earth first)
            Sum (P) := Earth_Sum (P);
         else
            Sum (P) := Stone_Sum (P);
         end if;
      end loop;
   end Site_Patches;

   --  A column of a house's site brought to where its earth is to be: what
   --  grows on it cut, what stands above its level (or where its wall is to
   --  stand) dug off, a hollow filled.  (The earth is the site's own: what
   --  is dug off fills the hollows, and what is over is thrown aside on the
   --  lot.)
   procedure Level_Column (H : Positive; U, V : Integer) is
      F   : CB.House renames Houses (H).F;
      X   : constant Integer := H_X (F, U, V);
      Y   : constant Integer := H_Y (F, U, V);
      Top : constant Integer := Top_By (X, Y, F.Pad - 1);
   begin
      if Top < 0 then
         return;
      end if;
      Cut_Plants (X, Y, Top);
      declare
         P : constant Column_Plan := Plan_Of (H, U, V);
         E : constant Integer := Integer'Min (P.Stone - 1, P.Top);
      begin
         for Z in reverse P.Top + 1 .. Top loop
            Write_Src (X, Y, Z, Air_Block);
         end loop;
         for Z in Top + 1 .. E loop
            Write_Src (X, Y, Z, (Mat => Dirt, State => 0));
         end loop;
      end;
      --  where the house and its eaves will be, what hangs there of a tree
      --  standing by is lopped (one drawn turned: where it is drawn too, as Work_In asks:
      --  asked and not done, its builder levelled for ever under a bough)
      if (U in -1 .. F.W and then V in -1 .. F.D) or else Under_Turn (F, U, V, Margin => 1) then
         for Z in F.Pad .. House_Top (F) loop
            if Mat (X, Y, Z) in Crown or else Mat (X, Y, Z) in Trunk then
               Write_Src (X, Y, Z, Air_Block);
            end if;
         end loop;
      end if;
      --  a stockyard's: whatever stands on it cleared with its ground (a stump, a bush, what
      --  hangs over it of a tree beside it; its own trees are felled first: Go_Fell_Yard)
      if Yard_Site (F) then
         for Z in Plan_Of (H, U, V).Top + 1 .. Plan_Of (H, U, V).Top + Yard_Clear_B loop
            if Mat (X, Y, Z) in Crown or else Mat (X, Y, Z) in Trunk or else Mat (X, Y, Z) in Berry_Bush | Bare_Bush then
               Write_Src (X, Y, Z, Air_Block);
            end if;
         end loop;
      end if;
   end Level_Column;

   --  Patch P of house H's site: its earth moved (0: all of the site's).
   procedure Level_Patch (H : Positive; P : Natural) is
      procedure Level (K : Positive; U, V : Integer; Pu, Pv : Integer) is
      begin
         if P = 0 or else Patch_Of (Houses (H).F, Pu, Pv) = P then
            Level_Column (K, U, V);
         end if;
      end Level;
      procedure Level_All is new For_Site (Level);
   begin
      Level_All (H);
   end Level_Patch;

   --  A piece of a site's ground is worked from beside it, and a storehouse's
   --  ground there and back (the spec, under "Most_Builders").  (Reach_On: above, before Near_Of.)
   Zigzag_On : Boolean := True;
   Stood_N   : Natural := 0;
   procedure Set_Reach_Out (On : Boolean) is
   begin
      Reach_On := On;
   end Set_Reach_Out;
   function Reach_Out return Boolean is (Reach_On);
   function Stood_On_Fill return Natural is (Stood_N);
   procedure Set_Zigzag (On : Boolean) is
   begin
      Zigzag_On := On;
   end Set_Zigzag;
   function Zigzag return Boolean is (Zigzag_On);

   --  Whoever stands still in a block column of house H's site with ground
   --  in it over its feet (earth just filled in, stone just laid) stands on
   --  that ground: as far up as a figure is tall, where there is room to
   --  stand; else it is left (it finds its own way out, as before).
   procedure Stand_On_Fill (H : Positive) is
      F : CB.House renames Houses (H).F;
   begin
      for J in 1 .. N_Members loop
         declare
            O  : Member renames Band (J);
            X  : constant Integer := B (O.Pos.X);
            Y  : constant Integer := B (O.Pos.Y);
            Zf : constant Integer := B (O.Pos.Z + 0.01);       --  the row its feet are in
            Top : Integer;
         begin
            if not O.Is_Dead and then abs (O.Pos.X - O.Prev.X) + abs (O.Pos.Y - O.Prev.Y) < 0.001
              and then In_Site (F, H_U (F, X, Y), H_V (F, X, Y))
              and then Class_Of (Mat (X, Y, Zf)) = Solid and then Mat (X, Y, Zf) in Dirt | Grass | Fieldstone | Footpath
            then
               Top := Zf;
               while Top < Zf + Castle.Nav.Head_B and then Class_Of (Mat (X, Y, Top)) = Solid loop
                  Top := Top + 1;
               end loop;
               if Class_Of (Mat (X, Y, Top)) /= Solid
                 and then (for all Up in 0 .. Castle.Nav.Head_B - 1 => Class_Of (Mat (X, Y, Top + Up)) /= Solid)
               then
                  O.Pos.Z := Float (Top) * 0.25;
                  O.Prev := O.Pos;
                  Stood_N := Stood_N + 1;
               end if;
            end if;
         end;
      end loop;
   end Stand_On_Fill;

   --  Stone laid in patch P of house H's site (0: all of it), from the foot
   --  of each wall up, where no earth is left to move, in place of whatever
   --  earth stands there: Most blocks at most.  Laid: how many were.
   procedure Wall_Patch (H : Positive; P : Natural; Most : Natural; Laid : out Natural) is
      Done : Natural := 0;
      procedure Lay (K : Positive; U, V : Integer; Pu, Pv : Integer) is
         Work : Ground_Work;
         N    : Natural;
      begin
         if Done >= Most or else not (P = 0 or else Patch_Of (Houses (H).F, Pu, Pv) = P) then
            return;
         end if;
         Work_In (K, U, V, Work, N);
         if Work = To_Wall then
            declare
               X    : constant Integer := H_X (Houses (K).F, U, V);
               Y    : constant Integer := H_Y (Houses (K).F, U, V);
               Plan : constant Column_Plan := Plan_Of (K, U, V);
            begin
               for Z in Plan.Stone .. Plan.Top loop
                  exit when Done >= Most;
                  if Mat (X, Y, Z) /= Fieldstone then
                     Write_Src (X, Y, Z, (Mat => Fieldstone, State => 0));
                     Done := Done + 1;
                  end if;
               end loop;
            end;
         end if;
      end Lay;
      procedure Lay_All is new For_Site (Lay);
   begin
      Lay_All (H);
      Laid := Done;
   end Wall_Patch;

   --  Someone other than its builder stands where block (X, Y, Z) is to go.
   --  (The builder stands clear of what it lays; where it could find no
   --  such place, the block is laid all the same and it steps out of it.)
   function Someone_At (X, Y, Z : Integer; But : Natural) return Boolean is
     (for some J in 1 .. N_Members =>
        J /= But and then not Band (J).Is_Dead and then B (Band (J).Pos.X) = X and then B (Band (J).Pos.Y) = Y
        and then Z in B (Band (J).Pos.Z) .. B (Band (J).Pos.Z) + Castle.Nav.Head_B - 1);

   --  Whoever stands still where block (X, Y, Z) is to go steps aside (John,
   --  2026-11-17: "need make sure serfs have a way to continue their work if
   --  they meet obstacles"): to the nearest block column round it that is
   --  not the block's own, whose ground is within a step of its feet, with
   --  room to stand, where nobody stands; what it is doing it goes on
   --  doing from there.  One that is walking is let pass.  (A builder laid
   --  nothing while someone stood where its next block went, and looked
   --  again every two seconds, for as long as that one stood.)
   Way_On : Boolean := True;
   procedure Set_Make_Way (On : Boolean) is
   begin
      Way_On := On;
   end Set_Make_Way;
   function Make_Way_On return Boolean is (Way_On);
   --  (a measure: colony seconds builders have waited for someone in the way, and the longest wait)
   Blocked_Total, Blocked_Longest : Float := 0.0;
   Blocked_Run : array (1 .. Max_Members) of Float := [others => 0.0];
   Bout_Blocked : Boolean := False;
   Stepped_N : Natural := 0;
   function Stepped_Aside return Natural is (Stepped_N);
   function Places_Lost return Natural is (Places_Lost_N);
   function Builders_Blocked_S return Float is (Blocked_Total);
   function Builders_Blocked_Longest_S return Float is (Blocked_Longest);
   procedure Make_Way (X, Y, Z : Integer; But : Natural) is
   begin
      for J in 1 .. N_Members loop
         declare
            O : Member renames Band (J);
         begin
            if J /= But and then not O.Is_Dead and then B (O.Pos.X) = X and then B (O.Pos.Y) = Y
              and then Z in B (O.Pos.Z) .. B (O.Pos.Z) + Castle.Nav.Head_B - 1
              and then abs (O.Pos.X - O.Prev.X) + abs (O.Pos.Y - O.Prev.Y) < 0.001       --  (standing still)
            then
               declare
                  Feet : constant Integer := B (O.Pos.Z) - 1;      --  the row it stands on
                  Done : Boolean := False;
               begin
                  Rings :
                  for R in 1 .. 8 loop
                     for Dx in -R .. R loop
                        for Dy in -R .. R loop
                           if (abs Dx = R or else abs Dy = R) and then not Done then
                              declare
                                 Cx : constant Integer := X + Dx;
                                 Cy : constant Integer := Y + Dy;
                                 G  : constant Integer := Ground_Row (Cx, Cy, Feet);
                              begin
                                 if G >= 0 and then abs (G - Feet) <= 1
                                   and then Castle.Nav.Ground_Speed (Mat (Cx, Cy, G)) > 0.0
                                   and then (for all Up in 1 .. Castle.Nav.Head_B =>
                                               Class_Of (Mat (Cx, Cy, G + Up)) /= Solid)
                                   and then not Someone_At (Cx, Cy, G + 1, But => J)
                                   and then Zone_Of_Block (Cx, Cy) = Zone_Of_Block (X, Y)
                                 then
                                    declare
                                       To_P : constant Vec3 :=
                                         ((Float (Cx) + 0.5) * 0.25, (Float (Cy) + 0.5) * 0.25, Float (G + 1) * 0.25);
                                    begin
                                       --  (and never into a place it could not walk out of: the strip between
                                       --  a house and the wall that holds its ground, a pit)
                                       if not Stake_Set
                                         or else Castle.Nav."=" (Castle.Nav.Plan (To_P, Stake_At).Result, Castle.Nav.Found)
                                       then
                                          O.Pos := To_P;
                                          O.Prev := O.Pos;
                                          Done := True;
                                          Stepped_N := Stepped_N + 1;
                                       end if;
                                    end;
                                 end if;
                              end;
                           end if;
                        end loop;
                     end loop;
                     exit Rings when Done;
                  end loop Rings;
               end;
            end if;
         end;
      end loop;
   end Make_Way;

   --  For the checks, as Supply is: member I stood at P with nothing to do for Seconds.
   procedure Hold_Still (I : Positive; P : Vec3; Seconds : Float) is
      M : Member renames Band (I);
   begin
      Release (M, I);
      M.Pos := P;
      M.Prev := P;
      M.Route.N := 0;
      M.State := Idle;
      M.Wait := Seconds;
   end Hold_Still;

   ------------------------------------------------------------------ the square's walls and stair

   --  The banks of the square the colony was founded on, walled with stone
   --  (the spec, "The square's walls and stair").  Nothing of them is kept:
   --  what each block column of the floor's edge is to be is worked out
   --  from the floor's level, the square's own frame and the top of the laid
   --  path outside it (Plan_Walls), and what is still to do from the blocks
   --  as they stand (Column_Work), each time; the count and the laying go
   --  by the same two routines, so that what cannot be laid is never
   --  counted as left.
   Wall_Fail   : constant := 31_098;   --  a fail memo: no stone to be had for them, or none of them it could get to
   Walls_Day_Ticks : constant := 2 * 1_440 * Tick_Hz + 4;  --  (two game days of the colony's steps, and to the minute's count)

   procedure Set_Square_Walls (On : Boolean) is
   begin
      Walls_On := On;
      Walls_Stale := True;
   end Set_Square_Walls;
   function Square_Walls return Boolean is (Walls_On);
   --  (a square's stair in a corner of the zone, not at the middle of its side: the spec, "A square's
   --  stair in a corner of the zone".  Off since the evening of 2026-11-21: his words were of the
   --  stockyard's stair.)
   Stair_Corner_On : Boolean := False;
   procedure Set_Square_Stair_Corner (On : Boolean) is
   begin
      Stair_Corner_On := On;
      Walls_Stale := True;
   end Set_Square_Stair_Corner;
   function Square_Stair_Corner return Boolean is (Stair_Corner_On);
   --  (the square's path stepped with stone where a levelled stretch of it ends: the spec, "The
   --  square's path stepped with stone")
   procedure Set_Path_Steps (On : Boolean) is
   begin
      Steps_On := On;
      Walls_Stale := True;
   end Set_Path_Steps;
   function Path_Steps return Boolean is (Steps_On);
   --  (the square metre where two sides' paths cross laid as one: the spec, "The corners of the
   --  square's path")
   procedure Set_Corner_Whole (On : Boolean) is
   begin
      Corner_On := On;
      Walls_Stale := True;
   end Set_Corner_Whole;
   function Corner_Whole return Boolean is (Corner_On);
   procedure Set_Strip_Wait (On : Boolean) is
   begin
      Strip_Wait_On := On;
      Walls_Stale := True;
   end Set_Strip_Wait;
   function Strip_Wait return Boolean is (Strip_Wait_On);
   function Square_Crossing (Bx, By : Integer) return Natural is (Cross_Of (Cut_Now, Bx, By));
   procedure Set_Corner_Steps (On : Boolean) is
   begin
      Corner_Steps_On := On;
      Walls_Stale := True;
   end Set_Corner_Steps;
   function Corner_Steps return Boolean is (Corner_Steps_On);

   Wall_Span : constant := 44;         --  block columns each way of the square's middle a plan covers (aslant, the
                                       --  wider square's path reaches 37; room for a wall outside its floor)
   subtype Wall_Ix is Integer range -Wall_Span .. Wall_Span - 1;
   type Wall_Rows is array (Wall_Ix, Wall_Ix) of Integer_16;
   type Wall_Flags is array (Wall_Ix, Wall_Ix) of Boolean;
   type Wall_Plan is record
      Ok       : Boolean := False;
      X0, Y0   : Integer := 0;         --  the block column east and north of the square's middle: column (0, 0)
      Level    : Integer := 0;         --  the floor's
      Floor    : Wall_Flags;           --  a block column of the square's floor
      Top      : Wall_Rows;            --  the row its top is brought to
      Stone    : Wall_Rows;            --  the lowest row of it that is stone (Top + 1: none)
      Columns  : Natural := 0;         --  of them, those that are wall, ledge or stair
      Stairs   : Natural := 0;
      Too_High : Natural := 0;         --  sides whose bank is too high for a stair
      Stair_At : Stair_Places := [others => No_Stair];     --  where each side's stands
      Lost     : Natural := 0;         --  sides that would have one at their middle and take none at either end
      Shared   : Natural := 0;         --  sides whose stair is another side's, in the corner the two meet at
      By_Level : Natural := 0;         --  stairs in a corner where the path of the side met there comes in level
      Sites    : Stair_Sites;          --  the bank a stair would stand against, each side's three places
      Highest  : Natural := 0;         --  the highest bank walled, blocks
      Lifts    : Natural := 0;         --  the most lifts in one wall
      Unready  : Natural := 0;         --  edge columns whose path beside them is still to lay
      --  (of a square whose walls stand outside its floor)
      Short    : Natural := 0;         --  columns of wall that stand steeper than a ring a lift: their strip is too narrow
      Unwalled : Natural := 0;         --  edge columns of the floor whose bank is left earth: no strip on that side
      Inside   : Natural := 0;         --  columns of the floor that are stone and neither a step nor beside one (none)
      Capped   : Natural := 0;         --  columns of a strip that are no wall's: capped with stone at the path's level
      Zoned    : Natural := 0;         --  columns of a strip that are some zone's ground (none: a strip is nobody's to zone)
      Need     : Square_Strips := [others => 0];     --  the most lifts the path as laid asks of each side
      --  (the square's path stepped with stone: Set_Path_Steps)
      Step       : Wall_Flags;         --  a block column of its path that is to be a step of stone: of the plan too
      Path_Steps : Natural := 0;       --  how many
      Step_Slices : Natural := 0;      --  quarter metres of its path that are to be steps, or are and want stone yet
      Barred     : Step_Bars := [others => 0];     --  jumps at a levelled stretch's end left as they are, by why
   end record;

   --  A wall's column K rings in from the floor's edge (1: the outermost),
   --  the laid path outside its strip at row G, the floor at L: the row its
   --  top is brought to.  Against higher ground the top lift stands in the
   --  outermost ring, flush with that ground, and each lift under it a ring
   --  further in; holding the floor up over lower ground, the first lift
   --  stands in the outermost ring and each lift over it a ring further in:
   --  either way, counted up from the lower ground, a ring toward the higher
   --  for every Square_Lift_B of wall (John: "from lower ground for each 1m
   --  of retaining wall step inwards .25").
   --  (Base: the lowest row of its lift, which is stone from there to its
   --  top; over Top: it is no part of a wall.)
   procedure Wall_Column (G, K, L : Integer; Top, Base : out Integer) is
      H : constant Integer := G - L;
      N : Integer;
   begin
      Top := L;
      Base := L + 1;
      if H > Retain_Over_B then
         N := (H + Square_Lift_B - 1) / Square_Lift_B;
         if K <= N then
            Top := Integer'Min (G, L + Square_Lift_B * (N - K + 1));
            Base := L + Square_Lift_B * (N - K) + 1;
         end if;
      elsif -H > Retain_Over_B then
         N := (-H + Square_Lift_B - 1) / Square_Lift_B;
         if K <= N then
            Top := Integer'Min (L, G + Square_Lift_B * K);
            Base := G + Square_Lift_B * (K - 1) + 1;
         end if;
      end if;
   end Wall_Column;
   --  And a column of a stair: a block a step from the path's level to the
   --  floor's, a step Rows rings deep.
   function Stair_Top (G, K, L : Integer; Rows : Positive) return Integer is
      T : constant Integer := (K + Rows - 1) / Rows;
   begin
      return (if G > L then Integer'Max (L, G - T) elsif G < L then Integer'Min (L, G + T) else L);
   end Stair_Top;

   procedure Plan_Walls (P : out Wall_Plan) is
      L : constant Integer := Camp_Level;
   begin
      P.Ok := False;
      P.Columns := 0;
      P.Stairs := 0;
      P.Too_High := 0;
      P.Stair_At := [others => No_Stair];
      P.Lost := 0;
      P.Shared := 0;
      P.By_Level := 0;
      P.Sites := [others => [others => <>]];
      P.Highest := 0;
      P.Lifts := 0;
      P.Unready := 0;
      P.Short := 0;
      P.Unwalled := 0;
      P.Inside := 0;
      P.Capped := 0;
      P.Zoned := 0;
      P.Need := [others => 0];
      P.Step := [others => [others => False]];
      P.Path_Steps := 0;
      P.Step_Slices := 0;
      P.Barred := [others => 0];
      if not Camp_Square or else Camp_Zone_N = 0 or else L < 0 then
         return;
      end if;
      declare
         Aslant : constant Boolean := Zones (Camp_Zone_N).Way mod 2 = 1;
         Ex   : constant Float := (if Aslant then 1.0 / Sqrt (2.0) else 1.0);
         Ey   : constant Float := (if Aslant then 1.0 / Sqrt (2.0) else 0.0);
         W    : constant Float := (if Aslant then 0.25 / Sqrt (2.0) else 0.25);      --  a ring's width
         Half : constant Float :=
           (if Aslant then Float (Square_Diag_B) * 0.25 / Sqrt (2.0) else Float (Square_Ring_B) * 0.25) - Path_Width_M / 2.0;
         X0   : constant Integer := B (Camp_At.X + 0.01);     --  (its middle is on a corner of blocks)
         Y0   : constant Integer := B (Camp_At.Y + 0.01);
         Rows : constant Positive := (if Aslant then Square_Step_Rows else 1);
         K_Most : constant Positive := Square_Stair_Most_B * Rows + 1;                --  (no stair or lift reaches further in)
         Read : Wall_Rows := [others => [others => -2]];     --  the path's top outside (-2: not read; -1: none to go by)
         Is_Stair : Wall_Flags := [others => [others => False]];
         type Axis is (Along, Across);
         subtype Side is Integer range 1 .. 4;               --  along +, along -, across +, across -
         Stair_Of : Stair_Places := [others => No_Stair];    --  where each side's stair stands
         --  A square whose walls stand outside its floor (the spec, "A special zone's area is kept
         --  whole"): the rings kept outside each side, and which columns of them have anything planned.
         Out_Sq : constant Boolean := Square_Outside;
         --  (and its stair in a corner of the floor: with the walls on the floor's own edge the wall of
         --  the side it meets there would take the outer columns of its width)
         In_Corner : constant Boolean := Stair_Corner_On and then Out_Sq;
         --  The width of a stair at a side's end, in rings counted in from the edge of the side it meets
         --  there: squarely a block column more where the floor's outermost column is half of a cell of
         --  the walking map (its middle on an odd block corner), so that its inner four are two whole cells.
         N_Edge : constant Integer := Integer (Float'Rounding (Half / 0.25));
         function End_Width (A : Axis) return Positive is
           (if Aslant then 2 * Square_Stair_Rows + 1
            else Square_Stair_B + (if ((if A = Along then Y0 else X0) + N_Edge) mod 2 = 0 then 0 else 1));
         Geo    : constant Square_Geo := Geo_Now;
         In_Strip : Wall_Flags := [others => [others => False]];
         function Strip_Of (Sd : Side) return Natural is (if Out_Sq then Square_Strip (Sd) else 0);
         Di : constant array (1 .. 4) of Integer := [1, -1, 0, 0];
         Dj : constant array (1 .. 4) of Integer := [0, 0, 1, -1];

         procedure Frame (I, J : Integer; U, V : out Float) is
            Dx : constant Float := (Float (X0 + I) + 0.5) * 0.25 - Camp_At.X;
            Dy : constant Float := (Float (Y0 + J) + 0.5) * 0.25 - Camp_At.Y;
         begin
            U := Dx * Ex + Dy * Ey;
            V := Dy * Ex - Dx * Ey;
         end Frame;
         function Of_Floor (I, J : Integer) return Boolean is (I in Wall_Ix and then J in Wall_Ix and then P.Floor (I, J));
         --  The laid path's top at a column outside the floor: what a wall is planned against.  None to
         --  go by where the path is still to lay (the wall waits for it), under a tree, and where
         --  anything else stands (a boulder is its own bank: no wall is asked for beside it).
         function Reading (I, J : Integer) return Integer is
         begin
            if I not in Wall_Ix or else J not in Wall_Ix then
               return -1;
            end if;
            if Read (I, J) = -2 then
               declare
                  G : constant Integer := Top_By (X0 + I, Y0 + J, L);
               begin
                  Read (I, J) :=
                    (if G >= 0 and then Mat (X0 + I, Y0 + J, G) in Footpath | Fieldstone
                       and then Mat (X0 + I, Y0 + J, G + 1) not in Trunk
                     then Integer_16 (G) else -1);
               end;
            end if;
            return Integer (Read (I, J));
         end Reading;
         --  The laid path's top nearest a column of the path's innermost ring, along the side it lies
         --  on (Reading, of the first column either way that has one, four metres at the most; of two
         --  as near, the one further off the floor's level).
         function Near_Reading (Oi, Oj : Integer; A : Axis) return Integer is
            --  (a step along that side: squarely along Y or along X; aslant along its diagonal row)
            Dx : constant Integer := (if not Aslant then (if A = Along then 0 else 1) elsif A = Along then -1 else 1);
            Dy : constant Integer := (if not Aslant then (if A = Along then 1 else 0) else 1);
         begin
            for T in 1 .. 16 loop
               declare
                  Ra : constant Integer := Reading (Oi + T * Dx, Oj + T * Dy);
                  Rb : constant Integer := Reading (Oi - T * Dx, Oj - T * Dy);
               begin
                  if Ra >= 0 or else Rb >= 0 then
                     return (if Ra < 0 then Rb elsif Rb < 0 then Ra elsif abs (Ra - L) >= abs (Rb - L) then Ra else Rb);
                  end if;
               end;
            end loop;
            return -1;
         end Near_Reading;
         --  How many rings in from the edge of side (A, its sign S) a floor column lies, and which side.
         procedure Ring_Of (I, J : Integer; A : Axis; K : out Integer; S : out Integer) is
            U, V : Float;
         begin
            Frame (I, J, U, V);
            declare
               C : constant Float := (if A = Along then U else V);
            begin
               S := (if C >= 0.0 then 1 else -1);
               K := Integer (Float'Floor ((Half - abs C) / W)) + 1;
            end;
         end Ring_Of;
         function Side_Of (A : Axis; S : Integer) return Side is
           (if A = Along then (if S > 0 then 1 else 2) else (if S > 0 then 3 else 4));
         --  The column outside the floor at the end of a floor column's strip: straight out across
         --  the edge (aslant: by diagonal steps, the odd one along X).
         procedure Outside (I, J : Integer; A : Axis; S, K : Integer; Oi, Oj : out Integer) is
            Nx : constant Integer := (if not Aslant then (if A = Along then S else 0) elsif A = Along then S else -S);
            Ny : constant Integer := (if not Aslant then (if A = Along then 0 else S) else S);
         begin
            if Aslant then
               Oi := I + ((K + 1) / 2) * Nx;
               Oj := J + (K / 2) * Ny;
            else
               Oi := I + K * Nx;
               Oj := J + K * Ny;
            end if;
         end Outside;
         --  Within the width of a stair of a side across axis A.  At its middle: squarely
         --  Square_Stair_B block columns about the middle of the side, begun on an even column (two
         --  whole cells of the walking map); aslant, Square_Stair_Rows diagonal rows either side of
         --  the middle one.  At an end: as wide, counted in from the edge of the side it meets there
         --  (End_Width), and no further out than that edge: the corner of the two strips is no part of it.
         function In_Spot (I, J : Integer; A : Axis; Spot : Stair_Spot) return Boolean is
         begin
            if Spot /= At_Middle then
               declare
                  K2, S2 : Integer;
               begin
                  Ring_Of (I, J, (if A = Along then Across else Along), K2, S2);
                  return S2 = (if Spot = At_High then 1 else -1) and then K2 in 1 .. End_Width (A);
               end;
            end if;
            if Aslant then
               return abs (if A = Along then J - I else I + J + 1) <= Square_Stair_Rows;
            end if;
            declare
               T  : constant Integer := (if A = Along then J else I);
               C0 : constant Integer := (if A = Along then Y0 else X0);
               T0 : constant Integer := -(Square_Stair_B / 2) + (if (C0 - Square_Stair_B / 2) mod 2 = 0 then 0 else 1);
            begin
               return T in T0 .. T0 + Square_Stair_B - 1;
            end;
         end In_Spot;
         --  Within the width of the stair the side across axis A on the side S of the middle has.
         function In_Stair (I, J : Integer; A : Axis; S : Integer) return Boolean is
           (Stair_Of (Side_Of (A, S)) /= No_Stair and then In_Spot (I, J, A, Stair_Of (Side_Of (A, S))));
         --  **The square's path stepped with stone** (the spec of that name; John, 2026-11-21: "we
         --  need to do something about having the .5m jumps in the path around the square too", and of
         --  the ways put to him, 2026-11-22: "Steps of stone").  A quarter metre of the square's path
         --  is brought to the floor's level whole or left as the land lies (Lay_Metre), so where a
         --  levelled stretch ends the path stood two or three blocks off it at once.  From each
         --  quarter metre at the floor's level outward along its side, the one K on is a step K blocks
         --  off that level, toward the land's own side of it, while the path's middle there lies at
         --  least that far off and every column of it within Path_Level_B of that row; the first that
         --  is not ends the flight, and beyond it the path is as it was.  A step is all its columns
         --  across the path at that one row, each a tread of stone, laid by whoever builds the walls.
         --    * **Read from the path as it is laid, and only from that** (Reading): a quarter metre
         --      with a column still to lay, under a tree, or anything else, is no step and ends a
         --      flight, so nothing here asks who laid which metre first.  A flight half built reads
         --      as the same flight (a column moved toward its row does not move the row), one built
         --      as itself (all at one row K blocks off, K on from a level one: laid before, or the
         --      land's own step, which is left as it is unless some of it is stone already).
         --    * **No step where two sides' paths cross** (a quarter metre with a column that is on
         --      another side's path too), with Corner_Steps_Here off: what was laid there went by
         --      which side's metre came first, and a tread of stone in a metre still to lay would
         --      leave it unlevelled (Lay_Metre takes stone for ground it does not know).
         --    * **No stair is moved, lost or made by them**: the stairs are decided from the path
         --      before the middle of each side (Banks), each time.  Before a stair that stands there
         --      is no step; before the middle of a side with none, only steps too low for a stair
         --      to stand against (below).  So that reading says the same before and after the steps
         --      are laid, and no stair is read against a step.
         --    * The walls and the strips beside a step are planned against it as it will stand (Read
         --      is given its row), from the first: a wall is never built against the jump and left
         --      standing over the step.
         --  Only of a square whose walls stand outside its floor.
         Steps_Here : constant Boolean := Steps_On and then Out_Sq;
         Path_Step_Most : constant := 6;           --  (quarter metres: the land is seldom three blocks off, never four)
         --    * **Into and through the corners** (Corner_Steps_On, with the corners laid as one,
         --      Corner_On; the spec, "The corners of the square's path"): the square metre where two
         --      sides' paths cross is one step of a flight, a landing, all its columns at one row, and
         --      a flight that comes to it along one side goes on from it along the other.  So the
         --      path round the square is one round of quarter metres and four landings, and a
         --      flight runs along it from each level one, either way.  (With the corner's square
         --      metre laid a quarter metre of each side's at a time there was no step there at all:
         --      what lay in it went by which side's metre came first.)  Not where a stair stands in
         --      a corner of the floor (In_Corner).
         Corner_Steps_Here : constant Boolean := Steps_Here and then Corner_On and then Corner_Steps_On and then not In_Corner;
         --  (a column of the path whose quarter metre may yet become a step, or a step of another row:
         --  one within a flight's reach of it along the round is still to lay.  What stands beside it
         --  waits: Strip_Wait_On, below.)
         Path_Unsettled : Wall_Flags := [others => [others => False]];
         procedure Plan_Steps is
            Cut : constant Path_Cut := Cut_Now;
            subtype Sl is Integer range 0 .. Path_Cut_Most;
            --  (a unit of the round: a quarter metre of side 1 to 4's path; or, as "side" 4 + N, slice 0,
            --  the square metre N in which two sides' paths cross)
            subtype Unit_Side is Integer range 1 .. 8;
            type Sl_Rows is array (Unit_Side, Sl) of Top_Row;
            type Sl_Ints is array (Unit_Side, Sl) of Integer;
            type Sl_Flags is array (Unit_Side, Sl) of Boolean;
            Tops   : Sl_Rows;
            N      : Sl_Ints := [others => [others => 0]];
            Stones : Sl_Ints := [others => [others => 0]];
            --  (for the measure alone: every column's top as the tools read it, laid path or not)
            All_Tops : Sl_Rows;
            All_N    : Sl_Ints := [others => [others => 0]];
            Lo     : Sl_Ints := [others => [others => Integer'Last]];
            Hi     : Sl_Ints := [others => [others => Integer'First]];
            Unread, Cross, Faces, Mid_Spot : Sl_Flags := [others => [others => False]];
            To     : Sl_Ints := [others => [others => -1]];
            Step_K : Sl_Ints := [others => [others => 0]];
            Corner_Of : Sl_Ints := [others => [others => 0]];     --  (the crossing a side's quarter metre lies in)
            To_Lay, Unsettled : Sl_Flags := [others => [others => False]];
            --  A place on the round and the way a flight is going along it.
            type Pos is record
               Ok  : Boolean := False;
               S   : Unit_Side := 1;
               C   : Integer := 0;
               Dir : Integer := 1;          --  (along a side: its slices up or down; at a crossing: nothing)
               Via : Integer := 0;          --  (at a crossing: the side it was come to along)
            end record;
            function Is_Path (I, J : Integer) return Boolean is
              (not P.Floor (I, J) and then Part_Of (Geo, X0 + I, Y0 + J) = Part_Path);
            function Level (Sd : Unit_Side; Sc : Integer) return Boolean is
              (N (Sd, Sc) > 0 and then not Unread (Sd, Sc) and then Lo (Sd, Sc) = L and then Hi (Sd, Sc) = L);
            function Middle_Of (Row : Top_Row; Count : Natural) return Integer is
               V : Top_Row := Row;
            begin
               for I in 2 .. Count loop                        --  (a few: sorted in place)
                  declare
                     X : constant Integer := V (I);
                     J : Natural := I - 1;
                  begin
                     while J >= 1 and then V (J) > X loop
                        V (J + 1) := V (J);
                        J := J - 1;
                     end loop;
                     V (J + 1) := X;
                  end;
               end loop;
               return V ((Count + 1) / 2);
            end Middle_Of;
            function Middle (Sd : Unit_Side; Sc : Integer) return Integer is (Middle_Of (Tops (Sd, Sc), N (Sd, Sc)));
            --  The two sides that cross in square metre Cn, and which Cn it is at an end of a side
            --  (Cross_Of's numbers).
            function Side_A (Cn : Positive) return Side is ((Cn - 1) / 2 + 1);
            function Side_B (Cn : Positive) return Side is ((Cn - 1) mod 2 + 3);
            function Crossing_At (Sd : Side; High : Boolean) return Positive is
              (if Sd <= 2 then (Sd - 1) * 2 + (if High then 3 else 4) - 2
               else ((if High then 1 else 2) - 1) * 2 + Sd - 2);
            --  From crossing Cn out along side Sd: its first quarter metre that is not of the crossing.
            function Off_Corner (Cn : Positive; Sd : Side) return Pos is
               High   : constant Boolean := Crossing_At (Sd, True) = Cn;
               At_End : constant Boolean := High /= Cut.From_High (Sd);     --  (at the end of its last slices)
               Last   : constant Integer := Integer'Min (Path_Cut_Most, Cut.Slices (Sd) - 1);
               C      : Integer := (if At_End then Last else 0);
            begin
               while C in 0 .. Last and then Cross (Sd, C) loop
                  C := C + (if At_End then -1 else 1);
               end loop;
               return (Ok => C in 0 .. Last, S => Sd, C => C, Dir => (if At_End then -1 else 1), Via => 0);
            end Off_Corner;
            --  The next one along the round.
            function Step_On (U : Pos) return Pos is
            begin
               if not U.Ok then
                  return U;
               elsif U.S > 4 then
                  return Off_Corner (U.S - 4, (if U.Via = Side_A (U.S - 4) then Side_B (U.S - 4) else Side_A (U.S - 4)));
               end if;
               declare
                  C : constant Integer := U.C + U.Dir;
               begin
                  if C not in Sl or else C >= Cut.Slices (U.S) then
                     return (Ok => False, others => <>);
                  elsif Corner_Steps_Here and then Cross (U.S, C) then
                     return (Ok => Corner_Of (U.S, C) > 0, S => 4 + Integer'Max (1, Corner_Of (U.S, C)), C => 0, Dir => 0,
                             Via => U.S);
                  else
                     return (Ok => True, S => U.S, C => C, Dir => U.Dir, Via => 0);
                  end if;
               end;
            end Step_On;
            --  A flight from a level one, First the one next to it.
            procedure Flight (First : Pos) is
               U   : Pos := First;
               Sgn : Integer := 0;
            begin
               for K in 1 .. Path_Step_Most loop
                  declare
                     M, Sg : Integer;
                  begin
                     --  (a measure: the quarter metre next to a level one stands two blocks or more off it
                     --  and is left so, and why; as the tools read it: by every column's top, laid path
                     --  or not, of the side's own quarter metre there)
                     if K = 1 and then U.Ok then
                        declare
                           --  (at a crossing: the first quarter metre of it on the side come along)
                           Ms : constant Unit_Side := (if U.S > 4 then U.Via else U.S);
                           Mc : constant Integer :=
                             (if U.S > 4 then Off_Corner (U.S - 4, U.Via).C - Off_Corner (U.S - 4, U.Via).Dir else U.C);
                        begin
                           if Mc in Sl and then All_N (Ms, Mc) > 0 and then not Level (U.S, U.C)
                             and then abs (Middle_Of (All_Tops (Ms, Mc), All_N (Ms, Mc)) - L) >= 2
                           then
                              declare
                                 Mid_All : constant Integer := Middle_Of (All_Tops (Ms, Mc), All_N (Ms, Mc));
                                 To_Row  : constant Integer := L + (if Mid_All > L then 1 else -1);
                              begin
                                 if Unread (U.S, U.C) then
                                    P.Barred (Castle.Colony.Unread) := P.Barred (Castle.Colony.Unread) + 1;
                                 elsif Cross (U.S, U.C) then
                                    P.Barred (At_Crossing) := P.Barred (At_Crossing) + 1;
                                 elsif Faces (U.S, U.C) then
                                    P.Barred (Before_Stair) := P.Barred (Before_Stair) + 1;
                                 elsif abs (Lo (U.S, U.C) - To_Row) > Path_Level_B
                                   or else abs (Hi (U.S, U.C) - To_Row) > Path_Level_B
                                   or else (U.S > 4 and then Middle (U.S, U.C) = L)
                                 then
                                    P.Barred (Uneven) := P.Barred (Uneven) + 1;
                                 end if;
                              end;
                           end if;
                        end;
                     end if;
                     exit when not U.Ok or else N (U.S, U.C) = 0
                       or else Unread (U.S, U.C) or else Cross (U.S, U.C) or else Faces (U.S, U.C)
                       or else Level (U.S, U.C);
                     if Lo (U.S, U.C) = Hi (U.S, U.C) and then abs (Lo (U.S, U.C) - L) = K then
                        --  (a step laid before, or the land's own: the flight runs on through
                        --  it; one with some of its treads stone and some not is finished)
                        Sg := (if Lo (U.S, U.C) > L then 1 else -1);
                        exit when Sgn /= 0 and then Sg /= Sgn;
                        Sgn := Sg;
                        if Stones (U.S, U.C) in 1 .. N (U.S, U.C) - 1
                          and then (Step_K (U.S, U.C) = 0 or else K < Step_K (U.S, U.C))
                        then
                           Step_K (U.S, U.C) := K;
                           To (U.S, U.C) := L + Sgn * K;
                        end if;
                     else
                        M := Middle (U.S, U.C);
                        exit when M = L;
                        Sg := (if M > L then 1 else -1);
                        exit when Sgn /= 0 and then Sg /= Sgn;
                        Sgn := Sg;
                        exit when abs (M - L) < K;
                        exit when Mid_Spot (U.S, U.C) and then K >= Square_Stair_Least_B;
                        exit when abs (Lo (U.S, U.C) - (L + Sgn * K)) > Path_Level_B
                          or else abs (Hi (U.S, U.C) - (L + Sgn * K)) > Path_Level_B;
                        if Step_K (U.S, U.C) = 0 or else K < Step_K (U.S, U.C) then
                           Step_K (U.S, U.C) := K;
                           To (U.S, U.C) := L + Sgn * K;
                        end if;
                     end if;
                     U := Step_On (U);
                  end;
               end loop;
            end Flight;
            procedure Note (Sd : Unit_Side; Sc : Integer; I, J, R : Integer) is
               Z : constant Integer := Ground_Row (X0 + I, Y0 + J, L);
            begin
               if Z >= 0 and then All_N (Sd, Sc) < Top_Row'Last then
                  All_N (Sd, Sc) := All_N (Sd, Sc) + 1;
                  All_Tops (Sd, Sc) (All_N (Sd, Sc)) := Z;
               end if;
               --  (still to lay: a stretch has it to turn to path yet.  Not a boulder or a tree's foot, nor
               --  ground no stretch ever comes to: out of a stretch's reach, further up or down than a
               --  metre of path is looked for; what waited for that would wait for ever)
               if R < 0 and then Column_To_Lay (X0 + I, Y0 + J) then
                  To_Lay (Sd, Sc) := True;
               end if;
               if R < 0 or else N (Sd, Sc) = Top_Row'Last then
                  Unread (Sd, Sc) := True;
               else
                  N (Sd, Sc) := N (Sd, Sc) + 1;
                  Tops (Sd, Sc) (N (Sd, Sc)) := R;
                  Lo (Sd, Sc) := Integer'Min (Lo (Sd, Sc), R);
                  Hi (Sd, Sc) := Integer'Max (Hi (Sd, Sc), R);
                  if Mat (X0 + I, Y0 + J, R) = Fieldstone then
                     Stones (Sd, Sc) := Stones (Sd, Sc) + 1;
                  end if;
               end if;
            end Note;
         begin
            if not Cut.Ok then
               return;
            end if;
            --  each side's path, a quarter metre at a time: its columns' tops as laid
            for I in Wall_Ix loop
               for J in Wall_Ix loop
                  if Is_Path (I, J) then
                     declare
                        Sc   : array (Side) of Integer;
                        Of_N : Natural := 0;
                        R    : constant Integer := Reading (I, J);
                        Cn   : constant Natural := (if Corner_Steps_Here then Cross_Of (Cut, X0 + I, Y0 + J) else 0);
                     begin
                        for Sd in Side loop
                           Sc (Sd) := Slice_Of (Cut, Sd, X0 + I, Y0 + J);
                           if Sc (Sd) >= 0 then
                              Of_N := Of_N + 1;
                           end if;
                        end loop;
                        for Sd in Side loop
                           if Sc (Sd) >= 0 then
                              if Of_N > 1 or else Cn > 0 then
                                 Cross (Sd, Sc (Sd)) := True;
                              end if;
                              if Cn > 0 then
                                 Corner_Of (Sd, Sc (Sd)) := Cn;
                              end if;
                              Note (Sd, Sc (Sd), I, J, R);
                           end if;
                        end loop;
                        if Cn > 0 then
                           Note (4 + Cn, 0, I, J, R);
                        end if;
                     end;
                  end if;
               end loop;
            end loop;
            --  the quarter metres that the place a side's stair stands at, or would stand at, faces: the
            --  middle of each side (and its two ends, where a stair stands in a corner); aslant, and
            --  the one to either side, a floor column's way out being by diagonal steps.  **Whether a
            --  side has a stair is read from the path there** (Banks: a bank of Square_Stair_Least_B
            --  blocks or more all across its width), each time, so the steps must leave that reading
            --  what it was:
            --    * before a stair that stands (Faces): no step at all, or its bank would read less
            --      and the stair be gone;
            --    * before the middle of a side that has none (Mid_Spot): a step only at a row less
            --      than Square_Stair_Least_B off the floor's level, which no stair stands against.  The
            --      third quarter metre of a flight brought to one row there made a bank of two and
            --      three blocks one of three all across, and a stair was planned at the middle of a
            --      side that had none (two of 323 squares, found by the sites script: their walls
            --      then never came to an end).
            for I in Wall_Ix loop
               for J in Wall_Ix loop
                  if P.Floor (I, J) then
                     for A in Axis loop
                        declare
                           K, S, Oi, Oj : Integer;
                        begin
                           Ring_Of (I, J, A, K, S);
                           if K in 1 .. K_Most
                             and then (In_Spot (I, J, A, At_Middle)
                                       or else (In_Corner
                                                and then (In_Spot (I, J, A, At_Low) or else In_Spot (I, J, A, At_High))))
                           then
                              Outside (I, J, A, S, K + Strip_Of (Side_Of (A, S)), Oi, Oj);
                              if Oi in Wall_Ix and then Oj in Wall_Ix then
                                 declare
                                    Sc : constant Integer := Slice_Of (Cut, Side_Of (A, S), X0 + Oi, Y0 + Oj);
                                    Wd : constant Integer := (if Aslant then 1 else 0);
                                 begin
                                    for D in -Wd .. Wd loop
                                       if Sc >= 0 and then Sc + D in Sl then
                                          if In_Stair (I, J, A, S) or else In_Corner then
                                             Faces (Side_Of (A, S), Sc + D) := True;
                                          else
                                             Mid_Spot (Side_Of (A, S), Sc + D) := True;
                                          end if;
                                       end if;
                                    end loop;
                                 end;
                              end if;
                           end if;
                        end;
                     end loop;
                  end if;
               end loop;
            end loop;
            --  (a crossing that is one of the round's is no bar to a flight: its quarter metres are
            --  never come to one by one)
            if Corner_Steps_Here then
               for Cn in 1 .. 4 loop
                  Cross (4 + Cn, 0) := False;
               end loop;
            end if;
            --  the flights
            for Sd in Side loop
               for From in 0 .. Integer'Min (Path_Cut_Most, Cut.Slices (Sd) - 1) loop
                  if Level (Sd, From) and then not (Corner_Steps_Here and then Cross (Sd, From)) then
                     Flight (Step_On ((Ok => True, S => Sd, C => From, Dir => -1, Via => 0)));
                     Flight (Step_On ((Ok => True, S => Sd, C => From, Dir => 1, Via => 0)));
                  end if;
               end loop;
            end loop;
            if Corner_Steps_Here then
               for Cn in 1 .. 4 loop
                  if Level (4 + Cn, 0) then
                     Flight (Off_Corner (Cn, Side_A (Cn)));
                     Flight (Off_Corner (Cn, Side_B (Cn)));
                  end if;
               end loop;
            end if;
            for Sd in Side loop
               for Sc in Sl loop
                  if To (Sd, Sc) >= 0 or else (Corner_Of (Sd, Sc) > 0 and then To (4 + Corner_Of (Sd, Sc), 0) >= 0) then
                     P.Step_Slices := P.Step_Slices + 1;
                  end if;
               end loop;
            end loop;
            --  what may yet change: a quarter metre, or a corner, with one still to lay within a flight's
            --  reach along the round, either way (a flight may come to it from a level one laid later, or
            --  reach it at another step)
            if Strip_Wait_On then
               declare
                  procedure Walk (From : Pos; Sd : Unit_Side; Sc : Integer) is
                     U : Pos := From;
                  begin
                     for K in 1 .. Path_Step_Most loop
                        exit when not U.Ok;
                        if To_Lay (U.S, U.C) then
                           Unsettled (Sd, Sc) := True;
                        end if;
                        U := Step_On (U);
                     end loop;
                  end Walk;
               begin
                  for Sd in Side loop
                     for Sc in 0 .. Integer'Min (Path_Cut_Most, Cut.Slices (Sd) - 1) loop
                        if N (Sd, Sc) > 0 or else Unread (Sd, Sc) then
                           Walk (Step_On ((Ok => True, S => Sd, C => Sc, Dir => -1, Via => 0)), Sd, Sc);
                           Walk (Step_On ((Ok => True, S => Sd, C => Sc, Dir => 1, Via => 0)), Sd, Sc);
                        end if;
                     end loop;
                  end loop;
                  if Corner_Steps_Here then
                     for Cn in 1 .. 4 loop
                        Walk (Off_Corner (Cn, Side_A (Cn)), 4 + Cn, 0);
                        Walk (Off_Corner (Cn, Side_B (Cn)), 4 + Cn, 0);
                     end loop;
                  end if;
               end;
            end if;
            --  its columns: of the plan, and what the walls beside them are planned against
            for I in Wall_Ix loop
               for J in Wall_Ix loop
                  if Is_Path (I, J) then
                     declare
                        Cn : constant Natural := (if Corner_Steps_Here then Cross_Of (Cut, X0 + I, Y0 + J) else 0);
                     begin
                        if Cn > 0 then
                           if To (4 + Cn, 0) >= 0 then
                              P.Step (I, J) := True;
                              Read (I, J) := Integer_16 (To (4 + Cn, 0));
                           end if;
                           Path_Unsettled (I, J) := Unsettled (4 + Cn, 0);
                        else
                           for Sd in Side loop
                              declare
                                 Sc : constant Integer := Slice_Of (Cut, Sd, X0 + I, Y0 + J);
                              begin
                                 if Sc >= 0 and then To (Sd, Sc) >= 0 then
                                    P.Step (I, J) := True;
                                    Read (I, J) := Integer_16 (To (Sd, Sc));
                                 end if;
                                 if Sc >= 0 and then Unsettled (Sd, Sc) then
                                    Path_Unsettled (I, J) := True;
                                 end if;
                              end;
                           end loop;
                        end if;
                     end;
                  end if;
               end loop;
            end loop;
         end Plan_Steps;
      begin
         P.X0 := X0;
         P.Y0 := Y0;
         P.Level := L;
         P.Floor := [others => [others => False]];
         for K in Zones (Camp_Zone_N).First + 1 .. Zones (Camp_Zone_N).First + Zones (Camp_Zone_N).N loop
            for X in Integer (Runs (K).X0) .. Integer (Runs (K).X1) loop
               if X - X0 in Wall_Ix and then Integer (Runs (K).Y) - Y0 in Wall_Ix then
                  P.Floor (X - X0, Integer (Runs (K).Y) - Y0) := True;
               end if;
            end loop;
         end loop;
         --  which sides have a stair, and where: all the width of it against a bank of
         --  Square_Stair_Least_B blocks or more, all one way, and none of it over Square_Stair_Most_B
         declare
            type Bank is record
               Seen : Natural := 0;
               None, Up, Down : Boolean := False;
               Least : Integer := Integer'Last;
               Most  : Integer := 0;
            end record;
            Banks : array (Side, Stair_Spot) of Bank;
            function Banked (Bk : Bank) return Boolean is
              (Bk.Seen > 0 and then not Bk.None and then Bk.Least >= Square_Stair_Least_B
               and then not (Bk.Up and then Bk.Down));
            function Takes (Bk : Bank) return Boolean is (Banked (Bk) and then Bk.Most <= Square_Stair_Most_B);
            --  (the end of each side that a walk round the square with the floor on the right comes to
            --  last, and the corner each end is: 1 .. 4 round the square the same way)
            Last_End  : constant array (Side) of Stair_Spot := [At_Low, At_High, At_High, At_Low];
            --  (the end of another side that each end of a side meets in its corner: where that
            --  side's own path comes in level, the corner is a level way in already)
            type Meeting is record
               Sd   : Side;
               Spot : Stair_Spot;
            end record;
            Meets : constant array (Side, Boolean) of Meeting :=
              [1 => [False => (4, At_High), True => (3, At_High)], 2 => [False => (4, At_Low), True => (3, At_Low)],
               3 => [False => (2, At_High), True => (1, At_High)], 4 => [False => (2, At_Low), True => (1, At_Low)]];
            function Level (Bk : Bank) return Boolean is
              (Bk.Seen > 0 and then not Bk.None and then Bk.Most <= Retain_Over_B);
            function Level_Corner (Sd : Side; High : Boolean) return Boolean is
              (Level (Banks (Meets (Sd, High).Sd, Meets (Sd, High).Spot)));
            Corner_Of : constant array (Side, Boolean) of Positive :=
              [1 => [False => 2, True => 1], 2 => [False => 3, True => 4],
               3 => [False => 4, True => 1], 4 => [False => 3, True => 2]];        --  (True: its high end)
         begin
            for I in Wall_Ix loop
               for J in Wall_Ix loop
                  if P.Floor (I, J) then
                     for A in Axis loop
                        declare
                           K, S, Oi, Oj, R : Integer;
                        begin
                           Ring_Of (I, J, A, K, S);
                           if K in 1 .. 2 then
                              for Spot in Stair_Spot loop
                                 if In_Spot (I, J, A, Spot) then
                                    declare
                                       Bk : Bank renames Banks (Side_Of (A, S), Spot);
                                    begin
                                       Outside (I, J, A, S, K + Strip_Of (Side_Of (A, S)), Oi, Oj);  --  (the path beyond its strip)
                                       R := Reading (Oi, Oj);
                                       Bk.Seen := Bk.Seen + 1;
                                       if R < 0 then
                                          Bk.None := True;
                                       else
                                          Bk.Least := Integer'Min (Bk.Least, abs (R - L));
                                          Bk.Most := Integer'Max (Bk.Most, abs (R - L));
                                          Bk.Up := Bk.Up or else R > L;
                                          Bk.Down := Bk.Down or else R < L;
                                       end if;
                                    end;
                                 end if;
                              end loop;
                           end if;
                        end;
                     end loop;
                  end if;
               end loop;
            end loop;
            for Sd in Side loop
               for Spot in Stair_Spot loop
                  declare
                     Bk : Bank renames Banks (Sd, Spot);
                     Rd : constant Boolean := Bk.Seen > 0 and then not Bk.None;
                  begin
                     P.Sites (Sd, Spot) :=
                       (Read => Rd, Takes => Takes (Bk), Banked => Banked (Bk),
                        Level => Level (Bk), Up => Bk.Up and then not Bk.Down,
                        Least_B => (if Rd then Bk.Least else 0), Most_B => Bk.Most);
                  end;
               end loop;
            end loop;
            for Sd in Side loop
               if Banked (Banks (Sd, At_Middle)) then
                  if Banks (Sd, At_Middle).Most > Square_Stair_Most_B then
                     P.Too_High := P.Too_High + 1;
                  elsif not In_Corner then
                     Stair_Of (Sd) := At_Middle;
                  else
                     --  at an end of its side, judged where it stands: the one that takes it; of two,
                     --  the one whose corner is not a level way in already (the opposite corner from
                     --  the level one), else the lower bank, and of two as high the end come to last
                     declare
                        Lo : Bank renames Banks (Sd, At_Low);
                        Hi : Bank renames Banks (Sd, At_High);
                     begin
                        if Takes (Lo) and then Takes (Hi) then
                           Stair_Of (Sd) :=
                             (if Level_Corner (Sd, False) /= Level_Corner (Sd, True)
                              then (if Level_Corner (Sd, False) then At_High else At_Low)
                              elsif Lo.Most < Hi.Most then At_Low elsif Hi.Most < Lo.Most then At_High else Last_End (Sd));
                        elsif Takes (Lo) then
                           Stair_Of (Sd) := At_Low;
                        elsif Takes (Hi) then
                           Stair_Of (Sd) := At_High;
                        else
                           P.Lost := P.Lost + 1;
                           if (Banked (Lo) and then Lo.Most > Square_Stair_Most_B)
                             or else (Banked (Hi) and then Hi.Most > Square_Stair_Most_B)
                           then
                              P.Too_High := P.Too_High + 1;
                           end if;
                        end if;
                     end;
                  end if;
               end if;
            end loop;
            --  one stair to a corner: of two sides' there, the lower bank's, and of two as high the one
            --  of the side that ends there last
            if In_Corner then
               for Sa in Side loop
                  for Sb in Sa + 1 .. 4 loop
                     if Stair_Of (Sa) /= No_Stair and then Stair_Of (Sb) /= No_Stair
                       and then Corner_Of (Sa, Stair_Of (Sa) = At_High) = Corner_Of (Sb, Stair_Of (Sb) = At_High)
                     then
                        declare
                           Ma : constant Integer := Banks (Sa, Stair_Of (Sa)).Most;
                           Mb : constant Integer := Banks (Sb, Stair_Of (Sb)).Most;
                           Keep_A : constant Boolean :=
                             (if Ma /= Mb then Ma < Mb else Stair_Of (Sa) = Last_End (Sa));
                        begin
                           if Keep_A then
                              Stair_Of (Sb) := No_Stair;
                           else
                              Stair_Of (Sa) := No_Stair;
                           end if;
                           P.Shared := P.Shared + 1;
                        end;
                     end if;
                  end loop;
               end loop;
            end if;
            for Sd in Side loop
               if Stair_Of (Sd) /= No_Stair then
                  P.Stairs := P.Stairs + 1;
                  if Stair_Of (Sd) /= At_Middle and then Level_Corner (Sd, Stair_Of (Sd) = At_High) then
                     P.By_Level := P.By_Level + 1;
                  end if;
               end if;
            end loop;
            P.Stair_At := Stair_Of;
         end;
         --  (the path's steps of stone: after the stairs are decided, before anything is planned against the path)
         if Steps_Here then
            Plan_Steps;
         end if;
         --  each floor column's top
         for I in Wall_Ix loop
            for J in Wall_Ix loop
               P.Top (I, J) := Integer_16 (L);
               P.Stone (I, J) := Integer_16 (L + 1);
               if P.Floor (I, J) then
                  declare
                     T : array (Axis) of Integer := [others => L];
                     Base : array (Axis) of Integer := [others => Integer'Last];      --  (the lowest row of its lift)
                  begin
                     for A in Axis loop
                        declare
                           K, S, Oi, Oj, R : Integer;
                        begin
                           Ring_Of (I, J, A, K, S);
                           if K in 1 .. K_Most then
                              Outside (I, J, A, S, K + Strip_Of (Side_Of (A, S)), Oi, Oj);
                              R := Reading (Oi, Oj);
                              if R >= 0 then
                                 if In_Stair (I, J, A, S) then
                                    --  (its steps are cut into the floor from its edge, as they were: the strip
                                    --  before them is a landing at the path's level)
                                    T (A) := Stair_Top (R, K, L, Rows);
                                    Is_Stair (I, J) := Is_Stair (I, J) or else T (A) /= L;
                                 elsif Out_Sq then
                                    --  the floor is kept whole: the wall of its bank stands in the strip outside it;
                                    --  with no strip kept on that side the bank is left earth
                                    if K = 1 and then abs (R - L) > Retain_Over_B then
                                       P.Need (Side_Of (A, S)) :=
                                         Natural'Max (P.Need (Side_Of (A, S)), (abs (R - L) + Square_Lift_B - 1) / Square_Lift_B);
                                       if Strip_Of (Side_Of (A, S)) = 0 then
                                          P.Unwalled := P.Unwalled + 1;
                                       end if;
                                    end if;
                                 else
                                    Wall_Column (R, K, L, T (A), Base (A));
                                    if Base (A) > T (A) then
                                       Base (A) := Integer'Last;
                                    end if;
                                    if abs (R - L) > Retain_Over_B then
                                       P.Highest := Natural'Max (P.Highest, abs (R - L));
                                       P.Lifts := Natural'Max (P.Lifts, (abs (R - L) + Square_Lift_B - 1) / Square_Lift_B);
                                    end if;
                                 end if;
                              end if;
                           end if;
                        end;
                     end loop;
                     --  (at a corner, by the side that asks more of it: the higher of two walls against
                     --  higher ground, the lower of two ledges)
                     P.Top (I, J) := Integer_16
                       (if T (Along) > L or else T (Across) > L then Integer'Max (T (Along), T (Across))
                        else Integer'Min (T (Along), T (Across)));
                     --  (a lift is stone from its lowest row to its top: kept until what is beside it is known)
                     if Integer'Min (Base (Along), Base (Across)) <= Integer (P.Top (I, J)) then
                        P.Stone (I, J) := Integer_16 (Integer'Min (Base (Along), Base (Across)));
                     else
                        P.Stone (I, J) := P.Top (I, J) + 1;
                     end if;
                  end;
               end if;
            end loop;
         end loop;
         --  A square whose walls stand outside its floor: the columns of its strips.  Ring Kr out
         --  from the floor's edge (1: beside the floor), of Wd kept on that side, the laid path beyond
         --  the strip at row R: the wall its bank wants, N lifts of it, stands in the rings nearest
         --  the floor, a ring a lift, counted up from the lower ground toward the higher (against
         --  higher ground the lowest lift beside the floor and the top one, flush with the path,
         --  furthest out; holding the floor up, the top lift beside the floor, flush with it, and
         --  the lowest furthest out).  With fewer rings than lifts the outermost ring takes what is
         --  left (Short).  The rings beyond the wall, and all of them where the path lies within a
         --  block of the floor and no wall is wanted, are brought to the path's level and capped with
         --  stone: dug down where they stand over it, filled with stone where they lie under it (left
         --  as they lay, they were tufts of grass on the wall's top and a slot between wall and path).
         --  (Where the path is level with the floor the strip was laid level with it, as path:
         --  Lay_Metre.)  Before a stair the rings are a
         --  landing of stone at the path's level: its steps are cut into the floor, as they were.
         --  At a corner, where two strips meet, a column is what the side that asks more of
         --  it says, as a corner of the floor was.  A column with no laid path to go by (or a tree's
         --  foot) has nothing planned.
         if Out_Sq then
            for I in Wall_Ix loop
               for J in Wall_Ix loop
                  if not P.Floor (I, J) and then Part_Of (Geo, X0 + I, Y0 + J) = Part_Strip then
                     if Zone_Of_Block (X0 + I, Y0 + J) /= 0 then
                        P.Zoned := P.Zoned + 1;
                     end if;
                     declare
                        Own  : constant Integer := Top_By (X0 + I, Y0 + J, L);
                        U, V : Float;
                        None : constant Integer := Integer'First;
                        T    : array (Axis) of Integer := [others => None];
                        Base : array (Axis) of Integer := [others => Integer'Last];
                        Step : array (Axis) of Boolean := [others => False];
                        Waits : Boolean := False;        --  (the path of one of its sides is still to lay beside it)
                     begin
                        Frame (I, J, U, V);
                        if Own >= 0 and then Mat (X0 + I, Y0 + J, Own + 1) not in Trunk then
                           for A in Axis loop
                              declare
                                 C  : constant Float := (if A = Along then U else V);
                                 S  : constant Integer := (if C >= 0.0 then 1 else -1);
                                 Sd : constant Side := Side_Of (A, S);
                                 Wd : constant Natural := Square_Strip (Sd);
                                 Kr : constant Integer := Integer (Float'Floor ((abs C - Half) / W)) + 1;
                                 Oi, Oj, R : Integer;
                              begin
                                 if abs C >= Half and then Kr in 1 .. Wd then
                                    Outside (I, J, A, S, Wd - Kr + 1, Oi, Oj);
                                    R := Reading (Oi, Oj);
                                    --  (its path laid there, but a quarter metre within a flight's reach of it still
                                    --  to lay: it may yet be made a step, at another row than it lies at)
                                    if R >= 0 and then Oi in Wall_Ix and then Oj in Wall_Ix and then Path_Unsettled (Oi, Oj) then
                                       Waits := True;
                                    end if;
                                    if R < 0 then
                                       if Oi in Wall_Ix and then Oj in Wall_Ix
                                         and then Mat (X0 + Oi, Y0 + Oj, Integer'Max (0, Top_By (X0 + Oi, Y0 + Oj, L)))
                                                    in Grass | Dirt | Sand | Gravel | Clay | Placer_Gravel | Bog_Iron
                                         and then In_Square_Path (X0 + Oi, Y0 + Oj)
                                       then
                                          if Column_To_Lay (X0 + Oi, Y0 + Oj) then
                                             Waits := True;
                                          end if;
                                          if Kr = Wd then
                                             P.Unready := P.Unready + 1;     --  (its path still to lay there: it waits)
                                          end if;
                                       else
                                          --  (no path there to go by, and none to come: a boulder stands in its
                                          --  line.  The wall runs on before the rock as it stands beside it, by
                                          --  the path nearest along that side: left as it lay, the strip there was
                                          --  a bank of earth and rock between two walls, a place a serf could
                                          --  step down onto from the path above and not leave)
                                          R := Near_Reading (Oi, Oj, A);
                                       end if;
                                    end if;
                                    if R < 0 then
                                       null;
                                    elsif In_Stair (I, J, A, S) then
                                       --  (before a stair: a landing at the path's level, of stone)
                                       T (A) := R;
                                       if Own < R then
                                          Base (A) := Own + 1;
                                       end if;
                                       Step (A) := True;
                                    else
                                       declare
                                          H  : constant Integer := R - L;
                                          N  : constant Integer :=
                                            (if abs H > Retain_Over_B then (abs H + Square_Lift_B - 1) / Square_Lift_B else 0);
                                          Ne : constant Integer := Integer'Min (N, Wd);
                                       begin
                                          P.Need (Sd) := Natural'Max (P.Need (Sd), N);
                                          if Kr > Ne and then Own = R
                                            and then Mat (X0 + I, Y0 + J, Own) in Footpath | Fieldstone
                                          then
                                             T (A) := Own;                   --  (laid as path with its path, or capped: done)
                                          elsif Kr > Ne then
                                             --  (beyond its wall, or where no wall is wanted: capped with stone
                                             --  at the path's level, from its own ground up where that lies lower)
                                             T (A) := R;
                                             Base (A) := Integer'Min (R, Own + 1);
                                             P.Capped := P.Capped + 1;
                                          else
                                             Wall_Column (R, N - Kr + 1, L, T (A), Base (A));
                                             if Kr = Ne and then Ne < N then
                                                if H > 0 then
                                                   T (A) := R;
                                                else
                                                   Base (A) := R + 1;
                                                end if;
                                                P.Short := P.Short + 1;
                                             end if;
                                             if Base (A) > T (A) then
                                                Base (A) := Integer'Last;
                                             end if;
                                             P.Highest := Natural'Max (P.Highest, abs H);
                                             P.Lifts := Natural'Max (P.Lifts, N);
                                          end if;
                                       end;
                                    end if;
                                 end if;
                              end;
                           end loop;
                        end if;
                        --  **A strip's column waits for the path it is planned against** (Strip_Wait_On).  A
                        --  column of two sides' strips, planned by the one that is laid alone, was walled against
                        --  that path; when the other side's metre beside it was laid after, the stone stood where
                        --  that side's quarter metre would have been laid level, strip and all, or stood higher
                        --  than both sides ask together, and nothing takes laid stone up (with their walls built
                        --  when half their paths were laid, 23 of 323 squares stood otherwise than built in
                        --  order).  And a column beside a quarter metre that was laid, while one within a
                        --  flight's reach of it was not, was capped at the path's row there, a block over the
                        --  step that quarter metre then became (3 more).  Only while a path is still to lay: a
                        --  boulder in its line gives the reading beside it, as before.
                        if Waits and then Strip_Wait_On then
                           T := [others => None];
                        end if;
                        if T (Along) /= None or else T (Across) /= None then
                           declare
                              Ta : constant Integer := (if T (Along) /= None then T (Along) else T (Across));
                              Tb : constant Integer := (if T (Across) /= None then T (Across) else T (Along));
                              Asked : constant Integer :=
                                (if Ta > L or else Tb > L then Integer'Max (Ta, Tb) else Integer'Min (Ta, Tb));
                              --  (a column laid as path, with a quarter metre of path brought level, is left
                              --  as path unless something is to stand on it: at a corner the other side's
                              --  reading may lie a block under it)
                              As_Path : constant Boolean := Mat (X0 + I, Y0 + J, Own) = Footpath and then Asked <= Own;
                              Top : constant Integer := (if As_Path then Own else Asked);
                              Lowest : constant Integer :=
                                (if As_Path then Integer'Last else Integer'Min (Base (Along), Base (Across)));
                           begin
                              In_Strip (I, J) := True;
                              P.Floor (I, J) := True;                        --  (a column of the plan, as the floor's are)
                              P.Top (I, J) := Integer_16 (Top);
                              P.Stone (I, J) := Integer_16 (if Lowest <= Top then Lowest else Top + 1);
                              Is_Stair (I, J) := not As_Path
                                and then ((Step (Along) and then T (Along) = Top) or else (Step (Across) and then T (Across) = Top));
                           end;
                        end if;
                     end;
                  end if;
               end loop;
            end loop;
         end if;
         --  (the path's steps: columns of the plan from here on, each a tread of stone at its row; what is
         --  under a tread that is raised is stone too: Column_Work lays from just over the ground up)
         if Steps_Here then
            for I in Wall_Ix loop
               for J in Wall_Ix loop
                  if P.Step (I, J) then
                     P.Floor (I, J) := True;
                     P.Top (I, J) := Read (I, J);
                     P.Stone (I, J) := Read (I, J);
                     P.Path_Steps := P.Path_Steps + 1;
                     P.Columns := P.Columns + 1;
                  end if;
               end loop;
            end loop;
         end if;
         --  and what of each is stone: where it stands more than a block over what is beside it (a
         --  lower column of the floor, the path outside), from there up; a stair's step, its tread
         for I in Wall_Ix loop
            for J in Wall_Ix loop
               if P.Floor (I, J) and then not P.Step (I, J) then
                  declare
                     Top : constant Integer := Integer (P.Top (I, J));
                     Lo  : Integer := Top;
                     procedure Beside (Ni, Nj : Integer) is
                        U, V : Float;
                     begin
                        if Of_Floor (Ni, Nj) and then not P.Step (Ni, Nj) then
                           Lo := Integer'Min (Lo, Integer (P.Top (Ni, Nj)));
                        elsif Ni in Wall_Ix and then Nj in Wall_Ix then
                           Frame (Ni, Nj, U, V);
                           if Float'Max (abs U, abs V) >= Half then           --  (outside the floor: its path)
                              declare
                                 R : constant Integer := Reading (Ni, Nj);
                              begin
                                 if R >= 0 then
                                    --  (a square whose walls stand outside its floor: no column of the
                                    --  floor is made stone for the path's sake)
                                    if not Out_Sq or else In_Strip (I, J) then
                                       Lo := Integer'Min (Lo, R);
                                    end if;
                                 elsif Out_Sq and then (In_Strip (I, J) or else Part_Of (Geo, X0 + Ni, Y0 + Nj) /= Part_Path) then
                                    null;                                    --  (counted with the strips, above)
                                 elsif Mat (X0 + Ni, Y0 + Nj, Integer'Max (0, Top_By (X0 + Ni, Y0 + Nj, L)))
                                         in Grass | Dirt | Sand | Gravel | Clay | Placer_Gravel | Bog_Iron
                                   and then In_Square_Path (X0 + Ni, Y0 + Nj)
                                 then
                                    P.Unready := P.Unready + 1;              --  (its path still to lay there)
                                 end if;
                              end;
                           end if;
                        end if;
                     end Beside;
                  begin
                     Beside (I + 1, J);
                     Beside (I - 1, J);
                     Beside (I, J + 1);
                     Beside (I, J - 1);
                     P.Stone (I, J) := Integer_16
                       (Integer'Min (Integer (P.Stone (I, J)),
                                     (if Top - Lo > Retain_Over_B then Lo + 1 elsif Is_Stair (I, J) then Top else Top + 1)));
                     if In_Strip (I, J) then
                        if Integer (P.Stone (I, J)) <= Top then              --  (of a strip: what is stone)
                           P.Columns := P.Columns + 1;
                        end if;
                     elsif Top /= L or else Integer (P.Stone (I, J)) <= Top then
                        P.Columns := P.Columns + 1;
                        --  (stone in the floor that is neither a stair's step nor the earth beside one, faced)
                        if Out_Sq and then not Is_Stair (I, J)
                          and then not (for some D in 1 .. 4 =>
                                          I + Di (D) in Wall_Ix and then J + Dj (D) in Wall_Ix
                                          and then Is_Stair (I + Di (D), J + Dj (D)))
                        then
                           P.Inside := P.Inside + 1;
                        end if;
                     end if;
                  end;
               end if;
            end loop;
         end loop;
         P.Ok := True;
      end;
   end Plan_Walls;

   --  What is still to do in one column of the plan, read from its blocks:
   --  earth over its planned top to dig off (top down), then stone to lay
   --  from its lowest stone row, or from just over its ground where that
   --  lies lower, up to its top (bottom up).  Rock is left where it is, and
   --  counts as wall; a column with water in the way has nothing to do.
   --  (Path: a column of the square's path that is to be a step: its trodden top is dug and turned
   --  to stone as earth is.)
   procedure Column_Work
     (X, Y, Top, Stone, L : Integer; Visit : not null access procedure (X, Y, Z : Integer; Dig : Boolean);
      Path : Boolean := False)
   is
      Z : Integer := Top_By (X, Y, L);
      function Soft (M : Material) return Boolean is (Is_Earth (M) or else (Path and then M = Footpath));
   begin
      if Z < 0 then
         return;
      end if;
      while Z > Top and then Soft (Mat (X, Y, Z)) loop
         Visit (X, Y, Z, True);
         Z := Z - 1;
      end loop;
      if Z > Top then
         return;                              --  (rock, or stone laid before, over its top: left)
      end if;
      for Zs in Integer'Min (Stone, Z + 1) .. Top loop
         declare
            M : constant Material := Mat (X, Y, Zs);
         begin
            exit when Class_Of (M) = Liquid;
            if M /= Fieldstone and then (Soft (M) or else Class_Of (M) /= Solid) then
               Visit (X, Y, Zs, False);
            end if;
         end;
      end loop;
   end Column_Work;

   --  A column of the plan that is wall, ledge or stair (not plain floor).
   function Is_Wall (P : Wall_Plan; I, J : Integer) return Boolean is
     (I in Wall_Ix and then J in Wall_Ix and then P.Floor (I, J)
      and then (Integer (P.Top (I, J)) /= P.Level or else Integer (P.Stone (I, J)) <= Integer (P.Top (I, J))));

   --  A column can be worked at now, without leaving a place a serf drops
   --  into and cannot climb out of while the rest is still to build: **the
   --  walls are built from the bank outward and dug from the path inward.**
   --  It is not raised while a column beside it that is to stand higher (the
   --  lift behind it, the step above it) is still lower than its own top is
   --  to be: raised first, it would wall off a trench behind it (a lower lift
   --  before the upper, a stair's lower steps before its upper).  It is not
   --  dug while a column beside it that is to lie lower (the step below it,
   --  toward the path) still stands over its own planned top: dug first, it
   --  would be a slot.  (Neither waits for a column in which nothing more can
   --  be done.)
   function Wall_Ready (P : Wall_Plan; I, J : Integer) return Boolean is
      T : constant Integer := Integer (P.Top (I, J));
      A : constant Integer := Top_By (P.X0 + I, P.Y0 + J, P.Level);
      function Left (Ni, Nj : Integer) return Boolean is
         Any : Boolean := False;
         procedure Note (X, Y, Z : Integer; Dig : Boolean) is
            pragma Unreferenced (X, Y, Z, Dig);
         begin
            Any := True;
         end Note;
      begin
         Column_Work (P.X0 + Ni, P.Y0 + Nj, Integer (P.Top (Ni, Nj)), Integer (P.Stone (Ni, Nj)), P.Level, Note'Access,
                      Path => P.Step (Ni, Nj));
         return Any;
      end Left;
      function Waits (Ni, Nj : Integer) return Boolean is
      begin
         if not (Ni in Wall_Ix and then Nj in Wall_Ix and then P.Floor (Ni, Nj)) then
            return False;
         end if;
         declare
            Tn : constant Integer := Integer (P.Top (Ni, Nj));
            An : constant Integer := Top_By (P.X0 + Ni, P.Y0 + Nj, P.Level);
         begin
            return ((A < T and then Tn > T and then An < T) or else (A > T and then Tn < T and then An > T))
              and then Left (Ni, Nj);
         end;
      end Waits;
   begin
      return A = T
        or else not (Waits (I + 1, J) or else Waits (I - 1, J) or else Waits (I, J + 1) or else Waits (I, J - 1));
   end Wall_Ready;

   --  Blocks of stone still to lay in them, and of earth to dig off for
   --  them; and which patches of the camp's ground have any that can be
   --  worked at now.
   procedure Walls_Wanting (P : Wall_Plan; Stone_N, Dig_N : out Natural; Wants : out Patch_Flags; Sum : out Patch_Sums) is
      S, D : Natural := 0;
      Now  : Boolean := False;
      procedure Note (X, Y, Z : Integer; Dig : Boolean) is
         pragma Unreferenced (Z);
         Pt : constant Natural := Patch_Near (X, Y);
      begin
         if Dig then
            D := D + 1;
         else
            S := S + 1;
         end if;
         if Pt > 0 and then Now then
            Wants (Pt) := True;
            Sum (Pt) := Sum (Pt) + ((Float (X) + 0.5) * 0.25, (Float (Y) + 0.5) * 0.25, 1.0);
         end if;
      end Note;
   begin
      Wants := [others => False];
      Sum := [others => (0.0, 0.0, 0.0)];
      if P.Ok then
         for I in Wall_Ix loop
            for J in Wall_Ix loop
               if Is_Wall (P, I, J) then
                  Now := Wall_Ready (P, I, J);
                  Column_Work (P.X0 + I, P.Y0 + J, Integer (P.Top (I, J)), Integer (P.Stone (I, J)), P.Level, Note'Access,
                               Path => P.Step (I, J));
               end if;
            end loop;
         end loop;
      end if;
      Stone_N := S;
      Dig_N := D;
   end Walls_Wanting;

   --  Counted (at once when the ground by the square has moved, and once a
   --  minute besides: Advance): what whoever thinks goes by.
   procedure Count_Walls is
      P : Wall_Plan;
      Dig_N : Natural;
      Wants : Patch_Flags;
      Sum   : Patch_Sums;
   begin
      Walls_Stale := False;
      Wall_Left_N := 0;
      --  (not before its fire has been lit: counted as soon as the hearth stood, the walls took the
      --  hands that bring the first log, and at one square of eight the fire was lit most of an hour
      --  later for them.  Or, with no fire lit at all, a band nobody has given a forester or a cook,
      --  from the first count after the colony's second day: Walls_Day_Ticks, the minute's own count,
      --  so that a run saved on the day's turn and loaded counts them no sooner than the straight one.
      --  After its first day they began three hours before the fire of a square whose first log came
      --  the next morning, and that log an hour later)
      if Walls_On and then Labour_On and then Camp_Square and then Camp_Built
        and then (N_Burnt > 0 or else Fuel_H > 0.0 or else Ember_H > 0.0 or else Tick_N >= Walls_Day_Ticks)
      then
         Plan_Walls (P);
         Walls_Wanting (P, Wall_Left_N, Dig_N, Wants, Sum);
      end if;
   end Count_Walls;
   function Walls_Left return Natural is (Wall_Left_N);

   function Square_Walls_State return Walls_View is
      P : Wall_Plan;
      V : Walls_View;
      Wants : Patch_Flags;
      Sum   : Patch_Sums;
   begin
      if Walls_On and then Camp_Built then
         Plan_Walls (P);
         Walls_Wanting (P, V.Stone_Left, V.Dig_Left, Wants, Sum);
         V.Columns := P.Columns;
         V.Highest_B := P.Highest;
         V.Stairs := P.Stairs;
         V.Too_High := P.Too_High;
         V.Stair_At := P.Stair_At;
         V.Stairs_Lost := P.Lost;
         V.Stairs_Shared := P.Shared;
         V.Stairs_By_Level := P.By_Level;
         V.Lifts := P.Lifts;
         V.Unready := P.Unready;
         if Camp_Square and then Square_Outside then
            V.Outside := True;
            V.Strip := Square_Strip;
            V.Need := P.Need;
            V.Short := P.Short;
            V.Unwalled := P.Unwalled;
            V.Inside := P.Inside;
            V.Capped := P.Capped;
            V.Strip_Zoned := P.Zoned;
            V.Path_Steps := P.Path_Steps;
            V.Step_Slices := P.Step_Slices;
            V.Steps_Barred := P.Barred;
         end if;
      end if;
      return V;
   end Square_Walls_State;

   function Square_Stair_Sites return Stair_Sites is
      P : Wall_Plan;
   begin
      if Walls_On and then Camp_Built then
         Plan_Walls (P);
         return P.Sites;
      end if;
      return [others => [others => <>]];
   end Square_Stair_Sites;

   function Square_Path_Middle (Side : Positive) return Vec3 is
      G  : constant Square_Geo := Geo_Now;
      Ex : constant Float := (if G.Aslant then 1.0 / Sqrt (2.0) else 1.0);
      Ey : constant Float := (if G.Aslant then 1.0 / Sqrt (2.0) else 0.0);
      D  : constant Float :=
        (if Side in 1 .. 4 then G.Half + Float (G.Strip (Side)) * Ring_Width (G) + Path_Width_M / 2.0 else 0.0);
      U  : constant Float := (case Side is when 1 => D, when 2 => -D, when others => 0.0);
      V  : constant Float := (case Side is when 3 => D, when 4 => -D, when others => 0.0);
      X  : constant Float := G.Mx + U * Ex - V * Ey;
      Y  : constant Float := G.My + U * Ey + V * Ex;
      Z  : constant Float := Castle.Nav.Surface_Z (X, Y);
   begin
      return (X, Y, Z);
   end Square_Path_Middle;

   --  A bout at them by member I (0: on the spot, by nobody): in patch From
   --  first (0: anywhere), then in the patches nearest it, the earth over a
   --  ledge or a stair's steps is dug off and thrown aside, and stone laid,
   --  Most blocks of it at the most.  Whoever stands still where a block
   --  goes steps aside; a block with someone in its way is left for another
   --  bout.
   procedure Wall_Bout (From : Natural; I : Natural; Most : Natural; Laid, Dug : out Natural) is
      P : Wall_Plan;
      Stone_N, Dig_N : Natural;
      Wants : Patch_Flags;
      Sum   : Patch_Sums;
      Done  : Patch_Flags := [others => False];
      Cur   : Natural := From;
      Mid   : Vec3 := (0.0, 0.0, 0.0);
      N_Laid, N_Dug : Natural := 0;
      Stopped : Boolean := False;      --  (a block of this column could not be laid: nothing over it is, this bout)
      Step_Now : Boolean := False;     --  (the column being worked is a step of the square's path)
      procedure Work (X, Y, Z : Integer; Dig : Boolean) is
      begin
         if Stopped then
            return;
         end if;
         if Dig and then Step_Now and then N_Laid >= Most then
            --  (a step of the path is dug only with the stone for its tread in hand, and the tread
            --  laid in the same bout: dug and left, its top is earth, which no path's reading knows,
            --  and the flight it was of would be planned no more)
            Stopped := True;
         elsif Dig then
            Write_Src (X, Y, Z, Air_Block);
            N_Dug := N_Dug + 1;
         elsif N_Laid >= Most then
            Stopped := True;
         else
            if N_Members > 0 and then Someone_At (X, Y, Z, But => 0) then
               if Way_On then
                  Make_Way (X, Y, Z, But => 0);
               end if;
               if Someone_At (X, Y, Z, But => 0) then
                  Stopped := True;
                  return;
               end if;
            end if;
            Write_Src (X, Y, Z, (Mat => Fieldstone, State => 0));
            N_Laid := N_Laid + 1;
         end if;
      end Work;
      --  (a patch is gone over until a pass of it does nothing more: a column that waited for the one
      --  beside it is worked at once that one is done)
      procedure Do_Patch (Pt : Natural) is
         Before : Natural;
      begin
         loop
            Before := N_Laid + N_Dug;
            for Ci in Wall_Ix loop
               for Cj in Wall_Ix loop
                  if Is_Wall (P, Ci, Cj) and then (Pt = 0 or else Patch_Near (P.X0 + Ci, P.Y0 + Cj) = Pt)
                    and then Wall_Ready (P, Ci, Cj)
                  then
                     Stopped := False;
                     Cut_Plants (P.X0 + Ci, P.Y0 + Cj, Integer'Max (0, Top_By (P.X0 + Ci, P.Y0 + Cj, P.Level)));
                     Step_Now := P.Step (Ci, Cj);
                     Column_Work (P.X0 + Ci, P.Y0 + Cj, Integer (P.Top (Ci, Cj)), Integer (P.Stone (Ci, Cj)), P.Level,
                                  Work'Access, Path => Step_Now);
                  end if;
               end loop;
            end loop;
            exit when N_Laid + N_Dug = Before or else N_Laid >= Most;
         end loop;
      end Do_Patch;
   begin
      Laid := 0;
      Dug := 0;
      if not (Walls_On and then Camp_Built) then
         return;
      end if;
      Plan_Walls (P);
      if not P.Ok then
         return;
      end if;
      Walls_Wanting (P, Stone_N, Dig_N, Wants, Sum);
      if Cur = 0 then
         Do_Patch (0);
      else
         Mid := (if Sum (Cur).Z > 0.0 then (Sum (Cur).X / Sum (Cur).Z, Sum (Cur).Y / Sum (Cur).Z, 0.0)
                 elsif I > 0 then Band (I).Pos else Camp_At);
         loop
            Do_Patch (Cur);
            Done (Cur) := True;
            exit when N_Laid >= Most;
            --  (what is left of the stone in its hands goes into the nearest patch that wants any)
            declare
               Best   : Natural := 0;
               Best_D : Float := Float'Last;
            begin
               for Pt in Wants'Range loop
                  if Wants (Pt) and then not Done (Pt)
                    and then Flat_Dist ((Sum (Pt).X / Sum (Pt).Z, Sum (Pt).Y / Sum (Pt).Z, 0.0), Mid) < Best_D
                  then
                     Best := Pt;
                     Best_D := Flat_Dist ((Sum (Pt).X / Sum (Pt).Z, Sum (Pt).Y / Sum (Pt).Z, 0.0), Mid);
                  end if;
               end loop;
               exit when Best = 0;
               Cur := Best;
            end;
         end loop;
      end if;
      Laid := N_Laid;
      Dug := N_Dug;
      if N_Laid + N_Dug > 0 then
         Read_Camp_Ground;
         Settle_On_Floor;
         Walls_Stale := True;
         Wall_Left_N := Wall_Left_N - Natural'Min (Wall_Left_N, N_Laid);
      end if;
   end Wall_Bout;

   procedure Build_Walls_Now (Most : Natural := Natural'Last) is
      Laid, Dug : Natural;
   begin
      Wall_Bout (0, 0, Most, Laid, Dug);
      Count_Walls;
   end Build_Walls_Now;

   procedure For_Wall_Plan
     (Visit : not null access procedure (Bx, By, Top, Stone, Level : Integer))
   is
      P : Wall_Plan;
   begin
      if not (Walls_On and then Camp_Built) then
         return;
      end if;
      Plan_Walls (P);
      if P.Ok then
         for I in Wall_Ix loop
            for J in Wall_Ix loop
               if P.Floor (I, J) then
                  Visit (P.X0 + I, P.Y0 + J, Integer (P.Top (I, J)), Integer (P.Stone (I, J)), P.Level);
               end if;
            end loop;
         end loop;
      end if;
   end For_Wall_Plan;

   --  A door's way made again to its path as it lies (the spec, "A door's
   --  way meets its path as it lies"): each column of a hovel's way past its
   --  landing brought to a step between the landing's level and the top of
   --  the laid path beyond the way's end, a block a column from the path's
   --  side back.  Beaten: its top is trodden (the house stands); else earth
   --  (its ground is ready, and the way is trodden when it stands).  Not a
   --  storehouse's (its stair is a flight of stone, End_Steps), nor a hovel's
   --  whose ground is made where it is drawn turned.
   Door_Meet_On : Boolean := True;
   Door_Meet_N  : Natural := 0;
   procedure Set_Door_Meet (On : Boolean) is
   begin
      Door_Meet_On := On;
   end Set_Door_Meet;
   function Door_Meet return Boolean is (Door_Meet_On);
   function Door_Columns_Remade return Natural is (Door_Meet_N);

   procedure Meet_Door (H : Positive; Beaten : Boolean) is
      F : CB.House renames Houses (H).F;
      L : constant Integer := F.Pad - 1;              --  the row of the landing's top
   begin
      if not Door_Meet_On or else Is_Store (F) or else Yard_Turned (F) or else (F.Turn_Ground and then F.Turn /= 0)
        or else F.Door_Run = 0
      then
         return;
      end if;
      for U in Way_Lo (F) .. Way_Hi (F) loop
         declare
            Run : constant Integer := Integer'Max (F.Door_Run, Front_Of (F, U));
            Px  : constant Integer := H_X (F, U, -(Run + 1));
            Py  : constant Integer := H_Y (F, U, -(Run + 1));
            Pz  : constant Integer := Ground_Row (Px, Py, L);
            --  (the first column that may be a step: past the landing, or the way's last where it is no longer)
            First : constant Integer := (if Run > CB.Door_Landing_B then CB.Door_Landing_B + 1 else Run);
            N     : constant Integer := Run - First + 1;
         begin
            if Pz >= 0 and then abs (Pz - L) <= 12 and then Mat (Px, Py, Pz) = Footpath and then Zone_Of_Block (Px, Py) = 0 then
               for T in First .. Run loop
                  declare
                     X    : constant Integer := H_X (F, U, -T);
                     Y    : constant Integer := H_Y (F, U, -T);
                     Want : constant Integer := L + ((Pz - L) * (T - First + 1)) / (N + 1);
                     Top  : constant Integer := Top_By (X, Y, Want);
                  begin
                     if Top >= 0 and then abs (Top - Want) <= 8 and then Top /= Want
                       and then Zone_Of_Block (X, Y) = Houses (H).Zone
                       and then (for all Z in Integer'Min (Top, Want) + 1 .. Want + 2 => Class_Of (Mat (X, Y, Z)) /= Liquid)
                     then
                        Cut_Plants (X, Y, Top);
                        for Z in reverse Want + 1 .. Top loop          --  what stands over the step cut off
                           Write_Src (X, Y, Z, Air_Block);
                        end loop;
                        for Z in Top .. Want - 1 loop                  --  what lies under it filled with earth
                           Write_Src (X, Y, Z, (Mat => Dirt, State => 0));
                        end loop;
                        Write_Src (X, Y, Want, (Mat => (if Beaten then Footpath else Dirt), State => 0));
                        Door_Meet_N := Door_Meet_N + 1;
                     end if;
                  end;
               end loop;
            end if;
         end;
      end loop;
   end Meet_Door;

   --  The footpath from a house's door to the path it fronts: the top of
   --  the ground of its door's way (made a stair with the rest of its
   --  ground) turned to footpath, and what grows on it cut.
   procedure Lay_Door_Path (H : Positive) is
      F    : CB.House renames Houses (H).F;
      procedure Beat (U, V : Integer) is
         X   : constant Integer := H_X (F, U, V);
         Y   : constant Integer := H_Y (F, U, V);
         Top : constant Integer := Top_By (X, Y, F.Pad - 1);
      begin
         if Top >= 0 and then Is_Earth (Mat (X, Y, Top)) and then Zone_Of_Block (X, Y) = Houses (H).Zone then
            Write_Src (X, Y, Top, (Mat => Footpath, State => 0));
            Cut_Plants (X, Y, Top);
         end if;
      end Beat;
   begin
      --  One drawn turned, its ground made where it is drawn, and no stair to
      --  its door: the way is trodden straight out from the door as drawn,
      --  square to its path (a block out and a block along at each step), as
      --  wide as the doorway and a block to either side, to the path's edge.
      if F.Turn_Ground and then F.Turn /= 0 and then F.Door_Run > 0
        and then abs (F.Door_Row - (F.Pad - 1)) <= Retain_Over_B
      then
         declare
            Sg : constant Integer := F.Turn * (F.Ux * F.Vy - F.Uy * F.Vx);
            Mid : constant Integer := (Way_Lo (F) + Way_Hi (F)) / 2;
         begin
            for T in 1 .. Front_Most (F) loop
               exit when Near_Path ((Float (H_X (F, Mid + Sg * T, -T)) + 0.5) * 0.25,
                                    (Float (H_Y (F, Mid + Sg * T, -T)) + 0.5) * 0.25, 0.0);
               for U in Way_Lo (F) - 1 .. Way_Hi (F) + 1 loop
                  Beat (U + Sg * T, -T);
                  Beat (U + Sg * T, -T - 1);
               end loop;
            end loop;
         end;
         return;
      end if;
      if Yard_Turned (F) then               --  (a stockyard along its path: its way in, column by column)
         declare
            Bx : constant Frame_Box :=
              Design_Box (F, Float (Way_Lo (F)) - 0.5, Float (Way_Hi (F)) + 0.5, Float (-Front_Most (F)) - 0.5, -0.5);
         begin
            for U in Bx.U0 .. Bx.U1 loop
               for V in Bx.V0 .. Bx.V1 loop
                  if In_Door_Way (F, U, V) then
                     declare
                        X   : constant Integer := H_X (F, U, V);
                        Y   : constant Integer := H_Y (F, U, V);
                        Top : constant Integer := Top_By (X, Y, Level_Of (F, U, V));
                     begin
                        if Top >= 0 and then Is_Earth (Mat (X, Y, Top)) and then Zone_Of_Block (X, Y) = Houses (H).Zone then
                           Write_Src (X, Y, Top, (Mat => Footpath, State => 0));
                           Cut_Plants (X, Y, Top);
                        end if;
                     end;
                  end if;
               end loop;
            end loop;
         end;
         return;
      end if;
      for U in Way_Lo (F) .. Way_Hi (F) loop
         for T in 1 .. Integer'Max (F.Door_Run, (if F.Door_Run > 0 then Front_Of (F, U) else 0)) loop
            declare
               X   : constant Integer := H_X (F, U, -T);
               Y   : constant Integer := H_Y (F, U, -T);
               Top : constant Integer := Top_By (X, Y, Level_Of (F, U, -T));
            begin
               if Top >= 0 and then Is_Earth (Mat (X, Y, Top)) and then Zone_Of_Block (X, Y) = Houses (H).Zone then
                  Write_Src (X, Y, Top, (Mat => Footpath, State => 0));
                  Cut_Plants (X, Y, Top);
               end if;
            end;
         end loop;
      end loop;
      Meet_Door (H, Beaten => True);         --  (and its steps made again to the path as it lies now)
      --  (and where the way has not columns enough for the path's height, the path's edge before
      --  it stepped as a path is where it meets trodden ground: never the square's own)
      if Meet_On and then Door_Meet_On and then not Is_Store (F) and then F.Door_Run > 0 then
         declare
            X0, Y0 : Integer := Integer'Last;
            X1, Y1 : Integer := Integer'First;
         begin
            for U in Way_Lo (F) .. Way_Hi (F) loop
               for T in Integer'Max (1, F.Door_Run - 1) .. Integer'Max (F.Door_Run, Front_Of (F, U)) + 1 loop
                  X0 := Integer'Min (X0, H_X (F, U, -T));
                  X1 := Integer'Max (X1, H_X (F, U, -T));
                  Y0 := Integer'Min (Y0, H_Y (F, U, -T));
                  Y1 := Integer'Max (Y1, H_Y (F, U, -T));
               end loop;
            end loop;
            Step_Seams (X0, Y0, X1, Y1, F.Pad - 1);
         end;
      end if;
   end Lay_Door_Path;

   --  Where a place is in a house's frame, in H_Point's units (block
   --  middles at whole numbers): its middle across the frame's U and V.
   function Frame_U (F : CB.House; P : Vec3) return Float is
     ((P.X * 4.0 - Float (F.Fx) - 0.5) * Float (F.Ux) + (P.Y * 4.0 - Float (F.Fy) - 0.5) * Float (F.Uy));
   function Frame_V (F : CB.House; P : Vec3) return Float is
     ((P.X * 4.0 - Float (F.Fx) - 0.5) * Float (F.Vx) + (P.Y * 4.0 - Float (F.Fy) - 0.5) * Float (F.Vy));
   --  (where a place is in a house's design: of a storehouse drawn turned, back through its turn)
   function Y_U (F : CB.House; P : Vec3) return Float is
      Qu, Qv : Float;
   begin
      CB.Back_Turn (F, Frame_U (F, P), Frame_V (F, P), Qu, Qv);
      return (if Yard_Turned (F) then Qu else Frame_U (F, P));
   end Y_U;
   function Y_V (F : CB.House; P : Vec3) return Float is
      Qu, Qv : Float;
   begin
      CB.Back_Turn (F, Frame_U (F, P), Frame_V (F, P), Qu, Qv);
      return (if Yard_Turned (F) then Qv else Frame_V (F, P));
   end Y_V;
   --  (the two ways of its design in the world: along its front, and from its front into it)
   function Y_Along (F : CB.House) return Vec3 is
      D : constant Vec3 := Y_Point (F, 1.0, 0.0) - Y_Point (F, 0.0, 0.0);
   begin
      return (D.X * 4.0, D.Y * 4.0, 0.0);
   end Y_Along;
   function Y_Inward (F : CB.House) return Vec3 is
      D : constant Vec3 := Y_Point (F, 0.0, 1.0) - Y_Point (F, 0.0, 0.0);
   begin
      return (D.X * 4.0, D.Y * 4.0, 0.0);
   end Y_Inward;

   function Stockyard_Walls return Yard_Walls is
      W : Yard_Walls;
   begin
      if Store_House not in 1 .. N_Houses then
         return W;
      end if;
      W.Stands := Houses (Store_House).Built;
      W.Rise := (if Houses (Store_House).F.Door_Run > 0
                 then Houses (Store_House).F.Pad - 1 - Houses (Store_House).F.Door_Row else 0);
      W.Way_End := Houses (Store_House).F.Way_End;
      W.Way_Deep := Houses (Store_House).F.Door_Run;
      W.Floor_Row := Houses (Store_House).F.Pad - 1;
      declare
         H : constant Positive := Store_House;
         F : CB.House renames Houses (H).F;
         procedure Count (K : Positive; P : Column_Plan; Lvl : Integer) is
            S : Wall_Side renames W.Side (K);
            N : constant Natural := Integer'Max (0, P.Top - P.Stone + 1);
         begin
            S.Rim := S.Rim + 1;
            if N > 0 then
               S.Stone := S.Stone + 1;
               S.Blocks := S.Blocks + N;
               S.Highest := Natural'Max (S.Highest, N);
               if P.Top > Lvl then
                  S.Back := S.Back + 1;
               else
                  S.Up := S.Up + 1;
               end if;
            end if;
         end Count;
      begin
         for U in Site_U_Lo (F) .. Site_U_Hi (F) loop
            for V in Site_V_Lo (F) .. Site_V_Hi (F) loop
               if In_Site (F, U, V) then
                  declare
                     P   : constant Column_Plan := Plan_Of (H, U, V);
                     Lvl : constant Integer := Level_Of (F, U, V);
                     On_Rim : Boolean := False;
                  begin
                     if Is_Stair (F, U, V) then
                        W.Stair := W.Stair + 1;
                     end if;
                     W.All_Blocks := W.All_Blocks + Integer'Max (0, P.Top - P.Stone + 1);
                     if not In_Site (F, U, V - 1) then
                        Count (1, P, Lvl); On_Rim := True;
                     end if;
                     if not In_Site (F, U, V + 1) then
                        Count (2, P, Lvl); On_Rim := True;
                     end if;
                     if not In_Site (F, U - 1, V) then
                        Count (3, P, Lvl); On_Rim := True;
                     end if;
                     if not In_Site (F, U + 1, V) then
                        Count (4, P, Lvl); On_Rim := True;
                     end if;
                     if not On_Rim and then P.Stone <= P.Top then
                        W.Inner := W.Inner + 1;
                     end if;
                     if On_Rim and then P.Stone <= P.Top then
                        declare
                           Du : constant Integer := (if Yard_Turned (F) then D_U (F, U, V) else U);
                           Dv : constant Integer := (if Yard_Turned (F) then D_V (F, U, V) else V);
                           X  : constant Integer := H_X (F, U, V);
                           Y  : constant Integer := H_Y (F, U, V);
                        begin
                           if Is_Stair (F, U, V) or else In_Door_Way (F, U, V) then
                              W.Way := W.Way + 1;
                              if Is_Stair (F, U, V) then
                                 W.Way_Stair := W.Way_Stair + 1;
                              end if;
                           elsif Dv < F.D - 1 then
                              W.Clear := W.Clear + 1;
                           elsif Du <= F.Yard_U0 + 1 or else Du >= F.Yard_U1 - 1 or else Dv >= F.Yard_V1 - 1 then
                              W.Fenced := W.Fenced + 1;        --  (within a block of the fence's line: a turned
                           else                                 --  yard's rim is stepped)
                              W.Goods := W.Goods + 1;
                           end if;
                           if Houses (H).Built and then not (Is_Stair (F, U, V) or else In_Door_Way (F, U, V)) then
                              declare
                                 Top  : constant Integer := Integer'Max (P.Top, Lvl);
                                 Wood : constant Boolean :=
                                   (for some Z in Top + 1 .. Top + CB.Gate_Post_H_B + 2 => Mat (X, Y, Z) in Log | Plank);
                                 Cx   : constant Float := (Float (X) + 0.5) * 0.25;
                                 Cy   : constant Float := (Float (Y) + 0.5) * 0.25;
                                 Best : Natural := 0;
                                 Bd   : Float := 0.75;
                              begin
                                 for C in 1 .. N_Cells loop
                                    if Cells (C).Zone = Houses (H).Zone
                                      and then Float'Max (abs (Cells (C).Centre.X - Cx), abs (Cells (C).Centre.Y - Cy)) < Bd
                                    then
                                       Bd := Float'Max (abs (Cells (C).Centre.X - Cx), abs (Cells (C).Centre.Y - Cy));
                                       Best := C;
                                    end if;
                                 end loop;
                                 if Wood then
                                    W.Seen_Fence := W.Seen_Fence + 1;
                                 elsif Best = 0 or else Cells (Best).Closed or else Cells (Best).Fit = Kept_Clear then
                                    W.Seen_Clear := W.Seen_Clear + 1;
                                 else
                                    W.Seen_Goods := W.Seen_Goods + 1;
                                 end if;
                              end;
                           end if;
                        end;
                     end if;
                  end;
               end if;
            end loop;
         end loop;
      end;
      return W;
   end Stockyard_Walls;

   function Stockyard_Front return Yard_Front is
      R : Yard_Front;
   begin
      if Store_House not in 1 .. N_Houses then
         return R;
      end if;
      declare
         F     : CB.House renames Houses (Store_House).F;
         Floor : constant Integer := F.Pad - 1;
         procedure Read (Spot : Front_Spot; U0 : Integer) is
            Bk  : Front_Bank renames R (Spot);
            Any : Boolean := False;
         begin
            Bk.Least := Integer'Last;
            Bk.Most := Integer'First;
            Bk.Rim_Least := Integer'Last;
            Bk.Rim_Most := Integer'First;
            Bk.Deep := Natural'Last;
            for U in U0 .. U0 + CB.Store_Door_W_B - 1 loop
               declare
                  N   : constant Natural := Front_Of (F, U);
                  Path : constant Integer := Top_By (Y_X (F, U, -(N + 1)), Y_Y (F, U, -(N + 1)), Floor);
                  Rim : constant Integer := Top_By (Y_X (F, U, -N), Y_Y (F, U, -N), Floor);
               begin
                  Bk.Deep := Natural'Min (Bk.Deep, N);
                  if Path >= 0 then
                     Bk.Read := True;
                     Bk.Least := Integer'Min (Bk.Least, Path - Floor);
                     Bk.Most := Integer'Max (Bk.Most, Path - Floor);
                     if U = U0 + CB.Store_Door_W_B / 2 then
                        Bk.Mid := Path - Floor;
                     end if;
                  end if;
                  if Rim >= 0 then
                     Any := True;
                     Bk.Rim_Least := Integer'Min (Bk.Rim_Least, Rim - Floor);
                     Bk.Rim_Most := Integer'Max (Bk.Rim_Most, Rim - Floor);
                  end if;
               end;
            end loop;
            if not Bk.Read then
               Bk.Least := 0;
               Bk.Most := 0;
            end if;
            if not Any then
               Bk.Rim_Least := 0;
               Bk.Rim_Most := 0;
            end if;
         end Read;
      begin
         Read (Low_End, End_Way_U (F, 1));
         Read (Front_Middle, Store_Way_U (F));
         Read (High_End, End_Way_U (F, 2));
      end;
      return R;
   end Stockyard_Front;

   procedure For_Yard_Plan
     (Visit : not null access procedure (Bx, By, Top, Stone, Floor : Integer; Way, Stair : Boolean)) is
   begin
      if Store_House not in 1 .. N_Houses then
         return;
      end if;
      declare
         H : constant Positive := Store_House;
         F : CB.House renames Houses (H).F;
      begin
         for U in Site_U_Lo (F) .. Site_U_Hi (F) loop
            for V in Site_V_Lo (F) .. Site_V_Hi (F) loop
               if In_Site (F, U, V) then
                  declare
                     P : constant Column_Plan := Plan_Of (H, U, V);
                  begin
                     Visit (H_X (F, U, V), H_Y (F, U, V), P.Top, P.Stone, F.Pad - 1, In_Door_Way (F, U, V), Is_Stair (F, U, V));
                  end;
               end if;
            end loop;
         end loop;
      end;
   end For_Yard_Plan;

   function Yard_Stair_Whole return Boolean is
   begin
      if Store_House not in 1 .. N_Houses then
         return True;
      end if;
      declare
         F : CB.House renames Houses (Store_House).F;
         Stepped : array (1 .. Max_Site_Patches) of Boolean := [others => False];
      begin
         for U in Site_U_Lo (F) .. Site_U_Hi (F) loop
            for V in Site_V_Lo (F) .. Site_V_Hi (F) loop
               if In_Site (F, U, V) and then Is_Stair (F, U, V) then
                  Stepped (Patch_Of (F, U, V)) := True;
               end if;
            end loop;
         end loop;
         for U in Site_U_Lo (F) .. Site_U_Hi (F) loop
            for V in Site_V_Lo (F) .. Site_V_Hi (F) loop
               if In_Site (F, U, V) and then Stepped (Patch_Of (F, U, V))
                 and then (if Yard_Turned (F) then D_U (F, U, V) else U) not in Way_Lo (F) .. Way_Hi (F)
               then
                  return False;
               end if;
            end loop;
         end loop;
         return True;
      end;
   end Yard_Stair_Whole;

   function Storehouse_Lie return Store_Lie is
      L : Store_Lie;
   begin
      if Store_House not in 1 .. N_Houses then
         return L;
      end if;
      declare
         F  : CB.House renames Houses (Store_House).F;
         Z  : constant Natural := Houses (Store_House).Zone;
         Nx, Ny : Float := 0.0;
      begin
         L.W := F.W;
         L.D := F.D;
         L.Front_Least := Natural'Last;
         for U in 0 .. F.W - 1 loop
            L.Front_Least := Natural'Min (L.Front_Least, F.Front (U));
            L.Front_Most := Natural'Max (L.Front_Most, F.Front (U));
         end loop;
         L.Behind := Integer'Max (0, F.Yard_V1 - (F.D - 1));
         L.Left := Integer'Max (0, -F.Yard_U0);
         L.Right := Integer'Max (0, F.Yard_U1 - (F.W - 1));
         if Z in 1 .. N_Zones then
            Front_Of_Zone (Z, Nx, Ny);
            L.Own_Front := (Nx /= 0.0 or else Ny /= 0.0)
              and then Y_Inward (F).X * Nx + Y_Inward (F).Y * Ny > 0.99;
            for U in 0 .. F.W - 1 loop
               for V in 0 .. F.D - 1 loop
                  declare
                     X : constant Integer := H_X (F, U, V);
                     Y : constant Integer := H_Y (F, U, V);
                  begin
                     if Zone_Of_Block (X, Y) /= Z then
                        L.Own_Out := L.Own_Out + 1;
                        if Near_Path ((Float (X) + 0.5) * 0.25, (Float (Y) + 0.5) * 0.25, 0.0) then
                           L.Own_On_Path := L.Own_On_Path + 1;
                        end if;
                     end if;
                  end;
               end loop;
            end loop;
         end if;
      end;
      return L;
   end Storehouse_Lie;

   --  The wall a shelf's place or a leaning ladder's is against: the point
   --  on its face nearest the place's middle, at the floor's height (a
   --  shelf: a long wall's inside, the front's or the back's; a ladder: the
   --  back wall's outside, in the yard).
   function Fit_Wall (K : Positive) return Vec3 is
   begin
      if Cells (K).Fit not in Shelf | Lean or else Store_House not in 1 .. N_Houses then
         return Cells (K).Centre;
      end if;
      declare
         F  : CB.House renames Houses (Store_House).F;
         Uc : constant Float := Y_U (F, Cells (K).Centre);
         Vc : constant Float := Y_V (F, Cells (K).Centre);
         Lo : constant Boolean := Vc < Float (F.D - 1) / 2.0;
      begin
         return Y_Point (F, Uc, (if Cells (K).Fit = Lean then Float (F.D) - 0.5
                                 elsif Lo then 0.5 else Float (F.D) - 1.5));
      end;
   end Fit_Wall;

   --  The storehouse H stands: its stockyard's places fitted out (the
   --  spec, Fitting).  A place's square, in the house's frame: whole
   --  blocks (a stockyard lies square to the grid, its places on whole
   --  metres, and the storehouse's left wall on the last block of one).
   --  Inside, the places make columns along its length and rows from its
   --  front wall to its back: by each end's door the two middle places are
   --  kept clear; a barrel in each corner and beside it along the front and
   --  the back wall (the two back corners' for water, the nearest the
   --  gateways); a shelf's three places in the middle of the front wall and
   --  of the back; the rest floor.  In the yard behind it: the places under
   --  a covering; a ladder's place each along the outside of its back wall;
   --  the rest ordinary places, open now.  Its staging, the ground beside its
   --  ends and the row its back wall and the gateways stand in are no places
   --  (Kept_Clear).
   procedure Fit_Storehouse (H : Positive) is
      F : CB.House renames Houses (H).F;
      Z : constant Natural := Houses (H).Zone;
      type Sq is record
         U0, U1, V0, V1 : Integer := 0;
      end record;
      function Square (C : Positive) return Sq is
         --  (its four blocks each way, from its middle to the nearest corner of blocks: the places of
         --  a zone put down whole are counted from its front's beginning less a centimetre, Box_Edge_M,
         --  and taken by the block their middle lies in, those of a box turned east or north were
         --  judged a block further back along its way: a column of them, or a row, was found under
         --  the storehouse's wall and kept clear, 14 places on its floor for 18)
         X0 : constant Integer := Integer (Float'Rounding (Cells (C).Centre.X * 4.0)) - 2;
         Y0 : constant Integer := Integer (Float'Rounding (Cells (C).Centre.Y * 4.0)) - 2;
         Ua : constant Integer := H_U (F, X0, Y0);
         Ub : constant Integer := H_U (F, X0 + 3, Y0 + 3);
         Va : constant Integer := H_V (F, X0, Y0);
         Vb : constant Integer := H_V (F, X0 + 3, Y0 + 3);
      begin
         if Yard_Turned (F) then
            --  (laid out along its path: the four blocks each way of its design the place's middle is
            --  the middle of)
            declare
               U0 : constant Integer := Integer (Float'Rounding (Y_U (F, Cells (C).Centre) - 1.5));
               V0 : constant Integer := Integer (Float'Rounding (Y_V (F, Cells (C).Centre) - 1.5));
            begin
               return (U0, U0 + 3, V0, V0 + 3);
            end;
         end if;
         return (Integer'Min (Ua, Ub), Integer'Max (Ua, Ub), Integer'Min (Va, Vb), Integer'Max (Va, Vb));
      end Square;
      function Inside (S : Sq) return Boolean is
        (S.U0 >= 1 and then S.U1 <= F.W - 2 and then S.V0 >= 1 and then S.V1 <= F.D - 2);
      Col_Lo, Row_Lo : Integer := Integer'Last;
      Col_Hi, Row_Hi : Integer := Integer'First;
   begin
      for C in 1 .. N_Cells loop
         if Cells (C).Zone = Z and then Inside (Square (C)) then
            Col_Lo := Integer'Min (Col_Lo, Square (C).U0);
            Col_Hi := Integer'Max (Col_Hi, Square (C).U0);
            Row_Lo := Integer'Min (Row_Lo, Square (C).V0);
            Row_Hi := Integer'Max (Row_Hi, Square (C).V0);
         end if;
      end loop;
      for C in 1 .. N_Cells loop
         if Cells (C).Zone = Z then
            declare
               S  : constant Sq := Square (C);
               Cl : Cell renames Cells (C);
            begin
               Cl.Made := True;
               Cl.Closed := False;
               if Inside (S) then
                  declare
                     Col  : constant Integer := (S.U0 - Col_Lo) / 4;          --  0 .. N_Col along its length
                     Row  : constant Integer := (S.V0 - Row_Lo) / 4;          --  0 .. N_Row from its front wall
                     N_Col : constant Integer := (Col_Hi - Col_Lo) / 4;
                     N_Row : constant Integer := (Row_Hi - Row_Lo) / 4;
                     By_Wall : constant Boolean := Row = 0 or else Row = N_Row;
                     At_End  : constant Boolean := Col = 0 or else Col = N_Col;
                     Mid     : constant Integer := N_Col / 2;
                  begin
                     Cl.Centre.Z := Pad_Z (F);
                     --  (by a door: the places its opening comes onto, one that it reaches half of too;
                     --  of a storehouse of 5 m, as it was, the two middle ones)
                     if At_End and then not By_Wall
                       and then (F.D <= CB.Store_D_B
                                 or else (S.V1 >= F.Openings (1).Offset
                                          and then S.V0 <= F.Openings (1).Offset + F.Openings (1).Width - 1))
                     then
                        Cl.Fit := Kept_Clear;                                  --  (by a door)
                     elsif At_End and then Row = N_Row then
                        Cl.Fit := Water_Barrel;
                     elsif By_Wall and then (At_End or else Col = 1 or else Col = N_Col - 1) then
                        Cl.Fit := Meat_Barrel;
                     elsif By_Wall and then Col in Mid - Shelf_Places / 2 .. Mid - Shelf_Places / 2 + Shelf_Places - 1 then
                        Cl.Fit := Shelf;
                     else
                        Cl.Fit := Floor;
                     end if;
                     Cl.Made := Cl.Fit not in Shelf | Meat_Barrel | Water_Barrel;
                  end;
               elsif S.V0 <= F.D + 1 then
                  Cl.Fit := Kept_Clear;       --  (the staging, beside its ends, under its walls, the gateways' row)
               else
                  declare
                     Under : Boolean := False;
                  begin
                     for K in 1 .. F.Covers loop
                        if S.U0 >= F.Cover_U (K) - 1 and then S.U1 <= F.Cover_U (K) + CB.Cover_W_B
                          and then S.V0 >= F.Yard_V1 - CB.Cover_D_B - 1 and then S.V1 <= F.Yard_V1
                        then
                           Under := True;
                        end if;
                     end loop;
                     if Under then
                        Cl.Fit := Cover;
                     elsif S.V0 in F.D + 2 .. F.D + 5 and then S.U0 >= 0 and then S.U1 <= F.W - 1 then
                        Cl.Fit := Lean;       --  (the row behind its back wall)
                     else
                        Cl.Fit := Ground;
                     end if;
                     if Yard_Level_On then
                        Cl.Centre.Z := Pad_Z (F);
                     end if;
                  end;
               end if;
               if Cl.Fit = Kept_Clear then
                  Cl.Closed := True;          --  (no place: nothing is ever put there)
               end if;
            end;
         end if;
      end loop;
      Zones_Ver := Zones_Ver + 1;
   end Fit_Storehouse;

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
            if Hs.F.Kind = CB.Storehouse then
               Store_Built_By := I;
            end if;
            Band (I).Site := 0;
            Band (I).Site_Patch := 0;
         end if;
      end loop;
      Read_Zone_Ground (Hs.Zone);
      Zones_Ver := Zones_Ver + 1;
      Draw_Owner (H);                       --  (it is somebody's from the moment it stands)
      if Hs.F.Kind = CB.Storehouse then
         Fit_Storehouse (H);
         --  the stores move into the stockyard: the stockpile takes nothing more (what lies in it is
         --  taken from first, and carried over by the stockman and by porters with nothing else to do)
         if Move_On then
            for C in 1 .. N_Cells loop
               if Cells (C).Zone in 1 .. N_Zones and then not Zones (Cells (C).Zone).Yard then
                  Cells (C).Closed := True;
               end if;
            end loop;
         end if;
      end if;
   end Finish_House;

   --  House H built on the spot, nothing taken from anywhere.
   --  Where a block of a storehouse's yard goes (its beaten ground, its
   --  fence, a covering): the yard is laid on the ground as it lies, its
   --  rows counted from the row over the ground's top (a covering's: the
   --  highest under it), and nothing is laid where something else stands.
   --  Z: the row it goes at; Top: the top of the ground there; Skip: it is
   --  not laid.  (The builder's, block by block, and the instant build's.)
   procedure Yard_Row (Hs : House_Rec; Bk : BP_Block; Z, Top : out Integer; Skip : out Boolean) is
      X    : constant Integer := Integer (Bk.X);
      Y    : constant Integer := Integer (Bk.Y);
      Near : constant Integer := Hs.F.Pad - 1;
      C    : constant Natural :=
        CB.Covering_At (Hs.F, D_U (Hs.F, H_U (Hs.F, X, Y), H_V (Hs.F, X, Y)),
                        D_V (Hs.F, H_U (Hs.F, X, Y), H_V (Hs.F, X, Y)));
   begin
      Skip := False;
      Z := Integer (Bk.Z);
      Top := Top_By (X, Y, Near);
      if Bk.S in CB.Cover | CB.Smooth and then C > 0 then
         declare
            F  : CB.House renames Hs.F;
            U0 : constant Integer := F.Cover_U (C);
            V0 : constant Integer := F.Yard_V1 - CB.Cover_D_B;
            Hi : Integer := -1;
         begin
            for U in U0 .. U0 + CB.Cover_W_B - 1 loop
               for V in V0 .. V0 + CB.Cover_D_B - 1 loop
                  Hi := Integer'Max (Hi, Top_By (Y_X (F, U, V), Y_Y (F, U, V), Near));
               end loop;
            end loop;
            Z := Hi + 1 + (Integer (Bk.Z) - Hs.F.Pad);
            Skip := Hi < 0;
         end;
      elsif Bk.S = CB.Beaten then
         --  (one drawn turned: under where its own blocks stand the ground is at its pad's
         --  level, whatever post stands on it)
         if Yard_Turned (Hs.F) and then H_U (Hs.F, X, Y) in -1 .. Hs.F.W and then H_V (Hs.F, X, Y) in -1 .. Hs.F.D then
            Top := Near;
         end if;
         Z := Top;
         Skip := Top < 0 or else Mat (X, Y, Top) not in Grass | Dirt;
      elsif Yard_Turned (Hs.F) and then H_U (Hs.F, X, Y) in -1 .. Hs.F.W and then H_V (Hs.F, X, Y) in -1 .. Hs.F.D then
         null;                                 --  (the plank's end under its eave, one of its own blocks: where it is drawn up)
      else
         Z := Top + 1 + (Integer (Bk.Z) - Hs.F.Pad);
         Skip := Top < 0;
      end if;
      if not Skip and then Bk.S = CB.Smooth then
         Skip := Mat (X, Y, Z) /= Bk.M;   --  (a covering's smoothing: its thatch again, where it was laid)
      elsif not Skip and then Bk.S /= CB.Beaten
        and then Mat (X, Y, Z) not in Air | Tall_Grass | Wild_Grain | Wild_Vegetables
      then
         Skip := True;                    --  (the cart, a tree, anything that stands there)
      end if;
   end Yard_Row;

   procedure Raise_Now (H : Positive; As_Laid : Boolean := False) is
      Hs : House_Rec renames Houses (H);
   begin
      if not Hs.Pad_Done then
         declare
            Dig, Wall : Site_Flags;
            Sum  : Site_Sums;
            Wanted, Laid : Natural;
         begin
            Level_Patch (H, 0);
            Site_Patches (H, Dig, Wall, Sum, Wanted);
            Wall_Patch (H, 0, Natural'Last, Laid);
            Hs.Got (Stone) := Hs.Got (Stone) + (Laid + Wall_Per_Stone - 1) / Wall_Per_Stone;
            Note_Stone (H, 0);
         end;
         Read_Zone_Ground (Hs.Zone);          --  (its ground as it is made ready, before anything stands on it)
         Hs.Pad_Done := True;
      end if;
      Blueprint_Of (H);
      for K in Hs.Placed + 1 .. BP_N loop
         --  (one drawn turned: its yard laid as its builder lays it, on the ground as it lies.  A
         --  square one's is written as drawn up, as it was before 2026-11-20: the checks' and the
         --  scripted starts' worlds are as they were.  As drawn up, its ground is beaten at the
         --  floor's row over every column, a stair's steps that lie under the floor among them, and
         --  its fence stands at the floor's row along a rim that is a wall over it: with As_Laid a
         --  square one's is laid as its builder lays it too, for whatever looks at its ground.)
         if BP (K).S in CB.Beaten | CB.Fence | CB.Cover | CB.Smooth and then (Yard_Turned (Hs.F) or else As_Laid) then
            declare
               Z, Top : Integer;
               Skip   : Boolean;
            begin
               Yard_Row (Hs, BP (K), Z, Top, Skip);
               if not Skip then
                  Write_Src (Integer (BP (K).X), Integer (BP (K).Y), Z, (Mat => BP (K).M, State => BP (K).St));
                  if BP (K).S = CB.Cover and then BP (K).M = Log and then Integer (BP (K).Z) = Hs.F.Pad then
                     for Zf in Top + 1 .. Z - 1 loop
                        if Mat (Integer (BP (K).X), Integer (BP (K).Y), Zf) in Air | Tall_Grass | Wild_Grain | Wild_Vegetables then
                           Write_Src (Integer (BP (K).X), Integer (BP (K).Y), Zf, (Mat => Log, State => 0));
                        end if;
                     end loop;
                  end if;
               end if;
            end;
         else
            Write_Src (Integer (BP (K).X), Integer (BP (K).Y), Integer (BP (K).Z), (Mat => BP (K).M, State => BP (K).St));
         end if;
      end loop;
      Hs.Placed := BP_N;
      Hs.Got := Hs.Takes;
      Finish_House (H);
   end Raise_Now;

   procedure Build_Homes_Now (Last_First : Boolean := False; As_Laid : Boolean := False) is
      Ok : Boolean;
      Begun : constant Natural := N_Houses;
   begin
      for H in 1 .. N_Houses loop
         Draw_Owner (H);                   --  (houses nobody's now to those without)
      end loop;
      for K in 1 .. Begun loop
         declare
            H : constant Positive := (if Last_First then Begun + 1 - K else K);
         begin
            if not Houses (H).Built then
               Raise_Now (H, As_Laid);
            end if;
         end;
      end loop;
      while Without_A_House > 0 loop
         Begin_Lot (Ok);
         exit when not Ok;
         Raise_Now (N_Houses, As_Laid);
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
      + Hearth_Short (K) + (if N_Houses > 0 then Houses_Short (K) else 0)
      + (if K = Wood then Fittings_Left else 0));
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
               when Salt | Ladder => False,        --  (nobody of the band brings either in: never asked for)
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
            if Zones (Z).Kind = Habitation_Zone or else (Store_House > 0 and then Houses (Store_House).Zone = Z) then
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

   --  One with nothing to do for want of room moves what lies in the
   --  overflow into the stockpile, once an ordinary place has room for it
   --  (John, 2026-11-17: "When space opens up in the stockpile someone can
   --  move it from the overflow to the stockpile"): a load at a time, from
   --  the overflow place nearest it whose kind the ordinary places take more
   --  loads of than are already on their way.
   function Go_Clear_Overflow (I : Positive) return Boolean is
      M : Member renames Band (I);
   begin
      if not Overflow_On or else M.Carried > 0 then
         return False;
      end if;
      for Attempt in 1 .. 3 loop
         declare
            Best   : Natural := 0;
            Best_D : Float := Float'Last;
         begin
            for C in 1 .. N_Cells loop
               if Cells (C).Overflow and then Cells (C).Count > Cells (C).Outgoing
                 and then Carry_Limit (Cells (C).Kind) > 0 and then not Failed (M, Cell_Base + C)
                 and then Flat_Dist (M.Pos, Cells (C).Centre) < Best_D
                 and then Ordinary_Loads (Cells (C).Kind) > Loads_Out (Cells (C).Kind)
               then
                  Best := C;
                  Best_D := Flat_Dist (M.Pos, Cells (C).Centre);
               end if;
            end loop;
            if Best = 0 then
               return False;
            end if;
            if Route_To (M, Cells (Best).Centre, 0.6) then
               Release (M, I);
               M.Cell := Best;
               M.Due := Natural'Min (Carry_Limit (Cells (Best).Kind), Cells (Best).Count - Cells (Best).Outgoing);
               Cells (Best).Outgoing := Cells (Best).Outgoing + M.Due;
               M.Use_For := For_Store;
               M.State := To_Take;
               Store_Now.Overflow_Moves := Store_Now.Overflow_Moves + 1;   --  (a measure)
               return True;
            end if;
            Remember_Failure (M, Cell_Base + Best);
         end;
      end loop;
      return False;
   end Go_Clear_Overflow;

   --  A storehouse's builder takes away what lies on the places closed for
   --  it, a load at a time to a place that has room, before its ground is
   --  made ready (True: on its way to one; Left: something lies there).
   function Go_Clear_Closed (I : Positive; Z : Positive; Left : out Boolean) return Boolean is
      M : Member renames Band (I);
   begin
      Left := False;
      for C in 1 .. N_Cells loop
         if Cells (C).Zone = Z and then Cells (C).Closed and then (Cells (C).Count > 0 or else Cells (C).Incoming > 0) then
            Left := True;
         end if;
      end loop;
      if not Left or else M.Carried > 0 then
         return False;
      end if;
      for Attempt in 1 .. 3 loop
         declare
            Best   : Natural := 0;
            Best_D : Float := Float'Last;
         begin
            for C in 1 .. N_Cells loop
               if Cells (C).Zone = Z and then Cells (C).Closed and then Cells (C).Count > Cells (C).Outgoing
                 and then Carry_Limit (Cells (C).Kind) > 0 and then not Failed (M, Cell_Base + C)
                 and then Flat_Dist (M.Pos, Cells (C).Centre) < Best_D
                 and then Ordinary_Loads (Cells (C).Kind) > Loads_Out (Cells (C).Kind)
               then
                  Best := C;
                  Best_D := Flat_Dist (M.Pos, Cells (C).Centre);
               end if;
            end loop;
            if Best = 0 then
               return False;
            end if;
            if Route_To (M, Cells (Best).Centre, 0.6) then
               Release (M, I);
               M.Cell := Best;
               M.Due := Natural'Min (Carry_Limit (Cells (Best).Kind), Cells (Best).Count - Cells (Best).Outgoing);
               Cells (Best).Outgoing := Cells (Best).Outgoing + M.Due;
               M.Use_For := For_Store;
               M.State := To_Take;
               return True;
            end if;
            Remember_Failure (M, Cell_Base + Best);
         end;
      end loop;
      return False;
   end Go_Clear_Closed;

   --  One that has nothing to do for want of room: the overflow moved in if
   --  there is room for it, else its leisure at the campfire (John, the same
   --  day: "they can go spend their leisure time at the campfire if they
   --  aren't doing anything else"): about the camp, as at rest.
   procedure Wait_For_Room (I : Positive) is
   begin
      if not Go_Clear_Overflow (I) then
         Rest (I);
      end if;
   end Wait_For_Room;

   --  The stores moved into the stockyard (John, 2026-11-17: "When stockyard
   --  is built, change all deliveries and pickups to the stokyard from the
   --  stockpile"): a load out of a stockpile's places, closed when the
   --  storehouse stood, for a place of the stockyard (the stockman's, before
   --  it sorts; a porter's, with nothing else to fetch).
   function Go_Move_In (I : Positive) return Boolean is
      Left : Boolean;
   begin
      for Z in 1 .. N_Zones loop
         if Zones (Z).Kind = Stockpile_Zone and then not Zones (Z).Yard and then (Stores_Moved or else Zones (Z).Leaving)
           and then Go_Clear_Closed (I, Z, Left)
         then
            return True;
         end if;
      end loop;
      return False;
   end Go_Move_In;

   ------------------------------------------------------------------ the stockman

   --  Once a colony second: a stockman made when the storehouse stands, and
   --  another when it has died or is a porter no more (the spec).
   procedure Choose_Keeper is
   begin
      if not Keep_On or else Store_House not in 1 .. N_Houses or else not Houses (Store_House).Built then
         return;
      end if;
      if Keeper_N in 1 .. N_Members and then not Band (Keeper_N).Is_Dead and then Band (Keeper_N).Job = Porter then
         return;
      end if;
      Keeper_N := 0;
      for I in 1 .. N_Members loop
         if not Band (I).Is_Dead and then Band (I).Job = Porter
           and then (Keeper_N = 0 or else Band (I).Skill (Portering) > Band (Keeper_N).Skill (Portering))
         then
            Keeper_N := I;
         end if;
      end loop;
   end Choose_Keeper;

   --  How many more of each kind the places fitted out for it hold.
   function Fitted_Rooms return Per_Kind is
      R : Per_Kind := [others => 0];
   begin
      for C in 1 .. N_Cells loop
         declare
            Cl : Cell renames Cells (C);
         begin
            if Cl.Fit /= Ground and then Cl.Made and then not Cl.Closed then
               for K in Item_Kind loop
                  if For_Fit (Cl.Fit, K) and then Keeps (C, K, 0) then
                     R (K) := R (K) + Integer'Max (0, Place_Limit (C, K) - (if Cl.Kind = K then Cl.Count + Cl.Incoming else 0));
                  end if;
               end loop;
            end if;
         end;
      end loop;
      return R;
   end Fitted_Rooms;

   --  The stockman sorts: from the yard's place nearest it holding what a
   --  place fitted out has room for, a load of it (no more than that room);
   --  and what lies in a place fitted out for something else (it lay there
   --  before the place was fitted out) to where it belongs, or the yard.
   function Go_Sort (I : Positive) return Boolean is
      M    : Member renames Band (I);
      Room : constant Per_Kind := Fitted_Rooms;
      function Misplaced (C : Positive) return Boolean is
        (Cells (C).Fit /= Ground and then not For_Fit (Cells (C).Fit, Cells (C).Kind));
      function Load_Of (C : Positive) return Natural is
        (Natural'Min (Natural'Min (Carry_Limit (Cells (C).Kind),
                                   (if Misplaced (C) and then Room (Cells (C).Kind) = 0 then Natural'Last
                                    else Room (Cells (C).Kind))),
                      Cells (C).Count - Cells (C).Outgoing));
   begin
      for Attempt in 1 .. 3 loop
         declare
            Best   : Natural := 0;
            Best_D : Float := Float'Last;
         begin
            for C in 1 .. N_Cells loop
               declare
                  Cl : Cell renames Cells (C);
               begin
                  if not Cl.Closed and then Cl.Count > Cl.Outgoing and then Carry_Limit (Cl.Kind) > 0
                    and then ((Cl.Fit = Ground and then Room (Cl.Kind) > 0)
                              or else (Misplaced (C)
                                       and then (Room (Cl.Kind) > 0
                                                 or else Ordinary_Loads (Cl.Kind) > Loads_Out (Cl.Kind))))
                    and then not Failed (M, Cell_Base + C)
                    and then Flat_Dist (M.Pos, Cl.Centre) < Best_D
                  then
                     Best := C;
                     Best_D := Flat_Dist (M.Pos, Cl.Centre);
                  end if;
               end;
            end loop;
            if Best = 0 then
               return False;
            end if;
            if Route_To (M, Cells (Best).Centre, 0.6) then
               Release (M, I);
               M.Cell := Best;
               M.Due := Load_Of (Best);
               Cells (Best).Outgoing := Cells (Best).Outgoing + M.Due;
               M.Use_For := For_Store;
               M.State := To_Take;
               return True;
            end if;
            Remember_Failure (M, Cell_Base + Best);
         end;
      end loop;
      return False;
   end Go_Sort;

   ------------------------------------------------------------------ the carpenter

   function Free_For_Building (K : Item_Kind) return Natural;      --  (with the builder, below)

   --  Once a colony second: a carpenter made when the storehouse stands
   --  (its builder first, else the free forester with the most building),
   --  and another when it has died or is a forester no more.
   procedure Choose_Carpenter is
   begin
      if not Carp_On or else Store_House not in 1 .. N_Houses or else not Houses (Store_House).Built then
         return;
      end if;
      if Carp_N in 1 .. N_Members and then not Band (Carp_N).Is_Dead and then Band (Carp_N).Job = Forester then
         --  (one named by hand before the storehouse stood, that took a house to build meanwhile:
         --  a carpenter builds none, so its house wants another builder, as when a builder is given
         --  another job.  One chosen by skill has no house: this is never come to for it.)
         if Band (Carp_N).Site /= 0 then
            declare
               M : Member renames Band (Carp_N);
            begin
               M.Build_First := False;
               M.Site := 0;
               M.Site_Patch := 0;
               if M.State not in To_Eat | Eating | To_Bed | Sleeping | To_Seat then
                  Release (M, Carp_N);
                  if M.State /= To_Store and then M.State /= Storing then
                     M.State := Idle;
                     M.Wait := 0.0;
                     M.Route.N := 0;
                  end if;
               end if;
            end;
         end if;
         return;
      end if;
      --  by skill, like the others (John, 2026-11-19: "Carpenter comes by skill like the others"): the
      --  forester with no house to build that is best at carpentry (until then it was whoever had
      --  raised the storehouse)
      Carp_N := 0;
      Store_Built_By := 0;
      for I in 1 .. N_Members loop
         if not Band (I).Is_Dead and then Band (I).Job = Forester and then Band (I).Site = 0
           and then (Carp_N = 0 or else Band (I).Skill (Carpentry) > Band (Carp_N).Skill (Carpentry))
         then
            Carp_N := I;
         end if;
      end loop;
   end Choose_Carpenter;

   --  The next shelf or barrel to make: the shelves first, then each place's first barrel, then a
   --  second barrel on one that is full.
   function Next_Fitting return Natural is
   begin
      for Pass in 1 .. 2 loop
         for C in 1 .. N_Cells loop
            if not Cells (C).Made and then not Cells (C).Closed
              and then (if Pass = 1 then Cells (C).Fit = Shelf else Cells (C).Fit in Meat_Barrel | Water_Barrel)
            then
               return C;
            end if;
         end loop;
      end loop;
      for C in 1 .. N_Cells loop
         if Wants_Second (C) then
            return C;
         end if;
      end loop;
      return 0;
   end Next_Fitting;

   --  The carpenter: a log from the stores to the next shelf or barrel,
   --  and made there.  False: nothing to make, or nothing to make it of.
   function Think_Carpenter (I : Positive) return Boolean is
      M : Member renames Band (I);
      C : constant Natural := Next_Fitting;
   begin
      if C = 0 then
         if M.Use_For = For_Fitting then
            M.Use_For := For_Store;           --  (a log taken for one, and all are made: stored)
         end if;
         return False;
      end if;
      if M.Carried > 0 then
         if M.Carry = Wood and then M.Use_For = For_Fitting then
            if not Failed (M, Cell_Base + C) and then Route_To (M, Cells (C).Centre, 0.6) then
               M.Cell := C;
               M.State := To_Fitting;
               return True;
            end if;
            Remember_Failure (M, Cell_Base + C);
            M.Use_For := For_Store;
         end if;
         return False;
      end if;
      if Free_For_Building (Wood) = 0 then
         M.Why := No_Timber;
         return False;
      end if;
      return Go_Take (I, Wood, 1, For_Fitting);
   end Think_Carpenter;

   procedure Step_Fitting (I : Positive) is
      M  : Member renames Band (I);
      Ok : Boolean;
   begin
      case M.State is
         when To_Fitting =>
            Keep_Route_Good (M, Ok);
            --  (made meanwhile, and no second barrel wanted there: nothing to go for)
            if not Ok or else M.Cell not in 1 .. N_Cells
              or else (Cells (M.Cell).Made and then not Wants_Second (M.Cell))
            then
               if not Ok and then M.Cell in 1 .. N_Cells then
                  Remember_Failure (M, Cell_Base + M.Cell);
               end if;
               M.Cell := 0;
               M.State := Idle;
               M.Wait := 1.0;
            elsif Walk_On (M, 0.6) then
               M.State := Fitting_Out;
               M.Work := 0.0;
               M.Spot := Cells (M.Cell).Centre + (0.0, 0.0, 0.5);
            end if;
         when Fitting_Out =>
            M.Work := M.Work + Tick_S * Work_Rate (M, Joinery);
            if M.Cell not in 1 .. N_Cells then
               M.State := Idle;
            elsif M.Work >= (if Cells (M.Cell).Fit = Shelf then Shelf_S else Barrel_S) then
               if Cells (M.Cell).Made then
                  Cells (M.Cell).Second := Cells (M.Cell).Fit in Meat_Barrel | Water_Barrel;   --  (on the first)
               else
                  Cells (M.Cell).Made := True;
               end if;
               M.Carried := M.Carried - Natural'Min (1, M.Carried);
               if M.Carried = 0 then
                  M.Carry := Nothing;
                  M.Use_For := For_Store;
               end if;
               M.Cell := 0;
               M.State := Idle;
               M.Wait := 0.5;
               Zones_Ver := Zones_Ver + 1;
            end if;
         when others =>
            null;
      end case;
   end Step_Fitting;

   --  Where the lord's cart stands at the storehouse's front: in its
   --  staging, beside the way to its door, its shafts toward the path.
   function Cart_Front (P : out Vec3; Turn : out Float) return Boolean;
   function Cart_At_Front return Boolean;
   function Go_Tow_Front (I : Positive) return Boolean;
   function Go_Unload (I : Positive) return Boolean;

   --  The stockman, with its hands empty: the overflow, the cart, its salt,
   --  then sorting (the spec).  False: nothing of it to do now.
   function Think_Keeper (I : Positive) return Boolean is
     (Band (I).Carried = 0
      and then ((Overflow_Busy and then Go_Clear_Overflow (I))
                or else Go_Tow_Front (I)
                or else Go_Unload (I)
                or else Go_Move_In (I)
                or else Go_Sort (I)));

   ------------------------------------------------------------------ housing: the builder

   --  What building may take of K from the stores: all that is free, but
   --  never the logs the camp's fire burns in a day, nor those its seats
   --  and its hearth still want.
   function Free_For_Building (K : Item_Kind) return Natural is
      Free : constant Natural := Free_Stock (K);
      Keep : constant Natural :=
        (if K = Wood and then Camp_Set
         then Fire_Day_Logs + (if Seats_Laid < Seat_Logs then Seat_Logs - Seats_Laid else 0) + Hearth_Short (Wood)
         elsif K = Stone and then Camp_Set then Hearth_Short (Stone)       --  (the hearth's stones first)
         else 0);
   begin
      return (if Free > Keep then Free - Keep else 0);
   end Free_For_Building;

   --  What house H next has to have carried to it (its timber is all laid
   --  before anything of straw: colony_check holds every blueprint to it).
   --  (a storehouse's yard after its roof: wood for its fence and its
   --  coverings' posts, then straw for their roofs)
   function Next_Kind (H : Positive) return Item_Kind is
     (if Houses (H).Placed < Houses (H).Wood_N then Wood
      elsif Houses (H).Placed < Houses (H).Dress_N then Straw
      elsif Houses (H).Placed < Houses (H).Yard_Wood_N then Wood
      else Straw);

   --  The feet go by a storehouse as it is drawn (the spec, Set_Yard_Turn):
   --  one drawn turned, from when its walls and roof are up.
   function Walked_Drawn (K : Positive) return Boolean is
     ((Yard_Turned (Houses (K).F) or else (Houses (K).F.Walk and then Houses (K).F.Turn /= 0))
      and then Houses (K).Pad_Done and then Houses (K).Dress_N > 0
      and then Houses (K).Placed >= Houses (K).Dress_N);

   function House_At (K : Positive) return House_View is
      Hs   : House_Rec renames Houses (K);
      F    : CB.House renames Hs.F;
      Bd   : constant Natural := Builder_Of (K);
      Next : constant Item_Kind := (if Hs.Built then Wood else Next_Kind (K));
      Bringing : constant Boolean :=
        Bd > 0 and then Band (Bd).Use_For = For_House and then Band (Bd).State in To_Take | Taking | To_Site | Idle;
   begin
      return
        (Kind => F.Kind, Zone => Hs.Zone, Owner => Hs.Owner, Builder => Bd,
         Phase => (if Hs.Built then Standing elsif not Hs.Pad_Done then Ground
                   elsif Hs.Placed < Hs.Floor_N then Flooring elsif Hs.Placed < Hs.Frame_N then Framing
                   elsif Hs.Placed < Hs.Walls_N then Walling elsif Hs.Placed < Hs.Roof_N then Roofing
                   elsif Hs.Placed < Hs.Dress_N then Trimming
                   else Yard),
         Blocks => Hs.Total, Placed => Hs.Placed, Takes => Hs.Takes, Got => Hs.Got,
         Waits => (if Hs.Built then Not_Waiting
                   elsif Bd = 0 then For_A_Builder
                   elsif Failed (Band (Bd), Site_Fail + K) then For_A_Way
                   elsif Hs.Raze then Not_Waiting               --  (coming down: it wants nothing brought)
                   elsif not Hs.Pad_Done
                   then (if Band (Bd).Why = No_Stone and then Hs.Lying (Stone) = 0 and then not Bringing
                           and then Free_For_Building (Stone) = 0
                         then For_Stone else Not_Waiting)
                   elsif Hs.Pad_Done and then Hs.Placed >= Hs.Floor_N and then Hs.Lying (Next) = 0 and then not Bringing
                     and then Free_For_Building (Next) = 0
                   then (if Next = Straw then For_Straw else For_Wood)
                   else Not_Waiting),
         Corner => [H_Point (F, -0.5, -0.5), H_Point (F, Float (F.W) - 0.5, -0.5),
                    H_Point (F, Float (F.W) - 0.5, Float (F.D) - 0.5), H_Point (F, -0.5, Float (F.D) - 0.5)],
         Door => Y_Point (F, Float (Mid_Lo (F) + Mid_Hi (F)) / 2.0, -2.5),
         Way => F.Door_Run, Rise => (if F.Door_Run > 0 then F.Pad - 1 - F.Door_Row else 0),
         Bed => Bed_Place (K),
         Top_Z => Float (F.Pad + F.Wall_H + (if F.Ridge_Along_U then (F.D + 1) / 2 else (F.W + 1) / 2)) * 0.25,
         Has_Bed => Hs.Bed, Reach_L => F.Reach_L, Reach_R => F.Reach_R, Marked => Hs.Raze,
         Turn => Float (F.Turn) * Ada.Numerics.Pi / 4.0, Turn_Ground => F.Turn_Ground,
         Drawn => [Drawn_Point (F, -0.5, -0.5), Drawn_Point (F, Float (F.W) - 0.5, -0.5),
                   Drawn_Point (F, Float (F.W) - 0.5, Float (F.D) - 0.5), Drawn_Point (F, -0.5, Float (F.D) - 0.5)],
         Drawn_Door => Drawn_Point (F, Float (Mid_Lo (F) + Mid_Hi (F)) / 2.0, -2.5),
         Pivot => H_Point (F, CB.Pivot_U (F), CB.Pivot_V (F)),
         Walk => F.Walk or else Yard_Turned (F),
         Yard_Turned => Yard_Turned (F),
         Walked_Drawn => Walked_Drawn (K),
         People_Turned => F.Turn /= 0
           and then (if Yard_Turned (F) then Hs.Placed >= Hs.Floor_N and then Hs.Placed < Hs.Dress_N
                     else not Walked_Drawn (K)));
   end House_At;

   function House_Drawn_On (K : Positive; X, Y : Float; Margin : Float := 0.0) return Boolean is
      F : CB.House renames Houses (K).F;
      P : constant Vec3 := (X, Y, 0.0);
   begin
      return Under_Drawn (F, Frame_U (F, P), Frame_V (F, P), Margin * 4.0);
   end House_Drawn_On;

   --  The walking map told what ground is kept off (the spec, Set_Keep_Off):
   --  each hovel that stands with its ground made where it is drawn, as it is
   --  drawn, less its walls' own place and the way out from its door.
   procedure Keep_Off_Turned is
      Key  : Integer := (if Keep_Off_On then 1 else 0);
      List : Castle.Nav.Kept_List (1 .. Castle.Nav.Max_Kept);
      N    : Natural := 0;
      --  (not one that is walked where it is drawn: its walls as drawn are walls already)
      function Kept (H : Positive) return Boolean is
        (Keep_Off_On and then Houses (H).Built and then not Houses (H).Raze and then Houses (H).F.Turn_Ground
         and then Houses (H).F.Turn /= 0 and then not Houses (H).F.Walk);
      function Box_Of (A, B : Vec3) return Castle.Nav.Kept_Box is
        ((X0 => Float'Min (A.X, B.X), Y0 => Float'Min (A.Y, B.Y), X1 => Float'Max (A.X, B.X), Y1 => Float'Max (A.Y, B.Y)));
   begin
      for H in 1 .. N_Houses loop
         if Kept (H) then
            Key := (Key * 31 + H * 7 + Houses (H).F.Fx * 3 + Houses (H).F.Fy) mod 1_000_003;
         end if;
      end loop;
      if Key = Kept_Key then
         return;
      end if;
      Kept_Key := Key;
      for H in 1 .. N_Houses loop
         if Kept (H) and then N < List'Last then
            declare
               F : CB.House renames Houses (H).F;
               function Drawn (U, V : Float) return Vec3 is
                  Au, Av : Float;
               begin
                  CB.Fore_Turn (F, U, V, Au, Av);
                  return H_Point (F, Au, Av);
               end Drawn;
               Out_Most : constant Float :=
                 Float (Integer'Max (F.Door_Run, Integer'Max (Front_Of (F, Way_Lo (F)), Front_Of (F, Way_Hi (F)))));
            begin
               N := N + 1;
               List (N) :=
                 (Corner => [Drawn (-0.5, -0.5), Drawn (Float (F.W) - 0.5, -0.5),
                             Drawn (Float (F.W) - 0.5, Float (F.D) - 0.5), Drawn (-0.5, Float (F.D) - 0.5)],
                  But_A  => Box_Of (H_Point (F, -0.5, -0.5), H_Point (F, Float (F.W) - 0.5, Float (F.D) - 0.5)),
                  But_B  => Box_Of (H_Point (F, Float (Way_Lo (F)) - 1.5, -Out_Most - 1.5),
                                    H_Point (F, Float (Way_Hi (F)) + 1.5, 0.5)));
            end;
         end if;
      end loop;
      Castle.Nav.Set_Kept (List (1 .. N));
   end Keep_Off_Turned;

   --  The walking map told which buildings are walked where they are drawn
   --  (Castle.Nav.Set_Drawn): each storehouse drawn turned whose walls and
   --  roof are up.  Its walls as drawn, a piece each, its doorways left out.
   --  When the list changes every way being walked is looked over again (a
   --  way laid before may go where a wall is now).
   Drawn_Key : Integer := -1;
   --  (the walking map's list holds every house there can be: none is ever left off it)
   Drawn_Room : constant Positive := Castle.Nav.Max_Drawn - Max_Houses + 1 with Unreferenced;
   procedure Walk_Drawn is
      Key  : Integer := 0;
      List : Castle.Nav.Drawn_List (1 .. Castle.Nav.Max_Drawn);
      N    : Natural := 0;
   begin
      for H in 1 .. N_Houses loop
         if Walked_Drawn (H) then
            Key := (Key * 31 + H * 7 + Houses (H).F.Fx * 3 + Houses (H).F.Fy + 977) mod 1_000_003;
         end if;
      end loop;
      if Key = Drawn_Key then
         return;
      end if;
      for H in 1 .. N_Houses loop
         if Walked_Drawn (H) and then N < List'Last then
            declare
               F : CB.House renames Houses (H).F;
               D : Castle.Nav.Drawn_House;
               --  (a place of it where it is drawn)
               function Y_Or_Drawn (U, V : Float) return Vec3 is (Drawn_Point (F, U, V));
               procedure Piece (U0, U1, V0, V1 : Float) is
               begin
                  if D.Walls < D.Wall'Last and then U1 > U0 and then V1 > V0 then
                     D.Walls := D.Walls + 1;
                     D.Wall (D.Walls) :=
                       [Y_Or_Drawn (U0, V0), Y_Or_Drawn (U1, V0), Y_Or_Drawn (U1, V1), Y_Or_Drawn (U0, V1)];
                  end if;
               end Piece;
               --  a wall from end to end, less the doorways in it (at most one is looked for), as thick as
               --  it is drawn, a block
               procedure Wall (Side : CB.Wall_Side) is
                  Long : constant Float := (case Side is when CB.Front | CB.Back => Float (F.W), when others => Float (F.D));
                  Lo   : Float := Long;             --  the doorway's two ends along the wall (none: past its end)
                  Hi   : Float := Long;
                  procedure Stretch (A0, A1 : Float) is
                  begin
                     case Side is
                        when CB.Front => Piece (A0, A1, -0.5, 0.5);
                        when CB.Back  => Piece (A0, A1, Float (F.D) - 1.5, Float (F.D) - 0.5);
                        when CB.Left  => Piece (-0.5, 0.5, A0, A1);
                        when CB.Right => Piece (Float (F.W) - 1.5, Float (F.W) - 0.5, A0, A1);
                     end case;
                  end Stretch;
               begin
                  for O in 1 .. F.Open_N loop
                     if CB."=" (F.Openings (O).Side, Side) and then F.Openings (O).Bottom = 0 then
                        Lo := Float (F.Openings (O).Offset) - 0.5;
                        Hi := Float (F.Openings (O).Offset + F.Openings (O).Width) - 0.5;
                     end if;
                  end loop;
                  Stretch (-0.5, Float'Min (Lo, Long - 0.5));
                  Stretch (Hi, Long - 0.5);
               end Wall;
               A : constant Vec3 := H_Point (F, -1.5, -1.5);
               C : constant Vec3 := H_Point (F, Float (F.W) + 0.5, Float (F.D) + 0.5);
            begin
               D.Box := (X0 => Float'Min (A.X, C.X), Y0 => Float'Min (A.Y, C.Y),
                         X1 => Float'Max (A.X, C.X), Y1 => Float'Max (A.Y, C.Y));
               D.Z := F.Pad;
               Wall (CB.Front);
               Wall (CB.Back);
               Wall (CB.Left);
               Wall (CB.Right);
               if not Is_Store (F) then
                  --  (a hovel: its walls as drawn slow, they do not shut (Castle.Nav.Wall_Pace);
                  --  where its blocks stand is turf, walked as turf; and its doorway, a metre wide, has
                  --  its cells held open: all of it but half a block at each jamb, from a metre out to
                  --  0.6 m in)
                  D.Slow := True;
                  D.Speed := 1.0;
                  D.Whole := True;
                  for O in 1 .. F.Open_N loop
                     if F.Openings (O).Bottom = 0 and then D.Doors < D.Door'Last then
                        declare
                           Op : CB.Opening renames F.Openings (O);
                           A0 : constant Float := Float (Op.Offset) - 0.5 + 0.5;
                           A1 : constant Float := Float (Op.Offset + Op.Width) - 0.5 - 0.5;
                           --  (Across: blocks from the wall's middle line, outward)
                           function Q (A, Across : Float) return Vec3 is
                             (case Op.Side is
                                 when CB.Front => Y_Or_Drawn (A, -Across),
                                 when CB.Back  => Y_Or_Drawn (A, Float (F.D - 1) + Across),
                                 when CB.Left  => Y_Or_Drawn (-Across, A),
                                 when CB.Right => Y_Or_Drawn (Float (F.W - 1) + Across, A));
                           Out_D : constant Float := 4.0;
                           In_D  : constant Float := -2.5;
                        begin
                           D.Doors := D.Doors + 1;
                           D.Door (D.Doors) := [Q (A0, In_D), Q (A1, In_D), Q (A1, Out_D), Q (A0, Out_D)];
                        end;
                     end if;
                  end loop;
               end if;
               N := N + 1;
               List (N) := D;
            end;
         end if;
      end loop;
      Castle.Nav.Set_Drawn (List (1 .. N));
      if Drawn_Key /= -1 then
         --  (as a load leaves every way: the ground it was planned on not known, so that the next
         --  look goes over it step by step and plans again only where it can no longer be walked.
         --  So a run saved in the very tick its walls and roof were finished, and loaded, goes on
         --  as the run that was not: a load tells the map before anybody steps, and does this too.)
         for I in 1 .. N_Members loop
            if not Band (I).Is_Dead then
               for K in 1 .. Band (I).Route.N_Stamps loop
                  Band (I).Route.Stamps (K).Version := 0;
               end loop;
               --  (and a way with legs still to walk is found again outright: looked over step by
               --  step, a leg that crossed a wall as it is now drawn was taken for good still, and
               --  its walker went through the wall's corner: found 2026-11-23, when new rules moved
               --  who was walking where as a turned hovel's roof was finished)
               if Band (I).Route.N >= 2 and then Band (I).Leg < Band (I).Route.N then
                  Band (I).Replan := True;
               end if;
            end if;
         end loop;
      end if;
      Drawn_Key := Key;
   end Walk_Drawn;

   function House_Walls_On (K : Positive; X, Y : Float) return Boolean is
     (H_U (Houses (K).F, B (X), B (Y)) in 0 .. Houses (K).F.W - 1
      and then H_V (Houses (K).F, B (X), B (Y)) in 0 .. Houses (K).F.D - 1);

   function House_Drawn_Ground (K : Positive) return Drawn_Ground is
      F  : CB.House renames Houses (K).F;
      Bx : constant Frame_Box := Drawn_Box (F, 1.0);
      R  : Drawn_Ground;
   begin
      for U in Bx.U0 .. Bx.U1 loop
         for V in Bx.V0 .. Bx.V1 loop
            if Under_Drawn (F, Float (U), Float (V), 1.0) and then not (U in 0 .. F.W - 1 and then V in 0 .. F.D - 1) then
               declare
                  X   : constant Integer := H_X (F, U, V);
                  Y   : constant Integer := H_Y (F, U, V);
                  Top : constant Integer := Top_By (X, Y, F.Pad - 1);
               begin
                  R.Columns := R.Columns + 1;
                  if Top /= F.Pad - 1 then
                     R.Off := R.Off + 1;
                     R.Most_Off := Natural'Max (R.Most_Off, (if Top < 0 then 24 else abs (Top - (F.Pad - 1))));
                  end if;
                  if (for some Z in F.Pad .. House_Top (F) =>
                        Mat (X, Y, Z) in Crown or else Mat (X, Y, Z) in Trunk or else Mat (X, Y, Z) in Berry_Bush | Bare_Bush)
                  then
                     R.Grown := R.Grown + 1;
                  end if;
               end;
            end if;
         end loop;
      end loop;
      return R;
   end House_Drawn_Ground;

   function Yard_Ground (K : Positive) return Drawn_Ground is
      F : CB.House renames Houses (K).F;
      R : Drawn_Ground;
   begin
      if not Yard_Turned (F) then
         return R;
      end if;
      for U in Site_U_Lo (F) .. Site_U_Hi (F) loop
         for V in Site_V_Lo (F) .. Site_V_Hi (F) loop
            if In_Site (F, U, V) then
               declare
                  X    : constant Integer := H_X (F, U, V);
                  Y    : constant Integer := H_Y (F, U, V);
                  Want : constant Integer := Plan_Of (K, U, V).Top;
                  --  (under its own blocks the ground is what lies under them)
                  Own  : constant Boolean := U in -1 .. F.W and then V in -1 .. F.D;
                  Top  : constant Integer := (if Own then Ground_Row (X, Y, F.Pad - 1) else Top_By (X, Y, F.Pad - 1));
               begin
                  R.Columns := R.Columns + 1;
                  if not Own and then Top /= Want and then Mat (X, Y, Want) /= Plank then      --  (its floor is at its level)
                     R.Off := R.Off + 1;
                     R.Most_Off := Natural'Max (R.Most_Off, (if Top < 0 then 24 else abs (Top - Want)));
                  end if;
                  --  (leaves or a bush: its own timbers are of the stuff trunks are)
                  if (for some Z in Want + 1 .. Want + Yard_Clear_B =>
                        Mat (X, Y, Z) in Crown or else Mat (X, Y, Z) in Berry_Bush | Bare_Bush)
                  then
                     R.Grown := R.Grown + 1;
                  end if;
               end;
            end if;
         end loop;
      end loop;
      return R;
   end Yard_Ground;

   --  (what the last call for each house gave, and for what: its place and how far it was laid; a
   --  view is asked every frame, and its blueprint walked whole each time it is made)
   type Pieces_Key is record
      Fx, Fy, Placed : Integer := -1;
   end record;
   Pieces_Kept : array (1 .. Max_Houses) of Yard_Pieces_View;
   Pieces_Kept_Key : array (1 .. Max_Houses) of Pieces_Key;
   --  (a view made while some of the ground it stands on could not be read, its ground not yet in, is
   --  not kept: in the game the first frames come before it is)
   Pieces_Unread : Boolean := False;
   function Make_Pieces (K : Positive) return Yard_Pieces_View;
   function Yard_Pieces (K : Positive) return Yard_Pieces_View is
      Key : constant Pieces_Key := (Houses (K).F.Fx, Houses (K).F.Fy, Houses (K).Placed);
   begin
      if Pieces_Kept_Key (K) /= Key then
         Pieces_Unread := False;
         Pieces_Kept (K) := Make_Pieces (K);
         Pieces_Kept_Key (K) := (if Pieces_Unread then (-1, -1, -1) else Key);
      end if;
      return Pieces_Kept (K);
   end Yard_Pieces;
   function Make_Pieces (K : Positive) return Yard_Pieces_View is
      Hs : House_Rec renames Houses (K);
      F  : CB.House renames Hs.F;
      P  : Yard_Pieces_View;
      Max_Posts : constant := Max_Yard_Rails / 2 + 1;
      type Post is record
         X, Y : Integer := 0;       --  its block column
         Top  : Natural := 0;       --  the blueprint's number of its last block
      end record;
      Posts  : array (1 .. Max_Posts) of Post;
      N_Post : Natural := 0;
      Last_Plank : array (1 .. 2) of Natural := [others => 0];   --  (each gateway's: its last block's number)
      --  (each covering's: the number of the last block of each of its rows smoothed)
      Row_Done : array (1 .. CB.Max_Covers, 0 .. CB.Cover_D_B - 1) of Natural := [others => [others => 0]];
      N_Bp : Natural := 0;
      Near : constant Integer := F.Pad - 1;
      procedure Note (Bx, By, Bz : Integer; M : Material; S : CB.Stage; State : Natural) is
         pragma Unreferenced (State);
      begin
         if M = Air then
            return;
         end if;
         N_Bp := N_Bp + 1;
         if CB."=" (S, CB.Fence) and then M = Log then
            if Bz = F.Pad then
               if N_Post < Max_Posts then
                  N_Post := N_Post + 1;
                  Posts (N_Post) := (Bx, By, N_Bp);
               end if;
            elsif N_Post > 0 and then Posts (N_Post).X = Bx and then Posts (N_Post).Y = By then
               Posts (N_Post).Top := N_Bp;
            end if;
         elsif CB."=" (S, CB.Fence) and then M = Plank then
            --  (the planks over the gateways: which, by the side of its design they are on)
            Last_Plank ((if D_U (F, H_U (F, Bx, By), H_V (F, Bx, By)) < F.W / 2 then 1 else 2)) := N_Bp;
         elsif CB."=" (S, CB.Smooth) then
            declare
               Du : constant Integer := D_U (F, H_U (F, Bx, By), H_V (F, Bx, By));
               Dv : constant Integer := D_V (F, H_U (F, Bx, By), H_V (F, Bx, By));
               C  : constant Natural := CB.Covering_At (F, Du, Dv);
               Rw : constant Integer := Dv - (F.Yard_V1 - CB.Cover_D_B);
            begin
               if C > 0 and then Rw in 0 .. CB.Cover_D_B - 1 then
                  Row_Done (C, Rw) := N_Bp;
               end if;
            end;
         end if;
      end Note;
      procedure Draw is new CB.Blueprint (Note);
      --  (the ground's top at a column, its ground not yet in noted)
      function Ground_At (X, Y : Integer) return Integer is
         T : constant Integer := Top_By (X, Y, Near);
      begin
         if T < 0 then
            Pieces_Unread := True;
         end if;
         return T;
      end Ground_At;
      function Mid (X, Y : Integer; Z_B : Float) return Vec3 is
        (((Float (X) + 0.5) * 0.25, (Float (Y) + 0.5) * 0.25, Z_B * 0.25));
      Fence : constant Boolean := Yard_Turned (F) and then F.Fence_Pieces;
   begin
      if not Is_Store (F) or else not (Fence or else F.Smooth_Covers) or else Hs.Placed = 0 then
         return P;
      end if;
      Draw (F);
      --  the rails: two to each stretch between one post and the next, at the second block and the
      --  fourth, once the post that ends it stands
      for I in 1 .. N_Post - 1 loop
         if Fence and then Hs.Placed >= Posts (I + 1).Top and then P.N_Rails + 2 <= Max_Yard_Rails then
            declare
               Ta : constant Integer := Ground_At (Posts (I).X, Posts (I).Y);
               Tb : constant Integer := Ground_At (Posts (I + 1).X, Posts (I + 1).Y);
            begin
               for Row in 1 .. 2 loop
                  declare
                     Up : constant Float := (if Row = 1 then 2.5 else 4.5);
                  begin
                     P.N_Rails := P.N_Rails + 1;
                     P.Rails (P.N_Rails) :=
                       (A => Mid (Posts (I).X, Posts (I).Y, Float (Ta) + Up),
                        B => Mid (Posts (I + 1).X, Posts (I + 1).Y, Float (Tb) + Up), Plank => False);
                  end;
               end loop;
            end;
         end if;
      end loop;
      --  the planks over the gateways: from the post at each end of the fence to the storehouse's
      --  corner as it is drawn, at the gateway's height, once laid
      if Fence and then N_Post >= 2 then
         for G in 1 .. 2 loop
            if Last_Plank (G) > 0 and then Hs.Placed >= Last_Plank (G) and then P.N_Rails < Max_Yard_Rails then
               declare
                  Po : constant Post := (if G = 1 then Posts (1) else Posts (N_Post));
                  T  : constant Integer := Ground_At (Po.X, Po.Y);
                  C  : constant Vec3 := Drawn_Point (F, (if G = 1 then -1.0 else Float (F.W)), Float (F.D - 1));
               begin
                  P.N_Rails := P.N_Rails + 1;
                  P.Rails (P.N_Rails) :=
                    (A => Mid (Po.X, Po.Y, Float (T + 1 + CB.Gate_Post_H_B) + 0.5),
                     B => (C.X, C.Y, (Float (F.Pad + CB.Gate_Post_H_B) + 0.5) * 0.25), Plank => True);
               end;
            end if;
         end loop;
      end if;
      --  the coverings' roofs: as far back as each is smoothed, in the plane from the top of its front
      --  edge to the top of its back
      if F.Smooth_Covers then
         for C in 1 .. F.Covers loop
            declare
               Done : Natural := 0;
            begin
               for Rw in 0 .. CB.Cover_D_B - 1 loop
                  exit when Row_Done (C, Rw) = 0 or else Hs.Placed < Row_Done (C, Rw);
                  Done := Rw + 1;
               end loop;
               if Done > 0 then
                  declare
                     U0 : constant Integer := F.Cover_U (C);
                     V0 : constant Integer := F.Yard_V1 - CB.Cover_D_B;
                     Hi : Integer := -1;
                     Fu0 : constant Float := Float (U0) - 0.5;
                     Fu1 : constant Float := Float (U0 + CB.Cover_W_B) - 0.5;
                     Fv0 : constant Float := Float (V0) - 0.5;
                     Fv1 : constant Float := Float (V0 + CB.Cover_D_B) - 0.5;
                     function At_H (U, V : Float; Z_B : Integer) return Vec3 is
                        Q : constant Vec3 := Y_Point (F, U, V);
                     begin
                        return (Q.X, Q.Y, Float (Z_B) * 0.25);
                     end At_H;
                  begin
                     for U in U0 .. U0 + CB.Cover_W_B - 1 loop
                        for V in V0 .. V0 + CB.Cover_D_B - 1 loop
                           Hi := Integer'Max (Hi, Ground_At (Y_X (F, U, V), Y_Y (F, U, V)));
                        end loop;
                     end loop;
                     P.N_Roofs := P.N_Roofs + 1;
                     P.Roofs (P.N_Roofs) :=
                       (Front_L => At_H (Fu0, Fv0, Hi + 2 + CB.Cover_Front_H_B),
                        Front_R => At_H (Fu1, Fv0, Hi + 2 + CB.Cover_Front_H_B),
                        Back_R  => At_H (Fu1, Fv1, Hi + 2 + CB.Cover_Back_H_B),
                        Back_L  => At_H (Fu0, Fv1, Hi + 2 + CB.Cover_Back_H_B),
                        Smoothed => Done, Rows => CB.Cover_D_B);
                  end;
               end if;
            end;
         end loop;
      end if;
      return P;
   end Make_Pieces;

   function House_Place (K : Positive; X, Y : Float) return Drawn_Place is
      F  : CB.House renames Houses (K).F;
      P  : constant Vec3 := (X, Y, 0.0);
      Fu : constant Float := Frame_U (F, P);
      Fv : constant Float := Frame_V (F, P);
      W  : constant Float := Float (F.W);
      D  : constant Float := Float (F.D);
      Qu, Qv : Float;                 --  (where that is in it as it is drawn)
   begin
      CB.Back_Turn (F, Fu, Fv, Qu, Qv);
      if Qu in -0.5 .. W - 0.5 and then Qv in -0.5 .. D - 0.5 then
         if Qu in 0.5 .. W - 1.5 and then Qv in 0.5 .. D - 1.5 then
            return Within_It;
         end if;
         for O in 1 .. F.Open_N loop
            declare
               Op : CB.Opening renames F.Openings (O);
               A  : constant Float := (case Op.Side is when CB.Front | CB.Back => Qu, when others => Qv);
               On : constant Boolean :=
                 (case Op.Side is
                     when CB.Front => Qv < 0.5,
                     when CB.Back  => Qv > D - 1.5,
                     when CB.Left  => Qu < 0.5,
                     when CB.Right => Qu > W - 1.5);
            begin
               if Op.Bottom = 0 and then On and then A in Float (Op.Offset) - 0.5 .. Float (Op.Offset + Op.Width) - 0.5 then
                  return Within_It;                 --  (in a doorway)
               end if;
            end;
         end loop;
         return In_Its_Wall;
      elsif Fu in -1.5 .. W + 0.5 and then Fv in -1.5 .. D + 0.5 then
         return Where_Its_Blocks_Stand;
      end if;
      return Off_It;
   end House_Place;

   function Doorway_Count (K : Positive) return Natural is
      F : CB.House renames Houses (K).F;
      N : Natural := 0;
   begin
      for O in 1 .. F.Open_N loop
         if F.Openings (O).Bottom = 0 then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Doorway_Count;

   --  A house's windows, as its doorways: the foot at the opening's lower
   --  corner, on the row its sill's top is.
   function Window_Count (K : Positive) return Natural is
      F : CB.House renames Houses (K).F;
      N : Natural := 0;
   begin
      for O in 1 .. F.Open_N loop
         if F.Openings (O).Bottom > 0 then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Window_Count;

   function Opening_View (F : CB.House; Op : CB.Opening) return Doorway_View is
      U  : constant Vec3 := (Float (F.Ux), Float (F.Uy), 0.0);
      V  : constant Vec3 := (Float (F.Vx), Float (F.Vy), 0.0);
      Lo : constant Float := Float (Op.Offset) - 0.5;
   begin
      return
        (Foot   => (case Op.Side is
                       when CB.Front => H_Point (F, Lo, 0.0),
                       when CB.Back  => H_Point (F, Lo, Float (F.D - 1)),
                       when CB.Left  => H_Point (F, 0.0, Lo),
                       when CB.Right => H_Point (F, Float (F.W - 1), Lo)) + (0.0, 0.0, Float (Op.Bottom) * 0.25),
         Along  => (case Op.Side is when CB.Front | CB.Back => U, when CB.Left | CB.Right => V),
         Inward => (case Op.Side is
                       when CB.Front => V, when CB.Back => V * (-1.0),
                       when CB.Left => U, when CB.Right => U * (-1.0)),
         Width  => Float (Op.Width) * 0.25, Height => Float (Op.Height) * 0.25, Hung => True);
   end Opening_View;

   function Window_At (K : Positive; N : Positive) return Doorway_View is
      F    : CB.House renames Houses (K).F;
      Seen : Natural := 0;
   begin
      for O in 1 .. F.Open_N loop
         if F.Openings (O).Bottom > 0 then
            Seen := Seen + 1;
            if Seen = N then
               return Opening_View (F, F.Openings (O));
            end if;
         end if;
      end loop;
      return (others => <>);
   end Window_At;

   --  A storehouse's two gateways (the blueprint's: from its end out,
   --  Store_Gate_W_B wide or all the gap, in the line of its back wall).
   function Gateway_Count (K : Positive) return Natural is
     (if Is_Store (Houses (K).F) and then Houses (K).F.Yard_U1 > Houses (K).F.Yard_U0 then 2 else 0);

   function Gateway_At (K : Positive; N : Positive) return Doorway_View is
      F      : CB.House renames Houses (K).F;
      L_Gate : constant Integer := Integer'Max (F.Yard_U0 + 1, -CB.Store_Gate_W_B);
      R_Gate : constant Integer := Integer'Min (F.Yard_U1 - 1, F.W - 1 + CB.Store_Gate_W_B);
      Gate_V : constant Float := Float (F.D - 1);
      First  : constant Integer := (if N = 1 then L_Gate else F.W);
      Last   : constant Integer := (if N = 1 then -1 else R_Gate);
      Post_U : constant Integer := (if N = 1 then L_Gate - 1 else R_Gate + 1);
      At_P   : Vec3 := Y_Point (F, Float (First) - 0.5, Gate_V);
      Mid    : constant Vec3 := Y_Point (F, Float (First + Last) / 2.0, Gate_V);
      Post   : constant Vec3 := Y_Point (F, Float (Post_U), Gate_V);
   begin
      --  (on the ground as it lies there; hung once its outer post is raised)
      declare        --  (the ground under the gateway's lintel: the nearest to its yard's level)
         G : constant Integer := Ground_Row (B (Mid.X), B (Mid.Y), F.Pad - 1);
      begin
         At_P.Z := (if G >= 0 then Float (G + 1) * 0.25 else Pad_Z (F));
      end;
      return (Foot => At_P, Along => Y_Along (F), Inward => Y_Inward (F),
              Width => Float (Last - First + 1) * 0.25, Height => 1.0,
              Hung => Last >= First
                and then (for some Z in F.Pad - 8 .. F.Pad + 10 => Mat (B (Post.X), B (Post.Y), Z) = Log));
   end Gateway_At;

   function Doorway_At (K : Positive; N : Positive) return Doorway_View is
      F    : CB.House renames Houses (K).F;
      Seen : Natural := 0;
   begin
      for O in 1 .. F.Open_N loop
         if F.Openings (O).Bottom = 0 then
            Seen := Seen + 1;
            if Seen = N then
               return Opening_View (F, F.Openings (O));
            end if;
         end if;
      end loop;
      return (others => <>);
   end Doorway_At;

   --  Its bed: straw for one, then to where it sleeps with it.  True: it
   --  is seeing to it.
   function Think_Bed (I : Positive) return Boolean is separate;

   --  How far a place of a storehouse's ground is to walk from where its
   --  way in meets its path, when all is made (blocks): down the way, then
   --  over the floor from the way's foot.  Its ground is dug in that order.
   function Yard_Order (F : CB.House; P : Vec3) return Float is
      U   : constant Float := Y_U (F, P);
      V   : constant Float := Y_V (F, P);
      Mid : constant Float := Float (Way_Lo (F) + Way_Hi (F)) / 2.0;
   begin
      if At_End (F) then
         --  (a way at an end of its front: its stair from the path's edge inward, then the floor
         --  outward from the landing at the stair's foot, wherever along the way that is)
         declare
            Steps : constant Float := Float (End_Steps (F));
            Foot  : constant Float := Steps - Float (F.Door_Run) + 1.0;
         begin
            return (if V < Foot - 1.5 and then U in Float (Way_Lo (F)) - 0.5 .. Float (Way_Hi (F)) + 0.5
                    then Float (F.Door_Run) + V
                    else Float (F.Door_Run) + Steps + abs (U - Mid) + abs (V - Foot));
         end;
      end if;
      return (if V < -0.5 and then U in Float (Way_Lo (F)) - 0.5 .. Float (Way_Hi (F)) + 0.5
              then Float (F.Door_Run) + V
              else Float (F.Door_Run) + abs (U - Mid) + abs (V + 2.0));
   end Yard_Order;

   --  A tree standing on the stockyard is felled by its storehouse's
   --  builder before the ground is made (John, 2026-11-17: "Fell apple
   --  trees in the stockyard"): whatever its kind, whatever the order to
   --  spare apple trees, and whether or not wood is asked for; the nearest
   --  first.  Standing: one stands there still.  (Its logs are its own to
   --  carry home, as any tree's it fells: Go_Haul, before the next.)
   function Go_Fell_Yard (I : Positive; H : Positive; Standing : out Boolean) return Boolean is
      M : Member renames Band (I);
      F : CB.House renames Houses (H).F;
   begin
      Standing := False;
      for Attempt in 1 .. 3 loop
         declare
            Best   : Natural := 0;
            Best_D : Float := Float'Last;
         begin
            for K in 1 .. N_Trees loop
               declare
                  T : Tree_Rec renames Trees (K);
               begin
                  if not T.Down and then In_Site (F, H_U (F, T.Info.Bx, T.Info.By), H_V (F, T.Info.Bx, T.Info.By)) then
                     if Mat (T.Info.Bx, T.Info.By, T.Info.Bz + 1) not in Trunk then
                        T.Down := True;                  --  gone since it was found
                     else
                        Standing := True;
                        if (T.Reserved_By = 0 or else T.Reserved_By = I) and then not Failed (M, Tree_Base_Id + K)
                          and then Flat_Dist (M.Pos, Tree_Base (K)) < Best_D
                        then
                           Best := K;
                           Best_D := Flat_Dist (M.Pos, Tree_Base (K));
                        end if;
                     end if;
                  end if;
               end;
            end loop;
            if Best = 0 then
               return False;
            end if;
            if Route_To (M, Tree_Base (Best), Half_W (Best) + 0.9) then
               Release (M, I);
               M.Tree := Best;
               Trees (Best).Reserved_By := I;
               M.State := To_Tree;
               return True;
            end if;
            Remember_Failure (M, Tree_Base_Id + Best);
         end;
      end loop;
      return False;
   end Go_Fell_Yard;

   --  A builder at its house: a load for it carried there; its ground made
   --  ready; then its blueprint laid from what lies there, and more fetched
   --  from the stores when that runs out.  False: nothing of it for M to do
   --  now (no house wants a builder, or there is nothing to build with: it
   --  goes on as the forester it is).
   ------------------------------------------------------------------ housing: a ladder for the roof

   Ladder_Fail : constant := 21_400;   --  fail memos: no way to that house's ladder, or to stand one at it (to 21_448)

   procedure Set_Ladders (On : Boolean) is
   begin
      Ladders_On := On;
   end Set_Ladders;

   procedure Set_Path_Holes (On : Boolean) is
   begin
      Holes_On := On;
   end Set_Path_Holes;
   function Path_Holes return Boolean is (Holes_On);
   procedure Set_Path_Level (On : Boolean) is
   begin
      Path_Level_On := On;
   end Set_Path_Level;
   function Path_Level return Boolean is (Path_Level_On);
   procedure Set_Builder (I : Positive; On : Boolean) is
   begin
      if I <= N_Members and then not Band (I).Is_Dead then
         if On and then Band (I).Job /= Forester then
            Set_Job (I, Forester);
         end if;
         Band (I).Build_First := On;
      end if;
   end Set_Builder;
   function Is_Builder (I : Positive) return Boolean is
     (I <= N_Members and then Band (I).Build_First and then Band (I).Job = Forester);
   procedure Name_Stockman (I : Positive; By : Actor := The_Player) is
   begin
      if I <= N_Members and then not Band (I).Is_Dead then
         Set_Job (I, Porter, By);
         Keeper_N := I;
      end if;
   end Name_Stockman;
   procedure Name_Carpenter (I : Positive; By : Actor := The_Player) is
   begin
      if I <= N_Members and then not Band (I).Is_Dead then
         if Band (I).Job = Forester and then (Band (I).Site /= 0 or else Band (I).Build_First) then
            Set_Job (I, Unassigned, By);     --  (a builder: its house is left to another, as by any job given)
         end if;
         Set_Job (I, Forester, By);
         Carp_N := I;
      end if;
   end Name_Carpenter;
   procedure Set_Smooth_Covers (On : Boolean) is
   begin
      Smooth_Covers_On := On;
   end Set_Smooth_Covers;
   function Smooth_Covers return Boolean is (Smooth_Covers_On);
   procedure Set_Fence_Pieces (On : Boolean) is
   begin
      Fence_Pieces_On := On;
   end Set_Fence_Pieces;
   function Fence_Pieces return Boolean is (Fence_Pieces_On);

   procedure Set_Roof_Timbers (On : Boolean) is
   begin
      Truss_On := On;
   end Set_Roof_Timbers;
   function Roof_Timbers return Boolean is (Truss_On);
   procedure Set_Full_Truss (On : Boolean) is
   begin
      Full_On := On;
   end Set_Full_Truss;
   function Full_Truss return Boolean is (Full_On);
   procedure Set_Window_Timber (On : Boolean) is
   begin
      Sill_On := On;
   end Set_Window_Timber;
   function Window_Timber return Boolean is (Sill_On);
   function House_Has_Timbers (K : Positive) return Boolean is (Houses (K).F.Truss);
   function House_Has_Sills (K : Positive) return Boolean is (Houses (K).F.Sill);
   function Ladders return Boolean is (Ladders_On);
   function Ladders_Made return Natural is (N_Ladders);
   function Ladders_Lost return Natural is (N_Ladders_Lost);
   function Ladders_Standing return Natural is
      N : Natural := 0;
   begin
      for H in 1 .. N_Houses loop
         if Houses (H).Ladder > 0 then
            N := N + 1;
         end if;
      end loop;
      return N;
   end Ladders_Standing;

   --  The next block of a house's blueprint is of its roof, or of the
   --  roof's trimming.
   function Roof_Next (Hs : House_Rec) return Boolean is
     (not Hs.Built and then Hs.Pad_Done and then Hs.Placed >= Hs.Walls_N and then Hs.Placed < Hs.Dress_N);

   --  The slope a column of a house's roof is of, by the eave it runs down
   --  to: 1 front, 2 back (its ridge along its front), 3 left, 4 right.
   function Roof_Side (F : CB.House; Bx, By : Integer) return Positive is
     (if F.Ridge_Along_U then (if 2 * H_V (F, Bx, By) + 1 <= F.D then 1 else 2)
      else (if 2 * H_U (F, Bx, By) + 1 <= F.W then 3 else 4));

   --  Where along its front wall a ladder is stood: the middle of the
   --  longer stretch of wall beside its door, so that it is not in the
   --  doorway.
   function Clear_Of_Door (F : CB.House) return Float is
      D0 : constant Float := Float (Mid_Lo (F));
      D1 : constant Float := Float (Mid_Hi (F));
   begin
      return (if D0 >= Float (F.W - 1) - D1 then (D0 - 1.0) / 2.0 else (D1 + 1.0 + Float (F.W - 1)) / 2.0);
   end Clear_Of_Door;

   --  Where a ladder's foot is put for a side (Out_B blocks out from the
   --  wall), on the ground at the pad's level.
   function Ladder_Place (F : CB.House; Side : Positive; Out_B : Float) return Vec3 is
     (case Side is
         when 1 => H_Point (F, Clear_Of_Door (F), -Out_B),
         when 2 => H_Point (F, Clear_Of_Door (F), Float (F.D - 1) + Out_B),
         when 3 => H_Point (F, -Out_B, Float (F.D - 1) / 2.0),
         when others => H_Point (F, Float (F.W - 1) + Out_B, Float (F.D - 1) / 2.0));

   --  Where the ladder at a house rests on its eave (the eave is a block
   --  out from the wall, its top at the top of the wall).
   function Ladder_Top (Hs : House_Rec) return Vec3 is
      P : constant Vec3 := Ladder_Place (Hs.F, Positive'Max (1, Hs.Ladder), 1.0);
   begin
      return (P.X, P.Y, Pad_Z (Hs.F) + 0.25 * Float (Hs.F.Wall_H));
   end Ladder_Top;

   function Ladder_At (H : Positive) return Ladder_View is
   begin
      if H > N_Houses or else Houses (H).Ladder = 0 then
         return (others => <>);
      end if;
      declare
         F : constant Vec3 := Houses (H).Ladder_P;
         T : Vec3 := Ladder_Top (Houses (H));
      begin
         --  (its foot on high ground behind a house cut into a hill: it leans over the eave, not flat along it)
         T.Z := Float'Max (T.Z, F.Z + Ladder_Lean * Flat_Dist (F, T));
         return (Standing => True, Side => Houses (H).Ladder, Foot => F, Top => T);
      end;
   end Ladder_At;

   --  Member I is at the foot of the ladder that stands at its house, with
   --  its roof next: what it lays, it lays from the ladder.
   function At_Ladder (I : Positive) return Boolean is
      M : Member renames Band (I);
   begin
      return Ladders_On and then M.Site in 1 .. N_Houses and then Houses (M.Site).Ladder > 0
        and then Roof_Next (Houses (M.Site)) and then Flat_Dist (M.Pos, Houses (M.Site).Ladder_P) <= 0.7;
   end At_Ladder;

   --  (Up it between two bouts as well: after a bout it thinks, with empty
   --  hands, and sets out for the ladder's foot it stands at, a few ticks
   --  that were shown on the ground: John, 2026-11-17, "Fix thatching
   --  animation so serfs don't pop on and off the ladder between smoothing
   --  sections".  Only while straw for the roof lies at the house (or the
   --  roof is being trimmed, which takes none) and it is thinking, not
   --  waiting: one that waits for straw, or sleeps, stands on
   --  the ground.  Shown only: Set_Ladder_Stay (False) is how it was drawn.)
   Stay_Up : Boolean := True;
   procedure Set_Ladder_Stay (On : Boolean) is
   begin
      Stay_Up := On;
   end Set_Ladder_Stay;
   function Aloft (I : Positive) return Boolean is
     (I <= N_Members and then not Band (I).Is_Dead and then Band (I).Site_Patch = 0
      and then (Band (I).State = Raising
                or else (Stay_Up and then Band (I).Carried = 0
                         and then (Band (I).State = To_Site or else (Band (I).State = Idle and then Band (I).Wait <= 0.15))
                         and then Band (I).Site in 1 .. N_Houses
                         and then (Houses (Band (I).Site).Placed >= Houses (Band (I).Site).Roof_N    --  (trimming:
                                   or else Houses (Band (I).Site).Lying (Next_Kind (Band (I).Site)) > 0)))   --  nothing carried)
      and then At_Ladder (I));

   function Shown_At (I : Positive) return Vec3 is
   begin
      if not Aloft (I) then
         return Where (I);
      end if;
      declare
         L : constant Ladder_View := Ladder_At (Band (I).Site);
         D : constant Vec3 := L.Top - L.Foot;
         Len : constant Float := Sqrt (Dot (D, D));
      begin
         --  (its feet on a rung, a metre and a half up the ladder, or as far as the eave if that is nearer)
         return L.Foot + D * (Float'Min (1.5, 0.75 * Len) / Float'Max (0.1, Len));
      end;
   end Shown_At;

   --  A hovel that stands with a ladder still against it that nobody is
   --  going for (0: none).
   function Spare_Ladder (I : Positive) return Natural is
   begin
      for K in 1 .. N_Houses loop
         if Houses (K).Built and then Houses (K).Ladder > 0 and then not Failed (Band (I), Ladder_Fail + K)
           and then (for all J in 1 .. N_Members => Band (J).State /= To_Ladder or else Band (J).Ladder_Of /= K)
         then
            return K;
         end if;
      end loop;
      return 0;
   end Spare_Ladder;

   --  Member I is a builder whose roof is next with no ladder at its house
   --  and none to be had (stored, or left at a hovel that stands): a log of
   --  its own that it brings home is the ladder's.
   function Wants_Ladder_Log (I : Positive) return Boolean is
      M : Member renames Band (I);
   begin
      return Ladders_On and then M.Job = Forester and then M.Site in 1 .. N_Houses
        and then Roof_Next (Houses (M.Site)) and then Houses (M.Site).Ladder = 0
        and then Free_Stock (Ladder) = 0 and then Spare_Ladder (I) = 0;
   end Wants_Ladder_Log;

   --  To the ladder that stands at house K, to take it away.
   function Go_Ladder (I : Positive; K : Positive) return Boolean is
      M : Member renames Band (I);
   begin
      if Failed (M, Ladder_Fail + K) then
         return False;
      end if;
      if Route_To (M, Houses (K).Ladder_P, 0.6) then
         Release (M, I);
         M.Ladder_Of := K;
         M.State := To_Ladder;
         return True;
      end if;
      Remember_Failure (M, Ladder_Fail + K, Seconds => 300);
      return False;
   end Go_Ladder;

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
   --  The lord's cart pulled into a stockpile (with the cart, below).
   function Cart_To_Pull return Boolean;
   function Go_Tow (I : Positive) return Boolean;

   function Think_Build (I : Positive) return Boolean is separate;

   ------------------------------------------------------------------ the lord's cart

   Cart_Id : constant := 31_004;   --  a fail memo: no way to the cart

   --  Where one stands to take from it: beside the middle of its long side,
   --  on the stake's side of it.
   function Cart_Beside return Vec3 is
      Off : constant Float := Float (Cart_Wide_B) * 0.125 + 0.6;
   begin
      return (if Cart_X then (Cart_P.X, Cart_P.Y + (if Stake_At.Y >= Cart_P.Y then Off else -Off), Cart_P.Z)
              else (Cart_P.X + (if Stake_At.X >= Cart_P.X then Off else -Off), Cart_P.Y, Cart_P.Z));
   end Cart_Beside;

   --  The cart comes with the band: at the first step with a stake raised
   --  (its ground is in by then) it is stood on the first level, open ground
   --  found going out from the stake a metre at a time and round it from the
   --  north, its long side to the stake.  Open: grass or bare earth with
   --  nothing on it but grass to cut, no zone's and no path's, and nothing
   --  about it standing higher than its middle (so that nobody can step up
   --  onto it).  What makes it a thing in the world is its bed, a slab of
   --  timber over the ground (blocks of log: every test for a tree in the
   --  way holds for it, and nobody walks under it); the rest is drawn.
   procedure Place_Cart is
      From : constant Vec3 := (if N_Members > 0 then Band (1).Pos else Stake_At);
      procedure Turned (Along_X : Boolean) is
      begin
         Cart_Turn := (if Along_X then 0.0 else Ada.Numerics.Pi / 2.0);
      end Turned;
      function Fits (Cx, Cy : Integer; Along_X : Boolean; Row : out Integer) return Boolean is
         L  : constant Integer := (if Along_X then Cart_Long_B else Cart_Wide_B);
         W  : constant Integer := (if Along_X then Cart_Wide_B else Cart_Long_B);
         X0 : constant Integer := Cx - L / 2;
         Y0 : constant Integer := Cy - W / 2;
      begin
         Row := Ground_Row (Cx, Cy, B (Stake_At.Z) - 1);
         if Row < 0 then
            return False;
         end if;
         for X in X0 - 2 .. X0 + L + 1 loop
            for Y in Y0 - 2 .. Y0 + W + 1 loop
               declare
                  Zr : constant Integer := Ground_Row (X, Y, Row);
               begin
                  if Zr not in Row - 1 .. Row or else Mat (X, Y, Zr) not in Grass | Dirt
                    or else Zone_Of_Block (X, Y) /= 0
                    or else Near_Path ((Float (X) + 0.5) * 0.25, (Float (Y) + 0.5) * 0.25, 0.5)
                  then
                     return False;
                  end if;
                  for Z in Zr + 1 .. Row + Cart_Up_B + 6 loop
                     if Mat (X, Y, Z) not in Air | Tall_Grass then
                        return False;
                     end if;
                  end loop;
               end;
            end loop;
         end loop;
         return True;
      end Fits;
   begin
      Cart_Set := False;
      for Ring in 0 .. Integer (Cart_Far_M - Cart_Near_M) loop
         for Step in 0 .. 11 loop
            declare
               R   : constant Float := Cart_Near_M + Float (Ring);
               A   : constant Float := Ada.Numerics.Pi / 2.0 - Float (Step) * Ada.Numerics.Pi / 6.0;
               Cx  : constant Integer := B (Stake_At.X + R * Cos (A));
               Cy  : constant Integer := B (Stake_At.Y + R * Sin (A));
               Along_X : constant Boolean := abs Sin (A) > 0.7;      --  (its long side to the stake)
               Row : Integer;
            begin
               if Fits (Cx, Cy, Along_X, Row) then
                  Cart_P := (Float (Cx) * 0.25, Float (Cy) * 0.25, Float (Row + 1) * 0.25);
                  Cart_X := Along_X;
                  Turned (Along_X);
                  Cart_Set := True;
                  if Castle.Nav."=" (Castle.Nav.Plan (From, Cart_Beside, Within => Own_Region).Result, Castle.Nav.Found) then
                     for X in Cart_X0 .. Cart_X0 + (if Along_X then Cart_Long_B else Cart_Wide_B) - 1 loop
                        for Y in Cart_Y0 .. Cart_Y0 + (if Along_X then Cart_Wide_B else Cart_Long_B) - 1 loop
                           for Z in Row .. Row + Cart_Up_B - 1 loop      --  (the grass under it cut)
                              if Mat (X, Y, Z) = Tall_Grass then
                                 Write_Src (X, Y, Z, (Mat => Air, State => 0));
                              end if;
                           end loop;
                           Write_Src (X, Y, Row + Cart_Up_B, (Mat => Log, State => 0));
                        end loop;
                     end loop;
                     return;
                  end if;
                  Cart_Set := False;
               end if;
            end;
         end loop;
      end loop;
   end Place_Cart;

   --  A hunter keeps salt by for its kills: while the stockpiles (and the
   --  band's hands) hold less than Salt_Keep_Lb of it, the cart has some,
   --  there is room to store it and nobody is at the cart for it already.
   function Salt_Short return Boolean is
     (Curing_On and then Cart_Set and then not Cart_Bound and then Cart_Salt_N > 0 and then Have (Salt) < Salt_Keep_Lb
      and then Room_For (Salt)
      and then (for all J in 1 .. N_Members => Band (J).State not in To_Cart | At_Cart));

   --  To the cart for a sackful of it.
   function Go_Cart (I : Positive) return Boolean is
      M : Member renames Band (I);
   begin
      if not Salt_Short or else Failed (M, Cart_Id) then
         return False;
      end if;
      if Route_To (M, Cart_Beside, 0.6) then
         Release (M, I);
         M.State := To_Cart;
         return True;
      end if;
      Remember_Failure (M, Cart_Id, Seconds => 600);
      return False;
   end Go_Cart;

   --  N pounds of salt out of the stockpiles (as much as there is).
   procedure Use_Salt (N : Natural) is
      Left : Natural := N;
   begin
      for C in 1 .. N_Cells loop
         exit when Left = 0;
         if Cells (C).Kind = Salt and then Cells (C).Count > Cells (C).Outgoing then
            declare
               T : constant Natural := Natural'Min (Left, Cells (C).Count - Cells (C).Outgoing);
            begin
               Cells (C).Count := Cells (C).Count - T;
               Left := Left - T;
               if Cells (C).Count = 0 and then Cells (C).Incoming = 0 and then Cells (C).Outgoing = 0 then
                  Cells (C).Kind := Nothing;
               end if;
            end;
         end if;
      end loop;
   end Use_Salt;

   ------------------------------------------------------------------ the lord's cart pulled into a stockpile

   Tow_Fail : constant := 31_005;   --  a fail memo: no place for it, or no way to its shafts or on with it

   --  Its middle stands on a stockpile zone's ground.
   function Cart_In_Stockpile return Boolean is
      Z : constant Natural := Zone_Of_Block (B (Cart_P.X), B (Cart_P.Y));
   begin
      return Z in 1 .. N_Zones and then Zones (Z).Kind = Stockpile_Zone;
   end Cart_In_Stockpile;

   function Cart_To_Pull return Boolean is
     (Pull_On and then Curing_On and then Cart_Set and then not Cart_Bound and then N_Cells > 0
      and then not Cart_In_Stockpile
      and then (for all J in 1 .. N_Members => Band (J).State not in To_Cart | At_Cart));

   --  The bar across its shafts, standing at P and turned so.
   function Shaft_End (P : Vec3; Turn : Float) return Vec3 is
     (P.X + Cos (Turn) * Cart_Shaft_M, P.Y + Sin (Turn) * Cart_Shaft_M, P.Z);

   --  Its bed laid in the world, or taken out of it, its middle at P (on
   --  its ground: the row under P.Z is that ground's top).
   procedure Lay_Bed (P : Vec3; Along_X : Boolean; Lay : Boolean) is
      Row : constant Integer := Integer (Float'Floor (P.Z * 4.0 + 0.5)) - 1;
   begin
      for X in Bed_X0 (P, Along_X) .. Bed_X0 (P, Along_X) + (if Along_X then Cart_Long_B else Cart_Wide_B) - 1 loop
         for Y in Bed_Y0 (P, Along_X) .. Bed_Y0 (P, Along_X) + (if Along_X then Cart_Wide_B else Cart_Long_B) - 1 loop
            if Lay then
               for Z in Row .. Row + Cart_Up_B - 1 loop
                  if Mat (X, Y, Z) in Tall_Grass | Wild_Grain | Wild_Vegetables then
                     Write_Src (X, Y, Z, Air_Block);
                  end if;
               end loop;
               Write_Src (X, Y, Row + Cart_Up_B, (Mat => Log, State => 0));
            elsif Mat (X, Y, Row + Cart_Up_B) = Log then
               Write_Src (X, Y, Row + Cart_Up_B, Air_Block);
            end if;
         end loop;
      end loop;
   end Lay_Bed;

   --  Its bed fits with its middle at block corner (Cx, Cy): on Z's ground
   --  if Z > 0 (no place under it holding or awaiting anything, nobody
   --  standing there), else on ground nobody has marked and off the paths;
   --  level within a block, nothing over it but grass, nothing round it
   --  higher.  Row: the top of its ground.
   function Bed_Fits (Cx, Cy : Integer; Along_X : Boolean; Z : Natural; Near_Row : Integer; Row : out Integer)
     return Boolean
   is
      L  : constant Integer := (if Along_X then Cart_Long_B else Cart_Wide_B);
      W  : constant Integer := (if Along_X then Cart_Wide_B else Cart_Long_B);
      X0 : constant Integer := Cx - L / 2;
      Y0 : constant Integer := Cy - W / 2;
      P  : constant Vec3 := (Float (Cx) * 0.25, Float (Cy) * 0.25, 0.0);
   begin
      Row := Ground_Row (Cx, Cy, Near_Row);
      if Row < 0 then
         return False;
      end if;
      for X in X0 - 1 .. X0 + L loop
         for Y in Y0 - 1 .. Y0 + W loop
            declare
               Zr  : constant Integer := Ground_Row (X, Y, Row);
               Bed : constant Boolean := X in X0 .. X0 + L - 1 and then Y in Y0 .. Y0 + W - 1;
            begin
               if Zr < 0 or else Zr > Row then
                  return False;
               end if;
               if Bed then
                  if Zr < Row - 1
                    or else Mat (X, Y, Zr) not in Grass | Dirt | Footpath | Sand | Gravel | Clay | Placer_Gravel | Bog_Iron
                    or else (if Z > 0 then Zone_Of_Block (X, Y) /= Z
                             else Zone_Of_Block (X, Y) /= 0
                                  or else Near_Path ((Float (X) + 0.5) * 0.25, (Float (Y) + 0.5) * 0.25, 0.5))
                  then
                     return False;
                  end if;
                  for Zz in Zr + 1 .. Row + Cart_Up_B + 6 loop
                     if Mat (X, Y, Zz) not in Air | Tall_Grass | Wild_Grain | Wild_Vegetables then
                        return False;
                     end if;
                  end loop;
               end if;
            end;
         end loop;
      end loop;
      for K in 1 .. N_Cells loop
         if Bed_On_Block (P, Along_X, B (Cells (K).Centre.X), B (Cells (K).Centre.Y))
           and then (Cells (K).Kind /= Nothing or else Cells (K).Incoming > 0 or else Cells (K).Outgoing > 0)
         then
            return False;
         end if;
      end loop;
      for J in 1 .. N_Members loop
         if not Band (J).Is_Dead and then Bed_On_Block (P, Along_X, B (Band (J).Pos.X), B (Band (J).Pos.Y), Margin => 1)
         then
            return False;
         end if;
      end loop;
      return True;
   end Bed_Fits;

   --  Where it is to stand in a stockpile: on two of the zone's places side
   --  by side, empty, the nearest such to it, in the zone nearest it that has
   --  them; its bed square to the grid along the way the two lie, with a way
   --  from the stake to beside it.  Turn: the way it is pulled in.
   function Find_Cart_Place (P : out Vec3; Turn : out Float) return Boolean is
      Most : constant := 64;
      type Cand is record
         Mid  : Vec3;
         Z    : Natural;
         Away : Float;
         Along_X : Boolean;           --  the two part along X (else along Y)
      end record;
      C : array (1 .. Most) of Cand := [others => (Mid => (0.0, 0.0, 0.0), Z => 0, Away => 0.0, Along_X => True)];
      N : Natural := 0;
      function Empty (K : Positive) return Boolean is
        (Cells (K).Kind = Nothing and then Cells (K).Incoming = 0 and then Cells (K).Outgoing = 0
         and then not Under_Cart (K) and then not Cells (K).Overflow and then not Cells (K).Closed);
   begin
      P := (0.0, 0.0, 0.0);
      Turn := 0.0;
      for K1 in 1 .. N_Cells loop
         if Empty (K1) and then Cells (K1).Zone in 1 .. N_Zones then
            for K2 in K1 + 1 .. N_Cells loop
               if Cells (K2).Zone = Cells (K1).Zone and then Empty (K2)
                 and then Flat_Dist (Cells (K1).Centre, Cells (K2).Centre) in 0.8 .. 1.2
               then
                  declare
                     M : constant Vec3 := (Cells (K1).Centre + Cells (K2).Centre) * 0.5;
                     D : constant Float := Flat_Dist (M, Cart_P);
                     W : Natural := 0;
                  begin
                     if N < Most then
                        N := N + 1;
                        W := N;
                     else
                        for J in 1 .. N loop        --  (the farthest kept gives way)
                           if C (J).Away > D and then (W = 0 or else C (J).Away > C (W).Away) then
                              W := J;
                           end if;
                        end loop;
                     end if;
                     if W > 0 then
                        C (W) := (Mid => M, Z => Cells (K1).Zone, Away => D,
                                  Along_X => abs (Cells (K1).Centre.X - Cells (K2).Centre.X)
                                             >= abs (Cells (K1).Centre.Y - Cells (K2).Centre.Y));
                     end if;
                  end;
               end if;
            end loop;
         end if;
      end loop;
      --  nearest first: a zone's nearer pairs before a farther zone's
      for Try in 1 .. N loop
         declare
            Best : Natural := 0;
         begin
            for J in 1 .. N loop
               if C (J).Z > 0 and then (Best = 0 or else C (J).Away < C (Best).Away) then
                  Best := J;
               end if;
            end loop;
            exit when Best = 0;
            declare
               Mid : constant Vec3 := C (Best).Mid;
               Z   : constant Natural := C (Best).Z;
               Cx  : constant Integer := Integer (Float'Rounding (Mid.X * 4.0));
               Cy  : constant Integer := Integer (Float'Rounding (Mid.Y * 4.0));
               Along_X : constant Boolean := C (Best).Along_X;
               Row : Integer;
            begin
               C (Best).Z := 0;
               declare
               begin
                  begin
                     if Bed_Fits (Cx, Cy, Along_X, Z, B (Mid.Z) - 1, Row)
                       and then (for some K in 1 .. N_Cells =>
                                   Bed_On_Block ((Float (Cx) * 0.25, Float (Cy) * 0.25, 0.0), Along_X,
                                                 B (Cells (K).Centre.X), B (Cells (K).Centre.Y)))
                     then
                        declare
                           At_P : constant Vec3 := (Float (Cx) * 0.25, Float (Cy) * 0.25, Float (Row + 1) * 0.25);
                           Sgn  : constant Float :=
                             (if (if Along_X then At_P.X - Cart_P.X else At_P.Y - Cart_P.Y) >= 0.0 then 1.0 else -1.0);
                           T    : constant Float :=
                             (if Along_X then (if Sgn > 0.0 then 0.0 else Ada.Numerics.Pi)
                              else (if Sgn > 0.0 then Ada.Numerics.Pi / 2.0 else -Ada.Numerics.Pi / 2.0));
                           Off  : constant Float := Float (Cart_Wide_B) * 0.125 + 0.6;
                           Side : constant Vec3 :=
                             (if Along_X then (At_P.X, At_P.Y + (if Stake_At.Y >= At_P.Y then Off else -Off), At_P.Z)
                              else (At_P.X + (if Stake_At.X >= At_P.X then Off else -Off), At_P.Y, At_P.Z));
                        begin
                           if Castle.Nav."=" (Castle.Nav.Plan (Stake_At, Side, Within => Own_Region).Result, Castle.Nav.Found)
                             and then Castle.Nav."=" (Castle.Nav.Plan (Stake_At, Shaft_End (At_P, T), Within => Own_Region).Result,
                                                      Castle.Nav.Found)
                           then
                              P := At_P;
                              Turn := T;
                              return True;
                           end if;
                        end;
                     end if;
                  end;
               end;
            end;
         end;
      end loop;
      return False;
   end Find_Cart_Place;

   function Go_Tow (I : Positive) return Boolean is
      M : Member renames Band (I);
      P : Vec3;
      T : Float;
   begin
      if not Cart_To_Pull or else Failed (M, Tow_Fail) then
         return False;
      end if;
      if Find_Cart_Place (P, T) and then Route_To (M, Shaft_End (Cart_P, Cart_Turn), 0.4) then
         Release (M, I);
         Cart_Bound := True;
         Cart_By := I;
         Goal_P := P;
         Goal_Turn := T;
         M.State := To_Tow;
         M.Spot := Shaft_End (Cart_P, Cart_Turn) + (0.0, 0.0, 0.8);
         return True;
      end if;
      Remember_Failure (M, Tow_Fail, Seconds => 600);
      return False;
   end Go_Tow;

   procedure Take_Cart_Away is
   begin
      if Cart_Set then
         Lay_Bed (Cart_P, Cart_X, Lay => False);
         Cart_Set := False;
      end if;
   end Take_Cart_Away;

   --  Set down where it is, if it fits there (or near, a metre at a time and
   --  round, ten at most); else where it was lifted from.
   procedure Set_Cart_Down (Near : Vec3) is
      Row : Integer;
      procedure Stand (Cx, Cy : Integer; Along_X : Boolean; R : Integer; Turn : Float) is
      begin
         Cart_P := (Float (Cx) * 0.25, Float (Cy) * 0.25, Float (R + 1) * 0.25);
         Cart_X := Along_X;
         Cart_Turn := Turn;
         Lay_Bed (Cart_P, Cart_X, Lay => True);
         Cart_Set := True;
         Cart_Towed := False;
         Cart_Bound := False;
         Cart_By := 0;
      end Stand;
      Ax : constant Boolean := Turn_Along_X (Cart_Turn);
      T  : constant Float :=
        (if Ax then (if Cos (Cart_Turn) >= 0.0 then 0.0 else Ada.Numerics.Pi)
         else (if Sin (Cart_Turn) >= 0.0 then Ada.Numerics.Pi / 2.0 else -Ada.Numerics.Pi / 2.0));
   begin
      for Ring in 0 .. 10 loop
         for Step in 0 .. (if Ring = 0 then 0 else 11) loop
            declare
               A  : constant Float := Float (Step) * Ada.Numerics.Pi / 6.0;
               Cx : constant Integer := Integer (Float'Rounding ((Near.X + Float (Ring) * Cos (A)) * 4.0));
               Cy : constant Integer := Integer (Float'Rounding ((Near.Y + Float (Ring) * Sin (A)) * 4.0));
               Z  : constant Natural := Zone_Of_Block (Cx, Cy);
               Zs : constant Natural := (if Z in 1 .. N_Zones and then Zones (Z).Kind = Stockpile_Zone then Z else 0);
            begin
               if Bed_Fits (Cx, Cy, Ax, Zs, B (Near.Z) - 1, Row) then
                  Stand (Cx, Cy, Ax, Row, T);
                  return;
               end if;
            end;
         end loop;
      end loop;
      Stand (B (Cart_From.X + 0.125), B (Cart_From.Y + 0.125), Turn_Along_X (Cart_Turn), B (Cart_From.Z) - 1, T);
   end Set_Cart_Down;

   procedure Step_Tow (I : Positive) is
      M    : Member renames Band (I);
      Ok   : Boolean;
      Goal : constant Vec3 := M.Goal;
   begin
      case M.State is
         when To_Tow =>
            Keep_Route_Good (M, Ok);
            if not Ok or else not Cart_Set or else not Cart_Bound or else Cart_By /= I then
               if not Ok then
                  Remember_Failure (M, Tow_Fail, Seconds => 600);
               end if;
               M.State := Idle;                     --  (the place held for it is let go: Keep_Cart)
               M.Wait := 0.5;
            elsif Walk_On (M, 0.5) then
               --  its shafts taken up: lifted off its ground, and on to the place held for it, its
               --  puller to stand at the bar with the cart where it is to stand behind
               if Route_To (M, Shaft_End (Goal_P, Goal_Turn), 0.3) then
                  Lay_Bed (Cart_P, Cart_X, Lay => False);
                  Cart_From := Cart_P;
                  Cart_Set := False;
                  Cart_Towed := True;
                  M.State := Towing;
               else
                  Remember_Failure (M, Tow_Fail, Seconds => 600);
                  M.State := Idle;
                  M.Wait := 0.5;
               end if;
            end if;
         when Towing =>
            Keep_Route_Good (M, Ok);
            if not Ok then
               Remember_Failure (M, Tow_Fail, Seconds => 600);
               M.State := Idle;                     --  (set down where it is: Keep_Cart)
               M.Wait := 0.5;
               return;
            end if;
            if Walk (M, Goal, 0.3, Scale => Cart_Tow_Pace) then
               declare
                  Row : Integer;
                  Ax  : constant Boolean := Turn_Along_X (Goal_Turn);
               begin
                  if Bed_Fits (B (Goal_P.X + 0.125), B (Goal_P.Y + 0.125), Ax,
                               Zone_Of_Block (B (Goal_P.X), B (Goal_P.Y)), B (Goal_P.Z) - 1, Row)
                  then
                     Cart_P := Goal_P;
                     Cart_X := Ax;
                     Cart_Turn := Goal_Turn;
                     Lay_Bed (Cart_P, Cart_X, Lay => True);
                     Cart_Set := True;
                     Cart_Towed := False;
                     Cart_Bound := False;
                     Cart_By := 0;
                  else
                     Set_Cart_Down (Cart_P);
                  end if;
               end;
               M.State := Idle;
               M.Wait := 0.5;
            else
               --  it trails behind, its middle Cart_Shaft_M back from where its puller is
               declare
                  Dx : constant Float := M.Pos.X - Cart_P.X;
                  Dy : constant Float := M.Pos.Y - Cart_P.Y;
                  L  : constant Float := Sqrt (Dx * Dx + Dy * Dy);
               begin
                  if L > Cart_Shaft_M then
                     Cart_P := On_Ground (M.Pos.X - Dx / L * Cart_Shaft_M, M.Pos.Y - Dy / L * Cart_Shaft_M);
                  end if;
                  if L > 0.05 then
                     Cart_Turn := Arctan (Dy, Dx);
                  end if;
                  M.Spot := M.Pos + (0.0, 0.0, 0.8);
               end;
            end if;
         when others =>
            null;
      end case;
   end Step_Tow;

   --  Once a step: a cart in tow with nobody at its shafts is set down; a
   --  place held for it with nobody coming to it is let go.
   procedure Keep_Cart is
   begin
      if Cart_Towed and then (Cart_By not in 1 .. N_Members or else Band (Cart_By).Is_Dead
                              or else Band (Cart_By).State /= Towing)
      then
         Set_Cart_Down (Cart_P);
      end if;
      if Cart_Bound and then not Cart_Towed
        and then (Cart_By not in 1 .. N_Members or else Band (Cart_By).Is_Dead or else Band (Cart_By).State /= To_Tow)
      then
         Cart_Bound := False;
         Cart_By := 0;
      end if;
   end Keep_Cart;

   function Cart_Front (P : out Vec3; Turn : out Float) return Boolean is
   begin
      P := (0.0, 0.0, 0.0);
      Turn := 0.0;
      if Store_House not in 1 .. N_Houses or else not Houses (Store_House).Built then
         return False;
      end if;
      declare
         F  : CB.House renames Houses (Store_House).F;
         --  its middle: half a metre past the edge of the way in from the path (the middle of the
         --  storehouse's front), on the wider side of the yard, in the middle of the staging
         Hi_Side : constant Boolean := F.Yard_U1 - (F.W - 1) >= -F.Yard_U0;
         Cv : constant Float := Float (F.Yard_V0) / 2.0;
         --  One place tried: on the high or the low side of the way in, Out_B blocks further from it,
         --  across the staging with its shafts toward the path, or along the front with its shafts
         --  away from the way in.
         function Tried (Hi, Across : Boolean; Out_B : Natural) return Boolean is
            Half : constant Float := Float (if Across then Cart_Wide_B else Cart_Long_B) / 2.0;
            Cu : constant Float :=
              (if Hi then Float (Mid_Hi (F)) + 0.5 + Half + 2.0 + Float (Out_B)
               else Float (Mid_Lo (F)) - 0.5 - Half - 2.0 - Float (Out_B));
            Mid : constant Vec3 := Y_Point (F, Cu, Cv - 0.5);    --  (rounded to a block corner: the bed's middle)
            To  : constant Vec3 := (if Across then Y_Point (F, Cu, -100.0)
                                    else Y_Point (F, Cu + (if Hi then 100.0 else -100.0), Cv - 0.5));
            Row : Integer;
         begin
            --  (its bed before the storehouse's front, not past its ends)
            if Cu - Half < -2.0 or else Cu + Half > Float (F.W + 1) then
               return False;
            end if;
            P := (Float'Rounding (Mid.X * 4.0) * 0.25, Float'Rounding (Mid.Y * 4.0) * 0.25, Pad_Z (F));
            Turn := Arctan (To.Y - P.Y, To.X - P.X);
            if Bed_Fits (B (P.X + 0.125), B (P.Y + 0.125), Turn_Along_X (Turn), Houses (Store_House).Zone,
                         B (P.Z) - 1, Row)
            then
               P.Z := Float (Row + 1) * 0.25;
               return True;
            end if;
            return False;
         end Tried;
      begin
         --  (as it always was: across the staging, hard by the way in, on the wider side)
         if Tried (Hi_Side, Across => True, Out_B => 0) then
            return True;
         end if;
         --  (Since 2026-11-21, where that place does not take it: along the front, which a staging of a
         --  metre and a half has room for; the other side of the way; further from the way, a metre at
         --  a time.  The first that fits, in an order that never changes.)
         for Out_B in 0 .. (if Cart_Search_On then F.W / 4 else -1) loop
            for Side in Boolean loop
               for Across in reverse Boolean loop
                  if not (Out_B = 0 and then Side = False and then Across)        --  (tried above)
                    and then Tried ((if Side then not Hi_Side else Hi_Side), Across, 4 * Out_B)
                  then
                     return True;
                  end if;
               end loop;
            end loop;
         end loop;
         P := (0.0, 0.0, 0.0);
         Turn := 0.0;
         return False;
      end;
   end Cart_Front;

   function Cart_At_Front return Boolean is
      P : Vec3;
      T : Float;
   begin
      if not Cart_Set or else Store_House not in 1 .. N_Houses or else not Houses (Store_House).Built then
         return False;
      end if;
      declare
         F : CB.House renames Houses (Store_House).F;
         V : constant Float := Y_V (F, Cart_P);
         U : constant Float := Y_U (F, Cart_P);
      begin
         --  in the staging before its front, clear of the way in, or where it is to stand
         --  (the way in where it is: at an end of the stockyard's front the middle of the storehouse's
         --  front is no way, and a cart set down anywhere before the front is before the storehouse.
         --  Held to the middle all the same, one set down a metre short of its place, on arriving to
         --  find it taken, stood before the storehouse for good with its salt never carried in: its
         --  next place's shafts lay up on the path, over the staging's wall.  With the floor chosen
         --  from the land, Set_Yard_Floor_Low off, as it was.)
         return (V in Float (F.Yard_V0) .. -1.0 and then U in -2.0 .. Float (F.W + 1)
                 and then (if Yard_Low_On and then At_End (F)
                           then U < Float (Way_Lo (F)) - 2.0 or else U > Float (Way_Hi (F)) + 2.0
                           else U < Float (Mid_Lo (F)) - 2.0 or else U > Float (Mid_Hi (F)) + 2.0))
           or else (Cart_Front (P, T) and then Flat_Dist (P, Cart_P) < 0.3);
      end;
   end Cart_At_Front;

   function Cart_At_Storehouse return Boolean is (Cart_At_Front);
   function Cart_Place_By_Storehouse return Boolean is
      P : Vec3;
      T : Float;
   begin
      return Cart_Front (P, T);
   end Cart_Place_By_Storehouse;

   --  The stockman brings the lord's cart to the storehouse's front, once.
   function Go_Tow_Front (I : Positive) return Boolean is
      M : Member renames Band (I);
      P : Vec3;
      T : Float;
   begin
      if not Curing_On or else not Cart_Set or else Cart_Bound or else Cart_Towed or else Cart_At_Front
        or else Failed (M, Tow_Fail)
        or else (for some J in 1 .. N_Members => Band (J).State in To_Cart | At_Cart)
      then
         return False;
      end if;
      if Cart_Front (P, T) and then Route_To (M, Shaft_End (Cart_P, Cart_Turn), 0.4) then
         Release (M, I);
         Cart_Bound := True;
         Cart_By := I;
         Goal_P := P;
         Goal_Turn := T;
         M.State := To_Tow;
         M.Spot := Shaft_End (Cart_P, Cart_Turn) + (0.0, 0.0, 0.8);
         return True;
      end if;
      Remember_Failure (M, Tow_Fail, Seconds => 600);
      return False;
   end Go_Tow_Front;

   --  And carries its salt in, a sack at a time, while a place inside has room.
   function Go_Unload (I : Positive) return Boolean is
      M : Member renames Band (I);
   begin
      if not Curing_On or else not Cart_Set or else Cart_Bound or else Cart_Salt_N = 0 or else not Cart_At_Front
        or else Fitted_Rooms (Salt) = 0 or else Failed (M, Cart_Id)
        or else (for some J in 1 .. N_Members => Band (J).State in To_Cart | At_Cart)
      then
         return False;
      end if;
      if Route_To (M, Cart_Beside, 0.6) then
         Release (M, I);
         M.State := To_Cart;
         return True;
      end if;
      Remember_Failure (M, Cart_Id, Seconds => 600);
      return False;
   end Go_Unload;

   --  A deer is butchered by whoever carries it home (the spec, Set_Kill_Home).
   Kill_Home_On : Boolean := True;
   procedure Set_Kill_Home (On : Boolean) is
   begin
      Kill_Home_On := On;
   end Set_Kill_Home;
   function Kill_Home return Boolean is (Kill_Home_On);
   --  (a measure: a whole deer laid down, by why, and whether on a stockpile's ground)
   Drops, Drops_In_Pile : array (Carcass_Drop) of Natural := [others => 0];
   function Carcasses_Dropped (Why : Carcass_Drop; In_A_Stockpile : Boolean := False) return Natural is
     (if In_A_Stockpile then Drops_In_Pile (Why) else Drops (Why));
   procedure Note_Drop (M : Member; Why : Carcass_Drop) is
      Z : constant Natural := Zone_Of_Block (B (M.Pos.X), B (M.Pos.Y));
   begin
      if M.Prize > 0 then
         Drops (Why) := Drops (Why) + 1;
         if Z in 1 .. N_Zones and then Zones (Z).Kind = Stockpile_Zone then
            Drops_In_Pile (Why) := Drops_In_Pile (Why) + 1;
         end if;
      end if;
   end Note_Drop;

   procedure Think (I : Positive) is separate;

   ------------------------------------------------------------------ one step

   --  It dies where it is: what it had set aside or claimed is let go, what
   --  it carried is lost with it (a deer it carried is put down), and the
   --  rest grieve.
   procedure Die (I : Positive) is separate;

   --  For the checks, as Supply is: member I dies where it stands.
   procedure Strike_Down (I : Positive) is
   begin
      if I <= N_Members and then not Band (I).Is_Dead then
         Die (I);
      end if;
   end Strike_Down;


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

   --  A stockpile's place is made level when something is first put on it
   --  (the spec, "A place is made level").  Once a colony second: every
   --  ground place of a stockpile (not the stockyard's: its ground is its
   --  storehouse's) that holds something or has something on its way, and
   --  has not been looked at yet: each block column of its square metre that
   --  is its zone's ground brought to the place's own level, a block or two
   --  cut off or put under, its top as it was (turf stays turf).  Never under
   --  a tree's foot, through water, or under the cart.
   Place_Level_On : Boolean := True;
   Places_Level_N, Place_Blocks_N : Natural := 0;
   procedure Flatten_Pile (Z : Positive; Again : Boolean := False);     --  (its body is below, with its rule)

   --  What a block column of a stockpile's ground is to the level it is to
   --  have (Flatten_Pile, below; Level_Places): there already; to be cut or
   --  filled; to be left until a trunk on it or the cart over it is gone;
   --  or left for good (further off than Flat_Most_B, something laid or
   --  built on top, water in what would be moved or beside it, something
   --  standing where the earth would go).
   --
   --  The land is cut or filled whatever it is made of: earth, rock, a
   --  boulder, ore at the surface.  (Left as it lay, a boulder stood in the
   --  floor on a plinth of its own earth, the places over it closed, and
   --  where the band then prised its stone off the earth under it stood
   --  bare over the floor or in a hole of it; and a meadow of bog iron,
   --  three block columns in ten at the reference stake, left as many of a
   --  stockpile's columns unmoved: 2026-11-23, the fourteen awkward sites.)
   subtype Of_The_Land is Material
     with Static_Predicate =>
       Of_The_Land in Bedrock | Granite | Limestone | Sandstone | Dirt | Grass | Sand | Gravel | Clay
                    | Coal | Iron_Ore | Bog_Iron | Silver_Ore | Gold_Ore | Rock_Salt | Placer_Gravel
                    | Boulder | Footpath | Deep;
   --  What lies on top of a block column brought to the level: what lay on
   --  top of it before (turf stays turf, rock rock), but no boulder: a
   --  boulder's block in the floor would be prised out of it for its stone,
   --  and leave a hole under what is stored there.
   function Flat_Top (Was : Material) return Material is (if Was in Boulder | Deep then Dirt else Was);
   function Flat_Kind (X, Y, Top, Level : Integer) return Flat_Column is
      Lo : constant Integer := Integer'Min (Top, Level);
      Hi : constant Integer := Integer'Max (Top, Level);
   begin
      if Top < 0 then
         return No_Ground;
      elsif (for some Z in Lo + 1 .. Hi + 2 => Mat (X, Y, Z) in Trunk) then
         --  (a trunk is rooted two blocks into the ground: the earth under one may lie at the level
         --  already, and comes up again to where the land lay when its stump is taken out)
         return Trunk_On;
      elsif Top = Level then
         return At_Level;
      elsif Cart_On_Block (X, Y, Margin => 4) then
         --  (before what follows: the cart's own bed stands where the earth would go, and a block
         --  column that waits for the cart is not one left for good)
         return Cart_On;
      elsif abs (Top - Level) > Flat_Most_B then
         return Too_Far;
      elsif Mat (X, Y, Top) not in Of_The_Land then
         return Not_Earth;
      elsif (for some Z in Lo + 1 .. Hi + 2 => Class_Of (Mat (X, Y, Z)) = Liquid) then
         return Water_In;
      elsif Level > Top
        and then (for some Z in Top + 1 .. Level + 1 =>
                    Mat (X, Y, Z) not in Air | Tall_Grass | Wild_Grain | Wild_Vegetables | Crown)
      then
         return Thing_Over;            --  (something stands where the earth would go; leaves are lopped)
      elsif Level < Top
        and then (for some Z in Level + 1 .. Top + 2 =>
                    Class_Of (Mat (X + 1, Y, Z)) = Liquid or else Class_Of (Mat (X - 1, Y, Z)) = Liquid
                    or else Class_Of (Mat (X, Y + 1, Z)) = Liquid or else Class_Of (Mat (X, Y - 1, Z)) = Liquid)
      then
         return Water_By;              --  (water stands beside it, higher than it would be cut to: its bank is left)
      else
         return To_Move;
      end if;
   end Flat_Kind;

   --  Whoever and whatever is on zone Z's ground stands or lies on it as it
   --  is now, up or down (a stockpile made one level under them: as far as
   --  Flat_Most_B): the living that stand there, where there is room to
   --  stand; logs and a deer lying there.  And every way being walked is
   --  found again (it was planned over the ground as it lay).
   procedure Settle_On (Z : Positive) is
      function Ground_M (P : Vec3; Found : out Boolean) return Float is
         X : constant Integer := B (P.X);
         Y : constant Integer := B (P.Y);
         T : Integer;
      begin
         Found := False;
         if Zone_Of_Block (X, Y) /= Z then
            return P.Z;
         end if;
         T := Top_By (X, Y, B (P.Z + 0.01) - 1);
         if T < 0 or else abs (Float (T + 1) * 0.25 - P.Z) > Float (Flat_Most_B) * 0.25 + 0.01
           or else (for some Up in 1 .. Castle.Nav.Head_B => Class_Of (Mat (X, Y, T + Up)) = Solid)
         then
            return P.Z;
         end if;
         Found := True;
         return Float (T + 1) * 0.25;
      end Ground_M;
      Found : Boolean;
      Zm    : Float;
   begin
      for J in 1 .. N_Members loop
         if not Band (J).Is_Dead then
            Zm := Ground_M (Band (J).Pos, Found);
            if Found and then abs (Zm - Band (J).Pos.Z) > 0.01 then
               Band (J).Pos.Z := Zm;
               Band (J).Prev.Z := Zm;
            end if;
            if Band (J).Route.N >= 2 and then Band (J).Leg < Band (J).Route.N then
               Band (J).Replan := True;
            end if;
         end if;
      end loop;
      for P in 1 .. N_Piles loop
         if Piles (P).Count > 0 then
            Zm := Ground_M (Piles (P).Centre, Found);
            if Found then
               Piles (P).Centre.Z := Zm;
            end if;
         end if;
      end loop;
      for K in 1 .. N_Carcasses loop
         if Carcasses (K).Used and then Carcasses (K).Lying then
            Zm := Ground_M (Carcasses (K).Centre, Found);
            if Found then
               Carcasses (K).Centre.Z := Zm;
            end if;
         end if;
      end loop;
   end Settle_On;
   procedure Set_Place_Level (On : Boolean) is
   begin
      Place_Level_On := On;
   end Set_Place_Level;
   function Place_Level return Boolean is (Place_Level_On);
   function Places_Levelled return Natural is (Places_Level_N);
   function Place_Blocks_Moved return Natural is (Place_Blocks_N);
   procedure Level_Places is
      Touched : array (1 .. Max_Zones) of Boolean := [others => False];
      Any     : Boolean := False;
   begin
      if not Place_Level_On then
         return;
      end if;
      --  (the cart in tow: a stockpile made one level that it was lifted off is made level where
      --  it stood.  That ground waited for the cart to go, and no place lies on it to do it: a
      --  place is not planned where the cart stands.  Left, it was the land as it lay in a floor
      --  cut or filled round it: a hollow as deep as the fill, which a serf drops into and does
      --  not climb out of.  By where it was lifted from, which is saved: a run loaded while it
      --  is in tow does the same)
      if Flat_On and then Cart_Towed then
         declare
            --  (the block columns its bed stood in are nobody's: the stockpiles round them)
            Seen : array (1 .. Max_Zones) of Boolean := [others => False];
            Zc   : Natural;
         begin
            for Dx in -10 .. 10 loop
               for Dy in -10 .. 10 loop
                  Zc := Zone_Of_Block (B (Cart_From.X) + Dx, B (Cart_From.Y) + Dy);
                  if Zc in 1 .. N_Zones and then not Seen (Zc) then
                     Seen (Zc) := True;
                     if Zones (Zc).Kind = Stockpile_Zone and then not Zones (Zc).Yard then
                        Flatten_Pile (Zc, Again => True);
                     end if;
                  end if;
               end loop;
            end loop;
         end;
      end if;
      for C in 1 .. N_Cells loop
         declare
            Cl : Cell renames Cells (C);
         begin
            if not Cl.Level_Ok and then Cl.Fit = Ground and then not Cl.Closed
              and then (Cl.Count > 0 or else Cl.Incoming > 0 or else (Flat_On and then not Cl.Overflow))
              and then Cl.Zone in 1 .. N_Zones and then Zones (Cl.Zone).Kind = Stockpile_Zone and then not Zones (Cl.Zone).Yard
              and then (Flat_On or else not Under_Cart (C))
            then
               --  (a stockpile one level: each block column says for itself whether the cart is on
               --  it (Flat_Kind, Cart_On), so a place the cart reaches is not left out whole.  Not
               --  proved by cutting: the sixty-four block columns left where the cart had stood
               --  were mended by the making level while it is in tow, above, not by this)
               declare
                  T  : constant Float := Zones (Cl.Zone).Turn;
                  Cs : constant Float := Cos (T);
                  Sn : constant Float := Sin (T);
                  Zr : constant Integer := B (Cl.Centre.Z + 0.01) - 1;       --  the row its ground's top is to be
                  Moved : Natural := 0;
                  Waiting : Boolean := False;     --  (Flat_On: a block column of it has a trunk in the way still)
               begin
                  for Bx in B (Cl.Centre.X - 0.75) .. B (Cl.Centre.X + 0.75) loop
                     for By in B (Cl.Centre.Y - 0.75) .. B (Cl.Centre.Y + 0.75) loop
                        declare
                           Dx : constant Float := (Float (Bx) + 0.5) * 0.25 - Cl.Centre.X;
                           Dy : constant Float := (Float (By) + 0.5) * 0.25 - Cl.Centre.Y;
                        begin
                           if abs (Dx * Cs + Dy * Sn) < 0.5 and then abs (Dy * Cs - Dx * Sn) < 0.5
                             and then Zone_Of_Block (Bx, By) = Cl.Zone
                           then
                              declare
                                 Top : constant Integer := Top_By (Bx, By, Zr);
                              begin
                                 if Top >= 0 and then Top /= Zr
                                   and then
                                     (if Flat_On then Flat_Kind (Bx, By, Top, Zr) = To_Move
                                      else abs (Top - Zr) <= Place_Level_B
                                        and then Mat (Bx, By, Top) in Grass | Dirt | Sand | Gravel | Clay | Footpath
                                        and then (for all Z in Integer'Min (Top, Zr) + 1 .. Integer'Max (Top, Zr) + 2 =>
                                                    Class_Of (Mat (Bx, By, Z)) /= Liquid
                                                    and then Mat (Bx, By, Z) not in Trunk))
                                 then
                                    declare
                                       Was : constant Material :=
                                         (if Flat_On then Flat_Top (Mat (Bx, By, Top)) else Mat (Bx, By, Top));
                                    begin
                                       Cut_Plants (Bx, By, Top);
                                       for Z in reverse Zr + 1 .. Top loop
                                          Write_Src (Bx, By, Z, Air_Block);
                                       end loop;
                                       for Z in Top .. Zr - 1 loop
                                          Write_Src (Bx, By, Z, (Mat => Dirt, State => 0));
                                       end loop;
                                       Write_Src (Bx, By, Zr, (Mat => Was, State => 0));
                                       Moved := Moved + abs (Top - Zr);
                                    end;
                                 elsif Flat_On and then Flat_Kind (Bx, By, Top, Zr) in Flat_Waits then
                                    Waiting := True;
                                 end if;
                              end;
                           end if;
                        end;
                     end loop;
                  end loop;
                  --  (a place with a trunk still on a column of it is looked at again once the trunk is
                  --  gone: its neighbour's tree, felled and its stump taken out, leaves earth to the
                  --  height the land had.  Looked at once and never again, three block columns stood two
                  --  blocks over a stockpile made one level, and a run loaded before the felling made
                  --  them level where the straight run did not: tools/square_sites.sh, 2026-11-23.)
                  Cl.Level_Ok := not Waiting;
                  if Moved > 0 then
                     Places_Level_N := Places_Level_N + 1;
                     Place_Blocks_N := Place_Blocks_N + Moved;
                     Touched (Cl.Zone) := True;
                     Any := True;
                  end if;
               end;
            end if;
         end;
      end loop;
      if Any then
         for Z in 1 .. N_Zones loop
            if Touched (Z) then
               Read_Zone_Ground (Z);
            end if;
         end loop;
         --  (whoever stands still on a place just filled in stands on it)
         for J in 1 .. N_Members loop
            declare
               O  : Member renames Band (J);
               X  : constant Integer := B (O.Pos.X);
               Y  : constant Integer := B (O.Pos.Y);
               Zf : constant Integer := B (O.Pos.Z + 0.01);
            begin
               if not O.Is_Dead and then abs (O.Pos.X - O.Prev.X) + abs (O.Pos.Y - O.Prev.Y) < 0.001
                 and then Zone_Of_Block (X, Y) in 1 .. N_Zones and then Touched (Zone_Of_Block (X, Y))
                 and then Class_Of (Mat (X, Y, Zf)) = Solid and then Class_Of (Mat (X, Y, Zf + 1)) /= Solid
                 and then Class_Of (Mat (X, Y, Zf + 2)) /= Solid
               then
                  O.Pos.Z := Float (Zf + 1) * 0.25;
                  O.Prev := O.Pos;
               end if;
            end;
         end loop;
         if Flat_On then                       --  (and, with a stockpile one level, whatever it took: Settle_On)
            for Z in 1 .. N_Zones loop
               if Touched (Z) then
                  Settle_On (Z);
               end if;
            end loop;
         end if;
      end if;
   end Level_Places;

   --  **A stockpile is one level** (the spec, "A stockpile is one level").
   --  Flatten_Pile, where a stockpile is put down (Zone_Stockpile, Place_Box):
   --  the level is the middle one (the lower median) of the tops of its
   --  ground's block columns that have a path's column beside them, and for
   --  want of any, of all its ground's; every block column of its ground is
   --  brought to it, cut or filled, its top as it was; every place's height is
   --  that level.  Left as they lie: a column more than Flat_Most_B off the
   --  level, one with something built on top, one with water in what would
   --  be moved or beside it (a place over such a column is closed); and,
   --  until it is free, one a trunk stands on or the cart stands over
   --  (Level_Places makes the place level then, as far as it takes).
   Flat_N : Natural := 0;
   Flat_Last : Flat_Note;
   procedure Set_Pile_Flat (On : Boolean) is
   begin
      Flat_On := On;
   end Set_Pile_Flat;
   procedure Set_Steep_Refuse (On : Boolean) is
   begin
      Steep_On := On;
   end Set_Steep_Refuse;
   function Steep_Refuse return Boolean is (Steep_On);
   function Pile_Flat return Boolean is (Flat_On);
   function Piles_Flattened return Natural is (Flat_N);
   function Last_Flat return Flat_Note is (Flat_Last);
   function Last_Flat_Said return String is
      --  (metres to the quarter: 20.25)
      Q : constant Natural := Natural (Float'Rounding (Float'Max (0.0, Flat_Last.Level_M) * 100.0));
      Whole : constant String := Natural'Image (Q / 100);
      Cents : constant String := Natural'Image (100 + Q mod 100);
      Level_Said : constant String := Whole (Whole'First + 1 .. Whole'Last) & "." & Cents (Cents'Last - 1 .. Cents'Last);
   begin
      return
     ("made one level: its things lie at " & Level_Said & " m ("
      & (if Flat_Last.By_Path then "the middle of its ground beside a path"
         else "the middle of all its ground: none of it lies beside a path")
      & ");" & Flat_Last.Columns'Image & " block columns, the deepest cut" & Flat_Last.Cut_Most'Image
      & " blocks, the highest fill" & Flat_Last.Fill_Most'Image & "," & Flat_Last.Moved'Image & " blocks moved,"
      & Flat_Last.Left'Image & " columns left as they lie"
      & (if Flat_Last.Shut > 0 then "," & Flat_Last.Shut'Image & " places closed (water, or something standing there)" else "")
      & (if Flat_Last.Bushes > 0 then "," & Flat_Last.Bushes'Image & " bushes moved with their ground" else ""));
   end Last_Flat_Said;

   --  Again: it was made one level before, and what could not be moved then
   --  is looked at anew (a tree that stood in it is felled, stump and roots):
   --  at the level its places have (most of them one height, or it is no
   --  stockpile made one level and nothing is done).
   procedure Flatten_Pile (Z : Positive; Again : Boolean := False) is
      Zn : Zone_Rec renames Zones (Z);
      function Mid (K : Integer) return Float is ((Float (K) + 0.5) * 0.25);
      --  the row most of its places lie on (-1: fewer than three in four of them on one)
      function Level_Of_Places return Integer is
         Best, Best_N, Total : Integer := 0;
      begin
         for C in 1 .. N_Cells loop
            if Cells (C).Zone = Z and then not Cells (C).Overflow and then Cells (C).Fit = Ground then
               Total := Total + 1;
               declare
                  Row : constant Integer := B (Cells (C).Centre.Z + 0.01) - 1;
                  N   : Natural := 0;
               begin
                  if Row /= Best then
                     for D in 1 .. N_Cells loop
                        if Cells (D).Zone = Z and then not Cells (D).Overflow and then Cells (D).Fit = Ground
                          and then B (Cells (D).Centre.Z + 0.01) - 1 = Row
                        then
                           N := N + 1;
                        end if;
                     end loop;
                     if N > Best_N then
                        Best := Row;
                        Best_N := N;
                     end if;
                  end if;
               end;
            end if;
         end loop;
         Total := 0;
         Best_N := 0;
         for C in 1 .. N_Cells loop
            if Cells (C).Zone = Z and then not Cells (C).Overflow and then Cells (C).Fit = Ground then
               Total := Total + 1;
               if B (Cells (C).Centre.Z + 0.01) - 1 = Best then
                  Best_N := Best_N + 1;
               end if;
            end if;
         end loop;
         return (if Total > 0 and then Best_N * 4 >= Total * 3 then Best else -1);
      end Level_Of_Places;
      Level_Had : constant Integer := (if Again and then Flat_On then Level_Of_Places else -1);
   begin
      if not Flat_On or else Zn.Kind /= Stockpile_Zone or else Zn.Yard or else Zn.N = 0
        or else (Again and then Level_Had < 0)
      then
         return;
      end if;
      Measure_Zone (Z);
      declare
         --  The block columns round its ground, counted from 0, a column's margin all round.  Each
         --  is its ground, or can be reached from outside it without crossing its ground, or is an
         --  island in it: ground the zoning left out (a bush stands on it, a ledge cut it off).  An
         --  island left as it lay under a floor filled in round it is a pit a serf walks into and
         --  not out of (a gatherer starved in one, by a bush, at the square in the wood): so an
         --  island's earth is brought to the level too, and a bush on it goes with its ground.
         Gx0 : constant Integer := Zn.Bx0 - 1;
         Gy0 : constant Integer := Zn.By0 - 1;
         W   : constant Integer := Zn.Bx1 - Zn.Bx0 + 3;
         H   : constant Integer := Zn.By1 - Zn.By0 + 3;
         type Column_Is is (Unseen, Outside, Its_Ground, Island);
         type Kind_Grid is array (0 .. W - 1, 0 .. H - 1) of Column_Is;
         type Row_Grid is array (0 .. W - 1, 0 .. H - 1) of Integer;
         type Kind_Grid_Access is access Kind_Grid;
         type Row_Grid_Access is access Row_Grid;
         procedure Free is new Ada.Unchecked_Deallocation (Kind_Grid, Kind_Grid_Access);
         procedure Free is new Ada.Unchecked_Deallocation (Row_Grid, Row_Grid_Access);
         Whose : Kind_Grid_Access := new Kind_Grid'(others => (others => Unseen));
         Was   : Row_Grid_Access := new Row_Grid'(others => (others => -1));     --  each column's ground top before,
         Now   : Row_Grid_Access := new Row_Grid'(others => (others => -1));     --  and after
         Lo, Hi : Integer;
         Level  : Integer;
         Note   : Flat_Note := (Zone => Z, others => <>);
         --  the bushes lifted off it while its ground is moved: each block, and what it is
         type Lifted is record
            Bush, Index : Natural := 0;
            Bl : Block := Air_Block;
         end record;
         Max_Lifted : constant := 3_200;
         type Lifted_List is array (1 .. Max_Lifted) of Lifted;
         type Lifted_Access is access Lifted_List;
         procedure Free is new Ada.Unchecked_Deallocation (Lifted_List, Lifted_Access);
         Lift   : Lifted_Access := new Lifted_List;
         N_Lift : Natural := 0;
         function In_Grid (X, Y : Integer) return Boolean is (X - Gx0 in 0 .. W - 1 and then Y - Gy0 in 0 .. H - 1);
         --  the top of the ground at a column, looked for from well over its ground's highest
         --  (never a bush's own block: so it reads the same with the bushes on it and lifted off)
         function Top_From_Above (X, Y : Integer) return Integer is
         begin
            for Row in reverse Integer'Max (1, Lo - 2 * Flat_Most_B) .. Hi + Flat_Most_B + 2 loop
               if Is_Ground (Mat (X, Y, Row)) and then Mat (X, Y, Row) not in Berry_Bush | Bare_Bush then
                  return Row;
               end if;
            end loop;
            return -1;
         end Top_From_Above;
      begin
         --  its ground, and the rows its tops lie in
         Lo := Integer'Last;
         Hi := Integer'First;
         for K in Zn.First + 1 .. Zn.First + Zn.N loop
            for X in Integer (Runs (K).X0) .. Integer (Runs (K).X1) loop
               declare
                  Y : constant Integer := Integer (Runs (K).Y);
                  T : constant Integer := Top_By (X, Y, Integer (Runs (K).Z));
               begin
                  if In_Grid (X, Y) and then T >= 0 then
                     Whose (X - Gx0, Y - Gy0) := Its_Ground;
                     Was (X - Gx0, Y - Gy0) := T;
                     Now (X - Gx0, Y - Gy0) := T;
                     Lo := Integer'Min (Lo, T);
                     Hi := Integer'Max (Hi, T);
                  end if;
               end;
            end loop;
         end loop;
         if Lo > Hi then
            Free (Whose);
            Free (Was);
            Free (Now);
            Free (Lift);
            return;
         end if;
         --  what can be reached from outside it (its margin is outside); the rest are islands
         declare
            type Spot is record
               I, J : Integer;
            end record;
            type Spot_List is array (1 .. W * H) of Spot;
            type Spot_Access is access Spot_List;
            procedure Free is new Ada.Unchecked_Deallocation (Spot_List, Spot_Access);
            Queue : Spot_Access := new Spot_List;
            Head, Tail : Natural := 0;
            procedure Reach (I, J : Integer) is
            begin
               if I in 0 .. W - 1 and then J in 0 .. H - 1 and then Whose (I, J) = Unseen then
                  Whose (I, J) := Outside;
                  Tail := Tail + 1;
                  Queue (Tail) := (I, J);
               end if;
            end Reach;
         begin
            for I in 0 .. W - 1 loop
               Reach (I, 0);
               Reach (I, H - 1);
            end loop;
            for J in 0 .. H - 1 loop
               Reach (0, J);
               Reach (W - 1, J);
            end loop;
            while Head < Tail loop
               Head := Head + 1;
               Reach (Queue (Head).I + 1, Queue (Head).J);
               Reach (Queue (Head).I - 1, Queue (Head).J);
               Reach (Queue (Head).I, Queue (Head).J + 1);
               Reach (Queue (Head).I, Queue (Head).J - 1);
            end loop;
            Free (Queue);
         end;
         for I in 0 .. W - 1 loop
            for J in 0 .. H - 1 loop
               if Whose (I, J) = Unseen then
                  --  (not a path's, another zone's or kept for the square's wall: those are left)
                  Whose (I, J) :=
                    (if On_Path (Mid (Gx0 + I), Mid (Gy0 + J)) or else Zone_Of_Block (Gx0 + I, Gy0 + J) /= 0
                       or else Strip_Kept (Gx0 + I, Gy0 + J)
                     then Outside else Island);
               end if;
            end loop;
         end loop;
         --  (looked at anew, and nothing of it to move: nothing is touched.  It is asked every
         --  second while the cart is in tow: no bush is lifted and put back, no way found again)
         if Again then
            declare
               To_Do : Boolean := False;
            begin
               Scan :
               for I in 0 .. W - 1 loop
                  for J in 0 .. H - 1 loop
                     if Whose (I, J) in Its_Ground | Island then
                        declare
                           X : constant Integer := Gx0 + I;
                           Y : constant Integer := Gy0 + J;
                           T : constant Integer := (if Whose (I, J) = Island then Top_From_Above (X, Y) else Was (I, J));
                           K : constant Flat_Column := Flat_Kind (X, Y, T, Level_Had);
                        begin
                           if K = To_Move or else (K = At_Level and then Mat (X, Y, T) /= Flat_Top (Mat (X, Y, T))) then
                              To_Do := True;
                              exit Scan;
                           end if;
                        end;
                     end if;
                  end loop;
               end loop Scan;
               if not To_Do then
                  Free (Whose);
                  Free (Was);
                  Free (Now);
                  Free (Lift);
                  return;
               end if;
            end;
         end if;
         --  the level: the middle one of its ground's tops beside a path (the lower of two), else of all
         declare
            All_N, Front_N : array (Lo .. Hi) of Natural := [others => 0];
            N_All, N_Front : Natural := 0;
         begin
            for I in 0 .. W - 1 loop
               for J in 0 .. H - 1 loop
                  if Whose (I, J) = Its_Ground then
                     declare
                        X : constant Integer := Gx0 + I;
                        Y : constant Integer := Gy0 + J;
                     begin
                        All_N (Was (I, J)) := All_N (Was (I, J)) + 1;
                        N_All := N_All + 1;
                        if On_Path (Mid (X + 1), Mid (Y)) or else On_Path (Mid (X - 1), Mid (Y))
                          or else On_Path (Mid (X), Mid (Y + 1)) or else On_Path (Mid (X), Mid (Y - 1))
                        then
                           Front_N (Was (I, J)) := Front_N (Was (I, J)) + 1;
                           N_Front := N_Front + 1;
                        end if;
                     end;
                  end if;
               end loop;
            end loop;
            declare
               Want : constant Natural := ((if N_Front > 0 then N_Front else N_All) + 1) / 2;
               Seen : Natural := 0;
            begin
               Level := Lo;
               for Row in Lo .. Hi loop
                  Seen := Seen + (if N_Front > 0 then Front_N (Row) else All_N (Row));
                  if Seen >= Want then
                     Level := Row;
                     exit;
                  end if;
               end loop;
            end;
            if Again then
               Level := Level_Had;
            end if;
            Note.By_Path := N_Front > 0;
            Note.Level_M := Float (Level + 1) * 0.25;
            Note.Columns := N_All;
         end;
         --  (its bushes are to be known first: a stack is looked through for them some ticks after
         --  the stake is put, and a stockpile put down with the stake came before that: a bush not
         --  yet known stood where it was while the floor was filled in round it, in a pit)
         if Version_Src /= null then
            for SX in Integer (Float'Floor (Float (Gx0 - 8) * 0.25 / 8.0)) .. Integer (Float'Floor (Float (Gx0 + W + 8) * 0.25 / 8.0)) loop
               for SY in Integer (Float'Floor (Float (Gy0 - 8) * 0.25 / 8.0)) .. Integer (Float'Floor (Float (Gy0 + H + 8) * 0.25 / 8.0)) loop
                  if SX in Indexed_Grid'Range (1) and then SY in Indexed_Grid'Range (2)
                    and then (not Indexed (SX, SY) or else Indexed_Far (SX, SY)) and then Own_V (SX, SY) > 0
                  then
                     Index_Stack (SX, SY);
                  end if;
               end loop;
            end loop;
         end if;
         --  the bushes that stand on it or on an island of it, lifted off
         for K in 1 .. N_Bushes loop
            if Bushes (K).N > 0
              and then (for some I in 1 .. Bushes (K).N =>
                          In_Grid (Integer (Bushes (K).Blocks (I).X), Integer (Bushes (K).Blocks (I).Y))
                          and then Whose (Integer (Bushes (K).Blocks (I).X) - Gx0,
                                          Integer (Bushes (K).Blocks (I).Y) - Gy0) in Its_Ground | Island)
              and then N_Lift + Bushes (K).N <= Max_Lifted
            then
               for I in 1 .. Bushes (K).N loop
                  declare
                     P : Block_Pos renames Bushes (K).Blocks (I);
                  begin
                     N_Lift := N_Lift + 1;
                     Lift (N_Lift) := (K, I, Read_Src (Integer (P.X), Integer (P.Y), Integer (P.Z)));
                     Write_Src (Integer (P.X), Integer (P.Y), Integer (P.Z), Air_Block);
                  end;
               end loop;
               Note.Bushes := Note.Bushes + 1;
            end if;
         end loop;
         --  the islands' ground as it lies (read with the bushes off it)
         for I in 0 .. W - 1 loop
            for J in 0 .. H - 1 loop
               if Whose (I, J) = Island then
                  Was (I, J) := Top_From_Above (Gx0 + I, Gy0 + J);
                  Now (I, J) := Was (I, J);
               end if;
            end loop;
         end loop;
         --  its ground, and its islands', brought to the level
         for I in 0 .. W - 1 loop
            for J in 0 .. H - 1 loop
               if Whose (I, J) in Its_Ground | Island then
                  declare
                     X : constant Integer := Gx0 + I;
                     Y : constant Integer := Gy0 + J;
                     T : constant Integer := Was (I, J);
                  begin
                     case Flat_Kind (X, Y, T, Level) is
                        when At_Level =>
                           --  (a boulder whose top lies at the level: no block of it in the floor's
                           --  top either.  Left there, the band prised it out from the stockpile's
                           --  edge inwards: eight block columns of a floor stood three blocks low
                           --  on its twelfth day, at the square at 1172 1092)
                           if Mat (X, Y, T) /= Flat_Top (Mat (X, Y, T)) then
                              Write_Src (X, Y, T, (Mat => Flat_Top (Mat (X, Y, T)), State => 0));
                           end if;
                        when Flat_Never | Flat_Waits =>
                           if Whose (I, J) = Its_Ground then
                              Note.Left := Note.Left + 1;
                           end if;
                        when To_Move =>
                           declare
                              Top_Was : constant Material := Flat_Top (Mat (X, Y, T));
                           begin
                              Cut_Plants (X, Y, T);
                              for Row in reverse Level + 1 .. T loop
                                 Write_Src (X, Y, Row, Air_Block);
                              end loop;
                              for Row in T .. Level - 1 loop
                                 Write_Src (X, Y, Row, (Mat => Dirt, State => 0));
                              end loop;
                              Write_Src (X, Y, Level, (Mat => Top_Was, State => 0));
                              --  (where the floor comes up under a tree's leaves they are lopped as
                              --  high as a serf stands: else the place under them is no place to walk)
                              if Level > T then
                                 for Row in Level + 1 .. Level + Castle.Nav.Head_B loop
                                    if Mat (X, Y, Row) in Crown then
                                       Write_Src (X, Y, Row, Air_Block);
                                    end if;
                                 end loop;
                              end if;
                              Now (I, J) := Level;
                              Note.Cut_Most := Natural'Max (Note.Cut_Most, Integer'Max (0, T - Level));
                              Note.Fill_Most := Natural'Max (Note.Fill_Most, Integer'Max (0, Level - T));
                              Note.Moved := Note.Moved + abs (T - Level);
                           end;
                     end case;
                  end;
               end if;
            end loop;
         end loop;
         --  the bushes put back, each block as far up or down as the ground of its own column went
         for L in 1 .. N_Lift loop
            declare
               P  : Block_Pos renames Bushes (Lift (L).Bush).Blocks (Lift (L).Index);
               X  : constant Integer := Integer (P.X);
               Y  : constant Integer := Integer (P.Y);
               Dz : constant Integer :=
                 (if In_Grid (X, Y) and then Whose (X - Gx0, Y - Gy0) in Its_Ground | Island
                  then Now (X - Gx0, Y - Gy0) - Was (X - Gx0, Y - Gy0) else 0);
            begin
               P.Z := Integer_16 (Integer (P.Z) + Dz);
               if Mat (X, Y, Integer (P.Z)) in Air | Tall_Grass | Wild_Grain | Wild_Vegetables then
                  Write_Src (X, Y, Integer (P.Z), Lift (L).Bl);
               end if;
            end;
         end loop;
         for K in 1 .. N_Bushes loop
            if Bushes (K).N > 0 and then (for some L in 1 .. N_Lift => Lift (L).Bush = K) then
               declare
                  X : constant Integer := B (Bushes (K).Centre.X);
                  Y : constant Integer := B (Bushes (K).Centre.Y);
               begin
                  if In_Grid (X, Y) and then Whose (X - Gx0, Y - Gy0) in Its_Ground | Island
                    and then Now (X - Gx0, Y - Gy0) >= 0
                  then
                     Bushes (K).Centre.Z := Float (Now (X - Gx0, Y - Gy0) + 1) * 0.25;
                  end if;
               end;
            end if;
         end loop;
         --  its places at that height; one with a column in it that is never moved (rock, water)
         --  is a place no more: nothing is put half on a boulder (Cell_In_Rock keeps it closed)
         for C in 1 .. N_Cells loop
            declare
               Cl : Cell renames Cells (C);
               Cs : constant Float := Cos (Cl.Turn);
               Sn : constant Float := Sin (Cl.Turn);
               Own : Boolean := False;       --  a column of it is never moved
               Done : Boolean := True;       --  all of its square metre is at the level
            begin
               if Cl.Zone = Z and then not Cl.Overflow and then Cl.Fit = Ground then
                  for Bx in B (Cl.Centre.X - 0.75) .. B (Cl.Centre.X + 0.75) loop
                     for By in B (Cl.Centre.Y - 0.75) .. B (Cl.Centre.Y + 0.75) loop
                        declare
                           Dx : constant Float := (Float (Bx) + 0.5) * 0.25 - Cl.Centre.X;
                           Dy : constant Float := (Float (By) + 0.5) * 0.25 - Cl.Centre.Y;
                        begin
                           if abs (Dx * Cs + Dy * Sn) < 0.5 and then abs (Dy * Cs - Dx * Sn) < 0.5
                             and then In_Grid (Bx, By) and then Whose (Bx - Gx0, By - Gy0) = Its_Ground
                           then
                              case Flat_Kind (Bx, By, Now (Bx - Gx0, By - Gy0), Level) is
                                 when At_Level => null;
                                 when Flat_Never => Own := True;
                                 when Flat_Waits | To_Move => Done := False;
                              end case;
                           end if;
                        end;
                     end loop;
                  end loop;
                  Cl.Centre.Z := Float (Level + 1) * 0.25;
                  Cl.Level_Ok := Done;
                  if Own and then not Cl.Closed then
                     Cl.Closed := True;
                     Note.Shut := Note.Shut + 1;
                  end if;
               end if;
            end;
         end loop;
         Read_Zone_Ground (Z);
         Settle_On (Z);
         --  (and whoever stands on an island of it that was moved)
         for M of Band (1 .. N_Members) loop
            if not M.Is_Dead and then In_Grid (B (M.Pos.X), B (M.Pos.Y))
              and then Whose (B (M.Pos.X) - Gx0, B (M.Pos.Y) - Gy0) = Island
              and then Now (B (M.Pos.X) - Gx0, B (M.Pos.Y) - Gy0) /= Was (B (M.Pos.X) - Gx0, B (M.Pos.Y) - Gy0)
            then
               M.Pos.Z := Float (Now (B (M.Pos.X) - Gx0, B (M.Pos.Y) - Gy0) + 1) * 0.25;
               M.Prev.Z := M.Pos.Z;
            end if;
         end loop;
         if not Again then
            Flat_N := Flat_N + 1;
            Flat_Last := Note;
         end if;
         Free (Whose);
         Free (Was);
         Free (Now);
         Free (Lift);
      end;
   end Flatten_Pile;

   --  A stockpile ordered removed (Remove_Stockpile) is gone when it is
   --  empty: nothing lies on its places, nothing is on its way to them or
   --  set aside on them, and nobody's errand names one.  Its strips out of
   --  the list (as Read_Zone_Ground takes them out), its places out of
   --  theirs, and whoever holds a place's number after them told the new
   --  number (a member's two; a fail memo of a place).  Once a colony second.
   Removed_N : Natural := 0;
   type Removal_Refused_For is (Removal_Ok, No_Stockpile, Is_The_Yard);
   Remove_Refused : Removal_Refused_For := Removal_Ok;
   function Stockpiles_Removed return Natural is (Removed_N);
   procedure Drop_Emptied is
   begin
      for Z in 1 .. N_Zones loop
         if Zones (Z).Kind = Stockpile_Zone and then Zones (Z).Leaving then
            declare
               Lo : Natural := 0;
               Hi : Natural := 0;
               Busy : Boolean := False;
            begin
               for C in 1 .. N_Cells loop
                  if Cells (C).Zone = Z then
                     Lo := (if Lo = 0 then C else Lo);
                     Hi := C;
                     Cells (C).Closed := True;
                     Busy := Busy or else Cells (C).Count > 0 or else Cells (C).Incoming > 0 or else Cells (C).Outgoing > 0;
                  end if;
               end loop;
               for I in 1 .. N_Members loop
                  Busy := Busy or else (not Band (I).Is_Dead and then Lo > 0
                                        and then (Band (I).Cell in Lo .. Hi or else Band (I).Cell2 in Lo .. Hi));
               end loop;
               --  (its places lie together: they were made together, and no place is ever moved but here)
               if not Busy and then (Lo = 0 or else (for all C in Lo .. Hi => Cells (C).Zone = Z)) then
                  if Lo > 0 then
                     declare
                        Gone : constant Positive := Hi - Lo + 1;
                     begin
                        for C in Hi + 1 .. N_Cells loop
                           Cells (C - Gone) := Cells (C);
                        end loop;
                        N_Cells := N_Cells - Gone;
                        for I in 1 .. N_Members loop
                           declare
                              M : Member renames Band (I);
                           begin
                              if M.Cell in Lo .. Hi then
                                 M.Cell := 0;
                              elsif M.Cell > Hi then
                                 M.Cell := M.Cell - Gone;
                              end if;
                              if M.Cell2 in Lo .. Hi then
                                 M.Cell2 := 0;
                              elsif M.Cell2 > Hi then
                                 M.Cell2 := M.Cell2 - Gone;
                              end if;
                              for F of M.Fails loop
                                 if F.Bush in Cell_Base + Lo .. Cell_Base + Hi then
                                    F := (others => <>);
                                 elsif F.Bush in Cell_Base + Hi + 1 .. Cell_Base + Max_Cells then
                                    F.Bush := F.Bush - Gone;
                                 end if;
                              end loop;
                           end;
                        end loop;
                     end;
                  end if;
                  declare
                     Old : constant Natural := Zones (Z).N;
                  begin
                     for K in Zones (Z).First + Old + 1 .. N_Runs loop
                        Runs (K - Old) := Runs (K);
                     end loop;
                     for Zn in 1 .. N_Zones loop
                        if Zones (Zn).First > Zones (Z).First then
                           Zones (Zn).First := Zones (Zn).First - Old;
                        end if;
                     end loop;
                     N_Runs := N_Runs - Old;
                  end;
                  Zones (Z) := (Kind => Stockpile_Zone, First => N_Runs, others => <>);
                  Removed_N := Removed_N + 1;
                  Zones_Ver := Zones_Ver + 1;
                  Box_Trees_At := Natural'Last;
               end if;
            end;
         end if;
      end loop;
   end Drop_Emptied;

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
      M.Build_First := False;   --  (set to building: lifted by any job given)
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

   procedure Place_Stake (Ground : Vec3; Band_Size : Positive; Seed : U64; Post : Boolean := True;
                          As_Read : Boolean := False) is separate;

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

   --  Paths straight or at 45 degrees (the spec, Path_Line_Start).
   function Block_Corner (V : Float) return Float is (Float'Rounding (V * 4.0) * 0.25);
   function At_Corner (V : Float) return Boolean is (abs (V - Block_Corner (V)) < 1.0E-3);
   --  The ground's height at a point of a planned line (as a stretch's joint has it).
   --  **Under a tree, the ground under it** (Line_Ground_On; Set_Line_Ground): the walking map's
   --  first floor there is the highest, a bough, and a line's end given that height was a stretch
   --  whose metres near that end look for their ground four and five metres up and find none (a
   --  metre of path is looked for within four metres under the stretch's own height there): never
   --  counted, never laid.  So where what is stood on there is no ground (nothing of its cell's four
   --  block columns is ground at that row), the height is that of the highest ground under it, read
   --  as a site's is (Top_By); beside a trunk's foot, the ground beside it.
   Line_Ground_On : Boolean := True;
   function Line_Point (X, Y, Else_Z : Float) return Vec3 is
      Z : constant Float := Castle.Nav.Surface_Z (X, Y);
   begin
      if Z >= 0.0 and then Line_Ground_On then
         declare
            Cx : constant Integer := 2 * Integer (Float'Floor (X * 2.0));       --  (its cell's four block columns)
            Cy : constant Integer := 2 * Integer (Float'Floor (Y * 2.0));
            Zb : constant Integer := Integer (Float'Rounding (Z * 4.0)) - 1;     --  (the row stood on)
            Open, Roots : Integer := -1;
         begin
            if not (for some Dx in 0 .. 1 => (for some Dy in 0 .. 1 => Is_Ground (Mat (Cx + Dx, Cy + Dy, Zb)))) then
               for Dx in 0 .. 1 loop
                  for Dy in 0 .. 1 loop
                     declare
                        Zn : constant Integer := Top_By (Cx + Dx, Cy + Dy, Zb);
                     begin
                        if Zn >= 0 and then Mat (Cx + Dx, Cy + Dy, Zn + 1) not in Trunk then
                           Open := Integer'Max (Open, Zn);
                        elsif Zn >= 0 then
                           Roots := Integer'Max (Roots, Zn + 2);     --  (a trunk is rooted two blocks into the ground)
                        end if;
                     end;
                  end loop;
               end loop;
               if Open >= 0 or else Roots >= 0 then
                  return (X, Y, Float ((if Open >= 0 then Open else Roots) + 1) * 0.25);
               end if;
            end if;
         end;
      end if;
      return (X, Y, (if Z >= 0.0 then Z else Else_Z));
   end Line_Point;
   procedure Set_Line_Ground (On : Boolean) is
   begin
      Line_Ground_On := On;
   end Set_Line_Ground;
   function Line_Ground return Boolean is (Line_Ground_On);
   --  Which way a stretch lies, if it lies one of the eight ways with its
   --  middle line through corners of blocks: Sx, Sy in -1 .. 1, a block a
   --  step (0, 0: it does not).
   procedure Grid_Way (S : Path_Seg; Sx, Sy : out Integer) is
      Dx : constant Float := S.B.X - S.A.X;
      Dy : constant Float := S.B.Y - S.A.Y;
      function Sign (V : Float) return Integer is (if V > 0.0 then 1 elsif V < 0.0 then -1 else 0);
   begin
      Sx := 0;
      Sy := 0;
      if abs (Dx) < 0.1 and then abs (Dy) < 0.1 then
         null;
      elsif abs (Dy) < 1.0E-3 then
         if At_Corner (S.A.Y) then
            Sx := Sign (Dx);
         end if;
      elsif abs (Dx) < 1.0E-3 then
         if At_Corner (S.A.X) then
            Sy := Sign (Dy);
         end if;
      elsif abs (abs (Dx) - abs (Dy)) < 1.0E-3
        and then At_Corner (S.A.Y - Float (Sign (Dx) * Sign (Dy)) * S.A.X)
      then
         Sx := Sign (Dx);
         Sy := Sign (Dy);
      end if;
   end Grid_Way;

   function Path_Line_Start (P : Vec3) return Vec3 is
      C      : Vec3 := (Block_Corner (P.X), Block_Corner (P.Y), P.Z);
      Best   : Natural := 0;
      Best_D : Float := Path_Width_M / 2.0;
      Sx, Sy : Integer;
   begin
      --  the end of a path already (a line going on from where the last ended)
      for K in 1 .. N_Paths loop
         for E of Vec3_Pair'(Path_List (K).A, Path_List (K).B) loop
            if abs (E.X - P.X) < 1.0E-3 and then abs (E.Y - P.Y) < 1.0E-3 then
               return (E.X, E.Y, (if E.Z >= 0.0 then E.Z else P.Z));
            end if;
         end loop;
      end loop;
      --  on a path that lies one of the eight ways: the corner on its middle line
      for K in 1 .. N_Paths loop
         Grid_Way (Path_List (K), Sx, Sy);
         if (Sx /= 0 or else Sy /= 0) and then Seg_Dist (P, Path_List (K)) <= Best_D then
            Best := K;
            Best_D := Seg_Dist (P, Path_List (K));
         end if;
      end loop;
      if Best > 0 then
         declare
            S  : Path_Seg renames Path_List (Best);
            Dx : constant Float := S.B.X - S.A.X;
            Dy : constant Float := S.B.Y - S.A.Y;
            T  : constant Float :=
              Float'Max (0.0, Float'Min (1.0, ((P.X - S.A.X) * Dx + (P.Y - S.A.Y) * Dy) / (Dx * Dx + Dy * Dy)));
         begin
            Grid_Way (S, Sx, Sy);
            if Sy = 0 then
               C := (Block_Corner (S.A.X + Dx * T), Block_Corner (S.A.Y), P.Z);
            elsif Sx = 0 then
               C := (Block_Corner (S.A.X), Block_Corner (S.A.Y + Dy * T), P.Z);
            else
               C.X := Block_Corner (S.A.X + Dx * T);
               C.Y := Float (Sx * Sy) * C.X + Block_Corner (S.A.Y - Float (Sx * Sy) * S.A.X);
            end if;
         end;
      end if;
      --  and the end of a path near that, if it is on a corner itself
      declare
         Near   : Vec3 := C;
         Near_D : Float := Path_Width_M;
      begin
         for K in 1 .. N_Paths loop
            for E of Vec3_Pair'(Path_List (K).A, Path_List (K).B) loop
               if At_Corner (E.X) and then At_Corner (E.Y) and then Flat_Dist (E, C) <= Near_D then
                  Near_D := Flat_Dist (E, C);
                  Near := (Block_Corner (E.X), Block_Corner (E.Y), P.Z);
               end if;
            end loop;
         end loop;
         return Line_Point (Near.X, Near.Y, P.Z);
      end;
   end Path_Line_Start;

   function Path_Line_End (From, P : Vec3) return Vec3 is
      Dx : constant Float := P.X - From.X;
      Dy : constant Float := P.Y - From.Y;
      Tan_Half : constant := 0.414_213_56;       --  (the tangent of 22.5 degrees: half way between two of the eight)
      Ux : constant Integer := (if abs (Dx) <= Tan_Half * abs (Dy) then 0 elsif Dx > 0.0 then 1 else -1);
      Uy : constant Integer := (if abs (Dy) <= Tan_Half * abs (Dx) then 0 elsif Dy > 0.0 then 1 else -1);
      N  : Integer;
      function At_Step (K : Integer) return Vec3 is
        ((From.X + Float (K * Ux) * 0.25, From.Y + Float (K * Uy) * 0.25, 0.0));
   begin
      --  (pointed at where it begins, or nearly: no line.  A click twice on one spot lays no stub.)
      if Dx * Dx + Dy * Dy < Path_Line_Least_M ** 2 then
         return From;
      end if;
      --  as near P as a whole number of blocks along that way comes
      N := Integer'Max (2, Integer (Float'Rounding
                                      ((Dx * Float (Ux) + Dy * Float (Uy)) / Float (Ux * Ux + Uy * Uy) * 4.0)));
      --  up to a path it comes to: to the crossing of the two middle lines
      declare
         E      : constant Vec3 := At_Step (N);
         Best_D : Float := Path_Width_M + 0.01;
         Sx, Sy : Integer;
      begin
         for K in 1 .. N_Paths loop
            Grid_Way (Path_List (K), Sx, Sy);
            if (Sx /= 0 or else Sy /= 0) and then Ux * Sy - Uy * Sx /= 0
              and then Seg_Dist (E, Path_List (K)) <= Path_Width_M
            then
               declare
                  S : Path_Seg renames Path_List (K);
                  --  From + T (Ux, Uy) = S.A + V (Sx, Sy), T in metres along a block's step
                  T : constant Float :=
                    ((S.A.X - From.X) * Float (Sy) - (S.A.Y - From.Y) * Float (Sx)) / Float (Ux * Sy - Uy * Sx);
                  M : constant Integer := Integer (Float'Rounding (T * 4.0));
               begin
                  if M >= 2 and then Seg_Dist (At_Step (M), S) <= 0.2 and then Flat_Dist (At_Step (M), E) < Best_D then
                     Best_D := Flat_Dist (At_Step (M), E);
                     N := M;
                  end if;
               end;
            end if;
         end loop;
      end;
      return Line_Point (At_Step (N).X, At_Step (N).Y,
                         (if P.Z >= 0.0 then P.Z else From.Z));
   end Path_Line_End;

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

   type Path_Refused is (Laid_Some, Nothing_There, Through_Zone, No_More, Through_Cart, Through_Lot);
   Path_Refused_For : Path_Refused := Laid_Some;

   function Path_Refusal return String is
     (case Path_Refused_For is
         when Laid_Some     => "",
         when Nothing_There => "there is no ground there to lay a path on",
         when Through_Zone  => "a zone is in the way: paths go round zones",
         when No_More       => "there are as many paths as there can be",
         when Through_Cart  => "the lord's cart is in the way: it cannot be moved yet",
         when Through_Lot   => "a hovel's lot is in the way: a path goes through housing only where nothing is built");

   --  Planned, a path is kept as stretches of Path_Stretch_M, the last what
   --  is left (and up to a metre over, not a sliver of its own): how many a
   --  line L long is, and piece P of them.  Where a piece ends is on the
   --  ground there if that is in (else at no height yet: it is given one
   --  when it is).
   function Line_Pieces (L : Float) return Positive is
     (if Labour_On then Positive'Max (1, Natural (Float'Ceiling ((L - 1.0) / Path_Stretch_M))) else 1);
   function Line_Piece (From, To : Vec3; P, Pieces : Positive) return Path_Seg is
      L : constant Float := Flat_Dist (From, To);
      function Joint (T : Float) return Vec3 is
         X : constant Float := From.X + (To.X - From.X) * T;
         Y : constant Float := From.Y + (To.Y - From.Y) * T;
         Z : constant Float := Castle.Nav.Surface_Z (X, Y);
      begin
         return (X, Y, (if Z >= 0.0 then Z elsif From.Z >= 0.0 and then To.Z >= 0.0
                        then From.Z + (To.Z - From.Z) * T else -1.0));
      end Joint;
   begin
      return (A => (if P = 1 then From else Joint (Float (P - 1) * Path_Stretch_M / L)),
              B => (if P = Pieces then To else Joint (Float (P) * Path_Stretch_M / L)), others => <>);
   end Line_Piece;

   procedure Lay_Path (From, To : Vec3; Laid : out Natural) is separate;

   procedure For_Path_Left (K : Positive; Visit : not null access procedure (X, Y, Zr : Integer)) is
      procedure Each (X, Y, Zr, Metre : Integer) is
      begin
         if (Path_List (K).Todo and Shift_Left (Unsigned_64'(1), Integer'Min (63, Metre - 1))) /= 0 then
            Visit (X, Y, Zr);
         end if;
      end Each;
   begin
      if K <= N_Paths and then Path_List (K).Known and then Path_List (K).Todo /= 0
        and then Path_List (K).A.Z >= 0.0 and then Path_List (K).B.Z >= 0.0
      then
         For_Path_Work (Path_List (K), Each'Access);
      end if;
   end For_Path_Left;

   procedure For_Path_Line (From, To : Vec3; Visit : not null access procedure (X, Y, Zr : Integer)) is
      L : constant Float := Flat_Dist (From, To);
      procedure Each (X, Y, Zr, Metre : Integer) is
         pragma Unreferenced (Metre);
      begin
         Visit (X, Y, Zr);
      end Each;
   begin
      if L < 0.25 then
         return;
      end if;
      for P in 1 .. Line_Pieces (L) loop
         declare
            S : constant Path_Seg := Line_Piece (From, To, P, Line_Pieces (L));
         begin
            if Stretch_In (S, Held => True) and then S.A.Z >= 0.0 and then S.B.Z >= 0.0 then
               For_Path_Work (S, Each'Access);
            end if;
         end;
      end loop;
   end For_Path_Line;

   function Paths_Left_Key return Natural is
      H : U64 := U64 (N_Paths);
   begin
      for K in 1 .. N_Paths loop
         H := Castle.Hash.Mix (H + U64 (Path_List (K).Todo) + (if Path_List (K).Known then 1 else 0));
      end loop;
      return Natural (H mod 2 ** 30);
   end Paths_Left_Key;

   ------------------------------------------------------------------ zones: laying out a lot

   --  A lot as planned: the ground it would fill and, for a stockpile, the
   --  places it would get.  Worked out by Plan_Lot, with nothing changed;
   --  a zoning takes the plan it has just made.
   type Lot_Refusal is (Lot_Ok, Off_Path, No_Ground, Too_Large, No_Room, Too_Small, One_Only, Too_Steep);
   Steep_Said : constant String :=
     "the ground is too steep for a stockpile there (some of it rises more than half a metre in a metre)";
   type Plan_Runs_Array is array (1 .. Max_Plan_Runs) of Run_Rec;
   type Plan_Cells_Array is array (1 .. Max_Cells) of Vec3;
   Plan_Run     : Plan_Runs_Array;
   Plan_N       : Natural := 0;
   Plan_Blocks  : Natural := 0;
   Plan_Cell    : Plan_Cells_Array;
   Plan_Cells_N : Natural := 0;
   Plan_Over_N  : Natural := 0;           --  of those, the last so many are its overflow's
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
         when No_Room   => "there is no room for another",
         when Too_Small => "it is too small (a stockpile is at least" & Integer'Image (Integer (Least_M)) & " m by"
                           & Integer'Image (Integer (Least_M)) & " m)",
         when One_Only  => "the stockpile is placed once, and it is placed",
         when Too_Steep => Steep_Said);

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
   --  ground and within half a metre of level.  Least: its ground reaches
   --  that far along and across, or it is refused (Too_Small).  Overflow:
   --  up to that many places more just outside the rectangle, for its
   --  overflow (the last Plan_Over_N of the places), their ground the
   --  lot's.  Clear_All: whatever stands on its ground is to be cleared, so
   --  the ground under it is its own too; with Keep_Feet all but a tree's
   --  foot, which is left out of it.  One_Level: its ground is to be made
   --  one level (a stockpile's, with Set_Pile_Flat), so a place lies on it
   --  however it falls under the place.  Fell_Trees (a lot that is not cleared
   --  otherwise): a tree's foot is its ground too, the tree to be felled,
   --  and a place may lie over it.  Into the plan.
   procedure Plan_Lot
     (Ex, Ey             : Float;
      Ra0, Ra1, Rb0, Rb1 : Float;
      Seed               : Vec3;
      Step_B             : Natural;
      Places             : Boolean;
      Ia0, Ia1, Ib0, Ib1 : Integer := 0;
      Least              : Float := 0.0;
      Overflow           : Natural := 0;
      Clear_All          : Boolean := False;
      One_Level          : Boolean := False;
      Steep_B            : Natural := 0;
      Oa, Ob             : Float := 0.0;
      Drawn_Out          : Boolean := True;
      Keep_Feet          : Boolean := False;
      Fell_Trees         : Boolean := False) is separate;

   --  The camp's zone has a place kept for it: stockpiles take all but one.
   function Zone_Room return Boolean is (N_Zones < Max_Zones - (if Camp_Set then 0 else 1));

   --  The plan for a stockpile between two corners (X0, Y0: where it was begun).
   procedure Plan_Stockpile_Lot (X0, Y0, X1, Y1 : Float) is separate;

   function Plan_View return Lot_Plan is
     ((Ok => Plan_Refused = Lot_Ok, Corner => Plan_Corner, Turn => Plan_Turn, Cells => Plan_Cells_N - Plan_Over_N,
       Overflow => Plan_Over_N, Blocks => Plan_Blocks));

   function Plan_Stockpile (X0, Y0, X1, Y1 : Float) return Lot_Plan is
   begin
      Plan_Stockpile_Lot (X0, Y0, X1, Y1);
      return Plan_View;
   end Plan_Stockpile;

   function Stockpile_Count return Natural is
      N : Natural := 0;
   begin
      for Z in 1 .. N_Zones loop
         if Zones (Z).Kind = Stockpile_Zone and then not Zones (Z).Yard and then Zones (Z).N > 0 then
            N := N + 1;                              --  (the stockyard is not one; nor one removed)
         end if;
      end loop;
      return N;
   end Stockpile_Count;

   --  The square the player's stockpile is placed on at (X, Y): beside the
   --  path nearest the point (within Square_Snap_M of its middle), on the
   --  point's side of it, its front on the path's edge, Stockpile_Side_M
   --  along the path with the point across from its middle, and as far
   --  back; on the whole metres of the lot's way, so that it is that many
   --  places each way.  C0: its corner on the path, C1 the far one (a hair
   --  inside each).
   procedure Square_Of (X, Y : Float; C0, C1 : out Vec3; Ok : out Boolean) is
      P      : constant Vec3 := (X, Y, 0.0);
      Half   : constant Float := Path_Width_M / 2.0;
      Side_M : constant Float := Stockpile_Side_M;
      Best   : Natural := 0;
      Best_D : Float := Float'Last;
   begin
      Ok := False;
      C0 := P;
      C1 := P;
      for K in 1 .. N_Paths loop
         if Seg_Dist (P, Path_List (K)) < Best_D then
            Best_D := Seg_Dist (P, Path_List (K));
            Best := K;
         end if;
      end loop;
      if Best = 0 or else Best_D > Square_Snap_M then
         return;
      end if;
      declare
         S  : Path_Seg renames Path_List (Best);
         Dx : constant Float := S.B.X - S.A.X;
         Dy : constant Float := S.B.Y - S.A.Y;
         L  : constant Float := Sqrt (Dx * Dx + Dy * Dy);
      begin
         if L < 0.01 then
            return;
         end if;
         declare
            Tx : constant Float := Dx / L;
            Ty : constant Float := Dy / L;
            T  : constant Float := Float'Max (0.0, Float'Min (L, (X - S.A.X) * Tx + (Y - S.A.Y) * Ty));
            Qx : constant Float := S.A.X + Tx * T;
            Qy : constant Float := S.A.Y + Ty * T;
            Sd : constant Float := (if (X - Qx) * (-Ty) + (Y - Qy) * Tx >= 0.0 then 1.0 else -1.0);
            Nx : constant Float := -Ty * Sd;
            Ny : constant Float := Tx * Sd;
            Ex, Ey, Gap : Float;
         begin
            Way_Of_Path ((Qx, Qy, 0.0), (X, Y, 0.0), Ex, Ey, Gap);
            declare
               function Fa (Px, Py : Float) return Float is (Px * Ex + Py * Ey);
               function Fb (Px, Py : Float) return Float is (Py * Ex - Px * Ey);
               function Wx (A, B : Float) return Float is (A * Ex - B * Ey);
               function Wy (A, B : Float) return Float is (A * Ey + B * Ex);
               --  across the path: the lot's a or its b, whichever the way out from the path is along
               Across_A : constant Boolean := abs Fa (Nx, Ny) >= abs Fb (Nx, Ny);
               Out_Sign : constant Float := (if Across_A then Fa (Nx, Ny) else Fb (Nx, Ny));
               Edge_X   : constant Float := Qx + Nx * Half;
               Edge_Y   : constant Float := Qy + Ny * Half;
               E_Across : constant Float := (if Across_A then Fa (Edge_X, Edge_Y) else Fb (Edge_X, Edge_Y));
               Mid      : constant Float := (if Across_A then Fb (X, Y) else Fa (X, Y));
               Lo_Along : constant Float := Float'Rounding (Mid - Side_M / 2.0);
               Front, Back : Float;          --  across: the side on the path, the far side
               A0, B0, A1, B1 : Float;
            begin
               if Out_Sign >= 0.0 then
                  Front := Float'Ceiling (E_Across - 0.05);
                  Back := Front + Side_M;
               else
                  Front := Float'Floor (E_Across + 0.05);
                  Back := Front - Side_M;
               end if;
               --  a hair inside each corner
               declare
                  F_In : constant Float := Front + (if Out_Sign >= 0.0 then 0.01 else -0.01);
                  B_In : constant Float := Back - (if Out_Sign >= 0.0 then 0.01 else -0.01);
               begin
                  if Across_A then
                     A0 := F_In;
                     A1 := B_In;
                     B0 := Lo_Along + 0.01;
                     B1 := Lo_Along + Side_M - 0.01;
                  else
                     B0 := F_In;
                     B1 := B_In;
                     A0 := Lo_Along + 0.01;
                     A1 := Lo_Along + Side_M - 0.01;
                  end if;
               end;
               C0 := (Wx (A0, B0), Wy (A0, B0), 0.0);
               C1 := (Wx (A1, B1), Wy (A1, B1), 0.0);
               Ok := True;
            end;
         end;
      end;
   end Square_Of;

   function Plan_Stockpile_At (X, Y : Float) return Lot_Plan is
      C0, C1 : Vec3;
      Ok     : Boolean;
   begin
      if One_Pile_On and then Stockpile_Count > 0 then
         Plan_Refused := One_Only;
         Plan_N := 0;
         Plan_Corner := [others => (X, Y, 0.0)];
         return Plan_View;
      end if;
      Square_Of (X, Y, C0, C1, Ok);
      if not Ok then
         Plan_Refused := Off_Path;
         Plan_N := 0;
         Plan_Corner := [(X - 5.0, Y - 5.0, 0.0), (X + 5.0, Y - 5.0, 0.0), (X + 5.0, Y + 5.0, 0.0), (X - 5.0, Y + 5.0, 0.0)];
         return Plan_View;
      end if;
      Plan_Stockpile_Lot (C0.X, C0.Y, C1.X, C1.Y);
      return Plan_View;
   end Plan_Stockpile_At;

   procedure Place_Stockpile (X, Y : Float; Cells : out Natural) is
      C0, C1 : Vec3;
      Ok     : Boolean;
   begin
      Cells := 0;
      if One_Pile_On and then Stockpile_Count > 0 then
         Plan_Refused := One_Only;
         return;
      end if;
      Square_Of (X, Y, C0, C1, Ok);
      if not Ok then
         Plan_Refused := Off_Path;
         return;
      end if;
      Zone_Stockpile (C0.X, C0.Y, C1.X, C1.Y, Cells);
   end Place_Stockpile;

   --  The plan for a stockyard between two corners: a lot square to the
   --  block grid on the whole metres the corners span, its side nearest a
   --  path drawn out toward it as far as Yard_Snap_M (the fill stops at the
   --  path: beside a path aslant, the ground between is the yard's staging).
   Yard_Refused : Lot_Refusal := Lot_Ok;
   Yard_Steep   : Boolean := False;       --  the last was refused for how its ground lies (no storehouse could stand)
   Yard_Turn_On : Boolean := True;
   procedure Set_Yard_Turn (On : Boolean) is
   begin
      Yard_Turn_On := On;
   end Set_Yard_Turn;
   function Yard_Turn return Boolean is (Yard_Turn_On);
   procedure Plan_Stockyard_Lot (X0, Y0, X1, Y1 : Float) is
      Ia0 : constant Integer := Integer (Float'Floor (Float'Min (X0, X1)));
      Ia1 : constant Integer := Integer (Float'Ceiling (Float'Max (X0, X1))) - 1;
      Ib0 : constant Integer := Integer (Float'Floor (Float'Min (Y0, Y1)));
      Ib1 : constant Integer := Integer (Float'Ceiling (Float'Max (Y0, Y1))) - 1;
      procedure Nothing_Planned is
      begin
         Plan_N := 0;
         Plan_Blocks := 0;
         Plan_Cells_N := 0;
         Plan_Over_N := 0;
         Plan_Under_N := 0;
      end Nothing_Planned;
      function To_Path (X, Y : Float) return Float is
         D : Float := Float'Last;
      begin
         for K in 1 .. N_Paths loop
            D := Float'Min (D, Seg_Dist ((X, Y, 0.0), Path_List (K)));
         end loop;
         return D;
      end To_Path;
      Ex, Ey, Gap : Float;
   begin
      --  **Beside a path at 45 degrees it is laid out along the path** (John,
      --  2026-11-20: "go on with the second way for the stockyard"; Set_Yard_Turn):
      --  the whole metres its corners span along and across the path's way, as
      --  a stockpile's lot is, its places turned with it; all of it has to be
      --  taken, as of a square one.
      Way_Of_Path ((X0, Y0, 0.0), (X1, Y1, 0.0), Ex, Ey, Gap);
      if Yard_Turn_On and then Yard_Level_On and then Stockyard = 0 and then abs (abs Ey - 0.707_106_78) < 0.02 then
         declare
            A0 : constant Float := X0 * Ex + Y0 * Ey;
            A1 : constant Float := X1 * Ex + Y1 * Ey;
            B0 : constant Float := Y0 * Ex - X0 * Ey;
            B1 : constant Float := Y1 * Ex - X1 * Ey;
            Ja0 : constant Integer := Integer (Float'Floor (Float'Min (A0, A1)));
            Ja1 : constant Integer := Integer (Float'Ceiling (Float'Max (A0, A1))) - 1;
            Jb0 : constant Integer := Integer (Float'Floor (Float'Min (B0, B1)));
            Jb1 : constant Integer := Integer (Float'Ceiling (Float'Max (B0, B1))) - 1;
            Am  : constant Float := Float (Ja0 + Ja1 + 1) / 2.0;
            Bm  : constant Float := Float (Jb0 + Jb1 + 1) / 2.0;
            function Corner (A, Bb : Integer) return Vec3 is
              ((Float (A) * Ex - Float (Bb) * Ey, Float (A) * Ey + Float (Bb) * Ex, 0.0));
         begin
            if Float (Ja1 - Ja0 + 1) > Stockyard_Most_M or else Float (Jb1 - Jb0 + 1) > Stockyard_Most_M then
               Plan_Turn := Arctan (Ey, Ex);
               Plan_Refused := Too_Large;
               Nothing_Planned;
            else
               Plan_Lot (Ex, Ey, Float (Ja0), Float (Ja1 + 1), Float (Jb0), Float (Jb1 + 1),
                         Seed => (Am * Ex - Bm * Ey, Am * Ey + Bm * Ex, 0.0),
                         Step_B => Integer (CB.Max_Step_B) + 4, Places => True,
                         Ia0 => Ja0, Ia1 => Ja1, Ib0 => Jb0, Ib1 => Jb1, Least => Stockyard_Least_M, Clear_All => True);
               if Plan_Refused /= Too_Large then
                  if not Plan_At_Path then
                     Plan_Refused := Off_Path;
                  elsif Plan_Refused = Lot_Ok and then not Zone_Room then
                     Plan_Refused := No_Room;
                  elsif Plan_Refused = Lot_Ok and then Plan_Cells_N < (Ja1 - Ja0 + 1) * (Jb1 - Jb0 + 1) then
                     Plan_Refused := No_Ground;
                  end if;
               end if;
               if Plan_Refused /= Lot_Ok then
                  Nothing_Planned;
               end if;
            end if;
            Plan_Corner := [Corner (Ja0, Jb0), Corner (Ja1 + 1, Jb0), Corner (Ja1 + 1, Jb1 + 1), Corner (Ja0, Jb1 + 1)];
            Yard_Refused := Plan_Refused;
            return;
         end;
      end if;
      Plan_Turn := 0.0;
      Plan_Corner := [(Float (Ia0), Float (Ib0), 0.0), (Float (Ia1 + 1), Float (Ib0), 0.0),
                      (Float (Ia1 + 1), Float (Ib1 + 1), 0.0), (Float (Ia0), Float (Ib1 + 1), 0.0)];
      if Stockyard > 0 then
         Plan_Refused := One_Only;
         Nothing_Planned;
      elsif Float (Ia1 - Ia0 + 1) > Stockyard_Most_M or else Float (Ib1 - Ib0 + 1) > Stockyard_Most_M then
         Plan_Refused := Too_Large;
         Nothing_Planned;
      else
         declare
            Xm  : constant Float := Float (Ia0 + Ia1 + 1) / 2.0;
            Ym  : constant Float := Float (Ib0 + Ib1 + 1) / 2.0;
            D_S : constant Float := To_Path (Xm, Float (Ib0));
            D_N : constant Float := To_Path (Xm, Float (Ib1 + 1));
            D_W : constant Float := To_Path (Float (Ia0), Ym);
            D_E : constant Float := To_Path (Float (Ia1 + 1), Ym);
            Least_D : constant Float := Float'Min (Float'Min (D_S, D_N), Float'Min (D_W, D_E));
            Out_M : constant Float := Yard_Snap_M;
            Ra0 : constant Float := Float (Ia0) - (if D_W = Least_D and then D_S /= Least_D and then D_N /= Least_D
                                                   then Out_M else 0.0);
            Ra1 : constant Float := Float (Ia1 + 1) + (if D_E = Least_D and then D_S /= Least_D and then D_N /= Least_D
                                                       and then D_W /= Least_D then Out_M else 0.0);
            Rb0 : constant Float := Float (Ib0) - (if D_S = Least_D then Out_M else 0.0);
            Rb1 : constant Float := Float (Ib1 + 1) + (if D_N = Least_D and then D_S /= Least_D then Out_M else 0.0);
         begin
            Plan_Lot (1.0, 0.0, Ra0, Ra1, Rb0, Rb1,
                      Seed => ((Float (Ia0 + Ia1 + 1)) / 2.0, (Float (Ib0 + Ib1 + 1)) / 2.0, 0.0),
                      Step_B => (if Yard_Level_On then Integer (CB.Max_Step_B) + 4 else Integer (Zone_Step_M * 4.0)),
                      Places => True, Ia0 => Ia0, Ia1 => Ia1, Ib0 => Ib0, Ib1 => Ib1, Least => Stockyard_Least_M,
                      Clear_All => Yard_Level_On);
            Plan_Corner := [(Float (Ia0), Float (Ib0), 0.0), (Float (Ia1 + 1), Float (Ib0), 0.0),
                            (Float (Ia1 + 1), Float (Ib1 + 1), 0.0), (Float (Ia0), Float (Ib1 + 1), 0.0)];
            if Plan_Refused /= Too_Large then
               --  (the lot itself has to come within a metre of the path somewhere along its front: the
               --  ground drawn out is for a path aslant, not for a yard set back from its path)
               if not Plan_At_Path
                 or else not (for some K in 0 .. 4 * Integer'Max (Ia1 - Ia0 + 1, Ib1 - Ib0 + 1) =>
                                To_Path ((if D_S = Least_D or else D_N = Least_D
                                          then Float'Min (Float (Ia0) + 0.25 * Float (K), Float (Ia1 + 1)) else
                                          (if D_W = Least_D then Float (Ia0) else Float (Ia1 + 1))),
                                         (if D_S = Least_D then Float (Ib0) elsif D_N = Least_D then Float (Ib1 + 1)
                                          else Float'Min (Float (Ib0) + 0.25 * Float (K), Float (Ib1 + 1))))
                                <= Path_Width_M / 2.0 + Snap_M)
               then
                  Plan_Refused := Off_Path;
               elsif Plan_Refused = Lot_Ok and then not Zone_Room then
                  Plan_Refused := No_Room;
               elsif Plan_Refused = Lot_Ok and then Yard_Level_On
                 and then Plan_Cells_N < (Ia1 - Ia0 + 1) * (Ib1 - Ib0 + 1)
               then
                  Plan_Refused := No_Ground;       --  (water, a path across it, a ledge: a stockyard is all of its lot)
               end if;
            end if;
            if Plan_Refused /= Lot_Ok then
               Nothing_Planned;
            end if;
         end;
      end if;
      Yard_Refused := Plan_Refused;
   end Plan_Stockyard_Lot;

   function Plan_Stockyard (X0, Y0, X1, Y1 : Float) return Lot_Plan is
   begin
      Plan_Stockyard_Lot (X0, Y0, X1, Y1);
      return Plan_View;
   end Plan_Stockyard;

   function Stockyard_Refusal return String is
     (if Yard_Steep
      then "its ground will not take the storehouse: it falls more than 3 m, or lies more than 2 m off its path"
      else
      (case Yard_Refused is
         when Lot_Ok    => "",
         when Off_Path  => "a stockyard has to come within a metre of a path",
         when No_Ground => "that ground cannot all be taken (water, a path, another zone or a ledge on it)",
         when Too_Large => "it is too large (" & Integer'Image (Integer (Stockyard_Most_M)) & " m a side at most)",
         when No_Room   => "there is no room for another zone",
         when Too_Small => "it is too small (a stockyard is at least" & Integer'Image (Integer (Stockyard_Least_M))
                           & " m by" & Integer'Image (Integer (Stockyard_Least_M)) & " m)",
         when One_Only  => "the stockyard is placed once, and it is placed",
         when Too_Steep => Steep_Said));


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
            --  (the whole of each plant; with the band's labour off, the camp standing at once as it did,
            --  the block over the ground alone, as it was: the three oldest reference logs go by it)
            if Labour_On then
               Cut_Plants (X, Integer (Plan_Run (K).Y), Integer (Plan_Run (K).Z));
            elsif Mat (X, Integer (Plan_Run (K).Y), Integer (Plan_Run (K).Z) + 1) /= Air then
               Write_Src (X, Integer (Plan_Run (K).Y), Integer (Plan_Run (K).Z) + 1, Air_Block);
            end if;
         end loop;
      end loop;
   end Clear_Plan;

   --  What grows on the planned places is cut, so what is put there can be
   --  seen; the rest of a stockpile's ground keeps its grass.
   --  (the whole of each plant: long grass two blocks high had its lower block cut and its upper left
   --  in the air over the place, John's "grass in the air ... Even before compacting", 2026-11-17)
   procedure Clear_Places is
   begin
      for K in 1 .. Plan_Under_N loop
         Cut_Plants (Integer (Plan_Under (K).X), Integer (Plan_Under (K).Y), Integer (Plan_Under (K).Z));
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

   ------------------------------------------------------------------ placements

   --  A zone put down whole, with its path (the spec, "placements").
   function Box_Side_M (Kind : Box_Kind) return Float is
     (case Kind is when Stockpile_Box => Stockpile_Side_M, when Stockyard_Box => Stockyard_Side_M);

   Way_Dx : constant array (Way_Index) of Integer := [1, 1, 0, -1, -1, -1, 0, 1];
   Way_Dy : constant array (Way_Index) of Integer := [0, 1, 1, 1, 0, -1, -1, -1];

   --  Blocks of path along a box's front: its side along a straight way; along
   --  a slanting one the least whole number that is not shorter.
   function Box_Along_B (Kind : Box_Kind; Way : Way_Index) return Natural is
      S4 : constant Float := Box_Side_M (Kind) * 4.0;
   begin
      return (if Way mod 2 = 0 then Natural (S4) else Natural (Float'Ceiling (S4 / Sqrt (2.0) - 0.001)));
   end Box_Along_B;

   --  A box as it lies: where its front begins on its path's middle line (Ox,
   --  Oy: a corner of blocks), the way along it and the way to its left
   --  (units), how long its front is and how deep it lies.  A point's place
   --  in it: U along from the front's beginning, V out from the path's
   --  middle line (the box is V from half a path to that and its depth).
   type Box_Frame is record
      Ox, Oy : Float := 0.0;
      Ux, Uy : Float := 1.0;
      Nx, Ny : Float := 0.0;
      L, Side : Float := 0.0;
   end record;
   function Frame_Of (Kind : Box_Kind; Way : Way_Index; Ox, Oy : Float) return Box_Frame is
      Dx  : constant Float := Float (Way_Dx (Way));
      Dy  : constant Float := Float (Way_Dy (Way));
      Len : constant Float := Sqrt (Dx * Dx + Dy * Dy);
   begin
      return (Ox => Ox, Oy => Oy, Ux => Dx / Len, Uy => Dy / Len, Nx => -Dy / Len, Ny => Dx / Len,
              L => Float (Box_Along_B (Kind, Way)) * 0.25 * Len, Side => Box_Side_M (Kind));
   end Frame_Of;
   function Box_U (F : Box_Frame; X, Y : Float) return Float is ((X - F.Ox) * F.Ux + (Y - F.Oy) * F.Uy);
   function Box_V (F : Box_Frame; X, Y : Float) return Float is ((X - F.Ox) * F.Nx + (Y - F.Oy) * F.Ny);

   --  Every block column whose middle lies in a box from U0 to U1 along it,
   --  In_M within its edges.  Turned aslant, a box's two ends run through
   --  the middles of blocks: such a column is the box's at its beginning
   --  and not at its end (Box_Edge_M: the ends are taken a centimetre back
   --  along it), so that a box begun where another ends has what the other
   --  leaves, and the sum never decides it.
   Box_Edge_M : constant := 0.01;
   procedure For_Box_Columns
     (F : Box_Frame; U0, U1, In_M : Float; Visit : not null access procedure (Bx, By : Integer; Stop : in out Boolean))
   is
      Half : constant Float := Path_Width_M / 2.0;
      Xs   : constant array (1 .. 4) of Float :=
        [F.Ox + U0 * F.Ux + Half * F.Nx, F.Ox + U1 * F.Ux + Half * F.Nx,
         F.Ox + U1 * F.Ux + (Half + F.Side) * F.Nx, F.Ox + U0 * F.Ux + (Half + F.Side) * F.Nx];
      Ys   : constant array (1 .. 4) of Float :=
        [F.Oy + U0 * F.Uy + Half * F.Ny, F.Oy + U1 * F.Uy + Half * F.Ny,
         F.Oy + U1 * F.Uy + (Half + F.Side) * F.Ny, F.Oy + U0 * F.Uy + (Half + F.Side) * F.Ny];
      Stop : Boolean := False;
   begin
      for Bx in B (Float'Min (Float'Min (Xs (1), Xs (2)), Float'Min (Xs (3), Xs (4))))
        .. B (Float'Max (Float'Max (Xs (1), Xs (2)), Float'Max (Xs (3), Xs (4))))
      loop
         for By in B (Float'Min (Float'Min (Ys (1), Ys (2)), Float'Min (Ys (3), Ys (4))))
           .. B (Float'Max (Float'Max (Ys (1), Ys (2)), Float'Max (Ys (3), Ys (4))))
         loop
            declare
               X : constant Float := (Float (Bx) + 0.5) * 0.25;
               Y : constant Float := (Float (By) + 0.5) * 0.25;
               U : constant Float := Box_U (F, X, Y);
               V : constant Float := Box_V (F, X, Y);
            begin
               if U >= U0 - Box_Edge_M + In_M and then U < U1 - Box_Edge_M - In_M
                 and then V >= Half + In_M and then V < Half + F.Side - In_M
               then
                  Visit (Bx, By, Stop);
                  if Stop then
                     return;
                  end if;
               end if;
            end;
         end loop;
      end loop;
   end For_Box_Columns;

   --  A path that lies one of the eight ways on the corners of blocks, as a
   --  line: which way (Sx, Sy: a block a step), and where it is.  A corner
   --  of blocks on it is given by one whole number, Step: its X in blocks
   --  (its Y, for a path that runs north and south); the stretch itself
   --  reaches from Lo to Hi of that (not whole numbers at a joint between
   --  two stretches of one long slanting path: Line_Piece).
   type Grid_Line is record
      Sx, Sy : Integer := 0;
      Fixed  : Float := 0.0;      --  its Y (east and west), its X (north and south), its Y where X is nought (aslant)
      Lo, Hi : Float := 0.0;
   end record;
   function Line_Of (S : Path_Seg) return Grid_Line is
      G : Grid_Line;
   begin
      Grid_Way (S, G.Sx, G.Sy);
      if G.Sx = 0 and then G.Sy = 0 then
         return G;
      elsif G.Sy = 0 then
         G.Fixed := Block_Corner (S.A.Y);
      elsif G.Sx = 0 then
         G.Fixed := Block_Corner (S.A.X);
      else
         G.Fixed := Block_Corner (S.A.Y - Float (G.Sx * G.Sy) * S.A.X);
      end if;
      if G.Sx = 0 then
         G.Lo := Float'Min (S.A.Y, S.B.Y) * 4.0;
         G.Hi := Float'Max (S.A.Y, S.B.Y) * 4.0;
      else
         G.Lo := Float'Min (S.A.X, S.B.X) * 4.0;
         G.Hi := Float'Max (S.A.X, S.B.X) * 4.0;
      end if;
      return G;
   end Line_Of;
   --  (the corner of blocks at Step of it, and the step of the corner of it nearest a point)
   procedure Line_At (G : Grid_Line; Step : Integer; X, Y : out Float) is
   begin
      if G.Sx = 0 then
         X := G.Fixed;
         Y := Float (Step) * 0.25;
      elsif G.Sy = 0 then
         X := Float (Step) * 0.25;
         Y := G.Fixed;
      else
         X := Float (Step) * 0.25;
         Y := Float (G.Sx * G.Sy) * X + G.Fixed;
      end if;
   end Line_At;
   function Line_Step (G : Grid_Line; X, Y : Float) return Integer is
   begin
      if G.Sx = 0 then
         return Integer (Float'Rounding (Y * 4.0));
      elsif G.Sy = 0 then
         return Integer (Float'Rounding (X * 4.0));
      else
         --  (the foot of the point on the line: half way between its own X and the X the line has at its Y)
         return Integer (Float'Rounding ((X + Float (G.Sx * G.Sy) * (Y - G.Fixed)) * 2.0));
      end if;
   end Line_Step;
   --  (how far a point lies off it, to one side or the other; metres)
   function Line_Off (G : Grid_Line; X, Y : Float) return Float is
     (if G.Sx = 0 then G.Fixed - X
      elsif G.Sy = 0 then Y - G.Fixed
      else (Y - Float (G.Sx * G.Sy) * X - G.Fixed) / Sqrt (2.0));

   function Box_Middle (P : Placement) return Vec3 is
      F : constant Box_Frame := Frame_Of (P.Kind, P.Way, P.Front.X, P.Front.Y);
      H : constant Float := Path_Width_M / 2.0 + F.Side / 2.0;
   begin
      return (F.Ox + F.Ux * F.L / 2.0 + F.Nx * H, F.Oy + F.Uy * F.L / 2.0 + F.Ny * H, P.Front.Z);
   end Box_Middle;

   function Box_At (Kind : Box_Kind; Middle : Vec3; Way : Way_Index) return Placement is
      Half : constant Float := Path_Width_M / 2.0;
      Dx   : constant Integer := Way_Dx (Way);
      Dy   : constant Integer := Way_Dy (Way);
      N    : constant Natural := Box_Along_B (Kind, Way);
      F0   : constant Box_Frame := Frame_Of (Kind, Way, 0.0, 0.0);
      --  where its front would begin, held free
      Fx   : constant Float := Middle.X - F0.Nx * (Half + F0.Side / 2.0) - F0.Ux * F0.L / 2.0;
      Fy   : constant Float := Middle.Y - F0.Ny * (Half + F0.Side / 2.0) - F0.Uy * F0.L / 2.0;
      Ex   : constant Float := Fx + Float (N * Dx) * 0.25;      --  and end
      Ey   : constant Float := Fy + Float (N * Dy) * 0.25;
      --  the best so far: where the front begins, how many blocks its path
      --  runs on before it and after it (to a path it meets), how far that
      --  is from where it is held
      Best_X  : Float := Block_Corner (Fx);
      Best_Y  : Float := Block_Corner (Fy);
      Best_D  : Float := Float'Last;
      Best_S  : Box_Snap := Free;
      Best_Before, Best_After : Natural := 0;

      procedure Offer (X, Y : Float; S : Box_Snap; Before, After : Natural := 0) is
         D : constant Float := Sqrt ((X - Fx) ** 2 + (Y - Fy) ** 2);
      begin
         if D < Best_D - 1.0E-3 then
            Best_D := D;
            Best_X := X;
            Best_Y := Y;
            Best_S := S;
            Best_Before := Before;
            Best_After := After;
         end if;
      end Offer;

      --  An end of stretch K (its lower along its line, or its upper) is where
      --  it joins another stretch of the same line: not an end of a path.
      function Joint (K : Positive; At_Lo : Boolean) return Boolean is
         G  : constant Grid_Line := Line_Of (Path_List (K));
         At_S : constant Float := (if At_Lo then G.Lo else G.Hi);
      begin
         for J in 1 .. N_Paths loop
            if J /= K then
               declare
                  H : constant Grid_Line := Line_Of (Path_List (J));
               begin
                  if (H.Sx /= 0 or else H.Sy /= 0) and then H.Sx * G.Sy - H.Sy * G.Sx = 0
                    and then abs (H.Fixed - G.Fixed) < 1.0E-3
                    and then (abs (H.Lo - At_S) < 0.02 or else abs (H.Hi - At_S) < 0.02)
                  then
                     return True;
                  end if;
               end;
            end if;
         end loop;
         return False;
      end Joint;

      --  The least number of blocks a box whose path meets a path at (Jx, Jy)
      --  has to begin beyond there (At_Start), or end short of there, to
      --  have none of its ground by that end on a path: 0 .. 3, or 2 where
      --  none will do (it is refused for the path through it).
      function Clear_Of (Jx, Jy : Float; At_Start : Boolean) return Natural is
      begin
         for Off in 0 .. 3 loop
            declare
               Fr : constant Box_Frame :=
                 Frame_Of (Kind, Way,
                           (if At_Start then Jx + Float (Off * Dx) * 0.25 else Jx - Float ((Off + N) * Dx) * 0.25),
                           (if At_Start then Jy + Float (Off * Dy) * 0.25 else Jy - Float ((Off + N) * Dy) * 0.25));
               Hit : Boolean := False;
               procedure Look (Bx, By : Integer; Stop : in out Boolean) is
               begin
                  if Near_Path ((Float (Bx) + 0.5) * 0.25, (Float (By) + 0.5) * 0.25, 0.0) then
                     Hit := True;
                     Stop := True;
                  end if;
               end Look;
            begin
               --  (the two metres of it by that end: a path that runs on into it is found by the plan)
               For_Box_Columns (Fr, (if At_Start then 0.0 else Fr.L - 2.0), (if At_Start then 2.0 else Fr.L), 0.0,
                                Look'Access);
               if not Hit then
                  return Off;
               end if;
            end;
         end loop;
         return 2;
      end Clear_Of;
   begin
      for K in 1 .. N_Paths loop
         declare
            S : Path_Seg renames Path_List (K);
            G : constant Grid_Line := Line_Of (S);
         begin
            if G.Sx = 0 and then G.Sy = 0 then
               null;                               --  (a path that lies on no corners draws nothing)
            elsif Dx * G.Sy - Dy * G.Sx = 0 then
               --  along it: its front put on that path's line
               declare
                  Off  : constant Float := Line_Off (G, Fx, Fy);
                  --  a step of the line is a block of path when the box runs the way the line is counted
                  --  (toward greater X, or north along a path that runs north and south), else a block back
                  Dir  : constant Integer := (if G.Sx = 0 then Dy else Dx);
                  T0   : Integer := Line_Step (G, Fx, Fy);
                  T_Lo : constant Integer := Integer'Min (T0, T0 + N * Dir);
                  T_Hi : constant Integer := Integer'Max (T0, T0 + N * Dir);
                  Step_M : constant Float := (if G.Sx /= 0 and then G.Sy /= 0 then 0.25 * Sqrt (2.0) else 0.25);
                  Snap_B : constant Float := Float (Box_Snap_M) / Step_M;
                  Shift  : Integer := 0;
                  Shift_D : Float := Float'Last;
                  procedure Try (By_Steps : Float) is
                  begin
                     if abs By_Steps <= Snap_B and then abs By_Steps < Shift_D
                       and then abs (By_Steps - Float'Rounding (By_Steps)) < 0.01      --  (an end on a corner)
                     then
                        Shift_D := abs By_Steps;
                        Shift := Integer (Float'Rounding (By_Steps));
                     end if;
                  end Try;
                  X, Y : Float;
               begin
                  if abs Off <= Half + F0.Side / 2.0
                    and then Float (T_Lo) <= G.Hi + Snap_B and then Float (T_Hi) >= G.Lo - Snap_B
                  then
                     --  an end of it at an end of that path: flush with it, or going on from it (an end, not
                     --  where one stretch of a long path joins the next)
                     if not Joint (K, At_Lo => True) then
                        Try (G.Lo - Float (T_Lo));
                        Try (G.Lo - Float (T_Hi));
                     end if;
                     if not Joint (K, At_Lo => False) then
                        Try (G.Hi - Float (T_Hi));
                        Try (G.Hi - Float (T_Lo));
                     end if;
                     --  or at an end of a box put down along that line already: against it, or level with
                     --  it across the path
                     for Z in 1 .. N_Zones loop
                        if Zones (Z).Placed then
                           declare
                              Zx : constant Float := Float (Zones (Z).Fx) * 0.25;
                              Zy : constant Float := Float (Zones (Z).Fy) * 0.25;
                              Zs : constant Path_Seg :=
                                (A => (Zx, Zy, 0.0),
                                 B => (Zx + Float (Zones (Z).Along_B * Way_Dx (Zones (Z).Way)) * 0.25,
                                       Zy + Float (Zones (Z).Along_B * Way_Dy (Zones (Z).Way)) * 0.25, 0.0),
                                 others => <>);
                              Zg : constant Grid_Line := Line_Of (Zs);
                           begin
                              if (Zg.Sx /= 0 or else Zg.Sy /= 0) and then Zg.Sx * G.Sy - Zg.Sy * G.Sx = 0
                                and then abs (Zg.Fixed - G.Fixed) < 1.0E-3
                              then
                                 Try (Zg.Hi - Float (T_Lo));
                                 Try (Zg.Lo - Float (T_Hi));
                                 Try (Zg.Lo - Float (T_Lo));
                                 Try (Zg.Hi - Float (T_Hi));
                              end if;
                           end;
                        end if;
                     end loop;
                     T0 := T0 + Shift;
                     Line_At (G, T0, X, Y);
                     Offer (X, Y, Along_Path);
                  end if;
               end;
            else
               --  another way: an end of its front at an end of that path, or on its line
               for At_Start in Boolean loop
                  declare
                     Px : constant Float := (if At_Start then Fx else Ex);
                     Py : constant Float := (if At_Start then Fy else Ey);
                     procedure Meet (Jx, Jy : Float; Snap : Box_Snap) is
                        Off : constant Natural := Clear_Of (Jx, Jy, At_Start);
                     begin
                        if At_Start then
                           Offer (Jx + Float (Off * Dx) * 0.25, Jy + Float (Off * Dy) * 0.25, Snap, Before => Off);
                        else
                           Offer (Jx - Float ((Off + N) * Dx) * 0.25, Jy - Float ((Off + N) * Dy) * 0.25, Snap,
                                  After => Off);
                        end if;
                     end Meet;
                     Ended : Boolean := False;
                  begin
                     for E of Vec3_Pair'(S.A, S.B) loop
                        if At_Corner (E.X) and then At_Corner (E.Y)
                          and then Sqrt ((E.X - Px) ** 2 + (E.Y - Py) ** 2) <= Float (Box_Snap_M)
                        then
                           Meet (Block_Corner (E.X), Block_Corner (E.Y), At_End);
                           Ended := True;
                        end if;
                     end loop;
                     if not Ended and then Seg_Dist ((Px, Py, 0.0), S) <= Float (Box_Snap_M) then
                        --  where its own line crosses that path's line (not the foot of its end on it: held
                        --  again where it was put, its line crosses at the same corner), the corner nearest
                        declare
                           Ax, Ay : Float;
                        begin
                           Line_At (G, Integer (Float'Rounding ((G.Lo + G.Hi) / 2.0)), Ax, Ay);
                           declare
                              Along : constant Float :=
                                ((Ax - Px) * Float (G.Sy) - (Ay - Py) * Float (G.Sx)) / Float (Dx * G.Sy - Dy * G.Sx);
                              T : constant Integer :=
                                Integer'Max (Integer (Float'Ceiling (G.Lo - 0.01)),
                                             Integer'Min (Integer (Float'Floor (G.Hi + 0.01)),
                                                          Line_Step (G, Px + Along * Float (Dx), Py + Along * Float (Dy))));
                              X, Y : Float;
                           begin
                              Line_At (G, T, X, Y);
                              Meet (X, Y, At_Middle);
                           end;
                        end;
                     end if;
                  end;
               end loop;
            end if;
         end;
      end loop;
      declare
         Fr : constant Box_Frame := Frame_Of (Kind, Way, Best_X, Best_Y);
         P  : Placement;
         function On (U, V : Float) return Vec3 is ((Fr.Ox + U * Fr.Ux + V * Fr.Nx, Fr.Oy + U * Fr.Uy + V * Fr.Ny, 0.0));
         Z0 : constant Float := Castle.Nav.Surface_Z (Best_X - Float (Best_Before * Dx) * 0.25,
                                                     Best_Y - Float (Best_Before * Dy) * 0.25);
         Z1 : constant Float := Castle.Nav.Surface_Z (Best_X + Float ((N + Best_After) * Dx) * 0.25,
                                                     Best_Y + Float ((N + Best_After) * Dy) * 0.25);
      begin
         P.Kind := Kind;
         P.Way := Way;
         P.Along_B := N;
         P.Snap := Best_S;
         P.Ok := Z0 >= 0.0 and then Z1 >= 0.0;
         P.Front := (Best_X, Best_Y, (if Z0 >= 0.0 then Z0 else Middle.Z));
         P.From := (Best_X - Float (Best_Before * Dx) * 0.25, Best_Y - Float (Best_Before * Dy) * 0.25,
                    (if Z0 >= 0.0 then Z0 else Middle.Z));
         P.To := (Best_X + Float ((N + Best_After) * Dx) * 0.25, Best_Y + Float ((N + Best_After) * Dy) * 0.25,
                  (if Z1 >= 0.0 then Z1 else Middle.Z));
         P.Corner := [On (0.0, Half), On (Fr.L, Half), On (Fr.L, Half + Fr.Side), On (0.0, Half + Fr.Side)];
         return P;
      end;
   end Box_At;

   --  Why a box was refused.
   type Box_Refused_For is
     (Box_Ok, No_Ground_There, Path_In_Zone, Path_In_Cart, No_More_Paths, Over_A_Zone, Over_A_Path, No_Places,
      No_More_Zones, Yard_Is_Placed, Not_All_Ground, No_Storehouse, Over_The_Cart, Too_Steep_There);
   Box_Refused   : Box_Refused_For := Box_Ok;
   Box_Over_Kind : Zone_Kind := Stockpile_Zone;      --  (Over_A_Zone: what kind of zone)
   Box_Over_Yard : Boolean := False;

   function Box_Refusal return String is
     (case Box_Refused is
         when Box_Ok          => "",
         when No_Ground_There => "there is no ground there for its path",
         when Path_In_Zone    => "a zone is in the way of its path",
         when Path_In_Cart    => "the lord's cart is in the way of its path",
         when No_More_Paths   => "there are as many paths as there can be",
         when Over_A_Zone     =>
           "it overlaps " & (case Box_Over_Kind is
                                when Stockpile_Zone  => (if Box_Over_Yard then "the stockyard" else "a stockpile"),
                                when Camp_Zone       => "the camp",
                                when Habitation_Zone => "housing"),
         when Over_A_Path     => "it overlaps a path",
         when No_Places       => "there is no clear ground there to put things on",
         when No_More_Zones   => "there is no room for another zone",
         when Yard_Is_Placed  => "the stockyard is placed once, and it is placed",
         when Not_All_Ground  => "that ground cannot all be taken (water, a ledge or something standing on it)",
         when Over_The_Cart   => "the lord's cart stands on it",
         when Too_Steep_There => Steep_Said,
         when No_Storehouse   =>
           --  (its floor at its path's level at the lower corner of its front: how far the land lies off
           --  the path no longer refuses one)
           (if Yard_Level_On and then Yard_Corner_On and then Yard_Low_On
            then "its ground will not take the storehouse: it falls more than 3 m from end to end"
            else "its ground will not take the storehouse: it falls more than 3 m, or lies too far off its path's level"));

   --  The parts of a box's path that no path lies along yet, in blocks from
   --  its beginning (From): those of 0 .. Total not covered by a stretch on
   --  the same line.
   Max_Box_Gaps : constant := 8;
   type Box_Gap is record
      A, B : Natural := 0;
   end record;
   type Box_Gaps is array (1 .. Max_Box_Gaps) of Box_Gap;
   --  (Line_Gaps: of any line that lies Way from a corner of blocks to one.)
   procedure Line_Gaps (From, To : Vec3; Way : Way_Index; Total : out Natural; Gaps : out Box_Gaps;
                        N_Gaps : out Natural)
   is
      Dx : constant Integer := Way_Dx (Way);
      Dy : constant Integer := Way_Dy (Way);
      Step_M : constant Float := (if Dx /= 0 and then Dy /= 0 then 0.25 * Sqrt (2.0) else 0.25);
      Mine : constant Path_Seg := (A => From, B => To, others => <>);
      G_Mine : constant Grid_Line := Line_Of (Mine);
      Covered : array (0 .. 511) of Boolean := [others => False];     --  (block K .. K + 1 of it)
   begin
      Total := Natural (Float'Rounding (Flat_Dist (From, To) / Step_M));
      Gaps := [others => <>];
      N_Gaps := 0;
      if Total > Covered'Last then
         Total := Covered'Last;
      end if;
      for K in 1 .. N_Paths loop
         declare
            G : constant Grid_Line := Line_Of (Path_List (K));
         begin
            if (G.Sx /= 0 or else G.Sy /= 0) and then Dx * G.Sy - Dy * G.Sx = 0
              and then abs (G.Fixed - G_Mine.Fixed) < 1.0E-3
            then
               --  on my line: from which of my blocks to which (a step of the line is a block of mine, or one back)
               declare
                  Dir : constant Integer := (if G.Sx = 0 then Dy else Dx);
                  T0  : constant Float := Float (Line_Step (G, From.X, From.Y));
                  A   : constant Float := (if Dir > 0 then G.Lo - T0 else T0 - G.Hi);
                  Z   : constant Float := (if Dir > 0 then G.Hi - T0 else T0 - G.Lo);
               begin
                  --  (a block by its middle: at a joint between two stretches of one path it is one's or
                  --  the other's)
                  for I in 0 .. Total - 1 loop
                     if Float (I) + 0.5 >= A - 0.01 and then Float (I) + 0.5 <= Z + 0.01 then
                        Covered (I) := True;
                     end if;
                  end loop;
               end;
            end if;
         end;
      end loop;
      declare
         I : Natural := 0;
      begin
         while I < Total loop
            if not Covered (I) then
               declare
                  J : Natural := I;
               begin
                  while J + 1 < Total and then not Covered (J + 1) loop
                     J := J + 1;
                  end loop;
                  if N_Gaps < Max_Box_Gaps then
                     N_Gaps := N_Gaps + 1;
                     Gaps (N_Gaps) := (I, J + 1);
                  end if;
                  I := J + 1;
               end;
            else
               I := I + 1;
            end if;
         end loop;
      end;
   end Line_Gaps;
   procedure Path_Gaps (P : Placement; Total : out Natural; Gaps : out Box_Gaps; N_Gaps : out Natural) is
   begin
      Line_Gaps (P.From, P.To, P.Way, Total, Gaps, N_Gaps);
   end Path_Gaps;

   --  The planned ground as the grid a house's place is tried on (Lot_Grid_Of_Zone's, of a zone
   --  that is not there yet).
   procedure Lot_Grid_Of_Plan is
      Bx0, By0 : Integer := Integer'Last;
      Bx1, By1 : Integer := Integer'First;
   begin
      for K in 1 .. Plan_N loop
         Bx0 := Integer'Min (Bx0, Integer (Plan_Run (K).X0));
         Bx1 := Integer'Max (Bx1, Integer (Plan_Run (K).X1));
         By0 := Integer'Min (By0, Integer (Plan_Run (K).Y));
         By1 := Integer'Max (By1, Integer (Plan_Run (K).Y));
      end loop;
      Lot_Open (Bx0, By0, Bx1, By1);
      for K in 1 .. Plan_N loop
         Lot_Run (Plan_Run (K));
      end loop;
      for H in 1 .. N_Houses loop
         Lot_Take (Houses (H).F);
      end loop;
      for K in 1 .. N_Lots loop
         Lot_Take (Lots (K).F);
      end loop;
   end Lot_Grid_Of_Plan;

   --  Whether the storehouse could stand on the stockyard just planned for box P (its own path
   --  taken as lying there): the very trial Place_Storehouse makes of the zone once it is there,
   --  on the same bounds, read from the plan's places as that reads them from the zone's.
   procedure Try_Store_On_Plan (P : Placement; Stands : out Boolean) is
      Fr      : constant Box_Frame := Frame_Of (P.Kind, P.Way, P.Front.X, P.Front.Y);
      G       : CB.House;
      Fits    : Boolean;
      Verdict : Lot_Verdict;
   begin
      Stands := False;
      if Plan_Cells_N = 0 or else N_Houses >= Max_Houses then
         return;
      end if;
      if abs Plan_Turn > 0.01 then
         declare
            Ex : constant Float := Cos (Plan_Turn);
            Ey : constant Float := Sin (Plan_Turn);
            A0, B0 : Float := Float'Last;
            A1, B1 : Float := Float'First;
         begin
            for K in 1 .. Plan_Cells_N - Plan_Over_N loop
               declare
                  A  : constant Float := Plan_Cell (K).X * Ex + Plan_Cell (K).Y * Ey;
                  Bb : constant Float := Plan_Cell (K).Y * Ex - Plan_Cell (K).X * Ey;
               begin
                  A0 := Float'Min (A0, A - 0.5);
                  A1 := Float'Max (A1, A + 0.5);
                  B0 := Float'Min (B0, Bb - 0.5);
                  B1 := Float'Max (B1, Bb + 0.5);
               end;
            end loop;
            if A1 - A0 < Stockyard_Least_M or else B1 - B0 < Stockyard_Least_M then
               return;
            end if;
            Store_Turned (Plan_Turn, A0, A1, B0, B1, Fr.Nx, Fr.Ny, G, Fits);
         end;
      else
         declare
            X0, Y0 : Integer := Integer'Last;
            X1, Y1 : Integer := Integer'First;
            Least  : constant Integer := Integer (Stockyard_Least_M) * 4;
         begin
            for K in 1 .. Plan_Cells_N - Plan_Over_N loop
               X0 := Integer'Min (X0, B (Plan_Cell (K).X - 0.4));
               X1 := Integer'Max (X1, B (Plan_Cell (K).X + 0.4));
               Y0 := Integer'Min (Y0, B (Plan_Cell (K).Y - 0.4));
               Y1 := Integer'Max (Y1, B (Plan_Cell (K).Y + 0.4));
            end loop;
            if X1 - X0 + 1 < Least or else Y1 - Y0 + 1 < Least then
               return;
            end if;
            Store_Squarely (X0, Y0, X1, Y1, Integer (Fr.Nx), Integer (Fr.Ny), G, Fits);
         end;
      end if;
      if Fits then
         Lot_Grid_Of_Plan;
         Try_Lot (G, Verdict, Stands, Fronts_Own => True);
      end if;
   end Try_Store_On_Plan;

   --  The plan of a box where it lies: its lot planned as its two corners
   --  would plan it, with its own path taken as lying there already.
   procedure Plan_Box_Lot (P : Placement; New_Path_M : out Float) is
      Half : constant Float := Path_Width_M / 2.0;
      Fr   : constant Box_Frame := Frame_Of (P.Kind, P.Way, P.Front.X, P.Front.Y);
      Dx   : constant Integer := Way_Dx (P.Way);
      Dy   : constant Integer := Way_Dy (P.Way);
      Step_M : constant Float := (if Dx /= 0 and then Dy /= 0 then 0.25 * Sqrt (2.0) else 0.25);
      Total, N_Gaps : Natural;
      Gaps : Box_Gaps;
      --  (a stockyard's: all of its lot's places are on its ground; its storehouse could stand)
      Yard_Whole  : Boolean := True;
      Yard_Stands : Boolean := True;
      procedure Nothing_Planned is
      begin
         Plan_N := 0;
         Plan_Blocks := 0;
         Plan_Cells_N := 0;
         Plan_Over_N := 0;
         Plan_Under_N := 0;
      end Nothing_Planned;
   begin
      New_Path_M := 0.0;
      Box_Refused := Box_Ok;
      Plan_Corner := P.Corner;
      Plan_Turn := 0.0;
      Nothing_Planned;
      Plan_Refused := No_Ground;
      if P.Kind = Stockyard_Box and then Stockyard > 0 then
         Box_Refused := Yard_Is_Placed;
         return;
      end if;
      if not P.Ok then
         Box_Refused := No_Ground_There;
         return;
      end if;
      --  its box: no zone's ground and no path's already
      declare
         procedure Look (Bx, By : Integer; Stop : in out Boolean) is
            Z : constant Natural := Zone_Of_Block (Bx, By);
         begin
            if Z /= 0 then
               Box_Refused := Over_A_Zone;
               Box_Over_Kind := Zones (Z).Kind;
               Box_Over_Yard := Zones (Z).Yard;
               Stop := True;
            elsif Near_Path ((Float (Bx) + 0.5) * 0.25, (Float (By) + 0.5) * 0.25, 0.0) then
               Box_Refused := Over_A_Path;
               Stop := True;
            elsif P.Kind = Stockyard_Box and then Cart_Set and then Cart_On_Block (Bx, By) then
               --  (a stockyard is all of its lot: the cart's own ground cannot be its; a stockpile is laid
               --  round it, as round anything that stands)
               Box_Refused := Over_The_Cart;
               Stop := True;
            end if;
         end Look;
      begin
         For_Box_Columns (Fr, 0.0, Fr.L, 0.0, Look'Access);
         if Box_Refused /= Box_Ok then
            return;
         end if;
      end;
      --  its path, where none lies along its line yet: as Lay_Path would refuse it
      Path_Gaps (P, Total, Gaps, N_Gaps);
      declare
         Pieces : Natural := 0;
      begin
         for Gp in 1 .. N_Gaps loop
            declare
               L : constant Float := Float (Gaps (Gp).B - Gaps (Gp).A) * Step_M;
            begin
               New_Path_M := New_Path_M + L;
               Pieces := Pieces + Line_Pieces (L);
               for K in 0 .. Integer (Float'Ceiling (L * 8.0)) loop
                  declare
                     T  : constant Float := Float (Gaps (Gp).A) * Step_M + Float'Min (L, Float (K) / 8.0);
                     Px : constant Float := P.From.X + Fr.Ux * T;
                     Py : constant Float := P.From.Y + Fr.Uy * T;
                  begin
                     if N_Zones > 0 and then Zone_On (Px, Py) /= 0 then
                        Box_Refused := Path_In_Zone;
                        return;
                     elsif Cart_Set and then Cart_On_Block (B (Px), B (Py), Margin => Integer (Half * 4.0)) then
                        Box_Refused := Path_In_Cart;
                        return;
                     end if;
                  end;
               end loop;
            end;
         end loop;
         if N_Paths + Pieces + 1 > Max_Paths then
            Box_Refused := No_More_Paths;
            return;
         end if;
      end;
      if not Zone_Room then
         Box_Refused := No_More_Zones;
         return;
      end if;
      --  its lot: along and across its path's way as a lot's is (within 45
      --  degrees of east), measured from its own corner
      declare
         Ex : Float := Fr.Ux;
         Ey : Float := Fr.Uy;
         T  : Float;
         A_Lo, B_Lo : Float := Float'Last;
         A_Hi, B_Hi : Float := Float'First;
      begin
         for Turn in 1 .. 3 loop
            exit when Ex > 0.0 and then abs Ey <= Ex;
            T := Ex;
            Ex := Ey;
            Ey := -T;
         end loop;
         if Ey = 0.0 then
            Ey := 0.0;
         end if;
         for C of P.Corner loop
            A_Lo := Float'Min (A_Lo, C.X * Ex + C.Y * Ey);
            A_Hi := Float'Max (A_Hi, C.X * Ex + C.Y * Ey);
            B_Lo := Float'Min (B_Lo, C.Y * Ex - C.X * Ey);
            B_Hi := Float'Max (B_Hi, C.Y * Ex - C.X * Ey);
         end loop;
         --  (its two ends a centimetre back along it, as For_Box_Columns has them: whichever of the
         --  lot's two measures its way is, and whichever way along that)
         declare
            Sa : constant Float := Fr.Ux * Ex + Fr.Uy * Ey;
            Sb : constant Float := Fr.Uy * Ex - Fr.Ux * Ey;
         begin
            if abs Sa > 0.5 then
               A_Lo := A_Lo - (if Sa > 0.0 then Box_Edge_M else -Box_Edge_M);
               A_Hi := A_Hi - (if Sa > 0.0 then Box_Edge_M else -Box_Edge_M);
            else
               B_Lo := B_Lo - (if Sb > 0.0 then Box_Edge_M else -Box_Edge_M);
               B_Hi := B_Hi - (if Sb > 0.0 then Box_Edge_M else -Box_Edge_M);
            end if;
         end;
         --  (its own path lies there for the plan: its ground stops at it, and comes right up to it)
         N_Paths := N_Paths + 1;
         Path_List (N_Paths) := (A => P.From, B => P.To, others => <>);
         begin
            case P.Kind is
               when Stockpile_Box =>
                  --  (a stockpile made one level takes the ledges in its box and the steep of it:
                  --  its ground will be one level, and so every place of its box is a place)
                  Plan_Lot (Ex, Ey, 0.0, A_Hi - A_Lo, 0.0, B_Hi - B_Lo,
                            Seed => Box_Middle (P),
                            Step_B => (if Flat_On then Flat_Most_B else Integer (Zone_Step_M * 4.0)), Places => True,
                            Ia0 => 0, Ia1 => Integer (Float'Floor (A_Hi - A_Lo + 0.01)) - 1,
                            Ib0 => 0, Ib1 => Integer (Float'Floor (B_Hi - B_Lo + 0.01)) - 1,
                            Overflow => (if Overflow_On then Overflow_Places else 0), One_Level => Flat_On,
                            Steep_B => (if Steep_On and then not Flat_On then Steep_Rise_B else 0),
                            Oa => A_Lo, Ob => B_Lo, Drawn_Out => False, Fell_Trees => Box_Fell_On);
               when Stockyard_Box =>
                  --  (a stockyard's lot as its two corners plan it: its ground taken over any ledge its
                  --  levelling will make good, whatever stands on it to be cleared; all of it or none;
                  --  and its storehouse tried on it, while its own path still counts as lying there)
                  Plan_Lot (Ex, Ey, 0.0, A_Hi - A_Lo, 0.0, B_Hi - B_Lo,
                            Seed => Box_Middle (P),
                            Step_B => (if Yard_Level_On then Integer (CB.Max_Step_B) + 4 else Integer (Zone_Step_M * 4.0)),
                            Places => True,
                            Ia0 => 0, Ia1 => Integer (Float'Floor (A_Hi - A_Lo + 0.01)) - 1,
                            Ib0 => 0, Ib1 => Integer (Float'Floor (B_Hi - B_Lo + 0.01)) - 1,
                            Least => Stockyard_Least_M, Clear_All => Yard_Level_On,
                            Oa => A_Lo, Ob => B_Lo, Drawn_Out => False);
                  if Plan_Refused = Lot_Ok then
                     Yard_Whole := not Yard_Level_On
                       or else Plan_Cells_N >= Integer (Float'Floor (A_Hi - A_Lo + 0.01))
                                               * Integer (Float'Floor (B_Hi - B_Lo + 0.01));
                     if Yard_Whole then
                        Try_Store_On_Plan (P, Yard_Stands);
                     end if;
                  end if;
            end case;
         exception
            when others =>
               N_Paths := N_Paths - 1;
               raise;
         end;
         N_Paths := N_Paths - 1;
         Plan_Corner := P.Corner;
      end;
      if Plan_Refused /= Lot_Ok then
         Box_Refused := (if Plan_Refused = No_Room then No_More_Zones
                         elsif Plan_Refused = Too_Steep then Too_Steep_There
                         elsif P.Kind = Stockyard_Box then Not_All_Ground else No_Places);
         Nothing_Planned;
      elsif not Yard_Whole then
         Box_Refused := Not_All_Ground;
         Nothing_Planned;
      elsif not Yard_Stands then
         Box_Refused := No_Storehouse;
         Nothing_Planned;
      end if;
   end Plan_Box_Lot;

   function Box_Counts (Z : Positive) return Box_Count is
      C    : Box_Count;
      Half : constant Float := Path_Width_M / 2.0;
   begin
      if Z > N_Zones or else not Zones (Z).Placed then
         return C;
      end if;
      if Zones (Z).Kind = Camp_Zone then
         --  (the square the colony was founded on: its floor's block columns)
         declare
            Aslant : constant Boolean := Zones (Z).Way mod 2 = 1;
            Ex : constant Float := (if Aslant then 1.0 / Sqrt (2.0) else 1.0);
            Ey : constant Float := (if Aslant then 1.0 / Sqrt (2.0) else 0.0);
            H  : constant Float :=
              (if Aslant then Float (Square_Diag_B) * 0.25 / Sqrt (2.0) else Float (Square_Ring_B) * 0.25) - Half;
            R  : constant Float := H * (abs Ex + abs Ey);
         begin
            for Bx in B (Camp_At.X - R) .. B (Camp_At.X + R) loop
               for By in B (Camp_At.Y - R) .. B (Camp_At.Y + R) loop
                  declare
                     Dx : constant Float := (Float (Bx) + 0.5) * 0.25 - Camp_At.X;
                     Dy : constant Float := (Float (By) + 0.5) * 0.25 - Camp_At.Y;
                     Whose : constant Natural := Zone_Of_Block (Bx, By);
                  begin
                     if abs (Dx * Ex + Dy * Ey) < H and then abs (Dy * Ex - Dx * Ey) < H then
                        C.Box := C.Box + 1;
                        if Whose = Z then
                           C.Its_Own := C.Its_Own + 1;
                        elsif Whose /= 0 then
                           C.Other := C.Other + 1;
                        elsif Near_Path (Camp_At.X + Dx, Camp_At.Y + Dy, 0.0) then
                           C.Path := C.Path + 1;
                        else
                           C.Bare := C.Bare + 1;
                        end if;
                     end if;
                  end;
               end loop;
            end loop;
         end;
         return C;
      end if;
      declare
         Fr : constant Box_Frame :=
           Frame_Of ((if Zones (Z).Yard then Stockyard_Box else Stockpile_Box), Zones (Z).Way,
                     Float (Zones (Z).Fx) * 0.25, Float (Zones (Z).Fy) * 0.25);
         procedure Count (Bx, By : Integer; Stop : in out Boolean) is
            pragma Unreferenced (Stop);
            X : constant Float := (Float (Bx) + 0.5) * 0.25;
            Y : constant Float := (Float (By) + 0.5) * 0.25;
            Whose : constant Natural := Zone_Of_Block (Bx, By);
         begin
            C.Box := C.Box + 1;
            if Whose = Z then
               C.Its_Own := C.Its_Own + 1;
            elsif Whose /= 0 then
               C.Other := C.Other + 1;
            elsif Near_Path (X, Y, 0.0) then
               C.Path := C.Path + 1;
            else
               C.Bare := C.Bare + 1;
               if Box_V (Fr, X, Y) < Half + 1.0 then
                  C.Front_Bare := C.Front_Bare + 1;
               end if;
            end if;
         end Count;
      begin
         For_Box_Columns (Fr, 0.0, Fr.L, 0.0, Count'Access);
      end;
      return C;
   end Box_Counts;

   function Plan_Box (Kind : Box_Kind; Middle : Vec3; Way : Way_Index) return Box_Plan is
      R : Box_Plan;
   begin
      R.Where := Box_At (Kind, Middle, Way);
      Plan_Box_Lot (R.Where, R.New_Path_M);
      R.Lot := Plan_View;
      R.Lot.Ok := Box_Refused = Box_Ok;
      return R;
   end Plan_Box;

   --  A tree's foot stands in a place of a stockpile (in its square metre,
   --  measured the way its lot lies): nothing is put there while it does.
   function Cell_Has_Trunk (C : Positive) return Boolean is
      Cl : Cell renames Castle.Colony.Cells (C);
      T  : constant Float := (if Cl.Zone in 1 .. N_Zones then Zones (Cl.Zone).Turn else 0.0);
      Cs : constant Float := Cos (T);
      Sn : constant Float := Sin (T);
      Zn : Natural;
      Row : Integer;
   begin
      for Bx in B (Cl.Centre.X - 0.75) .. B (Cl.Centre.X + 0.75) loop
         for By in B (Cl.Centre.Y - 0.75) .. B (Cl.Centre.Y + 0.75) loop
            declare
               Dx : constant Float := (Float (Bx) + 0.5) * 0.25 - Cl.Centre.X;
               Dy : constant Float := (Float (By) + 0.5) * 0.25 - Cl.Centre.Y;
            begin
               if abs (Dx * Cs + Dy * Sn) < 0.5 and then abs (Dy * Cs - Dx * Sn) < 0.5 then
                  Zone_Of_Block (Bx, By, Zn, Row);
                  if Zn = Cl.Zone and then Row >= 0 and then Mat (Bx, By, Row + 1) in Trunk then
                     return True;
                  end if;
               end if;
            end;
         end loop;
      end loop;
      return False;
   end Cell_Has_Trunk;

   --  A place of a stockpile made one level with a block column in it that
   --  is never moved to its level (rock, water, further off than
   --  Flat_Most_B): closed where the stockpile was put down, and kept so.
   function Cell_In_Rock (C : Positive) return Boolean is
      Cl : Cell renames Castle.Colony.Cells (C);
      T  : constant Float := (if Cl.Zone in 1 .. N_Zones then Zones (Cl.Zone).Turn else 0.0);
      Cs : constant Float := Cos (T);
      Sn : constant Float := Sin (T);
      Zr : constant Integer := B (Cl.Centre.Z + 0.01) - 1;
   begin
      if not Flat_On or else Cl.Overflow or else Cl.Fit /= Ground or else Cl.Zone not in 1 .. N_Zones
        or else Zones (Cl.Zone).Kind /= Stockpile_Zone or else Zones (Cl.Zone).Yard
      then
         return False;
      end if;
      for Bx in B (Cl.Centre.X - 0.75) .. B (Cl.Centre.X + 0.75) loop
         for By in B (Cl.Centre.Y - 0.75) .. B (Cl.Centre.Y + 0.75) loop
            declare
               Dx : constant Float := (Float (Bx) + 0.5) * 0.25 - Cl.Centre.X;
               Dy : constant Float := (Float (By) + 0.5) * 0.25 - Cl.Centre.Y;
            begin
               if abs (Dx * Cs + Dy * Sn) < 0.5 and then abs (Dy * Cs - Dx * Sn) < 0.5
                 and then Zone_Of_Block (Bx, By) = Cl.Zone
                 and then Flat_Kind (Bx, By, Top_By (Bx, By, Zr), Zr) in Flat_Never
               then
                  return True;
               end if;
            end;
         end loop;
      end loop;
      return False;
   end Cell_In_Rock;

   procedure Flat_Column_At (Bx, By : Integer; Zone : out Natural; Level_M : out Float; Kind : out Flat_Column) is
      Row : Integer;
   begin
      Level_M := 0.0;
      Kind := No_Ground;
      Zone_Of_Block (Bx, By, Zone, Row);
      if Zone not in 1 .. N_Zones or else Zones (Zone).Kind /= Stockpile_Zone or else Zones (Zone).Yard then
         Zone := 0;
         return;
      end if;
      for C in 1 .. N_Cells loop
         if Castle.Colony.Cells (C).Zone = Zone and then not Castle.Colony.Cells (C).Overflow
           and then Castle.Colony.Cells (C).Fit = Ground
         then
            declare
               Zr : constant Integer := B (Castle.Colony.Cells (C).Centre.Z + 0.01) - 1;
            begin
               Level_M := Castle.Colony.Cells (C).Centre.Z;
               Kind := Flat_Kind (Bx, By, Top_By (Bx, By, Zr), Zr);
               return;
            end;
         end if;
      end loop;
      Zone := 0;
   end Flat_Column_At;

   procedure Remove_Stockpile (Z : Positive; On : Boolean := True) is
   begin
      Remove_Refused := Removal_Ok;
      if Z not in 1 .. N_Zones or else Zones (Z).Kind /= Stockpile_Zone or else Zones (Z).N = 0 then
         Remove_Refused := No_Stockpile;
         return;
      end if;
      if Zones (Z).Yard then
         Remove_Refused := Is_The_Yard;
         return;
      end if;
      Zones (Z).Leaving := On;
      for C in 1 .. N_Cells loop
         if Cells (C).Zone = Z then
            Cells (C).Closed := On or else (Box_Fell_On and then Cell_Has_Trunk (C)) or else Cell_In_Rock (C)
              or else Stores_Moved;
         end if;
      end loop;
      Zones_Ver := Zones_Ver + 1;
   end Remove_Stockpile;
   function Removal_Refusal return String is
     (case Remove_Refused is
         when Removal_Ok   => "",
         when No_Stockpile => "there is no stockpile there",
         when Is_The_Yard  => "the stockyard is not removed: its storehouse is built on it");

   --  A tree that stood in stockpile Z has been felled and taken out: its
   --  ground read again, and the places it stood in opened (unless the
   --  stores have moved to the storehouse, which closed them all).
   procedure Box_Tree_Felled (Z : Positive) is
   begin
      Read_Zone_Ground (Z);
      Flatten_Pile (Z, Again => True);       --  (a stockpile made one level: where the tree stood, too)
      Box_Trees_At := Natural'Last;
      if Stores_Moved or else Zones (Z).Leaving then
         return;
      end if;
      for C in 1 .. N_Cells loop
         if Castle.Colony.Cells (C).Zone = Z and then Castle.Colony.Cells (C).Closed and then not Cell_Has_Trunk (C)
           and then not Cell_In_Rock (C)
         then
            Castle.Colony.Cells (C).Closed := False;
            Zones_Ver := Zones_Ver + 1;
         end if;
      end loop;
   end Box_Tree_Felled;

   --  (a measure, for the tools: the parts of placed boxes' own paths that Lay_Path found nothing to lay on)
   Box_Unlaid_N : Natural := 0;
   function Box_Paths_Unlaid return Natural is (Box_Unlaid_N);
   procedure Place_Box (Kind : Box_Kind; Middle : Vec3; Way : Way_Index; Cells : out Natural) is
      P : constant Placement := Box_At (Kind, Middle, Way);
      Fr : constant Box_Frame := Frame_Of (Kind, Way, P.Front.X, P.Front.Y);
      Dx : constant Integer := Way_Dx (Way);
      Dy : constant Integer := Way_Dy (Way);
      Step_M : constant Float := (if Dx /= 0 and then Dy /= 0 then 0.25 * Sqrt (2.0) else 0.25);
      New_M : Float;
      Total, N_Gaps : Natural;
      Gaps  : Box_Gaps;
      First : constant Natural := N_Cells;
   begin
      Cells := 0;
      Plan_Box_Lot (P, New_M);
      if Box_Refused /= Box_Ok then
         return;
      end if;
      --  its path first, where none lies along its line: the zone's ground is what is left beside it
      Path_Gaps (P, Total, Gaps, N_Gaps);
      for Gp in 1 .. N_Gaps loop
         declare
            Laid : Natural;
            A : constant Vec3 := Line_Point (P.From.X + Fr.Ux * Float (Gaps (Gp).A) * Step_M,
                                             P.From.Y + Fr.Uy * Float (Gaps (Gp).A) * Step_M, P.From.Z);
            C : constant Vec3 := Line_Point (P.From.X + Fr.Ux * Float (Gaps (Gp).B) * Step_M,
                                             P.From.Y + Fr.Uy * Float (Gaps (Gp).B) * Step_M, P.To.Z);
         begin
            Lay_Path (A, C, Laid);          --  (ground a path cannot be laid on, water or rock, is left as it lies)
            if Laid = 0 then
               Box_Unlaid_N := Box_Unlaid_N + 1;
            end if;
         end;
      end loop;
      Plan_Box_Lot (P, New_M);
      if Box_Refused /= Box_Ok then
         return;
      end if;
      case Kind is
         when Stockpile_Box =>
            Clear_Places;
            for K in 1 .. Plan_Cells_N loop
               N_Cells := N_Cells + 1;
               Castle.Colony.Cells (N_Cells) :=
                 (Centre => Plan_Cell (K), Turn => Plan_Turn, Overflow => K > Plan_Cells_N - Plan_Over_N, others => <>);
            end loop;
            Cells := N_Cells - First;
            New_Stockpile_Zone (First + 1);
         when Stockyard_Box =>
            for K in 1 .. Plan_Cells_N loop
               N_Cells := N_Cells + 1;
               Castle.Colony.Cells (N_Cells) :=
                 (Centre => Plan_Cell (K), Turn => Plan_Turn, Closed => True, others => <>);   --  (until its storehouse stands)
            end loop;
            New_Stockpile_Zone (First + 1);
            Zones (N_Zones).Yard := True;
      end case;
      Zones (N_Zones).Placed := True;
      Zones (N_Zones).Fx := Integer (Float'Rounding (P.Front.X * 4.0));
      Zones (N_Zones).Fy := Integer (Float'Rounding (P.Front.Y * 4.0));
      Zones (N_Zones).Way := Way;
      Zones (N_Zones).Along_B := P.Along_B;
      if Kind = Stockyard_Box then
         --  its storehouse, tried on the zone as it now is (the plan tried it on the same ground
         --  before the path was laid: it stands); asked for already, it is begun at once
         declare
            Ok : Boolean;
         begin
            Yard_Steep := False;
            Place_Storehouse (N_Zones, Ok, Try_Only => True);
            if not Ok then
               N_Runs := N_Runs - Zones (N_Zones).N;
               N_Zones := N_Zones - 1;
               N_Cells := First;
               Zones_Ver := Zones_Ver + 1;
               Box_Refused := No_Storehouse;
               return;
            end if;
            Clear_Places;
            Cells := N_Cells - First;
            Yard_Refused := Lot_Ok;
            if Store_On and then Store_Asked and then Store_House = 0 then
               Place_Storehouse (N_Zones, Ok);
               if Ok then
                  Store_Note_N := Store_Note_N + 1;
               end if;
            end if;
         end;
         return;
      end if;
      --  the trees that stand in it are to be felled (they are known from now, not only once their
      --  stacks are looked through), and nothing is put in a place a tree's foot stands in until then
      if Box_Fell_On then
         if Find_Src /= null then
            for CX in Floor_Div (Zones (N_Zones).Bx0 - Tree_Cell_B, Chunk_B)
              .. Floor_Div (Zones (N_Zones).Bx1 + Tree_Cell_B, Chunk_B)
            loop
               for CY in Floor_Div (Zones (N_Zones).By0 - Tree_Cell_B, Chunk_B)
                 .. Floor_Div (Zones (N_Zones).By1 + Tree_Cell_B, Chunk_B)
               loop
                  if CX >= 0 and then CY >= 0 then
                     Index_Trees (CX, CY);
                  end if;
               end loop;
            end loop;
         end if;
         for C in First + 1 .. N_Cells loop
            if Cell_Has_Trunk (C) then
               Castle.Colony.Cells (C).Closed := True;
            end if;
         end loop;
         Box_Trees_At := Natural'Last;
      end if;
      Flatten_Pile (N_Zones);                 --  (a stockpile is one level: Set_Pile_Flat)
   end Place_Box;

   procedure Zone_Stockyard (X0, Y0, X1, Y1 : Float; Cells : out Natural) is
      First : constant Natural := N_Cells;
      Ok    : Boolean;
   begin
      Cells := 0;
      Yard_Steep := False;
      Plan_Stockyard_Lot (X0, Y0, X1, Y1);
      if Plan_Refused /= Lot_Ok then
         return;
      end if;
      for K in 1 .. Plan_Cells_N loop
         N_Cells := N_Cells + 1;
         Castle.Colony.Cells (N_Cells) :=
           (Centre => Plan_Cell (K), Turn => Plan_Turn, Closed => True, others => <>);   --  (until its storehouse stands)
      end loop;
      New_Stockpile_Zone (First + 1);
      Zones (N_Zones).Yard := True;
      --  a storehouse has to be able to stand on it (its ground within Max_Step_B from end to end, its
      --  floor within reach of its path): tried now, and the zone not taken if none could
      Place_Storehouse (N_Zones, Ok, Try_Only => True);
      if not Ok then
         N_Runs := N_Runs - Zones (N_Zones).N;
         N_Zones := N_Zones - 1;
         N_Cells := First;
         Zones_Ver := Zones_Ver + 1;
         Yard_Steep := True;
         return;
      end if;
      Clear_Places;
      Cells := N_Cells - First;
      Yard_Refused := Lot_Ok;
      if Store_On and then Store_Asked and then Store_House = 0 then    --  (asked for already: begun at once)
         Place_Storehouse (N_Zones, Ok);
         if Ok then
            Store_Note_N := Store_Note_N + 1;
         end if;
      end if;
   end Zone_Stockyard;

   ------------------------------------------------------------------ the camp: zoning

   type Refusal is (Taken_None, Already, No_Stake_Yet, Too_Steep, In_The_Way, Over_Stockpile, Path_Near,
                    No_Free_Ground, Out_Of_Room, Over_Cart);
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
         when Out_Of_Room    => "there is no room for another zone",
         when Over_Cart      => "the lord's cart stands there: it cannot be moved yet");

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

   ------------------------------------------------------------------ the homestake and the campfire one

   function Camp_Is_Square return Boolean is (Camp_Square);
   function Square_Trees_Left return Natural is (Square_Trees_Standing);

   type Square_Refused_For is
     (Square_Ok, Stake_Raised, No_Ground_For_It, Too_Uneven, Something_On_It, Water_On_It, No_Zone_Left, Cut_Off);
   Square_Refused : Square_Refused_For := Square_Ok;
   Square_Off_Cm  : Natural := 0;                      --  (Too_Uneven: how far off its middle's the ground lies)
   Square_In_Way  : Vec3 := (0.0, 0.0, 0.0);           --  (Something_On_It, Water_On_It: where)

   function Square_Off_M return Float is (Float (Square_Off_Cm) / 100.0);

   function Square_Refusal return String is
     (case Square_Refused is
         when Square_Ok        => "",
         when Stake_Raised     => "the homestake is raised already",
         when No_Ground_For_It => "there is no ground there for it",
         when Too_Uneven       => "the ground rises and falls too much for it (it is" & Natural'Image (Square_Off_Cm)
                                  & " cm off its middle's;" & Integer'Image (Integer (Square_Fall_M * 100.0))
                                  & " cm at most)",
         when Something_On_It  => (if Square_Fell_On then "a boulder stands by where its fire is to be, at"
                                   else "something stands by where its fire is to be (a tree, a boulder) at")
                                  & Integer'Image (Integer (Square_In_Way.X)) & ","
                                  & Integer'Image (Integer (Square_In_Way.Y)),
         when Water_On_It      => "there is water on it at" & Integer'Image (Integer (Square_In_Way.X)) & ","
                                  & Integer'Image (Integer (Square_In_Way.Y)),
         when No_Zone_Left     => "there is no room for another zone",
         when Cut_Off          => "its floor would lie cut off, a bank all round it (no side of it within half a"
                                  & " metre of the ground beside it)");

   --  Where a square held with its middle at Middle and turned Way lies:
   --  its middle on the corner of blocks nearest, its floor's corners and
   --  the corners of its path's line (the first to the south-west squarely,
   --  to the west aslant, and on round to the left).
   function Square_At (Middle : Vec3; Way : Way_Index) return Square_Plan is
      Mx : constant Float := Block_Corner (Middle.X);
      My : constant Float := Block_Corner (Middle.Y);
      P  : Square_Plan;
      Z  : constant Float := Castle.Nav.Surface_Z (Mx, My);
   begin
      P.Way := Way;
      P.Middle := (Mx, My, (if Z >= 0.0 then Z else Middle.Z));
      if Way mod 2 = 0 then
         declare
            R : constant Float := Float (New_Ring_B) * 0.25;
            H : constant Float := R - Path_Width_M / 2.0;
         begin
            P.Ring := [(Mx - R, My - R, 0.0), (Mx + R, My - R, 0.0), (Mx + R, My + R, 0.0), (Mx - R, My + R, 0.0)];
            P.Corner := [(Mx - H, My - H, 0.0), (Mx + H, My - H, 0.0), (Mx + H, My + H, 0.0), (Mx - H, My + H, 0.0)];
         end;
      else
         declare
            R : constant Float := Float (New_Diag_B) * 0.25;
            H : constant Float := R - Path_Width_M / 2.0 * Sqrt (2.0);
         begin
            P.Ring := [(Mx - R, My, 0.0), (Mx, My - R, 0.0), (Mx + R, My, 0.0), (Mx, My + R, 0.0)];
            P.Corner := [(Mx - H, My, 0.0), (Mx, My - H, 0.0), (Mx + H, My, 0.0), (Mx, My + H, 0.0)];
         end;
      end if;
      return P;
   end Square_At;

   --  The strips a square planned at P is to have (the spec, "A special
   --  zone's area is kept whole"), its floor to lie at row Level: each
   --  side's path tried where it lies and, while a bank of more lifts than
   --  the rings kept would be left beside it, further out.  P is given them
   --  and the corners of its path's lines.  A quarter metre of a path's
   --  length is brought to the floor's level, and the strip between it and
   --  the floor with it, when all of its width and of the strip's lies
   --  within Path_Level_B of that level (Lay_Metre, of the square's own
   --  path: the same quarter metres, counted from the same end); one that
   --  is not is laid as its ground lies, and its innermost column is what
   --  the wall is planned against (Plan_Walls).  The ground is read as it is: its own
   --  top, whatever stands on it; under a tree's foot, where it will be when
   --  the tree is felled and its foot made ground, before the path is laid.
   procedure Forecast_Strips (P : in out Square_Plan; Level : Integer) is
      Aslant : constant Boolean := P.Way mod 2 = 1;
      R0 : constant Float := Float (if Aslant then New_Diag_B else New_Ring_B) * 0.25;
      G  : Square_Geo := (Mx => P.Middle.X, My => P.Middle.Y, Aslant => Aslant,
                          Half => (if Aslant then R0 / Sqrt (2.0) else R0) - Path_Width_M / 2.0,
                          Strip => [others => 0]);
      Ex : constant Float := (if Aslant then 1.0 / Sqrt (2.0) else 1.0);
      Ey : constant Float := (if Aslant then 1.0 / Sqrt (2.0) else 0.0);
      W  : constant Float := Ring_Width (G);
      Half_W : constant Float := Path_Width_M / 2.0;
      --  (the side each of the four stretches lies along: Square_At's order of corners)
      Side_Of_Path : constant array (Boolean, 1 .. 4) of Positive := [False => [4, 1, 3, 2], True => [2, 4, 1, 3]];
      --  The top a column's ground will have when its path is laid, Zr its own top now: under a
      --  tree's foot, two blocks higher (a trunk is rooted two blocks into the ground; felled and
      --  taken out, its roots are earth to the level of the ground about it: Stump_Out).
      function Ground_To_Be (X, Y, Zr : Integer) return Integer is
        (if Mat (X, Y, Zr + 1) in Trunk then Zr + 2 else Zr);
   begin
      for Pass in 1 .. Strip_Most + 1 loop
         declare
            Ring    : constant Lot_Corners := Line_Corners (G.Mx, G.My, Aslant, R0, G.Strip);
            Changed : Boolean := False;
         begin
            for K in 1 .. 4 loop
               declare
                  Sd  : constant Positive := Side_Of_Path (Aslant, K);
                  S   : constant Path_Seg := (A => Ring (K), B => Ring (K mod 4 + 1), others => <>);
                  Len : constant Float := Flat_Dist (S.A, S.B);
                  Last_Sec : constant Integer := Integer (Float'Ceiling (Len * 4.0)) + 1;
                  Off  : array (0 .. Last_Sec) of Boolean := [others => False];
                  Need : Natural := 0;
                  function Section (X, Y : Integer) return Integer is
                     C : constant Vec3 := ((Float (X) + 0.5) * 0.25, (Float (Y) + 0.5) * 0.25, 0.0);
                     T : constant Float :=
                       Float'Max (0.0, Float'Min (1.0, ((C.X - S.A.X) * (S.B.X - S.A.X)
                                                         + (C.Y - S.A.Y) * (S.B.Y - S.A.Y)) / (Len * Len)));
                  begin
                     return Integer'Min (Last_Sec, Integer (Float'Floor (T * Len * 4.0)));
                  end Section;
                  function On_It (X, Y : Integer) return Boolean is
                    (Seg_Dist (((Float (X) + 0.5) * 0.25, (Float (Y) + 0.5) * 0.25, 0.0), S) <= Half_W
                     and then Part_Of (G, X, Y) = Part_Path);
                  --  (or on the strip kept so far between it and the floor: a quarter metre is brought
                  --  level strip and all, or not at all)
                  function On_Strip (X, Y : Integer) return Boolean is
                    (G.Strip (Sd) > 0
                     and then Seg_Dist (((Float (X) + 0.5) * 0.25, (Float (Y) + 0.5) * 0.25, 0.0), S)
                                <= Half_W + Float (G.Strip (Sd)) * W + 0.001
                     and then Part_Of (G, X, Y) = Part_Strip);
                  Reach : constant Float := Half_W + Float (Strip_Most) * 0.25;
               begin
                  for X in B (Float'Min (S.A.X, S.B.X) - Reach) .. B (Float'Max (S.A.X, S.B.X) + Reach) loop
                     for Y in B (Float'Min (S.A.Y, S.B.Y) - Reach) .. B (Float'Max (S.A.Y, S.B.Y) + Reach) loop
                        if On_It (X, Y) or else On_Strip (X, Y) then
                           declare
                              Zr : constant Integer := Top_By (X, Y, Level);
                           begin
                              if Zr < 0 or else abs (Level - Ground_To_Be (X, Y, Zr)) > Path_Level_B then
                                 Off (Section (X, Y)) := True;
                              end if;
                           end;
                        end if;
                     end loop;
                  end loop;
                  for X in B (Float'Min (S.A.X, S.B.X) - Half_W) .. B (Float'Max (S.A.X, S.B.X) + Half_W) loop
                     for Y in B (Float'Min (S.A.Y, S.B.Y) - Half_W) .. B (Float'Max (S.A.Y, S.B.Y) + Half_W) loop
                        if On_It (X, Y) and then Off (Section (X, Y)) then
                           declare
                              Dx : constant Float := (Float (X) + 0.5) * 0.25 - G.Mx;
                              Dy : constant Float := (Float (Y) + 0.5) * 0.25 - G.My;
                              U  : constant Float := Dx * Ex + Dy * Ey;
                              V  : constant Float := Dy * Ex - Dx * Ey;
                              --  how far out it lies on this side, and along it (the side that way)
                              Out_C : constant Float := (case Sd is when 1 => U, when 2 => -U, when 3 => V, when others => -V);
                              Along : constant Float := (if Sd <= 2 then V else U);
                              Other : constant Positive := (if Sd <= 2 then (if V >= 0.0 then 3 else 4)
                                                            else (if U >= 0.0 then 1 else 2));
                              Z0 : constant Integer := Top_By (X, Y, Level);
                              Zr : constant Integer := (if Z0 >= 0 then Ground_To_Be (X, Y, Z0) else -1);
                           begin
                              --  (its innermost ring, beside the floor or beside the strip of the side it meets)
                              if Out_C < G.Half + Float (G.Strip (Sd)) * W + W
                                and then abs Along < G.Half + Float (G.Strip (Other)) * W
                                and then Zr >= 0 and then abs (Zr - Level) > Retain_Over_B
                              then
                                 Need := Natural'Max (Need, (abs (Zr - Level) + Square_Lift_B - 1) / Square_Lift_B);
                              end if;
                           end;
                        end if;
                     end loop;
                  end loop;
                  --  (Aslant, two rings wherever a wall is wanted, and no more: the lines of a path at 45
                  --  degrees that a stockpile or a turned house can lie along are every other diagonal
                  --  of the block grid, and where two sides' lines lay an odd number of rings apart they
                  --  crossed at the middle of a block's edge, the stretches' ends no corner of blocks.
                  --  A wall of one lift has the second ring for its top, capped; one of three stands
                  --  steeper in the two.)
                  if Aslant and then Need > 0 then
                     Need := 2;
                  end if;
                  if Natural'Min (Need, Strip_Most) > G.Strip (Sd) then
                     G.Strip (Sd) := Natural'Min (Need, Strip_Most);
                     Changed := True;
                  end if;
               end;
            end loop;
            exit when not Changed;
         end;
      end loop;
      P.Strip := G.Strip;
      P.Ring := Line_Corners (G.Mx, G.My, Aslant, R0, G.Strip);
   end Forecast_Strips;

   --  The plan of it: refused or not, its floor's ground (the plan's), and,
   --  where a square's walls stand outside its floor, the strips kept for
   --  them and the corners of its path's lines with them.
   procedure Plan_Square_Lot (P : in out Square_Plan) is
      Aslant : constant Boolean := P.Way mod 2 = 1;
      Ex : constant Float := (if Aslant then 1.0 / Sqrt (2.0) else 1.0);
      Ey : constant Float := (if Aslant then 1.0 / Sqrt (2.0) else 0.0);
      --  half its floor, and half of floor and path together, along and across its way
      H  : constant Float :=
        (if Aslant then Float (New_Diag_B) * 0.25 / Sqrt (2.0) else Float (New_Ring_B) * 0.25) - Path_Width_M / 2.0;
      Out_H : constant Float := H + Path_Width_M;
      Fa : constant Float := P.Middle.X * Ex + P.Middle.Y * Ey;
      Fb : constant Float := P.Middle.Y * Ex - P.Middle.X * Ey;
      Cx : constant Integer := Integer (Float'Floor (P.Middle.X * 4.0 + 0.5));
      Cy : constant Integer := Integer (Float'Floor (P.Middle.Y * 4.0 + 0.5));
      Zc : constant Integer := Top_By (Cx, Cy, B (P.Middle.Z) - 1);
      R  : constant Float := Out_H * (abs Ex + abs Ey);
      --  along and across its way, out from its middle
      function Along (X, Y : Integer) return Float is
        (abs ((Float (X) + 0.5) * 0.25 * Ex + (Float (Y) + 0.5) * 0.25 * Ey - Fa));
      function Across (X, Y : Integer) return Float is
        (abs ((Float (Y) + 0.5) * 0.25 * Ex - (Float (X) + 0.5) * 0.25 * Ey - Fb));
   begin
      Plan_N := 0;
      Plan_Blocks := 0;
      Plan_Cells_N := 0;
      Plan_Over_N := 0;
      Plan_Under_N := 0;
      Plan_Corner := P.Corner;
      Plan_Turn := Arctan (Ey, Ex);
      Plan_Refused := No_Ground;
      Square_Refused := Square_Ok;
      if Stake_Set then
         Square_Refused := Stake_Raised;
         return;
      elsif Zc < 0 then
         Square_Refused := No_Ground_For_It;
         return;
      elsif N_Zones >= Max_Zones then
         Square_Refused := No_Zone_Left;
         return;
      end if;
      --  its floor and its path: ground under all of it, none of it under
      --  water, no tree or boulder by where its fire is to be, and its floor
      --  no further off its middle's level than it may be
      Square_Off_Cm := 0;
      for X in B (P.Middle.X - R) .. B (P.Middle.X + R) loop
         for Y in B (P.Middle.Y - R) .. B (P.Middle.Y + R) loop
            declare
               Px : constant Float := (Float (X) + 0.5) * 0.25;
               Py : constant Float := (Float (Y) + 0.5) * 0.25;
               A  : constant Float := Along (X, Y);
               Bb : constant Float := Across (X, Y);
            begin
               if A < Out_H and then Bb < Out_H then
                  declare
                     --  (the ground's own top there, whatever stands on it or hangs over it)
                     Zr : constant Integer := Top_By (X, Y, Zc);
                  begin
                     if Zr < 0 then
                        --  (none within 6 m of its middle's level: a cliff)
                        Square_Refused := Too_Uneven;
                        Square_Off_Cm := 600;
                        return;
                     elsif Class_Of (Mat (X, Y, Zr + 1)) = Liquid then
                        Square_Refused := Water_On_It;
                        Square_In_Way := (Px, Py, 0.0);
                        return;
                     elsif Mat (X, Y, Zr + 1) in Trunk and then Square_Fell_On then
                        null;       --  (a tree's foot: the tree is felled and taken out, and its place made floor)
                     elsif Mat (X, Y, Zr) = Boulder or else Mat (X, Y, Zr + 1) in Trunk then
                        --  (a boulder; a tree's foot, with Set_Square_Fell off: by the fire it is in the
                        --  way; further out it is left standing, and the square is made round it)
                        if Sqrt ((Px - P.Middle.X) ** 2 + (Py - P.Middle.Y) ** 2) <= Square_Core_M then
                           Square_Refused := Something_On_It;
                           Square_In_Way := (Px, Py, 0.0);
                           return;
                        end if;
                     elsif A < H and then Bb < H then
                        --  (a bush on it, a bough low over it: cleared when it is founded)
                        Square_Off_Cm := Natural'Max (Square_Off_Cm, 25 * abs (Zr - Zc));
                     end if;
                  end;
               end if;
            end;
         end loop;
      end loop;
      if Float (Square_Off_Cm) > Square_Fall_M * 100.0 then
         Square_Refused := Too_Uneven;
         return;
      end if;
      --  (its ground: all of its box but a tree's foot, over any step there can be within it)
      Plan_Lot (Ex, Ey, 0.0, 2.0 * H, 0.0, 2.0 * H, Seed => P.Middle,
                Step_B => Integer (Square_Fall_M * 8.0) + 1, Places => False,
                Clear_All => True, Keep_Feet => not Square_Fell_On,
                Oa => Fa - H, Ob => Fb - H, Drawn_Out => False);
      Plan_Corner := P.Corner;
      if Plan_Refused /= Lot_Ok or else Plan_N = 0 then
         Square_Refused := (if Plan_Refused = No_Room then No_Zone_Left else No_Ground_For_It);
         Plan_N := 0;
         Plan_Blocks := 0;
         return;
      end if;
      --  made level by the band, it must not lie cut off: a floor a serf can
      --  step down off (a metre) and not up onto again (half of one), or the
      --  other way about, on every side.  So some of its edge has ground
      --  beside it within a step of the level it will be brought to: two
      --  metres' worth of block columns at the least.
      if Labour_On and then Level_On then
         declare
            Level : constant Integer := Level_For (Run_List (Plan_Run (1 .. Plan_N)), All_Floor => True);
            Ways  : Natural := 0;
            Dx : constant array (1 .. 4) of Integer := [1, -1, 0, 0];
            Dy : constant array (1 .. 4) of Integer := [0, 0, 1, -1];
         begin
            --  (the level it will be founded at is Choose_Level's, which counts the ground under a
            --  tree's foot: where trees stand on it that can be a block lower than the level above,
            --  by which it is judged cut off or not as it always was)
            P.Level_Row := Level_For (Run_List (Plan_Run (1 .. Plan_N)), All_Floor => True, With_Feet => True);
            for K in 1 .. Plan_N loop
               for X in Integer (Plan_Run (K).X0) .. Integer (Plan_Run (K).X1) loop
                  for D in 1 .. 4 loop
                     declare
                        Nx : constant Integer := X + Dx (D);
                        Ny : constant Integer := Integer (Plan_Run (K).Y) + Dy (D);
                        Zn : Integer;
                     begin
                        if Along (Nx, Ny) >= H or else Across (Nx, Ny) >= H then
                           Zn := Top_By (Nx, Ny, Level);
                           if Zn >= 0 and then abs (Zn - Level) <= Castle.Nav.Climb_B
                             and then Class_Of (Mat (Nx, Ny, Zn + 1)) /= Liquid
                             and then Mat (Nx, Ny, Zn + 1) not in Trunk
                           then
                              Ways := Ways + 1;
                           end if;
                        end if;
                     end;
                  end loop;
               end loop;
            end loop;
            if Ways < 8 then
               Square_Refused := Cut_Off;
               Plan_N := 0;
               Plan_Blocks := 0;
            elsif Outside_On and then Walls_On then
               --  its walls' strips, and the ground its path lies on beyond them: none of it under
               --  water, ground under all of it (what lies within its plain ring was looked at above)
               Forecast_Strips (P, P.Level_Row);
               if (for some S in 1 .. 4 => P.Strip (S) > 0) then
                  declare
                     G : constant Square_Geo := (Mx => P.Middle.X, My => P.Middle.Y, Aslant => Aslant,
                                                 Half => H, Strip => P.Strip);
                     Far : constant Float := (Out_H + Float (Strip_Most) * 0.25) * (abs Ex + abs Ey);
                  begin
                     Shifted :
                     for X in B (P.Middle.X - Far) .. B (P.Middle.X + Far) loop
                        for Y in B (P.Middle.Y - Far) .. B (P.Middle.Y + Far) loop
                           if (Along (X, Y) >= Out_H or else Across (X, Y) >= Out_H)
                             and then Part_Of (G, X, Y) /= Part_None
                           then
                              declare
                                 Zr : constant Integer := Top_By (X, Y, Zc);
                              begin
                                 if Zr < 0 then
                                    Square_Refused := Too_Uneven;
                                    Square_Off_Cm := 600;
                                 elsif Class_Of (Mat (X, Y, Zr + 1)) = Liquid then
                                    Square_Refused := Water_On_It;
                                    Square_In_Way := ((Float (X) + 0.5) * 0.25, (Float (Y) + 0.5) * 0.25, 0.0);
                                 end if;
                              end;
                              exit Shifted when Square_Refused /= Square_Ok;
                           end if;
                        end loop;
                     end loop Shifted;
                  end;
                  if Square_Refused /= Square_Ok then
                     Plan_N := 0;
                     Plan_Blocks := 0;
                  end if;
               end if;
            end if;
         end;
      end if;
   end Plan_Square_Lot;

   function Plan_Square (Middle : Vec3; Way : Way_Index) return Square_Plan is
      P : Square_Plan := Square_At (Middle, Way);
   begin
      Plan_Square_Lot (P);
      P.Ok := Square_Refused = Square_Ok;
      return P;
   end Plan_Square;

   procedure Place_Square (Middle : Vec3; Way : Way_Index; Band_Size : Positive; Seed : Castle.Hash.U64) is
      Plain : constant Square_Plan := Square_At (Middle, Way);      --  (its path's plain ring: the zone's frame)
      P : Square_Plan := Plain;
      Laid : Natural;
   begin
      Plan_Square_Lot (P);
      if Square_Refused /= Square_Ok then
         return;
      end if;
      --  the colony founded there: no post, the stake's place the fire's
      if Fire_Ground_On then
         --  (on the ground the plan read under whatever stands or hangs over its middle; a tree's foot
         --  on the fire's own block column, which is felled before anything is made there: the
         --  ground beside it, of the four columns that meet at the middle)
         declare
            Cx : constant Integer := Integer (Float'Floor (P.Middle.X * 4.0 + 0.5));
            Cy : constant Integer := Integer (Float'Floor (P.Middle.Y * 4.0 + 0.5));
            Zf : Integer := Top_By (Cx, Cy, B (P.Middle.Z) - 1);
         begin
            if Zf >= 0 and then Mat (Cx, Cy, Zf + 1) in Trunk then
               declare
                  Beside : Integer := -1;
               begin
                  for Dx in -1 .. 0 loop
                     for Dy in -1 .. 0 loop
                        declare
                           Zn : constant Integer := Top_By (Cx + Dx, Cy + Dy, Zf + 2);
                        begin
                           if Zn >= 0 and then Mat (Cx + Dx, Cy + Dy, Zn + 1) not in Trunk then
                              Beside := Integer'Max (Beside, Zn);
                           end if;
                        end;
                     end loop;
                  end loop;
                  Zf := (if Beside >= 0 then Beside else Zf + 2);
               end;
            end if;
            if Zf >= 0 then
               Place_Stake ((P.Middle.X, P.Middle.Y, Float (Zf + 1) * 0.25), Band_Size, Seed, Post => False,
                            As_Read => True);
            end if;
         end;
      else
         Place_Stake (P.Middle, Band_Size, Seed, Post => False);
      end if;
      if not Stake_Set then
         Square_Refused := No_Ground_For_It;
         return;
      end if;
      Camp_Set := True;
      Camp_Square := True;
      --  (under the rule only where its walls are built at all: a square founded with them off is as
      --  squares were before there were any)
      Square_Outside := Outside_On and then Walls_On and then Labour_On and then Level_On;
      Square_Strip := (if Square_Outside then P.Strip else [others => 0]);
      Camp_At := Stake_At;
      Camp_Level := -1;
      New_Camp_Zone;
      Take_Plan (Camp_Zone_N);
      Zones (Camp_Zone_N).Placed := True;
      Zones (Camp_Zone_N).Fx := Integer (Float'Rounding (Plain.Ring (1).X * 4.0));
      Zones (Camp_Zone_N).Fy := Integer (Float'Rounding (Plain.Ring (1).Y * 4.0));
      Zones (Camp_Zone_N).Way := Way;
      Zones (Camp_Zone_N).Along_B := (if Way mod 2 = 0 then 2 * New_Ring_B else New_Diag_B);
      --  the trees that stand on it are known from the first (they are found as a stack is looked
      --  through, which is later: the band fells them, and its camp is not built while one stands)
      if Find_Src /= null then
         for CX in Floor_Div (B (P.Middle.X - Square_Side_Now), Chunk_B) .. Floor_Div (B (P.Middle.X + Square_Side_Now), Chunk_B)
         loop
            for CY in Floor_Div (B (P.Middle.Y - Square_Side_Now), Chunk_B)
              .. Floor_Div (B (P.Middle.Y + Square_Side_Now), Chunk_B)
            loop
               if CX >= 0 and then CY >= 0 then
                  Index_Trees (CX, CY);
               end if;
            end loop;
         end loop;
      end if;
      --  what is soft on its floor is cleared at the founding, bushes and what hangs low over it of a
      --  tree, as far up as a serf needs under it once it is made: nothing is left on it but a
      --  boulder and a tree's foot (a tree is felled by the band; with Set_Square_Fell off it stays,
      --  its foot not the square's ground).  (A bush left where the floor is filled up round it stands
      --  in a hole a serf drops into and cannot climb out of.)
      Camp_Level := (if Labour_On and then Level_On then Choose_Level else -1);
      --  (its strips were judged against the level it was planned at: the level it is founded at)
      pragma Assert (P.Level_Row < 0 or else Camp_Level = P.Level_Row,
                     "a square is founded at the level it was planned at");
      for K in Zones (Camp_Zone_N).First + 1 .. Zones (Camp_Zone_N).First + Zones (Camp_Zone_N).N loop
         for X in Integer (Runs (K).X0) .. Integer (Runs (K).X1) loop
            if Mat (X, Integer (Runs (K).Y), Integer (Runs (K).Z) + 1) not in Trunk then      --  (not a tree's own foot)
               for Z in Integer (Runs (K).Z) + 1
                 .. Integer'Max (Integer (Runs (K).Z), Camp_Level) + Castle.Nav.Head_B + 1
               loop
                  if Mat (X, Integer (Runs (K).Y), Z) in Crown | Berry_Bush | Bare_Bush
                    or else Mat (X, Integer (Runs (K).Y), Z) in Trunk
                  then
                     Write_Src (X, Integer (Runs (K).Y), Z, Air_Block);
                  end if;
               end loop;
            end if;
         end loop;
      end loop;
      --  and on the strips kept for its walls: a bush left standing there would stand between its
      --  floor and its path where no wall comes to be built
      if Square_Outside and then (for some S in 1 .. 4 => Square_Strip (S) > 0) then
         declare
            G   : constant Square_Geo := Geo_Now;
            Far : constant Integer := B (Square_Side_Now) + 4;
         begin
            for X in B (Camp_At.X) - Far .. B (Camp_At.X) + Far loop
               for Y in B (Camp_At.Y) - Far .. B (Camp_At.Y) + Far loop
                  if Part_Of (G, X, Y) = Part_Strip then
                     declare
                        Zr : constant Integer := Top_By (X, Y, Integer'Max (1, Camp_Level));
                     begin
                        if Zr >= 0 and then Mat (X, Y, Zr + 1) not in Trunk then
                           for Z in Zr + 1 .. Integer'Max (Zr, Camp_Level) + Castle.Nav.Head_B + 1 loop
                              if Mat (X, Y, Z) in Crown | Berry_Bush | Bare_Bush or else Mat (X, Y, Z) in Trunk then
                                 Write_Src (X, Y, Z, Air_Block);
                              end if;
                           end loop;
                        end if;
                     end;
                  end if;
               end loop;
            end loop;
         end;
      end if;
      if Labour_On then
         --  marked: the band builds it
         Zones (Camp_Zone_N).Built := False;
         Zones (Camp_Zone_N).Got := [others => 0];
         Check_Built;
      else
         --  as a camp was with its labour off: it stands at once, what grows on it cut
         Clear_Plan;
         Finish_Camp (Tread => False);
      end if;
      --  its path round it, from corner to corner (beyond its strips, where it has any): at the
      --  square's level, where that is chosen
      for K in 1 .. 4 loop
         declare
            A : Vec3 := Line_Point (P.Ring (K).X, P.Ring (K).Y, Stake_At.Z);
            C : Vec3 := Line_Point (P.Ring (K mod 4 + 1).X, P.Ring (K mod 4 + 1).Y, Stake_At.Z);
         begin
            if Camp_Level >= 0 then
               A.Z := Float (Camp_Level + 1) * 0.25;
               C.Z := Float (Camp_Level + 1) * 0.25;
            end if;
            Lay_Path (A, C, Laid);
         end;
      end loop;
   end Place_Square;

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
     ((Centre => Cells (K).Centre, Kind => Cells (K).Kind, Count => Cells (K).Count, Turn => Cells (K).Turn,
       Overflow => Cells (K).Overflow, Closed => Cells (K).Closed, Fit => Cells (K).Fit, Made => Cells (K).Made,
       Second => Cells (K).Second,
       Wall => Fit_Wall (K)));
   function Store_Counts return Store_Stats is (Store_Now);

   ------------------------------------------------------------------ housing: zoning

   Housing_Too_Far  : Boolean := False;    --  the last strip planned for housing reaches further from the stake
                                           --  than ground can be kept in
   Housing_Is_Housing : Boolean := False;  --  or lies wholly on ground that is housing already
   Housing_Open     : Boolean := False;    --  the last fill planned was of ground that paths do not close round
   Housing_No_Path  : Boolean := False;    --  or of ground no path lies beside
   Plan_Hovels      : Natural := 0;        --  how many more hovels there would be room for
   --  the housing zones the planned strip overlaps or touches: it is taken into the first of them, and the rest with it
   Plan_Join        : array (1 .. Max_Zones) of Natural := [others => 0];
   Plan_Join_N      : Natural := 0;
   Joined_Last      : Natural := 0;        --  how many the last zoning was combined with
   Zoned_Last       : Natural := 0;        --  the housing zone the last zoning made, or added to

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

   Houses_Razed : Natural := 0;                      --  (a measure, not saved)
   Razed_Back   : Per_Kind := [others => 0];         --  and what came back to the stores of them
   function Razed return Natural is (Houses_Razed);
   function Razed_Came_Back (K : Item_Kind) return Natural is (Razed_Back (K));

   --  A house's lot holds block column (X, Y): its ground stays its zone's.
   function In_Lot (F : CB.House; X, Y : Integer) return Boolean is
      P : constant Vec3 := ((Float (X) + 0.5) * 0.25, (Float (Y) + 0.5) * 0.25, 0.0);
      U : constant Integer := Integer (Float'Rounding (Frame_U (F, P)));
      V : constant Integer := Integer (Float'Rounding (Frame_V (F, P)));
   begin
      return U in -Lot_Left (F) .. F.W - 1 + Lot_Right (F) and then V in V_Lo .. Lot_Back (F);
   end In_Lot;

   function Hovel_At (X, Y : Float) return Natural is
   begin
      for H in 1 .. N_Houses loop
         if not Is_Store (Houses (H).F) and then In_Lot (Houses (H).F, B (X), B (Y)) then
            return H;
         end if;
      end loop;
      return 0;
   end Hovel_At;

   procedure Mark_Hovel (H : Positive; On : Boolean) is
   begin
      if H > N_Houses or else Is_Store (Houses (H).F) or else Houses (H).Raze = On then
         return;
      end if;
      if On and then Houses (H).Owner /= 0 then
         return;                               --  (lived in: John, 2026-11-19, "limit razing buildings to unowned")
      end if;
      Houses (H).Raze := On;
      if On and then Houses (H).Built then
         --  (it is taken down as it was put up, the other way: a house being built, at its last block)
         Houses (H).Built := False;
         Houses (H).Placed := Houses (H).Total;
         Houses (H).Bed := False;
      end if;
      --  (the mark lifted: a house being built again, from what of it stands and what of it lies there)
      Zones_Ver := Zones_Ver + 1;
   end Mark_Hovel;

   Unzone_Left : Natural := 0;
   function Unzone_Lived_In return Natural is (Unzone_Left);

   procedure Unzone_Box (X0, Y0, X1, Y1 : Float; Mark : Boolean; Columns : out Natural; Marked : out Natural;
                         Only : access function (X, Y : Integer) return Boolean := null)
   is
      Bx0 : constant Integer := B (Float'Min (X0, X1));
      Bx1 : constant Integer := B (Float'Max (X0, X1));
      By0 : constant Integer := B (Float'Min (Y0, Y1));
      By1 : constant Integer := B (Float'Max (Y0, Y1));
      function Kept (X, Y : Integer) return Boolean is
        (for some H in 1 .. N_Houses => In_Lot (Houses (H).F, X, Y));
   begin
      Columns := 0;
      Marked := 0;
      --  a hovel any of whose lot's ground is in the box is marked, and keeps its lot
      Unzone_Left := 0;
      if Mark then
         for H in 1 .. N_Houses loop
            if not Is_Store (Houses (H).F) and then not Houses (H).Raze
              and then (for some X in Bx0 .. Bx1 => (for some Y in By0 .. By1 => In_Lot (Houses (H).F, X, Y)))
            then
               if Houses (H).Owner = 0 then
                  Mark_Hovel (H, True);
                  Marked := Marked + 1;
               else
                  Unzone_Left := Unzone_Left + 1;      --  (lived in: it stays, and keeps its lot)
               end if;
            end if;
         end loop;
      end if;
      for Z0 in 1 .. N_Zones loop
         if Zones (Z0).Kind = Habitation_Zone and then Zones (Z0).N > 0
           and then Zones (Z0).Bx0 <= Bx1 and then Zones (Z0).Bx1 >= Bx0
           and then Zones (Z0).By0 <= By1 and then Zones (Z0).By1 >= By0
         then
            declare
               Old   : constant Run_List (1 .. Zones (Z0).N) :=
                 Run_List (Runs (Zones (Z0).First + 1 .. Zones (Z0).First + Zones (Z0).N));
               Fresh : Run_List (1 .. Zones (Z0).Blocks + 1);
               N     : Natural := 0;
               Gone  : Natural := 0;
            begin
               for R of Old loop
                  for X in Integer (R.X0) .. Integer (R.X1) loop
                     if Integer (R.Y) in By0 .. By1 and then X in Bx0 .. Bx1
                       and then (Only = null or else Only (X, Integer (R.Y)))      --  (of the box, only those)
                       and then not Kept (X, Integer (R.Y))
                     then
                        Gone := Gone + 1;
                     elsif N > 0 and then Fresh (N).Y = R.Y and then Fresh (N).Z = R.Z
                       and then Integer (Fresh (N).X1) + 1 = X
                     then
                        Fresh (N).X1 := Integer_16 (X);
                     else
                        N := N + 1;
                        Fresh (N) := (Y => R.Y, X0 => Integer_16 (X), X1 => Integer_16 (X), Z => R.Z);
                     end if;
                  end loop;
               end loop;
               if Gone > 0 and then N_Runs - Old'Length + N <= Max_Zone_Runs then
                  --  its old strips out of the list, the new ones on the end (as Read_Zone_Ground)
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
                  Columns := Columns + Gone;
               end if;
            end;
         end if;
      end loop;
      if Columns > 0 then
         Zones_Ver := Zones_Ver + 1;
         Count_Housing;
         Plan_Lots;               --  (the lots still to begin, laid out anew on what is left)
      end if;
   end Unzone_Box;

   procedure Unzone_Housing (X0, Y0, X1, Y1 : Float; Columns : out Natural; Marked : out Natural) is
   begin
      Unzone_Box (X0, Y0, X1, Y1, True, Columns, Marked);
   end Unzone_Housing;

   --  A hovel taken down to nothing is gone: what half of what lay there
   --  comes to goes to the stores (John's call, as it was put to him:
   --  "half of what it took comes back"), a ladder standing at it too; its
   --  record leaves the list, every house after it one number lower (the
   --  builders' sites, the ladders they go for, the storehouse's number);
   --  and its lot is no zone's any more.
   procedure Remove_House (H : Positive) is
      Was  : constant House_Rec := Houses (H);
      F    : CB.House renames Was.F;
      Got, Columns, Marked : Natural;
      C1 : constant Vec3 := H_Point (F, Float (-Lot_Left (F)), Float (V_Lo));
      C2 : constant Vec3 := H_Point (F, Float (F.W - 1 + Lot_Right (F)), Float (Lot_Back (F)));
   begin
      for K in Item_Kind loop
         if K in Wood | Straw and then Was.Lying (K) > 0 then
            Supply (K, Was.Lying (K) / Blocks_Per (K) / 2, Got);
            Razed_Back (K) := Razed_Back (K) + Got;
         end if;
      end loop;
      if Was.Ladder > 0 then
         Supply (Ladder, 1, Got);
         if Got = 0 then
            N_Ladders_Lost := N_Ladders_Lost + 1;
         end if;
      end if;
      for I in 1 .. N_Members loop
         declare
            M : Member renames Band (I);
         begin
            if M.Site = H then
               M.Site := 0;
               M.Site_Patch := 0;
               if M.State in To_Site | Raising then
                  M.State := Idle;
                  M.Wait := 0.2;
               end if;
            elsif M.Site > H then
               M.Site := M.Site - 1;
            end if;
            if M.Ladder_Of = H then
               M.Ladder_Of := 0;
               if M.State = To_Ladder then
                  M.State := Idle;
                  M.Wait := 0.2;
               end if;
            elsif M.Ladder_Of > H then
               M.Ladder_Of := M.Ladder_Of - 1;
            end if;
            --  (what it remembers of not getting to a house goes by the house's number: forgotten)
            for Fl of M.Fails loop
               if Fl.Bush in Site_Fail + 1 .. Site_Fail + Max_Houses | Ladder_Fail + 1 .. Ladder_Fail + Max_Houses then
                  Fl.Until_Tick := 0;
               end if;
            end loop;
         end;
      end loop;
      for K in H .. N_Houses - 1 loop
         Houses (K) := Houses (K + 1);
      end loop;
      Houses (N_Houses) := (others => <>);
      N_Houses := N_Houses - 1;
      if Store_House > H then
         Store_House := Store_House - 1;
      end if;
      BP_Of := 0;                                --  (the blueprint held is of a number that has moved)
      Houses_Razed := Houses_Razed + 1;
      Unzone_Box (Float'Min (C1.X, C2.X), Float'Min (C1.Y, C2.Y), Float'Max (C1.X, C2.X), Float'Max (C1.Y, C2.Y),
                  False, Columns, Marked);
      Zones_Ver := Zones_Ver + 1;
   end Remove_House;

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
      for J in 1 .. Plan_Join_N loop
         Bx0 := Integer'Min (Bx0, Zones (Plan_Join (J)).Bx0);
         Bx1 := Integer'Max (Bx1, Zones (Plan_Join (J)).Bx1);
         By0 := Integer'Min (By0, Zones (Plan_Join (J)).By0);
         By1 := Integer'Max (By1, Zones (Plan_Join (J)).By1);
      end loop;
      Housing_Too_Far := Far_Of (Bx0, By0, Bx1, By1) > Far_Reach_Max_M;
      if Housing_Too_Far then
         return 0;
      end if;
      if Bx1 - Bx0 >= Max_Plan_B or else By1 - By0 >= Max_Plan_B then
         return 0;                           --  (Plan_Housing_Lot sees to it that this is never so)
      end if;
      Lot_Open (Bx0, By0, Bx1, By1);
      for K in 1 .. Plan_N loop
         Lot_Run (Plan_Run (K));
      end loop;
      for J in 1 .. Plan_Join_N loop
         for K in Zones (Plan_Join (J)).First + 1 .. Zones (Plan_Join (J)).First + Zones (Plan_Join (J)).N loop
            Lot_Run (Runs (K));
         end loop;
      end loop;
      for H in 1 .. N_Houses loop
         Lot_Take (Houses (H).F);
      end loop;
      --  (the next houses in turn, as they are begun: the count ends at the
      --  first that does not fit)
      while N_Houses + N < Max_Houses loop
         Place_House (House_Serial + N + 1, F, Key, Ok);
         exit when not Ok;
         Lot_Take (F);
         N := N + 1;
      end loop;
      return N;
   end Planned_Hovels;

   --  The straight run of path that stretch K is of: the stretches that
   --  carry on from it end to end in a line (a path is recorded a stretch
   --  at a time: a stretch's joint is not an end or a turn of the path).
   --  From: one end of it; (Tx, Ty): the way it runs from there; Len: how
   --  long it is.
   Of_Run : array (1 .. Max_Paths) of Boolean := [others => False];   --  (which stretches the last run asked for is of)

   procedure Run_Of (K : Positive; From : out Vec3; Tx, Ty, Len : out Float) is
      A    : Vec3 := Path_List (K).A;
      Bp   : Vec3 := Path_List (K).B;
      L0   : constant Float := Flat_Dist (A, Bp);
      Grew : Boolean := L0 > 0.01;
      Turns : Natural := 0;
   begin
      From := A;
      Tx := 1.0;
      Ty := 0.0;
      Len := L0;
      Of_Run := [others => False];
      Of_Run (K) := True;
      if L0 <= 0.01 then
         return;
      end if;
      Tx := (Bp.X - A.X) / L0;
      Ty := (Bp.Y - A.Y) / L0;
      while Grew and then Turns <= N_Paths loop
         Grew := False;
         Turns := Turns + 1;
         for J in 1 .. N_Paths loop
            declare
               S  : Path_Seg renames Path_List (J);
               L  : constant Float := Flat_Dist (S.A, S.B);
               function Ahead (P, Of_P : Vec3) return Float is ((P.X - Of_P.X) * Tx + (P.Y - Of_P.Y) * Ty);
               Joined : Boolean := False;
            begin
               if L > 0.01 and then abs Ahead (S.B, S.A) >= Run_Straight * L then
                  if Flat_Dist (S.A, Bp) < Run_Joint_M and then Ahead (S.B, Bp) > Run_Joint_M then
                     Bp := S.B;
                     Joined := True;
                  elsif Flat_Dist (S.B, Bp) < Run_Joint_M and then Ahead (S.A, Bp) > Run_Joint_M then
                     Bp := S.A;
                     Joined := True;
                  elsif Flat_Dist (S.B, A) < Run_Joint_M and then Ahead (S.A, A) < -Run_Joint_M then
                     A := S.A;
                     Joined := True;
                  elsif Flat_Dist (S.A, A) < Run_Joint_M and then Ahead (S.B, A) < -Run_Joint_M then
                     A := S.B;
                     Joined := True;
                  end if;
                  if Joined then
                     Grew := True;
                     Of_Run (J) := True;
                  end if;
               end if;
            end;
         end loop;
      end loop;
      From := A;
      Len := Flat_Dist (A, Bp);
      Tx := (Bp.X - A.X) / Len;
      Ty := (Bp.Y - A.Y) / Len;
   end Run_Of;

   --  What every plan for housing ends with, its ground worked out: nothing
   --  of it to take, no room for another zone, housing too large to be
   --  worked out over as one (it is left as it is, and this is a zone
   --  beside it), ground too far from the stake; and how many hovels it
   --  would hold (Count: worked out by placing them, for a zoning and not
   --  for every frame a pull is shown).
   procedure Close_Housing_Plan (Count : Boolean) is
   begin
      if Plan_Refused = Lot_Ok and then Plan_N = 0 then
         Plan_Refused := No_Ground;
         Housing_Is_Housing := Plan_Join_N > 0;
      elsif Plan_Refused = Lot_Ok and then Plan_Join_N = 0 and then not Zone_Room then
         Plan_Refused := No_Room;
      end if;
      if Plan_Refused = Lot_Ok then
         --  housing too large to be worked out over as one is left as it is, and this is a zone beside it
         declare
            Bx0, By0 : Integer := Integer'Last;
            Bx1, By1 : Integer := Integer'First;
         begin
            for K in 1 .. Plan_N loop
               Bx0 := Integer'Min (Bx0, Integer (Plan_Run (K).X0));
               Bx1 := Integer'Max (Bx1, Integer (Plan_Run (K).X1));
               By0 := Integer'Min (By0, Integer (Plan_Run (K).Y));
               By1 := Integer'Max (By1, Integer (Plan_Run (K).Y));
            end loop;
            for J in 1 .. Plan_Join_N loop
               Bx0 := Integer'Min (Bx0, Zones (Plan_Join (J)).Bx0);
               Bx1 := Integer'Max (Bx1, Zones (Plan_Join (J)).Bx1);
               By0 := Integer'Min (By0, Zones (Plan_Join (J)).By0);
               By1 := Integer'Max (By1, Zones (Plan_Join (J)).By1);
            end loop;
            if Bx1 - Bx0 >= Max_Plan_B or else By1 - By0 >= Max_Plan_B then
               Plan_Join_N := 0;
               if not Zone_Room then
                  Plan_Refused := No_Room;
               end if;
            end if;
            Housing_Too_Far := Far_Of (Bx0, By0, Bx1, By1) > Far_Reach_Max_M;
         end;
      end if;
      --  (how many hovels it would hold is worked out by placing them: for
      --  a zoning, not for every frame a pull is shown)
      if Plan_Refused = Lot_Ok and then not Housing_Too_Far and then Count then
         Plan_Hovels := Planned_Hovels;
      end if;
      if Plan_Refused /= Lot_Ok or else Housing_Too_Far then      --  nothing to show of a strip that is refused
         Plan_N := 0;
         Plan_Blocks := 0;
         Plan_Join_N := 0;
      end if;
   end Close_Housing_Plan;

   --  The plan for housing begun at (X0, Y0) and pulled to (X1, Y1): a
   --  strip along the straight run of the path nearest where it was begun,
   --  on that side of it, from the path's edge as far back as a hovel takes
   --  (Housing_Deep_M, and more beside a path that runs aslant, since a
   --  house stands square to the block grid), between the two points along
   --  the path, and no further than Housing_Past_B past an end or a turn of
   --  it.  Its ground is every block column of that strip that is free;
   --  those that are housing already, and any housing its ground touches,
   --  are what it is to be combined with (Plan_Join).
   procedure Plan_Housing_Lot (X0, Y0, X1, Y1 : Float; Count : Boolean := True; Seg : Natural := 0) is
      P0     : constant Vec3 := (X0, Y0, 0.0);
      Half   : constant Float := Path_Width_M / 2.0;
      Best   : Natural := 0;
      Best_D : Float := Float'Last;
      From   : Vec3;
      Tx, Ty, Len : Float;
   begin
      Housing_Too_Far := False;
      Housing_Is_Housing := False;
      Housing_Open := False;
      Housing_No_Path := False;
      Plan_Hovels := 0;
      Plan_Join_N := 0;
      Plan_N := 0;
      Plan_Blocks := 0;
      Plan_Cells_N := 0;
      Plan_Under_N := 0;
      Plan_At_Path := False;
      Plan_Turn := 0.0;
      Plan_Corner := [others => P0];
      if Seg in 1 .. N_Paths then
         --  (a pull with its path: it lies along that stretch, whichever is nearest where it was begun)
         Best := Seg;
         Best_D := 0.0;
      else
         for K in 1 .. N_Paths loop
            if Seg_Dist (P0, Path_List (K)) < Best_D then
               Best_D := Seg_Dist (P0, Path_List (K));
               Best := K;
            end if;
         end loop;
      end if;
      if Best = 0 or else Best_D > Housing_Snap_M then
         Plan_Refused := Off_Path;
         return;
      end if;
      Run_Of (Best, From, Tx, Ty, Len);
      declare
         function Along (X, Y : Float) return Float is ((X - From.X) * Tx + (Y - From.Y) * Ty);
         function Left (X, Y : Float) return Float is ((Y - From.Y) * Tx - (X - From.X) * Ty);
         Side : constant Float :=
           (if abs Left (X0, Y0) > 0.05 then (if Left (X0, Y0) > 0.0 then 1.0 else -1.0)
            elsif Left (X1, Y1) < 0.0 then -1.0 else 1.0);
         Past : constant Float := Float (Housing_Past_B) * 0.25;
         A0   : constant Float := Along (X0, Y0);
         A1   : constant Float := Along (X1, Y1);
         Lo   : Float := Float'Max (Float'Min (A0, A1), -Past);
         Hi   : Float := Float'Min (Float'Max (A0, A1), Len + Past);
         Deep : constant Float := Half + Housing_Deep_M * (abs Tx + abs Ty);
         function Wx (A, Off : Float) return Float is (From.X + A * Tx - Off * Side * Ty);
         function Wy (A, Off : Float) return Float is (From.Y + A * Ty + Off * Side * Tx);
      begin
         if Hi - Lo > Housing_Long_M then           --  (pulled further than one zoning goes: as far as that)
            if A0 <= A1 then
               Hi := Lo + Housing_Long_M;
            else
               Lo := Hi - Housing_Long_M;
            end if;
         end if;
         if Hi - Lo < 0.25 then                     --  begun and ended past the same end of the path
            Plan_Refused := Off_Path;
            return;
         end if;
         Plan_Corner := [(Wx (Lo, Half), Wy (Lo, Half), 0.0), (Wx (Hi, Half), Wy (Hi, Half), 0.0),
                         (Wx (Hi, Deep), Wy (Hi, Deep), 0.0), (Wx (Lo, Deep), Wy (Lo, Deep), 0.0)];
         declare                                    --  the way it lies, within 45 degrees of east, as every lot's is
            Dx : Float := Tx;
            Dy : Float := Ty;
            T  : Float;
         begin
            for Turn in 1 .. 3 loop
               exit when Dx > 0.0 and then abs Dy <= Dx;
               T := Dx;
               Dx := Dy;
               Dy := -T;
            end loop;
            Plan_Turn := Arctan (Dy, Dx);
         end;
         declare
            X_Lo : constant Float := Float'Min (Float'Min (Wx (Lo, 0.0), Wx (Hi, 0.0)), Float'Min (Wx (Lo, Deep), Wx (Hi, Deep)));
            X_Hi : constant Float := Float'Max (Float'Max (Wx (Lo, 0.0), Wx (Hi, 0.0)), Float'Max (Wx (Lo, Deep), Wx (Hi, Deep)));
            Y_Lo : constant Float := Float'Min (Float'Min (Wy (Lo, 0.0), Wy (Hi, 0.0)), Float'Min (Wy (Lo, Deep), Wy (Hi, Deep)));
            Y_Hi : constant Float := Float'Max (Float'Max (Wy (Lo, 0.0), Wy (Hi, 0.0)), Float'Max (Wy (Lo, Deep), Wy (Hi, Deep)));
            Gx0  : constant Integer := B (X_Lo) - 1;
            Gy0  : constant Integer := B (Y_Lo) - 1;
            W    : constant Integer := B (X_Hi) + 1 - Gx0 + 1;
            H    : constant Integer := B (Y_Hi) + 1 - Gy0 + 1;
            G    : Plan_Grid renames Plan_G.all;
            --  a block column of the strip, as it is worked out: nothing of
            --  it (Not_It), housing already (Is_Housing; Was_Housing once the
            --  fill has reached it), free ground not yet reached (Seen_Base
            --  less the row of its top), or free ground reached (that row)
            Not_It      : constant Integer_16 := -2;
            Is_Housing  : constant Integer_16 := -3;
            Was_Housing : constant Integer_16 := -4;
            Seen_Base   : constant Integer_16 := -16;
            Near_Seg : array (1 .. Max_Paths) of Positive;
            N_Near   : Natural := 0;

            function Mid (Bx, By : Integer) return Vec3 is ((Float (Bx) + 0.5) * 0.25, (Float (By) + 0.5) * 0.25, 0.0);

            function Path_Here (P : Vec3) return Boolean is
              (for some K in 1 .. N_Near => Seg_Dist (P, Path_List (Near_Seg (K))) <= Half);

            procedure Join (Z : Positive) is
            begin
               if Zones (Z).Kind = Habitation_Zone and then (for all J in 1 .. Plan_Join_N => Plan_Join (J) /= Z) then
                  Plan_Join_N := Plan_Join_N + 1;
                  Plan_Join (Plan_Join_N) := Z;
               end if;
            end Join;

            --  the row of the free ground at a block column: nothing on it
            --  but what grows and can be cut (-1: none)
            function Free_Row (Bx, By, Near : Integer) return Integer is
               Zr : constant Integer := Ground_Row (Bx, By, Near);
            begin
               return (if Zr < 0 or else Mat (Bx, By, Zr) in Trunk
                         or else Mat (Bx, By, Zr + 1) not in Air | Tall_Grass | Wild_Grain | Wild_Vegetables
                       then -1 else Zr);
            end Free_Row;
         begin
            if W > Max_Plan_B or else H > Max_Plan_B then
               Plan_Refused := Too_Large;
               return;
            end if;
            for K in 1 .. N_Paths loop
               declare
                  S : Path_Seg renames Path_List (K);
               begin
                  if Float'Max (S.A.X, S.B.X) >= X_Lo - 1.0 and then Float'Min (S.A.X, S.B.X) <= X_Hi + 1.0
                    and then Float'Max (S.A.Y, S.B.Y) >= Y_Lo - 1.0 and then Float'Min (S.A.Y, S.B.Y) <= Y_Hi + 1.0
                  then
                     N_Near := N_Near + 1;
                     Near_Seg (N_Near) := K;
                  end if;
               end;
            end loop;
            --  what each block column of the strip is: free ground (the row
            --  of its top), housing already (Is_Housing), or neither
            for Y in 0 .. H - 1 loop
               for X in 0 .. W - 1 loop
                  declare
                     P   : constant Vec3 := Mid (Gx0 + X, Gy0 + Y);
                     A   : constant Float := Along (P.X, P.Y);
                     Off : constant Float := Left (P.X, P.Y) * Side;
                     Row : Integer := -1;
                     Z, Zr : Integer;
                  begin
                     G (X, Y) := Not_It;
                     --  (past an end of its path, from the line of the path's edge: not round
                     --  the end of the path to its middle (John, 2026-11-17: "The end of a zone
                     --  wraps around the end of a path if it extends past it"))
                     if A >= Lo and then A < Hi and then Off > (if A < 0.0 or else A > Len then Half else 0.0)
                       and then Off < Deep
                     then
                        if Path_Here (P) then
                           Plan_At_Path := True;
                        elsif Strip_Kept (Gx0 + X, Gy0 + Y) then
                           null;                          --  (kept for the square's wall: none of its ground)
                        else
                           Zone_Of_Block (Gx0 + X, Gy0 + Y, Z, Zr);
                           if Z /= 0 then
                              if Zones (Z).Kind = Habitation_Zone then
                                 G (X, Y) := Is_Housing;
                              end if;
                           else
                              --  (the ground beside it is the best guess at where this column's is)
                              if X > 0 and then G (X - 1, Y) <= Seen_Base then
                                 Row := Free_Row (Gx0 + X, Gy0 + Y, Integer (Seen_Base - G (X - 1, Y)));
                              elsif Y > 0 and then G (X, Y - 1) <= Seen_Base then
                                 Row := Free_Row (Gx0 + X, Gy0 + Y, Integer (Seen_Base - G (X, Y - 1)));
                              else
                                 declare
                                    Sz : constant Float := Castle.Nav.Surface_Z (P.X, P.Y);
                                 begin
                                    Row := (if Sz >= 0.0 then Free_Row (Gx0 + X, Gy0 + Y, B (Sz) - 1) else -1);
                                 end;
                              end if;
                              if Row >= 0 then
                                 G (X, Y) := Seen_Base - Integer_16 (Row);     --  free, not yet reached
                              end if;
                           end if;
                        end if;
                     end if;
                  end;
               end loop;
            end loop;
            --  its ground is what of that can be got to from the edge of its
            --  own path without crossing a path, another kind of zone or
            --  anything standing: out from the strip's front, a block at a
            --  time to the four sides, through free ground and housing.
            --  The front is the ground beside the path itself, where no
            --  other path lies nearer: what is past an end or a turn of the
            --  path is reached from there or not at all (John, 2026-11-12:
            --  "a slice of the habitation zone passes over the connecting
            --  road": begun from the whole front, the seven blocks past a
            --  turn were taken on the far side of the road that led off it)
            declare
               --  beside its own path, and no other path nearer
               function Fronts_Own (P : Vec3) return Boolean is
                  Own, Other : Float := Float'Last;
               begin
                  for K in 1 .. N_Near loop
                     declare
                        D : constant Float := Seg_Dist (P, Path_List (Near_Seg (K)));
                     begin
                        if Of_Run (Near_Seg (K)) then
                           Own := Float'Min (Own, D);
                        else
                           Other := Float'Min (Other, D);
                        end if;
                     end;
                  end loop;
                  return Other >= Own;
               end Fronts_Own;
               Queue : Plan_Spots renames Plan_Q.all;
               Head, Tail : Natural := 0;
               procedure Reach (X, Y : Integer) is
                  Z, Zr : Integer;
               begin
                  if X not in 0 .. W - 1 or else Y not in 0 .. H - 1 then
                     return;
                  end if;
                  if G (X, Y) <= Seen_Base then
                     G (X, Y) := Seen_Base - G (X, Y);             --  free, and reached: the row of its top
                  elsif G (X, Y) = Is_Housing then
                     G (X, Y) := Was_Housing;
                     Zone_Of_Block (Gx0 + X, Gy0 + Y, Z, Zr);
                     if Z /= 0 then
                        Join (Z);
                     end if;
                  else
                     return;
                  end if;
                  Tail := Tail + 1;
                  Queue (Tail) := (Integer_16 (X), Integer_16 (Y));
               end Reach;
            begin
               for Y in 0 .. H - 1 loop
                  for X in 0 .. W - 1 loop
                     if G (X, Y) <= Seen_Base or else G (X, Y) = Is_Housing then
                        declare
                           P : constant Vec3 := Mid (Gx0 + X, Gy0 + Y);
                        begin
                           if Left (P.X, P.Y) * Side < Half + 0.75 and then Along (P.X, P.Y) >= 0.0
                             and then Along (P.X, P.Y) <= Len and then Fronts_Own (P)
                           then
                              Reach (X, Y);
                           end if;
                        end;
                     end if;
                  end loop;
               end loop;
               while Head < Tail loop
                  Head := Head + 1;
                  declare
                     X : constant Integer := Integer (Queue (Head).X);
                     Y : constant Integer := Integer (Queue (Head).Y);
                  begin
                     Reach (X + 1, Y);
                     Reach (X - 1, Y);
                     Reach (X, Y + 1);
                     Reach (X, Y - 1);
                  end;
               end loop;
            end;
            --  housing that its ground touches from outside the strip is combined with it too
            for Y in 0 .. H - 1 loop
               for X in 0 .. W - 1 loop
                  if G (X, Y) >= 0 then
                     for D in 1 .. 4 loop
                        declare
                           Nx : constant Integer := X + (case D is when 1 => 1, when 2 => -1, when others => 0);
                           Ny : constant Integer := Y + (case D is when 3 => 1, when 4 => -1, when others => 0);
                           Z, Zr : Integer;
                        begin
                           if Nx not in 0 .. W - 1 or else Ny not in 0 .. H - 1 or else G (Nx, Ny) = Not_It then
                              Zone_Of_Block (Gx0 + Nx, Gy0 + Ny, Z, Zr);
                              if Z /= 0 then
                                 Join (Z);
                              end if;
                           end if;
                        end;
                     end loop;
                  end if;
               end loop;
            end loop;
            --  its ground as strips: rows south to north, west to east in a row
            Plan_Refused := Lot_Ok;
            Rows :
            for Y in 0 .. H - 1 loop
               declare
                  X : Integer := 0;
               begin
                  while X < W loop
                     if G (X, Y) >= 0 then
                        declare
                           X_0 : constant Integer := X;
                           Zr  : constant Integer_16 := G (X, Y);
                        begin
                           while X + 1 < W and then G (X + 1, Y) = Zr loop
                              X := X + 1;
                           end loop;
                           if Plan_N = Max_Plan_Runs or else N_Runs + Plan_N >= Max_Zone_Runs then
                              Plan_Refused := No_Room;
                              exit Rows;
                           end if;
                           Plan_N := Plan_N + 1;
                           Plan_Run (Plan_N) := (Y => Integer_16 (Gy0 + Y), X0 => Integer_16 (Gx0 + X_0),
                                                 X1 => Integer_16 (Gx0 + X), Z => Zr);
                           Plan_Blocks := Plan_Blocks + X - X_0 + 1;
                        end;
                     end if;
                     X := X + 1;
                  end loop;
               end;
            end loop Rows;
         end;
      end;
      Close_Housing_Plan (Count);
   end Plan_Housing_Lot;

   --  The plan for housing all the ground inside a round of paths (John,
   --  2026-11-12: "it would be nice if player had a fill option for closed
   --  loop paths"): from the block column at (X, Y) out over free ground
   --  and housing, a block at a time to the four sides, until paths, other
   --  zones and whatever stands stop it on every side.  Ground it runs out
   --  over without being stopped (as far as a lot can be worked out over,
   --  or to ground that is not in) is not closed, and nothing is planned;
   --  nor where no path lies beside it.  Housing it meets is what it is to
   --  be combined with, as a strip's is.
   procedure Plan_Housing_Fill (X, Y : Float; Count : Boolean := True) is
      P0   : constant Vec3 := (X, Y, 0.0);
      Half : constant Float := Path_Width_M / 2.0;
      W    : constant := Max_Plan_B;
      Gx0  : constant Integer := B (X) - W / 2;
      Gy0  : constant Integer := B (Y) - W / 2;
      G    : Plan_Grid renames Plan_G.all;
      Unseen      : constant Integer_16 := -1;
      Not_It      : constant Integer_16 := -2;
      Was_Housing : constant Integer_16 := -4;
      Near_Seg : array (1 .. Max_Paths) of Positive;
      N_Near   : Natural := 0;
      Queue    : Plan_Spots renames Plan_Q.all;
      Head, Tail : Natural := 0;
      Open     : Boolean := False;

      function Mid (Bx, By : Integer) return Vec3 is ((Float (Bx) + 0.5) * 0.25, (Float (By) + 0.5) * 0.25, 0.0);
      function Path_Here (P : Vec3) return Boolean is
        (for some K in 1 .. N_Near => Seg_Dist (P, Path_List (Near_Seg (K))) <= Half);

      procedure Join (Z : Positive) is
      begin
         if (for all J in 1 .. Plan_Join_N => Plan_Join (J) /= Z) then
            Plan_Join_N := Plan_Join_N + 1;
            Plan_Join (Plan_Join_N) := Z;
         end if;
      end Join;

      --  Block column (Gx0 + Cx, Gy0 + Cy), come to from ground whose top is at row Near.
      procedure Reach (Cx, Cy, Near : Integer) is
         Bx : constant Integer := Gx0 + Cx;
         By : constant Integer := Gy0 + Cy;
         Z, Zr, Row : Integer;
      begin
         if Cx not in 0 .. W - 1 or else Cy not in 0 .. W - 1 then
            Open := True;                    --  out past what a lot can be worked out over
            return;
         end if;
         if G (Cx, Cy) /= Unseen then
            return;
         end if;
         G (Cx, Cy) := Not_It;
         --  (the player's plan: read from the ground that is held, the colony's own or not)
         if Version_Src (Integer (Float'Floor (Float (Bx) / 32.0)), Integer (Float'Floor (Float (By) / 32.0))) = 0 then
            Open := True;                    --  ground that is not in: nothing says what stops it there
            return;
         end if;
         if Path_Here (Mid (Bx, By)) then
            Plan_At_Path := True;
            return;
         end if;
         if Strip_Kept (Bx, By) then
            return;                          --  (kept for the square's wall: none of its ground, and not passed)
         end if;
         Zone_Of_Block (Bx, By, Z, Zr);
         if Z /= 0 then
            if Zones (Z).Kind /= Habitation_Zone then
               return;
            end if;
            Join (Z);
            G (Cx, Cy) := Was_Housing;
            Row := Zr;
         else
            Row := Ground_Row (Bx, By, Near);
            if Row < 0 or else Mat (Bx, By, Row) in Trunk
              or else Mat (Bx, By, Row + 1) not in Air | Tall_Grass | Wild_Grain | Wild_Vegetables
            then
               return;                       --  (whatever stands there: none of its ground, and not passed)
            end if;
            G (Cx, Cy) := Integer_16 (Row);
         end if;
         Tail := Tail + 1;
         Queue (Tail) := (Integer_16 (Cx), Integer_16 (Cy));
      end Reach;
   begin
      Housing_Too_Far := False;
      Housing_Is_Housing := False;
      Housing_Open := False;
      Housing_No_Path := False;
      Plan_Hovels := 0;
      Plan_Join_N := 0;
      Plan_N := 0;
      Plan_Blocks := 0;
      Plan_Cells_N := 0;
      Plan_Under_N := 0;
      Plan_At_Path := False;
      Plan_Turn := 0.0;
      Plan_Corner := [others => P0];
      Plan_Refused := Lot_Ok;
      for K in 1 .. N_Paths loop
         declare
            S  : Path_Seg renames Path_List (K);
            R  : constant Float := Float (W) * 0.125 + 1.0;
         begin
            if Float'Max (S.A.X, S.B.X) >= X - R and then Float'Min (S.A.X, S.B.X) <= X + R
              and then Float'Max (S.A.Y, S.B.Y) >= Y - R and then Float'Min (S.A.Y, S.B.Y) <= Y + R
            then
               N_Near := N_Near + 1;
               Near_Seg (N_Near) := K;
            end if;
         end;
      end loop;
      for Cx in 0 .. W - 1 loop
         for Cy in 0 .. W - 1 loop
            G (Cx, Cy) := Unseen;
         end loop;
      end loop;
      declare
         Sz : constant Float := Castle.Nav.Surface_Z (X, Y);
      begin
         if Sz >= 0.0 then
            Reach (W / 2, W / 2, B (Sz) - 1);
         end if;
      end;
      while Head < Tail and then not Open loop
         Head := Head + 1;
         declare
            Cx  : constant Integer := Integer (Queue (Head).X);
            Cy  : constant Integer := Integer (Queue (Head).Y);
            Z, Zr : Integer;
            Row : Integer := Integer (G (Cx, Cy));
         begin
            if G (Cx, Cy) = Was_Housing then
               Zone_Of_Block (Gx0 + Cx, Gy0 + Cy, Z, Zr);
               Row := Zr;
            end if;
            Reach (Cx + 1, Cy, Row);
            Reach (Cx - 1, Cy, Row);
            Reach (Cx, Cy + 1, Row);
            Reach (Cx, Cy - 1, Row);
         end;
      end loop;
      if Tail = 0 then
         Plan_Refused := No_Ground;          --  (begun on a path, another zone, or something standing)
      elsif Open then
         Plan_Refused := No_Ground;
         Housing_Open := True;
      elsif not Plan_At_Path then
         Plan_Refused := No_Ground;
         Housing_No_Path := True;
      else
         --  its ground as strips: rows south to north, west to east in a row
         Rows :
         for Cy in 0 .. W - 1 loop
            declare
               Cx : Integer := 0;
            begin
               while Cx < W loop
                  if G (Cx, Cy) >= 0 then
                     declare
                        X_0 : constant Integer := Cx;
                        Zr  : constant Integer_16 := G (Cx, Cy);
                     begin
                        while Cx + 1 < W and then G (Cx + 1, Cy) = Zr loop
                           Cx := Cx + 1;
                        end loop;
                        if Plan_N = Max_Plan_Runs or else N_Runs + Plan_N >= Max_Zone_Runs then
                           Plan_Refused := (if Plan_N = Max_Plan_Runs then Too_Large else No_Room);
                           exit Rows;
                        end if;
                        Plan_N := Plan_N + 1;
                        Plan_Run (Plan_N) := (Y => Integer_16 (Gy0 + Cy), X0 => Integer_16 (Gx0 + X_0),
                                              X1 => Integer_16 (Gx0 + Cx), Z => Zr);
                        Plan_Blocks := Plan_Blocks + Cx - X_0 + 1;
                     end;
                  end if;
                  Cx := Cx + 1;
               end loop;
            end;
         end loop Rows;
      end if;
      if Plan_Refused /= Lot_Ok then
         Plan_Join_N := 0;
      end if;
      Close_Housing_Plan (Count);
   end Plan_Housing_Fill;

   function Housing_Refusal return String is
     (if Housing_Too_Far
      then "it is too far from the homestake (the band's ground reaches" & Integer'Image (Integer (Far_Reach_Max_M))
           & " m at most)"
      elsif Housing_Open
      then "the paths round that ground do not close (or it is more than"
           & Integer'Image (Integer (Float (Max_Plan_B) * 0.125)) & " m from there to them)"
      elsif Housing_No_Path
      then "housing is marked along a path: no path lies beside that ground"
      elsif Housing_Is_Housing and then Plan_Refused = No_Ground
      then "that ground is housing already"
      else (case Plan_Refused is
               when Lot_Ok    => "",
               when Off_Path  => "housing is marked along a path: begin beside one, and pull along it",
               when No_Ground | Too_Small | One_Only | Too_Steep => "there is no clear ground there to build on",
               when Too_Large => "it is too large",
               when No_Room   => "there is no room for another zone"));

   function Housing_Joined return Natural is (Joined_Last);

   function Plan_Housing (X0, Y0, X1, Y1 : Float; Count : Boolean := True) return Lot_Plan is
      V : Lot_Plan;
   begin
      Plan_Housing_Lot (X0, Y0, X1, Y1, Count);
      V := Plan_View;
      V.Ok := Plan_Refused = Lot_Ok and then not Housing_Too_Far;
      V.Cells := Plan_Hovels;
      return V;
   end Plan_Housing;

   function Plan_Housing_Inside (X, Y : Float; Count : Boolean := True) return Lot_Plan is
      V : Lot_Plan;
   begin
      Plan_Housing_Fill (X, Y, Count);
      V := Plan_View;
      V.Ok := Plan_Refused = Lot_Ok and then not Housing_Too_Far;
      V.Cells := Plan_Hovels;
      return V;
   end Plan_Housing_Inside;

   --  The planned strip and the housing zones it meets (Plan_Join) become
   --  one zone, the first of them: its ground is theirs and the strip's
   --  together, and the houses of the others are its houses.  The runs of
   --  every zone are packed again (a zone's own lie together), and the
   --  zones after one that is gone move down a place, with whatever is kept
   --  by a zone's number (a stockpile's places, the camp, the houses).
   procedure Join_Plan is
      Keep : Positive := Plan_Join (1);
      function Joined (Z : Positive) return Boolean is (for some J in 1 .. Plan_Join_N => Plan_Join (J) = Z);
      function Before (L, R : Run_Rec) return Boolean is (L.Y < R.Y or else (L.Y = R.Y and then L.X0 < R.X0));
      procedure Sort is new Ada.Containers.Generic_Array_Sort (Positive, Run_Rec, Run_List, Before);
      N_All : Natural := Plan_N;
   begin
      for J in 1 .. Plan_Join_N loop
         Keep := Positive'Min (Keep, Plan_Join (J));
         N_All := N_All + Zones (Plan_Join (J)).N;
      end loop;
      declare
         type Run_List_Access is access Run_List;
         procedure Free is new Ada.Unchecked_Deallocation (Run_List, Run_List_Access);
         All_Runs : Run_List_Access := new Run_List (1 .. N_All);
         N : Natural := 0;
         M : Natural := 0;
         Packed : Natural := 0;
      begin
         for K in 1 .. Plan_N loop
            N := N + 1;
            All_Runs (N) := Plan_Run (K);
         end loop;
         for J in 1 .. Plan_Join_N loop
            for K in Zones (Plan_Join (J)).First + 1 .. Zones (Plan_Join (J)).First + Zones (Plan_Join (J)).N loop
               N := N + 1;
               All_Runs (N) := Runs (K);
            end loop;
         end loop;
         Sort (All_Runs.all);
         for K in 1 .. N loop                 --  strips that carry on from one another at one level are one
            if M > 0 and then All_Runs (M).Y = All_Runs (K).Y and then All_Runs (M).Z = All_Runs (K).Z
              and then Integer (All_Runs (M).X1) + 1 = Integer (All_Runs (K).X0)
            then
               All_Runs (M).X1 := All_Runs (K).X1;
            else
               M := M + 1;
               All_Runs (M) := All_Runs (K);
            end if;
         end loop;
         --  the other zones' runs packed again in the zones' order, then this zone's.
         --  **From a copy of the list as it was**: a zone's strips do not lie in the list in the
         --  zones' order (Read_Zone_Ground and Unzone_Box put a zone's on the end), and packed in
         --  place a zone whose strips lay after another's was written over that other's before
         --  those were moved: every zone after it had its ground lost (John, 2026-11-23: "the
         --  stockpile zones just disappeared at some point": the square's floor made, its ground
         --  read again and so last in the list; then housing pulled on to housing that was there)
         declare
            Was : Run_List_Access := new Run_List'(Run_List (Runs (1 .. N_Runs)));
         begin
            for Z in 1 .. N_Zones loop
               if not Joined (Z) then
                  declare
                     First_Was : constant Natural := Zones (Z).First;
                  begin
                     Zones (Z).First := Packed;
                     for K in 1 .. Zones (Z).N loop
                        Runs (Packed + K) := Was (First_Was + K);
                     end loop;
                     Packed := Packed + Zones (Z).N;
                  end;
               end if;
            end loop;
            Free (Was);
         end;
         Zones (Keep).First := Packed;
         Zones (Keep).N := M;
         for K in 1 .. M loop
            Runs (Packed + K) := All_Runs (K);
         end loop;
         N_Runs := Packed + M;
         Free (All_Runs);
      end;
      for Z in reverse 1 .. N_Zones loop      --  the zones taken into it are gone
         if Z /= Keep and then Joined (Z) then
            for K in Z .. N_Zones - 1 loop
               Zones (K) := Zones (K + 1);
            end loop;
            N_Zones := N_Zones - 1;
            for K in 1 .. N_Cells loop
               if Cells (K).Zone > Z then
                  Cells (K).Zone := Cells (K).Zone - 1;
               end if;
            end loop;
            if Camp_Zone_N > Z then
               Camp_Zone_N := Camp_Zone_N - 1;
            end if;
            for H in 1 .. N_Houses loop
               if Houses (H).Zone = Z then
                  Houses (H).Zone := Keep;
               elsif Houses (H).Zone > Z then
                  Houses (H).Zone := Houses (H).Zone - 1;
               end if;
            end loop;
            for J in 1 .. Plan_Join_N loop
               if Plan_Join (J) > Z then
                  Plan_Join (J) := Plan_Join (J) - 1;
               elsif Plan_Join (J) = Z then
                  Plan_Join (J) := Keep;
               end if;
            end loop;
         end if;
      end loop;
      Measure_Zone (Keep);
      Zoned_Last := Keep;
      Zones_Ver := Zones_Ver + 1;
   end Join_Plan;

   --  The housing last planned is taken: a zone of its own, or one with
   --  the housing it meets.
   procedure Take_Housing_Plan (Lots : out Natural) is
   begin
      Lots := 0;
      Joined_Last := 0;
      if Plan_Refused /= Lot_Ok or else Housing_Too_Far then
         return;
      end if;
      Joined_Last := Plan_Join_N;
      if Plan_Join_N = 0 then
         declare
            --  (a housing zone all of whose ground was taken out again, Unzone_Housing, is used anew)
            Again : Natural := 0;
         begin
            for Z in 1 .. N_Zones loop
               if Again = 0 and then Zones (Z).Kind = Habitation_Zone and then Zones (Z).N = 0
                 and then (for all H in 1 .. N_Houses => Houses (H).Zone /= Z)
               then
                  Again := Z;
               end if;
            end loop;
            if Again = 0 then
               N_Zones := N_Zones + 1;
               Again := N_Zones;
            end if;
            Zones (Again) := (Kind => Habitation_Zone, others => <>);
            Take_Plan (Again);
            Zoned_Last := Again;
         end;
      else
         Join_Plan;
      end if;
      Count_Housing;
      --  the lots of every house still to begin, laid out now (and not
      --  while the band is at its work)
      Plan_Lots;
      for K in 1 .. N_Lots loop
         if Castle.Colony.Lots (K).Zone = Zoned_Last then
            Lots := Lots + 1;
         end if;
      end loop;
   end Take_Housing_Plan;

   procedure Zone_Housing (X0, Y0, X1, Y1 : Float; Lots : out Natural) is
   begin
      Plan_Housing_Lot (X0, Y0, X1, Y1, Count => False);
      Take_Housing_Plan (Lots);
   end Zone_Housing;

   procedure Zone_Housing_Inside (X, Y : Float; Lots : out Natural) is
   begin
      Plan_Housing_Fill (X, Y, Count => False);
      Take_Housing_Plan (Lots);
   end Zone_Housing_Inside;

   ------------------------------------------------------------------ housing pulled with its path

   type Pull_Refused_For is
     (Pull_Ok, Not_Pulled, Path_In_Zone, Path_In_Lot, Path_In_Cart, Path_No_Ground, Path_Too_Many, No_Row);
   Pull_Refused   : Pull_Refused_For := Pull_Ok;
   Pull_Zone_Kind : Zone_Kind := Stockpile_Zone;
   Pull_Zone_Yard : Boolean := False;
   Pull_Laid_M    : Float := 0.0;
   Pull_Gone      : Natural := 0;
   Pull_Zoned     : Natural := 0;

   function Pull_Refusal return String is
     (case Pull_Refused is
         when Pull_Ok        => "",
         when Not_Pulled     => "pull it along the way its path is to run",
         when Path_In_Zone   =>
           (case Pull_Zone_Kind is
               when Stockpile_Zone  => (if Pull_Zone_Yard then "the stockyard" else "a stockpile"),
               when Camp_Zone       => "the camp",
               when Habitation_Zone => "housing")
           & " is in the way of its path",
         when Path_In_Lot    => "a hovel's lot is in the way of its path",
         when Path_In_Cart   => "the lord's cart is in the way of its path: it cannot be moved yet",
         when Path_No_Ground => "there is no ground there to lay its path on",
         when Path_Too_Many  => "there are as many paths as there can be",
         when No_Row         => Housing_Refusal);
   function Pull_Path_M return Float is (Pull_Laid_M);
   function Pull_Gave_Way return Natural is (Pull_Gone);
   function Pull_Rows_Zoned return Natural is (Pull_Zoned);

   --  A pull as it is read from its two points: its line, the stretches of
   --  path to lay for it, and the two points its strip is planned from on
   --  either side (the strip's planner takes its extent along the path and
   --  its side from them).
   type Pull_Piece is record
      A, B : Vec3 := (0.0, 0.0, 0.0);
   end record;
   type Pull_Piece_List is array (1 .. Max_Box_Gaps) of Pull_Piece;
   type Pull_Res is record
      View     : Pull_View;
      Seg      : Natural := 0;                 --  along a path: a stretch of that path
      Ux, Uy   : Float := 0.0;                 --  the way its line runs
      P0, P1   : Vec3 := (0.0, 0.0, 0.0);      --  its strip's two points, for the side it was begun on,
      Q0, Q1   : Vec3 := (0.0, 0.0, 0.0);      --  and for the other
      Piece    : Pull_Piece_List;              --  what of its path is to lay
      N_Pieces : Natural := 0;
      Too_Many : Boolean := False;             --  (more parts of it to lay than are kept)
      Unsure   : Boolean := False;             --  begun on its line: which side is the side begun is not said by
                                               --  its two points (the left of its way, until the rows are looked at)
   end record;

   function Way_From (Sx, Sy : Integer) return Way_Index is
   begin
      for W in Way_Index loop
         if Way_Dx (W) = Sx and then Way_Dy (W) = Sy then
            return W;
         end if;
      end loop;
      return 0;
   end Way_From;

   --  A pull read from its two points.  Known: the side begun is Left of
   --  the way it was pulled (it was read before: Pull_Line); else it is as
   --  the two points say.
   function Read_Pull (Begun, Pulled_To : Vec3; Known : Boolean := False; Left_Side : Boolean := True)
                       return Pull_Res
   is
      R  : Pull_Res;
      Dx : constant Float := Pulled_To.X - Begun.X;
      Dy : constant Float := Pulled_To.Y - Begun.Y;
      Half : constant Float := Path_Width_M / 2.0;
      Tan_Half : constant := 0.414_213_56;        --  (as Path_Line_End: half way between two of the eight ways)
      Wx : constant Integer := (if abs (Dx) <= Tan_Half * abs (Dy) then 0 elsif Dx > 0.0 then 1 else -1);
      Wy : constant Integer := (if abs (Dy) <= Tan_Half * abs (Dx) then 0 elsif Dy > 0.0 then 1 else -1);
      Par    : Natural := 0;
      Par_D  : Float := Float'Last;       --  the nearest path that runs the way it was pulled,
      Near_D : Float := Float'Last;       --  and the nearest that runs any way
      Along_It : Boolean := False;
      procedure Add_Piece (A, C : Vec3) is
      begin
         if R.N_Pieces < R.Piece'Last then
            R.N_Pieces := R.N_Pieces + 1;
            R.Piece (R.N_Pieces) := (A, C);
            R.View.New_Path_M := R.View.New_Path_M + Flat_Dist (A, C);
         else
            R.Too_Many := True;
         end if;
      end Add_Piece;
   begin
      R.View.Begun := Begun;
      R.View.Pulled_To := Pulled_To;
      if Dx * Dx + Dy * Dy < Path_Line_Least_M ** 2 then
         return R;
      end if;
      for K in 1 .. N_Paths loop
         declare
            S : Path_Seg renames Path_List (K);
            L : constant Float := Flat_Dist (S.A, S.B);
            D : constant Float := Seg_Dist (Begun, S);
         begin
            if L > 0.01 then
               Near_D := Float'Min (Near_D, D);
               if D < Par_D
                 and then abs ((S.B.X - S.A.X) * Float (Wx) + (S.B.Y - S.A.Y) * Float (Wy))
                          >= 0.9239 * L * Sqrt (Float (Wx * Wx + Wy * Wy))
               then
                  Par := K;
                  Par_D := D;
               end if;
            end if;
         end;
      end loop;
      --  along that path: within reach of it, not begun on another path instead, and beside some of it
      if Par > 0 and then Par_D <= Housing_Snap_M and then not (Near_D <= Half and then Par_D > Half) then
         declare
            RF : Vec3;
            Tx, Ty, Len : Float;
            Sx, Sy : Integer;
         begin
            Run_Of (Par, RF, Tx, Ty, Len);
            Grid_Way (Path_List (Par), Sx, Sy);
            declare
               function Along (P : Vec3) return Float is ((P.X - RF.X) * Tx + (P.Y - RF.Y) * Ty);
               function Left (P : Vec3) return Float is ((P.Y - RF.Y) * Tx - (P.X - RF.X) * Ty);
               function At_Run (A : Float) return Vec3 is (Line_Point (RF.X + A * Tx, RF.Y + A * Ty, Begun.Z));
               A0   : constant Float := Along (Begun);
               A1   : constant Float := Along (Pulled_To);
               Fwd  : constant Boolean := A1 >= A0;
               Lo   : Float := Float'Min (A0, A1);
               Hi   : Float := Float'Max (A0, A1);
               Past : constant Float := Float (Housing_Past_B) * 0.25;
               --  the side its two points say it was begun on, of the run's own way, as the strip's
               --  planner takes it from them (0: neither says)
               Said : constant Float :=
                 (if abs Left (Begun) > 0.05 then (if Left (Begun) > 0.0 then 1.0 else -1.0)
                  elsif abs Left (Pulled_To) > 0.05 then (if Left (Pulled_To) > 0.0 then 1.0 else -1.0)
                  else 0.0);
               Side : constant Float :=
                 (if Known then (if Left_Side = Fwd then 1.0 else -1.0)
                  elsif Said /= 0.0 then Said
                  elsif Fwd then 1.0 else -1.0);
               Step_M : constant Float := (if Sx /= 0 and then Sy /= 0 then 0.25 * Sqrt (2.0) else 0.25);
               --  a block's step the run's own way
               Rx : constant Float := (if abs Tx < 0.01 then 0.0 elsif Tx > 0.0 then 0.25 else -0.25);
               Ry : constant Float := (if abs Ty < 0.01 then 0.0 elsif Ty > 0.0 then 0.25 else -0.25);
               End_X : constant Float := RF.X + Len * Tx;
               End_Y : constant Float := RF.Y + Len * Ty;
               Lo_D, Hi_D : Float;         --  how far it reaches along the run, with what is laid past its ends
               N    : Integer;
               --  that point on side S of the path's line: itself if it is there, across the line
               --  from itself if it is on the other, a metre off the line if it is on it
               function On_Side (P : Vec3; S : Float) return Vec3 is
                  L : constant Float := Left (P);
                  M : constant Float :=
                    (if abs L > 0.05 and then (L > 0.0) = (S > 0.0) then 0.0 elsif abs L > 0.05 then -2.0 * L else S - L);
               begin
                  return (P.X - M * Ty, P.Y + M * Tx, P.Z);
               end On_Side;
            begin
               if Lo < Len - 0.25 and then Hi > 0.25 then
                  Along_It := True;
                  if Hi - Lo > Housing_Long_M then           --  (as the strip's planner cuts it: from the end begun)
                     if A0 <= A1 then
                        Hi := Lo + Housing_Long_M;
                     else
                        Lo := Hi - Housing_Long_M;
                     end if;
                  end if;
                  Lo_D := Float'Max (Lo, -Past);
                  Hi_D := Float'Min (Hi, Len + Past);
                  --  pulled past an end of the run: the path goes on from that end, a whole number of blocks
                  --  (a run that lies one of the eight ways from a corner of blocks; another is left as it ends)
                  if Sx /= 0 or else Sy /= 0 then
                     if Hi >= Len + Path_Line_Least_M and then At_Corner (End_X) and then At_Corner (End_Y) then
                        N := Integer'Max (2, Integer (Float'Rounding ((Hi - Len) / Step_M)));
                        Add_Piece (Line_Point (Block_Corner (End_X), Block_Corner (End_Y), Begun.Z),
                                   Line_Point (Block_Corner (End_X) + Float (N) * Rx, Block_Corner (End_Y) + Float (N) * Ry,
                                               Begun.Z));
                        Hi_D := Len + Float (N) * Step_M;
                     end if;
                     if Lo <= -Path_Line_Least_M and then At_Corner (RF.X) and then At_Corner (RF.Y) then
                        N := Integer'Max (2, Integer (Float'Rounding (-Lo / Step_M)));
                        Add_Piece (Line_Point (Block_Corner (RF.X) - Float (N) * Rx, Block_Corner (RF.Y) - Float (N) * Ry,
                                               Begun.Z),
                                   Line_Point (Block_Corner (RF.X), Block_Corner (RF.Y), Begun.Z));
                        Lo_D := -Float (N) * Step_M;
                     end if;
                  end if;
                  R.View.Ok := Hi_D - Lo_D >= 0.25;
                  R.View.Along_Path := True;
                  R.View.From := At_Run (if Fwd then Lo_D else Hi_D);
                  R.View.To := At_Run (if Fwd then Hi_D else Lo_D);
                  R.View.Begun_Left := (Side > 0.0) = Fwd;
                  R.Unsure := not Known and then Said = 0.0;
                  R.Seg := Par;
                  R.Ux := (if Fwd then Tx else -Tx);
                  R.Uy := (if Fwd then Ty else -Ty);
                  --  (the two points themselves where they say that side: Zone_Housing's strip for them)
                  if Said = Side then
                     R.P0 := Begun;
                     R.P1 := Pulled_To;
                  else
                     R.P0 := On_Side (Begun, Side);
                     R.P1 := On_Side (Pulled_To, Side);
                  end if;
                  R.Q0 := On_Side (Begun, -Side);
                  R.Q1 := On_Side (Pulled_To, -Side);
               end if;
            end;
         end;
      end if;
      if not Along_It then
         --  a line of its own, as the path tool draws one
         declare
            From : constant Vec3 := Path_Line_Start (Begun);
            To   : Vec3 := Path_Line_End (From, Pulled_To);
            L    : Float := Flat_Dist (From, To);
            Sx   : constant Integer := (if abs (To.X - From.X) < 1.0E-3 then 0 elsif To.X > From.X then 1 else -1);
            Sy   : constant Integer := (if abs (To.Y - From.Y) < 1.0E-3 then 0 elsif To.Y > From.Y then 1 else -1);
            Step_M : constant Float := (if Sx /= 0 and then Sy /= 0 then 0.25 * Sqrt (2.0) else 0.25);
            Total, N_Gaps : Natural;
            Gaps : Box_Gaps;
         begin
            if L < Path_Line_Least_M then
               return R;
            end if;
            if L > Housing_Long_M then                    --  (no further than one zoning goes)
               declare
                  N : constant Integer := Integer (Float'Floor (Housing_Long_M / Step_M));
               begin
                  To := Line_Point (From.X + Float (N * Sx) * 0.25, From.Y + Float (N * Sy) * 0.25, To.Z);
                  L := Flat_Dist (From, To);
               end;
            end if;
            R.Ux := (To.X - From.X) / L;
            R.Uy := (To.Y - From.Y) / L;
            --  what of it no path lies along yet
            if At_Corner (From.X) and then At_Corner (From.Y) and then At_Corner (To.X) and then At_Corner (To.Y)
              and then (Sx = 0 or else Sy = 0 or else abs (abs (To.X - From.X) - abs (To.Y - From.Y)) < 1.0E-3)
            then
               Line_Gaps (From, To, Way_From (Sx, Sy), Total, Gaps, N_Gaps);
               for G in 1 .. N_Gaps loop
                  Add_Piece (Line_Point (From.X + Float (Gaps (G).A * Sx) * 0.25, From.Y + Float (Gaps (G).A * Sy) * 0.25,
                                         From.Z),
                             Line_Point (From.X + Float (Gaps (G).B * Sx) * 0.25, From.Y + Float (Gaps (G).B * Sy) * 0.25,
                                         To.Z));
               end loop;
            else
               Add_Piece (From, To);       --  (begun at the end of a path that lies no such way: all of it)
            end if;
            R.View.Ok := True;
            R.View.Along_Path := False;
            R.View.From := From;
            R.View.To := To;
            declare
               --  begun clearly to one side of its line (more than half a metre off): that side; else the left
               Off : constant Float := (Begun.Y - From.Y) * R.Ux - (Begun.X - From.X) * R.Uy;
               S   : constant Float :=
                 (if Known then (if Left_Side then 1.0 else -1.0) elsif Off < -0.5 then -1.0 else 1.0);
            begin
               R.View.Begun_Left := S > 0.0;
               R.Unsure := not Known and then abs Off <= 0.5;
               R.P0 := (From.X - S * R.Uy, From.Y + S * R.Ux, From.Z);
               R.P1 := (To.X - S * R.Uy, To.Y + S * R.Ux, To.Z);
               R.Q0 := (From.X + S * R.Uy, From.Y - S * R.Ux, From.Z);
               R.Q1 := (To.X + S * R.Uy, To.Y - S * R.Ux, To.Z);
            end;
         end;
      end if;
      return R;
   end Read_Pull;

   --  The stretch of path that lies along a pull's line at its middle (0: none).
   function Pull_Stretch (R : Pull_Res) return Natural is
      M : constant Vec3 := ((R.View.From.X + R.View.To.X) * 0.5, (R.View.From.Y + R.View.To.Y) * 0.5, 0.0);
   begin
      if R.View.Along_Path then
         return R.Seg;
      end if;
      for K in reverse 1 .. N_Paths loop
         declare
            S : Path_Seg renames Path_List (K);
            L : constant Float := Flat_Dist (S.A, S.B);
         begin
            if L > 0.01 and then Seg_Dist (M, S) < 0.02
              and then abs ((S.B.X - S.A.X) * R.Uy - (S.B.Y - S.A.Y) * R.Ux) < 0.02 * L
            then
               return K;
            end if;
         end;
      end loop;
      return 0;
   end Pull_Stretch;

   --  A hovel's lot, begun or standing, holds that block column.
   function In_A_Lot (Bx, By : Integer) return Boolean is
     (for some H in 1 .. N_Houses => In_Lot (Houses (H).F, Bx, By));

   --  Whether the path a pull would lay can be laid (Pull_Refused says why
   --  not): as Lay_Path would refuse it, but that housing with no hovel's
   --  lot on it gives way.
   procedure Check_Pull_Path (R : Pull_Res) is
      Half   : constant Float := Path_Width_M / 2.0;
      Pieces : Natural := 0;
   begin
      if R.Too_Many then
         Pull_Refused := Path_Too_Many;
         return;
      end if;
      for I in 1 .. R.N_Pieces loop
         declare
            A  : Vec3 renames R.Piece (I).A;
            C  : Vec3 renames R.Piece (I).B;
            L  : constant Float := Flat_Dist (A, C);
            S  : constant Path_Seg := (A => A, B => C, others => <>);
            Earth : Natural := 0;
         begin
            Pieces := Pieces + Line_Pieces (L);
            for K in 0 .. Integer (Float'Ceiling (L * 8.0)) loop
               declare
                  T  : constant Float := Float'Min (1.0, Float (K) / (L * 8.0));
                  Px : constant Float := A.X + (C.X - A.X) * T;
                  Py : constant Float := A.Y + (C.Y - A.Y) * T;
                  Z  : constant Natural := (if N_Zones > 0 then Zone_On (Px, Py) else 0);
               begin
                  if Z /= 0 and then Zones (Z).Kind /= Habitation_Zone then
                     Pull_Refused := Path_In_Zone;
                     Pull_Zone_Kind := Zones (Z).Kind;
                     Pull_Zone_Yard := Zones (Z).Yard;
                     return;
                  elsif Z /= 0 and then In_A_Lot (B (Px), B (Py)) then
                     Pull_Refused := Path_In_Lot;
                     return;
                  elsif Cart_Set and then Cart_On_Block (B (Px), B (Py), Margin => Integer (Half * 4.0)) then
                     Pull_Refused := Path_In_Cart;
                     return;
                  end if;
               end;
            end loop;
            --  ground to lay it on, where the ground is in: earth that is no zone's, or housing's that gives way
            if Stretch_In (S, Held => True) then
               for X in B (Float'Min (A.X, C.X) - Half) .. B (Float'Max (A.X, C.X) + Half) loop
                  for Y in B (Float'Min (A.Y, C.Y) - Half) .. B (Float'Max (A.Y, C.Y) + Half) loop
                     declare
                        Mid : constant Vec3 := ((Float (X) + 0.5) * 0.25, (Float (Y) + 0.5) * 0.25, 0.0);
                        Zn  : constant Natural := (if N_Zones > 0 then Zone_Of_Block (X, Y) else 0);
                     begin
                        if Seg_Dist (Mid, S) <= Half
                          and then (Zn = 0 or else (Zones (Zn).Kind = Habitation_Zone and then not In_A_Lot (X, Y)))
                        then
                           declare
                              T  : constant Float :=
                                Float'Max (0.0, Float'Min (1.0, ((Mid.X - A.X) * (C.X - A.X)
                                                                  + (Mid.Y - A.Y) * (C.Y - A.Y)) / (L * L)));
                              Zr : constant Integer := Ground_Row (X, Y, B (A.Z + (C.Z - A.Z) * T));
                           begin
                              if Zr >= 0
                                and then Mat (X, Y, Zr) in Grass | Dirt | Sand | Gravel | Clay | Placer_Gravel | Bog_Iron
                              then
                                 Earth := Earth + 1;
                              end if;
                           end;
                        end if;
                     end;
                  end loop;
               end loop;
               if Earth = 0 then
                  Pull_Refused := Path_No_Ground;
                  return;
               end if;
            end if;
         end;
      end loop;
      if N_Paths + Pieces > Max_Paths then
         Pull_Refused := Path_Too_Many;
      end if;
   end Check_Pull_Path;

   --  One row of a pull planned, its path taken as lying there (the
   --  stretches it would be kept as, as Lay_Path makes them: the plan's own,
   --  gone again when it is made).  Into the plan.
   procedure Plan_Pull_Row (R : Pull_Res; Begun_Side : Boolean; Count : Boolean) is
      Were : constant Natural := N_Paths;
      A0   : constant Vec3 := (if Begun_Side then R.P0 else R.Q0);
      A1   : constant Vec3 := (if Begun_Side then R.P1 else R.Q1);
      Seg  : Natural;
   begin
      for I in 1 .. R.N_Pieces loop
         declare
            L : constant Float := Flat_Dist (R.Piece (I).A, R.Piece (I).B);
            N : constant Positive := Line_Pieces (L);
         begin
            for P in 1 .. N loop
               exit when N_Paths >= Max_Paths;
               N_Paths := N_Paths + 1;
               Path_List (N_Paths) := Line_Piece (R.Piece (I).A, R.Piece (I).B, P, N);
            end loop;
         end;
      end loop;
      begin
         Seg := Pull_Stretch (R);
         if Seg = 0 then
            --  (no stretch lies along it: nothing of its path could be taken as lying there)
            Plan_Housing_Lot (A0.X, A0.Y, A0.X, A0.Y, Count => False);      --  (the plan emptied: begun and ended at one point)
            Plan_Refused := Off_Path;
         else
            Plan_Housing_Lot (A0.X, A0.Y, A1.X, A1.Y, Count, Seg => Seg);
         end if;
      exception
         when others =>
            N_Paths := Were;
            raise;
      end;
      N_Paths := Were;
   end Plan_Pull_Row;

   --  The row a pull's first reading looked at, if it can be zoned: it lies
   --  in the plan still, and Plan_Housing_Pull for that row of that line
   --  takes it as it lies (a pull is read and its rows planned every frame
   --  it is held: a row of 60 m at 45 degrees is some 3 ms to plan).  Known
   --  by what the plan holds, so whatever else has been planned since is
   --  seen.
   type Pull_Memo_Rec is record
      Fresh  : Boolean := False;
      Begun, Pulled_To : Vec3 := (0.0, 0.0, 0.0);
      Left   : Boolean := True;             --  the row: on the left of the way it was pulled
      N, Blocks : Natural := 0;
      Corner : Lot_Corners := [others => (0.0, 0.0, 0.0)];
      First, Last : Run_Rec;
   end record;
   Pull_Memo : Pull_Memo_Rec;
   procedure Keep_Pull_Row (Begun, Pulled_To : Vec3; Left : Boolean) is
   begin
      Pull_Memo := (Fresh => Plan_N > 0, Begun => Begun, Pulled_To => Pulled_To, Left => Left, N => Plan_N,
                    Blocks => Plan_Blocks, Corner => Plan_Corner,
                    First => (if Plan_N > 0 then Plan_Run (1) else (others => <>)),
                    Last => (if Plan_N > 0 then Plan_Run (Plan_N) else (others => <>)));
   end Keep_Pull_Row;
   function Pull_Row_Kept (Line : Pull_View; Left : Boolean) return Boolean is
     (Pull_Memo.Fresh and then Pull_Memo.Begun = Line.Begun and then Pull_Memo.Pulled_To = Line.Pulled_To
      and then Pull_Memo.Left = Left and then Plan_N = Pull_Memo.N and then Plan_N > 0
      and then Plan_Blocks = Pull_Memo.Blocks and then Plan_Corner = Pull_Memo.Corner
      and then Plan_Run (1) = Pull_Memo.First and then Plan_Run (Plan_N) = Pull_Memo.Last
      and then Plan_Refused = Lot_Ok and then not Housing_Too_Far);

   --  A pull read for the first time.  Begun on its line, the side begun is
   --  the left of the way it was pulled; or the right, where the left can
   --  take no housing and the right can.
   function Pull_Line (Begun, Pulled_To : Vec3) return Pull_View is
      R : constant Pull_Res := Read_Pull (Begun, Pulled_To);
   begin
      Pull_Memo.Fresh := False;
      if R.View.Ok and then R.Unsure then
         Plan_Pull_Row (R, True, Count => False);
         if Plan_Refused = Lot_Ok and then not Housing_Too_Far then
            Keep_Pull_Row (Begun, Pulled_To, Left => R.View.Begun_Left);
         else
            Plan_Pull_Row (R, False, Count => False);
            if Plan_Refused = Lot_Ok and then not Housing_Too_Far then
               Keep_Pull_Row (Begun, Pulled_To, Left => not R.View.Begun_Left);
               return Read_Pull (Begun, Pulled_To, Known => True, Left_Side => not R.View.Begun_Left).View;
            end if;
         end if;
      end if;
      return R.View;
   end Pull_Line;

   function Plan_Housing_Pull (Line : Pull_View; Begun_Side : Boolean; Count : Boolean := True) return Lot_Plan is
      R : constant Pull_Res := Read_Pull (Line.Begun, Line.Pulled_To, Known => True, Left_Side => Line.Begun_Left);
      V : Lot_Plan;
   begin
      Pull_Refused := Pull_Ok;
      if not R.View.Ok then
         Plan_Housing_Lot (Line.Begun.X, Line.Begun.Y, Line.Begun.X, Line.Begun.Y, Count => False);   --  (the plan emptied)
         Pull_Refused := Not_Pulled;
         V := Plan_View;
         V.Ok := False;
         V.Corner := [others => Line.Begun];
         return V;
      end if;
      --  (the row its reading looked at lies in the plan still: not planned again)
      if Count or else not Pull_Row_Kept (Line, Left => (Begun_Side = Line.Begun_Left)) then
         Plan_Pull_Row (R, Begun_Side, Count);
      end if;
      Pull_Memo.Fresh := False;
      Check_Pull_Path (R);
      if Pull_Refused /= Pull_Ok then
         Plan_N := 0;                      --  (nothing to show of a row whose path cannot be laid)
         Plan_Blocks := 0;
         Plan_Join_N := 0;
      elsif Plan_Refused /= Lot_Ok or else Housing_Too_Far then
         Pull_Refused := No_Row;
      end if;
      V := Plan_View;
      V.Ok := Pull_Refused = Pull_Ok;
      V.Cells := (if V.Ok then Plan_Hovels else 0);
      return V;
   end Plan_Housing_Pull;

   --  The housing under a stretch of path that is about to be laid gives
   --  way: its block columns within the path's width are no zone's any
   --  more (never those of a hovel's lot: Unzone_Box keeps them).  Counted
   --  into Pull_Gone.
   procedure Housing_Gives_Way (A, C : Vec3) is
      Half : constant Float := Path_Width_M / 2.0;
      S    : constant Path_Seg := (A => A, B => C, others => <>);
      function On_It (X, Y : Integer) return Boolean is
        (Seg_Dist (((Float (X) + 0.5) * 0.25, (Float (Y) + 0.5) * 0.25, 0.0), S) <= Half);
      Columns, Marked : Natural;
   begin
      if N_Housing = 0 then
         return;
      end if;
      Unzone_Box (Float'Min (A.X, C.X) - Half, Float'Min (A.Y, C.Y) - Half,
                  Float'Max (A.X, C.X) + Half, Float'Max (A.Y, C.Y) + Half,
                  Mark => False, Columns => Columns, Marked => Marked, Only => On_It'Access);
      Pull_Gone := Pull_Gone + Columns;
   end Housing_Gives_Way;

   --  A path laid by the player's order, the path tool's (John, 2026-11-20:
   --  "a paths pull through housing should give way as built, if the path
   --  can pass and not interfere with anything built"): as Lay_Path, but
   --  that housing gives way under it as under a housing pull's path.
   --  Through a hovel's lot, begun or standing, it is refused (Path_Refusal);
   --  through any other zone, as it always was.
   Path_Through_On : Boolean := True;
   procedure Set_Metre_Ground (On : Boolean) is
   begin
      Metre_Ground_On := On;
   end Set_Metre_Ground;
   function Metre_Ground return Boolean is (Metre_Ground_On);

   procedure Set_Path_Through (On : Boolean) is
   begin
      Path_Through_On := On;
   end Set_Path_Through;
   function Path_Through return Boolean is (Path_Through_On);

   procedure Lay_Path_Through (From, To : Vec3; Laid : out Natural) is
      R : Pull_Res;
   begin
      Laid := 0;
      Pull_Gone := 0;
      if not Path_Through_On or else N_Housing = 0 or else Flat_Dist (From, To) < 0.25 then
         Lay_Path (From, To, Laid);
         return;
      end if;
      R.N_Pieces := 1;
      R.Piece (1) := (From, To);
      Pull_Refused := Pull_Ok;
      Check_Pull_Path (R);
      if Pull_Refused = Path_In_Lot then
         Path_Refused_For := Through_Lot;
         Pull_Refused := Pull_Ok;
         return;
      elsif Pull_Refused = Pull_Ok then
         Housing_Gives_Way (From, To);
      end if;
      Pull_Refused := Pull_Ok;
      Lay_Path (From, To, Laid);        --  (a zone of another kind, the cart, no ground: it says so itself)
   end Lay_Path_Through;

   procedure Pull_Housing (Line : Pull_View; Rows : Pull_Rows; Lots : out Natural) is
      R     : constant Pull_Res := Read_Pull (Line.Begun, Line.Pulled_To, Known => True, Left_Side => Line.Begun_Left);
      Ask_B : constant Boolean := Rows in Side_Begun | Both_Sides;
      Ask_O : constant Boolean := Rows in Other_Side | Both_Sides;
      Ok_B, Ok_O : Boolean := False;
   begin
      Lots := 0;
      Pull_Laid_M := 0.0;
      Pull_Gone := 0;
      Pull_Zoned := 0;
      Pull_Refused := Pull_Ok;
      if not R.View.Ok then
         Pull_Refused := Not_Pulled;
         return;
      end if;
      Check_Pull_Path (R);
      if Pull_Refused /= Pull_Ok then
         return;
      end if;
      --  every row asked is planned before anything is laid (the side it was begun on last: its
      --  reason is the one said if neither can be zoned)
      if Ask_O then
         Plan_Pull_Row (R, False, Count => False);
         Ok_O := Plan_Refused = Lot_Ok and then not Housing_Too_Far;
      end if;
      if Ask_B then
         Plan_Pull_Row (R, True, Count => False);
         Ok_B := Plan_Refused = Lot_Ok and then not Housing_Too_Far;
      end if;
      if not (Ok_B or else Ok_O) then
         Pull_Refused := No_Row;
         return;
      end if;
      --  housing under its path gives way
      for I in 1 .. R.N_Pieces loop
         Housing_Gives_Way (R.Piece (I).A, R.Piece (I).B);
      end loop;
      --  its path
      for I in 1 .. R.N_Pieces loop
         declare
            Laid : Natural;
         begin
            Lay_Path (R.Piece (I).A, R.Piece (I).B, Laid);
            if Laid > 0 then
               Pull_Laid_M := Pull_Laid_M + Flat_Dist (R.Piece (I).A, R.Piece (I).B);
            end if;
         end;
      end loop;
      --  its rows
      declare
         Seg : constant Natural := Pull_Stretch (R);
         L   : Natural;
      begin
         if Seg = 0 then
            Pull_Refused := Path_No_Ground;
            return;
         end if;
         if Ok_B then
            Plan_Housing_Lot (R.P0.X, R.P0.Y, R.P1.X, R.P1.Y, Count => False, Seg => Seg);
            if Plan_Refused = Lot_Ok and then not Housing_Too_Far then
               Take_Housing_Plan (L);
               Lots := Lots + L;
               Pull_Zoned := Pull_Zoned + 1;
            end if;
         end if;
         if Ok_O then
            Plan_Housing_Lot (R.Q0.X, R.Q0.Y, R.Q1.X, R.Q1.Y, Count => False, Seg => Seg);
            if Plan_Refused = Lot_Ok and then not Housing_Too_Far then
               Take_Housing_Plan (L);
               Lots := Lots + L;
               Pull_Zoned := Pull_Zoned + 1;
            end if;
         end if;
         if Pull_Zoned = 0 then
            Pull_Refused := No_Row;
         end if;
      end;
   end Pull_Housing;

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
                         and then (M.Why in Enough_Wood | Enough_Meat | Enough_Food | Stocks_Full
                                   or else (Room_Gated and then M.Why in No_Room | Nearly_Full and then M.Carried = 0)),
              Trade => Trade_Of (I), Site => Site_Of (I), Home => Home_Of (I), Housed => Housed (I),
              Has_Bed => Has_Bed (I));
   end Person;

   ------------------------------------------------------------------ saves

   Save_Version : constant := 46;   --  46: which stockpiles the player has ordered removed (blobs of 30 to 45
                                    --  still read: none of theirs was);
                                    --  45: whether a house begun from now on has the fuller truss, and which
                                    --  houses have (blobs of 30 to 44 still read: none of theirs has).  They
                                    --  are the blob's last bytes, read long after the houses: **whatever
                                    --  hangs on a house's blueprint is worked out after them** (Load measures
                                    --  such a house again there and only then holds what is laid of it
                                    --  against its blueprint: done where the house is read, that refused
                                    --  every save with a hovel of the fuller truss standing);
                                    --  44: a storehouse's walls, along its front and back from it (blobs of 30 to
                                    --  43 still read: theirs is 40 by 20);
                                    --  43: whether the colony was founded on a square, the homestake and the
                                    --  campfire one (blobs of 30 to 42 still read: none of theirs was);
                                    --  42: each zone's frame, if it was put down whole with its path (where its
                                    --  front begins, which way, how long), and whether the player's stockpile is
                                    --  put down so (blobs of 30 to 41 still read: no zone of theirs has a frame);
                                    --  41: how a storehouse's yard is made (its coverings' roofs smoothed, its
                                    --  fence in pieces), with each storehouse, and whether one begun from now
                                    --  on is so (blobs of 30 to 40 still read: their stockyards are as begun);
                                    --  40: whether a turned hovel is walked where it is drawn, with each house
                                    --  and each lot laid out (in the byte that holds its turn), and whether
                                    --  those placed from now on are (blobs of 30 to 39 still read: their turned
                                    --  hovels are walked as they stand, as they were);
                                    --  39: what a storehouse drawn turned is turned about, with each house, and
                                    --  whether a stockyard beside a path at 45 degrees is laid out along it
                                    --  (blobs of 30 to 38 still read: their stockyards are as they were zoned);
                                    --  38: whether the band is told of ways that are not there, and what it has
                                    --  been told (blobs of 30 to 37 still read);
                                    --  37: whether a turned house's ground is made where it is drawn, with each
                                    --  house and each lot laid out, and whether it is for those placed from now
                                    --  on (blobs of 30 to 36 still read: their turned houses and lots keep the
                                    --  square ground they have);
                                    --  36: a house's turn, and whether houses are turned (blobs of 30 to 35 still read);
                                    --  35: how far the gatherers and the porters look (blobs of 30 to 34 still read);
                                    --  34: a measuring start for wood (Set_Wood_From); the player's stockpile of any
                                    --  size again and stockpiles staying open are what a blob of 30 to 33 loads with;
                                    --  33: how far the foresters look for a tree, and whether they look further
                                    --  than the work radius (blobs of 30 to 32 are still read);
                                    --  32: his answers of 2026-11-19: with each house whether plank stands beside
                                    --  its windows and whether a hovel has a ridge beam, and who is set to
                                    --  building (blobs of 30 and 31 are still read);
                                    --  31: the next pass of his notes: making way, paths levelled, a house's
                                    --  roof timbers and window timber (a blob of 30 is still read);
                                    --  30: the stockyard: which zone is the yard, whether its ground is levelled;
                                    --  a house's patch numbers and a storehouse's shape moved with it (29 refused)
   --  29: the playtest round of 2026-11-18: the stores' last places kept,
                                    --  the one stockpile, long grass cut from the top, bushes shared (28 refused)
   --  28: the storehouse used: each place's fitting and whether it is made,
                                    --  the stockman, the carpenter, water (27 refused)
   --  27: the storehouse: a house's kind and a storehouse's yard, and on
                                    --  the end whether one is asked for, the stake's day, whether it has
                                    --  been asked, its house and the places closed for it (26, the first
                                    --  pass alone, refused: it never left the branch, but John tries every
                                    --  build)
   --  26: the stockpile's first pass: how many may be builders at once, how
                                    --  large a stockpile has to be, whether one gets overflow places and
                                    --  which places they are (on the end; 25, before it, refused)
   --  25: housing: the houses (their front yards and their stone with them), the
                                    --  house each builder is at, the lots laid out for the houses still to
                                    --  begin, each one's place by the fire, what the pass's fourth round
                                    --  added, and on its end whether a hole under a path is filled and the
                                    --  lord's cart pulled into a stockpile (18 to 24 were housing before that, before the pass's fourth round, before the band chose
                                    --  where to lie, before its lots were laid out beforehand and its houses
                                    --  drawn for by lot, before its ground was walled, the hovel of plank and
                                    --  then of daub: refused)
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
   subtype V16_Kinds is Item_Kind range Earth .. Earth;                        --  and 16
   subtype V23_Kinds is Item_Kind range Salt .. Item_Kind'Last;                --  and 23 (the next kind closes this range)

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
