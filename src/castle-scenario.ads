with Castle.Colony;
with Castle.Hash;
with Castle.Bodies;

--  A colony set up from the command line, and the log lines that report
--  it: shared by the game and the windowless runner (tools/colony_run), so
--  a scripted start is the same colony in both.
--
--    --stake X Y            the homestake (everything below needs it)
--    --band N               how many arrive (Castle.Colony.Arrivals: 13; 6 until 2026-11-17)
--    --path X0 Y0 X1 Y1     a footpath (up to 16), planned: the band lays it
--    --paths-built          those paths laid on the spot
--    --stone-from M         for measuring: the camp's builders take no stone from nearer the stake
--                           than M metres, as if the nearest lay that far off
--    --stockpile X0 Y0 X1 Y1   a stockpile (up to 8)
--    --housing X0 Y0 X1 Y1  housing (up to 8): begun beside a path at X0 Y0, on that side of it, and
--                           pulled along the path as far as X1 Y1; combined with housing it meets.
--                           The band builds a hovel there for each of its people, its foresters
--                           turning builder
--    --homes-built          a hovel for everyone those zones have room for, built on the spot
--    --camp X Y             the camp, its fire there (marked: the band builds it)
--    --camp-built           that camp built on the spot (--stoke H builds it too, and lights its fire)
--    --gatherers N --foresters N --porters N --hunters N --cooks N
--                           the first N members, then the next N, in that order
--    --job I JOB            member I's job (gatherer, forester, porter, hunter, cook, none), after
--                           the counts above
--    --supply KIND N        N of it in the stockpiles at the start
--    --reserve wood|straw|meat|vegetables N   a surplus to keep (--wood-reserve N is the first)
--    --winter-store DAYS    days of food to keep for winter
--    --no-demand            the colony as before the demand chain: gatherers never stop, hunters
--                           go by the meat reserve alone, wood has no limit unless a reserve is
--                           given (a colony loaded from a save keeps the switch it was saved with)
--    --no-needs             nobody eats or sleeps (Castle.Colony.Set_Needs: the stress test's
--                           band of forty-eight, which the land cannot feed, kept at work)
--    --spare-deer  --fell-apples
--    --no-skills            everyone works at the one pace, as before there were skills (a colony
--                           loaded from a save keeps the switch it was saved with)
--    --no-labour            the colony as it was before what the player marks took the band's
--                           labour: the camp stands and a path is laid the moment it is marked,
--                           and the fire feeds itself from its stack, a log every four hours (a
--                           colony loaded from a save keeps the switch it was saved with;
--                           --instant-camp, its first name, is still taken)
--    --extra-hands N        at most N at extra tasks (the camp's building, the paths' laying) at
--                           once, instead of one in three of the band
--    --all-hands            extra tasks as they were before they were limited: everyone turns to
--                           them before its job, and a path is laid a metre at a time by whoever
--                           is nearest, not a stretch to a serf
--    --no-level             the camp's floor left as it lies, as before the band levelled it
--    --no-beds              nobody makes itself a bed of straw, as before they did
--    --no-cook-hold         the cook keeps nothing in the stores for the pot, as before it did:
--                           whoever is hungry with no stew eats raw whatever is stored
--    --no-curing            the band as it was before the lord's cart: no cart, no salt, and meat
--                           counted in joints (a doe 8, thirty points each in the pot)
--    --cart-salt LB         the salt in the lord's cart at the start (0: a band whose salt has
--                           run out)
--    --no-ladders           every roof thatched from the ground, its builder walking round the
--                           house from bout to bout, as before they made ladders
--    --no-path-holes        a path laid down into a hole in the ground, as it was, not over it
--                           with the hole filled
--    --no-cart-pull         the lord's cart left where it stood by the stake, as it was, not
--                           pulled into the nearest stockpile
--    --builders N           at most N builders at once (0: no limit, as before 2026-11-17; the
--                           colony's own is Castle.Colony.Most_Builders, 4)
--    --stockpile-least M    a stockpile's ground at least M metres along its path and across (0: any
--                           size, as before 2026-11-17; the colony's own is Stockpile_Least_M, 15)
--    --no-overflow          a stockpile with no overflow places round it, and a gatherer picking with
--                           nowhere to put what it picks, as before 2026-11-17 (as it is again since
--                           2026-11-18: kept for the scripts that say it)
--    --overflow             a stockpile zoned gets the first pass's five overflow places round it
--    --last-places N        the stores' last N empty places kept for loads in hand: nobody sets out for
--                           what would need one (0: none kept, as before 2026-11-18; the colony's own is
--                           Castle.Colony.Last_Places, 10)
--    --no-storehouse        no storehouse asked for on the second morning, as before 2026-11-17
--    --no-stockman          nobody made the storehouse's stockman (its places fitted out fill with water alone)
--    --no-carpenter         nobody made its carpenter: no shelf or barrel is made
--    --no-water             no water brought to its water barrels
--    --square X Y WAY       the colony founded on a square (the homestake and the campfire one: 10 m of
--                           floor, a path round it, the fire in its middle), its middle at X Y, turned WAY
--                           (even: squarely; odd: aslant); in place of --stake and --camp
--    --no-square            the homestake the player raises is the post, the camp zoned apart, as before
--                           2026-11-20 (--stake is that whatever this says)
--    --yard-stair-middle    a stockyard's stair at the middle of its storehouse's front, as before the evening of
--                           2026-11-21 (now in a corner of the zone: Castle.Colony.Set_Yard_Stair_Corner)
--    --no-corner-whole      the square metre where two sides' paths cross laid a quarter metre of each side's at a
--                           time, by whichever side's metre comes first, as before 2026-11-22, later (now all of
--                           it at once, level whole or left whole: Castle.Colony.Set_Corner_Whole)
--    --no-corner-steps      no step of stone in the square metre where two sides' paths cross, as before
--                           2026-11-22, later (now a landing of a flight that goes on along the other side:
--                           Castle.Colony.Set_Corner_Steps)
--    --no-strip-wait        a column of two sides' strips, beyond a corner of a square's floor, walled by whichever
--                           side's path is laid first, as before 2026-11-22, later (now it waits for both:
--                           Castle.Colony.Set_Strip_Wait)
--    --no-line-ground       a planned line's end under a tree at the height of the bough over it, as before
--                           2026-11-22, later (now at the ground's under it: Castle.Colony.Set_Line_Ground)
--    --no-path-steps        the square's path as it lies where a levelled stretch of it ends, half a metre and
--                           more at once, as before 2026-11-22 (now steps of stone there, a block a quarter
--                           metre: Castle.Colony.Set_Path_Steps)
--    --yard-floor-by-land   a stockyard's floor chosen from the land under it and held to the steps that fit
--                           before its storehouse, as before 2026-11-22 (now at its path's level at the lower
--                           corner of its front, the stair at the higher: Castle.Colony.Set_Yard_Floor_Low)
--    --square-stair-corner  a square's stair at an end of its side, in a corner of the zone
--                           (Castle.Colony.Set_Square_Stair_Corner; built 2026-11-21 on a misreading of his
--                           words, which were of the stockyard's stair, and kept off behind this)
--    --square-stair-middle  a square's stair at the middle of its side: as it is anyway (he was given this word
--                           while the corner was the rule, and it is kept)
--    --no-fire-ground       a square's stake looked for near the highest floor at its middle, as before
--                           2026-11-21 (under a tree: put on a bough, or refused after its plan said yes)
--    --stockpile-box X Y WAY  a stockpile put down whole with its path, as the player's tool puts it: held by
--                           its middle at X Y (metres) and turned WAY (0 .. 7: its path runs east, north-east,
--                           north ... and it lies on the left of that); drawn to a path near it
--                           (Castle.Colony.Box_At)
--    --no-box-place         the player's stockpile zoned corner to corner, as before 2026-11-20
--    --stockyard-box X Y WAY  the stockyard put down whole with its path, twenty metres square, as the
--                           player's tool puts it: held by its middle and turned as a stockpile's box is
--    --no-yard-box          the player's stockyard zoned corner to corner (15 to 25 m), as before 2026-11-21
--    --no-store-stacks      food on the storehouse's floor one place high and one barrel to a barrel's
--                           place, as before 2026-11-21 (Castle.Colony.Set_Store_Stacks)
--    --one-cart-place       the lord's cart brought to the one place before the storehouse it always had, or
--                           not at all (as before 2026-11-21: across the staging by the way in)
--    --storehouse L D S     the storehouse begun from now on: L m along its front, D m back, S m of the
--                           stockyard's ground before its front wall (12 8 1.5 unless said; 10 5 4.5 is the
--                           storehouse of before 2026-11-21; 12 5 1.5 and 10 7 1.5 the other readings of his
--                           "8x12"); beside a path at 45 degrees S is 3.5 at the least
--    --stockyard X0 Y0 X1 Y1  a stockyard zoned corner to corner (metres), beside a path: the storehouse's
--    --no-yard-level        the stockyard's ground beaten as it lies, the storehouse's own pad alone made
--                           level (as before 2026-11-18)
--    --set-builders N       the first N of the foresters are set to building (Castle.Colony.Set_Builder: they
--                           take a house before the others, whatever their skill)
--    --no-roof-timbers      a house is begun without its roof's timbers (as before 2026-11-19)
--    --no-window-timber     and with a window's sill a block wider than it, no lintel, no plank (the same)
--    --no-path-level        a path is laid on the ground as it lies, only closed hollows filled (as before
--                           2026-11-19)
--    --no-make-way          one standing where a builder's next block goes is waited for, not stepped aside
--    --no-reach-out         a builder stands on the square metre of ground it makes ready, as before 2026-11-23
--    --no-zigzag            a storehouse's ground worked every row from the same end, as before 2026-11-23
--    --no-paths-meet        a path left half a metre off the trodden ground it meets, as before 2026-11-23
--    --no-door-meet         a door's way left as it was planned when its hovel was placed, as before 2026-11-23
--    --no-kill-home         one given another job puts down the deer it carries at once, as before 2026-11-23
--    --no-full-truss        a gable's truss three blocks short of its wall's ends, one king post, as before 2026-11-23
--    --no-build-help        one builder a house, as before 2026-11-23
--    --no-place-level       a stockpile's place left as its ground lies under what is put on it, as before 2026-11-23
--    --no-cart-room         things put on the places beside the cart's wheels and under its shafts, as before 2026-11-23
--    --no-step-at-edge      a walker keeps the height it came from for the first eighth of a metre of a step, as before 2026-11-23
--    --pile-flat            a stockpile made one level where it is put down (built 2026-11-23 and set aside the same day: "let's go back to the stepped version")
--    --no-steep-refuse      a stockpile is put down however steep its ground (as until 2026-11-23)
--                           (as before 2026-11-19)
--    --stockpile-stays      the stockpile goes on in use when the storehouse stands (it is closed and
--                           emptied into the stockyard otherwise)
--    --one-to-a-bush        a bush is one gatherer's while it picks there, as before 2026-11-18 (now as
--                           many pick at a bush as it has basketfuls of ripe berries)
--    --no-top-cut           a porter cuts the block of long grass it found, not the top of its tuft,
--                           as before 2026-11-18 (the lower block of a tuft two high cut, the upper
--                           left in the air)
--    --deer-scatter         the herds as they were before they fled together: each deer bolting on
--                           a heading of its own and trotting back, wading wherever a serf can (a
--                           colony loaded from a save keeps the switch it was saved with)
--    --herds-anywhere       a herd put down on the highest floor at the place drawn for it, a tree's
--                           top or a boulder's among them, as before 2026-11-22 (now only where a
--                           deer can walk off: Castle.Herds.Set_Walk_Off)
--    --by-skill             the jobs above go to whoever is best at each (gatherers first, and so
--                           on in that order), not to the first N members
--    --name-stockman I      member I named the storehouse's stockman by hand: a porter, and its
--    --name-carpenter I     stockman when it stands (the carpenter: a forester), whatever their skill;
--                           what the development entries of a person's menu do (Castle.Colony.Name_Stockman)
--    --skills-at LEVEL      everyone arrives at LEVEL (0 .. 1) in every working skill: a band of
--                           novices, or of masters, to measure what skill is worth
package Castle.Scenario is

   type Rects is array (Positive range <>, Positive range <>) of Float;
   type Job_Flags is array (1 .. Castle.Colony.Max_Members) of Boolean;
   type Job_List is array (1 .. Castle.Colony.Max_Members) of Castle.Colony.Job_Kind;

   type Setup is record
      Stake            : Boolean := False;
      Stake_X, Stake_Y : Float := 0.0;
      As_Square        : Boolean := False;   --  --square X Y WAY: founded on a square, its middle there
      Square_Way       : Natural := 0;
      Band             : Positive := Castle.Colony.Arrivals;
      Paths            : Rects (1 .. 16, 1 .. 4) := [others => [others => 0.0]];
      Path_N           : Natural := 0;
      Piles            : Rects (1 .. 8, 1 .. 4) := [others => [others => 0.0]];
      Pile_N           : Natural := 0;
      Boxes            : Rects (1 .. 8, 1 .. 3) := [others => [others => 0.0]];   --  --stockpile-box X Y WAY
      Box_N            : Natural := 0;
      No_Box_Place     : Boolean := False;   --  --no-box-place: the player's stockpile zoned corner to corner
      Yard_Box         : Boolean := False;   --  --stockyard-box X Y WAY: the stockyard put down whole, as the
      Yard_Box_At      : Rects (1 .. 1, 1 .. 3) := [others => [others => 0.0]];   --  player's tool puts it
      No_Yard_Box      : Boolean := False;   --  --no-yard-box: the player's stockyard zoned corner to corner
      Housing          : Rects (1 .. 8, 1 .. 4) := [others => [others => 0.0]];
      Housing_N        : Natural := 0;
      Pulls            : Rects (1 .. 8, 1 .. 5) := [others => [others => 0.0]];   --  --housing-pull X0 Y0 X1 Y1 ROWS
      Pull_N           : Natural := 0;
      Inside           : Rects (1 .. 8, 1 .. 2) := [others => [others => 0.0]];   --  --housing-inside X Y
      Inside_N         : Natural := 0;
      Pace             : Float := 0.0;       --  --pace P (0: the colony's own, Castle.Colony.Serf_Pace)
      Homes_Built      : Boolean := False;   --  --homes-built: no waiting for the band to build them
      Camp             : Boolean := False;
      Camp_X, Camp_Y   : Float := 0.0;
      Stoke            : Float := 0.0;    --  --stoke H: the camp's fire burning from the start, H hours on it
      Camp_Built       : Boolean := False;   --  --camp-built: no waiting for the band to build it
      Paths_Built      : Boolean := False;   --  --paths-built: nor to lay the paths
      Stone_From       : Float := 0.0;       --  --stone-from M
      Extra_Hands      : Natural := 0;       --  --extra-hands N (0: the colony's rule)
      All_Hands        : Boolean := False;   --  --all-hands
      No_Level         : Boolean := False;   --  --no-level
      No_Beds          : Boolean := False;   --  --no-beds: the band as it was before it made itself beds of straw
      No_Cook_Hold     : Boolean := False;   --  --no-cook-hold: the stores as they were before the cook kept a pot's fill
      No_Curing        : Boolean := False;   --  --no-curing: no cart, no salt, meat in joints, as it was
      No_Ladders       : Boolean := False;   --  --no-ladders: roofs thatched from the ground, as they were
      No_Path_Holes    : Boolean := False;   --  --no-path-holes: paths laid down into holes, as they were
      No_Cart_Pull     : Boolean := False;   --  --no-cart-pull: the lord's cart left where it stood, as it was
      Cart_Salt        : Integer := -1;      --  --cart-salt LB: the salt in the lord's cart at the start (-1: the colony's own)
      Builders         : Integer := -1;      --  --builders N: at most N builders at once (0: no limit; -1: the colony's own)
      Stockpile_Least  : Float := -1.0;      --  --stockpile-least M: a stockpile at least M by M (0: any size; below: the colony's own)
      No_Overflow      : Boolean := False;   --  --no-overflow: no overflow places, and gatherers pick with nowhere to put it
      Overflow         : Boolean := False;   --  --overflow: the overflow places of the first pass (off since 2026-11-18)
      Last_Places      : Integer := -1;      --  --last-places N: the stores' last N empty places kept (0: none; -1: the colony's own)
      No_Storehouse    : Boolean := False;   --  --no-storehouse: no storehouse asked for on the second morning
      No_Stockman      : Boolean := False;   --  --no-stockman
      No_Carpenter     : Boolean := False;   --  --no-carpenter
      No_Water         : Boolean := False;   --  --no-water
      No_Top_Cut       : Boolean := False;   --  --no-top-cut: straw cut from the block found, as it was
      Yard             : Boolean := False;   --  --stockyard X0 Y0 X1 Y1: a stockyard zoned corner to corner
      Yard_At          : Rects (1 .. 1, 1 .. 4) := [others => [others => 0.0]];
      No_Yard_Level    : Boolean := False;   --  --no-yard-level: the stockyard beaten as it lies, not levelled
      Set_Builders     : Natural := 0;       --  --set-builders N: the first N foresters are set to building
      Name_Stockman    : Natural := 0;       --  --name-stockman I: member I named the stockman (a porter; 0: nobody)
      Name_Carpenter   : Natural := 0;       --  --name-carpenter I: member I named the carpenter (a forester)
      No_Roof_Timbers  : Boolean := False;   --  --no-roof-timbers: houses begun without trusses, tie beams, ridge beam
      No_Window_Timber : Boolean := False;   --  --no-window-timber: a window's sill a block wider than it, no more
      No_Path_Level    : Boolean := False;   --  --no-path-level: a path laid on the ground as it lies (hollows filled)
      Wood_From        : Float := 0.0;       --  --wood-from M: no tree felled nearer the stake (measuring)
      No_House_Turn    : Boolean := False;   --  --no-house-turn: a hovel beside a path at 45 degrees is not turned
      No_Turn_Ground   : Boolean := False;   --  --no-turn-ground: a turned hovel's ground is the square one it stands on
      No_Keep_Off      : Boolean := False;   --  --no-keep-off: nobody keeps off the ground a turned hovel is drawn on
      Turn_Fall        : Boolean := False;   --  --turn-fall: a turned hovel's ground may fall 2 m under its walls as drawn too
      No_Ways_Told     : Boolean := False;   --  --no-ways-told: each finds out for itself where there is no way
      No_Yard_Turn     : Boolean := False;   --  --no-yard-turn: a stockyard square to the grid beside any path
      No_Hovel_Walk    : Boolean := False;   --  --no-hovel-walk: a turned hovel walked as it stands, as before 2026-11-20
      No_Smooth_Covers : Boolean := False;   --  --no-smooth-covers: a storehouse's coverings' roofs left stepped
      No_Fence_Pieces  : Boolean := False;   --  --no-fence-pieces: a turned stockyard's rails laid stepped, drawn so
      One_Stockpile    : Boolean := False;   --  --one-stockpile: the player's stockpile 10 m square, placed once
      Stores_Move      : Boolean := False;   --  --stores-move: every stockpile closes when the storehouse stands
      No_Path_Snap     : Boolean := False;   --  --no-path-snap: a path along the line as it is given, at any angle
      No_Wood_Reach    : Boolean := False;   --  --no-wood-reach: a forester looks for a tree no further than the work radius
      No_Make_Way      : Boolean := False;   --  --no-make-way: a builder waits for whoever stands where its block goes
      No_Reach_Out     : Boolean := False;   --  --no-reach-out: a builder stands on the ground it makes ready
      No_Zigzag        : Boolean := False;   --  --no-zigzag: a storehouse's ground, every row from the same end
      No_Paths_Meet    : Boolean := False;   --  --no-paths-meet: a path not stepped where it meets trodden ground
      No_Door_Meet     : Boolean := False;   --  --no-door-meet: a door's way not made again to its path as it lies
      No_Kill_Home     : Boolean := False;   --  --no-kill-home: a deer put down when its carrier is given another job
      No_Full_Truss    : Boolean := False;   --  --no-full-truss: a house begun without the fuller truss
      No_Build_Help    : Boolean := False;   --  --no-build-help: one builder a house
      No_Place_Level   : Boolean := False;   --  --no-place-level: a stockpile's place not made level
      No_Cart_Room     : Boolean := False;   --  --no-cart-room: things put beside the cart's wheels and under its shafts
      No_Step_At_Edge  : Boolean := False;   --  --no-step-at-edge: a walker's height changed at the next point of its way
      Pile_Flat        : Boolean := False;   --  --pile-flat: a stockpile made one level
      No_Steep_Refuse  : Boolean := False;   --  --no-steep-refuse: a stockpile on ground however steep
      Stockpile_Stays  : Boolean := False;   --  --stockpile-stays: the stockpile goes on in use beside the stockyard
      One_To_A_Bush    : Boolean := False;   --  --one-to-a-bush: a bush is one gatherer's while it picks there, as it was
      Deer_Scatter     : Boolean := False;   --  --deer-scatter
      Herds_Anywhere   : Boolean := False;   --  --herds-anywhere: a herd put down wherever there is a floor, as it was
      Gatherers, Foresters, Porters, Hunters, Cooks : Natural := 0;
      Supply           : Castle.Colony.Per_Kind := [others => 0];
      Reserves         : Castle.Colony.Per_Kind := Castle.Colony.Default_Reserve;
      Wood_Reserve     : Natural := 0;
      Wood_Given       : Boolean := False;    --  else the colony's own (no limit, without the demand chain)
      Winter_Store     : Natural := 0;
      Spare_Deer       : Boolean := False;
      Fell_Apples      : Boolean := False;
      Skills           : Boolean := True;
      Demand           : Boolean := True;
      Needs            : Boolean := True;    --  --no-needs: nobody eats or sleeps (the stress test's long runs)
      Labour      : Boolean := True;
      By_Skill         : Boolean := False;
      Skills_At        : Float := -1.0;       --  below 0: as each arrives
      Job_Set          : Job_Flags := [others => False];   --  --job: these members' jobs, said one by one
      Job_Given        : Job_List := [others => Castle.Colony.Unassigned];
   end record;

   function Parse (S : in out Setup; I : in out Positive) return Boolean;
   --  If command-line argument I is one of the options above: takes it and
   --  its values into S, moves I past them and returns True.

   procedure Apply (S : Setup; Seed : Castle.Hash.U64);
   --  The colony as S asks, on ground that is loaded (Castle.Nav answers
   --  for it): the stake and the band (seeded from the world's Seed, as a
   --  click in the game seeds them), paths, stockpiles, the camp, supplies,
   --  jobs and orders.  Says what it did on standard output.

   function Body_Job (J : Castle.Colony.Job_Kind) return Castle.Bodies.Job_Kind;

   function Deer_Alive return Natural;
   function Colony_Line return String;   --  "colony: 6 in the band, ..." ("" with no stake)
   procedure Put_Report (After_Colony_Line : String := "");
   --  The colony line (with After_Colony_Line on its end), the camp's, the
   --  cook's and (with skills on) the skills', on standard output.
   function Housing_Line return String;
   function Storehouse_Line return String;   --  the storehouse ("" before it is asked for)
   function Ladders_Line return String;
   --  "ladders: 2 made, 1 standing at a house, 1 stored, 0 carried, 0 lost"
   --  ("": none has been made).
   function Cart_Line return String;
   --  "salt: 220 lb in the cart, 14 stored; 3 deer salted, 0 not, 0 lb of
   --  meat lost" ("": with no curing, or no stake).
   function Beds_Line return String;
   --  Who of the living has a bed of straw where it sleeps, and the straw
   --  in them all ("": nobody makes beds, or there is no camp).
   --  "housing: 2 standing, 1 being built, 4 without a home, 2 at home;
   --  Agnes's: the walls 41 %, wood 12 of 25, straw 0 of 28, built by Wat"
   --  ("" with no house begun and no housing zone).  At home: inside its
   --  own house now (at night, those of the housed who found their way in).
   function Demand_Line return String;
   --  "demand: food 1.2 of 12.0 days, asked; wood 14 of 32; ...": each good
   --  that is asked for or kept, what the stores have of what they want,
   --  and how many of the band are at rest with nothing asked of them.
   function Skills_Line return String;
   --  "skills: gathering 0.31 (2), ...": for each working skill, the mean
   --  level of the living whose job it is, and how many they are.
   function Food_Line (Hours : Long_Float) return String;
   procedure Put_Who;
   --  A line for each of the living: its name, how full its belly is and
   --  what it is doing (its status).  For measuring: colony_run --who puts
   --  them under each of its --log-hours lines.
   --  One line on the band's food at game clock Hours (--log-hours).

end Castle.Scenario;
