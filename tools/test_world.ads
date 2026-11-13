with Castle.Blocks; use Castle.Blocks;
with Castle.Water;
with Castle.Math;   use Castle.Math;
with Castle.Rays;

--  A made-up world for the headless checks: blocks in a box of 256 x 256
--  columns (64 m square, 8 x 8 stacks) and 64 rows (16 m), air outside it.
--  It answers Castle.Nav and Castle.Colony the way Castle.World_Blocks
--  does in the game: column stretches, blocks, and a version per stack
--  that changes whenever the stack's blocks do.
package Test_World is

   W_B        : constant := 256;
   H_B        : constant := 64;
   Ground_Row : constant := 16;     --  feet stand at 4 m on the meadow
   Ground_M   : constant := 4.0;

   procedure Meadow (Top : Material := Grass);
   --  Dirt to row 14, Top in row 15, air above.

   procedure Fill (X0, Y0, X1, Y1 : Float; Z0, Z1 : Integer; M : Material);
   --  Blocks from (X0, Y0) to (X1, Y1) metres (X1, Y1 excluded), rows Z0 .. Z1.

   procedure Set (Bx, By, Bz : Integer; M : Material);
   function Get (Bx, By, Bz : Integer) return Material;

   procedure Changed_World;   --  every stack's version moves on

   --  The sources, for Castle.Nav.Set_Source and Castle.Colony.Set_World.
   procedure Column (Bx, By : Integer; C : out Castle.Water.Column; Known : out Boolean);
   function Material_At (Bx, By, Bz : Integer) return Material;
   function Block_At (Bx, By, Bz : Integer) return Block;
   procedure Write_Block (Bx, By, Bz : Integer; B : Block);
   function Version (CX, CY : Integer) return Natural;

   procedure Attach;          --  both packages read and write this world

   function Cast (From, Dir : Vec3; Max_M : Float) return Castle.Rays.Hit;
   --  The first block of this world along a ray, as Castle.World_Blocks.Cast
   --  finds it in the game's.

   type Snapshot is private;
   procedure Take (S : out Snapshot);
   procedure Give_Back (S : Snapshot);   --  the blocks as they were (versions move on)

private

   type Grid is array (0 .. W_B - 1, 0 .. W_B - 1, 0 .. H_B - 1) of Material;
   type Snapshot is access Grid;

end Test_World;
