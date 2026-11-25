with Castle.Blocks;      use Castle.Blocks;
with Castle.Climate;
with Castle.Maps;
with Castle.Math;        use Castle.Math;
with Castle.Pick;
with Castle.Text;
with Castle.World_Blocks;

--  The game's on-screen panels, built from Castle.UI each frame:
--    status (top left)    the date, time and weather, snow and ice
--    tools (top right)    dig or place, brush size, material: clickable
--    ground (bottom left) the block under the cursor: what it is, the
--                         well that could be sunk there, moisture
--    debug (bottom right, F3)   frame times, streaming, edits, water
--    survey (F2)          the nearest deposits (a developer's view: it
--                         shows what the colony has not found)
--    help (F1)            the keys
--    the band (Tab)       under the tools: the band's food and confidence,
--                         and four tabs: Band (everyone in a scroll list:
--                         follow, job, what they are doing), Stores, Camp,
--                         Orders (the reserves and the protections), Skills
--                         (everyone's level in each working skill, marked
--                         by how fast they learn it)
--  F4 hides them all.  Everything shown is read from the game; nothing is
--  invented for show.
--
--  These panels are the development interface: dense, complete, on Tab and
--  the F-keys.  What the game's own interface is made of is here too, and
--  nothing of it depends on the panels: a tooltip on whatever the cursor's
--  ray points at (a person, a zone, a deer) and a context menu on a right
--  click, both built from the same data views (Castle.Views) and the same
--  action table (Castle.Actions) the panels use.  Tooltips say; menus do.
--  Nothing here pauses the game or covers the world.
package Castle.HUD is

   type Palette_Array is array (1 .. 7) of Material;
   Palette : constant Palette_Array := [Plank, Log, Shingle, Granite, Dirt, Sand, Footpath];

   type Tool_Mode is (Edit, Stake, Path, Stockpile, Camp, Housing, Stockyard, Unzone);
   --  What a left click on the ground does: dig or place (Edit), raise the
   --  homestake, lay a path from the last point, zone a stockpile corner to
   --  corner, zone the camp (the fire where it is clicked), zone housing
   --  corner to corner; Unzone: take housing out again, corner to corner
   --  (begun from the ground's menu on housing).

   type Band_Tab is (People_Tab, Stores_Tab, Camp_Tab, Orders_Tab, Skills_Tab);
   Band_Rows : constant := 12;       --  people shown at once in the band's list

   Note_S : constant := 4.0;         --  seconds a note stays up

   type Tool_State is record
      Place  : Boolean   := False;   --  sticky place mode (Ctrl places while held as well)
      Brush  : Positive  := 4;       --  blocks: 1 (25 cm), 4 (1 m), 8 (2 m)
      Pick   : Positive  := 1;       --  index into Palette
      Mode   : Tool_Mode := Edit;
      Speed  : Natural   := 1;       --  0 paused, 1 .. 3
      Follow : Natural   := 0;       --  the member the eye follows (0: nobody)
      Tab    : Band_Tab  := People_Tab;   --  the band panel's chosen tab
      Band_Top : Natural := 0;       --  its list: rows scrolled past
      Skills_Top : Natural := 0;     --  and the Skills tab's list
      --  a path line or a stockpile half drawn: where it was begun
      Path_From    : Vec3 := (0.0, 0.0, 0.0);
      Path_Started : Boolean := False;
      Zone_From    : Vec3 := (0.0, 0.0, 0.0);
      Zone_Started : Boolean := False;
      --  a box held to be put down (the stockpile): the way it is turned, an
      --  eighth a step (Castle.Colony.Way_Index), and why it would be
      --  refused where it is held ("": it would not), said by the cursor
      Way          : Natural := 0;
      Warn         : Castle.Text.Line;
      --  housing pulled with its path: which rows (0: the side it was begun
      --  on, 1: the other, 2: both: Castle.Colony.Pull_Rows by position)
      Rows         : Natural := 0;
      Last_Done    : Boolean := True;   --  the last order was carried out
      --  what the last order came to, said for a few seconds (and to the log)
      Note       : Castle.Text.Line;
      Note_Bad   : Boolean := False;   --  it was refused
      Note_Left  : Float := 0.0;       --  seconds it still shows
      Note_Count : Natural := 0;       --  goes up with each new note
   end record;

   type Shown is record
      Visible : Boolean := True;
      Help    : Boolean := False;
      Survey  : Boolean := False;
      Debug   : Boolean := False;
      Band    : Boolean := True;     --  Tab: the band and the stockpile (once there is a colony)
   end record;

   type Stats is record
      Fps, Gpu_Ms, Cpu_Ms, Cpu_Max : Float := 0.0;
      Stacks, Edits, Awake, Simulated, Streaming : Natural := 0;
      Quads : Natural := 0;
   end record;

   type Status is record
      Clock      : Castle.Climate.Game_Hours := 0.0;
      Weather    : Castle.Climate.Weather;
      Snow       : Float := 0.0;     --  metres on open ground in the valley
      Ice        : Float := 0.0;     --  0 open .. 1 frozen
      Focus_X, Focus_Y, Focus_Z : Float := 0.0;   --  metres
      Place_Held : Boolean := False;
      Cursor     : Castle.World_Blocks.Hit;
      Under      : Castle.Pick.Thing;      --  what the cursor's ray points at (nothing, over a panel)
      Mouse_X, Mouse_Y : Float := 0.0;     --  the cursor (pixels)
      Right_Click : Boolean := False;      --  the right button was clicked this frame, without a drag
      Seconds    : Float := 0.0;           --  real time this frame took
      Show_Cursor : Boolean := False;      --  draw an arrow at the cursor (scripted runs have no real one)
   end record;

   procedure Build
     (W     : Castle.Maps.World;
      S     : Status;
      St    : Stats;
      Tools : in out Tool_State;
      Show  : Shown);
   --  Between Castle.UI.Begin_Frame and End_Frame.

   procedure Say (Tools : in out Tool_State; S : String; Bad : Boolean := False);
   --  A note at the foot of the screen for a few seconds: what something
   --  the player just did came to (the game puts it in the log too).

   ------------------------------------------------------- the pointer

   procedure Point
     (Under         : Castle.Pick.Thing;
      X, Y          : Float;               --  the cursor (pixels)
      Clicked       : Boolean;             --  the left button went down
      Right_Clicked : Boolean;             --  the right button was clicked, without a drag
      Tools         : in out Tool_State;
      For_World     : out Boolean);
   --  Once a frame, after Castle.UI.Begin_Frame and before the world acts
   --  on a click.  A right click opens the context menu of what is under the
   --  cursor (the ground, where there is nothing else), closing any other;
   --  a left click away from an open menu closes it and goes no further.
   --  For_World: the left click is the world's to have (a tool's, on the
   --  ground).

   procedure Ground_Click (P : Vec3; Tools : in out Tool_State);
   --  A left click on the ground at P (metres) with a colony tool in hand:
   --  the stake raised, the path's next point, a stockpile's corner, the
   --  camp.  Through the action table, as the menu's choices go.

   function Cancel (Tools : in out Tool_State) return Boolean;
   --  Esc: the menu closed, or the path line or the stockpile half drawn
   --  ended, or a box held to be put down put away.  False: there was
   --  nothing to cancel.

   function Menu_Open return Boolean;
   function Menu_On return Castle.Pick.Thing;   --  what the open menu is about (to mark it in the world)

   function Pretty (M : Material) return String;   --  Iron_Ore -> "Iron ore"
   function Compass (Dx, Dy : Float) return String;   --  +y is north: "N", "NE", ...

end Castle.HUD;
