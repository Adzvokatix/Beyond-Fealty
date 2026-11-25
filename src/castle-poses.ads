with Castle.Math;   use Castle.Math;
with Castle.Bodies; use Castle.Bodies;

--  Where every bone of a serf is: a Pose (a handful of angles, where the
--  pelvis is, where the feet stand, where the hands reach) solved into a
--  world frame per bone.  Legs, and arms that reach for something, are
--  solved by two-bone IK (the law of cosines, as .kkrieger's limb operator
--  did): knees bend forward, elbows back.  The boxes then hang from the
--  frames (Castle.Figures draws them).
package Castle.Poses is

   type Frame is record
      X : Vec3 := (1.0, 0.0, 0.0);   --  the bone's right,
      Y : Vec3 := (0.0, 1.0, 0.0);   --  forward
      Z : Vec3 := (0.0, 0.0, 1.0);   --  and up (its box hangs down Z from the joint)
      O : Vec3;                      --  the joint, world metres
   end record;
   type Frames is array (Bone) of Frame;

   function Place (F : Frame; P : Vec3) return Vec3;
   --  A point given in body pixels in the bone's frame, in world metres.

   type Per_Side is array (Side) of Float;
   type Points is array (Side) of Vec3;
   type Flags is array (Side) of Boolean;

   type Pose is record
      Pelvis   : Vec3;                  --  the pelvis joint, world metres
      Heading  : Float := 0.0;          --  facing (cos, sin): 0 east, pi/2 north
      Lean     : Float := 0.0;          --  the pelvis pitched forward (rad)
      Tilt     : Float := 0.0;          --  and rolled, right side down
      Bend     : Float := 0.0;          --  the chest bent forward from the pelvis
      Twist    : Float := 0.0;          --  and turned left from it (counter-rotation)
      Look_Yaw, Look_Pitch : Float := 0.0;   --  the head, turned left and tipped down, from the chest
      Swing    : Per_Side := [others => 0.0];    --  upper arm forward
      Spread   : Per_Side := [others => 0.06];   --  upper arm out from the side
      Elbow    : Per_Side := [others => 0.15];   --  forearm forward from the upper arm
      Fore_In  : Per_Side := [others => 0.0];    --  and back in toward the body from it (rad, about the
                                                  --  forward axis): the elbow out of the line of the arm
      Reach    : Flags    := [others => False];  --  arm solved to Hand instead
      Hand     : Points;                          --  wrist targets, world
      Grip     : Per_Side := [others => 0.0];    --  0 to 1: what the hand holds turned from along
                                                  --  the forearm to upright across it (a bow drawn)
      Elbows   : Per_Side := [others => 0.0];    --  an arm solved to Hand: 0, its elbow goes back (down
                                                  --  and out a little: reaching out for something); 1,
                                                  --  down by the ribs and out (a hand held before the
                                                  --  chest: eating)
      Foot     : Points;                          --  ankle targets, world
      Foot_Heading : Per_Side := [others => 0.0];
   end record;

   function Standing (R : Rig; Ground : Vec3; Heading : Float) return Pose;
   --  At rest, feet under the hips, on the ground at Ground.

   procedure Solve (R : Rig; P : Pose; F : out Frames);

   function Chest_Frame (R : Rig; P : Pose) return Frame;
   --  The chest's frame as Solve gives it (its joint, at the waist; X the
   --  body's right, Y forward, Z up the trunk as it leans, bends and
   --  twists): for whoever places a hand before the chest and not at a
   --  point of the world.

   procedure Two_Bone
     (Root, Target, Pole : Vec3;     --  Pole: the side the middle joint bends toward
      A, B               : Float;    --  the two lengths
      Mid, Tip           : out Vec3; --  Tip is Target, or as far toward it as reaches
      Reached            : out Boolean);

   function Unwrap (Angle, Near : Float) return Float;
   --  Angle plus whole turns, as close as can be to Near: feed headings to
   --  a filter this way so it never spins the long way round.

   function Rotate (V, Axis : Vec3; Angle : Float) return Vec3;
   --  Right-handed about a unit axis.

end Castle.Poses;
