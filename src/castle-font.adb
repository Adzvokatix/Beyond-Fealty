with Castle.Font_Data; use Castle.Font_Data;

package body Castle.Font is

   function Code_Of (C : Character) return Code is
      P : constant Natural := Character'Pos (C);
   begin
      if P in 32 .. 126 then
         return P;
      elsif P = 176 then   --  degree sign (Latin-1)
         return 127;
      else
         return Character'Pos ('?');
      end if;
   end Code_Of;

   function Width (C : Code) return Natural is (Glyphs (C).Width);

   function Advance (C : Code) return Natural is
     (if C = 32 then Glyphs (C).Width else Glyphs (C).Width + 1);

   function Cell_X (C : Code) return Natural is (((C - First) mod Per_Row) * Cell_W);
   function Cell_Y (C : Code) return Natural is (((C - First) / Per_Row) * Cell_H);

   function String_Width (S : String) return Natural is
      W : Natural := 0;
   begin
      for Ch of S loop
         W := W + Advance (Code_Of (Ch));
      end loop;
      if S'Length > 0 and then Code_Of (S (S'Last)) /= 32 then
         W := W - 1;
      end if;
      return W;
   end String_Width;

   procedure Atlas (Pixels : out Atlas_Pixels) is
   begin
      Pixels := [others => [others => 0]];
      for C in Code loop
         for R in Picture'Range loop
            for K in 1 .. Glyphs (C).Width loop
               if Glyphs (C).Pic (R) (K) = '#' then
                  Pixels (Cell_Y (C) + R, Cell_X (C) + K - 1) := 255;
               end if;
            end loop;
         end loop;
      end loop;
   end Atlas;

end Castle.Font;
