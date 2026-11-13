package body Castle.Maps is

   procedure Allocate (W : out World; Seed : Castle.Hash.U64) is
   begin
      W.Seed := Seed;
      for C in W.Ch'Range loop
         W.Ch (C) := Castle.Hash.Derive (Seed, Castle.Hash.U64 (C));
      end loop;
      W.Height      := New_Field;
      W.Mountain    := New_Field;
      W.Water       := New_Field;
      W.Kind        := new Kind_Field;
      W.Down        := new Dir_Field;
      for K in Cell_Range loop
         W.Kind (K) := Dry;
         W.Down (K) := -1;
      end loop;
      W.Flow        := New_Field;
      W.Dist_Water  := New_Field;
      W.Moisture    := New_Field;
      W.Water_Table := New_Field;
      W.Aquifer     := New_Field;
      W.Slope       := New_Field;
      W.Fold        := New_Coarse;
      W.Granite_Top := New_Coarse;
      W.Deposits    := null;
      W.Index       := null;
      W.Tubes       := null;
      W.Tube_Start  := null;
      W.Tube_Item   := null;
   end Allocate;

end Castle.Maps;
