with Interfaces;    use Interfaces;
with Castle.Blocks; use Castle.Blocks;
with Castle.Chunks; use Castle.Chunks;

--  Every change made to the generated world, block by block.
--
--  The world is always the generator's output with these written over it,
--  so a save is the seed plus this list.  The main thread records edits;
--  stream workers read a stack's edits under a lock when they rebuild it.
--  Each stack has a generation that every edit touching it, or touching
--  its 1-block rim (which its faces and corner shading look at), advances:
--  a rebuilt mesh can tell whether it is already out of date.
package Castle.Edits is

   procedure Set (Bx, By, Bz : Integer; B : Block);
   --  World block coordinates; outside the world it is ignored.

   procedure Set_Brick (Bx, By, Bz : Integer; M : Material);
   --  The whole 1 m brick holding block (Bx, By, Bz) becomes M: one edit
   --  instead of 64.  Older block edits inside it are dropped (this one is
   --  newer); later block edits inside it win over it.

   function Find (Bx, By, Bz : Integer; B : out Block) return Boolean;

   function Generation (CX, CY : Integer) return Natural;

   type Rim_Edit is record
      X, Y, Z : Integer := 0;           --  stack-local; X or Y is -1 or 32
      Mat     : Material := Air;        --  as it is drawn (Castle.Blocks.Seen_Mat): the rim is the mesher's alone
   end record;
   type Rim_Array is array (Positive range <>) of Rim_Edit;
   type Rim_Access is access Rim_Array;

   procedure Apply (CX, CY : Integer; Work : Stack_Work_Access; Gen : out Natural; Rim : out Rim_Access);
   --  Writes the stack's edits into a freshly generated Work, lowering its
   --  skin and raising Air_From so packing and meshing see them; Gen is the
   --  generation this reflects.  Rim: the edits in the 1-block rim round the
   --  stack, sorted by (X, Y, Z), or null.

   function Rim_Material (R : Rim_Access; X, Y, Z : Integer; M : out Material) return Boolean;
   procedure Free (R : in out Rim_Access);

   procedure Clear;
   function Count return Natural;

   --  Saves: every edit in key order, and putting them all back.
   type Saved_Edit is record
      Brick : Boolean := False;         --  a whole brick (key: stack * 2**14 + brick index)
      Key   : Unsigned_64 := 0;         --  or one block (key: stack * 2**20 + block index)
      B     : Block;
   end record;
   type Saved_Array is array (Positive range <>) of Saved_Edit;
   type Saved_Access is access Saved_Array;

   function All_Edits return Saved_Access;
   --  Bricks first, then blocks, each in key order.
   procedure Restore (E : Saved_Array);   --  replaces every edit; touched stacks advance
   procedure Free (E : in out Saved_Access);

end Castle.Edits;
