with Ada.Text_IO;                       use Ada.Text_IO;
with Ada.Unchecked_Deallocation;
with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Interfaces;                        use Interfaces;
with Castle.Fields;                     use Castle.Fields;
with Castle.Hash;                       use Castle.Hash;
with Castle.Noise;                      use Castle.Noise;
with Castle.Maps;                       use Castle.Maps;
with Castle.Text;                       use Castle.Text;
with Castle.Channels;
with Castle.Jobs;

package body Castle.Hydrology is

   DX : constant array (0 .. 7) of Integer := (1, 1, 0, -1, -1, -1, 0, 1);
   DY : constant array (0 .. 7) of Integer := (0, 1, 1, 1, 0, -1, -1, -1);
   DL : constant array (0 .. 7) of Float :=
     (1.0, 1.414_21, 1.0, 1.414_21, 1.0, 1.414_21, 1.0, 1.414_21);

   type Flag_Field is array (Cell_Range) of Boolean with Component_Size => 8;
   type Flag_Access is access Flag_Field;

   type Count_Field is array (Cell_Range) of Unsigned_8;
   type Count_Access is access Count_Field;

   type Cell_List is array (Cell_Range) of Cell_Range;
   type Cell_List_Access is access Cell_List;

   type Heap_Item is record
      Key  : Float;
      Cell : Cell_Range;
   end record;
   type Heap_Array is array (Positive range 1 .. N * N) of Heap_Item;
   type Heap_Access is access Heap_Array;

   procedure Free is new Ada.Unchecked_Deallocation (Castle.Fields.Field, Field_Access);
   procedure Free is new Ada.Unchecked_Deallocation (Dir_Field, Dir_Access);
   procedure Free is new Ada.Unchecked_Deallocation (Flag_Field, Flag_Access);
   procedure Free is new Ada.Unchecked_Deallocation (Count_Field, Count_Access);
   procedure Free is new Ada.Unchecked_Deallocation (Cell_List, Cell_List_Access);
   procedure Free is new Ada.Unchecked_Deallocation (Heap_Array, Heap_Access);

   procedure Push (H : in out Heap_Array; Size : in out Natural; Item : Heap_Item) is
      I : Positive;
   begin
      Size := Size + 1;
      I    := Size;
      while I > 1 and then H (I / 2).Key > Item.Key loop
         H (I) := H (I / 2);
         I     := I / 2;
      end loop;
      H (I) := Item;
   end Push;

   procedure Pop (H : in out Heap_Array; Size : in out Natural; Item : out Heap_Item) is
      Last  : constant Heap_Item := H (Size);
      I     : Positive := 1;
      Child : Positive;
   begin
      Item := H (1);
      Size := Size - 1;
      if Size = 0 then
         return;
      end if;
      loop
         Child := 2 * I;
         exit when Child > Size;
         if Child < Size and then H (Child + 1).Key < H (Child).Key then
            Child := Child + 1;
         end if;
         exit when H (Child).Key >= Last.Key;
         H (I) := H (Child);
         I     := Child;
      end loop;
      H (I) := Last;
   end Pop;

   function In_Map (X, Y : Integer) return Boolean is
     (X >= 0 and then X < N and then Y >= 0 and then Y < N);

   --  Two-pass chamfer distance.  Dist holds 0.0 at sources, a large value
   --  elsewhere.
   procedure Chamfer (Dist : in out Castle.Fields.Field) is
      procedure Relax (C : Cell_Range; X, Y : Integer; Cost : Float) is
      begin
         if In_Map (X, Y) and then Dist (Idx (X, Y)) + Cost < Dist (C) then
            Dist (C) := Dist (Idx (X, Y)) + Cost;
         end if;
      end Relax;
   begin
      for Y in 0 .. N - 1 loop
         for X in 0 .. N - 1 loop
            Relax (Idx (X, Y), X - 1, Y,     1.0);
            Relax (Idx (X, Y), X - 1, Y - 1, 1.414_21);
            Relax (Idx (X, Y), X,     Y - 1, 1.0);
            Relax (Idx (X, Y), X + 1, Y - 1, 1.414_21);
         end loop;
      end loop;
      for Y in reverse 0 .. N - 1 loop
         for X in reverse 0 .. N - 1 loop
            Relax (Idx (X, Y), X + 1, Y,     1.0);
            Relax (Idx (X, Y), X + 1, Y + 1, 1.414_21);
            Relax (Idx (X, Y), X,     Y + 1, 1.0);
            Relax (Idx (X, Y), X - 1, Y + 1, 1.414_21);
         end loop;
      end loop;
   end Chamfer;

   procedure Generate (W : in out World; Report : Boolean := True) is
      H      : Castle.Fields.Field renames W.Height.all;
      Filled : Field_Access     := New_Field;
      Closed : Flag_Access      := new Flag_Field;
      Parent : Dir_Access       := new Dir_Field;
      Down   : Dir_Access renames W.Down;
      Queue  : Cell_List_Access := new Cell_List;
      Heap   : Heap_Access      := new Heap_Array;
      Wet    : Flag_Access      := new Flag_Field;   --  silted basins
      Orig   : Field_Access;
      Heap_N : Natural := 0;
      Q_Head : Natural := 0;
      Q_Tail : Natural := 0;
      Kept   : Natural := 0;
      Silted : Natural := 0;
      Joined : Natural := 0;          --  lake outflows made channel down to the first stream
      Heads  : Natural := 0;          --  channel network: heads, length (m), river length, widest
      Ch_Len, Riv_Len, Widest : Float := 0.0;
      Max_Q, Deepest : Float := 0.0;  --  largest discharge; deepest cut below the old ground
      Deepest_At     : Natural := 0;
      Silt_A : Natural := 0;

      procedure Seed_Edge (K : Cell_Range) is
      begin
         if not Closed (K) then
            Closed (K) := True;
            Filled (K) := H (K);
            Push (Heap.all, Heap_N, (H (K), K));
         end if;
      end Seed_Edge;

      function Target (C : Cell_Range) return Cell_Range is
        (Idx (C mod N + DX (Integer (Down (C))), C / N + DY (Integer (Down (C)))));

   begin
      --------------------------------------------------------------------
      --  1. Priority-Flood + FIFO.  Map edges are the outlets.
      --------------------------------------------------------------------
      for K in Cell_Range loop
         Closed (K) := False;
         Parent (K) := -1;
      end loop;
      for X in 0 .. N - 1 loop
         Seed_Edge (Idx (X, 0));
         Seed_Edge (Idx (X, N - 1));
      end loop;
      for Y in 1 .. N - 2 loop
         Seed_Edge (Idx (0, Y));
         Seed_Edge (Idx (N - 1, Y));
      end loop;

      loop
         declare
            C    : Cell_Range;
            Item : Heap_Item;
         begin
            if Q_Head < Q_Tail then
               C      := Queue (Q_Head);
               Q_Head := Q_Head + 1;
            elsif Heap_N > 0 then
               Pop (Heap.all, Heap_N, Item);
               C := Item.Cell;
            else
               exit;
            end if;

            declare
               Level : constant Float   := Filled (C);
               Cx    : constant Integer := C mod N;
               Cy    : constant Integer := C / N;
            begin
               for D in 0 .. 7 loop
                  if In_Map (Cx + DX (D), Cy + DY (D)) then
                     declare
                        K : constant Cell_Range := Idx (Cx + DX (D), Cy + DY (D));
                     begin
                        if not Closed (K) then
                           Closed (K) := True;
                           Parent (K) := Flow_Dir ((D + 4) mod 8);
                           if H (K) <= Level then
                              Filled (K)     := Level;       --  inside a depression
                              Queue (Q_Tail) := K;
                              Q_Tail         := Q_Tail + 1;
                           else
                              Filled (K) := H (K);
                              Push (Heap.all, Heap_N, (H (K), K));
                           end if;
                        end if;
                     end;
                  end if;
               end loop;
            end;
         end;
      end loop;
      Free (Heap);

      --------------------------------------------------------------------
      --  2. Drainage: steepest descent on the filled surface, otherwise
      --     follow the flood tree (lake beds and flats).
      --------------------------------------------------------------------
      for C in Cell_Range loop
         declare
            Cx   : constant Integer := C mod N;
            Cy   : constant Integer := C / N;
            Best : Flow_Dir := -1;
            Drop : Float    := 0.0;
         begin
            for D in 0 .. 7 loop
               if In_Map (Cx + DX (D), Cy + DY (D)) then
                  declare
                     S : constant Float :=
                       (Filled (C) - Filled (Idx (Cx + DX (D), Cy + DY (D)))) / DL (D);
                  begin
                     if S > Drop then
                        Drop := S;
                        Best := Flow_Dir (D);
                     end if;
                  end;
               end if;
            end loop;
            Down (C) := (if Best = -1 then Parent (C) else Best);
         end;
      end loop;
      Free (Parent);

      --------------------------------------------------------------------
      --  3. Flow accumulation (Kahn's topological order).
      --------------------------------------------------------------------
      declare
         In_Deg : Count_Access := new Count_Field;
      begin
         for C in Cell_Range loop
            In_Deg (C) := 0;
         end loop;
         for C in Cell_Range loop
            if Down (C) >= 0 then
               In_Deg (Target (C)) := In_Deg (Target (C)) + 1;
            end if;
         end loop;
         Q_Head := 0;
         Q_Tail := 0;
         for C in Cell_Range loop
            W.Flow (C) := 1.0;
            if In_Deg (C) = 0 then
               Queue (Q_Tail) := C;
               Q_Tail         := Q_Tail + 1;
            end if;
         end loop;
         while Q_Head < Q_Tail loop
            declare
               C : constant Cell_Range := Queue (Q_Head);
            begin
               Q_Head := Q_Head + 1;
               if Down (C) >= 0 then
                  declare
                     T : constant Cell_Range := Target (C);
                  begin
                     W.Flow (T) := W.Flow (T) + W.Flow (C);
                     In_Deg (T) := In_Deg (T) - 1;
                     if In_Deg (T) = 0 then
                        Queue (Q_Tail) := T;
                        Q_Tail         := Q_Tail + 1;
                     end if;
                  end;
               end if;
            end;
         end loop;
         if Q_Tail /= N * N then
            raise Program_Error with "drainage graph is not acyclic";
         end if;
         Free (In_Deg);
      end;

      --------------------------------------------------------------------
      --  4. Lakes.  A depression at least Lake_Min_Depth deep and
      --     Lake_Min_Area wide holds water at its spill level, and so does a
      --     small one at least Tarn_Min_Depth deep and Tarn_Min_Area wide: a
      --     tarn.  The rest silt up: the ground rises to the spill level,
      --     flat ground, no pond.  (A hollow 11 m deep and 2,400 m^2 wide in
      --     the mountains of seed 1 used to silt up to its brim for want of
      --     area: a dry lake bed of bare rock with a stream running out.)
      --------------------------------------------------------------------
      for C in Cell_Range loop
         W.Water (C) := 0.0;
         W.Kind (C)  := Dry;
         Closed (C)  := False;
         Wet (C)     := False;
      end loop;
      for C in Cell_Range loop
         if not Closed (C) and then Filled (C) - H (C) > 0.02 then
            Q_Head     := 0;
            Q_Tail     := 1;
            Queue (0)  := C;
            Closed (C) := True;
            declare
               Max_D : Float := 0.0;
            begin
               while Q_Head < Q_Tail loop
                  declare
                     K  : constant Cell_Range := Queue (Q_Head);
                     Kx : constant Integer    := K mod N;
                     Ky : constant Integer    := K / N;
                  begin
                     Q_Head := Q_Head + 1;
                     Max_D  := Float'Max (Max_D, Filled (K) - H (K));
                     for D in 0 .. 3 loop
                        declare
                           Nx : constant Integer := Kx + DX (2 * D);
                           Ny : constant Integer := Ky + DY (2 * D);
                        begin
                           if In_Map (Nx, Ny) then
                              declare
                                 Kn : constant Cell_Range := Idx (Nx, Ny);
                              begin
                                 if not Closed (Kn) and then Filled (Kn) - H (Kn) > 0.02 then
                                    Closed (Kn)    := True;
                                    Queue (Q_Tail) := Kn;
                                    Q_Tail         := Q_Tail + 1;
                                 end if;
                              end;
                           end if;
                        end;
                     end loop;
                  end;
               end loop;
               if (Q_Tail >= Lake_Min_Area and then Max_D >= Lake_Min_Depth)
                 or else (Q_Tail >= Tarn_Min_Area and then Max_D >= Tarn_Min_Depth)
               then
                  Kept := Kept + 1;
                  for I in 0 .. Q_Tail - 1 loop
                     W.Water (Queue (I)) := Filled (Queue (I));
                     W.Kind (Queue (I))  := Lake;
                  end loop;
               else
                  Silted := Silted + 1;
                  Silt_A := Silt_A + Q_Tail;
                  for I in 0 .. Q_Tail - 1 loop
                     H (Queue (I))   := Filled (Queue (I));
                     Wet (Queue (I)) := True;
                  end loop;
               end if;
            end;
         end if;
      end loop;
      Free (Filled);

      --------------------------------------------------------------------
      --  5. Channels with a meander pass.  Width ~ sqrt(catchment).  Each
      --     brush centre is displaced by one smooth 2-D warp field: channels
      --     curve, and a cell shared by a tributary and its river moves to
      --     the same place for both, so junctions stay joined.  The warp
      --     fades near lakes, the map edge and on steep ground.  Bed and
      --     water level come from the lower of the source cell and the
      --     displaced spot, so water never stands above the ground it is in.
      --------------------------------------------------------------------
      Orig := New_Field;
      for C in Cell_Range loop
         Orig (C) := H (C);
      end loop;

      declare
         Dist_L : Field_Access := New_Field;
         S_M    : constant U64 := W.Ch (Castle.Channels.Meander);

         --  A cell inside a channel (within its half-width plus 0.75 m)
         --  takes bed and water from the one channel centre nearest to it,
         --  so on a slope every cell keeps its own level.  (Taking the
         --  highest water of every brush in reach let brushes high on a
         --  slope flood the cells below them, which stacked water in sheets
         --  down mountainsides.)  A bank cell outside every channel is cut to
         --  the lowest of the bank slopes around it, which rise at least as
         --  steeply as the ground, and holds water only where the nearest
         --  channel's surface reaches it.
         Cov_D  : Field_Access := New_Field (1.0E9);   --  distance to the nearest covering centre
         Cov_B  : Field_Access := New_Field;           --  its bed
         Cov_S  : Field_Access := New_Field;           --  its water surface
         Cov_F  : Field_Access := New_Field;           --  its catchment
         Bank_H : Field_Access := New_Field (1.0E9);   --  lowest bank slope over the cell
         Near_D : Field_Access := New_Field (1.0E9);   --  distance past the nearest channel edge
         Near_S : Field_Access := New_Field;
         Near_F : Field_Access := New_Field;

         --  The main upstream neighbour of every channel cell, for smoothing
         --  the centreline: D8 paths step in 45-degree stairs, which gave
         --  river banks a saw-tooth edge.
         type Up_Field is array (Cell_Range) of Integer;
         type Up_Access is access Up_Field;
         procedure Free_Up is new Ada.Unchecked_Deallocation (Up_Field, Up_Access);
         Up : Up_Access := new Up_Field'(others => -1);

         --  A channel carries a discharge: Runoff per m^2 of catchment.  Its
         --  width grows with the square root of that; its depth is the depth
         --  the flow runs at on its slope (Manning, n = Roughness: a rough bed,
         --  so rivers run slower and deeper than a smooth one would carry them).
         function Width_Q (Q : Float) return Float is (Clamp (5.0 * Sqrt (Q), 1.5, 24.0));

         --  Bisection on (K A)^3 R^2 = Q^3 with K = sqrt (S) / n: Manning's
         --  formula cubed, so only + - * / and Sqrt (all exactly rounded)
         --  are used and the world comes out the same on every machine.
         function Normal_Depth (Q, B, S : Float) return Float is
            K  : constant Float := Sqrt (S) / Roughness;
            Lo : Float := 0.01;
            Hi : Float := 8.0;
         begin
            for I in 1 .. 40 loop
               declare
                  D  : constant Float := 0.5 * (Lo + Hi);
                  KA : constant Float := K * B * D;
                  R  : constant Float := B * D / (B + 2.0 * D);
               begin
                  if KA * KA * KA * R * R < Q * Q * Q then
                     Lo := D;
                  else
                     Hi := D;
                  end if;
               end;
            end loop;
            return 0.5 * (Lo + Hi);
         end Normal_Depth;


         --  The network: every cell whose catchment reaches Feed_Area, and
         --  the main stem above each stream's start up to Head_Area, so the
         --  feeds are fewer but run further up the hills.
         Kept    : Flag_Access  := new Flag_Field'(others => False);
         Main_Up : Up_Access    := new Up_Field'(others => -1);   --  largest upstream neighbour of every cell
         --  Along every channel cell: water surface, bed, width.
         Ch_Top  : Field_Access := New_Field;
         Ch_Bed  : Field_Access := New_Field;
         Ch_W    : Field_Access := New_Field;

         --  Lakes feed the streams that start near them: the path water
         --  takes out of a lake is channel all the way down to the first
         --  stream, if that is within Connect_Range_M.  (A small pond's
         --  outflow carries too little catchment to be a channel, so its
         --  stream used to start metres to tens of metres downhill, with dry
         --  ground between.  A stream head below a lake's level close by is
         --  in practice always on that path: in eight seeds no other kind
         --  turned up.)
         Outflow  : Flag_Access  := new Flag_Field'(others => False);

         function Is_Channel (C : Cell_Range) return Boolean is
           ((Kept (C) or else Outflow (C)) and then W.Kind (C) /= Lake);

         function Down_Of (C : Cell_Range) return Cell_Range is
           (if Down (C) < 0 then C else Target (C));

         function Up_Of (C : Cell_Range) return Cell_Range is
           (if Up (C) < 0 then C else Cell_Range (Up (C)));

         function Gradient (C : Cell_Range) return Float is
            X  : constant Integer := C mod N;
            Y  : constant Integer := C / N;
            Gx : constant Float := (At_Cell (Orig.all, X + 2, Y) - At_Cell (Orig.all, X - 2, Y)) * 0.25;
            Gy : constant Float := (At_Cell (Orig.all, X, Y + 2) - At_Cell (Orig.all, X, Y - 2)) * 0.25;
         begin
            return Sqrt (Gx * Gx + Gy * Gy);
         end Gradient;

         procedure Offset (C : Cell_Range; Ox, Oy : out Float) is
            X    : constant Integer := C mod N;
            Y    : constant Integer := C / N;
            Px   : constant Float   := Float (X) + 0.5;
            Py   : constant Float   := Float (Y) + 0.5;
            Edge : constant Float   :=
              Float (Integer'Min (Integer'Min (X, Y), Integer'Min (N - 1 - X, N - 1 - Y)));
            Amp  : constant Float   :=
              Meander_Amp
              * Smoothstep (0.0, 25.0, Dist_L (C))
              * Smoothstep (0.0, 40.0, Edge)
              * (1.0 - Smoothstep (0.05, 0.25, Gradient (C)));
         begin
            Ox := 2.0 * Amp * FBM_2 (S_M, Px / Meander_Len, Py / Meander_Len, 2);
            Oy := 2.0 * Amp * FBM_2 (S_M + 1, Px / Meander_Len, Py / Meander_Len, 2);
         end Offset;

         --  Centre of the brush for channel cell C: a 1-4-6-4-1 average of
         --  the cell and its neighbours two steps up and down the channel,
         --  then the meander offset.
         procedure Centre (C : Cell_Range; Fx, Fy : out Float) is
            U1 : constant Cell_Range := Up_Of (C);
            U2 : constant Cell_Range := Up_Of (U1);
            D1 : constant Cell_Range := Down_Of (C);
            D2 : constant Cell_Range := Down_Of (D1);
            function Px (K : Cell_Range) return Float is (Float (K mod N) + 0.5);
            function Py (K : Cell_Range) return Float is (Float (K / N) + 0.5);
            Ox, Oy : Float;
         begin
            Offset (C, Ox, Oy);
            Fx := (Px (U2) + 4.0 * Px (U1) + 6.0 * Px (C) + 4.0 * Px (D1) + Px (D2)) / 16.0 + Ox;
            Fy := (Py (U2) + 4.0 * Py (U1) + 6.0 * Py (C) + 4.0 * Py (D1) + Py (D2)) / 16.0 + Oy;
         end Centre;

         procedure Stamp (C : Cell_Range) is
            Slope  : constant Float := Gradient (C);
            Wd     : constant Float := Ch_W (C);
            Dp     : constant Float := Ch_Top (C) - Ch_Bed (C);
            R      : constant Float := Wd * 0.5;
            Bank_K : constant Float := Float'Max (0.8, 1.25 * Slope);
            Reach  : constant Float := R + 1.75 + (Dp + Freeboard_M) / Bank_K;
            Fx, Fy : Float;
         begin
            Centre (C, Fx, Fy);
            declare
               Bed : constant Float := Ch_Bed (C);
               Top : constant Float := Ch_Top (C);
            begin
               for Y in Floor_I (Fy - Reach) .. Floor_I (Fy + Reach) loop
                  for X in Floor_I (Fx - Reach) .. Floor_I (Fx + Reach) loop
                     if In_Map (X, Y) then
                        declare
                           K : constant Cell_Range := Idx (X, Y);
                           D : constant Float :=
                             Sqrt ((Float (X) + 0.5 - Fx) ** 2 + (Float (Y) + 0.5 - Fy) ** 2);
                        begin
                           if D <= Reach then
                              if D <= R + 0.75 then
                                 if D < Cov_D (K) then
                                    Cov_D (K) := D;
                                    Cov_B (K) := Bed;
                                    Cov_S (K) := Top;
                                    Cov_F (K) := W.Flow (C);
                                 end if;
                              else
                                 Bank_H (K) :=
                                   Float'Min (Bank_H (K), Bed + (D - R - 0.75) * Bank_K);
                                 if D - R < Near_D (K) then
                                    Near_D (K) := D - R;
                                    Near_S (K) := Top;
                                    Near_F (K) := W.Flow (C);
                                 end if;
                              end if;
                           end if;
                        end;
                     end if;
                  end loop;
               end loop;
            end;
         end Stamp;

      begin
         for C in Cell_Range loop
            Dist_L (C) := (if W.Kind (C) = Lake then 0.0 else 1.0E9);
         end loop;
         Chamfer (Dist_L.all);

         --  The network: Feed_Area of catchment makes a stream, and each
         --  stream's head then climbs its main stem up to Head_Area.
         for C in Cell_Range loop
            if Down (C) >= 0 then
               declare
                  T : constant Cell_Range := Target (C);
               begin
                  if Main_Up (T) < 0 or else W.Flow (C) > W.Flow (Cell_Range (Main_Up (T))) then
                     Main_Up (T) := C;
                  end if;
               end;
            end if;
            Kept (C) := W.Flow (C) >= Feed_Area and then W.Kind (C) /= Lake;
         end loop;
         for C in Cell_Range loop
            if Kept (C) and then (Main_Up (C) < 0 or else not Kept (Cell_Range (Main_Up (C)))) then
               declare
                  J : Integer := Main_Up (C);
               begin
                  while J >= 0 and then not Kept (Cell_Range (J))
                    and then W.Flow (Cell_Range (J)) >= Head_Area and then W.Kind (Cell_Range (J)) /= Lake
                  loop
                     Kept (Cell_Range (J)) := True;
                     J := Main_Up (Cell_Range (J));
                  end loop;
               end;
            end if;
         end loop;

         --  Lake outflows down to the first stream.
         for C in Cell_Range loop
            if W.Kind (C) = Lake and then Down (C) >= 0 and then W.Kind (Target (C)) /= Lake then
               declare
                  Path  : array (1 .. 256) of Cell_Range;
                  Count : Natural := 0;
                  P     : Cell_Range := Target (C);
                  Len   : Float := 0.0;
                  Hit   : Boolean := False;
               begin
                  loop
                     if Kept (P) or else W.Kind (P) = Lake then
                        Hit := True;
                        exit;
                     end if;
                     exit when Count = Path'Last or else Len > Connect_Range_M or else Down (P) < 0;
                     Count := Count + 1;
                     Path (Count) := P;
                     Len := Len + (if Down (P) mod 2 = 1 then 1.414 else 1.0);
                     P := Target (P);
                  end loop;
                  if Hit then
                     for I in 1 .. Count loop
                        Outflow (Path (I)) := True;
                     end loop;
                     Joined := Joined + (if Count > 0 then 1 else 0);
                  end if;
               end;
            end if;
         end loop;


         for C in Cell_Range loop
            if Is_Channel (C) and then Down (C) >= 0 then
               declare
                  T : constant Cell_Range := Target (C);
               begin
                  if Up (T) < 0 or else W.Flow (C) > W.Flow (Cell_Range (Up (T))) then
                     Up (T) := C;
                  end if;
               end;
            end if;
         end loop;

         --  The water surface along the network, upstream first: under the
         --  lowest ground round each channel's cross-section by Freeboard_M,
         --  falling at least S_Min per metre all the way to its mouth.  Then,
         --  from every lake back up the rivers that end in it, no lower than
         --  the lake: still water backs up a river mouth.  The bed lies the
         --  flow's depth below the surface.
         declare
            In_C   : Count_Access := new Count_Field'(others => 0);
            Top_In : Field_Access := New_Field (1.0E9);

            --  The lowest ground at the banks: across the flow on both sides,
            --  half the width and 1.5 m out from the centre.  (Down the
            --  channel the ground is lower by design; counting it as a bank
            --  sank mountain creeks metres into their slopes.)
            function Rim_Ground (C : Cell_Range) return Float is
               Rr     : constant Float := 0.5 * Width_Q (W.Flow (C) * Runoff) + 1.5;
               G      : Float := Orig (C);
               Ux, Uy : Float := 0.0;            --  across the flow, unit length
               Fx, Fy : Float;
            begin
               Centre (C, Fx, Fy);
               G := Float'Min (G, Sample (Orig.all, Fx, Fy));
               if Down (C) >= 0 then
                  Ux := -Float (DY (Integer (Down (C)))) / DL (Integer (Down (C)));
                  Uy := Float (DX (Integer (Down (C)))) / DL (Integer (Down (C)));
               else
                  Ux := 1.0;
               end if;
               for Side in -1 .. 1 loop
                  if Side /= 0 then
                     G := Float'Min (G, Sample (Orig.all, Fx + Float (Side) * Rr * Ux, Fy + Float (Side) * Rr * Uy));
                  end if;
               end loop;
               return G;
            end Rim_Ground;
         begin
            for C in Cell_Range loop
               if Down (C) >= 0 and then Is_Channel (Target (C)) then
                  if Is_Channel (C) then
                     In_C (Target (C)) := In_C (Target (C)) + 1;
                  elsif W.Kind (C) = Lake then
                     Top_In (Target (C)) :=
                       Float'Min (Top_In (Target (C)), W.Water (C) - S_Min * DL (Integer (Down (C))));
                  end if;
               end if;
            end loop;
            Q_Head := 0;
            Q_Tail := 0;
            for C in Cell_Range loop
               if Is_Channel (C) and then In_C (C) = 0 then
                  Queue (Q_Tail) := C;
                  Q_Tail := Q_Tail + 1;
               end if;
            end loop;
            while Q_Head < Q_Tail loop
               declare
                  C : constant Cell_Range := Queue (Q_Head);
               begin
                  Q_Head := Q_Head + 1;
                  --  freeboard is out of reach at a shore: it ramps in over the
                  --  first 8 m from a lake, so outflows leave at the lake's level
                  --  instead of draining it
                  Ch_Top (C) := Float'Min
                    (Rim_Ground (C) - Freeboard_M * Smoothstep (1.0, 8.0, Dist_L (C)), Top_In (C));
                  if Down (C) >= 0 and then Is_Channel (Target (C)) then
                     declare
                        T : constant Cell_Range := Target (C);
                     begin
                        Top_In (T) := Float'Min (Top_In (T), Ch_Top (C) - S_Min * DL (Integer (Down (C))));
                        In_C (T) := In_C (T) - 1;
                        if In_C (T) = 0 then
                           Queue (Q_Tail) := T;
                           Q_Tail := Q_Tail + 1;
                        end if;
                     end;
                  end if;
               end;
            end loop;
            --  Downstream first: no lower than the water below a cell (still
            --  water backs up from a lake), and no more than the grade above
            --  it.  Rivers are graded: where the bank dips, or a tributary
            --  comes in from higher ground, the surface comes down to it over
            --  a stretch instead of in one step (which left walls of water in
            --  rivers).  Only where the ground itself is steeper (cliffs,
            --  mountain creeks) does the water fall as steeply.
            for I in reverse 0 .. Q_Tail - 1 loop
               declare
                  C : constant Cell_Range := Queue (I);
               begin
                  if Down (C) >= 0 and then (W.Kind (Target (C)) = Lake or else Is_Channel (Target (C))) then
                     declare
                        Below : constant Float :=
                          (if W.Kind (Target (C)) = Lake then W.Water (Target (C)) else Ch_Top (Target (C)));
                        Grade : constant Float := Float'Max (Grade_Max, 1.25 * Gradient (C));
                     begin
                        Ch_Top (C) := Float'Min (Float'Max (Ch_Top (C), Below),
                                                 Below + Grade * DL (Integer (Down (C))));
                     end;
                  end if;
               end;
            end loop;
            for I in 0 .. Q_Tail - 1 loop
               declare
                  C  : constant Cell_Range := Queue (I);
                  Q  : constant Float := W.Flow (C) * Runoff;
                  Ln : Float := 1.0;
                  Tn : Float := Ch_Top (C) - S_Min;
               begin
                  if Down (C) >= 0 then
                     Ln := DL (Integer (Down (C)));
                     if W.Kind (Target (C)) = Lake then
                        Tn := W.Water (Target (C));
                     elsif Is_Channel (Target (C)) then
                        Tn := Ch_Top (Target (C));
                     else
                        Tn := Ch_Top (C) - S_Min * Ln;
                     end if;
                  end if;
                  Ch_W (C) := Width_Q (Q);
                  Ch_Bed (C) := Ch_Top (C) - Clamp
                    (Normal_Depth (Q, Ch_W (C), Float'Max (S_Min, (Ch_Top (C) - Tn) / Ln)),
                     (if W.Flow (C) >= River_Area then D_Min_River_M else D_Min_M), D_Max_M);
                  if Orig (C) - Ch_Bed (C) > Deepest then
                     Deepest := Orig (C) - Ch_Bed (C);
                     Deepest_At := C;
                  end if;
                  Max_Q := Float'Max (Max_Q, Q);
               end;
            end loop;
            Free (In_C);
            Free (Top_In);
         end;

         for C in Cell_Range loop
            if Is_Channel (C) then
               Stamp (C);
               if Up (C) < 0 then
                  Heads := Heads + 1;
               end if;
               if Down (C) >= 0 then
                  Ch_Len := Ch_Len + DL (Integer (Down (C)));
                  if W.Flow (C) >= River_Area then
                     Riv_Len := Riv_Len + DL (Integer (Down (C)));
                  end if;
               end if;
               Widest := Float'Max (Widest, Ch_W (C));
            end if;
         end loop;

         for K in Cell_Range loop
            declare
               Covered : constant Boolean := Cov_D (K) < 1.0E8;
               Floor   : constant Float := (if Covered then Cov_B (K) else Bank_H (K));
               Level   : constant Float := (if Covered then Cov_S (K)
                                            elsif Near_D (K) < 1.0E8 then Near_S (K) else 0.0);
               Flow    : constant Float := (if Covered then Cov_F (K) else Near_F (K));
            begin
               if Floor < H (K) then
                  H (K) := Floor;
               end if;
               if Level > 0.0 and then H (K) < Level and then Level > W.Water (K) then
                  W.Water (K) := Level;
                  if W.Kind (K) /= Lake then
                     W.Kind (K) :=
                       (if Flow >= River_Area or else W.Kind (K) = River then River else Stream);
                  end if;
               end if;
            end;
         end loop;

         Free (Dist_L);
         Free (Outflow);
         Free (Kept);
         Free_Up (Main_Up);
         Free (Ch_Top);
         Free (Ch_Bed);
         Free (Ch_W);
         Free (Cov_D);
         Free (Cov_B);
         Free (Cov_S);
         Free (Cov_F);
         Free (Bank_H);
         Free (Near_D);
         Free (Near_S);
         Free (Near_F);
         Free_Up (Up);
      end;

      for C in Cell_Range loop
         if W.Water (C) > 0.0 and then W.Water (C) <= H (C) + 0.01 then
            W.Water (C) := 0.0;
            W.Kind (C)  := Dry;
         end if;
      end loop;

      --------------------------------------------------------------------
      --  6. Slope of the final surface.
      --------------------------------------------------------------------
      declare
         procedure Row (Y : Integer) is
         begin
            for X in 0 .. N - 1 loop
               declare
                  Gx : constant Float := (At_Cell (H, X + 1, Y) - At_Cell (H, X - 1, Y)) * 0.5;
                  Gy : constant Float := (At_Cell (H, X, Y + 1) - At_Cell (H, X, Y - 1)) * 0.5;
               begin
                  W.Slope (Idx (X, Y)) := Sqrt (Gx * Gx + Gy * Gy);
               end;
            end loop;
         end Row;
         procedure Rows is new Castle.Jobs.Parallel_For (Row);
      begin
         Rows (0, N - 1, 16);
      end;

      --------------------------------------------------------------------
      --  7. Distance to open water (two-pass chamfer) carrying the level of
      --     the nearest water, so lake and river shores get sand; streams
      --     carry a negative level and get none.
      --------------------------------------------------------------------
      declare
         Dist : Castle.Fields.Field renames W.Dist_Water.all;
         Near : Castle.Fields.Field renames Orig.all;

         procedure Relax (C : Cell_Range; X, Y : Integer; Cost : Float) is
         begin
            if In_Map (X, Y) then
               declare
                  K : constant Cell_Range := Idx (X, Y);
               begin
                  if Dist (K) + Cost < Dist (C) then
                     Dist (C) := Dist (K) + Cost;
                     Near (C) := Near (K);
                  end if;
               end;
            end if;
         end Relax;
      begin
         for C in Cell_Range loop
            if W.Water (C) > H (C) then
               Dist (C) := 0.0;
               Near (C) := (if W.Kind (C) = Stream then -W.Water (C) else W.Water (C));
            else
               Dist (C) := 1.0E9;
               Near (C) := 0.0;
            end if;
         end loop;
         for Y in 0 .. N - 1 loop
            for X in 0 .. N - 1 loop
               Relax (Idx (X, Y), X - 1, Y,     1.0);
               Relax (Idx (X, Y), X - 1, Y - 1, 1.414_21);
               Relax (Idx (X, Y), X,     Y - 1, 1.0);
               Relax (Idx (X, Y), X + 1, Y - 1, 1.414_21);
            end loop;
         end loop;
         for Y in reverse 0 .. N - 1 loop
            for X in reverse 0 .. N - 1 loop
               Relax (Idx (X, Y), X + 1, Y,     1.0);
               Relax (Idx (X, Y), X + 1, Y + 1, 1.414_21);
               Relax (Idx (X, Y), X,     Y + 1, 1.0);
               Relax (Idx (X, Y), X - 1, Y + 1, 1.414_21);
            end loop;
         end loop;
         for C in Cell_Range loop
            if W.Kind (C) = Dry and then Dist (C) < 2.5
              and then Near (C) > 0.0 and then H (C) - Near (C) < 0.8
            then
               W.Kind (C) := Shore;
            end if;
         end loop;
      end;
      Free (Orig);

      --------------------------------------------------------------------
      --  8. Moisture and water table.
      --------------------------------------------------------------------
      declare
         S_M : constant U64 := W.Ch (Castle.Channels.Moisture);

         procedure Row (Y : Integer) is
         begin
            for X in 0 .. N - 1 loop
               declare
                  K  : constant Cell_Range := Idx (X, Y);
                  D  : constant Float := W.Dist_Water (K);
                  Hk : constant Float := H (K);
                  Mo : constant Float :=
                    0.65 * Clamp (1.0 - D / 160.0, 0.0, 1.0)
                    + 0.35 * (0.5 + 0.5 * FBM_2 (S_M, Float (X) / 380.0, Float (Y) / 380.0, 3))
                    - 0.012 * Float'Max (0.0, Hk - 22.0);
                  Dt : constant Float :=
                    0.6 + 3.5 * Smoothstep (0.0, 180.0, D) + 0.35 * Float'Max (0.0, Hk - 18.0);
               begin
                  if Wet (K) and then W.Water (K) <= Hk then
                     --  A silted basin: wet meadow over a high water table.
                     W.Moisture (K)    := Float'Max (0.8, Clamp (Mo, 0.0, 1.0));
                     W.Water_Table (K) := Hk - 0.4;
                  else
                     W.Moisture (K)    := Clamp (Mo, 0.0, 1.0);
                     W.Water_Table (K) :=
                       (if W.Water (K) > Hk then W.Water (K) else Float'Max (0.5, Hk - Dt));
                  end if;
               end;
            end loop;
         end Row;
         procedure Rows is new Castle.Jobs.Parallel_For (Row);
      begin
         Rows (0, N - 1, 16);
      end;

      if Report then
         declare
            Lake_C, River_C, Stream_C, Shore_C : Natural := 0;
            Max_Flow : Float := 0.0;
         begin
            for C in Cell_Range loop
               case W.Kind (C) is
                  when Lake   => Lake_C   := Lake_C + 1;
                  when River  => River_C  := River_C + 1;
                  when Stream => Stream_C := Stream_C + 1;
                  when Shore  => Shore_C  := Shore_C + 1;
                  when Dry    => null;
               end case;
               Max_Flow := Float'Max (Max_Flow, W.Flow (C));
            end loop;
            Put_Line ("    lake outflow cells made channel down to the first stream: " & Img (Joined));
            Put_Line ("    channels: " & Img (Heads) & " heads, " & Img (Ch_Len / 1000.0, 1) & " km ("
                      & Img (Riv_Len / 1000.0, 1) & " km river), widest " & Img (Widest, 1) & " m, largest flow "
                      & Img (Max_Q, 1) & " m^3/s, deepest cut " & Img (Deepest, 1) & " m at"
                      & Natural'Image (Deepest_At mod N) & "," & Natural'Image (Deepest_At / N));
            Put_Line ("    lakes: " & Img (Kept) & "; silted depressions: " & Img (Silted)
                      & " (" & Img (Float (Silt_A) / 10_000.0, 1) & " ha of flat ground)");
            Put_Line ("    open water: lake " & Img (Float (Lake_C) / 10_000.0, 1)
                      & " ha, river " & Img (Float (River_C) / 10_000.0, 1)
                      & " ha, stream " & Img (Float (Stream_C) / 10_000.0, 1)
                      & " ha; shore " & Img (Float (Shore_C) / 10_000.0, 1) & " ha");
            Put_Line ("    largest catchment: " & Img (Max_Flow / 1.0E6, 2) & " km^2");
         end;
      end if;

      Free (Closed);
      Free (Queue);
      Free (Wet);
   end Generate;

end Castle.Hydrology;
