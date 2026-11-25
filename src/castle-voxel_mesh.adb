with Ada.Unchecked_Deallocation;

package body Castle.Voxel_Mesh is

   use type Interfaces.Unsigned_8;
   use type Interfaces.Unsigned_32;

   function Pack (X, Y, Z : Coord; W, H : Positive; F : Facing; Colour : U8; Bone : Natural) return Quad is
   begin
      return (A => U32 (X) or Interfaces.Shift_Left (U32 (Y), 6) or Interfaces.Shift_Left (U32 (Z), 12)
                   or Interfaces.Shift_Left (U32 (W - 1), 18) or Interfaces.Shift_Left (U32 (H - 1), 24),
              B => U32 (Facing'Pos (F)) or Interfaces.Shift_Left (U32 (Colour), 3)
                   or Interfaces.Shift_Left (U32 (Bone), 11));
   end Pack;

   procedure Unpack (Q : Quad; X, Y, Z : out Coord; W, H : out Positive; F : out Facing; Colour : out U8;
                     Bone : out Natural) is
   begin
      X := Coord (Q.A and 63);
      Y := Coord (Interfaces.Shift_Right (Q.A, 6) and 63);
      Z := Coord (Interfaces.Shift_Right (Q.A, 12) and 63);
      W := Natural (Interfaces.Shift_Right (Q.A, 18) and 63) + 1;   --  (stored less one: 0 is a width of one)
      H := Natural (Interfaces.Shift_Right (Q.A, 24) and 63) + 1;
      F := Facing'Val (Natural (Q.B and 7));
      Colour := U8 (Interfaces.Shift_Right (Q.B, 3) and 255);
      Bone := Natural (Interfaces.Shift_Right (Q.B, 11) and 15);
   end Unpack;

   function At_P (P : Part; X, Y, Z : Integer) return U8 is
     (if X in 0 .. P.Nx - 1 and then Y in 0 .. P.Ny - 1 and then Z in 0 .. P.Nz - 1 then P.G (X, Y, Z) else 0);

   procedure Mesh (P : Part; Bone : Natural; Quads : in out Quad_Array; N : in out Natural;
                   By_Colour : Boolean := True) is
      --  (a layer's faces: the colour of each voxel whose side that way is open, 0 where none)
      Mask : array (Coord, Coord) of U8;
   begin
      for F in Facing loop
         declare
            Axis : constant Natural := Facing'Pos (F) / 2;          --  0 X, 1 Y, 2 Z
            Step : constant Integer := (if Facing'Pos (F) mod 2 = 0 then 1 else -1);
            Nl : constant Natural := (case Axis is when 0 => P.Nx, when 1 => P.Ny, when others => P.Nz);
            Nu : constant Natural := (if Axis = 0 then P.Ny else P.Nx);
            Nv : constant Natural := (if Axis = 2 then P.Ny else P.Nz);
            function V_At (L, U, V : Integer) return U8 is
              (case Axis is when 0 => At_P (P, L, U, V), when 1 => At_P (P, U, L, V), when others => At_P (P, U, V, L));
         begin
            for L in 0 .. Nl - 1 loop
               for U in 0 .. Nu - 1 loop
                  for V in 0 .. Nv - 1 loop
                     Mask (U, V) :=
                       (if V_At (L, U, V) /= 0 and then V_At (L + Step, U, V) = 0
                        then (if By_Colour then V_At (L, U, V) else 1) else 0);
                  end loop;
               end loop;
               for V in 0 .. Nv - 1 loop
                  declare
                     U : Natural := 0;
                  begin
                     while U < Nu loop
                        if Mask (U, V) = 0 then
                           U := U + 1;
                        else
                           declare
                              C : constant U8 := Mask (U, V);
                              W : Positive := 1;
                              H : Positive := 1;
                              Whole : Boolean;
                           begin
                              while U + W < Nu and then Mask (U + W, V) = C loop
                                 W := W + 1;
                              end loop;
                              loop
                                 exit when V + H >= Nv;
                                 Whole := (for all K in U .. U + W - 1 => Mask (K, V + H) = C);
                                 exit when not Whole;
                                 H := H + 1;
                              end loop;
                              for K in U .. U + W - 1 loop
                                 for J in V .. V + H - 1 loop
                                    Mask (K, J) := 0;
                                 end loop;
                              end loop;
                              if N >= Quads'Last then      --  (so that a look too big is said, not written past)
                                 raise Constraint_Error with "more than" & Quads'Last'Image & " voxel quads";
                              end if;
                              N := N + 1;
                              Quads (N) := (case Axis is
                                               when 0 => Pack (L, U, V, W, H, F, (if By_Colour then C else 0), Bone),
                                               when 1 => Pack (U, L, V, W, H, F, (if By_Colour then C else 0), Bone),
                                               when others => Pack (U, V, L, W, H, F, (if By_Colour then C else 0), Bone));
                              U := U + W;
                           end;
                        end if;
                     end loop;
                  end;
               end loop;
            end loop;
         end;
      end loop;
   end Mesh;

   procedure Quads_Of (P : Part; By_Colour, Any_Colour, Unmerged : out Natural) is
      type Quads_Access is access Quad_Array;
      Q : Quads_Access := new Quad_Array (1 .. 40_000);
      Flat : Part := (G => new Grid, Nx => P.Nx, Ny => P.Ny, Nz => P.Nz, Ox => P.Ox, Oy => P.Oy, Oz => P.Oz);
      N : Natural := 0;
      S, F : Natural;
      procedure Free is new Ada.Unchecked_Deallocation (Quad_Array, Quads_Access);
      procedure Free is new Ada.Unchecked_Deallocation (Grid, Grid_Access);
   begin
      Mesh (P, 0, Q.all, N);
      By_Colour := N;
      Unmerged := 0;
      for X in 0 .. P.Nx - 1 loop
         for Y in 0 .. P.Ny - 1 loop
            for Z in 0 .. P.Nz - 1 loop
               Flat.G (X, Y, Z) := (if P.G (X, Y, Z) /= 0 then 1 else 0);
               if P.G (X, Y, Z) /= 0 then
                  Unmerged := Unmerged
                    + (if At_P (P, X + 1, Y, Z) = 0 then 1 else 0) + (if At_P (P, X - 1, Y, Z) = 0 then 1 else 0)
                    + (if At_P (P, X, Y + 1, Z) = 0 then 1 else 0) + (if At_P (P, X, Y - 1, Z) = 0 then 1 else 0)
                    + (if At_P (P, X, Y, Z + 1) = 0 then 1 else 0) + (if At_P (P, X, Y, Z - 1) = 0 then 1 else 0);
               end if;
            end loop;
         end loop;
      end loop;
      N := 0;
      Mesh (Flat, 0, Q.all, N);
      Any_Colour := N;
      Count (Flat, S, F);
      Free (Q);
      Free (Flat.G);
   end Quads_Of;

   procedure Halve (P : Part; Into : in out Part) is
      Ox : constant Integer := (if P.Ox mod 2 = 0 then P.Ox else P.Ox - 1);     --  (on the coarse grid's own lattice)
      Oy : constant Integer := (if P.Oy mod 2 = 0 then P.Oy else P.Oy - 1);
      Oz : constant Integer := (if P.Oz mod 2 = 0 then P.Oz else P.Oz - 1);
   begin
      Into.Ox := Ox / 2 - (if Ox < 0 and then Ox mod 2 /= 0 then 1 else 0);
      Into.Oy := Oy / 2 - (if Oy < 0 and then Oy mod 2 /= 0 then 1 else 0);
      Into.Oz := Oz / 2 - (if Oz < 0 and then Oz mod 2 /= 0 then 1 else 0);
      Into.Nx := (P.Ox + P.Nx - Ox + 1) / 2;
      Into.Ny := (P.Oy + P.Ny - Oy + 1) / 2;
      Into.Nz := (P.Oz + P.Nz - Oz + 1) / 2;
      for X in 0 .. Into.Nx - 1 loop
         for Y in 0 .. Into.Ny - 1 loop
            for Z in 0 .. Into.Nz - 1 loop
               declare
                  Seen : array (1 .. 8) of U8 := [others => 0];
                  Ns : Natural := 0;
                  Best : U8 := 0;
                  Best_N : Natural := 0;
               begin
                  for Dx in 0 .. 1 loop
                     for Dy in 0 .. 1 loop
                        for Dz in 0 .. 1 loop
                           declare
                              C : constant U8 := At_P (P, Ox - P.Ox + 2 * X + Dx, Oy - P.Oy + 2 * Y + Dy, Oz - P.Oz + 2 * Z + Dz);
                           begin
                              if C /= 0 then
                                 Ns := Ns + 1;
                                 Seen (Ns) := C;
                              end if;
                           end;
                        end loop;
                     end loop;
                  end loop;
                  if Ns >= 4 then
                     for I in 1 .. Ns loop
                        declare
                           K : Natural := 0;
                        begin
                           for J in 1 .. Ns loop
                              if Seen (J) = Seen (I) then
                                 K := K + 1;
                              end if;
                           end loop;
                           if K > Best_N or else (K = Best_N and then Seen (I) < Best) then
                              Best_N := K;
                              Best := Seen (I);
                           end if;
                        end;
                     end loop;
                  end if;
                  Into.G (X, Y, Z) := Best;
               end;
            end loop;
         end loop;
      end loop;
   end Halve;

   procedure Count (P : Part; Solid, Surface : out Natural) is
   begin
      Solid := 0;
      Surface := 0;
      for X in 0 .. P.Nx - 1 loop
         for Y in 0 .. P.Ny - 1 loop
            for Z in 0 .. P.Nz - 1 loop
               if P.G (X, Y, Z) /= 0 then
                  Solid := Solid + 1;
                  if At_P (P, X + 1, Y, Z) = 0 or else At_P (P, X - 1, Y, Z) = 0 or else At_P (P, X, Y + 1, Z) = 0
                    or else At_P (P, X, Y - 1, Z) = 0 or else At_P (P, X, Y, Z + 1) = 0 or else At_P (P, X, Y, Z - 1) = 0
                  then
                     Surface := Surface + 1;
                  end if;
               end if;
            end loop;
         end loop;
      end loop;
   end Count;

end Castle.Voxel_Mesh;
