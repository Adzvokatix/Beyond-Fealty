with Ada.Real_Time;
with Ada.Unchecked_Deallocation;
with Ada.Containers.Hashed_Sets;
with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Castle.Blocks; use Castle.Blocks;

package body Castle.Nav is

   use Interfaces;

   Columns_Src : Column_Reader;
   Blocks_Src  : Block_Reader;
   Version_Src : Version_Reader;
   Changes_Src : Changes_Reader;

   ---------------------------------------------------------------- the map

   type Packed_Floor is record
      Z     : Integer_16 := 0;
      Head  : Unsigned_8 := 0;
      Water : Unsigned_8 := 0;
      Speed : Float := 0.0;
   end record;
   type Packed_Floors is array (1 .. Max_Floors) of Packed_Floor;
   type Cell is record
      N : Natural range 0 .. Max_Floors := 0;
      F : Packed_Floors;
   end record;
   Empty : constant Cell := (N => 0, F => <>);

   type Cell_Grid is array (0 .. Cells_Per_Stack - 1, 0 .. Cells_Per_Stack - 1) of Cell;

   --  The pieces of a stack's ground: floors joined by a step either way,
   --  numbered 1 .. N_Comp (0: a floor not walked on).  Edges: which sides
   --  of the stack each piece reaches (1 east, 2 west, 4 north, 8 south).
   --  A border holds the pairs of pieces a step joins across the stack's
   --  east or north edge, as the two stacks were (their versions).
   Max_Comps : constant := Cells_Per_Stack * Cells_Per_Stack * Max_Floors;
   type Comp_Grid is array (0 .. Cells_Per_Stack - 1, 0 .. Cells_Per_Stack - 1, 1 .. Max_Floors) of Unsigned_16;
   type Edge_Masks is array (1 .. Max_Comps) of Unsigned_8;
   Max_Links : constant := Cells_Per_Stack * Max_Floors * Max_Floors;
   type Link is record
      Here, There : Unsigned_16 := 0;
   end record;
   type Link_Array is array (1 .. Max_Links) of Link;
   type Border is record
      Valid         : Boolean := False;
      My_V, Their_V : Natural := 0;
      N             : Natural := 0;
      L             : Link_Array;
   end record;

   type Stack_Nav is record
      Version : Natural := 0;            --  the ground's version it is read at
      Shape   : Natural := 0;            --  moves only when a cell of it changes (borders go by this)
      Cells   : Cell_Grid;
      Comp    : Comp_Grid := [others => [others => [others => 0]]];
      N_Comp  : Natural := 0;
      Edges   : Edge_Masks := [others => 0];
      East, North : Border;
   end record;
   type Stack_Nav_Access is access Stack_Nav;
   procedure Free is new Ada.Unchecked_Deallocation (Stack_Nav, Stack_Nav_Access);

   Stacks_XY : constant := Cells_XY / Cells_Per_Stack;
   type Nav_Grid is array (0 .. Stacks_XY - 1, 0 .. Stacks_XY - 1) of Stack_Nav_Access;
   type Nav_Grid_Access is access Nav_Grid;
   Navs : constant Nav_Grid_Access := new Nav_Grid;

   Shapes : Natural := 0;           --  the count Shape is stamped from
   Built : Natural := 0;            --  stacks (re)built during the current call
   Last  : Stats;
   Tot   : Totals_Rec;
   Slow  : Slow_List;

   function Ground_Speed (M : Material) return Float is
     (case M is
         when Footpath | Plank             => Best_Speed,
         when Grass | Dirt                 => 1.0,
         when Gravel | Placer_Gravel | Clay => 0.9,
         when Trunk                        => 0.8,
         when Sand                         => 0.75,
         when Bog_Iron                     => 0.6,
         when Shingle | Thatch | Air | Castle.Blocks.Water => 0.0,   --  roofs are not walked on
         when others                       => 0.85);   --  rock, ore, a boulder's top

   function Brush_Speed (M : Material) return Float is
     (case M is
         when Tall_Grass                           => 0.92,
         when Wild_Grain                           => 0.7,
         when Wild_Vegetables                      => 0.85,
         when Berry_Bush | Bare_Bush               => 0.4,
         when Crown                                => 0.5,
         when others                               => 1.0);

   Wading : constant array (0 .. Wade_B) of Float := [1.0, 0.55, 0.3];

   --  A cell's floors from its four columns.  A floor at row Z needs every
   --  column open from Z up for Head_B rows (nothing in the way of the
   --  body), and at least two of them standing on ground no more than a
   --  block below Z (a hole or a step in the rest of the footprint is
   --  stepped over).
   procedure Build_Cell (Cx, Cy : Integer; C : out Cell) is
      Bx0  : constant Integer := Cx * Cell_B;
      By0  : constant Integer := Cy * Cell_B;
      Cols : array (0 .. 3) of Castle.Water.Column;
      Cand : array (1 .. 4 * Castle.Water.Max_Stretch) of Integer := [others => 0];
      NC   : Natural := 0;
      Hold : array (0 .. 3) of Natural;
      Known : Boolean;
   begin
      C := Empty;
      for K in 0 .. 3 loop
         Columns_Src (Bx0 + K mod 2, By0 + K / 2, Cols (K), Known);
         if not Known then
            return;
         end if;
         for S in 1 .. Cols (K).N loop
            declare
               Z   : constant Integer := Cols (K).S (S).Floor;
               New_One : Boolean := True;
            begin
               for I in 1 .. NC loop
                  if Cand (I) = Z then
                     New_One := False;
                  end if;
               end loop;
               if New_One then
                  NC := NC + 1;
                  Cand (NC) := Z;
               end if;
            end;
         end loop;
      end loop;
      --  highest first
      for I in 2 .. NC loop
         declare
            V : constant Integer := Cand (I);
            J : Natural := I - 1;
         begin
            while J >= 1 and then Cand (J) < V loop
               Cand (J + 1) := Cand (J);
               J := J - 1;
            end loop;
            Cand (J + 1) := V;
         end;
      end loop;

      for Ci in 1 .. NC loop
         exit when C.N = Max_Floors;
         declare
            Z       : constant Integer := Cand (Ci);
            Open    : Boolean := True;
            Support : Natural := 0;
            Head    : Integer := 255;
            Water   : Integer := 0;
            Sum     : Float := 0.0;
         begin
            for K in 0 .. 3 loop
               Hold (K) := 0;
               for S in 1 .. Cols (K).N loop
                  if Cols (K).S (S).Floor <= Z and then Cols (K).S (S).Ceil >= Z + Head_B then
                     Hold (K) := S;
                     exit;
                  end if;
               end loop;
               if Hold (K) = 0 then
                  Open := False;
                  exit;
               end if;
            end loop;
            if Open then
               for K in 0 .. 3 loop
                  declare
                     St : Castle.Water.Stretch renames Cols (K).S (Hold (K));
                     Bx : constant Integer := Bx0 + K mod 2;
                     By : constant Integer := By0 + K / 2;
                  begin
                     Head := Integer'Min (Head, St.Ceil - Z);
                     Water := Integer'Max (Water, St.Floor + St.Water - Z);
                     if St.Floor >= Z - 1 then
                        Support := Support + 1;
                        Sum := Sum + Ground_Speed (Blocks_Src (Bx, By, St.Floor - 1))
                                     * Brush_Speed (Blocks_Src (Bx, By, Z));
                     end if;
                  end;
               end loop;
               if Support >= 2 then
                  declare
                     Speed : Float := Sum / Float (Support);
                  begin
                     if Water > Wade_B then
                        Speed := 0.0;
                     else
                        Speed := Speed * Wading (Water);
                     end if;
                     C.N := C.N + 1;
                     C.F (C.N) := (Z     => Integer_16 (Z),
                                   Head  => Unsigned_8 (Integer'Min (255, Head)),
                                   Water => Unsigned_8 (Integer'Min (255, Water)),
                                   Speed => Speed);
                  end;
               end if;
            end if;
         end;
      end loop;
   end Build_Cell;

   procedure Label_Stack (P : in out Stack_Nav);   --  (below, with the steps)

   procedure Read_Whole (SX, SY : Integer; P : in out Stack_Nav) is
   begin
      for I in 0 .. Cells_Per_Stack - 1 loop
         for J in 0 .. Cells_Per_Stack - 1 loop
            Build_Cell (SX * Cells_Per_Stack + I, SY * Cells_Per_Stack + J, P.Cells (I, J));
         end loop;
      end loop;
   end Read_Whole;

   --  A mended stack must be the stack read whole: its cells, and with them
   --  its pieces.  (Assertions on: the debug build, where every mend is
   --  checked this way.)
   procedure Check_Mended (SX, SY : Integer; P : Stack_Nav) is
      Q : Stack_Nav_Access := new Stack_Nav;
   begin
      Read_Whole (SX, SY, Q.all);
      if Q.Cells /= P.Cells then
         Free (Q);
         raise Program_Error with "Castle.Nav: stack" & SX'Image & SY'Image & " mended is not the stack read whole";
      end if;
      Label_Stack (Q.all);
      if Q.Comp /= P.Comp or else Q.N_Comp /= P.N_Comp then
         Free (Q);
         raise Program_Error with "Castle.Nav: stack" & SX'Image & SY'Image & " mended has other pieces of ground";
      end if;
      Free (Q);
   end Check_Mended;

   function Stack (SX, SY : Integer) return Stack_Nav_Access is
   begin
      if Version_Src = null or else SX not in Nav_Grid'Range (1) or else SY not in Nav_Grid'Range (2) then
         return null;
      end if;
      declare
         V : constant Natural := Version_Src (SX, SY);
         P : Stack_Nav_Access renames Navs (SX, SY);
      begin
         if V = 0 then
            if P /= null then
               Free (P);
            end if;
            return null;
         end if;
         if P = null then
            P := new Stack_Nav;
         end if;
         if P.Version /= V then
            declare
               N         : Natural := 0;
               Cols      : Castle.World_Blocks.Changed_List;
               All_Of_It : Boolean := True;
               T0        : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
               use type Ada.Real_Time.Time;
            begin
               if Mending and then Changes_Src /= null and then P.Version > 0 then
                  Changes_Src (SX, SY, P.Version, N, Cols, All_Of_It);
               end if;
               if All_Of_It then
                  Read_Whole (SX, SY, P.all);
                  Label_Stack (P.all);
                  Shapes := Shapes + 1;
                  P.Shape := Shapes;
                  Tot.Stacks_Built := Tot.Stacks_Built + 1;
                  Tot.Cells_Built := Tot.Cells_Built + Cells_Per_Stack * Cells_Per_Stack;
                  Tot.Labellings := Tot.Labellings + 1;
               else
                  --  mended: the cells over the changed columns, and the pieces
                  --  only if one of them came out otherwise
                  declare
                     Changed : Boolean := False;
                     C       : Cell;
                  begin
                     for K in 1 .. N loop
                        declare
                           Cx : constant Integer := Cols (K).Bx / Cell_B;
                           Cy : constant Integer := Cols (K).By / Cell_B;
                           I  : constant Integer := Cx - SX * Cells_Per_Stack;
                           J  : constant Integer := Cy - SY * Cells_Per_Stack;
                           Seen : Boolean := False;
                        begin
                           for E in 1 .. K - 1 loop
                              Seen := Seen or else (Cols (E).Bx / Cell_B = Cx and then Cols (E).By / Cell_B = Cy);
                           end loop;
                           if not Seen and then I in 0 .. Cells_Per_Stack - 1 and then J in 0 .. Cells_Per_Stack - 1 then
                              Build_Cell (Cx, Cy, C);
                              Tot.Cells_Built := Tot.Cells_Built + 1;
                              if C /= P.Cells (I, J) then
                                 P.Cells (I, J) := C;
                                 Changed := True;
                              end if;
                           end if;
                        end;
                     end loop;
                     if Changed then
                        Label_Stack (P.all);
                        Shapes := Shapes + 1;
                        P.Shape := Shapes;
                        Tot.Labellings := Tot.Labellings + 1;
                     end if;
                     Tot.Stacks_Mended := Tot.Stacks_Mended + 1;
                     pragma Debug (Check_Mended (SX, SY, P.all));
                  end;
               end if;
               Tot.Map_Seconds := Tot.Map_Seconds + Long_Float (Ada.Real_Time.To_Duration (Ada.Real_Time.Clock - T0));
            end;
            P.Version := V;
            Built := Built + 1;
         end if;
         return P;
      end;
   end Stack;

   --  The last stack looked at: neighbours mostly share it.  Valid only
   --  within one call (between calls the ground may change).
   Cache_SX, Cache_SY : Integer := -1;
   Cache_P : Stack_Nav_Access;

   procedure Reset_Cache is
   begin
      Cache_SX := -1;
      Cache_SY := -1;
      Cache_P := null;
   end Reset_Cache;

   function Cell_At (Cx, Cy : Integer) return Cell is
   begin
      if Cx not in 0 .. Cells_XY - 1 or else Cy not in 0 .. Cells_XY - 1 then
         return Empty;
      end if;
      declare
         SX : constant Integer := Cx / Cells_Per_Stack;
         SY : constant Integer := Cy / Cells_Per_Stack;
      begin
         if SX /= Cache_SX or else SY /= Cache_SY then
            Cache_P := Stack (SX, SY);
            Cache_SX := SX;
            Cache_SY := SY;
         end if;
         if Cache_P = null then
            return Empty;
         end if;
         return Cache_P.Cells (Cx mod Cells_Per_Stack, Cy mod Cells_Per_Stack);
      end;
   end Cell_At;

   procedure Set_Source (Columns : Column_Reader; Blocks : Block_Reader; Version : Version_Reader;
                         Changes : Changes_Reader := null) is
   begin
      Columns_Src := Columns;
      Blocks_Src := Blocks;
      Version_Src := Version;
      Changes_Src := Changes;
      Forget;
   end Set_Source;

   procedure Forget is
   begin
      Reset_Cache;
      for P of Navs.all loop
         if P /= null then
            Free (P);
         end if;
      end loop;
   end Forget;

   procedure Forget_Stack (CX, CY : Integer) is
   begin
      Reset_Cache;
      if CX in Nav_Grid'Range (1) and then CY in Nav_Grid'Range (2) and then Navs (CX, CY) /= null then
         Free (Navs (CX, CY));
      end if;
   end Forget_Stack;

   function Unpack (F : Packed_Floor) return Floor is
     ((Z => Integer (F.Z), Head => Natural (F.Head), Water => Natural (F.Water), Speed => F.Speed));

   procedure Floors_At (Cx, Cy : Integer; N : out Natural; F : out Floor_List) is
      C : Cell;
   begin
      Reset_Cache;
      C := Cell_At (Cx, Cy);
      N := C.N;
      F := [others => <>];
      for I in 1 .. C.N loop
         F (I) := Unpack (C.F (I));
      end loop;
   end Floors_At;

   function Cell_Of (M : Float) return Integer is (Integer (Float'Floor (M / Cell_M)));

   function Surface_Z (X, Y : Float) return Float is
      C : Cell;
   begin
      Reset_Cache;
      C := Cell_At (Cell_Of (X), Cell_Of (Y));
      for I in 1 .. C.N loop
         if C.F (I).Speed > 0.0 then
            return Float (C.F (I).Z) * 0.25;
         end if;
      end loop;
      return -1.0;
   end Surface_Z;

   ---------------------------------------------------------------- steps

   Wade_Now : Natural := Wade_B;   --  the deepest water stepped into, for the plan being made (Plan's Wade)

   --  A step a serf can take (what the pieces of ground are made of,
   --  whatever plan is being made).
   function Step_Free (A, B : Packed_Floor) return Boolean is
      D  : constant Integer := Integer (B.Z) - Integer (A.Z);
      Hi : constant Integer := Integer'Max (Integer (A.Z), Integer (B.Z));
   begin
      return B.Speed > 0.0 and then D in -Drop_B .. Climb_B
        and then Integer (A.Z) + Integer (A.Head) >= Hi + Head_B
        and then Integer (B.Z) + Integer (B.Head) >= Hi + Head_B;
   end Step_Free;

   --  A step of the plan being made: no deeper into water than it wades.
   function Step_Ok (A, B : Packed_Floor) return Boolean is
     (Natural (B.Water) <= Wade_Now and then Step_Free (A, B));

   --  Seconds to climb or step down from A to B, on top of the way across.
   function Rise_Time (A, B : Packed_Floor) return Float is
      D : constant Integer := Integer (B.Z) - Integer (A.Z);
   begin
      if D > 0 then
         return Float (D) * 0.25 * Climb_S;
      elsif D < 0 then
         return Float (-D) * 0.25 * Descend_S + (if -D > Climb_B then Drop_S else 0.0);
      end if;
      return 0.0;
   end Rise_Time;

   function Step_Time (A, B : Packed_Floor; Diagonal : Boolean) return Float is
     ((if Diagonal then 0.707_106_78 else 0.5) / (Walk_Speed * Float'Max (0.05, 0.5 * (A.Speed + B.Speed)))
      + Rise_Time (A, B));

   --  The corner cell (X, Y) beside a diagonal step from A to B: the step
   --  is allowed only if the way round through it could be walked too.
   function Side_Ok (X, Y : Integer; A, B : Packed_Floor) return Boolean is
      C : constant Cell := Cell_At (X, Y);
   begin
      for I in 1 .. C.N loop
         if Step_Ok (A, C.F (I)) and then Step_Ok (C.F (I), B) then
            return True;
         end if;
      end loop;
      return False;
   end Side_Ok;

   ---------------------------------------------------------------- pieces of ground

   procedure Label_Stack (P : in out Stack_Nav) is
      N_Ids  : constant := Max_Comps;
      Parent : array (0 .. N_Ids - 1) of Integer;
      Num    : array (0 .. N_Ids - 1) of Unsigned_16 := [others => 0];
      function Id (I, J, F : Integer) return Integer is ((I * Cells_Per_Stack + J) * Max_Floors + (F - 1));
      function Root (X : Integer) return Integer is
         R : Integer := X;
      begin
         while Parent (R) /= R loop
            R := Parent (R);
         end loop;
         return R;
      end Root;
      procedure Join (A, B : Integer) is
         Ra : constant Integer := Root (A);
         Rb : constant Integer := Root (B);
      begin
         if Ra /= Rb then
            Parent (Integer'Max (Ra, Rb)) := Integer'Min (Ra, Rb);
         end if;
      end Join;
      Last : constant Integer := Cells_Per_Stack - 1;
   begin
      for K in Parent'Range loop
         Parent (K) := K;
      end loop;
      for I in 0 .. Last loop
         for J in 0 .. Last loop
            declare
               C : Cell renames P.Cells (I, J);
            begin
               for F in 1 .. C.N loop
                  if C.F (F).Speed > 0.0 then
                     if I < Last then
                        declare
                           E : Cell renames P.Cells (I + 1, J);
                        begin
                           for G in 1 .. E.N loop
                              if E.F (G).Speed > 0.0
                                and then (Step_Free (C.F (F), E.F (G)) or else Step_Free (E.F (G), C.F (F)))
                              then
                                 Join (Id (I, J, F), Id (I + 1, J, G));
                              end if;
                           end loop;
                        end;
                     end if;
                     if J < Last then
                        declare
                           E : Cell renames P.Cells (I, J + 1);
                        begin
                           for G in 1 .. E.N loop
                              if E.F (G).Speed > 0.0
                                and then (Step_Free (C.F (F), E.F (G)) or else Step_Free (E.F (G), C.F (F)))
                              then
                                 Join (Id (I, J, F), Id (I, J + 1, G));
                              end if;
                           end loop;
                        end;
                     end if;
                  end if;
               end loop;
            end;
         end loop;
      end loop;
      P.N_Comp := 0;
      P.Comp := [others => [others => [others => 0]]];
      for I in 0 .. Last loop
         for J in 0 .. Last loop
            for F in 1 .. P.Cells (I, J).N loop
               if P.Cells (I, J).F (F).Speed > 0.0 then
                  declare
                     R : constant Integer := Root (Id (I, J, F));
                  begin
                     if Num (R) = 0 then
                        P.N_Comp := P.N_Comp + 1;
                        Num (R) := Unsigned_16 (P.N_Comp);
                        P.Edges (P.N_Comp) := 0;
                     end if;
                     P.Comp (I, J, F) := Num (R);
                     declare
                        E : Unsigned_8 renames P.Edges (Integer (Num (R)));
                     begin
                        if I = Last then E := E or 1; end if;
                        if I = 0 then E := E or 2; end if;
                        if J = Last then E := E or 4; end if;
                        if J = 0 then E := E or 8; end if;
                     end;
                  end;
               end if;
            end loop;
         end loop;
      end loop;
      P.East.Valid := False;
      P.North.Valid := False;
   end Label_Stack;

   --  Mapped, and mapped as the ground is now.
   function Current (SX, SY : Integer) return Boolean is
     (SX in Nav_Grid'Range (1) and then SY in Nav_Grid'Range (2) and then Navs (SX, SY) /= null
      and then Version_Src (SX, SY) > 0 and then Navs (SX, SY).Version = Version_Src (SX, SY));

   --  Stack (SX, SY)'s east or north border, worked out again if either
   --  stack has changed since (both must be current).
   procedure Fresh_Border (SX, SY : Integer; North : Boolean) is
      Here  : Stack_Nav renames Navs (SX, SY).all;
      There : Stack_Nav renames Navs ((if North then SX else SX + 1), (if North then SY + 1 else SY)).all;
      Last  : constant Integer := Cells_Per_Stack - 1;

      procedure Work_Out (B : in out Border) is
      begin
         if B.Valid and then B.My_V = Here.Shape and then B.Their_V = There.Shape then
            return;
         end if;
         B.N := 0;
         for K in 0 .. Last loop
            declare
               A_I : constant Integer := (if North then K else Last);
               A_J : constant Integer := (if North then Last else K);
               B_I : constant Integer := (if North then K else 0);
               B_J : constant Integer := (if North then 0 else K);
               CA  : Cell renames Here.Cells (A_I, A_J);
               CB  : Cell renames There.Cells (B_I, B_J);
            begin
               for F in 1 .. CA.N loop
                  for G in 1 .. CB.N loop
                     if CA.F (F).Speed > 0.0 and then CB.F (G).Speed > 0.0
                       and then (Step_Free (CA.F (F), CB.F (G)) or else Step_Free (CB.F (G), CA.F (F)))
                     then
                        declare
                           L : constant Link := (Here.Comp (A_I, A_J, F), There.Comp (B_I, B_J, G));
                           Seen : Boolean := False;
                        begin
                           for M in 1 .. B.N loop
                              Seen := Seen or else B.L (M) = L;
                           end loop;
                           if not Seen and then B.N < Max_Links then
                              B.N := B.N + 1;
                              B.L (B.N) := L;
                           end if;
                        end;
                     end if;
                  end loop;
               end loop;
            end;
         end loop;
         B.Valid := True;
         B.My_V := Here.Shape;
         B.Their_V := There.Shape;
      end Work_Out;
   begin
      if North then
         Work_Out (Here.North);
      else
         Work_Out (Here.East);
      end if;
   end Fresh_Border;

   --  A piece of ground, by its stack and number.
   function Piece_Key (SX, SY : Integer; C : Unsigned_16) return Unsigned_64 is
     (Unsigned_64 (SX * Stacks_XY + SY) * 4_096 + Unsigned_64 (C));
   function Hash_Key (K : Unsigned_64) return Ada.Containers.Hash_Type is
     (Ada.Containers.Hash_Type ((K * 16#9E37_79B9_7F4A_7C15#) / 2 ** 32 and 16#FFFF_FFFF#));
   package Piece_Sets is new Ada.Containers.Hashed_Sets
     (Element_Type => Unsigned_64, Hash => Hash_Key, Equivalent_Elements => "=");

   Max_Pieces : constant := 60_000;    --  looked over at most, from one end

   type Spread is record
      Set    : Piece_Sets.Set;
      Open   : Boolean := False;   --  reaches a stack that is loaded but not mapped as it is now
      Full   : Boolean := False;   --  gave up: too many pieces
      Met    : Boolean := False;   --  came to the other end's piece
   end record;

   --  Every piece joined to (SX, SY)'s piece C, through mapped stacks only,
   --  until Other is met.
   procedure Gather (SX, SY : Integer; C : Unsigned_16; Other : Unsigned_64; S : in out Spread) is
      type Item is record
         X, Y : Integer;
         C    : Unsigned_16;
      end record;
      type Item_Array is array (1 .. Max_Pieces) of Item;
      type Item_Access is access Item_Array;
      procedure Free_Items is new Ada.Unchecked_Deallocation (Item_Array, Item_Access);
      Q    : Item_Access := new Item_Array;
      Head : Positive := 1;
      Tail : Natural := 0;

      procedure Add (X, Y : Integer; P : Unsigned_16) is
         K : constant Unsigned_64 := Piece_Key (X, Y, P);
      begin
         if P = 0 or else S.Set.Contains (K) then
            return;
         end if;
         if K = Other then
            S.Met := True;
         end if;
         if Tail = Max_Pieces then
            S.Full := True;
            return;
         end if;
         S.Set.Insert (K);
         Tail := Tail + 1;
         Q (Tail) := (X, Y, P);
      end Add;

      --  Across border B from piece C: to the pieces it joins in (NX, NY).
      --  Backwards: B is the neighbour's border, C on its far side.
      procedure Follow (B : Border; C : Unsigned_16; Backwards : Boolean; NX, NY : Integer) is
      begin
         for M in 1 .. B.N loop
            if not Backwards and then B.L (M).Here = C then
               Add (NX, NY, B.L (M).There);
            elsif Backwards and then B.L (M).There = C then
               Add (NX, NY, B.L (M).Here);
            end if;
         end loop;
      end Follow;
   begin
      S.Set.Clear;
      S.Open := False;
      S.Full := False;
      S.Met := False;
      Add (SX, SY, C);
      while Head <= Tail and then not S.Met and then not S.Full loop
         declare
            It : constant Item := Q (Head);
            E  : constant Unsigned_8 := Navs (It.X, It.Y).Edges (Integer (It.C));
         begin
            Head := Head + 1;
            for Side in 0 .. 3 loop
               if (E and Shift_Left (Unsigned_8'(1), Side)) /= 0 then
                  declare
                     NX : constant Integer := It.X + (case Side is when 0 => 1, when 1 => -1, when others => 0);
                     NY : constant Integer := It.Y + (case Side is when 2 => 1, when 3 => -1, when others => 0);
                  begin
                     if NX in Nav_Grid'Range (1) and then NY in Nav_Grid'Range (2) and then Version_Src (NX, NY) > 0 then
                        --  (ground loaded but not mapped as it is now is mapped, or
                        --  mended, here and now: it used to leave the question open,
                        --  and an open question is a search of everything in reach)
                        if Map_On_The_Way and then not Current (NX, NY) and then Stack (NX, NY) = null then
                           null;
                        end if;
                        if not Current (NX, NY) then
                           S.Open := True;           --  ground not mapped yet: anything may lie there
                        else
                           case Side is
                              when 0 =>              --  this stack's own east or north border
                                 Fresh_Border (It.X, It.Y, North => False);
                                 Follow (Navs (It.X, It.Y).East, It.C, False, NX, NY);
                              when 2 =>
                                 Fresh_Border (It.X, It.Y, North => True);
                                 Follow (Navs (It.X, It.Y).North, It.C, False, NX, NY);
                              when 1 =>              --  the neighbour's, read backwards
                                 Fresh_Border (NX, NY, North => False);
                                 Follow (Navs (NX, NY).East, It.C, True, NX, NY);
                              when others =>
                                 Fresh_Border (NX, NY, North => True);
                                 Follow (Navs (NX, NY).North, It.C, True, NX, NY);
                           end case;
                        end if;
                     end if;
                  end;
               end if;
            end loop;
         end;
      end loop;
      Free_Items (Q);
   end Gather;

   From_Side, To_Side : Spread;

   Labels_On : Boolean := True;
   procedure Use_Labels (On : Boolean) is
   begin
      Labels_On := On;
   end Use_Labels;

   ---------------------------------------------------------------- search state

   subtype Node is Unsigned_32;

   function Make (Cx, Cy, Fi : Integer) return Node is (Node ((Cx * Cells_XY + Cy) * 4 + (Fi - 1)));
   function Cx_Of (N : Node) return Integer is (Integer (N / 4) / Cells_XY);
   function Cy_Of (N : Node) return Integer is (Integer (N / 4) mod Cells_XY);
   function Fi_Of (N : Node) return Integer is (Integer (N mod 4) + 1);

   Table_Bits : constant := 20;
   Table_Size : constant := 2 ** Table_Bits;
   type Slot is record
      Key    : Node := 0;
      Gen    : Unsigned_32 := 0;
      G      : Float := 0.0;
      Parent : Node := 0;
      Closed : Boolean := False;
   end record;
   type Slot_Array is array (0 .. Table_Size - 1) of Slot;
   type Slot_Access is access Slot_Array;
   Table   : Slot_Access;
   Gen     : Unsigned_32 := 0;
   Entries : Natural := 0;

   function Find (K : Node; Create : Boolean) return Integer is
      H : Integer := Integer (Shift_Right (K * 2_654_435_761, 32 - Table_Bits));
   begin
      loop
         if Table (H).Gen /= Gen then
            if not Create then
               return -1;
            end if;
            Table (H) := (Key => K, Gen => Gen, G => Float'Last, Parent => K, Closed => False);
            Entries := Entries + 1;
            return H;
         elsif Table (H).Key = K then
            return H;
         end if;
         H := (H + 1) mod Table_Size;
      end loop;
   end Find;

   type Heap_Item is record
      F, G : Float := 0.0;
      N    : Node := 0;
   end record;
   Heap_Max : constant := 2 ** 20;
   type Heap_Array is array (1 .. Heap_Max) of Heap_Item;
   type Heap_Access is access Heap_Array;
   Heap   : Heap_Access;
   Heap_N : Natural := 0;

   --  Lower F first; between equals, the one further along (higher G).
   function Before (A, B : Heap_Item) return Boolean is
     (A.F < B.F or else (A.F = B.F and then A.G > B.G));

   procedure Push (It : Heap_Item) is
      I : Positive;
   begin
      Heap_N := Heap_N + 1;
      I := Heap_N;
      while I > 1 and then Before (It, Heap (I / 2)) loop
         Heap (I) := Heap (I / 2);
         I := I / 2;
      end loop;
      Heap (I) := It;
   end Push;

   function Pop return Heap_Item is
      Top  : constant Heap_Item := Heap (1);
      Last_It : constant Heap_Item := Heap (Heap_N);
      I    : Positive := 1;
   begin
      Heap_N := Heap_N - 1;
      loop
         declare
            L : constant Natural := 2 * I;
            M : Natural := I;
         begin
            exit when L > Heap_N;
            M := L;
            if L + 1 <= Heap_N and then Before (Heap (L + 1), Heap (L)) then
               M := L + 1;
            end if;
            exit when not Before (Heap (M), Last_It);
            Heap (I) := Heap (M);
            I := M;
         end;
      end loop;
      if Heap_N > 0 then
         Heap (I) := Last_It;
      end if;
      return Top;
   end Pop;

   ---------------------------------------------------------------- ends

   --  The floor to start or end at: in P's own cell if one is there, else
   --  the nearest within 3 m, weighing a difference in height double.  A
   --  negative P.Z asks for the highest floor (the surface).
   procedure Nearest (P : Vec3; Cx, Cy, Fi : out Integer; Have : out Boolean) is
      X0   : constant Integer := Cell_Of (P.X);
      Y0   : constant Integer := Cell_Of (P.Y);
      Best : Float := Float'Last;
   begin
      Cx := X0;
      Cy := Y0;
      Fi := 1;
      Have := False;
      for R in 0 .. 6 loop
         for Dx in -R .. R loop
            for Dy in -R .. R loop
               if abs Dx = R or else abs Dy = R then
                  declare
                     C  : constant Cell := Cell_At (X0 + Dx, Y0 + Dy);
                     Hx : constant Float := (Float (X0 + Dx) + 0.5) * Cell_M - P.X;
                     Hy : constant Float := (Float (Y0 + Dy) + 0.5) * Cell_M - P.Y;
                     Dh : constant Float := (if R = 0 then 0.0 else Sqrt (Hx * Hx + Hy * Hy));
                  begin
                     for I in 1 .. C.N loop
                        if C.F (I).Speed > 0.0 then
                           declare
                              --  within a step up or down is the same level (on a
                              --  slope the cell's floor is its highest column)
                              Score : constant Float :=
                                (if P.Z < 0.0 then Dh + 0.001 * Float (I)
                                 else Dh + 2.0 * Float'Max (0.0, abs (Float (C.F (I).Z) * 0.25 - P.Z)
                                                                  - Float (Climb_B) * 0.25));
                           begin
                              if Score < Best then
                                 Best := Score;
                                 Cx := X0 + Dx;
                                 Cy := Y0 + Dy;
                                 Fi := I;
                                 Have := True;
                              end if;
                           end;
                        end if;
                     end loop;
                  end;
               end if;
            end loop;
         end loop;
         exit when Have and then Best <= Float (R + 1) * Cell_M;
      end loop;
   end Nearest;

   ---------------------------------------------------------------- straight lines

   --  The route being made by Plan.
   Work : Route;

   procedure Note_Stack (Cx, Cy : Integer) is
      SX : constant Integer_16 := Integer_16 (Cx / Cells_Per_Stack);
      SY : constant Integer_16 := Integer_16 (Cy / Cells_Per_Stack);
   begin
      for I in 1 .. Work.N_Stamps loop
         if Work.Stamps (I).CX = SX and then Work.Stamps (I).CY = SY then
            return;
         end if;
      end loop;
      if Work.N_Stamps = Max_Stamps then
         Work.Overflow := True;
      else
         Work.N_Stamps := Work.N_Stamps + 1;
         Work.Stamps (Work.N_Stamps) := (SX, SY, Version_Src (Integer (SX), Integer (SY)));
      end if;
   end Note_Stack;

   procedure Add_Point (P : Vec3; T, D : Float) is
   begin
      if Work.N < Max_Points then
         Work.N := Work.N + 1;
         Work.Pts (Work.N) := (P => P, T => T, D => D);
      end if;
   end Add_Point;

   --  Walk the straight line from P0 (on floor F0 of its cell) to P1 in
   --  eighths of a metre, taking in each new cell the floor a step can
   --  reach; it fails where no step can, where a diagonal step would cut a
   --  corner, or if it ends on another level than F1.  Time: seconds at
   --  Walk_Speed.  With Emit, it adds points to Work wherever the height or
   --  the going changes, and at the end (T0, D0: time and distance so far).
   procedure Line (P0 : Vec3; F0 : Packed_Floor; P1 : Vec3; F1 : Packed_Floor;
                   Ok : out Boolean; Time : out Float;
                   Emit : Boolean := False; T0, D0 : Float := 0.0)
   is
      Dx    : constant Float := P1.X - P0.X;
      Dy    : constant Float := P1.Y - P0.Y;
      L     : constant Float := Sqrt (Dx * Dx + Dy * Dy);
      Steps : constant Positive := Positive'Max (1, Integer (Float'Ceiling (L / 0.125)));
      Step  : constant Float := L / Float (Steps);
      X     : Integer := Cell_Of (P0.X);
      Y     : Integer := Cell_Of (P0.Y);
      Cur   : Packed_Floor := F0;
   begin
      Ok := False;
      Time := 0.0;
      if Emit then
         Note_Stack (X, Y);
      end if;
      for K in 1 .. Steps loop
         declare
            Qx_M : constant Float := P0.X + Dx * Float (K) / Float (Steps);
            Qy_M : constant Float := P0.Y + Dy * Float (K) / Float (Steps);
            Qx   : constant Integer := Cell_Of (Qx_M);
            Qy   : constant Integer := Cell_Of (Qy_M);
         begin
            if Qx /= X or else Qy /= Y then
               declare
                  C    : constant Cell := Cell_At (Qx, Qy);
                  Pick : Natural := 0;
               begin
                  --  floors in a cell lie at least a body's height apart, so a
                  --  step reaches one at most
                  for I in 1 .. C.N loop
                     if Step_Ok (Cur, C.F (I)) then
                        Pick := I;
                     end if;
                  end loop;
                  if Pick = 0 then
                     return;
                  end if;
                  if Qx /= X and then Qy /= Y
                    and then not (Side_Ok (X, Qy, Cur, C.F (Pick)) and then Side_Ok (Qx, Y, Cur, C.F (Pick)))
                  then
                     return;
                  end if;
                  Time := Time + Rise_Time (Cur, C.F (Pick));
                  if Emit then
                     Note_Stack (Qx, Qy);
                     --  a point where the height changes, or the pace by more
                     --  than an eighth (not for every tuft of tall grass)
                     if C.F (Pick).Z /= Cur.Z or else abs (C.F (Pick).Speed - Cur.Speed) > 0.12 * Cur.Speed then
                        Add_Point ((Qx_M, Qy_M, Float (C.F (Pick).Z) * 0.25),
                                   T0 + Time + Step / (Walk_Speed * Float'Max (0.05, C.F (Pick).Speed)),
                                   D0 + Step * Float (K));
                     end if;
                  end if;
                  Cur := C.F (Pick);
                  X := Qx;
                  Y := Qy;
               end;
            end if;
            Time := Time + Step / (Walk_Speed * Float'Max (0.05, Cur.Speed));
         end;
      end loop;
      if Cur.Z /= F1.Z or else X /= Cell_Of (P1.X) or else Y /= Cell_Of (P1.Y) then
         return;
      end if;
      if Emit then
         Add_Point ((P1.X, P1.Y, Float (F1.Z) * 0.25), T0 + Time, D0 + L);
      end if;
      Ok := True;
   end Line;

   ---------------------------------------------------------------- planning

   Max_Raw : constant := 16_384;
   type Raw_Step is record
      N : Node;
      G : Float;
   end record;
   type Raw_Array is array (1 .. Max_Raw) of Raw_Step;
   type Raw_Access is access Raw_Array;
   Raw : Raw_Access;

   type Way is record
      P : Vec3;
      F : Packed_Floor;
      T : Float;              --  time along the cells to here
   end record;
   type Way_Array is array (1 .. Max_Raw) of Way;
   type Way_Access is access Way_Array;
   Ways : Way_Access;

   function Floor_Of (N : Node) return Packed_Floor is
      C : constant Cell := Cell_At (Cx_Of (N), Cy_Of (N));
   begin
      return C.F (Fi_Of (N));
   end Floor_Of;

   function Centre (N : Node) return Vec3 is
     (((Float (Cx_Of (N)) + 0.5) * Cell_M, (Float (Cy_Of (N)) + 0.5) * Cell_M,
       Float (Floor_Of (N).Z) * 0.25));

   Dirs : constant array (1 .. 8, 1 .. 2) of Integer :=
     [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]];

   function Plan (From, To : Vec3; Budget : Positive := 300_000; Weight : Float := Heuristic_Weight;
                  Wade : Natural := Wade_B)
                  return Route is
      use Ada.Real_Time;
      Began  : constant Time := Clock;
      Sx, Sy, Sf, Gx, Gy, Gf : Integer;
      Have_S, Have_G : Boolean;
      Start, Goal, Best : Node;
      Goal_Z  : Integer := 0;
      Best_H  : Float;
      Reached : Boolean := False;
      Looked  : Natural := 0;
      N_Raw   : Natural := 0;
      Out_Of_Reach : Boolean := False;   --  the labels showed it: heading for the nearest floor instead
      CPS : constant := Cells_Per_Stack;

      function H (Cx, Cy, Z : Integer) return Float is
         Dx  : constant Float := Float (abs (Cx - Gx));
         Dy  : constant Float := Float (abs (Cy - Gy));
         Oct : constant Float := Float'Max (Dx, Dy) + 0.414_213_56 * Float'Min (Dx, Dy);
         Dz  : constant Integer := Goal_Z - Z;
      begin
         return Weight * (Oct * Cell_M / (Walk_Speed * Best_Speed)
           + (if not Have_G then 0.0
              elsif Dz > 0 then Float (Dz) * 0.25 * Climb_S else Float (-Dz) * 0.25 * Descend_S));
      end H;

      procedure Done is
      begin
         Wade_Now := Wade_B;
         Last := (Looked_At => Looked, Seconds => Float (To_Duration (Clock - Began)), Stacks => Built,
                  Out_Of_Reach => Out_Of_Reach);
         Tot.Plans := Tot.Plans + 1;
         Tot.Plan_Floors := Tot.Plan_Floors + Long_Integer (Looked);
         Tot.Plan_Seconds := Tot.Plan_Seconds + Long_Float (Last.Seconds);
         Tot.Longest_Plan := Float'Max (Tot.Longest_Plan, Last.Seconds);
         if Last.Seconds >= 0.005 then
            Tot.Slow_Plans := Tot.Slow_Plans + 1;
            Tot.Slow_Seconds := Tot.Slow_Seconds + Long_Float (Last.Seconds);
         end if;
         if Looked >= Budget then
            Tot.Spent_Plans := Tot.Spent_Plans + 1;
         end if;
         if Work.Result /= Found then
            Tot.Short_Plans := Tot.Short_Plans + 1;
         end if;
         if Out_Of_Reach then
            Tot.Unreached := Tot.Unreached + 1;
         end if;
         if Last.Seconds > Slow (Slow'Last).Seconds then
            declare
               K : Positive := Slow'Last;
               E : constant Vec3 := (if Work.N > 0 then Work.Pts (Work.N).P else From);
            begin
               while K > 1 and then Slow (K - 1).Seconds < Last.Seconds loop
                  Slow (K) := Slow (K - 1);
                  K := K - 1;
               end loop;
               Slow (K) := (From, To, Last.Seconds, Looked, Work.Result,
                            Sqrt ((E.X - To.X) ** 2 + (E.Y - To.Y) ** 2));
            end;
         end if;
      end Done;

      function Piece (Cx, Cy, Fi : Integer) return Unsigned_16 is
        (Navs (Cx / CPS, Cy / CPS).Comp (Cx mod CPS, Cy mod CPS, Fi));

      --  Whether the goal is out of reach, by the pieces of ground: true
      --  only when the start's pieces or the goal's are all known and don't
      --  meet.  Start_Known: it was the start's (From_Side) that were.
      procedure Look_Over (Start_Known : out Boolean) is
         PS : constant Unsigned_16 := Piece (Sx, Sy, Sf);
         PG : constant Unsigned_16 := Piece (Gx, Gy, Gf);
         KS : constant Unsigned_64 := Piece_Key (Sx / CPS, Sy / CPS, PS);
         KG : constant Unsigned_64 := Piece_Key (Gx / CPS, Gy / CPS, PG);
      begin
         Start_Known := False;
         if PS = 0 or else PG = 0 or else KS = KG then
            return;
         end if;
         Gather (Sx / CPS, Sy / CPS, PS, KG, From_Side);
         if From_Side.Met then
            return;
         end if;
         if not From_Side.Open and then not From_Side.Full then
            Out_Of_Reach := True;
            Start_Known := True;
            return;
         end if;
         Gather (Gx / CPS, Gy / CPS, PG, KS, To_Side);
         if not To_Side.Met and then not To_Side.Open and then not To_Side.Full then
            Out_Of_Reach := True;
         end if;
      end Look_Over;

      --  Out of reach: the floor nearest the goal (by the estimate, as a
      --  search that went everywhere would have ended) among those in the
      --  start's pieces, or, when only the goal's are known, outside them.
      --  Mapped stacks only, ring by ring round the goal's.
      procedure Nearest_Reachable (Start_Known : Boolean; Tx, Ty, Tf : out Integer; Got : out Boolean) is
         GSX : constant Integer := Gx / CPS;
         GSY : constant Integer := Gy / CPS;
         Best_S : Float := Float'Last;
         Stacks_In : Piece_Sets.Set;
      begin
         Tx := 0;
         Ty := 0;
         Tf := 1;
         Got := False;
         if Start_Known then
            for K of From_Side.Set loop
               Stacks_In.Include (K / 4_096);
            end loop;
         end if;
         for R in 0 .. 64 loop
            exit when Got and then Weight * Float (R - 1) * Float (CPS) * Cell_M / (Walk_Speed * Best_Speed) > Best_S;
            for DX in -R .. R loop
               for DY in -R .. R loop
                  if (abs DX = R or else abs DY = R) and then Current (GSX + DX, GSY + DY)
                    and then (not Start_Known
                              or else Stacks_In.Contains (Unsigned_64 ((GSX + DX) * Stacks_XY + (GSY + DY))))
                  then
                     declare
                        P : Stack_Nav renames Navs (GSX + DX, GSY + DY).all;
                     begin
                        for I in 0 .. CPS - 1 loop
                           for J in 0 .. CPS - 1 loop
                              for F in 1 .. P.Cells (I, J).N loop
                                 if P.Comp (I, J, F) /= 0 then
                                    declare
                                       K  : constant Unsigned_64 := Piece_Key (GSX + DX, GSY + DY, P.Comp (I, J, F));
                                       Ok : constant Boolean :=
                                         (if Start_Known then From_Side.Set.Contains (K)
                                          else not To_Side.Set.Contains (K));
                                       Cx : constant Integer := (GSX + DX) * CPS + I;
                                       Cy : constant Integer := (GSY + DY) * CPS + J;
                                       Sc : constant Float := (if Ok then H (Cx, Cy, Integer (P.Cells (I, J).F (F).Z))
                                                               else Float'Last);
                                    begin
                                       if Sc < Best_S then
                                          Best_S := Sc;
                                          Tx := Cx;
                                          Ty := Cy;
                                          Tf := F;
                                          Got := True;
                                       end if;
                                    end;
                                 end if;
                              end loop;
                           end loop;
                        end loop;
                     end;
                  end if;
               end loop;
            end loop;
         end loop;
      end Nearest_Reachable;
   begin
      Reset_Cache;
      Built := 0;
      Work.Result := None;
      Work.N := 0;
      Work.N_Stamps := 0;
      Work.Overflow := False;
      Wade_Now := Natural'Min (Wade, Wade_B);
      if Version_Src = null then
         Done;
         return Work;
      end if;
      if Table = null then
         Table := new Slot_Array;
         Heap := new Heap_Array;
         Raw := new Raw_Array;
         Ways := new Way_Array;
      end if;

      Nearest (From, Sx, Sy, Sf, Have_S);
      Nearest (To, Gx, Gy, Gf, Have_G);
      if not Have_S then
         Done;
         return Work;
      end if;
      Start := Make (Sx, Sy, Sf);
      if Have_G then
         Goal := Make (Gx, Gy, Gf);
         Goal_Z := Integer (Cell_At (Gx, Gy).F (Gf).Z);
      else
         Gx := Cell_Of (To.X);              --  nowhere to stand there: head
         Gy := Cell_Of (To.Y);              --  for it, end where nearest
         Goal := Node'Last;
      end if;

      --  a goal the pieces of ground show to be out of reach: head for the
      --  floor nearest it that can be reached instead of searching everywhere
      if Labels_On and then Have_G and then Start /= Goal
        and then Current (Sx / CPS, Sy / CPS) and then Current (Gx / CPS, Gy / CPS)
      then
         declare
            Start_Known, Got : Boolean;
            Tx, Ty, Tf : Integer;
         begin
            Look_Over (Start_Known);
            if Out_Of_Reach then
               Nearest_Reachable (Start_Known, Tx, Ty, Tf, Got);
               if not Got or else Make (Tx, Ty, Tf) = Start then
                  Done;
                  return Work;
               end if;
               Gx := Tx;
               Gy := Ty;
               Gf := Tf;
               Goal := Make (Gx, Gy, Gf);
               Goal_Z := Integer (Cell_At (Gx, Gy).F (Gf).Z);
            end if;
         end;
      end if;

      Gen := Gen + 1;
      Entries := 0;
      Heap_N := 0;
      declare
         S : constant Integer := Find (Start, True);
      begin
         Table (S).G := 0.0;
         Best := Start;
         Best_H := H (Sx, Sy, Integer (Cell_At (Sx, Sy).F (Sf).Z));
         Push ((F => Best_H, G => 0.0, N => Start));
      end;

      Search :
      while Heap_N > 0 loop
         declare
            It : constant Heap_Item := Pop;
            S  : constant Integer := Find (It.N, False);
         begin
            if not Table (S).Closed and then It.G <= Table (S).G then
               Table (S).Closed := True;
               Looked := Looked + 1;
               if It.N = Goal then
                  Reached := True;
                  Best := Goal;
                  exit Search;
               end if;
               if It.F - It.G < Best_H then
                  Best_H := It.F - It.G;
                  Best := It.N;
               end if;
               exit Search when Looked >= Budget or else Entries > Table_Size * 7 / 10
                 or else Heap_N > Heap_Max - 64;
               declare
                  Cx : constant Integer := Cx_Of (It.N);
                  Cy : constant Integer := Cy_Of (It.N);
                  A  : constant Packed_Floor := Cell_At (Cx, Cy).F (Fi_Of (It.N));
               begin
                  for D in Dirs'Range (1) loop
                     declare
                        Nx   : constant Integer := Cx + Dirs (D, 1);
                        Ny   : constant Integer := Cy + Dirs (D, 2);
                        Diag : constant Boolean := D > 4;
                        C    : constant Cell := Cell_At (Nx, Ny);
                     begin
                        for I in 1 .. C.N loop
                           if Step_Ok (A, C.F (I))
                             and then (not Diag
                                       or else (Side_Ok (Nx, Cy, A, C.F (I)) and then Side_Ok (Cx, Ny, A, C.F (I))))
                           then
                              declare
                                 K  : constant Node := Make (Nx, Ny, I);
                                 Ng : constant Float := It.G + Step_Time (A, C.F (I), Diag);
                                 T  : constant Integer := Find (K, True);
                              begin
                                 if not Table (T).Closed and then Ng < Table (T).G then
                                    Table (T).G := Ng;
                                    Table (T).Parent := It.N;
                                    Push ((F => Ng + H (Nx, Ny, Integer (C.F (I).Z)), G => Ng, N => K));
                                 end if;
                              end;
                           end if;
                        end loop;
                     end;
                  end loop;
               end;
            end if;
         end;
      end loop Search;

      if Best = Start and then not Reached then
         Done;
         return Work;
      end if;

      --  the cells, start to end
      declare
         K : Node := Best;
      begin
         loop
            declare
               S : constant Integer := Find (K, False);
            begin
               if N_Raw = Max_Raw then
                  Done;
                  return Work;
               end if;
               N_Raw := N_Raw + 1;
               Raw (N_Raw) := (N => K, G => Table (S).G);
               exit when K = Start;
               K := Table (S).Parent;
            end;
         end loop;
         for I in 1 .. N_Raw / 2 loop
            declare
               T : constant Raw_Step := Raw (I);
            begin
               Raw (I) := Raw (N_Raw + 1 - I);
               Raw (N_Raw + 1 - I) := T;
            end;
         end loop;
      end;

      --  Pulled straight, in two passes: from each point the furthest of the
      --  next 48 cells that a straight line reaches no slower than the cells
      --  did; then the same over those points (up to 64 m), so that a long
      --  straight run is one line.  Then the lines are walked again to put
      --  down the route's points.
      declare
         End_P : constant Vec3 :=
           (if Reached and then not Out_Of_Reach and then Cell_Of (To.X) = Cx_Of (Best)
              and then Cell_Of (To.Y) = Cy_Of (Best)
            then (To.X, To.Y, 0.0) else Centre (Best));
         Start_P : Vec3 := (From.X, From.Y, 0.0);
         NW    : Positive := 1;
         Cur_I : Positive := 1;
         Ok    : Boolean;
         Tm    : Float;
      begin
         if Cell_Of (From.X) /= Cx_Of (Raw (1).N) or else Cell_Of (From.Y) /= Cy_Of (Raw (1).N) then
            Start_P := Centre (Raw (1).N);       --  started from a cell nearby
         end if;
         Ways (1) := (P => Start_P, F => Floor_Of (Raw (1).N), T => 0.0);
         while Cur_I < N_Raw loop
            declare
               Pick  : Positive := Cur_I + 1;
               Fails : Natural := 0;
            begin
               for J in Cur_I + 2 .. Integer'Min (N_Raw, Cur_I + 48) loop
                  declare
                     Pj : constant Vec3 := (if J = N_Raw then End_P else Centre (Raw (J).N));
                  begin
                     Line (Ways (NW).P, Ways (NW).F, Pj, Floor_Of (Raw (J).N), Ok, Tm);
                     if Ok and then Tm <= (Raw (J).G - Raw (Cur_I).G) * 1.02 + 0.01 then
                        Pick := J;
                        Fails := 0;
                     else
                        Fails := Fails + 1;
                        exit when Fails = 8;
                     end if;
                  end;
               end loop;
               NW := NW + 1;
               Ways (NW) := (P => (if Pick = N_Raw then End_P else Centre (Raw (Pick).N)),
                             F => Floor_Of (Raw (Pick).N), T => Raw (Pick).G);
               Cur_I := Pick;
            end;
         end loop;

         declare
            I : Positive := 1;
            T_Acc, D_Acc : Float := 0.0;
         begin
            Work.Result := (if Reached and then not Out_Of_Reach then Found else Partial);
            Add_Point ((Start_P.X, Start_P.Y, Float (Ways (1).F.Z) * 0.25), 0.0, 0.0);
            Note_Stack (Cx_Of (Raw (1).N), Cy_Of (Raw (1).N));
            while I < NW loop
               declare
                  Pick : Positive := I + 1;
               begin
                  for J in I + 2 .. Integer'Min (NW, I + 8) loop
                     exit when abs (Ways (J).P.X - Ways (I).P.X) + abs (Ways (J).P.Y - Ways (I).P.Y) > 90.0;
                     Line (Ways (I).P, Ways (I).F, Ways (J).P, Ways (J).F, Ok, Tm);
                     if Ok and then Tm <= (Ways (J).T - Ways (I).T) * 1.02 + 0.01 then
                        Pick := J;
                     end if;
                  end loop;
                  declare
                     Dx : constant Float := Ways (Pick).P.X - Ways (I).P.X;
                     Dy : constant Float := Ways (Pick).P.Y - Ways (I).P.Y;
                  begin
                     Line (Ways (I).P, Ways (I).F, Ways (Pick).P, Ways (Pick).F, Ok, Tm,
                           Emit => True, T0 => T_Acc, D0 => D_Acc);
                     if not Ok then
                        Work.Result := Partial;   --  cannot happen for a line checked above; stop there
                        exit;
                     end if;
                     T_Acc := T_Acc + Tm;
                     D_Acc := D_Acc + Sqrt (Dx * Dx + Dy * Dy);
                  end;
                  I := Pick;
                  if Work.N = Max_Points then
                     Work.Result := Partial;
                     exit;
                  end if;
               end;
            end loop;
         end;
      end;
      for I in 1 .. N_Raw loop
         Note_Stack (Cx_Of (Raw (I).N), Cy_Of (Raw (I).N));
      end loop;
      Done;
      return Work;
   end Plan;

   ---------------------------------------------------------------- after edits

   function Changed (R : Route) return Boolean is
   begin
      if Version_Src = null then
         return True;
      end if;
      if R.Overflow then
         return True;
      end if;
      for I in 1 .. R.N_Stamps loop
         if Version_Src (Integer (R.Stamps (I).CX), Integer (R.Stamps (I).CY)) /= R.Stamps (I).Version then
            return True;
         end if;
      end loop;
      return False;
   end Changed;

   --  The floor of P's cell at P's height, if there is one.
   procedure Floor_At_Height (P : Vec3; F : out Packed_Floor; Have : out Boolean) is
      C : constant Cell := Cell_At (Cell_Of (P.X), Cell_Of (P.Y));
      Z : constant Integer := Integer (Float'Rounding (P.Z * 4.0));
   begin
      Have := False;
      F := (others => <>);
      for I in 1 .. C.N loop
         if Integer (C.F (I).Z) = Z and then C.F (I).Speed > 0.0 then
            F := C.F (I);
            Have := True;
            return;
         end if;
      end loop;
   end Floor_At_Height;

   function Still_Good (R : Route; From_Point : Positive) return Boolean is
   begin
      Reset_Cache;
      Tot.Rewalks := Tot.Rewalks + 1;
      Tot.Rewalk_Steps := Tot.Rewalk_Steps + Long_Integer (Integer'Max (0, R.N - From_Point));
      for K in From_Point .. R.N - 1 loop
         declare
            F0, F1 : Packed_Floor;
            H0, H1, Ok : Boolean;
            Tm : Float;
         begin
            Floor_At_Height (R.Pts (K).P, F0, H0);
            Floor_At_Height (R.Pts (K + 1).P, F1, H1);
            if not (H0 and then H1) then
               return False;
            end if;
            Line (R.Pts (K).P, F0, R.Pts (K + 1).P, F1, Ok, Tm);
            if not Ok then
               return False;
            end if;
         end;
      end loop;
      return True;
   end Still_Good;

   procedure Restamp (R : in out Route) is
   begin
      for I in 1 .. R.N_Stamps loop
         R.Stamps (I).Version := Version_Src (Integer (R.Stamps (I).CX), Integer (R.Stamps (I).CY));
      end loop;
   end Restamp;

   function Last_Stats return Stats is (Last);

   function Totals return Totals_Rec is (Tot);
   function Slowest return Slow_List is (Slow);

   procedure Reset_Totals is
   begin
      Tot := (others => <>);
   end Reset_Totals;

end Castle.Nav;
