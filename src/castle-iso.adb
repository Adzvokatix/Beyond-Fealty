with Ada.Unchecked_Deallocation;
with Interfaces;  use Interfaces;
with Castle.Colors;
with Castle.Hash; use Castle.Hash;

package body Castle.Iso is

   type Face is (None, Top, Left, Right);
   type Sprite is array (Natural range <>, Natural range <>) of Face;   --  (row, column)

   type Pt is record
      X, Y : Float;
   end record;
   type Quad is array (1 .. 4) of Pt;

   function Inside (Q : Quad; P : Pt) return Boolean is
      Pos, Neg : Boolean := False;
   begin
      for I in Q'Range loop
         declare
            A : constant Pt    := Q (I);
            B : constant Pt    := Q (if I = Q'Last then Q'First else I + 1);
            C : constant Float := (B.X - A.X) * (P.Y - A.Y) - (B.Y - A.Y) * (P.X - A.X);
         begin
            if C > 0.0 then
               Pos := True;
            elsif C < 0.0 then
               Neg := True;
            end if;
         end;
      end loop;
      return not (Pos and then Neg);
   end Inside;

   function Make_Sprite (S : Positive) return Sprite is
      F  : constant Float := Float (S);
      Tq : constant Quad  := ((F, 0.0), (2.0 * F, F / 2.0), (F, F), (0.0, F / 2.0));
      Lq : constant Quad  := ((0.0, F / 2.0), (F, F), (F, 2.0 * F), (0.0, 1.5 * F));
      Rq : constant Quad  := ((F, F), (2.0 * F, F / 2.0), (2.0 * F, 1.5 * F), (F, 2.0 * F));
      Sp : Sprite (0 .. 2 * S - 1, 0 .. 2 * S - 1) := (others => (others => None));
   begin
      for Row in Sp'Range (1) loop
         for Col in Sp'Range (2) loop
            declare
               P : constant Pt := (Float (Col) + 0.5, Float (Row) + 0.5);
            begin
               if Inside (Tq, P) then
                  Sp (Row, Col) := Top;
               elsif Inside (Lq, P) then
                  Sp (Row, Col) := Left;
               elsif Inside (Rq, P) then
                  Sp (Row, Col) := Right;
               end if;
            end;
         end loop;
      end loop;
      return Sp;
   end Make_Sprite;

   type Depth_Buf is array (Natural range <>, Natural range <>) of Integer;
   type Depth_Access is access Depth_Buf;
   procedure Free is new Ada.Unchecked_Deallocation (Depth_Buf, Depth_Access);

   function Render
     (Vox    : Grid;
      Z_Lo   : Natural;
      Z_Hi   : Natural;
      Seed   : U64;
      Flip_X : Boolean := False;
      Flip_Y : Boolean := False;
      Scale  : Positive := 4) return Image_Access
   is
      S    : constant Positive := Scale;
      Mask : constant Sprite   := Make_Sprite (S);
      Dx  : constant Integer := (if Flip_X then -1 else 1);
      Dy  : constant Integer := (if Flip_Y then -1 else 1);
      Nx  : constant Integer := Vox'Length (1);
      Ny  : constant Integer := Vox'Length (2);
      Wd  : constant Integer := (Nx + Ny) * S + 2 * S;
      Ht  : constant Integer := (Nx + Ny) * S / 2 + (Z_Hi - Z_Lo + 1) * S + 2 * S;
      Pic : constant Image_Access := new Image (0 .. Ht - 1, 0 .. Wd - 1);
      Dep : Depth_Access := new Depth_Buf (0 .. Ht - 1, 0 .. Wd - 1);

      function Open (X, Y, Z : Integer) return Boolean is
        (X not in Vox'Range (1) or else Y not in Vox'Range (2) or else Z > Vox'Last (3)
         or else Vox (X, Y, Z) = Air);
   begin
      for Row in 0 .. Ht - 1 loop
         for Col in 0 .. Wd - 1 loop
            Pic (Row, Col) := (R => 250, G => 250, B => 247);
            Dep (Row, Col) := Integer'First;
         end loop;
      end loop;

      for X in Vox'Range (1) loop
         for Y in Vox'Range (2) loop
            for Z in Z_Lo .. Z_Hi loop
               declare
                  M : constant Material := Vox (X, Y, Z);
               begin
                  if M /= Air
                    and then (Open (X, Y, Z + 1) or else Open (X + Dx, Y, Z) or else Open (X, Y + Dy, Z))
                  then
                     declare
                        Lx   : constant Integer :=
                          (if Flip_X then Vox'Last (1) - X else X - Vox'First (1));
                        Ly   : constant Integer :=
                          (if Flip_Y then Vox'Last (2) - Y else Y - Vox'First (2));
                        Ax   : constant Integer := (Lx - Ly + Ny - 1) * S + S / 2;
                        Ay   : constant Integer := (Lx + Ly) * S / 2 + (Z_Hi - Z) * S + S / 2;
                        Key  : constant Integer := Lx + Ly + Z;
                        J    : constant Float   := 0.92 + 0.16 * Unit_3 (Seed, X, Y, Z);
                        Base : constant Castle.Colors.RGB := Base_Color (M);
                     begin
                        for Row in Mask'Range (1) loop
                           for Col in Mask'Range (2) loop
                              if Mask (Row, Col) /= None and then Key >= Dep (Ay + Row, Ax + Col) then
                                 Dep (Ay + Row, Ax + Col) := Key;
                                 declare
                                    Sh : constant Float :=
                                      J * (case Mask (Row, Col) is
                                              when Top   => 1.0,
                                              when Left  => 0.80,
                                              when Right => 0.64,
                                              when None  => 0.0);
                                 begin
                                    Pic (Ay + Row, Ax + Col) :=
                                      (R => Unsigned_8 (Float'Min (255.0, Float (Base.R) * Sh)),
                                       G => Unsigned_8 (Float'Min (255.0, Float (Base.G) * Sh)),
                                       B => Unsigned_8 (Float'Min (255.0, Float (Base.B) * Sh)));
                                 end;
                              end if;
                           end loop;
                        end loop;
                     end;
                  end if;
               end;
            end loop;
         end loop;
      end loop;
      Free (Dep);
      return Pic;
   end Render;

end Castle.Iso;
