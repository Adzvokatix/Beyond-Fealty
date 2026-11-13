with Castle.Noise; use Castle.Noise;

package body Castle.Fields is

   function Idx (X, Y : Integer) return Cell_Range is
   begin
      return Y * N + X;
   end Idx;

   function Clamp_Cell (I : Integer) return Integer is
   begin
      return Integer'Max (0, Integer'Min (N - 1, I));
   end Clamp_Cell;

   function At_Cell (F : Field; X, Y : Integer) return Float is
   begin
      return F (Clamp_Cell (Y) * N + Clamp_Cell (X));
   end At_Cell;

   function Sample (F : Field; Xm, Ym : Float) return Float is
      U  : constant Float   := Xm - 0.5;
      V  : constant Float   := Ym - 0.5;
      I  : constant Integer := Floor_I (U);
      J  : constant Integer := Floor_I (V);
      Fu : constant Float   := U - Float (I);
      Fv : constant Float   := V - Float (J);
      A  : constant Float   := At_Cell (F, I, J);
      B  : constant Float   := At_Cell (F, I + 1, J);
      C  : constant Float   := At_Cell (F, I, J + 1);
      D  : constant Float   := At_Cell (F, I + 1, J + 1);
      Lo : constant Float   := A + (B - A) * Fu;
      Hi : constant Float   := C + (D - C) * Fu;
   begin
      return Lo + (Hi - Lo) * Fv;
   end Sample;

   function Sample (F : Coarse_Field; Xm, Ym : Float) return Float is
      U  : constant Float   := Xm / Float (Coarse_M) - 0.5;
      V  : constant Float   := Ym / Float (Coarse_M) - 0.5;
      I  : constant Integer := Floor_I (U);
      J  : constant Integer := Floor_I (V);
      Fu : constant Float   := U - Float (I);
      Fv : constant Float   := V - Float (J);

      function Get (X, Y : Integer) return Float is
        (F (Integer'Max (0, Integer'Min (NC - 1, Y)) * NC
            + Integer'Max (0, Integer'Min (NC - 1, X))));

      A  : constant Float := Get (I, J);
      B  : constant Float := Get (I + 1, J);
      C  : constant Float := Get (I, J + 1);
      D  : constant Float := Get (I + 1, J + 1);
      Lo : constant Float := A + (B - A) * Fu;
      Hi : constant Float := C + (D - C) * Fu;
   begin
      return Lo + (Hi - Lo) * Fv;
   end Sample;

   function New_Field (Value : Float := 0.0) return Field_Access is
      F : constant Field_Access := new Field;
   begin
      for K in F'Range loop
         F (K) := Value;
      end loop;
      return F;
   end New_Field;

   function New_Coarse (Value : Float := 0.0) return Coarse_Access is
      F : constant Coarse_Access := new Coarse_Field;
   begin
      for K in F'Range loop
         F (K) := Value;
      end loop;
      return F;
   end New_Coarse;

end Castle.Fields;
