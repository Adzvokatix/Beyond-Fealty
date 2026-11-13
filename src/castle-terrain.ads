with Castle.Dims;
with Castle.Maps;

--  Stage 1: the 1 m heightmap and the mountain mask.
--    plains  ~16 m (+-1.6 m swells)
--    hills   ~24 m average inside hill districts
--    ridged mountains inside mountain districts, peaks ~160 m
--    cliff bands on steep ground in patches of hill and mountain country:
--      the slope is remapped into ledges and near-vertical risers
--  Everything is domain-warped so district edges and ridgelines meander.
package Castle.Terrain is

   Mountain_Relief_M : constant := 160.0;
   --  Ridge height added at the heart of a mountain district.  Seed 1 peaks
   --  at about this height; slopes there are 74 % median, 165 % at p90.

   Ridge_Scale_M : constant := 420.0;
   --  Ridge spacing.  Wider spacing means gentler flanks for the same relief.

   Terrain_Cap_M : constant Float := Float (Castle.Dims.Height_M) - 48.0;
   Knee_M        : constant Float := Terrain_Cap_M - 40.0;
   --  Above Knee_M heights are compressed smoothly toward Terrain_Cap_M and
   --  never reach it, so no summit is ever cut flat; the 48 m above the
   --  cap stay free for trees and towers.

   Cliff_Step_Min_M : constant := 5.0;    --  riser heights vary between these
   Cliff_Step_Max_M : constant := 14.0;
   Cliff_Strength   : constant := 0.9;    --  1.0: perfectly flat ledges

   procedure Generate (W : in out Castle.Maps.World);

end Castle.Terrain;
