with Ada.Text_IO;   use Ada.Text_IO;
with Ada.Real_Time; use Ada.Real_Time;
with Castle.Terrain;
with Castle.Geology;
with Castle.Deposits;
with Castle.Hydrology;
with Castle.Text;   use Castle.Text;

package body Castle.Worldgen is

   procedure Create (Seed : Castle.Hash.U64; W : out Castle.Maps.World; Report : Boolean := True) is
      T : Time := Clock;

      procedure Lap (Name : String) is
         Now : constant Time := Clock;
      begin
         if Report then
            Put_Line ("  " & Name & ": " & Img (Float (To_Duration (Now - T)), 2) & " s");
         end if;
         T := Now;
      end Lap;
   begin
      Castle.Maps.Allocate (W, Seed);
      Lap ("allocate fields");
      Castle.Terrain.Generate (W);
      Lap ("terrain (1 m heightmap)");
      Castle.Geology.Generate_Coarse (W);
      Lap ("geology fields");
      Castle.Hydrology.Generate (W, Report);
      Lap ("hydrology");
      Castle.Deposits.Generate (W);
      Castle.Deposits.Build_Index (W);
      Lap ("deposits");
      Castle.Geology.Generate_Aquifer (W);
      Lap ("aquifer field");
      if Report then
         Castle.Deposits.Report (W);
      end if;
   end Create;

end Castle.Worldgen;
