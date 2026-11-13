with Castle.Blocks; use Castle.Blocks;
with Castle.Chunks;
with Castle.Water;
with Castle.Math;   use Castle.Math;
with Castle.Rays;

--  What block is where, for picking now and the simulation later: each
--  loaded stack keeps the packed copy of its blocks from its last build,
--  and edits made since then are looked up on top.  Main thread only.
package Castle.World_Blocks is

   procedure Keep (CX, CY : Integer; S : in out Castle.Chunks.Chunk_Stack_Access; Gen : Natural;
                   Summary : in out Castle.Water.Summary_Access);
   --  Takes S and Summary over (they come back null) and drops the stack's
   --  older copies.  Gen: the edit generation S was built at.

   procedure Ground (Bx, By : Integer; C : out Castle.Water.Column; Known : out Boolean);
   function Summary_Of (CX, CY : Integer) return Castle.Water.Summary_Access;   --  kept with the stack; null if none
   --  Where a column's water lies, for the water simulation: its stretches
   --  and the water blocks in each.  Known False: the stack is not loaded.

   procedure Reground (Bx, By, Z_Lo, Z_Hi : Integer);
   --  After an edit of rows Z_Lo .. Z_Hi: read the column's stretches again
   --  (only the rows the edit can have changed are looked at).

   procedure Drop (CX, CY : Integer);

   function Ground_Version (CX, CY : Integer) return Natural;
   --  Changes whenever the stack's ground does (built, edited, dropped);
   --  0 while it is not loaded.  For caches of what the ground means
   --  (Castle.Nav).

   Max_Changed : constant := 48;
   type Changed_Column is record
      Bx, By : Integer := 0;
   end record;
   type Changed_List is array (1 .. Max_Changed) of Changed_Column;

   procedure Changes_Since (CX, CY : Integer; Since : Natural; N : out Natural; Cols : out Changed_List;
                            All_Of_It : out Boolean);
   --  What of stack (CX, CY)'s ground has changed since its version was
   --  Since (as Ground_Version gave it then): the block columns edited
   --  after that, oldest first, a column perhaps more than once.
   --  All_Of_It: it cannot say, and the whole stack must be taken as
   --  changed (it was kept anew or dropped since, or more columns were
   --  edited than it remembers).  For caches that are dear to remake whole
   --  (Castle.Nav's map: an edit changes one cell of 256).

   procedure Note_Edit (Bx, By : Integer);
   --  The main thread edited block column (Bx, By): the stacks that look at
   --  it consult the edit store until they are rebuilt, for that column
   --  alone (Block_At asked the store about every block of an edited stack:
   --  a quarter of the colony's time on the reference band).

   procedure Note_All_Edited;            --  after loading a save

   --  For measuring (colony_run --nav-stats): how often a stack's ground
   --  version moved because a column of it was edited, and because the
   --  stack itself was kept anew or dropped.
   function Stamps_By_Edit return Natural;
   function Stamps_By_Stack return Natural;

   function Block_At (Bx, By, Bz : Integer) return Block;
   --  Air where no stack is loaded.

   subtype Hit is Castle.Rays.Hit;
   --  Found; the block hit (X, Y, Z); the face the ray came in through
   --  (Nx, Ny, Nz); Dist, metres along the ray.

   function Cast (From, Dir : Vec3; Max_M : Float) return Hit;
   --  The first solid block or tree foliage along the ray (metres, Dir a
   --  unit vector); grass, grain and water let it through.

end Castle.World_Blocks;
