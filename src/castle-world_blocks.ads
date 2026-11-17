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

   Small_Summaries : Boolean := True;
   --  A stack's ground summary is kept small (Castle.Water.Small_Summary:
   --  3.7 KB a stack on average where it was 32, nothing lost).  Off
   --  (colony_run --full-summaries, and the game's): kept whole, as it
   --  always was.  It is storage and changes no run: the debug build packs
   --  and unpacks every summary kept and every column rewritten and
   --  compares, and tools/stress.sh runs the crowd both ways.  Set it
   --  before any stack is kept.

   procedure Ground (Bx, By : Integer; C : out Castle.Water.Column; Known : out Boolean);
   function Summary_Of (CX, CY : Integer) return Castle.Water.Summary_Access;
   --  Where a column's water lies, for the water simulation: its stretches
   --  and the water blocks in each.  Known False: the stack is not loaded.
   --  Summary_Of: the stack's whole summary, or null if it is not loaded.
   --  Kept small, it is unpacked into one buffer that the next call
   --  overwrites: read it at once and keep no access to it.

   function Summary_Repacks return Natural;
   --  Times an edit made a stack's small summary be packed again (measuring).

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
   --  unit vector); grass, grain and water let it through, and so does a
   --  cleared roof where less than half of it is drawn (Castle.Rays.Stops):
   --  it is the pointer's ray, and nothing the colony decides may use it.

   --  What is kept of the stacks that are in, counted from the sizes of the
   --  objects and how many of each are allocated (measuring only: colony_run
   --  --mem).  Bytes over every stack kept; the spread is of a stack's
   --  blocks (its array of chunks, their grids, its fine bricks).
   type Stretch_Counts is array (0 .. Castle.Water.Max_Stretch) of Long_Integer;
   type Fine_Counts is array (Castle.Chunks.Brick_Kind) of Long_Integer;
   type Kept_Sizes is record
      Stacks      : Natural := 0;
      Summaries   : Long_Integer := 0;    --  the water summaries
      Arrays      : Long_Integer := 0;
      Grids       : Long_Integer := 0;
      Fine        : Long_Integer := 0;
      Notes       : Long_Integer := 0;    --  what stacks remember of their edits
      Records     : Long_Integer := 0;    --  the record kept for each
      Allocations : Long_Integer := 0;
      Chunks_Fine : Long_Integer := 0;    --  chunks that are not uniform
      Fine_By     : Fine_Counts := (others => 0);
      Fine_Bytes_By : Fine_Counts := (others => 0);   --  and what those of each kind take
      Columns     : Stretch_Counts := (others => 0);   --  block columns by their stretches of open space
      Columns_Wet : Long_Integer := 0;    --  those with water
      Columns_Plain : Long_Integer := 0;  --  those that are one stretch, open to the sky, dry and not source water
      Least, Tenth, Median, Ninetieth, Most : Natural := 0;   --  a stack's blocks, bytes
      Heaviest_CX, Heaviest_CY : Integer := 0;
   end record;
   function Sizes return Kept_Sizes;

end Castle.World_Blocks;
