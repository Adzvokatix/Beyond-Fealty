with Castle.Hash;
with Castle.Maps;

package Castle.Worldgen is

   Generator_Version : constant := 14;   --  2: 256 m world, taller mountains; 3: cliffs, veins, water;
                                        --  4: blocky broadleaf crowns; 5: contained water, lakes feed
                                        --  the streams that start near them; 6: channels carry a
                                        --  discharge, beds fall all the way, fewer lakes;
                                        --  7: rougher, deeper, slower channels;
                                        --  8: no curtain columns at falls;
                                        --  9: no Aquifer blocks (aquifers are a field; the material
                                        --  is gone, block codes renumbered: Bare_Bush)
                                        --  10: thick forests in patches, lone apples in the open,
                                        --  aspens, pines and spruces, half the berry bushes; new
                                        --  bark and leaf blocks (codes renumbered)
                                        --  11: wild vegetables in patches (a new plant block,
                                        --  codes renumbered)
                                        --  12: tarns (a small deep hollow holds a lake instead
                                        --  of silting up to its brim)
                                        --  13: trees reshaped (crowns of lumpy domes on boughs,
                                        --  spruces of drooping whorls; where a tree stands, its
                                        --  kind and its trunk are as they were); tall grass in
                                        --  drifts, some of it two blocks high
                                        --  14: a fifth of the mountains' boulders, and three in ten
                                        --  more on open land (Castle.Flora.Boulders_Mountain, _Open)
   --  Bump whenever any stage changes its output for the same seed.  Saves
   --  store only modified chunks and regenerate the rest, so a save must be
   --  loaded with the generator version that created it.

   procedure Create (Seed : Castle.Hash.U64; W : out Castle.Maps.World; Report : Boolean := True);
   --  Stages: terrain -> geology fields -> hydrology -> deposits (all
   --  surface-visible, gold and silver deep in seam tails) -> aquifer field.

end Castle.Worldgen;
