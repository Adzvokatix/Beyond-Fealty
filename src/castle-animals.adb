with Ada.Numerics;
with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Castle.Bodies;
with Castle.Poses;
with Castle.Figures;
with Castle.Serfs;
with Castle.Nav;
with Castle.Second_Order_1;
with Castle.Second_Order_3;

package body Castle.Animals is

   package S1 renames Castle.Second_Order_1;
   package S3 renames Castle.Second_Order_3;
   use Castle.Deer;
   Pi : constant := Ada.Numerics.Pi;

   function Flat (V : Vec3) return Vec3 is ((V.X, V.Y, 0.0));
   function Len (V : Vec3) return Float is (Sqrt (Dot (V, V)));
   function Clamp (X, Lo, Hi : Float) return Float is (Float'Max (Lo, Float'Min (Hi, X)));
   function Frac (X : Float) return Float is (X - Float'Floor (X));
   function Ground (P : Vec3) return Float is (Castle.Serfs.Ground_At (P.X, P.Y, P.Z));

   ------------------------------------------------------------------ gaits

   type Leg_Floats is array (Leg) of Float;
   type Gait_Spec is record
      Duty   : Float;          --  of a cycle each hoof is down
      Offset : Leg_Floats;     --  where in the cycle each hoof lifts
      Stride : Float;          --  metres a cycle, for an adult doe
      Lift   : Float;          --  how high a hoof is carried
   end record;
   Specs : constant array (Gait range Walk .. Bound) of Gait_Spec :=
     [Walk  => (Duty => 0.75, Offset => [Hind_L => 0.0, Fore_L => 0.25, Hind_R => 0.5, Fore_R => 0.75],
                Stride => 0.85, Lift => 0.10),
      Trot  => (Duty => 0.45, Offset => [Hind_L => 0.0, Fore_R => 0.0, Hind_R => 0.5, Fore_L => 0.5],
                Stride => 1.5, Lift => 0.14),
      Bound => (Duty => 0.25, Offset => [Hind_L => 0.0, Hind_R => 0.06, Fore_L => 0.48, Fore_R => 0.56],
                Stride => 3.0, Lift => 0.22)];
   --  The stance a leg covers (Duty x Stride) has to fit its reach: a
   --  standing deer's legs are nearly straight, so a moving one carries its
   --  body a little lower, as low as its planted hooves need (see Animate).

   --  speeds (an adult doe's; scaled by size) at which the gait changes
   Walk_From  : constant := 0.08;
   Trot_From  : constant := 1.7;
   Bound_From : constant := 3.4;

   ------------------------------------------------------------------ state

   type Hoof_State is record
      Pos      : Vec3 := (0.0, 0.0, 0.0);  --  the ground point under it, planted or in the air
      Swinging : Boolean := False;
      From, To : Vec3 := (0.0, 0.0, 0.0);
      T, Dur   : Float := 0.0;
      Lift     : Float := 0.1;
      Height   : Float := 0.0;            --  above the ground in the swing
   end record;
   type Hooves is array (Leg) of Hoof_State;

   type Animal is record
      Used    : Boolean := False;
      C       : Class := Doe;
      D       : Dims;
      Seed    : U64 := 0;
      Winter  : Boolean := False;
      Target  : Vec3 := (0.0, 0.0, 0.0);
      M       : Mode := Idle;
      Root    : S3.Filter;
      Heading : S1.Filter;
      Neck    : S1.Filter;
      Yaw     : S1.Filter;
      Bob     : S1.Filter;
      G       : Gait := Stand;
      Phase   : Float := 0.0;
      Clock   : Float := 0.0;
      H       : Hooves;
      Next_Look : Float := 0.0;
      Look    : Float := 0.0;
      Lively  : Float := 1.0;
      Spd     : Float := 0.0;
      P       : Castle.Deer.Pose;
      Half    : Float := 0.0;       --  each end of its back from its middle across the ground, as last animated (0: not yet)
      Ok      : Castle.Deer.Leg_Flags := [others => True];
      --  scripted walkers
      Walker  : Boolean := False;
      A, B    : Vec3 := (0.0, 0.0, 0.0);
      To_B    : Boolean := True;
      Pace    : Float := 1.0;
      Pause   : Float := 0.0;
      Route   : Castle.Nav.Route;
      Leg_I   : Positive := 1;
      Along   : Float := 0.0;
   end record;

   Herd  : array (1 .. Max_Animals) of Animal;
   N     : Natural := 0;

   Back_N : Back_Count;
   function Backs return Back_Count is (Back_N);
   procedure Clear_Backs is
   begin
      Back_N := (others => <>);
   end Clear_Backs;

   --  one look per class and coat, made the first time it is wanted
   Looks : array (Class, Boolean) of Natural := [others => [others => 0]];

   function Look_Of (C : Class; Winter : Boolean) return Castle.Figures.Look_Id is
   begin
      if Looks (C, Winter) = 0 then
         declare
            R    : Castle.Bodies.Rig;
            Skin : Castle.Bodies.Skin_Pixels;
         begin
            Castle.Deer.Build (C, Winter, R, Skin);
            Looks (C, Winter) := Castle.Figures.New_Look (R, Skin);
         end;
      end if;
      return Looks (C, Winter);
   end Look_Of;

   function Look (C : Class; Winter : Boolean) return Natural is (Natural (Look_Of (C, Winter)));

   function Hash01 (A : Animal; K, J : Integer) return Float is (Unit (Hash_2 (Derive (A.Seed, 77), K, J)));

   --  Where hoof L stands at rest under a body whose middle is at Mid,
   --  facing Fw (flat, unit).
   function Rest (A : Animal; Mid, Fw : Vec3; L : Leg) return Vec3 is
      Rt : constant Vec3 := (Fw.Y, -Fw.X, 0.0);
      --  (under its joint: half the spine from the middle, less as the back is pitched: Whole_Back)
      P  : constant Vec3 := Mid + Fw * ((if Is_Fore (L) then 1.0 else -1.0)
                                        * (if Whole_Back and then A.Half > 0.0 then A.Half else 0.5 * A.D.Spine))
                            + Rt * ((if Is_Left (L) then -1.0 else 1.0) * A.D.Half_W);
   begin
      return (P.X, P.Y, Ground ((P.X, P.Y, Mid.Z)));
   end Rest;

   ------------------------------------------------------------------ spawning

   function Spawn (C : Class; Where : Vec3; Facing : Float; Seed : U64; Winter : Boolean) return Natural is
   begin
      if N = Max_Animals then
         return 0;
      end if;
      N := N + 1;
      declare
         A  : Animal renames Herd (N);
         Gz : constant Float := Ground (Where);
         Fw : constant Vec3 := (Cos (Facing), Sin (Facing), 0.0);
      begin
         A := (others => <>);
         A.Used := True;
         A.C := C;
         A.D := Dims_Of (C);
         A.Seed := Seed;
         A.Winter := Winter;
         A.Target := (Where.X, Where.Y, Gz);
         A.Lively := (if C = Fawn then 1.3 else 0.9 + 0.2 * Hash01 (A, 1, 0));
         A.Root := S3.Make ((1.4 * A.Lively, 0.95, 0.3), Flat (A.Target));
         A.Heading := S1.Make ((0.9 * A.Lively, 1.0, 0.0), Facing);
         A.Neck := S1.Make ((1.2 * A.Lively, 0.85, 0.0), 0.5);
         A.Yaw := S1.Make ((1.0 * A.Lively, 0.8, 0.0), 0.0);
         A.Bob := S1.Make ((3.0, 0.7, 0.0), 0.0);
         A.Next_Look := 0.5 + 2.0 * Hash01 (A, 2, 0);
         for L in Leg loop
            A.H (L).Pos := Rest (A, A.Target, Fw, L);
         end loop;
      end;
      declare
         Dummy : constant Castle.Figures.Look_Id := Look_Of (C, Winter);   --  made now, not mid-frame
      begin
         null;
      end;
      return N;
   end Spawn;

   procedure Drive (I : Positive; Where : Vec3; M : Mode) is
   begin
      if I <= N then
         Herd (I).Target := Where;
         Herd (I).M := M;
      end if;
   end Drive;

   procedure Set_Winter (I : Positive; Winter : Boolean) is
   begin
      if I <= N then
         Herd (I).Winter := Winter;
      end if;
   end Set_Winter;

   procedure Clear is
   begin
      N := 0;
   end Clear;

   procedure Restyle (I : Positive; C : Class) is
   begin
      if I <= N and then Herd (I).C /= C then
         Herd (I).C := C;
         Herd (I).D := Dims_Of (C);
         declare
            Dummy : constant Castle.Figures.Look_Id := Look_Of (C, Herd (I).Winter);
         begin
            null;
         end;
      end if;
   end Restyle;

   procedure Remove (I : Positive) is
   begin
      if I <= N then
         Herd (I).Used := False;
      end if;
   end Remove;

   procedure Spawn_Walker (C : Class; From, To : Vec3; Speed : Float; Seed : U64; Winter : Boolean) is
      K : constant Natural := Spawn (C, From, Arctan (To.Y - From.Y, To.X - From.X), Seed, Winter);
   begin
      if K > 0 then
         Herd (K).Walker := True;
         Herd (K).A := Herd (K).Target;
         Herd (K).B := (To.X, To.Y, -1.0);
         Herd (K).Pace := Speed;
      end if;
   end Spawn_Walker;

   --  a walker's target: along its route at its pace, back and forth
   procedure Walk (A : in out Animal; Dt : Float) is
      R : Castle.Nav.Route renames A.Route;
   begin
      if A.Pause > 0.0 then
         A.Pause := A.Pause - Dt;
         return;
      end if;
      if R.N < 2 then
         --  (kept to the ground round its two ends, as a walking serf's is: Castle.Serfs.Plan_Route)
         R := Castle.Nav.Plan (A.Target, (if A.To_B then A.B else A.A),
                               Within => Castle.Nav.Within_M ((A.A.X + A.B.X) / 2.0, (A.A.Y + A.B.Y) / 2.0,
                                                              Sqrt ((A.A.X - A.B.X) ** 2 + (A.A.Y - A.B.Y) ** 2) / 2.0
                                                              + Castle.Serfs.Walker_Round_M));
         A.Leg_I := 1;
         A.Along := 0.0;
         if R.N < 2 then
            A.Pause := 2.0;
            return;
         end if;
      end if;
      declare
         Move : Float := A.Pace * Dt;
      begin
         while Move > 0.0 and then A.Leg_I < R.N loop
            declare
               L : constant Float := R.Pts (A.Leg_I + 1).D - R.Pts (A.Leg_I).D;
            begin
               if A.Along + Move < L then
                  A.Along := A.Along + Move;
                  Move := 0.0;
               else
                  Move := Move - (L - A.Along);
                  A.Leg_I := A.Leg_I + 1;
                  A.Along := 0.0;
               end if;
            end;
         end loop;
         if A.Leg_I >= R.N then
            A.Target := R.Pts (R.N).P;
            A.To_B := not A.To_B;
            R.N := 0;
            A.Pause := 1.5;
         else
            declare
               P0 : constant Vec3 := R.Pts (A.Leg_I).P;
               P1 : constant Vec3 := R.Pts (A.Leg_I + 1).P;
               L  : constant Float := R.Pts (A.Leg_I + 1).D - R.Pts (A.Leg_I).D;
               T  : constant Float := (if L > 0.0 then A.Along / L else 0.0);
            begin
               A.Target := P0 + (P1 - P0) * T;
            end;
         end if;
      end;
   end Walk;

   ------------------------------------------------------------------ animate

   procedure Animate (A : in out Animal; Dt : Float) is
      Size : constant Float := A.D.Size;
   begin
      A.Clock := A.Clock + Dt;
      if A.Walker then
         Walk (A, Dt);
      end if;

      --  the body follows where it is meant to be
      S3.Update (A.Root, Dt, Flat (A.Target));
      declare
         Mid0 : constant Vec3 := S3.Value (A.Root);
         V    : constant Vec3 := Flat (S3.Rate (A.Root));
         Spd  : constant Float := Len (V);
         Want_H : constant Float :=
           (if Spd > 0.2 then Arctan (V.Y, V.X) else S1.Value (A.Heading));
         Hd   : Float;
         Fw   : Vec3;
         Mid  : Vec3;
      begin
         A.Spd := Spd;
         S1.Update (A.Heading, Dt, Castle.Poses.Unwrap (Want_H, S1.Value (A.Heading)));
         Hd := S1.Value (A.Heading);
         Fw := (Cos (Hd), Sin (Hd), 0.0);
         Mid := (Mid0.X, Mid0.Y, Ground ((Mid0.X, Mid0.Y, A.Target.Z)));

         --  the gait, with a little hysteresis
         declare
            S  : constant Float := Spd / Size;
            Up : constant Float := (if A.G = Stand then 1.0 else 0.85);
         begin
            A.G := (if S < Walk_From * Up then Stand
                    elsif S < Trot_From * (if A.G >= Trot then 0.85 else 1.0) then Walk
                    elsif S < Bound_From * (if A.G = Bound then 0.85 else 1.0) then Trot
                    else Bound);
         end;

         --  the hooves
         if A.G = Stand then
            --  one hoof at a time, the one furthest out of place
            declare
               Any_Up : Boolean := False;
               Worst  : Leg := Fore_L;
               Err    : Float := 0.0;
            begin
               for L in Leg loop
                  Any_Up := Any_Up or else A.H (L).Swinging;
                  declare
                     E : constant Float := Len (Flat (Rest (A, Mid, Fw, L) - A.H (L).Pos));
                  begin
                     if E > Err then
                        Err := E;
                        Worst := L;
                     end if;
                  end;
               end loop;
               if not Any_Up and then Err > 0.1 * Size then
                  A.H (Worst) := (Pos => A.H (Worst).Pos, Swinging => True, From => A.H (Worst).Pos,
                                  To => Rest (A, Mid, Fw, Worst), T => 0.0, Dur => 0.3, Lift => 0.06 * Size,
                                  Height => 0.0);
               end if;
            end;
         else
            declare
               Sp : constant Gait_Spec := Specs (A.G);
               Stride : constant Float := Sp.Stride * Size;
               Cycle  : constant Float := Stride / Float'Max (0.05, Spd);   --  seconds
               Old    : constant Float := A.Phase;
            begin
               A.Phase := A.Phase + Dt / Cycle;
               pragma Unreferenced (Old);
               for L in Leg loop
                  declare
                     --  where this hoof is in its own cycle: down from 0 to Duty,
                     --  in the air from Duty back round to 0
                     Ph     : constant Float := Frac (A.Phase - Sp.Offset (L));
                     Base   : constant Vec3 := Rest (A, Mid, Fw, L);
                     Behind : constant Float := Len (Flat (Base - A.H (L).Pos));
                     --  as far as the leg reaches with the body no lower than 80 %
                     Leg_L  : constant Float :=
                       (if Is_Fore (L) then A.D.Fore_Upper + A.D.Fore_Lower else A.D.Hind_Upper + A.D.Hind_Lower);
                     Low_H  : constant Float := 0.8 * (if Is_Fore (L) then A.D.Shoulder_H else A.D.Hip_H) - A.D.Hoof;
                     Reach  : constant Float := Sqrt (Float'Max (0.01, (0.98 * Leg_L) ** 2 - Low_H ** 2));
                     Due    : constant Boolean := Ph >= Sp.Duty;   --  its time in the air
                  begin
                     if not A.H (L).Swinging and then (Due or else Behind > Reach) then
                        declare
                           --  in its turn: land as its cycle comes round; out of it
                           --  (left behind): a quick step, to be back in its turn
                           --  (never a long hover: at a crawl a cycle lasts seconds)
                           Dur  : constant Float :=
                             (if Due then Float'Max (0.08, Float'Min (0.45 * Size ** 0.5, (1.0 - Ph) * Cycle))
                              else Float'Max (0.08, Float'Min (0.3, 0.25 * Cycle)));
                           Ph_L : constant Float := Frac (Ph + Dur / Cycle);   --  where it lands in its cycle
                           --  so that its stance ends half a stance behind the hip
                           Ahead : constant Float := (0.5 * Sp.Duty - (if Ph_L < Sp.Duty then Ph_L else 0.0)) * Stride;
                           Land : constant Vec3 := Base + V * Dur + Fw * Ahead;
                        begin
                           A.H (L) := (Pos => A.H (L).Pos, Swinging => True, From => A.H (L).Pos,
                                       To => (Land.X, Land.Y, Ground ((Land.X, Land.Y, Mid.Z))),
                                       T => 0.0, Dur => Dur, Lift => Sp.Lift * Size, Height => 0.0);
                        end;
                     end if;
                  end;
               end loop;
            end;
         end if;
         for L in Leg loop
            declare
               H : Hoof_State renames A.H (L);
            begin
               if H.Swinging then
                  H.T := H.T + Dt / H.Dur;
                  if H.T >= 1.0 then
                     H.Swinging := False;
                     H.Pos := H.To;
                     H.Height := 0.0;
                  else
                     declare
                        T : constant Float := H.T * H.T * (3.0 - 2.0 * H.T);
                     begin
                        H.Pos := H.From + (H.To - H.From) * T;
                        H.Height := H.Lift * Sin (Pi * H.T);
                     end;
                  end if;
               end if;
            end;
         end loop;

         --  the body over the hooves: hips and withers at their heights over
         --  the ground under them, lifted a little in the bound's flight
         declare
            Half0 : constant Float := 0.5 * A.D.Spine;
            Hip_0 : constant Vec3 := Mid - Fw * Half0;
            Sh_0  : constant Vec3 := Mid + Fw * Half0;
            Hz0   : constant Float := Ground ((Hip_0.X, Hip_0.Y, Mid.Z));
            Sz0   : constant Float := Ground ((Sh_0.X, Sh_0.Y, Mid.Z));
            --  Whole_Back.  The pitch the ground under the two ends asks of the back, no steeper than
            --  one is drawn; pitched, the two ends are that much nearer each other across the ground
            --  (a back's length apart along the back), and it is the ground there they stand over.
            Rise  : constant Float := A.D.Shoulder_H - A.D.Hip_H;
            Tan0  : constant Float := Clamp ((Sz0 - Hz0 + Rise) / A.D.Spine, -Back_Pitch_Tan, Back_Pitch_Tan);
            Half  : constant Float :=
              (if Whole_Back then 0.5 * Sqrt (A.D.Spine ** 2 + Rise ** 2) / Sqrt (1.0 + Tan0 ** 2) else Half0);
            Hip_G : constant Vec3 := (if Whole_Back then Mid - Fw * Half else Hip_0);
            Sh_G  : constant Vec3 := (if Whole_Back then Mid + Fw * Half else Sh_0);
            Hz1   : constant Float := (if Whole_Back then Ground ((Hip_G.X, Hip_G.Y, Mid.Z)) else Hz0);
            Sz1   : constant Float := (if Whole_Back then Ground ((Sh_G.X, Sh_G.Y, Mid.Z)) else Sz0);
            --  Where the ground is steeper than that, the higher end stands on its own ground and
            --  the lower is held up as far as the back lets it hang: its legs reach down for their
            --  hooves and fall short (never the higher end sunk into the hill).
            Most  : constant Float := 2.0 * Half * Back_Pitch_Tan;
            Hz    : constant Float := (if Whole_Back then Float'Max (Hz1, Sz1 + Rise - Most) else Hz1);
            Sz    : constant Float := (if Whole_Back then Float'Max (Sz1, Hz1 - Rise - Most) else Sz1);
            Flight : Float := 0.0;
            Down   : Natural := 0;
         begin
            for L in Leg loop
               if not A.H (L).Swinging then
                  Down := Down + 1;
               end if;
            end loop;
            if A.G = Bound and then Down = 0 then
               Flight := 0.07 * Size;
            elsif A.G = Trot then
               Flight := 0.03 * Size * Sin (2.0 * Pi * A.Phase * 2.0);
            elsif A.G = Walk then
               Flight := -0.012 * Size * Cos (4.0 * Pi * A.Phase);
            end if;
            S1.Update (A.Bob, Dt, Flight);
            A.Half := Half;
            A.P.Hips := (Hip_G.X, Hip_G.Y, Hz + A.D.Hip_H + S1.Value (A.Bob));
            A.P.Shoulders := (Sh_G.X, Sh_G.Y, Sz + A.D.Shoulder_H + S1.Value (A.Bob));
            --  never higher than the planted hooves let the legs reach; each
            --  end goes down at least half as far as the other, so the back
            --  stays nearer level
            declare
               Rt : constant Vec3 := (Fw.Y, -Fw.X, 0.0);
               Hip0 : constant Float := A.P.Hips.Z;
               Sh0  : constant Float := A.P.Shoulders.Z;
            begin
               for L in Leg loop
                  if not A.H (L).Swinging then        --  a hoof in the air may fall short
                     declare
                        Fore  : constant Boolean := Is_Fore (L);
                        Joint : constant Vec3 := (if Fore then A.P.Shoulders else A.P.Hips)
                                                 + Rt * ((if Is_Left (L) then -1.0 else 1.0) * A.D.Half_W);
                        Fet   : constant Vec3 := A.H (L).Pos + (0.0, 0.0, A.D.Hoof + A.H (L).Height);
                        Leg_L : constant Float :=
                          0.99 * (if Fore then A.D.Fore_Upper + A.D.Fore_Lower else A.D.Hind_Upper + A.D.Hind_Lower);
                        Hd    : constant Float := Len (Flat (Joint - Fet));
                        Top   : constant Float := Fet.Z + Sqrt (Float'Max (0.0, Leg_L ** 2 - Hd ** 2));
                     begin
                        --  but never below 85 % of standing: past that the hoof
                        --  falls a little short, which shows less than a dropped back
                        if Hd >= 0.95 * Leg_L then
                           null;               --  out of reach across: lowering the body wouldn't help
                        elsif Fore then
                           A.P.Shoulders.Z := Float'Min (A.P.Shoulders.Z, Float'Max (Top, Sz + 0.85 * A.D.Shoulder_H));
                        else
                           A.P.Hips.Z := Float'Min (A.P.Hips.Z, Float'Max (Top, Hz + 0.85 * A.D.Hip_H));
                        end if;
                     end;
                  end if;
               end loop;
               declare
                  Hip_Drop : constant Float := Hip0 - A.P.Hips.Z;
                  Sh_Drop  : constant Float := Sh0 - A.P.Shoulders.Z;
               begin
                  A.P.Hips.Z := Hip0 - Float'Max (Hip_Drop, 0.5 * Sh_Drop);
                  A.P.Shoulders.Z := Sh0 - Float'Max (Sh_Drop, 0.5 * Hip_Drop);
               end;
            end;
            --  one piece: the hips and the withers no further apart than they stand on level ground
            declare
               D    : constant Vec3 := A.P.Shoulders - A.P.Hips;
               L    : constant Float := Len (D);
               Rest : constant Float := Sqrt (A.D.Spine ** 2 + (A.D.Shoulder_H - A.D.Hip_H) ** 2);
            begin
               if Whole_Back and then L > Rest then
                  declare
                     C : constant Vec3 := (A.P.Hips + A.P.Shoulders) * 0.5;
                  begin
                     A.P.Hips := C - D * (0.5 * Rest / L);
                     A.P.Shoulders := C + D * (0.5 * Rest / L);
                  end;
               end if;
               declare
                  Drawn : constant Float := Len (A.P.Shoulders - A.P.Hips) / Rest;
               begin
                  Back_N.Frames := Back_N.Frames + 1;
                  if Drawn > Long_Back then
                     Back_N.Long := Back_N.Long + 1;
                  end if;
                  Back_N.Longest := Float'Max (Back_N.Longest, Drawn);
               end;
            end;
            A.P.Flex := (if A.G = Bound then 0.08 * Sin (2.0 * Pi * (A.Phase - 0.25)) else 0.0);
            A.P.Roll := 0.0;
         end;

         --  the head: down to the grass grazing, up and looking about when
         --  standing, forward when moving
         declare
            Want_Neck : constant Float :=
              (case A.G is
                  when Stand => (case A.M is when Graze => 2.25, when Alert => 0.45, when Idle => 0.6),
                  when Walk  => 0.8,
                  when Trot  => 0.95,
                  when Bound => 1.25);
         begin
            if A.Clock > A.Next_Look then
               A.Look := (if A.G = Stand and then A.M /= Graze then 1.2 * (Hash01 (A, 3, Integer (A.Clock)) - 0.5)
                          else 0.0);
               A.Next_Look := A.Clock + 1.5 + 3.0 * Hash01 (A, 4, Integer (A.Clock));
            end if;
            S1.Update (A.Neck, Dt, Want_Neck);
            S1.Update (A.Yaw, Dt, (if A.G = Stand then A.Look else 0.0));
            A.P.Neck := S1.Value (A.Neck);
            A.P.Neck_Yaw := Clamp (S1.Value (A.Yaw), -0.9, 0.9);
         end;
         for L in Leg loop
            A.P.Hoof (L) := A.H (L).Pos + (0.0, 0.0, A.D.Hoof + A.H (L).Height);
         end loop;
      end;
   end Animate;

   procedure Update (Dt : Float) is
   begin
      if Dt <= 0.0 then
         return;
      end if;
      for I in 1 .. N loop
         if Herd (I).Used then
            Animate (Herd (I), Float'Min (Dt, 0.25));
         end if;
      end loop;
   end Update;

   procedure Submit is
      F : Castle.Poses.Frames;
   begin
      for I in 1 .. N loop
         declare
            A : Animal renames Herd (I);
         begin
            if A.Used then
               Castle.Deer.Solve (A.D, A.P, F, A.Ok);
               Castle.Figures.Add (Look_Of (A.C, A.Winter), F);
               declare
                  M : constant Vec3 := (A.P.Hips + A.P.Shoulders) * 0.5;
               begin
                  Castle.Figures.Add_Shadow ((M.X, M.Y, Ground ((M.X, M.Y, M.Z - A.D.Hip_H))),
                                             0.35 * A.D.Size + 0.1);
               end;
            end if;
         end;
      end loop;
   end Submit;

   ------------------------------------------------------------------ for checks

   function Count return Natural is (N);
   function Where (I : Positive) return Vec3 is
     (if I <= N then (S3.Value (Herd (I).Root).X, S3.Value (Herd (I).Root).Y, Herd (I).Target.Z)
      else (0.0, 0.0, 0.0));
   function Speed (I : Positive) return Float is (if I <= N then Herd (I).Spd else 0.0);
   function Gait_Of (I : Positive) return Gait is (if I <= N then Herd (I).G else Stand);
   function Planted (I : Positive; L : Leg) return Boolean is (I <= N and then not Herd (I).H (L).Swinging);
   function Hoof_At (I : Positive; L : Leg) return Vec3 is
     (if I <= N then Herd (I).H (L).Pos else (0.0, 0.0, 0.0));
   function Reached (I : Positive) return Boolean is
   begin
      if I > N then
         return False;
      end if;
      for L in Leg loop
         if not Herd (I).H (L).Swinging and then not Herd (I).Ok (L) then
            return False;
         end if;
      end loop;
      return True;
   end Reached;
   function Class_Of (I : Positive) return Class is (if I <= N then Herd (I).C else Doe);
   function Pose_Of (I : Positive) return Castle.Deer.Pose is (if I <= N then Herd (I).P else (others => <>));

end Castle.Animals;
