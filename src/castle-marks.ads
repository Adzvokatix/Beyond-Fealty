with Interfaces;
with Castle.Math; use Castle.Math;

--  Flat strips laid over the ground to show things in the world: for now
--  the routes serfs mean to take (F6) and the walking map (F7).  Gathered
--  on the CPU each frame like Castle.Figures and drawn by Castle.Render in
--  one call, see-through, after the people.  Main thread only.
package Castle.Marks is

   Max_Marks : constant := 32_768;

   type Colour is record
      R, G, B, A : Float := 1.0;
   end record;

   procedure Begin_Frame;
   procedure Strip (From, To : Vec3; Width : Float; C : Colour; Of_Ground : Boolean := False);
   --  A strip Width wide from From to To, lying level across (it may climb
   --  along its length); its ends run on half its width so strips joined end
   --  to end leave no gaps at the bends.  Of_Ground: it is something of the
   --  world's (a zone's ground filled in) and dims with the daylight, where
   --  the developer's marks keep their colour at night.

   ------------------------------------------------------- for the renderer

   subtype F32 is Interfaces.IEEE_Float_32;
   type GPU_Mark is record                --  std430: three vec4s
      Ax, Ay, Az, W  : F32 := 0.0;
      Bx, By, Bz, Dim : F32 := 0.0;     --  Dim 1: it dims with the daylight
      R, G, B, A     : F32 := 0.0;
   end record with Convention => C;
   type Mark_Array is array (Natural range <>) of aliased GPU_Mark with Convention => C;

   Marks : Mark_Array (0 .. Max_Marks - 1);
   Count : Natural := 0;

end Castle.Marks;
