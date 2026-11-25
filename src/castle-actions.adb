with Castle.Text; use Castle.Text;

package body Castle.Actions is

   Band_N    : Positive := Castle.Colony.Arrivals;
   Band_Seed : Castle.Hash.U64 := 1;

   procedure Set_Arrivals (Band : Positive; Seed : Castle.Hash.U64) is
   begin
      Band_N := Band;
      Band_Seed := Seed;
   end Set_Arrivals;

   function Rank_Of (Who : Actor) return Rank is
     (if Who = The_Player then Leader elsif Who = No_One then Nobody else Serf);

   function Row_Of (A : Action) return Row is
     (case A is
         when Raise_Stake      => (To_Line ("raise the homestake"), The_Ground, Leader),
         when Lay_Path         => (To_Line ("lay a path"), The_Ground, Leader),
         when Zone_Stockpile   => (To_Line ("zone a stockpile"), The_Ground, Leader),
         when Zone_Camp        => (To_Line ("zone the camp"), The_Ground, Leader),
         when Give_Job         => (To_Line ("give a job"), A_Person, Leader),
         when Follow           => (To_Line ("follow"), A_Person, Leader),
         when Set_Reserve      => (To_Line ("set a reserve"), A_Stockpile, Leader),
         when Set_Winter_Store => (To_Line ("set the winter store"), A_Stockpile, Leader),
         when Spare_Apples     => (To_Line ("spare the apple trees"), The_Colony, Leader),
         when Spare_Deer       => (To_Line ("spare the deer"), The_Colony, Leader),
         when Zone_Housing     => (To_Line ("zone housing"), The_Ground, Leader),
         when Fill_Housing     => (To_Line ("zone housing inside paths"), The_Ground, Leader),
         when Place_Stockpile  => (To_Line ("place the stockpile"), The_Ground, Leader),
         when Zone_Stockyard   => (To_Line ("zone the stockyard"), The_Ground, Leader),
         when Unzone_Housing   => (To_Line ("take housing out"), The_Ground, Leader),
         when Mark_Hovel       => (To_Line ("mark a hovel for razing"), The_Ground, Leader),
         when Make_Builder     => (To_Line ("set to building"), A_Person, Leader),
         when Pull_Housing     => (To_Line ("zone housing with its path"), The_Ground, Leader),
         when Place_Stockyard  => (To_Line ("place the stockyard"), The_Ground, Leader),
         when Make_Stockman    => (To_Line ("name the stockman"), A_Person, Leader),
         when Make_Carpenter   => (To_Line ("name the carpenter"), A_Person, Leader),
         when Remove_Stockpile => (To_Line ("remove a stockpile"), A_Stockpile, Leader));

   function Name (A : Action) return String is (Str (Row_Of (A).Name));

   function May (Who : Actor; A : Action) return Boolean is (Rank_Of (Who) >= Row_Of (A).Least);

   function Job_Name (J : Job_Kind) return String is
     (case J is
         when Unassigned => "no job", when Gatherer => "gatherer", when Forester => "forester",
         when Hunter => "hunter", when Porter => "porter", when Cook => "cook");

   --  The kinds a reserve can be set of.
   --  (apples since 2026-11-18: John, "Add apple gathering to the list of foods")
   function Has_Reserve (K : Item_Kind) return Boolean is (K in Wood | Straw | Meat | Vegetables | Apples);

   ------------------------------------------------------------------ orders

   function Path_Begin (P : Vec3) return Vec3 is (if Path_Snap then Path_Line_Start (P) else P);
   function Path_Reach (From, P : Vec3) return Vec3 is (if Path_Snap then Path_Line_End (From, P) else P);

   procedure Perform (O : Order; R : out Result) is
   begin
      R := (others => <>);
      if not May (O.By, O.What) then
         R.Why := Not_Permitted;
         return;
      end if;
      case O.What is
         when Raise_Stake =>
            if Has_Stake then
               R.Why := Not_Now;
               return;
            end if;
            if O.As_Square then
               Place_Square (O.Stake_At, O.Stake_Way, Band_N, Band_Seed);
            else
               Place_Stake (O.Stake_At, Band_N, Band_Seed);
            end if;
            R.Done := Has_Stake;
         when Lay_Path =>
            if not Has_Stake then
               R.Why := Not_Now;
               return;
            end if;
            Lay_Path_Through (Path_Begin (O.From), Path_Reach (Path_Begin (O.From), O.To), R.Count);
            R.Done := R.Count > 0;
         when Zone_Stockpile =>
            if not Has_Stake then
               R.Why := Not_Now;
               return;
            end if;
            Zone_Stockpile (O.X0, O.Y0, O.X1, O.Y1, R.Count);
            R.Done := R.Count > 0;
         when Zone_Camp =>
            Zone_Camp (O.Fire_At, R.Done);       --  with no stake, or a camp already, it says so itself
         when Place_Stockpile =>
            if not Has_Stake then
               R.Why := Not_Now;
               return;
            end if;
            if Box_Place then
               Place_Box (Stockpile_Box, O.Pile_At, O.Pile_Way, R.Count);
            else
               Place_Stockpile (O.Pile_At.X, O.Pile_At.Y, R.Count);
            end if;
            R.Done := R.Count > 0;
         when Zone_Stockyard =>
            if not Has_Stake then
               R.Why := Not_Now;
               return;
            end if;
            Zone_Stockyard (O.X0, O.Y0, O.X1, O.Y1, R.Count);
            R.Done := R.Count > 0;
         when Place_Stockyard =>
            if not Has_Stake then
               R.Why := Not_Now;
               return;
            end if;
            Place_Box (Stockyard_Box, O.Pile_At, O.Pile_Way, R.Count);
            R.Done := R.Count > 0;
         when Give_Job =>
            if O.Whom not in 1 .. Members or else Dead (O.Whom) then
               R.Why := No_Such_Target;
               return;
            end if;
            Set_Job (O.Whom, O.Job, By => O.By);
            R.Done := True;
         when Make_Builder =>
            if O.Whom not in 1 .. Members or else Dead (O.Whom) then
               R.Why := No_Such_Target;
               return;
            end if;
            Set_Job (O.Whom, Forester, By => O.By);
            Set_Builder (O.Whom, True);
            R.Done := True;
         when Make_Stockman =>
            if O.Whom not in 1 .. Members or else Dead (O.Whom) then
               R.Why := No_Such_Target;
               return;
            end if;
            Name_Stockman (O.Whom, By => O.By);
            R.Done := True;
         when Make_Carpenter =>
            if O.Whom not in 1 .. Members or else Dead (O.Whom) then
               R.Why := No_Such_Target;
               return;
            end if;
            Name_Carpenter (O.Whom, By => O.By);
            R.Done := True;
         when Follow =>
            if O.Whom > Members then
               R.Why := No_Such_Target;
               return;
            end if;
            R.Done := True;                      --  the interface's to carry out
         when Set_Reserve =>
            if not Has_Reserve (O.Kind) then
               R.Why := No_Such_Target;
               return;
            end if;
            if O.Kind = Wood then
               Set_Wood_Reserve (O.Amount);
            else
               Set_Reserve (O.Kind, O.Amount);
            end if;
            R.Done := True;
         when Set_Winter_Store =>
            Set_Winter_Store (O.Days);
            R.Done := True;
         when Spare_Apples =>
            Set_Protect_Apples (O.On);
            R.Done := True;
         when Spare_Deer =>
            Set_Spare_Deer (O.On);
            R.Done := True;
         when Zone_Housing =>
            if not Has_Stake then
               R.Why := Not_Now;
               return;
            end if;
            Zone_Housing (O.X0, O.Y0, O.X1, O.Y1, R.Count);
            R.Done := Housing_Refusal = "";      --  (room for no hovel yet is not a refusal: it can be pulled further)
         when Fill_Housing =>
            if not Has_Stake then
               R.Why := Not_Now;
               return;
            end if;
            Zone_Housing_Inside (O.Inside.X, O.Inside.Y, R.Count);
            R.Done := Housing_Refusal = "";
         when Pull_Housing =>
            if not Has_Stake then
               R.Why := Not_Now;
               return;
            end if;
            Pull_Housing (Pull_Line (O.Begun, O.Pulled_To), O.Rows, R.Count);
            R.Done := Pull_Refusal = "";         --  (room for no hovel yet is not a refusal, as for housing zoned)
         when Unzone_Housing =>
            declare
               Marked : Natural;
            begin
               Unzone_Housing (O.X0, O.Y0, O.X1, O.Y1, R.Count, Marked);
               R.Done := R.Count > 0 or else Marked > 0 or else Unzone_Lived_In > 0;
               R.Marked := Marked;
            end;
         when Remove_Stockpile =>
            if O.Pile not in 1 .. Zone_Count then
               R.Why := No_Such_Target;
               return;
            end if;
            Castle.Colony.Remove_Stockpile (O.Pile, O.Remove);
            R.Done := Removal_Refusal = "";
            if not R.Done then
               R.Why := The_Ground_Refused;
               return;
            end if;
         when Mark_Hovel =>
            if O.Hovel not in 1 .. House_Count then
               R.Why := No_Such_Target;
               return;
            end if;
            Mark_Hovel (O.Hovel, O.Marked);                   --  (a storehouse is never marked)
            R.Done := House_At (O.Hovel).Marked = O.Marked;
            if not R.Done then
               R.Why := No_Such_Target;
               return;
            end if;
      end case;
      if not R.Done then
         R.Why := The_Ground_Refused;
      end if;
   end Perform;

   function Why_Not (O : Order; R : Result) return String is
     (case R.Why is
         when None => "",
         when Not_Permitted => "not permitted to " & Name (O.What),
         when No_Such_Target =>
           (case O.What is
               when Give_Job | Follow | Make_Builder | Make_Stockman | Make_Carpenter =>
                 "there is nobody there to " & Name (O.What),
               when Set_Reserve       => "no reserve is kept of " & Castle.Colony.Name (O.Kind),
               when others            => "there is nothing there to do it to"),
         when Not_Now =>
           (if O.What = Raise_Stake then "the homestake is raised already" else "raise the homestake first"),
         when The_Ground_Refused =>
           (case O.What is
               when Raise_Stake    => (if O.As_Square then Square_Refusal else "there is no ground to raise it on"),
               when Lay_Path       => Path_Refusal,
               when Zone_Stockpile => Stockpile_Refusal,
               when Place_Stockpile => (if Box_Place then Box_Refusal else Stockpile_Refusal),
               when Zone_Stockyard => Stockyard_Refusal,
               when Place_Stockyard => Box_Refusal,
               when Zone_Camp      => Camp_Refusal,
               when Zone_Housing | Fill_Housing => Housing_Refusal,
               when Pull_Housing   => Pull_Refusal,
               when Unzone_Housing => "there is no housing in it",
               when Remove_Stockpile => Removal_Refusal,
               when others         => "it could not be done"));

   ------------------------------------------------------------------ what one may do to a thing

   function Menu_For (Who : Actor; T : Target) return Menu is
      M : Menu;

      procedure Add (C : Choice) is
      begin
         if M.N < Max_Choices and then May (Who, C.Todo.What) then
            M.N := M.N + 1;
            M.Items (M.N) := C;
            M.Items (M.N).Todo.By := Who;
         end if;
      end Add;

      --  A step down and a step up of one number, as one line.
      procedure Add_Steps (Label : String; Down, Up : Order) is
      begin
         if M.N + 2 <= Max_Choices and then May (Who, Down.What) then
            Add ((Label => To_Line (Label), Todo => Down, Step => Fewer, others => <>));
            Add ((Label => To_Line (Label), Todo => Up, Step => More, others => <>));
         end if;
      end Add_Steps;

      function Less (N : Natural) return Natural is (if N <= Reserve_Step then 0 else N - Reserve_Step);
   begin
      case T.Kind is
         when The_Ground =>
            M.Title := To_Line ("The ground");
            if not Has_Stake then
               if Square_Stake then               --  (the square: held and turned by the interface)
                  Add ((Label => To_Line ((if Castle.Colony.Square_Wide
                                           then "The homestake: a square of 11 m, its path round it"
                                           else "The homestake: a square of 10 m, its path round it")),
                        Todo => (What => Raise_Stake, By => Who, Stake_At => T.Point, As_Square => True,
                                 Stake_Way => 0),
                        Two_Point => True, others => <>));
               else
                  Add ((Label => To_Line ("Raise the homestake here"),
                        Todo => (What => Raise_Stake, By => Who, Stake_At => T.Point, As_Square => False,
                                 Stake_Way => 0), others => <>));
               end if;
            else
               Add ((Label => To_Line ("Path from here"),
                     Todo => (What => Lay_Path, By => Who, From => T.Point, To => T.Point),
                     Two_Point => True, others => <>));
               if Box_Place then                     --  (put down whole, with its path: the interface holds it)
                  Add ((Label => To_Line ("Stockpile, 10 by 10 m, with its path"),
                        Todo => (What => Place_Stockpile, By => Who, Pile_At => T.Point, Pile_Way => 0),
                        Two_Point => True, others => <>));
               elsif not One_Stockpile then
                  Add ((Label => To_Line ("Stockpile from here"),
                        Todo => (What => Zone_Stockpile, By => Who, X0 => T.Point.X, Y0 => T.Point.Y,
                                 X1 => T.Point.X, Y1 => T.Point.Y),
                        Two_Point => True, others => <>));
               elsif Stockpile_Count = 0 then        --  (the stockpile is placed once)
                  Add ((Label => To_Line ("Stockpile here, 10 by 10 m"),
                        Todo => (What => Place_Stockpile, By => Who, Pile_At => T.Point, Pile_Way => 0), others => <>));
               end if;
               if Stockyard = 0 and then Yard_Box then   --  (put down whole, with its path: the interface holds it)
                  Add ((Label => To_Line ("Stockyard, 20 by 20 m, with its path"),
                        Todo => (What => Place_Stockyard, By => Who, Pile_At => T.Point, Pile_Way => 0),
                        Two_Point => True, others => <>));
               elsif Stockyard = 0 then              --  (the stockyard is zoned once)
                  Add ((Label => To_Line ("Stockyard from here"),
                        Todo => (What => Zone_Stockyard, By => Who, X0 => T.Point.X, Y0 => T.Point.Y,
                                 X1 => T.Point.X, Y1 => T.Point.Y),
                        Two_Point => True, others => <>));
               end if;
               if not Has_Camp then
                  Add ((Label => To_Line ("Camp here"),
                        Todo => (What => Zone_Camp, By => Who, Fire_At => T.Point), others => <>));
               end if;
               if Housing_Pull then                  --  (pulled with its path: the interface holds its beginning)
                  Add ((Label => To_Line ("Housing with its path, from here"),
                        Todo => (What => Pull_Housing, By => Who, Begun => T.Point, Pulled_To => T.Point,
                                 Rows => Side_Begun),
                        Two_Point => True, others => <>));
               else
                  Add ((Label => To_Line ("Housing from here"),
                        Todo => (What => Zone_Housing, By => Who, X0 => T.Point.X, Y0 => T.Point.Y,
                                 X1 => T.Point.X, Y1 => T.Point.Y),
                        Two_Point => True, others => <>));
               end if;
               if Path_Count > 0 then
                  Add ((Label => To_Line ("Housing inside these paths"),
                        Todo => (What => Fill_Housing, By => Who, Inside => T.Point), others => <>));
               end if;
               --  (on housing: ground out of it again, and a hovel's mark)
               if Zone_On (T.Point.X, T.Point.Y) > 0
                 and then Zone_At (Zone_On (T.Point.X, T.Point.Y)).Kind = Habitation_Zone
               then
                  Add ((Label => To_Line ("Take housing out from here"),
                        Todo => (What => Unzone_Housing, By => Who, X0 => T.Point.X, Y0 => T.Point.Y,
                                 X1 => T.Point.X, Y1 => T.Point.Y),
                        Two_Point => True, others => <>));
               end if;
               --  (only a hovel nobody owns: John, 2026-11-19, "limit razing buildings to unowned")
               if Hovel_At (T.Point.X, T.Point.Y) > 0
                 and then (House_At (Hovel_At (T.Point.X, T.Point.Y)).Marked
                           or else House_At (Hovel_At (T.Point.X, T.Point.Y)).Owner = 0)
               then
                  declare
                     H : constant Positive := Hovel_At (T.Point.X, T.Point.Y);
                  begin
                     Add ((Label => To_Line ((if House_At (H).Marked then "Keep this hovel (lift the mark)"
                                              else "Raze this hovel (nobody's)")),
                           Todo => (What => Mark_Hovel, By => Who, Hovel => H, Marked => not House_At (H).Marked),
                           others => <>));
                  end;
               end if;
            end if;
         when A_Person =>
            if T.Index in 1 .. Members then
               M.Title := To_Line (Name_Of (T.Index));
               if not Dead (T.Index) then
                  for J in Job_Kind loop
                     --  (the cook's is come to by skill, not given: a development entry, in its old row)
                     if J /= Cook or else Dev_Jobs then
                        Add ((Label => To_Line
                                (Capital (Job_Name (J))
                                 & (if Skills and then Has_Skill (J)
                                    then ": " & Img (Integer (100.0 * Skill_Of (T.Index, Job_Skill (J)))) & " %, x"
                                         & Img (Aptitude_Of (T.Index, Job_Skill (J)), 1)
                                    else "")),
                              Todo => (What => Give_Job, By => Who, Whom => T.Index, Job => J),
                              Is_Now => Job_Of (T.Index) = J and then not Is_Builder (T.Index)
                                        and then not (Dev_Jobs and then (Stockman_Named (T.Index)
                                                                         or else Carpenter_Named (T.Index))),
                              others => <>));
                     end if;
                  end loop;
                  if Dev_Jobs then              --  (the jobs a serf comes to by itself, for development)
                     declare
                        procedure Trade_Row (Name : String; Skill : Skill_Kind; What : Action; Now : Boolean) is
                        begin
                           Add ((Label => To_Line
                                   (Name
                                    & (if Skills
                                       then ": " & Img (Integer (100.0 * Skill_Of (T.Index, Skill))) & " %, x"
                                            & Img (Aptitude_Of (T.Index, Skill), 1)
                                       else "")),
                                 Todo => (case What is
                                             when Make_Stockman =>
                                               (What => Make_Stockman, By => Who, Whom => T.Index, Job => Porter),
                                             when Make_Carpenter =>
                                               (What => Make_Carpenter, By => Who, Whom => T.Index, Job => Forester),
                                             when others =>
                                               (What => Make_Builder, By => Who, Whom => T.Index, Job => Forester)),
                                 Is_Now => Now, others => <>));
                        end Trade_Row;
                     begin
                        Trade_Row ("Builder", Building, Make_Builder, Is_Builder (T.Index));
                        Trade_Row ("Stockman", Portering, Make_Stockman, Stockman_Named (T.Index));
                        Trade_Row ("Carpenter", Carpentry, Make_Carpenter,
                                   Carpenter_Named (T.Index) and then not Is_Builder (T.Index));
                     end;
                  end if;
               end if;
               Add ((Label => To_Line ("Follow"),
                     Todo => (What => Follow, By => Who, Whom => T.Index, Job => Unassigned), others => <>));
            end if;
         when A_Stockpile =>
            M.Title := To_Line ("Stockpile");
            for K in Item_Kind loop
               if Has_Reserve (K) then
                  declare
                     Now : constant Natural := (if K = Wood then Wood_Reserve else Reserve_Of (K));
                     Has : constant Natural := (if K = Wood then Wood_Total else Have (K));
                  begin
                     Add_Steps
                       (Capital (Castle.Colony.Name (K)) & ": "
                        & (if Now = 0
                           then (if Demand_Chain then "none" elsif K = Wood then "no limit"
                                 elsif K = Vegetables then "any" else "none")
                           else Img (Has) & " of " & Img (Now)),
                        (What => Set_Reserve, By => Who, Kind => K, Amount => Less (Now)),
                        (What => Set_Reserve, By => Who, Kind => K, Amount => Now + Reserve_Step));
                  end;
               end if;
            end loop;
            Add_Steps
              ("Winter store: " & (if Winter_Store = 0 then "none"
                                   else Img (Store_Held_Days, 1) & " of " & Img (Winter_Store) & " days"),
               (What => Set_Winter_Store, By => Who, Days => (if Winter_Store = 0 then 0 else Winter_Store - 1)),
               (What => Set_Winter_Store, By => Who, Days => Winter_Store + 1));
            --  (the stockpile itself, where the menu is one's: removed, or the order taken back; never the stockyard)
            if T.Index in 1 .. Zone_Count and then Zone_At (T.Index).Kind = Stockpile_Zone and then not Zone_At (T.Index).Yard
              and then Zone_At (T.Index).Blocks > 0
            then
               Add ((Label => To_Line (if Zone_At (T.Index).Leaving then "Keep this stockpile" else "Remove this stockpile"),
                     Todo => (What => Remove_Stockpile, By => Who, Pile => T.Index, Remove => not Zone_At (T.Index).Leaving),
                     others => <>));
            end if;
         when The_Camp =>
            M.Title := To_Line ("The camp");      --  nothing to do to it yet
         when A_Deer =>
            M.Title := To_Line ("A deer");        --  nor to a deer
         when The_Colony =>
            M.Title := To_Line ("The colony");
            Add ((Label => To_Line ("Spare apples"),
                  Todo => (What => Spare_Apples, By => Who, On => not Protect_Apples),
                  Is_Now => Protect_Apples, others => <>));
            Add ((Label => To_Line ("Spare deer"),
                  Todo => (What => Spare_Deer, By => Who, On => not Castle.Colony.Spare_Deer),
                  Is_Now => Castle.Colony.Spare_Deer, others => <>));
      end case;
      return M;
   end Menu_For;

end Castle.Actions;
