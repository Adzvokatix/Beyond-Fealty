separate (Castle.Colony)
procedure Lay_Path (From, To : Vec3; Laid : out Natural) is
   S    : constant Path_Seg := (A => From, B => To, others => <>);
   Half : constant Float := Path_Width_M / 2.0;
   X0   : constant Integer := B (Float'Min (From.X, To.X) - Half);
   X1   : constant Integer := B (Float'Max (From.X, To.X) + Half);
   Y0   : constant Integer := B (Float'Min (From.Y, To.Y) - Half);
   Y1   : constant Integer := B (Float'Max (From.Y, To.Y) + Half);
   L    : constant Float := Flat_Dist (From, To);
   --  planned, a path is kept as stretches of Path_Stretch_M (Line_Pieces)
   Pieces : constant Positive := Line_Pieces (L);
   Paths_Were : constant Natural := N_Paths;
begin
   Laid := 0;
   Path_Refused_For := Nothing_There;
   if L < 0.25 or else N_Paths + Pieces > Max_Paths then
      if N_Paths + Pieces > Max_Paths then
         Path_Refused_For := No_More;
      end if;
      return;
   end if;
   --  paths go round zones: a line that runs through zoned ground is not laid
   if N_Zones > 0 then
      for K in 0 .. Integer (Float'Ceiling (L * 8.0)) loop
         declare
            T : constant Float := Float'Min (1.0, Float (K) / (L * 8.0));
         begin
            if Zone_On (From.X + (To.X - From.X) * T, From.Y + (To.Y - From.Y) * T) /= 0 then
               Path_Refused_For := Through_Zone;
               return;
            end if;
         end;
      end loop;
   end if;
   --  nor through the lord's cart
   if Cart_Set then
      for K in 0 .. Integer (Float'Ceiling (L * 8.0)) loop
         declare
            T  : constant Float := Float'Min (1.0, Float (K) / (L * 8.0));
            Px : constant Float := From.X + (To.X - From.X) * T;
            Py : constant Float := From.Y + (To.Y - From.Y) * T;
         begin
            if Cart_On_Block (B (Px), B (Py), Margin => Integer (Half * 4.0)) then
               Path_Refused_For := Through_Cart;
               return;
            end if;
         end;
      end loop;
   end if;
   if Labour_On then
      --  planned: the band lays it.  What there is of it to lay is counted
      --  from the ground where that is in (a stretch on ground that is not
      --  in is taken on trust, and counted once it is).
      declare
         procedure Count (X, Y, Zr, Metre : Integer) is
            pragma Unreferenced (X, Y, Zr, Metre);
         begin
            Laid := Laid + 1;
         end Count;
         First : constant Positive := N_Paths + 1;
      begin
         if Stretch_In (S, Held => True) then      --  (the player's act: by the ground that is held)
            For_Path_Work (S, Count'Access);
            if Laid = 0 then
               return;                        --  nothing there to lay a path on
            end if;
         else
            Laid := Natural (L * Path_Width_M * 16.0);
         end if;
         for P in 1 .. Pieces loop
            N_Paths := N_Paths + 1;
            Path_List (N_Paths) := Line_Piece (From, To, P, Pieces);
         end loop;
         for K in First .. N_Paths loop
            Refresh_Path (K);
         end loop;
         Count_Paths;
         Path_Refused_For := Laid_Some;
      end;
      return;
   end if;
   for X in X0 .. X1 loop
      for Y in Y0 .. Y1 loop
         declare
            C : constant Vec3 := ((Float (X) + 0.5) * 0.25, (Float (Y) + 0.5) * 0.25, 0.0);
         begin
            --  (where it only brushes a zone, the zone keeps its ground)
            if Seg_Dist (C, S) <= Half and then (N_Zones = 0 or else Zone_Of_Block (X, Y) = 0) then
               declare
                  --  the height along the line here, to look for the ground near
                  T : constant Float :=
                    Float'Max (0.0, Float'Min (1.0, ((C.X - From.X) * (To.X - From.X)
                                                      + (C.Y - From.Y) * (To.Y - From.Y)) / (L * L)));
                  Zr : constant Integer := Ground_Row (X, Y, B (From.Z + (To.Z - From.Z) * T));
               begin
                  if Zr >= 0 and then Mat (X, Y, Zr) in Grass | Dirt | Sand | Gravel | Clay | Placer_Gravel | Bog_Iron
                  then
                     Write_Src (X, Y, Zr, (Mat => Footpath, State => 0));
                     Laid := Laid + 1;
                     if Mat (X, Y, Zr + 1) in Tall_Grass | Wild_Grain | Wild_Vegetables then
                        Write_Src (X, Y, Zr + 1, Air_Block);
                     end if;
                  end if;
               end;
            end if;
         end;
      end loop;
   end loop;
   if Laid > 0 then
      N_Paths := N_Paths + 1;
      Path_List (N_Paths) := (A => From, B => To, Todo => 0, Known => True);
      Path_Refused_For := Laid_Some;
   end if;
   if N_Paths > Paths_Were and then N_Housing > 0 then
      Plan_Lots;                 --  (a house fronts a path: the lots still to begin, laid out anew)
   end if;
end Lay_Path;
