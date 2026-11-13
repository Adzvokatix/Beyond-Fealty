with Ada.Numerics;
with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;

package body Castle.Poses is

   Pi : constant := Ada.Numerics.Pi;

   function Rotate (V, Axis : Vec3; Angle : Float) return Vec3 is
      C : constant Float := Cos (Angle);
      S : constant Float := Sin (Angle);
   begin
      --  Rodrigues: v cos + (k x v) sin + k (k . v)(1 - cos)
      return V * C + Cross (Axis, V) * S + Axis * (Dot (Axis, V) * (1.0 - C));
   end Rotate;

   function Turned (F : Frame; Axis : Vec3; Angle : Float) return Frame is
     ((X => Rotate (F.X, Axis, Angle), Y => Rotate (F.Y, Axis, Angle),
       Z => Rotate (F.Z, Axis, Angle), O => F.O));

   function Place (F : Frame; P : Vec3) return Vec3 is
     (F.O + F.X * (P.X * Px) + F.Y * (P.Y * Px) + F.Z * (P.Z * Px));

   function Offset (F : Frame; J : Vec3) return Vec3 is
     (F.O + F.X * J.X + F.Y * J.Y + F.Z * J.Z);

   function Unwrap (Angle, Near : Float) return Float is
     (Angle - 2.0 * Pi * Float'Rounding ((Angle - Near) / (2.0 * Pi)));

   function Yaw_Frame (H : Float; O : Vec3) return Frame is
     ((X => (Sin (H), -Cos (H), 0.0), Y => (Cos (H), Sin (H), 0.0), Z => (0.0, 0.0, 1.0), O => O));

   --  A bone from its joint to the next one down, its forward axis the
   --  pole made square to it.
   function Along (From, To, Pole : Vec3) return Frame is
      Z : constant Vec3 := Normalize (From - To);
      Y : Vec3 := Pole - Z * Dot (Pole, Z);
   begin
      if Dot (Y, Y) < 1.0E-8 then
         Y := Cross (Z, (1.0, 0.0, 0.0));
      end if;
      Y := Normalize (Y);
      return (X => Cross (Y, Z), Y => Y, Z => Z, O => From);
   end Along;

   procedure Two_Bone
     (Root, Target, Pole : Vec3;
      A, B               : Float;
      Mid, Tip           : out Vec3;
      Reached            : out Boolean)
   is
      D : constant Vec3 := Target - Root;
      C : constant Float := Sqrt (Dot (D, D));
   begin
      Reached := C <= A + B;
      if C < 1.0E-5 then
         Mid := Root + Normalize (Pole) * A;
         Tip := Root;
         return;
      end if;
      declare
         Cc : constant Float := Float'Max (abs (A - B) + 1.0E-4, Float'Min (A + B - 1.0E-5, C));
         J  : constant Vec3 := D * (1.0 / C);
         I0 : constant Vec3 := Pole - J * Dot (Pole, J);
         I  : constant Vec3 :=
           (if Dot (I0, I0) > 1.0E-10 then Normalize (I0) else Normalize (Cross (J, (0.0, 0.0, 1.0))));
         T  : constant Float := (Cc * Cc + A * A - B * B) / (2.0 * Cc);   --  along the line, by the law of cosines
         S  : constant Float := Sqrt (Float'Max (0.0, A * A - T * T));    --  and out to the side
      begin
         Mid := Root + J * T + I * S;
         Tip := Root + J * Cc;
      end;
   end Two_Bone;

   function Standing (R : Rig; Ground : Vec3; Heading : Float) return Pose is
      P   : Pose;
      Rt  : constant Vec3 := (Sin (Heading), -Cos (Heading), 0.0);
   begin
      P.Pelvis  := Ground + (0.0, 0.0, R.Hip);
      P.Heading := Heading;
      P.Foot (Left)  := Ground + Rt * (-R.Hip_Half) + (0.0, 0.0, R.Ankle);
      P.Foot (Right) := Ground + Rt * R.Hip_Half + (0.0, 0.0, R.Ankle);
      P.Foot_Heading := [others => Heading];
      return P;
   end Standing;

   Upper : constant array (Side) of Bone := [Left => Upper_Arm_L, Right => Upper_Arm_R];
   Fore  : constant array (Side) of Bone := [Left => Forearm_L, Right => Forearm_R];
   Hand  : constant array (Side) of Bone := [Left => Hand_L, Right => Hand_R];
   Thigh : constant array (Side) of Bone := [Left => Thigh_L, Right => Thigh_R];
   Shin  : constant array (Side) of Bone := [Left => Shin_L, Right => Shin_R];
   Foot  : constant array (Side) of Bone := [Left => Foot_L, Right => Foot_R];
   Out_Sign : constant array (Side) of Float := [Left => 1.0, Right => -1.0];   --  spreading turns -Z toward -X on the left

   procedure Solve (R : Rig; P : Pose; F : out Frames) is
      Body_F : Frame := Yaw_Frame (P.Heading, P.Pelvis);
   begin
      --  pelvis: lean forward (up toward forward), then roll
      Body_F := Turned (Body_F, Body_F.X, -P.Lean);
      Body_F := Turned (Body_F, Body_F.Y, P.Tilt);
      F (Pelvis) := Body_F;

      declare
         C : Frame := F (Pelvis);
      begin
         C.O := Offset (F (Pelvis), R.Joint (Chest));
         C := Turned (C, C.Z, P.Twist);
         C := Turned (C, C.X, -P.Bend);
         F (Chest) := C;
      end;
      declare
         H : Frame := F (Chest);
      begin
         H.O := Offset (F (Chest), R.Joint (Head));
         H := Turned (H, H.Z, P.Look_Yaw);
         H := Turned (H, H.X, -P.Look_Pitch);
         F (Head) := H;
      end;

      for S in Side loop
         declare
            Shoulder : constant Vec3 := Offset (F (Chest), R.Joint (Upper (S)));
         begin
            if P.Reach (S) then
               declare
                  Pole : constant Vec3 := F (Chest).Y * (-1.0) + F (Chest).Z * (-0.4)
                    + F (Chest).X * (-0.5 * Out_Sign (S));      --  elbows back, down and out
                  Elbow, Wrist : Vec3;
                  Ok : Boolean;
               begin
                  Two_Bone (Shoulder, P.Hand (S), Pole, R.Upper_Arm, R.Forearm, Elbow, Wrist, Ok);
                  F (Upper (S)) := Along (Shoulder, Elbow, F (Chest).Y);
                  F (Fore (S)) := Along (Elbow, Wrist, F (Chest).Y);
                  F (Hand (S)) := F (Fore (S));
                  F (Hand (S)).O := Wrist;
               end;
            else
               declare
                  U : Frame := F (Chest);
               begin
                  U.O := Shoulder;
                  U := Turned (U, U.X, P.Swing (S));
                  U := Turned (U, U.Y, Out_Sign (S) * P.Spread (S));
                  F (Upper (S)) := U;
                  declare
                     Fa : Frame := U;
                  begin
                     Fa.O := Offset (U, R.Joint (Fore (S)));
                     Fa := Turned (Fa, Fa.X, P.Elbow (S));
                     F (Fore (S)) := Fa;
                     F (Hand (S)) := Fa;
                     F (Hand (S)).O := Offset (Fa, R.Joint (Hand (S)));
                  end;
               end;
            end if;
         end;

         --  the hand turned at the wrist: what it holds (along the hand's Z)
         --  swings from along the forearm to upright across it
         if P.Grip (S) > 0.0 then
            declare
               Zo : constant Vec3 := F (Hand (S)).Z;
               Zu : constant Vec3 := (0.0, 0.0, 1.0) - Zo * Zo.Z;
            begin
               if Dot (Zu, Zu) > 1.0E-4 then
                  F (Hand (S)) := Turned (F (Hand (S)), Normalize (Cross (Zo, Zu)),
                                          Float'Min (1.0, P.Grip (S)) * Pi / 2.0);
               end if;
            end;
         end if;

         declare
            Hip   : constant Vec3 := Offset (F (Pelvis), R.Joint (Thigh (S)));
            Pole  : constant Vec3 := Yaw_Frame (P.Heading, Hip).Y;     --  knees forward
            Knee, Ankle : Vec3;
            Ok    : Boolean;
         begin
            Two_Bone (Hip, P.Foot (S), Pole, R.Thigh, R.Shin, Knee, Ankle, Ok);
            F (Thigh (S)) := Along (Hip, Knee, Pole);
            F (Shin (S)) := Along (Knee, Ankle, Pole);
            F (Foot (S)) := Yaw_Frame (P.Foot_Heading (S), Ankle);
         end;
      end loop;
   end Solve;

end Castle.Poses;
