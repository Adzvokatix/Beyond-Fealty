with Castle.Colors;

--  Minimal dependency-free PNG writer: 8-bit RGB, stored (uncompressed)
--  deflate blocks.  Files are large but open everywhere.
package Castle.PNG is

   subtype RGB is Castle.Colors.RGB;

   type Image is array (Natural range <>, Natural range <>) of RGB;
   --  (row, column); row 0 is the top of the picture.
   type Image_Access is access Image;

   procedure Write (Path : String; Img : Image);
   procedure Free (Img : in out Image_Access);

end Castle.PNG;
