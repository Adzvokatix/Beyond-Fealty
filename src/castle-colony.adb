with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Ada.Unchecked_Conversion;
with Ada.Unchecked_Deallocation;
with Ada.Containers.Hashed_Maps;
with Ada.Containers.Generic_Array_Sort;
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
      Roof_N   : Natural := 0;               --  the last that is roof (its trimming comes after),
      Dress_N  : Natural := 0;               --  the last that is roof or its trimming,
      Wood_N   : Natural := 0;               --  the last that is of wood (what takes straw comes after),
      Bed      : Boolean := False;           --  a bed of straw has been made in it (its owner's, whoever that is)
      Stone_Left : Natural := 0;             --  blocks of its ground's walls and stairs still to lay, as last counted,
      Takes    : Per_Kind := [others => 0];  --  and what they take: logs, sheaves)
      Ladder   : Natural := 0;               --  a ladder stands at it: under which eave (1 front, 2 back, 3 left,
      Ladder_P : Vec3 := (0.0, 0.0, 0.0);    --  4 right; 0: none), and where its foot is
      Ladder_Fells : Natural := 0;           --  trees its builder has gone to fell for want of a log to make one of
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
   Beds_On   : Boolean := True;   --  each makes itself a bed of straw (off: as it was before they did)
   Hold_On   : Boolean := True;   --  the cook keeps a pot's fill of greens from being eaten raw (off: as before it did)
   Ladders_On : Boolean := True;  --  a roof is thatched from a ladder (off: from the ground, as it was)
   Holes_On  : Boolean := True;   --  a hole under a path is filled as it is laid (off: as it was)
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

   type Task_State is (Idle, To_Bush, Picking, To_Store, Storing, Strolling,
                       To_Tree, Chopping, To_Pile, Lifting, To_Source, Gathering,
                       Stalking, Aiming, Recovering, To_Carcass, Lifting_Carcass, To_Butcher, Butchering,
                       To_Eat, Eating, To_Bed, Sleeping,
                       To_Take, Taking, To_Camp, Putting_In, Cooking, To_Seat,
                       Stoking, To_Patch, Tamping,
                       To_Site, Raising,
                       To_Cart, At_Cart,
                       Making, To_Ladder,
                       To_Tow, Towing);
   --  (To_Site, Raising: a builder going to its house's site, and at work there)
   --  (To_Cart, At_Cart: going to the lord's cart for salt, and taking it out)
   --  (Making: a ladder, at the stockpile; To_Ladder: going to where one stands, to take it away)
   --  (saved by position: new states go on the end, as below)
   type Why_Idle is (Nothing_Yet, No_Bush, No_Room, No_Way, No_Tree, Enough_Wood, Nothing_To_Haul,
                     No_Source, Stocks_Full, No_Prey, Enough_Meat, Deer_Spared,
                     No_Camp, Pot_Full, Nothing_To_Cook, Winter_Bare, Enough_Food, Camp_Unbuilt,
                     No_Timber, No_Thatch, No_Stone);
   --  (No_Timber, No_Thatch, No_Stone: a builder with no wood, no straw or no stone to build with)
   --  what the cook is bringing to the camp (For_Store: nothing, its load is for a stockpile)
   --  (For_Stoke: no load at all: it goes to put a log from the stack on
   --  the fire.  For_Ring, For_Frame: stone and wood to build the hearth with,
   --  which anyone may be bringing, as a seat log.)
   --  (For_Floor: earth, for a hollow of the camp's floor.)
   --  (For_House: wood or straw, for the house it is building.)
   --  (For_Bed: straw, for its own bed.)
   --  (For_Ladder: a log, to make a ladder of.)
   type Camp_Use is (For_Store, For_Pot, For_Fire, For_Seat, For_Stoke, For_Ring, For_Frame, For_Floor, For_House,
                     For_Bed, For_Ladder);
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
            | To_Tow | Towing =>
           (if Band (I).Route.N >= 2 and then Band (I).Leg < Band (I).Route.N then Walking else Standing),
         when Tamping | Raising | Making => Picking,
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
           (if M.Use_For in For_Ring | For_Frame then Site_Work
            elsif M.Use_For = For_House then House_Raising
            elsif M.Use_For = For_Bed then Handling else Camp_Keeping),
         when To_Patch | Tamping                                  => Site_Work,
         when To_Site | Raising                                   =>
           (if M.Site_Patch > 0 then Site_Work else House_Raising),
         when Making | To_Ladder                                  => House_Raising,
         when Idle | Strolling | To_Eat | Eating | To_Bed | Sleeping | To_Seat | To_Tow | Towing => Handling);

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

   function Route_To (M : in out Member; Goal_Asked : Vec3; Near : Float := 0.0) return Boolean is
      Goal : constant Vec3 := (if Cart_Set then Off_Cart (Goal_Asked) else Goal_Asked);
   begin
      M.Route := Castle.Nav.Plan (M.Pos, Goal, Within => Own_Region);
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
         when To_Tow => 0.5,
         when Towing => 0.3,
         when others  => 0.0);

   procedure Keep_Route_Good (M : in out Member; Ok : out Boolean) is separate;

   ------------------------------------------------------------------ deciding

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
   function Under_Cart (K : Positive) return Boolean is
     (Cart_On_Block (B (Cells (K).Centre.X), B (Cells (K).Centre.Y))
      or else (Cart_Bound
               and then Bed_On_Block (Goal_P, Turn_Along_X (Goal_Turn), B (Cells (K).Centre.X), B (Cells (K).Centre.Y))));

   --  Stockpile place K takes N of kind Kind: one holding that with room for
   --  all of them, or an empty one; never one under the cart.  The one test
   --  of it (Go_Store, Room_For, Can_Store, the butchering's; Supply's empty
   --  places).
   function Takes (K : Positive; Kind : Item_Kind; N : Natural) return Boolean is
     (((Cells (K).Kind = Kind and then Cells (K).Count + Cells (K).Incoming + N <= Cell_Limit (Kind))
       or else (Cells (K).Kind = Nothing and then Cells (K).Incoming = 0))
      and then not Under_Cart (K));

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

   function Room_For (K : Item_Kind) return Boolean is (for some C in 1 .. N_Cells => Takes (C, K, 1));

   --  A stockpile cell takes the whole of what M carries: Go_Store's own
   --  test (the cells it has lately failed to get to left out).
   function Can_Store (M : Member) return Boolean is
     (for some K in 1 .. N_Cells => Takes (K, M.Carry, M.Carried) and then not Failed (M, Cell_Base + K));

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

   function Search_Reach return Float is (Float'Max (Work_Radius_M, Far_Reach));
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
   function Ground_Reach_M return Float is
     (Float'Max (Float'Max (Float'Max (Search_Reach, Path_Far), Housing_Far), Stores_Far));

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
      if Holes_On then
         For_Path_Work (Path_List (K), Bound'Access);
      end if;
      declare
         Any : constant Boolean := Holes_On and then X0 <= X1;
         --  the ground round the metre, its hollows filled (Fill_Hollows): what each column is laid at
         G : Top_Grid ((if Any then X0 - R else 1) .. (if Any then X1 + R else 0),
                       (if Any then Y0 - R else 1) .. (if Any then Y1 + R else 0));
         Raw : Top_Grid (G'Range (1), G'Range (2));
         --  (a column is raised only where the ground read round the metre is its own top: read from
         --  another height it could be a bough or a hump; and never by more than Hollow_Rise_B)
         procedure Turn (X, Y, Zr, M : Integer) is
            Top : constant Integer :=
              (if Any and then X in G'Range (1) and then Y in G'Range (2) and then Raw (X, Y) = Zr
                 and then G (X, Y) - Zr in 1 .. Hollow_Rise_B
               then G (X, Y) else Zr);
         begin
            if This_Metre (M) then
               Cut_Plants (X, Y, Zr);                    --  what grows on it cut (filled: over what it is filled to too)
               if Top > Zr then
                  Cut_Plants (X, Y, Top);
               end if;
               for Z in Zr .. Top - 1 loop               --  a hole filled with earth
                  Write_Src (X, Y, Z, (Mat => Dirt, State => 0));
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
            Fill_Hollows (G);
         end if;
         For_Path_Work (Path_List (K), Turn'Access);
      end;
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
   Site_Patch_Fail : constant := 20_100;   --  and no way to that patch of its ground (to 20_484)
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

   --  How many blocks the path's ground may lie above or below a house's
   --  pad for its door to be got to: a block where the path is hard by, a
   --  block for each column of the way past its landing otherwise.
   function Door_Steps (F : CB.House) return Natural is
     (Integer'Max (1, F.Door_Run - CB.Door_Landing_B));

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
   function In_Door_Way (F : CB.House; U, V : Integer) return Boolean is
     (V < 0 and then F.Door_Run > 0
      and then U in F.Openings (1).Offset .. F.Openings (1).Offset + F.Openings (1).Width - 1
      and then -V <= Integer'Max (F.Door_Run, Front_Of (F, U)));
   function Site_U_Lo (F : CB.House) return Integer is (-Apron_U (F) - F.Reach_L);
   function Site_U_Hi (F : CB.House) return Integer is (F.W - 1 + Apron_U (F) + F.Reach_R);
   function Site_V_Lo (F : CB.House) return Integer is
      M : Integer := CB.Apron_Front_B;
   begin
      for U in Site_U_Lo (F) .. Site_U_Hi (F) loop
         M := Integer'Max (M, Front_Of (F, U));
      end loop;
      return -M;
   end Site_V_Lo;
   function In_Site (F : CB.House; U, V : Integer) return Boolean is
     (U in Site_U_Lo (F) .. Site_U_Hi (F) and then V <= V_Hi (F) and then V >= -Front_Of (F, U));

   --  A column of its door's way that is a step of its stair.  There is a
   --  stair only where the path's ground lies more than a block above or
   --  below its floor (Retain_Over_B, as for a wall): a single block is a
   --  step like any other of the land's, left as earth (John, 2026-11-12,
   --  of a patch of stone before a door: "the stairs were added when the
   --  pathway was pretty much already leavel witht he house path").
   function Is_Stair (F : CB.House; U, V : Integer) return Boolean is
     (In_Door_Way (F, U, V) and then (-V > CB.Door_Landing_B or else -V > F.Door_Run)
      and then abs (F.Door_Row - (F.Pad - 1)) > Retain_Over_B);

   --  The row the top of the ground at (U, V) of a house's site is brought
   --  to, before any wall: its floor's, but on the way out from its door,
   --  past a landing at that level, a stair between it and the ground where
   --  that way meets the path (a block to a block at most: Place_House sees
   --  to it, by Door_Steps).
   function Level_Of (F : CB.House; U, V : Integer) return Integer is
      Pad : constant Integer := F.Pad - 1;
   begin
      return (if not In_Door_Way (F, U, V) then Pad
              elsif -V > F.Door_Run then F.Door_Row            --  (past the stair's foot, beside a path aslant)
              elsif -V > CB.Door_Landing_B
              then Pad + (F.Door_Row - Pad) * (-V - CB.Door_Landing_B) / (F.Door_Run - CB.Door_Landing_B)
              else Pad);
   end Level_Of;

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
         when For_Ring | For_Frame | For_Floor | For_House | For_Bed | For_Ladder =>
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
      then Bed_Place (Home_Of (I)) + (Float (Houses (Home_Of (I)).F.Vx), Float (Houses (Home_Of (I)).F.Vy), 0.0)
      elsif Band (I).Placed and then not (N_Houses > 0 and then Housed (I)) then Own_Facing (I)
      elsif Camp_Set then Camp_At else Stake_At);
   --  (the same for one that is to lie at Feet, wherever it stands now)
   function Bed_Facing_At (I : Positive; Feet : Vec3) return Vec3 is
     (if N_Houses > 0 and then Housed (I)
      then Feet + (Float (Houses (Home_Of (I)).F.Vx), Float (Houses (Home_Of (I)).F.Vy), 0.0)
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
                     for Up in 1 .. 3 loop
                        exit when Mat (X, Y, Z + Up) not in Tall_Grass | Wild_Grain | Wild_Vegetables;
                        Write_Src (X, Y, Z + Up, Air_Block);
                     end loop;
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
   --  (a roof's trimming is its thatch again, as it lies: work alone)
   function Kind_Of (Bk : BP_Block) return Item_Kind is
     (if Bk.S = CB.Dress then Nothing else Kind_Of_Block (Bk.M));

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
      Hs.Roof_N := 0;
      Hs.Dress_N := 0;
      for K in 1 .. BP_N loop
         N (Kind_Of (BP (K))) := N (Kind_Of (BP (K))) + 1;
         if Kind_Of (BP (K)) = Wood then
            Hs.Wood_N := K;
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
     (if Houses (H).Built or else Houses (H).Got (K) >= Houses (H).Takes (K) then 0
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
   --  the earth for them is always there, as for the camp's floor),
   --  reckoned as if its hollows were filled: they are, with the turf cut
   --  off its floor (Fill_Hollows).  Reckoned on the ground as it lies, a hole or
   --  two in level ground wanted earth that nothing dug off gave, and the
   --  whole lot was dug down to their bottoms instead (John, 2026-11-13:
   --  "othewise even ground was dug out entirely becuase it had a couple
   --  of holes in it, instead of just filling the holes").  A slope has
   --  no holes: its pad is where it was.
   procedure Choose_Pad (F : in out CB.House) is
      Au : constant Integer := Apron_U (F);
      Tops : Top_Grid (-CB.Apron_B - 1 .. CB.Max_Width_B + CB.Apron_B,
                       -(CB.Max_Push_B + CB.Setback_Max_B + 6) - 1 .. CB.Max_Depth_B + CB.Apron_B) :=
        [others => [others => -1]];                              --  -1: not of its lot
      Lo : Integer := Integer'Last;
      Hi : Integer := Integer'First;
   begin
      for U in -Au .. F.W - 1 + Au loop
         for V in -Front_Of (F, U) .. V_Hi (F) loop
            Tops (U, V) := Lot_Cell (H_X (F, U, V), H_Y (F, U, V)) - 1;
         end loop;
      end loop;
      Fill_Hollows (Tops);
      for V in 0 .. F.D - 1 loop
         for U in 0 .. F.W - 1 loop
            Lo := Integer'Min (Lo, Tops (U, V));
            Hi := Integer'Max (Hi, Tops (U, V));
         end loop;
      end loop;
      for Level in reverse Lo .. Hi loop
         F.Pad := Level + 1;
         declare
            Cut, Fill : Natural := 0;
         begin
            for U in -Au .. F.W - 1 + Au loop
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
            exit when Cut >= Fill;
         end;
      end loop;
   end Choose_Pad;

   --  A house's front yard as it is placed: at each place along its front,
   --  the free ground of its zone straight out from its front wall's line,
   --  as far as that goes (to its path's edge, as a rule).
   procedure Front_Yard (F : in out CB.House) is
      Most : constant := CB.Max_Push_B + CB.Setback_Max_B + 6;
   begin
      F.Front := [others => 0];
      for U in -Apron_U (F) .. F.W - 1 + Apron_U (F) loop
         declare
            N : Natural := 0;
         begin
            while N < Most and then Lot_Cell (H_X (F, U, -(N + 1)), H_Y (F, U, -(N + 1))) > 0 loop
               N := N + 1;
            end loop;
            --  (straight out past the end of its path, or to something else
            --  in the way: no further than the least a yard is)
            if N = Most
              or else not Near_Path ((Float (H_X (F, U, -(N + 1))) + 0.5) * 0.25,
                                     (Float (H_Y (F, U, -(N + 1))) + 0.5) * 0.25, 0.0)
            then
               N := Natural'Min (N, CB.Apron_Front_B);
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

   --  A house where it is put, on the grid as it is filled: its yard to its
   --  path, its pad's level and its door's way worked out.  Verdict: how its
   --  lot lies; Ok: it can stand there, its door got to from its path.
   procedure Try_Lot (G : in out CB.House; Verdict : out Lot_Verdict; Ok : out Boolean) is
   begin
      Ok := False;
      G.Door_Run := 0;
      Verdict := Check_Lot (G);
      if Verdict /= Clear then
         return;
      end if;
      Front_Yard (G);
      Choose_Pad (G);
      Door_Way (G);
      --  its door has to be got to from the path: a pad that would stand
      --  higher over the path's ground than its door's way can step down is
      --  cut deeper; one that would lie further below it steps back for a
      --  longer way, if there is room
      if G.Door_Run > 0 and then G.Pad - 1 > G.Door_Row + Door_Steps (G) then
         G.Pad := G.Door_Row + Door_Steps (G) + 1;
      end if;
      Ok := G.Door_Run > 0 and then G.Pad - 1 >= G.Door_Row - Door_Steps (G);
   end Try_Lot;

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
                  declare
                     Verdict : Lot_Verdict;
                     Stands  : Boolean;
                  begin
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
   function Lots_Short return Boolean is (Lots_Are_Short);

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
                  if A.Ux = F.Ux and then A.Uy = F.Uy and then A.Vx = F.Vx and then A.Vy = F.Vy
                    and then Dv <= F.D - 1 and then Dv + A.D - 1 >= 0
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

   --  A house that stands and is nobody's is drawn for by lot among the
   --  living who have none (John, 2026-11-12: "just assign it to them by
   --  lottery, when the construction is complete").  The draw is made from
   --  the house's seed and how many are in it: the same house among the same
   --  people falls to the same one.
   procedure Draw_Owner (H : Positive) is
      N : Natural := 0;
   begin
      if Houses (H).Owner /= 0 or else not Houses (H).Built then
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
         if not Houses (H).Built then
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

   function Site_Patch_At (U, V : Integer) return Positive is
     (((U + CB.Apron_B + CB.Max_Reach_B) / 4) * 16 + (V + 32) / 4 + 1);
   --  (U from as far to its left as its ground can reach, V from -30, as far as a front yard can)
   --  (how far back from its path a patch lies: the nearest are worked first)
   function Patch_Band (P : Positive) return Natural is ((P - 1) mod 16);

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
           or else (U in -1 .. F.W and then V in -1 .. F.D
                    and then (for some Z in F.Pad .. House_Top (F) =>
                                Mat (X, Y, Z) in Crown or else Mat (X, Y, Z) in Trunk))
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
      for V in Site_V_Lo (F) .. V_Hi (F) loop
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
         P    : constant Positive := Site_Patch_At (Pu, Pv);
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
      --  standing by is lopped
      if U in -1 .. F.W and then V in -1 .. F.D then
         for Z in F.Pad .. House_Top (F) loop
            if Mat (X, Y, Z) in Crown or else Mat (X, Y, Z) in Trunk then
               Write_Src (X, Y, Z, Air_Block);
            end if;
         end loop;
      end if;
   end Level_Column;

   --  Patch P of house H's site: its earth moved (0: all of the site's).
   procedure Level_Patch (H : Positive; P : Natural) is
      procedure Level (K : Positive; U, V : Integer; Pu, Pv : Integer) is
      begin
         if P = 0 or else Site_Patch_At (Pu, Pv) = P then
            Level_Column (K, U, V);
         end if;
      end Level;
      procedure Level_All is new For_Site (Level);
   begin
      Level_All (H);
   end Level_Patch;

   --  Stone laid in patch P of house H's site (0: all of it), from the foot
   --  of each wall up, where no earth is left to move, in place of whatever
   --  earth stands there: Most blocks at most.  Laid: how many were.
   procedure Wall_Patch (H : Positive; P : Natural; Most : Natural; Laid : out Natural) is
      Done : Natural := 0;
      procedure Lay (K : Positive; U, V : Integer; Pu, Pv : Integer) is
         Work : Ground_Work;
         N    : Natural;
      begin
         if Done >= Most or else not (P = 0 or else Site_Patch_At (Pu, Pv) = P) then
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

   --  The footpath from a house's door to the path it fronts: the top of
   --  the ground of its door's way (made a stair with the rest of its
   --  ground) turned to footpath, and what grows on it cut.
   procedure Lay_Door_Path (H : Positive) is
      F    : CB.House renames Houses (H).F;
      Door : CB.Opening renames F.Openings (1);
   begin
      for U in Door.Offset .. Door.Offset + Door.Width - 1 loop
         for T in 1 .. Integer'Max (F.Door_Run, (if F.Door_Run > 0 then Front_Of (F, U) else 0)) loop
            declare
               X   : constant Integer := H_X (F, U, -T);
               Y   : constant Integer := H_Y (F, U, -T);
               Top : constant Integer := Top_By (X, Y, Level_Of (F, U, -T));
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
      Draw_Owner (H);                       --  (it is somebody's from the moment it stands)
   end Finish_House;

   --  House H built on the spot, nothing taken from anywhere.
   procedure Raise_Now (H : Positive) is
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
         Write_Src (Integer (BP (K).X), Integer (BP (K).Y), Integer (BP (K).Z), (Mat => BP (K).M, State => BP (K).St));
      end loop;
      Hs.Placed := BP_N;
      Hs.Got := Hs.Takes;
      Finish_House (H);
   end Raise_Now;

   procedure Build_Homes_Now (Last_First : Boolean := False) is
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
               Raise_Now (H);
            end if;
         end;
      end loop;
      while Without_A_House > 0 loop
         Begin_Lot (Ok);
         exit when not Ok;
         Raise_Now (N_Houses);
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
         elsif K = Stone and then Camp_Set then Hearth_Short (Stone)       --  (the hearth's stones first)
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
                   elsif Hs.Placed < Hs.Walls_N then Walling elsif Hs.Placed < Hs.Roof_N then Roofing
                   else Trimming),
         Blocks => Hs.Total, Placed => Hs.Placed, Takes => Hs.Takes, Got => Hs.Got,
         Waits => (if Hs.Built then Not_Waiting
                   elsif Bd = 0 then For_A_Builder
                   elsif Failed (Band (Bd), Site_Fail + K) then For_A_Way
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
         Door => H_Point (F, Float (Door.Offset) + Float (Door.Width) / 2.0 - 0.5, -2.5),
         Way => F.Door_Run, Rise => (if F.Door_Run > 0 then F.Pad - 1 - F.Door_Row else 0),
         Bed => Bed_Place (K),
         Top_Z => Float (F.Pad + F.Wall_H + (if F.Ridge_Along_U then (F.D + 1) / 2 else (F.W + 1) / 2)) * 0.25,
         Has_Bed => Hs.Bed, Reach_L => F.Reach_L, Reach_R => F.Reach_R);
   end House_At;

   --  Its bed: straw for one, then to where it sleeps with it.  True: it
   --  is seeing to it.
   function Think_Bed (I : Positive) return Boolean is separate;

   --  A builder at its house: a load for it carried there; its ground made
   --  ready; then its blueprint laid from what lies there, and more fetched
   --  from the stores when that runs out.  False: nothing of it for M to do
   --  now (no house wants a builder, or there is nothing to build with: it
   --  goes on as the forester it is).
   ------------------------------------------------------------------ housing: a ladder for the roof

   Ladder_Fail : constant := 20_600;   --  fail memos: no way to that house's ladder, or to stand one at it (to 20_648)

   procedure Set_Ladders (On : Boolean) is
   begin
      Ladders_On := On;
   end Set_Ladders;

   procedure Set_Path_Holes (On : Boolean) is
   begin
      Holes_On := On;
   end Set_Path_Holes;
   function Path_Holes return Boolean is (Holes_On);
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
      D0 : constant Float := Float (F.Openings (1).Offset);
      D1 : constant Float := Float (F.Openings (1).Offset + F.Openings (1).Width - 1);
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

   function Aloft (I : Positive) return Boolean is
     (I <= N_Members and then not Band (I).Is_Dead and then Band (I).State = Raising and then Band (I).Site_Patch = 0
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
         and then not Under_Cart (K));
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

   type Path_Refused is (Laid_Some, Nothing_There, Through_Zone, No_More, Through_Cart);
   Path_Refused_For : Path_Refused := Laid_Some;

   function Path_Refusal return String is
     (case Path_Refused_For is
         when Laid_Some     => "",
         when Nothing_There => "there is no ground there to lay a path on",
         when Through_Zone  => "a zone is in the way: paths go round zones",
         when No_More       => "there are as many paths as there can be",
         when Through_Cart  => "the lord's cart is in the way: it cannot be moved yet");

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
   procedure Plan_Housing_Lot (X0, Y0, X1, Y1 : Float; Count : Boolean := True) is
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
      for K in 1 .. N_Paths loop
         if Seg_Dist (P0, Path_List (K)) < Best_D then
            Best_D := Seg_Dist (P0, Path_List (K));
            Best := K;
         end if;
      end loop;
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
                     if A >= Lo and then A < Hi and then Off > 0.0 and then Off < Deep then
                        if Path_Here (P) then
                           Plan_At_Path := True;
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
               when No_Ground => "there is no clear ground there to build on",
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
         --  the other zones' runs moved down over the gaps, then this zone's
         for Z in 1 .. N_Zones loop
            if not Joined (Z) then
               declare
                  First_Was : constant Natural := Zones (Z).First;
               begin
                  Zones (Z).First := Packed;
                  for K in 1 .. Zones (Z).N loop
                     Runs (Packed + K) := Runs (First_Was + K);
                  end loop;
                  Packed := Packed + Zones (Z).N;
               end;
            end if;
         end loop;
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
         N_Zones := N_Zones + 1;
         Zones (N_Zones) := (Kind => Habitation_Zone, others => <>);
         Take_Plan (N_Zones);
         Zoned_Last := N_Zones;
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
              Trade => Trade_Of (I), Site => Site_Of (I), Home => Home_Of (I), Housed => Housed (I),
              Has_Bed => Has_Bed (I));
   end Person;

   ------------------------------------------------------------------ saves

   Save_Version : constant := 25;   --  25: housing: the houses (their front yards and their stone with them), the
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
