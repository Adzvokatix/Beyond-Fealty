with Interfaces;    use Interfaces;
with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Castle.Bodies; use Castle.Bodies;
with Castle.Blocks;
with Castle.Poses;  use Castle.Poses;
with Castle.Colors;
with Castle.Textures;

package body Castle.Props is

   Made     : Boolean := False;
   Basket_L : Castle.Figures.Look_Id := 1;

   function RGBA (R, G, B : Integer) return Unsigned_32 is
     (Unsigned_32 (R) or Shift_Left (Unsigned_32 (G), 8) or Shift_Left (Unsigned_32 (B), 16)
      or Shift_Left (Unsigned_32'(255), 24));

   --  A palette colour as a skin texel, brightened by Gain.
   function Hex (H : Castle.Colors.Hex_Code; Gain : Float := 1.0; Alpha : Integer := 255) return Unsigned_32 is
      C : constant Castle.Colors.RGB := Castle.Colors.Of_Hex (H);
      function G (V : Unsigned_8) return Integer is (Integer'Min (255, Integer (Float (V) * Gain)));
   begin
      return Unsigned_32 (G (C.R)) or Shift_Left (Unsigned_32 (G (C.G)), 8) or Shift_Left (Unsigned_32 (G (C.B)), 16)
        or Shift_Left (Unsigned_32 (Alpha), 24);
   end Hex;

   function Basket return Castle.Figures.Look_Id is
      R    : Rig;
      Skin : Skin_Pixels := [others => [others => 0]];
   begin
      if Made then
         return Basket_L;
      end if;
      --  (berries: the first basket, its colours as they were)
      R.Count := 2;
      R.Boxes (1) := (On => Pelvis, Lo => (-3.0, -3.0, 0.0), Size => (6.0, 6.0, 4.0),
                      W => 6, D => 6, H => 4, U => 0, V => 0, Cutout => False, Glow => False, others => <>);
      R.Boxes (2) := (On => Pelvis, Lo => (-2.5, -2.5, 4.0), Size => (5.0, 5.0, 1.0),
                      W => 5, D => 5, H => 1, U => 0, V => 10, Cutout => False, Glow => False, others => <>);
      --  wicker: the weave in alternate texels, a lighter rim along the top
      for F in Face loop
         declare
            U0, V0, Wf, Hf : Natural;
         begin
            Face_Rect (R.Boxes (1), F, U0, V0, Wf, Hf);
            for V in 0 .. Hf - 1 loop
               for U in 0 .. Wf - 1 loop
                  Skin (V0 + V, U0 + U) :=
                    (if F = Neg_Z then RGBA (92, 66, 38)
                     elsif F = Pos_Z then RGBA (70, 50, 30)
                     elsif V = 0 then RGBA (176, 140, 88)
                     elsif (U + V) mod 2 = 0 then RGBA (150, 112, 64) else RGBA (118, 86, 48));
               end loop;
            end loop;
            Face_Rect (R.Boxes (2), F, U0, V0, Wf, Hf);
            for V in 0 .. Hf - 1 loop
               for U in 0 .. Wf - 1 loop
                  declare
                     H : constant Float := Castle.Hash.Unit_2 (77, U0 + U, V0 + V);
                  begin
                     Skin (V0 + V, U0 + U) :=
                       (if H < 0.45 then RGBA (128, 26, 48)
                        elsif H < 0.75 then RGBA (92, 24, 66)
                        elsif H < 0.92 then RGBA (60, 18, 40) else RGBA (70, 104, 52));
                  end;
               end loop;
            end loop;
         end;
      end loop;
      Basket_L := Castle.Figures.New_Look (R, Skin);
      Made := True;
      return Basket_L;
   end Basket;

   Heaped   : array (Heap_Kind) of Castle.Figures.Look_Id := [others => 1];
   Heaped_Made : array (Heap_Kind) of Boolean := [others => False];

   function Basket_Of (Heap : Heap_Kind) return Castle.Figures.Look_Id is
      R    : Rig;
      Skin : Skin_Pixels := [others => [others => 0]];
   begin
      if Heap = Berry_Heap then
         return Basket;
      elsif Heaped_Made (Heap) then
         return Heaped (Heap);
      end if;
      R.Count := 2;
      R.Boxes (1) := (On => Pelvis, Lo => (-3.0, -3.0, 0.0), Size => (6.0, 6.0, 4.0),
                      W => 6, D => 6, H => 4, U => 0, V => 0, Cutout => False, Glow => False, others => <>);
      R.Boxes (2) := (On => Pelvis, Lo => (-2.5, -2.5, 4.0), Size => (5.0, 5.0, 1.0),
                      W => 5, D => 5, H => 1, U => 0, V => 10, Cutout => False, Glow => False, others => <>);
      for F in Face loop
         declare
            U0, V0, Wf, Hf : Natural;
         begin
            Face_Rect (R.Boxes (1), F, U0, V0, Wf, Hf);
            for V in 0 .. Hf - 1 loop
               for U in 0 .. Wf - 1 loop
                  Skin (V0 + V, U0 + U) :=
                    (if F = Neg_Z then RGBA (92, 66, 38)
                     elsif F = Pos_Z then RGBA (70, 50, 30)
                     elsif V = 0 then RGBA (176, 140, 88)
                     elsif (U + V) mod 2 = 0 then RGBA (150, 112, 64) else RGBA (118, 86, 48));
               end loop;
            end loop;
            Face_Rect (R.Boxes (2), F, U0, V0, Wf, Hf);
            for V in 0 .. Hf - 1 loop
               for U in 0 .. Wf - 1 loop
                  declare
                     use Castle.Colors;
                     H : constant Float := Castle.Hash.Unit_2 (79, U0 + U, V0 + V);
                  begin
                     Skin (V0 + V, U0 + U) :=
                       (case Heap is
                           when Vegetable_Heap =>      --  roots, and their greens
                              (if H < 0.3 then Hex (Warm_Copper, 1.2) elsif H < 0.5 then Hex (Salt_Pale)
                               elsif H < 0.65 then Hex (Sand_Tan, 1.2) else Hex (Sprout_Green)),
                           when Apple_Heap =>
                              (if H < 0.55 then Hex (Brightened_Crimson) elsif H < 0.8 then Hex (Heraldic_Crimson)
                               elsif H < 0.92 then Hex (Brightened_Gold) else Hex (Emerald_Lift)),
                           when Grain_Heap =>
                              (if H < 0.5 then Hex (Brightened_Gold) elsif H < 0.85 then Hex (Gilded_Amber)
                               else Hex (Sand_Tan)),
                           when Berry_Heap => 0);
                  end;
               end loop;
            end loop;
         end;
      end loop;
      Heaped (Heap) := Castle.Figures.New_Look (R, Skin);
      Heaped_Made (Heap) := True;
      return Heaped (Heap);
   end Basket_Of;

   Log_Made : Boolean := False;
   Log_L    : Castle.Figures.Look_Id := 1;

   function Log return Castle.Figures.Look_Id is
      R    : Rig;
      Skin : Skin_Pixels := [others => [others => 0]];
   begin
      if Log_Made then
         return Log_L;
      end if;
      R.Count := 1;
      R.Boxes (1) := (On => Pelvis, Lo => (-10.0, -2.0, 0.0), Size => (20.0, 4.0, 4.0),
                      W => 20, D => 4, H => 4, U => 0, V => 0, Cutout => False, Glow => False, others => <>);
      for F in Face loop
         declare
            U0, V0, Wf, Hf : Natural;
         begin
            Face_Rect (R.Boxes (1), F, U0, V0, Wf, Hf);
            for V in 0 .. Hf - 1 loop
               for U in 0 .. Wf - 1 loop
                  declare
                     H : constant Float := Castle.Hash.Unit_2 (91, U0 + U, V0 + V);
                  begin
                     if F in Pos_X | Neg_X then
                        --  end grain: a pale face, a ring round the middle, bark at the rim
                        declare
                           Rim  : constant Boolean := U = 0 or else V = 0 or else U = Wf - 1 or else V = Hf - 1;
                        begin
                           Skin (V0 + V, U0 + U) :=
                             (if Rim then RGBA (84, 60, 38)
                              elsif H < 0.5 then RGBA (196, 160, 108) else RGBA (176, 140, 92));
                        end;
                     else
                        --  bark: dark, in streaks along the log, a few lighter flecks
                        declare
                           Streak : constant Float := Castle.Hash.Unit_2 (93, (if F in Pos_Z | Neg_Z then V else U), 0);
                           Along  : constant Boolean := F in Pos_Y | Neg_Y;
                           S      : constant Float := (if Along then Castle.Hash.Unit_2 (95, V, 1) else Streak);
                        begin
                           Skin (V0 + V, U0 + U) :=
                             (if H < 0.06 then RGBA (128, 104, 76)
                              elsif S < 0.4 then RGBA (82, 60, 40)
                              elsif S < 0.75 then RGBA (98, 72, 48) else RGBA (70, 50, 34));
                        end;
                     end if;
                  end;
               end loop;
            end loop;
         end;
      end loop;
      Log_L := Castle.Figures.New_Look (R, Skin);
      Log_Made := True;
      return Log_L;
   end Log;

   --  A one-box prop: Paint gives each texel of each face its colour.
   function One_Box
     (Lo, Size : Vec3;
      Paint    : not null access function (F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32;
      Glow     : Boolean := False;
      Casts    : Boolean := True;
      Thin     : Boolean := False)
      return Castle.Figures.Look_Id
   is
      R    : Rig;
      Skin : Skin_Pixels := [others => [others => 0]];
   begin
      R.Count := 1;
      R.Boxes (1) := (On => Pelvis, Lo => Lo, Size => Size,
                      W => Natural (Size.X), D => Natural (Size.Y), H => Natural (Size.Z),
                      U => 0, V => 0, Cutout => False, Glow => Glow, others => <>);
      for F in Face loop
         declare
            U0, V0, Wf, Hf : Natural;
         begin
            Face_Rect (R.Boxes (1), F, U0, V0, Wf, Hf);
            for V in 0 .. Hf - 1 loop
               for U in 0 .. Wf - 1 loop
                  Skin (V0 + V, U0 + U) := Paint (F, U, V, Wf, Hf, Castle.Hash.Unit_2 (97, U0 + U, V0 + V));
               end loop;
            end loop;
         end;
      end loop;
      return Castle.Figures.New_Look (R, Skin, Casts, Thin);
   end One_Box;

   Sheaf_Made, Stone_Made, Bucket_Made : Boolean := False;
   Sheaf_L, Stone_L, Bucket_L : Castle.Figures.Look_Id := 1;

   function Paint_Sheaf (F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      pragma Unreferenced (V, Hf);
   begin
      if F in Pos_X | Neg_X then                    --  the cut ends of the stalks
         return (if H < 0.5 then RGBA (150, 122, 60) else RGBA (118, 92, 44));
      elsif (F in Pos_Y | Neg_Y and then U in Wf / 2 - 1 .. Wf / 2)
        or else (F in Pos_Z | Neg_Z and then U in Wf / 2 - 1 .. Wf / 2)
      then
         return RGBA (120, 84, 40);                 --  the band tying it
      else
         return (if H < 0.3 then RGBA (214, 186, 104) elsif H < 0.8 then RGBA (196, 166, 88)
                 else RGBA (170, 140, 70));
      end if;
   end Paint_Sheaf;

   function Paint_Stone (F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      pragma Unreferenced (U, V, Wf, Hf);
      Lit : constant Integer := (if F = Pos_Z then 14 else 0);
   begin
      return (if H < 0.35 then RGBA (118 + Lit, 116 + Lit, 110 + Lit)
              elsif H < 0.8 then RGBA (100 + Lit, 98 + Lit, 94 + Lit) else RGBA (84 + Lit, 82 + Lit, 80 + Lit));
   end Paint_Stone;

   function Paint_Clod (F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      pragma Unreferenced (U, V, Wf, Hf);
      use Castle.Colors;
      Gain : constant Float := (if F = Pos_Z then 1.15 else 1.0);
   begin
      return (if H < 0.3 then Hex (Ashen_Brown, Gain) elsif H < 0.75 then Hex (Mudstone, Gain)
              else Hex (Shadow_Earth, Gain));
   end Paint_Clod;

   function Paint_Bucket (F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
   begin
      if F = Pos_Z then                              --  water inside a rim of staves
         return (if U = 0 or else V = 0 or else U = Wf - 1 or else V = Hf - 1 then RGBA (110, 78, 46)
                 elsif H < 0.4 then RGBA (64, 108, 150) else RGBA (52, 92, 134));
      elsif F = Neg_Z then
         return RGBA (84, 60, 36);
      elsif V = 1 or else V = Hf - 2 then
         return RGBA (58, 58, 62);                   --  the iron bands
      else
         return (if U mod 2 = 0 then RGBA (128, 92, 54) else RGBA (110, 78, 46));   --  staves
      end if;
   end Paint_Bucket;

   Joint_Made, Hide_Made, Arrow_Made : Boolean := False;
   Joint_L, Hide_L, Arrow_L : Castle.Figures.Look_Id := 1;

   function Paint_Joint (F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      pragma Unreferenced (U, V, Wf, Hf);
   begin
      if F in Pos_Y | Neg_Y then
         return (if H < 0.3 then RGBA (196, 150, 140) else RGBA (150, 44, 40));   --  the cut: fat and lean
      end if;
      return (if H < 0.5 then RGBA (112, 40, 34) else RGBA (96, 34, 30));
   end Paint_Joint;

   function Paint_Hide (F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      pragma Unreferenced (U, V, Wf, Hf);
   begin
      if F = Pos_Z then
         return (if H < 0.5 then RGBA (150, 96, 58) else RGBA (136, 86, 50));          --  the hair side
      end if;
      return (if H < 0.5 then RGBA (214, 196, 168) else RGBA (200, 182, 152));        --  the flesh side and edges
   end Paint_Hide;

   function Paint_Arrow (F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      pragma Unreferenced (F, U, Wf, Hf, H);
   begin
      --  rows run along the shaft from its top end (the fletching, V small) to the point
      return (if V < 3 then RGBA (220, 220, 210) elsif V >= 13 then RGBA (70, 70, 74) else RGBA (150, 116, 70));
   end Paint_Arrow;

   function Joint return Castle.Figures.Look_Id is
   begin
      if not Joint_Made then
         Joint_L := One_Box ((-2.0, -1.5, 0.0), (4.0, 3.0, 3.0), Paint_Joint'Access);
         Joint_Made := True;
      end if;
      return Joint_L;
   end Joint;

   function Hide return Castle.Figures.Look_Id is
   begin
      if not Hide_Made then
         Hide_L := One_Box ((-4.0, -3.0, 0.0), (8.0, 6.0, 1.0), Paint_Hide'Access);
         Hide_Made := True;
      end if;
      return Hide_L;
   end Hide;

   function Arrow return Castle.Figures.Look_Id is
   begin
      if not Arrow_Made then
         --  along Z in its own box (so a side face's rows run down the shaft); laid
         --  along Y by the frame the game gives it
         Arrow_L := One_Box ((-0.3, -0.3, -14.0), (0.6, 0.6, 14.0), Paint_Arrow'Access);
         Arrow_Made := True;
      end if;
      return Arrow_L;
   end Arrow;

   function Sheaf return Castle.Figures.Look_Id is
   begin
      if not Sheaf_Made then
         Sheaf_L := One_Box ((-8.0, -2.5, 0.0), (16.0, 5.0, 5.0), Paint_Sheaf'Access);
         Sheaf_Made := True;
      end if;
      return Sheaf_L;
   end Sheaf;

   --  Cloaks: a folded one and a spread one of each colour asked for (the
   --  band's cloaks are of a handful of wools).
   Max_Cloaks : constant := 12;
   type Cloak_Looks is record
      C      : RGB;
      Folded : Castle.Figures.Look_Id := 1;
      Spread : Castle.Figures.Look_Id := 1;
   end record;
   Cloaks   : array (1 .. Max_Cloaks) of Cloak_Looks;
   N_Cloaks : Natural := 0;

   function Wool (C : RGB; Gain : Float) return Unsigned_32 is
      function B8 (F : Float) return Integer is (Integer (Float'Max (0.0, Float'Min (255.0, F * Gain * 255.0))));
   begin
      return RGBA (B8 (C.R), B8 (C.G), B8 (C.B));
   end Wool;

   --  A look of boxes all of one wool: woven (a little lighter and darker,
   --  texel by texel), a lighter hem along the rim of each top.
   function Wool_Look (C : RGB; R0 : Rig) return Castle.Figures.Look_Id is
      R    : Rig := R0;
      Skin : Skin_Pixels := [others => [others => 0]];
      V_At : Natural := 0;
   begin
      for K in 1 .. R.Count loop
         R.Boxes (K).W := Natural (R.Boxes (K).Size.X);
         R.Boxes (K).D := Natural (R.Boxes (K).Size.Y);
         R.Boxes (K).H := Natural (R.Boxes (K).Size.Z);
         R.Boxes (K).U := 0;
         R.Boxes (K).V := V_At;
         V_At := V_At + R.Boxes (K).D + R.Boxes (K).H;
         for F in Face loop
            declare
               U0, V0, Wf, Hf : Natural;
            begin
               Face_Rect (R.Boxes (K), F, U0, V0, Wf, Hf);
               for V in 0 .. Hf - 1 loop
                  for U in 0 .. Wf - 1 loop
                     declare
                        H   : constant Float := Castle.Hash.Unit_2 (131, U0 + U, V0 + V);
                        Hem : constant Boolean :=
                          F = Pos_Z and then (U = 0 or else V = 0 or else U = Wf - 1 or else V = Hf - 1);
                     begin
                        Skin (V0 + V, U0 + U) :=
                          Wool (C, (if Hem then 1.22 elsif F = Neg_Z then 0.8 else 0.9 + 0.2 * H));
                     end;
                  end loop;
               end loop;
            end;
         end loop;
      end loop;
      return Castle.Figures.New_Look (R, Skin, True, False);
   end Wool_Look;

   function Cloak_Slot (C : RGB) return Positive is
      Folded, Spread : Rig;
   begin
      for K in 1 .. N_Cloaks loop
         if abs (Cloaks (K).C.R - C.R) + abs (Cloaks (K).C.G - C.G) + abs (Cloaks (K).C.B - C.B) < 0.02 then
            return K;
         end if;
      end loop;
      if N_Cloaks = Max_Cloaks then
         return 1;                                   --  (more wools than there is room for: the first)
      end if;
      --  folded: three thicknesses of cloth, 45 x 30 cm
      Folded.Count := 2;
      Folded.Boxes (1) := (On => Pelvis, Lo => (-4.5, -3.0, 0.0), Size => (9.0, 6.0, 1.0), others => <>);
      Folded.Boxes (2) := (On => Pelvis, Lo => (-4.0, -3.0, 1.0), Size => (8.0, 5.0, 1.0), others => <>);
      --  spread over a sleeper on its side: over its shoulders and its
      --  body, and lower over its legs drawn up
      Spread.Count := 2;
      Spread.Boxes (1) := (On => Pelvis, Lo => (-5.0, -7.0, 0.0), Size => (18.0, 15.0, 12.0), Round => 3.0, others => <>);
      Spread.Boxes (2) := (On => Pelvis, Lo => (-14.0, -7.5, 0.0), Size => (14.0, 16.0, 11.0), Round => 3.0, others => <>);
      N_Cloaks := N_Cloaks + 1;
      Cloaks (N_Cloaks) := (C => C, Folded => Wool_Look (C, Folded), Spread => Wool_Look (C, Spread));
      return N_Cloaks;
   end Cloak_Slot;

   function Cloak_Folded (C : RGB) return Castle.Figures.Look_Id is (Cloaks (Cloak_Slot (C)).Folded);
   function Cloak_Spread (C : RGB) return Castle.Figures.Look_Id is (Cloaks (Cloak_Slot (C)).Spread);

   Pallet_Made : Boolean := False;
   Pallet_L    : Castle.Figures.Look_Id := 1;

   --  (loose straw: short stalks lying mostly along it, pale and dull, darker
   --  where they part; their cut ends at its ends)
   function Paint_Pallet (F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      pragma Unreferenced (Wf, Hf);
      Run : constant Float := Castle.Hash.Unit_2 (211, (U + 2 * (V mod 3)) / 3, V);   --  a stalk: three texels of a row
   begin
      if F in Pos_X | Neg_X then
         return (if H < 0.5 then RGBA (146, 124, 70) else RGBA (120, 100, 56));
      elsif H < 0.12 then
         return RGBA (124, 104, 58);                 --  a gap between stalks
      elsif Run < 0.3 then
         return (if H < 0.55 then RGBA (168, 146, 86) else RGBA (156, 134, 78));
      elsif Run < 0.75 then
         return (if H < 0.55 then RGBA (188, 166, 100) else RGBA (178, 156, 92));
      else
         return (if H < 0.55 then RGBA (202, 182, 116) else RGBA (194, 172, 106));
      end if;
   end Paint_Pallet;

   function Pallet return Castle.Figures.Look_Id is
   begin
      if not Pallet_Made then
         Pallet_L := One_Box ((-19.0, -8.0, 0.0), (38.0, 16.0, 2.0), Paint_Pallet'Access, Casts => False);
         Pallet_Made := True;
      end if;
      return Pallet_L;
   end Pallet;

   function Stone return Castle.Figures.Look_Id is
   begin
      if not Stone_Made then
         Stone_L := One_Box ((-2.0, -1.5, 0.0), (4.0, 3.0, 3.0), Paint_Stone'Access);
         Stone_Made := True;
      end if;
      return Stone_L;
   end Stone;

   Clod_Made : Boolean := False;
   Clod_L    : Castle.Figures.Look_Id := 1;

   function Clod return Castle.Figures.Look_Id is
   begin
      if not Clod_Made then
         Clod_L := One_Box ((-2.5, -2.5, 0.0), (5.0, 5.0, 4.0), Paint_Clod'Access);
         Clod_Made := True;
      end if;
      return Clod_L;
   end Clod;

   function Bucket return Castle.Figures.Look_Id is
   begin
      if not Bucket_Made then
         Bucket_L := One_Box ((-2.5, -2.5, 0.0), (5.0, 5.0, 5.0), Paint_Bucket'Access);
         Bucket_Made := True;
      end if;
      return Bucket_L;
   end Bucket;

   ------------------------------------------------------------------ the camp

   Seat_Made, Crossbar_Made, Pot_Made, Embers_Made, Ashes_Made : Boolean := False;
   Seat_L, Crossbar_L, Embers_L, Ashes_L : Castle.Figures.Look_Id := 1;
   Pot_L : array (Boolean) of Castle.Figures.Look_Id := [others => 1];

   function Paint_Seat (F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      use Castle.Colors;
   begin
      if F in Pos_X | Neg_X then                       --  sawn ends: pale wood, rings, bark rim
         declare
            Rim : constant Boolean := U = 0 or else V = 0 or else U = Wf - 1 or else V = Hf - 1;
            Ring : constant Boolean := (U = Wf / 2 or else V = Hf / 2) and then not Rim;
         begin
            return (if Rim then Hex (Dark_Bark)
                    elsif Ring then Hex (Sand_Tan, 0.85)
                    elsif H < 0.5 then Hex (Gilded_Amber, 0.95) else Hex (Sand_Tan, 1.15));
         end;
      elsif F = Pos_Z and then V in Hf / 2 - 1 .. Hf / 2 then   --  the top worn smooth where people sit
         return (if H < 0.5 then Hex (Weathered_Oak, 1.35) else Hex (Mudstone, 1.2));
      else
         declare
            S : constant Float := Castle.Hash.Unit_2 (131, (if F in Pos_Z | Neg_Z then V else 0) + 7 * V, 3);
         begin
            return (if H < 0.07 then Hex (Ashen_Brown, 1.3)
                    elsif S < 0.45 then Hex (Weathered_Oak) elsif S < 0.8 then Hex (Dark_Bark) else Hex (Mudstone));
         end;
      end if;
   end Paint_Seat;

   function Seat return Castle.Figures.Look_Id is
   begin
      if not Seat_Made then
         Seat_L := One_Box ((-10.0, -3.5, 0.0), (20.0, 7.0, 7.0), Paint_Seat'Access);
         Seat_Made := True;
      end if;
      return Seat_L;
   end Seat;

   --  Several boxes, each painted by Paint, in one look.
   type Box_Spec is record
      Lo, Size : Vec3;
      Glow     : Boolean := False;
      On       : Bone := Pelvis;          --  the bone it hangs on (a prop of one piece: all on the first)
      Round    : Float := Auto_Round;
      Taper    : Float := 0.0;
   end record;
   type Box_Specs is array (Positive range <>) of Box_Spec;

   --  (Fill: what the skin is where no face of a box lies.  Nothing is drawn of it close to, but far
   --  off the sampler takes in what lies round a face: left clear and black, a large flat face shows
   --  a dark rim.)
   function Many_Boxes
     (Specs : Box_Specs;
      Paint : not null access function (Box : Positive; F : Face; U, V, Wf, Hf : Natural; H : Float)
                                        return Unsigned_32;
      Fill  : Unsigned_32 := 0)
      return Castle.Figures.Look_Id
   is
      R    : Rig;
      Skin : Skin_Pixels := [others => [others => Fill]];
      U_At : Natural := 0;
      V_At : Natural := 0;
      Row_H : Natural := 0;
   begin
      R.Count := Specs'Length;
      for K in Specs'Range loop
         declare
            W : constant Natural := Natural'Max (1, Natural (Float'Ceiling (Specs (K).Size.X)));
            D : constant Natural := Natural'Max (1, Natural (Float'Ceiling (Specs (K).Size.Y)));
            Hh : constant Natural := Natural'Max (1, Natural (Float'Ceiling (Specs (K).Size.Z)));
            Net_W : constant Natural := 2 * (W + D);
            Net_H : constant Natural := Hh + 2 * D;
         begin
            if U_At + Net_W > Skin'Length (2) then          --  next row of nets
               U_At := 0;
               V_At := V_At + Row_H;
               Row_H := 0;
            end if;
            R.Boxes (K - Specs'First + 1) :=
              (On => Specs (K).On, Lo => Specs (K).Lo, Size => Specs (K).Size, W => W, D => D, H => Hh,
               U => U_At, V => V_At, Cutout => False, Glow => Specs (K).Glow,
               Round => Specs (K).Round, Taper => Specs (K).Taper, Round_Ends => 0.0);
            U_At := U_At + Net_W;
            Row_H := Natural'Max (Row_H, Net_H);
            if Net_W > Skin'Length (2) or else V_At + Row_H > Skin'Length (1) then
               raise Program_Error with "a prop's boxes do not fit one skin: make it of several looks";
            end if;
         end;
      end loop;
      for K in Specs'Range loop
         for F in Face loop
            declare
               U0, V0, Wf, Hf : Natural;
            begin
               Face_Rect (R.Boxes (K - Specs'First + 1), F, U0, V0, Wf, Hf);
               for V in 0 .. Hf - 1 loop
                  for U in 0 .. Wf - 1 loop
                     Skin (V0 + V, U0 + U) :=
                       Paint (K - Specs'First + 1, F, U, V, Wf, Hf, Castle.Hash.Unit_2 (Castle.Hash.U64 (101 + K), U0 + U, V0 + V));
                  end loop;
               end loop;
            end;
         end loop;
      end loop;
      return Castle.Figures.New_Look (R, Skin);
   end Many_Boxes;

   --  A cloth's panels in a wool: fifteen thin boxes 2 px square, each on a
   --  bone of its own, twice (a sheet has thirty)
   Tile_Px : constant := 2.0;
   Tile_Thick_Px : constant := 0.5;
   Max_Cloth_Wools : constant := 16;
   type Tile_Looks is array (1 .. 2) of Castle.Figures.Look_Id;
   Cloth_Wools : array (1 .. Max_Cloth_Wools) of RGB;
   Cloth_Tiles : array (1 .. Max_Cloth_Wools) of Tile_Looks;
   N_Cloth_Wools : Natural := 0;

   function Tiles_Of (C : RGB) return Tile_Looks is
      function Paint (Box : Positive; F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
         pragma Unreferenced (Box, U, V, Wf, Hf);
      begin
         return Wool (C, (if F = Neg_Z then 0.84 else 0.95 + 0.03 * H));
      end Paint;
      Specs : Box_Specs (1 .. 15);
   begin
      for K in 1 .. N_Cloth_Wools loop
         if abs (Cloth_Wools (K).R - C.R) + abs (Cloth_Wools (K).G - C.G) + abs (Cloth_Wools (K).B - C.B) < 0.02 then
            return Cloth_Tiles (K);
         end if;
      end loop;
      for K in Specs'Range loop
         Specs (K) := (Lo => (0.0, 0.0, 0.0), Size => (Tile_Px, Tile_Px, Tile_Thick_Px), On => Bone'Val (K - 1),
                       Round => 0.0, others => <>);
      end loop;
      declare
         T : constant Tile_Looks := [Many_Boxes (Specs, Paint'Access), Many_Boxes (Specs, Paint'Access)];
      begin
         if N_Cloth_Wools < Max_Cloth_Wools then
            N_Cloth_Wools := N_Cloth_Wools + 1;
            Cloth_Wools (N_Cloth_Wools) := C;
            Cloth_Tiles (N_Cloth_Wools) := T;
         end if;
         return T;
      end;
   end Tiles_Of;

   procedure Put_Cloth (C : Castle.Cloth.Cloth_Id; Colour : RGB;
                        Pivot : Vec3 := (0.0, 0.0, 0.0); Radians : Float := 0.0) is
      Tc : constant Float := (if Radians = 0.0 then 1.0 else Cos (Radians));
      Ts : constant Float := (if Radians = 0.0 then 0.0 else Sin (Radians));
      function Point (C : Castle.Cloth.Cloth_Id; I, J : Positive) return Vec3 is
         P : constant Vec3 := Castle.Cloth.Point (C, I, J);
      begin
         return (if Radians = 0.0 then P
                 else (Pivot.X + Tc * (P.X - Pivot.X) - Ts * (P.Y - Pivot.Y),
                       Pivot.Y + Ts * (P.X - Pivot.X) + Tc * (P.Y - Pivot.Y), P.Z));
      end Point;
      use Castle.Cloth;
      T  : constant Tile_Looks := Tiles_Of (Colour);
      Fs : array (1 .. 2) of Frames;
      K  : Natural := 0;
      Over : constant := 1.1;            --  each panel a little wider than its four points, so that none parts
      Thick : constant := 0.014;         --  metres
   begin
      for J in 1 .. Nv - 1 loop
         for I in 1 .. Nu - 1 loop
            declare
               P00 : constant Vec3 := Point (C, I, J);
               P10 : constant Vec3 := Point (C, I + 1, J);
               P01 : constant Vec3 := Point (C, I, J + 1);
               P11 : constant Vec3 := Point (C, I + 1, J + 1);
               Eu  : constant Vec3 := ((P10 - P00) + (P11 - P01)) * (0.5 * Over);
               Ev  : constant Vec3 := ((P01 - P00) + (P11 - P10)) * (0.5 * Over);
               Ctr : constant Vec3 := (P00 + P10 + P01 + P11) * 0.25;
               N   : constant Vec3 := Cross (Eu, Ev);
               Nl  : constant Float := Sqrt (Dot (N, N));
               Nz  : constant Vec3 := (if Nl > 1.0e-6 then N * (1.0 / Nl) else (0.0, 0.0, 1.0));
               X   : constant Vec3 := Eu * (1.0 / (Tile_Px * Px));
               Y   : constant Vec3 := Ev * (1.0 / (Tile_Px * Px));
               Z   : constant Vec3 := Nz * (Thick / (Tile_Thick_Px * Px));
            begin
               K := K + 1;
               Fs ((K - 1) / 15 + 1) (Bone'Val ((K - 1) mod 15)) :=
                 (X => X, Y => Y, Z => Z,
                  O => Ctr - X * (0.5 * Tile_Px * Px) - Y * (0.5 * Tile_Px * Px) - Z * (0.5 * Tile_Thick_Px * Px));
            end;
         end loop;
      end loop;
      Castle.Figures.Add (T (1), Fs (1));
      Castle.Figures.Add (T (2), Fs (2));
   end Put_Cloth;


   function Paint_Crossbar (Box : Positive; F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      pragma Unreferenced (U, Wf, Hf);
      use Castle.Colors;
   begin
      if Box = 5 then                                     --  the hook: iron
         return (if H < 0.5 then Hex (Iron) else Hex (Charcoal));
      elsif F in Pos_Z | Neg_Z and then Box /= 3 then     --  cut ends of the posts and forks
         return Hex (Sand_Tan);
      end if;
      return (if H < 0.1 then Hex (Ashen_Brown, 1.2)
              elsif (V + Box) mod 3 = 0 then Hex (Dark_Bark) else Hex (Weathered_Oak));
   end Paint_Crossbar;

   function Crossbar return Castle.Figures.Look_Id is
   begin
      if not Crossbar_Made then
         Crossbar_L := Many_Boxes
           ([(Lo => (-15.5, -0.6, 0.0), Size => (1.2, 1.2, 23.0), Glow => False, others => <>),     --  the posts, 1.5 m apart
             (Lo => (14.3, -0.6, 0.0), Size => (1.2, 1.2, 23.0), Glow => False, others => <>),
             (Lo => (-16.5, -0.5, 23.5), Size => (33.0, 1.0, 1.0), Glow => False, others => <>),   --  the bar on their forks
             (Lo => (-16.0, -0.8, 22.0), Size => (1.0, 1.6, 2.4), Glow => False, others => <>),    --  the forks
             (Lo => (-0.3, -0.3, 17.0), Size => (0.6, 0.6, 6.5), Glow => False, others => <>),     --  the hook and chain
             (Lo => (15.0, -0.8, 22.0), Size => (1.0, 1.6, 2.4), Glow => False, others => <>)],
            Paint_Crossbar'Access);
         Crossbar_Made := True;
      end if;
      return Crossbar_L;
   end Crossbar;

   Pot_Full_Now : Boolean := False;   --  which pot Paint_Pot paints

   function Paint_Pot (Box : Positive; F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      pragma Unreferenced (Wf);
      use Castle.Colors;
   begin
      if Box = 2 then                                     --  the bail: a band of iron
         return Hex (Iron, 0.9);
      elsif Box = 3 then                                  --  the rim
         return (if H < 0.5 then Hex (Iron, 1.1) else Hex (Charcoal, 1.2));
      elsif F = Pos_Z then                                --  inside: stew, or the dark iron bottom
         if not Pot_Full_Now then
            return Hex (Charcoal, 0.7);
         end if;
         return (if H < 0.12 then Hex (Forest_Gold_Green, 1.2)
                 elsif H < 0.22 then Hex (Heraldic_Crimson)
                 elsif H < 0.3 then Hex (Gilded_Amber)
                 elsif H < 0.7 then Hex (Copper_Brown) else Hex (Warm_Umber));
      elsif F = Neg_Z then
         return Hex (Ash_Stone, 0.6);                     --  sooted
      end if;
      --  the sides: cast iron, sooty toward the bottom, a seam of rivets
      return (if V >= Hf - 2 then Hex (Ash_Stone, 0.7)
              elsif V = 1 and then U mod 2 = 0 then Hex (Silvered_Steel, 0.9)
              elsif H < 0.5 then Hex (Charcoal) else Hex (Ash_Stone));
   end Paint_Pot;

   function Pot (Full : Boolean) return Castle.Figures.Look_Id is
   begin
      if not Pot_Made then
         for B in Boolean loop
            Pot_Full_Now := B;
            Pot_L (B) := Many_Boxes
              ([(Lo => (-3.5, -3.5, 0.0), Size => (7.0, 7.0, 5.0), Glow => False, others => <>),      --  the belly
                (Lo => (-0.25, -3.2, 5.0), Size => (0.5, 6.4, 2.0), Glow => False, others => <>),    --  the bail, up to the hook
                (Lo => (-3.7, -3.7, 5.0), Size => (7.4, 7.4, 0.6), Glow => False, others => <>)],    --  the rim
               Paint_Pot'Access);
         end loop;
         Pot_Made := True;
      end if;
      return Pot_L (Full);
   end Pot;

   --  The pieces a fire is drawn from: one small cube each, in the colours
   --  of a flame from its heart to its tips, and of smoke.
   Bit_Px     : constant := Bit_M / 0.05;      --  body pixels on a side
   Flame_Made : array (Flame_Heat) of Boolean := [others => False];
   Flame_L    : array (Flame_Heat) of Castle.Figures.Look_Id := [others => 1];
   Smoke_Made : array (Smoke_Shade) of Boolean := [others => False];
   Smoke_L    : array (Smoke_Shade) of Castle.Figures.Look_Id := [others => 1];
   Heat_Now   : Flame_Heat := 1;               --  which piece Paint_Flame_Bit paints
   Shade_Now  : Smoke_Shade := 1;

   function Paint_Flame_Bit (F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      pragma Unreferenced (F, U, V, Wf, Hf);
      use Castle.Colors;
   begin
      return (case Heat_Now is
                 when 1 => (if H < 0.5 then Hex (Flame_Core, 1.15) else Hex (Flame_Core)),
                 when 2 => (if H < 0.5 then Hex (Flame_Core) else Hex (Aged_Gold, 1.25)),
                 when 3 => (if H < 0.35 then Hex (Aged_Gold, 1.25) else Hex (Flame_Edge)),
                 when 4 => (if H < 0.5 then Hex (Flame_Edge, 0.95) else Hex (Ember_Glow)),
                 when 5 => (if H < 0.5 then Hex (Ember_Glow, 0.8) else Hex (Ember_Glow, 0.6)));
   end Paint_Flame_Bit;

   function Flame_Bit (Heat : Flame_Heat) return Castle.Figures.Look_Id is
   begin
      if not Flame_Made (Heat) then
         Heat_Now := Heat;
         Flame_L (Heat) := One_Box ((-0.5 * Bit_Px, -0.5 * Bit_Px, 0.0), (Bit_Px, Bit_Px, Bit_Px),
                                    Paint_Flame_Bit'Access, Glow => True);
         Flame_Made (Heat) := True;
      end if;
      return Flame_L (Heat);
   end Flame_Bit;

   function Paint_Smoke_Bit (F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      pragma Unreferenced (F, U, V, Wf, Hf);
      use Castle.Colors;
   begin
      return (case Shade_Now is
                 when 1 => (if H < 0.5 then Hex (Fog_Gray) else Hex (Fog_Gray, 1.15)),
                 when 2 => (if H < 0.5 then Hex (Silvered_Steel) else Hex (Silvered_Steel, 1.2)),
                 when 3 => (if H < 0.5 then Hex (Salt_Pale, 0.85) else Hex (Salt_Pale)));
   end Paint_Smoke_Bit;

   function Smoke_Bit (Shade : Smoke_Shade) return Castle.Figures.Look_Id is
   begin
      if not Smoke_Made (Shade) then
         Shade_Now := Shade;
         Smoke_L (Shade) := One_Box ((-0.5 * Bit_Px, -0.5 * Bit_Px, 0.0), (Bit_Px, Bit_Px, Bit_Px),
                                     Paint_Smoke_Bit'Access, Casts => False, Thin => True);
         Smoke_Made (Shade) := True;
      end if;
      return Smoke_L (Shade);
   end Smoke_Bit;

   function Paint_Embers (Box : Positive; F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      pragma Unreferenced (U, V, Wf, Hf);
      use Castle.Colors;
   begin
      if Box = 1 then                                     --  the bed of coals
         return (if F /= Pos_Z then Hex (Charcoal, 0.8)
                 elsif H < 0.3 then Hex (Ember_Glow, 1.0) elsif H < 0.5 then Hex (Flame_Edge, 0.9)
                 elsif H < 0.8 then Hex (Charcoal) else Hex (Ash_Stone, 1.4));
      end if;
      --  charred sticks across it, glowing in places
      return (if H < 0.15 then Hex (Ember_Glow, 0.9) elsif H < 0.6 then Hex (Charcoal) else Hex (Dark_Bark, 0.7));
   end Paint_Embers;

   --  The bed and the sticks across it; Lit: the coals glow.
   function Bed_Boxes (Lit : Boolean) return Box_Specs is
     ([(Lo => (-4.0, -4.0, 0.0), Size => (8.0, 8.0, 0.6), Glow => Lit, others => <>),    --  the coals, or the ash
       (Lo => (-4.0, -0.6, 0.6), Size => (8.0, 1.2, 1.2), Glow => False, others => <>),
       (Lo => (-0.6, -4.0, 1.4), Size => (1.2, 8.0, 1.2), Glow => False, others => <>),
       (Lo => (-3.0, -3.0, 0.6), Size => (6.0, 1.0, 1.0), Glow => False, others => <>)]);

   function Embers return Castle.Figures.Look_Id is
   begin
      if not Embers_Made then
         Embers_L := Many_Boxes (Bed_Boxes (Lit => True), Paint_Embers'Access);
         Embers_Made := True;
      end if;
      return Embers_L;
   end Embers;

   function Paint_Ashes (Box : Positive; F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      pragma Unreferenced (U, V, Wf, Hf);
      use Castle.Colors;
   begin
      if Box = 1 then                                     --  grey ash, a few dead coals in it
         return (if F /= Pos_Z then Hex (Charcoal, 0.8)
                 elsif H < 0.35 then Hex (Fog_Gray, 1.2) elsif H < 0.7 then Hex (Stone_Gray) else Hex (Charcoal));
      end if;
      return (if H < 0.5 then Hex (Charcoal) elsif H < 0.85 then Hex (Dark_Bark, 0.7) else Hex (Stone_Gray, 0.9));
   end Paint_Ashes;

   function Ashes return Castle.Figures.Look_Id is
   begin
      if not Ashes_Made then
         Ashes_L := Many_Boxes (Bed_Boxes (Lit => False), Paint_Ashes'Access);
         Ashes_Made := True;
      end if;
      return Ashes_L;
   end Ashes;

   ------------------------------------------------------------------ tools

   Axe_Made, Bow_Made : Boolean := False;
   Axe_L, Bow_L : Castle.Figures.Look_Id := 1;

   function Paint_Axe (Box : Positive; F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      pragma Unreferenced (U, Wf, Hf);
      use Castle.Colors;
   begin
      case Box is
         when 1 =>                                        --  the haft: ash, worn pale where it is held
            return (if V >= 8 then Hex (Copper_Brown, (if H < 0.5 then 1.1 else 1.25))
                    elsif H < 0.25 then Hex (Warm_Umber, 0.9) else Hex (Copper_Brown, 0.95));
         when 2 =>                                        --  the poll and the eye
            return (if H < 0.5 then Hex (Iron) else Hex (Iron, 1.2));
         when others =>                                   --  the bit, bright along its edge
            return (if F = Pos_Y then Hex (Salt_Pale)
                    elsif H < 0.5 then Hex (Silvered_Steel, 0.85) else Hex (Silvered_Steel));
      end case;
   end Paint_Axe;

   function Axe return Castle.Figures.Look_Id is
   begin
      if not Axe_Made then
         Axe_L := Many_Boxes
           ([(Lo => (-0.45, -0.55, 0.0), Size => (0.9, 1.1, 11.0), Taper => -0.15, others => <>),   --  the haft
             (Lo => (-0.7, -1.1, 8.4), Size => (1.4, 2.0, 2.4), others => <>),                      --  the poll and eye
             (Lo => (-0.4, 0.7, 7.9), Size => (0.8, 2.7, 3.4), Round => 0.15, others => <>)],       --  the bit
            Paint_Axe'Access);
         Axe_Made := True;
      end if;
      return Axe_L;
   end Axe;

   Quiver_Made : Boolean := False;
   Quiver_L    : Castle.Figures.Look_Id := 1;

   function Paint_Quiver (Box : Positive; F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      pragma Unreferenced (U, Wf);
      use Castle.Colors;
   begin
      case Box is
         when 1 =>                                        --  the tube: leather, a seam of stitches down it
            return (if F = Neg_Y and then V mod 2 = 0 then Hex (Warm_Umber, 0.8)
                    elsif H < 0.3 then Hex (Aged_Leather, 0.9) else Hex (Aged_Leather, 1.05));
         when 2 =>                                        --  the band round its mouth
            return (if H < 0.5 then Hex (Warm_Umber, 0.85) else Hex (Warm_Umber));
         when others =>                                   --  an arrow's end: the shaft, the fletching, the nock
            if F in Pos_Z | Neg_Z then
               return Hex (Copper_Brown, 1.2);
            end if;
            return (if V = 0 then Hex (Copper_Brown, 1.2)
                    elsif V + 2 >= Hf then RGBA (150, 116, 70)
                    elsif Box mod 2 = 0 then RGBA (220, 220, 210) else RGBA (196, 198, 190));
      end case;
   end Paint_Quiver;

   function Quiver return Castle.Figures.Look_Id is
   begin
      if not Quiver_Made then
         Quiver_L := Many_Boxes
           ([(Lo => (-1.1, -1.1, 0.0), Size => (2.2, 2.2, 8.0), Taper => -0.22, Round => 0.8, others => <>),    --  the tube
             (Lo => (-1.3, -1.3, 6.8), Size => (2.6, 2.6, 1.2), Round => 0.8, others => <>),                    --  the band
             (Lo => (-0.85, -0.75, 7.0), Size => (0.6, 0.6, 5.0), Round => 0.0, others => <>),                  --  four arrows
             (Lo => (0.30, -0.55, 7.0), Size => (0.6, 0.6, 5.6), Round => 0.0, others => <>),
             (Lo => (-0.55, 0.25, 7.0), Size => (0.6, 0.6, 6.0), Round => 0.0, others => <>),
             (Lo => (0.35, 0.40, 7.0), Size => (0.6, 0.6, 4.6), Round => 0.0, others => <>)],
            Paint_Quiver'Access);
         Quiver_Made := True;
      end if;
      return Quiver_L;
   end Quiver;

   procedure Put_In (L : Castle.Figures.Look_Id; F : Frame) is
   begin
      Castle.Figures.Add (L, [others => F]);
   end Put_In;

   --  The bow: a grip, four pieces to a limb, each turned a little further
   --  toward the string than the one before, and the string in two halves
   --  from the tips to where it is held.
   Bow_Grip_M   : constant := 0.12;
   Bow_Piece_M  : constant := 0.12;
   Bow_Pieces   : constant := 4;
   Bow_Bend     : constant array (1 .. Bow_Pieces) of Float := [0.10, 0.24, 0.40, 0.58];
   --  each piece's turn from the grip's line at rest (rad); drawn, they grow by
   Bow_Flex     : constant := 0.55;
   String_M     : constant := 0.5;                        --  the length a half of the string is made at
   Bow_Limb     : constant array (Boolean, 1 .. Bow_Pieces) of Bone :=
     [True  => [Chest, Head, Upper_Arm_L, Forearm_L],     --  the upper limb, from the grip out
      False => [Hand_L, Upper_Arm_R, Forearm_R, Hand_R]];
   Bow_String   : constant array (Boolean) of Bone := [True => Thigh_L, False => Shin_L];

   function Paint_Bow (Box : Positive; F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      pragma Unreferenced (U, Wf, Hf);
      use Castle.Colors;
   begin
      if Box = 1 then                                     --  the grip, bound in leather
         return (if V mod 2 = 0 then Hex (Aged_Leather) else Hex (Dark_Bark, 1.2));
      elsif Box >= 10 then                                --  the string: flax
         return Hex (Sand_Tan, (if H < 0.5 then 1.5 else 1.65));
      elsif (Box = 5 or else Box = 9) and then V = 0 then --  the horn nocks at the tips
         return Hex (Salt_Pale, 0.8);
      end if;
      --  yew: pale sapwood on the back, the heartwood darker on the belly
      return (if F = Pos_Y then Hex (Gilded_Amber, (if H < 0.5 then 0.85 else 0.95))
              elsif F = Neg_Y then Hex (Warm_Umber, (if H < 0.5 then 0.8 else 0.9))
              else Hex (Copper_Brown, (if H < 0.5 then 0.85 else 0.95)));
   end Paint_Bow;

   function Bow return Castle.Figures.Look_Id is
      Wide : constant array (1 .. Bow_Pieces) of Float := [1.0, 0.95, 0.85, 0.7];    --  across the limb
      Deep : constant array (1 .. Bow_Pieces) of Float := [0.85, 0.75, 0.65, 0.55];  --  back to belly
      Long : constant Float := Bow_Piece_M / Px + 0.35;   --  each piece reaches a little into the next
      Specs : Box_Specs (1 .. 3 + 2 * Bow_Pieces);
   begin
      if not Bow_Made then
         Specs (1) := (Lo => (-0.6, -0.6, -0.5 * Bow_Grip_M / Px), Size => (1.2, 1.2, Bow_Grip_M / Px),
                       others => <>);
         for Up in Boolean loop
            for I in 1 .. Bow_Pieces loop
               Specs (1 + (if Up then 0 else Bow_Pieces) + I) :=
                 (Lo => (-0.5 * Wide (I), -0.5 * Deep (I), -0.2), Size => (Wide (I), Deep (I), Long),
                  On => Bow_Limb (Up, I), Taper => -0.12, others => <>);
            end loop;
         end loop;
         for Up in Boolean loop
            Specs (2 * Bow_Pieces + (if Up then 2 else 3)) :=
              (Lo => (-0.15, -0.15, 0.0), Size => (0.3, 0.3, String_M / Px), On => Bow_String (Up),
               Round => 0.1, others => <>);
         end loop;
         Bow_L := Many_Boxes (Specs, Paint_Bow'Access);
         Bow_Made := True;
      end if;
      return Bow_L;
   end Bow;

   --  The frames of a limb's pieces, the bow bent Bend times its rest (1: at
   --  rest), and where its tip comes to.
   procedure Bow_Limb_Frames (Grip : Frame; Up : Boolean; Bend : Float; Fs : in out Frames; Tip : out Vec3) is
      S  : constant Float := (if Up then 1.0 else -1.0);
      Here : Vec3 := Grip.O + Grip.Z * (S * 0.5 * Bow_Grip_M);
   begin
      for I in 1 .. Bow_Pieces loop
         declare
            A : constant Float := Bow_Bend (I) * Bend;
            Z : constant Vec3 := Grip.Z * (S * Cos (A)) - Grip.Y * Sin (A);
            X : constant Vec3 := Grip.X * S;
         begin
            Fs (Bow_Limb (Up, I)) := (X => X, Y => Cross (Z, X), Z => Z, O => Here);
            Here := Here + Z * Bow_Piece_M;
         end;
      end loop;
      Tip := Here;
   end Bow_Limb_Frames;

   function Bow_Rest (Grip : Frame) return Vec3 is
      Fs : Frames := [others => Grip];
      A, B : Vec3;
   begin
      Bow_Limb_Frames (Grip, True, 1.0, Fs, A);
      Bow_Limb_Frames (Grip, False, 1.0, Fs, B);
      return (A + B) * 0.5;
   end Bow_Rest;

   procedure Put_Bow (Grip : Frame; Held : Boolean := False; Nock : Vec3 := (0.0, 0.0, 0.0)) is
      Fs   : Frames := [others => Grip];
      Rest : constant Vec3 := Bow_Rest (Grip);
      Back : constant Float := (if Held then Float'Max (0.0, Dot (Rest - Nock, Grip.Y)) else 0.0);
      Bend : constant Float := 1.0 + Bow_Flex * Float'Min (1.0, Back / Bow_Draw_M);
      Tip  : array (Boolean) of Vec3;
   begin
      for Up in Boolean loop
         Bow_Limb_Frames (Grip, Up, Bend, Fs, Tip (Up));
      end loop;
      declare
         Mid : constant Vec3 := (if Held then Nock else (Tip (True) + Tip (False)) * 0.5);
      begin
         for Up in Boolean loop
            declare
               D  : constant Vec3 := Mid - Tip (Up);
               L  : constant Float := Float'Max (1.0E-4, Sqrt (Dot (D, D)));
               Zu : constant Vec3 := D * (1.0 / L);
               X0 : constant Vec3 := Grip.X - Zu * Dot (Grip.X, Zu);
               X  : constant Vec3 := X0 * (1.0 / Float'Max (1.0E-4, Sqrt (Dot (X0, X0))));
            begin
               --  (its Z is as long as the half is, against the length it was made at)
               Fs (Bow_String (Up)) := (X => X, Y => Cross (Zu, X), Z => D * (1.0 / String_M), O => Tip (Up));
            end;
         end loop;
      end;
      Castle.Figures.Add (Bow, Fs);
   end Put_Bow;

   procedure Put_Scaled (L : Castle.Figures.Look_Id; Ground : Vec3; Turn : Float; Wide, Tall, Lean_X : Float) is
      Xa : constant Vec3 := (Cos (Turn), Sin (Turn), 0.0);
      F  : constant Frame := (X => Xa * Wide, Y => (-Sin (Turn) * Wide, Cos (Turn) * Wide, 0.0),
                              Z => (Xa.X * Lean_X * Tall, Xa.Y * Lean_X * Tall, Tall), O => Ground);
   begin
      Castle.Figures.Add (L, [others => F]);
   end Put_Scaled;

   ------------------------------------------------------------------ the lord's cart

   --  A skin is 128 by 64 texels and a box's net 2 (W + D) by H + 2 D of
   --  them, so the cart is several looks of a few boxes each, long boxes
   --  lying along X, put together by Put_Cart.
   Cart_Made, Wheel_Made, Sack_Made : Boolean := False;
   Bed_L, Side_L, End_L, Shafts_L, Prop_L, Wheel_L, Sack_L : Castle.Figures.Look_Id := 1;

   --  boards: uneven grain, a darker line between two of them
   function Board (H : Float; Line : Boolean) return Unsigned_32 is
      use Castle.Colors;
   begin
      return (if Line then Hex (Dark_Bark, 0.85)
              elsif H < 0.15 then Hex (Mudstone, 1.1) elsif H < 0.6 then Hex (Weathered_Oak, 1.12)
              else Hex (Weathered_Oak, 1.28));
   end Board;

   function Paint_Bed (Box : Positive; F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      pragma Unreferenced (Box, F, V, Wf, Hf);
   begin
      return Board (H, U mod 4 = 0);                      --  laid across the cart
   end Paint_Bed;

   --  a side or an end: two boards one over the other, a post at one end of
   --  it (box 2), and under an end its axle (box 3)
   function Paint_Side (Box : Positive; F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      pragma Unreferenced (U, Wf);
      use Castle.Colors;
   begin
      if Box = 3 then                                     --  the axle: dark, greased
         return (if H < 0.5 then Hex (Dark_Bark, 0.8) else Hex (Charcoal, 1.2));
      elsif Box = 2 then                                  --  the post: its top sawn pale
         return (if F = Pos_Z then Hex (Sand_Tan, 0.9) elsif H < 0.5 then Hex (Weathered_Oak) else Hex (Dark_Bark, 1.1));
      end if;
      return Board (H, F not in Pos_Z | Neg_Z and then V = Hf / 2);
   end Paint_Side;

   function Paint_Shafts (Box : Positive; F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      pragma Unreferenced (Box, F, U, V, Wf, Hf);
      use Castle.Colors;
   begin
      return (if H < 0.3 then Hex (Dark_Bark, 1.1) else Hex (Weathered_Oak));
   end Paint_Shafts;

   --  A wheel is three slabs that make a stepped round (18 px across), and
   --  a hub.  On its two faces: the tyre on the rim, the felloes inside it,
   --  eight spokes to the hub.
   Wheel_Lo : constant array (1 .. 4) of Vec3 :=
     [(-9.0, -1.0, 5.0), (-5.0, -1.0, 0.0), (-7.5, -1.05, 1.5), (-1.5, -1.8, 7.5)];
   Wheel_Size : constant array (1 .. 4) of Vec3 :=
     [(18.0, 2.0, 8.0), (10.0, 2.0, 18.0), (15.0, 2.1, 15.0), (3.0, 3.6, 3.0)];

   function Paint_Wheel (Box : Positive; F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      pragma Unreferenced (Wf, Hf);
      use Castle.Colors;
   begin
      if Box = 4 then                                     --  the hub
         return (if F in Pos_Y | Neg_Y then Hex (Iron, 0.9) elsif H < 0.5 then Hex (Dark_Bark) else Hex (Weathered_Oak, 0.9));
      elsif F not in Pos_Y | Neg_Y then                   --  the tread: the iron tyre
         return (if H < 0.5 then Hex (Iron, 0.8) else Hex (Charcoal, 1.3));
      end if;
      declare
         --  where this texel is on the wheel, from its middle (pixels; a face's V runs down from its top)
         X : constant Float := Wheel_Lo (Box).X + Float (U) + 0.5;
         Z : constant Float := Wheel_Lo (Box).Z + Wheel_Size (Box).Z - Float (V) - 0.5 - 9.0;
         R : constant Float := Sqrt (X * X + Z * Z);
         On_Spoke : constant Boolean :=
           abs X < 0.8 or else abs Z < 0.8 or else abs (abs X - abs Z) < 0.8;
      begin
         return (if R > 8.1 then Hex (Iron, 0.8)
                 elsif R > 6.2 then (if H < 0.5 then Hex (Weathered_Oak) else Hex (Dark_Bark, 1.15))
                 elsif R < 2.0 then Hex (Dark_Bark)
                 elsif On_Spoke then Hex (Weathered_Oak, 1.2)
                 else Hex (Shadow_Earth, 0.55));           --  between the spokes: the dark under the cart
      end;
   end Paint_Wheel;

   function Wheel return Castle.Figures.Look_Id is
   begin
      if not Wheel_Made then
         Wheel_L := Many_Boxes
           ([(Lo => Wheel_Lo (1), Size => Wheel_Size (1), Round => 0.6, others => <>),
             (Lo => Wheel_Lo (2), Size => Wheel_Size (2), Round => 0.6, others => <>),
             (Lo => Wheel_Lo (3), Size => Wheel_Size (3), Round => 0.6, others => <>),
             (Lo => Wheel_Lo (4), Size => Wheel_Size (4), others => <>)],
            Paint_Wheel'Access);
         Wheel_Made := True;
      end if;
      return Wheel_L;
   end Wheel;

   function Paint_Sack (Box : Positive; F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      pragma Unreferenced (F, Wf, Hf);
      use Castle.Colors;
   begin
      if Box = 2 then                                     --  its neck, tied with cord
         return (if U = 0 then Hex (Dark_Bark) elsif H < 0.5 then Hex (Sand_Tan, 0.9) else Hex (Sand_Tan, 1.05));
      end if;
      return (if (U + 2 * V) mod 5 = 0 then Hex (Sand_Tan, 0.85)       --  coarse cloth, a seam, salt showing pale
              elsif H < 0.08 then Hex (Salt_Pale)
              elsif H < 0.5 then Hex (Sand_Tan) else Hex (Sand_Tan, 1.12));
   end Paint_Sack;

   function Sack return Castle.Figures.Look_Id is
   begin
      if not Sack_Made then
         Sack_L := Many_Boxes
           ([(Lo => (-6.0, -3.5, 0.0), Size => (11.0, 7.0, 5.0), Round => 2.2, others => <>),
             (Lo => (4.6, -1.3, 1.3), Size => (2.4, 2.6, 2.6), Round => 0.8, others => <>)],
            Paint_Sack'Access);
         Sack_Made := True;
      end if;
      return Sack_L;
   end Sack;

   Barrel_Made : array (Boolean) of Boolean := [others => False];
   Barrel_L    : array (Boolean) of Castle.Figures.Look_Id := [others => 1];
   Shelf_Made  : Boolean := False;
   Shelf_L     : Castle.Figures.Look_Id := 1;

   function Paint_Barrel_Shut (Box : Positive; F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      pragma Unreferenced (Box);
      use Castle.Colors;
   begin
      if F = Pos_Z then                                   --  the lid: boards across, a rim
         return (if U = 0 or else V = 0 or else U = Wf - 1 or else V = Hf - 1 then Hex (Dark_Bark)
                 elsif V mod 3 = 0 then Hex (Weathered_Oak, 0.85) else Hex (Weathered_Oak, (if H < 0.5 then 1.0 else 1.08)));
      elsif F = Neg_Z then
         return Hex (Dark_Bark);
      elsif V in 2 | 3 or else V = Hf / 2 or else V in Hf - 4 | Hf - 3 then
         return Hex (Iron, (if H < 0.5 then 0.8 else 0.9));          --  the hoops
      else
         return (if U mod 3 = 0 then Hex (Dark_Bark, 1.2) else Hex (Weathered_Oak, (if H < 0.5 then 0.95 else 1.05)));
      end if;
   end Paint_Barrel_Shut;

   function Paint_Barrel_Water (Box : Positive; F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
   begin
      if F = Pos_Z then                                   --  open: water inside a rim of staves
         return (if U = 0 or else V = 0 or else U = Wf - 1 or else V = Hf - 1 then RGBA (110, 78, 46)
                 elsif H < 0.4 then RGBA (64, 108, 150) else RGBA (52, 92, 134));
      end if;
      return Paint_Barrel_Shut (Box, F, U, V, Wf, Hf, H);
   end Paint_Barrel_Water;

   function Barrel (Water : Boolean) return Castle.Figures.Look_Id is
   begin
      if not Barrel_Made (Water) then
         Barrel_L (Water) :=
           Many_Boxes ([(Lo => (-5.5, -5.5, 0.0), Size => (11.0, 11.0, 16.0), Round => 3.0, others => <>)],
                       (if Water then Paint_Barrel_Water'Access else Paint_Barrel_Shut'Access));
         Barrel_Made (Water) := True;
      end if;
      return Barrel_L (Water);
   end Barrel;

   function Paint_Shelf (Box : Positive; F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      pragma Unreferenced (V, Wf, Hf);
      use Castle.Colors;
   begin
      if Box <= 4 then                                    --  a post
         return Hex (Weathered_Oak, (if H < 0.5 then 0.75 else 0.85));
      end if;
      return (if F in Pos_Z | Neg_Z and then U mod 7 = 0 then Hex (Weathered_Oak, 0.8)   --  a board's planks
              else Hex (Weathered_Oak, (if H < 0.5 then 1.0 else 1.1)));
   end Paint_Shelf;

   function Shelf return Castle.Figures.Look_Id is
   begin
      if not Shelf_Made then
         Shelf_L := Many_Boxes
           ([(Lo => (-10.0, 0.0, 0.0), Size => (1.4, 1.4, 30.0), Round => 0.3, others => <>),
             (Lo => (8.6, 0.0, 0.0), Size => (1.4, 1.4, 30.0), Round => 0.3, others => <>),
             (Lo => (-10.0, 6.6, 0.0), Size => (1.4, 1.4, 30.0), Round => 0.3, others => <>),
             (Lo => (8.6, 6.6, 0.0), Size => (1.4, 1.4, 30.0), Round => 0.3, others => <>),
             (Lo => (-10.0, 0.0, 4.0), Size => (20.0, 8.0, 1.0), Round => 0.2, others => <>),
             (Lo => (-10.0, 0.0, 14.0), Size => (20.0, 8.0, 1.0), Round => 0.2, others => <>),
             (Lo => (-10.0, 0.0, 24.0), Size => (20.0, 8.0, 1.0), Round => 0.2, others => <>)],
            Paint_Shelf'Access);
         Shelf_Made := True;
      end if;
      return Shelf_L;
   end Shelf;

   procedure Put_Cart (Ground : Vec3; Turn : Float; Sacks : Natural; Towed : Boolean := False; Roll : Float := 0.0) is
      Ct : constant Float := Cos (Turn);
      St : constant Float := Sin (Turn);
      Pi : constant := Ada.Numerics.Pi;
      function At_Cart (A, Bb, Up : Float) return Vec3 is (Ground + (A * Ct - Bb * St, A * St + Bb * Ct, Up));
   begin
      if not Cart_Made then
         --  the bed's boards, over the slab (its top at 15 px)
         Bed_L := Many_Boxes ([(Lo => (-20.3, -10.3, 15.0), Size => (40.6, 20.6, 0.5), Round => 0.0, others => <>)],
                              Paint_Bed'Access);
         --  a side: its boards along X at the look's -Y edge, a post at its -X end
         Side_L := Many_Boxes
           ([(Lo => (-20.8, -11.0, 9.6), Size => (41.6, 0.8, 11.4), Round => 0.2, others => <>),
             (Lo => (-21.2, -11.4, 9.6), Size => (1.6, 1.6, 13.4), others => <>)],
            Paint_Side'Access);
         --  an end, as it lies turned a quarter: its boards along X at the look's -Y edge (the cart's
         --  end), a post at its -X end, and its axle 7 px in from it, under the bed
         End_L := Many_Boxes
           ([(Lo => (-10.6, -20.9, 9.6), Size => (21.2, 0.8, 11.4), Round => 0.2, others => <>),
             (Lo => (9.8, -21.2, 9.6), Size => (1.6, 1.6, 13.4), others => <>),
             (Lo => (-12.6, -13.8, 8.0), Size => (25.2, 1.6, 1.6), others => <>)],
            Paint_Side'Access);
         --  the shafts out of its front end, the bar across them, the prop they rest on
         Shafts_L := Many_Boxes
           ([(Lo => (20.6, -7.4, 9.0), Size => (26.0, 1.4, 1.4), others => <>),
             (Lo => (20.6, 6.0, 9.0), Size => (26.0, 1.4, 1.4), others => <>),
             (Lo => (45.0, -7.4, 9.0), Size => (1.4, 14.8, 1.4), others => <>)],
            Paint_Shafts'Access);
         Prop_L := Many_Boxes ([(Lo => (44.0, -0.6, 0.0), Size => (1.2, 1.2, 9.2), others => <>)], Paint_Shafts'Access);
         Cart_Made := True;
      end if;
      Put (Bed_L, Ground, Turn);
      Put (Side_L, Ground, Turn);
      Put (Side_L, Ground, Turn + Pi);
      Put (End_L, Ground, Turn + Pi / 2.0);
      Put (End_L, Ground, Turn - Pi / 2.0);
      Put (Shafts_L, Ground, Turn);
      if not Towed then
         Put (Prop_L, Ground, Turn);
      end if;
      for Ax in 0 .. 1 loop
         for Side in 0 .. 1 loop
            --  (turned by Roll about its axle, its top going the way the shafts point: the look
            --  stands on its ground point, its hub Wheel_Hub_M over it)
            declare
               Hub : constant Vec3 := At_Cart ((if Ax = 0 then -Cart_Axle_M else Cart_Axle_M),
                                               (if Side = 0 then -Cart_Track_M else Cart_Track_M), Wheel_Hub_M);
               Fx  : constant Vec3 := (Ct, St, 0.0);
               Up  : constant Vec3 := (0.0, 0.0, 1.0);
               Zr  : constant Vec3 := Up * Cos (Roll) + Fx * Sin (Roll);
               F   : constant Frame := (X => Fx * Cos (Roll) - Up * Sin (Roll), Y => (-St, Ct, 0.0), Z => Zr,
                                        O => Hub - Zr * Wheel_Hub_M);
               Fs  : constant Frames := [others => F];
            begin
               Castle.Figures.Add (Wheel, Fs);
            end;
         end loop;
      end loop;
      --  the sacks left in it: three across the bed, and three more on those
      for K in 1 .. Natural'Min (6, Sacks) loop
         declare
            Layer : constant Natural := (K - 1) / 3;
            Slot  : constant Natural := (K - 1) mod 3;
         begin
            Put (Sack,
                 At_Cart (-0.62 + 0.62 * Float (Slot) + (if Layer = 1 then 0.2 else 0.0),
                          (if Layer = 1 then 0.0 else (if Slot mod 2 = 0 then -0.1 else 0.1)),
                          Cart_Bed_M + 0.24 * Float (Layer)),
                 Turn + Pi / 2.0 + 0.15 * Float (K mod 3 - 1));
         end;
      end loop;
   end Put_Cart;

   ------------------------------------------------------------------ a door's leaf

   Leaf_Made : array (Boolean) of Boolean := [others => False];
   Leaf_L    : array (Boolean) of Castle.Figures.Look_Id := [others => 1];

   --  Planks upright, a ledge across near its head and its foot on the side
   --  that swings into the house, two iron straps on the other, a latch.
   function Paint_Leaf_Side
     (Box : Positive; F : Face; U, V, Wf, Hf : Natural; H : Float; Out_F : Face) return Unsigned_32
   is
      use Castle.Colors;
      --  how far a texel of the outside is from the hinge edge (a face's U runs the other way on the other side)
      From_Hinge : constant Natural := (if Out_F = Neg_Y then U else Wf - 1 - U);
   begin
      if Box > 1 then                                     --  a ledge
         return Hex (Dark_Bark, (if H < 0.5 then 1.15 else 1.3));
      elsif F = Out_F and then V in 6 | 7 | Hf - 8 | Hf - 7 and then From_Hinge < 13 then
         return Hex (Iron, (if H < 0.5 then 0.75 else 0.9));           --  the straps, from the hinge
      elsif F = Out_F and then From_Hinge in 16 | 17 and then V in Hf / 2 - 1 .. Hf / 2 then
         return Hex (Iron, 0.8);                                         --  the latch
      elsif F in Pos_Y | Neg_Y and then U mod 4 = 3 then
         return Hex (Dark_Bark, 1.1);                                    --  between two planks
      else
         return Hex (Weathered_Oak, (if H < 0.33 then 0.82 elsif H < 0.66 then 0.9 else 0.98));
      end if;
   end Paint_Leaf_Side;

   function Paint_Leaf (Box : Positive; F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
     (Paint_Leaf_Side (Box, F, U, V, Wf, Hf, H, Neg_Y));
   function Paint_Leaf_Mirrored (Box : Positive; F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
     (Paint_Leaf_Side (Box, F, U, V, Wf, Hf, H, Pos_Y));

   function Door_Leaf (Mirrored : Boolean := False) return Castle.Figures.Look_Id is
      Ledge_Y : constant Float := (if Mirrored then -1.3 else 0.6);
   begin
      if not Leaf_Made (Mirrored) then
         Leaf_L (Mirrored) := Many_Boxes
           ([(Lo => (0.2, -0.6, 0.2), Size => (19.6, 1.2, 39.4), Round => 0.1, others => <>),
             (Lo => (1.0, Ledge_Y, 6.0), Size => (18.0, 0.7, 2.4), Round => 0.1, others => <>),
             (Lo => (1.0, Ledge_Y, 30.0), Size => (18.0, 0.7, 2.4), Round => 0.1, others => <>)],
            (if Mirrored then Paint_Leaf_Mirrored'Access else Paint_Leaf'Access));
         Leaf_Made (Mirrored) := True;
      end if;
      return Leaf_L (Mirrored);
   end Door_Leaf;

   ------------------------------------------------------------------ a gate's leaf, a window's trim

   Gate_Made : array (Boolean) of Boolean := [others => False];
   Gate_L    : array (Boolean) of Castle.Figures.Look_Id := [others => 1];
   Trim_Made : array (Boolean) of Boolean := [others => False];
   Trim_L    : array (Boolean) of Castle.Figures.Look_Id := [others => 1];

   function Paint_Gate (Box : Positive; F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      pragma Unreferenced (F, U, V, Wf, Hf);
      use Castle.Colors;
   begin
      return (if Box <= 3 then Hex (Dark_Bark, (if H < 0.5 then 1.15 else 1.3))            --  its stiles
              else Hex (Weathered_Oak, (if H < 0.33 then 0.8 elsif H < 0.66 then 0.9 else 1.0)));   --  its rails
   end Paint_Gate;

   function Gate_Leaf (Mirrored : Boolean := False) return Castle.Figures.Look_Id is
      Y : constant Float := (if Mirrored then 0.5 else -1.3);      --  (the rails on the side that is outward)
   begin
      if not Gate_Made (Mirrored) then
         Gate_L (Mirrored) := Many_Boxes
           ([(Lo => (0.2, -0.7, 1.0), Size => (1.4, 1.4, 20.0), others => <>),
             (Lo => (9.2, -0.5, 1.0), Size => (1.2, 1.0, 19.0), others => <>),
             (Lo => (18.2, -0.7, 1.0), Size => (1.4, 1.4, 20.0), others => <>),
             (Lo => (0.4, Y, 4.0), Size => (19.0, 0.8, 2.0), Round => 0.2, others => <>),
             (Lo => (0.4, Y, 10.0), Size => (19.0, 0.8, 2.0), Round => 0.2, others => <>),
             (Lo => (0.4, Y, 16.0), Size => (19.0, 0.8, 2.0), Round => 0.2, others => <>)],
            Paint_Gate'Access);
         Gate_Made (Mirrored) := True;
      end if;
      return Gate_L (Mirrored);
   end Gate_Leaf;

   ------------------------------------------------------------------ a stockyard's pieces

   Rail_Made  : array (Boolean) of Boolean := [others => False];
   Rail_L     : array (Boolean) of Castle.Figures.Look_Id := [others => 1];
   Tile_Made  : Boolean := False;
   Tile_L     : Castle.Figures.Look_Id := 1;
   Roll_Made  : array (Boolean) of Boolean := [others => False];
   Roll_L     : array (Boolean) of Castle.Figures.Look_Id := [others => 1];

   --  The land's own texels of thatch (Cover_Thatch): made once, from the
   --  seed the land's are made from.
   Texel_Seed : Castle.Hash.U64 := 1;
   Land_Set   : Castle.Textures.Texture_Set;
   Land_Made  : Boolean := False;
   procedure Set_Texel_Seed (Seed : Castle.Hash.U64) is
   begin
      if Land_Made and then Seed /= Texel_Seed then
         Castle.Textures.Free (Land_Set);
         Land_Made := False;
      end if;
      Texel_Seed := Seed;
   end Set_Texel_Seed;
   --  Texel (Tx, Ty) of the block at (Bu, Bv) of a face: one of the land's
   --  variants by the block's place there, as the land takes one by a
   --  block's place in the world.  Row 0 is the dark line where one course
   --  of straw overlaps the next.
   function Land_Thatch (Bu, Bv, Tx, Ty : Natural) return Unsigned_32 is
      use Castle.Textures;
      Var : constant Natural :=
        Natural (Castle.Hash.Mix (Castle.Hash.U64 (Bu) * 7_919 + Castle.Hash.U64 (Bv) * 104_729 + 13)
                 mod Castle.Hash.U64 (Variants));
      I   : constant Natural :=
        (((Castle.Blocks.Material'Pos (Castle.Blocks.Thatch) * Variants + Var) * Size + Ty) * Size + Tx) * 4;
   begin
      if not Land_Made then
         Land_Set := Generate (Texel_Seed);
         Land_Made := True;
      end if;
      return Unsigned_32 (Land_Set.Detail (I)) or Shift_Left (Unsigned_32 (Land_Set.Detail (I + 1)), 8)
        or Shift_Left (Unsigned_32 (Land_Set.Detail (I + 2)), 16) or Shift_Left (Unsigned_32'(255), 24);
   end Land_Thatch;

   --  (a log's texels: its colour, each its own brightness, the bark's furrows along it)
   function Paint_Rail (Box : Positive; F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      pragma Unreferenced (Box, U, Wf, Hf);
      K : Float := 0.88 + 0.24 * H;
   begin
      if F not in Pos_X | Neg_X and then V mod 2 = 0 then
         K := K * 0.82;
      end if;
      return Hex (Castle.Colors.Weathered_Oak, K);
   end Paint_Rail;
   --  (a plank's: a seam where one board meets the next)
   function Paint_Plank (Box : Positive; F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      pragma Unreferenced (Box, F, U, Wf, Hf);
      K : Float := 0.88 + 0.24 * H;
   begin
      if V mod 5 = 0 then
         K := K * 0.72;
      end if;
      return Hex (Castle.Colors.Copper_Brown, K);
   end Paint_Plank;
   function Rail (Plank : Boolean := False) return Castle.Figures.Look_Id is
   begin
      if not Rail_Made (Plank) then
         Rail_L (Plank) := Many_Boxes
           ([1 => (Lo => (0.0, -2.5, -2.5), Size => (20.0, 5.0, 5.0), Round => 0.4, others => <>)],
            (if Plank then Paint_Plank'Access else Paint_Rail'Access));
         Rail_Made (Plank) := True;
      end if;
      return Rail_L (Plank);
   end Rail;

   --  (thatch's texels: courses of straw, a dark line where one overlaps the next every block
   --  down the slope, the stalks running down it between, on the face that is its top; its other
   --  faces plain straw)
   function Paint_Thatch_On (Top : Face; F : Face; U, V : Natural; H : Float) return Unsigned_32 is
      K : Float := 0.88 + 0.24 * H;
   begin
      if F = Top then
         if V mod 5 = 2 then
            K := K * 0.7;
         elsif (U + V / 5) mod 2 = 0 then
            K := K * 0.9;
         end if;
      end if;
      return Hex (Castle.Colors.Thatch_Straw, K);
   end Paint_Thatch_On;
   function Paint_Thatch (Box : Positive; F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      pragma Unreferenced (Box, Wf, Hf);
   begin
      return Paint_Thatch_On (Pos_Z, F, U, V, H);
   end Paint_Thatch;
   function Paint_Roof (Box : Positive; F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      pragma Unreferenced (Box, Wf, Hf);
   begin
      return Paint_Thatch_On (Pos_Y, F, U, V, H);
   end Paint_Roof;
   --  (a covering's whole roof, one box: 3 m along X, 4 px thick along Y under its top (Y = 0), and
   --  2.1 m down its slope along Z: so its skin's net, 2 (60 + 4) by 42 + 8, fits one skin, and no
   --  seam crosses it.  Tiles of a metre square were tried first: from twenty metres off a dark
   --  seam showed at every tile's edge, where the sampler took in what lies round its face in the skin)
   --  (with Cover_Thatch: the land's texels.  A face's U and V run back along the box's X and up its
   --  Z (Castle.Render, Box_Face_Source), so on the roof's top a block's place and its texel are
   --  counted from the front's corner along it and down the slope, the dark row at each course's
   --  lower edge; its other faces, and a roll's, a block every five texels as they come)
   function Paint_Roof_Land (Box : Positive; F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      pragma Unreferenced (Box, H);
      X : constant Natural := Wf - 1 - U;
      Z : constant Natural := Hf - 1 - V;
   begin
      if F = Pos_Y then
         return Land_Thatch (X / 5, Z / 5, X mod 5, 4 - Z mod 5);
      else
         return Land_Thatch (U / 5 + 40 + 16 * Face'Pos (F), V / 5 + 40, U mod 5, V mod 5);
      end if;
   end Paint_Roof_Land;
   function Paint_Roll_Land (Box : Positive; F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      pragma Unreferenced (Box, Wf, Hf, H);
   begin
      return Land_Thatch (U / 5 + 16 * Face'Pos (F), V / 5 + 80, U mod 5, V mod 5);
   end Paint_Roll_Land;
   Straw_Fill : constant Unsigned_32 := Hex (Castle.Colors.Thatch_Straw, 0.9);
   function Thatch_Tile return Castle.Figures.Look_Id is
   begin
      if not Tile_Made then
         Tile_L := Many_Boxes
           ([1 => (Lo => (0.0, -4.0, 0.0), Size => (60.0, 4.0, 42.0), Round => 0.0, others => <>)],
            (if Cover_Thatch then Paint_Roof_Land'Access else Paint_Roof'Access),
            Fill => (if Cover_Thatch then Straw_Fill else 0));
         Tile_Made := True;
      end if;
      return Tile_L;
   end Thatch_Tile;
   --  (with Cover_Thatch a piece is 1.3 m long, its metre from 0 to 20 along X: it reaches Roll_Lap_M
   --  past each end, where its ends are rounded off, and the next piece, the other width, is whole
   --  there)
   function Thatch_Roll (Inner : Boolean := False) return Castle.Figures.Look_Id is
      Lap : constant Float := Roll_Lap_M * 20.0;
   begin
      if not Roll_Made (Inner) then
         if not Cover_Thatch then
            Roll_L (Inner) := Many_Boxes
              ([1 => (Lo => (0.0, -3.0, -3.0), Size => (20.0, 6.0, 6.0), Round => 2.8, others => <>)],
               Paint_Thatch'Access);
         elsif Inner then
            Roll_L (Inner) := Many_Boxes
              ([1 => (Lo => (-Lap, -2.9, -2.9), Size => (20.0 + 2.0 * Lap, 5.8, 5.8), Round => 2.7, others => <>)],
               Paint_Roll_Land'Access, Fill => Straw_Fill);
         else
            Roll_L (Inner) := Many_Boxes
              ([1 => (Lo => (-Lap, -3.0, -3.0), Size => (20.0 + 2.0 * Lap, 6.0, 6.0), Round => 2.8, others => <>)],
               Paint_Roll_Land'Access, Fill => Straw_Fill);
         end if;
         Roll_Made (Inner) := True;
      end if;
      return Roll_L (Inner);
   end Thatch_Roll;

   function Paint_Trim (Box : Positive; F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      pragma Unreferenced (F, Wf, Hf);
      use Castle.Colors;
   begin
      --  (plank: the grain along each piece)
      return (if (if Box = 3 then V else U) mod 2 = 1 and then H < 0.3 then Hex (Weathered_Oak, 1.0)
              else Hex (Sand_Tan, (if H < 0.5 then 0.82 else 0.9)));
   end Paint_Trim;

   function Window_Trim (Tall : Boolean) return Castle.Figures.Look_Id is
      Hh : constant Float := (if Tall then 15.0 else 10.0);
   begin
      if not Trim_Made (Tall) then
         Trim_L (Tall) := Many_Boxes
           ([(Lo => (-Trim_W, -3.0, 0.0), Size => (Trim_W, 0.6, Hh), Round => 0.05, others => <>),
             (Lo => (10.0, -3.0, 0.0), Size => (Trim_W, 0.6, Hh), Round => 0.05, others => <>),
             (Lo => (-Trim_W, -3.0, Hh), Size => (10.0 + 2.0 * Trim_W, 0.6, Trim_W), Round => 0.05, others => <>)],
            Paint_Trim'Access);
         Trim_Made (Tall) := True;
      end if;
      return Trim_L (Tall);
   end Window_Trim;

   ------------------------------------------------------------------ a ladder

   Ladder_Made : Boolean := False;
   Ladder_L    : Castle.Figures.Look_Id := 1;

   function Paint_Ladder (Box : Positive; F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      pragma Unreferenced (F, V, Wf, Hf);
      use Castle.Colors;
   begin
      if Box > 4 then                                     --  a rung: split ash, paler
         return (if H < 0.5 then Hex (Sand_Tan, 0.9) else Hex (Gilded_Amber, 0.8));
      end if;
      return (if U mod 9 = 4 then Hex (Dark_Bark)          --  a rail: a pole with its knots
              elsif H < 0.4 then Hex (Weathered_Oak, 1.1) else Hex (Weathered_Oak, 1.3));
   end Paint_Ladder;

   function Ladder return Castle.Figures.Look_Id is
      Specs : Box_Specs (1 .. 14);
   begin
      if not Ladder_Made then
         --  each rail in two lengths (a net 68 px long would not fit the skin's width)
         Specs (1) := (Lo => (-34.0, -4.6, -0.6), Size => (34.0, 1.2, 1.2), others => <>);
         Specs (2) := (Lo => (0.0, -4.6, -0.6), Size => (34.0, 1.2, 1.2), others => <>);
         Specs (3) := (Lo => (-34.0, 3.4, -0.6), Size => (34.0, 1.2, 1.2), others => <>);
         Specs (4) := (Lo => (0.0, 3.4, -0.6), Size => (34.0, 1.2, 1.2), others => <>);
         for K in 0 .. 9 loop
            Specs (5 + K) := (Lo => (-29.4 + 6.4 * Float (K), -4.0, -0.4), Size => (0.8, 8.0, 0.8), others => <>);
         end loop;
         Ladder_L := Many_Boxes (Specs, Paint_Ladder'Access);
         Ladder_Made := True;
      end if;
      return Ladder_L;
   end Ladder;

   --  A look that lies 3.4 m along its X about its middle, leaning from
   --  Foot toward Top.
   procedure Put_Leaning (L : Castle.Figures.Look_Id; Foot, Top : Vec3) is
      D   : constant Vec3 := Top - Foot;
      Len : constant Float := Sqrt (Dot (D, D));
      Flat : constant Float := Sqrt (D.X * D.X + D.Y * D.Y);
   begin
      if Len < 0.3 then
         return;
      end if;
      declare
         X  : constant Vec3 := D * (1.0 / Len);                           --  up it
         Y  : constant Vec3 := (if Flat > 0.01 then (-D.Y / Flat, D.X / Flat, 0.0) else (0.0, 1.0, 0.0));   --  across it, level
         Z  : constant Vec3 := (X.Y * Y.Z - X.Z * Y.Y, X.Z * Y.X - X.X * Y.Z, X.X * Y.Y - X.Y * Y.X);
         F  : constant Frame := (X => X, Y => Y, Z => Z, O => Foot + X * 1.7);
      begin
         Put_In (L, F);
      end;
   end Put_Leaning;

   procedure Put_Ladder (Foot, Top : Vec3) is
   begin
      Put_Leaning (Ladder, Foot, Top);
   end Put_Ladder;

   Pole_Made : Boolean := False;
   Pole_L    : Castle.Figures.Look_Id := 1;

   function Paint_Pole (Box : Positive; F : Face; U, V, Wf, Hf : Natural; H : Float) return Unsigned_32 is
      pragma Unreferenced (Box, F, V, Wf, Hf);
      use Castle.Colors;
   begin
      return (if U mod 11 = 5 then Hex (Dark_Bark) elsif H < 0.4 then Hex (Weathered_Oak) else Hex (Weathered_Oak, 1.2));
   end Paint_Pole;

   procedure Put_Ladder_Stood (Ground : Vec3; Turn : Float; Nth : Positive := 1) is
      D    : constant Vec3 := (Cos (Turn), Sin (Turn), 0.0);
      Side : constant Vec3 := (-Sin (Turn), Cos (Turn), 0.0) * (0.28 * Float (Nth - 1));
      Apex : constant Vec3 := Ground + (0.0, 0.0, 3.37);
   begin
      if not Pole_Made then            --  (the pole it is propped on: in two lengths, as a ladder's rails are)
         Pole_L := Many_Boxes
           ([(Lo => (-34.0, -0.7, -0.7), Size => (34.0, 1.4, 1.4), others => <>),
             (Lo => (0.0, -0.7, -0.7), Size => (34.0, 1.4, 1.4), others => <>)],
            Paint_Pole'Access);
         Pole_Made := True;
      end if;
      Put_Leaning (Ladder, Ground + Side - D * 0.40, Apex + Side);
      if Nth = 1 then
         Put_Leaning (Pole_L, Ground + D * 0.40, Apex);
      end if;
   end Put_Ladder_Stood;

   procedure Put (L : Castle.Figures.Look_Id; Ground : Vec3; Turn : Float) is
      F  : constant Frame := (X => (Cos (Turn), Sin (Turn), 0.0), Y => (-Sin (Turn), Cos (Turn), 0.0),
                              Z => (0.0, 0.0, 1.0), O => Ground);
      Fs : constant Frames := [others => F];
   begin
      Castle.Figures.Add (L, Fs);
   end Put;

end Castle.Props;
