# Castle Game handoff (2026-11-19: "can't we just detach the entire building and rotate it?", the integration held, gatherers and porters to 250 m)

The round before it is `Handoff_2026_11_19_stockpiles_and_reach.md`. Everything is on branch
`stockpile`, not merged; `main` is 537176c. No merge word was given.

## John's words, whole

> no I am not running the game right now, we have to fix somethings before I can contiue play testing,
> and I think for the next couple of days we will be polishing, so hold off on the integration, we are
> goning to finish up the current projects, I am going to let you has it out, I saw the walls you were
> drawing, looks like you're getting the hang of it, let me ask you, why can't the blocks just be
> rotated on top of each other? do they have to line up? look at the mats the serfs put on the ground,
> they can go at 45 degree angles around the fire, can't we just "detatch" the entire building and
> rotate it? I mean it would still be connected to the ground essentially, right? I can do some
> research, and the workers. The questions can rest for now. We will get to those next.

Taken as:

- **"hold off on the integration"**: the logistics network's later passes wait (the first, the
  stockpiles, stays as built: he did not ask for it back). Written into the brief and CLAUDE.md.
- **"we are goning to finish up the current projects, I am going to let you has it out"**: the two
  things owed (buildings at 45 degrees; workers to 250 m) are the work, and how is left to me.
- **"can't we just detach the entire building and rotate it?"**: a question, answered below with a
  still. Read also as the way he would rather it went.
- **"I can do some research, and the workers"**: read as "and then there are the workers": built for
  gatherers and porters. If he meant something else by it, that reading is wrong.
- **"The questions can rest for now"**: the calls rest. None was acted on.

## His question

**Yes, it can be drawn that way, and it was: one standing hovel, turned 45 degrees as one piece,
walls, frame and roof whole** (`~/CASTLE_GAME/releases/turned_hovel.png`; a scratch build, not in the
branch: `turned_building_proof.patch`, fifteen lines in the land's vertex shader that turn every
block of the house about its middle). No stepping anywhere, and the roof comes with it, which the
cut-block wall of the round before could not promise.

Why the blocks line up today, and what "detached" has to answer:

- The mats are drawn things (`Castle.Props`): nothing walks into them, nothing is laid on them, no
  pointer has to find them. They can lie any way because the game knows nothing of them but where.
- A building's blocks are the map's own blocks: where a serf can walk, what the pointer lands on, what
  the cutaway clears, what a builder has laid and a save holds are all read from the map's grid. A
  block on that grid cannot be turned; a picture of it can.
- So "detached" is: the building's blocks kept in a small grid of its own and drawn turned; and on
  the map's grid under it, only what the game has to know: its level ground, and hidden blocks where
  its walls stand (to the nearest block) so that nobody walks through a wall. It is still on the
  ground; the ground under it is still blocks.

Wrong in the still, and why: the house is lit as it stood before the turn (a face's light goes by the
side it had); no shadow was tried (the casters' pass was not changed); its floor and its way to the
path are left where they were (the ground was not turned, and must not be); doors, trim and people
were not turned (they are placed from the house's frame).

**Chosen** (his "I am going to let you has it out"): the building drawn as one turned piece, not
blocks cut corner to corner. The steps are in the brief ("Buildings at 45 degrees"); the first is the
drawing, built so that a house standing square is the same picture to the pixel.

## Workers to 250 m: gatherers and porters

- **A gatherer that finds nothing to gather in reach looks a ring further the next time** (16 m), to
  250 m; bushes are now looked for as far as the gatherers look (they were looked for within 88 m of
  the stake only). **A porter that finds none of what it is sent for does the same.**
  `Food_Reach_M`, `Haul_Reach_M`; the foresters' switch (`--no-wood-reach`) holds all three off.
- **Not as far as the foresters went**: a gatherer or a porter whose nearest bush or grass is across
  water still stands saying it cannot get there; only the foresters ask their way first and look
  past what they cannot reach.
- **The porters have one reach for all they fetch**: a thing there is none of within 250 m (stone, on
  some ground) takes it out to 250 m, and the colony's ground with it. At the open-land site the
  colony's ground at 250 m took 3.0 ms of computing a colony second where it takes 1.3 (the foresters'
  run of the round before).
- **Hunters: nothing.** The herds live within their range of the stake until they come apart from it.
- Proved in `colony_check` (797 now; a bush 67 m and long grass 64 m from the stake: nothing brought
  with the switch off, both brought with it on, the reaches saved).
- On the real world, the band of thirteen at the reference site, 41 days, one run each: the gatherers
  were looking 92 m by the end (vegetables asked for and none left nearer), the porters 60 m; thirteen
  living, six hovels and the storehouse standing, as before it; 3,170 vegetables pulled where it was
  3,011. `colony_run --tree-stats` says how far each looks at the end.

## Saves

Colony blob **35** (how far the gatherers and the porters look). Blobs of 30 to 34 are still read.

## Gate

Gate 56, from a clean copy of 001111c (the last commit that changes code): both builds from nothing
with the six known warnings and no error; the nine checks in debug (water_sim 77, edit 41, ui 112,
dynamics 18, serf 19, path 70, **colony 797**, deer 14, pick 59), none failing; the eight reference
logs line for line; the three stockyard sites; the stress runner, nothing died and nothing dropped; the
flora hash unchanged (5676219328934879273 in both builds).

The stress states moved again with the blob: six_4_years cebab0ba9d8c7609, six_41_days
bb88fcf9f8a04777, housing 8561bd239c8ffada, crowd_as_it_is 4dfcfd6d58905e52, crowd at work
0c5e697b1274e5a4; each case agrees with its own variants.

## Known limits

- The turned hovel is a still from a scratch build: nothing of it is in the branch.
- The calls of the rounds before rest, by his word.

## Test windows and input

Stills in short windows of mine, his game not running (his word, and `pgrep`). All input scripted.
Nothing pushed.
