with Castle.Second_Order;

--  Second-order dynamics on one number: a height, an angle (unwrap it
--  first: Castle.Poses.Unwrap), a weight.
package Castle.Second_Order_1 is new Castle.Second_Order (Vec => Float, Zero => 0.0);
