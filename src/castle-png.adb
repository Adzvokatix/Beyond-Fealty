with Ada.Streams;           use Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Unchecked_Deallocation;
with Interfaces;            use Interfaces;

package body Castle.PNG is

   package SIO renames Ada.Streams.Stream_IO;

   type CRC_Table is array (Unsigned_32 range 0 .. 255) of Unsigned_32;

   function Make_Table return CRC_Table is
      T : CRC_Table;
      C : Unsigned_32;
   begin
      for N in T'Range loop
         C := N;
         for K in 1 .. 8 loop
            if (C and 1) /= 0 then
               C := 16#EDB8_8320# xor Shift_Right (C, 1);
            else
               C := Shift_Right (C, 1);
            end if;
         end loop;
         T (N) := C;
      end loop;
      return T;
   end Make_Table;

   Table : constant CRC_Table := Make_Table;

   Signature : constant array (1 .. 8) of Unsigned_8 := (137, 80, 78, 71, 13, 10, 26, 10);

   procedure Write (Path : String; Img : Image) is
      F             : SIO.File_Type;
      Buf           : Stream_Element_Array (1 .. 65_536);
      Fill          : Stream_Element_Offset := 0;
      Crc           : Unsigned_32 := 0;
      Width         : constant Natural := Img'Length (2);
      Height        : constant Natural := Img'Length (1);
      Raw_Len       : constant Unsigned_64 := Unsigned_64 (Height) * Unsigned_64 (1 + 3 * Width);
      Blocks        : constant Unsigned_64 := (Raw_Len + 65_534) / 65_535;
      Z_Len         : constant Unsigned_64 := 2 + Raw_Len + 5 * Blocks + 4;
      S1            : Unsigned_32 := 1;
      S2            : Unsigned_32 := 0;
      Left_In_Block : Natural := 0;
      Raw_Left      : Unsigned_64 := Raw_Len;

      procedure Flush is
      begin
         if Fill > 0 then
            SIO.Write (F, Buf (1 .. Fill));
            Fill := 0;
         end if;
      end Flush;

      procedure Emit (B : Unsigned_8) is
      begin
         if Fill = Buf'Last then
            Flush;
         end if;
         Fill       := Fill + 1;
         Buf (Fill) := Stream_Element (B);
         Crc        := Table ((Crc xor Unsigned_32 (B)) and 16#FF#) xor Shift_Right (Crc, 8);
      end Emit;

      procedure Emit_32 (V : Unsigned_32) is
      begin
         Emit (Unsigned_8 (Shift_Right (V, 24)));
         Emit (Unsigned_8 (Shift_Right (V, 16) and 16#FF#));
         Emit (Unsigned_8 (Shift_Right (V, 8) and 16#FF#));
         Emit (Unsigned_8 (V and 16#FF#));
      end Emit_32;

      procedure Begin_Chunk (Length : Unsigned_32; Kind : String) is
      begin
         Emit_32 (Length);
         Crc := 16#FFFF_FFFF#;
         for C of Kind loop
            Emit (Unsigned_8 (Character'Pos (C)));
         end loop;
      end Begin_Chunk;

      procedure End_Chunk is
         Final : constant Unsigned_32 := Crc xor 16#FFFF_FFFF#;
      begin
         Emit_32 (Final);
      end End_Chunk;

      procedure Raw (B : Unsigned_8) is
      begin
         if Left_In_Block = 0 then
            declare
               Len   : constant Natural := Natural (Unsigned_64'Min (65_535, Raw_Left));
               Final : constant Boolean := Unsigned_64 (Len) = Raw_Left;
            begin
               Emit ((if Final then 1 else 0));
               Emit (Unsigned_8 (Len mod 256));
               Emit (Unsigned_8 (Len / 256));
               Emit (Unsigned_8 ((65_535 - Len) mod 256));
               Emit (Unsigned_8 ((65_535 - Len) / 256));
               Left_In_Block := Len;
            end;
         end if;
         Emit (B);
         Left_In_Block := Left_In_Block - 1;
         Raw_Left      := Raw_Left - 1;
         S1 := (S1 + Unsigned_32 (B)) mod 65_521;
         S2 := (S2 + S1) mod 65_521;
      end Raw;

   begin
      SIO.Create (F, SIO.Out_File, Path);
      for B of Signature loop
         Emit (B);
      end loop;
      Begin_Chunk (13, "IHDR");
      Emit_32 (Unsigned_32 (Width));
      Emit_32 (Unsigned_32 (Height));
      Emit (8);   --  bit depth
      Emit (2);   --  colour type RGB
      Emit (0);
      Emit (0);
      Emit (0);
      End_Chunk;
      Begin_Chunk (Unsigned_32 (Z_Len), "IDAT");
      Emit (16#78#);
      Emit (16#01#);
      for R in Img'Range (1) loop
         Raw (0);   --  filter: none
         for C in Img'Range (2) loop
            Raw (Img (R, C).R);
            Raw (Img (R, C).G);
            Raw (Img (R, C).B);
         end loop;
      end loop;
      Emit_32 (Shift_Left (S2, 16) or S1);
      End_Chunk;
      Begin_Chunk (0, "IEND");
      End_Chunk;
      Flush;
      SIO.Close (F);
   end Write;

   procedure Free_Image is new Ada.Unchecked_Deallocation (Image, Image_Access);

   procedure Free (Img : in out Image_Access) is
   begin
      Free_Image (Img);
   end Free;

end Castle.PNG;
