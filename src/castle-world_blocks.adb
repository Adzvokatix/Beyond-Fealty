with Ada.Unchecked_Deallocation;
with Interfaces;
with Castle.Dims;  use Castle.Dims;
with Castle.Edits;

package body Castle.World_Blocks is

   use type Castle.Chunks.Chunk_Stack_Access;
   use type Castle.Water.Summary_Access;
   use type Castle.Water.Small_Access;
   use type Interfaces.Unsigned_32;

   --  What a stack remembers of its edits since it was last kept: which of
   --  its columns were edited (a bit each: only those are looked up in the
   --  edit store), and the last Max_Changed of them with the version each
   --  gave the stack (Changes_Since).  Made when the first edit comes.
   type Column_Bits is array (0 .. Chunk_B - 1) of Interfaces.Unsigned_32;
   type Logged is record
      X, Y    : Interfaces.Unsigned_8 := 0;
      Version : Natural := 0;
   end record;
   type Log_Ring is array (0 .. Max_Changed - 1) of Logged;
   type Edit_Notes is record
      Edited : Column_Bits := [others => 0];
      Log    : Log_Ring;
      Log_N  : Natural := 0;             --  entries ever written; the ring holds the last Max_Changed
      Lost_V : Natural := 0;             --  the version of the newest entry the ring has let go
   end record;
   type Notes_Access is access Edit_Notes;
   procedure Free is new Ada.Unchecked_Deallocation (Edit_Notes, Notes_Access);

   type Kept_Stack is record
      S       : Castle.Chunks.Chunk_Stack_Access;
      Sum     : Castle.Water.Summary_Access;   --  its ground summary: whole (Small_Summaries off),
      Small   : Castle.Water.Small_Access;     --  or kept small; one of the two while it is loaded
      Dirty   : Boolean := False;        --  edited since S was built
      All_Cols : Boolean := False;       --  ... and it is not known where: every column asks the edit store
      Version : Natural := 0;            --  stamped from Changes whenever its ground changes
      Whole_V : Natural := 0;            --  the version it had when it was last kept or dropped
      Notes   : Notes_Access;
   end record;
   type Kept_Grid is array (0 .. Chunks_XY - 1, 0 .. Chunks_XY - 1) of Kept_Stack;
   type Kept_Access is access Kept_Grid;
   Cache : constant Kept_Access := new Kept_Grid;
   Changes : Natural := 0;
   By_Edit, By_Stack : Natural := 0;

   procedure Stamp (E : in out Kept_Stack) is
   begin
      Changes := Changes + 1;
      E.Version := Changes;
   end Stamp;

   function Stamps_By_Edit return Natural is (By_Edit);
   function Stamps_By_Stack return Natural is (By_Stack);

   --  The stack's ground is known: it is loaded.  (The one test of it.)
   function Has_Ground (E : Kept_Stack) return Boolean is (E.Sum /= null or else E.Small /= null);

   --  A column of a loaded stack's summary, read and written, whichever way
   --  the summary is kept.
   function Column_At (E : Kept_Stack; X, Y : Integer) return Castle.Water.Short_Column is
     (if E.Small /= null then Castle.Water.Column_Of (E.Small.all, X, Y) else E.Sum (X, Y));

   Repacks : Natural := 0;
   function Summary_Repacks return Natural is (Repacks);

   procedure Put_Column (E : in out Kept_Stack; X, Y : Integer; C : Castle.Water.Short_Column) is
   begin
      if E.Small = null then
         E.Sum (X, Y) := C;
         return;
      end if;
      declare
         Again : Boolean;
         --  (assertions on: what the summary must be after, worked out whole)
         Want : Castle.Water.Summary_Access;
         procedure Before is
         begin
            Want := new Castle.Water.Ground_Summary;
            Castle.Water.Expand (E.Small.all, Want.all);
            Want (X, Y) := C;
         end Before;
         procedure After is
            Got : Castle.Water.Summary_Access := new Castle.Water.Ground_Summary;
            Same : Boolean;
            use type Castle.Water.Ground_Summary;
         begin
            Castle.Water.Expand (E.Small.all, Got.all);
            Same := Got.all = Want.all;
            Castle.Water.Free (Got);
            Castle.Water.Free (Want);
            if not Same then
               raise Program_Error with "Castle.World_Blocks: a column written into a small summary"
                 & X'Image & Y'Image & " left it other than the whole summary with that column written";
            end if;
         end After;
      begin
         pragma Debug (Before);
         Castle.Water.Set_Column (E.Small, X, Y, C, Again);
         pragma Debug (After);
         if Again then
            Repacks := Repacks + 1;
         end if;
      end;
   end Put_Column;

   function Ground_Version (CX, CY : Integer) return Natural is
     (if CX in Cache'Range (1) and then CY in Cache'Range (2) and then Has_Ground (Cache (CX, CY))
      then Cache (CX, CY).Version else 0);

   Whole : constant Castle.Water.Summary_Access := new Castle.Water.Ground_Summary;
   --  (Summary_Of's buffer for a small summary unpacked)

   function Summary_Of (CX, CY : Integer) return Castle.Water.Summary_Access is
   begin
      if CX not in Cache'Range (1) or else CY not in Cache'Range (2) then
         return null;
      elsif Cache (CX, CY).Small /= null then
         Castle.Water.Expand (Cache (CX, CY).Small.all, Whole.all);
         return Whole;
      else
         return Cache (CX, CY).Sum;
      end if;
   end Summary_Of;

   --  (assertions on: a summary kept small unpacks to the summary it was made from)
   procedure Check_Small (Small : Castle.Water.Small_Summary; Full : Castle.Water.Ground_Summary; CX, CY : Integer) is
      Back : Castle.Water.Summary_Access := new Castle.Water.Ground_Summary;
      Same : Boolean;
      use type Castle.Water.Ground_Summary;
   begin
      Castle.Water.Expand (Small, Back.all);
      Same := Back.all = Full;
      Castle.Water.Free (Back);
      if not Same then
         raise Program_Error with "Castle.World_Blocks: stack" & CX'Image & CY'Image
           & " kept small does not unpack to its summary";
      end if;
   end Check_Small;

   procedure Keep (CX, CY : Integer; S : in out Castle.Chunks.Chunk_Stack_Access; Gen : Natural;
                   Summary : in out Castle.Water.Summary_Access) is
      E : Kept_Stack renames Cache (CX, CY);
   begin
      Castle.Chunks.Free (E.S);
      Castle.Water.Free (E.Sum);
      Castle.Water.Free (E.Small);
      if Small_Summaries then
         E.Small := Castle.Water.Shrink (Summary.all);
         pragma Debug (Check_Small (E.Small.all, Summary.all, CX, CY));
         Castle.Water.Free (Summary);
      else
         E.Sum := Summary;
         Summary := null;
      end if;
      E.S := S;
      E.Dirty := Gen /= Castle.Edits.Generation (CX, CY);
      E.All_Cols := E.Dirty;             --  (edited while it was being built: where is not known)
      Free (E.Notes);
      S := null;
      Stamp (E);
      E.Whole_V := E.Version;
      By_Stack := By_Stack + 1;
   end Keep;

   procedure Drop (CX, CY : Integer) is
   begin
      Castle.Chunks.Free (Cache (CX, CY).S);
      Castle.Water.Free (Cache (CX, CY).Sum);
      Castle.Water.Free (Cache (CX, CY).Small);
      Cache (CX, CY).Dirty := False;
      Cache (CX, CY).All_Cols := False;
      Free (Cache (CX, CY).Notes);
      Stamp (Cache (CX, CY));
      Cache (CX, CY).Whole_V := Cache (CX, CY).Version;
      By_Stack := By_Stack + 1;
   end Drop;

   procedure Note_Edit (Bx, By : Integer) is
   begin
      for Dx in -1 .. 1 loop
         for Dy in -1 .. 1 loop
            declare
               CX : constant Integer := (Bx + Dx) / Chunk_B;
               CY : constant Integer := (By + Dy) / Chunk_B;
            begin
               if Bx + Dx >= 0 and then By + Dy >= 0 and then CX in Kept_Grid'Range (1)
                 and then CY in Kept_Grid'Range (2)
               then
                  Cache (CX, CY).Dirty := True;
                  if Dx = 0 and then Dy = 0 then         --  the column's own stack: this column of it
                     if Cache (CX, CY).Notes = null then
                        Cache (CX, CY).Notes := new Edit_Notes;
                     end if;
                     declare
                        Row : Interfaces.Unsigned_32 renames Cache (CX, CY).Notes.Edited (By mod Chunk_B);
                     begin
                        Row := Row or Interfaces.Shift_Left (Interfaces.Unsigned_32'(1), Bx mod Chunk_B);
                     end;
                  end if;
               end if;
            end;
         end loop;
      end loop;
   end Note_Edit;

   procedure Note_All_Edited is
   begin
      for E of Cache.all loop
         E.Dirty := True;
         E.All_Cols := True;
      end loop;
   end Note_All_Edited;

   function Block_At (Bx, By, Bz : Integer) return Block is
   begin
      if Bx < 0 or else By < 0 or else Bx >= Size_B or else By >= Size_B
        or else Bz < 0 or else Bz >= Height_B
      then
         return Air_Block;
      end if;
      declare
         E : Kept_Stack renames Cache (Bx / Chunk_B, By / Chunk_B);
         B : Block;
      begin
         if E.S = null then
            return Air_Block;
         end if;
         --  (the edit store is asked only about a column that was edited)
         if E.Dirty
           and then (E.All_Cols
                     or else (E.Notes /= null
                              and then (E.Notes.Edited (By mod Chunk_B)
                                        and Interfaces.Shift_Left (Interfaces.Unsigned_32'(1), Bx mod Chunk_B)) /= 0))
           and then Castle.Edits.Find (Bx, By, Bz, B)
         then
            return B;
         end if;
         return Castle.Chunks.Block_In (E.S.all, Bx mod Chunk_B, By mod Chunk_B, Bz);
      end;
   end Block_At;

   procedure Ground (Bx, By : Integer; C : out Castle.Water.Column; Known : out Boolean) is
   begin
      C := (N => 0, S => (others => (0, 0, 0)), others => <>);
      Known := False;
      if Bx in 0 .. Size_B - 1 and then By in 0 .. Size_B - 1 then
         declare
            E : Kept_Stack renames Cache (Bx / Chunk_B, By / Chunk_B);
         begin
            if Has_Ground (E) then
               C := Castle.Water.To_Column (Column_At (E, Bx mod Chunk_B, By mod Chunk_B));
               Known := True;
            end if;
         end;
      end if;
   end Ground;

   procedure Reground (Bx, By, Z_Lo, Z_Hi : Integer) is
   begin
      if Bx not in 0 .. Size_B - 1 or else By not in 0 .. Size_B - 1 then
         return;
      end if;
      declare
         E : Kept_Stack renames Cache (Bx / Chunk_B, By / Chunk_B);
      begin
         if not Has_Ground (E) then
            return;
         end if;
         declare
            Old : constant Castle.Water.Column :=
              Castle.Water.To_Column (Column_At (E, Bx mod Chunk_B, By mod Chunk_B));
            function Solid_Z (Z : Integer) return Boolean is (Class_Of (Block_At (Bx, By, Z).Mat) = Solid);
            function Wet_Z (Z : Integer) return Boolean is (Block_At (Bx, By, Z).Mat = Castle.Blocks.Water);
            procedure Scan_Here is new Castle.Water.Scan (Solid_Z, Wet_Z);
            --  above the old top stretch's floor all was open, but what the
            --  edit put there; below the lowest stretch and the edit, solid
            Top : constant Integer :=
              Integer'Min (Height_B - 1, Integer'Max ((if Old.N > 0 then Old.S (1).Floor - 1 else 0), Z_Hi));
            Low : Integer := Z_Lo;
            C   : Castle.Water.Column;
         begin
            for I in 1 .. Old.N loop
               Low := Integer'Min (Low, Old.S (I).Floor);
            end loop;
            Scan_Here (Top, Integer'Max (0, Low - 1), C);
            C.Flowing := Old.Flowing;
            C.Rest := Old.Rest;
            Put_Column (E, Bx mod Chunk_B, By mod Chunk_B, Castle.Water.To_Short (C));
            Stamp (E);
            By_Edit := By_Edit + 1;
            if E.Notes = null then
               E.Notes := new Edit_Notes;
            end if;
            if E.Notes.Log_N >= Max_Changed then
               E.Notes.Lost_V := E.Notes.Log (E.Notes.Log_N mod Max_Changed).Version;
            end if;
            E.Notes.Log (E.Notes.Log_N mod Max_Changed) :=
              (Interfaces.Unsigned_8 (Bx mod Chunk_B), Interfaces.Unsigned_8 (By mod Chunk_B), E.Version);
            E.Notes.Log_N := E.Notes.Log_N + 1;
         end;
      end;
   end Reground;

   procedure Changes_Since (CX, CY : Integer; Since : Natural; N : out Natural; Cols : out Changed_List;
                            All_Of_It : out Boolean) is
   begin
      N := 0;
      Cols := [others => (0, 0)];
      All_Of_It := True;
      if CX not in Cache'Range (1) or else CY not in Cache'Range (2) then
         return;
      end if;
      declare
         E : Kept_Stack renames Cache (CX, CY);
      begin
         --  kept anew or dropped since, or never seen at that version
         if not Has_Ground (E) or else Since < E.Whole_V or else Since > E.Version then
            return;
         end if;
         if Since = E.Version then
            All_Of_It := False;
            return;
         end if;
         if E.Notes = null then
            return;                      --  (it moved, and nothing says where: cannot be)
         end if;
         declare
            Nt    : Edit_Notes renames E.Notes.all;
            First : constant Natural := (if Nt.Log_N > Max_Changed then Nt.Log_N - Max_Changed else 0);
         begin
            --  (every stamp since it was kept is one of the logged edits, and
            --  the ring has the last of them: all that came after Since are
            --  in it unless one it has let go was later than Since)
            if Nt.Lost_V > Since then
               return;
            end if;
            for K in First .. Nt.Log_N - 1 loop
               declare
                  L : Logged renames Nt.Log (K mod Max_Changed);
               begin
                  if L.Version > Since then
                     N := N + 1;
                     Cols (N) := (CX * Chunk_B + Integer (L.X), CY * Chunk_B + Integer (L.Y));
                  end if;
               end;
            end loop;
            All_Of_It := False;
         end;
      end;
   end Changes_Since;

   function Stops_Ray (X, Y, Z : Integer) return Boolean is (Castle.Rays.Stops (Block_At (X, Y, Z).Mat, X, Y, Z));
   function Walk_Blocks is new Castle.Rays.Walk (Stops_Ray);

   function Cast (From, Dir : Vec3; Max_M : Float) return Hit is (Walk_Blocks (From, Dir, Max_M));

   function Sizes return Kept_Sizes is
      use type Interfaces.Integer_16;
      use type Interfaces.Integer_32;
      use type Interfaces.Unsigned_8;
      type Per_Array is array (Positive range <>) of Natural;
      type Per_Access is access Per_Array;
      procedure Free_Per is new Ada.Unchecked_Deallocation (Per_Array, Per_Access);
      Per : Per_Access := new Per_Array (1 .. Chunks_XY * Chunks_XY);
      R   : Kept_Sizes;
      procedure Sort (A : in out Per_Array) is
         procedure Sift (Root, Last : Positive) is
            At_R : Positive := Root;
         begin
            loop
               declare
                  C : Positive := 2 * At_R;
                  T : Natural;
               begin
                  exit when C > Last;
                  if C < Last and then A (C + 1) > A (C) then
                     C := C + 1;
                  end if;
                  exit when A (At_R) >= A (C);
                  T := A (At_R);
                  A (At_R) := A (C);
                  A (C) := T;
                  At_R := C;
               end;
            end loop;
         end Sift;
         T : Natural;
      begin
         for I in reverse 1 .. A'Last / 2 loop
            Sift (I, A'Last);
         end loop;
         for I in reverse 2 .. A'Last loop
            T := A (1);
            A (1) := A (I);
            A (I) := T;
            Sift (1, I - 1);
         end loop;
      end Sort;
   begin
      for CX in Cache'Range (1) loop
         for CY in Cache'Range (2) loop
            declare
               E : Kept_Stack renames Cache (CX, CY);
            begin
               if E.S /= null then
                  declare
                     Z : constant Castle.Chunks.Stack_Sizes := Castle.Chunks.Sizes_Of (E.S.all);
                     Mine : constant Natural := Z.Bytes_Array + Z.Bytes_Grids + Z.Bytes_Fine;
                  begin
                     R.Stacks := R.Stacks + 1;
                     R.Arrays := R.Arrays + Long_Integer (Z.Bytes_Array);
                     R.Grids := R.Grids + Long_Integer (Z.Bytes_Grids);
                     R.Fine := R.Fine + Long_Integer (Z.Bytes_Fine);
                     R.Allocations := R.Allocations + Long_Integer (Z.Allocations);
                     R.Chunks_Fine := R.Chunks_Fine + Long_Integer (Z.Chunks_Fine);
                     for K in Z.Fine'Range loop
                        R.Fine_By (K) := R.Fine_By (K) + Long_Integer (Z.Fine (K));
                        R.Fine_Bytes_By (K) := R.Fine_Bytes_By (K) + Long_Integer (Z.Fine_Bytes (K));
                     end loop;
                     Per (R.Stacks) := Mine;
                     if Mine > R.Most then
                        R.Most := Mine;
                        R.Heaviest_CX := CX;
                        R.Heaviest_CY := CY;
                     end if;
                  end;
                  R.Records := R.Records + Kept_Stack'Object_Size / 8;
                  if E.Notes /= null then
                     R.Notes := R.Notes + Edit_Notes'Object_Size / 8;
                     R.Allocations := R.Allocations + 1;
                  end if;
                  if Has_Ground (E) then
                     R.Summaries := R.Summaries
                       + (if E.Small /= null then Long_Integer (Castle.Water.Bytes_Of (E.Small.all))
                          else Castle.Water.Ground_Summary'Object_Size / 8);
                     R.Allocations := R.Allocations + 1;
                     for X in 0 .. Chunk_B - 1 loop
                        for Y in 0 .. Chunk_B - 1 loop
                           declare
                              C : constant Castle.Water.Short_Column := Column_At (E, X, Y);
                              Wet : Boolean := False;
                           begin
                              R.Columns (Integer (C.N)) := R.Columns (Integer (C.N)) + 1;
                              for S in 1 .. Integer (C.N) loop
                                 Wet := Wet or else C.S (S).Water > 0;
                              end loop;
                              if Wet then
                                 R.Columns_Wet := R.Columns_Wet + 1;
                              end if;
                              if C.N = 1 and then Integer (C.S (1).Ceil) = Height_B and then not Wet
                                and then not C.Flowing and then C.Rest = 0
                              then
                                 R.Columns_Plain := R.Columns_Plain + 1;
                              end if;
                           end;
                        end loop;
                     end loop;
                  end if;
               end if;
            end;
         end loop;
      end loop;
      if R.Stacks > 0 then
         Sort (Per (1 .. R.Stacks));
         R.Least := Per (1);
         R.Tenth := Per (Integer'Max (1, R.Stacks / 10));
         R.Median := Per (Integer'Max (1, R.Stacks / 2));
         R.Ninetieth := Per (Integer'Max (1, R.Stacks * 9 / 10));
      end if;
      Free_Per (Per);
      return R;
   end Sizes;

end Castle.World_Blocks;
