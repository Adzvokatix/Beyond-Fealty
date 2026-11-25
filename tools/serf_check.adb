--  Serfs without a window: thousands of generated people fit their skins,
--  build the same every time, are mirror images left and right (but for
--  what is meant not to be), stand on their feet at the height they were
--  given, and the two-bone IK lands where it is asked to.
--  ./bin/debug/serf_check [--png FILE]   (FILE: a sheet of skins to look at)
--  ./bin/debug/serf_check --voxels FILE [N [JOB [winter]]]   (one serf as voxel parts, to draw outside the game)

with Ada.Text_IO;      use Ada.Text_IO;
with Ada.Command_Line; use Ada.Command_Line;
with Interfaces;       use Interfaces;
with Castle.Bodies;    use Castle.Bodies;
with Castle.Bodies.Voxels;
with Castle.Voxel_Mesh;
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
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Characters.Handling;
with Ada.Real_Time;

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
   --  more form (Castle.Bodies.More_Form, 2026-11-22), beside the serfs as they were (off: --no-form):
   --  of the body before the reference body (Reference_Body off, --no-reference-body)
   Reference_Body := False;
   declare
      R_New, R_Old : Rig;
      Built : Natural := 0;
      More_Least : Integer := Integer'Last;
      More_Most  : Integer := Integer'First;
      Same_Limbs, Head_Where, Shoulders_Lower : Boolean := True;
   begin
      for I in 1 .. 500 loop
         declare
            G : constant Genome := Random_Genome (Derive (7, U64 (I)), Child => I mod 10 = 0, Elder => I mod 10 = 1);
         begin
            for J in Job_Kind loop
               for W in Boolean loop
                  More_Form := True;
                  Build (G, (J, W, False), R_New, Skin_A.all);
                  More_Form := False;
                  Build (G, (J, W, False), R_Old, Skin_B.all);     --  (raises if its nets do not fit)
                  More_Form := True;
                  Built := Built + 1;
                  More_Least := Integer'Min (More_Least, R_New.Count - R_Old.Count);
                  More_Most := Integer'Max (More_Most, R_New.Count - R_Old.Count);
                  Same_Limbs := Same_Limbs and then R_New.Height = R_Old.Height and then R_New.Hip = R_Old.Hip
                    and then R_New.Thigh = R_Old.Thigh and then R_New.Shin = R_Old.Shin
                    and then R_New.Upper_Arm = R_Old.Upper_Arm and then R_New.Forearm = R_Old.Forearm
                    and then R_New.Hip_Half = R_Old.Hip_Half;
                  --  (the head's joint over the hips' is the chest's over the hips' and the head's over the chest's)
                  Head_Where := Head_Where
                    and then abs ((R_New.Joint (Chest).Z + R_New.Joint (Head).Z)
                                  - (R_Old.Joint (Chest).Z + R_Old.Joint (Head).Z)) < 1.0E-5;
                  Shoulders_Lower := Shoulders_Lower
                    and then R_New.Joint (Chest).Z = R_Old.Joint (Chest).Z          --  (the hips as they were)
                    and then abs (R_Old.Joint (Upper_Arm_L).Z - R_New.Joint (Upper_Arm_L).Z - Float (Neck_Px) * Px) < 1.0E-5;
               end loop;
            end loop;
         end;
      end loop;
      Check (More_Least = 2 and then More_Most = 3,
             "with more form a serf has two boxes more, or three (a neck, a nose; a cap of hair or a kerchief"
             & " unless it is bald): " & Img (Built) & " built both ways, the serfs as they were among them");
      Check (Same_Limbs and then Head_Where and then Shoulders_Lower,
             "as tall, its legs and its arms as long and its head where it was; its shoulders a pixel lower (its neck)");
   end;
   Reference_Body := True;

   --  The reference body (John, 2026-11-23: "the skeleton model is the refrence bone structure ... a
   --  small button nose is fine, but the nose you have is too long"), against the bought skeleton's
   --  own measures: its thighs' joints at 40 % (24.5 voxels of 61), its hands, hanging, ending at
   --  28 % (17.3: the middle of the thigh).  An adult is held within five points of each: a pixel and
   --  a half of the shortest adult (29 pixels).  Its head, a third of its height (20 voxels: 33 %),
   --  is a bit smaller here (John, 2026-11-24, with a chart of a face's proportions: "cut the head
   --  down a bit, make it a bit smaller"): every adult's under that third; every head 8 or 9 pixels
   --  tall and its face in thirds as on his chart; since his words of the same morning ("lower the nose a
   --  square", and "lower the top of the head a couple of blocks, make the head shorter") every head 7 or
   --  8 pixels tall, its crown a pixel lower, the nose's foot 2.5 pixels (five voxels) over the chin's
   --  bottom, and the hair's edge over the forehead, where there is a cap, 3.5 over the nose's foot.
   Put_Line ("the reference body:");
   declare
      R : Rig;
      Built : Natural := 0;
      Head_Lo, Leg_Lo, Hand_Lo : Float := 1.0;
      Head_Hi, Leg_Hi, Hand_Hi : Float := 0.0;
      Below_Knee : Natural := 0;           --  serfs of any age whose hands, hanging, end at the knee or under it
      Nose_Most : Float := 0.0;           --  how far the nose stands out of the face, body pixels
      Noses, No_Nose : Natural := 0;
      Rows_Off, Thirds_Off : Natural := 0;   --  heads not 8 or 9 pixels tall; faces not in thirds
      Rows_8, Rows_9 : Natural := 0;         --  adults' heads of 8 pixels and of 9
      Eared, Ears_Off : Natural := 0;        --  heads with two ears; heads with ears where none should be, or none
      Crowned, Crown_Off : Natural := 0;     --  hair or a kerchief narrowing over the crown; where it does not
      F : Frames;
   begin
      for I in 1 .. 500 loop
         declare
            G : constant Genome := Random_Genome (Derive (7, U64 (I)), Child => I mod 10 = 0, Elder => I mod 10 = 1);
         begin
            for J in Job_Kind loop
               for W in Boolean loop
                  Build (G, (J, W, False), R, Skin_A.all);
                  Built := Built + 1;
                  --  the head's shape (Head_Shape): an ear a box half a pixel wide, a pixel deep and a pixel and
                  --  a half tall on each side where the hair leaves the sides bare; the cap of hair or kerchief
                  --  narrowing to its top
                  declare
                     Ears, Narrowing, Caps : Natural := 0;
                     Bare : constant Boolean :=
                       not W and then not G.Coif and then G.Hair_Style in Bald | Cropped | Short | Bun;
                  begin
                     for K in 1 .. R.Count loop
                        if R.Boxes (K).On = Head and then R.Boxes (K).Size = (0.5, 1.0, 1.5) then
                           Ears := Ears + 1;
                        end if;
                        if R.Boxes (K).On = Head and then R.Boxes (K).Taper < 0.0 and then not R.Boxes (K).Cutout then
                           Narrowing := Narrowing + 1;            --  (the hood narrows too: it is see-through at the face)
                        end if;
                     end loop;
                     Caps := (if (G.Hair_Style /= Bald or else G.Coif) and then not W then 1 else 0);   --  (in a hood: none)
                     if Ears = 2 and then Bare then
                        Eared := Eared + 1;
                     elsif Ears /= 0 or else Bare then
                        Ears_Off := Ears_Off + 1;
                     end if;
                     if Narrowing = Caps then
                        Crowned := Crowned + Caps;
                     else
                        Crown_Off := Crown_Off + 1;
                     end if;
                  end;
                  Solve (R, Standing (R, (0.0, 0.0, 0.0), 0.0), F);
                  if Place (F (Hand_L), (0.0, 0.0, -2.0)).Z <= R.Ankle + R.Shin + 0.001 then
                     Below_Knee := Below_Knee + 1;
                  end if;
                  declare
                     Head_Box : Natural := 0;
                     Nose_Box : Natural := 0;
                  begin
                     for K in 1 .. R.Count loop
                        if R.Boxes (K).On = Head and then Head_Box = 0 then
                           Head_Box := K;
                        elsif R.Boxes (K).On = Head and then R.Boxes (K).Size.X = 1.0 and then R.Boxes (K).Size.Z = 1.0
                          and then R.Boxes (K).Lo.Y > 0.0
                        then
                           Nose_Box := K;
                        end if;
                     end loop;
                     if R.Boxes (Head_Box).Size.Z /= 7.0 and then R.Boxes (Head_Box).Size.Z /= 8.0 then
                        Rows_Off := Rows_Off + 1;
                     end if;
                     declare
                        Foot : constant Float :=
                          (if Nose_Box = 0 then -1.0 else R.Boxes (Nose_Box).Lo.Z - R.Boxes (Head_Box).Lo.Z);
                        Cap  : Natural := 0;          --  the cap of hair or kerchief: narrowing, not see-through
                     begin
                        for K in 1 .. R.Count loop
                           if R.Boxes (K).On = Head and then R.Boxes (K).Taper < 0.0 and then not R.Boxes (K).Cutout then
                              Cap := K;
                           end if;
                        end loop;
                        if abs (Foot - 2.5) > 0.001
                          or else (Cap > 0 and then abs (R.Boxes (Cap).Lo.Z - R.Boxes (Head_Box).Lo.Z - Foot - 3.5) > 0.001)
                        then
                           Thirds_Off := Thirds_Off + 1;
                        end if;
                     end;
                     if G.Age >= 16.0 and then not W then
                        declare
                           Hb : constant Box := R.Boxes (Head_Box);
                        begin
                           if Hb.Size.Z = 7.0 then
                              Rows_8 := Rows_8 + 1;
                           elsif Hb.Size.Z = 8.0 then
                              Rows_9 := Rows_9 + 1;
                           end if;
                           Head_Lo := Float'Min (Head_Lo, Hb.Size.Z * Px / R.Height);
                           Head_Hi := Float'Max (Head_Hi, Hb.Size.Z * Px / R.Height);
                           Leg_Lo := Float'Min (Leg_Lo, R.Hip / R.Height);
                           Leg_Hi := Float'Max (Leg_Hi, R.Hip / R.Height);
                           declare
                              Low : constant Float := Place (F (Hand_L), (0.0, 0.0, -2.0)).Z / R.Height;   --  the hand's bottom
                           begin
                              Hand_Lo := Float'Min (Hand_Lo, Low);
                              Hand_Hi := Float'Max (Hand_Hi, Low);
                           end;
                           if Nose_Box > 0 then
                              Noses := Noses + 1;
                              Nose_Most := Float'Max (Nose_Most, R.Boxes (Nose_Box).Lo.Y + R.Boxes (Nose_Box).Size.Y
                                                                - (Hb.Lo.Y + Hb.Size.Y));
                           else
                              No_Nose := No_Nose + 1;
                           end if;
                        end;
                     end if;
                  end;
               end loop;
            end loop;
         end;
      end loop;
      Check (Head_Hi < 0.33,
             "adults' heads are " & Img (100.0 * Head_Lo, 1) & " to " & Img (100.0 * Head_Hi, 1)
             & " % of their height, under the skeleton's 33 % (a tall man's the least), of " & Img (Built) & " built");
      Check (Ears_Off = 0 and then Crown_Off = 0 and then Eared > 0 and then Crowned > 0,
             "the head's shape: two ears on every head whose sides the hair leaves bare (" & Img (Eared)
             & "), none under a kerchief, long hair or a hood; the hair or the kerchief narrowing over the crown on"
             & " every head that has one (" & Img (Crowned) & "): " & Img (Ears_Off) & " and " & Img (Crown_Off)
             & " otherwise");
      Check (Rows_Off = 0 and then Thirds_Off = 0,
             "every head 7 or 8 pixels tall (adults' " & Img (Rows_8) & " of 7 and " & Img (Rows_9)
             & " of 8), the nose's foot 2.5 pixels over the chin's bottom and the hair's edge 3.5 over it (the brows"
             & " and two voxels of forehead between) ("
             & Img (Rows_Off) & " heads and " & Img (Thirds_Off) & " faces otherwise)");
      --  (the skeleton's 40 %, held within five points but a point and a half more at the top: the head
      --  smaller than its third, the legs take their share of the rest, up to 46 % of a tall man)
      Check (Leg_Lo >= 0.40 - 0.05 and then Leg_Hi <= 0.40 + 0.065,
             "their hips' joints at " & Img (100.0 * Leg_Lo, 1) & " to " & Img (100.0 * Leg_Hi, 1)
             & " % of their height (the skeleton's 40 %; with its head smaller than the skeleton's third)");
      Check (Hand_Lo >= 0.28 - 0.05 and then Hand_Hi <= 0.28 + 0.05,
             "their hands, hanging, end at " & Img (100.0 * Hand_Lo, 1) & " to " & Img (100.0 * Hand_Hi, 1)
             & " % of their height (the skeleton's 28 %: the middle of the thigh)");
      Check (Below_Knee = 0, "no serf's hands, of any age, hang to its knees (" & Img (Below_Knee) & " do)");
      Check (No_Nose = 0 and then Nose_Most <= 0.5001,
             "a button nose on every face, a pixel square and at most half a pixel (a voxel) out of it: "
             & Img (Nose_Most, 2) & " px (it was 0.8 px, a pixel and a half tall)");
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
                  if A.On = Head and then Top = 0.0 then        --  (the head's own box is the first of the head's)
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

   --  At work, how far the hands and forearms go into the head (the reference body's head is 8 or 9
   --  pixels tall, and the poses were made for a head of six): sixty serfs in a row,
   --  in summer clothes, each at each kind of work over three seconds, with a spot to work at where
   --  the colony would give one; whatever of a hand or a forearm lies a quarter of a pixel or more
   --  inside a box of its own head (the head, its hair, its nose, a beard) is counted, and the body
   --  as it was beside it.  Printed, not failed on: the body as it was does it too (2026-11-23: all
   --  sixty at chop, aim, eat and sit_eat), and keeping the hands out is put to John.
   Put_Line ("hands at work:");
   declare
      use type Castle.Serfs.Motion_Kind;
      N_Row : constant := 60;
      type Count_Of is array (Castle.Serfs.Motion_Kind) of Natural;
      type Depth_Of is array (Castle.Serfs.Motion_Kind) of Float;
      procedure Row (Into : out Count_Of; Deepest : out Depth_Of) is
         Base : constant Natural := Castle.Serfs.Count;
      begin
         Into := [others => 0];
         Deepest := [others => 0.0];
         for M in Castle.Serfs.Motion_Kind loop
            if M not in Castle.Serfs.Walk | Castle.Serfs.Lie | Castle.Serfs.Sleep then
               Castle.Serfs.Clear;
               Castle.Serfs.Spawn_Lineup (N_Row, (0.0, 30.0, 10.0), 0.0, 4242, False);
               declare
                  Hit : array (1 .. N_Row) of Boolean := [others => False];
               begin
                  for F in 1 .. 90 loop
                     for I in 1 .. Castle.Serfs.Count loop
                        declare
                           P  : constant Vec3 := Castle.Serfs.Where (I);
                           H  : constant Float := Castle.Serfs.Heading (I);
                           Fw : constant Vec3 := (Cos (H), Sin (H), 0.0);
                           Spot : constant Vec3 :=
                             (case M is
                                 when Castle.Serfs.Pick => P + Fw * 0.5 + (0.0, 0.0, 0.5),
                                 when Castle.Serfs.Put_Down => P + Fw * 0.5,
                                 when Castle.Serfs.Chop => P + Fw * 0.9 + (0.0, 0.0, 0.7),
                                 when Castle.Serfs.Stir => P + Fw * 0.6 + (0.0, 0.0, 0.3),
                                 when others => P + Fw * 3.0 + (0.0, 0.0, 0.7));
                        begin
                           Castle.Serfs.Drive (I, P, M, Spot);
                        end;
                     end loop;
                     Castle.Serfs.Update (1.0 / 30.0, (0.0, -20.0, 30.0));
                     if F > 30 then
                        for I in 1 .. Castle.Serfs.Count loop
                           declare
                              R  : constant Rig := Castle.Serfs.Rig_Of (I);
                              Fr : Frames;
                           begin
                              Solve (R, Castle.Serfs.Posed (I), Fr);
                              for K in 1 .. R.Count loop
                                 if R.Boxes (K).On in Hand_L | Hand_R | Forearm_L | Forearm_R then
                                    declare
                                       A  : constant Box := R.Boxes (K);
                                       Nx : constant Positive := Natural (Float'Ceiling (2.0 * A.Size.X)) + 1;
                                       Ny : constant Positive := Natural (Float'Ceiling (2.0 * A.Size.Y)) + 1;
                                       Nz : constant Positive := Natural (Float'Ceiling (2.0 * A.Size.Z)) + 1;
                                    begin
                                       for Ix in 0 .. Nx - 1 loop
                                          for Iy in 0 .. Ny - 1 loop
                                             for Iz in 0 .. Nz - 1 loop
                                                declare
                                                   W : constant Vec3 :=
                                                     Place (Fr (A.On), (A.Lo.X + A.Size.X * Float (Ix) / Float (Nx - 1),
                                                                        A.Lo.Y + A.Size.Y * Float (Iy) / Float (Ny - 1),
                                                                        A.Lo.Z + A.Size.Z * Float (Iz) / Float (Nz - 1)));
                                                   Hf : constant Frame := Fr (Head);
                                                   D  : constant Vec3 := W - Hf.O;
                                                   L  : constant Vec3 := (Dot (D, Hf.X) / Px, Dot (D, Hf.Y) / Px, Dot (D, Hf.Z) / Px);
                                                begin
                                                   for J in 1 .. R.Count loop
                                                      if R.Boxes (J).On = Head and then not R.Boxes (J).Cutout then
                                                         declare
                                                            B2 : constant Box := R.Boxes (J);
                                                            Depth : constant Float :=
                                                              Float'Min (Float'Min (Float'Min (L.X - B2.Lo.X, B2.Lo.X + B2.Size.X - L.X),
                                                                                    Float'Min (L.Y - B2.Lo.Y, B2.Lo.Y + B2.Size.Y - L.Y)),
                                                                         Float'Min (L.Z - B2.Lo.Z, B2.Lo.Z + B2.Size.Z - L.Z));
                                                         begin
                                                            if Depth >= 0.25 then
                                                               Hit (I) := True;
                                                               Deepest (M) := Float'Max (Deepest (M), Depth);
                                                            end if;
                                                         end;
                                                      end if;
                                                   end loop;
                                                end;
                                             end loop;
                                          end loop;
                                       end loop;
                                    end;
                                 end if;
                              end loop;
                           end;
                        end loop;
                     end if;
                  end loop;
                  for I in Hit'Range loop
                     Into (M) := Into (M) + (if Hit (I) then 1 else 0);
                  end loop;
               end;
            end if;
         end loop;
         Castle.Serfs.Clear;
         pragma Unreferenced (Base);
      end Row;
      New_In, Old_In : Count_Of;
      New_D, Old_D : Depth_Of;
      Worst : Natural := 0;
      Said_New, Said_Old : Unbounded_String;
   begin
      Row (New_In, New_D);
      Reference_Body := False;
      Row (Old_In, Old_D);
      Reference_Body := True;
      for M in Castle.Serfs.Motion_Kind loop
         if M not in Castle.Serfs.Walk | Castle.Serfs.Lie | Castle.Serfs.Sleep then
            Worst := Natural'Max (Worst, New_In (M));
            Append (Said_New, " " & Ada.Characters.Handling.To_Lower (M'Image) & " " & Img (New_In (M))
                    & (if New_In (M) > 0 then " (" & Img (New_D (M), 1) & " px)" else ""));
            Append (Said_Old, " " & Ada.Characters.Handling.To_Lower (M'Image) & " " & Img (Old_In (M))
                    & (if Old_In (M) > 0 then " (" & Img (Old_D (M), 1) & " px)" else ""));
         end if;
      end loop;
      Put_Line ("  " & (if Worst = 0 then "ok    " else "MISS  ") & "of " & Img (Natural'(N_Row))
                & " serfs at each work, how many put a hand or a forearm into their own head (the deepest):"
                & To_String (Said_New));
      Put_Line ("        the body as it was:" & To_String (Said_Old));
   end;

   --  Voxel parts (docs/design/Voxel_people_brief.md, step 1: the parity).  Counted over 600
   --  genomes, every job, summer and winter: 7,200 looks.
   Put_Line ("voxel parts:");
   declare
      package BV renames Castle.Bodies.Voxels;
      package VM renames Castle.Voxel_Mesh;
      L1 : constant BV.Look_Access := new BV.Voxel_Look;
      L2 : constant BV.Look_Access := new BV.Voxel_Look;
      R  : Rig;
      type Tally is record
         N, Sum, Most : Natural := 0;
      end record;
      procedure Add (T : in out Tally; Q : Natural) is
      begin
         T.N := T.N + 1;
         T.Sum := T.Sum + Q;
         T.Most := Natural'Max (T.Most, Q);
      end Add;
      function Said (T : Tally) return String is
        (Img (2 * T.Sum / Natural'Max (1, T.N)) & " (the most " & Img (2 * T.Most) & ")");
      Every, Women, Men, Children, Summer, Winter_T, Boxes_T : Tally;
      By_Job : array (Job_Kind) of Tally;
      Same : Boolean := True;
      Colours_Most, Merged_Looks, Empty_Boxes, Empty_Looks : Natural := 0;
      Stray, Bare, Unlike : Natural := 0;
      Solid_Sum, Surface_Sum : Natural := 0;
      Half : VM.Part := (G => new VM.Grid, others => <>);
      Alt_N, Alt_Own, Alt_Any, Alt_Un, Alt_Half, Alt_Half_Any : Natural := 0;
      Drawn_Sum, Drawn_Most, Bytes_Most, Boxes_Most : Natural := 0;   --  what is drawn (merged whatever the colour)
      Old_Drawn_Most, Old_Bytes_Most, Old_N, Old_Drawn_Sum : Natural := 0;   --  the same, of the body as it was
      Build_Ms : Float := 0.0;                                                --  a look made for the game, ms
      Off_Face, Off_Area, Off_Byte : Natural := 0;   --  drawn quads not on an open face; looks short or over; bytes astray
   begin
      for I in 1 .. 600 loop
         declare
            G : constant Genome := Random_Genome (Derive (7, U64 (I)), Child => I mod 10 = 0, Elder => I mod 10 = 1);
         begin
            for J in Job_Kind loop
               for W in Boolean loop
                  Build (G, (J, W, False), R, Skin_A.all);
                  BV.Build (R, Skin_A.all, L1.all);
                  Add (Every, L1.N);
                  Add (Boxes_T, 54 * R.Count);          --  (a box is 108 triangles)
                  Drawn_Sum := Drawn_Sum + L1.Drawn_N;
                  Drawn_Most := Natural'Max (Drawn_Most, L1.Drawn_N);
                  Bytes_Most := Natural'Max (Bytes_Most, L1.Bytes_N);
                  Boxes_Most := Natural'Max (Boxes_Most, R.Count);
                  if G.Age < 15.0 then
                     Add (Children, L1.N);
                  elsif G.Sex = Female then
                     Add (Women, L1.N);
                  else
                     Add (Men, L1.N);
                  end if;
                  if W then
                     Add (Winter_T, L1.N);
                  else
                     Add (Summer, L1.N);
                  end if;
                  Add (By_Job (J), L1.N);
                  Colours_Most := Natural'Max (Colours_Most, L1.Colours);
                  Merged_Looks := Merged_Looks + (if L1.Merged > 0 then 1 else 0);
                  Empty_Boxes := Empty_Boxes + L1.Empty;
                  Empty_Looks := Empty_Looks + (if L1.Empty > 0 then 1 else 0);
                  Solid_Sum := Solid_Sum + L1.Solid;
                  Surface_Sum := Surface_Sum + L1.Surface;
                  if I <= 120 then        --  (what else it could be meshed as: counted, not built)
                     for B in Bone loop
                        declare
                           P : constant VM.Part := BV.Part_Of (B);
                           Bc, Ac, Un : Natural;
                        begin
                           VM.Quads_Of (P, Bc, Ac, Un);
                           Alt_Any := Alt_Any + Ac;
                           Alt_Un := Alt_Un + Un;
                           VM.Halve (P, Half);
                           VM.Quads_Of (Half, Bc, Ac, Un);
                           Alt_Half := Alt_Half + Bc;
                           Alt_Half_Any := Alt_Half_Any + Ac;
                        end;
                     end loop;
                     Alt_N := Alt_N + 1;
                     Alt_Own := Alt_Own + L1.N;
                  end if;
                  if I <= 40 then
                     --  the drawn quads (merged whatever the colour) lie on open faces, each face of
                     --  each quad, and cover as many faces as there are open, as the brief's quads do
                     declare
                        Open, Area_Drawn, Area_Brief : Natural := 0;
                     begin
                        for B in Bone loop
                           declare
                              P : constant VM.Part := BV.Part_Of (B);
                              function At_G (X, Y, Z : Integer) return Boolean is
                                (X in 0 .. P.Nx - 1 and then Y in 0 .. P.Ny - 1 and then Z in 0 .. P.Nz - 1
                                 and then P.G (X, Y, Z) /= 0);
                           begin
                              for X in 0 .. P.Nx - 1 loop
                                 for Y in 0 .. P.Ny - 1 loop
                                    for Z in 0 .. P.Nz - 1 loop
                                       if At_G (X, Y, Z) then
                                          Open := Open + Boolean'Pos (not At_G (X + 1, Y, Z)) + Boolean'Pos (not At_G (X - 1, Y, Z))
                                            + Boolean'Pos (not At_G (X, Y + 1, Z)) + Boolean'Pos (not At_G (X, Y - 1, Z))
                                            + Boolean'Pos (not At_G (X, Y, Z + 1)) + Boolean'Pos (not At_G (X, Y, Z - 1));
                                       end if;
                                    end loop;
                                 end loop;
                              end loop;
                              for K in 1 .. L1.Drawn_N loop
                                 declare
                                    Qx, Qy, Qz : VM.Coord;
                                    Qw, Qh : Positive;
                                    Qf : VM.Facing;
                                    Qc : VM.U8;
                                    Qb : Natural;
                                 begin
                                    VM.Unpack (L1.Drawn (K), Qx, Qy, Qz, Qw, Qh, Qf, Qc, Qb);
                                    if Qb = Bone'Pos (B) then
                                       Area_Drawn := Area_Drawn + Qw * Qh;
                                       for U in 0 .. Qw - 1 loop
                                          for V in 0 .. Qh - 1 loop
                                             declare

                                                Ax : constant Natural := VM.Facing'Pos (Qf) / 2;
                                                St : constant Integer := (if VM.Facing'Pos (Qf) mod 2 = 0 then 1 else -1);
                                                X : constant Integer := Qx + (if Ax = 0 then 0 else U);
                                                Y : constant Integer := Qy + (if Ax = 0 then U elsif Ax = 1 then 0 else V);
                                                Z : constant Integer := Qz + (if Ax = 2 then 0 else V);
                                                Nx : constant Integer := X + (if Ax = 0 then St else 0);
                                                Ny : constant Integer := Y + (if Ax = 1 then St else 0);
                                                Nz : constant Integer := Z + (if Ax = 2 then St else 0);
                                             begin
                                                if not At_G (X, Y, Z) or else At_G (Nx, Ny, Nz) or else Qc /= 0 then
                                                   Off_Face := Off_Face + 1;
                                                end if;
                                             end;
                                          end loop;
                                       end loop;
                                    end if;
                                 end;
                              end loop;
                              for K in 1 .. L1.N loop
                                 declare
                                    Qx, Qy, Qz : VM.Coord;
                                    Qw, Qh : Positive;
                                    Qf : VM.Facing;
                                    Qc : VM.U8;
                                    Qb : Natural;
                                 begin
                                    VM.Unpack (L1.Quads (K), Qx, Qy, Qz, Qw, Qh, Qf, Qc, Qb);
                                    if Qb = Bone'Pos (B) then
                                       Area_Brief := Area_Brief + Qw * Qh;
                                    end if;
                                 end;
                              end loop;
                              --  and the bytes are the grid, at the part's own offset
                              for X in 0 .. P.Nx - 1 loop
                                 for Y in 0 .. P.Ny - 1 loop
                                    for Z in 0 .. P.Nz - 1 loop
                                       if L1.Bytes (L1.Parts (B).Offset + X + P.Nx * (Y + P.Ny * Z)) /= P.G (X, Y, Z) then
                                          Off_Byte := Off_Byte + 1;
                                       end if;
                                    end loop;
                                 end loop;
                              end loop;
                           end;
                        end loop;
                        if Area_Drawn /= Open or else Area_Brief /= Open then
                           Off_Area := Off_Area + 1;
                        end if;
                     end;
                     --  the same again: the same quads and palette
                     BV.Build (R, Skin_A.all, L2.all);
                     Same := Same and then L1.N = L2.N and then L1.Colours = L2.Colours
                       and then (for all K in 1 .. L1.N => VM."=" (L1.Quads (K), L2.Quads (K)))
                       and then (for all K in 0 .. 255 => L1.Pal (K) = L2.Pal (K));
                     --  the parity: a voxel is solid if and only if its centre lies inside a box of
                     --  its bone (but where the skin is see-through); a ring of voxels round each part too
                     for B in Bone loop
                        declare
                           P : constant VM.Part := BV.Part_Of (B);
                        begin
                           for X in -1 .. P.Nx loop
                              for Y in -1 .. P.Ny loop
                                 for Z in -1 .. P.Nz loop
                                    declare
                                       C : constant Vec3 := ((Float (P.Ox + X) + 0.5) * 0.5, (Float (P.Oy + Y) + 0.5) * 0.5,
                                                             (Float (P.Oz + Z) + 0.5) * 0.5);
                                       In_Grid : constant Boolean :=
                                         X in 0 .. P.Nx - 1 and then Y in 0 .. P.Ny - 1 and then Z in 0 .. P.Nz - 1;
                                       Is_Solid : constant Boolean := In_Grid and then P.G (X, Y, Z) /= 0;
                                       Inside_One, Inside_Plain : Boolean := False;
                                    begin
                                       for K in 1 .. R.Count loop
                                          if R.Boxes (K).On = B and then BV.Outside (R.Boxes (K), C) <= 0.0 then
                                             Inside_One := True;
                                             Inside_Plain := Inside_Plain or else not R.Boxes (K).Cutout;
                                          end if;
                                       end loop;
                                       if Is_Solid and then not Inside_One then
                                          Stray := Stray + 1;
                                       elsif Inside_Plain and then not Is_Solid then
                                          Bare := Bare + 1;
                                       end if;
                                    end;
                                 end loop;
                              end loop;
                           end loop;
                        end;
                     end loop;
                  end if;
                  if I <= 200 and then J = Idle and then not W then
                     --  left and right: the same shape, mirrored (colours are the skin's, checked above)
                     for B in Bone loop
                        if not Is_Middle (B) and then Bone'Pos (B) < Bone'Pos (Mirror (B)) then
                           declare
                              P : constant VM.Part := BV.Part_Of (B);
                              Q : constant VM.Part := BV.Part_Of (Mirror (B));
                           begin
                              if P.Nx /= Q.Nx or else P.Ny /= Q.Ny or else P.Nz /= Q.Nz or else P.Oy /= Q.Oy
                                or else P.Oz /= Q.Oz or else P.Ox /= -(Q.Ox + Q.Nx)
                              then
                                 Unlike := Unlike + 1;
                              else
                                 for X in 0 .. P.Nx - 1 loop
                                    for Y in 0 .. P.Ny - 1 loop
                                       for Z in 0 .. P.Nz - 1 loop
                                          if (P.G (X, Y, Z) /= 0) /= (Q.G (Q.Nx - 1 - X, Y, Z) /= 0) then
                                             Unlike := Unlike + 1;
                                          end if;
                                       end loop;
                                    end loop;
                                 end loop;
                              end if;
                           end;
                        end if;
                     end loop;
                  end if;
               end loop;
            end loop;
         end;
      end loop;
      --  what a look costs the game to make (drawn quads only, Brief_Mesh off): the first 200
      declare
         use type Ada.Real_Time.Time;
         T0 : constant Ada.Real_Time.Time := Ada.Real_Time.Clock;
         Made : Natural := 0;
      begin
         for I in 1 .. 100 loop
            declare
               G : constant Genome := Random_Genome (Derive (7, U64 (I)), Child => I mod 10 = 0, Elder => I mod 10 = 1);
            begin
               for W in Boolean loop
                  Build (G, (Gatherer, W, False), R, Skin_A.all);
                  BV.Build (R, Skin_A.all, L1.all, Brief_Mesh => False);
                  Made := Made + 1;
               end loop;
            end;
         end loop;
         Build_Ms := Float (Ada.Real_Time.To_Duration (Ada.Real_Time.Clock - T0)) * 1000.0 / Float (Made);
      end;
      --  the body as it was (--no-reference-body), voxels drawn: what it needs room for
      Reference_Body := False;
      for I in 1 .. 300 loop
         declare
            G : constant Genome := Random_Genome (Derive (7, U64 (I)), Child => I mod 10 = 0, Elder => I mod 10 = 1);
         begin
            for J in Job_Kind loop
               for W in Boolean loop
                  Build (G, (J, W, False), R, Skin_A.all);
                  BV.Build (R, Skin_A.all, L1.all);
                  Old_N := Old_N + 1;
                  Old_Drawn_Sum := Old_Drawn_Sum + L1.Drawn_N;
                  Old_Drawn_Most := Natural'Max (Old_Drawn_Most, L1.Drawn_N);
                  Old_Bytes_Most := Natural'Max (Old_Bytes_Most, L1.Bytes_N);
               end loop;
            end loop;
         end;
      end loop;
      Reference_Body := True;
      Check (Same, "the same rig and skin give the same quads and palette");
      --  (the room a look has: twice the most of the reference body, and room for the body as it was)
      Check (2 * Drawn_Most <= BV.Max_Drawn and then 2 * Bytes_Most <= BV.Max_Bytes
               and then Old_Drawn_Most <= BV.Max_Drawn and then Old_Bytes_Most <= BV.Max_Bytes,
             "a look as drawn (its faces merged whatever their colour): " & Img (2 * Drawn_Sum / Every.N)
             & " triangles (the most " & Img (2 * Drawn_Most) & "), its parts' voxels at the most "
             & Img (Bytes_Most) & ", in room for" & BV.Max_Drawn'Image & " quads and" & BV.Max_Bytes'Image
             & " voxels; the body as it was " & Img (2 * Old_Drawn_Sum / Old_N) & " (the most " & Img (2 * Old_Drawn_Most)
             & "), at the most " & Img (Old_Bytes_Most) & " voxels, over " & Img (Old_N) & " looks; at the most "
             & Img (Boxes_Most) & " boxes a look");
      Put_Line ("        a look made as the game makes it (its drawn quads only): " & Img (Build_Ms, 2)
                & " ms, the body with its rig and skin included (200 looks; this build's own speed)");
      Check (Off_Face = 0 and then Off_Area = 0 and then Off_Byte = 0,
             "the drawn quads lie on open faces and cover them all, as the brief's do; each part's bytes are its grid ("
             & Img (Off_Face) & " faces astray, " & Img (Off_Area) & " looks short or over, " & Img (Off_Byte)
             & " bytes astray, over 480 looks)");
      Check (Stray = 0 and then Bare = 0,
             "a voxel is solid where its centre lies inside a box of its bone, and nowhere else (" & Img (Stray)
             & " outside every box, " & Img (Bare) & " inside one and air)");
      Check (Unlike = 0, "left and right parts are the same shape, mirrored (" & Img (Unlike) & " voxels or parts unlike)");
      --  (The brief's two first values, as measured on 2026-11-23, are not met: a skin's grain is a
      --  shade a texel, so a look has more colours than a palette holds and few faces merge.  They
      --  are printed, not failed on: which way to go is put to John (the voxel handoff, his calls).)
      Check (Colours_Most <= 255, "no palette past 255 entries");
      Put_Line ("  " & (if Merged_Looks = 0 then "ok    " else "MISS  ") & "a look's colours fit its palette without merging: "
                & Img (Merged_Looks) & " of " & Img (Every.N) & " looks had colours merged for room");
      Put_Line ("        boxes that took no voxel (thinner than one): " & Img (Empty_Boxes) & " in " & Img (Empty_Looks)
                & " of " & Img (Every.N) & " looks");
      Put_Line ("        voxels a look: " & Img (Solid_Sum / Every.N) & ", " & Img (Surface_Sum / Every.N) & " of them with a side open");
      Put_Line ("        triangles a look, as boxes: " & Said (Boxes_T));
      Put_Line ("        triangles a look, voxel parts: " & Said (Every) & "; women " & Said (Women) & ", men " & Said (Men)
                & ", children " & Said (Children));
      Put_Line ("        summer " & Said (Summer) & ", winter " & Said (Winter_T));
      Put_Line ("        counted over the first " & Img (Alt_N) & " looks, triangles a look: as built " & Img (2 * Alt_Own / Alt_N)
                & "; merged whatever the colour " & Img (2 * Alt_Any / Alt_N) & "; a quad an open side, nothing merged "
                & Img (2 * Alt_Un / Alt_N) & "; at half the fineness (5 cm) " & Img (2 * Alt_Half / Alt_N)
                & ", and merged whatever the colour " & Img (2 * Alt_Half_Any / Alt_N));
      for J in Job_Kind loop
         Put_Line ("        " & J'Image & " " & Said (By_Job (J)));
      end loop;
      Put_Line ("  " & (if 2 * Every.Sum / Every.N <= 2600 then "ok    " else "MISS  ")
                & "the brief's first limit, a mean of 2,600 triangles a serf merged by colour: " & Img (2 * Every.Sum / Every.N));
   end;

   --  one serf's voxels, to draw (tools outside the repository): --voxels FILE [N [JOB [winter]]]
   for A in 1 .. Argument_Count - 1 loop
      if Argument (A) = "--voxels" then
         declare
            package BV renames Castle.Bodies.Voxels;
            package VM renames Castle.Voxel_Mesh;
            N : constant Natural := (if A + 2 <= Argument_Count then Natural'Value (Argument (A + 2)) else 0);
            Jb : constant Job_Kind := (if A + 3 <= Argument_Count then Job_Kind'Value (Argument (A + 3)) else Idle);
            Wn : constant Boolean := A + 4 <= Argument_Count and then Argument (A + 4) = "winter";
            G : constant Genome := Random_Genome (Derive (21, U64 (N)));
            R : Rig;
            L : constant BV.Look_Access := new BV.Voxel_Look;
            F : File_Type;
            At_J : array (Bone) of Vec3;
         begin
            Build (G, (Jb, Wn, False), R, Skin_A.all);
            BV.Build (R, Skin_A.all, L.all);
            Create (F, Out_File, Argument (A + 1));
            Put_Line (F, "serf " & Describe (G, (Jb, Wn, False)) & "; height" & Integer'Image (Integer (R.Height * 1000.0))
                      & " mm; quads" & L.N'Image & "; boxes" & R.Count'Image);
            for B in Bone loop
               At_J (B) := (if B = Pelvis then R.Joint (B) else At_J (Parent (B)) + R.Joint (B));
               declare
                  P : constant VM.Part := BV.Part_Of (B);
               begin
                  Put_Line (F, "bone " & B'Image & Integer'Image (Integer (At_J (B).X * 1.0e5)) & Integer'Image (Integer (At_J (B).Y * 1.0e5))
                            & Integer'Image (Integer (At_J (B).Z * 1.0e5)));
                  for X in 0 .. P.Nx - 1 loop
                     for Y in 0 .. P.Ny - 1 loop
                        for Z in 0 .. P.Nz - 1 loop
                           if P.G (X, Y, Z) /= 0 then
                              Put_Line (F, "v" & Integer'Image (P.Ox + X) & Integer'Image (P.Oy + Y) & Integer'Image (P.Oz + Z)
                                        & Unsigned_32'Image (L.Pal (Natural (P.G (X, Y, Z))) and 16#FFFFFF#));
                           end if;
                        end loop;
                     end loop;
                  end loop;
               end;
            end loop;
            Close (F);
            Put_Line ("wrote " & Argument (A + 1) & ": " & Describe (G, (Jb, Wn, False)));
         end;
      end if;
   end loop;

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
