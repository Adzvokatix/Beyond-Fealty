with Castle.Hash;

--  Gradient noise and fractal combinations.  Only +, -, *, /, floor and abs
--  are used, so results are bit-identical on every IEEE-754 machine as long
--  as the compiler never contracts a*b+c into FMA (castle.gpr passes
--  -ffp-contract=off for exactly this reason).
package Castle.Noise with Pure is



   function Floor_I (X : Float) return Integer with Inline;

   function Perlin_2 (Seed : Castle.Hash.U64; X, Y : Float) return Float;
   --  Approximately in [-1, 1]; zero on integer lattice points.

   function Perlin_3 (Seed : Castle.Hash.U64; X, Y, Z : Float) return Float;

   function FBM_2 (Seed : Castle.Hash.U64; X, Y : Float; Octaves : Positive) return Float;
   --  Fractal sum (lacunarity 2, gain 0.5), normalised.  Typically |v| < 0.6.

   function Ridged_2 (Seed : Castle.Hash.U64; X, Y : Float; Octaves : Positive) return Float;
   --  Ridged multifractal in [0, 1], crests at 1.

   function Clamp (X, Lo, Hi : Float) return Float with Inline;
   function Lerp (A, B, T : Float) return Float with Inline;
   function Smoothstep (E0, E1, X : Float) return Float with Inline;

end Castle.Noise;
