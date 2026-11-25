with Castle.Actions;
with Castle.Colony;
with Castle.Views;
with Ada.Characters.Handling;
with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Castle.Fields;
with Castle.Geology;
with Castle.Text;   use Castle.Text;
with Castle.UI;     use Castle.UI;

package body Castle.HUD is

   use Castle.Maps;
   Degree : constant Character := Character'Val (176);

   function Pretty (M : Material) return String is
      S : String := Material'Image (M);
   begin
      for I in S'Range loop
         if S (I) = '_' then
            S (I) := ' ';
         elsif I > S'First then
            S (I) := Ada.Characters.Handling.To_Lower (S (I));
         end if;
      end loop;
      return S;
   end Pretty;

   function Compass (Dx, Dy : Float) return String is
      Names : constant array (0 .. 7) of String (1 .. 2) :=
        ["E ", "NE", "N ", "NW", "W ", "SW", "S ", "SE"];
   begin
      if abs Dx + abs Dy < 1.0E-6 then
         return "-";
      end if;
      declare
         A : constant Float := Arctan (Dy, Dx);                 --  -pi .. pi, 0 east
         K : constant Integer := Integer (Float'Floor (A / (Ada.Numerics.Pi / 4.0) + 0.5)) mod 8;
         N : constant String := Names (K);
      begin
         return (if N (2) = ' ' then N (1 .. 1) else N);
      end;
   end Compass;

   function Kind_Name (K : Deposit_Kind) return String is
     (case K is
         when Coal_Vein      => "Coal vein",
         when Iron_Vein      => "Iron vein",
         when Salt_Vein      => "Salt vein",
         when Bog_Iron_Patch => "Bog iron");

   function Metres (M : Float) return String is
     (if M < 10.0 then Img (M, 1) & " m" else Img (M, 0) & " m");

   ---------------------------------------------------------------- status

   function Season_Text (S : Castle.Climate.Season) return String is
     (case S is
         when Castle.Climate.Spring => "Spring",
         when Castle.Climate.Summer => "Summer",
         when Castle.Climate.Autumn => "Autumn",
         when Castle.Climate.Winter => "Winter");

   procedure Status_Panel (S : Status; Tools : in out Tool_State) is
      use Castle.Climate;
      D   : constant Float := Day_Of_Year (S.Clock);
      H   : constant Float := Hour_Of_Day (S.Clock);
      Hh  : constant Integer := Integer (Float'Floor (H));
      Mm  : constant Integer := Integer (Float'Floor ((H - Float (Hh)) * 60.0));
      Wx  : Weather renames S.Weather;
      T   : constant Float := Temperature_At (Wx, S.Focus_Z);
      Spd : constant Float := Sqrt (Wx.Wind_X ** 2 + Wx.Wind_Y ** 2);
      Sky : constant String :=
        (if Wx.Snow > 0.05 then (if Wx.Snow > 0.6 then "Heavy snow" else "Snow")
         elsif Wx.Rain > 0.05 then (if Wx.Rain > 0.6 then "Heavy rain" else "Rain")
         elsif Wx.Cloud_Cover > 0.7 then "Overcast"
         elsif Wx.Cloud_Cover > 0.35 then "Cloudy" else "Clear");
      function Two (V : Integer) return String is (if V < 10 then "0" & Img (V) else Img (V));
      Season_Name : constant String := Season_Text (Season_Of (D));
      P : Panel := Begin_Panel (6.0, 6.0, 150.0, Season_Name & ", day" & Day_Of_Season (D)'Image);
   begin
      Value (P, "Time", Two (Hh) & ":" & Two (Mm));
      Value (P, "Sky", Sky);
      Value (P, "Temperature", Img (T, 0) & Degree & "C",
             (if T <= 0.0 then Bar_Blue else Ink));
      --  Wind blows toward (Wind_X, Wind_Y): name where it comes from.
      Value (P, "Wind", Img (Spd, 0) & " m/s from " & Compass (-Wx.Wind_X, -Wx.Wind_Y));
      if S.Snow > 0.005 then
         Bar (P, "Snow on the ground", S.Snow / 0.5, Bar_Blue, Img (S.Snow * 100.0, 0) & " cm");
      end if;
      if S.Ice > 0.01 then
         Bar (P, "Ice on the water", S.Ice, Bar_Blue, Img (S.Ice * 100.0, 0) & " %");
      end if;
      if Button (P, "||", On => Tools.Speed = 0, Width => 30.0) then
         Tools.Speed := 0;
      end if;
      if Button (P, "1x", On => Tools.Speed = 1, Width => 30.0) then
         Tools.Speed := 1;
      end if;
      if Button (P, "2x", On => Tools.Speed = 2, Width => 30.0) then
         Tools.Speed := 2;
      end if;
      if Button (P, "3x", On => Tools.Speed = 3, Width => 30.0) then
         Tools.Speed := 3;
      end if;
      Gap (P, 0.25);
      Label (P, "F1 keys  F2 survey  F3 debug", Ink_Dim);
      End_Panel (P);
   end Status_Panel;

   ------------------------------------------------------------------ notes

   --  What an order came to, said on screen for a few seconds (and the game
   --  puts it in the log): a refusal with its reason, a zone's size.
   procedure Say (Tools : in out Tool_State; S : String; Bad : Boolean := False) is
   begin
      Tools.Note := To_Line (S);
      Tools.Note_Bad := Bad;
      Tools.Note_Left := Note_S;
      Tools.Note_Count := Tools.Note_Count + 1;
   end Say;

   --  Text too long for a line, broken at its spaces over as many lines as
   --  it takes, each set in by Indent.
   procedure Wrapped (P : in out Panel; S : String; C : Color; Indent : String := "  ") is
      Room   : constant Float := Inner_W (P) - Text_Width (Indent);
      From   : Positive := S'First;
      Cut    : Natural;
   begin
      while From <= S'Last loop
         Cut := S'Last;
         if Text_Width (S (From .. S'Last)) > Room then
            Cut := From;                                   --  the last space that still fits
            for K in From .. S'Last loop
               exit when Text_Width (S (From .. K)) > Room;
               if S (K) = ' ' then
                  Cut := K;
               end if;
            end loop;
            if Cut = From then                             --  one long word: let Label cut it
               Cut := S'Last;
            end if;
         end if;
         Label (P, Indent & S (From .. (if Cut < S'Last then Cut - 1 else Cut)), C);
         From := Cut + 1;
      end loop;
   end Wrapped;

   --  At the foot of the screen, between the corner panels.
   procedure Note_Panel (Tools : in out Tool_State; Seconds : Float) is
   begin
      if Tools.Note_Left <= 0.0 then
         return;
      end if;
      Tools.Note_Left := Tools.Note_Left - Seconds;
      declare
         T    : constant String := Str (Tools.Note);
         Full : constant Float := Screen_W / Scale;
         Wd   : constant Float :=
           Float'Max (80.0, Float'Min (Full - 2.0 * 162.0, Text_Width (T) / Scale + 12.0));
         P    : Panel := Begin_Panel (Float'Max (0.0, Float'Floor ((Full - Wd) / 2.0)), 6.0, Wd, From => Bottom_Left);
      begin
         Wrapped (P, T, (if Tools.Note_Bad then Ink_Bad else Ink), Indent => "");
         End_Panel (P);
      end;
   end Note_Panel;

   ------------------------------------------------------------------ orders

   --  Every order of the interface goes through the action table, and what
   --  comes of it is said.
   procedure Carry_Out (O : Castle.Actions.Order; Tools : in out Tool_State) is
      use Castle.Actions;
      R : Result;
   begin
      Perform (O, R);
      Tools.Last_Done := R.Done;
      case O.What is
         when Raise_Stake =>
            if R.Done then
               Say (Tools, (if O.As_Square then "the colony is founded: its square's middle at "
                            else "the homestake is raised at ")
                           & Img (Castle.Colony.Stake.X, 1) & ", " & Img (Castle.Colony.Stake.Y, 1));
               Tools.Mode := Path;
               Tools.Path_Started := False;
            else
               Say (Tools, "no homestake there: " & Why_Not (O, R), Bad => True);
            end if;
         when Lay_Path =>
            if not R.Done then
               Say (Tools, "no path there: " & Why_Not (O, R), Bad => True);
            elsif Castle.Colony.Pull_Gave_Way > 0 then
               Say (Tools, "the path goes through the housing, which gave way under it");
            end if;
         when Zone_Stockpile | Place_Stockpile =>
            if R.Done then
               Say (Tools, "stockpile zoned:" & R.Count'Image & " cells");
               --  (placed once: the tool goes; put down whole, another can be: the tool stays in hand)
               if O.What = Place_Stockpile and then Tools.Mode = Stockpile and then not Castle.Colony.Box_Place then
                  Tools.Mode := Path;
                  Tools.Path_Started := False;
               end if;
            else
               Say (Tools, "no stockpile there: " & Why_Not (O, R), Bad => True);
            end if;
         when Zone_Stockyard | Place_Stockyard =>
            if R.Done then
               Say (Tools, "stockyard zoned:" & R.Count'Image & " places, closed until its storehouse stands");
               if Tools.Mode = Stockyard then          --  (zoned once: the tool goes)
                  Tools.Mode := Path;
                  Tools.Path_Started := False;
               end if;
            else
               Say (Tools, "no stockyard there: " & Why_Not (O, R), Bad => True);
            end if;
         when Unzone_Housing =>
            if R.Done then
               Say (Tools, "housing taken out:" & R.Count'Image & " block columns"
                           & (if R.Marked > 0
                              then ";" & R.Marked'Image & (if R.Marked = 1 then " hovel" else " hovels")
                                   & " there nobody's: to be taken down"
                              else "")
                           & (if Castle.Colony.Unzone_Lived_In > 0
                              then ";" & Castle.Colony.Unzone_Lived_In'Image & " lived in: left, with"
                                   & (if Castle.Colony.Unzone_Lived_In = 1 then " its lot" else " their lots")
                              else ""));
            else
               Say (Tools, "nothing taken out: " & Why_Not (O, R), Bad => True);
            end if;
            if Tools.Mode = Unzone then
               Tools.Mode := Housing;
            end if;
         when Mark_Hovel =>
            if R.Done then
               Say (Tools, (if O.Marked then "the hovel is to be taken down" else "the mark lifted: the hovel is kept"));
            else
               Say (Tools, "a hovel that is lived in is not razed", Bad => True);
            end if;
         when Zone_Camp =>
            if R.Done then
               Say (Tools, "camp zoned at " & Img (Castle.Colony.Camp.X, 1) & ", " & Img (Castle.Colony.Camp.Y, 1));
               if Tools.Mode = Camp then
                  Tools.Mode := Path;
                  Tools.Path_Started := False;
               end if;
            else
               Say (Tools, "no camp there: " & Why_Not (O, R), Bad => True);
            end if;
         when Follow =>
            if R.Done then
               Tools.Follow := (if Tools.Follow = O.Whom then 0 else O.Whom);
            end if;
         when Zone_Housing | Fill_Housing =>
            if R.Done then
               Say (Tools, (if Castle.Colony.Housing_Joined > 0 then "housing extended: room for" else "housing zoned: room for")
                           & (if R.Count = 0
                              then " no hovel yet: the next in turn does not fit on it ("
                                   & (if O.What = Zone_Housing then "pull it further, or " else "") & "mark more elsewhere)"
                              else R.Count'Image & (if R.Count = 1 then " hovel" else " hovels")
                                   & (if Castle.Colony.Housing_Joined > 0 then " now" else "")));
            else
               Say (Tools, "no housing there: " & Why_Not (O, R), Bad => True);
            end if;
         when Pull_Housing =>
            if R.Done then
               Say (Tools, "housing with its path: "
                           & (if Castle.Colony.Pull_Rows_Zoned = 2 then "two rows, " else "")
                           & (if R.Count = 0 then "room for no hovel yet (pull it further)"
                              else "room for" & R.Count'Image & (if R.Count = 1 then " hovel" else " hovels"))
                           & (if Castle.Colony.Pull_Path_M > 0.0
                              then ";" & Integer'Image (Integer (Castle.Colony.Pull_Path_M)) & " m of path to lay"
                              else "; along the path that is there")
                           & (if Castle.Colony.Pull_Gave_Way > 0 then "; housing gave way under it" else ""));
            else
               Say (Tools, "no housing there: " & Why_Not (O, R), Bad => True);
            end if;
         when Castle.Actions.Remove_Stockpile =>
            Say (Tools, (if not R.Done then Why_Not (O, R)
                         elsif O.Remove then "the stockpile is to go: what lies on it is carried off first"
                         else "the stockpile stays"), Bad => not R.Done);
         when Give_Job | Make_Builder | Make_Stockman | Make_Carpenter | Set_Reserve | Set_Winter_Store | Spare_Apples
            | Castle.Actions.Spare_Deer =>
            if not R.Done then
               Say (Tools, Why_Not (O, R), Bad => True);
            end if;
      end case;
   end Carry_Out;

   procedure Ground_Click (P : Vec3; Tools : in out Tool_State) is
      use Castle.Actions;
   begin
      case Tools.Mode is
         when Stake =>
            Carry_Out ((What => Raise_Stake, By => Castle.Colony.The_Player, Stake_At => P,
                        As_Square => Castle.Actions.Square_Stake, Stake_Way => Tools.Way), Tools);
         when Path =>
            --  (the line as it will be laid: straight or at 45 degrees, Castle.Actions.Path_Snap)
            if Tools.Path_Started then
               declare
                  To : constant Vec3 := Path_Reach (Tools.Path_From, P);
               begin
                  Carry_Out ((What => Lay_Path, By => Castle.Colony.The_Player, From => Tools.Path_From, To => To),
                             Tools);
                  if Tools.Last_Done then
                     Tools.Path_From := To;  --  (a stretch refused: the line goes on from where it had got to)
                  end if;
               end;
            else
               Tools.Path_From := Path_Begin (P);
            end if;
            Tools.Path_Started := True;
         when Stockpile =>
            if Castle.Colony.Box_Place then            --  (put down whole with its path, where it is held)
               Carry_Out ((What => Place_Stockpile, By => Castle.Colony.The_Player, Pile_At => P,
                           Pile_Way => Tools.Way), Tools);
            elsif Castle.Colony.One_Stockpile then
               Carry_Out ((What => Place_Stockpile, By => Castle.Colony.The_Player, Pile_At => P, Pile_Way => 0), Tools);
            elsif Tools.Zone_Started then
               Carry_Out ((What => Zone_Stockpile, By => Castle.Colony.The_Player,
                           X0 => Tools.Zone_From.X, Y0 => Tools.Zone_From.Y, X1 => P.X, Y1 => P.Y), Tools);
               Tools.Zone_Started := False;
            else
               Tools.Zone_From := P;
               Tools.Zone_Started := True;
            end if;
         when Stockyard =>
            if Castle.Colony.Yard_Box then             --  (put down whole with its path, where it is held)
               Carry_Out ((What => Place_Stockyard, By => Castle.Colony.The_Player, Pile_At => P,
                           Pile_Way => Tools.Way), Tools);
            elsif Tools.Zone_Started then
               Carry_Out ((What => Zone_Stockyard, By => Castle.Colony.The_Player,
                           X0 => Tools.Zone_From.X, Y0 => Tools.Zone_From.Y, X1 => P.X, Y1 => P.Y), Tools);
               Tools.Zone_Started := False;
            else
               Tools.Zone_From := P;
               Tools.Zone_Started := True;
            end if;
         when Camp =>
            Carry_Out ((What => Zone_Camp, By => Castle.Colony.The_Player, Fire_At => P), Tools);
         when Housing =>
            if Tools.Zone_Started and then Castle.Actions.Housing_Pull then
               Carry_Out ((What => Pull_Housing, By => Castle.Colony.The_Player, Begun => Tools.Zone_From,
                           Pulled_To => P, Rows => Castle.Colony.Pull_Rows'Val (Tools.Rows mod 3)), Tools);
               Tools.Zone_Started := False;
            elsif Tools.Zone_Started then
               Carry_Out ((What => Zone_Housing, By => Castle.Colony.The_Player,
                           X0 => Tools.Zone_From.X, Y0 => Tools.Zone_From.Y, X1 => P.X, Y1 => P.Y), Tools);
               Tools.Zone_Started := False;
            else
               Tools.Zone_From := P;
               Tools.Zone_Started := True;
            end if;
         when Unzone =>
            if Tools.Zone_Started then
               Carry_Out ((What => Unzone_Housing, By => Castle.Colony.The_Player,
                           X0 => Tools.Zone_From.X, Y0 => Tools.Zone_From.Y, X1 => P.X, Y1 => P.Y), Tools);
               Tools.Zone_Started := False;
            else
               Tools.Zone_From := P;
               Tools.Zone_Started := True;
            end if;
         when Edit =>
            null;
      end case;
   end Ground_Click;

   --  A choice of a menu: done at once, or (a path, a stockpile) begun here
   --  for the next click on the ground to finish.
   procedure Choose (C : Castle.Actions.Choice; Tools : in out Tool_State) is
      use Castle.Actions;
   begin
      if not C.Two_Point then
         Carry_Out (C.Todo, Tools);
      elsif C.Todo.What = Lay_Path then
         Tools.Mode := Path;
         Tools.Path_From := Path_Begin (C.Todo.From);
         Tools.Path_Started := True;
         Tools.Zone_Started := False;
      elsif C.Todo.What = Place_Stockpile then    --  (a box to put down: taken in hand, the next click puts it)
         Tools.Mode := Stockpile;
         Tools.Zone_Started := False;
         Tools.Path_Started := False;
      elsif C.Todo.What = Place_Stockyard then    --  (the stockyard's box likewise)
         Tools.Mode := Stockyard;
         Tools.Zone_Started := False;
         Tools.Path_Started := False;
      elsif C.Todo.What = Raise_Stake then        --  (the square: taken in hand, to be turned and put down)
         Tools.Mode := Stake;
      elsif C.Todo.What = Pull_Housing then       --  (housing with its path: begun there, the next click pulls it)
         Tools.Mode := Housing;
         Tools.Zone_From := C.Todo.Begun;
         Tools.Zone_Started := True;
         Tools.Path_Started := False;
      elsif C.Todo.What in Zone_Stockpile | Zone_Housing | Zone_Stockyard | Unzone_Housing then
         Tools.Mode := (if C.Todo.What = Zone_Housing then Housing
                        elsif C.Todo.What = Unzone_Housing then Unzone
                        elsif C.Todo.What = Zone_Stockyard then Stockyard else Stockpile);
         Tools.Zone_From := (C.Todo.X0, C.Todo.Y0, 0.0);
         Tools.Zone_Started := True;
         Tools.Path_Started := False;
      end if;
   end Choose;

   --  A menu's choices as buttons: one to a line, the one that already
   --  holds lit; a step down and up as a minus and a plus before their
   --  label.  Chose: one that ends a menu was taken (a step does not).
   procedure Lay_Choices (P : in out Panel; M : Castle.Actions.Menu; Tools : in out Tool_State; Chose : out Boolean;
                          Width : Float := 0.0)
   is
      use Castle.Actions;
      K : Positive := 1;
   begin
      Chose := False;
      while K <= M.N loop
         if M.Items (K).Step = Fewer and then K < M.N and then M.Items (K + 1).Step = More then
            if Button (P, "-", Width => 14.0) then
               Choose (M.Items (K), Tools);
            end if;
            if Button (P, "+", Width => 14.0) then
               Choose (M.Items (K + 1), Tools);
            end if;
            Beside (P, Str (M.Items (K).Label));
            Same_Line_End (P);
            K := K + 2;
         else
            if Button (P, Str (M.Items (K).Label), On => M.Items (K).Is_Now, Width => Width) then
               Choose (M.Items (K), Tools);
               Chose := True;
            end if;
            K := K + 1;
         end if;
      end loop;
   end Lay_Choices;

   ------------------------------------------------------------------ sheets

   --  A sheet's lines in a panel: a name and its value on a line (the value
   --  on a line of its own when both will not fit), a bar where there is
   --  one.  What the player's character could not know comes last, under a
   --  rule, so the development view shows it and says so.
   procedure Lay_Sheet (P : in out Panel; S : Castle.Views.Sheet) is
      procedure Line (R : Castle.Views.Row) is
         C  : constant Color :=
           (case R.Shade is
               when Castle.Views.Plain | Castle.Views.Good => Ink,
               when Castle.Views.Dim => Ink_Dim,
               when Castle.Views.Bad => Ink_Bad);
         N  : constant String := Str (R.Name);
         V  : constant String := Str (R.Value);
      begin
         if R.Bar >= 0.0 then
            Bar (P, N, R.Bar,
                 (case R.Shade is
                     when Castle.Views.Bad => Bar_Red, when Castle.Views.Dim => Bar_Amber, when others => Bar_Green),
                 V);
         elsif Text_Width (N) + Text_Width (V) + 6.0 * Scale <= Inner_W (P) then
            Value (P, N, V, C);
         else
            Label (P, N, Ink_Dim);
            Wrapped (P, V, C);
         end if;
      end Line;
      Hidden : Natural := 0;
   begin
      if S.Note.N > 0 then
         Label (P, Str (S.Note), Ink_Dim);
      end if;
      for K in 1 .. S.N loop
         if S.Rows (K).Known then
            Line (S.Rows (K));
         else
            Hidden := Hidden + 1;
         end if;
      end loop;
      if Hidden > 0 then
         Separator (P);
         for K in 1 .. S.N loop
            if not S.Rows (K).Known then
               Line (S.Rows (K));
            end if;
         end loop;
      end if;
   end Lay_Sheet;

   ------------------------------------------------------------------ the context menu

   type Menu_State is record
      Open   : Boolean := False;
      X, Y   : Float := 0.0;                  --  where it was opened (pixels)
      On     : Castle.Pick.Thing;             --  what it is about
      Target : Castle.Actions.Target;
   end record;
   The_Menu : Menu_State;

   function Menu_Open return Boolean is (The_Menu.Open);
   function Menu_On return Castle.Pick.Thing is
     (if The_Menu.Open then The_Menu.On else (others => <>));

   --  The top of the block a ray went into: the ground a click lands on.
   function Top_Of (H : Castle.World_Blocks.Hit) return Vec3 is
     (((Float (H.X) + 0.5) * 0.25, (Float (H.Y) + 0.5) * 0.25, Float (H.Z + 1) * 0.25));

   function Ground_Target (T : Castle.Pick.Thing) return Castle.Actions.Target is
     ((Kind => Castle.Actions.The_Ground, Index => 0, Point => Top_Of (T.Ground)));

   function Target_Of (T : Castle.Pick.Thing) return Castle.Actions.Target is
      use Castle.Pick;
   begin
      case T.Kind is
         when A_Person =>
            return (Castle.Actions.A_Person, T.Index, T.Point);
         when A_Deer =>
            return (Castle.Actions.A_Deer, T.Index, T.Point);
         when A_Zone =>
            if Castle.Colony."=" (Castle.Colony.Zone_At (T.Index).Kind, Castle.Colony.Stockpile_Zone) then
               return (Castle.Actions.A_Stockpile, T.Index, T.Point);
            end if;
            return Ground_Target (T);            --  nothing to do to the camp yet: its ground's menu
         when A_Block | A_House | A_Cart | Nothing =>     --  (nor to a house, nor to the cart)
            return Ground_Target (T);
      end case;
   end Target_Of;

   function Half_Drawn (Tools : Tool_State) return Boolean is (Tools.Path_Started or else Tools.Zone_Started);

   procedure Open_Menu (T : Castle.Pick.Thing; Target : Castle.Actions.Target; X, Y : Float) is
   begin
      The_Menu := (Open => True, X => X, Y => Y, On => T, Target => Target);
   end Open_Menu;

   procedure Point
     (Under         : Castle.Pick.Thing;
      X, Y          : Float;
      Clicked       : Boolean;
      Right_Clicked : Boolean;
      Tools         : in out Tool_State;
      For_World     : out Boolean)
   is
      use Castle.Pick;
      use type Castle.Actions.Target_Kind;
   begin
      For_World := Clicked and then not Castle.UI.Wants_Mouse;
      if The_Menu.Open and then (Clicked or else Right_Clicked) and then not Castle.UI.Over_Popup then
         The_Menu.Open := False;                 --  a click away closes it,
         For_World := False;                     --  and goes no further
      end if;
      if Right_Clicked and then not Castle.UI.Wants_Mouse
        and then (Under.Kind /= Nothing or else Under.Ground.Found)
      then
         declare
            T : constant Castle.Actions.Target := Target_Of (Under);
         begin
            if T.Kind /= Castle.Actions.The_Ground or else Under.Ground.Found then
               if Castle.Actions.Menu_For (Castle.Colony.The_Player, T).N > 0
                 or else (T.Kind = Castle.Actions.The_Ground and then Half_Drawn (Tools))
               then
                  Open_Menu (Under, T, X, Y);
               end if;
            end if;
         end;
      end if;
   end Point;

   function Cancel (Tools : in out Tool_State) return Boolean is
   begin
      if The_Menu.Open then
         The_Menu.Open := False;
         return True;
      elsif Half_Drawn (Tools) then
         Tools.Path_Started := False;
         Tools.Zone_Started := False;
         return True;
      elsif (Tools.Mode = Stockpile and then Castle.Colony.Box_Place)       --  (a box held: put away)
        or else (Tools.Mode = Stockyard and then Castle.Colony.Yard_Box)
      then
         Tools.Mode := Path;
         return True;
      end if;
      return False;
   end Cancel;

   procedure Menu_Popup (Tools : in out Tool_State) is
      use Castle.Actions;
      M     : Menu := Menu_For (Castle.Colony.The_Player, The_Menu.Target);
      On_Ground : constant Boolean := The_Menu.Target.Kind = The_Ground;
      Extra : constant Boolean := On_Ground and then Half_Drawn (Tools);
      Here  : constant Vec3 := The_Menu.Target.Point;
      Chose : Boolean := False;
   begin
      if M.N = 0 and then not Extra then
         The_Menu.Open := False;
         return;
      end if;
      for K in 1 .. M.N loop                      --  whom the eye follows is the interface's to know
         if M.Items (K).Todo.What = Follow then
            M.Items (K).Is_Now := Tools.Follow > 0 and then Tools.Follow = M.Items (K).Todo.Whom;
         end if;
      end loop;
      declare
         P : Panel := Begin_Popup
           (The_Menu.X, The_Menu.Y,
            (case The_Menu.Target.Kind is
                when A_Person    => (if Castle.Colony.Skills then 136.0 else 96.0),
                when A_Stockpile => 176.0,
                when others      => 150.0),
            Str (M.Title));
      begin
         if Extra and then Tools.Path_Started then          --  a path line on the go: on to here, or done
            if Button (P, "Path to here") then
               declare
                  To : constant Vec3 := Path_Reach (Tools.Path_From, Here);
               begin
                  Carry_Out ((What => Lay_Path, By => Castle.Colony.The_Player, From => Tools.Path_From, To => To),
                             Tools);
                  if Tools.Last_Done then
                     Tools.Path_From := To;
                  end if;
               end;
               Chose := True;
            end if;
            if Button (P, "End the path") then
               Tools.Path_Started := False;
               Chose := True;
            end if;
            Separator (P);
         elsif Extra and then Tools.Zone_Started and then Tools.Mode = Housing then
            if Button (P, "Housing to here") then
               if Castle.Actions.Housing_Pull then
                  Carry_Out ((What => Pull_Housing, By => Castle.Colony.The_Player, Begun => Tools.Zone_From,
                              Pulled_To => Here, Rows => Castle.Colony.Pull_Rows'Val (Tools.Rows mod 3)), Tools);
               else
                  Carry_Out ((What => Zone_Housing, By => Castle.Colony.The_Player,
                              X0 => Tools.Zone_From.X, Y0 => Tools.Zone_From.Y, X1 => Here.X, Y1 => Here.Y), Tools);
               end if;
               Tools.Zone_Started := False;
               Chose := True;
            end if;
            if Button (P, "Cancel the housing") then
               Tools.Zone_Started := False;
               Chose := True;
            end if;
            Separator (P);
         elsif Extra and then Tools.Zone_Started and then Tools.Mode = Unzone then
            if Button (P, "Take housing out to here") then
               Carry_Out ((What => Unzone_Housing, By => Castle.Colony.The_Player,
                           X0 => Tools.Zone_From.X, Y0 => Tools.Zone_From.Y, X1 => Here.X, Y1 => Here.Y), Tools);
               Tools.Zone_Started := False;
               Chose := True;
            end if;
            if Button (P, "Cancel") then
               Tools.Zone_Started := False;
               Tools.Mode := Housing;
               Chose := True;
            end if;
            Separator (P);
         elsif Extra and then Tools.Zone_Started and then Tools.Mode = Stockyard then
            if Button (P, "Stockyard to here") then
               Carry_Out ((What => Zone_Stockyard, By => Castle.Colony.The_Player,
                           X0 => Tools.Zone_From.X, Y0 => Tools.Zone_From.Y, X1 => Here.X, Y1 => Here.Y), Tools);
               Tools.Zone_Started := False;
               Chose := True;
            end if;
            if Button (P, "Cancel the stockyard") then
               Tools.Zone_Started := False;
               Chose := True;
            end if;
            Separator (P);
         elsif Extra and then Tools.Zone_Started then
            if Button (P, "Stockpile to here") then
               Carry_Out ((What => Zone_Stockpile, By => Castle.Colony.The_Player,
                           X0 => Tools.Zone_From.X, Y0 => Tools.Zone_From.Y, X1 => Here.X, Y1 => Here.Y), Tools);
               Tools.Zone_Started := False;
               Chose := True;
            end if;
            if Button (P, "Cancel the stockpile") then
               Tools.Zone_Started := False;
               Chose := True;
            end if;
            Separator (P);
         end if;
         declare
            Took : Boolean;
         begin
            Lay_Choices (P, M, Tools, Took);
            Chose := Chose or else Took;
         end;
         End_Popup (P);
      end;
      if Chose then
         The_Menu.Open := False;
      end if;
   end Menu_Popup;

   ------------------------------------------------------------------ the band

   Row_Hover : Natural := 0;    --  the member whose row of the list the cursor is on, this frame

   --  Everyone in the band, a line each: the name (follow them), the job
   --  (its menu: the one a right click on the person gives), what it is
   --  doing.  The cursor on a line shows the person's tooltip.
   --  The cursor is on member I's line of a list: its tooltip, and its menu
   --  on a right click (the one a right click on the person gives).
   procedure On_Row (I : Positive; S : Status) is
   begin
      Row_Hover := I;
      if S.Right_Click then
         Open_Menu ((Kind => Castle.Pick.A_Person, Index => I, others => <>),
                    (Castle.Actions.A_Person, I, (0.0, 0.0, 0.0)), S.Mouse_X, S.Mouse_Y);
      end if;
   end On_Row;

   procedure People_List (P : in out Panel; S : Status; Tools : in out Tool_State; Top_Y : Float) is
      use Castle.Colony;
      Row_H : constant := 16.0;
      --  as many as the tunable says, or as fit above the foot of the window
      Room  : constant Float := Screen_H - Top_Y - 8.0 * Scale;
      Fit_N : constant Integer := Integer (Float'Floor (Room / (Row_H * Scale)));
      L : List := Begin_List (P, Members, Integer'Max (3, Integer'Min (Band_Rows, Fit_N)), Row_H, Tools.Band_Top);
   begin
      for I in First (L) .. Last (L) loop
         declare
            Hot : constant Boolean := Row (P, L, I);
            V   : constant Person_View := Person (I);
         begin
            if Button (P, Name_Of (I), On => Tools.Follow = I, Width => 60.0) then
               Carry_Out ((What => Castle.Actions.Follow, By => The_Player, Whom => I, Job => Unassigned), Tools);
            end if;
            if V.Dead then
               Beside (P, Castle.Colony.Status (I), Ink_Bad);
            else
               if Button (P, Castle.Views.Job_Label (I), Width => 56.0) then
                  Open_Menu ((Kind => Castle.Pick.A_Person, Index => I, others => <>),
                             (Castle.Actions.A_Person, I, (0.0, 0.0, 0.0)), S.Mouse_X, S.Mouse_Y);
               end if;
               Beside (P, Castle.Colony.Status (I), (if V.Starving or else V.Fending then Ink_Bad else Ink_Dim));
            end if;
            if Hot then
               On_Row (I, S);
            end if;
         end;
      end loop;
      End_List (P, L);
   end People_List;

   --  Everyone's level in each working skill, a line each: bright where
   --  the person learns that skill fast, dim where slowly, boxed where it
   --  is the skill of the job it has.  A line shows the person's tooltip
   --  and takes a right click, as in the Band tab.
   procedure Skills_Table (P : in out Panel; S : Status; Tools : in out Tool_State; Top_Y : Float) is
      use Castle.Colony;
      Row_H  : constant := 13.0;
      Name_W : constant := 60.0;
      Job_W  : constant := 56.0;
      Col_W  : constant := 30.0;
      function Col_X (K : Working_Skill) return Float is
        (Name_W + 4.0 + Job_W + 4.0 + Float (Skill_Kind'Pos (K)) * (Col_W + 4.0));
   begin
      if not Skills then
         Label (P, "Skills are off: everyone works at the one pace", Ink_Dim);
         return;
      end if;
      Column_Text (P, 0.0, Name_W, "Name", Ink_Dim);
      Column_Text (P, Name_W + 4.0, Job_W, "Job", Ink_Dim);
      for K in Working_Skill loop
         Column_Text (P, Col_X (K), Col_W, Capital (Name (K) (1 .. 4)), Ink_Dim, Right);
      end loop;
      Next_Line (P, 12.0);
      declare
         Room  : constant Float := Screen_H - Top_Y - (8.0 + 12.0 + 14.0) * Scale;
         Fit_N : constant Integer := Integer (Float'Floor (Room / (Row_H * Scale)));
         L : List := Begin_List (P, Members, Integer'Max (3, Integer'Min (Band_Rows + 4, Fit_N)), Row_H,
                                 Tools.Skills_Top);
      begin
         for I in First (L) .. Last (L) loop
            declare
               Hot : constant Boolean := Row (P, L, I);
               V   : constant Person_View := Person (I);
            begin
               Column_Text (P, 0.0, Name_W, Name_Of (I), (if V.Dead then Ink_Bad else Ink), Drop => 1.0);
               Column_Text (P, Name_W + 4.0, Job_W, (if V.Dead then "dead" else Castle.Views.Job_Label (I)), Ink_Dim,
                            Drop => 1.0);
               if not V.Dead then
                  for K in Working_Skill loop
                     Column_Text
                       (P, Col_X (K), Col_W, Img (Integer (100.0 * V.Level (K))),
                        (if V.Aptitude (K) >= Castle.Views.Apt_From then Ink_Strong
                         elsif V.Aptitude (K) < Castle.Views.Slow_Below then Ink_Dim else Ink),
                        Right, Drop => 1.0,
                        Back => (if Has_Skill (V.Job) and then Job_Skill (V.Job) = K then Button_Hot else 0));
                  end loop;
               end if;
               if Hot then
                  On_Row (I, S);
               end if;
            end;
         end loop;
         End_List (P, L);
      end;
      Label (P, "bright: learns it fast; dim: slowly; boxed: its job's", Ink_Dim);
   end Skills_Table;

   --  What is stored, against what is asked to be kept, and each stockpile
   --  by its own count.
   procedure Stores_Tab_Body (P : in out Panel) is
      use Castle.Colony;
      Shown  : Natural := 0;
      Piles  : Natural := 0;
   begin
      if Cell_Count = 0 then
         Label (P, "No stockpile zoned", Ink_Dim);
      end if;
      --  the demand table: what the stores have of what is asked, and by whom
      Lay_Sheet (P, Castle.Views.Demand);
      if Winter_Store > 0 then
         Value (P, "Held for winter", Img (Store_Held_Days, 1) & " of " & Img (Winter_Store) & " days");
      end if;
      if Trees_Felled > 0 or else Logs_Lying > 0 then
         Value (P, "Felled", Img (Trees_Felled) & (if Trees_Felled = 1 then " tree, " else " trees, ")
                & Img (Logs_Lying) & " logs lying");
      end if;
      for Z in 1 .. Zone_Count loop
         if Zone_At (Z).Kind = Stockpile_Zone and then Zone_At (Z).Blocks > 0 then      --  (not one removed)
            Piles := Piles + 1;
            if Shown < 3 then
               Shown := Shown + 1;
               Separator (P);
               Lay_Sheet (P, (Castle.Views.Zone (Z) with delta Note => To_Line ("Stockpile, " & Str (Castle.Views.Zone (Z).Note))));
            end if;
         end if;
      end loop;
      if Piles > Shown then
         Label (P, "and " & Img (Piles - Shown) & " more (point at one)", Ink_Dim);
      end if;
   end Stores_Tab_Body;

   procedure Band_Panel (S : Status; Tools : in out Tool_State) is
      use Castle.Colony;
      P : Panel := Begin_Panel (6.0, Castle.UI.Last_Bottom + 4.0, 300.0,
                                "The band (" & Img (Living) & (if Deaths > 0 then " living, " & Img (Deaths) & " dead"
                                                               else "") & ")", From => Top_Right);
   begin
      if Needs then
         declare
            Hungry_N, Asleep_N, Cold_N : Natural := 0;
         begin
            for I in 1 .. Members loop
               if Hungry (I) then
                  Hungry_N := Hungry_N + 1;
               end if;
               if Asleep (I) then
                  Asleep_N := Asleep_N + 1;
               end if;
               if Cold (I) then
                  Cold_N := Cold_N + 1;
               end if;
            end loop;
            Value (P, "Food", Img (Food_Days, 1) & " days" & (if Hungry_N > 0 then ", " & Img (Hungry_N) & " hungry"
                                                              else "")
                   & (if Asleep_N > 0 then ", " & Img (Asleep_N) & " asleep" else "")
                   & (if Cold_N > 0 then ", " & Img (Cold_N) & " cold" else ""),
                   (if Hungry_N > 0 or else Cold_N > 0 then Ink_Bad else Ink));
            Value (P, "Confidence", Img (Integer (100.0 * Confidence)) & " %",
                   (if Confidence < 0.4 or else Deaths > 0 then Ink_Bad else Ink));
         end;
      end if;
      Gap (P, 0.15);
      if Tab (P, "Band", Tools.Tab = People_Tab) then
         Tools.Tab := People_Tab;
      end if;
      if Tab (P, "Stores", Tools.Tab = Stores_Tab) then
         Tools.Tab := Stores_Tab;
      end if;
      if Tab (P, "Camp", Tools.Tab = Camp_Tab) then
         Tools.Tab := Camp_Tab;
      end if;
      if Tab (P, "Orders", Tools.Tab = Orders_Tab) then
         Tools.Tab := Orders_Tab;
      end if;
      if Tab (P, "Skills", Tools.Tab = Skills_Tab) then
         Tools.Tab := Skills_Tab;
      end if;
      End_Tabs (P);
      case Tools.Tab is
         when People_Tab =>
            People_List (P, S, Tools, Top_Y => Cursor_Y (P));
         when Stores_Tab =>
            Stores_Tab_Body (P);
         when Camp_Tab =>
            if Has_Camp then
               Lay_Sheet (P, Castle.Views.Zone (Camp_Zone));
            else
               Label (P, "No camp zoned", Ink_Dim);
               Label (P, "(Campfire in the tools, or right click the ground)", Ink_Dim);
            end if;
         when Skills_Tab =>
            Skills_Table (P, S, Tools, Top_Y => Cursor_Y (P));
         when Orders_Tab =>
            --  the same choices a stockpile's menu gives, and the colony's protections
            declare
               Took : Boolean;
            begin
               Label (P, "Keep in store", Ink_Dim);
               Lay_Choices (P, Castle.Actions.Menu_For (The_Player, (Castle.Actions.A_Stockpile, 0, (0.0, 0.0, 0.0))),
                            Tools, Took);
               Gap (P, 0.2);
               Label (P, "Protect", Ink_Dim);
               Lay_Choices (P, Castle.Actions.Menu_For (The_Player, (Castle.Actions.The_Colony, 0, (0.0, 0.0, 0.0))),
                            Tools, Took, Width => 96.0);
            end;
      end case;
      End_Panel (P);
   end Band_Panel;

   ------------------------------------------------------------------ what the cursor is on

   --  The tooltip of what the cursor rests on: a person (in the world, or
   --  on its line of the band's list), a zone, a deer.
   procedure Tip_Panel (S : Status; Warning : String := "") is
      use Castle.Pick;
      Key : constant Natural :=
        (if Row_Hover > 0 then 1_000 + Row_Hover
         else (case S.Under.Kind is
                  when A_Person => 1_000 + S.Under.Index,
                  when A_Deer   => 2_000 + S.Under.Index,
                  when A_Zone   => 3_000 + S.Under.Index,
                  when A_House  => 4_000 + S.Under.Index,
                  when A_Cart   => 5_000,
                  when A_Block | Nothing => 0));
   begin
      --  (a box held where it would be refused: why, at once, in place of what is under it)
      if not The_Menu.Open and then Warning /= "" then
         declare
            P : Panel := Begin_Tip (190.0);
         begin
            Wrapped (P, Warning, Ink_Bad, Indent => "");
            End_Tip (P);
         end;
         return;
      end if;
      if The_Menu.Open or else not Tip_Due (Key) then
         return;
      end if;
      declare
         Sheet : constant Castle.Views.Sheet :=
           (if Key >= 5_000 then Castle.Views.Cart
            elsif Key >= 4_000 then Castle.Views.House (Key - 4_000)
            elsif Key >= 3_000 then Castle.Views.Zone (Key - 3_000)
            elsif Key >= 2_000 then Castle.Views.Deer (Key - 2_000)
            else Castle.Views.Person (Key - 1_000));
         P : Panel := Begin_Tip (190.0, Str (Sheet.Title));
      begin
         Lay_Sheet (P, Sheet);
         End_Tip (P);
      end;
   end Tip_Panel;

   ----------------------------------------------------------------- tools

   procedure Tools_Panel (Tools : in out Tool_State; Place_Held : Boolean) is
      Placing : constant Boolean := Tools.Place or else Place_Held;
      P : Panel := Begin_Panel (6.0, 6.0, 136.0, "Tools", From => Top_Right);
   begin
      if Button (P, "Dig", On => Tools.Mode = Edit and then not Placing, Width => 62.0) then
         Tools.Place := False;
         Tools.Mode := Edit;
      end if;
      if Button (P, "Place", On => Tools.Mode = Edit and then Placing, Width => 62.0) then
         Tools.Place := True;
         Tools.Mode := Edit;
      end if;
      Gap (P, 0.2);
      Label (P, "Brush", Ink_Dim);
      if Button (P, "25 cm", On => Tools.Brush = 1, Width => 40.0) then
         Tools.Brush := 1;
      end if;
      if Button (P, "1 m", On => Tools.Brush = 4, Width => 40.0) then
         Tools.Brush := 4;
      end if;
      if Button (P, "2 m", On => Tools.Brush = 8, Width => 40.0) then
         Tools.Brush := 8;
      end if;
      Gap (P, 0.2);
      Label (P, "Colony", Ink_Dim);
      if not Castle.Colony.Has_Stake then
         if Button (P, "Homestake", On => Tools.Mode = Stake) then
            Tools.Mode := Stake;
         end if;
      else
         if Button (P, "Path", On => Tools.Mode = Path, Width => 62.0) then
            Tools.Mode := Path;
         end if;
         if not Castle.Colony.One_Stockpile or else Castle.Colony.Stockpile_Count = 0 then
            if Button (P, "Stockpile", On => Tools.Mode = Stockpile, Width => 62.0) then
               Tools.Mode := Stockpile;
            end if;
         elsif Tools.Mode = Stockpile then      --  (the stockpile is placed once)
            Tools.Mode := Path;
         end if;
         if not Castle.Colony.Has_Camp then
            if Button (P, "Campfire", On => Tools.Mode = Camp, Width => 62.0) then
               Tools.Mode := Camp;
            end if;
         elsif Tools.Mode = Camp then
            Tools.Mode := Path;
         end if;
         if Button (P, "Housing", On => Tools.Mode = Housing, Width => 62.0) then
            Tools.Mode := Housing;
         end if;
         if Castle.Colony.Stockyard = 0 then
            if Button (P, "Stockyard", On => Tools.Mode = Stockyard, Width => 62.0) then
               Tools.Mode := Stockyard;
               Tools.Zone_Started := False;
            end if;
         elsif Tools.Mode = Stockyard then      --  (the stockyard is zoned once)
            Tools.Mode := Path;
         end if;
      end if;
      case Tools.Mode is
         when Stake     => if Castle.Actions.Square_Stake then
                              Label (P, (if Castle.Colony.Square_Wide then "11 m square, a path round"
                                         else "10 m square, a path round"), Ink_Dim);
                              Label (P, "Z, X: turn it; click: found it", Ink_Dim);
                           else
                              Label (P, "click the ground", Ink_Dim);
                           end if;
         when Path      => Label (P, "click along the way", Ink_Dim);
                           Label (P, "Esc: stop", Ink_Dim);
         when Stockpile => if Castle.Colony.Box_Place then
                              Label (P, "10 x 10 m, with its path", Ink_Dim);
                              Label (P, "Z, X: turn it; click: put it", Ink_Dim);
                           elsif Castle.Colony.One_Stockpile then
                              Label (P, "click beside a path", Ink_Dim);
                              Label (P, "10 x 10 m, once", Ink_Dim);
                           else
                              Label (P, "click two corners", Ink_Dim);
                              Label (P, "beside a path", Ink_Dim);
                           end if;
         when Stockyard => if Castle.Colony.Yard_Box then
                              Label (P, "20 x 20 m, with its path", Ink_Dim);
                              Label (P, "Z, X: turn it; click: put it", Ink_Dim);
                           else
                              Label (P, "click two corners", Ink_Dim);
                              Label (P, "beside a path, 15 x 15 m", Ink_Dim);
                           end if;
         when Camp      => Label (P, "click the fire's place", Ink_Dim);
                           Label (P, "7 x 7 m, on level grass", Ink_Dim);
         when Housing   => if Castle.Actions.Housing_Pull then
                              Label (P, "click, pull its path, click", Ink_Dim);
                              Label (P, "Z, X: " & (case Tools.Rows mod 3 is
                                                       when 0 => "this side",
                                                       when 1 => "the other side",
                                                       when others => "both sides"), Ink_Dim);
                           else
                              Label (P, "click beside a path,", Ink_Dim);
                              Label (P, "then pull along it", Ink_Dim);
                           end if;
         when Unzone    => Label (P, "click the other corner:", Ink_Dim);
                           Label (P, "housing in it is taken out", Ink_Dim);
         when Edit      => null;
      end case;
      if Placing and then Tools.Mode = Edit then
         Gap (P, 0.2);
         Label (P, "Material", Ink_Dim);
         for I in Palette'Range loop
            if Button (P, Pretty (Palette (I)), On => Tools.Pick = I, Width => 62.0) then
               Tools.Pick := I;
            end if;
         end loop;
      end if;
      End_Panel (P);
   end Tools_Panel;

   ---------------------------------------------------------------- ground

   procedure Ground_Panel (W : World; S : Status) is
      H : Castle.World_Blocks.Hit renames S.Cursor;
   begin
      if not H.Found then
         return;
      end if;
      declare
         Xm  : constant Float := (Float (H.X) + 0.5) * 0.25;
         Ym  : constant Float := (Float (H.Y) + 0.5) * 0.25;
         Top : constant Float := Float (H.Z + 1) * 0.25;
         M   : constant Material := Castle.World_Blocks.Block_At (H.X, H.Y, H.Z).Mat;
         Depth, Yield : Float;
         Moist : constant Float := Castle.Fields.Sample (W.Moisture.all, Xm, Ym);
         P : Panel := Begin_Panel (6.0, 6.0, 150.0, Pretty (M), From => Bottom_Left);
      begin
         Castle.Geology.Well_Info (W, Xm, Ym, Depth, Yield);
         Value (P, "At", Img (Xm, 0) & ", " & Img (Ym, 0));
         Value (P, "Height", Img (Top, 2) & " m");
         if Is_Ore (M) then
            Label (P, "Ore", Ink_Strong);
         end if;
         Bar (P, "Well: water at " & Metres (Depth), Yield,
              (if Yield > 0.6 then Bar_Blue elsif Yield > 0.3 then Bar_Amber else Bar_Red),
              (if Yield > 0.6 then "good" elsif Yield > 0.3 then "fair" else "poor"));
         Bar (P, "Moisture", Moist, Bar_Green, Img (Moist * 100.0, 0) & " %");
         End_Panel (P);
      end;
   end Ground_Panel;

   ----------------------------------------------------------------- debug

   procedure Debug_Panel (St : Stats) is
      P : Panel := Begin_Panel (6.0, 6.0, 150.0, "Debug", From => Bottom_Right);
   begin
      Value (P, "Frame rate", Img (St.Fps, 0) & " fps");
      Value (P, "GPU", Img (St.Gpu_Ms, 2) & " ms");
      Value (P, "CPU", Img (St.Cpu_Ms, 2) & " ms (max " & Img (St.Cpu_Max, 1) & ")",
             (if St.Cpu_Max > 33.0 then Ink_Bad else Ink));
      Separator (P);
      Value (P, "Stacks loaded", Img (St.Stacks));
      Value (P, "Quads", Img (Float (St.Quads) / 1.0E6, 2) & " M");
      Value (P, "Streaming", Img (St.Streaming));
      Value (P, "Edits", Img (St.Edits));
      Value (P, "Water awake", Img (St.Awake) & " of" & St.Simulated'Image);
      Value (P, "UI quads", Img (Quad_Count + 1));   --  this line's own count is near enough
      End_Panel (P);
   end Debug_Panel;

   ---------------------------------------------------------------- survey

   procedure Survey_Panel (W : World; S : Status) is
      Show : constant := 10;
      type Pick_List is array (1 .. Show) of Natural;
      Best : Pick_List := [others => 0];
      Dist : array (1 .. Show) of Float := [others => Float'Last];
      Cols : constant Columns :=
        [(56.0, Left), (34.0, Right), (14.0, Centre), (34.0, Right), (24.0, Centre)];
      P : Panel := Begin_Panel (162.0, 6.0, Table_W (Cols) + 10.0, "Survey: nearest deposits");
   begin
      if W.Deposits /= null then
         for K in W.Deposits'Range loop
            declare
               D : constant Float :=
                 Sqrt ((W.Deposits (K).Cx - S.Focus_X) ** 2 + (W.Deposits (K).Cy - S.Focus_Y) ** 2);
            begin
               for I in Best'Range loop
                  if D < Dist (I) then
                     for J in reverse I + 1 .. Show loop
                        Best (J) := Best (J - 1);
                        Dist (J) := Dist (J - 1);
                     end loop;
                     Best (I) := K;
                     Dist (I) := D;
                     exit;
                  end if;
               end loop;
            end;
         end loop;
      end if;
      declare
         T : Table := Begin_Table (P, Cols);
      begin
         Header (T, "Kind");
         Header (T, "Away");
         Header (T, "");
         Header (T, "Ore m3");
         Header (T, "Rich");
         for I in Best'Range loop
            exit when Best (I) = 0;
            declare
               D : Deposit renames W.Deposits (Best (I));
               Rich : constant String :=
                 (if D.Gold_Vol > 0.0 and then D.Silver_Vol > 0.0 then "Ag Au"
                  elsif D.Gold_Vol > 0.0 then "Au"
                  elsif D.Silver_Vol > 0.0 then "Ag" else "-");
            begin
               Cell (T, Kind_Name (D.Kind));
               Cell (T, Img (Dist (I), 0) & " m");
               Cell (T, Compass (D.Cx - S.Focus_X, D.Cy - S.Focus_Y), Ink_Dim);
               Cell (T, Img (D.Reserves, 0));
               Cell (T, Rich, (if Rich = "-" then Ink_Dim else Ink_Strong));
            end;
         end loop;
         End_Table (P, T);
      end;
      Label (P, "Developer view: shows the unfound", Ink_Dim);
      End_Panel (P);
   end Survey_Panel;

   ------------------------------------------------------------------ help

   procedure Help_Panel is
      type Pair is record
         Key, What : access constant String;
      end record;
      K1  : aliased constant String := "W A S D, arrows";   D1  : aliased constant String := "pan";
      K2  : aliased constant String := "Middle drag";        D2  : aliased constant String := "grab the ground";
      K3  : aliased constant String := "Q / E, right drag";  D3  : aliased constant String := "turn";
      K4  : aliased constant String := "R / F, PgUp / PgDn"; D4  : aliased constant String := "tilt";
      K5  : aliased constant String := "Wheel, + / -";       D5  : aliased constant String := "zoom";
      K6  : aliased constant String := "Home";               D6  : aliased constant String := "reset the view";
      K7  : aliased constant String := "[ and ]";            D7  : aliased constant String := "scrub hours";
      K8  : aliased constant String := ", and .";            D8  : aliased constant String := "scrub days";
      K9  : aliased constant String := "Left click";         D9  : aliased constant String := "dig, or the tool in hand";
      K10 : aliased constant String := "Ctrl + left click";  D10 : aliased constant String := "place on the face";
      K11 : aliased constant String := "B / M";              D11 : aliased constant String := "brush size / material";
      K12 : aliased constant String := "F5 / F9";            D12 : aliased constant String := "quick save / load";
      K13 : aliased constant String := "F12";                D13 : aliased constant String := "screenshot";
      K14 : aliased constant String := "F1 F2 F3 / F4";      D14 : aliased constant String := "these panels / hide all";
      K15 : aliased constant String := "F6 / F7 / F8";       D15 : aliased constant String := "routes / walking / wells";
      K16 : aliased constant String := "Space, 1 2 3";       D16 : aliased constant String := "pause, speed";
      K17 : aliased constant String := "Tab";                D17 : aliased constant String := "the band";
      K18 : aliased constant String := "Esc";                D18 : aliased constant String := "cancel; then quit";
      K19 : aliased constant String := "Point at";           D19 : aliased constant String := "a person, zone, deer: what it is";
      K20 : aliased constant String := "Right click";        D20 : aliased constant String := "what you may do with it";
      K21 : aliased constant String := "F10 / F11";          D21 : aliased constant String := "interface smaller / larger";
      K22 : aliased constant String := "H";                  D22 : aliased constant String := "houses open: as looked at / all / none";
      K23 : aliased constant String := "Z / X";              D23 : aliased constant String := "turn what is held to be put down";
      Rows : constant array (1 .. 23) of Pair :=
        [(K1'Access, D1'Access), (K2'Access, D2'Access), (K3'Access, D3'Access), (K4'Access, D4'Access),
         (K5'Access, D5'Access), (K6'Access, D6'Access), (K7'Access, D7'Access), (K8'Access, D8'Access),
         (K9'Access, D9'Access), (K23'Access, D23'Access), (K10'Access, D10'Access), (K11'Access, D11'Access),
         (K12'Access, D12'Access),
         (K13'Access, D13'Access), (K14'Access, D14'Access), (K15'Access, D15'Access), (K22'Access, D22'Access),
         (K16'Access, D16'Access), (K17'Access, D17'Access), (K18'Access, D18'Access),
         (K19'Access, D19'Access), (K20'Access, D20'Access), (K21'Access, D21'Access)];
      Cols : constant Columns := [(92.0, Left), (170.0, Left)];
      Wd   : constant Float := Table_W (Cols) + 10.0;
      P    : Panel := Begin_Panel
        (Float'Max (0.0, Float'Floor ((Screen_W / Scale - Wd) / 2.0)), 40.0, Wd, "Keys");
      T    : Table := Begin_Table (P, Cols);
   begin
      for R of Rows loop
         Cell (T, R.Key.all, Ink_Strong);
         Cell (T, R.What.all);
      end loop;
      End_Table (P, T);
      End_Panel (P);
   end Help_Panel;

   procedure Build
     (W     : World;
      S     : Status;
      St    : Stats;
      Tools : in out Tool_State;
      Show  : Shown) is
   begin
      Row_Hover := 0;
      if Show.Visible then              --  the development panels (F4 hides them)
         Status_Panel (S, Tools);
         Tools_Panel (Tools, S.Place_Held);
         if Show.Band and then Castle.Colony.Has_Stake then
            Band_Panel (S, Tools);      --  under the tools
         end if;
         Ground_Panel (W, S);
         if Show.Debug then
            Debug_Panel (St);
         end if;
         if Show.Survey then
            Survey_Panel (W, S);
         end if;
         if Show.Help then
            Help_Panel;
         end if;
      end if;
      --  the game's own: none of it needs the panels
      Note_Panel (Tools, S.Seconds);
      Tip_Panel (S, (if ((Tools.Mode = Stockpile and then Castle.Colony.Box_Place)
                         or else (Tools.Mode = Stockyard and then Castle.Colony.Yard_Box)
                         or else (Tools.Mode = Stake and then Castle.Actions.Square_Stake
                                  and then not Castle.Colony.Has_Stake)
                         or else (Tools.Mode = Housing and then Castle.Actions.Housing_Pull
                                  and then Tools.Zone_Started))
                       and then not Castle.UI.Wants_Mouse
                     then Str (Tools.Warn) else ""));
      if The_Menu.Open then
         Menu_Popup (Tools);            --  last: over everything
      end if;
      if S.Show_Cursor then
         Pointer (S.Mouse_X, S.Mouse_Y);
      end if;
   end Build;

end Castle.HUD;
