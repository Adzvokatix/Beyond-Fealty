with Ada.Numerics;
with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Ada.Unchecked_Conversion;
with Ada.Unchecked_Deallocation;
with Castle.Climate;
with Castle.Nav;

package body Castle.Herds is

   use Interfaces;
   use Castle.Hash;
   use type Castle.Nav.Outcome;
   use type Castle.Deer.Standing_Mode;
   use type Castle.Climate.Season;
   Pi : constant := Ada.Numerics.Pi;

   Hours_A_Year : constant := 24.0 * Float (Castle.Climate.Days_Per_Year);

   function Flat_Dist (A, B : Vec3) return Float is (Sqrt ((A.X - B.X) ** 2 + (A.Y - B.Y) ** 2));
   function Turned (V : Vec3; A : Float) return Vec3 is
     ((V.X * Cos (A) - V.Y * Sin (A), V.X * Sin (A) + V.Y * Cos (A), 0.0));
   function Flat_Unit (V : Vec3; Fallback : Vec3) return Vec3 is
     (if Sqrt (V.X * V.X + V.Y * V.Y) > 1.0E-4
      then (V.X / Sqrt (V.X * V.X + V.Y * V.Y), V.Y / Sqrt (V.X * V.X + V.Y * V.Y), 0.0) else Fallback);

   ------------------------------------------------------------------ state

   type Herd_Mode is (Grazing, Moving, Fleeing);

   type Herd_Rec is record
      Used      : Boolean := False;
      Node      : Vec3 := (0.0, 0.0, 0.0);
      Mode      : Herd_Mode := Grazing;
      Timer     : Float := 0.0;            --  grazing: seconds until it moves on
      Route     : Castle.Nav.Route;
      Leg       : Positive := 1;
      Along     : Float := 0.0;
      Pace      : Float := 0.8;
      Bred_Year : Integer := -1;
      Calm      : Float := 99.0;           --  seconds since it last panicked
      Seed      : U64 := 0;
      N         : Natural := 0;            --  draws taken from its seed
   end record;

   type Deer_Rec is record
      Alive  : Boolean := False;
      Herd   : Natural := 0;
      Male   : Boolean := False;
      Born   : Long_Float := 0.0;          --  game hours
      Pos, Prev : Vec3 := (0.0, 0.0, 0.0);
      Spot   : Vec3 := (0.0, 0.0, 0.0);    --  its place round the node
      Spot_T : Float := 0.0;               --  seconds until it picks another
      Act    : Castle.Deer.Standing_Mode := Castle.Deer.Graze;
      Act_T  : Float := 0.0;
      Panic  : Float := 0.0;               --  seconds of panic left
      Dir    : Vec3 := (1.0, 0.0, 0.0);    --  where it bolts
      Pace   : Float := 6.5;
      Seed   : U64 := 0;
      N      : Natural := 0;
      Startle : Float := 0.0;              --  seconds left of its start on a heading of its own
   end record;

   Herds   : array (1 .. Max_Herds) of Herd_Rec;
   N_Herds : Natural := 0;
   Deer    : array (1 .. Max_Deer) of Deer_Rec;
   N_Deer  : Natural := 0;               --  slots used (some may be dead)

   Old_Way   : Boolean := False;         --  Set_Scatter: the herds as they were
   Pending   : Boolean := False;
   Stake_At  : Vec3 := (0.0, 0.0, 0.0);
   Base_Seed : U64 := 1;
   Now       : Long_Float := 0.0;

   function Draw (Seed : U64; N : in out Natural) return Float is
   begin
      N := N + 1;
      return Unit (Hash_2 (Seed, N, 17));
   end Draw;
   function Rnd (H : in out Herd_Rec) return Float is (Draw (H.Seed, H.N));
   function Rnd (D : in out Deer_Rec) return Float is (Draw (D.Seed, D.N));

   ------------------------------------------------------------------ the ground

   --  The floor at (X, Y) a deer at height Z could step onto: up at most a
   --  step, down at most a metre, walkable (not deep water, not a roof);
   --  the nearest such, metres, or -1.
   function Floor_Near (X, Y, Z : Float; Wade : Natural := Castle.Nav.Wade_B) return Float is
      N    : Natural;
      F    : Castle.Nav.Floor_List;
      Zr   : constant Integer := Integer (Float'Floor (Z * 4.0 + 0.5));
      Best : Integer := Integer'Last;
   begin
      Castle.Nav.Floors_At (Integer (Float'Floor (X / Castle.Nav.Cell_M)), Integer (Float'Floor (Y / Castle.Nav.Cell_M)),
                            N, F);
      for I in 1 .. N loop
         if F (I).Speed > 0.0 and then F (I).Water <= Wade
           and then F (I).Z - Zr in -Castle.Nav.Drop_B .. Castle.Nav.Climb_B
           and then abs (F (I).Z - Zr) < abs (Best - Zr)
         then
            Best := F (I).Z;
         end if;
      end loop;
      return (if Best = Integer'Last then -1.0 else Float (Best) * 0.25);
   end Floor_Near;

   --  The rows of water on the floor nearest height Z at (X, Y); none where
   --  there is no floor.
   function Water_At (X, Y, Z : Float) return Natural is
      N    : Natural;
      F    : Castle.Nav.Floor_List;
      Zr   : constant Integer := Integer (Float'Floor (Z * 4.0 + 0.5));
      Best : Integer := Integer'Last;
      Wet  : Natural := 0;
   begin
      Castle.Nav.Floors_At (Integer (Float'Floor (X / Castle.Nav.Cell_M)), Integer (Float'Floor (Y / Castle.Nav.Cell_M)),
                            N, F);
      for I in 1 .. N loop
         if abs (F (I).Z - Zr) < abs (Best - Zr) then
            Best := F (I).Z;
            Wet := F (I).Water;
         end if;
      end loop;
      return Wet;
   end Water_At;

   --  Ground a herd can be on: somewhere to stand at (X, Y) (the highest
   --  floor walked on) under no more than Wade rows of water.
   function Dry_Spot (X, Y : Float; Wade : Natural) return Boolean is
      N : Natural;
      F : Castle.Nav.Floor_List;
   begin
      Castle.Nav.Floors_At (Integer (Float'Floor (X / Castle.Nav.Cell_M)), Integer (Float'Floor (Y / Castle.Nav.Cell_M)),
                            N, F);
      for I in 1 .. N loop
         if F (I).Speed > 0.0 then
            return F (I).Water <= Wade;
         end if;
      end loop;
      return False;
   end Dry_Spot;

   function In_Range (P : Vec3; Inner : Float := 0.0) return Boolean is
     (Flat_Dist (P, Stake_At) <= Range_M and then Flat_Dist (P, Stake_At) >= Inner);

   --  A step of up to Len along Dir, turning aside up to 90 degrees round
   --  what is in the way; False if no way on was found.
   function Step_To (D : in out Deer_Rec; Dir : Vec3; Len : Float) return Boolean is
      Turns : constant array (1 .. 7) of Float := [0.0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5];
   begin
      if Len <= 0.0 then
         return True;
      end if;
      for A of Turns loop
         declare
            V : constant Vec3 := Turned (Dir, A);
            Q : constant Vec3 := (D.Pos.X + V.X * Len, D.Pos.Y + V.Y * Len, D.Pos.Z);
            Z : constant Float := Floor_Near (Q.X, Q.Y, D.Pos.Z);
         begin
            --  in reach of the stake, and no nearer the colony than Near_Stake_M - 10
            --  (or at least no nearer than it was)
            if Z >= 0.0 and then In_Range (Q)
              and then (Flat_Dist (Q, Stake_At) >= Near_Stake_M - 10.0
                        or else Flat_Dist (Q, Stake_At) >= Flat_Dist (D.Pos, Stake_At))
            then
               D.Pos := (Q.X, Q.Y, Z);
               return True;
            end if;
         end;
      end loop;
      return False;
   end Step_To;

   --  The herds' flight together (see the spec).  A deer turns toward Want
   --  (flat, unit) at no more than Rate, then steps Speed x Dt the way it
   --  faces, turning aside round what is in the way (the side Want lies on
   --  first), onto no floor under more than Wade rows of water unless it
   --  stands as deep already; and the way it went is the way it faces.
   --  False: no way on.
   function Head_Step (D : in out Deer_Rec; Want : Vec3; Speed, Rate : Float; Wade : Natural; Dt : Float)
                       return Boolean is
      Cur  : constant Float := Arctan (D.Dir.Y, D.Dir.X);
      Dif0 : constant Float := Arctan (Want.Y, Want.X) - Cur;
      Dif  : constant Float := Dif0 - 2.0 * Pi * Float'Rounding (Dif0 / (2.0 * Pi));
      A    : constant Float := Cur + Float'Max (-Rate * Dt, Float'Min (Rate * Dt, Dif));
      Dir  : constant Vec3 := (Cos (A), Sin (A), 0.0);
      S    : constant Float := (if Dif >= 0.0 then 1.0 else -1.0);
      Turns : constant array (1 .. 7) of Float := [0.0, 0.4, -0.4, 0.8, -0.8, 1.3, -1.3];
      Len  : constant Float := Speed * Dt;
      Deep : constant Natural := Natural'Max (Wade, Water_At (D.Pos.X, D.Pos.Y, D.Pos.Z));
   begin
      D.Dir := Dir;
      if Len <= 0.0 then
         return True;
      end if;
      for T of Turns loop
         declare
            V : constant Vec3 := Turned (Dir, S * T);
            Q : constant Vec3 := (D.Pos.X + V.X * Len, D.Pos.Y + V.Y * Len, D.Pos.Z);
            Z : constant Float := Floor_Near (Q.X, Q.Y, D.Pos.Z, Deep);
         begin
            if Z >= 0.0 and then In_Range (Q)
              and then (Flat_Dist (Q, Stake_At) >= Near_Stake_M - 10.0
                        or else Flat_Dist (Q, Stake_At) >= Flat_Dist (D.Pos, Stake_At))
            then
               D.Pos := (Q.X, Q.Y, Z);
               D.Dir := V;
               return True;
            end if;
         end;
      end loop;
      --  no way on within a quarter turn of where it faces: it turns on, always
      --  the same way round, so that step by step it looks all about for one
      --  (off a ledge it ran onto, round a pool) and then goes along the edge
      D.Dir := Turned (Dir, (if D.Seed mod 2 = 0 then 0.7 else -0.7));
      return False;
   end Head_Step;

   procedure Set_Scatter (On : Boolean) is
   begin
      Old_Way := On;
   end Set_Scatter;

   function Scatter return Boolean is (Old_Way);

   ------------------------------------------------------------------ herds

   procedure Reset is
   begin
      N_Herds := 0;
      N_Deer := 0;
      Pending := False;
      Now := 0.0;
      for H of Herds loop
         H.Used := False;
      end loop;
      for D of Deer loop
         D.Alive := False;
      end loop;
   end Reset;

   procedure Found (Stake : Vec3; Seed : U64) is
   begin
      Reset;
      Stake_At := Stake;
      Base_Seed := Seed;
      Pending := True;
   end Found;

   function Year_Of (H : Long_Float) return Integer is (Integer (Long_Float'Floor (H / Long_Float (Hours_A_Year))));

   function Adult_Female (D : Deer_Rec) return Boolean is
     (D.Alive and then not D.Male and then Float (Now - D.Born) >= 1.5 * Hours_A_Year);

   procedure New_Spot (D : in out Deer_Rec; Fawn : Boolean) is
      A : constant Float := 2.0 * Pi * Rnd (D);
      R : constant Float := (if Fawn then 1.0 + 2.0 * Rnd (D) else 2.0 + 5.0 * Rnd (D));
   begin
      D.Spot := (R * Cos (A), R * Sin (A), 0.0);
      D.Spot_T := 15.0 + 30.0 * Rnd (D);
   end New_Spot;

   --  A deer born into herd H at P (game hours: its birth).
   procedure Add_Deer (H : Positive; P : Vec3; Male : Boolean; Born : Long_Float; Seed : U64) is
      Slot : Natural := 0;
   begin
      for K in 1 .. N_Deer loop
         if not Deer (K).Alive then
            Slot := K;
            exit;
         end if;
      end loop;
      if Slot = 0 then
         if N_Deer = Max_Deer then
            return;
         end if;
         N_Deer := N_Deer + 1;
         Slot := N_Deer;
      end if;
      Deer (Slot) := (Alive => True, Herd => H, Male => Male, Born => Born, Pos => P, Prev => P,
                      Seed => Seed, others => <>);
      New_Spot (Deer (Slot), Fawn => Float (Now - Born) < Hours_A_Year);
      Deer (Slot).Act_T := 2.0 + 6.0 * Rnd (Deer (Slot));
   end Add_Deer;

   function In_Herd (H : Positive) return Natural is
      N : Natural := 0;
   begin
      for K in 1 .. N_Deer loop
         if Deer (K).Alive and then Deer (K).Herd = H then
            N := N + 1;
         end if;
      end loop;
      return N;
   end In_Herd;

   --  The herds, round the stake, once its ground is in.
   procedure Place_Herds is
      Years : constant Long_Float := Long_Float (Hours_A_Year);
   begin
      for H in 1 .. 2 loop
         declare
            Hr : Herd_Rec;
         begin
            Hr.Seed := Derive (Base_Seed, U64 (5_000 + H));
            for Try in 1 .. 32 loop
               declare
                  --  the two on opposite sides, give or take; failing that, anywhere
                  U : constant Float := Rnd (Hr);
                  A : constant Float := (if Try <= 16 then Pi * Float (H - 1) + 2.0 * (U - 0.5) else 2.0 * Pi * U);
                  R : constant Float := 30.0 + 25.0 * Rnd (Hr);
                  P : constant Vec3 := (Stake_At.X + R * Cos (A), Stake_At.Y + R * Sin (A), 0.0);
                  Z : constant Float := Castle.Nav.Surface_Z (P.X, P.Y);
               begin
                  if Z >= 0.0 and then In_Range (P, Near_Stake_M)
                    and then (Old_Way or else Dry_Spot (P.X, P.Y, Deer_Wade_B))
                  then
                     N_Herds := N_Herds + 1;
                     Hr.Used := True;
                     Hr.Node := (P.X, P.Y, Z);
                     Hr.Timer := 30.0 + 60.0 * Rnd (Hr);
                     Hr.Bred_Year := Year_Of (Now);
                     Herds (N_Herds) := Hr;
                     declare
                        type Who is record
                           Male : Boolean;
                           Age  : Long_Float;   --  years
                        end record;
                        Band : constant array (1 .. 5) of Who :=
                          (if H = 1 then [(True, 3.5), (False, 2.5), (False, 4.0), (True, 1.4), (False, 0.3)]
                           else [(False, 3.0), (False, 2.0), (False, 5.0), (True, 0.4), (False, 1.2)]);
                     begin
                        for I in Band'Range loop
                           Add_Deer (N_Herds, Hr.Node, Band (I).Male, Now - Band (I).Age * Years,
                                     Derive (Hr.Seed, U64 (100 + I)));
                        end loop;
                     end;
                     exit;
                  end if;
               end;
            end loop;
         end;
      end loop;
   end Place_Herds;

   --  Start H walking (or fleeing, at Pace) to T by a planned route.
   --  (the herds' flight together: by a way that keeps out of water deeper
   --  than Wade rows)
   function Go (H : in out Herd_Rec; T : Vec3; Pace : Float; Wade : Natural := Castle.Nav.Wade_B) return Boolean is
      R : Castle.Nav.Route :=
        (if Old_Way then Castle.Nav.Plan (H.Node, T)
         else Castle.Nav.Plan (H.Node, T, Budget => Herd_Budget, Wade => Wade));
   begin
      --  the node never stops in water: a way that ends in it (one that
      --  falls short of where it was going) is cut back to its last dry turn
      if not Old_Way then
         while R.N >= 2 and then not Dry_Spot (R.Pts (R.N).P.X, R.Pts (R.N).P.Y, Deer_Wade_B) loop
            R.N := R.N - 1;
            R.Result := Castle.Nav.Partial;
         end loop;
      end if;
      if R.N >= 2 and then (R.Result = Castle.Nav.Found or else Castle.Nav.Length (R) > 8.0) then
         H.Route := R;
         H.Leg := 1;
         H.Along := 0.0;
         H.Pace := Pace;
         return True;
      end if;
      return False;
   end Go;

   --  The way the node is going: along the leg of its route it is on.
   function Travel (H : Herd_Rec) return Vec3 is
     (if H.Route.N >= 2 and then H.Leg < H.Route.N
      then Flat_Unit (H.Route.Pts (H.Leg + 1).P - H.Route.Pts (H.Leg).P, (1.0, 0.0, 0.0))
      else (1.0, 0.0, 0.0));

   --  The herd flees together (see the spec).  Startle: its deer start
   --  afresh, each on a heading of its own (not when a herd in flight is
   --  turned again).
   procedure Flee (Hi : Positive; From : Vec3; Startle : Boolean) is
      H    : Herd_Rec renames Herds (Hi);
      Away : constant Vec3 := Flat_Unit (H.Node - From, Turned ((1.0, 0.0, 0.0), 2.0 * Pi * Rnd (H)));
      Turns : constant array (1 .. 7) of Float := [0.0, 0.5, -0.5, 1.0, -1.0, 1.6, -1.6];
      Fled : Boolean := False;
      --  the full flight straight away or to either side of that; failing
      --  those (at the edge of its range, the danger inside it), shorter,
      --  and round past the danger
      Wide  : constant array (1 .. 4) of Float := [2.2, -2.2, 2.8, -2.8];
      Reach : constant array (1 .. 3) of Float := [Flee_M, 0.6 * Flee_M, 0.35 * Flee_M];
      procedure Try (A, Far : Float) is
         V : constant Vec3 := Turned (Away, A);
         T : constant Vec3 := (H.Node.X + V.X * Far, H.Node.Y + V.Y * Far, H.Node.Z);
      begin
         if not Fled and then In_Range (T, Near_Stake_M) and then Dry_Spot (T.X, T.Y, Deer_Wade_B)
           and then Go (H, T, Flee_Pace, Flight_Wade_B)
         then
            H.Mode := Fleeing;
            Fled := True;
         end if;
      end Try;
   begin
      H.Calm := 0.0;
      for Far of Reach loop
         for A of Turns loop
            Try (A, Far);
         end loop;
         if Far < Flee_M then
            for A of Wide loop
               Try (A, Far);
            end loop;
         end if;
      end loop;
      if not Fled and then H.Mode = Fleeing then
         return;                        --  turned again, but no better way: it runs on as it was
      end if;
      for K in 1 .. N_Deer loop
         declare
            D : Deer_Rec renames Deer (K);
         begin
            if D.Alive and then D.Herd = Hi then
               declare
                  Off  : constant Vec3 := Flat_Unit (D.Pos - From, Away);
                  Fawn : constant Boolean := Float (Now - D.Born) < Hours_A_Year;
                  U1   : constant Float := Rnd (D);
                  U2   : constant Float := Rnd (D);
                  U3   : constant Float := Rnd (D);
               begin
                  if not Fled then
                     --  nowhere for the herd to go: each bolts a moment by itself
                     D.Panic := 1.5 + 1.5 * U1;
                     D.Startle := D.Panic;
                     D.Dir := Turned (Off, 1.2 * (U2 - 0.5));
                  else
                     D.Panic := Flight_Max_S;
                     if Startle then
                        --  (its own heading: between away from the danger and the way the herd goes)
                        D.Startle := Startle_S * (1.0 + 0.5 * U1);
                        D.Dir := Turned (Flat_Unit (Off + Travel (H), Off), 0.8 * (U2 - 0.5));
                     end if;
                  end if;
                  D.Pace := (if Fawn then 5.0 else 6.0) + 1.5 * U3;
               end;
               D.Act := Castle.Deer.Alert;
               D.Act_T := 2.0;
            end if;
         end;
      end loop;
   end Flee;

   procedure Panic (Hi : Positive; From : Vec3) is
      H    : Herd_Rec renames Herds (Hi);
      Away : constant Vec3 := Flat_Unit (H.Node - From, Turned ((1.0, 0.0, 0.0), 2.0 * Pi * Rnd (H)));
      Turns : constant array (1 .. 7) of Float := [0.0, 0.5, -0.5, 1.0, -1.0, 1.6, -1.6];
   begin
      H.Calm := 0.0;
      for A of Turns loop
         declare
            V : constant Vec3 := Turned (Away, A);
            T : constant Vec3 := (H.Node.X + V.X * 30.0, H.Node.Y + V.Y * 30.0, H.Node.Z);
         begin
            if In_Range (T, Near_Stake_M) and then Castle.Nav.Surface_Z (T.X, T.Y) >= 0.0 and then Go (H, T, 4.0) then
               H.Mode := Fleeing;
               exit;
            end if;
         end;
      end loop;
      for K in 1 .. N_Deer loop
         declare
            D : Deer_Rec renames Deer (K);
         begin
            if D.Alive and then D.Herd = Hi then
               declare
                  Off  : constant Vec3 := Flat_Unit (D.Pos - From, Away);
                  Fawn : constant Boolean := Float (Now - D.Born) < Hours_A_Year;
                  U1   : constant Float := Rnd (D);
                  U2   : constant Float := Rnd (D);
                  U3   : constant Float := Rnd (D);
               begin
                  D.Panic := 3.0 + 3.0 * U1;
                  D.Dir := Turned (Off, 1.2 * (U2 - 0.5));
                  D.Pace := (if Fawn then 5.0 else 6.0) + 1.5 * U3;
               end;
               D.Act := Castle.Deer.Alert;
               D.Act_T := 2.0;
            end if;
         end;
      end loop;
   end Panic;

   procedure Kill (K : Positive) is
   begin
      if K <= N_Deer then
         Deer (K).Alive := False;
      end if;
   end Kill;

   procedure Scare (Aimed_At, From : Vec3) is
      Best   : Natural := 0;
      Best_D : Float := Fear_M;
   begin
      for K in 1 .. N_Deer loop
         if Deer (K).Alive and then Flat_Dist (Deer (K).Pos, Aimed_At) <= Best_D then
            Best_D := Flat_Dist (Deer (K).Pos, Aimed_At);
            Best := K;
         end if;
      end loop;
      if Best > 0 then
         if Old_Way then
            Panic (Deer (Best).Herd, From);
         else
            Flee (Deer (Best).Herd, From, Startle => Herds (Deer (Best).Herd).Mode /= Fleeing);
         end if;
      end if;
   end Scare;

   ------------------------------------------------------------------ a step

   procedure Step_Herd (Hi : Positive; Dt : Float) is
      H : Herd_Rec renames Herds (Hi);
   begin
      H.Calm := H.Calm + Dt;
      case H.Mode is
         when Grazing =>
            H.Timer := H.Timer - Dt;
            if H.Timer <= 0.0 then
               H.Timer := 20.0;                      --  if nowhere is found, look again later
               for Try in 1 .. 8 loop
                  declare
                     A : constant Float := 2.0 * Pi * Rnd (H);
                     R : constant Float := 15.0 + 15.0 * Rnd (H);
                     T : constant Vec3 := (H.Node.X + R * Cos (A), H.Node.Y + R * Sin (A), H.Node.Z);
                  begin
                     if In_Range (T, Near_Stake_M) and then Castle.Nav.Surface_Z (T.X, T.Y) >= 0.0
                       and then (Old_Way or else Dry_Spot (T.X, T.Y, Deer_Wade_B))
                       and then Go (H, T, 0.8, Deer_Wade_B)
                     then
                        H.Mode := Moving;
                        exit;
                     end if;
                  end;
               end loop;
            end if;
         when Moving | Fleeing =>
            declare
               R    : Castle.Nav.Route renames H.Route;
               Move : Float := H.Pace * Dt;
            begin
               while Move > 0.0 and then H.Leg < R.N loop
                  declare
                     L : constant Float := R.Pts (H.Leg + 1).D - R.Pts (H.Leg).D;
                  begin
                     if H.Along + Move < L then
                        H.Along := H.Along + Move;
                        Move := 0.0;
                     else
                        Move := Move - (L - H.Along);
                        H.Leg := H.Leg + 1;
                        H.Along := 0.0;
                     end if;
                  end;
               end loop;
               if H.Leg >= R.N then
                  H.Node := R.Pts (R.N).P;
                  H.Mode := Grazing;
                  H.Timer := 60.0 + 120.0 * Rnd (H);
                  if Old_Way then
                     R.N := 0;
                  else
                     H.Leg := R.N;         --  the way it came is kept: a deer left behind takes it
                     H.Along := 0.0;
                  end if;
               else
                  declare
                     P0 : constant Vec3 := R.Pts (H.Leg).P;
                     P1 : constant Vec3 := R.Pts (H.Leg + 1).P;
                     L  : constant Float := R.Pts (H.Leg + 1).D - R.Pts (H.Leg).D;
                     T  : constant Float := (if L > 0.0 then H.Along / L else 0.0);
                  begin
                     H.Node := P0 + (P1 - P0) * T;
                  end;
               end if;
            end;
      end case;
   end Step_Herd;

   --  Where a deer at P, left behind, makes for: the point of the way its
   --  node went Trail_Ahead_M past where that way is nearest it, never past
   --  the node.  Found: False when there is no such way, or the deer is
   --  already as far along it as the node (it makes straight for its place).
   procedure Trail_Point (H : Herd_Rec; P : Vec3; Q : out Vec3; Found : out Boolean) is
      R      : Castle.Nav.Route renames H.Route;
      Node_D : Float;
      Best   : Float := Float'Last;
      Best_D : Float := 0.0;
   begin
      Q := P;
      Found := False;
      if R.N < 2 then
         return;
      end if;
      Node_D := (if H.Leg >= R.N then R.Pts (R.N).D else R.Pts (H.Leg).D + H.Along);
      for I in 1 .. R.N - 1 loop
         exit when R.Pts (I).D >= Node_D;
         declare
            A  : constant Vec3 := R.Pts (I).P;
            B  : constant Vec3 := R.Pts (I + 1).P;
            Ex : constant Float := B.X - A.X;
            Ey : constant Float := B.Y - A.Y;
            L2 : constant Float := Ex * Ex + Ey * Ey;
            T  : constant Float :=
              (if L2 > 1.0E-6 then Float'Max (0.0, Float'Min (1.0, ((P.X - A.X) * Ex + (P.Y - A.Y) * Ey) / L2))
               else 0.0);
            Dd : constant Float := Sqrt ((A.X + Ex * T - P.X) ** 2 + (A.Y + Ey * T - P.Y) ** 2);
         begin
            if Dd < Best then
               Best := Dd;
               Best_D := R.Pts (I).D + (R.Pts (I + 1).D - R.Pts (I).D) * T;
            end if;
         end;
      end loop;
      if Best = Float'Last or else Best_D + Trail_Ahead_M >= Node_D then
         return;
      end if;
      declare
         Want_D : constant Float := Best_D + Trail_Ahead_M;
      begin
         for I in 1 .. R.N - 1 loop
            if R.Pts (I + 1).D >= Want_D then
               declare
                  L : constant Float := R.Pts (I + 1).D - R.Pts (I).D;
                  T : constant Float := (if L > 1.0E-4 then (Want_D - R.Pts (I).D) / L else 0.0);
               begin
                  Q := R.Pts (I).P + (R.Pts (I + 1).P - R.Pts (I).P) * T;
                  Found := True;
                  return;
               end;
            end if;
         end loop;
      end;
   end Trail_Point;

   --  A deer's step, the herds fleeing together (see the spec).
   procedure Step_With_Herd (K : Positive; Dt : Float) is
      D    : Deer_Rec renames Deer (K);
      H    : Herd_Rec renames Herds (D.Herd);
      Fawn : constant Boolean := Float (Now - D.Born) < Hours_A_Year;
      Goal : Vec3;
      To_Goal : Vec3;
      Dist : Float;
      Via  : Vec3 := (0.0, 0.0, 0.0);
      By_Trail : Boolean := False;
   begin
      D.Prev := D.Pos;
      if D.Panic <= 0.0 then
         D.Spot_T := D.Spot_T - Dt;
         if D.Spot_T <= 0.0 then
            New_Spot (D, Fawn);
         end if;
      end if;
      --  (calm and standing in water: for the node itself, which is on dry ground)
      Goal := (if D.Panic <= 0.0 and then Water_At (D.Pos.X, D.Pos.Y, D.Pos.Z) > Deer_Wade_B then H.Node
               else H.Node + D.Spot);
      To_Goal := (Goal.X - D.Pos.X, Goal.Y - D.Pos.Y, 0.0);
      Dist := Flat_Dist (D.Pos, Goal);
      --  left behind: by the way the node went, not straight
      if Dist > Trail_M then
         Trail_Point (H, D.Pos, Via, By_Trail);
      end if;
      if D.Panic > 0.0 then
         D.Panic := D.Panic - Dt;
         if D.Startle > 0.0 then
            --  its start: off on its own heading, away from the danger
            D.Startle := D.Startle - Dt;
            declare
               Its_Own : constant Vec3 := D.Dir;
            begin
               if not Head_Step (D, Its_Own, D.Pace, Flight_Turn, Flight_Wade_B, Dt) then
                  D.Startle := 0.0;              --  no way on: with the herd, then
               end if;
            end;
         elsif By_Trail then
            declare
               Faces : constant Vec3 := D.Dir;
               Sp    : constant Float :=
                 Float'Min (D.Pace, Float'Max (2.4, (if H.Mode = Fleeing then H.Pace else 0.0) + Keep_Gain * Dist));
               Moved : constant Boolean :=
                 Head_Step (D, Flat_Unit (Via - D.Pos, Faces), Sp, Flight_Turn, Flight_Wade_B, Dt);
            begin
               if not Moved and then H.Mode /= Fleeing then
                  D.Panic := Float'Min (D.Panic, 1.0);
               end if;
            end;
         elsif H.Mode = Fleeing then
            --  with the herd: for its own place round the node, as fast as
            --  keeps it; ahead of its place it runs on slower, never back
            declare
               T     : constant Vec3 := Travel (H);
               Along : constant Float := To_Goal.X * T.X + To_Goal.Y * T.Y;
               Side  : constant Vec3 := (To_Goal.X - T.X * Along, To_Goal.Y - T.Y * Along, 0.0);
               Fwd   : constant Float := Float'Max (Flight_Slow, H.Pace + Keep_Gain * Along);
               V     : constant Vec3 := T * Fwd + Side * Keep_Gain;
               Sp    : constant Float := Float'Min (D.Pace, Sqrt (V.X * V.X + V.Y * V.Y));
               Moved : constant Boolean := Head_Step (D, Flat_Unit (V, T), Sp, Flight_Turn, Flight_Wade_B, Dt);
            begin
               pragma Unreferenced (Moved);
            end;
         elsif Dist < Arrive_M then
            D.Panic := 0.0;                      --  the node has stopped and it is at its place: over
         else
            declare
               Sp    : constant Float := Float'Min (D.Pace, Float'Max (2.4, Keep_Gain * Dist));
               Faces : constant Vec3 := D.Dir;
               Moved : constant Boolean :=
                 Head_Step (D, Flat_Unit (To_Goal, Faces), Sp, Flight_Turn, Flight_Wade_B, Dt);
            begin
               if not Moved then
                  D.Panic := Float'Min (D.Panic, 1.0);   --  it can't get there: it gives up in a moment
               end if;
            end;
         end if;
         return;
      end if;
      if Dist > 1.0 then
         declare
            Pace  : constant Float := (if Dist > 8.0 then 2.4 elsif Fawn then 1.1 else 0.9);
            Faces : constant Vec3 := D.Dir;
            To    : constant Vec3 := (if By_Trail then Via - D.Pos else To_Goal);
         begin
            if not Head_Step (D, Flat_Unit ((To.X, To.Y, 0.0), Faces), Float'Min (Dist / Dt, Pace), Turn_Rate,
                              Deer_Wade_B, Dt)
            then
               New_Spot (D, Fawn);                       --  can't get to it: somewhere else
            end if;
         end;
      else
         D.Act_T := D.Act_T - Dt;
         if D.Act_T <= 0.0 then
            declare
               U : constant Float := Rnd (D);
            begin
               D.Act := (if U < 0.6 then Castle.Deer.Graze elsif U < 0.85 then Castle.Deer.Idle
                         else Castle.Deer.Alert);
               D.Act_T := 4.0 + 10.0 * Rnd (D);
            end;
         end if;
      end if;
   end Step_With_Herd;

   procedure Step_Deer (K : Positive; Dt : Float) is
      D    : Deer_Rec renames Deer (K);
      H    : Herd_Rec renames Herds (D.Herd);
      Fawn : constant Boolean := Float (Now - D.Born) < Hours_A_Year;
   begin
      if not Old_Way then
         Step_With_Herd (K, Dt);
         return;
      end if;
      D.Prev := D.Pos;
      if D.Panic > 0.0 then
         D.Panic := D.Panic - Dt;
         declare
            Dir : constant Vec3 := D.Dir;
         begin
            if not Step_To (D, Dir, D.Pace * Dt) then
               declare
                  U : constant Float := Rnd (D);
               begin
                  D.Dir := Turned (Dir, Pi * (U - 0.5) + Pi);   --  cornered: break the other way
               end;
            end if;
         end;
         return;
      end if;
      D.Spot_T := D.Spot_T - Dt;
      if D.Spot_T <= 0.0 then
         New_Spot (D, Fawn);
      end if;
      declare
         Goal : constant Vec3 := H.Node + D.Spot;
         Dist : constant Float := Flat_Dist (D.Pos, Goal);
      begin
         if Dist > 1.0 then
            declare
               Pace : constant Float := (if Dist > 8.0 then 2.4 elsif Fawn then 1.1 else 0.9);
            begin
               if not Step_To (D, Flat_Unit (Goal - D.Pos, (1.0, 0.0, 0.0)), Float'Min (Dist, Pace * Dt)) then
                  New_Spot (D, Fawn);                       --  can't get to it: somewhere else
               end if;
            end;
         else
            D.Act_T := D.Act_T - Dt;
            if D.Act_T <= 0.0 then
               declare
                  U : constant Float := Rnd (D);
               begin
                  D.Act := (if U < 0.6 then Castle.Deer.Graze elsif U < 0.85 then Castle.Deer.Idle
                            else Castle.Deer.Alert);
                  D.Act_T := 4.0 + 10.0 * Rnd (D);
               end;
            end if;
         end if;
      end;
   end Step_Deer;

   --  Spring: each grown doe may bear a fawn, once a year.
   procedure Breed is
      Year : constant Integer := Year_Of (Now);
   begin
      if Castle.Climate.Season_Of (Castle.Climate.Day_Of_Year (Now)) /= Castle.Climate.Spring then
         return;
      end if;
      for Hi in 1 .. N_Herds loop
         declare
            H : Herd_Rec renames Herds (Hi);
         begin
            if H.Used and then H.Bred_Year < Year then
               H.Bred_Year := Year;
               for K in 1 .. N_Deer loop
                  if Adult_Female (Deer (K)) and then Deer (K).Herd = Hi and then In_Herd (Hi) < Max_In_Herd
                    and then Rnd (H) < 0.6
                  then
                     declare
                        Live : Natural := 0;
                     begin
                        for J in 1 .. N_Deer loop
                           if Deer (J).Alive then
                              Live := Live + 1;
                           end if;
                        end loop;
                        if Live < Max_Deer then
                           Add_Deer (Hi, Deer (K).Pos, Rnd (H) < 0.5, Now,
                                     Derive (H.Seed, U64 (1_000 + Year * 64 + K)));
                        end if;
                     end;
                  end if;
               end loop;
            end if;
         end;
      end loop;
   end Breed;

   --  Two grown deer (a doe, and a doe or a young stag) wander in and join
   --  the smallest herd, if it is under Full_Herd.
   procedure Arrive is
      Least : Natural := 0;
   begin
      for Hi in 1 .. N_Herds loop
         if Herds (Hi).Used and then In_Herd (Hi) < Full_Herd
           and then (Least = 0 or else In_Herd (Hi) < In_Herd (Least))
         then
            Least := Hi;
         end if;
      end loop;
      if Least = 0 then
         return;
      end if;
      declare
         H : Herd_Rec renames Herds (Least);
         U : constant Float := Rnd (H);
         S : constant U64 := Derive (H.Seed, U64 (9_000) + U64 (Float'Floor (U * 1.0E6)));
      begin
         Add_Deer (Least, H.Node, False, Now - 2.5 * Long_Float (Hours_A_Year), Derive (S, 1));
         Add_Deer (Least, H.Node, U < 0.5, Now - 1.6 * Long_Float (Hours_A_Year), Derive (S, 2));
      end;
   end Arrive;

   procedure Step (Dt : Float; Hours : Long_Float; Near : People) is
      Every : constant Long_Float := Long_Float (Arrive_Days) * 24.0;
      Was   : constant Long_Float := Now;
   begin
      Now := Hours;
      if Pending then
         Pending := False;
         Place_Herds;
      elsif Was > 0.0 and then Long_Float'Floor (Was / Every) /= Long_Float'Floor (Now / Every) then
         Arrive;
      end if;
      --  fear, the herds fleeing together: someone too near a deer of a herd
      --  not lately startled; a herd in flight is only turned, by someone close
      if not Old_Way then
         for Hi in 1 .. N_Herds loop
            declare
               Running : constant Boolean := Herds (Hi).Used and then Herds (Hi).Mode = Fleeing;
            begin
               if Herds (Hi).Used and then Herds (Hi).Calm > (if Running then Turn_Again_S else Settle_S) then
                  Seen :
                  for P of Near loop
                     for K in 1 .. N_Deer loop
                        if Deer (K).Alive and then Deer (K).Herd = Hi
                          and then Flat_Dist (Deer (K).Pos, P.P)
                                   <= (if P.Stalking then Stalked_M elsif Running then Close_M else Fear_M)
                        then
                           Flee (Hi, P.P, Startle => not Running);
                           exit Seen;
                        end if;
                     end loop;
                  end loop Seen;
               end if;
            end;
         end loop;
      end if;
      --  fear: someone too near a deer of a herd that has calmed down
      for Hi in 1 .. N_Herds loop
         if Old_Way and then Herds (Hi).Used and then Herds (Hi).Calm > 3.0 then
            Look :
            for P of Near loop
               for K in 1 .. N_Deer loop
                  if Deer (K).Alive and then Deer (K).Herd = Hi
                    and then Flat_Dist (Deer (K).Pos, P.P) <= (if P.Stalking then Stalked_M else Fear_M)
                  then
                     Panic (Hi, P.P);
                     exit Look;
                  end if;
               end loop;
            end loop Look;
         end if;
      end loop;
      for Hi in 1 .. N_Herds loop
         if Herds (Hi).Used then
            Step_Herd (Hi, Dt);
         end if;
      end loop;
      for K in 1 .. N_Deer loop
         if Deer (K).Alive then
            Step_Deer (K, Dt);
         end if;
      end loop;
      Breed;
   end Step;

   ------------------------------------------------------------------ queries

   function Herd_Count return Natural is (N_Herds);
   function Node (H : Positive) return Vec3 is (Herds (H).Node);
   function Panicked (H : Positive) return Boolean is
   begin
      for K in 1 .. N_Deer loop
         if Deer (K).Alive and then Deer (K).Herd = H and then Deer (K).Panic > 0.0 then
            return True;
         end if;
      end loop;
      return False;
   end Panicked;
   function Deer_Slots return Natural is (N_Deer);
   function Alive (K : Positive) return Boolean is (Deer (K).Alive);
   function Herd_Of (K : Positive) return Natural is (Deer (K).Herd);
   function Class_Of (K : Positive) return Castle.Deer.Class is
      Age : constant Float := Float (Now - Deer (K).Born) / Hours_A_Year;
   begin
      return (if Age < 1.0 then Castle.Deer.Fawn
              elsif not Deer (K).Male then Castle.Deer.Doe
              elsif Age < 2.0 then Castle.Deer.Young_Stag else Castle.Deer.Stag);
   end Class_Of;
   function Where (K : Positive; Blend : Float := 1.0) return Vec3 is
     (Deer (K).Prev + (Deer (K).Pos - Deer (K).Prev) * Blend);
   function Doing (K : Positive) return Castle.Deer.Standing_Mode is
     (if Deer (K).Panic > 0.0 then Castle.Deer.Alert else Deer (K).Act);
   function In_Panic (K : Positive) return Boolean is (Deer (K).Panic > 0.0);
   function Seed_Of (K : Positive) return U64 is (Deer (K).Seed);

   ------------------------------------------------------------------ saves

   Save_Version : constant := 2;   --  2: whether the herds scatter as they were; each deer's start

   function F32_Bits is new Ada.Unchecked_Conversion (Float, Unsigned_32);
   function Bits_F32 is new Ada.Unchecked_Conversion (Unsigned_32, Float);
   function F64_Bits is new Ada.Unchecked_Conversion (Long_Float, Unsigned_64);
   function Bits_F64 is new Ada.Unchecked_Conversion (Unsigned_64, Long_Float);
   type Bytes_Access is access Bytes;
   procedure Free is new Ada.Unchecked_Deallocation (Bytes, Bytes_Access);

   function Save return Bytes is
      Buf  : Bytes_Access := new Bytes (0 .. 16_383);
      Size : Natural := 0;
      procedure Put (V : Unsigned_64; Count : Positive) is
      begin
         if Size + Count > Buf'Length then
            declare
               Bigger : constant Bytes_Access := new Bytes (0 .. 2 * Buf'Length - 1);
            begin
               Bigger (0 .. Size - 1) := Buf (0 .. Size - 1);
               Free (Buf);
               Buf := Bigger;
            end;
         end if;
         for K in 0 .. Count - 1 loop
            Buf (Size) := Unsigned_8 (Shift_Right (V, 8 * K) and 255);
            Size := Size + 1;
         end loop;
      end Put;
      procedure Put_F (V : Float) is
      begin
         Put (Unsigned_64 (F32_Bits (V)), 4);
      end Put_F;
      procedure Put_V (V : Vec3) is
      begin
         Put_F (V.X);
         Put_F (V.Y);
         Put_F (V.Z);
      end Put_V;
      procedure Put_B (V : Boolean) is
      begin
         Put ((if V then 1 else 0), 1);
      end Put_B;
   begin
      Put (Save_Version, 1);
      Put_B (Pending);
      Put_V (Stake_At);
      Put (Base_Seed, 8);
      Put (F64_Bits (Now), 8);
      Put (Unsigned_64 (N_Herds), 1);
      for Hi in 1 .. N_Herds loop
         declare
            H : Herd_Rec renames Herds (Hi);
         begin
            Put_B (H.Used);
            Put_V (H.Node);
            Put (Unsigned_64 (Herd_Mode'Pos (H.Mode)), 1);
            Put_F (H.Timer);
            Put (Unsigned_64 (H.Route.N), 2);
            for P in 1 .. H.Route.N loop
               Put_V (H.Route.Pts (P).P);
               Put_F (H.Route.Pts (P).D);
            end loop;
            Put (Unsigned_64 (H.Leg), 2);
            Put_F (H.Along);
            Put_F (H.Pace);
            Put (Unsigned_64 (Integer'Max (-1, H.Bred_Year) + 1), 4);
            Put_F (H.Calm);
            Put (H.Seed, 8);
            Put (Unsigned_64 (H.N), 4);
         end;
      end loop;
      Put (Unsigned_64 (N_Deer), 1);
      for K in 1 .. N_Deer loop
         declare
            D : Deer_Rec renames Deer (K);
         begin
            Put_B (D.Alive);
            Put (Unsigned_64 (D.Herd), 1);
            Put_B (D.Male);
            Put (F64_Bits (D.Born), 8);
            Put_V (D.Pos);
            Put_V (D.Prev);
            Put_V (D.Spot);
            Put_F (D.Spot_T);
            Put (Unsigned_64 (Castle.Deer.Standing_Mode'Pos (D.Act)), 1);
            Put_F (D.Act_T);
            Put_F (D.Panic);
            Put_V (D.Dir);
            Put_F (D.Pace);
            Put (D.Seed, 8);
            Put (Unsigned_64 (D.N), 4);
         end;
      end loop;
      Put_B (Old_Way);
      for K in 1 .. N_Deer loop
         Put_F (Deer (K).Startle);
      end loop;
      declare
         Result : constant Bytes := Buf (0 .. Size - 1);
      begin
         Free (Buf);
         return Result;
      end;
   end Save;

   Bad_Save : exception;

   procedure Load (B : Bytes; Ok : out Boolean) is
      Pos : Natural := B'First;
      function Get (Count : Positive) return Unsigned_64 is
         V : Unsigned_64 := 0;
      begin
         if Pos + Count - 1 > B'Last then
            raise Bad_Save;
         end if;
         for K in 0 .. Count - 1 loop
            V := V or Shift_Left (Unsigned_64 (B (Pos + K)), 8 * K);
         end loop;
         Pos := Pos + Count;
         return V;
      end Get;
      function Get_F return Float is (Bits_F32 (Unsigned_32 (Get (4))));
      function Get_V return Vec3 is
         X : constant Float := Get_F;
         Y : constant Float := Get_F;
         Z : constant Float := Get_F;
      begin
         return (X, Y, Z);
      end Get_V;
      function Get_B return Boolean is (Get (1) /= 0);
      Version : Natural;
   begin
      Reset;
      Ok := False;
      Version := Natural (Get (1));
      if Version not in 1 .. Save_Version then
         return;
      end if;
      Pending := Get_B;
      Stake_At := Get_V;
      Base_Seed := Get (8);
      Now := Bits_F64 (Get (8));
      N_Herds := Natural (Get (1));
      for Hi in 1 .. N_Herds loop
         declare
            H : Herd_Rec renames Herds (Hi);
         begin
            H := (others => <>);
            H.Used := Get_B;
            H.Node := Get_V;
            H.Mode := Herd_Mode'Val (Get (1));
            H.Timer := Get_F;
            H.Route.N := Natural (Get (2));
            for P in 1 .. H.Route.N loop
               H.Route.Pts (P).P := Get_V;
               H.Route.Pts (P).D := Get_F;
            end loop;
            H.Leg := Positive (Get (2));
            H.Along := Get_F;
            H.Pace := Get_F;
            H.Bred_Year := Integer (Get (4)) - 1;
            H.Calm := Get_F;
            H.Seed := Get (8);
            H.N := Natural (Get (4));
         end;
      end loop;
      N_Deer := Natural (Get (1));
      for K in 1 .. N_Deer loop
         declare
            D : Deer_Rec renames Deer (K);
         begin
            D.Alive := Get_B;
            D.Herd := Natural (Get (1));
            D.Male := Get_B;
            D.Born := Bits_F64 (Get (8));
            D.Pos := Get_V;
            D.Prev := Get_V;
            D.Spot := Get_V;
            D.Spot_T := Get_F;
            D.Act := Castle.Deer.Standing_Mode'Val (Get (1));
            D.Act_T := Get_F;
            D.Panic := Get_F;
            D.Dir := Get_V;
            D.Pace := Get_F;
            D.Seed := Get (8);
            D.N := Natural (Get (4));
            D.Startle := 0.0;
         end;
      end loop;
      if Version >= 2 then
         Old_Way := Get_B;
         for K in 1 .. N_Deer loop
            Deer (K).Startle := Get_F;
         end loop;
      else
         --  from before the herds fled together: they do from here on.  A deer
         --  caught in its panic of the old kind runs that out as its start.
         Old_Way := False;
         for K in 1 .. N_Deer loop
            Deer (K).Startle := Float'Max (0.0, Deer (K).Panic);
         end loop;
      end if;
      if Pos /= B'Last + 1 then
         raise Bad_Save;
      end if;
      Ok := True;
   exception
      when Bad_Save | Constraint_Error =>
         Reset;
         Ok := False;
   end Load;

end Castle.Herds;
