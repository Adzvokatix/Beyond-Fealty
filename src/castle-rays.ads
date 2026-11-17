with Castle.Blocks; use Castle.Blocks;
with Castle.Math;   use Castle.Math;

--  A ray into the blocks: the walk from block to block along it, for
--  whatever answers what block is where (the loaded world, a check's
--  made-up one).
package Castle.Rays is

   type Hit is record
      Found      : Boolean := False;
      X, Y, Z    : Integer := 0;         --  the block hit
      Nx, Ny, Nz : Integer := 0;         --  the face the ray came in through
      Dist       : Float := 0.0;         --  metres along the ray to that face
   end record;

   function Pickable (M : Material) return Boolean;
   --  What stops a ray: solid blocks, foliage and bushes; grass, grain and
   --  water let it through.
   function Stops (M : Material; X, Y, Z : Integer) return Boolean;
   --  Pickable, but for a roof's thatch where a cleared roof is drawn at
   --  less than half, and for whatever stands in a cleared wall's place
   --  (Castle.Cutaway): the pointer goes on through what is not seen.  The
   --  block (X, Y, Z) is M.

   generic
      with function Stops (X, Y, Z : Integer) return Boolean;
   function Walk (From, Dir : Vec3; Max_M : Float) return Hit;
   --  The first block along the ray that Stops (metres, Dir a unit vector),
   --  within Max_M and the world's height.  Amanatides-Woo, in block units.

end Castle.Rays;
