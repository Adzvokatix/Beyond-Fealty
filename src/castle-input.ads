with Interfaces.C;
with Castle.GLFW;

--  Named actions over raw keys, so the options menu can rebind them later.
--  Call Update once per frame after Castle.GLFW.Poll_Events.
package Castle.Input is

   type Action is
     (Pan_Forward, Pan_Back, Pan_Left, Pan_Right,
      Turn_Left, Turn_Right, Tilt_Up, Tilt_Down,
      Zoom_In, Zoom_Out, Reset_View, Time_Back, Time_Forward, Day_Back, Day_Forward,
      Brush_Size, Next_Material, Quick_Save, Quick_Load, Place_Mode,
      Show_Help, Show_Survey, Show_Debug, Hide_HUD, Show_Routes, Show_Nav, Show_Wells,
      Show_Band, Open_Roofs, Pause_Game, Speed_1, Speed_2, Speed_3,
      UI_Smaller, UI_Larger,
      Screenshot, Quit);

   type Keys is array (1 .. 2) of Interfaces.C.int;   --  0 = unbound

   Bindings : array (Action) of Keys :=
     [Pan_Forward => [Castle.GLFW.Key_W, Castle.GLFW.Key_Up],
      Pan_Back    => [Castle.GLFW.Key_S, Castle.GLFW.Key_Down],
      Pan_Left    => [Castle.GLFW.Key_A, Castle.GLFW.Key_Left],
      Pan_Right   => [Castle.GLFW.Key_D, Castle.GLFW.Key_Right],
      Turn_Left   => [Castle.GLFW.Key_Q, 0],
      Turn_Right  => [Castle.GLFW.Key_E, 0],
      Tilt_Up     => [Castle.GLFW.Key_R, Castle.GLFW.Key_Page_Up],
      Tilt_Down   => [Castle.GLFW.Key_F, Castle.GLFW.Key_Page_Down],
      Zoom_In     => [Castle.GLFW.Key_Equal, Castle.GLFW.Key_KP_Add],
      Zoom_Out    => [Castle.GLFW.Key_Minus, Castle.GLFW.Key_KP_Subtract],
      Reset_View  => [Castle.GLFW.Key_Home, 0],
      Time_Back   => [Castle.GLFW.Key_Left_Bracket, 0],
      Time_Forward => [Castle.GLFW.Key_Right_Bracket, 0],
      Day_Back    => [Castle.GLFW.Key_Comma, 0],
      Day_Forward => [Castle.GLFW.Key_Period, 0],
      Brush_Size  => [Castle.GLFW.Key_B, 0],
      Next_Material => [Castle.GLFW.Key_M, 0],
      Quick_Save  => [Castle.GLFW.Key_F5, 0],
      Quick_Load  => [Castle.GLFW.Key_F9, 0],
      Place_Mode  => [Castle.GLFW.Key_Left_Control, Castle.GLFW.Key_Right_Control],
      Show_Help   => [Castle.GLFW.Key_F1, 0],
      Show_Survey => [Castle.GLFW.Key_F2, 0],
      Show_Debug  => [Castle.GLFW.Key_F3, 0],
      Hide_HUD    => [Castle.GLFW.Key_F4, 0],
      Show_Routes => [Castle.GLFW.Key_F6, 0],
      Show_Nav    => [Castle.GLFW.Key_F7, 0],
      Show_Wells  => [Castle.GLFW.Key_F8, 0],
      Show_Band   => [Castle.GLFW.Key_Tab, 0],
      Open_Roofs  => [Castle.GLFW.Key_H, 0],          --  houses opened where the eye and the pointer are, all of them, or none
      Pause_Game  => [Castle.GLFW.Key_Space, 0],
      Speed_1     => [Castle.GLFW.Key_1, 0],
      Speed_2     => [Castle.GLFW.Key_2, 0],
      Speed_3     => [Castle.GLFW.Key_3, 0],
      UI_Smaller  => [Castle.GLFW.Key_F10, 0],
      UI_Larger   => [Castle.GLFW.Key_F11, 0],
      Screenshot  => [Castle.GLFW.Key_F12, 0],
      Quit        => [Castle.GLFW.Key_Escape, 0]];

   procedure Attach (W : Castle.GLFW.Window);   --  installs the wheel callback
   procedure Update (W : Castle.GLFW.Window);
   procedure Ignore (On : Boolean);
   --  Read no keys, buttons, wheel or pointer (scripted runs: a window that
   --  takes the focus mustn't be steered by keys meant for another).

   function Held (A : Action) return Boolean;
   function Pressed (A : Action) return Boolean;    --  went down this frame
   function Wheel return Float;                     --  wheel steps this frame
   procedure Drop_Wheel;                            --  the interface has it: none for anyone else this frame
   function Left_Held return Boolean;               --  left button is down
   function Mouse_Dx return Float;                  --  pixels this frame
   function Mouse_Dy return Float;
   function Orbit_Drag return Boolean;              --  right button held
   function Pan_Drag return Boolean;                --  middle button held
   function Clicked return Boolean;                 --  left button went down this frame
   function Right_Clicked return Boolean;           --  right button let go without dragging
   function Cursor_X return Float;                  --  -1 (left) .. 1 (right)
   function Cursor_Y return Float;                  --  -1 (bottom) .. 1 (top)

end Castle.Input;
