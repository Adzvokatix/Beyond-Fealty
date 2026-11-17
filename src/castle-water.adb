with Ada.Containers.Ordered_Sets;
with Ada.Unchecked_Conversion;
with Ada.Unchecked_Deallocation;
with Castle.Blocks; use Castle.Blocks;

package body Castle.Water is

   Side     : constant := Chunk_B;           --  columns to a stack side
   Grid     : constant := Chunks_XY;         --  stacks to a world side
   Max_Open : constant := 4;                 --  openings through one face

   type Dir is range 0 .. 3;                 --  east, west, north, south
   DX  : constant array (Dir) of Integer := (1, -1, 0, 0);
   DY  : constant array (Dir) of Integer := (0, 0, 1, -1);
   Opp : constant array (Dir) of Dir := (1, 0, 3, 2);

   --  Flow, worked out Substeps times a tick.  A pipe's flow gains the head
   --  across it times g h dt^2 / l^2, h being the water over the pipe's sill
   --  (two thirds of gravity's), and keeps what friction leaves of it, so
   --  water runs fast where it falls and a breach fills a pit in seconds.
   --  Friction takes a share each step, larger the shallower the water, and
   --  a share at any depth that damps waves out: 5 % a step in water 1 m
   --  deep, which damps a pond 10 m across critically and anything wider
   --  more, so it settles without sloshing, and ripples die within a second.
   --  (At 0.7 % a pond rang for seconds, a few mm high, which shows now that
   --  water is drawn at fractional height.  Without momentum at all a
   --  basin took minutes to level.  Damping this hard would stop a river
   --  carrying its discharge, but rivers and lakes are locked sources.)
   Substeps    : constant := 4;
   G_Den       : constant := 4_012_408;
   H_Cap       : constant := 8 * Unit;
   Friction    : constant := Unit / 70;
   Still_Share : constant := 65_536 / 20;    --  of the flow each step, in water 1 m deep or more
   Quiet_Flow  : constant := Unit / 4_096;   --  a step (0.06 mm): nothing is creeping either
   --  (thicker water creeps slowly while it levels; at 1/128 of a block a
   --  heap of it fell asleep a block high)
   Sleep_Ticks : constant := 50;             --  5 s of that and the stack sleeps
   Steady_Ticks : constant Integer := Integer (Steady_Seconds / Tick_Seconds);

   --  Flows are kept in sixteenths of a unit, and only whole units of water
   --  move.  (With whole units, a head under about 1/500 of a block gained
   --  no flow at all in shallow water, and across a basin those invisible
   --  steps added up to a slope of a fifth of a block that never levelled.)
   Fine : constant := 16;

   function Gain (Head, Over_Sill : Integer) return Integer is
     (Integer (Long_Long_Integer (Head) * Long_Long_Integer (Integer'Min (Over_Sill, H_Cap)) * Fine / G_Den));

   function Moved (F : Integer) return Integer is (F / Fine);   --  whole units this step

   --  Friction's share, Friction / (h + Unit), in 1/65,536ths, for h in
   --  eighths of a block up to H_Cap: a multiply and a shift a step instead
   --  of a 64-bit division by h.  The damping share grows with depth, full
   --  from 1 m down.  Integers throughout, the same on every machine.
   Steps_Per_Block : constant := 8;
   type Share_Table is array (0 .. 8 * Steps_Per_Block) of Long_Long_Integer;
   function Shares return Share_Table is
      T : Share_Table;
   begin
      for I in T'Range loop
         T (I) := Long_Long_Integer (Friction) * 65_536
           / Long_Long_Integer (I * (Unit / Steps_Per_Block) + Unit)
           + Long_Long_Integer (Still_Share) * Long_Long_Integer (Integer'Min (I, 4 * Steps_Per_Block))
             / Long_Long_Integer (4 * Steps_Per_Block);
      end loop;
      return T;
   end Shares;
   Share : constant Share_Table := Shares;

   --  The friction share is rounded up, so every flow loses at least a unit
   --  a step and dies away in the end.
   function Kept (F, Over_Sill : Integer) return Integer is
      S : constant Long_Long_Integer :=
        Share (Integer'Min (Share_Table'Last, Over_Sill / (Unit / Steps_Per_Block)));
   begin
      if F > 0 then
         return F - Integer ((Long_Long_Integer (F) * S + 65_535) / 65_536);
      elsif F < 0 then
         return F + Integer ((Long_Long_Integer (-F) * S + 65_535) / 65_536);
      else
         return 0;
      end if;
   end Kept;

   function Cap (S : Stretch) return Integer is ((S.Ceil - S.Floor) * Unit) with Inline;
   function Surf (S : Stretch) return Integer is (Integer'Min (S.Floor * Unit + S.Water, S.Ceil * Unit)) with Inline;

   type Flux is array (0 .. Side - 1, 0 .. Side - 1, Dir, 1 .. Max_Open) of Integer;
   type Shown_Blocks is array (0 .. Side - 1, 0 .. Side - 1, 1 .. Max_Stretch) of Integer;

   type Sim_Stack is record
      C     : Stack_Columns;                                  --  Water in units
      F     : Flux := (others => (others => (others => (others => 0))));   --  out through each opening
      Shown : Shown_Blocks := (others => (others => (others => 0)));      --  water blocks drawn
      Awake : Boolean := False;
      Quiet : Natural := 0;
      --  running on without changing (see the spec): the depths the count
      --  started from, their sum, the ticks since, and whether it sleeps so
      Ref     : Shown_Blocks := (others => (others => (others => 0)));
      Ref_Sum : Long_Long_Integer := 0;
      Steady  : Natural := 0;
      Running : Boolean := False;
   end record;
   type Sim_Access is access Sim_Stack;
   procedure Free_Sim is new Ada.Unchecked_Deallocation (Sim_Stack, Sim_Access);

   type Sim_Grid is array (0 .. Grid - 1, 0 .. Grid - 1) of Sim_Access;
   type Sim_Grid_Access is access Sim_Grid;
   Sims : constant Sim_Grid_Access := new Sim_Grid;

   type Count_Grid is array (0 .. Grid - 1, 0 .. Grid - 1) of Natural;
   type Count_Access is access Count_Grid;
   Vers     : constant Count_Access := new Count_Grid'(others => (others => 0));
   Activity : constant Count_Access := new Count_Grid'(others => (others => 0));   --  largest move this tick

   package Key_Sets is new Ada.Containers.Ordered_Sets (Natural);
   Awake_Set, Changed_Set, Wake_Set : Key_Sets.Set;
   Simulated : Natural := 0;

   Ground  : Ground_Source := null;
   Was_Capped : Boolean := False;
   In_Sum  : Long_Long_Integer := 0;

   --  Source water and drying (see the spec).
   Supply   : Supply_Source;
   Recharge : Supply_Source;
   Seep     : Seep_Source;
   Refill_Steps : constant Integer := Integer (Refill_Seconds * Substeps / Tick_Seconds);
   Dried_Sum    : Long_Long_Integer := 0;
   Dried_Set    : Key_Sets.Set;
   Leak_On      : Boolean := False;
   Leak_Den     : constant := 256;             --  a column keeps 1/256 of what it passes on
   Sheet_Depth  : constant := Unit / 4;        --  under 1/16 m, on the move: a sheet
   Sheet_Loss   : constant := 64;              --  units a step it soaks away (about 1 cm a second)

   Out_Sum : Long_Long_Integer := 0;

   --  What has come in from source water in all, tick by tick over the
   --  last Steady_Seconds: water that only settles (a pond levelling) has
   --  had none and is left to the quiet rule; an established flow is one
   --  that is fed.  (What runs off does not count: the leak takes from a
   --  levelling pond too.)
   type Through_Ring is array (0 .. Steady_Ticks) of Long_Long_Integer;
   Through    : Through_Ring := (others => 0);
   Through_At : Natural := 0;

   function Key (CX, CY : Integer) return Natural is (CX * Grid + CY);
   function In_World (Bx, By : Integer) return Boolean is
     (Bx in 0 .. Size_B - 1 and then By in 0 .. Size_B - 1);

   procedure Set_Ground (Source : Ground_Source) is
   begin
      Ground := Source;
   end Set_Ground;

   --  Which stretch of a column holds its source water: the one its
   --  resting level lies in.  0: none (not source water, or its place has
   --  been built over or filled in to its level, and then it is ground
   --  like any other for as long as that stands).
   function Src (C : Column) return Natural with Inline;
   function Src (C : Column) return Natural is
   begin
      if C.Flowing then
         for I in 1 .. C.N loop
            if C.S (I).Floor * Unit < C.Rest and then C.Rest <= C.S (I).Ceil * Unit then
               return I;
            end if;
         end loop;
      end if;
      return 0;
   end Src;

   --  A ground column's resting level: what the ground says, else what
   --  the simulation had (Before), else where its water lies now.
   function Rest_Units (G : Column; Before : Integer := 0) return Integer is
     (if not G.Flowing then 0
      elsif G.Rest > 0 then G.Rest
      elsif Before > 0 then Before
      elsif G.N >= 1 and then G.S (1).Water > 0 then (G.S (1).Floor + G.S (1).Water) * Unit
      else 0);

   --  The ground's column as the simulation holds it: water in units, and
   --  source water at its level, whatever an edit left of its blocks (it
   --  is asleep, and asleep it holds its level).
   procedure Ground_Units (Bx, By : Integer; C : out Column; Known : out Boolean) is
   begin
      Ground (Bx, By, C, Known);
      if Known then
         C.Rest := Rest_Units (C);
         for I in 1 .. C.N loop
            C.S (I).Water := C.S (I).Water * Unit;
         end loop;
         declare
            I : constant Natural := Src (C);
         begin
            if I > 0 then
               C.S (I).Water := C.Rest - C.S (I).Floor * Unit;
            end if;
         end;
      end if;
   end Ground_Units;

   --  Openings between two columns: every pair of their stretches that
   --  share open rows, lowest first (at most Max_Open).  Both columns list
   --  the same openings in the same order, so a flow and its return meet.
   type Opening is record
      A, B   : Positive := 1;                  --  the stretch on this side, on the other
      Lo, Hi : Integer  := 0;                  --  the open rows they share
   end record;
   type Opening_Array is array (1 .. Max_Open) of Opening;

   procedure Open (A, B : Column; O : out Opening_Array; N : out Natural) with Inline;
   procedure Open (A, B : Column; O : out Opening_Array; N : out Natural) is
   begin
      N := 0;
      if A.N = 1 and then B.N = 1 then
         --  nearly every face: one stretch on each side
         declare
            Lo : constant Integer := Integer'Max (A.S (1).Floor, B.S (1).Floor);
            Hi : constant Integer := Integer'Min (A.S (1).Ceil, B.S (1).Ceil);
         begin
            if Hi > Lo then
               N := 1;
               O (1) := (1, 1, Lo, Hi);
            end if;
         end;
         return;
      end if;
      for I in 1 .. A.N loop
         for J in 1 .. B.N loop
            declare
               Lo : constant Integer := Integer'Max (A.S (I).Floor, B.S (J).Floor);
               Hi : constant Integer := Integer'Min (A.S (I).Ceil, B.S (J).Ceil);
            begin
               if Hi > Lo and then (N < Max_Open or else Lo < O (N).Lo) then
                  declare
                     P : Positive := (if N < Max_Open then N + 1 else N);
                  begin
                     N := Integer'Min (Max_Open, N + 1);
                     while P > 1 and then O (P - 1).Lo > Lo loop
                        O (P) := O (P - 1);
                        P := P - 1;
                     end loop;
                     O (P) := (I, J, Lo, Hi);
                  end;
               end if;
            end;
         end loop;
      end loop;
   end Open;

   procedure Wake (CX, CY : Integer) is
   begin
      if CX not in 0 .. Grid - 1 or else CY not in 0 .. Grid - 1 or else Ground = null then
         return;
      end if;
      if not Awake_Set.Contains (Key (CX, CY)) and then Natural (Awake_Set.Length) >= Max_Awake then
         Was_Capped := True;                  --  enough is moving: this stays as it lies
         return;
      end if;
      if Sims (CX, CY) = null then
         declare
            C     : Column;
            Known : Boolean;
         begin
            Ground (CX * Side, CY * Side, C, Known);
            if not Known then
               return;
            end if;
         end;
         Sims (CX, CY) := new Sim_Stack;
         Simulated := Simulated + 1;
         --  remeshed once: its surface cells now cover every column
         Vers (CX, CY) := Vers (CX, CY) + 1;
         Changed_Set.Include (Key (CX, CY));
         for X in 0 .. Side - 1 loop
            for Y in 0 .. Side - 1 loop
               declare
                  Known : Boolean;
               begin
                  Ground_Units (CX * Side + X, CY * Side + Y, Sims (CX, CY).C (X, Y), Known);
                  for I in 1 .. Sims (CX, CY).C (X, Y).N loop
                     Sims (CX, CY).Shown (X, Y, I) := Sims (CX, CY).C (X, Y).S (I).Water / Unit;
                  end loop;
               end;
            end loop;
         end loop;
      end if;
      Sims (CX, CY).Awake := True;
      Sims (CX, CY).Quiet := 0;
      Sims (CX, CY).Steady := 0;
      Sims (CX, CY).Running := False;
      Awake_Set.Include (Key (CX, CY));
   end Wake;

   procedure About_To_Change (Bx, By : Integer) is
   begin
      if In_World (Bx, By) then
         for I in -1 .. 1 loop
            for J in -1 .. 1 loop
               Wake (Bx / Side + I, By / Side + J);
            end loop;
         end loop;
      end if;
   end About_To_Change;

   procedure Ground_Changed (Bx, By : Integer) is
      CX : constant Integer := Bx / Side;
      CY : constant Integer := By / Side;
      Had : Boolean;
   begin
      if not In_World (Bx, By) then
         return;
      end if;
      Had := Sims (CX, CY) /= null;
      if Sims (CX, CY) /= null then
         declare
            S     : Sim_Stack renames Sims (CX, CY).all;
            X     : constant Integer := Bx mod Side;
            Y     : constant Integer := By mod Side;
            Old   : constant Column := S.C (X, Y);
            New_C : Column;
            Known : Boolean;
         begin
            Ground (Bx, By, New_C, Known);
            if Known then
               New_C.Rest := Rest_Units (New_C, Before => Old.Rest);
               --  dug or built in: its open rows are not what they were
               --  (a plant cut or a block changed for another leaves it
               --  as it was made)
               New_C.Touched := Old.Touched or else New_C.N /= Old.N
                 or else (for some I in 1 .. New_C.N =>
                            New_C.S (I).Floor /= Old.S (I).Floor or else New_C.S (I).Ceil /= Old.S (I).Ceil);
               for I in 1 .. New_C.N loop
                  New_C.S (I).Water := 0;
               end loop;
               --  Water stays in the rows it lay in, where they are still
               --  open, and settles on the floor of the stretch they are
               --  now part of: dug out below, it falls in.  Water in rows
               --  that are now solid is gone: a block placed in water takes
               --  its place.  (It used to be lifted into the stretch above,
               --  so water climbed onto whatever was built in it, a column
               --  as tall as the water had been deep.)
               for I in 1 .. Old.N loop
                  if Old.S (I).Water > 0 then
                     declare
                        Bottom : constant Integer := Old.S (I).Floor * Unit;
                        Top    : constant Integer := Bottom + Integer'Min (Old.S (I).Water, Cap (Old.S (I)));
                        Left   : Integer := Old.S (I).Water;
                     begin
                        for J in 1 .. New_C.N loop
                           declare
                              Lo : constant Integer := Integer'Max (Bottom, New_C.S (J).Floor * Unit);
                              Hi : constant Integer := Integer'Min (Top, New_C.S (J).Ceil * Unit);
                           begin
                              if Hi > Lo then
                                 New_C.S (J).Water := New_C.S (J).Water + (Hi - Lo);
                                 Left := Left - (Hi - Lo);
                              end if;
                           end;
                        end loop;
                        Out_Sum := Out_Sum + Long_Long_Integer (Left);   --  where the blocks went in
                     end;
                  end if;
               end loop;
               --  (Source water is not put back at its level here: a bed dug
               --  deeper leaves a dip that fills again as any drop in it
               --  does, and where its place is filled in to its level it
               --  is source water no longer.)
               S.C (X, Y) := New_C;
               --  the openings through its faces have changed: their flows start again
               for D in Dir loop
                  for Q in 1 .. Max_Open loop
                     S.F (X, Y, D, Q) := 0;
                  end loop;
                  declare
                     Nx : constant Integer := Bx + DX (D);
                     Ny : constant Integer := By + DY (D);
                  begin
                     if In_World (Nx, Ny) and then Sims (Nx / Side, Ny / Side) /= null then
                        for Q in 1 .. Max_Open loop
                           Sims (Nx / Side, Ny / Side).F (Nx mod Side, Ny mod Side, Opp (D), Q) := 0;
                        end loop;
                     end if;
                  end;
               end loop;
            end if;
         end;
      end if;
      for I in -1 .. 1 loop
         for J in -1 .. 1 loop
            Wake (CX + I, CY + J);
         end loop;
      end loop;
      --  first seen with the edit already made (About_To_Change was not
      --  called, or too much was awake then): how it lay before is not
      --  known, so it counts as changed
      if not Had and then Sims (CX, CY) /= null then
         Sims (CX, CY).C (Bx mod Side, By mod Side).Touched := True;
      end if;
   end Ground_Changed;

   procedure Tick is
      Changed_Now : Key_Sets.Set;
      To_Sleep    : Key_Sets.Set;
      All_Steady  : Boolean := True;
      Any_Running : Boolean := False;
      Fed         : Boolean := False;
   begin
      for K of Wake_Set loop
         Wake (K / Grid, K mod Grid);
      end loop;
      Wake_Set.Clear;

      for Step in 1 .. Substeps loop

         --  1. The flow out of every stretch of every awake column, from the
         --  water as it stands.
         for K of Awake_Set loop
            declare
               S  : Sim_Stack renames Sims (K / Grid, K mod Grid).all;
               CX : constant Integer := K / Grid;
               CY : constant Integer := K mod Grid;
            begin
               for X in 0 .. Side - 1 loop
                  for Y in 0 .. Side - 1 loop
                     declare
                        Own     : Column renames S.C (X, Y);
                        Own_Src : constant Natural := Src (Own);
                        Bx      : constant Integer := CX * Side + X;
                        By      : constant Integer := CY * Side + Y;
                        Mine_Of : array (Dir, 1 .. Max_Open) of Positive;   --  valid up to Used
                        Used    : array (Dir) of Natural := (others => 0);
                        Sum     : array (1 .. Max_Stretch) of Integer;
                     begin
                        for A in 1 .. Own.N loop
                           Sum (A) := 0;
                        end loop;
                        for D in Dir loop
                           declare
                              Nx : constant Integer := Bx + DX (D);
                              Ny : constant Integer := By + DY (D);

                              procedure Face (Other : Column; Live : Boolean) is
                                 O       : Opening_Array;
                                 No      : Natural;
                                 Oth_Src : constant Natural := Src (Other);
                              begin
                                 Open (Own, Other, O, No);
                                 for Q in 1 .. Max_Open loop
                                    if Q > No then
                                       S.F (X, Y, D, Q) := 0;
                                    else
                                       declare
                                          A    : Stretch renames Own.S (O (Q).A);
                                          B    : Stretch renames Other.S (O (Q).B);
                                          Ha   : constant Integer := Surf (A);
                                          Hb   : constant Integer := Surf (B);
                                          Sill : constant Integer := O (Q).Lo * Unit;
                                          Lid  : constant Integer := O (Q).Hi * Unit;
                                          --  Between source water and source water the
                                          --  head is the difference in how far each
                                          --  stands from its own level: at their levels
                                          --  nothing is simulated to move, whatever the
                                          --  fall between them (the river's own flow is
                                          --  drawn, not simulated).
                                          Both : constant Boolean := Own_Src = O (Q).A and then Oth_Src = O (Q).B;
                                          Head : constant Integer :=
                                            (if Both then (Ha - Own.Rest) - (Hb - Other.Rest)
                                             else Integer'Max (Ha, Sill) - Integer'Max (Hb, Sill));
                                          --  Source water against other ground, as the world
                                          --  was made: it holds (see the spec).  Water may
                                          --  still come into the source across it.
                                          Shut : constant Boolean :=
                                            (Own_Src = O (Q).A) /= (Oth_Src = O (Q).B)
                                            and then not Own.Touched and then not Other.Touched;
                                          F    : Integer := 0;
                                       begin
                                          if Shut and then Own_Src = O (Q).A then
                                             null;                 --  held in: nothing out, and nothing wakes for it
                                          elsif Live then
                                             --  live water: each side gives its own outflow
                                             declare
                                                Over : constant Integer := Integer'Min (Ha, Lid) - Sill;
                                             begin
                                                if A.Water > 0 and then Over > 0 and then B.Water < Cap (B) then
                                                   --  a quarter of the room left at most: fed from all
                                                   --  four sides at once, no stretch overfills
                                                   F := Integer'Min
                                                     ((Cap (B) - B.Water) / 4 * Fine,
                                                      Integer'Max (0, Kept (S.F (X, Y, D, Q), Over) + Gain (Head, Over)));
                                                end if;
                                             end;
                                          elsif Oth_Src = O (Q).B then
                                             --  resting source water (a river or a lake): a
                                             --  fixed-level edge, and a pipe like any other, with
                                             --  momentum both ways (water coming in without it
                                             --  used to lose to water going out, and a woken
                                             --  stretch of river drained to a few blocks)
                                             declare
                                                Over : constant Integer :=
                                                  (if Head >= 0 then Integer'Min (Ha, Lid) else Integer'Min (Hb, Lid)) - Sill;
                                             begin
                                                if Over > 0 then
                                                   F := Kept (S.F (X, Y, D, Q), Over) + Gain (Head, Over);
                                                   if F > 0 and then A.Water = 0 then
                                                      F := 0;
                                                   elsif F < 0 then
                                                      F := Integer'Max (F, -((Cap (A) - A.Water) / 4 * Fine));
                                                      F := Integer'Max (F, -(Integer'Max (0, -Head) / 2 * Fine));
                                                      --  on the order of what the river carries
                                                      --  past here: twice a column's share, so a
                                                      --  woken stretch of river still gets all of
                                                      --  its discharge from upstream (or it would
                                                      --  drain below its level and show a step)
                                                      if Supply /= null then
                                                         F := Integer'Max (F, -(Supply (Nx, Ny) * 2 * Fine));
                                                      end if;
                                                   end if;
                                                end if;
                                                if Shut then
                                                   F := Integer'Max (F, 0);
                                                --  drawn well below it, it wakes: the drop
                                                --  spreads into it instead of ending in a step
                                                elsif Head < -Wake_Drop and then Hb > Sill then
                                                   Wake_Set.Include (Key (Nx / Side, Ny / Side));
                                                end if;
                                             end;
                                          else
                                             --  resting still water holds only what it has, and dry
                                             --  ground holds nothing: flow across the face wakes it
                                             --  (and waits for it).  A resting lake used to feed a
                                             --  breach without end and flood whole valleys.
                                             declare
                                                Over : constant Integer :=
                                                  (if Head >= 0 then Integer'Min (Ha, Lid) else Integer'Min (Hb, Lid)) - Sill;
                                             begin
                                                if Over > 0
                                                  and then ((B.Water = 0 and then Head > 0 and then A.Water > 0
                                                             and then Kept (S.F (X, Y, D, Q), Over) + Gain (Head, Over) > 0)
                                                            or else (B.Water > 0 and then abs Head > Unit / 16
                                                                     and then (if Head > 0 then A.Water > 0 else A.Water < Cap (A))))
                                                then
                                                   Wake_Set.Include (Key (Nx / Side, Ny / Side));
                                                end if;
                                             end;
                                          end if;
                                          S.F (X, Y, D, Q) := F;
                                          Mine_Of (D, Q) := O (Q).A;
                                          Used (D) := Q;
                                          if F > 0 then
                                             Sum (O (Q).A) := Sum (O (Q).A) + Moved (F);
                                          end if;
                                       end;
                                    end if;
                                 end loop;
                              end Face;
                           begin
                              if not In_World (Nx, Ny) then
                                 --  off the map: it runs away (source water holds:
                                 --  the river goes on beyond)
                                 for Q in 1 .. Max_Open loop
                                    if Q <= Own.N and then Own.S (Q).Water > 0 and then Q /= Own_Src then
                                       S.F (X, Y, D, Q) := Integer'Max
                                         (0, Kept (S.F (X, Y, D, Q), Own.S (Q).Water)
                                             + Gain (Own.S (Q).Water, Own.S (Q).Water));
                                       Mine_Of (D, Q) := Q;
                                       Used (D) := Q;
                                       Sum (Q) := Sum (Q) + Moved (S.F (X, Y, D, Q));
                                    else
                                       S.F (X, Y, D, Q) := 0;
                                    end if;
                                 end loop;
                              elsif Sims (Nx / Side, Ny / Side) /= null then
                                 Face (Sims (Nx / Side, Ny / Side).C (Nx mod Side, Ny mod Side),
                                       Sims (Nx / Side, Ny / Side).Awake);
                              else
                                 declare
                                    G     : Column;
                                    Known : Boolean;
                                 begin
                                    Ground_Units (Nx, Ny, G, Known);
                                    if Known then
                                       Face (G, False);
                                    else
                                       for Q in 1 .. Max_Open loop
                                          S.F (X, Y, D, Q) := 0;
                                       end loop;
                                    end if;
                                 end;
                              end if;
                           end;
                        end loop;
                        --  no stretch gives more than it holds
                        for A in 1 .. Own.N loop
                           if Sum (A) > Own.S (A).Water then
                              for D in Dir loop
                                 for Q in 1 .. Used (D) loop
                                    if Mine_Of (D, Q) = A and then S.F (X, Y, D, Q) > 0 then
                                       S.F (X, Y, D, Q) := Integer (Long_Long_Integer (S.F (X, Y, D, Q))
                                         * Long_Long_Integer (Own.S (A).Water) / Long_Long_Integer (Sum (A)));
                                    end if;
                                 end loop;
                              end loop;
                           end if;
                        end loop;
                     end;
                  end loop;
               end loop;
            end;
         end loop;

         --  2. Every depth, from those flows.
         for K of Awake_Set loop
            declare
               S   : Sim_Stack renames Sims (K / Grid, K mod Grid).all;
               CX  : constant Integer := K / Grid;
               CY  : constant Integer := K mod Grid;
               Act : Natural renames Activity (K / Grid, K mod Grid);
            begin
               for X in 0 .. Side - 1 loop
                  for Y in 0 .. Side - 1 loop
                     declare
                        Own    : Column renames S.C (X, Y);
                        Own_Src : constant Natural := Src (Own);
                        Bx     : constant Integer := CX * Side + X;
                        By     : constant Integer := CY * Side + Y;
                        Old    : array (1 .. Max_Stretch) of Integer;   --  depths (1 .. Own.N)
                        Out_Of : array (1 .. Max_Stretch) of Integer := (others => 0);   --  passed on this step
                     begin
                        for A in 1 .. Own.N loop
                           Old (A) := Own.S (A).Water;
                        end loop;
                        for D in Dir loop
                           declare
                              Nx : constant Integer := Bx + DX (D);
                              Ny : constant Integer := By + DY (D);

                              procedure Face (Other : Column; Live : Sim_Access) is
                                 O  : Opening_Array;
                                 No : Natural;
                              begin
                                 Open (Own, Other, O, No);
                                 for Q in 1 .. No loop
                                    declare
                                       A  : constant Positive := O (Q).A;
                                       Fo : constant Integer := Moved (S.F (X, Y, D, Q));
                                    begin
                                       Own.S (A).Water := Own.S (A).Water - Fo;
                                       if Fo > 0 then
                                          Out_Of (A) := Out_Of (A) + Fo;
                                       end if;
                                       Act := Natural'Max (Act, abs Fo);
                                       if Live /= null then
                                          Own.S (A).Water := Own.S (A).Water
                                            + Moved (Live.F (Nx mod Side, Ny mod Side, Opp (D), Q));
                                       elsif Fo > 0 then
                                          Out_Sum := Out_Sum + Long_Long_Integer (Fo);   --  into the resting river or lake
                                       else
                                          In_Sum := In_Sum + Long_Long_Integer (-Fo);    --  from it
                                       end if;
                                    end;
                                 end loop;
                              end Face;
                           begin
                              if not In_World (Nx, Ny) then
                                 for Q in 1 .. Own.N loop
                                    Own.S (Q).Water := Own.S (Q).Water - Moved (S.F (X, Y, D, Q));
                                    Out_Sum := Out_Sum + Long_Long_Integer (Moved (S.F (X, Y, D, Q)));
                                    Act := Natural'Max (Act, Moved (S.F (X, Y, D, Q)));
                                 end loop;
                              elsif Sims (Nx / Side, Ny / Side) /= null then
                                 Face (Sims (Nx / Side, Ny / Side).C (Nx mod Side, Ny mod Side),
                                       (if Sims (Nx / Side, Ny / Side).Awake then Sims (Nx / Side, Ny / Side) else null));
                              else
                                 declare
                                    G     : Column;
                                    Known : Boolean;
                                 begin
                                    Ground_Units (Nx, Ny, G, Known);
                                    if Known then
                                       Face (G, null);
                                    end if;
                                 end;
                              end if;
                           end;
                        end loop;
                        --  Source water off its level: what it lacks comes
                        --  back, a share a step and no faster than the river
                        --  brings it or the lake has it; what it has over
                        --  runs off as fast.
                        if Own_Src > 0 and then Recharge /= null then
                           declare
                              T    : Stretch renames Own.S (Own_Src);
                              Lack : constant Integer := Own.Rest - (T.Floor * Unit + T.Water);
                              R    : Integer := 0;
                           begin
                              if Lack > 0 then
                                 R := Integer'Min (Lack, Integer'Min (Recharge (Bx, By),
                                                                      Integer'Max (1, Lack / Refill_Steps)));
                                 In_Sum := In_Sum + Long_Long_Integer (R);
                              elsif Lack < 0 then
                                 R := -Integer'Min (-Lack, Integer'Max (1, (-Lack) / Refill_Steps));
                                 Out_Sum := Out_Sum + Long_Long_Integer (-R);
                              end if;
                              T.Water := T.Water + R;
                           end;
                        end if;
                        --  Water off the sources runs out: a column keeps a
                        --  little of what runs through it, and a thin sheet
                        --  on the move soaks away fast (see the spec).
                        if Leak_On then
                           for A in 1 .. Own.N loop
                              if Out_Of (A) > 0 and then A /= Own_Src then
                                 declare
                                    L : Integer := Out_Of (A) / Leak_Den;
                                 begin
                                    if Own.S (A).Water < Sheet_Depth then
                                       L := L + Sheet_Loss;
                                    end if;
                                    L := Integer'Min (L, Own.S (A).Water);
                                    if L > 0 then
                                       Own.S (A).Water := Own.S (A).Water - L;
                                       Dried_Sum := Dried_Sum + Long_Long_Integer (L);
                                    end if;
                                 end;
                              end if;
                           end loop;
                        end if;
                        for A in 1 .. Own.N loop
                           Act := Natural'Max (Act, abs (Own.S (A).Water - Old (A)));
                        end loop;
                     end;
                  end loop;
               end loop;
            end;
         end loop;
      end loop;

      --  3. Once a tick: what is drawn, and who sleeps.
      for K of Awake_Set loop
         declare
            S   : Sim_Stack renames Sims (K / Grid, K mod Grid).all;
            CX  : constant Integer := K / Grid;
            CY  : constant Integer := K mod Grid;
            Act : Natural renames Activity (K / Grid, K mod Grid);
         begin
            for X in 0 .. Side - 1 loop
               for Y in 0 .. Side - 1 loop
                  for A in 1 .. Max_Stretch loop
                     declare
                        Blocks : constant Integer :=
                          (if A > S.C (X, Y).N then 0
                           else (Integer'Min (S.C (X, Y).S (A).Water, Cap (S.C (X, Y).S (A))) + Unit / 2) / Unit);
                     begin
                        if Blocks /= S.Shown (X, Y, A) and then A = 1 then
                           --  open-sky water is drawn from the surface
                           --  textures, which follow it every tick
                           S.Shown (X, Y, A) := Blocks;
                        elsif Blocks /= S.Shown (X, Y, A) then
                           S.Shown (X, Y, A) := Blocks;
                           Changed_Now.Include (K);
                           --  the neighbours' faces look at the border columns
                           if X = 0 and then CX > 0 then Changed_Now.Include (Key (CX - 1, CY)); end if;
                           if X = Side - 1 and then CX < Grid - 1 then Changed_Now.Include (Key (CX + 1, CY)); end if;
                           if Y = 0 and then CY > 0 then Changed_Now.Include (Key (CX, CY - 1)); end if;
                           if Y = Side - 1 and then CY < Grid - 1 then Changed_Now.Include (Key (CX, CY + 1)); end if;
                        end if;
                     end;
                  end loop;
               end loop;
            end loop;
            if Act <= Quiet_Flow then
               S.Quiet := S.Quiet + 1;
               if S.Quiet >= Sleep_Ticks then
                  To_Sleep.Include (K);
               end if;
            else
               S.Quiet := 0;
            end if;
            Act := 0;
            --  running on without changing?
            declare
               Sum   : Long_Long_Integer := 0;
               Moved : Boolean := False;
            begin
               for X in 0 .. Side - 1 loop
                  for Y in 0 .. Side - 1 loop
                     for A in 1 .. S.C (X, Y).N loop
                        declare
                           W : constant Integer := S.C (X, Y).S (A).Water;
                        begin
                           Sum := Sum + Long_Long_Integer (W);
                           if abs (W - S.Ref (X, Y, A)) > Steady_Within
                             and then Integer'Max (W, S.Ref (X, Y, A)) >= Sheet_Depth
                           then
                              Moved := True;
                           end if;
                        end;
                     end loop;
                  end loop;
               end loop;
               if Moved or else abs (Sum - S.Ref_Sum) > Steady_Sum or else S.Steady = 0 then
                  for X in 0 .. Side - 1 loop
                     for Y in 0 .. Side - 1 loop
                        for A in 1 .. Max_Stretch loop
                           S.Ref (X, Y, A) := (if A <= S.C (X, Y).N then S.C (X, Y).S (A).Water else 0);
                        end loop;
                     end loop;
                  end loop;
                  S.Ref_Sum := Sum;
                  S.Steady := 1;
               else
                  S.Steady := S.Steady + 1;
               end if;
               --  (a stack with nothing on the move, woken by an edit
               --  beside it, is not waited for: it sleeps by itself)
               All_Steady := All_Steady and then (S.Steady > Steady_Ticks or else S.Quiet > 0);
               Any_Running := Any_Running or else S.Quiet = 0;
            end;
         end;
      end loop;
      --  the flow is established: all that is awake sleeps as it lies
      Through_At := (Through_At + 1) mod (Steady_Ticks + 1);
      Fed := In_Sum > Through (Through_At);    --  against the tick Steady_Seconds back
      Through (Through_At) := In_Sum;
      if All_Steady and then Any_Running and then Fed then
         for K of Awake_Set loop
            if not To_Sleep.Contains (K) then
               Sims (K / Grid, K mod Grid).Running := Sims (K / Grid, K mod Grid).Quiet = 0;
               To_Sleep.Include (K);
            end if;
         end loop;
      end if;

      for K of To_Sleep loop
         Sims (K / Grid, K mod Grid).Awake := False;
         Awake_Set.Exclude (K);
         if Sims (K / Grid, K mod Grid).Running then
            goto Asleep;                      --  as it lies, its flows kept for the drawing and the waking
         end if;
         Sims (K / Grid, K mod Grid).F := (others => (others => (others => (others => 0))));
         --  source water going to sleep all but at its level is put on it
         for C of Sims (K / Grid, K mod Grid).C loop
            declare
               I : constant Natural := Src (C);
            begin
               if I > 0 then
                  declare
                     Lack : constant Integer := C.Rest - (C.S (I).Floor * Unit + C.S (I).Water);
                  begin
                     if Lack /= 0 and then abs Lack <= Settle_Within then
                        C.S (I).Water := C.S (I).Water + Lack;
                        if Lack > 0 then
                           In_Sum := In_Sum + Long_Long_Integer (Lack);
                        else
                           Out_Sum := Out_Sum + Long_Long_Integer (-Lack);
                        end if;
                     end if;
                  end;
               end if;
            end;
         end loop;
         <<Asleep>>
      end loop;
      for K of Changed_Now loop
         Vers (K / Grid, K mod Grid) := Vers (K / Grid, K mod Grid) + 1;
         Changed_Set.Include (K);
      end loop;
   end Tick;

   function Take_Changed return Stack_List is
      L : Stack_List (1 .. Natural (Changed_Set.Length));
      I : Natural := 0;
   begin
      for K of Changed_Set loop
         I := I + 1;
         L (I) := (K / Grid, K mod Grid);
      end loop;
      Changed_Set.Clear;
      return L;
   end Take_Changed;

   function Version (CX, CY : Integer) return Natural is (Vers (CX, CY));

   function View_Of (CX, CY : Integer) return View_Access is
      Any : Boolean := False;
      V   : View_Access;
   begin
      for I in -1 .. 1 loop
         for J in -1 .. 1 loop
            if CX + I in 0 .. Grid - 1 and then CY + J in 0 .. Grid - 1
              and then Sims (CX + I, CY + J) /= null
            then
               Any := True;
            end if;
         end loop;
      end loop;
      if not Any then
         return null;
      end if;
      V := new View_Grid;
      for X in View_Grid'Range (1) loop
         for Y in View_Grid'Range (2) loop
            declare
               Bx : constant Integer := CX * Side + X;
               By : constant Integer := CY * Side + Y;
            begin
               if In_World (Bx, By) and then Sims (Bx / Side, By / Side) /= null then
                  declare
                     S : Sim_Stack renames Sims (Bx / Side, By / Side).all;
                  begin
                     V (X, Y).Sim := True;
                     V (X, Y).C := S.C (Bx mod Side, By mod Side);
                     for A in 1 .. V (X, Y).C.N loop
                        V (X, Y).C.S (A).Water := S.Shown (Bx mod Side, By mod Side, A);
                     end loop;
                  end;
               end if;
            end;
         end loop;
      end loop;
      return V;
   end View_Of;

   procedure Free_View is new Ada.Unchecked_Deallocation (View_Grid, View_Access);
   procedure Free (V : in out View_Access) is
   begin
      if V /= null then
         Free_View (V);
      end if;
   end Free;

   procedure Apply (V : View_Grid; Work : in out Stack_Work) is
   begin
      for X in 0 .. Side - 1 loop
         for Y in 0 .. Side - 1 loop
            if V (X, Y).Sim then
               for A in 1 .. V (X, Y).C.N loop
                  declare
                     St  : Stretch renames V (X, Y).C.S (A);
                     Top : constant Integer := Integer'Min (St.Ceil, Integer'Min (Height_B, Work.Air_From + 1));
                  begin
                     --  the water that lay in the stretch goes; the simulation's comes
                     for Z in St.Floor .. Top - 1 loop
                        if Work.G (X, Y, Z).Mat = Castle.Blocks.Water then
                           Work.G (X, Y, Z) := Air_Block;
                        end if;
                     end loop;
                     for Z in St.Floor .. Integer'Min (St.Ceil, St.Floor + St.Water) - 1 loop
                        if Class_Of (Work.G (X, Y, Z).Mat) /= Solid then
                           Work.G (X, Y, Z) := (Mat => Castle.Blocks.Water, State => 0);
                        end if;
                     end loop;
                     Work.Air_From := Integer'Max (Work.Air_From, Integer'Min (St.Ceil, St.Floor + St.Water));
                  end;
               end loop;
            end if;
         end loop;
      end loop;
   end Apply;

   procedure Scan (Top, Bottom : Integer; C : out Column) is
      Ceil    : Integer := Height_B;
      In_Open : Boolean := True;

      procedure Add (Floor : Integer) is
         W : Natural := 0;
      begin
         while Floor + W < Ceil and then Floor + W <= Top and then Wet (Floor + W) loop
            W := W + 1;
         end loop;
         C.N := C.N + 1;
         C.S (C.N) := (Floor, Ceil, W);
      end Add;
   begin
      C := (N => 0, S => (others => (0, 0, 0)), others => <>);
      for Z in reverse Bottom .. Top loop
         if Solid (Z) then
            if In_Open then
               Add (Z + 1);
               In_Open := False;
               exit when C.N = Max_Stretch;
            end if;
         elsif not In_Open then
            Ceil := Z + 1;
            In_Open := True;
         end if;
      end loop;
      if In_Open and then C.N < Max_Stretch then
         Add (Bottom);
      end if;
   end Scan;

   function To_Column (S : Short_Column) return Column is
      C : Column;
   begin
      C.N := Natural (S.N);
      C.Flowing := S.Flowing;
      C.Rest := Integer (S.Rest);
      for I in 1 .. C.N loop
         C.S (I) := (Integer (S.S (I).Floor), Integer (S.S (I).Ceil), Integer (S.S (I).Water));
      end loop;
      return C;
   end To_Column;

   function To_Short (C : Column) return Short_Column is
      S : Short_Column;
   begin
      S.N := Interfaces.Unsigned_8 (C.N);
      S.Flowing := C.Flowing;
      S.Rest := Interfaces.Integer_32 (C.Rest);
      for I in 1 .. C.N loop
         S.S (I) := (Interfaces.Integer_16 (C.S (I).Floor), Interfaces.Integer_16 (C.S (I).Ceil),
                     Interfaces.Integer_16 (C.S (I).Water));
      end loop;
      return S;
   end To_Short;

   procedure Summarize (Work : Stack_Work; S : out Ground_Summary) is
   begin
      for X in 0 .. Side - 1 loop
         for Y in 0 .. Side - 1 loop
            declare
               function Solid_Z (Z : Integer) return Boolean is (Class_Of (Work.G (X, Y, Z).Mat) = Solid);
               function Wet_Z (Z : Integer) return Boolean is (Work.G (X, Y, Z).Mat = Castle.Blocks.Water);
               procedure Scan_Here is new Scan (Solid_Z, Wet_Z);
               C : Column;
            begin
               --  nothing is open below the skin but what edits opened (they
               --  lower the skin round themselves)
               Scan_Here (Integer'Min (Height_B - 1, Work.Air_From),
                          Work.Skin (X / Blocks_Per_Meter, Y / Blocks_Per_Meter) * Blocks_Per_Meter, C);
               C.Flowing := Work.Flowing (X, Y);
               C.Rest := Integer (Float'Rounding (Work.Rest (X, Y) * Float (Unit)));
               S (X, Y) := To_Short (C);
            end;
         end loop;
      end loop;
   end Summarize;

   ---------------------------------------------------------- the summary kept small

   use type Interfaces.Integer_16;
   use type Interfaces.Integer_32;
   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;

   function Is_Plain (C : Short_Column) return Boolean is
     (C.N = 1 and then Integer (C.S (1).Ceil) = Height_B and then C.S (1).Water = 0 and then C.S (1).Floor >= 0
      and then not C.Flowing and then C.Rest = 0);

   --  Words a column that is not plain takes in the pool.
   function Words_Of (C : Short_Column) return Natural is (3 + 3 * Natural (C.N));

   function Low (V : Interfaces.Integer_32) return Interfaces.Integer_16 is
      function To_I16 is new Ada.Unchecked_Conversion (Interfaces.Unsigned_16, Interfaces.Integer_16);
      function To_U32 is new Ada.Unchecked_Conversion (Interfaces.Integer_32, Interfaces.Unsigned_32);
   begin
      return To_I16 (Interfaces.Unsigned_16 (To_U32 (V) and 16#FFFF#));
   end Low;

   function High (V : Interfaces.Integer_32) return Interfaces.Integer_16 is
      function To_I16 is new Ada.Unchecked_Conversion (Interfaces.Unsigned_16, Interfaces.Integer_16);
      function To_U32 is new Ada.Unchecked_Conversion (Interfaces.Integer_32, Interfaces.Unsigned_32);
   begin
      return To_I16 (Interfaces.Unsigned_16 (Interfaces.Shift_Right (To_U32 (V), 16)));
   end High;

   function Join (Lo, Hi : Interfaces.Integer_16) return Interfaces.Integer_32 is
      function To_U16 is new Ada.Unchecked_Conversion (Interfaces.Integer_16, Interfaces.Unsigned_16);
      function To_I32 is new Ada.Unchecked_Conversion (Interfaces.Unsigned_32, Interfaces.Integer_32);
   begin
      return To_I32 (Interfaces.Shift_Left (Interfaces.Unsigned_32 (To_U16 (Hi)), 16)
                     or Interfaces.Unsigned_32 (To_U16 (Lo)));
   end Join;

   procedure Write (Pool : in out Word_Array; At_W : Positive; C : Short_Column) is
      W : Positive := At_W;
   begin
      Pool (W) := Interfaces.Integer_16 (C.N) + (if C.Flowing then 256 else 0);
      Pool (W + 1) := Low (C.Rest);
      Pool (W + 2) := High (C.Rest);
      W := W + 3;
      for I in 1 .. Natural (C.N) loop
         Pool (W) := C.S (I).Floor;
         Pool (W + 1) := C.S (I).Ceil;
         Pool (W + 2) := C.S (I).Water;
         W := W + 3;
      end loop;
   end Write;

   function Shrink (S : Ground_Summary) return Small_Access is
      Words : Natural := 0;
      R     : Small_Access;
      Next  : Positive := 1;
   begin
      for X in S'Range (1) loop
         for Y in S'Range (2) loop
            if not Is_Plain (S (X, Y)) then
               Words := Words + Words_Of (S (X, Y));
            end if;
         end loop;
      end loop;
      R := new Small_Summary (Words);
      for X in S'Range (1) loop
         for Y in S'Range (2) loop
            if Is_Plain (S (X, Y)) then
               R.Place (X, Y) := S (X, Y).S (1).Floor;
            else
               R.Place (X, Y) := -Interfaces.Integer_16 (Next);
               Write (R.Pool, Next, S (X, Y));
               Next := Next + Words_Of (S (X, Y));
            end if;
         end loop;
      end loop;
      return R;
   end Shrink;

   function Column_Of (S : Small_Summary; X, Y : Integer) return Short_Column is
      P : constant Interfaces.Integer_16 := S.Place (X, Y);
      C : Short_Column;
   begin
      if P >= 0 then
         C.N := 1;
         C.S (1) := (Floor => P, Ceil => Interfaces.Integer_16 (Height_B), Water => 0);
         return C;
      end if;
      declare
         W : Positive := Positive (-Integer (P));
      begin
         C.N := Interfaces.Unsigned_8 (S.Pool (W) mod 256);
         C.Flowing := S.Pool (W) >= 256;
         C.Rest := Join (S.Pool (W + 1), S.Pool (W + 2));
         W := W + 3;
         for I in 1 .. Natural (C.N) loop
            C.S (I) := (Floor => S.Pool (W), Ceil => S.Pool (W + 1), Water => S.Pool (W + 2));
            W := W + 3;
         end loop;
      end;
      return C;
   end Column_Of;

   procedure Expand (S : Small_Summary; Into : out Ground_Summary) is
   begin
      for X in Into'Range (1) loop
         for Y in Into'Range (2) loop
            Into (X, Y) := Column_Of (S, X, Y);
         end loop;
      end loop;
   end Expand;

   procedure Free_Small is new Ada.Unchecked_Deallocation (Small_Summary, Small_Access);
   procedure Free (S : in out Small_Access) is
   begin
      if S /= null then
         Free_Small (S);
      end if;
   end Free;

   procedure Set_Column (S : in out Small_Access; X, Y : Integer; C : Short_Column; Repacked : out Boolean) is
      P : constant Interfaces.Integer_16 := S.Place (X, Y);
   begin
      Repacked := False;
      if Is_Plain (C) and then P >= 0 then
         S.Place (X, Y) := C.S (1).Floor;                 --  plain still: its floor
      elsif not Is_Plain (C) and then P < 0
        and then Natural (S.Pool (Positive (-Integer (P))) mod 256) = Natural (C.N)
      then
         Write (S.Pool, Positive (-Integer (P)), C);      --  as many stretches as it had: over its own words
      else
         declare
            Full : Ground_Summary;
            Was  : Small_Access := S;
         begin
            Expand (S.all, Full);
            Full (X, Y) := C;
            S := Shrink (Full);
            Free (Was);
            Repacked := True;
         end;
      end if;
   end Set_Column;

   function Bytes_Of (S : Small_Summary) return Natural is (S'Size / 8);

   procedure Free_Summary is new Ada.Unchecked_Deallocation (Ground_Summary, Summary_Access);
   procedure Free (S : in out Summary_Access) is
   begin
      if S /= null then
         Free_Summary (S);
      end if;
   end Free;

   procedure Each_Stack (Visit : not null access procedure (CX, CY : Integer; Awake : Boolean;
                                                            C : Stack_Columns)) is
   begin
      for CX in 0 .. Grid - 1 loop
         for CY in 0 .. Grid - 1 loop
            if Sims (CX, CY) /= null then
               --  (running water is saved as awake: its flows are not kept,
               --  and it finds them again)
               Visit (CX, CY, Sims (CX, CY).Awake or else Sims (CX, CY).Running, Sims (CX, CY).C);
            end if;
         end loop;
      end loop;
   end Each_Stack;

   procedure Restore (CX, CY : Integer; Awake : Boolean; C : Stack_Columns) is
   begin
      if Sims (CX, CY) = null then
         Sims (CX, CY) := new Sim_Stack;
         Simulated := Simulated + 1;
      end if;
      declare
         S : Sim_Stack renames Sims (CX, CY).all;
      begin
         S.C := C;
         S.F := (others => (others => (others => (others => 0))));
         for X in 0 .. Side - 1 loop
            for Y in 0 .. Side - 1 loop
               for A in 1 .. Max_Stretch loop
                  S.Shown (X, Y, A) :=
                    (if A > C (X, Y).N then 0
                     else (Integer'Min (C (X, Y).S (A).Water, Cap (C (X, Y).S (A))) + Unit / 2) / Unit);
               end loop;
            end loop;
         end loop;
         S.Awake := Awake;
         S.Quiet := 0;
         S.Steady := 0;
         S.Running := False;
         if Awake then
            Awake_Set.Include (Key (CX, CY));
         end if;
      end;
      for I in -1 .. 1 loop
         for J in -1 .. 1 loop
            if CX + I in 0 .. Grid - 1 and then CY + J in 0 .. Grid - 1 then
               Vers (CX + I, CY + J) := Vers (CX + I, CY + J) + 1;
            end if;
         end loop;
      end loop;
   end Restore;

   function Total return Long_Long_Integer is
      T : Long_Long_Integer := 0;
   begin
      for S of Sims.all loop
         if S /= null then
            for C of S.C loop
               for I in 1 .. C.N loop
                  T := T + Long_Long_Integer (C.S (I).Water);
               end loop;
            end loop;
         end if;
      end loop;
      return T;
   end Total;

   function Came_In return Long_Long_Integer is (In_Sum);
   function Went_Out return Long_Long_Integer is (Out_Sum);
   function Awake_Count return Natural is (Natural (Awake_Set.Length));
   function Capped return Boolean is (Was_Capped);
   function Simulated_Count return Natural is (Simulated);
   function Is_Awake (CX, CY : Integer) return Boolean is
     (Sims (CX, CY) /= null and then Sims (CX, CY).Awake);
   function Is_Running (CX, CY : Integer) return Boolean is
     (CX in 0 .. Grid - 1 and then CY in 0 .. Grid - 1 and then Sims (CX, CY) /= null
      and then Sims (CX, CY).Running);

   procedure Surface (CX, CY : Integer; G : out Surface_Grid; Have : out Boolean) is
   begin
      G := (others => (others => <>));
      Have := CX in 0 .. Grid - 1 and then CY in 0 .. Grid - 1 and then Sims (CX, CY) /= null;
      if not Have then
         return;
      end if;
      declare
         S : Sim_Stack renames Sims (CX, CY).all;
      begin
         for X in 0 .. Side - 1 loop
            for Y in 0 .. Side - 1 loop
               declare
                  C : Column renames S.C (X, Y);
               begin
                  if C.N >= 1 then
                     declare
                        T  : Stretch renames C.S (1);
                        D  : constant Integer := Integer'Min (T.Water, Cap (T));
                        Wd : constant Float := Float (Integer'Max (D, Unit / 8));
                        --  whole units out through a face this step; only a
                        --  one-stretch column's first opening is surely its
                        --  top stretch's
                        function Out_Of (Dr : Dir) return Float is
                          (if C.N = 1 then Float (S.F (X, Y, Dr, 1)) / Float (Fine) else 0.0);
                        --  units per step over the depth: the share of the
                        --  column moving, times 0.25 m per 0.025 s step
                        function Speed (V : Float) return Float is
                          (Float'Max (-3.0, Float'Min (3.0, V / Wd * 10.0)));
                     begin
                        G (X, Y).Floor := Float (T.Floor);
                        G (X, Y).Level := Float (T.Floor) + Float (D) / Float (Unit);
                        G (X, Y).Source := Src (C) = 1;
                        if (S.Awake or else S.Running) and then D > 0 then
                           G (X, Y).Vx := Speed (Out_Of (0) - Out_Of (1));
                           G (X, Y).Vy := Speed (Out_Of (2) - Out_Of (3));
                        end if;
                     end;
                  end if;
               end;
            end loop;
         end loop;
      end;
   end Surface;

   procedure Outflows (CX, CY : Integer; G : out Outflow_Grid; Have : out Boolean) is
   begin
      G := (others => (others => (others => <>)));
      Have := CX in 0 .. Grid - 1 and then CY in 0 .. Grid - 1 and then Sims (CX, CY) /= null
        and then (Sims (CX, CY).Awake or else Sims (CX, CY).Running);
      if not Have then
         return;
      end if;
      declare
         S : Sim_Stack renames Sims (CX, CY).all;
      begin
         for X in 0 .. Side - 1 loop
            for Y in 0 .. Side - 1 loop
               if S.C (X, Y).N >= 1 and then S.C (X, Y).S (1).Water > 0 then
                  for D in Dir loop
                     if (for some Q in 1 .. Max_Open => S.F (X, Y, D, Q) > 0) then
                        declare
                           Own   : Column renames S.C (X, Y);
                           Nx    : constant Integer := CX * Side + X + DX (D);
                           Ny    : constant Integer := CY * Side + Y + DY (D);
                           Other : Column;
                           Known : Boolean := In_World (Nx, Ny);
                           O     : Opening_Array;
                           No    : Natural;
                        begin
                           if Known then
                              if Sims (Nx / Side, Ny / Side) /= null then
                                 Other := Sims (Nx / Side, Ny / Side).C (Nx mod Side, Ny mod Side);
                              else
                                 Ground_Units (Nx, Ny, Other, Known);
                              end if;
                           end if;
                           if Known then
                              Open (Own, Other, O, No);
                              for Q in 1 .. No loop
                                 --  (the top stretch's opening: the one drawn as surface;
                                 --  and not between source water and source water: what
                                 --  moves there is how far each has dropped from its own
                                 --  level, not the river's flow, which is drawn and not
                                 --  simulated, so a stream's own fall looks the same awake
                                 --  as asleep)
                                 if O (Q).A = 1 and then S.F (X, Y, D, Q) > 0
                                   and then (Src (Own) /= 1 or else Src (Other) /= O (Q).B)
                                 then
                                    declare
                                       Over : constant Integer :=
                                         Integer'Min (Surf (Own.S (1)), O (Q).Hi * Unit) - O (Q).Lo * Unit;
                                    begin
                                       if Over > 0 then
                                          G (X, Y) (Integer (D)) :=
                                            (Speed => Float'Min (10.0, Float (S.F (X, Y, D, Q)) / Float (Fine)
                                                                       / Float (Over) * 10.0),
                                             Over  => Float (Over) / Float (Unit));
                                       end if;
                                    end;
                                 end if;
                              end loop;
                           end if;
                        end;
                     end if;
                  end loop;
               end if;
            end loop;
         end loop;
      end;
   end Outflows;

   function Is_Simulated (CX, CY : Integer) return Boolean is
     (CX in 0 .. Grid - 1 and then CY in 0 .. Grid - 1 and then Sims (CX, CY) /= null);

   function Awake_List return Stack_List is
      L : Stack_List (1 .. Natural (Awake_Set.Length));
      I : Natural := 0;
   begin
      for K of Awake_Set loop
         I := I + 1;
         L (I) := (CX => K / Grid, CY => K mod Grid);
      end loop;
      return L;
   end Awake_List;

   procedure Set_Supply (Source : Supply_Source) is
   begin
      Supply := Source;
   end Set_Supply;

   procedure Set_Recharge (Source : Supply_Source) is
   begin
      Recharge := Source;
   end Set_Recharge;

   function Rest_Level (Bx, By : Integer) return Integer is
   begin
      if not In_World (Bx, By) or else Sims (Bx / Side, By / Side) = null then
         return 0;
      end if;
      declare
         C : Column renames Sims (Bx / Side, By / Side).C (Bx mod Side, By mod Side);
      begin
         return (if Src (C) > 0 then C.Rest else 0);
      end;
   end Rest_Level;

   function Drop (Bx, By : Integer) return Integer is
   begin
      if not In_World (Bx, By) or else Sims (Bx / Side, By / Side) = null then
         return 0;
      end if;
      declare
         C : Column renames Sims (Bx / Side, By / Side).C (Bx mod Side, By mod Side);
         I : constant Natural := Src (C);
      begin
         return (if I > 0 then C.Rest - (C.S (I).Floor * Unit + C.S (I).Water) else 0);
      end;
   end Drop;

   procedure Set_Seep (Source : Seep_Source) is
   begin
      Seep := Source;
   end Set_Seep;

   procedure Dry_Out (Hours, Evaporation_Mm, Seep_Scale : Float) is
      Per_Mm : constant Float := Float (Unit) / 250.0;     --  a block is 250 mm
   begin
      if Hours <= 0.0 then
         return;
      end if;
      for CX in 0 .. Grid - 1 loop
         for CY in 0 .. Grid - 1 loop
            --  (asleep with its flow established it is fed as it dries)
            if Sims (CX, CY) /= null and then not Sims (CX, CY).Running then
               declare
                  S   : Sim_Stack renames Sims (CX, CY).all;
                  Any : Boolean := False;
                  Low : Boolean := False;                --  tunnel water changed as blocks show it
               begin
                  for X in 0 .. Side - 1 loop
                     for Y in 0 .. Side - 1 loop
                        for A in 1 .. S.C (X, Y).N loop
                           declare
                              T : Stretch renames S.C (X, Y).S (A);
                           begin
                              --  (source water is fed as fast as it dries: left
                              --  out, or a river once woken sank into its bed)
                              if T.Water > 0 and then A /= Src (S.C (X, Y)) then
                                 declare
                                    Mm : Float := 0.0;
                                 begin
                                    if Seep /= null then
                                       Mm := Seep (CX * Side + X, CY * Side + Y, T.Floor - 1) * Seep_Scale;
                                    end if;
                                    if A = 1 and then T.Ceil >= Height_B then
                                       Mm := Mm + Evaporation_Mm;
                                    end if;
                                    declare
                                       Loss : constant Integer :=
                                         Integer'Min (T.Water, Integer (Float'Max (0.0, Mm * Hours * Per_Mm)));
                                    begin
                                       if Loss > 0 then
                                          T.Water := T.Water - Loss;
                                          Dried_Sum := Dried_Sum + Long_Long_Integer (Loss);
                                          Any := True;
                                          if A >= 2 and then (Integer'Min (T.Water, Cap (T)) + Unit / 2) / Unit
                                            /= S.Shown (X, Y, A)
                                          then
                                             S.Shown (X, Y, A) := (Integer'Min (T.Water, Cap (T)) + Unit / 2) / Unit;
                                             Low := True;
                                          end if;
                                       end if;
                                    end;
                                 end;
                              end if;
                           end;
                        end loop;
                     end loop;
                  end loop;
                  if Any and then not S.Awake then
                     Dried_Set.Include (Key (CX, CY));
                  end if;
                  if Low then
                     Vers (CX, CY) := Vers (CX, CY) + 1;
                     Changed_Set.Include (Key (CX, CY));
                  end if;
               end;
            end if;
         end loop;
      end loop;
   end Dry_Out;

   procedure Pour (Bx, By : Integer; Units : Natural) is
      CX : constant Integer := Bx / Side;
      CY : constant Integer := By / Side;
   begin
      Wake (CX, CY);
      if CX in 0 .. Grid - 1 and then CY in 0 .. Grid - 1 and then Sims (CX, CY) /= null then
         declare
            C : Column renames Sims (CX, CY).C (Bx mod Side, By mod Side);
            Room : constant Integer := (if C.N >= 1 then Cap (C.S (1)) - C.S (1).Water else 0);
            Add  : constant Integer := Integer'Min (Units, Integer'Max (0, Room));
         begin
            if Add > 0 then
               C.S (1).Water := C.S (1).Water + Add;
               In_Sum := In_Sum + Long_Long_Integer (Add);   --  water from outside, like a source's
            end if;
         end;
      end if;
   end Pour;

   function Take_Dried return Stack_List is
      L : Stack_List (1 .. Natural (Dried_Set.Length));
      I : Natural := 0;
   begin
      for K of Dried_Set loop
         I := I + 1;
         L (I) := (CX => K / Grid, CY => K mod Grid);
      end loop;
      Dried_Set.Clear;
      return L;
   end Take_Dried;

   function Dried return Long_Long_Integer is (Dried_Sum);

   procedure Set_Leak (On : Boolean) is
   begin
      Leak_On := On;
   end Set_Leak;

   function Depth (Bx, By : Integer) return Integer is
   begin
      if not In_World (Bx, By) or else Sims (Bx / Side, By / Side) = null then
         return -1;
      end if;
      declare
         C : Column renames Sims (Bx / Side, By / Side).C (Bx mod Side, By mod Side);
         T : Integer := 0;
      begin
         for I in 1 .. C.N loop
            T := T + C.S (I).Water;
         end loop;
         return T;
      end;
   end Depth;

   function Depth_At (Bx, By, Row : Integer) return Integer is
   begin
      if not In_World (Bx, By) or else Sims (Bx / Side, By / Side) = null then
         return -1;
      end if;
      declare
         C : Column renames Sims (Bx / Side, By / Side).C (Bx mod Side, By mod Side);
      begin
         for I in 1 .. C.N loop
            if Row >= C.S (I).Floor and then Row < C.S (I).Ceil then
               return C.S (I).Water;
            end if;
         end loop;
         return -1;
      end;
   end Depth_At;

   procedure Reset is
   begin
      for S of Sims.all loop
         if S /= null then
            Free_Sim (S);
         end if;
      end loop;
      Dried_Sum := 0;
      Dried_Set.Clear;
      Awake_Set.Clear;
      Changed_Set.Clear;
      Wake_Set.Clear;
      Simulated := 0;
      Was_Capped := False;
      In_Sum := 0;
      Out_Sum := 0;
      Through := (others => 0);
      Through_At := 0;
   end Reset;

end Castle.Water;
