with Interfaces;

--  The 2-D layer drawn over the world: text, panels, bars, buttons and
--  tables, immediate mode.
--
--  Every frame the game describes what is on screen between Begin_Frame
--  and End_Frame; nothing is kept from one frame to the next but the
--  places panels took (so a click on a panel is not a click on the world:
--  Wants_Mouse) and which panel the cursor was over.  Calls only collect
--  coloured quads on the CPU; Draw sends them to the GPU in one draw call.
--  So everything but Init and Draw runs without a window, which is how
--  tools/ui_check tests it.
--
--  Units are screen pixels, origin top left, y down.  Scale follows the
--  window height (a whole number, about 1 per 450 px) unless it is set,
--  and it can be set in steps of Scale_Step.  At a whole scale the pixel
--  font (Castle.Font) is drawn texel for pixel, so it stays sharp; at a
--  scale between, the layout is still on whole pixels and only the
--  glyphs' edges are softened, by how much of each pixel they cover.
package Castle.UI is

   ----------------------------------------------------------------- colours

   type Color is new Interfaces.Unsigned_32;   --  RGBA8, red in the low byte
   function RGBA (R, G, B : Natural; A : Natural := 255) return Color;
   function With_Alpha (C : Color; A : Natural) return Color;

   --  The house style.  Tuning table: change them here.
   Ink         : constant Color := 16#FFD2E6F0#;   --  text (240, 230, 210)
   Ink_Dim     : constant Color := 16#FF8CA0AA#;   --  labels, units
   Ink_Strong  : constant Color := 16#FF6FD8FF#;   --  headings (255, 216, 111)
   Ink_Bad     : constant Color := 16#FF5A64E6#;   --  warnings (230, 100, 90)
   Shadow      : constant Color := 16#C0000000#;
   Panel_Top   : constant Color := 16#E01A1E28#;   --  background, graded top to bottom
   Panel_Foot  : constant Color := 16#E00D0F14#;
   Panel_Edge  : constant Color := 16#FF46607A#;   --  1-pixel rim
   Title_Back  : constant Color := 16#F0192432#;
   Row_Stripe  : constant Color := 16#18FFFFFF#;
   Bar_Back    : constant Color := 16#FF0C0E12#;
   Button_Back : constant Color := 16#FF242E3C#;
   Button_Hot  : constant Color := 16#FF36465A#;
   Button_On   : constant Color := 16#FF2E6E8C#;   --  a selected toggle

   Row_Hot     : constant Color := 16#30FFFFFF#;   --  the list row under the cursor
   Tab_Back    : constant Color := 16#FF161C26#;   --  a tab not chosen
   Tip_Edge    : constant Color := 16#FF6FD8FF#;   --  a tooltip's rim: the heading colour

   Bar_Green : constant Color := 16#FF4AA85A#;
   Bar_Blue  : constant Color := 16#FFC88C46#;
   Bar_Amber : constant Color := 16#FF32A0DC#;
   Bar_Red   : constant Color := 16#FF3C46C8#;

   ------------------------------------------------------------------ frames

   procedure Begin_Frame
     (Width, Height     : Natural;
      Mouse_X, Mouse_Y  : Float;      --  pixels from the top left
      Mouse_Clicked     : Boolean;    --  left button went down this frame
      Fixed_Scale       : Float := 0.0;    --  0: from the window height (else taken to the nearest step)
      Wheel             : Float := 0.0;    --  wheel steps this frame (away from the user: positive)
      Mouse_Held        : Boolean := False;   --  left button is down
      Seconds           : Float := 0.0);   --  real time since the last frame (tooltips wait on it)
   procedure End_Frame;

   function Scale return Float;

   --  The scale can be set a little larger or smaller than the window
   --  gives: in steps of Scale_Step, from Scale_Min to Scale_Max.
   Scale_Step : constant := 0.25;
   Scale_Min  : constant := 1.0;
   Scale_Max  : constant := 8.0;
   function Auto_Scale (Height : Natural) return Float;   --  what a window that tall gets unless told
   function Nearest_Scale (S : Float) return Float;       --  S as a step within the limits
   function Next_Scale (S : Float; Larger : Boolean) return Float;   --  a step up or down from S
   function Screen_W return Float;
   function Screen_H return Float;

   function Wants_Mouse return Boolean;
   --  The cursor is over a panel (as laid out last frame), so the world
   --  should not take the click or the wheel.

   function Click_Taken return Boolean;
   --  A widget took this frame's click.

   function Wheel_Taken return Boolean;
   --  A list scrolled by this frame's wheel.

   ------------------------------------------------------------- primitives

   procedure Rect (X, Y, W, H : Float; C : Color);
   procedure Gradient (X, Y, W, H : Float; Top, Bottom : Color);
   procedure Outline (X, Y, W, H : Float; C : Color);   --  Scale pixels thick, inside the box

   type Align is (Left, Centre, Right);

   procedure Text
     (X, Y   : Float;
      S      : String;
      C      : Color    := Ink;
      Size   : Positive := 1;           --  times Scale
      Shade  : Boolean  := True);       --  one-pixel drop shadow
   --  Y is the top of the line.  Latin-1: only printable ASCII and the
   --  degree sign have glyphs; anything else shows as '?'.

   function Text_Width (S : String; Size : Positive := 1) return Float;
   function Line_H (Size : Positive := 1) return Float;   --  line advance
   function Fit (S : String; Width : Float; Size : Positive := 1) return String;
   --  S, cut short with ".." if it is wider than Width.

   ----------------------------------------------------------------- panels

   --  A panel is a box that lays its contents out top to bottom.  Its
   --  height is whatever its contents take (or at least Min_H), worked out
   --  at End_Panel: the background is reserved at Begin_Panel and sized
   --  afterwards.
   type Anchor is (Top_Left, Top_Right, Bottom_Left, Bottom_Right);

   type Panel is private;

   function Begin_Panel
     (X, Y   : Float;                  --  offset from the anchored corner (pixels at Scale 1)
      W      : Float;                  --  width (pixels at Scale 1)
      Title  : String  := "";
      From   : Anchor  := Top_Left;
      Min_H  : Float   := 0.0) return Panel;
   procedure End_Panel (P : in out Panel);
   --  Panels anchored to a bottom corner grow upward.  They are placed by
   --  the height they had last frame (panels are told apart by the order
   --  they are begun in), so buttons in them are hit where they are drawn;
   --  a panel whose height changed is moved into place at End_Panel.

   function Inner_W (P : Panel) return Float;   --  pixels inside the padding
   function Cursor_Y (P : Panel) return Float;  --  where its next line goes (pixels from the top)
   function Last_Bottom return Float;
   --  The lower edge of the panel ended last, in pixels at Scale 1 from the
   --  top: to put another panel under it.

   --  Contents.  Each takes one line (or as noted) and moves the panel's
   --  cursor down.
   procedure Label (P : in out Panel; S : String; C : Color := Ink; Al : Align := Left);
   procedure Heading (P : in out Panel; S : String);
   procedure Value (P : in out Panel; Name, Val : String; C : Color := Ink);
   --  Name on the left, dimmed; Val on the right.
   procedure Bar
     (P        : in out Panel;
      Name     : String;
      Fraction : Float;                 --  clamped to 0 .. 1
      Fill     : Color  := Bar_Green;
      Val      : String := "");         --  shown on the right of the name
   --  Name and value on one line, the bar on the next, thin.
   procedure Gap (P : in out Panel; Lines : Float := 0.5);
   procedure Separator (P : in out Panel);

   function Button
     (P      : in out Panel;
      Text   : String;
      On     : Boolean := False;        --  draw as a selected toggle
      Width  : Float   := 0.0)          --  0: the panel's inner width (pixels at Scale 1 otherwise)
      return Boolean;
   --  True when clicked this frame.  Consecutive buttons given a Width go
   --  on one line while they fit; any other content, or Same_Line_End,
   --  ends the run.
   procedure Same_Line_End (P : in out Panel);

   procedure Beside (P : in out Panel; S : String; C : Color := Ink);
   --  Text on the line of the buttons just laid, after the last of them,
   --  cut to the room left.  Takes no line of its own.

   procedure Column_Text
     (P    : in out Panel;
      X, W : Float;                     --  from the panel's content edge, and wide (pixels at Scale 1)
      S    : String;
      C    : Color := Ink;
      Al   : Align := Left;
      Drop : Float := 0.0;              --  down from the line's top (pixels at Scale 1)
      Back : Color := 0);               --  0: none; else a box behind it, H high
   Column_H : constant := 11.0;         --  that box's height (pixels at Scale 1)
   --  Text in a column of the line the panel is at, cut to the column.  It
   --  takes no line of its own: Next_Line (or a list's next Row) moves on.
   procedure Next_Line (P : in out Panel; H : Float := 11.0);   --  H pixels (at Scale 1) down

   ------------------------------------------------------------------- tabs

   function Tab (P : in out Panel; Text : String; On : Boolean) return Boolean;
   --  One tab of a row: each as wide as its name, the chosen one (On) lit.
   --  True when clicked.  Which is chosen is the caller's to keep.
   procedure End_Tabs (P : in out Panel);
   --  The rule under the row; what follows is the chosen tab's content.

   ------------------------------------------------------------------ lists

   --  A list of rows all one height, Shown of them on screen at once: the
   --  wheel over it scrolls (Wheel_Rows a step; parts of a step, as a
   --  touchpad gives them, add up till they make one), and when there are more
   --  rows than fit a bar on the right shows where one is and takes clicks
   --  and drags.  It scrolls by whole rows, so nothing is ever cut.  How far
   --  it is scrolled (Top: rows passed) is the caller's to keep.
   Wheel_Rows : constant := 2;

   type List is private;

   function Begin_List
     (P     : in out Panel;
      Total : Natural;                  --  rows there are
      Shown : Positive;                 --  rows on screen at once
      Row_H : Float;                    --  a row's height (pixels at Scale 1)
      Top   : in out Natural) return List;
   function First (L : List) return Positive;   --  the rows to lay out now:
   function Last (L : List) return Natural;     --  First .. Last, in order
   function Row (P : in out Panel; L : in out List; K : Positive) return Boolean;
   --  Starts row K: what is laid out next goes in it.  True: the cursor is
   --  on this row.
   procedure End_List (P : in out Panel; L : in out List);

   --------------------------------------------------------------- tooltips

   --  A tooltip is a panel by the cursor that takes no clicks and is never
   --  in the cursor's way: it is not counted in Wants_Mouse, and it keeps on
   --  the screen (left of the cursor, or above it, when there is no room).
   --  It waits until the cursor has rested on one thing for Tip_Delay_S.
   Tip_Delay_S : constant := 0.3;

   function Tip_Due (Key : Natural) return Boolean;
   --  Once a frame, with a number that names what the cursor is on (0:
   --  nothing).  True once it has been on that same thing long enough.
   function Begin_Tip (W : Float; Title : String := "") return Panel;   --  W: pixels at Scale 1
   procedure End_Tip (P : in out Panel);

   ----------------------------------------------------------------- popups

   --  A popup is a panel opened at a point (a context menu where the right
   --  button was clicked), over everything else: laid out last, kept on the
   --  screen, and what is under it gets no clicks.  Whether one is open, and
   --  where, is the caller's to keep; Over_Popup and Popup_Shown say how
   --  last frame's lay, so a click away from it can close it.
   function Begin_Popup (X, Y : Float; W : Float; Title : String := "") return Panel;
   --  X, Y: the screen point it was opened at (pixels); W: pixels at Scale 1.
   procedure End_Popup (P : in out Panel);
   function Popup_Shown return Boolean;   --  one was laid out last frame
   function Over_Popup return Boolean;    --  and the cursor is on it

   procedure Pointer (X, Y : Float);
   --  An arrow drawn at a point (pixels): the cursor of a scripted run,
   --  where there is no real one to see.

   ----------------------------------------------------------------- tables

   type Column is record
      Width : Float := 40.0;            --  pixels at Scale 1
      Al    : Align := Left;
   end record;
   type Columns is array (Positive range <>) of Column;

   type Table (N : Positive) is private;

   function Begin_Table (P : Panel; Cols : Columns) return Table
     with Pre => Cols'Length = Cols'Last and then Cols'First = 1;
   procedure Header (T : in out Table; S : String);    --  the first row: headings
   procedure Cell (T : in out Table; S : String; C : Color := Ink);
   --  Cells fill a row left to right; the cell after the last column
   --  starts the next row.  A cell's text is cut to its column.
   procedure End_Table (P : in out Panel; T : Table);

   function Table_W (Cols : Columns) return Float;   --  pixels at Scale 1, gaps included

   ------------------------------------------------------------------- GPU

   procedure Init;
   --  Needs the OpenGL context: the font texture, the quad buffer, the shader.

   procedure Draw;
   --  Draws the frame's quads over whatever framebuffer 0 holds.  Call after
   --  Castle.Render.Draw and before Swap_Buffers (and before a screenshot,
   --  so it shows the interface too).

   ------------------------------------------------------------------ tests

   type Quad is record
      X0, Y0, X1, Y1 : Interfaces.IEEE_Float_32;
      U0, V0, U1, V1 : Interfaces.IEEE_Float_32;   --  font texels; U0 < 0: solid colour
      Top, Bottom    : Interfaces.Unsigned_32;
      Pad0, Pad1     : Interfaces.Unsigned_32 := 0;
   end record with Convention => C;                --  std430, 48 bytes

   function Quad_Count return Natural;
   function Quad_At (I : Positive) return Quad;
   function Dropped return Natural;   --  quads past capacity this frame

private

   type Panel_Kind is (Fixed, Tip, Popup);

   type Panel is record
      Kind        : Panel_Kind := Fixed;
      X, Y, W     : Float := 0.0;   --  pixels
      W_U         : Float := 0.0;   --  its width as asked for (pixels at Scale 1)
      Line_U      : Float := 0.0;   --  how much of a shared line is taken (pixels at Scale 1)
      Cursor      : Float := 0.0;   --  next line's top
      Line_X      : Float := 0.0;   --  next button on a shared line (0: none)
      Line_Top    : Float := 0.0;
      Line_Bottom : Float := 0.0;
      Min_H       : Float := 0.0;
      Bottom      : Float := 0.0;   --  where a bottom-anchored panel's lower edge belongs
      Pad         : Float := 0.0;
      From        : Anchor := Top_Left;
      First_Quad  : Natural := 0;   --  the background quads, sized at End_Panel
      Back_Quad   : Natural := 0;
      Box_Index   : Natural := 0;
   end record;

   type List is record
      X, Y     : Float := 0.0;      --  its top left (pixels)
      W        : Float := 0.0;      --  of the rows (the bar is beside them)
      Row_H    : Float := 0.0;      --  pixels
      First    : Positive := 1;
      Last     : Natural := 0;
      Panel_W  : Float := 0.0;      --  the panel's width, given back at End_List
      Panel_U  : Float := 0.0;      --  and as it was asked for
      Narrowed : Boolean := False;
   end record;

   type Col_X is array (Positive range <>) of Float;

   type Table (N : Positive) is record
      Cols   : Columns (1 .. N);
      X0     : Col_X (1 .. N);
      W      : Float := 0.0;
      Top    : Float := 0.0;
      Y      : Float := 0.0;
      Col    : Natural := 0;     --  cells written in this row
      Rows   : Natural := 0;     --  data rows begun (for the stripes)
   end record;

end Castle.UI;
