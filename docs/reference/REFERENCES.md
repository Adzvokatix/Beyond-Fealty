# References

The papers and the reference video are kept outside git, in `CASTLE_GAME/papers/`. The notes are here.

| Title | Author | File | Used for |
|---|---|---|---|
| Real-Time Fluid Dynamics for Games (GDC 2003) | Jos Stam | StamFluidforGames.pdf | Live water |
| Real Time Large Scale Fluids for Games | Daniel Kallin | ecp083410.pdf | Live water |
| Water Flow in Portal 2 (SIGGRAPH 2010, Advanced Real-Time Rendering course) | Alex Vlachos, Valve | Vlachos-Waterflow(SIGGRAPH 2010 Advanced RealTime Rendering Course).pdf | Flow maps for drawing moving water |
| Making and Using Non-Standard Textures (GDC 2011) | Bronwen Grimes, Valve | gdc_2011_grimes_nonstandard_textures.pdf | Textures |
| Modular Procedural Generation for Voxel Maps (arXiv 2104.08890) | Adarsh Pyarelal, Aditya Banerjee, Kobus Barnard | roomvoxelgeneration.pdf | Buildings and rooms |
| Pathfinding in Open Terrain (Future Play 2006) | S. D. Goodwin, S. Menon, R. G. Price | 2006-SG-SM-RP-Futureplay.pdf | Routes |
| Voxel water tech demo (video) | not recorded | m2-res_464p.mp4 | Live water: the behaviour to match |

The video, in John's words (2026-11-09): a 3 x 3 m pond with a source node in the middle that fills the
grid to one level. The player breaks a cliff face and opens a channel to the pond. The water next to
the channel drops, and the source hurries to raise it back; water rushes out of the channel and down
the cliff in a jetting waterfall, with splashes and a flow mesh that gives the look of running water
(the same thing our Valve flow-map drawing is for). It hits the ground and spreads outward in a
circle, and goes on until the player puts blocks back in the gap. Then the flow stops, what is out
soaks into the ground and evaporates, and the nine pond blocks go back to sleep once the water is
back at the source's level.

## Notes in this folder

- `kkrieger_notes.md`: what .kkrieger / werkkzeug3 does that matters here (rigid segments on a
  procedural stepper with two-bone IK, operator-graph textures, assets stored as their history). The
  basis of `Castle.Serfs`, `Castle.Poses` and the texture generator; read it before work on creatures,
  crowds on roads (the separation force) or texture operators.
