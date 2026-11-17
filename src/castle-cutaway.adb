with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;

package body Castle.Cutaway is

   Way      : View := Dynamic;
   Last_Eye : Vec3 := (0.0, 0.0, 0.0);        --  where the eye was at the last Follow (which walls face it)
   type Cleared_Array is array (1 .. Max_Roofs) of Cleared;
   State   : Cleared_Array;
   N       : Natural := 0;

   function Of_Corners (Id : Positive; Front_Left, Front_Right, Back_Right, Back_Left : Vec3;
                        Top_Z : Float) return Roof
   is
      A  : constant Vec3 := (Front_Right.X - Front_Left.X, Front_Right.Y - Front_Left.Y, 0.0);
      B  : constant Vec3 := (Back_Left.X - Front_Left.X, Back_Left.Y - Front_Left.Y, 0.0);
      La : constant Float := Sqrt (A.X * A.X + A.Y * A.Y);
      Lb : constant Float := Sqrt (B.X * B.X + B.Y * B.Y);
   begin
      return (Id     => Id,
              Centre => ((Front_Left.X + Front_Right.X + Back_Right.X + Back_Left.X) / 4.0,
                         (Front_Left.Y + Front_Right.Y + Back_Right.Y + Back_Left.Y) / 4.0,
                         Float'Min (Float'Min (Front_Left.Z, Front_Right.Z), Float'Min (Back_Right.Z, Back_Left.Z))),
              Along  => (if La > 1.0e-4 then (A.X / La, A.Y / La, 0.0) else (1.0, 0.0, 0.0)),
              Half_A => La / 2.0,
              Half_B => Lb / 2.0,
              Top_Z  => Top_Z);
   end Of_Corners;

   --  P in R's own frame: along its walls, across them, up.
   function Local (R : Roof; P : Vec3) return Vec3 is
     ((P.X - R.Centre.X) * R.Along.X + (P.Y - R.Centre.Y) * R.Along.Y,
      (P.Y - R.Centre.Y) * R.Along.X - (P.X - R.Centre.X) * R.Along.Y,
      P.Z);

   --  A point of R's own frame is in its house: within its walls and eaves,
   --  from just under its floor to its roof's slopes and a little over.
   Over_M : constant := 0.5;

   function Under_Roof (R : Roof; P : Vec3) return Boolean is
      Across : constant Float := (if R.Half_A >= R.Half_B then abs P.Y else abs P.X);   --  from under the ridge
   begin
      return abs P.X <= R.Half_A + Eave_M and then abs P.Y <= R.Half_B + Eave_M
        and then P.Z >= R.Centre.Z - 0.5 and then P.Z <= R.Top_Z - Across + Over_M;
   end Under_Roof;

   function Crosses (From, To : Vec3; R : Roof) return Boolean is
      P  : constant Vec3 := Local (R, From);
      Q  : constant Vec3 := Local (R, To);
      Lo : constant Vec3 := (-(R.Half_A + Eave_M), -(R.Half_B + Eave_M), R.Centre.Z - 0.5);
      Hi : constant Vec3 := (R.Half_A + Eave_M, R.Half_B + Eave_M, R.Top_Z + Over_M);
      T0 : Float := 0.0;
      T1 : Float := 1.0;

      --  The part of the line within the slab Lo .. Hi of one axis.
      procedure Slab (A, B, L, H : Float) is
         D : constant Float := B - A;
      begin
         if abs D < 1.0e-6 then
            if A < L or else A > H then
               T0 := 2.0;                     --  never in it
            end if;
         else
            declare
               U : constant Float := (L - A) / D;
               V : constant Float := (H - A) / D;
            begin
               T0 := Float'Max (T0, Float'Min (U, V));
               T1 := Float'Min (T1, Float'Max (U, V));
            end;
         end if;
      end Slab;
   begin
      Slab (P.X, Q.X, Lo.X, Hi.X);
      Slab (P.Y, Q.Y, Lo.Y, Hi.Y);
      Slab (P.Z, Q.Z, Lo.Z, Hi.Z);
      if T0 > T1 then
         return False;                        --  not even through the box round it
      end if;
      --  within the box, a point every quarter metre or so: under the slopes?
      declare
         D   : constant Vec3 := Q - P;
         Len : constant Float := Sqrt (D.X * D.X + D.Y * D.Y + D.Z * D.Z) * (T1 - T0);
         N   : constant Positive := Integer'Min (200, 1 + Integer (Float'Ceiling (Len / 0.25)));
      begin
         for K in 0 .. N loop
            if Under_Roof (R, P + D * (T0 + (T1 - T0) * Float (K) / Float (N))) then
               return True;
            end if;
         end loop;
      end;
      return False;
   end Crosses;

   procedure Follow (Eye, Focus : Vec3; Roofs : Roof_List; Dt : Float;
                     Pointing : Boolean := False; Pointed : Vec3 := (0.0, 0.0, 0.0)) is
      Step : constant Float := (if Dt > 0.0 then Dt / Fade_S else 0.0);
      D    : constant Vec3 := Focus - Eye;
      L    : constant Float := Sqrt (D.X * D.X + D.Y * D.Y + D.Z * D.Z);
      To   : constant Vec3 := (if L > 1.0e-4 then Focus + D * (Past_M / L) else Focus);
      Kept : Cleared_Array;
      M    : Natural := 0;

      function On_Line (R : Roof) return Boolean is
        (case Way is
            when None    => False,
            when Full    => True,
            when Dynamic => (L > 1.0e-4 and then Crosses (Eye, To, R))
                            or else (Pointing and then Crosses (Eye, Pointed, R)));
   begin
      Last_Eye := Eye;
      --  those already clearing, or coming back: by the roofs offered now
      for K in 1 .. N loop
         for R of Roofs loop
            if R.Id = State (K).R.Id then
               declare
                  A0 : constant Float :=
                    (if On_Line (R) then State (K).Amount + Step else State (K).Amount - Step);
                  A  : constant Float :=                --  (whole steps come out whole)
                    (if A0 > 1.0 - 1.0e-4 then 1.0 elsif A0 < 1.0e-4 then 0.0 else A0);
               begin
                  if A > 0.0 then
                     M := M + 1;
                     Kept (M) := (R => R, Amount => A);
                  end if;
               end;
               exit;
            end if;
         end loop;
      end loop;
      --  and those the line has come to
      for R of Roofs loop
         exit when M = Max_Roofs;
         if Step > 0.0 and then On_Line (R)
           and then (for all K in 1 .. M => Kept (K).R.Id /= R.Id)
         then
            M := M + 1;
            Kept (M) := (R => R, Amount => Float'Min (1.0, Step));
         end if;
      end loop;
      State (1 .. M) := Kept (1 .. M);
      N := M;
   end Follow;

   procedure Clear is
   begin
      N := 0;
   end Clear;

   procedure Set_View (V : View) is
   begin
      Way := V;
   end Set_View;

   function Viewing return View is (Way);

   function Count return Natural is (N);
   function Shown (K : Positive) return Cleared is (State (K));

   function Cover (C : Cleared; X, Y, Z : Float) return Float is
      P : constant Vec3 := Local (C.R, (X, Y, Z));
      A : constant Float := abs P.X;
      B : constant Float := abs P.Y;
   begin
      if A > C.R.Half_A + Eave_M or else B > C.R.Half_B + Eave_M
        or else Z < C.R.Centre.Z or else Z > C.R.Top_Z + 0.5
      then
         return 1.0;
      end if;
      declare
         T : constant Float := Float'Max (0.0, Float'Min (1.0, Float'Min (C.R.Half_A - A, C.R.Half_B - B) / Taper_M));
         R : constant Float := Edge_Cover * (1.0 - T * T * (3.0 - 2.0 * T));
      begin
         return 1.0 - C.Amount * (1.0 - R);
      end;
   end Cover;

   function Cover_At (X, Y, Z : Float) return Float is
      C : Float := 1.0;
   begin
      for K in 1 .. N loop
         C := Float'Min (C, Cover (State (K), X, Y, Z));
      end loop;
      return C;
   end Cover_At;

   function Wall_Cover (C : Cleared; Eye : Vec3; X, Y, Z : Float) return Float is
      P    : constant Vec3 := Local (C.R, (X, Y, Z));
      In_A : constant Float := C.R.Half_A - abs P.X;       --  how far in from each pair of walls
      In_B : constant Float := C.R.Half_B - abs P.Y;
   begin
      if In_A < -0.02 or else In_B < -0.02 or else Float'Min (In_A, In_B) > Wall_M
        or else Z < C.R.Centre.Z + 0.03 or else Z > C.R.Top_Z + 0.5
      then
         return 1.0;                                       --  not of its walls
      end if;
      declare
         --  the wall it is of, by its outward side (level, the world's)
         Sa : constant Float := (if P.X < 0.0 then -1.0 else 1.0);
         Sb : constant Float := (if P.Y < 0.0 then -1.0 else 1.0);
         Nx : constant Float := (if In_A < In_B then Sa * C.R.Along.X else -Sb * C.R.Along.Y);
         Ny : constant Float := (if In_A < In_B then Sa * C.R.Along.Y else Sb * C.R.Along.X);
         Ex : constant Float := Eye.X - X;
         Ey : constant Float := Eye.Y - Y;
         Facing : constant Float := (Nx * Ex + Ny * Ey) / Float'Max (Sqrt (Ex * Ex + Ey * Ey), 0.5);
         T  : constant Float := Float'Max (0.0, Float'Min (1.0, (Facing - Face_Lo) / (Face_Hi - Face_Lo)));
      begin
         return 1.0 - C.Amount * (T * T * (3.0 - 2.0 * T));
      end;
   end Wall_Cover;

   function Wall_Cover_At (X, Y, Z : Float) return Float is
      C : Float := 1.0;
   begin
      for K in 1 .. N loop
         C := Float'Min (C, Wall_Cover (State (K), Last_Eye, X, Y, Z));
      end loop;
      return C;
   end Wall_Cover_At;

   function Eye_Now return Vec3 is (Last_Eye);

end Castle.Cutaway;
