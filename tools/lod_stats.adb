with Ada.Command_Line;  use Ada.Command_Line;
with Ada.Text_IO;       use Ada.Text_IO;
with Castle.Chunks;     use Castle.Chunks;
with Castle.Hash;
with Castle.Lod;        use Castle.Lod;
with Castle.Maps;       use Castle.Maps;
with Castle.Mesher;
with Castle.Text;       use Castle.Text;
with Castle.Worldgen;

--  What the far view costs (John, 2026-11-15: "let's figure out how to get
--  everything in view"): tiles of the world at coarser blocks
--  (Castle.Lod), counted on seed 1.  For each level, tiles taken evenly
--  over the map: the quads a tile comes to (with the corner occlusion and
--  without), and what a worker spends making one (generating its stacks,
--  reducing them, meshing).  Then what whole rings of tiles come to round
--  a place: level 0 (the stacks themselves) to --view metres, each level
--  after to twice as far, the last to the map's edge.
--    lod_stats [--at X Y] [--view M] [--every N]
--  A measurement, not a check.
procedure Lod_Stats is
   W     : World;
   Work  : constant Stack_Work_Access := new Stack_Work;
   S     : constant Scratch_Access := new Scratch;
   At_X  : Float := 1178.0;
   At_Y  : Float := 1078.0;
   View  : Float := 160.0;
   Every : Positive := 1;

   type Sums is record
      Tiles : Natural := 0;
      Quads, Quads_Plain, Water, Most, Rows : Long_Integer := 0;
      T : aliased Tile_Times;
   end record;
   By : array (Level) of Sums;

   function Count (Q : Castle.Mesher.Quad_Access) return Long_Integer is
     (if Castle.Mesher."=" (Q, null) then 0 else Long_Integer (Q'Length));
   function Ms (D : Duration; N : Natural) return String is
     (Img (Float (D) * 1000.0 / Float (Integer'Max (1, N)), 1));

   --  Tiles of level L wholly or partly within R1 of the place and not wholly within R0.
   function In_Ring (L : Level; R0, R1 : Float) return Natural is
      Side : constant Float := Float (Tile_Stacks (L)) * 8.0;
      N    : Natural := 0;
   begin
      for TY in 0 .. Tiles (L) - 1 loop
         for TX in 0 .. Tiles (L) - 1 loop
            declare
               X0 : constant Float := Float (TX) * Side;
               Y0 : constant Float := Float (TY) * Side;
               Nx : constant Float := Float'Max (0.0, Float'Max (X0 - At_X, At_X - (X0 + Side)));
               Ny : constant Float := Float'Max (0.0, Float'Max (Y0 - At_Y, At_Y - (Y0 + Side)));
               Fx : constant Float := Float'Max (abs (X0 - At_X), abs (X0 + Side - At_X));
               Fy : constant Float := Float'Max (abs (Y0 - At_Y), abs (Y0 + Side - At_Y));
            begin
               if Nx * Nx + Ny * Ny < R1 * R1 and then Fx * Fx + Fy * Fy > R0 * R0 then
                  N := N + 1;
               end if;
            end;
         end loop;
      end loop;
      return N;
   end In_Ring;

   I : Positive := 1;
begin
   while I <= Argument_Count loop
      if Argument (I) = "--at" then
         At_X := Float'Value (Argument (I + 1)); At_Y := Float'Value (Argument (I + 2)); I := I + 3;
      elsif Argument (I) = "--view" then
         View := Float'Value (Argument (I + 1)); I := I + 2;
      elsif Argument (I) = "--every" then
         Every := Positive'Value (Argument (I + 1)); I := I + 2;
      else
         Put_Line ("lod_stats [--at X Y] [--view M] [--every N]"); return;
      end if;
   end loop;
   Castle.Worldgen.Create (Castle.Hash.U64 (1), W, Report => False);
   Put_Line ("the far view, seed 1: tiles of the world at coarser blocks");
   for L in Level loop
      declare
         --  about 24 x 2 ** (4 - L) tiles of the level, evenly over the map
         Step : constant Positive := Integer'Max (1, (Tiles (L) * Every) / (if L = 4 then 5 elsif L = 3 then 7 else 10));
         M    : Castle.Mesher.Mesh;
         Ed   : Boolean;
      begin
         for TY in 0 .. Tiles (L) - 1 loop
            for TX in 0 .. Tiles (L) - 1 loop
               if TX mod Step = Step / 2 and then TY mod Step = Step / 2 then
                  Build_Tile (W, L, TX, TY, Work, S.all, M, Ed, With_AO => False);
                  By (L).Quads_Plain := By (L).Quads_Plain + Count (M.Solid) + Count (M.Water);
                  Castle.Mesher.Free (M);
                  Build_Tile (W, L, TX, TY, Work, S.all, M, Ed, With_AO => True, Times => By (L).T'Access);
                  By (L).Tiles := By (L).Tiles + 1;
                  By (L).Quads := By (L).Quads + Count (M.Solid) + Count (M.Water);
                  By (L).Water := By (L).Water + Count (M.Water);
                  By (L).Most := Long_Integer'Max (By (L).Most, Count (M.Solid) + Count (M.Water));
                  By (L).Rows := By (L).Rows + Long_Integer (M.Z_Hi - M.Z_Lo + 1);
                  Castle.Mesher.Free (M);
               end if;
            end loop;
         end loop;
         declare
            B : Sums renames By (L);
            N : constant Long_Integer := Long_Integer (Integer'Max (1, B.Tiles));
         begin
            Put_Line ("level" & L'Image & ": cells of " & Img (Float (Cell_B (L)) * 0.25, 2) & " m, tiles of"
                      & Integer'Image (Tile_Stacks (L) * 8) & " m (" & Img (Tile_Stacks (L) ** 2) & " stacks); "
                      & Img (B.Tiles) & " tiles made: " & Img (Integer (B.Quads / N)) & " quads a tile ("
                      & Img (Integer (B.Quads_Plain / N)) & " with no corner occlusion; water "
                      & Img (Integer (B.Water / N)) & "; the most " & Img (Integer (B.Most)) & "), "
                      & Img (Integer (B.Rows / N)) & " rows of cells; a worker: generating "
                      & Ms (B.T.Generate, B.Tiles) & " ms, reducing " & Ms (B.T.Reduce, B.Tiles) & ", meshing "
                      & Ms (B.T.Mesh, B.Tiles) & " a tile");
         end;
      end;
   end loop;
   New_Line;
   Put_Line ("rings round " & Img (At_X, 0) & ", " & Img (At_Y, 0) & ", the stacks themselves to " & Img (View, 0)
             & " m and each level to twice as far as the one before (the last to the map's edge):");
   declare
      R0 : Float := View;
      All_Quads, All_Ms : Float := 0.0;
   begin
      for L in Level loop
         declare
            R1 : constant Float := (if L = Level'Last then 1.0E9 else View * Float (2 ** L));
            N  : constant Natural := In_Ring (L, R0, R1);
            B  : Sums renames By (L);
            Q  : constant Float := Float (N) * Float (B.Quads) / Float (Integer'Max (1, B.Tiles));
            T  : constant Float :=
              Float (N) * Float (B.T.Generate + B.T.Reduce + B.T.Mesh) / Float (Integer'Max (1, B.Tiles));
         begin
            Put_Line ("  level" & L'Image & ", " & Img (R0, 0) & " m to "
                      & (if L = Level'Last then "the edge" else Img (R1, 0) & " m") & ":" & N'Image & " tiles, "
                      & Img (Q / 1.0E6, 2) & " million quads (" & Img (Q * 8.0 / 1_048_576.0, 0) & " MB), "
                      & Img (T, 1) & " s of a worker");
            All_Quads := All_Quads + Q;
            All_Ms := All_Ms + T;
            R0 := R1;
         end;
      end loop;
      Put_Line ("  in all: " & Img (All_Quads / 1.0E6, 1) & " million quads (" & Img (All_Quads * 8.0 / 1_048_576.0, 0)
                & " MB), " & Img (All_Ms, 0) & " s of a worker");
   end;
end Lod_Stats;
