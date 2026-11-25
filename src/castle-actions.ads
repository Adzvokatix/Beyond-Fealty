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
      Set_Reserve,        --  the surplus to keep of a kind: wood, straw, meat, vegetables, apples
      Set_Winter_Store,   --  days of food held back for winter
      Spare_Apples,       --  a protection: apple trees are not felled
      Spare_Deer,         --  a protection: deer are not hunted
      Zone_Housing,       --  housing, corner to corner: where the band may build its homes
      Fill_Housing,       --  housing, all the ground inside a round of paths
      Place_Stockpile,    --  a stockpile put down whole with its path, held by its middle here and turned
                          --  (Castle.Colony.Place_Box); with Castle.Colony.Set_Box_Place off, the one
                          --  stockpile, Stockpile_Side_M square, beside a path here
      Zone_Stockyard,     --  the stockyard, corner to corner: where the storehouse is built, once
      Unzone_Housing,     --  ground taken out of the housing again, corner to corner; a hovel there is marked
      Mark_Hovel,         --  a hovel marked for razing, or the mark lifted
      Make_Builder,       --  a person set to building: a forester that takes a house before the others (for
                          --  development: Dev_Jobs)
      Pull_Housing,       --  housing pulled with its path: begun here, pulled to there, on the rows asked
                          --  (Castle.Colony.Pull_Housing)
      Place_Stockyard,    --  the stockyard put down whole with its path, twenty metres square, held by its
                          --  middle here and turned (Castle.Colony.Place_Box; with Castle.Colony.Set_Yard_Box
                          --  off the interface gives Zone_Stockyard, corner to corner, instead)
      Make_Stockman,      --  a person named the storehouse's stockman: a porter (Castle.Colony.Name_Stockman;
                          --  for development: Dev_Jobs)
      Make_Carpenter,     --  and its carpenter: a forester (Castle.Colony.Name_Carpenter; for development)
      Remove_Stockpile);  --  a stockpile removed, once what lies on it is carried off; or the order taken back
                          --  (Castle.Colony.Remove_Stockpile; never the stockyard)

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
            Stake_At  : Vec3 := (0.0, 0.0, 0.0);     --  a point on the ground (metres)
            As_Square : Boolean := False;            --  the homestake and the campfire one: a square of
                                                     --  Castle.Colony.Square_Side_M with its path round it, its
                                                     --  middle there (Castle.Colony.Place_Square); False: the
                                                     --  stake's post, the camp to be zoned apart
            Stake_Way : Castle.Colony.Way_Index := 0;   --  (As_Square: the way it is turned)
         when Lay_Path =>
            From, To : Vec3 := (0.0, 0.0, 0.0);
         when Zone_Stockpile | Zone_Housing | Zone_Stockyard | Unzone_Housing =>
            X0, Y0, X1, Y1 : Float := 0.0;           --  corners, in either order
         when Mark_Hovel =>
            Hovel  : Natural := 0;                   --  the house
            Marked : Boolean := True;
         when Remove_Stockpile =>
            Pile   : Natural := 0;                   --  its zone
            Remove : Boolean := True;                --  False: the order taken back
         when Zone_Camp =>
            Fire_At : Vec3 := (0.0, 0.0, 0.0);
         when Place_Stockpile | Place_Stockyard =>
            Pile_At  : Vec3 := (0.0, 0.0, 0.0);
            Pile_Way : Castle.Colony.Way_Index := 0;   --  the way it is turned (its path's, the box on the left)
         when Fill_Housing =>
            Inside : Vec3 := (0.0, 0.0, 0.0);        --  a point of the ground to be filled
         when Pull_Housing =>
            Begun, Pulled_To : Vec3 := (0.0, 0.0, 0.0);      --  where it was begun and where it was pulled to
            Rows : Castle.Colony.Pull_Rows := Castle.Colony.Side_Begun;   --  the side it was begun on, the other, both
         when Give_Job | Follow | Make_Builder | Make_Stockman | Make_Carpenter =>
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
      Count : Natural := 0;         --  blocks of path laid, cells zoned, hovels a housing zone has room for,
                                    --  block columns taken out of the housing
      Marked : Natural := 0;        --  Unzone_Housing: the hovels marked for razing
      Why   : Refusal := None;
   end record;

   --  The player's housing is pulled with its path (John, 2026-11-20: "it
   --  will include the path with the zone placement"): the Housing tool and
   --  the ground's menu give a Pull_Housing order.  Off (--no-housing-pull):
   --  a Zone_Housing order, beside a path that is there, as before.  What
   --  an order does is the order's own: this is only which the interface
   --  makes.  Not saved.
   Housing_Pull : Boolean := True;

   Path_Snap : Boolean := True;
   --  A path is ordered straight or at 45 degrees, its ends on corners of
   --  blocks (John, 2026-11-19: "I think we need to lock the paths to
   --  straight and 45 degree angles, slighty being off doesn't really work
   --  in a voxel world"; Castle.Colony.Path_Line_Start): Perform lays a
   --  Lay_Path order along Path_Begin (From) .. Path_Reach (that, To), and
   --  whoever shows a line before it is ordered shows it by the same two,
   --  so the line shown is the line laid.  Off (--no-path-snap): the line
   --  as it is given, as it was.  Not saved: it is how an order is read.
   function Path_Begin (P : Vec3) return Vec3;
   function Path_Reach (From, P : Vec3) return Vec3;

   Square_Stake : Boolean := True;
   --  The homestake the player raises is the square (John, 2026-11-20:
   --  "Let's merge the homestake and the campfire, no physical stake now"):
   --  the ground's menu and the Homestake tool give Raise_Stake orders with
   --  As_Square.  False (--no-square): the post, and the camp zoned apart, as
   --  before.  An order says which itself (the scripts' --stake is the post,
   --  --square the square), so this is only what the player's own are.  Not
   --  saved: it is how the player's order is made.

   Dev_Jobs : Boolean := True;
   --  The jobs a serf comes to by itself are on a person's menu too, for
   --  development (John, 2026-11-19: "We can assign jobs in the development
   --  ... so keep adding new jobs as we work them in to that list, but the
   --  player won't need to delegate further, past opening positions"):
   --  Builder, and since 2026-11-22 Cook, Stockman and Carpenter (his word
   --  that day: "The cook is earned by skill, but the development UI is the
   --  backend we can assign jobs however we want with the development UI,
   --  the player won't be able to", and "yes add the cook and the stockman
   --  and carpenter").  Cook keeps its row among the jobs; Builder, Stockman
   --  and Carpenter follow them.  False (the game's --no-dev-jobs): the
   --  opening jobs alone (no job, gatherer, forester, hunter, porter), as
   --  the player is to have it: no Cook either.  An order to give the cook's
   --  job is carried out whichever way this is (the scripts' --cooks).

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
