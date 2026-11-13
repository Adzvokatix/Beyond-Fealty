with Ada.Text_IO;      use Ada.Text_IO;
with Castle.Dims;      use Castle.Dims;
with Castle.Fields;    use Castle.Fields;
with Castle.Maps;      use Castle.Maps;
with Castle.Worldgen;

--  fall_find: where seed 1's streams fall a metre or more in one cell,
--  the biggest first, for looking at waterfalls.
procedure Fall_Find is
   W : World;
   type Fall is record
      X, Y : Integer := 0;
      Drop : Float := 0.0;
   end record;
   Best : array (1 .. 12) of Fall;
begin
   Castle.Worldgen.Create (1, W, Report => False);
   for Y in 1 .. Size_M - 2 loop
      for X in 1 .. Size_M - 2 loop
         declare
            K : constant Cell_Range := Idx (X, Y);
         begin
            if W.Kind (K) in Stream | River and then W.Down (K) >= 0
              and then W.Water (K) > W.Height (K)
            then
               declare
                  J : constant Cell_Range := Idx (X + Dir_DX (W.Down (K)), Y + Dir_DY (W.Down (K)));
                  D : constant Float := W.Water (K) - W.Water (J);
               begin
                  if W.Water (J) > W.Height (J) and then D >= 1.0 and then D > Best (Best'Last).Drop then
                     declare
                        I : Positive := Best'Last;
                     begin
                        --  keep falls apart: skip one within 30 m of a bigger one
                        if (for all B of Best => (B.X - X) ** 2 + (B.Y - Y) ** 2 > 900 or else B.Drop < D) then
                           while I > 1 and then Best (I - 1).Drop < D loop
                              Best (I) := Best (I - 1);
                              I := I - 1;
                           end loop;
                           Best (I) := (X, Y, D);
                        end if;
                     end;
                  end if;
               end;
            end if;
         end;
      end loop;
   end loop;
   for B of Best loop
      if B.Drop > 0.0 then
         Put_Line ("fall at" & B.X'Image & B.Y'Image & ": drop" & Integer'Image (Integer (B.Drop * 100.0))
                   & " cm, ground" & Integer'Image (Integer (W.Height (Idx (B.X, B.Y)))) & " m");
      end if;
   end loop;
end Fall_Find;
