with Castle.Math; use Castle.Math;

--  Roofs cleared on the camera's ray (John, 2026-11-13: "semi-transparent
--  roofs on the ray of the camera, It would be nice to have a tapering
--  transparency with full transparency in the middle and
--  semi-trasnparency along the edges wher the roof meets the walls").
--
--  A house that the line from the eye to what it looks at passes through
--  (its walls or its roof, running on a little past the focus) has its
--  roof cleared: drawn at Edge_Cover over its walls and its eaves, thinning
--  inward to nothing over Taper_M, so that its middle is open and its
--  outline stays.  It clears over Fade_S and comes back the same way when
--  the line has left the house.
--
--  And the pointer's, and all of them (John, 2026-11-13, of the first
--  build: "For the roof let's run it to the mouse and the camera, along
--  with an option to have all roofs transparent"): a house the pointer's
--  ray passes through on its way to what it lands on is cleared as well,
--  and in the view Full every roof offered is.
--
--  And the walls on the camera's side (John, 2026-11-13, asked whether
--  walls should be cut down and light let in: "Let's cut down the walls
--  in-line with the camera too, the transparency is there so the player
--  can just see through them, as far as the game is concerned the walls
--  are still there to block light ... We can have the H k toggle through,
--  dynamic transparency, full trasnparency, or no transparency."): of a
--  house whose roof is cleared, the walls whose outward side faces the eye
--  are cleared with it, whole of them (panel, timber and gable), fading
--  through edge-on by the angle; the walls beyond stand, seen from inside.
--  Three ways of it (View): where the eye and the pointer are, every house,
--  none.
--
--  Drawing and pointing only: the roof is still there (it casts its
--  shadow, it is what a sleeper is under, it is walked under), nothing of
--  this is saved and the colony knows nothing of it.  The land's shader
--  draws it by the same sums as Cover and Wall_Cover here
--  (`Castle.Render`), and the pointer's ray goes on through a roof or a
--  wall where less than half of it is drawn (`Castle.Rays.Stops`).  A wall
--  is cleared by its place (the walls' line of a cleared house, above its
--  floor), whatever it is made of: its timber is a tree's too.  Main thread
--  only.
package Castle.Cutaway is

   --  First values (his to tune):
   Edge_Cover : constant := 0.5;    --  of a cleared roof, how much is drawn where it meets its walls (and over its eaves)
   Taper_M    : constant := 1.25;   --  from its walls inward it thins to nothing over this far (metres)
   Fade_S     : constant := 0.25;   --  seconds of drawn time a roof takes to clear, or to come back
   Past_M     : constant := 1.5;    --  the line runs on past what the eye looks at this far
   Eave_M     : constant := 0.4;    --  a roof hangs out past its walls (a block of eave, and a ragged edge's reach;
                                    --  0.3 until the thatch was drawn fuller, 2026-11-19)
   Wall_M     : constant := 0.27;   --  a wall is this thick from its outer side in (a block, and a little)
   Face_Lo    : constant := 0.05;   --  a wall begins to clear when its outward side faces the eye this squarely
   Face_Hi    : constant := 0.30;   --  (the cosine, level), and is clear from here: edge-on it stands whole
   Max_Roofs  : constant := 48;     --  cleared or clearing at once: every house a colony can have
                                    --  (Castle.Colony.Max_Houses; the shader's arrays are this long)

   type Roof is record
      Id     : Positive := 1;                 --  whose (a house's number): a roof keeps its fade by it
      Centre : Vec3 := (0.0, 0.0, 0.0);       --  the middle of its walls, at its floor
      Along  : Vec3 := (1.0, 0.0, 0.0);       --  a level unit vector along one pair of its walls
      Half_A : Float := 1.0;                  --  half its walls' length along Along,
      Half_B : Float := 1.0;                  --  and across
      Top_Z  : Float := 0.0;                  --  its ridge
      Pivot  : Vec3 := (0.0, 0.0, 0.0);       --  a house drawn turned (Castle.Render.Set_Turns): about this
      Turn_C : Float := 1.0;                  --  point, by the angle of this cosine and sine (1, 0: as it
      Turn_S : Float := 0.0;                  --  stands)
   end record;
   type Roof_List is array (Positive range <>) of Roof;

   function Of_Corners (Id : Positive; Front_Left, Front_Right, Back_Right, Back_Left : Vec3;
                        Top_Z : Float; Pivot : Vec3 := (0.0, 0.0, 0.0); Radians : Float := 0.0) return Roof;
   --  A house's, from its walls' outer corners on the ground (in order round)
   --  and its ridge, where it stands.  Pivot, Radians: it is drawn turned
   --  that far about that point (the fourth step of the turned building,
   --  2026-11-19).  Everything here is then reckoned where the house
   --  stands, as the land's shader does (it clears by a block's place
   --  before its turn): the eye, what it looks at and what the pointer is on
   --  are each taken back through the house's turn first (Home), so the
   --  roof clears when the eye's line crosses the house as drawn, and the
   --  walls cleared are those that face the eye as drawn.
   function Home (R : Roof; P : Vec3) return Vec3;
   --  A point of the world as it is seen, taken back through R's turn: the
   --  point of the house as it stands that is drawn there.

   function Crosses (From, To : Vec3; R : Roof) return Boolean;
   --  The line from From to To passes through R's house: under its roof's
   --  two slopes (a ridge along its longer walls, pitched one to one from
   --  Top_Z; half a metre over them still counts), within its walls and
   --  eaves.  Not the box round it: a ray that only passes over a roof's
   --  ridge to the ground behind does not cross the house.

   procedure Follow (Eye, Focus : Vec3; Roofs : Roof_List; Dt : Float;
                     Pointing : Boolean := False; Pointed : Vec3 := (0.0, 0.0, 0.0));
   --  Every frame, with every house that has a roof: those the line from Eye
   --  through Focus (and Past_M on) crosses clear, and with Pointing those
   --  the line from Eye to Pointed crosses (where the pointer's ray lands,
   --  and a little on: whatever it lands on, roof, wall, floor or the ground
   --  seen through a door, the answer is the same whole and cleared); the
   --  others come back.  Dt is drawn seconds (a recording repeats).  A roof
   --  no longer offered is whole at once.
   type View is (Dynamic, Full, None);
   --  Dynamic: the houses the eye's line and the pointer's ray cross.  Full:
   --  every house offered.  None: nothing clears.  (His order: the H key
   --  goes through them so.)
   procedure Set_View (V : View);
   function Viewing return View;
   procedure Clear;
   --  Every roof whole at once (a load, a new colony); the view stays.

   type Cleared is record
      R      : Roof;
      Amount : Float := 0.0;                  --  0: whole .. 1: cleared
   end record;
   function Count return Natural;             --  roofs cleared or clearing
   function Shown (K : Positive) return Cleared;

   function Cover (C : Cleared; X, Y, Z : Float) return Float;
   --  How much of C's roof is drawn at (X, Y, Z): 1 whole (or not its roof);
   --  cleared, Edge_Cover over its walls and eaves, nothing Taper_M in.
   function Cover_At (X, Y, Z : Float) return Float;
   --  The least over every roof shown (1: none there).

   function Wall_Cover (C : Cleared; Eye : Vec3; X, Y, Z : Float) return Float;
   --  How much of C's walls is drawn at (X, Y, Z), seen from Eye: 1 whole
   --  (not within Wall_M of its walls' outer side, not above its floor, or a
   --  wall whose outward side does not face the eye); cleared, nothing where
   --  the wall faces the eye squarely (Face_Hi), fading to whole edge-on
   --  (Face_Lo).
   function Wall_Cover_At (X, Y, Z : Float) return Float;
   --  The least over every house shown, from where the eye was at the last
   --  Follow (Eye_Now).
   function Eye_Now return Vec3;

   --  A roof's timbers (John, 2026-11-17: "add trusses, ridge beam, and
   --  cross member support"; the tie beams, king posts, rafters and ridge
   --  beam a house begun since 2026-11-19 has inside its walls) clear with
   --  its roof, by their place: timber inside a cleared house's walls,
   --  Timber_Up_M or more over its floor.  As the thatch does: a share by
   --  the walls, nothing Taper_M in.  (The trusses in its gable ends are
   --  of its walls, and clear with those.)
   Timber_Up_M : constant := 1.9;    --  over a serf's head: nothing of timber stands that high on a floor
   function Timber_Cover (C : Cleared; X, Y, Z : Float) return Float;
   function Timber_Cover_At (X, Y, Z : Float) return Float;

end Castle.Cutaway;
