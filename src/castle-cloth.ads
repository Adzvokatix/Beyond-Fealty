with Castle.Math; use Castle.Math;

--  Cloth (John, 2026-11-13: "can we have the cloaks be dynamic cloth ...
--  it would be a very cool touch and would translate well when we get to
--  other wearable items later in production"): a sheet of particles, Nu
--  across and Nv down, held to each other by their rest lengths (each to
--  the next across and down, each to the next but one, and corner to
--  corner), falling under its own weight, pushed out of the capsules of
--  whatever body it hangs on or lies over and off the ground.  Its top row
--  can be pinned to points given each frame (what holds it up: shoulders,
--  a peg); unpinned it falls, and once it has lain still a while it is
--  frozen: not stepped at all until it is woken (a frozen sheet is dead
--  still, so its shadow is).
--
--  It knows nothing of cloaks, nor of the colony: it is drawing only,
--  stepped by drawn time (a recording repeats), nothing of it saved.  What
--  it hangs from and where it lies is its user's to say each frame.
--  Main thread only.
package Castle.Cloth is

   Nu : constant := 6;               --  particles across
   Nv : constant := 7;               --  and down: (Nu - 1) x (Nv - 1) panels, thirty
   Max_Cloths : constant := 512;

   subtype Cloth_Id is Natural range 0 .. Max_Cloths;    --  0: none

   function New_Cloth (Width, Length : Float) return Cloth_Id;
   --  A sheet Width across and Length down (metres), lying nowhere yet: say
   --  where with Lay or Hang before it is first stepped.  0 when every slot
   --  is taken.
   procedure Free (C : in out Cloth_Id);
   procedure Free_All;

   type Row_Points is array (1 .. Nu) of Vec3;

   procedure Hang (C : Cloth_Id; Top : Row_Points; Down : Vec3);
   --  Its top row put at Top and the rest hung straight from it along Down
   --  (a unit vector), still: as it is put on, or after a jump.
   procedure Lay (C : Cloth_Id; Corner, Across, Down : Vec3);
   --  Flat, still and unpinned: its first row from Corner along Across (the
   --  whole width), the rest along Down (the whole length).  Woken.

   procedure Pin (C : Cloth_Id; Top : Row_Points);
   --  This frame its top row is held at Top (until Unpin).
   procedure Unpin (C : Cloth_Id);
   function Pinned (C : Cloth_Id) return Boolean;

   type Capsule is record
      A, B : Vec3;                   --  the ends of its spine
      R    : Float;                  --  its radius
   end record;
   type Capsules is array (Positive range <>) of Capsule;

   procedure Step (C : Cloth_Id; Dt : Float; Over : Capsules; Ground_Z : Float; Stick : Boolean := False);
   --  Dt seconds on (drawn time; at most a twentieth is taken), kept out of
   --  Over's capsules (the body it hangs on or lies over) and above
   --  Ground_Z.  Nothing, when frozen.  Stick: a point that has come to rest
   --  on a capsule or the ground stays there (until it is laid, hung or let
   --  go again), so that a sheet laid over a body drapes from where it first
   --  rests on it and does not slide off a narrow back.
   function Frozen (C : Cloth_Id) return Boolean;
   procedure Wake (C : Cloth_Id);

   function Point (C : Cloth_Id; I, J : Positive) return Vec3;   --  I across 1 .. Nu, J down 1 .. Nv

   --  What a step cost, all told (for whatever measures it).
   Steps_Taken : Natural := 0;

end Castle.Cloth;
