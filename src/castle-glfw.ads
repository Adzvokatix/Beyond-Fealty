with System;
with Interfaces.C;         use Interfaces.C;
with Interfaces.C.Strings; use Interfaces.C.Strings;

--  Thin binding to the parts of GLFW 3 the game uses: window, GL context,
--  keyboard and mouse.  Every call must come from the main thread.
package Castle.GLFW is

   subtype Window is System.Address;

   Context_Version_Major : constant int := 16#0002_2002#;
   Context_Version_Minor : constant int := 16#0002_2003#;
   OpenGL_Forward_Compat : constant int := 16#0002_2006#;
   OpenGL_Profile        : constant int := 16#0002_2008#;
   OpenGL_Core_Profile   : constant int := 16#0003_2001#;
   Alpha_Bits            : constant int := 16#0002_1004#;
   Depth_Bits            : constant int := 16#0002_1005#;
   Samples               : constant int := 16#0002_100D#;
   Resizable             : constant int := 16#0002_0003#;
   Wayland_App_ID        : constant int := 16#0002_6001#;   --  GLFW 3.4+
   X11_Class_Name        : constant int := 16#0002_4001#;

   Press : constant int := 1;

   Key_Comma       : constant int := 44;
   Key_Minus       : constant int := 45;
   Key_Period      : constant int := 46;
   Key_Equal       : constant int := 61;
   Key_A           : constant int := 65;
   Key_B           : constant int := 66;
   Key_H           : constant int := 72;
   Key_M           : constant int := 77;
   Key_F1          : constant int := 290;
   Key_F2          : constant int := 291;
   Key_F3          : constant int := 292;
   Key_F4          : constant int := 293;
   Key_F5          : constant int := 294;
   Key_F6          : constant int := 295;
   Key_F7          : constant int := 296;
   Key_F8          : constant int := 297;
   Key_Space       : constant int := 32;
   Key_1           : constant int := 49;
   Key_2           : constant int := 50;
   Key_3           : constant int := 51;
   Key_Tab         : constant int := 258;
   Key_F9          : constant int := 298;
   Key_F10         : constant int := 299;
   Key_F11         : constant int := 300;
   Key_Left_Control  : constant int := 341;
   Key_Right_Control : constant int := 345;
   Key_D           : constant int := 68;
   Key_E           : constant int := 69;
   Key_F           : constant int := 70;
   Key_Q           : constant int := 81;
   Key_R           : constant int := 82;
   Key_S           : constant int := 83;
   Key_W           : constant int := 87;
   Key_Left_Bracket  : constant int := 91;
   Key_Right_Bracket : constant int := 93;
   Key_Escape      : constant int := 256;
   Key_Right       : constant int := 262;
   Key_Left        : constant int := 263;
   Key_Down        : constant int := 264;
   Key_Up          : constant int := 265;
   Key_Page_Up     : constant int := 266;
   Key_Page_Down   : constant int := 267;
   Key_Home        : constant int := 268;
   Key_F12         : constant int := 301;
   Key_KP_Subtract : constant int := 333;
   Key_KP_Add      : constant int := 334;

   Mouse_Left   : constant int := 0;
   Mouse_Right  : constant int := 1;
   Mouse_Middle : constant int := 2;

   function Init return int
     with Import, Convention => C, External_Name => "glfwInit";
   procedure Shutdown
     with Import, Convention => C, External_Name => "glfwTerminate";
   procedure Window_Hint (Hint, Value : int)
     with Import, Convention => C, External_Name => "glfwWindowHint";
   procedure Window_Hint_String (Hint : int; Value : chars_ptr)
     with Import, Convention => C, External_Name => "glfwWindowHintString";
   function Create_Window
     (Width, Height : int; Title : chars_ptr;
      Monitor, Share : System.Address) return Window
     with Import, Convention => C, External_Name => "glfwCreateWindow";
   procedure Destroy_Window (W : Window)
     with Import, Convention => C, External_Name => "glfwDestroyWindow";
   procedure Make_Context_Current (W : Window)
     with Import, Convention => C,
          External_Name => "glfwMakeContextCurrent";
   procedure Swap_Interval (Interval : int)
     with Import, Convention => C, External_Name => "glfwSwapInterval";
   function Window_Should_Close (W : Window) return int
     with Import, Convention => C, External_Name => "glfwWindowShouldClose";
   procedure Set_Window_Should_Close (W : Window; Value : int)
     with Import, Convention => C,
          External_Name => "glfwSetWindowShouldClose";
   procedure Poll_Events
     with Import, Convention => C, External_Name => "glfwPollEvents";
   procedure Swap_Buffers (W : Window)
     with Import, Convention => C, External_Name => "glfwSwapBuffers";
   procedure Get_Framebuffer_Size (W : Window; Width, Height : out int)
     with Import, Convention => C,
          External_Name => "glfwGetFramebufferSize";
   function Get_Key (W : Window; Key : int) return int
     with Import, Convention => C, External_Name => "glfwGetKey";
   function Get_Mouse_Button (W : Window; Button : int) return int
     with Import, Convention => C, External_Name => "glfwGetMouseButton";
   procedure Get_Window_Size (W : Window; Width, Height : out int)
     with Import, Convention => C, External_Name => "glfwGetWindowSize";
   procedure Get_Cursor_Pos (W : Window; X, Y : out double)
     with Import, Convention => C, External_Name => "glfwGetCursorPos";
   procedure Set_Window_Title (W : Window; Title : chars_ptr)
     with Import, Convention => C, External_Name => "glfwSetWindowTitle";
   function Get_Time return double
     with Import, Convention => C, External_Name => "glfwGetTime";

   type Scroll_Callback is access procedure (W : Window; Dx, Dy : double)
     with Convention => C;
   function Set_Scroll_Callback
     (W : Window; Callback : Scroll_Callback) return Scroll_Callback
     with Import, Convention => C, External_Name => "glfwSetScrollCallback";

   type Error_Callback is access procedure
     (Code : int; Description : chars_ptr)
     with Convention => C;
   function Set_Error_Callback (Callback : Error_Callback)
     return Error_Callback
     with Import, Convention => C, External_Name => "glfwSetErrorCallback";

end Castle.GLFW;
