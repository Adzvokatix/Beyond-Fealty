with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;
with Castle.Text;

package body Castle.Settings is

   Max_Lines : constant := 64;
   type Entry_Rec is record
      Name, Value : Unbounded_String;
   end record;
   Lines : array (1 .. Max_Lines) of Entry_Rec;
   N     : Natural := 0;

   function Find (Name : String) return Natural is
   begin
      for I in 1 .. N loop
         if To_String (Lines (I).Name) = Name then
            return I;
         end if;
      end loop;
      return 0;
   end Find;

   procedure Put (Name, Value : String) is
      I : Natural := Find (Name);
   begin
      if I = 0 and then N < Max_Lines then
         N := N + 1;
         I := N;
      end if;
      if I > 0 then
         Lines (I) := (To_Unbounded_String (Name), To_Unbounded_String (Value));
      end if;
   end Put;

   procedure Load (Path : String) is
      use Ada.Text_IO;
      F : File_Type;
   begin
      N := 0;
      if not Ada.Directories.Exists (Path) then
         return;
      end if;
      Open (F, In_File, Path);
      while not End_Of_File (F) loop
         declare
            L : constant String := Ada.Strings.Fixed.Trim (Get_Line (F), Ada.Strings.Both);
            S : constant Natural := Ada.Strings.Fixed.Index (L, " ");
         begin
            if L'Length > 0 then
               if S = 0 then
                  Put (L, "");
               else
                  Put (L (L'First .. S - 1), Ada.Strings.Fixed.Trim (L (S .. L'Last), Ada.Strings.Both));
               end if;
            end if;
         end;
      end loop;
      Close (F);
   exception
      when others =>             --  a file that can't be read sets nothing more
         if Is_Open (F) then
            Close (F);
         end if;
   end Load;

   function Has (Name : String) return Boolean is (Find (Name) > 0);

   function Get (Name : String; Default : Float) return Float is
      I : constant Natural := Find (Name);
   begin
      if I = 0 then
         return Default;
      end if;
      return Float'Value (To_String (Lines (I).Value));
   exception
      when Constraint_Error =>
         return Default;
   end Get;

   procedure Set (Name : String; Value : Float) is
   begin
      Put (Name, Castle.Text.Img (Value, 2));
   end Set;

   procedure Save (Path : String; Ok : out Boolean) is
      use Ada.Text_IO;
      F   : File_Type;
      Dir : constant String := Ada.Directories.Containing_Directory (Path);
   begin
      Ok := False;
      if Dir /= "" and then not Ada.Directories.Exists (Dir) then
         Ada.Directories.Create_Path (Dir);
      end if;
      Create (F, Out_File, Path);
      for I in 1 .. N loop
         Put_Line (F, To_String (Lines (I).Name)
                   & (if Length (Lines (I).Value) > 0 then " " & To_String (Lines (I).Value) else ""));
      end loop;
      Close (F);
      Ok := True;
   exception
      when others =>
         if Is_Open (F) then
            Close (F);
         end if;
   end Save;

end Castle.Settings;
