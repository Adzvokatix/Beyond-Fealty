with Castle.Dims;

--  Global 2-D fields over the whole map.  Fine fields: 1 m cells (2048^2,
--  16 MB of Float each).  Coarse fields: 4 m cells for slow-varying geology.
package Castle.Fields is

   N : constant := Castle.Dims.Size_M;
   subtype Cell_Range is Natural range 0 .. N * N - 1;

   type Field is array (Cell_Range) of Float;
   type Field_Access is access Field;

   Coarse_M : constant := 4;
   NC       : constant := N / Coarse_M;
   subtype Coarse_Range is Natural range 0 .. NC * NC - 1;

   type Coarse_Field is array (Coarse_Range) of Float;
   type Coarse_Access is access Coarse_Field;

   function Idx (X, Y : Integer) return Cell_Range with Inline;
   function Clamp_Cell (I : Integer) return Integer with Inline;

   function At_Cell (F : Field; X, Y : Integer) return Float with Inline;
   --  Clamped to the map edge.

   function Sample (F : Field; Xm, Ym : Float) return Float;
   --  Bilinear; Xm, Ym in metres.  Cell (i, j) is centred on (i + 0.5, j + 0.5).

   function Sample (F : Coarse_Field; Xm, Ym : Float) return Float;

   function New_Field (Value : Float := 0.0) return Field_Access;
   function New_Coarse (Value : Float := 0.0) return Coarse_Access;

end Castle.Fields;
