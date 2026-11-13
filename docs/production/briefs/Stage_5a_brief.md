# Stage 5a brief: the scaffold (phase B)

2026-11-09. The five rules below were agreed with John on 2026-11-10, as written. Built and closed
2026-11-10 (docs/handoffs/Handoff_2026_11_10_stage_5a_scaffold.md); what changed in the building is at
the end.

- **Goal:** point at a person, a stockpile or the camp and see what it is and what you may do with it;
  and the development panels become views that the game's tooltips and reports will reuse.

## Pillars touched

| Pillar | How it is met |
|---|---|
| 1 The player says where | Zones become things with borders; nothing new is ordered through them |
| 3 Serfs are self-reliant | Nothing in this stage asks the player to do a serf's work; a tooltip only reports |
| 4 Failure is visible | A person's tooltip carries the reason it already states ("starving: nothing to gather in winter") |
| 8 Evidence, not explanations | Tooltips and zone views state conditions; they do not join them into causes |
| 9 Few natural parameters | One action table, one zone record, one view per kind of thing |
| The player's interface | Tooltips say, context menus do; picked by a ray; no modal dialog; the dev panels are the scaffold |

## In scope

1. **Zones as things.** A zone record: kind, bounds, an id, and what is inside it. The stockpile and the
   camp are its first two kinds. A stockpile zoned in one go is one zone that owns its cells (today the
   cells are loose). Older saves load with one zone made per connected group of cells.
2. **Who directs whom.** Each member records who delegated its work: the player today. Saved. No
   behaviour reads it yet.
3. **The action table.** Named actions, each with what it applies to (a person, a zone, the ground) and
   who may do it. First rows: set a person's starting job; follow a person; zone a stockpile; zone the
   camp; lay a path; raise the stake; set a zone's or the colony's surplus (the reserves that exist).
   The band panel's buttons and the scripted options go through it. The player may do all of them; a
   serf may do none yet.
4. **Data views.** A view of a person (name, job, who directs it, task and status, fed, mood, what it
   carries) and of a zone (kind, what it holds, what is coming and going). A view is data, not drawing:
   a panel, a tooltip and later a desk report each show it their own way.
5. **Picking things.** A ray (from the cursor now, from a reticle later) finds the nearest of: a person,
   a zone, a deer, else the block. Within a reach in metres, which is unlimited in the development
   view and a named tunable for the view on foot.
6. **Tooltip.** Hover a picked thing: its view, as rich as the thing is.
7. **Context menu.** Right click a picked thing: the actions the player may do to it, from the table.
   It closes on a choice or a click away, and never pauses or covers the world.
8. **Dev panels.** The band panel is rebuilt from person views, with tabs (Band, Stores, Camp, Orders)
   and a scroll list, so it stays usable past six people.

## Out of scope

- Skills, work rate and capacity (5b). The demand chain (its own stage after 5b).
- The player's character, the view on foot, the HUD for his person and inventory (stage 7).
- Draggable windows, text input, key rebinding from a menu.
- Any new job, building or resource. No behaviour changes: the reference run must give the same log.

## Rules agreed with John (2026-11-10)

1. A right click on the ground opens a context menu (zone here, path from here) instead of ending a
   path line as it does now; a path line is ended from the menu or with Esc.
2. In the development view the tooltip shows everything in a person's view, moods included. (The game
   will later show only what the player's character could know; the view marks which fields those are.)
3. One stockpile zoning is one zone; two that touch stay two zones.
4. Deer are pickable and get a tooltip (class, herd size, calm or alarmed) but no actions yet.
5. The dev panels stay on Tab and F-keys as now; nothing of the game interface depends on them.

## State and saves

- New state: zones (id, kind, bounds, its cells), each member's director. Colony blob version 11.
- Older blobs: a zone per connected group of stockpile cells, the camp's zone from the camp, every
  member directed by the player.
- Enumerations saved by position get new values on the end only.

## Packages

- Touched: Castle.Colony (zones, director, views, the action table), Castle.UI (tabs, scroll list,
  tooltip, context menu), Castle.HUD (the band panel from views), Castle.World_Blocks or a new
  Castle.Pick (the ray against people, zones and deer), Castle.Scenario (options through the table),
  game/castle_game.adb.
- New: Castle.Pick; Castle.Colony's views and actions as child units if they stay small and clean.

## Leaves room for

| Later system | The hook it needs from here |
|---|---|
| Skills (5b) | Fields added to the person view; the tooltip shows them with no new code |
| The demand chain | A zone's "coming and going" becomes its demand rows; surplus actions already exist |
| Habitation (6), farms (10) | New zone kinds on the same record, with the same view and menu |
| The player's character (7) | The ray comes from a reticle; reach becomes the tunable; the actor is a member |
| Permissions, delegation, law | "Who may do it" in the action table; the director field |
| Desk reports (E) | Zone and colony views shown on a page instead of a panel |

## Tunables (first values; balance waits for phase G)

- Reach_M on foot: 6.0 (unused until stage 7). Tooltip delay: 0.3 s. Scroll list rows shown: 12.

## Check

- colony_check: zones made, owned cells, a save round trip to the same bytes, an older blob loading into
  zones; the action table refusing what is not permitted; the director saved.
- ui_check: tabs, the scroll list, the tooltip and the context menu laid out and hit-tested with no window.
- A pick check on the made-up world: the ray finds the person in front of the zone in front of the block.
- The reference run gives the same state hash as before the stage, apart from the blob version: the
  check compares the log lines, which must be identical.

## Demo

A minute in the development view: hover people at work and read their tooltips; right click one and
change its job from the menu; hover the stockpile and the camp; open the band panel's tabs and scroll.

## Read list

docs/systems/interface.md, colony.md, people.md; the framework's "The player's interface", "Needs, then
demand", "Demand drives demand" and "Hooks to build before more mechanics".

## Changed in the building

- **Who directs whom.** The brief had every member of an older save directed by the player. As built,
  a director is whoever gave the job: the player for a job set from a panel, a menu or the command
  line; no one for the unassigned and for the cook who takes the job up on its own. An older save
  loads that way too (a job: the player's; none: nobody's), since it can no longer tell a cook who
  chose itself from one who was told. For John to confirm.
- **Views are two layers.** Typed views in Castle.Colony (Person, Zone_At: plain data), and
  Castle.Views, which turns them into sheets of named rows. Panels and tooltips show sheets.
- **The action table is Castle.Actions**, a package of its own, not a child of the colony. It has a
  row for every setter the panels and the command line used: also the winter store and the two
  protections. Castle.Colony.Supply stays outside it (goods from nowhere are nobody's to do).
- **Castle.Rays** was added: the block walk as a generic, so the check's made-up world is walked by
  the same code as the game's.
- **Added, not in the brief:** a note line that says what an order came to (a refusal and its reason);
  `--pointer`, a scripted cursor, without which no recording could show a tooltip or a menu; the
  pointer keeps whom it was on in a crowd; a band of more than six no longer gets two of one name.
- **The list shows up to 12 rows**, fewer when the window is too short for them.
- **The camp and a deer have no menu**: there is nothing yet to do to either. A right click on the
  camp's ground gives the ground's menu.

