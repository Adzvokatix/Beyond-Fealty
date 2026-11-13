# Stage 5b brief: skills (phase B)

2026-11-10. **Accepted as built, 2026-11-10.** John said "5b it is"; the rules below were drawn from his
design documents (the design report's "Skills and professions", the organized design, jobs.txt, the
plan's line for this stage) with first values of mine, the stage was built on them on branch `stage-5b`,
and they were put to him as "agree, or change any". His answer, after trying the build: "I only have
critiques that don't concern functionality that we can tweak later, the important part is getting the
structure in place and working. So 5c it is." So the stage is closed and merged with the nine rules
standing as built. They are first values he has not gone through line by line: his critiques (not
listed, not about function) are still to come, and any of the nine is his to change.

- **Goal:** people are better at some work than other work and get better at what they do; the player
  can see who is good at what, and who would learn it fastest, and give jobs to match.

## Pillars touched

| Pillar | How it is met |
|---|---|
| 3 Serfs are self-reliant | Nobody is taught or told to practise: skill comes from doing the work |
| 5 Conditions improve things; clicks don't | No upgrade, no training order: a level rises with hours worked |
| 7 Emergence over scripting | Who is worth which job is in the people, for the player to find; a band left in one job grows into it |
| 8 Evidence, not explanations | The sheet states a level and an aptitude; it does not say whom to assign |
| 9 Few natural parameters | One rate, one learning time, one table of what work teaches what |
| The player's interface | Skills are rows of the person's sheet, so the tooltip, the list and the menu show them with no code of their own |

## In scope

1. **Skills as state.** Each member has a level, none to mastery, in each skill. Five are the skills of
   work that exists: gathering, forestry, hunting, portering, cooking. Six only grow alongside, for the
   trades to come: building, carpentry, stonework, farming, tanning, taming.
2. **What a level does.** The framework's hook: every work timer runs at rate = condition x skill x
   direction. Condition is what it was (slower starving). Skill is the level in the work's own skill.
   Direction is 1 for everyone until a trade directs helpers. A hunter's level also moves its chance to
   hit, a cook's what the pot yields. The short work times get names.
3. **Start levels and aptitude.** People arrive with levels of their own; each has an aptitude for each
   skill, fixed for life, that says how fast it learns it.
4. **Skill by doing.** An hour of work is an hour of practice in the work's skill, with fractions to
   the skills beside it. It goes by the work done, not the job held.
5. **Seen through the scaffold.** Rows on the person's sheet (so the tooltip and the list's tooltip show
   them); level and aptitude beside each job in a person's menu; a Skills tab in the band panel: a
   table of everyone. The band's log gets a line on its skills.
6. **A switch.** Skills can be turned off (`--no-skills`): everyone works at the old pace. With it the
   reference run must be stage 5a's, line for line.
7. **Saves.** Colony blob 12: the switch and each member's levels.

## Out of scope, and where each goes

| Named for this stage in the plan or the framework | What 5b does about it |
|---|---|
| Job tiers | Deferred to the first earned trade (stage 6 or 8). Today's six jobs can all be given to anyone; a tier has nothing to gate yet. What a tier will stand on is here: each job's own skill and everyone's level in it |
| Earning a trade by skill; reversion | With that first earned trade, as the framework's open decisions already say |
| The serf menu ("an Unassigned tab and a tab per job") | It is the Skills tab, the person's menu and the person's sheet. A tab per job is not built: one scroll list holds the 48 people there can be; sorting and filtering wait for a need |
| Capacity as a function | Deferred to the first post that directs helpers (the farmer). 5b builds the rate half of that hook, with direction in it at 1 |
| Tools that cap a skill; teaching; forgetting | Later phases (tools: D). A level never falls in 5b |

## Rules proposed to John (standing as built since 2026-11-10; see the top)

1. **The skills there are now** are the five of today's work and the six trade skills named above. More
   come with their trades.
2. **A level changes the pace of the skilled part of work only**: three quarters of today's pace with no
   skill, today's pace at a third of the way to mastery, half as fast again at mastery. Carrying,
   lifting, putting down and walking are not skilled. A hunter's chance to hit runs from 0.8 to 1.4 of
   today's, a cook's pot from 0.9 to 1.2.
3. **People arrive unequal.** 15 to 50 % in each of the five working skills (an elder 20 points more, a
   child half), next to nothing in the trades. So a starting band works at about today's pace on the
   whole, one of them better and one worse.
4. **Aptitude** is how fast a person learns a skill, from half to one and a half times, one for each
   skill. Whoever has the best aptitude for cooking takes up cooking on its own (the same person as
   before this stage). That is the band's fastest learner, as the design report has it, not its best
   cook on the day: its level is its own draw. Before skills the self-chosen cook was the best cook by
   construction and its pot gave about 7 % over; now the first pot is about par. (John was asked
   whether it should be the best level instead and did not take it up: it stands.)
5. **An hour on the job is an hour of practice**: the whole trip counts (going out, the work, carrying
   it home), not only the moments of skilled work, or a forester, whose felling takes minutes and
   whose carrying takes hours, would never learn. It teaches the work's own skill in full and the
   skills beside it by the fractions in the table below. Learning is fastest from nothing and slows
   toward mastery: 600 hours of work close the gap to mastery by about two thirds (a little over a
   season of full days makes a middling worker a good one; mastery takes years).
6. **Practice goes by the work done, not the job held.** A cook out gathering learns gathering; so
   does anyone fending for itself.
7. **The player sees everyone's levels and aptitudes** ("the player can see everyone's aptitudes and
   assign jobs to match"). They count as things his character knows.
8. **Nothing is gated by skill yet.** Any job can still be given to anyone.
9. **Carried from 5a:** a member whose job nobody gave it (the unassigned; the cook who chose itself) is
   directed by no one. It stands as built unless John says otherwise (he has not).

| Work | Its own skill | Alongside |
|---|---|---|
| Picking (berries, vegetables, apples) | gathering | farming 0.2, cooking 0.1 |
| Felling, and carrying the logs | forestry | building 0.15, carpentry 0.1 |
| The hunt (stalking, the shot) | hunting | taming 0.1 |
| Bringing in the kill, butchering | hunting | tanning 0.3, cooking 0.2 |
| Cutting straw | portering | farming 0.3 |
| Prising stone | portering | stonework 0.3 |
| Keeping the camp (the fire, the pot) | cooking | none |

## State and saves

- New state: a switch; each member's level in each skill. Colony blob 12, which stores how many skills
  it holds, so skills added later still load.
- Aptitudes and start levels come from the member's seed and are not saved. The cooking aptitude is the
  number `Cooking_Of` already gave, so the same member is the band's best cook.
- Older blobs: skills on; each member gets the start levels it would have arrived with.
- `tools/colony_v11.bin` was cut with the version 11 code before any of this (a forester mid-chop).

## Packages

- Touched: Castle.Colony (state, the rate, practice, the pot and the shot), Castle.Views (skill rows),
  Castle.Actions (a job's label in a menu), Castle.HUD (the Skills tab), Castle.UI (text in columns),
  Castle.Scenario (`--no-skills`, the skills line).
- New: none.

## Leaves room for

| Later system | The hook it needs from here |
|---|---|
| Habitation (6): builders from foresters | The building level foresters have been gaining; a threshold on it is one comparison |
| Earned trades and reversion (8) | A job's own skill; the table of what work teaches what |
| The farmer and his hands (10) | Direction is already a factor of every work rate; capacity is a function to add beside it |
| The demand chain (5c) | Nothing: skills change how fast demand is met, not what is asked |
| Tools (D) | A cap on a level is one line in the practice step |
| Balance (G) | Every number is a named constant in the colony's spec; `--no-skills` gives the baseline |

## Tunables (first values; balance waits for phase G)

- Novice_Rate 0.75, Master_Rate 1.5. Novice_Aim 0.8, Master_Aim 1.4. Novice_Pot 0.9, Master_Pot 1.2.
- Learn_Hours 600. Aptitude 0.5 to 1.5.
- Start levels: 0.15 to 0.5 in the working skills (Elder_Start +0.2, Child_Start x0.5); 0 to 0.1 in the
  trade skills.
- The table above (`Learns`).
- Work times named: putting a load down 1 s, lifting a log 1.2 s, lifting a deer 2.5 s, taking from a
  cell 1 s, putting into the pot or on the fire 1 s, giving up a stalk 90 s.

## Check

- colony_check: start levels and aptitudes in their ranges and the same for the same seed; two
  gatherers of unequal skill pick at unequal pace, in the ratio the rule gives; carrying and putting
  down take the same time whatever the skill; a level follows the learning curve to within rounding;
  the fractions reach the skills beside it; nothing is learnt idle, eating or asleep; a cook out
  gathering learns gathering; the shot and the pot move with skill; with skills off the pot and the
  shot are exactly what they were; the first cook is who it was; a save mid-work round trips to the
  same bytes; the version 11 blob loads into skills and saves as 12.
- The older sections of colony_check run with skills off, as they run with needs off.
- The reference run with `--no-skills` gives stage 5a's log line for line, and with the blob written in
  the version 11 layout, its state hashes. The reference run with skills is recorded beside it.
- ui_check: text in columns.

## Demo

Half a minute at the start (a person's tooltip with its skills; the Skills tab; a menu showing level
and aptitude beside each job, and a job given from it), then the same band twenty days on, from a
windowless run: the Skills tab again, the levels risen. `tools/demo_stage5b.sh`.

## Added in the building

- `--by-skill` (the scripted jobs to whoever is best at each), `--skills-at LEVEL` (a band of novices
  or masters, to measure what skill is worth) and `--job I JOB` (one member's job), beside `--no-skills`.
- `tools/reference_check.sh`: the 41-day reference run with skills off against stage 5a's log, as a
  standing regression for everything in the colony that is not skills.
- Levels are kept as Long_Float: a step's practice in a neighbouring skill is below a Float's
  resolution near mastery.
- `Castle.UI.Column_Text` and `Next_Line`, for the Skills tab's table in a scroll list.

## Read list

docs/systems/colony.md (Zones, Who directs whom, Actions), interface.md ("Two interfaces, one layer"),
needs.md; docs/design/Preliminary_Design_Report.md ("Skills and professions"), jobs.txt.
