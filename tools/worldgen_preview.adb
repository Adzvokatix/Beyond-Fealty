with Ada.Command_Line;      use Ada.Command_Line;
with Ada.Text_IO;           use Ada.Text_IO;
with Ada.Directories;
with Ada.Real_Time;         use Ada.Real_Time;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Castle.Hash;
with Castle.Jobs;
with Castle.Maps;
with Castle.Preview;
with Castle.Text;           use Castle.Text;
with Castle.Worldgen;

--  worldgen_preview [--seed N] [--out DIR] [--workers N] [--samples N] [--no-maps]
procedure Worldgen_Preview is
   Seed    : Castle.Hash.U64  := 1;
   Dir     : Unbounded_String := To_Unbounded_String ("preview");
   Samples : Positive         := 256;
   Maps_On : Boolean          := True;
   W       : Castle.Maps.World;
   Arg     : Positive         := 1;
begin
   while Arg <= Argument_Count loop
      declare
         A     : constant String  := Argument (Arg);
         Value : constant Boolean := Arg < Argument_Count;
      begin
         if A = "--seed" and then Value then
            Seed := Castle.Hash.U64'Value (Argument (Arg + 1));
            Arg  := Arg + 2;
         elsif A = "--out" and then Value then
            Dir := To_Unbounded_String (Argument (Arg + 1));
            Arg := Arg + 2;
         elsif A = "--workers" and then Value then
            Castle.Jobs.Worker_Count := Positive'Value (Argument (Arg + 1));
            Arg := Arg + 2;
         elsif A = "--samples" and then Value then
            Samples := Positive'Value (Argument (Arg + 1));
            Arg     := Arg + 2;
         elsif A = "--no-maps" then
            Maps_On := False;
            Arg     := Arg + 1;
         else
            Put_Line ("usage: worldgen_preview [--seed N] [--out DIR] [--workers N]"
                      & " [--samples N] [--no-maps]");
            return;
         end if;
      end;
   end loop;

   if not Ada.Directories.Exists (To_String (Dir)) then
      Ada.Directories.Create_Path (To_String (Dir));
   end if;

   Put_Line ("Castle worldgen v" & Img (Integer (Castle.Worldgen.Generator_Version))
             & ", seed" & Castle.Hash.U64'Image (Seed) & ", "
             & Img (Castle.Jobs.Worker_Count) & " worker(s)");
   Castle.Worldgen.Create (Seed, W);

   if Maps_On then
      declare
         T : Time := Clock;

         procedure Lap (Name : String) is
            Now : constant Time := Clock;
         begin
            Put_Line ("  " & Name & ": " & Img (Float (To_Duration (Now - T)), 2) & " s");
            T := Now;
         end Lap;
      begin
         Castle.Preview.Terrain_Map (W, To_String (Dir) & "/terrain.png");
         Lap ("terrain.png");
         Castle.Preview.Zoom_Map (W, To_String (Dir) & "/outcrops.png");
         Lap ("outcrops.png");
         Castle.Preview.Aquifer_Map (W, To_String (Dir) & "/aquifer.png");
         Lap ("aquifer.png");
         Castle.Preview.Resource_Map (W, To_String (Dir) & "/resources.png");
         Lap ("resources.png");
         Castle.Preview.Sections (W, To_String (Dir) & "/sections.png");
         Lap ("sections.png");
      end;
   end if;

   Castle.Preview.Survey (W, Samples);
end Worldgen_Preview;
