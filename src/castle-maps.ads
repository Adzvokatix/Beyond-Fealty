with Castle.Hash;
with Castle.Fields; use Castle.Fields;

--  The persistent output of world generation.  Read-only after
--  Castle.Worldgen.Create, so any number of threads may sample it.
package Castle.Maps is

   type Water_Kind is (Dry, Shore, Stream, River, Lake) with Size => 8;

   type Kind_Field is array (Cell_Range) of Water_Kind with Component_Size => 8;
   type Kind_Access is access Kind_Field;

   type Flow_Dir is range -1 .. 7 with Size => 8;   --  D8 drainage; -1 leaves the map
   Dir_DX : constant array (Flow_Dir range 0 .. 7) of Integer := (1, 1, 0, -1, -1, -1, 0, 1);
   Dir_DY : constant array (Flow_Dir range 0 .. 7) of Integer := (0, 1, 1, 1, 0, -1, -1, -1);
   type Dir_Field is array (Cell_Range) of Flow_Dir with Component_Size => 8;
   type Dir_Access is access Dir_Field;

   type Channel_Seeds is array (0 .. 63) of Castle.Hash.U64;

   --  Every common resource shows at the surface.  Coal, iron and salt
   --  are veins: a tree of tapering tubes that starts at a small outcrop
   --  and roots down into the ground, snaking and branching.  Gold and
   --  silver sit in the deep tips of some veins, never near the outcrop.
   --  Bog iron is a shallow patch under rust-speckled turf.
   type Deposit_Kind is (Coal_Vein, Iron_Vein, Salt_Vein, Bog_Iron_Patch);

   type Deposit is record
      Kind           : Deposit_Kind := Coal_Vein;
      Cx, Cy         : Float := 0.0;   --  outcrop / patch centre (m)
      Ca             : Float := 1.0;   --  veins: heading of the trunk into the ground
      Sa             : Float := 0.0;
      Radius         : Float := 1.0;   --  veins: trunk radius at the outcrop; patches: radius (m)
      X0, Y0, X1, Y1 : Float := 0.0;   --  veins: map footprint of every tube and the loose ore
      First_Tube     : Positive := 1;  --  veins: tubes First_Tube .. Last_Tube of W.Tubes
      Last_Tube      : Natural := 0;
      Reach          : Float := 0.0;   --  veins: longest path from the outcrop (m)
      Deepest        : Float := 0.0;   --  veins: most ground over any tube (m)
      Precious_Cover : Float := 0.0;   --  veins: least ground over its silver or gold (m)
      Thick          : Float := 0.0;   --  patches: maximum thickness (m)
      Depth          : Float := 0.0;   --  patches: depth of the top below ground (m)
      Reserves       : Float := 0.0;   --  base ore (m^3)
      Silver_Vol     : Float := 0.0;   --  silver ore (m^3)
      Gold_Vol       : Float := 0.0;   --  gold ore (m^3)
      Seed           : Castle.Hash.U64 := 0;
   end record;

   --  One tube of a vein: an axis from A (the outcrop side) to B, tapering
   --  from radius Ra to Rb.
   type Vein_Tube is record
      Ax, Ay, Az   : Float := 0.0;
      Bx, By, Bz   : Float := 0.0;
      Ra, Rb       : Float := 0.0;
      Owner        : Natural := 0;   --  deposit
      Parent       : Natural := 0;   --  tube it grows from (0: the trunk's first)
      Path         : Float := 0.0;   --  metres along the vein from the outcrop to A
      Silver, Gold : Float := 0.0;   --  share of the tube's ore that is silver / gold
   end record;
   type Tube_Array is array (Positive range <>) of Vein_Tube;
   type Tube_Array_Access is access Tube_Array;

   --  Tube index: 16 m cells, each listing the tubes whose footprint
   --  (plus 2 m) touches it, packed: cell C owns items Start (C) .. Start (C + 1) - 1.
   Tube_Cell_M : constant := 16;
   Tube_N      : constant := N / Tube_Cell_M;
   type Tube_Starts is array (0 .. Tube_N * Tube_N) of Positive;
   type Tube_Starts_Access is access Tube_Starts;
   type Tube_Items is array (Positive range <>) of Positive;
   type Tube_Items_Access is access Tube_Items;

   Max_Near : constant := 40;
   type Tube_Ids is array (1 .. Max_Near) of Positive;
   type Near_Tubes is record
      Count : Natural  := 0;
      Ids   : Tube_Ids := (others => 1);
   end record;
   --  The tubes near one vertical line of the world (see Castle.Deposits.Gather).

   type Deposit_Array is array (Positive range <>) of Deposit;
   type Deposit_Array_Access is access Deposit_Array;

   --  Spatial index: 64 m cells listing the deposits whose footprint
   --  touches them.
   Index_Cell_M : constant := 64;
   Index_N      : constant := N / Index_Cell_M;
   Max_Per_Cell : constant := 32;

   type Index_Slots is array (1 .. Max_Per_Cell) of Positive;
   type Index_Entry is record
      Count : Natural     := 0;
      Items : Index_Slots := (others => 1);
   end record;
   type Deposit_Index is array (0 .. Index_N - 1, 0 .. Index_N - 1) of Index_Entry;
   type Deposit_Index_Access is access Deposit_Index;

   function Index_Of (M : Float) return Integer is
     (Integer'Max (0, Integer'Min (Index_N - 1, Integer (Float'Floor (M)) / Index_Cell_M)));

   type World is record
      Seed        : Castle.Hash.U64 := 0;
      Ch          : Channel_Seeds   := (others => 0);
      Height      : Field_Access;   --  ground surface (m), rivers carved
      Mountain    : Field_Access;   --  mountain mask 0 .. 1
      Water       : Field_Access;   --  open-water surface (m), 0.0 where dry
      Kind        : Kind_Access;
      Down        : Dir_Access;     --  drainage direction of every 1 m cell
      Flow        : Field_Access;   --  upstream catchment (m^2)
      Dist_Water  : Field_Access;   --  distance to open water (m)
      Moisture    : Field_Access;   --  0 .. 1
      Water_Table : Field_Access;   --  phreatic surface (m)
      Aquifer     : Field_Access;   --  well yield 0 .. 1
      Slope       : Field_Access;   --  |grad h| (m/m)
      Fold        : Coarse_Access;  --  strata offset (m)
      Granite_Top : Coarse_Access;  --  top of crystalline basement (m)
      Deposits    : Deposit_Array_Access;
      Index       : Deposit_Index_Access;
      Tubes       : Tube_Array_Access;
      Tube_Start  : Tube_Starts_Access;
      Tube_Item   : Tube_Items_Access;
   end record;

   procedure Allocate (W : out World; Seed : Castle.Hash.U64);

   function Deposit_Count (W : World) return Natural is
     (if W.Deposits = null then 0 else W.Deposits'Length);

end Castle.Maps;
