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
  them and a 128 x 64 painted skin (each box's faces unfolded as a net and
  the nets shelf-packed), the same every time, so a save will need only the
  genome. The left limbs are built and painted and the right ones are their
  mirror images; then the symmetry is broken on purpose: the tool goes in
  the dominant hand (one in ten is left-handed), one sleeve may be pushed
  up, a scar sits on one cheek, a sword hangs on the off side. Jobs so far:
  forester (greens, an axe), hunter (leather jerkin, bow), gatherer (apron,
  basket on the back), porter (sack on the back), lord (rich dyes, gold
  trim, sword) and idle. Winter adds a cloak and a hood with the face cut
  out. Children carry no tools. (The axe and the bow are no longer boxes
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
  upright in the hand held out instead of pointing at the deer.
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
`--winter` (winter dress whatever the season) and `--record DIR N` (save
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
stands 500 of them up, tests the IK on 1,000 targets and walks one over
flat ground (pace, reach, bob, no sliding feet, one foot always down, arms
against legs, the same stride at 30 and 120 fps); `--png FILE` writes a
sheet of skins to look at.

Not there yet: cloth (skirts and cloaks are rigid,
so a long stride can push a leg through a skirt), culling figures off
screen, tools for the other jobs. Left out on purpose (John, above): a
hand that goes to the hip, the shoulder or the quiver for what it takes.
