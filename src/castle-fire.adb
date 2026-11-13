with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Castle.Figures;
with Castle.Hash;
with Castle.Props;

package body Castle.Fire is

   Pi : constant := Ada.Numerics.Pi;

   --  A number in 0 .. 1 that is piece I's own: its Kth, of the life Life
   --  (0: the same in every life).
   function Own (I, K : Natural; Life : Integer := 0) return Float is
     (Castle.Hash.Unit_3 (16#F1AE#, I, K, Life));

   --  Smooth noise along X, -1 .. 1: a value at each whole number, eased
   --  from one to the next.
   function Wander (X : Float; Channel : Integer) return Float is
      F : constant Float := Float'Floor (X);
      I : constant Integer := Integer (F);
      T : constant Float := X - F;
      S : constant Float := T * T * (3.0 - 2.0 * T);
      A : constant Float := Castle.Hash.Unit_2 (16#F1AF#, I, Channel);
      B : constant Float := Castle.Hash.Unit_2 (16#F1AF#, I + 1, Channel);
   begin
      return 2.0 * (A + (B - A) * S) - 1.0;
   end Wander;

   function Clamp_01 (X : Float) return Float is (Float'Max (0.0, Float'Min (1.0, X)));

   --  Which life piece I is in at time T, living Span seconds each, and how
   --  far through it (0 born .. 1 gone).  Start staggers the pieces.
   procedure Life_Of (T, Span, Start : Float; Life : out Integer; Age : out Float) is
      Phase : constant Float := T / Span + Start;
   begin
      Life := Integer (Float'Floor (Phase));
      Age := Phase - Float'Floor (Phase);
   end Life_Of;

   procedure Show (Bed : Vec3; Heat, T : Float; Wind : Vec3 := (0.0, 0.0, 0.0); Dying : Float := 0.0) is
      H     : constant Float := Clamp_01 (Heat);
      D     : constant Float := Clamp_01 (Dying);
      Tall  : constant Float := Flame_Tall * (0.5 + 0.5 * H) * (1.0 - (1.0 - Die_Tall) * D);
      Alive : constant Natural := Natural (Float (Flames) * (0.55 + 0.45 * H) * (1.0 - (1.0 - Die_Flames) * D));
      --  the wind, no stronger than a stiff breeze (a gale would lay the fire flat)
      Blow  : constant Float := Sqrt (Wind.X * Wind.X + Wind.Y * Wind.Y);
      Air   : constant Vec3 := (if Blow > 8.0 then Wind * (8.0 / Blow) else Wind);

      --  Where the whole fire stands off its bed's middle at height Z: it
      --  wanders, more the higher up, and leans with the wind.
      function Sway (Z : Float) return Vec3 is
         K : constant Float := Float'Min (1.2, Z / Flame_Tall);
         A : constant Float := 0.10 * K * Sqrt (K);
      begin
         return (A * Wander (1.6 * T + 2.2 * Z, 1) + Wind_Lean * Air.X * Z,
                 A * Wander (1.9 * T + 2.6 * Z, 2) + Wind_Lean * Air.Y * Z, 0.0);
      end Sway;

      --  One piece, Size metres across and Tall_By times as tall, its middle at P.
      procedure Piece (L : Castle.Figures.Look_Id; P : Vec3; Size : Float; Tall_By : Float := 1.0) is
      begin
         Castle.Props.Put_Scaled (L, P - (0.0, 0.0, 0.5 * Size * Tall_By), 0.0,
                                  Size / Castle.Props.Bit_M, Tall_By * Size / Castle.Props.Bit_M, 0.0);
      end Piece;
   begin
      --  The flames.
      for I in 0 .. Alive - 1 loop
         declare
            Life : Integer;
            Age  : Float;
         begin
            Life_Of (T, 0.42 + 0.38 * Own (I, 0), Own (I, 1), Life, Age);
            declare
               Out_R : constant Float := Sqrt (Own (I, 2, Life));         --  0 the middle .. 1 the rim
               Ang   : constant Float := 2.0 * Pi * Own (I, 3, Life);
               Mid   : constant Float := 1.0 - Out_R;
               Top   : constant Float := Tall * (0.35 + 0.65 * Mid) * (0.75 + 0.5 * Own (I, 4, Life));
               Z     : constant Float := Top * (0.3 * Age + 0.7 * Age * Age);
               R     : constant Float := Bed_R * (0.55 + 0.45 * H) * Out_R * (1.0 - 0.8 * Age);
               Size  : constant Float :=
                 Flame_Size * (0.55 + 0.45 * Mid) * (0.7 + 0.6 * Own (I, 5, Life)) * Sqrt (1.0 - Age);
               Warm  : constant Float := (1.0 - Age) * (0.5 + 0.5 * Mid);
            begin
               if Size > 0.012 then
                  Piece (Castle.Props.Flame_Bit ((if Warm > 0.68 then 1 elsif Warm > 0.52 then 2
                                                  elsif Warm > 0.34 then 3 elsif Warm > 0.17 then 4 else 5)),
                         Bed + (R * Cos (Ang), R * Sin (Ang), 0.06 + Z) + Sway (Z), Size, Tall_By => 1.3);
               end if;
            end;
         end;
      end loop;

      --  Sparks: now and then one flies up out of the fire, slowing, and winks out.
      for I in 0 .. Sparks - 1 loop
         declare
            Span : constant Float := 1.0 + 0.9 * Own (I, 10);
            Life : Integer;
            Age  : Float;
         begin
            Life_Of (T, Span, Own (I, 11), Life, Age);
            declare
               Ang  : constant Float := 2.0 * Pi * Own (I, 12, Life);
               Away : constant Float := 0.06 + (0.10 + 0.45 * Own (I, 13, Life)) * Age;
               Top  : constant Float := Spark_Tall * (0.45 + 0.55 * Own (I, 14, Life)) * (0.6 + 0.4 * H);
               Z    : constant Float := 0.15 + Top * (1.0 - (1.0 - Age) * (1.0 - Age));
               Size : constant Float := 0.03 * (1.0 - Age * Age);
            begin
               if Own (I, 15, Life) < (0.3 + 0.4 * H) * (1.0 - D) and then Size > 0.008 then
                  Piece (Castle.Props.Flame_Bit ((if Age < 0.5 then 2 elsif Age < 0.8 then 3 else 4)),
                         Bed + (Away * Cos (Ang), Away * Sin (Ang), Z) + Sway (Z) * 0.5
                         + Air * (0.6 * Smoke_Drift * Age * Span), Size);
               end if;
            end;
         end;
      end loop;

      --  Smoke: puffs that rise off the flames' top, swell, spread, go with the wind and thin away.
      for I in 0 .. Natural (Float (Smokes) * (0.6 + 0.4 * H) * (1.0 - (1.0 - Die_Smoke) * D)) - 1 loop
         declare
            Span : constant Float := 3.2 + 2.2 * Own (I, 20);
            Life : Integer;
            Age  : Float;
         begin
            Life_Of (T, Span, Own (I, 21), Life, Age);
            declare
               Ang  : constant Float := 2.0 * Pi * Own (I, 22, Life);
               Away : constant Float := 0.03 + 0.22 * Age * Own (I, 23, Life);
               Z    : constant Float := 0.75 * Tall + Smoke_Tall * Age ** 0.85;
               Size : constant Float := Smoke_Size * (0.6 + 0.8 * Own (I, 24, Life)) * Sin (Pi * Age ** 0.6);
               Roam : constant Vec3 := (0.20 * Age * Wander (0.35 * T + Float (I), 3),
                                        0.20 * Age * Wander (0.35 * T + Float (I), 4), 0.0);
            begin
               if Size > 0.015 then
                  Piece (Castle.Props.Smoke_Bit ((if Age < 0.3 then 1 elsif Age < 0.65 then 2 else 3)),
                         Bed + (Away * Cos (Ang), Away * Sin (Ang), Z) + Sway (Tall) + Roam
                         + Air * (Smoke_Drift * Age * Span), Size);
               end if;
            end;
         end;
      end loop;
   end Show;

   function Light_At (Bed : Vec3; Heat, T : Float) return Vec3 is
     (Bed + (Light_Roam * Wander (2.3 * T, 5), Light_Roam * Wander (2.7 * T, 6),
             Light_Up + 0.08 * Clamp_01 (Heat) + 0.02 * Wander (3.1 * T, 7)));

   function Light_Strength (Heat, T : Float) return Float is
     (Clamp_01 (Heat) * (0.86 + 0.09 * Wander (5.0 * T, 8) + 0.05 * Wander (13.0 * T, 9)));

end Castle.Fire;
