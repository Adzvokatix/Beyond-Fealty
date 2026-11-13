--  Small linear algebra for the camera: column-major 4x4 matrices as
--  OpenGL expects them, and frustum culling of boxes.
package Castle.Math is

   type Vec3 is record
      X, Y, Z : Float := 0.0;
   end record;

   function "+" (A, B : Vec3) return Vec3 is (A.X + B.X, A.Y + B.Y, A.Z + B.Z);
   function "-" (A, B : Vec3) return Vec3 is (A.X - B.X, A.Y - B.Y, A.Z - B.Z);
   function "*" (A : Vec3; S : Float) return Vec3 is (A.X * S, A.Y * S, A.Z * S);
   function Dot (A, B : Vec3) return Float is (A.X * B.X + A.Y * B.Y + A.Z * B.Z);
   function Cross (A, B : Vec3) return Vec3 is
     (A.Y * B.Z - A.Z * B.Y, A.Z * B.X - A.X * B.Z, A.X * B.Y - A.Y * B.X);
   function Normalize (A : Vec3) return Vec3;
   function Heading_Of (V : Vec3; Otherwise : Float) return Float;
   --  The way V points across the ground (radians from +X toward +Y, -pi ..
   --  pi), or Otherwise when it is too short to point anywhere (Arctan (0, 0)
   --  has no answer and raises).

   Fov_Y : constant := 0.96;   --  vertical field of view of the game camera (rad)
   Near_M : constant := 0.2;   --  its near and far planes (metres): the renderer turns the
   Far_M  : constant := 1_600.0;   --  picture's depths back into distances with these

   type Mat4 is array (0 .. 15) of aliased Float;   --  column-major

   function "*" (A, B : Mat4) return Mat4;

   function Perspective (Fovy, Aspect, Near, Far : Float) return Mat4;
   --  OpenGL clip space (z in -1 .. 1), right-handed eye space.

   function Look_Dir (Forward, Up : Vec3) return Mat4;
   --  Rotation-only view matrix: the renderer draws camera-relative, so
   --  the translation is subtracted per vertex instead.

   type Plane is record
      A, B, C, D : Float := 0.0;
   end record;
   type Frustum is array (1 .. 6) of Plane;

   function Planes (M : Mat4) return Frustum;
   function Box_Visible (F : Frustum; Lo, Hi : Vec3) return Boolean;

end Castle.Math;
