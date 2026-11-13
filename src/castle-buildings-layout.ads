with Castle.Maps; use Castle.Maps;

--  The first layout of tier-1 habitation, on the generated fields: a
--  pathway network (standing in for the player's designation), a zone, and
--  one house per resident attached to the pathways, nearest the stake by
--  walking distance first, some sharing a side wall.  village_preview draws
--  it.  The game does not use it: there the colony places houses on the
--  ground its housing zones fill (Castle.Colony, "housing"), with the same
--  houses (Castle.Buildings.Blueprint).
package Castle.Buildings.Layout is

   type Point is record
      X, Y : Float := 0.0;   --  metres
   end record;
   type Point_List is array (1 .. 8) of Point;

   type Pathway is record
      Count      : Natural := 0;
      Pts        : Point_List;
      Width      : Float := 2.0;    --  metres
      Start_Dist : Float := 0.0;    --  walking distance from the stake to Pts (1)
   end record;
   type Pathway_List is array (1 .. 8) of Pathway;

   type Network is record
      Count : Natural := 0;
      Ways  : Pathway_List;
   end record;

   Max_Houses : constant := 48;
   type House_List is array (1 .. Max_Houses) of House;

   Free_Cell   : constant := 0;
   Path_Cell   : constant := -1;    --  a designated pathway
   Margin_Cell : constant := -2;    --  the 0.25 m kept clear along a pathway
   Door_Cell   : constant := -3;    --  path from a door to the pathway

   type Occupancy is array (Integer range <>, Integer range <>) of Integer;   --  > 0: house number
   type Occupancy_Access is access Occupancy;

   type Plan is record
      Count  : Natural := 0;
      Shared : Natural := 0;   --  side walls shared
      Houses : House_List;
      Occ    : Occupancy_Access;
   end record;

   procedure Lay_Out
     (W : World; Net : Network; X0, Y0, X1, Y1 : Integer; Residents : Positive; P : out Plan);
   --  X0 .. X1 - 1 by Y0 .. Y1 - 1: the habitation zone (blocks).

   generic
      with procedure Column (Bx, By, Old_Top, New_Top : Integer);
   procedure Level (W : World; H : House; Id : Positive; Occ : Occupancy);
   --  Site work: the pad and its feathered bank, one call per block column
   --  (tops are counts of ground blocks), never touching another house.

end Castle.Buildings.Layout;
