--  Serfs without a window: thousands of generated people fit their skins,
--  build the same every time, are mirror images left and right (but for
--  what is meant not to be), stand on their feet at the height they were
--  given, and the two-bone IK lands where it is asked to.
--  ./bin/debug/serf_check [--png FILE]   (FILE: a sheet of skins to look at)

with Ada.Text_IO;      use Ada.Text_IO;
with Ada.Command_Line; use Ada.Command_Line;
with Interfaces;       use Interfaces;
with Castle.Bodies;    use Castle.Bodies;
with Castle.Poses;     use Castle.Poses;
with Castle.Serfs;
with Castle.Nav;
with Castle.Water;
with Castle.Blocks;
with Castle.Dims;
with Castle.Math;      use Castle.Math;
with Castle.Hash;      use Castle.Hash;
with Castle.PNG;
with Castle.Text;      use Castle.Text;
with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;

procedure Serf_Check is
   Failed : Natural := 0;

   procedure Check (Ok : Boolean; What : String) is
   begin
      Put_Line ((if Ok then "  ok    " else "  FAIL  ") & What);
      if not Ok then
         Failed := Failed + 1;
      end if;
   end Check;

   type Skin_Access is access Skin_Pixels;
   Skin_A : constant Skin_Access := new Skin_Pixels;
   Skin_B : constant Skin_Access := new Skin_Pixels;

begin
   Put_Line ("generation:");
   declare
      Built, Most_Boxes, Overlaps, Outside, Rows_Used : Natural := 0;
      Lefties, Men, Women : Natural := 0;
      Men_H, Women_H : Float := 0.0;
      R : Rig;
   begin
      for I in 1 .. 3000 loop
         declare
            G : constant Genome := Random_Genome (Derive (7, U64 (I)), Child => I mod 10 = 0, Elder => I mod 10 = 1);
         begin
            for J in Job_Kind loop
               for W in Boolean loop
                  Build (G, (J, W, False), R, Skin_A.all);
                  Built := Built + 1;
                  Most_Boxes := Natural'Max (Most_Boxes, R.Count);
                  for K in 1 .. R.Count loop
                     declare
                        A : constant Box := R.Boxes (K);
                     begin
                        if A.U + 2 * (A.W + A.D) > Skin_W or else A.V + A.D + A.H > Skin_H then
                           Outside := Outside + 1;
                        end if;
                        Rows_Used := Natural'Max (Rows_Used, A.V + A.D + A.H);
                        for L in K + 1 .. R.Count loop
                           declare
                              B2 : constant Box := R.Boxes (L);
                           begin
                              if A.U < B2.U + 2 * (B2.W + B2.D) and then B2.U < A.U + 2 * (A.W + A.D)
                                and then A.V < B2.V + B2.D + B2.H and then B2.V < A.V + A.D + A.H
                              then
                                 Overlaps := Overlaps + 1;
                              end if;
                           end;
                        end loop;
                     end;
                  end loop;
               end loop;
            end loop;
            if I mod 10 > 1 then
               if G.Hand = Left then
                  Lefties := Lefties + 1;
               end if;
               if G.Sex = Male then
                  Men := Men + 1;
                  Men_H := Men_H + G.Height;
               else
                  Women := Women + 1;
                  Women_H := Women_H + G.Height;
               end if;
            end if;
         end;
      end loop;
      Check (Outside = 0 and then Overlaps = 0,
             Img (Built) & " serfs built (3000 people x 6 jobs x summer and winter): every net inside the skin,"
             & " none overlapping; at most" & Most_Boxes'Image & " boxes of" & Max_Boxes'Image
             & ", at most" & Rows_Used'Image & " of the skin's" & Skin_H'Image & " rows");
      Check (abs (Float (Lefties) / Float (Men + Women) - 0.1) < 0.025,
             "left-handed: " & Img (100.0 * Float (Lefties) / Float (Men + Women), 1) & " % (one in ten)");
      Check (abs (Men_H / Float (Men) - 1.72) < 0.02 and then abs (Women_H / Float (Women) - 1.61) < 0.02,
             "adult heights: men " & Img (Men_H / Float (Men), 2) & " m, women " & Img (Women_H / Float (Women), 2) & " m");
   end;

   declare
      G  : constant Genome := Random_Genome (12345);
      R1, R2 : Rig;
   begin
      Build (G, (Forester, True, False), R1, Skin_A.all);
      Build (G, (Forester, True, False), R2, Skin_B.all);
      Check (R1 = R2 and then Skin_A.all = Skin_B.all, "the same genome builds the same serf, pixel for pixel");
   end;

   Put_Line ("symmetry:");
   declare
      Mirrors, Off : Natural := 0;
      Rolled_Seen : Natural := 0;
   begin
      for I in 1 .. 200 loop
         declare
            G : constant Genome := Random_Genome (Derive (11, U64 (I)));
            R : Rig;
         begin
            Build (G, (Idle, False, False), R, Skin_A.all);
            for K in 1 .. R.Count loop
               declare
                  A : constant Box := R.Boxes (K);
               begin
                  if A.On in Upper_Arm_L .. Hand_L | Thigh_L .. Foot_L then
                     for L in 1 .. R.Count loop
                        declare
                           B2 : constant Box := R.Boxes (L);
                        begin
                           if B2.On = Mirror (A.On) and then B2.Size = A.Size
                             and then abs (B2.Lo.X + A.Lo.X + A.Size.X) < 1.0E-5
                             and then B2.Lo.Y = A.Lo.Y and then B2.Lo.Z = A.Lo.Z
                           then
                              --  compare the skins face by face, one mirrored
                              declare
                                 Same : Boolean := True;
                                 Ua, Va, Wa, Ha, Ub, Vb, Wb, Hb : Natural;
                              begin
                                 for F in Face loop
                                    Face_Rect (A, F, Ua, Va, Wa, Ha);
                                    Face_Rect (B2, (case F is when Pos_X => Neg_X, when Neg_X => Pos_X, when others => F),
                                               Ub, Vb, Wb, Hb);
                                    for T in 0 .. Ha - 1 loop
                                       for S in 0 .. Wa - 1 loop
                                          if Skin_A (Va + T, Ua + S) /= Skin_A (Vb + T, Ub + Wb - 1 - S) then
                                             Same := False;
                                          end if;
                                       end loop;
                                    end loop;
                                 end loop;
                                 if Same then
                                    Mirrors := Mirrors + 1;
                                 elsif A.On = Forearm_L then
                                    Rolled_Seen := Rolled_Seen + 1;
                                 else
                                    Off := Off + 1;
                                 end if;
                              end;
                           end if;
                        end;
                     end loop;
                  end if;
               end;
            end loop;
         end;
      end loop;
      Check (Off = 0 and then Mirrors > 1000,
             Img (Mirrors) & " limb pairs are mirror images, box and skin; the only exceptions are"
             & Rolled_Seen'Image & " forearms with one sleeve pushed up (on purpose)");
      Check (Rolled_Seen > 10, "and those do happen");
   end;

   Put_Line ("standing:");
   declare
      Worst_H, Worst_Sole : Float := 0.0;
      Hands_Ok : Boolean := True;
   begin
      for I in 1 .. 500 loop
         declare
            G : constant Genome := Random_Genome (Derive (13, U64 (I)), Child => I mod 7 = 0);
            R : Rig;
            F : Frames;
            Top, Sole : Float := 0.0;
         begin
            Build (G, (Idle, False, False), R, Skin_A.all);
            Solve (R, Standing (R, (100.0, 200.0, 30.0), 0.7), F);
            Sole := 1.0E9;
            for K in 1 .. R.Count loop
               declare
                  A : constant Box := R.Boxes (K);
               begin
                  if A.On = Head and then A.Lo = (-3.0, -3.0, 0.0) then
                     Top := Place (F (Head), (0.0, 0.0, A.Lo.Z + A.Size.Z)).Z;
                  end if;
                  if A.On in Foot_L | Foot_R then
                     Sole := Float'Min (Sole, Place (F (A.On), (0.0, 0.0, A.Lo.Z)).Z);
                  end if;
               end;
            end loop;
            Worst_H := Float'Max (Worst_H, abs ((Top - 30.0) - G.Height));
            Worst_Sole := Float'Max (Worst_Sole, abs (Sole - 30.0));
            if F (Hand_L).O.Z - 30.0 < R.Hip * 0.6 or else F (Hand_L).O.Z > F (Pelvis).O.Z + 0.2 then
               Hands_Ok := False;
            end if;
         end;
      end loop;
      Check (Worst_H <= 0.0251, "500 serfs stand as tall as their genomes say, within "
             & Img (Worst_H * 100.0, 1) & " cm (half a 5 cm pixel)");
      Check (Worst_Sole < 0.001, "with their soles on the ground (within " & Img (Worst_Sole * 1000.0, 1) & " mm)");
      Check (Hands_Ok, "and their hands hanging between the knee and the hip");
   end;

   Put_Line ("two-bone IK:");
   declare
      Mid, Tip : Vec3;
      Ok : Boolean;
      Worst : Float := 0.0;
      Bent_Right_Way : Boolean := True;
   begin
      for I in 1 .. 1000 loop
         declare
            T : constant Vec3 :=
              (Unit (Hash_2 (5, I, 1)) - 0.5, Unit (Hash_2 (5, I, 2)) - 0.5, -0.2 - 0.6 * Unit (Hash_2 (5, I, 3)));
            Pole : constant Vec3 := (0.0, 1.0, 0.0);
            D : Vec3;
         begin
            Two_Bone ((0.0, 0.0, 0.0), T, Pole, 0.4, 0.38, Mid, Tip, Ok);
            if Ok then
               D := Tip - T;
               Worst := Float'Max (Worst, Sqrt (Dot (D, D)));
               --  the middle joint sits toward the pole, off the root-tip line
               declare
                  J : constant Vec3 := Normalize (T);
                  Side_Off : constant Vec3 := Mid - J * Dot (Mid, J);
               begin
                  if Dot (Side_Off, Pole - J * Dot (Pole, J)) < -1.0E-4 then
                     Bent_Right_Way := False;
                  end if;
               end;
               D := Mid;
               if abs (Sqrt (Dot (D, D)) - 0.4) > 1.0E-3 or else abs (Sqrt (Dot (Tip - Mid, Tip - Mid)) - 0.38) > 1.0E-3 then
                  Bent_Right_Way := False;
               end if;
            end if;
         end;
      end loop;
      Check (Worst < 1.0E-4, "1000 reachable targets reached within " & Img (Worst * 1.0E6, 1) & " micrometres");
      Check (Bent_Right_Way, "with the bones their own lengths and the joint bent toward the pole");
      Two_Bone ((0.0, 0.0, 0.0), (0.0, 0.0, -2.0), (0.0, 1.0, 0.0), 0.4, 0.38, Mid, Tip, Ok);
      Check (not Ok and then abs (Tip.Z + 0.78) < 1.0E-3, "out of reach: straight toward it, " & Img (Tip.Z, 3));
   end;

   --  Walking on flat ground (nothing is loaded, so the ground is flat at
   --  the height given): six seconds at 30 frames a second, measured after
   --  the first two.
   Put_Line ("walking:");
   declare
      type Run_Result is record
         Max_Ahead, Max_Behind, Hip_Lo, Hip_Hi, Speed, Stride : Float := 0.0;
         Both_Up, Slides, Arm_Ok, Arm_N : Natural := 0;
      end record;

      function Run (Index : Positive; Fps : Float) return Run_Result is
         Res  : Run_Result;
         Dt   : constant Float := 1.0 / Fps;
         Prev : Pose;
         First_X : Float := 0.0;
         Landings : Natural := 0;
         Land_Sum : Float := 0.0;
         Last_Land : array (Side) of Float := [others => -1.0];
         Was_Up : array (Side) of Boolean := [others => False];
         R    : constant Rig := Castle.Serfs.Rig_Of (Index);
      begin
         Res.Hip_Lo := 1.0E9;
         Res.Hip_Hi := -1.0E9;
         Res.Max_Ahead := -1.0E9;
         Res.Max_Behind := 1.0E9;
         for F in 1 .. Natural (6.0 * Fps) loop
            Castle.Serfs.Update (Dt, (0.0, -20.0, 30.0));
            declare
               P  : constant Pose := Castle.Serfs.Posed (Index);
               Fw : constant Vec3 := (Cos (P.Heading), Sin (P.Heading), 0.0);
               Up : array (Side) of Boolean;
            begin
               for Sd in Side loop
                  Up (Sd) := P.Foot (Sd).Z > 10.0 + R.Ankle + 0.005;
               end loop;
               if Float (F) > 2.0 * Fps and then Float (F) < 5.0 * Fps then
                  if F = Natural (2.0 * Fps) + 1 then
                     First_X := P.Pelvis.X;
                  end if;
                  Res.Hip_Lo := Float'Min (Res.Hip_Lo, P.Pelvis.Z - 10.0);
                  Res.Hip_Hi := Float'Max (Res.Hip_Hi, P.Pelvis.Z - 10.0);
                  for Sd in Side loop
                     declare
                        Off : constant Float := Dot (P.Foot (Sd) - P.Pelvis, Fw);
                     begin
                        Res.Max_Ahead := Float'Max (Res.Max_Ahead, Off);
                        Res.Max_Behind := Float'Min (Res.Max_Behind, Off);
                     end;
                     --  a foot on the ground must stay where it is
                     if not Up (Sd) and then not Was_Up (Sd)
                       and then abs (P.Foot (Sd).X - Prev.Foot (Sd).X) + abs (P.Foot (Sd).Y - Prev.Foot (Sd).Y) > 0.002
                     then
                        Res.Slides := Res.Slides + 1;
                     end if;
                     if Was_Up (Sd) and then not Up (Sd) then
                        if Last_Land (Sd) >= 0.0 then
                           Land_Sum := Land_Sum + (P.Foot (Sd).X - Last_Land (Sd));
                           Landings := Landings + 1;
                        end if;
                        Last_Land (Sd) := P.Foot (Sd).X;
                     end if;
                  end loop;
                  if Up (Left) and then Up (Right) then
                     Res.Both_Up := Res.Both_Up + 1;
                  end if;
                  --  arms against the legs: the left arm forward when the right foot is
                  declare
                     Lead : constant Float := Dot (P.Foot (Right) - P.Foot (Left), Fw);
                  begin
                     if abs Lead > 0.15 then
                        Res.Arm_N := Res.Arm_N + 1;
                        if (Lead > 0.0) = (P.Swing (Left) > P.Swing (Right)) then
                           Res.Arm_Ok := Res.Arm_Ok + 1;
                        end if;
                     end if;
                  end;
                  Res.Speed := (P.Pelvis.X - First_X) / (Float (F) * Dt - 2.0);
               end if;
               for Sd in Side loop
                  Was_Up (Sd) := Up (Sd);
               end loop;
               Prev := P;
            end;
         end loop;
         Res.Stride := (if Landings > 0 then Land_Sum / Float (Landings) else 0.0);
         return Res;
      end Run;

      A, B : Run_Result;

      pragma Warnings (Off, "formal parameter * is not referenced");   --  the map is the same everywhere
      --  The walkers plan routes (Castle.Nav): a map of flat grass at 10 m
      --  everywhere, as the feet find it (no blocks loaded: Ground_At gives
      --  back the height it is asked about).
      procedure Flat_Column (Bx, By : Integer; C : out Castle.Water.Column; Known : out Boolean) is
      begin
         C := (N => 1, S => [1 => (Floor => 40, Ceil => Castle.Dims.Height_B, Water => 0), others => (0, 0, 0)],
               others => <>);
         Known := True;
      end Flat_Column;
      function Flat_Block (Bx, By, Bz : Integer) return Castle.Blocks.Material is
        (if Bz < 40 then Castle.Blocks.Grass else Castle.Blocks.Air);
      function Flat_Version (CX, CY : Integer) return Natural is (1);
   begin
      Castle.Nav.Set_Source (Flat_Column'Unrestricted_Access, Flat_Block'Unrestricted_Access,
                             Flat_Version'Unrestricted_Access);
      Castle.Serfs.Spawn_Walker ((0.0, 0.0, 10.0), (40.0, 0.0, 10.0), 777, Forester, False, 1.3);
      Castle.Serfs.Spawn_Walker ((0.0, 5.0, 10.0), (40.0, 5.0, 10.0), 777, Forester, False, 1.3);
      A := Run (1, 30.0);
      B := Run (2, 120.0);
      Check (A.Speed > 1.2 and then A.Speed < 1.4, "a walker keeps the pace it is given: " & Img (A.Speed, 2) & " m/s (1.3)");
      Check (A.Max_Ahead < 0.4 and then A.Max_Behind > -0.4,
             "feet stay within reach of the hips: " & Img (A.Max_Behind, 2) & " .. " & Img (A.Max_Ahead, 2) & " m");
      Check (A.Hip_Hi - A.Hip_Lo > 0.02 and then A.Hip_Hi - A.Hip_Lo < 0.09,
             "the pelvis bobs " & Img ((A.Hip_Hi - A.Hip_Lo) * 100.0, 1) & " cm a step");
      Check (A.Slides = 0, "no foot slides while it is down (" & Img (A.Slides) & " frames)");
      Check (A.Both_Up = 0, "one foot always on the ground: a walk, not a hop");
      Check (A.Arm_N > 0 and then Float (A.Arm_Ok) / Float (A.Arm_N) > 0.85,
             "the arms swing against the legs " & Img (100.0 * Float (A.Arm_Ok) / Float (Natural'Max (1, A.Arm_N)), 0)
             & " % of the time");
      Check (A.Stride > 0.5 and then abs (A.Stride - B.Stride) < 0.1 * A.Stride,
             "the same stride at 30 and 120 frames a second: " & Img (A.Stride, 2) & " and " & Img (B.Stride, 2) & " m");
   end;

   --  a sheet of skins to look at
   for A in 1 .. Argument_Count - 1 loop
      if Argument (A) = "--png" then
         declare
            Cols : constant := 6;
            Scale : constant := 3;
            Img_P : Castle.PNG.Image_Access :=
              new Castle.PNG.Image (0 .. 2 * Skin_H * Scale - 1, 0 .. Cols * Skin_W * Scale - 1);
            R : Rig;
            type Job_List is array (0 .. Cols * 2 - 1) of Job_Kind;
            Jobs : constant Job_List :=
              [Idle, Forester, Hunter, Gatherer, Porter, Lord, Idle, Forester, Hunter, Gatherer, Porter, Lord];
         begin
            for N in 0 .. Cols * 2 - 1 loop
               Build (Random_Genome (Derive (21, U64 (N)), Child => N = 6), (Jobs (N), N >= Cols, False), R, Skin_A.all);
               for Y in 0 .. Skin_H - 1 loop
                  for X in 0 .. Skin_W - 1 loop
                     declare
                        P : constant Unsigned_32 := Skin_A (Y, X);
                        A8 : constant Unsigned_32 := Shift_Right (P, 24);
                        C : constant Castle.PNG.RGB :=
                          (if A8 = 0 then (40, 36, 44)
                           else (Unsigned_8 (P and 255), Unsigned_8 (Shift_Right (P, 8) and 255),
                                 Unsigned_8 (Shift_Right (P, 16) and 255)));
                     begin
                        for Sy in 0 .. Scale - 1 loop
                           for Sx in 0 .. Scale - 1 loop
                              Img_P ((N / Cols) * Skin_H * Scale + Y * Scale + Sy,
                                     (N mod Cols) * Skin_W * Scale + X * Scale + Sx) := C;
                           end loop;
                        end loop;
                     end;
                  end loop;
               end loop;
            end loop;
            Castle.PNG.Write (Argument (A + 1), Img_P.all);
            Castle.PNG.Free (Img_P);
            Put_Line ("wrote " & Argument (A + 1));
         end;
      end if;
   end loop;

   if Failed = 0 then
      Put_Line ("all checks passed");
   else
      Put_Line (Img (Failed) & " checks FAILED");
      Set_Exit_Status (1);
   end if;
end Serf_Check;
