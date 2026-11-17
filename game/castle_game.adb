with Ada.Command_Line;      use Ada.Command_Line;
with Ada.Containers.Ordered_Maps;
with Ada.Directories;
with Ada.Unchecked_Deallocation;
with Interfaces;
with Castle.Currents;
with Castle.Fields;
with Castle.Mesher;
with Ada.Real_Time;         use Ada.Real_Time;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;           use Ada.Text_IO;
with Interfaces.C;          use Interfaces.C;
with System.Multiprocessors;
with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Castle.Lod;
with Castle.Blocks;         use Castle.Blocks;
with Castle.Camera;
with Castle.Edits;
with Castle.Falls;
with Castle.Math;           use Castle.Math;
with Castle.Saves;
with Castle.Water;
with Castle.World_Blocks;
with Castle.Climate;
with Castle.Dims;           use Castle.Dims;
with Castle.GLFW;           use Castle.GLFW;
with Castle.Hash;           use Castle.Hash;
with Castle.Input;
with Castle.Maps;           use Castle.Maps;
with Castle.Platform;
with Castle.Render;
with Castle.Streaming;
use type Castle.Streaming.Result_Access;
with Castle.Worldgen;
with Castle.UI;
with Castle.HUD;
use type Castle.HUD.Tool_Mode;
with Castle.Serfs;
with Castle.Animals;
with Castle.Deer;
with Castle.Poses;
with Castle.Colony;
with Castle.Scenario;
with Castle.Actions;
with Castle.Pick;
with Ada.Strings;
with Ada.Strings.Fixed;
with Castle.Herds;
with Castle.Flora;
with Castle.Props;
with Castle.Cloth;
with Castle.Cutaway;
with Castle.Fire;
with Castle.Figures;
with Castle.Text;
with Castle.Settings;
use type Castle.Saves.Blob_Access;
with Castle.Nav;
with Castle.Geology;
with Castle.Marks;
with Castle.Zone_Marks;
with Castle.Bodies;

--  Castle Game: world, window, camera and streaming view.
--
--    castle_game [--seed N] [--at X Y] [--view METRES] [--size W H]
--                [--workers N] [--novsync] [--frames N --shot FILE.png]
--                [--cam YAW PITCH DIST] [--pan DX DY] [--msaa N] [--time HOUR] [--noshadows] [--noreflect]
--                [--flatclouds] [--mist AMOUNT] [--nomist] [--wet AMOUNT] [--nowet] [--lights N]
--                [--moon PHASE] [--nostars]
--                [--clouds COVER] [--day D] [--timescale H] [--weather KIND] [--snow M]
--                [--hud help,survey,debug,place|none] [--uiscale S] [--settings FILE] [--mouse X Y]
--
--  The clock runs at --timescale game hours per real second (a game minute
--  a second by default); [ and ] scrub hours, comma and period scrub days.
--  --weather forces clear, cloudy, rain, snow or storm; --snow forces the
--  snow depth (m).  Both only change what you see, not the climate.
--
--  --frames renders until the view has streamed in and at least N frames
--  have passed, saves a screenshot and exits (benchmarks, headless checks).
--  --pan moves the camera by (DX, DY) metres once the view has filled, so
--  a headless run also exercises unloading and re-streaming.
--
--  --hud opens panels at the start (F1 help, F2 survey, F3 debug; none
--  hides them all, as F4 does; stores, camp or orders opens that tab of the
--  band panel); --uiscale fixes the interface's scale (2, or 2.5: steps of
--  a quarter; F10 and F11 change it as you play, and that is remembered in
--  saves/settings.txt, or the file --settings names: a scripted run reads
--  no settings unless it is given that); --mouse puts the cursor at a
--  pixel, for headless shots of what hovering shows.
--
--  --pointer "FRAME:COMMAND, ..." drives the cursor in a scripted run
--  (--frames, --record take no real input): at each frame, counted from
--  the first with a colony on loaded ground, one of
--    move X Y      glide to a pixel          rel DX DY   glide that far from where it is aimed
--    member I      glide to member I of the band, and keep on them
--    deer K        the same for deer K       ground X Y  the ground at X, Y (metres)
--    click  rclick  wheel N  esc
--  An arrow is drawn where it is.
procedure Castle_Game is

   Seed      : U64 := 1;
   Start_X   : Float := 1_184.0;
   Start_Y   : Float := 1_088.0;
   View_M    : Float := 160.0;
   Width     : Positive := 1_600;
   Height    : Positive := 900;
   Workers   : Positive :=
     Positive'Max (1, Integer (System.Multiprocessors.Number_Of_CPUs) - 1);
   Vsync     : Boolean := True;
   Frames    : Natural := 0;
   Shot      : Unbounded_String := To_Unbounded_String ("screenshot.png");
   Cam_Set   : Boolean := False;
   At_Set    : Boolean := False;             --  --at given: it stands after a --load too
   Cam_Yaw, Cam_Pitch, Cam_Dist : Float := 0.0;
   Pan_X, Pan_Y : Float := 0.0;
   Pan_Back  : Boolean := False;             --  --pan-back: once there and the view filled, glide back again
   Pan_Home  : Boolean := False;             --  (it has turned for home)
   MSAA      : Natural := 4;
   Start_Day : Float := 20.0;                --  day of the 60-day year at the start
   Start_Hour : Float := 15.0;
   Time_Scale : Long_Float := 1.0 / 60.0;    --  game hours per real second: a game minute a second
   Game_Clock : Castle.Climate.Game_Hours := 0.0;
   Climate   : Castle.Climate.State;
   Forced    : Unbounded_String;             --  --weather: clear, cloudy, rain, snow, storm
   Forced_Snow : Float := -1.0;              --  --snow: metres everywhere
   Forced_Mist : Float := -1.0;              --  --mist: how much, 0 .. 1
   Forced_Wet  : Float := -1.0;              --  --wet: how wet the ground is, 0 .. 1
   Forced_Moon : Float := -1.0;              --  --moon: its phase, 0 new .. 0.5 full .. 1
   Test_Lights : Natural := 0;               --  --lights: fires scattered round the start, for looking and costing
   Hitch_Ms    : Float := 0.0;
   --  --hitch MS: a frame that takes the CPU longer than this says where the
   --  time went (the streaming, the colony's steps, the figures, the drawing).
   Panned    : Boolean := False;
   Load_Path : Unbounded_String;             --  --load: a save to start from
   Save_Path : Unbounded_String;             --  --save: write a save when --frames or --record ends
   Quick_Path : constant String := "saves/quicksave.castle";
   Dig_Boxes : array (1 .. 8, 1 .. 6) of Float := [others => [others => 0.0]];   --  --dig: metres (repeatable)
   Dig_Count : Natural := 0;
   Pour_Of   : array (1 .. 8) of Float := [others => 0.0];   --  --puddle: metres poured into the box instead
   Dig_Set   : Boolean := False;
   Dig_Late  : Boolean := False;             --  --late: dig once the view is loaded, as a click would
   Fill_Box  : array (1 .. 6) of Float := [others => 0.0];  --  --fill: metres, filled with planks once loaded
   Fill_Set  : Boolean := False;
   Sim_Ticks : Natural := 0;                 --  --simticks: water ticks run at once after the scripted edits
   Water_Clock : Float := 0.0;               --  real seconds owed to the water simulation
   Frame_Seconds : Float := 0.0;             --  real time this frame covers
   Flame_T       : Float := 0.0;             --  seconds the flames have flickered (drawn time, not the colony's)
   Sky_T         : Long_Float := 0.0;
   Drawn_Still   : Boolean := False;        --  --drawn-still: clouds, ripples and flames do not move
   --  Seconds the clouds have drifted, the water rippled and the rain
   --  fallen: drawn time too, so a recording steps it a thirtieth of a
   --  second a frame (it was the wall clock, and a recording's clouds went
   --  by at whatever pace the machine wrote its frames).
   Wind_Now      : Vec3 := (0.0, 0.0, 0.0);  --  the wind this frame (m/s): flames lean on it, smoke goes with it
   Step_Seconds  : Float := 0.0;             --  game time it moves on, before the speed: the
                                             --  frame's time, 0.1 s at most; a 30th in --record
   Water_Ticks : Natural := 0;               --  ticks run in real time (reported by --frames runs)
   Cap_Told    : Boolean := False;
   Rebuilding : Natural := 0;                --  edit rebuilds queued or running

   --  Editing (developer tools until the colony gives the orders).
   Tools     : Castle.HUD.Tool_State;
   Brush     : Positive renames Tools.Brush;   --  blocks: 1 (25 cm), 4 (1 m), 8 (2 m)
   Palette   : Castle.HUD.Palette_Array renames Castle.HUD.Palette;
   Pick      : Positive renames Tools.Pick;

   --  The interface: which panels show, the scale (0: from the window),
   --  and for headless shots a cursor fixed at a pixel (--mouse X Y).
   Show      : Castle.HUD.Shown;
   UI_Scale  : Float := 0.0;
   UI_Given  : Boolean := False;             --  --uiscale: it is not taken from the settings then
   Settings_Path  : Unbounded_String := To_Unbounded_String ("saves/settings.txt");
   Settings_Given : Boolean := False;        --  --settings: read even by a scripted run
   Mouse_Set : Boolean := False;
   Mouse_PX, Mouse_PY : Float := 0.0;
   Hud_Stats : Castle.HUD.Stats;
   Cursor_Hit : Castle.World_Blocks.Hit;

   --  People to look at until the colony brings its own: --lineup N stands
   --  N generated serfs in a row at the start; --walk X0 Y0 X1 Y1 sends one
   --  walking there and back (repeatable); --follow keeps the camera on the
   --  first; --record DIR N writes N frames, a thirtieth of a second apart,
   --  once they are out (for looking at motion headless).
   Lineup_N    : Natural := 0;
   Lineup_Turn : Float := 0.0;      --  --lineup-turn: the row turned this far from facing the camera (rad)
   Lineup_Does : Castle.Serfs.Motion_Kind := Castle.Serfs.Stand;   --  --lineup-does: what the row is doing
   Lineup_Posed : Boolean := False;
   Walk_N      : Natural := 0;
   Walks       : array (1 .. 8, 1 .. 4) of Float := [others => [others => 0.0]];
   Follow      : Boolean := False;
   Serfs_Out   : Boolean := False;
   --  Deer to look at: --deer N stands N in a row (every class in turn, some
   --  grazing, some alert); --deer-walk X0 Y0 X1 Y1 SPEED sends one there and
   --  back (repeatable; SPEED in m/s picks the gait); --follow-deer keeps the
   --  camera on the first.
   Deer_N      : Natural := 0;
   Deer_Walk_N : Natural := 0;
   Deer_Walks  : array (1 .. 8, 1 .. 5) of Float := [others => [others => 0.0]];
   Follow_Deer : Boolean := False;
   Record_Dir  : Unbounded_String;
   Record_N    : Natural := 0;
   Recorded    : Natural := 0;
   Force_Winter : Boolean := False;
   Show_Routes : Boolean := False;   --  F6, --paths: the serfs' routes over the ground
   Show_Map    : Boolean := False;   --  F7, --navmap: the walking map round the camera
   Show_Wells  : Boolean := False;   --  F8, --wellmap: the aquifer heat map round the camera

   --  The colony (Castle.Colony): each member drawn by a serf of Castle.Serfs.
   Serf_Of      : array (1 .. Castle.Colony.Max_Members) of Natural := [others => 0];
   Job_Shown    : array (1 .. Castle.Colony.Max_Members) of Castle.Colony.Job_Kind :=
     [others => Castle.Colony.Unassigned];
   Winter_Shown : array (1 .. Castle.Colony.Max_Members) of Boolean := [others => False];
   Cloak_Off_Shown : array (1 .. Castle.Colony.Max_Members) of Boolean := [others => False];
   --  Cloaks of cloth (John, 2026-11-13: "can we have the cloaks be dynamic cloth, that they wear at the
   --  start, then take off when they make their bed, and then draped over them when they sleep"; an
   --  experiment: --no-cloth is the cloaks as they were)
   Cloth_On : Boolean := True;
   type Cloak_Is is (Not_Yet, Worn, Off, Over);   --  on its back; lying where it was put down; over its sleeper
   Cloak_Cloth : array (1 .. Castle.Colony.Max_Members) of Castle.Cloth.Cloth_Id := [others => 0];
   Cloak_State : array (1 .. Castle.Colony.Max_Members) of Cloak_Is := [others => Not_Yet];
   Cloak_Pin   : array (1 .. Castle.Colony.Max_Members) of Vec3 := [others => (0.0, 0.0, 0.0)];
   Cloak_Hips  : array (1 .. Castle.Colony.Max_Members) of Vec3 := [others => (0.0, 0.0, 0.0)];   --  a frame ago,
   Cloak_Still : array (1 .. Castle.Colony.Max_Members) of Natural := [others => 0];       --  frames held still,
   Cloak_Laid  : array (1 .. Castle.Colony.Max_Members) of Vec3 := [others => (0.0, 0.0, 0.0)];   --  laid over here
   Still_Frames : constant := 10;     --  a sleeper's body this many frames still before its cloak is laid over it
   --  The herds (Castle.Herds): each live deer drawn by an animal of Castle.Animals.
   Deer_Anim    : array (1 .. Castle.Herds.Max_Deer) of Natural := [others => 0];
   Last_Speed   : Positive := 1;

   --  The pointer: the cursor's pixel, its clicks and the wheel, from the
   --  mouse or, in a scripted run, from --pointer; and what its ray is on.
   Ptr_X, Ptr_Y : Float := 0.0;
   Ptr_Click, Ptr_RClick, Ptr_Held, Ptr_Esc : Boolean := False;
   Ptr_Wheel    : Float := 0.0;
   Under        : Castle.Pick.Thing;
   Notes_Told   : Natural := 0;       --  the interface's notes put in the log so far

   type Script_Kind is (Move, Rel, To_Member, To_Deer, To_Ground, Click, RClick, Wheel, Esc);
   type Script_Event is record
      Frame : Natural := 0;
      Kind  : Script_Kind := Move;
      A, B  : Float := 0.0;
   end record;
   Script       : array (1 .. 128) of Script_Event;
   Script_N     : Natural := 0;
   Script_At    : Positive := 1;      --  the next event
   Script_Frame : Natural := 0;       --  frames with a colony on loaded ground
   type Aim_Kind is (At_Pixel, At_Member, At_Deer, At_Ground);
   Aim          : Aim_Kind := At_Pixel;
   Aim_X, Aim_Y : Float := 0.0;       --  the pixel, or the ground point (metres)
   Aim_I        : Natural := 0;
   Tgt_X, Tgt_Y : Float := 0.0;       --  the pixel it is gliding to
   --  a colony set up from the command line (--stake, --path, --stockpile, --gatherers)
   Scn             : Castle.Scenario.Setup;
   Log_Hours       : Float := 0.0;      --  --log-hours H: a line on the band's food every H game hours
   Deaths_Told     : Natural := 0;
   Told_Dead       : array (1 .. Castle.Colony.Max_Members) of Boolean := [others => False];
   Logged_At       : Long_Float := -1.0;
   Float_Window    : Boolean := False;   --  --float: a fixed-size window (Sway floats it at --size)
   Colony_Scripted : Boolean := False;
   type Stack_Pair is record
      CX, CY : Integer := 0;
   end record;
   Dirty   : array (1 .. 512) of Stack_Pair;   --  stacks the colony's edits touched this frame
   Dirty_N : Natural := 0;

   Upload_Budget  : constant := 48;          --  meshes taken per frame
   Arena_Quads    : constant := 32 * 1024 * 1024;   --  256 MB of quads

   type Stack_State is (None, Requested, Loaded);
   type State_Grid is array (0 .. Chunks_XY - 1, 0 .. Chunks_XY - 1) of Stack_State;
   type State_Grid_Access is access State_Grid;
   States    : constant State_Grid_Access := new State_Grid'(others => [others => None]);
   In_Flight : Natural := 0;

   --  Loaded stacks with a rebuild queued after edits.
   type Flag_Grid is array (0 .. Chunks_XY - 1, 0 .. Chunks_XY - 1) of Boolean;
   type Flag_Grid_Access is access Flag_Grid;
   Pending   : constant Flag_Grid_Access := new Flag_Grid'(others => [others => False]);

   --  Every stack that is requested or loaded, so unloading never depends
   --  on how far the camera moved in one frame.
   type Coord is record
      CX, CY : Integer := 0;
   end record;
   Max_Active : constant := 16_384;
   Active     : array (1 .. Max_Active) of Coord;
   Active_N   : Natural := 0;

   procedure Activate (Cx, Cy : Integer) is
   begin
      Active_N := Active_N + 1;
      Active (Active_N) := (Cx, Cy);
   end Activate;

   --  The whole map held (John, 2026-11-14: "can make the whole map solid
   --  and stream only the mesh?", and "ok build it with the whole map solid").
   --  Every stack's blocks and its ground summary are kept from soon after
   --  the start (Castle.World_Blocks: what the simulation reads); the view
   --  streams the meshes alone.  States above is the mesh's: None is a stack
   --  that is not drawn, held or not.  A stack out of view is asked for
   --  without a mesh, a few hundred out at a time, behind everything the view
   --  asks; one that leaves the view gives up its mesh and what is drawn of
   --  its water and keeps its blocks.  A held stack whose edits have moved
   --  since it was kept (a load; an edit across its edge) is asked for
   --  again: Hold_More looks the map over all the time, a little a frame.
   --  --no-whole-map: as before, a stack is dropped with its mesh.
   Whole_Map    : Boolean := True;
   Hold_Wait    : Boolean := False;          --  --hold-wait: a scripted run does not end before the map is held
   Show_Mem     : Boolean := False;          --  --mem: what the process holds, said at the end of a scripted run
   Hold_Cap     : constant := 256;           --  jobs without a mesh out at once
   Hold_Budget  : constant := 128;           --  and their results taken a frame at most,
   Hold_Frame_Ms : constant := 0.5;          --  or until keeping them has taken this long of the frame
   Hold_Out     : constant Flag_Grid_Access := new Flag_Grid'(others => [others => False]);
   Hold_Stale   : constant Flag_Grid_Access := new Flag_Grid'(others => [others => False]);   --  (kept before a load)
   type Gen_Grid is array (0 .. Chunks_XY - 1, 0 .. Chunks_XY - 1) of Natural;
   type Gen_Grid_Access is access Gen_Grid;
   Held_Gen     : constant Gen_Grid_Access := new Gen_Grid'(others => [others => 0]);   --  the edits each was kept at
   Holds_Out_N  : Natural := 0;
   Holds_Taken  : Natural := 0;              --  results without a mesh kept, all told
   Hold_Ms      : Float := 0.0;              --  the workers' time in them
   Hold_Main_Ms, Hold_Main_Max : Float := 0.0;   --  the main thread's in asking and keeping, all told and the worst frame
   type Coord_List is array (1 .. Chunks_XY * Chunks_XY) of Coord;
   type Coord_List_Access is access Coord_List;
   Hold_Order   : Coord_List_Access;         --  every stack, nearest the first view first
   Hold_At      : Natural := 0;              --  how far through it the looking is
   Hold_Since   : Natural := 0;              --  stacks looked at since one was last asked for
   Hold_Done    : Float := -1.0;             --  seconds from the first frame to the whole map held
   Hold_Began   : Time;
   Hold_Whole   : Boolean := False;          --  the looking has gone all round and found nothing to ask for, and none is out
   --  Scripted probes of what is held (the proofs in docs/systems/world.md, "The whole map held"):
   --  --save-at F PATH and --load-at F PATH save and load at frame F after the view filled (a save at 1 is
   --  taken before a --late dig); --probe-block X Y Z says at the end what block the simulation reads there.
   Save_At, Load_At : Natural := 0;
   Save_At_Path, Load_At_Path : Unbounded_String;
   type Probe is record
      X, Y, Z : Float := 0.0;
   end record;
   Probes  : array (1 .. 8) of Probe;
   Probe_N : Natural := 0;
   function Held (CX, CY : Integer) return Boolean is (Castle.World_Blocks.Ground_Version (CX, CY) > 0);

   --  The far view (John, 2026-11-15: "let's figure out how to get everything
   --  in view"; Castle.Render, "The far view").  Past the view, the land is
   --  drawn from tiles of coarser cells (Castle.Lod), in rings about the
   --  focus: level 1 from where the stacks' ring ends to twice as far, each
   --  level after to twice as far again, and the last level over the whole
   --  map, always, so that something is under everything from the first
   --  seconds.  The workers make them (after all the view asks, before what
   --  is only held); a tile whose stacks are edited is made again once it
   --  shows, not more often than its level's Far_Again_S.  --no-lod: none.
   Far_On    : Boolean := True;
   Far_Wait  : Boolean := False;           --  --far-wait: a scripted run does not end before the far view is whole
   Settle_Frames : Natural := 0;           --  --settle N: nor before N frames with nothing more coming in
   type Far_State is (None, Requested, Loaded);
   type Far_Tile is record
      State    : Far_State := None;
      Dirty    : Boolean := False;         --  one of its stacks edited since it was asked for
      Again    : Boolean := False;         --  asked for again, its mesh drawn until the new one comes
      Built_At : Float := 0.0;             --  when its mesh came (seconds from the first frame)
   end record;
   type Far_Tile_Grid is array (Castle.Lod.Level, 0 .. Chunks_XY / 2 - 1, 0 .. Chunks_XY / 2 - 1) of Far_Tile;
   type Far_Tile_Grid_Access is access Far_Tile_Grid;
   Far_Tiles   : constant Far_Tile_Grid_Access := new Far_Tile_Grid;
   Far_Out     : Natural := 0;             --  tiles the workers have in hand
   Far_Whole   : Boolean := False;         --  nothing wanted is missing, none is in hand
   Far_Fresh   : Boolean := False;         --  and none that shows is waiting to be made again for an edit
   Far_Made    : Natural := 0;
   Far_Ms      : Float := 0.0;             --  the workers' time in them
   Far_Done    : Float := -1.0;            --  seconds from the first frame to the far view whole
   Far_Began   : Time;
   Far_Started : Boolean := False;
   Far_Scan    : Natural := 0;
   Far_Scanned : Natural := 0;             --  when every tile was last looked at, and where the focus was
   Far_At_X, Far_At_Y : Float := -1.0E6;
   Far_Budget  : constant := 64;           --  tiles taken a frame
   Far_Again_S : constant array (Castle.Lod.Level) of Float := [2.0, 4.0, 8.0, 16.0];

   --  Stack (CX, CY) has been edited: the tiles over it are to be made again.
   procedure Far_Touch (CX, CY : Integer) is
   begin
      if Far_On and then CX in 0 .. Chunks_XY - 1 and then CY in 0 .. Chunks_XY - 1 then
         for L in Castle.Lod.Level loop
            Far_Tiles (L, CX / 2 ** L, CY / 2 ** L).Dirty := True;
         end loop;
      end if;
   end Far_Touch;

   W     : World;
   Flow_Debug : Boolean := False;              --  --flowmap: water coloured by its current
   Water_Steps : Natural := 8;                 --  --watersteps N: water drawn in steps of 1/N block (0: one sheet)
   Win   : Window;
   Cam   : Castle.Camera.State;
   Meshed       : Natural := 0;
   Worker_Ms    : Float := 0.0;

   function Material_At (Bx, By, Bz : Integer) return Material is
     (Castle.World_Blocks.Block_At (Bx, By, Bz).Mat);

   --  The map routes are planned on (Castle.Nav), 30 m round the camera's
   --  focus: every 0.5 m cell a serf can stand in, at the level nearest the
   --  focus, coloured by how quick it is to cross (blue a footpath or planks,
   --  green grass, yellow sand or rock, orange bog or brush, red wading);
   --  where nothing is drawn no one walks: walls, trunks, deep water, cliffs
   --  too tall to stand under.
   procedure Show_Walking_Map is
      R  : constant := 60;                    --  cells
      Cx : constant Integer := Integer (Float'Floor (Cam.X / Castle.Nav.Cell_M));
      Cy : constant Integer := Integer (Float'Floor (Cam.Y / Castle.Nav.Cell_M));
   begin
      for X in Cx - R .. Cx + R loop
         for Y in Cy - R .. Cy + R loop
            if (X - Cx) ** 2 + (Y - Cy) ** 2 <= R * R then
               declare
                  N    : Natural;
                  F    : Castle.Nav.Floor_List;
                  Pick : Natural := 0;
               begin
                  Castle.Nav.Floors_At (X, Y, N, F);
                  for I in 1 .. N loop
                     if F (I).Speed > 0.0 and then
                       (Pick = 0 or else abs (Float (F (I).Z) * 0.25 - Cam.Z) < abs (Float (F (Pick).Z) * 0.25 - Cam.Z))
                     then
                        Pick := I;
                     end if;
                  end loop;
                  if Pick > 0 then
                     declare
                        S  : constant Float := F (Pick).Speed;
                        Z  : constant Float := Float (F (Pick).Z) * 0.25 + 0.06;
                        Yc : constant Float := (Float (Y) + 0.5) * Castle.Nav.Cell_M;
                        C  : constant Castle.Marks.Colour :=
                          (if S >= 1.1 then (0.3, 0.6, 1.0, 0.45)
                           elsif S >= 0.9 then (0.3, 0.9, 0.3, 0.35)
                           elsif S >= 0.7 then (1.0, 0.9, 0.2, 0.45)
                           elsif S >= 0.45 then (1.0, 0.55, 0.1, 0.5)
                           else (1.0, 0.15, 0.1, 0.55));
                     begin
                        Castle.Marks.Strip ((Float (X) * Castle.Nav.Cell_M + 0.2, Yc, Z),
                                            (Float (X + 1) * Castle.Nav.Cell_M - 0.2, Yc, Z), 0.42, C);
                     end;
                  end if;
               end;
            end if;
         end loop;
      end loop;
   end Show_Walking_Map;

   --  Where a well would find water, 30 m round the camera's focus, a square a
   --  metre: the heat map of the aquifer (Castle.Geology.Well_Info), which is
   --  a field, not blocks.  Hue the yield, red poor through yellow to blue
   --  good; darker the further down the water lies (15 m and more darkest).
   procedure Show_Well_Map is
      R  : constant := 30;
      Cx : constant Integer := Integer (Float'Floor (Cam.X));
      Cy : constant Integer := Integer (Float'Floor (Cam.Y));
      function Mix (A, B : Float; T : Float) return Float is (A + (B - A) * T);
   begin
      for X in Cx - R .. Cx + R loop
         for Y in Cy - R .. Cy + R loop
            if (X - Cx) ** 2 + (Y - Cy) ** 2 <= R * R then
               declare
                  Xm : constant Float := Float (X) + 0.5;
                  Ym : constant Float := Float (Y) + 0.5;
                  Z  : constant Float := Castle.Nav.Surface_Z (Xm, Ym);
                  Depth, Yield : Float;
               begin
                  if Z >= 0.0 then
                     Castle.Geology.Well_Info (W, Xm, Ym, Depth, Yield);
                     declare
                        T    : constant Float := Float'Max (0.0, Float'Min (1.0, Yield));
                        Dark : constant Float := 1.0 - 0.6 * Float'Min (1.0, Float'Max (0.0, Depth / 15.0));
                        C    : constant Castle.Marks.Colour :=
                          (if T < 0.5
                           then (Dark * Mix (0.59, 0.88, 2.0 * T), Dark * Mix (0.27, 0.8, 2.0 * T),
                                 Dark * Mix (0.18, 0.35, 2.0 * T), 0.7)
                           else (Dark * Mix (0.88, 0.16, 2.0 * T - 1.0), Dark * Mix (0.8, 0.55, 2.0 * T - 1.0),
                                 Dark * Mix (0.35, 0.92, 2.0 * T - 1.0), 0.7));
                     begin
                        Castle.Marks.Strip ((Float (X) + 0.08, Ym, Z + 0.07), (Float (X + 1) - 0.08, Ym, Z + 0.07),
                                            0.84, C);
                     end;
                  end if;
               end;
            end if;
         end loop;
      end loop;
   end Show_Well_Map;

   ------------------------------------------------------------------ the colony

   function Body_Job (J : Castle.Colony.Job_Kind) return Castle.Bodies.Job_Kind is
     (case J is
         when Castle.Colony.Unassigned => Castle.Bodies.Idle,
         when Castle.Colony.Gatherer   => Castle.Bodies.Gatherer,
         when Castle.Colony.Forester   => Castle.Bodies.Forester,
         when Castle.Colony.Hunter     => Castle.Bodies.Hunter,
         when Castle.Colony.Porter     => Castle.Bodies.Porter,
         when Castle.Colony.Cook       => Castle.Bodies.Idle);

   function Motion_Of (A : Castle.Colony.Act) return Castle.Serfs.Motion_Kind is
     (case A is
         when Castle.Colony.Standing     => Castle.Serfs.Stand,
         when Castle.Colony.Walking      => Castle.Serfs.Walk,
         when Castle.Colony.Picking      => Castle.Serfs.Pick,
         when Castle.Colony.Putting_Down => Castle.Serfs.Put_Down,
         when Castle.Colony.Chopping     => Castle.Serfs.Chop,
         when Castle.Colony.Sneaking     => Castle.Serfs.Sneak,
         when Castle.Colony.Aiming       => Castle.Serfs.Aim,
         when Castle.Colony.Eating       => Castle.Serfs.Eat,
         when Castle.Colony.Sleeping     => Castle.Serfs.Sleep,
         when Castle.Colony.Stirring     => Castle.Serfs.Stir,
         when Castle.Colony.Eating_Seated => Castle.Serfs.Sit_Eat,
         when Castle.Colony.Dead         => Castle.Serfs.Lie);

   --  The colony's trees are the generator's (Castle.Flora).
   pragma Compile_Time_Error (Castle.Colony.Tree_Cell_B /= Castle.Flora.Tree_Cell,
                              "the colony's tree cells must be the generator's");

   function Colony_Tree (I, J : Integer) return Castle.Colony.Tree_Info is
      T : constant Castle.Flora.Tree := Castle.Flora.Tree_At (W, I, J);
   begin
      if not T.Valid then
         return (others => <>);
      end if;
      return (Valid => True,
              Kind => (case T.Kind is
                          when Castle.Flora.Broadleaf | Castle.Flora.Aspen => Castle.Colony.Broadleaf,
                          when Castle.Flora.Spruce | Castle.Flora.Pine     => Castle.Colony.Conifer,
                          when Castle.Flora.Apple                          => Castle.Colony.Apple),
              Bx => T.Bx, By => T.By, Bz => T.Bz, Trunk_W => T.Trunk_W, Trunk_H => T.Trunk_H);
   end Colony_Tree;

   procedure Colony_Tree_Shape
     (I, J  : Integer;
      Visit : not null access procedure (Bx, By, Bz : Integer; M : Material)) is
   begin
      Castle.Flora.Tree_Blocks (Castle.Flora.Tree_At (W, I, J), Visit);
   end Colony_Tree_Shape;

   --  A serf for every member, dressed for their job and the season, told
   --  each frame where the member is and what they are doing.
   procedure Show_Members is
      use Castle.Colony;
      Winter : constant Boolean := Force_Winter
        or else Castle.Climate."=" (Castle.Climate.Season_Of (Castle.Climate.Day_Of_Year (Game_Clock)),
                                    Castle.Climate.Winter);
   begin
      for I in 1 .. Members loop
         declare
            J : constant Job_Kind := Job_Of (I);
            --  (asleep in winter its cloak is off its back: it lies under it)
            Off : constant Boolean := (Winter and then Doing (I) = Sleeping) or else Cloth_On;   --  (cloth: drawn apart)
            O : constant Castle.Bodies.Outfit := (Job => Body_Job (J), Winter => Winter, Cloak_Off => Off);
         begin
            if Serf_Of (I) = 0 then
               Serf_Of (I) := Castle.Serfs.Spawn_Driven (Genome_Of (I), O, Where (I), 0.0);
               Job_Shown (I) := J;
               Winter_Shown (I) := Winter;
               Cloak_Off_Shown (I) := Off;
            elsif Job_Shown (I) /= J or else Winter_Shown (I) /= Winter or else Cloak_Off_Shown (I) /= Off then
               Castle.Serfs.Restyle (Serf_Of (I), O);
               Job_Shown (I) := J;
               Winter_Shown (I) := Winter;
               Cloak_Off_Shown (I) := Off;
            end if;
            if Serf_Of (I) > 0 then
               --  (up its ladder, where its feet are on the rungs)
               Castle.Serfs.Drive (Serf_Of (I), Shown_At (I), Motion_Of (Doing (I)), Work_Spot (I),
                                   Log => Carrying (I) in Wood | Straw | Carcass | Salt | Ladder
                                          or else (Cart.Towed and then Cart.By = I));   --  (its hands on the shafts)
               Castle.Serfs.Perch (Serf_Of (I), (if Aloft (I) then Shown_At (I).Z - Where (I).Z else 0.0));
               --  (asleep across the way to the fire, its face is to the fire)
               Castle.Serfs.Lie_Facing (Serf_Of (I), Doing (I) = Sleeping and then Sleeping_Place (I).By_Fire,
                                        Castle.Colony.Camp);
            end if;
         end;
      end loop;
   end Show_Members;

   --  An animal for every live deer of the herds, in its class and the
   --  season's coat, told each frame where the deer is (between colony
   --  steps) and what it is doing.
   procedure Show_Deer is
      Winter : constant Boolean := Force_Winter
        or else Castle.Climate."=" (Castle.Climate.Season_Of (Castle.Climate.Day_Of_Year (Game_Clock)),
                                    Castle.Climate.Winter);
      T : constant Float := Castle.Colony.Blend;
   begin
      for K in 1 .. Castle.Herds.Deer_Slots loop
         if Castle.Herds.Alive (K) then
            declare
               P : constant Vec3 := Castle.Herds.Where (K, T);
            begin
               if Deer_Anim (K) = 0 then
                  Deer_Anim (K) := Castle.Animals.Spawn (Castle.Herds.Class_Of (K), P, 0.0,
                                                         Castle.Herds.Seed_Of (K), Winter);
               end if;
               if Deer_Anim (K) > 0 then
                  Castle.Animals.Restyle (Deer_Anim (K), Castle.Herds.Class_Of (K));
                  Castle.Animals.Set_Winter (Deer_Anim (K), Winter);
                  Castle.Animals.Drive (Deer_Anim (K), P, Castle.Herds.Doing (K));
               end if;
            end;
         elsif Deer_Anim (K) > 0 then
            Castle.Animals.Remove (Deer_Anim (K));
            Deer_Anim (K) := 0;
         end if;
      end loop;
   end Show_Deer;

   --  The colony as the command line asks for it, once the ground is loaded.
   procedure Script_Colony is
   begin
      Castle.Scenario.Apply (Scn, Seed);
   end Script_Colony;

   --  The top of the block a ray hit: where a click on the ground lands.
   function Ground_Point (H : Castle.World_Blocks.Hit) return Vec3 is
     (((Float (H.X) + 0.5) * 0.25, (Float (H.Y) + 0.5) * 0.25, Float (H.Z + 1) * 0.25));

   --  N props L stacked at Centre lying along Turn: rows of Across side by
   --  side Gap apart, each row Rise above the one under it with one fewer
   --  in it, four rows at most.
   procedure Prop_Stack (L : Castle.Figures.Look_Id; Centre : Vec3; Turn : Float; N, Across : Positive;
                         Gap, Rise : Float) is
      Side_V : constant Vec3 := (-Sin (Turn), Cos (Turn), 0.0);
      Left   : Natural := N;
      Row    : Natural := 0;
   begin
      while Left > 0 and then Row < 4 loop
         declare
            In_Row : constant Positive := Integer'Max (1, Across - Row);
            Here   : constant Natural := Natural'Min (Left, In_Row);
         begin
            for J in 0 .. Here - 1 loop
               Castle.Props.Put (L, Centre + Side_V * (Gap * (Float (J) - Float (In_Row - 1) / 2.0))
                                    + (0.0, 0.0, Rise * Float (Row)),
                                 Turn + 0.04 * Float ((J * 7 + Row * 3) mod 5 - 2));
            end loop;
            Left := Left - Here;
            Row := Row + 1;
         end;
      end loop;
   end Prop_Stack;

   procedure Log_Stack (Centre : Vec3; Turn : Float; N, Across : Positive) is
   begin
      Prop_Stack (Castle.Props.Log, Centre, Turn, N, Across, 0.21, 0.19);
   end Log_Stack;

   --  N small things on a cell: a grid of Per_Side x Per_Side, Gap apart,
   --  in layers Rise apart (Rise 0: one layer).
   procedure Prop_Grid (L : Castle.Figures.Look_Id; Centre : Vec3; N, Per_Side : Positive; Gap, Rise : Float;
                        Turn : Float := 0.0) is
      K : Natural := 0;
      Layers : constant Positive := (if Rise > 0.0 then 3 else 1);
      Ct : constant Float := Cos (Turn);
      St : constant Float := Sin (Turn);
   begin
      for Layer in 0 .. Layers - 1 loop
         for A in 0 .. Per_Side - 1 loop
            for C in 0 .. Per_Side - 1 loop
               exit when K >= N;
               declare
                  Off : constant Float := Float (Per_Side - 1) / 2.0;
                  J   : constant Float := 0.03 * Float ((A * 5 + C * 3 + Layer * 7) mod 5 - 2);
               begin
                  declare
                     Dx : constant Float := Gap * (Float (A) - Off) + J;
                     Dy : constant Float := Gap * (Float (C) - Off) - J;
                  begin
                     Castle.Props.Put (L, Centre + (Dx * Ct - Dy * St, Dx * St + Dy * Ct, Rise * Float (Layer)),
                                       Turn + 0.5 * Float ((A + 2 * C + Layer) mod 4));
                  end;
                  K := K + 1;
               end;
            end loop;
         end loop;
      end loop;
   end Prop_Grid;

   function Season_Winter return Boolean is
     (Force_Winter or else Castle.Climate."=" (Castle.Climate.Season_Of (Castle.Climate.Day_Of_Year (Game_Clock)),
                                               Castle.Climate.Winter));

   --  A deer lying on its side at Ground, its spine along Turn, legs out.
   procedure Lying_Deer (Ground : Vec3; Turn : Float; C : Castle.Deer.Class) is
      D   : constant Castle.Deer.Dims := Castle.Deer.Dims_Of (C);
      Fw  : constant Vec3 := (Cos (Turn), Sin (Turn), 0.0);
      Rt  : constant Vec3 := (Fw.Y, -Fw.X, 0.0);
      Mid : constant Vec3 := Ground + (0.0, 0.0, 0.16 * D.Size);
      P   : Castle.Deer.Pose;
      F   : Castle.Poses.Frames;
      Ok  : Castle.Deer.Leg_Flags;
   begin
      P.Hips := Mid - Fw * (0.5 * D.Spine);
      P.Shoulders := Mid + Fw * (0.5 * D.Spine);
      P.Roll := 1.5708;                       --  on its right side
      P.Neck := 1.5;                          --  stretched out along the ground
      for L in Castle.Deer.Leg loop
         declare
            Root : constant Vec3 := (if Castle.Deer.Is_Fore (L) then P.Shoulders else P.Hips);
            Len  : constant Float := 0.85 * (if Castle.Deer.Is_Fore (L) then D.Fore_Upper + D.Fore_Lower
                                             else D.Hind_Upper + D.Hind_Lower);
         begin
            P.Hoof (L) := (Root.X - Rt.X * Len, Root.Y - Rt.Y * Len, Ground.Z + 0.06)
              + Fw * ((if Castle.Deer.Is_Left (L) then 0.08 else -0.08) * D.Size);
         end;
      end loop;
      Castle.Deer.Solve (D, P, F, Ok);
      Castle.Figures.Add (Castle.Figures.Look_Id (Castle.Animals.Look (C, Season_Winter)), F);
   end Lying_Deer;

   --  A deer across serf S's shoulders, its legs and head hanging.
   procedure Carried_Deer (S : Positive; C : Castle.Deer.Class) is
      D   : constant Castle.Deer.Dims := Castle.Deer.Dims_Of (C);
      H   : constant Float := Castle.Serfs.Heading (S);
      Rt  : constant Vec3 := (Sin (H), -Cos (H), 0.0);
      Top : constant Vec3 := Castle.Serfs.Shoulders_Top (S) + (0.0, 0.0, 0.08);
      P   : Castle.Deer.Pose;
      F   : Castle.Poses.Frames;
      Ok  : Castle.Deer.Leg_Flags;
   begin
      P.Hips := Top + Rt * (0.5 * D.Spine);
      P.Shoulders := Top - Rt * (0.5 * D.Spine);
      P.Neck := 2.7;                          --  the head hanging
      for L in Castle.Deer.Leg loop
         declare
            Root : constant Vec3 := (if Castle.Deer.Is_Fore (L) then P.Shoulders else P.Hips);
            Len  : constant Float := 0.9 * (if Castle.Deer.Is_Fore (L) then D.Fore_Upper + D.Fore_Lower
                                            else D.Hind_Upper + D.Hind_Lower);
         begin
            P.Hoof (L) := Root - (0.0, 0.0, Len);
         end;
      end loop;
      Castle.Deer.Solve (D, P, F, Ok);
      Castle.Figures.Add (Castle.Figures.Look_Id (Castle.Animals.Look (C, Season_Winter)), F);
   end Carried_Deer;

   --  An arrow in flight (on a shallow arc) or stuck in the ground.
   procedure Show_Arrow (A : Castle.Colony.Arrow_View) is
      Way : constant Vec3 := A.To - A.From;
      L   : constant Float := Float'Max (0.01, Sqrt (Dot (Way, Way)));
      T   : constant Float := A.Flight;
      Arc : constant Float := 0.04 * L;       --  how high it rises over the way
      Pt  : constant Vec3 := A.From + Way * T + (0.0, 0.0, 4.0 * Arc * T * (1.0 - T));
      --  its heading: along the way, pitched by the arc (steeper stuck in the ground)
      Rise : constant Float := (if A.Stuck and then T >= 1.0 then -0.6 * L else 4.0 * Arc * (1.0 - 2.0 * T));
      Dir0 : constant Vec3 := (Way.X / L, Way.Y / L, (Way.Z + Rise) / L);
      Dir  : constant Vec3 := Dir0 * (1.0 / Float'Max (0.01, Sqrt (Dot (Dir0, Dir0))));
      X0   : constant Vec3 := (Dir.Y, -Dir.X, 0.0);
      X    : constant Vec3 := X0 * (1.0 / Float'Max (0.01, Sqrt (Dot (X0, X0))));
      Z    : constant Vec3 := (-Dir.X, -Dir.Y, -Dir.Z);
      Y    : constant Vec3 := Cross (Z, X);
      Tip  : constant Vec3 := (if A.Stuck and then T >= 1.0 then A.To + Dir * 0.25 else Pt);
      Fr   : constant Castle.Poses.Frame := (X => X, Y => Y, Z => Z, O => Tip - Dir * 0.7);
   begin
      if not A.Stuck and then T >= 1.0 then
         return;                              --  it struck home
      end if;
      Castle.Figures.Add (Castle.Props.Arrow, [others => Fr]);
   end Show_Arrow;

   --  How well the camp's fire burns, 0 .. 1: it sinks as the wood on it
   --  runs out, and on through its dying down; and how far through that it is.
   function Camp_Heat return Float is (Castle.Colony.Camp_State.Heat);
   function Camp_Dying return Float is
     (if Castle.Colony.Camp_State.Dying
      then 1.0 - Castle.Colony.Camp_State.Ember_H / Castle.Colony.Die_Down_Hours else 0.0);
   function Camp_Alight return Boolean is (Castle.Colony.Camp_State.Burning or else Castle.Colony.Camp_State.Dying);

   --  The camp (its ground is shown with the other zones').  Being built:
   --  the stones and the wood brought for its hearth so far, lying where it
   --  will stand.  Built: a ring of stones round the fire's bed (glowing
   --  coals, or ash when it is out), the fire while it burns (Castle.Fire:
   --  flames, sparks, smoke), the crossbar and the pot over it.  Either way
   --  the seat logs laid, and the firewood stacked in its south-east corner.
   procedure Show_Camp is
      use Castle.Colony;
      C : constant Vec3 := Camp;
      S : constant Camp_View := Camp_State;
      function G (X, Y : Float) return Vec3 is
         Z : constant Float := Castle.Nav.Surface_Z (X, Y);
      begin
         return (X, Y, (if Z >= 0.0 then Z else C.Z));
      end G;
   begin
      if not S.Built then
         declare
            Ct : constant Float := Cos (Camp_Turn);
            St : constant Float := Sin (Camp_Turn);
         begin
            if S.Stones > 0 then
               Prop_Grid (Castle.Props.Stone, G (C.X - 0.35 * Ct, C.Y - 0.35 * St), S.Stones, 2, 0.24, 0.15, Camp_Turn);
            end if;
            if S.Frame > 0 then
               Log_Stack (G (C.X + 0.45 * Ct, C.Y + 0.45 * St), Camp_Turn + Ada.Numerics.Pi / 2.0, S.Frame, 3);
            end if;
         end;
      else
         for K in 0 .. 9 loop
            declare
               A : constant Float := 2.0 * Ada.Numerics.Pi * Float (K) / 10.0;
            begin
               Castle.Props.Put (Castle.Props.Stone, G (C.X + 0.42 * Cos (A), C.Y + 0.42 * Sin (A)),
                                 A + Ada.Numerics.Pi / 2.0);
            end;
         end loop;
         Castle.Props.Put ((if Camp_Alight then Castle.Props.Embers else Castle.Props.Ashes), C, 0.3);
         if Camp_Alight then
            Castle.Fire.Show (C, Camp_Heat, Flame_T, Wind_Now, Dying => Camp_Dying);
         end if;
         Castle.Props.Put (Castle.Props.Crossbar, C, Camp_Turn);
         Castle.Props.Put (Castle.Props.Pot (S.Stew > 0 or else S.In_Pot > 0), C + (0.0, 0.0, 0.5), 0.0);
      end if;
      for K in 1 .. S.Seats loop
         Castle.Props.Put (Castle.Props.Seat, Seat_Log (K), Seat_Turn (K));
      end loop;
      if S.Logs > 0 then
         Log_Stack (Firewood_Place, Camp_Turn, S.Logs, 2);
      end if;
   end Show_Camp;

   --  The zones: each one's ground filled in, a line round its edge (a
   --  stockpile's, the camp's); and the paths planned, as far as they are
   --  still to lay.
   procedure Show_Zones is
      use Castle.Colony;
   begin
      Castle.Zone_Marks.Show_Paths;
      for Z in 1 .. Zone_Count loop
         Castle.Zone_Marks.Show_Zone
           (Z, (case Zone_At (Z).Kind is
                   when Stockpile_Zone  => Castle.Zone_Marks.Stockpile,
                   when Camp_Zone       => Castle.Zone_Marks.Camp,
                   when Habitation_Zone => Castle.Zone_Marks.Housing));
      end loop;
      Castle.Zone_Marks.Show_Houses;
   end Show_Zones;

   --  What lies in the stockpiles, each place's lying the way its lot
   --  does: baskets (one to a gatherer's load, four at most), logs and
   --  sheaves stacked, stones, clods of earth and joints heaped, hides laid flat.
   procedure Show_Stockpiles is
      use Castle.Colony;
      Spot : constant array (1 .. 4) of Vec3 :=
        [(-0.2, -0.2, 0.0), (0.2, 0.2, 0.0), (0.2, -0.2, 0.0), (-0.2, 0.2, 0.0)];
   begin
      for K in 1 .. Cell_Count loop
         declare
            C  : constant Cell_View := Cell_At (K);
            Ct : constant Float := Cos (C.Turn);
            St : constant Float := Sin (C.Turn);
         begin
            if C.Count > 0 and then C.Kind in Berries | Vegetables | Apples | Grain then
               for J in 1 .. Natural'Min (4, (C.Count + Carry_Limit (C.Kind) - 1) / Carry_Limit (C.Kind)) loop
                  Castle.Props.Put (Castle.Props.Basket_Of (case C.Kind is
                                                               when Vegetables => Castle.Props.Vegetable_Heap,
                                                               when Apples => Castle.Props.Apple_Heap,
                                                               when Grain => Castle.Props.Grain_Heap,
                                                               when others => Castle.Props.Berry_Heap),
                                    C.Centre + (Spot (J).X * Ct - Spot (J).Y * St, Spot (J).X * St + Spot (J).Y * Ct, 0.0),
                                    0.4 * Float (J + K));
               end loop;
            elsif C.Count > 0 and then C.Kind = Wood then
               Log_Stack (C.Centre, C.Turn, C.Count, 4);
            elsif C.Count > 0 and then C.Kind = Straw then
               Prop_Stack (Castle.Props.Sheaf, C.Centre, C.Turn, (C.Count + 1) / 2, 3, 0.27, 0.23);
            elsif C.Count > 0 and then C.Kind = Stone then
               Prop_Grid (Castle.Props.Stone, C.Centre, (C.Count + 1) / 2, 3, 0.27, 0.15, C.Turn);
            elsif C.Count > 0 and then C.Kind = Earth then
               Prop_Grid (Castle.Props.Clod, C.Centre, (C.Count + 3) / 4, 3, 0.27, 0.2, C.Turn);
            elsif C.Count > 0 and then C.Kind = Meat then
               Prop_Grid (Castle.Props.Joint, C.Centre, (C.Count + 1) / 2, 3, 0.25, 0.15, C.Turn);
            elsif C.Count > 0 and then C.Kind = Hide then
               Prop_Grid (Castle.Props.Hide, C.Centre, C.Count, 1, 0.0, 0.05, C.Turn);
            elsif C.Count > 0 and then C.Kind = Ladder then         --  stood in its place, propped on a pole
               for J in 1 .. C.Count loop
                  Castle.Props.Put_Ladder_Stood (C.Centre, C.Turn, J);
               end loop;
            elsif C.Count > 0 and then C.Kind = Salt then           --  a sack to twenty pounds
               Prop_Grid (Castle.Props.Sack, C.Centre, (C.Count + 19) / 20, 2, 0.42, 0.24, C.Turn);
            end if;
         end;
      end loop;
      --  logs where trees came down
      for K in 1 .. Pile_Count loop
         declare
            P : constant Pile_View := Pile_At (K);
         begin
            if P.Count > 0 then
               Log_Stack (P.Centre, P.Turn, P.Count, 3);
            end if;
         end;
      end loop;
      --  deer brought down: lying where they fell, or across a hunter's shoulders
      for K in 1 .. Carcass_Count loop
         if Carcass_Used (K) then
            declare
               C : constant Carcass_View := Carcass_At (K);
            begin
               if C.Lying then
                  Lying_Deer (C.Centre, C.Turn, C.Class);
               elsif C.Holder in 1 .. Members and then Serf_Of (C.Holder) > 0 then
                  Carried_Deer (Serf_Of (C.Holder), C.Class);
               end if;
            end;
         end if;
      end loop;
      for K in 1 .. Arrow_Count loop
         Show_Arrow (Arrow_At (K));
      end loop;
      --  a ladder against the eave of each house that has one standing at it
      for H in 1 .. House_Count loop
         declare
            L : constant Ladder_View := Ladder_At (H);
         begin
            if L.Standing then
               Castle.Props.Put_Ladder (L.Foot, L.Top);
            end if;
         end;
      end loop;
      --  and on shoulders (stone goes in the porter's sack)
      for I in 1 .. Members loop
         if Serf_Of (I) > 0 and then Carrying (I) in Wood | Straw | Salt | Ladder then
            Castle.Props.Put ((if Carrying (I) = Wood then Castle.Props.Log
                               elsif Carrying (I) = Salt then Castle.Props.Sack
                               elsif Carrying (I) = Ladder then Castle.Props.Ladder else Castle.Props.Sheaf),
                              Castle.Serfs.Log_Rest (Serf_Of (I)) + (if Carrying (I) = Ladder then (0.0, 0.0, 0.05) else (0.0, 0.0, 0.0)),
                              Castle.Serfs.Heading (Serf_Of (I)));
         end if;
      end loop;
   end Show_Stockpiles;

   --  The lord's cart: its body and four wheels round the bed that stands
   --  in the world, and the sacks of salt left in it (one to forty pounds,
   --  six at the most, the last ones on top).
   procedure Show_Cart is
      C : constant Castle.Colony.Cart_View := Castle.Colony.Cart;
   begin
      if C.Here then
         Castle.Props.Put_Cart (C.At_P, C.Turn, (C.Salt + 39) / 40, Towed => C.Towed);
      end if;
   end Show_Cart;

   --  F6: where each member is going.
   --  The beds of straw: each one's by the fire, where it made it, and the
   --  one in each house that has one; a bed lies back from where its
   --  sleeper's feet are, away from the fire (in a house, toward its door).
   procedure Show_Beds is
      use Castle.Colony;
      procedure Bed (Feet, Toward : Vec3) is
         Dx : constant Float := Toward.X - Feet.X;
         Dy : constant Float := Toward.Y - Feet.Y;
         L  : constant Float := Sqrt (Dx * Dx + Dy * Dy);
      begin
         if L > 0.01 then
            Castle.Props.Put (Castle.Props.Pallet, (Feet.X - 1.05 * Dx / L, Feet.Y - 1.05 * Dy / L, Feet.Z),
                              Arctan (Dy, Dx));
         end if;
      end Bed;
   begin
      for I in 1 .. Members loop
         declare
            B : constant Bed_View := Camp_Bed (I);
         begin
            if B.Made then
               Bed (B.Feet, B.Toward);
            end if;
         end;
      end loop;
      for H in 1 .. House_Count loop
         declare
            V : constant House_View := House_At (H);
         begin
            if V.Has_Bed then
               Bed (V.Bed, V.Bed + (V.Corner (4) - V.Corner (1)));
            end if;
         end;
      end loop;
   end Show_Beds;

   --  The band's cloaks (John, 2026-11-12: "they can set down next to their
   --  bed during the summer, wear it during with their winter clothes in the
   --  winter, and use it as a blanket when they sleep"): asleep, each lies
   --  under its own; awake and not in winter (when it is on its back), it
   --  lies folded by the head of its owner's bed.
   --  Serf S's cloak spread over it as it lies.
   procedure Spread_Cloak (S : Positive) is
      Hips, Along, Belly : Vec3;
      K : constant Float := Castle.Serfs.Height_Of (S) / 1.7;
   begin
      Castle.Serfs.Lying_Frame (S, Hips, Along, Belly);
      Castle.Props.Put_In
        (Castle.Props.Cloak_Spread (Castle.Serfs.Cloak_Of (S)),
         (X => Along * K, Y => (-Along.Y * K, Along.X * K, 0.0), Z => (0.0, 0.0, K), O => Hips + Belly * (0.14 * K)));
   end Spread_Cloak;

   --  The cloaks of cloth.  Worn on its back from the start (its top held
   --  across the shoulders, behind the neck) until its owner has made the
   --  bed it sleeps on; then taken off where it is (let go: it falls), and
   --  over its owner asleep (laid over it from above: it settles over its
   --  body); awake again it is left lying on the bed.  In winter it is worn
   --  whenever its owner is awake, as before.  Snapped onto the shoulders
   --  again after a jump (a load, a fast clock) and whenever it is put on.
   --  From a sleeper's feet toward its head, as its bed lies (back from its
   --  feet, away from what they point to).
   function Toward_Head (P : Castle.Colony.Bed_View) return Vec3 is
      Dx : constant Float := P.Feet.X - P.Toward.X;
      Dy : constant Float := P.Feet.Y - P.Toward.Y;
      L  : constant Float := Sqrt (Dx * Dx + Dy * Dy);
   begin
      return (if L > 0.01 then (Dx / L, Dy / L, 0.0) else (1.0, 0.0, 0.0));
   end Toward_Head;

   Cloth_Near_M : constant := 40.0;   --  a cloak further than this from the eye hangs straight, not stepped

   procedure Show_Cloths is
      use Castle.Colony;
      use Castle.Cloth;
      Dt  : constant Float := Step_Seconds;
      Eye : constant Vec3 := Castle.Camera.Eye (Cam);
   begin
      for I in 1 .. Members loop
         if Serf_Of (I) > 0 and then not Dead (I) then
            declare
               S  : constant Positive := Serf_Of (I);
               F  : constant Castle.Poses.Frames := Castle.Serfs.Frames_Of (S);
               K  : constant Float := Castle.Serfs.Height_Of (S) / 1.7;
               P  : constant Bed_View := Sleeping_Place (I);
               --  (down, and still: laid over a body still lying down it falls beside it, and over one still
               --  easing into its place, as one does into its bed in a hovel when a save is loaded, it is lain on)
               Asleep : constant Boolean :=
                 Doing (I) = Sleeping and then Castle.Serfs.Lies (S) > 0.97
                 and then (Cloak_State (I) = Over or else Cloak_Still (I) >= Still_Frames);
               Want : constant Cloak_Is :=
                 (if Asleep then Over elsif not P.Made or else Season_Winter then Worn else Off);
               Sl : constant Vec3 := F (Castle.Bodies.Upper_Arm_L).O;
               Sr : constant Vec3 := F (Castle.Bodies.Upper_Arm_R).O;
               Fw : constant Vec3 := F (Castle.Bodies.Chest).Y;
               Fl : constant Float := Sqrt (Fw.X * Fw.X + Fw.Y * Fw.Y);
               Back : constant Vec3 := (if Fl > 1.0e-3 then (-Fw.X / Fl, -Fw.Y / Fl, 0.0) else (0.0, 0.0, 0.0));
               Top  : Row_Points;
               C    : Cloth_Id renames Cloak_Cloth (I);
               --  the body, as capsules: the trunk, the hips, the head, the limbs
               Hips : constant Vec3 := F (Castle.Bodies.Pelvis).O - F (Castle.Bodies.Pelvis).Z * (0.08 * K);
               --  and what it carries on its back all day, a gatherer's basket or a porter's sack (boxes of
               --  its chest, Castle.Bodies): the cloak hangs over it, not through it
               Packed : constant Boolean :=
                 Castle.Bodies."=" (Body_Job (Job_Shown (I)), Castle.Bodies.Gatherer)
                 or else Castle.Bodies."=" (Body_Job (Job_Shown (I)), Castle.Bodies.Porter);
               Up_C   : constant Vec3 := Normalize (F (Castle.Bodies.Chest).Z);
               Side_C : constant Vec3 := Normalize (F (Castle.Bodies.Chest).X);
               --  (how far behind the chest's middle the pack's own middle and its far face are: a basket is
               --  four pixels deep, a sack three, each half a pixel off the back, and a pixel further off over
               --  winter clothes: Castle.Bodies, "Gear on the back")
               Basket   : constant Boolean := Castle.Bodies."=" (Body_Job (Job_Shown (I)), Castle.Bodies.Gatherer);
               Pack_Mid : constant Float :=
                 (if Basket then 0.225 else 0.20) + (if Winter_Shown (I) then 0.05 else 0.0);
               Pack_Far : constant Float :=
                 (if Basket then 0.325 else 0.275) + (if Winter_Shown (I) then 0.05 else 0.0);
               Pack   : constant Vec3 :=
                 (if Packed
                  then (Sl + Sr) * 0.5 - Up_C * (0.13 * K) - Normalize (F (Castle.Bodies.Chest).Y) * (Pack_Mid * K)
                  else F (Castle.Bodies.Chest).O);
               Caps : constant Capsules :=
                 [(F (Castle.Bodies.Chest).O, F (Castle.Bodies.Pelvis).O, 0.15 * K),
                  (Pack - Side_C * (if Packed then 0.06 * K else 0.0), Pack + Side_C * (if Packed then 0.06 * K else 0.0),
                   (if Packed then 0.14 * K else 0.0)),    --  (its far edges are 0.16 from its middle)
                  (Hips, Hips, 0.15 * K),
                  (F (Castle.Bodies.Head).O + F (Castle.Bodies.Head).Z * (0.1 * K),
                   F (Castle.Bodies.Head).O + F (Castle.Bodies.Head).Z * (0.1 * K), 0.11 * K),
                  (F (Castle.Bodies.Thigh_L).O, F (Castle.Bodies.Shin_L).O, 0.08 * K),
                  (F (Castle.Bodies.Thigh_R).O, F (Castle.Bodies.Shin_R).O, 0.08 * K),
                  (F (Castle.Bodies.Shin_L).O, F (Castle.Bodies.Foot_L).O, 0.06 * K),
                  (F (Castle.Bodies.Shin_R).O, F (Castle.Bodies.Foot_R).O, 0.06 * K),
                  (F (Castle.Bodies.Upper_Arm_L).O, F (Castle.Bodies.Forearm_L).O, 0.055 * K),
                  (F (Castle.Bodies.Upper_Arm_R).O, F (Castle.Bodies.Forearm_R).O, 0.055 * K)];
               --  the ground it falls to: under its wearer, or under the middle of it (on a bed: the bed's top)
               Bed_Ah : constant Vec3 := Toward_Head (P);
               Bed_C  : constant Vec3 := P.Feet + Bed_Ah * 1.05;
               Mid_P  : constant Vec3 := (if C > 0 and then Cloak_State (I) /= Not_Yet then Point (C, 3, 4) else Bed_C);
               Ground : constant Float :=
                 (if Want = Worn then Castle.Serfs.Where (S).Z
                  else Castle.Serfs.Ground_At (Mid_P.X, Mid_P.Y, Mid_P.Z)
                       + (if P.Made and then Sqrt ((Mid_P.X - Bed_C.X) ** 2 + (Mid_P.Y - Bed_C.Y) ** 2) < 1.1
                          then 0.07 else 0.0));
               --  laid flat on its bed, from the head end down
               procedure On_Bed is
                  Ac : constant Vec3 := (-Bed_Ah.Y, Bed_Ah.X, 0.0);
               begin
                  Lay (C, Bed_C + (0.0, 0.0, 0.15) + Bed_Ah * (0.5 * K) - Ac * (0.4 * K), Ac * (0.8 * K), Bed_Ah * (-1.0 * K));
               end On_Bed;
               --  laid flat over where it sleeps, a little above, from the head end down toward its feet
               procedure Over_Sleeper is
                  Head : constant Vec3 := F (Castle.Bodies.Head).O;
                  Mid  : constant Vec3 := Hips + (Head - Hips) * 0.3;
                  Dx   : constant Float := Hips.X - Head.X;
                  Dy   : constant Float := Hips.Y - Head.Y;
                  Dl   : constant Float := Float'Max (1.0e-3, Sqrt (Dx * Dx + Dy * Dy));
                  Dn   : constant Vec3 := (Dx / Dl, Dy / Dl, 0.0);
                  Ac   : constant Vec3 := (-Dn.Y, Dn.X, 0.0);
               begin
                  Lay (C, Mid + (0.0, 0.0, 0.45 * K) - Dn * (0.4 * K) - Ac * (0.4 * K), Ac * (0.8 * K), Dn * (1.0 * K));
               end Over_Sleeper;
            begin
               for T in 1 .. Nu loop
                  declare
                     U : constant Float := Float (T - 1) / Float (Nu - 1);
                  begin
                     --  (over a pack it is thrown round the pack's far edge, by the chest's own back and
                     --  up: the pack leans with its bearer)
                     Top (T) :=
                       (if Packed
                        then Sl + (Sr - Sl) * U
                             - Normalize (F (Castle.Bodies.Chest).Y)
                               * ((0.07 + (Pack_Far - 0.04) * Sin (Ada.Numerics.Pi * U)) * K)
                             + Up_C * (0.04 * K)
                        else Sl + (Sr - Sl) * U
                             + Back * ((0.07 + 0.06 * Sin (Ada.Numerics.Pi * U)) * K) + (0.0, 0.0, 0.03 * K));
                  end;
               end loop;
               if C = 0 then
                  C := New_Cloth (0.8 * K, 1.0 * K);
                  Cloak_State (I) := Not_Yet;
               end if;
               if C > 0 then
                  if Want /= Cloak_State (I) then
                     case Want is
                        when Worn =>
                           Hang (C, Top, (0.0, 0.0, -1.0));
                        when Over =>
                           Over_Sleeper;
                           Cloak_Laid (I) := Hips;
                        when Off =>
                           if Cloak_State (I) = Not_Yet then
                              On_Bed;                          --  (first seen off: on its bed)
                           else
                              Unpin (C);                       --  taken off, or left as it rises: it falls
                              Wake (C);
                           end if;
                        when Not_Yet =>
                           null;
                     end case;
                     Cloak_State (I) := Want;
                  elsif Want = Over and then Cloak_Still (I) >= Still_Frames
                    and then Sqrt ((Hips.X - Cloak_Laid (I).X) ** 2 + (Hips.Y - Cloak_Laid (I).Y) ** 2) > 0.2
                  then
                     Over_Sleeper;                             --  (its sleeper has moved from under it: laid again)
                     Cloak_Laid (I) := Hips;
                  elsif Want = Worn then
                     if Sqrt ((Top (3).X - Cloak_Pin (I).X) ** 2 + (Top (3).Y - Cloak_Pin (I).Y) ** 2) > 0.8
                       or else Sqrt ((Top (3).X - Eye.X) ** 2 + (Top (3).Y - Eye.Y) ** 2) > Cloth_Near_M
                     then
                        Hang (C, Top, (0.0, 0.0, -1.0));       --  (a jump: put on again; far off: hung straight)
                     else
                        Pin (C, Top);
                     end if;
                  end if;
                  Cloak_Pin (I) := Top (3);
                  if Dt > 0.0 then
                     Cloak_Still (I) :=
                       (if Sqrt ((Hips.X - Cloak_Hips (I).X) ** 2 + (Hips.Y - Cloak_Hips (I).Y) ** 2
                                 + (Hips.Z - Cloak_Hips (I).Z) ** 2) < 0.1 * Dt
                        then Natural'Min (Cloak_Still (I) + 1, Still_Frames) else 0);
                  end if;
                  Cloak_Hips (I) := Hips;
                  if not (Want = Worn and then Sqrt ((Top (3).X - Eye.X) ** 2 + (Top (3).Y - Eye.Y) ** 2) > Cloth_Near_M)
                  then
                     Step (C, Dt, (if Want = Off then Capsules'(1 .. 0 => (A => (0.0, 0.0, 0.0), B => (0.0, 0.0, 0.0), R => 0.0))
                                   else Caps), Ground, Stick => Want = Over);
                  end if;
                  Castle.Props.Put_Cloth (C, Castle.Serfs.Cloak_Of (S));
               end if;
            end;
         end if;
      end loop;
   end Show_Cloths;

   --  Roofs cleared on the camera's ray (Castle.Cutaway): every house with
   --  thatch on it, by its walls' corners and its ridge; drawn time, so a
   --  recording repeats.
   Point_Has : Boolean := False;                --  the pointer's ray landed on something a frame ago,
   Point_To  : Vec3 := (0.0, 0.0, 0.0);         --  there (and a little on); kept while the pointer is on the interface

   procedure Follow_Roofs is
      use Castle.Colony;
      Roofs : Castle.Cutaway.Roof_List (1 .. House_Count);
      N     : Natural := 0;
   begin
      for K in 1 .. House_Count loop
         declare
            V : constant House_View := House_At (K);
         begin
            if V.Phase in Roofing | Trimming | Standing then
               N := N + 1;
               Roofs (N) := Castle.Cutaway.Of_Corners (K, V.Corner (1), V.Corner (2), V.Corner (3), V.Corner (4),
                                                       V.Top_Z);
            end if;
         end;
      end loop;
      Castle.Cutaway.Follow (Castle.Camera.Eye (Cam), (Cam.X, Cam.Y, Cam.Z), Roofs (1 .. N), Step_Seconds,
                             Pointing => Point_Has, Pointed => Point_To);
   end Follow_Roofs;

   procedure Show_Cloaks is
      use Castle.Colony;
   begin
      if Cloth_On then
         Show_Cloths;
         return;
      end if;
      for I in 1 .. Members loop
         if Serf_Of (I) > 0 and then not Dead (I) then
            declare
               S   : constant Positive := Serf_Of (I);
               Col : constant Castle.Bodies.RGB := Castle.Serfs.Cloak_Of (S);
            begin
               if Doing (I) = Sleeping and then Castle.Serfs.Lies (S) > 0.6 then
                  Spread_Cloak (S);
               elsif not Season_Winter then
                  declare
                     P  : constant Bed_View := Sleeping_Place (I);
                     Dx : constant Float := P.Toward.X - P.Feet.X;
                     Dy : constant Float := P.Toward.Y - P.Feet.Y;
                     L  : constant Float := Sqrt (Dx * Dx + Dy * Dy);
                     Sd : constant Float := (if I mod 2 = 0 then 0.62 else -0.62);
                  begin
                     if L > 0.01 then
                        Castle.Props.Put (Castle.Props.Cloak_Folded (Col),
                                          (P.Feet.X - 1.5 * Dx / L - Sd * Dy / L, P.Feet.Y - 1.5 * Dy / L + Sd * Dx / L,
                                           P.Feet.Z),
                                          Arctan (Dy, Dx) + 0.35 * Sd);
                     end if;
                  end;
               end if;
            end;
         end if;
      end loop;
   end Show_Cloaks;

   procedure Show_Member_Routes is
      use Castle.Colony;
      Lift : constant Vec3 := (0.0, 0.0, 0.08);
      Palette_C : constant array (0 .. 5) of Castle.Marks.Colour :=
        [(1.0, 0.85, 0.3, 0.75), (0.45, 0.85, 1.0, 0.75), (0.75, 1.0, 0.45, 0.75),
         (1.0, 0.6, 0.85, 0.75), (1.0, 1.0, 1.0, 0.7), (0.7, 0.6, 1.0, 0.75)];
   begin
      for I in 1 .. Members loop
         declare
            R : constant Route_View := Route_Of (I);
            L : constant Positive := Leg_Of (I);
            C : constant Castle.Marks.Colour := Palette_C (I mod Palette_C'Length);
            W : constant Vec3 := Where (I);
         begin
            if Doing (I) = Walking and then R.N >= 2 and then L < R.N then
               Castle.Marks.Strip ((W.X, W.Y, R.Pts (L).P.Z) + Lift,
                                   (R.Pts (L + 1).P.X, R.Pts (L + 1).P.Y, R.Pts (L).P.Z) + Lift, 0.12, C);
               for K in L + 1 .. R.N - 1 loop
                  Castle.Marks.Strip (R.Pts (K).P + Lift, (R.Pts (K + 1).P.X, R.Pts (K + 1).P.Y, R.Pts (K).P.Z) + Lift,
                                      0.12, C);
               end loop;
            end if;
         end;
      end loop;
   end Show_Member_Routes;

   --  What a click will do in the colony tools: the path from its last point
   --  to the cursor, the stockpile from its first corner, the stake's spot.
   procedure Show_Tool_Preview is
      P : Vec3;
      Lay  : constant Castle.Marks.Colour := (0.95, 0.85, 0.5, 0.55);
      Zone : constant Castle.Marks.Colour := (0.95, 0.85, 0.55, 0.6);
   begin
      if Tools.Mode = Castle.HUD.Edit or else not Cursor_Hit.Found or else Castle.UI.Wants_Mouse
        or else Castle.HUD.Menu_Open
      then
         return;
      end if;
      P := Ground_Point (Cursor_Hit) + (0.0, 0.0, 0.06);
      case Tools.Mode is
         when Castle.HUD.Stake =>
            Castle.Marks.Strip (P + (-0.4, 0.0, 0.0), P + (0.4, 0.0, 0.0), 0.1, Zone);
            Castle.Marks.Strip (P + (0.0, -0.4, 0.0), P + (0.0, 0.4, 0.0), 0.1, Zone);
         when Castle.HUD.Path =>
            if Tools.Path_Started then
               Castle.Zone_Marks.Show_Path_Line (Tools.Path_From, Ground_Point (Cursor_Hit), Lay);
            else
               Castle.Marks.Strip (P + (-0.5, 0.0, 0.0), P + (0.5, 0.0, 0.0), 0.1, Lay);
            end if;
         when Castle.HUD.Stockpile =>
            --  the lot as it would be taken: turned to its path, drawn out to
            --  it, filled as far as it would fill (or, refused, its outline)
            if Tools.Zone_Started then
               declare
                  Plan : constant Castle.Colony.Lot_Plan :=
                    Castle.Colony.Plan_Stockpile (Tools.Zone_From.X, Tools.Zone_From.Y, P.X, P.Y);
               begin
                  if Plan.Ok then
                     Castle.Zone_Marks.Show_Plan (Castle.Zone_Marks.Planned);
                  else
                     Castle.Zone_Marks.Show_Lot (Plan.Corner, P.Z, Castle.Zone_Marks.Refused_C);
                  end if;
               end;
            else
               Castle.Marks.Strip (P + (-0.5, 0.0, 0.0), P + (0.5, 0.0, 0.0), 0.1, Zone);
               Castle.Marks.Strip (P + (0.0, -0.5, 0.0), P + (0.0, 0.5, 0.0), 0.1, Zone);
            end if;
         when Castle.HUD.Housing =>
            --  the ground it would take, as a stockpile's is shown
            if Tools.Zone_Started then
               declare
                  Plan : constant Castle.Colony.Lot_Plan :=
                    Castle.Colony.Plan_Housing (Tools.Zone_From.X, Tools.Zone_From.Y, P.X, P.Y, Count => False);
               begin
                  if Plan.Ok then
                     Castle.Zone_Marks.Show_Plan (Castle.Zone_Marks.Planned);
                  else
                     Castle.Zone_Marks.Show_Lot (Plan.Corner, P.Z, Castle.Zone_Marks.Refused_C);
                  end if;
               end;
            else
               Castle.Marks.Strip (P + (-0.5, 0.0, 0.0), P + (0.5, 0.0, 0.0), 0.1, Zone);
               Castle.Marks.Strip (P + (0.0, -0.5, 0.0), P + (0.0, 0.5, 0.0), 0.1, Zone);
            end if;
         when Castle.HUD.Camp =>
            declare
               Plan : constant Castle.Colony.Lot_Plan := Castle.Colony.Plan_Camp (Ground_Point (Cursor_Hit));
            begin
               if Plan.Ok then
                  Castle.Zone_Marks.Show_Plan (Castle.Zone_Marks.Planned);
               elsif not Castle.Colony.Has_Camp then
                  Castle.Zone_Marks.Show_Lot
                    ([P + (-3.5, -3.5, 0.0), P + (3.5, -3.5, 0.0), P + (3.5, 3.5, 0.0), P + (-3.5, 3.5, 0.0)], P.Z,
                     Castle.Zone_Marks.Refused_C);
               end if;
            end;
            Castle.Marks.Strip (P + (-0.3, 0.0, 0.0), P + (0.3, 0.0, 0.0), 0.1, Zone);
            Castle.Marks.Strip (P + (0.0, -0.3, 0.0), P + (0.0, 0.3, 0.0), 0.1, Zone);
         when Castle.HUD.Edit =>
            null;
      end case;
   end Show_Tool_Preview;

   --  --pointer: "FRAME:command a b, FRAME:command, ..." into Script.
   procedure Parse_Script (S : String) is
      use Ada.Strings;
      use Ada.Strings.Fixed;
      From : Positive := S'First;

      procedure One (Item : String) is
         Colon : constant Natural := Index (Item, ":");
      begin
         if Trim (Item, Both) = "" then
            return;
         end if;
         if Colon = 0 or else Script_N = Script'Last then
            raise Constraint_Error with "--pointer: FRAME:command (at most" & Script'Last'Image & "), not " & Item;
         end if;
         declare
            Rest  : constant String := Trim (Item (Colon + 1 .. Item'Last), Both) & " ";
            Words : array (1 .. 3) of Unbounded_String;
            N     : Natural := 0;
            Start : Positive := Rest'First;
            E     : Script_Event;
         begin
            for K in Rest'Range loop
               if Rest (K) = ' ' then
                  if K > Start and then N < 3 then
                     N := N + 1;
                     Words (N) := To_Unbounded_String (Rest (Start .. K - 1));
                  end if;
                  Start := K + 1;
               end if;
            end loop;
            E.Frame := Natural'Value (Trim (Item (Item'First .. Colon - 1), Both));
            declare
               C : constant String := To_String (Words (1));
            begin
               E.Kind := (if C = "move" then Move elsif C = "rel" then Rel elsif C = "member" then To_Member
                          elsif C = "deer" then To_Deer elsif C = "ground" then To_Ground
                          elsif C = "click" then Click elsif C = "rclick" then RClick
                          elsif C = "wheel" then Wheel elsif C = "esc" then Esc
                          else raise Constraint_Error with "--pointer: no command " & C);
            end;
            E.A := (if N >= 2 then Float'Value (To_String (Words (2))) else 0.0);
            E.B := (if N >= 3 then Float'Value (To_String (Words (3))) else 0.0);
            Script_N := Script_N + 1;
            Script (Script_N) := E;
         end;
      end One;
   begin
      for K in S'Range loop
         if S (K) = ',' then
            One (S (From .. K - 1));
            From := K + 1;
         end if;
      end loop;
      if From <= S'Last then
         One (S (From .. S'Last));
      end if;
   end Parse_Script;

   procedure Parse is
      I : Positive := 1;
      function Arg (K : Natural) return String is (Argument (I + K));
   begin
      while I <= Argument_Count loop
         if Castle.Scenario.Parse (Scn, I) then
            null;                                  --  the colony's own options
         elsif Arg (0) = "--seed" then
            Seed := U64'Value (Arg (1)); I := I + 2;
         elsif Arg (0) = "--at" then
            Start_X := Float'Value (Arg (1)); Start_Y := Float'Value (Arg (2)); I := I + 3;
            At_Set := True;
         elsif Arg (0) = "--view" then
            View_M := Float'Value (Arg (1)); I := I + 2;
         elsif Arg (0) = "--size" then
            Width := Positive'Value (Arg (1)); Height := Positive'Value (Arg (2)); I := I + 3;
         elsif Arg (0) = "--workers" then
            Workers := Positive'Value (Arg (1)); I := I + 2;
         elsif Arg (0) = "--frames" then
            Frames := Natural'Value (Arg (1)); I := I + 2;
         elsif Arg (0) = "--shot" then
            Shot := To_Unbounded_String (Arg (1)); I := I + 2;
         elsif Arg (0) = "--cam" then
            Cam_Set := True;
            Cam_Yaw := Float'Value (Arg (1));
            Cam_Pitch := Float'Value (Arg (2));
            Cam_Dist := Float'Value (Arg (3));
            I := I + 4;
         elsif Arg (0) = "--pan" then
            Pan_X := Float'Value (Arg (1)); Pan_Y := Float'Value (Arg (2)); I := I + 3;
         elsif Arg (0) = "--pan-back" then      --  with --pan: there, and when that view has filled, back again
            Pan_Back := True; I := I + 1;
         elsif Arg (0) = "--hud" then
            --  comma list: help, survey, debug, none
            declare
               L : constant String := Arg (1);
               function Has (Name : String) return Boolean is
               begin
                  for K in L'First .. L'Last - Name'Length + 1 loop
                     if L (K .. K + Name'Length - 1) = Name then
                        return True;
                     end if;
                  end loop;
                  return False;
               end Has;
            begin
               Show.Help := Has ("help");
               Show.Survey := Has ("survey");
               Show.Debug := Has ("debug");
               Show.Visible := not Has ("none");
               Show.Band := not Has ("noband");
               Tools.Place := Has ("place");   --  start in place mode
               Tools.Tab := (if Has ("stores") then Castle.HUD.Stores_Tab elsif Has ("camp") then Castle.HUD.Camp_Tab
                             elsif Has ("orders") then Castle.HUD.Orders_Tab
                             elsif Has ("skills") then Castle.HUD.Skills_Tab else Castle.HUD.People_Tab);
            end;
            I := I + 2;
         elsif Arg (0) = "--pointer" then
            Parse_Script (Arg (1)); I := I + 2;
         elsif Arg (0) = "--lineup" then
            Lineup_N := Natural'Value (Arg (1)); I := I + 2;
         elsif Arg (0) = "--lineup-turn" then
            Lineup_Turn := Float'Value (Arg (1)); I := I + 2;
         elsif Arg (0) = "--lineup-does" then
            --  stand, walk, pick, put_down, chop, sneak, aim, eat, lie, stir, sit_eat
            Lineup_Does := Castle.Serfs.Motion_Kind'Value (Arg (1)); Lineup_Posed := True; I := I + 2;
         elsif Arg (0) = "--walk" then
            if Walk_N < Walks'Last (1) then
               Walk_N := Walk_N + 1;
               for K in 1 .. 4 loop
                  Walks (Walk_N, K) := Float'Value (Argument (I + K));
               end loop;
            end if;
            I := I + 5;
         elsif Arg (0) = "--deer" then
            Deer_N := Natural'Value (Arg (1)); I := I + 2;
         elsif Arg (0) = "--deer-walk" then
            if Deer_Walk_N < Deer_Walks'Last (1) then
               Deer_Walk_N := Deer_Walk_N + 1;
               for K in 1 .. 5 loop
                  Deer_Walks (Deer_Walk_N, K) := Float'Value (Argument (I + K));
               end loop;
            end if;
            I := I + 6;
         elsif Arg (0) = "--follow-deer" then
            Follow_Deer := True; I := I + 1;
         elsif Arg (0) = "--follow" then
            Follow := True; I := I + 1;
         elsif Arg (0) = "--winter" then
            Force_Winter := True; I := I + 1;
         elsif Arg (0) = "--paths" then
            Show_Routes := True; I := I + 1;
         elsif Arg (0) = "--navmap" then
            Show_Map := True; I := I + 1;
         elsif Arg (0) = "--wellmap" then
            Show_Wells := True; I := I + 1;
         elsif Arg (0) = "--float" then
            Float_Window := True; I := I + 1;
         elsif Arg (0) = "--speed" then
            Tools.Speed := Natural'Min (240, Natural'Value (Arg (1))); I := I + 2;   --  the panel goes to 3
         elsif Arg (0) = "--log-hours" then
            Log_Hours := Float'Value (Arg (1)); I := I + 2;
         elsif Arg (0) = "--record" then
            Record_Dir := To_Unbounded_String (Arg (1));
            Record_N := Natural'Value (Arg (2));
            Ada.Directories.Create_Path (Arg (1));   --  made if it isn't there
            I := I + 3;
         elsif Arg (0) = "--uiscale" then
            UI_Scale := Float'Value (Arg (1)); UI_Given := True; I := I + 2;
         elsif Arg (0) = "--settings" then
            Settings_Path := To_Unbounded_String (Arg (1)); Settings_Given := True; I := I + 2;
         elsif Arg (0) = "--mouse" then
            Mouse_Set := True;
            Mouse_PX := Float'Value (Arg (1));
            Mouse_PY := Float'Value (Arg (2));
            I := I + 3;
         elsif Arg (0) = "--noshadows" then
            Castle.Render.Shadows := False; I := I + 1;
         elsif Arg (0) = "--loadorder" then
            Castle.Render.Near_First := False; I := I + 1;
         elsif Arg (0) = "--noreflect" then
            Castle.Render.Reflections := False; I := I + 1;
         elsif Arg (0) = "--flatclouds" then
            Castle.Render.Volumetric := False; I := I + 1;
         elsif Arg (0) = "--hitch" then
            Hitch_Ms := Float'Value (Arg (1)); I := I + 2;
         elsif Arg (0) = "--lights" then
            Test_Lights := Natural'Value (Arg (1)); I := I + 2;
         elsif Arg (0) = "--moon" then
            Forced_Moon := Float'Value (Arg (1)); I := I + 2;
         elsif Arg (0) = "--nostars" then
            Castle.Render.Stars := False; I := I + 1;
         elsif Arg (0) = "--nowet" then
            Castle.Render.Wetness := False; I := I + 1;
         elsif Arg (0) = "--wet" then
            Forced_Wet := Float'Value (Arg (1)); I := I + 2;
         elsif Arg (0) = "--nomist" then
            Castle.Render.Mists := False; I := I + 1;
         elsif Arg (0) = "--mist" then
            Forced_Mist := Float'Value (Arg (1)); I := I + 2;
         elsif Arg (0) = "--clouds" then
            Forced := To_Unbounded_String ("cover:" & Arg (1)); I := I + 2;
         elsif Arg (0) = "--weather" then
            Forced := To_Unbounded_String (Arg (1)); I := I + 2;
         elsif Arg (0) = "--snow" then
            Forced_Snow := Float'Value (Arg (1)); I := I + 2;
         elsif Arg (0) = "--day" then
            Start_Day := Float'Value (Arg (1)); I := I + 2;
         elsif Arg (0) = "--drawn-still" then
            Drawn_Still := True; I := I + 1;
         elsif Arg (0) = "--timescale" then
            Time_Scale := Long_Float'Value (Arg (1)); I := I + 2;
         elsif Arg (0) = "--time" then
            Start_Hour := Float'Value (Arg (1)); I := I + 2;
         elsif Arg (0) = "--msaa" then
            MSAA := Natural'Value (Arg (1)); I := I + 2;
         elsif Arg (0) = "--novsync" then
            Vsync := False; I := I + 1;
         elsif Arg (0) = "--no-whole-map" then
            Whole_Map := False; I := I + 1;
         elsif Arg (0) = "--no-lod" then
            Far_On := False; I := I + 1;
         elsif Arg (0) = "--no-far-shadows" then    --  (past the view's edge nothing casts or takes a shadow, as it was)
            Castle.Render.Far_Shadows := False; I := I + 1;
         elsif Arg (0) = "--no-ground-haze" then    --  (no haze on the ground and none at the map's rim)
            Castle.Render.Ground_Haze := False; I := I + 1;
         elsif Arg (0) = "--haze" then              --  (the ground haze this many times as thick; 1: as built)
            Castle.Render.Haze_Amount := Float'Value (Arg (1)); I := I + 2;
         elsif Arg (0) = "--rim" then               --  (the map's rim goes into the haze over this many metres; 0: not)
            Castle.Render.Haze_Rim_M := Float'Value (Arg (1)); I := I + 2;
         elsif Arg (0) = "--no-far-mirror" then     --  (far water mirrors the sky alone, as it did)
            Castle.Render.Far_Reflections := False; I := I + 1;
         elsif Arg (0) = "--no-round-boulders" then --  (a boulder's edges and corners in steps, as they were)
            Castle.Mesher.Round_Boulders := False; I := I + 1;
         elsif Arg (0) = "--no-low-horizon" then    --  (the sun and the moon cut off at eye level, as they were)
            Castle.Render.Low_Horizon := False; I := I + 1;
         elsif Arg (0) = "--no-floor" then          --  (holes in the land show the sky, as they did)
            Castle.Render.Ground_Floor := False; I := I + 1;
         elsif Arg (0) = "--far-wait" then
            Far_Wait := True; I := I + 1;
         elsif Arg (0) = "--no-far-cull" then
            Castle.Render.Far_Cull := False; I := I + 1;
         elsif Arg (0) = "--settle" then           --  a scripted run goes on for N frames after all is in
            Settle_Frames := Natural'Value (Arg (1)); I := I + 2;
         --  The far land (Castle.Far; `docs/systems/rendering.md`, "The far land")
         --  is out of the game: John, 2026-11-15, "remove the old far land,
         --  but keep the functionality just comment it out or something, just
         --  in case".  Its code is all still there and still compiled; these
         --  two lines are what brought it in, and bring it back:
         --  elsif Arg (0) = "--far" then
         --     Castle.Render.Far_Land := True; I := I + 1;
         elsif Arg (0) = "--no-far" then            --  (the default since 2026-11-15; taken still)
            Castle.Render.Far_Land := False; I := I + 1;
         elsif Arg (0) = "--hold-wait" then
            Hold_Wait := True; I := I + 1;
         elsif Arg (0) = "--mem" then
            Show_Mem := True; I := I + 1;
         elsif Arg (0) = "--save-at" then
            Save_At := Natural'Value (Arg (1)); Save_At_Path := To_Unbounded_String (Arg (2)); I := I + 3;
         elsif Arg (0) = "--load-at" then
            Load_At := Natural'Value (Arg (1)); Load_At_Path := To_Unbounded_String (Arg (2)); I := I + 3;
         elsif Arg (0) = "--probe-block" then
            if Probe_N < Probes'Last then
               Probe_N := Probe_N + 1;
               Probes (Probe_N) := (Float'Value (Arg (1)), Float'Value (Arg (2)), Float'Value (Arg (3)));
            end if;
            I := I + 4;
         elsif Arg (0) = "--load" then
            Load_Path := To_Unbounded_String (Arg (1)); I := I + 2;
         elsif Arg (0) = "--save" then
            Save_Path := To_Unbounded_String (Arg (1)); I := I + 2;
         elsif Arg (0) = "--fill" then
            for K in 1 .. 6 loop
               Fill_Box (K) := Float'Value (Argument (I + K));
            end loop;
            Fill_Set := True; I := I + 7;
         elsif Arg (0) = "--simticks" then
            Sim_Ticks := Natural'Value (Arg (1)); I := I + 2;
         elsif Arg (0) = "--no-cloth" then      --  the cloaks as they were: boxes on the body, laid over a sleeper
            Cloth_On := False; I := I + 1;
         elsif Arg (0) = "--full-summaries" then   --  each stack's ground summary kept whole, as it always was
            Castle.World_Blocks.Small_Summaries := False; I := I + 1;
         elsif Arg (0) = "--no-cutaway" then    --  no roof or wall cleared (the H key's third way, for a scripted run)
            Castle.Cutaway.Set_View (Castle.Cutaway.None); I := I + 1;
         elsif Arg (0) = "--all-roofs" then     --  every house cleared (the H key's second way)
            Castle.Cutaway.Set_View (Castle.Cutaway.Full); I := I + 1;
         elsif Arg (0) = "--nofalls" then      --  falls drawn as they were: a curtain on the face, a film on a slope
            Castle.Falls.Set_On (False); I := I + 1;
         elsif Arg (0) = "--throw" then        --  the share of the lip's simulated speed a fall's sheet leaves with
            Castle.Falls.Set_Throw (Float'Value (Arg (1))); I := I + 2;
         elsif Arg (0) = "--flowmap" then
            Flow_Debug := True; I := I + 1;
         elsif Arg (0) = "--watersteps" then
            Water_Steps := Natural'Value (Arg (1)); I := I + 2;
         elsif Arg (0) = "--late" then
            Dig_Late := True; I := I + 1;
         elsif Arg (0) = "--puddle" then
            --  X0 Y0 Z0 X1 Y1 Z1 depth (metres): water poured on the ground
            --  there once the view is loaded, reported like a dug box
            if Dig_Count < Dig_Boxes'Last (1) then
               Dig_Count := Dig_Count + 1;
               for K in 1 .. 6 loop
                  Dig_Boxes (Dig_Count, K) := Float'Value (Argument (I + K));
               end loop;
               Pour_Of (Dig_Count) := Float'Value (Argument (I + 7));
            end if;
            Dig_Set := True; I := I + 8;
         elsif Arg (0) = "--dig" then
            if Dig_Count < Dig_Boxes'Last (1) then
               Dig_Count := Dig_Count + 1;
               for K in 1 .. 6 loop
                  Dig_Boxes (Dig_Count, K) := Float'Value (Argument (I + K));
               end loop;
            end if;
            Dig_Set := True; I := I + 7;
         else
            raise Constraint_Error with "unknown option " & Arg (0);
         end if;
      end loop;
   end Parse;

   --  A scripted box's corners in blocks (from metres; the far corner inclusive).
   function Box (B, K : Positive) return Integer is
     (Integer (Dig_Boxes (B, K) * 4.0) - (if K > 3 then 1 else 0));

   --  Rebuild a loaded stack after edits, ahead of everything else.
   procedure Remesh (CX, CY : Integer) is
   begin
      if CX in 0 .. Chunks_XY - 1 and then CY in 0 .. Chunks_XY - 1
        and then States (CX, CY) = Loaded and then not Pending (CX, CY)
      then
         Pending (CX, CY) := True;
         Rebuilding := Rebuilding + 1;
         Castle.Streaming.Request (CX, CY, -1.0,
            Castle.Water.View_Of (CX, CY), Castle.Water.Version (CX, CY));
      end if;
   end Remesh;

   --  Dig out (M = Air) or fill (M solid) the block box X0..X1, Y0..Y1,
   --  Z0..Z1.  Digging takes whatever is there; filling only takes air,
   --  water and plants.  A 1 m brick wholly inside the box is one brick edit
   --  when digging, or when all of it would take the fill; the rest are
   --  block edits.  Force takes every block (the scripted dig at the start,
   --  before anything is loaded to look at).
   procedure Edit_Box (X0, Y0, Z0, X1, Y1, Z1 : Integer; M : Material; Force : Boolean := False) is
      Changed : Natural := 0;

      function Takes (X, Y, Z : Integer) return Boolean is
         Now : constant Material := Castle.World_Blocks.Block_At (X, Y, Z).Mat;
      begin
         return Force
           or else (M = Air and then Now /= Air)
           or else (M /= Air and then Class_Of (Now) /= Solid and then Now /= M);
      end Takes;

      --  (what is there now, this edit's blocks too: the column is noted as edited only below)
      function Mat_Now (X, Y, Z : Integer) return Material is
         B : Block;
      begin
         return (if Castle.Edits.Find (X, Y, Z, B) then B.Mat else Castle.World_Blocks.Block_At (X, Y, Z).Mat);
      end Mat_Now;

      Xa : constant Integer := Integer'Max (0, X0);
      Ya : constant Integer := Integer'Max (0, Y0);
      Za : constant Integer := Integer'Max (0, Z0);
      Xb : constant Integer := Integer'Min (Size_B - 1, X1);
      Yb : constant Integer := Integer'Min (Size_B - 1, Y1);
      Zb : constant Integer := Integer'Min (Height_B - 1, Z1);
   begin
      for Bi in Xa / 4 .. Xb / 4 loop
         for Bj in Ya / 4 .. Yb / 4 loop
            for Bk in Za / 4 .. Zb / 4 loop
               declare
                  Lx : constant Integer := Integer'Max (Xa, 4 * Bi);
                  Hx : constant Integer := Integer'Min (Xb, 4 * Bi + 3);
                  Ly : constant Integer := Integer'Max (Ya, 4 * Bj);
                  Hy : constant Integer := Integer'Min (Yb, 4 * Bj + 3);
                  Lz : constant Integer := Integer'Max (Za, 4 * Bk);
                  Hz : constant Integer := Integer'Min (Zb, 4 * Bk + 3);
                  Whole : constant Boolean :=
                    Hx - Lx = 3 and then Hy - Ly = 3 and then Hz - Lz = 3;
                  Taking : Natural := 0;
               begin
                  for X in Lx .. Hx loop
                     for Y in Ly .. Hy loop
                        for Z in Lz .. Hz loop
                           if Takes (X, Y, Z) then
                              Taking := Taking + 1;
                           end if;
                        end loop;
                     end loop;
                  end loop;
                  if Taking = 0 then
                     null;
                  elsif Whole and then (M = Air or else Taking = 64) then
                     Castle.Edits.Set_Brick (Lx, Ly, Lz, M);
                     Changed := Changed + Taking;
                  else
                     for X in Lx .. Hx loop
                        for Y in Ly .. Hy loop
                           for Z in Lz .. Hz loop
                              if Takes (X, Y, Z) then
                                 Castle.Edits.Set (X, Y, Z, (Mat => M, State => 0));
                                 Changed := Changed + 1;
                              end if;
                           end loop;
                        end loop;
                     end loop;
                  end if;
               end;
            end loop;
         end loop;
      end loop;
      --  what grew on ground dug out from under it goes with it (John,
      --  2026-11-13: "dirt having been removed, and the grass stays in the
      --  air"): a plant is never left over a hole
      if M = Air and then Zb + 1 < Height_B then
         for X in Xa .. Xb loop
            for Y in Ya .. Yb loop
               for Z in Zb + 1 .. Integer'Min (Height_B - 1, Zb + 3) loop
                  exit when Mat_Now (X, Y, Z) not in Tall_Grass | Wild_Grain | Wild_Vegetables
                    or else Mat_Now (X, Y, Z - 1) /= Air;
                  Castle.Edits.Set (X, Y, Z, Air_Block);
                  Changed := Changed + 1;
               end loop;
            end loop;
         end loop;
      end if;
      if Changed > 0 then
         for X in Xa .. Xb loop
            for Y in Ya .. Yb loop
               Castle.Water.About_To_Change (X, Y);  --  the water round it wakes, as it lay
               Castle.World_Blocks.Note_Edit (X, Y);
               Castle.World_Blocks.Reground (X, Y, Za, (if M = Air then Integer'Min (Height_B - 1, Zb + 3) else Zb));
               Castle.Water.Ground_Changed (X, Y);
            end loop;
         end loop;
         for CX in Integer'Max (0, Xa - 1) / Chunk_B .. Integer'Min (Size_B - 1, Xb + 1) / Chunk_B loop
            for CY in Integer'Max (0, Ya - 1) / Chunk_B .. Integer'Min (Size_B - 1, Yb + 1) / Chunk_B loop
               Remesh (CX, CY);
               Far_Touch (CX, CY);
            end loop;
         end loop;
      end if;
   end Edit_Box;

   --  The colony's own edits (a bush picked, a path laid, the stake raised):
   --  the bookkeeping the player's get in Edit_Box, a block at a time, and
   --  the stacks round them remeshed once a frame (Flush_Colony_Edits).
   procedure Note_Dirty (CX, CY : Integer) is
   begin
      for K in 1 .. Dirty_N loop
         if Dirty (K).CX = CX and then Dirty (K).CY = CY then
            return;
         end if;
      end loop;
      if Dirty_N < Dirty'Last then
         Dirty_N := Dirty_N + 1;
         Dirty (Dirty_N) := (CX, CY);
      end if;
   end Note_Dirty;

   procedure Colony_Write (Bx, By, Bz : Integer; B : Block) is
   begin
      if Bx not in 0 .. Size_B - 1 or else By not in 0 .. Size_B - 1 or else Bz not in 0 .. Height_B - 1 then
         return;
      end if;
      Castle.Edits.Set (Bx, By, Bz, B);
      Castle.Water.About_To_Change (Bx, By);
      Castle.World_Blocks.Note_Edit (Bx, By);
      Castle.World_Blocks.Reground (Bx, By, Bz, Bz);
      Castle.Water.Ground_Changed (Bx, By);
      for CX in Integer'Max (0, Bx - 1) / Chunk_B .. Integer'Min (Size_B - 1, Bx + 1) / Chunk_B loop
         for CY in Integer'Max (0, By - 1) / Chunk_B .. Integer'Min (Size_B - 1, By + 1) / Chunk_B loop
            Note_Dirty (CX, CY);
         end loop;
      end loop;
   end Colony_Write;

   procedure Flush_Colony_Edits is
   begin
      for K in 1 .. Dirty_N loop
         Remesh (Dirty (K).CX, Dirty (K).CY);
         Far_Touch (Dirty (K).CX, Dirty (K).CY);
      end loop;
      Dirty_N := 0;
   end Flush_Colony_Edits;

   --  Ask for every stack inside the view circle, let go of those that fell
   --  out of it, and upload finished meshes.
   --  Surface water (see Castle.Render): each loaded stack's open-sky
   --  water is drawn as surface cells over texels holding its levels.  A
   --  resting stack shows the generated water, with the level read from
   --  the 1 m surface so rivers slope smoothly instead of in block steps;
   --  a simulated stack covers every column (water may come anywhere) and
   --  its texels follow the simulation each tick, the shader blending
   --  between the last two.
   type Block_Access is access Castle.Render.Surface_Block;
   procedure Free_Block is new Ada.Unchecked_Deallocation (Castle.Render.Surface_Block, Block_Access);
   procedure Free_Quads is new Ada.Unchecked_Deallocation (Castle.Mesher.Quad_Array, Castle.Mesher.Quad_Access);
   package Mirror_Maps is new Ada.Containers.Ordered_Maps (Integer, Block_Access);
   Mirrors         : Mirror_Maps.Map;          --  what each moving stack last showed
   Last_Water_Tick : Time := Clock;

   function Stack_Key (CX, CY : Integer) return Integer is (CX * 4096 + CY);

   --  The generated water's level (rows) at a block column: the level
   --  source water rests at (Castle.Geology.Water_Level), so a stack drawn
   --  at rest and the same stack simulated lie at one height.
   function Wet_Level (Bx, By, Floor, Rows : Integer) return Float is
     (Castle.Geology.Water_Level (W, Bx, By, Floor, Rows));

   type Wet_Grid is array (0 .. 31, 0 .. 31) of Boolean;

   --  Which stacks are meshed with the second cells a fall's sheet is
   --  drawn with (Castle.Falls): those a sheet has stood over since they
   --  were loaded.  A stack is built again the first time one comes over
   --  it, once (a fall whose tip only reaches a stack on its pulses would
   --  otherwise have it built again on every one).
   type Air_Grid is array (0 .. Chunks_XY - 1, 0 .. Chunks_XY - 1) of Boolean with Pack;
   type Air_Grid_Access is access Air_Grid;
   Air_Wanted : constant Air_Grid_Access := new Air_Grid'[others => [others => False]];
   Air_Builds : Natural := 0;               --  stacks built again for it (reported by --frames runs)

   --  A stack's surface texels: the simulation's water if it is simulated,
   --  else the generated water (a lake column at its pool's level now).
   procedure Make_Texels (CX, CY : Integer; Summary : Castle.Water.Summary_Access;
                          Tex : out Castle.Render.Surface_Block; Wet : out Wet_Grid; Have : out Boolean)
   is
      use type Interfaces.Unsigned_8;
      use type Interfaces.Integer_16;
      use type Castle.Water.Summary_Access;
      Live : Castle.Water.Surface_Grid;
   begin
      Wet := (others => (others => False));
      Castle.Water.Surface (CX, CY, Live, Have);
      for X in 0 .. 31 loop
         for Y in 0 .. 31 loop
            declare
               Floor : Float := Float (Height_B);
               Level : Float := Float (Height_B);
            begin
               if Have then
                  Floor := Live (X, Y).Floor;
                  Level := Live (X, Y).Level;
                  Wet (X, Y) := Floor < Float (Height_B);
               elsif Summary /= null and then Summary (X, Y).N >= 1 then
                  declare
                     T : constant Castle.Water.Short_Stretch := Summary (X, Y).S (1);
                  begin
                     Floor := Float (T.Floor);
                     Level := (if T.Water > 0
                               then Wet_Level (CX * 32 + X, CY * 32 + Y, Integer (T.Floor), Integer (T.Water))
                               else Floor);

                     Wet (X, Y) := T.Water > 0;
                  end;
               end if;
               Tex (Y, X) := (Prev => Level, Cur => Level, Floor => Floor,
                              Air => Castle.Falls.Air (CX * 32 + X, CY * 32 + Y));
            end;
         end loop;
      end loop;
   end Make_Texels;

   procedure Show_Surface (CX, CY : Integer; M : in out Castle.Mesher.Mesh;
                           Summary : Castle.Water.Summary_Access)
   is
      use Castle.Render;
      use type Interfaces.Unsigned_32;
      use type Castle.Mesher.Quad_Access;
      Tex   : Surface_Block;
      Wet   : Wet_Grid;
      Have  : Boolean;
      Cells : Natural := 0;
      Sheet : Boolean;                     --  a fall's sheet stands over it: the second cells too
   begin
      Make_Texels (CX, CY, Summary, Tex, Wet, Have);
      if Castle.Falls.Over (CX, CY) then
         Air_Wanted (CX, CY) := True;
      end if;
      Sheet := Have and then Air_Wanted (CX, CY);
      for X in 0 .. 31 loop
         for Y in 0 .. 31 loop
            if Wet (X, Y) then
               Cells := Cells + 1;
            end if;
         end loop;
      end loop;
      Set_Surface (CX * 32, CY * 32, Tex);
      if Have and then Castle.Water.Is_Awake (CX, CY) then
         declare
            K : constant Integer := Stack_Key (CX, CY);
         begin
            if Mirrors.Contains (K) then
               Mirrors (K).all := Tex;
            else
               Mirrors.Insert (K, new Surface_Block'(Tex));
            end if;
         end;
      end if;
      if Cells > 0 then
         declare
            Old   : Castle.Mesher.Quad_Access := M.Water;
            N_Old : constant Natural := Castle.Mesher.Count (Old);
            --  (under a fall's sheet the columns get a second cell each,
            --  six faces: Castle.Falls)
            Q     : constant Castle.Mesher.Quad_Access :=
              new Castle.Mesher.Quad_Array (1 .. N_Old + Cells * (if Sheet then 11 else 5));
            I     : Natural := N_Old;
            Mat   : constant Interfaces.Unsigned_32 :=
              Interfaces.Unsigned_32 (Material'Pos (Castle.Blocks.Water));
         begin
            if Old /= null then
               Q (1 .. N_Old) := Old.all;
               Free_Quads (Old);
            end if;
            for X in 0 .. 31 loop
               for Y in 0 .. 31 loop
                  if Wet (X, Y) then
                     for Face in 0 .. 4 loop          --  four sides and the top
                        I := I + 1;
                        Q (I) := (W0 => Interfaces.Unsigned_32 (X)
                                        or Interfaces.Shift_Left (Interfaces.Unsigned_32 (Y), 5)
                                        or Interfaces.Shift_Left (Interfaces.Unsigned_32 (Face), 25)
                                        or 16#1000_0000#,
                                  W1 => Interfaces.Shift_Left (Mat, 8));
                     end loop;
                     if Sheet then
                        for Face in 0 .. 5 loop       --  the sheet: its sides, top and underside (z = 1)
                           I := I + 1;
                           Q (I) := (W0 => Interfaces.Unsigned_32 (X)
                                           or Interfaces.Shift_Left (Interfaces.Unsigned_32 (Y), 5)
                                           or Interfaces.Shift_Left (Interfaces.Unsigned_32'(1), 10)
                                           or Interfaces.Shift_Left (Interfaces.Unsigned_32 (Face), 25)
                                           or 16#1000_0000#,
                                     W1 => Interfaces.Shift_Left (Mat, 8));
                        end loop;
                     end if;
                  end if;
               end loop;
            end loop;
            M.Water := Q;
         end;
      end if;
   end Show_Surface;

   --  A loaded stack's texels again, at rest (its pool moved, or it dried).
   procedure Refresh_Texels (CX, CY : Integer) is
      Tex  : Castle.Render.Surface_Block;
      Wet  : Wet_Grid;
      Have : Boolean;
   begin
      if States (CX, CY) = Loaded and then not Mirrors.Contains (Stack_Key (CX, CY)) then
         Make_Texels (CX, CY, Castle.World_Blocks.Summary_Of (CX, CY), Tex, Wet, Have);
         Castle.Render.Set_Surface (CX * 32, CY * 32, Tex);
      end if;
   end Refresh_Texels;

   --  A loaded stack's texels written again whatever its water is doing: it
   --  has come back into the surface texture's window (Castle.Render, "a
   --  slot is its window stack's alone"), its slot having been another's or
   --  hidden while the camera was far off.  Awake, the texels of its last
   --  tick; at rest, its pool's.
   procedure Own_Texels (CX, CY : Integer) is
      K : constant Integer := Stack_Key (CX, CY);
   begin
      if Mirrors.Contains (K) then
         Castle.Render.Set_Surface (CX * 32, CY * 32, Mirrors.Element (K).all);
      else
         declare
            Tex  : Castle.Render.Surface_Block;
            Wet  : Wet_Grid;
            Have : Boolean;
         begin
            Make_Texels (CX, CY, Castle.World_Blocks.Summary_Of (CX, CY), Tex, Wet, Have);
            Castle.Render.Set_Surface (CX * 32, CY * 32, Tex);
         end;
      end if;
   end Own_Texels;

   --  Source water and drying: what a resting river column can give a step
   --  (its share of the discharge), and what a floor soaks up (mm a game
   --  hour: sand and gravel fast, soil steadily, clay barely, rock and
   --  anything laid not at all).
   function River_Supply (Bx, By : Integer) return Natural is
      Q : constant Float := Float'Max (0.36, Castle.Currents.Discharge (Bx / 4, By / 4));
      B : constant Float := Float'Max (1.5, Float'Min (24.0, 5.0 * Sqrt (Q)));
   begin
      --  Q / B m^2/s over a 0.25 m column face for 0.025 s, as depth on a
      --  0.0625 m^2 column, at 262,144 units a metre
      return Natural (Float'Min (1.0E6, Q / B * 26_214.0));
   end River_Supply;

   --  What an awake source column below its level gets back a step, at
   --  most: of a river a share of what it carries past (an eighth of the
   --  column's own flow), of a lake what stands behind it (first values).
   Lake_Refill : constant := 256;             --  units a step: 4 cm a second

   function Source_Refill (Bx, By : Integer) return Natural is
     (if Bx in 0 .. Size_B - 1 and then By in 0 .. Size_B - 1
        and then W.Kind (Castle.Fields.Idx (Bx / 4, By / 4)) in Castle.Maps.Lake
      then Lake_Refill else River_Supply (Bx, By) / 8);

   function Seep_Rate (Bx, By, Row : Integer) return Float is
      M : constant Material := Castle.World_Blocks.Block_At (Bx, By, Row).Mat;
   begin
      return (case M is
                 when Sand => 25.0,
                 when Gravel | Placer_Gravel => 40.0,
                 when Dirt | Grass => 8.0,
                 when Clay => 0.5,
                 when Sandstone => 2.0,
                 when Limestone => 0.5,
                 when Deep => 4.0,
                 when Crown | Tall_Grass | Wild_Grain | Wild_Vegetables | Berry_Bush | Bare_Bush => 15.0,
                 when others => 0.0);
   end Seep_Rate;

   Last_Dry : Castle.Climate.Game_Hours := 0.0;

   --  Once a game minute: the weather's evaporation (tuned for play: about
   --  2 mm an hour in warm sun, none in rain or frost, so a puddle on rock
   --  lasts a day or so and a stone cistern a season), frozen ground soaks
   --  nothing up.
   procedure Dry_Water is
      Hours : constant Float := Float (Game_Clock - Last_Dry);
   begin
      if Hours < 0.0 or else Hours > 24.0 then
         Last_Dry := Game_Clock;               --  the clock was set: start again from here
      elsif Hours >= 1.0 / 60.0 then
         declare
            Wx  : constant Castle.Climate.Weather := Castle.Climate.Weather_At (Seed, Game_Clock);
            T   : constant Float := Castle.Climate.Temperature_At (Wx, Castle.Fields.Sample (W.Height.all, Cam.X, Cam.Y));
            Ev  : constant Float :=
              (if T <= 0.0 then 0.0
               else 2.0 * Float'Min (1.5, T / 20.0) * (1.0 - 0.6 * Wx.Cloud_Cover) * (1.0 - Float'Min (1.0, Wx.Rain)));
         begin
            Castle.Water.Dry_Out (Hours, Ev, (if T <= 0.0 then 0.0 else 1.0));
            Last_Dry := Game_Clock;
         end;
         for R of Castle.Water.Take_Dried loop
            Refresh_Texels (R.CX, R.CY);
         end loop;
      end if;
   end Dry_Water;

   procedure Forget_Surface (CX, CY : Integer) is
      K : constant Integer := Stack_Key (CX, CY);
   begin
      if Mirrors.Contains (K) then
         declare
            B : Block_Access := Mirrors (K);
         begin
            Free_Block (B);
         end;
         Mirrors.Delete (K);
      end if;
   end Forget_Surface;

   --  After the simulation ticks: every moving stack's new levels (the
   --  last ones become the previous) and its currents; a stack that has
   --  come to rest is settled (previous = current) and its generated
   --  currents put back.
   procedure Follow_Surface is
      use Castle.Render;
      use type Castle.Fields.Field_Access;
      Seen  : Mirror_Maps.Map;
      Gen_E : constant Castle.Fields.Field_Access := Castle.Currents.East;
      Gen_N : constant Castle.Fields.Field_Access := Castle.Currents.North;
   begin
      for R of Castle.Water.Awake_List loop
         if States (R.CX, R.CY) = Loaded then
            declare
               Live : Castle.Water.Surface_Grid;
               Have : Boolean;
               K    : constant Integer := Stack_Key (R.CX, R.CY);
               Old  : constant Block_Access := (if Mirrors.Contains (K) then Mirrors (K) else null);
               Tex  : Surface_Block;
               Cur  : Current_Block := (others => (others => (others => 0.0)));
            begin
               Castle.Water.Surface (R.CX, R.CY, Live, Have);
               if Have then
                  for X in 0 .. 31 loop
                     for Y in 0 .. 31 loop
                        Tex (Y, X) := (Prev  => (if Old /= null then Old (Y, X).Cur else Live (X, Y).Level),
                                       Cur   => Live (X, Y).Level,
                                       Floor => Live (X, Y).Floor,
                                       Air   => Castle.Falls.Air (R.CX * 32 + X, R.CY * 32 + Y));
                        Cur (Y / 4, X / 4, 0) := Cur (Y / 4, X / 4, 0) + Live (X, Y).Vx / 16.0;
                        Cur (Y / 4, X / 4, 1) := Cur (Y / 4, X / 4, 1) + Live (X, Y).Vy / 16.0;
                        --  awake source water: what is simulated is what it
                        --  does besides running as the river runs
                        if Live (X, Y).Source and then Gen_E /= null then
                           declare
                              K : constant Castle.Fields.Cell_Range :=
                                Castle.Fields.Idx (R.CX * 8 + X / 4, R.CY * 8 + Y / 4);
                           begin
                              Cur (Y / 4, X / 4, 0) := Cur (Y / 4, X / 4, 0) + Gen_E (K) / 16.0;
                              Cur (Y / 4, X / 4, 1) := Cur (Y / 4, X / 4, 1) + Gen_N (K) / 16.0;
                           end;
                        end if;
                     end loop;
                  end loop;
                  Set_Surface (R.CX * 32, R.CY * 32, Tex);
                  Set_Currents (R.CX * 8, R.CY * 8, Cur);
                  if Old = null then
                     Mirrors.Insert (K, new Surface_Block'(Tex));
                  else
                     Old.all := Tex;
                  end if;
                  Seen.Insert (K, null);
               end if;
            end;
         end if;
      end loop;
      declare
         Rested : Mirror_Maps.Map;
      begin
         for C in Mirrors.Iterate loop
            if not Seen.Contains (Mirror_Maps.Key (C)) then
               Rested.Insert (Mirror_Maps.Key (C), Mirror_Maps.Element (C));
            end if;
         end loop;
         for C in Rested.Iterate loop
            declare
               K  : constant Integer := Mirror_Maps.Key (C);
               B  : constant Block_Access := Mirror_Maps.Element (C);
               CX : constant Integer := K / 4096;
               CY : constant Integer := K mod 4096;
            begin
               if States (CX, CY) = Loaded then
                  for X in 0 .. 31 loop
                     for Y in 0 .. 31 loop
                        B (Y, X).Prev := B (Y, X).Cur;
                        B (Y, X).Air := Castle.Falls.Air (CX * 32 + X, CY * 32 + Y);
                     end loop;
                  end loop;
                  Set_Surface (CX * 32, CY * 32, B.all);
                  --  (asleep with its flow established it is still running
                  --  water: its last currents stay)
                  if not Castle.Water.Is_Running (CX, CY) then
                     Reset_Currents (CX, CY);
                  end if;
               end if;
               Forget_Surface (CX, CY);
            end;
         end loop;
      end;
      --  The sheets of falls over stacks that are not moving themselves (a
      --  fall landing in water asleep; the last of a fall that has stopped).
      for R of Castle.Falls.Take_Changed loop
         if not Seen.Contains (Stack_Key (R.CX, R.CY)) then
            Refresh_Texels (R.CX, R.CY);
         end if;
         --  (a sheet over a stack built without the cells to draw it with)
         if States (R.CX, R.CY) = Loaded and then Castle.Falls.Over (R.CX, R.CY)
           and then not Air_Wanted (R.CX, R.CY)
         then
            Air_Wanted (R.CX, R.CY) := True;
            Air_Builds := Air_Builds + 1;
            Remesh (R.CX, R.CY);
         end if;
      end loop;
   end Follow_Surface;

   --  The colony's ground stays loaded wherever the camera goes: the band
   --  works there whether anyone is looking or not.  Stacks within Colony_R
   --  of the stake's (its work radius and a margin for the way round
   --  things) are asked for like the view's and not let go while there is a
   --  colony (two stacks of slack, like the view).
   --  (Its reach is its work radius as a rule, and wider while the band
   --  looks further afield for what its camp takes, or has a path to lay
   --  further out: Castle.Colony.Ground_Reach_M.)
   --  (The herds' ways are looked for only on ground this keeps:
   --  Castle.Herds.Dry_Reach_M.  colony_check has the sum; change the 3
   --  here and run it.)
   --  (The colony's own ground: the same stacks the runner brings in, so that
   --  the two keep one colony.  It was 3 more than the reach, and the colony
   --  read whatever else the camera had loaded.)
   Colony_R_Most : Integer := 0;            --  the most it has been: no stack once the colony's is let go
   function Colony_R return Integer is
   begin
      Colony_R_Most := Integer'Max (Colony_R_Most, Integer (Castle.Colony.Ground_Reach_M / 8.0) + 5);
      return Colony_R_Most;
   end Colony_R;

   function Stake_Stack return Coord is
     ((Integer (Float'Floor (Castle.Colony.Stake.X / 8.0)), Integer (Float'Floor (Castle.Colony.Stake.Y / 8.0))));

   function Colony_Holds (Cx, Cy : Integer) return Boolean is
     (Castle.Colony.Has_Stake
      and then (Cx - Stake_Stack.CX) ** 2 + (Cy - Stake_Stack.CY) ** 2 <= (Colony_R + 2) ** 2);

   --  Every stack of the colony's ground in (the colony waits for it, so a
   --  bush is never read as bare, or a way as shut, for want of its blocks).
   function Colony_Ground_Ready return Boolean is
      S : constant Coord := Stake_Stack;
   begin
      for Dy in -Colony_R .. Colony_R loop
         for Dx in -Colony_R .. Colony_R loop
            if Dx * Dx + Dy * Dy <= Colony_R * Colony_R
              and then S.CX + Dx in 0 .. Chunks_XY - 1 and then S.CY + Dy in 0 .. Chunks_XY - 1
              and then States (S.CX + Dx, S.CY + Dy) /= Loaded
            then
               return False;
            end if;
         end loop;
      end loop;
      return True;
   end Colony_Ground_Ready;

   procedure Stream is
      Fcx  : constant Integer := Integer (Float'Floor (Cam.X / 8.0));
      Fcy  : constant Integer := Integer (Float'Floor (Cam.Y / 8.0));
      R    : constant Integer := Integer (View_M / 8.0);
      Keep : constant Integer := (R + 2) ** 2;
      Res  : Castle.Streaming.Result_Access;
      Window_Moved : Boolean;
      Holds   : Natural := 0;                  --  results without a mesh taken this frame
      Hold_T0 : Time;
      Hold_Frame : Float := 0.0;               --  the main thread's milliseconds in holding, this frame

      --  (the debug build) Every loaded stack inside the surface texture's
      --  window holds its own slot of it.
      procedure Check_Surfaces is
      begin
         for I in 1 .. Active_N loop
            if States (Active (I).CX, Active (I).CY) = Loaded
              and then Castle.Render.In_Surface_Window (Active (I).CX, Active (I).CY)
              and then not Castle.Render.Owns_Surface (Active (I).CX, Active (I).CY)
            then
               raise Program_Error with "the water's surface: stack" & Active (I).CX'Image & Active (I).CY'Image
                 & " is loaded inside the window and its texels are not its own";
            end if;
         end loop;
      end Check_Surfaces;

      --  The stacks of the map in the order they are held: rings round the
      --  stack first looked at.
      procedure Order_Holds is
         N : Natural := 0;
         procedure Put (Dx, Dy : Integer) is
         begin
            if Fcx + Dx in 0 .. Chunks_XY - 1 and then Fcy + Dy in 0 .. Chunks_XY - 1 then
               N := N + 1;
               Hold_Order (N) := (Fcx + Dx, Fcy + Dy);
            end if;
         end Put;
      begin
         Hold_Order := new Coord_List;
         Put (0, 0);
         for Ring in 1 .. Chunks_XY - 1 loop
            for D in -Ring .. Ring loop                 --  the ring's two whole sides
               Put (D, -Ring);
               Put (D, Ring);
            end loop;
            for D in -Ring + 1 .. Ring - 1 loop         --  and what is left of the other two
               Put (-Ring, D);
               Put (Ring, D);
            end loop;
         end loop;
         pragma Assert (N = Hold_Order'Last);
      end Order_Holds;

      --  Ask for stacks that are not drawn and not held as they are now,
      --  without a mesh: up to Hold_Cap out at once.  The looking goes round
      --  the map for ever, fast while it finds any and slowly once a whole
      --  round has found none.
      procedure Hold_More is
         Total  : constant Natural := Chunks_XY * Chunks_XY;
         Budget : constant Natural := (if Hold_Since < Total then 4_096 else 256);
         Looked : Natural := 0;
      begin
         if Hold_Order = null then
            Order_Holds;
            Hold_Began := Clock;
         end if;
         while Holds_Out_N < Hold_Cap and then Looked < Budget loop
            Hold_At := Hold_At mod Total + 1;
            Looked := Looked + 1;
            Hold_Since := Natural'Min (Total, Hold_Since + 1);
            declare
               C : constant Coord := Hold_Order (Hold_At);
            begin
               if States (C.CX, C.CY) /= None then
                  if not Held (C.CX, C.CY) then
                     Hold_Since := 0;                  --  (the view's to bring in: not held yet)
                  end if;
               elsif not Hold_Out (C.CX, C.CY)
                 and then (not Held (C.CX, C.CY) or else Hold_Stale (C.CX, C.CY)
                           or else Held_Gen (C.CX, C.CY) /= Castle.Edits.Generation (C.CX, C.CY))
               then
                  Hold_Out (C.CX, C.CY) := True;
                  Holds_Out_N := Holds_Out_N + 1;
                  Hold_Since := 0;
                  Castle.Streaming.Request (C.CX, C.CY, 1.0E9 + Float (Hold_At),
                                            Castle.Water.View_Of (C.CX, C.CY), Castle.Water.Version (C.CX, C.CY),
                                            Mesh => False);
               elsif Hold_Out (C.CX, C.CY) then
                  Hold_Since := 0;
               end if;
            end;
         end loop;
         Hold_Whole := Hold_Since >= Total and then Holds_Out_N = 0;
         if Hold_Done < 0.0 and then Hold_Whole then
            Hold_Done := Float (To_Duration (Clock - Hold_Began));
         end if;
      end Hold_More;

      --  The blocks of a result for a stack that is not drawn (asked for
      --  without a mesh, or gone from the view while its mesh was made): kept
      --  if they are newer than what is held of it.  (A stack that is drawn
      --  has its own, kept by its mesh's results.)
      procedure Take_Blocks (R : Castle.Streaming.Result_Access) is
         T0 : constant Time := Clock;
      begin
         if Whole_Map and then States (R.CX, R.CY) = None
           and then (not Held (R.CX, R.CY) or else Hold_Stale (R.CX, R.CY) or else R.Gen > Held_Gen (R.CX, R.CY))
         then
            Castle.World_Blocks.Keep (R.CX, R.CY, R.Packed, R.Gen, R.Summary);
            Held_Gen (R.CX, R.CY) := R.Gen;
            Hold_Stale (R.CX, R.CY) := False;
            if not R.Meshed then
               Holds_Taken := Holds_Taken + 1;
               Hold_Ms := Hold_Ms + R.Millis;
            end if;
            Hold_Frame := Hold_Frame + Float (To_Duration (Clock - T0)) * 1000.0;
         end if;
      end Take_Blocks;

      --  The far view's tiles: those the workers have made taken in, those
      --  wanted asked for (the nearest first, the last level's before any
      --  other's), those out of their rings let go.
      procedure Far_Stream is
         use Castle.Lod;
         subtype Level is Castle.Lod.Level;
         R0    : constant Float := View_M;
         --  (how many the workers have in hand or waiting at once.  What the view
         --  asks goes before any of them in the workers' queue, so only a tile
         --  already begun keeps a mesh of the view waiting: 4 to 56 ms, a fifth
         --  of a second for the last level's)
         Cap   : constant Natural := Natural'Min (128, 4 * Workers);
         Now_S : Float;
         type Cand is record
            L, TX, TY : Integer := 0;
            Key       : Float := 0.0;
            Again     : Boolean := False;
         end record;
         Best  : array (1 .. 128) of Cand;
         Best_N  : Natural := 0;
         Missing : Boolean := False;
         Stale   : Boolean := False;       --  a tile that shows is to be made again for an edit, or is being

         procedure Offer (C : Cand) is
            Room : constant Integer := Cap - Far_Out;
            I    : Integer;
         begin
            if Room <= 0 then
               return;
            elsif Best_N < Room then
               Best_N := Best_N + 1;
            elsif C.Key >= Best (Best_N).Key then
               return;
            end if;
            I := Best_N;
            while I > 1 and then Best (I - 1).Key > C.Key loop
               Best (I) := Best (I - 1);
               I := I - 1;
            end loop;
            Best (I) := C;
         end Offer;
      begin
         if not Far_Started then
            Far_Began := Clock;
            Far_Started := True;
         end if;
         Now_S := Float (To_Duration (Clock - Far_Began));
         for K in 1 .. Far_Budget loop
            Castle.Streaming.Poll_Far (Res);
            exit when Res = null;
            Far_Out := Far_Out - 1;
            declare
               T : Far_Tile renames Far_Tiles (Res.Level, Res.CX, Res.CY);
            begin
               if T.State = Requested or else (T.State = Loaded and then T.Again) then
                  Castle.Render.Upload_Far (Res.Level, Res.CX, Res.CY, Res.M);
                  T.State := Loaded;
                  T.Again := False;
                  T.Built_At := Now_S;
                  Far_Made := Far_Made + 1;
                  Far_Ms := Far_Ms + Res.Millis;
               end if;
            end;
            Castle.Streaming.Free (Res);
         end loop;
         --  (every tile is looked at only when something can have changed: the
         --  focus has moved, a tile is missing or in hand, or a second has gone
         --  by, for those edited and waiting their turn)
         Far_Scan := Far_Scan + 1;
         if not (not Far_Whole or else Far_Scan - Far_Scanned >= 60
                 or else abs (Cam.X - Far_At_X) + abs (Cam.Y - Far_At_Y) > 2.0)
         then
            return;
         end if;
         Far_Scanned := Far_Scan;
         Far_At_X := Cam.X;
         Far_At_Y := Cam.Y;
         for L in Level loop
            declare
               Last  : constant Boolean := L = Level'Last;
               Side  : constant Float := Float (Tile_Stacks (L)) * 8.0;
               Outer : constant Float := R0 * 2.0 ** L;
               Inner : constant Float := R0 * 2.0 ** (Float (L - 1) - Float (Castle.Render.Far_Fade));
            begin
               for TY in 0 .. Tiles (L) - 1 loop
                  for TX in 0 .. Tiles (L) - 1 loop
                     declare
                        T   : Far_Tile renames Far_Tiles (L, TX, TY);
                        X0  : constant Float := Float (TX) * Side;
                        Y0  : constant Float := Float (TY) * Side;
                        Nx  : constant Float := Float'Max (0.0, Float'Max (X0 - Cam.X, Cam.X - (X0 + Side)));
                        Ny  : constant Float := Float'Max (0.0, Float'Max (Y0 - Cam.Y, Cam.Y - (Y0 + Side)));
                        Fx  : constant Float := Float'Max (abs (X0 - Cam.X), abs (X0 + Side - Cam.X));
                        Fy  : constant Float := Float'Max (abs (Y0 - Cam.Y), abs (Y0 + Side - Cam.Y));
                        Dn2 : constant Float := Nx * Nx + Ny * Ny;
                        Df2 : constant Float := Fx * Fx + Fy * Fy;
                        Shows : constant Boolean := (Last or else Dn2 < Outer * Outer) and then Df2 > Inner * Inner;
                        --  (asked for a little before it shows, kept a little after)
                        Wanted : constant Boolean :=
                          Last or else (Dn2 < (Outer * 1.1) ** 2 and then Df2 > (Inner * 0.9) ** 2);
                        Keep   : constant Boolean :=
                          Last or else (Dn2 < (Outer * 1.3) ** 2 and then Df2 > (Inner * 0.75) ** 2);
                     begin
                        case T.State is
                           when None =>
                              if Wanted then
                                 Missing := True;
                                 --  (the nearest first; the last level's, which stand in for
                                 --  all the others, as if 300 m nearer)
                                 Offer ((L, TX, TY, (if Last then 0.0 else 300.0) + Sqrt (Dn2), False));
                              end if;
                           when Requested =>
                              if Keep then
                                 Missing := True;
                              else
                                 T.State := None;            --  (what comes of it is thrown away)
                              end if;
                           when Loaded =>
                              if not Keep then
                                 Castle.Render.Unload_Far (L, TX, TY);
                                 T := (others => <>);
                              elsif (T.Dirty or else T.Again) and then Shows then
                                 Stale := True;
                                 if not T.Again and then Now_S - T.Built_At > Far_Again_S (L) then
                                    Offer ((L, TX, TY, 1.0E5 + Sqrt (Dn2), True));
                                 end if;
                              end if;
                        end case;
                     end;
                  end loop;
               end loop;
            end;
         end loop;
         for I in 1 .. Best_N loop
            declare
               C : Cand renames Best (I);
               T : Far_Tile renames Far_Tiles (C.L, C.TX, C.TY);
            begin
               if C.Again then
                  T.Again := True;
               else
                  T.State := Requested;
               end if;
               T.Dirty := False;
               Castle.Streaming.Request_Far (C.L, C.TX, C.TY, 1.0E6 + C.Key);
               Far_Out := Far_Out + 1;
            end;
         end loop;
         Far_Whole := not Missing and then Far_Out = 0;
         Far_Fresh := Far_Whole and then not Stale;
         if Far_Whole and then Far_Done < 0.0 then
            Far_Done := Now_S;
         end if;
      end Far_Stream;

      procedure Ask (Cx, Cy : Integer) is
      begin
         if Cx in 0 .. Chunks_XY - 1 and then Cy in 0 .. Chunks_XY - 1
           and then States (Cx, Cy) = None
           and then Active_N < Max_Active
         then
            States (Cx, Cy) := Requested;
            Activate (Cx, Cy);
            Castle.Streaming.Wanted (Cx, Cy) := True;
            Castle.Streaming.Request (Cx, Cy, Float ((Cx - Fcx) ** 2 + (Cy - Fcy) ** 2),
                                      Castle.Water.View_Of (Cx, Cy), Castle.Water.Version (Cx, Cy));
            In_Flight := In_Flight + 1;
         end if;
      end Ask;
   begin
      --  The water's surface texture is a window round the stack looked at.
      --  A stack kept loaded outside the view (the colony's ground) that the
      --  window has come back to has its texels written again: its slot was
      --  another's, or hidden, while the camera was far off.
      Castle.Render.Set_Surface_Focus (Fcx, Fcy, Window_Moved);
      if Window_Moved then
         for I in 1 .. Active_N loop
            if States (Active (I).CX, Active (I).CY) = Loaded
              and then Castle.Render.In_Surface_Window (Active (I).CX, Active (I).CY)
              and then not Castle.Render.Owns_Surface (Active (I).CX, Active (I).CY)
            then
               Own_Texels (Active (I).CX, Active (I).CY);
            end if;
         end loop;
      end if;
      for Dy in -R .. R loop
         for Dx in -R .. R loop
            if Dx * Dx + Dy * Dy <= R * R then
               Ask (Fcx + Dx, Fcy + Dy);
            end if;
         end loop;
      end loop;
      if Castle.Colony.Has_Stake then
         declare
            S : constant Coord := Stake_Stack;
         begin
            for Dy in -Colony_R .. Colony_R loop
               for Dx in -Colony_R .. Colony_R loop
                  if Dx * Dx + Dy * Dy <= Colony_R * Colony_R then
                     Ask (S.CX + Dx, S.CY + Dy);
                  end if;
               end loop;
            end loop;
         end;
      end if;

      declare
         I : Positive := 1;
      begin
         while I <= Active_N loop
            declare
               C : constant Coord := Active (I);
            begin
               if (C.CX - Fcx) ** 2 + (C.CY - Fcy) ** 2 > Keep and then not Colony_Holds (C.CX, C.CY) then
                  if States (C.CX, C.CY) = Loaded then
                     Castle.Render.Unload (C.CX, C.CY);
                     Castle.Render.Hide_Surface (C.CX * 32, C.CY * 32);
                     Forget_Surface (C.CX, C.CY);
                     Air_Wanted (C.CX, C.CY) := False;
                     if not Whole_Map then              --  (held: its blocks stay, what was drawn of it goes)
                        Castle.World_Blocks.Drop (C.CX, C.CY);
                     end if;
                     Castle.Nav.Forget_Stack (C.CX, C.CY);
                  else
                     In_Flight := In_Flight - 1;
                  end if;
                  Castle.Streaming.Wanted (C.CX, C.CY) := False;
                  if Pending (C.CX, C.CY) then
                     Pending (C.CX, C.CY) := False;
                     Rebuilding := Rebuilding - 1;
                  end if;
                  States (C.CX, C.CY) := None;
                  Active (I) := Active (Active_N);     --  swap-remove
                  Active_N := Active_N - 1;
               else
                  I := I + 1;
               end if;
            end;
         end loop;
      end;

      --  What the view asked for, a frame's worth of meshes.
      for K in 1 .. Upload_Budget loop
         Castle.Streaming.Poll (Res, Meshed => True);
         exit when Res = null;
         Meshed := Meshed + 1;
         Worker_Ms := Worker_Ms + Res.Millis;
         if States (Res.CX, Res.CY) in Requested | Loaded then
            Show_Surface (Res.CX, Res.CY, Res.M, Res.Summary);
            Castle.Render.Upload (Res.CX, Res.CY, Res.M, Edited => Castle.Edits.Generation (Res.CX, Res.CY) > 0);
            Castle.World_Blocks.Keep (Res.CX, Res.CY, Res.Packed, Res.Gen, Res.Summary);
            Held_Gen (Res.CX, Res.CY) := Res.Gen;
            Hold_Stale (Res.CX, Res.CY) := False;
            if States (Res.CX, Res.CY) = Requested then
               States (Res.CX, Res.CY) := Loaded;
               In_Flight := In_Flight - 1;
            end if;
            if Pending (Res.CX, Res.CY) then
               Pending (Res.CX, Res.CY) := False;
               Rebuilding := Rebuilding - 1;
            end if;
            --  Edited again while it was being built: once more.
            if Res.Gen /= Castle.Edits.Generation (Res.CX, Res.CY)
              or else Res.Water_Ver /= Castle.Water.Version (Res.CX, Res.CY)
            then
               Remesh (Res.CX, Res.CY);
            end if;
         else
            Take_Blocks (Res);                 --  (it left the view while its mesh was made)
         end if;
         Castle.Streaming.Free (Res);
      end loop;
      --  What is held and not drawn: until the frame has given it its share.
      while Whole_Map and then Holds < Hold_Budget and then Hold_Frame < Hold_Frame_Ms loop
         Castle.Streaming.Poll (Res, Meshed => False);
         exit when Res = null;
         Holds := Holds + 1;
         Hold_Out (Res.CX, Res.CY) := False;
         Holds_Out_N := Holds_Out_N - 1;
         Take_Blocks (Res);
         Castle.Streaming.Free (Res);
      end loop;
      if Far_On then
         Far_Stream;
      end if;
      if Whole_Map then
         Hold_T0 := Clock;
         Hold_More;
         Hold_Frame := Hold_Frame + Float (To_Duration (Clock - Hold_T0)) * 1000.0;
         Hold_Main_Ms := Hold_Main_Ms + Hold_Frame;
         Hold_Main_Max := Float'Max (Hold_Main_Max, Hold_Frame);
      end if;
      pragma Debug (Check_Surfaces);
   end Stream;

   --  What the process holds, by the kernel's count (--mem).
   procedure Put_Mem is
      F : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Open (F, Ada.Text_IO.In_File, "/proc/self/status");
      while not Ada.Text_IO.End_Of_File (F) loop
         declare
            L : constant String := Ada.Text_IO.Get_Line (F);
         begin
            if L'Length > 6 and then (L (L'First .. L'First + 5) = "VmRSS:" or else L (L'First .. L'First + 5) = "VmHWM:")
            then
               Put_Line ("mem: " & L);
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (F);
   exception
      when others =>
         Put_Line ("mem: /proc/self/status could not be read");
   end Put_Mem;

   function Img (F : Float; Decimals : Natural := 1) return String is
      Scale : constant Integer := 10 ** Decimals;
      V     : constant Integer := Integer (abs F * Float (Scale));
      Whole : constant String := Integer'Image (V / Scale);
      Frac  : constant String := Integer'Image (V mod Scale + Scale);
   begin
      return (if F < 0.0 and then V > 0 then "-" else "")
        & Whole (Whole'First + 1 .. Whole'Last)
        & (if Decimals > 0 then "." & Frac (Frac'First + 2 .. Frac'Last) else "");
   end Img;

   Now_Weather : Castle.Climate.Weather;
   Now_Mist    : Float := 0.0;               --  as last drawn
   Now_Moon    : Float := 0.5;               --  the moon's phase, as last drawn

   --  "Winter 7, 14:30, -6 C, snow, 32 cm on the ground"
   function Date_Text return String is
      use Castle.Climate;
      D  : constant Float := Day_Of_Year (Game_Clock);
      H  : constant Float := Hour_Of_Day (Game_Clock);
      Hh : constant Integer := Integer (Float'Floor (H));
      Mm : constant Integer := Integer (Float'Floor ((H - Float (Hh)) * 6.0)) * 10;
      Sky : constant String :=
        (if Now_Weather.Snow > 0.05 then "snow"
         elsif Now_Weather.Rain > 0.05 then "rain"
         elsif Now_Weather.Cloud_Cover > 0.7 then "overcast"
         elsif Now_Weather.Cloud_Cover > 0.35 then "cloudy" else "clear")
        & (if Now_Mist > 0.5 then ", thick mist" elsif Now_Mist > 0.15 then ", mist" else "")
        & (if Now_Moon in 0.46 .. 0.54 then ", full moon" elsif Now_Moon < 0.04 or else Now_Moon > 0.96
           then ", new moon" else "");
      function Two (V : Integer) return String is
        (if V < 10 then "0" & Img (Float (V), 0) else Img (Float (V), 0));
   begin
      return Season'Image (Season_Of (D)) & Day_Of_Season (D)'Image & ", " & Two (Hh) & ":" & Two (Mm)
        & ", " & Img (Now_Weather.Temperature, 0) & " C, " & Sky
        & (if Climate.Snow (1) > 0.01 then ", " & Img (Climate.Snow (1) * 100.0, 0) & " cm snow" else "");
   end Date_Text;


   --  How much water each scripted box holds: the stretch holding its bottom row.
   --  The live water in one line, for a scripted run's log: what is out of
   --  the rivers and lakes (columns wet that are not source water, and how
   --  much), and how far source water stands from its level.
   procedure Report_Water is
      Out_Cols, Low_Cols : Natural := 0;
      Out_Sum            : Long_Long_Integer := 0;
      Deepest, Highest   : Integer := 0;
      At_X, At_Y         : Integer := 0;
      U                  : constant := Castle.Water.Unit;
   begin
      for CX in 0 .. Chunks_XY - 1 loop
         for CY in 0 .. Chunks_XY - 1 loop
            if Castle.Water.Is_Simulated (CX, CY) then
               for X in CX * 32 .. CX * 32 + 31 loop
                  for Y in CY * 32 .. CY * 32 + 31 loop
                     if Castle.Water.Rest_Level (X, Y) = 0 then
                        if Castle.Water.Depth (X, Y) > 0 then
                           Out_Cols := Out_Cols + 1;
                           Out_Sum := Out_Sum + Long_Long_Integer (Castle.Water.Depth (X, Y));
                        end if;
                     else
                        declare
                           D : constant Integer := Castle.Water.Drop (X, Y);
                        begin
                           if D > U / 64 then
                              Low_Cols := Low_Cols + 1;
                           end if;
                           if D > Deepest then
                              Deepest := D;
                              At_X := X;
                              At_Y := Y;
                           end if;
                           Highest := Integer'Max (Highest, -D);
                        end;
                     end if;
                  end loop;
               end loop;
            end if;
         end loop;
      end loop;
      Put_Line ("water out of its sources:" & Out_Cols'Image & " columns, "
                & Img (Float (Out_Sum) / Float (U) / 64.0, 2) & " m^3; source water below its level:"
                & Low_Cols'Image & " columns, at most " & Img (Float (Deepest) / Float (U) * 0.25, 2) & " m"
                & (if Deepest > 0 then " (at " & Img (Float (At_X) * 0.25, 1) & ", " & Img (Float (At_Y) * 0.25, 1) & ")"
                   else "")
                & ", over it at most " & Img (Float (Highest) / Float (U) * 0.25, 2) & " m");
   end Report_Water;

   procedure Report_Boxes is
   begin
      for B in 1 .. Dig_Count loop
         declare
            Sum, Cols : Long_Long_Integer := 0;
         begin
            for X in Box (B, 1) .. Box (B, 4) loop
               for Y in Box (B, 2) .. Box (B, 5) loop
                  if Castle.Water.Depth_At (X, Y, Box (B, 3)) >= 0 then
                     Sum := Sum + Long_Long_Integer (Castle.Water.Depth_At (X, Y, Box (B, 3)));
                     Cols := Cols + 1;
                  end if;
               end loop;
            end loop;
            if Cols > 0 then
               Put_Line ("water in dug box" & B'Image & ": "
                         & Img (Float (Sum) / Float (Cols) / Float (Castle.Water.Unit) * 0.25, 2)
                         & " m deep on average, over" & Long_Long_Integer'Image (Cols) & " columns");
            end if;
         end;
      end loop;
   end Report_Boxes;

   --  One line on the colony, for the log: enough to see a save come back.
   --  When the colony is waiting for its ground: how many of its stacks
   --  are not in yet, and what they are waiting on.
   function Ground_Wait return String is
      S : constant Coord := Stake_Stack;
      Asked, Never : Natural := 0;
      First : Coord := (0, 0);
   begin
      if Colony_Ground_Ready then
         return "";
      end if;
      for Dy in -Colony_R .. Colony_R loop
         for Dx in -Colony_R .. Colony_R loop
            if Dx * Dx + Dy * Dy <= Colony_R * Colony_R
              and then S.CX + Dx in 0 .. Chunks_XY - 1 and then S.CY + Dy in 0 .. Chunks_XY - 1
              and then States (S.CX + Dx, S.CY + Dy) /= Loaded
            then
               if States (S.CX + Dx, S.CY + Dy) = Requested then
                  Asked := Asked + 1;
               else
                  Never := Never + 1;
               end if;
               if Asked + Never = 1 then
                  First := (S.CX + Dx, S.CY + Dy);
               end if;
            end if;
         end loop;
      end loop;
      return "; waiting for its ground:" & Asked'Image & " stacks asked for," & Never'Image
        & " not asked (first" & First.CX'Image & "," & First.CY'Image & "), in flight" & In_Flight'Image
        & ", queued" & Castle.Streaming.Queued'Image;
   end Ground_Wait;


   procedure Report_Colony is
   begin
      Castle.Scenario.Put_Report (Ground_Wait);
   end Report_Colony;

   --  One line on the band's food (--log-hours).
   procedure Food_Line is
   begin
      Put_Line (Castle.Scenario.Food_Line (Long_Float (Game_Clock)));
   end Food_Line;

   procedure Do_Save (Path : String) is
      Err : Unbounded_String;
   begin
      Report_Colony;
      declare
         Data : constant Castle.Colony.Bytes := Castle.Colony.Save;
         Blob : Castle.Saves.Blob_Access :=
           (if Castle.Colony.Has_Stake then new Castle.Saves.Blob'(Castle.Saves.Blob (Data)) else null);
         procedure Free is new Ada.Unchecked_Deallocation (Castle.Saves.Blob, Castle.Saves.Blob_Access);
      begin
         Castle.Saves.Save
           (Path, (Seed => Seed, Clock => Long_Float (Game_Clock), Climate => Climate,
                   Cam_X => Cam.T_X, Cam_Y => Cam.T_Y, Cam_Yaw => Cam.T_Yaw,
                   Cam_Pitch => Cam.T_Pitch, Cam_Dist => Cam.T_Dist, Colony => Blob), Err);
         Free (Blob);
      end;
      if Err = Null_Unbounded_String then
         Put_Line ("saved " & Path & " (" & Img (Float (Castle.Edits.Count), 0) & " edits,"
                   & Castle.Water.Simulated_Count'Image & " stacks of live water)");
      else
         Put_Line ("save failed: " & To_String (Err));
      end if;
   end Do_Save;

   --  Restore a save made from this world; Snap puts the camera there at
   --  once instead of gliding.
   procedure Do_Load (Path : String; Snap : Boolean := False) is
      Err  : Unbounded_String;
      Made : U64;
      S    : Castle.Saves.Snapshot;
   begin
      Castle.Saves.Peek (Path, Made, Err);
      if Err = Null_Unbounded_String and then Interfaces."/=" (Made, Seed) then
         Err := To_Unbounded_String ("that save is of world" & Made'Image & "; start it with --load " & Path);
      end if;
      if Err = Null_Unbounded_String then
         Castle.Saves.Load (Path, S, Err);
      end if;
      if Err /= Null_Unbounded_String then
         Put_Line ("load failed: " & To_String (Err));
         return;
      end if;
      Game_Clock := Castle.Climate.Game_Hours (S.Clock);
      Climate := S.Climate;
      --  the colony as it was (after the edits it made, which came back with them)
      if S.Colony /= null then
         declare
            Ok : Boolean;
         begin
            Castle.Colony.Load (Castle.Colony.Bytes (S.Colony.all), Ok);
            if not Ok then
               Put_Line ("the colony in that save could not be read");
            end if;
         end;
      else
         Castle.Colony.Reset;
      end if;
      Castle.Serfs.Clear;
      Serf_Of := [others => 0];
      Castle.Cutaway.Clear;                  --  (every roof whole: the houses are the other game's)
      Castle.Cloth.Free_All;                 --  (the cloaks begin again with the serfs: none is where it lay in the other game)
      Cloak_Cloth := [others => 0];
      Cloak_State := [others => Not_Yet];
      Cloak_Still := [others => 0];
      Castle.Animals.Clear;
      Deer_Anim := [others => 0];
      Cam.T_X := S.Cam_X;  Cam.T_Y := S.Cam_Y;
      Cam.T_Yaw := S.Cam_Yaw;  Cam.T_Pitch := S.Cam_Pitch;  Cam.T_Dist := S.Cam_Dist;
      if Snap then
         Cam.X := S.Cam_X;  Cam.Y := S.Cam_Y;  Cam.Yaw := S.Cam_Yaw;
         Cam.Pitch := S.Cam_Pitch;  Cam.Dist := S.Cam_Dist;  Cam.Held := S.Cam_Dist;
         Cam.Held_Pitch := S.Cam_Pitch;
      end if;
      Castle.World_Blocks.Note_All_Edited;
      --  (what is held and not drawn was made with the edits there were: all of it again)
      for CX in Hold_Stale'Range (1) loop
         for CY in Hold_Stale'Range (2) loop
            Hold_Stale (CX, CY) := States (CX, CY) = None and then Held (CX, CY);
         end loop;
      end loop;
      Hold_Since := 0;
      Hold_Whole := False;
      --  (and every tile of the far view was made with the edits there were: again, at once)
      for T of Far_Tiles.all loop
         if T.State /= None then
            T.Dirty := True;
            T.Built_At := -1.0E6;
         end if;
      end loop;
      Colony_R_Most := 0;                  --  (the colony's ground begins again with the colony that was loaded)
      Castle.Falls.Reset;                  --  (the loaded water finds its flows again, and its falls with them)
      for I in 1 .. Active_N loop
         Remesh (Active (I).CX, Active (I).CY);
      end loop;
      Put_Line ("loaded " & Path & " (" & Img (Float (Castle.Edits.Count), 0) & " edits,"
                & Castle.Water.Simulated_Count'Image & " stacks of live water)");
      Report_Colony;
   end Do_Load;

   T0, T1      : Time;
   Fw, Fh      : int := 0;
   Frame       : Natural := 0;
   Last, Now   : double;
   Title_Clock : double := 0.0;
   Title_Frames : Natural := 0;
   Fill_Done   : Float := -1.0;
   Started     : double;

   --  CPU time is the loop's own work, excluding the wait inside
   --  Swap_Buffers, so vsync doesn't hide it.
   Frame_Start  : Time;
   Cpu_Ms       : Float;
   Win_Cpu_Sum, Win_Cpu_Max, Win_Gpu_Sum : Float := 0.0;
   Run_Frames   : Natural := 0;               --  after the view filled
   Run_Cpu_Sum, Run_Cpu_Max, Run_Gpu_Sum : Float := 0.0;
   Held_Frames  : Natural := 0;               --  after the whole map was held
   Held_Cpu_Sum, Held_Gpu_Sum, Held_Gpu_Max : Float := 0.0;
   Laps     : array (1 .. 7) of Float := [others => 0.0];   --  --hitch: milliseconds each part of the frame took
   Lap_From : Time := Clock;
   procedure Lap (K : Positive) is
      T : constant Time := Clock;
   begin
      Laps (K) := Float (To_Duration (T - Lap_From)) * 1000.0;
      Lap_From := T;
   end Lap;

   --  Where a point of the world is on the screen (pixels), as the camera
   --  stands; Seen False behind the eye.
   procedure Screen_Of (P : Vec3; X, Y : out Float; Seen : out Boolean) is
      E      : constant Vec3 := Castle.Camera.Eye (Cam);
      Fwd    : constant Vec3 := Normalize (Vec3'(Cam.X, Cam.Y, Cam.Z) - E);
      Right  : constant Vec3 := Normalize (Cross (Fwd, (0.0, 0.0, 1.0)));
      Up     : constant Vec3 := Cross (Right, Fwd);
      Ty     : constant Float := Tan (Fov_Y / 2.0);
      Aspect : constant Float := (if Fw > 0 and then Fh > 0 then Float (Fw) / Float (Fh) else 1.0);
      V      : constant Vec3 := P - E;
      Z      : constant Float := Dot (V, Fwd);
   begin
      Seen := Z > 0.2;
      X := 0.0;
      Y := 0.0;
      if Seen then
         X := (Dot (V, Right) / (Z * Ty * Aspect) + 1.0) * 0.5 * Float (Fw);
         Y := (1.0 - Dot (V, Up) / (Z * Ty)) * 0.5 * Float (Fh);
      end if;
   end Screen_Of;

   --  The pointer this frame: the mouse's, or the script's (--pointer),
   --  which glides to where it is aimed and clicks when it is told to.
   procedure Read_Pointer is
   begin
      if Script_N = 0 then
         Ptr_X := (if Mouse_Set then Mouse_PX else (Castle.Input.Cursor_X + 1.0) * 0.5 * Float (Fw));
         Ptr_Y := (if Mouse_Set then Mouse_PY else (1.0 - Castle.Input.Cursor_Y) * 0.5 * Float (Fh));
         Ptr_Click := Castle.Input.Clicked;
         Ptr_RClick := Castle.Input.Right_Clicked;
         Ptr_Held := Castle.Input.Left_Held;
         Ptr_Wheel := Castle.Input.Wheel;
         Ptr_Esc := Castle.Input.Pressed (Castle.Input.Quit);
         return;
      end if;
      Ptr_Click := False;
      Ptr_RClick := False;
      Ptr_Held := False;
      Ptr_Wheel := 0.0;
      Ptr_Esc := False;
      if Castle.Colony.Has_Stake and then Colony_Ground_Ready then
         Script_Frame := Script_Frame + 1;
         while Script_At <= Script_N and then Script (Script_At).Frame <= Script_Frame loop
            declare
               E : Script_Event renames Script (Script_At);
            begin
               case E.Kind is
                  when Move      => Aim := At_Pixel;  Aim_X := E.A;  Aim_Y := E.B;
                  when Rel       => Aim := At_Pixel;  Aim_X := Tgt_X + E.A;  Aim_Y := Tgt_Y + E.B;
                  when To_Member => Aim := At_Member;  Aim_I := Natural (E.A);
                  when To_Deer   => Aim := At_Deer;  Aim_I := Natural (E.A);
                  when To_Ground => Aim := At_Ground;  Aim_X := E.A;  Aim_Y := E.B;
                  when Click     => Ptr_Click := True;  Ptr_Held := True;
                  when RClick    => Ptr_RClick := True;
                  when Wheel     => Ptr_Wheel := E.A;
                  when Esc       => Ptr_Esc := True;
               end case;
            end;
            Script_At := Script_At + 1;
         end loop;
      end if;
      declare
         Seen : Boolean := True;
         X, Y : Float := 0.0;
      begin
         case Aim is
            when At_Pixel =>
               X := Aim_X;
               Y := Aim_Y;
            when At_Member =>
               if Aim_I in 1 .. Castle.Colony.Members then
                  Screen_Of (Castle.Colony.Where (Aim_I)
                             + (0.0, 0.0, (if Castle.Colony."=" (Castle.Colony.Doing (Aim_I), Castle.Colony.Sleeping)
                                           then 0.2 else 1.0)), X, Y, Seen);
               else
                  Seen := False;
               end if;
            when At_Deer =>
               if Aim_I in 1 .. Castle.Herds.Deer_Slots and then Castle.Herds.Alive (Aim_I) then
                  Screen_Of (Castle.Herds.Where (Aim_I, Castle.Colony.Blend) + (0.0, 0.0, 0.7), X, Y, Seen);
               else
                  Seen := False;
               end if;
            when At_Ground =>
               declare
                  Z : constant Float := Castle.Nav.Surface_Z (Aim_X, Aim_Y);
               begin
                  Screen_Of ((Aim_X, Aim_Y, (if Z >= 0.0 then Z else Cam.Z)), X, Y, Seen);
               end;
         end case;
         if Seen then
            Tgt_X := X;
            Tgt_Y := Y;
         end if;
         if abs (Tgt_X - Ptr_X) + abs (Tgt_Y - Ptr_Y) < 2.0 then
            Ptr_X := Tgt_X;
            Ptr_Y := Tgt_Y;
         else
            Ptr_X := Ptr_X + (Tgt_X - Ptr_X) * 0.25;
            Ptr_Y := Ptr_Y + (Tgt_Y - Ptr_Y) * 0.25;
         end if;
      end;
   end Read_Pointer;

   --  People and deer for the pointer's ray, where they are drawn (a body
   --  eases after its colony position; a sleeper lies the way it faced).
   function Drawn_Person (I : Positive) return Castle.Pick.Capsule is
      S : constant Natural := (if I in Serf_Of'Range then Serf_Of (I) else 0);
   begin
      if S = 0 then
         return Castle.Pick.Colony_Person (I);
      end if;
      declare
         P : constant Vec3 := Castle.Serfs.Where (S);
         H : constant Float := Castle.Colony.Genome_Of (I).Height;
      begin
         case Castle.Colony.Doing (I) is
            when Castle.Colony.Sleeping | Castle.Colony.Dead =>
               return Castle.Pick.Lying (P, Castle.Serfs.Heading (S), H);
            when Castle.Colony.Eating_Seated =>
               return Castle.Pick.Standing (P, 0.75 * H);
            when others =>
               return Castle.Pick.Standing (P, H);
         end case;
      end;
   end Drawn_Person;

   function Drawn_Deer (K : Positive) return Castle.Pick.Capsule is
      C : Castle.Pick.Capsule := Castle.Pick.Herd_Deer (K);
   begin
      if K in Deer_Anim'Range and then Deer_Anim (K) > 0 then
         declare
            Off : constant Vec3 :=
              Castle.Animals.Where (Deer_Anim (K)) - Castle.Herds.Where (K, Castle.Colony.Blend);
         begin
            C.A := C.A + Off;
            C.B := C.B + Off;
         end;
      end if;
      return C;
   end Drawn_Deer;

   --  What the pointer is on (or the open menu is about), marked on the
   --  ground: a ring round a person or a deer, a zone's borders.
   procedure Show_Pointed is
      use Castle.Pick;
      T   : constant Thing := (if Castle.HUD.Menu_Open then Castle.HUD.Menu_On else Under);
      Col : constant Castle.Marks.Colour := (1.0, 0.92, 0.6, 0.9);

      procedure Ring (C : Capsule) is
         Mid : constant Vec3 := (C.A + C.B) * 0.5;
         Dx  : constant Float := C.B.X - C.A.X;
         Dy  : constant Float := C.B.Y - C.A.Y;
         R   : constant Float := Float'Max (0.55, 0.5 * Sqrt (Dx * Dx + Dy * Dy) + 0.4);
         Z   : constant Float := Float'Min (C.A.Z, C.B.Z) - C.R + 0.06;
         N   : constant := 14;
      begin
         for K in 0 .. N - 1 loop
            declare
               A0 : constant Float := 2.0 * Ada.Numerics.Pi * Float (K) / Float (N);
               A1 : constant Float := 2.0 * Ada.Numerics.Pi * Float (K + 1) / Float (N);
            begin
               Castle.Marks.Strip ((Mid.X + R * Cos (A0), Mid.Y + R * Sin (A0), Z),
                                   (Mid.X + R * Cos (A1), Mid.Y + R * Sin (A1), Z), 0.1, Col);
            end;
         end loop;
      end Ring;
   begin
      case T.Kind is
         when A_Person =>
            if T.Index in 1 .. Castle.Colony.Members then
               Ring (Drawn_Person (T.Index));
            end if;
         when A_Deer =>
            if T.Index in 1 .. Castle.Herds.Deer_Slots and then Castle.Herds.Alive (T.Index) then
               Ring (Drawn_Deer (T.Index));
            end if;
         when A_Zone =>
            if T.Index in 1 .. Castle.Colony.Zone_Count then
               Castle.Zone_Marks.Show_Zone (T.Index, Castle.Zone_Marks.Pointed);
            end if;
         when A_House =>
            if T.Index in 1 .. Castle.Colony.House_Count then
               declare
                  V : constant Castle.Colony.House_View := Castle.Colony.House_At (T.Index);
               begin
                  Castle.Zone_Marks.Show_Lot (V.Corner, V.Corner (1).Z + 0.05, Castle.Zone_Marks.Pointed.Edge, 0.12);
               end;
            end if;
         when A_Cart =>
            if Castle.Colony.Cart.Here then
               declare
                  C  : constant Castle.Colony.Cart_View := Castle.Colony.Cart;
                  Hl : constant Float := 0.125 * Float (Castle.Colony.Cart_Long_B) + 0.35;
                  Hw : constant Float := 0.125 * Float (Castle.Colony.Cart_Wide_B) + 0.35;
                  Hx : constant Float := (if C.Along_X then Hl else Hw);
                  Hy : constant Float := (if C.Along_X then Hw else Hl);
               begin
                  Castle.Zone_Marks.Show_Lot
                    ([(C.At_P.X - Hx, C.At_P.Y - Hy, C.At_P.Z), (C.At_P.X + Hx, C.At_P.Y - Hy, C.At_P.Z),
                      (C.At_P.X + Hx, C.At_P.Y + Hy, C.At_P.Z), (C.At_P.X - Hx, C.At_P.Y + Hy, C.At_P.Z)],
                     C.At_P.Z + 0.05, Castle.Zone_Marks.Pointed.Edge, 0.12);
               end;
            end if;
         when A_Block | Nothing =>
            null;
      end case;
   end Show_Pointed;

begin
   Parse;
   if Load_Path /= Null_Unbounded_String then
      declare
         Err : Unbounded_String;
      begin
         Castle.Saves.Peek (To_String (Load_Path), Seed, Err);
         if Err /= Null_Unbounded_String then
            Put_Line ("load failed: " & To_String (Err));
            return;
         end if;
      end;
   end if;

   Castle.Actions.Set_Arrivals (Scn.Band, Castle.Hash.Derive (Seed, 7));
   Castle.Colony.Set_Skills (Scn.Skills);      --  --no-skills holds for a stake raised by hand too (a save has its own)
   Castle.Colony.Set_Demand_Chain (Scn.Demand);   --  and --no-demand
   Castle.Pick.Set_Shapes (Drawn_Person'Unrestricted_Access, Drawn_Deer'Unrestricted_Access);

   T0 := Clock;
   Castle.Worldgen.Create (Seed, W, Report => False);
   Castle.Water.Set_Ground (Castle.World_Blocks.Ground'Access);
   Castle.Falls.Set_Ground (Castle.World_Blocks.Ground'Access);
   Castle.Nav.Set_Source (Castle.World_Blocks.Ground'Access, Material_At'Unrestricted_Access,
                          Castle.World_Blocks.Ground_Version'Access,
                          Castle.World_Blocks.Changes_Since'Access);
   Castle.Colony.Set_World (Castle.World_Blocks.Block_At'Access, Colony_Write'Unrestricted_Access,
                            Castle.World_Blocks.Ground_Version'Access);
   Castle.Colony.Set_Trees (Colony_Tree'Unrestricted_Access, Colony_Tree_Shape'Unrestricted_Access);
   T1 := Clock;
   Put_Line ("world" & Seed'Image & " created in "
             & Img (Float (To_Duration (T1 - T0))) & " s");

   Win := Castle.Platform.Open ("Castle", Width, Height, Fixed => Float_Window);
   Swap_Interval (if Vsync then 1 else 0);
   Castle.Input.Attach (Win);
   --  a scripted run (--frames, --record) takes no input: its window can take
   --  the focus on a desktop, and keys meant for something else (Space
   --  pauses) would steer it
   Castle.Input.Ignore (Frames > 0 or else Record_N > 0);
   --  What the player set last time.  A scripted run takes none of it
   --  unless it names the file, so a shot or a recording does not depend
   --  on whose machine made it.
   if Settings_Given or else (Frames = 0 and then Record_N = 0) then
      Castle.Settings.Load (To_String (Settings_Path));
      if not UI_Given and then Castle.Settings.Has ("ui_scale") then
         UI_Scale := Castle.Settings.Get ("ui_scale", 0.0);
         if UI_Scale > 0.0 then
            Put_Line ("interface scale " & Img (Castle.UI.Nearest_Scale (UI_Scale), 2)
                      & " (" & To_String (Settings_Path) & ")");
         end if;
      end if;
   end if;
   Castle.Currents.Build (W);
   Castle.Water.Set_Supply (River_Supply'Unrestricted_Access);
   Castle.Water.Set_Recharge (Source_Refill'Unrestricted_Access);
   Castle.Water.Set_Seep (Seep_Rate'Unrestricted_Access);
   Castle.Water.Set_Leak (True);
   Last_Dry := Game_Clock;
   Castle.Render.Set_Water_Reach (View_M);
   Castle.Render.Init (W, Arena_Quads, Samples => MSAA);
   Castle.UI.Init;
   Castle.Render.Set_Flow_Debug (Flow_Debug);
   Castle.Render.Set_Water_Steps (Water_Steps);
   Put_Line ("OpenGL " & Castle.Platform.GL_Version & " on " & Castle.Platform.GL_Renderer
             & (if Castle.Render.MSAA_Samples > 0
                then "," & Castle.Render.MSAA_Samples'Image & "x MSAA" else ", no MSAA"));
   Castle.Render.Far_View := Far_On;
   if Far_On then
      Castle.Render.Far_Plane := 4_800.0;     --  (the map's far corner from an eye 450 m off its focus, and room)
   end if;
   Castle.Streaming.Start (W, Workers);
   Castle.Camera.Reset (Cam, Start_X, Start_Y, W);
   Game_Clock := Long_Float (Start_Day) * 24.0 + Long_Float (Start_Hour);
   Castle.Climate.Start (Climate, W.Seed, Game_Clock);
   if Cam_Set then
      Cam.Yaw := Cam_Yaw;     Cam.T_Yaw := Cam_Yaw;
      Cam.Pitch := Cam_Pitch; Cam.T_Pitch := Cam_Pitch;
      Cam.Dist := Cam_Dist;   Cam.T_Dist := Cam_Dist;
      Cam.Held := Cam_Dist;
      Cam.Held_Pitch := Cam_Pitch;
   end if;
   if Load_Path /= Null_Unbounded_String then
      Do_Load (To_String (Load_Path), Snap => True);
      --  a view asked for on the command line stands, whatever the save was looking at
      if At_Set then
         Cam.X := Start_X;  Cam.T_X := Start_X;
         Cam.Y := Start_Y;  Cam.T_Y := Start_Y;
      end if;
      if Cam_Set then
         Cam.Yaw := Cam_Yaw;     Cam.T_Yaw := Cam_Yaw;
         Cam.Pitch := Cam_Pitch; Cam.T_Pitch := Cam_Pitch;
         Cam.Dist := Cam_Dist;   Cam.T_Dist := Cam_Dist;
         Cam.Held := Cam_Dist;
         Cam.Held_Pitch := Cam_Pitch;
      end if;
   end if;
   if Dig_Set and then not Dig_Late then
      for B in 1 .. Dig_Count loop
         Edit_Box (Box (B, 1), Box (B, 2), Box (B, 3), Box (B, 4), Box (B, 5), Box (B, 6), Air, Force => True);
      end loop;
      Put_Line ("dug out the --dig box:" & Castle.Edits.Count'Image & " edits");
   end if;
   Put_Line ("streaming" & Workers'Image & " workers, view radius " & Img (View_M, 0) & " m");

   Last := Get_Time;
   Started := Last;
   while Window_Should_Close (Win) = 0 loop
      Frame_Start := Clock;
      Lap_From := Frame_Start;
      Laps := [others => 0.0];
      Poll_Events;
      Castle.Input.Update (Win);
      Now := Get_Time;

      --  The interface takes the cursor first: a click on a panel is not a
      --  click on the world, and the wheel over one is the panel's (a list
      --  scrolls), not the camera's.  (Sizes are last frame's; they rarely
      --  change.)
      Read_Pointer;
      Castle.UI.Begin_Frame (Natural (Fw), Natural (Fh), Ptr_X, Ptr_Y, Ptr_Click, UI_Scale,
                             Wheel => Ptr_Wheel, Mouse_Held => Ptr_Held,
                             Seconds => (if Record_N > 0 then 1.0 / 30.0 else Float'Min (0.1, Float (Now - Last))));
      if Castle.UI.Wants_Mouse then
         Castle.Input.Drop_Wheel;
      end if;
      --  the interface a step smaller or larger (from the next frame), and remembered
      if Castle.Input.Pressed (Castle.Input.UI_Smaller) or else Castle.Input.Pressed (Castle.Input.UI_Larger) then
         declare
            To : constant Float :=
              Castle.UI.Next_Scale (Castle.UI.Scale, Larger => Castle.Input.Pressed (Castle.Input.UI_Larger));
            Own : constant Boolean := To = Castle.UI.Auto_Scale (Natural (Fh));
            Ok  : Boolean;
         begin
            UI_Scale := (if Own then 0.0 else To);        --  the window's own: it follows the window again
            Castle.HUD.Say (Tools, "Interface scale " & Img (To, 2)
                            & (if Own then " (the window's own)" else "") & ": F10 smaller, F11 larger");
            Castle.Settings.Set ("ui_scale", UI_Scale);
            Castle.Settings.Save (To_String (Settings_Path), Ok);
         end;
      end if;
      if Castle.Input.Pressed (Castle.Input.Show_Help)   then Show.Help   := not Show.Help;   end if;
      if Castle.Input.Pressed (Castle.Input.Show_Survey) then Show.Survey := not Show.Survey; end if;
      if Castle.Input.Pressed (Castle.Input.Show_Debug)  then Show.Debug  := not Show.Debug;  end if;
      if Castle.Input.Pressed (Castle.Input.Show_Routes) then Show_Routes := not Show_Routes; end if;
      if Castle.Input.Pressed (Castle.Input.Show_Nav)    then Show_Map := not Show_Map;       end if;
      if Castle.Input.Pressed (Castle.Input.Show_Wells)  then Show_Wells := not Show_Wells;   end if;
      if Castle.Input.Pressed (Castle.Input.Show_Band)   then Show.Band := not Show.Band;     end if;
      --  (John, 2026-11-13: "the H k toggle through, dynamic transparency, full trasnparency, or no
      --  transparency"; said in a note, since the first and the last look alike until something is pointed at)
      if Castle.Input.Pressed (Castle.Input.Open_Roofs)  then
         case Castle.Cutaway.Viewing is
            when Castle.Cutaway.Dynamic =>
               Castle.Cutaway.Set_View (Castle.Cutaway.Full);
               Castle.HUD.Say (Tools, "Roofs and walls: every house open");
            when Castle.Cutaway.Full =>
               Castle.Cutaway.Set_View (Castle.Cutaway.None);
               Castle.HUD.Say (Tools, "Roofs and walls: all whole");
            when Castle.Cutaway.None =>
               Castle.Cutaway.Set_View (Castle.Cutaway.Dynamic);
               Castle.HUD.Say (Tools, "Roofs and walls: open where you look and point");
         end case;
      end if;
      if Castle.Input.Pressed (Castle.Input.Pause_Game) then
         if Tools.Speed = 0 then
            Tools.Speed := Last_Speed;
         else
            Tools.Speed := 0;
         end if;
      end if;
      if Castle.Input.Pressed (Castle.Input.Speed_1) then Tools.Speed := 1; end if;
      if Castle.Input.Pressed (Castle.Input.Speed_2) then Tools.Speed := 2; end if;
      if Castle.Input.Pressed (Castle.Input.Speed_3) then Tools.Speed := 3; end if;
      if Tools.Speed > 0 then
         Last_Speed := Tools.Speed;
      end if;
      if Castle.Input.Pressed (Castle.Input.Hide_HUD)    then Show.Visible := not Show.Visible; end if;
      Castle.Camera.Update (Cam, W, Float'Min (0.1, Float (Now - Last)));
      Follow_Roofs;                          --  (before the pointer's ray: it goes through what is cleared)

      --  Editing: the block under the cursor.  A click digs out the brush
      --  box round it; with Ctrl held it fills the box in front of the face
      --  pointed at.
      declare
         use Castle.Input;
         Aspect : constant Float :=
           (if Fw > 0 and then Fh > 0 then Float (Fw) / Float (Fh) else Float (Width) / Float (Height));
         E      : constant Vec3 := Castle.Camera.Eye (Cam);
         Fwd    : constant Vec3 := Normalize (Vec3'(Cam.X, Cam.Y, Cam.Z) - E);
         Right  : constant Vec3 := Normalize (Cross (Fwd, (0.0, 0.0, 1.0)));
         Up     : constant Vec3 := Cross (Right, Fwd);
         Ty     : constant Float := Tan (Fov_Y / 2.0);
         Pnt_X  : constant Float := (if Fw > 0 then 2.0 * Ptr_X / Float (Fw) - 1.0 else 0.0);
         Pnt_Y  : constant Float := (if Fh > 0 then 1.0 - 2.0 * Ptr_Y / Float (Fh) else 0.0);
         Ray    : constant Vec3 :=
           Normalize (Fwd + Right * (Pnt_X * Ty * Aspect) + Up * (Pnt_Y * Ty));
         Place  : constant Boolean := Held (Place_Mode) or else Tools.Place;
         On_UI  : constant Boolean := Castle.UI.Wants_Mouse;
         H      : constant Castle.World_Blocks.Hit :=
           (if On_UI then (others => <>) else Castle.World_Blocks.Cast (E, Ray, 700.0));
         World_Click : Boolean;      --  the left click is the world's: not a panel's, nor one that closed a menu
      begin
         if Pressed (Brush_Size) then
            Brush := (case Brush is when 1 => 4, when 4 => 8, when others => 1);
         end if;
         if Pressed (Next_Material) then
            Pick := Pick mod Palette'Length + 1;
         end if;
         Cursor_Hit := H;
         --  What the ray points at: a person, a deer, a zone, else the block;
         --  six pixels of slack, so someone far off can be pointed at, and
         --  whoever it was on a moment ago kept while the ray is still on
         --  them.  From above there is no limit of reach.
         Under := (if On_UI then (others => <>)
                   else Castle.Pick.Look (E, Ray, H, Slack => 12.0 * Ty / Float (Integer'Max (1, Integer (Fh))),
                                          Keep => Under));
         --  Where the pointer's ray landed, for the roofs it clears next frame
         --  (Follow_Roofs).  On the interface, or with a menu open, the last
         --  place stands: a roof does not close over what its menu is about.
         if not On_UI and then not Castle.HUD.Menu_Open then
            Point_Has := H.Found;
            if H.Found then
               Point_To := E + Ray * (H.Dist + 0.3);
            end if;
         end if;
         Castle.HUD.Point (Under, Ptr_X, Ptr_Y, Ptr_Click, Ptr_RClick, Tools, World_Click);
         if Tools.Mode = Castle.HUD.Edit then
            Tools.Path_Started := False;    --  the colony's tools put down: nothing half drawn
            Tools.Zone_Started := False;
         end if;
         if H.Found then
            declare
               Tx : constant Integer := Integer'Max (0, (if Place then H.X + H.Nx else H.X));
               Ty2 : constant Integer := Integer'Max (0, (if Place then H.Y + H.Ny else H.Y));
               Tz : constant Integer := Integer'Max (0, (if Place then H.Z + H.Nz else H.Z));
               X0 : constant Integer := Tx - Tx mod Brush;
               Y0 : constant Integer := Ty2 - Ty2 mod Brush;
               Z0 : constant Integer := Tz - Tz mod Brush;
            begin
               if Tools.Mode /= Castle.HUD.Edit then
                  Castle.Render.Set_Outline ((0.0, 0.0, 0.0), (0.0, 0.0, 0.0), False);
                  if World_Click then
                     Castle.HUD.Ground_Click (Ground_Point (H), Tools);
                  end if;
               elsif Under.Kind in Castle.Pick.A_Person | Castle.Pick.A_Deer or else Castle.HUD.Menu_Open then
                  --  pointing at someone, or a menu up: no brush box, and a click digs nothing
                  Castle.Render.Set_Outline ((0.0, 0.0, 0.0), (0.0, 0.0, 0.0), False);
               else
                  Castle.Render.Set_Outline
                    ((Float (X0) * 0.25, Float (Y0) * 0.25, Float (Z0) * 0.25),
                     (Float (X0 + Brush) * 0.25, Float (Y0 + Brush) * 0.25, Float (Z0 + Brush) * 0.25), True);
                  if World_Click then
                     Edit_Box (X0, Y0, Z0, X0 + Brush - 1, Y0 + Brush - 1, Z0 + Brush - 1,
                               (if Place then Palette (Pick) else Air));
                  end if;
               end if;
            end;
         else
            Castle.Render.Set_Outline ((0.0, 0.0, 0.0), (0.0, 0.0, 0.0), False);
         end if;
         if Pressed (Quick_Save) then
            Do_Save (Quick_Path);
         end if;
         if Pressed (Quick_Load) then
            Do_Load (Quick_Path);
         end if;
      end;
      if Record_N > 0 then
         Castle.Render.Set_Outline ((0.0, 0.0, 0.0), (0.0, 0.0, 0.0), False);   --  no edit box in recordings
      end if;
      --  The game clock, the climate it drives, and how the world looks.
      declare
         use Castle.Climate;
         use Castle.Input;
         Dt     : constant Long_Float := Long_Float (Float'Min (0.1, Float (Now - Last)));
         Before : constant Game_Hours := Game_Clock;
      begin
         --  one step for the sky, the colony and the serfs alike, so they keep together
         Step_Seconds := (if Record_N > 0 then 1.0 / 30.0 else Float (Dt));
         --  (--drawn-still: drawn time holds still, so that two builds' pictures
         --  of one view can be compared pixel by pixel)
         if not Drawn_Still then
            Flame_T := Flame_T + Step_Seconds;
            if Flame_T > 3_600.0 then
               Flame_T := Flame_T - 3_600.0;
            end if;
            Sky_T := Sky_T + Long_Float (Step_Seconds);
         end if;
         Game_Clock := Game_Clock + Long_Float (Step_Seconds) * Time_Scale * Long_Float (Tools.Speed);
         if Held (Time_Forward) then Game_Clock := Game_Clock + 3.0 * Dt;  end if;
         if Held (Time_Back)    then Game_Clock := Game_Clock - 3.0 * Dt;  end if;
         if Held (Day_Forward)  then Game_Clock := Game_Clock + 48.0 * Dt; end if;
         if Held (Day_Back)     then Game_Clock := Game_Clock - 48.0 * Dt; end if;
         if Game_Clock < Before or else Game_Clock - Climate.T > 30.0 * 24.0 then
            Start (Climate, W.Seed, Game_Clock);     --  went back, or far ahead: replay the month before
         else
            Advance (Climate, W.Seed, Game_Clock);
         end if;

         declare
            Wx  : Weather := Weather_At (W.Seed, Game_Clock);
            D   : constant Float := Day_Of_Year (Game_Clock);
            F   : constant String := To_String (Forced);
            L   : Castle.Render.Look;
         begin
            if F = "clear" then
               Wx := (Wx with delta Cloud_Cover => 0.1, Rain => 0.0, Snow => 0.0);
            elsif F = "cloudy" then
               Wx := (Wx with delta Cloud_Cover => 0.7, Rain => 0.0, Snow => 0.0);
            elsif F = "rain" then
               Wx := (Wx with delta Cloud_Cover => 0.95, Rain => 0.8, Snow => 0.0);
            elsif F = "snow" then
               Wx := (Wx with delta Cloud_Cover => 0.95, Rain => 0.0, Snow => 0.8);
            elsif F = "storm" then
               Wx := (Wx with delta Cloud_Cover => 1.0, Rain => (if Wx.Temperature > 1.0 then 1.0 else 0.0),
                                    Snow => (if Wx.Temperature > 1.0 then 0.0 else 1.0));
            elsif F'Length > 6 and then F (F'First .. F'First + 5) = "cover:" then
               Wx := (Wx with delta Cloud_Cover => Float'Value (F (F'First + 6 .. F'Last)));
            end if;
            L := (Day         => D,
                  Hour        => Hour_Of_Day (Game_Clock),
                  Cloud_Cover => Wx.Cloud_Cover,
                  Rain        => Wx.Rain,
                  Snowfall    => Wx.Snow,
                  Wind_X      => Wx.Wind_X,
                  Wind_Y      => Wx.Wind_Y,
                  Snow_Lo     => (if Forced_Snow >= 0.0 then Forced_Snow else Climate.Snow (1)),
                  Snow_Mid    => (if Forced_Snow >= 0.0 then Forced_Snow else Climate.Snow (2)),
                  Snow_Hi     => (if Forced_Snow >= 0.0 then Forced_Snow else Climate.Snow (3)),
                  Ice         => Climate.Ice,
                  --  (the ground is wet as soon as rain falls on it: the climate's own
                  --  count of it, which dries with the sun, takes an hour or two to fill)
                  Wet         => (if Forced_Wet >= 0.0 then Forced_Wet
                                  else Float'Max (Climate.Wet, Float'Min (1.0, 1.3 * Wx.Rain))),
                  Mist        => (if Forced_Mist >= 0.0 then Forced_Mist
                                  elsif F'Length > 0 then 0.0     --  a forced sky is as it is asked for
                                  else Mist (W.Seed, Game_Clock, Wx, Climate)),
                  Moon        => (if Forced_Moon >= 0.0 then Forced_Moon else Moon_Phase (Game_Clock)),
                  Moon_Per_Day => (if Forced_Moon >= 0.0 then 0.0 else 1.0 / Float (Moon_Days)),
                  Leaf_Turn   => Leaf_Turn (D),
                  Leaf_Fall   => Leaf_Fall (D),
                  Grass_Dry   => Grass_Dry (D),
                  Seconds     => Float (Sky_T));
            Castle.Render.Set_Look (L);
            Now_Weather := Wx;
            Now_Mist := (if Castle.Render.Mists then L.Mist else 0.0);
            Now_Moon := L.Moon;
            Wind_Now := (Wx.Wind_X, Wx.Wind_Y, 0.0);
         end;
      end;
      Frame_Seconds := Float (Now - Last);   --  before Last moves on: the water clock needs it too
      Last := Now;
      --  Esc cancels what is on the go (a menu, a path line or a stockpile
      --  half drawn); with nothing to cancel it quits (never from a script).
      if Ptr_Esc and then not Castle.HUD.Cancel (Tools) and then Script_N = 0 then
         Set_Window_Should_Close (Win, 1);
      end if;

      Lap (1);
      Stream;
      Lap (2);
      if In_Flight = 0 and then Fill_Done < 0.0 then
         Fill_Done := Float (Now - Started);
      end if;

      --  People, once the ground under them is loaded.
      if In_Flight = 0 and then not Serfs_Out and then (Lineup_N > 0 or else Walk_N > 0 or else Deer_N > 0
                                                        or else Deer_Walk_N > 0)
      then
         declare
            Eye    : constant Vec3 := Castle.Camera.Eye (Cam);
            Winter : constant Boolean := Force_Winter
              or else Castle.Climate."=" (Castle.Climate.Season_Of (Castle.Climate.Day_Of_Year (Game_Clock)), Castle.Climate.Winter);
         begin
            if Lineup_N > 0 then
               Castle.Serfs.Spawn_Lineup
                 (Lineup_N, (Cam.X, Cam.Y, Cam.Z), Heading_Of (Eye - (Cam.X, Cam.Y, Cam.Z), 0.0) + Lineup_Turn,
                  Seed, Winter);
            end if;
            for K in 1 .. Walk_N loop
               Castle.Serfs.Spawn_Walker
                 ((Walks (K, 1), Walks (K, 2), Cam.Z), (Walks (K, 3), Walks (K, 4), Cam.Z),
                  Castle.Hash.Derive (Seed, U64 (100 + K)),
                  Castle.Bodies.Job_Kind'Val (K mod 6), Winter);
            end loop;
            --  deer: a row across the view, facing the camera's right, every class in turn
            declare
               Fc : constant Float := Heading_Of (Eye - (Cam.X, Cam.Y, Cam.Z), 0.0);
               Across : constant Vec3 := (-Sin (Fc), Cos (Fc), 0.0);
            begin
               for K in 1 .. Deer_N loop
                  declare
                     C : constant Castle.Deer.Class := Castle.Deer.Class'Val ((K - 1) mod 4);
                     P : constant Vec3 := (Cam.X, Cam.Y, Cam.Z) + Across * ((Float (K) - Float (Deer_N + 1) / 2.0) * 1.8);
                     A : constant Natural := Castle.Animals.Spawn (C, P, Fc + 1.5708, Castle.Hash.Derive (Seed, U64 (300 + K)),
                                                                   Winter);
                  begin
                     if A > 0 then
                        Castle.Animals.Drive (A, P, (case K mod 3 is when 0 => Castle.Deer.Graze,
                                                                       when 1 => Castle.Deer.Idle,
                                                                       when others => Castle.Deer.Alert));
                     end if;
                  end;
               end loop;
            end;
            for K in 1 .. Deer_Walk_N loop
               Castle.Animals.Spawn_Walker
                 (Castle.Deer.Class'Val ((K - 1) mod 4 + (if K = 1 then 1 else 0)),
                  (Deer_Walks (K, 1), Deer_Walks (K, 2), Cam.Z), (Deer_Walks (K, 3), Deer_Walks (K, 4), Cam.Z),
                  Deer_Walks (K, 5), Castle.Hash.Derive (Seed, U64 (400 + K)), Winter);
            end loop;
            Serfs_Out := True;
            Castle.Serfs.Plan_Walkers;
            Put_Line ("serfs:" & Castle.Serfs.Count'Image);
            for K in 1 .. Castle.Serfs.Count loop
               Put_Line ("  " & Castle.Serfs.Describe (K));
               if K > Castle.Serfs.Count - Walk_N then
                  Put_Line ("    route: " & Castle.Serfs.Route_Summary (K));
               end if;
            end loop;
         end;
      end if;
      --  The colony: set up from the command line once the ground is in, a
      --  step of its clock at the game's speed, and its members shown.
      --  (the colony's own ground, which it reads nothing beyond, whatever else is loaded)
      Castle.Colony.Set_Ground_Stacks (Colony_R);
      if In_Flight = 0 and then Scn.Stake and then not Colony_Scripted then
         Colony_Scripted := True;
         Script_Colony;
      end if;
      if Castle.Colony.Has_Stake and then Colony_Ground_Ready then
         Lap (3);
         Castle.Colony.Advance (Step_Seconds * Float (Tools.Speed),
                                Long_Float (Game_Clock));
         Lap (4);
         Flush_Colony_Edits;
         Lap (5);
         if Castle.Colony.Deaths > Deaths_Told then
            for I in 1 .. Castle.Colony.Members loop
               if Castle.Colony.Dead (I) and then not Told_Dead (I) then
                  Told_Dead (I) := True;
                  Put_Line (Castle.Colony.Name_Of (I) & " has died of hunger");
               end if;
            end loop;
            Deaths_Told := Castle.Colony.Deaths;
         end if;
         if Log_Hours > 0.0
           and then Long_Float'Floor (Game_Clock / Long_Float (Log_Hours)) /= Logged_At
         then
            Logged_At := Long_Float'Floor (Game_Clock / Long_Float (Log_Hours));
            Food_Line;
         end if;
         Show_Members;
         Show_Deer;
         if Tools.Follow in 1 .. Castle.Colony.Members then
            declare
               P : constant Vec3 := Castle.Colony.Where (Tools.Follow);
            begin
               Cam.T_X := P.X;
               Cam.T_Y := P.Y;
               if Record_N > 0 then
                  Cam.X := P.X;
                  Cam.Y := P.Y;
               end if;
            end;
         end if;
      end if;
      if Serfs_Out and then Lineup_Posed and then Lineup_N > 0 and then not Castle.Colony.Has_Stake then
         --  the row at work where it stands, at something three metres in front of each
         for I in 1 .. Natural'Min (Lineup_N, Castle.Serfs.Count) loop
            declare
               use type Castle.Serfs.Motion_Kind;
               P : constant Vec3 := Castle.Serfs.Where (I);
               H : constant Float := Castle.Serfs.Heading (I);
               D : constant Float := (if Lineup_Does = Castle.Serfs.Chop then 0.9 else 3.0);
            begin
               Castle.Serfs.Drive (I, P, Lineup_Does, P + (Cos (H) * D, Sin (H) * D, 0.7));
            end;
         end loop;
      end if;
      if Serfs_Out or else Castle.Colony.Has_Stake then
         Castle.Serfs.Update (Step_Seconds * Float (Tools.Speed),
                              Castle.Camera.Eye (Cam));
         Castle.Animals.Update (Step_Seconds * Float (Tools.Speed));
         if Follow_Deer and then Castle.Animals.Count > 0 then
            declare
               P : constant Vec3 := Castle.Animals.Where (1);
            begin
               Cam.T_X := P.X;
               Cam.T_Y := P.Y;
               if Record_N > 0 then
                  Cam.X := P.X;
                  Cam.Y := P.Y;
               end if;
            end;
         end if;
         if Follow and then Castle.Serfs.Count > 0 then
            declare
               P : constant Vec3 := Castle.Serfs.Where (1);
            begin
               Cam.T_X := P.X;
               Cam.T_Y := P.Y;
               if Record_N > 0 then
                  Cam.X := P.X;              --  locked, so frames a thirtieth apart stay steady
                  Cam.Y := P.Y;
               end if;
            end;
         end if;
      end if;
      Castle.Serfs.Submit;
      Castle.Animals.Submit;
      Castle.Marks.Begin_Frame;
      if Show_Routes then
         Castle.Serfs.Submit_Routes;
      end if;
      if Lineup_Posed and then not Castle.Colony.Has_Stake then
         --  (a row put to sleep, to be looked at: each under its cloak)
         for I in 1 .. Natural'Min (Lineup_N, Castle.Serfs.Count) loop
            if Castle.Serfs."=" (Lineup_Does, Castle.Serfs.Sleep) and then Castle.Serfs.Lies (I) > 0.6 then
               Spread_Cloak (I);
            end if;
         end loop;
      end if;
      if Castle.Colony.Has_Stake then
         Show_Zones;
         Show_Stockpiles;
         Show_Cart;
         Show_Beds;
         Show_Cloaks;
         if Castle.Colony.Has_Camp then
            Show_Camp;
         end if;
      end if;
      Castle.Render.Clear_Lights;
      if Castle.Colony.Has_Camp and then Camp_Alight then
         Castle.Render.Add_Light (Castle.Fire.Light_At (Castle.Colony.Camp, Camp_Heat, Flame_T),
                                  Castle.Fire.Light_Strength (Camp_Heat, Flame_T));
      end if;
      --  --lights N: fires scattered round where the view began, the nearer
      --  the more (a spiral, each about seven metres from the next), to see
      --  and to cost many lights at once; the first twelve are drawn as fires.
      for I in 1 .. Test_Lights loop
         declare
            R   : constant Float := 4.0 * Sqrt (Float (I));
            A   : constant Float := 2.399_963 * Float (I);
            X   : constant Float := Start_X + R * Cos (A);
            Y   : constant Float := Start_Y + R * Sin (A);
            Bed : constant Vec3 := (X, Y, Castle.Fields.Sample (W.Height.all, X, Y) + 0.05);
            T   : constant Float := Flame_T + 7.3 * Float (I);
         begin
            if I <= 12 then
               Castle.Fire.Show (Bed, 1.0, T, Wind_Now);
            end if;
            Castle.Render.Add_Light (Castle.Fire.Light_At (Bed, 1.0, T), Castle.Fire.Light_Strength (1.0, T));
         end;
      end loop;
      if Castle.Colony.Has_Stake then
         if Show_Routes then
            Show_Member_Routes;
         end if;
      end if;
      Show_Tool_Preview;
      Show_Pointed;
      if Show_Map then
         Show_Walking_Map;
      end if;
      if Show_Wells then
         Show_Well_Map;
      end if;
      if In_Flight = 0 and then not Panned and then (Pan_X /= 0.0 or else Pan_Y /= 0.0)
        and then (not (Far_Wait and then Far_On) or else Far_Fresh)       --  (asked to wait for the far view: the pan too)
      then
         Cam.T_X := Cam.T_X + Pan_X;            --  glide there, streaming on the way
         Cam.T_Y := Cam.T_Y + Pan_Y;
         Panned := True;
         Put_Line ("panning by " & Img (Pan_X, 0) & "," & Img (Pan_Y, 0) & " m after"
                   & Castle.Render.Stacks_Resident'Image & " stacks");
      elsif In_Flight = 0 and then Panned and then Pan_Back and then not Pan_Home
        and then abs (Cam.X - Cam.T_X) + abs (Cam.Y - Cam.T_Y) < 0.5
      then
         Cam.T_X := Cam.T_X - Pan_X;            --  and back, the far view having filled
         Cam.T_Y := Cam.T_Y - Pan_Y;
         Pan_Home := True;
         Put_Line ("panning back with" & Castle.Render.Stacks_Resident'Image & " stacks");
      end if;

      Lap (6);
      Get_Framebuffer_Size (Win, Fw, Fh);
      if Fw > 0 and then Fh > 0 then
         Castle.Render.Draw (Castle.Camera.Eye (Cam), (Cam.X, Cam.Y, Cam.Z),
                             Castle.Camera.View_Proj (Cam, Float (Fw) / Float (Fh), Castle.Render.Far_Plane),
                             Natural (Fw), Natural (Fh), View_M);
         Hud_Stats.Stacks    := Castle.Render.Stacks_Resident;
         Hud_Stats.Quads     := Castle.Render.Quads_Resident;
         Hud_Stats.Edits     := Castle.Edits.Count;
         Hud_Stats.Awake     := Castle.Water.Awake_Count;
         Hud_Stats.Simulated := Castle.Water.Simulated_Count;
         Hud_Stats.Streaming := In_Flight;
         Castle.HUD.Build
           (W,
            (Clock      => Game_Clock,
             Weather    => Now_Weather,
             Snow       => (if Forced_Snow >= 0.0 then Forced_Snow else Climate.Snow (1)),
             Ice        => Climate.Ice,
             Focus_X    => Cam.X,
             Focus_Y    => Cam.Y,
             Focus_Z    => Cam.Z,
             Place_Held => Castle.Input.Held (Castle.Input.Place_Mode),
             Cursor     => Cursor_Hit,
             Under      => Under,
             Mouse_X    => Ptr_X,
             Mouse_Y    => Ptr_Y,
             Right_Click => Ptr_RClick,
             Seconds    => (if Record_N > 0 then 1.0 / 30.0 else Frame_Seconds),
             Show_Cursor => Script_N > 0 or else Mouse_Set),
            Hud_Stats, Tools, Show);
         if Tools.Note_Count /= Notes_Told then       --  what an order came to, for the log too
            Notes_Told := Tools.Note_Count;
            Put_Line (Castle.Text.Str (Tools.Note));
         end if;
         Castle.UI.End_Frame;
         Castle.UI.Draw;
         --  (a recording waits for its people; one with none asked for, of
         --  the land or the water, starts once the view has filled)
         if (Serfs_Out or else Castle.Colony.Has_Stake
             or else (Fill_Done >= 0.0 and then not Scn.Stake and then Lineup_N = 0 and then Walk_N = 0
                      and then Deer_N = 0 and then Deer_Walk_N = 0))
           and then Record_N > 0 and then Recorded < Record_N
           --  (and, asked to wait for them, for the whole map and the far view: from then on without a break)
           and then (Recorded > 0
                     or else ((not (Far_Wait and then Far_On) or else Far_Fresh)
                              and then (not (Hold_Wait and then Whole_Map) or else Hold_Whole)))
         then
            Recorded := Recorded + 1;
            declare
               Num : constant String := Natural'Image (10_000 + Recorded);
            begin
               Castle.Render.Screenshot (To_String (Record_Dir) & "/frame_" & Num (3 .. Num'Last) & ".png",
                                         Natural (Fw), Natural (Fh));
            end;
            if Recorded = Record_N then
               Put_Line ("recorded" & Recorded'Image & " frames in " & To_String (Record_Dir));
               if Save_Path /= Null_Unbounded_String then
                  Do_Save (To_String (Save_Path));
               end if;
               Set_Window_Should_Close (Win, 1);
            end if;
         end if;
         if Castle.Input.Pressed (Castle.Input.Screenshot) then
            Castle.Render.Screenshot (To_String (Shot), Natural (Fw), Natural (Fh));
            Put_Line ("saved " & To_String (Shot));
         end if;
      end if;
      Frame := Frame + 1;
      Title_Frames := Title_Frames + 1;

      Lap (7);
      Cpu_Ms := Float (To_Duration (Clock - Frame_Start)) * 1000.0;
      if Hitch_Ms > 0.0 and then Cpu_Ms > Hitch_Ms then
         Put_Line ("hitch: frame" & Frame'Image & " took " & Img (Cpu_Ms, 0) & " ms: input and clock " & Img (Laps (1), 0)
                   & ", streaming " & Img (Laps (2), 0) & ", setting out " & Img (Laps (3), 0)
                   & ", the colony's steps " & Img (Laps (4), 0) & ", its edits " & Img (Laps (5), 0)
                   & ", figures and marks " & Img (Laps (6), 0) & ", drawing " & Img (Laps (7), 0)
                   & " (day " & Img (Float (Game_Clock / 24.0), 2) & ")");
      end if;
      Win_Cpu_Sum := Win_Cpu_Sum + Cpu_Ms;
      Win_Cpu_Max := Float'Max (Win_Cpu_Max, Cpu_Ms);
      Win_Gpu_Sum := Win_Gpu_Sum + Castle.Render.GPU_Millis;
      if Fill_Done >= 0.0 then
         Run_Frames := Run_Frames + 1;
         Run_Cpu_Sum := Run_Cpu_Sum + Cpu_Ms;
         Run_Cpu_Max := Float'Max (Run_Cpu_Max, Cpu_Ms);
         Run_Gpu_Sum := Run_Gpu_Sum + Castle.Render.GPU_Millis;
         --  (and once nothing more is coming in: the whole map held, the far view whole)
         if (Whole_Map or else Far_On) and then (not Whole_Map or else Hold_Done >= 0.0)
           and then (not Far_On or else Far_Whole)
         then
            Held_Frames := Held_Frames + 1;
            Held_Cpu_Sum := Held_Cpu_Sum + Cpu_Ms;
            Held_Gpu_Sum := Held_Gpu_Sum + Castle.Render.GPU_Millis;
            Held_Gpu_Max := Float'Max (Held_Gpu_Max, Castle.Render.GPU_Millis);
         end if;
         if Save_At > 0 and then Run_Frames = Save_At then
            Do_Save (To_String (Save_At_Path));
         end if;
         if Load_At > 0 and then Run_Frames = Load_At then
            Do_Load (To_String (Load_At_Path));
         end if;
      end if;

      if Dig_Set and then Dig_Late and then Fill_Done >= 0.0 then
         Dig_Set := False;
         declare
            N0 : constant Natural := Castle.Edits.Count;
         begin
            for B in 1 .. Dig_Count loop
               if Pour_Of (B) > 0.0 then
                  for X in Box (B, 1) .. Box (B, 4) loop
                     for Y in Box (B, 2) .. Box (B, 5) loop
                        Castle.Water.Pour (X, Y, Natural (Pour_Of (B) * 4.0 * Float (Castle.Water.Unit)));
                     end loop;
                  end loop;
               else
                  Edit_Box (Box (B, 1), Box (B, 2), Box (B, 3), Box (B, 4), Box (B, 5), Box (B, 6), Air);
               end if;
            end loop;
            Put_Line ("dug out" & Natural'Image (Castle.Edits.Count - N0) & " edits into the loaded view, rebuilding"
                      & Rebuilding'Image & " stacks");
         end;
      end if;

      if Fill_Set and then Fill_Done >= 0.0 and then not (Dig_Set and then Dig_Late) then
         Fill_Set := False;
         declare
            N0 : constant Natural := Castle.Edits.Count;
         begin
            Edit_Box (Integer (Fill_Box (1) * 4.0), Integer (Fill_Box (2) * 4.0), Integer (Fill_Box (3) * 4.0),
                      Integer (Fill_Box (4) * 4.0) - 1, Integer (Fill_Box (5) * 4.0) - 1,
                      Integer (Fill_Box (6) * 4.0) - 1, Plank);
            Put_Line ("filled with planks:" & Natural'Image (Castle.Edits.Count - N0) & " edits");
         end;
      end if;

      --  Live water: 10 ticks a second of real time (at most 3 a frame).
      --  (This read Now - Last after Last had been set to Now: always zero,
      --  so in play the water never moved; only --simticks ran it.)
      --  At most 6 ms of it a frame: past that the water slows down, not the
      --  game.  (A flood across a valley woke stack after stack and every
      --  frame waited for all of them.)
      --  (In a recording the water steps with the frames, a thirtieth of a
      --  second each, as the colony does: it ran at whatever pace the
      --  machine wrote frames, slow motion in the video.)
      Water_Clock := Float'Min (0.3, Water_Clock + (if Record_N > 0 then 1.0 / 30.0 else Frame_Seconds));
      declare
         Water_Start : constant Time := Clock;
         Ticked      : Boolean := False;
      begin
         while Water_Clock >= Castle.Water.Tick_Seconds loop
            Castle.Water.Tick;
            Castle.Falls.Follow;
            Ticked := True;
            Water_Ticks := Water_Ticks + 1;
            Water_Clock := Water_Clock - Castle.Water.Tick_Seconds;
            if To_Duration (Clock - Water_Start) > 0.006 then
               Water_Clock := 0.0;
               exit;
            end if;
         end loop;
         if Ticked then
            Follow_Surface;
            Last_Water_Tick := Clock;
         end if;
      end;
      Castle.Render.Set_Water_Blend
        (Float (To_Duration (Clock - Last_Water_Tick)) / Castle.Water.Tick_Seconds);
      Dry_Water;
      if Castle.Water.Capped and then not Cap_Told then
         Put_Line ("water: more than" & Integer'Image (Castle.Water.Max_Awake)
                   & " stacks would be moving; the rest holds still until some settle");
         Cap_Told := True;
      end if;
      if Sim_Ticks > 0 and then Fill_Done >= 0.0 and then not (Dig_Set and then Dig_Late) and then not Fill_Set then
         for T in 1 .. Sim_Ticks loop
            Castle.Water.Tick;
            Castle.Falls.Follow;
         end loop;
         Follow_Surface;
         Follow_Surface;                      --  shown at rest: previous = current
         Put_Line ("ran" & Sim_Ticks'Image & " water ticks:" & Castle.Water.Awake_Count'Image & " stacks awake,"
                   & Castle.Water.Simulated_Count'Image & " simulated");
         Report_Water;
         Report_Boxes;
         Sim_Ticks := 0;
      end if;
      for R of Castle.Water.Take_Changed loop
         Remesh (R.CX, R.CY);
      end loop;

      --  (a running colony edits its ground all the time, so the rebuilds are
      --  not waited for once it has one)
      if Frames > 0 and then Frame >= Frames and then In_Flight = 0
        and then (not (Hold_Wait and then Whole_Map) or else Hold_Whole)
        and then (not (Far_Wait and then Far_On) or else Far_Fresh)
        and then Held_Frames >= Settle_Frames
        and then (Load_At = 0 or else Run_Frames > Load_At)
        and then (Rebuilding = 0 or else Castle.Colony.Has_Stake)
        and then not (Dig_Set and then Dig_Late) and then not Fill_Set and then Sim_Ticks = 0
        and then (not Panned or else abs (Cam.X - Cam.T_X) + abs (Cam.Y - Cam.T_Y) < 0.5)
        and then (not (Panned and then Pan_Back) or else Pan_Home)
      then
         Castle.Render.Screenshot (To_String (Shot), Natural (Fw), Natural (Fh));
         Put_Line ("view filled in " & Img (Fill_Done, 2) & " s,"
                   & Castle.Render.Stacks_Resident'Image & " stacks,"
                   & Castle.Render.Quads_Resident'Image & " quads ("
                   & Img (Float (Castle.Render.Quads_Resident) * 8.0 / 1_048_576.0) & " MB),"
                   & Castle.Render.Draws_Last_Frame'Image & " draws last frame"
                   & (if Castle.Render.Stacks_Skipped > 0
                      then ";" & Castle.Render.Stacks_Skipped'Image & " stacks found no room in the arena" else ""));
         Put_Line ("worker time per stack " & Img (Worker_Ms / Float (Integer'Max (1, Meshed)), 2)
                   & " ms (generate + mesh), " & Img (Float (Castle.Render.Quads_Resident)
                   / Float (Integer'Max (1, Castle.Render.Stacks_Resident)), 0) & " quads per stack");
         if Run_Frames > 0 then
            Put_Line ("after the fill:" & Run_Frames'Image & " frames, gpu "
                      & Img (Run_Gpu_Sum / Float (Run_Frames), 2) & " ms, cpu "
                      & Img (Run_Cpu_Sum / Float (Run_Frames), 2) & " ms (max "
                      & Img (Run_Cpu_Max, 2) & ")");
         end if;
         if Held_Frames > 0 then
            Put_Line ("settled (the map held, the far view whole):" & Held_Frames'Image & " frames, gpu "
                      & Img (Held_Gpu_Sum / Float (Held_Frames), 2) & " ms (the longest "
                      & Img (Held_Gpu_Max, 2) & "), cpu "
                      & Img (Held_Cpu_Sum / Float (Held_Frames), 2) & " ms");
            if Castle.Render.Far_Shadow_Draws > 0 then
               Put_Line ("the far shadows:" & Castle.Render.Far_Shadow_Draws'Image & " maps drawn in the run");
            end if;
         end if;
         if Whole_Map then
            declare
               N : Natural := 0;
            begin
               for CX in 0 .. Chunks_XY - 1 loop
                  for CY in 0 .. Chunks_XY - 1 loop
                     if Held (CX, CY) then
                        N := N + 1;
                     end if;
                  end loop;
               end loop;
               Put_Line ("the map held:" & N'Image & " of" & Integer'Image (Chunks_XY * Chunks_XY) & " stacks"
                         & (if Hold_Done >= 0.0 then ", all of it " & Img (Hold_Done, 1) & " s after the first frame"
                            else " (not all of it yet)")
                         & ";" & Holds_Taken'Image & " came without a mesh, "
                         & Img (Hold_Ms / Float (Integer'Max (1, Holds_Taken)), 2) & " ms of a worker each;"
                         & " the main thread gave the holding " & Img (Hold_Main_Ms, 0) & " ms in all, "
                         & Img (Hold_Main_Max, 2) & " in its worst frame");
            end;
         end if;
         if Far_On then
            Put_Line ("the far view:" & Castle.Render.Far_Tiles_Resident'Image & " tiles,"
                      & Castle.Render.Far_Quads_Resident'Image & " quads ("
                      & Img (Float (Castle.Render.Far_Quads_Resident) * 8.0 / 1_048_576.0) & " MB),"
                      & Castle.Render.Far_Draws_Last_Frame'Image & " of them drawn in the last frame ("
                      & Castle.Render.Far_Sent_Last_Frame'Image & " quads sent);"
                      & Far_Made'Image & " made, " & Img (Far_Ms / Float (Integer'Max (1, Far_Made)), 1)
                      & " ms of a worker each"
                      & (if Far_Done >= 0.0 then "; whole " & Img (Far_Done, 1) & " s after the first frame"
                         else "; not whole yet") & (if Far_Whole then "" else " (some wanted now)"));
         end if;
         if Castle.Streaming.Lost > 0 then
            Put_Line ("STREAMING LOST" & Castle.Streaming.Lost'Image & " jobs: the queue was full");
         end if;
         for K in 1 .. Probe_N loop
            declare
               Bx : constant Integer := Integer (Float'Floor (Probes (K).X * 4.0));
               By : constant Integer := Integer (Float'Floor (Probes (K).Y * 4.0));
               Bz : constant Integer := Integer (Float'Floor (Probes (K).Z * 4.0));
            begin
               Put_Line ("block at " & Img (Probes (K).X, 2) & ", " & Img (Probes (K).Y, 2) & ", " & Img (Probes (K).Z, 2)
                         & ": " & Castle.World_Blocks.Block_At (Bx, By, Bz).Mat'Image
                         & (if not Held (Bx / Chunk_B, By / Chunk_B) then " (its stack is not held)"
                            elsif States (Bx / Chunk_B, By / Chunk_B) = Loaded then " (its stack is drawn)"
                            else " (its stack is held and not drawn)"));
            end;
         end loop;
         if Show_Mem then
            Put_Mem;
         end if;
         Put_Line ("camera: wanted " & Img (Cam.Dist, 1) & " m at tilt " & Img (Cam.Pitch, 2)
                   & ", held at " & Img (Cam.Held, 1) & " m and tilt " & Img (Cam.Held_Pitch, 2)
                   & " to stay clear of the ground");
         Put_Line ("saved " & To_String (Shot));
         Put_Line ("water ticks run in real time:" & Water_Ticks'Image & ";" & Castle.Water.Awake_Count'Image
                   & " stacks awake," & Castle.Water.Simulated_Count'Image & " simulated");
         if Castle.Falls.Sheets > 0 then
            Put_Line ("falls: sheets over" & Castle.Falls.Sheets'Image & " columns;" & Air_Builds'Image
                      & " stacks built again to draw them");
         end if;
         if Hitch_Ms > 0.0 then            --  (with --hitch: what the walking map had to read again, and how)
            Put_Line ("walking map read anew:" & Castle.Nav.Totals.Stacks_Built'Image & " stacks whole,"
                      & Castle.Nav.Totals.Stacks_Mended'Image & " mended where the ground changed");
         end if;
         if Castle.Water.Simulated_Count > 0 then
            Report_Water;
         end if;
         if Dig_Count > 0 then
            Report_Boxes;
         end if;
         if Save_Path /= Null_Unbounded_String then
            Do_Save (To_String (Save_Path));
         end if;
         exit;
      end if;

      if Now - Title_Clock >= 0.5 then
         declare
            N : constant Float := Float (Integer'Max (1, Title_Frames));
         begin
            Hud_Stats.Fps     := Float (Title_Frames) / Float (Now - Title_Clock);
            Hud_Stats.Gpu_Ms  := Win_Gpu_Sum / N;
            Hud_Stats.Cpu_Ms  := Win_Cpu_Sum / N;
            Hud_Stats.Cpu_Max := Win_Cpu_Max;
            Castle.Platform.Set_Title
              (Win, "Castle  " & Img (Float (Title_Frames) / Float (Now - Title_Clock), 0) & " fps"
               & "  gpu " & Img (Win_Gpu_Sum / N, 2) & " ms"
               & "  cpu " & Img (Win_Cpu_Sum / N, 2) & " ms (max " & Img (Win_Cpu_Max, 1) & ")"
               & "  " & Date_Text
               & "  " & Img (Cam.X, 0) & "," & Img (Cam.Y, 0)
               & "  " & Img (Float (Castle.Render.Quads_Resident) / 1.0E6) & "M quads"
               & "  [" & (if Castle.Input.Held (Castle.Input.Place_Mode) or else Tools.Place
                          then "place " & Material'Image (Palette (Pick)) else "dig")
               & (case Brush is when 1 => " 25 cm", when 4 => " 1 m", when others => " 2 m") & "]"
               & (if Castle.Edits.Count > 0 then Castle.Edits.Count'Image & " edits" else "")
               & (if Castle.Water.Awake_Count > 0 then "  water:" & Castle.Water.Awake_Count'Image & " awake" else "")
               & (if In_Flight > 0 then "  streaming" & In_Flight'Image else ""));
         end;
         Title_Clock := Now;
         Title_Frames := 0;
         Win_Cpu_Sum := 0.0;
         Win_Cpu_Max := 0.0;
         Win_Gpu_Sum := 0.0;
      end if;

      Swap_Buffers (Win);
   end loop;

   Castle.Streaming.Stop;
   Castle.Platform.Close (Win);
end Castle_Game;
