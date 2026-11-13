with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Castle.Math; use Castle.Math;
with Castle.Nav;

package body Castle.Zone_Marks is

   use Castle.Colony;

   Lift_Fill : constant := 0.03;   --  over the ground, so it is not lost in it
   Lift_Edge : constant := 0.04;

   type Run_List is array (Positive range <>) of Zone_Run;

   --  R: a zone's strips, rows south to north and west to east in a row.
   procedure Show (R : Run_List; S : Style) is
      function Top (K : Positive) return Float is (Float (R (K).Z + 1) * 0.25);

      --  a line along the south (North False) or north side of strip K, block columns A .. B
      procedure Side (K : Positive; A, B : Integer; North : Boolean) is
         Y : constant Float := Float (R (K).Y + (if North then 1 else 0)) * 0.25;
      begin
         Castle.Marks.Strip ((Float (A) * 0.25, Y, Top (K) + Lift_Edge), (Float (B + 1) * 0.25, Y, Top (K) + Lift_Edge),
                             S.Edge_W, S.Edge, S.Of_Ground);
      end Side;

      --  the parts of strip K with nothing of rows From .. To beside them
      procedure Open_Sides (K : Positive; From, To : Natural; North : Boolean) is
         Cur : Integer := R (K).X0;
      begin
         for P in From .. To loop
            exit when Cur > R (K).X1;
            if R (P).X1 >= Cur and then R (P).X0 <= R (K).X1 then
               if R (P).X0 > Cur then
                  Side (K, Cur, R (P).X0 - 1, North);
               end if;
               Cur := R (P).X1 + 1;
            end if;
         end loop;
         if Cur <= R (K).X1 then
            Side (K, Cur, R (K).X1, North);
         end if;
      end Open_Sides;

      Row_0 : Positive := 1;       --  this row's strips: Row_0 .. Row_1
      Row_1 : Natural;
      Prev_0 : Positive := 1;      --  the row before's, if it is the next row south
      Prev_1 : Natural := 0;
   begin
      if S.Fill.A > 0.0 then
         for K in R'Range loop
            Castle.Marks.Strip (((Float (R (K).X0) + 0.5) * 0.25, (Float (R (K).Y) + 0.5) * 0.25, Top (K) + Lift_Fill),
                                ((Float (R (K).X1) + 0.5) * 0.25, (Float (R (K).Y) + 0.5) * 0.25, Top (K) + Lift_Fill),
                                0.25, S.Fill, S.Of_Ground);
         end loop;
      end if;
      if S.Edge.A <= 0.0 then
         return;
      end if;
      while Row_0 <= R'Last loop
         Row_1 := Row_0;
         while Row_1 < R'Last and then R (Row_1 + 1).Y = R (Row_0).Y loop
            Row_1 := Row_1 + 1;
         end loop;
         declare
            Next_0 : constant Positive := Row_1 + 1;
            Next_1 : Natural := Row_1;
            Y0     : constant Float := Float (R (Row_0).Y) * 0.25;
         begin
            if Next_0 <= R'Last and then R (Next_0).Y = R (Row_0).Y + 1 then
               Next_1 := Next_0;
               while Next_1 < R'Last and then R (Next_1 + 1).Y = R (Next_0).Y loop
                  Next_1 := Next_1 + 1;
               end loop;
            end if;
            for K in Row_0 .. Row_1 loop
               --  its ends, unless the ground goes on at another level
               if K = Row_0 or else R (K - 1).X1 + 1 /= R (K).X0 then
                  Castle.Marks.Strip ((Float (R (K).X0) * 0.25, Y0, Top (K) + Lift_Edge),
                                      (Float (R (K).X0) * 0.25, Y0 + 0.25, Top (K) + Lift_Edge), S.Edge_W, S.Edge, S.Of_Ground);
               end if;
               if K = Row_1 or else R (K + 1).X0 - 1 /= R (K).X1 then
                  Castle.Marks.Strip ((Float (R (K).X1 + 1) * 0.25, Y0, Top (K) + Lift_Edge),
                                      (Float (R (K).X1 + 1) * 0.25, Y0 + 0.25, Top (K) + Lift_Edge), S.Edge_W, S.Edge, S.Of_Ground);
               end if;
               Open_Sides (K, Prev_0, Prev_1, North => False);
               Open_Sides (K, Next_0, Next_1, North => True);
            end loop;
            --  the row after this one has it to its south only if it is the very next
            if Next_1 >= Next_0 then
               Prev_0 := Row_0;
               Prev_1 := Row_1;
            else
               Prev_0 := 1;
               Prev_1 := 0;
            end if;
         end;
         Row_0 := Row_1 + 1;
      end loop;
   end Show;

   procedure Show_Zone (Z : Positive; S : Style) is
   begin
      if Z > Zone_Count or else Zone_Runs (Z) = 0 then
         return;
      end if;
      declare
         R : Run_List (1 .. Zone_Runs (Z));
      begin
         for K in R'Range loop
            R (K) := Zone_Run_At (Z, K);
         end loop;
         Show (R, S);
      end;
   end Show_Zone;

   procedure Show_Plan (S : Style) is
      R : Run_List (1 .. Planned_Runs);
   begin
      for K in R'Range loop
         R (K) := Planned_Run_At (K);
      end loop;
      if R'Length > 0 then
         Show (R, S);
      end if;
   end Show_Plan;

   procedure Show_Paths (C : Castle.Marks.Colour := Path_Plan) is
      Half : constant Float := Path_Width_M / 2.0;
   begin
      if Paths_To_Lay = 0 then
         return;
      end if;
      for K in 1 .. Path_Count loop
         declare
            A : constant Vec3 := Path_End (K, Second => False);
            B : constant Vec3 := Path_End (K, Second => True);
            L : constant Float := Sqrt ((B.X - A.X) ** 2 + (B.Y - A.Y) ** 2);
            N : constant Natural := Natural (Float'Ceiling (L));

            --  the point D metres along it, on the ground
            function Along (D : Float) return Vec3 is
               T : constant Float := (if L > 0.0 then D / L else 0.0);
               X : constant Float := A.X + (B.X - A.X) * T;
               Y : constant Float := A.Y + (B.Y - A.Y) * T;
               Z : constant Float := Castle.Nav.Surface_Z (X, Y);
            begin
               return (X, Y, (if Z >= 0.0 then Z else A.Z + (B.Z - A.Z) * T) + Lift_Edge);
            end Along;

            M : Positive := 1;
         begin
            while M <= N loop
               if Path_Todo (K, M) then
                  declare
                     M0 : constant Positive := M;
                  begin
                     while M < N and then Path_Todo (K, M + 1) loop
                        M := M + 1;
                     end loop;
                     declare
                        D0 : constant Float := Float (M0 - 1);
                        D1 : constant Float := Float'Min (L, Float (M));
                        Mid : constant Float := (D0 + D1) / 2.0;
                     begin
                        --  (a strip's ends run on half its width: drawn that much short)
                        Castle.Marks.Strip (Along (Float'Min (Mid, D0 + Half)), Along (Float'Max (Mid, D1 - Half)),
                                            Path_Width_M, C, Of_Ground => True);
                     end;
                  end;
               end if;
               M := M + 1;
            end loop;
         end;
      end loop;
   end Show_Paths;

   procedure Show_Lot (Corner : Lot_Corners; Z : Float; C : Castle.Marks.Colour; Width : Float := 0.08) is
   begin
      for K in Corner'Range loop
         declare
            A : constant Vec3 := Corner (K);
            B : constant Vec3 := Corner (if K = Corner'Last then Corner'First else K + 1);
         begin
            Castle.Marks.Strip ((A.X, A.Y, Z), (B.X, B.Y, Z), Width, C);
         end;
      end loop;
   end Show_Lot;

   procedure Show_Houses (C : Castle.Marks.Colour := House_Plan) is
   begin
      for H in 1 .. House_Count loop
         declare
            V : constant House_View := House_At (H);
            Z : constant Float := V.Corner (1).Z + Lift_Edge;
         begin
            if V.Phase /= Standing then
               Show_Lot (V.Corner, Z, C, 0.1);
               --  its door: a short line out from the front wall
               declare
                  --  the way in: from its front wall toward its back
                  Dx : constant Float := V.Corner (4).X - V.Corner (1).X;
                  Dy : constant Float := V.Corner (4).Y - V.Corner (1).Y;
                  L  : constant Float := Float'Max (0.01, Sqrt (Dx * Dx + Dy * Dy));
               begin
                  Castle.Marks.Strip ((V.Door.X, V.Door.Y, Z),
                                      (V.Door.X + 0.75 * Dx / L, V.Door.Y + 0.75 * Dy / L, Z),
                                      1.0, (C.R, C.G, C.B, C.A * 0.5), True);
               end;
            end if;
         end;
      end loop;
   end Show_Houses;

end Castle.Zone_Marks;
