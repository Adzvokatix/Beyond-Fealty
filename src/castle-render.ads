with Castle.Maps;
with Castle.Math;   use Castle.Math;
with Castle.Mesher; use Castle.Mesher;

--  World renderer.  One shader, vertex pulling: every stack's quads live in
--  one big GPU buffer, and a frame is two multi-draw-indirect calls (solid,
--  then water) over the stacks inside the view frustum.
package Castle.Render is

   procedure Init (W : Castle.Maps.World; Capacity_Quads : Positive; Samples : Natural);
   --  Needs a current OpenGL 4.5+ context.  Uploads the block textures and
   --  the 1 m height field, which lights distant ground smoothly.  With
   --  Samples >= 2 the world is drawn into the renderer's own multisampled
   --  target and resolved to the window, so MSAA never depends on what the
   --  window system offers; cut-out coverage then uses alpha-to-coverage.

   function MSAA_Samples return Natural;   --  0 when drawing straight to the window

   Shadows : Boolean := True;   --  the sun's shadows, and the fire's (--noshadows)

   Near_First : Boolean := True;
   --  The land's stacks are drawn the nearest to the eye first, so what is
   --  hidden behind what is already drawn is thrown out by its depth before
   --  it is shaded (they were drawn in the order they were loaded).  The
   --  picture is the same.  Off (--loadorder): as it was, for measuring.

   --  The sun's shadows (first values).  The land's are drawn into a depth
   --  map over everything loaded, and whatever Castle.Figures draws (people,
   --  deer, props) into a second, finer one round the focus, every frame.
   --  Neither is drawn for where the sun is, which changes every frame the
   --  clock runs: a map drawn anew for each new direction lands on new
   --  texels each time, and every shadow in the view flickers.  They are
   --  drawn for two held directions instead, one the sun has passed and one
   --  it is coming to, and the shade is mixed from the two by how far along
   --  the sun is; between two steps nothing changes but the mix.
   Shadow_Hold       : constant := 0.01;
   --  How far on the next held direction lies: where shadows will have
   --  moved this far for each metre of what casts them (a 10 m tree's, 10 cm).
   Shadow_Min_Frames : constant := 12;
   --  ... and never so near that the sun gets there in fewer frames (a low
   --  sun, a fast clock): the land's map is drawn at most that often.
   Shadow_Low_Sun    : constant := 0.07;
   --  The sine of the lowest sun shadows are cast from (4 degrees): below
   --  it they keep that length and fade with the light, down to sunset.
   Shadow_Snap       : constant := 64;
   --  The land's map moves with the focus this many texels at a time, so
   --  panning seldom draws it again.
   Figure_Shadow_M   : constant := 24.0;
   Figure_Shadow_By  : constant := 3.0;
   --  Half the width of the figures' map at its smallest (1.2 cm texels);
   --  it is doubled until it is Figure_Shadow_By times the eye's distance
   --  from the focus (at a low tilt the view reaches about that far beyond
   --  the focus), up to the land's own map: 24 m with the eye within 8 m,
   --  48 m within 16, 96 m within 32.
   Contact_Shade     : constant := 0.22;
   --  The soft disc under a figure (Castle.Figures.Add_Shadow) where no
   --  sun reaches to cast its shadow (night, overcast): this dark at most.
   Reflections : Boolean := True;
   --  Open water mirrors the world as well as the sky: the land, the trees
   --  and the people in the picture, found by walking the reflected ray
   --  out through the picture's own depths.  Off (--noreflect), or where
   --  the picture cannot be read back (no multisampled target), it mirrors
   --  the sky alone, as it did.

   --  The sky (John, 2026-11-11: "Volumetric clouds, no moon, black sun in
   --  winter when snowing"; first values).  It is put together in one order
   --  everywhere it is drawn or mirrored: the gradient from the horizon to
   --  the zenith, then the sun and the moon, which only ever add light to
   --  what is behind them (the sun's disc was mixed in at the colour of its
   --  light on the land, which overcast and a low sun take nearly all of: a
   --  dark disc on a pale sky), then the clouds over both.
   --
   --  The moon (John, 2026-11-11, on being asked: "Moonlight on the land,
   --  phases, stars.  Sounds great"; first values).  It goes round from the
   --  sun by its phase (Look.Moon: 0 new, 0.5 full; the game takes it from
   --  the clock, Castle.Climate.Moon_Phase): new, it is with the sun and
   --  unseen; full, it stands where the sun is not, rising as the sun sets,
   --  high in winter and low in summer; between, it is up for part of the
   --  day and part of the night, and its disc is a ball lit from where the
   --  sun is.  Once the sun's light has left the land the moon's falls on it
   --  (Moonlight at the full, high in a clear sky; much less at the
   --  quarters; none at the new moon, or while it is down), with shadows
   --  through the same held maps as the sun's.  Under it the night's own
   --  light is as it was: a night with no moon is the night there was.
   --
   --  The stars: about Star_Share of Star_Cells x Star_Cells x 6 squares of
   --  the sky have one, a soft dot Star_Size across at most (radians), few
   --  bright and many faint; they turn about the pole with the clock, come
   --  out as the day goes, are fewer by a bright moon and none through
   --  cloud.  Only the sky pass draws them: water does not mirror them.
   Stars      : Boolean := True;      --  off (--nostars)
   Moonlight  : constant := 0.30;     --  the full moon's light on the land, of the scale the sun's 0.72 is on
   Star_Cells : constant := 56.0;
   Star_Share : constant := 0.30;
   Star_Size  : constant := 0.0026;
   Shadow_Least : constant := 0.004;
   --  The land's light fainter than this casts no shadows worth the maps
   --  (a thin moon low down): they are not drawn.
   --
   --  The clouds are a slab of air Cloud_Lo_M to Cloud_Hi_M up, and where
   --  they stand in it is the weather's own map, the one their shadows on
   --  the ground have always gone by (so a shadow lies under its cloud): a
   --  cloud is flat underneath and stands as tall as it is deep into the
   --  map, and a noise in three dimensions bites its edges into billows.
   --  The clouds' pass walks a ray of the sky through the slab for every
   --  pixel of a picture half the window's size each way, in long strides
   --  through clear air and short steps in cloud, and at each step that is
   --  in cloud looks three times toward the sun (the moon by night) for how
   --  much cloud lies in the light's way.  Only that pass walks: the land's
   --  and the figures' shaders, and the water's mirror of the sky, still
   --  take the flat map (a tap or two).  Nothing in a still view changes
   --  from frame to frame but the clouds' own drift.
   Volumetric  : Boolean := True;     --  off (--flatclouds): one flat layer, as it was
   Cloud_Lo_M  : constant := 650.0;
   Cloud_Hi_M  : constant := 1_250.0;
   Cloud_Steps : constant := 128;     --  at most, to a ray
   Cloud_Step        : constant := 0.008;
   Cloud_Step_Min_M  : constant := 14.0;
   Cloud_Step_Max_M  : constant := 70.0;
   --  A step in or near a cloud: this share of how far off it is (16 m at
   --  2 km, 40 m at 5 km), within these.
   Cloud_Stride_M    : constant := 260.0;   --  the longest stride through clear air
   Cloud_Thick : constant := 0.030;   --  how much light a metre of full cloud stops (1/m)
   Cloud_Far_M : constant := 15_000.0;
   --  Clouds further off than this are not walked: they fade into the
   --  horizon's own colour from a third of the way out.

   --  Mist (John, 2026-11-11: "Mist/fog?"; first values).  A layer of it
   --  lying on the land: thickest at the land's own level thereabouts (the
   --  mean over 80 m, the water's where there is open water), so it pools in
   --  hollows and over lakes and a rise stands out of it; thinning upward by
   --  e for every Mist_Height_M; half as thick again by open water as far
   --  from any.  At its thickest (Look.Mist 1) a metre of it at its floor
   --  stops Mist_Thick of the light: looking along it from a man's height, a
   --  tree 30 m off is half gone; looking down on it from the usual tilt, a
   --  quarter of the ground's colour is.  It takes the colour of the sky it
   --  lies under.  How much there is (Look.Mist) is the weather's to say
   --  (Castle.Climate.Mist).  Worked out along the line of sight, exactly,
   --  in the same routine that hazes the edge of the loaded world (air, in
   --  the shared sky source): no pass, no texture but the land's level.
   Mists         : Boolean := True;   --  off (--nomist): none is drawn
   Mist_Height_M : constant := 5.0;
   Mist_Thick    : constant := 0.045;
   Mist_From_Above : constant := 0.5;
   --  Looked down on steeply, mist is drawn that much thinner than it is:
   --  the colony under it has to stay readable.

   --  Wet surfaces (John, 2026-11-11: "wet surfaces"; first values).  What
   --  the rain reaches is wet by Look.Wet; what a roof or a crown shelters
   --  (the map that looks straight down, which the snow goes by) is only
   --  Wet_Sheltered of that.  Wet, a thing is darker (Wet_Dark; earth, sand
   --  and bark soak it up: Wet_Soak) and richer in colour (Wet_Rich); it
   --  mirrors the sky, the more the flatter it is seen (rock and planks
   --  Wet_Shine_Hard of what glass would, turf, leaves and earth
   --  Wet_Shine_Soft); and it glints where the sun comes off it
   --  (Wet_Glint).  On level bare earth and rock under the open sky water
   --  stands in pools: by place, on a noise, so the same pools after every
   --  rain; hardly any until the ground is half wet (the noise over
   --  Pool_None), and at its wettest where the noise is over Pool_Most
   --  (about a third of level bare ground);
   --  not on ground that slopes more than Pool_Slope (m/m, by the 1 m
   --  height field).  A pool is the ground darker still (Pool_Dark) with the
   --  sky in it as open water has it (Water_Mirror, Water_Glance), ringed
   --  by the rain while it falls; open water is ringed too.  All in the
   --  land's own shader: no pass, no texture.
   Wetness        : Boolean := True;   --  off (--nowet): nothing is drawn wet
   Wet_Sheltered  : constant := 0.35;
   Wet_Dark       : constant := 0.16;
   Wet_Soak       : constant := 0.36;
   Wet_Rich       : constant := 0.20;
   Wet_Shine_Hard : constant := 0.85;
   Wet_Shine_Soft : constant := 0.30;
   Wet_Glint      : constant := 0.9;
   Pool_None      : constant := 0.70;
   Pool_Most      : constant := 0.54;
   Pool_Slope     : constant := 0.20;
   Pool_Dark      : constant := 0.30;

   --  How the world looks right now: the sun's place by the calendar, the
   --  weather, and what the season and the weather have left on the ground.
   type Look is record
      Day           : Float := 20.0;   --  day of the 60-day year (fractional)
      Hour          : Float := 15.0;
      Cloud_Cover   : Float := 0.45;   --  0 clear .. 1 overcast
      Rain          : Float := 0.0;    --  falling now, 0 .. 1
      Snowfall      : Float := 0.0;
      Wind_X        : Float := 3.0;    --  m/s
      Wind_Y        : Float := 1.2;
      Snow_Lo       : Float := 0.0;    --  metres of snow on open ground at 16 m,
      Snow_Mid      : Float := 0.0;    --  at 70 m,
      Snow_Hi       : Float := 0.0;    --  and at 140 m
      Ice           : Float := 0.0;    --  lakes and rivers: 0 open .. 1 frozen
      Wet           : Float := 0.0;    --  wet ground after rain
      Mist          : Float := 0.0;    --  0 none .. 1 thick
      Moon          : Float := 0.5;    --  the moon's phase: 0 new, 0.5 full, of the way round from the sun
      Moon_Per_Day  : Float := 0.1;    --  how far it goes round in a day
      Leaf_Turn     : Float := 0.0;    --  broadleaf autumn colour
      Leaf_Fall     : Float := 0.0;    --  share of broadleaf leaves fallen
      Grass_Dry     : Float := 0.0;    --  0 lush .. 1 dead
      Seconds       : Float := 0.0;    --  real clock: clouds, ripples, falling snow
   end record;

   procedure Set_Look (L : Look);

   --  Lights (John, 2026-11-11: "deferred lighting techniques if not already
   --  implemented or not effective"; first values).  The renderer is a
   --  forward one: every fragment is lit as it is drawn, into a multisampled
   --  target, and leaves, grass and smoke are cut out by coverage.  What
   --  deferred lighting is for is many lights at a cost that does not grow
   --  with their number, and that is had here without giving those up: the
   --  lights are a table, and for every Light_Cell_M of the world the
   --  renderer keeps which of them reach it (64 bits a cell), so a fragment
   --  sums only the lights of its own cell: none, away from any.
   --
   --  The game gives the frame's lights each frame: Clear_Lights, then
   --  Add_Light for each (a fire's place and strength 0 .. 1, flickering and
   --  wandering as the caller likes: Castle.Fire gives both).  Of those
   --  whose reach comes into the view the Max_Lights nearest the focus
   --  light the world.
   --
   --  One of them casts shadows, the nearest to the focus (first values):
   --  the land round it and every figure are drawn into the six faces of a
   --  cube of depth maps about the light, every frame, by the same routine
   --  as the sun's (so whatever casts from the sun casts from the fire).
   --  Nothing within Fire_Near_M of the light casts: the fire's own stones,
   --  its bed, and the pot hung just over it, which would darken everything
   --  above a man's waist.  What stands in a shadow, or is turned from a
   --  light, still has Fire_Fill of its light (the glow off the ground and
   --  the smoke; without it a figure's far side is cut out black).  The
   --  other lights shine through whatever stands in their way.
   Max_Lights   : constant := 64;
   Fire_Reach_M : constant := 10.0;   --  a fire's light falls away to nothing over this
   Fire_Near_M  : constant := 0.6;
   Fire_Fill    : constant := 0.25;
   Fire_By_Day  : constant := 0.35;
   --  How much of a light shows by day, in any weather (the eye is set
   --  for the day: a fire at noon lights its own stones and little else).
   --  It comes up as the day goes down, to all of it at night.
   procedure Clear_Lights;
   procedure Add_Light (At_P : Vec3; Strength : Float; Reach_M : Float := Fire_Reach_M;
                        Colour : Vec3 := (1.0, 0.55, 0.22));
   function Lights_In_View return Natural;   --  as last drawn

   Marks_By_Night : constant := 0.22;
   --  How bright a mark that is of the ground (Castle.Marks, Of_Ground: a
   --  zone filled in) is drawn at night, of its colour by day: it is no
   --  light of its own.

   procedure Upload (CX, CY : Integer; M : Mesh);    --  replaces any old mesh
   procedure Unload (CX, CY : Integer);

   --  Surface water: every loaded stack's open-sky water, per block column,
   --  in a texture that wraps round the camera.  Each texel holds the
   --  column's previous and current water level and the floor under it,
   --  all in block rows; the water pass draws surface cells (a top and four
   --  sides per column) at the level blended between the two, so the water
   --  moves smoothly between the simulation's ticks and a change in level
   --  needs no new mesh.  A floor of 4095 hides a column.
   --
   --  Falls.  Air is the sheet of a fall passing over the column
   --  (Castle.Falls.Air: its top in sixteenths of a block, times 1024,
   --  plus its thickness in sixteenths; 0: none).  A second cell drawn for
   --  the column (a quad with z = 1 beside its surface cell: six faces, the
   --  underside too) is that sheet: a slab, joined to the sheets beside
   --  it into one stepped arch, lit as falling water and whiter
   --  (Fall_White and Fall_Streak of the light, Fall_Alpha), mirroring
   --  nothing.  Under a sheet that falls free, water thinner than a block
   --  is not drawn (it is the same water, which the simulation has running
   --  down the face), and a column draws no curtain down a side by which a
   --  sheet leaves.
   type Surface_Texel is record
      Prev, Cur, Floor, Air : Float := 0.0;
   end record with Convention => C;
   Fall_White  : constant := 0.16;
   Fall_Streak : constant := 0.46;
   Fall_Alpha  : constant := 0.80;
   type Surface_Block is array (0 .. 31, 0 .. 31) of Surface_Texel
     with Convention => C;                                   --  (y, x): rows run along x
   Hidden_Floor : constant Float := 4095.0;

   procedure Set_Water_Reach (Metres : Float);              --  before Init: the view radius
   procedure Set_Surface (Bx0, By0 : Integer; S : Surface_Block);
   procedure Hide_Surface (Bx0, By0 : Integer);             --  its stack was unloaded
   procedure Set_Water_Blend (B : Float);                   --  0 previous .. 1 current

   --  The current (m/s) on the 1 m flow map, which the water's ripples
   --  follow; Init loads the generated currents, the simulation overwrites
   --  a stack's 8 x 8 cells while it moves and puts them back when it rests.
   type Current_Block is array (0 .. 7, 0 .. 7, 0 .. 1) of Float
     with Convention => C;                                   --  (y, x, east/north)
   procedure Set_Currents (Mx0, My0 : Integer; C : Current_Block);
   procedure Reset_Currents (CX, CY : Integer);
   procedure Set_Flow_Debug (On : Boolean);                 --  colour water by its current
   --  Deeper water, deeper hue (first values).  A column's water takes
   --  its colour from its own depth: Storm Blue in the shallows, turning to
   --  Royal Indigo over Water_Hue_M metres and on to Abyss Blue over
   --  Water_Abyss_M; and it hides its bed by how much water is looked
   --  through (the depth over the cosine of the view): as clear as it ever
   --  was (Water_Thin_Alpha) where it is thin, all but opaque
   --  (Water_Deep_Alpha) once Water_Clear_M metres lie in the way.
   Water_Hue_M      : constant := 2.0;
   Water_Abyss_M    : constant := 12.0;
   Water_Clear_M    : constant := 2.5;
   Water_Thin_Alpha : constant := 0.62;
   Water_Deep_Alpha : constant := 0.97;

   --  How much of what it mirrors shows (first values): Water_Mirror
   --  looking straight down, rising to all of it at a glancing view by the
   --  power Water_Glance (5 is Schlick's, as glass does; lower shows more
   --  from the usual view above).
   Water_Mirror : constant := 0.12;
   Water_Glance : constant := 2.5;

   --  Foliage drawn soft (John, 2026-11-11: foliage "needs a bit more organic
   --  feel to it"; first values).  The mesher gives a face of leaves, or of
   --  a bush, that lies along an edge or at a corner of its clump to a quad
   --  of its own, and says how each corner of the block grid there lies to
   --  the foliage about it (Castle.Mesher, "Soft quads"); the vertex shader
   --  moves those corners, the same way for every face that meets one: cut
   --  back Foliage_Cut of a block along each axis the corner is open on, so
   --  a clump is rounded off, and astray by up to Foliage_Jitter of a block
   --  by where it is, so no two edges are alike.  A flat side stays where
   --  it is (and is meshed as it always was: moving it too cost two fifths
   --  more quads over the whole view for little that showed).
   --  The light's normal turns over a cut edge (Foliage_Bend) and by a
   --  little from block to block (Foliage_Ruffle), so a side of a crown is
   --  no longer one flat tone; the crown is lighter and darker in masses a
   --  metre or so across (Foliage_Mass, on a noise); what stands out of a
   --  clump is a little lighter (Foliage_Lift) and has more gaps between its
   --  leaves (Foliage_Ragged: that share of its texels at a clump's very
   --  corner are open, none on a flat side), so a crown's outline frays.
   --  Nothing moves with time: the shadows are held still.  The texels are
   --  as they were, laid on the block grid before it is moved.
   Foliage_Cut     : constant := 0.30;
   Foliage_Jitter  : constant := 0.14;
   Foliage_Bend    : constant := 0.6;
   Foliage_Ruffle  : constant := 0.4;
   Foliage_Mass    : constant := 0.3;
   Foliage_Lift    : constant := 0.16;
   Foliage_Ragged  : constant := 0.22;
   Foliage_Deep    : constant := 0.42;   --  a gap between the leaves is the crown's inside: this dark

   --  Grass (John, 2026-11-11: "grass can get a slight overhaul"; first
   --  values).  A tuft of grass, of grain or of wild vegetables is a block
   --  with its blades painted on its sides (Castle.Mesher, "Tufts").  It is
   --  no longer drawn as that block: by where it stands, its top leans up to
   --  Tuft_Lean of a block any way, is drawn in by Tuft_Taper of a block on
   --  every side, and stands between Tuft_Low and Tuft_High of its height,
   --  so no two tufts are alike and none is a cube.  It takes the light as
   --  the turf it stands in does, mostly from above (Tuft_Up: how far its
   --  sides' normals are turned up), not as four walls, of which the two
   --  away from the sun used to be nearly black; it is darker at the root
   --  and lighter at the tip (Tuft_Root, Tuft_Tip), and seen from above it
   --  is the tips of its blades (Tuft_Tips of the texels of its top; grain's
   --  ears Grain_Tips), not a lid.  Nothing moves with time.
   Tuft_Lean   : constant := 0.24;
   Tuft_Taper  : constant := 0.16;
   Tuft_Low    : constant := 0.55;
   Tuft_High   : constant := 1.30;
   Tuft_Up     : constant := 0.75;
   Tuft_Root   : constant := 0.80;
   Tuft_Tip    : constant := 1.18;
   Tuft_Tips   : constant := 0.34;
   Grain_Tips  : constant := 0.42;
   --  The turf itself.  The side of a block of turf, the riser of a step in
   --  a meadow, is a bank of grass, not a wall: its normal is turned up by
   --  Turf_Up and it takes the sun's shadow from just above its own top
   --  edge, so a step no longer stands in its own shade (it was nearly
   --  black on the side away from the sun; what a tree or a hill casts
   --  falls on it as before).  And a meadow is not one green: it is lighter
   --  and darker in drifts (Meadow_Tone, on a noise a few metres across and
   --  one of tens of metres) and yellower here and there (Meadow_Sere).
   Turf_Up     : constant := 0.60;
   Meadow_Tone : constant := 0.14;
   Meadow_Sere : constant := 0.30;

   --  The fringe between turf and bare earth (John, 2026-11-11: "it would be
   --  nice if the edges around the paths and compacted areas had some
   --  charecter too it"; first values).  The mesher marks which sides of a
   --  top face of turf, or of bare earth (a footpath, trodden or dug
   --  ground), meet the other kind (Castle.Mesher, "Fringe").  Along those
   --  sides, texel by texel: grass creeps onto the earth, thick at the very
   --  edge (Fringe_Grass_Share of the texels there) and thinning out over a
   --  width that wanders along the edge between Fringe_Grass_Min and
   --  Fringe_Grass_Max of a block on a noise Fringe_Wander_M metres across;
   --  and the turf beside the earth is worn through to it the same way
   --  (Fringe_Wear_*), and what grass is left there is trodden: duller and
   --  yellowed; and here and there along the edge lies a pebble
   --  (Fringe_Pebbles: that share of the texels at the very edge, Warm Gray
   --  lightened).  So the edge is ragged and no two metres of it alike.
   --  Far off, where texels are under a pixel, the two are blended instead.
   Fringe_Grass_Share : constant := 0.85;
   Fringe_Grass_Min   : constant := 0.15;
   Fringe_Grass_Max   : constant := 0.95;
   Fringe_Wear_Share  : constant := 0.65;
   Fringe_Wear_Min    : constant := 0.35;
   Fringe_Wear_Max    : constant := 1.3;
   Fringe_Trodden     : constant := 0.5;    --  how far the turf left by the edge is turned dull
   Fringe_Pebbles     : constant := 0.06;
   Fringe_Wander_M    : constant := 5.0;

   procedure Set_Water_Steps (Steps : Natural);
   --  How open water is drawn: 0, one sheet (every corner at the mean of
   --  the columns meeting there); N, stepped (each column flat at its own
   --  level to the nearest 1/N of a block, with risers between).
   function Loaded (CX, CY : Integer) return Boolean;

   procedure Draw (Eye, Focus : Vec3; View_Proj : Mat4; Width, Height : Natural;
                   Fog_Distance : Float);
   --  Fog thickens with ground distance from Focus and is complete at
   --  Fog_Distance, the edge of what is streamed in.

   procedure Set_Outline (Lo, Hi : Vec3; Visible : Boolean);
   --  A wire box (metres) drawn over the world: what an edit would touch.

   procedure Screenshot (Path : String; Width, Height : Natural);

   function Stacks_Resident return Natural;
   function Stacks_Skipped return Natural;
   --  Uploads that found the quad arena full, so far: stacks not drawn.
   function Quads_Resident return Natural;
   function Draws_Last_Frame return Natural;
   function Capacity_Left return Natural;
   function GPU_Millis return Float;
   --  GPU time of the latest measured frame (timer query, a few frames
   --  behind so reading it never stalls the pipeline).

end Castle.Render;
