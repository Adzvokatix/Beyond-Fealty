with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Castle.Dims;   use Castle.Dims;
with Castle.Fields; use Castle.Fields;
with Castle.Input;  use Castle.Input;

package body Castle.Camera is

   Min_Pitch : constant := 0.12;
   Max_Pitch : constant := 1.45;
   Min_Dist  : constant := 3.0;
   Max_Dist  : constant := 450.0;

   Ring_X : constant array (1 .. 8) of Float := (1.0, 0.7071, 0.0, -0.7071, -1.0, -0.7071, 0.0, 0.7071);
   Ring_Y : constant array (1 .. 8) of Float := (0.0, 0.7071, 1.0, 0.7071, 0.0, -0.7071, -1.0, -0.7071);

   function Ground (W : World; X, Y : Float) return Float is
     (Sample (W.Height.all, X, Y));

   procedure Reset (C : in out State; X, Y : Float; W : World) is
   begin
      C := (X => X, Y => Y, Z => Ground (W, X, Y), others => <>);
      C.T_X := X;
      C.T_Y := Y;
   end Reset;

   procedure Update (C : in out State; W : World; Dt : Float) is
      Ease  : constant Float := 1.0 - Exp (-Dt * 10.0);
      Fx    : constant Float := -Cos (C.T_Yaw);        --  forward on the ground
      Fy    : constant Float := -Sin (C.T_Yaw);
      Rx    : constant Float := Fy;                    --  right = forward x up
      Ry    : constant Float := -Fx;
      Speed : constant Float := (6.0 + 0.9 * C.T_Dist) * Dt;
      Grab  : constant Float := 0.0016 * C.T_Dist;     --  metres per dragged pixel
      F, R  : Float := 0.0;
   begin
      if Held (Pan_Forward) then F := F + 1.0; end if;
      if Held (Pan_Back)    then F := F - 1.0; end if;
      if Held (Pan_Right)   then R := R + 1.0; end if;
      if Held (Pan_Left)    then R := R - 1.0; end if;
      C.T_X := C.T_X + (Fx * F + Rx * R) * Speed;
      C.T_Y := C.T_Y + (Fy * F + Ry * R) * Speed;

      if Held (Turn_Left)  then C.T_Yaw := C.T_Yaw - 1.8 * Dt; end if;
      if Held (Turn_Right) then C.T_Yaw := C.T_Yaw + 1.8 * Dt; end if;
      if Held (Tilt_Up)    then C.T_Pitch := C.T_Pitch + 1.2 * Dt; end if;
      if Held (Tilt_Down)  then C.T_Pitch := C.T_Pitch - 1.2 * Dt; end if;
      if Held (Zoom_In)    then C.T_Dist := C.T_Dist * (1.0 - 1.6 * Dt); end if;
      if Held (Zoom_Out)   then C.T_Dist := C.T_Dist * (1.0 + 1.6 * Dt); end if;
      C.T_Dist := C.T_Dist * 0.85 ** Wheel;

      if Orbit_Drag then
         C.T_Yaw := C.T_Yaw - 0.006 * Mouse_Dx;
         C.T_Pitch := C.T_Pitch + 0.005 * Mouse_Dy;
      end if;
      if Pan_Drag then                                 --  the ground follows the cursor
         C.T_X := C.T_X - Rx * Mouse_Dx * Grab + Fx * Mouse_Dy * Grab;
         C.T_Y := C.T_Y - Ry * Mouse_Dx * Grab + Fy * Mouse_Dy * Grab;
      end if;
      if Pressed (Reset_View) then
         C.T_Yaw := -0.9;
         C.T_Pitch := 0.62;
         C.T_Dist := 70.0;
      end if;

      C.T_Pitch := Float'Max (Min_Pitch, Float'Min (Max_Pitch, C.T_Pitch));
      C.T_Dist := Float'Max (Min_Dist, Float'Min (Max_Dist, C.T_Dist));
      C.T_X := Float'Max (0.0, Float'Min (Float (Size_M) - 0.01, C.T_X));
      C.T_Y := Float'Max (0.0, Float'Min (Float (Size_M) - 0.01, C.T_Y));

      C.X := C.X + (C.T_X - C.X) * Ease;
      C.Y := C.Y + (C.T_Y - C.Y) * Ease;
      C.Yaw := C.Yaw + (C.T_Yaw - C.Yaw) * Ease;
      C.Pitch := C.Pitch + (C.T_Pitch - C.Pitch) * Ease;
      C.Dist := C.Dist + (C.T_Dist - C.Dist) * Ease;
      --  The focus rides the ground averaged over a patch that grows with
      --  the view, eased a little more slowly than the pan.
      declare
         R   : constant Float := 2.0 + 0.08 * C.Dist;
         Sum : Float := Ground (W, C.X, C.Y);
      begin
         for K in Ring_X'Range loop
            Sum := Sum + Ground (W, C.X + R * Ring_X (K), C.Y + R * Ring_Y (K));
         end loop;
         C.Z := C.Z + (Sum / 9.0 - C.Z) * (1.0 - Exp (-Dt * 6.0));
      end;

      declare
         Clearance : constant Float := 1.0;
         Fz        : constant Float := C.Z + 1.5;     --  the line starts just above the focus
         Cy        : constant Float := Cos (C.Yaw);
         Sy        : constant Float := Sin (C.Yaw);
         --  Ground within the patch the focus height is averaged over is
         --  the ground at the focus, not an obstacle: the line is checked
         --  from beyond it.  (Averaged, the focus sits a little under the
         --  real ground on a slope, so the first metres would always read
         --  as blocked.)
         Skip      : constant Float := 3.0 + 0.08 * C.Dist;

         --  Highest ground within a metre of (X, Y): keeps the line off
         --  ridge crests and cliff lips rather than skimming them.
         function Top (X, Y : Float) return Float is
           (Float'Max (Float'Max (Ground (W, X - 1.0, Y - 1.0), Ground (W, X + 1.0, Y - 1.0)),
                       Float'Max (Ground (W, X - 1.0, Y + 1.0), Ground (W, X + 1.0, Y + 1.0))));

         --  The tilt at which the line clears everything out to the eye:
         --  the steepest elevation angle of the ground along it.  Where the
         --  line meets the ground depends on the tilt itself (a steeper line
         --  reaches less far out), so the tilt is raised until it clears the
         --  very points it is measured at; it only ever rises, so a few
         --  rounds settle it.
         function Need_At (P : Float) return Float is
            Need : Float := C.Pitch;
         begin
            for K in 1 .. 64 loop
               declare
                  H : constant Float := C.Dist * Float (K) / 64.0 * Cos (P);
               begin
                  if H > Skip then
                     Need := Float'Max
                       (Need, 0.015 + Arctan (Top (C.X + Cy * H, C.Y + Sy * H) + Clearance - Fz, H));
                  end if;
               end;
            end loop;
            return Float'Min (Max_Pitch, Need);
         end Need_At;

         function Needed return Float is
            P : Float := C.Pitch;
         begin
            for Round in 1 .. 8 loop
               declare
                  Next : constant Float := Float'Max (P, Need_At (P));
               begin
                  exit when Next - P < 0.001;
                  P := Next;
               end;
            end loop;
            return P;
         end Needed;

         --  How far the line at tilt P stays clear (all the way: C.Dist),
         --  tested at exactly the points the tilt was worked out from and
         --  with half the clearance, so it only finds the line blocked when
         --  the tilt needed was more than the camera can give.
         function Reach (P : Float) return Float is
         begin
            for K in 1 .. 64 loop
               declare
                  S : constant Float := C.Dist * Float (K) / 64.0;
                  H : constant Float := S * Cos (P);
               begin
                  if H > Skip
                    and then Fz + S * Sin (P) < Top (C.X + Cy * H, C.Y + Sy * H) + 0.5 * Clearance
                  then
                     return Float'Max (2.0, S - C.Dist / 64.0);
                  end if;
               end;
            end loop;
            return C.Dist;
         end Reach;

         P     : constant Float := Needed;
         Limit : Float;
      begin
         C.Held_Pitch := C.Held_Pitch + (P - C.Held_Pitch)
           * (1.0 - Exp (-Dt * (if P > C.Held_Pitch then 6.0 else 1.5)));
         --  Distance answers only to the tilt the terrain needs: while the
         --  camera is still rising toward it the eye guard below keeps it
         --  clear, so the view doesn't pump in and out.
         Limit := Reach (P);
         C.Held := C.Held + (Float'Min (C.Dist, Limit) - C.Held)
           * (1.0 - Exp (-Dt * (if Limit < C.Held then 8.0 else 2.0)));

         --  The last guard: never within 0.6 m of the ground under the eye.
         declare
            Ex : constant Float := C.X + C.Held * Cos (C.Held_Pitch) * Cy;
            Ey : constant Float := C.Y + C.Held * Cos (C.Held_Pitch) * Sy;
            Ez : constant Float := Fz + C.Held * Sin (C.Held_Pitch);
         begin
            C.Lift := Float'Max (0.0, Ground (W, Ex, Ey) + 0.6 - Ez);
         end;
      end;
   end Update;

   function Eye (C : State) return Vec3 is
     ((C.X + C.Held * Cos (C.Held_Pitch) * Cos (C.Yaw),
       C.Y + C.Held * Cos (C.Held_Pitch) * Sin (C.Yaw),
       C.Z + 1.5 + C.Held * Sin (C.Held_Pitch) + C.Lift));

   function View_Proj (C : State; Aspect : Float) return Mat4 is
      E : constant Vec3 := Eye (C);
   begin
      return Perspective (Fov_Y, Aspect, Near_M, Far_M)
        * Look_Dir ((C.X - E.X, C.Y - E.Y, C.Z - E.Z), (0.0, 0.0, 1.0));
   end View_Proj;

end Castle.Camera;
