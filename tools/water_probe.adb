--  water_probe X Y [R]: the generated water round metre (X, Y) of seed 1,
--  block by block: ground row, water rows above it, and the 1 m fields under them.  For looking at steps.
with Ada.Text_IO;      use Ada.Text_IO;
with Ada.Command_Line; use Ada.Command_Line;
with Castle.Fields;    use Castle.Fields;
with Castle.Maps;      use Castle.Maps;
with Castle.Geology;
with Castle.Worldgen;

procedure Water_Probe is
   W  : World;
   Xm : constant Integer := Integer'Value (Argument (1));
   Ym : constant Integer := Integer'Value (Argument (2));
   R  : constant Integer := (if Argument_Count >= 3 then Integer'Value (Argument (3)) else 3);
   function Pad (S : String; N : Natural) return String is
     ((if S'Length < N then (1 .. N - S'Length => ' ') else "") & S);
begin
   Castle.Worldgen.Create (1, W, Report => False);
   Put_Line ("1 m cells: kind water height (rows north to south)");
   for Y in reverse Ym - R .. Ym + R loop
      for X in Xm - R .. Xm + R loop
         declare
            K : constant Cell_Range := Idx (X, Y);
         begin
            Put (Pad (Water_Kind'Image (W.Kind (K)) (1 .. 2), 3) & Pad (Integer'Image (Integer (W.Water (K) * 100.0)), 7)
                 & "/" & Pad (Integer'Image (Integer (W.Height (K) * 100.0)), 6));
         end;
      end loop;
      New_Line;
   end loop;
   Put_Line ("blocks: ground row + water rows , rows north to south");
   for By in reverse (Ym - R) * 4 .. (Ym + R) * 4 + 3 loop
      for Bx in (Xm - R) * 4 .. (Xm + R) * 4 + 3 loop
         declare
            C : constant Castle.Geology.Column := Castle.Geology.Prepare_Column (W, Bx, By);
            D : constant Integer := Integer'Max (0, C.Water_Top - C.Solid);
         begin
            Put (Pad (Integer'Image (C.Solid), 4) & (if D > 0 then "+" & Integer'Image (D) (2 .. Integer'Image (D)'Last) else "  ")
                 & (if D > 9 then "" else " "));
         end;
      end loop;
      New_Line;
   end loop;
end Water_Probe;
