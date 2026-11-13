package Castle.Text is

   function Img (X : Integer) return String;
   function Img (X : Long_Long_Integer) return String;
   function Img (X : Float; Aft : Natural := 1) return String;
   --  Aft 0: rounded to a whole number, no point.

   --  A short line of text held by value, for records: a name, a label, a
   --  value.  Longer text is cut to Max_Line.
   Max_Line : constant := 120;
   type Line is record
      S : String (1 .. Max_Line) := [others => ' '];
      N : Natural := 0;
   end record;
   function To_Line (S : String) return Line;
   function Str (L : Line) return String;

   function Capital (S : String) return String;   --  its first letter a capital

end Castle.Text;
