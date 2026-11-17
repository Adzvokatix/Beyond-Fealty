with Castle.Dims;   use Castle.Dims;
with Castle.Maps;   use Castle.Maps;
with Castle.Mesher; use Castle.Mesher;
with Castle.Chunks;
with Castle.Water;

--  Persistent worker pool for the running game: generate a stack, mesh it,
--  hand the mesh back.  Jobs are served nearest-first and the main thread
--  never waits on a worker.
package Castle.Streaming is

   type Result is record
      CX, CY : Integer := 0;
      M      : Mesh;
      Packed : Castle.Chunks.Chunk_Stack_Access;   --  the stack's blocks, for lookups
      Gen    : Natural := 0;                 --  edit generation the stack was built at
      Summary   : Castle.Water.Summary_Access;   --  where its water lies, for the water simulation
      Water_Ver : Natural := 0;                  --  water version it was built with
      Millis : Float := 0.0;                 --  worker time, generate + mesh
      Meshed : Boolean := True;              --  False: asked for without a mesh (its blocks and summary alone)
      Level  : Natural := 0;                 --  a tile of the far view (Castle.Lod): its level, CX and CY its place among
                                             --  that level's tiles, M its mesh in cells; nothing else of the record
      Edited : Boolean := False;             --  such a tile: one of its stacks has been edited
   end record;
   type Result_Access is access Result;

   Wanted : array (0 .. Chunks_XY - 1, 0 .. Chunks_XY - 1) of Boolean :=
     (others => (others => False))
     with Atomic_Components;
   --  Written by the main thread.  A worker skips a queued stack that is no
   --  longer wanted, so a fast-moving camera doesn't leave a backlog.

   Build_Meshes : Boolean := True;
   --  Off (measuring: colony_run --no-mesh): a worker makes a stack's blocks
   --  and its summary and no mesh.  The runner draws nothing and throws
   --  every mesh away, so its runs come out the same either way; the game
   --  must leave it on.

   procedure Start (W : World; Workers : Positive);
   procedure Request (CX, CY : Integer; Priority : Float;    --  lower first
                      View : Castle.Water.View_Access := null; Water_Ver : Natural := 0;
                      Mesh : Boolean := True);
   --  View: the live water to build the stack with (taken over).
   --  Mesh False: the stack's blocks and its summary alone, for a stack that
   --  is held and not drawn (the game holds the whole map and meshes what is
   --  in view): a sixth of the work.  Such a job is done whether or not the
   --  stack is Wanted, which is the view's word.
   --
   --  Nothing asked for is lost: the queue has room for every stack of the
   --  world twice over, and a worker with a result waits while the ring of
   --  results is full (the main thread takes them as it can).  Before
   --  2026-11-14 the queue held 32,768 and dropped what came after, and a
   --  result that found the ring of 8,192 full was dropped and leaked, both
   --  silently: whoever asked for more than that at once waited for ever.
   procedure Request_Far (Level : Positive; TX, TY : Integer; Priority : Float);
   procedure Poll_Far (R : out Result_Access);                --  null if none
   --  A tile of the far view (Castle.Lod.Build_Tile: its stacks generated,
   --  the edits laid on, reduced and meshed).  Their results wait in a ring
   --  of their own.  A tile of level 4 keeps a worker a fifth of a second.

   function Lost return Natural;
   --  Jobs that found the queue full all the same (never, by its size: a
   --  host says so loudly if it is not 0).
   procedure Poll (R : out Result_Access; Meshed : Boolean := True);   --  null if none
   --  The results of jobs asked for with a mesh and of those asked for
   --  without wait apart, so that what the view asked for is never behind
   --  what is only held.
   function Queued return Natural;
   procedure Stop;
   procedure Free (R : in out Result_Access);

end Castle.Streaming;
