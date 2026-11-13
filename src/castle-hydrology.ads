with Castle.Maps;

--  Stage 3: water.
--    1. Priority-Flood + FIFO depression filling (Barnes, Lehman & Mulla 2014).
--    2. D8 steepest descent on the filled surface; flats and lake beds drain
--       along the flood order, so the drainage graph is acyclic by
--       construction and every cell reaches the map edge.  Kept in W.Down.
--    3. Flow accumulation in topological order -> catchment area per cell.
--    4. Lakes where a depression is deep and wide enough, and tarns where
--       a small one is deep (a mountain hollow); shallower or smaller
--       depressions silt up into flat wet meadow instead of ponds.
--    5. Channels, ready for live water.  A stream exists where catchment
--       reaches Feed_Area; its head then climbs its main stem to Head_Area
--       (fewer feeds, running further up).  Each carries a discharge
--       (catchment x Runoff).  Its water surface, worked out upstream
--       first, sits Freeboard_M under the lowest bank ground across the
--       flow, falls at least S_Min a metre to its mouth, is graded (no
--       steeper than Grade_Max unless the ground is), and backs up to a
--       lake's level at a river mouth.  Width ~ sqrt (discharge); the bed
--       lies the flow's Manning depth below the surface.  A meander pass
--       (one smooth warp field) displaces every channel, so tributaries
--       still meet their river exactly.
--    6. Distance to water, shores, moisture, water table.
package Castle.Hydrology is

   Feed_Area      : constant Float := 60_000.0;   --  m^2 of catchment that makes a stream
   Head_Area      : constant Float := 6_000.0;    --  a stream's head climbs its main stem up to this
   Runoff         : constant Float := 6.0E-6;     --  discharge per m^2 of catchment (m/s, game scale)
   S_Min          : constant Float := 0.002;      --  least fall of a water surface per metre downstream
   Grade_Max      : constant Float := 0.04;       --  steepest fall per metre, where the ground is gentler
   Freeboard_M    : constant Float := 0.35;       --  banks stand at least this far above the water
   Roughness      : constant Float := 0.1;        --  Manning's n: rough beds run slower and deeper
   D_Min_M        : constant Float := 0.75;       --  shallowest a stream runs
   D_Min_River_M  : constant Float := 1.0;        --  shallowest a river runs
   D_Max_M        : constant Float := 4.0;
   River_Area     : constant Float := 120_000.0;  --  m^2 of catchment for a river
   Lake_Min_Depth : constant Float := 2.5;        --  shallower depressions silt up
   Lake_Min_Area  : constant := 6_000;            --  m^2; smaller depressions silt up,
   Tarn_Min_Depth : constant Float := 4.0;        --  unless they are this deep: a tarn
   Tarn_Min_Area  : constant := 500;              --  m^2; and at least this wide
   Meander_Amp    : constant Float := 12.0;       --  channel displacement in flat ground (m)
   Meander_Len    : constant Float := 110.0;      --  meander wavelength (m)
   Connect_Range_M : constant Float := 60.0;      --  a lake feeds a stream that starts this close

   procedure Generate (W : in out Castle.Maps.World; Report : Boolean := True);
   --  Requires Height.

end Castle.Hydrology;
