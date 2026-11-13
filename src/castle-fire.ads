with Castle.Math; use Castle.Math;

--  A fire as it is seen: its flames, its sparks, its smoke, and where its
--  light comes from.  Presentation only: the colony says whether a fire
--  burns and how well, and this draws it, through Castle.Props and
--  Castle.Figures like any other prop.
--
--  The flames are many small glowing pieces, not a few large ones.  Each is
--  born on the bed, rises (slowly at first, then faster), draws in toward
--  the middle, shrinks, and cools from pale yellow through gold and orange
--  to a dull red before it is gone; the pieces born in the middle are the
--  largest, the hottest and the ones that climb highest, so the fire stands
--  as a pointed body, pale at its heart, red at its tips and its rim.  None
--  turns and none bobs in place: all that moves is the stream upward, and
--  the whole of it leaning a little on the wind and wandering, more the
--  higher up.  (The flames before were six tall boxes turning and
--  stretching where they stood.  John, 2026-11-10: "cute, but it feels
--  unnatural".)
--
--  Everything is a function of the fire's place, its heat and the drawn
--  time: nothing is kept from one frame to the next, a piece's life is
--  worked out from the time alone, and a recording repeats.
package Castle.Fire is

   --  First values.
   Flames      : constant := 72;     --  pieces of flame alive at once at full heat
   Flame_Tall  : constant := 0.62;   --  metres the middle ones climb at full heat (half that, dying)
   Flame_Size  : constant := 0.09;   --  metres across, a middle one new-born
   Bed_R       : constant := 0.17;   --  they are born within this of the middle
   Wind_Lean   : constant := 0.05;   --  metres a flame leans for each metre up, per m/s of wind
   Sparks      : constant := 10;     --  at most in the air
   Spark_Tall  : constant := 1.6;    --  metres the highest fly
   Smokes      : constant := 24;     --  puffs of smoke in the air
   Smoke_Tall  : constant := 3.5;    --  metres they rise before they are gone
   Smoke_Size  : constant := 0.10;   --  metres across at their largest
   Smoke_Drift : constant := 0.25;   --  of the wind's speed, how fast smoke goes with it
   Light_Up    : constant := 0.34;   --  metres over the bed its light comes from, dying (0.08 more at full
                                     --  heat): the lower, the longer the shadows of every step in the ground
   Light_Roam  : constant := 0.03;   --  metres its light wanders each way
   Die_Flames  : constant := 0.1;    --  of its flames, left as its dying down ends
   Die_Tall    : constant := 0.2;    --  of their height
   Die_Smoke   : constant := 0.4;    --  of its smoke

   procedure Show (Bed : Vec3; Heat, T : Float; Wind : Vec3 := (0.0, 0.0, 0.0); Dying : Float := 0.0);
   --  The fire burning at Bed (the middle of its bed, on the ground) this
   --  frame.  Heat: 0 (all but out) to 1; T: seconds of drawn time; Wind:
   --  m/s across the ground.  Dying: 0 while it has wood, and from 0 to 1
   --  as, burnt out, it dies down: fewer and lower flames, till Die_Flames
   --  of them a Die_Tall as high are left over the embers, hardly a spark,
   --  and less smoke.  After Castle.Serfs.Submit, like any prop.  Flames and
   --  sparks glow and cast no shadow; nor does the smoke, which is half seen
   --  through.

   function Light_At (Bed : Vec3; Heat, T : Float) return Vec3;
   function Light_Strength (Heat, T : Float) return Float;
   --  Where its light comes from this frame (the flames' heart, wandering
   --  a few centimetres, so the shadows it casts stir) and how strong, 0 to
   --  1 (Heat, wavering): for Castle.Render.Add_Light.

end Castle.Fire;
