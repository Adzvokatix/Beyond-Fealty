with Ada.Command_Line;  use Ada.Command_Line;
with Ada.Text_IO;       use Ada.Text_IO;
with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Castle.Dims;       use Castle.Dims;
with Castle.Hash;
with Castle.Maps;       use Castle.Maps;
with Castle.Terrain;

--  Heights and mountain steepness of the terrain stage, for tuning
--  Castle.Terrain.Mountain_Relief_M and Ridge_Scale_M.
--    terrain_stats [SEED ...]          (default: seeds 1 2 3)
--  Slopes are rise over run in percent: 100 % is 45 degrees.
procedure Terrain_Stats is
   N : constant Integer := Size_M;
   W : World;
   type Hist is array (0 .. 1_000) of Natural;

   function Pct (H : Hist; Total : Natural; P : Float) return Integer is
      Acc : Natural := 0;
   begin
      for I in H'Range loop
         Acc := Acc + H (I);
         if Float (Acc) >= P * Float (Total) then
            return I;
         end if;
      end loop;
      return H'Last;
   end Pct;

   function At_H (X, Y : Integer) return Float is
     (W.Height (Integer'Max (0, Integer'Min (N - 1, Y)) * N + Integer'Max (0, Integer'Min (N - 1, X))));

   procedure Report (Seed : Castle.Hash.U64) is
      Heights, Slopes : Hist := (others => 0);
      Peak       : Float := 0.0;
      Px, Py     : Integer := 0;
      Core       : Natural := 0;
      Above_Knee : Natural := 0;
      Cliff      : Natural := 0;               --  cells steeper than 70 degrees
      Best_C     : Float   := 0.0;             --  tallest drop to a neighbour cell
      Cx, Cy     : Integer := 0;
   begin
      Allocate (W, Seed);
      Castle.Terrain.Generate (W);
      for Y in 0 .. N - 1 loop
         for X in 0 .. N - 1 loop
            declare
               H  : constant Float := At_H (X, Y);
               Gx : constant Float := (At_H (X + 1, Y) - At_H (X - 1, Y)) / 2.0;
               Gy : constant Float := (At_H (X, Y + 1) - At_H (X, Y - 1)) / 2.0;
               S  : constant Integer := Integer'Min (1_000, Integer (100.0 * Sqrt (Gx * Gx + Gy * Gy)));
               Hb : constant Integer := Integer'Min (1_000, Integer (H));
            begin
               Heights (Hb) := Heights (Hb) + 1;
               if H > Peak then
                  Peak := H; Px := X; Py := Y;
               end if;
               if S >= 275 then
                  Cliff := Cliff + 1;
                  declare
                     Drop : constant Float := H - Float'Min (Float'Min (At_H (X + 2, Y), At_H (X - 2, Y)),
                                                             Float'Min (At_H (X, Y + 2), At_H (X, Y - 2)));
                  begin
                     if Drop > Best_C and then W.Mountain (Y * N + X) < 0.6 then
                        Best_C := Drop; Cx := X; Cy := Y;
                     end if;
                  end;
               end if;
               if H > Castle.Terrain.Knee_M then
                  Above_Knee := Above_Knee + 1;
               end if;
               if W.Mountain (Y * N + X) >= 0.5 then
                  Core := Core + 1;
                  Slopes (S) := Slopes (S) + 1;
               end if;
            end;
         end loop;
      end loop;
      Put_Line ("seed" & Seed'Image & ": peak" & Integer (Peak)'Image & " m at" & Px'Image & Py'Image
                & ", p99" & Pct (Heights, N * N, 0.99)'Image & " m, p99.9"
                & Pct (Heights, N * N, 0.999)'Image & " m," & Above_Knee'Image & " m2 above the knee");
      Put_Line ("   cliff faces (over 70 degrees):" & Integer (Float (Cliff) / 1.0E4)'Image
                & " ha; a tall one at" & Cx'Image & Cy'Image & " (" & Integer (Best_C)'Image & " m in 2 m)");
      if Core > 0 then
         Put_Line ("   mountain core" & Integer (Float (Core) / 1.0E4)'Image & " ha, slope p50"
                   & Pct (Slopes, Core, 0.5)'Image & "% p90" & Pct (Slopes, Core, 0.9)'Image
                   & "% p99" & Pct (Slopes, Core, 0.99)'Image & "%");
      end if;
   end Report;

begin
   Put_Line ("relief" & Integer (Castle.Terrain.Mountain_Relief_M)'Image & " m, ridge scale"
             & Integer (Castle.Terrain.Ridge_Scale_M)'Image & " m, knee"
             & Integer (Castle.Terrain.Knee_M)'Image & " m, cap" & Integer (Castle.Terrain.Terrain_Cap_M)'Image
             & " m, world" & Height_M'Image & " m");
   if Argument_Count = 0 then
      for S in 1 .. 3 loop
         Report (Castle.Hash.U64 (S));
      end loop;
   else
      for I in 1 .. Argument_Count loop
         Report (Castle.Hash.U64'Value (Argument (I)));
      end loop;
   end if;
end Terrain_Stats;
