with Castle.Bodies; use Castle.Bodies;
with Castle.Poses;  use Castle.Poses;
with Castle.Math;   use Castle.Math;

--  Deer, made the way serfs are: boxes on the 5 cm pixel grid with a
--  painted skin, hung on the same fifteen bones put to a four-legged use:
--  Pelvis is the hindquarters (its joint the hips), Chest the forequarters
--  (the withers), Head the neck and head together (rooted at the front of
--  the chest, so lowering it to graze swings both), the arm bones the
--  forelegs (upper leg, cannon, hoof) and the leg bones the hind legs
--  (thigh, shank, hoof).
--
--  A look is made per class and coat, not per animal (texture layers are
--  shared with the serfs): a fawn (small, dappled), a doe, a young stag
--  (spikes) and a stag (branched antlers), each in a summer and a winter
--  coat.  Castle.Animals moves them and Castle.Figures draws them.
package Castle.Deer is

   type Class is (Fawn, Doe, Young_Stag, Stag);

   --  The shape of its boxes (Castle.Bodies.Box.Round, Taper; first values).
   Barrel_Round : constant := 2.0;    --  the rounding of the hindquarters and forequarters, body pixels
   Haunch_Taper : constant := 0.35;   --  an upper leg narrows by this share to the knee or the hock
   Neck_Taper   : constant := 0.2;    --  the neck, to the head

   type Standing_Mode is (Idle, Graze, Alert);
   --  What a deer does when it is not going anywhere.  The herds decide it
   --  (Castle.Herds, which saves it by position) and Castle.Animals shows it.

   type Dims is record     --  metres
      Hip_H, Shoulder_H : Float := 0.0;   --  the hip and shoulder joints above the ground, standing
      Spine      : Float := 0.0;          --  hips to shoulders
      Half_W     : Float := 0.0;          --  each leg out from the middle
      Fore_Upper, Fore_Lower : Float := 0.0;
      Hind_Upper, Hind_Lower : Float := 0.0;
      Hoof       : Float := 0.0;          --  the fetlock above the ground
      Neck_Root  : Vec3 := (0.0, 0.0, 0.0);   --  in the chest's frame (X right, Y forward, Z up)
      Neck_Len   : Float := 0.0;          --  root to the poll
      Size       : Float := 1.0;          --  an adult doe is 1
   end record;

   function Dims_Of (C : Class) return Dims;

   procedure Build (C : Class; Winter : Boolean; R : out Rig; Skin : out Skin_Pixels);
   --  Raises Program_Error if the nets don't fit the skin (deer_check
   --  builds every class and coat to make sure they do).

   type Leg is (Fore_L, Fore_R, Hind_L, Hind_R);
   type Leg_Points is array (Leg) of Vec3;
   function Is_Fore (L : Leg) return Boolean is (L in Fore_L | Fore_R);
   function Is_Left (L : Leg) return Boolean is (L in Fore_L | Hind_L);

   type Pose is record
      Hips      : Vec3 := (0.0, 0.0, 0.0);   --  the hip joints' middle, world metres
      Shoulders : Vec3 := (0.0, 1.0, 0.0);   --  the shoulder joints' middle
      Roll      : Float := 0.0;     --  the body tilted, right side down (rad)
      Flex      : Float := 0.0;     --  the back arched (rad): hindquarters and forequarters pitched apart
      Neck      : Float := 0.5;     --  the neck from upright toward forward (rad): about 0.3 alert,
                                    --  0.8 walking, 1.3 running, 2.3 grazing (head to the ground)
      Neck_Yaw  : Float := 0.0;     --  turned left
      Hoof      : Leg_Points := [others => (0.0, 0.0, 0.0)];   --  each fetlock (the top of the hoof), world
   end record;

   type Leg_Flags is array (Leg) of Boolean;
   procedure Solve (D : Dims; P : Pose; F : out Frames; Reached : out Leg_Flags);
   --  A frame per bone; the legs by two-bone IK (forelegs' knees forward,
   --  hind hocks back).  Reached: each hoof was within its leg's reach (a
   --  leg that can't reach points at its hoof, straight).

   function Bone_Of (L : Leg; Part : Positive) return Bone;
   --  Part 1 the upper leg, 2 the lower, 3 the hoof.

end Castle.Deer;
