with Ada.Numerics;
with Ada.Text_IO;
with Interfaces; use Interfaces;
with Castle.Bodies.Voxels;
with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Castle.Blocks;      use Castle.Blocks;
with Castle.World_Blocks;
with Castle.Figures;
with Castle.Poses;       use Castle.Poses;
with Castle.Second_Order_1;
with Castle.Second_Order_3;
with Castle.Nav;
use type Castle.Nav.Outcome;
with Castle.Marks;
with Castle.Props;
with Castle.Text;

package body Castle.Serfs is

   Seat_Hip : constant := 0.45;   --  sitting: the hips this far over the ground (a seat log 35 cm high)

   package S1 renames Castle.Second_Order_1;
   package S3 renames Castle.Second_Order_3;
   Pi : constant := Ada.Numerics.Pi;

   Made_Up_Ground : Solid_Reader := null;       --  (the checks': Set_Ground_Source)
   procedure Set_Ground_Source (Solid : Solid_Reader) is
   begin
      Made_Up_Ground := Solid;
   end Set_Ground_Source;

   function Ground_At (X, Y, Near_Z : Float) return Float is
      Bx  : constant Integer := Integer (Float'Floor (X * 4.0));
      By  : constant Integer := Integer (Float'Floor (Y * 4.0));
      Top : constant Integer := Integer (Float'Floor (Near_Z * 4.0)) + 4;
   begin
      if Made_Up_Ground /= null then
         for Bz in reverse Top - 24 .. Top loop
            if Made_Up_Ground (Bx, By, Bz) and then not Made_Up_Ground (Bx, By, Bz + 1) then
               return Float (Bz + 1) * 0.25;
            end if;
         end loop;
         return Near_Z;
      end if;
      for Bz in reverse Top - 24 .. Top loop
         if Class_Of (Castle.World_Blocks.Block_At (Bx, By, Bz).Mat) = Solid
           and then Class_Of (Castle.World_Blocks.Block_At (Bx, By, Bz + 1).Mat) /= Solid
         then
            return Float (Bz + 1) * 0.25;
         end if;
      end loop;
      return Near_Z;
   end Ground_At;

   function Flat (V : Vec3) return Vec3 is ((V.X, V.Y, 0.0));
   function Len (V : Vec3) return Float is (Sqrt (Dot (V, V)));
   function Clamp (X, Lo, Hi : Float) return Float is (Float'Max (Lo, Float'Min (Hi, X)));
   function Smooth (T : Float) return Float is (T * T * (3.0 - 2.0 * T));
   function Other (S : Side) return Side is (if S = Left then Right else Left);
   Out_Of : constant array (Side) of Float := [Left => -1.0, Right => 1.0];   --  along the body's right

   type Foot_State is record
      Pos      : Vec3;                 --  the ankle now
      Base     : Float := 0.0;         --  its height without the lift of a swing
      From, To : Vec3;
      T        : Float := 1.0;         --  swing progress; 1 is planted
      Dur      : Float := 0.4;
      Head, From_Head, To_Head : Float := 0.0;
   end record;
   type Feet_Array is array (Side) of Foot_State;
   type Arm_Filters is array (Side) of S1.Filter;

   type Serf is record
      Used     : Boolean := False;
      Last_F   : Frames;                --  its bones as last submitted (what a cloth hangs on)
      Last_Home : Frames;                 --  (and before any turn: Frames_Home)
      G        : Genome;
      O        : Outfit;
      R        : Rig;
      Slot     : Castle.Figures.Look_Id := 1;
      Vox      : Natural := 0;              --  its look as voxel parts (Castle.Figures.Vox_Look_Id; 0: drawn as boxes)
      --  where it is meant to be (later: the simulation's business)
      Target   : Vec3;
      Walker   : Boolean := False;
      A, B     : Vec3;
      Speed    : Float := 1.3;
      Pace     : Float := 0.0;            --  the speed now
      To_B     : Boolean := True;
      Pause    : Float := 0.0;
      Facing   : Float := 0.0;
      Prev_Target : Vec3;
      Up_Want, Up : Float := 0.0;          --  how far over the ground it stands (on a ladder), asked and as drawn
      Turn_C  : Float := 1.0;              --  drawn turned about Turn_P (Turn_About): the turn's cosine and
      Turn_S  : Float := 0.0;              --  sine (1, 0: not turned)
      Turn_P  : Vec3 := (0.0, 0.0, 0.0);
      Turn_Want, Turn_A : Float := 0.0;    --  the turn asked and as drawn (it comes on and off in a moment)
      Route    : Castle.Nav.Route;         --  walkers: the way to the end they are heading for
      Leg      : Positive := 1;            --  between Route points Leg and Leg + 1
      Along    : Float := 0.0;             --  metres along that leg
      Check_At : Float := 0.0;             --  when to look whether the ground under the route changed
      Blocked  : Boolean := False;         --  nowhere to go, or the goal out of reach
      Plan_Ms  : Float := 0.0;
      Looked   : Natural := 0;
      Driven   : Boolean := False;         --  the colony says where it is and what it does
      Motion   : Motion_Kind := Stand;
      Spot     : Vec3 := (0.0, 0.0, 0.0);
      Log      : Boolean := False;          --  a log on the off shoulder
      Buckets  : Boolean := False;          --  a bucket in each hand
      Log_W    : S1.Filter;                --  0 .. 1: the off hand up on it
      Work_W   : S1.Filter;                --  0 .. 1: how far into the work pose
      Work     : Motion_Kind := Stand;      --  the work that pose is of (kept while it fades out)
      Lie_W    : S1.Filter;                --  0 .. 1: lying down
      Side_W   : S1.Filter;                --  0 .. 1: and on its side, curled up (asleep)
      Faces    : Boolean := False;         --  asleep, it turns its face to
      Faces_P  : Vec3 := (0.0, 0.0, 0.0);  --  this (Lie_Facing)
      Tool_W   : S1.Filter;                --  0 .. 1: its tool from where it is stowed into the hand
      Tool_Hold : Float := 0.0;            --  seconds the tool stays in the hand yet
      --  how it shows it
      Root     : S3.Filter;
      Heading  : S1.Filter;
      Hip_Z    : S1.Filter;
      Lean     : S1.Filter;
      Arms     : Arm_Filters;
      Gaze     : S3.Filter;            --  (yaw, pitch, 0) of the head
      Sway     : S1.Filter;
      Feet     : Feet_Array;
      Last     : Side := Right;
      Clock    : Float := 0.0;
      Next_Glance : Float := 0.0;
      Glance   : Vec3 := (0.0, 0.0, 0.0);
      Shift    : Float := 0.0;         --  standing: which leg takes the weight
      Next_Shift : Float := 0.0;
      Ground   : Float := 0.0;
      Lively   : Float := 1.0;         --  frequency scale: children quick, elders slow
      Bounce   : Float := 0.7;         --  damping: lower is springier
      P        : Pose;
   end record;

   Serfs   : array (1 .. Max_Serfs) of Serf;
   N_Serfs : Natural := 0;

   function Count return Natural is (N_Serfs);

   function Describe (I : Positive) return String is
     (if I <= N_Serfs then Castle.Bodies.Describe (Serfs (I).G, Serfs (I).O) else "");

   function Where (I : Positive) return Vec3 is
     (if I <= N_Serfs then (S3.Value (Serfs (I).Root).X, S3.Value (Serfs (I).Root).Y, Serfs (I).Ground)
      else (0.0, 0.0, 0.0));

   function Posed (I : Positive) return Pose is (Serfs (I).P);
   function Frames_Of (I : Positive) return Frames is (Serfs (I).Last_F);
   function Frames_Home (I : Positive) return Frames is (Serfs (I).Last_Home);
   function Rig_Of (I : Positive) return Rig is (Serfs (I).R);

   function Hash01 (S : Serf; K, J : Integer) return Float is (Unit (Hash_2 (S.G.Seed + 99, K, J)));

   --  A serf's look as voxel parts, made from its rig and skin (Castle.Bodies.Voxels.Voxel_People;
   --  the game's --no-voxel: none, drawn as boxes as it was).  0 when there is none: off, no slot
   --  free, or a look too big for its parts (drawn as boxes, and said once).
   Scratch_Look : Castle.Bodies.Voxels.Look_Access := null;
   Too_Big_Said : Boolean := False;
   function Voxel_Look_Of (R : Rig; Skin : Skin_Pixels) return Natural is
   begin
      if not Castle.Bodies.Voxels.Voxel_People
        or else Castle.Figures.Voxel_Looks_Used = Castle.Figures.Max_Vox_Looks
      then
         return 0;
      end if;
      if Castle.Bodies.Voxels."=" (Scratch_Look, null) then
         Scratch_Look := new Castle.Bodies.Voxels.Voxel_Look;
      end if;
      Castle.Bodies.Voxels.Build (R, Skin, Scratch_Look.all, Brief_Mesh => False);
      return Castle.Figures.New_Voxel_Look (Scratch_Look.all);
   exception
      when Constraint_Error =>
         if not Too_Big_Said then
            Too_Big_Said := True;
            Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, "serfs: a look too big for its voxel parts, drawn as boxes");
         end if;
         return 0;
   end Voxel_Look_Of;

   procedure Spawn (G : Genome; O : Outfit; Where : Vec3; Facing : Float;
                    Walker : Boolean; To : Vec3; Speed : Float)
   is
      Skin : Skin_Pixels;
   begin
      if N_Serfs = Max_Serfs or else Castle.Figures.Looks_Used = Castle.Figures.Max_Looks then
         return;
      end if;
      N_Serfs := N_Serfs + 1;
      declare
         S  : Serf renames Serfs (N_Serfs);
         Gz : constant Float := Ground_At (Where.X, Where.Y, Where.Z);
      begin
         S := (others => <>);
         S.Used := True;
         S.G := G;
         S.O := O;
         Build (G, O, S.R, Skin);
         S.Slot := Castle.Figures.New_Look (S.R, Skin);
         S.Vox := Voxel_Look_Of (S.R, Skin);
         S.Target := (Where.X, Where.Y, Gz);
         S.Prev_Target := S.Target;
         S.Ground := Gz;
         S.Walker := Walker;
         S.A := S.Target;
         S.B := To;                            --  Z < 0: whatever floor is highest there
         S.Speed := Speed;
         S.Facing := (if Walker then Heading_Of (To - Where, Facing) else Facing);
         S.Lively := (if G.Age < 15.0 then 1.35 elsif G.Age > 60.0 then 0.7
                      else 0.9 + 0.2 * Hash01 (S, 1, 0));
         S.Bounce := 0.55 + 0.35 * Hash01 (S, 2, 0) + (if G.Age > 60.0 then 0.2 else 0.0);
         S.Root    := S3.Make ((1.6 * S.Lively, 0.9, 0.5), Flat (S.Target));
         S.Heading := S1.Make ((1.1 * S.Lively, 0.9, 0.0), S.Facing);
         S.Hip_Z   := S1.Make ((3.0 * S.Lively, 0.6 + 0.2 * S.Bounce, 0.0), Gz + S.R.Hip);
         S.Lean    := S1.Make ((1.5, 1.0, 0.0), 0.0);
         S.Sway    := S1.Make ((1.2 * S.Lively, 0.8, 0.0), 0.0);
         S.Gaze    := S3.Make ((1.2 * S.Lively, S.Bounce, -0.2), (0.0, 0.0, 0.0));
         S.Work_W  := S1.Make ((2.0 * S.Lively, 1.0, 0.0), 0.0);
         S.Log_W   := S1.Make ((2.5 * S.Lively, 1.0, 0.0), 0.0);
         S.Lie_W   := S1.Make ((0.9 * S.Lively, 1.0, 0.0), 0.0);
         S.Side_W  := S1.Make ((0.9 * S.Lively, 1.0, 0.0), 0.0);
         S.Tool_W  := S1.Make ((2.2 * S.Lively, 1.0, 0.0), 0.0);
         for Sd in Side loop
            S.Arms (Sd) := S1.Make ((2.8 * S.Lively, 0.45 + 0.25 * S.Bounce, 0.0), 0.0);   --  trails the legs by about 30 degrees
         end loop;
         S.P := Standing (S.R, S.Target, S.Facing);
         for Sd in Side loop
            S.Feet (Sd).Pos := S.P.Foot (Sd);
            S.Feet (Sd).Base := S.P.Foot (Sd).Z;
            S.Feet (Sd).From := S.P.Foot (Sd);
            S.Feet (Sd).To := S.P.Foot (Sd);
            S.Feet (Sd).Head := S.Facing;
         end loop;
         S.Next_Glance := 0.5 + 2.0 * Hash01 (S, 3, 0);
         S.Next_Shift := 1.0 + 3.0 * Hash01 (S, 4, 0);
      end;
   end Spawn;

   procedure Spawn_Lineup (N : Positive; Centre : Vec3; Facing : Float; Seed : U64; Winter : Boolean) is
      Across : constant Vec3 := (-Sin (Facing), Cos (Facing), 0.0);   --  their left: the first stands leftmost seen from in front
   begin
      for I in 1 .. N loop
         declare
            G : constant Genome :=
              Random_Genome (Derive (Seed, U64 (I)), Child => I mod 5 = 0, Elder => I mod 7 = 3);
            O : constant Outfit := (Job => Job_Kind'Val (I mod (Job_Kind'Pos (Job_Kind'Last) + 1)),
                                    Winter => Winter, Cloak_Off => False);
            Off : constant Float := (Float (I) - Float (N + 1) / 2.0) * 0.9;
         begin
            Spawn (G, O, Centre + Across * Off, Facing, False, Centre, 0.0);
         end;
      end loop;
   end Spawn_Lineup;

   procedure Spawn_Walker (From, To : Vec3; Seed : U64; Job : Job_Kind; Winter : Boolean;
                           Speed : Float := 1.3) is
      Top : constant Float := Castle.Nav.Surface_Z (From.X, From.Y);
   begin
      Spawn (Random_Genome (Seed), (Job, Winter, False), (From.X, From.Y, (if Top >= 0.0 then Top else From.Z)),
             0.0, True, (To.X, To.Y, -1.0), Speed);
   end Spawn_Walker;

   ------------------------------------------------------------------ routes

   procedure Plan_Route (S : in out Serf) is
      Goal : constant Vec3 := (if S.To_B then S.B else S.A);
      --  (kept to the ground round its two ends: the game holds the whole map
      --  since 2026-11-14, and an end that cannot be got to would be looked
      --  for over all of it)
      Mid  : constant Vec3 := ((S.A.X + S.B.X) / 2.0, (S.A.Y + S.B.Y) / 2.0, 0.0);
      Half : constant Float := Sqrt ((S.A.X - S.B.X) ** 2 + (S.A.Y - S.B.Y) ** 2) / 2.0;
   begin
      S.Route := Castle.Nav.Plan ((S.Target.X, S.Target.Y, S.Ground), Goal,
                                  Within => Castle.Nav.Within_M (Mid.X, Mid.Y, Half + Walker_Round_M));
      S.Plan_Ms := Castle.Nav.Last_Stats.Seconds * 1000.0;
      S.Looked := Castle.Nav.Last_Stats.Looked_At;
      S.Leg := 1;
      S.Along := 0.0;
      S.Check_At := S.Clock + 0.5;
      S.Blocked := S.Route.Result /= Castle.Nav.Found;
      if S.Route.Result = Castle.Nav.None or else S.Route.N < 2 then
         S.Route.N := 0;
         S.Pause := 2.0;               --  nowhere walkable from here: wait, then try again
         S.Pace := 0.0;
      end if;
   end Plan_Route;

   procedure Plan_Walkers is
   begin
      for I in 1 .. N_Serfs loop
         if Serfs (I).Walker and then Serfs (I).Route.N = 0 and then Serfs (I).Pause <= 0.0 then
            Plan_Route (Serfs (I));
         end if;
      end loop;
   end Plan_Walkers;

   function Route_Summary (I : Positive) return String is
      use Castle.Text;
      S : Serf renames Serfs (I);
   begin
      if I > N_Serfs or else not S.Walker then
         return "";
      end if;
      return Castle.Nav.Outcome'Image (S.Route.Result) & ", " & Img (Castle.Nav.Length (S.Route), 1) & " m, "
        & Img (Castle.Nav.Total_Time (S.Route), 1) & " s at a walk; planned in " & Img (S.Plan_Ms, 2)
        & " ms, " & Img (S.Looked) & " floors looked at";
   end Route_Summary;

   --  Along the route at the pace each leg takes (slower uphill, wading,
   --  on sand), speeding up and slowing down at 2 m/s/s, and every half
   --  second a look whether the ground under the rest of it has changed.
   procedure Walk (S : in out Serf; Dt : Float) is
      R : Castle.Nav.Route renames S.Route;
   begin
      if S.Pause > 0.0 then
         S.Pause := S.Pause - Dt;
         return;
      end if;
      if R.N < 2 then
         Plan_Route (S);
         if R.N < 2 then
            return;
         end if;
      end if;
      if S.Clock >= S.Check_At then
         S.Check_At := S.Clock + 0.5;
         if Castle.Nav.Changed (R) then
            --  a route that falls short is planned again too: the change may
            --  have opened the way (a bridge built, a wall dug through)
            if R.Result = Castle.Nav.Found and then Castle.Nav.Still_Good (R, S.Leg) then
               Castle.Nav.Restamp (R);
            else
               Plan_Route (S);            --  dug up or built over: from here, again
               if R.N < 2 then
                  return;
               end if;
            end if;
         end if;
      end if;
      declare
         Seg_L : constant Float := R.Pts (S.Leg + 1).D - R.Pts (S.Leg).D;
         Seg_T : constant Float := R.Pts (S.Leg + 1).T - R.Pts (S.Leg).T;
         Want  : constant Float :=
           (if Seg_T > 0.001 and then Seg_L > 0.001 then Seg_L / Seg_T else Castle.Nav.Walk_Speed)
           * S.Speed / Castle.Nav.Walk_Speed;
         Left  : constant Float := R.Pts (R.N).D - (R.Pts (S.Leg).D + S.Along);
         Move  : Float;
      begin
         if Want > S.Pace then
            S.Pace := Float'Min (Want, S.Pace + 2.0 * Dt);
         else
            S.Pace := Float'Max (Want, S.Pace - 3.0 * Dt);
         end if;
         S.Pace := Float'Min (S.Pace, Sqrt (2.0 * 2.0 * Float'Max (0.0, Left)));
         Move := S.Pace * Dt;
         while Move > 0.0 and then S.Leg < R.N loop
            declare
               L : constant Float := R.Pts (S.Leg + 1).D - R.Pts (S.Leg).D;
            begin
               if S.Along + Move < L then
                  S.Along := S.Along + Move;
                  Move := 0.0;
               else
                  Move := Move - (L - S.Along);
                  S.Leg := S.Leg + 1;
                  S.Along := 0.0;
               end if;
            end;
         end loop;
         if S.Leg >= R.N or else Left < 0.02 then
            --  there, or as near as it can get: turn round after a breather
            S.Target := R.Pts (R.N).P;
            S.To_B := not S.To_B;
            S.Pause := 1.5;
            S.Pace := 0.0;
            R.N := 0;
         else
            declare
               A : constant Vec3 := R.Pts (S.Leg).P;
               B : constant Vec3 := R.Pts (S.Leg + 1).P;
               L : constant Float := R.Pts (S.Leg + 1).D - R.Pts (S.Leg).D;
               T : constant Float := (if L > 0.0 then S.Along / L else 0.0);
            begin
               S.Target := (A.X + (B.X - A.X) * T, A.Y + (B.Y - A.Y) * T, A.Z);
            end;
         end if;
      end;
   end Walk;

   Palette : constant array (0 .. 5) of Castle.Marks.Colour :=
     [(1.0, 0.85, 0.3, 0.75), (0.45, 0.85, 1.0, 0.75), (0.75, 1.0, 0.45, 0.75),
      (1.0, 0.6, 0.85, 0.75), (1.0, 1.0, 1.0, 0.7), (0.7, 0.6, 1.0, 0.75)];

   procedure Submit_Routes is
      Lift : constant Vec3 := (0.0, 0.0, 0.08);
   begin
      for I in 1 .. N_Serfs loop
         declare
            S : Serf renames Serfs (I);
            R : Castle.Nav.Route renames S.Route;
            C : constant Castle.Marks.Colour :=
              (if S.Blocked then (1.0, 0.25, 0.2, 0.8) else Palette (I mod Palette'Length));
         begin
            if S.Walker and then R.N >= 2 and then S.Leg < R.N then
               --  each leg lies at the height of its start: the height changes only at points
               Castle.Marks.Strip ((S.Target.X, S.Target.Y, R.Pts (S.Leg).P.Z) + Lift,
                                   (R.Pts (S.Leg + 1).P.X, R.Pts (S.Leg + 1).P.Y, R.Pts (S.Leg).P.Z) + Lift, 0.15, C);
               for K in S.Leg + 1 .. R.N - 1 loop
                  Castle.Marks.Strip (R.Pts (K).P + Lift,
                                      (R.Pts (K + 1).P.X, R.Pts (K + 1).P.Y, R.Pts (K).P.Z) + Lift, 0.15, C);
               end loop;
               declare
                  E : constant Vec3 := R.Pts (R.N).P + Lift;
                  H : constant Float := 0.3;
               begin
                  Castle.Marks.Strip (E + (-H, -H, 0.0), E + (H, -H, 0.0), 0.06, C);
                  Castle.Marks.Strip (E + (H, -H, 0.0), E + (H, H, 0.0), 0.06, C);
                  Castle.Marks.Strip (E + (H, H, 0.0), E + (-H, H, 0.0), 0.06, C);
                  Castle.Marks.Strip (E + (-H, H, 0.0), E + (-H, -H, 0.0), 0.06, C);
               end;
            end if;
         end;
      end loop;
   end Submit_Routes;

   ------------------------------------------------------------------ feet

   --  A swinging foot: across in an ease-in-out, up early when stepping up
   --  and down late when stepping down, lifted on an arc over the way.
   --  Until 70 % of the swing its target follows Land, where the body will
   --  want it when it lands; then it is committed.
   procedure Swing (F : in out Foot_State; Dt : Float; Land : Vec3; Want_Head : Float) is
   begin
      F.T := Float'Min (1.0, F.T + Dt / F.Dur);
      if F.T < 0.7 then
         F.To := Land;
         F.To_Head := Want_Head;
      end if;
      declare
         Hz   : constant Float := Smooth (F.T);
         Up   : constant Float := F.To.Z - F.From.Z;
         Vz   : constant Float :=
           (if Up > 0.01 then 1.0 - (1.0 - F.T) ** 2 elsif Up < -0.01 then F.T ** 2 else Hz);
         Lift : constant Float := (if Up >= 0.0 then 0.06 + 0.45 * Up else 0.05 - 0.15 * Up);
      begin
         F.Base := F.From.Z + Up * Vz;
         F.Pos := (F.From.X + (F.To.X - F.From.X) * Hz, F.From.Y + (F.To.Y - F.From.Y) * Hz,
                   F.Base + Lift * Sin (Pi * F.T));
         F.Head := F.From_Head + (Unwrap (F.To_Head, F.From_Head) - F.From_Head) * Hz;
      end;
   end Swing;

   procedure Animate (S : in out Serf; Dt : Float; Eye : Vec3) is
      R : Rig renames S.R;
   begin
      S.Clock := S.Clock + Dt;
      S.Up := S.Up + (S.Up_Want - S.Up) * Float'Min (1.0, 4.0 * Dt);      --  (up or down its ladder in a moment)
      --  (into a building drawn turned, or out of it: turned with it in a moment, no jump)
      if S.Turn_A /= S.Turn_Want then
         S.Turn_A := S.Turn_A + (S.Turn_Want - S.Turn_A) * Float'Min (1.0, 6.0 * Dt);
         if abs (S.Turn_A - S.Turn_Want) < 2.0E-3 then
            S.Turn_A := S.Turn_Want;
         end if;
         S.Turn_C := (if S.Turn_A = 0.0 then 1.0 else Cos (S.Turn_A));
         S.Turn_S := (if S.Turn_A = 0.0 then 0.0 else Sin (S.Turn_A));
      end if;

      --  1. where it is meant to be: walkers go back and forth along routes
      S.Prev_Target := S.Target;
      if S.Walker then
         Walk (S, Dt);
      end if;

      --  2. the body follows it
      S3.Update (S.Root, Dt, Flat (S.Target));
      declare
         Root : constant Vec3 := S3.Value (S.Root);
         V    : constant Vec3 := Flat (S3.Rate (S.Root));
         Spd  : constant Float := Len (V);
         Walking : constant Boolean := Spd > 0.12;
         Working : constant Boolean := S.Driven and then S.Motion in Pick | Put_Down | Chop | Aim | Eat | Stir | Sit_Eat;
         Want_H : constant Float :=
           (if Spd > 0.25 then Arctan (V.Y, V.X)
            elsif (Working and then S.Motion /= Eat) or else (S.Driven and then S.Motion in Lie | Sleep)
            then Heading_Of (S.Spot - Root, S1.Value (S.Heading))   --  face the work (lying: feet to it)
            elsif S.Walker or else S.Driven then S1.Value (S.Heading) else S.Facing);
         Sitting : constant Boolean := S.Driven and then S.Motion = Sit_Eat and then Spd < 0.35;
         W : Float;                         --  how far into the work pose
         H, Step_T : Float;
         Fw, Rt : Vec3;
         Desired : Points;
         Rise : Float := 0.0;               --  sin pi T of the foot in the air
         Stance : Side := Left;
         Swinging : Boolean := False;
      begin
         S.Ground := Ground_At (Root.X, Root.Y, S.Ground);
         S1.Update (S.Work_W, Dt, (if Working and then Spd < 0.35 then 1.0 else 0.0));
         S1.Update (S.Lie_W, Dt, (if S.Driven and then S.Motion in Lie | Sleep and then Spd < 0.35 then 1.0 else 0.0));
         S1.Update (S.Side_W, Dt, (if S.Driven and then S.Motion = Sleep and then Spd < 0.35 then 1.0 else 0.0));
         W := Clamp (S1.Value (S.Work_W), 0.0, 1.0);
         if Working then
            S.Work := S.Motion;   --  the work pose fades out of this one, not toward the next motion's
         end if;
         --  its tool: in the hand while it works with it, and a little after
         declare
            Out_Now : constant Boolean := S.Driven
              and then ((S.O.Job = Forester and then S.Motion = Chop)
                        or else (S.O.Job = Hunter and then S.Motion in Sneak | Aim));
         begin
            if Out_Now then
               S.Tool_Hold := (if S.O.Job = Hunter then Bow_Hold_S else Axe_Hold_S);
            else
               S.Tool_Hold := Float'Max (0.0, S.Tool_Hold - Dt);
            end if;
            S1.Update (S.Tool_W, Dt, (if Out_Now or else S.Tool_Hold > 0.0 then 1.0 else 0.0));
         end;
         S1.Update (S.Heading, Dt, Unwrap (Want_H, S1.Value (S.Heading)));
         H := S1.Value (S.Heading);
         Fw := (Cos (H), Sin (H), 0.0);
         Rt := (Sin (H), -Cos (H), 0.0);
         --  steps quicken with speed: the speed the body is meant to have,
         --  so the first step out is already a walking step
         Step_T := Clamp (0.52 - 0.1 * Float'Max (Spd, Len (Flat (S.Target - S.Prev_Target)) / Dt), 0.3, 0.52)
           / S.Lively ** 0.3;

         --  3. the feet: where each wants to be, half a step ahead of the hip.
         --  A foot lands that far ahead and lifts as far behind, so the feet
         --  stay within V Step_T / 2 of the hip: a quarter metre at a walk,
         --  which the short legs reach with a 5 cm dip of the pelvis.
         for Sd in Side loop
            declare
               --  sitting, the feet go out in front of the seat
               D : constant Vec3 :=
                 (if Sitting and then W > 0.3 then Root + Fw * 0.42 + Rt * (Out_Of (Sd) * (R.Hip_Half + 0.05))
                  else Root + Rt * (Out_Of (Sd) * R.Hip_Half) + V * (0.42 * Step_T));
            begin
               Desired (Sd) := (D.X, D.Y, Ground_At (D.X, D.Y, S.Ground) + R.Ankle);
            end;
         end loop;
         for Sd in Side loop
            if S.Feet (Sd).T < 1.0 then
               declare
                  F    : Foot_State renames S.Feet (Sd);
                  Land : constant Vec3 := Desired (Sd) + V * ((1.0 - F.T) * F.Dur);   --  where the body will be
                  Lag  : constant Float := Len (Flat (Desired (Other (Sd)) - S.Feet (Other (Sd)).Pos));
               begin
                  --  hurry if the standing foot is being left too far behind
                  Swing (F, Dt * (1.0 + 4.0 * Float'Max (0.0, Lag - 0.6)),
                         (Land.X, Land.Y, Ground_At (Land.X, Land.Y, S.Ground) + R.Ankle), H);
               end;
               if S.Feet (Sd).T >= 1.0 then
                  S.Feet (Sd).Pos := S.Feet (Sd).To;
                  S.Feet (Sd).Base := S.Feet (Sd).To.Z;
                  S.Last := Sd;
               else
                  Swinging := True;
                  Rise := Sin (Pi * S.Feet (Sd).T);
                  Stance := Other (Sd);
               end if;
            end if;
         end loop;
         if not Swinging then
            --  the next step: the other foot, unless only this one is out of place
            declare
               Th   : constant Float := (if Walking then 0.06 else 0.09);
               Next : constant Side := Other (S.Last);
               Err  : array (Side) of Float;
               Go   : Side;
               Any  : Boolean := False;
            begin
               for Sd in Side loop
                  Err (Sd) := Len (Flat (Desired (Sd) - S.Feet (Sd).Pos))
                    + 2.0 * abs (Desired (Sd).Z - S.Feet (Sd).Pos.Z);
               end loop;
               if Err (Next) > Th then
                  Go := Next;
                  Any := True;
               elsif Err (S.Last) > Th then
                  Go := S.Last;
                  Any := True;
               end if;
               if Any then
                  declare
                     F : Foot_State renames S.Feet (Go);
                  begin
                     F.From := F.Pos;
                     F.From_Head := F.Head;
                     F.To := Desired (Go);
                     F.To_Head := H;
                     F.T := 0.0;
                     F.Dur := (if Walking then Step_T else 0.35);
                     F.Base := F.Pos.Z;
                  end;
               end if;
            end;
         end if;

         --  4. the pelvis rides on the feet: lowest with both down, highest
         --  as the free foot passes, over the standing foot, and never so
         --  high a leg can't reach the ground
         declare
            Hip_Want : Float :=
              (S.Feet (Left).Base + S.Feet (Right).Base) / 2.0 - R.Ankle + R.Hip
              - (if Walking then 0.025 - 0.02 * Rise else 0.004 * (1.0 + Sin (2.0 * Pi * 0.22 * S.Clock)));
            Reach_Z : Float := Float'Last;
            Sway_Want : Float;
         begin
            for Sd in Side loop
               declare
                  Hip_At : constant Vec3 := Root + Rt * (Out_Of (Sd) * R.Hip_Half);
                  Hd : constant Float := Len (Flat (S.Feet (Sd).Pos - Hip_At));
                  L  : constant Float := R.Thigh + R.Shin - 0.01;
               begin
                  Reach_Z := Float'Min (Reach_Z, S.Feet (Sd).Pos.Z + Sqrt (Float'Max (0.0, L * L - Hd * Hd)));
               end;
            end loop;
            Hip_Want := Float'Min (Hip_Want, Reach_Z)
              - W * (case S.Work is when Put_Down => 0.3, when Chop => 0.06, when Aim => 0.03, when Eat => 0.02,
                                    when Stir => 0.05, when Sit_Eat => 0.0, when others => 0.16)
              - (if S.Motion = Sneak then 0.12 else 0.0);   --  crouching to the work, or creeping
            if S.Work = Sit_Eat then                       --  down onto the seat
               Hip_Want := Hip_Want + W * (S.Ground + Seat_Hip - Hip_Want);
               Reach_Z := Float'Max (Reach_Z, S.Ground + Seat_Hip);
            end if;
            S1.Update (S.Hip_Z, Dt, Hip_Want);
            if Walking or else Swinging then
               Sway_Want := (if Swinging then Out_Of (Stance) * 0.03 * Rise else 0.0);
            else
               if S.Clock > S.Next_Shift then        --  standing: shift the weight now and then
                  S.Shift := (if S.Shift > 0.0 then -1.0 else 1.0) * (0.5 + 0.5 * Hash01 (S, 5, Integer (S.Clock)));
                  S.Next_Shift := S.Clock + 2.5 + 4.0 * Hash01 (S, 6, Integer (S.Clock));
               end if;
               Sway_Want := 0.022 * S.Shift;
            end if;
            S1.Update (S.Sway, Dt, Sway_Want);
            --  lean into the walk, more going uphill, back a little going down
            declare
               Ahead : constant Vec3 := Root + Fw * 0.6;
               Slope : constant Float :=
                 (if Walking then Clamp ((Ground_At (Ahead.X, Ahead.Y, S.Ground) - S.Ground) / 0.6, -1.0, 1.0)
                  else 0.0);
            begin
               S1.Update (S.Lean, Dt, (if Walking then 0.03 + 0.05 * Spd + 0.18 * Slope else 0.0)
                                      + (if S.G.Age > 60.0 then 0.08 else 0.0)
                                      + W * (case S.Work is when Put_Down => 0.5, when Chop => 0.1,
                                                              when Aim => 0.02, when Eat => 0.06, when Stir => 0.18,
                                                              when Sit_Eat => 0.12, when others => 0.3)
                                      + (if S.Motion = Sneak then 0.28 else 0.0));
            end;
            S.P.Pelvis := (Root.X, Root.Y, Float'Min (S1.Value (S.Hip_Z), Reach_Z))
              + Rt * S1.Value (S.Sway);
            S.P.Tilt := -1.4 * S1.Value (S.Sway);
         end;

         S.P.Heading := H;
         S.P.Lean := S1.Value (S.Lean);
         S.P.Bend := 0.012 * Sin (2.0 * Pi * 0.22 * S.Clock) + (if S.G.Age > 60.0 then 0.12 else 0.0)
           + 0.2 * W;

         --  5. the arms swing against the legs and lag behind them
         declare
            Stride : constant Float := Float'Max (0.3, Spd * Step_T);
            Gain   : constant Float := (if S.Buckets then 0.1 else 0.35) * Float'Min (1.0, Spd / 1.2);
            --  standing at rest, on the reference body: the elbows out from the sides and the arms bent a
            --  little more (Rest_Arms), gone as it walks or works
            Rest_W : constant Float :=
              (if Rest_Arms and then Castle.Bodies.Reference_Body
               then (1.0 - Float'Min (1.0, Spd / 0.6)) * (1.0 - W) else 0.0);
         begin
            for Sd in Side loop
               declare
                  Ahead : constant Float := Dot (S.Feet (Other (Sd)).Pos - S.Feet (Sd).Pos, Fw) / Stride;
               begin
                  S1.Update (S.Arms (Sd), Dt, Gain * Clamp (Ahead, -1.0, 1.0));
                  S.P.Swing (Sd) := S1.Value (S.Arms (Sd));
                  S.P.Elbow (Sd) := 0.18 + (if Walking then 0.12 else 0.0)
                    + 0.35 * Float'Max (0.0, S.P.Swing (Sd)) + Rest_Elbow * Rest_W;
                  S.P.Spread (Sd) := 0.05 + 0.03 * Float'Max (0.0, S.G.Build) + (if S.Buckets then 0.14 else 0.0)
                    + Rest_Spread * Rest_W;
                  S.P.Fore_In (Sd) := Rest_Fore_In * Rest_W;
               end;
            end loop;
            S.P.Twist := -0.25 * (S1.Value (S.Arms (Left)) - S1.Value (S.Arms (Right))) * 0.5;
            --  at work the hands go to the spot: picking, into the bush in turn,
            --  each on a small circle; putting down, both to just over it;
            --  chopping, both on the haft, wound up over the dominant shoulder
            --  and swung down into the trunk.  Weighed from where they hang by
            --  W, so they reach out and back.  A log on the shoulder is held
            --  there by the off hand while the work leaves it free.
            S1.Update (S.Log_W, Dt, (if S.Log then 1.0 else 0.0));
            declare
               LW   : constant Float := Clamp (S1.Value (S.Log_W), 0.0, 1.0) * (1.0 - W);
               Dom  : constant Side := S.G.Hand;
               Off  : constant Side := Other (Dom);
               Up   : constant Vec3 := (0.0, 0.0, 1.0);
               --  the chop: a wind-up, a quick swing, the bit held in the wood
               Ph   : constant Float := S.Clock / 1.4 - Float'Floor (S.Clock / 1.4);
               Reach_Out : constant Float :=
                 Clamp (Len (Flat (S.Spot - S.P.Pelvis)) - 0.48, 0.22, 0.45);
               Hit  : constant Vec3 := S.P.Pelvis + Fw * Reach_Out + Rt * (Out_Of (Dom) * 0.04) + Up * 0.3;
               Wound : constant Vec3 := S.P.Pelvis + Rt * (Out_Of (Dom) * 0.2) - Fw * 0.02
                                        + Up * (0.4 * R.Height);
               Chop_T : constant Float :=
                 (if Ph < 0.55 then 1.0 - Smooth (Ph / 0.55)
                  elsif Ph < 0.68 then ((Ph - 0.55) / 0.13) ** 2
                  else 1.0 - 0.06 * Sin (Pi * (Ph - 0.68) / 0.32));
               Axe_Hand : constant Vec3 := Wound + (Hit - Wound) * Chop_T;   --  1: at the trunk
               Shoulder_Mid : constant Vec3 := S.P.Pelvis + Up * (0.3 * R.Height);
               Up_Haft : constant Vec3 := Axe_Hand - Shoulder_Mid;
               --  eating, the hands before the chest (Hands_Before_Chest): in the chest's own frame,
               --  metres from its joint at the waist (X the body's right, Y forward, Z up the trunk)
               Chest_F   : constant Frame := Chest_Frame (R, S.P);
               Chest_Top : constant Float := (R.Boxes (2).Lo.Z + R.Boxes (2).Size.Z) * Px;   --  the shoulders' height
               Mouth_Z   : constant Float := R.Joint (Head).Z - 0.02 * Chest_Top;      --  the hand at the mouth
               Chest_Fr  : constant Float := 0.5 * R.Boxes (2).Size.Y * Px;    --  the chest's front
               Bite      : constant Float := Smooth (0.5 + 0.5 * Sin (2.0 * Pi * 0.45 * S.Clock));
               function Before_Chest (X, Y, Z : Float) return Vec3 is
                 (Chest_F.O + Chest_F.X * X + Chest_F.Y * Y + Chest_F.Z * Z);
            begin
               for Sd in Side loop
                  declare
                     Rest : constant Vec3 := S.P.Pelvis + Rt * (Out_Of (Sd) * (R.Hip_Half + 0.14)) + Fw * 0.03
                                             - (0.0, 0.0, 0.06);
                     Ph2  : constant Float := (if Sd = Left then 0.0 else Pi);
                     A    : constant Float := 2.0 * Pi * 0.8 * S.Clock + Ph2;
                     Goal : constant Vec3 :=
                       (case S.Work is
                           when Pick =>
                              S.Spot - (0.0, 0.0, S.Up) + Rt * (Out_Of (Sd) * 0.09) - Fw * 0.04 + Fw * (0.05 * Sin (A))
                              + (0.0, 0.0, 0.05 * Cos (A)),
                           when Chop =>
                             (if Sd = Dom then Axe_Hand
                              else Axe_Hand + Up_Haft * (0.1 / Float'Max (0.05, Len (Up_Haft)))),
                           --  the bow out in front in the off hand, the arm all but straight,
                           --  the string drawn level to the cheek
                           when Aim =>
                             (if Sd = Dom then S.P.Pelvis + Up * (0.4 * R.Height) + Fw * 0.03 + Rt * (Out_Of (Dom) * 0.07)
                              else S.P.Pelvis + Up * (0.385 * R.Height) + Fw * 0.46 + Rt * (Out_Of (Off) * 0.03)),
                           --  the dominant hand round in the pot, the other at its rim
                           when Stir =>
                             (if Sd = Dom then
                                S.Spot + (0.08 * Cos (2.0 * Pi * 0.5 * S.Clock), 0.08 * Sin (2.0 * Pi * 0.5 * S.Clock),
                                          0.2)
                              else S.Spot + Rt * (Out_Of (Off) * 0.2) - Fw * 0.05 + Up * 0.12),
                           --  food at the chest in the off hand, the other hand to the mouth and back
                           when Eat | Sit_Eat =>
                             (if Hands_Before_Chest then
                                (if Sd = Dom then
                                   --  from the food, held at the chest, up to the mouth and back
                                   Before_Chest (Out_Of (Dom) * (0.06 - 0.03 * Bite),
                                                 Chest_Fr + 0.14 - 0.02 * Bite,
                                                 0.55 * Chest_Top + Bite * (Mouth_Z - 0.55 * Chest_Top))
                                 else Before_Chest (Out_Of (Off) * 0.05, Chest_Fr + 0.13, 0.5 * Chest_Top))
                              elsif Sd = Dom then
                                S.P.Pelvis + Up * (0.27 * R.Height) + Fw * 0.2
                                + (Up * (0.13 * R.Height) - Fw * 0.08)
                                  * Smooth (0.5 + 0.5 * Sin (2.0 * Pi * 0.45 * S.Clock))
                                + Rt * (Out_Of (Dom) * 0.03)
                              else S.P.Pelvis + Up * (0.26 * R.Height) + Fw * 0.2 + Rt * (Out_Of (Off) * 0.04)),
                           when others => S.Spot - (0.0, 0.0, S.Up) + Rt * (Out_Of (Sd) * 0.1) + (0.0, 0.0, 0.12));
                     Steady : constant Vec3 :=
                       S.P.Pelvis + Rt * (Out_Of (Off) * (R.Hip_Half + 0.06)) + Fw * 0.12
                       + Up * (0.36 * R.Height);
                  begin
                     S.P.Elbows (Sd) := (if Hands_Before_Chest and then S.Work in Eat | Sit_Eat then W else 0.0);
                     if W > 0.02 then
                        S.P.Reach (Sd) := True;
                        S.P.Hand (Sd) := Rest + (Goal - Rest) * W;
                     elsif Sd = Off and then LW > 0.02 then
                        S.P.Reach (Sd) := True;
                        S.P.Hand (Sd) := Rest + (Steady - Rest) * LW;
                     else
                        S.P.Reach (Sd) := False;
                     end if;
                  end;
               end loop;
               --  aiming, the bow (in the off hand) is turned upright across the
               --  arm held out, not left pointing along it
               S.P.Grip := [others => 0.0];
               if S.Work = Aim then
                  S.P.Grip (Off) := W;
               end if;
            end;
         end;

         --  6. the head: into turns when walking; standing, a look around now
         --  and then, sometimes at whoever is watching
         declare
            Yaw, Pitch : Float;
         begin
            if S.Clock > S.Next_Glance then
               declare
                  K : constant Integer := Integer (S.Clock * 10.0);
               begin
                  if Hash01 (S, 7, K) < 0.3 then
                     declare
                        To_Eye : constant Float := Heading_Of (Eye - Root, H);
                     begin
                        S.Glance := (Clamp (Unwrap (To_Eye, H) - H, -1.0, 1.0), -0.25, 0.0);
                     end;
                  else
                     S.Glance := (1.4 * (Hash01 (S, 8, K) - 0.5), 0.35 * Hash01 (S, 9, K) - 0.12, 0.0);
                  end if;
                  S.Next_Glance := S.Clock + 1.5 + 3.0 * Hash01 (S, 10, K);
               end;
            end if;
            if Walking then
               Yaw := Clamp (0.8 * (Unwrap (Want_H, H) - H), -0.6, 0.6) + 0.3 * S.Glance.X;
               Pitch := 0.12;
            else
               Yaw := S.Glance.X;
               Pitch := S.Glance.Y;
            end if;
            if S.G.Age > 60.0 then
               Pitch := Pitch - 0.1;             --  a stooped back looks up to see ahead
            end if;
            Yaw := Yaw * (1.0 - W);
            Pitch := Pitch + W * (0.45 - Pitch);   --  at work, eyes on it
            S3.Update (S.Gaze, Dt, (Yaw, Pitch, 0.0));
            S.P.Look_Yaw := Clamp (S3.Value (S.Gaze).X, -1.1, 1.1);
            S.P.Look_Pitch := Clamp (S3.Value (S.Gaze).Y, -0.5, 0.6);
         end;

         for Sd in Side loop
            S.P.Foot (Sd) := S.Feet (Sd).Pos;
            S.P.Foot_Heading (Sd) := S.Feet (Sd).Head;
         end loop;
      end;
   end Animate;

   function Spawn_Driven (G : Genome; O : Outfit; Where : Vec3; Facing : Float) return Natural is
      Before : constant Natural := N_Serfs;
   begin
      Spawn (G, O, Where, Facing, False, Where, 1.3);
      if N_Serfs = Before then
         return 0;
      end if;
      Serfs (N_Serfs).Driven := True;
      return N_Serfs;
   end Spawn_Driven;

   procedure Turn_About (I : Positive; Pivot : Vec3; Radians : Float) is
   begin
      if I <= N_Serfs then
         Serfs (I).Turn_Want := Radians;
         if Radians /= 0.0 then
            if Serfs (I).Turn_A = 0.0 then
               Serfs (I).Turn_P := Pivot;          --  (into a turn: about its point)
            elsif Serfs (I).Turn_P /= Pivot then
               Serfs (I).Turn_P := Pivot;          --  (from one turned house straight into another: at once)
               Serfs (I).Turn_A := Radians;
            end if;
         end if;
      end if;
   end Turn_About;

   --  A point and a way of serf S's, as it is drawn (Turn_About).
   function Turned_Way (S : Serf; V : Vec3) return Vec3 is
     (if S.Turn_S = 0.0 then V else (S.Turn_C * V.X - S.Turn_S * V.Y, S.Turn_S * V.X + S.Turn_C * V.Y, V.Z));
   function Turned (S : Serf; P : Vec3) return Vec3 is
     (if S.Turn_S = 0.0 then P
      else (S.Turn_P.X, S.Turn_P.Y, 0.0) + Turned_Way (S, (P.X - S.Turn_P.X, P.Y - S.Turn_P.Y, P.Z)));

   procedure Perch (I : Positive; Up : Float) is
   begin
      if I <= N_Serfs then
         Serfs (I).Up_Want := Float'Max (0.0, Up);
      end if;
   end Perch;

   procedure Drive (I : Positive; Where : Vec3; M : Motion_Kind; Spot : Vec3; Log : Boolean := False;
                    Buckets : Boolean := False) is
   begin
      if I <= N_Serfs then
         Serfs (I).Driven := True;       --  (a serf of a lineup put to work: --lineup-does)
         Serfs (I).Target := Where;
         Serfs (I).Motion := M;
         Serfs (I).Spot := Spot;
         Serfs (I).Log := Log;
         Serfs (I).Buckets := Buckets;
      end if;
   end Drive;

   function Hand_At (I : Positive; S : Side) return Vec3 is
      F : Frames;
   begin
      if I > N_Serfs then
         return (0.0, 0.0, 0.0);
      end if;
      Solve (Serfs (I).R, Serfs (I).P, F);
      return Turned (Serfs (I), F (if S = Left then Hand_L else Hand_R).O);
   end Hand_At;

   function Log_Rest (I : Positive) return Vec3 is
      F : Frames;
   begin
      if I > N_Serfs then
         return (0.0, 0.0, 0.0);
      end if;
      declare
         S   : Serf renames Serfs (I);
         Off : constant Side := Other (S.G.Hand);
         Arm : constant Bone := (if Off = Left then Upper_Arm_L else Upper_Arm_R);
      begin
         Solve (S.R, S.P, F);
         --  on top of the shoulder, out from the head
         return Turned (S, F (Arm).O + F (Chest).X * (0.06 * (if Off = Left then -1.0 else 1.0)) + F (Chest).Z * 0.07);
      end;
   end Log_Rest;

   function Heading (I : Positive) return Float is
     (if I > N_Serfs then 0.0
      elsif Serfs (I).Turn_S = 0.0 then Serfs (I).P.Heading
      else Serfs (I).P.Heading + Arctan (Serfs (I).Turn_S, Serfs (I).Turn_C));

   function Shoulders_Top (I : Positive) return Vec3 is
      F : Frames;
   begin
      if I > N_Serfs then
         return (0.0, 0.0, 0.0);
      end if;
      Solve (Serfs (I).R, Serfs (I).P, F);
      return Turned (Serfs (I), (F (Upper_Arm_L).O + F (Upper_Arm_R).O) * 0.5 + F (Chest).Z * 0.06 - F (Chest).Y * 0.04);
   end Shoulders_Top;

   procedure Restyle (I : Positive; O : Outfit) is
      Skin : Skin_Pixels;
   begin
      if I <= N_Serfs then
         declare
            S : Serf renames Serfs (I);
         begin
            S.O := O;
            Castle.Figures.Free_Look (S.Slot);
            if S.Vox > 0 then
               Castle.Figures.Free_Voxel_Look (S.Vox);
            end if;
            Build (S.G, O, S.R, Skin);
            S.Slot := Castle.Figures.New_Look (S.R, Skin);
            S.Vox := Voxel_Look_Of (S.R, Skin);
         end;
      end if;
   end Restyle;

   procedure Clear is
   begin
      for I in 1 .. N_Serfs loop
         if Serfs (I).Used then
            Castle.Figures.Free_Look (Serfs (I).Slot);
            if Serfs (I).Vox > 0 then
               Castle.Figures.Free_Voxel_Look (Serfs (I).Vox);
            end if;
            Serfs (I).Used := False;
         end if;
      end loop;
      N_Serfs := 0;
   end Clear;

   procedure Update (Dt : Float; Eye : Vec3) is
   begin
      if Dt <= 0.0 then
         return;
      end if;
      for I in 1 .. N_Serfs loop
         if Serfs (I).Used then
            Animate (Serfs (I), Float'Min (Dt, 0.25), Eye);
         end if;
      end loop;
   end Update;

   --  Asleep it lies on its side, a little curled up (John, 2026-11-12:
   --  "have serfs sleep on their side"): which side is its own, from its seed.
   --  (told to face something as it sleeps, it lies on the side that turns
   --  its belly that way: lying back from the way it faced, on its right
   --  side its belly is to what was its right)
   function Lies_On (S : Serf) return Side is
      H : constant Float := S1.Value (S.Heading);
      R : constant Vec3 := S3.Value (S.Root);
   begin
      if S.Faces then
         return (if Sin (H) * (S.Faces_P.X - R.X) - Cos (H) * (S.Faces_P.Y - R.Y) > 0.0 then Right else Left);
      end if;
      return (if Hash01 (S, 11, 0) < 0.5 then Left else Right);
   end Lies_On;

   procedure Lie_Facing (I : Positive; On : Boolean; P : Vec3 := (0.0, 0.0, 0.0)) is
   begin
      if I <= N_Serfs then
         Serfs (I).Faces := On;
         Serfs (I).Faces_P := P;
      end if;
   end Lie_Facing;

   --  The pose it is drawn in: as animated; asleep (Side_W), with its legs
   --  drawn up (the upper one further), its arms folded before its chest,
   --  its back and its neck a little bent.
   function Posed (S : Serf) return Pose is
      W : constant Float := Clamp (S1.Value (S.Side_W), 0.0, 1.0);
      P : Pose := S.P;
   begin
      if W < 0.01 then
         return P;
      end if;
      declare
         Fw : constant Vec3 := (Cos (P.Heading), Sin (P.Heading), 0.0);
      begin
         for Sd in Side loop
            declare
               Upper : constant Boolean := Sd /= Lies_On (S);
            begin
               P.Foot (Sd) := P.Foot (Sd)
                 + (Fw * (if Upper then 0.32 else 0.22) + (0.0, 0.0, (if Upper then 0.25 else 0.14))) * W;
               P.Reach (Sd) := P.Reach (Sd) and then W < 0.5;
               --  (the upper arm across its chest, the hand down before it: it lies under its cloak)
               P.Swing (Sd) := P.Swing (Sd) + ((if Upper then 0.45 else 0.6) - P.Swing (Sd)) * W;
               P.Elbow (Sd) := P.Elbow (Sd) + ((if Upper then 1.4 else 2.1) - P.Elbow (Sd)) * W;
               P.Spread (Sd) := P.Spread (Sd) + ((if Upper then -0.55 else 0.04) - P.Spread (Sd)) * W;
            end;
         end loop;
         P.Bend := P.Bend + (0.2 - P.Bend) * W;
         P.Look_Pitch := P.Look_Pitch + (0.25 - P.Look_Pitch) * W;
         P.Look_Yaw := P.Look_Yaw * (1.0 - W);
         P.Twist := P.Twist * (1.0 - W);
      end;
      return P;
   end Posed;

   --  Lying down (Lie_W): the whole body tipped back about a line on the
   --  ground behind its heels, so that it ends on its back, its head where
   --  the way it faced was behind it; and asleep (Side_W) rolled onto its
   --  side as it goes down, that shoulder and hip on the ground.
   procedure Lay_Down (S : Serf; F : in out Frames) is
      W : constant Float := Float'Min (1.0, Float'Max (0.0, S1.Value (S.Lie_W)));
   begin
      if W < 0.01 then
         return;
      end if;
      declare
         H     : constant Float := S1.Value (S.Heading);
         Fw    : constant Vec3 := (Cos (H), Sin (H), 0.0);
         Rt    : constant Vec3 := (Sin (H), -Cos (H), 0.0);
         Root  : constant Vec3 := S3.Value (S.Root);
         Pivot : constant Vec3 := (Root.X, Root.Y, S.Ground + 0.03) - Fw * 0.15;
         A     : constant Float := W * Pi / 2.0;
         --  the roll: about the line of its spine as it lies (0.15 m over
         --  the pivot's ground), toward the side it sleeps on; and up, so
         --  that the lower shoulder rests on the ground
         Spine : constant Vec3 := Pivot + (0.0, 0.0, 0.15);
         Along_It : constant Vec3 := Fw * (-1.0);
         Ws    : constant Float := Float'Min (W, Clamp (S1.Value (S.Side_W), 0.0, 1.0));
         Roll  : constant Float := (if Lies_On (S) = Right then -1.0 else 1.0) * Ws * Pi / 2.0;
         Half  : constant Float := abs S.R.Joint (Upper_Arm_L).X + 0.05;       --  half its width at the shoulders
         Lift  : constant Vec3 := (0.0, 0.0, Ws * Float'Max (0.0, Half - 0.16));
      begin
         for B in F'Range loop
            F (B) := (X => Rotate (F (B).X, Rt, A), Y => Rotate (F (B).Y, Rt, A), Z => Rotate (F (B).Z, Rt, A),
                      O => Pivot + Rotate (F (B).O - Pivot, Rt, A));
            F (B) := (X => Rotate (F (B).X, Along_It, Roll), Y => Rotate (F (B).Y, Along_It, Roll),
                      Z => Rotate (F (B).Z, Along_It, Roll),
                      O => Spine + Rotate (F (B).O - Spine, Along_It, Roll) + Lift);
         end loop;
      end;
   end Lay_Down;

   function Cloak_Of (I : Positive) return RGB is
     (if I <= N_Serfs then Serfs (I).R.Cloak else (0.3, 0.3, 0.3));
   function Height_Of (I : Positive) return Float is (if I <= N_Serfs then Serfs (I).R.Height else 1.7);

   function Lies (I : Positive) return Float is
     (if I <= N_Serfs then Clamp (S1.Value (Serfs (I).Lie_W), 0.0, 1.0) else 0.0);

   procedure Lying_Frame (I : Positive; Hips, Along, Belly : out Vec3) is
      F : Frames;
   begin
      Hips := (0.0, 0.0, 0.0);
      Along := (1.0, 0.0, 0.0);
      Belly := (0.0, 1.0, 0.0);
      if I > N_Serfs then
         return;
      end if;
      declare
         S  : Serf renames Serfs (I);
         H  : constant Float := S1.Value (S.Heading);
         Up : Vec3;
         Fy : Vec3;
      begin
         Solve (S.R, Posed (S), F);
         Lay_Down (S, F);
         Hips := (F (Pelvis).O.X, F (Pelvis).O.Y, S.Ground);
         Up := Flat (F (Chest).O - F (Pelvis).O);
         Along := (if Len (Up) > 0.02 then Up * (1.0 / Len (Up)) else (-Cos (H), -Sin (H), 0.0));
         --  (its belly's way, square to the way it lies)
         Fy := Flat (F (Chest).Y);
         Fy := Fy - Along * Dot (Fy, Along);
         Belly := (if Len (Fy) > 0.05 then Fy * (1.0 / Len (Fy)) else (-Along.Y, Along.X, 0.0));
         Hips := Turned (S, Hips);
         Along := Turned_Way (S, Along);
         Belly := Turned_Way (S, Belly);
      end;
   end Lying_Frame;

   --  A frame T of the way from A to B (eased), its axes kept square.
   function Between (A, B : Frame; T : Float) return Frame is
      U  : constant Float := Smooth (Clamp (T, 0.0, 1.0));
      Z  : constant Vec3 := Normalize (A.Z + (B.Z - A.Z) * U);
      Y0 : constant Vec3 := A.Y + (B.Y - A.Y) * U;
      Y1 : constant Vec3 := Y0 - Z * Dot (Y0, Z);
      Y  : constant Vec3 := (if Dot (Y1, Y1) > 1.0E-6 then Normalize (Y1) else Normalize (Cross (Z, A.X)));
   begin
      return (X => Cross (Y, Z), Y => Y, Z => Z, O => A.O + (B.O - A.O) * U);
   end Between;

   Hand_Bone : constant array (Side) of Bone := [Left => Hand_L, Right => Hand_R];
   Fore_Bone : constant array (Side) of Bone := [Left => Forearm_L, Right => Forearm_R];

   --  The tool of its job, from the body's frames F as they are drawn (see
   --  the spec).  Stowed, the axe hangs head up behind the hip of the
   --  dominant side, its bit flat to the body and turned inward, its haft
   --  down and a little out; the bow lies flat across the back, its upper
   --  limb over the off shoulder.  In the hands, the axe's haft runs from
   --  the dominant hand through the other, its bit leading the stroke; the
   --  bow is in the off hand, carried level while stalking and stood
   --  upright to shoot, its string drawn to the other hand with an arrow
   --  on it.
   procedure Show_Tool (S : Serf; F : Frames) is
      T    : constant Float := Clamp (S1.Value (S.Tool_W), 0.0, 1.0);
      Dom  : constant Side := S.G.Hand;
      Off  : constant Side := Other (Dom);
      Sd   : constant Float := Out_Of (Dom);
      Hips : Box renames S.R.Boxes (1);
      Ribs : Box renames S.R.Boxes (2);
      Out_Px : constant Float := (if S.O.Winter then Cloak_Px else 0.0);
      H    : constant Float := S.P.Heading;
      Fw   : constant Vec3 := (Cos (H), Sin (H), 0.0);
      Rt   : constant Vec3 := (Sin (H), -Cos (H), 0.0);
      Up   : constant Vec3 := (0.0, 0.0, 1.0);
      function Palm (Sd : Side) return Vec3 is (F (Hand_Bone (Sd)).O - F (Hand_Bone (Sd)).Z * Px);
   begin
      if S.G.Age < 15.0 then
         return;
      end if;
      case S.O.Job is
         when Forester =>
            declare
               P    : Frame renames F (Pelvis);
               Zs   : constant Vec3 := Normalize (P.Z - P.X * (Sd * 0.2) + P.Y * 0.1);
               Ys0  : constant Vec3 := P.X * (-Sd);
               Ys   : constant Vec3 := Normalize (Ys0 - Zs * Dot (Ys0, Zs));
               Head : constant Vec3 :=
                 Place (P, (Sd * (0.5 * Hips.Size.X - 1.2), Hips.Lo.Y - 1.0 - Out_Px, Hips.Lo.Z + Hips.Size.Z - 1.0));
               Stow : constant Frame :=
                 (X => Cross (Ys, Zs), Y => Ys, Z => Zs, O => Head - Zs * Castle.Props.Axe_Head_M);
            begin
               if T < 0.01 then
                  Castle.Props.Put_In (Castle.Props.Axe, Stow);
               else
                  declare
                     A   : constant Vec3 := Palm (Dom);
                     D   : constant Vec3 := Palm (Off) - A;
                     Zh  : constant Vec3 := (if Len (D) > 0.03 then D * (1.0 / Len (D)) else F (Fore_Bone (Dom)).Z * (-1.0));
                     Yh0 : constant Vec3 := Fw * 0.5 - Up;
                     Yh1 : constant Vec3 := Yh0 - Zh * Dot (Yh0, Zh);
                     Yh  : constant Vec3 := (if Dot (Yh1, Yh1) > 1.0E-6 then Normalize (Yh1) else Fw);
                     In_Hand : constant Frame := (X => Cross (Yh, Zh), Y => Yh, Z => Zh, O => A - Zh * 0.05);
                  begin
                     Castle.Props.Put_In (Castle.Props.Axe, Between (Stow, In_Hand, T));
                  end;
               end if;
            end;
         when Hunter =>
            declare
               C    : Frame renames F (Chest);
               Zs   : constant Vec3 := Normalize (C.Z * 0.82 - C.X * (Sd * 0.57));
               Xs   : constant Vec3 := C.Y * (-1.0);
               Ys   : constant Vec3 := Cross (Zs, Xs);
               Mid  : constant Vec3 := Place (C, (0.0, Ribs.Lo.Y - 0.9 - Out_Px, Ribs.Lo.Z + 0.5 * Ribs.Size.Z));
               Slung : constant Frame :=
                 (X => Xs, Y => Ys, Z => Zs, O => Mid + Ys * (0.5 * Castle.Props.Bow_Brace_M));
               --  with a load across the shoulders (a deer brought home) it is
               --  let down level across the small of the back, under the load
               Zl   : constant Vec3 := C.X * (-Sd);
               Yl   : constant Vec3 := Cross (Zl, Xs);
               Low  : constant Frame :=
                 (X => Xs, Y => Yl, Z => Zl,
                  O => Place (C, (0.0, Ribs.Lo.Y - 0.9 - Out_Px, Ribs.Lo.Z + 0.15 * Ribs.Size.Z))
                       + Yl * (0.5 * Castle.Props.Bow_Brace_M));
               Stow : constant Frame := Between (Slung, Low, S1.Value (S.Log_W));
               --  the quiver: on the belt behind the hip of the drawing hand,
               --  leaning out to that side, the arrows' ends up by the elbow
               --  (seated, it is swung up along the belt, clear of the seat)
               P    : Frame renames F (Pelvis);
               Sat  : constant Float :=
                 (if S.Work = Sit_Eat then Smooth (Clamp (S1.Value (S.Work_W), 0.0, 1.0)) else 0.0);
               Tilt : constant Float := Quiver_Tilt + (Quiver_Sat - Quiver_Tilt) * Sat;
               Zq   : constant Vec3 := Normalize (P.Z * Cos (Tilt) + P.X * (Sd * Sin (Tilt)) - P.Y * 0.12);
               Yq   : constant Vec3 := Normalize (P.Y - Zq * Dot (P.Y, Zq));
               Mouth : constant Vec3 :=
                 Place (P, (Sd * (0.5 * Hips.Size.X - 0.2), Hips.Lo.Y - 1.4 - Out_Px, Hips.Lo.Z + Hips.Size.Z + 0.6));
            begin
               Castle.Props.Put_In
                 (Castle.Props.Quiver,
                  (X => Cross (Yq, Zq), Y => Yq, Z => Zq, O => Mouth - Zq * Castle.Props.Quiver_Mouth_M));
               if T < 0.01 then
                  Castle.Props.Put_Bow (Stow);
               else
                  declare
                     Aim_W : constant Float :=
                       (if S.Work = Aim then Smooth (Clamp (S1.Value (S.Work_W), 0.0, 1.0)) else 0.0);
                     Th    : constant Float := 0.35 + (0.5 * Pi - 0.35) * Aim_W;   --  level at the side, upright to shoot
                     In_Hand : constant Frame :=
                       (X => Rt, Y => Fw * Sin (Th) - Up * Cos (Th), Z => Fw * Cos (Th) + Up * Sin (Th), O => Palm (Off));
                     G     : constant Frame := Between (Stow, In_Hand, T);
                     Draw  : constant Float :=
                       (if S.Motion = Aim then T * Smooth (Clamp ((Aim_W - 0.4) / 0.55, 0.0, 1.0)) else 0.0);
                  begin
                     if Draw > 0.01 then
                        declare
                           Rest : constant Vec3 := Castle.Props.Bow_Rest (G);
                           Nock : constant Vec3 := Rest + (Palm (Dom) - Rest) * Draw;
                           Dir  : constant Vec3 := Normalize (G.O - Nock);
                           Ax0  : constant Vec3 := Rt - Dir * Dot (Rt, Dir);
                           Ax   : constant Vec3 := Normalize (Ax0);
                        begin
                           Castle.Props.Put_Bow (G, Held => True, Nock => Nock);
                           if Draw > 0.3 then          --  the arrow on the string, its point past the grip
                              Castle.Props.Put_In (Castle.Props.Arrow,
                                                   (X => Ax, Y => Cross (Dir * (-1.0), Ax), Z => Dir * (-1.0), O => Nock));
                           end if;
                        end;
                     else
                        Castle.Props.Put_Bow (G);
                     end if;
                  end;
               end if;
            end;
         when others =>
            null;
      end case;
   end Show_Tool;

   procedure Submit is
      F : Frames;
   begin
      Castle.Figures.Begin_Frame;
      for I in 1 .. N_Serfs loop
         declare
            S : Serf renames Serfs (I);
         begin
            if S.Used then
               Solve (S.R, Posed (S), F);
               Lay_Down (S, F);
               if S.Up > 0.005 then                --  (on its ladder: all of it that much higher)
                  for B in Bone loop
                     F (B).O := F (B).O + (0.0, 0.0, S.Up);
                  end loop;
               end if;
               S.Last_Home := F;
               if S.Turn_S /= 0.0 then             --  (within a building drawn turned: all of it through that turn)
                  for B in Bone loop
                     F (B) := (X => Turned_Way (S, F (B).X), Y => Turned_Way (S, F (B).Y), Z => Turned_Way (S, F (B).Z),
                               O => Turned (S, F (B).O));
                  end loop;
               end if;
               if S.Vox > 0 then
                  Castle.Figures.Add_Voxel (S.Vox, F);
               else
                  Castle.Figures.Add (S.Slot, F);
               end if;
               S.Last_F := F;
               Show_Tool (S, F);
               declare
                  Root : constant Vec3 := S3.Value (S.Root);
               begin
                  Castle.Figures.Add_Shadow (Turned (S, (Root.X, Root.Y, S.Ground)), 0.14 * S.R.Height + 0.05);
               end;
            end if;
         end;
      end loop;
   end Submit;

end Castle.Serfs;
