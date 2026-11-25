# Castle Game handoff (2026-11-19: the round on his eight answers to the next pass)

The pass before it is `Handoff_2026_11_19_next_pass.md` (the ten items left of his playtest notes, its
eight calls). This is his answer to those calls, built. Everything is on branch `stockpile`, not
merged; `main` is 537176c. No merge word was given.

## John's words, whole

> 1. limit razing buildings to unowned, this happens when a serf passes to a new job and they house somewhere else, for example when the farm is built.
> 2. Document's stores is my model the new idea, the logistics network.
> 3. Delegation doesn't extend past basic work at the beginning, serfs fill jobs as the have been, as the are needed, dictated by skill. We can assign jobs in the development, AI so keep adding new jobs as we work them in to that list, but the player won't need to delegate further, past opening positions.
> 4. yeah add the leafs on the gateways.
> 5. Thin trim around the tops and side(s).
> 6. eh, go ahead and add a ridge beam to the hovels
> 7. Hold, off for additonal playtesting, half a metere is fine for now.
> 8. The thatch looks great now, can you do that ragged look to the entire surface of the roof, you nailed it on the ends, exactly what I wanted.

`bin/castle_game` in the working copy was still the build of 18 November when this came: he had seen
the pass in the sheet of stills, not in play.

## Answer by answer

1. **Razing, limited to hovels nobody owns; and the taking down, built.** Two readings of mine:
   - **"Unowned" includes a hovel still being built** (it is nobody's until it stands). A standing
     hovel is nobody's today only when its owner has died. His case, "when a serf passes to a new job
     and they house somewhere else, for example when the farm is built", is a later stage's and is
     written there, unbuilt.
   - **His limit was taken as leave to build the taking down as it had been put to him**: he changed
     nothing else of it. No hovel is both marked and owned: the mark is refused on one lived in; the
     box that takes housing out leaves a lived-in hovel standing with its lot and says how many it
     left; a mark saved on an owned hovel by the pass before is lifted on load. A marked hovel is
     nobody's to draw and asks the stores for nothing; a builder stands before its door and takes its
     blocks off, the last laid first, twice as fast as they were laid; what they took lies at the
     site, and with nothing standing half of it goes to the stores, the hovel leaves the list and its
     lot leaves the zone. Its beaten floor and its levelled ground stay as ground. The mark lifted
     half way down, it is built up again from what lies there. On the ground's menu on its lot: "Raze
     this hovel (nobody's)", "Keep this hovel (lift the mark)".
2. **The document's stores are the model: the logistics network. Planned, not built.** He confirmed
   it; he did not order it. It is mapped to the build in `docs/production/briefs/Stage_6_brief.md`
   ("The logistics network"), in passes with a default each. One count was run for it ("Measured").
3. **Jobs.** Read as: the player gives the opening jobs only and serfs come to the rest by skill, as
   now; and for development the jobs worked in go on the list too. **Builder is on a person's menu**,
   after the opening jobs, with its skill beside it: a forester so set takes a house before any that is
   not, whatever their skill, and fells when there is none. Any job given lifts it.
   `Castle.Actions.Dev_Jobs`; `--no-dev-jobs` gives the menu as the player is to have it. Who builds
   is otherwise unchanged, **and it is by skill already**: the forester best at building with no house
   to build. The stockman is the porter with the most portering, also by skill; **the carpenter is not:
   it is whoever raised the storehouse.** Stockman and Carpenter are shown in the lists and not yet on
   the menu.
4. **Leaves on the gateways.** Two leaves of rails in each of the stockyard's gateways, hung once the
   gateway's post is raised, swung into the yard while anyone or the cart is within reach. A gateway
   narrower than 1.9 m has one leaf and a gap beside it; narrower than 0.95 m, none. Drawn only.
5. **A thin trim.** A strip of plank 8 cm wide up each side of a window's opening and across its top,
   none under it, on the wall's outer face. Drawn, so every house's windows have it. A hovel begun
   from now on has daub beside its windows again; one begun in the pass before keeps the plank blocks
   it was begun with. `--no-window-trim`.
6. **A ridge beam in the hovels.** A hovel begun from now on has one, gable to gable. Under a whole
   roof it is not seen; it clears with an open one, as the storehouse's does.
7. **Paths.** Nothing changed: half a metre stands, and the call stays open for his playtesting.
8. **The whole roof ragged.** Every corner of a dressed roof's top hangs unevenly, by its place, by the
   amount the edges have (10 cm at the most; its own number, `Thatch_Surface_Drop`). **The eaves and
   verges are as they were to the pixel**: with the surface's amount at zero, and with
   `--no-ragged-roof`, a still of four roofs is pixel for pixel the one he praised.

## Saves

Colony blob **32** (with each house whether plank stands beside its windows and whether a hovel has a
ridge beam; who is set to building). **Blobs of 30 and 31 are still read.** Proved on houses half
built, which the pass before had not done: a colony saved by his build of 18 November (blob 30) and
one saved by the pass before (blob 31), each with three hovels and the storehouse half built, were run
on in this build until all stood.

## Measured

- **The case his answer names, a hovel that stands and is nobody's**, made in `colony_check`: two of
  the band and two hovels, one owner struck down (nobody is then without a home to draw the hovel);
  marked, its 3,464 blocks come off from the roof's trimming down to nothing; no thatch, daub, timber
  or plank of it is left over its ground; 1 log and 15 sheaves came back; the other hovel stands and is
  its owner's; a save half way down and one after load to the same bytes.
- Razing on the reference site, the band of thirteen with housing, the stockpile and the stockyard,
  the first hovel marked 26 and 34 game hours in (four houses begun, the storehouse later in the
  list): taken down; 2 logs and 3 or 9 sheaves came back; the storehouse stands; five hovels stand;
  thirteen living, nobody starving in 15 days. The save of it loads.
- For his stores model, one count, 41 days, the band of thirteen: see the brief; the three runs are
  one each.

## Gate

Gate 52, from a clean copy of 5272c2d (the last commit that changes code; gate 51, of 75725d5 before
the standing case and the wording, passed the same way): both builds from nothing
with the six known warnings and no error; the nine checks in debug (water_sim 77, edit 41, ui 112,
dynamics 18, serf 19, path 70, **colony 767**, deer 14, pick 59), none failing; the eight reference
logs line for line (nobody is set to building in them; the three defaults of the pass before held off
as then); both stockyard sites; the stress runner, nothing died and nothing dropped; the flora hash
unchanged.

The stress states moved again with the blob (a byte a member, two a house): six_4_years
4f3f63e778a0a210, six_41_days f2a7c91867604f86, housing 50918b5f33aef50f, crowd_as_it_is
3ff1c55251882edd, crowd at work fd5ddae90002c439; each case agrees with its own variants. The eight
logs are what says the behaviour did not move.

## His calls (first values of mine)

1. **The two readings of razing**: a hovel still being built counts as unowned; and the taking down
   was built on his limit (half of what lay there comes back; taken down twice as fast as built; from
   before its door; the lot leaves the zone).
2. **The logistics network's first pass**, in the brief. Its first question is his own note against
   his document: "a onetime placement of a 10x10 zone" (17 November) or many stockpiles along the
   paths.
3. **Stockman and Carpenter on the development list** too, or shown only as now. And whether the
   carpenter should come by skill like the others.
4. How wide the trim (8 cm), and whether inside the house as well (outside only now).
5. How ragged the roof's top (the edges' 10 cm now).
6. A gateway narrower than two metres: one leaf and a gap now.
7. The calls of the two rounds before stand open as they were, the paths' half metre among them.

## Known limits

- Razing is hovels only. The storehouse is never marked.
- A builder takes a hovel down from before its door, whatever of it is in reach; it does not go round
  it or use a ladder.
- While it comes down a hovel's sheet says "a hovel, being taken down" and "nobody: it is to be razed",
  the zone's sheet "being taken down", and the log's housing line counts it by itself ("1 being taken
  down"), not among those being built.
- In the next-pass handoff a column of "hungry serf-hours" (73 and 23) was wrong and is corrected
  there: those runs were logged once a day.
- The ground a razed hovel stood on stays levelled, its stone walls with it; nothing puts it back.
- Seen through the interface with a scripted pointer: taking housing out (the pass before), and
  Builder on a person's menu with the list calling that serf Builder. **Not seen through the
  interface: "Raze this hovel (nobody's)"** (checked through the order it gives, in `colony_check`).
  No still of a hovel half down was taken.
- A gate's leaves were seen shut and held open for a still, not opening for someone walking through. A
  storehouse door was seen open for its stockman standing in it.
- The trim is on the outer face only.

## Test windows and input

Stills in short windows of mine, each only when `pgrep` found his game not running. All input
scripted. Nothing pushed.
