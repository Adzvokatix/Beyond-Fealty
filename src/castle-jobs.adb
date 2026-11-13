with Ada.Exceptions; use Ada.Exceptions;

package body Castle.Jobs is

   procedure Parallel_For (First, Last : Integer; Grain : Positive := 1) is

      protected Dispatcher is
         procedure Next (Lo, Hi : out Integer; Ok : out Boolean);
         procedure Fail (E : Exception_Occurrence);
         function Failure return Exception_Occurrence_Access;
      private
         Cursor : Integer := First;
         Error  : Exception_Occurrence_Access := null;
      end Dispatcher;

      protected body Dispatcher is

         procedure Next (Lo, Hi : out Integer; Ok : out Boolean) is
         begin
            if Cursor > Last or else Error /= null then
               Lo := 0;
               Hi := -1;
               Ok := False;
            else
               Lo     := Cursor;
               Hi     := (if Last - Cursor < Grain then Last else Cursor + Grain - 1);
               Cursor := Hi + 1;
               Ok     := True;
            end if;
         end Next;

         procedure Fail (E : Exception_Occurrence) is
         begin
            if Error = null then
               Error := Save_Occurrence (E);
            end if;
         end Fail;

         function Failure return Exception_Occurrence_Access is
         begin
            return Error;
         end Failure;

      end Dispatcher;

      task type Worker with Storage_Size => 16 * 1024 * 1024;

      task body Worker is
         Lo, Hi : Integer;
         Ok     : Boolean;
      begin
         loop
            Dispatcher.Next (Lo, Hi, Ok);
            exit when not Ok;
            for I in Lo .. Hi loop
               Process (I);
            end loop;
         end loop;
      exception
         when E : others =>
            Dispatcher.Fail (E);
      end Worker;

   begin
      if Last < First then
         return;
      end if;

      if Worker_Count = 1 then
         for I in First .. Last loop
            Process (I);
         end loop;
         return;
      end if;

      declare
         Blocks : constant Integer := (Last - First) / Grain + 1;
         Pool   : array (1 .. Integer'Min (Worker_Count, Blocks)) of Worker;
         pragma Unreferenced (Pool);
      begin
         null;   --  this block cannot be left until every Worker has terminated
      end;

      if Dispatcher.Failure /= null then
         Reraise_Occurrence (Dispatcher.Failure.all);
      end if;
   end Parallel_For;

end Castle.Jobs;
