with Interfaces;

--  Counter-based hashing.  Every random decision in world generation is a
--  hash of (channel seed, integer coordinates): no RNG state, no ordering
--  dependence, safe from any number of threads.
package Castle.Hash with Pure is

   subtype U64 is Interfaces.Unsigned_64;

   function Mix (X : U64) return U64 with Inline;
   --  SplitMix64 finaliser: a bijection on 64-bit words with full avalanche.

   function Derive (Seed, Channel : U64) return U64 with Inline;
   --  Independent sub-seed for one generator channel.

   function Hash_2 (Seed : U64; X, Y : Integer) return U64 with Inline;
   function Hash_3 (Seed : U64; X, Y, Z : Integer) return U64 with Inline;

   function Unit (H : U64) return Float with Inline;
   --  Uniform in [0.0, 1.0) from the top 24 bits of H.

   function Unit_2 (Seed : U64; X, Y : Integer) return Float with Inline;
   function Unit_3 (Seed : U64; X, Y, Z : Integer) return Float with Inline;

end Castle.Hash;
