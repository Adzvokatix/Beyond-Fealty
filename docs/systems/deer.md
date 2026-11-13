# Deer

- Packages: Castle.Deer, Animals, Herds
- Check: deer_check (about 1 s); herds are also in colony_check
- Saves: the herds' own blob inside the colony blob (from colony version 5)
- Stage: stage 3 (Handoff_2026_11_08_stage_3.md); deer wandering in, stage 4; the herds' flight together and
  out of water, 2026-11-11 (Handoff_2026_11_11_models_pass.md)

## Deer

Deer are made the way serfs are (`Castle.Deer`): boxes on the 5 cm pixel
grid with a painted skin, hung on the same fifteen bones put to a
four-legged use. The pelvis is the hindquarters, the chest the forequarters,
the head bone the neck and head together (rooted at the front of the chest,
so lowering it to graze swings both), the arm bones the forelegs and the leg
bones the hind legs, each leg an upper bone, a lower bone and a hoof. There
are four classes, a fawn (small and dappled), a doe, a young stag (spikes)
and a stag (branched antlers), each in a red-brown summer and a grey-brown
winter coat, with a pale belly and throat, a white rump patch, dark hooves
and nose. One look per class and coat is made and shared, not one per
animal: texture layers are shared with the serfs. Their boxes are drawn
rounded like everyone's (`people.md`, "Rounded boxes"): the two halves of
the barrel by 2 pixels (`Barrel_Round`), an upper leg narrowing by a third
to the knee or the hock, the neck to the head, the ears to their tips
(`castle-deer.ads`); the hindquarters reach two pixels into the
forequarters so their rounded ends leave no groove between them.

* **Pose.** `Castle.Deer.Solve` takes where the hips and the withers are, how
  far the neck is tipped forward (about 0.5 alert, 0.8 walking, 2.25 head to
  the grass), its turn, an arch of the back and the four hooves, and gives a
  frame per bone: the legs by two-bone IK, the forelegs' knees forward and
  the hind hocks back.
* **Gait** (`Castle.Animals`, the deer's counterpart of `Castle.Serfs`):
  movement is presentation, the body following where it is meant to be
  through second-order filters. The legs are a stepper locked to the gait's
  phase: a hoof stays where it landed (it never slides) until its turn in
  the footfall, then swings on an arc to land half a stance ahead of its hip
  as its cycle comes round, so the legs fall back into step by themselves
  after any change. The gait follows the speed: a walk under 1.7 m/s (left
  hind, left fore, right hind, right fore, three hooves always down, 0.85 m a
  stride), a trot under 3.4 m/s (diagonal pairs, 1.5 m) and above that a bound
  (hind pair then fore pair, all four in the air between strides, 3 m, the
  back arching). A deer stands with its legs nearly straight, so a moving
  one carries its body as low as its planted hooves need to be reached,
  never below 85 % of standing, the two ends dipping together so the back
  stays nearly level. Standing, it shifts one hoof at a time; its head is up
  and turning when alert, down in the grass when grazing.

Test options on the game: `--deer N` (N deer in a row at the start focus,
every class in turn, grazing, idle or alert), `--deer-walk X0 Y0 X1 Y1 SPEED`
(a deer going there and back by planned routes at SPEED m/s, which picks the
gait; up to eight), `--follow-deer` (the camera on the first).

```sh
./bin/castle_game --float --at 1176 1080 --cam 2.9 0.3 6 --deer 6
./bin/castle_game --float --at 1176 1080 --cam 1.57 0.2 4 --deer-walk 1160 1080 1195 1080 6.0 --follow-deer
```

`./bin/debug/deer_check` builds every class and coat (every net inside the
skin), stands each up (every leg reaching its hoof), moves hooves about
within reach (each reached exactly), then drives a doe across flat ground:
no planted hoof ever slides, walking three hooves are down and they lift in
the walk's order, trotting the diagonal pairs lift together, bounding all
four are off the ground between strides, the gait follows the speed, the
stride is the same at 30 and 120 frames a second, the legs reach their
planted hooves, the back stays within 15 degrees of level, and the body
keeps up.

**Herds** (`Castle.Herds`, simulated on the colony's clock and saved with
it). When a colony is founded, two herds are placed round the stake (once
its ground is in) on walkable ground 30 to 55 m off: a stag or a young stag,
does, a fawn. Each herd has a node, which is where the herd is and decides
where it goes: it grazes a few minutes, then plans a route (`Castle.Nav`)
to another spot 15 to 30 m away and walks it, keeping at least 32 m from the
stake and within 70 m of it (the colony's ground, which stays loaded); a
deer never wanders nearer the stake than 22 m, so the band going about its
work doesn't set off one panic after another. The
deer wander round the node: each keeps to a spot of its own a few metres
from it, picked afresh now and then, walks to it (trots if far) and grazes,
idles or stands alert there. A deer steps over the walking map itself, a
step at a time, turning aside round what is in the way: up at most a step,
down at most a metre, never into water too deep to wade. Only the node
plans routes.

* **Fear, and the herd's flight together.** John, 2026-11-11: "deer
  pathfinding is kinda wonky, when the herd node move away and deer panic
  they start to rubberband and swing around, they also don't mind
  submerging themselves in water". Someone walking within 15 m of a deer,
  a hunter stalking within 7 m, or an arrow loosed at the herd startles
  it, and the node flees about 30 m straight away from the danger, as
  before. What the deer do is new (first rules and values of mine, his to
  tune; the numbers are at the top of `castle-herds.ads`):
  1. A deer starts on a heading of its own for about 0.6 to 0.9 s
     (`Startle_S`), between away from the danger and the way the herd is
     going; then it runs with the herd, for its own place round the node,
     as fast as it needs to keep that place and no faster than it can run
     (6 to 7.5 m/s; a fawn 5 to 6.5). Ahead of its place it runs on
     slower (`Flight_Slow`) and is caught up; it never runs back toward
     the danger to find its place.
  2. The node runs at 5 m/s (`Flee_Pace`; it was 4, and the deer outran
     it). A deer's flight is over when the node has stopped and it has
     come within 2.5 m of its place (or after 30 s, whatever happens).
  3. A herd in flight is not startled again. Only someone within 8 m
     (`Close_M`) of one of its deer turns it: the node plans a new way and
     the deer follow, none of them starting afresh. A herd that has
     stopped is not startled within 3 s of the last time.
  4. At the edge of its range, the danger inside it, the node tries
     shorter flights (18 m, 10 m) and ways round past the danger before it
     gives up; with nowhere at all to go, each deer bolts a second or two
     by itself and comes back.
  5. A deer turns at no more than 2.5 rad/s (4.5 in flight), and the way
     it turned aside round something is the way it then faces, so it does
     not flick from heading to heading step by step. With no way on
     within a quarter turn of where it faces it turns on, always the same
     way round, until it finds one, and goes along the edge of what
     stopped it.
  6. A deer left more than 8 m (`Trail_M`) behind its place does not make
     straight for it: it takes the way the node went, the route the node
     planned (kept after the node has arrived), heading for a point of it
     3 m past where it is nearest. Only the node plans, as before.
  7. A deer keeps out of water. Calm, it steps onto no floor under water
     at all; in flight, a quarter of a metre at most (`Flight_Wade_B`).
     One that finds itself deeper may step to water no deeper than it
     stands in and, calm, makes for the node until it is out. The node's
     ways are planned dry the same (`Castle.Nav.Plan`'s `Wade`), it never
     stops in water, and herds are placed on dry ground.
* **The herds as they were** (`Castle.Herds.Set_Scatter`, `--deer-scatter`;
  saved): each deer bounding off on a heading of its own for 3 to 6 s and
  then trotting back to the node wherever it had got to, startled again
  every 3 s while someone was near, cornered deer reversing, wading
  wherever a serf can (half a metre). Six of the seven reference logs are
  kept with it, so the older checks still prove what they proved.
* **Measured** (seed 1, the reference band, four game days from six on
  day 20, `colony_run --deer-track`, a line a deer a colony second; on the
  world of generator 13, measured again when the trees and the grass
  changed, since a different world is a different four days):

  | | as they were | fleeing together |
  |---|---|---|
  | deer-seconds in water | 2,661 of 41,316 (6.4 %); 2,524 deeper than a block | 5 of 44,750 (0.01 %); none deeper than a block |
  | further than 15 m from its node | 3,942 s; furthest 146 m | 1 s; furthest 16 m |
  | walked in the 20 s after a panic | 28.0 m | 3.7 m |
  | heading turned over 120 degrees from one second to the next, on the move | 295 times | 32 times |

  Over the 41 days of the reference run the two hunters bring down 32
  deer with 74 arrows (30 with 73 as the herds were; measured again
  2026-11-11, after a goal out of reach was always known for one,
  `routes.md`: before that it was 31 with 75, and 31 with 83). The water that is
  left is a quarter metre deep: 4 deer-seconds of flight through it, as
  rule 7 allows, and 1 of a calm deer walking out. (On generator 12 the
  same four days gave 334 deer-seconds in water against 23, 4,931 s
  astray against 8, 27.8 m against 3.9, 139 turns against 36, and the 41
  days 29 deer with 72 arrows against 32 with 87: the herds as they were
  go by chance from world to world, the herds fleeing together hardly.)
* **Deer wander in.** Every three game days two grown deer join the
  smallest herd if it has fewer than five (`Arrive_Days`, `Full_Herd`), so
  a hunted-out neighbourhood recovers.
* **Fawns and growing up.** Each spring every grown doe may bear a fawn (a
  herd keeps to ten); a fawn is a doe or a young stag at a year old, a young
  stag a stag at two (a game year is 60 days). The look changes with the
  class and with the season's coat.
* **Saves.** The herds go into the colony's save (its version 5): nodes,
  routes, every deer's place, spot, panic and age, so a load carries on
  exactly. A colony saved before herds gets them placed when it is loaded.
  The herds' blob is its own version 2 (the colony's 17): after
  version 1's content, whether the herds scatter as they were (a byte)
  and, for every deer, the seconds left of its start (f32). A version 1
  blob loads with the herds fleeing together from then on; a deer caught
  mid-bolt runs it out as its start.

The colony's log line counts the deer and herds, and while the colony is
waiting for its ground it says how many stacks it is waiting on.

`colony_check` has the flight (the deer never more than 16 m from the
node, no step toward the danger, no turn sharper than the rule's, no
trotting back afterwards), a pool across the way (no deer in it, calm or
startled), a save taken in a flight, and a version 16 blob with a herd
mid-bolt; its older herd section runs with the herds as they were.

Not there yet: the tail's flag when alarmed, ears turning, deer lying down,
deer dying of age. A herd keeps within 70 m of the stake, so one pressed
against that edge can still be cornered (rule 4). Deer cross no water
deeper than a quarter metre: a herd on one bank of a stream stays there
unless there is a dry way round.
