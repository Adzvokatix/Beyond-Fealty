separate (Castle.Colony)
function Status (I : Positive) return String is
   M : Member renames Band (I);
   function N_Of (N : Natural) return String is
     (Natural'Image (N) (2 .. Natural'Image (N)'Last));
   --  the house it is building, as it is spoken of
   --  (the storehouse by its name: its builder was said to be levelling the ground "for a hovel")
   function Its_House return String is
     (if M.Site in 1 .. N_Houses and then M.Site = Store_House then "the storehouse"
      elsif M.Site in 1 .. N_Houses and then Houses (M.Site).Owner in 1 .. N_Members
      then (if Houses (M.Site).Owner = I then "its own hovel" else Name_Of (Houses (M.Site).Owner) & "'s hovel")
      else "a hovel");
   function Doing_Now return String is
   begin
   case M.State is
      when Making    => return "making a ladder";
      when To_Fitting =>
         return "carrying a log to make " & (if M.Cell in 1 .. N_Cells and then Cells (M.Cell).Fit = Shelf
                                              then "a shelf" else "a barrel") & " in the storehouse";
      when Fitting_Out =>
         return "making " & (if M.Cell in 1 .. N_Cells and then Cells (M.Cell).Fit = Shelf then "a shelf"
                             else "a barrel") & " in the storehouse";
      when To_Ladder => return "going for the ladder";
      when To_Site   =>
         return (if M.Site in 1 .. N_Houses and then Houses (M.Site).Raze and then M.Site_Patch = 0
                 then "going to take down a hovel"
                 elsif M.Carried > 0 and then M.Carry = Ladder then "carrying the ladder to " & Its_House
                 elsif M.Carried > 0 and then M.Carry = Wood then "carrying a log to " & Its_House
                 elsif M.Carried > 0 and then M.Carry = Stone then "carrying stone to " & Its_House
                 elsif M.Carried > 0 then "carrying " & N_Of (M.Carried) & " " & Name (M.Carry) & " to " & Its_House
                 elsif M.Site_Patch > 0 then "going to make the ground ready for " & Its_House
                 else "going to work on " & Its_House);
      when Raising   =>
         return (if M.Site in 1 .. N_Houses and then Houses (M.Site).Raze and then M.Site_Patch = 0
                 then "taking down a hovel"
                 elsif M.Site_Patch > 0 then "levelling the ground for " & Its_House
                 elsif M.Site in 1 .. N_Houses and then Houses (M.Site).Placed < Houses (M.Site).Floor_N
                 then "beating the floor of " & Its_House
                 elsif M.Site in 1 .. N_Houses and then Houses (M.Site).Placed < Houses (M.Site).Frame_N
                 then "raising the frame of " & Its_House
                 elsif M.Site in 1 .. N_Houses and then Houses (M.Site).Placed < Houses (M.Site).Walls_N
                 then "daubing the walls of " & Its_House
                 elsif M.Site in 1 .. N_Houses and then Houses (M.Site).Placed < Houses (M.Site).Roof_N
                 then "thatching " & Its_House
                 elsif M.Site in 1 .. N_Houses and then Houses (M.Site).Cover_N < Houses (M.Site).Total
                   and then Houses (M.Site).Placed >= Houses (M.Site).Cover_N
                 then "smoothing the coverings' roofs by " & Its_House
                 else "trimming the thatch of " & Its_House);
      when To_Bush   => return "going to pick berries";
      when Picking   => return "picking berries (" & N_Of (M.Carried) & ")";
      when To_Store  =>
         return (if M.Carry = Ladder then "carrying the ladder to the stockpile"
                 elsif M.Carry = Wood then "carrying a log to the stockpile"
                 else "taking " & N_Of (M.Carried) & " " & Name (M.Carry) & " to the stockpile");
      when Storing   => return (if M.Carry = Wood then "stacking a log" elsif M.Carry = Ladder then "putting the ladder down"
                                else "putting down " & Name (M.Carry));
      when To_Tree   => return (if M.Tree in 1 .. N_Trees and then Trees (M.Tree).Down
                                then "going to take a stump out of the stockpile" else "going to fell a tree");
      when Chopping  => return (if M.Tree in 1 .. N_Trees and then Trees (M.Tree).Down
                                then "taking a stump out of the stockpile" else "felling a tree");
      when To_Pile   => return "going for a log";
      when Lifting   => return "lifting a log";
      when To_Source =>
         return "going for " & (if M.Fetch = Sticks and then M.Use_For = For_Frame then "deadwood"
                                else Name (M.Fetch))
           & (if M.Use_For in For_Ring | For_Frame then " for the hearth"
              elsif M.Use_For = For_Wall then " for the square's wall"
              elsif M.Use_For = For_Bed then " for its bed" else "");
      when To_Patch  =>
         return (if M.Site_Seg > 0 then "going to lay the path"
                 elsif M.Use_For = For_Wall and then M.Carried > 0
                 then "carrying " & N_Of (M.Carried) & " stone to the square's wall"
                 elsif M.Carry = Earth and then M.Carried > 0
                 then "carrying " & N_Of (M.Carried) & " earth to a hollow of the camp's ground"
                 else "going to make the camp's ground ready");
      when Tamping   =>
         return (if M.Site_Seg > 0 then "laying the path"
                 elsif M.Use_For = For_Wall and then M.Carried > 0 then "laying stone in the square's wall"
                 elsif M.Carry = Earth and then M.Carried > 0 then "filling a hollow of the camp's ground"
                 else "making the camp's ground ready");
      when To_Take   =>
         return (case M.Use_For is
                    when For_Pot  => "fetching " & (if M.Cell > 0 then Name (Cells (M.Cell).Kind) else "food")
                                     & " for the pot",
                    when For_Fire => "fetching wood for the fire",
                    when For_Seat => "fetching a log for a seat",
                    when For_Ring => "fetching stone for the hearth",
                    when For_Frame => "fetching a log for the hearth",
                    when For_Floor => "fetching earth for the camp's ground",
                    when For_House => "fetching "
                                      & (if M.Cell > 0 and then Cells (M.Cell).Kind = Ladder then "a ladder"
                                         elsif M.Cell > 0 then Name (Cells (M.Cell).Kind) else "what it takes")
                                      & " for " & Its_House,
                    when For_Bed => "fetching straw for its bed",
                    when For_Ladder => "fetching a log to make a ladder of",
                    when For_Fitting => "fetching a log for a shelf or a barrel",
                    when For_Wall => "fetching stone for the square's wall",
                    when For_Store | For_Stoke => "fetching");
      when Taking    => return "taking it from the stockpile";
      when To_Camp   =>
         if M.Carried = 0 then
            return (if M.Use_For = For_Stoke then "going to stoke the fire" else "going to the pot");
         end if;
         return (case M.Use_For is
                    when For_Pot  => "taking " & N_Of (M.Carried) & " " & Name (M.Carry) & " to the pot",
                    when For_Fire => (if M.Carry = Sticks then "taking sticks to the fire"
                                      else "carrying a log to the fire"),
                    when For_Seat => "carrying a log for a seat",
                    when For_Ring => "carrying " & N_Of (M.Carried) & " stone to the hearth",
                    when For_Frame => (if M.Carry = Sticks then "carrying deadwood to the hearth"
                                       else "carrying a log to the hearth"),
                    when For_Bed => "carrying straw to where it sleeps",
                    when For_Store | For_Stoke | For_Floor | For_House | For_Ladder | For_Fitting | For_Wall => "carrying");
      when Putting_In =>
         return (case M.Use_For is
                    when For_Pot  => "putting " & Name (M.Carry) & " in the pot",
                    when For_Fire => (if M.Carry = Sticks then "feeding the fire"
                                      elsif Labour_On and then Fuel_H <= 0.0 then "putting a log on the fire"
                                      else "stacking firewood"),
                    when For_Seat => "laying a seat log",
                    when For_Ring => "setting stones for the hearth",
                    when For_Frame => "setting up wood for the hearth",
                    when For_Bed => "making its bed",
                    when For_Store | For_Stoke | For_Floor | For_House | For_Ladder | For_Fitting | For_Wall =>
                      "putting it down");
      when Stoking   => return "stoking the fire";
      when Cooking   => return "stirring the stew";
      when To_Seat   => return "taking a bowl of stew to the fire";
      when Stalking  => return (if Sneaking_Now (I) then "stalking a deer" else "going after deer");
      when Aiming    => return "drawing the bow";
      when Recovering => return "letting the deer settle";
      when To_Cart    => return "going to the lord's cart for salt";
      when To_Tow     => return "going to pull the lord's cart";
      when Towing     => return "pulling the lord's cart to the stockpile";
      when At_Cart    => return "taking salt from the lord's cart";
      when To_Carcass => return "going for the kill";
      when Lifting_Carcass => return "lifting the deer";
      when To_Butcher => return "carrying a deer home";
      when Butchering => return "butchering a deer";
      when Gathering =>
         return (case M.Fetch is
                    when Straw => (if M.Use_For = For_Bed then "cutting straw for its bed (" else "cutting straw ("),
                    when Stone => "gathering stone (",
                    when Vegetables => "pulling vegetables (",
                    when Apples => "picking apples (",
                    when Sticks => (if M.Use_For = For_Frame then "picking up deadwood (" else "picking up sticks ("),
                    when others => "drawing water (") & N_Of (M.Carried) & ")";
      when Idle | Strolling =>
         if M.Job = Unassigned then
            return "waiting at the stake";
         end if;
         return (case M.Why is
                    when No_Bush => "nothing to gather in reach",
                    when No_Room => (if M.Carry /= Nothing then "nowhere to put " & Name (M.Carry)
                                     elsif M.Job = Forester then "nowhere to put wood"
                                     else "the stockpiles are full"),
                    when No_Way  => "can't get there",
                    when No_Tree => "no trees to fell in reach",
                    when Enough_Wood => (if Chain_On then "enough wood in store" else "enough wood (the reserve is met)"),
                    when Nothing_To_Haul => "nothing to carry",
                    when No_Source => "no " & Name (M.Fetch) & " in reach",
                    when Stocks_Full => "the stocks are full",
                    when No_Prey => "no deer to hunt in reach",
                    when Herds_Breeding => "the deer near are left to breed: no herd has more than"
                                           & Natural'Image (Spare_Last),
                    when Herd_Settling => "letting the herd it shot at settle",
                    when Nearly_Full => "the stockpile is nearly full: nothing more brought in",
                    when Bushes_Taken => "the bushes near are being picked by others",
                    when Trees_No_Way => "can't get to the trees left in reach",
                    when Trees_Taken => "the trees left in reach are being felled by others",
                    when Trees_Spared => "only apple trees stand in reach, and they are spared",
                    when Trees_Further => "looking further off for a tree to fell",
                    when Enough_Meat => (if not Chain_On then "enough meat (the reserve is met)"
                                         elsif Food_Asking then "enough meat in store (and no cook to make food of it)"
                                         else "enough food and meat in store"),
                    when Deer_Spared => "the deer are spared",
                    when No_Camp => "no camp to cook at",
                    when Camp_Unbuilt => "the camp is not built yet",
                    when Pot_Full => "tending the fire (the pot is full)",
                    when Nothing_To_Cook => "nothing to cook",
                    when Winter_Bare => "nothing to gather in winter",
                    when Enough_Food => "enough food in store",
                    when No_Timber => "no wood to build " & Its_House & " with",
                    when No_Thatch => "no straw to build " & Its_House & " with",
                    when No_Stone => "no stone to wall the ground of " & Its_House & " with",
                    when Nothing_Yet => "looking for work");
      when To_Eat    => return (if M.From_Pot then "going for stew" else "going to eat");
      when Eating    => return (if M.From_Pot then "eating stew" else "eating");
      when To_Bed    => return "going to sleep";
      when Sleeping  => return "asleep";
   end case;
   end Doing_Now;
   --  a cook with nothing to cook gathers
   function Now_Said return String is
     (if M.Job = Cook and then M.Use_For = For_Store
        and then M.State in To_Bush | Picking | To_Source | Gathering | To_Store | Storing
      then "nothing to cook: " & Doing_Now else Doing_Now);
begin
   if M.Is_Dead then
      return "dead, of hunger";
   elsif M.Fends then
      return "fending for itself: " & Doing_Now;
   end if;
   if Needs_On and then M.State not in To_Eat | Eating | To_Bed | Sleeping | To_Seat then
      if M.Fed <= 0.0 then
         return "starving: " & Now_Said;
      elsif M.Fed < Hungry_At then
         return "hungry: " & Now_Said;
      end if;
   end if;
   return Now_Said;
end Status;
