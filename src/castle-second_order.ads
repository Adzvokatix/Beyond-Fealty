--  Second-order dynamics: Y follows an input X the way a mass dragged by a
--  spring and a damper would, after t3ssel8r's "Giving Personality to
--  Procedural Animations using Math".  Three numbers give it a character:
--
--    F     natural frequency (Hz): how quickly it answers.
--    Zeta  damping: 0 rings for ever, below 1 overshoots and settles,
--          1 arrives as fast as it can without overshooting, above 1 eases in.
--    R     initial response: 0 eases into a move, 1 answers at once,
--          above 1 overshoots at the start, below 0 winds up the wrong way
--          first (anticipation).
--
--  Transfer function (r w z s + w^2) / (s^2 + 2 z w s + w^2), w = 2 pi F.
--  Each step is the equation's exact solution over the frame (an exp, a
--  sin and a cos, then a handful of multiplies), so it is stable at any
--  frame time and moves the same at 24 frames a second as at 144.
--
--  Presentation only: animation runs once a frame with whatever T the frame
--  took, so none of this may feed back into the simulation.
generic
   type Vec is private;
   Zero : Vec;
   with function "+" (A, B : Vec) return Vec is <>;
   with function "-" (A, B : Vec) return Vec is <>;
   with function "*" (V : Vec; S : Float) return Vec is <>;
package Castle.Second_Order is

   type Params is record
      F    : Float := 2.0;
      Zeta : Float := 1.0;
      R    : Float := 0.0;
   end record;

   type Filter is private;

   function Make (P : Params; X0 : Vec) return Filter;
   --  At rest at X0.

   procedure Tune (S : in out Filter; P : Params);
   --  A new character; where it is and how fast it moves are kept.

   procedure Snap (S : in out Filter; X : Vec);
   --  Jump to X, at rest (a figure coming back into view).

   procedure Update (S : in out Filter; T : Float; X : Vec);
   --  T seconds have passed and the input is now X; its rate is taken from
   --  the last X.  T <= 0 changes nothing.

   procedure Update (S : in out Filter; T : Float; X, Xd : Vec);
   --  The same with the input's rate given.

   function Value (S : Filter) return Vec;
   function Rate (S : Filter) return Vec;
   function Input (S : Filter) return Vec;   --  the last X

private

   type Filter is record
      W, Z, D    : Float := 0.0;   --  2 pi F, Zeta, damped frequency w sqrt |z^2 - 1|
      K1, K2, K3 : Float := 0.0;
      Xp, Y, Yd  : Vec   := Zero;
   end record;

end Castle.Second_Order;
