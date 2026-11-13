with Ada.Exceptions;  use Ada.Exceptions;
with Ada.Real_Time;   use Ada.Real_Time;
with Ada.Text_IO;     use Ada.Text_IO;
with Ada.Unchecked_Deallocation;
with Castle.Chunks;   use Castle.Chunks;
with Castle.Edits;

package body Castle.Streaming is

   use type Castle.Water.View_Access;

   type Job is record
      CX, CY    : Integer := 0;
      Priority  : Float := 0.0;
      View      : Castle.Water.View_Access;
      Water_Ver : Natural := 0;
   end record;

   Max_Jobs    : constant := 32_768;
   Max_Results : constant := 8_192;

   type Job_Heap is array (1 .. Max_Jobs) of Job;
   type Result_Ring is array (0 .. Max_Results - 1) of Result_Access;

   The_World : World;

   protected Jobs is
      entry Take (J : out Job; Ok : out Boolean);
      procedure Put (J : Job);
      procedure Halt;
      function Count return Natural;
   private
      Heap     : Job_Heap;
      N        : Natural := 0;
      Stopping : Boolean := False;
   end Jobs;

   protected body Jobs is

      entry Take (J : out Job; Ok : out Boolean) when N > 0 or else Stopping is
         Last  : Job;
         I     : Positive := 1;
         Child : Positive;
      begin
         if Stopping then
            J := (0, 0, 0.0, null, 0);
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
            return;                                --  cannot happen at sane view ranges
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

   end Jobs;

   protected Results is
      procedure Put (R : Result_Access);
      procedure Get (R : out Result_Access);
   private
      Ring       : Result_Ring := (others => null);
      Head, Tail : Natural := 0;
      N          : Natural := 0;
   end Results;

   protected body Results is

      procedure Put (R : Result_Access) is
      begin
         if N < Max_Results then
            Ring (Tail) := R;
            Tail := (Tail + 1) mod Max_Results;
            N := N + 1;
         end if;
      end Put;

      procedure Get (R : out Result_Access) is
      begin
         if N = 0 then
            R := null;
         else
            R := Ring (Head);
            Ring (Head) := null;
            Head := (Head + 1) mod Max_Results;
            N := N - 1;
         end if;
      end Get;

   end Results;

   task type Worker;
   type Worker_Access is access Worker;
   Pool : array (1 .. 64) of Worker_Access;

   task body Worker is
      Work : constant Stack_Work_Access := new Stack_Work;
      J    : Job;
      Ok   : Boolean;
   begin
      loop
         Jobs.Take (J, Ok);
         exit when not Ok;
         if Wanted (J.CX, J.CY) then
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
                  Build (The_World, J.CX, J.CY, Work.all, R.M, Rim, J.View);
                  Castle.Edits.Free (Rim);
               end;
               R.Packed := new Castle.Chunks.Chunk_Stack;
               Pack (Work.all, R.Packed.all);
               R.CX := J.CX;
               R.CY := J.CY;
               R.Millis := Float (To_Duration (Clock - T0)) * 1000.0;
               Results.Put (R);
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
                      View : Castle.Water.View_Access := null; Water_Ver : Natural := 0) is
   begin
      Jobs.Put ((CX, CY, Priority, View, Water_Ver));
   end Request;

   procedure Poll (R : out Result_Access) is
   begin
      Results.Get (R);
   end Poll;

   function Queued return Natural is (Jobs.Count);

   procedure Stop is
   begin
      Jobs.Halt;
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
