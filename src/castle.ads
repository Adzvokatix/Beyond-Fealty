--  Castle Game engine - root package.
--
--  Conventions used everywhere in the engine:
--    * Axes: X east, Y north, Z up (right-handed).
--    * 1 block = 0.25 m.  Names ending in _B are blocks, _M are metres.
--    * Fields are 1 m x 1 m cells over the 2048 m x 2048 m map.
--    * World generation is a pure function of (seed, coordinates): any chunk
--      can be generated on any thread, in any order, with identical results.
package Castle with Pure is
end Castle;
