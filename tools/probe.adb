with Ada.Command_Line; use Ada.Command_Line;
with Ada.Text_IO;      use Ada.Text_IO;
with Castle.Blocks;    use Castle.Blocks;
with Castle.Deposits;
with Castle.Fields;    use Castle.Fields;
with Castle.Geology;   use Castle.Geology;
with Castle.Maps;      use Castle.Maps;
with Castle.Text;      use Castle.Text;
with Castle.Worldgen;

--  probe X Y ... : what the generator put at metre positions (X, Y).
procedure Probe is
   W : World;
begin
   Castle.Worldgen.Create (1, W, Report => False);
   for A in 1 .. Argument_Count / 2 loop
      declare
         X : constant Integer := Integer'Value (Argument (2 * A - 1));
         Y : constant Integer := Integer'Value (Argument (2 * A));
         C : constant Column  := Prepare_Column (W, X * 4 + 2, Y * 4 + 2);
         K : constant Cell_Range := Idx (X, Y);
      begin
         Put_Line ("(" & Img (X) & "," & Img (Y) & ") h=" & Img (W.Height (K), 2)
                   & " water=" & Img (W.Water (K), 2) & " kind=" & Water_Kind'Image (W.Kind (K))
                   & " moist=" & Img (W.Moisture (K), 2) & " slope=" & Img (W.Slope (K), 3)
                   & " mtn=" & Img (W.Mountain (K), 2));
         Put_Line ("   solid=" & Img (C.Solid) & " soil=" & Img (C.Soil) & " top=" & Material'Image (C.Top)
                   & " vein=" & Material'Image (C.Vein_Mat) & " " & Img (C.Vein_Lo) & ".." & Img (C.Vein_Hi)
                   & " speckle=" & Material'Image (C.Speckle_Mat) & " " & Img (C.Speckle, 2)
                   & " bog=" & Img (C.Bog_Lo) & ".." & Img (C.Bog_Hi)
                   & " visible=" & Material'Image (Top_Material (W, C, X * 4 + 2, Y * 4 + 2)));
         for D of W.Deposits.all loop
            if Castle.Deposits.Touches (D, Float (X) + 0.5, Float (Y) + 0.5) then
               Put_Line ("   deposit " & Deposit_Kind'Image (D.Kind) & " at (" & Img (D.Cx, 0) & ","
                         & Img (D.Cy, 0) & ") r=" & Img (D.Radius, 1)
                         & " tubes=" & Img (D.Last_Tube - D.First_Tube + 1) & " reach=" & Img (D.Reach, 0)
                         & " deepest=" & Img (D.Deepest, 1) & " silver=" & Img (D.Silver_Vol, 0)
                         & " gold=" & Img (D.Gold_Vol, 0) & " thick=" & Img (D.Thick, 2));
            end if;
         end loop;
      end;
   end loop;
end Probe;
