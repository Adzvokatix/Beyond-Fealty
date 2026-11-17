with Interfaces;

--  The game's colour palette, from the designer's "Medieval Game Color
--  Palette" (docs/design/color_palette.txt; its hex codes are
--  the source, the picture only illustrates them).  Colours in the game
--  come from here by name, so the look can be retuned in one place.
--
--  Muted environmental colours are for the world: terrain, stone, wood,
--  foliage, night and interiors.  Rich contrasting colours are for what
--  should stand out: banners, clothing, the UI, blood, gold, magic and
--  important characters.
package Castle.Colors with Pure is

   type RGB is record
      R, G, B : Interfaces.Unsigned_8;
   end record;

   --  Each palette colour is its hex code, as written in the palette
   --  (a static number, so Pure units can build tables of them).
   type Hex_Code is range 0 .. 16#FF_FFFF#;

   function Of_Hex (H : Hex_Code) return RGB is
     ((R => Interfaces.Unsigned_8 (H / 16#1_0000#),
       G => Interfaces.Unsigned_8 (H / 16#100# mod 16#100#),
       B => Interfaces.Unsigned_8 (H mod 16#100#)));

   ------------------------------------------- muted environmental colours

   Ash_Stone        : constant := 16#3C3C3C#;
   Weathered_Oak    : constant := 16#4A3428#;
   Deep_Forest      : constant := 16#1B3329#;
   River_Slate      : constant := 16#2D3E48#;
   Shadow_Earth     : constant := 16#3F2C22#;
   Mist_Iron        : constant := 16#4A5560#;
   Moss_Shadow      : constant := 16#24362C#;
   Cool_Stone_Blue  : constant := 16#3A4550#;
   Dusk_Blue        : constant := 16#2F3F52#;
   Fog_Blue         : constant := 16#4C5C68#;

   Pine_Shadow      : constant := 16#1A2E26#;
   Olive_Dark       : constant := 16#2F3B2A#;
   Marsh_Green      : constant := 16#2A4035#;

   Dark_Bark        : constant := 16#3A2A1E#;
   Mudstone         : constant := 16#4E3B2F#;
   Ashen_Brown      : constant := 16#5A4638#;

   Charcoal         : constant := 16#2A2A2A#;
   Stone_Gray       : constant := 16#4A4E52#;
   Fog_Gray         : constant := 16#5C6268#;
   Blue_Gray_Shadow : constant := 16#3A4550#;

   ------------------------------------------- rich contrasting colours

   Heraldic_Crimson    : constant := 16#8B1E1E#;
   Burgundy_Velvet     : constant := 16#5C1518#;
   Gilded_Amber        : constant := 16#B08D3E#;
   Aged_Gold           : constant := 16#C9A227#;
   Royal_Indigo        : constant := 16#1E3A5F#;
   Deep_Emerald        : constant := 16#0E4F3A#;
   Warm_Copper         : constant := 16#8B4513#;
   Storm_Blue          : constant := 16#2A4A7A#;
   Sapphire            : constant := 16#2458A0#;
   Twilight_Purple     : constant := 16#3D2A5C#;
   Royal_Violet        : constant := 16#4A306E#;
   Brightened_Crimson  : constant := 16#A52828#;
   Brightened_Gold     : constant := 16#D4B84A#;
   Brightened_Sapphire : constant := 16#3A6EB8#;

   Deep_Hunter       : constant := 16#0F5A3A#;
   Emerald_Lift      : constant := 16#1A6B4A#;
   Forest_Gold_Green : constant := 16#3D5C2E#;

   Aged_Leather : constant := 16#6B3E26#;
   Copper_Brown : constant := 16#8B5A2B#;
   Warm_Umber   : constant := 16#7A4E2A#;

   Iron           : constant := 16#3F4A52#;
   Silvered_Steel : constant := 16#6A7278#;
   Warm_Gray      : constant := 16#5A534C#;

   ------------------------------------------- derived (no palette entry fits)
   --  Each is worked out by hand from named entries above; keep the sum
   --  in the comment so it can be redone if those change.

   Sand_Tan  : constant := 16#857045#;   --  Gilded_Amber and Warm_Gray, half and half
   Salt_Pale : constant := 16#AAB6C0#;   --  Silvered_Steel x 1.6
   Grass_Seed : constant := 16#546631#;  --  Forest_Gold_Green 80 %, Gilded_Amber 20 %
   Aspen_Green : constant := 16#637335#; --  Forest_Gold_Green 75 %, Brightened_Gold 25 %
   Sprout_Green : constant := 16#62934A#; --  Forest_Gold_Green x 1.6
   Flame_Core  : constant := 16#FEDD59#; --  Brightened_Gold x 1.2
   Flame_Edge  : constant := 16#DE6E1E#; --  Warm_Copper x 1.6
   Ember_Glow  : constant := 16#D63434#; --  Brightened_Crimson x 1.3
   Abyss_Blue  : constant := 16#0F1D30#; --  Royal_Indigo x 0.5: the deepest water
   Thatch_Straw : constant := 16#967C42#; --  Gilded_Amber 70 %, Warm_Gray 30 %: a roof of straw, weathered
   Daub_Clay    : constant := 16#BDAEA0#; --  Warm_Gray x 2.1: a wall of wattle and daub, dried pale
   Field_Stone  : constant := 16#6D6D6C#; --  Fog_Gray and Warm_Gray, half and half, x 1.2: a wall of gathered stones

end Castle.Colors;
