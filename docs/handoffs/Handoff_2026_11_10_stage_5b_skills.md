# Castle Game handoff (2026-11-10: stage 5b, skills; closed; Claude Code)

- Code: GAME_alpha_1_3/compiled, `main` (the stage was built on branch `stage-5b` from fb67a08 and
  fast-forwarded). The code John tried is 6bd44b5; the closing commit after it changes documents only.
  Zip: CASTLE_GAME/releases/castle_game_stage5b.zip, a git archive of the closing commit.
- Checks: all nine pass in debug, from a clean unzip of the zip; six known warnings. colony_check 243
  checks (was 206), ui_check 63 (was 59), pick_check 31. `tools/reference_check.sh` passes.
- Versions: Generator_Version 11 and save format 5, unchanged. Colony blob 12: the skills switch, how
  many skills the blob holds, each member's level in each.

## How the rules stand (2026-11-10)
John said "5b it is". The stage was built on nine rules drawn from his design documents, with first
values of mine (docs/production/briefs/Stage_5b_brief.md), and they were put to him afterwards as
"agree, or change any". His answer, after trying the build:

> I tested it mouse pointer and clicks work with a real mouse. I always test all your builds, I would
> like the ability to scale the UI a bit. I only have critiques that don't concern functionality that
> we can tweak later, the important part is getting the structure in place and working. So 5c it is.

So the stage is closed with the nine standing as built. He did not go through them line by line: they
are first values, his to tune, and his critiques (not listed; not about function) are still to come.

In short: five working skills and six trade skills; a level changes the pace of skilled work only
(0.75 with none, the old pace a third of the way, 1.5 at mastery), a hunter's aim (0.8 to 1.4) and a
cook's pot (0.9 to 1.2); people arrive unequal (15 to 50 %); aptitude is how fast each learns each
skill (0.5 to 1.5); an hour on the job, the whole trip, is an hour of practice in the work's skill,
with fractions to the skills beside it, 600 hours closing two thirds of the gap to mastery; practice
goes by the work done, not the job held; the player sees everyone's levels and aptitudes; nothing is
gated by skill yet.

Two things he was asked and did not take up, standing as built by default:
- **The first cook is the fastest learner, not the best cook on the day.** The design report says the
  highest cooking aptitude takes up cooking, and that is built (the same member as before). A level is
  its own draw, so the band's first pot is about par; before skills the self-chosen cook was the best by
  construction, about 7 % over. If it should be the best level instead, `Choose_Cook` compares one
  number.
- **The director question from 5a.** The unassigned and the self-chosen cook are directed by no one.

## What John confirmed by hand
The pointer and clicks, with a real mouse. He did not name the wheel over a list, a drag on a scroll
bar, or a touchpad's part-steps; those are still checked only by ui_check and the scripted pointer.
He tries every build, so nothing more is asked of him here.

## Asked for, not in this stage
- **A way to scale the interface a bit.** It follows on `main` as its own commit, after this zip.

## Built
- **Skills in the colony.** `Skill_Kind` (11), a level 0 .. 1 per member and skill (kept as Long_Float:
  a step's practice is a millionth of a level), aptitudes and start levels from each member's seed.
  `Work_Kind` names the work a member can be at; `Learns` is the table of what each teaches.
- **The work rate.** `Work_Rate (M, W)` = condition x skill x direction behind every work timer:
  picking, felling, the fetch (straw, stone, vegetables, apples, sticks), the draw of the bow,
  butchering and stirring by the level in the work's own skill; storing, lifting, taking and putting by
  condition alone (`Handling`); direction 1 for everyone. Walking and the hunter's patience (the 90 s
  after which a stalk is given up) stay on condition alone. The short work times have names.
- **The shot and the pot.** `Hit_Chance_Of`, `Pot_Yield_Of`.
- **Learning.** Each step, a member at work practises that work (`Work_Now`: the whole trip, by what is
  being got or carried). Nothing idle, eating or asleep.
- **Off.** `Set_Skills (False)`, saved: the one pace, the old shot, the old pot (0.9 + 0.2 x
  `Cooking_Of`), no learning.
- **Seen.** The person's sheet (its job's skill with a bar and "learns x1.3"; its best three other
  skills; what it is apt at); a person's menu ("Forester: 43 %, x1.1"); the band panel's fifth tab,
  Skills: everyone's level in the five working skills, bright where they learn fast, dim where slowly,
  boxed where it is their job's. `Castle.UI.Column_Text` and `Next_Line` for the table.
- **Options** (Castle.Scenario): `--no-skills`; `--by-skill` (scripted jobs to whoever is best at
  each); `--skills-at LEVEL` (a band of novices or masters, for measuring); `--job I JOB`. The log has
  a `skills:` line, and each member's job skill in the band's listing, when skills are on.
- `tools/reference_check.sh`: the standing regression (skills off = stage 5a's log).
- Demo: CASTLE_GAME/releases/colony_stage5b_skills.mp4 (42 s; `tools/demo_stage5b.sh`).

## What the plan and the framework named for 5b that is not in it (by the brief)
- **Job tiers, trades earned by skill, reversion:** deferred to the first earned trade (stage 6 or 8).
  Any job can still be given to anyone.
- **"The serf menu: an Unassigned tab and a tab per job":** it is the Skills tab, the person's menu and
  sheet. A tab per job was not built.
- **Capacity as a function:** deferred to the first post that directs helpers (the farmer). Direction
  is in the rate, at 1.

## Measured (seed 1, the reference setup, colony_run)
- **Skills off is stage 5a.** With `--no-skills` the 41-day log is stage 5a's line for line, and with
  the blob written in the version 11 layout the states are stage 5a's: 3 days 9609e60367c60fff, 41 days
  d3f9abae3bb7efce. So the rate plumbing, the named times and everything else are exact.
- **States with skills on** (blob 12): 3 days 1bc8acb9221efb47 (the same in debug and with 3 workers);
  41 days (--winter-store 10 --reserve meat 60) e7544f4f15a0096c; the log is
  docs/production/reference_runs/reference_run_stage5b.txt.
- **What skill is worth.** Ten days of the reference band (day 20 to 30), food in store at the end:
  everyone a novice 4.1 days; everyone at a third 6.1; everyone a master 8.6; skills off 6.6 (the
  scripted cook had one of the best cooking numbers, so its old pot gave 10 % more than a cook at a
  third does now).
- **The reference band with skills, jobs by position.** It arrives a little under par (gathering 0.27,
  forestry 0.27, hunting 0.37, cooking 0.28) and by day 45 is at 0.59, 0.54, 0.39 and 0.55. It goes
  into winter with the stores it had before (5.2 days against 5.3) and runs out a day sooner; on that
  knife edge all six die by day 58, where one died in stage 5a's run (there the last food went on day
  56 and spring came before most had been two days empty). Winter balance is untouched, by the
  designer's call.
- **Jobs by skill** (`--by-skill`) did not do better here: 4.2 days in store at day 45 against 5.2. The
  best gatherer is the elder, who walks slowest, and one run on one seed is noise as much as signal.
- **How fast they learn.** Measured: a band started at a third has its gatherers at 0.47 after ten
  days. By the rule a full-time gatherer at aptitude 1 is at about 0.8 after a 60-day year. Hunters
  learn least: they hunt only while meat is short.

## Saves
- Blob 12 appends: the switch (1 byte), how many skills (1 byte), then for each member that many levels
  (8 bytes each). A blob holding fewer skills than this build knows leaves the rest at their start
  levels; one holding more has the extra skipped.
- Before 12: skills on, everyone at the levels they would have arrived with.
- `tools/colony_v11.bin`: version 11, written by fb67a08 on the check's meadow, a forester mid-chop.

## Bugs found and fixed
- None in the game. (Float was too coarse for a level: a step's practice in a neighbouring skill is
  below its resolution near mastery, so the level would have stalled. Levels are Long_Float.)

## Known limits
- The Skills tab shows the five working skills; the six trade skills show only on a person's sheet,
  among its best three others.
- A level never falls, and nothing caps it.
- Hunting practice depends on the meat reserve: hunters idle once it is met.
- The scripted reference band is given jobs by position, so with skills on it is a careless lord's band.
- `--no-skills` does nothing for a colony loaded from a save: the save's own switch stands.
- The demo's second half shows a band of twelve at seven in the morning: several are "hungry" before
  breakfast, which reads worse than it is.

## Not done
- John's critiques of 5a and 5b, when he lists them.
- The upload to the Project (John's step).

## Next
- The interface scale John asked for, on `main`.
- Then stage 5c, the demand chain, on a branch, its rules put to John as 5b's were.
