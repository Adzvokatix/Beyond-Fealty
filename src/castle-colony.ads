with Interfaces;
with Castle.Blocks;
with Castle.Math;   use Castle.Math;
with Castle.Bodies;
with Castle.Hash;
with Castle.Nav;
with Castle.Deer;
with Castle.Buildings;

--  The colony: the band, what each of them is doing and carrying, the
--  homestake, the paths, the stockpiles and the bushes they pick, on a
--  clock of its own.  It decides; Castle.Serfs only shows it.
--
--  The clock runs in fixed steps, Tick_Hz to a second at normal speed (the
--  game passes real seconds times its speed, nothing when paused), so the
--  same start gives the same colony whatever the frame rate.  Each member
--  is a small machine: think, walk a route (Castle.Nav), work, carry,
--  store.  What two of them could both go for (a bush, room in a stockpile
--  cell) is reserved by the first, and a goal that can't be reached is left
--  alone for a while instead of being tried every step.
--
--  The world is read and changed through the game (Set_World): picking a
--  bush, laying a path and raising the stake are block edits like the
--  player's own, so they are saved, drawn and walked on like any other.
--
--  The player says where (the stake, paths, stockpiles), the jobs say who:
--  a gatherer looks for the ripe bush nearest it, weighed toward the stake
--  (the stake's priority gradient), picks it into its basket, and carries
--  a full basket (or what it has, when nothing ripe is in reach) to the
--  nearest stockpile cell with room.  Picked bushes grow their berries back
--  in Regrow_Days, but not in winter.  Main thread only.
package Castle.Colony is

   ------------------------------------------------------- the world it works in

   type Block_Reader is access function (Bx, By, Bz : Integer) return Castle.Blocks.Block;
   type Block_Writer is access procedure (Bx, By, Bz : Integer; B : Castle.Blocks.Block);
   type Version_Reader is access function (CX, CY : Integer) return Natural;   --  0: not loaded

   procedure Set_World (Read : Block_Reader; Write : Block_Writer; Version : Version_Reader);
   --  The routes come from Castle.Nav, whose source is set apart.

   procedure Set_Ground_Stacks (N : Natural);
   function Ground_Stacks return Natural;
   --  The colony's own ground: the host has in, or is bringing in, every
   --  stack within N stacks of the stake's (counted stack to stack), and
   --  the colony reads no ground beyond them, whatever else is loaded: it
   --  indexes, searches and lays out nothing there, and its routes keep to
   --  them (Castle.Nav.Within_Stacks).  So a colony comes out the same
   --  whether its host holds that ground alone (the runner), what the
   --  camera has passed over besides (the game as it was), or the whole map
   --  (the game since 2026-11-14; colony_run --ground-stacks 400 ends in
   --  the very state of a run on the colony's own ground, and
   --  tools/stress.sh holds it to that).  Until it is called the colony
   --  reads whatever is loaded (checks on made-up worlds).  A statement of
   --  the host's, not the colony's state: Reset leaves it, nothing saves it.
   --  What the player plans is not the band's doing and is read from all
   --  the ground that is held: the line of a path shown and counted, the
   --  ground inside a round of paths.  A zone or a path so marked further
   --  out widens Ground_Reach_M, and the band goes there once the host has
   --  said that ground is its own.
   --  The stacks to bring in are those within Integer (Ground_Reach_M / 8)
   --  + 5 of the stake's, and never fewer than were once in.

   --  Trees come from the generator (in the game, Castle.Flora): one at
   --  most to each Tree_Cell_B x Tree_Cell_B cell of block columns.  The
   --  colony asks for the trees whose trunks stand in the stacks it looks
   --  through, and for a tree's own blocks when it is felled.
   type Tree_Kind is (Broadleaf, Conifer, Apple);
   type Tree_Info is record
      Valid   : Boolean   := False;
      Kind    : Tree_Kind := Broadleaf;
      Bx, By  : Integer   := 0;   --  the trunk's south-west column (blocks)
      Bz      : Integer   := 0;   --  its first block above the ground
      Trunk_W : Integer   := 1;   --  blocks square
      Trunk_H : Integer   := 0;   --  blocks
   end record;
   Tree_Cell_B : constant := 16;   --  Castle.Flora.Tree_Cell (the game checks they agree)
   type Tree_Finder is access function (I, J : Integer) return Tree_Info;
   type Tree_Shaper is access procedure
     (I, J  : Integer;
      Visit : not null access procedure (Bx, By, Bz : Integer; M : Castle.Blocks.Material));
   --  Every block the tree of cell (I, J) was generated with (trunk,
   --  branches, crown), whatever stands there now.
   procedure Set_Trees (Find : Tree_Finder; Shape : Tree_Shaper);

   ------------------------------------------------------- the clock

   Tick_Hz : constant := 20;
   Tick_S  : constant := 1.0 / Tick_Hz;

   procedure Advance (Seconds : Float; Hours : Long_Float);
   --  Seconds of colony time (real seconds times the game's speed) are run
   --  as whole steps, the rest kept for next time.  Hours: the game clock
   --  now, for what grows back by the day.
   function Ticks return Natural;
   function Blend return Float;   --  how far into the next step (0 .. 1), to draw between steps

   ------------------------------------------------------- things carried and stored

   type Item_Kind is (Nothing, Berries, Wood, Stone, Water, Straw, Meat, Hide, Carcass,
                      Vegetables, Apples, Sticks, Grain, Earth, Salt, Ladder);
   --  Berries are counted in handfuls, wood in logs (a metre long, carried
   --  one at a time on the shoulder), straw in sheaves (a block of tall
   --  grass each), stone in stones (a block of boulder each, carried in the
   --  porter's sack), meat in pounds (in joints, until 2026-11-12, and still
   --  with curing off: "The lord's cart", below) and hides one a deer.
   --  Water is counted in pails: porters draw it into the storehouse's
   --  water barrels (the stores' fittings, below); nothing uses it yet.  A
   --  carcass is carried (across the shoulders), never stored: it is
   --  butchered at the stockpile, into meat and a hide.  Vegetables are
   --  wild roots and greens, one plant pulled each; apples are picked one by
   --  one.  Sticks are an armful of dead wood picked up under a tree, for the
   --  fire: never stored, carried straight to it.  Grain is counted in
   --  handfuls; nobody gathers it for itself: it comes in with the straw
   --  (see Grain_Per_Plant).  Earth is counted in blocks (a basketful is
   --  Carry_Limit of them): what is dug off ground being levelled; it is
   --  heaped in a stockpile, and nobody asks for it but a hollow to fill.
   --  Salt is counted in pounds: it comes from the lord's cart, a sackful
   --  at a time, and is used up as deer are butchered.  A ladder is a
   --  ladder: made at a stockpile by a builder with a roof to thatch,
   --  carried over the shoulder, stood against the house, and stored again.
   --  (Saved by position: new kinds go on the end.)

   function Carry_Limit (K : Item_Kind) return Natural;   --  the most of it carried at once
   function Cell_Limit (K : Item_Kind) return Natural;    --  and the most a stockpile's place holds
   --  (meat's: by the pound, or with curing off by the joint, as below)
   Carry_Table : constant array (Item_Kind) of Natural :=
     [Nothing => 0, Berries => 30, Wood => 1, Stone => 4, Water => 2, Straw => 6, Meat => 4, Hide => 2,
      Carcass => 1, Vegetables => 12, Apples => 20, Sticks => 1, Grain => 30, Earth => 16, Salt => 20, Ladder => 1];
   Cell_Table : constant array (Item_Kind) of Natural :=
     [Nothing => 0, Berries => 120, Wood => 20, Stone => 40, Water => 10, Straw => 40, Meat => 20, Hide => 20,
      Carcass => 0, Vegetables => 60, Apples => 80, Sticks => 0, Grain => 120, Earth => 64, Salt => 240, Ladder => 2];

   function Name (K : Item_Kind) return String;   --  "berries"

   ------------------------------------------------------- the homestake

   Arrivals : constant := 13;
   --  How many arrive when the stake is raised, unless a start says otherwise
   --  (John, 2026-11-17: "When the player places the homestake, a
   --  "messenger" is sent to the retinue of serfs and an advisor who will
   --  assist the player throught the game ... So we need 13 starting serfs,
   --  basically the player begins by delegating the tasks, as we have
   --  done").  The reference runs and the stress test say --band 6: the
   --  band every figure before then was measured with.
   procedure Place_Stake (Ground : Vec3; Band_Size : Positive; Seed : Castle.Hash.U64; Post : Boolean := True;
                          As_Read : Boolean := False);
   --  Ground: a point on the ground (metres).  Raises the stake there (a
   --  post 1.75 m tall) and the band arrives round it, every one of them
   --  unassigned.  Once per colony.  Post False (the square's: see "the
   --  homestake and the campfire one"): no post is raised, and the stake's
   --  place is the corner of blocks nearest Ground.  As_Read (with Post
   --  False): Ground's height is the ground's own there, as whoever asks has
   --  read it under whatever stands or hangs over it; else the ground is
   --  looked for near that height, and the highest solid thing within 2 m
   --  over it is taken (a bough, a tree's top).
   function Has_Stake return Boolean;
   function Stake return Vec3;            --  the foot of the post

   ------------------------------------------------------- the band

   Max_Members : constant := 48;
   type Job_Kind is (Unassigned, Gatherer, Forester, Hunter, Porter, Cook);
   --  Gatherers pick berries; a forester fells a tree and carries every
   --  log of it home before felling the next (its logs are its own: no one
   --  else touches them); porters fetch straw first (tall grass cut, for
   --  the thatch) up to its reserve, then stone (prised off boulders) as it
   --  is wanted, and never carry wood; hunters hunt deer (below); the cook
   --  keeps the camp (below).
   type Act is (Standing, Walking, Picking, Putting_Down, Chopping, Sneaking, Aiming, Eating, Sleeping,
                Stirring, Eating_Seated, Dead);
   --  what the body is doing (Eating_Seated: on a seat log at the fire)

   --  Who directs whom.  Everyone who acts on the colony is an actor: the
   --  player, or a member of the band (the player's own character will be
   --  one of those).  Each member records who delegated its work: the actor
   --  who gave it its job, or no one, for the unassigned and for a job it
   --  took up on its own (the band's first cook).  Nothing reads it yet: it
   --  is there for the trades whose holders direct helpers, and for whom a
   --  person answers to.  Delegation runs only downward.
   subtype Actor is Integer range -1 .. Max_Members;
   The_Player : constant Actor := -1;
   No_One     : constant Actor := 0;      --  1 .. Max_Members: that member

   function Members return Natural;
   function Genome_Of (I : Positive) return Castle.Bodies.Genome;
   function Name_Of (I : Positive) return String;
   function Job_Of (I : Positive) return Job_Kind;
   procedure Set_Job (I : Positive; J : Job_Kind; By : Actor := The_Player);
   --  By: who gives it the job (its director from now on; no one, for Unassigned).
   function Director_Of (I : Positive) return Actor;
   function Where (I : Positive) return Vec3;          --  the feet, between steps (Blend)
   function Doing (I : Positive) return Act;
   function Work_Spot (I : Positive) return Vec3;      --  where the hands go, picking or putting down
   function Carrying (I : Positive) return Item_Kind;
   function Carried (I : Positive) return Natural;
   function Status (I : Positive) return String;       --  "picking berries", "taking 30 berries to the stockpile"

   type Route_View is access constant Castle.Nav.Route;
   function Route_Of (I : Positive) return Route_View;
   function Leg_Of (I : Positive) return Positive;     --  walking between route points Leg and Leg + 1

   ------------------------------------------------------- paths

   --  The player plans a path; the band lays it (John, 2026-11-10: "the
   --  path should work the same way, the player plans it the serfs build
   --  it").  Lay_Path marks a path Path_Width_M wide along the ground;
   --  from then on that ground is a path's (no zone takes it, and zones
   --  are laid out along it), though it is grass still.  The band lays it a
   --  metre at a time (Tamp_S a metre: what grows on it cut and the top of
   --  the ground turned to footpath, each metre all at once), as an extra
   --  task, the camp's building first (Extra_Hands).  Which metres are
   --  still to lay is read from the ground itself, so a bit dug up is laid
   --  again.
   --
   --  A path is laid a stretch to a serf (John, 2026-11-11: "when a serf
   --  starts compacting a road they are assigned a stretch, say 20m for
   --  example").  A path is kept as stretches of Path_Stretch_M (the last
   --  what is left; a shorter click is a stretch of its own).  Whoever
   --  starts on a path is given a stretch nobody has, the one with the
   --  least way to it, weighed toward the stake: it is that serf's alone,
   --  and it lays it from end to end.  Then it goes back to its own work
   --  (and may be given another when it next has empty hands and there is a
   --  place for it); only if its stretch was short does it go on to another
   --  nobody has, till it has laid Path_Stretch_M metres.  Leaving for
   --  anything else (to eat, to sleep, for the camp) gives its stretch up.
   --  So a path takes as many serfs at once as it has stretches, and no
   --  more than Extra_Hands allows.
   --
   --  The colony's ground reaches as far as any stretch still to lay
   --  (Ground_Reach_M).  With the band's labour off (Set_Labour) a path is
   --  laid the moment it is marked, as it used to be.
   Path_Width_M   : constant := 1.0;
   Path_Stretch_M : constant := 20.0;
   procedure Lay_Path (From, To : Vec3; Laid : out Natural);
   --  A footpath Path_Width_M wide along the ground from From to To
   --  (metres): planned, for the band to lay (or, with the band's labour
   --  off, laid: the top of the ground turned to footpath and anything
   --  growing on it cut).  Laid: block columns of it there are to turn (0:
   --  nothing there to lay on, or refused: Path_Refusal).
   --  Paths lie straight or at 45 degrees (John, 2026-11-19: "we need to do
   --  something about the paths being at slight angles, I think we need to
   --  lock the paths to straight and 45 degree angles, slighty being off
   --  doesn't really work in a voxel world, then we can start planning
   --  structures on that design pathway, keeps things tight and simple").
   --  A line a path is planned along is made so by whoever orders it
   --  (Castle.Actions, Path_Snap), with these two; Lay_Path lays whatever
   --  line it is given, and paths laid before lie as they lay.
   --
   --  Path_Line_Start (P): where a line begun at P begins: the corner of
   --  four blocks nearest it; on a path that lies so, the corner nearest it
   --  on that path's middle line; and the end of a path within
   --  Path_Width_M of that, so that a line goes on from an end or branches
   --  from a path's middle.  Path_Line_End (From, P): where a line from
   --  From toward P ends: along the nearest of the eight ways (east, north
   --  east, north ...), a whole number of blocks along it (two at the
   --  least; pointed nearer From than Path_Line_Least_M it is From itself:
   --  no line), as near P as that comes; and where that crosses the middle
   --  line of a path within Path_Width_M of there, at the crossing: a line
   --  drawn up to a path meets it.  So a line begun on a corner of blocks
   --  ends on one, its sides fall on block edges, and it is the same number
   --  of blocks across all along (four when straight; aslant five, a step a
   --  block).  Both give back what they are given when it is such a point
   --  already (the line shown and the line ordered are one line).  The
   --  height is the ground's there.
   Path_Line_Least_M : constant := 0.5;
   function Path_Line_Start (P : Vec3) return Vec3;
   function Path_Line_End (From, P : Vec3) return Vec3;
   --  **The height of a line's point under a tree is the ground's under it** (found 2026-11-22: the
   --  walking map's first floor there is a bough, and a path whose end was given a bough's height,
   --  four metres up and more, had metres by that end that looked for their ground up there and
   --  found none: never counted, never laid.  4 of some 1,680 parts of the paths of stockyards put
   --  down whole at ten places).  Of every line planned: the path tool's, a zone's put down whole,
   --  the square's, housing's pulled with its path.
   --  Set_Line_Ground (False), --no-line-ground: the first floor's height, as it was.  Not saved.
   procedure Set_Line_Ground (On : Boolean);
   function Line_Ground return Boolean;
   procedure Lay_Path_Through (From, To : Vec3; Laid : out Natural);
   --  A path as the player orders one (the path tool): Lay_Path, but that
   --  housing gives way under it where no hovel's lot is (John,
   --  2026-11-20, of a path pulled through housing: "should give way as
   --  built, if the path can pass and not interfere with anything built"):
   --  the block columns of housing under the path are no zone's any more,
   --  the lots still to begin are laid out anew.  Through a hovel's lot,
   --  begun or standing, it is refused; through any other zone or the
   --  lord's cart, as Lay_Path refuses it.  Pull_Gave_Way: how many block
   --  columns gave way.  Set_Path_Through (False), --no-path-through: as
   --  Lay_Path, as before.  Not saved.
   procedure Set_Path_Through (On : Boolean);
   function Path_Through return Boolean;
   --  Whoever lays a metre of path goes to its middle **on the ground the path lies on**: where a
   --  bough that can be stood on hangs over it (two floors in that half metre of the walking map) the
   --  floor nearest the stretch's own height, not the first.  (Gone to on the bough, the metre was
   --  never laid: no way up to it.  Found 2026-11-21 on the path round a square of eleven metres on
   --  sloping ground, a tree beside it that is not felled for it: the square's wall, which waits for
   --  its path, was left with a gap a metre wide.)  Set_Metre_Ground (False), --no-metre-ground: the
   --  first floor, as it was.  Not saved.
   procedure Set_Metre_Ground (On : Boolean);
   function Metre_Ground return Boolean;
   procedure Build_Paths_Now (Backward : Boolean := False; Most : Natural := Natural'Last);
   --  Every stretch planned laid on the spot, as Build_Camp_Now builds the
   --  camp: for scripted starts (--paths-built) and the checks.  (Backward:
   --  the last stretch first and each stretch's last metre first: what is
   --  laid is not to depend on the order it is laid in, and the checks and
   --  colony_run --paths-backward lay it both ways to see.  Most: so many
   --  metres of them at the most, the rest left to lay: for building
   --  something else between two parts of them, colony_run --walls-between.)
   function Paths_To_Lay return Natural;   --  metres of planned path still to lay, as last counted
   function Path_Todo (K : Positive; Metre : Positive) return Boolean;
   --  Metre Metre (from its first end) of stretch K is still to lay, as last
   --  counted: for whatever shows a planned path.
   procedure For_Path_Left (K : Positive; Visit : not null access procedure (X, Y, Zr : Integer));
   --  Every block column of stretch K that is still to be turned to
   --  footpath, as its ground lies now, and the row of that column's top:
   --  for whatever shows a planned path on the ground it will lie on (John,
   --  2026-11-12: "the pathing zone also just forms a stright line by
   --  elevation and it is in the air above the ground instead of drawing
   --  along it").  West to east, and south to north in each line of columns.
   procedure For_Path_Line (From, To : Vec3; Visit : not null access procedure (X, Y, Zr : Integer));
   --  And every block column a path laid From .. To would have to turn,
   --  piece by piece as Lay_Path would record it: for the line as it is
   --  drawn.  Nothing is changed.
   function Paths_Left_Key return Natural;
   --  Moves when what is still to lay does (a stretch planned, a metre
   --  laid, a stretch read from the ground again).
   function Stretch_Of (I : Positive) return Natural;   --  the stretch member I has to lay (0: none)
   function Laid_By (I : Positive) return Natural;      --  metres it has laid since it was given one
   procedure Set_Path_Holes (On : Boolean);
   --  On (the default): a hole in the ground under a metre of path is
   --  filled as the metre is laid, to the ground round it, and the path
   --  laid over it (John, 2026-11-13: "It would be nice if there was a way
   --  for serfs to fill in holes in the path when they are compacting the
   --  ground").  A hole is a column with nothing of the eight round it
   --  lower and more than half of them higher: a pit, a dent, a ditch a
   --  block wide; never a step of a slope, which a path goes down as it
   --  did.  The earth is the turf cut where the path is laid.  Off: a path
   --  goes down into a hole as it did.  Saved with the colony.
   function Path_Holes return Boolean;
   procedure Set_Path_Level (On : Boolean);
   --  On (the default): a metre of path is levelled as it is laid (John,
   --  2026-11-17: "paths still need to be leveled as well to elimiate small
   --  bumps and holes in the road, some holes get filled, others don't").
   --  The path has a line of its own: at each quarter metre along it the
   --  middle height of the ground across its width, and that smoothed over
   --  Path_Level_Span_B before and behind, so that a slope keeps its steps
   --  and a bump or a dent shorter than the span is gone.  Each column laid
   --  is cut down or filled up to that line where it is within Path_Level_B
   --  of it: across its width the path lies level, and along it it steps
   --  only where the land does.  Further off than that it is a bank or a
   --  ditch, and the path goes over it as it did.  Off (--no-path-level):
   --  only closed hollows are filled, as before.  Saved with the colony.
   function Path_Level return Boolean;
   --  A forester set to building (John, 2026-11-19: "serfs fill jobs as the
   --  have been, as the are needed, dictated by skill. We can assign jobs in
   --  the development, AI so keep adding new jobs as we work them in to that
   --  list, but the player won't need to delegate further, past opening
   --  positions").  A builder is still the forester best at building with no
   --  house to build; one set so here takes a house before any that is not,
   --  whatever their skill, and fells when there is none.  It sets the job
   --  to forester; giving any job lifts it.  For development: the game
   --  offers it on a person's menu (--no-dev-jobs: not).  Saved (blob 32).
   procedure Strike_Down (I : Positive);
   --  For the checks, as Supply is: member I dies where it stands.
   procedure Set_Builder (I : Positive; On : Boolean);
   function Is_Builder (I : Positive) return Boolean;
   --  The stockman and the carpenter named by hand, for development as the
   --  builder is (John, 2026-11-22, asked whether the cook, the stockman and
   --  the carpenter should be on that list: "yes add the cook and the
   --  stockman and carpenter"; the game offers them on a person's menu,
   --  --no-dev-jobs: not).  Name_Stockman makes member I a porter and the
   --  storehouse's stockman whatever its portering; Name_Carpenter a
   --  forester and its carpenter whatever its carpentry (one with a house to
   --  build leaves it to another builder).  **Before the storehouse stands**
   --  the one named is a porter or a forester like any other, and is its
   --  stockman or its carpenter from the moment it stands (a carpenter-to-be
   --  that took a house to build meanwhile leaves it then).  It is so for as
   --  long as it lives and keeps that job: given other work, the next is
   --  chosen by skill, as ever.  With the rule off (Set_Stockman (False),
   --  Set_Carpenter (False)) the name is kept and nobody is.  Nothing new is
   --  saved: who the stockman and the carpenter are always was.
   procedure Name_Stockman (I : Positive; By : Actor := The_Player);
   procedure Name_Carpenter (I : Positive; By : Actor := The_Player);
   function Stockman_Named (I : Positive) return Boolean;
   function Carpenter_Named (I : Positive) return Boolean;
   --  Member I is the stockman (the carpenter), or is the one named to be
   --  when the storehouse stands: for a menu's mark.
   --  How a house begun from now on is made (John's notes of 2026-11-17;
   --  a house keeps how it was begun, and both are saved with the colony):
   procedure Set_Roof_Timbers (On : Boolean);
   --  On (the default): its roof has timbers ("Add timber truss the the
   --  ends of the houses and cross member support to the sides of the
   --  houses perpendicular to the door, add trusses, ridge beam, and cross
   --  member support for the storehouse"): a truss in each gable end (a
   --  king post and a rafter under each slope, where daub was), tie beams
   --  across from eave wall to eave wall about every two metres; in a
   --  storehouse a truss on each tie beam and a ridge beam.  Raised with
   --  its frame, of its own logs.  Off (--no-roof-timbers): none.
   function Roof_Timbers return Boolean;
   --  **The truss runs to the ends of its wall, and is the same either side
   --  of its middle** (John, 2026-11-23: "can we extend the truss to the end
   --  of the wall? make it symmetrical, either add another support if the
   --  length is even?").  A gable's rafters met the wall's top beam three
   --  blocks in from either corner, and its king post stood at the lower of
   --  the two middle places of a span of an even number of blocks.  With
   --  this (and its roof's timbers) the line of each rafter goes on down
   --  through the wall's top corner to its corner post (three blocks of
   --  timber where there was daub, at either end of each gable), and an even
   --  span has two king posts side by side, in its gables and on a
   --  storehouse's tie beams, and two ridge beams.  Of its own logs: twelve
   --  blocks of timber more for an odd span, some forty-four for an even one
   --  (a log makes ninety-six).  A house keeps how it was begun, and both
   --  are saved (blob 45).  Set_Full_Truss (False), --no-full-truss: as
   --  before.
   procedure Set_Full_Truss (On : Boolean);
   function Full_Truss return Boolean;
   procedure Set_Window_Timber (On : Boolean);
   --  On (the default): a window's sill runs from the post on its one side
   --  to the post on its other, a lintel over it the same, and the wall to
   --  either side of the opening is of plank ("Fix floating timber for
   --  windows on houses, make the timber extend the length of the timber
   --  columns it sit's inside. Change the color of the first fraction of
   --  blocks around the window, like planks as trim").  Off
   --  (--no-window-timber): a sill a block wider than the window.
   function Window_Timber return Boolean;
   function House_Has_Timbers (K : Positive) return Boolean;   --  house K was begun with them
   function House_Has_Sills (K : Positive) return Boolean;
   Path_Level_B      : constant := 2;    --  a column is moved this far at the most (half a metre: his to tune)
   --  **A path is stepped where it meets trodden ground** (John, 2026-11-23:
   --  "we need to figure out a way to handle how paths and zone buildings
   --  meet up ... we have the .5m jumps where a path is extended from
   --  square").  A metre of path is brought to its own line, the square's
   --  path to its floor's level, each by itself: where one met the other, or
   --  the land stepped under one, trodden ground lay half a metre (two
   --  blocks: the most a serf climbs) off the trodden ground beside it.  When
   --  a metre is laid, the columns of path within Meet_Reach_B of it are
   --  looked at again: one that stands two blocks or more over trodden ground
   --  beside it has a block cut off it; one that lies two blocks or more
   --  under ground that is never moved has a block of earth put under it;
   --  and so on until none does, or it has been moved Meet_Most_B blocks.
   --  So a jump of half a metre becomes two steps of a quarter, a quarter
   --  metre apart.  Never moved: the square's own path, the strips kept for
   --  its walls, and any zone's ground (a floor, a door's way).  The earth is
   --  the turf's, as a hollow's is.  Set_Paths_Meet (False),
   --  --no-paths-meet: as before.  Not saved.
   Meet_Reach_B : constant := 8;        --  two metres round the metre laid
   Meet_Most_B  : constant := 2;        --  a column is moved this many blocks at the most when a metre is laid
   procedure Set_Paths_Meet (On : Boolean);
   function Paths_Meet return Boolean;
   function Path_Columns_Stepped return Natural;   --  blocks cut off or put under a path so (a measure, not saved)
   --  **A door's way meets its path as it lies** (the same message: "we
   --  have blocks that aren't knocked down").  A hovel's way out is planned
   --  when the hovel is placed, against the ground where it will meet its
   --  path (Door_Row): a landing level with the floor, then a block a column
   --  to that ground.  The path is laid afterwards, brought to its own line
   --  or the square's level, and stepped where it meets other paths: so a
   --  step of the way stood a block over a path that had come to lie lower,
   --  or the way ended half a metre off it.  When its ground is ready, and
   --  again when it stands, the columns of its way past the landing are made
   --  again between the landing's level and the laid path's top beyond the
   --  way's end, a block a column from the path's side back (earth cut off
   --  or filled in; where the path lies further off the floor than the way
   --  has columns for, the last step is the higher).  Only where the path is
   --  laid there; not a storehouse's way, nor a hovel's whose ground is made
   --  where it is drawn turned.  Set_Door_Meet (False), --no-door-meet: as
   --  before.  Not saved.
   procedure Set_Door_Meet (On : Boolean);
   function Door_Meet return Boolean;
   function Door_Columns_Remade return Natural;    --  columns of doors' ways made again so (a measure, not saved)
   Path_Level_Span_B : constant := 4;    --  and the line smoothed over a metre before and a metre behind
   procedure Set_Stretches (On : Boolean);
   --  On (the default): a path is laid a stretch to a serf, as above.  Off:
   --  as it was before stretches, for the older reference logs: anyone at
   --  an extra task lays the metre with the least way to it, one metre at a
   --  time, several to a stretch.  Saved with the colony.
   function Stretches return Boolean;
   --  Paths and zones never share ground.  A path is laid round a zone: one
   --  whose line would run through zoned ground is refused whole, and one
   --  that only brushes a zone leaves the zone's blocks as they are.  (The
   --  other way round, ground a path lies on can never be zoned: see zones.)
   function Path_Refusal return String;   --  why the last Lay_Path laid nothing ("" if it laid some)
   function Path_Count return Natural;
   function Path_End (K : Positive; Second : Boolean) return Vec3;
   function Near_Path (X, Y, Within_M : Float) return Boolean;
   function On_Path (X, Y : Float) return Boolean;   --  that ground is a path's own

   ------------------------------------------------------- stockpiles

   Max_Cells : constant := 1_024;
   --  **A place is made level when something is first put on it** (John,
   --  2026-11-23: "the straw half in the ground and half outside, I don't
   --  know what the solution for that is, we might have to flatten
   --  stockpiles").  A place is a square metre, sixteen block columns, and
   --  what lies on it is drawn at the height of its middle; on ground that
   --  steps under it, the columns a block higher stood through whatever lay
   --  there and those a block lower left it over air.  From the moment a
   --  place of a stockpile holds something, or has something on its way,
   --  its block columns are brought to the place's own level: a block or two
   --  cut off or put under (Place_Level_B at the most), their tops as they
   --  were.  Each place by itself: a stockpile on a slope becomes steps a
   --  metre square, and nothing is moved under a place nothing is put on.
   --  Not the stockyard's (its ground is levelled whole with its
   --  storehouse's), nor under a tree's foot, through water or under the
   --  cart.  The earth is the turf's, as a path's hollow is.
   --  Set_Place_Level (False), --no-place-level: as before.  Not saved.
   Place_Level_B : constant := 3;
   procedure Set_Place_Level (On : Boolean);
   function Place_Level return Boolean;
   function Places_Levelled return Natural;     --  places with a block moved so (a measure, not saved)
   function Place_Blocks_Moved return Natural;  --  and blocks cut off or put under
   procedure Zone_Stockpile (X0, Y0, X1, Y1 : Float; Cells : out Natural);
   --  A stockpile on the lot between two corners (metres, in either order;
   --  the first is the side of a path it is on), and only if it comes
   --  within a metre of a path's edge.  The lot is laid out the way zones are (see
   --  zones): turned to lie along its path, drawn out to the path's edge,
   --  stopping at any path and at any other zone.  Things are put down in
   --  places 1 m square, set out in rows along the lot; a place with
   --  anything standing on it (a bush, a log, a stone), or a top more than
   --  half a metre off level, or part of it off the lot's ground, is left
   --  out.  Grass and grain on the places are cut, so what is put there
   --  can be seen (the rest of its ground keeps its grass).  Cells: how
   --  many places it got (0: refused, and Stockpile_Refusal says why).  One
   --  zoning is one zone.
   function Stockpile_Refusal return String;   --  why the last Zone_Stockpile was refused ("" if it was not)
   --  Its overflow (John, 2026-11-17: "for the 5 blocks of overflow, if
   --  there is no space in the stockpile, just have them use 5 free blocks
   --  around the stockpile as an overflow to set things down so they arent
   --  carrything them everywhere, and then they won't collect anymore until
   --  space frees up").  A stockpile zoned with the overflow on gets up to
   --  Overflow_Places places more just outside its lot: 1 m square on the
   --  lot's whole metres, in the ring round it, each wholly on free ground
   --  (no path's, no zone's, nothing on it but what grows and is cut,
   --  within half a metre of level), those nearest a path first.  Their
   --  ground is the zone's and they are its places (Cell_View.Overflow).
   --  A load goes to an ordinary place while one takes it, and only then
   --  to an overflow place; nobody sets out to bring in a kind no ordinary
   --  place has room for (Room_For: a gatherer now, as a porter, a forester
   --  hauling and a hunter already did); and what is taken out of the
   --  stores is taken from an overflow place first.  Set_Overflow (False),
   --  --no-overflow: no overflow places, and a gatherer picks with nowhere
   --  to put what it picks, as before.  Saved with the colony.
   --  Off since 2026-11-18 (John: "remove overflow"): no stockpile gets
   --  overflow places unless Set_Overflow (True), --overflow.
   Overflow_Places : constant := 5;
   procedure Set_Overflow (On : Boolean);
   function Overflow return Boolean;

   --  The stockpile's last places as the signal (John, 2026-11-17: "Change
   --  stockpile to a onetime placement of a 10x10 zone, remove overflow,
   --  use the last 10 blocks as a signal to the serfs to slow/cease
   --  production if the stockpile gets full").  While the stores' empty
   --  ordinary places are no more than Last_Places, they are kept for the
   --  loads already in hands or lying out (a forester's felled logs, a
   --  hunter's kill): nobody sets out to bring in a load that would need
   --  one of them (a gatherer, a porter, a forester felling, a hunter), and
   --  what has a place of its own kind with room still goes there (so the
   --  bringing in slows, and stops when nothing has room).  Whoever is held
   --  back says so ("the stockpile is nearly full: nothing more brought
   --  in") and rests at the camp until there is room.  A place is "ordinary"
   --  as for the overflow: not a storehouse's fitting, not closed.
   --  Never more than a tenth of the stores' ordinary places are kept (his
   --  ten are of a hundred): a scripted stockpile of fewer than ten places
   --  keeps none.  Set_Last_Places (0), --last-places 0: none kept, as
   --  before.  Saved.
   Last_Places : constant := 10;
   procedure Set_Last_Places (N : Natural);
   function Last_Places_Kept return Natural;

   --  The storehouse (the stockpile's second pass; John, 2026-11-17: "On
   --  the second day, the advisor asks the player to zone more area, if the
   --  stockpile isn't big enough, to build the storehouse, the stockpile
   --  will then be "upgraded" if it meets the requirements, the builders
   --  will build a stockhouse, compact the land of the stockpile, build a
   --  fence with a gate, build coverings for outside materials ... But we
   --  aren't doing the player and advisor thing just yet, so just simulate
   --  the request").  On the second morning after the stake is raised
   --  (Store_Morning_H on the day after) the request is made: the first
   --  stockpile whose places make a lot of at least Storehouse_Lot_M by as
   --  much, square to the block grid, with ground for it, is upgraded; with
   --  none, the request stands (Storehouse_Note says so) and is looked at
   --  again every game hour.  Upgraded, a storehouse
   --  (Castle.Buildings.Storehouse_Design) is begun at the end of its lot
   --  nearest the stake, its door toward the path with the places before it
   --  for staging (Store_Yard_B), and its yard laid out round it: the
   --  places under it and before it are closed (what lies on them is taken
   --  away first, by its builder, or eaten), then the builders raise it as
   --  they raise a hovel, from the stores, and then beat the yard's ground,
   --  fence it with a gateway before the door, and raise the coverings
   --  along its back.  It is nobody's home.  Set_Storehouse (False),
   --  --no-storehouse: none, as before.  Saved with the colony.
   --
   --  **Since 2026-11-18 it goes on a stockyard, never on a stockpile**
   --  (John, 2026-11-17: "Keep stockpile, move storehouse to a new stockyard
   --  zone.  Storehouse to be built with doors at each end of the building,
   --  the fence is to be placed around the stockyard with the gates
   --  extending from the storehouse, inline with the inside wall of the
   --  storehouse to the stockyard").  A stockyard is zoned corner to corner
   --  beside a path (Zone_Stockyard): a lot square to the block grid
   --  whatever way its path runs, at least Stockyard_Least_M each way and
   --  Stockyard_Most_M at most, its side toward the path drawn out to it (as
   --  far as Yard_Snap_M: beside a path aslant, the ground between); one,
   --  placed once.  It is a stockpile's zone marked as the yard (its places
   --  are places like any, all closed until the storehouse stands).  The
   --  second morning's request is for a stockyard now; on one, the
   --  storehouse is begun in the middle of its front: its length along the
   --  path, Store_Yard_B of staging before it, a door in each end, its yard
   --  behind it fenced, a gateway beside each end in the line of its back
   --  wall, coverings along the back.
   Storehouse_Lot_M  : constant := 15.0;
   Stockyard_Least_M : constant := 15.0;
   Stockyard_Most_M  : constant := 25.0;
   Yard_Snap_M       : constant := 12.0;
   --  **The stockyard put down whole** (John, 2026-11-21: "For the stockyard, lets expand the zones
   --  to 20x20"; his design of 2026-11-20 for zones put down with their paths: "placements",
   --  below).  One box Stockyard_Side_M square with its path along its front, held by its middle
   --  and turned as a stockpile's is (Place_Box with Stockyard_Box).  Its places lie on its own
   --  whole metres from its front's beginning, all of them taken or none (a stockyard is all of
   --  its lot).  Its front is the side its own path lies along, whatever other path is nearer
   --  (a stockyard zoned between two corners fronts the nearest), and its storehouse stands
   --  measured from that path's edge.  **The storehouse is tried on the planned ground before
   --  anything is laid**: what Plan_Box says would be taken, Place_Box takes, and where no
   --  storehouse could stand no path is laid for one.  One, placed once, as ever.
   --  Set_Yard_Box (False), --no-yard-box: the player's stockyard is zoned corner to corner, 15 to
   --  25 metres, as before.  Not saved: it speaks of the tool.  Zone_Stockyard (two corners) stays
   --  the scripts' and the checks' (--stockyard); --stockyard-box X Y WAY is the box.
   Stockyard_Side_M  : constant := 20.0;
   procedure Set_Yard_Box (On : Boolean);
   function Yard_Box return Boolean;
   --  **The storehouse's size, and how near its path it stands** (John, 2026-11-21: "bring the
   --  storehouse forward 3m towards the path so that the fenced area becomes 3m deeper, add 2m to
   --  the width of the storehouse, so that it is now 8x12").  Read as the result he names: today's
   --  5 m by 10 m with the 3 m and the 2 m he gives, 8 m back from its front wall and 12 m along
   --  it, its front wall 3 m nearer its path.  Set_Store_Size says, in blocks, the walls of a
   --  storehouse begun from now on (along its front, and back from it) and the stockyard's ground
   --  before its front wall: 48 by 32 with 6 unless told (Castle.Buildings.Store_W_New_B ..);
   --  40 by 20 with 18 is the storehouse of before.  Whole metres along and back (multiples of
   --  four), the staging two more than a multiple of four: its walls stand on its places' lines.
   --  **A storehouse keeps what it was begun with** (its walls are saved with it since blob 44; one
   --  of an older blob is 40 by 20; its staging is its yard's own, saved always).  Not saved
   --  itself: it speaks of the next one.  --storehouse LONG DEEP STAGING, in metres.
   --  **Beside a path at 45 degrees the staging is no less than keeps the storehouse's own blocks
   --  on its own ground**: they stand square to the grid about its middle and are drawn turned,
   --  so a corner of them reaches further toward the path than its front wall is drawn: 14 blocks
   --  (3.5 m) for either size.  Nearer, a corner stood across the path (28 block columns of today's
   --  storehouse, with 6).  The plan refuses any place where they would not all be its stockyard's.
   procedure Set_Store_Size (Long_B, Deep_B, Staging_B : Positive);
   function Store_Long_B return Positive;
   function Store_Deep_B return Positive;
   function Store_Staging_B return Positive;
   --  **Beside a path at 45 degrees a stockyard is laid out along the path**
   --  (John, 2026-11-20, of three ways put to him: "go on with the second way
   --  for the stockyard").  Its lot is the whole metres its two corners span
   --  along and across the path's way, as a stockpile's is; its places, its
   --  ground, its fence, its gateways and its coverings are made for real
   --  along the path, block by block on the grid (so its fence and its
   --  coverings' edges are stepped).  Its storehouse's own blocks stand
   --  square to the grid about its middle and are drawn turned an eighth,
   --  as a turned hovel's are, so that it lies along the path among them.
   --  **Once its walls and roof are up, the feet go by the storehouse as it
   --  is drawn** (Castle.Nav.Set_Drawn): its walls as drawn are walls, its
   --  two doorways as drawn are the ways in, and where its blocks stand is
   --  walked as the yard it is.  So whoever is in it, and whatever lies in
   --  it, is where it is seen, and nothing is drawn through the turn but
   --  its builder while its frame, walls and roof go up.  A stockyard beside
   --  a straight path is as before.  Set_Yard_Turn (False), --no-yard-turn:
   --  square to the grid beside any path, as before.  Saved.
   procedure Set_Yard_Turn (On : Boolean);
   function Yard_Turn return Boolean;
   --  **A covering's roof is smoothed** (John, 2026-11-20: "The outdoor roof
   --  covering needs a smoothing pass"; of the roofs, 2026-11-12: "the
   --  builders smooth the roofs so they don't step, rounded edges around the
   --  peremeter").  Once a storehouse's coverings are up, its builder goes
   --  over each one's roof again, a row at a time from its front, as it
   --  trims a hovel's thatch (work alone: nothing is carried); a row so
   --  smoothed is drawn as part of one plane from the covering's front edge
   --  to its back, its edges rounded (Yard_Pieces; its blocks stay, laid as
   --  pieces: Castle.Blocks.Piece).  Said when a storehouse is begun, and
   --  kept with it.  Set_Smooth_Covers (False), --no-smooth-covers: stepped,
   --  as before.  Saved.
   procedure Set_Smooth_Covers (On : Boolean);
   function Smooth_Covers return Boolean;
   --  **The fence of a stockyard along a path at 45 degrees is drawn along
   --  it** (his question of 2026-11-20: "what do you think about turning
   --  the fence too?"): its posts stand where they are laid, each a column
   --  of blocks, and its rails, and the planks over its gateways, are laid
   --  as pieces and drawn straight, post to post (the planks: from the
   --  gateway's post to the storehouse's corner as it is drawn); their
   --  blocks stay where they are laid, stepped along the line, and are what
   --  the feet meet.  Said when a storehouse is begun, and kept with it.
   --  Set_Fence_Pieces (False), --no-fence-pieces: stepped, as before.
   --  Saved.
   procedure Set_Fence_Pieces (On : Boolean);
   function Fence_Pieces return Boolean;
   --  **The player removes a stockpile** (John, 2026-11-23: "the stockpile
   --  zones just disappeared at some point, let the player remove them if
   --  they want to").  Nothing but this order takes a stockpile away.
   --  Remove_Stockpile (Z): its places are closed from that moment (nothing
   --  more is put there, and what lies there is taken from first by whoever
   --  takes from the stores); a porter with empty hands carries what lies
   --  there to a place with room elsewhere, a load at a time, before it
   --  fetches anything; and when nothing lies there, nothing is on its way
   --  there and nobody is coming for anything, the stockpile is gone: its
   --  ground is no zone's and its places are no more.  An empty one is gone
   --  at the next colony second.  With no room anywhere else what lies there
   --  stays, and so does the stockpile, closed.  On False: the order taken
   --  back, its places open again (one a tree stands in stays closed).  Never
   --  the stockyard, whose storehouse is built on it (refused).  The zones
   --  after it keep their numbers.  Saved (blob 46).
   procedure Remove_Stockpile (Z : Positive; On : Boolean := True);
   function Removal_Refusal return String;       --  why the last Remove_Stockpile was refused ("" if it was not)
   function Stockpiles_Removed return Natural;   --  gone so, all told (a measure, not saved)
   procedure Zone_Stockyard (X0, Y0, X1, Y1 : Float; Cells : out Natural);
   function Stockyard_Refusal return String;    --  why the last Zone_Stockyard was refused ("" if it was not)
   function Stockyard return Natural;           --  its zone (0: none zoned)
   --  The stockyard levelled, same as houses (John, 2026-11-17: "level the
   --  stockyard, same as houses"): all of its lot, from its staging to its
   --  back fence, is the storehouse's ground, brought to its floor's level
   --  by its builder before anything is raised, walled with stone where
   --  the land beside it stands more than a block over or under.
   --  Set_Yard_Level (False), --no-yard-level: the storehouse's own pad and
   --  the bank round it alone, its yard beaten as it lies.  Saved.
   procedure Set_Yard_Level (On : Boolean);
   function Yard_Level return Boolean;
   --  The stores move into the stockyard (John, 2026-11-17: "When stockyard
   --  is built, change all deliveries and pickups to the stokyard from the
   --  stockpile").  When the storehouse stands, every stockpile's places are
   --  closed: nothing more is put there, what lies there is taken from
   --  first by whoever takes from the stores, and it is carried over a load
   --  at a time, by the stockman before it sorts and by a porter with
   --  nothing else to fetch, while a place of the stockyard has room for
   --  it.  The stockpile's zone stays, empty.  Set_Stores_Move (False),
   --  --stockpile-stays: the stockpile goes on beside the stockyard.  Saved.
   --  Making way (John, 2026-11-17: "need make sure serfs have a way to
   --  continue their work if they meet obstacles").  A builder lays no
   --  block where someone stands; one standing still there (at its work, at
   --  rest, asleep) steps aside to the nearest free ground and goes on with
   --  what it was doing; one walking through is waited for.
   --  Set_Make_Way (False), --no-make-way: the builder waits for as long as
   --  it stands there, as before.  Saved (blob 31).  Builders_Blocked_S: the colony
   --  seconds builders have waited so since the colony was founded or
   --  loaded, and the longest one wait (a measure, not saved;
   --  colony_run --who says them at the end).
   procedure Set_Ladder_Stay (On : Boolean);
   --  A builder thatching from its ladder is shown up it between two bouts
   --  too (Aloft; drawn only, nothing saved).  False: on the ground for the
   --  moment it thinks, as it was drawn before 2026-11-19.
   procedure Set_Make_Way (On : Boolean);
   function Make_Way_On return Boolean;
   function Builders_Blocked_S return Float;
   function Builders_Blocked_Longest_S return Float;
   function Stepped_Aside return Natural;   --  times someone has stepped aside for a block (a measure, not saved)
   function Places_Lost return Natural;     --  sleeping places by the fire given up, their ground built on or dug (the same)
   procedure Hold_Still (I : Positive; P : Vec3; Seconds : Float);
   --  For the checks, as Supply is: member I stood at P with nothing to do
   --  for that many colony seconds.
   procedure Set_Stores_Move (On : Boolean);
   function Stores_Move return Boolean;
   function Stores_Moved return Boolean;        --  the storehouse stands, and they have
   Store_Morning_H  : constant := 7.0;
   procedure Set_Storehouse (On : Boolean);
   function Storehouse_On return Boolean;
   function Storehouse return Natural;          --  its house (0: none begun)
   --  How the storehouse lies on its stockyard, in block columns (for measuring it: colony_run
   --  --box-stats): its walls; the ground before its front wall to its path's edge, the least and
   --  the most along its front (its staging); the yard behind its back wall to the lot's back, and
   --  beside each end to the lot's sides; and, on a stockyard put down whole, whether its front is
   --  the side that zone's own path lies along.  All nought with none begun.
   type Store_Lie is record
      W, D        : Natural := 0;
      Front_Least : Natural := 0;
      Front_Most  : Natural := 0;
      Behind      : Natural := 0;
      Left, Right : Natural := 0;
      Own_Front   : Boolean := False;
      Own_Out     : Natural := 0;       --  block columns its own blocks stand in that are not its stockyard's
      Own_On_Path : Natural := 0;       --  ground (a storehouse drawn turned stands square to the grid about
                                        --  its middle), and those of them that are a path's
   end record;
   function Storehouse_Lie return Store_Lie;
   --  (for the tools) **Where the stockyard's own stone stands**: of the outermost block columns of
   --  the storehouse's site (which is its stockyard's ground: all four hundred places of one put
   --  down whole), by the side they are on in its frame (1 its front, towards its path; 2 its back;
   --  3 its left; 4 its right; a corner counts for both its sides): how many there are, how many
   --  of them its plan makes of stone (a retaining wall: Plan_Of), how many of those hold higher
   --  ground back (their top over the yard's level) and how many hold the yard up over lower
   --  ground, and the most blocks of stone in one.  Inner: columns of stone that are not on its
   --  rim (a stair's treads, a step in its way).  Read from the world as it lies, as the builders
   --  will read it; all nothing with no storehouse begun.
   type Wall_Side is record
      Rim     : Natural := 0;
      Stone   : Natural := 0;
      Back    : Natural := 0;       --  holding higher ground back
      Up      : Natural := 0;       --  holding the yard up
      Highest : Natural := 0;       --  blocks of stone in the tallest
      Blocks  : Natural := 0;       --  of stone in all of them
   end record;
   type Wall_Sides is array (1 .. 4) of Wall_Side;
   --  And what each column of stone on the rim stands on, by the stockyard's design: Way, a tread of
   --  its stair or its way in from the path; Clear, the ground before the line of its back wall (its
   --  staging and beside the storehouse's ends, where there are no places); Fenced, the line its
   --  fence stands on (the sides from that line back, and the back); Goods, anything else: a place's
   --  ground where goods lie with no fence on it.  Once it stands, read again from what is there:
   --  Seen_Fence, columns of rim stone with the fence's timber over them; Seen_Clear, with no place
   --  or one kept clear; Seen_Goods, on a place that holds goods and no fence over it.
   --  And its only stair, the flight of the way to its storehouse's door (a house's: Is_Stair, where
   --  the path lies more than a block off the storehouse's floor): Stair, block columns of its
   --  site that are a step of it, on the rim or not (Way_Stair: those of the rim's stone that are);
   --  Rise, blocks between the path and the floor there (0: none; under 0: the path lies higher).
   --  Way_End: where its way in is (0 the middle of the storehouse's front, 1 and 2 the low and the
   --  high end of the stockyard's front, a corner of the zone); Way_Deep, the block columns from the
   --  front wall's line to the path's edge there.
   type Yard_Walls is record
      Side  : Wall_Sides;
      Inner : Natural := 0;
      Way, Clear, Fenced, Goods : Natural := 0;
      Stair, Way_Stair : Natural := 0;
      Rise  : Integer := 0;
      Way_End  : Natural := 0;
      Way_Deep : Natural := 0;
      All_Blocks : Natural := 0;       --  blocks of stone in all its site's columns, on its rim or not
      Floor_Row  : Integer := 0;       --  the row of its floor's top
      Stands : Boolean := False;
      Seen_Fence, Seen_Clear, Seen_Goods : Natural := 0;
   end record;
   function Stockyard_Walls return Yard_Walls;
   --  (for the tools) **How the land lies along a stockyard's front, against its floor**: at the
   --  two ends of its front (the front corners of the zone: Store_Door_W_B block columns of it, a
   --  block column in from the side's rim) and at the middle of its storehouse's front: the top of
   --  the ground just outside its own there (its path's), over those columns, in blocks over its
   --  floor (under 0: under it): Least and Most, and Mid, at the middle of them; Rim_Least and
   --  Rim_Most, the same of its own outermost column there; Deep, the least block columns of its
   --  own ground before its front wall's line there.  Read from the world as it lies; all nothing
   --  with no storehouse begun.
   type Front_Spot is (Low_End, Front_Middle, High_End);
   type Front_Bank is record
      Read      : Boolean := False;
      Least     : Integer := 0;
      Most      : Integer := 0;
      Mid       : Integer := 0;
      Rim_Least : Integer := 0;
      Rim_Most  : Integer := 0;
      Deep      : Natural := 0;
   end record;
   type Yard_Front is array (Front_Spot) of Front_Bank;
   function Stockyard_Front return Yard_Front;
   --  (for the tools: colony_run --yard-map) Every block column of the storehouse's site, which is
   --  its stockyard's ground: where it is in the world, the row its top is to be brought to, the
   --  lowest row of it that is to be stone (over its top: none of it), the row of the floor's top,
   --  and whether it is of the way in from the path, and a step of its stair.
   procedure For_Yard_Plan
     (Visit : not null access procedure (Bx, By, Top, Stone, Floor : Integer; Way, Stair : Boolean));
   --  (for the checks) Its stair is dug by itself: every patch of the storehouse's ground (the square
   --  metre it is made ready by) that holds a step of the stair holds no block column beside the
   --  way in.  True with no storehouse begun or no stair.
   function Yard_Stair_Whole return Boolean;
   function Storehouse_Note return String;
   --  What the advisor would say, simulated: "" before the second morning;
   --  then that the storehouse is ordered on the Nth stockpile zoned
   --  (Stockpile_Number), or that a
   --  stockpile of 15 m by 15 m is wanted for it.
   function Storehouse_Note_Key return Natural;  --  moves when the note does
   function Stockpile_Number (Z : Positive) return Natural;
   --  Zone Z counted among the stockpiles, first zoned first (0: not one):
   --  what a note calls it, since the player sees no zone's number.
   --  A stockpile's ground reaches at least Stockpile_Least_M along its
   --  path and as far across it, or it is refused (John, 2026-11-17: "make
   --  the minimum zoning area 15x15m for the stockpile, it can be larger
   --  the workers will adapt, but that will fit the storehouse with the 5m
   --  of staging area at the front, the fence and coverings for the
   --  outdoor stocks").  Measured on the ground the lot fills (drawn out to
   --  its path), a block and a half spared for a lot that lies aslant the
   --  block grid.  Set_Stockpile_Least (0.0), --stockpile-least 0: any size, as
   --  before.  Saved with the colony.
   Stockpile_Least_M : constant := 15.0;   --  (the first pass's; since 2026-11-18 no least is set unless asked:
                                           --  the storehouse goes on a stockyard, and the player's stockpile is
                                           --  Stockpile_Side_M square)
   procedure Set_Stockpile_Least (Metres : Float);
   function Stockpile_Least return Float;
   function Stored (K : Item_Kind) return Natural;      --  in every stockpile
   procedure Supply (K : Item_Kind; N : Natural; Placed : out Natural);
   --  N of K put straight into the stockpiles (cells already holding K
   --  with room first, then empty ones), as if brought in: for scripted
   --  starts and the checks.  Placed: how many found room.
   function Cell_Count return Natural;

   --  The storehouse used (the stockpile's third pass, 2026-11-17; John:
   --  "When the stockhouse is completed, we upgrade a serf to manage the
   --  stockhouse, who will organize the stockpile, a carpenter will also
   --  come about from the builders ... A carpenter will build barrels and
   --  shelves in the storehouse, the stockman will pack the barrels with
   --  meat and salt, porters can also begin bringing water to stockhouse
   --  ... hides placed on the self.  We need to let the stockman pile the
   --  wood and straw under the coverings, and they need to extend across
   --  blocks so he can stack them higher ... we need to watch stone as
   --  well", and on the barrels: "barrels of water is not a good storage
   --  idea for berries and apples. So they can just be stacked in the
   --  baskets in the storehouse by the stockman").  When the storehouse
   --  stands its stockpile's places are fitted out (Fit_Storehouse): the
   --  places inside it on its plank floor, but the row by its door kept
   --  clear: along its long walls a shelf to each place for hides (two of
   --  Shelf_Places), in its two back rows barrels (Water_Barrels of them,
   --  the nearest its yard side, for water, the rest for meat), the rest
   --  floor for baskets (berries, apples, vegetables, grain) and sacks of
   --  salt; the yard's places under a covering hold Cover_Holds times as
   --  much wood, straw or stone, stacked higher; the places along the
   --  outside of its long wall on the yard's side a ladder each, leaned
   --  against the wall.  Shelves and barrels stand only once the carpenter
   --  has made them (Made).  A place fitted out takes only what it is for,
   --  and only from the stockman, but for water, which porters pour into
   --  the water barrels; anyone takes from any place.
   type Fitting is (Ground, Floor, Shelf, Meat_Barrel, Water_Barrel, Cover, Lean, Kept_Clear);
   --  (Kept_Clear: no place at all: the stockyard's staging, the ground beside the storehouse's ends,
   --  under its walls, and inside it by each door.  Saved by position.)
   Shelf_Places   : constant := 3;          --  a shelf along each long wall, 3 m
   Water_Barrels  : constant := 2;
   Cover_Holds    : constant := 3;          --  times a place's own, under a covering
   Shelf_Hides    : constant := 6;          --  hides a shelf's place holds (two to a board, three boards)
   Barrel_Meat_Lb : constant := 60;
   Barrel_Pails   : constant := 12;         --  pails of water (Carry_Limit (Water): two to a porter)

   type Cell_View is record
      Centre : Vec3;
      Kind   : Item_Kind;
      Count  : Natural;
      Turn   : Float;       --  the way its lot lies (radians): what is put there lies the same way
      Overflow : Boolean;   --  one of its stockpile's overflow places
      Closed : Boolean;     --  a place no more: the storehouse's ground (what is on it is taken away)
      Fit    : Fitting;     --  what it is fitted out as (Ground: an ordinary place)
      Made   : Boolean;     --  its shelf or barrel stands (the carpenter's)
      Second : Boolean;     --  a barrel's place: a second barrel stands on the first (Set_Store_Stacks)
      Wall   : Vec3;        --  a shelf's or a leaning ladder's wall: the point on it nearest the place's
                            --  middle, at the floor's or the ground's height
   end record;
   function Cell_At (K : Positive) return Cell_View;
   function Place_Limit (K : Positive; Kind : Item_Kind) return Natural;   --  the most place K holds of Kind

   --  **Food and full barrels stacked in the storehouse** (John, 2026-11-21: "Allow food and full
   --  barrels to be stacked in the storehouse").  A place on the storehouse's floor holds its
   --  baskets of food (berries, apples, vegetables, grain) Floor_Stack high: that many times a
   --  place's own.  A barrel's place takes a second barrel on the first once that one is full:
   --  the carpenter makes it there (a log and a barrel's work, after the shelves and the first
   --  barrels), and the place holds Barrel_Stack barrels' worth from then on; the lower one is
   --  shut.  How high are first values of mine, his calls.  Nothing else changes: the stockman
   --  puts a load in the nearest place that keeps it, as before, so with a higher place the food
   --  stands in fewer of them.  Set_Store_Stacks (False), --no-store-stacks: a place its own, one
   --  barrel to a place, as before 2026-11-21 (a second barrel that stands, stands).  Not saved;
   --  a second barrel is (2 in its place's byte for its barrel: blob 44 still).
   Floor_Stack  : constant := 3;
   Barrel_Stack : constant := 2;
   procedure Set_Store_Stacks (On : Boolean);
   function Store_Stacks return Boolean;

   --  **The stockyard's stair in a corner of the zone** (John, 2026-11-21: "The path level at one
   --  corner is great, move the stair to the opposite corner instead of the center, if a stair is
   --  to be had it's to be at the corner of the zone"; and, when that had been read of the square:
   --  "I was talking about the stockyard having the stair in the corner rather than the middle").
   --  A stockyard's way in from its path was the middle of its storehouse's front, two metres
   --  wide, across the staging, with a stair wherever the path lay more than a block off the
   --  floor there; the storehouse's doors are in its ends.  Now:
   --    * **The floor's level is chosen as it was**, by the land under the stockyard and by the
   --      path at the middle of its front, so the same places take a stockyard, at the same level.
   --    * **A stockyard that would have no steps at that middle is as it was**: its way in there.
   --    * **One that would have steps there has its way in at an end of its front instead, in a
   --      corner of the zone**: two metres wide, a block column in from the side's rim (the rim,
   --      walled where the land beside it stands over or under, is the stair's outer flank), a
   --      block a step from the path's edge inward, as many steps as there are blocks between the
   --      path and the floor at that end (two to eight), a landing at its foot.  Beside the
   --      storehouse's end no wall stands across it, so a flight longer than the staging is deep
   --      runs on past the line of the front wall.  The middle of the front is then rim like the
   --      rest of it: a wall of stone where the path lies more than a block off the floor.
   --    * **Which end.**  Where the path comes in level at one end (within a block of the floor
   --      there) and the other end takes a stair: the other, the opposite corner.  With a bank at
   --      both ends: the lower (of two as high the end nearer the homestake by a metre or more,
   --      else the end its design counts from: mine).  Where one end only takes a stair, that one.
   --      **Where an end is level and no end takes a stair, there is none**: the way in is the
   --      level end.  Where neither end is level or takes one (its path does not reach them, or
   --      lies over two metres off at both, or the flight has no room), the way and its stair stay
   --      at the middle.
   --    * Its ground is dug down the stair from the path and outward over the floor from the
   --      stair's foot, as ever; the lord's cart is brought before the storehouse's front where it
   --      was, and the ladder stood where it was.
   --  Only of a stockyard that is levelled (Set_Yard_Level): with that off a storehouse's ground is
   --  its own pad and the yard before its front, and its way in stays at the middle of its front.
   --  A storehouse keeps the way it was begun with (Castle.Buildings.House.Way_End, in two more
   --  values of its byte of blob 41: no new version; a blob of before reads as the middle).
   --  Set_Yard_Stair_Corner (False), --yard-stair-middle: at the middle, as it was.  Not saved.
   procedure Set_Yard_Stair_Corner (On : Boolean);
   function Yard_Stair_Corner return Boolean;

   --  **A stockyard's floor at its path's level at the lower corner of its front** (John,
   --  2026-11-22: "Set the floors level of the stockyard to the path level at the lower corner, the
   --  higher corner along the path gets the stairs", and "After 2m no stair built"; in answer to the
   --  calls of the rule above).  Of a stockyard that is levelled, its stair in a corner of the zone,
   --  whose path runs beside both corners of its front (one put down whole fronts its own path for
   --  all its length):
   --    * **Its floor lies at the level of the path at the lower of its front's two corners**, so
   --      that the path comes in level there, whatever the land does under the rest of it.  (It was
   --      chosen from the land under the stockyard, the highest level at which what is dug off
   --      fills its hollows, and held within three steps of the path at the middle of its front: a
   --      stockyard whose land lies further under its path than that was refused, and is taken now.
   --      A floor can stand over the land it was chosen on now, filled and held up by its walls,
   --      which no pad did before.)  Of two corners as low, the one nearer the homestake by a metre
   --      or more, else the end its design counts from.
   --    * **The stair stands at the other corner, the higher one along the path**, where the path
   --      lies two to eight blocks over the floor there: the way in is that end, down from the path.
   --    * **Over eight blocks, two metres, there is no stair**: the way in is the level corner.
   --    * Where the path lies within a block of the floor at the higher corner too, and at the
   --      middle of the storehouse's front, there is no stair and the way in is across the staging
   --      at that middle, as it always was on level ground; with a hump or a dip at the middle
   --      alone, the level corner.
   --  The path's level is read from the path's own nearest block column beside the way's two
   --  metres there, the middle one of them (its top where it is laid, the land on its line where it
   --  is still to lay), when the storehouse is begun, once: the floor's level and the row its way
   --  meets the path at are kept with it, as ever.  Where the path does not run beside both corners
   --  (a stockyard zoned between two corners beside a path that ends short of one), the floor and
   --  the way are judged as before.
   --  Set_Yard_Floor_Low (False), --yard-floor-by-land: the floor chosen from the land, its stair in
   --  a corner as the rule above alone puts it.  Not saved; nothing new is kept.
   procedure Set_Yard_Floor_Low (On : Boolean);
   function Yard_Floor_Low return Boolean;

   --  The stockman (John: "we upgrade a serf to manage the stockhouse, who
   --  will organize the stockpile"): when the storehouse stands, the living
   --  porter with the most portering is made its stockman, and another when
   --  it dies or is given other work (none while there is no porter).  With
   --  its hands empty, before a porter's work: a load out of the overflow
   --  into the stockpile; the lord's cart to the storehouse's front and its
   --  salt carried in, a sack at a time ("Stockman can bring the cart to the
   --  front of the storehouse, and unload all the salt into the
   --  storehouse"); then what lies in the yard's places that a place fitted
   --  out is for, a load at a time: baskets and salt into the storehouse,
   --  hides onto the shelves, meat into the barrels, wood, straw and stone
   --  under the coverings, ladders against the wall ("the ladders can be
   --  leaned up against the storehouse when not in use").  Whatever it
   --  carries goes to a place fitted out for it first.  Set_Stockman
   --  (False), --no-stockman: nobody is, and the places fitted out fill
   --  with water alone.  Saved.
   procedure Set_Stockman (On : Boolean);
   function Stockman_On return Boolean;
   function Stockman return Natural;            --  the member (0: none)
   function Cart_At_Storehouse return Boolean;  --  the lord's cart stands in the storehouse's staging, clear of its door
   --  (for the tools: there is a place before the storehouse's front that takes the lord's cart, as the
   --  ground lies now: Cart_Front.  False with no storehouse standing.)
   function Cart_Place_By_Storehouse return Boolean;
   --  **The cart's place before the storehouse is looked for** (2026-11-21).  It was one place: across
   --  the staging, hard by the way in, on the wider side of the yard; where its bed did not fit there
   --  (a bank beside it, a stair, the storehouse's own blocks at 45 degrees) the cart was never
   --  brought and its salt stayed in it: at four of nine test stockyards.  Now, where that place does
   --  not take it: along the front (which a staging of a metre and a half has room for), the other
   --  side of the way in, and further from the way a metre at a time; the first that fits.
   --  Set_Cart_Search (False), --one-cart-place: the one place, as it was.  Not saved.
   procedure Set_Cart_Search (On : Boolean);
   function Cart_Search return Boolean;

   --  The carpenter ("a carpenter will also come about from the builders,
   --  and a serf can take a builders spot"): when the storehouse stands, its
   --  builder (else the forester with the most building) is made the
   --  carpenter, and another forester when it dies or is given other work.
   --  It builds no house, so its place among the builders is another's.
   --  With its hands empty it takes a log from the stores (as a builder
   --  does: Free_For_Building) to the next shelf or barrel not yet made,
   --  the shelves first, and makes it there (Shelf_S, Barrel_S of work);
   --  with all made, it is a forester.  Set_Carpenter (False),
   --  --no-carpenter: none, and no shelf or barrel is made.  Saved.
   Shelf_S  : constant := 60.0;            --  colony seconds of work: a game hour a shelf's place
   Barrel_S : constant := 120.0;           --  and two a barrel
   procedure Set_Carpenter (On : Boolean);
   function Carpenter_On return Boolean;
   function Carpenter return Natural;           --  the member (0: none)

   --  Water ("porters can also begin bringing water to stockhouse"): once
   --  a water barrel stands, a porter with nothing else asked of it goes to
   --  the nearest water for two pails and pours them in, until the water
   --  barrels are full.  Nothing uses it yet.  Set_Water (False),
   --  --no-water: none is fetched.  Saved.
   procedure Set_Water (On : Boolean);
   function Water_On return Boolean;

   --  Grass in the air (John, 2026-11-17: "Grass in the air issue when
   --  compacting ground, grass is visible, not attached to the ground in
   --  places. Even before compacting. Investigate."): long grass two
   --  blocks high had its lower block cut, and the upper left standing on
   --  air, wherever only the block over the ground was cut: a stockpile's
   --  places cleared when it is zoned, a path laid, a yard's ground beaten,
   --  and a porter cutting straw (the block it found, often the lower).
   --  The first three now cut the whole of a plant (Cut_Plants), which
   --  moves no run; a porter cuts the top block of a tuft first
   --  (Set_Top_Cut), which moves the runs a porter cuts straw in (which
   --  block is left for the next cut).  Set_Top_Cut (False), --no-top-cut:
   --  the block found, as before.  Saved with the colony.
   procedure Set_Top_Cut (On : Boolean);
   function Top_Cut return Boolean;

   --  For measuring what a full stockpile costs (colony_run --store-stats;
   --  not saved, and nothing is decided by it): the colony seconds the
   --  living have stood with a load and nowhere to put it (Holding_S), and
   --  with empty hands for want of room for what they would bring in
   --  (Roomless_S), since the colony was founded or loaded; the clock
   --  (hours, as Advance is given it) when a load first found no place
   --  (below 0: never); loads sent to an overflow place; and the most
   --  overflow places holding something at once (looked at once a second).
   type Per_Kind_Seconds is array (Item_Kind) of Float;
   type Store_Stats is record
      Holding_S, Roomless_S : Float := 0.0;
      First_Full : Long_Float := -1.0;
      Overflow_Loads, Overflow_Most : Natural := 0;
      Overflow_Moves : Natural := 0;   --  loads taken out of the overflow to be put in the stockpile
      Busy_S : Float := 0.0;           --  colony seconds the overflow held something (nothing brought in)
      Holding_Of : Per_Kind_Seconds := [others => 0.0];   --  Holding_S, by what was held
   end record;
   function Store_Counts return Store_Stats;

   ------------------------------------------------------- bushes

   Regrow_Days   : constant := 6.0;
   Pick_S        : constant := 1.5;    --  seconds a handful
   Work_Radius_M : constant := 60.0;   --  how far from the stake work is looked for
   function Bush_Count return Natural;                 --  bushes (one across a stack edge is one)
   function Bush_Slots return Natural;                 --  K in 1 .. Bush_Slots for the ones below
   function Bush_Alive (K : Positive) return Boolean;  --  false: joined into another
   function Ripe_Bushes return Natural;
   function Berries_Left return Natural;   --  handfuls on every known bush
   function Bush_Centre (K : Positive) return Vec3;
   function Bush_Radius (K : Positive) return Float;
   function Bush_Ripe (K : Positive) return Natural;
   function Bush_Reserved_By (K : Positive) return Natural;   --  0: nobody
   --  A bush takes as many pickers at once as it has basketfuls of ripe
   --  berries on it (a basket is Carry_Limit (Berries); one picker at the
   --  least).  Until 2026-11-18 a bush was one gatherer's while it picked
   --  there, and the rest of a band of eight stood by a bush of a hundred
   --  handfuls with "nothing to gather in reach" (John, 2026-11-17:
   --  "Gatherers can't find berries even when they are close").
   --  Set_Bush_Sharing (False), --one-to-a-bush: one, as before.  Saved.
   procedure Set_Bush_Sharing (On : Boolean);
   function Bush_Sharing return Boolean;
   procedure Index_All;
   --  Look through every loaded stack in reach of the stake for bushes now
   --  (otherwise a few stacks a step, nearest first).

   ------------------------------------------------------- gathering: what, and how far

   --  Gatherers pick berries off bushes, pull wild vegetables (a plant
   --  each, Castle.Blocks.Wild_Vegetables) and, from summer's tenth day to
   --  the end of autumn (Apples_From_Day .. Apples_To_Day), pick apples off
   --  apple trees.  What a gatherer goes for is one score: the way there,
   --  and half the way from the stake, over its pull.  Berries pull 1,
   --  apples Apple_Pull (fruit last).  Vegetables, the cook's best greens,
   --  pull Veg_Pull (a little further is worth it); half as much again when
   --  the band has less than a day's food stored (none of that at two
   --  days), and up to twice that again as the vegetables in store fall
   --  short of their reserve.  Their reach grows the same way, from
   --  Work_Radius_M by up to 10 m for each, to Forage_Reach_M at most.  With
   --  no vegetables in store at all a gatherer goes for nothing else while
   --  there are any in reach.  A basket part full is filled with the same.
   --  A vegetable pulled grows back in Veg_Regrow_Days (not in winter); an
   --  apple tree bears about Apple_Yield apples a year.
   Veg_Pull        : constant := 1.3;
   Apple_Pull      : constant := 0.9;
   Forage_Reach_M  : constant := 80.0;
   Veg_Regrow_Days : constant := 10.0;
   Apples_From_Day : constant := 25.0;
   Apples_To_Day   : constant := 45.0;
   Apple_Yield     : constant := 40;
   function Apples_Left return Natural;     --  on the apple trees in reach, now (0 out of season)
   function Vegetables_Pulled return Natural;   --  all told

   ------------------------------------------------------- trees and logs

   function Chop_S (T : Tree_Info) return Float;   --  seconds of chopping to fell it
   function Logs_Of (T : Tree_Info) return Positive;   --  logs it comes down as
   function Tree_Count return Natural;
   function Tree_At (K : Positive) return Tree_Info;
   function Tree_Base (K : Positive) return Vec3;      --  the middle of the trunk, on the ground
   function Tree_Down (K : Positive) return Boolean;
   function Tree_Reserved_By (K : Positive) return Natural;
   function Trees_Felled return Natural;
   --  How far the foresters go for a tree (John, 2026-11-19: "Still having
   --  issues with the foresters not finding trees in range").  A felled
   --  tree does not grow back, so the trees within Work_Radius_M of the
   --  stake are used up as the band builds (at the reference site, a band
   --  of thirteen with housing and a storehouse: none left by the hundred
   --  and thirtieth day, 189 standing 60 to 80 m off, and no log in the
   --  stores from then on), and a stake on open land has few to begin with.
   --  So a forester with no tree left to fell that near that it can get to
   --  looks a ring further (Reach_Step_M), and another, as far as
   --  Fell_Reach_Max_M from the stake: Fell_Reach_M is how far the foresters
   --  look now (Work_Radius_M until one has looked further; it never comes
   --  back in: nothing grows back).  A tree somebody else is felling is no
   --  reason to look further.  A tree there is no way to (across a river)
   --  is asked of the walking map's pieces of ground alone and then left
   --  untried by everyone for Tree_No_Way_S, so a wood out of reach costs
   --  a look a tree and nobody stands trying it; and one that can be got
   --  to only by a long way round (Fell_Budget) is left the same way, for
   --  Tree_Round_S: a forester does not walk 330 m round by a ford for a
   --  tree 70 m off.  The colony's ground reaches as far
   --  (Ground_Reach_M).  Among the trees in reach the choice is as it was
   --  (the way there and half the way from the stake), so a nearer tree
   --  is still the first felled.  Set_Wood_Reach (False), --no-wood-reach:
   --  no further than the work radius, as it was.  Saved with the colony.
   Fell_Reach_Max_M : constant := 250.0;      --  (John, 2026-11-19: "Let workers go 250m for resources, wood is a
                                              --  vital resource"; it was 124 m, a first value of mine)
   Tree_No_Way_S    : constant := 1_440;        --  colony seconds a tree no forester could get to is left untried
   Fell_Tries       : constant := 32;         --  trees a forester asks its way to in one thought, at the most
   Ask_Tries        : constant := 16;         --  bushes, or places to fetch from, a gatherer or a porter asks its
                                              --  way to in one thought (Set_Ways_Told)
   Fell_Budget      : constant := 4_000;      --  floors a search for the way to a tree may look at, and
   Fell_Budget_M    : constant := 300.0;      --  this many more for each metre it stands off (measured: a
                                              --  straight way of 125 to 145 m took 100 to 205 a metre, one
                                              --  round by a ford 570 and more)
   Tree_Round_S     : constant := 14_400;     --  colony seconds a tree with only a long way round is left untried
                                              --  (ten days: such a search is dear, 40 ms for a tree 250 m off)
   Fell_Round_Tries : constant := 2;          --  such trees found in one thought, at the most
   procedure Set_Wood_Reach (On : Boolean);
   function Wood_Reach_On return Boolean;
   function Fell_Reach_M return Float;
   --  The same for what gatherers and porters bring (John, 2026-11-19: "Let
   --  workers go 250m for resources"): a gatherer that finds nothing to
   --  gather in reach (no ripe bush, no apples, no vegetables: not when the
   --  bushes are only taken, or it is winter, or the stores have no room),
   --  and a porter that finds none of what it is sent for, looks a ring
   --  further the next time, to Fell_Reach_Max_M at the most:
   --  Food_Reach_M and Haul_Reach_M are how far each looks now.  Neither
   --  comes back in.  Bushes are looked for as far as the gatherers look
   --  (they were looked for no further than Forage_Reach_M).  One whose
   --  nearest is out of reach across water does not look past it yet (the
   --  foresters do).  The same switch (Set_Wood_Reach).  Saved (blob 35).
   function Food_Reach_M return Float;
   function Haul_Reach_M return Float;
   procedure Set_Wood_From (Metres : Float);
   --  For measurements and the checks, as Set_Stone_From is: the foresters
   --  leave alone any tree nearer the stake than this, as if the nearest
   --  wood stood that far off (0, the default: none is left).  Saved.
   function Trees_Left_Untried return Natural;   --  standing trees no forester tries now (no way, or a long way round)
   type Pile_View is record
      Centre : Vec3;
      Turn   : Float;      --  the way the logs lie (radians)
      Count  : Natural;
      Owner  : Natural;    --  the forester who felled it (0: nobody's)
   end record;
   function Pile_Count return Natural;
   function Pile_At (K : Positive) return Pile_View;
   function Logs_Lying return Natural;                 --  in every pile, not yet carried off

   ------------------------------------------------------- standing orders

   procedure Set_Protect_Apples (On : Boolean);   --  apple trees are never felled (default on)
   function Protect_Apples return Boolean;
   procedure Set_Wood_Reserve (Logs : Natural);
   --  The surplus of logs to keep (Set_Reserve (Wood, Logs)).  Before the
   --  demand chain, and with it off, 0 was no limit.
   function Wood_Reserve return Natural;
   function Wood_Total return Natural;

   type Per_Kind is array (Item_Kind) of Natural;
   Default_Reserve : constant Per_Kind := [Wood => 20, Straw => 20, Meat => 20, Vegetables => 40, others => 0];
   procedure Set_Reserve (K : Item_Kind; N : Natural);
   --  A surplus to keep in store, on top of what is used: the order's row
   --  of the demand table (see demand).  Counted with what is carried and
   --  on its way (a carcass lying or carried counts its meat; logs lying
   --  count).  Vegetables: below it gatherers also go further for them (see
   --  gathering).  Wood: Set_Wood_Reserve is the same.
   function Reserve_Of (K : Item_Kind) return Natural;
   function Have (K : Item_Kind) return Natural;   --  stored and carried

   --  What is wanted for a use: porters fetch stone, after straw, until
   --  the colony has as much as is wanted.  A colony starts wanting
   --  Stone_Quota (for paving the paths, once there are masons); the work
   --  that uses it (paving) will ask for more with Want and take it away
   --  as it is used.
   Stone_Quota : constant := 20;
   procedure Want (K : Item_Kind; N : Natural);   --  N more of K wanted
   function Wanted_Of (K : Item_Kind) return Natural;

   --  Grain is a by-product of straw: a porter cutting straw cuts wild
   --  grain as readily as tall grass (the whole stalk, to the ground), and
   --  each plant of grain gives, with its sheaf of straw, Grain_Per_Plant
   --  handfuls of grain.  The grain rides home with the straw and goes into
   --  a stockpile cell of its own when the straw is put down (kept by the
   --  porter till there is room).  It is not eaten raw; the cook puts it in
   --  the pot after the vegetables, berries and apples are gone.
   Grain_Per_Plant : constant := 2;
   function Grain_Carried (I : Positive) return Natural;   --  with its straw

   Fetch_S : constant array (Item_Kind) of Float :=   --  seconds to get one
     [Straw => 0.8, Stone => 2.0, Water => 2.0, Vegetables => 2.5, Sticks => 20.0, others => 1.0];

   ------------------------------------------------------- needs: eating and sleeping

   --  Everyone eats and sleeps, on the game clock (the Hours Advance is
   --  given: a game minute to a colony second at the game's normal
   --  timescale).  Food is counted in points.  An adult eats Day_Food
   --  points a game day, a child 60 % of that, an elder 80 %.  Each holds
   --  Belly_Hours of food; once down to Hungry_At of it, at the next break
   --  in its work it eats.  Stew from the pot at the camp comes first (it
   --  takes a bowl and sits at the fire to eat it); without stew it eats
   --  raw: what it carries if that is food, else from the nearest stockpile
   --  cell of food, apples first, then berries, then vegetables (the cook's
   --  best greens are left to last).  What it will eat is set aside for it
   --  on the way.  Raw food fills a belly poorly (Raw_Food); the same food
   --  cooked into stew goes much further (Stew_Food).  Meat is never eaten
   --  raw.  At Very_Hungry it stops what it is doing to eat (never a load
   --  in its arms or a butchering: those are finished first).  With no food
   --  to be had it goes on working, hungry; once its belly is empty it is
   --  starving, and walks and works at Starving_Pace until it has eaten.
   --
   --  At night, from Bed_Hour (children an hour earlier, elders half an
   --  hour) to Wake_Hour, give or take a little for each, everyone puts
   --  down what it carries, eats supper unless it is nearly full
   --  (Supper_At), goes to its own place round the fire (round the stake
   --  while there is no camp) and sleeps.  Asleep, it gets hungry half as
   --  fast.
   Day_Food      : constant := 240;     --  points a game day, an adult (docs/systems/needs.md, "How it was tuned")
   Belly_Hours   : constant := 10.0;    --  hours of food it holds
   Hungry_At     : constant := 0.4;     --  of a full belly: eats at the next break
   Very_Hungry   : constant := 0.15;    --  stops work to eat (if there is food)
   Supper_At     : constant := 0.85;    --  at bedtime it eats first, below this
   Starving_Pace : constant := 0.6;     --  of its pace and work, with an empty belly
   Bed_Hour      : constant := 21.0;
   Wake_Hour     : constant := 5.5;
   Raw_Food  : constant array (Item_Kind) of Natural := [Berries => 1, Vegetables => 3, Apples => 2, others => 0];
   function Stew_Food (K : Item_Kind) return Natural;
   --  points an item gives, eaten raw / cooked into stew (meat's: a pound's,
   --  Pound_Stew, or with curing off a joint's, as in the table)
   Stew_Table : constant array (Item_Kind) of Natural :=
     [Meat => 30, Vegetables => 8, Berries => 3, Apples => 5, Grain => 4, others => 0];

   --  Fending for itself: once its belly is down to Very_Hungry with no
   --  stew to be had, no food in the stockpiles and none in its hands, a
   --  member leaves its job and gathers for itself (what a gatherer would
   --  go for), eating it as soon as it has enough, and its own work waits.
   --  In winter, a member whose belly has been empty for Death_Hours dies
   --  of hunger (it lies where it fell).
   --
   --  Mood: each member's eases, over about Mood_Hours, toward how it is
   --  living: Mood_Stew fed on stew, Mood_Raw fed on raw food, Mood_Hungry
   --  hungry, Mood_Starving starving, nothing at all while it has to fend
   --  for itself; and starting to fend takes Mood_Fend off at once.  A
   --  death takes Mood_Grief off everyone.  The band's confidence in the
   --  player is the mean of the living's moods: that is what the player is
   --  shown, not each one's.
   Death_Hours   : constant := 48.0;
   Mood_Hours    : constant := 12.0;
   Mood_Stew     : constant := 0.8;
   Mood_Raw      : constant := 0.55;
   Mood_Hungry   : constant := 0.35;
   Mood_Starving : constant := 0.1;
   Mood_Fend     : constant := 0.1;
   Mood_Grief    : constant := 0.25;
   Mood_Start    : constant := 0.7;

   --  Winter.  Nothing is gathered in winter: the berries are gone and the
   --  roots lie under the snow (hunting goes on).  So the band lives on
   --  what it stored, and the winter store is the order for that: outside
   --  winter, Winter_Store days of the band's food are held back in the
   --  stockpiles, the kinds that keep first (grain, apples, meat, then
   --  vegetables and berries), and neither the cook nor anyone eating raw
   --  touches them; gatherers work as if that food were not there.  The
   --  store is built from surplus: a day's food (the pot and the stockpiles
   --  together) is never held, so ordering a store starves nobody.  Only
   --  someone starving who has found nothing to gather breaks into it.  In
   --  winter the hold lifts by itself.
   --
   --  The fire is kept in all day and night in winter (six logs a day), and
   --  the cook fills its stack before anything else.  Anyone asleep in
   --  winter away from a burning fire is cold: it gets hungry at the waking
   --  rate, not half, and its mood can rise no higher than Mood_Cold.
   Mood_Cold : constant := 0.3;
   --  Orders of preference, and the rest of the needs' tunables.
   type Kind_List is array (Positive range <>) of Item_Kind;
   Raw_Order    : constant Kind_List := [Apples, Berries, Vegetables];        --  eaten raw: first to last
   Greens_Order : constant Kind_List := [Vegetables, Berries, Apples, Grain]; --  the pot's greens: first to last
   Keep_Order   : constant Kind_List := [Grain, Apples, Meat, Vegetables, Berries];   --  held for winter: first to last
   Fetch_Order  : constant Kind_List := [Straw, Stone];                       --  what porters fetch, first things first
   Free_Day        : constant := 1.0;    --  days of food the winter store never holds back
   Eat_Base_S      : constant := 8.0;    --  seconds a meal takes, and
   Eat_Per_Point_S : constant := 0.25;   --  more for each point of food

   --  Fixed capacities (raise them with the population target of a phase).
   Max_Paths       : constant := 256;
   Max_Bushes      : constant := 4_096;
   Max_Bush_Blocks : constant := 160;    --  blocks to a bush
   Max_Trees       : constant := 8_000;   --  (4,096 until the foresters went 250 m; a tree's fail memo is
                                          --  8,192 and its number: under the piles' 16,384)
   Max_Piles       : constant := 512;    --  log piles
   Max_Carcasses   : constant := 32;
   Max_Arrows      : constant := 16;
   Max_Pulled      : constant := 4_096;  --  vegetables pulled, waiting to grow back
   Max_Zones       : constant := 256;    --  stockpiles and the camp
   Max_Zone_Runs   : constant := 32_768; --  the strips of ground all the zones are kept as
   Max_Plan_B      : constant := 400;    --  block columns each way a lot is worked out over (Max_Lot_M at any turn)
   Max_Plan_Runs   : constant := 8_192;  --  strips of ground to one lot
   Patch_Span      : constant := 7;      --  metres each way of the fire the camp's ground is made ready in (6 until
                                         --  2026-11-21: the wider square's floor, and a wall outside it, reach further)

   procedure Set_Winter_Store (Days : Natural);   --  0 (the default): nothing held back
   function Winter_Store return Natural;
   function Store_Held_Days return Float;         --  held back now, in days of the band's food

   --  What the cook keeps for the pot (John, 2026-11-12: "rather than
   --  waiting for the cook to use the stockpile to cook food, the serfs
   --  were eating raw directly from the stockpile preventing food from
   --  being cooked, can the cook reserve food in the stockpile and only
   --  suprlus is availible to eat raw if no stew is present").  While the
   --  camp's hearth stands and the band has a living cook, a pot's fill of
   --  what is stored is the cook's (Cook_Keeps points as stew, whatever is
   --  in the pot already: the next pot's): meat for half of it while there
   --  is meat, and for the rest greens in the cook's own order
   --  (Greens_Order), from what the winter store does not hold.  Nobody
   --  eating raw touches those greens: only what is over is eaten raw, and
   --  only with no stew to be had, as before.  Someone starving who has
   --  found nothing to gather breaks into them, as into the winter store
   --  (a serf won't let itself starve).  Before the hearth stands, and in a
   --  band with no cook, nothing is kept: there is nobody to cook it.  What
   --  a serf carries is its own to eat, as it was.  First values, his to
   --  tune: the size of it and who may break into it.
   Cook_Keeps : constant := 900;                  --  points as stew: a pot's fill (Pot_Points)
   procedure Set_Cook_Hold (On : Boolean);        --  off: the stores as they were before the cook kept anything
   function Cook_Holds return Boolean;
   function Cook_Held (K : Item_Kind) return Natural;   --  of K, kept for the pot now
   function Cold (I : Positive) return Boolean;

   procedure Set_Source_Memos (On : Boolean);
   --  On (the default): what a search for the nearest straw, stone, water
   --  or wild vegetables found in a stack is kept until that stack's ground
   --  (or the ground just beside it) changes.  Off: every search reads the
   --  ground again, as it always did; the same places are found either way
   --  (for checks and for measuring).  Not saved.

   procedure Set_House_Memos (On : Boolean);
   --  On (the default): a house's blueprint is kept while it is the one
   --  being asked about, and a search for a lot that found none is not made
   --  again until a zone, a path or a house has changed.  Off: both are
   --  worked out every time, as if nothing were kept; the same houses come
   --  out either way (for checks and for measuring).  Not saved.

   procedure Set_Needs (On : Boolean);
   --  On (the default): the band eats and sleeps.  Off: nobody does (for
   --  checks of the work alone).  Saved with the colony.
   function Needs return Boolean;
   function Fed_Of (I : Positive) return Float;     --  0 (starving) .. 1 (full)
   function Hungry (I : Positive) return Boolean;   --  down to Hungry_At or below
   function Asleep (I : Positive) return Boolean;
   function Fending (I : Positive) return Boolean;
   function Mood_Of (I : Positive) return Float;    --  0 .. 1
   function Confidence return Float;                --  0 .. 1: the living's mean mood
   function Dead (I : Positive) return Boolean;
   function Living return Natural;
   function Deaths return Natural;                  --  all told
   function Eaten return Natural;                   --  food points eaten, all told
   function Food_Days return Float;
   --  The food stored and in the pot, in days of what the band eats (0 with
   --  no band): stew as it is, the rest as the cook would make it into stew
   --  while there is a cook and a camp, raw otherwise.

   ------------------------------------------------------- the camp and the cook

   --  The camp is a zone the player marks: a Camp_Size_M square with the
   --  fire in its middle, in a ring of fieldstones, and over it the iron
   --  pot the band brought with them, hung from a crossbar.  Seat logs go
   --  round the fire (Seat_Logs of them, two places each), and the band
   --  sleeps round it.  One camp to a colony.
   --
   --  It is built, not conjured (John, 2026-11-10: "the fire just doesn't
   --  magically appear, they build it, the current model comes into
   --  existent after they deliver stone and wood to build it ... they also
   --  need to prepare the ground, compacting the earth around the campfire
   --  grass disappears").  Zoning it marks where; then the band builds it,
   --  as its own need: anyone with empty hands and nothing more pressing
   --  (eating, sleeping) turns to it before its job.
   --    the ground   made ready a square metre at a time (Tamp_S a visit),
   --                 from the fire outward: what grows on the camp's
   --                 ground is cut, and within Hearth_Ground_M of the fire
   --                 (its floor) the ground is made level and the turf
   --                 trodden to bare earth
   --  The floor is levelled (John, 2026-11-11: "I have tested it on uneven
   --  ground, and it causes some issues with the logs and such, so I think
   --  we need to have them level the terrain at least for the compacted
   --  part, they can move the dirt to the stockpile").  Its level is chosen
   --  when the camp is marked: the highest at which the earth dug off what
   --  stands above it, with the turf cut off the rest (a block of earth for
   --  every Sod_Share block columns of it), is at least what the hollows
   --  below it take, so the earth for them is always there.  Whoever makes
   --  a square metre of it ready digs off what stands above the level, a
   --  basketful a visit (Carry_Limit (Earth) blocks), cuts its turf (which
   --  lies there, for filling: it is never carried off), and fills its
   --  hollows with the earth in its hands.  What earth is left in them it
   --  carries to another hollow of the floor if one wants it, else to the
   --  stockpile, where it is heaped as earth (with nowhere to put it, it
   --  is thrown aside).  Once nothing is left to dig off, the hollows still
   --  there are filled with the turf's earth, and then from the
   --  stockpile's; with none to be had anywhere a hollow is left.  Rock is
   --  not dug: a column of it stands as it is.  The fire's place follows
   --  its ground.
   --    stone        Hearth_Stones for the ring: from the stockpile if it
   --                 holds any, else prised off the nearest boulder by
   --                 whoever goes for it
   --    wood         Hearth_Wood pieces for the crossbar: a log from the
   --                 stockpile, carried by one whose work logs are (the
   --                 cook, a forester); from anyone else, or with none
   --                 stored, an armful of deadwood from under the nearest
   --                 tree (never by a porter: porters carry no wood)
   --  With the ground ready and both delivered the hearth stands: the
   --  ring, the crossbar, and the pot with them (the pot is the band's own
   --  and needs no making).  The seat logs are laid as soon as there are
   --  logs in the stockpile, by the cook and by a forester, before anything
   --  else of their own: the hearth does not wait for them, nor they for
   --  the cook to have nothing else to do.  What
   --  the building still takes is asked of the stores as well (a zone's
   --  rows of the demand table), so porters and foresters bring it in.
   --  With the camp's labour off (Set_Labour) it stands the moment it
   --  is zoned, the grass on it cut, as it used to.
   --
   --  The cook keeps it.  First the fire.  A log on it burns Log_Hours;
   --  then the fire dies down for Die_Down_Hours more, its flames sinking
   --  to embers, and all that while a log put on it takes at once and it is
   --  away again: that is when it is restoked.  After that it is out.  It is
   --  tended by hand: nothing goes on it but what someone puts there.  The
   --  cook sees to it whenever it is wanted and there is not enough on it:
   --  for cooking (enough to see a pot through); for the night, from
   --  Stoke_Ahead_Hours before bedtime (enough that it burns, or at least
   --  glows, till waking: a log at bedtime lasts the night and leaves embers
   --  to restoke in the morning); and in winter, when it is kept in all day,
   --  as soon as it begins to die down.  A fire dying down still warms those
   --  asleep round it; it does not cook.  Logs come from the stockpile and
   --  are stacked by the fire (Fire_Stack), and the cook stokes it from the
   --  stack; with no logs stored it picks up an armful of dead sticks under
   --  the nearest tree instead (Sticks_Hours), for cooking only, so a band
   --  without a forester can still cook.  Then the pot: once the stew in it
   --  is down to Pot_Low, the cook fetches what to make more with from the
   --  stockpile, a load at a time: meat for up to half the pot, the rest
   --  vegetables, or berries when there are no vegetables, or apples after
   --  those; all meat or all greens when that is all there is.  It stirs
   --  it over the fire for Cook_Hours (at its work rate), and the pot holds
   --  Stew_Food points for each thing put in, a quarter more again for a pot
   --  of meat and greens together (Balanced_Bonus), and more or less by how
   --  good a cook it is (Pot_Yield_Of).  Once the fire has wood and the pot stew, it
   --  lays the seat logs (logs from the stockpile).  With nothing to cook
   --  it goes out gathering till there is.
   --
   --  Nobody need be told to cook: once there is a camp and something to
   --  cook, and nobody has ever been the cook, the best cook in the band
   --  takes it up on its own (Cooking_Of; the player can change it after).
   --
   --  (John, 2026-11-10: "fire life needs to be extended to about 8hours
   --  with a 3 hour diedown for restoking".  Before that, and still with the
   --  camp's labour off (Set_Labour), a log burnt Instant_Log_Hours and
   --  the fire took one off its stack by itself whenever it burnt out while
   --  it was wanted.)
   Camp_Size_M    : constant := 7.0;
   Hearth_Stones  : constant := 10;      --  fieldstones for the fire's ring
   Hearth_Wood    : constant := 3;       --  pieces of wood for the crossbar (two posts and the bar)
   Hearth_Ground_M : constant := 2.6;    --  the camp's floor: level, its turf cut off, this far round the fire
   Sod_Share      : constant := 2;       --  block columns of turf cut off the floor that make a block of earth
   Hollow_Most    : constant := 64;      --  block columns a hollow in the ground may take (four square metres:
                                         --  a hovel's pad and a path fill one, as of 2026-11-13; more is low ground)
   Hollow_Reach_B : constant := 10;      --  and how far round a metre of path one is looked for (block columns),
   Hollow_Rise_B  : constant := 4;       --  and the most a column of path is raised to fill one (a metre)
   Tamp_S         : constant := 4.0;     --  seconds to make a square metre of the camp's ground ready
   Patch_Reach_M  : constant := 1.6;     --  it is worked from this near its middle, if no nearer can be got to
                                         --  (a bank is dug from the foot of it)
   Seat_Logs      : constant := 4;
   Seat_R         : constant := 2.0;     --  seat logs this far from the fire
   Fire_Stack     : constant := 4;       --  logs stacked by the fire, at most
   Log_Hours      : constant := 8.0;     --  a log's burning
   Die_Down_Hours : constant := 3.0;     --  then it dies down this long, and can be restoked on its embers
   Stoke_Ahead_Hours : constant := 2.0;  --  the fire is seen to for the night from this long before bedtime
   Fire_Sink_Hours   : constant := 1.0;  --  its flames sink through its last hour of wood, to
   Ember_Heat        : constant := 0.45; --  this much of its full heat as the die-down begins
   Instant_Log_Hours : constant := 4.0;  --  with the camp's labour off: a log's burning as it was
   Sticks_Hours   : constant := 1.5;
   Cook_Hours     : constant := 1.0;
   Pot_Points     : constant := 900;
   Pot_Low        : constant := 450;
   Balanced_Bonus : constant := 1.25;

   procedure Zone_Camp (Centre : Vec3; Ok : out Boolean);
   --  The camp round Centre (a point on the ground, metres): marked, to be
   --  built by the band.  Refused (Ok False) once there is one, or where
   --  its ground anywhere is more than a metre above or below the middle's,
   --  or anything but grass stands on it (a tree, a bush, a stone, the
   --  stake, water), or a stockpile cell is on it, or a path or a zone
   --  comes within Camp_Clear_M of the fire.
   function Camp_Refusal return String;   --  why the last Zone_Camp was refused ("" if it was not)
   function Has_Camp return Boolean;
   procedure Stoke (Hours : Float);
   --  The camp's fire given Hours more of burning, as if wood had just
   --  gone on it; nothing is taken from any store.  A camp not built yet
   --  is built on the spot for it (its ground made ready, its hearth
   --  standing), as Supply conjures goods.  For scripted starts (--stoke)
   --  and the checks: a fire to look at without waiting for the band.
   --  Nothing without a camp.
   procedure Build_Camp_Now;
   --  The camp built on the spot: its ground ready, its hearth standing,
   --  nothing taken from anywhere.  For scripted starts (--camp-built) and
   --  the checks, as Supply is.  Nothing without a camp, or with one built.
   function Camp return Vec3;             --  the fire, on the ground
   type Camp_View is record
      Built    : Boolean := False; --  its hearth stands (the ring, the crossbar, the pot)
      Ground_Left : Natural := 0;  --  square metres of its ground still to be made ready
      Stones   : Natural := 0;     --  delivered for the ring, of Hearth_Stones
      Frame    : Natural := 0;     --  pieces of wood delivered for the crossbar, of Hearth_Wood
      Looking  : Float   := 0.0;   --  how far the band is looking for those (Looking_M)
      To_Dig   : Natural := 0;     --  blocks of earth still to dig off its floor, to level it
      To_Fill  : Natural := 0;     --  blocks its hollows still take
      Floor_Z  : Float   := -1.0;  --  the height its floor is levelled to (-1: left as it lies)
      Seats    : Natural := 0;     --  seat logs laid
      Logs     : Natural := 0;     --  stacked by the fire
      Fuel_H   : Float   := 0.0;   --  hours the fire burns on what is on it
      Burning  : Boolean := False;
      Dying    : Boolean := False; --  burnt out and dying down: embers, to be restoked
      Ember_H  : Float   := 0.0;   --  hours of the die-down left
      Heat     : Float   := 0.0;   --  how well it burns, 0 (out) .. 1
      Stew     : Natural := 0;     --  points ready in the pot
      In_Pot   : Natural := 0;     --  points of what is in it, not yet cooked
      Stirring : Boolean := False;
      Burnt    : Natural := 0;     --  logs the fire has taken, all told
      Set_Aside : Natural := 0;    --  of the stew, points promised to people on their way for a bowl
   end record;
   function Camp_State return Camp_View;

   procedure Set_Labour (On : Boolean);
   --  On (the default): what the player marks takes the band's labour: the
   --  camp is built and its fire tended by hand, as above, and paths are
   --  laid by the band (see paths).  Off: the colony as it was before any
   --  of that, for the older checks and reference logs: the camp stands
   --  and a path is laid the moment it is marked, and the fire feeds itself
   --  from its stack, a log every Instant_Log_Hours, with no dying down.
   --  Saved with the colony.
   function Labour return Boolean;

   --  Extra tasks: what the band does that is nobody's job (the camp's
   --  building, the paths' laying).  (John, 2026-11-11: "we should limit
   --  the amount of workers that can perform extra tasks".)  At most
   --  Extra_Hands are at them at once: one in Extra_Share of the living, at
   --  least one, unless a number has been set.  Whoever has a job turns to
   --  an extra task only while fewer than that are at them; the rest go on
   --  with their work.  Someone with no job never waits for a place (it has
   --  nothing else to do), but counts as a hand, at a task yet or not: while
   --  the idle are enough, nobody leaves a job.  The camp's building is the cook's own work, not
   --  an extra task for it: the cook neither waits nor counts there (at a
   --  path it is a hand like any other).  A load already in hand for the
   --  camp is always carried there.
   Extra_Share : constant := 3;
   procedure Set_Extra_Hands (N : Natural);
   --  At most N at extra tasks at once (0: by the rule above; Max_Members:
   --  everyone, as it was before there was a limit).  Saved with the colony.
   function Extra_Hands return Natural;   --  the limit now
   procedure Set_Levelling (On : Boolean);
   --  On (the default): a camp marked from now on has its floor levelled by
   --  the band, as above.  Off: its ground is left as it lies, as before
   --  2026-11-11, for the older reference logs.  Saved with the colony.
   function Levelling return Boolean;
   function At_Extra return Natural;      --  how many hands are at extra tasks now (the cook at its camp not counted)

   --  How far the band goes for what its camp's building takes: as far as
   --  it has to (John, 2026-11-10: "Don't place a distance limit on initial
   --  gathering, if they have to walk 200m to get stone they walk 200m").
   --  Its work is looked for within Work_Radius_M of the stake, and so
   --  first are the camp's stone and deadwood.  When all the ground that
   --  near has been looked through and holds none that can be got at, the
   --  band looks further: Reach_Step_M more at a time, each ring looked
   --  through before the next, until there is some or Far_Reach_Max_M is
   --  reached (which is as far as the ground can be kept in: the engine's
   --  limit, not a rule).  Whoever is free goes for it, however far; the
   --  rest go on with their work meanwhile.  Once the camp stands and
   --  everyone is back within reach of the stake, the band looks no further
   --  than its work again.
   --
   --  The colony's ground (the stacks the game keeps loaded for it, and
   --  waits for) follows: Ground_Reach_M is how far from the stake it has
   --  to reach now.  Work_Radius_M as a rule, so that nothing changes while
   --  nobody looks further; wider while the band looks or is afield, and as
   --  far as any stretch of path still to lay.
   Reach_Step_M    : constant := 16.0;
   Far_Reach_Max_M : constant := 256.0;
   function Ground_Reach_M return Float;
   function Looking_M return Float;
   --  How far from the stake the band is looking for what the camp's
   --  building takes (0: no further than its work).
   procedure Set_Stone_From (Metres : Float);
   --  For measurements and the checks, as Supply is: the camp's builders
   --  leave alone any stone nearer the stake than this, as if the nearest
   --  lay that far off (0, the default: none is left).  It sends the band
   --  far afield on ground where stone is never far.  Saved with the colony.
   function Camp_Turn return Float;
   --  The way the camp lies (radians): its zone's, a path's that passes
   --  within reach of its square, else east and north.
   function Firewood_Place return Vec3;              --  where the fire's stack of logs stands
   function Seat_Place (K : Positive) return Vec3;   --  K in 1 .. 2 * Seat_Logs: where one sits
   function Seat_Log (K : Positive) return Vec3;     --  K in 1 .. Seat_Logs: the middle of the log
   function Seat_Turn (K : Positive) return Float;   --  the way it lies (radians)
   function Cooking_Of (I : Positive) return Float;
   --  0 .. 1, from its seed: what made a cook good before there were skills
   --  (and still does with skills off).  Its aptitude for cooking is this
   --  spread over Aptitude_Lo .. Aptitude_Hi, so the band's best cook is who
   --  it always was.
   function Cooked return Natural;                   --  points of stew made, all told
   function Put_In_Pot (K : Item_Kind) return Natural;   --  of K, all told
   function Eaten_Raw (K : Item_Kind) return Natural;    --  of K, all told

   ------------------------------------------------------- skills

   --  People are better at some work than other work, and get better at
   --  what they do.  Each member has a level, 0 (none) .. 1 (mastery), in
   --  each skill, and an aptitude for each, Aptitude_Lo .. Aptitude_Hi, that
   --  says how fast it learns it: its own for life, from its seed.  The
   --  first five are the skills of the work there is; the rest only grow
   --  alongside, for the trades to come.
   --  (Saved by position: new skills go on the end.)
   type Skill_Kind is (Gathering, Forestry, Hunting, Portering, Cooking,
                       Building, Carpentry, Stonework, Farming, Tanning, Taming);
   subtype Working_Skill is Skill_Kind range Gathering .. Cooking;
   function Name (S : Skill_Kind) return String;   --  "forestry"

   --  The work a member can be at.  Handling is what has no skill in it:
   --  carrying, lifting, putting down, taking from a cell.
   --  Site_Work is building: making ground ready, bringing what a building
   --  takes and setting it up (the camp's hearth is the first).
   --  House_Raising is a builder's: laying a house's floor, walls and roof.
   type Work_Kind is (Handling, Picking, Felling, Stalking_Game, Butchering, Reaping, Quarrying, Drawing_Water,
                      Camp_Keeping, Site_Work, House_Raising, Joinery);
   subtype Skilled_Work is Work_Kind range Picking .. Joinery;
   Own_Skill : constant array (Skilled_Work) of Skill_Kind :=
     [Picking => Gathering, Felling => Forestry, Stalking_Game => Hunting, Butchering => Hunting,
      Reaping => Portering, Quarrying => Portering, Drawing_Water => Portering, Camp_Keeping => Cooking,
      Site_Work => Building, House_Raising => Building, Joinery => Carpentry];

   --  How fast the band works and walks (John, 2026-11-12: "also can we
   --  increase the work and travel speed of serfs by about 50%"): every
   --  work rate, and every pace over the ground, is multiplied by the
   --  colony's pace.  Serf_Pace is what a colony is founded with; 1 is the
   --  band as it was until then, which a colony loaded from before it
   --  keeps, and which the older sections of the checks and the seven
   --  older reference runs are held at (Set_Pace, --pace 1).  Saved with
   --  the colony.  Nothing else goes by it: not hunger, the clock, a
   --  hunter's patience at its aim, how fast a skill is learnt (an hour at
   --  the work is an hour of practice still) or the deer.
   Serf_Pace : constant := 1.5;
   procedure Set_Pace (To : Float);
   function Pace return Float;

   --  A level's worth.  Every timer of skilled work runs at
   --     rate = pace x condition x skill x direction
   --  condition: Starving_Pace with an empty belly, else 1; skill: from
   --  Novice_Rate with none of the work's own skill to Master_Rate at
   --  mastery (1 at a third of the way: the pace before there were skills);
   --  direction: what whoever directs it adds, 1 for everyone until a trade
   --  directs helpers.  Handling goes by condition and direction alone, and
   --  walking by condition.  A hunter's chance to hit is today's times
   --  Novice_Aim .. Master_Aim (never over Best_Aim), and a cook's pot holds
   --  Novice_Pot .. Master_Pot of what went into it.
   Novice_Rate : constant := 0.75;
   Master_Rate : constant := 1.5;
   Novice_Aim  : constant := 0.8;
   Master_Aim  : constant := 1.4;
   Best_Aim    : constant := 0.95;
   Novice_Pot  : constant := 0.9;
   Master_Pot  : constant := 1.2;

   --  Skill by doing.  An hour on a job is an hour of practice: the whole
   --  trip (going out, the work, carrying it home), by the work done, not
   --  the job held (a cook out gathering learns gathering).  It teaches the
   --  work's own skill in full and the skills beside it by the fractions in
   --  Learns.  A level closes on mastery at a rate of its aptitude over
   --  Learn_Hours: fast from nothing, slower the better it is; Learn_Hours
   --  of work at aptitude 1 leave about a third of the gap.  Nothing is
   --  learnt idle, eating or asleep, and nothing is forgotten.
   Learn_Hours : constant := 600.0;
   Aptitude_Lo : constant := 0.5;
   Aptitude_Hi : constant := 1.5;
   type Shares is array (Skill_Kind) of Float;
   Learns : constant array (Work_Kind) of Shares :=
     [Handling      => [others => 0.0],
      Picking       => [Gathering => 1.0, Farming => 0.2, Cooking => 0.1, others => 0.0],
      Felling       => [Forestry => 1.0, Building => 0.15, Carpentry => 0.1, others => 0.0],
      Stalking_Game => [Hunting => 1.0, Taming => 0.1, others => 0.0],
      Butchering    => [Hunting => 1.0, Tanning => 0.3, Cooking => 0.2, others => 0.0],
      Reaping       => [Portering => 1.0, Farming => 0.3, others => 0.0],
      Quarrying     => [Portering => 1.0, Stonework => 0.3, others => 0.0],
      Drawing_Water => [Portering => 1.0, others => 0.0],
      Camp_Keeping  => [Cooking => 1.0, others => 0.0],
      Site_Work     => [Building => 1.0, Stonework => 0.2, others => 0.0],
      House_Raising => [Building => 1.0, Carpentry => 0.3, Forestry => 0.1, others => 0.0],
      Joinery       => [Carpentry => 1.0, Building => 0.2, others => 0.0]];

   --  What people arrive with: Start_Lo .. Start_Hi in each working skill
   --  (an elder Elder_Start more, a child Child_Start of it), up to
   --  Trade_Start in the others.  A band's mean is about a third: on the
   --  whole it works at the pace it did before there were skills.
   Start_Lo    : constant := 0.15;
   Start_Hi    : constant := 0.5;
   Elder_Start : constant := 0.2;
   Child_Start : constant := 0.5;
   Trade_Start : constant := 0.1;

   --  The short work times (seconds): what has no skill in it.
   Store_S        : constant := 1.0;    --  putting a load down in a stockpile cell
   Lift_Log_S     : constant := 1.2;    --  a log on to the shoulder
   Lift_Carcass_S : constant := 2.5;    --  a deer across the shoulders
   Take_S         : constant := 1.0;    --  taking what was set aside from a cell
   Put_In_S       : constant := 1.0;    --  into the pot, on to the fire or its stack, a seat log laid
   Stalk_Patience_S : constant := 90.0; --  a stalk with no shot in this long is given up for a while

   procedure Set_Skills (On : Boolean);
   --  On (the default): as above.  Off: everyone works at the one pace,
   --  aims and cooks as before there were skills, and learns nothing (the
   --  levels stay).  Saved with the colony.
   function Skills return Boolean;

   function Skill_Of (I : Positive; S : Skill_Kind) return Float;      --  0 .. 1
   function Aptitude_Of (I : Positive; S : Skill_Kind) return Float;   --  Aptitude_Lo .. Aptitude_Hi
   procedure Set_Skill (I : Positive; S : Skill_Kind; Level : Float);
   --  For scripted starts and the checks, as Supply is: nobody's to do.

   function Has_Skill (J : Job_Kind) return Boolean;                   --  every job but Unassigned
   function Job_Skill (J : Job_Kind) return Skill_Kind with Pre => Has_Skill (J);
   --  The skill of a job's own work.

   function Work_Of (I : Positive) return Work_Kind;
   --  What member I is at now, for its practice: Handling when it is at
   --  nothing that teaches (idle, eating, asleep).
   function Work_Rate_Of (I : Positive; W : Work_Kind) return Float;
   --  The rate member I would do work W at now: condition x skill x direction.
   function Direction_Of (I : Positive) return Float;
   --  What its director's direction adds to its work: 1 for everyone, until
   --  a trade directs helpers (then by that director's skill).
   function Hit_Chance_Of (I : Positive; Metres : Float) return Float;   --  hunter I's, at that range
   function Pot_Yield_Of (I : Positive) return Float;
   --  What cook I's pot holds of what went into it (before the bonus for
   --  meat and greens together).

   ------------------------------------------------------- zones

   --  A zone is a piece of ground the player has marked for a use: a thing
   --  of its own, with a kind, borders and what is inside them.  Stockpiles
   --  and the camp are the first two kinds.  One zoning is one zone: a
   --  stockpile zoned in one go owns the cells it got (its borders are the
   --  box round them), and two that touch stay two.  Zones are numbered
   --  from 1 in the order they were made, and keep their numbers.
   --
   --  Information belongs to what is in the world, and a zone is where it
   --  is gathered: what lies inside its borders, what is on its way in and
   --  out, who is there.  That is all anyone is shown of it (Zone_At), and
   --  what is not in a zone nobody keeps count of.
   --
   --  A zone's ground.  A zone is the ground it fills, kept block column by
   --  block column, so it has whatever outline its place gives it:
   --    fill       its ground is every free block column of its lot that
   --               can be reached from where it was begun without crossing
   --               a path, a zone, a ledge higher than Zone_Step_M or
   --               anything standing in the way.  It is shown filled in.
   --    snap       the lot is a rectangle turned to lie along the nearest
   --               path, whatever way that runs; a side that comes within
   --               Snap_M of a path's edge is drawn out to it, so no strip
   --               of no man's land is left between.
   --    terminate  the fill stops at the path: ground a path lies on is
   --               never a zone's, and a lot drawn across a path keeps to
   --               the side it was begun on.
   --  No block column is ever in two zones, or in a zone and a path.
   --  (Zone_Kind is saved by position: new kinds go on the end.)
   Snap_M      : constant := 1.0;    --  a lot's side this near a path's edge is drawn out to it
   Zone_Step_M : constant := 0.5;    --  a zone does not climb a ledge higher than this
   Max_Lot_M   : constant := 64.0;   --  a lot's sides, at most
   Camp_Clear_M : constant := 3.0;   --  the fire is refused nearer a path or a zone than this
   Camp_Step_M  : constant := 2.0;   --  the camp's own ground may step this much (it lies within a metre of its middle)
   Snap_Facing  : constant := 0.64;  --  a side is drawn out to a path it faces to within 50 degrees (the cosine)

   type Zone_Kind is (Stockpile_Zone, Camp_Zone, Habitation_Zone);

   --  What is built on a zone takes materials, delivered to it by the band
   --  (see the camp): by kind of zone.  A stockpile takes nothing yet (its
   --  storehouse, its fences and its coverings will be rows here).  What a
   --  housing zone takes is not a number of its kind's: it is what its
   --  houses' blueprints count up to (see housing), and is asked for the
   --  same way.
   type Build_List is array (Zone_Kind) of Per_Kind;
   Build_Takes : constant Build_List :=
     [Stockpile_Zone  => [others => 0],
      Camp_Zone       => [Stone => Hearth_Stones, Wood => Hearth_Wood, others => 0],
      Habitation_Zone => [others => 0]];

   subtype Way_Index is Natural range 0 .. 7;
   --  One of the eight ways a path can run: east, north-east, north,
   --  north-west, west, south-west, south, south-east (see placements).

   type Zone_View is record
      Kind   : Zone_Kind := Stockpile_Zone;
      Lo, Hi : Vec3 := (0.0, 0.0, 0.0);      --  opposite corners of the box round its ground (Z: its lowest and highest)
      Turn   : Float := 0.0;                 --  the way its lot lies: its path's, within 45 degrees of east (radians)
      Along, Across : Float := 0.0;          --  how far its ground reaches along that way and across it (metres)
      Blocks : Natural := 0;                 --  its ground, in block columns (sixteen to a square metre)
      Built  : Boolean := True;              --  what is to be built on it stands (a stockpile needs nothing built)
      Got    : Per_Kind := [others => 0];    --  delivered for its building, of Build_Takes
      Yard   : Boolean := False;             --  a stockpile's zone that is the stockyard (the storehouse's)
      Leaving : Boolean := False;            --  a stockpile ordered removed: gone when the last thing is carried off it
      Cells  : Natural := 0;                 --  a stockpile's places for things (the camp has none)
      In_Use : Natural := 0;                 --  of those, holding something or promised to it
      Overflow, Over_In_Use : Natural := 0;  --  and its overflow's places, and of those in use
      Holds  : Per_Kind := [others => 0];    --  what lies in it (the camp: its firewood; the pot is in Camp_State)
      Coming : Per_Kind := [others => 0];    --  on its way there, room set aside for it
      Going  : Per_Kind := [others => 0];    --  set aside for someone on the way to take it
      People : Natural := 0;                 --  the living inside its borders
      Homes  : Natural := 0;                 --  housing: the houses begun on it, standing or not,
      Homes_Built : Natural := 0;            --  and those of them that stand
      Short  : Per_Kind := [others => 0];    --  housing: what its houses still take that has not been delivered
      No_Room : Boolean := False;            --  housing: someone is without a house, none is being built for them
                                             --  and no lot is laid out to begin one on (the player's to mend)
      Lots   : Natural := 0;                 --  housing: the lots laid out on it for houses not yet begun
      Placed : Boolean := False;             --  it was put down whole, with its path (see placements): its frame,
      From   : Vec3 := (0.0, 0.0, 0.0);      --  where its front begins on its path's middle line,
      Way    : Way_Index := 0;               --  the way its path runs from there (it lies on the left of that),
      Along_B : Natural := 0;                --  and how many blocks of path lie along its front
   end record;
   function Zone_Count return Natural;
   function Zone_At (Z : Positive) return Zone_View;
   function Zone_Of_Cell (K : Positive) return Natural;   --  the zone that owns stockpile cell K
   function Zone_On (X, Y : Float) return Natural;
   --  The zone whose ground (X, Y) is (0: none).
   function Zone_Top (X, Y : Float) return Float;
   --  The top of the zoned ground at (X, Y), metres (below 0: not zoned).
   function Camp_Zone return Natural;                      --  the camp's zone (0: no camp)

   --  A zone's ground, for whatever draws it: strips of block columns
   --  X0 .. X1 in row Y (west to east, rows south to north) whose tops are
   --  the top of block Z.
   type Zone_Run is record
      Y, X0, X1 : Integer := 0;
      Z         : Integer := 0;
   end record;
   function Zone_Runs (Z : Positive) return Natural;
   function Zone_Run_At (Z, K : Positive) return Zone_Run;   --  K in 1 .. Zone_Runs (Z)
   function Zones_Version return Natural;   --  moves on whenever any zone's ground does

   --  What a zoning would give, with nothing changed: for showing a lot
   --  before it is taken.  The plan's ground is Planned_Run_At, until the
   --  next plan or zoning.
   type Lot_Corners is array (1 .. 4) of Vec3;
   type Lot_Plan is record
      Ok     : Boolean := False;      --  it would be taken
      Corner : Lot_Corners := [others => (0.0, 0.0, 0.0)];   --  the lot as drawn, turned to its path
      Turn   : Float := 0.0;
      Cells  : Natural := 0;          --  places for things it would get
      Overflow : Natural := 0;        --  and places for its overflow, round it (see stockpiles)
      Blocks : Natural := 0;          --  ground it would fill (block columns)
   end record;
   function Plan_Stockpile (X0, Y0, X1, Y1 : Float) return Lot_Plan;

   --  The stockpile the player places (John, 2026-11-17: "Change stockpile
   --  to a onetime placement of a 10x10 zone"): one click beside a path
   --  (within Square_Snap_M of its middle), and a stockpile Stockpile_Side_M
   --  square is zoned there: on the click's side of the nearest path, its
   --  front on the path's edge, the click across from its middle, on the
   --  whole metres of its lot (a hundred places where nothing stands in the
   --  way).  Laid out and refused as Zone_Stockpile's two corners are; and,
   --  with One_Stockpile, refused once any stockpile is zoned ("the
   --  stockpile is placed once").  Zone_Stockpile (two corners) is the
   --  scripts' and the checks', of any size, as before.  Set_One_Stockpile
   --  (False): the player's places a stockpile as often as asked (the
   --  square all the same).  Saved.
   Stockpile_Side_M : constant := 10.0;
   Square_Snap_M    : constant := 12.0;
   procedure Place_Stockpile (X, Y : Float; Cells : out Natural);
   function Plan_Stockpile_At (X, Y : Float) return Lot_Plan;
   function Plan_Stockyard (X0, Y0, X1, Y1 : Float) return Lot_Plan;   --  (what Zone_Stockyard would take)
   function Stockpile_Count return Natural;
   procedure Set_One_Stockpile (On : Boolean);
   function One_Stockpile return Boolean;
   function Plan_Camp (Centre : Vec3) return Lot_Plan;
   function Planned_Runs return Natural;
   function Planned_Run_At (K : Positive) return Zone_Run;

   ------------------------------------------------------- placements

   --  A zone put down whole, with its path (John, 2026-11-20: "let's lock
   --  the size of the stockpile, if the player places it, it will be a
   --  square box, lets fix the path artifcats by including the path in
   --  front of the stockpile, the player can rotate the placement.  Since
   --  the paths are now snapped to specific directions, they can either
   --  align it with an existing path, rotate and snap it to the end of or
   --  if they orientate it at an angle to the middle of a path it will snap
   --  at that angle to the path.  Along with a warning for overlap.  This
   --  should make things easy for us and the player; and allow us to make
   --  the angled zones their own grid").
   --
   --  A box is held by its middle and turned one of the eight ways a path
   --  can run.  Its path is a stretch along its front, begun on a corner
   --  of blocks and a whole number of blocks long; the box lies on the
   --  left of that way, from the path's edge back, Box_Side_M deep and as
   --  long as its front: Box_Side_M along a straight way; along a slanting
   --  one the least whole number of blocks that is not shorter (a slanting
   --  block is 35 cm long: 10.25 m for 10).  So no ground lies between a
   --  box and its path whichever way it is turned, and a box cannot wrap
   --  round a path's end or be broken by one (his "path artifacts are when
   --  the zone collides with the path and part spills/wraps over the end,
   --  or disrupts the box").
   --
   --  Near a path that lies one of the eight ways on the corners of blocks
   --  it is drawn to it, by the least move of:
   --    along      turned the way that path runs, or straight back along
   --               it, its front within half its depth and half a path of
   --               that path's line: its path is that line, and nothing new
   --               is laid where a path lies already; an end of its front
   --               within Box_Snap_M of an end of that path is put there
   --               (the path goes on from its end, or the box stands flush
   --               with it);
   --    an end     turned another way, an end of its front within
   --               Box_Snap_M of a path's end: its path begins or ends
   --               there, a corner;
   --    the middle turned another way, an end of its front within
   --               Box_Snap_M of a path's line: its path meets that line
   --               there, a branch at that angle.
   --  Where its path meets another so, the box begins as many blocks on as
   --  keep it off that path (two, squarely; one, aslant on the open side;
   --  on the side that path runs into it cannot be kept off it, and is
   --  refused).  Away from any path it lies where it is held, its front
   --  begun on the nearest corner of blocks.
   --
   --  It is refused, Box_Refusal saying why, where there is no ground under
   --  its path's ends, where its path could not be laid (a zone or the
   --  lord's cart in its way), where any of its box is a zone's ground or a
   --  path's already (his "warning for overlap ... the click is refused
   --  for special zones"), or where its ground gives it no place.  What is
   --  placed is its kind's zone: its ground the block columns that lie
   --  within it ("the .25m blocks around it that will fit the zone"), its
   --  places on its own whole metres from its front's beginning.  The zone
   --  keeps its frame (Zone_View's Placed, From, Way, Along_B): what is
   --  built on an angled zone is to be kept on that grid.
   --
   --  Box_At is the one routine that says where a box held at a point lies:
   --  whatever shows it and whatever places it ask it, and held by its own
   --  middle (Box_Middle) a box is given back as it is.
   --  Set_Box_Place (False), --no-box-place: the player's stockpile is zoned
   --  corner to corner, as before.  Saved.
   type Box_Kind is (Stockpile_Box, Stockyard_Box);
   type Box_Snap is (Free, Along_Path, At_End, At_Middle);
   type Placement is record
      Ok       : Boolean := False;         --  there is ground under both ends of its path
      Kind     : Box_Kind := Stockpile_Box;
      From, To : Vec3 := (0.0, 0.0, 0.0);  --  its path's middle line (longer than its front where it meets a path)
      Front    : Vec3 := (0.0, 0.0, 0.0);  --  where its front begins on that line
      Way      : Way_Index := 0;
      Along_B  : Natural := 0;             --  blocks along its front
      Snap     : Box_Snap := Free;
      Corner   : Lot_Corners := [others => (0.0, 0.0, 0.0)];   --  its box: 1 and 2 along its front, from its beginning
   end record;
   Box_Snap_M : constant := 2.0;
   function Box_Side_M (Kind : Box_Kind) return Float;
   function Box_At (Kind : Box_Kind; Middle : Vec3; Way : Way_Index) return Placement;
   function Box_Middle (P : Placement) return Vec3;
   type Box_Plan is record
      Where : Placement;
      Lot   : Lot_Plan;                    --  Lot.Ok: it would be taken (its ground: Planned_Run_At)
      New_Path_M : Float := 0.0;           --  metres of its path that no path lies along yet
   end record;
   function Plan_Box (Kind : Box_Kind; Middle : Vec3; Way : Way_Index) return Box_Plan;
   procedure Place_Box (Kind : Box_Kind; Middle : Vec3; Way : Way_Index; Cells : out Natural);
   --  (for the tools: how many parts of placed boxes' own paths, where no path lay along their line,
   --  had nothing a path could be laid on and were left out, since the program began)
   function Box_Paths_Unlaid return Natural;
   function Box_Refusal return String;     --  why the last Plan_Box or Place_Box was refused ("" if it was not)
   --  What lies in a zone that was put down whole, for measuring it
   --  (colony_run --box-stats): the block columns whose middles lie in its
   --  box; of those its own ground, a path's, another zone's, and nobody's
   --  (ground it could not take: something stands there, or a ledge); and
   --  of nobody's, those within a metre of its front, between it and its
   --  path, where there should be none on open ground.  All nought for a
   --  zone that was not put down so.
   type Box_Count is record
      Box, Its_Own, Path, Other, Bare, Front_Bare : Natural := 0;
   end record;
   function Box_Counts (Z : Positive) return Box_Count;
   procedure Set_Box_Place (On : Boolean);
   function Box_Place return Boolean;
   --  A tree that stands in a stockpile put down whole is felled and taken
   --  out (John, 2026-11-20: "fell the tree in the stockpile"): its foot is
   --  the stockpile's ground, a place lies over it (closed, nothing put
   --  there, while the tree stands), whoever has a place at an extra task
   --  fells it, its stump and roots are earth from then on, and its place
   --  is opened.  **The stump of a tree felled before the stockpile was put
   --  down** (a forester's work: the trees nearest a fire are the first to
   --  go) is taken out the same way, in the time the tree took to fell,
   --  and no log comes of it.  One to take out is a reason of its own for
   --  anyone to turn to the band's building (Think): there need be no camp
   --  to build, no path to lay and no cart to pull.  A bush or a boulder in
   --  it leaves places out, as ever.  Set_Box_Fell (False), --no-box-fell:
   --  a tree leaves places out too, as before.  Not saved; a stockpile put
   --  down with it off keeps its trees.
   procedure Set_Box_Fell (On : Boolean);
   function Box_Fell return Boolean;
   function Box_Trees_Left return Natural;    --  trees and stumps still to take out of such stockpiles

   ------------------------------------------------------- the homestake and the campfire one

   --  (John, 2026-11-20: "Let's merge the homestake and the campfire, no
   --  physical stake now, lets expand the campfire/homestake, to a 10x10
   --  area, terriform so the entire area is flat, and build a path around
   --  the perimeter.  The idea is when the campfire becomes obsolete, it
   --  can become the village center, or town square.  The player can start
   --  building off of it as the please"; and of the path: "place the path
   --  around the outside of the 10x10m so it will be 12x12m when it's
   --  built".)
   --
   --  One placement founds the colony: a square held by its middle and
   --  turned, squarely or aslant (Way: even or odd).  No post is raised; the
   --  stake's place is the fire's, the square's middle, on a corner of
   --  blocks, and everything that is measured from the stake is measured
   --  from there as before.  The band arrives round it.  The square is the
   --  camp's zone, Square_Side_M a side (aslant, 11.02 m: its path lies on
   --  the corners of blocks; ten metres and 9.96 until 2026-11-21, see
   --  Set_Square_Wide), all of it the camp's floor: the band brings
   --  the whole of it to one level and treads it to bare earth, as it
   --  does the ground round a camp's fire, before the hearth is built.
   --  Round the outside of it lies a path, four stretches from corner to
   --  corner, laid by the band as any path is and brought to the square's
   --  level where the ground lies within half a metre of that; beyond that
   --  it lies as the ground does.  They are paths like any other: a box is
   --  drawn to them, a path goes on from their corners.
   --
   --  Refused (Square_Refusal says why) once there is a stake; where there
   --  is no ground under its middle, or water on it or on its path; where
   --  its ground (read under whatever stands on it) rises and falls more
   --  than Square_Fall_M from its middle's; where a boulder stands within
   --  Square_Core_M of its middle (the fire, its seats, its stack of wood);
   --  and where its floor, made level, would lie cut off: a floor a serf
   --  can step down off and not up onto again, or the other way about, on
   --  every side (a knoll, a hollow: less than two metres of its edge with
   --  ground beside it within a step of its level).
   --
   --  What stands on it.  **A tree is felled and taken out** (John,
   --  2026-11-20: "a tree left on a square, can stay in habitation zone, if
   --  it doesn't interfere with anything, or felled and removed anywhere
   --  else"): its foot is the square's ground like the rest; the band fells
   --  every tree that stands on the floor or on the path round it before
   --  the ground is made under it (anyone at the camp's building does, as
   --  a builder fells a stockyard's own), what is left of it, stump and
   --  roots, is earth from then on, its logs lie where it fell, and the
   --  camp is not built while one stands.  A boulder further out than
   --  Square_Core_M is left standing, and the floor is made round it.  A
   --  bush on its floor, and what hangs within a serf's height over it of
   --  a tree, is cleared when it is founded, and its ground is floor like
   --  the rest (left where the floor is filled up round it, a bush stands
   --  in a hole a serf drops into and cannot climb out of).
   --
   --  Set_Square_Fell (False), --no-square-fell: a tree is left standing, as
   --  it first was: one within Square_Core_M refuses the square; further
   --  out its foot is not the square's ground, the floor is made round it,
   --  and no forester fells it (felled, it would leave such a hole).  A
   --  square founded so keeps its trees whatever is set later.  Not saved.
   --  (colony_run --square-census counts the places that take a square;
   --  --square-scan founds and makes one at every place of a grid and looks
   --  each over for pits.)
   --
   --  Plan_Square is what Place_Square would take, nothing changed (its
   --  floor's ground: Planned_Run_At).  The zone keeps its frame: From the
   --  first corner of its path's line, Way, Along_B the blocks of one side.
   Square_Side_M : constant := 11.0;      --  (10.0 until 2026-11-21, and with Set_Square_Wide off)
   Square_Fall_M : constant := 1.5;
   Square_Core_M : constant := 4.0;
   --  (the rings reserved outside each side of its floor for a wall, below: side 1 along its way
   --  from its middle, 2 against it, 3 across it to the left, 4 to the right; squarely east, west,
   --  north, south; aslant north-east, south-west, north-west, south-east)
   type Square_Strips is array (1 .. 4) of Natural;
   type Square_Plan is record
      Ok     : Boolean := False;
      Way    : Way_Index := 0;
      Middle : Vec3 := (0.0, 0.0, 0.0);                        --  the fire's place
      Corner : Lot_Corners := [others => (0.0, 0.0, 0.0)];     --  its floor
      Ring   : Lot_Corners := [others => (0.0, 0.0, 0.0)];     --  the corners of its path's middle line
      Strip  : Square_Strips := [others => 0];                 --  what is kept outside each side for a wall
      Level_Row : Integer := -1;                               --  the row its floor's top is to be brought to (-1: left as it lies):
                                                               --  the very level Place_Square then founds it at
   end record;
   function Plan_Square (Middle : Vec3; Way : Way_Index) return Square_Plan;
   procedure Place_Square (Middle : Vec3; Way : Way_Index; Band_Size : Positive; Seed : Castle.Hash.U64);
   function Square_Refusal return String;   --  why the last Plan_Square or Place_Square was refused ("" if it was not)
   function Square_Off_M return Float;
   --  How far the ground of the last square planned lies off its middle's,
   --  at the most (metres; where that was looked at: for measuring).
   function Camp_Is_Square return Boolean;   --  this colony was founded so
   procedure Set_Square_Fell (On : Boolean);
   function Square_Fell return Boolean;
   --  **A square is founded on the ground its plan read** (2026-11-21, found measuring the stockyard
   --  against 323 squares of seed 1): the plan's middle has the height of the highest floor there
   --  (Castle.Nav.Surface_Z: under a tree's crown, a bough or the tree's top), and the plan reads
   --  the fire's own ground under it.  The stake used to be asked for near the plan's middle's
   --  height: where a bough lay over the fire's own block column the stake's place, and the fire's,
   --  was put on the bough, four or five metres up, the band arrived on the tree tops round it
   --  ("the floor nearest the square's height") and whoever could not get down starved (11 places
   --  of 323; at two of four tried somebody starved); where the bough lay beside that column the
   --  founding found no ground within 4 m and refused what the plan had shown as taken (3 more).
   --  Now the stake is put on the ground the plan read (beside a tree's foot that stands on the
   --  fire's own place, the ground by it).  Set_Fire_Ground (False), --no-fire-ground: as it was.
   --  Not saved; nothing to a colony that is founded.
   procedure Set_Fire_Ground (On : Boolean);
   function Fire_Ground return Boolean;
   --  The square's size (John, 2026-11-21: "Let's expand the campfire/homestake square to 13x13m (with
   --  the footpath) so the campfire is in the center"): a floor of eleven metres, thirteen with its
   --  path; its ground is worked a square metre at a time, counted from its edges, so that the fire
   --  stands in the middle of the middle one (on ten metres it stood where four of them meet).
   --  Set_Square_Wide (False), --square-10: a square is founded ten metres, as it first was.  Not
   --  saved, and nothing to a square that is founded: that keeps the size it was founded with.
   procedure Set_Square_Wide (On : Boolean);
   function Square_Wide return Boolean;
   --  **A special zone's area is kept whole** (John, 2026-11-21: "A rule, the area of a special zone
   --  like these takes precedent, so if a retaining wall is needed put it on the zones edge, shift the
   --  path. So the area of the campfire stays 11x11m + the wall on the sides if needed then the path
   --  that follows, the size can change overall").  A square founded under the rule has a strip kept
   --  outside each side of its floor where that side's bank will want a wall: Strip rings wide, a ring
   --  a block column squarely (25 cm) and a diagonal row of blocks aslant (18 cm): squarely one for
   --  each lift of the highest wall that side is to have, Strip_Most at the most; aslant two wherever
   --  a wall is wanted (35 cm: a path at 45 degrees that a stockpile or a turned house can lie along
   --  runs on every other diagonal of the block grid, and two sides' lines an odd number of rings
   --  apart cross at the middle of a block's edge).  Its wall stands in the strip
   --  and its path lies beyond: on that side the path's line is that much further out, the four
   --  stretches run between the corners where the four lines meet, and the square with its path is
   --  wider than thirteen metres by as much.  The floor is all floor: nothing of it is wall or ledge
   --  (a stair's steps are still cut into it from its edge, as they were; the strip before them is
   --  a landing of stone at the path's level).  **Where a side's path lies level with the floor the
   --  strip between them is laid level with both, as path**: a quarter metre of the path's length is
   --  brought to the floor's level strip and all, or not at all, so the path is that much wider
   --  there, and the strip is a wall's only where there is a bank.
   --
   --  The strips are judged when the square is planned, before any of it is made: from the ground as
   --  it lies and the level the floor is to have (Square_Plan.Level_Row: the level it is founded at,
   --  the ground under the feet of the trees that stand on it counted as the founding counts it;
   --  judged against a level reckoned without them, three squares of 320 on seed 1 were founded a
   --  block lower than their strips had been judged for, 2026-11-21), each side's path is tried at
   --  its place and further
   --  out, a ring at a time, until no quarter metre of its length would leave a bank of more lifts
   --  than the rings kept (a quarter metre all within Path_Level_B of the level is brought to it, and
   --  leaves none; else the bank is what the path's innermost column lies over or under the floor).
   --  They are the square's from then on, saved with it, and what Plan_Square shows.  What is built
   --  is still read from the path as laid (the walls, below), so where the two differ: beside a bank,
   --  what of a strip its wall does not want (and all of it where the path lies within a block of
   --  the floor) is brought to the path's level and capped with stone, the wall's top that much
   --  broader; a wall that wants more lifts than its strip has rings stands steeper, its outermost
   --  ring taking what is left; and on a side with no strip a bank is left earth, as banks were
   --  before there were walls.  None of the three takes any of the floor.  Square_Walls_State counts
   --  them.
   --
   --  Set_Square_Outside (False), --square-walls-inside: a square is founded with its walls on its own
   --  outermost quarter metre and its path a fixed ring, as squares were until 2026-11-21.  A square
   --  keeps the rule it was founded under (saved); one founded with its walls off (Set_Square_Walls)
   --  has no strips and is not under it.
   Strip_Most : constant := 3;
   procedure Set_Square_Outside (On : Boolean);
   function Square_Outside_Rule return Boolean;          --  (the switch)
   function Square_Is_Outside return Boolean;            --  this colony's square was founded under the rule
   function Square_Strips_Now return Square_Strips;      --  and its strips (none: no square, or not under it)
   function Square_Path_Middle (Side : Positive) return Vec3;
   --  The middle of the path along side Side (1 .. 4) of the square the colony was founded on, on the
   --  ground: for looking at it (colony_run --square-scan walks from there to the fire and back).
   function Square_Trees_Left return Natural;   --  trees still to fell on it
   --  (for the tools) **How the path round the square steps**, as it stands: each of its four
   --  sides' paths gone along a quarter metre at a time, from the line of the path it meets at its
   --  low end to that of the one at its high end (a slice: the block columns of the square's path
   --  across its width there), Visit told of each slice that has any: the side it runs along
   --  (1 .. 4), which quarter metre from the end its own stretch begins at (cut as that stretch is
   --  laid), how many there are in the side, its columns,
   --  and the lowest, the middle and the highest of their tops, in blocks over the floor's level
   --  (under 0: under it), and how many of them have a top of stone (a step's treads).  Read from
   --  the ground, whatever stretch laid it (a stockpile's or a stockyard's own path lies along a
   --  side's too).  Nothing before the floor's level is chosen.
   --  (colony_run --square-path, and its scan.)
   procedure For_Square_Path_Slices
     (Visit : not null access procedure (Side : Positive; Slice, Slices : Natural; Columns : Positive;
                                         Lowest, Middle, Highest : Integer; Stone : Natural));

   --  The square's walls and stair (John, 2026-11-20, of the banks of earth
   --  a square on rising ground has, its path level with it only where the
   --  land is within half a metre: "stone wall and stair, also step the
   --  stone walls towards the higher ground if over 1m. so from lower ground
   --  for each 1m of retaining wall step inwards .25").
   --
   --  Once the hearth stands, wherever the path round the square is laid
   --  and lies more than a block over or under its floor, the floor's edge
   --  is a wall of stone: against higher ground its top flush with the path,
   --  over lower ground holding the floor up.  The stone stands on the
   --  square's own outermost quarter metre (the path keeps its metre), as a
   --  hovel's walls stand on its own site.  **A wall over a metre is set
   --  back**: counted up from the lower ground, each further Square_Lift_B
   --  blocks of it stand a block column nearer the higher ground (against
   --  higher ground the lower lifts stand further into the floor, which is
   --  that much narrower on that side; over lower ground the outermost
   --  column is a ledge a metre over the path and the floor's edge a block
   --  in).  Aslant, a block column in is one diagonal row of blocks, 18 cm.
   --  Each lift is stone from its own lowest row to its top.
   --  **A stair** is cut into the floor for each side whose bank at its
   --  middle, over all a stair's width and all one way, is
   --  Square_Stair_Least_B to Square_Stair_Most_B blocks: a block a step
   --  from the path's level to the floor's, its treads of stone and the
   --  earth beside it faced with stone (squarely Square_Stair_B block columns
   --  wide, on two whole cells of the walking map, a step a block deep;
   --  aslant Square_Stair_Rows diagonal rows either side of its middle one,
   --  a step Square_Step_Rows of them deep).  A higher bank has none on that
   --  side; a lower one is stepped over like any half metre of the land.
   --
   --  **A square's stair in a corner of the zone, not at the middle of its
   --  side: a rule kept behind its switch, off** (Set_Square_Stair_Corner
   --  (True), --square-stair-corner).  It was built on John's "The path
   --  level at one corner is great, move the stair to the opposite corner
   --  instead of the center, if a stair is to be had it's to be at the
   --  corner of the zone" (2026-11-21, afternoon), read as a square's; he
   --  meant the stockyard's (the evening: "No let's go back to square stair
   --  middle, I was talking about the stockyard having the stair in the
   --  corner rather than the middle").  **A square's stair stands at the
   --  middle of its side**, as above.  With the switch on, of a square whose
   --  walls stand outside its floor (one with its walls on its own edge
   --  keeps its stair at the middle): a side that would have a
   --  stair has it at one of its two ends, the last metre of the floor
   --  along that side, its outer flank the wall of the side it meets there
   --  (as wide as it was, counted in from the floor's corner; squarely a
   --  block column wider where the floor's edge does not fall on the edge of
   --  a cell of the walking map, so that no slot is left between stair and
   --  corner).  It is judged where it stands: an end takes it if the
   --  bank there, over all the stair's width and all one way, is
   --  Square_Stair_Least_B to Square_Stair_Most_B blocks.  So a side whose
   --  path comes in level at one end has its stair at the other.  Of two
   --  ends that would both take it: the one whose
   --  corner is not a level way in already (a corner where the path of
   --  the side met there comes in level, within Retain_Over_B of the floor
   --  over a stair's width: a side banked from end to end, the next side
   --  level where they meet, has its stair at its far end from that
   --  corner, though the bank is higher there); else the one with the
   --  lower bank, and of two as high the end a walk round the square with
   --  the floor on the right comes to last on that side (the stairs of two
   --  sides banked evenly, one up and one down, then stand at corners
   --  diagonally across the square from each other).  With neither end
   --  taking it the side has none (Stairs_Lost; a side too high for one
   --  where it would stand is counted Too_High, as one too high at its
   --  middle is).  A side with one end only that takes it has it there,
   --  be that corner a level way in on the side it meets (Stairs_By_Level
   --  counts them).  One stair to a corner: two sides whose stairs fall in
   --  the same corner have the one with the lower bank there, and of two as
   --  high the one for which that end is the end named above
   --  (Stairs_Shared).  Nothing then stands at the middle of any side.
   --  Not saved: a stair is read from the ground each time, as the walls
   --  are (a square whose stairs were laid in its corners, loaded with the
   --  switch off, keeps that stone, which nothing takes up, and is built
   --  the ones at its sides' middles; and the other way about).
   --
   --  Nothing of them is kept: what each column is to be is read from the
   --  floor's level and the laid path outside it each time, and what is left
   --  to do from the blocks (what was dug level when the square was made is
   --  built up again in stone).  No wall is planned against a stretch of
   --  path still to lay (it waits), against a boulder or under a tree; rock
   --  is left as it is.  **They are built from the bank outward and dug
   --  from the path inward**: no column is raised while one beside it that
   --  is to stand higher is still lower than it is to be, and none dug while
   --  one that is to lie lower still stands over it, so that a wall half
   --  built never leaves a place a serf drops into and cannot climb out of.
   --  They are built by whoever has a place at an extra task, after the
   --  paths, and not before the fire has been lit (the hands that bring
   --  its first log are not taken for them; with no fire lit at all, from
   --  the colony's third day): stone from a stockpile (what the hearth and the houses do not
   --  want of it), else prised off a boulder within the band's reach (it
   --  looks no further for them, and does not ask again for ten minutes),
   --  carried to the wall, a stone Wall_Per_Stone blocks of it and Tamp_S
   --  seconds; the earth dug off a ledge or a stair's steps is thrown aside,
   --  and stone left over with no room in the stores is left lying.  One
   --  carrying stone to them is not left off for night or hunger.  Whoever
   --  stands at a wall's foot stands on the ground of its own block column
   --  (the walking map's floor there is the wall's top).  A sleeper's place
   --  that a wall or a stair is built on is given up, and another chosen;
   --  one left with none lies on the old ring, and keeps that place.
   --
   --  **While they are on, the square's path is brought to the floor's level
   --  a slice at a time** (the block columns across its width at one quarter
   --  metre along it: all of them within Path_Level_B of that level, or none
   --  is moved), so that a bank stands at the floor's edge, where its wall
   --  can be built, and never along the middle of the path.
   --
   --  Set_Square_Walls (False), --no-square-walls: none are built (what
   --  stands, stands), and the path is brought level column by column as it
   --  first was.  Not saved.
   Square_Lift_B        : constant := 4;   --  a lift of wall: a metre
   Square_Stair_Least_B : constant := 3;   --  a bank of so many blocks at a side's middle has a stair,
   Square_Stair_Most_B  : constant := 8;   --  and of no more than so many (2 m: a longer flight would reach the seats)
   Square_Stair_B       : constant := 4;   --  a stair's width, squarely, in block columns
   Square_Stair_Rows    : constant := 4;   --  aslant: so many diagonal rows either side of its middle one (1.6 m)
   Square_Step_Rows     : constant := 2;   --  aslant: a step is so many diagonal rows deep (35 cm)
   procedure Set_Square_Walls (On : Boolean);
   function Square_Walls return Boolean;
   --  Where a side's stair stands: at the end of the side where the square's own frame counts
   --  least along it, at its middle, at the other end.  The sides are 1 .. 4 as the strips are
   --  (along, against, left and right of its way); with the way east they are the east, west,
   --  north and south sides, and At_Low is the south end of the first two and the west end of
   --  the others.
   type Stair_Place is (No_Stair, At_Low, At_Middle, At_High);
   subtype Stair_Spot is Stair_Place range At_Low .. At_High;
   type Stair_Places is array (1 .. 4) of Stair_Place;
   --  The bank a stair would stand against at each of the three, as the path is laid (for
   --  counting them: colony_run --square-scan): whether any of it was read; Takes: a stair can be
   --  had there (all of its width against a bank of Square_Stair_Least_B to Square_Stair_Most_B
   --  blocks, all one way); Banked: so, or higher; Level: all of its width within Retain_Over_B
   --  of the floor (the path comes in level there, no wall is wanted).
   type Stair_Bank is record
      Read    : Boolean := False;
      Takes   : Boolean := False;
      Banked  : Boolean := False;
      Level   : Boolean := False;
      Up      : Boolean := False;      --  the path lies over the floor there
      Least_B : Natural := 0;
      Most_B  : Natural := 0;
   end record;
   type Stair_Sites is array (1 .. 4, Stair_Spot) of Stair_Bank;
   procedure Set_Square_Stair_Corner (On : Boolean);
   function Square_Stair_Corner return Boolean;

   --  **The square's path stepped with stone** (John, 2026-11-21: "we need to do something about
   --  having the .5m jumps in the path around the square too"; of four ways put to him, 2026-11-22:
   --  "Steps of stone", and "The only thing left to fix on the square is the path jumps").  The path
   --  round the square is brought to the floor's level a quarter metre of its length at a time,
   --  whole, where all of that quarter metre lies within half a metre of the level, and left as the
   --  land lies where it does not; so where a levelled stretch ended the path stood two or three
   --  blocks off it at once.  Of a square whose walls stand outside its floor:
   --    * **From the end of each levelled stretch the path goes up or down to the land a block a
   --      quarter metre**: the first quarter metre past the end is a step one block off the floor's
   --      level, toward the land's side of it, the next two blocks, and so on while the path there
   --      lies at least that far off and every column of that quarter metre within half a metre of
   --      the step's row (no column moves more than the half metre a path's may).  Where that ends,
   --      the path beyond is as it was.
   --    * **A step is of stone**: every block column of it across the path's width a tread of
   --      fieldstone at the step's row (what is under a tread that had to be raised is stone too),
   --      the wall builders' work, with the walls: counted with them, fetched for with them, laid
   --      in the same bouts.  The levelled stretch itself is not touched.
   --    * **Planned from the path as it is laid and from nothing else**, each time (as the walls
   --      are: nothing of it is kept): a quarter metre still to lay, or under a tree, is no step and
   --      ends a flight until it is laid, so the steps do not go by who laid which metre first.  A
   --      step is dug only with the stone for its tread in hand.
   --    * **None where two sides' paths cross** with Set_Corner_Steps off (the corner square metres
   --      were laid by whichever side's metre came first; since 2026-11-22, later, they are laid as
   --      one and are landings of the flights: below), and **none before a stair**; before the middle of
   --      a side that has no stair, only steps one and two blocks off the floor's level.  Whether
   --      a side has a stair is read from the path before its middle (a bank of three blocks or
   --      more all across): so the steps leave that reading what it was, and the stairs stand
   --      where they stood, as they stood, none lost and none made.
   --    * The walls and the strips beside a step are planned against the path as stepped.
   --  Set_Path_Steps (False), --no-path-steps: the path as it was.  Not saved.
   procedure Set_Path_Steps (On : Boolean);
   function Path_Steps return Boolean;
   --  **The corners of the square's path** (his "stick with whatever you think is best", 2026-11-22,
   --  of the corners, where 37 of the 50 jumps left lay; only of a square whose walls stand outside
   --  its floor).  **The square metre in which two sides' paths cross is laid as one**: all of it at
   --  once, when the first metre that has a column of it is laid, whichever side's that is; brought
   --  to the floor's level whole where every column of it lies within Path_Level_B of that level,
   --  and else left whole as its ground lies.  By its own columns alone, so it is the same square
   --  metre whichever side's metre comes first (a quarter metre of each side's at a time, a column
   --  of it was level or not by whichever side reached it first).  The few columns at its outer
   --  corner that no stretch reaches are laid with it.
   --  Set_Corner_Whole (False), --no-corner-whole: the corners as they were.  Not saved.
   --  **A column of two sides' strips waits for both sides' paths** (found 2026-11-22; his "Mend the
   --  issues you found").  Where the strips kept for two sides' walls meet beyond a corner of the
   --  floor, a column is of both, and is planned by what both sides' laid paths say.  Planned while
   --  one of them was still to lay, it was walled by the other alone, and that stone stood when
   --  the second path came: with their walls built when half their paths were laid, 23 of 323
   --  squares stood otherwise than built in order.  Now such a column has nothing planned, and is
   --  counted as nothing left, while a path beside it is still to lay.
   --  Set_Strip_Wait (False), --no-strip-wait: as it was.  Not saved.
   procedure Set_Strip_Wait (On : Boolean);
   function Strip_Wait return Boolean;
   procedure Set_Corner_Whole (On : Boolean);
   function Corner_Whole return Boolean;
   --  Which of those four square metres block column (Bx, By) is of (1 to 4; 0: none, or no square
   --  with its floor's level chosen): for the tools and the checks.
   function Square_Crossing (Bx, By : Integer) return Natural;
   --  **And the steps of stone run into it and through it**: with the corners laid as one, the
   --  square metre where two sides' paths cross is one step of a flight, a landing: all its columns
   --  at one row, each a tread of stone; and a flight that comes to it along one side goes on from
   --  it along the other.  So the path round the square is one round of quarter metres and four
   --  landings, and a flight runs along it from each level one, either way, a block a step, six
   --  at the most, by the rules a flight along a side goes by (Set_Path_Steps).  A corner that is
   --  level is a level one of the round, as a quarter metre is.  Planned from the laid path alone,
   --  as every step is; not where a square's stair stands in a corner of its floor
   --  (Set_Square_Stair_Corner).
   --  Set_Corner_Steps (False), --no-corner-steps: no step where two sides' paths cross, as it
   --  was.  Not saved.
   procedure Set_Corner_Steps (On : Boolean);
   function Corner_Steps return Boolean;
   function Square_Stair_Sites return Stair_Sites;   --  (counted when asked; nothing before the hearth stands)
   --  (why a step of two blocks or more at the end of a levelled stretch of the square's path is left
   --  as it is: the quarter metre past the end is on another side's path too; it lies before a
   --  stair;
   --  its own columns lie too far apart to be brought to one row; a column of it has no laid path to
   --  read: a boulder lies on the path there, a tree stands on it, or it is still to lay)
   type Step_Bar is (At_Crossing, Before_Stair, Uneven, Unread);
   type Step_Bars is array (Step_Bar) of Natural;
   type Walls_View is record
      Stone_Left : Natural := 0;   --  blocks of stone still to lay in them
      Dig_Left   : Natural := 0;   --  blocks of earth still to dig off for them
      Columns    : Natural := 0;   --  block columns of the floor that are wall, ledge or stair
      Highest_B  : Natural := 0;   --  the highest bank walled, blocks
      Lifts      : Natural := 0;   --  the most lifts in one wall (2 or more: set back)
      Stairs     : Natural := 0;
      Too_High   : Natural := 0;   --  sides whose bank is too high for a stair
      Stair_At   : Stair_Places := [others => No_Stair];   --  where each side's stands
      Stairs_Lost   : Natural := 0;   --  sides that would have one at their middle and take none at either end
      Stairs_Shared : Natural := 0;   --  sides whose stair is another side's, in the corner the two meet at
      Stairs_By_Level : Natural := 0; --  stairs in a corner where the path of the side met there comes in level
      Unready    : Natural := 0;   --  edge columns whose path beside them is still to lay
      --  Of a square whose walls stand outside its floor (Outside): the rings kept outside each side
      --  when it was founded, and the most lifts the path as laid asks of each (where the two differ
      --  the strip is too wide there, or too narrow); columns of wall that stand steeper than a ring
      --  a lift for want of rings; edge columns of the floor whose bank is left earth for want of a
      --  strip; and columns of the floor that are stone and neither a stair's step nor the earth
      --  beside one (none, if all is well).
      Outside    : Boolean := False;
      Strip      : Square_Strips := [others => 0];
      Need       : Square_Strips := [others => 0];
      Short      : Natural := 0;
      Unwalled   : Natural := 0;
      Inside     : Natural := 0;
      Capped     : Natural := 0;   --  columns of a strip that are no wall's: capped with stone at the path's level
      Strip_Zoned : Natural := 0;  --  columns of a strip that are some zone's ground (none: a strip is nobody's to zone)
      --  (the square's path stepped with stone: block columns of its path that are still to be made a
      --  step, or have their tread still to lay; and the quarter metres of path they are of)
      Path_Steps  : Natural := 0;
      Step_Slices : Natural := 0;
      Steps_Barred : Step_Bars := [others => 0];   --  jumps at a levelled stretch's end left as they are, by why
   end record;
   function Square_Walls_State return Walls_View;   --  (counted when asked; nothing before the hearth stands)
   function Walls_Left return Natural;              --  blocks of stone still to lay, as the band last counted
   procedure Build_Walls_Now (Most : Natural := Natural'Last);   --  on the spot, the stone from nowhere (a scripted
                                                    --  square); Most: so many blocks of stone at the most, in one bout
   --  The plan, column by column, for looking at it: each block column of
   --  the square's floor with the row its top is to be brought to and the
   --  lowest row of it that is to be stone (Top + 1: none), and the floor's
   --  level.  (Nothing before the hearth stands.)
   procedure For_Wall_Plan
     (Visit : not null access procedure (Bx, By, Top, Stone, Level : Integer));

   ------------------------------------------------------- housing

   --  Housing is a zone the player marks along a path, as a stockpile is
   --  (two corners; fill, snap, terminate).  That is all the player does:
   --  which lot, which house, for whom and when are the band's own.
   --
   --  Everyone without a home asks for one, a hovel each.  A hovel is begun
   --  for a person (it is theirs from its first block), only so many at
   --  once: as many as there are foresters to build them, and one even with
   --  none.  It is given the free frontage nearest the homestake along any
   --  path a housing zone lies on: a lot Lot_M along the path and Lot_M
   --  back, no two overlapping, the house (Castle.Buildings.Design: its
   --  size, door and windows from its own seed) square to the block grid,
   --  its front wall half a metre to a metre off the path's edge and its
   --  door toward the path; on a slanting path it steps back until it is
   --  clear.  Its walls and the bank round them have to lie wholly on the
   --  zone's ground, on ground that falls no more than a metre.
   --
   --  Builders come from the foresters.  A forester takes a house that has
   --  no builder (the best at building first), and is its builder until it
   --  stands: nobody is appointed, and no skill is asked yet.  It makes the
   --  ground ready a square metre at a time (the pad under the walls level,
   --  a bank Apron_B wide feathered round it, what grows there cut; the
   --  earth dug off fills the hollows and the rest is thrown aside on the
   --  lot), then lays the blueprint block by block in its order (the floor,
   --  the walls course by course, the gables, the roof), Lay_Blocks to a
   --  bout of Lay_S seconds, from what it has carried there: a log from the
   --  stockpile makes Planks_Per_Log blocks of plank or timber, a sheaf of
   --  straw Thatch_Per_Sheaf of thatch.  What a house takes is counted from
   --  its blueprint, and what its zone's houses are still short of is asked
   --  of the stores (the zone's rows of the demand table), so foresters
   --  fell and porters cut straw for it.  Building never takes the logs the
   --  camp's fire burns in a day, nor those its seats and hearth still
   --  want.
   --
   --  Reversion: a builder with nothing to build with (no wood in store
   --  that building may take, or no straw when the roof is next) goes on as
   --  the forester it is, and comes back to its house when there is some.
   --  Building is its own work, not an extra task: it counts against no
   --  limit, and the camp's building and the paths come first for it as
   --  for anyone.
   --
   --  When a house stands its owner lives there: it sleeps in it, not by
   --  the fire, and asleep under its own roof it is not cold in winter.  A
   --  house whose owner dies goes to the next without one.
   --
   --  At most Most_Builders foresters are builders at once (John,
   --  2026-11-17: "let's limit the number of builders that can be promoted
   --  to four"): a fifth forester fells, and no more houses are begun at
   --  once than there can be builders for.  Set_Builders (0), --builders 0:
   --  no limit, as before.  Saved with the colony.
   Most_Builders : constant := 4;
   procedure Set_Builders (N : Natural);
   function Builders_Most return Natural;   --  0: no limit
   --  **A builder with no house of its own helps at a larger one** (John,
   --  2026-11-23: "let's also have builders who finish their project help
   --  finish larger projects together").  A forester that could take a house
   --  (the best free at building, while fewer than Most_Builders build) and
   --  finds none without a builder goes to a larger house that is being
   --  built: one whose blueprint is more than Help_Over_B blocks (a hovel's
   --  is some 3,400, the storehouse's some 15,000: today, the storehouse),
   --  the one with the most still to lay, where no more than Help_Most build
   --  already.  It is a builder of that house beside its own: it makes
   --  ready a square metre of its ground that nobody else is at, fetches
   --  what it is short of, and lays the next blocks of its blueprint with
   --  what lies there, until it stands.  It leaves when a house has no
   --  builder (it takes that one) and while the roof is thatched (one
   --  ladder, one thatcher).  The house is its first builder's: whoever of
   --  them has the lower number.  Helpers count among the Most_Builders.
   --  Set_Build_Help (False), --no-build-help: one builder a house, as
   --  before.  Not saved (who builds what always was).
   Help_Over_B : constant := 6_000;
   Help_Most   : constant := 3;
   procedure Set_Build_Help (On : Boolean);
   function Build_Help return Boolean;
   function Helping (I : Positive) return Boolean;      --  it builds a house that another, of a lower number, builds too
   function Builders_At (H : Positive) return Natural;  --  the living whose house to build that is
   --  **A piece of a site's ground is worked from beside it** (John,
   --  2026-11-23: "the builder is standing on the blocks their placing and
   --  when the place them they fall through, maybe extend their reach a
   --  little bit").  A builder stood on the square metre it made ready: the
   --  earth it filled in closed over its feet, and the earth it dug off left
   --  it standing in the air.  It stands beside the square metre now, within
   --  Site_Reach_M of the middle of the work, on ground that is not of that
   --  piece: for choice ground with no work left in it (what is made already,
   --  or lies outside the site), and of that the nearest to where it stands.
   --  Where no such place can be got to, on the piece as before; and whoever
   --  is left standing in a column that earth was filled into stands on the
   --  earth, not in it.  Set_Reach_Out (False), --no-reach-out: on the piece,
   --  as before.  Not saved.
   Site_Reach_M : constant := 1.75;
   procedure Set_Reach_Out (On : Boolean);
   function Reach_Out return Boolean;
   function Stood_On_Fill return Natural;   --  times someone was stood on earth filled in round it (a measure, not saved)
   --  **A storehouse's ground is worked there and back** (the same message:
   --  "on top of that they walk back and fourth like a typewriter instead of
   --  a zigzag").  Its ground is made ready outward from the foot of its way
   --  in, by how far each square metre is to walk from there (Yard_Order):
   --  every row of that order was begun at the same end, and its builder
   --  walked the length of the row back to begin the next (four to six
   --  metres between one square metre and the next, counted at six
   --  stockyards).  The rows are a metre of that order deep now, and within a
   --  row the square metre nearest to where its builder stands is next: a row
   --  is begun where the last one ended.  The order of the rows is as it
   --  was, so what is dug has its way out as before.  A hovel's ground was
   --  worked so already (the nearest of the row nearest its path).
   --  Set_Zigzag (False), --no-zigzag: each row from the same end, as before.
   --  Not saved.
   procedure Set_Zigzag (On : Boolean);
   function Zigzag return Boolean;
   Lot_M            : constant := 7.0;
   Retain_Over_B    : constant := 1;      --  a rise or a fall of more than this many blocks at the edge of a
                                          --  house's ground is held by a wall of stone (John: "if its over .25m")
   Wall_Per_Stone   : constant := 16;     --  blocks of wall or stair a stone from the stockpile makes
   Planks_Per_Log   : constant := 96;     --  blocks of plank or timber a log makes
   Thatch_Per_Sheaf : constant := 64;     --  blocks of thatch a sheaf of straw makes
   Lay_Blocks       : constant := 16;     --  blocks laid in a bout: a square metre
   Trim_S           : constant := 2.0;    --  seconds a bout of trimming a roof takes (as many blocks: lighter work)
   Lay_S            : constant := 5.0;    --  seconds a bout
   Build_Reach_M    : constant := 2.5;    --  a block is laid from this near, across the ground
   Reach_Slack_M    : constant := 0.5;    --  (and a bout goes on to blocks this much further off)
   Stand_Off_B      : constant := 3.5;    --  a builder stands this many blocks clear of a wall it is laying,
   Stand_In_B       : constant := 3.0;    --  and inside the house only for what is this far in from every wall;
   Stand_Near_M     : constant := 1.2;    --  its way there may end this near the place chosen
   Bed_In_B         : constant := 4;      --  the owner's bed: this many blocks in from the left and the back wall
   Home_M           : constant := 1.5;    --  it is at home within this of its bed
   Max_Houses       : constant := Max_Members;
   Max_House_Blocks : constant := 24_576; --  blocks to a blueprint (its roof's trimming among them; a storehouse's
                                          --  yard: the largest stockyard's comes to some 17,000)
   Max_Fronts       : constant := 2_048;  --  frontages looked at for a lot (a metre of path, either side, each)
   Max_Site_Patches : constant := 1_134;  --  square metres of a building's ground, at most (its own and what it
                                          --  reaches over to a neighbour's)

   --  A trade is earned, not given: taken up by someone whose job leads to
   --  it (Trade_From) when there is work for it, and left for that job when
   --  there is not.  The builder is the first.  (Saved by position.)
   type Trade_Kind is (No_Trade, Builder, As_Stockman, As_Carpenter);
   Trade_From : constant array (Trade_Kind) of Job_Kind :=
     [No_Trade => Unassigned, Builder => Forester, As_Stockman => Porter, As_Carpenter => Forester];
   function Trade_Of (I : Positive) return Trade_Kind;   --  Builder: it has a house to build; As_Stockman:
                                                         --  the storehouse's stockman; As_Carpenter: its carpenter
   function Site_Of (I : Positive) return Natural;       --  the house it is building (0: none)
   function Home_Of (I : Positive) return Natural;       --  its house (0: none: a house is nobody's until it stands,
                                                         --  and is then drawn for by lot among those without one)
   function Housed (I : Positive) return Boolean;        --  it has one
   function At_Home (I : Positive) return Boolean;       --  and it is inside it
   function Homeless return Natural;                     --  the living whose house does not stand

   --  Housing is marked along a path (John, 2026-11-12: "make the area fixed
   --  distance from the path that will fit a hovel, and then they can pull
   --  it along the path to the desired length, and if they intersect with
   --  another habitation zone let them overlap and just combine the entire
   --  zone ... don't let them go farther than 7 blocks from the end or turn
   --  of a path").  First values, his to tune:
   Housing_Deep_M : constant := 9.5;     --  how far back from a path's edge housing reaches, beside a path that
                                         --  runs with the block grid (beside one that runs aslant, more: this
                                         --  times the sum of its way's two parts, 13.4 m at 45 degrees).  It is
                                         --  what the largest hovel takes on ground that falls 2 m across it,
                                         --  below its path: stood back for a stair of eight steps to its door
   Housing_Past_B : constant := 7;       --  block columns past an end or a turn of its path that it may reach
   Housing_Snap_M : constant := 12.0;    --  it is begun within this of a path, on the side it is begun on
   Housing_Long_M : constant := 60.0;    --  one pull along a path goes this far at most (pull again from its end)
   Run_Straight   : constant := 0.9986;  --  two stretches of path are one straight run within 3 degrees (the cosine),
   Run_Joint_M    : constant := 0.3;     --  their ends this near

   procedure Zone_Housing (X0, Y0, X1, Y1 : Float; Lots : out Natural);
   --  Housing begun at (X0, Y0) and pulled to (X1, Y1) (metres): a strip
   --  along the straight run of the path nearest the first point, on the
   --  side of it that point is on, from the path's edge Housing_Deep_M
   --  back, as long as from the one point to the other along the path.
   --  All of it that is free ground is taken, whether or not a hovel fits
   --  on it by itself; a housing zone it overlaps or touches is combined
   --  with it into one (Housing_Joined: how many were).  The lots of the
   --  houses still to begin are laid out anew, there and on all the other
   --  housing (it is done here, and when a path is laid: never while the
   --  band is at its work).  Lots: how many of them lie on this zone.  The
   --  next hovel in turn is never passed over for one that would fit: if it
   --  fits nowhere, no more are laid out (Lots_Short) until there is more
   --  housing or another path.  Refused (Housing_Refusal says
   --  why, "" if it was not): with no path within Housing_Snap_M of where
   --  it was begun, with no free ground in the strip, or too far from the
   --  stake.
   procedure Zone_Housing_Inside (X, Y : Float; Lots : out Natural);
   --  Housing of all the ground inside a round of paths (John, 2026-11-12:
   --  "it would be nice if player had a fill option for closed loop
   --  paths"): from the point (metres) out over free ground, a block at a
   --  time, until paths, other zones and whatever stands have stopped it on
   --  every side.  Housing it meets is combined with it, and the lots are
   --  laid out anew, as for a strip.  Refused (Housing_Refusal) where the
   --  ground is not closed round (it runs on as far as a lot can be worked
   --  out over, Max_Plan_B block columns across with the point in the
   --  middle, or to ground that is not in), where no path lies beside it,
   --  begun on a path, a zone or something standing, or too far from the
   --  stake.  It is as deep as the paths lie apart: the fixed depth of a
   --  strip and its seven blocks past a turn are a strip's rules, not its.
   function Plan_Housing_Inside (X, Y : Float; Count : Boolean := True) return Lot_Plan;
   --  What that would give, with nothing changed.

   --  Housing pulled with its path (John, 2026-11-20: "when the player
   --  starts laying the habitation what we are chaning with the zone right
   --  now is that it will include the path with the zone placement, it will
   --  allow either an overlap, extension, or intersection with an existing
   --  path"; and of its rows: "Housing on one side, if they want both sides
   --  they can lay down the zones twice. OR we can allow the player to
   --  select a double or single row?").
   --
   --  The player gives two points, where it was begun and where it was
   --  pulled to, and which rows.  Pull_Line reads the two points, once, for
   --  whoever shows it and whoever orders it:
   --
   --  Along a path.  Begun within Housing_Snap_M of a path, pulled the way
   --  that path runs (the nearest of the eight ways to the pull is the
   --  path's own, either way along it) and beside some of it (not all of
   --  the pull lies past one of its ends), it is housing along that path,
   --  as Zone_Housing's is for the same two points: nothing is laid where
   --  the path lies (an overlap).  Pulled past an end of that path by
   --  Path_Line_Least_M or more, the path goes on from its end as far as
   --  the pull went, to a whole number of blocks (an extension), and the
   --  housing with it.  (Begun on another path, one that runs another way,
   --  it is a line of its own from there: a street off that path.)
   --
   --  A line of its own.  Begun elsewhere, or pulled another way, its path
   --  is a line as the path tool draws one: from Path_Line_Start of where
   --  it was begun (on a path's middle line, at a path's end, or the corner
   --  of blocks nearest) to Path_Line_End of where it was pulled to (one of
   --  the eight ways; up to a path it comes to, or across one: an
   --  intersection), Housing_Long_M at the most.  What of that line a path
   --  lies along already is not laid again.
   --
   --  The housing is Zone_Housing's strip along that line, on the rows
   --  asked: the side it was begun on, the other, or both.  Begun on the
   --  line itself, the side begun is the left of the way it was pulled; or
   --  the right, where the left can take no housing and the right can
   --  (along a side of the square the colony was founded on, the side off
   --  its floor).
   --
   --  Where its path would run through housing already zoned, the housing
   --  gives way: the block columns under the path are no zone's any more,
   --  and the lots still to begin are laid out anew (so a street can leave
   --  a street that has housing along both its sides).  Not through the
   --  lot of a hovel begun or standing, nor through any other zone, nor the
   --  lord's cart: there it is refused (Pull_Refusal), as it is where no
   --  row asked can be zoned (for Housing_Refusal's reasons), and nothing
   --  is laid.  The path tool is as it was: a path alone goes round zones.
   --
   --  Nothing of it is saved that was not: its path is paths, its rows
   --  housing zones like any.
   type Pull_Rows is (Side_Begun, Other_Side, Both_Sides);
   type Pull_View is record
      Ok         : Boolean := False;          --  it was pulled far enough to be a line
      Begun, Pulled_To : Vec3 := (0.0, 0.0, 0.0);   --  the two points it was read from
      Along_Path : Boolean := False;          --  along a path that is there (else a line of its own)
      From, To   : Vec3 := (0.0, 0.0, 0.0);   --  its path's middle line, the way it was pulled
      Begun_Left : Boolean := True;           --  the side it was begun on is the left of that way
      New_Path_M : Float := 0.0;              --  of that line, what no path lies along yet
   end record;
   function Pull_Line (Begun, Pulled_To : Vec3) return Pull_View;
   --  The pull as it is read, once: whoever shows it and whoever orders it
   --  hand what this gives to the two below (which side is the side begun
   --  can take a look at both rows to say).
   function Plan_Housing_Pull (Line : Pull_View; Begun_Side : Boolean; Count : Boolean := True) return Lot_Plan;
   --  What one row of it would take (the side it was begun on, or the
   --  other), with nothing changed: the plan's ground is Planned_Run_At;
   --  Cells, with Count, the hovels it would hold.
   procedure Pull_Housing (Line : Pull_View; Rows : Pull_Rows; Lots : out Natural);
   --  Its path planned for the band to lay (laid, with the band's labour
   --  off) and its rows zoned.  Lots: the lots laid out on what was zoned.
   function Pull_Refusal return String;       --  why the last of those two was refused ("" if it was not)
   function Pull_Path_M return Float;         --  metres of path the last Pull_Housing added
   function Pull_Gave_Way return Natural;     --  block columns of housing that gave way under them
   function Pull_Rows_Zoned return Natural;   --  and how many of its rows it zoned (0 .. 2)
   --  Ground taken out of the housing again (John, 2026-11-17: "Add away to
   --  delete parts of a zone, and if a structure exists, mark a structure
   --  for razing").  Every block column of housing in the box (corners, in
   --  either order) is no zone's any more, and the lots of the hovels still
   --  to begin are laid out anew on what is left.  A hovel begun or
   --  standing any of whose lot is in the box keeps its lot zoned and is
   --  marked for razing (Marked): Columns, Marked say how much and how
   --  many.  Mark_Hovel sets or lifts it (a storehouse is never
   --  marked); Hovel_At: the hovel whose lot holds a point (0: none).  A
   --  zone all of whose ground is gone stays in the list with no ground, and
   --  is the next housing zoned.  Saved (the mark with its house, blob 31).
   --  Since his answer of 2026-11-19 ("limit razing buildings to unowned,
   --  this happens when a serf passes to a new job and they house somewhere
   --  else, for example when the farm is built"): only a hovel nobody owns
   --  is marked (one still being built is nobody's yet; a standing one is
   --  nobody's when its owner has died, and later when its owner houses
   --  elsewhere); a hovel lived in that is in the box keeps its lot and is
   --  left as it is (Unzone_Lived_In: how many, at the last Unzone_Housing).
   --  And a marked hovel is taken down: it is nobody's to draw, asks the
   --  stores for nothing, and a builder (as for a house to build) stands
   --  before its door and takes its blueprint's blocks off, the last laid
   --  first, twice a bout's laying to a bout; what they took lies at the
   --  site, and when nothing stands half of that goes to the stores, the
   --  hovel leaves the list (every house after it a number lower) and its
   --  lot leaves the zone.  Its beaten floor and the ground made for it
   --  stay as ground.  The mark lifted meanwhile, it is built up again from
   --  what lies there.  Razed, Razed_Came_Back: measures, not saved.
   function Unzone_Lived_In return Natural;
   function Razed return Natural;
   function Razed_Came_Back (K : Item_Kind) return Natural;
   procedure Unzone_Housing (X0, Y0, X1, Y1 : Float; Columns : out Natural; Marked : out Natural);
   procedure Mark_Hovel (H : Positive; On : Boolean);
   function Hovel_At (X, Y : Float) return Natural;
   function Housing_Refusal return String;   --  why the last Zone_Housing or Plan_Housing was refused ("" if it was not)
   function Housing_Joined return Natural;   --  the housing zones the last Zone_Housing was combined with
   function Lot_Count return Natural;        --  the lots laid out for houses not yet begun, on all the housing
   function Lot_At (K : Positive) return Lot_Corners;
   function Lot_Drawn_At (K : Positive) return Lot_Corners;   --  (its walls' corners where the house is to be drawn)
   --  The walls' outer corners, on the ground, of the house lot K is laid
   --  out for (K in 1 .. Lot_Count, in the order they will be begun).
   function Lot_Turn (K : Positive) return Integer;
   --  The eighth of a turn the house of lot K is to be drawn by (Set_House_Turn): 1, -1, or 0.
   function Lot_Design (K : Positive) return Castle.Buildings.House;
   --  The house lot K is laid out for, whole (for the checks: a lot comes
   --  back from a save the very house it was laid out as, its timbers too).
   function Lots_Short return Boolean;       --  the next hovel in turn fits nowhere on the housing there is
   function Room_Short return Boolean;       --  and someone is without a house with none being built for them
   function Plan_Housing (X0, Y0, X1, Y1 : Float; Count : Boolean := True) return Lot_Plan;
   --  What that zoning would give, with nothing changed (Cells: the hovels
   --  it would hold, if Count: they are counted by placing them, which is
   --  many times the cost of the strip's ground, so whatever shows a pull
   --  every frame asks without).

   --  A ladder for the roof (John, 2026-11-12: "serfs building spend a lot
   --  of time walking around the house thatching, can we have them construct
   --  a ladder in the stockpile, and use the ladder to thatch roofs, that
   --  would be cool").  First rules and values of mine, his to tune.  When a
   --  house's roof is next, its builder gets a ladder: one left standing at
   --  a hovel that is built, else one from a stockpile, else it makes one,
   --  at the stockpile, of Ladder_Wood logs that building may take
   --  (Ladder_S seconds, at its rate of building).  It carries it to the
   --  house and stands it under the eave of the slope that is next, at that
   --  wall's middle (clear of the door), and from the ladder a bout is laid
   --  with no walking: every block of that slope is within its reach.  When
   --  the other slope is next it carries the ladder round.  Trimming is done
   --  from it the same way.  The log is asked of the stores with the
   --  house's timber, from the day the house is begun; with none there that
   --  building may take when the roof comes, its builder goes and fells for
   --  it as the forester it is (Ladder_Fells_Most trees at the most).  With
   --  no ladder to be had and no wood for one after that, and where a ladder
   --  cannot be stood or got to, the roof is thatched from the ground as it
   --  was.  A ladder left at a hovel that stands goes
   --  to the next roof that wants one, or back to a stockpile while there
   --  is room there.  A ladder is in one place at every moment: stored,
   --  carried, or standing at a house (one carried by somebody who dies is
   --  lost with the rest of its load).  Two builders at two roofs want a
   --  ladder each.  Set_Ladders (False), --no-ladders: every roof from the
   --  ground, as it was.
   Ladder_Wood : constant := 1;       --  logs a ladder is made of
   Ladder_S    : constant := 20.0;    --  seconds it takes to make
   Ladder_Fells_Most : constant := 2; --  trees a builder goes to fell for want of that log, before it thatches from the ground
   Ladder_M    : constant := 3.4;     --  its length (drawn)
   procedure Set_Ladders (On : Boolean);
   function Ladders return Boolean;
   function Ladders_Made return Natural;             --  all told
   function Ladders_Lost return Natural;             --  with whoever carried them, all told
   function Ladders_Standing return Natural;         --  at houses now
   type Ladder_View is record
      Standing : Boolean := False;
      Side     : Natural := 0;                       --  the eave it is under: 1 front, 2 back, 3 left, 4 right
      Foot     : Vec3 := (0.0, 0.0, 0.0);            --  on the ground, where its builder stood it
      Top      : Vec3 := (0.0, 0.0, 0.0);            --  where it leans: the eave, or over it where its foot
                                                     --  stands high (never flatter than Ladder_Lean)
   end record;
   Ladder_Lean : constant := 1.3;                    --  it rises at least this much for each metre out
   function Ladder_At (H : Positive) return Ladder_View;   --  house H's
   function Aloft (I : Positive) return Boolean;           --  it is up a ladder, at a roof
   function Shown_At (I : Positive) return Vec3;
   --  Where member I is to be seen: Where (I), or on its ladder's rungs.

   type House_Phase is (Ground, Flooring, Framing, Walling, Roofing, Trimming, Yard, Standing);
   --  (Yard: a storehouse's yard, after its roof)
   type House_Wait is (Not_Waiting, For_A_Builder, For_Wood, For_Straw, For_A_Way, For_Stone);
   type House_View is record
      Kind    : Castle.Buildings.Building_Kind := Castle.Buildings.Hovel;
      Zone    : Natural := 0;
      Owner   : Natural := 0;                 --  whose it is (0: nobody's just now)
      Builder : Natural := 0;                 --  who is building it (0: nobody)
      Phase   : House_Phase := Ground;
      Blocks  : Natural := 0;                 --  its blueprint's blocks,
      Placed  : Natural := 0;                 --  and those laid
      Takes   : Per_Kind := [others => 0];    --  what it takes all told: wood in logs, straw in sheaves
      Got     : Per_Kind := [others => 0];    --  and what has been carried to it
      Waits   : House_Wait := Not_Waiting;    --  what its building waits for
      Corner  : Lot_Corners := [others => (0.0, 0.0, 0.0)];
      --  its walls' outer corners on the ground: front left, front right, back right, back left
      Door    : Vec3 := (0.0, 0.0, 0.0);      --  on the ground just outside its door (a storehouse's: before the
                                              --  middle of its front, wherever its stockyard's way in is)
      Way     : Natural := 0;                 --  how far its door is from the path it faces (block columns),
      Rise    : Integer := 0;                 --  and how far its floor lies above the path's ground there (rows);
                                              --  a storehouse's: of its stockyard's way in, where that is
      Bed     : Vec3 := (0.0, 0.0, 0.0);      --  where its owner sleeps
      Top_Z   : Float := 0.0;                 --  the height of its ridge (metres)
      Has_Bed : Boolean := False;             --  a bed of straw has been made in it (at Bed, lying back toward its door)
      Reach_L : Natural := 0;                 --  how far its ground reaches past its own yard to its left (seen
      Reach_R : Natural := 0;                 --  from its path) and to its right, to meet the ground of a house
                                              --  begun before it (block columns; 0: it does not, or they touch)
      Marked  : Boolean := False;             --  the player has marked it for razing (Unzone_Housing, Mark_Hovel)
      Turn    : Float := 0.0;                 --  it is drawn turned this far (radians) about the middle of its
                                              --  doorway (Doorway_At (K, 1)); 0: as it stands
      Turn_Ground : Boolean := False;         --  and its ground is made where it is drawn (Set_Turn_Ground)
      Drawn   : Lot_Corners := [others => (0.0, 0.0, 0.0)];   --  Corner as it is drawn (one not turned: Corner),
      Drawn_Door : Vec3 := (0.0, 0.0, 0.0);   --  and Door
      Pivot   : Vec3 := (0.0, 0.0, 0.0);      --  the point it is drawn turned about (the middle of its doorway;
                                              --  a storehouse's: near its middle)
      Walk          : Boolean := False;       --  it is one that is walked where it is drawn (such a storehouse; a
                                              --  hovel placed turned since 2026-11-20): what is said of its inside
                                              --  (Bed) is said where it is drawn
      Yard_Turned   : Boolean := False;       --  a storehouse drawn turned, its yard laid out along its path
      Walked_Drawn  : Boolean := False;       --  and the feet go by it as it is drawn (its walls and roof are up):
                                              --  who is in it is where it is seen
      People_Turned : Boolean := False;       --  who is within its walls as they stand, and its builder about
                                              --  them, is drawn through its turn: of one walked as it stands,
                                              --  always; of one walked where it is drawn, until it is (a hovel's
                                              --  builder; a storehouse's while its frame, walls and roof go up)
   end record;
   function House_Count return Natural;
   function House_At (K : Positive) return House_View;   --  K in 1 .. House_Count
   --  A hovel beside a path at 45 degrees is turned to it (John, 2026-11-19:
   --  "can't we just \"detatch\" the entire building and rotate it?"; the
   --  third step of it).  When a hovel is placed, the path nearest its
   --  doorway is looked at: if that runs at 45 degrees with its middle line
   --  through corners of blocks, the hovel is to be drawn turned an eighth
   --  of a turn about the middle of its doorway, the way that lays its
   --  front along the path (House_View.Turn; kept with the house, saved).
   --  Nothing else of the colony goes by it: the house stands square on the
   --  grid where it was placed, and is built, walked and lived in there.
   --  Set_House_Turn (False), --no-house-turn: no house is turned.  Saved.
   procedure Set_House_Turn (On : Boolean);
   function House_Turn_On return Boolean;
   --  **The ground of a hovel drawn turned** (the rest of that step, the same
   --  day).  The house stands square on the grid and is drawn swung about its
   --  doorway, so half of it is drawn off the ground it stands on.  With this
   --  on (the default), a hovel placed turned has its ground made where it is
   --  drawn as well: the block columns under it as drawn, and two round them,
   --  are of its site (brought to its pad's level, cleared of what grows and
   --  of boughs as high as its ridge, walled where the land beside stands
   --  over or under) and of its lot (no other house's lot or ground comes
   --  there, and where they are not its zone's free ground it is not placed);
   --  the fall of the ground is looked at under its walls as drawn too; its
   --  floor of beaten earth is laid under it as drawn, not under its walls as
   --  they stand (Castle.Buildings.Blueprint); and it reaches its ground to
   --  no neighbour's.  Fixed for a house when it is placed, and saved with
   --  it: a house placed with this off, or loaded from a blob before 37,
   --  keeps the square ground it has.  Set_Turn_Ground (False),
   --  --no-turn-ground: as before it (the colony's doing is then line for
   --  line what it is with no house turned).  Saved.
   procedure Set_Turn_Ground (On : Boolean);
   function Turn_Ground return Boolean;
   --  **Who walks keeps off the ground a turned hovel is drawn on.**  Its
   --  walls stand elsewhere, so nothing there stops a step: somebody crossing
   --  its yard was drawn walking through it.  With this on (the default), the
   --  ground under a hovel that stands with its ground made where it is
   --  drawn, less its walls' own place and the way out from its door, is
   --  walked at a tenth of the pace (Castle.Nav.Set_Kept): a way round is
   --  taken wherever there is one, and whoever has business there (a ladder
   --  left at its eave) still gets there.  From when it stands until it is
   --  marked to be razed: its builder works there before.  Set_Keep_Off
   --  (False), --no-keep-off: nothing is kept off.  Saved.
   procedure Set_Keep_Off (On : Boolean);
   function Keep_Off return Boolean;
   --  **A hovel placed turned is walked where it is drawn** (John,
   --  2026-11-20, of the storehouse's way offered for it: "Let's do that").
   --  Once its walls and roof are up the feet go by it as it is drawn
   --  (Castle.Nav.Set_Drawn; House_View.Walked_Drawn): its walls as drawn
   --  are walls, its doorway as drawn the way in, and the square its blocks
   --  stand on is walked as the turf it looks like.  So its bed is in it as
   --  drawn, whoever is in it is where they are seen (nobody in it is drawn
   --  through its turn any more: only its builder, while its frame, walls
   --  and roof go up), and nothing is kept off it: it needs no keeping off.
   --  Fixed when a hovel is placed, with its ground made where it is drawn
   --  (House.Walk), and saved with it.  Set_Hovel_Walk (False),
   --  --no-hovel-walk: as it was before (walked as it stands, its people
   --  drawn through its turn, the ground it is drawn on kept off).  Saved.
   procedure Set_Hovel_Walk (On : Boolean);
   function Hovel_Walk return Boolean;
   --  **A turned hovel is placed wherever a square one would be** (John,
   --  2026-11-19: "we don't want to limit the player they need to be able to
   --  place diagonals on hillsides if they want to").  The fall of the ground
   --  (2 m at the most) is taken under its walls as they stand, as a square
   --  house's is, and its ground is made under it as drawn however far the
   --  land falls there.  Set_Turn_Fall (True), --turn-fall: the fall is
   --  taken under its walls as drawn too, as it was for some hours that day
   --  (on the hillside east of the reference stake no turned hovel was then
   --  placed).  Not saved: it is asked only when a lot is laid out.
   procedure Set_Turn_Fall (On : Boolean);
   function Turn_Fall return Boolean;
   --  **What one of the band finds there is no way to, the others are told**
   --  (2026-11-20; the rest of John's "Let workers go 250m for resources",
   --  for the gatherers and the porters).  A gatherer went for the bush
   --  nearest it, and where that stood across water it found no way,
   --  remembered so for a minute, tried the two after it, and said "can't
   --  get there": with a dozen such bushes nearer than the first it could
   --  reach, it went round them for ever (at an open site by a river: 722 of
   --  the gatherers' serf-hours in twenty days).  With this on (the default,
   --  and only while the band looks further: Set_Wood_Reach), the way to a
   --  bush, an apple tree or a place to fetch from is asked as a forester
   --  asks the way to a tree (Castle.Nav's pieces of ground first: no
   --  search for what they show out of reach); one with no way to it, found by somebody who has
   --  a way home, is nobody's to try for a day (ten where the search ran
   --  out: a long way round), so the next thought is of the next nearest,
   --  Ask_Tries of them at a time; and when none in reach is left untried
   --  the band looks a ring further, as it does when there are none.
   --  Set_Ways_Told (False), --no-ways-told: each finds out for itself, as
   --  before.  Saved, with what has been told.
   procedure Set_Ways_Told (On : Boolean);
   function Ways_Told return Boolean;
   function Ways_Told_Now return Natural;      --  how many places nobody is to try just now
   --  Whether the ground at (X, Y) lies under house K as it is drawn: within
   --  its walls' outer faces turned about its doorway, and Margin metres round
   --  them (one not turned: under its walls as they stand).
   function House_Drawn_On (K : Positive; X, Y : Float; Margin : Float := 0.0) return Boolean;
   function House_Walls_On (K : Positive; X, Y : Float) return Boolean;   --  (under its walls as they stand)
   --  The ground a turned house is drawn on off its own walls' place, for
   --  measuring (colony_run --turn-stats): the block columns under it as
   --  drawn and a block round (its eave) that are not under its walls as
   --  they stand; those whose ground's top is not at its pad's level, and
   --  the most rows any is off; those with a tree, a bough or a bush over
   --  them as high as the house.
   type Drawn_Ground is record
      Columns, Off, Most_Off, Grown : Natural := 0;
   end record;
   function House_Drawn_Ground (K : Positive) return Drawn_Ground;
   --  For the checks and colony_run --turn-stats.  Yard_Ground, of a
   --  storehouse drawn turned (House_View.Yard_Turned): the block columns of
   --  all its ground as it is made (its yard, its staging, its way in), those
   --  not at the level they are to be at, and those with something growing
   --  over them.  House_Place, of any house drawn turned: where a spot is by
   --  it as it is drawn.
   function Yard_Ground (K : Positive) return Drawn_Ground;
   type Drawn_Place is (Off_It, In_Its_Wall, Within_It, Where_Its_Blocks_Stand);
   function House_Place (K : Positive; X, Y : Float) return Drawn_Place;

   --  **What of a stockyard is drawn as its design has it** rather than as
   --  its blocks are laid (Smooth_Covers, Fence_Pieces): a turned one's
   --  fence's rails, straight from post to post, two to a stretch, once the
   --  post that ends it stands; the planks over its gateways, straight from
   --  the gateway's post to the storehouse's corner as it is drawn, once
   --  laid; and its coverings' roofs, each as far back from its front as it
   --  is smoothed (Smoothed of Rows, Castle.Buildings.Cover_D_B), in the
   --  plane through its front and its back edge.  The game draws them.
   Max_Yard_Rails : constant := 96;
   type Yard_Rail is record
      A, B  : Vec3;                 --  the middle of the rail at either end, metres
      Plank : Boolean := False;     --  a plank over a gateway
   end record;
   type Yard_Rail_List is array (1 .. Max_Yard_Rails) of Yard_Rail;
   type Yard_Roof is record
      Front_L, Front_R, Back_R, Back_L : Vec3;    --  its top's corners, metres: its front (the higher
                                                  --  edge, toward the storehouse) from left to right
      Smoothed, Rows : Natural := 0;              --  rows of it smoothed, from its front, of so many
   end record;
   type Yard_Roof_List is array (1 .. 8) of Yard_Roof;    --  (Castle.Buildings.Max_Covers)
   type Yard_Pieces_View is record
      Rails : Yard_Rail_List;
      N_Rails : Natural := 0;
      Roofs : Yard_Roof_List;
      N_Roofs : Natural := 0;
   end record;
   function Yard_Pieces (K : Positive) return Yard_Pieces_View;
   --  A house's doorways, for the drawing of their leaves (John, 2026-11-17:
   --  "Add doors and animations to buildings"): one in a hovel's front, one
   --  in each end of a storehouse.  A doorway is still an opening of the
   --  walls that anyone walks through: nothing here is saved or simulated.
   type Doorway_View is record
      Foot   : Vec3 := (0.0, 0.0, 0.0);      --  on the floor in the middle of the wall's thickness, at one side of it
      Along  : Vec3 := (1.0, 0.0, 0.0);      --  level unit vector from there to its other side,
      Inward : Vec3 := (0.0, 1.0, 0.0);      --  and into the house
      Width  : Float := 1.0;                 --  metres
      Height : Float := 2.0;
      Hung   : Boolean := True;              --  (a gateway: its post is raised, so a leaf can hang there)
   end record;
   function Doorway_Count (K : Positive) return Natural;                 --  of house K
   function Doorway_At (K : Positive; N : Positive) return Doorway_View;  --  N in 1 .. Doorway_Count (K)
   --  Its windows the same way (the foot at the opening's lower corner, at
   --  its sill's top), for the trim drawn round them (John, 2026-11-19:
   --  "Thin trim around the tops and side(s)"); and a storehouse's two
   --  gateways, for their leaves ("yeah add the leafs on the gateways"): the
   --  foot on the ground as it lies at the storehouse's end of the gateway,
   --  Inward into the yard, Hung once the gateway's outer post is raised.
   function Window_Count (K : Positive) return Natural;
   function Window_At (K : Positive; N : Positive) return Doorway_View;
   function Gateway_Count (K : Positive) return Natural;                 --  2 for a storehouse on its yard, else 0
   function Gateway_At (K : Positive; N : Positive) return Doorway_View;
   function House_On (X, Y : Float) return Natural;
   --  The house whose walls stand, or are to stand, round (X, Y) (0: none).
   --  Beds (John, 2026-11-12: "when the campground is built have them pull
   --  or collect straw for a bed ... When they get assigned a home they can
   --  build a new straw bed in their house, we will let the old one decay
   --  outside when we add decay later").  Each of the band makes itself a
   --  bed of straw where it sleeps: by the fire once the camp is built, and
   --  another in its house when one falls to it; the one by the fire stays
   --  where it was made.  First values, his to tune:
   Bed_Straw : constant := 2;            --  sheaves of straw to a bed (or as many as it could come by: one at least)
   --  Its straw is the stockpile's, before the hovels being built have any
   --  of it (John, 2026-11-12: "serfs didn't create a bed when straw was in
   --  the stockpile, might have been reserved by the housing, basic needs
   --  take priority"); with none stored it cuts its own, as a porter cuts
   --  straw.  And its bed comes before the band's building (the paths; not
   --  the camp, which it waits for).  A bed changes nothing but where its
   --  maker is seen to lie.
   --
   --  Where each lies by the fire (John, 2026-11-12: "it would be nice if
   --  the serfs found level ground and slept perpendicular to the fire"):
   --  once the camp stands each of the band looks for a place of its own
   --  round the fire, lying across the way to it, on ground that is the
   --  camp's or nobody's, level under all its length, that it can get to
   --  and nobody else has; the nearest such to the fire.  Chosen once and
   --  kept (it makes its bed there), until something is built or dug where
   --  it lies.  First values, his to tune:
   Bed_Near_M   : constant := 3.0;      --  a sleeper's middle is no nearer the fire than this (clear of the camp's floor),
   Bed_Far_M    : constant := 5.5;      --  and no further (asleep within 6 m of a warm fire it is not cold)
   Bed_Ring_M   : constant := 0.5;      --  places are tried on rings this far apart, this far apart round each
   Bed_Apart_M  : constant := 0.9;      --  two sleepers lie this far apart at the least, middle line to middle line
   Bed_Step_M   : constant := 3.0;      --  a place a block out of level is as good as a level one this much further off,
   Bed_Uneven_B : constant := 2;        --  and one more blocks out of level than this is no place at all
   --  (with no such place within Bed_Far_M it lies as the band did before:
   --  on a ring round the fire, its feet to it, whatever the ground)
   procedure Set_Beds (On : Boolean);    --  off: the band as it was before it made beds (the older reference runs)
   function Beds return Boolean;
   function Has_Bed (I : Positive) return Boolean;   --  it has a bed where it sleeps now (its house's, if it has a house)
   function Straw_In_Beds return Natural;            --  sheaves, in all the beds made
   type Bed_View is record
      Made   : Boolean := False;
      Feet   : Vec3 := (0.0, 0.0, 0.0);  --  where its sleeper's feet are: it lies back from there,
      Toward : Vec3 := (0.0, 0.0, 0.0);  --  away from this (a point a metre beyond its feet)
      By_Fire : Boolean := False;        --  at the camp, across the way to the fire: its sleeper turns to face it
   end record;
   function Sleeping_Place (I : Positive) return Bed_View;
   --  Where member I lies down to sleep now (Made: on a bed), and what its
   --  feet point to: its cloak lies there while it is not wearing it.
   function Camp_Bed (I : Positive) return Bed_View;
   --  The bed member I made itself at the camp (it lies there still when the
   --  member has a house, and when it is dead).

   procedure Build_Homes_Now (Last_First : Boolean := False; As_Laid : Boolean := False);
   --  A house for everyone without one, begun and built on the spot, nothing
   --  taken from anywhere, for as many as the housing zones have room for:
   --  for scripted starts (--homes-built) and the checks, as Supply is.
   --  (Last_First: the houses already begun are raised the last of them
   --  first, so that a house's ground is made ready before that of the
   --  earlier house beside it: for the checks.  As_Laid: a storehouse's yard
   --  is laid on the ground as it lies, as its builder lays it, where it is
   --  otherwise written as drawn up, at the floor's row everywhere: for
   --  whatever looks at a stockyard's ground, its stair or its walls.)

   ------------------------------------------------------- a person, as data

   --  What there is to know of member I, for whatever shows it (a panel, a
   --  tooltip, later a report): its name is Name_Of, what it says it is
   --  doing Status, its looks Genome_Of.
   type Person_View is record
      Job      : Job_Kind := Unassigned;
      Director : Actor := No_One;
      Doing    : Act := Standing;
      Child, Elder : Boolean := False;
      Fed      : Float := 1.0;              --  0 (starving) .. 1 (full)
      Mood     : Float := 0.0;              --  0 .. 1
      Hungry, Starving, Asleep, Fending, Cold, Dead : Boolean := False;
      Carrying : Item_Kind := Nothing;
      Carried  : Natural := 0;
      Grain    : Natural := 0;              --  handfuls with its straw
      Zone     : Natural := 0;              --  the zone it stands in (0: none)
      Level    : Shares := [others => 0.0]; --  its skills, 0 .. 1
      Aptitude : Shares := [others => 1.0]; --  how fast it learns each
      Work     : Work_Kind := Handling;     --  what it is at now, for its practice
      Resting  : Boolean := False;          --  at rest: nothing its job brings in is asked for
      Trade    : Trade_Kind := No_Trade;    --  the trade it is at (a builder: a forester with a house to build)
      Site     : Natural := 0;              --  the house it is building (0: none)
      Home     : Natural := 0;              --  its house (0: none begun),
      Housed   : Boolean := False;          --  and whether it stands
      Has_Bed  : Boolean := False;          --  it has a bed of straw where it sleeps now
   end record;
   function Person (I : Positive) return Person_View;

   ------------------------------------------------------- demand

   --  Demand starts with the people and runs up the supply chain.  What
   --  is used is asked of the stores (the stockpiles, all of them together);
   --  the player asks for a surplus on top; and what the stores are then
   --  short of is what the band's producers work to bring in.  Nothing else
   --  sets them to work: with what is asked for in store, they stop.
   --
   --  The table has a row for everything asked: who asks, for what, and how
   --  much.  Who asks today:
   --    the people   food: what the band eats in a day (in points; any food
   --                 will do, counted as the pot would make it)
   --    a zone       the camp: logs for its fire, by the day (what it burns
   --                 from an hour before bedtime to waking, and one for the
   --                 cooking; in winter all day), and for its seats, once
   --    the paths    stone, for paving (Stone_Quota, till there are masons
   --                 to ask for it)
   --    an order     a surplus the player wants kept: of wood, straw, meat
   --                 or vegetables (Set_Reserve), and of food, in days (the
   --                 winter store: asked for all year; in winter it is eaten,
   --                 and whoever can still bring food in goes on doing so)
   --  Only an order is set by hand; the rest follow from what is there.
   --
   --  The stores stand at two levels for each good.  One with users is
   --  asked for once the stores are down to its surplus and Ask_Below_Days
   --  of its use, and until they hold the surplus and Ask_Until_Days of it.
   --  One nobody uses by the day is asked for while it is short of what is
   --  wanted (its surplus, and what is wanted once).  Whether each is being
   --  asked for is saved.  Stock is taken once a colony second.
   --
   --  Producers answer what is asked: a forester fells while wood is asked
   --  for, a porter fetches straw and stone while they are, a hunter hunts
   --  while meat is, or food; a gatherer gathers while food is asked for,
   --  or else whichever of its own kinds (Gathered) is, and that alone.
   --  Needs come first as ever: eating, sleeping, fending for oneself and a
   --  cook's gathering when it has nothing to cook ask nobody's leave.
   Ask_Below_Days : constant := 1.0;
   Ask_Until_Days : constant := 2.0;
   Gathered : constant Kind_List := [Vegetables, Berries, Apples];   --  what gatherers bring in

   type Asker is (The_People, A_Zone, The_Paths, An_Order);
   type Ask_Kind is (By_The_Day, Once, Surplus);
   type Demand_Row is record
      Who    : Asker := An_Order;
      Zone   : Natural := 0;           --  A_Zone: which
      By     : Actor := No_One;        --  An_Order: whose (the player's)
      Kind   : Ask_Kind := Surplus;
      Food   : Boolean := False;       --  food of any kind, Amount in points; else What, by its own count
      What   : Item_Kind := Nothing;
      Amount : Natural := 0;           --  By_The_Day: what a day takes
   end record;
   Max_Demand_Rows : constant := 32;
   function Demand_Rows return Natural;
   function Demand_Row_At (K : Positive) return Demand_Row;   --  K in 1 .. Demand_Rows

   --  A good, as the stores stand to it.
   type Good_View is record
      Have    : Natural := 0;       --  stored, carried and on its way (food: points in store and in the pot)
      A_Day   : Natural := 0;       --  what its users take in a day
      Once    : Natural := 0;       --  what is wanted for a use, all told
      Surplus : Natural := 0;       --  what the orders ask kept on top
      Low     : Natural := 0;       --  asked for once the stores are down to this
      High    : Natural := 0;       --  and until they hold this
      Asked   : Boolean := False;   --  it is being asked for now
      Makers  : Natural := 0;       --  the living whose job brings it in
   end record;
   function Demand_For (K : Item_Kind) return Good_View;
   function Food_Demand return Good_View;   --  food as one good, in points
   function Food_A_Day return Natural;      --  points the band eats in a day (0 with needs off)

   function Asked_For (K : Item_Kind) return Boolean;
   --  K is to be brought in now: it is asked for by its own count or, a
   --  food that is hunted or gathered, food is.  This is the one question
   --  every producer puts before it sets out.

   procedure Set_Demand_Chain (On : Boolean);
   --  On (the default): as above.  Off: the colony as it was before there
   --  was a chain, for checks of the work alone and as a baseline: gatherers
   --  never stop, hunters hunt only while meat is short of its reserve, a
   --  wood reserve of none is no limit, and nothing has two levels.  Either
   --  way it sets the wood reserve to what that way of working starts with
   --  (the default surplus on, none off), so it is said before any order for
   --  wood.  Saved with the colony.
   function Demand_Chain return Boolean;

   ------------------------------------------------------- saves

   type Bytes is array (Natural range <>) of Interfaces.Unsigned_8;
   function Save return Bytes;
   procedure Load (B : Bytes; Ok : out Boolean);
   procedure Reset;   --  no colony at all

   ------------------------------------------------------- hunting

   --  A hunter goes for the nearest grown deer of a herd larger than
   --  Spare_Last (so a herd can always breed), while the colony is short
   --  of meat and deer are not spared.  It walks until it is Close_M off,
   --  then stalks (slowly, unseen until it is Castle.Herds.Stalked_M
   --  away) to Shoot_M, and with a clear line draws its short bow (Draw_S)
   --  and looses: a hit is likelier the nearer it is.  Hit or missed, the
   --  herd bolts.  A deer brought down lies where it fell; the hunter
   --  carries it home across its shoulders and butchers it at the
   --  stockpile, its meat and hide going into cells there.
   Spare_Last : constant := 3;
   Close_M    : constant := 30.0;
   Shoot_M    : constant := 18.0;
   Draw_S     : constant := 1.5;
   Butcher_S  : constant := 10.0;
   function Meat_Of (C : Castle.Deer.Class) return Positive;
   --  The meat a deer gives: pounds of it dressed, all of it kept if it is
   --  salted as it is butchered (below); with curing off, joints, as it was.

   --  The lord's cart, salt, and meat by the pound (John, 2026-11-12: "we
   --  need to up the amount of meat a single deer can provide, we are
   --  looking at 60lbs of field dressed meat from a deer that should be
   --  enough to feed a camp for a couple of days when smoked or cured ...
   --  the player is a minor noble tasked wtih improving the land by their
   --  lord, taxes on production would come after a few years, so the lord
   --  provides a small workforce a minimum of starting supplies so for now
   --  lets just add a cart with salt in it for curing, we can expand the
   --  supplies later and work the story in as we get to the players role,
   --  but for now that way a single deer can provide for the camp for a
   --  couple of days").  First values and first rules of mine, his to tune:
   --
   --  Meat is counted in pounds.  A doe gives 60 lb dressed (Deer_Lb: a
   --  stag more, a young stag and a fawn less), and a pound is worth
   --  Pound_Stew points in the pot, so that a doe's meat is two days' food
   --  for a band of six (60 x 48 = 2,880 points; six eat 1,440 a day).
   --
   --  The band arrives with a cart, the lord's, which stands a few metres
   --  from the homestake from the moment that is raised (Cart_Near_M to
   --  Cart_Far_M off, on the first level, open ground found going out a
   --  metre at a time and round from the north), with Cart_Salt_Lb of salt
   --  in it.  It is a thing in
   --  the world: nothing is zoned over it, a camp marked over it and a path
   --  laid through it are refused, nobody walks through it, and it can be
   --  pointed at (its sheet says what is left in it).
   --
   --  The band pulls it into the stockpile zone nearest it (John,
   --  2026-11-13: "the cart, can they pull it into the closest stockpile
   --  zone?"), as an extra task of the band's (after the camp and its seats,
   --  before the paths), once there is one: one of them goes to its shafts,
   --  lifts them and pulls it at Cart_Tow_Pace of a walk to a place in the
   --  zone held for it from the start, where it is set down.  The place is
   --  two of the zone's places side by side, empty, the nearest such to it
   --  in the zone nearest it that has them, on level ground (its bed square
   --  to the grid, along the way the two lie); nothing is put on a place
   --  under it, standing or held for it, and nothing else about the
   --  stockpile changes.  In tow it is nothing of the world: drawn behind its
   --  puller, its middle Cart_Shaft_M back.  Its puller called away (to
   --  other work, dead): it is set down where it is, or near, or back where
   --  it stood.  Standing in a stockpile zone it stays.  Its salt is
   --  fetched and used as before.  Set_Cart_Pull (False), --no-cart-pull:
   --  it stays where it stood, as before.
   --
   --  A hunter with empty hands keeps salt by for its kills: while the
   --  stockpiles hold less than Salt_Keep_Lb of it, the cart has some and
   --  there is room to store it, it fetches a sackful (Carry_Limit (Salt))
   --  from the cart to a stockpile before it goes after deer.
   --
   --  A deer is salted as it is butchered, with the salt in the stockpiles:
   --  a pound of salt to Lb_Per_Salt of meat.  Salted, all of its meat is
   --  kept.  With no salt, only what can be eaten before the rest turns is
   --  kept: one pound in Fresh_Div (with some salt, that much of it is
   --  salted and the rest goes as unsalted meat does).  Nothing spoils once
   --  it is stored: spoilage is a later stage's, and until then this is the
   --  whole of what salt does.  Meat is never asked for in salt's name, and
   --  salt is never in the demand table: nobody of the band can make it.
   --
   --  Set_Curing (False), --no-curing: the band as it was before any of
   --  this: no cart, no salt, meat in joints (a doe 8, a joint 30 points in
   --  the pot, four to a load, twenty to a place).  The seven older
   --  reference runs are held at it.
   type Deer_Yield is array (Castle.Deer.Class) of Positive;
   Deer_Lb      : constant Deer_Yield :=
     [Castle.Deer.Fawn => 20, Castle.Deer.Doe => 60, Castle.Deer.Young_Stag => 45, Castle.Deer.Stag => 75];
   Deer_Joints  : constant Deer_Yield :=
     [Castle.Deer.Fawn => 3, Castle.Deer.Doe => 8, Castle.Deer.Young_Stag => 6, Castle.Deer.Stag => 10];
   Pound_Stew   : constant := 48;      --  points a pound of meat gives in the pot
   Meat_Load_Lb : constant := 20;      --  pounds of meat carried at once
   Meat_Cell_Lb : constant := 120;     --  and to a stockpile's place (two does)
   Lb_Per_Salt  : constant := 10;      --  pounds of meat a pound of salt cures
   Fresh_Div    : constant := 4;       --  unsalted, one pound in this many is kept
   Cart_Salt_Lb : constant := 240;     --  the salt the band is sent out with (forty does' worth)
   Salt_Keep_Lb : constant := 16;      --  a hunter fetches more when the stockpiles hold less (two stags' worth)
   Cart_Near_M  : constant := 4.0;     --  the cart stands this far from the stake at the least,
   Cart_Far_M   : constant := 20.0;    --  and no further (found none so near: there is no cart)
   Cart_Long_B  : constant := 8;       --  its bed, in block columns: 2 m long
   Cart_Wide_B  : constant := 4;       --  and 1 m across
   Cart_Up_B    : constant := 3;       --  and this many rows over the ground it stands on (its floor's top: 0.75 m)
   Cart_Tow_Pace : constant := 0.6;    --  pulling it, a walk's pace this much of its own
   Cart_Shaft_M : constant := 2.3;     --  from its middle to the bar across its shafts (where its puller stands)

   procedure Set_Curing (On : Boolean);
   --  Said before the stake is raised (the cart comes with the band); off:
   --  the band as it was.  Saved with the colony.
   function Curing return Boolean;
   function Kept_Of (Lb, Salt_Lb : Natural) return Natural;
   --  What is kept of Lb pounds of a deer butchered with Salt_Lb pounds of
   --  salt to hand.
   function Salt_For (Lb : Natural) return Natural;   --  the salt that all of it takes

   type Cart_View is record
      Here  : Boolean := False;            --  there is one
      At_P  : Vec3 := (0.0, 0.0, 0.0);     --  the middle of it, on the ground it stands on
      Along_X : Boolean := True;           --  it lies along the world's X (else along Y)
      Salt  : Natural := 0;                --  pounds of salt left in it
      Turn  : Float := 0.0;                --  the way its shafts point (radians)
      Towed : Boolean := False;            --  in tow, by
      By    : Natural := 0;                --  that member
   end record;
   procedure Set_Cart_Pull (On : Boolean);
   function Cart_Pull return Boolean;
   function Cart_In_Stockpile return Boolean;   --  it stands, its middle on a stockpile zone's ground
   --  **Room round the cart** (John, 2026-11-23: "some clipping issues where
   --  the cart or goods are placed on top of each other", with a picture of
   --  a sack under its wheel).  Nothing was put on a place under its bed;
   --  but the cart as it is drawn reaches past its bed, a wheel to either
   --  side of it and its shafts before it, over the places beside and before
   --  the two it stands on.  Nothing is put on those either: the two places
   --  to either side of its bed, and the two its shafts lie over (six places
   --  more).  What lies there already stays until it is taken.  Where the
   --  cart goes and stands is untouched (his word of 2026-11-22: "leave the
   --  cart doing whatever it's doing right now").  Set_Cart_Room (False),
   --  --no-cart-room: as before.  Not saved.
   procedure Set_Cart_Room (On : Boolean);
   function Cart_Room return Boolean;
   --  **A walker is at the height of the place it steps into as it steps
   --  into it** (2026-11-23, found when the stockpile's places were made
   --  level: of 2,540 serf-seconds in eighteen days of the game as it is
   --  played with someone standing still and a block of the ground in its own
   --  block column at its feet, nearly all were at the stockpile, eating or
   --  looking for work, a block deep).  A way is a line of points, one
   --  wherever the height changes: the first eighth of a metre inside the
   --  next place of the walking map (Castle.Nav.Line).  Between two points a
   --  walker kept the height of the one it had left, so for that eighth it
   --  walked in the step it was climbing, and whoever stopped there (one
   --  stops as soon as its work is within reach, so the same few centimetres
   --  past the same edge every time) stood in it until it next walked.  Now
   --  it has the next point's height from where it enters that point's
   --  place.  Set_Step_At_Edge (False), --no-step-at-edge: as before.  Not
   --  saved (nothing to save: it is where the feet are put, each step).
   procedure Set_Step_At_Edge (On : Boolean);
   function Step_At_Edge return Boolean;
   --  **A stockpile is one level** (John, 2026-11-23, of "flatten a stockpile
   --  whole, or each place by itself?": "flatten the stockpile, let's just
   --  make this easy for ourselves").  Where a stockpile is put down, all its
   --  ground is brought to one level, at once and by nobody (as a place was
   --  made level), and every place of it has that height.
   --
   --  **The level is the middle one of its ground's block columns that have
   --  a path's column beside them** (the lower of two), so that it is walked
   --  into from its path; with no such column, the middle one of all its
   --  ground.  (Counted over 58 stockpiles as the land lay, `colony_run
   --  --flat-scan` with the rule off: at the middle of all the ground none
   --  of the front lay within two blocks of its path at 4 of them, and
   --  John's own had no way in from its path; at the lowest of the front
   --  the cut is deeper for less of the front.  Built: all of the front
   --  within two blocks of its path at 46, half of it or more at 56, some
   --  of it at all 58.)
   --
   --  The land is cut or filled as far as Flat_Most_B blocks, **whatever it
   --  is made of** (earth, rock, a boulder, ore at the surface), and what
   --  lay on top lies on top (turf stays turf, rock rock; where a boulder is
   --  cut through or lies in the floor's top, earth: a boulder's block in
   --  the floor would be prised out of it for its stone and leave a hole
   --  under what is stored).  The stone of a boulder cut away is nobody's:
   --  it is gone, as the earth is.  (The square leaves a boulder standing
   --  and is made round it.  Left standing in a stockpile cut two metres
   --  down round it, a boulder stood on a plinth of its own earth with the
   --  places over it closed, and the earth under it stood bare when the
   --  band had prised it away; and bog iron lies in the turf of three block
   --  columns in ten at the reference stake.)  No wall is built and no
   --  stair: where the land beside stands off it, it stands as a bank.
   --
   --  **It is all of what was marked**: its lot is planned for ground that
   --  will be one level, so it takes the ledges in its box (as far as
   --  Flat_Most_B) and a place lies on it however the land falls under the
   --  place (Plan_Lot, One_Level).  As the land lay, a ledge higher than
   --  Zone_Step_M ended it and a place needed its square metre within half
   --  a metre of level.
   --
   --  **What the zoning still leaves out inside it goes with it**: an
   --  island of ground in it (a bush stands there) is brought to the level
   --  too, and a bush goes up or down with its ground, block column by
   --  block column; leaves that hang where the floor comes up are lopped as
   --  high as a serf stands.  (Left as it lay under a floor filled in round
   --  it, such an island is a pit a serf walks into and not out of: the
   --  walking map lets one drop a metre and climb half.  A gatherer starved
   --  in one by a bush, at the square in the wood, in the first run of this
   --  rule.)
   --
   --  Left as it lies, for good: a block column further off the level than
   --  Flat_Most_B, one with something laid or built on top, one with water
   --  in what would be moved, one beside water that stands higher than it
   --  would be cut to (the water's bank), and one with something standing
   --  where the earth would go.  **A place with such a column in it is a
   --  place no more** (closed, and kept closed: Flat_Note.Shut): nothing is
   --  put half in a pond.  Left until it is free: the ground a trunk stands
   --  on (the tree stands on a pillar of its own earth, or in a hollow,
   --  until it is felled, stump and roots; then the stockpile is made level
   --  again where it stood) and the ground under the cart and a metre round
   --  it (the place is made level when the cart is gone: Level_Places,
   --  which with this rule makes every open place level as soon as it can,
   --  as far as it takes, and looks again at one a trunk was in the way
   --  of).
   --
   --  Whoever stands there is put on the ground as it is now, and logs or a
   --  deer lying there; every way being walked is found again.
   --  Set_Pile_Flat (False), the default (--pile-flat sets it): each place by itself, three
   --  blocks at the most, on ground a ledge ends, as on the morning of
   --  2026-11-23.  Not saved (a place's height is, and whether it is
   --  closed; a stockpile of an older save keeps its places' own heights).
   --  The stockyard is not touched: its ground is its storehouse's.
   --
   --  **Off since the afternoon of 2026-11-23** (John, of the picture of his
   --  own stockpile cut four metres into its hill: "let's go back to the
   --  stepped version, not the cut one"): the stockpile is stepped again,
   --  each place by itself, and --pile-flat gives this rule.  In its place:
   --
   --  **A stockpile is refused on ground too steep** (the same message:
   --  "let's block the players placement if it's too steep, let's say
   --  anything where a part is over 1/2 slope").  Set_Steep_Refuse,
   --  --no-steep-refuse.  Read as: some part of the ground it would take
   --  rises more than Steep_Rise_B blocks (half a metre) over a metre, along
   --  the block grid either way; or a ledge lies in it (two neighbouring
   --  block columns of its lot more than Zone_Step_M apart, which as it was
   --  ended the stockpile there).  A boulder in it and a tree's foot are
   --  not counted: they stand on a slope without being one.  Refused whole,
   --  with its reason said at the pointer ("the ground is too steep for a
   --  stockpile there ..."), dragged or put down whole.  Not asked of a
   --  stockpile that is to be one level, nor of the stockyard (its floor is
   --  its storehouse's, and has its own bounds).  Not saved.
   Steep_Rise_B : constant := 2;
   procedure Set_Steep_Refuse (On : Boolean);
   function Steep_Refuse return Boolean;
   procedure Set_Pile_Flat (On : Boolean);
   function Pile_Flat return Boolean;
   Flat_Most_B : constant := 24;       --  (six metres: the deepest cut at the 58 was eighteen)
   type Flat_Note is record
      Zone      : Natural := 0;        --  the stockpile last made one level (0: none yet)
      Level_M   : Float := 0.0;        --  the height its things lie at
      By_Path   : Boolean := False;    --  taken from its ground beside a path (else: from all its ground)
      Columns   : Natural := 0;        --  the block columns of its ground,
      Left      : Natural := 0;        --  those of them left as they lie (for good, or until a tree or the cart is gone),
      Cut_Most  : Natural := 0;        --  the deepest cut and
      Fill_Most : Natural := 0;        --  the highest fill (blocks),
      Moved     : Natural := 0;        --  and the blocks cut off or put under in all
      Bushes    : Natural := 0;        --  bushes that stood on it, moved up or down with their ground
      Shut      : Natural := 0;        --  its places closed: a block column in them is never moved (rock, water)
   end record;
   --  What a block column of a stockpile's ground is to its level.
   type Flat_Column is
     (At_Level,        --  it lies at the level
      To_Move,         --  earth to cut off or to put under
      Trunk_On,        --  left until the tree on it is felled, stump and roots
      Cart_On,         --  left until the cart is gone from it
      No_Ground,       --  (left for good, from here on) no ground is found there
      Too_Far,         --  further off the level than Flat_Most_B
      Not_Earth,       --  its top is nothing of the land's: stone laid there, something built
      Water_In,        --  water in what would be moved
      Thing_Over,      --  something stands where the earth would go
      Water_By);       --  water stands beside it, higher than it would be cut to: its bank
   subtype Flat_Waits is Flat_Column range Trunk_On .. Cart_On;
   subtype Flat_Never is Flat_Column range No_Ground .. Water_By;
   --  An instrument's (`colony_run --column`, `--flat-scan`): what the block
   --  column is to the level of the stockpile whose ground it is (Zone 0:
   --  it is no stockpile's), read from the world as it lies now.
   procedure Flat_Column_At (Bx, By : Integer; Zone : out Natural; Level_M : out Float; Kind : out Flat_Column);
   function Last_Flat return Flat_Note;
   function Piles_Flattened return Natural;
   function Last_Flat_Said return String;     --  that note in a line, for a log ("made one level: ...")
   function Cart return Cart_View;
   function Cart_On (X, Y : Float) return Boolean;   --  (metres) its bed is over that ground
   function Cart_Beside return Vec3;                 --  where one stands to take from it
   procedure Set_Cart_Salt (Lb : Natural);           --  (scripted starts and checks: what is left in it)
   --  For a tool that founds one colony after another in the same world (colony_run --square-scan):
   --  the cart's bed taken off the ground it stands on, before the colony is given up (Reset leaves
   --  the world as it is: the bed of the last colony's cart stood on in the next one's path, eight
   --  metres from where the last was founded, and that stretch of path was never laid).
   procedure Take_Cart_Away;
   function Deer_Salted return Natural;              --  deer butchered with salt for all their meat, all told
   function Deer_Unsalted return Natural;            --  and with less than that
   function Meat_Lost return Natural;                --  pounds of meat not kept for want of salt, all told
   function Hit_Chance (Metres : Float) return Float;

   procedure Set_Spare_Deer (On : Boolean);   --  a protection: deer are not hunted (default off)
   function Spare_Deer return Boolean;

   type Carcass_View is record
      Centre : Vec3;          --  where it lies (or the carrier's feet)
      Turn   : Float;         --  the way its spine lies
      Class  : Castle.Deer.Class;
      Lying  : Boolean;       --  False: carried
      Holder : Natural;       --  carrying it, or 0
   end record;
   function Carcass_Count return Natural;           --  K in 1 .. Carcass_Count
   --  (a measure, not saved: how often a whole deer was laid down unbutchered, by why, and how many
   --  of those times on a stockpile's ground.  John, 2026-11-23: "a hunter placed the deer in the
   --  stockpile without quatering it, I have only seen it happen once, and I don't know what caused
   --  it".  No_Hunter_Now: its carrier was given another job; No_Room_For_It, No_Way_Home: nowhere
   --  to butcher it, or no way there, and its carrier hungry or night come; Its_Carrier_Died.)
   type Carcass_Drop is (No_Hunter_Now, No_Room_For_It, No_Way_Home, Its_Carrier_Died);
   function Carcasses_Dropped (Why : Carcass_Drop; In_A_Stockpile : Boolean := False) return Natural;
   --  **A deer is butchered by whoever carries it home.**  A hunter given
   --  another job with a deer on its shoulders put it down where it stood,
   --  whole, for any hunter to fetch: in the stockpile if that is where it
   --  stood, and for good if the band had no other hunter.  It brings the
   --  deer home and butchers it first now, then takes up its new job; only
   --  with nowhere to butcher it does it put it down, as before.
   --  Set_Kill_Home (False), --no-kill-home: put down at once, as before.
   --  Not saved.
   procedure Set_Kill_Home (On : Boolean);
   function Kill_Home return Boolean;
   function Carcass_Used (K : Positive) return Boolean;
   function Carcass_At (K : Positive) return Carcass_View;
   function Kills return Natural;                    --  deer brought down
   function Shots return Natural;                    --  arrows loosed

   type Arrow_View is record
      From, To : Vec3;        --  the bow and where it ends (a deer, or the ground past it)
      Flight   : Float;       --  0 .. 1 along the way; 1: it has landed
      Stuck    : Boolean;     --  missed: it lies in the ground at To
   end record;
   function Arrow_Count return Natural;
   function Arrow_At (K : Positive) return Arrow_View;

end Castle.Colony;
