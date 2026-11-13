with Castle.Maps;

--  Headless previews and measurements of a generated world.
package Castle.Preview is

   procedure Terrain_Map (W : Castle.Maps.World; Path : String);
   --  2048 x 2048, 1 px = 1 m: the visible surface (outcrops, crusts and
   --  rust included), hillshade, water depth, trees, bushes, boulders.

   procedure Zoom_Map (W : Castle.Maps.World; Path : String);
   --  Two 256 m windows at 1 px per block: around a coal outcrop and an iron
   --  outcrop (seams with gold tails preferred).

   procedure Resource_Map (W : Castle.Maps.World; Path : String);
   --  1024 x 1024, 1 px = 2 m: outcrop bands (bright), each seam's reach
   --  underground (faint), silver tails (blue) and gold tails (yellow) under
   --  ground, bog iron.

   procedure Aquifer_Map (W : Castle.Maps.World; Path : String);
   --  1024 x 1024: the well heatmap.  Hue = yield, brightness = depth.

   procedure Sections (W : Castle.Maps.World; Path : String);
   --  Four 256 m vertical cuts at 2 px per block: straight down the dip of a
   --  coal and an iron seam (gold tails preferred; gold yellow, silver blue),
   --  the highest peak, the largest river.  The stored skin is drawn per block; the deep
   --  below it is generated on the fly for the picture (dimmed, outlined).

   procedure Survey (W : Castle.Maps.World; Samples : Positive);
   --  Generates and packs random stacks, measures time and storage,
   --  extrapolates to the whole world, prints a determinism checksum.

end Castle.Preview;
