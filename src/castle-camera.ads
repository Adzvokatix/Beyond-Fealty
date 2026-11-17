with Castle.Maps; use Castle.Maps;
with Castle.Math; use Castle.Math;

--  Orbit camera for a colony game: it circles a focus point that rides the
--  ground.  Keys and mouse move targets; the camera eases toward them.
--  Over rough ground the camera rides smoothly:
--    * the focus follows the ground averaged over an area that grows with
--      the view, so a cliff edge under it is not a jolt;
--    * the tilt the terrain needs (the line from the focus to the eye must
--      clear every point in between) is worked out from the elevation angles
--      along that line, and the camera follows it quickly up and slowly back
--      down, so passing ridges cannot flip it;
--    * only if even the steepest tilt is blocked does the eye come in;
--    * a last, continuous lift keeps the eye 0.6 m above the ground under it.
package Castle.Camera is

   type State is record
      X, Y, Z    : Float := 1_024.0;   --  focus (m); Z follows the ground
      Yaw        : Float := -0.9;      --  where the eye sits around the focus
      Pitch      : Float := 0.62;      --  above the horizon (rad)
      Dist       : Float := 70.0;      --  eye to focus (m)
      T_X, T_Y   : Float := 1_024.0;   --  targets
      T_Yaw      : Float := -0.9;
      T_Pitch    : Float := 0.62;
      T_Dist     : Float := 70.0;
      Held       : Float := 70.0;      --  eye distance after keeping clear of the ground
      Held_Pitch : Float := 0.62;      --  tilt after keeping clear of the ground
      Lift       : Float := 0.0;       --  last guard: eye raised off the ground under it
   end record;

   procedure Reset (C : in out State; X, Y : Float; W : World);
   procedure Update (C : in out State; W : World; Dt : Float);

   function Eye (C : State) return Vec3;
   function View_Proj (C : State; Aspect : Float; Far : Float := Far_M) return Mat4;
   --  (Far: the far plane; the renderer must be told the same, Castle.Render.Far_Plane)

end Castle.Camera;
