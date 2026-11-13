with Ada.Text_IO;   use Ada.Text_IO;
with Ada.Command_Line; use Ada.Command_Line;
with Castle.Climate; use Castle.Climate;
with Castle.Hash;
with Castle.Text;   use Castle.Text;

--  A year of weather for a seed, a line every few days: the season, the
--  day's coldest and warmest hour, how much of it rained or snowed, and
--  the snow and ice it left, and the day's mist: the most there was and
--  for how many hours there was any to speak of.  Then a count of the
--  year's misty mornings.  For tuning Castle.Climate.
--    climate_year [SEED]
procedure Climate_Year is
   Seed : constant Castle.Hash.U64 :=
     (if Argument_Count > 0 then Castle.Hash.U64'Value (Argument (1)) else 1);
   S : State;
   type Tally is array (0 .. 3) of Natural;      --  days with no mist, a little, a fair mist, a thick one
   Year_Days : array (Season) of Tally := [others => [others => 0]];
begin
   Start (S, Seed, 0.0);
   Put_Line ("day  season   low  high  rain h  snow h   snow 16 m / 70 m / 140 m   ice   mist (most, hours)");
   for Day in 0 .. 2 * Days_Per_Year - 1 loop
      declare
         Lo, Hi : Float := 0.0;
         Rain_H, Snow_H : Float := 0.0;
         Mist_Most, Mist_H : Float := 0.0;
      begin
         Lo := 99.0; Hi := -99.0;
         for Q in 0 .. 95 loop
            declare
               T : constant Game_Hours := Long_Float (Day) * 24.0 + Long_Float (Q) * 0.25;
               W : constant Weather := Weather_At (Seed, T);
            begin
               Advance (S, Seed, T);
               Lo := Float'Min (Lo, W.Temperature);
               Hi := Float'Max (Hi, W.Temperature);
               if W.Rain > 0.1 then Rain_H := Rain_H + 0.25; end if;
               if W.Snow > 0.1 then Snow_H := Snow_H + 0.25; end if;
               Mist_Most := Float'Max (Mist_Most, Mist (Seed, T, W, S));
               if Mist (Seed, T, W, S) > 0.15 then Mist_H := Mist_H + 0.25; end if;
            end;
         end loop;
         if Day >= Days_Per_Year and then Day mod 3 = 0 then        --  the second year, settled
            Put_Line (Img (Day - Days_Per_Year) & ASCII.HT & Season'Image (Season_Of (Float (Day mod Days_Per_Year)))
                      & ASCII.HT & Img (Lo, 0) & ASCII.HT & Img (Hi, 0) & ASCII.HT & Img (Rain_H, 1)
                      & ASCII.HT & Img (Snow_H, 1) & ASCII.HT & Img (S.Snow (1) * 100.0, 0) & " / "
                      & Img (S.Snow (2) * 100.0, 0) & " / " & Img (S.Snow (3) * 100.0, 0) & " cm"
                      & ASCII.HT & Img (S.Ice, 2) & ASCII.HT & Img (Mist_Most, 2) & "  " & Img (Mist_H, 1));
         end if;
         if Day >= Days_Per_Year then
            Year_Days (Season_Of (Float (Day mod Days_Per_Year))) (if Mist_Most > 0.6 then 3 elsif Mist_Most > 0.3 then 2
                                                                      elsif Mist_Most > 0.1 then 1 else 0) :=
              @ + 1;
         end if;
      end;
   end loop;
   Put_Line ("mornings by the most mist of the day: none / a little (over 0.1) / fair (over 0.3) / thick (over 0.6)");
   for Sn in Season loop
      Put_Line ("  " & Season'Image (Sn) & ":" & Year_Days (Sn) (0)'Image & " /" & Year_Days (Sn) (1)'Image & " /"
                & Year_Days (Sn) (2)'Image & " /" & Year_Days (Sn) (3)'Image);
   end loop;
end Climate_Year;
