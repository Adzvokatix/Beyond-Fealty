with Castle.Colony; use Castle.Colony;
with Castle.Hash;
with Castle.Math;   use Castle.Math;
with Castle.Text;

--  The action table: what an actor can do to the world by intent.  Each
--  action is a named row saying what it is done to and who may do it, and
--  every interface (the development panels, the game's context menus, the
--  command line) acts through Perform and nothing else: no interface has an
--  action of its own.
--
--  The player and the serfs are one kind of actor (Castle.Colony.Actor)
--  using this one set of actions; rank narrows what each may do.  Today the
--  player may do every one and a serf none: a row's Least is the lowest
--  rank that may, and comes down as roles arrive (a farmer directing his
--  hands).  A context menu is Menu_For: what this actor may do to that
--  thing, now.
--
--  What is not here: what the band does for itself (gathering, hunting,
--  cooking: its jobs' own work), and Castle.Colony.Supply, which conjures
--  goods for scripted starts and checks and is nobody's to do.
package Castle.Actions is

   type Action is
     (Raise_Stake,        --  the homestake, once
      Lay_Path,           --  a footpath from one point to another
      Zone_Stockpile,     --  a stockpile, corner to corner
      Zone_Camp,          --  the camp, its fire here
      Give_Job,           --  a person's job (its starting job, until hiring)
      Follow,             --  keep the eye on a person (the interface's own: nothing in the colony changes)
      Set_Reserve,        --  the surplus to keep of a kind: wood, straw, meat, vegetables
      Set_Winter_Store,   --  days of food held back for winter
      Spare_Apples,       --  a protection: apple trees are not felled
      Spare_Deer,         --  a protection: deer are not hunted
      Zone_Housing);      --  housing, corner to corner: where the band may build its homes

   --  What an action is done to.  The reserves belong to the stockpiles
   --  (every stockpile stands for the colony's stores until zones have
   --  their own); the protections to the colony.
   type Target_Kind is (The_Ground, A_Person, A_Stockpile, The_Camp, A_Deer, The_Colony);

   type Rank is (Nobody, Serf, Leader);
   function Rank_Of (Who : Actor) return Rank;

   type Row is record
      Name  : Castle.Text.Line;     --  as a menu or a log names it
      On    : Target_Kind;
      Least : Rank;                 --  the lowest rank that may do it
   end record;
   function Row_Of (A : Action) return Row;
   function Name (A : Action) return String;
   function May (Who : Actor; A : Action) return Boolean;

   ------------------------------------------------------------------ orders

   type Order (What : Action := Follow) is record
      By : Actor := The_Player;
      case What is
         when Raise_Stake =>
            Stake_At : Vec3 := (0.0, 0.0, 0.0);      --  a point on the ground (metres)
         when Lay_Path =>
            From, To : Vec3 := (0.0, 0.0, 0.0);
         when Zone_Stockpile | Zone_Housing =>
            X0, Y0, X1, Y1 : Float := 0.0;           --  corners, in either order
         when Zone_Camp =>
            Fire_At : Vec3 := (0.0, 0.0, 0.0);
         when Give_Job | Follow =>
            Whom : Natural := 0;                     --  the member (Follow 0: nobody any more)
            Job  : Job_Kind := Unassigned;           --  Give_Job
         when Set_Reserve =>
            Kind   : Item_Kind := Nothing;
            Amount : Natural := 0;
         when Set_Winter_Store =>
            Days : Natural := 0;
         when Spare_Apples | Spare_Deer =>
            On : Boolean := True;
      end case;
   end record;

   type Refusal is
     (None,
      Not_Permitted,        --  this actor may not do it
      No_Such_Target,       --  nobody, or nothing, of that kind to do it to
      Not_Now,              --  the colony is not ready for it (no stake yet; a stake already)
      The_Ground_Refused);  --  the world would not have it there (Why_Not says why)
   type Result is record
      Done  : Boolean := False;
      Count : Natural := 0;         --  blocks of path laid, cells zoned, hovels a housing zone has room for
      Why   : Refusal := None;
   end record;

   procedure Perform (O : Order; R : out Result);
   function Why_Not (O : Order; R : Result) return String;   --  "" if it was done

   procedure Set_Arrivals (Band : Positive; Seed : Castle.Hash.U64);
   --  Who comes when the stake is raised: how many, and the seed they are
   --  made from.  The world's to say, not the actor's (the game and the
   --  runner set it from the command line and the world's seed).

   ------------------------------------------------------------------ what one may do to a thing

   type Target is record
      Kind  : Target_Kind := The_Ground;
      Index : Natural := 0;                    --  the member, the zone, the deer
      Point : Vec3 := (0.0, 0.0, 0.0);         --  where on the ground
   end record;

   Reserve_Step : constant := 10;              --  a reserve goes up and down by this

   type Step_Kind is (Single, Fewer, More);
   --  Fewer is always followed by its More: together one line of a menu, a
   --  step down and a step up of the same number.
   type Choice is record
      Label     : Castle.Text.Line;
      Todo      : Order;
      Two_Point : Boolean := False;   --  Todo holds the first point: the interface asks for the other
                                      --  (a path's far end, a stockpile's far corner) before it performs it
      Is_Now    : Boolean := False;   --  how things already stand (a person's present job)
      Step      : Step_Kind := Single;
   end record;
   Max_Choices : constant := 24;
   type Choice_List is array (1 .. Max_Choices) of Choice;
   type Menu is record
      Title : Castle.Text.Line;
      N     : Natural := 0;
      Items : Choice_List;
   end record;

   function Menu_For (Who : Actor; T : Target) return Menu;
   --  What Who may do to T as things stand, from the table: nothing (N = 0)
   --  where there is nothing, or nothing permitted.

   function Job_Name (J : Job_Kind) return String;   --  "gatherer"; "no job" for Unassigned

end Castle.Actions;
