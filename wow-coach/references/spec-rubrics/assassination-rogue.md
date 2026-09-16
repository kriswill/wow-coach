# Assassination rogue — coaching rubric (Midnight 12.1, S2)

Built 2026-09-15 for Trnq (Kris's rogue, level 80 → 90 via Timewalking; not
graded until 90). Layered on top of `../analysis-rubric.md` — that file's
triage order (downtime → cooldowns → burst → target priority → deaths →
consumables) and evidence hierarchy still bind; this file supplies the
spec-specific numbers. Every number below is tagged **S** (sourced, URL in
§9), **I** (inferred by the research agents), or **LOG** (settle it from the
player's own first logged fight — it outranks both).

## 0. Kit changes in 12.1 that invalidate old instincts

| Old habit | 12.1 reality | Grade as |
|---|---|---|
| Shiv on cooldown as a DPS button | Icy Veins: "no longer part of our DPS rotation whatsoever"; Method's rotation page still says "on cooldown" (stale) **S** | **SETTLED 2026-09-15 (Trnq, Blackrock Caverns TW): 0 Shiv casts across 5 bosses** — do not flag it |
| Cold Blood (active) | Now the passive "Cold Blooded Killer" proc, +10 % crit on the next finisher **S** | N/A — never ask for it |
| Indiscriminate Carnage, Serrated Bone Spike | Removed **S** | N/A |
| Crimson Tempest as an AoE finisher | Now a **builder** that spreads Garrote + Rupture to mobs lacking bleeds **S** | AoE opener, see §4 |
| Thistle Tea manual timing | Choice node; auto version fires under 30 energy, 1 charge/min, "no manual benefit" **S** | Only check charges are consumed ≈ 1/min |
| Slice and Dice | Absent from every 12.1 Assassination guide fetched **I** | **SETTLED 2026-09-15: Slice and Dice IS still applied** (4 applications in one TW dungeon) — track its uptime like the bleeds |
| Deathmark bonus | 75 % (was 100 %) **S**; Kingsbane −15 % **S** | — |
| Implacable | Redesigned: "refreshing Envenom late is consistently the best" **S** | see §2 |

## 1. Build sanity (before any grade)

- **Hero tree = Fatebound** for raid and M+ by usage: murlok top-50 M+ 78 %,
  archon high keys 92.6 %, u.gg Mythic raid 1,573 Fatebound parses vs 2
  Deathstalker **S**. Method/Maxroll prose says Deathstalker +2–5 % — prose,
  outranked by usage. Note the Icy Veins *leveling* string Kris imported at
  80 is Deathstalker; at 90 swap to a Fatebound string (the Icy Veins M+ one
  decoded clean: Fatebound, 74 nodes).
- Poisons: **Deadly + Amplifying always** (lethal pair), Atrophic non-lethal
  in raid, tank's call in keys **S**. A missing poison aura in `loadout`/log
  is finding #1 before anything else.
- Fatebound M+ string (Icy Veins, verbatim, decoded OK 2026-09-15):
  `CMQAAAAAAAAAAAAAAAAAAAAAAYmlZmFDGAAAAAY2GsNDAAAAAIbzMzMzMjxyMzMbzsMzMPgZMzYMMzYMAGYBmxoxsBYbAbGAMzMGD`

## 2. Rotation checks (single target)

| Check | Good | Finding | Log signature |
|---|---|---|---|
| Garrote uptime | ~100 % goal **S**; ≥90 % acceptable **I** | <90 % | aura uptime on the boss; refreshes at 0 s remaining = "allowed to expire" |
| Rupture uptime | same; refresh in pandemic ≤7.2 s left at 5 CP (24 s base; 8.4 s / 9.6 s at 6 / 7 CP) **S** | <90 %, or refreshes with >8 s left (clipping) | Rupture cast timestamps vs prior application |
| Envenom | chained at **5+ CP** (7 CP when Darkest Night is up, Deathstalker only) **S**; refresh late (Implacable) **S** | casts at ≤4 CP; buff gaps while energy >70 | `SPELL_CAST_SUCCESS Envenom` CP field; Envenom aura gaps |
| Improved Garrote (from Vanish/stealth) | never overwritten by a normal Garrote **S** | a Garrote cast while the empowered one is up | Garrote recast inside its own duration right after Vanish |
| Kingsbane | inside Deathmark on every second use, 100 % melee + Envenom uptime during its 14 s **S** | Kingsbane cast >10 s from a Deathmark that was available | timeline marks |
| Thistle Tea | ≈1 charge/min consumed **S** | manual version parked at max charges | cast count vs floor(t/60)+1 |
| Poison uptime | both lethal poisons on the boss all fight | either <95 % **I** | aura uptime |

Expected shares, raid ST (Noxxic sim ilvl 338, Fatebound; **sim, not log —
soft bands**): Envenom 25–30 %, Rupture 15–20 %, Garrote 15–20 %, Kingsbane
~10 %, Amplifying Poison ~8 %. A breakdown with Envenom <20 % or a bleed <12 %
points at the row above, not at gear.

## 3. Cooldown counts

Expected casts = floor(combat_s / CD) + 1; 30 %+ under = held (generic rule
from `../analysis-rubric.md`; no rogue guide states its own tolerance).

| Cooldown | CD | Duration | Notes |
|---|---|---|---|
| Deathmark | 2 min **S** | 16 s | first use within 10 s of pull; never on a target about to die |
| Kingsbane | 1 min **S** | 14 s DoT | every second one inside Deathmark |
| Vanish → Improved Garrote | 2 min **S** | — | "ideally lined up with Deathmark" **S** |
| Shiv | base CD not extracted; Toxic Stiletto −15 s **S** | — | **LOG** whether it is cast at all before grading it |
| Thistle Tea | 1 charge / min **S** | — | see §2 |

## 4. AoE / keys

- Opener on a pack: **Crimson Tempest until every mob that will outlive a
  bleed has Garrote + Rupture, then Fan of Knives as the builder on 3+
  (Method says 2+), Envenom once all DoTs are out** (Envenom also applies
  Caustic Spatter) **S**.
- Do not bleed mobs that die inside the DoT **S** — Rupture ticks on a mob
  that died 4 s later is the signature.
- Target priority per the generic rubric: share on the priority target vs
  overall share, >10 points lower = padding.
- Trinket/stat context (bloodmallet 2026-09-09, local TSVs): top trinkets at
  321 = Voracious Heart of Ula'tek 319.0k > Font of Venomous Rage 314.2k ≈
  Zul'jin's Guillotine Technique 313.7k; Gebbo's Bag 315.3k, Freightrunner's
  Flask 314.7k. Best secondary split crit-heavy: 40/30/20/10
  (crit/haste/mastery/vers) at 1 and 3 targets, 30/40/20/10 at 5.

## 5. Burst alignment

Inside each Deathmark window: Kingsbane, Vanish→Improved Garrote, potion,
on-use trinket, and an unbroken Envenom chain **S**; Maxroll: the window "is
not a fixed rotation" — grade presence, not order. Generic ±10 s tolerance
applies to lust/potion marks. The potion is **Light's Potential** for
agility users too (same item grants Str/Agi/Int by spec **S**), so the
`consumable` mark label is the same string as the casters' — unless the
player runs Potion of Recklessness (crit-stacking alternative **S**);
**LOG** the label on the first pull.

## 6. Deaths — defensive kit

| Button | CD | What it answers |
|---|---|---|
| Cloak of Shadows | 2 min, 5 s | magic (DoTs, casts, most "ground" damage that is a spell) **S** |
| Evasion | 2 min, 10 s | melee only **S** |
| Feint | 15 s, 6 s, 40 % AoE reduction, 2 charges talented, 35 energy **S** | raid-wide / AoE pulses |
| Crimson Vial | 30 s, 20 energy, larger heal in Midnight **S** | low-HP dwell |
| Vanish | 2 min | threat drop / a fixate |
| Cheat Death (choice vs Elusiveness) | once per 6 min **S** | the one-shot; unavoidable only if the hit is >2× max HP |

Grading (generic rules + **I**): *defensible* = the matching button was
available and unpressed (magic→Cloak, melee→Evasion, pulse→Feint charge,
<40 % dwell→Vial); *mitigable* = the matching one on CD but Feint/Vial up;
*unavoidable* = everything on CD, or a hit ≥150 % max HP with Cheat Death
already spent. Rogues have MORE answers than the DH/warlock — a zero-
defensive death is a finding every time.

## 7. Consumables

Potion on pull + the 5-min re-use (generic rule). Kris's pattern on three
other characters: **potion fires only when lust cues it** — check the
no-lust bosses first.

## 8. Benchmarks that do NOT exist yet

No published DPS bands for ilvl 300–320 Heroic / +10–14; no WoWAnalyzer
module for 12.1 Assassination; no group-share figure; no explicit "needs
work" uptime number from any guide. Benchmark #1 is therefore the store's
own `trend` per encounter + difficulty once Trnq has fights, and #2 the
fight's DPS-role median. Say so in the first report rather than inventing
a band.

## 9. Sources

Icy Veins rotation https://www.icy-veins.com/wow/assassination-rogue-pve-dps-rotation-cooldowns-abilities ·
Icy Veins overview/changes https://www.icy-veins.com/wow/assassination-rogue-pve-dps-guide ·
Icy Veins M+ https://www.icy-veins.com/wow/assassination-rogue-pve-dps-mythic-plus-tips ·
Icy Veins leveling https://www.icy-veins.com/wow/assassination-rogue-leveling-guide ·
Maxroll raid https://maxroll.gg/wow/class-guides/assassination-rogue-raid-guide ·
Maxroll M+ https://maxroll.gg/wow/class-guides/assassination-rogue-mythic-plus-guide ·
Method rotation https://www.method.gg/guides/assassination-rogue/playstyle-and-rotation ·
Method talents https://www.method.gg/guides/assassination-rogue/talents ·
murlok M+ https://murlok.io/rogue/assassination/m+ ·
u.gg Mythic raid hero usage https://u.gg/wow/assassination/rogue/talents/raid?difficulty=mythic&hero=fatebound ·
Noxxic ST sim https://www.noxxic.com/wow/sims/assassination-rogue ·
Wowhead: Deathmark spell=360194, Kingsbane spell=385627, Garrote spell=703, Cloak spell=31224, Evasion spell=5277, Feint spell=1966, Crimson Vial spell=185311, Light's Potential item=241309, Potion of Recklessness item=241289 ·
Method consumables https://www.method.gg/guides/list-of-all-midnight-consumables-enchants-and-gems ·
archon.gg returned 403 on every page 2026-09-15 (per-boss uptime tables unverified).

## Other rogue specs, one paragraph each (for spec swaps)

**Outlaw** — Sinister Strike to 5 CP, Dispatch / Between the Eyes at 6+,
Roll the Bones below stage 1, Keep It Rolling at stage 3+, Adrenaline Rush
into Killing Spree (12.1: +15 % per surplus CP), Blade Flurry at 2+ targets.
Trickster ~5 % ahead everywhere **S**.
**Subtlety** — two Shadow Dances per 90-s Shadow Blades, Secret Technique
(fixed 30 s CD) at 6+ CP, Shadowstrike / Shuriken Storm builders; Rupture,
Symbols of Death and Flagellation removed for Sub in 12.1. Deathstalker ahead
of Trickster **S**. Trnq's saved "DS Raid" string decodes as Subtlety /
Deathstalker (69 nodes); "TRK M+" arrived truncated in the 2026-09-15 paste.
