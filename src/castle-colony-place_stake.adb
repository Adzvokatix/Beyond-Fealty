separate (Castle.Colony)
procedure Place_Stake (Ground : Vec3; Band_Size : Positive; Seed : U64; Post : Boolean := True;
                       As_Read : Boolean := False) is
   --  (with no post: the block column whose corner is the corner of blocks nearest, as a camp's fire has it)
   Bx  : constant Integer := (if Post then B (Ground.X) else Integer (Float'Floor (Ground.X * 4.0 + 0.5)));
   By  : constant Integer := (if Post then B (Ground.Y) else Integer (Float'Floor (Ground.Y * 4.0 + 0.5)));
   --  (As_Read: the height given is the ground's own, its top the row under it)
   Top : constant Integer := (if As_Read and then not Post then B (Ground.Z + 0.01) - 1
                              else Ground_Row (Bx, By, B (Ground.Z)));
begin
   if Stake_Set or else Top < 0 then
      return;
   end if;
   Stake_Set := True;
   Band_Seed := Seed;
   Demand (Stone) := Stone_Quota;
   Stake_At := (if Post then ((Float (Bx) + 0.5) * 0.25, (Float (By) + 0.5) * 0.25, Float (Top + 1) * 0.25)
                else (Float (Bx) * 0.25, Float (By) * 0.25, Float (Top + 1) * 0.25));
   Castle.Herds.Found (Stake_At, Castle.Hash.Derive (Seed, 9));   --  placed round it once its ground is in
   if Post then
      for Z in Top + 1 .. Top + 7 loop                       --  a post, 1.75 m
         Write_Src (Bx, By, Z, (Mat => Log, State => 0));
      end loop;
      Write_Src (Bx, By, Top + 8, (Mat => Plank, State => 0));   --  a board on top
   end if;
   for K in 1 .. Integer'Min (Band_Size, Max_Members) loop
      N_Members := N_Members + 1;
      declare
         M : Member renames Band (N_Members);
         H : constant U64 := Castle.Hash.Derive (Seed, U64 (1_000 + K));
         A : constant Float := 2.0 * Ada.Numerics.Pi * Float (K) / Float (Band_Size) + 0.3;
         R : constant Float := 2.0 + Castle.Hash.Unit (H + 7);
         P : Vec3 := (Stake_At.X + R * Cos (A), Stake_At.Y + R * Sin (A), Stake_At.Z);
         Z : Float := Castle.Nav.Surface_Z (P.X, P.Y);
      begin
         --  (founded on a square, which may be among trees: the highest floor where one of the band is to
         --  stand can be a tree's top.  The floor nearest the square's own height then, a little further
         --  out along the same way if there is none within 2 m of it where it was to stand.  With a post
         --  raised, as it always was.)
         if not Post then
            for Try in 0 .. 8 loop
               declare
                  Rt : constant Float := R + 0.5 * Float (Try);
                  Pt : constant Vec3 := (Stake_At.X + Rt * Cos (A), Stake_At.Y + Rt * Sin (A), Stake_At.Z);
                  Fl : Castle.Nav.Floor_List;
                  Fn : Natural;
                  Best : Float := Float'Last;
               begin
                  Castle.Nav.Floors_At (Integer (Float'Floor (Pt.X * 2.0)), Integer (Float'Floor (Pt.Y * 2.0)), Fn, Fl);
                  for F in 1 .. Fn loop
                     if Fl (F).Speed > 0.0
                       and then abs (Float (Fl (F).Z) * 0.25 - Stake_At.Z) < abs (Best - Stake_At.Z)
                     then
                        Best := Float (Fl (F).Z) * 0.25;
                     end if;
                  end loop;
                  if Best < Float'Last and then abs (Best - Stake_At.Z) <= 2.0 then
                     P := Pt;
                     Z := Best;
                     exit;
                  end if;
               end;
            end loop;
         end if;
         M := (others => <>);
         M.Seed := H;
         M.Elder := K = 5;                        --  one elder in the band
         M.G := Castle.Bodies.Random_Genome (H, Child => False, Elder => M.Elder);
         M.Name := Natural (Castle.Hash.Mix (H + 3) mod 20);
         M.Pos := (P.X, P.Y, (if Z >= 0.0 then Z else Stake_At.Z));
         M.Prev := M.Pos;
         M.Speed := 1.3 * (if M.Elder then 0.85 else 0.95 + 0.1 * Castle.Hash.Unit (H + 9));
         M.Wait := 1.0 + 3.0 * Castle.Hash.Unit (H + 11);
         Give_Skills (M);
      end;
   end loop;
   --  no two of the band with one name: each takes the next free one of
   --  its twenty (seven on, which goes round them all), while there is one
   for I in 2 .. N_Members loop
      for Try in 1 .. 19 loop
         exit when (for all J in 1 .. I - 1 =>
                      Band (J).G.Sex /= Band (I).G.Sex or else Band (J).Name /= Band (I).Name);
         Band (I).Name := (Band (I).Name + 7) mod 20;
      end loop;
   end loop;
   Take_Stock;      --  what the new colony asks for, from the start
end Place_Stake;
