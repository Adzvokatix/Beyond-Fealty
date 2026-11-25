with Castle.Blocks; use Castle.Blocks;
with Castle.Hash;

--  Building generator, tier 1: the hovel (docs/design/
--  preliminary_PROCEEDURAL_GENERATION.txt for its size and its place; for
--  how it is made, John's references of 2026-11-12, the peasant house of
--  the twelfth century: a timber frame filled with wattle and daub, a
--  steep roof of thatch, a floor of beaten earth, windows small or none).
--  A house is only built attached to a pathway: front wall half a metre to
--  a metre off its edge, door toward it, a short door path joining it.
--  Houses vary in size around the minimum floor area per resident and vary
--  doors and windows within simple rules.  Every number here is a tuning
--  parameter.
--
--  A blueprint is a pure function of where the house fronts its path and of
--  its seed (and, later, of who lives in it and how far it has been
--  improved): Design gives the house its size and its openings from the
--  seed alone, whoever places it gives it its place, and Blueprint is every
--  block of it in the order it is built.  The colony (Castle.Colony) places
--  houses on the ground its housing zones fill; Castle.Buildings.Layout is
--  the older layout on the generated fields, kept for village_preview.
package Castle.Buildings is

   Min_Floor_B    : constant := 400;    --  25 m^2 of floor per resident, in blocks
   Min_Width_B    : constant := 21;     --  exterior frontage 5.25 .. 6.5 m
   Max_Width_B    : constant := 26;
   Max_Depth_B    : constant := 24;     --  front wall to back wall, at most (6 m: it stands in a lot 7 m deep)
   Depth_Var_B    : constant := 2;      --  up to 0.5 m deeper than the minimum
   Wall_H_B       : constant := 10;     --  2.5 m walls, or a block less
   Door_W_B       : constant := 4;      --  1 m
   Door_H_B       : constant := 8;      --  2 m
   Window_B       : constant := 2;      --  the window beside the door: small (half a metre square),
   Window_Up_B    : constant := 5;      --  and high (1.25 m off the floor), to keep the heat in
   Stud_B         : constant := 4;      --  a post of the frame about every metre of wall, between the corners'
   Setback_Min_B  : constant := 2;      --  front wall 0.5 .. 1 m off the pathway edge
   Setback_Max_B  : constant := 4;
   Max_Push_B     : constant := 20;     --  slide up to 3 m further on a slanting pathway
   Shared_Rate    : constant := 0.35;   --  (the preview's layout) chance that the next house shares a side wall
   Woodpile_Rate  : constant := 0.30;   --  (the preview's layout)
   Max_Step_B     : constant := 8;      --  lots falling more than 2 m are refused
   Apron_B        : constant := 2;      --  its ground reaches two blocks past its walls behind and to either side
                                        --  (as far as its lot is): one of open ground at its floor's level, and one
                                        --  that is a wall of stone where the land beside it stands over or under.
                                        --  No wider: a yard a serf could stand in between a house and a wall over
                                        --  its head would be a pit with no way out (the walking map lets a serf
                                        --  drop a metre and climb half of one), and a builder starved in one.
                                        --  Before its front wall its ground reaches to its path,
   Apron_Front_B  : constant := 2;      --  half a metre at the least
   Door_Landing_B : constant := 3;      --  the ground before a door is level with the floor this far out: a serf
                                        --  stepping down to it from half a metre up would not clear the eave
                                        --  over the first block, nor the lintel (the walking map's cells are
                                        --  two blocks, so three keep the step clear of both whichever way the
                                        --  cells fall)
   Lot_B          : constant := 28;     --  the lot kept for a house: 7 m along the path and 7 m back
   Max_Long_B     : constant := 40;     --  what a house's Front is made for: a hovel's longest wall, and a
                                        --  storehouse's 10 m (one of 12 m fits it with its yard's reach to
                                        --  either side, on a stockyard of 20 to 25 m: asked when it is placed)
   Wood_Per_Block : constant := 0.1;    --  (the preview's count) wood units per plank, shingle or log block

   type Wall_Side is (Front, Back, Left, Right);   --  left = the u = 0 wall

   --  What a building is.  The storehouse (John, 2026-11-17: "the builders
   --  will build a stockhouse, compact the land of the stockpile, build a
   --  fence with a gate, build coverings for outside materials, etc...
   --  Stockhouse gets a wood floor ... make the stockhouse some reasonable
   --  size, 5x10m same as the houses, but door is on the end of the
   --  warehouse, path to the door ... the coverings will be along the edges
   --  of the stockpile next to the fences, the backside. So think of a
   --  thatch roof with four posts with a larger opening at the front"): a
   --  hovel's frame, walls and thatch, a floor of plank; and its yard.
   --  Since 2026-11-18 it stands on a stockyard, a zone of its own (John,
   --  2026-11-17: "Keep stockpile, move storehouse to a new stockyard zone.
   --  Storehouse to be built with doors at each end of the building, the
   --  fence is to be placed around the stockyard with the gates extending
   --  from the storehouse, inline with the inside wall of the storehouse to
   --  the stockyard"): its length (Store_W_B) along its path with the
   --  staging before it, a door in each end, the yard behind it fenced, and
   --  a gateway beside each end in the line of its inside (back) wall, from
   --  its corner out; coverings along the back fence.  (Until then: its
   --  end, with its one door, toward the path, on a stockpile's lot.)
   type Building_Kind is (Hovel, Storehouse);
   Store_W_B      : constant := 40;     --  10 m along its front, the side toward the path
   Store_D_B      : constant := 20;     --  5 m back
   --  (those two, with Store_Yard_B before it, are the storehouse of before 2026-11-21 and of every
   --  older save.  John, 2026-11-21: "bring the storehouse forward 3m towards the path so that the
   --  fenced area becomes 3m deeper, add 2m to the width of the storehouse, so that it is now 8x12":
   --  the storehouse the colony begins from then on, unless it is told another size
   --  (Castle.Colony.Set_Store_Size).  One begun keeps what it was begun with.)
   Store_W_New_B    : constant := 48;   --  12 m along its front
   Store_D_New_B    : constant := 32;   --  8 m back
   Store_Yard_New_B : constant := 6;    --  1.5 m of the stockyard's ground before its front wall: 3 m nearer
   Store_Door_W_B : constant := 8;      --  2 m: a door in each end
   Store_Gate_W_B : constant := 8;      --  2 m: a gateway beside each end, from its corner out (all the gap
                                        --  to the side fence, where that is less)
   Store_Yard_B   : constant := 18;     --  the stockyard's ground before its front wall (with the ground drawn
                                        --  out to the path, 5 m of staging)
   Fence_H_B      : constant := 4;      --  a fence a metre high: a post every Fence_Post_B, rails between
   Fence_Post_B   : constant := 8;      --  at the second and the fourth block
   Gate_Post_H_B  : constant := 9;      --  the gateway: two posts and a plank across their tops, head room under it
   Cover_W_B      : constant := 12;     --  a covering: 3 m along the back fence,
   Cover_D_B      : constant := 8;      --  2 m deep, just inside it,
   Cover_Front_H_B : constant := 10;    --  its roof's front edge 2.5 m up
   Cover_Back_H_B : constant := 8;      --  and its back 2 m: the opening larger at the front
   Max_Covers     : constant := 8;
   type Cover_List is array (1 .. Max_Covers) of Integer;

   type Opening is record
      Side   : Wall_Side := Front;
      Offset : Integer   := 0;   --  along the wall (blocks)
      Width  : Integer   := 2;
      Bottom : Integer   := 0;   --  above the floor
      Height : Integer   := 2;
   end record;
   type Opening_List is array (1 .. 5) of Opening;

   Max_Reach_B : constant := 32;    --  a house's ground reaches at most this far past its own yard to either side,
                                    --  to meet the ground of the house beside it (a gap no lot would fit in)
   type Front_Runs is array (-(Apron_B + Max_Reach_B) .. Max_Long_B - 1 + Apron_B + Max_Reach_B) of Natural;

   type House is record
      Fx, Fy        : Integer := 0;     --  front-left corner (blocks)
      Ux, Uy        : Integer := 1;     --  along the front wall
      Vx, Vy        : Integer := 0;     --  from the front wall into the house
      W, D          : Integer := 22;    --  exterior size along U and V (blocks)
      Wall_H        : Integer := Wall_H_B;
      Pad           : Integer := 0;     --  ground blocks 0 .. Pad - 1 after levelling
      Door_Run      : Natural := 0;     --  block columns from its front wall straight out from its door to the
      Front         : Front_Runs := [others => 0];
                                        --  its front yard: at each place along its front (and the yard's to
                                        --  either side), the block columns of ground between its front wall's
                                        --  line and the edge of its path (the colony's to say)
      Door_Row      : Integer := 0;     --  path's ground, and the row of the ground where that way meets the
                                        --  path: past a landing (Door_Landing_B) the way is cut or built up
                                        --  as a stair between the pad and that (0 columns: no stair, as the
                                        --  preview has it)
      Reach_L       : Natural := 0;     --  its ground reaches this many block columns further to its left and
      Reach_R       : Natural := 0;     --  to its right than its own yard: as far as the ground of the house
                                        --  begun before it beside it, so that the two are one terrace and the
                                        --  walls behind them one wall (the colony's to say)
      Ridge_Along_U : Boolean := True;
      Shared_Left   : Boolean := False;
      Shared_Right  : Boolean := False;
      Openings      : Opening_List;     --  the door is Openings (1)
      Open_N        : Natural := 0;
      Woodpile      : Natural := 0;     --  0 none, 1 left side, 2 right side
      Dist          : Float   := 0.0;   --  walking distance from the stake (m)
      Cut, Fill     : Natural := 0;     --  blocks of earth moved
      Kind          : Building_Kind := Hovel;
      Floor         : Material := Footpath;   --  what its floor is laid in (beaten earth; a storehouse's plank)
      Yard_U0, Yard_U1, Yard_V0, Yard_V1 : Integer := 0;
                                        --  a storehouse's yard in its frame (blocks, inclusive): the stockyard's
                                        --  lot, from its front (V0, before the staging) to its back, the fence
                                        --  round what of it lies behind the storehouse (the colony's to say)
      Gate_U        : Integer := 0;     --  (not used since the gateways went beside its ends: kept in the blob)
      Covers        : Natural := 0;     --  coverings along the back fence,
      Cover_U       : Cover_List := [others => 0];   --  each one's first column
      --  (2026-11-20; the colony says them when it begins a storehouse, and keeps them)
      Smooth_Covers : Boolean := False; --  its coverings' roofs are smoothed after they are laid (Smooth)
      Fence_Pieces  : Boolean := False; --  drawn turned (Yard_Turned): its rails and the planks over its
                                        --  gateways are laid as pieces (Castle.Blocks.Piece), drawn straight
      --  How it is made (John's notes of 2026-11-17; each false: as every house was until
      --  2026-11-19; the colony says them when it begins a house, and keeps them with it):
      Truss         : Boolean := False; --  its roof has timbers: a truss in each gable end (a king post, and a
                                        --  rafter under each slope), tie beams across from eave wall to eave
                                        --  wall about every Tie_B; a storehouse a truss over each tie beam
                                        --  too, and a ridge beam from gable to gable
      Sill          : Boolean := False; --  a window's sill runs from the post on its one side to the post on
                                        --  its other, a lintel over it the same, and the wall to either side
                                        --  of the opening between them is of plank
      --  (his answers of 2026-11-19; the colony says them when it begins a house, and keeps them)
      Jambs         : Boolean := True;  --  with Sill: the block to either side of a window is of plank, as in
                                        --  the houses begun on 2026-11-19; false: daub, as the wall is (a thin
                                        --  trim is drawn round every window instead: "Thin trim around the
                                        --  tops and side(s)")
      Ridge         : Boolean := False; --  with Truss: a hovel has a ridge beam too, from gable to gable
                                        --  ("eh, go ahead and add a ridge beam to the hovels")
      --  (his notes of 2026-11-23; the colony says it when it begins a house, and keeps it)
      Full          : Boolean := False; --  with Truss: a gable's truss runs to the ends of its wall (the line
                                        --  of each rafter goes on down through the wall's top corner to its
                                        --  corner post: three blocks of timber where there was daub), and
                                        --  where the span is an even number of blocks there are two king
                                        --  posts side by side, and two ridge beams, so that the truss is the
                                        --  same on either side of its middle ("can we extend the truss to the
                                        --  end of the wall? make it symmetrical, either add another support
                                        --  if the length is even?")
      Turn          : Integer range -1 .. 1 := 0;
                                        --  it is drawn turned an eighth of a turn about the middle of its doorway
                                        --  (1: to the left as seen from above, -1: to the right), its front
                                        --  along a path that runs at 45 degrees; where it stands on the grid,
                                        --  and all the colony knows of it, is as ever (the colony's to say)
      Turn_Ground   : Boolean := False; --  with Turn: its ground is made where it is drawn too (the colony's
                                        --  to say and to make), and its floor is laid under it as drawn
      Walk          : Boolean := False; --  a hovel's, with Turn_Ground: once its walls and roof are up the feet
                                        --  go by it as it is drawn (the colony's to say, and the walking
                                        --  map's to do: Castle.Nav.Set_Drawn), so whoever is in it is where
                                        --  it is seen.  (A storehouse drawn turned is always walked so.)
      Piv_U, Piv_V  : Float := 0.0;     --  a storehouse's, with Turn: what it is turned about, in its frame
                                        --  (near its middle: the colony's to say, so that its yard as it is
                                        --  laid out lies on its stockyard's places)
      Way_End       : Natural range 0 .. 2 := 0;
                                        --  a storehouse's: where its stockyard's way in from its path is.  0: at
                                        --  the middle of its front, across the staging, as every stockyard's
                                        --  was until 2026-11-21; 1, 2: at the end of the stockyard's front where
                                        --  its design's U counts least, or most, in a corner of the zone (the
                                        --  colony's to say when it begins the storehouse, and kept with it)
   end record;

   --  **A storehouse drawn turned (Yard_Turned) has its yard laid out for
   --  real along its path** (John, 2026-11-20, of three ways put to him: "go
   --  on with the second way for the stockyard").  The storehouse's own
   --  blocks stand square to the grid in its frame, as a turned hovel's do,
   --  and are drawn turned about (Piv_U, Piv_V).  Everything else of it is
   --  **designed** in its frame as a square stockyard's is (Yard_U0 .. the
   --  gateways, the coverings, its places) and **made where the turn puts
   --  it**: the place (U, V) of the design is made at Fore_Turn (U, V) of
   --  its frame, block by block on the grid, so its fence and its coverings
   --  are stepped.  Design_Of: the place of the design that block column
   --  (U, V) of its frame is made as (each column is of one; a place of the
   --  design has one column, two or none).  Of any other house: (U, V).
   --  (The end of each gateway's plank under the storehouse's eave is laid
   --  where it is in the frame, one of the storehouse's own blocks: drawn
   --  turned with it, it meets the rest of the plank at its corner as drawn.)
   function Yard_Turned (H : House) return Boolean is (H.Kind = Storehouse and then H.Turn /= 0);
   procedure Design_Of (H : House; U, V : Integer; Du, Dv : out Integer);
   function Pivot_U (H : House) return Float;
   function Pivot_V (H : House) return Float;

   --  A house drawn turned (Turn): the turn is about the middle of its first
   --  opening (its door) in the line of its front wall's middle (a
   --  storehouse's: about (Piv_U, Piv_V), its doors being in its ends).  U and V
   --  are places of its frame in blocks (0, 0 the middle of its front left
   --  corner block), fractions allowed.
   procedure Back_Turn (H : House; U, V : Float; Qu, Qv : out Float);
   --  The place of the house as it stands that is drawn at (U, V).
   procedure Fore_Turn (H : House; U, V : Float; Qu, Qv : out Float);
   --  Where the place (U, V) of the house as it stands is drawn.
   function Under_Drawn (H : House; U, V : Float; Margin : Float := 0.0) return Boolean;
   --  (U, V) lies under the house as drawn, or within Margin blocks of its
   --  walls' outer faces (one not turned: under it as it stands).
   type Frame_Box is record
      U0, U1, V0, V1 : Integer := 0;
   end record;
   function Drawn_Box (H : House; Margin : Float := 0.0) return Frame_Box;
   --  The block columns of its frame that the house as drawn, and Margin
   --  blocks round it, lies within.
   Tie_B : constant := 8;               --  a tie beam about every two metres of a house's length

   function Min_Depth (W : Integer) return Integer;
   --  The least depth (exterior, blocks) that gives Min_Floor_B of floor
   --  inside walls a block thick, for a house W wide.

   function Design (Seed : Castle.Hash.U64; Level : Natural := 0) return House;
   --  The house of that seed: its size, its walls' height, the way its
   --  ridge runs, its door and its windows.  Where it stands (Fx, Fy, the
   --  two axes) and the level of its pad are left as they are by default,
   --  for whoever places it.  The door is in the front wall, in the middle
   --  or toward a corner; beside it, on the wider side, a small window
   --  (Window_B square, Window_Up_B off the floor, clear of the door's frame
   --  and of the end wall); now and then another in another wall.  Level:
   --  how far it has been improved (0: the hovel; nothing more yet).

   function Storehouse_Design (W : Positive := Store_W_B; D : Positive := Store_D_B) return House;
   --  The storehouse: W by D (Store_W_B by Store_D_B unless given), walls Wall_H_B high, its ridge
   --  along its length (gables at its ends), a door Store_Door_W_B wide in
   --  the middle of each end, no windows, a floor of plank.  Where it
   --  stands and its yard are the colony's to say.

   function Yard_Clashes (H : House) return Natural;
   --  Of a storehouse drawn turned: the blocks of its fence, its gateways
   --  and its coverings that would stand among its own blocks as they stand
   --  (they are left out of its blueprint: drawn turned with it, they would
   --  be seen somewhere else).  A stockyard is laid out so that there are none.
   function Covering_At (H : House; U, V : Integer) return Natural;
   --  The covering of a storehouse's yard whose ground (U, V) is (0: none).

   type Stage is (Site, Floor, Trim, Walls, Gables, Roof, Dress, Extras, Beaten, Fence, Cover, Smooth);
   --  (in the order they are built in; the last four are a storehouse's
   --  yard, laid on the ground as it lies: their rows count from the row
   --  over the ground's top, a covering's from the highest under it)

   generic
      with procedure Put (Bx, By, Bz : Integer; M : Material; S : Stage; State : Natural);
   procedure Blueprint (H : House);
   --  Every block of the house in build order.  The floor (Floor): the
   --  threshold under its door and the earth inside the walls beaten hard,
   --  row by row (with Turn_Ground: the earth under it as it is drawn, to
   --  the middle of its walls as drawn, row by row of its frame; the blocks
   --  of it may lie outside its walls as they stand).  The frame (Trim), in
   --  log: a post at every corner and every Stud_B along each wall, each
   --  raised whole, the door's jambs among them; a sill under each window
   --  and a lintel over the door; a beam along the top of every wall (the
   --  tie beam under each gable end); with Sill a window's sill and lintel
   --  from post to post and its jambs of plank, with Truss the roof's
   --  timbers (the gables' trusses, the tie beams, a storehouse's trusses
   --  and ridge beam).  The walls (Walls): wattle and daub
   --  between the timbers, a course at a time walked round the house
   --  (front, right, back, left); air marks door and windows.  The gables
   --  (Gables), in daub, one end and then the other.  The roof (Roof), in
   --  thatch, strip by strip from one eave over the ridge to the other.
   --  All its timber comes before any of its daub or thatch.  Last (Dress)
   --  the roof is trimmed, strip by strip the same way: the top block of
   --  thatch of each of its columns again, now with the state that says it
   --  is dressed and how it lies (Castle.Blocks.Dressed): the same block at
   --  the same place, so nothing is carried for it.  State is 0 for every
   --  block but those.  A storehouse's floor is of plank, and after its
   --  roof comes its yard: the ground beaten (Beaten: its top block, at the
   --  row under the floor), the fence (Fence) and the coverings (Cover),
   --  each block's row given as if the ground lay at the pad's level: the
   --  colony lays it that far over the ground's top where it goes.  With
   --  Fence_Pieces (one drawn turned), its rails and the planks over its
   --  gateways are laid with the state Castle.Blocks.Piece.  With
   --  Smooth_Covers, last (Smooth) each covering's roof is smoothed: its
   --  thatch again, a row at a time from its front to its back, with the
   --  state Piece (the same block at the same place: nothing is carried for
   --  it; "the builders smooth the roofs", John, 2026-11-12).

end Castle.Buildings;
