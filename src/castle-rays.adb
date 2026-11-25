with Castle.Dims; use Castle.Dims;
with Castle.Cutaway;

package body Castle.Rays is

   function Pickable (M : Material) return Boolean is
     (Class_Of (M) = Solid or else M in Crown | Berry_Bush | Bare_Bush);

   function Stops (M : Material; X, Y, Z : Integer) return Boolean is
      Px : constant Float := (Float (X) + 0.5) / Float (Blocks_Per_Meter);
      Py : constant Float := (Float (Y) + 0.5) / Float (Blocks_Per_Meter);
      Pz : constant Float := (Float (Z) + 0.5) / Float (Blocks_Per_Meter);
   begin
      if not Pickable (M) then
         return False;
      elsif Castle.Cutaway.Count = 0 then
         return True;
      elsif M = Thatch then
         return Castle.Cutaway.Cover_At (Px, Py, Pz) >= 0.5;
      else
         --  (a cleared wall, by its place: whatever it is made of; and a roof's timber with its roof)
         return Class_Of (M) /= Solid
           or else (Castle.Cutaway.Wall_Cover_At (Px, Py, Pz) >= 0.5
                    and then (M /= Log or else Castle.Cutaway.Timber_Cover_At (Px, Py, Pz) >= 0.5));
      end if;
   end Stops;

   function Walk (From, Dir : Vec3; Max_M : Float) return Hit is
      Inf : constant Float := 1.0E30;
      P   : Vec3 := From * Float (Blocks_Per_Meter);
      T0  : Float := 0.0;
      R   : Hit;
   begin
      --  Start where the ray comes down into the world's height.
      if P.Z >= Float (Height_B) then
         if Dir.Z >= 0.0 then
            return R;
         end if;
         T0 := (P.Z - Float (Height_B) + 0.01) / (-Dir.Z);
         P := P + Dir * T0;
      end if;
      declare
         X  : Integer := Integer (Float'Floor (P.X));
         Y  : Integer := Integer (Float'Floor (P.Y));
         Z  : Integer := Integer (Float'Floor (P.Z));
         Sx : constant Integer := (if Dir.X > 0.0 then 1 else -1);
         Sy : constant Integer := (if Dir.Y > 0.0 then 1 else -1);
         Sz : constant Integer := (if Dir.Z > 0.0 then 1 else -1);
         Dx : constant Float := (if Dir.X /= 0.0 then abs (1.0 / Dir.X) else Inf);
         Dy : constant Float := (if Dir.Y /= 0.0 then abs (1.0 / Dir.Y) else Inf);
         Dz : constant Float := (if Dir.Z /= 0.0 then abs (1.0 / Dir.Z) else Inf);
         Tx : Float := (if Dir.X /= 0.0 then (Float (X) + (if Sx > 0 then 1.0 else 0.0) - P.X) / Dir.X else Inf);
         Ty : Float := (if Dir.Y /= 0.0 then (Float (Y) + (if Sy > 0 then 1.0 else 0.0) - P.Y) / Dir.Y else Inf);
         Tz : Float := (if Dir.Z /= 0.0 then (Float (Z) + (if Sz > 0 then 1.0 else 0.0) - P.Z) / Dir.Z else Inf);
         Limit : constant Float := Max_M * Float (Blocks_Per_Meter) - T0;
         Axis  : Integer := 2;
         T     : Float := 0.0;
      begin
         loop
            if Z < 0 or else (Z >= Height_B and then Sz > 0) or else T > Limit then
               return R;
            end if;
            if Stops (X, Y, Z) then
               R := (Found => True, X => X, Y => Y, Z => Z,
                     Nx => (if Axis = 0 then -Sx else 0),
                     Ny => (if Axis = 1 then -Sy else 0),
                     Nz => (if Axis = 2 then -Sz else 0),
                     Dist => (T0 + T) / Float (Blocks_Per_Meter));
               return R;
            end if;
            if Tx < Ty and then Tx < Tz then
               X := X + Sx; T := Tx; Tx := Tx + Dx; Axis := 0;
            elsif Ty < Tz then
               Y := Y + Sy; T := Ty; Ty := Ty + Dy; Axis := 1;
            else
               Z := Z + Sz; T := Tz; Tz := Tz + Dz; Axis := 2;
            end if;
         end loop;
      end;
   end Walk;

end Castle.Rays;
