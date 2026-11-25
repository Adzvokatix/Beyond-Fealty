separate (Castle.Colony)
procedure Index_Some (Budget : Natural) is
   Done  : Natural := 0;
   SX    : constant Integer := Integer (Float'Floor (Stake_At.X / 8.0));
   SY    : constant Integer := Integer (Float'Floor (Stake_At.Y / 8.0));
   --  (as far as its work reaches; further while the band looks further, and as far as its
   --  foresters look for a tree)
   Rings : constant Integer :=
     Integer (Float'Max (Float'Max (Float'Max (Forage_Reach_M, Far_Reach), Wood_Reach),
                         Float'Max (Food_Reach, Haul_Reach)) / 8.0) + 1;
   --  Past where anyone gathers, a stack is looked through for what the
   --  camp's building is after (boulders, trees), not for its bushes.
   --  (as far as the gatherers look: a stack looked through before that for its trees
   --  alone is looked through again for its bushes)
   Near  : constant Integer := Integer (Float'Max (Forage_Reach_M, Food_Reach) / 8.0) + 1;
begin
   if not Stake_Set or else Version_Src = null then
      return;
   end if;
   --  Ring by ring, each ring's stacks in the order they always came in
   --  (west to east, and south to north within a column), but only the
   --  ring's own: the rest of the square inside it was walked through and
   --  passed over for every ring, twenty times a second (a fifth of the
   --  reference band's time went on it).
   for R in 0 .. Rings loop
      for DX in -R .. R loop
         declare
            Whole : constant Boolean := abs DX = R;     --  the ring's west or east side
            DY    : Integer := -R;
         begin
            loop
               if SX + DX in Indexed_Grid'Range (1) and then SY + DY in Indexed_Grid'Range (2)
                 and then (not Indexed (SX + DX, SY + DY) or else (R <= Near and then Indexed_Far (SX + DX, SY + DY)))
                 and then Own_V (SX + DX, SY + DY) > 0
               then
                  Index_Stack (SX + DX, SY + DY, Far => R > Near);
                  Done := Done + 1;
                  if Done >= Budget then
                     return;
                  end if;
               end if;
               exit when DY = R;
               DY := (if Whole then DY + 1 else R);
            end loop;
         end;
      end loop;
   end loop;
end Index_Some;
