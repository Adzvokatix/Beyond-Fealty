with Ada.Unchecked_Deallocation;
with Interfaces;    use Interfaces;
with Castle.Colors; use Castle.Colors;
with Castle.Hash;   use Castle.Hash;

package body Castle.Textures is

   procedure Free_Data is new Ada.Unchecked_Deallocation (Texel_Data, Texel_Access);

   procedure Free (T : in out Texture_Set) is
   begin
      if T.Detail /= null then
         Free_Data (T.Detail);
      end if;
      if T.Variant /= null then
         Free_Data (T.Variant);
      end if;
      if T.Overall /= null then
         Free_Data (T.Overall);
      end if;
   end Free;

   function Detail (Seed : U64) return Texel_Access is
      T : constant Texel_Access := new Texel_Data (0 .. Layers * Size * Size * 4 - 1);

      function Byte (V : Float) return Unsigned_8 is
        (Unsigned_8 (Float'Max (0.0, Float'Min (255.0, V))));
   begin
      for M in Material loop
         for V in 0 .. Variants - 1 loop
            for Ty in 0 .. Size - 1 loop
               for Tx in 0 .. Size - 1 loop
                  declare
                     Mp : constant Integer := Material'Pos (M);
                     Ti : constant Integer := Ty * Size + Tx;
                     H  : constant Float := Unit_3 (Seed, Mp, V, Ti);
                     H2 : constant Float := Unit_3 (Seed + 1, Mp, V, Ti);
                     C  : constant RGB := Base_Color (M);
                     R  : Float := Float (C.R);
                     G  : Float := Float (C.G);
                     B  : Float := Float (C.B);
                     A  : Float := 255.0;
                     K  : Float := 0.88 + 0.24 * H;   --  texel brightness jitter
                     Blade : constant Integer :=
                       2 + Integer (Float'Floor (3.0 * Unit_3 (Seed + 2, Mp, V, Tx)));
                     I  : constant Natural := (((Mp * Variants + V) * Size + Ty) * Size + Tx) * 4;

                     procedure Paint (Hex : Hex_Code; Jitter : Boolean := False) is
                        P : constant RGB := Of_Hex (Hex);
                     begin
                        R := Float (P.R);
                        G := Float (P.G);
                        B := Float (P.B);
                        if not Jitter then
                           K := 1.0;
                        end if;
                     end Paint;
                  begin
                     case M is
                        when Air =>
                           A := 0.0;
                        when Plank =>
                           if Ty = 0 then
                              K := K * 0.72;                  --  seam between boards
                           end if;
                        when Shingle =>
                           if Ty = 0 or else (Tx + 2 * V) mod 5 = 0 then
                              K := K * 0.74;                  --  overlap and splits
                           end if;
                        when Fieldstone =>
                           --  stones of all sizes laid dry: each texel its own grey, dark joints between courses
                           --  and here and there down through one
                           K := 0.8 + 0.4 * H;
                           if Ty = 0 or else (Tx + 3 * V) mod 4 = 0 then
                              K := K * 0.62;
                           end if;
                        when Daub =>
                           --  a hand-laid plaster: mottled, a crack here and there
                           K := 0.93 + 0.12 * H;
                           if H2 > 0.93 then
                              K := K * 0.8;
                           end if;
                        when Thatch =>
                           --  courses of straw: a dark line where one overlaps the
                           --  next, the stalks running down the roof between
                           if Ty = 0 then
                              K := K * 0.7;
                           elsif (Tx + V) mod 2 = 0 then
                              K := K * 0.9;
                           end if;
                        when Log =>
                           if Tx mod 2 = 0 then
                              K := K * 0.82;                  --  bark furrows
                           end if;
                        when Aspen_Log =>
                           --  pale bark, smooth, with the dark scars aspens carry
                           K := 0.95 + 0.1 * H;
                           if (Ty + V) mod 3 = 0 and then H2 > 0.45 then
                              Paint (Charcoal, Jitter => True);
                           end if;
                        when Pine_Log =>
                           --  plates: offset in rows, dark cracks between them
                           if (Tx + (if (Ty / 2) mod 2 = 0 then 0 else 1)) mod 3 = 0 then
                              K := K * 0.7;
                           elsif Ty mod 2 = 0 and then H2 > 0.6 then
                              K := K * 0.85;
                           end if;
                        when Grass =>
                           if H2 > 0.8 then
                              R := R * 1.12;
                              G := G * 1.12;
                           end if;
                        when Crown | Berry_Bush | Bare_Bush =>
                           if H2 < 0.22 then
                              A := 0.0;                       --  gaps in the foliage
                           elsif M = Apple_Leaves and then Ti = (7 * V + 6) mod 25 then
                              Paint (Brightened_Crimson);     --  an apple
                           elsif M = Berry_Bush and then H2 > 0.86 then
                              Paint (Heraldic_Crimson);       --  berries
                           end if;
                        when Wild_Vegetables =>
                           --  broad leaves in a rosette from the ground, tallest in the
                           --  middle; at the foot the top of the root shows: a wild carrot,
                           --  a turnip, a parsnip or an onion (by variant)
                           declare
                              Leaf_H : constant Integer :=
                                (case Tx is when 2 => 4, when 1 | 3 => 3, when others => 2)
                                - (if H2 > 0.8 then 1 else 0);
                           begin
                              if Ty = 0 then
                                 if Tx in 1 .. 3 then
                                    Paint ((case V is
                                               when 0 => Warm_Copper,
                                               when 1 => Salt_Pale,
                                               when 2 => Sand_Tan,
                                               when others => Brightened_Gold), Jitter => True);
                                 else
                                    A := 0.0;
                                 end if;
                              elsif Ty > Leaf_H then
                                 A := 0.0;
                              elsif Tx = 2 and then Ty <= 2 then
                                 K := K * 1.18;                  --  the pale rib up the middle
                              end if;
                           end;
                        when Tall_Grass | Wild_Grain =>
                           if Tx mod 2 = 1 or else Ty >= Blade then
                              A := 0.0;                       --  blades rise from the bottom
                           elsif M = Wild_Grain and then Ty = Blade - 1 then
                              Paint (Brightened_Gold, Jitter => True);   --  the ear
                           end if;
                        when Water =>
                           A := 255.0;                        --  the water pass blends it
                           K := 0.94 + 0.12 * H;
                        when Coal | Iron_Ore | Bog_Iron | Silver_Ore | Gold_Ore
                           | Rock_Salt | Placer_Gravel =>
                           if H2 > 0.74 then
                              K := K * 1.35;                  --  glints
                           elsif H2 < 0.2 then
                              K := K * 0.75;
                           end if;
                        when Footpath =>
                           if H2 > 0.78 then
                              K := K * 0.8;                   --  trodden stones
                           end if;
                        when others =>
                           null;
                     end case;
                     T (I)     := Byte (R * K);
                     T (I + 1) := Byte (G * K);
                     T (I + 2) := Byte (B * K);
                     T (I + 3) := Byte (A);
                  end;
               end loop;
            end loop;
         end loop;
      end loop;
      return T;
   end Detail;

   type Sum is record
      R, G, B, A : Float := 0.0;   --  colour weighted by alpha, and alpha
   end record;

   procedure Add (S : in out Sum; R, G, B, A : Float) is
   begin
      S := (S.R + R * A, S.G + G * A, S.B + B * A, S.A + A);
   end Add;

   procedure Store (T : Texel_Access; I : Natural; S : Sum; Count : Positive) is
      function Byte (V : Float) return Unsigned_8 is
        (Unsigned_8 (Float'Max (0.0, Float'Min (255.0, Float'Rounding (V)))));
      W : constant Float := (if S.A > 0.0 then 1.0 / S.A else 0.0);
   begin
      T (I)     := Byte (S.R * W);
      T (I + 1) := Byte (S.G * W);
      T (I + 2) := Byte (S.B * W);
      T (I + 3) := Byte (S.A * 255.0 / Float (Count));
   end Store;

   function Generate (Seed : U64) return Texture_Set is
      D   : constant Texel_Access := Detail (Seed);
      Var : constant Texel_Access := new Texel_Data (0 .. Layers * 2 * 2 * 4 - 1);
      All_V : constant Texel_Access := new Texel_Data (0 .. Layers * 4 - 1);
   begin
      for M in 0 .. Layers / Variants - 1 loop
         declare
            Mat_Sum : Sum;
         begin
            for V in 0 .. Variants - 1 loop
               declare
                  L : constant Natural := M * Variants + V;
                  S : Sum;
               begin
                  for K in 0 .. Size * Size - 1 loop
                     declare
                        I : constant Natural := (L * Size * Size + K) * 4;
                     begin
                        Add (S, Float (D (I)), Float (D (I + 1)), Float (D (I + 2)),
                             Float (D (I + 3)) / 255.0);
                     end;
                  end loop;
                  for K in 0 .. 3 loop
                     Store (Var, (L * 4 + K) * 4, S, Size * Size);
                  end loop;
                  declare
                     Avg : constant Natural := (L * 4) * 4;   --  one of the four, all equal
                  begin
                     Add (Mat_Sum, Float (Var (Avg)), Float (Var (Avg + 1)), Float (Var (Avg + 2)),
                          Float (Var (Avg + 3)) / 255.0);
                  end;
               end;
            end loop;
            for V in 0 .. Variants - 1 loop
               Store (All_V, (M * Variants + V) * 4, Mat_Sum, Variants);
            end loop;
         end;
      end loop;
      return (Detail => D, Variant => Var, Overall => All_V);
   end Generate;

end Castle.Textures;
