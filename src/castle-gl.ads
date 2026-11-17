with System;
with Interfaces.C;         use Interfaces.C;
with Interfaces.C.Strings; use Interfaces.C.Strings;

--  Thin binding to the OpenGL 4.5 core functions the renderer uses.  On
--  Linux libGL (glvnd) exports every core entry point, so these link
--  directly with no loader.  (Windows will need wglGetProcAddress later.)
package Castle.GL is

   subtype Enum     is unsigned;
   subtype Bitfield is unsigned;
   subtype UInt     is unsigned;
   subtype Sizei    is int;
   subtype Float32  is C_float;
   subtype Sizeiptr is ptrdiff_t;
   subtype Intptr   is ptrdiff_t;
   subtype Bool     is unsigned_char;

   GL_False : constant Bool := 0;
   GL_True  : constant Bool := 1;

   Color_Buffer_Bit      : constant Bitfield := 16#4000#;
   Depth_Buffer_Bit      : constant Bitfield := 16#0100#;
   Dynamic_Storage_Bit   : constant Bitfield := 16#0100#;
   Depth_Test            : constant Enum := 16#0B71#;
   Cull_Face_Cap         : constant Enum := 16#0B44#;
   Blend                 : constant Enum := 16#0BE2#;
   Back                  : constant Enum := 16#0405#;
   CCW                   : constant Enum := 16#0901#;
   Less                  : constant Enum := 16#0201#;
   Lequal                : constant Enum := 16#0203#;
   Src_Alpha             : constant Enum := 16#0302#;
   One_Minus_Src_Alpha   : constant Enum := 16#0303#;
   Triangles             : constant Enum := 16#0004#;
   Lines                 : constant Enum := 16#0001#;
   Vertex_Shader         : constant Enum := 16#8B31#;
   Fragment_Shader       : constant Enum := 16#8B30#;
   Compile_Status        : constant Enum := 16#8B81#;
   Link_Status           : constant Enum := 16#8B82#;
   Shader_Storage_Buffer : constant Enum := 16#90D2#;
   Draw_Indirect_Buffer  : constant Enum := 16#8F3F#;
   Int_Type              : constant Enum := 16#1404#;
   Unsigned_Byte         : constant Enum := 16#1401#;
   Texture_2D_Array      : constant Enum := 16#8C1A#;
   Texture_3D            : constant Enum := 16#806F#;
   RGBA8                 : constant Enum := 16#8058#;
   RGBA                  : constant Enum := 16#1908#;
   RGB                   : constant Enum := 16#1907#;
   Texture_Min_Filter    : constant Enum := 16#2801#;
   Texture_Mag_Filter    : constant Enum := 16#2800#;
   Nearest               : constant int  := 16#2600#;
   Version               : constant Enum := 16#1F02#;
   Renderer              : constant Enum := 16#1F01#;
   Pack_Alignment        : constant Enum := 16#0D05#;
   Time_Elapsed          : constant Enum := 16#88BF#;
   Texture_2D            : constant Enum := 16#0DE1#;
   R16F                  : constant Enum := 16#822D#;
   R32F                  : constant Enum := 16#822E#;
   RG16F                 : constant Enum := 16#822F#;
   RGBA32F               : constant Enum := 16#8814#;
   RGBA16F               : constant Enum := 16#881A#;
   RG32UI                : constant Enum := 16#823C#;
   RG_Integer            : constant Enum := 16#8228#;
   Unsigned_Int          : constant Enum := 16#1405#;
   RG                    : constant Enum := 16#8227#;
   Red                   : constant Enum := 16#1903#;
   Float_Type            : constant Enum := 16#1406#;
   Linear                : constant int  := 16#2601#;
   Texture_Wrap_S        : constant Enum := 16#2802#;
   Texture_Wrap_T        : constant Enum := 16#2803#;
   Clamp_To_Edge         : constant int  := 16#812F#;
   Sample_Alpha_To_Coverage : constant Enum := 16#809E#;
   Framebuffer           : constant Enum := 16#8D40#;
   Renderbuffer          : constant Enum := 16#8D41#;
   Color_Attachment_0    : constant Enum := 16#8CE0#;
   Depth_Attachment      : constant Enum := 16#8D00#;
   Framebuffer_Complete  : constant Enum := 16#8CD5#;
   Depth_Component_24    : constant Enum := 16#81A6#;
   Max_Samples           : constant Enum := 16#8D57#;
   Nearest_Filter        : constant Enum := 16#2600#;
   Depth_Component_32F   : constant Enum := 16#8CAC#;
   Depth_Component_16    : constant Enum := 16#81A5#;
   Texture_Cube_Map      : constant Enum := 16#8513#;
   Texture_Cube_Map_Seamless : constant Enum := 16#884F#;
   Texture_Wrap_R        : constant Enum := 16#8072#;
   Texture_Compare_Mode  : constant Enum := 16#884C#;
   Compare_Ref_To_Texture : constant int := 16#884E#;
   Texture_Compare_Func  : constant Enum := 16#884D#;
   Polygon_Offset_Fill   : constant Enum := 16#8037#;
   Front                 : constant Enum := 16#0404#;
   No_Buffer             : constant Enum := 0;
   Repeat                : constant int  := 16#2901#;
   Linear_Mipmap_Linear  : constant int  := 16#2703#;
   R8                    : constant Enum := 16#8229#;
   Draw_Framebuffer      : constant Enum := 16#8CA9#;
   Read_Framebuffer      : constant Enum := 16#8CA8#;
   Query_Result          : constant Enum := 16#8866#;
   Query_Result_Available : constant Enum := 16#8867#;
   Unpack_Alignment      : constant Enum := 16#0CF5#;

   procedure Viewport (X, Y : int; Width, Height : Sizei)
     with Import, Convention => C, External_Name => "glViewport";
   procedure Clear_Color (R, G, B, A : Float32)
     with Import, Convention => C, External_Name => "glClearColor";
   procedure Clear (Mask : Bitfield)
     with Import, Convention => C, External_Name => "glClear";
   procedure Enable (Cap : Enum)
     with Import, Convention => C, External_Name => "glEnable";
   procedure Disable (Cap : Enum)
     with Import, Convention => C, External_Name => "glDisable";
   procedure Depth_Func (Func : Enum)
     with Import, Convention => C, External_Name => "glDepthFunc";
   procedure Depth_Mask (Flag : Bool)
     with Import, Convention => C, External_Name => "glDepthMask";
   procedure Cull_Face (Mode : Enum)
     with Import, Convention => C, External_Name => "glCullFace";
   procedure Front_Face (Mode : Enum)
     with Import, Convention => C, External_Name => "glFrontFace";
   procedure Blend_Func (S, D : Enum)
     with Import, Convention => C, External_Name => "glBlendFunc";
   function Get_String (Name : Enum) return chars_ptr
     with Import, Convention => C, External_Name => "glGetString";
   procedure Finish
     with Import, Convention => C, External_Name => "glFinish";
   procedure Pixel_Store_I (Pname : Enum; Param : int)
     with Import, Convention => C, External_Name => "glPixelStorei";
   procedure Read_Pixels
     (X, Y : int; Width, Height : Sizei; Format, Kind : Enum;
      Data : System.Address)
     with Import, Convention => C, External_Name => "glReadPixels";

   function Create_Shader (Kind : Enum) return UInt
     with Import, Convention => C, External_Name => "glCreateShader";
   procedure Shader_Source
     (Shader : UInt; Count : Sizei; Strings, Lengths : System.Address)
     with Import, Convention => C, External_Name => "glShaderSource";
   procedure Compile_Shader (Shader : UInt)
     with Import, Convention => C, External_Name => "glCompileShader";
   procedure Get_Shader_Iv (Shader : UInt; Pname : Enum; Param : out int)
     with Import, Convention => C, External_Name => "glGetShaderiv";
   procedure Get_Shader_Info_Log
     (Shader : UInt; Max : Sizei; Length : out Sizei; Log : System.Address)
     with Import, Convention => C, External_Name => "glGetShaderInfoLog";
   procedure Delete_Shader (Shader : UInt)
     with Import, Convention => C, External_Name => "glDeleteShader";
   function Create_Program return UInt
     with Import, Convention => C, External_Name => "glCreateProgram";
   procedure Attach_Shader (Program, Shader : UInt)
     with Import, Convention => C, External_Name => "glAttachShader";
   procedure Link_Program (Program : UInt)
     with Import, Convention => C, External_Name => "glLinkProgram";
   procedure Get_Program_Iv (Program : UInt; Pname : Enum; Param : out int)
     with Import, Convention => C, External_Name => "glGetProgramiv";
   procedure Get_Program_Info_Log
     (Program : UInt; Max : Sizei; Length : out Sizei; Log : System.Address)
     with Import, Convention => C, External_Name => "glGetProgramInfoLog";
   procedure Use_Program (Program : UInt)
     with Import, Convention => C, External_Name => "glUseProgram";
   function Get_Uniform_Location (Program : UInt; Name : chars_ptr)
     return int
     with Import, Convention => C, External_Name => "glGetUniformLocation";
   procedure Program_Uniform_Matrix_4fv
     (Program : UInt; Location : int; Count : Sizei; Transpose : Bool;
      Value : System.Address)
     with Import, Convention => C,
          External_Name => "glProgramUniformMatrix4fv";
   procedure Program_Uniform_3f
     (Program : UInt; Location : int; X, Y, Z : Float32)
     with Import, Convention => C, External_Name => "glProgramUniform3f";
   procedure Program_Uniform_2f (Program : UInt; Location : int; X, Y : Float32)
     with Import, Convention => C, External_Name => "glProgramUniform2f";
   procedure Program_Uniform_1f (Program : UInt; Location : int; X : Float32)
     with Import, Convention => C, External_Name => "glProgramUniform1f";
   procedure Program_Uniform_1i (Program : UInt; Location : int; X : int)
     with Import, Convention => C, External_Name => "glProgramUniform1i";
   procedure Program_Uniform_2ui (Program : UInt; Location : int; X, Y : UInt)
     with Import, Convention => C, External_Name => "glProgramUniform2ui";
   procedure Program_Uniform_4fv (Program : UInt; Location : int; Count : Sizei; Value : System.Address)
     with Import, Convention => C, External_Name => "glProgramUniform4fv";
   procedure Program_Uniform_1fv (Program : UInt; Location : int; Count : Sizei; Value : System.Address)
     with Import, Convention => C, External_Name => "glProgramUniform1fv";

   procedure Create_Buffers (N : Sizei; Buffer : out UInt)
     with Import, Convention => C, External_Name => "glCreateBuffers";
   procedure Named_Buffer_Storage
     (Buffer : UInt; Size : Sizeiptr; Data : System.Address;
      Flags : Bitfield)
     with Import, Convention => C, External_Name => "glNamedBufferStorage";
   procedure Named_Buffer_Sub_Data
     (Buffer : UInt; Offset : Intptr; Size : Sizeiptr;
      Data : System.Address)
     with Import, Convention => C, External_Name => "glNamedBufferSubData";
   procedure Bind_Buffer (Target : Enum; Buffer : UInt)
     with Import, Convention => C, External_Name => "glBindBuffer";
   procedure Bind_Buffer_Base (Target : Enum; Index, Buffer : UInt)
     with Import, Convention => C, External_Name => "glBindBufferBase";
   procedure Create_Vertex_Arrays (N : Sizei; VAO : out UInt)
     with Import, Convention => C, External_Name => "glCreateVertexArrays";
   procedure Bind_Vertex_Array (VAO : UInt)
     with Import, Convention => C, External_Name => "glBindVertexArray";
   procedure Vertex_Array_Vertex_Buffer
     (VAO, Binding, Buffer : UInt; Offset : Intptr; Stride : Sizei)
     with Import, Convention => C,
          External_Name => "glVertexArrayVertexBuffer";
   procedure Vertex_Array_Attrib_I_Format
     (VAO, Attrib : UInt; Size : int; Kind : Enum; Relative : UInt)
     with Import, Convention => C,
          External_Name => "glVertexArrayAttribIFormat";
   procedure Vertex_Array_Attrib_Binding (VAO, Attrib, Binding : UInt)
     with Import, Convention => C,
          External_Name => "glVertexArrayAttribBinding";
   procedure Enable_Vertex_Array_Attrib (VAO, Attrib : UInt)
     with Import, Convention => C,
          External_Name => "glEnableVertexArrayAttrib";
   procedure Vertex_Array_Binding_Divisor (VAO, Binding, Divisor : UInt)
     with Import, Convention => C,
          External_Name => "glVertexArrayBindingDivisor";
   procedure Draw_Arrays (Mode : Enum; First : int; Count : Sizei)
     with Import, Convention => C, External_Name => "glDrawArrays";
   procedure Multi_Draw_Arrays_Indirect
     (Mode : Enum; Indirect : System.Address; Count, Stride : Sizei)
     with Import, Convention => C,
          External_Name => "glMultiDrawArraysIndirect";

   procedure Create_Textures (Target : Enum; N : Sizei; Texture : out UInt)
     with Import, Convention => C, External_Name => "glCreateTextures";
   procedure Delete_Textures (N : Sizei; Textures : System.Address)
     with Import, Convention => C, External_Name => "glDeleteTextures";
   procedure Texture_Storage_3D
     (Texture : UInt; Levels : Sizei; Format : Enum;
      Width, Height, Depth : Sizei)
     with Import, Convention => C, External_Name => "glTextureStorage3D";
   procedure Texture_Sub_Image_3D
     (Texture : UInt; Level, X, Y, Z : int; Width, Height, Depth : Sizei;
      Format, Kind : Enum; Pixels : System.Address)
     with Import, Convention => C, External_Name => "glTextureSubImage3D";
   procedure Texture_Storage_2D
     (Texture : UInt; Levels : Sizei; Format : Enum; Width, Height : Sizei)
     with Import, Convention => C, External_Name => "glTextureStorage2D";
   procedure Texture_Sub_Image_2D
     (Texture : UInt; Level, X, Y : int; Width, Height : Sizei;
      Format, Kind : Enum; Pixels : System.Address)
     with Import, Convention => C, External_Name => "glTextureSubImage2D";
   procedure Texture_Parameter_I (Texture : UInt; Pname : Enum; Param : int)
     with Import, Convention => C, External_Name => "glTextureParameteri";
   procedure Bind_Texture_Unit (Unit, Texture : UInt)
     with Import, Convention => C, External_Name => "glBindTextureUnit";

   procedure Get_Integer_V (Pname : Enum; Data : out int)
     with Import, Convention => C, External_Name => "glGetIntegerv";
   procedure Create_Framebuffers (N : Sizei; FBO : out UInt)
     with Import, Convention => C, External_Name => "glCreateFramebuffers";
   procedure Delete_Framebuffers (N : Sizei; FBOs : System.Address)
     with Import, Convention => C, External_Name => "glDeleteFramebuffers";
   procedure Create_Renderbuffers (N : Sizei; RB : out UInt)
     with Import, Convention => C, External_Name => "glCreateRenderbuffers";
   procedure Delete_Renderbuffers (N : Sizei; RBs : System.Address)
     with Import, Convention => C, External_Name => "glDeleteRenderbuffers";
   procedure Named_Renderbuffer_Storage_Multisample
     (RB : UInt; Samples : Sizei; Format : Enum; Width, Height : Sizei)
     with Import, Convention => C,
          External_Name => "glNamedRenderbufferStorageMultisample";
   procedure Named_Framebuffer_Renderbuffer (FBO : UInt; Attachment, Target : Enum; RB : UInt)
     with Import, Convention => C, External_Name => "glNamedFramebufferRenderbuffer";
   function Check_Named_Framebuffer_Status (FBO : UInt; Target : Enum) return Enum
     with Import, Convention => C, External_Name => "glCheckNamedFramebufferStatus";
   procedure Bind_Framebuffer (Target : Enum; FBO : UInt)
     with Import, Convention => C, External_Name => "glBindFramebuffer";
   procedure Named_Framebuffer_Texture (FBO : UInt; Attachment : Enum; Texture : UInt; Level : int)
     with Import, Convention => C, External_Name => "glNamedFramebufferTexture";
   procedure Named_Framebuffer_Texture_Layer (FBO : UInt; Attachment : Enum; Texture : UInt; Level, Layer : int)
     with Import, Convention => C, External_Name => "glNamedFramebufferTextureLayer";
   procedure Named_Framebuffer_Draw_Buffer (FBO : UInt; Buf : Enum)
     with Import, Convention => C, External_Name => "glNamedFramebufferDrawBuffer";
   procedure Named_Framebuffer_Read_Buffer (FBO : UInt; Src : Enum)
     with Import, Convention => C, External_Name => "glNamedFramebufferReadBuffer";
   procedure Generate_Texture_Mipmap (Texture : UInt)
     with Import, Convention => C, External_Name => "glGenerateTextureMipmap";
   procedure Polygon_Offset (Factor, Units : Float32)
     with Import, Convention => C, External_Name => "glPolygonOffset";
   procedure Blit_Framebuffer
     (Sx0, Sy0, Sx1, Sy1, Dx0, Dy0, Dx1, Dy1 : int; Mask : Bitfield; Filter : Enum)
     with Import, Convention => C, External_Name => "glBlitFramebuffer";
   procedure Color_Mask (R, G, B, A : Bool)
     with Import, Convention => C, External_Name => "glColorMask";
   procedure Blit_Named_Framebuffer
     (Read_FBO, Draw_FBO : UInt; Sx0, Sy0, Sx1, Sy1, Dx0, Dy0, Dx1, Dy1 : int;
      Mask : Bitfield; Filter : Enum)
     with Import, Convention => C, External_Name => "glBlitNamedFramebuffer";

   procedure Create_Queries (Target : Enum; N : Sizei; Ids : System.Address)
     with Import, Convention => C, External_Name => "glCreateQueries";
   procedure Begin_Query (Target : Enum; Id : UInt)
     with Import, Convention => C, External_Name => "glBeginQuery";
   procedure End_Query (Target : Enum)
     with Import, Convention => C, External_Name => "glEndQuery";
   procedure Get_Query_Object_Iv (Id : UInt; Pname : Enum; Param : out int)
     with Import, Convention => C, External_Name => "glGetQueryObjectiv";
   procedure Get_Query_Object_Ui64v (Id : UInt; Pname : Enum; Param : out unsigned_long_long)
     with Import, Convention => C, External_Name => "glGetQueryObjectui64v";

end Castle.GL;
