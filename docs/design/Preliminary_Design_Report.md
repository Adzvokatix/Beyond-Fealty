# Castle Game — Preliminary Design Report

Nov 5, 2026 · @John

## Overview

Castle Game is a medieval colony builder in which the player leads by delegation. He directly controls only his own character, and the rest of the population acts on his orders. The design rule: the player says where, and the population's demand says what.

The simulation follows the general design of RimWorld, Dwarf Fortress and Going Medieval; what changes is how the player makes things happen. In those games the player decides what is made, how much, when and by whom, down to floor plans and materials. Here, necessity, resources and skill decide.

Over a run, the player's responsibility grows from keeping a small band alive to ruling a realm. Each part of the settlement he builds well becomes one he can hand off. Ideas raised in discussion but not yet decided are collected under Proposals and open questions.

## The player's role

The player controls his own character directly and acts on everything else through orders. He can do simple tasks alongside the others, but nothing is built or produced at his command alone.

| Lever | What the player does | Example |
| --- | --- | --- |
| Designations | Marks where things go | A habitation post, a farm area, a stone road, a bridge |
| Starting jobs | Assigns the opening group to the base jobs | Forester, hunter, gatherer, porter |
| Reserves | Sets how much of a resource to hold back | Food kept for winter |
| Protections | Forbids using specific animals or trees | No hunting sheep, no cutting apple trees |
| Appointments | Hires wage roles once there is coin | Merchant, baker, guard, treasurer |
| His own work | Performs simple tasks himself | Crossover with the starting jobs |
| His castle | Has some direct building control over his own seat | Manor, keep and castle |

Everything else belongs to the population. Builders decide what a designated area needs and lay it out procedurally, with rooms and furnishings to match. Materials follow what resources are available.

Craftsmen choose what to make, and from what, by skill, demand and resources. The player never orders a product: when the carpenter makes signs and furniture, people go and buy them. An appointed baker asks for grain, eggs and milk, and the village has to supply them.

Where is the player's call, and timing is his real skill. Appointing a role before the village can supply it pulls a worker out of production and delays growth.

## Progression of responsibility

The player's attention moves up as the settlement grows: once part of the village runs itself, he hands it off. Early on, his job is making sure everyone is working, has what their job requires, and is ready for winter. Later, appointed officials take over whole areas; a treasurer, for example, takes over the economy once it is established.

| Early game | Later game |
| --- | --- |
| A bandit raid | An assault by a neighboring baron |
| Scarcity of food and clothing | Scarcity of weapons and armor |
| Where the farm should go | Where the castle walls should go |

If the colony is developed well, everything that depends on it runs on its own. Early mistakes can have nasty consequences later, and a player who sees a run through learns where he went wrong. The game teaches delegation rather than micromanagement, and asks for fortitude, patience and wit.

A run ends when the player's character dies. Otherwise the game can run indefinitely, and the player keeps designing his manor, keep and castle.

As his power and renown grow, so do his enemies and the sophistication of those who want him dead. Appointing an heir is possible, but deferred.

## The opening

A run starts with the player and a small group, for example five others. They need nourishment, shelter and clothing; clothing is covered at the start, so shelter and food come first.

The player plants a habitation zone, a post in the ground that says start here, and assigns the base jobs. Foresters cut trees and begin putting up walls and floors, and porters bring water and stone. Hunters and gatherers spread out and come back when they have food; two or three of them should feed a band of six.

Autonomy appears within the first couple of days: once food comes back, whoever has the highest cooking aptitude starts cooking. The player can see everyone's aptitudes and assign jobs to match. Production is deliberately simple, so trees give wood directly, with no mill to turn it into boards.

## Skills and professions

Skills grow by doing the work, and related skills grow more slowly alongside. A forester gains forestry fastest, plus small fractions of building and carpentry. A builder gains carpentry, a little forestry and less fine carpentry.

As skill rises, a worker begins to demand the resources and help his higher trade needs. When the stone pile grows, a miner who has become proficient in stonework turns mason, building stone walls, roads, hearths and wells. Stone roads the player designates then raise the demand for stone further.

Base needs come first. A mason doesn't start laying stone while there is no campfire for the cook or fireplace for the cold. A builder doesn't make bed frames before everyone has a roof and a floor.

When an input runs short, the trades that depend on it go unemployed and their workers revert to gathering it. A builder reverts to forester, and with no meat or fur, a tailor or cook reverts to hunter. Nobody refuses basic work because he has moved past it.

There are 23 proficiencies, of which about 15 are attainable by ordinary workers. Master trades such as architect, craftsman, brewer, chef, doctor, engineer, blacksmith and stone carver are held by one or two people, depending on demand, and are gated by research.

Most of the village does low-level production. By the time senior roles arrive, there may be no one capable of being an engineer or surgeon.

Roles come into being in two ways. Earned roles are filled by capability, technology and demand: a healer becomes a doctor and then a surgeon by doing the work, as technology allows, and the player cannot appoint one. Appointed roles are hired by the player and paid a wage.

The tier labels serf, peasant and nobility are preliminary, and this report uses earned and appointed as working labels. Class follows how a person earns a living: producing goods, or drawing a wage and charging for services.

&#91;embedded content: earned trades · from the four starting jobs\]

Cook, chef and brewer can be reached from either hunting or gathering.

The appointed roles as drafted, with the senior role each line leads to:

| Senior role | Promoted from | How the line starts |
| --- | --- | --- |
| Treasurer | Page | Pages tend to the early stages of economic management |
| Quartermaster | Merchant | Merchants oversee the movement and production of goods; innkeepers and storekeepers work in this line |
| General | Men-at-arms | Men-at-arms are soldiers, improved from guards |
| Sheriff | Guard | Guards are hired to ward off bandits |
| Knight | Squire | Squires are the best of the soldiers and the player's guard |
| Researcher | Tutor | Students are hired, and tutors are improved from students |

Senior roles require currency, and each takes an area of responsibility off the player's hands.

## Research

Research is not picked by the player. A discovery becomes possible only when its prerequisite research is done and someone in the village is capable of the task it needs. What gets discovered from that pool is rolled when an attempt completes, with lower-tier discoveries more likely than higher ones.

The researcher's skill raises both the speed of research and the chance of a discovery. If a highly skilled researcher dies in a raid, a low-skilled replacement fails to discover anything until his own skill rises.

Discoveries are broad. They cover a class of designs, or how to use a known or new resource, such as making steel from iron. Fine toolmaking helps the tailor and the farmer as much as the carpenter and the mason.

For example, fine carving needs research so that the forge worker knows how to make fine carving tools. Once those tools exist, the fine carpenter can hone his skill.

The researcher is paid a wage from levies, since he produces no goods to sell. Research creates monetary conditions for the town and the player and builds the economy alongside the other wage jobs. It also creates co-dependence, slows progression a little, and gives the player something to manage once base needs are met.

## Economy

Demand drives production, and the player never orders a product. Merchants are appointed to oversee the movement and production of goods. They create demand for roads, handle transport and distribution, and make sure stockpiles reach the people who need them.

Merchants create the labor demand for serfs, and the merchant class will be the most fleshed out. Merchants require improved goods, which raises demand for carpenters and craftsmen. Guards require armor and weapons, which raises demand for iron.

A baker asks for grain, eggs and milk. If the village can't produce them in surplus, the baker stagnates and the village's growth is delayed.

Farmers and herdsmen raise the output of the hunters and gatherers who work for them, and add byproducts such as milk, wool and eggs. Gatherers become the farmer's workforce, and the farmer spends his disposable income on finer goods and better living conditions for them.

Serfs are unpaid. They create the colony's wealth through resource production and low-quality goods, benefit from improvements last, and must be cared for. As the colony grows richer they demand more, and they become rebellious if those demands go unmet.

Selling surplus to traveling merchants is the main source of coin, and it keeps demand for production high. Taxes fill the coffers, and gold and silver paid out as wages trickle down to the people, who spend them.

Minting adds coin once gold and silver seams are found, which takes skilled miners and engineers for deep mines. Some coin is also generated. As disposable income grows, peasants and nobility pay architects and engineers to improve their buildings.

&#91;embedded content: money flow · how coin enters and circulates\]

Wages paid out of the coffers come back through purchases and taxes, while serfs work unpaid and are cared for by those they work for.

Appointments carry a cost. Each one shows its requirements before it is made: an innkeeper needs a cook or chef and an inn, which ties up a cook who can no longer gather or work for a farmer. Pulling an appointed worker back to basic production makes him unhappy, lets his building fall into disrepair, and wastes the resources and time spent on it.

## Population and pressures

New people arrive periodically: bands of traveling merchants, lone wanderers and refugees. Some bring problems, which are left for later design.

Progression is pushed from below. As workers become skilled in higher tiers, they grow unhappy if the town doesn't progress to meet their new demands, and if their needs go unmet they leave. Stagnation is not an option.

Wealth and size determine renown, and renown sets the size of later attacks. The four pressures chosen early in the discussion are summer sieges, winter and famine, a liege's tribute, and peasant unrest.

In play, those pressures become the emergent gameplay: keeping the connecting roads secure, dealing with bandits and famine, and keeping demand from outpacing production. Preparing for winter means surplus food, preserved food and winter clothes.

Protection is the player's job as much as management. If bandits kill the hens and the workers, everyone resents the player, because he should have had guards ready. Events are meant to be manageable, not impossible, though a player may need several runs to learn what is required of him.

The player can also cause problems himself: by improving too fast, by hiring merchants below the skill needed to oversee production, or by admitting problem travelers who want to settle.

## Information and interface

The player has all the information he needs to observe the development, needs and skills of the population and the town. Tooltips help, but the game doesn't hold his hand.

A supply, demand and production window shows what the village is doing and whether needs are met. Before the player appoints someone, it shows what the role requires, and the supply view shows a deficit if the town can't meet it. Hiring a baker, for example, means builders put up a bakery, and the window shows what that requires before the baker is assigned.

The player can also see everyone's aptitudes and the job tree, including what each job requires.

## Presentation

The world is a simple, layered 3D world in which everything is built from square blocks. Assets are generated procedurally in the manner of .kkrieger, with basic colors and textures.

Procedural generation carries the design. When the player does things right, development has to click and progress visibly: buildings must make sense, and growth must be satisfying to watch.

The player has to be confident he can manage the big problems without coming back to a village in arms and serfs burning down the inn. Engine design is left for a separate discussion.

## Proposals and open questions

These ideas came up in discussion as suggestions and are not yet part of the design. The Decision column is for marking each one.

### Proposals

| Area | Proposal | Decision |
| --- | --- | --- |
| Reversion | Workers revert at one stock level and return at a higher one, so they don't flicker between jobs | Undecided |
| Reversion | Only as many workers revert as the shortage needs, starting with whoever is best at the upstream job | Undecided |
| Tools | Tools wear out, keeping steady demand on the forge | Undecided |
| Tools | Each trade has a few tool tiers, each capping how high the trade can go | Undecided |
| Research | Discoveries are weighted toward trades whose workers have hit the limit of their tools | Undecided |
| Research | The researcher's skill caps the highest tier he can reach | Undecided |
| Research | An apprentice researcher can be funded as insurance against losing the master | Undecided |
| Research | Tutors can do low-tier research before a senior researcher exists | Undecided |
| Serfs | Serfs owe a set number of labor days a week, as a dial between output and resentment | Undecided |
| Trade | Each caravan arrives with limited coin and specific wants, and pays less for goods it has been flooded with | Undecided |
| Newcomers | How often people arrive depends on how well the settlement is doing | Undecided |
| Newcomers | Travelers show hints (where they came from, what they carry, how they talk) rather than full stats | Undecided |
| Departures | Skilled workers who leave take their tools, and word spreads so fewer people arrive | Undecided |
| Unrest | Unrest escalates in visible steps: complaints, slow work, theft, leaving, then violence | Undecided |
| Raids | Bandits announce themselves first, through sightings, rumors or a small probing raid | Undecided |
| Interface | The supply window forecasts deficits, so a midwinter shortage shows up in autumn | Undecided |
| Officials | Appointed officials report to the player, and their reports are only as good as their skill | Undecided |
| Player | Leading in person is worth something and is dangerous, since the run ends with his death | Undecided |
| Learning | A chronicle or end-of-run record traces late failures back to the decisions that caused them | Undecided |

### Open questions

- [ ] Is diplomacy the one area of responsibility the lord keeps for himself?
- [ ] How do merchants judge demand: prices that move with scarcity, or shortages against need?
- [ ] What happens when the treasury can't pay wages?
- [ ] Where does the generated coin come from?
- [ ] Do walls and arms count toward the wealth that draws attackers?
- [ ] How does the liege's tribute work?
- [ ] Where do squires come from: pages, or the best men-at-arms?
- [ ] Who are the courtiers that senior roles are drafted from?
- [ ] What are the final names for the role tiers?

## Next steps

- [ ] Profession tree: weights and thresholds for each proficiency, plus what raises it, which skills it feeds, what each role produces and needs, and what it reverts to
- [ ] Technology tree: each discovery's prerequisites, capability gate, tier, the trades it helps and what it unlocks
- [ ] Engine design, in a separate discussion: the block world and procedural generation
- [ ] First build target (proposed): the first winter with the starting group, covering needs, the four starting jobs, the habitation zone, reserves, skill gain, reversion, a procedural hut, and a winter that uses up food and firewood, with no coin, merchants or research yet
