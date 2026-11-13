with Interfaces;    use Interfaces;
with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Castle.Bodies; use Castle.Bodies;
with Castle.Poses;  use Castle.Poses;
with Castle.Hash;
with Castle.Colors;

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

   function Many_Boxes
     (Specs : Box_Specs;
      Paint : not null access function (Box : Positive; F : Face; U, V, Wf, Hf : Natural; H : Float)
                                        return Unsigned_32)
      return Castle.Figures.Look_Id
   is
      R    : Rig;
      Skin : Skin_Pixels := [others => [others => 0]];
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
               Round => Specs (K).Round, Taper => Specs (K).Taper);
            U_At := U_At + Net_W;
            Row_H := Natural'Max (Row_H, Net_H);
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

   procedure Put (L : Castle.Figures.Look_Id; Ground : Vec3; Turn : Float) is
      F  : constant Frame := (X => (Cos (Turn), Sin (Turn), 0.0), Y => (-Sin (Turn), Cos (Turn), 0.0),
                              Z => (0.0, 0.0, 1.0), O => Ground);
      Fs : constant Frames := [others => F];
   begin
      Castle.Figures.Add (L, Fs);
   end Put;

end Castle.Props;
