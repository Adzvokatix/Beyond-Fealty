with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Ada.Unchecked_Deallocation;
with Castle.Dims;      use Castle.Dims;
with Castle.Hydrology;

package body Castle.Currents is

   VX, VY : Field_Access;
   QF     : Field_Access;                   --  discharge, m^3/s

   function Discharge (Xm, Ym : Integer) return Float is
     (if QF = null or else Xm not in 0 .. Size_M - 1 or else Ym not in 0 .. Size_M - 1 then 0.0
      else QF (Idx (Xm, Ym)));

   function East  return Field_Access is (VX);
   function North return Field_Access is (VY);

   procedure Sample (X, Y : Float; To_East, To_North : out Float) is
   begin
      if VX = null then
         To_East := 0.0;
         To_North := 0.0;
      else
         To_East := Castle.Fields.Sample (VX.all, X, Y);
         To_North := Castle.Fields.Sample (VY.all, X, Y);
      end if;
   end Sample;

   type Cell_List is array (Positive range <>) of Cell_Range;
   type Cell_List_Access is access Cell_List;
   type Flags is array (Cell_Range) of Boolean with Pack;
   type Flags_Access is access Flags;
   procedure Free is new Ada.Unchecked_Deallocation (Flags, Flags_Access);
   procedure Free is new Ada.Unchecked_Deallocation (Cell_List, Cell_List_Access);
   procedure Free is new Ada.Unchecked_Deallocation (Field, Field_Access);

   Spread_Passes : constant := 14;     --  metres a trunk's current reaches across
   Smooth_Passes : constant := 4;
   Lake_Fade     : constant := 0.75;   --  a lake keeps this much per metre
   Bank_Reach    : constant := 3.0;    --  metres over which the banks slow it

   procedure Build (W : World) is
      N      : constant Integer := Size_M;
      Wet    : Flags_Access := new Flags'(others => False);
      Got    : Flags_Access := new Flags'(others => False);
      Count  : Natural := 0;
   begin
      VX := New_Field;
      VY := New_Field;
      QF := New_Field;

      for K in Cell_Range loop
         if W.Water (K) > W.Height (K) and then W.Kind (K) /= Dry then
            Wet (K) := True;
            Count := Count + 1;
         end if;
      end loop;

      declare
         List : Cell_List_Access := new Cell_List (1 .. Integer'Max (1, Count));
         TX   : Field_Access := New_Field;
         TY   : Field_Access := New_Field;
         Dist : Field_Access := New_Field (1.0E9);
         I    : Natural := 0;

         function Inside (X, Y : Integer) return Boolean is (X in 0 .. N - 1 and then Y in 0 .. N - 1);
      begin
         for K in Cell_Range loop
            if Wet (K) then
               I := I + 1;
               List (I) := K;
            end if;
         end loop;

         --  Seeds: the trunk, cells with real catchment, which run down
         --  their drainage.  A wide river's bank cells drain sideways into
         --  it, so their own directions would be wrong; they take the
         --  trunk's current in the spread below.
         for K of List (1 .. Count) loop
            if W.Kind (K) in Stream | River
              and then W.Flow (K) >= Castle.Hydrology.Head_Area
              and then W.Down (K) >= 0
            then
               declare
                  D  : constant Flow_Dir := W.Down (K);
                  L  : constant Float := (if D mod 2 = 0 then 1.0 else Sqrt (2.0));
                  Q  : constant Float := W.Flow (K) * Castle.Hydrology.Runoff;
                  B  : constant Float := Float'Max (1.5, Float'Min (24.0, 5.0 * Sqrt (Q)));
                  Dp : constant Float := Float'Max (0.2, W.Water (K) - W.Height (K));
                  S  : constant Float := Float'Max (0.05, Float'Min (2.5, Q / (B * Dp)));
               begin
                  VX (K) := Float (Dir_DX (D)) / L * S;
                  VY (K) := Float (Dir_DY (D)) / L * S;
                  QF (K) := Q;
                  Got (K) := True;
               end;
            end if;
         end loop;

         --  Spread across the channel a metre a pass: a wet cell not yet
         --  reached takes the mean of its reached neighbours; lakes let
         --  it fade.
         for Pass in 1 .. Spread_Passes loop
            declare
               New_Got : Natural := 0;
            begin
               for K of List (1 .. Count) loop
                  if not Got (K) then
                     declare
                        X  : constant Integer := Integer (K) mod N;
                        Y  : constant Integer := Integer (K) / N;
                        SX, SY : Float := 0.0;
                        SQ     : Float := 0.0;
                        C  : Natural := 0;
                     begin
                        for DY in -1 .. 1 loop
                           for DX in -1 .. 1 loop
                              if (DX /= 0 or else DY /= 0) and then Inside (X + DX, Y + DY) then
                                 declare
                                    J : constant Cell_Range := Idx (X + DX, Y + DY);
                                 begin
                                    if Got (J) then
                                       SX := SX + VX (J);
                                       SY := SY + VY (J);
                                       SQ := Float'Max (SQ, QF (J));
                                       C := C + 1;
                                    end if;
                                 end;
                              end if;
                           end loop;
                        end loop;
                        if C > 0 then
                           declare
                              F : constant Float := (if W.Kind (K) = Lake then Lake_Fade else 1.0);
                           begin
                              TX (K) := SX / Float (C) * F;
                              TY (K) := SY / Float (C) * F;
                              Dist (K) := SQ;            --  (borrowed until the banks pass)
                              New_Got := New_Got + 1;
                           end;
                        else
                           TX (K) := Float'Last;      --  not reached this pass
                        end if;
                     end;
                  end if;
               end loop;
               for K of List (1 .. Count) loop
                  if not Got (K) and then TX (K) /= Float'Last then
                     VX (K) := TX (K);
                     VY (K) := TY (K);
                     QF (K) := (if W.Kind (K) = Lake then 0.0 else Dist (K));
                     Got (K) := True;
                  end if;
               end loop;
               exit when New_Got = 0;
            end;
         end loop;

         --  Smooth: a box blur over wet cells only, so the drainage's
         --  turns round off and the current changes gently.
         for Pass in 1 .. Smooth_Passes loop
            for K of List (1 .. Count) loop
               declare
                  X  : constant Integer := Integer (K) mod N;
                  Y  : constant Integer := Integer (K) / N;
                  SX : Float := VX (K);
                  SY : Float := VY (K);
                  C  : Natural := 1;
               begin
                  for DY in -1 .. 1 loop
                     for DX in -1 .. 1 loop
                        if (DX /= 0 or else DY /= 0) and then Inside (X + DX, Y + DY) then
                           declare
                              J : constant Cell_Range := Idx (X + DX, Y + DY);
                           begin
                              if Wet (J) then
                                 SX := SX + VX (J);
                                 SY := SY + VY (J);
                                 C := C + 1;
                              end if;
                           end;
                        end if;
                     end loop;
                  end loop;
                  TX (K) := SX / Float (C);
                  TY (K) := SY / Float (C);
               end;
            end loop;
            for K of List (1 .. Count) loop
               VX (K) := TX (K);
               VY (K) := TY (K);
            end loop;
         end loop;

         --  Banks: distance in from dry ground (metres, 8-neighbour), and
         --  the current slows over the last few.
         for K of List (1 .. Count) loop
            Dist (K) := 1.0E9;
         end loop;
         for K of List (1 .. Count) loop
            declare
               X : constant Integer := Integer (K) mod N;
               Y : constant Integer := Integer (K) / N;
            begin
               for DY in -1 .. 1 loop
                  for DX in -1 .. 1 loop
                     if Inside (X + DX, Y + DY) and then not Wet (Idx (X + DX, Y + DY)) then
                        Dist (K) := 1.0;
                     end if;
                  end loop;
               end loop;
            end;
         end loop;
         for Ring in 2 .. Integer (Bank_Reach) loop
            for K of List (1 .. Count) loop
               if Dist (K) > Float (Ring) then
                  declare
                     X : constant Integer := Integer (K) mod N;
                     Y : constant Integer := Integer (K) / N;
                  begin
                     for DY in -1 .. 1 loop
                        for DX in -1 .. 1 loop
                           if Inside (X + DX, Y + DY) and then Dist (Idx (X + DX, Y + DY)) = Float (Ring - 1) then
                              Dist (K) := Float (Ring);
                           end if;
                        end loop;
                     end loop;
                  end;
               end if;
            end loop;
         end loop;
         for K of List (1 .. Count) loop
            declare
               F : constant Float := Sqrt (Float'Min (1.0, Dist (K) / Bank_Reach));
            begin
               VX (K) := VX (K) * F;
               VY (K) := VY (K) * F;
            end;
         end loop;
         Free (List);
         Free (TX);
         Free (TY);
         Free (Dist);
      end;
      Free (Wet);
      Free (Got);
   end Build;

end Castle.Currents;
