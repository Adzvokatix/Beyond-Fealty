with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Castle.Climate;
with Castle.Hash;
with Interfaces;

--  Save files: the seed and generator version the world came from, the
--  clock and what the weather has left behind, the camera, and every edit.
--  The generated world itself is never stored: it is made again from the
--  seed.  Written to a temporary file and renamed over the old save, so a
--  crash mid-save cannot leave a broken one; a checksum guards the rest.
package Castle.Saves is

   type Blob is array (Natural range <>) of Interfaces.Unsigned_8;
   type Blob_Access is access Blob;

   type Snapshot is record
      Seed    : Castle.Hash.U64 := 1;
      Clock   : Long_Float := 0.0;
      Climate : Castle.Climate.State;
      Cam_X, Cam_Y, Cam_Yaw, Cam_Pitch, Cam_Dist : Float := 0.0;
      Colony  : Blob_Access;   --  the colony as Castle.Colony.Save gives it (null: none)
   end record;

   procedure Save (Path : String; S : Snapshot; Error : out Unbounded_String);
   --  Error comes back empty on success.

   procedure Peek (Path : String; Seed : out Castle.Hash.U64; Error : out Unbounded_String);
   --  The seed a save was made with (the world has to be made from it first).

   procedure Load (Path : String; S : out Snapshot; Error : out Unbounded_String);
   --  Restores the edits as well; the caller applies the rest.

end Castle.Saves;
