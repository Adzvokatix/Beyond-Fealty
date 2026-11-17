with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;

package body Castle.Cloth is

   Gravity   : constant := 9.8;
   Damping   : constant := 0.985;     --  of its speed kept, each substep
   Iterations : constant := 6;        --  of the rest lengths, each substep (the body and the ground every other one)
   Substeps  : constant := 2;
   Margin    : constant := 0.025;     --  how far off a body or the ground it is kept (metres)
   Rest_Move : constant := 0.0008;    --  a step moving no point further than this is still,
   Rest_Steps : constant := 45;       --  and this many still steps on end freeze it
   Bend_Give : constant := 0.4;       --  how far a bend's rest length is held (of the way)
   Grip      : constant := 0.0;       --  of its speed along what it touches that a point keeps
   Settle_Steps : constant := 150;    --  let go, it is frozen this many steps on at the latest (five seconds drawn)

   type Grid is array (1 .. Nu, 1 .. Nv) of Vec3;
   type Flags is array (1 .. Nu, 1 .. Nv) of Boolean;

   type Sheet is record
      Used     : Boolean := False;
      P, Q     : Grid := [others => [others => (0.0, 0.0, 0.0)]];   --  now, and a step ago
      Across, Down : Float := 0.1;                                   --  rest lengths
      Held     : Boolean := False;
      Top      : Row_Points := [others => (0.0, 0.0, 0.0)];
      Still    : Natural := 0;
      Loose    : Natural := 0;        --  steps since it was let go
      Is_Frozen : Boolean := False;
      Stuck    : Flags := [others => [others => False]];   --  held where it came to rest on something (Stick)
   end record;

   Sheets : array (1 .. Max_Cloths) of Sheet;

   function New_Cloth (Width, Length : Float) return Cloth_Id is
   begin
      for K in Sheets'Range loop
         if not Sheets (K).Used then
            Sheets (K) := (Used => True, Across => Width / Float (Nu - 1), Down => Length / Float (Nv - 1), others => <>);
            return K;
         end if;
      end loop;
      return 0;
   end New_Cloth;

   procedure Free (C : in out Cloth_Id) is
   begin
      if C > 0 then
         Sheets (C).Used := False;
      end if;
      C := 0;
   end Free;

   procedure Free_All is
   begin
      for S of Sheets loop
         S.Used := False;
      end loop;
   end Free_All;

   procedure Hang (C : Cloth_Id; Top : Row_Points; Down : Vec3) is
      S : Sheet renames Sheets (C);
   begin
      for I in 1 .. Nu loop
         for J in 1 .. Nv loop
            S.P (I, J) := Top (I) + Down * (S.Down * Float (J - 1));
         end loop;
      end loop;
      S.Q := S.P;
      S.Top := Top;
      S.Held := True;
      S.Still := 0;
      S.Is_Frozen := False;
      S.Stuck := [others => [others => False]];
   end Hang;

   procedure Lay (C : Cloth_Id; Corner, Across, Down : Vec3) is
      S : Sheet renames Sheets (C);
   begin
      for I in 1 .. Nu loop
         for J in 1 .. Nv loop
            S.P (I, J) := Corner + Across * (Float (I - 1) / Float (Nu - 1)) + Down * (Float (J - 1) / Float (Nv - 1));
         end loop;
      end loop;
      S.Q := S.P;
      S.Held := False;
      S.Still := 0;
      S.Loose := 0;
      S.Is_Frozen := False;
      S.Stuck := [others => [others => False]];
   end Lay;

   procedure Pin (C : Cloth_Id; Top : Row_Points) is
   begin
      if not Sheets (C).Held then
         Sheets (C).Is_Frozen := False;
         Sheets (C).Still := 0;
      end if;
      Sheets (C).Top := Top;
      Sheets (C).Held := True;
   end Pin;

   procedure Unpin (C : Cloth_Id) is
   begin
      if Sheets (C).Held then
         Sheets (C).Held := False;
         Sheets (C).Is_Frozen := False;
         Sheets (C).Still := 0;
         Sheets (C).Loose := 0;
         Sheets (C).Stuck := [others => [others => False]];
      end if;
   end Unpin;

   function Pinned (C : Cloth_Id) return Boolean is (Sheets (C).Held);
   function Frozen (C : Cloth_Id) return Boolean is (Sheets (C).Is_Frozen);

   procedure Wake (C : Cloth_Id) is
   begin
      Sheets (C).Is_Frozen := False;
      Sheets (C).Still := 0;
      Sheets (C).Loose := 0;
   end Wake;

   function Point (C : Cloth_Id; I, J : Positive) return Vec3 is (Sheets (C).P (I, J));

   function Length_Of (V : Vec3) return Float is (Sqrt (V.X * V.X + V.Y * V.Y + V.Z * V.Z));

   procedure Step (C : Cloth_Id; Dt : Float; Over : Capsules; Ground_Z : Float; Stick : Boolean := False) is
      S : Sheet renames Sheets (C);
      H : constant Float := Float'Min (Dt, 0.05) / Float (Substeps);
      Moved : Float := 0.0;

      --  Points A and B drawn to Rest apart, each by half (a pinned point does not move).
      procedure Hold (I1, J1, I2, J2 : Positive; Rest : Float; Give : Float := 1.0) is
         D  : constant Vec3 := S.P (I2, J2) - S.P (I1, J1);
         L  : constant Float := Length_Of (D);
         P1 : constant Boolean := (S.Held and then J1 = 1) or else (Stick and then S.Stuck (I1, J1));
         P2 : constant Boolean := (S.Held and then J2 = 1) or else (Stick and then S.Stuck (I2, J2));
      begin
         if L < 1.0e-6 or else (P1 and then P2) then
            return;
         end if;
         declare
            Fix : constant Vec3 := D * (Give * (L - Rest) / L);
         begin
            if P1 then
               S.P (I2, J2) := S.P (I2, J2) - Fix;
            elsif P2 then
               S.P (I1, J1) := S.P (I1, J1) + Fix;
            else
               S.P (I1, J1) := S.P (I1, J1) + Fix * 0.5;
               S.P (I2, J2) := S.P (I2, J2) - Fix * 0.5;
            end if;
         end;
      end Hold;

      Diag : constant Float := Sqrt (S.Across * S.Across + S.Down * S.Down);
      Touching : array (1 .. Nu, 1 .. Nv) of Boolean;
   begin
      if not S.Used or else S.Is_Frozen or else H <= 0.0 then
         return;
      end if;
      Steps_Taken := Steps_Taken + 1;
      for Sub in 1 .. Substeps loop
         --  on under its own weight
         for I in 1 .. Nu loop
            for J in 1 .. Nv loop
               if S.Held and then J = 1 then
                  S.Q (I, J) := S.P (I, J);
                  S.P (I, J) := S.Top (I);
               elsif Stick and then S.Stuck (I, J) then
                  S.Q (I, J) := S.P (I, J);
               else
                  declare
                     V   : constant Vec3 := (S.P (I, J) - S.Q (I, J)) * Damping;
                     Now : constant Vec3 := S.P (I, J);
                  begin
                     S.P (I, J) := Now + V + (0.0, 0.0, -Gravity * H * H);
                     S.Q (I, J) := Now;
                  end;
               end if;
            end loop;
         end loop;
         --  held to its shape, kept out of the body it hangs on or lies over
         --  and off the ground (the rest lengths walked one way and back the
         --  other in turn, or the sheet creeps the way they are walked)
         Touching := [others => [others => False]];
         for It in 1 .. Iterations loop
            declare
               Fwd : constant Boolean := It mod 2 = 1;
            begin
               for Jj in 1 .. Nv loop
                  for Ii in 1 .. Nu - 1 loop
                     declare
                        I : constant Positive := (if Fwd then Ii else Nu - Ii);
                        J : constant Positive := (if Fwd then Jj else Nv + 1 - Jj);
                     begin
                        Hold (I, J, I + 1, J, S.Across);
                     end;
                  end loop;
               end loop;
               for Ii in 1 .. Nu loop
                  for Jj in 1 .. Nv - 1 loop
                     declare
                        I : constant Positive := (if Fwd then Ii else Nu + 1 - Ii);
                        J : constant Positive := (if Fwd then Jj else Nv - Jj);
                     begin
                        Hold (I, J, I, J + 1, S.Down);
                     end;
                  end loop;
               end loop;
               for Ii in 1 .. Nu - 1 loop
                  for Jj in 1 .. Nv - 1 loop
                     declare
                        I : constant Positive := (if Fwd then Ii else Nu - Ii);
                        J : constant Positive := (if Fwd then Jj else Nv - Jj);
                     begin
                        Hold (I, J, I + 1, J + 1, Diag, 0.6);
                        Hold (I + 1, J, I, J + 1, Diag, 0.6);
                     end;
                  end loop;
               end loop;
               for Jj in 1 .. Nv loop
                  for Ii in 1 .. Nu - 2 loop
                     declare
                        I : constant Positive := (if Fwd then Ii else Nu - 1 - Ii);
                     begin
                        Hold (I, Jj, I + 2, Jj, 2.0 * S.Across, Bend_Give);
                     end;
                  end loop;
               end loop;
               for Ii in 1 .. Nu loop
                  for Jj in 1 .. Nv - 2 loop
                     declare
                        J : constant Positive := (if Fwd then Jj else Nv - 1 - Jj);
                     begin
                        Hold (Ii, J, Ii, J + 2, 2.0 * S.Down, Bend_Give);
                     end;
                  end loop;
               end loop;
            end;
            for I in 1 .. (if It mod 2 = 0 then Nu else 0) loop
               for J in (if S.Held then 2 else 1) .. Nv loop
                  declare
                     X : Vec3 := S.P (I, J);
                  begin
                     for K of Over loop
                        declare
                           Ab : constant Vec3 := K.B - K.A;
                           L2 : constant Float := Dot (Ab, Ab);
                           T  : constant Float :=
                             (if L2 > 1.0e-8 then Float'Max (0.0, Float'Min (1.0, Dot (X - K.A, Ab) / L2)) else 0.0);
                           Cp : constant Vec3 := K.A + Ab * T;
                           D  : constant Vec3 := X - Cp;
                           Dl : constant Float := Length_Of (D);
                           R  : constant Float := K.R + Margin;
                        begin
                           if Dl < R then
                              X := (if Dl > 1.0e-5 then Cp + D * (R / Dl) else Cp + (0.0, 0.0, R));
                              Touching (I, J) := True;
                           end if;
                        end;
                     end loop;
                     if X.Z < Ground_Z + Margin then
                        X.Z := Ground_Z + Margin;
                        Touching (I, J) := True;
                     end if;
                     S.P (I, J) := X;
                  end;
               end loop;
            end loop;
         end loop;
         --  where it touches it holds (wool on wool, on the ground, does not slide);
         --  laid over something to stick, it stays where it came to rest on it
         for I in 1 .. Nu loop
            for J in 1 .. Nv loop
               if Touching (I, J) then
                  S.Q (I, J) := S.P (I, J) - (S.P (I, J) - S.Q (I, J)) * Grip;
                  if Stick then
                     S.Stuck (I, J) := True;
                  end if;
               end if;
            end loop;
         end loop;
      end loop;
      --  still enough, long enough, and nothing holding it: frozen
      for I in 1 .. Nu loop
         for J in 1 .. Nv loop
            Moved := Float'Max (Moved, Length_Of (S.P (I, J) - S.Q (I, J)));
         end loop;
      end loop;
      if not S.Held then
         S.Loose := S.Loose + 1;
      else
         S.Loose := 0;
      end if;
      if not S.Held and then (Moved < Rest_Move or else S.Loose >= Settle_Steps) then
         S.Still := S.Still + 1;
         if S.Still >= Rest_Steps or else S.Loose >= Settle_Steps then
            S.Is_Frozen := True;
            S.Q := S.P;
         end if;
      else
         S.Still := 0;
      end if;
   end Step;

end Castle.Cloth;
