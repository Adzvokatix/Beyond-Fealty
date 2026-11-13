separate (Castle.Colony)
function Next_Near (M : in out Member) return Boolean is
   Bx : constant Integer := B (M.Pos.X);
   By : constant Integer := B (M.Pos.Y);
   Bz : constant Integer := B (M.Pos.Z);
   R  : constant Integer := (case M.Fetch is when Stone => 6, when Vegetables => 8, when others => 4);
   Best : Float := Float'Last;
   Got  : Boolean := False;
begin
   if M.Fetch = Water then
      return Source_At (Water, M.Tgt);
   end if;
   for X in Bx - R .. Bx + R loop
      for Y in By - R .. By + R loop
         for Z in Bz - 2 .. Bz + (if M.Fetch = Stone then 7 else 0) loop
            declare
               P : constant Block_Pos := (Integer_16 (X), Integer_16 (Y), Integer_16 (Z));
               D : constant Float := Flat_Dist (M.Pos, Centre_Of (P)) - 0.1 * Float (Z - Bz);
            begin
               if D < Best and then Source_At (M.Fetch, P) then
                  Best := D;
                  M.Tgt := P;
                  Got := True;
               end if;
            end;
         end loop;
      end loop;
   end loop;
   return Got;
end Next_Near;
