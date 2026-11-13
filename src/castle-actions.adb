with Castle.Text; use Castle.Text;

package body Castle.Actions is

   Band_N    : Positive := 6;
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
         when Zone_Housing     => (To_Line ("zone housing"), The_Ground, Leader));

   function Name (A : Action) return String is (Str (Row_Of (A).Name));

   function May (Who : Actor; A : Action) return Boolean is (Rank_Of (Who) >= Row_Of (A).Least);

   function Job_Name (J : Job_Kind) return String is
     (case J is
         when Unassigned => "no job", when Gatherer => "gatherer", when Forester => "forester",
         when Hunter => "hunter", when Porter => "porter", when Cook => "cook");

   --  The kinds a reserve can be set of.
   function Has_Reserve (K : Item_Kind) return Boolean is (K in Wood | Straw | Meat | Vegetables);

   ------------------------------------------------------------------ orders

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
            Place_Stake (O.Stake_At, Band_N, Band_Seed);
            R.Done := Has_Stake;
         when Lay_Path =>
            if not Has_Stake then
               R.Why := Not_Now;
               return;
            end if;
            Lay_Path (O.From, O.To, R.Count);
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
         when Give_Job =>
            if O.Whom not in 1 .. Members or else Dead (O.Whom) then
               R.Why := No_Such_Target;
               return;
            end if;
            Set_Job (O.Whom, O.Job, By => O.By);
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
            R.Done := R.Count > 0;
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
               when Give_Job | Follow => "there is nobody there to " & Name (O.What),
               when Set_Reserve       => "no reserve is kept of " & Castle.Colony.Name (O.Kind),
               when others            => "there is nothing there to do it to"),
         when Not_Now =>
           (if O.What = Raise_Stake then "the homestake is raised already" else "raise the homestake first"),
         when The_Ground_Refused =>
           (case O.What is
               when Raise_Stake    => "there is no ground to raise it on",
               when Lay_Path       => Path_Refusal,
               when Zone_Stockpile => Stockpile_Refusal,
               when Zone_Camp      => Camp_Refusal,
               when Zone_Housing   => Housing_Refusal,
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
               Add ((Label => To_Line ("Raise the homestake here"),
                     Todo => (What => Raise_Stake, By => Who, Stake_At => T.Point), others => <>));
            else
               Add ((Label => To_Line ("Path from here"),
                     Todo => (What => Lay_Path, By => Who, From => T.Point, To => T.Point),
                     Two_Point => True, others => <>));
               Add ((Label => To_Line ("Stockpile from here"),
                     Todo => (What => Zone_Stockpile, By => Who, X0 => T.Point.X, Y0 => T.Point.Y,
                              X1 => T.Point.X, Y1 => T.Point.Y),
                     Two_Point => True, others => <>));
               if not Has_Camp then
                  Add ((Label => To_Line ("Camp here"),
                        Todo => (What => Zone_Camp, By => Who, Fire_At => T.Point), others => <>));
               end if;
               Add ((Label => To_Line ("Housing from here"),
                     Todo => (What => Zone_Housing, By => Who, X0 => T.Point.X, Y0 => T.Point.Y,
                              X1 => T.Point.X, Y1 => T.Point.Y),
                     Two_Point => True, others => <>));
            end if;
         when A_Person =>
            if T.Index in 1 .. Members then
               M.Title := To_Line (Name_Of (T.Index));
               if not Dead (T.Index) then
                  for J in Job_Kind loop
                     Add ((Label => To_Line
                             (Capital (Job_Name (J))
                              & (if Skills and then Has_Skill (J)
                                 then ": " & Img (Integer (100.0 * Skill_Of (T.Index, Job_Skill (J)))) & " %, x"
                                      & Img (Aptitude_Of (T.Index, Job_Skill (J)), 1)
                                 else "")),
                           Todo => (What => Give_Job, By => Who, Whom => T.Index, Job => J),
                           Is_Now => Job_Of (T.Index) = J, others => <>));
                  end loop;
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
