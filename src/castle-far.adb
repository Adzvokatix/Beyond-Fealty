with Castle.Blocks;  use Castle.Blocks;
with Castle.Fields;  use Castle.Fields;
with Castle.Flora;
with Castle.Geology;

package body Castle.Far is

   use Interfaces;

   --  The map's metres a corner at metre X looks at, along one axis: those
   --  the block columns of the cells either side of it are made from (a
   --  column's height is read between the metre its middle is in and the
   --  one before or after: Castle.Fields.Sample).
   Reach_Lo : constant := Cell_M + 1;
   Reach_Hi : constant := Cell_M;

   function Corner_Z (W : World; I, J : Integer) return Float is
      Xc : constant Integer := I * Cell_M;
      Yc : constant Integer := J * Cell_M;
      Z  : Float := Float'Last;
   begin
      for Y in Integer'Max (0, Yc - Reach_Lo) .. Integer'Min (Castle.Dims.Size_M - 1, Yc + Reach_Hi) loop
         for X in Integer'Max (0, Xc - Reach_Lo) .. Integer'Min (Castle.Dims.Size_M - 1, Xc + Reach_Hi) loop
            Z := Float'Min (Z, Float'Max (W.Height (Idx (X, Y)), W.Water (Idx (X, Y))));
         end loop;
      end loop;
      return Z - Sink_M;
   end Corner_Z;

   function Sheet_Z (W : World; Xm, Ym : Float) return Float is
      I  : constant Integer := Integer'Max (0, Integer'Min (Cells - 1, Integer (Float'Floor (Xm / Float (Cell_M)))));
      J  : constant Integer := Integer'Max (0, Integer'Min (Cells - 1, Integer (Float'Floor (Ym / Float (Cell_M)))));
      U  : constant Float := Xm / Float (Cell_M) - Float (I);
      V  : constant Float := Ym / Float (Cell_M) - Float (J);
      Z00 : constant Float := Corner_Z (W, I, J);
      Z11 : constant Float := Corner_Z (W, I + 1, J + 1);
   begin
      if U >= V then                                   --  the triangle (0, 0), (1, 0), (1, 1)
         return Z00 + (Corner_Z (W, I + 1, J) - Z00) * U + (Z11 - Corner_Z (W, I + 1, J)) * V;
      else                                             --  and (0, 0), (1, 1), (0, 1)
         return Z00 + (Z11 - Corner_Z (W, I, J + 1)) * U + (Corner_Z (W, I, J + 1) - Z00) * V;
      end if;
   end Sheet_Z;

   function Wet (W : World; I, J : Integer) return Boolean is
   begin
      for Y in Integer'Max (0, J * Cell_M - Reach_Lo) .. Integer'Min (Castle.Dims.Size_M - 1, (J + 1) * Cell_M + Reach_Hi) loop
         for X in Integer'Max (0, I * Cell_M - Reach_Lo) .. Integer'Min (Castle.Dims.Size_M - 1, (I + 1) * Cell_M + Reach_Hi)
         loop
            if W.Water (Idx (X, Y)) > 0.0 then
               return True;
            end if;
         end loop;
      end loop;
      return False;
   end Wet;

   function Colour (Overall : Castle.Textures.Texel_Data; M : Material; C : Class) return Texel is
      At_0 : constant Natural := Overall'First + Material'Pos (M) * Castle.Textures.Variants * 4;
   begin
      return (R => Overall (At_0), G => Overall (At_0 + 1), B => Overall (At_0 + 2),
              A => Unsigned_8 (Class'Pos (C) * Class_Step));
   end Colour;

   function Crown_Of (Overall : Castle.Textures.Texel_Data; C : Class) return Texel is
     (Colour (Overall,
              (case C is
                  when Aspen   => Aspen_Leaves,
                  when Conifer => Pine_Needles,
                  when others  => Leaves),
              C));

   function Cell_Of (W : World; Overall : Castle.Textures.Texel_Data; I, J : Integer) return Texel is
      Bx  : constant Integer := I * Castle.Flora.Tree_Cell + Castle.Flora.Tree_Cell / 2;
      By  : constant Integer := J * Castle.Flora.Tree_Cell + Castle.Flora.Tree_Cell / 2;
      Col : constant Castle.Geology.Column := Castle.Geology.Prepare_Column (W, Bx, By);
      T   : constant Castle.Flora.Tree := Castle.Flora.Tree_At (W, I, J);
      M   : constant Material := Castle.Geology.Top_Material (W, Col, Bx, By);
      R   : Texel;
   begin
      if Col.Water_Top > Col.Solid then
         R := Colour (Overall, M, Open_Water);            --  (its bed's colour: the water's own is the renderer's)
         R.A := R.A + Wet_Step;
         return R;
      elsif T.Valid then
         R := Colour (Overall, M,
                      (case T.Kind is
                          when Castle.Flora.Broadleaf | Castle.Flora.Apple => Broadleaf,
                          when Castle.Flora.Aspen                         => Aspen,
                          when Castle.Flora.Spruce | Castle.Flora.Pine    => Conifer));
      else
         R := Colour (Overall, M, (if M = Grass then Turf else Bare));
      end if;
      if Wet (W, I, J) then
         R.A := R.A + Wet_Step;
      end if;
      return R;
   end Cell_Of;

   procedure Build (W : World; Overall : Castle.Textures.Texel_Data; Z : out Height_Grid; C : out Texel_Grid) is
   begin
      for J in Z'Range (1) loop
         for I in Z'Range (2) loop
            Z (J, I) := IEEE_Float_32 (Corner_Z (W, I, J));
         end loop;
      end loop;
      for J in C'Range (1) loop
         for I in C'Range (2) loop
            C (J, I) := Cell_Of (W, Overall, I, J);
         end loop;
      end loop;
   end Build;

end Castle.Far;
