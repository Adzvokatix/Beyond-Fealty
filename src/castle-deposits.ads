with Castle.Blocks; use Castle.Blocks;
with Castle.Maps;   use Castle.Maps;

--  Every common deposit shows at the surface.
--    Coal, iron and salt veins: a tree of tapering tubes, like the roots of
--      a tree.  The trunk breaks the surface in a small outcrop a few metres
--      across, with loose ore scattered round its mouth, and dives into the
--      hill; along the way it snakes and splits into thinner branches that
--      die out deeper and farther in.  A mine starts at the outcrop and
--      follows the vein down.
--    Bog iron: rust-speckled turf over a limonite layer 0.5 m down.
--
--  Gold and silver sit in the deep tips of some veins: only branch ends at
--  least Min_Precious_Reach_M of vein in from the outcrop and with at least
--  Min_Precious_Cover_M of ground over them, so they are never in reach at
--  the start of a game.  How deep they lie decides whether the mine needs
--  shoring (Castle.Geology.Needs_Shoring).
package Castle.Deposits is

   type Precious_Odds is record
      Silver_Chance, Gold_Chance : Float;   --  chance that a vein carries the metal
      Silver_Share,  Gold_Share  : Float;   --  share of a rich tip's ore
   end record;

   Precious : constant array (Deposit_Kind range Coal_Vein .. Salt_Vein) of Precious_Odds :=
     (Coal_Vein => (0.35, 0.12, 0.45, 0.20),
      Iron_Vein => (0.60, 0.30, 0.55, 0.30),
      Salt_Vein => (0.25, 0.08, 0.40, 0.15));
   --  Tuning table.  The gold chance rises up to 2x in mountain districts.

   Min_Precious_Cover_M : constant := 5.0;
   Min_Precious_Reach_M : constant := 35.0;
   Float_Radius_M       : constant := 6.0;   --  loose ore lies this far round an outcrop

   procedure Generate (W : in out World);
   --  All deposits.  Requires terrain, geology fields and hydrology.

   procedure Build_Index (W : in out World);
   --  The deposit footprint index and the tube index.

   function Ore_Of (Kind : Deposit_Kind) return Material;

   function Touches (D : Deposit; Xm, Ym : Float) return Boolean;
   --  Whether the deposit's footprint (surface and underground) covers (Xm, Ym).

   function Float_Share (D : Deposit; Xm, Ym : Float) return Float;
   --  Veins: share of the ground at (Xm, Ym) strewn with loose ore, 0 .. 1.

   function Patch_Thickness (D : Deposit; Xm, Ym : Float) return Float;

   procedure Gather (W : World; Xm, Ym, Margin : Float; Near : out Near_Tubes);
   --  The tubes that pass within Margin of the vertical line through (Xm, Ym).

   function Inside (T : Vein_Tube; X, Y, Z : Float) return Float;
   --  How far point (X, Y, Z) lies inside tube T (m); negative outside.

   function Tube_Length (T : Vein_Tube) return Float;

   procedure Report (W : World);

end Castle.Deposits;
