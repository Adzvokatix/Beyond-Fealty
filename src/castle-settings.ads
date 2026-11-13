--  What the player has set that belongs to no game: kept in a small text
--  file, a setting to a line ("name value"), read when the game starts and
--  written when one changes.  A line it does not know is kept as it is, so
--  one build does not lose another's settings.  (Today: the interface's
--  scale.  The options menu will be this file's other reader.)
package Castle.Settings is

   procedure Load (Path : String);
   --  Forgets everything, then reads Path.  No such file: nothing is set.

   function Has (Name : String) return Boolean;
   function Get (Name : String; Default : Float) return Float;
   --  The Default too when what is there is not a number.

   procedure Set (Name : String; Value : Float);

   procedure Save (Path : String; Ok : out Boolean);
   --  Writes them all to Path, making its directory if there is none.

end Castle.Settings;
