--  The colony on the real world with no window: the generated world is
--  streamed in round the homestake as the game streams it, and the colony
--  steps on its fixed clock as fast as the machine goes.  Nothing is drawn
--  and nothing waits on real time, so the same command line gives the same
--  run to the last unit, on any machine and with any number of workers: the
--  last line is a hash of the colony's save blob to prove it.  For phase
--  gates, measurements and the reference run.
--
--    colony_run [--seed N] [--day D] [--time HOUR] --days N
--               [--log-hours H] [--workers N] [--load FILE] [--save FILE]
--               and the colony's own options (Castle.Scenario): --stake X Y,
--               --path, --stockpile, --camp, --gatherers N ..., --supply ...
--
--  --expect HASH makes the run a test: it exits 1 unless the final state
--  hash starts with HASH.
--  --days N runs N game days (fractions allowed) from --day D (20) at
--  --time HOUR (15), or from where --load FILE left off.  --save FILE
--  writes a save the game opens (--load FILE there).
--
--  Not the game's: live water does not move here (ponds and rivers rest as
--  generated), and stacks are rebuilt after edits every Rebuild_S colony
--  seconds, all at once, where the game rebuilds them as workers come free.
--  So a run here and the same start in the game agree in kind, not to the
--  unit.
--
--  Measuring what the ground costs to keep (2026-11-14):
--  --ground-stacks N brings in the ground within N stacks of the stake
--  (8 m each; 400 is the whole map) in place of the colony's own reach, in
--  batches.  The colony is told its own ground all the same (the stacks
--  within its reach and five more of the stake's: Set_Ground_Stacks) and
--  reads nothing beyond it, so a run with the whole map in ends in the very
--  state of a run on the colony's own ground (tools/stress.sh holds it to
--  that: it stands in for the game, which holds the whole map).  Before
--  2026-11-14 it was another run: the colony read whatever was loaded, and
--  with the whole map in its routes looked the whole map over (the band's
--  41 days took 85 s for 5.5).  --mem says, once the ground is in, what
--  is kept of every stack that is in, counted by part, and what the process
--  holds.  --no-mesh has the workers make no meshes (the runner throws them
--  away anyway: the run is the same and the ground comes in sooner).
--  --full-summaries keeps each stack's ground summary whole, as it was
--  before it was kept small: the run must be the same (tools/stress.sh).
--  --whole-bricks writes every fine brick whole, likewise.
--
--  A run loaded from a save carries on exactly as the run that wrote it
--  would have, but only from a save taken on a rebuild: its length a whole
--  number of Rebuild_S colony seconds (1/48 of a game day).  The rebuilds
--  are counted from the start of each run, and a loaded run has all its
--  edited ground rebuilt at the start; taken between two rebuilds, the
--  loaded run knows of that ground up to Rebuild_S seconds sooner than the
--  other would have, and the two part some time later (--save says so).
with Ada.Command_Line;      use Ada.Command_Line;
with Ada.Real_Time;         use Ada.Real_Time;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;           use Ada.Text_IO;
with Ada.Unchecked_Deallocation;
with Interfaces;            use Interfaces;
with System.Multiprocessors;
with Castle.Blocks;         use Castle.Blocks;
with Castle.Chunks;
with Castle.Climate;
with Castle.Colony;
with Castle.Dims;           use Castle.Dims;
with Castle.Edits;
with Castle.Flora;
with Castle.Hash;
with Castle.Herds;
with Castle.Maps;
with Ada.Numerics.Elementary_Functions;
with Castle.Math;           use Castle.Math;
with Castle.Nav;
with Castle.Saves;
with Castle.Scenario;
with Castle.Streaming;
with Castle.Text;           use Castle.Text;
with Castle.Water;
with Castle.World_Blocks;
with Castle.Worldgen;

procedure Colony_Run is
   use type Castle.Streaming.Result_Access;
   use type Castle.Saves.Blob_Access;

   Rebuild_S : constant := 30;      --  colony seconds between rebuilds of edited stacks
   --  the game's colony ground: as far as the colony's reach, which is its
   --  work radius until the band looks further afield
   Ground_Stacks : Natural := 0;    --  --ground-stacks N (measuring): this much ground in, whatever the colony reaches
   --  the colony's own ground, which it is told of (Castle.Colony.Set_Ground_Stacks) and reads nothing beyond
   function Own_R return Integer is (Integer (Castle.Colony.Ground_Reach_M / 8.0) + 5);
   Own_Was : Integer := 0;          --  the most it has been
   function Ground_R return Integer is (if Ground_Stacks > 0 then Integer'Max (Ground_Stacks, Own_R) else Own_R);
   Ground_Was : Integer := 0;       --  what it was when the ground was last brought in

   W         : Castle.Maps.World;
   Seed      : Castle.Hash.U64 := 1;
   Scn       : Castle.Scenario.Setup;
   Start_Day : Float := 20.0;
   Start_Hour : Float := 15.0;
   Days      : Float := 1.0;
   Log_Hours : Float := 0.0;
   Who       : Boolean := False;   --  --who: with each of those lines, what each of the band is doing
   Workers   : Positive := Positive'Max (1, Positive (System.Multiprocessors.Number_Of_CPUs) - 1);
   Load_Path, Save_Path, Expect : Unbounded_String;
   Hours     : Long_Float := 0.0;

   type Stack_State is (None, Asked, In_Place);
   States  : array (0 .. Chunks_XY - 1, 0 .. Chunks_XY - 1) of Stack_State := [others => [others => None]];
   Waiting : Natural := 0;          --  stacks asked for and not yet back
   Dirty   : array (0 .. Chunks_XY - 1, 0 .. Chunks_XY - 1) of Boolean := [others => [others => False]];
   Any_Dirty : Boolean := False;
   Rebuilt : Natural := 0;
   Wider   : Natural := 0;          --  times the colony's ground was widened

   function Material_At (Bx, By, Bz : Integer) return Material is
     (Castle.World_Blocks.Block_At (Bx, By, Bz).Mat);

   function Colony_Tree (I, J : Integer) return Castle.Colony.Tree_Info is
      T : constant Castle.Flora.Tree := Castle.Flora.Tree_At (W, I, J);
   begin
      if not T.Valid then
         return (others => <>);
      end if;
      return (Valid => True,
              Kind => (case T.Kind is
                          when Castle.Flora.Broadleaf | Castle.Flora.Aspen => Castle.Colony.Broadleaf,
                          when Castle.Flora.Spruce | Castle.Flora.Pine     => Castle.Colony.Conifer,
                          when Castle.Flora.Apple                          => Castle.Colony.Apple),
              Bx => T.Bx, By => T.By, Bz => T.Bz, Trunk_W => T.Trunk_W, Trunk_H => T.Trunk_H);
   end Colony_Tree;

   procedure Colony_Tree_Shape
     (I, J  : Integer;
      Visit : not null access procedure (Bx, By, Bz : Integer; M : Material)) is
   begin
      Castle.Flora.Tree_Blocks (Castle.Flora.Tree_At (W, I, J), Visit);
   end Colony_Tree_Shape;

   --  The colony's edits: into the edit store, as the game's are.
   procedure Colony_Write (Bx, By, Bz : Integer; B : Block) is
   begin
      if Bx not in 0 .. Size_B - 1 or else By not in 0 .. Size_B - 1 or else Bz not in 0 .. Height_B - 1 then
         return;
      end if;
      Castle.Edits.Set (Bx, By, Bz, B);
      Castle.World_Blocks.Note_Edit (Bx, By);
      Castle.World_Blocks.Reground (Bx, By, Bz, Bz);
      for CX in Integer'Max (0, Bx - 1) / Chunk_B .. Integer'Min (Size_B - 1, Bx + 1) / Chunk_B loop
         for CY in Integer'Max (0, By - 1) / Chunk_B .. Integer'Min (Size_B - 1, By + 1) / Chunk_B loop
            Dirty (CX, CY) := True;
            Any_Dirty := True;
         end loop;
      end loop;
   end Colony_Write;

   procedure Ask (CX, CY : Integer) is
   begin
      Castle.Streaming.Wanted (CX, CY) := True;
      Castle.Streaming.Request (CX, CY, 0.0, Castle.Water.View_Of (CX, CY), Castle.Water.Version (CX, CY));
      Waiting := Waiting + 1;
   end Ask;

   --  Wait for every stack asked for: each goes in as the game keeps it.
   procedure Take_All is
      Res : Castle.Streaming.Result_Access;
   begin
      while Waiting > 0 loop
         Castle.Streaming.Poll (Res);
         if Res = null then
            delay 0.000_2;
         else
            Waiting := Waiting - 1;
            if Res.Gen /= Castle.Edits.Generation (Res.CX, Res.CY) then   --  (never: nothing edits while we wait)
               Ask (Res.CX, Res.CY);
            end if;
            Castle.World_Blocks.Keep (Res.CX, Res.CY, Res.Packed, Res.Gen, Res.Summary);
            States (Res.CX, Res.CY) := In_Place;
            Castle.Streaming.Free (Res);
         end if;
      end loop;
   end Take_All;

   --  The ground within Ground_R stacks of (Xm, Ym), in.
   procedure Load_Ground (Xm, Ym : Float) is
      SX : constant Integer := Integer (Float'Floor (Xm / 8.0));
      SY : constant Integer := Integer (Float'Floor (Ym / 8.0));
   begin
      Ground_Was := Ground_R;
      for Dy in -Ground_R .. Ground_R loop
         for Dx in -Ground_R .. Ground_R loop
            if Dx * Dx + Dy * Dy <= Ground_R * Ground_R
              and then SX + Dx in 0 .. Chunks_XY - 1 and then SY + Dy in 0 .. Chunks_XY - 1
              and then States (SX + Dx, SY + Dy) = None
            then
               States (SX + Dx, SY + Dy) := Asked;
               Ask (SX + Dx, SY + Dy);
               --  (in batches still.  A great deal of ground asked for all at once never
               --  came in: the streaming's queue held 32,768 jobs and dropped the rest, its
               --  ring of results 8,192, both silently, and this waited for ever.  Mended
               --  2026-11-14, Castle.Streaming: every stack at once comes in in 8 s)
               if Ground_Stacks > 0 and then Waiting >= 512 then
                  Take_All;
               end if;
            end if;
         end loop;
      end loop;
      Take_All;
      Own_Was := Integer'Max (Own_Was, Own_R);
      Castle.Colony.Set_Ground_Stacks (Own_Was);
   end Load_Ground;

   --  --mem: what is kept of the stacks that are in, by part, and what the
   --  process holds (Linux: /proc/self/status).
   procedure Put_Mem is
      Z : constant Castle.World_Blocks.Kept_Sizes := Castle.World_Blocks.Sizes;
      N : constant Long_Integer := Long_Integer'Max (1, Long_Integer (Z.Stacks));
      All_Bytes : constant Long_Integer := Z.Summaries + Z.Arrays + Z.Grids + Z.Fine + Z.Notes + Z.Records;
      Fine_N : Long_Integer := 0;
      Cols : Long_Integer := 0;
      function KB (B : Long_Integer) return String is (Img (Float (B) / 1024.0, 1) & " KB");
      function MB (B : Long_Integer) return String is (Img (Float (B) / 1_048_576.0, 0) & " MB");
      function Share (A, Of_All : Long_Integer) return String is
        (Img (100.0 * Float (A) / Float (Long_Integer'Max (1, Of_All)), 1) & " %");
   begin
      for K in Z.Fine_By'Range loop
         Fine_N := Fine_N + Z.Fine_By (K);
      end loop;
      for K in Z.Columns'Range loop
         Cols := Cols + Z.Columns (K);
      end loop;
      Put_Line ("mem:" & Z.Stacks'Image & " stacks in; kept of them " & MB (All_Bytes) & ", " & KB (All_Bytes / N)
                & " a stack, in" & Z.Allocations'Image & " allocations");
      Put_Line ("mem: a stack: the water summary " & KB (Z.Summaries / N) & " (" & Share (Z.Summaries, All_Bytes)
                & "); fine bricks " & KB (Z.Fine / N) & " (" & Share (Z.Fine, All_Bytes) & "), "
                & Img (Float (Fine_N) / Float (N), 0) & " of them; brick and ref grids " & KB (Z.Grids / N) & " ("
                & Share (Z.Grids, All_Bytes) & "), " & Img (Float (Z.Chunks_Fine) / Float (N), 1)
                & " chunks not uniform; the array of chunks " & KB (Z.Arrays / N) & "; edit notes " & KB (Z.Notes / N)
                & "; its record" & Long_Integer'Image (Z.Records / N) & " bytes");
      Put ("mem: fine bricks by what they hold:");
      for K in Z.Fine_By'Range loop
         Put (" " & (case K is
                        when Castle.Chunks.Holds_Built   => "something built",
                        when Castle.Chunks.Holds_Tree    => "trees",
                        when Castle.Chunks.Holds_Plant   => "plants",
                        when Castle.Chunks.Holds_Water   => "water",
                        when Castle.Chunks.Holds_Boulder => "boulders",
                        when Castle.Chunks.Holds_Surface => "open surface",
                        when Castle.Chunks.Holds_Buried  => "ground with no air in it")
              & " " & Share (Z.Fine_By (K), Fine_N) & " ("
              & KB (Z.Fine_Bytes_By (K) / N) & " a stack)"
              & (if K in Castle.Chunks.Holds_Buried then "" else ","));
      end loop;
      New_Line;
      Put_Line ("mem: a stack's blocks (array, grids, fine bricks): least " & KB (Long_Integer (Z.Least)) & ", a tenth under "
                & KB (Long_Integer (Z.Tenth)) & ", half under " & KB (Long_Integer (Z.Median)) & ", nine tenths under "
                & KB (Long_Integer (Z.Ninetieth)) & ", most " & KB (Long_Integer (Z.Most)) & " (stack"
                & Z.Heaviest_CX'Image & Z.Heaviest_CY'Image & ")");
      if Cols > 0 then
         Put_Line ("mem: block columns by their stretches of open space: one " & Share (Z.Columns (1), Cols) & ", two "
                   & Share (Z.Columns (2), Cols) & ", three " & Share (Z.Columns (3), Cols) & ", four "
                   & Share (Z.Columns (4), Cols) & ", none " & Share (Z.Columns (0), Cols) & "; with water "
                   & Share (Z.Columns_Wet, Cols) & "; one stretch, open to the sky and dry "
                   & Share (Z.Columns_Plain, Cols));
      end if;
      declare
         F : Ada.Text_IO.File_Type;
      begin
         Open (F, In_File, "/proc/self/status");
         while not End_Of_File (F) loop
            declare
               L : constant String := Get_Line (F);
            begin
               if L'Length > 6 and then L (L'First .. L'First + 5) = "VmRSS:" then
                  Put_Line ("mem: the process holds now (resident): " & L (L'First + 6 .. L'Last));
               elsif L'Length > 6 and then L (L'First .. L'First + 5) = "VmHWM:" then
                  Put_Line ("mem: and at most so far: " & L (L'First + 6 .. L'Last));
               end if;
            end;
         end loop;
         Close (F);
      exception
         when others => null;            --  (no such file: not Linux)
      end;
   end Put_Mem;

   procedure Rebuild_Dirty is
   begin
      if not Any_Dirty then
         return;
      end if;
      for CX in Dirty'Range (1) loop
         for CY in Dirty'Range (2) loop
            if Dirty (CX, CY) then
               Dirty (CX, CY) := False;
               if States (CX, CY) = In_Place then
                  Ask (CX, CY);
                  Rebuilt := Rebuilt + 1;
               end if;
            end if;
         end loop;
      end loop;
      Any_Dirty := False;
      Take_All;
   end Rebuild_Dirty;

   function State_Hash return String is
      Data : constant Castle.Colony.Bytes := Castle.Colony.Save;
      H    : Unsigned_64 := 16#CBF2_9CE4_8422_2325#;
      Hex  : constant String := "0123456789abcdef";
      Out_S : String (1 .. 16);
   begin
      for B of Data loop
         H := (H xor Unsigned_64 (B)) * 16#0000_0100_0000_01B3#;
      end loop;
      for K in reverse Out_S'Range loop
         Out_S (K) := Hex (Natural (H and 15) + 1);
         H := Shift_Right (H, 4);
      end loop;
      return Out_S & " (" & Img (Integer (Data'Length)) & " bytes)";
   end State_Hash;

   procedure Save_To (Path : String) is
      Err  : Unbounded_String;
      Data : constant Castle.Colony.Bytes := Castle.Colony.Save;
      Blob : Castle.Saves.Blob_Access := new Castle.Saves.Blob'(Castle.Saves.Blob (Data));
      procedure Free is new Ada.Unchecked_Deallocation (Castle.Saves.Blob, Castle.Saves.Blob_Access);
      Climate : Castle.Climate.State;
      S    : constant Vec3 := Castle.Colony.Stake;
   begin
      Castle.Climate.Start (Climate, W.Seed, Castle.Climate.Game_Hours (Hours));
      Castle.Saves.Save
        (Path, (Seed => Seed, Clock => Hours, Climate => Climate,
                Cam_X => S.X, Cam_Y => S.Y, Cam_Yaw => 2.5, Cam_Pitch => 0.8, Cam_Dist => 30.0, Colony => Blob), Err);
      Free (Blob);
      Put_Line (if Err = Null_Unbounded_String then "saved " & Path & " (" & Img (Castle.Edits.Count) & " edits)"
                else "save failed: " & To_String (Err));
   end Save_To;

   --  --deer-track FILE: where every deer is after each colony second, for
   --  looking at how the herds move (a line a deer: the second, the deer,
   --  its herd, x y z, whether it is in panic, the rows of water it stands
   --  in, and its herd's node).
   Track_Path : Unbounded_String;
   Nav_Stats  : Boolean := False;        --  --nav-stats: what the walking map and the routes cost, at the end
   Try_Plan   : Boolean := False;        --  --try-plan X0 Y0 Z0 X1 Y1 Z1 WADE: at the end, a herd's way asked of the ground
   Try_From, Try_To : Vec3 := (0.0, 0.0, 0.0);
   Try_Wade   : Natural := 0;
   Try_Budget : Positive := Castle.Herds.Herd_Budget;   --  --try-budget N: floors that plan may look at
   Try_Within : Castle.Nav.Region := Castle.Nav.Everywhere;   --  --try-within X Y R: the ground it keeps to
   Try_Refuse : Boolean := False;        --  --try-refuse: not made for at all if the pieces say out of reach
   Nav_Log    : Unbounded_String;        --  --nav-log FILE: every plan that ran out of budget, as it happens
   Nav_Log_F  : Ada.Text_IO.File_Type;
   Clock_Now  : Long_Float := 0.0;       --  (the game clock, for that log's lines)
   No_Memos   : Boolean := False;        --  --no-memos (with --no-mending: the two that must change no run)
   Mem        : Boolean := False;        --  --mem: what is kept of the ground, counted, once it is in
   Step_Sum   : Long_Float := 0.0;       --  seconds in Castle.Colony.Advance, in all
   Step_Max   : Float := 0.0;            --  the longest colony second (twenty steps)
   Step_Slow  : Natural := 0;            --  colony seconds that took 10 ms or more
   Track_File : Ada.Text_IO.File_Type;
   Track_Open : Boolean := False;

   --  --nav-log: a line for each plan that ran out of budget, when it did.
   procedure Log_Spent (P : Castle.Nav.Spent_Plan) is
      D : constant Natural := Natural (Long_Float'Floor (Clock_Now / 24.0));
   begin
      Put_Line (Nav_Log_F,
                "day" & D'Image & " " & Img (Float (Clock_Now - Long_Float (D) * 24.0), 2) & " h: from "
                & Img (P.From.X, 1) & " " & Img (P.From.Y, 1) & " " & Img (P.From.Z, 1) & " to "
                & Img (P.To.X, 1) & " " & Img (P.To.Y, 1) & " " & Img (P.To.Z, 1) & "; budget" & P.Budget'Image
                & ", wade" & P.Wade'Image & ", the pieces said " & P.Answer'Image & ", " & P.Result'Image
                & ", ended " & Img (P.Reached_M, 1) & " m short, " & Img (P.Seconds * 1000.0, 1) & " ms");
      --  who of the band is nearest where it began (a herd's way begins at its node: who is frightening it)
      declare
         Best : Natural := 0;
         Dm   : Float := Float'Last;
      begin
         for I in 1 .. Castle.Colony.Members loop
            if not Castle.Colony.Dead (I) then
               declare
                  W : constant Vec3 := Castle.Colony.Where (I);
                  D : constant Float :=
                    Ada.Numerics.Elementary_Functions.Sqrt ((W.X - P.From.X) ** 2 + (W.Y - P.From.Y) ** 2);
               begin
                  if D < Dm then
                     Dm := D;
                     Best := I;
                  end if;
               end;
            end if;
         end loop;
         if Best > 0 then
            Put_Line (Nav_Log_F, "    nearest of the band: " & Castle.Colony.Name_Of (Best) & " (" & Best'Image & " ), "
                      & Img (Dm, 1) & " m off at " & Img (Castle.Colony.Where (Best).X, 1) & " "
                      & Img (Castle.Colony.Where (Best).Y, 1) & ", " & Castle.Colony.Job_Of (Best)'Image & ": "
                      & Castle.Colony.Status (Best));
         end if;
      end;
   end Log_Spent;

   procedure Track_Deer (Second : Natural) is
      use Castle.Herds;
   begin
      if not Track_Open then
         Create (Track_File, Out_File, To_String (Track_Path));
         Track_Open := True;
      end if;
      for K in 1 .. Deer_Slots loop
         if Alive (K) then
            declare
               P : constant Vec3 := Where (K);
               N : Natural;
               F : Castle.Nav.Floor_List;
               Wet : Natural := 0;
               Best : Integer := Integer'Last;
               Zr : constant Integer := Integer (Float'Floor (P.Z * 4.0 + 0.5));
               Nd : constant Vec3 := Node (Herd_Of (K));
            begin
               Castle.Nav.Floors_At (Integer (Float'Floor (P.X / Castle.Nav.Cell_M)),
                                     Integer (Float'Floor (P.Y / Castle.Nav.Cell_M)), N, F);
               for J in 1 .. N loop
                  if abs (F (J).Z - Zr) < abs (Best - Zr) then
                     Best := F (J).Z;
                     Wet := F (J).Water;
                  end if;
               end loop;
               Put_Line (Track_File, Second'Image & K'Image & Herd_Of (K)'Image & " " & Img (P.X, 2) & " " & Img (P.Y, 2)
                         & " " & Img (P.Z, 2) & (if In_Panic (K) then " 1" else " 0") & Wet'Image
                         & " " & Img (Nd.X, 2) & " " & Img (Nd.Y, 2));
            end;
         end if;
      end loop;
   end Track_Deer;

   I  : Positive := 1;
   T0 : constant Time := Clock;
begin
   while I <= Argument_Count loop
      declare
         A : constant String := Argument (I);
      begin
         if Castle.Scenario.Parse (Scn, I) then
            null;
         elsif A = "--seed" then
            Seed := Castle.Hash.U64'Value (Argument (I + 1)); I := I + 2;
         elsif A = "--day" then
            Start_Day := Float'Value (Argument (I + 1)); I := I + 2;
         elsif A = "--time" then
            Start_Hour := Float'Value (Argument (I + 1)); I := I + 2;
         elsif A = "--days" then
            Days := Float'Value (Argument (I + 1)); I := I + 2;
         elsif A = "--log-hours" then
            Log_Hours := Float'Value (Argument (I + 1)); I := I + 2;
         elsif A = "--who" then
            Who := True; I := I + 1;
         elsif A = "--workers" then
            Workers := Positive'Value (Argument (I + 1)); I := I + 2;
         elsif A = "--load" then
            Load_Path := To_Unbounded_String (Argument (I + 1)); I := I + 2;
         elsif A = "--expect" then
            Expect := To_Unbounded_String (Argument (I + 1)); I := I + 2;
         elsif A = "--save" then
            Save_Path := To_Unbounded_String (Argument (I + 1)); I := I + 2;
         elsif A = "--deer-track" then
            Track_Path := To_Unbounded_String (Argument (I + 1)); I := I + 2;
         elsif A = "--nav-stats" then
            Nav_Stats := True; I := I + 1;
         elsif A = "--ground-stacks" then
            Ground_Stacks := Natural'Value (Argument (I + 1)); I := I + 2;
         elsif A = "--mem" then
            Mem := True; I := I + 1;
         elsif A = "--full-summaries" then      --  each stack's ground summary kept whole, as it always was
            Castle.World_Blocks.Small_Summaries := False; I := I + 1;
         elsif A = "--whole-bricks" then        --  each fine brick written whole, as it always was
            Castle.Chunks.Small_Bricks := False; I := I + 1;
         elsif A = "--no-mesh" then
            Castle.Streaming.Build_Meshes := False; I := I + 1;
         elsif A = "--nav-log" then
            Nav_Log := To_Unbounded_String (Argument (I + 1)); I := I + 2;
         elsif A = "--try-plan" then
            Try_Plan := True;
            Try_From := (Float'Value (Argument (I + 1)), Float'Value (Argument (I + 2)), Float'Value (Argument (I + 3)));
            Try_To := (Float'Value (Argument (I + 4)), Float'Value (Argument (I + 5)), Float'Value (Argument (I + 6)));
            Try_Wade := Natural'Value (Argument (I + 7));
            I := I + 8;
         elsif A = "--try-budget" then
            Try_Budget := Positive'Value (Argument (I + 1)); I := I + 2;
         elsif A = "--try-within" then
            Try_Within := Castle.Nav.Within_M (Float'Value (Argument (I + 1)), Float'Value (Argument (I + 2)),
                                               Float'Value (Argument (I + 3)));
            I := I + 4;
         elsif A = "--try-refuse" then
            Try_Refuse := True; I := I + 1;
         elsif A = "--prove-dry" then           --  every dry way called out of reach searched for whole (slow)
            Castle.Nav.Prove_Dry := True; I := I + 1;
         elsif A = "--no-mending" then          --  every changed stack of the walking map read whole
            Castle.Nav.Mending := False; I := I + 1;
         elsif A = "--no-memos" then            --  every search for a source reads the ground again (and nothing of housing is kept)
            No_Memos := True; I := I + 1;
         else
            Put_Line ("colony_run: unknown option " & A);
            Set_Exit_Status (2);
            return;
         end if;
      end;
   end loop;

   if Load_Path /= Null_Unbounded_String then
      declare
         Err : Unbounded_String;
      begin
         Castle.Saves.Peek (To_String (Load_Path), Seed, Err);
         if Err /= Null_Unbounded_String then
            Put_Line ("load failed: " & To_String (Err));
            Set_Exit_Status (1);
            return;
         end if;
      end;
   end if;

   Castle.Worldgen.Create (Seed, W, Report => False);
   Castle.Water.Set_Ground (Castle.World_Blocks.Ground'Access);
   Castle.Nav.Set_Source (Castle.World_Blocks.Ground'Access, Material_At'Unrestricted_Access,
                          Castle.World_Blocks.Ground_Version'Access,
                          Castle.World_Blocks.Changes_Since'Access);
   Castle.Colony.Set_World (Castle.World_Blocks.Block_At'Access, Colony_Write'Unrestricted_Access,
                            Castle.World_Blocks.Ground_Version'Access);
   Castle.Colony.Set_Source_Memos (not No_Memos);
   Castle.Colony.Set_House_Memos (not No_Memos);
   Castle.Nav.Set_Spent_Memos (not No_Memos);
   Castle.Colony.Set_Trees (Colony_Tree'Unrestricted_Access, Colony_Tree_Shape'Unrestricted_Access);
   Castle.Streaming.Start (W, Workers);
   Hours := Long_Float (Start_Day) * 24.0 + Long_Float (Start_Hour);

   if Load_Path /= Null_Unbounded_String then
      declare
         Err : Unbounded_String;
         S   : Castle.Saves.Snapshot;
         Ok  : Boolean := False;
      begin
         Castle.Saves.Load (To_String (Load_Path), S, Err);
         if Err = Null_Unbounded_String and then S.Colony /= null then
            Castle.Colony.Load (Castle.Colony.Bytes (S.Colony.all), Ok);
         end if;
         if not Ok or else not Castle.Colony.Has_Stake then
            Put_Line ("load failed: " & (if Err /= Null_Unbounded_String then To_String (Err)
                                         else "no colony in that save"));
            Castle.Streaming.Stop;
            Set_Exit_Status (1);
            return;
         end if;
         Hours := S.Clock;
         Castle.World_Blocks.Note_All_Edited;
         Load_Ground (Castle.Colony.Stake.X, Castle.Colony.Stake.Y);
         Put_Line ("loaded " & To_String (Load_Path) & " (" & Img (Castle.Edits.Count) & " edits)");
      end;
   elsif Scn.Stake then
      Load_Ground (Scn.Stake_X, Scn.Stake_Y);
      Castle.Scenario.Apply (Scn, Seed);
      Rebuild_Dirty;
   else
      Put_Line ("colony_run: give it --stake X Y or --load FILE");
      Castle.Streaming.Stop;
      Set_Exit_Status (2);
      return;
   end if;
   Put_Line ("world" & Seed'Image & ", ground in, " & Img (Float (To_Duration (Clock - T0)), 1) & " s");
   if Mem then
      Put_Mem;
   end if;
   Castle.Scenario.Put_Report;

   declare
      Seconds : constant Natural := Natural (Days * 1_440.0);    --  a colony second is a game minute
      Told    : array (1 .. Castle.Colony.Max_Members) of Boolean := [others => False];
      Logged  : Long_Float := -1.0;
      T1      : constant Time := Clock;
   begin
      for I in 1 .. Castle.Colony.Members loop
         Told (I) := Castle.Colony.Dead (I);
      end loop;
      if Nav_Log /= Null_Unbounded_String then
         Create (Nav_Log_F, Out_File, To_String (Nav_Log));
         Castle.Nav.On_Spent (Log_Spent'Unrestricted_Access);
      end if;
      for S in 1 .. Seconds loop
         Hours := Hours + 1.0 / 60.0;
         Clock_Now := Hours;
         if Ground_R > Ground_Was or else Own_R > Own_Was then   --  the colony reaches further: that ground in first, as the game waits for it
            Load_Ground (Castle.Colony.Stake.X, Castle.Colony.Stake.Y);
            Wider := Wider + 1;
         end if;
         declare
            A0 : constant Time := Clock;
            Dt : Float;
         begin
            Castle.Colony.Advance (1.0, Hours);
            Dt := Float (To_Duration (Clock - A0));
            Step_Sum := Step_Sum + Long_Float (Dt);
            Step_Max := Float'Max (Step_Max, Dt);
            if Dt >= 0.010 then
               Step_Slow := Step_Slow + 1;
            end if;
         end;
         if S mod Rebuild_S = 0 then
            Rebuild_Dirty;
         end if;
         for I in 1 .. Castle.Colony.Members loop
            if Castle.Colony.Dead (I) and then not Told (I) then
               Told (I) := True;
               Put_Line (Castle.Colony.Name_Of (I) & " has died of hunger");
            end if;
         end loop;
         if Track_Path /= Null_Unbounded_String then
            Track_Deer (S);
         end if;
         if Log_Hours > 0.0 and then Long_Float'Floor (Hours / Long_Float (Log_Hours)) /= Logged then
            Logged := Long_Float'Floor (Hours / Long_Float (Log_Hours));
            Put_Line (Castle.Scenario.Food_Line (Hours));
            if Who then
               Castle.Scenario.Put_Who;
               --  and each herd: where, and who of the band is nearest its node
               for H in 1 .. Castle.Herds.Herd_Count loop
                  if Castle.Herds.In_Herd (H) > 0 then
                     declare
                        Nd   : constant Vec3 := Castle.Herds.Node (H);
                        Best : Natural := 0;
                        Dm   : Float := Float'Last;
                     begin
                        for I in 1 .. Castle.Colony.Members loop
                           if not Castle.Colony.Dead (I) then
                              declare
                                 W : constant Vec3 := Castle.Colony.Where (I);
                                 D : constant Float :=
                                   Ada.Numerics.Elementary_Functions.Sqrt ((W.X - Nd.X) ** 2 + (W.Y - Nd.Y) ** 2);
                              begin
                                 if D < Dm then
                                    Dm := D;
                                    Best := I;
                                 end if;
                              end;
                           end if;
                        end loop;
                        Put_Line ("    herd" & H'Image & ":" & Castle.Herds.In_Herd (H)'Image & " deer, its node at "
                                  & Img (Nd.X, 1) & " " & Img (Nd.Y, 1)
                                  & (if Castle.Herds.Panicked (H) then ", in flight" else "")
                                  & (if Best > 0
                                     then "; nearest of the band " & Castle.Colony.Name_Of (Best) & ", "
                                          & Img (Dm, 1) & " m off at " & Img (Castle.Colony.Where (Best).X, 1) & " "
                                          & Img (Castle.Colony.Where (Best).Y, 1) & ", "
                                          & Castle.Colony.Job_Of (Best)'Image & ": " & Castle.Colony.Status (Best)
                                     else ""));
                     end;
                  end if;
               end loop;
            end if;
         end if;
      end loop;
      Rebuild_Dirty;
      Castle.Scenario.Put_Report;
      Put_Line ("ran " & Img (Days, 2) & " game days in " & Img (Float (To_Duration (Clock - T1)), 1) & " s;"
                & Rebuilt'Image & " stack rebuilds," & Castle.Edits.Count'Image & " edits"
                & (if Wider > 0 then "; the ground widened" & Wider'Image & " times" else ""));
      if Try_Plan then
         declare
            Before : constant Castle.Nav.Answer_Counts := Castle.Nav.Spent_By;
            R  : constant Castle.Nav.Route :=
              Castle.Nav.Plan (Try_From, Try_To, Budget => Try_Budget, Wade => Try_Wade,
                               Within => Try_Within, Refuse => Try_Refuse);
            After : constant Castle.Nav.Answer_Counts := Castle.Nav.Spent_By;
         begin
            Put ("try-plan: " & R.Result'Image & "," & Castle.Nav.Last_Stats.Looked_At'Image & " floors, "
                 & Img (Castle.Nav.Last_Stats.Seconds * 1000.0, 1) & " ms, a way of "
                 & Img (Castle.Nav.Length (R), 1) & " m"
                 & (if Castle.Nav.Last_Stats.Out_Of_Reach then "; the pieces of ground said out of reach" else ""));
            for A in After'Range loop
               if After (A) > Before (A) then
                  Put ("; it ran out of budget, the pieces having said " & A'Image);
               end if;
            end loop;
            New_Line;
         end;
      end if;
      if Nav_Stats then
         declare
            N : constant Castle.Nav.Totals_Rec := Castle.Nav.Totals;
         begin
            Put_Line ("nav: the colony's steps took " & Img (Float (Step_Sum), 2) & " s in all; the longest colony second "
                      & Img (Step_Max * 1000.0, 1) & " ms;" & Step_Slow'Image & " took 10 ms or more");
            Put_Line ("nav: the ground's version moved" & Castle.World_Blocks.Stamps_By_Edit'Image
                      & " times for an edited column," & Castle.World_Blocks.Stamps_By_Stack'Image
                      & " for a stack kept anew; a stack's small summary was packed again"
                      & Castle.World_Blocks.Summary_Repacks'Image & " times");
            Put_Line ("nav: the map read anew:" & N.Stacks_Built'Image & " stacks whole," & N.Stacks_Mended'Image
                      & " mended," & N.Cells_Built'Image & " cells in all," & N.Labellings'Image & " labellings, "
                      & Img (Float (N.Map_Seconds), 2) & " s");
            Put_Line ("nav:" & N.Plans'Image & " plans," & N.Plan_Floors'Image & " floors looked at, "
                      & Img (Float (N.Plan_Seconds), 2) & " s in them (the slowest "
                      & Img (N.Longest_Plan * 1000.0, 1) & " ms);" & N.Rewalks'Image & " routes walked again,"
                      & N.Rewalk_Steps'Image & " legs");
            Put_Line ("nav:" & N.Slow_Plans'Image & " plans of 5 ms or more took "
                      & Img (Float (N.Slow_Seconds), 2) & " s;" & N.Spent_Plans'Image & " ran out of budget,"
                      & N.Short_Plans'Image & " ended short of the goal," & N.Unreached'Image
                      & " were known out of reach with no search," & N.Remembered'Image
                      & " were answered from the memory of one that ran out of budget");
            Put_Line ("nav: the herds were frightened" & Castle.Herds.Frights'Image & " times");
            Put_Line ("nav: dry going:" & N.Refused'Image & " ways refused as out of reach ("
                      & Img (Float (N.Refused_Seconds) * 1000.0, 1) & " ms in all);"
                      & N.Dry_Labellings'Image & " times a stack's dry pieces were worked out"
                      & (if Castle.Nav.Prove_Dry
                         then ";" & N.Proved'Image & " answers of out of reach searched for whole and borne out,"
                              & N.Unproved'Image & " not searched whole"
                         else ""));
            if N.Spent_Plans > 0 then
               declare
                  By : constant Castle.Nav.Answer_Counts := Castle.Nav.Spent_By;
               begin
                  Put ("nav: of those that ran out of budget, the pieces of ground had said:");
                  for A in By'Range loop
                     if By (A) > 0 then
                        Put (By (A)'Image & " " & A'Image);
                     end if;
                  end loop;
                  New_Line;
               end;
            end if;
            for P of Castle.Nav.Slowest loop
               exit when P.Seconds <= 0.0;
               Put_Line ("nav:   " & Img (P.Seconds * 1000.0, 1) & " ms," & P.Looked_At'Image & " floors, "
                         & P.Result'Image & ": from " & Img (P.From.X, 1) & " " & Img (P.From.Y, 1) & " "
                         & Img (P.From.Z, 1) & " to " & Img (P.To.X, 1) & " " & Img (P.To.Y, 1) & " " & Img (P.To.Z, 1)
                         & " (" & Img (Ada.Numerics.Elementary_Functions.Sqrt ((P.From.X - P.To.X) ** 2 + (P.From.Y - P.To.Y) ** 2), 0)
                         & " m off), ended " & Img (P.Reached_M, 1) & " m short");
            end loop;
         end;
      end if;
   end;
   if Save_Path /= Null_Unbounded_String then
      Save_To (To_String (Save_Path));
      if Natural (Days * 1_440.0) mod Rebuild_S /= 0 then
         Put_Line ("(saved" & Natural'Image (Natural (Days * 1_440.0) mod Rebuild_S)
                   & " colony seconds after the last rebuild of edited ground: a run loaded from this save will not"
                   & " keep step with one run straight on; for that, end the run on a multiple of"
                   & Natural'Image (Rebuild_S) & " colony seconds, 1/48 of a game day)");
      end if;
   end if;
   Put_Line ("state: " & State_Hash);
   Castle.Streaming.Stop;
   if Expect /= Null_Unbounded_String then
      declare
         E : constant String := To_String (Expect);
         H : constant String := State_Hash;
      begin
         if E'Length > 16 or else H (H'First .. H'First + E'Length - 1) /= E then
            Put_Line ("FAIL: expected state " & E);
            Set_Exit_Status (1);
         else
            Put_Line ("the state is as expected");
         end if;
      end;
   end if;
end Colony_Run;
