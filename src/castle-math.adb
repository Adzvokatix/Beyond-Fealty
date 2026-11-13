with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;

package body Castle.Math is

   function Normalize (A : Vec3) return Vec3 is
      L : constant Float := Sqrt (Dot (A, A));
   begin
      return (if L > 0.0 then A * (1.0 / L) else A);
   end Normalize;

   function Heading_Of (V : Vec3; Otherwise : Float) return Float is
     (if abs V.X + abs V.Y < 1.0E-5 then Otherwise else Arctan (V.Y, V.X));

   function "*" (A, B : Mat4) return Mat4 is
      R : Mat4 := (others => 0.0);
   begin
      for Col in 0 .. 3 loop
         for Row in 0 .. 3 loop
            for K in 0 .. 3 loop
               R (Col * 4 + Row) := R (Col * 4 + Row)
                 + A (K * 4 + Row) * B (Col * 4 + K);
            end loop;
         end loop;
      end loop;
      return R;
   end "*";

   function Perspective (Fovy, Aspect, Near, Far : Float) return Mat4 is
      F : constant Float := 1.0 / Tan (Fovy / 2.0);
      M : Mat4 := (others => 0.0);
   begin
      M (0)  := F / Aspect;
      M (5)  := F;
      M (10) := (Far + Near) / (Near - Far);
      M (11) := -1.0;
      M (14) := 2.0 * Far * Near / (Near - Far);
      return M;
   end Perspective;

   function Look_Dir (Forward, Up : Vec3) return Mat4 is
      F : constant Vec3 := Normalize (Forward);
      S : constant Vec3 := Normalize (Cross (F, Up));
      U : constant Vec3 := Cross (S, F);
   begin
      return (0 => S.X, 4 => S.Y, 8  => S.Z,
              1 => U.X, 5 => U.Y, 9  => U.Z,
              2 => -F.X, 6 => -F.Y, 10 => -F.Z,
              15 => 1.0, others => 0.0);
   end Look_Dir;

   function Planes (M : Mat4) return Frustum is
      function Row (I, J : Natural) return Float is (M (J * 4 + I));
      function Combine (I : Natural; S : Float) return Plane is
        ((A => Row (3, 0) + S * Row (I, 0),
          B => Row (3, 1) + S * Row (I, 1),
          C => Row (3, 2) + S * Row (I, 2),
          D => Row (3, 3) + S * Row (I, 3)));
   begin
      return (Combine (0, 1.0), Combine (0, -1.0),
              Combine (1, 1.0), Combine (1, -1.0),
              Combine (2, 1.0), Combine (2, -1.0));
   end Planes;

   function Box_Visible (F : Frustum; Lo, Hi : Vec3) return Boolean is
   begin
      for P of F loop
         --  the box corner farthest along the plane normal
         if P.A * (if P.A >= 0.0 then Hi.X else Lo.X)
           + P.B * (if P.B >= 0.0 then Hi.Y else Lo.Y)
           + P.C * (if P.C >= 0.0 then Hi.Z else Lo.Z) + P.D < 0.0
         then
            return False;
         end if;
      end loop;
      return True;
   end Box_Visible;

end Castle.Math;
