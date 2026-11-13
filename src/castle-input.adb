with Interfaces.C; use Interfaces.C;
with Castle.GLFW;  use Castle.GLFW;

package body Castle.Input is

   type Action_Flags is array (Action) of Boolean;
   Now, Before : Action_Flags := [others => False];
   Wheel_Accum  : Float := 0.0;
   Wheel_Frame  : Float := 0.0;
   Last_X, Last_Y : double := 0.0;
   Dx, Dy       : Float := 0.0;
   Right_Down, Middle_Down : Boolean := False;
   Right_Before : Boolean := False;
   Right_Drag   : Float := 0.0;      --  pixels moved while the right button is down
   Right_Click  : Boolean := False;
   Left_Down, Left_Before  : Boolean := False;
   Cx, Cy : Float := 0.0;

   procedure On_Scroll (W : Window; Sx, Sy : double) with Convention => C;

   procedure On_Scroll (W : Window; Sx, Sy : double) is
      pragma Unreferenced (W, Sx);
   begin
      Wheel_Accum := Wheel_Accum + Float (Sy);
   end On_Scroll;

   procedure Attach (W : Window) is
      Previous : Scroll_Callback;
      pragma Unreferenced (Previous);
   begin
      Previous := Set_Scroll_Callback (W, On_Scroll'Access);
      Get_Cursor_Pos (W, Last_X, Last_Y);
   end Attach;

   Deaf : Boolean := False;

   procedure Ignore (On : Boolean) is
   begin
      Deaf := On;
   end Ignore;

   procedure Update (W : Window) is
      X, Y : double;
   begin
      Before := Now;
      if Deaf then
         Now := [others => False];
         Before := Now;
         Wheel_Frame := 0.0;
         Wheel_Accum := 0.0;
         Dx := 0.0;
         Dy := 0.0;
         Right_Before := False;
         Right_Down := False;
         Right_Click := False;
         Left_Before := False;
         Left_Down := False;
         Middle_Down := False;
         return;
      end if;
      for A in Action loop
         Now (A) := False;
         for K of Bindings (A) loop
            if K /= 0 and then Get_Key (W, K) = Press then
               Now (A) := True;
            end if;
         end loop;
      end loop;
      Wheel_Frame := Wheel_Accum;
      Wheel_Accum := 0.0;
      Get_Cursor_Pos (W, X, Y);
      Dx := Float (X - Last_X);
      Dy := Float (Y - Last_Y);
      Last_X := X;
      Last_Y := Y;
      Right_Before := Right_Down;
      Right_Down := Get_Mouse_Button (W, Mouse_Right) = Press;
      if Right_Down and then not Right_Before then
         Right_Drag := 0.0;
      elsif Right_Down then
         Right_Drag := Right_Drag + abs Dx + abs Dy;
      end if;
      Right_Click := Right_Before and then not Right_Down and then Right_Drag < 5.0;
      Left_Before := Left_Down;
      Left_Down := Get_Mouse_Button (W, Mouse_Left) = Press;
      declare
         Ww, Wh : int;
      begin
         Get_Window_Size (W, Ww, Wh);
         if Ww > 0 and then Wh > 0 then
            Cx := 2.0 * Float (X) / Float (Ww) - 1.0;
            Cy := 1.0 - 2.0 * Float (Y) / Float (Wh);
         end if;
      end;
      Middle_Down := Get_Mouse_Button (W, Mouse_Middle) = Press;
   end Update;

   function Held (A : Action) return Boolean is (Now (A));
   function Pressed (A : Action) return Boolean is (Now (A) and then not Before (A));
   function Wheel return Float is (Wheel_Frame);
   function Left_Held return Boolean is (Left_Down);

   procedure Drop_Wheel is
   begin
      Wheel_Frame := 0.0;
   end Drop_Wheel;
   function Mouse_Dx return Float is (Dx);
   function Mouse_Dy return Float is (Dy);
   function Orbit_Drag return Boolean is (Right_Down);
   function Pan_Drag return Boolean is (Middle_Down);
   function Clicked return Boolean is (Left_Down and then not Left_Before);
   function Right_Clicked return Boolean is (Right_Click);
   function Cursor_X return Float is (Cx);
   function Cursor_Y return Float is (Cy);

end Castle.Input;
