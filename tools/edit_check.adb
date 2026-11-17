with Ada.Directories;
with Ada.Streams;            use Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;  use Ada.Strings.Unbounded;
with Ada.Text_IO;            use Ada.Text_IO;
with Castle.Blocks;          use Castle.Blocks;
with Castle.Chunks;          use Castle.Chunks;
with Ada.Calendar;
with Castle.Dims;
with Castle.Far;
with Castle.Fields;
with Castle.Flora;
with Castle.Geology;
with Castle.Lod;
with Castle.Textures;
with Castle.Edits;
with Castle.Hash;
with Castle.Maps;            use Castle.Maps;
with Castle.Mesher;
with Castle.Saves;
with Castle.Text;            use Castle.Text;
with Castle.Water;
with Castle.World_Blocks;
with Castle.Worldgen;
with Interfaces;

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

   --  A stack's ground summary kept small (John, 2026-11-14: "Sure build the
   --  compact summary"): nothing lost, read and written a column at a time.
   Put_Line ("a stack's ground summary kept small:");
   declare
      use Castle.Water;
      use type Interfaces.Integer_16;
      use type Interfaces.Integer_32;
      use type Interfaces.Unsigned_8;
      type Summary_Ptr is access Ground_Summary;
      Full : constant Summary_Ptr := new Ground_Summary;
      Back : constant Summary_Ptr := new Ground_Summary;
      Sky  : constant Interfaces.Integer_16 := Interfaces.Integer_16 (Castle.Dims.Height_B);   --  open to the sky
      Seed : Castle.Hash.U64 := 16#5EED#;
      function Next return Natural is
      begin
         Seed := Castle.Hash.Mix (Seed + 1);
         return Natural (Seed mod 1_000_000);
      end Next;
      --  a column of any kind: plain mostly, else none to four stretches, wet or dry, flowing or not
      function Any return Short_Column is
         C : Short_Column;
         R : constant Natural := Next mod 100;
         Z : Interfaces.Integer_16 := Sky;
      begin
         if R < 70 then
            C.N := 1;
            C.S (1) := (Floor => Interfaces.Integer_16 (Next mod 200), Ceil => Sky, Water => 0);
            return C;
         end if;
         C.N := Interfaces.Unsigned_8 (Next mod 5);
         C.Flowing := Next mod 3 = 0;
         C.Rest := (case Next mod 4 is
                       when 0 => 0, when 1 => Interfaces.Integer_32 (Next), when 2 => -Interfaces.Integer_32 (Next),
                       when others => Interfaces.Integer_32'Last - Interfaces.Integer_32 (Next mod 7));
         for I in 1 .. Natural (C.N) loop
            C.S (I).Ceil := Z;
            Z := Z - Interfaces.Integer_16 (1 + Next mod 40);
            C.S (I).Floor := Z;
            C.S (I).Water := Interfaces.Integer_16 (Next mod 3) * Interfaces.Integer_16 (Next mod 9);
            Z := Z - Interfaces.Integer_16 (1 + Next mod 20);
         end loop;
         return C;
      end Any;
      function Same_By_Column (S : Small_Summary; F : Ground_Summary) return Boolean is
        (for all X in F'Range (1) => (for all Y in F'Range (2) => Column_Of (S, X, Y) = F (X, Y)));
   begin
      --  real ground: the stack under the view, one of forest, one with the river in it
      declare
         type Place is record
            X, Y : Integer;
         end record;
         Places : constant array (1 .. 4) of Place := [(CX, CY), (148, 124), (150, 128), (172, 208)];
         All_Same, All_Small : Boolean := True;
         Most, Least : Natural := 0;
         Plain_N, Cols : Natural := 0;
      begin
         Least := Natural'Last;
         for P of Places loop
            Generate (W, P.X, P.Y, Work.all);
            Summarize (Work.all, Full.all);
            declare
               S : Small_Access := Shrink (Full.all);
            begin
               Expand (S.all, Back.all);
               All_Same := All_Same and then Back.all = Full.all and then Same_By_Column (S.all, Full.all);
               All_Small := All_Small and then Bytes_Of (S.all) < Ground_Summary'Size / 8 / 2;
               Most := Natural'Max (Most, Bytes_Of (S.all));
               Least := Natural'Min (Least, Bytes_Of (S.all));
               for X in Full'Range (1) loop
                  for Y in Full'Range (2) loop
                     Cols := Cols + 1;
                     if Is_Plain (Full (X, Y)) then
                        Plain_N := Plain_N + 1;
                     end if;
                  end loop;
               end loop;
               Free (S);
            end;
         end loop;
         Check (All_Same,
                "four stacks of the world (open land, forest, the river, a mountain forest): each summary kept small"
                & " unpacks to the very summary, and reads the same column by column");
         Check (All_Small and then Plain_N * 10 > Cols * 7,
                "and takes" & Least'Image & " to" & Most'Image & " bytes where it took"
                & Natural'Image (Ground_Summary'Size / 8) & " (" & Img (100.0 * Float (Plain_N) / Float (Cols), 0)
                & " % of their columns plain: one stretch, open to the sky, dry)");
      end;
      --  made-up columns of every kind
      declare
         S : Small_Access;
         By_N : array (0 .. 4) of Natural := [others => 0];
         Plain_N, Neg_Rest, Big_Rest, Flowing_N : Natural := 0;
      begin
         for X in Full'Range (1) loop
            for Y in Full'Range (2) loop
               Full (X, Y) := Any;
               By_N (Natural (Full (X, Y).N)) := By_N (Natural (Full (X, Y).N)) + 1;
               Plain_N := Plain_N + (if Is_Plain (Full (X, Y)) then 1 else 0);
               Neg_Rest := Neg_Rest + (if Full (X, Y).Rest < 0 then 1 else 0);
               Big_Rest := Big_Rest + (if Full (X, Y).Rest > 16#7FFF_0000# then 1 else 0);
               Flowing_N := Flowing_N + (if Full (X, Y).Flowing then 1 else 0);
            end loop;
         end loop;
         Full (0, 0) := (N => 1, Flowing => False, Rest => 0, S => [1 => (0, Sky, 0), others => (0, 0, 0)]);  --  floor 0
         Full (0, 1) := (N => 1, Flowing => False, Rest => 5, S => [1 => (40, Sky, 0), others => (0, 0, 0)]); --  a rest alone
         Full (0, 2) := (N => 1, Flowing => True, Rest => 0, S => [1 => (40, Sky, 0), others => (0, 0, 0)]);  --  flowing alone
         Full (0, 3) := (N => 1, Flowing => False, Rest => 0, S => [1 => (40, Sky, 3), others => (0, 0, 0)]); --  water alone
         Full (0, 4) := (N => 1, Flowing => False, Rest => 0, S => [1 => (40, 90, 0), others => (0, 0, 0)]);  --  a roof alone
         S := Shrink (Full.all);
         Expand (S.all, Back.all);
         Check (Back.all = Full.all and then Same_By_Column (S.all, Full.all)
                and then (for all N of By_N => N > 0) and then Plain_N > 500 and then Neg_Rest > 10 and then Big_Rest > 10
                and then Flowing_N > 10
                and then not Is_Plain (Full (0, 1)) and then not Is_Plain (Full (0, 2)) and then not Is_Plain (Full (0, 3))
                and then not Is_Plain (Full (0, 4)) and then Is_Plain (Full (0, 0)),
                "a made-up summary with columns of every kind (none to four stretches, water, source water, rest levels"
                & " of every sign and size, a roof over one stretch): the same back, in" & Bytes_Of (S.all)'Image & " bytes");
         --  written a column at a time, against the whole summary written the same
         declare
            In_Plain, In_Words, Again_N, Wrong : Natural := 0;
            Tight : Boolean := True;
         begin
            for K in 1 .. 4_000 loop
               declare
                  X : constant Integer := Next mod 32;
                  Y : constant Integer := Next mod 32;
                  --  (often a column like the one that is there: the cases that are written in place)
                  Was : constant Short_Column := Full (X, Y);
                  C : Short_Column := Any;
                  Again : Boolean;
               begin
                  if Next mod 3 = 0 and then not Is_Plain (Was) and then Was.N > 0 then
                     C := Was;
                     C.S (1).Water := C.S (1).Water + 1;
                     C.Flowing := not C.Flowing;
                     C.Rest := C.Rest / 2 - 3;
                  end if;
                  Full (X, Y) := C;
                  Set_Column (S, X, Y, C, Again);
                  if Again then
                     Again_N := Again_N + 1;
                  elsif Is_Plain (C) then
                     In_Plain := In_Plain + 1;
                  else
                     In_Words := In_Words + 1;
                  end if;
                  if K mod 16 = 0 or else K > 3_900 then
                     Expand (S.all, Back.all);
                     if Back.all /= Full.all then
                        Wrong := Wrong + 1;
                     end if;
                     declare
                        T : Small_Access := Shrink (Full.all);
                     begin
                        Tight := Tight and then Bytes_Of (T.all) = Bytes_Of (S.all);
                        Free (T);
                     end;
                  end if;
               end;
            end loop;
            Check (Wrong = 0 and then In_Plain > 300 and then In_Words > 300 and then Again_N > 300,
                   "four thousand columns written one at a time:" & In_Plain'Image & " plain over plain," & In_Words'Image
                   & " over their own words," & Again_N'Image & " by packing the summary again; it is the whole summary"
                   & " written the same, every time looked");
            Check (Tight, "and it never takes a byte more than that summary packed afresh");
         end;
         Free (S);
      end;
      --  through the kept blocks: small and whole answer the same, before an edit and after
      declare
         type Cols is array (0 .. 31, 0 .. 31) of Column;
         type Cols_Ptr is access Cols;
         A, B : constant Cols_Ptr := new Cols;
         SX : constant := 150;
         SY : constant := 128;
         Known_All : Boolean := True;
         procedure Keep_And_Read (Small : Boolean; Into : Cols_Ptr; Repacks : out Natural) is
            Packed : Chunk_Stack_Access := new Chunk_Stack;
            Sum    : Summary_Access := new Ground_Summary;
            Gen    : Natural;
            Rim    : Castle.Edits.Rim_Access;
            Known  : Boolean;
            R0     : constant Natural := Castle.World_Blocks.Summary_Repacks;
         begin
            Castle.Edits.Clear;
            Castle.World_Blocks.Small_Summaries := Small;
            Generate (W, SX, SY, Work.all);
            Castle.Edits.Apply (SX, SY, Work, Gen, Rim);
            Castle.Edits.Free (Rim);
            Summarize (Work.all, Sum.all);
            Pack (Work.all, Packed.all);
            Castle.World_Blocks.Keep (SX, SY, Packed, Gen, Sum);
            --  a pit dug four blocks deep into dry ground, a column walled up to the sky's foot, a
            --  block put into the river: each told to the kept blocks as the game tells them
            for Bx in SX * 32 + 3 .. SX * 32 + 6 loop
               for By in SY * 32 + 3 .. SY * 32 + 6 loop
                  declare
                     C : Column;
                  begin
                     Castle.World_Blocks.Ground (Bx, By, C, Known);
                     for Z in C.S (1).Floor - 4 .. C.S (1).Floor - 1 loop
                        Castle.Edits.Set (Bx, By, Z, Air_Block);
                        Castle.World_Blocks.Note_Edit (Bx, By);
                        Castle.World_Blocks.Reground (Bx, By, Z, Z);
                     end loop;
                     if Bx = SX * 32 + 6 then
                        for Z in C.S (1).Floor + 6 .. C.S (1).Floor + 8 loop      --  a lintel over it: two stretches
                           Castle.Edits.Set (Bx, By, Z, (Mat => Plank, State => 0));
                           Castle.World_Blocks.Note_Edit (Bx, By);
                           Castle.World_Blocks.Reground (Bx, By, Z, Z);
                        end loop;
                     end if;
                  end;
               end loop;
            end loop;
            for X in 0 .. 31 loop
               for Y in 0 .. 31 loop
                  Castle.World_Blocks.Ground (SX * 32 + X, SY * 32 + Y, Into (X, Y), Known);
                  Known_All := Known_All and then Known;
               end loop;
            end loop;
            Repacks := Castle.World_Blocks.Summary_Repacks - R0;
            Castle.World_Blocks.Drop (SX, SY);
         end Keep_And_Read;
         RA, RB : Natural;
         Two : Natural := 0;
      begin
         Keep_And_Read (True, A, RA);
         Keep_And_Read (False, B, RB);
         Castle.World_Blocks.Small_Summaries := True;
         Castle.Edits.Clear;
         for X in 0 .. 31 loop
            for Y in 0 .. 31 loop
               Two := Two + (if A (X, Y).N >= 2 then 1 else 0);
            end loop;
         end loop;
         Check (Known_All and then A.all = B.all and then RA > 0 and then RB = 0 and then Two >= 4,
                "a stack kept by the game's own calls, a pit dug in it and a lintel laid over one side: every column"
                & " answers the same with its summary small and whole (" & RA'Image & " packings again;" & Two'Image
                & " columns of two stretches or more)");
      end;
   end;

   --  A chunk's fine bricks kept small (2026-11-14): a brick of up to sixteen
   --  different blocks is those blocks and, for each place, which; of more,
   --  whole.  Nothing lost, whatever a brick holds.
   Put_Line ("fine bricks kept small:");
   declare
      Mats : constant array (0 .. 9) of Material :=
        [Air, Dirt, Grass, Granite, Leaves, Log, Tall_Grass, Castle.Blocks.Water, Thatch, Boulder];
      --  the brick at the top of what the stack holds, at brick column (I, J): filled with N different blocks
      function Top_M return Integer is ((Work.Air_From - 1) / 4);
      procedure Fill_Brick (I, J : Integer; N : Positive) is
         P : Natural := 0;
      begin
         for X in 0 .. 3 loop
            for Y in 0 .. 3 loop
               for Z in 0 .. 3 loop
                  --  (the first N places each another block, the rest going round them: a state
                  --  where the materials run out, so a block is its material and its state)
                  Work.G (4 * I + X, 4 * J + Y, 4 * Top_M + Z) :=
                    (Mat => Mats ((P mod N) mod 10), State => Interfaces.Unsigned_8 ((P mod N) / 10));
                  P := P + 1;
               end loop;
            end loop;
         end loop;
      end Fill_Brick;
      Kinds : constant array (0 .. 7) of Positive := [2, 3, 4, 5, 15, 16, 17, 64];
      function All_Back (S : Chunk_Stack) return Natural is
         Bad : Natural := 0;
      begin
         for X in 0 .. 31 loop
            for Y in 0 .. 31 loop
               for Z in Work.Skin (X / 4, Y / 4) * 4 .. Work.Air_From + 8 loop
                  if Block_In (S, X, Y, Z) /= Work.G (X, Y, Z) then
                     Bad := Bad + 1;
                  end if;
               end loop;
            end loop;
         end loop;
         return Bad;
      end All_Back;
      Small, Whole : Chunk_Stack_Access := new Chunk_Stack;
      Bad_S, Bad_W : Natural;
      ZS, ZW : Stack_Sizes;
      Whole_Back : Boolean := True;
   begin
      Castle.Edits.Clear;
      Generate (W, 148, 124, Work.all);                  --  forest: trees, plants, the ground under them
      for N in Kinds'Range loop
         Fill_Brick (N, 0, Kinds (N));
      end loop;
      Castle.Chunks.Small_Bricks := True;
      Pack (Work.all, Small.all);
      Castle.Chunks.Small_Bricks := False;
      Pack (Work.all, Whole.all);
      Castle.Chunks.Small_Bricks := True;
      Bad_S := All_Back (Small.all);
      Bad_W := All_Back (Whole.all);
      ZS := Sizes_Of (Small.all);
      ZW := Sizes_Of (Whole.all);
      for N in Kinds'Range loop
         declare
            C : Chunk renames Small (4 * Top_M / 32);
            F : constant Fine_Brick := Fine_At (C, N, 0, Top_M mod 8);
         begin
            for X in 0 .. 3 loop
               for Y in 0 .. 3 loop
                  for Z in 0 .. 3 loop
                     Whole_Back := Whole_Back and then F (X, Y, Z) = Work.G (4 * N + X, 4 * 0 + Y, 4 * Top_M + Z);
                  end loop;
               end loop;
            end loop;
         end;
      end loop;
      Check (Bad_S = 0 and then Bad_W = 0 and then Whole_Back,
             "a stack of forest with bricks made up of 2, 3, 4, 5, 15, 16, 17 and 64 different blocks: every block"
             & " reads back, kept small and written whole");
      Check (ZS.Fine = ZW.Fine and then ZS.Bytes_Fine * 4 < ZW.Bytes_Fine and then ZS.Bytes_Grids = ZW.Bytes_Grids,
             "its fine bricks take" & ZS.Bytes_Fine'Image & " bytes kept small where they take" & ZW.Bytes_Fine'Image
             & " whole, and are the same bricks by what they hold");
      Free (Small);
      Free (Whole);
   end;

   ------------------------------------------------------------------ the far view
   --  The world at coarser blocks (Castle.Lod): how eight cells become one, how a tile's cells are meshed,
   --  and that a tile is the world as it is, edits and all.
   Put_Line ("the far view:");
   declare
      use Castle.Lod;
      use type Interfaces.Unsigned_32;
      S : constant Scratch_Access := new Scratch;

      function Count (Q : Castle.Mesher.Quad_Access) return Natural is (if Q = null then 0 else Q'Length);

      --  A mesh's quads, hashed in their order; Ok: every one of them lies inside its tile.
      function Hash_Of (M : Castle.Mesher.Mesh; Ok : out Boolean) return Interfaces.Unsigned_64 is
         H : Interfaces.Unsigned_64 := 14695981039346656037;
         procedure Take (Q : Castle.Mesher.Quad) is
            X  : constant Integer := Integer (Q.W0 and 31);
            Y  : constant Integer := Integer (Interfaces.Shift_Right (Q.W0, 5) and 31);
            Z  : constant Integer := Integer (Interfaces.Shift_Right (Q.W0, 10) and 1023);
            Wd : constant Integer := Integer (Interfaces.Shift_Right (Q.W0, 20) and 31) + 1;
            Fc : constant Integer := Integer (Interfaces.Shift_Right (Q.W0, 25) and 7);
            Ht : constant Integer := Integer (Q.W1 and 255) + 1;
         begin
            H := (H xor Interfaces.Unsigned_64 (Q.W0)) * 1099511628211;
            H := (H xor Interfaces.Unsigned_64 (Q.W1)) * 1099511628211;
            if Fc > 5 or else Z not in M.Z_Lo .. M.Z_Hi
              or else (if Fc < 2 then Y + Wd > 32 or else Z + Ht > M.Z_Hi + 1
                       elsif Fc < 4 then X + Wd > 32 or else Z + Ht > M.Z_Hi + 1
                       else X + Wd > 32 or else Y + Ht > 32)
            then
               Ok := False;
            end if;
         end Take;
      begin
         Ok := True;
         if M.Solid /= null then
            for Q of M.Solid.all loop
               Take (Q);
            end loop;
         end if;
         if M.Water /= null then
            for Q of M.Water.all loop
               Take (Q);
            end loop;
         end if;
         return H;
      end Hash_Of;

      Flat  : constant Edge_Tops := [others => 3];
      M     : Castle.Mesher.Mesh;
      Ok    : Boolean;
      Ed    : Boolean;
   begin
      --  eight cells to one
      Check (Parent ([others => Air]) = Air
             and then Parent ([Dirt, Dirt, Dirt, Dirt, Air, Air, Air, Air]) = Dirt
             and then Parent ([Dirt, Dirt, Dirt, Dirt, Grass, Grass, Air, Air]) = Grass
             and then Parent ([Dirt, Dirt, Dirt, Air, Air, Air, Air, Air]) = Air
             and then Parent ([Sand, Sand, Sand, Sand, Water, Water, Air, Air]) = Water
             and then Parent ([Water, Water, Water, Water, Air, Air, Air, Air]) = Water
             and then Parent ([Water, Air, Air, Air, Air, Air, Air, Air]) = Air
             and then Parent ([Log, Air, Air, Air, Log, Air, Air, Air]) = Log
             and then Parent ([Leaves, Air, Air, Air, Leaves, Air, Air, Air]) = Air
             and then Parent ([Leaves, Leaves, Log, Air, Leaves, Leaves, Air, Air]) = Leaves
             and then Parent ([Daub, Daub, Air, Air, Thatch, Thatch, Air, Air]) = Thatch,
             "eight cells become one: half full is something, and what is on top names it; water on top stays"
             & " water; two of a thing thin by nature (a trunk, a wall) keep it; two of leaves do not");

      --  a made-up tile: ground three cells deep, level with what is beside it
      for X in 0 .. 31 loop
         for Y in 0 .. 31 loop
            for Z in 0 .. 7 loop
               S.C (X, Y, Z) := (if Z < 3 then Dirt else Air);
            end loop;
         end loop;
      end loop;
      Mesh_Cells (S.all, 0, 7, Flat, Flat, Flat, Flat, M);
      Check (Count (M.Solid) = 5 and then Count (M.Water) = 0 and then Hash_Of (M, Ok) /= 0 and then Ok,
             "level ground is one quad, and its four edges a skirt each (" & Img (Count (M.Solid)) & " quads)");
      Castle.Mesher.Free (M);
      --  a pillar on it, a pond in it, and lower ground beside it to the west
      S.C (10, 10, 3) := Log;
      S.C (10, 10, 4) := Log;
      S.C (20, 20, 2) := Water;
      S.C (21, 20, 2) := Water;
      declare
         Low : constant Edge_Tops := [others => 1];
         Pillar, West_Wall : Natural := 0;
      begin
         Mesh_Cells (S.all, 0, 7, Low, Flat, Flat, Flat, M);
         for Q of M.Solid.all loop
            declare
               X  : constant Integer := Integer (Q.W0 and 31);
               Y  : constant Integer := Integer (Interfaces.Shift_Right (Q.W0, 5) and 31);
               Z  : constant Integer := Integer (Interfaces.Shift_Right (Q.W0, 10) and 1023);
               Fc : constant Integer := Integer (Interfaces.Shift_Right (Q.W0, 25) and 7);
               Mt : constant Integer := Integer (Interfaces.Shift_Right (Q.W1, 8) and 255);
            begin
               if Mt = Material'Pos (Log) and then X = 10 and then Y = 10 and then Z in 3 .. 4 then
                  Pillar := Pillar + 1;
               end if;
               if Fc = 1 and then X = 0 and then Z = 1 then      --  the west face, from where the ground beside it ends
                  West_Wall := West_Wall + 1;
               end if;
            end;
         end loop;
         Check (Pillar in 5 .. 9 and then Count (M.Water) = 1 and then West_Wall >= 1 and then Hash_Of (M, Ok) /= 0
                and then Ok,
                "a pillar two cells high is its four sides and its top (" & Img (Pillar) & " quads: a side is two where"
                & " its foot is shaded); two cells of water are one quad of water (" & Img (Count (M.Water))
                & "); lower ground beside the tile shows the tile's side down to it (" & Img (West_Wall) & ")");
         Castle.Mesher.Free (M);
      end;

      --  tiles of the world: the same twice, every quad inside its tile; and an edit shows
      declare
         H1, H2 : Interfaces.Unsigned_64;
         All_Ok : Boolean := True;
         Same   : Boolean := True;
         Quads  : Natural := 0;
      begin
         Castle.Edits.Clear;                     --  (the world as it was made, from here on)
         for L in Level loop
            Build_Tile (W, L, Tiles (L) / 2 + 1, Tiles (L) / 2, Work, S.all, M, Ed);
            H1 := Hash_Of (M, Ok);
            All_Ok := All_Ok and then Ok and then Count (M.Solid) > 100;
            Quads := Quads + Count (M.Solid) + Count (M.Water);
            Castle.Mesher.Free (M);
            Build_Tile (W, L, Tiles (L) / 2 + 1, Tiles (L) / 2, Work, S.all, M, Ed);
            H2 := Hash_Of (M, Ok);
            Same := Same and then H1 = H2;
            Castle.Mesher.Free (M);
         end loop;
         Check (All_Ok and then Same,
                "a tile of the world at each of the four levels: the same made twice, every quad inside its tile ("
                & Img (Quads) & " quads the four)" & (if All_Ok then "" else " [a quad outside its tile, or too few]")
                & (if Same then "" else " [not the same twice]"));
      end;
      declare
         --  a pit 8 m square and 4 m deep, inside a tile of level 2 (and of the tiles over it)
         TX : constant Integer := Tiles (2) / 2 + 3;
         TY : constant Integer := Tiles (2) / 2 - 2;
         Bx : constant Integer := TX * 128 + 64;
         By : constant Integer := TY * 128 + 64;
         Before, Dug, After : array (Level) of Interfaces.Unsigned_64;
         Flagged : Boolean := True;
      begin
         Castle.Edits.Clear;
         for L in Level loop
            Build_Tile (W, L, Bx / (32 * 2 ** L), By / (32 * 2 ** L), Work, S.all, M, Ed);
            Before (L) := Hash_Of (M, Ok);
            Castle.Mesher.Free (M);
         end loop;
         for X in Bx .. Bx + 31 loop
            for Y in By .. By + 31 loop
               for Z in Castle.Geology.Surface_B (W, X, Y) - 16 .. Castle.Geology.Surface_B (W, X, Y) + 3 loop
                  Castle.Edits.Set (X, Y, Z, Air_Block);
               end loop;
            end loop;
         end loop;
         for L in Level loop
            Build_Tile (W, L, Bx / (32 * 2 ** L), By / (32 * 2 ** L), Work, S.all, M, Ed);
            Dug (L) := Hash_Of (M, Ok);
            Flagged := Flagged and then Ed;
            Castle.Mesher.Free (M);
         end loop;
         Castle.Edits.Clear;
         for L in Level loop
            Build_Tile (W, L, Bx / (32 * 2 ** L), By / (32 * 2 ** L), Work, S.all, M, Ed);
            After (L) := Hash_Of (M, Ok);
            Castle.Mesher.Free (M);
         end loop;
         Check (Flagged and then (for all L in Level => Dug (L) /= Before (L) and then After (L) = Before (L)),
                "a pit 8 m square dug in the world is in its tile at every level, and the tile says it holds an edit;"
                & " the edits gone, each tile is as it was"
                & (if Flagged then "" else " [not flagged]")
                & (if (for all L in Level => Dug (L) /= Before (L)) then "" else " [a level is unchanged by the pit]")
                & (if (for all L in Level => After (L) = Before (L)) then "" else " [a level did not come back]"));
      end;
   end;

   ------------------------------------------------------------------ the far land
   --  The whole world as one coarse sheet (Castle.Far), from the generator's map alone.
   Put_Line ("the far land:");
   declare
      use Castle.Far;
      Set     : Castle.Textures.Texture_Set := Castle.Textures.Generate (W.Seed);
      Z       : constant Height_Grid_Access := new Height_Grid;
      C       : constant Texel_Grid_Access := new Texel_Grid;
      T0      : constant Ada.Calendar.Time := Ada.Calendar.Clock;
      Seconds : Float;
      By_Class : array (Class) of Natural := [others => 0];
      Over, Looked : Natural := 0;
      Deepest : Float := 0.0;                 --  how far under the land the sheet goes at most, where looked at
      Trees, Crowns, Wet_N, Wet_Cells : Natural := 0;
   begin
      Build (W, Set.Overall.all, Z.all, C.all);
      Seconds := Float (Ada.Calendar."-" (Ada.Calendar.Clock, T0));
      --  never above the land as it was made: every seventh corner against the four block columns round it
      for J in 1 .. Cells - 1 loop
         for I in 1 .. Cells - 1 loop
            if (I + 3 * J) mod 7 = 0 then
               Looked := Looked + 1;
               declare
                  Low : Float := Float'Last;
               begin
                  for Dy in -1 .. 0 loop
                     for Dx in -1 .. 0 loop
                        declare
                           Col : constant Castle.Geology.Column :=
                             Castle.Geology.Prepare_Column (W, I * Cell_M * 4 + Dx, J * Cell_M * 4 + Dy);
                        begin
                           Low := Float'Min (Low, Float (Integer'Max (Col.Solid, Col.Water_Top)) * 0.25);
                        end;
                     end loop;
                  end loop;
                  if Float (Z (J, I)) > Low then
                     Over := Over + 1;
                  end if;
                  Deepest := Float'Max (Deepest, Low - Float (Z (J, I)));
               end;
            end if;
         end loop;
      end loop;
      Check (Over = 0, "no corner of the sheet stands above the land as it was made (" & Img (Looked)
             & " corners against the block columns round them; the furthest under is " & Img (Deepest, 1) & " m)");
      --  and between its corners: every block column of every 61st cell that is not Wet, against the
      --  sheet as it is drawn there
      declare
         Cells_N, Columns, Above : Natural := 0;
         Least : Float := Float'Last;           --  the least the sheet is under a dry block column's top
      begin
         for J in 0 .. Cells - 1 loop
            for I in 0 .. Cells - 1 loop
               if (I + 7 * J) mod 61 = 0 and then not Wet (W, I, J) then
                  Cells_N := Cells_N + 1;
                  for By in J * Cell_M * 4 .. (J + 1) * Cell_M * 4 - 1 loop
                     for Bx in I * Cell_M * 4 .. (I + 1) * Cell_M * 4 - 1 loop
                        declare
                           Col : constant Castle.Geology.Column := Castle.Geology.Prepare_Column (W, Bx, By);
                           Top : constant Float := Float (Col.Solid) * 0.25;
                           Zs  : Float := Float'First;
                        begin
                           --  (the sheet over the whole of the block column: at its four corners)
                           for Dy in 0 .. 1 loop
                              for Dx in 0 .. 1 loop
                                 Zs := Float'Max (Zs, Sheet_Z (W, Float (Bx + Dx) * 0.25, Float (By + Dy) * 0.25));
                              end loop;
                           end loop;
                           Columns := Columns + 1;
                           Least := Float'Min (Least, Top - Zs);
                           if Zs >= Top then
                              Above := Above + 1;
                           end if;
                        end;
                     end loop;
                  end loop;
               end if;
            end loop;
         end loop;
         Check (Above = 0 and then Least >= 0.2 and then Cells_N > 1_000,
                "the sheet lies under the land between its corners too: under every one of " & Img (Columns)
                & " block columns of " & Img (Cells_N) & " dry cells, by " & Img (Least, 2) & " m at the least");
      end;
      for J in 0 .. Cells - 1 loop
         for I in 0 .. Cells - 1 loop
            By_Class (Class'Val (Natural (C (J, I).A) / Class_Step)) := @ + 1;
            if Castle.Flora.Tree_At (W, I, J).Valid then
               Trees := Trees + 1;
               if Class'Val (Natural (C (J, I).A) / Class_Step) in Broadleaf | Aspen | Conifer then
                  Crowns := Crowns + 1;
               end if;
            end if;
            if W.Water (Castle.Fields.Idx (I * Cell_M + 2, J * Cell_M + 2)) > 0.0 then
               Wet_N := Wet_N + 1;
               if Class'Val (Natural (C (J, I).A) / Class_Step) = Open_Water then
                  Wet_Cells := Wet_Cells + 1;
               end if;
            end if;
         end loop;
      end loop;
      Check (By_Class (Open_Water) > 0 and then Wet_Cells * 10 >= Wet_N * 8
             and then Crowns + By_Class (Open_Water) >= Trees and then Crowns <= Trees
             and then By_Class (Turf) > By_Class (Bare),
             "a cell is what is seen on it: of " & Img (Natural'(Cells * Cells)) & ", turf " & Img (By_Class (Turf)) & ", bare "
             & Img (By_Class (Bare)) & ", broadleaf " & Img (By_Class (Broadleaf)) & ", aspen " & Img (By_Class (Aspen))
             & ", conifer " & Img (By_Class (Conifer)) & ", open water " & Img (By_Class (Open_Water))
             & " (" & Img (Trees) & " of the generator's trees; " & Img (Wet_Cells) & " of the " & Img (Wet_N)
             & " cells whose middle the map has under water)");
      Check (Seconds < 5.0, "worked out in " & Img (Seconds, 2) & " s on one thread");
      Castle.Textures.Free (Set);
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
