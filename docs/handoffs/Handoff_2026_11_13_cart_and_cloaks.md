# Castle Game handoff (2026-11-13: two things before the next stage: the lord's cart pulled into the nearest stockpile, and cloaks of cloth, an experiment; then, the same day, roofs cleared on the camera's ray, and a fault of the water's drawing he found: its surface gone round the stake after the camera had been away; then his answer to the roofs and the cloth: the pointer clears a roof too, a key clears them all; then his answers to the list of open questions: the walls on the camera's side cleared with the roof, the key's three views. Built on branch `cart-and-cloaks` from `main`; Claude Code)

- **Accepted on 2026-11-13, and on `main`.** Asked the one question left (does he accept the branch),
  John, whole: "ok commit we are at a good spot right now, then the stress test for the cart issues, and at last we can get to the stockpile". Read as:
  take the branch (the tree was clean: nothing else was there to commit). `main` was fast-forwarded to
  the branch (it was dd6e7ef: `git branch -f main dd6e7ef` takes it back). What he answered of its
  calls is in the sections below; those he did not take up stand by default (13: no wait before a
  house opens under the pointer; 14: the timbers cleared with the panels; 15: a wall edge-on stands;
  16: the roof's half-drawn edge stays over a cleared wall). **Next, in his order: "the stress test
  for the cart issues" (the herds' searched-out ways with the pull: a new branch and a new handoff),
  then the stockpile, his to open.** Where a paragraph below says "not merged" or "not accepted", it
  was so when it was written.
- Branch `cart-and-cloaks`, from `main` at
  dd6e7ef (the pass on building and zoning, accepted). Commits: d4a45b3 (his words; the grass left at
  his word, the documents that had called my reading of it the cause corrected), d287354 (the cart
  pulled; colony blob 25; the eighth reference log again), 0a2dfe7 (cloaks of cloth; documents), and
  a1a7c04 (the cloaks begun again when a save is loaded in the running game; the herds' searched-out
  ways written down as not explained; the demo script made runnable). **Then his next message asked
  for roofs cleared on the camera's ray** (below, "Roofs cleared on the camera's ray"); he said nothing
  of the cart or the cloaks, so it was built on the same branch, still not merged: dca8b94 (a cloak
  over a sleeper held where it rests: a fault of mine found looking into a hovel through a cleared
  roof), d7f8598 (the roofs), 1e1abaa (the demo and this handoff), 9a78965 and ac69003 (the
  forearms' capsules taken out again; the handoff corrected). **Then he reported the water's surface
  gone round the stake** (below, "The water's surface gone round the stake"): mended in bdd18db, on
  the same branch, not merged; the commits after it are documents only. That fault is on `main` too
  (run there: below). Taking the mend to `main` alone would be the renderer's and the game's hunks of
  that commit, its documents by hand: not tried. **Then his answer to the roofs and the cloth** (below,
  "His answer to the roofs and the cloth"): built in ac9bcb5 and a6ffe81 (the pack placed by its
  kind and the season), on the same branch, not merged. **Then his answers to the list of open
  questions** (below, "His answers to the list of open questions"): the walls and the key's three
  views, in 15f725f, the last commit that changes what is built (the one after the next mends a
  comment in a source file and the documents).
- Checks, from a clean copy (`git archive`) built from nothing, on d287354, on 0a2dfe7, on a1a7c04,
  on d7f8598, on 9a78965, on bdd18db, on ac9bcb5, on a6ffe81, on 15f725f and on the branch's last commit: both
  builds with the six known warnings only; all nine checks in debug (colony_check 616 -> 621,
  pick_check 41 -> 48 with the roofs, 54 with the pointer's and 59 with the walls, the rest as they
  were); `tools/reference_check.sh` line for line (the eighth recorded again with the
  pull; with `--no-cart-pull` it is the log kept before); `tools/stress.sh runner` ("nothing died,
  nothing dropped"; its crowd took 22 s where it took 12: "Measured, the cart"); the flora's hash the
  same in both builds.
- Versions: `Generator_Version` 13 and save format 6 as they were. **Colony blob 24 -> 25**: saves of
  the pass (and of `main`) do not load. Nothing of the cloth is saved.
- Driven only by script: nothing of the interface changed but a row of the cart's sheet ("Stands"),
  which no headless check reads; the cloth and the cleared roof's look have no headless check (they
  are drawing: stills, recordings and the demo). The pointer through a cleared roof is checked
  headless (`pick_check`, on the made-up meadow); in the game it was driven by a scripted pointer
  only, never by a real mouse.
- Zip: CASTLE_GAME/releases/castle_game_cart_and_cloaks.zip (a `git archive` of `main` at the branch's last
  commit). Demo: colony_cart_and_cloaks.mp4 (`tools/demo_cart_and_cloaks.sh`), twelve parts, 78 s: the
  cart pulled, the cloaks worn close up, the first beds made and the cloaks taken off, the night with
  the cloaks over the sleepers, the same night with `--no-cloth`, a hovel's roof cleared by day close
  up and at the default view, its owner asleep inside under its cloak that night (that part
  brightened threefold, and said so), the pointer taken along six hovels (each roof opens under it
  and comes back), three streets with every house open, the pointer put on a hovel's near wall from
  low down (the wall fades and the room is seen), and a hovel seen from its corner with the two walls
  on the camera's side gone.
- **Test windows of mine on his desktop**: a recording of the cart pulled (330 frames), a recording of
  the band's first minutes (200), some ten stills (the camp at night, on the slope at night, in winter,
  at the default view), four runs of 2,500 frames at the camp's fixed view for the cloth's cost, three
  runs of the debug build's game (a winter dawn among them), and the demo once. For the roofs: some
  fifteen stills of the hovels (by day, at night, in rain and snow, without multisampling, at the
  default view, the sleeper pointed at), four short recordings of a sleeper in a hovel (240 to 300
  frames) and a short run printing it, a recording of the camera gliding along the hovels (200
  frames), fourteen runs of 2,500 frames for the cost (two fixed views and the hovels, before and
  after), one run of the debug build's game, and the whole demo three times more. For the water:
  twenty-two windows (four looking for water 512 m off; four there-and-backs before the mend and
  after; nine looking at the far end, two of them sixty seconds long in which no stake was placed
  (the camera began too far off for it), three of ninety seconds with a band at work, one of those
  `main`'s build; five there-and-backs of the mended build, one the debug build's). For his answer to
  the roofs and the cloth: four stills, twelve recordings (three of the pointer held still, nine of
  the cloaks close up, 150 frames each and one of 240), eight runs of 2,500 frames for the cost, two
  runs of the debug build's game, and the demo twice more. For his answers to the open questions:
  eleven stills, one recording of 150 frames, sixteen runs of 2,500 frames for the cost, one run of
  `tools/shadow_still.sh` (200 frames), two runs of the debug build's game, and the demo once more.

## John's words

2026-11-13, after the pass on building and zoning was merged (whole): "I saw the grass going with the
ground every other time, it seemed to have just happened on a couple of blocks, the gatherer had been
collecting grass on the blocks before the plot began being built, maybe there is something there where
the state of the grass has been modified but not completed and the grass remains? Just leave it for
now, if I reproduce it again, I will try and recreate the exact conditions for debugging. Two last
things I want to work on before moving to the next stage, the cart, can they pull it into the closest
stockpile zone? I also want to try something, an experiment, can we have the cloaks be dynamic cloth,
that they wear at the start, then take off when they make their bed, and then draped over them when
they sleep, if we can do it, it would be a very cool touch and would translate well when we get to
other wearable items later in production."

How it is read:
- The grass: left at his word. Nothing done; the pass's handoff ("After the pass") and the documents
  that had said my reading of his picture was the cause now say the cause is not found.
- "the cart, can they pull it into the closest stockpile zone?": the band pulls the lord's cart from
  where it stands by the stake into the stockpile zone nearest it, and it stands there. Nothing else
  about it changes: its salt is fetched and used as it was.
- "can we have the cloaks be dynamic cloth, that they wear at the start, then take off when they make
  their bed, and then draped over them when they sleep": an experiment. A cloak is cloth, drawn only
  (nothing of it saved, the colony knows nothing of it), worn from the start, taken off when its owner
  makes its bed, and draped over its owner asleep. Winter is as he gave it before (worn when awake).
  The cloth is made so that it can hang from anything worn later, not for cloaks alone.

## The cart, as built

`docs/systems/colony.md` ("The lord's cart", "Pulled into the stockpile nearest it") has it whole. In
short: once there is a stockpile zone, one of the band, as an extra task (after the camp and its
seats, before the paths), goes to the bar across the cart's shafts, takes them up and pulls it at six
tenths of a walk to two of the nearest zone's empty places side by side, held for it from the moment
it set out; there it is set down and stays. Nothing is put on a place under it. In tow it is no thing
of the world, drawn 2.3 m behind its puller, turned as it goes, its prop gone from under its shafts;
called away mid-tow, its puller sets it down where it is (or near, or back where it stood). Its sheet
says where it stands. `--no-cart-pull` leaves it where it stood. Colony blob 25 (18 to 24 refused).

Measured (seed 1): in the reference band with the camp to build it is pulled at half past nine the
first morning (when a place at extra tasks comes free; a hunter at it for salt holds it up), with the
camp built at a quarter past seven, in a few game minutes each time. The eighth reference run is the
same as before it until then, and was recorded again with the pull on (all six live; 14 deer salted,
as before); with `--no-cart-pull` it gives the log kept before, line for line. Its slowest plans are
the hunters' far ones, as before (16.9 ms against 17.4). `colony_check` 616 -> 621.

## The cloaks of cloth, as built (an experiment)

`docs/systems/people.md` ("Cloth") has it whole. A cloak is a sheet of six particles by seven (thirty
panels), stepped by drawn time after the figures are posed: worn from the start, held across the
shoulders behind the neck and kept out of nine capsules on the body; taken off when its owner has made
the bed it sleeps on (let go, it falls where it is and lies there); laid over its owner once asleep and
all the way down (it settles over the body, then is frozen: dead still, its shadow too); left lying on
the bed when its owner rises. In winter worn whenever awake, as before. Drawn as thirty thin boxes, each
on a bone of its own (two figures a cloak), so it is lit and shadowed as any figure. `Castle.Cloth`
knows nothing of cloaks: it hangs from whatever points it is given. `--no-cloth` is the cloaks as they
were, exactly. Nothing of it is saved; the colony knows nothing of it.

(As first built: since then a sleeper's cloak sticks where it rests and waits for a still body, and
there is a tenth capsule for a pack on the back, 0.045 ms a worn cloak; the two sections on his later
messages, below.)

Measured: six cloaks cost 0.02 to 0.07 ms of GPU at the camp's fixed view (`tools/look_cost.sh`,
camp_day, twice each way: 2.00 and 2.05 ms, 1.98 and 1.98 without); stepping one worn cloak is about
0.04 ms of CPU a frame (forty-eight, 2.0 ms, in a scratch program at the game's optimisation); a
cloak lying still costs nothing; a cloak more than 40 m from the eye hangs straight and is not stepped.
A cloak dropped over a made-up sleeper on its side settled over it and froze within five seconds of
drawn time.

## His calls (what I decided that he may want otherwise)

(Answered on 2026-11-13, "His answers to the list of open questions" below: the cart is moved once
"for now" and who pulls it stands; its salt as stock waits for the stockpile; "The cloth is fine".)

1. **The cart's place in the stockpile is two of its places**, the empty pair nearest the cart in the
   zone nearest it; nothing is put on them while it stands there. Nothing else of the stockpile, and
   nothing of the salt, changes: hunters still carry sacks from the cart to the stockpile's places.
   Whether its salt should count as stored, and whether it should move again to a nearer stockpile
   zoned later, are his (the stockpile is his to open).
2. **Who pulls it is whoever is free for the band's extra tasks** (after the camp and its seats,
   before the paths), at six tenths of a walk, alone. Two at the shafts, or a porter's job, are
   possible.
3. **The cloak is taken off at the moment its owner's bed is made**, where it is, and lies where it
   fell until its owner sleeps; it is not folded or laid on the bed by hand. Over a sleeper it is laid
   from above at once, not drawn up by hand. In winter it is worn when awake, as you gave it before.
4. **The cloth is coarse**: thirty panels, so it folds in large facets and its edge is a line of
   panels. More panels cost more (the step is about the square of them).
5. **A cloak far off hangs straight** (40 m from the eye), to save its stepping when the band is
   large.

## Roofs cleared on the camera's ray (his next message, the same day)

His words, whole: "ok I guess it is time, and we should have planned for this and i forgot,
semi-transparent roofs on the ray of the camera, It would be nice to have a tapering transparency with
full transparency in the middle and semi-trasnparency along the edges wher the roof meets the walls"

How it is read: it answers the limit put to him in the report before it (a sleeper in a hovel could not
be looked at: the roof hides it). "The ray of the camera" is the line from the eye to the point the
camera looks at (and circles); a house that line passes through has its roof cleared, open in the
middle and half drawn where it meets its walls, tapering between. He said nothing of the cart or the
cloaks: not accepted, so this went on the same branch, unmerged.

As built (`docs/systems/rendering.md`, "A roof cleared on the camera's ray", has it whole):
`Castle.Cutaway` follows the line each frame and fades a roof clear in a quarter of a second of drawn
time, and back; the land's shader draws a cleared roof's thatch at half over its walls and eaves,
thinning to nothing 1.25 m in (alpha to coverage under multisampling, dithered by the pixel; a screen
door with `--msaa 0`). The roof still casts its shadow; walls, gables and frame stand. The faces under
a roof that a whole roof hid (a wall's top) are now meshed (86 quads for six hovels). The pointer goes
through a cleared roof where less than half of it is drawn, so a sleeper inside can be pointed at (and
the dig brush reaches the floor). `--no-cutaway` is the roofs as they were. Nothing saved; the colony
knows nothing of it. `pick_check` 41 -> 48 (it clears, it is open in the middle and half drawn at the
eave, the pointer finds the floor through it and the thatch at its eave, it comes back, the switch);
taking the pointer's pass-through out fails the check.

Seen in motion once (the camera gliding 20 m along the hovels, recorded): the roof the line comes to
clears over its quarter second and the dither holds still on the screen; a roof coming back was not
seen in a recording (`pick_check` has it, headless).

Measured: nothing measurable with no house in view (the camp's fixed view 2.01 to 2.04 ms against 1.99
to 2.01 for a1a7c04 built beside it, back to back three times; the meadow 1.79 against 1.77); six hovels
close up with one cleared 0.41 ms, switched off 0.41, before 0.40.

A fault of mine, found looking into a hovel through its cleared roof at night: **the sleeper lay on top
of its cloak**. Traced frame by frame: laid over the sleeper, the cloth slid off its side onto the bed
(0.4 m in five seconds) and froze there (at the camp the stills had not shown it). Mended in `Castle.Cloth` and the game: a sleeper's cloak is stepped to stick (a point that comes
to rest on the body or the bed stays there), it is laid over the sleeper only once the body has held
still ten frames (and laid again if the body moves 0.2 m from under it). In the same hovel it now stays
over the sleeper from the shoulders to the knees (a recording of it frame by frame); pointed at
through the cleared roof, the sleeper's own tooltip comes up (a still with the scripted pointer).

His calls, for the roofs (6 answered in "His answer to the roofs and the cloth": the pointer too; 7,
8 and 9 answered in "His answers to the list of open questions": the walls on the camera's side are
cleared, no light is let in, the taper is "adequate"):

6. **Only the line to the focus clears a roof**, a house at a time (eight at most), the whole house
   counted (at the default tilt that line comes in through the near wall). The pointer could clear the
   house it is over as well; a cylinder round the line could clear neighbours too.
7. **Only the roof is cleared**: at the default tilt the near wall still hides the floor beside it.
   Walls cut down too (as other games do) is his to ask for.
8. **The inside stays in the roof's shadow**: by day it reads, at night a sleeper is dim (the moon's
   shadow is the roof's too). Letting light in where the roof is cleared would be a new rule of
   light, not made unasked.
9. **The numbers**: half drawn over the walls and eaves, open 1.25 m in, a quarter of a second to
   clear or come back, the line run 1.5 m past the focus.

## The water's surface gone round the stake (his next message, the same day)

His words, whole, with four pictures (`~/CASTLE_GAME/TEST SCREENSHOTS/swappy-20261113-170745.png`,
`-170742.png`, `-170739.png`, `-170200.png`): "see these photos, water surface stop rendering around
the homesteak and some a little distance away, water was still there, surface rendered when activated,
first I moved the camera around the map after placing the homesteak and the serfs had been working
for some time, came back to see the water not rendering after finding water not rendering in the
mountains, I was testing if the workers still worked if they were on the other side of the map from
the camera, on recreation, I simply placed the homesteak, moved the camera around and the surface
water no longer rendered near the homesteak."

What the pictures show: a river's bed dry along a stretch by the camp and the hovels, water drawn
again further along it, its ends cut square on the stacks' edges (the last picture).

Reproduced before anything was changed, both halves, with a control (seed 1, the reference stake, a
scripted glide: `--pan DX DY`, and new, `--pan-back`):
- the stake placed, the camera 520 m east and back: the river south-west of the stake is a dry bed
  (it was drawn before the glide);
- the same 150 m and back: nothing wrong (every loaded stack still within one window);
- a stake at 1205 1068, a band at work, the camera glided 519 m east and held there ninety seconds: the
  river there dry along a long stretch, bites out of the next. The same run on a build of `main`
  (dd6e7ef) shows the same dry stretch: the fault is not this branch's. Whether this is his "water not
  rendering in the mountains" is not known: where his stake and his mountain were is not known. The
  test, for him: was that water about 512 m east, west, north or south of his stake's ground, or that
  far on the diagonal?

The cause: the water's surface texture is a window of the world 64 stacks across (512 m) that wraps,
and its comment's premise ("two loaded columns must never share a texel") stopped being true when the
colony's ground began staying loaded wherever the camera is. A stack loaded 512 m from a kept one
wrote over its texels and hid them when it was unloaded; a kept stack is never loaded again, so its
water stayed hidden. (His "surface rendered when activated": by the code a stack whose water is awake
writes its texels every tick, which would draw it again; not run.) The other way, whatever was written
of the colony's ground while the camera was far (a stack meshed again after the band's work) went
over the far view's water. The lines are the same on `main` since the import, and the far end was run
there.

The mend (`docs/systems/water.md`, "Drawing"): a slot of the texture is its window stack's alone.
`Castle.Render.Set_Surface` writes only for a stack inside the window round the stack looked at and
records the slot's owner; `Hide_Surface` hides only a slot its caller owns; when the window moves,
slots whose owners left it are hidden, and the game's `Stream` writes again every loaded stack the
window has come back to (`Own_Texels`: an awake stack's last tick, a resting one's pool). The debug
build checks after every `Stream` that each loaded stack inside the window owns its slot. Nothing
saved; nothing of the colony or the water's simulation touched.

Seen mended: the river drawn on coming back from 520 m east (release and debug), from 600 m east and
600 m north, from 1,040 m west, and with `--view 240` (the wider texture) from 1,030 m west; the far
river whole while the band works. In every one of those runs twelve stacks of the kept ground were
awake through the glide (so an awake stack's texels were written again from its last tick, and the
debug build's check held), but no awake water was in the picture. The longest frame of the
there-and-back was 15.6 ms, against 11.2 before the mend. In the ninety-second runs the band went on
working with the camera 519 m away (my runs; his own test of that is his to say). Not exercised: a
save loaded in the running game (no scripted way to; it takes the same path as a jump of the camera),
a real hand on the camera. The demo is of 9a78965: nothing it shows changed.

## His answer to the roofs and the cloth (the same day)

His words, whole: "For the roof let's run it to the mouse and the camera, along with an option to have
all roofs transparent, we can do the same with multi-level buildings, instead of slicing the
environment by elevation, you can add feedback on that if you have a better idea. What was the question
about the cloth, it works great, it would be nice if the clipping was less, but it's workable. After
those two things we can get to the salt and the stockpile."

How it is read:
- "let's run it to the mouse and the camera": call 6 answered. The pointer's ray clears a roof as the
  camera's line does. Built.
- "an option to have all roofs transparent": a key that clears every roof, and again puts them back.
  Built.
- "we can do the same with multi-level buildings, instead of slicing the environment by elevation, you
  can add feedback": there are no such buildings yet; nothing built; what was said back is below, as
  opinion.
- "What was the question about the cloth, it works great": the cloth stands as built, on his word that
  it works. The question was three calls (where the cloak is put down, that it is put on and laid over
  at once, how coarse it is): answered to him in the report, and they stand.
- "it would be nice if the clipping was less, but it's workable": a wish he called workable. One
  bounded pass: looked for where it clips, mended the one kind that was cheap, named the rest.
- "After those two things we can get to the salt and the stockpile": his to open. "Those two things"
  is read as the roof's two (the pointer, the option); if he meant the roofs and the clipping, both
  were done as far as was cheap.
- He said nothing of the cart's pull, the water's mend or the roofs' other calls (7 to 9): not
  accepted, not merged; those calls stand unanswered.

Roofs, as built (`docs/systems/rendering.md`, "A roof cleared on the camera's ray"): the game hands
`Castle.Cutaway.Follow` where the pointer's ray landed a frame ago (and 0.3 m on); a house that line
passes through is cleared. Passing through is now asked under the roof's two slopes, not of the box
round the house (a ray that only passes over the ridge to the ground behind cleared a roof the
pointer was not on). On the interface, or with a menu open, the last house pointed at stays cleared.
`Set_All` clears every roof offered: the H key (`Open_Roofs`, a row of the help panel) and
`--all-roofs`. Forty-eight at once (it was eight). `pick_check` 48 -> 54: the pointer alone clears and
the roof stays cleared with the ray gone on to the floor; the pointer gone, it comes back; a ray along
the ridge crosses, one a metre over or over a slope beside it does not; a dozen houses not looked at
stay whole; all twelve clear at once; and come back. Each rule taken out fails its check (the
pointer's, all, the slopes for the box, eight for forty-eight).

Seen: a scripted pointer held still on a roof's middle, on an eave and above a door, each recorded
150 frames: the roof clears and the picture then holds still (the largest change between two frames
after the fade 0.02 to 0.04 of 255); at night the pointer on a sleeper's hovel, a menu opened and the
pointer moved onto its rows: the roof stays open; 26 hovels on three streets all cleared with
`--all-roofs`; the debug build's game through a sweep of the pointer along six hovels, and with every
roof cleared. Measured (26 hovels and a band of forty in view, twice each way): GPU 1.45 and 1.47 ms,
CPU 0.63 as it stands; 1.44 and 1.48, 0.63 to 0.64 with every roof cleared; 1.43 and 1.47 switched off;
1.45 and 1.46, 0.63 for the build before: nothing measurable.

The cloth, where it clips (looked for close up on the band setting off, bending and carrying, and
asleep; kinds found, not "his clipping": he did not say where):
1. **a basket or a sack on the back came through a worn cloak** (gatherers, porters): mended, as far
   as this: the cloak is thrown round the pack's far edge and kept off it by a capsule, each placed by
   the pack's kind (a basket is deeper than a sack) and the season (a pack sits a pixel further off
   over winter clothes). Seen close up in summer and at a winter noon, walking and bending: the cloak
   hangs round and behind the pack; from above the pack's top shows at the collar, between the neck
   and the cloak; in winter a sliver of the basket's edge still shows in some poses. (A capsule alone
   changed nothing: the cloak was pinned between the back and the basket.) The cloth costs 0.045 ms a
   worn cloak now (forty-eight: 2.2 ms; 2.1 before).
2. a hunter's bow and quiver lie over and through its cloak: stands;
3. a sheaf or a log on the shoulder cuts the cloak's collar: stands;
4. where the cloth bends sharply its thirty panels part into shards (his call 4, the coarseness): stands;
5. the shape on a sleeper's flank (above): stands.

Buildings of more than one floor: what was said back (opinion; nothing built). Clearing by the
building is the better way: a slice by height cuts hills and trees that have nothing to do with the
house looked at, and on a slope no one height suits a street. What this build shows it will take:
- today the test is "thatch inside the house's plan"; for floors it is "anything of this house above
  the floor looked at": one more number a house in the same shader loop (a height to cut at), and a
  blueprint that knows each block's floor;
- the faces a cleared part hid must be meshed, as a wall's top under thatch is now: for floors that is
  every face between two of them;
- the near wall hides the floor at the default tilt with one floor already (call 7); with two it hides
  more, so the walls of the floor looked at want lowering on the camera's side;
- the pointer and the camera pick the house; something must pick the floor (the wheel with a key
  held, or the floor of whoever is pointed at);
- the inside is in the shadow of what is cleared over it, as it is in the roof's now (call 8).
A slice by height still has a use where there is no building to clear: under the ground (a cellar, a
mine).

His calls, added (10 answered in "His answers to the list of open questions": three views, and its
third is the way to a roof's middle for 11; 12 settled with "The cloth is fine"; 13 not taken up, so
it stands):

10. **One key, two states**: H clears every roof, H again puts them back to "where the camera and the
    pointer are". There is no state "never" on the key (`--no-cutaway` is that, for a scripted run).
11. **Pointing at a house opens its roof whatever tool is in hand**: with the dig brush the roof's
    middle cannot be reached now (the brush lands on the floor).
12. **A cloak over a pack hides the pack** from behind: the other way (the pack worn over the cloak)
    wants the basket moved off the back and the cloth held under it.
13. **A roof opens as soon as the pointer crosses its house**, with no dwell: sweeping the pointer over
    a street opens and closes each in turn (the demo's ninth part shows it). A short wait before it
    opens is a number in `Castle.Cutaway`, if he wants one.

Driven only by script: the H key (nothing of `Castle.Input`'s real keys can be driven headless: its
command-line twin `--all-roofs` was), and the pointer's clearing (the scripted pointer; no real mouse).

## His answers to the list of open questions (the same day)

He asked for the list ("Let's pull a list of open questions for the current build, I have lost
track."); it was put to him numbered, with "anything you skip stays as it is now". His answer, whole:
"Let's cut down the walls in-line with the camera too, the transparency is there so  the player can
just see through them, as far as the game is concerned the walls are still there to block light. The
taper is adequate. We can have the H k toggle through, dynamic transparency, full trasnparency, or no
transparency. Move the cart once for now, who pulls works great the way it is. When we get to the
stockpile we can sort out the details about the carts contents. The cloth is fine, for the water, we
have seemed to have fixed it, along with the grass in the air, I will continue testing to recreate the
conditions, but for now I can't. My tests show the workers keep working no matter how far the camera is
away fromt he camp. So that is it for this first pass, then we will track down the cart issues, then
the stockpile."

What it answers (the list's numbers):
- 5, the walls: cleared on the camera's side as well. Built.
- 6, light: none let in ("as far as the game is concerned the walls are still there to block light").
  Nothing changed: the sun's maps are untouched.
- 8, the key: three views, in his order. Built.
- 9, the taper: "adequate". Stands.
- 3 and 4, the cart: moved once "for now"; who pulls it "works great the way it is". Stand.
- 2, the cart's salt as stock: put to the stockpile ("When we get to the stockpile we can sort out the
  details about the carts contents").
- 10 to 14, the cloth: "The cloth is fine". Stand.
- 15 to 17, the water and the grass: his words above, and no more: he cannot recreate either now and
  will go on testing. Nothing is known of what mended the grass in the air.
- 18: his own test, in his words: "the workers keep working no matter how far the camera is away fromt
  he camp".
- 19: "then we will track down the cart issues": read as the herds' searched-out ways with the pull
  (the stress runner's crowd at 22 s for 12; "Measured, the cart"). **Next, after this pass; then the
  stockpile, his to open.**
- 7 (a wait before a house opens under the pointer): not taken up; stands (none).
- 1 (does he accept the branch): not answered. **Not merged.** It is the one question left.

As built (`docs/systems/rendering.md`, "A roof cleared on the camera's ray"):
- **The walls on the eye's side of a cleared house are cleared with its roof**, whole of them (panel,
  timber and gable), by their place: within 0.27 m of the walls' outer line, above the floor. Not by
  what they are made of (the frame's timber is a trunk's material). A wall is whole edge-on and clear
  from a cosine of 0.30 between its outward side and the way to the eye (level), fading between,
  dithered by the pixel. The walls beyond stand and are seen from inside. The pointer's ray goes
  through a cleared wall. Light is as it was.
- **The ground a wall stands on is meshed** (it was hidden by the wall: a slit into nothing under a
  cleared one). The same rule draws the ground under every tree's trunk: 2,274 quads more of 5.0
  million at the forest's fixed view.
- **Three views**: houses open where the eye and the pointer are; every house open; none. H goes
  through them in that order and says which in a note (the first and the last look alike until
  something is pointed at). `--all-roofs` and `--no-cutaway` are the second and the third. A load
  leaves the view as it is.
- `pick_check` 54 -> 59: before a house's front its front wall is cleared and its back wall, its
  middle and its floor are whole; a side wall seen edge-on stands; a ray through the cleared front
  wall, clear of the door, goes on inside; with the third view nothing clears and the ray meets the
  wall; the three views are in his order. Each rule taken out fails its check (the pointer's pass, the
  facing, the third view, the floor's exemption).

Seen: a cleared hovel from five sides and tilts (the walls on the eye's side gone, the far walls and
the floor seen, a wall edge-on standing) and at the default view; the pointer held still on a near
gable wall at a low tilt, recorded 150 frames: the wall fades, the room is seen, and the picture then
holds still (largest change between two frames 0.03 of 255); 26 hovels all open at a low tilt;
`--msaa 0` (a screen door at the edges, as the roof); from close and low, under the eaves (tilt 0.15,
6 m off, two sides): the room seen through the near walls, no slit where the roof lay on the cleared
beam; the debug build's game with the pointer on and off a near wall and with every house open. Not
seen: the fade with the camera turning (stills at several turns only: there is no scripted turn); a
sleeper picked through a cleared wall in the game (`pick_check` has the ray going on to the floor). Measured: 26 hovels in view, twice each way: every house
open 1.52 and 1.52 ms of GPU against 1.48 and 1.51 before the walls; as it stands 1.49 and 1.50; none
1.49; CPU 0.63 to 0.64 throughout. The forest's fixed view 0.49 ms against 0.50, the camp's 2.05 and
2.00 against 2.03. `tools/shadow_still.sh`: 0.00 % (no house is in its view: it says the land's shader
was not disturbed).

His calls, added:

14. **The timbers are cleared with the panels**: "walls" was read as the whole wall. Keeping the frame
    standing (a cage of posts, the panels gone) is the other reading, a change of one set in the
    shader.
15. **A wall edge-on to the eye stands whole** and fades as it turns to face it (clear from about 17
    degrees past edge-on). The numbers are `Face_Lo` and `Face_Hi`.
16. **The roof's half-drawn edge stays over a cleared wall** (its taper is as he called it, adequate):
    from low down it veils the top of the room a little.

Driven only by script: the H key and its note (nothing of `Castle.Input`'s real keys can be driven
headless; `--all-roofs` and `--no-cutaway` were), and the pointer (the scripted one; no real mouse).

## Known limits

- **The herds' searched-out ways with the pull** ("Measured, the cart"): not explained.
- **A cloak is one plane of ground**: on a terraced slope a cloak lying at a terrace's edge can hang
  into the step below or over it; at the camp on the slope (the demo's) the sleepers' cloaks lie
  over them.
- **A basket or a sack on the back** came through the cloak as first built; since his answer (above,
  "His answer to the roofs and the cloth") the cloak hangs round and behind it: the pack's top shows
  at the collar, seen from above, and in winter a sliver of a basket's edge still shows in some poses.
- **A sleeper in a hovel** was looked at through its cleared roof (above): its cloak slid off it, now
  mended. On that sleeper (no job: not a hunter's quiver) **a brown shape on its flank shows through the
  cloak**: by its place its upper arm, whose sleeve is wider than the capsule the cloth is kept off; not
  identified for certain (capsules for the forearms were tried, changed nothing seen, and were taken
  out again).
- **Through a cleared roof** the far slope's underside shows, in steps, within the taper by the walls,
  and the top block of each gable shows as a small pale square at the ridge's ends. With `--msaa 0`
  the half drawn edge is a visible screen door.
- **The cloak is put on and laid over its sleeper at once**, not by hand; it falls where its owner made
  its bed and lies there until night.
- **The cart moves once**: standing on a stockpile's ground it stays, even if a nearer stockpile is
  zoned later; it is not pulled anywhere else. Pulled, it is drawn going through whatever its puller
  walks between (trees): nothing of it is in the world in tow.
- Loading a save in the running game begins every cloak again (put on, laid over its sleeper or laid on
  its bed), as the serfs are.

## Measured, the cart (seed 1)

**Not explained: with the pull the herds' dry ways are searched out where they never were without
it.** The crowd of the stress runner (forty-eight, no needs, no demand chain, sixty days from seven in
the morning) took 22 s where it took 12; the time is in the herds' plans (a herd's way kept out of
water, searched to its budget of 40,000 floors: 737 such plans, none without the pull). Started at
seven other times, each run twenty or sixty days: with the pull 3, 6, 7, 16, 21, 34 and 935 such plans,
without it none, every time; at a quarter past seven they all fall between the fourth and the sixth
day, and the run takes 12.0 s where it took 11.7. In the same runs the plans "known out of reach with
no search" fall by about as many. The walking map is not at fault as far as the debug build can tell:
it compares every mended stack with the stack read whole, cells and pieces, and found nothing through
the six days in which they happen. Where a herd's way runs into water a serf could wade, the pieces of
ground (a serf's) say it can be got to and the herd's dry search runs to its budget: a known limit of
the herds (`routes.md`, "Not built"). Why the pull sends herds there, every time, is not found. In the
six-strong reference band it does not show (15 plans searched out with the pull, 23 without). The
stress runner passes ("nothing died, nothing dropped"); nothing waits on the time.
