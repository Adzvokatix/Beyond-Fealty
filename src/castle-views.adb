with Castle.Actions;
with Castle.Bodies;
with Castle.Colony; use Castle.Colony;
with Castle.Deer;
with Castle.Herds;
with Castle.Text;   use Castle.Text;
with Castle.Buildings;  use type Castle.Buildings.Building_Kind;

package body Castle.Views is

   function Percent (F : Float) return String is (Img (Integer (100.0 * F)) & " %");

   procedure Add (S : in out Sheet; Name, Value : String; Shade : Tone := Plain; Bar : Float := -1.0;
                  Known : Boolean := True) is
   begin
      if S.N < Max_Rows then
         S.N := S.N + 1;
         S.Rows (S.N) := (Name => To_Line (Name), Value => To_Line (Value), Shade => Shade, Bar => Bar,
                          Known => Known);
      else
         S.Lost := S.Lost + 1;
      end if;
   end Add;

   function Learns_Text (Aptitude : Float) return String is ("learns x" & Img (Aptitude, 1));

   --  The skills of a person's sheet (see the spec).
   procedure Add_Skills (S : in out Sheet; V : Person_View) is
      Own   : constant Boolean := Has_Skill (V.Job);
      Shown : array (Skill_Kind) of Boolean := [others => False];

      --  "gathering 31 %, hunting 18 %": the best of the rest, best first
      function The_Rest (Left : Natural) return String is
         Best : Float := Skill_Shown;
         Pick : Skill_Kind := Skill_Kind'First;
         Any  : Boolean := False;
      begin
         if Left = 0 then
            return "";
         end if;
         for K in Skill_Kind loop
            if not Shown (K) and then V.Level (K) >= Best then
               Best := V.Level (K);
               Pick := K;
               Any := True;
            end if;
         end loop;
         if not Any then
            return "";
         end if;
         Shown (Pick) := True;
         declare
            This : constant String := Name (Pick) & " " & Percent (V.Level (Pick));
            Rest : constant String := The_Rest (Left - 1);
         begin
            return This & (if Rest = "" then "" else ", " & Rest);
         end;
      end The_Rest;

      function Apt_List (From : Skill_Kind) return String is
         Rest : constant String := (if From = Skill_Kind'Last then "" else Apt_List (Skill_Kind'Succ (From)));
      begin
         if V.Aptitude (From) >= Apt_From then
            return Name (From) & (if Rest = "" then "" else ", " & Rest);
         end if;
         return Rest;
      end Apt_List;
   begin
      if Own then
         declare
            K : constant Skill_Kind := Job_Skill (V.Job);
         begin
            Shown (K) := True;
            Add (S, Capital (Name (K)), Percent (V.Level (K)) & ", " & Learns_Text (V.Aptitude (K)),
                 Bar => V.Level (K),
                 Shade => (if V.Aptitude (K) >= Apt_From then Good elsif V.Aptitude (K) < Slow_Below then Dim
                           else Plain));
         end;
      end if;
      declare
         Rest : constant String := The_Rest (Other_Skills);
         Apt  : constant String := Apt_List (Skill_Kind'First);
      begin
         if Rest /= "" then
            Add (S, (if Own then "Other skills" else "Skills"), Rest);
         end if;
         Add (S, "Apt at", (if Apt = "" then "nothing in particular" else Apt),
              Shade => (if Apt = "" then Dim else Plain));
      end;
   end Add_Skills;

   --  "30 berries", "a log", "3 logs", "a deer".
   function Load_Text (K : Item_Kind; N : Natural) return String is
     (case K is
         when Nothing => "nothing",
         when Wood    => (if N = 1 then "a log" else Img (N) & " logs"),
         when Carcass => "a deer",
         when Sticks  => "an armful of sticks",
         when Hide    => (if N = 1 then "a hide" else Img (N) & " hides"),
         when Ladder  => (if N = 1 then "a ladder" else Img (N) & " ladders"),
         when others  => Img (N) & " " & Name (K));

   --  "30 berries, a log": the kinds there is any of.
   function List (P : Per_Kind) return String is
      function From (K : Item_Kind) return String is
        ((if P (K) > 0 then Load_Text (K, P (K)) else "")
         & (if K = Item_Kind'Last then ""
            else (declare
                     Rest : constant String := From (Item_Kind'Succ (K));
                  begin
                     (if P (K) > 0 and then Rest /= "" then ", " else "") & Rest)));
   begin
      return From (Item_Kind'First);
   end List;

   function Any (P : Per_Kind) return Boolean is (for some K in Item_Kind => P (K) > 0);

   --  "Agnes's hovel"; "its own hovel" to its owner (For_Whom); "a hovel" that is nobody's.
   function House_Name (H : Positive; For_Whom : Natural := 0) return String is
      Owner : constant Natural := House_At (H).Owner;
   begin
      return (if House_At (H).Kind = Castle.Buildings.Storehouse then "the storehouse"
              elsif Owner = 0 then "a hovel" elsif Owner = For_Whom then "its own hovel"
              else Name_Of (Owner) & "'s hovel");
   end House_Name;

   ------------------------------------------------------------------ a person

   function Person (I : Positive) return Sheet is
      use type Castle.Bodies.Sex_Kind;
      V : constant Person_View := Castle.Colony.Person (I);
      G : constant Castle.Bodies.Genome := Genome_Of (I);
      S : Sheet;
   begin
      S.Title := To_Line (Name_Of (I));
      S.Note := To_Line
        ((if V.Child then (if G.Sex = Castle.Bodies.Male then "a boy" else "a girl")
          elsif G.Sex = Castle.Bodies.Male then "a man" else "a woman")
         & " of " & Img (Integer (G.Age)) & (if V.Elder then ", an elder" else ""));
      Add (S, "Job", Capital (Castle.Actions.Job_Name (V.Job)));
      Add (S, "Directed by",
           (if V.Director = The_Player then "you"
            elsif V.Director in 1 .. Members then Name_Of (V.Director)
            elsif V.Job = Unassigned then "no one" else "no one: its own choice"),
           Shade => (if V.Director = No_One then Dim else Plain));
      Add (S, "Doing", Status (I), Shade => (if V.Dead or else V.Starving or else V.Fending then Bad else Plain));
      Add (S, "Carrying",
           (if V.Carried = 0 then "nothing" else Load_Text (V.Carrying, V.Carried))
           & (if V.Grain > 0 then ", " & Img (V.Grain) & " grain" else ""),
           Shade => (if V.Carried = 0 then Dim else Plain));
      if V.Zone in 1 .. Zone_Count then
         Add (S, "In", (case Zone_At (V.Zone).Kind is
                           when Camp_Zone => "the camp", when Stockpile_Zone => "a stockpile",
                           when Habitation_Zone => "the housing"));
      end if;
      if V.Trade = Builder and then V.Site in 1 .. House_Count then
         Add (S, "Trade", "Builder, at " & House_Name (V.Site, I));
      elsif V.Trade = As_Stockman then
         Add (S, "Trade", "Stockman, keeping the storehouse");
      elsif V.Trade = As_Carpenter then
         Add (S, "Trade", "Carpenter, making the storehouse's shelves and barrels");
      end if;
      if House_Count > 0 and then not V.Dead then
         Add (S, "Home", (if V.Housed then "a hovel of its own, drawn by lot" else "none yet: it sleeps by the fire"),
              Shade => (if V.Housed then Plain else Dim));
      end if;
      if Beds and then not V.Dead and then (V.Housed or else Has_Camp) then
         Add (S, "Bed", (if V.Has_Bed then (if V.Housed then "of straw, in its hovel" else "of straw, by the fire")
                         elsif V.Housed then "none yet: it sleeps on its floor" else "none yet: it sleeps on the ground"),
              Shade => (if V.Has_Bed then Plain else Dim));
      end if;
      if V.Cold then
         Add (S, "Cold", "no fire burning near", Shade => Bad);
      end if;
      if Skills and then not V.Dead then
         Add_Skills (S, V);
      end if;
      if not V.Dead and then Needs then
         Add (S, "Fed", Percent (V.Fed), Bar => V.Fed, Known => False,
              Shade => (if V.Starving then Bad elsif V.Hungry then Dim else Good));
         Add (S, "Mood", Percent (V.Mood), Bar => V.Mood, Known => False,
              Shade => (if V.Mood < 0.4 then Bad else Good));
      end if;
      return S;
   end Person;

   function Job_Label (I : Positive) return String is
      V : constant Person_View := Castle.Colony.Person (I);
   begin
      return (case V.Trade is
                 when Builder      => "Builder",
                 when As_Stockman  => "Stockman",
                 when As_Carpenter => "Carpenter",
                 when No_Trade     =>
                   (if Is_Builder (I) then "Builder"          --  (set to building, with no house to build just now)
                    elsif V.Job = Unassigned then "No job" else Capital (Castle.Actions.Job_Name (V.Job))));
   end Job_Label;

   ------------------------------------------------------------------ a zone

   function Cart return Sheet is
      C : constant Cart_View := Castle.Colony.Cart;
      S : Sheet;
   begin
      S.Title := To_Line ("The lord's cart");
      S.Note := To_Line ("what the band was sent out with");
      if not C.Here then
         return S;
      end if;
      Add (S, "Salt", (if C.Salt = 0 then "none left" else Img (C.Salt) & " lb"),
           Shade => (if C.Salt = 0 then Bad else Plain));
      Add (S, "In the stores", (if Stored (Salt) = 0 then "none" else Img (Stored (Salt)) & " lb"),
           Shade => (if Stored (Salt) = 0 then Dim else Plain));
      Add (S, "Cures", Img (Integer'(Lb_Per_Salt)) & " lb of meat to the pound", Shade => Dim);
      if Cart_Pull then
         Add (S, "Stands", (if C.Towed then "pulled to a stockpile by " & Name_Of (C.By)
                            elsif Cart_In_Stockpile then "in a stockpile"
                            else "where it was left; to be pulled into a stockpile"),
              Shade => (if C.Towed or else Cart_In_Stockpile then Plain else Dim));
      end if;
      if Deer_Salted + Deer_Unsalted > 0 then
         Add (S, "Deer salted", Img (Deer_Salted) & " of " & Img (Deer_Salted + Deer_Unsalted));
      end if;
      if Meat_Lost > 0 then
         Add (S, "Meat lost unsalted", Img (Meat_Lost) & " lb", Shade => Bad);
      end if;
      return S;
   end Cart;

   function Zone (Z : Positive) return Sheet is
      V : constant Zone_View := Zone_At (Z);
      S : Sheet;
      Size : constant String :=
        "zone " & Img (Z) & ": " & Img (V.Along, 0) & " x " & Img (V.Across, 0) & " m";
   begin
      case V.Kind is
         when Stockpile_Zone =>
            S.Title := To_Line ((if V.Yard then "Stockyard" else "Stockpile"));
            S.Note := To_Line (Size);
            Add (S, "Cells", Img (V.Cells) & ", " & Img (V.In_Use) & " in use");
            if V.Overflow > 0 then
               Add (S, "Overflow", Img (V.Overflow) & ", " & Img (V.Over_In_Use) & " in use");
            end if;
            if not V.Yard and then Stores_Moved then
               Add (S, "Closed", "the stores are in the stockyard: what lies here is carried over", Shade => Dim);
            end if;
            if V.Yard and then Storehouse = 0 then
               Add (S, "Storehouse", "not begun: asked for on the second morning", Shade => Dim);
            end if;
            if Storehouse > 0 and then House_At (Storehouse).Zone = Z then
               declare
                  Hv : constant House_View := House_At (Storehouse);
               begin
                  Add (S, "Storehouse",
                       (if Hv.Phase = Standing then "standing"
                        else "being built, " & Percent (Float (Hv.Placed) / Float (Integer'Max (1, Hv.Blocks)))));
               end;
            end if;
            --  what it holds: the stores' staples always, none or not (John, 2026-11-17: "Add stone,
            --  berries, apples, and salt to the list of resources in the stockpile/storeyard tooltip":
            --  a kind was listed only while some of it lay there); anything else while it holds some
            for K in Item_Kind loop
               if V.Holds (K) > 0 then
                  Add (S, Capital (Name (K)), Img (V.Holds (K)));
               elsif K in Berries | Wood | Stone | Straw | Meat | Hide | Vegetables | Apples | Salt then
                  Add (S, Capital (Name (K)), "none", Shade => Dim);
               end if;
            end loop;
            if Demand_Chain then               --  demand lands on the stores: what they are short of
               Add (S, "The stores ask for", Asked_List, Shade => (if Asked_List = "nothing" then Dim else Plain));
            end if;
         when Camp_Zone =>
            declare
               C : constant Camp_View := Camp_State;
            begin
               S.Title := To_Line ("The camp");
               S.Note := To_Line (Size);
               if not C.Built then                --  marked, and being built by the band
                  Add (S, "Hearth", "to be built", Shade => Dim);
                  Add (S, "Ground", (if C.Ground_Left = 0 then "ready"
                                     else Img (C.Ground_Left) & " square metres to make ready"),
                       Shade => (if C.Ground_Left = 0 then Plain else Dim));
                  if C.To_Dig + C.To_Fill > 0 then   --  its floor, to be made level
                     Add (S, "Floor",
                          (if C.To_Dig > 0 then Img (C.To_Dig) & " blocks of earth to dig off" else "")
                          & (if C.To_Dig > 0 and then C.To_Fill > 0 then ", " else "")
                          & (if C.To_Fill > 0 then Img (C.To_Fill) & " to fill" else ""),
                          Shade => Dim);
                  elsif C.Floor_Z >= 0.0 then
                     Add (S, "Floor", "level");
                  end if;
                  Add (S, "Stone", Img (C.Stones) & " of " & Img (Integer'(Hearth_Stones)));
                  Add (S, "Wood", Img (C.Frame) & " of " & Img (Integer'(Hearth_Wood)));
               else
                  Add (S, "Fire", (if C.Burning then "burning, " & Img (C.Fuel_H, 1) & " h of wood on it"
                                   elsif C.Dying then "dying down, " & Img (C.Ember_H, 1) & " h left to restoke it"
                                   else "out"),
                       Shade => (if C.Burning then Plain else Dim));
                  Add (S, "Firewood", (if C.Logs = 0 then "none stacked" else Load_Text (Wood, C.Logs) & " stacked"),
                       Shade => (if C.Logs = 0 then Dim else Plain));
                  Add (S, "Pot",
                       (if C.Stew = 0 and then C.In_Pot = 0 then "empty" else Img (C.Stew) & " of stew")
                       & (if C.Stirring then ", cooking" elsif C.In_Pot > 0 then ", " & Img (C.In_Pot) & " in, not cooked"
                          else ""),
                       Shade => (if C.Stew = 0 then Dim else Plain));
                  --  what the cook keeps in the stores for the next pot (nobody eats it raw)
                  if Cook_Holds then
                     declare
                        function Kept (At_K : Positive) return String is
                           Rest : constant String := (if At_K = Greens_Order'Last then "" else Kept (At_K + 1));
                           K    : constant Item_Kind := Greens_Order (At_K);
                        begin
                           if Cook_Held (K) = 0 then
                              return Rest;
                           end if;
                           return Img (Cook_Held (K)) & " " & Name (K) & (if Rest = "" then "" else ", " & Rest);
                        end Kept;
                     begin
                        if Kept (Greens_Order'First) /= "" then
                           Add (S, "Kept for the pot", Kept (Greens_Order'First));
                        end if;
                     end;
                  end if;
               end if;
               Add (S, "Seats", Img (C.Seats) & " of " & Img (Integer'(Seat_Logs)) & " laid");
               if Camp_Is_Square and then Walls_Left > 0 then     --  (the walls and stairs of its banks)
                  Add (S, "Walls", Img (Walls_Left) & " blocks of stone still to lay", Shade => Dim);
               end if;
               if not C.Built then                --  what its hearth still waits for
                  declare
                     function Short (K : Item_Kind) return String is
                        Rest : constant String := (if K = Item_Kind'Last then "" else Short (Item_Kind'Succ (K)));
                        Need : constant Integer := Build_Takes (Camp_Zone) (K) - V.Got (K);
                     begin
                        if Need <= 0 then
                           return Rest;
                        end if;
                        return Img (Need) & " " & Name (K) & (if Rest = "" then "" else ", " & Rest);
                     end Short;
                  begin
                     if Short (Item_Kind'First) /= "" then
                        Add (S, "Short of", Short (Item_Kind'First), Shade => Bad);
                     end if;
                     if C.Looking >= Float (Far_Reach_Max_M) then
                        Add (S, "Looked for it", "as far as " & Img (C.Looking, 0) & " m: no further is known",
                             Shade => Bad);
                     elsif C.Looking > 0.0 then
                        Add (S, "Looking for it", "as far as " & Img (C.Looking, 0) & " m from the stake");
                     end if;
                  end;
               end if;
               declare                         --  what the camp asks of the stores
                  function Asks (N : Positive) return String is
                  begin
                     if N > Demand_Rows then
                        return "";
                     end if;
                     declare
                        R    : constant Demand_Row := Demand_Row_At (N);
                        Rest : constant String := Asks (N + 1);
                     begin
                        if R.Who /= A_Zone or else R.Zone /= Z then
                           return Rest;
                        end if;
                        return Img (R.Amount) & " " & Name (R.What)
                          & (if R.Kind = By_The_Day then " a day" else " once") & (if Rest = "" then "" else ", " & Rest);
                     end;
                  end Asks;
               begin
                  if Asks (1) /= "" then
                     Add (S, "Asks for", Asks (1));
                  end if;
               end;
               if C.Set_Aside > 0 then
                  Add (S, "Promised", Img (C.Set_Aside) & " of the stew", Known => False);
               end if;
            end;
         when Habitation_Zone =>
            declare
               Foresters : Natural := 0;
            begin
               S.Title := To_Line ("Housing");
               S.Note := To_Line (Size);
               for I in 1 .. Members loop
                  if not Dead (I) and then Job_Of (I) = Forester then
                     Foresters := Foresters + 1;
                  end if;
               end loop;
               Add (S, "Hovels",
                    (if V.Homes = 0 then "none begun"
                     else Img (V.Homes_Built) & " standing"
                          & (if V.Homes > V.Homes_Built then ", " & Img (V.Homes - V.Homes_Built) & " being built"
                             else "")),
                    Shade => (if V.Homes = 0 then Dim else Plain));
               Add (S, "Without a home", (if Homeless = 0 then "nobody" else Img (Homeless) & " of the band"),
                    Shade => (if Homeless = 0 then Good else Plain));
               Add (S, "Room for",
                    (if V.Lots = 0 then "no more hovels" elsif V.Lots = 1 then "1 more hovel"
                     else Img (V.Lots) & " more hovels"),
                    Shade => (if V.Lots = 0 then Dim else Plain));
               for H in 1 .. House_Count loop        --  those being built, each on a line
                  declare
                     Hv : constant House_View := House_At (H);
                  begin
                     if Hv.Zone = Z and then Hv.Phase /= Standing then
                        Add (S, Capital (House_Name (H)),
                             (if Hv.Marked then "being taken down: "
                              else "") &
                             (case Hv.Phase is
                                 when Ground => "the ground", when Flooring => "the floor",
                                 when Framing => "the frame",
                                 when Walling => "the walls", when Roofing => "the roof",
                                 when Trimming | Standing => "the roof's trimming", when Yard => "the yard")
                             & (if Hv.Blocks > 0 then ", " & Percent (Float (Hv.Placed) / Float (Hv.Blocks)) else "")
                             & (case Hv.Waits is
                                   when Not_Waiting => "", when For_A_Builder => "; no builder",
                                   when For_Wood => "; waits for wood", when For_Straw => "; waits for straw",
                                   when For_Stone => "; waits for stone",
                                   when For_A_Way => "; no way to it"),
                             Shade => (if Hv.Waits = Not_Waiting then Plain else Bad));
                     end if;
                  end;
               end loop;
               if Any (V.Short) then
                  Add (S, "Still takes", List (V.Short));
               end if;
               if V.Homes > V.Homes_Built and then Foresters = 0 then
                  Add (S, "Builders", "none: builders come from the foresters", Shade => Bad);
               end if;
               if V.No_Room then
                  Add (S, "No room", "for another hovel: mark more housing along a path", Shade => Bad);
               end if;
            end;
      end case;
      if Any (V.Coming) then
         Add (S, "Coming", List (V.Coming), Known => False);
      end if;
      if Any (V.Going) then
         Add (S, "Going", List (V.Going), Known => False);
      end if;
      if V.People > 0 then
         Add (S, "People here", Img (V.People));
      end if;
      return S;
   end Zone;

   ------------------------------------------------------------------ a house

   function House (H : Positive) return Sheet is
      V : constant House_View := House_At (H);
      S : Sheet;
   begin
      S.Title := To_Line (Capital (House_Name (H)));
      if V.Kind = Castle.Buildings.Storehouse then
         S.Note := To_Line ((if V.Phase = Standing then "of timber, daub and thatch, its floor of plank, its yard fenced"
                             else "being built: the storehouse of the stockyard"));
      else
         S.Note := To_Line ((if V.Marked then "a hovel, being taken down"
                             elsif V.Phase = Standing then "a hovel of timber, daub and thatch" else "a hovel, being built"));
         Add (S, (if V.Phase = Standing then "Lives here" else "For"),
              (if V.Marked then "nobody: it is to be razed"
               elsif V.Owner in 1 .. Members then Name_Of (V.Owner)
               elsif V.Phase = Standing then "nobody" else "whoever draws it when it stands"),
              Shade => (if V.Owner = 0 then Dim else Plain));
         if V.Marked then
            Add (S, "Marked", "for razing", Shade => Dim);     --  (nobody's: it is being taken down)
         end if;
      end if;
      if V.Phase /= Standing then
         Add (S, (if V.Marked then "Taken down to" else "Work"),
              (case V.Phase is
                  when Ground => "the ground", when Flooring => "the floor", when Framing => "the frame",
                  when Walling => "the walls", when Roofing => "the roof",
                                 when Trimming | Standing => "the roof's trimming",
                                 when Yard => "the yard: its ground beaten, its fence and gateways, its coverings"),
              Bar => (if V.Blocks > 0 then Float (V.Placed) / Float (V.Blocks) else 0.0));
         Add (S, "Builder",
              (if V.Builder in 1 .. Members then Name_Of (V.Builder) else "none: builders come from the foresters"),
              Shade => (if V.Builder = 0 then Bad else Plain));
         if V.Takes (Stone) > 0 then
            Add (S, "Stone", Img (V.Got (Stone)) & " of " & Img (V.Takes (Stone)) & " stones");
         end if;
         Add (S, "Wood", Img (V.Got (Wood)) & " of " & Img (V.Takes (Wood)) & " logs");
         Add (S, "Straw", Img (V.Got (Straw)) & " of " & Img (V.Takes (Straw)) & " sheaves");
         if V.Waits /= Not_Waiting then
            Add (S, "Waits for",
                 (case V.Waits is
                     when For_A_Builder => "a builder", when For_Wood => "wood in the stores",
                     when For_Straw => "straw in the stores", when For_A_Way => "a way to it",
                     when For_Stone => "stone in the stores",
                     when Not_Waiting => ""),
                 Shade => Bad);
         end if;
      end if;
      if Ladder_At (H).Standing then          --  (a ladder against an eave: its roof being thatched, or left there)
         Add (S, "Ladder",
              (if V.Phase = Standing then "left against its " else "against its ")
              & (case Ladder_At (H).Side is when 1 => "front", when 2 => "back", when 3 => "left", when others => "right")
              & " eave",
              Shade => (if V.Phase = Standing then Dim else Plain));
      end if;
      return S;
   end House;

   ------------------------------------------------------------------ the demand table

   --  "the camp 4 a day, 4 once; you 20": who asks for a good, from its rows.
   function Askers (Food : Boolean; K : Item_Kind) return String is
      A_Day : constant Natural := Food_A_Day;
      function Amount (R : Demand_Row) return String is
        (if not R.Food then Img (R.Amount)
         else Img ((if A_Day > 0 then Float (R.Amount) / Float (A_Day) else 0.0), 1) & " days");
      function Who (R : Demand_Row) return String is
        (case R.Who is
            when The_People => "the band",
            when A_Zone     => (if R.Zone > 0 and then Zone_At (R.Zone).Kind = Camp_Zone then "the camp"
                                else "zone " & Img (R.Zone)),
            when The_Paths  => "the paths",
            when An_Order   => "you");
      function From (N : Positive; Last_Who : String) return String is
      begin
         if N > Demand_Rows then
            return "";
         end if;
         declare
            R : constant Demand_Row := Demand_Row_At (N);
         begin
            if R.Food /= Food or else (not Food and then R.What /= K) then
               return From (N + 1, Last_Who);
            end if;
            declare
               W    : constant String := Who (R);
               Part : constant String :=
                 (case R.Kind is
                     when By_The_Day => (if R.Food then "by the day" else Amount (R) & " a day"),
                     when Once       => Amount (R) & " once",
                     when Surplus    => Amount (R));
            begin
               return (if Last_Who = "" then W & " " elsif W = Last_Who then ", " else "; " & W & " ")
                 & Part & From (N + 1, W);
            end;
         end;
      end From;
   begin
      return From (1, "");
   end Askers;

   function Asked_List return String is
      function From (K : Item_Kind) return String is
         Rest : constant String := (if K = Item_Kind'Last then "" else From (Item_Kind'Succ (K)));
      begin
         if Demand_For (K).High > 0 and then Demand_For (K).Asked then
            return Name (K) & (if Rest = "" then "" else ", " & Rest);
         end if;
         return Rest;
      end From;
      Kinds : constant String := From (Item_Kind'First);
      Food  : constant Boolean := Food_Demand.High > 0 and then Food_Demand.Asked;
   begin
      return (if Food then "food" & (if Kinds = "" then "" else ", " & Kinds)
              elsif Kinds = "" then "nothing" else Kinds);
   end Asked_List;

   function Demand return Sheet is
      S : Sheet;
      F : constant Good_View := Food_Demand;
      function State (G : Good_View) return String is
        (if not G.Asked then "" elsif G.Makers = 0 then ", asked of nobody" else ", asked");
      function Shade_Of (G : Good_View) return Tone is
        (if not G.Asked then Plain elsif G.Makers = 0 then Bad else Good);
      function Days (Points : Natural) return String is
        (Img ((if F.A_Day > 0 then Float (Points) / Float (F.A_Day) else 0.0), 1));
   begin
      S.Title := To_Line ("The stores");
      S.Note := To_Line ((if Demand_Chain then "what they have of what is asked" else "the demand chain is off"));
      if F.High > 0 then
         Add (S, "Food", Days (F.Have) & " of " & Days (F.High) & " days" & State (F), Shade => Shade_Of (F));
         Add (S, "  asked by", Askers (True, Nothing), Shade => Dim);
      end if;
      for K in Item_Kind loop
         declare
            G : constant Good_View := Demand_For (K);
         begin
            if G.High > 0 then
               Add (S, Capital (Name (K)), Img (G.Have) & " of " & Img (G.High) & State (G), Shade => Shade_Of (G));
               Add (S, "  asked by", Askers (False, K), Shade => Dim);
            elsif Stored (K) > 0 then
               Add (S, Capital (Name (K)), Img (Stored (K)) & ", not asked for", Shade => Dim);
            end if;
         end;
      end loop;
      if S.N = 0 then
         Add (S, "Asked for", "nothing", Shade => Dim);
      end if;
      return S;
   end Demand;

   ------------------------------------------------------------------ a deer

   function Deer (K : Positive) return Sheet is
      use Castle.Herds;
      S : Sheet;
      H : constant Natural := Herd_Of (K);
   begin
      S.Title := To_Line (case Class_Of (K) is
                             when Castle.Deer.Fawn => "Fawn", when Castle.Deer.Doe => "Doe",
                             when Castle.Deer.Young_Stag => "Young stag", when Castle.Deer.Stag => "Stag");
      S.Note := To_Line ("a deer");
      if H in 1 .. Herd_Count then
         Add (S, "Herd", Img (In_Herd (H)) & " deer");
         if Has_Stake and then In_Herd (H) <= Spare_Last then   --  (why the hunters let it be)
            Add (S, "Hunted", "not: its herd is down to" & Natural'Image (In_Herd (H)) & ", left to breed",
                 Shade => Dim);
         end if;
      end if;
      Add (S, "Mood", (if In_Panic (K) then "alarmed" else "calm"), Shade => (if In_Panic (K) then Bad else Plain));
      Add (S, "Doing",
           (if In_Panic (K) then "bolting"
            else (case Castle.Herds.Doing (K) is
                     when Castle.Deer.Graze => "grazing", when Castle.Deer.Alert => "watching",
                     when Castle.Deer.Idle => "standing")));
      return S;
   end Deer;

   ------------------------------------------------------------------ what a sheet holds

   function Known_Only (S : Sheet) return Sheet is
      R : Sheet := (Title => S.Title, Note => S.Note, Lost => S.Lost, others => <>);
   begin
      for K in 1 .. S.N loop
         if S.Rows (K).Known then
            R.N := R.N + 1;
            R.Rows (R.N) := S.Rows (K);
         end if;
      end loop;
      return R;
   end Known_Only;

   function Row_Named (S : Sheet; Name : String) return Natural is
   begin
      for K in 1 .. S.N loop
         if Str (S.Rows (K).Name) = Name then
            return K;
         end if;
      end loop;
      return 0;
   end Row_Named;

   function Value_Of (S : Sheet; Name : String) return String is
      K : constant Natural := Row_Named (S, Name);
   begin
      return (if K = 0 then "" else Str (S.Rows (K).Value));
   end Value_Of;

end Castle.Views;
