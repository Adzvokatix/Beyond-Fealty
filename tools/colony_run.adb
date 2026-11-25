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
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;           use Ada.Text_IO;
with Ada.Unchecked_Deallocation;
with Ada.Exceptions;
with GNAT.OS_Lib;
with GNAT.Traceback.Symbolic;
with Interfaces;            use Interfaces;
with System.Multiprocessors;
with Castle.Actions;
with Castle.Blocks;         use Castle.Blocks;
with Castle.Buildings;
with Castle.Chunks;
with Castle.Climate;
with Castle.Colony;
with Castle.Dims;           use Castle.Dims;
with Castle.Edits;
with Castle.Fields;
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
   Raze_K    : Natural := 0;       --  --raze K HOURS: house K marked for razing that many game hours into the run
   Raze_At_S : Natural := 0;       --  (if nobody owns it then: said either way)
   --  --later HOURS ORDER ...: an order of the player's given that many game hours into the run, through
   --  the action table as a click gives it (a second pull of housing days in, a path drawn on from the
   --  square, a stockpile removed): what a colony founded with everything at once never meets.
   --    housing-pull X0 Y0 X1 Y1 ROWS     path X0 Y0 X1 Y1     stockpile-box X Y WAY
   --    remove-stockpile ZONE             job MEMBER JOB
   type Later_Kind is (Later_Pull, Later_Path, Later_Box, Later_Remove, Later_Job);
   type Later_Values is array (1 .. 5) of Float;
   type Later_Order is record
      At_S : Natural := 0;
      Kind : Later_Kind := Later_Pull;
      V    : Later_Values := [others => 0.0];
      Job  : Castle.Colony.Job_Kind := Castle.Colony.Unassigned;
   end record;
   Later   : array (1 .. 16) of Later_Order;
   Later_N : Natural := 0;
   Removed_Seen : Natural := 0;     --  (stockpiles gone so far: said as each goes)
   Floating  : Boolean := False;   --  --floating: at the end, plants standing over air near the stake (grass in the air)
   Workers   : Positive := Positive'Max (1, Positive (System.Multiprocessors.Number_Of_CPUs) - 1);
   Load_Path, Save_Path, Expect : Unbounded_String;
   Hours     : Long_Float := 0.0;

   type Stack_State is (None, Asked, In_Place);
   States  : array (0 .. Chunks_XY - 1, 0 .. Chunks_XY - 1) of Stack_State := [others => [others => None]];
   Waiting : Natural := 0;          --  stacks asked for and not yet back
   Dirty   : array (0 .. Chunks_XY - 1, 0 .. Chunks_XY - 1) of Boolean := [others => [others => False]];
   Any_Dirty : Boolean := False;
   --  (the stacks the colony has written to since the land was last put back: Land_Back)
   Touched : array (0 .. Chunks_XY - 1, 0 .. Chunks_XY - 1) of Boolean := [others => [others => False]];
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
            Touched (CX, CY) := True;
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

   --  --box-stats: every zone put down whole, as it lies now.
   Walls_From, Walls_Until : Integer := -1;      --  (the colony seconds of the run between which its walls were being built)
   Walls_Most : Natural := 0;                    --  (blocks of stone they wanted when first counted)
   --  Where a side's stair stands, and the bank a stair would stand against, in words.
   function Stair_Word (P : Castle.Colony.Stair_Place) return String is
     (case P is
         when Castle.Colony.No_Stair  => "none",
         when Castle.Colony.At_Low    => "its low end",
         when Castle.Colony.At_Middle => "its middle",
         when Castle.Colony.At_High   => "its high end");
   function Bank_Word (B : Castle.Colony.Stair_Bank) return String is
     (if not B.Read then " ?"
      elsif B.Level then " level"
      else " " & Img (B.Least_B) & (if B.Most_B /= B.Least_B then "-" & Img (B.Most_B) else "")
           & (if B.Up then "u" elsif B.Banked then "d" else "x") & (if B.Takes then "*" else ""));
   procedure Put_Boxes (Said : String) is
      use Castle.Colony;
      Ways : constant array (Way_Index) of String (1 .. 2) := ["E ", "NE", "N ", "NW", "W ", "SW", "S ", "SE"];
      Any  : Boolean := False;
   begin
      for Z in 1 .. Zone_Count loop
         declare
            V : constant Zone_View := Zone_At (Z);
            C : constant Box_Count := Box_Counts (Z);
            Closed : Natural := 0;
         begin
            for K in 1 .. Cell_Count loop
               if Zone_Of_Cell (K) = Z and then Cell_At (K).Closed then
                  Closed := Closed + 1;
               end if;
            end loop;
            if V.Placed then
               Any := True;
               Put_Line ("box " & Said & ": zone" & Z'Image & ", its front from " & Img (V.From.X, 2) & ", "
                         & Img (V.From.Y, 2) & " " & Ways (V.Way) & V.Along_B'Image & " blocks;" & C.Box'Image
                         & " block columns in its box:" & C.Its_Own'Image & " its ground," & C.Path'Image
                         & " a path's," & C.Other'Image & " another zone's," & C.Bare'Image & " nobody's ("
                         & Img (C.Front_Bare) & " of those within a metre of its front);" & V.Cells'Image & " places"
                         & (if Closed > 0 then " (" & Img (Closed) & " closed)" else ""));
            end if;
         end;
      end loop;
      if Storehouse > 0 then
         declare
            L : constant Store_Lie := Storehouse_Lie;
            Zy : constant Natural := Stockyard;
         begin
            Put_Line ("storehouse " & Said & ": walls" & L.W'Image & " by" & L.D'Image & " blocks ("
                      & Img (House_At (Storehouse).Blocks) & " blocks in its blueprint, "
                      & Img (House_At (Storehouse).Takes (Wood)) & " logs, " & Img (House_At (Storehouse).Takes (Straw))
                      & " sheaves, " & Img (House_At (Storehouse).Takes (Stone)) & " stones); before its front wall "
                      & Img (Float (L.Front_Least) * 0.25, 2) & " m of ground to its path's edge ("
                      & Img (Float (L.Front_Most) * 0.25, 2) & " m at the most along it); behind its back wall "
                      & Img (Float (L.Behind) * 0.25, 2) & " m of yard; beside its ends "
                      & Img (Float (L.Left) * 0.25, 2) & " m and " & Img (Float (L.Right) * 0.25, 2) & " m"
                      & (if Zy > 0 and then Zone_At (Zy).Placed
                         then (if L.Own_Front then "; it fronts its stockyard's own path"
                               else "; IT DOES NOT FRONT ITS STOCKYARD'S OWN PATH")
                         else "")
                      & ";" & L.Own_Out'Image & " block columns its own blocks stand in are not its stockyard's ground ("
                      & Img (L.Own_On_Path) & " of them a path's)");
         end;
      end if;
      if Cart.Here then
         Put_Line ("cart " & Said & ": " & (if Cart.Towed then "in tow, at " else "stands at ") & Img (Cart.At_P.X, 2) & ", "
                   & Img (Cart.At_P.Y, 2) & (if Cart_In_Stockpile then ", on a stockpile's ground" else "")
                   & (if Storehouse > 0 and then Cart_At_Storehouse then ", before the storehouse"
                      elsif Storehouse > 0 and then House_At (Storehouse).Phase = Standing
                        and then not Cart_Place_By_Storehouse
                      then "; no place by its storehouse's front takes it (the staging's rim is walled there, or"
                           & " something stands on it)"
                      else ""));
      end if;
      if not Any then
         Put_Line ("box " & Said & ": no zone was put down whole");
      else
         Put_Line ("box " & Said & ":" & Natural'Image (Box_Trees_Left)
                   & " trees or stumps still to take out of stockpiles");
      end if;
      if Camp_Is_Square then
         Put_Line ("square " & Said & ": its floor " & (if Camp_State.Floor_Z >= 0.0
                                                         then "to be level at " & Img (Camp_State.Floor_Z, 2) & " m"
                                                         else "left as it lies")
                   & "," & Camp_State.To_Dig'Image & " blocks to dig," & Camp_State.To_Fill'Image & " to fill,"
                   & Camp_State.Ground_Left'Image & " square metres of it still to make ready; its hearth "
                   & (if Camp_State.Built then "stands" else "not built (" & Img (Camp_State.Stones) & " stones, "
                                                             & Img (Camp_State.Frame) & " pieces of wood brought)")
                   & ";" & Natural'Image (Paths_To_Lay) & " m of path still to lay");
         declare
            W : constant Walls_View := Square_Walls_State;
         begin
            Put_Line ("square " & Said & ": its walls" & (if Square_Walls then "" else " (off)") & ":" & W.Stone_Left'Image
                      & " blocks of stone still to lay," & W.Dig_Left'Image & " of earth to dig off;" & W.Columns'Image
                      & " block columns of wall, ledge or stair, the highest bank" & W.Highest_B'Image & " blocks,"
                      & W.Lifts'Image & " lifts," & W.Stairs'Image & " stairs (" & Img (W.Too_High)
                      & " sides too high for one);" & W.Unready'Image & " edge columns with no path laid by them;"
                      & Natural'Image (Places_Lost) & " sleeping places by the fire given up");
            if W.Stairs > 0 or else W.Stairs_Lost > 0 then
               Put_Line ("square " & Said & ": its stairs" & (if Square_Stair_Corner then " (in a corner of the zone)" else "")
                         & ", along, against, left and right of its way: " & Stair_Word (W.Stair_At (1)) & ", "
                         & Stair_Word (W.Stair_At (2)) & ", " & Stair_Word (W.Stair_At (3)) & ", "
                         & Stair_Word (W.Stair_At (4)) & ";" & W.Stairs_Lost'Image
                         & " sides that would have one at their middle take none at either end," & W.Stairs_Shared'Image
                         & " sides' stairs are another side's in the corner they meet at;" & W.Stairs_By_Level'Image
                         & " stand in a corner where the path of the side met there comes in level");
            end if;
            if W.Outside then
               Put_Line ("square " & Said & ": its walls stand outside its floor: rings kept along, against, left and"
                         & " right of its way" & W.Strip (1)'Image & W.Strip (2)'Image & W.Strip (3)'Image
                         & W.Strip (4)'Image & " (its path as laid asks" & W.Need (1)'Image & W.Need (2)'Image
                         & W.Need (3)'Image & W.Need (4)'Image & ");" & W.Short'Image
                         & " columns of wall steeper for want of a ring," & W.Unwalled'Image
                         & " edge columns of floor left an earth bank," & W.Inside'Image
                         & " columns of floor of stone that are no stair's," & W.Capped'Image
                         & " columns of strip capped with stone at the path's level," & W.Strip_Zoned'Image
                         & " columns of strip that are a zone's ground");
            end if;
            if Walls_From >= 0 then
               Put_Line ("square " & Said & ": its walls were first wanted after "
                         & Img (Float (Walls_From) / 60.0, 1) & " game hours (" & Img (Walls_Most) & " blocks of stone), "
                         & (if Walls_Until >= 0
                            then "and nothing of them was left after " & Img (Float (Walls_Until) / 60.0, 1) & " game hours"
                            else "and are not finished"));
            end if;
         end;
      end if;
   end Put_Boxes;

   --  --square-path: at the end of the run (and of every square of a scan), how the path round the
   --  square steps: each of its four stretches gone along a quarter metre at a time (a slice: its
   --  block columns across the path's width there); the middle column's top of each against the
   --  floor's level, and the steps between one slice and the next: how many of 0, 1, 2, 3 and of 4
   --  blocks or more; of those of two or more, how many lie where a slice at the floor's level meets
   --  one that is not (the end of a levelled stretch), how many within the first or the last metre
   --  and a quarter of a stretch (where two sides' paths meet), and the rest; and the slices whose
   --  own columns lie two blocks or more apart (a bank through the path's width).
   Square_Path : Boolean := False;
   Paths_Backward : Boolean := False;   --  (--paths-backward: wherever the runner lays paths on the spot, the last
                                        --  stretch first and each stretch's last metre first)
   Walls_Between  : Boolean := False;   --  (--walls-between: a scan's squares have their walls built when half their
                                        --  path's metres are laid, then the rest of the path, then the rest of the
                                        --  walls: what is built is not to go by which came first)
   type Step_Count is array (0 .. 4) of Natural;
   type Path_Count is record
      Slices, Level   : Natural := 0;
      Along           : Step_Count := [others => 0];
      At_Level_End    : Step_Count := [others => 0];
      At_Corner       : Step_Count := [others => 0];
      Elsewhere       : Step_Count := [others => 0];
      Across          : Step_Count := [others => 0];
      Most            : Natural := 0;
      Squares, With_2 : Natural := 0;      --  (squares read, and those with a step of two blocks or more along a stretch)
      Sides, Sides_2  : Natural := 0;      --  (and sides)
      --  (steps of stone: quarter metres with a tread of stone, their columns of stone, and those of
      --  them not all stone or not all at one row)
      Stone_Slices, Stone_Columns, Stone_Part : Natural := 0;
      Barred : Castle.Colony.Step_Bars := [others => 0];     --  (of a scan: jumps at a level end left, by why)
   end record;
   --  (the ground by the square as it stands, in one number: every block column within eleven metres
   --  of its middle, its top against the floor's level and what that is of.  Two arms of a scan that
   --  made a square in different orders agree on it or do not.)
   --  (Part: 0 all of it; 1 its floor alone, the block columns within five and a half metres of its
   --  middle along and across its way, where its stairs are cut; 2 what lies beyond its path, more
   --  than seven and a quarter metres out.  The steps of stone change neither of the last two.)
   function Square_Ground_Hash (Part : Natural := 0; Aslant : Boolean := False) return Unsigned_64 is
      use Castle.Colony;
      R  : constant := 44;
      X0 : constant Integer := Integer (Float'Floor (Stake.X * 4.0 + 0.04));
      Y0 : constant Integer := Integer (Float'Floor (Stake.Y * 4.0 + 0.04));
      Level : constant Integer := Integer (Camp_State.Floor_Z * 4.0) - 1;
      Ex : constant Float := (if Aslant then 0.707_106_78 else 1.0);
      Ey : constant Float := (if Aslant then 0.707_106_78 else 0.0);
      H  : Unsigned_64 := 14_695_981_039_346_656_037;
      procedure Mix (V : Integer) is
      begin
         H := (H xor Unsigned_64'Mod (V + 1_000)) * 1_099_511_628_211;
      end Mix;
   begin
      for I in -R .. R - 1 loop
         for J in -R .. R - 1 loop
            declare
               Dx : constant Float := (Float (X0 + I) + 0.5) * 0.25 - Stake.X;
               Dy : constant Float := (Float (Y0 + J) + 0.5) * 0.25 - Stake.Y;
               Out_M : constant Float := Float'Max (abs (Dx * Ex + Dy * Ey), abs (Dy * Ex - Dx * Ey));
            begin
               if Part = 0 or else (Part = 1 and then Out_M < 5.5) or else (Part = 2 and then Out_M > 7.25) then
                  for Z in reverse Integer'Max (1, Level - 30) .. Level + 40 loop
                     declare
                        M : constant Material := Castle.World_Blocks.Block_At (X0 + I, Y0 + J, Z).Mat;
                     begin
                        if Class_Of (M) in Solid and then M not in Trunk | Crown then
                           Mix (Z - Level);
                           Mix (Material'Pos (M));
                           exit;
                        end if;
                     end;
                  end loop;
               end if;
            end;
         end loop;
      end loop;
      return H;
   end Square_Ground_Hash;
   procedure Read_Square_Path (C : in out Path_Count; Lines : Boolean; Said : String := "") is
      use Castle.Colony;
      Max_Slices : constant := 160;
      None : constant := Integer'First;
      type Row is array (0 .. Max_Slices - 1) of Integer;
      Mid, Lo, Hi, Cols : array (1 .. 4) of Row := [others => [others => None]];
      Count : array (1 .. 4) of Natural := [others => 0];
      procedure Note
        (Side : Positive; Slice, Slices : Natural; Columns : Positive; Lowest, Middle, Highest : Integer; Stone : Natural) is
      begin
         if Stone > 0 then
            C.Stone_Slices := C.Stone_Slices + 1;
            C.Stone_Columns := C.Stone_Columns + Stone;
            if Stone < Columns or else Lowest /= Highest then
               C.Stone_Part := C.Stone_Part + 1;
            end if;
         end if;
         if Slice < Max_Slices then
            Cols (Side) (Slice) := Columns;
            Mid (Side) (Slice) := Middle;
            Lo (Side) (Slice) := Lowest;
            Hi (Side) (Slice) := Highest;
            Count (Side) := Natural'Max (Count (Side), Natural'Min (Max_Slices, Slices));
         end if;
      end Note;
      function Code (D : Integer) return Character is
        (if D = 0 then '.' elsif D in 1 .. 9 then Character'Val (Character'Pos ('0') + D) elsif D > 9 then '+'
         elsif D in -9 .. -1 then Character'Val (Character'Pos ('a') - D - 1) else '-');
      Any_2 : Boolean := False;
   begin
      For_Square_Path_Slices (Note'Access);
      if (for all Sd in 1 .. 4 => Count (Sd) = 0) then
         return;
      end if;
      C.Squares := C.Squares + 1;
      for Sd in 1 .. 4 loop
         declare
            Line  : String (1 .. Natural'Max (1, Count (Sd))) := [others => ' '];
            Marks : String (1 .. Natural'Max (1, Count (Sd))) := [others => ' '];
            Side_2 : Boolean := False;
         begin
            if Count (Sd) > 0 then
               C.Sides := C.Sides + 1;
            end if;
            for K in 0 .. Count (Sd) - 1 loop
               if Mid (Sd) (K) /= None then
                  C.Slices := C.Slices + 1;
                  Line (K + 1) := Code (Mid (Sd) (K));
                  if Lo (Sd) (K) = 0 and then Hi (Sd) (K) = 0 then
                     C.Level := C.Level + 1;
                  end if;
                  C.Across (Integer'Min (4, Hi (Sd) (K) - Lo (Sd) (K))) := C.Across (Integer'Min (4, Hi (Sd) (K) - Lo (Sd) (K))) + 1;
                  if Hi (Sd) (K) - Lo (Sd) (K) >= 2 then
                     Marks (K + 1) := '|';
                  end if;
                  if K + 1 < Count (Sd) and then Mid (Sd) (K + 1) /= None then
                     declare
                        D  : constant Natural := abs (Mid (Sd) (K + 1) - Mid (Sd) (K));
                        Dn : constant Natural := Integer'Min (4, D);
                        Level_A : constant Boolean := Lo (Sd) (K) = 0 and then Hi (Sd) (K) = 0;
                        Level_B : constant Boolean := Lo (Sd) (K + 1) = 0 and then Hi (Sd) (K + 1) = 0;
                     begin
                        C.Along (Dn) := C.Along (Dn) + 1;
                        C.Most := Natural'Max (C.Most, D);
                        if D >= 2 then
                           Side_2 := True;
                           Marks (K + 1) := '^';
                           if Level_A /= Level_B then
                              C.At_Level_End (Dn) := C.At_Level_End (Dn) + 1;
                           elsif K < 5 or else K + 1 >= Count (Sd) - 5 then
                              C.At_Corner (Dn) := C.At_Corner (Dn) + 1;
                           else
                              C.Elsewhere (Dn) := C.Elsewhere (Dn) + 1;
                           end if;
                        end if;
                     end;
                  end if;
               end if;
            end loop;
            if Side_2 then
               C.Sides_2 := C.Sides_2 + 1;
               Any_2 := True;
            end if;
            if Lines and then Count (Sd) > 0 then
               Put_Line ("square path" & Said & ", side" & Sd'Image & ": " & Line);
               if Side_2 or else (for some Ch of Marks => Ch = '|') then
                  Put_Line ("square path" & Said & ", side" & Sd'Image & ": " & Marks
                            & "  (^: two blocks or more to the next quarter metre; |: across this one)");
                  for K in 0 .. Count (Sd) - 2 loop
                     if Marks (K + 1) = '^' then
                        Put_Line ("square path" & Said & ", side" & Sd'Image & ": quarter metre" & K'Image & " lies"
                                  & Lo (Sd) (K)'Image & " to" & Hi (Sd) (K)'Image & " (" & Img (Cols (Sd) (K)) & " columns), the next"
                                  & Lo (Sd) (K + 1)'Image & " to" & Hi (Sd) (K + 1)'Image & " (" & Img (Cols (Sd) (K + 1))
                                  & " columns)");
                     end if;
                  end loop;
               end if;
            end if;
         end;
      end loop;
      if Any_2 then
         C.With_2 := C.With_2 + 1;
      end if;
   end Read_Square_Path;
   function Path_Words (C : Path_Count) return String is
      function Of_Steps (S : Step_Count) return String is
        (S (2)'Image & " of two blocks," & S (3)'Image & " of three," & S (4)'Image & " of four or more");
   begin
      return C.Squares'Image & " squares," & C.Sides'Image & " sides," & C.Slices'Image & " quarter metres of path read ("
        & Img (C.Level) & " of them all at the floor's level); from one quarter metre to the next, no step" & C.Along (0)'Image
        & ", a block" & C.Along (1)'Image & ", two blocks" & C.Along (2)'Image & ", three" & C.Along (3)'Image
        & ", four or more" & C.Along (4)'Image & " (the most" & C.Most'Image & "); steps of two blocks or more are on"
        & C.Sides_2'Image & " sides of" & C.With_2'Image & " squares: where a quarter metre at the floor's level meets one"
        & " that is not:" & Of_Steps (C.At_Level_End) & "; within a metre and a quarter of a stretch's end, where two"
        & " sides' paths meet:" & Of_Steps (C.At_Corner) & "; elsewhere along a side:" & Of_Steps (C.Elsewhere)
        & "; quarter metres whose own columns lie two blocks or more apart across the path:"
        & Natural'Image (C.Across (2) + C.Across (3) + C.Across (4))
        & "; quarter metres with a tread of stone:" & C.Stone_Slices'Image & " (" & Img (C.Stone_Columns)
        & " block columns of stone; " & Img (C.Stone_Part) & " of them not all stone or not all at one row)"
        & "; steps of two blocks or more at a levelled stretch's end left as they are: where two sides' paths cross"
        & C.Barred (Castle.Colony.At_Crossing)'Image & ", before a stair" & C.Barred (Castle.Colony.Before_Stair)'Image
        & ", their columns too far apart for one row" & C.Barred (Castle.Colony.Uneven)'Image
        & ", a column with no laid path to read" & C.Barred (Castle.Colony.Unread)'Image;
   end Path_Words;

   --  --wall-map: at the end of the run, the square's walls as planned and as they stand, a character
   --  a block column, north at the top: the row each column's top is to be brought to and the row it
   --  is at, against its floor's level (. level, 1 to 9 and + over it, a to i and - under it; a blank:
   --  not its floor; outside the floor, as it lies), and how many rows of each are to be stone.
   Wall_Map : Boolean := False;
   Walls_Now : Boolean := False;    --  (--walls-now: its camp, its paths and its walls built on the spot before the run)
   Camp_Now  : Boolean := False;    --  (--camp-now: its camp and its paths so, its walls left to the band)
   procedure Put_Wall_Map is
      use Castle.Colony;
      R : constant := 40;
      X0 : constant Integer := Integer (Float'Floor (Stake.X * 4.0 + 0.04));
      Y0 : constant Integer := Integer (Float'Floor (Stake.Y * 4.0 + 0.04));
      type Grid is array (-R .. R - 1, -R .. R - 1) of Integer;
      None : constant := Integer'First;
      Top, Stone : Grid := [others => [others => None]];
      Level : Integer := -1;
      procedure Note (Bx, By, T, S, L : Integer) is
      begin
         Level := L;
         if Bx - X0 in Grid'Range (1) and then By - Y0 in Grid'Range (2) then
            Top (Bx - X0, By - Y0) := T;
            Stone (Bx - X0, By - Y0) := S;
         end if;
      end Note;
      function Code (D : Integer) return Character is
        (if D = 0 then '.' elsif D in 1 .. 9 then Character'Val (Character'Pos ('0') + D) elsif D > 9 then '+'
         elsif D in -9 .. -1 then Character'Val (Character'Pos ('a') - D - 1) else '-');
      function Ground (Bx, By : Integer) return Integer is
      begin
         for Z in reverse Integer'Max (1, Level - 30) .. Level + 30 loop
            if Castle.Blocks.Class_Of (Castle.World_Blocks.Block_At (Bx, By, Z).Mat) in Castle.Blocks.Solid
              and then Castle.World_Blocks.Block_At (Bx, By, Z).Mat not in Castle.Blocks.Trunk | Castle.Blocks.Crown
            then
               return Z;
            end if;
         end loop;
         return None;
      end Ground;
   begin
      if not Has_Stake or else not Camp_Is_Square then
         Put_Line ("wall map: this colony was not founded on a square");
         return;
      end if;
      For_Wall_Plan (Note'Access);
      if Level < 0 then
         Put_Line ("wall map: no walls are planned (its hearth does not stand, or they are off)");
         return;
      end if;
      Put_Line ("wall map: the floor's level is row" & Level'Image & "; planned | as it stands | rows of stone planned");
      for J in reverse Grid'Range (2) loop
         declare
            A, B, C : String (1 .. 2 * R) := [others => ' '];
         begin
            for I in Grid'Range (1) loop
               declare
                  G : constant Integer := Ground (X0 + I, Y0 + J);
               begin
                  if Top (I, J) /= None then
                     A (I + R + 1) := Code (Top (I, J) - Level);
                     C (I + R + 1) := (if Stone (I, J) > Top (I, J) then '.' else Code (Top (I, J) - Stone (I, J) + 1));
                  end if;
                  if G /= None then
                     B (I + R + 1) :=
                       (if Castle.World_Blocks.Block_At (X0 + I, Y0 + J, G).Mat in Castle.Blocks.Fieldstone and then G = Level
                        then '=' else Code (G - Level));
                  end if;
               end;
            end loop;
            Put_Line (A & " | " & B & " | " & C);
         end;
      end loop;
   end Put_Wall_Map;

   --  --yard-pits: at the end of the run (and of each stockyard built on the spot in the census,
   --  --yard-built), every half metre of the stockyard's ground and two metres round it: the spots
   --  that can be got to from the fire, and those of them that cannot be got back from (a pit: a cut a
   --  serf drops into and cannot climb out of); and the way from the fire to the middle of the
   --  storehouse's floor and back, in metres (under 0: none).
   Yard_Pits_On : Boolean := False;
   procedure Yard_Pits (Spots, Pits : out Natural; In_M, Out_M : out Float; Where : Boolean := False) is
      use Castle.Colony;
      X_Lo, Y_Lo : Integer := Integer'Last;
      X_Hi, Y_Hi : Integer := Integer'First;
      procedure Bounds (Bx, By, Top, Stone, Floor : Integer; Way, Stair : Boolean) is
         pragma Unreferenced (Top, Stone, Floor, Way, Stair);
      begin
         X_Lo := Integer'Min (X_Lo, Bx);  X_Hi := Integer'Max (X_Hi, Bx);
         Y_Lo := Integer'Min (Y_Lo, By);  Y_Hi := Integer'Max (Y_Hi, By);
      end Bounds;
      Px, Py : Float;
   begin
      Spots := 0;
      Pits := 0;
      In_M := -1.0;
      Out_M := -1.0;
      if Storehouse = 0 or else not Has_Stake then
         return;
      end if;
      For_Yard_Plan (Bounds'Access);
      Px := Float (X_Lo) * 0.25 - 2.0 + 0.125;
      while Px <= Float (X_Hi + 1) * 0.25 + 2.0 loop
         Py := Float (Y_Lo) * 0.25 - 2.0 + 0.125;
         while Py <= Float (Y_Hi + 1) * 0.25 + 2.0 loop
            declare
               Pz : constant Float := Castle.Nav.Surface_Z (Px, Py);
            begin
               if Pz >= 0.0 and then Castle.Nav."=" (Castle.Nav.Plan (Stake, (Px, Py, Pz)).Result, Castle.Nav.Found) then
                  Spots := Spots + 1;
                  if not Castle.Nav."=" (Castle.Nav.Plan ((Px, Py, Pz), Stake).Result, Castle.Nav.Found) then
                     Pits := Pits + 1;
                     if Where and then Pits <= 8 then
                        Put_Line ("yard pits: a pit at " & Img (Px, 2) & ", " & Img (Py, 2) & ", " & Img (Pz, 2));
                     end if;
                  end if;
               end if;
            end;
            Py := Py + 0.5;
         end loop;
         Px := Px + 0.5;
      end loop;
      declare
         V : constant House_View := House_At (Storehouse);
         C : constant Lot_Corners := (if V.Yard_Turned then V.Drawn else V.Corner);
         Mx : constant Float := (C (1).X + C (2).X + C (3).X + C (4).X) / 4.0;
         My : constant Float := (C (1).Y + C (2).Y + C (3).Y + C (4).Y) / 4.0;
         Mz : constant Float := C (1).Z;          --  (its floor: the highest floor there is its roof)
      begin
         if Mz >= 0.0 then
            declare
               To   : constant Castle.Nav.Route := Castle.Nav.Plan (Stake, (Mx, My, Mz));
               Back : constant Castle.Nav.Route := Castle.Nav.Plan ((Mx, My, Mz), Stake);
            begin
               if Castle.Nav."=" (To.Result, Castle.Nav.Found) then
                  In_M := Castle.Nav.Length (To);
               end if;
               if Castle.Nav."=" (Back.Result, Castle.Nav.Found) then
                  Out_M := Castle.Nav.Length (Back);
               end if;
            end;
         end if;
      end;
   end Yard_Pits;

   --  --yard-map: at the end of the run, the stockyard's ground as planned and as it stands, a character
   --  a block column, north at the top, as the wall map's: the row each column's top is to be brought
   --  to against the floor's (. level, 1 to 9 and + over it, a to i and - under it; a blank: not its
   --  ground); the same as it stands (with the land round it, three columns out; # the storehouse's
   --  own blocks or anything else of wood, daub or thatch standing there); and how many rows of each
   --  are to be stone (. none; S: a step of its stair).
   Yard_Map : Boolean := False;
   Yard_Now : Boolean := False;     --  (--yard-now: at the end of the run the storehouse that is begun is raised on the
                                    --  spot, its ground made, before anything is printed of it)
   Yard_Built : Boolean := False;   --  (--yard-built: with --yard-census --yard-walls, every square is made on the spot,
                                    --  its path laid and its banks walled, before the stockyard is held against it (as
                                    --  a band three days in has it); and each stockyard with a stair, or its way in at
                                    --  an end of its front, is built on the spot and scanned for pits: Yard_Pits)
   procedure Put_Yard_Map is
      use Castle.Colony;
      None : constant := Integer'First;
      X_Lo, Y_Lo : Integer := Integer'Last;
      X_Hi, Y_Hi : Integer := Integer'First;
      Floor_Row : Integer := -1;
      procedure Bounds (Bx, By, Top, Stone, Floor : Integer; Way, Stair : Boolean) is
         pragma Unreferenced (Top, Stone, Way, Stair);
      begin
         X_Lo := Integer'Min (X_Lo, Bx);  X_Hi := Integer'Max (X_Hi, Bx);
         Y_Lo := Integer'Min (Y_Lo, By);  Y_Hi := Integer'Max (Y_Hi, By);
         Floor_Row := Floor;
      end Bounds;
      function Code (D : Integer) return Character is
        (if D = 0 then '.' elsif D in 1 .. 9 then Character'Val (Character'Pos ('0') + D) elsif D > 9 then '+'
         elsif D in -9 .. -1 then Character'Val (Character'Pos ('a') - D - 1) else '-');
   begin
      if Storehouse = 0 then
         Put_Line ("yard map: no storehouse is begun");
         return;
      end if;
      For_Yard_Plan (Bounds'Access);
      if Floor_Row < 0 then
         return;
      end if;
      X_Lo := X_Lo - 3;  X_Hi := X_Hi + 3;  Y_Lo := Y_Lo - 3;  Y_Hi := Y_Hi + 3;
      declare
         type Grid is array (X_Lo .. X_Hi, Y_Lo .. Y_Hi) of Integer;
         type Flags is array (X_Lo .. X_Hi, Y_Lo .. Y_Hi) of Boolean;
         Top, Stone : Grid := [others => [others => None]];
         Step : Flags := [others => [others => False]];
         procedure Note (Bx, By, T, S, Floor : Integer; Way, Stair : Boolean) is
            pragma Unreferenced (Floor, Way);
         begin
            Top (Bx, By) := T;
            Stone (Bx, By) := S;
            Step (Bx, By) := Stair;
         end Note;
         function Ground (Bx, By : Integer) return Integer is
         begin
            for Z in reverse Integer'Max (1, Floor_Row - 30) .. Floor_Row + 30 loop
               if Castle.Blocks.Class_Of (Castle.World_Blocks.Block_At (Bx, By, Z).Mat) in Castle.Blocks.Solid
                 and then Castle.World_Blocks.Block_At (Bx, By, Z).Mat not in Castle.Blocks.Trunk | Castle.Blocks.Crown
               then
                  return Z;
               end if;
            end loop;
            return None;
         end Ground;
      begin
         For_Yard_Plan (Note'Access);
         Put_Line ("yard map: the floor's top is row" & Floor_Row'Image & "; block columns" & X_Lo'Image & " to" & X_Hi'Image
                   & " east, north at the top from" & Y_Hi'Image & " down to" & Y_Lo'Image
                   & "; planned | as it stands | rows of stone planned");
         for By in reverse Y_Lo .. Y_Hi loop
            declare
               N : constant Natural := X_Hi - X_Lo + 1;
               A, B, C : String (1 .. N) := [others => ' '];
            begin
               for Bx in X_Lo .. X_Hi loop
                  declare
                     K : constant Positive := Bx - X_Lo + 1;
                     G : constant Integer := Ground (Bx, By);
                  begin
                     if Top (Bx, By) /= None then
                        A (K) := Code (Top (Bx, By) - Floor_Row);
                        C (K) := (if Step (Bx, By) then 'S' elsif Stone (Bx, By) > Top (Bx, By) then '.'
                                  else Code (Top (Bx, By) - Stone (Bx, By) + 1));
                     end if;
                     if G /= None then
                        B (K) :=
                          (if Castle.World_Blocks.Block_At (Bx, By, G).Mat
                             in Castle.Blocks.Log | Castle.Blocks.Plank | Castle.Blocks.Daub | Castle.Blocks.Thatch
                               | Castle.Blocks.Shingle
                           then '#'
                           elsif Castle.World_Blocks.Block_At (Bx, By, G).Mat in Castle.Blocks.Fieldstone and then G = Floor_Row
                           then '=' else Code (G - Floor_Row));
                     end if;
                  end;
               end loop;
               Put_Line (A & " | " & B & " | " & C);
            end;
         end loop;
      end;
   end Put_Yard_Map;

   --  --square-census R STEP: before the colony is founded, the square it could be founded on (John,
   --  2026-11-20: "Let's merge the homestake and the campfire ... a 10x10 area") tried with its middle
   --  every STEP metres within R of the stake's place, squarely and aslant: how many are taken, how
   --  many refused and why, and of those refused for their ground alone how far off its middle's it lies.
   Census_R    : Float := 0.0;
   Census_Step : Float := 4.0;
   procedure Square_Census is
      use Castle.Colony;
      N    : constant Integer := Integer (Float'Floor (Census_R / Census_Step));
      type Tally is record
         Tried, Taken, No_Ground, Standing, Water, Uneven, Cut_Off : Natural := 0;
         Off_1, Off_15, Off_2, Off_3, Off_More : Natural := 0;     --  (the uneven ones: off its middle's by up to ...)
      end record;
      T : array (0 .. 1) of Tally;
   begin
      for Way in 0 .. 1 loop
         for I in -N .. N loop
            for J in -N .. N loop
               declare
                  X : constant Float := Scn.Stake_X + Float (I) * Census_Step;
                  Y : constant Float := Scn.Stake_Y + Float (J) * Census_Step;
                  Z : constant Float := Castle.Nav.Surface_Z (X, Y);
               begin
                  if Float (I * I + J * J) * Census_Step ** 2 <= Census_R ** 2 then
                     T (Way).Tried := T (Way).Tried + 1;
                     if Z < 0.0 then
                        T (Way).No_Ground := T (Way).No_Ground + 1;
                     else
                        declare
                           P : constant Square_Plan := Plan_Square ((X, Y, Z), Way);
                           R : constant String := Square_Refusal;
                        begin
                           if P.Ok then
                              T (Way).Taken := T (Way).Taken + 1;
                           elsif (R'Length >= 15 and then R (R'First .. R'First + 14) = "something stand")
                             or else (R'Length >= 16 and then R (R'First .. R'First + 15) = "a boulder stands")
                           then
                              T (Way).Standing := T (Way).Standing + 1;
                           elsif R'Length >= 14 and then R (R'First .. R'First + 13) = "there is water" then
                              T (Way).Water := T (Way).Water + 1;
                           elsif R'Length >= 9 and then R (R'First .. R'First + 8) = "its floor" then
                              T (Way).Cut_Off := T (Way).Cut_Off + 1;
                           elsif R'Length >= 10 and then R (R'First .. R'First + 9) = "the ground" then
                              T (Way).Uneven := T (Way).Uneven + 1;
                              if Square_Off_M <= 1.0 then T (Way).Off_1 := T (Way).Off_1 + 1;
                              elsif Square_Off_M <= 1.5 then T (Way).Off_15 := T (Way).Off_15 + 1;
                              elsif Square_Off_M <= 2.0 then T (Way).Off_2 := T (Way).Off_2 + 1;
                              elsif Square_Off_M <= 3.0 then T (Way).Off_3 := T (Way).Off_3 + 1;
                              else T (Way).Off_More := T (Way).Off_More + 1;
                              end if;
                           else
                              T (Way).No_Ground := T (Way).No_Ground + 1;
                           end if;
                        end;
                     end if;
                  end if;
               end;
            end loop;
         end loop;
         Put_Line ("square census, " & (if Way = 0 then "squarely" else "aslant") & ", within " & Img (Census_R, 0)
                   & " m of " & Img (Scn.Stake_X, 0) & ", " & Img (Scn.Stake_Y, 0) & " every " & Img (Census_Step, 1)
                   & " m:" & T (Way).Tried'Image & " tried," & T (Way).Taken'Image & " taken;"
                   & T (Way).Standing'Image & " refused for something standing," & T (Way).Water'Image & " for water,"
                   & T (Way).Uneven'Image & " for the ground alone (off its middle's by up to 1.5 m"
                   & Natural'Image (T (Way).Off_1 + T (Way).Off_15) & ", 2 m" & T (Way).Off_2'Image & ", 3 m"
                   & T (Way).Off_3'Image & ", more" & T (Way).Off_More'Image & ")," & T (Way).Cut_Off'Image
                   & " for a floor that would lie cut off," & T (Way).No_Ground'Image & " for no ground");
      end loop;
   end Square_Census;

   --  --square-scan R STEP: a colony founded on a square at every place of
   --  that grid that takes one (squarely and aslant by turns), its floor and
   --  its path made on the spot, and the ground round it looked over: every
   --  spot within 9 m of its middle that can be got to from the fire, and
   --  whether the fire can be got to from it (one that cannot is a pit); and
   --  whether the fire can be got to from the land 14 m off on each side.
   --  Each is then given up for the next (the ground it made stays: STEP is
   --  to be 16 m or more, so that no two touch).
   Scan_R    : Float := 0.0;
   Scan_Step : Float := 16.0;
   Scan_List : Boolean := False;       --  (--square-scan-list: a line for every square, not only the faulty)
   --  --square-pits: at the end of a run, the same look round the square this colony was founded on
   --  (a save's, or one that the band has made): the spots within 9 m of its middle that can be got to
   --  from its fire and cannot be got back from, the trees still to fell on it, the trees standing on it.
   Square_Pits : Boolean := False;
   --  The way between the middle of side D's path (1 .. 4: along, against, left and right of the
   --  square's way) and the fire, there and back, in metres: a bank is gone round, a stair gone up or
   --  down.  Where the walking map has no floor at the very middle of the path (a cell of it cut by
   --  the foot of a wall aslant has none), from the nearest spot of the path that has one, tried a
   --  quarter metre at a time along the side, 3 m either way (Along: how far).  Under 0: no way to
   --  the fire from there (-1), none back (-2), no floor on the path within that (-3).
   function Side_Way_M (D : Positive; Along : out Float) return Float is
      use Castle.Colony;
      Mid  : constant Castle.Math.Vec3 := Square_Path_Middle (D);
      Next : constant Castle.Math.Vec3 := Square_Path_Middle ((if D <= 2 then 3 else 1));
      --  (along side D: the direction from the square's middle to the middle of a side beside it)
      Len  : constant Float := Ada.Numerics.Elementary_Functions.Sqrt ((Next.X - Stake.X) ** 2 + (Next.Y - Stake.Y) ** 2);
      Ax   : constant Float := (if Len > 0.0 then (Next.X - Stake.X) / Len else 0.0);
      Ay   : constant Float := (if Len > 0.0 then (Next.Y - Stake.Y) / Len else 0.0);
      function Length (R : Castle.Nav.Route) return Float is
         M : Float := 0.0;
      begin
         for K in 2 .. R.N loop
            M := M + Ada.Numerics.Elementary_Functions.Sqrt
              ((R.Pts (K).P.X - R.Pts (K - 1).P.X) ** 2 + (R.Pts (K).P.Y - R.Pts (K - 1).P.Y) ** 2);
         end loop;
         return M;
      end Length;
   begin
      Along := 0.0;
      for T in 0 .. 24 loop
         declare
            Off : constant Float := Float ((T + 1) / 2) * 0.25 * (if T mod 2 = 0 then 1.0 else -1.0);
            X   : constant Float := Mid.X + Off * Ax;
            Y   : constant Float := Mid.Y + Off * Ay;
            Z   : constant Float := Castle.Nav.Surface_Z (X, Y);
         begin
            if Z >= 0.0 then
               declare
                  To_Fire : constant Castle.Nav.Route := Castle.Nav.Plan ((X, Y, Z), Stake);
                  Back    : constant Castle.Nav.Route := Castle.Nav.Plan (Stake, (X, Y, Z));
               begin
                  Along := Off;
                  if not Castle.Nav."=" (To_Fire.Result, Castle.Nav.Found) then
                     return -1.0;
                  elsif not Castle.Nav."=" (Back.Result, Castle.Nav.Found) then
                     return -2.0;
                  end if;
                  return Length (To_Fire) + Length (Back);
               end;
            end if;
         end;
      end loop;
      return -3.0;
   end Side_Way_M;
   function Way_Word (D : Positive) return String is
      Along : Float;
      M     : constant Float := Side_Way_M (D, Along);
   begin
      return (if M >= 0.0 then Img (M, 1) elsif M > -1.5 then "none to the fire" elsif M > -2.5 then "none back"
              else "none (no floor on its path within 3 m of its middle)")
        & (if Along /= 0.0 and then M > -2.5 then " (" & Img (Along, 2) & " m along)" else "");
   end Way_Word;
   procedure Put_Square_Pits is
      use Castle.Colony;
      Spots, Pits, Standing : Natural := 0;
      Px, Py : Float;
   begin
      if not Has_Stake or else not Camp_Is_Square then
         Put_Line ("square pits: this colony was not founded on a square");
         return;
      end if;
      Px := Stake.X - 9.0;
      while Px <= Stake.X + 9.0 loop
         Py := Stake.Y - 9.0;
         while Py <= Stake.Y + 9.0 loop
            declare
               Pz : constant Float := Castle.Nav.Surface_Z (Px, Py);
            begin
               if Pz >= 0.0 and then Castle.Nav."=" (Castle.Nav.Plan (Stake, (Px, Py, Pz)).Result, Castle.Nav.Found) then
                  Spots := Spots + 1;
                  if not Castle.Nav."=" (Castle.Nav.Plan ((Px, Py, Pz), Stake).Result, Castle.Nav.Found) then
                     Pits := Pits + 1;
                     if Pits <= 8 then                       --  (where: the first eight, off its middle and its fire's level)
                        Put_Line ("square pits: a pit" & Img (Px - Stake.X, 2) & " m east and" & Img (Py - Stake.Y, 2)
                                  & " m north of its middle, " & Img (Pz - Stake.Z, 2) & " m over its fire's ground");
                     end if;
                  end if;
               end if;
            end;
            Py := Py + 0.25;
         end loop;
         Px := Px + 0.25;
      end loop;
      for K in 1 .. Tree_Count loop
         if not Tree_Down (K) and then abs (Tree_Base (K).X - Stake.X) < 5.0 and then abs (Tree_Base (K).Y - Stake.Y) < 5.0 then
            Standing := Standing + 1;
         end if;
      end loop;
      Put_Line ("square pits: of" & Spots'Image & " spots within 9 m of its middle that can be got to from its fire,"
                & Pits'Image & " cannot be got back from;" & Standing'Image & " trees standing within 5 m of its middle"
                & " east and north," & Square_Trees_Left'Image & " still to fell for it");
      Put_Line ("square ways: from the middle of the path along, against, left and right of its way to the fire and"
                & " back, m: " & Way_Word (1) & ", " & Way_Word (2) & ", " & Way_Word (3) & ", " & Way_Word (4));
   end Put_Square_Pits;
   --  --yard-census (with --square-scan R STEP): at every place of the scan's grid that takes a
   --  square, a stockyard put down whole against each of its four sides in turn, along that side's
   --  own path, as the player would hold it (Plan_Box, then Place_Box): how many are taken, why
   --  the others are refused, and whether what the plan said the click then did (it must).  With
   --  --yard-census-corners M: zoned between two corners instead, M metres a side (the scripts'
   --  way, of any size from 15 to 25: for comparing a size with another).
   Yard_Census   : Boolean := False;
   Yard_Census_M : Natural := 0;
   Yard_Walls_Census : Boolean := False;     --  --yard-walls: with --yard-census, where each taken stockyard's stone stands
   procedure Rebuild_Dirty;
   procedure Land_Back;
   procedure Yard_Scan is
      use Castle.Colony;
      N : constant Integer := Integer (Float'Floor (Scan_R / Scan_Step));
      Squares, Tried, Taken, Disagree, Not_Own, Unfounded : Natural := 0;
      --  (what the plan costs, which the tool's ghost asks every frame: the stockyard's, with its storehouse
      --  tried on the planned ground, and a stockpile's held along the same path, for comparing)
      Yard_S, Pile_S : array (0 .. 1) of Duration := [others => 0.0];
      Yard_Most, Pile_Most : array (0 .. 1) of Duration := [others => 0.0];
      Plans : array (0 .. 1) of Natural := [others => 0];
      Piles_Taken : Natural := 0;
      By_Way : array (0 .. 1, Boolean) of Natural := [others => [others => 0]];
      type Why is (No_Store, No_Ground, Over_Something, No_Path_Ground, Other);
      --  (where each taken stockyard's own stone stands, its storehouse begun: Stockyard_Walls)
      Begun, Walled, Front_Walled, No_Wall : Natural := 0;
      Rim_Sum, Stone_Sum, Back_Sum, Up_Sum, Blocks_Sum, Inner_Sum : Natural := 0;
      Way_Sum, Clear_Sum, Fenced_Sum, Goods_Sum, With_Goods : Natural := 0;
      --  (its only stair, the flight to its storehouse's door: stockyards with one, its columns, the
      --  rim's stone that is a step of it, the stockyards whose path lies a block or less off the floor
      --  and so have none, the most blocks between path and floor)
      With_Stair, Stair_Sum, Way_Stair_Sum, Rise_Small, Rise_Most : Natural := 0;
      type By_Height is array (0 .. 4) of Natural;        --  (the tallest wall: none, to 2 blocks, to 4, to 8, over)
      Tallest : By_Height := [others => 0];
      Sides_Walled : array (1 .. 4) of Natural := [others => 0];
      Most_Stone, Most_High : Natural := 0;
      --  (how the land lies along the front of each: at its two ends, the front corners of the zone,
      --  and at the middle of its storehouse's front, where its way in is: Stockyard_Front.  Of those
      --  with a stair, what its two ends are: level with the floor, a bank a stair can stand against,
      --  or higher)
      type End_Class is (Level, Takes, Over, Unread);
      Ends_Staired, Ends_All : array (End_Class, End_Class) of Natural := [others => [others => 0]];
      Far_Steps : array (0 .. 9) of Natural := [others => 0];    --  (the bank at the end away from a level end; 9: over 8)
      Both_Steps : array (0 .. 9) of Natural := [others => 0];   --  (both ends banked: the lower bank)
      Both_Same_Way, Both_Other_Way, Spread_2, Ends_Read : Natural := 0;
      --  (where each one's way in is: the middle of its storehouse's front, the low end of its front,
      --  the high end; those of them with a stair; the stairs by their steps, 9: over eight)
      Way_At, Way_Staired : array (0 .. 2) of Natural := [others => 0];
      All_Blocks_Sum : Natural := 0;       --  (blocks of stone in all their ground, on the rim or not)
      --  (built on the spot, --yard-built: how many, the spots scanned, those that are pits, the stockyards
      --  with one, those with no way from the fire into the storehouse or back, and those ways)
      Built_N, Built_Spots, Built_Pits, Built_With_Pits, Built_No_Way, Built_Not_Standing, Built_Cart : Natural := 0;
      Built_Way_M, Built_Way_Most : Float := 0.0;
      Stair_By_Steps : array (0 .. 9) of Natural := [others => 0];
      Mid_Banked_No_Stair, Stair_By_Level_End : Natural := 0;
      Deep_Least : Natural := Natural'Last;
      Deep_Most  : Natural := 0;
      function Class_Of (Bk : Front_Bank) return End_Class is
        (if not Bk.Read then Unread elsif abs Bk.Mid <= 1 then Level elsif abs Bk.Mid <= 8 then Takes else Over);
      procedure Count_Walls (Said : String) is
         W : Yard_Walls;
         Any : Boolean := False;
         High, Cols : Natural := 0;
      begin
         if Yard_Built then
            Build_Paths_Now (Backward => Paths_Backward);                      --  (the stockyard's own stretch of path laid before its storehouse is begun)
            Rebuild_Dirty;
         end if;
         --  (the second morning come, and the storehouse asked for: begun on the stockyard at once)
         Advance (1.0, 20.0 * 24.0 + 7.0);
         Advance (1.0, 22.0 * 24.0 + 8.0);
         if Storehouse = 0 then
            return;
         end if;
         Begun := Begun + 1;
         W := Stockyard_Walls;
         Inner_Sum := Inner_Sum + W.Inner;
         Way_Sum := Way_Sum + W.Way;
         Clear_Sum := Clear_Sum + W.Clear;
         Fenced_Sum := Fenced_Sum + W.Fenced;
         Goods_Sum := Goods_Sum + W.Goods;
         if W.Goods > 0 then
            With_Goods := With_Goods + 1;
         end if;
         declare
            Fr : constant Yard_Front := Stockyard_Front;
            Lo : constant End_Class := Class_Of (Fr (Low_End));
            Hi : constant End_Class := Class_Of (Fr (High_End));
            function Word (Bk : Front_Bank) return String is
              (if not Bk.Read then "not read"
               else Img (Bk.Mid) & " (" & Img (Bk.Least) & " to " & Img (Bk.Most) & ", its own rim " & Img (Bk.Rim_Least)
                    & " to " & Img (Bk.Rim_Most) & ", " & Img (Bk.Deep) & " deep)");
         begin
            Ends_All (Lo, Hi) := Ends_All (Lo, Hi) + 1;
            Way_At (W.Way_End) := Way_At (W.Way_End) + 1;
            --  (every one begun, for comparing two rules side by side: the floor's own row, the path
            --  against it at the two ends and the middle, its way, its stone)
            Put_Line ("yard floor: " & Said & ": row" & W.Floor_Row'Image
                      & "; path over it: low end " & (if Fr (Low_End).Read then Img (Fr (Low_End).Mid) else "none")
                      & ", middle " & (if Fr (Front_Middle).Read then Img (Fr (Front_Middle).Mid) else "none")
                      & ", high end " & (if Fr (High_End).Read then Img (Fr (High_End).Mid) else "none")
                      & "; way" & W.Way_End'Image & "; steps" & Natural'Image (if W.Stair > 0 then abs W.Rise else 0)
                      & "; stone" & W.All_Blocks'Image);
            All_Blocks_Sum := All_Blocks_Sum + W.All_Blocks;
            if W.Stair > 0 then
               Way_Staired (W.Way_End) := Way_Staired (W.Way_End) + 1;
               Stair_By_Steps (Integer'Min (9, abs W.Rise)) := Stair_By_Steps (Integer'Min (9, abs W.Rise)) + 1;
               --  (a stair at one end while the path comes in level at the other)
               if (W.Way_End = 1 and then Hi = Level) or else (W.Way_End = 2 and then Lo = Level) then
                  Stair_By_Level_End := Stair_By_Level_End + 1;
               end if;
            elsif Fr (Front_Middle).Read and then abs Fr (Front_Middle).Mid > 1 then
               Mid_Banked_No_Stair := Mid_Banked_No_Stair + 1;
            end if;
            if W.Stair > 0 or else W.Way_End > 0 or else (Fr (Front_Middle).Read and then abs Fr (Front_Middle).Mid > 1) then
               --  (a stockyard whose path lies more than a block off its floor at the middle of its front:
               --  the ones that had a stair there)
               Ends_Staired (Lo, Hi) := Ends_Staired (Lo, Hi) + 1;
               for Spot in Front_Spot loop
                  if Fr (Spot).Read and then Spot /= Front_Middle then
                     Ends_Read := Ends_Read + 1;
                     if Fr (Spot).Most - Fr (Spot).Least >= 2 then
                        Spread_2 := Spread_2 + 1;
                     end if;
                     Deep_Least := Natural'Min (Deep_Least, Fr (Spot).Deep);
                     Deep_Most := Natural'Max (Deep_Most, Fr (Spot).Deep);
                  end if;
               end loop;
               if Lo = Level and then Hi /= Level and then Hi /= Unread then
                  Far_Steps (Integer'Min (9, abs Fr (High_End).Mid)) := Far_Steps (Integer'Min (9, abs Fr (High_End).Mid)) + 1;
               elsif Hi = Level and then Lo /= Level and then Lo /= Unread then
                  Far_Steps (Integer'Min (9, abs Fr (Low_End).Mid)) := Far_Steps (Integer'Min (9, abs Fr (Low_End).Mid)) + 1;
               elsif Lo in Takes | Over and then Hi in Takes | Over then
                  declare
                     Least : constant Natural := Integer'Min (abs Fr (Low_End).Mid, abs Fr (High_End).Mid);
                  begin
                     Both_Steps (Integer'Min (9, Least)) := Both_Steps (Integer'Min (9, Least)) + 1;
                     if (Fr (Low_End).Mid > 0) = (Fr (High_End).Mid > 0) then
                        Both_Same_Way := Both_Same_Way + 1;
                     else
                        Both_Other_Way := Both_Other_Way + 1;
                     end if;
                  end;
               end if;
               Put_Line ("yard front: " & Said & ": the path, in blocks over the floor: at its front's low end "
                         & Word (Fr (Low_End)) & ", at the middle of the storehouse's front " & Word (Fr (Front_Middle))
                         & ", at its high end " & Word (Fr (High_End)) & "; its way in "
                         & (case W.Way_End is when 0 => "at the middle of the storehouse's front",
                                               when 1 => "at its front's low end", when others => "at its front's high end")
                         & "," & W.Way_Deep'Image & " block columns from the front wall's line to the path, "
                         & (if W.Stair > 0 then "a stair of" & Natural'Image (abs W.Rise) & " steps"
                                                & (if W.Rise < 0 then " down from the path" else " up from the path")
                            else "no stair") & " (floor less path" & W.Rise'Image & ")");
            end if;
         end;
         if Yard_Map and then (W.Stair > 0 or else W.Way_End > 0) then
            Put_Line ("yard map of the one " & Said & ":");
            Put_Yard_Map;                         --  (as planned on the land as it lies, before anything of it is made)
         end if;
         if Yard_Built and then (W.Stair > 0 or else W.Way_End > 0) then
            Build_Homes_Now (As_Laid => True);
            Rebuild_Dirty;
            declare
               Spots, Pits : Natural;
               In_M, Out_M : Float;
            begin
               Yard_Pits (Spots, Pits, In_M, Out_M, Where => Yard_Map);
               if Yard_Map and then Pits > 0 then
                  Put_Line ("yard map of the one " & Said & ", built:");
                  Put_Yard_Map;
               end if;
               Built_N := Built_N + 1;
               if Cart_Place_By_Storehouse then
                  Built_Cart := Built_Cart + 1;
               else
                  Put_Line ("yard built: " & Said & ": no place by its storehouse's front takes the lord's cart");
               end if;
               Built_Spots := Built_Spots + Spots;
               Built_Pits := Built_Pits + Pits;
               if House_At (Storehouse).Phase /= Standing then
                  Built_Not_Standing := Built_Not_Standing + 1;
               end if;
               if Pits > 0 then
                  Built_With_Pits := Built_With_Pits + 1;
               end if;
               if In_M < 0.0 or else Out_M < 0.0 then
                  Built_No_Way := Built_No_Way + 1;
               else
                  Built_Way_M := Built_Way_M + In_M + Out_M;
                  Built_Way_Most := Float'Max (Built_Way_Most, In_M + Out_M);
               end if;
               Put_Line ("yard built: " & Said & ": of" & Spots'Image & " spots" & Pits'Image & " are pits; from the fire into"
                         & " the storehouse " & (if In_M < 0.0 then "NO WAY" else Img (In_M, 1) & " m") & ", back "
                         & (if Out_M < 0.0 then "NO WAY" else Img (Out_M, 1) & " m"));
            end;
         end if;
         Stair_Sum := Stair_Sum + W.Stair;
         Way_Stair_Sum := Way_Stair_Sum + W.Way_Stair;
         Rise_Most := Natural'Max (Rise_Most, abs W.Rise);
         if W.Stair > 0 then
            With_Stair := With_Stair + 1;
         elsif abs W.Rise <= 1 then
            Rise_Small := Rise_Small + 1;
         end if;
         for K in 1 .. 4 loop
            Rim_Sum := Rim_Sum + W.Side (K).Rim;
            Stone_Sum := Stone_Sum + W.Side (K).Stone;
            Back_Sum := Back_Sum + W.Side (K).Back;
            Up_Sum := Up_Sum + W.Side (K).Up;
            Blocks_Sum := Blocks_Sum + W.Side (K).Blocks;
            Cols := Cols + W.Side (K).Stone;
            High := Natural'Max (High, W.Side (K).Highest);
            if W.Side (K).Stone > 0 then
               Any := True;
               Sides_Walled (K) := Sides_Walled (K) + 1;
            end if;
         end loop;
         if Any then
            Walled := Walled + 1;
            if W.Side (1).Stone > 0 then
               Front_Walled := Front_Walled + 1;
            end if;
         else
            No_Wall := No_Wall + 1;
         end if;
         Tallest ((if High = 0 then 0 elsif High <= 2 then 1 elsif High <= 4 then 2 elsif High <= 8 then 3 else 4)) :=
           Tallest ((if High = 0 then 0 elsif High <= 2 then 1 elsif High <= 4 then 2 elsif High <= 8 then 3 else 4)) + 1;
         Most_Stone := Natural'Max (Most_Stone, Cols);
         Most_High := Natural'Max (Most_High, High);
      end Count_Walls;
      Refused : array (Why) of Natural := [others => 0];
      function Has (S, Part : String) return Boolean is (Ada.Strings.Fixed.Index (S, Part) > 0);
      procedure Note (T : String) is
      begin
         if Has (T, "will not take the storehouse") then
            Refused (No_Store) := Refused (No_Store) + 1;
         elsif Has (T, "cannot all be taken") or else Has (T, "too small") or else Has (T, "no clear ground") then
            Refused (No_Ground) := Refused (No_Ground) + 1;
         elsif Has (T, "overlaps") or else Has (T, "in the way") then
            Refused (Over_Something) := Refused (Over_Something) + 1;
         elsif Has (T, "no ground there for its path") or else Has (T, "within a metre of a path") then
            Refused (No_Path_Ground) := Refused (No_Path_Ground) + 1;
         else
            Refused (Other) := Refused (Other) + 1;
            if Refused (Other) <= 3 then
               Put_Line ("yard census: refused otherwise: '" & T & "'");
            end if;
         end if;
      end Note;
   begin
      for I in -N .. N loop
         for J in -N .. N loop
            declare
               X   : constant Float := Scn.Stake_X + Float (I) * Scan_Step;
               Y   : constant Float := Scn.Stake_Y + Float (J) * Scan_Step;
               Z   : constant Float := Castle.Nav.Surface_Z (X, Y);
               Way : constant Way_Index := (I + J) mod 2;
            begin
               Take_Cart_Away;
               Reset;
               if Z >= 0.0 and then Plan_Square ((X, Y, Z), Way).Ok then
                  Squares := Squares + 1;
                  for D in 1 .. 4 loop
                     Take_Cart_Away;
                     Reset;
                     if Yard_Built then
                        Land_Back;                --  (what was built for the last one is gone from this one's ground)
                     end if;
                     Place_Square ((X, Y, Z), Way, 6, Seed);
                     if not Has_Stake and then D = 1 then
                        Unfounded := Unfounded + 1;
                        Put_Line ("yard census: at " & Img (X, 2) & ", " & Img (Y, 2)
                                  & (if Way = 0 then " squarely" else " aslant")
                                  & ": the square's plan said yes and it was not founded ('" & Square_Refusal & "')");
                     end if;
                     if Has_Stake and then Yard_Built then
                        --  (as a band three days in has it: the square made, its path laid and its banks
                        --  walled, before the stockyard is put down beside it)
                        Build_Camp_Now;
                        Build_Paths_Now (Backward => Paths_Backward);
                        Build_Walls_Now;
                        Rebuild_Dirty;
                     end if;
                     if Has_Stake then
                        declare
                           Mid : constant Vec3 := Square_Path_Middle (D);     --  the middle of that side's path
                           R2  : constant Float := 0.707_106_78;
                           --  the way out from the square across that side, and the way a box lies along it
                           --  with the square behind its path (a box lies on the left of its way)
                           Ox : constant Float :=
                             (if Way = 0 then (case D is when 1 => 1.0, when 2 => -1.0, when others => 0.0)
                              else (case D is when 1 | 4 => R2, when others => -R2));
                           Oy : constant Float :=
                             (if Way = 0 then (case D is when 3 => 1.0, when 4 => -1.0, when others => 0.0)
                              else (case D is when 1 | 3 => R2, when others => -R2));
                           Box_Way : constant Way_Index :=
                             (if Way = 0 then (case D is when 1 => 6, when 2 => 2, when 3 => 0, when others => 4)
                              else (case D is when 1 => 7, when 2 => 3, when 3 => 1, when others => 5));
                           Cells : Natural := 0;
                        begin
                           Tried := Tried + 1;
                           if Yard_Census_M > 0 then
                              --  (two corners: M metres along the side's path, centred, and M out from
                              --  the first whole metre beyond its edge; aslant along and across its way)
                              declare
                                 M  : constant Float := Float (Yard_Census_M);
                                 Ex : constant Float := (if Way = 0 then 1.0 else R2);
                                 Ey : constant Float := (if Way = 0 then 0.0 else R2);
                                 A_Mid : constant Float := Mid.X * Ex + Mid.Y * Ey;
                                 B_Mid : constant Float := Mid.Y * Ex - Mid.X * Ey;
                                 A_Out : constant Float := Ox * Ex + Oy * Ey;          --  (one of the two is 1 or -1)
                                 B_Out : constant Float := Oy * Ex - Ox * Ey;
                                 A0, A1, B0, B1 : Float;
                              begin
                                 if abs A_Out > 0.5 then
                                    A0 := (if A_Out > 0.0 then Float'Ceiling (A_Mid + 0.5) else Float'Floor (A_Mid - 0.5));
                                    A1 := A0 + A_Out * M;
                                    B0 := Float'Rounding (B_Mid - M / 2.0);
                                    B1 := B0 + M;
                                    A0 := A0 + A_Out * 0.01;  A1 := A1 - A_Out * 0.01;  B0 := B0 + 0.01;  B1 := B1 - 0.01;
                                 else
                                    B0 := (if B_Out > 0.0 then Float'Ceiling (B_Mid + 0.5) else Float'Floor (B_Mid - 0.5));
                                    B1 := B0 + B_Out * M;
                                    A0 := Float'Rounding (A_Mid - M / 2.0);
                                    A1 := A0 + M;
                                    B0 := B0 + B_Out * 0.01;  B1 := B1 - B_Out * 0.01;  A0 := A0 + 0.01;  A1 := A1 - 0.01;
                                 end if;
                                 Zone_Stockyard (A0 * Ex - B0 * Ey, A0 * Ey + B0 * Ex, A1 * Ex - B1 * Ey, A1 * Ey + B1 * Ex,
                                                 Cells);
                                 if Cells = Yard_Census_M * Yard_Census_M then
                                    Taken := Taken + 1;
                                    By_Way (Way, True) := By_Way (Way, True) + 1;
                                 else
                                    By_Way (Way, False) := By_Way (Way, False) + 1;
                                    Note (Stockyard_Refusal);
                                 end if;
                              end;
                           else
                              declare
                                 Held : constant Vec3 := (Mid.X + Ox * 10.5, Mid.Y + Oy * 10.5, Mid.Z);
                                 Held_Pile : constant Vec3 := (Mid.X + Ox * 5.5, Mid.Y + Oy * 5.5, Mid.Z);
                                 T_0  : constant Time := Clock;
                                 Pile : constant Box_Plan := Plan_Box (Stockpile_Box, Held_Pile, Box_Way);
                                 T_1  : constant Time := Clock;
                                 Plan : constant Box_Plan := Plan_Box (Stockyard_Box, Held, Box_Way);
                                 T_2  : constant Time := Clock;
                                 Why_Not : constant String := Box_Refusal;
                              begin
                                 Plans (Way) := Plans (Way) + 1;
                                 Pile_S (Way) := Pile_S (Way) + To_Duration (T_1 - T_0);
                                 Yard_S (Way) := Yard_S (Way) + To_Duration (T_2 - T_1);
                                 Pile_Most (Way) := Duration'Max (Pile_Most (Way), To_Duration (T_1 - T_0));
                                 Yard_Most (Way) := Duration'Max (Yard_Most (Way), To_Duration (T_2 - T_1));
                                 if Pile.Lot.Ok then
                                    Piles_Taken := Piles_Taken + 1;
                                 end if;
                                 Place_Box (Stockyard_Box, Held, Box_Way, Cells);
                                 if (Cells > 0) /= Plan.Lot.Ok then
                                    Disagree := Disagree + 1;
                                    Put_Line ("yard census: at " & Img (X, 2) & ", " & Img (Y, 2)
                                              & (if Way = 0 then " squarely" else " aslant") & ", side" & D'Image
                                              & ": THE PLAN SAID " & (if Plan.Lot.Ok then "YES" else "NO ('" & Why_Not & "')")
                                              & " AND THE CLICK " & (if Cells > 0 then "TOOK IT" else "DID NOT ('" & Box_Refusal & "')"));
                                 end if;
                                 if Cells > 0 then
                                    Taken := Taken + 1;
                                    By_Way (Way, True) := By_Way (Way, True) + 1;
                                    --  (and its storehouse, were it begun now, fronts that side's path)
                                    if not Plan.Where.Ok or else Plan.Where.Snap /= Along_Path then
                                       Not_Own := Not_Own + 1;
                                    end if;
                                    if Yard_Walls_Census then
                                       Count_Walls ("at " & Img (X, 2) & ", " & Img (Y, 2)
                                                    & (if Way = 0 then " squarely" else " aslant") & ", side" & D'Image
                                                    & " (held at " & Img (Held.X, 2) & ", " & Img (Held.Y, 2) & ", way"
                                                    & Box_Way'Image & ")");
                                    end if;
                                 else
                                    By_Way (Way, False) := By_Way (Way, False) + 1;
                                    Note (Why_Not);
                                 end if;
                              end;
                           end if;
                        end;
                     end if;
                     if Yard_Built then           --  (and nothing of this one is left for the next place's reading)
                        Take_Cart_Away;
                        Reset;
                        Land_Back;
                     end if;
                  end loop;
               end if;
            end;
         end loop;
      end loop;
      Take_Cart_Away;
      Reset;
      Put_Line ("yard census, " & (if Yard_Census_M > 0 then "between two corners," & Yard_Census_M'Image & " m a side"
                                   else "put down whole")
                & ", against each side of" & Squares'Image & " squares (" & Img (Unfounded)
                & " of them planned and not founded):" & Tried'Image & " tried," & Taken'Image
                & " taken (squarely" & By_Way (0, True)'Image & " of" & Natural'Image (By_Way (0, True) + By_Way (0, False))
                & ", aslant" & By_Way (1, True)'Image & " of" & Natural'Image (By_Way (1, True) + By_Way (1, False))
                & "); refused: no storehouse could stand" & Refused (No_Store)'Image
                & ", its ground cannot all be taken" & Refused (No_Ground)'Image
                & ", over a zone or a path" & Refused (Over_Something)'Image
                & ", no ground for its path or off its path" & Refused (No_Path_Ground)'Image
                & ", otherwise" & Refused (Other)'Image
                & (if Yard_Census_M > 0 then ""
                   else "; parts of their own paths with nothing to lay a path on" & Box_Paths_Unlaid'Image
                        & "; the plan and the click disagreed" & Disagree'Image & " times;" & Not_Own'Image
                        & " taken that were not held along the square's path; a stockpile's box held there is"
                        & " taken at" & Piles_Taken'Image));
      if Yard_Walls_Census then
         Put_Line ("yard census, where a stockyard's own stone stands:" & Begun'Image & " stockyards with their storehouse"
                   & " begun;" & Walled'Image & " have stone on their rim (" & No_Wall'Image & " none), on the front of"
                   & Front_Walled'Image & "; by side (front, back, left, right)" & Sides_Walled (1)'Image
                   & Sides_Walled (2)'Image & Sides_Walled (3)'Image & Sides_Walled (4)'Image
                   & "; rim columns counted" & Rim_Sum'Image & ", of stone" & Stone_Sum'Image & " (holding higher ground back"
                   & Back_Sum'Image & ", holding the yard up" & Up_Sum'Image & "), blocks of stone in them" & Blocks_Sum'Image
                   & "; the tallest wall of a stockyard: none" & Tallest (0)'Image & ", to two blocks" & Tallest (1)'Image
                   & ", to four" & Tallest (2)'Image & ", to eight" & Tallest (3)'Image & ", over" & Tallest (4)'Image
                   & "; the most rim columns of stone at one" & Most_Stone'Image & ", the tallest of all" & Most_High'Image
                   & " blocks; stone not on a rim (stairs, steps) in" & Inner_Sum'Image & " columns");
         Put_Line ("yard census, what the rim's stone stands on, by the stockyard's design: treads of its stair and its way in"
                   & Way_Sum'Image & " columns; the ground before its back wall's line (its staging, beside its ends: no"
                   & " places)" & Clear_Sum'Image & "; the line its fence stands on" & Fenced_Sum'Image
                   & "; a place's ground where goods lie with no fence on it" & Goods_Sum'Image & " (at" & With_Goods'Image
                   & " stockyards)");
         Put_Line ("yard census, a stockyard's stair (the flight of the way to its storehouse's door, where its path"
                   & " lies more than a block off the floor):" & With_Stair'Image & " stockyards have one," & Stair_Sum'Image
                   & " block columns of steps in all (" & Img (Way_Stair_Sum) & " of them the rim's stone);" & Rise_Small'Image
                   & " have none, their path within a block of the floor; the most between path and floor" & Rise_Most'Image
                   & " blocks");
         declare
            function Pairs (M : access function (Lo, Hi : End_Class) return Natural) return String is
              ("level at both" & M (Level, Level)'Image
               & ", level at one and a bank a stair can stand against at the other"
               & Natural'Image (M (Level, Takes) + M (Takes, Level))
               & " (the level end the low one" & M (Level, Takes)'Image & ", the high one" & M (Takes, Level)'Image & ")"
               & ", level at one and over eight blocks at the other" & Natural'Image (M (Level, Over) + M (Over, Level))
               & ", a bank at both" & M (Takes, Takes)'Image
               & ", a bank at one and over eight at the other" & Natural'Image (M (Takes, Over) + M (Over, Takes))
               & ", over eight at both" & M (Over, Over)'Image
               & ", an end not read"
               & Natural'Image (M (Unread, Level) + M (Unread, Takes) + M (Unread, Over) + M (Unread, Unread)
                                + M (Level, Unread) + M (Takes, Unread) + M (Over, Unread)));
            function Of_Staired (Lo, Hi : End_Class) return Natural is (Ends_Staired (Lo, Hi));
            function Of_All (Lo, Hi : End_Class) return Natural is (Ends_All (Lo, Hi));
            function Steps (A : access function (K : Natural) return Natural) return String is
              (A (2)'Image & "," & A (3)'Image & "," & A (4)'Image & "," & A (5)'Image & "," & A (6)'Image & ","
               & A (7)'Image & "," & A (8)'Image & "; over" & A (9)'Image & "; under two" & Natural'Image (A (0) + A (1)));
            function Far (K : Natural) return Natural is (Far_Steps (K));
            function Both (K : Natural) return Natural is (Both_Steps (K));
         begin
            Put_Line ("yard census, where a stockyard's way in is"
                      & (if not Yard_Stair_Corner then " (--yard-stair-middle)"
                         elsif not Yard_Floor_Low then " (--yard-floor-by-land)" else "")
                      & ": at the middle of its storehouse's front" & Way_At (0)'Image & " (" & Img (Way_Staired (0))
                      & " with a stair), at the low end of its front" & Way_At (1)'Image & " (" & Img (Way_Staired (1))
                      & " with a stair), at the high end" & Way_At (2)'Image & " (" & Img (Way_Staired (2))
                      & " with a stair); stairs of 2, 3, 4, 5, 6, 7, 8 steps:" & Stair_By_Steps (2)'Image & ","
                      & Stair_By_Steps (3)'Image & "," & Stair_By_Steps (4)'Image & "," & Stair_By_Steps (5)'Image & ","
                      & Stair_By_Steps (6)'Image & "," & Stair_By_Steps (7)'Image & "," & Stair_By_Steps (8)'Image
                      & ", over" & Stair_By_Steps (9)'Image & ";" & Stair_By_Level_End'Image
                      & " stairs at one end with the path level at the other;" & Mid_Banked_No_Stair'Image
                      & " with the path more than a block off the floor at the middle of the front and no stair anywhere;"
                      & All_Blocks_Sum'Image & " blocks of stone in all their ground, walls and stairs");
            if Yard_Built then
               Put_Line ("yard census, built on the spot (the square, its path and its walls made before the stockyard is"
                         & " put down; then the stockyard's ground and its storehouse):"
                         & Built_N'Image & " stockyards with a stair or their way in at an end of their front;"
                         & Built_Not_Standing'Image & " whose storehouse does not stand; of" & Built_Spots'Image
                         & " spots on their ground and within 2 m of it that can be got to from the fire," & Built_Pits'Image
                         & " cannot be got back from (at" & Built_With_Pits'Image & " stockyards);" & Built_No_Way'Image
                         & " with no way from the fire to the middle of the storehouse's floor or back; those ways, there"
                         & " and back, " & Img (Built_Way_M, 1) & " m in all, the longest " & Img (Built_Way_Most, 1) & " m;"
                         & Built_Cart'Image & " with a place before the storehouse that takes the lord's cart");
            end if;
            Put_Line ("yard census, the two ends of the front of a stockyard whose path lies more than a block off its floor"
                      & " at the middle of its front (the front corners of the zone; the path's ground at the middle of"
                      & " two metres there, against the floor): " & Pairs (Of_Staired'Access));
            Put_Line ("yard census, the same of every stockyard begun: " & Pairs (Of_All'Access));
            Put_Line ("yard census, a stair at the end away from the level one: blocks between path and floor there, 2 to 8:"
                      & Steps (Far'Access) & "; with a bank at both ends, the lower of the two:" & Steps (Both'Access)
                      & " (both over or both under the floor" & Both_Same_Way'Image & ", one over and one under"
                      & Both_Other_Way'Image & "); of" & Ends_Read'Image & " ends read," & Spread_2'Image
                      & " have two blocks or more between the path's lowest and highest over their two metres; the"
                      & " stockyard's own ground before its front wall's line at an end "
                      & (if Deep_Most = 0 then "not read" else Img (Deep_Least) & " to " & Img (Deep_Most) & " block columns deep"));
         end;
      end if;
      if Yard_Census_M = 0 then
         for W in 0 .. 1 loop
            if Plans (W) > 0 then
               Put_Line ("yard census, what a plan takes, " & (if W = 0 then "squarely" else "aslant") & ":"
                         & Plans (W)'Image & " plans; the stockyard's "
                         & Img (Float (Yard_S (W)) * 1000.0 / Float (Plans (W)), 2) & " ms on the mean, "
                         & Img (Float (Yard_Most (W)) * 1000.0, 2) & " at the most; a stockpile's there "
                         & Img (Float (Pile_S (W)) * 1000.0 / Float (Plans (W)), 2) & " ms on the mean, "
                         & Img (Float (Pile_Most (W)) * 1000.0, 2) & " at the most");
            end if;
         end loop;
      end if;
   end Yard_Scan;
   procedure Square_Scan is
      use Castle.Colony;
      N : constant Integer := Integer (Float'Floor (Scan_R / Scan_Step));
      --  (where a stair can stand: of the sides that take one at their middle, what their two ends
      --  take; the corners where the path comes in level; and what three readings of "the opposite
      --  corner" would put where)
      Mid_Stairs, Mid_Squares : Natural := 0;
      End_One, End_One_Level, End_One_Low, End_One_High, End_Both, End_Both_Tie, End_None, End_None_High : Natural := 0;
      Level_Squares : array (0 .. 4) of Natural := [others => 0];     --  squares by how many corners are level
      Level_Corners, Diag_Takes, Diag_Level, Diag_Other : Natural := 0;
      Diag_Stairs, Diag_Squares, Diag_Mid_None : Natural := 0;        --  one stair diagonally across from a level corner
      Each_Stairs, Each_Squares : Natural := 0;                       --  one at every corner that takes one
      High_Mid, High_Mid_End : Natural := 0;                          --  sides too high at their middle; with an end that takes one
      Lost_All, Shared_All, By_Level_All : Natural := 0;
      Stair_Most_B : array (Stair_Place) of Natural := [others => 0]; --  the highest bank a stair stands against, by place
      Stair_Count  : array (Stair_Place) of Natural := [others => 0]; --  the stairs, by place
      Stair_Steps : Natural := 0;                                     --  blocks of bank the stairs go up or down, in all
      Sites, Taken, With_Pits, No_Way_In, Pits_All : Natural := 0;
      Feet_All, Dug_Most, Filled_Most, Trees_All, Trees_Most, With_Trees, Piles_Off : Natural := 0;
      --  (their walls and stairs: how many have any, a wall set back, a stair; what they take)
      Walled, Set_Back, Thrice, Staired, Stairs_All, Too_High, Stone_All, Stone_Most, Earth_Most : Natural := 0;
      Path_All : Path_Count;               --  (how the squares' paths step: Read_Square_Path)
      Unready_All, Left_After, Bank_Most : Natural := 0;
      --  (the strips kept for walls that stand outside the floor: squares and sides with any; sides whose
      --  path as laid asks more rings than were kept, with a strip and with none; sides kept more than
      --  is asked; the columns that stand steeper or are left earth for it; stone in a floor with no stair)
      Out_Squares, Strip_Squares, Strip_Sides, Rings_All, Short_Sides, Bare_Sides, Spare_Sides : Natural := 0;
      Short_Cols, Bare_Cols, Inside_All, Capped_All, Capped_Most : Natural := 0;
      --  (and the squares whose floor was founded at another level than their plan said: the strips
      --  are judged against the plan's)
      Level_Off : Natural := 0;
      Planned_Row : Integer := -1;
      --  (and those planned that the founding then refused, and those founded with the fire's place more
      --  than 2 m off the level its floor is to have: not on the ground, a square's ground falling 1.5 m
      --  at the most)
      Plan_Only, Fire_Off : Natural := 0;
      Ways : array (0 .. 4) of Natural := [others => 0];
      --  (the way between the middle of each side's path and the fire, there and back: a bank is gone
      --  round, a stair is gone down)
      Side_Ways, Side_None, Side_Moved : Natural := 0;
      Side_M, Side_Most_M : Float := 0.0;
   begin
      for I in -N .. N loop
         for J in -N .. N loop
            declare
               X   : constant Float := Scn.Stake_X + Float (I) * Scan_Step;
               Y   : constant Float := Scn.Stake_Y + Float (J) * Scan_Step;
               Z   : constant Float := Castle.Nav.Surface_Z (X, Y);
               Way : constant Way_Index := (I + J) mod 2;
            begin
               Sites := Sites + 1;
               Take_Cart_Away;                         --  (the last one given up, and its cart's bed not left
               Reset;                                  --  standing where the next one's path is to be laid)
               if Z >= 0.0 and then Plan_Square ((X, Y, Z), Way).Ok then
                  Planned_Row := Plan_Square ((X, Y, Z), Way).Level_Row;
                  Place_Square ((X, Y, Z), Way, 6, Seed);
                  if not Has_Stake then
                     Plan_Only := Plan_Only + 1;
                     Put_Line ("square scan: at " & Img (X, 2) & ", " & Img (Y, 2) & (if Way = 0 then " squarely" else " aslant")
                               & ": its plan said yes and it was not founded ('" & Square_Refusal & "')");
                  elsif Camp_State.Floor_Z >= 0.0 and then abs (Stake.Z - Camp_State.Floor_Z) > 2.0 then
                     Fire_Off := Fire_Off + 1;
                     Put_Line ("square scan: at " & Img (X, 2) & ", " & Img (Y, 2) & (if Way = 0 then " squarely" else " aslant")
                               & ": its fire's place is at " & Img (Stake.Z, 2) & " m, its floor to be at "
                               & Img (Camp_State.Floor_Z, 2) & " m");
                  end if;
                  if Has_Stake and then Planned_Row >= 0
                    and then abs (Float (Planned_Row + 1) * 0.25 - Camp_State.Floor_Z) > 0.01
                  then
                     Level_Off := Level_Off + 1;
                     Put_Line ("square scan: at " & Img (X, 2) & ", " & Img (Y, 2) & (if Way = 0 then " squarely" else " aslant")
                               & ": planned at " & Img (Float (Planned_Row + 1) * 0.25, 2) & " m, founded at "
                               & Img (Camp_State.Floor_Z, 2) & " m");
                  end if;
                  if Has_Stake then
                     declare
                        To_Dig  : constant Natural := Camp_State.To_Dig;
                        To_Fill : constant Natural := Camp_State.To_Fill;
                        Floor_Z : constant Float := Camp_State.Floor_Z;
                        Blocks  : constant Natural := Zone_At (Camp_Zone).Blocks;
                        Whole   : constant Natural :=      --  (its floor's block columns: eleven metres, or ten)
                          (if Square_Wide then (if Way = 0 then 1_936 else 1_984) else (if Way = 0 then 1_600 else 1_624));
                        Spots, Pits, Ways_In : Natural := 0;
                        Px, Py : Float;
                        Trees_0 : constant Natural := Trees_Felled;
                        Felled, Off_Piles : Natural := 0;
                        W0, W1 : Walls_View;
                        Side_Way : array (1 .. 4) of Float := [others => -1.0];
                     begin
                        Build_Camp_Now;
                        if Walls_Between then
                           Build_Paths_Now (Backward => Paths_Backward, Most => 26);
                           Build_Walls_Now;
                        end if;
                        Build_Paths_Now (Backward => Paths_Backward);
                        W0 := Square_Walls_State;            --  (what its walls take, before any of them is laid)
                        declare
                           St : constant Stair_Sites := Square_Stair_Sites;
                           --  (the corners, 1 .. 4 round the square, and the two side ends that meet at each)
                           type End_Ref is record
                              Sd : Positive;
                              Sp : Stair_Spot;
                           end record;
                           Ends : constant array (1 .. 4, 1 .. 2) of End_Ref :=
                             [1 => [(1, At_High), (3, At_High)], 2 => [(1, At_Low), (4, At_High)],
                              3 => [(2, At_Low), (4, At_Low)], 4 => [(2, At_High), (3, At_Low)]];
                           function Corner_Level (C : Positive) return Boolean is
                             (St (Ends (C, 1).Sd, Ends (C, 1).Sp).Level or else St (Ends (C, 2).Sd, Ends (C, 2).Sp).Level);
                           function Corner_Takes (C : Positive) return Boolean is
                             (St (Ends (C, 1).Sd, Ends (C, 1).Sp).Takes or else St (Ends (C, 2).Sd, Ends (C, 2).Sp).Takes);
                           Mids, Levels, Diags, Eachs : Natural := 0;
                        begin
                           for Sd in 1 .. 4 loop
                              if St (Sd, At_Middle).Banked and then not St (Sd, At_Middle).Takes then
                                 High_Mid := High_Mid + 1;
                                 if St (Sd, At_Low).Takes or else St (Sd, At_High).Takes then
                                    High_Mid_End := High_Mid_End + 1;
                                 end if;
                              end if;
                              if St (Sd, At_Middle).Takes then
                                 Mids := Mids + 1;
                                 declare
                                    Lo : constant Stair_Bank := St (Sd, At_Low);
                                    Hi : constant Stair_Bank := St (Sd, At_High);
                                 begin
                                    if Lo.Takes and then Hi.Takes then
                                       End_Both := End_Both + 1;
                                       if Lo.Most_B = Hi.Most_B then
                                          End_Both_Tie := End_Both_Tie + 1;
                                       end if;
                                    elsif Lo.Takes or else Hi.Takes then
                                       End_One := End_One + 1;
                                       declare
                                          Other : constant Stair_Bank := (if Lo.Takes then Hi else Lo);
                                       begin
                                          if Other.Level then
                                             End_One_Level := End_One_Level + 1;
                                          elsif Other.Banked then
                                             End_One_High := End_One_High + 1;
                                          else
                                             End_One_Low := End_One_Low + 1;
                                          end if;
                                       end;
                                    else
                                       End_None := End_None + 1;
                                       if Lo.Banked or else Hi.Banked then
                                          End_None_High := End_None_High + 1;
                                       end if;
                                    end if;
                                 end;
                              end if;
                           end loop;
                           for C in 1 .. 4 loop
                              if Corner_Level (C) then
                                 Levels := Levels + 1;
                                 declare
                                    D : constant Positive := (C + 1) mod 4 + 1;
                                 begin
                                    if Corner_Level (D) then
                                       Diag_Level := Diag_Level + 1;
                                    elsif Corner_Takes (D) then
                                       Diag_Takes := Diag_Takes + 1;
                                       Diags := Diags + 1;
                                    else
                                       Diag_Other := Diag_Other + 1;
                                    end if;
                                 end;
                              elsif Corner_Takes (C) then
                                 Eachs := Eachs + 1;
                              end if;
                           end loop;
                           Mid_Stairs := Mid_Stairs + Mids;
                           Level_Corners := Level_Corners + Levels;
                           Level_Squares (Levels) := Level_Squares (Levels) + 1;
                           Diag_Stairs := Diag_Stairs + Diags;
                           Each_Stairs := Each_Stairs + Eachs;
                           if Mids > 0 then
                              Mid_Squares := Mid_Squares + 1;
                              if Diags = 0 then
                                 Diag_Mid_None := Diag_Mid_None + 1;
                              end if;
                           end if;
                           if Diags > 0 then
                              Diag_Squares := Diag_Squares + 1;
                           end if;
                           if Eachs > 0 then
                              Each_Squares := Each_Squares + 1;
                           end if;
                           Lost_All := Lost_All + W0.Stairs_Lost;
                           Shared_All := Shared_All + W0.Stairs_Shared;
                           By_Level_All := By_Level_All + W0.Stairs_By_Level;
                           for Sd in 1 .. 4 loop
                              if W0.Stair_At (Sd) /= No_Stair then
                                 Stair_Count (W0.Stair_At (Sd)) := Stair_Count (W0.Stair_At (Sd)) + 1;
                                 Stair_Most_B (W0.Stair_At (Sd)) :=
                                   Natural'Max (Stair_Most_B (W0.Stair_At (Sd)), St (Sd, W0.Stair_At (Sd)).Most_B);
                                 Stair_Steps := Stair_Steps + St (Sd, W0.Stair_At (Sd)).Most_B;
                              end if;
                           end loop;
                           if Scan_List and then (Mids > 0 or else W0.Stairs > 0) then
                              Put_Line ("square scan, stairs: at " & Img (Stake.X, 2) & ", " & Img (Stake.Y, 2)
                                        & (if Way = 0 then " squarely" else " aslant") & ": stairs at "
                                        & Stair_Word (W0.Stair_At (1)) & ", " & Stair_Word (W0.Stair_At (2)) & ", "
                                        & Stair_Word (W0.Stair_At (3)) & ", " & Stair_Word (W0.Stair_At (4))
                                        & "; the bank at each side's low end, middle and high end:"
                                        & Bank_Word (St (1, At_Low)) & Bank_Word (St (1, At_Middle)) & Bank_Word (St (1, At_High))
                                        & " |" & Bank_Word (St (2, At_Low)) & Bank_Word (St (2, At_Middle))
                                        & Bank_Word (St (2, At_High)) & " |" & Bank_Word (St (3, At_Low))
                                        & Bank_Word (St (3, At_Middle)) & Bank_Word (St (3, At_High)) & " |"
                                        & Bank_Word (St (4, At_Low)) & Bank_Word (St (4, At_Middle))
                                        & Bank_Word (St (4, At_High)) & ";" & Levels'Image & " corners level");
                           end if;
                        end;
                        Build_Walls_Now;
                        W1 := Square_Walls_State;
                        Felled := Trees_Felled - Trees_0;
                        Rebuild_Dirty;
                        Advance (1.0, Hours);
                        Rebuild_Dirty;
                        Px := Stake.X - 9.0;
                        while Px <= Stake.X + 9.0 loop
                           Py := Stake.Y - 9.0;
                           while Py <= Stake.Y + 9.0 loop
                              declare
                                 Pz : constant Float := Castle.Nav.Surface_Z (Px, Py);
                              begin
                                 if Pz >= 0.0
                                   and then Castle.Nav."=" (Castle.Nav.Plan (Stake, (Px, Py, Pz)).Result, Castle.Nav.Found)
                                 then
                                    Spots := Spots + 1;
                                    if not Castle.Nav."=" (Castle.Nav.Plan ((Px, Py, Pz), Stake).Result, Castle.Nav.Found)
                                    then
                                       Pits := Pits + 1;
                                    end if;
                                 end if;
                              end;
                              Py := Py + 0.5;
                           end loop;
                           Px := Px + 0.5;
                        end loop;
                        for D in 1 .. 4 loop
                           declare
                              Ox : constant Float := Stake.X + (case D is when 1 => 14.0, when 2 => -14.0, when others => 0.0);
                              Oy : constant Float := Stake.Y + (case D is when 3 => 14.0, when 4 => -14.0, when others => 0.0);
                              Oz : constant Float := Castle.Nav.Surface_Z (Ox, Oy);
                           begin
                              if Oz >= 0.0
                                and then Castle.Nav."=" (Castle.Nav.Plan ((Ox, Oy, Oz), Stake).Result, Castle.Nav.Found)
                                and then Castle.Nav."=" (Castle.Nav.Plan (Stake, (Ox, Oy, Oz)).Result, Castle.Nav.Found)
                              then
                                 Ways_In := Ways_In + 1;
                              end if;
                           end;
                        end loop;
                        for D in 1 .. 4 loop
                           declare
                              --  (from the middle of that side's path, wherever its strip has put it; where
                              --  the walking map has no floor at its very middle, from the nearest spot of
                              --  the path that has one)
                              Along : Float;
                              M     : constant Float := Side_Way_M (D, Along);
                           begin
                              Side_Way (D) := M;
                              if M >= 0.0 then
                                 Side_Ways := Side_Ways + 1;
                                 Side_M := Side_M + M;
                                 Side_Most_M := Float'Max (Side_Most_M, M);
                                 if Along /= 0.0 then
                                    Side_Moved := Side_Moved + 1;
                                 end if;
                              else
                                 Side_None := Side_None + 1;
                              end if;
                           end;
                        end loop;
                        --  (the logs of the trees felled for it: lying on the ground as it is now)
                        for K in 1 .. Pile_Count loop
                           declare
                              Pv : constant Pile_View := Pile_At (K);
                              Fl : Castle.Nav.Floor_List;
                              Fn : Natural;
                              Off : Float := Float'Last;     --  (off the nearest floor of the cell it lies in, or of one beside it)
                              Own : Float := Float'Last;
                           begin
                              for Dx in -1 .. 1 loop
                                 for Dy in -1 .. 1 loop
                                    Castle.Nav.Floors_At (Integer (Float'Floor (Pv.Centre.X * 2.0)) + Dx,
                                                          Integer (Float'Floor (Pv.Centre.Y * 2.0)) + Dy, Fn, Fl);
                                    for F in 1 .. Fn loop
                                       Off := Float'Min (Off, abs (Pv.Centre.Z - Float (Fl (F).Z) * 0.25));
                                       if Dx = 0 and then Dy = 0 then
                                          Own := Float'Min (Own, abs (Pv.Centre.Z - Float (Fl (F).Z) * 0.25));
                                       end if;
                                    end loop;
                                 end loop;
                              end loop;
                              --  (or on the ground of its own block column: at the foot of a wall or a bank
                              --  the cell's floor is the wall's top, and a pile lies where its blocks are)
                              declare
                                 Bx : constant Integer := Integer (Float'Floor (Pv.Centre.X * 4.0));
                                 By : constant Integer := Integer (Float'Floor (Pv.Centre.Y * 4.0));
                                 Bz : constant Integer := Integer (Float'Floor ((Pv.Centre.Z + 0.05) * 4.0));
                              begin
                                 if Castle.Blocks.Class_Of (Castle.World_Blocks.Block_At (Bx, By, Bz - 1).Mat) in Castle.Blocks.Solid
                                   and then Castle.Blocks.Class_Of (Castle.World_Blocks.Block_At (Bx, By, Bz).Mat)
                                              not in Castle.Blocks.Solid
                                 then
                                    Own := 0.0;
                                 end if;
                              end;
                              if Pv.Count > 0 and then (if Own < Float'Last then Own > 0.3 else Off > 0.5) then
                                 Off_Piles := Off_Piles + 1;
                                 if Scan_List then
                                    Put_Line ("square scan: a pile of" & Pv.Count'Image & " logs " & Img (Pv.Centre.X - Stake.X, 2)
                                              & " east and " & Img (Pv.Centre.Y - Stake.Y, 2) & " north of its middle lies at "
                                              & Img (Pv.Centre.Z, 2) & " m, "
                                              & (if Own < Float'Last then Img (Own, 2) & " m off the floor there"
                                                 else Img (Off, 2) & " m off the floors beside it (none where it lies)"));
                                 end if;
                              end if;
                           end;
                        end loop;
                        Read_Square_Path (Path_All, Lines => Square_Path,
                                          Said => " at " & Img (X, 2) & ", " & Img (Y, 2)
                                                  & (if Way = 0 then " squarely" else " aslant"));
                        if Square_Path then
                           Put_Line ("square ground at " & Img (X, 2) & ", " & Img (Y, 2)
                                     & (if Way = 0 then " squarely" else " aslant") & ":" & Square_Ground_Hash'Image);
                           Put_Line ("square floor at " & Img (X, 2) & ", " & Img (Y, 2)
                                     & (if Way = 0 then " squarely" else " aslant") & ":"
                                     & Square_Ground_Hash (1, Way /= 0)'Image
                                     & " beyond its path:" & Square_Ground_Hash (2, Way /= 0)'Image & " stairs at:"
                                     & " " & Square_Walls_State.Stair_At (1)'Image & " " & Square_Walls_State.Stair_At (2)'Image
                                     & " " & Square_Walls_State.Stair_At (3)'Image & " " & Square_Walls_State.Stair_At (4)'Image);
                        end if;
                        declare
                           Bars : constant Step_Bars := Square_Walls_State.Steps_Barred;
                        begin
                           for Bk in Step_Bar loop
                              Path_All.Barred (Bk) := Path_All.Barred (Bk) + Bars (Bk);
                           end loop;
                        end;
                        Taken := Taken + 1;
                        Trees_All := Trees_All + Felled;
                        Trees_Most := Natural'Max (Trees_Most, Felled);
                        Piles_Off := Piles_Off + Off_Piles;
                        if Felled > 0 then
                           With_Trees := With_Trees + 1;
                        end if;
                        Pits_All := Pits_All + Pits;
                        Feet_All := Feet_All + (Whole - Blocks);
                        Dug_Most := Natural'Max (Dug_Most, To_Dig);
                        Filled_Most := Natural'Max (Filled_Most, To_Fill);
                        if Pits > 0 then
                           With_Pits := With_Pits + 1;
                        end if;
                        if Ways_In = 0 then
                           No_Way_In := No_Way_In + 1;
                        end if;
                        Ways (Ways_In) := Ways (Ways_In) + 1;
                        if W0.Columns > 0 then
                           Walled := Walled + 1;
                        end if;
                        if W0.Lifts >= 2 then
                           Set_Back := Set_Back + 1;
                        end if;
                        if W0.Lifts >= 3 then
                           Thrice := Thrice + 1;
                        end if;
                        if W0.Stairs > 0 then
                           Staired := Staired + 1;
                        end if;
                        Stairs_All := Stairs_All + W0.Stairs;
                        Too_High := Too_High + W0.Too_High;
                        Stone_All := Stone_All + W0.Stone_Left;
                        Stone_Most := Natural'Max (Stone_Most, W0.Stone_Left);
                        Earth_Most := Natural'Max (Earth_Most, W0.Dig_Left);
                        Bank_Most := Natural'Max (Bank_Most, W0.Highest_B);
                        Unready_All := Unready_All + W0.Unready;
                        Left_After := Left_After + W1.Stone_Left + W1.Dig_Left;
                        if W0.Outside then
                           Out_Squares := Out_Squares + 1;
                           if (for some Sd in 1 .. 4 => W0.Strip (Sd) > 0) then
                              Strip_Squares := Strip_Squares + 1;
                           end if;
                           for Sd in 1 .. 4 loop
                              Rings_All := Rings_All + W0.Strip (Sd);
                              if W0.Strip (Sd) > 0 then
                                 Strip_Sides := Strip_Sides + 1;
                                 if W0.Need (Sd) > W0.Strip (Sd) then
                                    Short_Sides := Short_Sides + 1;
                                 elsif W0.Need (Sd) < W0.Strip (Sd) then
                                    Spare_Sides := Spare_Sides + 1;
                                 end if;
                              elsif W0.Need (Sd) > 0 then
                                 Bare_Sides := Bare_Sides + 1;
                              end if;
                           end loop;
                           Short_Cols := Short_Cols + W0.Short;
                           Bare_Cols := Bare_Cols + W0.Unwalled;
                           Inside_All := Inside_All + W1.Inside;
                           Capped_All := Capped_All + W0.Capped;
                           Capped_Most := Natural'Max (Capped_Most, W0.Capped);
                        end if;
                        if Pits > 0 or else Ways_In = 0 or else Off_Piles > 0 or else W1.Stone_Left + W1.Dig_Left > 0
                          or else Scan_List
                        then
                           Put_Line ("square scan: at " & Img (Stake.X, 2) & ", " & Img (Stake.Y, 2)
                                     & (if Way = 0 then " squarely" else " aslant") & ": floor at " & Img (Floor_Z, 2)
                                     & " m," & To_Dig'Image & " to dig," & To_Fill'Image & " to fill,"
                                     & Natural'Image (Whole - Blocks) & " block columns left out of it," & Felled'Image
                                     & " trees felled for it (" & Img (Off_Piles) & " of their piles of logs not lying"
                                     & " on the ground); of" & Spots'Image
                                     & " spots" & Pits'Image & " pits; the fire got to and from" & Ways_In'Image
                                     & " of the four sides" & (if Camp_State.Built then "" else "; ITS CAMP NOT BUILT")
                                     & "; walls:" & W0.Columns'Image & " columns, the highest bank" & W0.Highest_B'Image
                                     & " blocks," & W0.Lifts'Image & " lifts," & W0.Stairs'Image & " stairs,"
                                     & W0.Too_High'Image & " sides too high for one," & W0.Stone_Left'Image
                                     & " blocks of stone," & W0.Dig_Left'Image & " of earth to dig off,"
                                     & W0.Unready'Image & " edge columns with no path laid by them;"
                                     & Natural'Image (W1.Stone_Left + W1.Dig_Left) & " blocks left after building;"
                                     & " side ways " & Img (Side_Way (1), 1) & " " & Img (Side_Way (2), 1) & " "
                                     & Img (Side_Way (3), 1) & " " & Img (Side_Way (4), 1)
                                     & (if W0.Outside
                                        then "; rings kept" & W0.Strip (1)'Image & W0.Strip (2)'Image & W0.Strip (3)'Image
                                             & W0.Strip (4)'Image & " asked" & W0.Need (1)'Image & W0.Need (2)'Image
                                             & W0.Need (3)'Image & W0.Need (4)'Image & "," & W0.Short'Image & " steeper,"
                                             & W0.Unwalled'Image & " left earth," & W1.Inside'Image & " of floor stone,"
                                             & W0.Capped'Image & " of strip capped"
                                        else ""));
                        end if;
                     end;
                  end if;
               end if;
            end;
         end loop;
      end loop;
      Reset;
      Put_Line ("square scan, within " & Img (Scan_R, 0) & " m of " & Img (Scn.Stake_X, 0) & ", " & Img (Scn.Stake_Y, 0)
                & " every " & Img (Scan_Step, 0) & " m:" & Sites'Image & " places," & Taken'Image
                & " founded and made;" & With_Pits'Image & " with a pit by them (" & Img (Pits_All) & " spots in all),"
                & No_Way_In'Image & " whose fire cannot be got to and from any side;" & Feet_All'Image
                & " block columns left out of their floors (trees' feet);" & Trees_All'Image & " trees felled for"
                & With_Trees'Image & " of them (" & Img (Trees_Most) & " at the most, " & Img (Piles_Off)
                & " piles of logs not lying on the ground); the most to dig" & Dug_Most'Image
                & " blocks, to fill" & Filled_Most'Image);
      Put_Line ("square scan, walls" & (if Square_Walls then "" else " (off)") & ":" & Walled'Image & " of them walled,"
                & Set_Back'Image & " with a wall set back (" & Img (Thrice) & " twice)," & Staired'Image
                & " with a stair (" & Img (Stairs_All) & " stairs in all)," & Too_High'Image
                & " sides too high for one; the highest bank" & Bank_Most'Image & " blocks;" & Stone_All'Image
                & " blocks of stone in all, the most for one" & Stone_Most'Image & ", the most earth to dig off"
                & Earth_Most'Image & ";" & Unready_All'Image & " edge columns with no path laid by them;"
                & Left_After'Image & " blocks left after building; the fire got to and from 0, 1, 2, 3, 4 sides:"
                & Ways (0)'Image & "," & Ways (1)'Image & "," & Ways (2)'Image & "," & Ways (3)'Image & ","
                & Ways (4)'Image & "; from the middle of a side's path to the fire and back:" & Side_Ways'Image
                & " ways, " & Img (Side_M, 1) & " m in all, the longest " & Img (Side_Most_M, 1) & " m;"
                & Side_None'Image & " with no way;" & Side_Moved'Image
                & " of the ways from beside the middle (no floor of the walking map at the path's very middle)");
      Put_Line ("square scan, how their paths step:" & Path_Words (Path_All));
      Put_Line ("square scan, a stair's place" & (if Square_Stair_Corner then " (in a corner of the zone)" else "") & ":"
                & Staired'Image & " squares with a stair," & Stairs_All'Image & " stairs: at a side's low end, middle, high end"
                & Stair_Count (At_Low)'Image & "," & Stair_Count (At_Middle)'Image & "," & Stair_Count (At_High)'Image
                & " (the highest bank one stands against" & Stair_Most_B (At_Low)'Image & "," & Stair_Most_B (At_Middle)'Image
                & "," & Stair_Most_B (At_High)'Image & " blocks;" & Stair_Steps'Image & " blocks of bank gone up or down by"
                & " them in all);" & Lost_All'Image & " sides that would have one at their middle take none at either end,"
                & Shared_All'Image & " sides' stairs are another side's in the corner they meet at;" & By_Level_All'Image
                & " stairs stand in a corner where the path of the side met there comes in level");
      Put_Line ("square scan, where a stair can stand:" & Mid_Stairs'Image & " sides at" & Mid_Squares'Image
                & " squares take one at their middle; of those sides" & End_One'Image
                & " take one at one end only (the other end level" & End_One_Level'Image & ", a bank under a stair's"
                & End_One_Low'Image & ", over a stair's or mixed" & End_One_High'Image & ")," & End_Both'Image
                & " at both ends (" & Img (End_Both_Tie) & " of them as high at both)," & End_None'Image
                & " at neither (" & Img (End_None_High) & " for an end too high);" & High_Mid'Image
                & " sides are too high at their middle, " & Img (High_Mid_End) & " of them with an end that takes one");
      Put_Line ("square scan, level corners: squares with 0, 1, 2, 3, 4 corners where the path comes in level:"
                & Level_Squares (0)'Image & "," & Level_Squares (1)'Image & "," & Level_Squares (2)'Image & ","
                & Level_Squares (3)'Image & "," & Level_Squares (4)'Image & ";" & Level_Corners'Image
                & " such corners: the corner diagonally across takes a stair at" & Diag_Takes'Image
                & ", is level too at" & Diag_Level'Image & ", is neither at" & Diag_Other'Image
                & "; one stair at each corner diagonally across from a level one:" & Diag_Stairs'Image & " stairs at"
                & Diag_Squares'Image & " squares, and" & Diag_Mid_None'Image & " of the" & Mid_Squares'Image
                & " squares with a stair at a side's middle have none; one at every corner that takes one and is not"
                & " level:" & Each_Stairs'Image & " stairs at" & Each_Squares'Image & " squares");
      Put_Line ("square scan, walls outside the floor:" & Out_Squares'Image & " of them founded so;" & Strip_Squares'Image
                & " with a strip kept," & Strip_Sides'Image & " sides," & Rings_All'Image & " rings in all; of those sides"
                & Short_Sides'Image & " are asked more rings by their path as laid than were kept and" & Spare_Sides'Image
                & " fewer;" & Bare_Sides'Image & " sides with none kept are asked for a wall;" & Short_Cols'Image
                & " columns of wall steeper for want of a ring," & Bare_Cols'Image
                & " edge columns of floor left an earth bank;" & Inside_All'Image
                & " columns of floor of stone that are no stair's;" & Capped_All'Image
                & " columns of strip capped with stone at the path's level (" & Img (Capped_Most)
                & " at the most);" & Level_Off'Image & " founded at another level than they were planned at;"
                & Plan_Only'Image & " planned and not founded;" & Fire_Off'Image
                & " with the fire's place more than 2 m off the floor's level");
   end Square_Scan;

   --  --herd-scan R STEP: a colony founded (a plain stake, a band of six with no jobs) at every
   --  place of that grid that has land to stand on, and its herds looked at where they were put
   --  and a game hour on.  A herd's node or a deer that stands more than Aloft_M over the land
   --  as the generator made it is up a tree or on a boulder: the land's height is the
   --  generator's own (Castle.Maps.Height), so that nothing the walking map says is taken for
   --  it; what the floor it stands on is made of is read from the blocks.  One still up there
   --  after the hour could not walk off it.  (John, 2026-11-22, with a picture of deer up a
   --  spruce: "get stuck in the tree if they spawn in inside a tree?")
   Herd_R    : Float := 0.0;
   Herd_Step : Float := 20.0;
   procedure Herd_Scan is
      use Castle.Colony;
      N : constant Integer := Integer (Float'Floor (Herd_R / Herd_Step));
      Aloft_M : constant := 1.5;
      Sites, No_Land, Founded, Herds_Put, Herds_Aloft, Deer_Put, Deer_Aloft, Deer_Left_Aloft : Natural := 0;
      Herds_Held, Deer_Held, Deer_Left_Held : Natural := 0;     --  (that cannot walk off where they are: Castle.Herds.Can_Walk_Off)
      On_Trunk, On_Rock, On_Other : Natural := 0;
      function Land (P : Vec3) return Float is
        (W.Height (Castle.Fields.Idx (Integer (Float'Floor (P.X)), Integer (Float'Floor (P.Y)))));
      --  What the floor at P stands on: of the four block columns of its cell, a trunk's first,
      --  then a boulder's, then whatever else is solid there.
      function Under (P : Vec3) return Material is
         Bx0 : constant Integer := 2 * Integer (Float'Floor (P.X / Castle.Nav.Cell_M));
         By0 : constant Integer := 2 * Integer (Float'Floor (P.Y / Castle.Nav.Cell_M));
         Bz  : constant Integer := Integer (Float'Floor (P.Z * 4.0 + 0.5)) - 1;
         Found : Material := Air;
      begin
         for K in 0 .. 3 loop
            declare
               M : constant Material := Castle.World_Blocks.Block_At (Bx0 + K mod 2, By0 + K / 2, Bz).Mat;
            begin
               if M in Trunk then
                  return M;
               elsif M = Boulder or else (Found = Air and then Class_Of (M) = Solid) then
                  Found := M;
               end if;
            end;
         end loop;
         return Found;
      end Under;
      --  (a deer: that far over the land and on a trunk or a boulder.  On a mountainside the land's
      --  height, kept by the metre, is itself a metre or two off under a deer standing on bare rock.)
      function Up_There (P : Vec3) return Boolean is
        (P.Z - Land (P) > Aloft_M and then (Under (P) in Trunk or else Under (P) = Boulder));
   begin
      Castle.Herds.Set_Walk_Off (not Scn.Herds_Anywhere);   --  (the scenario is not applied here: its one option that bears)
      for I in -N .. N loop
         for J in -N .. N loop
            declare
               X : constant Float := Scn.Stake_X + Float (I) * Herd_Step;
               Y : constant Float := Scn.Stake_Y + Float (J) * Herd_Step;
               Z : Float;
            begin
               Sites := Sites + 1;
               Reset;
               Load_Ground (X, Y);
               Z := Castle.Nav.Surface_Z (X, Y);
               if Z < 0.0 or else Z - Land ((X, Y, Z)) > Aloft_M then
                  No_Land := No_Land + 1;                  --  (water, a wall of rock, a tree's top: no stake)
               else
                  Place_Stake ((X, Y, Z), 6, Seed);
               end if;
               if Has_Stake then
                  Founded := Founded + 1;
                  Advance (1.0, Hours);                    --  (its herds are put down at its first step)
                  for H in 1 .. Castle.Herds.Herd_Count loop
                     declare
                        Nd : constant Vec3 := Castle.Herds.Node (H);
                        Up : constant Float := Nd.Z - Land (Nd);
                     begin
                        Herds_Put := Herds_Put + 1;
                        if not Castle.Herds.Can_Walk_Off (Nd) then
                           Herds_Held := Herds_Held + 1;
                        end if;
                        if Up > Aloft_M then
                           Herds_Aloft := Herds_Aloft + 1;
                           if Under (Nd) in Trunk then
                              On_Trunk := On_Trunk + 1;
                           elsif Under (Nd) = Boulder then
                              On_Rock := On_Rock + 1;
                           else
                              On_Other := On_Other + 1;
                           end if;
                           Put_Line ("herd scan: stake " & Img (X, 1) & " " & Img (Y, 1) & ": herd" & H'Image
                                     & " put at " & Img (Nd.X, 2) & " " & Img (Nd.Y, 2) & " " & Img (Nd.Z, 2) & ", "
                                     & Img (Up, 2) & " m over the land, on " & Material'Image (Under (Nd)));
                        end if;
                     end;
                  end loop;
                  for K in 1 .. Castle.Herds.Deer_Slots loop
                     if Castle.Herds.Alive (K) then
                        Deer_Put := Deer_Put + 1;
                        if Up_There (Castle.Herds.Where (K)) then
                           Deer_Aloft := Deer_Aloft + 1;
                        end if;
                        if not Castle.Herds.Can_Walk_Off (Castle.Herds.Where (K)) then
                           Deer_Held := Deer_Held + 1;
                        end if;
                     end if;
                  end loop;
                  for S in 1 .. 60 loop
                     Advance (1.0, Hours + Long_Float (S) / 60.0);
                  end loop;
                  for K in 1 .. Castle.Herds.Deer_Slots loop
                     if Castle.Herds.Alive (K) and then Up_There (Castle.Herds.Where (K)) then
                        Deer_Left_Aloft := Deer_Left_Aloft + 1;
                     end if;
                     if Castle.Herds.Alive (K) and then not Castle.Herds.Can_Walk_Off (Castle.Herds.Where (K)) then
                        Deer_Left_Held := Deer_Left_Held + 1;
                        declare
                           P : constant Vec3 := Castle.Herds.Where (K);
                           N : Natural;
                           F : Castle.Nav.Floor_List;
                           Line : Unbounded_String;
                        begin
                           Castle.Nav.Floors_At (Integer (Float'Floor (P.X / Castle.Nav.Cell_M)),
                                                 Integer (Float'Floor (P.Y / Castle.Nav.Cell_M)), N, F);
                           for Q in 1 .. N loop
                              Append (Line, " [" & Img (Float (F (Q).Z) * 0.25, 2) & " m, water" & F (Q).Water'Image
                                            & (if F (Q).Speed > 0.0 then "" else ", not walked") & "]");
                           end loop;
                           Put_Line ("herd scan: stake " & Img (X, 1) & " " & Img (Y, 1) & ": a deer at " & Img (P.X, 2) & " "
                                     & Img (P.Y, 2) & " " & Img (P.Z, 2) & " cannot walk off, an hour on: "
                                     & Img (P.Z - Land (P), 2) & " m over the land, on " & Material'Image (Under (P))
                                     & "; its cell's floors:" & To_String (Line));
                        end;
                     end if;
                  end loop;
               end if;
            end;
         end loop;
      end loop;
      Put_Line ("herd scan:" & Sites'Image & " places," & No_Land'Image & " with no land to stake," & Founded'Image
                & " founded;" & Herds_Put'Image & " herds put down," & Herds_Aloft'Image & " more than "
                & Img (Float (Aloft_M), 1) & " m over the land (" & Img (On_Trunk) & " on a trunk, " & Img (On_Rock)
                & " on a boulder, " & Img (On_Other) & " on something else);" & Deer_Put'Image & " deer,"
                & Deer_Aloft'Image & " of them put down that far up a trunk or a boulder, and" & Deer_Left_Aloft'Image
                & " up one a game hour on");
      Put_Line ("herd scan: where a deer cannot walk " & Img (Float (Castle.Herds.Leave_M), 0) & " m off (up a step, down a metre, into no"
                & " water):" & Herds_Held'Image & " herds put down," & Deer_Held'Image & " deer put down, and" & Deer_Left_Held'Image
                & " deer a game hour on");
   end Herd_Scan;

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

   --  Every edit undone: the land as the generator makes it, wherever the colony has written since
   --  this was last called.  For a scan that builds on the spot at one place after another whose
   --  ground overlaps (a stockyard against each side of every square of a 20 m grid: what was built
   --  for the last one stood in the next one's ground).  The colony is to be Reset before it.
   procedure Land_Back is
   begin
      Castle.Edits.Clear;
      for CX in Touched'Range (1) loop
         for CY in Touched'Range (2) loop
            if Touched (CX, CY) then
               Touched (CX, CY) := False;
               Dirty (CX, CY) := False;
               if States (CX, CY) = In_Place then
                  Ask (CX, CY);
               end if;
            end if;
         end loop;
      end loop;
      Any_Dirty := False;
      Take_All;
   end Land_Back;

   --  (house K's bed: whether there is a way to it from the stake, and how many points of it, a
   --  tenth of a metre apart, are in a wall of K as it is drawn)
   function Bed_Way (K : Positive; V : Castle.Colony.House_View) return String is
      R  : constant Castle.Nav.Route := Castle.Nav.Plan (Castle.Colony.Stake, V.Bed);
      In_W : Natural := 0;
      use type Castle.Colony.Drawn_Place;
   begin
      for I in 1 .. R.N - 1 loop
         declare
            A : constant Vec3 := R.Pts (I).P;
            B : constant Vec3 := R.Pts (I + 1).P;
            N : constant Positive := Integer'Max (1, Integer (Ada.Numerics.Elementary_Functions.Sqrt ((B.X - A.X) ** 2 + (B.Y - A.Y) ** 2) * 10.0));
         begin
            for J in 0 .. N - 1 loop
               declare
                  Q : constant Vec3 := A + (B - A) * (Float (J) / Float (N));
               begin
                  if V.Walked_Drawn and then Castle.Colony.House_Place (K, Q.X, Q.Y) = Castle.Colony.In_Its_Wall then
                     In_W := In_W + 1;
                  end if;
               end;
            end loop;
         end;
      end loop;
      return Castle.Nav.Outcome'Image (R.Result) & (if V.Walked_Drawn then "," & In_W'Image & " points of it in a wall"
                                                    else "");
   end Bed_Way;

   --  (where member I's way runs from and to, and how long it is)
   function Way_Ends (I : Positive) return String is
      R   : constant Castle.Colony.Route_View := Castle.Colony.Route_Of (I);
      Len : Float := 0.0;
   begin
      if Castle.Colony."=" (R, null) or else R.N < 2 then
         return "";
      end if;
      for K in 1 .. R.N - 1 loop
         Len := Len + Ada.Numerics.Elementary_Functions.Sqrt
           ((R.Pts (K + 1).P.X - R.Pts (K).P.X) ** 2 + (R.Pts (K + 1).P.Y - R.Pts (K).P.Y) ** 2);
      end loop;
      return " (its way from " & Img (R.Pts (1).P.X, 1) & " " & Img (R.Pts (1).P.Y, 1) & " to "
        & Img (R.Pts (R.N).P.X, 1) & " " & Img (R.Pts (R.N).P.Y, 1) & ", " & Img (Len, 1) & " m)";
   end Way_Ends;

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
   Store_Stats : Boolean := False;       --  --store-stats: who stood for want of room in the stockpiles, at the end
   --  --tree-stats: what the foresters did, a colony second at a time, and
   --  what stood to fell (John, 2026-11-19: "foresters not finding trees in
   --  range"): at each log line the trees standing by how far from the stake;
   --  at the end each forester's hours by what its status said.
   Tree_Stats  : Boolean := False;
   --  --haul-stats: how far loads are carried (the logistics network's measure: metres walked with
   --  something in the arms for each load put down), sampled a colony second at a time.
   Haul_Stats  : Boolean := False;
   --  --feet-stats: how far each of the band's feet are off the floor nearest them of the cell they
   --  are in (the walking map's), a colony second at a time: ground dug or filled under someone
   --  standing on it leaves them in it or over it until they are settled on it.  The worst, when and
   --  whose; the serf-seconds more than a step (half a metre) off, and more than a block; and the
   --  first fourteen of those more than a step off, each with what it was doing.  (Between two cells
   --  a step apart the feet are up to a step off one of them, and stepping down a bank up to a
   --  metre: that much is ordinary, and it is walking.  Someone standing so is the fault.)
   Feet_Stats  : Boolean := False;
   --  --builder-stats: who stands in the ground (a solid block in its own block column at the row of
   --  its feet or the row over it), by what its status says; and how far the builders walk between
   --  two pieces of a site's ground ("going to make the ground ready for ..."), a hovel's and the
   --  storehouse's apart, with how many pieces.  --builder-list N: the first N in the ground, each said.
   --  --seam-stats [M]: at the end, over the block columns within M metres of the stake (60): where trodden
   --  ground (footpath on top: a path laid, a door's way, a floor) lies two blocks or more off the
   --  trodden ground beside it (a jump: half a metre, the most a serf climbs), a block off it (a step),
   --  and the columns of earth or turf left standing a block or more over trodden ground on both sides
   --  of them, or over trodden ground on one side and a hovel's lot on the other (a ridge between a path
   --  and what is built).  --seam-list N: the first N jumps and ridges, each said (12).
   Seam_Stats : Boolean := False;
   Seam_M     : Float := 60.0;
   Seam_List  : Natural := 12;
   Seam_Every_S : Natural := 0;       --  --seam-hours H: counted every H game hours too
   --  --ground-map X0 Y0 X1 Y1: at the end, the block columns of that box (metres) drawn twice, north at
   --  the top: the row of each one's top over the lowest in the box (0 .. 9, a .. z), and whose each is
   --  (P: a path laid, its top footpath; S: stone laid; #: a house's own blocks; l: a hovel's lot; p: a
   --  path planned and not laid; 1 .. 9: that zone's ground; a dot: nobody's).  For looking at how a
   --  path, a zone and what is built meet.  Up to four boxes.
   type Map_Box is array (1 .. 4) of Float;
   Map_Boxes : array (1 .. 4) of Map_Box;
   Map_N     : Natural := 0;
   --  --place-stats: at the end, of the places of the stockpiles (not the stockyard's) that hold something:
   --  how many have a block column of their square metre over the place's own level (what lies there is
   --  drawn at that level: the column stands through it) or under it (it lies over air), and by how many
   --  blocks at the most; and how many of them lie beside the cart's wheels or under its shafts.
   Place_Stats : Boolean := False;
   --  --flat-scan: at the end, of every stockpile (not the stockyard): the ground it lies on, and what one
   --  level under all of it would take, for three levels: the lowest of its ground beside a path (the low
   --  corner of its front), the middle (the median) of its ground beside a path, and the middle of all its
   --  ground.  For each: the deepest cut, the highest fill, the blocks moved, and how much of its front
   --  (its block columns that have a path's column beside them) would lie within two blocks of that
   --  path's column: a step a serf walks both ways.
   Flat_Scan : Boolean := False;
   --  What the runner's measures take for the ground's own blocks: the land, whatever it is made
   --  of, a path's surface and stone laid dry.  (Until 2026-11-23 each measure had its own list,
   --  none with ore or a boulder in it: where bog iron lies in the turf, three block columns in
   --  ten at the reference stake, the ground read a block low, and 27 of 29 places there read
   --  as having a block column under their level.)
   function Is_Land (M : Material) return Boolean is
     (M in Bedrock | Granite | Limestone | Sandstone | Dirt | Grass | Sand | Gravel | Clay
         | Coal | Iron_Ore | Bog_Iron | Silver_Ore | Gold_Ore | Rock_Salt | Placer_Gravel | Boulder | Deep
         | Footpath | Fieldstone);
   --  --column BX BY: at the end, what stands in that block column (block coordinates, as a ground map
   --  counts them) from six rows over its ground's top to six under it, and whose it is.
   Column_N : Natural := 0;
   Column_At : array (1 .. 16, 1 .. 2) of Integer := [others => [others => 0]];
   --  --carcass-stats: every whole deer that comes to lie on a stockpile's ground, said (the first twelve),
   --  how long each lay there, and at the end how often one was laid down unbutchered, by why.
   Carcass_Stats : Boolean := False;
   Carcass_Lay_S : Natural := 0;                    --  carcass-seconds lying on a stockpile's ground
   Carcass_Lay_N : Natural := 0;                    --  times one came to lie there
   Carcass_Longest : Natural := 0;
   Carcass_Run : array (1 .. 64) of Natural := [others => 0];
   Builder_Stats : Boolean := False;
   Builder_List  : Natural := 12;
   --  --watch MEMBER S0 S1: that member each colony second from S0 to S1: where its feet are, the top
   --  of the ground in its own block column, the walking map's floors of the cell it is in, what its
   --  status says and where its hands go.  (For finding why someone stands in the ground or over it.)
   Watch_Who : Natural := 0;
   Watch_S0, Watch_S1 : Natural := 0;
   Builder_Track : Unbounded_String;   --  --builder-track FILE: a line for each piece of ground begun (the second, who,
   Builder_Track_F : Ada.Text_IO.File_Type;   --  its house, 1 for the storehouse, where it stands, where its hands go)
   In_Ground_S   : Natural := 0;       --  serf-seconds in the ground
   In_Ground_Level, In_Ground_Lay : Natural := 0;   --  of them, levelling a site's ground; at any other work on a house
   In_Ground_Runs : Natural := 0;      --  times someone came to be in the ground (was not, the second before)
   In_Ground_Longest : Natural := 0;   --  the longest run of seconds
   type Site_Walk is record
      M      : Long_Float := 0.0;      --  metres walked going to make ground ready
      Pieces : Natural := 0;           --  pieces of ground worked ("levelling the ground for ...": begun)
      Work_S : Natural := 0;           --  seconds levelling
      Walk_S : Natural := 0;           --  seconds going to a piece
      Next_N : Natural := 0;           --  pieces begun within a minute of the one before, at the same house
      Next_M : Long_Float := 0.0;      --  and how far each was from where the one before was worked from, summed
      Far_N  : Natural := 0;           --  of those, more than three metres off
   end record;
   Walks : array (Boolean) of Site_Walk;        --  (True: the storehouse's)
   type Builder_Was is record
      P        : Vec3 := (0.0, 0.0, 0.0);
      Seen     : Boolean := False;
      Going    : Boolean := False;
      Levelling : Boolean := False;
      In_Run   : Natural := 0;
      Last_P   : Vec3 := (0.0, 0.0, 0.0);     --  where it last stood levelling,
      Last_S   : Natural := 0;                --  when (0: never),
      Last_H   : Natural := 0;                --  and at which house
   end record;
   In_Ground_Deepest : Natural := 0;   --  the most rows of blocks over anyone's feet, in its own column
   Help_S, Help_Most_Seen : Natural := 0;   --  serf-seconds helping at another's house; the most builders at one house at once
   Store_Stood_S : Natural := 0;            --  the colony second the storehouse was first seen standing (0: not)
   Builders_Were : array (1 .. Castle.Colony.Max_Members) of Builder_Was;
   Feet_Worst  : Float := 0.0;
   Feet_Worst_S : Natural := 0;
   Feet_Worst_I : Natural := 0;
   Feet_Worst_At : Vec3 := (0.0, 0.0, 0.0);
   Feet_Over_Step, Feet_Over_Block, Feet_Seen : Natural := 0;
   Feet_Air : Natural := 0;                        --  (standing still more than half a metre over its own column's ground)
   Feet_Deep : Natural := 0;                       --  (more than a metre over it, moving or not)
   Feet_Air_List : Natural := 10;                  --  (--feet-air-list N: so many of them listed)
   Feet_Prev : array (1 .. 64) of Vec3 := [others => (0.0, 0.0, -1.0)];
   --  --turn-stats: the ground under the hovels drawn turned (John, 2026-11-19: "can't we just
   --  \"detatch\" the entire building and rotate it?"), at the end: for each, the block columns it is
   --  drawn on off its walls' own place, those not at its pad's level, those with something growing
   --  over them; and, a colony second at a time, who stood there (its builder, its owner, anyone else).
   --  And of a storehouse drawn turned on a stockyard laid out along its path (John, 2026-11-20: "go
   --  on with the second way for the stockyard"): the block columns of all its ground, those not at
   --  their level, those grown over; and, from when the feet go by it as it is drawn, the serf-seconds
   --  spent within it as drawn, where its own blocks stand, and in a wall as drawn (there should be none).
   Turn_Stats  : Boolean := False;
   --  --box-stats: each zone that was put down whole with its path (John, 2026-11-20: "let's lock the
   --  size of the stockpile ... a square box ... including the path in front"), at the start and at
   --  the end: where its front begins, which way it is turned, the block columns in its box and whose
   --  they are, and how many places it has.
   Box_Stats   : Boolean := False;
   type Turn_Rec is record
      Builder_S, Owner_S, Other_S : Natural := 0;       --  on the ground it is drawn on, off its walls' place
      Stood_S                     : Natural := 0;       --  the seconds of those it stood (was built) for
      Other_Stood_S               : Natural := 0;       --  anyone else there while it stood
      --  (a storehouse walked where it is drawn, in serf-seconds from when it is)
      Walked_S                    : Natural := 0;       --  the seconds it has been walked so
      In_Wall_S, Within_S, On_Blocks_S : Natural := 0;  --  in a wall as drawn; within it; where its blocks stand
   end record;
   Turn_Was : array (1 .. Castle.Colony.Max_Houses) of Turn_Rec;
   Haul_M      : Long_Float := 0.0;
   Haul_Loads  : Natural := 0;
   type Haul_Rec is record
      P    : Vec3 := (0.0, 0.0, 0.0);
      Had  : Boolean := False;
      Seen : Boolean := False;
   end record;
   Haul_Was : array (1 .. Castle.Colony.Max_Members) of Haul_Rec;
   type Said_Rec is record
      Text : Unbounded_String;
      S    : Natural := 0;
   end record;
   Said   : array (1 .. 96) of Said_Rec;
   N_Said : Natural := 0;
   --  --work-stats: what the gatherers, the porters and the hunters were doing, a colony second at
   --  a time, by what each one's status said (John, 2026-11-19: "Let workers go 250m for
   --  resources"): at the end, each job's serf-hours by status.
   Work_Stats : Boolean := False;
   Work_Said  : array (1 .. 256) of Said_Rec;
   N_Work     : Natural := 0;
   procedure Note_Work (T : String) is
   begin
      for K in 1 .. N_Work loop
         if To_String (Work_Said (K).Text) = T then
            Work_Said (K).S := Work_Said (K).S + 1;
            return;
         end if;
      end loop;
      if N_Work < Work_Said'Last then
         N_Work := N_Work + 1;
         Work_Said (N_Work) := (To_Unbounded_String (T), 1);
      end if;
   end Note_Work;
   procedure Note_Said (T : String) is
   begin
      for K in 1 .. N_Said loop
         if To_String (Said (K).Text) = T then
            Said (K).S := Said (K).S + 1;
            return;
         end if;
      end loop;
      if N_Said < Said'Last then
         N_Said := N_Said + 1;
         Said (N_Said) := (To_Unbounded_String (T), 1);
      end if;
   end Note_Said;
   procedure Put_Trees (Ways : Boolean := False) is
      use type Castle.Colony.Tree_Kind;
      Near, Near_Apple, Near_Held, Ring_1, Ring_2, Far : Natural := 0;
      St : constant Vec3 := Castle.Colony.Stake;
   begin
      for K in 1 .. Castle.Colony.Tree_Count loop
         if not Castle.Colony.Tree_Down (K) then
            declare
               B : constant Vec3 := Castle.Colony.Tree_Base (K);
               D : constant Float := Ada.Numerics.Elementary_Functions.Sqrt ((B.X - St.X) ** 2 + (B.Y - St.Y) ** 2);
            begin
               if D <= Castle.Colony.Work_Radius_M then
                  if Castle.Colony.Tree_At (K).Kind = Castle.Colony.Apple then
                     Near_Apple := Near_Apple + 1;
                  else
                     Near := Near + 1;
                     if Castle.Colony.Tree_Reserved_By (K) > 0 then
                        Near_Held := Near_Held + 1;
                     end if;
                  end if;
               elsif Castle.Colony.Tree_At (K).Kind = Castle.Colony.Apple then
                  null;
               elsif D <= 80.0 then
                  Ring_1 := Ring_1 + 1;
               elsif D <= 100.0 then
                  Ring_2 := Ring_2 + 1;
               else
                  Far := Far + 1;
               end if;
            end;
         end if;
      end loop;
      Put_Line ("  trees standing: within" & Integer'Image (Integer (Castle.Colony.Work_Radius_M)) & " m of the stake"
                & Near'Image & " to fell (" & Img (Near_Held) & " somebody's)," & Near_Apple'Image
                & " apple trees; to fell 60 to 80 m off" & Ring_1'Image & ", 80 to 100 m" & Ring_2'Image
                & ", further" & Far'Image & "; felled so far" & Castle.Colony.Trees_Felled'Image);
      if Ways then                 --  (at the end: which of them can be got to from the stake)
         declare
            use type Castle.Nav.Outcome;
            Reach : constant Float := Castle.Colony.Fell_Reach_M;
            In_N, Way_N : Natural := 0;
         begin
            for K in 1 .. Castle.Colony.Tree_Count loop
               if not Castle.Colony.Tree_Down (K) and then Castle.Colony.Tree_At (K).Kind /= Castle.Colony.Apple then
                  declare
                     B : constant Vec3 := Castle.Colony.Tree_Base (K);
                     D : constant Float := Ada.Numerics.Elementary_Functions.Sqrt ((B.X - St.X) ** 2 + (B.Y - St.Y) ** 2);
                  begin
                     if D <= Reach then
                        In_N := In_N + 1;
                        if Castle.Nav.Plan (St, B, Refuse => True).Result = Castle.Nav.Found then
                           Way_N := Way_N + 1;
                        end if;
                     end if;
                  end;
               end if;
            end loop;
            Put_Line ("  trees to fell within " & Img (Reach, 0) & " m of the stake (how far the foresters look):"
                      & In_N'Image & ", of which" & Way_N'Image & " can be got to from the stake;"
                      & Castle.Colony.Trees_Left_Untried'Image & " left untried by the foresters now");
            Put_Line ("  the gatherers look " & Img (Castle.Colony.Food_Reach_M, 0) & " m from the stake, the porters "
                      & Img (Castle.Colony.Haul_Reach_M, 0) & " m");
         end;
      end if;
      if Near in 1 .. 12 then      --  (few left near: where each stands)
         for K in 1 .. Castle.Colony.Tree_Count loop
            if not Castle.Colony.Tree_Down (K) and then Castle.Colony.Tree_At (K).Kind /= Castle.Colony.Apple then
               declare
                  B : constant Vec3 := Castle.Colony.Tree_Base (K);
                  D : constant Float := Ada.Numerics.Elementary_Functions.Sqrt ((B.X - St.X) ** 2 + (B.Y - St.Y) ** 2);
               begin
                  if D <= Castle.Colony.Work_Radius_M then
                     Put_Line ("    to fell near: at " & Img (B.X, 1) & " " & Img (B.Y, 1) & " " & Img (B.Z, 1) & ", "
                               & Img (D, 1) & " m from the stake"
                               & (if Castle.Colony.Tree_Reserved_By (K) > 0
                                  then ", " & Castle.Colony.Name_Of (Castle.Colony.Tree_Reserved_By (K)) & "'s" else ""));
                  end if;
               end;
            end if;
         end loop;
      end if;
   end Put_Trees;
   Note_Told   : Natural := 0;           --  (the storehouse note last printed)
   Keeper_Told, Carp_Told : Natural := 0;   --  (the stockman and the carpenter last printed)
   Made_Told   : Natural := 0;           --  (the storehouse's shelves and barrels made, last printed)
   Front_Told  : Boolean := False;       --  (the lord's cart at the storehouse's front, printed)
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

   --  --seam-stats: the count (at the end, and with --seam-hours H every H game hours).
   procedure Put_Seams (Said : String) is
      St  : constant Vec3 := Castle.Colony.Stake;
      Bx0 : constant Integer := Integer (Float'Floor ((St.X - Seam_M) * 4.0));
      Bx1 : constant Integer := Integer (Float'Floor ((St.X + Seam_M) * 4.0));
      By0 : constant Integer := Integer (Float'Floor ((St.Y - Seam_M) * 4.0));
      By1 : constant Integer := Integer (Float'Floor ((St.Y + Seam_M) * 4.0));
      Mid_Z : constant Integer := Integer (St.Z * 4.0);
      type Top_Rec is record
         Z : Integer := Integer'First;
         M : Material := Air;
      end record;
      type Top_Grid is array (Integer range <>, Integer range <>) of Top_Rec;
      type Top_Grid_Access is access Top_Grid;
      procedure Free is new Ada.Unchecked_Deallocation (Top_Grid, Top_Grid_Access);
      --  (indexed from 0: this compiler reads a two-dimensional array with negative bounds wrongly)
      T : Top_Grid_Access := new Top_Grid (0 .. Bx1 - Bx0, 0 .. By1 - By0);
      function Ground (M : Material) return Boolean is (Is_Land (M));
      function At_T (X, Y : Integer) return Top_Rec is
        (if X in Bx0 .. Bx1 and then Y in By0 .. By1 then T (X - Bx0, Y - By0) else (others => <>));
      function Trod (X, Y : Integer) return Boolean is (At_T (X, Y).M = Footpath);
      function Earth (X, Y : Integer) return Boolean is (At_T (X, Y).M in Dirt | Grass);
      function Lot (X, Y : Integer) return Boolean is
        (Castle.Colony.Hovel_At ((Float (X) + 0.5) * 0.25, (Float (Y) + 0.5) * 0.25) > 0);
      Jumps, Steps, Pairs, Ridges, Listed : Natural := 0;
      Highest : Natural := 0;
      function Where (X, Y : Integer) return String is
        (Img ((Float (X) + 0.5) * 0.25, 2) & ", " & Img ((Float (Y) + 0.5) * 0.25, 2));
   begin
      for X in Bx0 .. Bx1 loop
         for Y in By0 .. By1 loop
            for Z in reverse Mid_Z - 80 .. Mid_Z + 80 loop
               declare
                  M : constant Material := Castle.World_Blocks.Block_At (X, Y, Z).Mat;
               begin
                  if Ground (M) then
                     T (X - Bx0, Y - By0) := (Z, M);
                     exit;
                  end if;
               end;
            end loop;
         end loop;
      end loop;
      for X in Bx0 .. Bx1 loop
         for Y in By0 .. By1 loop
            if Trod (X, Y) then
               for Way in 1 .. 2 loop
                  declare
                     Nx : constant Integer := X + (if Way = 1 then 1 else 0);
                     Ny : constant Integer := Y + (if Way = 1 then 0 else 1);
                     D  : Natural;
                  begin
                     if Trod (Nx, Ny) then
                        Pairs := Pairs + 1;
                        D := abs (At_T (X, Y).Z - At_T (Nx, Ny).Z);
                        if D = 1 then
                           Steps := Steps + 1;
                        elsif D >= 2 then
                           Jumps := Jumps + 1;
                           Highest := Natural'Max (Highest, D);
                           if Listed < Seam_List then
                              Listed := Listed + 1;
                              Put_Line ("seam " & Said & ": a jump of" & D'Image & " blocks between trodden ground at " & Where (X, Y)
                                        & " (" & Img (Float (At_T (X, Y).Z + 1) * 0.25, 2) & " m) and at "
                                        & Where (Nx, Ny) & " (" & Img (Float (At_T (Nx, Ny).Z + 1) * 0.25, 2) & " m)");
                           end if;
                        end if;
                     end if;
                  end;
               end loop;
            elsif Earth (X, Y) then
               declare
                  Z : constant Integer := At_T (X, Y).Z;
                  function Low_Trod (Dx, Dy : Integer) return Boolean is
                    (Trod (X + Dx, Y + Dy) and then At_T (X + Dx, Y + Dy).Z < Z);
                  function Low_Lot (Dx, Dy : Integer) return Boolean is
                    (At_T (X + Dx, Y + Dy).Z < Z and then At_T (X + Dx, Y + Dy).Z > Integer'First
                     and then Lot (X + Dx, Y + Dy));
                  Is_Ridge : constant Boolean :=
                    (Low_Trod (-1, 0) and then (Low_Trod (1, 0) or else Low_Lot (1, 0)))
                    or else (Low_Trod (1, 0) and then Low_Lot (-1, 0))
                    or else (Low_Trod (0, -1) and then (Low_Trod (0, 1) or else Low_Lot (0, 1)))
                    or else (Low_Trod (0, 1) and then Low_Lot (0, -1));
               begin
                  if Is_Ridge then
                     Ridges := Ridges + 1;
                     if Listed < Seam_List then
                        Listed := Listed + 1;
                        Put_Line ("seam " & Said & ": a column of earth left standing at " & Where (X, Y) & " (" & Img (Float (Z + 1) * 0.25, 2)
                                  & " m), trodden ground lower on one side of it and trodden ground or a hovel's lot"
                                  & " lower on the other");
                     end if;
                  end if;
               end;
            end if;
         end loop;
      end loop;
      Put_Line ("seams " & Said & ", within " & Img (Seam_M, 0) & " m of the stake: of" & Pairs'Image
                & " pairs of block columns of trodden ground side by side," & Jumps'Image
                & " lie two blocks or more apart (the most" & Highest'Image & ") and" & Steps'Image
                & " one block;" & Ridges'Image
                & " columns of earth are left standing between trodden ground and trodden ground or a hovel's lot;"
                & Castle.Colony.Path_Columns_Stepped'Image & " blocks cut off or put under paths to step them,"
                & Castle.Colony.Door_Columns_Remade'Image & " columns of doors' ways made again");
      Free (T);
   end Put_Seams;

   --  An order given later in the run (--later), as the player gives it: through Castle.Actions.Perform.
   procedure Give_Later (L : Later_Order) is
      use Castle.Actions;
      use Castle.Colony;
      function At_Ground (X, Y : Float) return Vec3 is ((X, Y, Castle.Nav.Surface_Z (X, Y)));
      R : Result;
      Flat_0 : Natural := 0;        --  (the stockpiles made one level before the order)
      Hour_Said : constant String := "later, after " & Img (Float (L.At_S) / 60.0, 1) & " h: ";
   begin
      case L.Kind is
         when Later_Pull =>
            declare
               Begun : constant Vec3 := At_Ground (L.V (1), L.V (2));
               To_P  : constant Vec3 := At_Ground (L.V (3), L.V (4));
               Rows  : constant Pull_Rows := Pull_Rows'Val (Natural (L.V (5)) mod 3);
               O     : constant Order := (What => Pull_Housing, By => The_Player, Begun => Begun, Pulled_To => To_P, Rows => Rows);
            begin
               Perform (O, R);
               Put_Line (Hour_Said
                         & (if not R.Done then "housing pull refused: " & Why_Not (O, R)
                            else "housing pulled: " & Img (Pull_Path_M, 2) & " m of path new,"
                                 & Natural'Image (Pull_Rows_Zoned) & " rows zoned, room for" & R.Count'Image
                                 & " hovels" & (if Housing_Joined > 0 then ", joined to housing that was there" else "")
                                 & (if Pull_Gave_Way > 0
                                    then ";" & Natural'Image (Pull_Gave_Way) & " block columns of housing gave way under it"
                                    else "")));
            end;
         when Later_Path =>
            declare
               O : constant Order := (What => Lay_Path, By => The_Player, From => At_Ground (L.V (1), L.V (2)),
                                      To => At_Ground (L.V (3), L.V (4)));
            begin
               Perform (O, R);
               Put_Line (Hour_Said & (if R.Count = 0 then "path refused: " & Why_Not (O, R)
                                      else "path planned:" & R.Count'Image & " blocks of footpath to lay"));
            end;
         when Later_Box =>
            declare
               O : constant Order := (What => Place_Stockpile, By => The_Player, Pile_At => At_Ground (L.V (1), L.V (2)),
                                      Pile_Way => Natural (L.V (3)) mod 8);
            begin
               Flat_0 := Castle.Colony.Piles_Flattened;
               Perform (O, R);
               Put_Line (Hour_Said & (if not R.Done then "stockpile refused: " & Why_Not (O, R)
                                      else "stockpile put down:" & R.Count'Image & " places"));
               if Castle.Colony.Piles_Flattened > Flat_0 then
                  Put_Line (Hour_Said & "stockpile " & Castle.Colony.Last_Flat_Said);
               end if;
            end;
         when Later_Remove =>
            declare
               O : constant Order := (What => Remove_Stockpile, By => The_Player, Pile => Natural (L.V (1)), Remove => True);
            begin
               Perform (O, R);
               Put_Line (Hour_Said & (if not R.Done then "stockpile not removed: " & Why_Not (O, R)
                                      else "stockpile" & Natural'Image (Natural (L.V (1))) & " is to go: its places closed,"
                                           & Zone_At (Natural (L.V (1))).Holds (Wood)'Image & " logs and"
                                           & Zone_At (Natural (L.V (1))).Holds (Straw)'Image & " sheaves among what lies on it"));
            end;
         when Later_Job =>
            declare
               O : constant Order := (What => Give_Job, By => The_Player, Whom => Natural (L.V (1)), Job => L.Job);
            begin
               Perform (O, R);
               Put_Line (Hour_Said & (if not R.Done then "job refused: " & Why_Not (O, R)
                                      else Name_Of (Natural (L.V (1))) & " is now " & Job_Name (L.Job)));
            end;
      end case;
      if Box_Stats then
         Put_Boxes ("after that order");
      end if;
   end Give_Later;

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
         elsif A = "--floating" then
            Floating := True; I := I + 1;
         elsif A = "--workers" then
            Workers := Positive'Value (Argument (I + 1)); I := I + 2;
         elsif A = "--raze" then
            Raze_K := Natural'Value (Argument (I + 1));
            Raze_At_S := Natural (Float'Value (Argument (I + 2)) * 60.0); I := I + 3;
         elsif A = "--later" then
            Later_N := Later_N + 1;
            Later (Later_N).At_S := Natural (Float'Value (Argument (I + 1)) * 60.0);
            declare
               What : constant String := Argument (I + 2);
               N    : Natural := 0;
            begin
               if What = "housing-pull" then
                  Later (Later_N).Kind := Later_Pull; N := 5;
               elsif What = "path" then
                  Later (Later_N).Kind := Later_Path; N := 4;
               elsif What = "stockpile-box" then
                  Later (Later_N).Kind := Later_Box; N := 3;
               elsif What = "remove-stockpile" then
                  Later (Later_N).Kind := Later_Remove; N := 1;
               elsif What = "job" then
                  Later (Later_N).Kind := Later_Job; N := 1;
                  Later (Later_N).Job := Castle.Colony.Job_Kind'Value (Argument (I + 4));
               else
                  Put_Line ("--later: no order " & What);
                  GNAT.OS_Lib.OS_Exit (2);
               end if;
               for K in 1 .. N loop
                  Later (Later_N).V (K) := Float'Value (Argument (I + 2 + K));
               end loop;
               I := I + 3 + N + (if What = "job" then 1 else 0);
            end;
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
         elsif A = "--store-stats" then
            Store_Stats := True; I := I + 1;
         elsif A = "--tree-stats" then
            Tree_Stats := True; I := I + 1;
         elsif A = "--haul-stats" then
            Haul_Stats := True; I := I + 1;
         elsif A = "--feet-stats" then
            Feet_Stats := True; I := I + 1;
         elsif A = "--seam-stats" then
            Seam_Stats := True; I := I + 1;
            if I <= Argument_Count and then Argument (I)'Length > 0 and then Argument (I) (1) in '0' .. '9' then
               Seam_M := Float'Value (Argument (I)); I := I + 1;
            end if;
         elsif A = "--seam-list" then
            Seam_Stats := True;
            Seam_List := Natural'Value (Argument (I + 1)); I := I + 2;
         elsif A = "--seam-hours" then
            Seam_Stats := True;
            Seam_Every_S := Natural (Float'Value (Argument (I + 1)) * 60.0); I := I + 2;
         elsif A = "--ground-map" then
            Map_N := Map_N + 1;
            for K in 1 .. 4 loop
               Map_Boxes (Map_N) (K) := Float'Value (Argument (I + K));
            end loop;
            I := I + 5;
         elsif A = "--place-stats" then
            Place_Stats := True; I := I + 1;
         elsif A = "--flat-scan" then
            Flat_Scan := True; I := I + 1;
         elsif A = "--column" then
            if Column_N < 16 then
               Column_N := Column_N + 1;
               Column_At (Column_N, 1) := Integer'Value (Argument (I + 1));
               Column_At (Column_N, 2) := Integer'Value (Argument (I + 2));
            end if;
            I := I + 3;
         elsif A = "--carcass-stats" then
            Carcass_Stats := True; I := I + 1;
         elsif A = "--builder-stats" then
            Builder_Stats := True; I := I + 1;
         elsif A = "--watch" then
            Watch_Who := Natural'Value (Argument (I + 1));
            Watch_S0 := Natural'Value (Argument (I + 2));
            Watch_S1 := Natural'Value (Argument (I + 3));
            I := I + 4;
         elsif A = "--builder-list" then
            Builder_Stats := True;
            Builder_List := Natural'Value (Argument (I + 1)); I := I + 2;
         elsif A = "--builder-track" then
            Builder_Stats := True;
            Builder_Track := To_Unbounded_String (Argument (I + 1)); I := I + 2;
            Create (Builder_Track_F, Out_File, To_String (Builder_Track));
         elsif A = "--feet-air-list" then
            Feet_Stats := True;
            Feet_Air_List := Natural'Value (Argument (I + 1)); I := I + 2;
         elsif A = "--turn-stats" then
            Turn_Stats := True; I := I + 1;
         elsif A = "--box-stats" then
            Box_Stats := True; I := I + 1;
         elsif A = "--square-census" then
            Census_R := Float'Value (Argument (I + 1));
            Census_Step := Float'Value (Argument (I + 2));
            I := I + 3;
         elsif A = "--square-scan" then
            Scan_R := Float'Value (Argument (I + 1));
            Scan_Step := Float'Value (Argument (I + 2));
            I := I + 3;
         elsif A = "--herd-scan" then
            Herd_R := Float'Value (Argument (I + 1));
            Herd_Step := Float'Value (Argument (I + 2));
            I := I + 3;
         elsif A = "--square-scan-list" then
            Scan_List := True; I := I + 1;
         elsif A = "--square-pits" then
            Square_Pits := True; I := I + 1;
         elsif A = "--square-path" then
            Square_Path := True; I := I + 1;
         elsif A = "--walls-between" then
            Walls_Between := True; I := I + 1;
         elsif A = "--paths-backward" then
            Paths_Backward := True; I := I + 1;
         elsif A = "--wall-map" then
            Wall_Map := True; I := I + 1;
         elsif A = "--yard-map" then
            Yard_Map := True; I := I + 1;
         elsif A = "--yard-now" then
            Yard_Now := True; I := I + 1;
         elsif A = "--yard-pits" then
            Yard_Pits_On := True; I := I + 1;
         elsif A = "--yard-built" then
            Yard_Built := True; I := I + 1;
         elsif A = "--yard-walls" then
            Yard_Walls_Census := True; I := I + 1;
         elsif A = "--yard-census" then
            Yard_Census := True; I := I + 1;
         elsif A = "--yard-census-corners" then
            Yard_Census := True; Yard_Census_M := Natural'Value (Argument (I + 1)); I := I + 2;
         elsif A = "--walls-now" then
            Walls_Now := True; I := I + 1;
         elsif A = "--camp-now" then
            Camp_Now := True; I := I + 1;
         elsif A = "--work-stats" then
            Work_Stats := True; I := I + 1;
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
         if Box_Stats then
            Put_Boxes ("as loaded");
         end if;
      end;
   elsif Scn.Stake then
      Load_Ground (Scn.Stake_X, Scn.Stake_Y);
      if Census_R > 0.0 then
         Square_Census;
      end if;
      if Scan_R > 0.0 and then Yard_Census then
         Yard_Scan;
      elsif Scan_R > 0.0 then
         Square_Scan;
         Castle.Streaming.Stop;
         return;
      elsif Herd_R > 0.0 then
         Herd_Scan;
         Castle.Streaming.Stop;
         return;
      end if;
      Castle.Scenario.Apply (Scn, Seed);
      Rebuild_Dirty;
      if (Walls_Now or else Camp_Now) and then Castle.Colony.Camp_Is_Square then
         Castle.Colony.Build_Camp_Now;                --  (its camp, its paths and its walls from nowhere)
         if Walls_Between and then Walls_Now then
            Castle.Colony.Build_Paths_Now (Backward => Paths_Backward, Most => 26);
            Castle.Colony.Build_Walls_Now;
         end if;
         Castle.Colony.Build_Paths_Now (Backward => Paths_Backward);
         if Walls_Now then
            Castle.Colony.Build_Walls_Now;
         end if;
         Rebuild_Dirty;
      end if;
      if Box_Stats then
         Put_Boxes ("at the start");
      end if;
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
         for L of Later (1 .. Later_N) loop
            if S = L.At_S then
               Give_Later (L);
            end if;
         end loop;
         if Castle.Colony.Stockpiles_Removed > Removed_Seen then
            Removed_Seen := Castle.Colony.Stockpiles_Removed;
            Put_Line ("after " & Img (Float (S) / 60.0, 1) & " h: a stockpile ordered removed is gone, the last thing carried off it ("
                      & Castle.Colony.Cell_Count'Image & " places in all now)");
         end if;
         if Raze_K > 0 and then S = Raze_At_S then
            if Raze_K <= Castle.Colony.House_Count then
               Castle.Colony.Mark_Hovel (Raze_K, True);
               Put_Line ("raze: house" & Raze_K'Image & " of" & Castle.Colony.House_Count'Image
                         & (if Castle.Colony.House_At (Raze_K).Marked then " marked for razing"
                            else " not marked: it is lived in, or a storehouse"));
            else
               Put_Line ("raze: there is no house" & Raze_K'Image);
            end if;
         end if;
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
         if Seam_Stats and then Seam_Every_S > 0 and then S mod Seam_Every_S = 0 and then Castle.Colony.Has_Stake then
            Put_Seams ("after" & Natural'Image (S / 60) & " h");      --  (nothing of the run moves by it)
         end if;
         --  (a measure: when the square's walls were first counted as wanted, and when nothing was left)
         if Castle.Colony.Camp_Is_Square and then Castle.Colony.Walls_Left > 0 then
            if Walls_From < 0 then
               Walls_From := S;
               Walls_Most := Castle.Colony.Walls_Left;
            end if;
            Walls_Until := -1;
         elsif Walls_From >= 0 and then Walls_Until < 0 then
            Walls_Until := S;
         end if;
         if Feet_Stats then
            for I in 1 .. Castle.Colony.Members loop
               if not Castle.Colony.Dead (I) then
                  declare
                     W  : constant Vec3 := Castle.Colony.Where (I);
                     Fl : Castle.Nav.Floor_List;
                     Fn : Natural;
                     Off : Float := Float'Last;
                  begin
                     Castle.Nav.Floors_At (Integer (Float'Floor (W.X * 2.0)), Integer (Float'Floor (W.Y * 2.0)), Fn, Fl);
                     for K in 1 .. Fn loop
                        Off := Float'Min (Off, abs (W.Z - Float (Fl (K).Z) * 0.25));
                     end loop;
                     if Fn = 0 then
                        Off := 0.0;
                     end if;
                     Feet_Seen := Feet_Seen + 1;
                     if Off > 0.5 + 0.01 then
                        Feet_Over_Step := Feet_Over_Step + 1;
                        if Feet_Over_Step <= 14 then
                           Put_Line ("feet: after" & S'Image & " s " & Castle.Colony.Name_Of (I) & " ("
                                     & Castle.Colony.Doing (I)'Image & ") at " & Img (W.X, 2) & ", " & Img (W.Y, 2)
                                     & ", its feet at " & Img (W.Z, 2) & " m, the floor there "
                                     & Img (W.Z + (if Fn > 0 and then W.Z > Float (Fl (1).Z) * 0.25 then -Off else Off), 2)
                                     & " m");
                        end if;
                     end if;
                     if Off > 0.25 + 0.01 then
                        Feet_Over_Block := Feet_Over_Block + 1;
                     end if;
                     if Off > Feet_Worst then
                        Feet_Worst := Off;
                        Feet_Worst_S := S;
                        Feet_Worst_I := I;
                        Feet_Worst_At := W;
                     end if;
                     --  (and against the blocks of its own column, which the walking map's cells of four
                     --  columns do not show: one standing still more than half a metre over the ground
                     --  under its own feet stands in the air; in a house or on a ladder it is let be)
                     declare
                        Bx : constant Integer := Integer (Float'Floor (W.X * 4.0));
                        By : constant Integer := Integer (Float'Floor (W.Y * 4.0));
                        Bz : constant Integer := Integer (Float'Floor ((W.Z + 0.05) * 4.0));
                        Under : Integer := -1;
                        Still : constant Boolean := I in Feet_Prev'Range and then Feet_Prev (I) = W;
                     begin
                        for Z in reverse Integer'Max (1, Bz - 16) .. Bz + 1 loop
                           if Castle.Blocks.Class_Of (Castle.World_Blocks.Block_At (Bx, By, Z).Mat) in Castle.Blocks.Solid then
                              Under := Z;
                              exit;
                           end if;
                        end loop;
                        --  (more than a metre over it, moving or not: further than the drawn figure, which
                        --  finds its own ground, looks up for a way back onto what the colony stands it on)
                        if Under >= 0 and then W.Z - Float (Under + 1) * 0.25 > 1.0 + 0.01
                          and then Castle.Colony.House_On (W.X, W.Y) = 0
                        then
                           Feet_Deep := Feet_Deep + 1;
                        end if;
                        if Still and then Under >= 0 and then W.Z - Float (Under + 1) * 0.25 > 0.5 + 0.01
                          and then Castle.Colony.House_On (W.X, W.Y) = 0
                        then
                           Feet_Air := Feet_Air + 1;
                           if Feet_Air <= Feet_Air_List then
                              Put_Line ("feet in the air: after" & S'Image & " s " & Castle.Colony.Name_Of (I) & " ("
                                        & Castle.Colony.Status (I) & ") stands still at " & Img (W.X, 2) & ", "
                                        & Img (W.Y, 2) & ", its feet at " & Img (W.Z, 2) & " m, the ground under them at "
                                        & Img (Float (Under + 1) * 0.25, 2) & " m");
                           end if;
                        end if;
                        if I in Feet_Prev'Range then
                           Feet_Prev (I) := W;
                        end if;
                     end;
                  end;
               end if;
            end loop;
         end if;
         if Carcass_Stats then
            for K in 1 .. Natural'Min (Carcass_Run'Last, Castle.Colony.Carcass_Count) loop
               declare
                  use Castle.Colony;
                  V : constant Carcass_View := Carcass_At (K);
                  Z : constant Natural := (if Carcass_Used (K) and then V.Lying then Zone_On (V.Centre.X, V.Centre.Y) else 0);
               begin
                  if Z > 0 and then Zone_At (Z).Kind = Stockpile_Zone then
                     if Carcass_Run (K) = 0 then
                        Carcass_Lay_N := Carcass_Lay_N + 1;
                        if Carcass_Lay_N <= 12 then
                           Put_Line ("carcass: after" & S'Image & " s (day" & Natural'Image (Natural (Long_Float'Floor (Hours / 24.0)))
                                     & ", " & Img (Float (Hours - 24.0 * Long_Float'Floor (Hours / 24.0)), 1)
                                     & " h) a whole deer lies on a stockpile's ground at " & Img (V.Centre.X, 1) & ", "
                                     & Img (V.Centre.Y, 1));
                        end if;
                     end if;
                     Carcass_Run (K) := Carcass_Run (K) + 1;
                     Carcass_Lay_S := Carcass_Lay_S + 1;
                     Carcass_Longest := Natural'Max (Carcass_Longest, Carcass_Run (K));
                  else
                     Carcass_Run (K) := 0;
                  end if;
               end;
            end loop;
         end if;
         if Watch_Who in 1 .. Castle.Colony.Members and then S in Watch_S0 .. Watch_S1
           and then not Castle.Colony.Dead (Watch_Who)
         then
            declare
               W  : constant Vec3 := Castle.Colony.Where (Watch_Who);
               Bx : constant Integer := Integer (Float'Floor (W.X * 4.0));
               By : constant Integer := Integer (Float'Floor (W.Y * 4.0));
               Bz : constant Integer := Integer (Float'Floor ((W.Z + 0.05) * 4.0));
               T  : Integer := Bz + 12;
               Fl : Castle.Nav.Floor_List;
               Fn : Natural;
               L  : Unbounded_String;
            begin
               while T > Bz - 12
                 and then not (Castle.Blocks.Class_Of (Castle.World_Blocks.Block_At (Bx, By, T).Mat) in Castle.Blocks.Solid)
               loop
                  T := T - 1;
               end loop;
               Castle.Nav.Floors_At (Integer (Float'Floor (W.X * 2.0)), Integer (Float'Floor (W.Y * 2.0)), Fn, Fl);
               for K in 1 .. Fn loop
                  Append (L, " " & Img (Float (Fl (K).Z) * 0.25, 2));
               end loop;
               Put_Line ("watch:" & S'Image & " s " & Castle.Colony.Name_Of (Watch_Who) & " at " & Img (W.X, 2) & " " & Img (W.Y, 2)
                         & ", feet " & Img (W.Z, 2) & " m, the ground's top in its column " & Img (Float (T + 1) * 0.25, 2)
                         & " m, the walking map's floors there" & (if Fn = 0 then " none" else To_String (L))
                         & "; " & Castle.Colony.Status (Watch_Who) & "; hands to "
                         & Img (Castle.Colony.Work_Spot (Watch_Who).X, 2) & " " & Img (Castle.Colony.Work_Spot (Watch_Who).Y, 2));
            end;
         end if;
         if Builder_Stats then
            for I in 1 .. Castle.Colony.Members loop
               if not Castle.Colony.Dead (I) and then Castle.Colony.Helping (I) then
                  Help_S := Help_S + 1;
               end if;
            end loop;
            for H in 1 .. Castle.Colony.House_Count loop
               Help_Most_Seen := Natural'Max (Help_Most_Seen, Castle.Colony.Builders_At (H));
            end loop;
            declare
               use type Castle.Colony.House_Phase;
            begin
               if Store_Stood_S = 0 and then Castle.Colony.Storehouse > 0
                 and then Castle.Colony.House_At (Castle.Colony.Storehouse).Phase = Castle.Colony.Standing
               then
                  Store_Stood_S := S;
               end if;
            end;
            for I in 1 .. Castle.Colony.Members loop
               if not Castle.Colony.Dead (I) then
                  declare
                     W  : constant Vec3 := Castle.Colony.Where (I);
                     St : constant String := Castle.Colony.Status (I);
                     function Says (Part : String) return Boolean is (Ada.Strings.Fixed.Index (St, Part) > 0);
                     Bx : constant Integer := Integer (Float'Floor (W.X * 4.0));
                     By : constant Integer := Integer (Float'Floor (W.Y * 4.0));
                     Bz : constant Integer := Integer (Float'Floor ((W.Z + 0.05) * 4.0));
                     function Solid_At (Z : Integer) return Boolean is
                       (Castle.Blocks.Class_Of (Castle.World_Blocks.Block_At (Bx, By, Z).Mat) in Castle.Blocks.Solid);
                     Was   : Builder_Was renames Builders_Were (I);
                     --  (standing still: one walking up a step has its feet under the next column's top for a moment)
                     In_It : constant Boolean := Was.Seen and then Was.P = W and then (Solid_At (Bz) or else Solid_At (Bz + 1));
                     Going : constant Boolean := Says ("going to make the ground ready for");
                     Level : constant Boolean := Says ("levelling the ground for");
                     Store : constant Boolean :=
                       Castle.Colony.Site_Of (I) > 0 and then Castle.Colony.Site_Of (I) = Castle.Colony.Storehouse;
                     Deep  : Natural := 0;
                  begin
                     if In_It then
                        for Z in (if Solid_At (Bz) then Bz else Bz + 1) .. Bz + 8 loop
                           exit when not Solid_At (Z);
                           Deep := Deep + 1;
                        end loop;
                        In_Ground_Deepest := Natural'Max (In_Ground_Deepest, Deep);
                        In_Ground_S := In_Ground_S + 1;
                        if Level or else Going then
                           In_Ground_Level := In_Ground_Level + 1;
                        elsif Castle.Colony.Site_Of (I) > 0 then
                           In_Ground_Lay := In_Ground_Lay + 1;
                        end if;
                        if Was.In_Run = 0 then
                           In_Ground_Runs := In_Ground_Runs + 1;
                           if In_Ground_Runs <= Builder_List then
                              Put_Line ("in the ground: after" & S'Image & " s " & Castle.Colony.Name_Of (I) & " (" & St
                                        & ") at " & Img (W.X, 2) & ", " & Img (W.Y, 2) & ", its feet at " & Img (W.Z, 2)
                                        & " m:" & Deep'Image & " blocks stand in its own block column from "
                                        & Img (Float (if Solid_At (Bz) then Bz else Bz + 1) * 0.25, 2) & " m up");
                           end if;
                        end if;
                        Was.In_Run := Was.In_Run + 1;
                        In_Ground_Longest := Natural'Max (In_Ground_Longest, Was.In_Run);
                     else
                        Was.In_Run := 0;
                     end if;
                     if Going then
                        Walks (Store).Walk_S := Walks (Store).Walk_S + 1;
                        if Was.Seen then
                           Walks (Store).M := Walks (Store).M
                             + Long_Float (Ada.Numerics.Elementary_Functions.Sqrt ((W.X - Was.P.X) ** 2 + (W.Y - Was.P.Y) ** 2));
                        end if;
                     end if;
                     if Level then
                        Walks (Store).Work_S := Walks (Store).Work_S + 1;
                        if not Was.Levelling then
                           Walks (Store).Pieces := Walks (Store).Pieces + 1;
                           if Length (Builder_Track) > 0 then
                              Put_Line (Builder_Track_F, S'Image & I'Image & Castle.Colony.Site_Of (I)'Image
                                        & (if Store then " 1 " else " 0 ") & Img (W.X, 2) & " " & Img (W.Y, 2) & " " & Img (W.Z, 2)
                                        & " " & Img (Castle.Colony.Work_Spot (I).X, 2) & " " & Img (Castle.Colony.Work_Spot (I).Y, 2));
                           end if;
                           if Was.Last_S > 0 and then S - Was.Last_S <= 60 and then Was.Last_H = Castle.Colony.Site_Of (I) then
                              declare
                                 D : constant Float :=
                                   Ada.Numerics.Elementary_Functions.Sqrt ((W.X - Was.Last_P.X) ** 2 + (W.Y - Was.Last_P.Y) ** 2);
                              begin
                                 Walks (Store).Next_N := Walks (Store).Next_N + 1;
                                 Walks (Store).Next_M := Walks (Store).Next_M + Long_Float (D);
                                 if D > 3.0 then
                                    Walks (Store).Far_N := Walks (Store).Far_N + 1;
                                 end if;
                              end;
                           end if;
                        end if;
                        Was.Last_P := W;
                        Was.Last_S := S;
                        Was.Last_H := Castle.Colony.Site_Of (I);
                     end if;
                     Was.P := W;
                     Was.Seen := True;
                     Was.Going := Going;
                     Was.Levelling := Level;
                  end;
               end if;
            end loop;
         end if;
         if Haul_Stats then
            for I in 1 .. Castle.Colony.Members loop
               if not Castle.Colony.Dead (I) then
                  declare
                     W   : constant Vec3 := Castle.Colony.Where (I);
                     Has : constant Boolean := Castle.Colony.Carried (I) > 0;
                     H   : Haul_Rec renames Haul_Was (I);
                  begin
                     if H.Seen and then H.Had then
                        Haul_M := Haul_M + Long_Float (Ada.Numerics.Elementary_Functions.Sqrt
                                                         ((W.X - H.P.X) ** 2 + (W.Y - H.P.Y) ** 2));
                        if not Has then
                           Haul_Loads := Haul_Loads + 1;
                        end if;
                     end if;
                     H := (P => W, Had => Has, Seen => True);
                  end;
               end if;
            end loop;
         end if;
         if Turn_Stats then
            for K in 1 .. Castle.Colony.House_Count loop
               declare
                  V : constant Castle.Colony.House_View := Castle.Colony.House_At (K);
                  use type Castle.Colony.House_Phase;
               begin
                  --  (a house walked where it is drawn: a storehouse drawn turned, a hovel placed turned)
                  if V.Walked_Drawn then
                     Turn_Was (K).Walked_S := Turn_Was (K).Walked_S + 1;
                     for I in 1 .. Castle.Colony.Members loop
                        if not Castle.Colony.Dead (I) then
                           case Castle.Colony.House_Place (K, Castle.Colony.Where (I).X, Castle.Colony.Where (I).Y) is
                              when Castle.Colony.In_Its_Wall =>
                                 Turn_Was (K).In_Wall_S := Turn_Was (K).In_Wall_S + 1;
                                 if Turn_Was (K).In_Wall_S <= 3 then     --  (who, and doing what: the first three)
                                    Put_Line ("  in a wall of house" & K'Image & " as it is drawn, day"
                                              & Integer'Image (Integer (Long_Float'Floor (Hours / 24.0))) & " at "
                                              & Img (Float (Hours - 24.0 * Long_Float'Floor (Hours / 24.0)), 2)
                                              & " h: " & Castle.Colony.Name_Of (I) & " ("
                                              & Img (Castle.Colony.Where (I).X, 2) & " "
                                              & Img (Castle.Colony.Where (I).Y, 2) & "), "
                                              & Castle.Colony.Status (I) & Way_Ends (I));
                                 end if;
                              when Castle.Colony.Within_It   => Turn_Was (K).Within_S := Turn_Was (K).Within_S + 1;
                              when Castle.Colony.Where_Its_Blocks_Stand =>
                                 Turn_Was (K).On_Blocks_S := Turn_Was (K).On_Blocks_S + 1;
                              when Castle.Colony.Off_It      => null;
                           end case;
                        end if;
                     end loop;
                  end if;
                  if V.Yard_Turned then
                     null;
                  elsif V.Turn /= 0.0 then
                     if V.Phase = Castle.Colony.Standing then
                        Turn_Was (K).Stood_S := Turn_Was (K).Stood_S + 1;
                     end if;
                     for I in 1 .. Castle.Colony.Members loop
                        if not Castle.Colony.Dead (I) then
                           declare
                              W : constant Vec3 := Castle.Colony.Where (I);
                           begin
                              if Castle.Colony.House_Drawn_On (K, W.X, W.Y)
                                and then not Castle.Colony.House_Walls_On (K, W.X, W.Y)
                              then
                                 if I = V.Builder then
                                    Turn_Was (K).Builder_S := Turn_Was (K).Builder_S + 1;
                                 elsif I = V.Owner then
                                    Turn_Was (K).Owner_S := Turn_Was (K).Owner_S + 1;
                                 else
                                    Turn_Was (K).Other_S := Turn_Was (K).Other_S + 1;
                                    if V.Phase = Castle.Colony.Standing then
                                       Turn_Was (K).Other_Stood_S := Turn_Was (K).Other_Stood_S + 1;
                                    end if;
                                 end if;
                              end if;
                           end;
                        end if;
                     end loop;
                  end if;
               end;
            end loop;
         end if;
         if Tree_Stats then
            declare
               use type Castle.Colony.Job_Kind;
            begin
               for I in 1 .. Castle.Colony.Members loop
                  if not Castle.Colony.Dead (I) and then Castle.Colony.Job_Of (I) = Castle.Colony.Forester then
                     Note_Said (Castle.Colony.Status (I));
                  end if;
               end loop;
            end;
         end if;
         if Work_Stats then
            for I in 1 .. Castle.Colony.Members loop
               if not Castle.Colony.Dead (I)
                 and then Castle.Colony.Job_Of (I) in Castle.Colony.Gatherer | Castle.Colony.Porter | Castle.Colony.Hunter
               then
                  Note_Work (Castle.Colony.Job_Of (I)'Image & ": " & Castle.Colony.Status (I));
               end if;
            end loop;
         end if;
         for I in 1 .. Castle.Colony.Members loop
            if Castle.Colony.Dead (I) and then not Told (I) then
               Told (I) := True;
               Put_Line (Castle.Colony.Name_Of (I) & " has died of hunger");
            end if;
         end loop;
         --  the storehouse used: who keeps it and who makes for it, what is made, the cart at its front
         declare
            When_S : constant String :=
              "day" & Integer'Image (Integer (Long_Float'Floor (Hours / 24.0))) & " at "
              & Img (Float (Hours - 24.0 * Long_Float'Floor (Hours / 24.0)), 1) & " h: ";
            Made_N, Fit_N : Natural := 0;
         begin
            if Castle.Colony.Stockman /= Keeper_Told then
               Keeper_Told := Castle.Colony.Stockman;
               if Keeper_Told > 0 then
                  Put_Line ("stockman, " & When_S & Castle.Colony.Name_Of (Keeper_Told));
               end if;
            end if;
            if Castle.Colony.Carpenter /= Carp_Told then
               Carp_Told := Castle.Colony.Carpenter;
               if Carp_Told > 0 then
                  Put_Line ("carpenter, " & When_S & Castle.Colony.Name_Of (Carp_Told));
               end if;
            end if;
            for K in 1 .. Castle.Colony.Cell_Count loop
               declare
                  use type Castle.Colony.Fitting;
                  C : constant Castle.Colony.Cell_View := Castle.Colony.Cell_At (K);
               begin
                  if C.Fit in Castle.Colony.Shelf | Castle.Colony.Meat_Barrel | Castle.Colony.Water_Barrel
                    and then not C.Closed
                  then
                     Fit_N := Fit_N + 1;
                     if C.Made then
                        Made_N := Made_N + 1;
                     end if;
                  end if;
               end;
            end loop;
            if Made_N /= Made_Told then
               Made_Told := Made_N;
               if Made_N = Fit_N and then Fit_N > 0 then
                  Put_Line ("carpenter, " & When_S & "all" & Integer'Image (Fit_N) & " shelves and barrels made");
               end if;
            end if;
            if not Front_Told and then Castle.Colony.Cart_At_Storehouse then
               Front_Told := True;
               Put_Line ("stockman, " & When_S & "the lord's cart at the storehouse's front");
            end if;
         end;
         if Castle.Colony.Storehouse_Note_Key /= Note_Told then
            Note_Told := Castle.Colony.Storehouse_Note_Key;
            if Castle.Colony.Storehouse_Note /= "" then     --  (the advisor's word, simulated)
               Put_Line ("advisor, day" & Integer'Image (Integer (Long_Float'Floor (Hours / 24.0))) & " at "
                         & Img (Float (Hours - 24.0 * Long_Float'Floor (Hours / 24.0)), 1) & " h: "
                         & Castle.Colony.Storehouse_Note);
            end if;
         end if;
         if Track_Path /= Null_Unbounded_String then
            Track_Deer (S);
         end if;
         if Log_Hours > 0.0 and then Long_Float'Floor (Hours / Long_Float (Log_Hours)) /= Logged then
            Logged := Long_Float'Floor (Hours / Long_Float (Log_Hours));
            Put_Line (Castle.Scenario.Food_Line (Hours));
            if Tree_Stats then
               Put_Trees;
            end if;
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
      if Yard_Now and then Castle.Colony.Storehouse > 0 then
         Castle.Colony.Build_Homes_Now (As_Laid => True);   --  (the storehouse begun, its ground and all of it from nowhere)
         Rebuild_Dirty;
      end if;
      if Box_Stats then
         Put_Boxes ("at the end");
      end if;
      if Square_Pits then
         Put_Square_Pits;
      end if;
      if Wall_Map then
         Put_Wall_Map;
      end if;
      if Square_Path then
         declare
            C : Path_Count;
         begin
            Read_Square_Path (C, Lines => True);
            C.Barred := Castle.Colony.Square_Walls_State.Steps_Barred;
            Put_Line ("square path:" & Path_Words (C));
         end;
      end if;
      if Yard_Map then
         Put_Yard_Map;
      end if;
      if Yard_Pits_On then
         declare
            Spots, Pits : Natural;
            In_M, Out_M : Float;
         begin
            Yard_Pits (Spots, Pits, In_M, Out_M, Where => True);
            Put_Line ("yard pits: of" & Spots'Image & " spots on the stockyard's ground and within 2 m of it that can be got"
                      & " to from the fire," & Pits'Image & " cannot be got back from; from the fire to the middle of the"
                      & " storehouse's floor " & (if In_M < 0.0 then "no way" else Img (In_M, 1) & " m") & ", back "
                      & (if Out_M < 0.0 then "no way" else Img (Out_M, 1) & " m"));
         end;
      end if;
      if Feet_Stats then
         Put_Line ("feet: of" & Feet_Seen'Image & " serf-seconds," & Feet_Over_Block'Image
                   & " more than a block off the ground under them and" & Feet_Over_Step'Image
                   & " more than a step; the worst " & Img (Feet_Worst, 2) & " m"
                   & (if Feet_Worst_I > 0
                      then ", " & Castle.Colony.Name_Of (Feet_Worst_I) & " at " & Img (Feet_Worst_At.X, 1) & ", "
                           & Img (Feet_Worst_At.Y, 1) & " after" & Feet_Worst_S'Image & " colony seconds"
                      else "")
                   & ";" & Feet_Air'Image & " standing still more than half a metre over the ground of their own block column,"
                   & Feet_Deep'Image & " (moving or not) more than a metre over it");
      end if;
      if Length (Builder_Track) > 0 then
         Close (Builder_Track_F);
      end if;
      if Seam_Stats and then Castle.Colony.Has_Stake then
         Put_Seams ("at the end");
      end if;
      for K in 1 .. Map_N loop
         declare
            Bx0 : constant Integer := Integer (Float'Floor (Float'Min (Map_Boxes (K) (1), Map_Boxes (K) (3)) * 4.0));
            Bx1 : constant Integer := Integer (Float'Floor (Float'Max (Map_Boxes (K) (1), Map_Boxes (K) (3)) * 4.0));
            By0 : constant Integer := Integer (Float'Floor (Float'Min (Map_Boxes (K) (2), Map_Boxes (K) (4)) * 4.0));
            By1 : constant Integer := Integer (Float'Floor (Float'Max (Map_Boxes (K) (2), Map_Boxes (K) (4)) * 4.0));
            Mid_Z : constant Integer :=
              Integer (Castle.Nav.Surface_Z (Float (Bx0 + Bx1) / 8.0, Float (By0 + By1) / 8.0) * 4.0);
            function Ground (M : Material) return Boolean is (Is_Land (M));
            function Top (X, Y : Integer) return Integer is
            begin
               for Z in reverse Mid_Z - 48 .. Mid_Z + 48 loop
                  if Ground (Castle.World_Blocks.Block_At (X, Y, Z).Mat) then
                     return Z;
                  end if;
               end loop;
               return Mid_Z - 49;
            end Top;
            Lowest : Integer := Integer'Last;
            Digit  : constant String := "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
         begin
            for Y in By0 .. By1 loop
               for X in Bx0 .. Bx1 loop
                  Lowest := Integer'Min (Lowest, Top (X, Y));
               end loop;
            end loop;
            Put_Line ("ground map" & K'Image & ": block columns" & Bx0'Image & " .." & Bx1'Image & " west to east,"
                      & By1'Image & " down to" & By0'Image & " north to south; the row of each one's top over row"
                      & Lowest'Image & " (" & Img (Float (Lowest + 1) * 0.25, 2) & " m)");
            for Y in reverse By0 .. By1 loop
               declare
                  L : String (1 .. Bx1 - Bx0 + 1);
               begin
                  for X in Bx0 .. Bx1 loop
                     L (X - Bx0 + 1) := Digit (Integer'Min (Digit'Last, Top (X, Y) - Lowest + 1));
                  end loop;
                  Put_Line ("  " & L);
               end;
            end loop;
            Put_Line ("ground map" & K'Image & ": whose each is");
            for Y in reverse By0 .. By1 loop
               declare
                  L : String (1 .. Bx1 - Bx0 + 1);
               begin
                  for X in Bx0 .. Bx1 loop
                     declare
                        Xm : constant Float := (Float (X) + 0.5) * 0.25;
                        Ym : constant Float := (Float (Y) + 0.5) * 0.25;
                        M  : constant Material := Castle.World_Blocks.Block_At (X, Y, Top (X, Y)).Mat;
                        Zn : constant Natural := Castle.Colony.Zone_On (Xm, Ym);
                     begin
                        L (X - Bx0 + 1) :=
                          (if M = Footpath then 'P'
                           elsif M = Fieldstone then 'S'
                           elsif Castle.Colony.House_On (Xm, Ym) > 0 then '#'
                           elsif Castle.Colony.Hovel_At (Xm, Ym) > 0 then 'l'
                           elsif Castle.Colony.On_Path (Xm, Ym) then 'p'
                           elsif Zn in 1 .. 9 then Character'Val (Character'Pos ('0') + Zn)
                           elsif Zn > 9 then 'z'
                           else '.');
                     end;
                  end loop;
                  Put_Line ("  " & L);
               end;
            end loop;
         end;
      end loop;
      for K in 1 .. Column_N loop
         declare
            X  : constant Integer := Column_At (K, 1);
            Y  : constant Integer := Column_At (K, 2);
            Xm : constant Float := (Float (X) + 0.5) * 0.25;
            Ym : constant Float := (Float (Y) + 0.5) * 0.25;
            Sz : constant Float := Castle.Nav.Surface_Z (Xm, Ym);
            Zm : constant Integer := (if Sz >= 0.0 then Integer (Sz * 4.0) else 80);
            Top : Integer := Zm + 40;
            L   : Unbounded_String;
         begin
            while Top > Zm - 40 and then not Is_Land (Castle.World_Blocks.Block_At (X, Y, Top).Mat) loop
               Top := Top - 1;
            end loop;
            for Z in reverse Top - 6 .. Top + 6 loop
               Append (L, " " & Castle.World_Blocks.Block_At (X, Y, Z).Mat'Image);
            end loop;
            Put_Line ("column" & X'Image & Y'Image & ": its ground's top at row" & Top'Image & " (" & Img (Float (Top + 1) * 0.25, 2)
                      & " m); zone" & Natural'Image (Castle.Colony.Zone_On (Xm, Ym))
                      & (if Castle.Colony.On_Path (Xm, Ym) then ", a path's" else "")
                      & "; from six rows over it down:" & To_String (L));
            declare
               Zn : Natural;
               Lv : Float;
               Kd : Castle.Colony.Flat_Column;
            begin
               Castle.Colony.Flat_Column_At (X, Y, Zn, Lv, Kd);
               if Zn > 0 then
                  Put_Line ("column" & X'Image & Y'Image & ": of stockpile zone" & Zn'Image & ", whose things lie at "
                            & Img (Lv, 2) & " m: " & Kd'Image);
               end if;
            end;
         end;
      end loop;
      if Flat_Scan then
         for Zn in 1 .. Castle.Colony.Zone_Count loop
            declare
               use type Castle.Colony.Zone_Kind;
               V : constant Castle.Colony.Zone_View := Castle.Colony.Zone_At (Zn);
               Max_Cols : constant := 40_000;
               type Row_List is array (1 .. Max_Cols) of Integer;
               type Row_List_Access is access Row_List;
               Tops : constant Row_List_Access := new Row_List;       --  every column of its ground
               F_Top, F_Path : constant Row_List_Access := new Row_List;   --  its columns beside a path's, and that path's
               N, Nf : Natural := 0;
               Zm : constant Integer := Integer (Float'Floor ((V.Lo.Z + V.Hi.Z) * 2.0));
               Rock : Natural := 0;      --  its block columns whose top is no earth (rock, a boulder, ore)
               function Ground (M : Material) return Boolean is (Is_Land (M));
               function Earth (M : Material) return Boolean is (M in Dirt | Grass | Sand | Gravel | Clay | Footpath);
               function Top (X, Y : Integer) return Integer is
               begin
                  for Z in reverse Zm - 64 .. Zm + 64 loop
                     if Ground (Castle.World_Blocks.Block_At (X, Y, Z).Mat) then
                        return Z;
                     end if;
                  end loop;
                  return Zm - 65;
               end Top;
               function Mid (K : Integer) return Float is ((Float (K) + 0.5) * 0.25);
               procedure Sort (L : in out Row_List; Count : Natural) is
               begin
                  for I in 2 .. Count loop
                     declare
                        Vv : constant Integer := L (I);
                        J  : Natural := I - 1;
                     begin
                        while J >= 1 and then L (J) > Vv loop
                           L (J + 1) := L (J);
                           J := J - 1;
                        end loop;
                        L (J + 1) := Vv;
                     end;
                  end loop;
               end Sort;
               procedure Say (What : String; Level : Integer) is
                  Cut, Fill, Moved, Both, In_Only : Natural := 0;
               begin
                  for K in 1 .. N loop
                     Cut := Natural'Max (Cut, Integer'Max (0, Tops (K) - Level));
                     Fill := Natural'Max (Fill, Integer'Max (0, Level - Tops (K)));
                     Moved := Moved + abs (Tops (K) - Level);
                  end loop;
                  for K in 1 .. Nf loop
                     if abs (F_Path (K) - Level) <= 2 then
                        Both := Both + 1;
                     elsif F_Path (K) - Level in 3 .. 4 then
                        In_Only := In_Only + 1;         --  (a drop a serf takes, and cannot climb)
                     end if;
                  end loop;
                  Put_Line ("flat scan: zone" & Zn'Image & ", " & What & " (" & Img (Float (Level + 1) * 0.25, 2) & " m): the deepest cut"
                            & Cut'Image & " blocks, the highest fill" & Fill'Image & ","
                            & Moved'Image & " blocks moved; of its front's" & Nf'Image & " block columns" & Both'Image
                            & " within two blocks of their path's," & In_Only'Image & " three or four under it");
               end Say;
            begin
               if V.Kind = Castle.Colony.Stockpile_Zone and then not V.Yard and then V.Blocks > 0 then
                  for X in Integer (Float'Floor (V.Lo.X * 4.0)) - 1 .. Integer (Float'Floor (V.Hi.X * 4.0)) + 1 loop
                     for Y in Integer (Float'Floor (V.Lo.Y * 4.0)) - 1 .. Integer (Float'Floor (V.Hi.Y * 4.0)) + 1 loop
                        if Castle.Colony.Zone_On (Mid (X), Mid (Y)) = Zn and then N < Max_Cols then
                           if not Earth (Castle.World_Blocks.Block_At (X, Y, Top (X, Y)).Mat) then
                              Rock := Rock + 1;
                           end if;
                           N := N + 1;
                           Tops (N) := Top (X, Y);
                           for D in 1 .. 4 loop
                              declare
                                 Nx : constant Integer := X + (case D is when 1 => 1, when 2 => -1, when others => 0);
                                 Ny : constant Integer := Y + (case D is when 3 => 1, when 4 => -1, when others => 0);
                              begin
                                 if Castle.Colony.On_Path (Mid (Nx), Mid (Ny)) and then Nf < Max_Cols then
                                    Nf := Nf + 1;
                                    F_Top (Nf) := Tops (N);
                                    F_Path (Nf) := Top (Nx, Ny);
                                 end if;
                              end;
                           end loop;
                        end if;
                     end loop;
                  end loop;
                  declare
                     All_Sorted : constant Row_List_Access := new Row_List'(Tops.all);
                     F_Sorted   : constant Row_List_Access := new Row_List'(F_Top.all);
                     P_Sorted   : constant Row_List_Access := new Row_List'(F_Path.all);
                  begin
                     Sort (All_Sorted.all, N);
                     Sort (F_Sorted.all, Nf);
                     Sort (P_Sorted.all, Nf);
                     Put_Line ("flat scan: zone" & Zn'Image & ":" & N'Image & " block columns of ground, from "
                               & Img (Float (All_Sorted (1) + 1) * 0.25, 2) & " to " & Img (Float (All_Sorted (N) + 1) * 0.25, 2)
                               & " m (" & Img (All_Sorted (N) - All_Sorted (1)) & " blocks)"
                               & (if Rock > 0 then "," & Rock'Image & " of them rock, a boulder or ore on top;" else ";")
                               & (if Nf = 0 then " no column of it beside a path's"
                                  else Nf'Image & " beside a path's, that path from " & Img (Float (P_Sorted (1) + 1) * 0.25, 2)
                                       & " to " & Img (Float (P_Sorted (Nf) + 1) * 0.25, 2) & " m"));
                     if Nf > 0 then
                        Say ("at the lowest of its ground beside a path", F_Sorted (1));
                        Say ("at the middle of its ground beside a path", F_Sorted ((Nf + 1) / 2));
                        Say ("at the middle of its path's columns there", P_Sorted ((Nf + 1) / 2));
                     end if;
                     Say ("at the middle of all its ground", All_Sorted ((N + 1) / 2));
                  end;
                  --  (and by the rule's own reading of each column, as the world lies now)
                  if Castle.Colony.Pile_Flat then
                     declare
                        use Castle.Colony;
                        Count : array (Flat_Column) of Natural := [others => 0];
                        Said  : Natural := 0;
                        Zq : Natural;
                        Lv : Float := 0.0;
                        Lq : Float;
                        Kd : Flat_Column;
                     begin
                        for X in Integer (Float'Floor (V.Lo.X * 4.0)) - 1 .. Integer (Float'Floor (V.Hi.X * 4.0)) + 1 loop
                           for Y in Integer (Float'Floor (V.Lo.Y * 4.0)) - 1 .. Integer (Float'Floor (V.Hi.Y * 4.0)) + 1 loop
                              Flat_Column_At (X, Y, Zq, Lq, Kd);
                              if Zq = Zn then
                                 Lv := Lq;
                                 Count (Kd) := Count (Kd) + 1;
                                 if Kd /= At_Level and then Said < 6 then
                                    Said := Said + 1;
                                    Put_Line ("flat scan: zone" & Zn'Image & ": column" & X'Image & Y'Image & " " & Kd'Image);
                                 end if;
                              end if;
                           end loop;
                        end loop;
                        Put_Line ("flat scan: zone" & Zn'Image & ", by the rule's own reading (its things at " & Img (Lv, 2) & " m):"
                                  & Count (At_Level)'Image & " block columns at its level," & Count (To_Move)'Image
                                  & " to move still," & Count (Trunk_On)'Image & " waiting for a tree to be felled,"
                                  & Count (Cart_On)'Image & " for the cart to go; left for good:" & Count (Not_Earth)'Image
                                  & " with something laid or built on top," & Count (Water_In)'Image & " with water in them,"
                                  & Count (Water_By)'Image & " beside water," & Count (Thing_Over)'Image
                                  & " with something standing over them," & Count (Too_Far)'Image & " too far off,"
                                  & Count (No_Ground)'Image & " with no ground found");
                     end;
                  end if;
               end if;
            end;
         end loop;
      end if;
      if Place_Stats then
         declare
            use Castle.Colony;
            use Ada.Numerics.Elementary_Functions;
            Used, Over, Under, By_Cart, Most : Natural := 0;
            C  : constant Cart_View := Cart;
         begin
            for K in 1 .. Cell_Count loop
               declare
                  V : constant Cell_View := Cell_At (K);
                  Z : constant Natural := Zone_Of_Cell (K);
                  T : constant Float := (if Z in 1 .. Zone_Count then Zone_At (Z).Turn else 0.0);
                  Zr : constant Integer := Integer (Float'Floor ((V.Centre.Z + 0.01) * 4.0)) - 1;
                  Hi, Lo : Boolean := False;
               begin
                  if V.Count > 0 and then Z in 1 .. Zone_Count and then not Zone_At (Z).Yard then
                     Used := Used + 1;
                     for Bx in Integer (Float'Floor ((V.Centre.X - 0.75) * 4.0)) .. Integer (Float'Floor ((V.Centre.X + 0.75) * 4.0)) loop
                        for By in Integer (Float'Floor ((V.Centre.Y - 0.75) * 4.0)) .. Integer (Float'Floor ((V.Centre.Y + 0.75) * 4.0)) loop
                           declare
                              Dx : constant Float := (Float (Bx) + 0.5) * 0.25 - V.Centre.X;
                              Dy : constant Float := (Float (By) + 0.5) * 0.25 - V.Centre.Y;
                              Top : Integer := Zr - 8;
                           begin
                              if abs (Dx * Cos (T) + Dy * Sin (T)) < 0.5 and then abs (Dy * Cos (T) - Dx * Sin (T)) < 0.5 then
                                 for Zz in reverse Zr - 8 .. Zr + 8 loop
                                    if Is_Land (Castle.World_Blocks.Block_At (Bx, By, Zz).Mat) then
                                       Top := Zz;
                                       exit;
                                    end if;
                                 end loop;
                                 Hi := Hi or else Top > Zr;
                                 Lo := Lo or else Top < Zr;
                                 Most := Natural'Max (Most, abs (Top - Zr));
                              end if;
                           end;
                        end loop;
                     end loop;
                     Over := Over + (if Hi then 1 else 0);
                     Under := Under + (if Lo and then not Hi then 1 else 0);
                     if C.Here and then not C.Towed then
                        declare
                           Dx : constant Float := V.Centre.X - C.At_P.X;
                           Dy : constant Float := V.Centre.Y - C.At_P.Y;
                           A  : constant Float := Dx * Cos (C.Turn) + Dy * Sin (C.Turn);
                           Sd : constant Float := Dy * Cos (C.Turn) - Dx * Sin (C.Turn);
                        begin
                           if (abs Sd <= 0.6 and then A >= -1.1 and then A <= Cart_Shaft_M + 0.3)
                             or else (abs Sd <= 1.25 and then abs A <= 1.25)
                           then
                              By_Cart := By_Cart + 1;
                           end if;
                        end;
                     end if;
                  end if;
               end;
            end loop;
            Put_Line ("places: of" & Used'Image & " places of the stockpiles that hold something," & Over'Image
                      & " have a block column of their square metre over the place's level and" & Under'Image
                      & " others one under it (the most" & Most'Image & " blocks);" & By_Cart'Image
                      & " lie under the cart's bed, beside its wheels or under its shafts");
         end;
      end if;
      --  (and whether each place can be walked to: a way asked of the walking map from the stake to
      --  beside every open place of the stockpiles, and back)
      if Place_Stats and then Castle.Colony.Has_Stake then
         declare
            use Castle.Colony;
            use type Castle.Nav.Outcome;
            Open, No_Way, No_Way_Back, Shut, At_Cart : Natural := 0;
            Said : Natural := 0;
            Cv : constant Cart_View := Castle.Colony.Cart;
            --  (where the cart stands nobody walks: under its bed, beside its wheels, under its shafts)
            function By_Cart (P : Castle.Math.Vec3) return Boolean is
               use Ada.Numerics.Elementary_Functions;
               Dx : constant Float := P.X - Cv.At_P.X;
               Dy : constant Float := P.Y - Cv.At_P.Y;
               A  : constant Float := Dx * Cos (Cv.Turn) + Dy * Sin (Cv.Turn);
               Sd : constant Float := Dy * Cos (Cv.Turn) - Dx * Sin (Cv.Turn);
            begin
               return Cv.Here and then not Cv.Towed
                 and then ((abs Sd <= 0.6 and then A >= -1.1 and then A <= Cart_Shaft_M + 0.3)
                           or else (abs Sd <= 1.25 and then abs A <= 1.25));
            end By_Cart;
         begin
            for K in 1 .. Cell_Count loop
               declare
                  V : constant Cell_View := Cell_At (K);
                  Z : constant Natural := Zone_Of_Cell (K);
               begin
                  if Z in 1 .. Zone_Count and then not Zone_At (Z).Yard and then not V.Overflow then
                     if V.Closed then
                        Shut := Shut + 1;
                     else
                        Open := Open + 1;
                        if Castle.Nav.Plan (Stake, V.Centre).Result /= Castle.Nav.Found then
                           No_Way := No_Way + 1;
                           if By_Cart (V.Centre) then
                              At_Cart := At_Cart + 1;
                           elsif Said < 12 then
                              Said := Said + 1;
                              Put_Line ("places: no way from the stake to the place at " & Img (V.Centre.X, 2) & ", "
                                        & Img (V.Centre.Y, 2) & ", " & Img (V.Centre.Z, 2) & " (zone" & Z'Image
                                        & (if V.Count > 0 then ", something lies there)" else ")"));
                           end if;
                        elsif Castle.Nav.Plan (V.Centre, Stake).Result /= Castle.Nav.Found then
                           No_Way_Back := No_Way_Back + 1;
                        end if;
                     end if;
                  end if;
               end;
            end loop;
            Put_Line ("places: of" & Open'Image & " open places of the stockpiles," & No_Way'Image
                      & " have no way to them from the stake (" & Img (At_Cart) & " of them where the cart stands) and"
                      & No_Way_Back'Image & " others none back to it;" & Shut'Image & " places are closed");
         end;
      end if;
      if Carcass_Stats then
         declare
            use Castle.Colony;
         begin
            Put_Line ("carcasses:" & Kills'Image & " deer killed;" & Carcass_Lay_N'Image
                      & " times a whole deer lay on a stockpile's ground," & Carcass_Lay_S'Image
                      & " colony seconds in all, the longest" & Carcass_Longest'Image
                      & " s; laid down unbutchered (of those on a stockpile's ground): its carrier given another job"
                      & Carcasses_Dropped (No_Hunter_Now)'Image & " (" & Img (Carcasses_Dropped (No_Hunter_Now, True))
                      & "), no room to butcher it and hungry or night" & Carcasses_Dropped (No_Room_For_It)'Image & " ("
                      & Img (Carcasses_Dropped (No_Room_For_It, True)) & "), no way there"
                      & Carcasses_Dropped (No_Way_Home)'Image & " (" & Img (Carcasses_Dropped (No_Way_Home, True))
                      & "), its carrier died" & Carcasses_Dropped (Its_Carrier_Died)'Image & " ("
                      & Img (Carcasses_Dropped (Its_Carrier_Died, True)) & ")");
         end;
      end if;
      if Builder_Stats then
         Put_Line ("in the ground:" & In_Ground_S'Image & " serf-seconds standing still with a block in one's own block column at"
                   & " one's feet or the row over them (" & In_Ground_Level'Image & " of them making a site's ground ready,"
                   & In_Ground_Lay'Image & " a builder's at anything else), in" & In_Ground_Runs'Image
                   & " times; the longest" & In_Ground_Longest'Image & " s, the deepest" & In_Ground_Deepest'Image & " blocks;"
                   & Castle.Colony.Stood_On_Fill'Image & " times someone was stood on earth just filled in round it");
         Put_Line ("helping:" & Help_S'Image & " serf-seconds spent as a builder of a house another builds too; the most builders"
                   & " at one house at once" & Help_Most_Seen'Image & "; the storehouse "
                   & (if Store_Stood_S > 0 then "stood after " & Img (Float (Store_Stood_S) / 1440.0, 2) & " days" else "does not stand"));
         for Store in Boolean loop
            Put_Line ("ground work, " & (if Store then "the storehouse's" else "the hovels'") & ":"
                      & Walks (Store).Pieces'Image & " pieces worked in" & Walks (Store).Work_S'Image & " s; "
                      & Img (Float (Walks (Store).M), 0) & " m walked to them in" & Walks (Store).Walk_S'Image & " s, "
                      & Img (Float (Walks (Store).M) / Float (Natural'Max (1, Walks (Store).Pieces)), 2) & " m a piece;"
                      & Walks (Store).Next_N'Image & " begun within a minute of the piece before, "
                      & Img (Float (Walks (Store).Next_M) / Float (Natural'Max (1, Walks (Store).Next_N)), 2)
                      & " m from where that one was worked from on the average," & Walks (Store).Far_N'Image
                      & " of them more than 3 m");
         end loop;
      end if;
      if Haul_Stats then
         Put_Line ("hauling:" & Haul_Loads'Image & " loads put down, carried " & Img (Float (Haul_M / 1000.0), 1)
                   & " km in all, " & Img (Float (Haul_M) / Float (Natural'Max (1, Haul_Loads)), 1) & " m a load");
      end if;
      if Turn_Stats then
         Put_Line ("houses drawn turned (a hovel: the ground it is drawn on off its walls' own place):");
         for K in 1 .. Castle.Colony.House_Count loop
            declare
               V : constant Castle.Colony.House_View := Castle.Colony.House_At (K);
            begin
               --  (a storehouse's pieces: what of its yard is drawn as its design has it)
               if Castle.Buildings."=" (V.Kind, Castle.Buildings.Storehouse) then
                  declare
                     P : constant Castle.Colony.Yard_Pieces_View := Castle.Colony.Yard_Pieces (K);
                     Planks, Rows, Of_Rows : Natural := 0;
                  begin
                     for R in 1 .. P.N_Rails loop
                        if P.Rails (R).Plank then
                           Planks := Planks + 1;
                        end if;
                     end loop;
                     for C in 1 .. P.N_Roofs loop
                        Rows := Rows + P.Roofs (C).Smoothed;
                        Of_Rows := Of_Rows + P.Roofs (C).Rows;
                     end loop;
                     Put_Line ("  the storehouse's pieces: " & Img (P.N_Rails - Planks) & " rails and " & Img (Planks)
                               & " planks over its gateways drawn as laid; " & Img (P.N_Roofs) & " coverings' roofs, "
                               & Img (Rows) & " of their" & Of_Rows'Image & " rows smoothed");
                  end;
               end if;
               if V.Yard_Turned then
                  declare
                     G : constant Castle.Colony.Drawn_Ground := Castle.Colony.Yard_Ground (K);
                     T : Turn_Rec renames Turn_Was (K);
                  begin
                     Put_Line ("  the storehouse, drawn turned on a stockyard along its path (" & V.Phase'Image & ","
                               & V.Blocks'Image & " blocks in its blueprint):"
                               & G.Columns'Image & " columns of ground," & G.Off'Image
                               & " not at their level (the most" & G.Most_Off'Image & " rows off)," & G.Grown'Image
                               & " with something growing over; walked where it is drawn for" & T.Walked_S'Image
                               & " s: in serf-seconds, within it" & T.Within_S'Image & ", where its blocks stand"
                               & T.On_Blocks_S'Image & ", in a wall as drawn" & T.In_Wall_S'Image & ";"
                               & V.Got (Castle.Colony.Stone)'Image & " stones in its ground");
                  end;
               elsif V.Turn /= 0.0 then
                  declare
                     G : constant Castle.Colony.Drawn_Ground := Castle.Colony.House_Drawn_Ground (K);
                     T : Turn_Rec renames Turn_Was (K);
                  begin
                     Put_Line ("  house" & K'Image & " (" & V.Phase'Image & ", its door at " & Img (V.Door.X, 1) & " "
                               & Img (V.Door.Y, 1) & (if V.Owner > 0 then ", " & Castle.Colony.Name_Of (V.Owner) & "'s" else "")
                               & "):" & G.Columns'Image & " columns,"
                               & G.Off'Image & " not at its pad's level (the most" & G.Most_Off'Image & " rows off),"
                               & G.Grown'Image & " with something growing over; there, in serf-seconds: its builder"
                               & T.Builder_S'Image & ", its owner" & T.Owner_S'Image & ", others" & T.Other_S'Image
                               & " (" & T.Other_Stood_S'Image & " of them in the" & T.Stood_S'Image & " s it stood);"
                               & V.Got (Castle.Colony.Stone)'Image & " stones in its ground"
                               & (if T.Walked_S > 0
                                  then "; walked where it is drawn for" & T.Walked_S'Image & " s: within it"
                                       & T.Within_S'Image & ", where its blocks stand" & T.On_Blocks_S'Image
                                       & ", in a wall as drawn" & T.In_Wall_S'Image
                                  else "")
                               & "; a way from the stake to its bed: " & Bed_Way (K, V));
                  end;
               end if;
            end;
         end loop;
      end if;
      if Work_Stats then
         Put_Line ("gatherers, porters and hunters, in serf-hours by what each was doing (an hour or more):");
         loop
            declare
               Best : Natural := 0;
            begin
               for K in 1 .. N_Work loop
                  if Work_Said (K).S > 0 and then (Best = 0 or else Work_Said (K).S > Work_Said (Best).S) then
                     Best := K;
                  end if;
               end loop;
               exit when Best = 0 or else Work_Said (Best).S < 60;
               Put_Line ("  " & Img (Float (Work_Said (Best).S) / 60.0, 1) & "  " & To_String (Work_Said (Best).Text));
               Work_Said (Best).S := 0;
            end;
         end loop;
      end if;
      if Tree_Stats then
         Put_Trees (Ways => True);
         Put_Line ("foresters, in serf-hours by what each was doing:");
         loop
            declare
               Best : Natural := 0;
            begin
               for K in 1 .. N_Said loop
                  if Said (K).S > 0 and then (Best = 0 or else Said (K).S > Said (Best).S) then
                     Best := K;
                  end if;
               end loop;
               exit when Best = 0 or else Said (Best).S < 30;
               Put_Line ("  " & Img (Float (Said (Best).S) / 60.0, 1) & "  " & To_String (Said (Best).Text));
               Said (Best).S := 0;
            end;
         end loop;
      end if;
      if Store_Stats then
         declare
            S : constant Castle.Colony.Store_Stats := Castle.Colony.Store_Counts;
            --  (a colony second is a game minute at the default timescale)
            Used, Over_Used : Natural := 0;
         begin
            for K in 1 .. Castle.Colony.Cell_Count loop
               if Castle.Colony.Cell_At (K).Count > 0 then
                  Used := Used + 1;
                  if Castle.Colony.Cell_At (K).Overflow then
                     Over_Used := Over_Used + 1;
                  end if;
               end if;
            end loop;
            Put_Line ("stores: stood with a load and nowhere to put it " & Img (S.Holding_S / 60.0, 1)
                      & " serf-hours; stood empty-handed for want of room " & Img (S.Roomless_S / 60.0, 1)
                      & " serf-hours; a load first found no place "
                      & (if S.First_Full < 0.0 then "never"
                         else "on day" & Integer'Image (Integer (Long_Float'Floor (S.First_Full / 24.0)))
                              & " at " & Img (Float (S.First_Full - 24.0 * Long_Float'Floor (S.First_Full / 24.0)), 1) & " h")
                      & "; places in use at the end" & Used'Image & " of" & Castle.Colony.Cell_Count'Image
                      & ";" & S.Overflow_Loads'Image & " loads sent to an overflow place, at most"
                      & S.Overflow_Most'Image & " in use at once," & Over_Used'Image & " at the end;"
                      & S.Overflow_Moves'Image & " loads moved from it into the stockpile; it held something "
                      & Img (S.Busy_S / 60.0, 1) & " game hours");
            if S.Holding_S > 0.0 then
               Put ("stores: held with nowhere to put it:");
               for K in Castle.Colony.Item_Kind loop
                  if S.Holding_Of (K) >= 30.0 then
                     Put (" " & Castle.Colony.Name (K) & " " & Img (S.Holding_Of (K) / 60.0, 1));
                  end if;
               end loop;
               New_Line;
            end if;
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
   --  plants over air within the colony's reach of the stake (John, 2026-11-17: "Grass in the air issue
   --  when compacting ground, grass is visible, not attached to the ground in places. Even before
   --  compacting"): each one, with what is under it and a row or two lower
   if Floating and then Castle.Colony.Has_Stake then
      declare
         S  : constant Vec3 := Castle.Colony.Stake;
         Cx : constant Integer := Integer (Float'Floor (S.X * 4.0));
         Cy : constant Integer := Integer (Float'Floor (S.Y * 4.0));
         Cz : constant Integer := Integer (Float'Floor (S.Z * 4.0));
         R  : constant Integer := Integer (Castle.Colony.Work_Radius_M * 4.0);
         N  : Natural := 0;
      begin
         for X in Cx - R .. Cx + R loop
            for Y in Cy - R .. Cy + R loop
               for Z in Cz - 80 .. Cz + 80 loop
                  if Material_At (X, Y, Z) in Tall_Grass | Wild_Grain | Wild_Vegetables
                    and then Material_At (X, Y, Z - 1) = Air
                  then
                     N := N + 1;
                     if N <= 40 then
                        declare
                           Below : Integer := Z - 1;
                        begin
                           while Below > Z - 40 and then Material_At (X, Y, Below) = Air loop
                              Below := Below - 1;
                           end loop;
                           Put_Line ("floating: " & Material'Image (Material_At (X, Y, Z)) & " at block" & X'Image & Y'Image
                                     & Z'Image & " (" & Img (Float (X) * 0.25, 2) & " " & Img (Float (Y) * 0.25, 2)
                                     & "), over" & Integer'Image (Z - 1 - Below) & " rows of air on "
                                     & Material'Image (Material_At (X, Y, Below)) & "; zone"
                                     & Castle.Colony.Zone_On (Float (X) * 0.25 + 0.125, Float (Y) * 0.25 + 0.125)'Image
                                     & (if Castle.Colony.On_Path (Float (X) * 0.25 + 0.125, Float (Y) * 0.25 + 0.125)
                                        then ", on a path" else ""));
                        end;
                     end if;
                  end if;
               end loop;
            end loop;
         end loop;
         Put_Line ("floating:" & N'Image & " plant blocks over air within" & Integer'Image (R / 4) & " m of the stake");
      end;
   end if;
   if Save_Path /= Null_Unbounded_String then
      Save_To (To_String (Save_Path));
      if Natural (Days * 1_440.0) mod Rebuild_S /= 0 then
         Put_Line ("(saved" & Natural'Image (Natural (Days * 1_440.0) mod Rebuild_S)
                   & " colony seconds after the last rebuild of edited ground: a run loaded from this save will not"
                   & " keep step with one run straight on; for that, end the run on a multiple of"
                   & Natural'Image (Rebuild_S) & " colony seconds, 1/48 of a game day)");
      end if;
   end if;
   if Castle.Colony.Razed > 0 then
      Put_Line ("razed:" & Castle.Colony.Razed'Image & " taken down;" & Castle.Colony.Razed_Came_Back (Castle.Colony.Wood)'Image
                & " logs and" & Castle.Colony.Razed_Came_Back (Castle.Colony.Straw)'Image & " sheaves came back to the stores");
   end if;
   if Yard_Walls_Census and then Scan_R = 0.0 and then Castle.Colony.Storehouse > 0 then
      declare
         W : constant Castle.Colony.Yard_Walls := Castle.Colony.Stockyard_Walls;
         Fr : constant Castle.Colony.Yard_Front := Castle.Colony.Stockyard_Front;
         Stone : Natural := 0;
      begin
         for K in 1 .. 4 loop
            Stone := Stone + W.Side (K).Stone;
         end loop;
         Put_Line ("stockyard's stone at the end: on its rim" & Stone'Image & " columns (front" & W.Side (1).Stone'Image
                   & ", back" & W.Side (2).Stone'Image & ", left" & W.Side (3).Stone'Image & ", right" & W.Side (4).Stone'Image
                   & "; the tallest" & Natural'Image (Natural'Max (Natural'Max (W.Side (1).Highest, W.Side (2).Highest),
                                                                    Natural'Max (W.Side (3).Highest, W.Side (4).Highest)))
                   & " blocks); by its design: stair and way" & W.Way'Image & " (" & Img (W.Way_Stair) & " a step of its stair, of"
                   & W.Stair'Image & " columns of steps; the path" & W.Rise'Image & " blocks off its floor; its way in "
                   & (case W.Way_End is when 0 => "at the middle of the storehouse's front",
                                         when 1 => "at its front's low end", when others => "at its front's high end")
                   & "," & W.Way_Deep'Image & " block columns from the front wall's line to the path; the path over its"
                   & " floor at its front's low end, the middle of the storehouse's front, its high end:"
                   & Fr (Castle.Colony.Low_End).Mid'Image & "," & Fr (Castle.Colony.Front_Middle).Mid'Image & ","
                   & Fr (Castle.Colony.High_End).Mid'Image & " blocks)"
                   & ", before its back wall's line" & W.Clear'Image
                   & ", on its fence's line" & W.Fenced'Image & ", on a place for goods" & W.Goods'Image
                   & (if W.Stands
                      then "; as it stands: with the fence's timber over them" & W.Seen_Fence'Image
                        & ", on no place or one kept clear" & W.Seen_Clear'Image
                        & ", on a place that holds goods with no fence over it" & W.Seen_Goods'Image
                      else "; (it does not stand yet)"));
      end;
   end if;
   if Who and then Castle.Colony.Stepped_Aside > 0 then
      Put_Line ("builders:" & Castle.Colony.Stepped_Aside'Image & " times someone stepped aside for a block");
   end if;
   if Who and then Castle.Colony.Builders_Blocked_S > 0.0 then
      Put_Line ("builders: waited " & Img (Castle.Colony.Builders_Blocked_S / 60.0, 1)
                & " game hours in all for someone standing where a block went, the longest wait "
                & Img (Castle.Colony.Builders_Blocked_Longest_S / 60.0, 1) & " game hours");
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
exception
   --  A run that raises says so and leaves at once, with 1.  (Left to the run-time, what it raised is
   --  said and the run then stands for ever, waiting for the workers' tasks, which nobody has told
   --  to stop: two debug scans of a gate stood so for half an hour, 2026-11-21.)
   when E : others =>
      Put_Line ("");
      Put_Line ("raised " & Ada.Exceptions.Exception_Name (E) & " : " & Ada.Exceptions.Exception_Message (E));
      Put_Line (GNAT.Traceback.Symbolic.Symbolic_Traceback (E));
      Flush;
      GNAT.OS_Lib.OS_Exit (1);
end Colony_Run;
