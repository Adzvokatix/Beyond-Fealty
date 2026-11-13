with Interfaces;
with Castle.Blocks; use Castle.Blocks;
with Castle.Hash;

--  Procedural block textures: 5x5 RGBA texels per face, a few variants
--  per material so neighbouring blocks don't repeat.  Layer of material M,
--  variant V = Material'Pos (M) * Variants + V.
--
--  Three levels per layer, used by the shader to fade detail out as it
--  shrinks below a pixel instead of letting it alias:
--    Detail  (5 x 5)  the texels
--    Variant (2 x 2)  every texel the layer's average colour
--    Overall (1 x 1)  the material's average over all its variants
--  Averages weight colour by alpha; alpha is the layer's coverage.
package Castle.Textures is

   Size     : constant := 5;
   Variants : constant := 4;
   Layers   : constant := (Material'Pos (Material'Last) + 1) * Variants;

   type Texel_Data is array (Natural range <>) of aliased Interfaces.Unsigned_8;
   type Texel_Access is access Texel_Data;

   type Texture_Set is record
      Detail  : Texel_Access;   --  Layers * 5 * 5 * 4 bytes, row 0 = bottom of the face
      Variant : Texel_Access;   --  Layers * 2 * 2 * 4
      Overall : Texel_Access;   --  Layers * 1 * 1 * 4
   end record;

   function Generate (Seed : Castle.Hash.U64) return Texture_Set;
   procedure Free (T : in out Texture_Set);

end Castle.Textures;
