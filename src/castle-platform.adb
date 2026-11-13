with Ada.Text_IO;          use Ada.Text_IO;
with Interfaces.C;         use Interfaces.C;
with Interfaces.C.Strings; use Interfaces.C.Strings;
with System;               use type System.Address;
with Castle.GL;
with Castle.GLFW;          use Castle.GLFW;

package body Castle.Platform is

   Probing : Boolean := False;   --  quiet while trying context versions

   procedure On_Error (Code : int; Description : chars_ptr) with Convention => C;

   procedure On_Error (Code : int; Description : chars_ptr) is
   begin
      if not Probing then
         Put_Line (Standard_Error, "GLFW error" & Code'Image & ": " & Value (Description));
      end if;
   end On_Error;

   function Open (Title : String; Width, Height : Positive; Fixed : Boolean := False) return Window is
      Previous : Error_Callback;
      pragma Unreferenced (Previous);
      Name : chars_ptr := New_String (Title);
      App  : chars_ptr := New_String ("castle");
      Win  : Window := System.Null_Address;
   begin
      Previous := Set_Error_Callback (On_Error'Access);
      if Init = 0 then
         raise Program_Error with "GLFW could not start";
      end if;
      for Minor in reverse 5 .. 6 loop
         Probing := Minor = 6;
         Window_Hint (Context_Version_Major, 4);
         Window_Hint (Context_Version_Minor, int (Minor));
         Window_Hint (OpenGL_Profile, OpenGL_Core_Profile);
         Window_Hint (OpenGL_Forward_Compat, 1);
         Window_Hint (Depth_Bits, 24);
         Window_Hint (Alpha_Bits, 0);   --  an opaque window: compositors may honour alpha
         Window_Hint (Samples, 0);
         Window_Hint (Resizable, (if Fixed then 0 else 1));
         Window_Hint_String (Wayland_App_ID, App);
         Window_Hint_String (X11_Class_Name, App);
         Win := Create_Window (int (Width), int (Height), Name,
                               System.Null_Address, System.Null_Address);
         exit when Win /= System.Null_Address;
      end loop;
      Probing := False;
      Free (Name);
      Free (App);
      if Win = System.Null_Address then
         Shutdown;
         raise Program_Error with "no OpenGL 4.5 core context on this machine";
      end if;
      Make_Context_Current (Win);
      return Win;
   end Open;

   procedure Close (W : Window) is
   begin
      Destroy_Window (W);
      Shutdown;
   end Close;

   procedure Set_Title (W : Window; Title : String) is
      Name : chars_ptr := New_String (Title);
   begin
      Set_Window_Title (W, Name);
      Free (Name);
   end Set_Title;

   function GL_Version return String is (Value (Castle.GL.Get_String (Castle.GL.Version)));
   function GL_Renderer return String is (Value (Castle.GL.Get_String (Castle.GL.Renderer)));

end Castle.Platform;
