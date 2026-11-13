with Ada.Containers.Ordered_Maps;
with Ada.Unchecked_Deallocation;
with Castle.Dims; use Castle.Dims;

package body Castle.Falls is

   use type Castle.Water.Ground_Source;

   Side : constant := Chunk_B;
   Block_M : constant := 0.25;

   DX : constant array (0 .. 3) of Integer := [1, -1, 0, 0];      --  east, west, north, south, as the water's
   DY : constant array (0 .. 3) of Integer := [0, 0, 1, -1];

   Ground    : Castle.Water.Ground_Source;
   On        : Boolean := True;
   Throw_Now : Float := Throw;
   Tick_N    : Natural := 0;
   Count     : Natural := 0;

   --  What leaves a face, settled over the ticks: the flow (m/s times
   --  blocks over the sill) and the water over the sill (blocks).
   type Launch is record
      Q, D : Float := 0.0;
   end record;
   type Launch_Grid is array (0 .. Side - 1, 0 .. Side - 1, 0 .. 3) of Launch;

   type Cell is record
      Top, Bottom : Float := 0.0;              --  blocks; Top 0: no sheet
   end record;
   type Cell_Grid is array (0 .. Side - 1, 0 .. Side - 1) of Cell;

   type Stack is record
      CX, CY   : Integer := 0;
      L        : Launch_Grid;
      Thrown   : Boolean := False;             --  any launch in L
      Seen     : Natural := 0;                 --  the tick its flows were last read
      A, Was   : Cell_Grid;
      Has_Air  : Boolean := False;
      Changed  : Boolean := False;
      --  its ground and water, as read this tick (for what lies under a sheet)
      Read_At  : Natural := 0;
      Sim      : Boolean := False;
      Surf     : Castle.Water.Surface_Grid;
   end record;
   type Stack_Access is access Stack;
   procedure Free is new Ada.Unchecked_Deallocation (Stack, Stack_Access);

   package Stack_Maps is new Ada.Containers.Ordered_Maps (Integer, Stack_Access);
   Stacks : Stack_Maps.Map;

   function Key (CX, CY : Integer) return Integer is (CX * 4096 + CY);

   function Find (CX, CY : Integer) return Stack_Access is
      C : constant Stack_Maps.Cursor := Stacks.Find (Key (CX, CY));
   begin
      return (if Stack_Maps.Has_Element (C) then Stack_Maps.Element (C) else null);
   end Find;

   function Get (CX, CY : Integer) return Stack_Access is
      S : Stack_Access := Find (CX, CY);
   begin
      if S = null then
         S := new Stack;
         S.CX := CX;
         S.CY := CY;
         Stacks.Insert (Key (CX, CY), S);
      end if;
      return S;
   end Get;

   procedure Set_Ground (Source : Castle.Water.Ground_Source) is
   begin
      Ground := Source;
   end Set_Ground;

   procedure Set_On (On : Boolean) is
   begin
      Castle.Falls.On := On;
   end Set_On;

   procedure Set_Throw (Share : Float) is
   begin
      Throw_Now := Share;
   end Set_Throw;

   function In_World (Bx, By : Integer) return Boolean is
     (Bx in 0 .. Size_B - 1 and then By in 0 .. Size_B - 1);

   --  A stack's ground and water as they stand this tick.
   procedure Read (S : in out Stack) is
   begin
      if S.Read_At /= Tick_N then
         S.Read_At := Tick_N;
         Castle.Water.Surface (S.CX, S.CY, S.Surf, S.Sim);
      end if;
   end Read;

   --  The top of what is in a column, water or ground (blocks); the top of
   --  the world where nothing is known of it, so that nothing flies there.
   function Under (Bx, By : Integer) return Float is
   begin
      if not In_World (Bx, By) then
         return Float (Height_B);
      end if;
      declare
         S : constant Stack_Access := Get (Bx / Side, By / Side);
      begin
         Read (S.all);
         if S.Sim then
            return Float'Min (Float (Height_B), Float'Max (S.Surf (Bx mod Side, By mod Side).Level,
                                                           S.Surf (Bx mod Side, By mod Side).Floor));
         elsif Ground /= null then
            declare
               C     : Castle.Water.Column;
               Known : Boolean;
            begin
               Ground (Bx, By, C, Known);
               if Known and then C.N >= 1 then
                  return Float (C.S (1).Floor + C.S (1).Water);
               end if;
            end;
         end if;
         return Float (Height_B);
      end;
   end Under;

   --  The sheet thrown from column (Bx, By) through face D at U m/s, the
   --  water standing Over blocks over the sill, its top at Z0 as it leaves:
   --  every column it passes over, until it meets what is there.  Over a
   --  column the sheet is a slab from where it comes in, at the near edge,
   --  down to where it goes out at the far one (and no thinner than it is
   --  thick), so the slabs of an arch meet edge to edge.
   procedure Fly (Bx, By, D : Integer; U, Over, Z0 : Float) is
      Thick : constant Float := Float'Min (Sheet_Most, Float'Max (Sheet_Least, Sheet_Over * Over));
      function Drop (Metres : Float) return Float is (0.5 * Gravity * (Metres / U) ** 2 / Block_M);
   begin
      for K in 1 .. Reach_Most loop
         declare
            X   : constant Integer := Bx + K * DX (D);
            Y   : constant Integer := By + K * DY (D);
            Top : constant Float := Z0 - Drop (Float (K - 1) * Block_M);
            Out_At : constant Float := Z0 - Drop (Float (K) * Block_M);
            Low : constant Float := Under (X, Y);
            Bot : Float := Float'Min (Top - Thick, Out_At);
         begin
            exit when K = 1 and then Z0 - Low < Clear_Least;   --  nothing to fall into: it runs on as it was
            exit when Top <= Low + 0.1;                        --  it has come down
            if Bot - Low < Join then
               Bot := Low;
            end if;
            declare
               S : constant Stack_Access := Get (X / Side, Y / Side);
               C : Cell renames S.A (X mod Side, Y mod Side);
            begin
               if C.Top = 0.0 then
                  C := (Top, Bot);
               else
                  C := (Float'Max (C.Top, Top), Float'Min (C.Bottom, Bot));
               end if;
               S.Has_Air := True;
            end;
            exit when Out_At <= Low;                           --  ... within this column
         end;
      end loop;
   end Fly;

   function Packed (C : Cell) return Float is
   begin
      if C.Top <= 0.0 then
         return 0.0;
      end if;
      declare
         T : constant Integer := Integer (C.Top * 16.0);
         B : constant Integer := Integer'Max (1, Integer'Min (1023, Integer ((C.Top - C.Bottom) * 16.0)));
      begin
         return Float (T * 1024 + B);
      end;
   end Packed;

   procedure Follow is
      Awake   : constant Castle.Water.Stack_List := Castle.Water.Awake_List;
      Stirred : Boolean := Awake'Length > 0;
   begin
      Tick_N := Tick_N + 1;

      --  1. What leaves each face, settled over the ticks.
      if On then
         for R of Awake loop
            declare
               S    : constant Stack_Access := Get (R.CX, R.CY);
               O    : Castle.Water.Outflow_Grid;
               Have : Boolean;
            begin
               Castle.Water.Outflows (R.CX, R.CY, O, Have);
               if Have then
                  S.Seen := Tick_N;
                  S.Thrown := False;
                  for X in 0 .. Side - 1 loop
                     for Y in 0 .. Side - 1 loop
                        for D in 0 .. 3 loop
                           declare
                              L : Launch renames S.L (X, Y, D);
                              F : constant Castle.Water.Outflow := O (X, Y) (D);
                           begin
                              if F.Speed > 0.0 or else L.Q > 0.0 then
                                 L.Q := L.Q + Settle * (F.Speed * F.Over - L.Q);
                                 L.D := L.D + Settle * (F.Over - L.D);
                                 if L.Q < 0.005 then
                                    L := (0.0, 0.0);
                                 else
                                    S.Thrown := True;
                                 end if;
                              end if;
                           end;
                        end loop;
                     end loop;
                  end loop;
               end if;
            end;
         end loop;
      end if;
      --  A stack asleep with its flow established keeps what it throws; one
      --  that has come to rest throws nothing.
      for S of Stacks loop
         if S.Thrown and then S.Seen /= Tick_N
           and then (not On or else not Castle.Water.Is_Running (S.CX, S.CY))
         then
            S.L := [others => [others => [others => <>]]];
            S.Thrown := False;
            Stirred := True;
         end if;
      end loop;
      if not Stirred then
         return;                                --  nothing awake and nothing stopped: the sheets stand as they were
      end if;

      --  2. The sheets, from every lip.
      for S of Stacks loop
         S.Was := S.A;
         if S.Has_Air then
            S.A := [others => [others => <>]];
            S.Has_Air := False;
         end if;
      end loop;
      declare
         --  (flying makes new stacks in the map: go by a list of those that throw)
         type Access_List is array (Positive range <>) of Stack_Access;
         Throwing : Access_List (1 .. Natural (Stacks.Length));
         N        : Natural := 0;
      begin
         for S of Stacks loop
            if S.Thrown then
               N := N + 1;
               Throwing (N) := S;
            end if;
         end loop;
         for S of Throwing (1 .. N) loop
            Read (S.all);
            if S.Sim then
               for X in 0 .. Side - 1 loop
                  for Y in 0 .. Side - 1 loop
                     for D in 0 .. 3 loop
                        declare
                           L : constant Launch := S.L (X, Y, D);
                        begin
                           if L.D >= Over_Least then
                              Fly (S.CX * Side + X, S.CY * Side + Y, D,
                                   Float'Max (Throw_Least, Float'Min (Throw_Most, Throw_Now * L.Q / L.D)),
                                   L.D, S.Surf (X, Y).Level);
                           end if;
                        end;
                     end loop;
                  end loop;
               end loop;
            end if;
         end loop;
      end;

      --  3. Which stacks' sheets changed; and the stacks with nothing left.
      Count := 0;
      declare
         Gone : Stack_Maps.Map;
      begin
         for S of Stacks loop
            for X in 0 .. Side - 1 loop
               for Y in 0 .. Side - 1 loop
                  if Packed (S.A (X, Y)) /= Packed (S.Was (X, Y)) then
                     S.Changed := True;
                  end if;
                  if S.A (X, Y).Top > 0.0 then
                     Count := Count + 1;
                  end if;
               end loop;
            end loop;
            --  (one only looked at, for what lies under a sheet, is kept a
            --  few seconds: it will be looked at again next tick)
            if not S.Thrown and then not S.Has_Air and then not S.Changed and then S.Read_At + 50 < Tick_N then
               Gone.Insert (Key (S.CX, S.CY), S);
            end if;
         end loop;
         for S of Gone loop
            declare
               P : Stack_Access := S;
            begin
               Stacks.Delete (Key (P.CX, P.CY));
               Free (P);
            end;
         end loop;
      end;
   end Follow;

   function Air (Bx, By : Integer) return Float is
   begin
      if not In_World (Bx, By) then
         return 0.0;
      end if;
      declare
         S : constant Stack_Access := Find (Bx / Side, By / Side);
      begin
         return (if S = null or else not S.Has_Air then 0.0 else Packed (S.A (Bx mod Side, By mod Side)));
      end;
   end Air;

   function Air_Top (Bx, By : Integer) return Float is
      S : constant Stack_Access := (if In_World (Bx, By) then Find (Bx / Side, By / Side) else null);
   begin
      return (if S = null then 0.0 else S.A (Bx mod Side, By mod Side).Top);
   end Air_Top;

   function Air_Bottom (Bx, By : Integer) return Float is
      S : constant Stack_Access := (if In_World (Bx, By) then Find (Bx / Side, By / Side) else null);
   begin
      return (if S = null then 0.0 else S.A (Bx mod Side, By mod Side).Bottom);
   end Air_Bottom;

   function Over (CX, CY : Integer) return Boolean is
      S : constant Stack_Access := Find (CX, CY);
   begin
      return S /= null and then S.Has_Air;
   end Over;

   function Take_Changed return Castle.Water.Stack_List is
      L : Castle.Water.Stack_List (1 .. Natural (Stacks.Length));
      N : Natural := 0;
   begin
      for S of Stacks loop
         if S.Changed then
            S.Changed := False;
            N := N + 1;
            L (N) := (S.CX, S.CY);
         end if;
      end loop;
      return L (1 .. N);
   end Take_Changed;

   function Sheets return Natural is (Count);

   procedure Reset is
   begin
      for S of Stacks loop
         declare
            P : Stack_Access := S;
         begin
            Free (P);
         end;
      end loop;
      Stacks.Clear;
      Count := 0;
   end Reset;

end Castle.Falls;
