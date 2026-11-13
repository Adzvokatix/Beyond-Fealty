with Interfaces; use type Interfaces.Unsigned_64;

package body Castle.Climate is

   --  cos (2 pi U) with plain arithmetic: reduce to |x| <= 0.25 turn, then
   --  a Taylor polynomial (error under 1e-5 there).  Library cos may differ
   --  in the last bit from machine to machine; this does not.
   function Cos_Turn (U : Float) return Float is
      X    : Float := U - Float'Floor (U);       --  0 .. 1
      Sign : Float := 1.0;
   begin
      if X > 0.5 then
         X := 1.0 - X;                           --  cos is even about 0.5
      end if;
      if X > 0.25 then
         X := 0.5 - X;                           --  cos (pi - a) = -cos a
         Sign := -1.0;
      end if;
      declare
         A  : constant Float := 6.283_185_3 * X;
         A2 : constant Float := A * A;
      begin
         return Sign * (1.0 - A2 / 2.0 * (1.0 - A2 / 12.0 * (1.0 - A2 / 30.0 * (1.0 - A2 / 56.0))));
      end;
   end Cos_Turn;

   function Smooth (E0, E1, X : Float) return Float is
      T : constant Float := Float'Max (0.0, Float'Min (1.0, (X - E0) / (E1 - E0)));
   begin
      return T * T * (3.0 - 2.0 * T);
   end Smooth;

   function Clamp (X, Lo, Hi : Float) return Float is (Float'Max (Lo, Float'Min (Hi, X)));

   --  Smooth value noise over time, -1 .. 1, a new random value every
   --  Period hours, eased in between.
   function Wobble (Seed : U64; T : Game_Hours; Period : Long_Float) return Float is
      X : constant Long_Float := T / Period;
      K : constant Long_Float := Long_Float'Floor (X);
      F : constant Float := Smooth (0.0, 1.0, Float (X - K));
      I : constant Integer := Integer (K);
      A : constant Float := 2.0 * Unit (Hash_2 (Seed, I, 0)) - 1.0;
      B : constant Float := 2.0 * Unit (Hash_2 (Seed, I + 1, 0)) - 1.0;
   begin
      return A + (B - A) * F;
   end Wobble;

   function Day_Of_Year (T : Game_Hours) return Float is
      D : constant Long_Float := T / 24.0;
   begin
      return Float (D - Long_Float (Days_Per_Year) * Long_Float'Floor (D / Long_Float (Days_Per_Year)));
   end Day_Of_Year;

   function Hour_Of_Day (T : Game_Hours) return Float is
     (Float (T - 24.0 * Long_Float'Floor (T / 24.0)));

   function Season_Of (Day : Float) return Season is
     (Season'Val (Integer'Min (3, Integer (Float'Floor (Day / Float (Days_Per_Season))))));

   function Day_Of_Season (Day : Float) return Positive is
     (Integer'Min (Days_Per_Season,
                   1 + Integer (Float'Floor (Day)) mod Days_Per_Season));

   --  Seasonal phase: 1 at mid-summer (day 22), -1 at mid-winter (day 52).
   function Summer (Day : Float) return Float is
     (Cos_Turn ((Day - 22.0) / Float (Days_Per_Year)));

   function Weather_At (Seed : U64; T : Game_Hours) return Weather is
      Day   : constant Float := Day_Of_Year (T);
      Hour  : constant Float := Hour_Of_Day (T);
      W     : Weather;
      Cover : Float;
      Fall  : Float;                      --  precipitation, 0 .. 1
      Snowy : Float;                      --  share of it that is snow
   begin
      W.Temperature :=
        7.0 + 14.0 * Summer (Day)                              --  the year: 21 in summer, -7 in winter
        + 4.0 * Cos_Turn ((Hour - 15.0) / 24.0)                --  the day, warmest mid-afternoon
        + 5.0 * Wobble (Seed + 1, T, 60.0)                     --  warm and cold spells
        + 2.0 * Wobble (Seed + 2, T, 14.0);
      Cover :=
        0.42 - 0.08 * Summer (Day)                             --  cloudier winters
        + 0.32 * Wobble (Seed + 3, T, 30.0)
        + 0.18 * Wobble (Seed + 4, T, 9.0);
      W.Cloud_Cover := Clamp (Cover, 0.0, 1.0);
      Fall  := Smooth (0.62, 0.92, W.Cloud_Cover);
      Snowy := 1.0 - Smooth (-0.5, 1.5, W.Temperature);
      W.Snow := Fall * Snowy;
      W.Rain := Fall * (1.0 - Snowy);
      W.Wind_X := 6.0 * Wobble (Seed + 5, T, 20.0) + 3.0 * Fall;
      W.Wind_Y := 6.0 * Wobble (Seed + 6, T, 26.0) + 1.0 * Fall;
      return W;
   end Weather_At;

   --  Latitude 47: sin and cos as constants.
   Sin_Lat : constant := 0.731_354;
   Cos_Lat : constant := 0.681_998;

   function Sun_Height (T : Game_Hours) return Float is
      Day  : constant Float := Day_Of_Year (T);
      Hour : constant Float := Hour_Of_Day (T);
      Dec  : constant Float := 0.408_407 * Summer (Day);       --  declination (rad), +-23.4 degrees
      Sd   : constant Float := Dec - Dec * Dec * Dec / 6.0;      --  sin and cos of a small angle
      Cd   : constant Float := 1.0 - Dec * Dec / 2.0 + Dec ** 4 / 24.0;
   begin
      return Sin_Lat * Sd + Cos_Lat * Cd * Cos_Turn ((Hour - 12.0) / 24.0);
   end Sun_Height;

   Step_H : constant := 0.25;

   procedure Step (S : in out State; Seed : U64) is
      W   : constant Weather := Weather_At (Seed, S.T);
      Sun : constant Float := Float'Max (0.0, Sun_Height (S.T)) * (1.0 - 0.8 * W.Cloud_Cover);
      Dt  : constant Float := Step_H;
   begin
      for L in Level loop
         declare
            Tl    : constant Float := Temperature_At (W, Level_Z (L));
            Snowy : constant Float := 1.0 - Smooth (-0.5, 1.5, Tl);
            Fall  : constant Float := W.Snow + W.Rain;             --  falling, as snow or rain up here
            Gain  : constant Float := Fall * Snowy * 0.025;        --  m/h: heavy snow lays 2.5 cm an hour
            Melt  : constant Float :=
              0.0006 * Float'Max (0.0, Tl)                          --  warm air: 14 mm a degree-day
              + (if Tl > -3.0 then 0.0015 * Sun else 0.0)           --  sun on the snow
              + 0.002 * Fall * (1.0 - Snowy);                       --  rain on the snow
         begin
            S.Snow (L) := Clamp (S.Snow (L) + (Gain - Melt) * Dt, 0.0, 2.0);
         end;
      end loop;
      if W.Temperature < -2.0 then
         S.Ice := Float'Min (1.0, S.Ice + 0.02 * (-2.0 - W.Temperature) * Dt);
      elsif W.Temperature > 0.5 then
         S.Ice := Float'Max (0.0, S.Ice - 0.04 * W.Temperature * Dt);
      end if;
      S.Wet := Clamp (S.Wet + 0.5 * W.Rain * Dt - 0.08 * (1.0 + 2.0 * Sun) * Dt, 0.0, 1.0);
      S.T := S.T + Step_H;
   end Step;

   procedure Start (S : out State; Seed : U64; T : Game_Hours) is
   begin
      S := (T => T - 30.0 * 24.0, others => <>);
      Advance (S, Seed, T);
   end Start;

   procedure Advance (S : in out State; Seed : U64; T : Game_Hours) is
   begin
      while S.T + Step_H <= T loop
         Step (S, Seed);
      end loop;
   end Advance;

   function Snow_At (S : State; Z_M : Float) return Float is
   begin
      if Z_M <= Level_Z (1) then
         return S.Snow (1);
      elsif Z_M >= Level_Z (3) then
         return S.Snow (3);
      elsif Z_M <= Level_Z (2) then
         return S.Snow (1) + (S.Snow (2) - S.Snow (1)) * (Z_M - Level_Z (1)) / (Level_Z (2) - Level_Z (1));
      else
         return S.Snow (2) + (S.Snow (3) - S.Snow (2)) * (Z_M - Level_Z (2)) / (Level_Z (3) - Level_Z (2));
      end if;
   end Snow_At;

   function Moon_Phase (T : Game_Hours) return Float is
      X : constant Long_Float := (T / 24.0 - Long_Float (Moon_Full_Day)) / Long_Float (Moon_Days) + 0.5;
   begin
      return Float (X - Long_Float'Floor (X));
   end Moon_Phase;

   function Mist (Seed : U64; T : Game_Hours; W : Weather; S : State) return Float is
      Day    : constant Float := Day_Of_Year (T);
      Hour   : constant Float := Hour_Of_Day (T);
      --  the night's course: 0 at the hour it begins to gather, 1 once it stands
      Since  : constant Float := (if Hour >= Mist_Gather_From then Hour - Mist_Gather_From
                                  else Hour + 24.0 - Mist_Gather_From);
      Span   : constant Float := Mist_Full_By + 24.0 - Mist_Gather_From;
      Gather : constant Float :=
        (if Since <= Span then Smooth (0.0, Span, Since)                 --  gathering, to the small hours
         elsif Hour < 10.0 then 1.0                                        --  standing, till mid-morning
         else 1.0 - Smooth (10.0, 14.0, Hour));                           --  what the sun has left goes by two
      Sun    : constant Float := Float'Max (0.0, Sun_Height (T)) * (1.0 - 0.7 * W.Cloud_Cover);
      Burn   : constant Float := 1.0 - Smooth (Mist_Burn_Lo, Mist_Burn_Hi, Sun);
      Speed  : constant Float := abs W.Wind_X + abs W.Wind_Y;
      Calm   : constant Float := 1.0 - Smooth (Mist_Calm, Mist_Wind, 0.7 * Speed);
      Chance : constant Float := Wobble (Seed + 7, T, 36.0);
      Damp   : constant Float :=
        Clamp (0.18 + 0.60 * Chance + 0.16 * (1.0 - abs Summer (Day)) + 0.5 * S.Wet, 0.0, 1.0);
      Fall   : constant Float := 1.0 - Smooth (0.3, 0.8, W.Rain + W.Snow);
      Frost  : constant Float := 0.35 + 0.65 * Smooth (-9.0, -1.0, W.Temperature);   --  hard frost dries the air
   begin
      return Gather * Burn * Calm * Damp * Fall * Frost;
   end Mist;

   --  Autumn (days 30-45): leaves turn from day 31, fall from day 36; the
   --  trees stand bare through winter and leaf out again in early spring.
   function Leaf_Turn (Day : Float) return Float is
     (if Day < 30.0 then 0.0 else Smooth (31.0, 38.0, Day));

   function Leaf_Fall (Day : Float) return Float is
     (if Day < 30.0 then 1.0 - Smooth (1.0, 7.0, Day)
      elsif Day < 45.0 then Smooth (36.0, 44.0, Day)
      else 1.0);

   function Grass_Dry (Day : Float) return Float is
     (if Day < 15.0 then 1.0 - Smooth (0.0, 6.0, Day)          --  greening
      elsif Day < 30.0 then 0.45 * Smooth (20.0, 30.0, Day)     --  late summer dries
      elsif Day < 45.0 then 0.45 + 0.35 * Smooth (30.0, 42.0, Day)
      else 0.8 + 0.2 * Smooth (45.0, 50.0, Day));

end Castle.Climate;
