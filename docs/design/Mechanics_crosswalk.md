# The design document against the build

- The document: `docs/design/detailed_mechanics.json`, John's, version 0.15. It is his and nothing here
  changes it. (It came as 0.14, dating itself 2026-11-18. 0.15 is one change made on his word of
  2026-11-22, the day they arrive: difference 1 below.)
- The build: `main` as of 2026-11-22 (the inspection was made on branch `inspection` from b77d6db and merged
  that day on his word).
- Kept by: `tools/mechanics_check.py` with `tools/mechanics_map.json`. Run the script whenever the document
  comes with a new version or one of the code's content enumerations grows: it fails until the map is brought
  up to date, and this page is brought up to date with the map.
- Written 2026-11-22 by Claude, for his word "We need to integrate the detailed mechanics.json". Read as: the
  document is brought into the project (committed, checked, mapped to the build, and made the thing the plan
  is read against); **none of its mechanics is built by this**. The logistics passes he put on hold on
  2026-11-19 are still on hold.

**How to read it.** Three columns: what the document says; what John has said since the document's date
where that bears on it, with the day; what the build does. The document as it came dated itself 18 November
and his rulings of 19 to 22 November came after it, while the file itself was edited up to 22 November. **So
where the three differ nothing here picks a winner**: each such place is in the list just below, for him.
A place he has since ruled on says so, in his words, and stays in the list.
What the build "does" is said from the code's own declarations and its system documents, not from a new run.

The mapping of names (the document's Woodcutter is the build's forester, and so on) is Claude's reading.

## Where they differ: for John

Each line is one thing that is not the same in the document, in his later words and in the build. The
section named has the detail. None is urgent. He ruled on 1, 4 and 5 on 2026-11-22; the other eleven are
as they were and nothing was changed for them.

1. **The day they arrive. Settled 2026-11-22: the document was changed, not the build.** His word: "We'll
   change the day to the 6th and the document. Just so we don't have to change the code." The document
   (0.14) had the 5th day of summer, autumn on day 11, winter on day 26, the thaw on day 41; the build
   starts at three in the afternoon of what its own clock calls "Summer, day 6", so autumn comes 9 days and
   9 hours after the start, winter after 24 days and 9 hours, spring after 39 days and 9 hours. The
   document (0.15) now has the 6th day, autumn on day 10, winter on day 25 and **the thaw on day 40** (the
   thaw moved with the day, by the document's own arithmetic; `tuning.thaw_day` is 40). No code, no run and
   no kept log changed. (Calendar)
2. **Who arrives, and with what.** The document: thirteen serfs and a priest, two carts (salt, grain and
   rations on one; a pot, tinderboxes, axes, pickaxes, bows, arrows, rods, buckets and tools on the other)
   and two horses, after the player and a messenger have chosen the site. The build: thirteen serfs and one
   cart with 240 lb of salt, all there the moment the stake is raised. His words since: no player or
   advisor yet (17 November); the horses and the arrival are the next part (22 November). (Game start)
3. **Forester or woodcutter.** The document renamed the one who fells trees Woodcutter and made Forester a
   noble who keeps the forest. The build says forester everywhere: the job on a person's menu, the logs,
   the options, the code. (Jobs)
4. **The cook. Answered 2026-11-22: the document stands and the build stays as it is.** His word: "The cook
   is earned by skill, but the development UI is the backend we can assign jobs however we want with the
   development UI, the player won't be able to." The document: a job come to by skill, not one the player
   gives; the player gives four (hunter, gatherer, porter, woodcutter). The build does both: the band's
   first cook chooses itself, and Cook is also on every person's menu beside the four. Read with his word:
   a person's menu as it is today is the development interface, where any job may be given; the player's
   own interface, when there is one, gives the four and not the cook. Built the same day on his next
   word ("yes add the cook and the stockman and carpenter"): Cook is a development entry, and the option
   that stands for the player's menu (`--no-dev-jobs`) gives the four and no Cook. (Jobs)
5. **The development list. Answered with 4, 2026-11-22**: what is on the development interface is ours to
   choose ("we can assign jobs however we want with the development UI"). His rule of 19 November: every
   job the band comes to by skill also goes on a person's menu while the game is in development. The list
   had the builder alone; the stockman and the carpenter, both come to by skill, were not on it. Asked,
   he said "yes add the cook and the stockman and carpenter" (22 November), and the three are on it. (Jobs)
6. **Who cuts straw and who gets stone.** The document: gatherers cut grass; a quarryman with a pickaxe cuts
   rock in a quarry; the porter draws water and digs clay. The build: porters cut the straw, prise stone
   off boulders and draw the water. (Jobs, Recipes)
7. **Where meat is salted.** The document: the stockman salts meat into barrels in the stock-house, and
   salted meat is a thing of its own (dried meat). The build: salt decides at the butchering how much of a
   deer is kept (the cart of salt "for curing" is his word of 12 November; where the salt is used was a
   first rule of mine), meat stays meat, and the stockman moves it into the storehouse's barrels. (Recipes)
8. **Wild grain.** The document: gatherers reap it. The build: nobody gathers it for itself; it comes in
   with the straw the porters cut. (Recipes)
9. **Skills.** The document: eighteen, from 0 to 20, in four ranks. The build: eleven, from nothing to
   mastery as a share (shown as a percentage), four of them under other names. (Skills)
10. **How people feel.** The document: each person's satisfaction in three bands, a confidence of his own
    that chases it, a count of the whole colony that weights the unhappiest, and a first winter in which
    nobody blames the player. The build: each person's mood, and the band's confidence as the plain average
    of the moods; no first-winter grace. (Needs, wants, states)
11. **The stockpile.** The document: any number of them, any shape, along the paths. His words since: any
    size along the path (19 November), then one size, a square box put down whole with its path (20
    November). The build has both ways: the player's tool puts down the box, the scripted start still takes
    two corners. (Zones)
12. **Daub.** The document's daubed tier takes clay. The build's daub is laid from straw; clay is in the
    ground and nothing digs it. (Construction tiers)
13. **Tools.** The document: axes, bows, the pot, buckets and tinderboxes are things that come on a cart,
    are handed out with a job and wear out. The build: none of them is a thing in the stores; an axe or a
    bow is drawn on whoever has the job. (Resources)
14. **Water.** The document: drink is a need. The build: porters draw water into the storehouse's two
    barrels, and a search of the code finds nothing that takes it out again. (Needs, wants, states)

## How much of the document has a counterpart in the build

From `tools/mechanics_check.py -v` (which lists every id on either side). A counterpart is a thing of the
same kind in the code; it says nothing of whether the build's rules for it are the document's.

| Section | In the document | With a counterpart | In the world only (generated, nothing in the colony uses it) |
|---|---|---|---|
| jobs | 65 | 8 | |
| skills | 18 | 11 | |
| resources | 131 | 17 | 5 (clay, coal, iron ore, silver ore, gold ore) |
| zones | 18 | 5 | |
| buildings | 55 | 4 | |
| flora | 9 | 6 | |
| fauna | 11 | 1 | |
| deposits | 10 | 3 | 7 (the three veins, clay, silver, gold, the aquifer) |
| recipes | 166 | 15 | |

## Section by section

### Calendar (`meta.calendar`)

| The document | His word since | The build |
|---|---|---|
| 15 days a season, four seasons, 60 days a year | | The same (`Castle.Climate.Days_Per_Season`) |
| They arrive on the 6th day of summer; "Arrival is game day 0. Autumn begins day 10, winter day 25, spring (the thaw) day 40." (0.14 had the 5th day and days 11, 26 and 41) | "We'll change the day to the 6th and the document. Just so we don't have to change the code." (22 November) | `Start_Day` 20.0 and `Start_Hour` 15.0 in the game and the runner: day 20 of the year counted from 0, which `Day_Of_Season` and the game's clock call day 6 of summer. Autumn at day 30 of the year, 9 days 9 hours on |
| The thaw ends the first winter's grace (`tuning.thaw_day` 40) | | No grace and no thaw day in the code |

The kept reference runs start at seven in the morning of the same day (`tools/reference_run.sh`, which calls it
"summer's fifth day": the fifth counted from 0, the clock's day 6) and are 41 days long, so they end a day and
seven hours into spring.

### Game start (`game_start`)

| The document | His word since | The build |
|---|---|---|
| The player and the Count's messenger ride the map; the player places the home stake; the messenger rides back | 2026-11-17: "we aren't doing the player and advisor thing just yet, so just simulate the request" | The player's tool raises the stake, which since 2026-11-20 is one square with the campfire (`Place_Square`). No messenger, no player figure |
| Thirteen serfs and the priest arrive; fifteen people with the player | 2026-11-17: "So we need 13 starting" | Thirteen (`Castle.Colony.Arrivals`), standing at the stake the moment it is raised. No priest |
| Two carts and two horses from the Count | 2026-11-12: "for now lets just add a cart with salt in it for curing, we can expand the supplies later". 2026-11-22: "the next part is adding the horses for the cart and how the colony arrives, they will be pulling the cart to the spot with the horses, it won't be magically popping in with the people" | One cart, put by the stake at the founding, towed by hand into a stockpile and later before the storehouse. No horses. At three hillside squares it finds no place and the colony has no cart (to be mended with the arrival, his word) |
| Stores cart: salt 40, grain 60, rations 60 | 2026-11-12: a deer gives 60 lb of meat | Salt 240 lb (`Cart_Salt_Lb`); no grain or rations on it. The document's quantities are placeholders by its own note |
| Kit cart: a cooking pot, 2 tinderboxes, 4 axes, 4 pickaxes, 3 self bows, 60 arrows, 2 fishing rods, 4 buckets, 6 tools; handed out when jobs are given | | None of these is a thing in the stores. The pot stands at the camp once the hearth is built; an axe, a bow and a quiver are drawn on who has the job |
| Clothing and a cloak on every back | 2026-11-12: "can we add cloaks" (a look) | A cloak is drawn in the cold, cloth since 2026-11-13; it is not a thing owned or worn out |
| Serfs unassigned on arrival; the player gives the opening jobs by aptitude | 2026-11-19: "Delegation doesn't extend past basic work at the beginning, serfs fill jobs ... dictated by skill" | They arrive unassigned; a person's menu shows each job with that person's skill and aptitude |

### Classes (`classes`)

| The document | His word since | The build |
|---|---|---|
| Serf, peasant, merchant, noble, and the clergy apart | | Serfs only. `Castle.Actions.Rank` (nobody, serf, leader) is who may give an order, not a class |
| A peasant is paid and has his workshop as his house; the wright, the carpenter, the stockman and the cook are peasants | | The builder, the stockman and the carpenter are trades a serf takes up and leaves (`Trade_Kind`); no pay, no coin |
| Each class has its housing, its wants and the grade it expects | | One kind of house, the hovel; no wants, no grades |

### Needs, wants, states (`mechanics.needs`, `.wants`, `.states`, `.needs_rule`, `.satisfaction`, `.colony_indices`)

| The document | His word since | The build |
|---|---|---|
| Nourishment, from the stock-house and the cook; cooked food better than raw | 2026-11-12: the cook keeps a pot's fill, only the surplus is eaten raw. 2026-11-13: a load is carried where it was going before eating | Food in points, 240 a day; stew at the pot first, raw from the stores without it; cooked goes about three times as far (`docs/systems/needs.md`) |
| Drink: water, milk, ale, mead, cider | | Not a need. Water is drawn into two barrels in the storehouse; nothing found that uses it |
| Rest: a straw pallet or a bed; "sleeping on the ground meets the need poorly" | 2026-11-12: beds of straw by the fire, then in the house | Everyone sleeps at night; each makes itself a bed of two sheaves. The bed was built as a look, with no effect on rest (the round's own record, 2026-11-12) |
| Shelter: housing | 2026-11-11: "one hovel per person for now" | A hovel each, drawn for by lot when it stands (his word of 2026-11-12) |
| Warmth: campfire, hearth, fireplace, brazier, cloak; in winter | | In winter, away from a burning fire and not under its own roof, a person is cold: hungry faster, and its mood can rise no higher than 0.3 |
| Clothing; care when hurt or ill | | Neither |
| Fending for himself when the stores fail; it stalls his work | Stage 4's rule (2026-11-08): serfs are self-reliant | Built: at 15 % fed a person leaves its work to eat and, with nothing in the stores for it, fends for itself |
| Grace through the first winter; after the thaw fending costs mood, which he blames on the player | | No grace. Starting to fend takes a tenth off mood at once, from the first day |
| Wants by class and grade, asked for by the dwelling | | None |
| Satisfaction per person, 0 to 100 %: failing under 30, provided to 80, content above | | Mood per person, 0 to 1: it eases over twelve hours toward 0.8 on stew, 0.55 on raw food, 0.35 hungry, 0.1 starving; a death takes a quarter off everyone; it starts at 0.7 |
| Confidence per person, chasing satisfaction | | None per person |
| Consent: everyone's confidence, the unhappiest weighing more (k 4). Stability, legitimacy, the mood trend, patience, prosperity: hidden | | `Confidence`: the plain average of the living's moods, shown to the player as a figure. None of the hidden counts |
| Health, 0 to 100 | | None |

### The supply chain (`mechanics.supply_chain`, zones stockpile and stockyard)

The stage brief (`docs/production/briefs/Stage_6_brief.md`, "The logistics network") has his model beside
the build, pass by pass. In short:

| The document | His word since | The build |
|---|---|---|
| A dwelling's need or want becomes a demand; the stockman fills it from the yard or passes the deficit to the job that makes the thing | 2026-11-19: "Document's stores is my model the new idea, the logistics network"; then "hold off on the integration" the same evening | The demand chain of stage 5c asks the stores zone by zone; builders fetch their own timber and straw. Pass 1 (stockpiles stay open beside the stockyard) is built; passes 2 to 5 are held |
| Stock hands: one sent to each stockpile, others deliver by cart and horse | 2026-11-22: "leave the cart doing whatever it's doing right now, we are going to work on the logistics soon" | None. Porters carry everything; the stockman keeps the storehouse |
| Reserves set by the player, kept by the stockman | | Reserves are set on a stockpile's menu and kept by the demand chain (`Set_Reserve`) |
| Priority: needs, then accepted orders, then reserves, then wants from noble down to serf | | The fire's day of logs and the camp's hearth come before building (`Free_For_Building`); no wants |

### Skills and progression (`skills`, `mechanics.skills`, `.progression`)

| The document | His word since | The build |
|---|---|---|
| Eighteen skills | | Eleven (`Skill_Kind`): gathering, hunting, cooking, building, carpentry, stonework, farming under the same names; forestry for woodcraft, portering for hauling, tanning for leatherwork, taming for husbandry. Not there: mining, smithing, weaving, pottery, healing, arms, letters |
| 0 to 20; novice, apprentice, journeyman, master, tied to the grades | | 0 to 1, "none" to "mastery"; shown as a percentage; no ranks |
| Aptitude per skill, about 0.5 to 1.5, shown on the serf's menu with the level | | The same idea: an aptitude per skill from the person's seed (`Aptitude_Lo` to `Aptitude_Hi`), shown on the menu |
| Gain by use, a weighted share spilling into related skills, slower at higher levels; no decay | | Gain by use, with a spill table by the kind of work (`Own_Skill` and the table after it); stage 5b's rules (`docs/production/briefs/Stage_5b_brief.md`) |
| A job opens when there is demand, a workplace and the research; the best candidate moves up; he reverts when inputs run short | 2026-11-19: the player gives the opening jobs only, the rest by skill; "Carpenter comes by skill like the others" | The builder, the stockman and the carpenter are taken up by the one best at the skill when there is work, and left when there is none. At most four builders (his figure of 2026-11-17) |
| The player can cap how many move up a line | | The cap on builders is a number of the code's, not the player's |
| Letters are taught, not trained | | No letters |

### Quality, kit, information (`mechanics.quality`, `.inventory`, `.information`, `.personalities`, `.dynamics`)

Not built: grades, kit that wears, counsel, asking around, the daily report, personalities. The one piece
of it in the build is older than the document: a sheet's rows are marked by whether the player's character
could know them (`Castle.Views`, stage 5a), and the framework's rule that the player's interface is what he
sees and is near (`docs/production/Production_Framework.md`, "The player's interface").

### Construction tiers (`construction_tiers`)

| The document | His word since | The build |
|---|---|---|
| Tier 1, wood and thatch: post-and-plank walls, plank or earth floor, thatch; materials wood and straw | 2026-11-12, with his pictures: a timber frame filled with wattle and daub, thatch | The hovel: a timber frame, daubed walls, a floor of beaten earth, thatch, small windows; it takes logs and straw (daub and thatch are both laid from straw), and stone where its ground needs a retaining wall |
| Tier 2, cruck frame with wattle and daub: wood, straw and clay | | The look of this tier from the materials of the first: no clay |
| Tiers 3 to 5: stone footings, stone, fortified | | None; nothing is improved (`castle-buildings.ads` says so of the hovel) |
| Built by the wright | | By builders (the document's wright under its plain name) |

### Zones (`zones`)

| The document | His word since | The build |
|---|---|---|
| Home stake: the centre of the village; nearer buildings improve first | 2026-11-20: "merge the homestake and the campfire", a square with a path round it. 2026-11-21: 11 m of floor, 13 with its path, the fire in the middle; a special zone's area is kept whole. 2026-11-22: its path stepped with stone | As his words since: `Place_Square`, with stone walls and stairs where its banks want them. Nothing improves, so no gradient |
| Pathway: every building attaches to one; footpath, then cart track, then metalled road | 2026-11-10: the player plans a path, the serfs build it. 2026-11-19: straight or at 45 degrees | Planned by the player, laid by the band, straight or at 45 degrees; one kind (footpath). Housing lies along a path; a placed zone comes with its own |
| Habitation: housing that builds itself along pathways; about 5 m by 5 m of living space a serf; set back 0.25 to 1 m from the path | 2026-11-12: "a fixed distance from the path". 2026-11-20: housing pulled with its path, one side or both | A strip along a path's run; a hovel has 25 square metres of floor for its one resident (`Min_Floor_B`: the document's 5 m by 5 m), fronts 5.25 to 6.5 m and is at most 6 m deep. Built by builders once the player has zoned it |
| Stockpile: an intermediate store along a pathway; it must touch one | 2026-11-19, then 2026-11-20 (line 11 of the list above) | The tool puts down a box 10 m square with its path; any number; they stay open beside the stockyard |
| Stockyard: the stock-house, the open yard, the staging area, the granary, the stable | 2026-11-21: 20 m by 20 m, the storehouse 12 m by 8 m and 3 m nearer its path. 2026-11-22: its floor at its path's level at the lower corner, the stair at the higher, none over 2 m | As his words since; the storehouse, its fenced yard with coverings, staging before it. No granary, no stable |
| Forest, hunting ground, orchard, farm, pasture, quarry, clay pit, mine, waterside, guard post, manor, craft quarter, merchant street | 2026-11-19: "Trees do not grow back yet, but they will" | None of them is a zone. Foresters fell within reach of the stake and further when that is bare; apple trees are spared by a standing order |

### Buildings (`buildings`)

| The document | His word since | The build |
|---|---|---|
| Serf's dwelling, tier 1 "Hovel"; one occupant; slots for a straw pallet, a trestle table, a stool, a brazier | 2026-11-12: a straw bed in the house | The hovel; one occupant; its bed of straw. No other furnishing |
| Stock-house, tier 1 "Store Shed": goods kept indoors; barrels and shelves; meat salted and packed here | 2026-11-21: "Allow food and full barrels to be stacked in the storehouse" | The storehouse: a floor of plank, shelves along the long walls, barrels for meat and two for water made by the carpenter; food and barrels stacked |
| Open yard, tier 1 "Fenced Yard", tier 2 "Yard with Lean-tos": wood, rock, ore, coal, clay, straw outside | | The stockyard's fenced ground with coverings, and the ladders' places against the wall |
| Staging area, tier 1 "Loading Ground": deliveries assembled; carts | | The ground kept clear before the storehouse, where the lord's cart is brought |
| Fifty-one others, from the cookhouse to the chapel | | None. The cook's fire is the camp's hearth |

### Jobs (`jobs`)

| The document | His word since | The build |
|---|---|---|
| Woodcutter (was Forester): fells trees for wood and saplings, carries the logs home; kit an axe | 2026-11-08: a forester carries every log of its tree home before felling the next. 2026-11-19: "Let workers go 250m for resources" | `Forester`. No saplings |
| Hunter: a self bow and arrows; meat, hides, feathers; fishes streams; makes his own rough bow and arrows | 2026-11-08: the short bow. 2026-11-13 and 14: the herds' rules | `Hunter`: deer only, with the bow; no feathers, no fishing. (The document's self bow is the old short bow renamed) |
| Gatherer: berries, mushrooms, herbs, wild vegetables, wild grain, flax, fruit | | `Gatherer`: berries, wild vegetables, apples |
| Porter: draws water and digs clay; "hauling passes to the stock hands once there is a stockyard"; kit a bucket | 2026-11-08: porters never carry wood | `Porter`: hauls, cuts straw, prises stone off boulders, draws water |
| Cook: a peasant, by skill (cooking 5), at the cookhouse; pottage and simple bread | 2026-11-17: "the cook becomes the cook when it is open" | `Cook`: the first cook chooses itself; the job is on the menu too. Stew at the camp's pot |
| Wright (plain name Builder): a peasant, rises from the woodcutter; builds and repairs tiers 1 to 3 | 2026-11-17: at most four builders. 2026-11-19: razing limited to hovels nobody owns | The builder, a forester's trade; it also takes down a hovel marked for razing |
| Stockman: a peasant, rises from the stock hand or the porter; runs the yard, keeps reserves, schedules deliveries, salts meat | | A porter's trade, by portering skill: keeps the storehouse and moves the stores in |
| Carpenter: a peasant, rises from the wright, in his own workshop; furniture, barrels, tool handles, shoring | 2026-11-19: "Carpenter comes by skill like the others" | A forester's trade, by carpentry: makes the storehouse's shelves and barrels there. No workshop |
| Stock hand, and fifty-six more | | None |
| The priest arrives at the start | 2026-11-17 (no advisor yet) | None |

On a person's menu the build lists unassigned, gatherer, forester, hunter, porter and cook, each with that
person's skill and aptitude, and "Builder" while `Castle.Actions.Dev_Jobs` is on (lines 4 and 5 of the list).

### Resources (`resources`)

The build counts sixteen kinds of thing carried or stored (`Item_Kind`), twelve of them the document's:
berries, wood, stone (its rock), water, straw, meat, hides, vegetables, apples (its fruit), grain, earth
(its dirt) and salt. Its own: a carcass (a kill carried home), sticks (dead wood for the fire), the ladder
(his word of 2026-11-12), and "nothing". It also has the cart, the bed of straw (the document's straw
pallet), the campfire, barrels and shelves as things that stand somewhere, not as stock.

Units: the build counts handfuls, logs, sheaves, stones and pounds; the document's quantities are
placeholders by its own note, so no quantity is compared here.

Nothing in the build is perishable or graded. (Spoilage was named as a later stage in the handoff of
2026-11-12.)

### Flora, fauna, deposits (`flora`, `fauna`, `deposits`, `livestock_products`)

| The document | His word since | The build |
|---|---|---|
| Tree: wood and a sapling | 2026-11-19: trees will grow back, later | Five kinds drawn, three for the colony (broadleaf, conifer, apple); wood only; nothing grows back |
| Fruit tree: protected by default | | Apple trees, spared by a standing order |
| Berry shrub: grows back in 6 days | | The same: 6 days, not in winter (`Regrow_Days`) |
| Wild vegetables, wild grain, grass | | All three grow; vegetables come back in 10 days, not in winter |
| Herbs, wild flax, mushrooms | | None |
| Deer: meat 4, a hide | 2026-11-12: 60 lb of dressed meat a deer | A doe 60 lb, a stag 75, a young stag 45; a hide each; herds that follow a node (`docs/systems/deer.md`) |
| Ten other animals; livestock | 2026-11-14: the herds are to come apart from the stake when the whole ecosystem is built | None |
| Rock, cut in a quarry | | Boulders on the land; no quarry |
| Iron, coal and salt veins that show at the surface; silver and gold deeper along them; clay near water | | All generated (`Castle.Deposits`, with bog iron and river gravel that the document does not have); nothing mines or digs them |
| Stream, lake, aquifer by a well | | Streams, rivers and lakes generated; water is drawn where it runs; the aquifer is a generated field, and there is no well |

### Recipes (`recipes`)

Fifteen of the 166 have something in the build. Where the build's way differs it is said.

| The document's recipe | The build |
|---|---|
| `fell_tree` (woodcutter, needs an axe): wood 4, a sapling | A forester fells a tree and carries home every log of it; no sapling; the axe is drawn, not needed |
| `forage_berries`, `forage_vegetables`, `pick_fruit` (gatherer) | Gatherers; no seed comes with the vegetables; apples are picked from day 25 to day 45 of the year (the last five days of summer, and autumn) |
| `cut_grass` (gatherer): straw | Porters cut tall grass for straw |
| `reap_wild_grain` (gatherer): grain and straw | Grain comes in with the straw; nobody gathers it for itself |
| `hunt_deer` (hunter, bow and arrow) | Hunters; arrows are not counted |
| `draw_water` (porter, needs a bucket) | Porters, into the storehouse's water barrels; no bucket |
| `quarry_rock` (quarryman, needs a pickaxe) | Porters prise stone off boulders |
| `cook_pottage` (cook, at the cookhouse; water with vegetables or grain, meat optional; needs the pot and a fire) | The cook's stew at the camp's pot, from whatever food is stored, by food points; no water in it |
| `salt_meat` (stockman, in the stock-house: meat, salt and a barrel give dried meat) | Salt at the butchering; meat barrels in the storehouse (line 7 of the list) |
| `make_campfire` (anyone: rock 2, wood 2; needs a tinderbox) | The band builds the camp's hearth of ten stones and three pieces of wood |
| `make_straw_pallet` (anyone: straw 3) | Each makes its own bed of two sheaves |
| `make_barrel`, `make_shelves` (carpenter, in his workshop, from wood) | The carpenter, in the storehouse |

### The realm (`realm`)

The story: the Count and the Duke, the priest who is the Count's man, messengers, justice, the loyalty
choice, how a lord falls. Nothing of it is built, by his word of 2026-11-17. It is kept here only as what
the document holds.

## Where the document's parts fall in the framework's phases and stages (a map; the order is his)

The framework (`docs/production/Production_Framework.md`, "Phases" and "Stages") was agreed before the
document was written; its stages 7 to 12 and phases C to H are marked proposed there. This sets the
document's sections against them, to show what each would draw on. It proposes no order and no new stage.

| The framework | What of the document it would draw on |
|---|---|
| Stage 6 (phase B, in progress): habitation and the stores | Zones habitation, stockpile, stockyard; the serf's dwelling, the stock-house, the open yard, the staging area; the wright, the stockman, the carpenter; the supply chain (its later passes held) |
| Next by his word of 2026-11-22: the arrival, the horses | `game_start`; the horse and the cart; the stable's first tier ("Horse Shelter") |
| Stage 7, the player's character | `realm.player`; `mechanics.information` (what he sees for himself, asking around); the priest as counsel |
| Stage 8, wood and stone trades | The carpenter in a workshop, the mason, the quarryman and the quarry; the furniture recipes; wants and the grades; the well; the pathway's upgrades |
| Stage 9, hide and cloth | The tanner, the weaver, the tailor; clothing and the cloak as things; kit that wears; clothing as a need |
| Stage 10, farm and herd | Zones farm and pasture; the farmstead, the granary, the mills, the pinfold and the folds; farm hand, farmer, herd hand, herdsman, shepherd, stable hand; livestock; the animals beyond deer |
| Stage 11, newcomers and losses | What is perishable; people leaving ("unmet needs make them leave"); care, the herbalist |
| Stage 12, housing that improves | The construction tiers; every building's tiers; the home stake's "nearer buildings improve first" |
| Phase D, the economy | The peasant and the merchant as paid classes; coin, the market, the merchant street and the craft quarter; appointed roles; research |
| Phase E, governance and threat | The colony's hidden counts (stability, legitimacy, the mood trend); justice, the bailiff, guards; bandits and the attention ladder; counsel's reports, espionage |
| Phase F, lordship | The manor's tiers, the fortified tier; knights and the marshal; the loyalty choice and the feud |

Not placed by the framework as it stands: mining and metal (the miner, the bloomer, the smith, the
armourer), pottery, the healing trades, letters and the school; drink as a need; the first winter's grace;
and the document's way of counting how people feel, where stage 4 built another (line 10 of the list at
the top).

## What the build has that the document does not

- The camp's square with its stone walls, stairs and stepped path; retaining walls and stairs at a hovel.
- The ladder; sticks for the fire; a carcass carried home; earth dug and heaped.
- The lord's cart towed by hand.
- Bog iron and gold in river gravel, in the ground.
- Buildings drawn turned along a path at 45 degrees.
- Water that runs, falls and can be let out of a lake; the weather, mist and the moon.

## The document against itself

From `tools/mechanics_check.py`, which follows every cross-reference in it (2,155 of them). It is in good
order:

- `buildings.infirmary` names the manor as its zone, and the manor's list of buildings does not have it.
- `dirt` is made by nothing and used by nothing (it is "terraforming only" by its own note).
- Eleven research topics are named by jobs, recipes, resources and skills (advanced structures, brickmaking,
  crossbow, deep mining, engineering, fine toolmaking, glazing, minting, steel, surgery, war bow) and the
  document has no section that says what research is or what each takes.

## How the document could become data the game reads (not built)

Nothing in the game reads the document. The way that fits this code is the one the font already takes:
a script reads his file and writes one Ada specification of tables (`tools/font_glyphs.py` writes
`src/castle-font_data.ads` so). The game would then name content by constants made from his ids, the tables
would be made again whenever he bumps the version, and nothing would parse the file while the game runs.

Two things it would have to respect. The code's jobs, skills, things carried and zones are saved by their
position in their lists, so his file's order cannot be the saved order: the map file would carry each id's
saved number. And his quantities are placeholders, so the tables would carry names and links first, and
numbers only once he says they are meant.

It is not built because nothing would read the tables today: the first system that needs a table wider
than today's lists (the job ladder, or recipes by job) is the time for it. His to say.
