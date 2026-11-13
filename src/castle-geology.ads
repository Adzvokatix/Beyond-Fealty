with Castle.Blocks; use Castle.Blocks;
with Castle.Maps;   use Castle.Maps;

--  The world as the game uses it:
--  * The skin: the top 2 m of ground and everything above it (water,
--    plants, trees), generated at 0.25 m.  Vein outcrops (coal, iron, salt)
--    with loose ore round them, and bog iron, show here, because every
--    common resource is visible from the surface.  Silver and gold never
--    reach the skin.
--  * The deep: everything below the skin.  Never generated up front, never
--    stored.  Deep_Brick produces any 1 m cell on demand (a well shaft, a
--    cellar, a mine following a vein into a hill) with the same result for
--    the same seed and generator version.
--  * Aquifers: not voxels.  A 2-D field of depth to water and yield answers
--    the well tooltip and the heat map; the rock looks the same wet or dry
--    (up to generator 8 water-bearing rock was its own block, Aquifer).
package Castle.Geology is

   Skin_Depth_M : constant := 2;

   --  Wild vegetables (roots and greens) grow in patches about 20 m across
   --  on moist, gentle grassland: where the patch noise is over Veg_Edge,
   --  up to Veg_Chance of the block columns in the thick of one.
   Veg_Edge   : constant := 0.2;
   Veg_Chance : constant := 0.08;

   --  Tall grass (generator 13; John, 2026-11-11: "grass can get a slight
   --  overhaul").  It stands in drifts, not evenly: a noise Grass_Drift_M
   --  metres across says how thick (nothing of a drift under Grass_Drift_Lo,
   --  its heart over Grass_Drift_Hi).  Out of a drift Grass_Thin of the
   --  block columns carry a tuft, in its heart Grass_Thick, more on moist
   --  ground and fewer on dry; and in the heart Grass_Long of the tufts
   --  stand two blocks high.  (It was 18 to 48 % of the columns everywhere,
   --  by moisture alone.)  A tuft is straw to the band, so none of the land
   --  is without.
   Grass_Drift_M  : constant := 9.0;
   Grass_Drift_Lo : constant := -0.08;
   Grass_Drift_Hi : constant := 0.30;
   Grass_Thin     : constant := 0.035;
   Grass_Thick    : constant := 0.46;
   Grass_Long     : constant := 0.30;

   procedure Generate_Coarse (W : in out World);
   --  Fold and Granite_Top.  Requires Height and Mountain.

   procedure Generate_Aquifer (W : in out World);
   --  Well yield per 1 m cell.  Requires hydrology.

   procedure Well_Info (W : World; Xm, Ym : Float; Depth_M, Yield : out Float);
   --  For the well tooltip: metres down to water, and yield 0 .. 1.

   function Gold_District (W : World; Xm, Ym : Float) return Float;
   --  Mountain-core district intensity 0 .. 1 (raises the gold-tail odds).

   Safe_Cover_M : constant array (Material) of Float :=
     (Granite => 14.0, Limestone => 9.0, Sandstone => 6.0, others => 6.0);
   Wet_Cover_M : constant := 4.0;          --  any rock bearing water
   --  Tuning table: the deepest digging (metres of ground overhead) that is
   --  safe without shoring, per host rock.  Wet rock fails first.

   function Needs_Shoring (Host : Material; Cover_M : Float; Wet : Boolean := False) return Boolean is
     (Cover_M > (if Wet then Wet_Cover_M else Safe_Cover_M (Host)));
   --  Whether a mine working here needs engineers to shore it.  Wet: the
   --  rock bears water (Water_Bearing), which fails first.

   ----------------------------------------------------------------------
   --  The skin: one 0.25 m block column
   ----------------------------------------------------------------------

   type Column is record
      Solid     : Integer  := 1;     --  blocks 0 .. Solid - 1 are ground
      Water_Top : Integer  := 0;     --  open water in Solid .. Water_Top - 1
      Soil      : Integer  := 0;     --  soil blocks at the top of the ground
      Top, Sub  : Material := Dirt;  --  surface block / soil below (Top = Air: bare rock)
      Kind      : Water_Kind := Dry;
      Bog_Lo    : Integer  := 0;     --  bog-iron blocks Bog_Lo .. Bog_Hi - 1
      Bog_Hi    : Integer  := 0;
      Vein_Mat  : Material := Air;   --  vein blocks Vein_Lo .. Vein_Hi - 1 (where a vein breaks the surface)
      Vein_Lo   : Integer  := 0;
      Vein_Hi   : Integer  := 0;
      Speckle   : Float    := 0.0;   --  share of the surface that is Speckle_Mat
      Speckle_Mat : Material := Bog_Iron;   --  rust over bog iron, loose ore round an outcrop
      Moisture  : Float    := 0.0;
      Slope     : Float    := 0.0;
      Plant     : Material := Air;
      Plant_H   : Integer  := 0;
      Near_Water : Boolean := False;   --  open water in the 3 x 3 cells round the column
   end record;

   function Surface_B (W : World; Bx, By : Integer) return Integer;
   --  Blocks 0 .. Surface_B - 1 of block column (Bx, By) are ground.

   function Water_Level (W : World; Bx, By, Floor, Rows : Integer) return Float;
   --  The generated water's level (rows) at a block column holding Rows
   --  blocks of it on Floor: the 1 m surface averaged over the wet cells
   --  round it, so it follows a river's fall smoothly.  Where that is more
   --  than a block from the water blocks' own top (falls, films over steep
   --  beds) the blocks are right; and never above them, which would lift a
   --  lip of water over the bank.  This is the level source water rests at,
   --  drawn and simulated.

   function Prepare_Column (W : World; Bx, By : Integer) return Column;
   --  Water never stands above the ground beside it: a dry column next to
   --  water held above its ground is raised (up to 1 m) to the water's
   --  surface, as the bank at the water line.

   function Skin_Material
     (W : World; C : Column; Rock : Brick; Bx, By, Bz : Integer) return Material;
   --  One block of the skin.  Rock is the brick that contains it.

   function Top_Material (W : World; C : Column; Bx, By : Integer) return Material;
   --  The visible ground block of the column (what the player sees).

   ----------------------------------------------------------------------
   --  The deep: 1 m bricks, on demand
   ----------------------------------------------------------------------


   type Brick_Column is record
      Xm, Ym    : Float := 0.0;      --  column centre (m)
      Surface_M : Float := 0.0;      --  ground at the centre (m)
      Soil_M    : Float := 0.0;
      Sub       : Material := Dirt;
      Fold      : Float := 0.0;
      Granite_M : Float := 0.0;
      WT_M      : Float := 0.0;
      Tubes     : Near_Tubes;        --  vein tubes near the column
   end record;

   function Prepare_Brick_Column (W : World; Mx, My : Integer) return Brick_Column;
   function Rock_At (W : World; BC : Brick_Column; Mz : Integer) return Brick;
   function Water_Bearing (BC : Brick_Column; Mz : Integer) return Boolean;
   --  The 1 m cell at height Mz is permeable rock below the water table.
   --  Rock of the 1 m cell Mz (0 .. Height_M - 1), ignoring the ground surface.
   function Brick_At (BC : Brick_Column; Mz : Integer; Rock : Brick) return Brick;
   --  Rock clipped by the ground: Air above it, soil in its top Soil_M.

   function Deep_Brick (W : World; Mx, My, Mz : Integer) return Brick;
   --  Any 1 m cell of the world, generated on demand.

end Castle.Geology;
