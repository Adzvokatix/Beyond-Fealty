--  Deer without a window: every class and coat builds and fits its skin;
--  standing, every leg reaches its hoof; the legs' IK lands on targets in
--  reach; and the stepper (Castle.Animals) on flat ground: hooves planted
--  never slide, a walk keeps three hooves down and goes left hind, left
--  fore, right hind, right fore, a trot lifts the diagonal pairs together, a
--  bound has all four hooves off the ground between strides, the gait
--  follows the speed, and the stride is the same at 30 and 120 frames a
--  second.
--  ./bin/debug/deer_check   (exits 1 on any failure)

with Ada.Text_IO;      use Ada.Text_IO;
with Ada.Command_Line;
with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Castle.Bodies;    use Castle.Bodies;
with Castle.Poses;     use Castle.Poses;
with Castle.Math;      use Castle.Math;
with Castle.Deer;      use Castle.Deer;
with Castle.Animals;   use Castle.Animals;
with Castle.Text;      use Castle.Text;

procedure Deer_Check is

   Fails : Natural := 0;

   procedure Check (Ok : Boolean; What : String) is
   begin
      Put_Line ((if Ok then "  ok    " else "  FAIL  ") & What);
      if not Ok then
         Fails := Fails + 1;
      end if;
   end Check;

   function Dist (A, B : Vec3) return Float is (Sqrt (Dot (A - B, A - B)));

   Ground_Z : constant := 10.0;   --  nothing is loaded: the ground is wherever the target is

   type Run_Result is record
      Slid        : Boolean := False;   --  a planted hoof moved
      Three_Down  : Float := 0.0;       --  share of samples with three or more hooves down
      None_Down   : Float := 0.0;       --  share with no hoof down
      Each_Down   : Float := 0.0;       --  share of the time a hoof is down, on average
      Order_Ok    : Boolean := True;    --  walk: the lifts came in the walk's order
      Pairs_Ok    : Boolean := True;    --  trot: diagonal hooves lifted together
      Gait        : Castle.Animals.Gait := Stand;
      Stride      : Float := 0.0;       --  metres between one left hind lift and the next
      Lag         : Float := 0.0;       --  the body behind its target at the end
      Reached     : Float := 0.0;       --  share of frames every leg reached its hoof
      Pitch       : Float := 0.0;       --  the body's steepest, hips to withers (rad)
      Hip_Low     : Float := 99.0;      --  the lowest the hips came, over the ground
   end record;

   --  A deer driven along +X at Speed for Seconds, Dt a frame.
   function Run (Speed, Seconds, Dt : Float; Check_Order, Check_Pairs : Boolean) return Run_Result is
      R      : Run_Result;
      Start  : constant Vec3 := (100.0, 100.0, Ground_Z);
      I      : constant Positive := Spawn (Doe, Start, 0.0, 7, False);
      Before : array (Leg) of Vec3;
      Was    : array (Leg) of Boolean;
      Steps  : constant Natural := Natural (Seconds / Dt);
      Sampled, Three, None, Hoof_Down, Reached_N : Natural := 0;
      --  the order hooves lift in, walking: each lift should follow the
      --  previous one in Hind_L, Fore_L, Hind_R, Fore_R
      Next_Of : constant array (Leg) of Leg := [Hind_L => Fore_L, Fore_L => Hind_R, Hind_R => Fore_R, Fore_R => Hind_L];
      Last_Lift : Leg := Fore_R;
      Have_Last : Boolean := False;
      Lift_Time : array (Leg) of Float := [others => -1.0];
      LH_Lifts  : Natural := 0;
      LH_First, LH_Last : Float := 0.0;
      T : Float := 0.0;
   begin
      for L in Leg loop
         Before (L) := Hoof_At (I, L);
         Was (L) := Planted (I, L);
      end loop;
      for K in 1 .. Steps loop
         T := T + Dt;
         Drive (I, Start + (Speed * T, 0.0, 0.0), Idle);
         Update (Dt);
         if T > 1.5 then                 --  once it is up to speed
            Sampled := Sampled + 1;
            Submit;                      --  solves the legs
            declare
               P : constant Castle.Deer.Pose := Pose_Of (I);
            begin
               R.Pitch := Float'Max (R.Pitch, abs (Arctan (P.Shoulders.Z - P.Hips.Z,
                                                           Dist ((P.Shoulders.X, P.Shoulders.Y, 0.0), (P.Hips.X, P.Hips.Y, 0.0)))));
               R.Hip_Low := Float'Min (R.Hip_Low, P.Hips.Z - Ground_Z);
            end;
            if Castle.Animals.Reached (I) then
               Reached_N := Reached_N + 1;
            end if;
            declare
               Down : Natural := 0;
            begin
               for L in Leg loop
                  if Planted (I, L) then
                     Down := Down + 1;
                     Hoof_Down := Hoof_Down + 1;
                  end if;
               end loop;
               if Down >= 3 then
                  Three := Three + 1;
               end if;
               if Down = 0 then
                  None := None + 1;
               end if;
            end;
         end if;
         for L in Leg loop
            if Was (L) and then Planted (I, L) and then Dist (Before (L), Hoof_At (I, L)) > 1.0E-4 then
               R.Slid := True;
            end if;
            if Was (L) and then not Planted (I, L) and then T > 1.5 then   --  a lift
               Lift_Time (L) := T;
               if Check_Order then
                  if Have_Last and then L /= Next_Of (Last_Lift) then
                     R.Order_Ok := False;
                  end if;
                  Last_Lift := L;
                  Have_Last := True;
               end if;
               if L = Hind_L then
                  if LH_Lifts = 0 then
                     LH_First := Where (I).X;
                  end if;
                  LH_Last := Where (I).X;
                  LH_Lifts := LH_Lifts + 1;
               end if;
            end if;
            Before (L) := Hoof_At (I, L);
            Was (L) := Planted (I, L);
         end loop;
         if Check_Pairs then
            --  a diagonal pair lifts within a few frames of each other
            for P in 1 .. 2 loop
               declare
                  A : constant Leg := (if P = 1 then Hind_L else Hind_R);
                  B : constant Leg := (if P = 1 then Fore_R else Fore_L);
               begin
                  if Lift_Time (A) > 0.0 and then Lift_Time (B) > 0.0 and then T - Float'Max (Lift_Time (A), Lift_Time (B)) < Dt
                    and then abs (Lift_Time (A) - Lift_Time (B)) > 0.08
                    and then abs (Lift_Time (A) - Lift_Time (B)) < 0.2
                  then
                     R.Pairs_Ok := False;
                  end if;
               end;
            end loop;
         end if;
      end loop;
      R.Three_Down := Float (Three) / Float (Natural'Max (1, Sampled));
      R.None_Down := Float (None) / Float (Natural'Max (1, Sampled));
      R.Each_Down := Float (Hoof_Down) / Float (4 * Natural'Max (1, Sampled));
      R.Reached := Float (Reached_N) / Float (Natural'Max (1, Sampled));
      R.Gait := Gait_Of (I);
      R.Stride := (if LH_Lifts > 1 then (LH_Last - LH_First) / Float (LH_Lifts - 1) else 0.0);
      R.Lag := Dist ((Where (I).X, Where (I).Y, 0.0), (Start.X + Speed * T, Start.Y, 0.0));
      Clear;
      return R;
   end Run;

begin
   ------------------------------------------------------------------ 1. bodies
   Put_Line ("every class and coat:");
   declare
      All_Fit : Boolean := True;
      Boxes   : Natural := 0;
   begin
      for C in Class loop
         for W in Boolean loop
            declare
               R    : Rig;
               Skin : Skin_Pixels;
            begin
               Build (C, W, R, Skin);
               Boxes := Natural'Max (Boxes, R.Count);
               for K in 1 .. R.Count loop
                  All_Fit := All_Fit and then R.Boxes (K).U + 2 * (R.Boxes (K).W + R.Boxes (K).D) <= Skin_W
                    and then R.Boxes (K).V + R.Boxes (K).D + R.Boxes (K).H <= Skin_H;
               end loop;
            exception
               when Program_Error =>
                  All_Fit := False;
            end;
         end loop;
      end loop;
      Check (All_Fit and then Boxes <= Max_Boxes,
             "they build, and every box's net is inside the skin (up to" & Boxes'Image & " boxes)");
   end;
   for C in Class loop
      declare
         D : constant Dims := Dims_Of (C);
      begin
         Put_Line ("    " & C'Image & ": hips " & Img (D.Hip_H, 2) & " m, withers " & Img (D.Shoulder_H, 2)
                   & " m, " & Img (D.Spine, 2) & " m from hips to withers");
      end;
   end loop;

   ------------------------------------------------------------------ 2. standing, and the IK
   Put_Line ("standing, and reaching:");
   declare
      Stands, Lands, Square : Boolean := True;
      Worst : Float := 0.0;
   begin
      for C in Class loop
         declare
            D : constant Dims := Dims_Of (C);
            P : Castle.Deer.Pose;
            F : Frames;
            Ok_L : Leg_Flags;
            Ok : Boolean;
         begin
            P.Hips := (0.0, 0.0, D.Hip_H);
            P.Shoulders := (0.0, D.Spine, D.Shoulder_H);
            for L in Leg loop
               P.Hoof (L) := ((if Is_Left (L) then -D.Half_W else D.Half_W), (if Is_Fore (L) then D.Spine else 0.0), D.Hoof);
            end loop;
            Solve (D, P, F, Ok_L);
            Ok := Ok_L = [Fore_L .. Hind_R => True];
            Stands := Stands and then Ok;
            for B in Bone loop
               Square := Square and then abs (Dot (F (B).X, F (B).Y)) < 1.0E-4 and then abs (Dot (F (B).Y, F (B).Z)) < 1.0E-4
                 and then abs (Dot (F (B).X, F (B).Z)) < 1.0E-4 and then abs (Dot (F (B).X, F (B).X) - 1.0) < 1.0E-4;
            end loop;
            --  hooves moved about within reach, the body lowered so the legs bend
            P.Hips.Z := 0.88 * D.Hip_H;
            P.Shoulders.Z := 0.88 * D.Shoulder_H;
            for K in 1 .. 250 loop
               declare
                  A  : constant Float := Float (K) * 0.7;
                  Pt : Castle.Deer.Pose := P;
               begin
                  for L in Leg loop
                     Pt.Hoof (L) := P.Hoof (L) + (0.12 * Cos (A + Float (Leg'Pos (L))), 0.25 * Sin (1.3 * A), 0.1 * Sin (0.7 * A))
                                                 * (0.6 * D.Size);
                  end loop;
                  Solve (D, Pt, F, Ok_L);
                  if Ok_L = [Fore_L .. Hind_R => True] then
                     for L in Leg loop
                        Worst := Float'Max (Worst, Dist (F (Bone_Of (L, 3)).O, Pt.Hoof (L)));
                     end loop;
                  else
                     Lands := False;
                  end if;
               end;
            end loop;
         end;
      end loop;
      Check (Stands, "standing, every leg reaches its hoof, every class");
      Check (Square, "every bone's frame is square");
      Check (Lands and then Worst < 0.001, "hooves moved about within reach are reached exactly (off by at most "
             & Img (Worst * 1000.0, 2) & " mm)");
   end;

   ------------------------------------------------------------------ 3. gaits
   Put_Line ("a doe walking, trotting and bounding on flat ground:");
   declare
      Walk30 : constant Run_Result := Run (1.2, 12.0, 1.0 / 30.0, True, False);
      Walk120 : constant Run_Result := Run (1.2, 12.0, 1.0 / 120.0, False, False);
      Trot  : constant Run_Result := Run (2.6, 10.0, 1.0 / 60.0, False, True);
      Bound : constant Run_Result := Run (6.5, 8.0, 1.0 / 60.0, False, False);
      Still : constant Run_Result := Run (0.0, 4.0, 1.0 / 60.0, False, False);
   begin
      Put_Line ("    walk: three or more hooves down " & Img (Walk30.Three_Down * 100.0, 0) & " % of the time, stride "
                & Img (Walk30.Stride, 2) & " m (" & Img (Walk120.Stride, 2) & " m at 120 fps)");
      Put_Line ("    trot: each hoof down " & Img (Trot.Each_Down * 100.0, 0) & " % of the time");
      Put_Line ("    bound: no hoof down " & Img (Bound.None_Down * 100.0, 0) & " % of the time, each hoof "
                & Img (Bound.Each_Down * 100.0, 0) & " %, stride " & Img (Bound.Stride, 2) & " m");
      Check (Walk30.Gait = Walk and then Trot.Gait = Castle.Animals.Trot and then Bound.Gait = Castle.Animals.Bound
             and then Still.Gait = Stand,
             "the gait follows the speed: stand, walk at 1.2 m/s, trot at 2.6, bound at 6.5");
      Check (not Walk30.Slid and then not Walk120.Slid and then not Trot.Slid and then not Bound.Slid,
             "a planted hoof never slides, in any gait or frame rate");
      Check (Walk30.Three_Down > 0.85, "walking, three hooves are down most of the time");
      Check (Walk30.Order_Ok, "walking, the hooves lift left hind, left fore, right hind, right fore");
      Check (Trot.Pairs_Ok, "trotting, the diagonal pairs lift together");
      Check (Bound.None_Down > 0.05, "bounding, all four hooves are off the ground between strides");
      Check (Walk30.Stride > 0.5 and then abs (Walk30.Stride - Walk120.Stride) < 0.05 * Walk30.Stride,
             "the stride is the same at 30 and 120 frames a second");
      Put_Line ("    the legs reach their hooves " & Img (Walk30.Reached * 100.0, 0) & " % of frames walking, "
                & Img (Trot.Reached * 100.0, 0) & " % trotting, " & Img (Bound.Reached * 100.0, 0) & " % bounding");
      Check (Walk30.Reached > 0.98 and then Trot.Reached > 0.98 and then Bound.Reached > 0.95,
             "moving, the legs reach their planted hooves: none drawn hanging off the ground");
      Put_Line ("    the body pitches at most " & Img (Walk30.Pitch * 57.3, 1) & " deg walking, "
                & Img (Trot.Pitch * 57.3, 1) & " trotting, " & Img (Bound.Pitch * 57.3, 1) & " bounding; hips down to "
                & Img (Bound.Hip_Low, 2) & " m");
      Check (Walk30.Pitch < 0.15 and then Trot.Pitch < 0.2 and then Bound.Pitch < 0.27,
             "the back stays level enough: no rearing or diving");
      Check (Walk30.Lag < 1.0 and then Bound.Lag < 2.5, "the body keeps up with where it is meant to be ("
             & Img (Walk30.Lag, 2) & " m behind walking, " & Img (Bound.Lag, 2) & " m bounding)");
   end;

   New_Line;
   if Fails = 0 then
      Put_Line ("all checks passed");
   else
      Put_Line (Fails'Image & " checks FAILED");
      Ada.Command_Line.Set_Exit_Status (1);
   end if;
end Deer_Check;
