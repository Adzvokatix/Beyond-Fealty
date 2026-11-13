with Ada.Text_IO;   use Ada.Text_IO;
with Castle.Dims;   use Castle.Dims;
with Castle.Geology;
with Castle.Hash;
with Castle.Maps;   use Castle.Maps;
with Castle.Text;   use Castle.Text;
with Castle.Worldgen;

--  Water quality over the whole map of seed 1, block by block:
--    * water standing above a dry neighbour's ground (it shows as a floating
--      block: never wanted), by kind of water and likely cause;
--    * steps between water columns (the flow going downhill), by height;
--    * how far each lake's outflow runs before it becomes a visible stream.
procedure Water_Check is
   W : World;
   N : constant := Size_M;                     --  1 m cells per side

   function Idx (X, Y : Integer) return Natural is (Y * N + X);
   function Wet_Cell (X, Y : Integer) return Boolean is
     (X in 0 .. N - 1 and then Y in 0 .. N - 1 and then W.Water (Idx (X, Y)) > 0.0);

   Float_Cols, Float_Faces : array (Water_Kind) of Natural := (others => 0);
   Film_Like  : Natural := 0;                  --  floating, one block deep on a steep cell
   Steps      : array (1 .. 5) of Natural := (others => 0);   --  1, 2, 3, 4-7, 8+ blocks
   Examples   : array (Water_Kind, 1 .. 2) of Integer := (others => (others => -1));
   Ex_Y       : array (Water_Kind, 1 .. 2) of Integer := (others => (others => -1));
   Seen       : Natural := 0;
   Big_Steps  : array (Water_Kind, Water_Kind) of Natural := (others => (others => 0));   --  2+ blocks
begin
   Castle.Worldgen.Create (Castle.Hash.U64 (1), W, Report => False);

   --  1. Lake outflows: from each lake cell draining out of its lake, follow
   --  the drainage to the first channel (or lake).
   declare
      Bins  : array (1 .. 6) of Natural := (others => 0);   --  0, <=20, <=40, <=80, <=160, more
      Shown : Natural := 0;
   begin
      for Y in 0 .. N - 1 loop
         for X in 0 .. N - 1 loop
            declare
               K : constant Natural := Idx (X, Y);
               D : constant Flow_Dir := W.Down (K);
            begin
               if W.Kind (K) = Lake and then D >= 0
                 and then W.Kind (Idx (X + Dir_DX (D), Y + Dir_DY (D))) /= Lake
               then
                  declare
                     Px  : Integer := X + Dir_DX (D);
                     Py  : Integer := Y + Dir_DY (D);
                     Len : Float := 0.0;
                     Hit : Boolean := False;
                  begin
                     loop
                        declare
                           P : constant Natural := Idx (Px, Py);
                        begin
                           if W.Kind (P) = Lake
                             or else (W.Kind (P) in Stream | River and then W.Water (P) > 0.0)
                           then
                              Hit := True;
                              exit;
                           end if;
                           exit when W.Down (P) < 0 or else Len > 400.0;
                           Len := Len + (if Dir_DX (W.Down (P)) /= 0 and then Dir_DY (W.Down (P)) /= 0
                                         then 1.414 else 1.0);
                           Px := Px + Dir_DX (W.Down (P));
                           Py := Py + Dir_DY (W.Down (P));
                        end;
                     end loop;
                     if not Hit or else Len > 160.0 then
                        Bins (6) := Bins (6) + 1;
                     elsif Len = 0.0 then
                        Bins (1) := Bins (1) + 1;
                     elsif Len <= 20.0 then
                        Bins (2) := Bins (2) + 1;
                     elsif Len <= 40.0 then
                        Bins (3) := Bins (3) + 1;
                     elsif Len <= 80.0 then
                        Bins (4) := Bins (4) + 1;
                     else
                        Bins (5) := Bins (5) + 1;
                     end if;
                     if Hit and then Len > 0.0 and then Len <= 80.0 and then Shown < 3 then
                        Shown := Shown + 1;
                        Put_Line ("   gap example: lake outlet at" & X'Image & "," & Y'Image & ", stream starts "
                                  & Img (Len, 0) & " m downhill");
                     end if;
                  end;
               end if;
            end;
         end loop;
      end loop;
      Put_Line ("lake outflows: joined at once" & Bins (1)'Image & ", gap <=20 m" & Bins (2)'Image
                & ", <=40 m" & Bins (3)'Image & ", <=80 m" & Bins (4)'Image & ", <=160 m" & Bins (5)'Image
                & ", longer or none" & Bins (6)'Image);
   end;

   --  2. Block columns in or next to water.
   for Y in 0 .. N - 1 loop
      for X in 0 .. N - 1 loop
         declare
            Near     : Boolean := False;
            Interior : Boolean := True;
         begin
            for DY in -1 .. 1 loop
               for DX in -1 .. 1 loop
                  if Wet_Cell (X + DX, Y + DY) then
                     Near := True;
                  end if;
                  if not (X + DX in 0 .. N - 1 and then Y + DY in 0 .. N - 1
                          and then W.Kind (Idx (X + DX, Y + DY)) = Lake)
                  then
                     Interior := False;
                  end if;
               end loop;
            end loop;
            if Near and then not Interior then
               for BX in 4 * X .. 4 * X + 3 loop
                  for BY in 4 * Y .. 4 * Y + 3 loop
                     declare
                        C : constant Castle.Geology.Column := Castle.Geology.Prepare_Column (W, BX, BY);
                     begin
                        Seen := Seen + 1;
                        if C.Water_Top > C.Solid then
                           for D in 0 .. 3 loop
                              declare
                                 NX : constant Integer := BX + (case D is when 0 => 1, when 1 => -1, when others => 0);
                                 NY : constant Integer := BY + (case D is when 2 => 1, when 3 => -1, when others => 0);
                              begin
                                 if NX in 0 .. Size_B - 1 and then NY in 0 .. Size_B - 1 then
                                    declare
                                       Cn : constant Castle.Geology.Column :=
                                         Castle.Geology.Prepare_Column (W, NX, NY);
                                    begin
                                       if Cn.Water_Top <= Cn.Solid then
                                          if Cn.Solid < C.Water_Top then
                                             Float_Cols (C.Kind) := Float_Cols (C.Kind) + 1;
                                             Float_Faces (C.Kind) := Float_Faces (C.Kind)
                                               + C.Water_Top - Integer'Max (Cn.Solid, C.Solid);
                                             if C.Water_Top - C.Solid = 1 and then C.Slope > 0.25 then
                                                Film_Like := Film_Like + 1;
                                             end if;
                                             for E in 1 .. 2 loop
                                                if Examples (C.Kind, E) < 0 then
                                                   if E = 1 or else abs (BX - Examples (C.Kind, 1)) > 400 then
                                                      Examples (C.Kind, E) := BX;
                                                      Ex_Y (C.Kind, E) := BY;
                                                   end if;
                                                   exit;
                                                end if;
                                             end loop;
                                          end if;
                                       elsif Cn.Water_Top < C.Water_Top then
                                          declare
                                             S : constant Integer := C.Water_Top - Integer'Max (Cn.Water_Top, C.Solid);
                                          begin
                                             if S >= 2 then
                                                Big_Steps (C.Kind, Cn.Kind) := Big_Steps (C.Kind, Cn.Kind) + 1;
                                             end if;
                                             if S > 0 then
                                                Steps (if S <= 3 then S elsif S <= 7 then 4 else 5) :=
                                                  Steps (if S <= 3 then S elsif S <= 7 then 4 else 5) + 1;
                                             end if;
                                          end;
                                       end if;
                                    end;
                                 end if;
                              end;
                           end loop;
                        end if;
                     end;
                  end loop;
               end loop;
            end if;
         end;
      end loop;
   end loop;

   Put_Line ("block columns looked at:" & Seen'Image);
   Put_Line ("water above a dry neighbour (floating), by kind of water:");
   for K in Water_Kind loop
      if Float_Cols (K) > 0 then
         Put_Line ("   " & Water_Kind'Image (K) & ":" & Float_Cols (K)'Image & " column sides,"
                   & Float_Faces (K)'Image & " exposed water faces");
         for E in 1 .. 2 loop
            if Examples (K, E) >= 0 then
               Put_Line ("      e.g. at " & Img (Float (Examples (K, E)) * 0.25, 1) & ","
                         & Img (Float (Ex_Y (K, E)) * 0.25, 1));
            end if;
         end loop;
      end if;
   end loop;
   Put_Line ("   of which one block deep on a steep cell (the fast-water film):" & Film_Like'Image);
   Put_Line ("steps down to lower water: 1 block" & Steps (1)'Image & ", 2:" & Steps (2)'Image
             & ", 3:" & Steps (3)'Image & ", 4-7:" & Steps (4)'Image & ", 8+:" & Steps (5)'Image);
   Put_Line ("steps of 2+ blocks, higher water -> lower:");
   for A in Water_Kind loop
      for B in Water_Kind loop
         if Big_Steps (A, B) > 0 then
            Put_Line ("   " & Water_Kind'Image (A) & " -> " & Water_Kind'Image (B) & ":" & Big_Steps (A, B)'Image);
         end if;
      end loop;
   end loop;

   --  Ready for live water?  Along every channel the surface must fall
   --  downstream, and the dry ground beside it must stand above it.
   declare
      Up_Steps, Flats, Falls : Natural := 0;
      Spill, Low_Bank, Banks : Natural := 0;
      Spill_By : array (1 .. 3) of Natural := (others => 0);   --  under 5 cm, 5-25 cm, more
      Deep_Near_Lake : Natural := 0;                          --  of the deep ones, within 15 m of a lake
      Deep_Shown     : Natural := 0;
      Lakes, Ponds : Natural := 0;
      Seen_L : array (0 .. N * N - 1) of Boolean := (others => False);
      Queue  : array (0 .. 65_535) of Natural;
   begin
      for Y in 1 .. N - 2 loop
         for X in 1 .. N - 2 loop
            declare
               K : constant Natural := Idx (X, Y);
            begin
               if W.Kind (K) in Stream | River and then W.Water (K) > 0.0 then
                  declare
                     D : constant Flow_Dir := W.Down (K);
                  begin
                     --  the channel line itself: cells with real catchment
                     --  (bank cells drain sideways across the channel)
                     if D >= 0 and then W.Flow (K) >= 5_000.0 then
                        declare
                           T : constant Natural := Idx (X + Dir_DX (D), Y + Dir_DY (D));
                        begin
                           if W.Water (T) > 0.0 then
                              --  the least fall is 2 mm a metre: tell level from
                              --  gently falling well inside that
                              if W.Water (T) > W.Water (K) + 0.0005 then
                                 Up_Steps := Up_Steps + 1;
                              elsif W.Water (T) >= W.Water (K) - 0.0005 and then W.Kind (T) /= Lake then
                                 Flats := Flats + 1;
                              else
                                 Falls := Falls + 1;
                              end if;
                           end if;
                        end;
                     end if;
                  end;
                  for DY in -1 .. 1 loop
                     for DX in -1 .. 1 loop
                        declare
                           J : constant Natural := Idx (X + DX, Y + DY);
                        begin
                           if W.Water (J) = 0.0 then
                              Banks := Banks + 1;
                              if W.Height (J) < W.Water (K) then
                                 Spill := Spill + 1;
                                 declare
                                    Below : constant Float := W.Water (K) - W.Height (J);
                                 begin
                                    Spill_By (if Below < 0.05 then 1 elsif Below < 0.25 then 2 else 3) :=
                                      Spill_By (if Below < 0.05 then 1 elsif Below < 0.25 then 2 else 3) + 1;
                                    if Below >= 0.25 then
                                       declare
                                          Near_Lake : Boolean := False;
                                       begin
                                          for LY in Integer'Max (0, Y - 15) .. Integer'Min (N - 1, Y + 15) loop
                                             for LX in Integer'Max (0, X - 15) .. Integer'Min (N - 1, X + 15) loop
                                                if W.Kind (Idx (LX, LY)) = Lake then
                                                   Near_Lake := True;
                                                end if;
                                             end loop;
                                          end loop;
                                          if Near_Lake then
                                             Deep_Near_Lake := Deep_Near_Lake + 1;
                                          elsif Deep_Shown < 3 then
                                             Deep_Shown := Deep_Shown + 1;
                                             Put_Line ("   deep spill away from lakes at" & X'Image & "," & Y'Image
                                                       & ": ground " & Img (Below, 2) & " m under the water");
                                          end if;
                                       end;
                                    end if;
                                 end;
                              elsif W.Height (J) < W.Water (K) + 0.25 then
                                 Low_Bank := Low_Bank + 1;
                              end if;
                           end if;
                        end;
                     end loop;
                  end loop;
               end if;
            end;
         end loop;
      end loop;
      --  lakes and ponds: 8-connected lake cells, ponds under 5,000 m^2
      for K in Seen_L'Range loop
         if W.Kind (K) = Lake and then not Seen_L (K) then
            declare
               H, T : Natural := 0;
               Area : Natural := 0;
            begin
               Queue (0) := K;
               T := 1;
               Seen_L (K) := True;
               while H < T loop
                  declare
                     Q : constant Natural := Queue (H mod Queue'Length);
                  begin
                     H := H + 1;
                     Area := Area + 1;
                     for DY in -1 .. 1 loop
                        for DX in -1 .. 1 loop
                           declare
                              X2 : constant Integer := Q mod N + DX;
                              Y2 : constant Integer := Q / N + DY;
                           begin
                              if X2 in 0 .. N - 1 and then Y2 in 0 .. N - 1
                                and then W.Kind (Idx (X2, Y2)) = Lake and then not Seen_L (Idx (X2, Y2))
                              then
                                 Seen_L (Idx (X2, Y2)) := True;
                                 Queue (T mod Queue'Length) := Idx (X2, Y2);
                                 T := T + 1;
                              end if;
                           end;
                        end loop;
                     end loop;
                  end;
               end loop;
               if Area < 5_000 then
                  Ponds := Ponds + 1;
               else
                  Lakes := Lakes + 1;
               end if;
            end;
         end if;
      end loop;
      Put_Line ("lakes:" & Lakes'Image & ", ponds (under 5,000 m^2):" & Ponds'Image);
      Put_Line ("along channel lines, water downstream is: lower" & Falls'Image & ", level" & Flats'Image
                & " (stagnant), higher" & Up_Steps'Image & " (water would run uphill)");
      Put_Line ("dry ground beside channel water:" & Banks'Image & " cells; below the water (spills)"
                & Spill'Image & ", under 25 cm above it" & Low_Bank'Image);
      Put_Line ("   spills by how far the ground is under the water: <5 cm" & Spill_By (1)'Image
                & ", 5-25 cm" & Spill_By (2)'Image & ", more" & Spill_By (3)'Image
                & " (of those" & Deep_Near_Lake'Image & " within 15 m of a lake)");
   end;

   --  A lake to disturb: the lake cell nearest the map's middle with lake
   --  water 4 m on every side.
   declare
      Best : Integer := Integer'Last;
      Bx, By : Integer := 0;
   begin
      for Y in 20 .. N - 21 loop
         for X in 20 .. N - 21 loop
            if W.Kind (Idx (X, Y)) = Lake and then W.Kind (Idx (X + 4, Y)) = Lake and then W.Kind (Idx (X - 4, Y)) = Lake
              and then W.Kind (Idx (X, Y + 4)) = Lake and then W.Kind (Idx (X, Y - 4)) = Lake
              and then (X - 1024) ** 2 + (Y - 1024) ** 2 < Best
            then
               Best := (X - 1024) ** 2 + (Y - 1024) ** 2;
               Bx := X;
               By := Y;
            end if;
         end loop;
      end loop;
      Put_Line ("a lake:" & Bx'Image & "," & By'Image & ", surface " & Img (W.Water (Idx (Bx, By)), 2)
                & " m, bed " & Img (W.Height (Idx (Bx, By)), 2) & " m");
   end;

   --  How deep the channels run: water over the bed along channel lines.
   declare
      Sum_R, Sum_S, Max_R, Max_S : Float := 0.0;
      N_R, N_S : Natural := 0;
   begin
      for K in 0 .. N * N - 1 loop
         if W.Water (K) > 0.0 and then W.Flow (K) >= 5_000.0 then
            declare
               D : constant Float := W.Water (K) - W.Height (K);
            begin
               if W.Kind (K) = River then
                  Sum_R := Sum_R + D; N_R := N_R + 1; Max_R := Float'Max (Max_R, D);
               elsif W.Kind (K) = Stream then
                  Sum_S := Sum_S + D; N_S := N_S + 1; Max_S := Float'Max (Max_S, D);
               end if;
            end;
         end if;
      end loop;
      Put_Line ("channel depth: rivers mean " & Img (Sum_R / Float (Natural'Max (1, N_R)), 2) & " m, deepest "
                & Img (Max_R, 2) & " m; streams mean " & Img (Sum_S / Float (Natural'Max (1, N_S)), 2)
                & " m, deepest " & Img (Max_S, 2) & " m");
   end;

   --  A river bank to dig into: river water with dry ground 6 m east of
   --  it, near the middle of the map.
   declare
      Shown : Natural := 0;
   begin
      for Y in 900 .. 1_200 loop
         for X in 900 .. 1_200 loop
            declare
               K : constant Natural := Idx (X, Y);
            begin
               if Shown < 2 and then W.Kind (K) = River and then W.Water (K) > 0.0
                 and then W.Water (Idx (X + 1, Y)) = 0.0 and then W.Water (Idx (X + 6, Y)) = 0.0
                 and then W.Water (Idx (X, Y + 6)) > 0.0 and then W.Water (Idx (X, Y - 6)) > 0.0
               then
                  Shown := Shown + 1;
                  Put_Line ("river bank: water at" & X'Image & "," & Y'Image & " (surface "
                            & Img (W.Water (K), 2) & " m), ground 6 m east at "
                            & Img (W.Height (Idx (X + 6, Y)), 2) & " m");
               end if;
            end;
         end loop;
      end loop;
   end;

   --  The highest stream on steep ground: an open mountain creek to look at.
   declare
      Best_H : Float := 0.0;
      Bx, By : Integer := 0;
   begin
      for Y in 0 .. N - 1 loop
         for X in 0 .. N - 1 loop
            declare
               K : constant Natural := Idx (X, Y);
            begin
               if W.Kind (K) = Stream and then W.Water (K) > Best_H and then W.Slope (K) > 0.3 then
                  Best_H := W.Water (K);
                  Bx := X;
                  By := Y;
               end if;
            end;
         end loop;
      end loop;
      Put_Line ("highest steep stream:" & Bx'Image & "," & By'Image & " at " & Img (Best_H, 0) & " m");
   end;

   --  3. Water bodies (8-connected wet cells): streams that come within
   --  60 m of a lake without joining it, and whether their water lies
   --  below the lake's (so the lake could feed them).
   declare
      type Int_Field is array (Natural range <>) of Integer;
      type Flt_Field is array (Natural range <>) of Float;
      type Int_Access is access Int_Field;
      type Flt_Access is access Flt_Field;
      Comp  : constant Int_Access := new Int_Field'(0 .. N * N - 1 => 0);
      Queue : constant Int_Access := new Int_Field (0 .. N * N - 1);
      Dist  : constant Flt_Access := new Flt_Field (0 .. N * N - 1);
      LComp : constant Int_Access := new Int_Field'(0 .. N * N - 1 => 0);   --  nearest lake's body
      LLvl  : constant Flt_Access := new Flt_Field'(0 .. N * N - 1 => 0.0);
      Bodies : Natural := 0;
      procedure Relax (K, J : Natural; Cost : Float) is
      begin
         if Dist (J) + Cost < Dist (K) then
            Dist (K) := Dist (J) + Cost;
            LComp (K) := LComp (J);
            LLvl (K) := LLvl (J);
         end if;
      end Relax;
   begin
      for K in Comp'Range loop
         if W.Water (K) > 0.0 and then Comp (K) = 0 then
            Bodies := Bodies + 1;
            declare
               H, T : Natural := 0;
            begin
               Queue (0) := K;
               T := 1;
               Comp (K) := Bodies;
               while H < T loop
                  declare
                     Q : constant Natural := Queue (H);
                  begin
                     H := H + 1;
                     for DY in -1 .. 1 loop
                        for DX in -1 .. 1 loop
                           declare
                              X : constant Integer := Q mod N + DX;
                              Y : constant Integer := Q / N + DY;
                           begin
                              if X in 0 .. N - 1 and then Y in 0 .. N - 1
                                and then W.Water (Idx (X, Y)) > 0.0 and then Comp (Idx (X, Y)) = 0
                              then
                                 Comp (Idx (X, Y)) := Bodies;
                                 Queue (T) := Idx (X, Y);
                                 T := T + 1;
                              end if;
                           end;
                        end loop;
                     end loop;
                  end;
               end loop;
            end;
         end if;
      end loop;
      for K in Dist'Range loop
         Dist (K) := (if W.Kind (K) = Lake then 0.0 else 1.0E9);
         LComp (K) := (if W.Kind (K) = Lake then Comp (K) else 0);
         LLvl (K) := W.Water (K);
      end loop;
      for Y in 0 .. N - 1 loop
         for X in 0 .. N - 1 loop
            if X > 0 then Relax (Idx (X, Y), Idx (X - 1, Y), 1.0); end if;
            if Y > 0 then Relax (Idx (X, Y), Idx (X, Y - 1), 1.0); end if;
            if X > 0 and then Y > 0 then Relax (Idx (X, Y), Idx (X - 1, Y - 1), 1.414); end if;
            if X < N - 1 and then Y > 0 then Relax (Idx (X, Y), Idx (X + 1, Y - 1), 1.414); end if;
         end loop;
      end loop;
      for Y in reverse 0 .. N - 1 loop
         for X in reverse 0 .. N - 1 loop
            if X < N - 1 then Relax (Idx (X, Y), Idx (X + 1, Y), 1.0); end if;
            if Y < N - 1 then Relax (Idx (X, Y), Idx (X, Y + 1), 1.0); end if;
            if X < N - 1 and then Y < N - 1 then Relax (Idx (X, Y), Idx (X + 1, Y + 1), 1.414); end if;
            if X > 0 and then Y < N - 1 then Relax (Idx (X, Y), Idx (X - 1, Y + 1), 1.414); end if;
         end loop;
      end loop;
      declare
         Best  : array (1 .. Bodies) of Float := (others => 1.0E9);
         Below : array (1 .. Bodies) of Boolean := (others => False);
         Bx, By : array (1 .. Bodies) of Integer := (others => 0);
         Lake_Body : array (1 .. Bodies) of Boolean := (others => False);
         Bins  : array (1 .. 3, Boolean) of Natural := (others => (others => 0));
         Shown : Natural := 0;
      begin
         for K in Comp'Range loop
            if Comp (K) > 0 then
               if W.Kind (K) = Lake then
                  Lake_Body (Comp (K)) := True;
               elsif LComp (K) /= Comp (K) and then Dist (K) < Best (Comp (K)) then
                  Best (Comp (K)) := Dist (K);
                  Below (Comp (K)) := W.Water (K) < LLvl (K);
                  Bx (Comp (K)) := K mod N;
                  By (Comp (K)) := K / N;
               end if;
            end if;
         end loop;
         for B in 1 .. Bodies loop
            if not Lake_Body (B) and then Best (B) <= 60.0 then
               declare
                  I : constant Integer := (if Best (B) <= 10.0 then 1 elsif Best (B) <= 30.0 then 2 else 3);
               begin
                  Bins (I, Below (B)) := Bins (I, Below (B)) + 1;
                  if Below (B) and then Shown < 4 then
                     Shown := Shown + 1;
                     Put_Line ("   unjoined stream at" & Bx (B)'Image & "," & By (B)'Image & ", "
                               & Img (Best (B), 0) & " m from a lake, below its level");
                  end if;
               end;
            end if;
         end loop;
         Put_Line ("water bodies:" & Bodies'Image & "; streams near a lake but not joined to it, below / above its level:");
         Put_Line ("   <=10 m:" & Bins (1, True)'Image & " /" & Bins (1, False)'Image
                   & "   <=30 m:" & Bins (2, True)'Image & " /" & Bins (2, False)'Image
                   & "   <=60 m:" & Bins (3, True)'Image & " /" & Bins (3, False)'Image);
      end;
   end;
end Water_Check;
