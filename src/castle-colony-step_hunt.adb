separate (Castle.Colony)
procedure Step_Hunt (I : Positive) is
   M  : Member renames Band (I);
   Ok : Boolean;
begin
   case M.State is
      when Stalking =>
         if M.Prey = 0 or else not Fair_Game (M.Prey) or else Deer_Safe then
            M.Prey := 0;
            M.State := Idle;
            M.Wait := 0.5;
         elsif Castle.Herds.In_Panic (M.Prey) then
            M.State := Recovering;                --  they've bolted: let them settle
            M.Wait := 4.0;
            M.Route.N := 0;
         elsif M.Work > Stalk_Patience_S then
            --  no shot at this one in a minute and a half (behind a wall, across
            --  water): another herd's, for a while
            Remember_Failure (M, Prey_Base_Id + 500 + Castle.Herds.Herd_Of (M.Prey), Seconds => 300);
            M.Prey := 0;
            M.State := Idle;
            M.Wait := 1.0;
            M.Route.N := 0;
         else
            M.Work := M.Work + Tick_S * Vigour (M);     --  its patience, not its work: no skill in it
            declare
               Deer_P : constant Vec3 := Castle.Herds.Where (M.Prey);
               Dist   : constant Float := Flat_Dist (M.Pos, Deer_P);
            begin
               if Dist <= Shoot_M and then Clear_Shot (M.Pos, Deer_P) then
                  M.State := Aiming;
                  M.Work := 0.0;
                  M.Spot := Deer_P + (0.0, 0.0, 0.7);
                  M.Route.N := 0;
               else
                  --  plan (again) toward it every couple of seconds: it wanders
                  if M.Route.N < 2 or else M.Leg >= M.Route.N or else Tick_N >= M.Check_Tick then
                     if not Route_To (M, Stand_For (M, M.Prey), 1.0) and then M.Route.N < 2 then
                        Remember_Failure (M, Prey_Base_Id + M.Prey);
                        M.Prey := 0;
                        M.State := Idle;
                        M.Wait := 1.0;
                     end if;
                     M.Check_Tick := Tick_N + 2 * Tick_Hz;
                     M.State := (if M.Prey = 0 then Idle else Stalking);
                  end if;
                  if M.State = Stalking then
                     declare
                        Done : constant Boolean :=
                          Walk (M, Stand_For (M, M.Prey), 0.3, Scale => (if Dist <= Close_M then 0.4 else 1.0));
                     begin
                        if Done and then Dist <= Shoot_M then
                           --  in range but no clear shot from here: try nearer, in a moment
                           M.Check_Tick := Natural'Min (M.Check_Tick, Tick_N + Tick_Hz);
                        end if;
                     end;
                  end if;
               end if;
            end;
         end if;

      when Aiming =>
         if M.Prey = 0 or else not Castle.Herds.Alive (M.Prey) or else Castle.Herds.In_Panic (M.Prey) then
            M.State := Recovering;
            M.Wait := 2.0;
         else
            M.Spot := Castle.Herds.Where (M.Prey) + (0.0, 0.0, 0.7);
            M.Work := M.Work + Tick_S * Work_Rate (M, Stalking_Game);
            if M.Work >= Draw_S then
               declare
                  Deer_P : constant Vec3 := Castle.Herds.Where (M.Prey);
                  Dist   : constant Float := Flat_Dist (M.Pos, Deer_P);
               begin
                  if Dist > Shoot_M + 2.0 or else not Clear_Shot (M.Pos, Deer_P) then
                     M.State := Stalking;          --  it moved off: closer again
                     M.Check_Tick := Tick_N;
                  else
                     N_Shots := N_Shots + 1;
                     declare
                        Roll : constant Float :=
                          Castle.Hash.Unit (Castle.Hash.Hash_2 (M.Seed, N_Shots, 4_242));
                        Bow  : constant Vec3 := M.Pos + (0.0, 0.0, 1.35);
                     begin
                        if Roll < Hit_Chance_Of (I, Dist) then
                           --  a hit: the deer falls where it stood, the rest bolt
                           declare
                              Slot : Natural := 0;
                           begin
                              for K in 1 .. N_Carcasses loop
                                 if not Carcasses (K).Used then
                                    Slot := K;
                                    exit;
                                 end if;
                              end loop;
                              if Slot = 0 and then N_Carcasses < Max_Carcasses then
                                 N_Carcasses := N_Carcasses + 1;
                                 Slot := N_Carcasses;
                              end if;
                              if Slot > 0 then
                                 Carcasses (Slot) :=
                                   (Used => True, Centre => Deer_P,
                                    Turn => 2.0 * Ada.Numerics.Pi * Castle.Hash.Unit (Castle.Hash.Hash_2 (M.Seed, N_Shots, 77)),
                                    Class => Castle.Herds.Class_Of (M.Prey), Lying => True, Holder => 0, Owner => I);
                                 N_Kills := N_Kills + 1;
                              end if;
                           end;
                           New_Arrow (Bow, Deer_P + (0.0, 0.0, 0.7), Stuck => False);
                           Castle.Herds.Kill (M.Prey);
                           Castle.Herds.Scare (Deer_P, M.Pos);
                        else
                           --  a miss: into the ground past it, and the herd bolts
                           declare
                              Dx : constant Float := Deer_P.X - M.Pos.X;
                              Dy : constant Float := Deer_P.Y - M.Pos.Y;
                              L  : constant Float := Float'Max (0.01, Sqrt (Dx * Dx + Dy * Dy));
                              Past : constant Float := 1.5 + 2.0 * Roll;
                              Land : constant Vec3 := (Deer_P.X + Dx / L * Past, Deer_P.Y + Dy / L * Past, Deer_P.Z);
                              Gz : constant Float := Castle.Nav.Surface_Z (Land.X, Land.Y);
                           begin
                              New_Arrow (Bow, (Land.X, Land.Y, (if Gz >= 0.0 then Gz else Deer_P.Z)), Stuck => True);
                           end;
                           Castle.Herds.Scare (Deer_P, M.Pos);
                        end if;
                     end;
                     M.Prey := 0;
                     M.State := Recovering;
                     M.Wait := 2.0;
                  end if;
               end;
            end if;
         end if;

      when Recovering =>
         M.Wait := M.Wait - Tick_S;
         if M.Wait <= 0.0 then
            M.State := Idle;
            M.Wait := 0.0;
         end if;

      when To_Carcass =>
         Keep_Route_Good (M, Ok);
         if M.Prize = 0 or else not Carcasses (M.Prize).Used or else not Carcasses (M.Prize).Lying then
            M.Prize := 0;
            M.State := Idle;
            M.Wait := 0.5;
         elsif not Ok then
            Remember_Failure (M, Prey_Base_Id + 1_000 + M.Prize);
            M.Prize := 0;
            M.State := Idle;
            M.Wait := 1.0;
         elsif Walk (M, Carcasses (M.Prize).Centre, 0.8) then
            M.State := Lifting_Carcass;
            M.Work := 0.0;
            M.Spot := Carcasses (M.Prize).Centre;
         end if;

      when Lifting_Carcass =>
         M.Work := M.Work + Tick_S * Work_Rate (M, Handling);
         if M.Prize = 0 or else not Carcasses (M.Prize).Used then
            M.Prize := 0;
            M.State := Idle;
         elsif M.Work >= Lift_Carcass_S then
            Carcasses (M.Prize).Lying := False;
            Carcasses (M.Prize).Holder := I;
            M.Carry := Carcass;
            M.Carried := 1;
            M.State := Idle;
            M.Wait := 0.2;
         end if;

      when To_Butcher =>
         Keep_Route_Good (M, Ok);
         if not Ok then
            Unreserve_Butcher (M);
            M.State := Idle;
            M.Wait := 2.0;
         elsif Walk (M, Cells (M.Cell).Centre, 0.55, Scale => 0.7) then   --  a deer is heavy
            M.State := Butchering;
            M.Work := 0.0;
            M.Spot := Cells (M.Cell).Centre;
         end if;

      when Butchering =>
         M.Work := M.Work + Tick_S * Work_Rate (M, Butchering);
         if M.Work >= Butcher_S then
            declare
               Full : constant Positive := Meat_Of (Carcasses (M.Prize).Class);
               N    : Natural := Full;
            begin
               --  salted as it is butchered, with the salt in the stockpiles:
               --  all of it kept; with none, only what is eaten before it turns
               if Curing_On then
                  declare
                     Need : constant Natural := Salt_For (Full);
                     Got  : constant Natural := Natural'Min (Need, Free_Stock (Salt));
                  begin
                     N := Kept_Of (Full, Got);
                     Use_Salt (Got);
                     if Got >= Need then
                        N_Salted := N_Salted + 1;
                     else
                        N_Unsalted := N_Unsalted + 1;
                     end if;
                     N_Meat_Lost := N_Meat_Lost + (Full - N);
                  end;
               end if;
               Cells (M.Cell).Count := Cells (M.Cell).Count + N;
               Cells (M.Cell).Incoming := Cells (M.Cell).Incoming - Full;
               Cells (M.Cell2).Count := Cells (M.Cell2).Count + 1;
               Cells (M.Cell2).Incoming := Cells (M.Cell2).Incoming - 1;
            end;
            Carcasses (M.Prize).Used := False;
            M.Prize := 0;
            M.Cell := 0;
            M.Cell2 := 0;
            M.Carry := Nothing;
            M.Carried := 0;
            M.State := Idle;
            M.Wait := 0.5;
         end if;

      when To_Cart =>
         Keep_Route_Good (M, Ok);
         if not Ok or else not Cart_Set or else Cart_Salt_N = 0 then
            if not Ok then
               Remember_Failure (M, Cart_Id, Seconds => 120);
            end if;
            M.State := Idle;
            M.Wait := 1.0;
         elsif Walk_On (M, 0.6) then
            M.State := At_Cart;
            M.Work := 0.0;
            M.Spot := Cart_P + (0.0, 0.0, 0.9);
         end if;

      when At_Cart =>
         M.Work := M.Work + Tick_S * Work_Rate (M, Handling);
         if M.Work >= Take_S then
            declare
               N : constant Natural := Natural'Min (Carry_Limit (Salt), Cart_Salt_N);
            begin
               Cart_Salt_N := Cart_Salt_N - N;
               if N > 0 then
                  M.Carry := Salt;
                  M.Carried := N;
                  M.Use_For := For_Store;
               end if;
            end;
            M.State := Idle;
            M.Wait := 0.2;
         end if;

      when others =>
         null;
   end case;
end Step_Hunt;
