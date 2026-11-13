with Castle.Math; use Castle.Math;
with Castle.Second_Order;

--  Second-order dynamics on a point or a direction in space.
package Castle.Second_Order_3 is new Castle.Second_Order (Vec => Vec3, Zero => (0.0, 0.0, 0.0));
