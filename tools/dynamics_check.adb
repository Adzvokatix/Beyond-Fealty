--  The second-order dynamics without a window: the step responses match
--  the theory, it stays stable at any frame time, and the motion is the
--  same at 30, 60 and 144 frames a second.
--  ./bin/debug/dynamics_check  (exits 1 on any failure)

with Ada.Text_IO;      use Ada.Text_IO;
with Ada.Command_Line;
with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Castle.Second_Order_1;
with Castle.Second_Order_3;
with Castle.Text;      use Castle.Text;

procedure Dynamics_Check is
   package S1 renames Castle.Second_Order_1;
   package S3 renames Castle.Second_Order_3;

   Failed : Natural := 0;

   procedure Check (Ok : Boolean; What : String) is
   begin
      Put_Line ((if Ok then "  ok    " else "  FAIL  ") & What);
      if not Ok then
         Failed := Failed + 1;
      end if;
   end Check;

   --  A step from 0 to 1 at time 0, stepped at Fps for Seconds.
   type Response is record
      Peak, Low   : Float := 0.0;   --  highest and lowest Y seen
      At_25, At_50, At_100 : Float := 0.0;   --  Y at 0.25, 0.5 and 1 s
      Last        : Float := 0.0;
   end record;

   function Step (P : S1.Params; Fps : Float; Seconds : Float := 3.0) return Response is
      F  : S1.Filter := S1.Make (P, 0.0);
      T  : constant Float := 1.0 / Fps;
      R  : Response;
      N  : constant Natural := Natural (Seconds * Fps);
      Y  : Float;
      Tm : Float;
   begin
      R.Low := 0.0;
      for I in 1 .. N loop
         S1.Update (F, T, 1.0);
         Y := S1.Value (F);
         Tm := Float (I) * T;
         R.Peak := Float'Max (R.Peak, Y);
         R.Low  := Float'Min (R.Low, Y);
         if abs (Tm - 0.25) < T / 2.0 then R.At_25 := Y; end if;
         if abs (Tm - 0.5) < T / 2.0 then R.At_50 := Y; end if;
         if abs (Tm - 1.0) < T / 2.0 then R.At_100 := Y; end if;
      end loop;
      R.Last := S1.Value (F);
      return R;
   end Step;

begin
   Put_Line ("step responses (1000 steps a second):");
   declare
      Z     : constant Float := 0.5;
      R     : constant Response := Step ((F => 2.0, Zeta => Z, R => 0.0), 1000.0);
      Over  : constant Float := Exp (-Ada.Numerics.Pi * Z / Sqrt (1.0 - Z * Z));
   begin
      Check (abs ((R.Peak - 1.0) - Over) < 0.01,
             "zeta 0.5 overshoots by " & Img ((R.Peak - 1.0) * 100.0, 1) & " % (theory "
             & Img (Over * 100.0, 1) & " %)");
      Check (abs (R.Last - 1.0) < 0.001, "and settles on the target");
   end;
   declare
      R : constant Response := Step ((F => 2.0, Zeta => 1.0, R => 0.0), 1000.0);
   begin
      Check (R.Peak <= 1.0 + 1.0E-4, "zeta 1 never overshoots: peak " & Img (R.Peak, 4));
      Check (R.At_50 > 0.98, "and is 98 % there in half a second (2 Hz): " & Img (R.At_50, 3));
   end;
   declare
      R : constant Response := Step ((F => 2.0, Zeta => 0.5, R => -1.0), 1000.0);
   begin
      Check (R.Low < -0.02, "r -1 winds up the wrong way first: dips to " & Img (R.Low, 3));
   end;
   declare
      F : S1.Filter := S1.Make ((F => 2.0, Zeta => 1.0, R => 1.0), 0.0);
   begin
      S1.Update (F, 0.001, 1.0);
      Check (S1.Rate (F) > 5.0, "r 1 answers at once: rate after one step " & Img (S1.Rate (F), 1) & " /s");
   end;
   declare
      F : S1.Filter := S1.Make ((F => 1.0, Zeta => 0.0, R => 0.0), 0.0);
      Low, High : Float := 0.0;
   begin
      for I in 1 .. 10_000 loop
         S1.Update (F, 0.001, 1.0);
         if I > 5_000 then
            Low := Float'Min (Low, S1.Value (F));
            High := Float'Max (High, S1.Value (F));
         end if;
      end loop;
      Check (High > 1.9 and then Low < 0.1, "zeta 0 rings for ever: 0 .. 2 after 5 s ("
             & Img (Low, 2) & " .. " & Img (High, 2) & ")");
   end;

   Put_Line ("stability (10 Hz, zeta 0.3: stiff and lively):");
   declare
      type Steps is array (1 .. 6) of Float;
      Frame : constant Steps := (0.004, 0.016, 0.05, 0.1, 0.25, 0.5);
      Worst : Float := 0.0;
      Naive_Blew : Boolean := False;
   begin
      for T of Frame loop
         declare
            F : S1.Filter := S1.Make ((F => 10.0, Zeta => 0.3, R => 0.0), 0.0);
            Big : Float := 0.0;
         begin
            for I in 1 .. Natural (20.0 / T) loop
               S1.Update (F, T, (if (I / Natural'Max (1, Natural (0.7 / T))) mod 2 = 0 then 1.0 else -1.0));
               Big := Float'Max (Big, abs S1.Value (F));
            end loop;
            Worst := Float'Max (Worst, Big);
         end;
         --  The same filter stepped the plain (semi-implicit) way, as a
         --  check that these frame times would really break it.
         declare
            W  : constant Float := 2.0 * Ada.Numerics.Pi * 10.0;
            K1 : constant Float := 0.3 / (Ada.Numerics.Pi * 10.0);
            K2 : constant Float := 1.0 / (W * W);
            Y, Yd : Float := 0.0;
         begin
            for I in 1 .. 200 loop
               Y := Y + T * Yd;
               Yd := Yd + T * (1.0 - Y - K1 * Yd) / K2;
               exit when abs Y > 1.0E6;
            end loop;
            if abs Y > 1.0E6 then
               Naive_Blew := True;
            end if;
         end;
      end loop;
      Check (Worst < 1.85, "square wave, frames of 4 ms to 0.5 s: never past " & Img (Worst, 2)
             & " (the input swings -1 .. 1; the continuous response peaks at 1.74)");
      Check (Naive_Blew, "where the plain semi-implicit step diverges");
   end;

   Put_Line ("frame-rate independence (2 Hz, zeta 0.5, r 0.5):");
   --  A target that keeps moving (two sines), so the comparison measures
   --  the filter, not when a jump happened to fall inside a frame.
   declare
      function Target (Tm : Float) return Float is
        (Sin (2.0 * Ada.Numerics.Pi * 1.3 * Tm) + 0.4 * Sin (2.0 * Ada.Numerics.Pi * 3.1 * Tm + 1.0));
      P : constant S1.Params := (F => 2.0, Zeta => 0.5, R => 0.5);
      type Samples is array (1 .. 12) of Float;
      function Run (Fps : Float) return Samples is
         F   : S1.Filter := S1.Make (P, Target (0.0));
         T   : constant Float := 1.0 / Fps;
         Out_S : Samples := (others => 0.0);
         Next : Positive := 1;
         Tm  : Float := 0.0;
      begin
         while Next <= Samples'Last loop
            Tm := Tm + T;
            S1.Update (F, T, Target (Tm));
            --  sample every half second: a whole number of frames at every
            --  rate tested, so no sample falls between frames
            while Next <= Samples'Last and then Float (Next) * 0.5 <= Tm + T * 0.25 loop
               Out_S (Next) := S1.Value (F);
               Next := Next + 1;
            end loop;
         end loop;
         return Out_S;
      end Run;
      Ref : constant Samples := Run (4000.0);
      type Rates is array (1 .. 5) of Float;
      Fps : constant Rates := (20.0, 24.0, 30.0, 60.0, 144.0);
   begin
      for I in Fps'Range loop
         declare
            R : constant Samples := Run (Fps (I));
            E : Float := 0.0;
         begin
            for K in R'Range loop
               E := Float'Max (E, abs (R (K) - Ref (K)));
            end loop;
            Check (E < 0.04, Img (Fps (I), 0) & " fps follows the 4000 fps curve within " & Img (E, 3)
                   & " (the target swings 2.8; most of what is left is the target itself being"
                   & " known only once a frame)");
         end;
      end loop;
      declare
         A : constant Response := Step ((F => 2.0, Zeta => 0.5, R => 0.0), 30.0);
         B : constant Response := Step ((F => 2.0, Zeta => 0.5, R => 0.0), 1000.0);
      begin
         Check (abs (A.Peak - B.Peak) < 0.01, "a step overshoots the same at 30 fps ("
                & Img ((A.Peak - 1.0) * 100.0, 1) & " %) as at 1000 (" & Img ((B.Peak - 1.0) * 100.0, 1) & " %)");
      end;
   end;

   --  For the record: the scheme the writeup settles on (implicit Euler
   --  while w T < zeta, pole-matched semi-implicit Euler above), run on the
   --  same tests.  Not checked, only shown: it is why Castle.Second_Order
   --  solves each frame exactly instead.
   Put_Line ("the writeup's scheme on the same tests (shown, not checked):");
   declare
      Pi : constant := Ada.Numerics.Pi;
      procedure Writeup_Step (Fz, Z : Float; T : Float; X, Xd : Float; Y, Yd : in out Float) is
         W  : constant Float := 2.0 * Pi * Fz;
         K1 : constant Float := Z / (Pi * Fz);
         K2 : constant Float := 1.0 / (W * W);
      begin
         if W * T < Z then
            Y  := Y + T * Yd;
            Yd := (K2 * Yd + T * (X - Y)) / (K2 + T * K1);
         else
            declare
               D     : constant Float := W * Sqrt (abs (Z * Z - 1.0));
               T1    : constant Float := Exp (-Z * W * T);
               Alpha : constant Float := 2.0 * T1 * (if Z <= 1.0 then Cos (T * D) else Cosh (T * D));
               Beta  : constant Float := T1 * T1;
               T2    : constant Float := T / (1.0 + Beta - Alpha);
            begin
               Y  := Y + T * Yd;
               Yd := Yd + T * (X - Y - (1.0 - Beta) * T2 * Yd) / (T * T2);
            end;
         end if;
         pragma Unreferenced (Xd);
      end Writeup_Step;
      function Peak (Fz, Z, T : Float; Square : Boolean) return Float is
         Y, Yd : Float := (if Square then -1.0 else 0.0);
         P : Float := 0.0;
         Hold : constant Natural := Natural'Max (1, Natural (0.7 / T));
      begin
         Yd := 0.0;
         for I in 1 .. Natural (6.0 / T) loop
            Writeup_Step (Fz, Z, T, (if not Square or else (I / Hold) mod 2 = 0 then 1.0 else -1.0), 0.0, Y, Yd);
            P := Float'Max (P, abs Y);
         end loop;
         return P;
      end Peak;
   begin
      Put_Line ("        2 Hz zeta 0.5 step peak: " & Img (Peak (2.0, 0.5, 0.001, False), 3) & " at 1000 fps, "
                & Img (Peak (2.0, 0.5, 1.0 / 30.0, False), 3) & " at 30 (w T just under zeta: implicit Euler; continuous 1.163)");
      Put_Line ("        10 Hz zeta 0.3 square wave peak at 20 fps (w T = pi, pole matching): "
                & Img (Peak (10.0, 0.3, 0.05, True), 2) & " (continuous: 1.74)");
   end;

   Put_Line ("state:");
   declare
      F : S1.Filter := S1.Make ((F => 1.0, Zeta => 0.7, R => 0.0), 0.0);
      Y, Yd : Float;
   begin
      for I in 1 .. 100 loop
         S1.Update (F, 0.01, 1.0);
      end loop;
      Y := S1.Value (F);
      Yd := S1.Rate (F);
      S1.Tune (F, (F => 4.0, Zeta => 0.2, R => 2.0));
      Check (S1.Value (F) = Y and then S1.Rate (F) = Yd, "retuning keeps where it is and how fast it moves");
      S1.Snap (F, 5.0);
      Check (S1.Value (F) = 5.0 and then S1.Rate (F) = 0.0, "a snap lands at rest");
   end;
   declare
      F : S3.Filter := S3.Make ((F => 2.0, Zeta => 1.0, R => 0.0), (0.0, 0.0, 0.0));
   begin
      for I in 1 .. 2000 loop
         S3.Update (F, 0.001, (3.0, -4.0, 12.0));
      end loop;
      Check (abs (S3.Value (F).X - 3.0) + abs (S3.Value (F).Y + 4.0) + abs (S3.Value (F).Z - 12.0) < 0.01,
             "on points: each axis follows the same way");
   end;

   if Failed = 0 then
      Put_Line ("all checks passed");
   else
      Put_Line (Img (Failed) & " checks FAILED");
      Ada.Command_Line.Set_Exit_Status (1);
   end if;
end Dynamics_Check;
