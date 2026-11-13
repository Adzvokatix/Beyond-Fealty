separate (Castle.Colony)
procedure Plan_Camp_Lot (Centre : Vec3; Cx, Cy, Zc : out Integer) is
   Half_M : constant Float := Camp_Size_M / 2.0;
   Half_W : constant Float := Path_Width_M / 2.0;
   Fire   : Vec3;
   Ex, Ey : Float := 0.0;
   Off    : Float;                 --  how far off the nearest path's middle is
begin
   Cx := Integer (Float'Floor (Centre.X * 4.0 + 0.5));   --  the fire on a block corner
   Cy := Integer (Float'Floor (Centre.Y * 4.0 + 0.5));
   Zc := Ground_Row (Cx, Cy, B (Centre.Z) - 1);
   Fire := (Float (Cx) * 0.25, Float (Cy) * 0.25, 0.0);
   Plan_N := 0;
   Plan_Blocks := 0;
   Plan_Cells_N := 0;
   Refused_For := (if Camp_Set then Already elsif not Stake_Set then No_Stake_Yet else Too_Steep);
   if Camp_Set or else not Stake_Set or else Zc < 0 then
      return;
   end if;
   --  the camp lies along a path that passes within reach of its square,
   --  squarely east and north with none; a path too near the fire refuses it
   Way_Of_Path (Fire, Fire, Ex, Ey, Off);
   if Off - Half_W < Camp_Clear_M then
      Refused_For := Path_Near;
      return;
   end if;
   if Off - Half_W > Half_M + Snap_M then
      Ex := 1.0;
      Ey := 0.0;
   end if;
   declare
      Fa : constant Float := Fire.X * Ex + Fire.Y * Ey;
      Fb : constant Float := Fire.Y * Ex - Fire.X * Ey;
      R  : constant Float := Half_M * (abs Ex + abs Ey);        --  its box reaches this far
      X0 : constant Integer := B (Fire.X - R);
      X1 : constant Integer := B (Fire.X + R) + 1;
      Y0 : constant Integer := B (Fire.Y - R);
      Y1 : constant Integer := B (Fire.Y + R) + 1;

      --  a block column of its square
      function Inside (X, Y : Integer) return Boolean is
         Px : constant Float := (Float (X) + 0.5) * 0.25;
         Py : constant Float := (Float (Y) + 0.5) * 0.25;
      begin
         return abs (Px * Ex + Py * Ey - Fa) < Half_M and then abs (Py * Ex - Px * Ey - Fb) < Half_M;
      end Inside;
   begin
      --  near level, nothing on it but grass and grain
      Fall_Cm := 0;
      for X in X0 .. X1 loop
         for Y in Y0 .. Y1 loop
            if Inside (X, Y) then
               declare
                  Zr : constant Integer := Ground_Row (X, Y, Zc);
               begin
                  if Zr >= 0 then
                     Fall_Cm := Natural'Max (Fall_Cm, 25 * abs (Zr - Zc));
                  end if;
               end;
            end if;
         end loop;
      end loop;
      if Fall_Cm > 100 then
         Refused_For := Too_Steep;
         return;
      end if;
      for X in X0 .. X1 loop
         for Y in Y0 .. Y1 loop
            if Inside (X, Y) then
               declare
                  Zr : constant Integer := Ground_Row (X, Y, Zc);
               begin
                  if Zr < 0 then
                     Refused_For := Too_Steep;
                     return;
                  elsif Mat (X, Y, Zr) in Trunk | Boulder | Plank
                    or else Mat (X, Y, Zr + 1) not in Air | Tall_Grass | Wild_Grain | Wild_Vegetables
                  then
                     Refused_For := In_The_Way;
                     In_Way_At := (Float (X) * 0.25, Float (Y) * 0.25, 0.0);
                     return;
                  end if;
               end;
            end if;
         end loop;
      end loop;
      for K in 1 .. N_Cells loop
         if abs (Cells (K).Centre.X - Fire.X) < Half_M + 0.5 and then abs (Cells (K).Centre.Y - Fire.Y) < Half_M + 0.5
         then
            Refused_For := Over_Stockpile;
            return;
         end if;
      end loop;
      --  nor any zone's ground nearer the fire than a path may be
      declare
         N : constant Integer := Integer (Camp_Clear_M * 4.0);
      begin
         for X in Cx - N .. Cx + N - 1 loop
            for Y in Cy - N .. Cy + N - 1 loop
               if Zone_Of_Block (X, Y) /= 0 then
                  Refused_For := Over_Stockpile;
                  return;
               end if;
            end loop;
         end loop;
      end;
      Plan_Lot (Ex, Ey, Fa - Half_M, Fa + Half_M, Fb - Half_M, Fb + Half_M,
                Seed => Fire, Step_B => Integer (Camp_Step_M * 4.0), Places => False);
      Refused_For := (case Plan_Refused is
                         when Lot_Ok => Taken_None,
                         when No_Room | Too_Large => Out_Of_Room,
                         when Off_Path | No_Ground => No_Free_Ground);
   end;
end Plan_Camp_Lot;
