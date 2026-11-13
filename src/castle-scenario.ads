with Castle.Colony;
with Castle.Hash;
with Castle.Bodies;

--  A colony set up from the command line, and the log lines that report
--  it: shared by the game and the windowless runner (tools/colony_run), so
--  a scripted start is the same colony in both.
--
--    --stake X Y            the homestake (everything below needs it)
--    --band N               how many arrive (6)
--    --path X0 Y0 X1 Y1     a footpath (up to 16), planned: the band lays it
--    --paths-built          those paths laid on the spot
--    --stone-from M         for measuring: the camp's builders take no stone from nearer the stake
--                           than M metres, as if the nearest lay that far off
--    --stockpile X0 Y0 X1 Y1   a stockpile (up to 8)
--    --housing X0 Y0 X1 Y1  a housing zone (up to 8): the band builds a hovel there for each of
--                           its people, its foresters turning builder
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
--    --deer-scatter         the herds as they were before they fled together: each deer bolting on
--                           a heading of its own and trotting back, wading wherever a serf can (a
--                           colony loaded from a save keeps the switch it was saved with)
--    --by-skill             the jobs above go to whoever is best at each (gatherers first, and so
--                           on in that order), not to the first N members
--    --skills-at LEVEL      everyone arrives at LEVEL (0 .. 1) in every working skill: a band of
--                           novices, or of masters, to measure what skill is worth
package Castle.Scenario is

   type Rects is array (Positive range <>, Positive range <>) of Float;
   type Job_Flags is array (1 .. Castle.Colony.Max_Members) of Boolean;
   type Job_List is array (1 .. Castle.Colony.Max_Members) of Castle.Colony.Job_Kind;

   type Setup is record
      Stake            : Boolean := False;
      Stake_X, Stake_Y : Float := 0.0;
      Band             : Positive := 6;
      Paths            : Rects (1 .. 16, 1 .. 4) := [others => [others => 0.0]];
      Path_N           : Natural := 0;
      Piles            : Rects (1 .. 8, 1 .. 4) := [others => [others => 0.0]];
      Pile_N           : Natural := 0;
      Housing          : Rects (1 .. 8, 1 .. 4) := [others => [others => 0.0]];
      Housing_N        : Natural := 0;
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
      Deer_Scatter     : Boolean := False;   --  --deer-scatter
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
   --  One line on the band's food at game clock Hours (--log-hours).

end Castle.Scenario;
