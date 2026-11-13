# What .kkrieger / werkkzeug3 does that matters for Castle Game
 
Source read: github.com/jaromil/kkrieger-werkkzeug3 (a mirror of farbrausch's released sources).
Licences: werkkzeug3 is BSD (Ohlerich, Giesen, Mahlke, Muetze, Hinrichs, Zuehlke); OpenKTG (ktg/) is
public domain. We reimplement in Ada either way; keep attribution in comments where we follow closely.
 
## The core idea
Assets are stored as their creation history (operator graphs), regenerated at load: 96 KB for a game
that would be 200-300 MB stored conventionally. Castle Game already does this for the world (seed +
edits); a serf's genome is the same idea.
 
## Creatures: rigid segments on a procedural stepper with two-bone IK
- Monster parts in kkrieger3383.k: robospider, kkillerscorp leg_upper/leg_lower, spider bein_oben/
  bein_unten (upper/lower leg), korpus (body), hellbug head. Rigid meshes per segment, no skinning.
- Scene_Walk (werkkzeug3_kkrieger/genscene.cpp, Exec_Scene_Walk): up to 8 feet, each with a rest
  offset, old/new position and a step timer. Parameters per walk/run: foot groups (feet with the same
  index mod groups step together: 2 groups = alternating gait), step length, step duration, next-step
  overlap; walk/run switch with hysteresis thresholds. The foot farthest from its rest spot (relative to
  where the body wants to be) steps next. Foot = lerp(old, new) plus a lift arc (default
  sin(t*pi)*0.25, or a "step spline" for the shape). Body position = mean of the feet; body axes fitted
  to the feet's displacements times their rest offsets (so a body tilts with the ground under it).
  Ground scan up/down for foot targets (commented out in this version). A "fake" mode runs the cycle
  on a timer in place (a treadmill for previewing).
- Scene_Limb: analytic two-bone IK by the law of cosines (t = (c^2+a^2-b^2)/2c, s = sqrt(a^2-t^2)),
  straight limb when out of reach.
- MinMesh_BoneChain / BoneTrain (genminmesh.cpp): skinned chains with cubic weights over 4 bones,
  bones following a spline with a delay: tails, tentacles, snakes.
- No smoothing dynamics: second-order filters (t3ssel8r) are what we add on top for weight.
## AI
No pathfinding: monsters steer straight at the player when in line of sight (notice/charge/wait radii)
plus a "magnet" repulsion between monsters (kkriegergame.cpp, MonsterAI / MonsterMagnetAI). Only the
separation force is worth borrowing (crowds on roads).
 
## Textures
genbitmap.cpp ops: Flat, Perlin, Cell, Gradient, GlowRect, Dots, Bricks, Text, Blur, Merge, Mask, HSCB,
ColorBalance, Range, Rotate, RotateMul, Twirl, Distort, Bulge, Normals, Bump, Light, Sharpen, Wavelet.
OpenKTG (public domain, ktg/gentexture.*) is the compact core: Noise with a colour ramp, Cells
(Voronoi), GlowRect, colour matrix, coordinate matrix (tile/rotate), colour remap, coordinate remap
(distort), derive (gradient/normals), blur, ternary (mask lerp/select), paste (stamp with combine op),
bump lighting, linear combine. Basis for serf skins, props, banners at 5 cm texels.
 
## Not useful to us
DX9 multipass renderer with stencil shadows and portals; mesh subdivision/bevel (smooth shapes, wrong
for blocks); the werkkzeug editor and graph format (our recipes can be Ada code).
