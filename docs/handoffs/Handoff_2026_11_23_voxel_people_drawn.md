# Handoff, 2026-11-23 (night): the serfs shaped as the bought skeleton, and drawn as voxel parts

**Merged into `main` on his word of 2026-11-24, morning** ("great I like it, when the shell is done, merge
and get ready for a clear, next we are going to polish up the animations"), once the gate on 22551f9 had
passed: `main` fast-forwarded from 091b720 to 027491d (36 commits); `bin/` holds 22551f9's gated build.
What is next is on the state page. Below, in the order they came: the first try and his answers of the
night, then each of his messages of 2026-11-24 with how it was read, what changed, what was run and its
gate.

Branch `voxel-people`. Four commits of code on top of the count's (98950de):
ca9f7d7 (the reference body), 28f7f71 (drawn as voxel parts), 03c4234 (the form kept, the face higher),
409eb55 (a fault in the count's mesh, found by the gate). **Gated at 409eb55: passed; that build was put
in `bin/`** ("The gate"). **Then his answer of 2026-11-24, early morning: the head a bit smaller**
(85132c5; "His answer", at the end, with its own gate). His brief is `docs/design/Voxel_people_brief.md`;
the count before this is `Handoff_2026_11_23_voxel_people_counted.md`.

## His words

The first message (2026-11-23, late evening), with seventeen pictures he put in `docs/reference/`: four
of a voxel Roman legionary (`voxel-roman-legionary-character-*`), five of a voxel knight
(`voxel-knight-character-*`), eight of the voxel skeleton (`sceleton-character-*`):

> the skeleton model is the refrence bone structure, there are some examples when they are "fleshed"
> out, a small button nose is fine, but the nose you have is too long

The second, sent while the first was being built, on the stills of the first try in its windows:

> why are their forheads so big? where are the hands? the slim waists? the shaped arms and legs?

| His words | Read as | Done |
|---|---|---|
| "the skeleton model is the refrence bone structure" | the count's call 1 answered: move our serfs to the bought skeleton's proportions. The skeleton read from its own files (`Skeleton_Character.zip`: a T-pose COLLADA, each part a node, voxels of its own, 61 to its height) | the reference body (ca9f7d7), behind `--no-reference-body` |
| "there are some examples when they are "fleshed" out" | the legionary and the knight: how flesh and clothes sit on that skeleton | first read too narrowly (limbs two pixels thick and straight); see the second message |
| "a small button nose is fine, but the nose you have is too long" | more form's nose (a pixel wide, 1.2 deep, 1.5 tall) | a pixel square, half a pixel proud |
| (no word on the count's call 2, the mesh) | stands as built: my default, the colour looked up where it is drawn; how it is built, the picture the same either way | drawn (28f7f71); a departure from the brief, below |
| "why are their forheads so big?" | the face sat in the head's lowest six rows: the eyes on the fourth row from the bottom, the hair over the top half | the eyes on the head's middle row (03c4234) |
| "where are the hands? the slim waists? the shaped arms and legs?" | the first try dropped what more form gave: two-pixel straight limbs, a straight waist, a hand as wide as its wrist | more form's limbs, waist and hands kept, the waist and the wrist drawn in harder so they show in voxels (03c4234) |

**A retraction, first**: the first try took off the waist, the limbs' rounding and narrowing, a pixel of
the limbs' thickness and of the trunk's width. Nobody asked for that; I read "fleshed out" as the
blocky voxel examples and took the form he had liked on 2026-11-22 off with it. It never left the
branch; 03c4234 puts it back.

## What is built

### The reference body (ca9f7d7, then 03c4234)

From the skeleton's files: a head 20 voxels of 61 (a third of the height), 12 wide and 14 deep; the
thighs' joints at 24.5 (40 %); the hands, hanging, ending at 17.3 (28 %: the middle of the thigh); an
upper arm of 11, a forearm of 8, a hand of 4. On the body pixel still (the brief's first build keeps
the joints on it):

- **the head** 10 pixels tall at 1.525 m and as the square root of the height else (a tall man's head is
  30 % of him, a short woman's 34 %), 6 wide and 7 deep, rounded by a pixel, narrowing to the jaw;
- **the face**: the eyes on the head's middle row, the brows above, the hair over the rows above those;
  the nose under the eyes; a row of cheek; the mouth; the chin to the head's last row. (The first try had
  the face in the lowest six rows: "why are their forheads so big?")
- **a button nose**, a pixel square and half a pixel proud;
- **the hair** a voxel proud of the head over the crown and the forehead to the brows, and down the back
  and the sides as far as the style is painted there; long hair, braids, a bun, a kerchief's knot and a
  full beard placed by the head's size; a hood sized to the head;
- **no neck** (the skeleton's head sits on its chest); the hips' joint at 57.5 % of the height under the
  head; the shoulders' joints a pixel under the chest's top; the chest a pixel deeper; the arms as long
  as leaves the hands' ends at 28 %, the upper arm 0.58 of the arm above the wrist;
- **the rest as more form has it**: limbs three pixels thick (a child's two), rounded and narrowing to
  the wrist and the ankle, the hands and the feet as they were; the waist drawn in by 0.22 (more form's
  0.12 hardly shows in voxels of half a pixel) and the forearm narrowing by half, to a wrist narrower than
  the hand.

`--no-reference-body`: the serfs as they were, **to the bit**: a hash of every field of 72,000 rigs and
skins (3,000 people, six jobs, summer and winter, with more form and without) is 98950de's, run on the
first commit and on the third (11416224824292578703 without more form, 1893737104172277074 with it; the
second does not touch the body).

### Drawn as voxel parts (28f7f71)

When a serf's look is made, its look as voxel parts is made beside it (`Castle.Bodies.Voxels`: its boxes
filled with voxels of 2.5 cm, one grid a bone) and drawn in its place: in the view, in the sun's figure
maps and in the fire's six faces, one draw a pass (`rendering.md`, "Serfs of voxel parts").
`--no-voxel`: as boxes, as they were.

- **How a face is coloured departs from the brief**: a part's open faces are merged into rectangles
  whatever their colour, and the colour is read where the face is drawn, voxel by voxel, from its look's
  slot on the GPU. Merged by colour as the brief has it, the final body is 6,979 triangles a serf (the
  brief's limit is 2,600); merged whatever the colour, 1,557 (the most 1,864), under today's boxes
  (2,274). The picture is the same either way.
- A look takes 3.6 ms to make; the game makes at most one again a frame, so the band dressing for winter
  at once comes over as many frames (4 to 8 ms of figures in each of thirteen, measured on the first
  try's body) and not in one.
- A look too big for its parts would be drawn as boxes, said once (none was, over 7,200 of the new body
  and 3,600 of the old).

## What was run, and what it showed

- `serf_check` (all pass): adults' heads 29.7 to 34.5 % of their height (the skeleton's 33 %, held
  within five points: a pixel and a half of the shortest adult); the hips' joints 37.9 to 40.6 % (40 %);
  the hands, hanging, end at 27.0 to 29.7 % (28 %); no serf's hands hang to its knees; a button nose on
  every face, half a pixel out of it. The drawn quads lie on open faces and cover them all, and each
  part's bytes are its grid: proved by breaking each (quads a voxel short: 480 looks short; bytes one
  place on: 3,654,697 astray; the faces across Z a layer off: 528,720 faces astray).
- **What the drawing costs** (RX 6900 XT, 1920 x 1080; sixty serfs in a row 14 m off; 600 frames, twice
  each way): 2.41 and 2.41 ms of the GPU a frame as voxel parts, 2.35 and 2.39 as boxes. The CPU 1.53 and
  1.89 ms a frame for 1.04 and 1.22, the sixty looks' making (221 and 338 ms, in the frame they arrive)
  among it; a gate ran beside those runs. The slots take 17 MB of the GPU's memory, the frame's list 2 MB.
- **Looked at**: voxel parts beside the same serfs as boxes at 3 m, at 12 m and at the game's own
  distance, a crop enlarged four times: the same serfs, the voxels' edges sharper; no speckle seen in a
  still. Whether they shimmer (a voxel's colour has no smaller levels to fall back on far off, where a
  skin has three), counted rather than watched: thirty serfs standing 22 m off (some 75 pixels tall),
  frames 40 to 69, the pixels where the two ways differ (12,644 of them, the figures): from one frame to
  the next they change by 1.57 of 765 as voxel parts and 1.19 as boxes, a third more and small either
  way. **Not watched in motion, and no pan recorded.**
- The game built in debug, the band run into winter and twenty serfs chopping in winter: nothing raised.
- The band of the reference stake at work, before and now, the same frame of each: every serf where it
  was (the drawing only; the gate's run of the game as it is played holds the rest).

## What he might take for a fault

- **Hands in the head at work.** Of sixty serfs at each work, every one puts a hand or a forearm into its
  own head when it chops (3.0 pixels deep), aims (3.0) and eats (1.7, sitting 1.7); picking 19 (2.0).
  **The body on `main` does it too** (chop 2.4, aim 3.0, eat 1.1; picking 5): the poses were made for a
  head of six pixels. `serf_check`, "hands at work", prints it and does not fail on it.
- **A deer carried across the shoulders** is placed by the shoulders' height, through where the head
  is: not looked at in a still.
- Bending to pick or put down, the big head comes low and forward: the old poses on the new body.
- The hood is a box over the head, as before, now as tall as the head with a pixel round it.

## Departures from the brief

- The mesh (above): the colour looked up, not carried by the quad.
- The skeleton's spine has a belly part between its hips and its chest; ours bends at the waist only.
  Not added (his call 2).

## His calls (each stands as built on no word)

1. **The hands at work**: keep the hands out of the head (the bow drawn to beside the face, the axe wound
   up beside it), or leave the poses as they were? Default: as they were.
2. **A belly joint**: the skeleton bends at its belly as well as its waist. Add one? Default: not added.
3. **A tall man's head**: 30 % of his height as built (the square root of the height), or a third for
   everyone (a 1.90 m man's head would be 63 cm)? Default: as built.

## The gate

- **On 03c4234, from a clean copy: failed**, at `serf_check` in the debug build (`raised
  CONSTRAINT_ERROR : castle-voxel_mesh.adb:22 range check failed`). A quad's width and height are kept
  less one (a width of one is kept as 0), and `Unpack` read them back as `Positive (...) + 1`: the debug
  build refuses the 0 before the one is added; the release build, its checks suppressed, read them
  right. The fault came with the count (98950de, not gated), where nothing called `Unpack`; this
  round's check of the drawn quads against the open faces is its first caller and its only one (the game
  never reads a quad back: the shader reads the words as kept). Mended in 409eb55 (`Natural (...) + 1`);
  `serf_check` in debug then passed, all of it.
- **On 409eb55, from a clean copy: passed**, in 58 minutes: both builds with no warning but
  `water_sim_check`'s six; the nine checks in debug, all passed; the reference check, line for line; the
  game as it is played, 41 days, the kept log line for line and its state d5bb6e2fdd00202f, which is
  `main`'s (the serfs' look touches nothing the colony does), and saved on its twentieth day, loaded and
  run on to the straight run's state; the stockyard sites, the turned streets and the square's sites, in
  release and in debug; the herds' places; the stress runner (nothing died, nothing dropped); the flora
  (one hash in both builds).
- **That build is in `bin/`** since 2026-11-24, 01:07, in the place of 6c118a2's (`main`'s code). The
  row of seven, run from there (1920 x 1080, one frame, counted where a pixel is off by more than 2 of
  255): against the still that was sent, 7,684 pixels (at most 13 off); the same build run twice, 4,699
  (at most 10): the frame is not the same to the bit from one run to the next. With
  `--no-reference-body --no-voxel`, against 6c118a2's own game: 801 (at most 6); 6c118a2's run twice,
  168 (at most 4); against that second run, none (at most 2). The save format is not touched.
- A gate on the first try (ca9f7d7) was stopped at the square's sites when that try was set aside;
  nothing had failed in it.

## His answer (2026-11-24, early morning)

He sent a picture with it, kept out of the repository: a chart of a face's proportions, one drawn man's
face seven times, each with red lines. The face is five eyes wide, an eye's width between the eyes;
the nose as wide as the space between the eyes; the eyes at the middle of the head, from the top of
the hair to the chin; the ears' foot level with the nose's; the mouth's corners under the pupils; the
face in thirds, the hairline to the brows, the brows to the nose's foot, the nose's foot to the chin.

> I mean it's close, just cut the head down a bit, make it a bit smaller, and I think we are good.

| His words | Read as | Done |
|---|---|---|
| "I mean it's close" | the face as it was, held to his chart, is near enough: nothing of the face moves | its rows and columns as they were |
| "just cut the head down a bit, make it a bit smaller" | the head smaller by a little every way but its width, which the face's columns need: a row of the chin or of the crown (or one of each), a pixel of its depth | 85132c5 |
| the chart | the measure the smaller head is held to: the face in thirds, the eyes at the head's middle | a head of 9 has both; `serf_check` holds them |
| "and I think we are good" | the look accepted once the head is smaller: **not the word to merge** | not merged |
| (my call 3 of the night: a tall man's head) | answered by this: smaller, not a third for everyone | a tall man's 24 %, a short woman's 29 % |
| (calls 1 and 2: the hands at work, a belly joint) | no word: they stand as built | |

**The other reading, a word away**: narrower too. A head 5 wide puts the eyes an eye apart, as on his
chart, but the head is then taller for its width than the chart's (some 1.9 to 1, the chart's 1.5).
Tried in scratch for a picture (`if_narrower_too_not_built.jpg`); not built.

### What changed (85132c5)

- **The head**: 8.5 pixels tall at 1.525 m (it was 10, the skeleton's 20 voxels), as the square root of
  the height else, never under 8 (`Ref_Head_Least`: at 7 a child's mouth would be its head's last row).
  Of 2,700 adults built, 2,586 have heads of 9 pixels and 114 of 8 (the shortest); children 8. Adults'
  heads are 24.3 to 29.0 % of their height (they were 29.7 to 34.5). Six wide as before (the skeleton's
  12 voxels); 6 deep (it was 7; `main`'s head is 6 too).
- **The face**: the same rows and columns. From the top: the hair, the brows, the eyes, the nose, a row
  of cheek, the mouth, the chin. What goes is a row of the chin (a head of 10 made 9), a row of the
  crown and one of the chin (11 made 9, 10 made 8), or a row of the crown (a child's 9 made 8). On a head
  of 9 the eyes are on its middle row and the face is in thirds as on his chart, three rows from the
  brows to the nose's foot and three from there to the chin; on a head of 8, the eyes on the row over
  its middle.
- **What the head gave up, the legs and the trunk took**, as the rule has it (the hips' joint at 57.5 %
  of the height under the head): the hips' joints at 40.6 to 44.4 % of the height (they were 37.9 to
  40.6; the skeleton's 40 %), the arms a little longer so that the hands still end at 27.0 to 29.7 %.
- **Tried first, in a scratch copy with the sizes as options**, the same views each way: 9 at 1.525 m
  (most men 10: a row less for everyone, hard to see at the game's distance), 8 (two rows less; a
  child's head 7 without a floor), and 8.5 (built: a row or two less, nearly every adult 9). Their
  stills against the built ones: no more apart than two runs of one build.

### What was run

- `serf_check`, release and debug: all pass. New: every head 8 or 9 pixels tall with the nose's foot 3
  pixels over the chin's bottom (none otherwise of 6,000 built); adults' heads under the skeleton's 33 %.
- `--no-reference-body`: the hash of 72,000 rigs and skins is still 98950de's (11416224824292578703
  and 1893737104172277074): the body as it was, to the bit.
- **The hands at work** (printed, not failed): picking, 5 of 60 serfs put a hand into the head (1.5
  pixels deep; it was 19 and 2.0); eating, 60 (1.2; it was 1.7), and sitting to eat the same; chopping
  and aiming, 60 (3.0, as before). `main`'s body: picking 5 (1.0), eating 60 (1.1), chopping 60 (2.4),
  aiming 60 (3.0).
- **A look**: 1,582 triangles drawn (the most 1,866; they were 1,557 and 1,864: the longer limbs and
  trunk add more than the smaller head takes off); the brief's way 7,087; made in 3.40 ms. The GPU's
  cost was not timed again (25 triangles a serf more than the 1,557 timed: 1.6 %).
- **Looked at**: four serfs close, the row of seven, the band at work at the game's distance (enlarged
  twice), six in winter hoods, fourteen from the front and from the back (a bald fringe, long hair, a
  kerchief, full beards): nothing out of place seen. Pictures in
  `~/CASTLE_GAME/releases/voxel_people_2026_11_24/`.
- **The debug game**, on this body: twenty chopping in winter, and the band from day 44 into winter
  at sixteen times speed: nothing raised.

### What he might take for a fault

- The bodies a little longer under the smaller head: the legs and the trunk took the rows (the hips at
  up to 44 % of the height).
- The hands still go into the head at chopping and aiming (3.0 pixels), less at picking and eating.
- The hair over the crown is still a flat-topped box a voxel proud of the head.

### Its gate

On 85132c5 from a clean copy: **passed**, in 59 minutes: both builds with no warning but
`water_sim_check`'s six; the nine checks in debug, all passed (`serf_check` with the new head checks);
the reference check, line for line; the game as it is played, 41 days, the kept log line for line and
its state d5bb6e2fdd00202f (`main`'s), and saved on its twentieth day, loaded and run on to the straight
run's state; the stockyard sites, the turned streets and the square's sites, in release and in debug;
the herds' places; the stress runner; the flora. **That build is in `bin/`** since 2026-11-24, 04:56,
in the place of 409eb55's.

## His next message (2026-11-24, early morning): the head's shape

Eight pictures with it, put by him in `docs/reference/` and kept out of git: voxel characters of the
same make as the bought skeleton, each standing whole. A young man with a shock of spiky hair; a
gunslinger in a broad hat, a moustache and stubble; a man in a black suit, long black hair and a beard;
a woodcutter, combed-up hair and a full beard; a viking with a full beard; a woman with a black bob and
a band across her brow; a woman pirate with curly red hair; a queen in a headdress. What their heads
share, read from the eight heads cropped side by side:

- **the hair is a mass**: it stands several voxels over the crown, stepped and uneven, not flat; it is
  wider than the head, and comes down the sides to the ears or past them;
- **ears** on every head whose sides are bare: skin, a voxel proud, at about the rows of the eyes and the
  nose;
- the head with its hair **squarer** than ours, about as wide as it is tall;
- **beards are masses too**, round the jaw from the ears;
- the faces painted a voxel fine: brows a voxel tall, an eye a white and a pupil, a mouth a line. Not
  taken (below).

> I have provided some refrences for the head shape ... the models can be a diffrent scale than the rest
> of the world

| His words | Read as | Done |
|---|---|---|
| "I have provided some refrences for the head shape" | the head's form as the eight have it: the hair a mass, ears, a squarer outline, a beard round the jaw. Not the face's paint: he called the face close, and painting it a voxel fine is the brief's step 3, not opened (a call) | below |
| "the models can be a diffrent scale than the rest of the world" | leave to size the head's parts off the 5 cm pixel, in voxels, where the shape needs it (his word in the brief: "they aren't exact blocks and sizes to the world"); not an order to resize the serfs | the hair, the ears and the beard in half pixels (a voxel) |
| (the narrower head, put to him with a picture) | no word: stands as built, six wide | |

**The other reading of the second, a line away**: the bodies back to the skeleton's shares (the hips at
40 %), the serfs shorter than their heights by what the head gave up.

### The first try, and his word on it

A first try was sent him as a still before anything was committed (`head_shape_close_before_and_now.jpg`,
`heads_beside_your_eight_for_you_only.jpg`): the hair a box two voxels proud all round, made uneven a
voxel at a time over all of it (later two voxels a side), ears, the beard round the jaw. He answered, the
same morning:

> ok great, can we make the heads more oval shapped? so the hair doesn't look like blocks or afros?

| His words | Read as | Done |
|---|---|---|
| "ok great" | the direction kept: a mass, ears, the beard | kept |
| "can we make the heads more oval shapped?" | the head with its hair an oval from the front and the side: widest about the brows, narrowing over the crown and down to the chin | the hair narrows over the crown and down the sides; the jaw already narrows to the chin |
| "so the hair doesn't look like blocks or afros?" | no box-cornered mass, and no tufts: the uneven voxels made the afro | the tufts taken out (never committed); the mass hugs the head, a voxel proud at the temples |

The tufts cost more than they showed: with them a look was some 1,861 triangles drawn (the most 3,428)
for the oval's 1,638.

### What changed (3c39116, 85511a1)

- **The hair** (short, long, braids, a bun; not cropped, under a kerchief or in a hood): a voxel proud of
  the head at the temples, two over the crown and at the back, one over the forehead to the brows; it
  narrows over the crown by `Crown_Taper` (0.25: a quarter narrower at its top) with its edges rounded a
  pixel and a half, and comes down the sides in one piece with it, narrowing by `Side_Taper` (0.15), to
  over the ears where they show and to the mouth's row where it is long, a pixel short of the face.
  Cropped hair and a kerchief, close to the head as before, narrow over the crown too (by 0.2).
- **Ears**, a box half a pixel wide (a voxel proud of where the jaw's narrowing has drawn the head's side
  in), a pixel deep and a pixel and a half tall, from the nose's foot, a pixel behind the head's middle:
  where the hair leaves the sides bare (bald, cropped, short, a bun), not under a kerchief, long hair or a
  hood. On 1,704 of 6,000 heads built.
- **A full beard round the jaw**: a voxel proud at the sides and in front, from in front of the ears down
  a pixel and a half past the chin, narrowing to its foot as the jaw does (it was a block four pixels wide
  on the chin).
- **The face itself as it was**: its rows, columns and paint; the head's box 6 wide, 6 deep, 8 or 9 tall.
- **`--no-head-shape`**: on 85511a1, the head as at 85132c5, to the bit (a hash of the reference body's
  72,000 rigs and skins, 7348574700058545616 and 15888902940299291596, is 85132c5's). After his list it
  turns off the hair's mass, the ears and the beard round the jaw, and leaves the list's changes on.
- **A look's room for drawn quads** 4,096 (it was 2,048: its most look is now 1,038 quads, and
  `serf_check` holds room for twice the most).
- **Found on the way (3c39116)**: with the hair made uneven a voxel at a time, `serf_check` (release)
  stopped with a storage error and a still showed some serfs' clothes speckled; both went once the
  quads fit their room. The cause is inferred: nothing stopped the mesher writing past its array where
  the checks are suppressed. It now raises. Tried in a scratch copy with room for 300 quads: the game
  said once "serfs: a look too big for its voxel parts, drawn as boxes", drew all seven of a row as
  boxes, and ran on.

### What was run

- `serf_check`, release and debug: all pass; new: two ears on every head whose sides the hair leaves bare
  (1,704), none on any other; the hair or kerchief narrowing over the crown on every head that has one
  (5,400). The face's checks of 85132c5 hold (every head 8 or 9 pixels, the face in thirds).
- `--no-reference-body`: the body as on `main`, to the bit (the hash of 98950de, 11416224824292578703
  and 1893737104172277074).
- **A look**: 1,638 triangles drawn (the most 2,076; on 85132c5 1,582 and 1,866); as boxes 2,337 (the
  ears and the beard: 2,274 before); made in 3.52 ms. The GPU's cost not timed again.
- **The hands at work**: as on 85132c5 (chop and aim 3.0 pixels, eat 1.2, picking 5 of 60).
- **Looked at**: four serfs close, the row of seven, fourteen from the front and from the back (a bald
  fringe and his ears, kerchiefs, long hair, a braid), six in winter hoods, the band at work at the game's
  distance (enlarged twice), and drawn flat, front and side, from their voxels: seven serfs, two with a
  bun (it stands out of the mass behind) and one with braids (`oval_heads_*.jpg`); nothing out of place
  seen.
- **The debug game**, on this body: twenty standing in summer, twenty chopping in winter, the band from
  day 44 into winter at sixteen times speed: nothing raised.

### What he might take for a fault

- The faces are still painted at the body pixel, their brows and eyes two voxels tall; his eight paint
  theirs a voxel fine (an eye a white and a pupil). That is the brief's step 3: his call, below.
- The hood (winter) is a box, as before; the hair under it is the close cap.
- The ears are small (a voxel proud); a head turned to the camera shows them, one seen from the front
  hardly.

### His call

1. **The faces a voxel fine**, as his eight have them (brows a voxel tall, an eye a white and a pupil, a
   mouth a line): the brief's step 3, painting moved from the skin to the voxels. Default: not now.

### Its gate

On 85511a1 from a clean copy: **passed**, in 58 minutes (both builds with no warning but
`water_sim_check`'s six; the nine checks in debug, all passed; the reference check line for line; the
game as it is played, 41 days, the kept log line for line and its state d5bb6e2fdd00202f, `main`'s, and
saved on its twentieth day and run on to the straight run's state; the sites, the herds, the stress
runner, the flora). **That build is in `bin/`** since 2026-11-24, 06:37, in the place of 85132c5's.

## His list (2026-11-24, morning), on the oval heads

> clip the arms at the sholders into the main body to remove the gap at the connection, make the arms a
> bit thinner, and I think we have a winner, make the chin a bit more rounded, make the detail finer,
> elbows angled away from the body at a resting state, slight bend at the arms, add thumbs, and improve
> the detail of the hair a bit, and I think we got it.

| His words | Read as | Done |
|---|---|---|
| "clip the arms at the sholders into the main body to remove the gap at the connection" | the upper arm's top reaching a voxel into the chest's side, so that no seam shows at the shoulder | below |
| "make the arms a bit thinner" | a grown serf's arm a voxel thinner (the upper arm six voxels across to five) | below |
| "and I think we have a winner", "and I think we got it" | praise: **not the word to merge** | not merged |
| "make the chin a bit more rounded" | the head's lower corners rounder, on the reference body only | below |
| "make the detail finer" | my call answered: the face painted a voxel fine (brows a voxel, an eye a white and an iris, a mouth a line). The other reading, a line away: the whole figure a voxel fine | below |
| "elbows angled away from the body at a resting state, slight bend at the arms" | standing at rest, the upper arms further out from the sides and the elbows bent a little more; walking and work as they were | below |
| "add thumbs" | a thumb on each hand | below |
| "improve the detail of the hair a bit" | strands of shade along the hair's fall, a voxel fine; colour only, no bumps (the tufts were just taken out) | below |

### What changed (a commit an item)

- **The shoulders (5deffe7)**: the upper arm's inner side half a pixel (a voxel) into the chest's side
  (`Ref_Shoulder_In`); it was a twentieth of a pixel out from it, and the chest's rounded top corner left
  a notch there.
- **Thinner arms (b412563)**: a grown serf's arm 2.5 pixels across (`Ref_Arm_W`; it was 3), the forearm
  0.2 less as before. A voxel's middle lies a quarter of a pixel off a joint, so a box 2.5 across about it
  comes out four voxels or six: it is set a quarter of a pixel toward the chest and comes out five (the
  upper arm six before; the forearm five at its top, narrowing to the wrist as before). A child's arm as
  it was (two pixels, four voxels). With the clip, the shoulders' span is a pixel narrower each side.
- **The chin (47bbf89)**: the head's edges rounded a pixel and a half (`Ref_Head_Round`; it was one), the
  reference body's alone: the chin's corners a voxel rounder. The jaw's narrowing (shared with the body
  as it was) untouched; the ears, the side hair and the beard, sized to it, stand as they did.
- **Thumbs (61fa599)**: a box a voxel square and two voxels tall at the front of each hand, on the side
  toward the body, a voxel proud, painted as the hand and mirrored as it. A look has at most 27 boxes of
  28 now; `Add` raises past 28 (a build with its checks off would have written past the list).
- **Arms at rest (0b228cc)**: standing at rest, on the reference body, the upper arms 0.18 rad further out
  from the sides (`Rest_Spread`), the forearms 0.30 rad back in toward the body from them (`Rest_Fore_In`,
  a new turn of the pose's forearm about its forward axis), so that the elbows stand out of the line of
  the arm, and bent 0.17 rad more (`Rest_Elbow`); faded out as the serf walks (gone at 0.6 m/s) and as it
  works. First values. `--no-rest-arms` gives the arms at rest as they were.
- **The face a voxel fine (e4b694b)**: the head's net is two texels a body pixel; what the body pixel
  painted is painted two by two, then the face over it a voxel fine: a voxel of forehead under the hair,
  the brows a voxel tall and three wide, each eye a white on its outer side and an iris on its inner, two
  voxels tall, the nostrils a voxel darker beside the nose's foot, the mouth a line a voxel tall with the
  lip's shadow under it, freckles a voxel each, a scar a voxel wide. A fine net's grain keeps to five
  shades. The skin sheet is 128 texels tall (it was 64), grown in height only. **A departure from the
  brief**: its step 3 paints on the voxels, with the skin sheet not needed; this paints on the skin.
- **The hair a voxel fine (9718f8a)**: the hair's own boxes (the mass, cropped hair, long hair, a full
  beard) two texels a body pixel, each column of each face one of five shades of the hair (up to
  `Hair_Strand`, 0.15, darker or lighter): strands with the fall down the sides and front to back over
  the crown. Colour only.
- **Not taken**: the other reading of "make the detail finer", the whole figure a voxel fine (clothes,
  a belt's buckle, hems, fingers): a call, below.

### What was run

- `serf_check`, release and debug: all pass. 36,000 serfs built: every net inside the skin, at most 79
  of its 128 rows and 27 boxes of 28; the parity of voxels and boxes, the mirror, the head's checks (8 or
  9 pixels, the face in thirds, ears, the crown narrowing) hold. A look's colours merged for room in 857
  of 7,200 looks (941 before).
- `--no-reference-body`: the hash of 72,000 rigs and skins over the skin's first 64 rows is 98950de's
  (11416224824292578703 and 1893737104172277074), and no texel past row 63 is set: the body as it was,
  to the bit. And drawn: the row of seven with `--no-reference-body --no-voxel` against 6c118a2's own
  game, 3 pixels off by more than 2 of 255 (6c118a2 against itself, 3; against its second run, none).
- **A look**: 1,677 triangles drawn (the most 2,112); as boxes 2,553 (the thumbs: 2,337 before); made in
  3.52 ms. The GPU's cost not timed again.
- **The hands at work** (printed, not failed): chop and aim 3.0 pixels into the head, as before; eat 1.3
  (1.2 before); picking 5 of 60 (1.6); putting down 3 (0.9). `serf_check`'s lines on the hands hanging
  (27.0 to 29.7 % of the height, none to the knees) measure the pose `Standing` gives, not the game's rest
  pose: they are as they were.
- **Looked at**: four serfs close and three closer, before and now; the row of seven with the arms at rest
  and with `--no-rest-arms`; six in winter hoods and cloaks; the band at work at the game's distance
  (enlarged twice: no sparkle seen); three chopping and three aiming close (the thumbs on the haft and the
  bow); eight heads drawn flat from their voxels, and one serf large (the thumb a voxel proud at the front
  of the hand, seen from the side).
- **The debug game**: twenty standing in summer and twenty chopping in winter, on this body: nothing
  raised.

### What he might take for a fault

- The thumbs show from the side and at work; from the front a thumb lies over the hand's inner column.
- The hands still go into the head at chopping and aiming (3.0 pixels), as on `main`.
- Clothes are painted at the body pixel still: the face and the hair are finer than the tunic.
- The hood (winter) is a box, as before.

### His calls

1. **The whole figure a voxel fine** (clothes, a belt's buckle, hems, fingers on a hand): the other
   reading of "make the detail finer". Default: not now.

### Its gate

On 9718f8a: started, and stopped when his next message came (it is gated with what follows).

## His next message (2026-11-24, morning), on the list's pictures

> We are getting somewhere, The nose isn't attached to the face, they look a bit crosseyed now, lower the
> nose a square, lower the eyes a square and spread them apart by two squares? Lower the forhead by two
> squares, and see if you can make the hood of the cloak a bit more shapely instead of the blockyness

| His words | Read as | Done |
|---|---|---|
| "We are getting somewhere" | praise: not the word to merge | not merged |
| "The nose isn't attached to the face" | where the jaw's narrowing draws the face back, the button stood a voxel off it (the face's front voxels a voxel behind the nose's) | the nose set into the face, a voxel proud of it |
| "they look a bit crosseyed now" | the irises on the eyes' inner sides, four voxels apart | answered by spreading them (below) |
| "lower the nose a square" | the nose a voxel lower | below |
| "lower the eyes a square and spread them apart by two squares" | the eyes a voxel lower, each a voxel further out: two voxels more between them | below |
| "Lower the forhead by two squares" | the hair two voxels lower over the forehead: down to the brows, which go down with the eyes | below |
| "see if you can make the hood of the cloak a bit more shapely instead of the blockyness" | the winter hood rounder and narrowing over the crown, as the oval head | rounder; not narrowed (below) |

### What changed (d69cdd7, e6daf13)

- **The face (d69cdd7)**, in voxels on a head of nine pixels, from the top: the hair (a kerchief, a bald
  brow) over the forehead two voxels lower than it was, down to the brows; the brows a voxel tall; the eyes
  two voxels tall, a voxel lower, each a voxel further out (the white on the outer side, the iris on the
  inner: six voxels between the irises, it was four); the nose a voxel lower, a pixel wide and a voxel
  proud, set into the face (`Nose_Z`); the nostrils beside its foot; a row of cheek; the mouth as it was;
  the chin. The face stays in thirds: the nose's foot 2.5 pixels over the chin's bottom, the hair's edge
  2.5 over the nose's foot (`serf_check` holds both). The ears' foot is the nose's, a voxel lower with it.
- **The hood (e6daf13)**: its edges rounded two pixels (`Hood_Round`; it was one). Tried narrowing it over
  the crown as the oval hair: its front then fell behind the head's and the head showed through it from
  the brows up, a voxel map of the face showed; so it is not narrowed. No cap of hair is built under a
  hood now (d69cdd7): nothing stands out of it.

### What was run

- `serf_check`, release and debug: all pass (the thirds at 2.5 pixels; caps narrowing on the 2,700 heads
  that have one out of winter, none in a hood).
- `--no-reference-body`: the hash over the skin's first 64 rows still 98950de's, no texel past row 63.
- Drawn flat from their voxels: ten heads, two in hoods; a map of the front-most voxels of a hooded head
  (the hood over all of it but the opening, from the chin to the brows' top).
- In the game: three serfs close, four in winter hoods, before and now.
- The debug game: twenty standing in summer, twenty chopping in winter: nothing raised.

### Its gate

On e6daf13: started, and stopped when his next message came.

## His next message (2026-11-24, morning), on the face's pictures

> the wrist exposes the bone, bring the sholders in another square, what I meant was lower the top of the
> head a couple of blocks, make the head shorter

**A retraction, first**: "Lower the forhead by two squares" was read as the hair brought two voxels lower
over the forehead (d69cdd7). He meant the top of the head lower: the head shorter. The hair over the
forehead goes back where it was; the head is made shorter instead.

| His words | Read as | Done |
|---|---|---|
| "the wrist exposes the bone" | the forearm narrows to a wrist so thin, between the sleeve and the hand, that it reads as a bone | below |
| "bring the sholders in another square" | the upper arm another voxel into the chest's side | below |
| "what I meant was lower the top of the head a couple of blocks, make the head shorter" | the crown two voxels (a pixel) lower, the face where it is; the hair over the forehead back where it was | below |

### What changed (a6887db, 4383be6)

- **The head a pixel shorter (a6887db)**: its crown cut a pixel (`Ref_Crown_Cut`), its face where it was
  over the chin: every head 7 or 8 pixels tall (it was 8 or 9; adults' 22.2 to 26.7 % of their height).
  The hair over the forehead back at the top of what was the brows' row, so with the brows a voxel lower
  (with the eyes) there are two voxels of forehead between them. **The body under the head as it was**,
  built to the genome's height, so the serf stands a pixel (5 cm) shorter than its genome says: his
  "the models can be a diffrent scale than the rest of the world". The other way, the body taking the
  pixel as it took the last cut, would put the hips at up to 45.9 % of the height.
- **The shoulders (4383be6)**: the upper arm's inner side a pixel (two voxels) into the chest's side
  (`Ref_Shoulder_In`; half a pixel before).
- **The wrist (4383be6)**: the forearm narrowing by 0.3 (`Ref_Fore_Taper`; 0.5 before, when its end came
  to a single voxel between the sleeve and the hand, the "bone") and reaching half a pixel down into the
  hand: three voxels across at the wrist, under the hand's four.

### What was run

- `serf_check`, release: all pass. Its lines of the reference body now: every head 7 or 8 pixels, the
  nose's foot 2.5 pixels over the chin and the hair's edge 3.5 over it; the serfs as tall as their
  genomes less the crown's cut, within half a pixel; the hips' share of the height the body is built to
  (40.6 to 44.4 %); the hands at work as before (chop and aim 3.0, eat 1.3; picking 5 of 60, 1.8 deep).
- `--no-reference-body`: the hash over the skin's first 64 rows still 98950de's, no texel past row 63.
- A forearm drawn voxel by voxel: three, five, five, five, five, five, then three to its end (it ended in
  one).
- In the game: three serfs close and four, before and now, four in winter; ten heads drawn flat.
- The debug game: twenty standing in summer, twenty chopping in winter: nothing raised.

### Its gate

On 4383be6 from a clean copy: **passed**, in 60 minutes (the game as it is played, `main`'s state
d5bb6e2fdd00202f, and every other part). Its log was first read while it was still at the herds' places,
after a notice of its end came early, and written here as cut short; it was not. **That build is in
`bin/`** since 2026-11-24, 08:30 (its serfs a pixel shorter than their genomes: 599db81 gives the pixel
back, gated below).

## His next message (2026-11-24, morning), on the shorter heads

> Let's extend the torso and legs proportionally to regain the 5cm, let's shape the chin a little bit
> more, by another step, and the top of the head let's round it a bit more, we are very close

| His words | Read as | Done |
|---|---|---|
| "Let's extend the torso and legs proportionally to regain the 5cm" | the body under the head takes the crown's cut, legs and trunk in the shares they have (the legs 57.5 % of the height under the head): every serf as tall as its genome again | below |
| "let's shape the chin a little bit more, by another step" | the chin's edges rounded a voxel more | below |
| "and the top of the head let's round it a bit more" | the crown rounder: the hair over it narrowing more, and the bald head's own crown rounded as the chin | below |
| "we are very close" | praise: not the word to merge | not merged |

### What changed (599db81, 7b472fb, 22551f9)

- **As tall as the genome again (599db81)**: the body under the head is built to the height less the
  head as it is, the legs 57.5 % of it and the trunk the rest, so both are a little longer in their
  shares. The hips' joints at 41.9 to 45.9 % of the height (the skeleton's 40 %).
- **The chin and the crown (7b472fb)**: a box can now have its top and bottom edges rounded more than
  its upright ones (`Box.Round_Ends`; voxel parts only, the box path draws the one radius). The head's
  upright edges stay rounded 1.5 pixels: rounded 2 all round, the eyes' outer columns (the whites, since
  the eyes went a voxel further out) fell back onto the head's side faces. Its chin's and crown's edges
  are rounded 2 (`Ref_Head_Ends`): the chin a voxel narrower at its foot each side, and a bald crown
  rounder.
- **The hair over the crown (22551f9)**: narrowing by 0.35 to its top (`Crown_Taper`; 0.25 before), the
  head's own crown inside it.

### What was run

- `serf_check`, release and debug: all pass (as tall as their genomes; the hips as above; the parity of
  voxels and boxes with the new shape test; heads 7 or 8 pixels, 21.6 to 25.8 % of the height). A look:
  1,762 triangles drawn (the most 2,044), as boxes 2,456 (the most 2,808); merged by colour as the brief
  has it 7,429. A look's colours merged for room in 364 of 7,200 looks (857 before; why fewer, not
  looked into).
- `--no-reference-body`: the hash of 72,000 rigs and skins over the skin's first 64 rows is 98950de's
  (11416224824292578703 and 1893737104172277074), no texel past row 63 is set and no box has its ends
  rounded: the body as it was, to the bit.
- The game in debug: twenty serfs in a row in summer (200 frames), and twenty chopping in winter (300):
  nothing raised.
- Ten heads drawn flat from their voxels (the eyes' whites on every face looked at); in the game, three
  serfs close and four, against the last pictures.
- The hands at work (printed, not failed), of 60 serfs at each: chopping 60 (3.0 pixels deep), aiming
  60 (2.9), eating and sitting to eat 60 (1.4), picking 3 (1.5), putting down 3 (0.5), stirring 3 (0.8);
  the body as it was: chopping 60 (2.4), aiming 60 (3.0), eating 60 (1.1), picking 5 (1.0).

### Its gate

On 22551f9 from a clean copy: **passed**, in 58 minutes. Both builds with no new warning; the nine
checks in debug (`serf_check`: 34 ok, none failed); the reference check; the game as it is played, 41 days,
line for line and to its state (d5bb6e2fdd00202f), saved on its twentieth day and run on to the same; the
three site scripts in release and in debug; the herds' places; the stress runner; the flora's hash. **That
build is in `bin/`** since 2026-11-24, 09:24. The commits after it are documents only.

## His word to merge (2026-11-24, morning)

> great I like it, when the shell is done, merge and get ready for a clear, next we are going to polish
> up the animations

| His words | Read as | Done |
|---|---|---|
| "great I like it" | the look as it stands at 22551f9 | nothing changed |
| "when the shell is done, merge" | **the word to merge**, once the gate then running in the background (on 22551f9) has passed: `main` fast-forwarded to the branch, no merge on a failure | the gate passed at 09:24; `main` fast-forwarded from 091b720 to 027491d; its build in `bin/` |
| "get ready for a clear" | the handoff, the state page, the stage log and the memory written so that a session that starts from nothing finds where things are; the working copy left on `main` | the state page rewritten; this file's head; a row in the stage log; an entry in `docs/conventions/rendering.md`; the branch's name taken out of the system documents; a zip of `main`; the working copy on `main` |
| "next we are going to polish up the animations" | his next piece, his to open: nothing of it built; what is known that bears on it (the hands at work, his two calls on the poses) goes on the state page | nothing built; the state page, "What is next" |

## Not done, and next

- **The animations, his next piece** ("next we are going to polish up the animations"): his to open;
  what bears on it is on the state page.
- The serfs watched in motion for shimmer (counted only, above, before the faces were made finer); the
  deer across the shoulders looked at.
- Steps 2 to 5 of the brief.

A session starts at `docs/production/State.md`.
