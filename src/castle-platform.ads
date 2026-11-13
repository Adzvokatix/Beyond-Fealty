with Castle.GLFW;

--  The window and its OpenGL context.
package Castle.Platform is

   function Open (Title : String; Width, Height : Positive; Fixed : Boolean := False)
                  return Castle.GLFW.Window;
   --  OpenGL 4.6 core when the driver has it, else 4.5 (everything the
   --  renderer uses is 4.5).  Raises Program_Error if neither exists.
   --  The window's own framebuffer is single-sampled: the renderer does
   --  its multisampling in a target of its own.  The window's app id (its
   --  class on X11) is "castle", for window manager rules.  Fixed: a window
   --  that can't be resized, which tiling compositors such as Sway float
   --  at exactly Width x Height instead of tiling it.

   procedure Close (W : Castle.GLFW.Window);
   procedure Set_Title (W : Castle.GLFW.Window; Title : String);

   function GL_Version return String;
   function GL_Renderer return String;

end Castle.Platform;
