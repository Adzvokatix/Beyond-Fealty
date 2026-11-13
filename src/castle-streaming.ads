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
   end record;
   type Result_Access is access Result;

   Wanted : array (0 .. Chunks_XY - 1, 0 .. Chunks_XY - 1) of Boolean :=
     (others => (others => False))
     with Atomic_Components;
   --  Written by the main thread.  A worker skips a queued stack that is no
   --  longer wanted, so a fast-moving camera doesn't leave a backlog.

   procedure Start (W : World; Workers : Positive);
   procedure Request (CX, CY : Integer; Priority : Float;    --  lower first
                      View : Castle.Water.View_Access := null; Water_Ver : Natural := 0);
   --  View: the live water to build the stack with (taken over).
   procedure Poll (R : out Result_Access);                    --  null if none
   function Queued return Natural;
   procedure Stop;
   procedure Free (R : in out Result_Access);

end Castle.Streaming;
