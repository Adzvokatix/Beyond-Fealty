with Interfaces;
with Castle.Nav;
with Castle.Colony;

package body Test_World is

   type Grid_Access is access Grid;
   G : constant Grid_Access := new Grid'[others => [others => [others => Air]]];
   --  (each block's state, as the world keeps it: a dressed roof's, a piece's; 0 for whatever is set or
   --  filled by material alone)
   type State_Grid is array (Grid'Range (1), Grid'Range (2), Grid'Range (3)) of Interfaces.Unsigned_8;
   type State_Access is access State_Grid;
   SG : constant State_Access := new State_Grid'[others => [others => [others => 0]]];

   Stacks : constant := W_B / 32;
   Versions : array (0 .. Stacks - 1, 0 .. Stacks - 1) of Natural := [others => [others => 1]];
   Next_V : Natural := 1;

   procedure Changed_World is
   begin
      Next_V := Next_V + 1;
      Versions := [others => [others => Next_V]];
   end Changed_World;

   procedure Bump (Bx, By : Integer) is
   begin
      Next_V := Next_V + 1;
      Versions (Bx / 32, By / 32) := Next_V;
   end Bump;

   function B (M : Float) return Integer is (Integer (Float'Floor (M * 4.0)));

   procedure Meadow (Top : Material := Grass) is
   begin
      for X in G'Range (1) loop
         for Y in G'Range (2) loop
            for Z in G'Range (3) loop
               G (X, Y, Z) := (if Z < Ground_Row - 1 then Dirt elsif Z = Ground_Row - 1 then Top else Air);
               SG (X, Y, Z) := 0;
            end loop;
         end loop;
      end loop;
      Changed_World;
   end Meadow;

   procedure Fill (X0, Y0, X1, Y1 : Float; Z0, Z1 : Integer; M : Material) is
   begin
      for X in Integer'Max (0, B (X0)) .. Integer'Min (W_B - 1, B (X1) - 1) loop
         for Y in Integer'Max (0, B (Y0)) .. Integer'Min (W_B - 1, B (Y1) - 1) loop
            for Z in Integer'Max (0, Z0) .. Integer'Min (H_B - 1, Z1) loop
               G (X, Y, Z) := M;
               SG (X, Y, Z) := 0;
            end loop;
         end loop;
      end loop;
      Changed_World;
   end Fill;

   function Inside (Bx, By, Bz : Integer) return Boolean is
     (Bx in 0 .. W_B - 1 and then By in 0 .. W_B - 1 and then Bz in 0 .. H_B - 1);

   procedure Set (Bx, By, Bz : Integer; M : Material) is
   begin
      if Inside (Bx, By, Bz) then
         G (Bx, By, Bz) := M;
         SG (Bx, By, Bz) := 0;
         Bump (Bx, By);
      end if;
   end Set;

   function Get (Bx, By, Bz : Integer) return Material is
     (if Inside (Bx, By, Bz) then G (Bx, By, Bz) elsif Bz < 0 then Granite else Air);

   procedure Column (Bx, By : Integer; C : out Castle.Water.Column; Known : out Boolean) is
      function Solid (Z : Integer) return Boolean is (Class_Of (G (Bx, By, Z)) = Castle.Blocks.Solid);
      function Wet (Z : Integer) return Boolean is (G (Bx, By, Z) = Castle.Blocks.Water);
      procedure Scan_Here is new Castle.Water.Scan (Solid, Wet);
   begin
      if Bx not in 0 .. W_B - 1 or else By not in 0 .. W_B - 1 then
         C := (N => 0, S => [others => (0, 0, 0)], others => <>);
         Known := False;
         return;
      end if;
      Scan_Here (H_B - 1, 0, C);
      Known := True;
   end Column;

   function Material_At (Bx, By, Bz : Integer) return Material is (Get (Bx, By, Bz));
   function Block_At (Bx, By, Bz : Integer) return Block is
     ((Mat => Get (Bx, By, Bz), State => (if Inside (Bx, By, Bz) then SG (Bx, By, Bz) else 0)));

   procedure Write_Block (Bx, By, Bz : Integer; B : Block) is
   begin
      Set (Bx, By, Bz, B.Mat);
      if Inside (Bx, By, Bz) then
         SG (Bx, By, Bz) := B.State;
      end if;
   end Write_Block;

   function Version (CX, CY : Integer) return Natural is
     (if CX in Versions'Range (1) and then CY in Versions'Range (2) then Versions (CX, CY) else 0);

   procedure Attach is
   begin
      Castle.Nav.Set_Source (Column'Access, Material_At'Access, Version'Access);
      Castle.Colony.Set_World (Block_At'Access, Write_Block'Access, Version'Access);
   end Attach;

   function Stops_Ray (X, Y, Z : Integer) return Boolean is (Castle.Rays.Stops (Get (X, Y, Z), X, Y, Z));
   function Walk_Blocks is new Castle.Rays.Walk (Stops_Ray);
   function Cast (From, Dir : Vec3; Max_M : Float) return Castle.Rays.Hit is (Walk_Blocks (From, Dir, Max_M));

   procedure Take (S : out Snapshot) is
   begin
      S := new Grid'(G.all);
   end Take;

   procedure Give_Back (S : Snapshot) is
   begin
      G.all := S.all;
      Changed_World;
   end Give_Back;

end Test_World;
