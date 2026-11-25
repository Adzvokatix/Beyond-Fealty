#!/usr/bin/env python3
# The two corners to give colony_run's --stockyard (or the game's stockyard tool) for a lot laid out
# along a path at 45 degrees (2026-11-20): opposite corners of the lot, a hair inside each, on the
# whole metres along and across the path's way that Castle.Colony lays such a lot on.
#   tools/yard_corners.py X0 Y0 X1 Y1 SIDE FROM LEN DEPTH [HALF]
# The path runs X0 Y0 -> X1 Y1.  SIDE: +1 toward the greater, -1 toward the less, of the lot's
# measure across the path (as Way_Of_Path turns it: within 45 degrees of east).  FROM: whole metres
# along from the path's lower end.  LEN by DEPTH metres (15 to 25 each).  HALF: half the path's
# width (0.5).  Prints "--stockyard X0 Y0 X1 Y1".
import sys, math
x0, y0, x1, y1 = map(float, sys.argv[1:5])
side = int(sys.argv[5]); a_from = float(sys.argv[6]); L = float(sys.argv[7]); D = float(sys.argv[8])
half = float(sys.argv[9]) if len(sys.argv) > 9 else 0.5
dx, dy = x1 - x0, y1 - y0
l = math.hypot(dx, dy); dx /= l; dy /= l
for _ in range(3):                      # quarter turns until it points within 45 degrees of east
    if dx > 0 and abs(dy) <= dx + 1e-6:
        break
    dx, dy = dy, -dx
ex, ey = dx, dy
a = lambda x, y: x * ex + y * ey
b = lambda x, y: y * ex - x * ey
w = lambda A, B: (A * ex - B * ey, A * ey + B * ex)
if abs(b(x1, y1) - b(x0, y0)) < 0.01:   # the path runs along a
    edge = b(x0, y0) + side * half
    front = math.ceil(edge - 1e-6) if side > 0 else math.floor(edge + 1e-6)
    A0 = math.ceil(min(a(x0, y0), a(x1, y1))) + a_from
    c = [(A0 + 0.3, front + side * 0.3), (A0 + L - 0.3, front + side * (D - 0.3))]
else:                                   # along b
    edge = a(x0, y0) + side * half
    front = math.ceil(edge - 1e-6) if side > 0 else math.floor(edge + 1e-6)
    B0 = math.ceil(min(b(x0, y0), b(x1, y1))) + a_from
    c = [(front + side * 0.3, B0 + 0.3), (front + side * (D - 0.3), B0 + L - 0.3)]
p = [w(*q) for q in c]
print("--stockyard %.2f %.2f %.2f %.2f" % (p[0][0], p[0][1], p[1][0], p[1][1]))
