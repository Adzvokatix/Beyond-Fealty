with Castle.Water;

--  Falling water, as it is drawn (John, 2026-11-11, of water let out of a
--  lake through a cut and down a hillside: "look at the big hole and the
--  almost linear path the water is taking down, can we make it more of a
--  arch, water rollong over itself, and second can we have the water extend
--  from the wall face so it doesn't become just streams down the wall
--  face").
--
--  The simulation moves water one column a step, so what goes over a lip
--  comes down the face under it, and it was drawn there: a film on every
--  step of a slope, a curtain flat against a wall.  Here the water that
--  leaves a column over a drop is drawn as a sheet thrown from the lip: it
--  goes out at a share of the speed the simulation has it leaving with and
--  falls as a thrown thing does, column by column, until it meets ground or
--  water.  Over a sheer drop that is an arch standing clear of the wall; down
--  a steep slope every step throws over the next few, and the sheets
--  together are one body of water standing off the slope, rolling over
--  itself as the speeds shift.
--
--  It is a drawing and nothing else: the simulated water still runs down
--  the face, column by column, as it did (water that really lands where it
--  is thrown, "reach", is in docs/systems/water.md under what is not
--  there yet, and would change how far released water runs).  Nothing here
--  is saved, and nothing the simulation or the colony does goes by it.
--
--  How the renderer has it: one more value in a column's texel of the
--  surface texture, the top of the sheet passing over that column and how
--  thick it is there (Air), drawn as a second cell over the column's own
--  water (docs/systems/rendering.md, "Falls").
package Castle.Falls is

   --  First values, his to tune.
   Throw       : constant := 1.0;
   --  The share of the lip's simulated speed that the sheet leaves with.
   --  (A cut a metre wide out of a lake has water leaving its lip at 1 to
   --  2 m/s, which thrown as it is lands a metre and a half out from a
   --  fall of 3 m.)
   Throw_Most  : constant := 3.0;
   --  m/s: no sheet leaves faster.  (Behind a head of a metre the
   --  simulation has a lip's water leaving at 5 to 6 m/s, and on a steep
   --  stair at anything up to its limit of 10: thrown as it is, that would
   --  land 5 m out from a fall of 4 m.)
   Throw_Least : constant := 0.6;
   --  m/s: none leaves slower.  The slowest fall still stands a column off
   --  the face it comes down.
   Over_Least  : constant := 0.04;   --  blocks of water over the sill (1 cm): less is a film, and keeps to the face
   Clear_Least : constant := 0.75;
   --  Blocks the lip's water must stand over what lies just beyond it:
   --  less is no fall (water running level, or down a gentle bed).
   Reach_Most  : constant := 32;     --  columns a sheet may fly (8 m)
   Gravity     : constant := 9.8;    --  m/s^2
   Sheet_Over  : constant := 2.0;    --  the sheet is this many times as thick as the water over the sill,
   Sheet_Least : constant := 0.5;    --  ... this many blocks at least
   Sheet_Most  : constant := 2.0;    --  ... and at most
   Join        : constant := 2.0;
   --  A sheet whose underside is within this many blocks of what lies under
   --  it is drawn down to it: one body of water standing off a slope, and
   --  the foot of a fall where it goes into its pool.
   Settle      : constant := 0.12;
   --  The share of each tick's flow taken into what is drawn (water on a
   --  steep slope comes in pulses: a step's speed swings between a tenth
   --  and ten times its mean from one tick to the next).

   procedure Set_Ground (Source : Castle.Water.Ground_Source);
   --  Where ground and water lie in a stack that is not simulated (the
   --  game: Castle.World_Blocks.Ground).

   procedure Set_On (On : Boolean);            --  off: no sheets (--nofalls), falls drawn as they were
   procedure Set_Throw (Share : Float);        --  in place of Throw (--throw: for tuning)

   procedure Follow;
   --  After Castle.Water.Tick: the sheets as they stand now, from the flows
   --  of every stack awake or asleep with its flow established.

   function Air (Bx, By : Integer) return Float;
   --  The sheet over a block column, as the surface texture holds it: the
   --  top of it in sixteenths of a block, times 1024, plus its thickness in
   --  sixteenths of a block.  None: 0.
   function Air_Top (Bx, By : Integer) return Float;      --  blocks from the bottom of the world; none: 0
   function Air_Bottom (Bx, By : Integer) return Float;

   function Over (CX, CY : Integer) return Boolean;
   --  A sheet stands over some column of the stack: it wants the second
   --  cells to draw one with (only such stacks are given them: a band's
   --  ground is simulated wherever it has dug, with no water near).

   function Take_Changed return Castle.Water.Stack_List;
   --  The stacks whose sheets changed in the last Follow (their texels are
   --  to be written again), once.

   function Sheets return Natural;             --  columns with a sheet over them (for reports)
   procedure Reset;

end Castle.Falls;
