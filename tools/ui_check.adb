--  The interface layer without a window: the font table, text measuring,
--  panel layout, buttons, clicks kept off the world, tables.
--  ./bin/debug/ui_check  (exits 1 on any failure)

with Ada.Text_IO;      use Ada.Text_IO;
with Ada.Command_Line;
with Interfaces;       use Interfaces;
with Castle.Font;
with Castle.Font_Data;
with Castle.UI;        use Castle.UI;
with Castle.Text;      use Castle.Text;
with Castle.Settings;
with Ada.Directories;

procedure UI_Check is
   Failed : Natural := 0;

   procedure Check (Ok : Boolean; What : String) is
   begin
      Put_Line ((if Ok then "  ok    " else "  FAIL  ") & What);
      if not Ok then
         Failed := Failed + 1;
      end if;
   end Check;

   procedure Frame (Mx, My : Float := -1.0; Click : Boolean := False; Scale : Float := 2.0;
                    Wheel : Float := 0.0; Held : Boolean := False; Seconds : Float := 0.0) is
   begin
      Begin_Frame (1280, 720, Mx, My, Click, Scale, Wheel => Wheel, Mouse_Held => Held, Seconds => Seconds);
   end Frame;

   type Scales is array (Positive range <>) of Float;

   function Bottom_Of_Quads (From : Positive) return Float is
      B : Float := 0.0;
   begin
      for I in From .. Quad_Count loop
         B := Float'Max (B, Float (Quad_At (I).Y1));
      end loop;
      return B;
   end Bottom_Of_Quads;

begin
   Put_Line ("font:");
   declare
      use Castle.Font_Data;
      Bad_Ink : Natural := 0;
      Narrow  : Natural := 0;
   begin
      for C in Glyphs'Range loop
         for R in Picture'Range loop
            for K in Glyphs (C).Width + 1 .. Max_W loop
               if Glyphs (C).Pic (R) (K) /= '.' then
                  Bad_Ink := Bad_Ink + 1;
               end if;
            end loop;
         end loop;
         if C /= 32 and then Glyphs (C).Width = 0 then
            Narrow := Narrow + 1;
         end if;
      end loop;
      Check (Bad_Ink = 0, "no ink past a glyph's width");
      Check (Narrow = 0, "every visible glyph has ink columns");
   end;
   Check (Castle.Font.String_Width ("Hi") = 7, "'Hi' is 7 pixels (5 + 1 + 1): " & Img (Castle.Font.String_Width ("Hi")));
   Check (Castle.Font.String_Width ("") = 0, "the empty string has no width");
   Check (Castle.Font.Code_Of (Character'Val (176)) = 127, "the degree sign has its glyph");
   Check (Castle.Font.Code_Of (Character'Val (200)) = Character'Pos ('?'), "other Latin-1 shows as '?'");

   Put_Line ("text:");
   Frame;
   Check (Text_Width ("Hi") = 14.0, "measured at scale 2: " & Img (Text_Width ("Hi"), 0));
   Check (Line_H = 22.0, "a line is 11 pixels times the scale");
   declare
      F : constant String := Fit ("Coal vein outcrop", Text_Width ("Coal vein"));
   begin
      Check (F'Length >= 2 and then F (F'Last - 1 .. F'Last) = ".."
             and then Text_Width (F) <= Text_Width ("Coal vein"), "a long name is cut to fit: """ & F & """");
   end;
   Check (Fit ("short", 1000.0) = "short", "a short one is left alone");
   Begin_Frame (1280, 720, 0.0, 0.0, False);
   Check (Scale = 2.0, "the scale follows the window: 720 px gives 2");
   Begin_Frame (3840, 2160, 0.0, 0.0, False);
   Check (Scale = 5.0, "and 2160 px gives 5");
   End_Frame;

   Put_Line ("panels:");
   declare
      P     : Panel;
      First : Positive;
   begin
      Frame;
      First := Quad_Count + 1;
      P := Begin_Panel (10.0, 10.0, 100.0, "Title");
      Label (P, "one");
      Label (P, "two");
      Value (P, "depth", "3.5 m");
      End_Panel (P);
      End_Frame;
      Check (Float (Quad_At (First).X0) = 20.0 and then Float (Quad_At (First).Y0) = 20.0,
             "placed at its offset times the scale");
      Check (Float (Quad_At (First).Y1) = Bottom_Of_Quads (First),
             "its background reaches the bottom of its contents: " & Img (Float (Quad_At (First).Y1), 0));
      Check (Float (Quad_At (First).Y1) - 20.0 >= 3.0 * Line_H + Line_H,
             "and is tall enough for the title and three lines");
   end;
   Frame (30.0, 30.0);
   Check (Wants_Mouse, "the cursor over last frame's panel keeps the click from the world");
   End_Frame;
   Frame (600.0, 600.0);
   Check (not Wants_Mouse, "elsewhere the world has it");
   End_Frame;

   Put_Line ("buttons:");
   declare
      P      : Panel;
      A, B   : Boolean;
      Bx, By : Float;
   begin
      --  Frame 1: lay out, no click, find where the second button lands.
      Frame;
      P := Begin_Panel (0.0, 0.0, 200.0);
      A := Button (P, "Dig", Width => 40.0);
      B := Button (P, "Place", Width => 40.0);
      End_Panel (P);
      End_Frame;
      Check (not A and then not B, "no click, nothing pressed");
      --  The panel's content starts at Scale + Pad = 2 + 8 = 10; buttons
      --  are 80 px wide with 4 px between, so the second starts at 94.
      Bx := 94.0 + 5.0;
      By := 10.0 + 5.0;
      Frame (Bx, By, Click => True);
      P := Begin_Panel (0.0, 0.0, 200.0);
      A := Button (P, "Dig", Width => 40.0);
      B := Button (P, "Place", Width => 40.0);
      End_Panel (P);
      Check (not A and then B, "a click on the second button of a row presses it alone");
      Check (Click_Taken, "and the click is taken");
      End_Frame;
      Frame (Bx, By + 200.0, Click => True);
      P := Begin_Panel (0.0, 0.0, 200.0);
      A := Button (P, "Dig", Width => 40.0);
      B := Button (P, "Place", Width => 40.0);
      End_Panel (P);
      Check (not A and then not B and then not Click_Taken, "a click below the panel presses nothing");
      End_Frame;
   end;

   Put_Line ("bottom corners:");
   declare
      P : Panel;
      First : Positive;
      Bottom_1, Bottom_2 : Float;
   begin
      for F in 1 .. 2 loop
         Frame;
         First := Quad_Count + 1;
         P := Begin_Panel (8.0, 8.0, 120.0, "Ground", From => Bottom_Right);
         for K in 1 .. 4 + F loop   --  grows a line on the second frame
            Label (P, "line" & K'Image);
         end loop;
         End_Panel (P);
         End_Frame;
         if F = 1 then
            Bottom_1 := Float (Quad_At (First).Y1);
         else
            Bottom_2 := Float (Quad_At (First).Y1);
         end if;
      end loop;
      Check (Bottom_1 = 720.0 - 16.0 and then Bottom_2 = 720.0 - 16.0,
             "a bottom-anchored panel keeps its lower edge as it grows: " & Img (Bottom_1, 0) & ", " & Img (Bottom_2, 0));
      Check (Float (Quad_At (First).X1) = 1280.0 - 16.0, "and its right edge 8 px (times the scale) in");
   end;

   Put_Line ("tables:");
   declare
      P : Panel;
      T : Table (3);
      Before, After : Float;
      First : Positive;
      Stripes : Natural := 0;
   begin
      Frame;
      P := Begin_Panel (0.0, 0.0, 300.0);
      Label (P, "above");
      First := Quad_Count + 1;
      T := Begin_Table (P, [(60.0, Left), (40.0, Right), (40.0, Right)]);
      Before := Bottom_Of_Quads (1);
      Header (T, "Kind");
      Header (T, "Dist");
      Header (T, "Ore");
      for R in 1 .. 4 loop
         Cell (T, "Coal vein, long name");
         Cell (T, Img (R * 10));
         Cell (T, "120");
      end loop;
      End_Table (P, T);
      Label (P, "below");
      End_Panel (P);
      After := Bottom_Of_Quads (First);
      for I in First .. Quad_Count loop
         if Quad_At (I).Top = Unsigned_32 (Row_Stripe) then
            Stripes := Stripes + 1;
         end if;
      end loop;
      End_Frame;
      Check (Stripes = 2, "every other row of four is striped:" & Stripes'Image);
      Check (After - Before >= 5.0 * (Line_H + 2.0), "the table takes a line a row and the header: "
             & Img (After - Before, 0) & " px");
      Check (Table_W ([(60.0, Left), (40.0, Right), (40.0, Right)]) = 152.0, "its width counts the gaps");
   end;

   Put_Line ("tabs:");
   declare
      P       : Panel;
      A, B, C : Boolean;
      Sel     : Positive := 1;
      X2      : Float;
      Lit     : Natural := 0;
      procedure Lay is
      begin
         P := Begin_Panel (0.0, 0.0, 200.0);
         A := Tab (P, "Band", Sel = 1);
         B := Tab (P, "Stores", Sel = 2);
         C := Tab (P, "Camp", Sel = 3);
         End_Tabs (P);
         Label (P, "what the chosen tab holds");
         End_Panel (P);
      end Lay;
   begin
      Frame;
      Lay;
      End_Frame;
      Check (not A and then not B and then not C, "no click, no tab chosen");
      --  content starts at 10; a tab is its name and 20 px wide, 2 px between
      X2 := 10.0 + Text_Width ("Band") + 20.0 + 2.0 + 6.0;
      Frame (X2, 16.0, Click => True);
      Lay;
      Check (not A and then B and then not C and then Click_Taken, "a click on the second tab chooses it alone");
      End_Frame;
      Sel := 2;
      Frame;
      Lay;
      for I in 1 .. Quad_Count loop
         if Quad_At (I).Top = Unsigned_32 (Ink_Strong) and then Quad_At (I).U0 < 0.0
           and then Float (Quad_At (I).X0) >= X2 - 6.0 - 1.0 and then Float (Quad_At (I).Y1 - Quad_At (I).Y0) = 2.0
         then
            Lit := Lit + 1;
         end if;
      end loop;
      End_Frame;
      Check (Lit = 1, "the chosen tab, and only it, is lit along its top");
   end;

   Put_Line ("lists:");
   declare
      P       : Panel;
      L       : List;
      Top     : Natural := 0;
      Hot_Row : Natural := 0;
      First_Q : Positive := 1;
      procedure Lay (Total : Natural) is
      begin
         Hot_Row := 0;
         First_Q := Quad_Count + 1;
         P := Begin_Panel (0.0, 0.0, 200.0);
         L := Begin_List (P, Total, 12, 15.0, Top);
         for K in First (L) .. Last (L) loop
            if Row (P, L, K) then
               Hot_Row := K;
            end if;
            Label (P, "row" & K'Image);
         end loop;
         End_List (P, L);
         End_Panel (P);
      end Lay;
   begin
      Frame;
      Lay (30);
      End_Frame;
      Check (First (L) = 1 and then Last (L) = 12, "30 rows, 12 shown: the first twelve are laid out");
      Check (Float (Quad_At (First_Q).Y1) = 10.0 + 12.0 * 30.0 + 2.0 + 8.0 - 2.0,
             "the list is twelve rows tall whatever is in it: " & Img (Float (Quad_At (First_Q).Y1), 0) & " px");
      Frame (60.0, 100.0, Wheel => -1.0);
      Lay (30);
      Check (First (L) = 3 and then Last (L) = 14 and then Wheel_Taken and then Top = 2,
             "the wheel over it, one step toward the user, scrolls two rows on");
      Check (Hot_Row = 6, "the cursor is on the fourth row shown, row" & Hot_Row'Image);
      End_Frame;
      Frame (60.0, 100.0, Wheel => -20.0);
      Lay (30);
      Check (First (L) = 19 and then Last (L) = 30, "it stops at the end: rows 19 to 30");
      End_Frame;
      Frame (600.0, 600.0, Wheel => 3.0);
      Lay (30);
      Check (First (L) = 19 and then not Wheel_Taken, "the wheel elsewhere leaves it alone (and is the world's)");
      End_Frame;
      --  a touchpad gives parts of a step: they add up
      Top := 0;
      for F in 1 .. 2 loop
         Frame (60.0, 100.0, Wheel => -0.4);
         Lay (30);
         End_Frame;
      end loop;
      Check (Top = 0 and then Wheel_Taken, "0.8 of a wheel step scrolls nothing yet (and is still the list's)");
      Frame (60.0, 100.0, Wheel => -0.4);
      Lay (30);
      Check (Top = 2, "the third 0.4 makes a whole step: two rows on");
      End_Frame;
      Frame (60.0, 100.0, Wheel => 1.2);
      Lay (30);
      Check (Top = 0, "and 1.2 the other way, with the 0.2 kept, comes back a step");
      End_Frame;
      Top := 18;
      --  the bar is the last 10 px of the content, which ends at 390
      Frame (385.0, 12.0, Click => True);
      Lay (30);
      Check (Top = 0 and then Click_Taken, "a click at the top of its bar goes to the start");
      End_Frame;
      Frame (385.0, 10.0 + 360.0 - 3.0, Held => True);
      Lay (30);
      Check (Top = 18, "the button held at the foot of the bar drags it to the end");
      End_Frame;
      Top := 0;
      Frame (60.0, 100.0, Wheel => -1.0);
      Lay (8);
      Check (First (L) = 1 and then Last (L) = 8 and then Top = 0 and then not Wheel_Taken,
             "eight rows all fit: nothing to scroll, and the list is only as tall as they are");
      End_Frame;
   end;

   Put_Line ("tooltips:");
   declare
      P : Panel;
      First_Q : Positive;
      Due : Boolean;
   begin
      Frame (300.0, 300.0, Seconds => 0.1);
      Due := Tip_Due (7);
      End_Frame;
      Check (not Due, "the cursor just arrived on something: no tip yet");
      Frame (300.0, 300.0, Seconds => 0.15);
      Due := Tip_Due (7);
      End_Frame;
      Check (not Due, "nor after 0.15 s");
      Frame (300.0, 300.0, Seconds => 0.15);
      Due := Tip_Due (7);
      End_Frame;
      Check (Due, "after 0.3 s on the same thing, it is due");
      Frame (300.0, 300.0, Seconds => 0.5);
      Due := Tip_Due (8);
      End_Frame;
      Check (not Due, "on to another thing: the wait starts again");
      Frame (300.0, 300.0, Seconds => 0.5);
      End_Frame;                                   --  on nothing for a frame
      Frame (300.0, 300.0, Seconds => 0.1);
      Due := Tip_Due (8);
      End_Frame;
      Check (not Due, "and after a moment on nothing, back on it, again");

      Frame (300.0, 300.0);
      First_Q := Quad_Count + 1;
      P := Begin_Tip (120.0, "Agnes");
      Label (P, "a woman of 40");
      Value (P, "Job", "Cook");
      End_Tip (P);
      End_Frame;
      Check (Float (Quad_At (First_Q).X0) = 328.0 and then Float (Quad_At (First_Q).Y0) = 332.0,
             "a tip is laid out by the cursor, below and to the right of it");
      Frame (340.0, 345.0);
      Check (not Wants_Mouse, "it takes no clicks: the cursor over where it was is still the world's");
      End_Frame;
      for F in 1 .. 2 loop
         Frame (1_270.0, 712.0);
         First_Q := Quad_Count + 1;
         P := Begin_Tip (120.0, "Agnes");
         Label (P, "a woman of 40");
         Value (P, "Job", "Cook");
         End_Tip (P);
         End_Frame;
         Check (Float (Quad_At (First_Q).X1) <= 1_270.0 and then Float (Quad_At (First_Q).Y1) <= 716.0
                and then Float (Quad_At (First_Q).X0) >= 0.0 and then Bottom_Of_Quads (First_Q) <= 716.0,
                (if F = 1 then "in the screen's corner it is kept on the screen, left of the cursor"
                 else "and from the next frame, above it") & ": to "
                & Img (Float (Quad_At (First_Q).X1), 0) & ", " & Img (Float (Quad_At (First_Q).Y1), 0));
      end loop;
   end;

   Put_Line ("context menus:");
   declare
      P, Q : Panel;
      U1, U2, U3, B, C : Boolean;
      First_Q : Positive := 1;
      procedure Lay (Menu_X, Menu_Y : Float; With_Menu : Boolean := True) is
      begin
         P := Begin_Panel (0.0, 0.0, 200.0);
         U1 := Button (P, "Under one");
         U2 := Button (P, "Under two");
         U3 := Button (P, "Under three");
         End_Panel (P);
         B := False;
         C := False;
         if With_Menu then
            First_Q := Quad_Count + 1;
            Q := Begin_Popup (Menu_X, Menu_Y, 100.0, "Agnes");
            B := Button (Q, "Cook");
            C := Button (Q, "Follow");
            End_Popup (Q);
         end if;
      end Lay;
   begin
      Frame;
      Check (not Popup_Shown, "no popup laid out yet");
      Lay (20.0, 0.0);
      End_Frame;
      --  the popup's first button lies over the panel's second (42 .. 70 px down)
      Frame (40.0, 50.0, Click => True);
      Check (Popup_Shown and then Over_Popup and then Wants_Mouse, "a popup opened over a panel: the cursor is on it");
      Lay (20.0, 0.0);
      Check (B and then not C and then not U1 and then not U2 and then not U3,
             "a click on its first choice presses that, and not the button underneath");
      End_Frame;
      Frame (300.0, 20.0, Click => True);
      Check (Popup_Shown and then not Over_Popup, "a click away from it is not on it (whoever opened it closes it)");
      Lay (20.0, 0.0, With_Menu => False);
      Check (U1, "and with it gone the panel's own button takes the click");
      End_Frame;
      Frame;
      Check (not Popup_Shown, "a frame without it: no popup shown");
      End_Frame;
      for F in 1 .. 2 loop
         Frame;
         Lay (1_275.0, 715.0);
         End_Frame;
         Check (Float (Quad_At (First_Q).X1) <= 1_276.0 and then Float (Quad_At (First_Q).Y1) <= 716.0
                and then Bottom_Of_Quads (First_Q) <= 716.0,
                (if F = 1 then "opened in the screen's corner it is moved to fit"
                 else "and stays there the next frame") & ": to "
                & Img (Float (Quad_At (First_Q).X1), 0) & ", " & Img (Float (Quad_At (First_Q).Y1), 0));
      end loop;
   end;

   Put_Line ("columns:");
   declare
      P : Panel;
      First_Q, After_Q : Positive;
      Top_1, Top_2 : Float;
      Right_Edge : Float := 0.0;
      Box : Natural := 0;
   begin
      Frame;
      P := Begin_Panel (0.0, 0.0, 200.0);
      Top_1 := Cursor_Y (P);
      First_Q := Quad_Count + 1;
      Column_Text (P, 60.0, 30.0, "42", Ink, Right);
      After_Q := Quad_Count;
      Top_2 := Cursor_Y (P);
      for I in First_Q .. After_Q loop
         Right_Edge := Float'Max (Right_Edge, Float (Quad_At (I).X1));
      end loop;
      --  content starts at 10; the column is from 130 to 190; the last glyph's shadow runs 2 px past it
      Check (Top_2 = Top_1 and then Right_Edge in 190.0 .. 192.0 and then Float (Quad_At (First_Q).X0) > 150.0,
             "text set right in a column ends at the column's edge, and takes no line (to " & Img (Right_Edge, 0) & ")");
      First_Q := Quad_Count + 1;
      Column_Text (P, 0.0, 30.0, "Gathering and more", Ink);
      Right_Edge := 0.0;
      for I in First_Q .. Quad_Count loop
         Right_Edge := Float'Max (Right_Edge, Float (Quad_At (I).X1));
      end loop;
      Check (Right_Edge <= 10.0 + 60.0 + 2.0, "text too long for its column is cut to it (to " & Img (Right_Edge, 0) & ")");
      First_Q := Quad_Count + 1;
      Column_Text (P, 100.0, 30.0, "7", Ink, Right, Back => Button_Hot);
      for I in First_Q .. Quad_Count loop
         if Quad_At (I).Top = Unsigned_32 (Button_Hot) and then Quad_At (I).U0 < 0.0
           and then Float (Quad_At (I).X1 - Quad_At (I).X0) = 64.0 and then Float (Quad_At (I).Y1 - Quad_At (I).Y0) = 22.0
         then
            Box := Box + 1;
         end if;
      end loop;
      Check (Box = 1, "a column's box lies behind its text, a line high and a pixel wider each side");
      Next_Line (P, 12.0);
      Check (Cursor_Y (P) = Top_1 + 24.0, "the next line is as far down as it is told");
      End_Panel (P);
      End_Frame;
   end;

   Put_Line ("a scale between whole numbers:");
   Check (Nearest_Scale (2.3) = 2.25 and then Nearest_Scale (2.4) = 2.5,
          "a scale is taken to the nearest quarter");
   Check (Nearest_Scale (0.2) = 1.0 and then Nearest_Scale (99.0) = 8.0, "and kept between 1 and 8");
   Check (Next_Scale (2.0, Larger => True) = 2.25 and then Next_Scale (2.0, Larger => False) = 1.75,
          "a step up or down is a quarter");
   Check (Next_Scale (1.0, Larger => False) = 1.0 and then Next_Scale (8.0, Larger => True) = 8.0,
          "and stops at the ends");
   Check (Auto_Scale (720) = 2.0 and then Auto_Scale (1440) = 3.0 and then Auto_Scale (300) = 1.0,
          "left alone, the window's height gives a whole number");
   for S of Scales'(2.25, 2.5, 2.75) loop
      declare
         P       : Panel;
         L       : List;
         Top     : Natural := 3;
         T       : Table (2);
         A, B, Unused_Tab : Boolean;
         Off_Grid, Off_Text, Rims : Natural := 0;
         First   : Positive;
         B_Quad  : Positive := 1;
         Bx, By  : Float := 0.0;
         function Whole (F : Interfaces.IEEE_Float_32) return Boolean is (Float (F) = Float'Floor (Float (F)));
         procedure Lay (Mx, My : Float; Click : Boolean) is
            Unused_Hot : Boolean;
         begin
            Frame (Mx, My, Click => Click, Scale => S);
            First := Quad_Count + 1;
            P := Begin_Panel (7.0, 9.0, 163.0, "Title");
            Label (P, "A line of text, gyp");
            Value (P, "depth", "3.5 m");
            Bar (P, "Fed", 0.37, Val => "37 %");
            Separator (P);
            A := Button (P, "Dig", Width => 41.0);
            B_Quad := Quad_Count + 1;
            B := Button (P, "Place", Width => 41.0);
            Beside (P, "beside");
            Unused_Tab := Tab (P, "Band", On => True);
            Unused_Tab := Tab (P, "Stores", On => False);
            End_Tabs (P);
            L := Begin_List (P, Total => 30, Shown => 6, Row_H => 13.0, Top => Top);
            for K in Castle.UI.First (L) .. Last (L) loop
               Unused_Hot := Row (P, L, K);
               Column_Text (P, 0.0, 60.0, "row" & K'Image, Back => Button_On);
               Column_Text (P, 64.0, 30.0, "12 %", Al => Right, Drop => 1.0);
            end loop;
            End_List (P, L);
            T := Begin_Table (P, [(60.0, Left), (40.0, Right)]);
            Header (T, "Kind");  Header (T, "Stored");
            Cell (T, "berries"); Cell (T, "120");
            Cell (T, "wood");    Cell (T, "7");
            End_Table (P, T);
            End_Panel (P);
            Outline (301.3, 207.7, 40.2, 33.3, Ink);
         end Lay;
      begin
         Lay (-1.0, -1.0, False);
         Check (Scale = S, "the scale is as set:" & Img (Scale, 2));
         for I in First .. Quad_Count loop
            declare
               Q : constant Quad := Quad_At (I);
            begin
               if Float (Q.U0) < 0.0 then
                  if not (Whole (Q.X0) and then Whole (Q.Y0) and then Whole (Q.X1) and then Whole (Q.Y1)) then
                     Off_Grid := Off_Grid + 1;
                  end if;
               elsif not (Whole (Q.X0) and then Whole (Q.Y0)) then
                  Off_Text := Off_Text + 1;
               end if;
            end;
         end loop;
         Check (Off_Grid = 0, "every box and rule lies on whole pixels (" & Img (Quad_Count - First + 1) & " quads)");
         Check (Off_Text = 0, "and every glyph starts on one");
         Check (Line_H = Float'Floor (Line_H), "a line of text is a whole number of pixels: " & Img (Line_H, 0));
         --  the rim: the background lies the same whole pixels inside the edge on every side
         declare
            Edge : constant Quad := Quad_At (First);
            Back : constant Quad := Quad_At (First + 1);
            Rim  : constant Float := Float (Back.X0) - Float (Edge.X0);
         begin
            if Rim >= 1.0 and then Float (Back.Y0) - Float (Edge.Y0) = Rim
              and then Float (Edge.X1) - Float (Back.X1) = Rim and then Float (Edge.Y1) - Float (Back.Y1) = Rim
            then
               Rims := 1;
            end if;
            Check (Rims = 1, "the panel's rim is as thick on every side: " & Img (Rim, 0) & " px");
         end;
         --  the outline drawn last: four rules that meet at the corners
         declare
            Qt : constant Quad := Quad_At (Quad_Count - 3);
            Qb : constant Quad := Quad_At (Quad_Count - 2);
            Ql : constant Quad := Quad_At (Quad_Count - 1);
            Qr : constant Quad := Quad_At (Quad_Count);
         begin
            Check (Qt.Y1 = Ql.Y0 and then Ql.Y1 = Qb.Y0 and then Qt.X0 = Ql.X0 and then Qt.X1 = Qr.X1
                   and then Qt.Y1 - Qt.Y0 = Ql.X1 - Ql.X0 and then Qb.Y1 - Qb.Y0 = Qr.X1 - Qr.X0,
                   "an outline's four rules meet and are one thickness");
         end;
         End_Frame;
         --  the second button, wherever this scale put it: it is pressed
         --  where it is drawn, to the pixel
         Bx := Float (Quad_At (B_Quad).X0);
         By := Float (Quad_At (B_Quad).Y0);
         Lay (Bx, By, True);
         Check (Bx > 0.0 and then B and then not A and then Click_Taken,
                "a click on the corner of the second button presses it alone (at" & Img (Bx, 0) & "," & Img (By, 0) & ")");
         End_Frame;
         Lay (Bx - 1.0, By, True);
         Check (not B, "and a pixel to its left does not");
         End_Frame;
         Lay (Bx, By - 1.0, True);
         Check (not B and then not A, "nor a pixel above it");
         End_Frame;
         --  what just fits at Scale 1 fits here too, whatever the rounding does
         declare
            Q         : Panel;
            D1, D2, D3, D4 : Positive;
            Unused    : Boolean;
            Tight     : constant String := "F1 keys  F2 survey  F3 debug";
         begin
            Frame (Scale => S);
            Q := Begin_Panel (6.0, 6.0, 136.0, "Tools");               --  126 inside: 62 + 2 + 62
            D1 := Quad_Count + 1;
            Unused := Button (Q, "Dig", Width => 62.0);
            D2 := Quad_Count + 1;
            Unused := Button (Q, "Place", Width => 62.0);
            Check (Quad_At (D2).Y0 = Quad_At (D1).Y0 and then Quad_At (D2).X0 > Quad_At (D1).X1,
                   "two buttons that just fill a line at Scale 1 share it here");
            D3 := Quad_Count + 1;
            Unused := Button (Q, "One", Width => 62.0);
            D4 := Quad_Count + 1;
            Unused := Button (Q, "Two too many", Width => 63.0);
            Check (Quad_At (D3).Y0 > Quad_At (D2).Y0 and then Quad_At (D4).Y0 > Quad_At (D3).Y0
                   and then Quad_At (D4).X0 = Quad_At (D1).X0,
                   "and one a pixel too wide for it goes to the next, as at Scale 1");
            End_Panel (Q);
            Q := Begin_Panel (6.0, 200.0, Float (Castle.Font.String_Width (Tight)) + 10.0);
            Check (Fit (Tight, Inner_W (Q)) = Tight, "a line of text that just fits its panel at Scale 1 is not cut");
            Check (Fit (Tight & "g", Inner_W (Q)) /= Tight & "g", "and one a letter longer is");
            End_Panel (Q);
            End_Frame;
         end;
      end;
   end loop;

   Put_Line ("settings:");
   declare
      use Castle.Settings;
      Path : constant String := "/tmp/ui_check_settings.txt";
      Ok   : Boolean;
      F    : Ada.Text_IO.File_Type;
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_File (Path);
      end if;
      Load (Path);
      Check (not Has ("ui_scale") and then Get ("ui_scale", 0.0) = 0.0, "no file: nothing is set, and the default is given");
      Set ("ui_scale", 2.25);
      Save (Path, Ok);
      Check (Ok, "a setting is written");
      Set ("ui_scale", 5.0);
      Load (Path);
      Check (Has ("ui_scale") and then Get ("ui_scale", 0.0) = 2.25, "and read back: " & Img (Get ("ui_scale", 0.0), 2));
      Create (F, Out_File, Path);
      Put_Line (F, "ui_scale 2.5");
      Put_Line (F, "something_newer on and off");
      Put_Line (F, "volume loud");
      Close (F);
      Load (Path);
      Check (Get ("volume", 0.7) = 0.7, "a value that is no number gives the default");
      Set ("ui_scale", 3.0);
      Save (Path, Ok);
      Load (Path);
      Open (F, In_File, Path);
      declare
         L1 : constant String := Get_Line (F);
         L2 : constant String := Get_Line (F);
      begin
         Check (L1 = "ui_scale 3.00" and then L2 = "something_newer on and off",
                "a line it does not know is kept as it was: """ & L2 & """");
      end;
      Close (F);
      Ada.Directories.Delete_File (Path);
   end;

   Put_Line ("capacity:");
   Frame;
   for I in 1 .. 20_000 loop
      Rect (0.0, 0.0, 1.0, 1.0, Ink);
   end loop;
   Check (Quad_Count = 16_384 and then Dropped = 20_000 - 16_384, "past 16,384 quads the rest are dropped, counted");
   End_Frame;

   if Failed = 0 then
      Put_Line ("all checks passed");
   else
      Put_Line (Img (Failed) & " checks FAILED");
      Ada.Command_Line.Set_Exit_Status (1);
   end if;
end UI_Check;
