with Ada.Calendar;
with Ada.Command_Line;
with Ada.Text_IO;  use Ada.Text_IO;
with Castle.Dims;  use Castle.Dims;
with Castle.Text;  use Castle.Text;
with Castle.Water;

--  The water simulation on made-up ground, no window: does a basin fill
--  flat and fall asleep, does a breached dam settle level, does a woken
--  stretch of river keep flowing between resting ends, does a tunnel opened
--  onto a pond flood, is every drop accounted for, does the same start give
--  the same end, and does water come back exactly from a save.  And source
--  water: does a lake opened at its bank drop beside the cut and no further
--  off, come back to its level when the cut is closed, and a stream on a
--  hill keep to its bed when part of it wakes.
procedure Water_Sim_Check is

   --  Ground for stacks 0..4 x 0..4 (160 x 160 columns); outside: not known.
   --  Each column: ground with water on it (flowing or still), and maybe a
   --  tunnel below (open rows T_Floor .. T_Ceil - 1).
   N : constant := 160;
   type Grid is array (0 .. N - 1, 0 .. N - 1) of Integer;
   Floor_Of, Water_Of, T_Floor, T_Ceil, T_Water : Grid;
   Flow_Of : array (0 .. N - 1, 0 .. N - 1) of Boolean;

   procedure Ground (Bx, By : Integer; C : out Castle.Water.Column; Known : out Boolean) is
   begin
      C := (N => 0, S => (others => (0, 0, 0)), others => <>);
      Known := Bx in 0 .. N - 1 and then By in 0 .. N - 1;
      if Known then
         C.N := 1;
         C.S (1) := (Floor_Of (Bx, By), Height_B, Water_Of (Bx, By));
         C.Flowing := Flow_Of (Bx, By);
         if T_Ceil (Bx, By) > T_Floor (Bx, By) then
            C.N := 2;
            C.S (2) := (T_Floor (Bx, By), T_Ceil (Bx, By), T_Water (Bx, By));
         end if;
      end if;
   end Ground;

   U       : constant := Castle.Water.Unit;
   Fails   : Natural := 0;
   Tick_Ms   : Float := 0.0;
   Asleep_At : Natural := 0;               --  tick the basin scene fell asleep

   procedure Check (Ok : Boolean; What : String) is
   begin
      Put_Line ((if Ok then "  ok    " else "  FAIL  ") & What);
      if not Ok then
         Fails := Fails + 1;
      end if;
   end Check;

   function Ledger return Long_Long_Integer is
     (Castle.Water.Total + Castle.Water.Went_Out - Castle.Water.Came_In);

   --  Surface spread over the ground stretches with water in [X0, X1] x [Y0, Y1].
   procedure Spread (X0, X1, Y0, Y1 : Integer; Lo, Hi : out Integer) is
   begin
      Lo := Integer'Last;
      Hi := Integer'First;
      for X in X0 .. X1 loop
         for Y in Y0 .. Y1 loop
            declare
               D : constant Integer := Castle.Water.Depth_At (X, Y, Floor_Of (X, Y));
            begin
               if D > 0 then
                  Lo := Integer'Min (Lo, Floor_Of (X, Y) * U + D);
                  Hi := Integer'Max (Hi, Floor_Of (X, Y) * U + D);
               end if;
            end;
         end loop;
      end loop;
   end Spread;

   --  A walled basin: floor 40 inside [8, 87]^2, walls 80 round it.
   procedure Basin is
   begin
      for X in 0 .. N - 1 loop
         for Y in 0 .. N - 1 loop
            Floor_Of (X, Y) := (if X in 8 .. 87 and then Y in 8 .. 87 then 40 else 80);
            Water_Of (X, Y) := 0;
            T_Floor (X, Y) := 0;
            T_Ceil (X, Y) := 0;
            T_Water (X, Y) := 0;
            Flow_Of (X, Y) := False;
         end loop;
      end loop;
   end Basin;

   procedure Wake_All is
   begin
      for CX in 0 .. 2 loop
         for CY in 0 .. 2 loop
            Castle.Water.Wake (CX, CY);
         end loop;
      end loop;
   end Wake_All;

   function Hash return Long_Long_Integer is
      H : Long_Long_Integer := 0;
   begin
      for X in 0 .. N - 1 loop
         for Y in 0 .. N - 1 loop
            H := (H * 31 + Long_Long_Integer (Castle.Water.Depth (X, Y))) mod 1_000_000_007;
         end loop;
      end loop;
      return H;
   end Hash;

   function Run_Basin return Long_Long_Integer is
      use Ada.Calendar;
      T0 : Time;
   begin
      Castle.Water.Reset;
      Basin;
      for X in 10 .. 17 loop
         for Y in 10 .. 17 loop
            Water_Of (X, Y) := 60;            --  a 2 m x 2 m tower of water, 15 m tall
         end loop;
      end loop;
      Wake_All;
      T0 := Clock;
      for T in 1 .. 300 loop                  --  all nine stacks awake throughout
         Castle.Water.Tick;
      end loop;
      Tick_Ms := Float (Clock - T0) * 1000.0 / 300.0;
      for T in 301 .. 3_000 loop
         Castle.Water.Tick;
         if Castle.Water.Awake_Count = 0 and then Asleep_At = 0 then
            Asleep_At := T;
         end if;
      end loop;
      return Hash;
   end Run_Basin;

   Lo, Hi : Integer;

   --  How long a scene takes to settle (all asleep) and how flat it ends.
   procedure Settle (Label : String; Dam : Boolean) is
      Ticks : Natural := 0;
   begin
      Castle.Water.Reset;
      Basin;
      for X in 8 .. 87 loop
         for Y in 8 .. 87 loop
            if Dam then
               Water_Of (X, Y) := (if X < 47 then 8 else 0);
            elsif X in 10 .. 17 and then Y in 10 .. 17 then
               Water_Of (X, Y) := 60;
            end if;
         end loop;
      end loop;
      Wake_All;
      loop
         Castle.Water.Tick;
         Ticks := Ticks + 1;
         exit when Ticks >= 30 and then Castle.Water.Awake_Count = 0;
         exit when Ticks >= 4_000;
      end loop;
      Spread (8, 87, 8, 87, Lo, Hi);
      Put (Label & ": " & Img (Ticks) & " ticks, spread " & Img (Float (Hi - Lo) / Float (U), 3) & " blocks; ");
   end Settle;

begin
   Castle.Water.Set_Ground (Ground'Unrestricted_Access);

   if Ada.Command_Line.Argument_Count > 0 then
      Settle ("basin", False);
      Settle ("dam", True);
      New_Line;
      return;
   end if;

   --  1. A tower of water in a basin's corner spreads, settles flat, sleeps.
   declare
      H1    : constant Long_Long_Integer := Run_Basin;
      Start : constant Long_Long_Integer := 64 * 60 * Long_Long_Integer (U);
   begin
      Put_Line ("basin:");
      Check (Ledger = Start, "every drop accounted for (" & Long_Long_Integer'Image (Ledger) & " of"
             & Long_Long_Integer'Image (Start) & ")");
      Spread (8, 87, 8, 87, Lo, Hi);
      Check (Hi - Lo <= U / 8, "settled flat: surface within " & Img (Hi - Lo) & " units (1/8 block ="
             & Integer'Image (U / 8) & ")");
      Check (Lo >= 40 * U + 55 * U / 100 and then Hi <= 40 * U + 67 * U / 100,
             "at the level the water's volume gives: " & Img (Float (Hi - 40 * U) / Float (U), 2)
             & " blocks deep (expect 0.6)");
      Check (Castle.Water.Awake_Count = 0, "and fell asleep (awake stacks:" & Castle.Water.Awake_Count'Image & ")");
      Check ((for all CX in 0 .. 2 => (for all CY in 0 .. 2 => not Castle.Water.Is_Running (CX, CY))),
             "as settled water, not as running water (nothing feeds it: it may dry)");
      Check (Run_Basin = H1, "the same start gives the same end, to the unit");
      Put_Line ("  cost: " & Img (Tick_Ms, 3) & " ms a tick for 9 awake stacks (4 steps each);"
                & " asleep after" & Asleep_At'Image & " ticks");
   end;

   --  2. A dam between a full half and an empty half is taken down.
   declare
      Start : Long_Long_Integer;
   begin
      Put_Line ("dam:");
      Castle.Water.Reset;
      Basin;
      for X in 8 .. 87 loop
         for Y in 8 .. 87 loop
            if X in 47 .. 48 then
               Floor_Of (X, Y) := 80;           --  the dam
            elsif X < 47 then
               Water_Of (X, Y) := 8;            --  2 m of water behind it
            end if;
         end loop;
      end loop;
      Wake_All;
      for T in 1 .. 100 loop
         Castle.Water.Tick;
      end loop;
      Start := Ledger;
      Check (Castle.Water.Awake_Count = 0, "held by the dam, it rests");
      for Y in 8 .. 87 loop
         for X in 47 .. 48 loop
            Floor_Of (X, Y) := 40;
            Castle.Water.Ground_Changed (X, Y);
         end loop;
      end loop;
      for T in 1 .. 4_000 loop
         Castle.Water.Tick;
      end loop;
      Check (Ledger = Start, "every drop accounted for after the breach");
      Spread (8, 87, 8, 87, Lo, Hi);
      Check (Hi - Lo <= U / 8, "both halves level: surface within " & Img (Hi - Lo) & " units");
      Check (abs (Hi - (40 * U + 4 * 39 * U / 40)) <= U / 4,
             "at half the old depth: " & Img (Float (Hi - 40 * U) / Float (U), 2) & " blocks (expect 3.9)");
      Check (Castle.Water.Awake_Count = 0, "and fell asleep again");
   end;

   --  3. A stretch of river woken in the middle stack: source water is
   --  locked, so it stays exactly as generated, nothing comes in or runs
   --  out, and it falls asleep (its flow is drawn, not simulated).
   declare
      Before : Long_Long_Integer;
   begin
      Put_Line ("river:");
      Castle.Water.Reset;
      Basin;
      for X in 0 .. N - 1 loop
         for Y in 0 .. N - 1 loop
            --  the bed falls 1 block every 8 columns; 2 blocks of water in it
            Floor_Of (X, Y) := (if Y in 40 .. 55 then 60 - X / 8 else 90);
            Water_Of (X, Y) := (if Y in 40 .. 55 then 2 else 0);
            Flow_Of (X, Y) := Y in 40 .. 55;
         end loop;
      end loop;
      Castle.Water.Wake (1, 1);                --  the middle stack only
      Before := Castle.Water.Total;
      for T in 1 .. 600 loop
         Castle.Water.Tick;
      end loop;
      Check (Castle.Water.Total = Before and then Castle.Water.Came_In = 0 and then Castle.Water.Went_Out = 0,
             "it holds exactly what it was given: nothing in, nothing out");
      declare
         Same : Boolean := True;
      begin
         for X in 32 .. 63 loop
            for Y in 40 .. 55 loop
               Same := Same and then Castle.Water.Depth_At (X, Y, Floor_Of (X, Y)) = 2 * U;
            end loop;
         end loop;
         Check (Same, "every column keeps its 2 blocks, sloping bed and all");
      end;
      Check (not Castle.Water.Is_Awake (1, 1), "and it fell asleep");
      Check (Castle.Water.Simulated_Count = 1, "the river banks stayed asleep (simulated stacks:"
             & Castle.Water.Simulated_Count'Image & ")");
      --  source water is fed as fast as it dries (it used to sink into its
      --  bed once woken: nothing filled a locked column again)
      declare
         pragma Warnings (Off, "formal parameter * is not referenced");   --  the same everywhere
         function Gravel (Bx, By, Row : Integer) return Float is (40.0);
         pragma Warnings (On, "formal parameter * is not referenced");
         Same : Boolean := True;
      begin
         Castle.Water.Set_Seep (Gravel'Unrestricted_Access);
         Castle.Water.Dry_Out (Hours => 10.0, Evaporation_Mm => 2.0, Seep_Scale => 1.0);
         Castle.Water.Set_Seep (null);
         for X in 32 .. 63 loop
            for Y in 40 .. 55 loop
               Same := Same and then Castle.Water.Depth_At (X, Y, Floor_Of (X, Y)) = 2 * U;
            end loop;
         end loop;
         Check (Same, "ten dry hours on a gravel bed and it still runs 2 blocks deep");
      end;
   end;

   --  4. A pond, and beside it land with a closed tunnel under it.  Digging
   --  through the 2-column wall between them lets the pond into the tunnel.
   declare
      Start      : Long_Long_Integer;
      Full, Cols : Natural := 0;
      Over       : Integer := 0;
   begin
      Put_Line ("tunnel:");
      Castle.Water.Reset;
      Basin;
      for X in 8 .. 87 loop
         for Y in 8 .. 87 loop
            if X <= 40 then
               Water_Of (X, Y) := 8;                 --  pond: floor 40, surface 48
            else
               Floor_Of (X, Y) := 52;                --  land above the pond's surface
               if X >= 43 and then X <= 80 and then Y in 40 .. 47 then
                  T_Floor (X, Y) := 42;              --  the tunnel: rows 42 .. 45
                  T_Ceil (X, Y) := 46;
               end if;
            end if;
         end loop;
      end loop;
      Wake_All;
      for T in 1 .. 100 loop
         Castle.Water.Tick;
      end loop;
      Check (Castle.Water.Depth_At (60, 44, 43) = 0, "the closed tunnel stays dry");
      Start := Ledger;
      for X in 41 .. 42 loop
         for Y in 40 .. 47 loop
            T_Floor (X, Y) := 42;                    --  dig through
            T_Ceil (X, Y) := 46;
            Castle.Water.Ground_Changed (X, Y);
         end loop;
      end loop;
      for T in 1 .. 1_500 loop
         Castle.Water.Tick;
      end loop;
      for X in 41 .. 80 loop
         for Y in 40 .. 47 loop
            declare
               D : constant Integer := Castle.Water.Depth_At (X, Y, 43);
            begin
               Cols := Cols + 1;
               if D >= 4 * U - U / 8 then
                  Full := Full + 1;
               end if;
               Over := Integer'Max (Over, D - 4 * U);
            end;
         end loop;
      end loop;
      Check (Full = Cols, "the tunnel floods to its roof:" & Full'Image & " of" & Cols'Image & " columns full");
      Check (Over <= U / 16, "and no higher (most over the roof: " & Img (Float (Over) / Float (U), 3) & " blocks)");
      Check (Ledger = Start, "every drop accounted for");
      Check (abs (Castle.Water.Depth_At (20, 44, 40) - (8 * U - 320 * 4 * U / (33 * 80))) <= U / 8,
             "the pond fell by what the tunnel took: " & Img (Float (Castle.Water.Depth_At (20, 44, 40)) / Float (U), 2)
             & " blocks deep (expect 7.52)");
      Check (Castle.Water.Depth_At (60, 44, 52) = 0, "the ground over the tunnel stays dry");
   end;

   --  5. A lake breached into a dry basin next to it.  Only the stacks round
   --  the breach wake; the rest of the lake rests.  Still water holds only
   --  what it has: the lake wakes as the flow reaches it and drains into the
   --  basin until both lie level, and nothing comes in from a resting edge.
   declare
      Lo2, Hi2 : Integer;
   begin
      Put_Line ("lake breach:");
      Castle.Water.Reset;
      Basin;
      for X in 0 .. N - 1 loop
         for Y in 0 .. N - 1 loop
            Floor_Of (X, Y) := (if X in 8 .. 151 and then Y in 8 .. 151 then 40 else 80);
            if X in 112 .. 113 then
               Floor_Of (X, Y) := 80;           --  the lake's rim
            elsif X in 8 .. 111 and then Y in 8 .. 151 then
               Water_Of (X, Y) := 8;            --  the lake, still water
            end if;
         end loop;
      end loop;
      for Y in 72 .. 79 loop
         for X in 112 .. 113 loop
            Floor_Of (X, Y) := 40;              --  the breach
            Castle.Water.Ground_Changed (X, Y);
         end loop;
      end loop;
      for T in 1 .. 6_000 loop
         Castle.Water.Tick;
      end loop;
      Check (Castle.Water.Came_In = 0, "nothing came in from resting water");
      Check (Castle.Water.Simulated_Count = 25, "the whole lake woke as the flow reached it ("
             & Castle.Water.Simulated_Count'Image & " of 25 stacks)");
      Spread (8, 151, 8, 151, Lo2, Hi2);
      Check (abs (Hi2 - (40 * U + 8 * 104 * 144 * U / (104 * 144 + 38 * 144 + 16))) <= U / 4
             and then Hi2 - Lo2 <= U / 4,
             "and lake and basin lie level at what the lake held: "
             & Img (Float (Hi2 - 40 * U) / Float (U), 2) & " blocks (expect 5.85)");
   end;

   --  5c. A river cut into: it gives what it carries, no more.  The river
   --  runs along one side, a breach opens it to a deep basin.  The river
   --  beside the cut wakes and runs out through it; what comes in is what
   --  its refill brings (at most Recharge a column a step) and what its
   --  resting ends give (at most twice Supply a face a step).  A river
   --  that carries ten times as much gives several times as much.
   declare
      Small, Rich : Long_Long_Integer := 0;
      Awake_Cols  : Natural := 0;
      function Tight (Bx, By : Integer) return Natural is (200);
      pragma Warnings (Off, "formal parameter * is not referenced");   --  the same everywhere
      function Tight_Refill (Bx, By : Integer) return Natural is (25);
      function Full (Bx, By : Integer) return Natural is (2_000);
      function Full_Refill (Bx, By : Integer) return Natural is (250);
      pragma Warnings (On, "formal parameter * is not referenced");
      Steps : constant := 4 * 300;
   begin
      Put_Line ("river supply:");
      for Pass in 1 .. 2 loop
         Castle.Water.Reset;
         Basin;
         for X in 0 .. N - 1 loop
            for Y in 0 .. N - 1 loop
               Floor_Of (X, Y) := 40;
               Water_Of (X, Y) := 0;
               Flow_Of (X, Y) := False;
               if X <= 31 then
                  Water_Of (X, Y) := 8;           --  the river, its own stacks the whole length
                  Flow_Of (X, Y) := True;
               elsif X in 32 .. 33 then
                  Floor_Of (X, Y) := 80;          --  its bank, in the next stacks
               else
                  Floor_Of (X, Y) := 20;          --  a deep basin beyond
               end if;
            end loop;
         end loop;
         if Pass = 1 then
            Castle.Water.Set_Supply (Tight'Unrestricted_Access);
            Castle.Water.Set_Recharge (Tight_Refill'Unrestricted_Access);
         else
            Castle.Water.Set_Supply (Full'Unrestricted_Access);
            Castle.Water.Set_Recharge (Full_Refill'Unrestricted_Access);
         end if;
         for Y in 72 .. 79 loop
            for X in 32 .. 33 loop
               Floor_Of (X, Y) := 44;             --  the cut, a metre above the river's bed
               Castle.Water.Ground_Changed (X, Y);
            end loop;
         end loop;
         for T in 1 .. 300 loop
            Castle.Water.Tick;
         end loop;
         if Pass = 1 then
            Small := Castle.Water.Came_In;
            for CY in 0 .. 4 loop
               if Castle.Water.Is_Simulated (0, CY) then
                  Awake_Cols := Awake_Cols + 32 * 32;
               end if;
            end loop;
         else
            Rich := Castle.Water.Came_In;
         end if;
         Castle.Water.Set_Supply (null);
         Castle.Water.Set_Recharge (null);
      end loop;
      declare
         --  every woken river column refilled at its most, and both resting ends giving theirs
         M : constant Long_Long_Integer :=
           (Long_Long_Integer (Awake_Cols) * 25 + 64 * 400) * Steps;
      begin
         Check (Small > 0 and then Small <= M,
                "the cut drew no more than the river brings:" & Long_Long_Integer'Image (Small / U)
                & " blocks of water in 30 s (at most" & Long_Long_Integer'Image (M / U) & ")");
      end;
      Check (Rich > 2 * Small, "where the river carries more, more comes:"
             & Long_Long_Integer'Image (Rich / U) & " blocks");
   end;

   --  5d. Drying: water nothing feeds goes in the end.  A puddle a block
   --  deep on sand soaks away; the same on rock only evaporates.
   declare
      Before : Long_Long_Integer;
      function Sand_Or_Rock (Bx, By, Row : Integer) return Float is (if Bx < 16 then 25.0 else 0.0);
   begin
      Put_Line ("drying:");
      Castle.Water.Reset;
      Basin;
      for X in 0 .. N - 1 loop
         for Y in 0 .. N - 1 loop
            Floor_Of (X, Y) := (if X = 16 then 80 else 40);
            Water_Of (X, Y) := (if X in 8 .. 23 and then Y in 8 .. 15 and then X /= 16 then 1 else 0);
            Flow_Of (X, Y) := False;
         end loop;
      end loop;
      Castle.Water.Wake (0, 0);
      Castle.Water.Set_Seep (Sand_Or_Rock'Unrestricted_Access);
      Before := Castle.Water.Total;
      Castle.Water.Dry_Out (Hours => 10.0, Evaporation_Mm => 2.0, Seep_Scale => 1.0);
      Check (Castle.Water.Depth (12, 12) = 0, "the puddle on sand soaked away in 10 hours");
      Check (abs (Castle.Water.Depth (20, 12) - (U - 20 * U / 250)) <= 2,
             "the one on rock lost 20 mm to the air:" & Integer'Image ((U - Castle.Water.Depth (20, 12)) * 250 / U) & " mm");
      Check (Castle.Water.Total + Castle.Water.Dried = Before, "every drop accounted for");
      Castle.Water.Set_Seep (null);
   end;

   --  5e. Water let off a source runs out.  A stream (three blocks deep)
   --  cut into open ground level with its bed spreads round the cut and
   --  stops: the wet patch stops growing, and it covers nothing like the
   --  plain.  (Without the leak the plain would fill to the stream's level.)
   declare
      function Supply_200 (Bx, By : Integer) return Natural is (200);
      pragma Warnings (Off, "formal parameter * is not referenced");   --  the same everywhere
      function Refill_25 (Bx, By : Integer) return Natural is (25);
      pragma Warnings (On, "formal parameter * is not referenced");
      function Wet_Count return Natural is
         C : Natural := 0;
      begin
         for X in 34 .. N - 1 loop
            for Y in 0 .. N - 1 loop
               if Castle.Water.Depth (X, Y) > 0 then
                  C := C + 1;
               end if;
            end loop;
         end loop;
         return C;
      end Wet_Count;
      Wet1, Wet2 : Natural;
   begin
      Put_Line ("spread and run out:");
      Castle.Water.Reset;
      Basin;
      for X in 0 .. N - 1 loop
         for Y in 0 .. N - 1 loop
            Floor_Of (X, Y) := 40;
            Water_Of (X, Y) := 0;
            Flow_Of (X, Y) := False;
            if X <= 31 then
               Water_Of (X, Y) := 3;              --  the stream
               Flow_Of (X, Y) := True;
            elsif X in 32 .. 33 then
               Floor_Of (X, Y) := 80;             --  its bank; beyond, a plain level with its bed
            end if;
         end loop;
      end loop;
      Castle.Water.Set_Supply (Supply_200'Unrestricted_Access);
      Castle.Water.Set_Recharge (Refill_25'Unrestricted_Access);
      Castle.Water.Set_Leak (True);
      for Y in 76 .. 77 loop
         for X in 32 .. 33 loop
            Floor_Of (X, Y) := 40;                --  a cut two columns wide
            Castle.Water.Ground_Changed (X, Y);
         end loop;
      end loop;
      for T in 1 .. 1_500 loop
         Castle.Water.Tick;
      end loop;
      Wet1 := Wet_Count;
      for T in 1 .. 1_500 loop
         Castle.Water.Tick;
      end loop;
      Wet2 := Wet_Count;
      Check (Wet2 > 0 and then Wet2 <= Wet1 + Wet1 / 10,
             "the wet patch stops growing:" & Wet1'Image & " columns after 150 s," & Wet2'Image & " after 300 s");
      Check (Wet2 < 126 * 160 / 4,
             "and covers nothing like the plain:" & Wet2'Image & " of" & Integer'Image (126 * 160) & " columns");
      Put_Line ("  (the stream 8 m off stands "
                & Img (Float (Castle.Water.Depth_At (16, 44, 40)) / Float (U), 2) & " blocks deep of 3;"
                & Castle.Water.Awake_Count'Image & " stacks awake)");
      Castle.Water.Set_Leak (False);
      Castle.Water.Set_Supply (null);
      Castle.Water.Set_Recharge (null);
   end;

   --  6. A pond barely disturbed: a hole dug in its floor.  How big a wave
   --  reaches the far shore, 25 m away, over the next 10 s?
   declare
      Level : constant Integer := 40 * U + 8 * U;
      Worst : Integer := 0;
   begin
      Put_Line ("calm:");
      Castle.Water.Reset;
      Basin;
      for X in 8 .. 87 loop
         for Y in 8 .. 87 loop
            Water_Of (X, Y) := 8;
         end loop;
      end loop;
      Wake_All;
      for T in 1 .. 30 loop
         Castle.Water.Tick;
      end loop;
      for X in 46 .. 49 loop
         for Y in 46 .. 49 loop
            Floor_Of (X, Y) := 36;
            Castle.Water.Ground_Changed (X, Y);
         end loop;
      end loop;
      for T in 1 .. 100 loop
         Castle.Water.Tick;
         for X in 8 .. 12 loop
            for Y in 8 .. 87 loop
               Worst := Integer'Max (Worst, abs (40 * U + Castle.Water.Depth_At (X, Y, 40) - Level));
            end loop;
         end loop;
      end loop;
      Check (Worst <= U / 16, "the biggest wave at the far shore: " & Img (Float (Worst) / Float (U), 3)
             & " blocks (1/16 allowed; the hole took 0.010 off the whole pond)");
   end;

   --  6b. Building in water.  A block placed in water takes its place: a
   --  pier raised through a pond stands dry, the pond keeps its level and
   --  no wave runs from it.  (The water used to be lifted onto the pier, a
   --  column as tall as the pond was deep.)  Over a bed raised under water
   --  the level stays; into a hole dug under it the water falls whole.
   declare
      Level : constant Integer := 40 * U + 8 * U;
      Start : Long_Long_Integer;
      Worst : Integer := 0;
      Dry   : Boolean := True;
   begin
      Put_Line ("building in water:");
      Castle.Water.Reset;
      Basin;
      for X in 8 .. 87 loop
         for Y in 8 .. 87 loop
            Water_Of (X, Y) := 8;
         end loop;
      end loop;
      Wake_All;
      for T in 1 .. 30 loop
         Castle.Water.Tick;
      end loop;
      Start := Ledger;
      for X in 40 .. 47 loop
         for Y in 40 .. 47 loop
            Floor_Of (X, Y) := 52;              --  the pier, a metre above the pond
            Castle.Water.Ground_Changed (X, Y);
         end loop;
      end loop;
      for X in 60 .. 63 loop
         for Y in 60 .. 63 loop
            Floor_Of (X, Y) := 42;              --  the bed raised two blocks under water
            Castle.Water.Ground_Changed (X, Y);
         end loop;
      end loop;
      Check (Castle.Water.Depth_At (44, 44, 52) = 0, "nothing is lifted onto the pier");
      Check (Castle.Water.Depth_At (61, 61, 42) = 6 * U,
             "over the raised bed the water keeps its level: "
             & Img (Float (Castle.Water.Depth_At (61, 61, 42)) / Float (U), 2) & " blocks (expect 6.00)");
      for T in 1 .. 300 loop
         Castle.Water.Tick;
         for X in 8 .. 87 loop
            for Y in 8 .. 87 loop
               if Floor_Of (X, Y) = 52 then
                  Dry := Dry and then Castle.Water.Depth_At (X, Y, 52) = 0;
               else
                  Worst := Integer'Max
                    (Worst, abs (Floor_Of (X, Y) * U + Castle.Water.Depth_At (X, Y, Floor_Of (X, Y)) - Level));
               end if;
            end loop;
         end loop;
      end loop;
      Check (Dry, "the pier stays dry");
      Check (Worst <= U / 16, "and the pond keeps its level: " & Img (Float (Worst) / Float (U), 3)
             & " blocks off at most (1/16 allowed)");
      Check (Ledger = Start, "every drop accounted for (what the blocks displaced went out)");
      Floor_Of (20, 20) := 36;                  --  a hole a metre deep dug under the pond
      Castle.Water.Ground_Changed (20, 20);
      Check (Castle.Water.Depth_At (20, 20, 36) >= 8 * U - U / 16,
             "into a hole dug under it the water falls whole: "
             & Img (Float (Castle.Water.Depth_At (20, 20, 36)) / Float (U), 2) & " blocks (expect 8.00)");
   end;

   --  7. A save and back: every stretch of every stack exactly as it was.
   declare
      type Kept is record
         CX, CY : Integer;
         Awake  : Boolean;
         C      : Castle.Water.Stack_Columns;
      end record;
      type Kept_Array is array (1 .. 32) of Kept;
      type Kept_Access is access Kept_Array;
      K      : constant Kept_Access := new Kept_Array;
      Count  : Natural := 0;
      H0     : constant Long_Long_Integer := Hash;
      T0     : constant Long_Long_Integer := Castle.Water.Total;
      procedure Take (CX, CY : Integer; Awake : Boolean; C : Castle.Water.Stack_Columns) is
      begin
         Count := Count + 1;
         K (Count) := (CX, CY, Awake, C);
      end Take;
   begin
      Put_Line ("save:");
      Castle.Water.Each_Stack (Take'Access);
      Castle.Water.Reset;
      Check (Castle.Water.Simulated_Count = 0 and then Castle.Water.Total = 0, "forgotten");
      for I in 1 .. Count loop
         Castle.Water.Restore (K (I).CX, K (I).CY, K (I).Awake, K (I).C);
      end loop;
      Check (Hash = H0 and then Castle.Water.Total = T0, "restored exactly:" & Count'Image & " stacks");
   end;

   --  8. Source water, on a wider ground (320 x 320 columns): a lake three
   --  metres deep behind a bank with the land falling away beyond it, and
   --  a stream on a hill.
   declare
      M : constant := 320;
      type Wide is array (0 .. M - 1, 0 .. M - 1) of Integer;
      type Wide_Access is access Wide;
      Fl : constant Wide_Access := new Wide'(others => (others => 0));
      Wa : constant Wide_Access := new Wide'(others => (others => 0));
      Rs : constant Wide_Access := new Wide'(others => (others => 0));   --  source water: the row it rests at

      procedure Wide_Ground (Bx, By : Integer; C : out Castle.Water.Column; Known : out Boolean) is
      begin
         C := (N => 0, S => (others => (0, 0, 0)), others => <>);
         Known := Bx in 0 .. M - 1 and then By in 0 .. M - 1;
         if Known then
            C.N := 1;
            --  as the game's ground has it: what was made as source water
            --  and the level it was made at, whatever is dug or built since
            C.S (1) := (Fl (Bx, By), Height_B, Integer'Max (0, Integer'Min (Wa (Bx, By), Rs (Bx, By) - Fl (Bx, By))));
            C.Flowing := Rs (Bx, By) > 0;
            C.Rest := Rs (Bx, By) * U;
         end if;
      end Wide_Ground;

      pragma Warnings (Off, "formal parameter * is not referenced");   --  the same everywhere
      function Lake_Refill (Bx, By : Integer) return Natural is (256);
      function Stream_Refill (Bx, By : Integer) return Natural is (200);
      function Stream_Supply (Bx, By : Integer) return Natural is (3_146);
      pragma Warnings (On, "formal parameter * is not referenced");

      Bank  : constant := 128;                  --  the bank: X 128 .. 135; the water lies west of it
      Y0    : constant := 160;                  --  the cut: Y 160 .. 163
      Level : constant := 112;                  --  the lake's surface (row)

      --  How far the water at (X, Y) stands from Rest (a row), in units
      --  (never woken, it lies as the ground has it).
      function Off (X, Y, Rest : Integer) return Integer is
        (if Castle.Water.Depth_At (X, Y, Fl (X, Y)) < 0 then (Fl (X, Y) + Wa (X, Y) - Rest) * U
         else Fl (X, Y) * U + Castle.Water.Depth_At (X, Y, Fl (X, Y)) - Rest * U);

      procedure Lake is
      begin
         Castle.Water.Reset;
         for X in 0 .. M - 1 loop
            for Y in 0 .. M - 1 loop
               if X < Bank then
                  Fl (X, Y) := Level - 12;
                  Wa (X, Y) := 12;
                  Rs (X, Y) := Level;
               elsif X < Bank + 8 then
                  Fl (X, Y) := Level + 8;
                  Wa (X, Y) := 0;
                  Rs (X, Y) := 0;
               else
                  Fl (X, Y) := Level - 12 - (X - Bank - 8) / 2;
                  Wa (X, Y) := 0;
                  Rs (X, Y) := 0;
               end if;
            end loop;
         end loop;
      end Lake;

      procedure Cut (To : Integer) is
      begin
         for X in Bank .. Bank + 7 loop
            for Y in Y0 .. Y0 + 3 loop
               Fl (X, Y) := To;
               Castle.Water.Ground_Changed (X, Y);
            end loop;
         end loop;
      end Cut;

      procedure Run (Ticks : Natural) is
      begin
         for T in 1 .. Ticks loop
            Castle.Water.Tick;
         end loop;
      end Run;
   begin
      Castle.Water.Set_Ground (Wide_Ground'Unrestricted_Access);
      Castle.Water.Set_Leak (True);

      --  8a. Dug under before it ever woke, source water is at its level.
      Put_Line ("source water, first touched:");
      Lake;
      Fl (60, 60) := Level - 16;
      Castle.Water.Ground_Changed (60, 60);
      Check (Castle.Water.Depth_At (60, 60, Level - 16) = 16 * U,
             "a column of the lake dug a metre deeper stands full to the lake's level: "
             & Img (Float (Castle.Water.Depth_At (60, 60, Level - 16)) / Float (U), 2) & " blocks (expect 16.00)");
      Check (Castle.Water.Depth_At (61, 60, Level - 12) = 12 * U, "and the lake beside it lies as it did");
      Run (100);
      Check (Castle.Water.Awake_Count = 0 and then Castle.Water.Came_In = 0,
             "nothing moves for it, and it sleeps");

      --  8a2. The world as it was made holds its water: a gap in the bank
      --  that was always there (the lip of a fall) lets nothing out, however
      --  low; dug one block deeper, it runs.
      Put_Line ("source water, a gap that was made with the world:");
      Lake;
      for X in Bank .. Bank + 7 loop
         for Y in Y0 .. Y0 + 3 loop
            Fl (X, Y) := Level - 6;              --  as made: no edit
         end loop;
      end loop;
      Castle.Water.Set_Recharge (Lake_Refill'Unrestricted_Access);
      for CX in 3 .. 5 loop
         for CY in 4 .. 6 loop
            Castle.Water.Wake (CX, CY);
         end loop;
      end loop;
      Run (100);
      Check (Castle.Water.Depth_At (Bank, Y0 + 1, Level - 6) = 0 and then Castle.Water.Came_In = 0
             and then Off (Bank - 1, Y0 + 1, Level) = 0,
             "woken, the lake stays in: nothing in the gap, nothing drawn");
      Check (Castle.Water.Awake_Count = 0, "and it sleeps");
      Fl (Bank, Y0 + 1) := Level - 7;
      Castle.Water.Ground_Changed (Bank, Y0 + 1);
      Run (100);
      Check (Castle.Water.Depth_At (Bank + 4, Y0 + 1, Level - 6) > 0 and then Off (Bank - 1, Y0 + 1, Level) < 0,
             "one block of the gap dug out, and the lake runs through it");
      Castle.Water.Set_Recharge (null);

      --  8b. The lake opened at its bank, the cut a metre and a half deep.
      Put_Line ("source water, a lake opened:");
      Lake;
      Castle.Water.Set_Recharge (Lake_Refill'Unrestricted_Access);
      Castle.Water.Set_Supply (Stream_Supply'Unrestricted_Access);
      Cut (Level - 6);
      Run (600);
      declare
         At_Cut : constant Integer := Off (Bank - 1, Y0 + 1, Level);
         Near   : constant Integer := Off (Bank - 9, Y0 + 1, Level);     --  2 m in
         Far    : constant Integer := Off (Bank - 41, Y0 + 1, Level);    --  10 m in
         Step   : Integer := 0;
         Far_1  : Integer;
         Awake  : constant Natural := Castle.Water.Awake_Count;
      begin
         Check (At_Cut < -U / 4, "the water beside the cut has dropped: "
                & Img (Float (-At_Cut) / Float (U), 2) & " blocks");
         Check (Near > At_Cut and then Near < 0 and then Far > Near and then Far >= -U / 8,
                "less the further from it: " & Img (Float (-Near) / Float (U), 2) & " blocks 2 m in, "
                & Img (Float (-Far) / Float (U), 2) & " blocks 10 m in");
         --  from 10 m in the lake to the middle of the cut, along its line
         for X in Bank - 40 .. Bank + 3 loop
            Step := Integer'Max (Step, abs (Off (X, Y0 + 1, Level) - Off (X - 1, Y0 + 1, Level)));
         end loop;
         Check (Step <= U, "it runs down into the cut without a wall: the biggest step from one column to the next is "
                & Img (Float (Step) / Float (U), 2) & " blocks (the water stands 6 over the cut's floor)");
         Check (not Castle.Water.Is_Simulated (0, 5) and then not Castle.Water.Is_Simulated (1, 5),
                "the lake 16 m off and more never woke");
         Check (Awake <= 24, "and few stacks are awake for it:" & Awake'Image);
         Far_1 := Off (Bank - 41, Y0 + 1, Level);
         Run (600);
         Check (abs (Off (Bank - 41, Y0 + 1, Level) - Far_1) <= U / 64
                and then abs (Off (Bank - 1, Y0 + 1, Level) - At_Cut) <= U / 16,
                "the flow is established: a minute on the lake lies the same (it is fed, and does not drain)");
      end;

      --  8c. A save and back with the lake drawn down.
      declare
         type Kept is record
            CX, CY : Integer;
            Awake  : Boolean;
            C      : Castle.Water.Stack_Columns;
         end record;
         type Kept_Array is array (1 .. 64) of Kept;
         type Kept_Access is access Kept_Array;
         K     : constant Kept_Access := new Kept_Array;
         Count : Natural := 0;
         Same  : Boolean := True;
         Seen  : Natural := 0;
         T0    : constant Long_Long_Integer := Castle.Water.Total;
         R0    : constant Integer := Castle.Water.Rest_Level (Bank - 1, Y0 + 1);
         procedure Take (CX, CY : Integer; Awake : Boolean; C : Castle.Water.Stack_Columns) is
         begin
            Count := Count + 1;
            K (Count) := (CX, CY, Awake, C);
         end Take;
         procedure Compare (CX, CY : Integer; Awake : Boolean; C : Castle.Water.Stack_Columns) is
            use type Castle.Water.Stack_Columns;
         begin
            Seen := Seen + 1;
            Same := Same and then Seen <= Count and then K (Seen).CX = CX and then K (Seen).CY = CY
              and then K (Seen).Awake = Awake and then K (Seen).C = C;
         end Compare;
      begin
         Castle.Water.Each_Stack (Take'Access);
         Castle.Water.Reset;
         for I in 1 .. Count loop
            Castle.Water.Restore (K (I).CX, K (I).CY, K (I).Awake, K (I).C);
         end loop;
         Castle.Water.Each_Stack (Compare'Access);
         Check (Same and then Seen = Count and then Castle.Water.Total = T0,
                "saved and restored with the lake drawn down: every column as it was (" & Img (Count) & " stacks)");
         Check (R0 = Level * U and then Castle.Water.Rest_Level (Bank - 1, Y0 + 1) = R0,
                "and it still knows the level it is to come back to");
      end;

      --  8d. The cut closed again.
      Put_Line ("source water, the cut closed:");
      Cut (Level + 8);
      declare
         Ticks  : Natural := 0;
         Back   : Boolean := True;
         On_Top : Boolean := False;
      begin
         loop
            Castle.Water.Tick;
            Ticks := Ticks + 1;
            exit when Ticks >= 50 and then Castle.Water.Awake_Count = 0;
            exit when Ticks >= 6_000;
         end loop;
         for X in 64 .. Bank - 1 loop
            for Y in Y0 - 96 .. Y0 + 96 loop
               Back := Back and then Off (X, Y, Level) = 0;
            end loop;
         end loop;
         for X in Bank .. Bank + 7 loop
            for Y in Y0 .. Y0 + 3 loop
               On_Top := On_Top or else Castle.Water.Depth_At (X, Y, Level + 8) > 0;
            end loop;
         end loop;
         Check (Back, "the lake is back at its level, to the unit");
         Check (not On_Top, "nothing stands on what closed the cut");
         Check (Castle.Water.Awake_Count = 0, "and everything sleeps (after" & Ticks'Image & " ticks)");
         declare
            Dried_0 : constant Long_Long_Integer := Castle.Water.Dried;
            Left    : constant Long_Long_Integer := Castle.Water.Total;
            Lake_0  : constant Integer := Off (Bank - 1, Y0 + 1, Level);
         begin
            Castle.Water.Dry_Out (Hours => 10.0, Evaporation_Mm => 2.0, Seep_Scale => 1.0);
            Check ((for all CX in 0 .. 9 => (for all CY in 0 .. 9 => not Castle.Water.Is_Running (CX, CY))),
                   "none of it kept as running water");
            Check (Castle.Water.Dried > Dried_0 and then Castle.Water.Total < Left
                   and then Off (Bank - 1, Y0 + 1, Level) = Lake_0,
                   "what is left out dries, the lake does not");
         end;
      end;

      --  8e. Built in: a pier raised through the lake is not source water,
      --  and nothing comes onto it; taken out again, the lake comes back.
      Put_Line ("source water, built in and dug out:");
      Lake;
      for X in 68 .. 75 loop
         for Y in 168 .. 175 loop
            Fl (X, Y) := Level + 4;
            Castle.Water.Ground_Changed (X, Y);
         end loop;
      end loop;
      Run (300);
      declare
         Dry, Back : Boolean := True;
      begin
         for X in 68 .. 75 loop
            for Y in 168 .. 175 loop
               Dry := Dry and then Castle.Water.Depth_At (X, Y, Level + 4) = 0
                 and then Castle.Water.Rest_Level (X, Y) = 0;
            end loop;
         end loop;
         Check (Dry, "the pier stands dry, and is source water no longer");
         Check (Off (67, 170, Level) = 0 and then Off (80, 180, Level) = 0, "the lake round it lies at its level");
         for X in 68 .. 75 loop
            for Y in 168 .. 175 loop
               Fl (X, Y) := Level - 12;
               Castle.Water.Ground_Changed (X, Y);
            end loop;
         end loop;
         Check (Castle.Water.Depth_At (70, 170, Level - 12) = 0, "taken out, its place is empty at first");
         Run (600);
         for X in 68 .. 75 loop
            for Y in 168 .. 175 loop
               Back := Back and then Off (X, Y, Level) = 0;
            end loop;
         end loop;
         Check (Back and then Castle.Water.Awake_Count = 0, "and the lake fills it to its level again, and sleeps");
      end;

      --  8f. A stream on a hill, three blocks deep and twelve columns wide,
      --  its bed falling a block every eight columns, cut into at its bank.
      --  The water beside the cut drops; nowhere does the stream stand over
      --  its level: the water higher up does not come down on the water
      --  below.
      Put_Line ("source water, a stream on a hill:");
      Castle.Water.Reset;
      for X in 0 .. M - 1 loop
         for Y in 0 .. M - 1 loop
            Wa (X, Y) := 0;
            Rs (X, Y) := 0;
            if X in Bank - 12 .. Bank - 1 then
               Fl (X, Y) := 200 - Y / 8;
               Wa (X, Y) := 3;
               Rs (X, Y) := 203 - Y / 8;
            elsif X < Bank + 8 then
               Fl (X, Y) := 200 - Y / 8 + 6;                           --  its banks, and the hill west of it
            else
               Fl (X, Y) := 200 - Y / 8 - 2 - (X - Bank - 8) / 2;      --  lower ground east of the bank
            end if;
         end loop;
      end loop;
      Castle.Water.Set_Recharge (Stream_Refill'Unrestricted_Access);
      Cut (200 - Y0 / 8);                        --  down to the bed
      Run (600);
      declare
         Over, Under : Integer := 0;
         Wet_Above   : Boolean := False;
      begin
         for X in Bank - 12 .. Bank - 1 loop
            for Y in 0 .. M - 1 loop
               if Castle.Water.Depth_At (X, Y, Fl (X, Y)) >= 0 then
                  Over := Integer'Max (Over, Off (X, Y, 203 - Y / 8));
                  Under := Integer'Min (Under, Off (X, Y, 203 - Y / 8));
               end if;
            end loop;
         end loop;
         for X in Bank - 20 .. Bank + 7 loop
            for Y in 0 .. M - 1 loop
               if not (X in Bank - 12 .. Bank - 1) and then not (Y in Y0 .. Y0 + 3)
                 and then Castle.Water.Depth (X, Y) > 0
               then
                  Wet_Above := True;
               end if;
            end loop;
         end loop;
         Check (Off (Bank - 1, Y0 + 1, 203 - (Y0 + 1) / 8) < -U / 8, "the water beside the cut has dropped: "
                & Img (Float (-Off (Bank - 1, Y0 + 1, 203 - (Y0 + 1) / 8)) / Float (U), 2) & " blocks");
         Check (Over <= U / 64, "nowhere does the stream stand over its level (most: "
                & Img (Float (Over) / Float (U), 3) & " blocks; the deepest drop " & Img (Float (-Under) / Float (U), 2) & ")");
         Check (not Wet_Above, "and none of it is over its banks");
         Check (Off (Bank - 6, Y0 - 80, 203 - (Y0 - 80) / 8) >= -U / 16
                and then Off (Bank - 6, Y0 + 80, 203 - (Y0 + 80) / 8) >= -U / 16,
                "20 m up the hill and 20 m down it lies at its level");
         Check (Castle.Water.Awake_Count <= 24, "few stacks are awake for it:" & Castle.Water.Awake_Count'Image);
      end;
      --  8g. A flow that runs on without changing sleeps.  A stream cut
      --  into at its bank, the land beyond level with its bed: the water
      --  spreads over it and soaks away as fast as it comes.  Once that has
      --  stood the same for ten seconds everything sleeps as it lies, still
      --  running water: nothing dries off it.  The cut closed, it wakes, the
      --  stream comes back to its level, what is out goes, and it sleeps
      --  for good.
      Put_Line ("a flow established:");
      Castle.Water.Reset;
      for X in 0 .. M - 1 loop
         for Y in 0 .. M - 1 loop
            Wa (X, Y) := 0;
            Rs (X, Y) := 0;
            Fl (X, Y) := 100;
            if X < Bank then
               Wa (X, Y) := 3;
               Rs (X, Y) := 103;
            elsif X < Bank + 8 then
               Fl (X, Y) := 120;
            end if;
         end loop;
      end loop;
      for X in Bank .. Bank + 7 loop
         for Y in Y0 .. Y0 + 1 loop
            Fl (X, Y) := 100;
            Castle.Water.Ground_Changed (X, Y);
         end loop;
      end loop;
      declare
         pragma Warnings (Off, "formal parameter * is not referenced");   --  the same everywhere
         function Rock (Bx, By, Row : Integer) return Float is (0.0);
         pragma Warnings (On, "formal parameter * is not referenced");
         function Wet return Natural is
            C : Natural := 0;
         begin
            for X in Bank + 8 .. M - 1 loop
               for Y in 0 .. M - 1 loop
                  if Castle.Water.Depth (X, Y) > 0 then
                     C := C + 1;
                  end if;
               end loop;
            end loop;
            return C;
         end Wet;
         Ticks   : Natural := 0;
         In_0    : Long_Long_Integer;
         Wet_0   : Natural;
         Running : Natural := 0;
         Awake_S : Natural := 0;
         procedure Count (CX, CY : Integer; Awake : Boolean; C : Castle.Water.Stack_Columns) is
            pragma Unreferenced (C);
         begin
            if Castle.Water.Is_Running (CX, CY) then
               Running := Running + 1;
               if Awake then
                  Awake_S := Awake_S + 1;
               end if;
            end if;
         end Count;
      begin
         loop
            Castle.Water.Tick;
            Ticks := Ticks + 1;
            exit when Ticks >= 50 and then Castle.Water.Awake_Count = 0;
            exit when Ticks >= 3_000;
         end loop;
         In_0 := Castle.Water.Came_In;
         Wet_0 := Wet;
         Castle.Water.Each_Stack (Count'Access);
         Check (Castle.Water.Awake_Count = 0, "the flow established, everything sleeps (after" & Ticks'Image & " ticks)");
         Check (Running > 0 and then Castle.Water.Is_Running (Bank / 32, Y0 / 32),
                "as running water:" & Running'Image & " stacks, the cut's among them");
         Check (Wet_0 > 100 and then Off (Bank - 1, Y0, 103) < -U / 8,
                "as it lay:" & Wet_0'Image & " columns wet beyond the bank, the stream "
                & Img (Float (-Off (Bank - 1, Y0, 103)) / Float (U), 2) & " blocks down at the cut");
         Run (100);
         Castle.Water.Set_Seep (Rock'Unrestricted_Access);
         Castle.Water.Dry_Out (Hours => 100.0, Evaporation_Mm => 2.0, Seep_Scale => 1.0);
         Check (Castle.Water.Came_In = In_0 and then Wet = Wet_0,
                "asleep nothing comes in, and a hundred dry hours take nothing off it (it is fed)");
         Check (Awake_S = Running, "a save has running water as awake (it finds its flows again)");
         for X in Bank .. Bank + 7 loop
            for Y in Y0 .. Y0 + 1 loop
               Fl (X, Y) := 120;                 --  the cut closed
               Castle.Water.Ground_Changed (X, Y);
            end loop;
         end loop;
         Ticks := 0;
         loop
            Castle.Water.Tick;
            Ticks := Ticks + 1;
            exit when Ticks >= 50 and then Castle.Water.Awake_Count = 0;
            exit when Ticks >= 6_000;
         end loop;
         Running := 0;
         Castle.Water.Each_Stack (Count'Access);
         Check (Castle.Water.Awake_Count = 0 and then Running = 0,
                "the cut closed, it all woke, ran out and sleeps for good (after" & Ticks'Image & " ticks)");
         Check (Off (Bank - 1, Y0, 103) = 0 and then Off (Bank - 6, Y0 + 20, 103) = 0,
                "the stream back at its level");
         Castle.Water.Dry_Out (Hours => 100.0, Evaporation_Mm => 2.0, Seep_Scale => 1.0);
         Check (Wet = 0, "and what was left out dries (" & Wet'Image & " columns wet after a hundred dry hours)");
         Castle.Water.Set_Seep (null);
      end;
      Castle.Water.Set_Recharge (null);
      Castle.Water.Set_Supply (null);
      Castle.Water.Set_Leak (False);
      Castle.Water.Set_Ground (Ground'Unrestricted_Access);
   end;

   if Fails = 0 then
      Put_Line ("all checks passed");
   else
      Put_Line (Img (Fails) & " checks FAILED");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Water_Sim_Check;
