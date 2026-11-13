with Ada.Strings;       use Ada.Strings;
with Ada.Strings.Fixed; use Ada.Strings.Fixed;
with Ada.Float_Text_IO;
with Ada.Characters.Handling;

package body Castle.Text is

   function Img (X : Integer) return String is
   begin
      return Trim (Integer'Image (X), Left);
   end Img;

   function Img (X : Long_Long_Integer) return String is
   begin
      return Trim (Long_Long_Integer'Image (X), Left);
   end Img;

   function Img (X : Float; Aft : Natural := 1) return String is
      Buf : String (1 .. 48);
   begin
      if Aft = 0 and then abs X < 2.0E9 then
         return Img (Integer (Float'Rounding (X)));   --  Put gives one decimal even at Aft 0
      end if;
      Ada.Float_Text_IO.Put (Buf, X, Aft => Aft, Exp => 0);
      return Trim (Buf, Both);
   end Img;

   function To_Line (S : String) return Line is
      L : Line;
   begin
      L.N := Natural'Min (S'Length, Max_Line);
      L.S (1 .. L.N) := S (S'First .. S'First + L.N - 1);
      return L;
   end To_Line;

   function Str (L : Line) return String is (L.S (1 .. L.N));

   function Capital (S : String) return String is
      R : String := S;
   begin
      if R'Length > 0 then
         R (R'First) := Ada.Characters.Handling.To_Upper (R (R'First));
      end if;
      return R;
   end Capital;

end Castle.Text;
