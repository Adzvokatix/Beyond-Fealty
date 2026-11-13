separate (Castle.Colony)
function Go_Forage (I : Positive; Only : Item_Kind := Nothing; Asked_Only : Boolean := False) return Boolean is
   M        : Member renames Band (I);
   --  How short the stores are of food: none when they hold all that is
   --  asked, 1 when they are down to where it is asked for again.
   function Food_Short return Float is
      G : constant Good_View := Food_Demand;
   begin
      return (if G.High <= G.Low then 0.0
              else Float'Max (0.0, Float'Min (1.0, (Float (G.High) - Float (G.Have)) / Float (G.High - G.Low))));
   end Food_Short;
   Demand   : constant Float :=
     (if Demand_Chain then Food_Short else Float'Max (0.0, Float'Min (1.0, 2.0 - (Food_Days - Held_Days))));
   Veg_Have : constant Natural := Have (Vegetables);
   Short    : constant Float :=
     (if Reserves (Vegetables) = 0 then 0.0
      else Float'Max (0.0, 1.0 - Float (Veg_Have) / Float (Reserves (Vegetables))));
   Pull     : constant Float := Veg_Pull * (1.0 + 0.5 * Demand) * (1.0 + Short);
   Reach    : constant Float := Float'Min (Forage_Reach_M, Work_Radius_M + 10.0 * Demand + 10.0 * Short);
   function Score (P : Vec3; Pl : Float) return Float is
     ((Flat_Dist (M.Pos, P) + 0.5 * Flat_Dist (Stake_At, P)) / Pl);
   S_Bush, S_Veg, S_Apple : Float := Float'Last;
   Veg_P  : Block_Pos;
   Found  : Boolean := False;
   Bush_K, Tree_K : Natural := 0;
   --  a kind it may go for: the one it is filling its basket with, and (on
   --  a gatherer's errand) only one that is asked for
   function Open (K : Item_Kind) return Boolean is
     (Only in Nothing | K and then (not Asked_Only or else Asked_For (K)));
begin
   if Winter_Now then                    --  the berries gone, the roots under the snow
      M.Why := Winter_Bare;
      return False;
   end if;
   if Open (Vegetables) and then not Failed (M, Kind_Id (Vegetables)) then
      Find_Source (Vegetables, M.Pos, I, Veg_P, Found, Reach);
      if Found then
         S_Veg := Score (Centre_Of (Veg_P), Pull);
      end if;
   end if;
   --  none in store: vegetables alone, while there are any
   if not (Found and then Veg_Have = 0 and then Reserves (Vegetables) > 0) then
      if Open (Berries) then
         Bush_K := Best_Bush (I);
         if Bush_K > 0 then
            S_Bush := Score (Bushes (Bush_K).Centre, 1.0);
         end if;
      end if;
      if Open (Apples) then
         Tree_K := Best_Apple_Tree (I);
         if Tree_K > 0 then
            S_Apple := Score (Tree_Base (Tree_K), Apple_Pull);
         end if;
      end if;
   end if;
   for Try in 1 .. 3 loop
      declare
         Best : constant Float := Float'Min (S_Veg, Float'Min (S_Bush, S_Apple));
      begin
         exit when Best = Float'Last;
         if S_Veg = Best then
            S_Veg := Float'Last;
            if Go_Fetch (I, Vegetables, Reach) then
               return True;
            end if;
         elsif S_Bush = Best then
            S_Bush := Float'Last;
            if Go_Pick (I) then
               return True;
            end if;
         else
            S_Apple := Float'Last;
            if Go_Apples (I, Tree_K) then
               return True;
            end if;
         end if;
      end;
   end loop;
   M.Why := (if Asked_Only and then not (for some G of Gathered => Open (G)) then Enough_Food else No_Bush);
   return False;
end Go_Forage;
