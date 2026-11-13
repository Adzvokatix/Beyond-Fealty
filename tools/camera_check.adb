with Ada.Text_IO;   use Ada.Text_IO;
with Castle.Camera;
with Castle.Fields; use Castle.Fields;
with Castle.Hash;
with Castle.Maps;   use Castle.Maps;
with Castle.Math;   use Castle.Math;
with Castle.Text;   use Castle.Text;
with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Castle.Worldgen;

--  Drives the game camera across the tallest mountain of seed 1 at a steady
--  pan, 60 frames a second, with no rendering, and reports how smoothly it
--  rode: the biggest frame-to-frame change in the eye's velocity (a whip
--  shows as a spike), in tilt and in distance, and any frame the eye was
--  less than 0.3 m above the ground under it.
procedure Camera_Check is
   W  : World;
   Dt : constant Float := 1.0 / 60.0;

   procedure Run (Label : String; Pitch, Dist, Yaw : Float) is
      C        : Castle.Camera.State;
      E, Last  : Vec3;
      V, Last_V : Vec3 := (0.0, 0.0, 0.0);
      Last_P, Last_D : Float := 0.0;
      Jerk, Turn, Zoom, Low : Float := 0.0;
      Under    : Natural := 0;
   begin
      Castle.Camera.Reset (C, 1_080.0, 1_233.0, W);
      C.Yaw := Yaw;   C.T_Yaw := Yaw;
      C.Pitch := Pitch; C.T_Pitch := Pitch; C.Held_Pitch := Pitch;
      C.Dist := Dist; C.T_Dist := Dist; C.Held := Dist;
      for Frame in 1 .. 720 loop
         C.T_X := C.T_X + 0.6;                       --  36 m/s east, over the peak at x 1282
         Castle.Camera.Update (C, W, Dt);
         E := Castle.Camera.Eye (C);
         if Frame > 60 then
            V := E - Last;
            Jerk := Float'Max (Jerk, Sqrt (Dot (V - Last_V, V - Last_V)));
            Turn := Float'Max (Turn, abs (C.Held_Pitch - Last_P));
            Zoom := Float'Max (Zoom, abs (C.Held - Last_D));
            declare
               Clear : constant Float := E.Z - Sample (W.Height.all, E.X, E.Y);
            begin
               if Clear < 0.3 then
                  Under := Under + 1;
               end if;
               Low := Float'Min (Low, Clear);
            end;
         end if;
         Last := E; Last_V := V; Last_P := C.Held_Pitch; Last_D := C.Held;
      end loop;
      Put_Line (Label & ": biggest jolt " & Img (Jerk, 2) & " m/frame^2, tilt swing "
                & Img (Turn * 57.3, 1) & " deg/frame, zoom swing " & Img (Zoom, 1) & " m/frame, "
                & Img (Under) & " frames near or under ground");
   end Run;
begin
   Castle.Worldgen.Create (Castle.Hash.U64 (1), W, Report => False);
   Run ("low tilt, far ", 0.25, 120.0, -0.9);
   Run ("default       ", 0.62, 70.0, -0.9);
   Run ("close         ", 0.40, 25.0, -0.9);
   Run ("facing uphill ", 0.30, 60.0, 0.0);
end Camera_Check;
