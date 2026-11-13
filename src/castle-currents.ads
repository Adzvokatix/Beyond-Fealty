with Castle.Fields; use Castle.Fields;
with Castle.Maps;   use Castle.Maps;

--  Currents: which way and how fast the generated water runs, in 1 m
--  cells, for the water's flow maps.  A river or stream runs down its
--  channel's trunk at the speed its discharge needs (discharge over width
--  and depth); that current spreads across the channel and is smoothed,
--  so the D8 drainage's 45-degree turns don't show, and slows toward the
--  banks.  Lakes lie still but for the pull near their inlets and
--  outlets, which fades a few metres out.
package Castle.Currents is

   procedure Build (W : World);

   function East  return Field_Access;   --  m/s toward +x (null before Build)
   function North return Field_Access;   --  m/s toward +y

   --  The discharge (m^3/s) of the channel a 1 m cell lies in, its
   --  trunk's carried across its width; 0.0 off the channels.
   function Discharge (Xm, Ym : Integer) return Float;

   --  Bilinear current at a point (metres), for blocks.
   procedure Sample (X, Y : Float; To_East, To_North : out Float);

end Castle.Currents;
