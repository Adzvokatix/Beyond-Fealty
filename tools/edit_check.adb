with Ada.Directories;
with Ada.Streams;            use Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Ada.Text_IO;            use Ada.Text_IO;
with Castle.Blocks;          use Castle.Blocks;
with Castle.Chunks;          use Castle.Chunks;
with Castle.Edits;
with Castle.Hash;
with Castle.Maps;            use Castle.Maps;
with Castle.Mesher;
with Castle.Saves;
with Castle.Text;            use Castle.Text;
with Castle.Worldgen;

--  Checks editing and saving end to end, without a window: packed lookups
--  agree with the generator, workers rebuild stacks with their edits (deep
--  ones too), edits on a border reach the neighbour, meshes grow faces for
--  them, and saves come back exactly or are refused when damaged.
procedure Edit_Check is
   use type Castle.Edits.Rim_Access;
   use type Castle.Edits.Saved_Array;
   use type Castle.Hash.U64;
   use type Castle.Mesher.Quad_Access;

   W     : World;
   Work  : constant Stack_Work_Access := new Stack_Work;
   Fails : Natural := 0;
   CX    : constant := 148;                  --  under the default view
   CY    : constant := 136;

   procedure Check (Ok : Boolean; What : String) is
   begin
      Put_Line ((if Ok then "  ok    " else "  FAIL  ") & What);
      if not Ok then
         Fails := Fails + 1;
      end if;
   end Check;

   function Quads (M : Castle.Mesher.Mesh) return Natural is
     ((if M.Solid = null then 0 else M.Solid'Length) + (if M.Water = null then 0 else M.Water'Length));

   procedure Rebuild (M : out Castle.Mesher.Mesh; Gen : out Natural) is
      Rim : Castle.Edits.Rim_Access;
   begin
      Generate (W, CX, CY, Work.all);
      declare
         Old_Skin : constant Skin_Grid := Work.Skin;
      begin
         Castle.Edits.Apply (CX, CY, Work, Gen, Rim);
         Deepen (W, CX, CY, Work.all, Old_Skin);
      end;
      Castle.Mesher.Build (W, CX, CY, Work.all, M, Rim);
      Castle.Edits.Free (Rim);
   end Rebuild;

   Zt : Integer := 0;                       --  top solid block of column (10, 12)
   Bx : constant Integer := CX * 32 + 10;
   By : constant Integer := CY * 32 + 12;
   Clean : Castle.Mesher.Mesh;
   Gen   : Natural;
begin
   Castle.Worldgen.Create (Castle.Hash.U64 (1), W, Report => False);
   Put_Line ("editing and saves, seed 1, stack" & CX'Image & "," & CY'Image);

   --  1. The packed copy reads back what the generator made.
   Rebuild (Clean, Gen);
   declare
      S         : Chunk_Stack_Access := new Chunk_Stack;
      Bad, Seen : Natural := 0;
   begin
      Pack (Work.all, S.all);
      for X in 0 .. 31 loop
         for Y in 0 .. 31 loop
            for Z in Work.Skin (X / 4, Y / 4) * 4 .. Work.Air_From + 8 loop
               Seen := Seen + 1;
               if Block_In (S.all, X, Y, Z) /= Work.G (X, Y, Z) then
                  Bad := Bad + 1;
               end if;
            end loop;
         end loop;
      end loop;
      Check (Bad = 0, "packed stack reads back all" & Seen'Image & " blocks from the skin up");
      Free (S);
   end;
   for Z in reverse 0 .. Work.Air_From loop
      if Class_Of (Work.G (10, 12, Z).Mat) = Solid then
         Zt := Z;
         exit;
      end if;
   end loop;

   --  2. Edits come back in a rebuilt stack: a dug block, one placed in
   --  the air, and a pocket dug 10 m down, well below the skin.
   declare
      G0  : constant Natural := Castle.Edits.Generation (CX, CY);
      M   : Castle.Mesher.Mesh;
      S   : Chunk_Stack_Access := new Chunk_Stack;
   begin
      Castle.Edits.Set (Bx, By, Zt, Air_Block);
      Castle.Edits.Set (Bx, By, Zt + 20, (Mat => Plank, State => 0));
      Castle.Edits.Set (Bx + 1, By, Zt - 40, Air_Block);
      Check (Castle.Edits.Generation (CX, CY) = G0 + 3, "each edit advances its stack's generation");
      Rebuild (M, Gen);
      Check (Gen = G0 + 3, "a rebuild reports the generation it reflects");
      Check (Work.G (10, 12, Zt).Mat = Air and then Work.G (10, 12, Zt + 20).Mat = Plank
             and then Work.G (11, 12, Zt - 40).Mat = Air, "a rebuilt stack carries its three edits");
      Check (Class_Of (Work.G (12, 12, Zt - 40).Mat) = Solid and then Work.G (12, 12, Zt - 40).Mat /= Deep
             and then Work.G (11, 12, Zt - 41).Mat /= Deep,
             "the deep pocket's walls and floor are real rock (" & Material'Image (Work.G (12, 12, Zt - 40).Mat)
             & ", " & Material'Image (Work.G (11, 12, Zt - 41).Mat) & "), not Deep");
      Check (Work.Air_From > Zt + 20, "a block placed in the air raises the stack's top");
      Check (Work.Skin (11 / 4, 12 / 4) <= (Zt - 40) / 4, "a dig 10 m down lowers the skin for that column");
      Pack (Work.all, S.all);
      Check (Block_In (S.all, 11, 12, Zt - 40).Mat = Air and then Block_In (S.all, 10, 12, Zt + 20).Mat = Plank,
             "the packed copy keeps the deep dig and the placed block");
      Free (S);
      Check (Quads (M) > Quads (Clean), "the mesh grows faces for them ("
             & Img (Quads (Clean)) & " -> " & Img (Quads (M)) & " quads)");
      Castle.Mesher.Free (M);
   end;

   --  3. An edit on the neighbour's edge reaches this stack's rim, and so
   --  does a whole brick there.
   declare
      G0  : constant Natural := Castle.Edits.Generation (CX, CY);
      Rim : Castle.Edits.Rim_Access;
      Mat : Material;
   begin
      Castle.Edits.Set ((CX + 1) * 32, By, Zt, Air_Block);         --  x = 0 of the stack east
      Check (Castle.Edits.Generation (CX, CY) = G0 + 1, "an edit on the neighbour's edge advances this stack too");
      Generate (W, CX, CY, Work.all);
      Castle.Edits.Apply (CX, CY, Work, Gen, Rim);
      Check (Rim /= null and then Castle.Edits.Rim_Material (Rim, 32, 12, Zt, Mat) and then Mat = Air,
             "and arrives in its rim at x = 32");
      Castle.Edits.Free (Rim);
      Castle.Edits.Set_Brick (CX * 32 - 4, By, Zt, Plank);          --  the stack west, at its east edge
      Generate (W, CX, CY, Work.all);
      Castle.Edits.Apply (CX, CY, Work, Gen, Rim);
      Check (Castle.Edits.Rim_Material (Rim, -1, 12, Zt, Mat) and then Mat = Plank
             and then not Castle.Edits.Rim_Material (Rim, -2, 12, Zt, Mat),
             "a neighbour's brick on the edge reaches the rim, and only its edge column");
      Castle.Edits.Free (Rim);
   end;

   --  4. A whole brick in one edit; a later block inside it wins.
   declare
      Rim : Castle.Edits.Rim_Access;
      B   : Block;
      N0  : constant Natural := Castle.Edits.Count;
      Bz  : constant Integer := (Zt / 4) * 4 - 4;          --  the brick under the top one
   begin
      Castle.Edits.Set_Brick (CX * 32 + 16, CY * 32 + 16, Bz, Air);
      Castle.Edits.Set (CX * 32 + 17, CY * 32 + 17, Bz + 1, (Mat => Shingle, State => 0));
      Check (Castle.Edits.Count = N0 + 2, "a brick is one edit, a block inside it another");
      Generate (W, CX, CY, Work.all);
      Castle.Edits.Apply (CX, CY, Work, Gen, Rim);
      Castle.Edits.Free (Rim);
      Check (Work.G (16, 16, Bz).Mat = Air and then Work.G (19, 19, Bz + 3).Mat = Air
             and then Work.G (17, 17, Bz + 1).Mat = Shingle, "the brick is dug out, the newer block inside it stays");
      Check (Castle.Edits.Find (CX * 32 + 18, CY * 32 + 18, Bz + 2, B) and then B.Mat = Air,
             "a lookup inside the brick finds the brick edit");
      Castle.Edits.Set_Brick (CX * 32 + 16, CY * 32 + 16, Bz, Dirt);
      Check (Castle.Edits.Count = N0 + 1, "a newer brick edit drops the older block edits inside it");
      Castle.Edits.Set_Brick (CX * 32 + 16, CY * 32 + 16, Bz, Air);
   end;

   --  5. Saves come back exactly, and damaged ones are refused.
   declare
      Path   : constant String := "/tmp/edit_check.castle";
      Before : Castle.Edits.Saved_Access := Castle.Edits.All_Edits;
      After  : Castle.Edits.Saved_Access;
      S      : Castle.Saves.Snapshot;
      Err    : Unbounded_String;
      Seed   : Castle.Hash.U64;
   begin
      S.Seed := 1;
      S.Clock := 1_234.5;
      S.Cam_X := 1_184.0;
      S.Cam_Dist := 70.0;
      Castle.Saves.Save (Path, S, Err);
      Check (Err = Null_Unbounded_String, "save writes " & Path & " ("
             & Img (Natural (Ada.Directories.Size (Path))) & " bytes for" & Before'Length'Image & " edits)");
      Check (not Ada.Directories.Exists (Path & ".tmp"), "the temporary file was renamed into place");
      Castle.Edits.Clear;
      Check (Castle.Edits.Count = 0, "edits cleared");
      Castle.Saves.Peek (Path, Seed, Err);
      Check (Err = Null_Unbounded_String and then Seed = 1, "peek reads the seed back");
      Castle.Saves.Load (Path, S, Err);
      After := Castle.Edits.All_Edits;
      Check (Err = Null_Unbounded_String and then S.Clock = 1_234.5 and then S.Cam_X = 1_184.0
             and then S.Cam_Dist = 70.0, "load restores the clock and camera");
      Check (After.all = Before.all, "load restores every edit exactly");
      Castle.Edits.Free (Before);
      Castle.Edits.Free (After);

      --  one flipped byte, then a cut-off file
      declare
         use Ada.Streams.Stream_IO;
         F    : Ada.Streams.Stream_IO.File_Type;
         N    : constant Stream_Element_Offset := Stream_Element_Offset (Ada.Directories.Size (Path));
         Data : Stream_Element_Array (1 .. N);
         Got  : Stream_Element_Offset;
      begin
         Open (F, In_File, Path);
         Read (F, Data, Got);
         Close (F);
         Data (N / 2) := Data (N / 2) xor 16#40#;
         Create (F, Out_File, "/tmp/edit_bad.castle");
         Write (F, Data);
         Close (F);
         Castle.Saves.Load ("/tmp/edit_bad.castle", S, Err);
         Check (Index (Err, "damaged") > 0, "a flipped byte is caught: " & To_String (Err));
         Data (N / 2) := Data (N / 2) xor 16#40#;
         Create (F, Out_File, "/tmp/edit_short.castle");
         Write (F, Data (1 .. N - 9));
         Close (F);
         Castle.Saves.Load ("/tmp/edit_short.castle", S, Err);
         Check (Err /= Null_Unbounded_String, "a cut-off file is refused: " & To_String (Err));
      end;
   end;

   Castle.Mesher.Free (Clean);
   if Fails = 0 then
      Put_Line ("all checks passed");
   else
      Put_Line (Img (Fails) & " checks FAILED");
   end if;

   --  The veins nearest the default view, for the visual test.
   for K in Deposit_Kind range Coal_Vein .. Iron_Vein loop
      declare
         Best : Natural := 0;
         D2   : Float := Float'Last;
      begin
         for I in W.Deposits'Range loop
            if W.Deposits (I).Kind = K then
               declare
                  D : constant Float := (W.Deposits (I).Cx - 1_184.0) ** 2 + (W.Deposits (I).Cy - 1_088.0) ** 2;
               begin
                  if D < D2 then
                     D2 := D;
                     Best := I;
                  end if;
               end;
            end if;
         end loop;
         if Best > 0 then
            Put_Line ("nearest " & Deposit_Kind'Image (K) & ": outcrop at " & Img (W.Deposits (Best).Cx, 0) & ","
                      & Img (W.Deposits (Best).Cy, 0) & ", heading " & Img (W.Deposits (Best).Ca, 2) & ","
                      & Img (W.Deposits (Best).Sa, 2) & ", reach " & Img (W.Deposits (Best).Reach, 0)
                      & " m, deepest cover " & Img (W.Deposits (Best).Deepest, 0) & " m");
         end if;
      end;
   end loop;
end Edit_Check;
