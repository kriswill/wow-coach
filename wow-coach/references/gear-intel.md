# Gear intelligence — BiS map, shopping list, crafting, stat mix

Built once per session by the gear-research agent (see
`references/research-agents.md`), then consulted live by the monitor loop.
Keep the results in a session note (a scratchpad file works) shaped like the
tables below, so lookups during the raid cost nothing.

## 1. BiS list, keyed by source

The player's current slot occupants come from the `loadout` MCP tool on a
recent instance fight (item ids, ilvls, enchants, gems per slot — no paste
needed; a SimC paste adds the bag/currency picture). Have the agent produce
the current BiS / near-BiS list for the player's class + active spec — from MythicSim-style sim rankings, murlok/archon
top-player usage, and Method/Wowhead BiS guides — and **key every item by
where it drops** (boss + instance, dungeon, crafted, vendor). Rank items
within each slot; note the sim-vs-usage disagreements rather than papering
over them.

## 2. Shopping list for anticipated bosses

Cross the BiS map with the bosses the player is likely to face — tonight's
raid instance (from `list_fights` names / the visit's instance), their M+
rotation, or an explicit target list. Output: for each anticipated boss, the
item(s) worth rolling on, with the player's current slot occupant and the
verdict (upgrade / sidegrade / skip). This is the artifact the live loop
uses:

**Live trigger**: when the monitor shows a new boss engaged or the raid is
clearly approaching one (trash segments named after it, prior boss just
died), check the shopping list — if a wanted item drops there, tell the
player *before or right after the kill*, one line: item, why, over what.
Verify the equip on the next pull with the `loadout` MCP tool (the item
id is in the slot or it isn't — shopping-list items are keyed by item id
for exactly this); a looted-but-unequipped upgrade also shows in the logs
as the old trinket's procs still firing — call that out too.

## 3. Crafting guidance

Ask the agent for the class/spec's currently-recommended crafted pieces
(weapons/off-hands/embellishments and the meta stat choices on them), what
they cost, and which slot they free the player from chasing. Cross-check the
player's own professions from the SimC paste — an alchemist gets consumable
self-supply notes, a crafter may be able to make their own piece. Deliver as
"craft this, with these stats, it replaces chasing X".

## 4. Stat mix — all specs of the class, plus a bag audit

- Collect the stat priority (with any soft caps / DR breakpoints) for
  **every spec of the played class**, not just the active one — players
  swap, and the coach follows. Node-level top-player stat averages (murlok)
  are the calibration; guide priorities are the explanation.
- Compare the player's current percentages (SimC paste / character sheet)
  against the top-player averages for the active spec. Flag only real
  deviations (a stat >5 points off the meta average, or an over-invested
  stat the meta shuns — versatility is the usual offender). "Your spread
  already matches the meta" is a legitimate and valuable verdict — don't
  invent a regemming project to seem useful.
- **Bag audit**: from the paste's `### Gear from Bags`, list items that beat
  the equipped piece on ilvl or trade a shunned stat for a favored one.
  SimC lines carry item ids + bonus ids, not stat values — resolve stats via
  the research agent (wowhead item pages) for the handful of candidates, not
  the whole bag. Frame swaps as "worth trying / sim to confirm", and prefer
  simming (Raidbots or a local SimC) for close calls over hand-waving.

### Local sim data first: `references/secondary-sims.tsv`

Before asking an agent for stat priorities, grep bloodmallet's
secondary-distribution sims — local, no web:

```sh
grep -P '^warlock\tdemonology\t1\t' references/secondary-sims.tsv
```

Rows are `class spec targets rank crit_haste_mastery_vers dps`: the
`targets` column is the profile (1 / 3 / 5 targets, mirroring a Raidbots
1T/3T/5T setup), the distribution is *percent of the secondary budget* in
crit/haste/mastery/vers order, rank 1 = best, and rank 0 carries the total
rating budget plus the grid-worst DPS so you can see the whole spread.
Read them like a sim, not a commandment:

- The top handful of rows usually sit within a fraction of a percent — that
  plateau, not the single rank-1 split, is the target. Only flag a player
  whose spread falls *off the plateau* (compare their actual percentages
  against the top-15 region, and weigh the rank-0 worst row to see how much
  a bad split even costs for this spec).
- Compare 1T vs 3T vs 5T rows before advising: when the ordering flips with
  target count, the advice is content-dependent (raid vs M+) — say so.
- This complements, not replaces, the murlok top-player calibration in §4:
  sims give the shape, top-player gear shows what's achievable with real
  itemization. Soft caps / DR breakpoints still come from research.
- Missing spec = bloodmallet has no chart this build; say "no sim data".
- Refresh per patch: `scripts/fetch-secondary-sims.sh`.

## 5. Trinket lookup — `references/trinket-sims.tsv` (local, no web)

Bloodmallet's trinket sim charts, flattened: one row per trinket per spec,
tab-separated `class spec rank trinket item_id ilvl:dps,...`, rank 1 = best,
rank 0 = the passive-stat baseline at minimum ilvl. Header lines carry the
fight style, sim date, and SimC build. Consult it whenever a trinket
question comes up — SimC paste review, a drop call from the shopping list,
or a bag-audit close call:

```sh
grep -P '^warlock\tdemonology\t' references/trinket-sims.tsv | head -12
```

- Compare at the *player's actual ilvls*: a rank-9 trinket at 334 routinely
  beats a rank-2 at 298 — read the dps off the matching `ilvl:` step, don't
  compare ranks alone.
- This is single-target data (`castingpatchwerk3`); say so when the question
  is M+/AoE, and let a research agent referee if it matters.
- In the evidence hierarchy this counts as **sim ranking** — it outranks
  guide tier-lists, and the header's sim date is its freshness receipt.
- A class/spec missing from the file means bloodmallet has no chart for it
  this build (their SimC module is down) — say "no sim data", don't guess.
- Refresh once per patch (or when the header date looks stale):
  `scripts/fetch-trinket-sims.sh [fight_style]`.

## Honesty rules apply throughout

Item effects and rankings follow the same evidence hierarchy as talents:
sim rankings and top-player usage outrank guide tier-lists, which outrank
prose. An item the agent cannot find in loot tables gets "couldn't verify",
not a guess — and any BiS claim delivered to the player names its source.
