package body Castle.Marks is

   procedure Begin_Frame is
   begin
      Count := 0;
   end Begin_Frame;

   procedure Strip (From, To : Vec3; Width : Float; C : Colour; Of_Ground : Boolean := False) is
   begin
      if Count < Max_Marks then
         Marks (Count) := (F32 (From.X), F32 (From.Y), F32 (From.Z), F32 (Width),
                           F32 (To.X), F32 (To.Y), F32 (To.Z), (if Of_Ground then 1.0 else 0.0),
                           F32 (C.R), F32 (C.G), F32 (C.B), F32 (C.A));
         Count := Count + 1;
      end if;
   end Strip;

end Castle.Marks;
