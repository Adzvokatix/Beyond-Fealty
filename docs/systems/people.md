# People

- Packages: Castle.Bodies, Poses, Second_Order, Figures, Serfs, Props, Fire (the fire: `rendering.md`, "The fire")
- Check: serf_check (about 8 s), dynamics_check (18 checks)
- Saves: nothing of their own: the colony saves who they are
- Stage: phase A; work poses added by stages 1 to 4; rounded boxes, the tools carried and the quiver,
  2026-11-11 (Handoff_2026_11_11_models_pass.md)

## People

Serfs are made the way the world is: boxes with 5 x 5 texels to 0.25 m, so
a body pixel is 5 cm, the world's texel. Box sizes snap to that pixel, not
to the block, so a serf can be tall or short, lean or stocky, a child or an
elder, and still look made of the same stuff as the ground. An adult is
about 35 pixels tall with a 6-pixel head: mildly stylised, so faces and
hats read from above.

* **Genome and look** (`Castle.Bodies`). A seeded genome (sex, age, height,
  build, skin, hair and eye colour, hair style, beard, handedness, scar,
  freckles, a coif) and an outfit (job, winter or not) are all a look
  needs. `Build` turns them into a skeleton of 15 bones, up to 28 boxes on
  them and a 128 x 128 painted skin (each box's faces unfolded as a net and
  the nets shelf-packed; 128 x 64 until 2026-11-24, and every net of the
  body as it was still lies in its top half), the same every time, so a save will need only the
  genome. The left limbs are built and painted and the right ones are their
  mirror images; then the symmetry is broken on purpose: the tool goes in
  the dominant hand (one in ten is left-handed), one sleeve may be pushed
  up, a scar sits on one cheek, a sword hangs on the off side. Jobs so far:
  forester (greens, an axe), hunter (leather jerkin, bow), gatherer (apron,
  basket on the back), porter (sack on the back), lord (rich dyes, gold
  trim, sword) and idle. Winter adds a cloak and a hood with the face cut
  out. **The cloak is its owner's the year round** (John, 2026-11-12:
  "can we add cloaks, they can set down next to their bed during the
  summer, wear it during with their winter clothes in the winter, and use
  it as a blanket when they sleep?"): its wool is the look's (`Rig.Cloak`),
  a third field of the outfit takes it off the back while its owner sleeps
  under it in winter (`Cloak_Off`), and off the body it is two props to a
  wool (`Castle.Props.Cloak_Folded`, `Cloak_Spread`), put where it belongs
  by the game (`habitation.md`, "Cloaks"). **Since 2026-11-13 the cloak is
  cloth** ("Cloth", below), and the rig's cloak and the two props are what
  `--no-cloth` draws. Children carry no tools. (The axe and the bow are no longer boxes
  of the body: see "Tools", below.)
* **Rounded boxes** (John, 2026-11-11: "a slight drift away from the voxel
  block design, something that removes the minecraft feel from the models,
  but not too much a hybrid, a tiny bit of smoothing, slightly higher
  triangle count for our models going forward, nothing too expensive").
  A model is still boxes on the 5 cm pixel with a painted skin, and the
  renderer draws every box of every look, people, deer and props alike,
  with its edges and corners rounded off: each face is three by three
  cells, the ones along its rim as wide as the rounding, their outer
  vertices drawn in onto the rounded edge, the normal turning with them
  (108 triangles a box, where it was 12). The radius is 0.28 of the box's
  thinnest side and no more than 1.2 pixels (6 cm), unless the box names
  its own (`Castle.Bodies.Box.Round`; 0 is sharp); a box can also narrow
  toward one end (`Taper`). A serf's limbs narrow to the wrist and the
  ankle, its chest and hips draw in to the waist, its head narrows to the
  jaw and is rounded by a pixel and a half, a dress widens to its hem
  (`Limb_Taper`, `Waist_Taper`, `Jaw_Taper`, `Skirt_Flare`, `Head_Round`
  at the top of `castle-bodies.ads`, first values). A new model is made
  the same way: boxes, with `Round` and `Taper` where the rule does not
  suit. The shadow pass draws the same shape.
* **More form** (`Castle.Bodies.More_Form`; John, 2026-11-22: "I had
  someone play the game and they suggest that the serfs need a little bit
  higher detail, a bit more "form""). First values of mine, his to judge:
  `--no-form` is the serfs as they were, to the box. Still boxes on the
  5 cm pixel with a painted skin; a serf has besides
  - **a neck**: a pixel of the trunk's height (`Neck_Px`), out of the
    chest. The head is where it was and a serf as tall as its genome
    says; the shoulders, and all that hangs from them (the arms, a pack,
    a cloak, a bow across the back), are a pixel lower; the hips and the
    legs as they were;
  - **a nose**, a pixel proud of the face between the eyes' row and the
    mouth's;
  - **its hair as a cap** over the crown, the back and the sides of its
    head as far forward as the temples and as far down as the hair is
    painted at the sides, a quarter of a pixel proud of the head (a
    kerchief likewise, in linen; a bald head has none);
  - **limbs rounded further**, all but round (`Form_Limb_Round`), and
    narrowing more to the wrist and the ankle (`Form_Limb_Taper`); the
    trunk a little more to the waist, the head to the jaw.
* **The reference body** (`Castle.Bodies.Reference_Body`; John,
  2026-11-23, of the voxel characters he bought: "the skeleton model is the
  refrence bone structure, there are some examples when they are "fleshed"
  out, a small button nose is fine, but the nose you have is too long").
  First values of mine, read from the bought skeleton's own files (a head
  20 voxels of 61, the thighs' joints at 40 %, the hands, hanging, ending
  at 28 %, the upper arm and the forearm as 11 to 8). Still boxes on the
  5 cm pixel with a painted skin (the joints too): **the head a bit
  smaller than the skeleton's third** (John, 2026-11-24, with a chart of
  a face's proportions: "I mean it's close, just cut the head down a bit,
  make it a bit smaller"; it was 10 pixels at 1.525 m and 7 deep): 8.5
  pixels at 1.525 m, as the square root of the height else, never under
  8, so 9 for nearly every adult (24 % of a tall man, 29 % of a short
  woman) and 8 for children and the shortest; 6 wide (the skeleton's 12
  voxels) and 6 deep; **the face in thirds as on his chart** (three rows
  from the brows to the nose's foot, three from there to the chin), **the
  eyes on its middle row** (on a head of 8, the row over it), the
  brows above them and the hair over the rows above those, the nose under
  the eyes, a row of cheek, the mouth, the chin to the head's last row; **no
  neck**, the head on the chest; the hips' joint at 57.5 % of the height
  under the head; the chest a pixel deeper; the arms as long as leaves the
  hands' ends, hanging, at 28 % of the height (the middle of the thigh);
  **a button nose**, a pixel square and half a pixel proud; the hair a voxel
  proud of the head over the crown and the forehead to the brows, and
  down the back and the sides as far as the style is painted there; a
  hood sized to the head. **The head's shape** (`Head_Shape`; John,
  2026-11-24, with eight voxel characters: "I have provided some
  refrences for the head shape", then "can we make the heads more oval
  shapped? so the hair doesn't look like blocks or afros?"): the hair a
  mass, a voxel proud at the temples and two over the crown and at the
  back, narrowing over the crown (`Crown_Taper`) and down the sides
  (`Side_Taper`) in one piece with it, to over the ears or, long, to the
  mouth's row (cropped hair and kerchiefs close to the head, narrowing over
  the crown too); ears, a voxel proud, where the sides are bare; a full
  beard round the jaw, narrowing to its foot; so that the head is an oval,
  widest about the brows. `--no-head-shape`: the hair, the ears and the
  beard as before them (to the bit on 85511a1; what came after stays). **His
  list of 2026-11-24** ("clip the arms at the sholders into the main body
  ..., make the arms a bit thinner, ... make the chin a bit more rounded,
  make the detail finer, elbows angled away from the body at a resting
  state, slight bend at the arms, add thumbs, and improve the detail of the
  hair a bit"): the upper arm's inner side half a pixel (a voxel) into the
  chest's (`Ref_Shoulder_In`; a pixel since, below); a grown serf's arm 2.5 pixels across
  (`Ref_Arm_W`: five voxels, set a quarter of a pixel toward the chest; it
  was six; a child's as it was); the head's edges rounded a pixel and a
  half (`Ref_Head_Round`, the chin's corners with them); a thumb on each
  hand, a voxel square and two tall, a voxel proud at the front on the
  side toward the body; **the head and the hair painted a voxel fine**
  (their nets two texels a body pixel: the brows a voxel tall, an eye a
  white and an iris, the nostrils, the mouth a line, freckles and a scar a
  voxel; the hair in strands of five shades along its fall; a fine net's
  grain in five shades), on the skin and not on the voxels as the brief
  has it; standing at rest, the elbows out (`Castle.Serfs.Rest_Arms`,
  `--no-rest-arms`). And of his next word ("The nose isn't attached to the
  face, they look a bit crosseyed now, lower the nose a square, lower the
  eyes a square and spread them apart by two squares? Lower the forhead by
  two squares, ... the hood of the cloak a bit more shapely"): the nose set
  into the face, a voxel proud and a voxel lower (`Nose_Z`); the brows and
  the eyes a voxel lower, the eyes each a voxel further out; the winter
  hood's edges rounded two pixels (`Hood_Round`), and no cap of hair under
  it. And then ("the wrist exposes the bone, bring the sholders in another
  square, what I meant was lower the top of the head a couple of blocks,
  make the head shorter"): the head's crown cut a pixel (`Ref_Crown_Cut`:
  every head 7 or 8 pixels, the face where it was; the hair over the
  forehead where it was, `Hair_Z`, two voxels of forehead over the brows),
  the body under it as it was (the serf a pixel shorter than its genome
  says, until his next word); the upper arm a pixel into the chest's side
  (`Ref_Shoulder_In`); the forearm narrowing by 0.3 (`Ref_Fore_Taper`) and
  reaching half a pixel into the hand. And then ("Let's extend the torso
  and legs proportionally to regain the 5cm, let's shape the chin a little
  bit more, by another step, and the top of the head let's round it a bit
  more"): the legs and the trunk built to the height less the head as it
  is, each in its share, so that the serf is its genome's height again
  (the hips' joints at 41.9 to 45.9 % of it); the head's chin's and
  crown's edges rounded two pixels (`Ref_Head_Ends`, `Box.Round_Ends`:
  voxel parts only), its upright edges a pixel and a half as before, which
  keeps the eyes' whites on the face; the hair over the crown narrowing by
  0.35 to its top (`Crown_Taper`; it was 0.25). **The rest as more form has it**: limbs three
  pixels thick (a child's two; on the reference body a grown serf's 2.5
  since his list), rounded and narrowing to the wrist and the
  ankle, the hands and the feet as they were; the waist drawn in by 0.22
  and the forearm narrowing by half to a wrist narrower than the hand, so
  that both show in voxels of half a pixel. (A first try that evening had
  straight limbs two pixels thick, a straight waist and the face in the
  head's lowest six rows; his word on its stills: "why are their forheads
  so big? where are the hands? the slim waists? the shaped arms and
  legs?".) `--no-reference-body` is the serfs as they were
  before it, to the bit (`More_Form` and `--no-form` as they were: hashed
  over 72,000 rigs and skins against the commit before). The poses were
  made for the old head and are as they were: at work, the hands and
  forearms of every serf go into its head when it aims, chops and eats, as
  they did before, chopping 0.6 of a pixel deeper and eating 0.3 (counted
  on 22551f9; `serf_check`, "hands at work", prints it: a call put to John).

  Two or three boxes more a serf, 25 at the most of the 28 a look may
  have (26 at the most as built now: `serf_check` on 22551f9). Tried and left out, as they looked: a shoulder round the top of
  each arm (puffed sleeves), a belt proud of the tunic (a square platter
  round the waist of anyone bending), the hair as a cap over the whole
  crown (a flat hat), the head stood a pixel higher on its neck (a serf
  5 cm taller than its genome says: `serf_check` holds that). Seen from
  22 m it changes little; it is for a close look. `serf_check` builds
  6,000 serfs both ways: as tall, the legs and the arms as long, the
  head where it was, the shoulders a pixel lower.
* **Tools** (John, 2026-11-11: "The shortbow for the hunter is a bit of an
  issue, right now it's just a stick jutting directly out from the hand,
  same with the axe, and is there a way to place the bow on the back, and
  the axe on the hip when they aren't swinging it", and "can we curve the
  bow too"). The axe and the bow are things of their own
  (`Castle.Props.Axe`, `Put_Bow`), which `Castle.Serfs` places each frame
  from the body's solved frames (`Show_Tool`), as the shoulder log and the
  carried deer are placed:
  - The axe: a haft 55 cm long, a poll and a flared bit with a bright
    edge. It hangs head up behind the hip of the dominant side, its bit
    flat to the body and turned inward. Chopping, its haft runs from the
    dominant hand through the other and its bit leads the stroke; it is
    back on the hip 0.8 s after the last stroke (`Axe_Hold_S`).
  - The bow: a grip and four pieces to each limb, each on a bone of its
    own and turned a little further toward the string than the one
    before, so the stave is a curve a little over a metre long; and a
    string in two halves from the tips. It lies flat across the back,
    its upper limb over the off shoulder. Stalking (`Sneak`), it is in
    the off hand, carried level at the side; aiming, it is stood upright,
    the string drawn back to the other hand with an arrow on it, and the
    limbs bend further the further the string is drawn (`Bow_Flex`, a
    full draw at 30 cm). It goes back across the back 2.5 s after the
    stalk or the shot (`Bow_Hold_S`). With a deer across the hunter's
    shoulders it is let down level across the small of the back, under
    the load.
  - The quiver (John, 2026-11-11: "A quiver would be nice"): a leather
    tube 40 cm long with a darker band round its mouth and the fletched
    ends of four arrows standing out of it (`Castle.Props.Quiver`). It
    hangs on the hunter's belt behind the hip of the drawing hand, leaning
    out to that side (`Quiver_Tilt`), where the forester's axe hangs; it
    is on the hip bone and never leaves it, so it lies under a deer
    carried across the shoulders and beside the bow let down. When he
    sits to eat it is swung up along his belt (`Quiver_Sat`), clear of the
    seat. The arrows in it are not counted: four show, whatever was shot.
  - Between where it is stowed and the hand a tool goes through a filter
    (`Tool_W`), not at once, and that is all the animation there is
    (John, 2026-11-11: "full animations are not important, we want a happy
    balance between realism and immersion, so just enough realism to be
    immersive without being expensive and time consuming"): no hand goes
    to the hip, the back or the quiver. Over a winter cloak a stowed tool
    sits 1.2 pixels further out. Children carry none.
* **Poses** (`Castle.Poses`). A pose is a handful of numbers: where the
  pelvis is, heading, lean, where the head looks, how the arms swing, where
  the hands and feet should be. `Solve` turns it into a frame per bone,
  reaching the hands and feet with two-bone IK (knees bend forward, elbows
  back). A hand can be turned at the wrist (`Grip`): what it holds swings
  from along the forearm to upright across it, so a bow drawn stands
  upright in the hand held out instead of pointing at the deer. **An arm
  that reaches bends its elbow back unless told otherwise** (`Elbows`: 1
  is down by the ribs and out), and back is wrong for a hand held near
  the chest's middle: the elbow goes behind the back and the forearm
  through the body. **Eating, standing or seated, the hands are placed
  before the chest** in the chest's own frame (`Chest_Frame`: the food a
  hand's breadth off its front in the off hand, the other hand going
  between it and the mouth) with the elbows down, wherever the trunk
  leans and bends (John, 2026-11-22, with two pictures of serfs on a
  seat: "serfs arms and hands are behind there back when they sit down
  to eat". The hands had been put 20 cm before the hips whatever the
  trunk did; measured on a seated eater in the chest's frame, that was
  9 cm before the chest's middle where its front is at 10, 3 cm from its
  middle line, and the elbow came out 13 cm behind the middle, behind
  the back. Standing eaters had it too). `--no-chest-hands`
  (`Castle.Serfs.Hands_Before_Chest`) is the pose as it was.
* **Movement is presentation** (`Castle.Serfs`, `Castle.Second_Order`).
  Where a serf is meant to be comes from outside (for now a lineup or a
  scripted route; later the colony); the body follows it through
  second-order filters (frequency, damping and initial response, as in
  t3ssel8r's procedural animation video), each solved exactly over the
  frame, so a filter moves the same at 20 fps as at 144 and can't blow up
  on a long frame. A stepper puts the feet down on the tops of real blocks,
  as .kkrieger's walk operator did, adapted to two legs: a foot stays
  planted until its turn, then swings on an arc to where it will be needed
  when it lands, lifted higher for a step up. The pelvis rides on the feet
  with a bob and a sway over the standing foot, the body leans into
  slopes, the arms swing against the legs and trail them a little, and the
  head looks into turns and glances about while standing. Each serf's
  filters take their character from the genome: children quick and
  bouncy, elders slow and heavily damped.
* **Lying down, and asleep** (`Lay_Down`, `Posed`). `Lie` tips the whole
  body back about a line behind its heels until it is on its back, its feet
  toward what it was driven to face: the dead lie so. `Sleep` (John,
  2026-11-12: "have serfs sleep on their side") tips it the same way and
  rolls it onto one side as it goes down (which side is its own, from its
  seed; told to face something as it sleeps, `Lie_Facing`, the side that
  turns its belly that way: the game says so for one asleep across the
  way to the camp's fire, so that its face is to the fire), the lower
  shoulder and hip on the ground, the legs drawn up (the
  upper one further), the upper arm across the chest, the back and the neck
  a little bent. `Lying_Frame` says where a sleeper's hips are, which way
  it lies and which way its belly faces, for the cloak spread over it.
  `--lineup N --lineup-does Sleep` shows it in daylight.
* **Drawing** (`Castle.Figures`, `Castle.Render`). Each look's skin is one
  layer of a texture array (256 resident at once). Each frame the game
  hands over every figure's bone frames, and every box of every figure is
  drawn in one call, its corners pulled from the box list in the vertex
  shader, lit, shadowed and fogged like the world. Whatever is drawn this
  way casts a shadow from the sun and from the fire with nothing more to do
  (`docs/systems/rendering.md`, "Shadows"): people, deer, props, what they
  carry. The soft disc on the ground under each is drawn only where no sun
  casts the figure's own shadow, at night and under heavy cloud.

Test options on the game: `--lineup N` (N serfs in a row at the start
focus, facing the camera, every job and age in turn), `--lineup-turn RAD`
(the row turned that far from facing the camera: 3.14 shows their backs),
`--lineup-does MOTION` (the row at work where it stands, at something
three metres in front of each: `stand`, `walk`, `pick`, `put_down`,
`chop`, `sneak`, `aim`, `eat`, `lie`, `stir`, `sit_eat`; a model's poses
and what it carries can be looked at with no colony; record it, since a
`--frames` run with `--novsync` passes almost no animated time),
`--walk X0 Y0 X1 Y1`
(a serf walking between two points, in metres, and back, pausing at each
end, by planned routes (see Routes); up to eight), `--follow` (the camera follows the first serf),
`--winter` (winter dress whatever the season), `--no-form` (the serfs as
they were before 2026-11-22: no neck, nose or cap of hair), `--no-reference-body`
(the serfs as they were before the bought skeleton's proportions, 2026-11-23),
`--no-voxel` (the serfs drawn as boxes, not as voxel parts), `--no-chest-hands`
(the eaters' arms as they were) and `--record DIR N` (save
N frames as `DIR/frame_0001.png` on, the animation stepping a thirtieth of
a second each, then exit; the first frame is the first with the people
asked for on loaded ground, or, with no people and no colony asked for,
the first after the view has filled, so the land or the water can be
recorded by itself). A lineup, and a walk up the hill by the default
view made into a video:

```sh
./bin/castle_game --at 1176 1080 --cam 2.9 0.28 7 --lineup 7
xvfb-run -a -s "-screen 0 1280x720x24" ./bin/castle_game --size 1280 720 --view 60 --novsync \
         --walk 1178 1080 1196 1094 --follow --cam 2.4 0.35 9 --hud none --record frames 300
ffmpeg -framerate 30 -i frames/frame_%04d.png -pix_fmt yuv420p walk.mp4
```

`./bin/debug/dynamics_check` tests the filters (overshoot against theory,
the response settings, square waves at frame times from 4 ms to 0.5 s, the
same curve at 20 to 144 fps) and shows the writeup's own discretisation
on the same tests for comparison. `./bin/debug/serf_check` builds 36,000
serfs (every net inside the skin, mirrored limbs, handedness, heights),
holds the reference body to the skeleton's measures, stands 500 of them up,
tests the IK on 1,000 targets, walks one over flat ground (pace, reach,
bob, no sliding feet, one foot always down, arms against legs, the same
stride at 30 and 120 fps), counts the hands at work that go into the head,
and checks the voxel parts (below); `--png FILE` writes a sheet of skins to
look at.

**Voxel parts** (2026-11-23, merged 2026-11-24; his brief `docs/design/Voxel_people_brief.md`,
step 1; `docs/handoffs/Handoff_2026_11_23_voxel_people_counted.md` and
`Handoff_2026_11_23_voxel_people_drawn.md`). `Castle.Bodies.Voxels.Build` fills each box of a rig
with voxels of 2.5 cm (`Castle.Voxel_Mesh.Vx`: the voxels whose centre lies inside the box as the
figure shader rounds and narrows it; a box's top and bottom edges rounded more than its upright ones,
`Round_Ends`, the reference head's chin and crown since 2026-11-24, are the voxel parts' alone: the
figure shader rounds every edge by `Round`), one grid a bone, coloured from the skin's texel at the nearest
point of the nearest face, a palette a look. **Since the evening of 2026-11-23 a serf is drawn so**
(`Castle.Bodies.Voxels.Voxel_People`; `--no-voxel`: as boxes, as it was): when its look is made, its
look as voxel parts is made beside it (3.4 ms; the game makes at most one again a frame, so the band
dressing for winter is spread over as many frames), and drawn in place of its boxes in the view, the
sun's figure maps and the fire's six faces (`rendering.md`, "Figures"). **How a face is coloured
departs from the brief**: a part's open faces are merged into rectangles whatever their colour
(`Mesh`, `By_Colour => False`), and a face's colour is read where it is drawn, voxel by voxel; merged
by colour as the brief has it a look would be 7,429 triangles on the reference body (its limit
2,600), and is 1,762 so (the most 2,044, in room for 4,096 quads; as boxes 2,456; on the heads of
2026-11-23 and of 85132c5, 1,557 and 1,582; counted on 22551f9). `serf_check`, "voxel parts", holds the parity (a voxel is
solid where its centre lies inside a box of its bone and nowhere else), the mirror and the sameness
of two builds over 7,200 looks; that the drawn quads lie on open faces and cover them all, and that
each part's bytes are its grid; the room a look needs; and prints the counts and what a look costs
to make. `./bin/debug/serf_check --voxels FILE [N [JOB [winter]]]` writes one serf's voxels for a
picture.

## Cloth

John, 2026-11-13: "can we have the cloaks be dynamic cloth, that they wear
at the start, then take off when they make their bed, and then draped over
them when they sleep, if we can do it, it would be a very cool touch and
would translate well when we get to other wearable items later in
production." An experiment, built with first values of mine; drawing only:
nothing of it is saved, the colony knows nothing of it, and `--no-cloth`
is the cloaks as they were, exactly.

- **`Castle.Cloth`** is a sheet of six particles across and seven down
  (thirty panels), knowing nothing of cloaks: held to its rest lengths
  (across, down, each to the next but one, and corner to corner), falling
  under its weight, kept out of the capsules of whatever body it hangs on
  or lies over and off the ground; its top row pinned to points given each
  frame, or let go. Where it touches it holds (no sliding); and stepped to
  stick (`Stick`, a sleeper's cloak), a point that has come to rest on the
  body or the ground stays there until the sheet is laid, hung or let go
  again, so that it drapes from where it first rests and does not slide
  off a narrow back. Let go, it is
  frozen once still, or five seconds of drawn time on at the latest: a
  frozen sheet is not stepped at all, so it and its shadow are dead still.
  It is stepped by drawn time after `Castle.Serfs.Submit`, so a recording
  repeats. Six passes over its lengths a step, two steps a frame, the body
  and the ground every other pass: about 0.045 ms a worn cloak a frame (48
  worn, 2.2 ms with the pack's capsule, 2.1 before it; a sleeper's, nothing
  once it lies still).
- **Drawn as boxes** (`Castle.Props.Put_Cloth`): each panel a thin box
  2 px square on a bone of its own (the bow's way: thirty panels are two
  figures of fifteen bones), framed onto its four points, a tenth wider
  than them so that none parts, sharp-edged (`Round` 0) so that they meet;
  one look pair to a wool. Lit and shadowed as any figure, with nothing
  more to do. Six cloaks cost 0.02 to 0.07 ms of GPU at the camp's fixed
  view (2.00 and 2.05 ms with them, 1.98 and 1.98 without).
- **The cloak** (the game's `Show_Cloths`): its top row held across the
  shoulders (the upper arms' joints), behind the neck; the body it is kept
  out of is ten capsules on the solved bones (the trunk, the hips, the
  head, thighs, shins, upper arms, and what is carried on the back all
  day: a gatherer's basket, a porter's sack). **Over a pack the cloak is
  thrown round the pack's far edge** (its top row arched out behind the
  pack by the chest's own back and up, so that it leans with its bearer)
  and hangs round and behind it: pinned across the shoulders alone it
  hung between the back and the basket, and the basket came through it.
  Arch and capsule go by the pack's kind and the season (`Pack_Mid`,
  `Pack_Far`: a basket is a pixel deeper than a sack, and both sit a pixel
  further off over winter clothes, as `Castle.Bodies` places them). From
  above the pack's top shows at the collar; in winter a sliver of a
  basket's edge still shows in some poses. **Worn from the start until its owner
  has made the bed it sleeps on; then taken off where it is**: let go, it
  falls, and lies there. **Over its owner asleep**: once it is all the way
  down (`Lies` past 0.97: laid over a body still lying down it falls
  beside it) and its body has held still ten frames (over one still easing
  into its place it was lain on), the sheet is laid flat a little above it
  from the head end down and settles over it, sticking where it rests; if
  the body moves more than 0.2 m from under it, it is laid again. (Looked
  at in a hovel through its cleared roof, 2026-11-13, a sleeper's cloak
  slid off its side onto the bed and the sleeper was seen lying on it:
  that is what the sticking and the wait mend.) Awake again it is left lying on the bed. In
  winter it is worn whenever its owner is awake, as before. It is put on
  again (hung straight from the shoulders) after a jump of the shoulders
  (a load, a fast clock), and a cloak more than 40 m from the eye hangs
  straight and is not stepped. The outfit's own cloak is never drawn while
  cloth is on (`Cloak_Off`).
- **Over a sleeper the cloak is kept off all the sleeper is dressed in**
  (the game's `Dressed`, `Cloak_Fit`; John, 2026-11-22: "the cloak
  clipping through their clothing when they sleep needs a bit of a fix ...
  just add their clothes to the "clip box", so the cloak wraps around it
  when they sleep"). The ten capsules above are a body's middle lines
  with radii of their own: none lies along the ribs at all (the first
  runs from the hips to the waist), and a sleeve, a skirt or the shoulder
  that is uppermost is wider than the one it hangs on, so a chest and an
  arm stood through the cloak of everyone asleep. Laid over a sleeper,
  the cloth is now kept out of every box of the sleeper's own rig as its
  bones lie: a capsule along the box's longest side, as thick as the box
  from corner to corner across it, two or three side by side for a box
  much wider than it is deep (the chest, the hips, a skirt); what is
  thinner than a pixel and a half is left out (a braid, a scabbard). So
  whatever a look is dressed in is in it, and a box added to a look is in
  it with nothing more to do. The sheet is laid 15 cm higher for it. **A
  worn cloak is kept off the ten capsules as before**: it hangs as it
  did, and costs what it did. A sleeper's costs only while it settles (it
  is frozen once still). `--no-cloak-fit`: as it was. Looked at on the
  thirteen asleep on the square of the played game, its second night,
  frame by frame as the cloaks settle, beside the build before.

Where it clips (John, 2026-11-13, of the cloaks: "it works great, it would
be nice if the clipping was less, but it's workable"; looked for close up
on the band setting off and at its work, and asleep): a basket or a sack
on the back came through a worn cloak (mended, above); a hunter's bow and
quiver lie over and through its cloak; a sheaf or a log on the shoulder
cuts its collar; where the cloth bends sharply its thirty panels part into
shards; and the sleeper's (mended 2026-11-22, above: it was the chest,
which no capsule covered, and the sleeves). The three between stand.

**Clothes of cloth: tried and dropped** (John, 2026-11-22: "They asked if
the clothes could be dynamic cloth too, I will leave that up to you, try
it, if it's too expensive to either work or performance wise, drop it").
The tunic's skirt and the dress as a sheet of the cloaks' cloth closed
into a tube, hung from a ring round the belt and kept off the hips and
the legs, in a scratch tree: thirteen skirts cost 0.88 to 1.02 ms a frame
in three recorded runs (the gate running beside them; thirteen worn
cloaks in one of the same runs 0.89), and a skirt is worn all day by
everyone where a cloak costs only while it is worn. Standing and walking
it read as a skirt, a bell of six flat sides, without the belt, the
hem's trim or a gatherer's apron (those are painted on the rigid skirt);
on someone turning it swung out into a skewed cone; asleep it was a
barrel round the legs, and it and the cloak cut through each other (the
cloth is kept out of capsules, not out of other cloth). The patch, six
stills and the figures are kept:
`~/CASTLE_GAME/releases/wip/cloth_skirts_trial_2026_11_22/`.

Not there yet: cloth for anything else (skirts are rigid,
so a long stride can push a leg through a skirt; the cloth package is made
to hang from anything, and nothing else hangs from it yet: the trial above), the cloak
taken up again by hand (it is put on, or laid over its sleeper, at once),
a cloak on the row put to sleep in daylight (`--lineup`: the old spread
cloak), cloth that blows in the wind, culling figures off
screen, tools for the other jobs. Left out on purpose (John, above): a
hand that goes to the hip, the shoulder or the quiver for what it takes.
