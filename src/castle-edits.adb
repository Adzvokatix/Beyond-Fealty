with Ada.Containers.Generic_Array_Sort;
with Ada.Containers.Ordered_Maps;
with Ada.Unchecked_Deallocation;
with Castle.Dims; use Castle.Dims;

package body Castle.Edits is

   package Maps is new Ada.Containers.Ordered_Maps (Unsigned_64, Block);

   Local_Bits : constant := 20;                         --  Z 10 bits, Y 5, X 5
   Local_Span : constant Unsigned_64 := 2 ** Local_Bits;
   Brick_Bits : constant := 14;                         --  K 8 bits (metres), J 3, I 3
   Brick_Span : constant Unsigned_64 := 2 ** Brick_Bits;

   function Stack_Key (CX, CY : Integer) return Unsigned_64 is
     (Unsigned_64 (CX * Chunks_XY + CY));

   function Key_Of (Bx, By, Bz : Integer) return Unsigned_64 is
     (Shift_Left (Stack_Key (Bx / Chunk_B, By / Chunk_B), Local_Bits)
      or Unsigned_64 (Bz * 1024 + (By mod Chunk_B) * 32 + Bx mod Chunk_B));

   function Brick_Key (Bx, By, Bz : Integer) return Unsigned_64 is
     (Shift_Left (Stack_Key (Bx / Chunk_B, By / Chunk_B), Brick_Bits)
      or Unsigned_64 ((Bz / 4) * 64 + ((By mod Chunk_B) / 4) * 8 + (Bx mod Chunk_B) / 4));

   type Gen_Grid is array (0 .. Chunks_XY - 1, 0 .. Chunks_XY - 1) of Natural;
   type Gen_Access is access Gen_Grid;

   function Less (A, B : Rim_Edit) return Boolean;
   procedure Sort is new Ada.Containers.Generic_Array_Sort (Positive, Rim_Edit, Rim_Array, Less);

   procedure Free_Rim is new Ada.Unchecked_Deallocation (Rim_Array, Rim_Access);
   procedure Free_Saved is new Ada.Unchecked_Deallocation (Saved_Array, Saved_Access);

   function Less (A, B : Rim_Edit) return Boolean is
     (A.X < B.X or else (A.X = B.X and then (A.Y < B.Y or else (A.Y = B.Y and then A.Z < B.Z))));

   protected Store is
      procedure Set (Bx, By, Bz : Integer; B : Block);
      procedure Set_Brick (Bx, By, Bz : Integer; M : Material);
      procedure Find (Bx, By, Bz : Integer; B : out Block; Found : out Boolean);
      procedure Gen_Of (CX, CY : Integer; G : out Natural);
      procedure Apply (CX, CY : Integer; Work : Stack_Work_Access; Gen : out Natural; Rim : out Rim_Access);
      procedure Clear;
      procedure Size (N : out Natural);
      procedure Dump (E : out Saved_Access);
      procedure Restore (E : Saved_Array);
   private
      M    : Maps.Map;                  --  block edits
      K    : Maps.Map;                  --  brick edits (Block.Mat; State unused)
      Gens : Gen_Access := new Gen_Grid'(others => (others => 0));
   end Store;

   protected body Store is

      --  Advance the stacks whose meshes look at block (Bx, By): its own,
      --  and the neighbours whose rim it is in.
      procedure Touch (Bx, By : Integer) is
         CX : constant Integer := Bx / Chunk_B;
         CY : constant Integer := By / Chunk_B;
         Lx : constant Integer := Bx mod Chunk_B;
         Ly : constant Integer := By mod Chunk_B;
      begin
         for Dx in -1 .. 1 loop
            for Dy in -1 .. 1 loop
               if (Dx = 0 or else (Dx = -1 and then Lx = 0) or else (Dx = 1 and then Lx = Chunk_B - 1))
                 and then (Dy = 0 or else (Dy = -1 and then Ly = 0) or else (Dy = 1 and then Ly = Chunk_B - 1))
                 and then CX + Dx in Gen_Grid'Range (1) and then CY + Dy in Gen_Grid'Range (2)
               then
                  Gens (CX + Dx, CY + Dy) := Gens (CX + Dx, CY + Dy) + 1;
               end if;
            end loop;
         end loop;
      end Touch;

      procedure Set (Bx, By, Bz : Integer; B : Block) is
      begin
         if Bx in 0 .. Size_B - 1 and then By in 0 .. Size_B - 1 and then Bz in 0 .. Height_B - 1 then
            M.Include (Key_Of (Bx, By, Bz), B);
            Touch (Bx, By);
         end if;
      end Set;

      procedure Set_Brick (Bx, By, Bz : Integer; M : Material) is
         X0 : constant Integer := Bx - Bx mod 4;
         Y0 : constant Integer := By - By mod 4;
         Z0 : constant Integer := Bz - Bz mod 4;
      begin
         if Bx in 0 .. Size_B - 1 and then By in 0 .. Size_B - 1 and then Bz in 0 .. Height_B - 1 then
            for X in X0 .. X0 + 3 loop
               for Y in Y0 .. Y0 + 3 loop
                  for Z in Z0 .. Z0 + 3 loop
                     Store.M.Exclude (Key_Of (X, Y, Z));
                  end loop;
                  Touch (X, Y);
               end loop;
            end loop;
            K.Include (Brick_Key (Bx, By, Bz), (Mat => M, State => 0));
         end if;
      end Set_Brick;

      procedure Find (Bx, By, Bz : Integer; B : out Block; Found : out Boolean) is
         C : Maps.Cursor;
      begin
         B := Air_Block;
         Found := False;
         if Bx in 0 .. Size_B - 1 and then By in 0 .. Size_B - 1 and then Bz in 0 .. Height_B - 1 then
            C := M.Find (Key_Of (Bx, By, Bz));
            if Maps.Has_Element (C) then
               B := Maps.Element (C);
               Found := True;
               return;
            end if;
            C := K.Find (Brick_Key (Bx, By, Bz));
            if Maps.Has_Element (C) then
               B := Maps.Element (C);
               Found := True;
            end if;
         end if;
      end Find;

      procedure Gen_Of (CX, CY : Integer; G : out Natural) is
      begin
         G := Gens (CX, CY);
      end Gen_Of;

      procedure Apply (CX, CY : Integer; Work : Stack_Work_Access; Gen : out Natural; Rim : out Rim_Access) is
         Base  : constant Unsigned_64 := Shift_Left (Stack_Key (CX, CY), Local_Bits);
         KBase : constant Unsigned_64 := Shift_Left (Stack_Key (CX, CY), Brick_Bits);
         C     : Maps.Cursor := M.Ceiling (Base);
         KC    : Maps.Cursor := K.Ceiling (KBase);
         Hi    : Integer := -1;
         Ring  : Rim_Array (1 .. 16_384);
         N     : Natural := 0;

         --  The skin reaches down to one block below an edit, in its brick
         --  column and the eight round it: those hold the edit's walls and
         --  floor, which Castle.Chunks.Deepen then generates for real.
         procedure Lower (X, Y, Z : Integer) is
            Mz : constant Integer := Integer'Max (0, Z - 1) / 4;
         begin
            for I in Integer'Max (0, (X - 1) / 4) .. Integer'Min (7, (X + 1) / 4) loop
               for J in Integer'Max (0, (Y - 1) / 4) .. Integer'Min (7, (Y + 1) / 4) loop
                  Work.Skin (I, J) := Integer'Min (Work.Skin (I, J), Mz);
               end loop;
            end loop;
         end Lower;

         procedure Add_Rim (X, Y, Z : Integer; Mat : Material) is
         begin
            if X in -1 .. 32 and then Y in -1 .. 32 and then N < Ring'Last then
               N := N + 1;
               Ring (N) := (X, Y, Z, Mat);
               Lower (Integer'Max (0, Integer'Min (31, X)), Integer'Max (0, Integer'Min (31, Y)), Z);
            end if;
         end Add_Rim;
      begin
         Gen := Gens (CX, CY);
         Rim := null;
         --  Whole bricks first; block edits after them are finer and win.
         while Maps.Has_Element (KC) and then Maps.Key (KC) < KBase + Brick_Span loop
            declare
               L  : constant Integer := Integer (Maps.Key (KC) and (Brick_Span - 1));
               I  : constant Integer := L mod 8;
               J  : constant Integer := (L / 8) mod 8;
               Mz : constant Integer := L / 64;
               B  : constant Block := Maps.Element (KC);
            begin
               for X in 4 * I .. 4 * I + 3 loop
                  for Y in 4 * J .. 4 * J + 3 loop
                     for Z in 4 * Mz .. 4 * Mz + 3 loop
                        Work.G (X, Y, Z) := B;
                     end loop;
                  end loop;
               end loop;
               Hi := Integer'Max (Hi, 4 * Mz + 3);
               Lower (4 * I, 4 * J, 4 * Mz);
               Lower (4 * I + 3, 4 * J + 3, 4 * Mz);
            end;
            Maps.Next (KC);
         end loop;
         while Maps.Has_Element (C) and then Maps.Key (C) < Base + Local_Span loop
            declare
               L : constant Integer := Integer (Maps.Key (C) and (Local_Span - 1));
               X : constant Integer := L mod 32;
               Y : constant Integer := (L / 32) mod 32;
               Z : constant Integer := L / 1024;
            begin
               Work.G (X, Y, Z) := Maps.Element (C);
               Hi := Integer'Max (Hi, Z);
               Lower (X, Y, Z);
            end;
            Maps.Next (C);
         end loop;
         if Hi >= 0 then
            Work.Air_From := Integer'Max (Work.Air_From, Hi + 1);
         end if;

         --  The rim: edits in the neighbouring columns next to this stack.
         for Dx in -1 .. 1 loop
            for Dy in -1 .. 1 loop
               if (Dx /= 0 or else Dy /= 0)
                 and then CX + Dx in Gen_Grid'Range (1) and then CY + Dy in Gen_Grid'Range (2)
               then
                  declare
                     B2 : constant Unsigned_64 := Shift_Left (Stack_Key (CX + Dx, CY + Dy), Local_Bits);
                     K2 : constant Unsigned_64 := Shift_Left (Stack_Key (CX + Dx, CY + Dy), Brick_Bits);
                     C2 : Maps.Cursor := M.Ceiling (B2);
                     D2 : Maps.Cursor := K.Ceiling (K2);
                     First_Block : constant Natural := N + 1;
                  begin
                     --  the neighbour's bricks along the shared edge, block by block
                     while Maps.Has_Element (D2) and then Maps.Key (D2) < K2 + Brick_Span loop
                        declare
                           L  : constant Integer := Integer (Maps.Key (D2) and (Brick_Span - 1));
                           X0 : constant Integer := 4 * (L mod 8) + 32 * Dx;
                           Y0 : constant Integer := 4 * ((L / 8) mod 8) + 32 * Dy;
                        begin
                           if X0 + 3 >= -1 and then X0 <= 32 and then Y0 + 3 >= -1 and then Y0 <= 32 then
                              for X in X0 .. X0 + 3 loop
                                 for Y in Y0 .. Y0 + 3 loop
                                    for Z in 4 * (L / 64) .. 4 * (L / 64) + 3 loop
                                       Add_Rim (X, Y, Z, Maps.Element (D2).Mat);
                                    end loop;
                                 end loop;
                              end loop;
                           end if;
                        end;
                        Maps.Next (D2);
                     end loop;
                     --  then its block edits, which win over its bricks (as they are drawn: the rim is the
                     --  mesher's alone, and a piece's block is drawn as air, or a post beside a rail hidden
                     --  across the edge lost the face toward it)
                     while Maps.Has_Element (C2) and then Maps.Key (C2) < B2 + Local_Span loop
                        declare
                           L : constant Integer := Integer (Maps.Key (C2) and (Local_Span - 1));
                           X : constant Integer := L mod 32 + 32 * Dx;
                           Y : constant Integer := (L / 32) mod 32 + 32 * Dy;
                           Z : constant Integer := L / 1024;
                           Replaced : Boolean := False;
                        begin
                           if X in -1 .. 32 and then Y in -1 .. 32 then
                              for R in First_Block .. N loop
                                 if Ring (R).X = X and then Ring (R).Y = Y and then Ring (R).Z = Z then
                                    Ring (R).Mat := Seen_Mat (Maps.Element (C2));
                                    Replaced := True;
                                    exit;
                                 end if;
                              end loop;
                              if not Replaced then
                                 Add_Rim (X, Y, Z, Seen_Mat (Maps.Element (C2)));
                              end if;
                           end if;
                        end;
                        Maps.Next (C2);
                     end loop;
                  end;
               end if;
            end loop;
         end loop;
         if N > 0 then
            Sort (Ring (1 .. N));
            Rim := new Rim_Array'(Ring (1 .. N));
         end if;
      end Apply;

      procedure Clear is
         C : Maps.Cursor := M.First;
         D : Maps.Cursor := K.First;
      begin
         while Maps.Has_Element (D) loop
            declare
               L  : constant Unsigned_64 := Maps.Key (D);
               SK : constant Integer := Integer (Shift_Right (L, Brick_Bits));
               Lc : constant Integer := Integer (L and (Brick_Span - 1));
               X0 : constant Integer := (SK / Chunks_XY) * Chunk_B + 4 * (Lc mod 8);
               Y0 : constant Integer := (SK mod Chunks_XY) * Chunk_B + 4 * ((Lc / 8) mod 8);
            begin
               Touch (X0, Y0);
               Touch (X0 + 3, Y0 + 3);
            end;
            Maps.Next (D);
         end loop;
         K.Clear;
         while Maps.Has_Element (C) loop
            declare
               L  : constant Unsigned_64 := Maps.Key (C);
               SK : constant Integer := Integer (Shift_Right (L, Local_Bits));
               Lc : constant Integer := Integer (L and (Local_Span - 1));
            begin
               Touch ((SK / Chunks_XY) * Chunk_B + Lc mod 32, (SK mod Chunks_XY) * Chunk_B + (Lc / 32) mod 32);
            end;
            Maps.Next (C);
         end loop;
         M.Clear;
      end Clear;

      procedure Size (N : out Natural) is
      begin
         N := Natural (M.Length) + Natural (K.Length);
      end Size;

      procedure Dump (E : out Saved_Access) is
         C : Maps.Cursor := M.First;
         D : Maps.Cursor := K.First;
         I : Natural := 0;
      begin
         E := new Saved_Array (1 .. Natural (M.Length) + Natural (K.Length));
         while Maps.Has_Element (D) loop
            I := I + 1;
            E (I) := (True, Maps.Key (D), Maps.Element (D));
            Maps.Next (D);
         end loop;
         while Maps.Has_Element (C) loop
            I := I + 1;
            E (I) := (False, Maps.Key (C), Maps.Element (C));
            Maps.Next (C);
         end loop;
      end Dump;

      procedure Restore (E : Saved_Array) is
      begin
         Clear;
         for X of E loop
            if X.Brick then
               K.Include (X.Key, X.B);
               declare
                  SK : constant Integer := Integer (Shift_Right (X.Key, Brick_Bits));
                  Lc : constant Integer := Integer (X.Key and (Brick_Span - 1));
                  X0 : constant Integer := (SK / Chunks_XY) * Chunk_B + 4 * (Lc mod 8);
                  Y0 : constant Integer := (SK mod Chunks_XY) * Chunk_B + 4 * ((Lc / 8) mod 8);
               begin
                  Touch (X0, Y0);
                  Touch (X0 + 3, Y0 + 3);
               end;
            else
               M.Include (X.Key, X.B);
               declare
                  SK : constant Integer := Integer (Shift_Right (X.Key, Local_Bits));
                  Lc : constant Integer := Integer (X.Key and (Local_Span - 1));
               begin
                  Touch ((SK / Chunks_XY) * Chunk_B + Lc mod 32, (SK mod Chunks_XY) * Chunk_B + (Lc / 32) mod 32);
               end;
            end if;
         end loop;
      end Restore;

   end Store;

   procedure Set (Bx, By, Bz : Integer; B : Block) is
   begin
      Store.Set (Bx, By, Bz, B);
   end Set;

   function Find (Bx, By, Bz : Integer; B : out Block) return Boolean is
      Found : Boolean;
   begin
      Store.Find (Bx, By, Bz, B, Found);
      return Found;
   end Find;

   function Generation (CX, CY : Integer) return Natural is
      G : Natural;
   begin
      Store.Gen_Of (CX, CY, G);
      return G;
   end Generation;

   procedure Set_Brick (Bx, By, Bz : Integer; M : Material) is
   begin
      Store.Set_Brick (Bx, By, Bz, M);
   end Set_Brick;

   procedure Apply (CX, CY : Integer; Work : Stack_Work_Access; Gen : out Natural; Rim : out Rim_Access) is
   begin
      Store.Apply (CX, CY, Work, Gen, Rim);
   end Apply;

   function Rim_Material (R : Rim_Access; X, Y, Z : Integer; M : out Material) return Boolean is
      Lo : Integer;
      Hi : Integer;
      K  : constant Rim_Edit := (X, Y, Z, Air);
   begin
      M := Air;
      if R = null then
         return False;
      end if;
      Lo := R'First;
      Hi := R'Last;
      while Lo <= Hi loop
         declare
            Mid : constant Integer := (Lo + Hi) / 2;
         begin
            if Less (R (Mid), K) then
               Lo := Mid + 1;
            elsif Less (K, R (Mid)) then
               Hi := Mid - 1;
            else
               M := R (Mid).Mat;
               return True;
            end if;
         end;
      end loop;
      return False;
   end Rim_Material;

   procedure Free (R : in out Rim_Access) is
   begin
      if R /= null then
         Free_Rim (R);
      end if;
   end Free;

   procedure Clear is
   begin
      Store.Clear;
   end Clear;

   function Count return Natural is
      N : Natural;
   begin
      Store.Size (N);
      return N;
   end Count;

   function All_Edits return Saved_Access is
      E : Saved_Access;
   begin
      Store.Dump (E);
      return E;
   end All_Edits;

   procedure Restore (E : Saved_Array) is
   begin
      Store.Restore (E);
   end Restore;

   procedure Free (E : in out Saved_Access) is
   begin
      if E /= null then
         Free_Saved (E);
      end if;
   end Free;

end Castle.Edits;
