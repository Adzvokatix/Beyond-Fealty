with Interfaces;
with Castle.Font_Data;

--  The UI's pixel font: the glyph pictures of Castle.Font_Data (drawn in
--  tools/font_glyphs.py) packed into one small single-channel atlas.
--  Proportional: each glyph is as wide as its picture, plus one column of
--  space.  Cap height 7 pixels, descenders 2, a line 11 pixels.
package Castle.Font is

   Cell_W  : constant := Castle.Font_Data.Max_W + 1;   --  6 texels a cell
   Cell_H  : constant := Castle.Font_Data.Rows + 1;    --  10
   Per_Row : constant := 16;
   Atlas_W : constant := Cell_W * Per_Row;             --  96
   Atlas_H : constant := Cell_H * 6;                   --  60
   Glyph_H : constant := Castle.Font_Data.Rows;        --  9 texels drawn per glyph
   Line_H  : constant := 11;                           --  pixels from line to line

   subtype Code is Integer range Castle.Font_Data.First .. Castle.Font_Data.Last;

   function Code_Of (C : Character) return Code;
   --  Printable ASCII as itself, the degree sign as 127, anything else '?'.

   function Width (C : Code) return Natural;     --  ink columns
   function Advance (C : Code) return Natural;   --  Width + 1 (the space: its own width)
   function Cell_X (C : Code) return Natural;    --  texel origin of its cell
   function Cell_Y (C : Code) return Natural;

   function String_Width (S : String) return Natural;
   --  Pixels at scale 1, without the trailing space of the last glyph.

   type Atlas_Pixels is array (0 .. Atlas_H - 1, 0 .. Atlas_W - 1) of Interfaces.Unsigned_8
     with Convention => C;   --  rows top first
   procedure Atlas (Pixels : out Atlas_Pixels);
   --  255 where a glyph has ink, 0 elsewhere.

end Castle.Font;
