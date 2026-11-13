# Climate

- Packages: Castle.Climate
- Check: none of its own (climate_year prints a year, its mist too)
- Saves: the clock, and the snow, ice and wet state in the game save
- Stage: phase A

Seasons and weather (`Castle.Climate`): a 60-day year, 15 days to a season
(`Days_Per_Season`). The weather is a function of the seed and the game
clock (seasonal temperature, a daily cycle, multi-day warm and cold spells,
cloud, rain or snow by temperature, wind), so a save needs only the clock.
The one piece of state is what the weather leaves behind: snow at three
heights (peaks run 9 degrees colder than the valley and keep their caps into
summer), lake ice and wet ground, advanced in fixed 15-minute steps with
plain arithmetic so every machine gets the same winter. `./bin/climate_year
[SEED]` prints a year: on seed 1 the valley holds 25-33 cm of snow from the
first day of winter until spring melts it by day 9.

Mist (`Castle.Climate.Mist`, 2026-11-11; first values, named at the top of
the spec): how much lies on the land, 0 to 1, a function of the clock, the
weather and the wet state the rain left, so nothing new is saved. It
gathers from ten at night and stands thickest from four; the sun burns it
off as it climbs (a height of 0.08 to 0.30, less under cloud: gone by
seven of a summer morning, by eleven in winter); wind over 2 m/s thins it
and 5 m/s clears it; falling rain or snow takes its place; hard frost
dries the air. Whether a night is a damp one goes by a chance that turns
over every day and a half, by the season (most in spring and autumn) and
by how wet the ground is. On seed 1 a year has some mist on about a
third of its mornings, a fair one every four or five days and a thick
one about once a season (`./bin/climate_year` prints each day's and
tallies them). It is only seen: the colony does not know of it.
`docs/systems/rendering.md`, "Mist", is how it is drawn.

The moon (`Castle.Climate.Moon_Phase`, 2026-11-11): its phase is the
clock's, ten days from one full moon to the next (`Moon_Days`), full on day
20.5 (`Moon_Full_Day`) and every tenth day after. Nothing is saved for it
and the colony does not know of it. `docs/systems/rendering.md`, "The
sky", is what it does to the picture.

What the seasons do to the picture:

- Snow coats whatever is open to the sky, found with a second depth map
  that looks straight down: ground, roofs, conifer tiers, branch tops; it is
  thin under canopies, patchy as a dusting, buries small steps and grass when
  deep, and banks only at the foot of cliffs. Lakes and rivers ice over from
  the shores and take snow.
- Broadleaf crowns turn yellow, orange and red tree by tree, then drop their
  leaves (their shadows too) and leaf out again in spring; grass dries to
  straw in late summer and stays dull through winter.
- Rain and snow fall as GPU particles in a box before the camera, built from
  the vertex number alone, and stop at roofs and canopies. Rain darkens the
  ground; heavy weather greys the sky, takes most of the sun and closes in
  the view.
