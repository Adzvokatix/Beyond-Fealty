with Ada.Exceptions;  use Ada.Exceptions;
with Ada.Real_Time;   use Ada.Real_Time;
with Ada.Text_IO;     use Ada.Text_IO;
with Ada.Unchecked_Deallocation;
with Castle.Chunks;   use Castle.Chunks;
with Castle.Edits;
with Castle.Lod;

package body Castle.Streaming is

   use type Castle.Water.View_Access;

   type Job is record
      CX, CY    : Integer := 0;
      Priority  : Float := 0.0;
      View      : Castle.Water.View_Access;
      Water_Ver : Natural := 0;
      Mesh      : Boolean := True;
      Level     : Natural := 0;        --  a tile of the far view (CX, CY: its place among its level's)
   end record;

   Max_Jobs    : constant := 2 * Chunks_XY * Chunks_XY;   --  every stack of the world, twice
   Max_Results : constant := 8_192;

   type Job_Heap is array (1 .. Max_Jobs) of Job;
   type Job_Heap_Access is access Job_Heap;
   type Result_Ring is array (0 .. Max_Results - 1) of Result_Access;

   The_World : World;

   protected Jobs is
      entry Take (J : out Job; Ok : out Boolean);
      procedure Put (J : Job);
      procedure Halt;
      function Count return Natural;
      function Lost_N return Natural;
   private
      Heap     : Job_Heap_Access := new Job_Heap;
      N        : Natural := 0;
      Stopping : Boolean := False;
      Lost     : Natural := 0;
   end Jobs;

   protected body Jobs is

      entry Take (J : out Job; Ok : out Boolean) when N > 0 or else Stopping is
         Last  : Job;
         I     : Positive := 1;
         Child : Positive;
      begin
         if Stopping then
            J := (0, 0, 0.0, null, 0, True, 0);
            Ok := False;
            return;
         end if;
         J := Heap (1);
         Ok := True;
         Last := Heap (N);
         N := N - 1;
         if N > 0 then
            loop
               Child := 2 * I;
               exit when Child > N;
               if Child < N and then Heap (Child + 1).Priority < Heap (Child).Priority then
                  Child := Child + 1;
               end if;
               exit when Heap (Child).Priority >= Last.Priority;
               Heap (I) := Heap (Child);
               I := Child;
            end loop;
            Heap (I) := Last;
         end if;
      end Take;

      procedure Put (J : Job) is
         I : Positive;
      begin
         if N = Max_Jobs then
            Lost := Lost + 1;                      --  (never: room for every stack twice; counted, and said)
            return;
         end if;
         N := N + 1;
         I := N;
         while I > 1 and then Heap (I / 2).Priority > J.Priority loop
            Heap (I) := Heap (I / 2);
            I := I / 2;
         end loop;
         Heap (I) := J;
      end Put;

      procedure Halt is
      begin
         Stopping := True;
      end Halt;

      function Count return Natural is
      begin
         return N;
      end Count;

      function Lost_N return Natural is (Lost);

   end Jobs;

   type Result_Kind is (Blocks_Only, With_Mesh, Far_Tile);   --  (what was asked for: each waits in a ring of its own)
   type Rings is array (Result_Kind) of Result_Ring;
   type Counts is array (Result_Kind) of Natural;

   protected Results is
      entry Put (Result_Kind) (R : Result_Access);   --  (waits while its ring is full)
      procedure Get (R : out Result_Access; Meshed : Result_Kind);
      procedure Halt;
   private
      Ring       : Rings := (others => (others => null));
      Head, Tail : Counts := (others => 0);
      N          : Counts := (others => 0);
      Stopping   : Boolean := False;
   end Results;

   protected body Results is

      entry Put (for K in Result_Kind) (R : Result_Access) when N (K) < Max_Results or else Stopping is
      begin
         if N (K) < Max_Results then
            Ring (K) (Tail (K)) := R;
            Tail (K) := (Tail (K) + 1) mod Max_Results;
            N (K) := N (K) + 1;
         end if;                               --  (stopping, and full: the program is ending)
      end Put;

      procedure Halt is
      begin
         Stopping := True;
      end Halt;

      procedure Get (R : out Result_Access; Meshed : Result_Kind) is
      begin
         if N (Meshed) = 0 then
            R := null;
         else
            R := Ring (Meshed) (Head (Meshed));
            Ring (Meshed) (Head (Meshed)) := null;
            Head (Meshed) := (Head (Meshed) + 1) mod Max_Results;
            N (Meshed) := N (Meshed) - 1;
         end if;
      end Get;

   end Results;

   task type Worker;
   type Worker_Access is access Worker;
   Pool : array (1 .. 64) of Worker_Access;

   task body Worker is
      Work : constant Stack_Work_Access := new Stack_Work;
      Far  : Castle.Lod.Scratch_Access;        --  (made when the first far tile is asked of this worker)
      J    : Job;
      Ok   : Boolean;
   begin
      loop
         Jobs.Take (J, Ok);
         exit when not Ok;
         if J.Level > 0 then
            declare
               use type Castle.Lod.Scratch_Access;
               T0 : constant Time := Clock;
               R  : constant Result_Access := new Result;
            begin
               if Far = null then
                  Far := new Castle.Lod.Scratch;
               end if;
               Castle.Lod.Build_Tile (The_World, J.Level, J.CX, J.CY, Work, Far.all, R.M, R.Edited);
               R.CX := J.CX;
               R.CY := J.CY;
               R.Level := J.Level;
               R.Millis := Float (To_Duration (Clock - T0)) * 1000.0;
               Results.Put (Far_Tile) (R);
            end;
         elsif not J.Mesh or else Wanted (J.CX, J.CY) then
            declare
               T0 : constant Time := Clock;
               R  : constant Result_Access := new Result;
            begin
               Generate (The_World, J.CX, J.CY, Work.all);
               declare
                  Rim : Castle.Edits.Rim_Access;
               begin
                  declare
                     Old_Skin : constant Skin_Grid := Work.Skin;
                  begin
                     Castle.Edits.Apply (J.CX, J.CY, Work, R.Gen, Rim);
                     Deepen (The_World, J.CX, J.CY, Work.all, Old_Skin);
                  end;
                  if J.View /= null then
                     Castle.Water.Apply (J.View.all, Work.all);
                  end if;
                  R.Summary := new Castle.Water.Ground_Summary;
                  Castle.Water.Summarize (Work.all, R.Summary.all);
                  R.Water_Ver := J.Water_Ver;
                  if Build_Meshes and then J.Mesh then
                     Build (The_World, J.CX, J.CY, Work.all, R.M, Rim, J.View);
                  end if;
                  R.Meshed := J.Mesh;
                  Castle.Edits.Free (Rim);
               end;
               R.Packed := new Castle.Chunks.Chunk_Stack;
               Pack (Work.all, R.Packed.all);
               R.CX := J.CX;
               R.CY := J.CY;
               R.Millis := Float (To_Duration (Clock - T0)) * 1000.0;
               Results.Put ((if J.Mesh then With_Mesh else Blocks_Only)) (R);
            end;
         end if;
         Castle.Water.Free (J.View);
      end loop;
   exception
      when E : others =>
         Put_Line (Standard_Error, "stream worker stopped: " & Exception_Information (E));
   end Worker;

   procedure Start (W : World; Workers : Positive) is
   begin
      The_World := W;
      for K in 1 .. Integer'Min (Workers, Pool'Last) loop
         Pool (K) := new Worker;
      end loop;
   end Start;

   procedure Request (CX, CY : Integer; Priority : Float;
                      View : Castle.Water.View_Access := null; Water_Ver : Natural := 0;
                      Mesh : Boolean := True) is
   begin
      Jobs.Put ((CX, CY, Priority, View, Water_Ver, Mesh, 0));
   end Request;

   procedure Request_Far (Level : Positive; TX, TY : Integer; Priority : Float) is
   begin
      Jobs.Put ((TX, TY, Priority, null, 0, True, Level));
   end Request_Far;

   procedure Poll_Far (R : out Result_Access) is
   begin
      Results.Get (R, Far_Tile);
   end Poll_Far;

   function Lost return Natural is (Jobs.Lost_N);

   procedure Poll (R : out Result_Access; Meshed : Boolean := True) is
   begin
      Results.Get (R, (if Meshed then With_Mesh else Blocks_Only));
   end Poll;

   function Queued return Natural is (Jobs.Count);

   procedure Stop is
   begin
      Jobs.Halt;
      Results.Halt;
   end Stop;

   procedure Free_R is new Ada.Unchecked_Deallocation (Result, Result_Access);

   procedure Free (R : in out Result_Access) is
   begin
      if R /= null then
         Free (R.M);
         Castle.Chunks.Free (R.Packed);
         Castle.Water.Free (R.Summary);
         Free_R (R);
      end if;
   end Free;

end Castle.Streaming;
