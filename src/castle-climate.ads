with Castle.Hash; use Castle.Hash;

--  Seasons and weather.
--
--  The calendar and the weather are functions of the game clock and the
--  world seed, so the only thing a save needs for them is the clock.  The
--  one piece of state is what the weather leaves behind: snow on the ground
--  (at three heights, so peaks keep theirs longer than valleys), lake ice
--  and wet ground.  It is advanced in fixed 15-minute steps with plain
--  arithmetic, so every machine gets the same winter.
package Castle.Climate is

   Days_Per_Season : constant := 15;
   Days_Per_Year   : constant := 4 * Days_Per_Season;   --  spring, summer, autumn, winter
   type Season is (Spring, Summer, Autumn, Winter);

   --  Game clock: hours since dawn of the first day of spring, year 1.
   subtype Game_Hours is Long_Float;

   function Day_Of_Year (T : Game_Hours) return Float;   --  0 .. Days_Per_Year, fractional
   function Hour_Of_Day (T : Game_Hours) return Float;   --  0 .. 24
   function Season_Of (Day : Float) return Season;
   function Day_Of_Season (Day : Float) return Positive;  --  1 .. Days_Per_Season

   --  The weather at the valley floor (16 m).
   type Weather is record
      Temperature    : Float := 10.0;   --  degrees C
      Cloud_Cover    : Float := 0.4;    --  0 clear .. 1 overcast
      Rain, Snow     : Float := 0.0;    --  falling now, 0 .. 1
      Wind_X, Wind_Y : Float := 3.0;    --  m/s
   end record;

   function Weather_At (Seed : U64; T : Game_Hours) return Weather;

   Lapse_Per_M : constant := 0.065;
   --  Degrees colder per metre up.  Ten times the real lapse rate, so a
   --  160 m peak is 9 degrees colder than the valley and keeps its snow.

   function Temperature_At (W : Weather; Z_M : Float) return Float is
     (W.Temperature - Lapse_Per_M * (Z_M - 16.0));

   function Sun_Height (T : Game_Hours) return Float;
   --  Sine of the sun's elevation: high long summer days, a low short arc in
   --  winter (latitude 47 degrees).  Negative at night.

   type Level is range 1 .. 3;
   Level_Z : constant array (Level) of Float := (16.0, 70.0, 140.0);
   type Level_Depths is array (Level) of Float;

   type State is record
      T    : Game_Hours := 0.0;               --  the clock this state is valid at
      Snow : Level_Depths := (others => 0.0); --  metres of snow on open ground at each level
      Ice  : Float := 0.0;                    --  lake ice, 0 open .. 1 frozen
      Wet  : Float := 0.0;                    --  wet ground after rain, 0 .. 1
   end record;

   procedure Start (S : out State; Seed : U64; T : Game_Hours);
   --  The state at T: the weather of the 30 days before it, played through.

   procedure Advance (S : in out State; Seed : U64; T : Game_Hours);
   --  Forward to T in fixed 15-minute steps (no-op if T is not later).

   function Snow_At (S : State; Z_M : Float) return Float;
   --  Metres of snow on open ground at height Z.

   Moon_Days : constant := 10.0;
   --  From one full moon to the next: six moons to the year.
   Moon_Full_Day : constant := 20.5;
   --  A day on which the moon is full (the game's default start is the
   --  afternoon of day 20, so the first night has one).

   function Moon_Phase (T : Game_Hours) return Float;
   --  The moon's phase at T: 0 new, 0.25 the first quarter, 0.5 full, 0.75
   --  the last, of the way round from the sun.  The clock's alone: nothing
   --  saved, and nothing the colony knows.

   function Mist (Seed : U64; T : Game_Hours; W : Weather; S : State) return Float;
   --  How much mist lies on the land, 0 (none) to 1: the weather's and the
   --  clock's, with what the rain left (S.Wet), so it needs nothing saved.
   --  It gathers through the night, from about ten, and stands thickest
   --  before dawn; the sun burns it off as it climbs (by seven of a summer
   --  morning, by eleven in winter, later under cloud); wind over about
   --  2 m/s thins it and 5 m/s clears it; falling rain or snow takes its
   --  place.  Whether a night is a damp one goes by a chance that turns
   --  over every day and a half, by the season (most in spring and autumn)
   --  and by how wet the ground is; a hard frost dries the air.  Only something seen:
   --  the colony does not know of it.
   Mist_Gather_From : constant := 22.0;   --  the hour it begins to gather
   Mist_Full_By     : constant := 4.0;    --  ... and stands thickest
   Mist_Burn_Lo     : constant := 0.08;   --  the sun's height (sine) that starts to burn it off,
   Mist_Burn_Hi     : constant := 0.30;   --  and the height it is gone by
   Mist_Calm        : constant := 2.0;    --  wind (m/s) that starts to thin it,
   Mist_Wind        : constant := 5.0;    --  and that clears it

   --  Vegetation by the calendar, each 0 .. 1.
   function Leaf_Turn (Day : Float) return Float;   --  autumn colour of broadleaf trees
   function Leaf_Fall (Day : Float) return Float;   --  share of their leaves gone
   function Grass_Dry (Day : Float) return Float;   --  0 lush .. 1 dead

end Castle.Climate;
