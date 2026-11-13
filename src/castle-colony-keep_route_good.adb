separate (Castle.Colony)
procedure Keep_Route_Good (M : in out Member; Ok : out Boolean) is
begin
   Ok := True;
   if M.Replan then
      M.Replan := False;
      declare
         Goal : constant Vec3 := M.Goal;
      begin
         Ok := Route_To (M, Goal, Near_Of (M));
      end;
      return;
   end if;
   if Tick_N >= M.Check_Tick and then M.Route.N >= 2 then
      M.Check_Tick := Tick_N + Tick_Hz / 2;
      if Castle.Nav.Changed (M.Route) then
         if M.Route.Result = Castle.Nav.Found and then Castle.Nav.Still_Good (M.Route, M.Leg) then
            Castle.Nav.Restamp (M.Route);
         else
            declare
               Goal : constant Vec3 := M.Goal;
            begin
               Ok := Route_To (M, Goal, Near_Of (M));
            end;
         end if;
      end if;
   end if;
end Keep_Route_Good;
