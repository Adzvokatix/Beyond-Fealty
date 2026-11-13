with Ada.Characters.Latin_1;
with Interfaces.C;         use Interfaces.C;
with Interfaces.C.Strings; use Interfaces.C.Strings;
with System;
with Castle.GL;            use Castle.GL;
with Castle.Font;

package body Castle.UI is

   use Interfaces;
   LF : constant Character := Ada.Characters.Latin_1.LF;

   Capacity  : constant := 16_384;      --  quads a frame
   Max_Boxes : constant := 64;          --  panels a frame

   type Quad_Array is array (1 .. Capacity) of aliased Quad;
   Quads     : Quad_Array;
   Count     : Natural := 0;
   Lost      : Natural := 0;

   type Box is record
      X, Y, W, H : Float := 0.0;
   end record;
   type Box_Array is array (1 .. Max_Boxes) of Box;
   Boxes, Prev_Boxes : Box_Array;
   Box_N, Prev_Box_N : Natural := 0;
   Heights           : array (1 .. Max_Boxes) of Float := [others => 0.0];   --  last frame's, by order

   S_V      : Float := 1.0;      --  the scale: a whole number, or one in steps of Scale_Step
   Whole    : Boolean := True;   --  it is a whole number: text is drawn texel for pixel
   W_Px     : Float := 0.0;
   H_Px     : Float := 0.0;
   Mx, My   : Float := -1.0;
   Click    : Boolean := False;
   Taken    : Boolean := False;
   Over     : Boolean := False;
   Held     : Boolean := False;
   Wheel_V  : Float := 0.0;
   Wheel_Used : Boolean := False;
   Wheel_Carry : Float := 0.0;      --  part of a wheel step not yet scrolled
   Dt       : Float := 0.0;

   --  the tooltip: what the cursor rests on, for how long, and how tall the tip was
   Tip_Key   : Natural := 0;
   Tip_Wait  : Float := 0.0;
   Tip_Asked : Boolean := False;
   Tip_H     : Float := 0.0;

   --  the popup, as laid out last frame and this
   type Popup_Box is record
      Live : Boolean := False;
      B    : Box;
   end record;
   Popup_Prev, Popup_Now : Popup_Box;
   Popup_H : Float := 0.0;

   function Sf return Float is (S_V);
   function Snap (F : Float) return Float is (Float'Floor (F + 0.5));

   --  N pixels at Scale 1, as whole pixels of the screen.  Everything is
   --  laid out in these, so at a scale that is not a whole number the
   --  boxes, the rules and the lines of text still lie on the pixel grid.
   --  (At a whole scale it is N times the scale, as it always was.)
   function Pix (N : Float) return Float is (Snap (N * S_V));
   --  A rim or a rule: one pixel at Scale 1, and never less than one of the screen's.
   function Hair return Float is (Float'Max (1.0, Snap (S_V)));

   ---------------------------------------------------------------- colours

   function RGBA (R, G, B : Natural; A : Natural := 255) return Color is
     (Color (Natural'Min (R, 255)) or Color (Natural'Min (G, 255)) * 2 ** 8
      or Color (Natural'Min (B, 255)) * 2 ** 16 or Color (Natural'Min (A, 255)) * 2 ** 24);

   function With_Alpha (C : Color; A : Natural) return Color is
     ((C and 16#00FF_FFFF#) or Color (Natural'Min (A, 255)) * 2 ** 24);

   ----------------------------------------------------------------- frames

   procedure Begin_Frame
     (Width, Height    : Natural;
      Mouse_X, Mouse_Y : Float;
      Mouse_Clicked    : Boolean;
      Fixed_Scale      : Float := 0.0;
      Wheel            : Float := 0.0;
      Mouse_Held       : Boolean := False;
      Seconds          : Float := 0.0) is
   begin
      Wheel_V := Wheel;
      Wheel_Used := False;
      Held := Mouse_Held or else Mouse_Clicked;
      Dt := Float'Max (0.0, Seconds);
      Tip_Asked := False;
      Popup_Prev := Popup_Now;
      Popup_Now.Live := False;
      W_Px := Float (Width);
      H_Px := Float (Height);
      S_V  := (if Fixed_Scale > 0.0 then Nearest_Scale (Fixed_Scale) else Auto_Scale (Height));
      Whole := S_V = Float'Floor (S_V);
      Mx := Mouse_X;
      My := Mouse_Y;
      Click := Mouse_Clicked;
      Taken := False;
      Count := 0;
      Lost  := 0;
      Over  := False;
      for I in 1 .. Prev_Box_N loop
         declare
            B : Box renames Prev_Boxes (I);
         begin
            if Mx >= B.X and then Mx < B.X + B.W and then My >= B.Y and then My < B.Y + B.H then
               Over := True;
            end if;
         end;
      end loop;
      Box_N := 0;
   end Begin_Frame;

   procedure End_Frame is
   begin
      Prev_Boxes := Boxes;
      Prev_Box_N := Box_N;
      if not Tip_Asked then            --  the cursor is on nothing that has a tip
         Tip_Key := 0;
         Tip_Wait := 0.0;
      end if;
   end End_Frame;

   function Scale return Float is (S_V);
   function Auto_Scale (Height : Natural) return Float is
     (Float (Positive'Max (1, Integer (Float (Height) / 450.0))));
   function Nearest_Scale (S : Float) return Float is
     (Float'Max (Scale_Min, Float'Min (Scale_Max, Float'Rounding (S / Scale_Step) * Scale_Step)));
   function Next_Scale (S : Float; Larger : Boolean) return Float is
     (Nearest_Scale (Nearest_Scale (S) + (if Larger then Scale_Step else -Scale_Step)));
   function Screen_W return Float is (W_Px);
   function Screen_H return Float is (H_Px);
   function Wants_Mouse return Boolean is (Over);
   function Click_Taken return Boolean is (Taken);
   function Wheel_Taken return Boolean is (Wheel_Used);

   function Inside (B : Box) return Boolean is
     (Mx >= B.X and then Mx < B.X + B.W and then My >= B.Y and then My < B.Y + B.H);

   function Popup_Shown return Boolean is (Popup_Prev.Live);
   function Over_Popup return Boolean is (Popup_Prev.Live and then Inside (Popup_Prev.B));

   function Quad_Count return Natural is (Count);
   function Quad_At (I : Positive) return Quad is (Quads (I));
   function Dropped return Natural is (Lost);

   ------------------------------------------------------------- primitives

   function F32 (F : Float) return IEEE_Float_32 is (IEEE_Float_32 (F));

   procedure Push (X0, Y0, X1, Y1, U0, V0, U1, V1 : Float; Top, Bottom : Color) is
   begin
      if Count = Capacity then
         Lost := Lost + 1;
         return;
      end if;
      Count := Count + 1;
      Quads (Count) := (F32 (X0), F32 (Y0), F32 (X1), F32 (Y1),
                        F32 (U0), F32 (V0), F32 (U1), F32 (V1),
                        Unsigned_32 (Top), Unsigned_32 (Bottom), 0, 0);
   end Push;

   procedure Gradient (X, Y, W, H : Float; Top, Bottom : Color) is
   begin
      if W > 0.0 and then H > 0.0 then
         Push (Snap (X), Snap (Y), Snap (X + W), Snap (Y + H), -1.0, 0.0, 0.0, 0.0, Top, Bottom);
      end if;
   end Gradient;

   procedure Rect (X, Y, W, H : Float; C : Color) is
   begin
      Gradient (X, Y, W, H, C, C);
   end Rect;

   procedure Outline (X, Y, W, H : Float; C : Color) is
      T  : constant Float := Hair;
      X0 : constant Float := Snap (X);
      Y0 : constant Float := Snap (Y);
      X1 : constant Float := Snap (X + W);
      Y1 : constant Float := Snap (Y + H);
   begin
      Rect (X0, Y0, X1 - X0, T, C);
      Rect (X0, Y1 - T, X1 - X0, T, C);
      Rect (X0, Y0 + T, T, Y1 - Y0 - 2.0 * T, C);
      Rect (X1 - T, Y0 + T, T, Y1 - Y0 - 2.0 * T, C);
   end Outline;

   function Line_H (Size : Positive := 1) return Float is
     (Pix (Float (Castle.Font.Line_H * Size)));

   function Text_Width (S : String; Size : Positive := 1) return Float is
     (Float (Castle.Font.String_Width (S)) * Sf * Float (Size));

   --  At a whole scale, to the pixel.  Between, a box's width has been
   --  rounded to whole pixels, so it is measured at Scale 1 with half a
   --  pixel's grace: what fits at one scale fits at them all.
   function Fits (S : String; Width : Float; Size : Positive) return Boolean is
     (if Whole then Text_Width (S, Size) <= Width
      else Float (Castle.Font.String_Width (S) * Size) <= Width / S_V + 0.5);

   function Fit (S : String; Width : Float; Size : Positive := 1) return String is
   begin
      if Fits (S, Width, Size) then
         return S;
      end if;
      for Last in reverse S'First .. S'Last - 1 loop
         if Fits (S (S'First .. Last) & "..", Width, Size) then
            return S (S'First .. Last) & "..";
         end if;
      end loop;
      return "";
   end Fit;

   procedure Text
     (X, Y  : Float;
      S     : String;
      C     : Color    := Ink;
      Size  : Positive := 1;
      Shade : Boolean  := True)
   is
      K  : constant Float := Sf * Float (Size);
      Sh : constant Float := Float'Max (1.0, Snap (K));   --  the shadow's offset: whole pixels
      --  at a scale that is not whole a glyph's quad takes in half of the
      --  empty texel past its ink, for its edge to fade out over (the shader)
      Ex : constant Float := (if Whole then 0.0 else 0.5);
      Px : Float := Snap (X);
      Py : constant Float := Snap (Snap (Y) + K);   --  one pixel of the line above the glyphs
   begin
      for Ch of S loop
         declare
            use Castle.Font;
            G  : constant Code := Code_Of (Ch);
            Gw : constant Float := Float (Width (G));
            U  : constant Float := Float (Cell_X (G));
            V  : constant Float := Float (Cell_Y (G));
         begin
            if G /= 32 and then Gw > 0.0 then
               declare
                  Gx : constant Float := Snap (Px);   --  every glyph starts on a pixel
                  Qw : constant Float := (Gw + Ex) * K;
                  Qh : constant Float := (Float (Glyph_H) + Ex) * K;
               begin
                  if Shade then
                     Push (Gx + Sh, Py + Sh, Gx + Sh + Qw, Py + Sh + Qh,
                           U, V, U + Gw + Ex, V + Float (Glyph_H) + Ex, Shadow, Shadow);
                  end if;
                  Push (Gx, Py, Gx + Qw, Py + Qh, U, V, U + Gw + Ex, V + Float (Glyph_H) + Ex, C, C);
               end;
            end if;
            Px := Px + Float (Advance (G)) * K;
         end;
      end loop;
   end Text;

   procedure Aligned (X, Y, W : Float; S : String; C : Color; Al : Align) is
      Tw : constant Float := Text_Width (S);
   begin
      case Al is
         when Left   => Text (X, Y, S, C);
         when Centre => Text (X + Float'Floor ((W - Tw) / 2.0), Y, S, C);
         when Right  => Text (X + W - Tw, Y, S, C);
      end case;
   end Aligned;

   ----------------------------------------------------------------- panels

   Pad_U : constant := 4.0;     --  a panel's padding, pixels at Scale 1

   function Content_X (P : Panel) return Float is (P.X + Hair + P.Pad);
   function Inner_W (P : Panel) return Float is (P.W - 2.0 * (Hair + P.Pad));
   --  The same at Scale 1.  What shares a line (a run of buttons, the tabs)
   --  is fitted by this, so a row breaks in the same place at every scale
   --  whatever the rounding to whole pixels does to its pieces.
   function Inner_U (P : Panel) return Float is (P.W_U - 2.0 * (1.0 + Pad_U));
   Fit_Slack : constant := 0.25;
   function Cursor_Y (P : Panel) return Float is (P.Cursor);

   procedure End_Run (P : in out Panel) is
   begin
      P.Line_X := 0.0;
      P.Line_U := 0.0;
   end End_Run;

   --  The cursor is on the popup, which is over this panel: nothing in the
   --  panel is under the cursor then.
   function Covered (P : Panel) return Boolean is (P.Kind /= Popup and then Over_Popup);

   --  A panel's frame at a place in pixels: the rim, the background (both
   --  sized at End_Panel), the title.
   procedure Open (P : in out Panel; Title : String) is
   begin
      P.First_Quad := Count + 1;
      Push (P.X, P.Y, P.X + P.W, P.Y, -1.0, 0.0, 0.0, 0.0,
            (if P.Kind = Tip then Tip_Edge else Panel_Edge), (if P.Kind = Tip then Tip_Edge else Panel_Edge));
      P.Back_Quad := Count + 1;
      Push (P.X + Hair, P.Y + Hair, P.X + P.W - Hair, P.Y + Hair, -1.0, 0.0, 0.0, 0.0, Panel_Top, Panel_Foot);
      if Title /= "" then
         Rect (P.X + Hair, P.Y + Hair, P.W - 2.0 * Hair, Line_H + Pix (3.0), Title_Back);
         Rect (P.X + Hair, P.Y + Line_H + Pix (4.0), P.W - 2.0 * Hair, Hair, With_Alpha (Panel_Edge, 160));
         Text (Content_X (P), P.Y + Pix (2.0), Fit (Title, Inner_W (P)), Ink_Strong);
         P.Cursor := P.Y + Line_H + Pix (5.0) + P.Pad;
      else
         P.Cursor := P.Y + Hair + P.Pad;
      end if;
   end Open;

   function Begin_Panel
     (X, Y  : Float;
      W     : Float;
      Title : String  := "";
      From  : Anchor  := Top_Left;
      Min_H : Float   := 0.0) return Panel
   is
      P : Panel;
   begin
      Box_N := Box_N + 1;
      P.Box_Index := Box_N;
      P.From  := From;
      P.W     := Snap (W * Sf);
      P.W_U   := W;
      P.Pad   := Pix (Pad_U);
      P.Min_H := Pix (Min_H);
      P.X := (case From is
                 when Top_Left | Bottom_Left   => Snap (X * Sf),
                 when Top_Right | Bottom_Right => W_Px - Snap (X * Sf) - P.W);
      P.Bottom := H_Px - Snap (Y * Sf);
      P.Y := (case From is
                 when Top_Left | Top_Right => Snap (Y * Sf),
                 when Bottom_Left | Bottom_Right =>
                    P.Bottom - Float'Max (P.Min_H, (if Box_N <= Max_Boxes then Heights (Box_N) else 0.0)));
      Open (P, Title);
      return P;
   end Begin_Panel;

   Last_Bottom_Px : Float := 0.0;
   function Last_Bottom return Float is (Last_Bottom_Px / S_V);

   procedure End_Panel (P : in out Panel) is
      H : constant Float := Float'Max (P.Min_H, Snap (P.Cursor - P.Y + P.Pad - Hair));
   begin
      End_Run (P);
      if P.First_Quad <= Count then
         Quads (P.First_Quad).Y1 := F32 (P.Y + H);
      end if;
      if P.Back_Quad <= Count then
         Quads (P.Back_Quad).Y1 := F32 (P.Y + H - Hair);
      end if;
      if P.From in Bottom_Left | Bottom_Right and then P.Y + H /= P.Bottom then
         declare
            Move : constant Float := P.Bottom - (P.Y + H);   --  placed by last frame's height
            M    : constant IEEE_Float_32 := F32 (Move);
         begin
            for I in P.First_Quad .. Count loop
               Quads (I).Y0 := Quads (I).Y0 + M;
               Quads (I).Y1 := Quads (I).Y1 + M;
            end loop;
            P.Y := P.Y + Move;
         end;
      end if;
      if P.Kind /= Fixed then
         --  by the cursor, or where it was opened: if it runs off the foot
         --  of the screen (its height was not known when it was placed),
         --  it is moved up
         declare
            Over_Foot : constant Float := P.Y + H - (H_Px - Pix (2.0));
            Move      : constant Float := (if Over_Foot > 0.0 then -Float'Min (Over_Foot, P.Y - Pix (2.0)) else 0.0);
            M         : constant IEEE_Float_32 := F32 (Move);
         begin
            if Move /= 0.0 then
               for I in P.First_Quad .. Count loop
                  Quads (I).Y0 := Quads (I).Y0 + M;
                  Quads (I).Y1 := Quads (I).Y1 + M;
               end loop;
               P.Y := P.Y + Move;
            end if;
         end;
      end if;
      case P.Kind is
         when Tip =>
            Tip_H := H;                          --  not a box: it takes no clicks
         when Popup =>
            Popup_H := H;
            Popup_Now := (Live => True, B => (P.X, P.Y, P.W, H));
            if P.Box_Index in 1 .. Max_Boxes then
               Boxes (P.Box_Index) := (P.X, P.Y, P.W, H);
            end if;
         when Fixed =>
            if P.Box_Index <= Max_Boxes then
               Boxes (P.Box_Index) := (P.X, P.Y, P.W, H);
               Heights (P.Box_Index) := H;
            end if;
            Last_Bottom_Px := P.Y + H;
      end case;
   end End_Panel;

   procedure Label (P : in out Panel; S : String; C : Color := Ink; Al : Align := Left) is
   begin
      End_Run (P);
      Aligned (Content_X (P), P.Cursor, Inner_W (P), Fit (S, Inner_W (P)), C, Al);
      P.Cursor := P.Cursor + Line_H;
   end Label;

   procedure Heading (P : in out Panel; S : String) is
   begin
      Label (P, S, Ink_Strong);
   end Heading;

   procedure Value (P : in out Panel; Name, Val : String; C : Color := Ink) is
      Vw : constant Float := Text_Width (Val);
   begin
      End_Run (P);
      Text (Content_X (P), P.Cursor, Fit (Name, Inner_W (P) - Vw - Pix (4.0)), Ink_Dim);
      Text (Content_X (P) + Inner_W (P) - Vw, P.Cursor, Val, C);
      P.Cursor := P.Cursor + Line_H;
   end Value;

   procedure Bar
     (P        : in out Panel;
      Name     : String;
      Fraction : Float;
      Fill     : Color  := Bar_Green;
      Val      : String := "")
   is
      F  : constant Float := Float'Max (0.0, Float'Min (1.0, Fraction));
      Bw : constant Float := Inner_W (P);
      Y  : Float;
   begin
      Value (P, Name, Val);
      Y := P.Cursor;
      Rect (Content_X (P), Y, Bw, Pix (4.0), Bar_Back);
      Gradient (Content_X (P), Y, Snap (Bw * F), Pix (4.0), Fill, With_Alpha (Fill, 150));
      Rect (Content_X (P), Y, Snap (Bw * F), Hair, With_Alpha (16#FFFFFFFF#, 60));   --  a highlight along the top
      P.Cursor := P.Cursor + Pix (7.0);
   end Bar;

   procedure Gap (P : in out Panel; Lines : Float := 0.5) is
   begin
      End_Run (P);
      P.Cursor := P.Cursor + Snap (Lines * Line_H);
   end Gap;

   procedure Separator (P : in out Panel) is
   begin
      End_Run (P);
      Rect (Content_X (P), P.Cursor + Pix (2.0), Inner_W (P), Hair, With_Alpha (Panel_Edge, 140));
      P.Cursor := P.Cursor + Pix (5.0);
   end Separator;

   function Button
     (P     : in out Panel;
      Text  : String;
      On    : Boolean := False;
      Width : Float   := 0.0) return Boolean
   is
      Bh : constant Float := Line_H + Pix (3.0);
      Bw : constant Float := (if Width > 0.0 then Float'Min (Snap (Width * Sf), Inner_W (P)) else Inner_W (P));
      Bw_U : constant Float := (if Width > 0.0 then Float'Min (Width, Inner_U (P)) else Inner_U (P));
      X, Y : Float;
   begin
      if Width > 0.0 and then P.Line_X > 0.0
        and then P.Line_U + Bw_U <= Inner_U (P) + Fit_Slack
      then
         X := P.Line_X;
         Y := P.Line_Top;
      else
         End_Run (P);
         X := Content_X (P);
         Y := P.Cursor;
         P.Line_Top := Y;
      end if;
      declare
         Hot : constant Boolean := Mx >= X and then Mx < X + Bw and then My >= Y and then My < Y + Bh
           and then not Covered (P);
         Hit : constant Boolean := Hot and then Click and then not Taken;
      begin
         Rect (X, Y, Bw, Bh, (if On then Button_On elsif Hot then Button_Hot else Button_Back));
         Rect (X, Y, Bw, Hair, With_Alpha (16#FFFFFFFF#, (if Hot then 50 else 28)));
         Rect (X, Y + Bh - Hair, Bw, Hair, With_Alpha (16#FF000000#, 90));
         Aligned (X, Y + Pix (1.5), Bw, Fit (Text, Bw - Pix (2.0)), (if On then Ink_Strong else Ink), Centre);
         if Hit then
            Taken := True;
         end if;
         if Width > 0.0 then
            P.Line_X := X + Bw + Pix (2.0);
            P.Line_U := P.Line_U + Bw_U + 2.0;
         end if;
         P.Line_Bottom := Y + Bh + Pix (2.0);
         P.Cursor := P.Line_Bottom;
         return Hit;
      end;
   end Button;

   procedure Same_Line_End (P : in out Panel) is
   begin
      End_Run (P);
   end Same_Line_End;

   procedure Beside (P : in out Panel; S : String; C : Color := Ink) is
      X    : constant Float := (if P.Line_X > 0.0 then P.Line_X + Pix (2.0) else Content_X (P));
      Room : constant Float := Content_X (P) + Inner_W (P) - X;
   begin
      if Room > 0.0 then
         Text (X, P.Line_Top + Pix (1.5), Fit (S, Room), C);
      end if;
   end Beside;

   procedure Column_Text
     (P    : in out Panel;
      X, W : Float;
      S    : String;
      C    : Color := Ink;
      Al   : Align := Left;
      Drop : Float := 0.0;
      Back : Color := 0)
   is
      Cx : constant Float := Content_X (P) + Pix (X);
      Cw : constant Float := Float'Min (Pix (W), Content_X (P) + Inner_W (P) - Cx);
      Cy : constant Float := P.Cursor + Pix (Drop);
   begin
      End_Run (P);
      if Cw <= 0.0 then
         return;
      end if;
      if Back /= 0 then
         Rect (Cx - Hair, Cy, Cw + 2.0 * Hair, Pix (Column_H), Back);
      end if;
      Aligned (Cx, Cy, Cw, Fit (S, Cw), C, Al);
   end Column_Text;

   procedure Next_Line (P : in out Panel; H : Float := 11.0) is
   begin
      End_Run (P);
      P.Cursor := P.Cursor + Pix (H);
   end Next_Line;

   ------------------------------------------------------------------- tabs

   function Tab (P : in out Panel; Text : String; On : Boolean) return Boolean is
      Th : constant Float := Line_H + Pix (4.0);
      Tw : constant Float := Snap (Text_Width (Text)) + Pix (10.0);
      Tw_U : constant Float := Float (Castle.Font.String_Width (Text)) + 10.0;
      X, Y : Float;
   begin
      if P.Line_X > 0.0 and then P.Line_U + Tw_U <= Inner_U (P) + Fit_Slack then
         X := P.Line_X;
         Y := P.Line_Top;
      else
         End_Run (P);
         X := Content_X (P);
         Y := P.Cursor;
         P.Line_Top := Y;
      end if;
      declare
         Hot : constant Boolean := Mx >= X and then Mx < X + Tw and then My >= Y and then My < Y + Th
           and then not Covered (P);
         Hit : constant Boolean := Hot and then Click and then not Taken;
      begin
         Rect (X, Y, Tw, Th, (if On then Button_On elsif Hot then Button_Hot else Tab_Back));
         if On then
            Rect (X, Y, Tw, Hair, Ink_Strong);                --  lit along its top
         end if;
         Aligned (X, Y + Pix (2.0), Tw, Text, (if On then Ink_Strong elsif Hot then Ink else Ink_Dim), Centre);
         if Hit then
            Taken := True;
         end if;
         P.Line_X := X + Tw + Hair;
         P.Line_U := P.Line_U + Tw_U + 1.0;
         P.Line_Bottom := Y + Th;
         P.Cursor := P.Line_Bottom;
         return Hit;
      end;
   end Tab;

   procedure End_Tabs (P : in out Panel) is
   begin
      End_Run (P);
      Rect (Content_X (P), P.Cursor, Inner_W (P), Hair, Button_On);
      P.Cursor := P.Cursor + Pix (4.0);
   end End_Tabs;

   ------------------------------------------------------------------ lists

   Bar_W : constant := 5.0;     --  the scroll bar, pixels at Scale 1

   function First (L : List) return Positive is (L.First);
   function Last (L : List) return Natural is (L.Last);

   function Begin_List
     (P     : in out Panel;
      Total : Natural;
      Shown : Positive;
      Row_H : Float;
      Top   : in out Natural) return List
   is
      L       : List;
      Vis     : constant Natural := Natural'Min (Total, Shown);
      Max_Top : constant Natural := Total - Vis;
      Rh      : constant Float := Pix (Row_H);
      H       : constant Float := Float (Vis) * Rh;
   begin
      End_Run (P);
      Top := Natural'Min (Top, Max_Top);
      L.X := Content_X (P);
      L.Y := P.Cursor;
      L.Row_H := Rh;
      L.Panel_W := P.W;
      L.Panel_U := P.W_U;
      L.W := Inner_W (P);
      if Max_Top > 0 then
         declare
            Bw      : constant Float := Pix (Bar_W);
            Bx      : constant Float := L.X + L.W - Bw;
            Thumb_H : constant Float := Float'Max (Pix (8.0), Snap (H * Float (Vis) / Float (Total)));
            Over_It : constant Boolean :=
              Mx >= L.X and then Mx < L.X + L.W and then My >= L.Y and then My < L.Y + H and then not Covered (P);
            On_Bar  : constant Boolean := Over_It and then Mx >= Bx - Pix (3.0);
         begin
            if Over_It and then Wheel_V /= 0.0 then
               --  whole steps scroll; a part of one (a touchpad gives them)
               --  is kept till the rest of it comes
               Wheel_Carry := Wheel_Carry + Wheel_V;
               declare
                  Steps : constant Integer := Integer (Float'Truncation (Wheel_Carry));
               begin
                  Wheel_Carry := Wheel_Carry - Float (Steps);
                  Top := Integer'Max (0, Integer'Min (Max_Top, Top - Steps * Wheel_Rows));
                  Wheel_Used := True;               --  over a list the wheel is the list's
               end;
            end if;
            if On_Bar and then Held and then H > Thumb_H then
               --  a click on the bar, or a drag along it: the thumb's middle goes to the cursor
               declare
                  F : constant Float := (My - L.Y - Thumb_H / 2.0) / (H - Thumb_H);
               begin
                  Top := Integer'Max (0, Integer'Min (Max_Top, Integer (Float'Rounding (F * Float (Max_Top)))));
                  if Click then
                     Taken := True;
                  end if;
               end;
            end if;
            Rect (Bx, L.Y, Bw, H, Bar_Back);
            Rect (Bx, L.Y + Snap ((H - Thumb_H) * Float (Top) / Float (Max_Top)), Bw, Thumb_H,
                  (if On_Bar then Ink_Dim else Panel_Edge));
            L.W := L.W - Bw - Pix (2.0);
            P.W := P.W - Bw - Pix (2.0);       --  what is laid out in the rows keeps clear of the bar
            P.W_U := P.W_U - Bar_W - 2.0;
            L.Narrowed := True;
         end;
      end if;
      L.First := Top + 1;
      L.Last := Top + Vis;
      return L;
   end Begin_List;

   function Row (P : in out Panel; L : in out List; K : Positive) return Boolean is
      Y   : constant Float := L.Y + Float (K - L.First) * L.Row_H;
      Hot : constant Boolean :=
        Mx >= L.X and then Mx < L.X + L.W and then My >= Y and then My < Y + L.Row_H and then not Covered (P);
   begin
      End_Run (P);
      P.Cursor := Y;
      if Hot then
         Rect (L.X - Pix (2.0), Y - Hair, L.W + 2.0 * Pix (2.0), L.Row_H, Row_Hot);
      elsif K mod 2 = 0 then
         Rect (L.X - Pix (2.0), Y - Hair, L.W + 2.0 * Pix (2.0), L.Row_H, Row_Stripe);
      end if;
      return Hot;
   end Row;

   procedure End_List (P : in out Panel; L : in out List) is
   begin
      End_Run (P);
      P.Cursor := L.Y + Float (L.Last - L.First + 1) * L.Row_H + Hair;
      if L.Narrowed then
         P.W := L.Panel_W;
         P.W_U := L.Panel_U;
         L.Narrowed := False;
      end if;
   end End_List;

   --------------------------------------------------------------- tooltips

   function Tip_Due (Key : Natural) return Boolean is
   begin
      if Key = 0 then
         return False;
      end if;
      if not Tip_Asked then
         Tip_Asked := True;
         if Key /= Tip_Key then
            Tip_Key := Key;
            Tip_Wait := 0.0;
         else
            Tip_Wait := Tip_Wait + Dt;
         end if;
      end if;
      return Key = Tip_Key and then Tip_Wait >= Tip_Delay_S;
   end Tip_Due;

   function Begin_Tip (W : Float; Title : String := "") return Panel is
      P : Panel;
   begin
      P.Kind := Tip;
      P.W := Pix (W);
      P.W_U := W;
      P.Pad := Pix (Pad_U);
      P.X := Mx + Pix (14.0);
      if P.X + P.W > W_Px - Pix (2.0) then             --  no room on the right: left of the cursor
         P.X := Float'Max (Pix (2.0), Mx - Pix (10.0) - P.W);
      end if;
      P.Y := My + Pix (16.0);
      if P.Y + Tip_H > H_Px - Pix (2.0) then           --  nor below: above it
         P.Y := Float'Max (Pix (2.0), My - Pix (8.0) - Tip_H);
      end if;
      P.X := Snap (P.X);
      P.Y := Snap (P.Y);
      Open (P, Title);
      return P;
   end Begin_Tip;

   procedure End_Tip (P : in out Panel) is
   begin
      End_Panel (P);
   end End_Tip;

   ----------------------------------------------------------------- popups

   function Begin_Popup (X, Y : Float; W : Float; Title : String := "") return Panel is
      P : Panel;
   begin
      if not Popup_Prev.Live then
         Popup_H := 0.0;                                --  a new one: its height is not known yet
      end if;
      Box_N := Box_N + 1;
      P.Box_Index := Box_N;
      P.Kind := Popup;
      P.W := Pix (W);
      P.W_U := W;
      P.Pad := Pix (Pad_U);
      P.X := Snap (Float'Max (Pix (2.0), Float'Min (X, W_Px - Pix (2.0) - P.W)));
      P.Y := Snap (Float'Max (Pix (2.0), Float'Min (Y, H_Px - Pix (2.0) - Popup_H)));
      Open (P, Title);
      return P;
   end Begin_Popup;

   procedure End_Popup (P : in out Panel) is
   begin
      End_Panel (P);
   end End_Popup;

   procedure Pointer (X, Y : Float) is
      Px : constant Float := Snap (X);
      Py : constant Float := Snap (Y);
      K  : constant Float := Float'Max (1.0, Float'Floor (Sf / 2.0));
      Dark  : constant Color := 16#FF000000#;
      Light : constant Color := 16#FFFFFFFF#;
   begin
      for R in 0 .. 11 loop                      --  an arrow: a wedge, then its tail
         declare
            Wd : constant Float := Float (if R <= 8 then R + 1 else 12 - R) * K;
         begin
            Rect (Px - K, Py + Float (R) * K - K, Wd + 2.0 * K, 3.0 * K, Dark);
         end;
      end loop;
      for R in 0 .. 11 loop
         declare
            Wd : constant Float := Float (if R <= 8 then R + 1 else 12 - R) * K;
         begin
            Rect (Px, Py + Float (R) * K, Wd, K, Light);
         end;
      end loop;
   end Pointer;

   ----------------------------------------------------------------- tables

   Col_Gap : constant := 6.0;   --  pixels at Scale 1 between columns

   function Table_W (Cols : Columns) return Float is
      W : Float := 0.0;
   begin
      for C of Cols loop
         W := W + C.Width;
      end loop;
      return W + Col_Gap * Float (Cols'Length - 1);
   end Table_W;

   function Row_H return Float is (Line_H + Hair);

   function Begin_Table (P : Panel; Cols : Columns) return Table is
      T : Table (Cols'Length);
      X : Float := Content_X (P);
   begin
      T.Cols := Cols;
      for I in Cols'Range loop
         T.X0 (I) := X;
         X := X + Pix (Cols (I).Width) + Pix (Col_Gap);
      end loop;
      T.W   := Float'Min (Inner_W (P), X - Pix (Col_Gap) - Content_X (P));
      T.Top := P.Cursor;
      T.Y   := P.Cursor;
      return T;
   end Begin_Table;

   procedure Put_Cell (T : in out Table; S : String; C : Color; Is_Header : Boolean) is
   begin
      if T.Col = T.N then
         T.Y := T.Y + Row_H;
         T.Col := 0;
      end if;
      if T.Col = 0 and then not Is_Header then
         T.Rows := T.Rows + 1;
         if T.Rows mod 2 = 0 then
            Rect (T.X0 (1) - Pix (2.0), T.Y - Hair, T.W + 2.0 * Pix (2.0), Row_H, Row_Stripe);
         end if;
      end if;
      T.Col := T.Col + 1;
      declare
         K  : constant Positive := T.Col;
         Cw : constant Float := Pix (T.Cols (K).Width);
      begin
         Aligned (T.X0 (K), T.Y, Cw, Fit (S, Cw), C, T.Cols (K).Al);
      end;
      if Is_Header and then T.Col = T.N then
         Rect (T.X0 (1), T.Y + Row_H - Hair, T.W, Hair, With_Alpha (Panel_Edge, 180));
         T.Y := T.Y + Hair;   --  room for the rule
      end if;
   end Put_Cell;

   procedure Header (T : in out Table; S : String) is
   begin
      Put_Cell (T, S, Ink_Strong, Is_Header => True);
   end Header;

   procedure Cell (T : in out Table; S : String; C : Color := Ink) is
   begin
      Put_Cell (T, S, C, Is_Header => False);
   end Cell;

   procedure End_Table (P : in out Panel; T : Table) is
   begin
      End_Run (P);
      P.Cursor := T.Y + (if T.Col > 0 then Row_H else 0.0) + Hair;
   end End_Table;

   -------------------------------------------------------------------- GPU

   Program : UInt := 0;
   VAO     : UInt := 0;
   Buf     : UInt := 0;
   Tex     : UInt := 0;
   Screen_Loc : int := -1;
   Smooth_Loc : int := -1;

   Vertex_Source : constant String :=
     "#version 450 core" & LF &
     "struct Q { vec4 r; vec4 uv; uvec4 c; };" & LF &
     "layout(std430, binding = 7) readonly buffer UI_Quads { Q q[]; };" & LF &
     "uniform vec2 u_screen;" & LF &
     "out vec2 v_uv;" & LF &
     "flat out int v_tex;" & LF &
     "out vec4 v_col;" & LF &
     "const vec2 corner[6] = vec2[6](vec2(0,0), vec2(1,0), vec2(1,1), vec2(0,0), vec2(1,1), vec2(0,1));" & LF &
     "void main() {" & LF &
     "  Q k = q[gl_VertexID / 6];" & LF &
     "  vec2 t = corner[gl_VertexID % 6];" & LF &
     "  vec2 p = mix(k.r.xy, k.r.zw, t);" & LF &
     "  v_uv = mix(k.uv.xy, k.uv.zw, t);" & LF &
     "  v_tex = k.uv.x < 0.0 ? 0 : 1;" & LF &
     "  v_col = mix(unpackUnorm4x8(k.c.x), unpackUnorm4x8(k.c.y), t.y);" & LF &
     "  gl_Position = vec4(p.x / u_screen.x * 2.0 - 1.0, 1.0 - p.y / u_screen.y * 2.0, 0.0, 1.0);" & LF &
     "}" & LF;

   Fragment_Source : constant String :=
     "#version 450 core" & LF &
     "layout(binding = 7) uniform sampler2D u_font;" & LF &
     "uniform int u_smooth;" & LF &
     "in vec2 v_uv;" & LF &
     "flat in int v_tex;" & LF &
     "in vec4 v_col;" & LF &
     "out vec4 o_col;" & LF &
     "float ink(ivec2 t) {" & LF &
     "  ivec2 n = textureSize(u_font, 0);" & LF &
     "  if (t.x < 0 || t.y < 0 || t.x >= n.x || t.y >= n.y) return 0.0;" & LF &
     "  return texelFetch(u_font, t, 0).r;" & LF &
     "}" & LF &
     "void main() {" & LF &
     "  float a = 1.0;" & LF &
     "  if (v_tex == 1) {" & LF &
     "    if (u_smooth == 0) {" & LF &
     "      a = texelFetch(u_font, ivec2(floor(v_uv)), 0).r;" & LF &
     "    } else {" & LF &
     --  A scale that is not whole: a pixel is box texels wide and may lie
     --  over two texels each way; it takes of each as much as it covers.
     "      vec2 box = clamp(fwidth(v_uv), 1e-4, 1.0);" & LF &
     "      vec2 tx = v_uv - 0.5 * box;" & LF &
     "      vec2 f = clamp((fract(tx) - (1.0 - box)) / box, 0.0, 1.0);" & LF &
     "      ivec2 i = ivec2(floor(tx));" & LF &
     "      a = mix(mix(ink(i), ink(i + ivec2(1, 0)), f.x)," & LF &
     "              mix(ink(i + ivec2(0, 1)), ink(i + ivec2(1, 1)), f.x), f.y);" & LF &
     "    }" & LF &
     "  }" & LF &
     "  if (a * v_col.a < 0.004) discard;" & LF &
     "  o_col = vec4(v_col.rgb, v_col.a * a);" & LF &
     "}" & LF;

   function Compile (Kind : Enum; Source : String) return UInt is
      Shader : constant UInt := Create_Shader (Kind);
      Src    : aliased chars_ptr := New_String (Source);
      Ok     : int := 0;
   begin
      Shader_Source (Shader, 1, Src'Address, System.Null_Address);
      Compile_Shader (Shader);
      Free (Src);
      Get_Shader_Iv (Shader, Compile_Status, Ok);
      if Ok = 0 then
         declare
            Log : aliased char_array (1 .. 4_096) := [others => nul];
            Len : Sizei := 0;
         begin
            Get_Shader_Info_Log (Shader, Log'Length, Len, Log'Address);
            raise Program_Error with "UI shader compile failed:" & LF & To_Ada (Log);
         end;
      end if;
      return Shader;
   end Compile;

   procedure Init is
      Ok : int := 0;
   begin
      Program := Create_Program;
      declare
         V : constant UInt := Compile (Vertex_Shader, Vertex_Source);
         F : constant UInt := Compile (Fragment_Shader, Fragment_Source);
      begin
         Attach_Shader (Program, V);
         Attach_Shader (Program, F);
         Link_Program (Program);
         Get_Program_Iv (Program, Link_Status, Ok);
         if Ok = 0 then
            declare
               Log : aliased char_array (1 .. 4_096) := [others => nul];
               Len : Sizei := 0;
            begin
               Get_Program_Info_Log (Program, Log'Length, Len, Log'Address);
               raise Program_Error with "UI shader link failed:" & LF & To_Ada (Log);
            end;
         end if;
         Delete_Shader (V);
         Delete_Shader (F);
      end;
      declare
         C : chars_ptr := New_String ("u_screen");
         D : chars_ptr := New_String ("u_smooth");
      begin
         Screen_Loc := Get_Uniform_Location (Program, C);
         Smooth_Loc := Get_Uniform_Location (Program, D);
         Free (C);
         Free (D);
      end;

      Create_Vertex_Arrays (1, VAO);
      Create_Buffers (1, Buf);
      Named_Buffer_Storage (Buf, Sizeiptr (Capacity * (Quad'Size / 8)), System.Null_Address,
                            Dynamic_Storage_Bit);

      declare
         Pixels : aliased Castle.Font.Atlas_Pixels;
      begin
         Castle.Font.Atlas (Pixels);
         Create_Textures (Texture_2D, 1, Tex);
         Texture_Storage_2D (Tex, 1, R8, Castle.Font.Atlas_W, Castle.Font.Atlas_H);
         Pixel_Store_I (Unpack_Alignment, 1);
         Texture_Sub_Image_2D (Tex, 0, 0, 0, Castle.Font.Atlas_W, Castle.Font.Atlas_H,
                               Red, Unsigned_Byte, Pixels'Address);
         Texture_Parameter_I (Tex, Texture_Min_Filter, Nearest);
         Texture_Parameter_I (Tex, Texture_Mag_Filter, Nearest);
      end;
   end Init;

   procedure Draw is
   begin
      if Count = 0 or else Program = 0 then
         return;
      end if;
      Named_Buffer_Sub_Data (Buf, 0, Sizeiptr (Count * (Quad'Size / 8)), Quads (1)'Address);
      Bind_Framebuffer (Framebuffer, 0);
      Viewport (0, 0, Sizei (W_Px), Sizei (H_Px));
      Disable (Depth_Test);
      Disable (Cull_Face_Cap);
      Enable (Blend);
      Blend_Func (Src_Alpha, One_Minus_Src_Alpha);
      Use_Program (Program);
      Program_Uniform_2f (Program, Screen_Loc, Float32 (W_Px), Float32 (H_Px));
      Program_Uniform_1i (Program, Smooth_Loc, (if Whole then 0 else 1));
      Bind_Vertex_Array (VAO);
      Bind_Buffer_Base (Shader_Storage_Buffer, 7, Buf);
      Bind_Texture_Unit (7, Tex);
      Draw_Arrays (Triangles, 0, Sizei (6 * Count));
      Disable (Blend);
      Enable (Depth_Test);
      Enable (Cull_Face_Cap);
   end Draw;

end Castle.UI;
