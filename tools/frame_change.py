#!/usr/bin/env python3
"""How much a recording of a still view changes from one frame to the next.

    tools/frame_change.py DIR [HEAT.png] [-v]

DIR holds frame_NNNN.png as --record writes them.  Only the last 60 are read
(the camera eases in over the first hundred or so).  Prints the mean change
of a pixel between consecutive frames (levels of 255, the largest of its
three channels), the frame that changed most, and the share of pixels that
step by more than 6, 20 and 50 levels in any one frame.  HEAT.png gets each
pixel's largest step, times four: where the picture flickers.  -v prints
every frame's mean.  Needs numpy and Pillow.
"""
import glob
import sys

import numpy as np
from PIL import Image

args = [a for a in sys.argv[1:] if a != "-v"]
files = sorted(glob.glob(args[0] + "/frame_*.png"))[-60:]
if len(files) < 2:
    sys.exit("no frames in " + args[0])
prev = None
worst = None
means = []
for f in files:
    a = np.asarray(Image.open(f).convert("RGB"), dtype=np.int16)
    if prev is not None:
        step = np.abs(a - prev).max(axis=2)
        means.append(step.mean())
        worst = step if worst is None else np.maximum(worst, step)
    prev = a
if "-v" in sys.argv:
    print(" ".join(f"{m:.2f}" for m in means))
print(f"{len(files)} frames: mean step {np.mean(means):.4f}, worst frame {np.max(means):.4f}, "
      f"pixels stepping >6: {100.0 * (worst > 6).mean():.2f} %, >20: {100.0 * (worst > 20).mean():.2f} %, "
      f">50: {100.0 * (worst > 50).mean():.2f} %")
if len(args) > 1:
    Image.fromarray(np.clip(worst * 4, 0, 255).astype(np.uint8)).save(args[1])
