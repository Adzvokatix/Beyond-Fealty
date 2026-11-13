with Interfaces; use Interfaces;

package body Castle.Noise is

   use Castle.Hash;

   type Vec2 is record
      X, Y : Float;
   end record;

   type Vec3 is record
      X, Y, Z : Float;
   end record;

   Grad_2 : constant array (U64 range 0 .. 15) of Vec2 :=
     ((1.0, 0.0), (0.923_88, 0.382_68), (0.707_11, 0.707_11), (0.382_68, 0.923_88),
      (0.0, 1.0), (-0.382_68, 0.923_88), (-0.707_11, 0.707_11), (-0.923_88, 0.382_68),
      (-1.0, 0.0), (-0.923_88, -0.382_68), (-0.707_11, -0.707_11), (-0.382_68, -0.923_88),
      (0.0, -1.0), (0.382_68, -0.923_88), (0.707_11, -0.707_11), (0.923_88, -0.382_68));

   --  Perlin's improved-noise edge set (12 directions, padded to 16).
   Grad_3 : constant array (U64 range 0 .. 15) of Vec3 :=
     ((1.0, 1.0, 0.0), (-1.0, 1.0, 0.0), (1.0, -1.0, 0.0), (-1.0, -1.0, 0.0),
      (1.0, 0.0, 1.0), (-1.0, 0.0, 1.0), (1.0, 0.0, -1.0), (-1.0, 0.0, -1.0),
      (0.0, 1.0, 1.0), (0.0, -1.0, 1.0), (0.0, 1.0, -1.0), (0.0, -1.0, -1.0),
      (1.0, 1.0, 0.0), (-1.0, 1.0, 0.0), (0.0, -1.0, 1.0), (0.0, -1.0, -1.0));

   function Fade (T : Float) return Float with Inline;

   function Fade (T : Float) return Float is
   begin
      return T * T * T * (T * (T * 6.0 - 15.0) + 10.0);
   end Fade;

   function Floor_I (X : Float) return Integer is
   begin
      return Integer (Float'Floor (X));
   end Floor_I;

   function Clamp (X, Lo, Hi : Float) return Float is
   begin
      return Float'Max (Lo, Float'Min (Hi, X));
   end Clamp;

   function Lerp (A, B, T : Float) return Float is
   begin
      return A + (B - A) * T;
   end Lerp;

   function Smoothstep (E0, E1, X : Float) return Float is
      T : constant Float := Clamp ((X - E0) / (E1 - E0), 0.0, 1.0);
   begin
      return T * T * (3.0 - 2.0 * T);
   end Smoothstep;

   function Perlin_2 (Seed : U64; X, Y : Float) return Float is
      Xf : constant Float   := Float'Floor (X);
      Yf : constant Float   := Float'Floor (Y);
      Xi : constant Integer := Integer (Xf);
      Yi : constant Integer := Integer (Yf);
      Fx : constant Float   := X - Xf;
      Fy : constant Float   := Y - Yf;

      function Corner (Ix, Iy : Integer; Dx, Dy : Float) return Float is
         G : constant Vec2 := Grad_2 (Hash_2 (Seed, Ix, Iy) and 15);
      begin
         return G.X * Dx + G.Y * Dy;
      end Corner;

      N00 : constant Float := Corner (Xi,     Yi,     Fx,       Fy);
      N10 : constant Float := Corner (Xi + 1, Yi,     Fx - 1.0, Fy);
      N01 : constant Float := Corner (Xi,     Yi + 1, Fx,       Fy - 1.0);
      N11 : constant Float := Corner (Xi + 1, Yi + 1, Fx - 1.0, Fy - 1.0);
      U   : constant Float := Fade (Fx);
      V   : constant Float := Fade (Fy);
   begin
      return 1.414 * Lerp (Lerp (N00, N10, U), Lerp (N01, N11, U), V);
   end Perlin_2;

   function Perlin_3 (Seed : U64; X, Y, Z : Float) return Float is
      Xf : constant Float   := Float'Floor (X);
      Yf : constant Float   := Float'Floor (Y);
      Zf : constant Float   := Float'Floor (Z);
      Xi : constant Integer := Integer (Xf);
      Yi : constant Integer := Integer (Yf);
      Zi : constant Integer := Integer (Zf);
      Fx : constant Float   := X - Xf;
      Fy : constant Float   := Y - Yf;
      Fz : constant Float   := Z - Zf;

      function Corner (Ix, Iy, Iz : Integer; Dx, Dy, Dz : Float) return Float is
         G : constant Vec3 := Grad_3 (Hash_3 (Seed, Ix, Iy, Iz) and 15);
      begin
         return G.X * Dx + G.Y * Dy + G.Z * Dz;
      end Corner;

      U : constant Float := Fade (Fx);
      V : constant Float := Fade (Fy);
      T : constant Float := Fade (Fz);
      A : constant Float :=
        Lerp (Lerp (Corner (Xi, Yi, Zi, Fx, Fy, Fz),
                    Corner (Xi + 1, Yi, Zi, Fx - 1.0, Fy, Fz), U),
              Lerp (Corner (Xi, Yi + 1, Zi, Fx, Fy - 1.0, Fz),
                    Corner (Xi + 1, Yi + 1, Zi, Fx - 1.0, Fy - 1.0, Fz), U), V);
      B : constant Float :=
        Lerp (Lerp (Corner (Xi, Yi, Zi + 1, Fx, Fy, Fz - 1.0),
                    Corner (Xi + 1, Yi, Zi + 1, Fx - 1.0, Fy, Fz - 1.0), U),
              Lerp (Corner (Xi, Yi + 1, Zi + 1, Fx, Fy - 1.0, Fz - 1.0),
                    Corner (Xi + 1, Yi + 1, Zi + 1, Fx - 1.0, Fy - 1.0, Fz - 1.0), U), V);
   begin
      return Lerp (A, B, T);
   end Perlin_3;

   --  Each octave is rotated by ~36.87 degrees (a 3-4-5 triangle) and
   --  offset, which hides lattice alignment between octaves.
   Rc : constant := 0.8;
   Rs : constant := 0.6;

   function FBM_2 (Seed : U64; X, Y : Float; Octaves : Positive) return Float is
      Sum  : Float := 0.0;
      Amp  : Float := 1.0;
      Norm : Float := 0.0;
      Px   : Float := X;
      Py   : Float := Y;
      T    : Float;
   begin
      for O in 1 .. Octaves loop
         Sum  := Sum + Amp * Perlin_2 (Seed + U64 (O) * 16#9E37_79B9#, Px, Py);
         Norm := Norm + Amp;
         Amp  := Amp * 0.5;
         T    := (Rc * Px - Rs * Py) * 2.0 + 17.31;
         Py   := (Rs * Px + Rc * Py) * 2.0 + 3.97;
         Px   := T;
      end loop;
      return Sum / Norm;
   end FBM_2;

   function Ridged_2 (Seed : U64; X, Y : Float; Octaves : Positive) return Float is
      Sum    : Float := 0.0;
      Amp    : Float := 0.5;
      Norm   : Float := 0.0;
      Weight : Float := 1.0;
      Px     : Float := X;
      Py     : Float := Y;
      S, T   : Float;
   begin
      for O in 1 .. Octaves loop
         S      := 1.0 - abs Perlin_2 (Seed + U64 (O) * 16#632B_E5AB#, Px, Py);
         S      := S * S * Weight;
         Weight := Clamp (S * 2.0, 0.0, 1.0);
         Sum    := Sum + S * Amp;
         Norm   := Norm + Amp;
         Amp    := Amp * 0.5;
         T      := (Rc * Px - Rs * Py) * 2.0 + 41.7;
         Py     := (Rs * Px + Rc * Py) * 2.0 + 9.13;
         Px     := T;
      end loop;
      return Sum / Norm;
   end Ridged_2;

end Castle.Noise;
