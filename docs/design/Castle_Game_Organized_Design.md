# Castle Game — Organized Design: Jobs ↔ Assets ↔ Progression

**Source materials synthesized:** Asset generation guide, job hierarchy, and Preliminary Design Report (Nov 5, 2026).

**Core rule (from design report):** The player marks *where* (designations, appointments, reserves, protections). Population demand, skill, and available resources decide *what* is produced and built. Workers revert to upstream jobs when inputs run short. Skill grows by doing the work; related skills grow slowly alongside.

**Starting band (example):** Player + 5 others. Assign the four base jobs. Clothing covered at start. Food and shelter first. Habitation zone planted. Autonomy appears within days (highest cooking aptitude starts cooking once food returns).

---

## 1. Resource & Asset Hierarchy

### Raw Resources (gathered or harvested)
| Category | Items | Primary Sources | Notes |
|----------|-------|-----------------|-------|
| **Minerals / Basic** | Dirt, Rock, Iron, Coal, Gold, Silver, Salt | Porter (water + stone), Miner | Clay = Water + Dirt |
| **Flora** | Wood, Saplings, Fruit, Herbs, Berries, Vegetables, Grain, Straw, Fibre | Trees, Fruit trees, Herbs, Shrubs, Vegetables, Wild grain, Grass | Foresters, Gatherers, Tree Farmers |
| **Animal products** | Meat, Hide, Milk, Wool, Eggs, Honey, Wax | Deer, Goat, Cow, Horse, Fox, Wolf, Bear, Chicken, Sheep, Fish, Bees | Hunters (wild); Tamers/Herdsmen (domestic) |
| **Forage / Other** | Mushrooms, etc. | Gatherers | |

### Improved / Processed Resources
| Item | Requires | Typical Producers |
|------|----------|-------------------|
| Clay | Water + Dirt | Porter / Miner / Potter |
| Iron / Gold / Silver Ingot | Ore + Coal or Wood | Blacksmith (Forge) |
| Stone Block | Rock | Stonecutter / Mason |
| Hard Leather | Water + Wax + Hide | Tanner |
| Light Cloth | Fibre | Tailor |
| Heavy Cloth | Wool | Tailor |
| Bread | Water + Egg + Grain + Salt | Baker |
| Ale | Grain/Water, Honey/Water, or Fruit/Water | Brewer / Innkeeper |
| Cheese | Milk + Salt | Cheese Maker |
| Dried Meat | Meat + Salt | Butcher |
| Medicine | Herbs | Apothecary / Healer |
| Steel Ingot | Iron Ingot + Coal | Blacksmith (advanced) |
| Brick | Clay + Coal or Wood | Potter |
| Rations | Dried Meat + Cheese | Butcher |
| Saddle | Hard Leather | Tanner |
| Food (prepared) | Combinations of cheese, bread, milk, water, veg, fruit, meat | Cook / Chef |
| Coin / Jewelry | Gold or Silver | Mint / Smith (trade goods) |

### Constructable Zones (player designates *where*; population builds *what* is needed)
Stockpile, Leisure, Warehouse, Habitation, Farm, Stables, Forge, Inn/Brewery, Baker, Butcher, Cheese Maker, Stonecutter, Potter, Apothecary, General Store, Tailor, Tanner, Armorer, Guardhouse.

### Furniture & Decor (produced by carpenters, masons, potters, etc. as demand arises)
Bed, shelves, fireplace, chairs/stools, tables, signs, campfire, kiln, barrel, forge, crafting table, research table, beehive, fence/gate, smoker, torch, game table, chest, candelabras, brazier, weapon/armor racks, wall shields, pottery, flags, banners.

### Weapons & Armor
- Early: Short Bow (Wood + Fibre; the hunter's starting weapon), Long Bow (Wood + Fibre), Axe (Woodsman)
- Mid: Sword, Spear, Shield, Lance, Hammer, Poleaxe (Wood + Iron/Steel)
- Armor: Cloth → Leather → Iron (then steel)

---

## 2. Job Trees Mapped to Resources & Outputs

**Tiers (preliminary labels from design report):** Serfs (unpaid producers, Tier 1) → Peasants (wage roles, Tier 2, drafted from serfs, create demand) → Nobility (senior appointed, Tier 3, drafted from courtiers).

**Reversion principle:** When an input is short, dependent workers revert to the upstream gathering job (e.g., Builder → Forester, Tailor/Cook → Hunter/Gatherer). Prefer the best at the upstream job; avoid flickering (proposal: revert at one stock level, return at a higher one).

### Serf Base Jobs (assignable at start) and Branches

**Forester** (gathers Wood + Saplings from Trees)
- Builder (uses Wood → buildings, floors, walls)
- Carpenter (improved wood products, furniture, tools)
  - Craftsman (master wood: wood tools & weapons)
  - Architect (advanced structures; works with Engineer)
- Tree Farmer (plants/tends saplings & trees)

**Hunter** (gathers Meat + Hide from wild animals)
- Cook (basic meals) → Chef (quality meals) → Brewer (fermented drinks)
- Tamer (tames for domestication: milk, wool, offspring) → Herdsman (large-scale herds)
- Tanner (leather from hides)

**Gatherer** (herbs + forageable food: berries, vegetables, grain, etc.)
- Cook / Chef / Brewer (same food line as Hunter)
- Farmer (crops + plant products; raises output of gatherers who work for him)
- Tailor (cloth, clothing, cloth armor from fibre/wool/leather)
- Healer (herbs) → Doctor → Surgeon (advanced tools)

**Porter** (gathers Water + Stone)
- Mason (stone/clay: walls, roads, hearths, wells, basic furnishings)
  - Stone Carver (quality stone furniture, oversees stone blocks)
  - Potter (quality clay furnishings, brick)
- Miner (iron, gold, silver, clay, coal)
  - Blacksmith (tools, armor, weapons, ingots)
    - Engineer (advanced structures with Architect; efficiency)

### Peasant Appointed Roles (require currency; create demand for serf production)
Merchant (oversees movement/production; assigned to player-designated zone) → branches into:
- Innkeeper, Storekeeper, Butcher, Armorer, Tanner, Tailor, Apothecary, Potter, Stonecutter, Cheese Maker, Baker, Brewer, Blacksmith

Guard (from Serfs) → Men-at-Arms (soldiers)

Student (from Serfs) → Tutor

Page (early economic management) → Squire (best soldiers / player's guard)

### Nobility Senior Roles (require currency; take areas off the player's hands)
| Senior Role | Promoted From | Responsibility Handoff |
|-------------|---------------|------------------------|
| Treasurer | Page | Economy / coffers |
| Quartermaster | Merchant | Goods movement & production |
| General | Men-at-Arms | Military |
| Sheriff | Guard | Local security |
| Knight | Squire | Elite / personal guard |
| Researcher | Tutor | Discovery (paid from levies; not player-picked) |

**Research note (design report):** Discoveries become possible only when prerequisites are done *and* someone capable exists. Weighted toward lower tiers and trades that have hit tool limits. Researcher's skill raises speed and success chance. Fine toolmaking helps many trades. Researcher produces no goods; creates co-dependence and monetary conditions.

---

## 3. Progression by Design Guide Stages

### Stage 0 — Opening (Days 1–few)
- **Player actions:** Plant Habitation zone. Assign Forester, Hunter, Gatherer, Porter (match aptitudes). Set basic reserves (food for winter later). Protect key animals/trees if desired.
- **Resources flowing:** Wood, Stone, Water, Meat, Hide, Herbs, Forage, Fruit/Berries/Veg/Grain.
- **Buildings/Furniture:** Procedural hut (roof + floor first). Campfire. Basic beds/shelves as wood allows.
- **Jobs active:** The four base jobs. Highest cooking aptitude begins cooking once food returns.
- **Pressures:** Scarcity of food & clothing (clothing covered at start). Shelter priority.
- **Handoff:** None yet. Player watches everyone is working and has what their job needs.

### Stage 1 — Early Colony (first winter target)
- **Focus:** Needs met, skill gain, reversion, procedural buildings, surplus for winter (food + firewood).
- **Resources:** Same as above + first improved (basic bread if grain/eggs/salt available, dried meat, simple cloth).
- **Zones:** Habitation, Stockpile, early Farm or Stables if seeds/animals domesticated.
- **Jobs:** Base + first earned steps (Cook, Builder, Tanner, Mason, Farmer/Tamer if skill rises). No coin, merchants, or research yet.
- **Design report first-build target:** First winter with starting group — needs, four jobs, habitation, reserves, skill, reversion, procedural hut, winter consumes food & firewood.
- **Pressures:** Winter/famine. Bandit raids (small).

### Stage 2 — Mid (surplus → appointed roles)
- **Trigger:** Surplus production + coin (from selling to traveling merchants or early minting).
- **Player actions:** Appoint first Merchants / Bakers / Guards / Innkeepers when the supply window shows the village can support them. Designate zones (Farm, Forge, Bakery, Inn, etc.). Set protections and reserves.
- **Resources unlocked/improved:** Ingots, Stone Blocks, Hard Leather, Cloth, Bread, Cheese, Ale, Medicine, basic weapons/armor. Tools begin wearing (proposal).
- **Jobs:** Full serf branches active. Peasants appear (Merchant line, Guards, Students). Demand from appointed roles pulls serfs (e.g., Baker asks for grain/eggs/milk → Farmers & Herdsmen).
- **Buildings:** Specialized workshops (Baker, Butcher, Tanner, Forge, etc.). Roads (raise stone demand). Better furniture.
- **Research:** Begins when a capable person exists and prerequisites met. Broad discoveries (classes of designs, new resource uses such as steel).
- **Pressures:** Scarcity shifts toward weapons/armor. Peasant unrest if demands unmet. Roads must stay secure.

### Stage 3 — Later / Established (officials & castle)
- **Player actions:** Appoint senior roles (Treasurer, Quartermaster, General, Sheriff, Researcher, Knight). Design castle walls, keep, manor (player has more direct control over his seat). Manage larger threats.
- **Resources:** Steel, advanced tools, fine goods, jewelry, full rations, quality meals. Gold/silver seams → minting.
- **Jobs:** Master trades (Architect, Craftsman, Brewer, Chef, Doctor, Engineer, Blacksmith, Stone Carver) held by 1–2 people, gated by research. Nobility take areas off player's hands. Serfs still produce the wealth and must be cared for (or unrest).
- **Buildings:** Full specialized zones + Guardhouse, Armorer, advanced structures. Castle.
- **Economy:** Wages paid from coffers return via purchases & taxes. Merchants flesh out logistics. Selling surplus keeps demand high. Appointments have visible costs (requirements shown before hiring; pulling someone back makes them unhappy).
- **Pressures:** Neighboring baron assaults, liege tribute, sophisticated enemies, larger raids. Renown (wealth + size) draws bigger attacks. Walls/arms may count toward wealth (open question).
- **Handoff:** Economy, military, research, local security largely delegated. Player focuses on strategy, diplomacy (open question), castle design, and personal leadership (dangerous — run ends on his death).

### Stage 4 — Indefinite / Endgame
- Game continues indefinitely until player's character dies. Heir appointment possible but deferred.
- Player keeps designing manor/keep/castle. Population runs the rest if developed well.
- Chronicle / end-of-run record proposed to trace late failures back to earlier decisions.

---

## 4. Key Connections & Design Principles

| Principle | How It Connects Jobs ↔ Assets |
|-----------|-------------------------------|
| **Demand drives production** | Appointed baker asks for grain/eggs/milk → Farmers, Herdsmen, Gatherers produce more. Merchant creates labor demand for serfs and demand for roads/improved goods. |
| **Skill by doing** | Forester gains forestry fastest + fractions of building/carpentry. When stone pile grows, proficient miner becomes mason. |
| **Reversion on shortage** | No meat/fur → Tailor or Cook reverts to Hunter. Builder reverts to Forester. Nobody refuses basic work. |
| **Base needs first** | Mason doesn't lay stone while no campfire or fireplace. Builder doesn't make bed frames before roof & floor. |
| **Appointments cost** | Hiring pulls a worker out of production. Shown in supply/demand window before assignment. Wasted if later pulled back. |
| **Research emerges** | Not player-picked. Needs capability + prerequisites. Helps multiple trades (fine tools). Creates co-dependence. |
| **Serfs vs wage roles** | Serfs unpaid, create wealth, benefit last, can become rebellious if demands unmet. Peasants/nobility draw wages and charge for services. |
| **Procedural buildings** | Player designates zone; builders lay out rooms & furnishings based on available materials and demand. |

**Open questions from design report (still relevant):**
- Diplomacy kept by the lord?
- How merchants judge demand (prices vs shortages)?
- Treasury can't pay wages?
- Source of generated coin?
- Walls/arms count toward renown/wealth?
- Liege tribute details?
- Squires from pages or best men-at-arms?
- Who are the courtiers?
- Final tier names?

**Proposals worth tracking while implementing:**
- Reversion hysteresis (low threshold to revert, higher to return).
- Only as many workers revert as the shortage needs.
- Tools wear out (steady forge demand).
- Tool tiers cap trade skill.
- Research weighted toward trades at tool limits.
- Unrest escalates in visible steps.
- Bandits announce via sightings/rumors/probing raid.
- Supply window forecasts deficits.
- Officials' reports only as good as their skill.
- Chronicle traces failures to decisions.

---

## 5. Quick Reference: Starting Jobs → Immediate Assets

| Starting Job | Gathers | Enables First | Feeds Into |
|--------------|---------|---------------|------------|
| Forester | Wood, Saplings | Walls, floors, campfire, tools, bows | Builder → Carpenter → Craftsman/Architect; Tree Farmer |
| Hunter | Meat, Hide | Cooking, leather, early clothing | Cook/Chef/Brewer; Tamer → Herdsman; Tanner |
| Gatherer | Herbs, forage, seeds | Medicine, farming, cloth | Farmer; Tailor; Healer → Doctor; Cook line |
| Porter | Water, Stone | Clay, stone walls/roads, wells | Mason → Stone Carver/Potter; Miner → Blacksmith → Engineer |

This mapping keeps the simulation demand-driven and the player's role focused on designations, timing of appointments, reserves, and his own castle seat — exactly as the design report describes.

**Next suggested steps (from design report):**
1. Profession tree: weights, thresholds, what raises each skill, what it produces/needs, what it reverts to.
2. Technology tree: prerequisites, capability gates, tiers, which trades each discovery helps.
3. Engine: block world + procedural generation.
4. First playable: first winter with the starting group.
