with Ada.Directories;
with Ada.Streams;            use Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Unchecked_Conversion;
with Ada.Unchecked_Deallocation;
with Interfaces;             use Interfaces;
with Interfaces.C;           use Interfaces.C;
with Interfaces.C.Strings;   use Interfaces.C.Strings;
with Castle.Blocks;          use Castle.Blocks;
with Castle.Edits;
with Castle.Water;
with Castle.Worldgen;

package body Castle.Saves is

   Magic   : constant String := "CASTLSV1";
   Format  : constant := 6;                  --  1: no water; 2: water; 3: and which of it flows; 4: lake levels
   --  5: the colony; 6: the level source water rests at
                                             --  (none now); 5: the colony

   type Bytes is array (Natural range <>) of Unsigned_8;
   type Bytes_Access is access Bytes;
   procedure Free is new Ada.Unchecked_Deallocation (Bytes, Bytes_Access);

   function F32_Bits is new Ada.Unchecked_Conversion (Float, Unsigned_32);
   function Bits_F32 is new Ada.Unchecked_Conversion (Unsigned_32, Float);
   function F64_Bits is new Ada.Unchecked_Conversion (Long_Float, Unsigned_64);
   function Bits_F64 is new Ada.Unchecked_Conversion (Unsigned_64, Long_Float);

   function C_Rename (Old_Name, New_Name : chars_ptr) return int
     with Import, Convention => C, External_Name => "rename";

   --  FNV-1a, 64 bits.
   function Checksum (B : Bytes; Last : Integer) return Unsigned_64 is
      H : Unsigned_64 := 14_695_981_039_346_656_037;
   begin
      for I in B'First .. Last loop
         H := (H xor Unsigned_64 (B (I))) * 1_099_511_628_211;
      end loop;
      return H;
   end Checksum;

   --  A growing little-endian byte buffer.
   type Writer is record
      Data : Bytes_Access := new Bytes (0 .. 65_535);
      Size : Natural := 0;
   end record;

   procedure Put (W : in out Writer; V : Unsigned_8) is
   begin
      if W.Size > W.Data'Last then
         declare
            Bigger : constant Bytes_Access := new Bytes (0 .. 2 * W.Data'Length - 1);
         begin
            Bigger (0 .. W.Size - 1) := W.Data (0 .. W.Size - 1);
            Free (W.Data);
            W.Data := Bigger;
         end;
      end if;
      W.Data (W.Size) := V;
      W.Size := W.Size + 1;
   end Put;

   procedure Put (W : in out Writer; V : Unsigned_64; Count : Positive) is
   begin
      for K in 0 .. Count - 1 loop
         Put (W, Unsigned_8 (Shift_Right (V, 8 * K) and 255));
      end loop;
   end Put;

   procedure Put_F32 (W : in out Writer; V : Float) is
   begin
      Put (W, Unsigned_64 (F32_Bits (V)), 4);
   end Put_F32;

   procedure Put_F64 (W : in out Writer; V : Long_Float) is
   begin
      Put (W, F64_Bits (V), 8);
   end Put_F64;

   type Reader is record
      Data    : Bytes_Access;
      Pos     : Natural := 0;
      Last    : Integer := -1;            --  last byte before the checksum
      Version : Natural := 0;             --  save format
   end record;

   Short : exception;

   function Get (R : in out Reader; Count : Positive) return Unsigned_64 is
      V : Unsigned_64 := 0;
   begin
      if R.Pos + Count - 1 > R.Last then
         raise Short;
      end if;
      for K in 0 .. Count - 1 loop
         V := V or Shift_Left (Unsigned_64 (R.Data (R.Pos + K)), 8 * K);
      end loop;
      R.Pos := R.Pos + Count;
      return V;
   end Get;

   function Get_F32 (R : in out Reader) return Float is (Bits_F32 (Unsigned_32 (Get (R, 4))));
   function Get_F64 (R : in out Reader) return Long_Float is (Bits_F64 (Get (R, 8)));

   ----------
   -- Save --
   ----------

   procedure Save (Path : String; S : Snapshot; Error : out Unbounded_String) is
      W     : Writer;
      Edits : Castle.Edits.Saved_Access := Castle.Edits.All_Edits;
   begin
      Error := Null_Unbounded_String;
      for C of Magic loop
         Put (W, Unsigned_8 (Character'Pos (C)));
      end loop;
      Put (W, Unsigned_64 (Format), 4);
      Put (W, Unsigned_64 (Castle.Worldgen.Generator_Version), 4);
      Put (W, Unsigned_64 (S.Seed), 8);
      Put_F64 (W, S.Clock);
      Put_F64 (W, S.Climate.T);
      for L in Castle.Climate.Level loop
         Put_F32 (W, S.Climate.Snow (L));
      end loop;
      Put_F32 (W, S.Climate.Ice);
      Put_F32 (W, S.Climate.Wet);
      Put_F32 (W, S.Cam_X);
      Put_F32 (W, S.Cam_Y);
      Put_F32 (W, S.Cam_Yaw);
      Put_F32 (W, S.Cam_Pitch);
      Put_F32 (W, S.Cam_Dist);
      Put (W, Unsigned_64 (Edits'Length), 8);
      for E of Edits.all loop
         Put (W, E.Key, 8);
         Put (W, Unsigned_8 (Material'Pos (E.B.Mat)));
         Put (W, E.B.State);
         Put (W, Unsigned_8 (if E.Brick then 1 else 0));
      end loop;
      Castle.Edits.Free (Edits);

      --  Water: every simulated stack, its stretches and their depths.
      declare
         Count : Natural := 0;
         procedure Count_One (CX, CY : Integer; Awake : Boolean; C : Castle.Water.Stack_Columns) is
            pragma Unreferenced (CX, CY, Awake, C);
         begin
            Count := Count + 1;
         end Count_One;
         procedure Put_One (CX, CY : Integer; Awake : Boolean; C : Castle.Water.Stack_Columns) is
         begin
            Put (W, Unsigned_64 (CX), 2);
            Put (W, Unsigned_64 (CY), 2);
            Put (W, Unsigned_8 (if Awake then 1 else 0));
            for X in C'Range (1) loop
               for Y in C'Range (2) loop
                  Put (W, Unsigned_8 (C (X, Y).N + (if C (X, Y).Flowing then 128 else 0)
                                      + (if C (X, Y).Touched then 64 else 0)));     --  64: format 6
                  if C (X, Y).Flowing then
                     Put (W, Unsigned_64 (C (X, Y).Rest), 4);     --  format 6
                  end if;
                  for I in 1 .. C (X, Y).N loop
                     Put (W, Unsigned_64 (C (X, Y).S (I).Floor), 2);
                     Put (W, Unsigned_64 (C (X, Y).S (I).Ceil), 2);
                     Put (W, Unsigned_64 (C (X, Y).S (I).Water), 4);
                  end loop;
               end loop;
            end loop;
         end Put_One;
      begin
         Castle.Water.Each_Stack (Count_One'Access);
         Put (W, Unsigned_64 (Count), 4);
         Castle.Water.Each_Stack (Put_One'Access);
      end;
      --  lake levels (format 4): lakes are locked sources now, none to keep
      Put (W, 0, 4);
      --  the colony (format 5)
      if S.Colony = null then
         Put (W, 0, 4);
      else
         Put (W, Unsigned_64 (S.Colony'Length), 4);
         for B of S.Colony.all loop
            Put (W, B);
         end loop;
      end if;
      Put (W, Checksum (W.Data.all, W.Size - 1), 8);

      declare
         use Ada.Streams.Stream_IO;
         Temp : constant String := Path & ".tmp";
         F    : File_Type;
         Dir  : constant String := Ada.Directories.Containing_Directory (Path);
      begin
         if Dir /= "" and then not Ada.Directories.Exists (Dir) then
            Ada.Directories.Create_Path (Dir);
         end if;
         Create (F, Out_File, Temp);
         declare
            Chunk : Stream_Element_Array (1 .. Stream_Element_Offset (W.Size));
         begin
            for I in 0 .. W.Size - 1 loop
               Chunk (Stream_Element_Offset (I + 1)) := Stream_Element (W.Data (I));
            end loop;
            Write (F, Chunk);
         end;
         Close (F);
         declare
            A : chars_ptr := New_String (Temp);
            B : chars_ptr := New_String (Path);
            R : constant int := C_Rename (A, B);
         begin
            Free (A);
            Free (B);
            if R /= 0 then
               Error := To_Unbounded_String ("could not move " & Temp & " into place");
            end if;
         end;
      exception
         when others =>
            Error := To_Unbounded_String ("could not write " & Temp);
      end;
      Free (W.Data);
   end Save;

   --  Read the whole file, check its frame and checksum.
   procedure Open (Path : String; R : out Reader; Error : out Unbounded_String) is
      use Ada.Streams.Stream_IO;
      F : File_Type;
   begin
      Error := Null_Unbounded_String;
      R := (Data => null, Pos => 0, Last => -1, Version => 0);
      if not Ada.Directories.Exists (Path) then
         Error := To_Unbounded_String ("no save at " & Path);
         return;
      end if;
      Open (F, In_File, Path);
      declare
         N     : constant Natural := Natural (Size (F));
         Chunk : Stream_Element_Array (1 .. Stream_Element_Offset (Natural'Max (1, N)));
         Got   : Stream_Element_Offset;
      begin
         Read (F, Chunk, Got);
         Close (F);
         if Natural (Got) /= N or else N < Magic'Length + 16 then
            Error := To_Unbounded_String (Path & " is too short to be a save");
            return;
         end if;
         R.Data := new Bytes (0 .. N - 1);
         for I in 0 .. N - 1 loop
            R.Data (I) := Unsigned_8 (Chunk (Stream_Element_Offset (I + 1)));
         end loop;
         R.Last := N - 9;
      end;
      for I in Magic'Range loop
         if R.Data (I - Magic'First) /= Unsigned_8 (Character'Pos (Magic (I))) then
            Error := To_Unbounded_String (Path & " is not a Castle save");
            return;
         end if;
      end loop;
      declare
         Stored : Unsigned_64 := 0;
      begin
         for K in 0 .. 7 loop
            Stored := Stored or Shift_Left (Unsigned_64 (R.Data (R.Last + 1 + K)), 8 * K);
         end loop;
         if Stored /= Checksum (R.Data.all, R.Last) then
            Error := To_Unbounded_String (Path & " is damaged (checksum does not match)");
            return;
         end if;
      end;
      R.Pos := Magic'Length;
      R.Version := Natural (Get (R, 4));
      if R.Version not in 1 .. Format then
         Error := To_Unbounded_String (Path & " is from another save format");
         return;
      end if;
      if Get (R, 4) /= Unsigned_64 (Castle.Worldgen.Generator_Version) then
         Error := To_Unbounded_String
           (Path & " was made by another version of the world generator; its edits would land on a different world");
         return;
      end if;
   exception
      when others =>
         Error := To_Unbounded_String ("could not read " & Path);
   end Open;

   procedure Peek (Path : String; Seed : out Castle.Hash.U64; Error : out Unbounded_String) is
      R : Reader;
   begin
      Seed := 1;
      Open (Path, R, Error);
      if Error = Null_Unbounded_String then
         Seed := Castle.Hash.U64 (Get (R, 8));
      end if;
      if R.Data /= null then
         Free (R.Data);
      end if;
   end Peek;

   procedure Load (Path : String; S : out Snapshot; Error : out Unbounded_String) is
      R : Reader;
   begin
      S := (others => <>);
      Open (Path, R, Error);
      if Error /= Null_Unbounded_String then
         if R.Data /= null then
            Free (R.Data);
         end if;
         return;
      end if;
      S.Seed := Castle.Hash.U64 (Get (R, 8));
      S.Clock := Get_F64 (R);
      S.Climate.T := Get_F64 (R);
      for L in Castle.Climate.Level loop
         S.Climate.Snow (L) := Get_F32 (R);
      end loop;
      S.Climate.Ice := Get_F32 (R);
      S.Climate.Wet := Get_F32 (R);
      S.Cam_X := Get_F32 (R);
      S.Cam_Y := Get_F32 (R);
      S.Cam_Yaw := Get_F32 (R);
      S.Cam_Pitch := Get_F32 (R);
      S.Cam_Dist := Get_F32 (R);
      declare
         N : constant Unsigned_64 := Get (R, 8);
         E : Castle.Edits.Saved_Access;
      begin
         if N > Unsigned_64 ((R.Last - R.Pos + 1) / 11) then
            raise Short;
         end if;
         E := new Castle.Edits.Saved_Array (1 .. Natural (N));
         for I in E'Range loop
            E (I).Key := Get (R, 8);
            declare
               M  : constant Unsigned_64 := Get (R, 1);
               St : constant Unsigned_64 := Get (R, 1);
               Kd : constant Unsigned_64 := Get (R, 1);
            begin
               if M > Unsigned_64 (Material'Pos (Material'Last)) or else Kd > 1 then
                  raise Short;
               end if;
               E (I).B := (Mat => Material'Val (Integer (M)), State => Unsigned_8 (St));
               E (I).Brick := Kd = 1;
            end;
         end loop;
         Castle.Edits.Restore (E.all);
         Castle.Edits.Free (E);
      end;
      Castle.Water.Reset;
      if R.Version >= 2 then
         declare
            Count : constant Unsigned_64 := Get (R, 4);
            C     : Castle.Water.Stack_Columns;
         begin
            for K in 1 .. Count loop
               declare
                  CX    : constant Integer := Integer (Get (R, 2));
                  CY    : constant Integer := Integer (Get (R, 2));
                  Awake : constant Boolean := Get (R, 1) = 1;
               begin
                  if CX > 255 or else CY > 255 then
                     raise Short;
                  end if;
                  for X in C'Range (1) loop
                     for Y in C'Range (2) loop
                        declare
                           B : constant Natural := Natural (Get (R, 1));
                        begin
                           C (X, Y).N := B mod 64;
                           C (X, Y).Flowing := B >= 128;
                           --  before format 6 nothing said which columns had
                           --  been dug or built in: all count as changed, so
                           --  what ran out when it was saved runs on
                           C (X, Y).Touched := (if R.Version >= 6 then B / 64 mod 2 = 1 else True);
                        end;
                        if C (X, Y).N > Castle.Water.Max_Stretch then
                           raise Short;
                        end if;
                        C (X, Y).Rest := (if C (X, Y).Flowing and then R.Version >= 6 then Integer (Get (R, 4)) else 0);
                        for I in 1 .. C (X, Y).N loop
                           C (X, Y).S (I).Floor := Integer (Get (R, 2));
                           C (X, Y).S (I).Ceil := Integer (Get (R, 2));
                           C (X, Y).S (I).Water := Integer (Get (R, 4));
                        end loop;
                        --  before format 6 source water was held where it
                        --  lay: that is its level
                        if C (X, Y).Flowing and then R.Version < 6 and then C (X, Y).N >= 1
                          and then C (X, Y).S (1).Water > 0
                        then
                           C (X, Y).Rest := C (X, Y).S (1).Floor * Castle.Water.Unit + C (X, Y).S (1).Water;
                        end if;
                     end loop;
                  end loop;
                  Castle.Water.Restore (CX, CY, Awake, C);
               end;
            end loop;
         end;
         if R.Version >= 4 then
            --  lake levels, from when lakes could drain: read past them
            declare
               Low : constant Natural := Natural (Get (R, 4));
            begin
               for K in 1 .. Low loop
                  declare
                     Id    : constant Unsigned_64 := Get (R, 2) with Unreferenced;
                     Level : constant Unsigned_64 := Get (R, 4) with Unreferenced;
                  begin
                     null;
                  end;
               end loop;
            end;
         end if;
         if R.Version >= 5 then
            declare
               N : constant Natural := Natural (Get (R, 4));
            begin
               if N > 0 then
                  S.Colony := new Blob (0 .. N - 1);
                  for K in 0 .. N - 1 loop
                     S.Colony (K) := Unsigned_8 (Get (R, 1));
                  end loop;
               end if;
            end;
         end if;
      end if;
      Free (R.Data);
   exception
      when Short =>
         Error := To_Unbounded_String (Path & " is damaged (truncated)");
         if R.Data /= null then
            Free (R.Data);
         end if;
   end Load;

end Castle.Saves;
