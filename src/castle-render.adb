with Ada.Text_IO;             use Ada.Text_IO;
with Ada.Unchecked_Deallocation;
with Interfaces;              use Interfaces;
with Interfaces.C;            use Interfaces.C;
with Interfaces.C.Strings;    use Interfaces.C.Strings;
with System;                  use System;
with System.Storage_Elements; use System.Storage_Elements;
with Ada.Numerics;
with Ada.Numerics.Elementary_Functions;
with Castle.Blocks;
with Castle.Bodies;
with Castle.Colors;
with Castle.Figures;
with Castle.Marks;
with Castle.Currents;
with Castle.Cutaway;
with Castle.Fields;
with Castle.Hash;
with Castle.Dims;             use Castle.Dims;
with Castle.Far;
with Castle.GL;               use Castle.GL;
with Castle.Lod;
with Castle.PNG;
with Castle.Textures;

package body Castle.Render is

   LF : constant Character := ASCII.LF;

   Fire_Far_M : constant := Fire_Reach_M + 2.0;   --  the far side of the fire's depth maps

   Light_Cell_M : constant := 16;                 --  the lights' grid: which reach each cell this size
   Light_Cells  : constant := Size_M / Light_Cell_M;

   --  A palette colour (Castle.Colors) as a GLSL vec3 literal, 0 to 1.
   function GLSL (Hex : Castle.Colors.Hex_Code) return String is
      C : constant Castle.Colors.RGB := Castle.Colors.Of_Hex (Hex);
      function Part (V : Unsigned_8) return String is
         M : constant Natural := (Natural (V) * 1000 + 127) / 255;   --  thousandths
         D : constant String := Natural'Image (1000 + M mod 1000);
      begin
         return Natural'Image (M / 1000) (2 .. Natural'Image (M / 1000)'Last) & "." & D (3 .. 5);
      end Part;
   begin
      return "vec3(" & Part (C.R) & ", " & Part (C.G) & ", " & Part (C.B) & ")";
   end GLSL;

   function GLSL (V : Float) return String is
      M : constant Natural := Natural (Float'Rounding (abs V * 1000.0));   --  thousandths
      D : constant String := Natural'Image (1000 + M mod 1000);
   begin
      return (if V < 0.0 then "-" else "") & Natural'Image (M / 1000) (2 .. Natural'Image (M / 1000)'Last)
        & "." & D (3 .. 5);
   end GLSL;

   function GLSL_Int (N : Natural) return String is (Natural'Image (N) (2 .. Natural'Image (N)'Last));

   --  Vertex pulling: gl_VertexID / 6 is the quad, mod 6 the corner.  The
   --  stack origin arrives as a per-draw attribute (divisor 1, fetched at
   --  the command's baseInstance), so no GL 4.6 draw parameters are needed.
   Vertex_Source : constant String :=
     "#version 450 core" & LF &
     "layout(location = 0) in ivec4 a_origin;" & LF &
     "layout(std430, binding = 0) readonly buffer Quads { uvec2 quads[]; };" & LF &
     "uniform mat4 u_viewproj;" & LF &
     "uniform vec3 u_camera;" & LF &
     "layout(binding = 5) uniform sampler2D u_lv;" & LF &
     "uniform float u_blend;" & LF &
     "uniform int u_wmask;" & LF &
     "uniform float u_wstep;" & LF &
     "out vec3 v_world;" & LF &
     "out vec3 v_grid;" & LF &                 --  where it is on the block grid (foliage is drawn moved off it)
     "out vec4 v_bend;" & LF &                 --  foliage: what the light's normal turns by; how far it stands out
     "flat out uint v_mat;" & LF &
     "flat out int v_face;" & LF &
     "flat out uint v_ao;" & LF &
     "flat out uint v_fr;" & LF &              --  the fringe's bits (Castle.Mesher)
     "flat out int v_lod;" & LF &              --  0: a stack's own mesh; else the level of a tile of the far view
     "flat out float v_depth;" & LF &          --  open water: blocks of it in this column (-1: not known)
     --  A hash of a corner of the block grid, for moving foliage: by place
     --  alone, so every face that meets a corner moves it alike, in the
     --  picture and in every light's depth map.
     "uint vhash(ivec3 p) {" & LF &
     "  uint h = uint(p.x) * 0x8da6b343u ^ uint(p.y) * 0xd8163841u ^ uint(p.z) * 0xcb1ab31fu;" & LF &
     "  h ^= h >> 16u; h *= 0x7feb352du; h ^= h >> 15u;" & LF &
     "  return h;" & LF &
     "}" & LF &
     "float pull_of(uint c) { return c == 1u ? 1.0 : c == 2u ? -1.0 : 0.0; }" & LF &
     --  Surface water: a column's level blended between the last two
     --  ticks, and the height of the surface at a corner of the block grid,
     --  the mean of every wet column meeting there.  So all open water is
     --  one sheet: neighbouring columns share their corners whatever their
     --  levels, a slope of water lies as a slope (not as 0.25 m stairs
     --  with a riser on every step), and a fall is the sheet running
     --  steeply from the level above to the level below.  (Columns more
     --  than 0.75 of a block apart used to keep separate corners, which
     --  drew every step of a fast creek, and every fall, as a lit wall.)
     "float lv_at(ivec2 c) { vec4 t = texelFetch(u_lv, c & ivec2(u_wmask), 0); return mix(t.r, t.g, u_blend); }" & LF &
     "bool wet_at(ivec2 c) { vec4 t = texelFetch(u_lv, c & ivec2(u_wmask), 0); return mix(t.r, t.g, u_blend) > t.b + 0.02; }" & LF &
     "float corner_z(ivec2 p, float ref) {" & LF &
     "  float s = 0.0, n = 0.0;" & LF &
     "  for (int j = -1; j <= 0; j++) for (int i = -1; i <= 0; i++) {" & LF &
     "    vec4 t = texelFetch(u_lv, (p + ivec2(i, j)) & ivec2(u_wmask), 0);" & LF &
     "    float l = mix(t.r, t.g, u_blend);" & LF &
     "    if (l > t.b + 0.02) { s += l; n += 1.0; }" & LF &
     "  }" & LF &
     "  return n > 0.0 ? s / n : ref;" & LF &
     "}" & LF &
     --  Stepped water (u_wstep steps to a block; 0: the one sheet above).
     --  Each column stands flat at its own level, taken to the nearest
     --  step, with a riser down to a lower neighbour: water that drops
     --  toward a cut goes down in steps, and water on the move ripples as
     --  its steps shift.  (John, 2026-11-10: "rippling by stepping the
     --  water instead of smoothing".)  Water thinner than half a step is
     --  drawn half a step deep, so a film still shows.
     "float stepped(float l, float fl) { return max(floor(l * u_wstep + 0.5), floor(fl * u_wstep) + 0.5) / u_wstep; }" & LF &
     "const vec2 corner[6] = vec2[6](vec2(0,0), vec2(1,0), vec2(1,1)," &
     " vec2(0,0), vec2(1,1), vec2(0,1));" & LF &
     "void main() {" & LF &
     "  uvec2 q = quads[gl_VertexID / 6];" & LF &
     "  vec2 k = corner[gl_VertexID % 6];" & LF &
     "  int x = int(q.x & 31u);" & LF &
     "  int y = int((q.x >> 5u) & 31u);" & LF &
     "  int z = int((q.x >> 10u) & 1023u);" & LF &
     "  bool soft = (q.x & 0x20000000u) != 0u;" & LF &      --  foliage: one block, its corners moved
     "  bool tuft = (q.x & 0x40000000u) != 0u;" & LF &      --  a plant on the ground: one column, its top moved
     "  float w = soft ? 1.0 : float(((q.x >> 20u) & 31u) + 1u);" & LF &
     "  int face = int((q.x >> 25u) & 7u);" & LF &
     "  float h = soft ? 1.0 : float((q.y & 255u) + 1u);" & LF &
     "  v_mat = (q.y >> 8u) & 255u;" & LF &
     "  v_ao = soft ? 255u : (q.y >> 16u) & 255u;" & LF &
     "  v_fr = soft ? 0u : (q.y >> 24u) & 255u;" & LF &
     "  v_face = face;" & LF &
     "  if (face == 1 || face == 2 || face == 5) k = k.yx;" & LF &
     "  vec3 p;" & LF &
     "  v_depth = -1.0;" & LF &
     "  v_bend = vec4(0.0);" & LF &
     "  v_lod = a_origin.w;" & LF &
     --  A surface cell (bit 28): one column of open-sky water.  Its top
     --  sits at the column's level, blended between the last two ticks;
     --  a side runs from whatever stands beside it (the neighbour's water
     --  or floor, whichever is higher) up to that level.  A dry column, or
     --  a side with nothing to show, collapses to a point off screen.
     "  if ((q.x & 0x10000000u) != 0u) {" & LF &
     "    ivec2 c = a_origin.xy + ivec2(x, y);" & LF &
     "    vec4 me = texelFetch(u_lv, c & ivec2(u_wmask), 0);" & LF &
     "    float lv = mix(me.r, me.g, u_blend);" & LF &
     "    bool show = lv > me.b + 0.02;" & LF &
     "    v_depth = max(lv - me.b, 0.0);" & LF &
     --  The sheet of a fall passing over this column (z 1; see the spec,
     --  "Falls"): a slab from its underside to its top, both taken to the
     --  step as the water's levels are.  A side toward a column with no
     --  sheet is the slab's own edge; toward one whose sheet is lower or
     --  higher it runs from the one top to the other, so the sheets of an
     --  arch join into one curtain, seen from the front and from behind.
     "    if (z == 1) {" & LF &
     "      float ws = u_wstep > 0.0 ? u_wstep : 8.0;" & LF &
     "      show = me.a > 0.5;" & LF &
     "      float th = mod(me.a, 1024.0) / 16.0;" & LF &
     "      float ar = floor(me.a / 1024.0) / 16.0;" & LF &
     "      float at = floor(ar * ws + 0.5) / ws;" & LF &
     "      float ab = min(floor((ar - th) * ws + 0.5) / ws, at - 1.0 / ws);" & LF &
     "      v_depth = 4.0;" & LF &                      --  (its hue is a metre of water's, however thin it is)
     "      v_fr = 0x100u;" & LF &                      --  (past any fringe byte: the mark of a sheet)
     "      if (face >= 4) {" & LF &
     "        p = vec3(float(x) + k.x, float(y) + k.y, face == 4 ? at : ab);" & LF &
     "      } else {" & LF &
     "        ivec2 o = face == 0 ? ivec2(1, 0) : face == 1 ? ivec2(-1, 0) : face == 2 ? ivec2(0, 1) : ivec2(0, -1);" & LF &
     "        float na = texelFetch(u_lv, (c + o) & ivec2(u_wmask), 0).a;" & LF &
     "        float z0 = ab, z1 = at;" & LF &
     "        if (na > 0.5) {" & LF &
     "          float nt = floor(floor(na / 1024.0) / 16.0 * ws + 0.5) / ws;" & LF &
     "          if (nt < at - 0.001) z0 = nt;" & LF &
     "          else if (nt > at + 0.001) { z0 = at; z1 = nt; }" & LF &
     "          else show = false;" & LF &
     "        }" & LF &
     "        if (face < 2) p = vec3(float(x + 1 - face), float(y) + k.x, z0 + k.y * (z1 - z0));" & LF &
     "        else          p = vec3(float(x) + k.x, float(y + 3 - face), z0 + k.y * (z1 - z0));" & LF &
     "      }" & LF &
     "    } else {" & LF &
     --  (thin water under a sheet that falls free is the same water, on its
     --  way down the face as the simulation has it: it is not drawn twice)
     "    if (me.a > 0.5) {" & LF &
     "      float ab = (floor(me.a / 1024.0) - mod(me.a, 1024.0)) / 16.0;" & LF &
     "      if (ab > lv + 0.5 && lv - me.b < 1.0) show = false;" & LF &
     "    }" & LF &
     "    if (face == 4) {" & LF &
     "      p = vec3(float(x) + k.x, float(y) + k.y," & LF &
     "               u_wstep > 0.0 ? stepped(lv, me.b) : corner_z(c + ivec2(k), lv));" & LF &
     "    } else if (u_wstep > 0.0) {" & LF &
     --  Stepped: a riser wherever what stands beside is lower (its water,
     --  or its floor if it is dry), from there up to this column's level.
     "      ivec2 o = face == 0 ? ivec2(1, 0) : face == 1 ? ivec2(-1, 0) : face == 2 ? ivec2(0, 1) : ivec2(0, -1);" & LF &
     "      vec4 nb = texelFetch(u_lv, (c + o) & ivec2(u_wmask), 0);" & LF &
     "      float nl = mix(nb.r, nb.g, u_blend);" & LF &
     "      float zt = stepped(lv, me.b);" & LF &
     "      float zb = nl > nb.b + 0.02 ? stepped(nl, nb.b) : max(nb.b, me.b);" & LF &
     "      if (zt < zb + 0.001) show = false;" & LF &
     --  (where a sheet leaves by this side, or stands against it, there
     --  is no curtain down the face as well)
     "      if (nb.a > 0.5) {" & LF &
     "        float nt = floor(nb.a / 1024.0) / 16.0;" & LF &
     "        if (nt - mod(nb.a, 1024.0) / 16.0 <= zt + 0.5 && nt >= zb) show = false;" & LF &
     "      }" & LF &
     "      if (face < 2) p = vec3(float(x + 1 - face), float(y) + k.x, zb + k.y * (zt - zb));" & LF &
     "      else          p = vec3(float(x) + k.x, float(y + 3 - face), zb + k.y * (zt - zb));" & LF &
     "    } else {" & LF &
     --  A side only where the neighbour is dry: from the higher of its
     --  floor and ours up to the sheet at this end of the edge (water held
     --  above lower dry ground).  Beside wet columns the sheet is joined.
     "      ivec2 o = face == 0 ? ivec2(1, 0) : face == 1 ? ivec2(-1, 0) : face == 2 ? ivec2(0, 1) : ivec2(0, -1);" & LF &
     "      ivec2 e = face < 2 ? ivec2(c.x + 1 - face, c.y + int(k.x)) : ivec2(c.x + int(k.x), c.y + 3 - face);" & LF &
     "      vec4 nb = texelFetch(u_lv, (c + o) & ivec2(u_wmask), 0);" & LF &
     "      float nl = mix(nb.r, nb.g, u_blend);" & LF &
     "      bool nwet = nl > nb.b + 0.02;" & LF &
     "      if (nwet) show = false;" & LF &
     "      float zt = corner_z(e, lv);" & LF &
     "      float zb = max(nb.b, me.b);" & LF &
     "      if (max(zt, lv) < zb + 0.01) show = false;" & LF &
     "      if (nb.a > 0.5) {" & LF &                     --  (no curtain where a sheet leaves, as above)
     "        float nt = floor(nb.a / 1024.0) / 16.0;" & LF &
     "        if (nt - mod(nb.a, 1024.0) / 16.0 <= lv + 0.5 && nt >= zb) show = false;" & LF &
     "      }" & LF &
     "      zb = min(zb, zt);" & LF &
     "      if (face < 2) p = vec3(float(x + 1 - face), float(y) + k.x, zb + k.y * (zt - zb));" & LF &
     "      else          p = vec3(float(x) + k.x, float(y + 3 - face), zb + k.y * (zt - zb));" & LF &
     "    }" & LF &
     "    }" & LF &
     "    if (!show) {" & LF &
     "      v_world = vec3(0.0);" & LF &
     "      v_grid = vec3(0.0);" & LF &
     "      gl_Position = vec4(2.0, 2.0, 2.0, 1.0);" & LF &
     "      return;" & LF &
     "    }" & LF &
     "  }" & LF &
     "  else if (face < 2) p = vec3(float(x + 1 - face), float(y) + k.x * w, float(z) + k.y * h);" & LF &
     "  else if (face < 4) p = vec3(float(x) + k.x * w, float(y + 3 - face), float(z) + k.y * h);" & LF &
     "  else               p = vec3(float(x) + k.x * w, float(y) + k.y * h, float(z + 5 - face));" & LF &
     --  (a tile of the far view: its quads are in cells of 2 ** level blocks)
     "  vec3 g = vec3(a_origin.xyz) + p * float(1 << a_origin.w);" & LF &
     "  v_grid = g * 0.25;" & LF &
     --  Foliage (see the spec): this corner's six bits say which way the
     --  foliage lies from it on each axis, if it is open on two or three: an
     --  edge or a corner of a clump, which is cut back and strays a little.
     --  A dressed roof (see the spec): the corner is moved just as far as
     --  its bits say, and the light goes by the face as it then lies (its
     --  four corners moved, and the turn of the face from where it was).
     "  if (soft && (q.x & 0x80000000u) != 0u) {" & LF &
     "    uint bits = ((q.y >> 16u) & 0xFFFFu) | ((q.y & 0xFFu) << 16u);" & LF &
     "    vec3 cn[4];" & LF &
     "    for (int i = 0; i < 4; i++) {" & LF &
     "      vec2 kk = vec2((i == 1 || i == 2) ? 1.0 : 0.0, (i >= 2) ? 1.0 : 0.0);" & LF &
     "      vec3 pp;" & LF &
     "      if (face < 2) pp = vec3(float(x + 1 - face), float(y) + kk.x, float(z) + kk.y);" & LF &
     "      else if (face < 4) pp = vec3(float(x) + kk.x, float(y + 3 - face), float(z) + kk.y);" & LF &
     "      else pp = vec3(float(x) + kk.x, float(y) + kk.y, float(z + 5 - face));" & LF &
     "      uint cd = (bits >> uint(6 * i)) & 63u;" & LF &
     "      uint cz = (cd >> 4u) & 3u;" & LF &
     "      cn[i] = pp + vec3(0.25 * pull_of(cd & 3u), 0.25 * pull_of((cd >> 2u) & 3u)," &
     " cz == 2u ? -1.0 : cz == 3u ? -0.5 : cz == 1u ? 1.0 : 0.0);" & LF &
     "    }" & LF &
     "    int ci = (k.y < 0.5) ? int(k.x) : 3 - int(k.x);" & LF &
     "    g = vec3(a_origin.xyz) + cn[ci];" & LF &
     "    vec3 fn = cross(cn[2] - cn[0], cn[3] - cn[1]);" & LF &
     "    const vec3 fnorm[6] = vec3[6](vec3(1,0,0), vec3(-1,0,0), vec3(0,1,0), vec3(0,-1,0), vec3(0,0,1), vec3(0,0,-1));" & LF &
     "    if (dot(fn, fnorm[face]) < 0.0) fn = -fn;" & LF &
     "    v_bend = vec4(dot(fn, fn) > 1.0e-6 ? normalize(fn) - fnorm[face] : vec3(0.0), 0.0);" & LF &
     "  }" & LF &
     "  else if (soft) {" & LF &
     "    int ci = (k.y < 0.5) ? int(k.x) : 3 - int(k.x);" & LF &
     "    uint bits = ((q.y >> 16u) & 0xFFFFu) | ((q.y & 0xFFu) << 16u);" & LF &
     "    uint code = (bits >> uint(6 * ci)) & 63u;" & LF &
     "    vec3 pull = vec3(pull_of(code & 3u), pull_of((code >> 2u) & 3u), pull_of((code >> 4u) & 3u));" & LF &
     "    float n = abs(pull.x) + abs(pull.y) + abs(pull.z);" & LF &
     "    if (n > 1.5 && v_mat == " & GLSL_Int (Castle.Blocks.Material'Pos (Castle.Blocks.Boulder)) & "u) {" & LF &
     "      g += pull * " & GLSL (Float (Boulder_Cut)) & ";" & LF &
     "      vec3 fn = vec3(face == 0 ? 1.0 : face == 1 ? -1.0 : 0.0, face == 2 ? 1.0 : face == 3 ? -1.0 : 0.0," &
     " face == 4 ? 1.0 : face == 5 ? -1.0 : 0.0);" & LF &
     --  (a corner drawn out of a hollow, bit 20 + its number: the way out is the way it went)
     "      bool outw = ((q.x >> (20u + uint(ci))) & 1u) != 0u;" & LF &
     "      v_bend = vec4(normalize(outw ? pull : -pull) - fn, 0.0);" & LF &
     "    }" & LF &
     "    else if (n > 1.5) {" & LF &
     "      ivec3 gi = ivec3(round(g));" & LF &
     "      uint hh = vhash(gi + ivec3(17, 5, 3));" & LF &
     "      vec3 j = vec3(float(hh & 1023u), float((hh >> 10u) & 1023u), float((hh >> 20u) & 1023u)) / 1023.0 - 0.5;" & LF &
     "      g += pull * " & GLSL (Float (Foliage_Cut)) & " + j * " & GLSL (Float (1.5 * Foliage_Jitter)) & ";" & LF &
     "      v_bend = vec4(-pull * " & GLSL (Float (Foliage_Bend)) & ", 0.5 * (n - 1.0));" & LF &
     "    }" & LF &
     "  }" & LF &
     --  A tuft (see the spec): its top leans, is drawn in and stands higher
     --  or lower, by the column it stands in, so all its faces agree.
     "  if (tuft) {" & LF &
     "    uint th = vhash(ivec3(a_origin.xy + ivec2(x, y), 91));" & LF &
     "    vec3 r = vec3(float(th & 1023u), float((th >> 10u) & 1023u), float((th >> 20u) & 1023u)) / 1023.0;" & LF &
     "    float top = (face == 4) ? 1.0 : (face == 5) ? 0.0 : k.y;" & LF &
     "    vec2 off = p.xy - (vec2(float(x), float(y)) + 0.5);" & LF &
     "    g.xy += top * ((r.xy - 0.5) * " & GLSL (Float (2.0 * Tuft_Lean)) & " - off * " & GLSL (Float (2.0 * Tuft_Taper)) & ");" & LF &
     "    g.z -= top * (1.0 - mix(" & GLSL (Float (Tuft_Low)) & ", " & GLSL (Float (Tuft_High)) & ", r.z));" & LF &
     "    v_bend = vec4(0.0, 0.0, 0.0, top);" & LF &
     "    v_fr = (face < 4) ? uint(h) : 0u;" & LF &             --  a side: how many blocks high the plant is
     "  }" & LF &
     "  v_world = g * 0.25;" & LF &
     "  gl_Position = u_viewproj * vec4(v_world - u_camera, 1.0);" & LF &
     "}" & LF;

   --  The sky, shared by the sky pass and the world shader (haze, and
   --  later water reflections): a gradient from the horizon colour to the
   --  zenith, the sun's glow and disc.  Below the horizon it is the haze
   --  distant ground fades into, so the edge of the loaded world meets the
   --  sky with no seam.
   Sky_Source : constant String :=
     --  The sun and the moon have two jobs each, kept apart: where they
     --  are in the sky (u_sun, u_moon: their discs and their glow), and what
     --  lights the land (u_lamp: the sun by day, the moon once the sun's
     --  light is gone).  One name for both is what drew the sun's disc dark.
     "uniform vec3 u_sun;" & LF &              --  toward the sun, wherever it is
     "uniform vec3 u_sun_glow;" & LF &         --  its glow in the sky (what overcast and a low sun leave of it)
     "uniform vec3 u_sun_disc;" & LF &         --  the sun's disc as it is seen
     "uniform vec3 u_moon;" & LF &             --  toward the moon
     "uniform vec3 u_moon_col;" & LF &         --  its lit face (nothing while it is down)
     "uniform float u_moon_k;" & LF &          --  how much light it gives the sky: by its phase, none by day
     "uniform float u_day;" & LF &             --  night 0 .. day 1
     "uniform vec3 u_lamp;" & LF &             --  toward what lights the land
     "uniform vec3 u_lamp_col;" & LF &         --  and its light on it
     "uniform vec3 u_orb;" & LF &              --  toward what lights the clouds: the sun, the moon once it is down
     "uniform vec3 u_orb_col;" & LF &          --  and its light on them, before any cloud is in its way
     "uniform vec3 u_zenith;" & LF &
     "uniform vec3 u_horizon;" & LF &
     "uniform vec3 u_sky_amb;" & LF &
     "uniform vec3 u_gnd_amb;" & LF &
     "layout(binding = 3) uniform sampler2D u_noise;" & LF &
     "uniform vec3 u_eye;" & LF &
     "uniform vec3 u_focus;" & LF &
     "uniform float u_fog_dist;" & LF &
     "uniform vec2 u_far;" & LF &              --  the haze at the edge of what is streamed in (1: all, as it was); where it is all
     "uniform float u_vis;" & LF &             --  weather haze per metre from the eye
     "uniform float u_mist;" & LF &            --  0 none .. 1 thick
     "uniform vec3 u_mist_col;" & LF &
     "layout(binding = 16) uniform sampler2D u_base;" & LF &   --  r: the land's level thereabouts (m); g: how damp the place is
     "uniform vec3 u_ghaze;" & LF &            --  the ground haze (see the spec): how thick at the focus, at the view's edge, far off (1/m; 0: none)
     "uniform float u_rim;" & LF &             --  the map's rim goes into the haze over this many metres (0: it does not)
     "layout(binding = 24) uniform sampler2D u_haze_top;" & LF &   --  how deep the ground haze lies on the ground (m)
     "layout(binding = 1) uniform sampler2D u_height;" & LF &      --  the land's height as it was made (m), a number a metre
     --  How far over the ground's level a point still counts as the ground,
     --  for the haze: half a block; half its cell, for a tile of the far view
     --  (whose tops stand up to that much over the ground they stand for);
     --  everything, for open water.  Set by whoever calls air.
     "float g_slack = 0.125;" & LF &
     "uniform float u_time;" & LF &
     "uniform float u_cover;" & LF &
     "uniform vec2 u_drift;" & LF &
     --  The lights (see the spec): a table of them, and for every 16 m of
     --  the world which of them reach it, so a fragment looks only at its own.
     "struct Light { vec4 at; vec4 col; };" & LF &                 --  place and reach (m); colour and strength
     "layout(std430, binding = 12) readonly buffer Light_Buf { Light lights[]; };" & LF &
     "layout(binding = 17) uniform usampler2D u_light_grid;" & LF &
     "uniform int u_light_n;" & LF &            --  how many are in the view (0: none of this runs)
     "uniform int u_light_cast;" & LF &         --  which of them casts shadows (-1: none)
     "uniform vec3 u_fire;" & LF &              --  where that one is: its depth maps are about it
     "uniform float u_fire_cast;" & LF &       --  1: the fire's depth maps are live
     "layout(binding = 13) uniform samplerCubeShadow u_fire_map;" & LF &
     --  Whether the fire can be seen from point P on a face with normal N:
     --  five filtered taps in the cube of depth maps about the light (see
     --  the spec), the point pushed off its face by a texel and a half of
     --  the map at that distance.  The depth a face of the cube holds is
     --  that of its 90-degree view, which is worked out here from the
     --  largest part of the line from the light.
     "float fire_open(vec3 p, vec3 n) {" & LF &
     "  if (u_fire_cast < 0.5) return 1.0;" & LF &
     "  float r = length(p - u_fire);" & LF &
     "  vec3 d = p + n * (0.01 + 0.006 * r) - u_fire;" & LF &
     "  float m = max(max(abs(d.x), abs(d.y)), abs(d.z));" & LF &
     "  if (m <= " & GLSL (Float (Fire_Near_M)) & ") return 1.0;" & LF &
     "  float ref = 0.5 + 0.5 * (" & GLSL (Float ((Fire_Far_M + Fire_Near_M) / (Fire_Far_M - Fire_Near_M)))
     & " - " & GLSL (Float (2.0 * Fire_Far_M * Fire_Near_M / (Fire_Far_M - Fire_Near_M))) & " / m);" & LF &
     "  vec3 a = normalize(cross(d, vec3(0.37, 0.53, 0.76)));" & LF &
     "  vec3 b = normalize(cross(d, a));" & LF &
     "  float w = 0.006 * r;" & LF &
     "  return 0.2 * (texture(u_fire_map, vec4(d, ref))" & LF &
     "              + texture(u_fire_map, vec4(d + (a + b) * w, ref)) + texture(u_fire_map, vec4(d + (a - b) * w, ref))" & LF &
     "              + texture(u_fire_map, vec4(d - (a + b) * w, ref)) + texture(u_fire_map, vec4(d - (a - b) * w, ref)));" & LF &
     "}" & LF &
     --  A light of the table on point P of a face with normal N: falling off
     --  to nothing over its reach, strongest on faces turned toward it; it
     --  shows at dusk and in the night.  What is turned from it has
     --  Fire_Fill of it, and so has what the one light that casts cannot see.
     "vec3 one_light(int i, vec3 p, vec3 n) {" & LF &
     "  vec3 d = lights[i].at.xyz - p;" & LF &
     "  float r = length(d);" & LF &
     "  float f = lights[i].col.a * max(0.0, 1.0 - r / lights[i].at.w);" & LF &
     "  if (f <= 0.0) return vec3(0.0);" & LF &
     "  float ndl = dot(n, d / max(r, 0.01));" & LF &
     --  (a face turned from the light is one of those drawn into its maps: it is
     --  not looked up against itself, and ground the light only grazes still faces it)
     "  float open = smoothstep(0.0, 0.04, ndl);" & LF &
     "  if (i == u_light_cast && open > 0.0) open *= fire_open(p, n);" & LF &
     "  return lights[i].col.rgb * 2.2 * f * f * (0.4 + 0.6 * max(ndl, 0.0))" & LF &
     "         * mix(" & GLSL (Float (Fire_Fill)) & ", 1.0, open);" & LF &
     "}" & LF &
     "vec3 firelight(vec3 p, vec3 n) {" & LF &
     "  if (u_light_n == 0) return vec3(0.0);" & LF &
     "  uvec2 m = texelFetch(u_light_grid, clamp(ivec2(floor(p.xy / " & GLSL (Float (Light_Cell_M))
     & ")), ivec2(0), ivec2(" & GLSL_Int (Light_Cells - 1) & ")), 0).rg;" & LF &
     "  vec3 sum = vec3(0.0);" & LF &
     "  while (m.x != 0u) { int i = findLSB(m.x); m.x &= m.x - 1u; sum += one_light(i, p, n); }" & LF &
     "  while (m.y != 0u) { int i = findLSB(m.y); m.y &= m.y - 1u; sum += one_light(i + 32, p, n); }" & LF &
     "  return sum;" & LF &
     "}" & LF &
     --  The weather's map of the clouds, drifting on the wind: two scales of
     --  the tiling noise, thresholded by the cover.  cloud_deep is how far
     --  into a cloud a place is on it (0 at its edge, 1 and more in its
     --  heart); cloud_at, how much of the sky a cloud covers there seen flat.
     --  Their shadows on the ground, the water's mirror of the sky and the
     --  flat layer go by cloud_at; the clouds the sky pass walks through
     --  stand where cloud_deep says (see the spec).
     "const float cloud_z = " & GLSL (Float (0.5 * (Cloud_Lo_M + Cloud_Hi_M))) & ";" & LF &
     "float cloud_deep(vec2 p) {" & LF &
     "  p += u_drift;" & LF &
     "  float n = 0.65 * texture(u_noise, p / 2000.0).r + 0.35 * texture(u_noise, p.yx / 700.0 + 0.37).r;" & LF &
     "  float t = 0.5 + 0.22 * (0.5 - u_cover);" & LF &        --  cover sets the threshold in the noise's own spread
     "  return (n - t + 0.04) / 0.14;" & LF &
     "}" & LF &
     "float cloud_at(vec2 p) {" & LF &
     "  float a = clamp(cloud_deep(p), 0.0, 1.0);" & LF &
     "  return a * a * (3.0 - 2.0 * a);" & LF &
     "}" & LF &
     --  Sunlight left after the clouds on the way down to point P.
     "float cloud_shade(vec3 p) {" & LF &
     "  if (u_lamp.z < 0.05) return 1.0;" & LF &
     "  return 1.0 - 0.6 * cloud_at(p.xy + u_lamp.xy * ((cloud_z - p.z) / u_lamp.z));" & LF &
     "}" & LF &
     "vec3 glow(vec3 d) {" & LF &
     "  float s = max(dot(d, u_sun), 0.0);" & LF &
     "  float m = max(dot(d, u_moon), 0.0);" & LF &
     "  return u_sun_glow * (0.18 * pow(s, 6.0) + 0.35 * pow(s, 48.0))" & LF &
     "       + u_moon_col * u_moon_k * (0.035 * pow(m, 8.0) + 0.10 * pow(m, 160.0));" & LF &
     "}" & LF &
     "vec3 haze(vec3 d) {" & LF &
     "  float l = length(d.xy);" & LF &
     "  vec3 h = (l > 1.0e-4) ? vec3(d.xy / l, 0.0) : vec3(1.0, 0.0, 0.0);" & LF &
     "  return u_horizon + glow(h);" & LF &
     "}" & LF &
     --  The sky behind everything: the horizon's colour up to the zenith's.
     "vec3 sky_back(vec3 d) {" & LF &
     "  return mix(u_horizon, u_zenith, 1.0 - (1.0 - d.z) * (1.0 - d.z));" & LF &
     "}" & LF &
     --  The sun and the moon, over sky C in direction D: discs that only ever
     --  add light to what is behind them.  (The sun's was mixed in at the
     --  colour of its light on the land, which overcast and a low sun take
     --  nearly all of: under snow cloud it was a dark disc on a pale sky.)
     --  The moon has its seas, from the noise.  Vis scales both, for
     --  reflections seen where their light does not fall.
     "vec3 orbs(vec3 c, vec3 d, float vis) {" & LF &
     "  float s = dot(d, u_sun);" & LF &
     "  c = max(c, mix(c, u_sun_disc, smoothstep(0.99955, 0.99975, s) * vis));" & LF &
     "  float m = dot(d, u_moon);" & LF &
     "  if (m > 0.9995 && u_moon_col.g > 0.0) {" & LF &
     "    vec3 mx = normalize(cross(vec3(0.0, 0.0, 1.0), u_moon));" & LF &
     "    vec3 my = cross(u_moon, mx);" & LF &
     "    vec2 q = vec2(dot(d, mx), dot(d, my)) / 0.0265;" & LF &            --  -1 .. 1 across the disc
     "    float seas = textureLod(u_noise, q * 0.11 + vec2(0.31, 0.57), 0.0).r;" & LF &
     --  (its phase: the disc is a ball, lit from where the sun is; the rest of
     --  it is all but dark)
     "    vec3 ball = mx * q.x + my * q.y - u_moon * sqrt(max(1.0 - dot(q, q), 0.0));" & LF &
     "    float lit = max(smoothstep(-0.08, 0.12, dot(ball, u_sun)), 0.035);" & LF &
     "    vec3 face = u_moon_col * (0.70 + 0.30 * smoothstep(0.40, 0.58, seas)) * (1.0 - 0.18 * dot(q, q)) * lit;" & LF &
     --  (by night its face stands in the sky's place; by day it is a pale
     --  thing in the blue: the sky made whiter by how bright the face is,
     --  never its own colour laid over the blue, which came out lilac)
     "    float mk = smoothstep(0.99955, 0.99975, m) * vis;" & LF &
     "    vec3 pale = c + (vec3(1.0) - c) * (dot(face, vec3(0.30, 0.59, 0.11)) * 0.55 * mk);" & LF &
     "    c = max(c, mix(mix(c, face, mk), pale, u_day));" & LF &
     "  }" & LF &
     "  return c;" & LF &
     "}" & LF &
     --  A cloud's underside as it is seen from the ground, with no walk
     --  through it: the flat layer's colour, and the water's mirror of it.
     "vec3 cloud_tone(vec3 d) {" & LF &
     "  float s = max(dot(d, u_sun), 0.0);" & LF &
     "  float m = max(dot(d, u_moon), 0.0);" & LF &
     "  return (u_sky_amb * 1.5 + u_sun_glow * (0.55 + 0.6 * pow(s, 4.0))"
     & " + u_moon_col * u_moon_k * (0.06 + 0.20 * pow(m, 6.0)))" & LF &
     "         * (1.0 - 0.45 * u_cover * u_cover);" & LF &
     "}" & LF &
     --  The sky with its clouds as one flat layer.  Sun_Vis scales the sun's
     --  and the moon's own light (glow and disc), for reflections of a sun
     --  that is shadowed where they are seen.
     "vec3 sky(vec3 d, float sun_vis) {" & LF &
     "  if (d.z <= 0.0) return haze(d);" & LF &
     "  vec3 c = orbs(sky_back(d) + glow(d) * sun_vis, d, sun_vis);" & LF &
     "  float t = (cloud_z - u_eye.z) / max(d.z, 0.02);" & LF &
     "  float k = cloud_at(u_eye.xy + d.xy * t) * (1.0 - smoothstep(6000.0, 14000.0, t));" & LF &
     "  return mix(c, cloud_tone(d), k * 0.92);" & LF &
     "}" & LF &
     "vec3 sky(vec3 d) { return sky(d, 1.0); }" & LF &
     --  (the same, with the weather's map read at a detail that is given: for
     --  a lookup inside a branch that not every pixel of a face takes, where
     --  the detail cannot be worked out from the pixels beside it)
     "vec3 sky_at(vec3 d, float sun_vis, float lod) {" & LF &
     "  if (d.z <= 0.0) return haze(d);" & LF &
     "  vec3 c = orbs(sky_back(d) + glow(d) * sun_vis, d, sun_vis);" & LF &
     "  float t = (cloud_z - u_eye.z) / max(d.z, 0.02);" & LF &
     "  vec2 p = u_eye.xy + d.xy * t + u_drift;" & LF &
     "  float n = 0.65 * textureLod(u_noise, p / 2000.0, lod).r + 0.35 * textureLod(u_noise, p.yx / 700.0 + 0.37, lod).r;" & LF &
     "  float a = clamp((n - (0.5 + 0.22 * (0.5 - u_cover)) + 0.04) / 0.14, 0.0, 1.0);" & LF &
     "  float k = a * a * (3.0 - 2.0 * a) * (1.0 - smoothstep(6000.0, 14000.0, t));" & LF &
     "  return mix(c, cloud_tone(d), k * 0.92);" & LF &
     "}" & LF &
     --  Mist (see the spec): a layer of it lying on the land, thickest at the
     --  land's own level thereabouts (so it pools in the hollows and over
     --  water, and a rise stands out of it) and thinning upward by half every
     --  few metres.  mist_through is how much of what is seen at P it leaves:
     --  the layer's thickness summed exactly along the line from the eye.
     "vec3 mist_colour(vec3 d) {" & LF &
     "  float l = length(d.xy);" & LF &
     "  vec3 h = (l > 1.0e-4) ? vec3(d.xy / l, 0.0) : vec3(1.0, 0.0, 0.0);" & LF &
     "  return u_mist_col + 0.6 * glow(h);" & LF &
     "}" & LF &
     "float mist_mean(float zp, float ze) {" & LF &            --  the mist's mean thickness between two heights over its floor
     "  const float H = " & GLSL (Float (Mist_Height_M)) & ";" & LF &
     "  zp = max(zp, 0.0); ze = max(ze, 0.0);" & LF &
     "  float dz = ze - zp;" & LF &
     "  return (abs(dz) > 0.05) ? H * (exp(-zp / H) - exp(-ze / H)) / dz : exp(-zp / H);" & LF &
     "}" & LF &
     --  (looked down on steeply it is drawn thinner than it is, by up to
     --  Mist_From_Above: the colony under it has to stay readable)
     "float mist_through(vec3 p) {" & LF &
     "  if (u_mist <= 0.0) return 1.0;" & LF &
     "  vec2 bd = textureLod(u_base, p.xy / 2048.0, 0.0).rg;" & LF &
     "  vec3 v = p - u_eye;" & LF &
     "  float l = length(v);" & LF &
     "  float steep = smoothstep(0.15, 0.55, -v.z / max(l, 0.01));" & LF &
     "  return exp(-u_mist * " & GLSL (Float (Mist_Thick)) & " * bd.g * l * (1.0 - " & GLSL (Float (Mist_From_Above)) & " * steep)"
     & " * mist_mean(p.z - bd.r, u_eye.z - bd.r));" & LF &
     "}" & LF &
     --  ... and of the sky in direction D: the layer looked up through from the eye
     "vec3 sky_mist(vec3 c, vec3 d) {" & LF &
     "  if (u_mist <= 0.0) return c;" & LF &
     "  vec2 bd = textureLod(u_base, u_eye.xy / 2048.0, 0.0).rg;" & LF &
     "  float ze = max(u_eye.z - bd.r, 0.0);" & LF &
     "  float od = u_mist * " & GLSL (Float (Mist_Thick)) & " * bd.g * exp(-ze / " & GLSL (Float (Mist_Height_M)) & ")" & LF &
     "             * ((d.z > 0.004) ? " & GLSL (Float (Mist_Height_M)) & " / d.z : 2000.0);" & LF &
     "  return mix(mist_colour(d), c, exp(-od));" & LF &
     "}" & LF &
     --  What the air does to colour C seen at point P: haze toward the edge
     --  of the loaded world, in the sky's own colour for that direction, so
     --  the ground meets the horizon; the weather's murk; and mist.  Thru is
     --  how much of the thing itself still shows.
     "vec3 air(vec3 c, vec3 p, out float thru) {" & LF &
     "  vec3 d = normalize(p - u_eye);" & LF &
     "  vec3 hz = haze(d);" & LF &
     --  (with the far land drawn beyond, the loaded land is not all haze at
     --  its edge: u_far.x of it, and the rest by u_far.y; with u_far.x 1 this
     --  is the one clamp it always was, to the bit)
     "  float gd = length(p.xy - u_focus.xy);" & LF &
     "  float fog = u_far.x * clamp((gd - 0.6 * u_fog_dist) / (0.4 * u_fog_dist), 0.0, 1.0)" & LF &
     "            + (1.0 - u_far.x) * clamp((gd - u_fog_dist) / (u_far.y - u_fog_dist), 0.0, 1.0);" & LF &
     "  float murk = 1.0 - exp(-length(p - u_eye) * u_vis);" & LF &
     "  c = mix(mix(c, hz, fog), hz, murk);" & LF &
     "  thru = (1.0 - fog) * (1.0 - murk);" & LF &
     --  (the ground haze: how deep under its top the point is, and how thick
     --  it lies that far from the focus; then the map's rim)
     "  if (u_ghaze.z > 0.0) {" & LF &
     "    float deep = textureLod(u_haze_top, p.xy / 2048.0, 0.0).r" & LF &
     "                 - max(p.z - textureLod(u_height, p.xy / 2048.0, 0.0).r - g_slack, 0.0);" & LF &
     "    if (deep > 0.0) {" & LF &
     --  (far from the focus and from under the eye alike: the ground one stands over is as clear as the ground one looks at)
     "      float hd = min(gd, length(p.xy - u_eye.xy));" & LF &
     "      float k = mix(u_ghaze.x, u_ghaze.y, smoothstep(" & GLSL (Float (Haze_From)) & " * u_fog_dist, "
     & GLSL (Float (Haze_Edge_At)) & " * u_fog_dist, hd))" & LF &
     "              + (u_ghaze.z - u_ghaze.y) * smoothstep(" & GLSL (Float (Haze_Edge_At)) & " * u_fog_dist, "
     & GLSL (Float (Haze_Far_At)) & " * u_fog_dist, hd);" & LF &
     "      float through = exp(-k * deep);" & LF &
     "      c = mix(hz, c, through);" & LF &
     "      thru *= through;" & LF &
     "    }" & LF &
     "  }" & LF &
     "  if (u_rim > 0.0) {" & LF &
     "    float open = smoothstep(0.0, u_rim, min(min(p.x, 2048.0 - p.x), min(p.y, 2048.0 - p.y)));" & LF &
     "    c = mix(hz, c, open);" & LF &
     "    thru *= open;" & LF &
     "  }" & LF &
     "  if (u_mist > 0.0) {" & LF &
     "    float mt = mist_through(p);" & LF &
     "    c = mix(mist_colour(d), c, mt);" & LF &
     "    thru *= mt;" & LF &
     "  }" & LF &
     "  return c;" & LF &
     "}" & LF &
     --  The final grade: a little more colour, a gentle contrast curve and
     --  a warm tint, the look of a painted diorama rather than a photo.
     "vec3 grade(vec3 c) {" & LF &
     "  c = clamp(c, 0.0, 1.0);" & LF &
     "  float l = dot(c, vec3(0.2126, 0.7152, 0.0722));" & LF &
     "  c = clamp(mix(vec3(l), c, 1.18), 0.0, 1.0);" & LF &
     "  c = mix(c, c * c * (3.0 - 2.0 * c), 0.35);" & LF &
     "  return c * vec3(1.03, 1.0, 0.95);" & LF &
     "}" & LF;

   --  The far land (see the spec): a grid of Castle.Far's cells, its
   --  corners' heights from a texture, six vertices a cell with no buffer.
   Far_Vertex_Source : constant String :=
     "#version 450 core" & LF &
     "layout(binding = 18) uniform sampler2D u_far_z;" & LF &
     "uniform mat4 u_viewproj;" & LF &
     "uniform vec3 u_camera;" & LF &
     "out vec3 v_world;" & LF &
     "const ivec2 corner[6] = ivec2[6](ivec2(0, 0), ivec2(1, 0), ivec2(1, 1), ivec2(0, 0), ivec2(1, 1), ivec2(0, 1));" & LF &
     "void main() {" & LF &
     "  int cell = gl_VertexID / 6;" & LF &
     "  ivec2 g = ivec2(cell % " & GLSL_Int (Castle.Far.Cells) & ", cell / " & GLSL_Int (Castle.Far.Cells)
     & ") + corner[gl_VertexID % 6];" & LF &
     "  v_world = vec3(vec2(g) * " & GLSL (Float (Castle.Far.Cell_M)) & ", texelFetch(u_far_z, g, 0).r);" & LF &
     "  gl_Position = u_viewproj * vec4(v_world - u_camera, 1.0);" & LF &
     "}" & LF;

   Far_Fragment_Head : constant String :=
     "#version 450 core" & LF &
     "in vec3 v_world;" & LF &
     "out vec4 o_color;" & LF &
     "layout(binding = 19) uniform sampler2D u_far_col;" & LF &      --  rgb: the ground; a: what the cell is (Castle.Far.Class)
     "layout(binding = 20) uniform sampler2D u_far_flag;" & LF &     --  a stack whose own mesh is loaded
     "uniform vec3 u_snow;" & LF &
     "uniform float u_ice;" & LF &
     "uniform float u_wet;" & LF &
     "uniform vec2 u_leaf;" & LF &
     "uniform float u_grass_dry;" & LF &
     "uniform vec3 u_crown[3];" & LF;          --  a broadleaf's, an aspen's and a conifer's crown

   Far_Fragment_Body : constant String :=
     "uint fhash(ivec2 p) {" & LF &
     "  uint h = uint(p.x) * 0x8da6b343u ^ uint(p.y) * 0xd8163841u;" & LF &
     "  h ^= h >> 16u; h *= 0x7feb352du; h ^= h >> 15u;" & LF &
     "  return h;" & LF &
     "}" & LF &
     "float snow_depth(float z) {" & LF &
     "  if (z <= 16.0) return u_snow.x;" & LF &
     "  if (z <= 70.0) return mix(u_snow.x, u_snow.y, (z - 16.0) / 54.0);" & LF &
     "  if (z <= 140.0) return mix(u_snow.y, u_snow.z, (z - 70.0) / 70.0);" & LF &
     "  return u_snow.z;" & LF &
     "}" & LF &
     "void main() {" & LF &
     "  ivec2 cell = clamp(ivec2(floor(v_world.xy / " & GLSL (Float (Castle.Far.Cell_M)) & ")), ivec2(0), ivec2("
     & GLSL_Int (Castle.Far.Cells - 1) & "));" & LF &
     "  vec4 t = texelFetch(u_far_col, cell, 0);" & LF &
     "  int code = int(t.a * 255.0 + 0.5);" & LF &
     "  int cls = code / " & GLSL_Int (Castle.Far.Class_Step) & ";" & LF &
     "  bool wet = (code % " & GLSL_Int (Castle.Far.Class_Step) & ") >= " & GLSL_Int (Castle.Far.Wet_Step) & ";" & LF &
     "  bool water = cls == 5;" & LF &
     "  bool crown = cls >= 2 && cls <= 4;" & LF &
     --  The sheet lies under the land as it was made (Castle.Far), so a
     --  stack's own mesh hides it and no hole is cut for one.  It is dropped
     --  where such a mesh is drawn (the loaded stacks whose nearest side is
     --  within the fog distance of the focus: Draw's own test, half a metre
     --  less here, so that where the two disagree by a hair both are drawn)
     --  only if the land there is no longer as it was made (the stack has
     --  been edited: a pit would show the sheet), or the cell stands at open
     --  water's level (the water's surface is drawn over its bed, and the
     --  sheet would lie between).
     "  ivec2 st = clamp(ivec2(floor(v_world.xy / 8.0)), ivec2(0), ivec2(" & GLSL_Int (Chunks_XY - 1) & "));" & LF &
     "  float flag = texelFetch(u_far_flag, st, 0).r;" & LF &      --  0: no mesh of its own; a half: one; 1: one, and edited
     "  if (flag > 0.25 && (wet || flag > 0.75)) {" & LF &
     "    vec2 lo = vec2(st) * 8.0;" & LF &
     "    vec2 g = max(vec2(0.0), max(lo - u_focus.xy, u_focus.xy - (lo + 8.0)));" & LF &
     "    float fd = max(u_fog_dist - 0.5, 0.0);" & LF &
     "    if (dot(g, g) < fd * fd) discard;" & LF &
     "  }" & LF &
     "  uint h = fhash(cell);" & LF &
     "  float r1 = float(h & 1023u) / 1023.0;" & LF &
     "  float r2 = float((h >> 10u) & 1023u) / 1023.0;" & LF &
     --  the lie of the land, from the map's height field (as the land's own
     --  far lighting goes by it); water lies flat
     "  vec2 hp = v_world.xy / 2048.0;" & LF &
     "  const float e = 2.0 / 2048.0;" & LF &
     "  float hx = texture(u_height, hp + vec2(e, 0.0)).r - texture(u_height, hp - vec2(e, 0.0)).r;" & LF &
     "  float hy = texture(u_height, hp + vec2(0.0, e)).r - texture(u_height, hp - vec2(0.0, e)).r;" & LF &
     "  vec3 n = water ? vec3(0.0, 0.0, 1.0) : normalize(vec3(-0.25 * hx, -0.25 * hy, 1.0));" & LF &
     --  (the ground's colour runs from one cell into the next; what a cell is does not)
     "  vec3 c = texture(u_far_col, v_world.xy / 2048.0).rgb;" & LF &
     "  float turfy = (cls == 1) ? 1.0 : 0.0;" & LF &
     --  A crown: its leaves' colour, a little its own tree's; a broadleaf's
     --  turns in autumn and then is gone, tree by tree, and the ground under
     --  it shows through its boughs.
     "  float bare = 0.0;" & LF &
     "  if (crown) {" & LF &
     "    vec3 k = u_crown[cls - 2] * (1.0 + 0.16 * (r1 - 0.5)) * vec3(1.0 + 0.10 * (r2 - 0.5), 1.0, 1.0 - 0.10 * (r2 - 0.5));" & LF &
     "    if (cls != 4) {" & LF &
     "      float tree = (cls == 3) ? 0.0 : r2;" & LF &
     "      vec3 autumn = (tree < 0.3) ? " & GLSL (Castle.Colors.Aged_Gold)
     & " : (tree < 0.6) ? " & GLSL (Castle.Colors.Warm_Copper) & LF &
     "                  : (tree < 0.85) ? " & GLSL (Castle.Colors.Brightened_Crimson)
     & " : " & GLSL (Castle.Colors.Warm_Umber) & ";" & LF &
     "      float l = clamp(dot(k, vec3(0.3, 0.59, 0.11)) / 0.3, 0.6, 1.4);" & LF &
     "      k = mix(k, autumn * l, u_leaf.x);" & LF &
     "      bare = clamp((u_leaf.y * 1.001 - 0.6 * r1) / 0.4, 0.0, 1.0);" & LF &
     "    }" & LF &
     --  (bare, its boughs stand over the ground: a little of their grey-brown)
     "    c = mix(k * " & GLSL (Float (Far_Crown)) & ", mix(c, " & GLSL (Castle.Colors.Warm_Umber) & ", 0.30), bare);" & LF &
     "    turfy = bare;" & LF &
     "  }" & LF &
     --  A meadow's drifts and its drying, as the land has them.
     "  if (turfy > 0.0) {" & LF &
     "    float d1 = texture(u_noise, v_world.xy / 53.0).r;" & LF &
     "    float d2 = texture(u_noise, v_world.yx / 137.0 + 0.41).r;" & LF &
     "    float tone = 1.0 + " & GLSL (Float (2.0 * Meadow_Tone)) & " * (0.65 * d1 + 0.35 * d2 - 0.5);" & LF &
     "    float sere = " & GLSL (Float (Meadow_Sere)) & " * smoothstep(0.5, 0.85, 0.5 + d2 - d1);" & LF &
     "    c = mix(c, c * tone * mix(vec3(1.0), vec3(1.16, 1.02, 0.70), sere), turfy);" & LF &
     "    if (u_grass_dry > 0.0) {" & LF &
     "      float l = dot(c, vec3(0.3, 0.59, 0.11));" & LF &
     "      c = mix(c, vec3(1.35, 1.12, 0.55) * l * 1.25, 0.85 * u_grass_dry * turfy);" & LF &
     "    }" & LF &
     "  }" & LF &
     "  vec3 amb = mix(u_gnd_amb, u_sky_amb, 0.5 + 0.5 * n.z);" & LF &
     "  float sun = max(dot(n, u_lamp), 0.0);" & LF &
     "  float lit = (sun > 0.0) ? cloud_shade(v_world) : 1.0;" & LF &
     "  vec3 light = amb + u_lamp_col * sun * lit;" & LF &
     --  Snow on what looks up at the sky; a crown holds less of it.
     "  float snow = water ? 0.0 : snow_depth(v_world.z);" & LF &
     "  float coat = 0.0;" & LF &
     "  if (snow > 0.0) {" & LF &
     "    float patchy = smoothstep(0.0, 0.05, snow * (0.5 + texture(u_noise, v_world.xy / 9.0).r));" & LF &
     "    coat = smoothstep(0.55, 0.9, n.z) * patchy * (crown ? mix(0.45, 0.70, bare) : 1.0);" & LF &
     "    c = mix(c, vec3(0.92, 0.94, 0.98), coat);" & LF &
     "  }" & LF &
     "  c *= 1.0 - " & GLSL (Float (Wet_Dark)) & " * u_wet * (1.0 - coat);" & LF &
     "  vec3 col = c * light;" & LF &
     --  Open water: its hue, the sky in it (more the flatter it is seen), and ice.
     "  if (water) {" & LF &
     "    vec3 v = normalize(u_eye - v_world);" & LF &
     "    float fres = pow(1.0 - max(v.z, 0.0), 3.0);" & LF &
     "    col = mix(" & GLSL (Castle.Colors.Storm_Blue) & ", " & GLSL (Castle.Colors.Royal_Indigo) & ", 0.5) * light;" & LF &
     "    col = mix(col, sky_at(reflect(-v, n), lit, 0.0), mix(" & GLSL (Float (Far_Mirror)) & ", 0.9, fres));" & LF &
     "    if (u_ice > 0.0) {" & LF &
     "      float ice = smoothstep(0.0, 0.15, u_ice * 1.6 - 0.6 * texture(u_noise, v_world.xy / 23.0).r);" & LF &
     "      col = mix(col, mix(vec3(0.74, 0.84, 0.92), vec3(0.92, 0.94, 0.98)," & LF &
     "                         ice * smoothstep(0.0, 0.05, snow_depth(v_world.z))) * light, ice);" & LF &
     "    }" & LF &
     "  }" & LF &
     "  float thru;" & LF &
     "  col = air(col, v_world, thru);" & LF &
     --  (the world ends: toward the map's edge the sheet goes into the haze,
     --  so that its end is not a straight line against the sky)
     "  float rim = min(min(v_world.x, 2048.0 - v_world.x), min(v_world.y, 2048.0 - v_world.y));" & LF &
     "  col = mix(haze(normalize(v_world - u_eye)), col, smoothstep(0.0, " & GLSL (Float (Far_Rim_M)) & ", rim));" & LF &
     "  o_color = vec4(grade(col), 1.0);" & LF &
     "}" & LF;

   --  Broadleaf leaves fall tree by tree: a 3 m patch (roughly one crown)
   --  sets most of a block's turn, the block itself the rest.  The world and
   --  the shadow and snow maps use the same rule, so bare trees cast bare
   --  shadows.
   Leaf_Source : constant String :=
     "uniform vec2 u_leaf;" & LF &              --  autumn colour, share fallen
     "uniform uvec2 u_broadleaf;" & LF &
     --  A set of materials is a 64-bit mask (two words): bit k is material k.
     "bool in_set(uvec2 m, uint k) {" & LF &
     "  return (((k < 32u) ? (m.x >> k) : (m.y >> (k - 32u))) & 1u) != 0u;" & LF &
     "}" & LF &
     "bool leaf_gone(ivec3 b, uint mat) {" & LF &
     "  if (!in_set(u_broadleaf, mat) || u_leaf.y <= 0.0) return false;" & LF &
     "  float tree = float(hash3(b / 12) & 1023u) / 1023.0;" & LF &
     "  float leaf = float(hash3(b) & 1023u) / 1023.0;" & LF &
     "  return 0.6 * tree + 0.4 * leaf < u_leaf.y * 1.001;" & LF &
     "}" & LF;

   --  The sun's depth map.  Grass and grain cast no shadow (it would only
   --  speckle the meadows); a quarter of the leaf blocks let light through,
   --  so a canopy throws dappled shade.  No colour is written.
   Shadow_Fragment_Source : constant String :=
     "#version 450 core" & LF &
     "in vec3 v_grid;" & LF &
     "flat in uint v_mat;" & LF &
     "flat in int v_face;" & LF &
     "uniform uvec2 u_plants;" & LF &
     "uniform uvec2 u_leaves;" & LF &
     "const vec3 normals[6] = vec3[6](vec3(1,0,0), vec3(-1,0,0), vec3(0,1,0)," &
     " vec3(0,-1,0), vec3(0,0,1), vec3(0,0,-1));" & LF &
     "uint hash3(ivec3 p) {" & LF &
     "  uint h = uint(p.x) * 0x8da6b343u ^ uint(p.y) * 0xd8163841u ^ uint(p.z) * 0xcb1ab31fu;" & LF &
     "  h ^= h >> 16u; h *= 0x7feb352du; h ^= h >> 15u;" & LF &
     "  return h;" & LF &
     "}" & LF &
     Leaf_Source &
     "void main() {" & LF &
     "  if (in_set(u_plants, v_mat)) discard;" & LF &
     "  if (leaf_gone(ivec3(floor(v_grid * 4.0 - normals[v_face] * 0.01)), v_mat)) discard;" & LF &
     "  if (in_set(u_leaves, v_mat)" & LF &
     "      && (hash3(ivec3(floor(v_grid * 4.0 - normals[v_face] * 0.01))) & 3u) == 0u) discard;" & LF &
     "}" & LF;

   --  Whether point P is open to the sky: the snow map looks straight down
   --  over everything loaded, so a point under a roof or a canopy is not.
   --  Four filtered lookups give soft edges under trees.
   Open_Source : constant String :=
     "layout(binding = 4) uniform sampler2DShadow u_snow_map;" & LF &
     "uniform mat4 u_snow_vp;" & LF &
     "float open_at(vec3 p) {" & LF &
     "  vec3 s = (u_snow_vp * vec4(p, 1.0)).xyz * 0.5 + 0.5;" & LF &
     "  if (s.x <= 0.0 || s.y <= 0.0 || s.x >= 1.0 || s.y >= 1.0) return 1.0;" & LF &
     "  float t = 1.0 / float(textureSize(u_snow_map, 0).x);" & LF &
     "  return 0.25 * (texture(u_snow_map, vec3(s.xy + vec2(-0.5, -0.5) * t, s.z))" & LF &
     "               + texture(u_snow_map, vec3(s.xy + vec2( 0.5, -0.5) * t, s.z))" & LF &
     "               + texture(u_snow_map, vec3(s.xy + vec2(-0.5,  0.5) * t, s.z))" & LF &
     "               + texture(u_snow_map, vec3(s.xy + vec2( 0.5,  0.5) * t, s.z)));" & LF &
     "}" & LF &
     "float sky_open(vec3 p) { return open_at(p + vec3(0.0, 0.0, 0.15)); }" & LF &
     --  (one lookup: for what needs no soft edge)
     "float open_1(vec3 p) {" & LF &
     "  vec3 s = (u_snow_vp * vec4(p, 1.0)).xyz * 0.5 + 0.5;" & LF &
     "  if (s.x <= 0.0 || s.y <= 0.0 || s.x >= 1.0 || s.y >= 1.0) return 1.0;" & LF &
     "  return texture(u_snow_map, s);" & LF &
     "}" & LF;

   --  Rain and snow: particles in a box in front of the camera, made from
   --  the vertex number alone (no buffers).  Each falls and drifts with the
   --  wind and wraps round the box, so the box can follow the camera while
   --  every drop keeps its place in the world.  Drops under a roof or a
   --  canopy are not drawn.
   Precip_Vertex_Source : constant String :=
     "#version 450 core" & LF &
     "uniform mat4 u_viewproj;" & LF &
     "uniform vec3 u_camera;" & LF &
     "uniform vec3 u_centre;" & LF &
     "uniform float u_box;" & LF &
     "uniform float u_time;" & LF &
     "uniform vec3 u_fall;" & LF &
     "uniform int u_kind;" & LF &
     "uniform vec3 u_right;" & LF &
     "uniform vec3 u_up;" & LF &
     "out vec2 v_uv;" & LF &
     "out vec3 v_pos;" & LF &
     "out float v_fade;" & LF &
     "uint mixu(uint x) { x ^= x >> 16u; x *= 0x7feb352du; x ^= x >> 15u; x *= 0x846ca68bu; x ^= x >> 16u; return x; }" & LF &
     "const vec2 corner[6] = vec2[6](vec2(-1,-1), vec2(1,-1), vec2(1,1), vec2(-1,-1), vec2(1,1), vec2(-1,1));" & LF &
     "void main() {" & LF &
     "  uint id = uint(gl_VertexID / 6);" & LF &
     "  vec2 k = corner[gl_VertexID % 6];" & LF &
     "  vec3 r = vec3(mixu(id * 3u), mixu(id * 3u + 1u), mixu(id * 3u + 2u)) / 4294967295.0;" & LF &
     "  vec3 p = r * u_box + u_fall * u_time;" & LF &
     "  if (u_kind == 1) p.xy += 0.35 * vec2(sin(u_time * 1.7 + r.x * 40.0), cos(u_time * 1.3 + r.y * 40.0));" & LF &
     "  p = u_centre + mod(p - u_centre + 0.5 * u_box, u_box) - 0.5 * u_box;" & LF &
     "  vec3 ax; vec3 ay;" & LF &
     "  if (u_kind == 1) { ax = u_right * 0.035; ay = u_up * 0.035; }" & LF &
     "  else { ay = normalize(u_fall) * 0.45; ax = normalize(cross(ay, u_camera - p)) * 0.008; }" & LF &
     "  v_uv = k;" & LF &
     "  v_pos = p;" & LF &
     "  v_fade = 1.0 - smoothstep(0.3, 0.5, length(p - u_centre) / u_box);" & LF &
     "  gl_Position = u_viewproj * vec4(p + ax * k.x + ay * k.y - u_camera, 1.0);" & LF &
     "}" & LF;

   Precip_Fragment_Source : constant String :=
     "#version 450 core" & LF &
     "in vec2 v_uv;" & LF &
     "in vec3 v_pos;" & LF &
     "in float v_fade;" & LF &
     "uniform int u_kind;" & LF &
     "uniform vec3 u_tint;" & LF &
     "out vec4 o_color;" & LF &
     Open_Source &
     "void main() {" & LF &
     "  float a = (u_kind == 1) ? 1.0 - smoothstep(0.3, 1.0, length(v_uv)) : (1.0 - abs(v_uv.x)) * 0.5;" & LF &
     "  if (a <= 0.01 || sky_open(v_pos) < 0.5) discard;" & LF &
     "  o_color = vec4(u_tint * ((u_kind == 1) ? 1.0 : 0.85), a * v_fade * ((u_kind == 1) ? 0.9 : 0.45));" & LF &
     "}" & LF;

   --  The edit outline: the twelve edges of a box, from the vertex number.
   Box_Vertex_Source : constant String :=
     "#version 450 core" & LF &
     "uniform mat4 u_viewproj;" & LF &
     "uniform vec3 u_camera;" & LF &
     "uniform vec3 u_lo;" & LF &
     "uniform vec3 u_hi;" & LF &
     "const int ends[24] = int[24](0,1, 2,3, 4,5, 6,7, 0,2, 1,3, 4,6, 5,7, 0,4, 1,5, 2,6, 3,7);" & LF &
     "void main() {" & LF &
     "  int c = ends[gl_VertexID];" & LF &
     "  vec3 p = mix(u_lo, u_hi, vec3(float(c & 1), float((c >> 1) & 1), float((c >> 2) & 1)));" & LF &
     "  gl_Position = u_viewproj * vec4(p - u_camera, 1.0);" & LF &
     "}" & LF;

   Box_Fragment_Source : constant String :=
     "#version 450 core" & LF &
     "out vec4 o_color;" & LF &
     "void main() { o_color = vec4(1.0, 0.95, 0.55, 1.0); }" & LF;

   --  The sky pass: one triangle over the screen at the far plane, drawn
   --  after the solid world so only the pixels it left empty are shaded.
   Sky_Vertex_Source : constant String :=
     "#version 450 core" & LF &
     "out vec2 v_ndc;" & LF &
     "void main() {" & LF &
     "  vec2 p = vec2((gl_VertexID << 1) & 2, gl_VertexID & 2) * 2.0 - 1.0;" & LF &
     "  v_ndc = p;" & LF &
     "  gl_Position = vec4(p, 1.0, 1.0);" & LF &
     "}" & LF;

   --  The clouds walked through (see the spec): only the sky pass has this.
   --  cloud_dens is how much cloud is at a point of the slab, 0 to 1: where
   --  the weather's map says a cloud stands, flat underneath and as tall as
   --  the place is deep into the map, its edges bitten into billows by the
   --  noise in three dimensions (Fine; the looks toward the light go
   --  without, and are the smoother for it).  clouds walks a ray of the sky
   --  through the slab and gives the light the clouds send down it and how
   --  much of what is behind them still shows.  Each stride starts a little
   --  further on or back by the pixel it is for, always the same for that
   --  pixel, so the strides do not show as rings and a still view is still.
   Cloud_Source : constant String :=
     "layout(binding = 14) uniform sampler3D u_puff;" & LF &
     "const float c_lo = " & GLSL (Float (Cloud_Lo_M)) & ";" & LF &
     "const float c_hi = " & GLSL (Float (Cloud_Hi_M)) & ";" & LF &
     --  how deep into a cloud the place is on the weather's map (cloud_deep, at a given detail)
     "float cloud_map(vec2 p, float lod) {" & LF &
     "  vec2 q = p + u_drift;" & LF &
     --  (without the map's finest detail: a cloud's body is the map stood on
     --  end, and every wrinkle of it would be a pleat down the cloud's side)
     "  float n = 0.65 * textureLod(u_noise, q / 2000.0, max(lod, 2.5)).r"
     & " + 0.35 * textureLod(u_noise, q.yx / 700.0 + 0.37, max(lod, 3.5)).r;" & LF &
     "  return (n - (0.5 + 0.22 * (0.5 - u_cover)) + 0.04) / 0.14 - 0.12;" & LF &
     "}" & LF &
     --  the cloud's body there, before the billows: flat underneath, as tall as it is deep
     "float cloud_body(float a, float h) {" & LF &
     "  if (a <= 0.0 || h <= 0.0 || h >= 1.0) return 0.0;" & LF &
     "  float top = 0.56 * sqrt(min(a, 2.0));" & LF &                       --  how tall it stands here, of the slab: a dome
     "  return smoothstep(0.0, 0.07, h) * (1.0 - smoothstep(0.45 * top, top, h)) * smoothstep(0.0, 0.35, a);" & LF &
     "}" & LF &
     "float cloud_dens(vec3 p, float lod, bool fine) {" & LF &
     "  float h = (p.z - c_lo) / (c_hi - c_lo);" & LF &
     "  if (h <= 0.0 || h >= 1.0) return 0.0;" & LF &
     "  float d = cloud_body(cloud_map(p.xy, lod), h);" & LF &
     "  if (!fine || d <= 0.0) return d;" & LF &
     "  vec3 w = vec3(p.xy + u_drift * 1.35, p.z);" & LF &
     "  float big = textureLod(u_puff, w / 640.0, lod).r;" & LF &
     "  float small = textureLod(u_puff, w / 190.0 + 0.5, lod).r;" & LF &
     "  d = clamp((d - 0.62 * (1.0 - big)) / (1.0 - 0.62 * (1.0 - big)), 0.0, 1.0);" & LF &
     "  return clamp((d - 0.28 * (1.0 - small)) / (1.0 - 0.28 * (1.0 - small)), 0.0, 1.0);" & LF &
     "}" & LF &
     --  The walk.  Through clear air it strides by how far the map says the
     --  nearest cloud is (never more than Cloud_Stride_M); in and near a cloud
     --  it goes in short steps that lengthen with the distance, since a cloud
     --  that stops the light within one long stride is drawn in rings.
     "vec4 clouds(vec3 d) {" & LF &
     "  float t0 = (c_lo - u_eye.z) / d.z;" & LF &
     "  float t1 = min((c_hi - u_eye.z) / d.z, " & GLSL (Float (Cloud_Far_M)) & ");" & LF &
     "  if (t1 <= t0) return vec4(0.0, 0.0, 0.0, 1.0);" & LF &
     "  float s = dot(d, u_orb);" & LF &
     --  (light sent on toward the eye from behind a cloud, and a little back from before it)
     "  float phase = 0.55 + 0.9 * pow(max(s, 0.0), 8.0) + 0.25 * max(-s, 0.0);" & LF &
     "  vec3 far_col = haze(d);" & LF &
     "  vec3 sum = vec3(0.0);" & LF &
     "  float tr = 1.0;" & LF &
     "  ivec2 px = ivec2(gl_FragCoord.xy) & 3;" & LF &
     "  const float bayer[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);" & LF &
     "  float jit = bayer[px.y * 4 + px.x] / 16.0;" & LF &
     "  float t = t0 + jit * clamp(t0 * " & GLSL (Float (Cloud_Step)) & ", " & GLSL (Float (Cloud_Step_Min_M)) & ", "
     & GLSL (Float (Cloud_Step_Max_M)) & ");" & LF &
     "  for (int i = 0; i < " & GLSL_Int (Cloud_Steps) & "; i++) {" & LF &
     "    if (t >= t1) break;" & LF &
     "    vec3 p = u_eye + d * t;" & LF &
     "    float fine = clamp(t * " & GLSL (Float (Cloud_Step)) & ", " & GLSL (Float (Cloud_Step_Min_M)) & ", "
     & GLSL (Float (Cloud_Step_Max_M)) & ");" & LF &
     "    float lod = clamp(log2(fine / 16.0), 0.0, 4.0);" & LF &
     "    float a = cloud_map(p.xy, lod);" & LF &
     "    if (a <= -0.25) {" & LF &
     "      t += clamp(-a * 70.0, fine, " & GLSL (Float (Cloud_Stride_M)) & ");" & LF &
     "      continue;" & LF &
     "    }" & LF &
     "    float h = (p.z - c_lo) / (c_hi - c_lo);" & LF &
     "    float dn = cloud_body(a, h);" & LF &
     "    if (dn > 0.0) {" & LF &
     "      vec3 w = vec3(p.xy + u_drift * 1.35, p.z);" & LF &
     "      float big = textureLod(u_puff, w / 640.0, lod).r;" & LF &
     "      float small = textureLod(u_puff, w / 190.0 + 0.5, lod).r;" & LF &
     "      dn = clamp((dn - 0.62 * (1.0 - big)) / (1.0 - 0.62 * (1.0 - big)), 0.0, 1.0);" & LF &
     "      dn = clamp((dn - 0.28 * (1.0 - small)) / (1.0 - 0.28 * (1.0 - small)), 0.0, 1.0);" & LF &
     "    }" & LF &
     "    if (dn > 0.002) {" & LF &
     "      float in_way = 30.0 * cloud_dens(p + u_orb * 30.0, lod, false)" & LF &
     "                   + 70.0 * cloud_dens(p + u_orb * 95.0, lod, false)" & LF &
     "                   + 150.0 * cloud_dens(p + u_orb * 230.0, lod, false);" & LF &
     "      float od = " & GLSL (Float (Cloud_Thick)) & " * in_way;" & LF &
     "      vec3 lit = u_orb_col * phase * (exp(-od) + 0.45 * exp(-0.22 * od))" & LF &
     "               + u_sky_amb * (0.55 + 0.75 * h) + u_gnd_amb * (0.6 * (1.0 - h));" & LF &
     "      float fade = exp(-t / " & GLSL (Float (Cloud_Far_M / 3.0)) & ");" & LF &
     "      float k = (1.0 - exp(-" & GLSL (Float (Cloud_Thick)) & " * dn * fine))" & LF &
     "              * (1.0 - smoothstep(" & GLSL (Float (0.7 * Cloud_Far_M)) & ", " & GLSL (Float (Cloud_Far_M)) & ", t));" & LF &
     "      sum += tr * k * mix(far_col, lit, fade);" & LF &
     "      tr *= 1.0 - k;" & LF &
     "      if (tr < 0.02) { tr = 0.0; break; }" & LF &
     "    }" & LF &
     "    t += fine;" & LF &
     "  }" & LF &
     "  return vec4(sum, tr);" & LF &
     "}" & LF;

   --  The clouds' own pass: the walk, for every pixel of a picture half the
   --  window's size each way (a cloud has no edge a pixel sharp, and a
   --  quarter of the pixels is a quarter of the walks).  The light they send
   --  down each ray, and how much of the sky behind them still shows.
   Cloud_Fragment_Source : constant String :=
     "#version 450 core" & LF &
     "in vec2 v_ndc;" & LF &
     "uniform vec3 u_fwd;" & LF &
     "uniform vec3 u_right;" & LF &
     "uniform vec3 u_up;" & LF &
     "out vec4 o_color;" & LF &
     Sky_Source &
     Cloud_Source &
     "void main() {" & LF &
     "  vec3 d = normalize(u_fwd + v_ndc.x * u_right + v_ndc.y * u_up);" & LF &
     "  o_color = (d.z <= 0.004) ? vec4(0.0, 0.0, 0.0, 1.0) : clouds(d);" & LF &
     "}" & LF;

   --  The sky: the gradient, the sun and the moon, and the clouds over them:
   --  walked through (their picture, each pixel the mean of the nine round
   --  it, which is also what evens out the strides' starts) or as the flat
   --  layer.
   Sky_Fragment_Source : constant String :=
     "#version 450 core" & LF &
     "in vec2 v_ndc;" & LF &
     "uniform vec3 u_fwd;" & LF &
     "uniform vec3 u_right;" & LF &
     "uniform vec3 u_up;" & LF &
     "uniform int u_vol;" & LF &
     "uniform vec2 u_px;" & LF &               --  one pixel of the window, of the whole picture
     "uniform float u_stars;" & LF &           --  how much the stars show (none by day)
     "uniform vec2 u_star_turn;" & LF &        --  how far the sky has turned about the pole (cosine, sine)
     "uniform float u_floor;" & LF &           --  1: under the land a floor (see the spec, Ground_Floor)
     "uniform int u_drop;" & LF &              --  1: the sun and the moon go down behind the map's edge (see the spec, Low_Horizon)
     "layout(binding = 15) uniform sampler2D u_clouds;" & LF &
     "out vec4 o_color;" & LF &
     Sky_Source &
     --  The stars (see the spec): only this pass draws them.  The sky is
     --  six faces of a cube that turns about the pole with the clock, each
     --  ruled into Star_Cells squares, and a square has at most one star,
     --  placed and made bright by a hash of the square: so a star is where
     --  it was last night.  Each is a soft dot a pixel or two across.
     "uint star_hash(uvec3 p) {" & LF &
     "  uint h = p.x * 0x8da6b343u ^ p.y * 0xd8163841u ^ p.z * 0xcb1ab31fu;" & LF &
     "  h ^= h >> 16u; h *= 0x7feb352du; h ^= h >> 15u; h *= 0x846ca68bu; h ^= h >> 16u;" & LF &
     "  return h;" & LF &
     "}" & LF &
     "vec3 stars(vec3 d) {" & LF &
     "  const vec3 pole = vec3(0.0, 0.682, 0.731);" & LF &
     "  vec3 e = d * u_star_turn.x + cross(pole, d) * u_star_turn.y + pole * dot(pole, d) * (1.0 - u_star_turn.x);" & LF &
     "  vec3 a = abs(e);" & LF &
     "  int face; vec2 uv;" & LF &
     "  if (a.x >= a.y && a.x >= a.z) { face = e.x > 0.0 ? 0 : 1; uv = e.yz / a.x; }" & LF &
     "  else if (a.y >= a.z)         { face = e.y > 0.0 ? 2 : 3; uv = e.xz / a.y; }" & LF &
     "  else                         { face = e.z > 0.0 ? 4 : 5; uv = e.xy / a.z; }" & LF &
     "  const float n = " & GLSL (Float (Star_Cells)) & ";" & LF &
     "  vec2 g = (uv * 0.5 + 0.5) * n;" & LF &
     "  ivec2 c = clamp(ivec2(floor(g)), ivec2(0), ivec2(int(n) - 1));" & LF &
     "  uint h = star_hash(uvec3(uint(c.x), uint(c.y), uint(face)));" & LF &
     "  float bright = float(h & 1023u) / 1023.0;" & LF &
     "  if (bright > " & GLSL (Float (Star_Share)) & ") return vec3(0.0);" & LF &
     "  bright = pow(1.0 - bright / " & GLSL (Float (Star_Share)) & ", 5.0);" & LF &     --  few bright, many faint
     "  vec2 at = (vec2(c) + 0.22 + 0.56 * vec2(float((h >> 10u) & 1023u), float((h >> 20u) & 1023u)) / 1023.0) / n * 2.0 - 1.0;" & LF &
     "  float sg = ((face & 1) == 0) ? 1.0 : -1.0;" & LF &
     "  vec3 sd = (face < 2) ? vec3(sg, at.x, at.y) : (face < 4) ? vec3(at.x, sg, at.y) : vec3(at.x, at.y, sg);" & LF &
     "  float off = length(normalize(sd) - e);" & LF &                         --  radians, near enough
     "  float r = " & GLSL (Float (Star_Size)) & " * (0.75 + 0.6 * bright);" & LF &
     "  float dot_ = 1.0 - smoothstep(0.35 * r, r, off);" & LF &
     "  vec3 tint = mix(vec3(1.0, 0.86, 0.72), vec3(0.78, 0.86, 1.0), float((h >> 5u) & 31u) / 31.0);" & LF &
     "  return tint * dot_ * (0.10 + 0.90 * bright) * u_stars * smoothstep(0.0, 0.22, d.z);" & LF &
     "}" & LF &
     --  (Low_Horizon) How far under eye level the map's edge lies, seen
     --  along D: the sine of it near enough, from the land's height where
     --  the line leaves the map, less Horizon_Under_M; none where the line
     --  does not cross the map or that is not under the eye.
     "float edge_under(vec3 d) {" & LF &
     "  float l = length(d.xy);" & LF &
     "  if (l < 1.0e-4) return 0.0;" & LF &
     "  vec2 h = d.xy / l;" & LF &
     "  vec2 inv = 1.0 / vec2(abs(h.x) > 1.0e-5 ? h.x : 1.0e-5, abs(h.y) > 1.0e-5 ? h.y : 1.0e-5);" & LF &
     "  vec2 ta = (vec2(0.0) - u_eye.xy) * inv, tb = (vec2(2048.0) - u_eye.xy) * inv;" & LF &
     "  float t0 = max(max(min(ta.x, tb.x), min(ta.y, tb.y)), 0.0);" & LF &
     "  float t1 = min(max(ta.x, tb.x), max(ta.y, tb.y));" & LF &
     "  if (t1 <= t0) return 0.0;" & LF &
     "  vec2 e = clamp(u_eye.xy + h * t1, vec2(0.5), vec2(2047.5));" & LF &
     "  float under = u_eye.z - textureLod(u_height, e / 2048.0, 0.0).r + " & GLSL (Float (Horizon_Under_M)) & ";" & LF &
     "  return (under > 0.0) ? under / length(vec2(under, t1)) : 0.0;" & LF &
     "}" & LF &
     "void main() {" & LF &
     "  vec3 d = normalize(u_fwd + v_ndc.x * u_right + v_ndc.y * u_up);" & LF &
     "  vec3 c;" & LF &
     "  bool floored = false;" & LF &
     "  if (d.z <= 0.004) {" & LF &
     "    c = haze(d);" & LF &
     --  (the floor under the land: the line of sight walked across the map
     --  in even strides until it is under the land's level thereabouts, less
     --  Floor_Under_M, and the place found between the last two; a line that
     --  leaves the map over the land is the sky's)
     "    if (u_floor > 0.0 && d.z < -0.001) {" & LF &
     "      vec2 inv = 1.0 / vec2(abs(d.x) > 1.0e-5 ? d.x : 1.0e-5, abs(d.y) > 1.0e-5 ? d.y : 1.0e-5);" & LF &
     "      vec2 ta = (vec2(0.0) - u_eye.xy) * inv, tb = (vec2(2048.0) - u_eye.xy) * inv;" & LF &
     "      float t0 = max(max(min(ta.x, tb.x), min(ta.y, tb.y)), 0.0);" & LF &
     "      float t1 = min(min(max(ta.x, tb.x), max(ta.y, tb.y)), -u_eye.z / d.z);" & LF &
     "      if (t1 > t0) {" & LF &
     "        const int steps = 24;" & LF &
     "        float dt = (t1 - t0) / float(steps), over0 = 1.0, tl = t0;" & LF &
     "        for (int i = 0; i <= steps; i++) {" & LF &
     "          float t = t0 + dt * float(i);" & LF &
     "          vec3 q = u_eye + d * t;" & LF &
     "          float over = q.z - (textureLod(u_base, q.xy / 2048.0, 0.0).r - " & GLSL (Float (Floor_Under_M)) & ");" & LF &
     "          if (over <= 0.0) {" & LF &
     "            float th = (i == 0) ? t : mix(tl, t, over0 / max(over0 - over, 1.0e-4));" & LF &
     "            float thru;" & LF &
     "            c = air(" & GLSL (Castle.Colors.Charcoal) & " * (u_sky_amb + u_gnd_amb + 0.5 * u_lamp_col), u_eye + d * th, thru);" & LF &
     "            floored = true;" & LF &
     "            break;" & LF &
     "          }" & LF &
     "          over0 = over; tl = t;" & LF &
     "        }" & LF &
     "      }" & LF &
     "    }" & LF &
     --  (Low_Horizon: under eye level the sky is the haze as ever, but the
     --  sun and the moon are drawn on it down to the map's edge, fading
     --  out by the last Sun_Gone under eye level, as the sun's light on
     --  the land does: so they go down behind the land, or into the haze
     --  over it, and never at a line of their own above it)
     "    if (!floored && u_drop == 1 && d.z > " & GLSL (Float (Sun_Gone)) & ") {" & LF &
     "      if (d.z > -edge_under(d)) c = orbs(c, d, smoothstep(" & GLSL (Float (Sun_Gone)) & ", 0.0, d.z));" & LF &
     "    }" & LF &
     "  } else {" & LF &
     "    vec3 back = sky_back(d) + glow(d);" & LF &
     "    if (u_stars > 0.0) back += stars(d);" & LF &
     "    back = orbs(back, d, 1.0);" & LF &
     "    if (u_vol == 1) {" & LF &
     "      vec2 uv = gl_FragCoord.xy * u_px;" & LF &
     "      vec4 cl = 0.25 * (texture(u_clouds, uv + vec2(-u_px.x, -u_px.y)) + texture(u_clouds, uv + vec2(u_px.x, -u_px.y))" & LF &
     "                      + texture(u_clouds, uv + vec2(-u_px.x, u_px.y)) + texture(u_clouds, uv + u_px));" & LF &
     "      c = back * cl.a + cl.rgb;" & LF &
     "    } else {" & LF &
     --  (the flat layer, as sky() has it, with the stars behind it)
     "      float t = (cloud_z - u_eye.z) / max(d.z, 0.02);" & LF &
     "      float k = cloud_at(u_eye.xy + d.xy * t) * (1.0 - smoothstep(6000.0, 14000.0, t));" & LF &
     "      c = mix(back, cloud_tone(d), k * 0.92);" & LF &
     "    }" & LF &
     "  }" & LF &
     "  o_color = vec4(grade(floored ? c : sky_mist(c, d)), 1.0);" & LF &
     "}" & LF;

   --  Share of sunlight reaching point P on a face with normal N.  There
   --  are four depth maps: the land's and the figures', each drawn for the
   --  two held directions of the sun (see the spec); a point is lit by a
   --  direction if both its maps say so, and the answer is the two
   --  directions' mixed by how far the sun is from the one to the other.
   --  Each lookup is nine filtered taps a texel apart (a soft edge four
   --  texels wide), from a point pushed out along the normal by a texel and
   --  a half of that map so faces don't shadow themselves.  Outside a map:
   --  full sun; the figures' map fades out toward its edge.
   Sunlit_Source : constant String :=
     "layout(binding = 2) uniform sampler2DShadow u_shadow;" & LF &
     "layout(binding = 7) uniform sampler2DShadow u_shadow_b;" & LF &
     "layout(binding = 11) uniform sampler2DShadow u_figsh;" & LF &
     "layout(binding = 12) uniform sampler2DShadow u_figsh_b;" & LF &
     "uniform mat4 u_light_vp;" & LF &
     "uniform mat4 u_light_vp_b;" & LF &
     "uniform mat4 u_fig_vp;" & LF &
     "uniform mat4 u_fig_vp_b;" & LF &
     "uniform float u_shadow_texel;" & LF &      --  metres; 0: no shadows
     "uniform float u_fig_texel;" & LF &
     "uniform float u_shadow_mix;" & LF &
     --  The far maps (see the spec, Far_Shadows): four filtered taps each.
     --  (Every tap of a depth map here is at a given detail, the maps having
     --  one: they are read inside branches that not every pixel takes.)
     "layout(binding = 22) uniform sampler2DShadow u_farsh;" & LF &
     "layout(binding = 23) uniform sampler2DShadow u_farsh_b;" & LF &
     "uniform mat4 u_farl_vp;" & LF &
     "uniform mat4 u_farl_vp_b;" & LF &
     "uniform vec2 u_far_sh;" & LF &            --  from the focus: where the far maps begin to take over, and where they have (0: there are none)
     "uniform vec2 u_far_sh2;" & LF &           --  their bias, of their depth; a texel of theirs in metres
     "float lit_far(sampler2DShadow m, mat4 vp, vec3 p) {" & LF &
     "  vec3 s = (vp * vec4(p, 1.0)).xyz * 0.5 + 0.5;" & LF &
     "  if (s.x <= 0.0 || s.y <= 0.0 || s.x >= 1.0 || s.y >= 1.0 || s.z >= 1.0) return 1.0;" & LF &
     --  (four filtered taps three quarters of a texel out: an edge three
     --  texels wide, 2 m, so that the two held maps, whose texels do not lie
     --  alike on the ground, go over into each other without the edge creeping)
     "  float t = 0.75 / float(textureSize(m, 0).x);" & LF &
     "  float z = s.z - u_far_sh2.x;" & LF &
     "  return 0.25 * (textureLod(m, vec3(s.xy + vec2(-t, -t), z), 0.0) + textureLod(m, vec3(s.xy + vec2(t, -t), z), 0.0)" & LF &
     "               + textureLod(m, vec3(s.xy + vec2(-t, t), z), 0.0) + textureLod(m, vec3(s.xy + vec2(t, t), z), 0.0));" & LF &
     "}" & LF &
     "float lit_in(sampler2DShadow m, mat4 vp, vec3 p, float fade) {" & LF &
     "  vec3 s = (vp * vec4(p, 1.0)).xyz * 0.5 + 0.5;" & LF &
     "  if (s.x <= 0.0 || s.y <= 0.0 || s.x >= 1.0 || s.y >= 1.0 || s.z >= 1.0) return 1.0;" & LF &
     "  float t = 1.0 / float(textureSize(m, 0).x);" & LF &
     "  float sum = 0.0;" & LF &
     "  for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++)" & LF &
     "    sum += textureLod(m, vec3(s.xy + vec2(float(i), float(j)) * t, s.z), 0.0);" & LF &
     "  vec2 e = min(s.xy, 1.0 - s.xy);" & LF &
     "  return mix(1.0, sum / 9.0, clamp(min(e.x, e.y) / max(fade, 1.0e-4), 0.0, 1.0));" & LF &
     "}" & LF &
     "float sunlit(vec3 p, vec3 n) {" & LF &
     "  if (u_shadow_texel <= 0.0) return 1.0;" & LF &
     --  (which maps a point asks: the near ones up to the fog distance, the
     --  far ones from Far_Shadow_Blend of it; in the one or the other alone
     --  only that one's taps are made.  Asked of every point with no branch,
     --  the far maps' two taps cost a tenth of a millisecond at the meadow.)
     "  float w = (u_far_sh.y > 0.0) ? smoothstep(u_far_sh.x, u_far_sh.y, length(p.xy - u_focus.xy)) : 0.0;" & LF &
     "  float near = 1.0, far = 1.0;" & LF &
     "  if (w < 1.0) {" & LF &
     "    vec3 pw = p + n * (1.5 * u_shadow_texel);" & LF &
     "    vec3 pf = p + n * (1.5 * u_fig_texel);" & LF &
     "    float a = min(lit_in(u_shadow, u_light_vp, pw, 0.0), lit_in(u_figsh, u_fig_vp, pf, 0.04));" & LF &
     "    float b = min(lit_in(u_shadow_b, u_light_vp_b, pw, 0.0), lit_in(u_figsh_b, u_fig_vp_b, pf, 0.04));" & LF &
     "    near = mix(a, b, u_shadow_mix);" & LF &
     "  }" & LF &
     "  if (w > 0.0) {" & LF &
     "    vec3 pq = p + n * (1.2 * u_far_sh2.y);" & LF &
     "    far = mix(lit_far(u_farsh, u_farl_vp, pq), lit_far(u_farsh_b, u_farl_vp_b, pq), u_shadow_mix);" & LF &
     "  }" & LF &
     "  return mix(near, far, w);" & LF &
     "}" & LF;

   --  A vertex of a figure's box (Castle.Figures), shared by the shader that
   --  draws the figures and the one that casts their shadows.  A box is six
   --  faces of three by three cells (54 vertices a face, 324 a box): the
   --  cells along a face's rim are as wide as the box's rounding, and their
   --  outer vertices are drawn in onto the rounded edge (the nearest point of
   --  the box shrunk by the radius, and the radius out from it), so two faces
   --  meet on the line halfway round their shared edge and three at the
   --  point halfway round the corner.  The normal turns with it, which is
   --  what shows at a distance.  Then the box is narrowed toward one end
   --  (Taper).  box_face: face F's point ST (0 .. 1 each way) of a box SZ
   --  body pixels in size, whose net has W, D and H texels; P the point in
   --  the box, O and E the face's texel origin and extent in the net, N its
   --  normal.
   Box_Face_Source : constant String :=
     "struct Box { vec4 lo; vec4 size; uvec4 info; };" & LF &      --  lo.w: rounding; size.w: taper
     "struct Bone { vec4 x; vec4 y; vec4 z; };" & LF &
     "layout(std430, binding = 8) readonly buffer Fig_Bones { Bone bones[]; };" & LF &
     "layout(std430, binding = 9) readonly buffer Fig_Boxes { Box boxes[]; };" & LF &
     "const vec2 corner[6] = vec2[6](vec2(0,0), vec2(0,1), vec2(1,1), vec2(0,0), vec2(1,1), vec2(1,0));" & LF &
     "void box_face(int f, vec2 st, vec3 sz, float W, float D, float H," & LF &
     "              out vec3 p, out vec2 o, out vec2 e, out vec3 n) {" & LF &
     "  if (f == 0)      { p = vec3(sz.x, st.x * sz.y, sz.z - st.y * sz.z);       o = vec2(0.0, D);               e = vec2(D, H); n = vec3(1, 0, 0); }" & LF &
     "  else if (f == 1) { p = vec3(0.0, sz.y - st.x * sz.y, sz.z - st.y * sz.z); o = vec2(D + W, D);           e = vec2(D, H); n = vec3(-1, 0, 0); }" & LF &
     "  else if (f == 2) { p = vec3(sz.x - st.x * sz.x, sz.y, sz.z - st.y * sz.z); o = vec2(D, D);              e = vec2(W, H); n = vec3(0, 1, 0); }" & LF &
     "  else if (f == 3) { p = vec3(st.x * sz.x, 0.0, sz.z - st.y * sz.z);         o = vec2(2.0 * D + W, D);    e = vec2(W, H); n = vec3(0, -1, 0); }" & LF &
     "  else if (f == 4) { p = vec3(sz.x - st.x * sz.x, st.y * sz.y, sz.z);        o = vec2(D, 0.0);            e = vec2(W, D); n = vec3(0, 0, 1); }" & LF &
     "  else             { p = vec3(sz.x - st.x * sz.x, sz.y - st.y * sz.y, 0.0);  o = vec2(D + W, 0.0);        e = vec2(W, D); n = vec3(0, 0, -1); }" & LF &
     "}" & LF &
     "float rim(float c, float r) { return c < 0.5 ? 0.0 : c < 1.5 ? r : c < 2.5 ? 1.0 - r : 1.0; }" & LF &
     "void box_vertex(int id, Box k, float W, float D, float H," & LF &
     "                out vec3 p, out vec2 o, out vec2 e, out vec2 st, out vec3 n) {" & LF &
     "  int f = (id / 54) % 6;" & LF &
     "  int cell = (id / 6) % 9;" & LF &
     "  vec2 c = corner[id % 6] + vec2(float(cell % 3), float(cell / 3));" & LF &
     "  vec3 sz = k.size.xyz;" & LF &
     "  float r = k.lo.w;" & LF &
     "  vec2 ext = (f < 2) ? sz.yz : (f < 4) ? sz.xz : sz.xy;" & LF &
     "  vec2 rr = min(vec2(r) / max(ext, vec2(1.0e-4)), vec2(0.5));" & LF &
     "  st = vec2(rim(c.x, rr.x), rim(c.y, rr.y));" & LF &
     "  box_face(f, st, sz, W, D, H, p, o, e, n);" & LF &
     "  if (r > 0.001) {" & LF &
     "    vec3 q = clamp(p, vec3(r), max(sz - vec3(r), vec3(r)));" & LF &
     "    vec3 d = p - q;" & LF &
     "    float l = length(d);" & LF &
     "    if (l > 1.0e-5) { n = d / l; p = q + n * r; }" & LF &
     "  }" & LF &
     "  float t = k.size.w;" & LF &
     "  if (t != 0.0) {" & LF &
     "    float h = clamp(p.z / max(sz.z, 1.0e-4), 0.0, 1.0);" & LF &
     "    float s = (t > 0.0) ? 1.0 - t * (1.0 - h) : 1.0 + t * h;" & LF &
     "    p.xy = 0.5 * sz.xy + (p.xy - 0.5 * sz.xy) * s;" & LF &
     "  }" & LF &
     "}" & LF &
     "vec3 bone_point(Bone b, vec3 q) {" & LF &
     "  return vec3(b.x.w, b.y.w, b.z.w) + b.x.xyz * q.x + b.y.xyz * q.y + b.z.xyz * q.z;" & LF &
     "}" & LF;

   --  What casts: every box of every figure, into a depth map (the sun's,
   --  the fire's), with no colour.  A box that glows casts nothing (it is a
   --  light), nor does a look made not to (Castle.Figures.New_Look, Casts:
   --  smoke).  This and the land's own depth pass (Shadow_Fragment_Source)
   --  are all that casts a shadow: Draw_Casters draws both, so whatever is
   --  drawn through Castle.Figures or meshed into a stack has its shadow
   --  from every light with nothing more to do.
   Caster_Vertex_Source : constant String :=
     "#version 450 core" & LF &
     Box_Face_Source &
     "uniform mat4 u_viewproj;" & LF &
     "uniform vec3 u_camera;" & LF &
     "void main() {" & LF &
     "  Box k = boxes[gl_VertexID / 324];" & LF &
     "  if (((k.info.w >> 25u) & 3u) != 0u) { gl_Position = vec4(2.0, 2.0, 2.0, 1.0); return; }" & LF &
     "  vec3 p; vec2 o; vec2 e; vec2 st; vec3 n;" & LF &
     "  box_vertex(gl_VertexID % 324, k, 1.0, 1.0, 1.0, p, o, e, st, n);" & LF &
     "  vec3 w = bone_point(bones[k.info.x], (k.lo.xyz + p) * 0.05);" & LF &
     "  gl_Position = u_viewproj * vec4(w - u_camera, 1.0);" & LF &
     "}" & LF;

   Caster_Fragment_Source : constant String :=
     "#version 450 core" & LF &
     "void main() { }" & LF;

   --  People (Castle.Figures): every box of every figure in one draw, six
   --  faces of nine cells each (box_vertex, above), pulled from the box and
   --  bone buffers by the vertex number.  A face's texels come from the box's net in its
   --  figure's skin (one layer of a texture array), laid out as
   --  Castle.Bodies.Face_Rect says; corners are in body pixels (5 cm) in
   --  the bone's frame.
   Figure_Vertex_Source : constant String :=
     "#version 450 core" & LF &
     Box_Face_Source &
     "uniform mat4 u_viewproj;" & LF &
     "uniform vec3 u_camera;" & LF &
     "out vec3 v_world;" & LF &
     "out vec3 v_tex;" & LF &
     "out vec3 v_n;" & LF &
     "flat out vec4 v_rect;" & LF &
     "flat out float v_glow;" & LF &
     "flat out float v_thin;" & LF &
     "void main() {" & LF &
     "  Box k = boxes[gl_VertexID / 324];" & LF &
     "  float W = float(k.info.w & 255u), D = float((k.info.w >> 8u) & 255u), H = float((k.info.w >> 16u) & 255u);" & LF &
     "  vec3 p; vec2 o; vec2 e; vec2 st; vec3 n;" & LF &   --  point in the box, face's texel origin and extent
     "  box_vertex(gl_VertexID % 324, k, W, D, H, p, o, e, st, n);" & LF &
     "  Bone b = bones[k.info.x];" & LF &
     "  v_world = bone_point(b, (k.lo.xyz + p) * 0.05);" & LF &
     "  v_n = b.x.xyz * n.x + b.y.xyz * n.y + b.z.xyz * n.z;" & LF &
     "  vec2 net = vec2(float(k.info.z & 65535u), float(k.info.z >> 16u)) + o;" & LF &
     "  v_tex = vec3(net + st * e, float(k.info.y));" & LF &
     "  v_rect = vec4(net + 0.002, net + e - 0.002);" & LF &   --  never sample past the face's own texels
     "  v_glow = float((k.info.w >> 25u) & 1u);" & LF &
     "  v_thin = float((k.info.w >> 27u) & 1u);" & LF &
     "  gl_Position = u_viewproj * vec4(v_world - u_camera, 1.0);" & LF &
     "}" & LF;

   Figure_Fragment_Source : constant String :=
     "#version 450 core" & LF &
     "in vec3 v_world;" & LF &
     "in vec3 v_tex;" & LF &
     "in vec3 v_n;" & LF &
     "flat in vec4 v_rect;" & LF &
     "flat in float v_glow;" & LF &
     "flat in float v_thin;" & LF &
     "uniform int u_a2c;" & LF &
     "layout(binding = 8) uniform sampler2DArray u_skin;" & LF &
     "uniform vec2 u_skin_size;" & LF &
     "out vec4 o_color;" & LF &
     Sky_Source &
     Sunlit_Source &
     "void main() {" & LF &
     "  vec2 t = clamp(v_tex.xy, v_rect.xy, v_rect.zw);" & LF &
     "  vec4 c = texture(u_skin, vec3(t / u_skin_size, v_tex.z));" & LF &
     "  if (c.a < 0.5) discard;" & LF &
     "  vec3 n = normalize(v_n);" & LF &
     "  vec3 amb = mix(u_gnd_amb, u_sky_amb, 0.5 + 0.5 * n.z);" & LF &
     "  float sun = max(dot(n, u_lamp), 0.0);" & LF &
     "  float lit = (sun > 0.0) ? sunlit(v_world, n) * cloud_shade(v_world) : 1.0;" & LF &
     "  vec3 col = c.rgb * (amb + u_lamp_col * sun * lit + firelight(v_world, n));" & LF &
     --  a box that glows (a flame, embers: Castle.Bodies.Box.Glow) is its own light
     "  if (v_glow > 0.5) col = c.rgb * 1.3;" & LF &
     "  float thru;" & LF &
     "  col = air(col, v_world, thru);" & LF &
     --  a thin look (smoke: Castle.Figures.New_Look, Thin) is half seen through: half
     --  the samples of each pixel under MSAA, every other pixel without it
     "  if (v_thin > 0.5 && u_a2c == 0 && ((int(gl_FragCoord.x) + int(gl_FragCoord.y)) & 1) == 0) discard;" & LF &
     "  o_color = vec4(grade(col), (v_thin > 0.5) ? 0.5 : 1.0);" & LF &
     "}" & LF;

   --  A soft dark disc on the ground under each figure.  In sunshine the
   --  figure's own shadow stands it on the ground and the disc is not
   --  drawn; under cloud and at night, where nothing casts one, the disc
   --  does (Contact_Shade).
   Blob_Vertex_Source : constant String :=
     "#version 450 core" & LF &
     "layout(std430, binding = 10) readonly buffer Fig_Blobs { vec4 blobs[]; };" & LF &
     "uniform mat4 u_viewproj;" & LF &
     "uniform vec3 u_camera;" & LF &
     "out vec2 v_q;" & LF &
     "const vec2 corner[6] = vec2[6](vec2(-1,-1), vec2(1,-1), vec2(1,1), vec2(-1,-1), vec2(1,1), vec2(-1,1));" & LF &
     "void main() {" & LF &
     "  vec4 b = blobs[gl_VertexID / 6];" & LF &
     "  v_q = corner[gl_VertexID % 6];" & LF &
     "  vec3 w = vec3(b.xy + v_q * b.w, b.z + 0.02);" & LF &
     "  gl_Position = u_viewproj * vec4(w - u_camera, 1.0);" & LF &
     "}" & LF;

   Blob_Fragment_Source : constant String :=
     "#version 450 core" & LF &
     "in vec2 v_q;" & LF &
     "uniform float u_blob;" & LF &
     "out vec4 o_color;" & LF &
     "void main() {" & LF &
     "  float r2 = dot(v_q, v_q);" & LF &
     "  if (r2 >= 1.0) discard;" & LF &
     "  o_color = vec4(0.0, 0.0, 0.0, u_blob * (1.0 - r2) * (1.0 - r2));" & LF &
     "}" & LF;

   --  Flat see-through strips over the ground (Castle.Marks): routes.
   Mark_Vertex_Source : constant String :=
     "#version 450 core" & LF &
     "struct Mark { vec4 a; vec4 b; vec4 c; };" & LF &
     "layout(std430, binding = 11) readonly buffer Marks_Buf { Mark marks[]; };" & LF &
     "uniform mat4 u_viewproj;" & LF &
     "uniform vec3 u_camera;" & LF &
     "uniform float u_dim;" & LF &
     "out vec4 v_col;" & LF &
     "const vec2 corner[6] = vec2[6](vec2(0,-1), vec2(1,-1), vec2(1,1), vec2(0,-1), vec2(1,1), vec2(0,1));" & LF &
     "void main() {" & LF &
     "  Mark m = marks[gl_VertexID / 6];" & LF &
     "  vec2 q = corner[gl_VertexID % 6];" & LF &
     "  vec2 d = m.b.xy - m.a.xy;" & LF &
     "  float l = length(d);" & LF &
     "  vec2 dir = l > 1e-5 ? d / l : vec2(1.0, 0.0);" & LF &
     "  float hw = 0.5 * m.a.w;" & LF &
     "  vec3 p = mix(m.a.xyz, m.b.xyz, q.x);" & LF &
     "  p.xy += vec2(-dir.y, dir.x) * (hw * q.y) + dir * ((2.0 * q.x - 1.0) * hw);" & LF &
     "  v_col = vec4(m.c.rgb * mix(1.0, u_dim, m.b.w), m.c.a);" & LF &
     "  gl_Position = u_viewproj * vec4(p - u_camera, 1.0);" & LF &
     "}" & LF;

   Mark_Fragment_Source : constant String :=
     "#version 450 core" & LF &
     "in vec4 v_col;" & LF &
     "out vec4 o_color;" & LF &
     "void main() { o_color = v_col; }" & LF;

   --  5x5 texels per block face, a variant picked per block by hash.
   --  (Everything of the wet look is between #ifdef WET and #endif: the
   --  land's shader is built twice, World_Fragment, and the one with it is
   --  only used while something is wet.  Left in one shader behind a test,
   --  it cost a twentieth of the frame in dry weather too, never run.)
   World_Fragment_Body : constant String :=
     "in vec3 v_world;" & LF &
     "in vec3 v_grid;" & LF &
     "in vec4 v_bend;" & LF &
     "flat in uint v_mat;" & LF &
     "flat in int v_face;" & LF &
     "flat in uint v_ao;" & LF &
     "flat in uint v_fr;" & LF &
     "flat in int v_lod;" & LF &
     "flat in float v_depth;" & LF &
     "uniform uvec2 u_foliage;" & LF &      --  leaves, needles, bushes: drawn soft
     "uniform int u_turf;" & LF &           --  the fringe's two kinds of ground: turf,
     "uniform int u_bare;" & LF &           --  and the bare earth drawn where turf is worn through
     "layout(binding = 0) uniform sampler2DArray u_tex;" & LF &
     "layout(binding = 9) uniform sampler2D u_scene;" & LF &
     "layout(binding = 10) uniform sampler2D u_scene_z;" & LF &
     "uniform mat4 u_viewproj;" & LF &
     "uniform int u_reflect;" & LF &
     "uniform vec3 u_far_view;" & LF &      --  the far view: where the stacks' ring ends (0: no far view); its cross-fade;
                                            --  where the stacks begin to give way
     "uniform vec3 u_zp;" & LF &            --  the camera's planes: 2 n f, f + n, f - n
     "layout(binding = 20) uniform sampler2D u_stack_flag;" & LF &    --  a stack whose own mesh is loaded
     "layout(binding = 21) uniform sampler2D u_far_have;" & LF &      --  how far in each level of the far view is, over each 16 m
     "uniform uvec2 u_ground;" & LF &
     "uniform int u_a2c;" & LF &
     "uniform vec3 u_camera;" & LF &
     "uniform int u_variants;" & LF &
     "uniform int u_water;" & LF &     "uniform int u_flowdbg;" & LF &
     "layout(binding = 6) uniform sampler2D u_flow;" & LF &
     "uniform vec3 u_snow;" & LF &          --  metres of snow at 16, 70 and 140 m
     "uniform float u_ice;" & LF &
     "uniform float u_wet;" & LF &
     "uniform float u_rain;" & LF &
     "uniform uvec2 u_soaks;" & LF &        --  earth, sand, bark: darkest when wet
     "uniform uvec2 u_shines;" & LF &       --  rock, planks, leaves: wet, they shine
     "uniform uvec2 u_pools;" & LF &        --  bare earth and rock: where water stands
     "uniform float u_grass_dry;" & LF &
     "uniform uvec2 u_grassy;" & LF &
     "uniform uvec2 u_plants;" & LF &
     "uniform uvec2 u_blades;" & LF &       --  tall grass and grain: blades, whose tips are all that shows from above
     "uniform int u_grain;" & LF &
     "uniform uvec2 u_crowns;" & LF &
     "uniform int u_aspen;" & LF &          --  the aspen's leaves: gold in autumn
     --  roofs cleared on the camera's ray (Castle.Cutaway, the same taper as
     --  its Cover): where (x, y), along which way (x, y); half the walls'
     --  lengths, the floor and the ridge; how far cleared
     "uniform int u_thatch;" & LF &
     "uniform uvec2 u_walls;" & LF &        --  what a wall can be made of (asked before its place is: daub, timber)
     "uniform vec4 u_roof_box;" & LF &      --  round every cleared house (x, y least; x, y most)
     "uniform int u_samples;" & LF &
     "uniform int u_roofs;" & LF &
     "uniform vec4 u_roof_a[" & GLSL_Int (Castle.Cutaway.Max_Roofs) & "];" & LF &
     "uniform vec4 u_roof_b[" & GLSL_Int (Castle.Cutaway.Max_Roofs) & "];" & LF &
     "uniform float u_roof_f[" & GLSL_Int (Castle.Cutaway.Max_Roofs) & "];" & LF &
     "out vec4 o_color;" & LF &
     Sky_Source &
     Sunlit_Source &
     "const vec3 normals[6] = vec3[6](vec3(1,0,0), vec3(-1,0,0), vec3(0,1,0)," &
     " vec3(0,-1,0), vec3(0,0,1), vec3(0,0,-1));" & LF &
     "uint hash3(ivec3 p) {" & LF &
     "  uint h = uint(p.x) * 0x8da6b343u ^ uint(p.y) * 0xd8163841u ^ uint(p.z) * 0xcb1ab31fu;" & LF &
     "  h ^= h >> 16u; h *= 0x7feb352du; h ^= h >> 15u;" & LF &
     "  return h;" & LF &
     "}" & LF &
     --  How much of a roof is drawn here: 1 whole (or no cleared roof's);
     --  cleared, a share over its walls and eaves, thinning to nothing
     --  inward (Castle.Cutaway.Cover, the same sum).
     "float roof_cover(vec3 p) {" & LF &
     "  float k = 1.0;" & LF &
     "  for (int i = 0; i < u_roofs; i++) {" & LF &
     "    vec2 d = p.xy - u_roof_a[i].xy;" & LF &
     "    vec2 w = u_roof_a[i].zw;" & LF &
     "    vec2 q = abs(vec2(dot(d, w), d.y * w.x - d.x * w.y));" & LF &
     "    vec4 b = u_roof_b[i];" & LF &
     "    if (q.x > b.x + " & GLSL (Float (Castle.Cutaway.Eave_M)) & " || q.y > b.y + "
     & GLSL (Float (Castle.Cutaway.Eave_M)) & " || p.z < b.z || p.z > b.w + 0.5) continue;" & LF &
     "    float r = " & GLSL (Float (Castle.Cutaway.Edge_Cover)) & " * (1.0 - smoothstep(0.0, "
     & GLSL (Float (Castle.Cutaway.Taper_M)) & ", min(b.x - q.x, b.y - q.y)));" & LF &
     "    k = min(k, 1.0 - u_roof_f[i] * (1.0 - r));" & LF &
     "  }" & LF &
     "  return k;" & LF &
     "}" & LF &
     --  How much of a wall is drawn here: 1 whole (not in a cleared house's
     --  walls' line above its floor, or a wall whose outward side does not
     --  face the eye); nothing where it faces the eye squarely, fading to
     --  whole edge-on (Castle.Cutaway.Wall_Cover, the same sum).
     "float wall_cover(vec3 p) {" & LF &
     "  float k = 1.0;" & LF &
     "  for (int i = 0; i < u_roofs; i++) {" & LF &
     "    vec2 d = p.xy - u_roof_a[i].xy;" & LF &
     "    vec2 w = u_roof_a[i].zw;" & LF &
     "    vec2 l = vec2(dot(d, w), d.y * w.x - d.x * w.y);" & LF &
     "    vec4 b = u_roof_b[i];" & LF &
     "    vec2 inn = b.xy - abs(l);" & LF &
     "    if (inn.x < -0.02 || inn.y < -0.02 || min(inn.x, inn.y) > " & GLSL (Float (Castle.Cutaway.Wall_M))
     & " || p.z < b.z + 0.03 || p.z > b.w + 0.5) continue;" & LF &
     "    vec2 n = (inn.x < inn.y) ? ((l.x < 0.0) ? -w : w)" & LF &
     "                             : ((l.y < 0.0) ? vec2(w.y, -w.x) : vec2(-w.y, w.x));" & LF &
     "    vec2 e = u_camera.xy - p.xy;" & LF &
     "    float facing = dot(n, e) / max(length(e), 0.5);" & LF &
     "    k = min(k, 1.0 - u_roof_f[i] * smoothstep(" & GLSL (Float (Castle.Cutaway.Face_Lo)) & ", "
     & GLSL (Float (Castle.Cutaway.Face_Hi)) & ", facing));" & LF &
     "  }" & LF &
     "  return k;" & LF &
     "}" & LF &
     --  a threshold for each pixel of a 4 x 4 tile, so that a share drawn
     --  is spread evenly (by the pixel, never by the frame)
     "float cut_dither(vec2 fc) {" & LF &
     "  ivec2 p = ivec2(fc) & 3;" & LF &
     "  const int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);" & LF &
     "  return (float(m[p.y * 4 + p.x]) + 0.5) / 16.0;" & LF &
     "}" & LF &
     --  Water ripples: two scales of the tiling noise drifting in different
     --  directions, as a height whose slope tilts the surface normal.
     Leaf_Source &
     Open_Source &
     "float snow_depth(float z) {" & LF &
     "  if (z <= 16.0) return u_snow.x;" & LF &
     "  if (z <= 70.0) return mix(u_snow.x, u_snow.y, (z - 16.0) / 54.0);" & LF &
     "  if (z <= 140.0) return mix(u_snow.y, u_snow.z, (z - 70.0) / 70.0);" & LF &
     "  return u_snow.z;" & LF &
     "}" & LF &
     --  The world in the water.  The reflected ray is walked out from the
     --  surface in growing strides and each point looked up in the picture
     --  so far: where the picture's own depth there is nearer than the
     --  point, the ray has gone into the land, a tree or a person; the
     --  place is narrowed down by halving and its colour taken.  It only
     --  counts if the picture's depth is nearer by no more than the ray
     --  itself went deeper over that stride (and a little): a crown that
     --  stands between the eye and the water hides the ray's point without
     --  the ray having reached it, and must not be mirrored for it.  A ray that leaves the picture or meets
     --  nothing gives no weight, and the sky is mirrored as before.  The
     --  colour is as the picture has it, graded already.  Past the
     --  picture's sides the ray goes on along its edge (the hill most
     --  likely carries on); toward its top the weight fades out, since what
     --  stands above the picture is not known.
     "float view_z(float d) {" & LF &
     "  return u_zp.x / (u_zp.y - (d * 2.0 - 1.0) * u_zp.z);" & LF &
     "}" & LF &
     --  (By: how many times longer the strides are, and how much deeper a
     --  thing may stand behind the picture's depth and still be the ray's:
     --  1 for water in the view; for a tile of the far view its cell's size,
     --  so the walk reaches as many cells as it does blocks close by.)
     "vec4 mirrored(vec3 p0, vec3 r, float by) {" & LF &
     "  float t = 0.4 * by, last = 0.0;" & LF &
     "  float wl = (u_viewproj * vec4(p0 - u_camera, 1.0)).w;" & LF &
     "  for (int i = 0; i < 30; i++) {" & LF &
     "    vec4 q = u_viewproj * vec4(p0 + r * t - u_camera, 1.0);" & LF &
     "    if (q.w <= 0.05) break;" & LF &
     "    vec2 uv = q.xy / q.w * 0.5 + 0.5;" & LF &
     "    if (uv.y <= 0.0 || uv.y >= 1.0) break;" & LF &
     "    uv.x = clamp(uv.x, 0.0, 1.0);" & LF &
     "    float ds = texture(u_scene_z, uv).r;" & LF &
     "    float zs = view_z(ds);" & LF &
     "    if (ds < 0.99999 && q.w > zs && q.w - zs < 0.6 * by + 1.5 * abs(q.w - wl)) {" & LF &
     "      float lo = last, hi = t;" & LF &
     "      for (int j = 0; j < 5; j++) {" & LF &
     "        float m = 0.5 * (lo + hi);" & LF &
     "        vec4 qm = u_viewproj * vec4(p0 + r * m - u_camera, 1.0);" & LF &
     "        if (qm.w > view_z(texture(u_scene_z, qm.xy / qm.w * 0.5 + 0.5).r)) hi = m; else lo = m;" & LF &
     "      }" & LF &
     "      vec4 qh = u_viewproj * vec4(p0 + r * hi - u_camera, 1.0);" & LF &
     "      vec2 uh = clamp(qh.xy / qh.w * 0.5 + 0.5, 0.0, 1.0);" & LF &
     "      float edge = smoothstep(0.0, 0.10, 1.0 - uh.y);" & LF &
     "      return vec4(texture(u_scene, uh).rgb, edge);" & LF &
     "    }" & LF &
     "    last = t;" & LF &
     "    wl = q.w;" & LF &
     "    t = t * 1.2 + 0.3 * by;" & LF &
     "  }" & LF &
     "  return vec4(0.0);" & LF &
     "}" & LF &
     "float ripple(vec2 q) {" & LF &
     "  return texture(u_noise, q / 19.0 + u_time * vec2(0.021, 0.013)).r" & LF &
     "       + 0.5 * texture(u_noise, q.yx / 7.0 - u_time * vec2(0.034, 0.027)).r;" & LF &
     "}" & LF &
     --  Rain on standing water: a drop to every third of a metre, each in
     --  its own time, and the ring that widens from it and dies.  Which way
     --  the surface is tipped there, to break what it mirrors.
     "vec2 rain_rings(vec2 p) {" & LF &
     "  vec2 g = p * 3.0;" & LF &
     "  ivec2 cell = ivec2(floor(g));" & LF &
     "  uint h = hash3(ivec3(cell, 911));" & LF &
     "  vec2 at = vec2(float(h & 255u), float((h >> 8u) & 255u)) / 255.0 * 0.5 + 0.25;" & LF &
     "  float age = fract(u_time * (0.9 + 0.5 * float((h >> 16u) & 255u) / 255.0) + float((h >> 24u) & 255u) / 255.0);" & LF &
     "  vec2 o = fract(g) - at;" & LF &
     "  float r = length(o);" & LF &
     "  float ring = (1.0 - smoothstep(0.0, 0.07, abs(r - 0.42 * age))) * (1.0 - age);" & LF &
     "  return (r > 1.0e-3) ? o / r * ring : vec2(0.0);" & LF &
     "}" & LF &
     "void main() {" & LF &
     --  The far view (see the spec): which level this place shows, and
     --  whether this fragment is of it.  c counts doublings of distance from
     --  the end of the stacks' ring; ring wl is c in wl - 1 .. wl.
     --  (a stack's own fragment well inside its ring is what shows, and asks nothing)
     "  float far_d = (u_far_view.x > 0.0) ? length(v_world.xy - u_focus.xy) : 0.0;" & LF &
     "  if (u_far_view.x > 0.0 && (v_lod > 0 || far_d > u_far_view.z)) {" & LF &
     "    float c = log2(max(far_d, 1.0) / u_far_view.x);" & LF &
     "    int wl = clamp(int(floor(c)) + 1, 0, " & GLSL_Int (Castle.Lod.Max_Level) & ");" & LF &
     "    if (v_lod < wl) discard;" & LF &
     --  (a level is loaded here, for this pixel, if its share is over the
     --  pixel's place in the pattern: a tile just come in takes its pixels a
     --  few more each frame, from whatever stood in for it)
     "    float dz = cut_dither(gl_FragCoord.xy);" & LF &
     "    vec4 wt = texelFetch(u_far_have, clamp(ivec2(floor(v_world.xy / 16.0)), ivec2(0), ivec2("
     & GLSL_Int (Chunks_XY / 2 - 1) & ")), 0);" & LF &
     "    bool st = texelFetch(u_stack_flag, clamp(ivec2(floor(v_world.xy / 8.0)), ivec2(0), ivec2("
     & GLSL_Int (Chunks_XY - 1) & ")), 0).r > 0.25;" & LF &
     "    int f = wl;" & LF &                  --  the finest level loaded here that is not finer than wanted
     "    while (f < " & GLSL_Int (Castle.Lod.Max_Level) & " && !((f == 0) ? st : (wt[f - 1] > dz))) f++;" & LF &
     --  (the cross-fade: tc is the coarser level's share of the pixels, tf
     --  what the finer has given up; tc runs Far_Lap ahead of tf, so that the
     --  two fragments of a pixel, which stand a little apart on the ground,
     --  never both give it up)
     "    const float span = " & GLSL (Float (Far_Fade - Far_Lap)) & ";" & LF &
     "    bool fade = wl < " & GLSL_Int (Castle.Lod.Max_Level) & ";" & LF &
     "    float tc = fade ? clamp((c - (float(wl) - u_far_view.y)) / span, 0.0, 1.0) : 0.0;" & LF &
     "    float tf = fade ? clamp((c - (float(wl) - span)) / span, 0.0, 1.0) : 0.0;" & LF &
     "    bool next = fade && wt[wl] > dz;" & LF &
     "    if (v_lod == f) {" & LF &
     "      if (f == wl && next && dz < tf) discard;" & LF &
     "    } else if (!(v_lod == wl + 1 && f == wl && next && dz < tc)) discard;" & LF &
     "  }" & LF &
     --  A cleared roof: as many of the pixel's samples as its share drawn
     --  (alpha to coverage, dithered between whole samples), or with no
     --  multisampling, as many of the pixels.
     --  (and the walls on the eye's side of a cleared house: by their place,
     --  asked only of what a wall can be made of, inside the box round the
     --  cleared houses)
     "  float roof_q = 1.0;" & LF &
     "  if (u_roofs > 0 && u_water == 0 && all(greaterThanEqual(v_world.xy, u_roof_box.xy))" & LF &
     "      && all(lessThanEqual(v_world.xy, u_roof_box.zw))" & LF &
     "      && (int(v_mat) == u_thatch || in_set(u_walls, v_mat))) {" & LF &
     "    float k = (int(v_mat) == u_thatch) ? roof_cover(v_world)" & LF &
     "            : in_set(u_walls, v_mat) ? wall_cover(v_world) : 1.0;" & LF &
     "    if (k < 1.0) {" & LF &
     "      float dz = cut_dither(gl_FragCoord.xy);" & LF &
     "      if (u_a2c == 1) {" & LF &
     "        roof_q = floor(k * float(u_samples) + dz) / float(u_samples);" & LF &
     "        if (roof_q <= 0.0) discard;" & LF &
     "      } else if (k <= dz) discard;" & LF &
     "    }" & LF &
     "  }" & LF &
     "  vec3 n = normals[v_face];" & LF &
     "  vec3 pb = v_grid * 4.0 - n * 0.01;" & LF &
     "  ivec3 b = ivec3(floor(pb));" & LF &
     "  vec3 f = fract(pb);" & LF &
     "  vec2 uv = (v_face < 2) ? f.yz : (v_face < 4) ? f.xz : f.xy;" & LF &
     "  ivec2 t = clamp(ivec2(uv * 5.0), ivec2(0), ivec2(4));" & LF &
     "  int layer = int(v_mat) * u_variants + int(hash3(b) % uint(u_variants));" & LF &
     "  if (u_water == 0 && leaf_gone(b, v_mat)) discard;" & LF &
     --  Snow lies where the sky reaches; grass and grain under deep snow
     --  are buried.
     "  float snow = (u_water == 0) ? snow_depth(v_world.z) : 0.0;" & LF &
     "  float open_sky = (snow > 0.0) ? sky_open(v_world) : 0.0;" & LF &
     "  if (in_set(u_plants, v_mat) && snow * open_sky > 0.12) discard;" & LF &
     --  Fade detail out as it shrinks below a pixel: texels first, then
     --  the per-block variants.  Under MSAA, cut-out coverage goes through
     --  alpha-to-coverage, so distant foliage keeps its density instead of
     --  vanishing; without it, a plain alpha test.
     "  float fb = max(length(dFdx(pb)), length(dFdy(pb)));" & LF &
     "  float m1 = smoothstep(0.1, 0.25, fb);" & LF &
     "  float m2 = smoothstep(0.5, 1.0, fb);" & LF &
     --  (a plant more than a block high: below its top block its blades are
     --  stalks, whole from foot to top, with no tips or ears part way up)
     "  if (v_face < 4 && v_fr > 1u && u_water == 0 && in_set(u_plants, v_mat)" & LF &
     "      && min(floor(v_bend.w * float(v_fr)), float(v_fr) - 1.0) < float(v_fr) - 1.5) t.y = 0;" & LF &
     "  vec4 c0 = texelFetch(u_tex, ivec3(t, layer), 0);" & LF &
     "  vec4 c1 = texelFetch(u_tex, ivec3(0, 0, layer), 1);" & LF &
     "  vec4 c2 = texelFetch(u_tex, ivec3(0, 0, layer), 2);" & LF &
     "  vec4 c = mix(mix(vec4(c0.rgb, step(0.5, c0.a)), c1, m1), c2, m2);" & LF &
     --  Foliage frays where it stands out of its clump: more of its texels
     --  are open there (far off, that much less of it covers the pixel).
     "  bool soft = in_set(u_foliage, v_mat);" & LF &
     "  float lift = v_bend.w;" & LF &
     "  if (soft && u_water == 0) {" & LF &
     "    float thin = " & GLSL (Float (Foliage_Ragged)) & " * lift;" & LF &
     "    float hs = float(hash3(ivec3(b.xy * 5 + t.yx, b.z * 5 + t.x + 31)) & 1023u) / 1023.0;" & LF &
     --  (with no multisampling there is no coverage to thin: far off it is whole)
     --  The gaps painted between the leaves show the dark inside of the
     --  crown, not the sky behind it: only a face's back is behind a gap, and
     --  that is never drawn.  (They were holes; a round crown is a shell, and
     --  stood against the sky like a veil.)
     "    c.rgb = mix(mix(c0.rgb * mix(" & GLSL (Float (Foliage_Deep)) & ", 1.0, step(0.5, c0.a))," & LF &
     "                    c1.rgb * mix(" & GLSL (Float (Foliage_Deep)) & ", 1.0, c1.a), m1)," & LF &
     "                c2.rgb * mix(" & GLSL (Float (Foliage_Deep)) & ", 1.0, c2.a), m2);" & LF &
     "    c.a = mix(step(thin, hs), (u_a2c == 0) ? 1.0 : 1.0 - thin, m1);" & LF &
     "  }" & LF &
     --  A tuft (see the spec) seen from above is the tips of its blades, not
     --  a lid: that share of its top's texels, the same share of the pixel
     --  far off.  Wild vegetables keep their painted rosette.
     "  bool plant = in_set(u_plants, v_mat);" & LF &
     "  if (plant && v_face == 4 && u_water == 0 && in_set(u_blades, v_mat)) {" & LF &
     "    float share = (int(v_mat) == u_grain) ? " & GLSL (Float (Grain_Tips)) & " : " & GLSL (Float (Tuft_Tips)) & ";" & LF &
     "    float hs = float(hash3(ivec3(b.xy * 5 + t, b.z + 53)) & 1023u) / 1023.0;" & LF &
     "    c = vec4(mix(mix(c0.rgb, c1.rgb, m1), c2.rgb, m2)," & LF &
     "             mix(step(hs, share), (u_a2c == 0) ? step(hs, share) : share, m1));" & LF &
     "  }" & LF &
     "  if (u_water == 0 && u_a2c == 0 && c.a < 0.5) discard;" & LF &
     --  The fringe between turf and bare earth (see the spec): along the
     --  sides the mesher marked, each texel may be the other kind's, the
     --  likelier the nearer the edge, over a width that wanders along it.
     "  float turfy = in_set(u_grassy, v_mat) ? 1.0 : 0.0;" & LF &     --  how far this texel is grass
     "  if (u_water == 0 && v_fr != 0u && v_face == 4) {" & LF &
     "    bool turf = int(v_mat) == u_turf;" & LF &
     "    vec2 tc = (vec2(t) + 0.5) / 5.0;" & LF &
     "    float d = 9.0;" & LF &
     "    if ((v_fr & 1u) != 0u) d = min(d, tc.x);" & LF &
     "    if ((v_fr & 2u) != 0u) d = min(d, 1.0 - tc.x);" & LF &
     "    if ((v_fr & 4u) != 0u) d = min(d, tc.y);" & LF &
     "    if ((v_fr & 8u) != 0u) d = min(d, 1.0 - tc.y);" & LF &
     "    if ((v_fr & 16u) != 0u) d = min(d, length(tc));" & LF &
     "    if ((v_fr & 32u) != 0u) d = min(d, length(tc - vec2(1.0, 0.0)));" & LF &
     "    if ((v_fr & 64u) != 0u) d = min(d, length(tc - vec2(1.0, 1.0)));" & LF &
     "    if ((v_fr & 128u) != 0u) d = min(d, length(tc - vec2(0.0, 1.0)));" & LF &
     "    float nz = smoothstep(0.25, 0.75, texture(u_noise, v_grid.xy / "
     & GLSL (Float (4.0 * Fringe_Wander_M)) & " + (turf ? vec2(0.37, 0.11) : vec2(0.0))).r);" & LF &
     "    float wd = turf ? mix(" & GLSL (Float (Fringe_Wear_Min)) & ", " & GLSL (Float (Fringe_Wear_Max)) & ", nz)" & LF &
     "                    : mix(" & GLSL (Float (Fringe_Grass_Min)) & ", " & GLSL (Float (Fringe_Grass_Max)) & ", nz);" & LF &
     "    float near = clamp(1.0 - d / wd, 0.0, 1.0);" & LF &
     "    float pr = (turf ? " & GLSL (Float (Fringe_Wear_Share)) & " : " & GLSL (Float (Fringe_Grass_Share))
     & ") * near * sqrt(near);" & LF &
     "    int ol = (turf ? u_bare : u_turf) * u_variants + int(hash3(b) % uint(u_variants));" & LF &
     "    vec3 o0 = texelFetch(u_tex, ivec3(t, ol), 0).rgb;" & LF &
     "    vec3 o1 = texelFetch(u_tex, ivec3(0, 0, ol), 1).rgb;" & LF &
     "    vec3 o2 = texelFetch(u_tex, ivec3(0, 0, ol), 2).rgb;" & LF &
     "    vec3 oc = mix(mix(o0, o1, m1), o2, m2);" & LF &
     "    float hs = float(hash3(ivec3(b.xy * 5 + t, b.z + 77)) & 1023u) / 1023.0;" & LF &
     "    float k = mix(step(hs, pr), pr, m1);" & LF &           --  texel by texel close up, a blend far off
     --  the grass by the edge is trodden, on either side of it: duller, yellowed
     "    vec3 trod = vec3(1.04, 0.92, 0.62);" & LF &
     "    float tk = " & GLSL (Float (Fringe_Trodden)) & " * clamp(1.0 - d / (wd + 0.4), 0.0, 1.0);" & LF &
     "    if (turf) c.rgb = mix(c.rgb, c.rgb * trod, tk); else oc = mix(oc, oc * trod, " & GLSL (Float (Fringe_Trodden)) & ");" & LF &
     "    c.rgb = mix(c.rgb, oc, k);" & LF &
     "    turfy = mix(turfy, 1.0 - turfy, k);" & LF &
     --  and here and there a pebble lies along the edge, kicked off the path
     "    float ps = float((hash3(ivec3(b.xy * 5 + t, b.z + 191)) >> 4u) & 1023u) / 1023.0;" & LF &
     "    float pk = step(ps, " & GLSL (Float (Fringe_Pebbles)) & " * clamp(1.0 - d / 0.9, 0.0, 1.0)) * (1.0 - m1);" & LF &
     "    c.rgb = mix(c.rgb, " & GLSL (Castle.Colors.Warm_Gray) & " * (1.05 + 0.45 * hs), pk);" & LF &
     "    turfy *= 1.0 - pk;" & LF &
     "  }" & LF &
     --  Seasons: broadleaf crowns turn yellow, orange and red (by tree);
     --  grass dries to straw in late summer and stays dull through winter.
     --  Crowns vary tree by tree (a 3 m column of blocks, about one crown):
     --  a little lighter or darker, a little yellower or bluer.
     "  if (in_set(u_crowns, v_mat)) {" & LF &
     "    uint th = hash3(ivec3(b.x / 12, b.y / 12, 7));" & LF &
     "    float t1 = float(th & 1023u) / 1023.0 - 0.5;" & LF &
     "    float t2 = float((th >> 10u) & 1023u) / 1023.0 - 0.5;" & LF &
     "    c.rgb *= (1.0 + 0.16 * t1) * vec3(1.0 + 0.10 * t2, 1.0, 1.0 - 0.10 * t2);" & LF &
     "  }" & LF &
     "  if (in_set(u_broadleaf, v_mat) && u_leaf.x > 0.0) {" & LF &
     "    float tree = float(hash3(b / 12) & 1023u) / 1023.0;" & LF &
     "    if (int(v_mat) == u_aspen) tree = 0.0;" & LF &   --  aspens all turn gold
     "    vec3 autumn = (tree < 0.3) ? " & GLSL (Castle.Colors.Aged_Gold)
     & " : (tree < 0.6) ? " & GLSL (Castle.Colors.Warm_Copper) & LF &
     "                : (tree < 0.85) ? " & GLSL (Castle.Colors.Brightened_Crimson)
     & " : " & GLSL (Castle.Colors.Warm_Umber) & ";" & LF &
     "    float l = clamp(dot(c.rgb, vec3(0.3, 0.59, 0.11)) / 0.3, 0.6, 1.4);" & LF &
     "    c.rgb = mix(c.rgb, autumn * l, u_leaf.x);" & LF &
     "  }" & LF &
     --  A meadow is lighter and darker in drifts, and yellower here and
     --  there (see the spec): by place, on two scales of the noise.
     "  if (turfy > 0.0 && u_water == 0) {" & LF &
     "    float d1 = texture(u_noise, v_grid.xy / 53.0).r;" & LF &
     "    float d2 = texture(u_noise, v_grid.yx / 137.0 + 0.41).r;" & LF &
     "    float tone = 1.0 + " & GLSL (Float (2.0 * Meadow_Tone)) & " * (0.65 * d1 + 0.35 * d2 - 0.5);" & LF &
     "    float sere = " & GLSL (Float (Meadow_Sere)) & " * smoothstep(0.5, 0.85, 0.5 + d2 - d1);" & LF &
     "    c.rgb = mix(c.rgb, c.rgb * tone * mix(vec3(1.0), vec3(1.16, 1.02, 0.70), sere), turfy);" & LF &
     "  }" & LF &
     "  if (turfy > 0.0 && u_grass_dry > 0.0) {" & LF &
     "    float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));" & LF &
     "    c.rgb = mix(c.rgb, vec3(1.35, 1.12, 0.55) * l * 1.25, 0.85 * u_grass_dry * turfy);" & LF &
     "  }" & LF &
     --  Light: sky from above and ground bounce from below, by the face's
     --  normal, plus sunlight.
     --  (foliage: the normal the light goes by turns over a clump's cut
     --  edges, and what stands out of the clump is a little lighter)
     "  vec3 nl = n;" & LF &
     --  (a tuft takes the light as the turf it stands in does, darker at
     --  the root and lighter at the tip)
     "  if (plant) {" & LF &
     "    nl = normalize(mix(n, vec3(0.0, 0.0, 1.0), " & GLSL (Float (Tuft_Up)) & "));" & LF &
     "    c.rgb *= mix(" & GLSL (Float (Tuft_Root)) & ", " & GLSL (Float (Tuft_Tip)) & ", v_bend.w);" & LF &
     "  }" & LF &
     --  (the side of a block of turf is a bank of grass: see the spec)
     "  bool bank = int(v_mat) == u_turf && v_face < 4 && u_water == 0;" & LF &
     "  if (bank) nl = normalize(mix(n, vec3(0.0, 0.0, 1.0), " & GLSL (Float (Turf_Up)) & "));" & LF &
     --  (a face of a dressed roof: the light goes by the way it was turned)
     "  if (!soft && !plant && dot(v_bend.xyz, v_bend.xyz) > 1.0e-4) nl = normalize(n + v_bend.xyz);" & LF &
     "  if (soft) {" & LF &
     "    uint rh = hash3(b + ivec3(3, 11, 7));" & LF &
     "    vec3 ruffle = vec3(float(rh & 1023u), float((rh >> 10u) & 1023u), float((rh >> 20u) & 1023u)) / 1023.0 - 0.5;" & LF &
     "    nl = normalize(n + v_bend.xyz + ruffle * " & GLSL (Float (2.0 * Foliage_Ruffle)) & " * (1.0 - m2));" & LF &
     "    float mass = texture(u_noise, v_grid.xy / 6.0 + v_grid.z * vec2(0.071, 0.113)).r;" & LF &
     "    c.rgb *= (1.0 + " & GLSL (Float (Foliage_Mass)) & " * (mass - 0.5) * 2.0)"
     & " * (1.0 + " & GLSL (Float (Foliage_Lift)) & " * (lift - 0.3));" & LF &
     "  }" & LF &
     "  vec3 amb = mix(u_gnd_amb, u_sky_amb, 0.5 + 0.5 * nl.z);" & LF &
     "  float sun = max(dot(nl, u_lamp), 0.0);" & LF &
     "  vec3 ns = n;" & LF &
     --  Once blocks are under a pixel their lit tops and shaded sides beat
     --  against the pixel grid; light distant ground from the smooth height
     --  field instead.
     "  if (m2 > 0.0 && in_set(u_ground, v_mat)) {" & LF &
     "    vec2 p = v_world.xy / 2048.0;" & LF &
     "    const float e = 1.0 / 2048.0;" & LF &
     "    float hx = texture(u_height, p + vec2(e, 0.0)).r - texture(u_height, p - vec2(e, 0.0)).r;" & LF &
     "    float hy = texture(u_height, p + vec2(0.0, e)).r - texture(u_height, p - vec2(0.0, e)).r;" & LF &
     "    ns = normalize(vec3(-0.5 * hx, -0.5 * hy, 1.0));" & LF &
     "    amb = mix(amb, mix(u_gnd_amb, u_sky_amb, 0.5 + 0.5 * ns.z), m2);" & LF &
     "    sun = mix(sun, max(dot(ns, u_lamp), 0.0), m2);" & LF &
     "  }" & LF &
     --  Snow coats faces that look up at the sky (at a distance, ground that
     --  slopes gently), patchy while it is only a dusting.
     "  float coat = 0.0;" & LF &
     "  if (snow > 0.0) {" & LF &
     "    float up = mix((v_face == 4) ? 1.0 : 0.0, smoothstep(0.55, 0.9, ns.z), m2);" & LF &
     --  A side face is buried where the ground just in front of it lies
     --  within the snow's depth below it: small steps vanish under deep
     --  snow, a cliff only gets snow banked at its foot.
     "    if (v_face < 4) {" & LF &
     "      vec3 front = v_world + n * 0.12;" & LF &
     "      up = max(up, sky_open(front) * (1.0 - open_at(front - vec3(0.0, 0.0, snow))));" & LF &
     "      open_sky = max(open_sky, sky_open(front));" & LF &
     "    }" & LF &
     "    float patchy = smoothstep(0.0, 0.05, snow * (0.5 + texture(u_noise, v_world.xy / 9.0).r));" & LF &
     "    coat = up * open_sky * patchy;" & LF &
     "    c.rgb = mix(c.rgb, vec3(0.92, 0.94, 0.98), coat);" & LF &
     "  }" & LF &
     --  Wet (see the spec): as wet as the rain reaches it (under a roof or a
     --  crown, Wet_Sheltered of that); earth, sand and bark soak it up and
     --  go darkest, and everything is a little richer in colour.
     "  float wet = 0.0, rained_on = 0.0;" & LF &
     "#ifdef WET" & LF &
     "  if (u_water == 0 && u_wet > 0.0) {" & LF &
     "    rained_on = (snow > 0.0 && v_face == 4) ? open_sky : open_1(v_world + n * 0.06 + vec3(0.0, 0.0, 0.15));" & LF &
     "    wet = u_wet * (1.0 - coat) * mix(" & GLSL (Float (Wet_Sheltered)) & ", 1.0, rained_on);" & LF &
     "    float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));" & LF &
     "    c.rgb = mix(vec3(l), c.rgb, 1.0 + " & GLSL (Float (Wet_Rich)) & " * wet)" & LF &
     "            * (1.0 - (in_set(u_soaks, v_mat) ? " & GLSL (Float (Wet_Soak)) & " : " & GLSL (Float (Wet_Dark)) & ") * wet);" & LF &
     "  }" & LF &
     "#endif" & LF &
     "  vec3 lp = bank ? vec3(v_world.xy + n.xy * 0.03, (float(b.z) + 1.0) * 0.25 + 0.04) : v_world;" & LF &
     "  float lit = (sun > 0.0) ? sunlit(lp, bank ? vec3(0.0, 0.0, 1.0) : n) * cloud_shade(v_world) : 1.0;" & LF &
     --  Ambient occlusion from the mesher: the face's four corners blended
     --  across each block; far off, the face's average, so it can't shimmer.
     "  if (u_water == 0) {" & LF &
     "    vec4 k = vec4(float(v_ao & 3u), float((v_ao >> 2u) & 3u), float((v_ao >> 4u) & 3u), float((v_ao >> 6u) & 3u)) / 3.0;" & LF &
     --  (a tile of the far view: across its own cell, not across each block of it)
     "    vec2 uva = uv;" & LF &
     "    if (v_lod > 0) {" & LF &
     "      vec3 fa = fract(pb / float(1 << v_lod));" & LF &
     "      uva = (v_face < 2) ? fa.yz : (v_face < 4) ? fa.xz : fa.xy;" & LF &
     "    }" & LF &
     "    float ao = mix(mix(k.x, k.y, uva.x), mix(k.w, k.z, uva.x), uva.y);" & LF &
     "    ao = mix(ao, dot(k, vec4(0.25)), m2);" & LF &
     "    float occl = 0.45 + 0.55 * ao;" & LF &
     "    amb *= occl;" & LF &
     "    lit *= mix(1.0, occl, 0.35);" & LF &
     "  }" & LF &
     --  Deeper water, deeper hue (see the spec): the texel is Storm Blue,
     --  and the column's depth turns it toward Royal Indigo and then Abyss
     --  Blue, before the light falls on it, so it darkens with the day as
     --  everything does.  (Water in a tunnel, laid as blocks, has no depth
     --  to go by: a metre.)
     "  float wdepth = ((v_depth < 0.0) ? 4.0 : v_depth) * 0.25;" & LF &
     "  if (u_water == 1) {" & LF &
     "    vec3 hue = mix(mix(" & GLSL (Castle.Colors.Storm_Blue) & ", " & GLSL (Castle.Colors.Royal_Indigo)
     & ", 1.0 - exp(-wdepth / " & GLSL (Float (Water_Hue_M)) & "))," & LF &
     "                   " & GLSL (Castle.Colors.Abyss_Blue)
     & ", 1.0 - exp(-wdepth / " & GLSL (Float (Water_Abyss_M)) & "));" & LF &
     "    c.rgb *= hue / " & GLSL (Castle.Colors.Storm_Blue) & ";" & LF &
     "  }" & LF &
     "  vec3 col = c.rgb * (amb + u_lamp_col * sun * lit + firelight(v_world, nl));" & LF &
     "  float alpha = c.a * roof_q;" & LF &
     --  What is wet shines: it mirrors the sky, the more the flatter it is
     --  seen (rock, planks and leaves more than turf and earth), and glints
     --  where the sun comes off it.  And on level bare ground under the
     --  open sky water stands in pools, more and wider the wetter it is,
     --  by place (the same pools after every rain): a pool is the ground
     --  darker still and the sky in it, as open water mirrors it, ringed by
     --  the rain while it falls.  Texel by texel close up, a share of the
     --  pixel far off.
     "#ifdef WET" & LF &
     --  (most of what is looked down on can show none of it, turf and leaves
     --  seen steeply with the sun's glint elsewhere, and is passed over)
     "  vec3 wv = u_camera - v_world;" & LF &
     "  bool may_pool = v_face == 4 && rained_on > 0.5 && in_set(u_pools, v_mat) && !plant;" & LF &
     "  bool hard = in_set(u_shines, v_mat);" & LF &
     "  if (wet > 0.0 && (may_pool || hard || dot(nl, wv) < 0.55 * length(wv))) {" & LF &
     "    vec3 v = normalize(wv);" & LF &
     "    float pool = 0.0;" & LF &
     "    vec3 wn = nl;" & LF &
     "    if (may_pool) {" & LF &
     "      vec2 tp = mix((floor(v_grid.xy * 20.0) + 0.5) / 20.0, v_grid.xy, m1);" & LF &
     "      float ld = log2(max(fb * 1.6, 1.0));" & LF &
     "      float pn = 0.6 * textureLod(u_noise, tp / 40.0 + 0.13, ld).r + 0.4 * textureLod(u_noise, tp.yx / 13.0 + 0.61, ld + 1.6).r;" & LF &
     "      float lvl = " & GLSL (Float (Pool_None)) & " - " & GLSL (Float (Pool_None - Pool_Most)) & " * u_wet;" & LF &
     "      vec2 hp = v_world.xy / 2048.0;" & LF &
     "      const float e = 1.0 / 2048.0;" & LF &
     "      vec2 sl = 0.5 * vec2(textureLod(u_height, hp + vec2(e, 0.0), 0.0).r - textureLod(u_height, hp - vec2(e, 0.0), 0.0).r," & LF &
     "                           textureLod(u_height, hp + vec2(0.0, e), 0.0).r - textureLod(u_height, hp - vec2(0.0, e), 0.0).r);" & LF &
     "      pool = smoothstep(lvl, lvl + mix(0.004, 0.03, m1), pn)" & LF &
     "             * (1.0 - smoothstep(" & GLSL (Float (Pool_Slope)) & ", " & GLSL (Float (2.0 * Pool_Slope)) & ", length(sl)));" & LF &
     "      if (pool > 0.0) {" & LF &
     "        wn = vec3(0.0, 0.0, 1.0);" & LF &
     "        if (u_rain > 0.0) wn = normalize(wn + vec3(rain_rings(tp), 0.0) * (0.35 * min(u_rain * 2.0, 1.0) * (1.0 - m1)));" & LF &
     "      }" & LF &
     "    }" & LF &
     "    float shine = mix((hard ? " & GLSL (Float (Wet_Shine_Hard)) & " : " & GLSL (Float (Wet_Shine_Soft))
     & ") * wet, 1.0, pool);" & LF &
     "    float glance = 1.0 - max(dot(wn, v), 0.0);" & LF &
     "    float fres = mix(0.03 + 0.97 * pow(glance, 5.0)," & LF &
     "                     " & GLSL (Float (Water_Mirror)) & " + " & GLSL (Float (1.0 - Water_Mirror))
     & " * pow(glance, " & GLSL (Float (Water_Glance)) & "), pool);" & LF &
     --  (a pool has the sky whole, clouds, sun and moon; a sheen only its
     --  tone, and nothing at all where it would not show: most of what is
     --  looked down on)
     "    float k = fres * shine * (1.0 - 0.6 * m2);" & LF &
     "    if (k > 0.015) {" & LF &
     "      vec3 rd = reflect(-v, wn);" & LF &
     "      rd = normalize(vec3(rd.xy, max(rd.z, 0.03)));" & LF &
     "      vec3 seen = (pool > 0.0) ? sky_at(rd, lit, 1.0)" & LF &
     "                               : mix(sky_back(rd) + glow(rd) * lit, cloud_tone(rd), 0.92 * smoothstep(0.25, 0.85, u_cover));" & LF &
     "      col = mix(col * (1.0 - " & GLSL (Float (Pool_Dark)) & " * pool), seen, k);" & LF &
     "    }" & LF &
     "    if (lit > 0.0 && sun > 0.0 && (hard || pool > 0.0))" & LF &
     "      col += u_lamp_col * lit * shine * (1.0 - pool) * " & GLSL (Float (Wet_Glint))
     & " * pow(max(dot(wn, normalize(u_lamp + v)), 0.0), 40.0) * (1.0 - m2);" & LF &
     "  }" & LF &
     "#endif" & LF &
     "  vec3 mir_c = vec3(0.0);" & LF &            --  the world mirrored in water: its colour,
     "  float mir_k = 0.0, mir_w = 0.0;" & LF &    --  how surely it was found, and its share of the pixel
     --  Water reflects the sky (clouds and sun included), more strongly the
     --  flatter it is seen; the sun's glint goes where the water is shaded.
     --  Falling water (side faces) gets pale streaks running down.
     "  if (u_water == 1) {" & LF &
     "    vec3 v = normalize(u_camera - v_world);" & LF &
     "    vec3 wn = n;" & LF &
     "    vec2 fl = vec2(0.0);" & LF &
     "    float sp = 0.0;" & LF &
     --  Flow map (after Valve's Portal 2 water): the ripples are read from
     --  upstream of where they show, by the current times a phase, so they
     --  travel with the water.  Two copies half a cycle apart cover each
     --  other's reset, and the cycle starts at a different moment from
     --  place to place so the resets never line up across the surface.
     --  Faster water is choppier.
     --  The sheet's own slope (it tilts where levels differ); steep
     --  sheets are falling water and get the streaks instead of ripples.
     "    vec3 gn = n;" & LF &
     "    float steep = 0.0;" & LF &
     "    bool air = v_fr == 0x100u;" & LF &                 --  the sheet of a fall (see the spec, "Falls")
     "    if (v_face == 4) {" & LF &
     "      gn = normalize(cross(dFdx(v_world), dFdy(v_world)));" & LF &
     "      if (gn.z < 0.0) gn = -gn;" & LF &
     "      steep = air ? 1.0 : 1.0 - smoothstep(0.45, 0.85, gn.z);" & LF &
     "    }" & LF &
     "    if (v_face == 4) {" & LF &
     "      vec2 q = v_world.xy;" & LF &
     "      fl = texture(u_flow, q / vec2(textureSize(u_flow, 0))).rg;" & LF &
     "      sp = length(fl);" & LF &
     "      float ph = u_time / 3.0 + texture(u_noise, q / 41.0).r;" & LF &
     "      float p0 = fract(ph);" & LF &
     "      float p1 = fract(ph + 0.5);" & LF &
     "      float bl = abs(2.0 * p0 - 1.0);" & LF &
     "      vec2 q0 = q - fl * (p0 * 3.0);" & LF &
     "      vec2 q1 = q - fl * (p1 * 3.0);" & LF &
     "      vec2 g0 = vec2(ripple(q0 + vec2(0.15, 0.0)) - ripple(q0 - vec2(0.15, 0.0)),"
     & " ripple(q0 + vec2(0.0, 0.15)) - ripple(q0 - vec2(0.0, 0.15)));" & LF &
     "      vec2 g1 = vec2(ripple(q1 + vec2(0.15, 0.0)) - ripple(q1 - vec2(0.15, 0.0)),"
     & " ripple(q1 + vec2(0.0, 0.15)) - ripple(q1 - vec2(0.0, 0.15)));" & LF &
     "      vec2 g = mix(g0, g1, bl) * (1.2 + 0.9 * min(sp, 1.5)) * (1.0 - steep);" & LF &
     --  (rain on the water: rings, as on a pool)
     "#ifdef WET" & LF &
     "      if (u_rain > 0.0) g -= rain_rings(q) * (0.5 * min(u_rain * 2.0, 1.0) * (1.0 - steep) * (1.0 - smoothstep(0.02, 0.2, fwidth(q.x))));" & LF &
     "#endif" & LF &
     "      wn = normalize(gn + vec3(-g, 0.0) * gn.z);" & LF &
     "    }" & LF &
     "    float fres = " & GLSL (Float (Water_Mirror)) & " + " & GLSL (Float (1.0 - Water_Mirror))
     & " * pow(1.0 - max(dot(wn, v), 0.0), " & GLSL (Float (Water_Glance)) & ");" & LF &
     --  What it mirrors: the world where the reflected ray meets it in
     --  the picture, the sky elsewhere.  (A ripple can tip the ray below
     --  the level; it is kept above it, or it would find the lake's own
     --  bed, which is in the picture under the water.)
     "    vec3 rd = reflect(-v, wn);" & LF &
     --  (u_reflect 2: far water too, in strides as long as its cells; 1: it mirrors the sky alone)
     "    if (u_reflect >= 1 && v_face == 4 && u_flowdbg == 0 && !air && (v_lod == 0 || u_reflect == 2)) {" & LF &
     "      vec3 ru = normalize(vec3(rd.xy, max(rd.z, 0.03)));" & LF &
     "      vec4 mir = mirrored(v_world, ru, float(1 << v_lod));" & LF &
     "      mir_c = mir.rgb;" & LF &
     "      mir_k = mir.a;" & LF &
     "    }" & LF &
     "    col = mix(col * 0.85, sky(rd, lit), fres * (1.0 - mir_k));" & LF &
     "    mir_w = fres * mir_k / max(1.0 - fres + fres * mir_k, 0.001);" & LF &
     --  How much of the bed shows: by the water looked through, never
     --  clearer than thin water ever was (a film on a fall, the sheet out
     --  of a cut still read as water).
     "    float through = wdepth / max(abs(v.z), 0.3);" & LF &
     "    float body = mix(" & GLSL (Float (Water_Thin_Alpha)) & ", " & GLSL (Float (Water_Deep_Alpha))
     & ", 1.0 - exp(-through / " & GLSL (Float (Water_Clear_M)) & "));" & LF &
     "    alpha = mix(body, max(body, 0.95), fres);" & LF &
     --  Ice grows out from the shores (a noise threshold) and takes snow.
     --  (The risers of stepped water freeze with the faces they join: a
     --  frozen stream is not striped with running water.)
     "    float iced = 0.0;" & LF &
     "    if (u_ice > 0.0) {" & LF &
     "      float ice = smoothstep(0.0, 0.15, u_ice * 1.6 - 0.6 * texture(u_noise, v_world.xy / 23.0).r);" & LF &
     "      vec3 light = amb + u_lamp_col * sun * lit;" & LF &
     "      vec3 ice_c = mix(vec3(0.74, 0.84, 0.92), vec3(0.92, 0.94, 0.98)," & LF &
     "                       ice * smoothstep(0.0, 0.05, snow_depth(v_world.z))) * light;" & LF &
     "      col = mix(col, ice_c, ice);" & LF &
     "      alpha = mix(alpha, 1.0, ice);" & LF &
     "      mir_w *= 1.0 - ice;" & LF &
     "      if (v_face < 4 || air) iced = ice;" & LF &
     "    }" & LF &
     "    float fall = (v_face < 4 || air) ? 1.0 - iced : steep;" & LF &
     "    mir_w *= 1.0 - fall;" & LF &
     "    if (fall > 0.0) {" & LF &
     --  (a sheet in the air: lit alike on every face, so that its slabs
     --  are one body and not boxes; mirroring nothing; whiter than a
     --  curtain on a face, with streaks that run over its top as well)
     "      if (air) {" & LF &
     "        float st = texture(u_noise, vec2((v_world.x + v_world.y) * 1.1, (v_world.z + 0.5 * (v_world.x - v_world.y)) / 3.5 + u_time * 0.8)).r;" & LF &
     "        vec3 light = amb + u_lamp_col * lit * 0.6;" & LF &
     "        vec3 sheet = mix(c.rgb * light, light * 0.9, " & GLSL (Float (Fall_White)) & " + " & GLSL (Float (Fall_Streak)) & " * smoothstep(0.40, 0.70, st));" & LF &
     "        col = mix(col, sheet, fall);" & LF &
     "        alpha = mix(alpha, " & GLSL (Float (Fall_Alpha)) & ", fall);" & LF &
     "      } else {" & LF &
     "        float st = texture(u_noise, vec2((v_world.x + v_world.y) / 3.0, v_world.z / 9.0 + u_time * 0.35)).r;" & LF &
     "        col = mix(col, mix(col, (amb + u_lamp_col * lit) * 0.8, 0.25 + 0.35 * smoothstep(0.45, 0.75, st)), fall);" & LF &
     "        alpha = mix(alpha, 0.88, fall);" & LF &
     "      }" & LF &
     "    }" & LF &     "    if (u_flowdbg == 1 && v_face == 4) {" & LF &
     "      col = vec3(0.5 + 0.5 * fl / max(sp, 0.001), min(sp / 1.5, 1.0));" & LF &
     "      alpha = 1.0;" & LF &
     "    }" & LF &
     "  }" & LF &
     --  The air between (haze, murk, mist: air, in the shared source).
     "  float thru;" & LF &
     "  g_slack = (u_water == 1) ? 1.0e4 : 0.125 * float(1 << v_lod);" & LF &
     "  col = air(col, v_world, thru);" & LF &
     --  (the mirrored world comes from the picture, graded already: it goes
     --  in after the grade, and fades with the distance and the weather as
     --  the water it lies on does)
     "  o_color = vec4(mix(grade(col), mir_c, mir_w * thru), alpha);" & LF &
     "}" & LF;

   function World_Fragment (Wet : Boolean) return String is
     ("#version 450 core" & LF & (if Wet then "#define WET" & LF else "") & World_Fragment_Body);

   --  Shadows from the sun (see the spec): for each of the two held
   --  directions, a depth map of the land and one of the figures.
   Shadow_Size    : constant := 4096;
   Figure_Size    : constant := 4096;
   Shadow_Program : UInt := 0;               --  the land into a depth map
   Caster_Program : UInt := 0;               --  the figures into one
   Shadows_Ready  : Boolean := False;
   Loc_S_VP, Loc_S_Camera, Loc_C_VP, Loc_C_Camera : int := -1;
   Changes        : Natural := 0;            --  meshes uploaded or dropped so far
   type Shadow_Key is array (1 .. 6) of Float;
   type Held_Map is record
      Tex, FBO         : UInt := 0;                         --  the land's shadows
      Fig_Tex, Fig_FBO : UInt := 0;                         --  the figures'
      Dir              : Vec3 := (0.0, 0.0, 1.0);           --  toward the sun, as held
      Lean             : Vec3 := (0.0, 0.0, 0.0);           --  where a shadow lies from what casts it, per metre of height
      VP, Fig_VP       : aliased Mat4 := (others => 0.0);   --  as the maps were last drawn
      Key              : Shadow_Key := (others => -1.0);    --  what the land's was drawn for
      --  the far map (see the spec, Far_Shadows): as it was last drawn
      Far_Tex, Far_FBO : UInt := 0;
      Far_VP           : aliased Mat4 := (others => 0.0);
      Far_Dir          : Vec3 := (0.0, 0.0, 0.0);           --  (none: not drawn yet)
      Far_Tiles, Far_Stacks : Natural := 0;                 --  the tiles' and the stacks' changes it was drawn at
      Far_Remade       : Natural := 0;                      --  and the tiles' remakings
      Far_At           : Natural := 0;                      --  the frame
      --  the near map's share of the far view: the tiles' changes it was drawn at, and the frame
      Seen_Far, Drawn_At : Natural := 0;
   end record;
   Far_Shadow_Size : constant := 4096;
   Far_Sh_Half     : constant := 1_470.0;   --  round the map's middle: all of it (2,048 m square, 256 high) from any side
   Far_Sh_Reach    : constant := 1_470.0;
   Far_Sh_Ready    : Boolean := False;
   Far_Sh_Tried    : Boolean := False;      --  (the two maps are made when first wanted: 64 MB of the card's memory)
   Far_Changes     : Natural := 0;          --  tiles of the far view come in or dropped so far
   Far_Remakes     : Natural := 0;          --  and tiles made again in place (for an edit)
   Far_Replacing   : Boolean := False;      --  (Upload_Far is putting a tile in the place of the one it had)
   Far_Casts       : Natural := 0;          --  far maps drawn so far
   Held       : array (0 .. 1) of Held_Map;
   From       : Natural range 0 .. 1 := 0;   --  Held (From): the sun has passed it; the other: it is coming to
   Held_Ok    : Boolean := False;
   Shadow_Mix : Float := 0.0;                --  how far the sun is from the one to the other
   Sun_Pace   : Float := 0.0;                --  how far shadows move in a frame, per metre of height (smoothed)
   Last_Lean  : Vec3 := (0.0, 0.0, 0.0);

   --  The fire's light and its shadows: a cube of depth maps about it.
   Fire_Size    : constant := 512;
   Fire_Tex     : UInt := 0;
   Fire_FBO     : array (0 .. 5) of UInt := [others => 0];    --  +X, -X, +Y, -Y, +Z, -Z
   Fire_Ready   : Boolean := False;
   Fire_At      : Vec3 := (0.0, 0.0, 0.0);  --  the light that casts this frame
   Fire_K       : Float := 0.0;             --  its strength (0: none casts)

   --  The lights (see the spec).  What the game gave this frame; of those,
   --  the ones whose reach comes into the view, nearest the focus first
   --  (Max_Lights at most), as the shaders have them; and which of those
   --  reach each cell of the world, a bit a light.
   type Light_Given is record
      At_P     : Vec3 := (0.0, 0.0, 0.0);
      Strength : Float := 0.0;
      Reach    : Float := Fire_Reach_M;
      Colour   : Vec3 := (1.0, 0.55, 0.22);
   end record;
   Max_Given : constant := 512;
   Given     : array (1 .. Max_Given) of Light_Given;
   Given_N   : Natural := 0;
   type GPU_Light is record
      X, Y, Z, Reach, R, G, B, K : Float32 := 0.0;
   end record with Convention => C;
   GPU_Lights : array (0 .. Max_Lights - 1) of aliased GPU_Light;
   type Light_Mask is record
      Lo, Hi : Unsigned_32 := 0;
   end record with Convention => C;
   type Light_Grid is array (0 .. Light_Cells - 1, 0 .. Light_Cells - 1) of aliased Light_Mask
     with Convention => C;                                       --  (y, x)
   type Light_Grid_Access is access Light_Grid;
   Grid         : constant Light_Grid_Access := new Light_Grid;
   Grid_Dirty   : Boolean := False;          --  the texture holds something
   Light_Buf    : UInt := 0;
   Light_Tex    : UInt := 0;
   Lights_Seen  : Natural := 0;              --  in the view this frame

   Noise_Tex   : UInt := 0;                --  tiling noise: clouds, ripples
   Puff_Tex    : UInt := 0;                --  tiling noise in three dimensions: the clouds' billows
   Base_Tex    : UInt := 0;                --  the land's level thereabouts, and how damp: what mist lies on
   Haze_Tex    : UInt := 0;                --  how deep the ground haze lies on the ground, for every 2 m

   --  The clouds' picture (see the spec): half the window each way.
   Cloud_Program            : UInt := 0;
   Cloud_FBO                : UInt := 0;
   Cloud_Tex                : aliased UInt := 0;
   Cloud_W, Cloud_H         : Natural := 0;
   Cloud_Ready              : Boolean := False;
   Clouds_Drawn             : Boolean := False;   --  this frame
   Loc_Vol, Loc_Px          : int := -1;
   Loc_Stars, Loc_Star_Turn, Loc_Drop : int := -1;
   Loc_C_Fwd, Loc_C_Right, Loc_C_Up : int := -1;

   --  The sky's view straight down, for snow and shelter.
   Snow_Size    : constant := 2048;
   Snow_Tex     : UInt := 0;
   Snow_FBO     : UInt := 0;
   Snow_Ready   : Boolean := False;
   Snow_VP      : aliased Mat4 := (others => 0.0);
   Snow_Drawn   : Shadow_Key := (others => -1.0);

   Precip_Program : UInt := 0;
   Box_Program    : UInt := 0;
   Box_Lo, Box_Hi : Vec3 := (0.0, 0.0, 0.0);
   Box_On         : Boolean := False;

   Current : Look;                         --  as last set
   Drift   : Vec3 := (0.0, 0.0, 0.0);      --  how far the clouds have blown (m)
   Last_Seconds : Float := 0.0;

   --  Uniforms several programs share, located once.
   type Program_Id is (P_World, P_World_Wet, P_Sky, P_Shadow, P_Precip, P_Figure, P_Blob, P_Cloud, P_Far);
   type Uniform_Id is
     (U_Sun, U_Sun_Glow, U_Sun_Disc, U_Moon, U_Moon_Col, U_Moon_K, U_Day, U_Lamp, U_Lamp_Col, U_Orb, U_Orb_Col,
      U_Zenith, U_Horizon, U_Sky_Amb, U_Gnd_Amb, U_Cover, U_Time, U_Drift,
      U_Eye, U_Snow, U_Ice, U_Wet, U_Leaf, U_Grass_Dry, U_Vis, U_Snow_VP, U_Fire,
      U_Light_A, U_Light_B, U_Fig_A, U_Fig_B, U_Shadow_Texel, U_Fig_Texel, U_Shadow_Mix, U_Fire_Cast,
      U_Mist, U_Mist_Col, U_Rain, U_Far, U_Floor, U_Focus, U_Fog, U_FarL_A, U_FarL_B, U_Far_Sh, U_Far_Sh2,
      U_GHaze, U_Rim);
   function Uniform_Name (U : Uniform_Id) return String is
     (case U is
         when U_Sun => "u_sun", when U_Sun_Glow => "u_sun_glow", when U_Sun_Disc => "u_sun_disc",
         when U_Moon => "u_moon", when U_Moon_Col => "u_moon_col", when U_Moon_K => "u_moon_k",
         when U_Day => "u_day", when U_Lamp => "u_lamp", when U_Lamp_Col => "u_lamp_col",
         when U_Orb => "u_orb", when U_Orb_Col => "u_orb_col", when U_Zenith => "u_zenith",
         when U_Horizon => "u_horizon", when U_Sky_Amb => "u_sky_amb", when U_Gnd_Amb => "u_gnd_amb",
         when U_Cover => "u_cover", when U_Time => "u_time", when U_Drift => "u_drift",
         when U_Eye => "u_eye", when U_Snow => "u_snow", when U_Ice => "u_ice", when U_Wet => "u_wet",
         when U_Leaf => "u_leaf", when U_Grass_Dry => "u_grass_dry", when U_Vis => "u_vis",
         when U_Snow_VP => "u_snow_vp", when U_Fire => "u_fire",
         when U_Light_A => "u_light_vp", when U_Light_B => "u_light_vp_b",
         when U_Fig_A => "u_fig_vp", when U_Fig_B => "u_fig_vp_b",
         when U_Shadow_Texel => "u_shadow_texel", when U_Fig_Texel => "u_fig_texel",
         when U_Shadow_Mix => "u_shadow_mix", when U_Fire_Cast => "u_fire_cast",
         when U_Mist => "u_mist", when U_Mist_Col => "u_mist_col", when U_Rain => "u_rain", when U_Far => "u_far",
         when U_Floor => "u_floor", when U_Focus => "u_focus", when U_Fog => "u_fog_dist",
         when U_FarL_A => "u_farl_vp", when U_FarL_B => "u_farl_vp_b",
         when U_Far_Sh => "u_far_sh", when U_Far_Sh2 => "u_far_sh2",
         when U_GHaze => "u_ghaze", when U_Rim => "u_rim");
   Programs : array (Program_Id) of UInt := (others => 0);
   Locs     : array (Program_Id, Uniform_Id) of int := (others => (others => -1));

   --  People: programs, the skin array, and the per-frame buffers.
   Fig_Program, Blob_Program, Mark_Program : UInt := 0;
   Mark_Buf : UInt := 0;
   Mark_Loc_VP, Mark_Loc_Camera, Mark_Loc_Dim : Int := -1;
   Skin_Tex : UInt := 0;
   Skin_Levels : constant := 4;              --  128 x 64 down to 16 x 8
   Fig_Bone_Buf, Fig_Box_Buf, Fig_Blob_Buf : UInt := 0;
   Fig_Loc_VP, Fig_Loc_Camera, Fig_Loc_Focus, Fig_Loc_Fog, Fig_Loc_A2C : int := -1;
   Blob_Loc_VP, Blob_Loc_Camera, Blob_Loc_Strength : int := -1;

   --  The far land (see the spec): its program, its corners' heights, its
   --  cells, and which stacks have a mesh of their own loaded.
   Far_Program  : UInt := 0;
   Far_Z_Tex, Far_Col_Tex, Far_Flag_Tex : UInt := 0;
   Far_Loc_VP, Far_Loc_Camera, Far_Loc_Focus, Far_Loc_Fog : int := -1;
   Far_Ready    : Boolean := False;
   Far_Flag     : aliased Unsigned_8 := 0;

   --  The far view (see the spec): a slot to every tile of every level, the
   --  loaded ones listed, and for every 16 m of the map which levels are
   --  loaded over it (bit L: level L), as the shader has it.
   Far_Side : constant := Chunks_XY / 2;            --  tiles a side at level 1; 16 m cells a side
   type Face_Counts is array (0 .. 5) of Natural;
   type Far_Slot is record
      Loaded           : Boolean := False;
      S_Start, S_Count : Natural := 0;
      By_Face          : Face_Counts := [others => 0];   --  its solid quads, which come face by face (+X, -X, +Y, -Y, +Z, -Z)
      Born             : Natural := 0;                   --  the frame it came in
      Coming           : Boolean := False;               --  still taking its pixels
      W_Start, W_Count : Natural := 0;
      Z_Lo, Z_Hi       : Integer := 0;             --  rows of its cells
      List_Pos         : Natural := 0;
   end record;
   type Far_Grid is array (1 .. Castle.Lod.Max_Level, 0 .. Far_Side - 1, 0 .. Far_Side - 1) of Far_Slot;
   type Far_Grid_Access is access Far_Grid;
   Far_Slots : constant Far_Grid_Access := new Far_Grid;
   type Far_Ref is record
      L, TX, TY : Integer := 0;
   end record;
   Max_Far   : constant := 16_384;
   Far_List  : array (1 .. Max_Far) of Far_Ref;
   Far_N     : Natural := 0;
   Far_Seen  : array (1 .. Max_Far) of Positive;    --  those drawn this frame
   Far_Quads : Natural := 0;
   Far_Drawn : Natural := 0;
   Far_Sent  : Natural := 0;                       --  solid quads of theirs sent this frame
   type Level_Shares is array (1 .. Castle.Lod.Max_Level) of aliased Unsigned_8 with Convention => C;
   type Have_Grid is array (0 .. Far_Side - 1, 0 .. Far_Side - 1) of aliased Level_Shares with Convention => C;   --  (y, x)
   Far_Have       : Have_Grid := [others => [others => [others => 0]]];
   --  (255: that level's tile is loaded there; less: it has just come and is taking its pixels)
   Far_Frame      : Natural := 0;                  --  frames drawn
   Far_Coming     : Natural := 0;                  --  tiles still taking their pixels
   Far_Have_Tex   : UInt := 0;
   Far_Have_Dirty : Boolean := False;
   Far_View_Loc, Zp_Loc : array (Boolean) of int := [others => -1];

   Sky_Program : UInt := 0;
   pragma Warnings (Off, Sky_Program);
   Sky_VAO     : UInt := 0;
   Loc_Fwd, Loc_Right, Loc_Up : int := -1;

   --  Daylight, set by Set_Look; every program carries the same values.
   type Daylight is record
      Sun, Sun_Glow, Zenith, Horizon, Sky_Amb, Gnd_Amb : Vec3;   --  Sun: toward it, wherever it is
      Sun_Disc       : Vec3;                --  the sun's disc as it is seen
      Moon, Moon_Col : Vec3;                --  toward the moon; its lit face (nothing while it is down)
      Moon_K         : Float := 0.0;        --  the light it gives the sky: by its phase, none by day
      Lamp, Lamp_Col : Vec3;                --  what lights the land: toward it, and its light
      Orb, Orb_Col   : Vec3;                --  what lights the clouds, and its light before any cloud
      Lit : Float := 1.0;                   --  night 0 .. day 1, whatever the weather
   end record;
   Day : Daylight;

   Max_Draws : constant := 32_768;          --  camera draws, then shadow draws
   Max_Spans : constant := 16_384;

   type Cmd is record
      Count, Instances, First, Base : Unsigned_32 := 0;
   end record;
   type Origin is record
      X, Y, Z, W : Integer_32 := 0;
   end record;
   type Cmd_Array is array (0 .. Max_Draws - 1) of aliased Cmd;
   type Origin_Array is array (0 .. Max_Draws - 1) of aliased Origin;
   type Cmd_Access is access Cmd_Array;
   type Origin_Access is access Origin_Array;

   Cmds    : constant Cmd_Access := new Cmd_Array;
   Origins : constant Origin_Access := new Origin_Array;

   Program, VAO, Quad_Buf, Cmd_Buf, Origin_Buf, Tex, Height_Tex : UInt := 0;

   --  The land's program is built twice: without the wet look and with it
   --  (World_Fragment).  Program and the Loc_ variables below are those of
   --  the one in use (Use_World).
   type World_Locs is record
      VP, Camera, Focus, A2C, Fog_Dist, Variants, Water, Blend, Wmask, Flowdbg, Wstep, Reflect : int := -1;
      Roofs, Roof_A, Roof_B, Roof_F, Roof_Box : int := -1;   --  houses cleared (Castle.Cutaway)
   end record;
   World_Prog : array (Boolean) of UInt := [others => 0];
   World_Loc  : array (Boolean) of World_Locs;

   --  Surface water and the flow map (see the spec).
   Lv_Tex, Flow_Tex : UInt := 0;
   Lv_Size          : Integer := 2048;             --  texels a side of the surface texture
   Loc_Blend, Loc_Wmask, Loc_Flowdbg, Loc_Wstep : int := -1;
   Water_Steps      : Natural := 0;                --  steps to a block the water is drawn in (0: one sheet)
   Blend_Now        : Float := 1.0;
   Flow_Debug       : Boolean := False;
   A2C : Boolean := False;

   --  The multisampled target the world is drawn into, resolved each frame.
   MSAA               : Natural := 0;
   Target             : UInt := 0;
   Color_RB, Depth_RB : aliased UInt := 0;
   Target_W, Target_H : Natural := 0;

   --  The picture so far, read back for the water's reflections: the solid
   --  world and the people, resolved out of the multisampled target into
   --  two textures (colour, and depth) just before the sky and the water
   --  are drawn.
   Scene_FBO          : UInt := 0;
   Scene_Col, Scene_Z : aliased UInt := 0;
   Scene_Ready        : Boolean := False;
   Loc_Reflect        : int := -1;
   Loc_VP, Loc_Camera, Loc_Focus, Loc_A2C, Loc_Fog_Dist, Loc_Variants, Loc_Water : int := -1;

   --  Free spans of the quad arena, sorted by start.
   type Span is record
      Start, Length : Natural := 0;
   end record;
   Spans      : array (1 .. Max_Spans) of Span;
   Span_N     : Natural := 0;
   Free_Quads : Natural := 0;

   type Slot is record
      Loaded           : Boolean := False;
      S_Start, S_Count : Natural := 0;
      S_Cast           : Natural := 0;     --  the first of them, which can cast a shadow (Castle.Mesher.Mesh.Cast)
      W_Start, W_Count : Natural := 0;
      Z_Lo, Z_Hi       : Integer := 0;
      List_Pos         : Natural := 0;
   end record;
   type Slot_Grid is array (0 .. Chunks_XY - 1, 0 .. Chunks_XY - 1) of Slot;
   type Slot_Grid_Access is access Slot_Grid;
   Slots : constant Slot_Grid_Access := new Slot_Grid;

   type Coord is record
      CX, CY : Integer := 0;
   end record;
   Max_Loaded  : constant := 16_384;
   Loaded_List : array (1 .. Max_Loaded) of Coord;
   Loaded_N    : Natural := 0;
   Visible     : array (1 .. Max_Loaded) of Positive;
   Near_Order  : array (1 .. Max_Loaded) of Positive;   --  the same, the nearest to the eye first
   Quads_Total : Natural := 0;
   Draws       : Natural := 0;
   Skipped     : Natural := 0;       --  stacks the arena had no room for, so far
   Draws_Short : Boolean := False;   --  a frame has wanted more draws than Max_Draws

   --  Ring of GPU timer queries: a slot is read just before it is reused,
   --  four frames after it was issued.
   type Query_Ring is array (0 .. 3) of aliased UInt;
   Queries     : Query_Ring := [others => 0];
   Issued      : Natural := 0;
   Last_GPU_Ms : Float := 0.0;

   ---------------------------------------------------------------- arena

   function Alloc (N : Positive) return Integer is
   begin
      for I in 1 .. Span_N loop
         if Spans (I).Length >= N then
            declare
               S : constant Natural := Spans (I).Start;
            begin
               Spans (I).Start := S + N;
               Spans (I).Length := Spans (I).Length - N;
               if Spans (I).Length = 0 then
                  Spans (I .. Span_N - 1) := Spans (I + 1 .. Span_N);
                  Span_N := Span_N - 1;
               end if;
               Free_Quads := Free_Quads - N;
               return S;
            end;
         end if;
      end loop;
      return -1;
   end Alloc;

   procedure Release (Start, N : Natural) is
      I : Positive := 1;
   begin
      if N = 0 then
         return;
      end if;
      Free_Quads := Free_Quads + N;
      while I <= Span_N and then Spans (I).Start < Start loop
         I := I + 1;
      end loop;
      if I > 1 and then Spans (I - 1).Start + Spans (I - 1).Length = Start then
         Spans (I - 1).Length := Spans (I - 1).Length + N;
         if I <= Span_N and then Spans (I - 1).Start + Spans (I - 1).Length = Spans (I).Start then
            Spans (I - 1).Length := Spans (I - 1).Length + Spans (I).Length;
            Spans (I .. Span_N - 1) := Spans (I + 1 .. Span_N);
            Span_N := Span_N - 1;
         end if;
      elsif I <= Span_N and then Start + N = Spans (I).Start then
         Spans (I).Start := Start;
         Spans (I).Length := Spans (I).Length + N;
      elsif Span_N < Max_Spans then
         Spans (I + 1 .. Span_N + 1) := Spans (I .. Span_N);
         Spans (I) := (Start, N);
         Span_N := Span_N + 1;
      else
         Free_Quads := Free_Quads - N;            --  too fragmented: leak the span
      end if;
   end Release;

   ---------------------------------------------------------------- shaders

   function Compile (Kind : Enum; Source : String) return UInt is
      Shader : constant UInt := Create_Shader (Kind);
      Text   : aliased chars_ptr := New_String (Source);
      Ok     : int := 0;
   begin
      Shader_Source (Shader, 1, Text'Address, Null_Address);
      Compile_Shader (Shader);
      Free (Text);
      Get_Shader_Iv (Shader, Compile_Status, Ok);
      if Ok = 0 then
         declare
            Log : aliased char_array (1 .. 4_096) := (others => nul);
            Len : Sizei := 0;
         begin
            Get_Shader_Info_Log (Shader, Log'Length, Len, Log'Address);
            raise Program_Error with "shader compile failed:" & LF & To_Ada (Log);
         end;
      end if;
      return Shader;
   end Compile;

   function Link (V, F : UInt) return UInt is
      P  : constant UInt := Create_Program;
      Ok : int := 0;
   begin
      Attach_Shader (P, V);
      Attach_Shader (P, F);
      Link_Program (P);
      Get_Program_Iv (P, Link_Status, Ok);
      if Ok = 0 then
         declare
            Log : aliased char_array (1 .. 4_096) := (others => nul);
            Len : Sizei := 0;
         begin
            Get_Program_Info_Log (P, Log'Length, Len, Log'Address);
            raise Program_Error with "shader link failed:" & LF & To_Ada (Log);
         end;
      end if;
      Delete_Shader (V);
      Delete_Shader (F);
      return P;
   end Link;

   function Location (Name : String; In_Program : UInt := 0) return int is
      C : chars_ptr := New_String (Name);
      L : constant int := Get_Uniform_Location ((if In_Program = 0 then Program else In_Program), C);
   begin
      Free (C);
      return L;
   end Location;

   --  Which of the land's two programs is in use: the one with the wet look
   --  or the one without (see World_Fragment_Body).
   procedure Use_World (Wet : Boolean) is
      L : World_Locs renames World_Loc (Wet);
   begin
      Program      := World_Prog (Wet);
      Loc_VP       := L.VP;
      Loc_Camera   := L.Camera;
      Loc_Focus    := L.Focus;
      Loc_A2C      := L.A2C;
      Loc_Fog_Dist := L.Fog_Dist;
      Loc_Variants := L.Variants;
      Loc_Water    := L.Water;
      Loc_Blend    := L.Blend;
      Loc_Wmask    := L.Wmask;
      Loc_Flowdbg  := L.Flowdbg;
      Loc_Wstep    := L.Wstep;
      Loc_Reflect  := L.Reflect;
   end Use_World;

   --  The roofs cleared on the camera's ray, to the program in use
   --  (Castle.Cutaway: drawing only).
   procedure Put_Roofs is
      type Vec4_Array is array (1 .. Castle.Cutaway.Max_Roofs, 1 .. 4) of Float32;
      type F_Array is array (1 .. Castle.Cutaway.Max_Roofs) of Float32;
      A, B : Vec4_Array := [others => [others => 0.0]];
      F    : F_Array := [others => 0.0];
      N    : constant Natural := Natural'Min (Castle.Cutaway.Count, Castle.Cutaway.Max_Roofs);
      Loc  : World_Locs renames World_Loc (Program = World_Prog (True));
      X0, Y0 : Float := Float'Last;
      X1, Y1 : Float := Float'First;
   begin
      for K in 1 .. N loop
         declare
            C : constant Castle.Cutaway.Cleared := Castle.Cutaway.Shown (K);
            Reach : constant Float := C.R.Half_A + C.R.Half_B + 1.0;      --  (further than any corner or eave)
         begin
            X0 := Float'Min (X0, C.R.Centre.X - Reach);  X1 := Float'Max (X1, C.R.Centre.X + Reach);
            Y0 := Float'Min (Y0, C.R.Centre.Y - Reach);  Y1 := Float'Max (Y1, C.R.Centre.Y + Reach);
            A (K, 1) := Float32 (C.R.Centre.X);  A (K, 2) := Float32 (C.R.Centre.Y);
            A (K, 3) := Float32 (C.R.Along.X);   A (K, 4) := Float32 (C.R.Along.Y);
            B (K, 1) := Float32 (C.R.Half_A);    B (K, 2) := Float32 (C.R.Half_B);
            B (K, 3) := Float32 (C.R.Centre.Z);  B (K, 4) := Float32 (C.R.Top_Z);
            F (K) := Float32 (C.Amount);
         end;
      end loop;
      Program_Uniform_1i (Program, Loc.Roofs, int (N));
      if N > 0 then
         Program_Uniform_4fv (Program, Loc.Roof_A, Sizei (N), A'Address);
         Program_Uniform_4fv (Program, Loc.Roof_B, Sizei (N), B'Address);
         Program_Uniform_1fv (Program, Loc.Roof_F, Sizei (N), F'Address);
         declare
            Box : constant array (1 .. 4) of Float32 := [Float32 (X0), Float32 (Y0), Float32 (X1), Float32 (Y1)];
         begin
            Program_Uniform_4fv (Program, Loc.Roof_Box, 1, Box'Address);
         end;
      end if;
   end Put_Roofs;

   ---------------------------------------------------------------- daylight

   function Mix (A, B : Vec3; T : Float) return Vec3 is (A + (B - A) * T);

   function Smooth (E0, E1, X : Float) return Float is
      T : constant Float := Float'Max (0.0, Float'Min (1.0, (X - E0) / (E1 - E0)));
   begin
      return T * T * (3.0 - 2.0 * T);
   end Smooth;

   procedure Put (U : Uniform_Id; X : Float) is
   begin
      for P in Program_Id loop
         if Locs (P, U) >= 0 then
            Program_Uniform_1f (Programs (P), Locs (P, U), Float32 (X));
         end if;
      end loop;
   end Put;

   procedure Put_Int (Name : String; X : Integer) is
   begin
      for P of Programs loop
         declare
            L : constant int := Location (Name, P);
         begin
            if L >= 0 then
               Program_Uniform_1i (P, L, int (X));
            end if;
         end;
      end loop;
   end Put_Int;

   procedure Put (U : Uniform_Id; X, Y : Float) is
   begin
      for P in Program_Id loop
         if Locs (P, U) >= 0 then
            Program_Uniform_2f (Programs (P), Locs (P, U), Float32 (X), Float32 (Y));
         end if;
      end loop;
   end Put;

   procedure Put (U : Uniform_Id; V : Vec3) is
   begin
      for P in Program_Id loop
         if Locs (P, U) >= 0 then
            Program_Uniform_3f (Programs (P), Locs (P, U), Float32 (V.X), Float32 (V.Y), Float32 (V.Z));
         end if;
      end loop;
   end Put;

   procedure Put (U : Uniform_Id; M : Mat4) is
      Copy : aliased Mat4 := M;
   begin
      for P in Program_Id loop
         if Locs (P, U) >= 0 then
            Program_Uniform_Matrix_4fv (Programs (P), Locs (P, U), 1, GL_False, Copy (0)'Address);
         end if;
      end loop;
   end Put;

   function Grey (V : Vec3; K : Float) return Vec3 is
      L : constant Float := (0.3 * V.X + 0.59 * V.Y + 0.11 * V.Z) * K;
   begin
      return (L, L, L);
   end Grey;

   --  The sun at latitude 47 degrees on a 60-day year: declination swings
   --  23.4 degrees about the equinoxes, peaking at mid-summer (day 22).
   function Sun_At (Day_Of_Year, Hour : Float) return Vec3 is
      use Ada.Numerics.Elementary_Functions;
      Pi  : constant := Ada.Numerics.Pi;
      Lat : constant Float := 47.0 * Pi / 180.0;
      Dec : constant Float := 0.408_4 * Cos (2.0 * Pi * (Day_Of_Year - 22.0) / 60.0);
      H   : constant Float := Pi * (Hour - 12.0) / 12.0;
   begin
      return (-Cos (Dec) * Sin (H),
              Sin (Dec) * Cos (Lat) - Cos (Dec) * Cos (H) * Sin (Lat),
              Sin (Dec) * Sin (Lat) + Cos (Dec) * Cos (H) * Cos (Lat));
   end Sun_At;

   function Luma (V : Vec3) return Float is (0.3 * V.X + 0.59 * V.Y + 0.11 * V.Z);

   --  The moon (see the spec): Phase of the way round from the sun (0 new,
   --  0.5 full), so it rises that share of a day after the sun does, and
   --  stands as high as the sun does that share of a year on: a full moon
   --  is where the sun is not.
   function Moon_At (Day_Of_Year, Hour, Phase : Float) return Vec3 is
      use Ada.Numerics.Elementary_Functions;
      Pi  : constant := Ada.Numerics.Pi;
      Lat : constant Float := 47.0 * Pi / 180.0;
      Phi : constant Float := 2.0 * Pi * Phase;
      Dec : constant Float := 0.408_4 * Cos (2.0 * Pi * (Day_Of_Year - 22.0) / 60.0 + Phi);
      H   : constant Float := Pi * (Hour - 12.0) / 12.0 - Phi;
   begin
      return (-Cos (Dec) * Sin (H),
              Sin (Dec) * Cos (Lat) - Cos (Dec) * Cos (H) * Sin (Lat),
              Sin (Dec) * Sin (Lat) + Cos (Dec) * Cos (H) * Cos (Lat));
   end Moon_At;

   --  How much of the moon's face is lit, 0 new .. 1 full.
   function Moon_Lit (Phase : Float) return Float is
     (0.5 - 0.5 * Ada.Numerics.Elementary_Functions.Cos (2.0 * Ada.Numerics.Pi * Phase));

   --  What lights the land: the sun while any of its light is left (it is
   --  gone Sun_Gone under the horizon), then the moon.  The one's light is
   --  nothing where the other takes over, so nothing jumps.  Both the
   --  daylight and the shadows' held directions go by this one routine.
   function Sun_Share (Se : Float) return Float is (Smooth (Sun_Gone, 0.06, Se));
   function Moon_Share (Se, Moon_Z, Phase : Float) return Float is
     (Moonlight * Ada.Numerics.Elementary_Functions."**" (Moon_Lit (Phase), 1.3)
      * Smooth (0.02, 0.25, Moon_Z) * Smooth (-Sun_Gone, 0.15, -Se));
   function Lamp_At (Day_Of_Year, Hour, Phase : Float) return Vec3 is
      Sun : constant Vec3 := Sun_At (Day_Of_Year, Hour);
   begin
      return (if Sun.Z > Sun_Gone then Sun else Moon_At (Day_Of_Year, Hour, Phase));
   end Lamp_At;

   --  Overcast skies turn grey and take most of the sun's direct light.
   procedure Daylight_For (L : Look) is
      Sun : constant Vec3 := Sun_At (L.Day, L.Hour);
      Se  : constant Float := Sun.Z;
      Lit : constant Float := Smooth (-0.15, 0.08, Se);           --  night 0 .. day 1
      Low : constant Float := 1.0 - Smooth (0.0, 0.40, Se);       --  a low, warm sun
      Oc  : constant Float := Smooth (0.45, 1.0, L.Cloud_Cover);  --  overcast
      Tint : constant Vec3 := Mix ((1.0, 0.95, 0.86), (1.0, 0.55, 0.30), Low);
      Moon : constant Vec3 := Moon_At (L.Day, L.Hour, L.Moon);
      Full : constant Float := Moon_Lit (L.Moon);
      Up   : constant Float := Smooth (-0.01, 0.08, Moon.Z);       --  the moon out of the haze
   begin
      Day.Sun := Sun;
      Day.Lit := Lit;
      Day.Sun_Glow := Tint * (0.72 * Sun_Share (Se) * (1.0 - 0.9 * Oc));
      --  The disc is the sun itself, not its light on the land: as bright
      --  under cloud and on the horizon as at noon, and redder low down.
      Day.Sun_Disc := Mix ((1.45, 1.39, 1.29), (1.35, 0.66, 0.30), Low);
      --  The moon: warm as it comes up out of the haze, pale high up.
      Day.Moon := Moon;
      Day.Moon_Col := Mix ((0.95, 0.80, 0.62), (0.86, 0.89, 0.96), Smooth (0.0, 0.30, Moon.Z)) * Up;
      Day.Moon_K := Full * Up * (1.0 - Lit);
      --  The land's light (Lamp_At): the sun's, or the moon's by its phase
      --  and its height once the sun's is gone; overcast takes most of either.
      if Se > Sun_Gone then
         Day.Lamp := Sun;
         Day.Lamp_Col := Day.Sun_Glow;
      else
         Day.Lamp := Moon;
         Day.Lamp_Col := Vec3'(0.56, 0.66, 1.0) * (Moon_Share (Se, Moon.Z, L.Moon) * (1.0 - 0.9 * Oc));
      end if;
      --  The clouds are lit by the sun for as long as it reaches them (from
      --  under the horizon it still lights their undersides), then by the
      --  moon, by its phase; the one is gone before the other comes.
      if Se > -0.09 then
         Day.Orb := Sun;
         Day.Orb_Col := Mix ((1.0, 0.96, 0.90), (1.0, 0.50, 0.26), Low) * (0.78 * Smooth (-0.09, 0.05, Se));
      else
         Day.Orb := Moon;
         Day.Orb_Col := Vec3'(0.10, 0.12, 0.17) * (Smooth (0.09, 0.24, -Se) * Full * Smooth (-0.02, 0.15, Moon.Z));
      end if;
      Day.Zenith  := Mix ((0.008, 0.012, 0.03), Mix ((0.24, 0.44, 0.78), (0.20, 0.28, 0.48), Low), Lit);
      Day.Horizon := Mix ((0.03, 0.04, 0.07), Mix ((0.66, 0.76, 0.88), (0.98, 0.62, 0.38), Low), Lit);
      Day.Zenith  := Mix (Day.Zenith, Grey (Day.Zenith, 1.3), 0.7 * Oc);
      Day.Horizon := Mix (Day.Horizon, Grey (Day.Horizon, 0.95), 0.6 * Oc);
      --  Night keeps a moonlit blue: dark, but a colony has to stay readable.
      Day.Sky_Amb := Mix ((0.11, 0.13, 0.20), Mix ((0.42, 0.46, 0.52), (0.40, 0.36, 0.40), Low), Lit)
                       * (1.0 + 0.12 * Oc);
      Day.Gnd_Amb := Mix ((0.04, 0.045, 0.06), (0.24, 0.22, 0.20), Lit);
   end Daylight_For;

   procedure Clear_Lights is
   begin
      Given_N := 0;
   end Clear_Lights;

   procedure Add_Light (At_P : Vec3; Strength : Float; Reach_M : Float := Fire_Reach_M;
                        Colour : Vec3 := (1.0, 0.55, 0.22)) is
   begin
      if Strength > 0.0 and then Reach_M > 0.0 and then Given_N < Max_Given then
         Given_N := Given_N + 1;
         Given (Given_N) := (At_P, Strength, Reach_M, Colour);
      end if;
   end Add_Light;

   function Lights_In_View return Natural is (Lights_Seen);

   --  This frame's lights for the shaders: those whose reach comes into the
   --  view, the nearest to the focus first and Max_Lights at most; the one
   --  that casts (the nearest, if its reach suits the depth maps); and
   --  which of them reach each cell.
   procedure Place_Lights (Focus : Vec3; Fog_Distance : Float) is
      Order : array (0 .. Max_Lights - 1) of Positive := [others => 1];      --  into Given
      Dist  : array (0 .. Max_Lights - 1) of Float := [others => 0.0];
      N     : Natural := 0;
      By_Day : constant Float := 1.0 - (1.0 - Fire_By_Day) * Day.Lit;
   begin
      for I in 1 .. Given_N loop
         declare
            Dx : constant Float := Given (I).At_P.X - Focus.X;
            Dy : constant Float := Given (I).At_P.Y - Focus.Y;
            D  : constant Float := Ada.Numerics.Elementary_Functions.Sqrt (Dx * Dx + Dy * Dy);
            At_K : Natural;
         begin
            if D < Fog_Distance + Given (I).Reach and then (N < Max_Lights or else D < Dist (N - 1)) then
               At_K := Natural'Min (N, Max_Lights - 1);
               while At_K > 0 and then Dist (At_K - 1) > D loop
                  Order (At_K) := Order (At_K - 1);
                  Dist (At_K) := Dist (At_K - 1);
                  At_K := At_K - 1;
               end loop;
               Order (At_K) := I;
               Dist (At_K) := D;
               N := Natural'Min (N + 1, Max_Lights);
            end if;
         end;
      end loop;
      Lights_Seen := N;
      if N = 0 and then not Grid_Dirty then
         Fire_K := 0.0;
         Put_Int ("u_light_n", 0);
         return;
      end if;
      Grid.all := [others => [others => (0, 0)]];
      for K in 0 .. N - 1 loop
         declare
            L  : Light_Given renames Given (Order (K));
            X0 : constant Integer := Integer'Max (0, Integer (Float'Floor ((L.At_P.X - L.Reach) / Float (Light_Cell_M))));
            X1 : constant Integer :=
              Integer'Min (Light_Cells - 1, Integer (Float'Floor ((L.At_P.X + L.Reach) / Float (Light_Cell_M))));
            Y0 : constant Integer := Integer'Max (0, Integer (Float'Floor ((L.At_P.Y - L.Reach) / Float (Light_Cell_M))));
            Y1 : constant Integer :=
              Integer'Min (Light_Cells - 1, Integer (Float'Floor ((L.At_P.Y + L.Reach) / Float (Light_Cell_M))));
         begin
            GPU_Lights (K) := (Float32 (L.At_P.X), Float32 (L.At_P.Y), Float32 (L.At_P.Z), Float32 (L.Reach),
                               Float32 (L.Colour.X), Float32 (L.Colour.Y), Float32 (L.Colour.Z),
                               Float32 (L.Strength * By_Day));
            for Y in Y0 .. Y1 loop
               for X in X0 .. X1 loop
                  if K < 32 then
                     Grid (Y, X).Lo := Grid (Y, X).Lo or Shift_Left (Unsigned_32'(1), K);
                  else
                     Grid (Y, X).Hi := Grid (Y, X).Hi or Shift_Left (Unsigned_32'(1), K - 32);
                  end if;
               end loop;
            end loop;
         end;
      end loop;
      Texture_Sub_Image_2D (Light_Tex, 0, 0, 0, Light_Cells, Light_Cells, RG_Integer, Unsigned_Int,
                            Grid (0, 0)'Address);
      Grid_Dirty := N > 0;
      if N > 0 then
         Named_Buffer_Sub_Data (Light_Buf, 0, Sizeiptr (N * 32), GPU_Lights (0)'Address);
      end if;
      Put_Int ("u_light_n", N);
      --  The nearest to the focus casts, if the depth maps about it reach as
      --  far as its light does.
      if N > 0 and then Given (Order (0)).Reach <= Fire_Reach_M then
         Fire_At := Given (Order (0)).At_P;
         Fire_K := Given (Order (0)).Strength;
      else
         Fire_K := 0.0;
      end if;
      Put (U_Fire, Fire_At);
   end Place_Lights;

   procedure Set_Look (L : Look) is
      Dt : constant Float := Float'Max (0.0, Float'Min (0.5, L.Seconds - Last_Seconds));
   begin
      Last_Seconds := L.Seconds;
      --  Clouds blow with the wind; the noise repeats every 14 km, so the
      --  drift wraps there and keeps its precision.
      Drift := (Drift.X + 1.5 * L.Wind_X * Dt, Drift.Y + 1.5 * L.Wind_Y * Dt, 0.0);
      Drift := (Drift.X - 14_000.0 * Float'Floor (Drift.X / 14_000.0),
                Drift.Y - 14_000.0 * Float'Floor (Drift.Y / 14_000.0), 0.0);
      Current := L;
      Daylight_For (L);
      Put (U_Sun, Day.Sun);
      Put (U_Sun_Glow, Day.Sun_Glow);
      Put (U_Sun_Disc, Day.Sun_Disc);
      Put (U_Moon, Day.Moon);
      Put (U_Moon_Col, Day.Moon_Col);
      Put (U_Moon_K, Day.Moon_K);
      Put (U_Day, Day.Lit);
      Put (U_Lamp, Day.Lamp);
      Put (U_Lamp_Col, Day.Lamp_Col);
      --  The stars: out as the day goes, fewer by a bright moon; the sky
      --  turns about the pole once a day, and once more in a year.
      declare
         use Ada.Numerics.Elementary_Functions;
         A : constant Float := 2.0 * Ada.Numerics.Pi * (L.Hour / 24.0 + L.Day / 60.0);
      begin
         Program_Uniform_1f (Sky_Program, Loc_Stars,
                             Float32 ((if Stars then (1.0 - Day.Lit) ** 2 * (1.0 - 0.45 * Day.Moon_K) else 0.0)));
         Program_Uniform_2f (Sky_Program, Loc_Star_Turn, Float32 (Cos (A)), Float32 (Sin (A)));
      end;
      Put (U_Orb, Day.Orb);
      Put (U_Orb_Col, Day.Orb_Col);
      Put (U_Zenith, Day.Zenith);
      Put (U_Horizon, Day.Horizon);
      Put (U_Sky_Amb, Day.Sky_Amb);
      Put (U_Gnd_Amb, Day.Gnd_Amb);
      Put (U_Cover, L.Cloud_Cover);
      Put (U_Time, L.Seconds);
      Put (U_Drift, Drift.X, Drift.Y);
      Put (U_Snow, Vec3'(L.Snow_Lo, L.Snow_Mid, L.Snow_Hi));
      Put (U_Ice, L.Ice);
      Put (U_Wet, (if Wetness then Float'Max (0.0, Float'Min (1.0, L.Wet)) else 0.0));
      Put (U_Rain, L.Rain);
      Put (U_Leaf, L.Leaf_Turn, L.Leaf_Fall);
      Put (U_Grass_Dry, L.Grass_Dry);
      Put (U_Vis, 0.010 * L.Snowfall + 0.005 * L.Rain + 0.002 * L.Cloud_Cover ** 2);
      Put (U_Mist, (if Mists then Float'Max (0.0, Float'Min (1.0, L.Mist)) else 0.0));
      --  Mist is lit by the sky it lies under: pale by day, warm at dawn, a
      --  faint blue at night.
      Put (U_Mist_Col, Day.Horizon * 0.6 + Day.Sky_Amb * 0.9);
   end Set_Look;

   ---------------------------------------------------------------- setup

   --  A set of materials for the shaders (in_set): bit k is material k, in
   --  two 32-bit words.
   function Bit (M : Castle.Blocks.Material) return Unsigned_64 is
     (Shift_Left (Unsigned_64'(1), Castle.Blocks.Material'Pos (M)));

   procedure Put_Set (P : UInt; Name : String; S : Unsigned_64) is
   begin
      Program_Uniform_2ui (P, Location (Name, P), UInt (S and 16#FFFF_FFFF#), UInt (Shift_Right (S, 32)));
   end Put_Set;

   --  A square depth texture to draw into and to look up with a comparison
   --  (filtered: each tap is the share of its four texels that pass).
   procedure Make_Depth_Map (Size : Positive; Format : Enum; Tex, FBO : out UInt; Ok : out Boolean) is
   begin
      Create_Textures (Texture_2D, 1, Tex);
      Texture_Storage_2D (Tex, 1, Format, Sizei (Size), Sizei (Size));
      Texture_Parameter_I (Tex, Texture_Min_Filter, Linear);
      Texture_Parameter_I (Tex, Texture_Mag_Filter, Linear);
      Texture_Parameter_I (Tex, Texture_Wrap_S, Clamp_To_Edge);
      Texture_Parameter_I (Tex, Texture_Wrap_T, Clamp_To_Edge);
      Texture_Parameter_I (Tex, Texture_Compare_Mode, Compare_Ref_To_Texture);
      Texture_Parameter_I (Tex, Texture_Compare_Func, int (Lequal));
      Create_Framebuffers (1, FBO);
      Named_Framebuffer_Texture (FBO, Depth_Attachment, Tex, 0);
      Named_Framebuffer_Draw_Buffer (FBO, No_Buffer);
      Named_Framebuffer_Read_Buffer (FBO, No_Buffer);
      Ok := Check_Named_Framebuffer_Status (FBO, Framebuffer) = Framebuffer_Complete;
   end Make_Depth_Map;

   procedure Init (W : Castle.Maps.World; Capacity_Quads : Positive; Samples : Natural) is
      use Castle.Blocks;
      Ground : Unsigned_64 := 0;
   begin
      --  Materials that follow the terrain surface: lit from the height
      --  field at a distance.
      for M in Material loop
         if M not in Air | Water | Boulder | Trunk | Crown | Berry_Bush | Bare_Bush | Plank | Shingle | Thatch | Daub
                     | Fieldstone
         then
            Ground := Ground or Bit (M);
         end if;
      end loop;
      declare
         Most : int := 0;
      begin
         Get_Integer_V (Max_Samples, Most);
         MSAA := (if Samples >= 2 then Natural'Min (Samples, Natural (Most)) else 0);
         if MSAA < 2 then
            MSAA := 0;
         end if;
      end;
      A2C := MSAA > 0;
      for Wet in Boolean loop
         World_Prog (Wet) := Link (Compile (Vertex_Shader, Vertex_Source),
                                   Compile (Fragment_Shader, World_Fragment (Wet)));
         Program := World_Prog (Wet);
         World_Loc (Wet) :=
           (VP => Location ("u_viewproj"), Camera => Location ("u_camera"), Focus => Location ("u_focus"),
            A2C => Location ("u_a2c"), Fog_Dist => Location ("u_fog_dist"), Variants => Location ("u_variants"),
            Water => Location ("u_water"), Blend => Location ("u_blend"), Wmask => Location ("u_wmask"),
            Flowdbg => Location ("u_flowdbg"), Wstep => Location ("u_wstep"), Reflect => Location ("u_reflect"),
            Roofs => Location ("u_roofs"), Roof_A => Location ("u_roof_a"), Roof_B => Location ("u_roof_b"),
            Roof_F => Location ("u_roof_f"), Roof_Box => Location ("u_roof_box"));
         Far_View_Loc (Wet) := Location ("u_far_view");
         Zp_Loc (Wet) := Location ("u_zp");
      end loop;
      Create_Textures (Texture_2D, 1, Far_Have_Tex);
      Texture_Storage_2D (Far_Have_Tex, 1, RGBA8, Far_Side, Far_Side);
      Texture_Sub_Image_2D (Far_Have_Tex, 0, 0, 0, Far_Side, Far_Side, RGBA, Unsigned_Byte, Far_Have (0, 0)'Address);
      Texture_Parameter_I (Far_Have_Tex, Texture_Min_Filter, Nearest);
      Texture_Parameter_I (Far_Have_Tex, Texture_Mag_Filter, Nearest);
      Texture_Parameter_I (Far_Have_Tex, Texture_Wrap_S, Clamp_To_Edge);
      Texture_Parameter_I (Far_Have_Tex, Texture_Wrap_T, Clamp_To_Edge);
      Use_World (False);
      Sky_Program := Link (Compile (Vertex_Shader, Sky_Vertex_Source),
                           Compile (Fragment_Shader, Sky_Fragment_Source));
      Loc_Fwd   := Location ("u_fwd", Sky_Program);
      Loc_Right := Location ("u_right", Sky_Program);
      Loc_Up    := Location ("u_up", Sky_Program);
      Loc_Vol   := Location ("u_vol", Sky_Program);
      Loc_Px    := Location ("u_px", Sky_Program);
      Loc_Stars := Location ("u_stars", Sky_Program);
      Loc_Star_Turn := Location ("u_star_turn", Sky_Program);
      Loc_Drop := Location ("u_drop", Sky_Program);
      Cloud_Program := Link (Compile (Vertex_Shader, Sky_Vertex_Source),
                             Compile (Fragment_Shader, Cloud_Fragment_Source));
      Loc_C_Fwd   := Location ("u_fwd", Cloud_Program);
      Loc_C_Right := Location ("u_right", Cloud_Program);
      Loc_C_Up    := Location ("u_up", Cloud_Program);
      Create_Vertex_Arrays (1, Sky_VAO);

      Shadow_Program := Link (Compile (Vertex_Shader, Vertex_Source),
                              Compile (Fragment_Shader, Shadow_Fragment_Source));
      Loc_S_VP     := Location ("u_viewproj", Shadow_Program);
      Loc_S_Camera := Location ("u_camera", Shadow_Program);
      declare
         Plants, Leafy : Unsigned_64 := 0;
      begin
         for M in Material loop
            if M in Tall_Grass | Wild_Grain | Wild_Vegetables then
               Plants := Plants or Bit (M);
            elsif M in Crown | Berry_Bush | Bare_Bush then
               Leafy := Leafy or Bit (M);
            end if;
         end loop;
         Put_Set (Shadow_Program, "u_plants", Plants);
         Put_Set (Shadow_Program, "u_leaves", Leafy);
      end;
      Caster_Program := Link (Compile (Vertex_Shader, Caster_Vertex_Source),
                              Compile (Fragment_Shader, Caster_Fragment_Source));
      Loc_C_VP     := Location ("u_viewproj", Caster_Program);
      Loc_C_Camera := Location ("u_camera", Caster_Program);
      Shadows_Ready := True;
      for M of Held loop
         declare
            Ok_Land, Ok_Fig : Boolean;
         begin
            Make_Depth_Map (Shadow_Size, Depth_Component_32F, M.Tex, M.FBO, Ok_Land);
            Make_Depth_Map (Figure_Size, Depth_Component_16, M.Fig_Tex, M.Fig_FBO, Ok_Fig);
            Shadows_Ready := Shadows_Ready and then Ok_Land and then Ok_Fig;
         end;
      end loop;
      if not Shadows_Ready then
         Put_Line (Standard_Error, "render: shadow map rejected, drawing without shadows");
      end if;

      --  The fire's cube of depth maps, a framebuffer for each face.
      Create_Textures (Texture_Cube_Map, 1, Fire_Tex);
      Texture_Storage_2D (Fire_Tex, 1, Depth_Component_16, Fire_Size, Fire_Size);
      Texture_Parameter_I (Fire_Tex, Texture_Min_Filter, Linear);
      Texture_Parameter_I (Fire_Tex, Texture_Mag_Filter, Linear);
      Texture_Parameter_I (Fire_Tex, Texture_Wrap_S, Clamp_To_Edge);
      Texture_Parameter_I (Fire_Tex, Texture_Wrap_T, Clamp_To_Edge);
      Texture_Parameter_I (Fire_Tex, Texture_Wrap_R, Clamp_To_Edge);
      Texture_Parameter_I (Fire_Tex, Texture_Compare_Mode, Compare_Ref_To_Texture);
      Texture_Parameter_I (Fire_Tex, Texture_Compare_Func, int (Lequal));
      Enable (Texture_Cube_Map_Seamless);
      Fire_Ready := True;
      for Face in Fire_FBO'Range loop
         Create_Framebuffers (1, Fire_FBO (Face));
         Named_Framebuffer_Texture_Layer (Fire_FBO (Face), Depth_Attachment, Fire_Tex, 0, int (Face));
         Named_Framebuffer_Draw_Buffer (Fire_FBO (Face), No_Buffer);
         Named_Framebuffer_Read_Buffer (Fire_FBO (Face), No_Buffer);
         Fire_Ready := Fire_Ready
           and then Check_Named_Framebuffer_Status (Fire_FBO (Face), Framebuffer) = Framebuffer_Complete;
      end loop;
      if not Fire_Ready then
         Put_Line (Standard_Error, "render: the fire's shadow maps rejected, its light casts none");
      end if;

      --  256 x 256 tiling value noise, five octaves, for the clouds and
      --  the water's ripples.
      declare
         Size : constant := 256;
         type Bytes is array (0 .. Size * Size - 1) of aliased Unsigned_8;
         type Bytes_Access is access Bytes;
         procedure Free_B is new Ada.Unchecked_Deallocation (Bytes, Bytes_Access);
         Img  : Bytes_Access := new Bytes;
         function Lattice (P, I, J : Integer) return Float is
           (Castle.Hash.Unit_3 (W.Seed + 77, I mod P, J mod P, P));
         function Smooth_T (T : Float) return Float is (T * T * (3.0 - 2.0 * T));
      begin
         for Y in 0 .. Size - 1 loop
            for X in 0 .. Size - 1 loop
               declare
                  V   : Float := 0.0;
                  Amp : Float := 0.5;
                  P   : Integer := 4;
               begin
                  for Octave in 1 .. 5 loop
                     declare
                        Fx : constant Float := Float (X) * Float (P) / Float (Size);
                        Fy : constant Float := Float (Y) * Float (P) / Float (Size);
                        I  : constant Integer := Integer (Float'Floor (Fx));
                        J  : constant Integer := Integer (Float'Floor (Fy));
                        Tx : constant Float := Smooth_T (Fx - Float (I));
                        Ty : constant Float := Smooth_T (Fy - Float (J));
                        A  : constant Float := Lattice (P, I, J) + (Lattice (P, I + 1, J) - Lattice (P, I, J)) * Tx;
                        B  : constant Float := Lattice (P, I, J + 1)
                                               + (Lattice (P, I + 1, J + 1) - Lattice (P, I, J + 1)) * Tx;
                     begin
                        V := V + Amp * (A + (B - A) * Ty);
                     end;
                     Amp := Amp * 0.5;
                     P   := P * 2;
                  end loop;
                  Img (Y * Size + X) := Unsigned_8 (Float'Max (0.0, Float'Min (255.0, V / 0.97 * 255.0)));
               end;
            end loop;
         end loop;
         Create_Textures (Texture_2D, 1, Noise_Tex);
         Texture_Storage_2D (Noise_Tex, 9, R8, Size, Size);
         Pixel_Store_I (Unpack_Alignment, 1);
         Texture_Sub_Image_2D (Noise_Tex, 0, 0, 0, Size, Size, Red, Unsigned_Byte, Img (0)'Address);
         Generate_Texture_Mipmap (Noise_Tex);
         Texture_Parameter_I (Noise_Tex, Texture_Min_Filter, Linear_Mipmap_Linear);
         Texture_Parameter_I (Noise_Tex, Texture_Mag_Filter, Linear);
         Texture_Parameter_I (Noise_Tex, Texture_Wrap_S, Repeat);
         Texture_Parameter_I (Noise_Tex, Texture_Wrap_T, Repeat);
         Free_B (Img);
      end;

      --  64 x 64 x 64 tiling noise for the clouds' billows: three octaves
      --  of cells, each the nearness of the nearest of a scatter of points
      --  (one a cell), so it is bright in rounded lumps with creases between.
      declare
         Size : constant := 64;
         type Bytes is array (0 .. Size * Size * Size - 1) of aliased Unsigned_8;
         type Bytes_Access is access Bytes;
         procedure Free_B is new Ada.Unchecked_Deallocation (Bytes, Bytes_Access);
         Img : Bytes_Access := new Bytes;
         type Octave is range 1 .. 3;
         Cells : constant array (Octave) of Positive := [4, 8, 16];
         Share : constant array (Octave) of Float := [0.60, 0.27, 0.13];
         type Points is array (0 .. 15, 0 .. 15, 0 .. 15, 0 .. 2) of Float;
         type Points_Access is access Points;
         procedure Free_P is new Ada.Unchecked_Deallocation (Points, Points_Access);
         Pt : array (Octave) of Points_Access;
         use Ada.Numerics.Elementary_Functions;
      begin
         for O in Octave loop
            Pt (O) := new Points;
            for K in 0 .. Cells (O) - 1 loop
               for J in 0 .. Cells (O) - 1 loop
                  for I in 0 .. Cells (O) - 1 loop
                     for A in 0 .. 2 loop
                        Pt (O) (I, J, K, A) :=
                          Castle.Hash.Unit_3 (W.Seed + 200 + Castle.Hash.U64 (10 * Integer (O) + A), I, J, K);
                     end loop;
                  end loop;
               end loop;
            end loop;
         end loop;
         for Z in 0 .. Size - 1 loop
            for Y in 0 .. Size - 1 loop
               for X in 0 .. Size - 1 loop
                  declare
                     V : Float := 0.0;
                  begin
                     for O in Octave loop
                        declare
                           N    : constant Positive := Cells (O);
                           Fx   : constant Float := (Float (X) + 0.5) * Float (N) / Float (Size);
                           Fy   : constant Float := (Float (Y) + 0.5) * Float (N) / Float (Size);
                           Fz   : constant Float := (Float (Z) + 0.5) * Float (N) / Float (Size);
                           Ci   : constant Integer := Integer (Float'Floor (Fx));
                           Cj   : constant Integer := Integer (Float'Floor (Fy));
                           Ck   : constant Integer := Integer (Float'Floor (Fz));
                           Best : Float := 9.0;
                        begin
                           for Dk in -1 .. 1 loop
                              for Dj in -1 .. 1 loop
                                 for Di in -1 .. 1 loop
                                    declare
                                       I  : constant Integer := (Ci + Di) mod N;
                                       J  : constant Integer := (Cj + Dj) mod N;
                                       K  : constant Integer := (Ck + Dk) mod N;
                                       Dx : constant Float := Float (Ci + Di) + Pt (O) (I, J, K, 0) - Fx;
                                       Dy : constant Float := Float (Cj + Dj) + Pt (O) (I, J, K, 1) - Fy;
                                       Dz : constant Float := Float (Ck + Dk) + Pt (O) (I, J, K, 2) - Fz;
                                    begin
                                       Best := Float'Min (Best, Dx * Dx + Dy * Dy + Dz * Dz);
                                    end;
                                 end loop;
                              end loop;
                           end loop;
                           V := V + Share (O) * Float'Max (0.0, 1.0 - Sqrt (Best));
                        end;
                     end loop;
                     Img ((Z * Size + Y) * Size + X) := Unsigned_8 (Float'Max (0.0, Float'Min (255.0, V * 255.0)));
                  end;
               end loop;
            end loop;
         end loop;
         for O in Octave loop
            Free_P (Pt (O));
         end loop;
         Create_Textures (Texture_3D, 1, Puff_Tex);
         Texture_Storage_3D (Puff_Tex, 5, R8, Size, Size, Size);
         Pixel_Store_I (Unpack_Alignment, 1);
         Texture_Sub_Image_3D (Puff_Tex, 0, 0, 0, 0, Size, Size, Size, Red, Unsigned_Byte, Img (0)'Address);
         Generate_Texture_Mipmap (Puff_Tex);
         Texture_Parameter_I (Puff_Tex, Texture_Min_Filter, Linear_Mipmap_Linear);
         Texture_Parameter_I (Puff_Tex, Texture_Mag_Filter, Linear);
         Texture_Parameter_I (Puff_Tex, Texture_Wrap_S, Repeat);
         Texture_Parameter_I (Puff_Tex, Texture_Wrap_T, Repeat);
         Texture_Parameter_I (Puff_Tex, Texture_Wrap_R, Repeat);
         Free_B (Img);
      end;

      --  What mist lies on: for every 16 m of the world, the level of the
      --  land (of its water, where there is open water) over the 80 m round
      --  it, and how damp the place is (1.5 at open water, 0.75 far from any).
      declare
         use Castle.Fields;
         Cell : constant := 16;
         Nb   : constant := Size_M / Cell;
         type Grid is array (0 .. Nb - 1, 0 .. Nb - 1) of Float;
         type Pair_Grid is array (0 .. Nb - 1, 0 .. Nb - 1, 0 .. 1) of Float with Convention => C;
         type Grid_Access is access Grid;
         type Pair_Access is access Pair_Grid;
         procedure Free_G is new Ada.Unchecked_Deallocation (Grid, Grid_Access);
         procedure Free_Pg is new Ada.Unchecked_Deallocation (Pair_Grid, Pair_Access);
         Level, Damp : Grid_Access := new Grid;
         Img         : Pair_Access := new Pair_Grid;
      begin
         for J in 0 .. Nb - 1 loop
            for I in 0 .. Nb - 1 loop
               declare
                  Sum_L, Sum_D : Float := 0.0;
               begin
                  for Y in J * Cell .. J * Cell + Cell - 1 loop
                     for X in I * Cell .. I * Cell + Cell - 1 loop
                        Sum_L := Sum_L + Float'Max (W.Height (Idx (X, Y)), W.Water (Idx (X, Y)));
                        Sum_D := Sum_D + 0.75 + 0.75 * Ada.Numerics.Elementary_Functions.Exp
                                                         (-Float'Max (0.0, W.Dist_Water (Idx (X, Y))) / 40.0);
                     end loop;
                  end loop;
                  Level (I, J) := Sum_L / Float (Cell * Cell);
                  Damp (I, J) := Sum_D / Float (Cell * Cell);
               end;
            end loop;
         end loop;
         for J in 0 .. Nb - 1 loop
            for I in 0 .. Nb - 1 loop
               declare
                  Sum_L, Sum_D : Float := 0.0;
                  N            : Natural := 0;
               begin
                  for Dj in -2 .. 2 loop
                     for Di in -2 .. 2 loop
                        if I + Di in 0 .. Nb - 1 and then J + Dj in 0 .. Nb - 1 then
                           Sum_L := Sum_L + Level (I + Di, J + Dj);
                           Sum_D := Sum_D + Damp (I + Di, J + Dj);
                           N := N + 1;
                        end if;
                     end loop;
                  end loop;
                  Img (J, I, 0) := Sum_L / Float (N);
                  Img (J, I, 1) := Sum_D / Float (N);
               end;
            end loop;
         end loop;
         Create_Textures (Texture_2D, 1, Base_Tex);
         Texture_Storage_2D (Base_Tex, 1, RG16F, Nb, Nb);
         Texture_Sub_Image_2D (Base_Tex, 0, 0, 0, Nb, Nb, RG, Float_Type, Img (0, 0, 0)'Address);
         Texture_Parameter_I (Base_Tex, Texture_Min_Filter, Linear);
         Texture_Parameter_I (Base_Tex, Texture_Mag_Filter, Linear);
         Texture_Parameter_I (Base_Tex, Texture_Wrap_S, Clamp_To_Edge);
         Texture_Parameter_I (Base_Tex, Texture_Wrap_T, Clamp_To_Edge);
         Free_G (Level);
         Free_G (Damp);
         Free_Pg (Img);
      end;

      --  How deep the ground haze lies on the ground (see the spec,
      --  Ground_Haze): from the land's level (its water's, where there is
      --  open water) and that level's mean over 65 m, a number for every 2 m.
      declare
         use Castle.Fields;
         R    : constant := 32;                   --  the mean is over 2 R + 1 m each way
         Half : constant := Size_M / 2;
         type Grid is array (0 .. Size_M - 1, 0 .. Size_M - 1) of Float;
         type Small is array (0 .. Half - 1, 0 .. Half - 1) of Float with Convention => C;
         type Grid_Access is access Grid;
         type Small_Access is access Small;
         procedure Free_G is new Ada.Unchecked_Deallocation (Grid, Grid_Access);
         procedure Free_S is new Ada.Unchecked_Deallocation (Small, Small_Access);
         F    : Grid_Access := new Grid;          --  (Y, X): the land's level
         Row  : Grid_Access := new Grid;          --  its mean along X
         Mean : Grid_Access := new Grid;          --  and then along Y
         Top  : Grid_Access := new Grid;
         Img  : Small_Access := new Small;
         function Clamped (I : Integer) return Integer is (Integer'Max (0, Integer'Min (Size_M - 1, I)));
      begin
         for Y in 0 .. Size_M - 1 loop
            for X in 0 .. Size_M - 1 loop
               F (Y, X) := Float'Max (W.Height (Idx (X, Y)), W.Water (Idx (X, Y)));
            end loop;
         end loop;
         for Y in 0 .. Size_M - 1 loop
            declare
               Sum : Float := 0.0;
            begin
               for X in -R .. R loop
                  Sum := Sum + F (Y, Clamped (X));
               end loop;
               for X in 0 .. Size_M - 1 loop
                  Row (Y, X) := Sum / Float (2 * R + 1);
                  Sum := Sum + F (Y, Clamped (X + R + 1)) - F (Y, Clamped (X - R));
               end loop;
            end;
         end loop;
         for X in 0 .. Size_M - 1 loop
            declare
               Sum : Float := 0.0;
            begin
               for Y in -R .. R loop
                  Sum := Sum + Row (Clamped (Y), X);
               end loop;
               for Y in 0 .. Size_M - 1 loop
                  Mean (Y, X) := Sum / Float (2 * R + 1);
                  Sum := Sum + Row (Clamped (Y + R + 1), X) - Row (Clamped (Y - R), X);
               end loop;
            end;
         end loop;
         for Y in 0 .. Size_M - 1 loop
            for X in 0 .. Size_M - 1 loop
               declare
                  Sx    : constant Float := (Mean (Y, Clamped (X + 4)) - Mean (Y, Clamped (X - 4))) / 8.0;
                  Sy    : constant Float := (Mean (Clamped (Y + 4), X) - Mean (Clamped (Y - 4), X)) / 8.0;
                  Slope : constant Float := Ada.Numerics.Elementary_Functions.Sqrt (Sx * Sx + Sy * Sy);
               begin
                  --  (open water: the whole depth, wherever it is; land: less of
                  --  it the steeper, and none in the mountains)
                  Top (Y, X) :=
                    (if W.Water (Idx (X, Y)) > W.Height (Idx (X, Y)) then Float (Haze_Deep_M)
                     else Float (Haze_Deep_M) * (1.0 - Smooth (Haze_Slope_Lo, Haze_Slope_Hi, Slope))
                          * (1.0 - Smooth (Haze_Mountain_Lo, Haze_Mountain_Hi, W.Mountain (Idx (X, Y)))));
               end;
            end loop;
         end loop;
         for J in 0 .. Half - 1 loop
            for I in 0 .. Half - 1 loop
               Img (J, I) := 0.25 * (Top (2 * J, 2 * I) + Top (2 * J, 2 * I + 1)
                                     + Top (2 * J + 1, 2 * I) + Top (2 * J + 1, 2 * I + 1));
            end loop;
         end loop;
         Create_Textures (Texture_2D, 1, Haze_Tex);
         Texture_Storage_2D (Haze_Tex, 1, R16F, Half, Half);
         Texture_Sub_Image_2D (Haze_Tex, 0, 0, 0, Half, Half, Red, Float_Type, Img (0, 0)'Address);
         Texture_Parameter_I (Haze_Tex, Texture_Min_Filter, Linear);
         Texture_Parameter_I (Haze_Tex, Texture_Mag_Filter, Linear);
         Texture_Parameter_I (Haze_Tex, Texture_Wrap_S, Clamp_To_Edge);
         Texture_Parameter_I (Haze_Tex, Texture_Wrap_T, Clamp_To_Edge);
         Free_G (F);
         Free_G (Row);
         Free_G (Mean);
         Free_G (Top);
         Free_S (Img);
      end;

      Precip_Program := Link (Compile (Vertex_Shader, Precip_Vertex_Source),
                              Compile (Fragment_Shader, Precip_Fragment_Source));
      Box_Program := Link (Compile (Vertex_Shader, Box_Vertex_Source),
                           Compile (Fragment_Shader, Box_Fragment_Source));

      --  The lights' table and their grid.
      Create_Buffers (1, Light_Buf);
      Named_Buffer_Storage (Light_Buf, Sizeiptr (Max_Lights * 32), Null_Address, Dynamic_Storage_Bit);
      Create_Textures (Texture_2D, 1, Light_Tex);
      Texture_Storage_2D (Light_Tex, 1, RG32UI, Light_Cells, Light_Cells);
      Texture_Parameter_I (Light_Tex, Texture_Min_Filter, Nearest);
      Texture_Parameter_I (Light_Tex, Texture_Mag_Filter, Nearest);
      Texture_Parameter_I (Light_Tex, Texture_Wrap_S, Clamp_To_Edge);
      Texture_Parameter_I (Light_Tex, Texture_Wrap_T, Clamp_To_Edge);
      Texture_Sub_Image_2D (Light_Tex, 0, 0, 0, Light_Cells, Light_Cells, RG_Integer, Unsigned_Int,
                            Grid (0, 0)'Address);

      --  The snow map: the sky's view straight down.
      Create_Textures (Texture_2D, 1, Snow_Tex);
      Texture_Storage_2D (Snow_Tex, 1, Depth_Component_32F, Snow_Size, Snow_Size);
      Texture_Parameter_I (Snow_Tex, Texture_Min_Filter, Linear);
      Texture_Parameter_I (Snow_Tex, Texture_Mag_Filter, Linear);
      Texture_Parameter_I (Snow_Tex, Texture_Wrap_S, Clamp_To_Edge);
      Texture_Parameter_I (Snow_Tex, Texture_Wrap_T, Clamp_To_Edge);
      Texture_Parameter_I (Snow_Tex, Texture_Compare_Mode, Compare_Ref_To_Texture);
      Texture_Parameter_I (Snow_Tex, Texture_Compare_Func, int (Lequal));
      Create_Framebuffers (1, Snow_FBO);
      Named_Framebuffer_Texture (Snow_FBO, Depth_Attachment, Snow_Tex, 0);
      Named_Framebuffer_Draw_Buffer (Snow_FBO, No_Buffer);
      Named_Framebuffer_Read_Buffer (Snow_FBO, No_Buffer);
      Snow_Ready := Check_Named_Framebuffer_Status (Snow_FBO, Framebuffer) = Framebuffer_Complete;

      Fig_Program := Link (Compile (Vertex_Shader, Figure_Vertex_Source),
                           Compile (Fragment_Shader, Figure_Fragment_Source));
      Blob_Program := Link (Compile (Vertex_Shader, Blob_Vertex_Source),
                            Compile (Fragment_Shader, Blob_Fragment_Source));
      Fig_Loc_VP     := Location ("u_viewproj", Fig_Program);
      Fig_Loc_Camera := Location ("u_camera", Fig_Program);
      Fig_Loc_Focus  := Location ("u_focus", Fig_Program);
      Fig_Loc_Fog    := Location ("u_fog_dist", Fig_Program);
      Fig_Loc_A2C    := Location ("u_a2c", Fig_Program);
      Program_Uniform_1i (Fig_Program, Fig_Loc_A2C, (if A2C then 1 else 0));
      Blob_Loc_VP     := Location ("u_viewproj", Blob_Program);
      Blob_Loc_Camera := Location ("u_camera", Blob_Program);
      Blob_Loc_Strength := Location ("u_blob", Blob_Program);
      Program_Uniform_2f (Fig_Program, Location ("u_skin_size", Fig_Program),
                          Float32 (Castle.Bodies.Skin_W), Float32 (Castle.Bodies.Skin_H));
      Create_Textures (Texture_2D_Array, 1, Skin_Tex);
      Texture_Storage_3D (Skin_Tex, Skin_Levels, RGBA8, Castle.Bodies.Skin_W, Castle.Bodies.Skin_H,
                          Castle.Figures.Max_Looks);
      Texture_Parameter_I (Skin_Tex, Texture_Min_Filter, Linear_Mipmap_Linear);
      Texture_Parameter_I (Skin_Tex, Texture_Mag_Filter, Nearest);
      Texture_Parameter_I (Skin_Tex, Texture_Wrap_S, Clamp_To_Edge);
      Texture_Parameter_I (Skin_Tex, Texture_Wrap_T, Clamp_To_Edge);
      Create_Buffers (1, Fig_Bone_Buf);
      Named_Buffer_Storage (Fig_Bone_Buf, Sizeiptr (Castle.Figures.Bones'Length * 48), Null_Address,
                            Dynamic_Storage_Bit);
      Create_Buffers (1, Fig_Box_Buf);
      Named_Buffer_Storage (Fig_Box_Buf, Sizeiptr (Castle.Figures.Boxes'Length * 48), Null_Address,
                            Dynamic_Storage_Bit);
      Create_Buffers (1, Fig_Blob_Buf);
      Named_Buffer_Storage (Fig_Blob_Buf, Sizeiptr (Castle.Figures.Blobs'Length * 16), Null_Address,
                            Dynamic_Storage_Bit);
      Mark_Program := Link (Compile (Vertex_Shader, Mark_Vertex_Source),
                            Compile (Fragment_Shader, Mark_Fragment_Source));
      Mark_Loc_VP     := Location ("u_viewproj", Mark_Program);
      Mark_Loc_Camera := Location ("u_camera", Mark_Program);
      Mark_Loc_Dim    := Location ("u_dim", Mark_Program);
      Create_Buffers (1, Mark_Buf);
      Named_Buffer_Storage (Mark_Buf, Sizeiptr (Castle.Marks.Marks'Length * 48), Null_Address,
                            Dynamic_Storage_Bit);

      --  (the far land is out of the game since 2026-11-15, John's word: none
      --  of it is made unless Far_Land has been set by the time this runs)
      if Far_Land then
         Far_Program := Link (Compile (Vertex_Shader, Far_Vertex_Source),
                              Compile (Fragment_Shader, Far_Fragment_Head & Sky_Source & Far_Fragment_Body));
         Far_Loc_VP     := Location ("u_viewproj", Far_Program);
         Far_Loc_Camera := Location ("u_camera", Far_Program);
         Far_Loc_Focus  := Location ("u_focus", Far_Program);
         Far_Loc_Fog    := Location ("u_fog_dist", Far_Program);
      end if;

      Programs := (P_World => World_Prog (False), P_World_Wet => World_Prog (True), P_Sky => Sky_Program,
                   P_Shadow => Shadow_Program, P_Precip => Precip_Program,
                   P_Figure => Fig_Program, P_Blob => Blob_Program, P_Cloud => Cloud_Program,
                   P_Far => Far_Program);
      for P in Program_Id loop
         for U in Uniform_Id loop
            if Programs (P) /= 0 then
               Locs (P, U) := Location (Uniform_Name (U), Programs (P));
            end if;
         end loop;
      end loop;

      declare
         Broad, Grassy, Plants, Crowns, Foliage : Unsigned_64 := 0;
      begin
         for M in Material loop
            if M in Castle.Mesher.Soft then
               Foliage := Foliage or Bit (M);
            end if;
            if M in Leaves | Dark_Leaves | Aspen_Leaves | Apple_Leaves | Berry_Bush | Bare_Bush then
               Broad := Broad or Bit (M);
            end if;
            if M in Grass | Tall_Grass | Wild_Grain then
               Grassy := Grassy or Bit (M);
            end if;
            if M in Tall_Grass | Wild_Grain | Wild_Vegetables then
               Plants := Plants or Bit (M);
            end if;
            if M in Crown then
               Crowns := Crowns or Bit (M);
            end if;
         end loop;
         for P of Programs loop
            Put_Set (P, "u_broadleaf", Broad);
         end loop;
         for Wet in Boolean loop
            Use_World (Wet);
            Put_Set (Program, "u_grassy", Grassy);
            Put_Set (Program, "u_plants", Plants);
            Put_Set (Program, "u_blades", Bit (Tall_Grass) or Bit (Wild_Grain));
            Program_Uniform_1i (Program, Location ("u_grain"), int (Material'Pos (Wild_Grain)));
            Put_Set (Program, "u_crowns", Crowns);
            Put_Set (Program, "u_foliage", Foliage);
            Put_Set (Program, "u_soaks", Bit (Dirt) or Bit (Sand) or Bit (Gravel) or Bit (Clay) or Bit (Footpath)
                                         or Bit (Log) or Bit (Aspen_Log) or Bit (Pine_Log) or Bit (Placer_Gravel)
                                         or Bit (Bog_Iron) or Bit (Thatch) or Bit (Daub));
            Put_Set (Program, "u_shines", Bit (Bedrock) or Bit (Granite) or Bit (Limestone) or Bit (Sandstone)
                                          or Bit (Boulder) or Bit (Coal) or Bit (Iron_Ore) or Bit (Silver_Ore)
                                          or Bit (Gold_Ore) or Bit (Rock_Salt) or Bit (Plank) or Bit (Shingle)
                                          or Bit (Fieldstone));
            Put_Set (Program, "u_pools", Bit (Dirt) or Bit (Footpath) or Bit (Clay) or Bit (Bedrock) or Bit (Granite)
                                         or Bit (Limestone) or Bit (Sandstone));
            Program_Uniform_1i (Program, Location ("u_aspen"), int (Material'Pos (Aspen_Leaves)));
            Program_Uniform_1i (Program, Location ("u_turf"), int (Material'Pos (Grass)));
            Program_Uniform_1i (Program, Location ("u_bare"), int (Material'Pos (Dirt)));
         end loop;
      end;
      declare
         Off : constant Mat4 := (12 => 9.0, 15 => 1.0, others => 0.0);   --  maps every point outside: open sky
      begin
         Put (U_Snow_VP, Off);
      end;
      Set_Look (Current);
      for Wet in Boolean loop
         Use_World (Wet);
         Program_Uniform_1i (Program, Loc_Variants, Castle.Textures.Variants);
         Put_Set (Program, "u_ground", Ground);
         Program_Uniform_1i (Program, Loc_A2C, (if A2C then 1 else 0));
         Program_Uniform_1i (Program, Location ("u_thatch"), int (Material'Pos (Thatch)));
         Put_Set (Program, "u_walls", Bit (Daub) or Bit (Log));
         Program_Uniform_1i (Program, Location ("u_samples"), int (Natural'Max (1, MSAA)));
         Program_Uniform_1i (Program, World_Loc (Wet).Roofs, 0);
      end loop;

      Create_Textures (Texture_2D, 1, Height_Tex);
      Texture_Storage_2D (Height_Tex, 1, R32F, Size_M, Size_M);
      Texture_Sub_Image_2D (Height_Tex, 0, 0, 0, Size_M, Size_M, Red, Float_Type,
                            W.Height (W.Height'First)'Address);
      Texture_Parameter_I (Height_Tex, Texture_Min_Filter, Linear);
      Texture_Parameter_I (Height_Tex, Texture_Mag_Filter, Linear);
      Texture_Parameter_I (Height_Tex, Texture_Wrap_S, Clamp_To_Edge);
      Texture_Parameter_I (Height_Tex, Texture_Wrap_T, Clamp_To_Edge);

      --  Surface water: block columns, wrapping round the camera, all
      --  hidden until their stacks arrive.
      Create_Textures (Texture_2D, 1, Lv_Tex);
      Texture_Storage_2D (Lv_Tex, 1, RGBA32F, Sizei (Lv_Size), Sizei (Lv_Size));
      declare
         type Texel_Row is array (Natural range <>) of Surface_Texel with Convention => C;
         Row : constant Texel_Row (0 .. Lv_Size - 1) := (others => (0.0, 0.0, Hidden_Floor, 0.0));
      begin
         for Y in 0 .. Lv_Size - 1 loop
            Texture_Sub_Image_2D (Lv_Tex, 0, 0, int (Y), Sizei (Lv_Size), 1, RGBA, Float_Type, Row'Address);
         end loop;
      end;
      Texture_Parameter_I (Lv_Tex, Texture_Min_Filter, Nearest);
      Texture_Parameter_I (Lv_Tex, Texture_Mag_Filter, Nearest);
      Texture_Parameter_I (Lv_Tex, Texture_Wrap_S, Repeat);
      Texture_Parameter_I (Lv_Tex, Texture_Wrap_T, Repeat);

      --  The flow map: the generated currents, 1 m cells, world-wide.
      Create_Textures (Texture_2D, 1, Flow_Tex);
      Texture_Storage_2D (Flow_Tex, 1, RG16F, Size_M, Size_M);
      declare
         use Castle.Fields;
         type Pair_Row is array (0 .. Size_M - 1, 0 .. 1) of Float with Convention => C;
         Row : Pair_Row := (others => (others => 0.0));
         E   : constant Field_Access := Castle.Currents.East;
         Nn  : constant Field_Access := Castle.Currents.North;
      begin
         for Y in 0 .. Size_M - 1 loop
            if E /= null then
               for X in 0 .. Size_M - 1 loop
                  Row (X, 0) := E (Idx (X, Y));
                  Row (X, 1) := Nn (Idx (X, Y));
               end loop;
            end if;
            Texture_Sub_Image_2D (Flow_Tex, 0, 0, int (Y), Size_M, 1, RG, Float_Type, Row'Address);
         end loop;
      end;
      Texture_Parameter_I (Flow_Tex, Texture_Min_Filter, Linear);
      Texture_Parameter_I (Flow_Tex, Texture_Mag_Filter, Linear);
      Texture_Parameter_I (Flow_Tex, Texture_Wrap_S, Clamp_To_Edge);
      Texture_Parameter_I (Flow_Tex, Texture_Wrap_T, Clamp_To_Edge);

      Create_Buffers (1, Quad_Buf);
      Named_Buffer_Storage (Quad_Buf, Sizeiptr (Capacity_Quads) * 8, Null_Address,
                            Dynamic_Storage_Bit);
      Create_Buffers (1, Cmd_Buf);
      Named_Buffer_Storage (Cmd_Buf, Max_Draws * 16, Null_Address, Dynamic_Storage_Bit);
      Create_Buffers (1, Origin_Buf);
      Named_Buffer_Storage (Origin_Buf, Max_Draws * 16, Null_Address, Dynamic_Storage_Bit);

      Create_Vertex_Arrays (1, VAO);
      Vertex_Array_Vertex_Buffer (VAO, 0, Origin_Buf, 0, 16);
      Vertex_Array_Attrib_I_Format (VAO, 0, 4, Int_Type, 0);
      Vertex_Array_Attrib_Binding (VAO, 0, 0);
      Enable_Vertex_Array_Attrib (VAO, 0);
      Vertex_Array_Binding_Divisor (VAO, 0, 1);

      declare
         use Castle.Textures;
         Set : Texture_Set := Generate (W.Seed);
      begin
         Create_Textures (Texture_2D_Array, 1, Tex);
         Texture_Storage_3D (Tex, 3, RGBA8, Size, Size, Layers);   --  5x5, 2x2, 1x1
         Pixel_Store_I (Unpack_Alignment, 1);
         Texture_Sub_Image_3D (Tex, 0, 0, 0, 0, Size, Size, Layers, RGBA, Unsigned_Byte,
                               Set.Detail (Set.Detail'First)'Address);
         Texture_Sub_Image_3D (Tex, 1, 0, 0, 0, 2, 2, Layers, RGBA, Unsigned_Byte,
                               Set.Variant (Set.Variant'First)'Address);
         Texture_Sub_Image_3D (Tex, 2, 0, 0, 0, 1, 1, Layers, RGBA, Unsigned_Byte,
                               Set.Overall (Set.Overall'First)'Address);
         Texture_Parameter_I (Tex, Texture_Min_Filter, Nearest);
         Texture_Parameter_I (Tex, Texture_Mag_Filter, Nearest);

         --  Which stacks have a mesh of their own loaded (the far view reads
         --  it; the far land was dropped by it).
         declare
            Zero : constant array (0 .. Chunks_XY * Chunks_XY - 1) of aliased Unsigned_8 := [others => 0];
         begin
            Create_Textures (Texture_2D, 1, Far_Flag_Tex);
            Texture_Storage_2D (Far_Flag_Tex, 1, R8, Chunks_XY, Chunks_XY);
            Texture_Sub_Image_2D (Far_Flag_Tex, 0, 0, 0, Chunks_XY, Chunks_XY, Red, Unsigned_Byte, Zero (0)'Address);
            Texture_Parameter_I (Far_Flag_Tex, Texture_Min_Filter, Nearest);
            Texture_Parameter_I (Far_Flag_Tex, Texture_Mag_Filter, Nearest);
            Texture_Parameter_I (Far_Flag_Tex, Texture_Wrap_S, Clamp_To_Edge);
            Texture_Parameter_I (Far_Flag_Tex, Texture_Wrap_T, Clamp_To_Edge);
         end;

         --  The far land: worked out once from the map (a fifth of a second),
         --  if it is asked for.
         if Far_Land and then Far_Program /= 0 then
            declare
               use Castle.Far;
               Z   : Height_Grid_Access := new Height_Grid;
               C   : Texel_Grid_Access := new Texel_Grid;
               procedure Free_Z is new Ada.Unchecked_Deallocation (Height_Grid, Height_Grid_Access);
               procedure Free_C is new Ada.Unchecked_Deallocation (Texel_Grid, Texel_Grid_Access);
               type Two is array (1 .. 2) of UInt;
            begin
               Build (W, Set.Overall.all, Z.all, C.all);
               Create_Textures (Texture_2D, 1, Far_Z_Tex);
               Texture_Storage_2D (Far_Z_Tex, 1, R32F, Cells + 1, Cells + 1);
               Texture_Sub_Image_2D (Far_Z_Tex, 0, 0, 0, Cells + 1, Cells + 1, Red, Float_Type, Z (0, 0)'Address);
               Create_Textures (Texture_2D, 1, Far_Col_Tex);
               Texture_Storage_2D (Far_Col_Tex, 1, RGBA8, Cells, Cells);
               Texture_Sub_Image_2D (Far_Col_Tex, 0, 0, 0, Cells, Cells, RGBA, Unsigned_Byte, C (0, 0)'Address);
               for T of Two'(Far_Z_Tex, Far_Col_Tex) loop
                  Texture_Parameter_I (T, Texture_Min_Filter, (if T = Far_Col_Tex then Linear else Nearest));
                  Texture_Parameter_I (T, Texture_Mag_Filter, (if T = Far_Col_Tex then Linear else Nearest));
                  Texture_Parameter_I (T, Texture_Wrap_S, Clamp_To_Edge);
                  Texture_Parameter_I (T, Texture_Wrap_T, Clamp_To_Edge);
               end loop;
               for K in Class range Broadleaf .. Conifer loop
                  declare
                     Crown : constant Texel := Crown_Of (Set.Overall.all, K);
                  begin
                     Program_Uniform_3f (Far_Program,
                                         Location ("u_crown[" & GLSL_Int (Class'Pos (K) - Class'Pos (Broadleaf)) & "]",
                                                   Far_Program),
                                         Float32 (Crown.R) / 255.0, Float32 (Crown.G) / 255.0, Float32 (Crown.B) / 255.0);
                  end;
               end loop;
               Free_Z (Z);
               Free_C (C);
               Far_Ready := True;
            end;
         end if;
         Free (Set);
      end;

      Create_Queries (Time_Elapsed, Queries'Length, Queries (0)'Address);

      Spans (1) := (0, Capacity_Quads);
      Span_N := 1;
      Free_Quads := Capacity_Quads;
   end Init;

   ---------------------------------------------------------------- meshes

   function Place (Q : Quad_Access; Start, Count : out Natural) return Boolean is
   begin
      Start := 0;
      Count := 0;
      if Q = null then
         return True;
      end if;
      declare
         A : constant Integer := Alloc (Q'Length);
      begin
         if A < 0 then
            return False;
         end if;
         Start := A;
         Count := Q'Length;
         Named_Buffer_Sub_Data (Quad_Buf, Intptr (A) * 8, Sizeiptr (Q'Length) * 8,
                                Q (Q'First)'Address);
         return True;
      end;
   end Place;

   procedure Set_Water_Reach (Metres : Float) is
   begin
      --  Two stacks of the view must never share a slot: the texture spans
      --  more than the view's loaded diameter, its two stacks of hysteresis
      --  included (the view radius in stacks and two more on either side fit
      --  the window of 64 or 128).  Stacks kept loaded outside the view (the
      --  colony's ground) can: see the spec, "a slot is its window stack's
      --  alone".
      Lv_Size := (if Metres * 8.0 + 256.0 <= 2048.0 then 2048 else 4096);
      if Metres * 8.0 + 256.0 > 4096.0 then
         Put_Line ("render: a view of" & Integer'Image (Integer (Metres))
                   & " m is wider than the water's surface texture (480 m at most): water past its window is not drawn");
      end if;
   end Set_Water_Reach;

   --  Whose each slot of the surface texture is (the spec: "a slot is its
   --  window stack's alone").  A stack's key is CX * 4096 + CY.
   Max_Lv_Stacks : constant := 128;
   No_Owner      : constant Integer := -1;
   Slot_Owner    : array (0 .. Max_Lv_Stacks - 1, 0 .. Max_Lv_Stacks - 1) of Integer :=
     [others => [others => No_Owner]];
   Lv_Fx, Lv_Fy  : Integer := 0;              --  the window's middle stack,
   Lv_Focused    : Boolean := False;          --  once it has been given (until then every stack is in it)

   function Lv_Stacks return Integer is (Lv_Size / 32);

   function In_Surface_Window (CX, CY : Integer) return Boolean is
     (not Lv_Focused
      or else (CX - Lv_Fx in -Lv_Stacks / 2 .. Lv_Stacks / 2 - 1
               and then CY - Lv_Fy in -Lv_Stacks / 2 .. Lv_Stacks / 2 - 1));

   function Owns_Surface (CX, CY : Integer) return Boolean is
     (Slot_Owner (CX mod Lv_Stacks, CY mod Lv_Stacks) = CX * 4096 + CY);

   Hidden_Block : constant Surface_Block := (others => (others => (0.0, 0.0, Hidden_Floor, 0.0)));

   procedure Write_Slot (SX, SY : Integer; S : Surface_Block) is
   begin
      if Lv_Tex /= 0 then
         Texture_Sub_Image_2D (Lv_Tex, 0, int (SX * 32), int (SY * 32), 32, 32, RGBA, Float_Type, S'Address);
      end if;
   end Write_Slot;

   procedure Set_Surface (Bx0, By0 : Integer; S : Surface_Block) is
      CX : constant Integer := Bx0 / 32;
      CY : constant Integer := By0 / 32;
   begin
      if In_Surface_Window (CX, CY) then
         Write_Slot (CX mod Lv_Stacks, CY mod Lv_Stacks, S);
         Slot_Owner (CX mod Lv_Stacks, CY mod Lv_Stacks) := CX * 4096 + CY;
      end if;
   end Set_Surface;

   procedure Hide_Surface (Bx0, By0 : Integer) is
      CX : constant Integer := Bx0 / 32;
      CY : constant Integer := By0 / 32;
   begin
      if Owns_Surface (CX, CY) then
         Write_Slot (CX mod Lv_Stacks, CY mod Lv_Stacks, Hidden_Block);
         Slot_Owner (CX mod Lv_Stacks, CY mod Lv_Stacks) := No_Owner;
      end if;
   end Hide_Surface;

   procedure Set_Surface_Focus (CX, CY : Integer; Moved : out Boolean) is
   begin
      Moved := not Lv_Focused or else CX /= Lv_Fx or else CY /= Lv_Fy;
      if Moved then
         Lv_Fx := CX;
         Lv_Fy := CY;
         Lv_Focused := True;
         for SX in 0 .. Lv_Stacks - 1 loop
            for SY in 0 .. Lv_Stacks - 1 loop
               declare
                  K : constant Integer := Slot_Owner (SX, SY);
               begin
                  if K /= No_Owner and then not In_Surface_Window (K / 4096, K mod 4096) then
                     Write_Slot (SX, SY, Hidden_Block);
                     Slot_Owner (SX, SY) := No_Owner;
                  end if;
               end;
            end loop;
         end loop;
      end if;
   end Set_Surface_Focus;

   procedure Set_Water_Blend (B : Float) is
   begin
      Blend_Now := Float'Max (0.0, Float'Min (1.0, B));
   end Set_Water_Blend;

   procedure Set_Currents (Mx0, My0 : Integer; C : Current_Block) is
   begin
      if Flow_Tex /= 0 and then Mx0 in 0 .. Size_M - 8 and then My0 in 0 .. Size_M - 8 then
         Texture_Sub_Image_2D (Flow_Tex, 0, int (Mx0), int (My0), 8, 8, RG, Float_Type, C'Address);
      end if;
   end Set_Currents;

   procedure Reset_Currents (CX, CY : Integer) is
      use Castle.Fields;
      C  : Current_Block := (others => (others => (others => 0.0)));
      E  : constant Field_Access := Castle.Currents.East;
      Nn : constant Field_Access := Castle.Currents.North;
   begin
      if E = null or else CX not in 0 .. Size_M / 8 - 1 or else CY not in 0 .. Size_M / 8 - 1 then
         return;
      end if;
      for Y in 0 .. 7 loop
         for X in 0 .. 7 loop
            C (Y, X, 0) := E (Idx (CX * 8 + X, CY * 8 + Y));
            C (Y, X, 1) := Nn (Idx (CX * 8 + X, CY * 8 + Y));
         end loop;
      end loop;
      Set_Currents (CX * 8, CY * 8, C);
   end Reset_Currents;

   procedure Set_Water_Steps (Steps : Natural) is
   begin
      Water_Steps := Steps;
   end Set_Water_Steps;

   procedure Set_Flow_Debug (On : Boolean) is
   begin
      Flow_Debug := On;
   end Set_Flow_Debug;

   procedure Upload (CX, CY : Integer; M : Mesh; Edited : Boolean := False) is
      S : Slot renames Slots (CX, CY);
   begin
      Changes := Changes + 1;
      if S.Loaded then
         Unload (CX, CY);
      end if;
      if Loaded_N = Max_Loaded then
         return;
      end if;
      if not Place (M.Solid, S.S_Start, S.S_Count)
        or else not Place (M.Water, S.W_Start, S.W_Count)
      then
         --  (said once: a view too wide for the arena skips thousands)
         if Skipped = 0 then
            Put_Line (Standard_Error, "render: the quad arena is full ("
                      & Natural'Image ((Quads_Total + Free_Quads) / 131_072) & " MB): stacks that do not fit are not drawn");
         end if;
         Skipped := Skipped + 1;
         Release (S.S_Start, S.S_Count);
         S := (others => <>);
         return;
      end if;
      S.S_Cast := Natural'Min (M.Cast, S.S_Count);
      S.Z_Lo := M.Z_Lo;
      S.Z_Hi := M.Z_Hi;
      S.Loaded := True;
      Loaded_N := Loaded_N + 1;
      Loaded_List (Loaded_N) := (CX, CY);
      S.List_Pos := Loaded_N;
      Quads_Total := Quads_Total + S.S_Count + S.W_Count;
      if Far_Flag_Tex /= 0 then                --  (what the far view goes by, and the far land was dropped by)
         Far_Flag := (if Edited then 255 else 128);
         Texture_Sub_Image_2D (Far_Flag_Tex, 0, int (CX), int (CY), 1, 1, Red, Unsigned_Byte, Far_Flag'Address);
      end if;
   end Upload;

   procedure Unload (CX, CY : Integer) is
      S : Slot renames Slots (CX, CY);
   begin
      Changes := Changes + 1;
      if not S.Loaded then
         return;
      end if;
      Release (S.S_Start, S.S_Count);
      Release (S.W_Start, S.W_Count);
      Quads_Total := Quads_Total - S.S_Count - S.W_Count;
      declare
         P    : constant Positive := S.List_Pos;
         Last : constant Coord := Loaded_List (Loaded_N);
      begin
         Loaded_List (P) := Last;
         Slots (Last.CX, Last.CY).List_Pos := P;
         Loaded_N := Loaded_N - 1;
      end;
      S := (others => <>);
      if Far_Flag_Tex /= 0 then
         Far_Flag := 0;
         Texture_Sub_Image_2D (Far_Flag_Tex, 0, int (CX), int (CY), 1, 1, Red, Unsigned_Byte, Far_Flag'Address);
      end if;
   end Unload;

   function Loaded (CX, CY : Integer) return Boolean is (Slots (CX, CY).Loaded);

   --  The far view's tiles.
   procedure Mark_Far (Level, TX, TY : Integer; Share : Unsigned_8) is
      N : constant Integer := 2 ** (Level - 1);          --  16 m cells a side
   begin
      for Y in TY * N .. TY * N + N - 1 loop
         for X in TX * N .. TX * N + N - 1 loop
            Far_Have (Y, X) (Level) := Share;
         end loop;
      end loop;
      Far_Have_Dirty := True;
   end Mark_Far;

   procedure Unload_Far (Level : Positive; TX, TY : Integer) is
      S : Far_Slot renames Far_Slots (Level, TX, TY);
   begin
      if not S.Loaded then
         return;
      end if;
      Release (S.S_Start, S.S_Count);
      Release (S.W_Start, S.W_Count);
      Far_Quads := Far_Quads - S.S_Count - S.W_Count;
      declare
         P    : constant Positive := S.List_Pos;
         Last : constant Far_Ref := Far_List (Far_N);
      begin
         Far_List (P) := Last;
         Far_Slots (Last.L, Last.TX, Last.TY).List_Pos := P;
         Far_N := Far_N - 1;
      end;
      if S.Coming then
         Far_Coming := Far_Coming - 1;
      end if;
      S := (others => <>);
      Mark_Far (Level, TX, TY, 0);
      if not Far_Replacing then
         Far_Changes := Far_Changes + 1;
      end if;
   end Unload_Far;

   procedure Upload_Far (Level : Positive; TX, TY : Integer; M : Mesh) is
      S     : Far_Slot renames Far_Slots (Level, TX, TY);
      Fresh : constant Boolean := not S.Loaded;       --  (one made again takes its place at once)
   begin
      if S.Loaded then
         Far_Replacing := True;
         Unload_Far (Level, TX, TY);
         Far_Replacing := False;
      end if;
      if Far_N = Max_Far then
         return;
      end if;
      if not Place (M.Solid, S.S_Start, S.S_Count) or else not Place (M.Water, S.W_Start, S.W_Count) then
         if Skipped = 0 then
            Put_Line (Standard_Error, "render: the quad arena is full: a tile of the far view does not fit and is not drawn");
         end if;
         Skipped := Skipped + 1;
         Release (S.S_Start, S.S_Count);
         S := (others => <>);
         return;
      end if;
      S.By_Face := [others => 0];
      if M.Solid /= null then
         for Q of M.Solid.all loop
            S.By_Face (Integer (Shift_Right (Q.W0, 25) and 7)) := @ + 1;
         end loop;
      end if;
      S.Z_Lo := M.Z_Lo;
      S.Z_Hi := M.Z_Hi;
      S.Loaded := True;
      Far_N := Far_N + 1;
      Far_List (Far_N) := (Level, TX, TY);
      S.List_Pos := Far_N;
      Far_Quads := Far_Quads + S.S_Count + S.W_Count;
      if Fresh then
         Far_Changes := Far_Changes + 1;
      else
         Far_Remakes := Far_Remakes + 1;
      end if;
      if Fresh and then Far_Arrive_Frames > 0 then
         S.Born := Far_Frame;
         S.Coming := True;
         Far_Coming := Far_Coming + 1;
         Mark_Far (Level, TX, TY, 0);
      else
         Mark_Far (Level, TX, TY, 255);
      end if;
   end Upload_Far;

   function Far_Loaded (Level : Positive; TX, TY : Integer) return Boolean is (Far_Slots (Level, TX, TY).Loaded);
   function Far_Shadow_Draws return Natural is (Far_Casts);
   function Far_Tiles_Resident return Natural is (Far_N);
   function Far_Quads_Resident return Natural is (Far_Quads);
   function Far_Draws_Last_Frame return Natural is (Far_Drawn);
   function Far_Sent_Last_Frame return Natural is (Far_Sent);

   ---------------------------------------------------------------- frame

   --  (Re)build the multisampled target when the window size changes.  If
   --  the driver rejects it, fall back to drawing straight to the window.
   procedure Prepare_Target (Width, Height : Natural) is
   begin
      if MSAA = 0 or else (Width = Target_W and then Height = Target_H) then
         return;
      end if;
      if Target /= 0 then
         declare
            Old : aliased UInt := Target;
         begin
            Delete_Framebuffers (1, Old'Address);
            Delete_Renderbuffers (1, Color_RB'Address);
            Delete_Renderbuffers (1, Depth_RB'Address);
         end;
      end if;
      Create_Renderbuffers (1, Color_RB);
      Named_Renderbuffer_Storage_Multisample (Color_RB, Sizei (MSAA), RGBA8, Sizei (Width), Sizei (Height));
      Create_Renderbuffers (1, Depth_RB);
      Named_Renderbuffer_Storage_Multisample
        (Depth_RB, Sizei (MSAA), Depth_Component_24, Sizei (Width), Sizei (Height));
      Create_Framebuffers (1, Target);
      Named_Framebuffer_Renderbuffer (Target, Color_Attachment_0, Renderbuffer, Color_RB);
      Named_Framebuffer_Renderbuffer (Target, Depth_Attachment, Renderbuffer, Depth_RB);
      if Check_Named_Framebuffer_Status (Target, Framebuffer) /= Framebuffer_Complete then
         Put_Line (Standard_Error, "render: multisampled target rejected, drawing without MSAA");
         MSAA := 0;
         A2C := False;
         for Wet in Boolean loop
            Program_Uniform_1i (World_Prog (Wet), World_Loc (Wet).A2C, 0);
         end loop;
         Program_Uniform_1i (Fig_Program, Fig_Loc_A2C, 0);
         return;
      end if;
      Target_W := Width;
      Target_H := Height;

      if Scene_FBO /= 0 then
         declare
            Old : aliased UInt := Scene_FBO;
         begin
            Delete_Framebuffers (1, Old'Address);
            Delete_Textures (1, Scene_Col'Address);
            Delete_Textures (1, Scene_Z'Address);
         end;
      end if;
      Create_Textures (Texture_2D, 1, Scene_Col);
      Texture_Storage_2D (Scene_Col, 1, RGBA8, Sizei (Width), Sizei (Height));
      Texture_Parameter_I (Scene_Col, Texture_Min_Filter, Linear);
      Texture_Parameter_I (Scene_Col, Texture_Mag_Filter, Linear);
      Texture_Parameter_I (Scene_Col, Texture_Wrap_S, Clamp_To_Edge);
      Texture_Parameter_I (Scene_Col, Texture_Wrap_T, Clamp_To_Edge);
      Create_Textures (Texture_2D, 1, Scene_Z);
      Texture_Storage_2D (Scene_Z, 1, Depth_Component_24, Sizei (Width), Sizei (Height));
      Texture_Parameter_I (Scene_Z, Texture_Min_Filter, Nearest);
      Texture_Parameter_I (Scene_Z, Texture_Mag_Filter, Nearest);
      Texture_Parameter_I (Scene_Z, Texture_Wrap_S, Clamp_To_Edge);
      Texture_Parameter_I (Scene_Z, Texture_Wrap_T, Clamp_To_Edge);
      Create_Framebuffers (1, Scene_FBO);
      Named_Framebuffer_Texture (Scene_FBO, Color_Attachment_0, Scene_Col, 0);
      Named_Framebuffer_Texture (Scene_FBO, Depth_Attachment, Scene_Z, 0);
      Scene_Ready := Check_Named_Framebuffer_Status (Scene_FBO, Framebuffer) = Framebuffer_Complete;
      if not Scene_Ready then
         Put_Line (Standard_Error, "render: the picture cannot be read back, water mirrors the sky alone");
      end if;
   end Prepare_Target;

   --  (Re)build the clouds' picture when the window's size changes.
   procedure Prepare_Clouds (Width, Height : Natural) is
      W : constant Natural := (Width + 1) / 2;
      H : constant Natural := (Height + 1) / 2;
   begin
      if W = Cloud_W and then H = Cloud_H then
         return;
      end if;
      if Cloud_FBO /= 0 then
         declare
            Old : aliased UInt := Cloud_FBO;
         begin
            Delete_Framebuffers (1, Old'Address);
            Delete_Textures (1, Cloud_Tex'Address);
         end;
      end if;
      Create_Textures (Texture_2D, 1, Cloud_Tex);
      Texture_Storage_2D (Cloud_Tex, 1, RGBA16F, Sizei (W), Sizei (H));
      Texture_Parameter_I (Cloud_Tex, Texture_Min_Filter, Linear);
      Texture_Parameter_I (Cloud_Tex, Texture_Mag_Filter, Linear);
      Texture_Parameter_I (Cloud_Tex, Texture_Wrap_S, Clamp_To_Edge);
      Texture_Parameter_I (Cloud_Tex, Texture_Wrap_T, Clamp_To_Edge);
      Create_Framebuffers (1, Cloud_FBO);
      Named_Framebuffer_Texture (Cloud_FBO, Color_Attachment_0, Cloud_Tex, 0);
      Cloud_Ready := Check_Named_Framebuffer_Status (Cloud_FBO, Framebuffer) = Framebuffer_Complete;
      if not Cloud_Ready then
         Put_Line (Standard_Error, "render: the clouds' picture rejected, drawing them as one flat layer");
      end if;
      Cloud_W := W;
      Cloud_H := H;
   end Prepare_Clouds;

   --  People: new skins into their layers and this frame's bones and
   --  boxes into their buffers, before anything is drawn (the shadow maps
   --  draw them first).
   procedure Upload_Figures is
      use Castle.Figures;
      Fresh : Boolean := False;
   begin
      loop
         declare
            L     : Look_Id;
            Sk    : Skin_Access;
            Found : Boolean;
         begin
            Next_Upload (L, Sk, Found);
            exit when not Found;
            Pixel_Store_I (Unpack_Alignment, 4);
            Texture_Sub_Image_3D (Skin_Tex, 0, 0, 0, int (L - 1), Castle.Bodies.Skin_W, Castle.Bodies.Skin_H, 1,
                                  RGBA, Unsigned_Byte, Sk.all (0, 0)'Address);
            Fresh := True;
         end;
      end loop;
      if Fresh then
         Generate_Texture_Mipmap (Skin_Tex);
      end if;
      if Box_Count > 0 then
         Named_Buffer_Sub_Data (Fig_Bone_Buf, 0, Sizeiptr (Bone_Count * 48), Bones (0)'Address);
         Named_Buffer_Sub_Data (Fig_Box_Buf, 0, Sizeiptr (Box_Count * 48), Boxes (0)'Address);
      end if;
   end Upload_Figures;

   --  The shadow discs, then every box of every figure.
   procedure Draw_Figures (Eye, Focus : Vec3; VP : Mat4; Fog_Distance : Float) is
      use Castle.Figures;
      M : aliased Mat4 := VP;
   begin
      if Box_Count = 0 then
         return;
      end if;
      Bind_Vertex_Array (Sky_VAO);

      if Blob_Count > 0 then
         Named_Buffer_Sub_Data (Fig_Blob_Buf, 0, Sizeiptr (Blob_Count * 16), Blobs (0)'Address);
         Use_Program (Blob_Program);
         Program_Uniform_Matrix_4fv (Blob_Program, Blob_Loc_VP, 1, GL_False, M (0)'Address);
         Program_Uniform_3f (Blob_Program, Blob_Loc_Camera, Float32 (Eye.X), Float32 (Eye.Y), Float32 (Eye.Z));
         --  where the sun casts the figure's own shadow the disc is not wanted;
         --  under cloud and at night it is what stands the figure on the ground
         --  (with shadows off: the disc as it always was, darker in sunshine)
         Program_Uniform_1f (Blob_Program, Blob_Loc_Strength,
                             Float32 (if Shadows and then Shadows_Ready
                                      then Contact_Shade * (1.0 - Smooth (0.02, 0.25, Luma (Day.Lamp_Col)))
                                      else 0.18 + 0.5 * Luma (Day.Lamp_Col)));
         Bind_Buffer_Base (Shader_Storage_Buffer, 10, Fig_Blob_Buf);
         Enable (Depth_Test);
         Depth_Func (Lequal);
         Depth_Mask (GL_False);
         Disable (Cull_Face_Cap);
         Enable (Blend);
         Blend_Func (Src_Alpha, One_Minus_Src_Alpha);
         Draw_Arrays (Triangles, 0, Sizei (6 * Blob_Count));
         Disable (Blend);
         Depth_Mask (GL_True);
         Depth_Func (Less);
         Enable (Cull_Face_Cap);
      end if;

      Use_Program (Fig_Program);
      Program_Uniform_Matrix_4fv (Fig_Program, Fig_Loc_VP, 1, GL_False, M (0)'Address);
      Program_Uniform_3f (Fig_Program, Fig_Loc_Camera, Float32 (Eye.X), Float32 (Eye.Y), Float32 (Eye.Z));
      Program_Uniform_3f (Fig_Program, Fig_Loc_Focus, Float32 (Focus.X), Float32 (Focus.Y), Float32 (Focus.Z));
      Program_Uniform_1f (Fig_Program, Fig_Loc_Fog, Float32 (Fog_Distance));
      Bind_Buffer_Base (Shader_Storage_Buffer, 8, Fig_Bone_Buf);
      Bind_Buffer_Base (Shader_Storage_Buffer, 9, Fig_Box_Buf);
      Bind_Texture_Unit (8, Skin_Tex);
      Bind_Texture_Unit (3, Noise_Tex);
      Enable (Depth_Test);
      Depth_Func (Less);
      Depth_Mask (GL_True);
      Enable (Cull_Face_Cap);
      Cull_Face (Back);
      Front_Face (CCW);
      Disable (Blend);
      if A2C then
         Enable (Sample_Alpha_To_Coverage);     --  (every box's alpha is 1 but a thin look's)
      end if;
      Draw_Arrays (Triangles, 0, Sizei (Box_Vertices * Box_Count));
      Disable (Sample_Alpha_To_Coverage);
   end Draw_Figures;

   procedure Draw_Marks (Eye : Vec3; VP : Mat4) is
      M : aliased Mat4 := VP;
   begin
      if Castle.Marks.Count = 0 then
         return;
      end if;
      Named_Buffer_Sub_Data (Mark_Buf, 0, Sizeiptr (Castle.Marks.Count * 48), Castle.Marks.Marks (0)'Address);
      Bind_Vertex_Array (Sky_VAO);
      Use_Program (Mark_Program);
      Program_Uniform_Matrix_4fv (Mark_Program, Mark_Loc_VP, 1, GL_False, M (0)'Address);
      Program_Uniform_3f (Mark_Program, Mark_Loc_Camera, Float32 (Eye.X), Float32 (Eye.Y), Float32 (Eye.Z));
      Program_Uniform_1f (Mark_Program, Mark_Loc_Dim, Float32 (Marks_By_Night + (1.0 - Marks_By_Night) * Day.Lit));
      Bind_Buffer_Base (Shader_Storage_Buffer, 11, Mark_Buf);
      Enable (Depth_Test);
      Depth_Func (Lequal);
      Depth_Mask (GL_False);
      Disable (Cull_Face_Cap);
      Enable (Blend);
      Blend_Func (Src_Alpha, One_Minus_Src_Alpha);
      Draw_Arrays (Triangles, 0, Sizei (6 * Castle.Marks.Count));
      Disable (Blend);
      Depth_Mask (GL_True);
      Depth_Func (Less);
      Enable (Cull_Face_Cap);
   end Draw_Marks;

   ---------------------------------------------------------------- shadows

   --  The direction shadows are cast from: the sun's, but never from lower
   --  than Shadow_Low_Sun (the shadows of a sun on the horizon have no end).
   function Cast_From (Sun : Vec3) return Vec3 is
      use Ada.Numerics.Elementary_Functions;
      N : constant Vec3 := Normalize (Sun);
      H : constant Float := Sqrt (N.X * N.X + N.Y * N.Y);
      C : constant Float := Sqrt (1.0 - Shadow_Low_Sun * Shadow_Low_Sun);
   begin
      if N.Z >= Shadow_Low_Sun or else H < 1.0E-4 then
         return N;
      end if;
      return (N.X / H * C, N.Y / H * C, Shadow_Low_Sun);
   end Cast_From;

   --  Where a shadow lies from what casts it, for each metre of its height.
   function Lean_Of (D : Vec3) return Vec3 is (D.X / D.Z, D.Y / D.Z, 0.0);

   --  Which two directions the maps are held at, and how far the sun is
   --  from the one to the other (Shadow_Mix).  The sun's place is followed
   --  by where shadows lie (Lean_Of), since that is what a step is seen by.
   procedure Hold_Sun is
      use Ada.Numerics.Elementary_Functions;
      function Len (V : Vec3) return Float is (Sqrt (Dot (V, V)));
      function Cast_In (Minutes : Float) return Vec3 is
        (Cast_From (Lamp_At (Current.Day + Minutes / 1_440.0, Current.Hour + Minutes / 60.0,
                             Current.Moon + Current.Moon_Per_Day * Minutes / 1_440.0)));
      Now_D   : constant Vec3 := Cast_From (Day.Lamp);
      Now_L   : constant Vec3 := Lean_Of (Now_D);
      Per_Min : constant Float := Len (Lean_Of (Cast_In (1.0)) - Now_L);   --  shadows' travel in a game minute
      --  How many game minutes on the next held direction lies: where
      --  shadows will have moved Shadow_Hold, and no nearer than the sun
      --  goes in Shadow_Min_Frames frames at the pace it is going.
      function Ahead return Float is
         Want : constant Float := Float'Max (Shadow_Hold, Sun_Pace * Float (Shadow_Min_Frames));
      begin
         return (if Per_Min * 30.0 > Want then Want / Per_Min else 30.0);
      end Ahead;
      procedure Aim (M : in out Held_Map; Minutes : Float) is
      begin
         M.Dir := Cast_In (Minutes);
         M.Lean := Lean_Of (M.Dir);
      end Aim;
      --  how far along the line from A to A + AB the sun is, and how far off it
      procedure Along (A, AB : Vec3; T, Off : out Float) is
         L2 : constant Float := Dot (AB, AB);
      begin
         T := (if L2 > 0.0 then Dot (Now_L - A, AB) / L2 else 2.0);
         Off := Len (Now_L - (A + AB * T)) - 0.25 * Sqrt (L2);
      end Along;
      T, Off : Float;
   begin
      Sun_Pace := (if Held_Ok then 0.8 * Sun_Pace + 0.2 * Len (Now_L - Last_Lean) else 0.0);
      Last_Lean := Now_L;
      if Held_Ok then
         Along (Held (From).Lean, Held (1 - From).Lean - Held (From).Lean, T, Off);
         if Off <= 1.0E-4 and then T >= -0.02 and then T <= 1.0 then
            Shadow_Mix := Float'Max (0.0, T);
            return;
         elsif Off <= 1.0E-4 and then T > 1.0 and then T < 2.5 then
            --  the sun has come to the direction it was coming to: that is now
            --  the one it has passed, and the other map is drawn for the next
            From := 1 - From;
            Aim (Held (1 - From), Ahead);
            Along (Held (From).Lean, Held (1 - From).Lean - Held (From).Lean, T, Off);
            Shadow_Mix := Float'Max (0.0, Float'Min (1.0, T));
            return;
         end if;
      end if;
      --  a start, the clock put elsewhere or run back: begin from where the sun is
      Held (From).Dir := Now_D;
      Held (From).Lean := Now_L;
      Aim (Held (1 - From), Ahead);
      Shadow_Mix := 0.0;
      Held_Ok := True;
   end Hold_Sun;

   --  The sun's view from Dir (toward the sun) over a square Half metres
   --  each way round Focus and Reach metres along the light each way.  The
   --  square is moved to a whole number of Snap texels across the light
   --  (Cs, Cu: which), so what holds still in the world lands on the same
   --  texels wherever the focus goes.
   procedure Sun_View (Dir, Focus : Vec3; Half, Reach : Float; Size, Snap : Positive;
                       VP : out Mat4; Cs, Cu : out Float) is
      Fwd    : constant Vec3 := (-Dir.X, -Dir.Y, -Dir.Z);
      Up_Ref : constant Vec3 := (if abs Dir.Z > 0.99 then (0.0, 1.0, 0.0) else (0.0, 0.0, 1.0));
      Side   : constant Vec3 := Normalize (Cross (Fwd, Up_Ref));
      Up     : constant Vec3 := Cross (Side, Fwd);
      Step   : constant Float := 2.0 * Half / Float (Size) * Float (Snap);
      Fs     : constant Float := Dot (Focus, Side);
      Fu     : constant Float := Dot (Focus, Up);
      Centre : Vec3;
      Eye_L  : Vec3;
      Near   : constant Float := 100.0;
      Far    : constant Float := 100.0 + 2.0 * Reach;
      Ortho  : Mat4 := (others => 0.0);
      Move   : Mat4 := (0 => 1.0, 5 => 1.0, 10 => 1.0, 15 => 1.0, others => 0.0);
   begin
      Cs := Float'Rounding (Fs / Step);
      Cu := Float'Rounding (Fu / Step);
      Centre := Focus + Side * (Cs * Step - Fs) + Up * (Cu * Step - Fu);
      Eye_L := Centre + Dir * (Reach + Near);
      Ortho (0)  := 1.0 / Half;
      Ortho (5)  := 1.0 / Half;
      Ortho (10) := -2.0 / (Far - Near);
      Ortho (14) := -(Far + Near) / (Far - Near);
      Ortho (15) := 1.0;
      Move (12) := -Eye_L.X;
      Move (13) := -Eye_L.Y;
      Move (14) := -Eye_L.Z;
      VP := Ortho * Look_Dir (Fwd, Up_Ref) * Move;
   end Sun_View;

   --  Depth maps are drawn back faces first: a lit face then keeps clear of
   --  its own shadow, and a shadow begins at the far side of what casts it.
   procedure Begin_Casting is
   begin
      Depth_Mask (GL_True);
      Enable (Depth_Test);
      Depth_Func (Less);
      Enable (Cull_Face_Cap);
      Cull_Face (Front);
      Front_Face (CCW);
      Enable (Polygon_Offset_Fill);
      Polygon_Offset (1.5, 3.0);
   end Begin_Casting;

   procedure End_Casting is
   begin
      Disable (Polygon_Offset_Fill);
      Cull_Face (Back);
   end End_Casting;

   --  Everything that casts a shadow, into the depth target bound (between
   --  Begin_Casting and End_Casting): the land, Land_N stacks from Land_At
   --  in the command buffer (none: it is left out), and with Figures every
   --  box of every figure.  View is the light's, of points less Origin.
   --  Whatever the game shows is drawn through one of these two, so it
   --  casts from every light with nothing more to do; a new way of drawing
   --  solid things gets its depth pass here, once.
   procedure Draw_Casters (View : Mat4; Origin : Vec3; Land_At, Land_N : Natural; Figures : Boolean) is
      V : aliased Mat4 := View;
   begin
      if Land_N > 0 then
         Use_Program (Shadow_Program);
         Bind_Vertex_Array (VAO);
         Bind_Buffer_Base (Shader_Storage_Buffer, 0, Quad_Buf);
         Bind_Buffer (Draw_Indirect_Buffer, Cmd_Buf);
         Program_Uniform_Matrix_4fv (Shadow_Program, Loc_S_VP, 1, GL_False, V (0)'Address);
         Program_Uniform_3f (Shadow_Program, Loc_S_Camera,
                             Float32 (Origin.X), Float32 (Origin.Y), Float32 (Origin.Z));
         Multi_Draw_Arrays_Indirect (Triangles, To_Address (Integer_Address (Land_At * 16)), Sizei (Land_N), 16);
      end if;
      if Figures and then Castle.Figures.Box_Count > 0 then
         Use_Program (Caster_Program);
         Bind_Vertex_Array (Sky_VAO);
         Bind_Buffer_Base (Shader_Storage_Buffer, 8, Fig_Bone_Buf);
         Bind_Buffer_Base (Shader_Storage_Buffer, 9, Fig_Box_Buf);
         Program_Uniform_Matrix_4fv (Caster_Program, Loc_C_VP, 1, GL_False, V (0)'Address);
         Program_Uniform_3f (Caster_Program, Loc_C_Camera,
                             Float32 (Origin.X), Float32 (Origin.Y), Float32 (Origin.Z));
         Draw_Arrays (Triangles, 0, Sizei (Castle.Figures.Box_Vertices * Castle.Figures.Box_Count));
      end if;
   end Draw_Casters;

   procedure Draw (Eye, Focus : Vec3; View_Proj : Mat4; Width, Height : Natural;
                   Fog_Distance : Float) is
      F       : constant Frustum := Planes (View_Proj);
      VP      : aliased Mat4 := View_Proj;
      Seen    : Natural := 0;
      K       : Natural := 0;
      N_Solid : Natural := 0;
   begin
      for I in 1 .. Loaded_N loop
         declare
            C  : constant Coord := Loaded_List (I);
            S  : Slot renames Slots (C.CX, C.CY);
            Lo : constant Vec3 := (Float (C.CX) * 8.0 - Eye.X, Float (C.CY) * 8.0 - Eye.Y,
                                   Float (S.Z_Lo) * 0.25 - Eye.Z);
            Hi : constant Vec3 := (Lo.X + 8.0, Lo.Y + 8.0, Float (S.Z_Hi + 1) * 0.25 - Eye.Z);
            --  how far its nearest side is from the focus, across the ground: past
            --  Fog_Distance it would be drawn all haze, the sky's own colour, so it
            --  isn't drawn (the colony keeps its ground loaded far from the camera)
            Gx : constant Float :=
              Float'Max (0.0, Float'Max (Float (C.CX) * 8.0 - Focus.X, Focus.X - Float (C.CX + 1) * 8.0));
            Gy : constant Float :=
              Float'Max (0.0, Float'Max (Float (C.CY) * 8.0 - Focus.Y, Focus.Y - Float (C.CY + 1) * 8.0));
         begin
            if S.S_Count + S.W_Count > 0 and then Gx * Gx + Gy * Gy < Fog_Distance * Fog_Distance
              and then Box_Visible (F, Lo, Hi)
            then
               Seen := Seen + 1;
               Visible (Seen) := I;
            end if;
         end;
      end loop;

      --  The land is drawn nearest first (Near_First), so that what stands in
      --  front is in the depth buffer before what it hides comes to be shaded,
      --  and is not: stacks by how far their middles are from the eye, to the
      --  nearest 8 m, in one counting pass.  The water after it keeps the
      --  order it had (it is blended, and has never been sorted).
      if Near_First then
         declare
            Rings : constant := 255;
            Ring  : array (1 .. Seen) of Natural;
            Count : array (0 .. Rings + 1) of Natural := [others => 0];
         begin
            for J in 1 .. Seen loop
               declare
                  C  : constant Coord := Loaded_List (Visible (J));
                  S  : Slot renames Slots (C.CX, C.CY);
                  Dx : constant Float := Float (C.CX) * 8.0 + 4.0 - Eye.X;
                  Dy : constant Float := Float (C.CY) * 8.0 + 4.0 - Eye.Y;
                  Dz : constant Float := Float (S.Z_Lo + S.Z_Hi + 1) * 0.125 - Eye.Z;
                  D  : constant Float := Ada.Numerics.Elementary_Functions.Sqrt (Dx * Dx + Dy * Dy + Dz * Dz);
               begin
                  Ring (J) := Natural'Min (Rings, Natural (D / 8.0));
                  Count (Ring (J) + 1) := Count (Ring (J) + 1) + 1;
               end;
            end loop;
            for R in 1 .. Rings + 1 loop
               Count (R) := Count (R) + Count (R - 1);       --  where each ring begins
            end loop;
            for J in 1 .. Seen loop
               Count (Ring (J)) := Count (Ring (J)) + 1;
               Near_Order (Count (Ring (J))) := Visible (J);
            end loop;
         end;
      else
         for J in 1 .. Seen loop
            Near_Order (J) := Visible (J);
         end loop;
      end if;

      --  The far view's tiles that can show: in the view, not wholly past
      --  their own ring, and not wholly inside it under finer ground that is
      --  loaded (the shader settles the rest fragment by fragment).
      Far_Drawn := 0;
      Far_Sent := 0;
      Far_Frame := Far_Frame + 1;
      if Far_Coming > 0 then
         for I in 1 .. Far_N loop
            declare
               T : constant Far_Ref := Far_List (I);
               S : Far_Slot renames Far_Slots (T.L, T.TX, T.TY);
            begin
               if S.Coming then
                  declare
                     Share : constant Natural :=
                       Natural'Min (255, ((Far_Frame - S.Born) * 255) / Natural'Max (1, Far_Arrive_Frames));
                  begin
                     Mark_Far (T.L, T.TX, T.TY, Unsigned_8 (Share));
                     if Share = 255 then
                        S.Coming := False;
                        Far_Coming := Far_Coming - 1;
                     end if;
                  end;
               end if;
            end;
         end loop;
      end if;
      if Far_View then
         declare
            R0   : constant Float := Fog_Distance;
            use Ada.Numerics.Elementary_Functions;
            Near : constant Float := R0 * 2.0 ** (-Float (Far_Fade));      --  where the stacks begin to give way
            --  Every 16 m of the tile has finer ground loaded over it.
            function Under_Finer (L, TX, TY : Integer) return Boolean is
               N : constant Integer := 2 ** (L - 1);
            begin
               for Y in TY * N .. TY * N + N - 1 loop
                  for X in TX * N .. TX * N + N - 1 loop
                     --  (no finer level of the far view wholly in here)
                     if (for all K in 1 .. L - 1 => Far_Have (Y, X) (K) < 255) then
                        declare
                           Fx : constant Float := Float'Max (abs (Float (X) * 16.0 - Focus.X), abs (Float (X + 1) * 16.0 - Focus.X));
                           Fy : constant Float := Float'Max (abs (Float (Y) * 16.0 - Focus.Y), abs (Float (Y + 1) * 16.0 - Focus.Y));
                        begin
                           if Fx * Fx + Fy * Fy >= Near * Near
                             or else not (Slots (2 * X, 2 * Y).Loaded and then Slots (2 * X + 1, 2 * Y).Loaded
                                          and then Slots (2 * X, 2 * Y + 1).Loaded
                                          and then Slots (2 * X + 1, 2 * Y + 1).Loaded)
                           then
                              return False;
                           end if;
                        end;
                     end if;
                  end loop;
               end loop;
               return True;
            end Under_Finer;
         begin
            for I in 1 .. Far_N loop
                  begin
                     declare
                        L    : constant Integer := Far_List (I).L;
                        T    : constant Far_Ref := Far_List (I);
                        S    : Far_Slot renames Far_Slots (T.L, T.TX, T.TY);
                        Side : constant Float := Float (2 ** L) * 8.0;
                        Cell : constant Float := Float (2 ** L) * 0.25;
                        X0   : constant Float := Float (T.TX) * Side;
                        Y0   : constant Float := Float (T.TY) * Side;
                        Lo   : constant Vec3 := (X0 - Eye.X, Y0 - Eye.Y, Float (S.Z_Lo) * Cell - Eye.Z);
                        Hi   : constant Vec3 := (Lo.X + Side, Lo.Y + Side, Float (S.Z_Hi + 1) * Cell - Eye.Z);
                        Nx   : constant Float := Float'Max (0.0, Float'Max (X0 - Focus.X, Focus.X - (X0 + Side)));
                        Ny   : constant Float := Float'Max (0.0, Float'Max (Y0 - Focus.Y, Focus.Y - (Y0 + Side)));
                        Fx   : constant Float := Float'Max (abs (X0 - Focus.X), abs (X0 + Side - Focus.X));
                        Fy   : constant Float := Float'Max (abs (Y0 - Focus.Y), abs (Y0 + Side - Focus.Y));
                        Outer : constant Float := R0 * 2.0 ** L;
                        Inner : constant Float := R0 * 2.0 ** (Float (L - 1) - Float (Far_Fade));
                     begin
                        if S.S_Count + S.W_Count > 0
                          and then (L = Castle.Lod.Max_Level or else Nx * Nx + Ny * Ny < Outer * Outer)
                          and then Box_Visible (F, Lo, Hi)
                          and then not (Fx * Fx + Fy * Fy < Inner * Inner and then Under_Finer (T.L, T.TX, T.TY))
                        then
                           Far_Drawn := Far_Drawn + 1;
                           Far_Seen (Far_Drawn) := I;
                        end if;
                     end;
                  end;
            end loop;
         end;
      end if;

      for Pass in 1 .. 2 loop
         for J in 1 .. Seen loop
            exit when K = Max_Draws;
            declare
               C     : constant Coord := Loaded_List ((if Pass = 1 then Near_Order (J) else Visible (J)));
               S     : Slot renames Slots (C.CX, C.CY);
               Count : constant Natural := (if Pass = 1 then S.S_Count else S.W_Count);
               Start : constant Natural := (if Pass = 1 then S.S_Start else S.W_Start);
            begin
               if Count > 0 then
                  Cmds (K) := (Count => Unsigned_32 (Count * 6), Instances => 1,
                               First => Unsigned_32 (Start * 6), Base => Unsigned_32 (K));
                  Origins (K) := (Integer_32 (C.CX * Chunk_B), Integer_32 (C.CY * Chunk_B), 0, 0);
                  K := K + 1;
               end if;
            end;
         end loop;
         --  A far tile's solid quads come face by face, and those of a face
         --  that looks away from the eye wherever in the tile it stands are not
         --  sent (of John's list: back-face chunk culling): seen from outside
         --  and above, half of them or more.  Faces next to each other in the
         --  order that are both sent go as one draw.
         for J in 1 .. Far_Drawn loop
            exit when K + 6 > Max_Draws;
            declare
               T     : constant Far_Ref := Far_List (Far_Seen (J));
               S     : Far_Slot renames Far_Slots (T.L, T.TX, T.TY);
               Side  : constant Float := Float (2 ** T.L) * 8.0;
               Cell  : constant Float := Float (2 ** T.L) * 0.25;
               X0    : constant Float := Float (T.TX) * Side;
               Y0    : constant Float := Float (T.TY) * Side;
               Shows : constant array (0 .. 5) of Boolean :=
                 [Eye.X > X0, Eye.X < X0 + Side, Eye.Y > Y0, Eye.Y < Y0 + Side,
                  Eye.Z > Float (S.Z_Lo) * Cell, Eye.Z < Float (S.Z_Hi + 1) * Cell];
               At_Q  : Natural := S.S_Start;
               Run_At, Run_N : Natural := 0;

               procedure Send (Start, Count : Natural) is
               begin
                  if Count > 0 then
                     Cmds (K) := (Count => Unsigned_32 (Count * 6), Instances => 1,
                                  First => Unsigned_32 (Start * 6), Base => Unsigned_32 (K));
                     Origins (K) := (Integer_32 (T.TX * 2 ** T.L * Chunk_B), Integer_32 (T.TY * 2 ** T.L * Chunk_B), 0,
                                     Integer_32 (T.L));
                     K := K + 1;
                  end if;
               end Send;
            begin
               if Pass = 2 then
                  Send (S.W_Start, S.W_Count);
               elsif not Far_Cull then
                  Send (S.S_Start, S.S_Count);
               else
                  for Fc in 0 .. 5 loop
                     if Shows (Fc) and then S.By_Face (Fc) > 0 then
                        if Run_N = 0 then
                           Run_At := At_Q;
                        end if;
                        Run_N := Run_N + S.By_Face (Fc);
                        Far_Sent := Far_Sent + S.By_Face (Fc);
                     else
                        Send (Run_At, Run_N);
                        Run_N := 0;
                     end if;
                     At_Q := At_Q + S.By_Face (Fc);
                  end loop;
                  Send (Run_At, Run_N);
               end if;
            end;
         end loop;
         if Pass = 1 then
            N_Solid := K;
         end if;
      end loop;
      Draws := K;

      --  (the timer covers the whole frame: the sun's and the snow's maps too)
      declare
         Slot  : constant UInt := Queries (Issued mod Queries'Length);
         Ready : int := 0;
         Ns    : unsigned_long_long := 0;
      begin
         if Issued >= Queries'Length then
            Get_Query_Object_Iv (Slot, Query_Result_Available, Ready);
            if Ready /= 0 then
               Get_Query_Object_Ui64v (Slot, Query_Result, Ns);
               Last_GPU_Ms := Float (Ns) / 1.0E6;
            end if;
         end if;
         Begin_Query (Time_Elapsed, Slot);
      end;

      Upload_Figures;
      Place_Lights (Focus, Fog_Distance);
      Bind_Buffer_Base (Shader_Storage_Buffer, 12, Light_Buf);
      Bind_Texture_Unit (17, Light_Tex);

      --  The sun's shadows (see the spec): which two directions are held,
      --  and how far the sun is from the one to the other; for each, the
      --  land's map if it is out of date (a new direction, the focus a snap
      --  further on, a mesh changed) and the figures' map, every frame.
      declare
         use Ada.Numerics.Elementary_Functions;
         --  (the lamp's shadows: the sun's, or the moon's while its light is
         --  worth the maps)
         Sun_Up   : constant Boolean :=
           Shadows and then Shadows_Ready and then Luma (Day.Lamp_Col) > Shadow_Least;
         Half     : constant Float :=
           (Fog_Distance + 16.0) * Float (Shadow_Size) / Float (Shadow_Size - Shadow_Snap);
         Texel    : constant Float := 2.0 * Half / Float (Shadow_Size);
         To_Eye   : constant Vec3 := Eye - Focus;
         Dist     : constant Float := Sqrt (Dot (To_Eye, To_Eye));
         Fig_Half : Float := Figure_Shadow_M;
         Land_At, Land_N : array (0 .. 1) of Natural := [others => 0];   --  each held map's draws of the land
         Redraw   : array (0 .. 1) of Boolean := [others => False];
         Next     : Natural := K;                 --  the next free command
         Snow_At  : Natural := 0;
         Nw       : Natural := 0;                 --  snow-map draws
         --  the fire casts while it burns within sight
         Fire_Off : constant Vec3 := Fire_At - Focus;
         Fire_On  : constant Boolean :=
           Shadows and then Fire_Ready and then Fire_K > 0.0
           and then Sqrt (Fire_Off.X * Fire_Off.X + Fire_Off.Y * Fire_Off.Y) < Fog_Distance + Fire_Reach_M;
         Fire_Land_At, Fire_Land_N : Natural := 0;   --  the stacks its light reaches
         Far_Cast : Integer := -1;                   --  which held direction's far map is drawn again this frame
         Far_Cast_At, Far_Cast_N : Natural := 0;
         Far_Sh_On : constant Boolean := Sun_Up and then Far_View and then Far_Shadows;
         Snow_On : constant Boolean :=
           Snow_Ready and then (Current.Snow_Lo + Current.Snow_Mid + Current.Snow_Hi > 0.0
                                or else Current.Rain + Current.Snowfall > 0.0
                                or else (Wetness and then Current.Wet > 0.0));
         S_Half  : constant Float := Fog_Distance + 16.0;
         S_Texel : constant Float := 2.0 * S_Half / Float (Snow_Size);
         Sx      : constant Float := Float'Rounding (Focus.X / S_Texel) * S_Texel;
         Sy      : constant Float := Float'Rounding (Focus.Y / S_Texel) * S_Texel;
         S_Key   : constant Shadow_Key :=
           (Sx, Sy, Float (Changes), Float'Rounding (Current.Leaf_Fall * 50.0), 0.0, 0.0);

         --  The far view's tiles that cast (see the spec, Far_Shadows), as
         --  commands from Next on: every tile that lies in its own ring,
         --  whole or in part (the ring's rule with no cross-fade: one level
         --  casts in any one place, or two where a tile lies across a ring's
         --  edge), and, unless Whole, only those the light's view LF holds
         --  whose tops stand over Low by Rise for every metre they are past
         --  the stacks' ground (the light's slope: lower, their shadows end
         --  short of the view).
         procedure Cast_Tiles (LF : Frustum; Whole : Boolean; Rise : Float := 0.0; Low : Float := 0.0) is
            R0 : constant Float := Fog_Distance;
         begin
            for J in 1 .. Far_N loop
               exit when Next = Max_Draws;
               declare
                  T     : constant Far_Ref := Far_List (J);
                  S     : Far_Slot renames Far_Slots (T.L, T.TX, T.TY);
                  Side  : constant Float := Float (2 ** T.L) * 8.0;
                  Cell  : constant Float := Float (2 ** T.L) * 0.25;
                  X0    : constant Float := Float (T.TX) * Side;
                  Y0    : constant Float := Float (T.TY) * Side;
                  Nx    : constant Float := Float'Max (0.0, Float'Max (X0 - Focus.X, Focus.X - (X0 + Side)));
                  Ny    : constant Float := Float'Max (0.0, Float'Max (Y0 - Focus.Y, Focus.Y - (Y0 + Side)));
                  Fx    : constant Float := Float'Max (abs (X0 - Focus.X), abs (X0 + Side - Focus.X));
                  Fy    : constant Float := Float'Max (abs (Y0 - Focus.Y), abs (Y0 + Side - Focus.Y));
                  Outer : constant Float := R0 * Float (2 ** T.L);
                  Inner : constant Float := R0 * Float (2 ** (T.L - 1));
               begin
                  if S.S_Count > 0
                    and then (T.L = Castle.Lod.Max_Level or else Nx * Nx + Ny * Ny < Outer * Outer)
                    and then Fx * Fx + Fy * Fy > Inner * Inner
                    and then (Whole
                              or else (Box_Visible (LF, (X0, Y0, Float (S.Z_Lo) * Cell),
                                                    (X0 + Side, Y0 + Side, Float (S.Z_Hi + 1) * Cell))
                                       --  (and stands high enough to shade the view from where it
                                       --  is: at noon next to nothing past the view's edge does)
                                       and then Float (S.Z_Hi + 1) * Cell - Low
                                                >= Rise * Float'Max (0.0, Sqrt (Nx * Nx + Ny * Ny) - (R0 + 16.0))))
                  then
                     Cmds (Next) := (Count => Unsigned_32 (S.S_Count * 6), Instances => 1,
                                     First => Unsigned_32 (S.S_Start * 6), Base => Unsigned_32 (Next));
                     Origins (Next) := (Integer_32 (T.TX * 2 ** T.L * Chunk_B), Integer_32 (T.TY * 2 ** T.L * Chunk_B), 0,
                                        Integer_32 (T.L));
                     Next := Next + 1;
                  end if;
               end;
            end loop;
         end Cast_Tiles;
      begin
         while Fig_Half < Figure_Shadow_By * Dist and then Fig_Half < Half loop
            Fig_Half := 2.0 * Fig_Half;
         end loop;
         Fig_Half := Float'Min (Fig_Half, Half);

         if Sun_Up then
            Hold_Sun;
            for I in Held'Range loop
               declare
                  M      : Held_Map renames Held (I);
                  VP_L   : Mat4;
                  Cs, Cu : Float;
               begin
                  --  (with the far shadows the map reaches as far up the light as
                  --  the map goes: what stands past the view casts into the view)
                  Sun_View (M.Dir, Focus, Half, (if Far_Sh_On then Far_Sh_Reach else 500.0), Shadow_Size, Shadow_Snap,
                            VP_L, Cs, Cu);
                  declare
                     Key  : constant Shadow_Key := (Cs, Cu, M.Dir.X, M.Dir.Y, M.Dir.Z, Float (Changes));
                     LF_P : constant Frustum := Planes (VP_L);
                  begin
                     --  (drawn again too, not often, while the far view's tiles come and go)
                     if Key /= M.Key
                       or else (Far_Sh_On and then M.Seen_Far /= Far_Changes
                                and then Far_Frame - M.Drawn_At >= Far_Shadow_Every)
                     then
                        M.Seen_Far := Far_Changes;
                        M.Drawn_At := Far_Frame;
                        M.Key := Key;
                        M.VP := VP_L;
                        Redraw (I) := True;
                        Land_At (I) := Next;
                        for J in 1 .. Loaded_N loop
                           exit when Next = Max_Draws;
                           declare
                              C  : constant Coord := Loaded_List (J);
                              S  : Slot renames Slots (C.CX, C.CY);
                              Lo : constant Vec3 := (Float (C.CX) * 8.0, Float (C.CY) * 8.0, Float (S.Z_Lo) * 0.25);
                              Hi : constant Vec3 := (Lo.X + 8.0, Lo.Y + 8.0, Float (S.Z_Hi + 1) * 0.25);
                           begin
                              if S.S_Cast > 0 and then Box_Visible (LF_P, Lo, Hi) then
                                 Cmds (Next) := (Count => Unsigned_32 (S.S_Cast * 6), Instances => 1,
                                                 First => Unsigned_32 (S.S_Start * 6), Base => Unsigned_32 (Next));
                                 Origins (Next) := (Integer_32 (C.CX * Chunk_B), Integer_32 (C.CY * Chunk_B), 0, 0);
                                 Next := Next + 1;
                              end if;
                           end;
                        end loop;
                        if Far_Sh_On then
                           declare
                              Low : Float := Float'Last;       --  the lowest ground a stack of the view has
                              Run : constant Float := Sqrt (Float'Max (1.0E-6, 1.0 - M.Dir.Z * M.Dir.Z));
                           begin
                              for J in 1 .. Loaded_N loop
                                 Low := Float'Min (Low, Float (Slots (Loaded_List (J).CX, Loaded_List (J).CY).Z_Lo) * 0.25);
                              end loop;
                              Cast_Tiles (LF_P, Whole => False, Rise => Float'Max (0.0, M.Dir.Z) / Run,
                                          Low => (if Loaded_N > 0 then Low else 0.0));
                           end;
                        end if;
                        Land_N (I) := Next - Land_At (I);
                     end if;
                  end;
                  Sun_View (M.Dir, Focus, Fig_Half, 1.5 * Fig_Half + 40.0, Figure_Size, 1, M.Fig_VP, Cs, Cu);
               end;
            end loop;
         else
            Held_Ok := False;
            for M of Held loop
               M.Key := (others => -1.0);
            end loop;
         end if;

         --  The far shadows (see the spec): which of the two far maps is
         --  drawn again this frame, if either (one whose direction has moved;
         --  else the longer out of date, by what has changed and how long
         --  ago), and what goes into it: every stack's own mesh, and every
         --  tile of the far view that lies in its own ring.
         if Far_Sh_On then
            if not Far_Sh_Tried then
               Far_Sh_Tried := True;
               Far_Sh_Ready := True;
               for M of Held loop
                  declare
                     Ok : Boolean;
                  begin
                     Make_Depth_Map (Far_Shadow_Size, Depth_Component_16, M.Far_Tex, M.Far_FBO, Ok);
                     Far_Sh_Ready := Far_Sh_Ready and then Ok;
                  end;
               end loop;
               if not Far_Sh_Ready then
                  Put_Line (Standard_Error, "render: far shadow map rejected, no shadows past the view's edge");
               end if;
            end if;
            if Far_Sh_Ready then
               for I in Held'Range loop
                  if Far_Cast < 0 and then Held (I).Far_Dir /= Held (I).Dir then
                     Far_Cast := I;
                  end if;
               end loop;
               if Far_Cast < 0 then
                  for I in Held'Range loop
                     declare
                        M   : Held_Map renames Held (I);
                        Age : constant Natural := Far_Frame - M.Far_At;
                     begin
                        if ((M.Far_Tiles /= Far_Changes and then Age >= Far_Shadow_Every)
                            or else ((M.Far_Stacks /= Changes or else M.Far_Remade /= Far_Remakes)
                                     and then Age >= Far_Shadow_Slow))
                          and then (Far_Cast < 0 or else M.Far_At < Held (Far_Cast).Far_At)
                        then
                           Far_Cast := I;
                        end if;
                     end;
                  end loop;
               end if;
            end if;
            if Far_Cast >= 0 then
               declare
                  M      : Held_Map renames Held (Far_Cast);
                  Cs, Cu : Float;
                  Mid    : constant Float := Float (Chunks_XY) * 4.0;
               begin
                  Sun_View (M.Dir, (Mid, Mid, 128.0), Far_Sh_Half, Far_Sh_Reach, Far_Shadow_Size, 1, M.Far_VP, Cs, Cu);
                  M.Far_Dir := M.Dir;
                  M.Far_Tiles := Far_Changes;
                  M.Far_Stacks := Changes;
                  M.Far_Remade := Far_Remakes;
                  M.Far_At := Far_Frame;
                  Far_Cast_At := Next;
                  for J in 1 .. Loaded_N loop
                     exit when Next = Max_Draws;
                     declare
                        C : constant Coord := Loaded_List (J);
                        S : Slot renames Slots (C.CX, C.CY);
                     begin
                        if S.S_Cast > 0 then
                           Cmds (Next) := (Count => Unsigned_32 (S.S_Cast * 6), Instances => 1,
                                           First => Unsigned_32 (S.S_Start * 6), Base => Unsigned_32 (Next));
                           Origins (Next) := (Integer_32 (C.CX * Chunk_B), Integer_32 (C.CY * Chunk_B), 0, 0);
                           Next := Next + 1;
                        end if;
                     end;
                  end loop;
                  Cast_Tiles (Planes (M.Far_VP), Whole => True);
                  Far_Cast_N := Next - Far_Cast_At;
               end;
            end if;
         else
            for M of Held loop
               M.Far_Dir := (0.0, 0.0, 0.0);
            end loop;
         end if;

         --  The snow map: the same ground, seen straight down.  Drawn again only
         --  when the box moves a texel, the loaded meshes change or leaves fall.
         if Snow_On then
            declare
               O    : Mat4 := (others => 0.0);
               Mv   : Mat4 := (0 => 1.0, 5 => 1.0, 10 => 1.0, 15 => 1.0, others => 0.0);
            begin
               O (0) := 1.0 / S_Half;
               O (5) := 1.0 / S_Half;
               O (10) := -2.0 / 440.0;
               O (14) := -(450.0 + 10.0) / 440.0;
               O (15) := 1.0;
               Mv (12) := -Sx;
               Mv (13) := -Sy;
               Mv (14) := -400.0;
               Snow_VP := O * Look_Dir ((0.0, 0.0, -1.0), (0.0, 1.0, 0.0)) * Mv;
            end;
            if S_Key /= Snow_Drawn then
               declare
                  SP : constant Frustum := Planes (Snow_VP);
               begin
                  Snow_At := Next;
                  for I in 1 .. Loaded_N loop
                     exit when Next = Max_Draws;
                     declare
                        C  : constant Coord := Loaded_List (I);
                        S  : Slot renames Slots (C.CX, C.CY);
                        Lo : constant Vec3 := (Float (C.CX) * 8.0, Float (C.CY) * 8.0, Float (S.Z_Lo) * 0.25);
                        Hi : constant Vec3 := (Lo.X + 8.0, Lo.Y + 8.0, Float (S.Z_Hi + 1) * 0.25);
                     begin
                        if S.S_Cast > 0 and then Box_Visible (SP, Lo, Hi) then
                           Cmds (Next) := (Count => Unsigned_32 (S.S_Cast * 6), Instances => 1,
                                           First => Unsigned_32 (S.S_Start * 6), Base => Unsigned_32 (Next));
                           Origins (Next) := (Integer_32 (C.CX * Chunk_B), Integer_32 (C.CY * Chunk_B), 0, 0);
                           Next := Next + 1;
                        end if;
                     end;
                  end loop;
                  Nw := Next - Snow_At;
               end;
            end if;
         end if;

         --  The fire: the stacks within its reach, for all six faces alike.
         if Fire_On then
            Fire_Land_At := Next;
            for CY in Integer (Float'Floor ((Fire_At.Y - Fire_Far_M) / 8.0))
                      .. Integer (Float'Floor ((Fire_At.Y + Fire_Far_M) / 8.0)) loop
               for CX in Integer (Float'Floor ((Fire_At.X - Fire_Far_M) / 8.0))
                         .. Integer (Float'Floor ((Fire_At.X + Fire_Far_M) / 8.0)) loop
                  if CX in Slots'Range (1) and then CY in Slots'Range (2) and then Next < Max_Draws
                    and then Slots (CX, CY).Loaded and then Slots (CX, CY).S_Cast > 0
                  then
                     Cmds (Next) := (Count => Unsigned_32 (Slots (CX, CY).S_Cast * 6), Instances => 1,
                                     First => Unsigned_32 (Slots (CX, CY).S_Start * 6), Base => Unsigned_32 (Next));
                     Origins (Next) := (Integer_32 (CX * Chunk_B), Integer_32 (CY * Chunk_B), 0, 0);
                     Next := Next + 1;
                  end if;
               end loop;
            end loop;
            Fire_Land_N := Next - Fire_Land_At;
         end if;

         --  (a frame that wants more draws than there is room for drops the
         --  last of them: some of the land out of a depth map.  Said once.)
         if Next = Max_Draws and then not Draws_Short then
            Draws_Short := True;
            Put_Line (Standard_Error, "render: more than" & Natural'Image (Max_Draws)
                      & " draws in a frame: some of the land is left out of the shadows' or the snow's map");
         end if;
         --  (every pass's commands go up together, before any is drawn)
         if Next > 0 then
            Named_Buffer_Sub_Data (Cmd_Buf, 0, Sizeiptr (Next) * 16, Cmds (0)'Address);
            Named_Buffer_Sub_Data (Origin_Buf, 0, Sizeiptr (Next) * 16, Origins (0)'Address);
         end if;

         if Sun_Up then
            Begin_Casting;
            for I in Held'Range loop
               if Redraw (I) then
                  Bind_Framebuffer (Framebuffer, Held (I).FBO);
                  Viewport (0, 0, Shadow_Size, Shadow_Size);
                  Clear (Depth_Buffer_Bit);
                  Draw_Casters (Held (I).VP, (0.0, 0.0, 0.0), Land_At (I), Land_N (I), Figures => False);
               end if;
               Bind_Framebuffer (Framebuffer, Held (I).Fig_FBO);
               Viewport (0, 0, Figure_Size, Figure_Size);
               Clear (Depth_Buffer_Bit);
               Draw_Casters (Held (I).Fig_VP, (0.0, 0.0, 0.0), 0, 0, Figures => True);
            end loop;
            if Far_Cast >= 0 then
               Bind_Framebuffer (Framebuffer, Held (Far_Cast).Far_FBO);
               Viewport (0, 0, Far_Shadow_Size, Far_Shadow_Size);
               Clear (Depth_Buffer_Bit);
               Draw_Casters (Held (Far_Cast).Far_VP, (0.0, 0.0, 0.0), Far_Cast_At, Far_Cast_N, Figures => False);
               Far_Casts := Far_Casts + 1;
            end if;
            End_Casting;
         end if;

         --  The fire's six views, a right angle wide each, from the light.
         if Fire_On then
            declare
               type Face_View is record
                  Fwd, Up : Vec3;
               end record;
               Faces : constant array (Fire_FBO'Range) of Face_View :=
                 [((1.0, 0.0, 0.0), (0.0, -1.0, 0.0)), ((-1.0, 0.0, 0.0), (0.0, -1.0, 0.0)),
                  ((0.0, 1.0, 0.0), (0.0, 0.0, 1.0)),  ((0.0, -1.0, 0.0), (0.0, 0.0, -1.0)),
                  ((0.0, 0.0, 1.0), (0.0, -1.0, 0.0)), ((0.0, 0.0, -1.0), (0.0, -1.0, 0.0))];
               Lens  : constant Mat4 := Perspective (Ada.Numerics.Pi / 2.0, 1.0, Fire_Near_M, Fire_Far_M);
            begin
               Begin_Casting;
               for Face in Fire_FBO'Range loop
                  Bind_Framebuffer (Framebuffer, Fire_FBO (Face));
                  Viewport (0, 0, Fire_Size, Fire_Size);
                  Clear (Depth_Buffer_Bit);
                  Draw_Casters (Lens * Look_Dir (Faces (Face).Fwd, Faces (Face).Up), Fire_At,
                                Fire_Land_At, Fire_Land_N, Figures => True);
               end loop;
               End_Casting;
            end;
         end if;
         Put (U_Fire_Cast, (if Fire_On then 1.0 else 0.0));
         Put_Int ("u_light_cast", (if Fire_On then 0 else -1));
         Bind_Texture_Unit (13, Fire_Tex);

         if Nw > 0 then
            Bind_Framebuffer (Framebuffer, Snow_FBO);
            Viewport (0, 0, Snow_Size, Snow_Size);
            Depth_Mask (GL_True);
            Clear (Depth_Buffer_Bit);
            Enable (Depth_Test);
            Depth_Func (Less);
            Enable (Cull_Face_Cap);
            Cull_Face (Back);
            Front_Face (CCW);
            Use_Program (Shadow_Program);
            Bind_Vertex_Array (VAO);
            Bind_Buffer_Base (Shader_Storage_Buffer, 0, Quad_Buf);
            Bind_Buffer (Draw_Indirect_Buffer, Cmd_Buf);
            Program_Uniform_Matrix_4fv (Shadow_Program, Loc_S_VP, 1, GL_False, Snow_VP (0)'Address);
            Program_Uniform_3f (Shadow_Program, Loc_S_Camera, 0.0, 0.0, 0.0);
            Multi_Draw_Arrays_Indirect
              (Triangles, To_Address (Integer_Address (Snow_At * 16)), Sizei (Nw), 16);
            Snow_Drawn := S_Key;
         end if;
         if Snow_On then
            Put (U_Snow_VP, Snow_VP);
         else
            Put (U_Snow_VP, Mat4'(12 => 9.0, 15 => 1.0, others => 0.0));
            Snow_Drawn := (others => -1.0);
         end if;

         if Sun_Up then
            Put (U_Light_A, Held (From).VP);
            Put (U_Light_B, Held (1 - From).VP);
            Put (U_Fig_A, Held (From).Fig_VP);
            Put (U_Fig_B, Held (1 - From).Fig_VP);
            Put (U_Shadow_Texel, Texel);
            Put (U_Fig_Texel, 2.0 * Fig_Half / Float (Figure_Size));
            Put (U_Shadow_Mix, Shadow_Mix);
         else
            Put (U_Shadow_Texel, 0.0);       --  no lookups: full sun
         end if;
         Bind_Texture_Unit (2, Held (From).Tex);
         Bind_Texture_Unit (7, Held (1 - From).Tex);
         Bind_Texture_Unit (11, Held (From).Fig_Tex);
         Bind_Texture_Unit (12, Held (1 - From).Fig_Tex);
         --  (the far maps are read once both have been drawn)
         if Far_Sh_On and then Far_Sh_Ready
           and then (for all M of Held => M.Far_Dir /= Vec3'(0.0, 0.0, 0.0))
         then
            Put (U_FarL_A, Held (From).Far_VP);
            Put (U_FarL_B, Held (1 - From).Far_VP);
            Put (U_Far_Sh, Far_Shadow_Blend * Fog_Distance, Fog_Distance);
            Put (U_Far_Sh2, Far_Shadow_Bias_M / (2.0 * Far_Sh_Reach), 2.0 * Far_Sh_Half / Float (Far_Shadow_Size));
         else
            Put (U_Far_Sh, 0.0, 0.0);
         end if;
         Bind_Texture_Unit (22, Held (From).Far_Tex);
         Bind_Texture_Unit (23, Held (1 - From).Far_Tex);
      end;

      Put (U_Eye, Eye);
      --  (the haze's two legs: with no far land, all haze at the fog distance, as it was)
      if Far_View then
         Put (U_Far, 0.0, Float'Max (Far_Haze_M, Fog_Distance + 1.0));
      elsif Far_Land and then Far_Ready then
         Put (U_Far, Far_Haze, Float'Max (Far_Whole_M, Fog_Distance + 1.0));
      else
         Put (U_Far, 1.0, Fog_Distance + 1.0);
      end if;
      Bind_Texture_Unit (16, Base_Tex);
      Bind_Texture_Unit (24, Haze_Tex);
      Bind_Texture_Unit (1, Height_Tex);       --  (for every program that has the air)
      if Far_View and then Ground_Haze then
         declare
            use Ada.Numerics.Elementary_Functions;
            --  what stops that share of the light in Haze_Deep_M, a metre
            function Per_M (Share : Float) return Float is (-Log (1.0 - Share) / Float (Haze_Deep_M));
         begin
            Put (U_GHaze, Vec3'(Per_M (Haze_Near), Per_M (Haze_Edge), Per_M (Haze_Far)) * Haze_Amount);
         end;
      else
         Put (U_GHaze, Vec3'(0.0, 0.0, 0.0));
      end if;
      Put (U_Rim, (if Far_View and then Ground_Haze then Haze_Rim_M else 0.0));
      Put (U_Floor, (if Far_View and then Ground_Floor then 1.0 else 0.0));
      Put (U_Focus, Focus);            --  (for every program that has the air: the sky's too, for the floor)
      Put (U_Fog, Fog_Distance);

      --  The clouds walked through, into their picture: only when some sky
      --  above the horizon is in the view (from the usual tilt none is).
      declare
         Fwd   : constant Vec3 := Normalize (Focus - Eye);
         Right : constant Vec3 := Normalize (Cross (Fwd, (0.0, 0.0, 1.0)));
         Up    : constant Vec3 := Cross (Right, Fwd);
         Ty    : constant Float := Ada.Numerics.Elementary_Functions.Tan (Fov_Y / 2.0);
         Tx    : constant Float := Ty * Float (Width) / Float (Natural'Max (1, Height));
      begin
         Clouds_Drawn := False;
         if Volumetric and then Fwd.Z + Up.Z * Ty > 0.0 then
            Prepare_Clouds (Width, Height);
            if Cloud_Ready then
               Bind_Framebuffer (Framebuffer, Cloud_FBO);
               Viewport (0, 0, Sizei (Cloud_W), Sizei (Cloud_H));
               Color_Mask (GL_True, GL_True, GL_True, GL_True);
               Disable (Depth_Test);
               Disable (Blend);
               Disable (Cull_Face_Cap);
               Use_Program (Cloud_Program);
               Bind_Vertex_Array (Sky_VAO);
               Bind_Texture_Unit (3, Noise_Tex);
               Bind_Texture_Unit (14, Puff_Tex);
               Program_Uniform_3f (Cloud_Program, Loc_C_Fwd, Float32 (Fwd.X), Float32 (Fwd.Y), Float32 (Fwd.Z));
               Program_Uniform_3f (Cloud_Program, Loc_C_Right,
                                   Float32 (Right.X * Tx), Float32 (Right.Y * Tx), Float32 (Right.Z * Tx));
               Program_Uniform_3f (Cloud_Program, Loc_C_Up,
                                   Float32 (Up.X * Ty), Float32 (Up.Y * Ty), Float32 (Up.Z * Ty));
               Draw_Arrays (Triangles, 0, 3);
               Enable (Depth_Test);
               Enable (Cull_Face_Cap);
               Clouds_Drawn := True;
            end if;
         end if;
      end;

      Prepare_Target (Width, Height);
      Bind_Framebuffer (Framebuffer, (if MSAA > 0 then Target else 0));

      Viewport (0, 0, Sizei (Width), Sizei (Height));
      Clear_Color (Float32 (Day.Horizon.X), Float32 (Day.Horizon.Y), Float32 (Day.Horizon.Z), 1.0);
      Color_Mask (GL_True, GL_True, GL_True, GL_True);
      Depth_Mask (GL_True);
      Clear (Color_Buffer_Bit or Depth_Buffer_Bit);
      --  Alpha drives coverage and blending but is never written: the
      --  picture stays opaque (alpha 1 from the clear) all the way to the
      --  window, where a compositor could otherwise show the desktop through.
      Color_Mask (GL_True, GL_True, GL_True, GL_False);

      Use_World (Wetness and then Current.Wet > 0.0);
      if K > 0 then
         Enable (Depth_Test);
         Depth_Func (Less);
         Enable (Cull_Face_Cap);
         Cull_Face (Back);
         Front_Face (CCW);
         Use_Program (Program);
         Bind_Vertex_Array (VAO);
         Bind_Buffer_Base (Shader_Storage_Buffer, 0, Quad_Buf);
         Bind_Buffer (Draw_Indirect_Buffer, Cmd_Buf);
         Bind_Texture_Unit (0, Tex);
         Bind_Texture_Unit (1, Height_Tex);
         Bind_Texture_Unit (3, Noise_Tex);
         Bind_Texture_Unit (4, Snow_Tex);
         Bind_Texture_Unit (5, Lv_Tex);
         Bind_Texture_Unit (6, Flow_Tex);
         Program_Uniform_1f (Program, Loc_Blend, Float32 (Blend_Now));
         Program_Uniform_1i (Program, Loc_Wmask, int (Lv_Size - 1));
         Program_Uniform_1i (Program, Loc_Flowdbg, (if Flow_Debug then 1 else 0));
         Program_Uniform_1f (Program, Loc_Wstep, Float32 (Water_Steps));
         Program_Uniform_Matrix_4fv (Program, Loc_VP, 1, GL_False, VP (0)'Address);
         Program_Uniform_3f (Program, Loc_Camera, Float32 (Eye.X), Float32 (Eye.Y), Float32 (Eye.Z));
         Program_Uniform_3f (Program, Loc_Focus, Float32 (Focus.X), Float32 (Focus.Y), Float32 (Focus.Z));
         Program_Uniform_1f (Program, Loc_Fog_Dist, Float32 (Fog_Distance));
         declare
            Wet_Now : constant Boolean := Wetness and then Current.Wet > 0.0;
         begin
            Program_Uniform_3f (Program, Far_View_Loc (Wet_Now), (if Far_View then Float32 (Fog_Distance) else 0.0),
                                Float32 (Far_Fade),
                                Float32 (Fog_Distance * Ada.Numerics.Elementary_Functions."**" (2.0, -Float (Far_Fade))));
            Program_Uniform_3f (Program, Zp_Loc (Wet_Now), Float32 (2.0 * Near_M * Far_Plane),
                                Float32 (Far_Plane + Near_M), Float32 (Far_Plane - Near_M));
         end;
         if Far_Have_Dirty then
            Texture_Sub_Image_2D (Far_Have_Tex, 0, 0, 0, Far_Side, Far_Side, RGBA, Unsigned_Byte, Far_Have (0, 0)'Address);
            Far_Have_Dirty := False;
         end if;
         Bind_Texture_Unit (20, Far_Flag_Tex);
         Bind_Texture_Unit (21, Far_Have_Tex);

         Program_Uniform_1i (Program, Loc_Water, 0);
         Put_Roofs;
         Disable (Blend);
         if A2C then
            Enable (Sample_Alpha_To_Coverage);
         end if;
         if N_Solid > 0 then
            Multi_Draw_Arrays_Indirect (Triangles, Null_Address, Sizei (N_Solid), 16);
         end if;
         Disable (Sample_Alpha_To_Coverage);
      end if;

      Draw_Figures (Eye, Focus, VP, Fog_Distance);

      --  The far land (see the spec), wherever no stack's own mesh is drawn:
      --  after the land, which is in front of nearly all of it.
      if Far_Land and then Far_Ready then
         Enable (Depth_Test);
         Depth_Func (Less);
         Depth_Mask (GL_True);
         Enable (Cull_Face_Cap);
         Cull_Face (Back);
         Front_Face (CCW);
         Disable (Blend);
         Use_Program (Far_Program);
         Bind_Vertex_Array (Sky_VAO);
         Bind_Texture_Unit (1, Height_Tex);
         Bind_Texture_Unit (3, Noise_Tex);
         Bind_Texture_Unit (18, Far_Z_Tex);
         Bind_Texture_Unit (19, Far_Col_Tex);
         Bind_Texture_Unit (20, Far_Flag_Tex);
         Program_Uniform_Matrix_4fv (Far_Program, Far_Loc_VP, 1, GL_False, VP (0)'Address);
         Program_Uniform_3f (Far_Program, Far_Loc_Camera, Float32 (Eye.X), Float32 (Eye.Y), Float32 (Eye.Z));
         Program_Uniform_3f (Far_Program, Far_Loc_Focus, Float32 (Focus.X), Float32 (Focus.Y), Float32 (Focus.Z));
         Program_Uniform_1f (Far_Program, Far_Loc_Fog, Float32 (Fog_Distance));
         Draw_Arrays (Triangles, 0, Sizei (Castle.Far.Cells * Castle.Far.Cells * 6));
      end if;

      --  The picture so far (the land and the people; not the marks, which
      --  are the developer's, nor the sky, which the water works out for
      --  itself), for the water to mirror.
      if Reflections and then Scene_Ready and then MSAA > 0 and then K > N_Solid then
         Bind_Framebuffer (Read_Framebuffer, Target);
         Bind_Framebuffer (Draw_Framebuffer, Scene_FBO);
         Blit_Framebuffer (0, 0, int (Width), int (Height), 0, 0, int (Width), int (Height),
                           Color_Buffer_Bit or Depth_Buffer_Bit, Nearest_Filter);
         Bind_Framebuffer (Framebuffer, Target);
      end if;

      Draw_Marks (Eye, VP);

      --  The sky, in whatever the solid world left empty.
      declare
         Fwd   : constant Vec3 := Normalize (Focus - Eye);
         Right : constant Vec3 := Normalize (Cross (Fwd, (0.0, 0.0, 1.0)));
         Up    : constant Vec3 := Cross (Right, Fwd);
         Ty    : constant Float := Ada.Numerics.Elementary_Functions.Tan (Fov_Y / 2.0);
         Tx    : constant Float := Ty * Float (Width) / Float (Natural'Max (1, Height));
      begin
         Use_Program (Sky_Program);
         Bind_Vertex_Array (Sky_VAO);
         Bind_Texture_Unit (3, Noise_Tex);
         Bind_Texture_Unit (15, Cloud_Tex);
         Program_Uniform_1i (Sky_Program, Loc_Vol, (if Clouds_Drawn then 1 else 0));
         Program_Uniform_1i (Sky_Program, Loc_Drop, (if Low_Horizon then 1 else 0));
         Program_Uniform_2f (Sky_Program, Loc_Px, 1.0 / Float32 (Natural'Max (1, Width)),
                             1.0 / Float32 (Natural'Max (1, Height)));
         Program_Uniform_3f (Sky_Program, Loc_Fwd, Float32 (Fwd.X), Float32 (Fwd.Y), Float32 (Fwd.Z));
         Program_Uniform_3f (Sky_Program, Loc_Right,
                             Float32 (Right.X * Tx), Float32 (Right.Y * Tx), Float32 (Right.Z * Tx));
         Program_Uniform_3f (Sky_Program, Loc_Up,
                             Float32 (Up.X * Ty), Float32 (Up.Y * Ty), Float32 (Up.Z * Ty));
         Enable (Depth_Test);
         Depth_Func (Lequal);
         Depth_Mask (GL_False);
         Disable (Cull_Face_Cap);
         Draw_Arrays (Triangles, 0, 3);
         Depth_Mask (GL_True);
         Depth_Func (Less);
         Enable (Cull_Face_Cap);
      end;

      if K > 0 then
         Use_Program (Program);
         Bind_Vertex_Array (VAO);
         if K > N_Solid then
            Program_Uniform_1i (Program, Loc_Water, 1);
            Program_Uniform_1i (Program, Loc_Reflect,
                                (if not (Reflections and then Scene_Ready and then MSAA > 0) then 0
                                 elsif Far_View and then Far_Reflections then 2 else 1));
            Bind_Texture_Unit (9, Scene_Col);
            Bind_Texture_Unit (10, Scene_Z);
            Enable (Blend);
            Blend_Func (Src_Alpha, One_Minus_Src_Alpha);
            Depth_Mask (GL_False);
            Multi_Draw_Arrays_Indirect
              (Triangles, To_Address (Integer_Address (N_Solid * 16)), Sizei (K - N_Solid), 16);
            Depth_Mask (GL_True);
            Disable (Blend);
         end if;
      end if;

      --  Rain and snow falling, in a 32 m box just in front of the camera.
      for Kind in 0 .. 1 loop
         declare
            Amount : constant Float := (if Kind = 0 then Current.Rain else Current.Snowfall);
            Count  : constant Natural := Natural ((if Kind = 0 then 9_000.0 else 14_000.0) * Amount);
         begin
            if Count > 0 then
               declare
                  Fwd   : constant Vec3 := Normalize (Focus - Eye);
                  Right : constant Vec3 := Normalize (Cross (Fwd, (0.0, 0.0, 1.0)));
                  Up    : constant Vec3 := Cross (Right, Fwd);
                  Ctr   : constant Vec3 := Eye + Fwd * 14.0;
                  Fall  : constant Vec3 :=
                    (if Kind = 0 then (0.6 * Current.Wind_X, 0.6 * Current.Wind_Y, -9.0)
                     else (0.8 * Current.Wind_X, 0.8 * Current.Wind_Y, -1.1));
                  Lum   : constant Float :=
                    Float'Min (1.0, 1.6 * (0.3 * (Day.Sky_Amb.X + Day.Lamp_Col.X) + 0.59 * (Day.Sky_Amb.Y + Day.Lamp_Col.Y)
                                           + 0.11 * (Day.Sky_Amb.Z + Day.Lamp_Col.Z)));
                  Tint  : constant Vec3 := (if Kind = 1 then (0.97 * Lum, 0.98 * Lum, Lum)    --  flakes: daylight white
                                            else (0.78 * Lum, 0.82 * Lum, 0.88 * Lum));
                  PP    : constant UInt := Precip_Program;
               begin
                  Use_Program (PP);
                  Bind_Vertex_Array (Sky_VAO);
                  Bind_Texture_Unit (4, Snow_Tex);
                  Program_Uniform_Matrix_4fv (PP, Location ("u_viewproj", PP), 1, GL_False, VP (0)'Address);
                  Program_Uniform_3f (PP, Location ("u_camera", PP), Float32 (Eye.X), Float32 (Eye.Y), Float32 (Eye.Z));
                  Program_Uniform_3f (PP, Location ("u_centre", PP), Float32 (Ctr.X), Float32 (Ctr.Y), Float32 (Ctr.Z));
                  Program_Uniform_1f (PP, Location ("u_box", PP), 32.0);
                  Program_Uniform_3f (PP, Location ("u_fall", PP), Float32 (Fall.X), Float32 (Fall.Y), Float32 (Fall.Z));
                  Program_Uniform_1i (PP, Location ("u_kind", PP), int (Kind));
                  Program_Uniform_3f (PP, Location ("u_right", PP), Float32 (Right.X), Float32 (Right.Y), Float32 (Right.Z));
                  Program_Uniform_3f (PP, Location ("u_up", PP), Float32 (Up.X), Float32 (Up.Y), Float32 (Up.Z));
                  Program_Uniform_3f (PP, Location ("u_tint", PP), Float32 (Tint.X), Float32 (Tint.Y), Float32 (Tint.Z));
                  Enable (Depth_Test);
                  Depth_Func (Less);
                  Depth_Mask (GL_False);
                  Disable (Cull_Face_Cap);
                  Enable (Blend);
                  Blend_Func (Src_Alpha, One_Minus_Src_Alpha);
                  Draw_Arrays (Triangles, 0, Sizei (6 * Count));
                  Disable (Blend);
                  Depth_Mask (GL_True);
                  Enable (Cull_Face_Cap);
               end;
            end if;
         end;
      end loop;

      if Box_On then
         declare
            BP : constant UInt := Box_Program;
         begin
            Use_Program (BP);
            Bind_Vertex_Array (Sky_VAO);
            Program_Uniform_Matrix_4fv (BP, Location ("u_viewproj", BP), 1, GL_False, VP (0)'Address);
            Program_Uniform_3f (BP, Location ("u_camera", BP), Float32 (Eye.X), Float32 (Eye.Y), Float32 (Eye.Z));
            Program_Uniform_3f (BP, Location ("u_lo", BP),
                                Float32 (Box_Lo.X - 0.01), Float32 (Box_Lo.Y - 0.01), Float32 (Box_Lo.Z - 0.01));
            Program_Uniform_3f (BP, Location ("u_hi", BP),
                                Float32 (Box_Hi.X + 0.01), Float32 (Box_Hi.Y + 0.01), Float32 (Box_Hi.Z + 0.01));
            Enable (Depth_Test);
            Depth_Func (Lequal);
            Depth_Mask (GL_False);
            Draw_Arrays (Lines, 0, 24);
            Depth_Mask (GL_True);
            Depth_Func (Less);
         end;
      end if;

      Color_Mask (GL_True, GL_True, GL_True, GL_True);

      if MSAA > 0 then
         --  Resolve into the window.  The window must be the *bound* draw
         --  framebuffer: Mesa attaches the swap chain's current back buffer
         --  only to bound window framebuffers (st_manager_validate_framebuffers),
         --  so a named blit into framebuffer 0 lands in a stale buffer, which
         --  shows as a black window on Wayland.
         Bind_Framebuffer (Draw_Framebuffer, 0);
         Bind_Framebuffer (Read_Framebuffer, Target);
         Blit_Framebuffer (0, 0, int (Width), int (Height), 0, 0, int (Width), int (Height),
                           Color_Buffer_Bit, Nearest_Filter);
         Bind_Framebuffer (Framebuffer, 0);
      end if;

      End_Query (Time_Elapsed);
      Issued := Issued + 1;
   end Draw;

   procedure Screenshot (Path : String; Width, Height : Natural) is
      type Bytes is array (Natural range <>) of aliased Unsigned_8;
      type Bytes_Access is access Bytes;
      procedure Free_B is new Ada.Unchecked_Deallocation (Bytes, Bytes_Access);
      Buf : Bytes_Access := new Bytes (0 .. Width * Height * 3 - 1);
      Img : Castle.PNG.Image_Access := new Castle.PNG.Image (0 .. Height - 1, 0 .. Width - 1);
   begin
      Finish;
      Pixel_Store_I (Pack_Alignment, 1);
      Read_Pixels (0, 0, Sizei (Width), Sizei (Height), RGB, Unsigned_Byte, Buf (0)'Address);
      for Row in 0 .. Height - 1 loop
         for Col in 0 .. Width - 1 loop
            declare
               I : constant Natural := (Row * Width + Col) * 3;
            begin
               Img (Height - 1 - Row, Col) := (Buf (I), Buf (I + 1), Buf (I + 2));
            end;
         end loop;
      end loop;
      Castle.PNG.Write (Path, Img.all);
      Castle.PNG.Free (Img);
      Free_B (Buf);
   end Screenshot;

   function Stacks_Resident return Natural is (Loaded_N);
   function Stacks_Skipped return Natural is (Skipped);
   function Quads_Resident return Natural is (Quads_Total);
   function Draws_Last_Frame return Natural is (Draws);
   function Capacity_Left return Natural is (Free_Quads);
   function GPU_Millis return Float is (Last_GPU_Ms);

   procedure Set_Outline (Lo, Hi : Vec3; Visible : Boolean) is
   begin
      Box_Lo := Lo;
      Box_Hi := Hi;
      Box_On := Visible;
   end Set_Outline;
   function MSAA_Samples return Natural is (MSAA);

end Castle.Render;
