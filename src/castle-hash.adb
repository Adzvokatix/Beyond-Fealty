package body Castle.Hash is

   use Interfaces;

   K1 : constant U64 := 16#9E37_79B9_7F4A_7C15#;
   K2 : constant U64 := 16#C2B2_AE3D_27D4_EB4F#;
   K3 : constant U64 := 16#1656_67B1_9E37_79F9#;

   function Mix (X : U64) return U64 is
      Z : U64 := X;
   begin
      Z := (Z xor Shift_Right (Z, 30)) * 16#BF58_476D_1CE4_E5B9#;
      Z := (Z xor Shift_Right (Z, 27)) * 16#94D0_49BB_1331_11EB#;
      return Z xor Shift_Right (Z, 31);
   end Mix;

   function Derive (Seed, Channel : U64) return U64 is
   begin
      return Mix (Seed + Mix (Channel * K2 + K1));
   end Derive;

   function Hash_2 (Seed : U64; X, Y : Integer) return U64 is
   begin
      return Mix (Seed xor (U64'Mod (X) * K1 + U64'Mod (Y) * K2));
   end Hash_2;

   function Hash_3 (Seed : U64; X, Y, Z : Integer) return U64 is
   begin
      return Mix (Seed xor (U64'Mod (X) * K1 + U64'Mod (Y) * K2 + U64'Mod (Z) * K3));
   end Hash_3;

   function Unit (H : U64) return Float is
   begin
      return Float (Shift_Right (H, 40)) * (1.0 / 16_777_216.0);
   end Unit;

   function Unit_2 (Seed : U64; X, Y : Integer) return Float is
   begin
      return Unit (Hash_2 (Seed, X, Y));
   end Unit_2;

   function Unit_3 (Seed : U64; X, Y, Z : Integer) return Float is
   begin
      return Unit (Hash_3 (Seed, X, Y, Z));
   end Unit_3;

end Castle.Hash;
