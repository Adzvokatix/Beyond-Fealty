with Ada.Numerics;
with Ada.Numerics.Long_Elementary_Functions; use Ada.Numerics.Long_Elementary_Functions;

package body Castle.Second_Order is

   Pi : constant := Ada.Numerics.Pi;

   procedure Tune (S : in out Filter; P : Params) is
      F : constant Float := Float'Max (1.0E-3, P.F);
      Z : constant Float := Float'Max (0.0, P.Zeta);
   begin
      S.W  := 2.0 * Pi * F;
      S.Z  := Z;
      S.D  := S.W * Float (Sqrt (Long_Float (abs (Z * Z - 1.0))));
      S.K1 := Z / (Pi * F);
      S.K2 := 1.0 / (S.W * S.W);
      S.K3 := P.R * Z / S.W;
   end Tune;

   function Make (P : Params; X0 : Vec) return Filter is
      S : Filter;
   begin
      Tune (S, P);
      S.Xp := X0;
      S.Y  := X0;
      S.Yd := Zero;
      return S;
   end Make;

   procedure Snap (S : in out Filter; X : Vec) is
   begin
      S.Xp := X;
      S.Y  := X;
      S.Yd := Zero;
   end Snap;

   --  The step is the equation's exact solution over T, with the input
   --  taken to move in a straight line from the last X to this one (as it
   --  did: the simulation moved it during the frame).  With x (t) = Xp + v t
   --  the particular solution is x (t) + P, P = K3 Xd - K1 v, and the rest,
   --  e = y - x - P, rings down freely: e'' + 2 z w e' + w^2 e = 0, so
   --    e (T)  = a e0 + b e0'      a = E (C + s S/D),  b = E S/D
   --    e' (T) = c e0 + d e0'      c = -E w^2 S/D,     d = E (C - s S/D)
   --  with s = z w, E = exp (-s T), and C, S the cos and sin of D T (cosh and
   --  sinh when z > 1; T and 1 when D T is tiny).  Exact at any frame time:
   --  stable, and the same motion at 24 frames a second as at 144.
   --  (The writeup's scheme, implicit Euler while w T < z and pole matching
   --  above, drifts just under w T = z (a 2 Hz, zeta 0.5 step at 30 fps
   --  overshoots 20 % instead of 16 %) and overshoots badly near w T = pi;
   --  dynamics_check prints both on the same tests.)
   procedure Update (S : in out Filter; T : Float; X, Xd : Vec) is
      Tc : constant Float := Float'Min (T, 1.0);   --  a frame longer than a second counts as one
   begin
      if Tc <= 0.0 then
         return;
      end if;
      declare
         W   : constant Long_Float := Long_Float (S.W);
         Sg  : constant Long_Float := Long_Float (S.Z) * W;        --  decay rate s
         D   : constant Long_Float := Long_Float (S.D);
         Tl  : constant Long_Float := Long_Float (Tc);
         Dt  : constant Long_Float := D * Tl;
         E_C, E_S_D : Long_Float;                                  --  E C and E S / D
      begin
         if Dt < 1.0E-6 then
            E_C   := Exp (-Sg * Tl);
            E_S_D := Exp (-Sg * Tl) * Tl;
         elsif S.Z < 1.0 then
            E_C   := Exp (-Sg * Tl) * Cos (Dt);
            E_S_D := Exp (-Sg * Tl) * Sin (Dt) / D;
         else
            --  E cosh and E sinh as differences of decaying exponentials, so
            --  nothing overflows however long the frame
            E_C   := 0.5 * (Exp (-(Sg - D) * Tl) + Exp (-(Sg + D) * Tl));
            E_S_D := 0.5 * (Exp (-(Sg - D) * Tl) - Exp (-(Sg + D) * Tl)) / D;
         end if;
         declare
            A  : constant Float := Float (E_C + Sg * E_S_D);
            B  : constant Float := Float (E_S_D);
            C  : constant Float := Float (-W * W * E_S_D);
            Dd : constant Float := Float (E_C - Sg * E_S_D);
            V  : constant Vec   := (X - S.Xp) * (1.0 / Tc);       --  the input's straight line
            P  : constant Vec   := Xd * S.K3 - V * S.K1;
            E0 : constant Vec   := S.Y - (S.Xp + P);
            E1 : constant Vec   := S.Yd - V;
         begin
            S.Y  := X + P + (E0 * A + E1 * B);
            S.Yd := V + (E0 * C + E1 * Dd);
         end;
      end;
      S.Xp := X;
   end Update;

   procedure Update (S : in out Filter; T : Float; X : Vec) is
   begin
      if T > 0.0 then
         Update (S, T, X, (X - S.Xp) * (1.0 / Float'Min (T, 1.0)));
      end if;
   end Update;

   function Value (S : Filter) return Vec is (S.Y);
   function Rate (S : Filter) return Vec is (S.Yd);
   function Input (S : Filter) return Vec is (S.Xp);

end Castle.Second_Order;
