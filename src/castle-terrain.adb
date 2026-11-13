with Castle.Hash;     use Castle.Hash;
with Castle.Noise;    use Castle.Noise;
with Castle.Fields;   use Castle.Fields;
with Castle.Channels; use Castle.Channels;
with Castle.Jobs;
with Ada.Unchecked_Deallocation;
with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;

package body Castle.Terrain is

   --  Identity up to Knee_M, then x / (1 + x) toward Terrain_Cap_M: smooth
   --  (slope 1 at the knee) and plain arithmetic, so it stays deterministic.
   function Soft_Ceiling (H : Float) return Float is
      Span : constant Float := Terrain_Cap_M - Knee_M;
   begin
      if H <= Knee_M then
         return H;
      end if;
      declare
         T : constant Float := (H - Knee_M) / Span;
      begin
         return Knee_M + Span * T / (1.0 + T);
      end;
   end Soft_Ceiling;

   procedure Generate (W : in out Castle.Maps.World) is
      S_WX : constant U64 := W.Ch (Warp_X);
      S_WY : constant U64 := W.Ch (Warp_Y);
      S_HM : constant U64 := W.Ch (Hill_Mask);
      S_MM : constant U64 := W.Ch (Mountain_Mask);
      S_PL : constant U64 := W.Ch (Plains);
      S_HI : constant U64 := W.Ch (Hills);
      S_RI : constant U64 := W.Ch (Ridges);
      Base : constant Float := Castle.Dims.Base_Elevation_M;
      S_CL : constant U64 := W.Ch (Cliffs);
      S_CP : constant U64 := W.Ch (Cliff_Phase);
      S_CS : constant U64 := W.Ch (Cliff_Step);
      S_CE : constant U64 := W.Ch (Cliff_Edge);
      Hgt  : Field renames W.Height.all;
      Mtn  : Field renames W.Mountain.all;
      Raw  : Field_Access := New_Field;    --  heights before the cliff pass
      Hl   : Field_Access := New_Field;    --  hill district 0 .. 1

      procedure Row (Y : Integer) is
         Py : constant Float := Float (Y) + 0.5;
      begin
         for X in 0 .. N - 1 loop
            declare
               Px     : constant Float := Float (X) + 0.5;
               Wx     : constant Float := Px + 90.0 * FBM_2 (S_WX, Px / 520.0, Py / 520.0, 3);
               Wy     : constant Float := Py + 90.0 * FBM_2 (S_WY, Px / 520.0, Py / 520.0, 3);
               Hill   : constant Float :=
                 Smoothstep (-0.10, 0.30, FBM_2 (S_HM, Wx / 760.0, Wy / 760.0, 3));
               M      : constant Float :=
                 Smoothstep (0.16, 0.46, FBM_2 (S_MM, Wx / 980.0, Wy / 980.0, 3));
               Swell  : constant Float := 1.6 * FBM_2 (S_PL, Wx / 170.0, Wy / 170.0, 4);
               Hill_H : constant Float := 8.0 + 5.0 * FBM_2 (S_HI, Wx / 210.0, Wy / 210.0, 5);
               R      : constant Float := Ridged_2 (S_RI, Wx / Ridge_Scale_M, Wy / Ridge_Scale_M, 6);
            begin
               Raw (Idx (X, Y)) :=
                 Float'Max (1.0, Base + Swell + Hill * Hill_H + M * (4.0 + Mountain_Relief_M * R * R));
               Mtn (Idx (X, Y)) := M;
               Hl (Idx (X, Y))  := Hill;
            end;
         end loop;
      end Row;

      --  Cliff bands.  Where the ground is steep enough, inside patches of
      --  hill and mountain country, heights are remapped through a terrace
      --  curve: flat-ish ledges and risers that are nearly vertical.  The
      --  curve only reorders nothing (it rises with the height it is given),
      --  so it makes no new hollows for the hydrology to fill.  Riser height,
      --  sharpness and the level the steps start from all wander with noise,
      --  so the bands break up and meander instead of ringing every hill.
      procedure Cliff_Row (Y : Integer) is
         Py : constant Float := Float (Y) + 0.5;
      begin
         for X in 0 .. N - 1 loop
            declare
               K     : constant Cell_Range := Idx (X, Y);
               Px    : constant Float := Float (X) + 0.5;
               H0    : constant Float := Raw (K);
               Gx    : constant Float := (At_Cell (Raw.all, X + 1, Y) - At_Cell (Raw.all, X - 1, Y)) * 0.5;
               Gy    : constant Float := (At_Cell (Raw.all, X, Y + 1) - At_Cell (Raw.all, X, Y - 1)) * 0.5;
               Slope : constant Float := Sqrt (Gx * Gx + Gy * Gy);
               Mask  : constant Float :=
                 Smoothstep (0.0, 0.3, FBM_2 (S_CL, Px / 340.0, Py / 340.0, 3))
                 * Smoothstep (0.15, 0.45, Mtn (K) + 0.6 * Hl (K))
                 * Smoothstep (0.22, 0.55, Slope);
               H     : Float := H0;
            begin
               if Mask > 0.0 then
                  declare
                     Step  : constant Float :=
                       Cliff_Step_Min_M + (Cliff_Step_Max_M - Cliff_Step_Min_M)
                         * Smoothstep (-0.4, 0.4, FBM_2 (S_CS, Px / 260.0, Py / 260.0, 2));
                     Phase : constant Float := Step * FBM_2 (S_CP, Px / 110.0, Py / 110.0, 2);
                     Edge  : constant Float :=
                       0.05 + 0.10 * Smoothstep (-0.3, 0.5, FBM_2 (S_CE, Px / 150.0, Py / 150.0, 2));
                     T     : constant Float := (H0 - Phase) / Step;
                     Lvl   : constant Float := Float'Floor (T);
                     Ter   : constant Float :=
                       (Lvl + Smoothstep (0.5 - Edge, 0.5 + Edge, T - Lvl)) * Step + Phase;
                  begin
                     H := H0 + Mask * Cliff_Strength * (Ter - H0);
                  end;
               end if;
               Hgt (K) := Soft_Ceiling (Float'Max (1.0, H));
            end;
         end loop;
      end Cliff_Row;

      procedure Rows is new Castle.Jobs.Parallel_For (Row);
      procedure Cliff_Rows is new Castle.Jobs.Parallel_For (Cliff_Row);
      procedure Free is new Ada.Unchecked_Deallocation (Field, Field_Access);
   begin
      Rows (0, N - 1, Grain => 8);
      Cliff_Rows (0, N - 1, Grain => 8);
      Free (Raw);
      Free (Hl);
   end Generate;

end Castle.Terrain;
