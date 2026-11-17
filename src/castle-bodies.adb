with Ada.Characters.Handling;
with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;

package body Castle.Bodies is

   use Interfaces;

   ----------------------------------------------------------------- colours

   function C8 (R, G, B : Natural) return RGB is
     (Float (R) / 255.0, Float (G) / 255.0, Float (B) / 255.0);

   function Mix (A, B : RGB; T : Float) return RGB is
     (A.R + (B.R - A.R) * T, A.G + (B.G - A.G) * T, A.B + (B.B - A.B) * T);

   function Times (A : RGB; K : Float) return RGB is (A.R * K, A.G * K, A.B * K);

   function Pack (C : RGB; Alpha : Natural := 255) return Unsigned_32 is
      function B8 (F : Float) return Unsigned_32 is
        (Unsigned_32 (Float'Max (0.0, Float'Min (255.0, F * 255.0 + 0.5))));
   begin
      return B8 (C.R) or Shift_Left (B8 (C.G), 8) or Shift_Left (B8 (C.B), 16)
        or Shift_Left (Unsigned_32 (Alpha), 24);
   end Pack;

   function Smooth (E0, E1, X : Float) return Float is
      T : constant Float := Float'Max (0.0, Float'Min (1.0, (X - E0) / (E1 - E0)));
   begin
      return T * T * (3.0 - 2.0 * T);
   end Smooth;

   --  Skin, pale to dark; most of a medieval valley sits in the first half,
   --  travellers and refugees anywhere along it.
   Skin_Ramp : constant array (0 .. 5) of RGB :=
     [C8 (240, 210, 186), C8 (226, 184, 152), C8 (204, 154, 116),
      C8 (172, 120, 82), C8 (126, 84, 56), C8 (86, 56, 40)];

   pragma Warnings (Off, "literal * is not referenced");   --  drawn by the odds, not by name
   type Hair_Shade is (Black, Dark_Brown, Mid_Brown, Auburn, Red, Dark_Blond, Blond);
   pragma Warnings (On, "literal * is not referenced");
   Hair_Colour : constant array (Hair_Shade) of RGB :=
     [C8 (34, 28, 26), C8 (58, 40, 28), C8 (96, 66, 40), C8 (122, 58, 30),
      C8 (160, 74, 34), C8 (150, 118, 72), C8 (202, 170, 110)];
   Hair_Odds : constant array (Hair_Shade) of Float :=   --  cumulative
     [0.15, 0.45, 0.65, 0.73, 0.78, 0.90, 1.0];
   Grey  : constant RGB := C8 (150, 148, 144);
   White : constant RGB := C8 (214, 212, 206);

   Eye_Colour : constant array (0 .. 4) of RGB :=
     [C8 (70, 44, 26), C8 (70, 110, 160), C8 (110, 118, 124), C8 (78, 112, 70), C8 (110, 90, 50)];
   Eye_Odds : constant array (0 .. 4) of Float := [0.40, 0.65, 0.80, 0.90, 1.0];

   --  Cloth: undyed wool and the dyes a valley has (muted), and for the
   --  lord, the dear ones.
   Undyed    : constant RGB := C8 (186, 176, 152);
   Oat       : constant RGB := C8 (164, 148, 118);
   Grey_Wool : constant RGB := C8 (128, 124, 116);
   Brown     : constant RGB := C8 (104, 78, 56);
   Russet    : constant RGB := C8 (128, 62, 42);
   Madder    : constant RGB := C8 (150, 58, 48);
   Woad      : constant RGB := C8 (64, 84, 120);
   Weld      : constant RGB := C8 (176, 152, 70);
   Green     : constant RGB := C8 (82, 100, 58);
   Moss      : constant RGB := C8 (70, 84, 50);
   Dark_Wool : constant RGB := C8 (60, 54, 48);
   Rich_Blue : constant RGB := C8 (40, 58, 120);
   Rich_Red  : constant RGB := C8 (136, 30, 32);
   Rich_Green : constant RGB := C8 (40, 80, 50);
   Gold      : constant RGB := C8 (196, 160, 60);
   Linen     : constant RGB := C8 (222, 214, 196);
   Leather   : constant RGB := C8 (110, 76, 48);
   Dark_Leather : constant RGB := C8 (70, 48, 32);
   Iron      : constant RGB := C8 (110, 112, 118);
   Straw     : constant RGB := C8 (190, 160, 100);
   Burlap    : constant RGB := C8 (170, 145, 105);

   type Dye_List is array (Positive range <>) of RGB;

   function Pick (L : Dye_List; U : Float) return RGB is
     (L (L'First + Natural'Min (L'Length - 1, Natural (Float'Floor (U * Float (L'Length))))));

   ----------------------------------------------------------------- genome

   function Random_Genome (Seed : U64; Child : Boolean := False; Elder : Boolean := False) return Genome is
      G : Genome;
      function R (K : Natural) return Float is (Unit (Hash_2 (Seed, K, 17)));
      function Normal (K : Natural) return Float is   --  about N (0, 1)
        ((R (K) + R (K + 100) + R (K + 200) - 1.5) * 2.0);
   begin
      G.Seed := Seed;
      G.Sex  := (if R (1) < 0.5 then Female else Male);
      G.Age  := (if Child then 6.0 + 8.0 * R (2)
                 elsif Elder then 60.0 + 15.0 * R (2)
                 else 16.0 + 44.0 * R (2) ** 1.4);
      declare
         Adult : constant Float := (if G.Sex = Male then 1.72 else 1.61) + 0.06 * Normal (3);
      begin
         if G.Age < 16.0 then
            G.Height := Float'Min (Adult, 0.80 + 0.058 * G.Age);
         elsif G.Age > 60.0 then
            G.Height := Adult - 0.003 * (G.Age - 60.0);
         else
            G.Height := Adult;
         end if;
         G.Height := Float'Max (1.0, Float'Min (1.92, G.Height));
      end;
      G.Build := Float'Max (-1.0, Float'Min (1.0, 0.5 * Normal (4)));

      declare
         T : constant Float := (if R (5) < 0.88 then 0.45 * R (6) else 0.45 + 0.55 * R (6));
         P : constant Float := T * 5.0;
         I : constant Natural := Natural'Min (4, Natural (Float'Floor (P)));
         Shade : Hair_Shade := Hair_Shade'Last;
      begin
         G.Skin := Mix (Skin_Ramp (I), Skin_Ramp (I + 1), P - Float (I));
         for H in Hair_Shade loop
            if R (7) < Hair_Odds (H) then
               Shade := H;
               exit;
            end if;
         end loop;
         if T > 0.5 and then Shade in Auburn .. Blond then
            Shade := Black;              --  darker skin, darker hair
         end if;
         G.Hair := Hair_Colour (Shade);
         G.Freckles := (T < 0.2 and then R (17) < 0.25) or else (Shade in Auburn | Red and then R (17) < 0.6);
         declare
            Greying : constant Float := Smooth (35.0, 70.0, G.Age) * (0.6 + 0.4 * R (8));
         begin
            G.Hair := Mix (G.Hair, Mix (Grey, White, Smooth (60.0, 75.0, G.Age)), Greying);
         end;
         for E in Eye_Odds'Range loop
            if R (9) < Eye_Odds (E) then
               G.Eyes := Eye_Colour (E);
               exit;
            end if;
         end loop;
         if T > 0.5 then
            G.Eyes := Eye_Colour (0);
         end if;
      end;

      if G.Sex = Male then
         if G.Age > 28.0 and then R (10) < (G.Age - 28.0) / 60.0 then
            G.Hair_Style := Bald;
         else
            G.Hair_Style := (if R (11) < 0.35 then Cropped elsif R (11) < 0.82 then Short else Long);
         end if;
         if G.Age < 17.0 then
            G.Beard := None;
         else
            declare
               U : constant Float := R (12) - 0.004 * (G.Age - 30.0);   --  older, more beard
            begin
               G.Beard := (if U > 0.70 then None elsif U > 0.50 then Stubble
                           elsif U > 0.18 then Short_Beard else Full_Beard);
            end;
         end if;
      else
         G.Hair_Style := (if R (11) < 0.30 then Long elsif R (11) < 0.65 then Bun
                          elsif R (11) < 0.90 then Braids else Short);
         G.Beard := None;
         G.Coif := G.Age > 18.0 and then R (13) < 0.45;
      end if;
      if Child then
         G.Hair_Style := (if G.Sex = Male then (if R (11) < 0.5 then Cropped else Short)
                          else (if R (11) < 0.5 then Braids else Long));
      end if;
      G.Hand := (if R (14) < 0.1 then Left else Right);
      G.Scar := G.Age > 18.0 and then R (15) < 0.12;
      G.Scar_Side := (if R (16) < 0.5 then Left else Right);
      return G;
   end Random_Genome;

   function Rounding (B : Box) return Float is
      Thin : constant Float := Float'Min (B.Size.X, Float'Min (B.Size.Y, B.Size.Z));
   begin
      return Float'Max (0.0, Float'Min (0.45 * Thin,
                                        (if B.Round < 0.0 then Float'Min (Round_Max, Round_Share * Thin)
                                         else B.Round)));
   end Rounding;

   ---------------------------------------------------------------- the net

   procedure Face_Rect (B : Box; F : Face; U0, V0, Wf, Hf : out Natural) is
   begin
      case F is
         when Pos_X => U0 := B.U;                   V0 := B.V + B.D; Wf := B.D; Hf := B.H;
         when Pos_Y => U0 := B.U + B.D;             V0 := B.V + B.D; Wf := B.W; Hf := B.H;
         when Neg_X => U0 := B.U + B.D + B.W;       V0 := B.V + B.D; Wf := B.D; Hf := B.H;
         when Neg_Y => U0 := B.U + 2 * B.D + B.W;   V0 := B.V + B.D; Wf := B.W; Hf := B.H;
         when Pos_Z => U0 := B.U + B.D;             V0 := B.V;       Wf := B.W; Hf := B.D;
         when Neg_Z => U0 := B.U + B.D + B.W;       V0 := B.V;       Wf := B.W; Hf := B.D;
      end case;
   end Face_Rect;

   function Mirrored (F : Face) return Face is
     (case F is when Pos_X => Neg_X, when Neg_X => Pos_X, when others => F);

   ------------------------------------------------------------------ packing

   procedure Pack_Nets (B : in out Rig; Count : Natural; Fits : out Boolean) is
      Order : array (1 .. Count) of Positive;
      X, Y, Row_H : Natural := 0;
   begin
      Fits := True;
      for I in Order'Range loop
         Order (I) := I;
      end loop;
      for I in Order'Range loop   --  tallest nets first: tighter shelves
         for J in I + 1 .. Order'Last loop
            if B.Boxes (Order (J)).D + B.Boxes (Order (J)).H > B.Boxes (Order (I)).D + B.Boxes (Order (I)).H then
               declare
                  T : constant Positive := Order (I);
               begin
                  Order (I) := Order (J);
                  Order (J) := T;
               end;
            end if;
         end loop;
      end loop;
      for K of Order loop
         declare
            Bx : Box renames B.Boxes (K);
            Nw : constant Natural := 2 * (Bx.W + Bx.D);
            Nh : constant Natural := Bx.D + Bx.H;
         begin
            if X + Nw > Skin_W then
               X := 0;
               Y := Y + Row_H;
               Row_H := 0;
            end if;
            if Y + Nh > Skin_H then
               Fits := False;
               return;
            end if;
            Bx.U := X;
            Bx.V := Y;
            X := X + Nw;
            Row_H := Natural'Max (Row_H, Nh);
         end;
      end loop;
   end Pack_Nets;

   ------------------------------------------------------------------ build

   procedure Build (G : Genome; O : Outfit; B : out Rig; Skin : out Skin_Pixels) is

      function R (K : Natural) return Float is (Unit (Hash_2 (G.Seed, K, 29)));

      Child  : constant Boolean := G.Age < 15.0;
      Is_Man : constant Boolean := G.Sex = Male;
      Hp     : constant Integer := Integer (G.Height / Px);
      Head_P : constant := 6;
      Ankle_P : constant := 2;
      Leg_P  : constant Integer := Integer (Float (Hp) * (if Child then 0.42 else 0.46));
      Thigh_P : constant Integer := (Leg_P - Ankle_P + 1) / 2;
      Shin_P : constant Integer := Leg_P - Ankle_P - Thigh_P;
      Torso_P : constant Integer := Hp - Head_P - Leg_P;
      Pelvis_P : constant Integer := Integer (Float (Torso_P) * 0.4);
      Chest_P : constant Integer := Torso_P - Pelvis_P;
      Upper_P : constant Integer := Integer (Float (Hp) * 0.17);
      Fore_P : constant Integer := Integer (Float (Hp) * 0.15);

      Chest_W : constant Integer :=
        (if Child then (if Hp < 26 then 5 else 6)
         else (if Is_Man then 8 else 7) + (if G.Build > 0.45 then 1 elsif G.Build < -0.55 then -1 else 0));
      Pelvis_W : constant Integer :=
        (if Child then (if Hp < 26 then 5 else 6)
         else (if Is_Man then 7 else 8) + (if G.Build > 0.6 then 1 elsif G.Build < -0.6 then -1 else 0));
      Chest_D  : constant Integer := (if not Child and then G.Build > 0.7 then 5 else 4);
      Pelvis_D : constant Integer := 4;
      Arm_W    : constant Integer := (if Child then 2 else 3);
      Leg_W    : constant Integer := (if Child then 2 else 3);
      Hip_Off  : constant Float := Float (Pelvis_W) / 2.0 - Float (Leg_W) / 2.0 - 0.1;
      --  how far the chest and the hips draw in to the waist between them
      Waist    : constant Float := (if Child then 0.5 * Waist_Taper else Waist_Taper);
      Skirt_Bottom : constant Integer :=    --  how far below the hip joint the tunic or dress reaches
        (if Is_Man then Thigh_P - 1 else (if Child then Thigh_P + 1 else Thigh_P + Shin_P - 3));

      --  Clothes.
      Tunic : RGB;
      Hose  : RGB;
      Cloak_C : RGB;
      Hood_C  : RGB;
      Shoe  : constant RGB := Dark_Leather;
      Belt  : constant RGB := Leather;
      Trim  : RGB;                         --  hems; gold for the lord
      Long_Sleeves : constant Boolean := O.Winter or else R (1) < 0.6;
      Rolled : constant Side := (if R (2) < 0.5 then Left else Right);   --  one sleeve pushed up, sometimes
      Roll_One : constant Boolean := Long_Sleeves and then not O.Winter and then R (3) < 0.3;

      ---------------------------------------------------------- boxes

      Count : Natural := 0;

      function Add (On : Bone; Lo, Size : Vec3; Cutout : Boolean := False; Taper : Float := 0.0)
                    return Positive is
      begin
         Count := Count + 1;
         B.Boxes (Count) :=
           (On => On, Lo => Lo, Size => Size,
            W => Natural (Float'Rounding (Size.X)), D => Natural (Float'Rounding (Size.Y)),
            H => Natural (Float'Rounding (Size.Z)), U => 0, V => 0, Cutout => Cutout, Glow => False,
            Round => Auto_Round, Taper => Taper);
         return Count;
      end Add;

      function Mirror_Box (Src : Positive) return Positive is
         S : constant Box := B.Boxes (Src);
      begin
         return Add (Mirror (S.On), (-(S.Lo.X + S.Size.X), S.Lo.Y, S.Lo.Z), S.Size, S.Cutout, S.Taper);
      end Mirror_Box;

      ---------------------------------------------------------- paint

      procedure Put (U, V : Natural; C : RGB; Alpha : Natural := 255) is
      begin
         if U < Skin_W and then V < Skin_H then
            Skin (V, U) := Pack (C, Alpha);
         end if;
      end Put;

      function Grain (U, V : Natural; Salt : Integer) return Float is
        (Unit (Hash_3 (G.Seed, U, V, Salt)) - 0.5);

      procedure Texel (Bi : Positive; F : Face; S, T : Integer; C : RGB; Amp : Float := 0.0;
                       Alpha : Natural := 255)
      is
         U0, V0, Wf, Hf : Natural;
      begin
         Face_Rect (B.Boxes (Bi), F, U0, V0, Wf, Hf);
         if S in 0 .. Wf - 1 and then T in 0 .. Hf - 1 then
            Put (U0 + S, V0 + T, Times (C, 1.0 + Amp * Grain (U0 + S, V0 + T, Bi)), Alpha);
         end if;
      end Texel;

      procedure Fill_Face (Bi : Positive; F : Face; C : RGB; Amp : Float) is
         U0, V0, Wf, Hf : Natural;
      begin
         Face_Rect (B.Boxes (Bi), F, U0, V0, Wf, Hf);
         for T in 0 .. Hf - 1 loop
            for S in 0 .. Wf - 1 loop
               Texel (Bi, F, S, T, C, Amp);
            end loop;
         end loop;
      end Fill_Face;

      procedure Fill (Bi : Positive; C : RGB; Amp : Float := 0.06) is
      begin
         for F in Face loop
            Fill_Face (Bi, F, C, Amp);
         end loop;
      end Fill;

      --  Rows of the four sides, counted from the top (or the bottom).
      procedure Band (Bi : Positive; From_Top, Rows : Integer; C : RGB; Amp : Float := 0.06) is
         U0, V0, Wf, Hf : Natural;
      begin
         for F in Pos_X .. Neg_Y loop
            Face_Rect (B.Boxes (Bi), F, U0, V0, Wf, Hf);
            for T in Integer'Max (0, From_Top) .. Integer'Min (Hf - 1, From_Top + Rows - 1) loop
               for S in 0 .. Wf - 1 loop
                  Texel (Bi, F, S, T, C, Amp);
               end loop;
            end loop;
         end loop;
      end Band;

      procedure Band_Up (Bi : Positive; From_Bottom, Rows : Integer; C : RGB; Amp : Float := 0.06) is
      begin
         Band (Bi, B.Boxes (Bi).H - From_Bottom - Rows, Rows, C, Amp);
      end Band_Up;

      --  Woven or plaited: two colours in a checker.
      procedure Weave (Bi : Positive; A, C : RGB) is
         U0, V0, Wf, Hf : Natural;
      begin
         for F in Face loop
            Face_Rect (B.Boxes (Bi), F, U0, V0, Wf, Hf);
            for T in 0 .. Hf - 1 loop
               for S in 0 .. Wf - 1 loop
                  Texel (Bi, F, S, T, (if (S + T) mod 2 = 0 then A else C), 0.08);
               end loop;
            end loop;
         end loop;
      end Weave;

      --  The right limb's skin is the left one's, seen in a mirror.
      procedure Copy_Mirrored (Src, Dst : Positive) is
         Us, Vs, Ws, Hs, Ud, Vd, Wd, Hd : Natural;
      begin
         for F in Face loop
            Face_Rect (B.Boxes (Dst), F, Ud, Vd, Wd, Hd);
            Face_Rect (B.Boxes (Src), Mirrored (F), Us, Vs, Ws, Hs);
            for T in 0 .. Natural'Min (Hd, Hs) - 1 loop
               for S in 0 .. Natural'Min (Wd, Ws) - 1 loop
                  Skin (Vd + T, Ud + S) := Skin (Vs + T, Us + Ws - 1 - S);
               end loop;
            end loop;
         end loop;
      end Copy_Mirrored;

      --  Columns of the front face seen from the front: 0 is the serf's
      --  right.  Side_Col gives the column for one side of the middle.
      function Side_Col (Wf : Natural; Sd : Side; From_Middle : Natural) return Integer is
        (if Sd = Right then Integer (Wf) / 2 - 1 - Integer (From_Middle) else (Integer (Wf) + 1) / 2 + Integer (From_Middle));

      ---------------------------------------------------------- the parts

      Pelvis_B, Chest_B, Head_B, Upper_L, Fore_L, Hand_L_B, Thigh_L_B, Shin_L_B, Foot_L_B : Positive;
      Upper_R, Fore_R, Hand_R_B, Thigh_R_B, Shin_R_B, Foot_R_B : Positive;
      Skirt_B : Positive;

      procedure Paint_Head is
         W  : constant Natural := B.Boxes (Head_B).W;
         Hr : constant RGB := G.Hair;
         Brow : constant RGB := Times (Mix (G.Hair, G.Skin, (if G.Hair_Style = Bald then 0.6 else 0.15)), 0.75);
         Hair_Rows_Back, Hair_Rows_Side : Natural;
      begin
         Fill (Head_B, G.Skin, 0.03);
         --  hair
         case G.Hair_Style is
            when Bald    => Hair_Rows_Back := 0; Hair_Rows_Side := 0;
            when Cropped => Hair_Rows_Back := 3; Hair_Rows_Side := 2;
            when Short   => Hair_Rows_Back := 4; Hair_Rows_Side := 3;
            when Long | Braids => Hair_Rows_Back := 6; Hair_Rows_Side := 5;
            when Bun     => Hair_Rows_Back := 5; Hair_Rows_Side := 3;
         end case;
         if G.Hair_Style = Bald then
            --  what is left: a fringe round the back
            for S in 0 .. W - 1 loop
               Texel (Head_B, Neg_Y, S, 2, Hr, 0.15);
               Texel (Head_B, Neg_Y, S, 3, Hr, 0.15);
            end loop;
            for S in 0 .. 2 loop
               Texel (Head_B, Pos_X, S, 2, Hr, 0.15);
               Texel (Head_B, Neg_X, W - 1 - S, 2, Hr, 0.15);
            end loop;
         else
            Fill_Face (Head_B, Pos_Z, Hr, 0.18);
            for T in 0 .. Hair_Rows_Back - 1 loop
               for S in 0 .. W - 1 loop
                  Texel (Head_B, Neg_Y, S, T, Hr, 0.18);
               end loop;
            end loop;
            for T in 0 .. Hair_Rows_Side - 1 loop
               for S in 0 .. W - 1 loop
                  --  the sides: hair from the back, toward the face on the top rows
                  if T <= 1 or else S < W - 2 then
                     Texel (Head_B, Pos_X, S, T, Hr, 0.18);           --  +X runs back to front
                     Texel (Head_B, Neg_X, W - 1 - S, T, Hr, 0.18);   --  -X runs front to back
                  end if;
               end loop;
            end loop;
            for S in 0 .. W - 1 loop
               Texel (Head_B, Pos_Y, S, 0, Hr, 0.18);                 --  the hairline
            end loop;
         end if;
         if G.Coif then
            --  a linen kerchief: top, back, sides, a band over the brow
            Fill_Face (Head_B, Pos_Z, Linen, 0.05);
            for T in 0 .. 4 loop
               for S in 0 .. W - 1 loop
                  Texel (Head_B, Neg_Y, S, T, Linen, 0.05);
                  if T <= 2 or else S < W - 2 then
                     Texel (Head_B, Pos_X, S, T, Linen, 0.05);
                     Texel (Head_B, Neg_X, W - 1 - S, T, Linen, 0.05);
                  end if;
               end loop;
            end loop;
            for S in 0 .. W - 1 loop
               Texel (Head_B, Pos_Y, S, 0, Linen, 0.05);
            end loop;
         end if;
         --  the face: brows, eyes, nose shadow, mouth (seen from the front,
         --  column 0 is the serf's right)
         for Sd in Side loop
            Texel (Head_B, Pos_Y, Side_Col (W, Sd, 1), 1, Brow);
            Texel (Head_B, Pos_Y, Side_Col (W, Sd, 1), 2, Times (G.Eyes, 0.55));
         end loop;
         Texel (Head_B, Pos_Y, Side_Col (W, Right, 0), 3, Times (G.Skin, 0.9));
         Texel (Head_B, Pos_Y, Side_Col (W, Left, 0), 3, Times (G.Skin, 0.9));
         declare
            Lip : constant RGB := Mix (Times (G.Skin, 0.72), C8 (150, 70, 60), 0.35);
         begin
            Texel (Head_B, Pos_Y, Side_Col (W, Right, 0), 4, Lip);
            Texel (Head_B, Pos_Y, Side_Col (W, Left, 0), 4, Lip);
         end;
         if G.Freckles then
            Texel (Head_B, Pos_Y, Side_Col (W, Right, 2), 3, Times (G.Skin, 0.86));
            Texel (Head_B, Pos_Y, Side_Col (W, Left, 1), 3, Times (G.Skin, 0.88));
         end if;
         if G.Scar then
            Texel (Head_B, Pos_Y, Side_Col (W, G.Scar_Side, 2), 3, Mix (G.Skin, C8 (236, 190, 180), 0.6));
            Texel (Head_B, Pos_Y, Side_Col (W, G.Scar_Side, 2), 4, Mix (G.Skin, C8 (236, 190, 180), 0.4));
         end if;
         --  beards: the lower face and the jaw at the sides
         if G.Beard /= None then
            declare
               Bc : constant RGB := (if G.Beard = Stubble then Mix (G.Skin, G.Hair, 0.4) else G.Hair);
               From : constant Natural := (if G.Beard = Full_Beard then 3 else 4);
            begin
               for T in From .. 5 loop
                  for S in 0 .. W - 1 loop
                     if not (T = 4 and then S in Side_Col (W, Right, 0) | Side_Col (W, Left, 0)) then
                        Texel (Head_B, Pos_Y, S, T, Bc, 0.12);
                     end if;
                  end loop;
                  for S in W - 2 .. W - 1 loop
                     Texel (Head_B, Pos_X, S, T, Bc, 0.12);
                     Texel (Head_B, Neg_X, W - 1 - S, T, Bc, 0.12);
                  end loop;
               end loop;
            end;
         end if;
      end Paint_Head;

      Hood_B, Cloak_B, Coif_B : Natural := 0;
      Basket_B, Sack_B, Scabbard_B, Guard_B : Natural := 0;

   begin
      Skin := [others => [others => 0]];

      --  Clothes by job, season and sex.
      if Is_Man or else Child then
         Tunic := (case O.Job is
                      when Idle     => Pick ([Undyed, Oat, Grey_Wool, Brown], R (10)),
                      when Forester => Pick ([Green, Moss, Brown], R (10)),
                      when Hunter   => Pick ([Brown, Russet, Grey_Wool], R (10)),
                      when Gatherer => Pick ([Undyed, Weld, Oat], R (10)),
                      when Porter   => Pick ([Brown, Grey_Wool, Oat, Russet], R (10)),
                      when Lord     => Pick ([Rich_Blue, Rich_Red, Rich_Green], R (10)));
      else
         Tunic := (case O.Job is
                      when Idle     => Pick ([Madder, Woad, Weld, Green, Undyed, Brown], R (10)),
                      when Forester => Pick ([Green, Moss], R (10)),
                      when Hunter   => Pick ([Brown, Russet], R (10)),
                      when Gatherer => Pick ([Undyed, Weld, Madder, Woad], R (10)),
                      when Porter   => Pick ([Brown, Grey_Wool, Russet], R (10)),
                      when Lord     => Pick ([Rich_Blue, Rich_Red, Rich_Green], R (10)));
      end if;
      Tunic := Times (Tunic, 0.92 + 0.16 * R (11));
      Hose := Times (Pick ([Brown, Grey_Wool, Dark_Wool, Russet], R (12)), 0.9 + 0.15 * R (13));
      Cloak_C := (if O.Job = Lord then Times (Tunic, 0.6) else Pick ([Dark_Wool, Brown, Moss, Grey_Wool], R (14)));
      Hood_C := (if O.Job = Forester then Moss else Times (Cloak_C, 1.1));
      B.Cloak := Cloak_C;
      Trim := (if O.Job = Lord then Gold else Times (Tunic, 0.78));

      --  The skeleton, standing: joint offsets from each parent (metres).
      B.Joint (Pelvis) := (0.0, 0.0, Float (Leg_P) * Px);
      B.Joint (Chest)  := (0.0, 0.0, Float (Pelvis_P) * Px);
      B.Joint (Head)   := (0.0, 0.0, Float (Chest_P) * Px);
      B.Joint (Upper_Arm_L) := (-(Float (Chest_W) / 2.0 + Float (Arm_W) / 2.0 + 0.05) * Px, 0.0, Float (Chest_P) * Px);
      B.Joint (Forearm_L) := (0.0, 0.0, -Float (Upper_P) * Px);
      B.Joint (Hand_L)    := (0.0, 0.0, -Float (Fore_P) * Px);
      B.Joint (Thigh_L)   := (-Hip_Off * Px, 0.0, 0.0);
      B.Joint (Shin_L)    := (0.0, 0.0, -Float (Thigh_P) * Px);
      B.Joint (Foot_L)    := (0.0, 0.0, -Float (Shin_P) * Px);
      for L in Bone loop
         if not Is_Middle (L) and then L in Upper_Arm_L .. Hand_L | Thigh_L .. Foot_L then
            B.Joint (Mirror (L)) := (-B.Joint (L).X, B.Joint (L).Y, B.Joint (L).Z);
         end if;
      end loop;
      B.Height    := Float (Hp) * Px;
      B.Hip       := Float (Leg_P) * Px;
      B.Ankle     := Float (Ankle_P) * Px;
      B.Hip_Half  := Hip_Off * Px;
      B.Thigh     := Float (Thigh_P) * Px;
      B.Shin      := Float (Shin_P) * Px;
      B.Upper_Arm := Float (Upper_P) * Px;
      B.Forearm   := Float (Fore_P) * Px;

      --  The body.  A lower segment reaches a pixel up into the one above
      --  and is 0.2 px thinner, so bending opens no gap and no faces lie
      --  in one plane to fight.
      Pelvis_B := Add (Pelvis, (-Float (Pelvis_W) / 2.0, -Float (Pelvis_D) / 2.0, 0.0),
                       (Float (Pelvis_W), Float (Pelvis_D), Float (Pelvis_P)), Taper => -Waist);
      declare
         Cw : constant Float := Float (Chest_W) - (if Chest_W = Pelvis_W then 0.2 else 0.0);
         Cd : constant Float := Float (Chest_D) - (if Chest_D = Pelvis_D then 0.2 else 0.0);
      begin
         Chest_B := Add (Chest, (-Cw / 2.0, -Cd / 2.0, -1.0), (Cw, Cd, Float (Chest_P) + 1.0), Taper => Waist);
      end;
      Head_B := Add (Head, (-3.0, -3.0, 0.0), (6.0, 6.0, 6.0), Taper => Jaw_Taper);
      B.Boxes (Head_B).Round := Head_Round;
      Upper_L := Add (Upper_Arm_L, (-Float (Arm_W) / 2.0, -Float (Arm_W) / 2.0, -Float (Upper_P)),
                      (Float (Arm_W), Float (Arm_W), Float (Upper_P)), Taper => 0.5 * Limb_Taper);
      Fore_L := Add (Forearm_L, (-(Float (Arm_W) - 0.2) / 2.0, -(Float (Arm_W) - 0.2) / 2.0, -Float (Fore_P)),
                     (Float (Arm_W) - 0.2, Float (Arm_W) - 0.2, Float (Fore_P) + 1.0), Taper => Limb_Taper);
      Hand_L_B := Add (Hand_L, (-1.0, -1.0, -2.0), (2.0, 2.0, 2.0));
      Thigh_L_B := Add (Thigh_L, (-Float (Leg_W) / 2.0, -Float (Leg_W) / 2.0, -Float (Thigh_P)),
                        (Float (Leg_W), Float (Leg_W), Float (Thigh_P) + 1.0), Taper => 0.5 * Limb_Taper);
      Shin_L_B := Add (Shin_L, (-(Float (Leg_W) - 0.2) / 2.0, -(Float (Leg_W) - 0.2) / 2.0, -Float (Shin_P)),
                       (Float (Leg_W) - 0.2, Float (Leg_W) - 0.2, Float (Shin_P) + 1.0), Taper => Limb_Taper);
      Foot_L_B := Add (Foot_L, (-Float (Leg_W) / 2.0, -1.5, -2.0), (Float (Leg_W), 5.0, 2.0));
      Upper_R := Mirror_Box (Upper_L);
      Fore_R := Mirror_Box (Fore_L);
      Hand_R_B := Mirror_Box (Hand_L_B);
      Thigh_R_B := Mirror_Box (Thigh_L_B);
      Shin_R_B := Mirror_Box (Shin_L_B);
      Foot_R_B := Mirror_Box (Foot_L_B);
      --  The tunic's skirt (a dress for women): a little wider than the hips,
      --  from just under the belt down.
      Skirt_B := Add (Pelvis, (-Float (Pelvis_W) / 2.0 - 0.5, -Float (Pelvis_D) / 2.0 - 0.5, -Float (Skirt_Bottom)),
                      (Float (Pelvis_W) + 1.0, Float (Pelvis_D) + 1.0, Float (Skirt_Bottom + Pelvis_P - 1)),
                      Taper => -(if Is_Man or else Child then 0.5 else 1.0) * Skirt_Flare);

      --  Hair and beards that stand out from the head.
      declare
         Dummy : Positive;
      begin
         case G.Hair_Style is
            when Long =>
               if not G.Coif then
                  Dummy := Add (Head, (-2.5, -3.5, -3.0), (5.0, 1.0, 7.0));
               end if;
            when Bun =>
               if not G.Coif then
                  Dummy := Add (Head, (-1.0, -4.0, 3.0), (2.0, 1.0, 2.0));
               end if;
            when Braids =>
               if not G.Coif then
                  Dummy := Add (Head, (-2.5, -3.5, -4.0), (1.0, 1.0, 6.0));
                  Dummy := Add (Head, (1.5, -3.5, -4.0), (1.0, 1.0, 6.0));
               end if;
            when others => null;
         end case;
         if G.Coif then
            Coif_B := Add (Head, (-2.0, -3.5, -2.0), (4.0, 1.0, 3.0));   --  the kerchief's knot and tails
         end if;
         if G.Beard = Full_Beard then
            Dummy := Add (Head, (-2.0, 2.5, -1.5), (4.0, 1.0, 3.0));
         end if;
      end;

      --  Winter: its cloak down the back (unless it is off: asleep, it lies
      --  under it) and a hood (its face open).
      if O.Winter then
         if not O.Cloak_Off then
            Cloak_B := Add (Chest, (-Float (Chest_W) / 2.0 - 0.5, -Float (Chest_D) / 2.0 - 1.5,
                                    -Float (Pelvis_P + Thigh_P - 1)),
                            (Float (Chest_W) + 1.0, 1.0, Float (Chest_P + Pelvis_P + Thigh_P - 1)));
         end if;
         Hood_B := Add (Head, (-4.0, -4.5, -1.5), (8.0, 8.0, 8.0), Cutout => True);
      end if;

      --  Gear on the back or at the hip.  (A forester's axe and a hunter's
      --  bow are things of their own, Castle.Props, which Castle.Serfs
      --  carries: stowed, or in the hand at work.)
      declare
         Sx   : constant Float := (if G.Hand = Right then -1.0 else 1.0);   --  the off side of the hips
      begin
         if not Child then
            case O.Job is
               when Gatherer =>
                  Basket_B := Add (Chest, (-2.5, -Float (Chest_D) / 2.0 - (if O.Winter then 5.5 else 4.5),
                                           Float (Chest_P) - 6.0), (5.0, 4.0, 5.0),
                                   Taper => 0.15);                               --  basket on the back
               when Porter =>
                  Sack_B := Add (Chest, (-2.5, -Float (Chest_D) / 2.0 - (if O.Winter then 4.5 else 3.5),
                                         Float (Chest_P) - 7.0), (5.0, 3.0, 6.0));     --  sack on the back
               when Lord =>
                  Scabbard_B := Add (Pelvis, (Sx * (Float (Pelvis_W) / 2.0 + 1.0) - 0.5, -0.5, -11.0),
                                     (1.0, 1.0, 12.0));
                  Guard_B := Add (Pelvis, (Sx * (Float (Pelvis_W) / 2.0 + 1.0) - 0.5, -1.5, 1.0),
                                  (1.0, 3.0, 1.0));
               when Idle | Forester | Hunter => null;
            end case;
         end if;
      end;

      ------------------------------------------------- pack the nets

      declare
         Fits : Boolean;
      begin
         Pack_Nets (B, Count, Fits);
         if not Fits then
            raise Program_Error with "serf skin overflow: " & Describe (G, O);
         end if;
      end;
      B.Count := Count;

      ------------------------------------------------- paint

      Paint_Head;

      --  the tunic (or dress) over chest, hips and skirt
      if O.Job = Hunter and then not Child then
         Fill (Chest_B, Leather, 0.12);                            --  a leather jerkin
         for T in 1 .. B.Boxes (Chest_B).H - 2 loop
            Texel (Chest_B, Pos_Y, B.Boxes (Chest_B).W / 2, T,
                   (if T mod 2 = 0 then Times (Leather, 1.25) else Times (Leather, 0.6)));
         end loop;
      else
         Fill (Chest_B, Tunic, 0.08);
      end if;
      declare
         W : constant Natural := B.Boxes (Chest_B).W;
      begin
         --  the neckline: a V for men, round for women
         if Is_Man then
            for Sd in Side loop
               Texel (Chest_B, Pos_Y, Side_Col (W, Sd, 0), 1, G.Skin, 0.03);
               Texel (Chest_B, Pos_Y, Side_Col (W, Sd, 0), 2, G.Skin, 0.03);
            end loop;
         else
            for S in 2 .. W - 3 loop
               Texel (Chest_B, Pos_Y, S, 1, G.Skin, 0.03);
            end loop;
         end if;
         if O.Job = Lord then
            for S in 0 .. W - 1 loop
               Texel (Chest_B, Pos_Y, S, 2, Gold);       --  embroidered trim under the neck
            end loop;
         end if;
         if O.Job = Gatherer and then not Child then
            for T in 3 .. B.Boxes (Chest_B).H - 1 loop  --  an apron's bib
               for S in 1 .. W - 2 loop
                  Texel (Chest_B, Pos_Y, S, T, Linen, 0.05);
               end loop;
            end loop;
         end if;
      end;
      Fill (Pelvis_B, Tunic, 0.08);
      Fill (Skirt_B, Tunic, 0.08);
      Band (Skirt_B, 0, 1, Belt, 0.1);
      Band_Up (Skirt_B, 0, 1, Trim, 0.06);
      declare
         W : constant Natural := B.Boxes (Skirt_B).W;
      begin
         Texel (Skirt_B, Pos_Y, W / 2, 0, (if O.Job = Lord then Gold else C8 (170, 160, 130)));   --  buckle
         if O.Job = Gatherer and then not Child then
            for T in 1 .. B.Boxes (Skirt_B).H - 2 loop
               for S in 1 .. W - 2 loop
                  Texel (Skirt_B, Pos_Y, S, T, Linen, 0.05);
               end loop;
            end loop;
         end if;
      end;

      --  the left limbs; the right are their mirror images
      Fill (Upper_L, (if O.Job = Hunter and then not Child then Times (Tunic, 0.9) else Tunic), 0.08);
      if Long_Sleeves then
         Fill (Fore_L, Tunic, 0.08);
         Band_Up (Fore_L, 0, 1, Times (Tunic, 0.8), 0.06);         --  cuff
      else
         Fill (Fore_L, G.Skin, 0.03);
         Band (Fore_L, 0, 1, Times (Tunic, 0.85), 0.06);           --  the sleeve's end
      end if;
      Fill (Hand_L_B, G.Skin, 0.03);
      Fill (Thigh_L_B, Hose, 0.07);
      Fill (Shin_L_B, Hose, 0.07);
      if O.Winter then
         for T in 0 .. B.Boxes (Shin_L_B).H - 1 loop               --  leg wraps
            if T mod 2 = 0 then
               Band (Shin_L_B, T, 1, Times (Hose, 1.15), 0.05);
            end if;
         end loop;
      end if;
      Band_Up (Shin_L_B, 0, 1, Shoe, 0.08);
      Fill (Foot_L_B, Shoe, 0.1);
      Fill_Face (Foot_L_B, Neg_Z, Times (Shoe, 0.6), 0.05);
      Copy_Mirrored (Upper_L, Upper_R);
      Copy_Mirrored (Fore_L, Fore_R);
      Copy_Mirrored (Hand_L_B, Hand_R_B);
      Copy_Mirrored (Thigh_L_B, Thigh_R_B);
      Copy_Mirrored (Shin_L_B, Shin_R_B);
      Copy_Mirrored (Foot_L_B, Foot_R_B);
      --  and then not quite: one sleeve pushed up
      if Roll_One then
         declare
            F : constant Positive := (if Rolled = Left then Fore_L else Fore_R);
         begin
            Fill (F, G.Skin, 0.03);
            Band (F, 0, 1, Times (Tunic, 0.85), 0.06);
         end;
      end if;

      --  the boxes added after the body: hair, beard, kerchief, cloak, hood
      for K in Skirt_B + 1 .. Count loop
         declare
            Bx : constant Box := B.Boxes (K);
         begin
            if K = Hood_B then
               Fill (K, Hood_C, 0.1);
               --  the face opening: see-through, framed by a pixel of hood
               for T in 2 .. 6 loop
                  for S in 1 .. Bx.W - 2 loop
                     Texel (K, Pos_Y, S, T, Hood_C, 0.0, Alpha => 0);
                  end loop;
               end loop;
               Fill_Face (K, Neg_Z, Times (Hood_C, 0.7), 0.05);
            elsif K = Cloak_B then
               Fill (K, Cloak_C, 0.1);
               Band (K, 0, 1, Times (Cloak_C, 1.2), 0.05);
            elsif K = Coif_B then
               Fill (K, Linen, 0.05);
            elsif Bx.On = Head then
               Fill (K, G.Hair, 0.18);                             --  hair, braids, beard
            end if;
         end;
      end loop;
      if Basket_B > 0 then
         Weave (Basket_B, Straw, Times (Straw, 0.75));
      end if;
      if Sack_B > 0 then
         Fill (Sack_B, Burlap, 0.14);
         Band (Sack_B, 0, 1, Times (Burlap, 0.6), 0.1);
      end if;
      if Scabbard_B > 0 then
         Fill (Scabbard_B, Dark_Leather, 0.08);
         Band_Up (Scabbard_B, 0, 1, Gold, 0.0);
         Fill (Guard_B, Iron, 0.05);
      end if;
   end Build;

   function Describe (G : Genome; O : Outfit) return String is
      Who : constant String :=
        (if G.Age < 15.0 then (if G.Sex = Male then "boy" else "girl")
         else (if G.Sex = Male then "man" else "woman"));
      Job : constant String := Ada.Characters.Handling.To_Lower (Job_Kind'Image (O.Job));
      Cm  : constant Natural := Natural (G.Height * 100.0);
   begin
      return Who & "," & Natural'Image (Natural (Float'Floor (G.Age))) & ","
        & Natural'Image (Cm / 100) & "." & (if Cm mod 100 < 10 then "0" else "")
        & Natural'Image (Cm mod 100) (2 .. Natural'Image (Cm mod 100)'Last) & " m, " & Job
        & (if O.Winter then ", winter" else "");
   end Describe;

end Castle.Bodies;
