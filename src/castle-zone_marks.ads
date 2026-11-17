with Castle.Colony;
with Castle.Marks;
with Castle.Math; use Castle.Math;

--  Zones shown on the ground: each one's ground filled in, see-through,
--  with a line round its edge, so a zone reads as the shape it has (along
--  a path, round a tree, stopping at another zone) and not as a box.  Laid
--  as Castle.Marks strips from the strips of block columns Castle.Colony
--  keeps a zone's ground as, every frame; nothing is kept here but the
--  planned paths' ground between two readings of it.  Main thread only,
--  after Castle.Marks.Begin_Frame.
package Castle.Zone_Marks is

   type Style is record
      Fill   : Castle.Marks.Colour;   --  over all its ground (alpha 0: none)
      Edge   : Castle.Marks.Colour;   --  along its edge
      Edge_W : Float := 0.06;         --  metres
      Of_Ground : Boolean := False;   --  it dims with the daylight (a zone as it lies; not one being pointed at or planned)
   end record;

   --  (the marks' own colours, as the routes' are: not the palette's yet)
   Stockpile : constant Style := ((0.95, 0.85, 0.55, 0.16), (0.95, 0.85, 0.55, 0.6), 0.06, True);
   Camp      : constant Style := ((0.95, 0.72, 0.42, 0.12), (0.95, 0.75, 0.45, 0.45), 0.06, True);
   Housing   : constant Style := ((0.72, 0.82, 0.95, 0.10), (0.72, 0.82, 0.95, 0.5), 0.06, True);
   House_Plan : constant Castle.Marks.Colour := (0.8, 0.88, 1.0, 0.7);                   --  a house begun: where its walls go
   Pointed   : constant Style := ((1.0, 0.92, 0.6, 0.0), (1.0, 0.92, 0.6, 0.9), 0.12, False);    --  under the cursor
   Planned   : constant Style := ((0.95, 0.85, 0.55, 0.3), (1.0, 0.92, 0.6, 0.8), 0.08, False);  --  a lot not taken yet
   Refused_C : constant Castle.Marks.Colour := (0.9, 0.35, 0.25, 0.75);                  --  one that would not be
   Path_Plan : constant Castle.Marks.Colour := (0.95, 0.85, 0.5, 0.3);                   --  a path planned, not yet laid

   procedure Show_Zone (Z : Positive; S : Style);
   --  Zone Z of the colony.

   procedure Show_Plan (S : Style);
   --  The ground of the lot Castle.Colony last planned (Plan_Stockpile, Plan_Camp).

   procedure Show_Paths (C : Castle.Marks.Colour := Path_Plan);
   --  Every stretch of path that is planned and not yet laid, as far as it
   --  is still to lay: the block columns it will turn, each on its own
   --  ground (it dims with the daylight, as a zone does).  What it shows is
   --  kept from call to call and read from the colony again when what is
   --  left to lay changes, and every half second or so besides.

   procedure Show_Path_Line (From, To : Vec3; C : Castle.Marks.Colour);
   --  A path as it is being drawn, From .. To: the block columns it would
   --  turn, each on its own ground.

   procedure Show_Houses (C : Castle.Marks.Colour := House_Plan);
   --  Every house begun and not yet standing: the line its walls will
   --  stand on, and its door's place, on its ground.

   procedure Show_Lot (Corner : Castle.Colony.Lot_Corners; Z : Float; C : Castle.Marks.Colour; Width : Float := 0.08);
   --  A lot as drawn, corner to corner, at height Z: for one that is refused.

end Castle.Zone_Marks;
