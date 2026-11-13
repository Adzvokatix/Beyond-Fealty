separate (Castle.Colony)
procedure Release (M : in out Member; I : Positive) is
begin
   if M.State in To_Take | Taking and then M.Cell in 1 .. N_Cells then   --  what it was to take, given back
      declare
         C : Cell renames Cells (M.Cell);
      begin
         C.Outgoing := C.Outgoing - Natural'Min (C.Outgoing, M.Due);
         if C.Count = 0 and then C.Incoming = 0 and then C.Outgoing = 0 then
            C.Kind := Nothing;
         end if;
      end;
      M.Cell := 0;
      M.Due := 0;
   end if;
   if M.Bush > 0 and then Bushes (M.Bush).Reserved_By = I then
      Bushes (M.Bush).Reserved_By := 0;
   end if;
   M.Bush := 0;
   if M.Tree > 0 and then Trees (M.Tree).Reserved_By = I then
      Trees (M.Tree).Reserved_By := 0;
   end if;
   M.Tree := 0;
   if M.Pile > 0 and then M.State in To_Pile | Lifting and then Piles (M.Pile).Claimed > 0 then
      Piles (M.Pile).Claimed := Piles (M.Pile).Claimed - 1;
   end if;
   M.Pile := 0;
   M.Patch := 0;
   M.Site_Seg := 0;
   M.Site_M := 0;
   M.Site_Laid := 0;
   M.Site_Patch := 0;                    --  (the house it is building is its still)
end Release;
