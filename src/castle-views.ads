with Castle.Text;

--  Data views: what there is to know of a thing in the world, as a sheet of
--  named lines.  A sheet is data, not drawing: the development panels show
--  it as rows, a tooltip shows it by the cursor, and later a report on a
--  desk will show it on a page, each in its own way and none of them
--  fetching anything for itself.  So a line added here (a skill, a want)
--  appears everywhere at once.
--
--  The information belongs to the thing: a person's sheet is what that
--  person is and is doing, a zone's what is inside its borders
--  (Castle.Colony.Zone_At).  Every row says whether the player's character
--  could know it, by looking or because he ordered it (Known); what only
--  the development view shows (a belly's exact fill, a mood, what is
--  promised to a cell) is marked not.  The game's own tooltips will show
--  Known_Only.
package Castle.Views is

   type Tone is (Plain, Dim, Good, Bad);

   type Row is record
      Name  : Castle.Text.Line;
      Value : Castle.Text.Line;
      Shade : Tone := Plain;
      Bar   : Float := -1.0;       --  0 .. 1: also drawn as a bar; below 0: no bar
      Known : Boolean := True;
   end record;
   Max_Rows : constant := 28;
   type Row_List is array (1 .. Max_Rows) of Row;

   type Sheet is record
      Title : Castle.Text.Line;
      Note  : Castle.Text.Line;    --  under the title: what kind of thing it is
      N     : Natural := 0;
      Rows  : Row_List;
      Lost  : Natural := 0;        --  rows there was no room for (never, if Max_Rows is enough: the checks say)
   end record;

   --  A person's skills on its sheet: the skill of its job (its level, a
   --  bar, how fast it learns it), its best other skills (up to
   --  Other_Skills of them, from Skill_Shown up), and what it is apt at
   --  (an aptitude of Apt_From or more).  The player can see everyone's
   --  skills and aptitudes and give jobs to match: they are Known.
   Other_Skills : constant := 3;
   Skill_Shown  : constant := 0.05;
   Apt_From     : constant := 1.2;
   Slow_Below   : constant := 0.8;
   function Learns_Text (Aptitude : Float) return String;   --  "learns x1.3"

   function Person (I : Positive) return Sheet;   --  member I of the band
   function Job_Label (I : Positive) return String;
   --  What member I is called in the band's lists: its trade while it has
   --  one ("Builder", "Stockman", "Carpenter": John, 2026-11-17, "Add
   --  builder to the job list"), else its job ("Forester", "No job").  A
   --  trade is still earned, not given: the menu of jobs is as it was.
   function Zone (Z : Positive) return Sheet;     --  zone Z: a stockpile, the camp, housing
   function House (H : Positive) return Sheet;    --  house H: whose it is, how far built, what it waits for
   function Deer (K : Positive) return Sheet;     --  deer K of the herds
   function Cart return Sheet;                    --  the lord's cart: what is left in it

   --  The demand table (Castle.Colony, "demand"): for food and for each
   --  kind that is asked for or in store, a line of what the stores have of
   --  what they want ("asked" while it is being asked for, "asked of
   --  nobody" when no one of the band brings it in), and under it who asks.
   --  It is the stores' own account, so the player's to know.
   function Demand return Sheet;
   function Asked_List return String;
   --  "food, wood": what the stores are asking for now ("nothing" if nothing).

   function Known_Only (S : Sheet) return Sheet;
   --  S without the rows the player's character could not know.

   function Row_Named (S : Sheet; Name : String) return Natural;   --  0: none
   function Value_Of (S : Sheet; Name : String) return String;     --  "" if there is no such row

end Castle.Views;
