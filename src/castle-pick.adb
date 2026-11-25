with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Castle.Colony;
with Castle.Deer;
with Castle.Herds;

package body Castle.Pick is

   Body_R  : constant := 0.3;    --  a person, for pointing at
   Lying_Z : constant := 0.18;   --  the middle of a body on its back, above the ground
   Goods_H  : constant := 0.5;   --  what lies in a stockpile cell stands about this high
   Hearth_H : constant := 1.3;   --  the fire, the pot and its crossbar
   Level_M  : constant := 0.6;   --  zoned ground is this near its zone's own level (a crown over it is not)
   Hide_M  : constant := 0.25;   --  a body this far past where the ray goes into the ground still shows

   function Standing (Feet : Vec3; Height : Float) return Capsule is
     ((A => Feet + (0.0, 0.0, Body_R), B => Feet + (0.0, 0.0, Float'Max (Body_R, Height - 0.5 * Body_R)), R => Body_R));

   function Lying (Feet : Vec3; Heading, Height : Float) return Capsule is
      Back : constant Vec3 := (-Cos (Heading), -Sin (Heading), 0.0);
   begin
      return (A => Feet + (0.0, 0.0, Lying_Z), B => Feet + Back * Height + (0.0, 0.0, Lying_Z), R => Body_R);
   end Lying;

   function Colony_Person (I : Positive) return Capsule is
      use Castle.Colony;
      P : constant Vec3 := Where (I);
      H : constant Float := Genome_Of (I).Height;
   begin
      if Doing (I) in Sleeping | Dead then
         declare
            S : constant Vec3 := Work_Spot (I);
         begin
            return Lying (P, Heading_Of (S - P, 0.0), H);
         end;
      elsif Doing (I) = Eating_Seated then
         return Standing (P, 0.75 * H);
      end if;
      return Standing (P, H);
   end Colony_Person;

   function Herd_Deer (K : Positive) return Capsule is
      D : constant Castle.Deer.Dims := Castle.Deer.Dims_Of (Castle.Herds.Class_Of (K));
      P : constant Vec3 := Castle.Herds.Where (K, Castle.Colony.Blend);
      R : constant Float := Float'Max (0.3, 0.5 * D.Spine);
   begin
      return (A => P + (0.0, 0.0, R), B => P + (0.0, 0.0, Float'Max (R, D.Shoulder_H + 0.2 * D.Size)), R => R);
   end Herd_Deer;

   People_Src : Shape_Source := Colony_Person'Access;
   Deer_Src   : Shape_Source := Herd_Deer'Access;

   procedure Set_Shapes (People, Deer : Shape_Source) is
   begin
      People_Src := (if People = null then Colony_Person'Access else People);
      Deer_Src := (if Deer = null then Herd_Deer'Access else Deer);
   end Set_Shapes;

   --  The ray From + T * Dir, T in 0 .. L, against the axis of C: how near
   --  they come (Gap) and where on the ray (T).
   procedure Approach (From, Dir : Vec3; L : Float; C : Capsule; T, Gap : out Float) is
      D1 : constant Vec3 := Dir * L;
      D2 : constant Vec3 := C.B - C.A;
      Rv : constant Vec3 := From - C.A;
      A  : constant Float := Dot (D1, D1);
      E  : constant Float := Dot (D2, D2);
      F  : constant Float := Dot (D2, Rv);
      Cc : constant Float := Dot (D1, Rv);
      S, U : Float;
      function Clamp (V : Float) return Float is (Float'Max (0.0, Float'Min (1.0, V)));
   begin
      if A <= 1.0E-12 then
         S := 0.0;
         U := (if E > 1.0E-12 then Clamp (F / E) else 0.0);
      elsif E <= 1.0E-12 then
         U := 0.0;
         S := Clamp (-Cc / A);
      else
         declare
            B     : constant Float := Dot (D1, D2);
            Denom : constant Float := A * E - B * B;
         begin
            S := (if Denom > 1.0E-9 then Clamp ((B * F - Cc * E) / Denom) else 0.0);
            U := (B * S + F) / E;
            if U < 0.0 then
               U := 0.0;
               S := Clamp (-Cc / A);
            elsif U > 1.0 then
               U := 1.0;
               S := Clamp ((B - Cc) / A);
            end if;
         end;
      end if;
      declare
         V : constant Vec3 := (From + D1 * S) - (C.A + D2 * U);
      begin
         Gap := Sqrt (Dot (V, V));
         T := S * L;
      end;
   end Approach;

   --  Where the ray goes into the box Lo .. Hi (T, metres), if it does
   --  within L.
   function Enters (From, Dir : Vec3; L : Float; Lo, Hi : Vec3; T : out Float) return Boolean is
      T0 : Float := 0.0;
      T1 : Float := L;
      procedure Slab (O, D, A, B : Float; Ok : in out Boolean) is
      begin
         if abs D < 1.0E-9 then
            Ok := Ok and then O >= A and then O <= B;
         else
            declare
               Ta : constant Float := (A - O) / D;
               Tb : constant Float := (B - O) / D;
            begin
               T0 := Float'Max (T0, Float'Min (Ta, Tb));
               T1 := Float'Min (T1, Float'Max (Ta, Tb));
            end;
         end if;
      end Slab;
      Ok : Boolean := True;
   begin
      Slab (From.X, Dir.X, Lo.X, Hi.X, Ok);
      Slab (From.Y, Dir.Y, Lo.Y, Hi.Y, Ok);
      Slab (From.Z, Dir.Z, Lo.Z, Hi.Z, Ok);
      T := T0;
      return Ok and then T0 <= T1;
   end Enters;

   function Look
     (From, Dir : Vec3;
      Ground    : Castle.Rays.Hit;
      Reach     : Float := No_Limit;
      Slack     : Float := 0.0;
      Keep      : Thing := (others => <>);
      Cast      : Caster := null) return Thing
   is
      Far   : constant Float := 2_000.0;

      --  Houses drawn turned (the spec, Cast).
      type Turned_Look is record
         House  : Natural := 0;      --  the house drawn turned that the ray meets as it is drawn (0: none),
         T      : Float := 0.0;      --  and where along the ray
         Unseen : Natural := 0;      --  the turned house, of whose walls as they stand Ground is a block
         Past   : Float := 0.0;      --  with Unseen: where the ray comes to the level of its pad
      end record;
      function Pad_Row (V : Castle.Colony.House_View) return Integer is (Integer (Float'Rounding (V.Corner (1).Z * 4.0)));
      function Look_Turned return Turned_Look is
         use Castle.Colony;
         TL : Turned_Look;
         Gp : constant Vec3 := From + Dir * Ground.Dist;
      begin
         if Ground.Found then
            declare
               H : constant Natural := House_On (Gp.X + 0.1 * Dir.X, Gp.Y + 0.1 * Dir.Y);
            begin
               --  (and the ground itself within the walls, as they stand, of a house that is walked
               --  where it is drawn, come to by the ray through a doorway of it as it stands: that
               --  ground is walked whatever is dug or built there, and is not the cursor's)
               if H > 0 and then House_At (H).Turn /= 0.0
                 and then (Ground.Z >= Pad_Row (House_At (H))
                           or else (House_At (H).Walked_Drawn and then Ground.Z >= Pad_Row (House_At (H)) - 1))
               then
                  TL.Unseen := H;
                  TL.Past := (if Dir.Z < -1.0E-4 then (House_At (H).Corner (1).Z - From.Z) / Dir.Z else Far);
               end if;
            end;
         end if;
         TL.T := Float'Last;
         for K in 1 .. House_Count loop
            declare
               V : constant House_View := House_At (K);
            begin
               if V.Turn /= 0.0 then
                  declare
                     C  : constant Float := Cos (V.Turn);
                     S  : constant Float := Sin (V.Turn);
                     D0 : constant Vec3 := From - V.Pivot;
                     --  (the ray taken back through its turn: to the house as it stands)
                     F2 : constant Vec3 := (V.Pivot.X + C * D0.X + S * D0.Y, V.Pivot.Y - S * D0.X + C * D0.Y, From.Z);
                     D2 : constant Vec3 := (C * Dir.X + S * Dir.Y, -S * Dir.X + C * Dir.Y, Dir.Z);
                     Lo : Vec3 := V.Corner (1);
                     Hi : Vec3 := V.Corner (1);
                     T0 : Float;
                  begin
                     for Cn of V.Corner loop
                        Lo := (Float'Min (Lo.X, Cn.X), Float'Min (Lo.Y, Cn.Y), Lo.Z);
                        Hi := (Float'Max (Hi.X, Cn.X), Float'Max (Hi.Y, Cn.Y), Hi.Z);
                     end loop;
                     Lo := Lo - (0.3, 0.3, 0.0);
                     Hi := (Hi.X + 0.3, Hi.Y + 0.3, V.Top_Z + 0.3);
                     if Enters (F2, D2, Far, Lo, Hi, T0) then
                        declare
                           Start : constant Float := Float'Max (0.0, T0 - 0.05);
                           H2    : constant Castle.Rays.Hit := Cast (F2 + D2 * Start, D2, 40.0);
                           P2    : constant Vec3 := F2 + D2 * (Start + H2.Dist);
                        begin
                           if H2.Found and then H2.Z >= Pad_Row (V)
                             and then House_On (P2.X + 0.1 * D2.X, P2.Y + 0.1 * D2.Y) = K
                             and then Start + H2.Dist < TL.T
                             --  (nothing seen stands before it)
                             and then (TL.Unseen > 0 or else not Ground.Found or else Start + H2.Dist <= Ground.Dist + 0.3)
                           then
                              TL.House := K;
                              TL.T := Start + H2.Dist;
                           end if;
                        end;
                     end if;
                  end;
               end if;
            end;
         end loop;
         return TL;
      end Look_Turned;
      TL : constant Turned_Look :=
        (if Cast /= null and then Castle.Colony.House_Count > 0 then Look_Turned else (others => <>));
      --  how far along the ray the ground that is seen lies
      Seen_T : constant Float := (if TL.Unseen > 0 then TL.Past else Ground.Dist);
      --  how far along the ray anything can still be seen: to the ground, and a little into it
      --  (and no further than a house drawn turned that the ray meets: its walls are in the way
      --  as they are drawn, though no block stands there for the ray to walk into)
      Sight : constant Float :=
        Float'Min ((if Ground.Found then Seen_T + Hide_M else Far), (if TL.House > 0 then TL.T + Hide_M else Far));
      L     : constant Float := Float'Min (Sight, (if Reach < Far then Reach + 1.0 else Far));
      R     : Thing;

      Hit_Kind  : Thing_Kind := Nothing;     --  a body the ray passes through: the nearest
      Hit_Index : Natural := 0;
      Hit_T     : Float := Float'Last;
      Near_Kind : Thing_Kind := Nothing;     --  failing that, the one it comes nearest, within the slack
      Near_Index : Natural := 0;
      Near_Miss : Float := Float'Last;
      Near_T    : Float := 0.0;
      Kept_T    : Float := -1.0;             --  where the ray goes into what Keep names, if it still does

      procedure Try (Kind : Thing_Kind; Index : Positive; C : Capsule) is
         T, Gap : Float;
      begin
         if C.R <= 0.0 then
            return;
         end if;
         Approach (From, Dir, L, C, T, Gap);
         if Gap <= C.R then
            declare
               In_T : constant Float := Float'Max (0.0, T - Sqrt (Float'Max (0.0, C.R * C.R - Gap * Gap)));
            begin
               if Kind = Keep.Kind and then Index = Keep.Index then
                  Kept_T := In_T;                   --  the one pointed at a moment ago, still under the ray
               end if;
               if In_T < Hit_T then
                  Hit_T := In_T;
                  Hit_Kind := Kind;
                  Hit_Index := Index;
               end if;
            end;
         elsif Gap <= C.R + Slack * T and then Gap - C.R < Near_Miss then
            Near_Miss := Gap - C.R;
            Near_Kind := Kind;
            Near_Index := Index;
            Near_T := T;
         end if;
      end Try;
   begin
      R.Ground := Ground;
      R.Turned := TL.House > 0 or else TL.Unseen > 0;
      for I in 1 .. Castle.Colony.Members loop
         Try (A_Person, I, People_Src (I));
      end loop;
      for K in 1 .. Castle.Herds.Deer_Slots loop
         if Castle.Herds.Alive (K) then
            Try (A_Deer, K, Deer_Src (K));
         end if;
      end loop;
      if Kept_T >= 0.0 then
         Hit_Kind := Keep.Kind;
         Hit_Index := Keep.Index;
         Hit_T := Kept_T;
      end if;
      if Hit_Kind = Nothing and then Near_Kind /= Nothing then
         Hit_Kind := Near_Kind;
         Hit_Index := Near_Index;
         Hit_T := Near_T;
      end if;
      if Hit_Kind /= Nothing then
         R.Kind := Hit_Kind;
         R.Index := Hit_Index;
         R.Dist := Hit_T;
         R.Point := From + Dir * Hit_T;
      else
         --  a zone: its goods, if the ray goes into them (a cell's heap, the
         --  hearth), else the ground the ray lands on, if that is zoned
         declare
            use Castle.Colony;
            Best   : Natural := 0;
            Best_T : Float := Float'Last;
            T      : Float;
            Gp     : constant Vec3 := From + Dir * Seen_T;
            --  the house whose ground (X, Y) is: one drawn turned, where it is drawn
            function House_Under (X, Y : Float) return Natural is
               H : constant Natural := House_On (X, Y);
            begin
               if Cast /= null then
                  for K in 1 .. House_Count loop
                     if House_At (K).Turn /= 0.0 and then House_Drawn_On (K, X, Y, 0.25) then
                        return K;
                     end if;
                  end loop;
               end if;
               return (if H > 0 and then Cast /= null and then House_At (H).Turn /= 0.0 then 0 else H);
            end House_Under;
         begin
            for K in 1 .. Cell_Count loop
               declare
                  C : constant Cell_View := Cell_At (K);
               begin
                  if C.Count > 0
                    and then Enters (From, Dir, L, C.Centre + (-0.5, -0.5, 0.0), C.Centre + (0.5, 0.5, Goods_H), T)
                    and then T < Best_T
                  then
                     Best_T := T;
                     Best := Zone_Of_Cell (K);
                  end if;
               end;
            end loop;
            if Has_Camp and then Camp_State.Built
              and then Enters (From, Dir, L, Camp + (-0.6, -0.6, 0.0), Camp + (0.6, 0.6, Hearth_H), T)
              and then T < Best_T
            then
               Best_T := T;
               Best := Camp_Zone;
            end if;
            --  the lord's cart: the ray lands on its bed, or on the ground under it
            if Best = 0 and then Ground.Found and then Cart.Here
              and then Cart_On (Gp.X + 0.05 * Dir.X, Gp.Y + 0.05 * Dir.Y)
              and then Gp.Z >= Cart.At_P.Z - 2.0 * Level_M and then Gp.Z <= Cart.At_P.Z + 1.5
            then
               R.Kind := A_Cart;
               R.Index := 1;
               R.Dist := Ground.Dist;
               R.Point := Gp;
               if R.Dist > Reach then
                  R.Kind := Nothing;
                  R.Index := 0;
               end if;
               return R;
            end if;
            --  a house drawn turned: the ray meets it as it is drawn
            if Best = 0 and then TL.House > 0 then
               R.Kind := A_House;
               R.Index := TL.House;
               R.Dist := TL.T;
               R.Point := From + Dir * TL.T;
               if R.Dist > Reach then
                  R.Kind := Nothing;
                  R.Index := 0;
               end if;
               return R;
            end if;
            --  a house: what the ray lands on is of it (a wall, the roof, the
            --  ground its walls are to stand on)
            if Best = 0 and then Ground.Found and then House_Count > 0 then
               declare
                  H : constant Natural := House_Under (Gp.X + 0.1 * Dir.X, Gp.Y + 0.1 * Dir.Y);
               begin
                  if H > 0 and then Gp.Z >= House_At (H).Corner (1).Z - 2.0 * Level_M
                    and then Gp.Z <= House_At (H).Top_Z + 2.0 * Level_M
                  then
                     R.Kind := A_House;
                     R.Index := H;
                     R.Dist := Seen_T;
                     R.Point := Gp;
                     if R.Dist > Reach then
                        R.Kind := Nothing;
                        R.Index := 0;
                     end if;
                     return R;
                  end if;
               end;
            end if;
            if Best = 0 and then Ground.Found then
               declare
                  Z   : constant Natural := Zone_On (Gp.X, Gp.Y);
                  Top : constant Float := Zone_Top (Gp.X, Gp.Y);
               begin
                  if Z > 0 and then abs (Gp.Z - Top) <= (if Z = Camp_Zone then 2.0 * Level_M else Level_M) then
                     Best := Z;
                     Best_T := Seen_T;
                  end if;
               end;
            end if;
            if Best > 0 then
               R.Kind := A_Zone;
               R.Index := Best;
               R.Dist := Best_T;
               R.Point := From + Dir * Best_T;
            elsif Ground.Found and then TL.Unseen = 0 then    --  (never a block that is drawn elsewhere)
               R.Kind := A_Block;
               R.Dist := Ground.Dist;
               R.Point := Gp;
            end if;
         end;
      end if;
      if R.Kind /= Nothing and then R.Dist > Reach then
         R.Kind := Nothing;                       --  out of reach
         R.Index := 0;
      end if;
      return R;
   end Look;

end Castle.Pick;
