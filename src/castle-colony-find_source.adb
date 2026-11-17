separate (Castle.Colony)
procedure Find_Source (K : Item_Kind; From : Vec3; Self : Positive; Tgt : out Block_Pos; Found : out Boolean;
                       Reach_M : Float := Work_Radius_M; Least_M : Float := 0.0) is
   M      : Member renames Band (Self);
   Bit    : constant Unsigned_8 := Source_Bit (K);
   FX     : constant Integer := Integer (Float'Floor (From.X / 8.0));
   FY     : constant Integer := Integer (Float'Floor (From.Y / 8.0));
   SX     : constant Integer := Integer (Float'Floor (Stake_At.X / 8.0));
   SY     : constant Integer := Integer (Float'Floor (Stake_At.Y / 8.0));
   Reach  : constant Integer := Integer (Reach_M / 8.0) + 1;
   Best_D : Float := Float'Last;

   procedure Consider (P : Block_Pos) is
      C : constant Vec3 := Centre_Of (P);
      D : constant Float := Flat_Dist (From, C);
   begin
      if D < Best_D and then Flat_Dist (Stake_At, C) <= Reach_M
        and then (Least_M <= 0.0 or else Flat_Dist (Stake_At, C) >= Least_M)
        and then not Failed (M, Source_Id (P)) and then not Taken (K, P, Self)
      then
         Best_D := D;
         Tgt := P;
         Found := True;
      end if;
   end Consider;

   --  Stack (CX, CY)'s sources of K, in the order they are come to: its
   --  cells west to east and south to north, a cell's floors highest first,
   --  the four block columns of each.
   procedure Read_Stack (CX, CY : Integer; N : out Natural; L : out Source_List) is
   begin
      N := 0;
      for I in 0 .. Castle.Nav.Cells_Per_Stack - 1 loop
         for J in 0 .. Castle.Nav.Cells_Per_Stack - 1 loop
            declare
               Nx : constant Integer := CX * Castle.Nav.Cells_Per_Stack + I;
               Ny : constant Integer := CY * Castle.Nav.Cells_Per_Stack + J;
               NF : Natural;
               F  : Castle.Nav.Floor_List;
            begin
               Castle.Nav.Floors_At (Nx, Ny, NF, F);
               for Fi in 1 .. NF loop
                  if K /= Water or else (F (Fi).Water > 0 and then F (Fi).Speed > 0.0) then
                     for A in 0 .. 1 loop
                        for C in 0 .. 1 loop
                           declare
                              P : constant Block_Pos :=
                                (Integer_16 (Nx * 2 + A), Integer_16 (Ny * 2 + C),
                                 Integer_16 (if K = Stone then F (Fi).Z - 1 else F (Fi).Z));
                           begin
                              if Source_At (K, P) then
                                 N := N + 1;
                                 L (N) := P;
                              end if;
                           end;
                        end loop;
                     end loop;
                  end if;
               end loop;
            end;
         end loop;
      end loop;
   end Read_Stack;

   Max_In_Stack : constant := Castle.Nav.Cells_Per_Stack * Castle.Nav.Cells_Per_Stack * Castle.Nav.Max_Floors * 4;

   procedure Scan (CX, CY : Integer) is
      function Ver (X, Y : Integer) return Natural is
        (if X in Memo_Grid'Range (1) and then Y in Memo_Grid'Range (2) then Own_V (X, Y) else 0);
      Slot : constant Memo_Slot :=
        (case K is when Straw => 0, when Stone => 1, when Water => 2, when others => 3);
   begin
      if not Memos_On then
         declare
            N : Natural;
            L : Source_List (1 .. Max_In_Stack);
         begin
            Read_Stack (CX, CY, N, L);
            for I in 1 .. N loop
               Consider (L (I));
            end loop;
            if N = 0 then
               Sources (CX, CY) := Sources (CX, CY) and not Bit;
            end if;
         end;
         return;
      end if;
      if Memos (CX, CY) = null then
         Memos (CX, CY) := new Stack_Memos;
      end if;
      declare
         M  : Source_Memo renames Memos (CX, CY) (Slot);
         V  : constant Natural := Ver (CX, CY);
         VE : constant Natural := Ver (CX + 1, CY);
         VW : constant Natural := Ver (CX - 1, CY);
         VN : constant Natural := Ver (CX, CY + 1);
         VS : constant Natural := Ver (CX, CY - 1);
      begin
         if M.V /= V or else M.VE /= VE or else M.VW /= VW or else M.VN /= VN or else M.VS /= VS then
            declare
               N : Natural;
               L : Source_List (1 .. Max_In_Stack);
            begin
               Read_Stack (CX, CY, N, L);
               Free (M.L);
               if N > 0 then
                  M.L := new Source_List'(L (1 .. N));
               end if;
               M := (V, VE, VW, VN, VS, M.L);
            end;
         end if;
         if M.L = null then
            Sources (CX, CY) := Sources (CX, CY) and not Bit;
         else
            for P of M.L.all loop
               Consider (P);
            end loop;
         end if;
      end;
   end Scan;
begin
   Found := False;
   Tgt := (0, 0, 0);
   for R in 0 .. 2 * Reach + 1 loop
      exit when Float (R - 1) * 8.0 > Best_D;
      for DX in -R .. R loop
         for DY in -R .. R loop
            if abs DX = R or else abs DY = R then
               declare
                  CX : constant Integer := FX + DX;
                  CY : constant Integer := FY + DY;
               begin
                  if abs (CX - SX) <= Reach and then abs (CY - SY) <= Reach
                    and then CX in Indexed_Grid'Range (1) and then CY in Indexed_Grid'Range (2)
                    and then Indexed (CX, CY) and then (Sources (CX, CY) and Bit) /= 0
                    and then Own_V (CX, CY) > 0
                  then
                     Scan (CX, CY);
                  end if;
               end;
            end if;
         end loop;
      end loop;
   end loop;
end Find_Source;
