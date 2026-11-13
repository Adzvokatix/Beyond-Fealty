separate (Castle.Colony)
procedure Zone_Camp (Centre : Vec3; Ok : out Boolean) is
   Cx, Cy, Zc : Integer;
begin
   Ok := False;
   Plan_Camp_Lot (Centre, Cx, Cy, Zc);
   if Refused_For /= Taken_None then
      return;
   end if;
   Camp_Set := True;
   Camp_At := (Float (Cx) * 0.25, Float (Cy) * 0.25, Float (Zc + 1) * 0.25);
   Camp_Level := -1;
   New_Camp_Zone;
   Take_Plan (Camp_Zone_N);
   if Labour_On then
      --  marked: the band builds it
      Zones (Camp_Zone_N).Built := False;
      Zones (Camp_Zone_N).Got := [others => 0];
      Camp_Level := (if Level_On then Choose_Level else -1);
      Check_Built;
   else
      --  as it was: it stands at once, the grass and grain on it cut
      Clear_Plan;
      Finish_Camp (Tread => False);
   end if;
   Ok := True;
end Zone_Camp;
