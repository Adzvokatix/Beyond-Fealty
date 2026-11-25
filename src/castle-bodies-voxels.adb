with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;

package body Castle.Bodies.Voxels is

   use type Interfaces.Unsigned_32;
   subtype U32 is Interfaces.Unsigned_32;

   Parts : array (Bone) of VM.Part := [others => (G => new VM.Grid, others => <>)];
   function Part_Of (B : Bone) return VM.Part is (Parts (B));

   --  P in the box's own frame (from its near corner), with its narrowing undone.
   function Unnarrowed (K : Box; V : Vec3) return Vec3 is
      H : constant Float := Float'Max (0.0, Float'Min (1.0, V.Z / Float'Max (K.Size.Z, 1.0e-4)));
      S : constant Float := (if K.Taper > 0.0 then 1.0 - K.Taper * (1.0 - H) elsif K.Taper < 0.0 then 1.0 + K.Taper * H
                             else 1.0);
   begin
      return (0.5 * K.Size.X + (V.X - 0.5 * K.Size.X) / S, 0.5 * K.Size.Y + (V.Y - 0.5 * K.Size.Y) / S, V.Z);
   end Unnarrowed;

   function Outside (K : Box; P : Vec3) return Float is
      R  : constant Float := Rounding (K);
      U  : constant Vec3 := Unnarrowed (K, (P.X - K.Lo.X, P.Y - K.Lo.Y, P.Z - K.Lo.Z));
      Qx : constant Float := abs (U.X - 0.5 * K.Size.X) - (0.5 * K.Size.X - R);
      Qy : constant Float := abs (U.Y - 0.5 * K.Size.Y) - (0.5 * K.Size.Y - R);
      Qz : constant Float := abs (U.Z - 0.5 * K.Size.Z) - (0.5 * K.Size.Z - R);
      Ox : constant Float := Float'Max (Qx, 0.0);
      Oy : constant Float := Float'Max (Qy, 0.0);
      Oz : constant Float := Float'Max (Qz, 0.0);
      D  : constant Float := Sqrt (Ox * Ox + Oy * Oy + Oz * Oz) + Float'Min (Float'Max (Qx, Float'Max (Qy, Qz)), 0.0) - R;
      Re : constant Float :=
        Float'Min (K.Round_Ends, 0.45 * Float'Min (K.Size.X, Float'Min (K.Size.Y, K.Size.Z)));
   begin
      if Re <= R then
         return D;
      end if;
      --  Its top and bottom edges rounded by Re, its upright edges by R: the box cut by two slabs, one
      --  rounded across X and Z (and as long as it likes in Y), the other across Y and Z.
      declare
         Ax : constant Float := abs (U.X - 0.5 * K.Size.X) - (0.5 * K.Size.X - Re);
         Ay : constant Float := abs (U.Y - 0.5 * K.Size.Y) - (0.5 * K.Size.Y - Re);
         Az : constant Float := abs (U.Z - 0.5 * K.Size.Z) - (0.5 * K.Size.Z - Re);
         function Slab (A, B : Float) return Float is
           (Sqrt (Float'Max (A, 0.0) ** 2 + Float'Max (B, 0.0) ** 2) + Float'Min (Float'Max (A, B), 0.0) - Re);
      begin
         return Float'Max (D, Float'Max (Slab (Ax, Az), Slab (Ay, Az)));
      end;
   end Outside;

   --  The skin's texel for the point P of box K: at the nearest of its six faces.
   function Texel (K : Box; Skin : Skin_Pixels; P : Vec3) return U32 is
      U  : constant Vec3 := Unnarrowed (K, (P.X - K.Lo.X, P.Y - K.Lo.Y, P.Z - K.Lo.Z));
      Fx : constant Float := Float'Max (0.0, Float'Min (0.9999, U.X / Float'Max (K.Size.X, 1.0e-4)));
      Fy : constant Float := Float'Max (0.0, Float'Min (0.9999, U.Y / Float'Max (K.Size.Y, 1.0e-4)));
      Fz : constant Float := Float'Max (0.0, Float'Min (0.9999, U.Z / Float'Max (K.Size.Z, 1.0e-4)));
      D  : constant array (Face) of Float :=
        [Pos_X => K.Size.X - U.X, Neg_X => U.X, Pos_Y => K.Size.Y - U.Y, Neg_Y => U.Y, Pos_Z => K.Size.Z - U.Z,
         Neg_Z => U.Z];
      F  : Face := Pos_X;
      Sx, Sy : Float;
      U0, V0, Wf, Hf : Natural;
   begin
      for G in Face loop
         if D (G) < D (F) then
            F := G;
         end if;
      end loop;
      case F is            --  (as box_face lays a face out in Castle.Render)
         when Pos_X => Sx := Fy;        Sy := 1.0 - Fz;
         when Neg_X => Sx := 1.0 - Fy;  Sy := 1.0 - Fz;
         when Pos_Y => Sx := 1.0 - Fx;  Sy := 1.0 - Fz;
         when Neg_Y => Sx := Fx;        Sy := 1.0 - Fz;
         when Pos_Z => Sx := 1.0 - Fx;  Sy := Fy;
         when Neg_Z => Sx := 1.0 - Fx;  Sy := 1.0 - Fy;
      end case;
      Face_Rect (K, F, U0, V0, Wf, Hf);
      if Wf = 0 or else Hf = 0 then
         return 0;
      end if;
      return Skin (Integer'Min (Skin_H - 1, V0 + Integer'Min (Hf - 1, Integer (Float'Floor (Float'Min (0.9999, Float'Max (0.0, Sy)) * Float (Hf))))),
                   Integer'Min (Skin_W - 1, U0 + Integer'Min (Wf - 1, Integer (Float'Floor (Float'Min (0.9999, Float'Max (0.0, Sx)) * Float (Wf))))));
   end Texel;

   procedure Build (R : Rig; Skin : Skin_Pixels; L : out Voxel_Look; Brief_Mesh : Boolean := True) is
      function Index_Of (C : U32) return VM.U8 is
         Best : Natural := 1;
         Best_D : Integer := Integer'Last;
      begin
         for I in 1 .. L.Colours loop
            if L.Pal (I) = C then
               return VM.U8 (I);
            end if;
         end loop;
         if L.Colours < 255 then
            L.Colours := L.Colours + 1;
            L.Pal (L.Colours) := C;
            return VM.U8 (L.Colours);
         end if;
         L.Merged := L.Merged + 1;
         for I in 1 .. L.Colours loop
            declare
               function Ch (V : U32; S : Natural) return Integer is (Integer (Interfaces.Shift_Right (V, S) and 255));
               D : constant Integer :=
                 abs (Ch (L.Pal (I), 0) - Ch (C, 0)) + abs (Ch (L.Pal (I), 8) - Ch (C, 8))
                 + abs (Ch (L.Pal (I), 16) - Ch (C, 16));
            begin
               if D < Best_D then
                  Best_D := D;
                  Best := I;
               end if;
            end;
         end loop;
         return VM.U8 (Best);
      end Index_Of;
      Took : array (1 .. Max_Boxes) of Boolean := [others => False];
   begin
      L.N := 0;
      L.Drawn_N := 0;
      L.Bytes_N := 0;
      L.Per_Bone := [others => 0];
      L.Pal := [others => 0];
      L.Colours := 0;
      L.Merged := 0;
      L.Solid := 0;
      L.Surface := 0;
      L.Empty := 0;
      for B in Bone loop
         declare
            P : VM.Part renames Parts (B);
            Lo : Int3 := (Integer'Last, Integer'Last, Integer'Last);
            Hi : Int3 := (Integer'First, Integer'First, Integer'First);
            Any : Boolean := False;
         begin
            for K in 1 .. R.Count loop
               if R.Boxes (K).On = B then
                  declare
                     X : Box renames R.Boxes (K);
                  begin
                     Any := True;
                     Lo := (Integer'Min (Lo.X, Integer (Float'Floor (X.Lo.X * 2.0))),
                            Integer'Min (Lo.Y, Integer (Float'Floor (X.Lo.Y * 2.0))),
                            Integer'Min (Lo.Z, Integer (Float'Floor (X.Lo.Z * 2.0))));
                     Hi := (Integer'Max (Hi.X, Integer (Float'Ceiling ((X.Lo.X + X.Size.X) * 2.0)) - 1),
                            Integer'Max (Hi.Y, Integer (Float'Ceiling ((X.Lo.Y + X.Size.Y) * 2.0)) - 1),
                            Integer'Max (Hi.Z, Integer (Float'Ceiling ((X.Lo.Z + X.Size.Z) * 2.0)) - 1));
                  end;
               end if;
            end loop;
            if not Any then
               P.Nx := 0;  P.Ny := 0;  P.Nz := 0;
               P.Ox := 0;  P.Oy := 0;  P.Oz := 0;
            else
               if Hi.X - Lo.X + 1 > VM.Side or else Hi.Y - Lo.Y + 1 > VM.Side or else Hi.Z - Lo.Z + 1 > VM.Side then
                  raise Constraint_Error with "a voxel part of more than" & VM.Side'Image & " voxels a side: " & B'Image;
               end if;
               P.Ox := Lo.X;  P.Oy := Lo.Y;  P.Oz := Lo.Z;
               P.Nx := Hi.X - Lo.X + 1;  P.Ny := Hi.Y - Lo.Y + 1;  P.Nz := Hi.Z - Lo.Z + 1;
               for I in 0 .. P.Nx - 1 loop
                  for J in 0 .. P.Ny - 1 loop
                     for Kz in 0 .. P.Nz - 1 loop
                        declare
                           C : constant Vec3 := ((Float (P.Ox + I) + 0.5) * 0.5, (Float (P.Oy + J) + 0.5) * 0.5,
                                                 (Float (P.Oz + Kz) + 0.5) * 0.5);      --  its centre, body pixels
                           Best : Natural := 0;
                           Best_D : Float := Float'First;
                           Colour : U32 := 0;
                        begin
                           for K in 1 .. R.Count loop
                              if R.Boxes (K).On = B then
                                 declare
                                    D : constant Float := Outside (R.Boxes (K), C);
                                 begin
                                    if D <= 0.0 and then D >= Best_D then
                                       declare
                                          T : constant U32 := Texel (R.Boxes (K), Skin, C);
                                       begin
                                          if Interfaces.Shift_Right (T, 24) /= 0 then      --  (see-through: not this box's)
                                             Best := K;
                                             Best_D := D;
                                             Colour := T;
                                          end if;
                                       end;
                                    end if;
                                 end;
                              end if;
                           end loop;
                           if Best > 0 then
                              P.G (I, J, Kz) := Index_Of (Colour);
                              Took (Best) := True;
                           else
                              P.G (I, J, Kz) := 0;
                           end if;
                        end;
                     end loop;
                  end loop;
               end loop;
            end if;
            L.Origin (B) := (P.Ox, P.Oy, P.Oz);
            L.Size (B) := (P.Nx, P.Ny, P.Nz);
            declare
               N0 : constant Natural := L.N;
               S, F : Natural;
               Vol : constant Natural := P.Nx * P.Ny * P.Nz;
            begin
               if Brief_Mesh then
                  VM.Mesh (P, Bone'Pos (B), L.Quads, L.N);
               end if;
               L.Per_Bone (B) := L.N - N0;
               VM.Mesh (P, Bone'Pos (B), L.Drawn, L.Drawn_N, By_Colour => False);
               VM.Count (P, S, F);
               L.Solid := L.Solid + S;
               L.Surface := L.Surface + F;
               if L.Bytes_N + Vol > Max_Bytes then
                  raise Constraint_Error with "a voxel look of more than" & Max_Bytes'Image & " voxels";
               end if;
               L.Parts (B) := (Offset => L.Bytes_N, Ox => P.Ox, Oy => P.Oy, Oz => P.Oz, Nx => P.Nx, Ny => P.Ny, Nz => P.Nz);
               for Kz in 0 .. P.Nz - 1 loop
                  for J in 0 .. P.Ny - 1 loop
                     for I in 0 .. P.Nx - 1 loop
                        L.Bytes (L.Bytes_N + I + P.Nx * (J + P.Ny * Kz)) := P.G (I, J, Kz);
                     end loop;
                  end loop;
               end loop;
               L.Bytes_N := L.Bytes_N + Vol;
            end;
         end;
      end loop;
      for K in 1 .. R.Count loop
         if not Took (K) then
            L.Empty := L.Empty + 1;
         end if;
      end loop;
   end Build;

end Castle.Bodies.Voxels;
