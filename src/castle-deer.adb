with Interfaces;    use Interfaces;
with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Castle.Hash;

package body Castle.Deer is

   function Scale_Of (C : Class) return Float is
     (case C is when Fawn => 0.6, when Doe => 1.0, when Young_Stag => 1.0, when Stag => 1.12);

   --  Body pixels at a doe's size, scaled to the class's.
   function S (C : Class; P : Float) return Float is (P * Scale_Of (C));
   --  A whole number of pixels, at least one.
   function Whole (C : Class; P : Float) return Float is (Float'Max (1.0, Float'Rounding (S (C, P))));

   --  The doe's proportions, in body pixels: forelegs 8 + 7 and hind legs
   --  8 + 8 to the fetlock, 2 of hoof below it; 14 from hips to shoulders.
   Fore_Upper_P : constant := 8.0;
   Fore_Lower_P : constant := 7.0;
   Hind_Upper_P : constant := 8.0;
   Hind_Lower_P : constant := 8.0;
   Hoof_P       : constant := 2.0;
   Spine_P      : constant := 14.0;
   Half_W_P     : constant := 2.0;
   Neck_P       : constant := 8.0;

   --  standing, a leg is not quite straight
   Stand_Reach : constant := 0.96;

   function Dims_Of (C : Class) return Dims is
      Fu : constant Float := Whole (C, Fore_Upper_P) * Px;
      Fl : constant Float := Whole (C, Fore_Lower_P) * Px;
      Hu : constant Float := Whole (C, Hind_Upper_P) * Px;
      Hl : constant Float := Whole (C, Hind_Lower_P) * Px;
      Ho : constant Float := Whole (C, Hoof_P) * Px;
   begin
      return (Hip_H      => (Hu + Hl) * Stand_Reach + Ho,
              Shoulder_H => (Fu + Fl) * Stand_Reach + Ho,
              Spine      => Whole (C, Spine_P) * Px,
              Half_W     => Whole (C, Half_W_P) * Px,
              Fore_Upper => Fu, Fore_Lower => Fl, Hind_Upper => Hu, Hind_Lower => Hl,
              Hoof       => Ho,
              Neck_Root  => (0.0, S (C, 2.0) * Px, S (C, 2.0) * Px),
              Neck_Len   => Whole (C, Neck_P) * Px,
              Size       => Scale_Of (C));
   end Dims_Of;

   function Bone_Of (L : Leg; Part : Positive) return Bone is
     (case L is
         when Fore_L => (case Part is when 1 => Upper_Arm_L, when 2 => Forearm_L, when others => Hand_L),
         when Fore_R => (case Part is when 1 => Upper_Arm_R, when 2 => Forearm_R, when others => Hand_R),
         when Hind_L => (case Part is when 1 => Thigh_L, when 2 => Shin_L, when others => Foot_L),
         when Hind_R => (case Part is when 1 => Thigh_R, when 2 => Shin_R, when others => Foot_R));

   ------------------------------------------------------------------ build

   type Role is (Coat, Rump, Chest_Box, Neck_Box, Head_Box, Muzzle, Ear, Tail, Upper_Leg, Lower_Leg, Hoof, Antler);

   function RGBA (R, G, B : Float) return Unsigned_32 is
      function C (V : Float) return Unsigned_32 is
        (Unsigned_32 (Integer'Max (0, Integer'Min (255, Integer (V * 255.0)))));
   begin
      return C (R) or Shift_Left (C (G), 8) or Shift_Left (C (B), 16) or Shift_Left (Unsigned_32'(255), 24);
   end RGBA;

   procedure Build (C : Class; Winter : Boolean; R : out Rig; Skin : out Skin_Pixels) is
      Count : Natural := 0;
      Roles : array (1 .. Max_Boxes) of Role := [others => Coat];

      --  A box at a doe's size in body pixels, scaled; sizes whole; Centred:
      --  kept centred on X whatever the rounding.
      procedure Add (On : Bone; Lo, Size : Vec3; What : Role; Centred : Boolean := True;
                     Taper : Float := 0.0; Round : Float := Auto_Round) is
         Sz : constant Vec3 := (Whole (C, Size.X), Whole (C, Size.Y), Whole (C, Size.Z));
         L  : Vec3 := (S (C, Lo.X), S (C, Lo.Y), S (C, Lo.Z));
      begin
         if Centred then
            L.X := -Sz.X / 2.0;
         end if;
         Count := Count + 1;
         R.Boxes (Count) := (On => On, Lo => L, Size => Sz,
                             W => Natural (Sz.X), D => Natural (Sz.Y), H => Natural (Sz.Z),
                             U => 0, V => 0, Cutout => False, Glow => False, Round => Round, Taper => Taper,
                             Round_Ends => 0.0);
         Roles (Count) := What;
      end Add;

      --  a leg's three boxes hang from its bones' joints
      procedure Leg_Boxes (L : Leg) is
         Fore : constant Boolean := Is_Fore (L);
         Up   : constant Float := (if Fore then Fore_Upper_P else Hind_Upper_P);
         Lo   : constant Float := (if Fore then Fore_Lower_P else Hind_Lower_P);
         Up_D : constant Float := (if Fore then 3.0 else 4.0);    --  the haunch is deeper than the shoulder
      begin
         Add (Bone_Of (L, 1), (0.0, -Up_D / 2.0, -Up), (2.0, Up_D, Up), Upper_Leg, Taper => Haunch_Taper);
         Add (Bone_Of (L, 2), (0.0, -0.5, -Lo), (1.0, 1.0, Lo), Lower_Leg);
         Add (Bone_Of (L, 3), (0.0, -0.5, -Hoof_P), (1.0, 2.0, Hoof_P), Hoof);
      end Leg_Boxes;

      --  the antlers on one side (Sx -1 left, +1 right), on the head bone,
      --  rising from the poll
      procedure Antlers (Sx : Float) is
         function X (P : Float) return Float is (if Sx > 0.0 then P else -P - 1.0);
      begin
         if C = Young_Stag then
            Add (Head, (X (1.0), 0.5, Neck_P + 3.0), (1.0, 1.0, 3.0), Antler, Centred => False);  --  a spike
         else
            Add (Head, (X (1.0), 0.5, Neck_P + 3.0), (1.0, 1.0, 5.0), Antler, Centred => False);  --  the beam
            Add (Head, (X (1.0), 1.5, Neck_P + 4.0), (1.0, 2.0, 1.0), Antler, Centred => False);  --  brow tine
            Add (Head, (X (2.0), 0.5, Neck_P + 7.0), (2.0, 1.0, 1.0), Antler, Centred => False);  --  out at the top
            Add (Head, (X (3.0), 0.5, Neck_P + 8.0), (1.0, 1.0, 2.0), Antler, Centred => False);  --  the crown
         end if;
      end Antlers;

      Fits : Boolean;
   begin
      R := (others => <>);
      Skin := [others => [others => 0]];

      --  the body: hindquarters on the hips, forequarters on the withers
      --  (the hindquarters reach two pixels into the forequarters and are a
      --  touch narrower, so their rounded ends leave no groove between them
      --  and no faces lie in one plane to fight)
      Add (Pelvis, (0.0, -3.0, -4.0), (6.0, 12.0, 6.0), Rump, Round => Barrel_Round);
      R.Boxes (Count).Lo.X := R.Boxes (Count).Lo.X + 0.1;
      R.Boxes (Count).Size.X := R.Boxes (Count).Size.X - 0.2;
      Add (Chest, (0.0, -7.0, -5.0), (6.0, 10.0, 8.0), Chest_Box, Round => Barrel_Round);
      Add (Pelvis, (0.0, -4.0, -2.0), (2.0, 1.0, 4.0), Tail);
      --  neck and head: the neck rises along the head bone's Z; the head and
      --  muzzle sit across its top, pointing along Y
      Add (Head, (0.0, -1.5, 0.0), (3.0, 4.0, Neck_P), Neck_Box, Taper => -Neck_Taper);
      Add (Head, (0.0, -1.0, Neck_P - 1.0), (4.0, 5.0, 4.0), Head_Box);
      Add (Head, (0.0, 4.0, Neck_P - 0.5), (2.0, 3.0, 2.0), Muzzle);
      Add (Head, (-2.5, -0.5, Neck_P + 2.0), (1.0, 1.0, 3.0), Ear, Centred => False, Taper => -0.5);
      Add (Head, (1.5, -0.5, Neck_P + 2.0), (1.0, 1.0, 3.0), Ear, Centred => False, Taper => -0.5);
      for L in Leg loop
         Leg_Boxes (L);
      end loop;
      if C in Young_Stag | Stag then
         Antlers (-1.0);
         Antlers (1.0);
      end if;

      Pack_Nets (R, Count, Fits);
      if not Fits then
         raise Program_Error with "deer skin overflow: " & C'Image;
      end if;
      R.Count := Count;
      R.Height := Dims_Of (C).Shoulder_H + S (C, Neck_P + 3.0) * Px;
      R.Hip := Dims_Of (C).Hip_H;

      --  paint: a coat with darker legs, a pale belly and rump patch, dark
      --  hooves and nose, dappled fawns, bone antlers
      declare
         type Colour is array (1 .. 3) of Float;
         Base : constant Colour :=
           (if Winter then [0.42, 0.36, 0.30] else [0.60, 0.36, 0.20]);
         Pale : constant Colour := [0.86, 0.80, 0.70];
         Dark : constant Colour := [0.16, 0.12, 0.10];
         Bone_C : constant Colour := [0.80, 0.72, 0.56];
         function Mix3 (A, B : Float; K : Positive) return Float is (A * (1.0 - B) + B * Pale (K));
      begin
         for Bi in 1 .. Count loop
            for F in Face loop
               declare
                  U0, V0, Wf, Hf : Natural;
                  Ro : constant Role := Roles (Bi);
               begin
                  Face_Rect (R.Boxes (Bi), F, U0, V0, Wf, Hf);
                  for V in 0 .. Hf - 1 loop
                     for U in 0 .. Wf - 1 loop
                        declare
                           H  : constant Float := Castle.Hash.Unit_2 (Unsigned_64 (101 + Class'Pos (C)), U0 + U, V0 + V);
                           Gr : constant Float := 1.0 + 0.12 * (H - 0.5);
                           Cl : Colour := Base;
                           --  how far down a side face this texel is (0 top, 1 bottom)
                           Down : constant Float := (if Hf > 1 then Float (V) / Float (Hf - 1) else 0.0);
                        begin
                           case Ro is
                              when Rump | Chest_Box =>
                                 if F = Neg_Z then
                                    Cl := Pale;                                     --  belly
                                 elsif F in Pos_X | Neg_X | Pos_Y | Neg_Y and then Down > 0.75 then
                                    for K in 1 .. 3 loop
                                       Cl (K) := Mix3 (Base (K), 0.5, K);           --  paler low on the flanks
                                    end loop;
                                 end if;
                                 if Ro = Rump and then F = Neg_Y and then Down > 0.15 then
                                    Cl := Pale;                                     --  the white rump patch
                                 end if;
                                 if F = Pos_Z then
                                    for K in 1 .. 3 loop
                                       Cl (K) := Base (K) * 0.85;                   --  darker along the back
                                    end loop;
                                 end if;
                                 if C = Fawn and then F in Pos_Z | Pos_X | Neg_X and then Down < 0.7
                                   and then H < 0.16
                                 then
                                    Cl := Pale;                                     --  a fawn's dapples
                                 end if;
                              when Tail =>
                                 Cl := (if F in Neg_Y | Neg_Z then Pale else Base);
                              when Neck_Box =>
                                 if F = Pos_Y then
                                    for K in 1 .. 3 loop
                                       Cl (K) := Mix3 (Base (K), 0.35, K);         --  a paler throat
                                    end loop;
                                 end if;
                              when Head_Box =>
                                 if F = Neg_Z then
                                    Cl := Pale;                                     --  under the jaw
                                 elsif F in Pos_X | Neg_X and then V = Hf / 2 and then U = Wf - 2 then
                                    Cl := Dark;                                     --  an eye
                                 end if;
                              when Muzzle =>
                                 Cl := (if F = Pos_Y and then V <= Hf / 2 then Dark
                                        elsif F = Neg_Z then Pale else Base);
                              when Ear =>
                                 Cl := (if F = Pos_Y then Pale elsif V = 0 then Dark else Base);
                              when Upper_Leg =>
                                 for K in 1 .. 3 loop
                                    Cl (K) := Base (K) * (1.0 - 0.15 * Down);
                                 end loop;
                              when Lower_Leg =>
                                 for K in 1 .. 3 loop
                                    Cl (K) := Base (K) * 0.75;
                                 end loop;
                              when Hoof =>
                                 Cl := Dark;
                              when Antler =>
                                 Cl := Bone_C;
                                 if F = Pos_Z then
                                    Cl := [0.92, 0.88, 0.78];                       --  pale tips
                                 end if;
                              when Coat =>
                                 null;
                           end case;
                           Skin (V0 + V, U0 + U) := RGBA (Cl (1) * Gr, Cl (2) * Gr, Cl (3) * Gr);
                        end;
                     end loop;
                  end loop;
               end;
            end loop;
         end loop;
      end;
   end Build;

   ------------------------------------------------------------------ solve

   function Len (V : Vec3) return Float is (Sqrt (Dot (V, V)));
   function Unit (V : Vec3; Fallback : Vec3) return Vec3 is
     (if Len (V) > 1.0E-6 then V * (1.0 / Len (V)) else Fallback);

   --  A frame on a bone running From (its joint) To its far end, its Y
   --  toward Pole: the box hangs down the frame's Z.
   function Along (From, To, Pole : Vec3) return Frame is
      Z : constant Vec3 := Unit (From - To, (0.0, 0.0, 1.0));
      Y : Vec3 := Pole - Z * Dot (Pole, Z);
   begin
      if Dot (Y, Y) < 1.0E-8 then
         Y := Cross (Z, (1.0, 0.0, 0.0));
      end if;
      Y := Unit (Y, (0.0, 1.0, 0.0));
      return (X => Cross (Y, Z), Y => Y, Z => Z, O => From);
   end Along;

   procedure Solve (D : Dims; P : Pose; F : out Frames; Reached : out Leg_Flags) is
      Up : constant Vec3 := (0.0, 0.0, 1.0);
      Fw : constant Vec3 := Unit (P.Shoulders - P.Hips, (0.0, 1.0, 0.0));
      Xr : Vec3 := Unit (Cross (Fw, Up), (1.0, 0.0, 0.0));
      Zu : Vec3;
      Flat_Fw : constant Vec3 := Unit ((Fw.X, Fw.Y, 0.0), (0.0, 1.0, 0.0));
   begin
      Reached := [others => True];
      Zu := Cross (Xr, Fw);
      if P.Roll /= 0.0 then
         Xr := Rotate (Xr, Fw, P.Roll);
         Zu := Rotate (Zu, Fw, P.Roll);
      end if;
      --  hindquarters and forequarters, pitched apart by the arch of the back
      declare
         Hy : constant Vec3 := Rotate (Fw, Xr, P.Flex);
         Hz : constant Vec3 := Rotate (Zu, Xr, P.Flex);
         Cy : constant Vec3 := Rotate (Fw, Xr, -P.Flex);
         Cz : constant Vec3 := Rotate (Zu, Xr, -P.Flex);
      begin
         F (Pelvis) := (X => Xr, Y => Hy, Z => Hz, O => P.Hips);
         F (Chest) := (X => Xr, Y => Cy, Z => Cz, O => P.Shoulders);
      end;
      --  the neck: the chest's frame turned by the yaw, then its Z tipped
      --  forward by the neck's angle
      declare
         C   : Frame renames F (Chest);
         Hx0 : constant Vec3 := Rotate (C.X, C.Z, P.Neck_Yaw);
         Hy0 : constant Vec3 := Rotate (C.Y, C.Z, P.Neck_Yaw);
         Hx  : constant Vec3 := Hx0;
         Hy  : constant Vec3 := Rotate (Hy0, Hx0, -P.Neck);
         Hz  : constant Vec3 := Rotate (C.Z, Hx0, -P.Neck);
      begin
         F (Head) := (X => Hx, Y => Hy, Z => Hz,
                      O => C.O + C.X * D.Neck_Root.X + C.Y * D.Neck_Root.Y + C.Z * D.Neck_Root.Z);
      end;
      --  the legs: two-bone IK from the hip or shoulder to the fetlock
      for L in Leg loop
         declare
            Fore  : constant Boolean := Is_Fore (L);
            Base  : constant Frame := (if Fore then F (Chest) else F (Pelvis));
            Root  : constant Vec3 := Base.O + Base.X * ((if Is_Left (L) then -1.0 else 1.0) * D.Half_W);
            A     : constant Float := (if Fore then D.Fore_Upper else D.Hind_Upper);
            B     : constant Float := (if Fore then D.Fore_Lower else D.Hind_Lower);
            --  forelegs' knees go forward, hind hocks back
            Pole  : constant Vec3 := Root + Flat_Fw * (if Fore then 1.0 else -1.0) - Up * 0.3;
            Mid, Tip : Vec3;
            Ok    : Boolean;
         begin
            Two_Bone (Root, P.Hoof (L), Pole, A, B, Mid, Tip, Ok);
            Reached (L) := Ok;
            F (Bone_Of (L, 1)) := Along (Root, Mid, Flat_Fw);
            F (Bone_Of (L, 2)) := Along (Mid, Tip, Flat_Fw);
            F (Bone_Of (L, 3)) := (X => Cross (Flat_Fw, Up), Y => Flat_Fw, Z => Up, O => Tip);
         end;
      end loop;
   end Solve;

end Castle.Deer;
