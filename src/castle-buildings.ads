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
   Wood_Per_Block : constant := 0.1;    --  (the preview's count) wood units per plank, shingle or log block

   type Wall_Side is (Front, Back, Left, Right);   --  left = the u = 0 wall

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
   type Front_Runs is array (-(Apron_B + Max_Reach_B) .. Max_Width_B - 1 + Apron_B + Max_Reach_B) of Natural;

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
   end record;

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

   type Stage is (Site, Floor, Trim, Walls, Gables, Roof, Dress, Extras);   --  (in the order they are built in)

   generic
      with procedure Put (Bx, By, Bz : Integer; M : Material; S : Stage; State : Natural);
   procedure Blueprint (H : House);
   --  Every block of the house in build order.  The floor (Floor): the
   --  threshold under its door and the earth inside the walls beaten hard,
   --  row by row.  The frame (Trim), in
   --  log: a post at every corner and every Stud_B along each wall, each
   --  raised whole, the door's jambs among them; a sill under each window
   --  and a lintel over the door; a beam along the top of every wall (the
   --  tie beam under each gable end).  The walls (Walls): wattle and daub
   --  between the timbers, a course at a time walked round the house
   --  (front, right, back, left); air marks door and windows.  The gables
   --  (Gables), in daub, one end and then the other.  The roof (Roof), in
   --  thatch, strip by strip from one eave over the ridge to the other.
   --  All its timber comes before any of its daub or thatch.  Last (Dress)
   --  the roof is trimmed, strip by strip the same way: the top block of
   --  thatch of each of its columns again, now with the state that says it
   --  is dressed and how it lies (Castle.Blocks.Dressed): the same block at
   --  the same place, so nothing is carried for it.  State is 0 for every
   --  block but those.

end Castle.Buildings;
