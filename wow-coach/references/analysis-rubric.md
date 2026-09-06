# Fight-grading rubric

Report findings in this order — it's the community-standard triage order, and
the top items are repeatedly worth more than everything below them combined:
**downtime → cooldown counts → burst alignment → target priority → deaths →
consumables.**

## The checks

1. **Downtime.** Flag >2 near-zero 10s buckets while the player was alive and
   enemies were up. >95% active is excellent; <85% is the first thing to fix.
   An `alive_buckets` count far short of the fight length is an early death —
   grade that as mortality, not rotation, and say so (a dead player's whole
   meter line is contaminated).
2. **Cooldown counts.** Expected casts ≈ floor(combat_time / cooldown) + 1.
   Count a major cooldown's damage-source hits or curve peaks; 30%+ under
   expectation = held cooldowns. First use should land within ~10 s of the
   pull (skip packs that die in <20 s — holding there is correct).
3. **Burst alignment.** Major-cooldown peaks should sit within ±10 s of
   Bloodlust/Power Infusion/on-use-trinket/potion marks. A lust mark with no
   burst peak near it, while the cooldown was available, is a finding.
4. **Target priority.** Player's damage share *on the priority target* vs
   their overall share; more than ~10 points lower = padding on fodder. Only
   apply where a priority target exists; on uniform AoE the total is the fair
   metric, and a funnel spec "losing" the trash meter is doing its job.
5. **Deaths.** Count **every** death, trash included — in a keystone, trash
   deaths are where runs bleed, and skipping them under the "don't report
   trash" policy understates the count the player is judged on. That policy
   governs what you *narrate*, never what you *count*.

   **Price each death as downtime, not as an event.** A death's cost is the
   time the player was not contributing, which varies enormously with
   graveyard placement (dungeons advance the graveyard after each boss, so
   the same death costs far less late in a run than early). Measure it from
   the raw log, not the 10 s buckets:

   - Find `UNIT_DIED` for the player: `grep -a 'UNIT_DIED' "$log" | grep -i '<name>'`
   - Find the first following `SPELL_CAST_SUCCESS` by them at a target that
     is **not themselves**, **excluding pet summons** (Call Dreadstalkers,
     Summon Demonic Tyrant, Summon Felhunter, Grimoire: *, Fel Domination …).
     A pet summon is not being back in the fight; the first real cast is.
     Excluding them moved the mark 2.5–2.9 s per death in the 2026-09-06 key.
   - **Downtime = death → first real cast.** Split it into *dead* vs
     *running* using the resurrection point (a battle rez shows as the rez
     spell cast **on** them — Intercession, Rebirth, Raise Ally, Soulstone;
     a graveyard run shows as them casting movement/self spells while no rez
     landed). The run-back half is usually the bigger number and is the part
     graveyard progression changes.
   - Buckets are a fallback only, at ±10 s: a run of near-zero 10 s buckets
     against the player's median bucket in the same segment.

   **Then add the costs the meter never shows:**
   - **15 s off the key timer per death**, charged directly by the game.
     Always state this next to the run's margin — a key timed by 47 s with
     2 deaths paid 30 s of timer plus ~105 s of missing damage, i.e. the
     deaths cost more than the whole margin, twice over.
   - **A battle rez consumed** is a group-wide resource spent on the player
     and appears on no meter. Name it.

   Grade each against the recap (newest-first; first row = killing
   blow):
   - *defensible* — low-HP dwell (≤40% for 3-5 s) or a survivable big hit,
     with a defensive/healthstone available and unused;
   - *mitigable* — main defensive on CD but healthstone/secondary was up;
   - *unavoidable* — a hit ≥ ~150% max HP (movement/mechanic failure — no
     button saves it) or death inside a full-raid wipe collapse.
   Zero defensive-consumable events across a run **with** deaths is an
   automatic finding.
6. **Consumables.** Combat potion: 5-min shared CD → expect a use on the
   opener of every serious pull and a re-use when it returns; count the
   `consumable` marks. Weapon oil/flask presence comes from the SimC paste.

## Benchmarks — in order of trust

1. **The player's own prior pulls** (trend). Always available, immune to
   gear/comp noise. The DPS line comes from the history store's `trend`
   tool scoped to the same encounter AND difficulty (Normal 14 / Heroic 15
   / Mythic 16 / keystone 8 — never mix them); pulls-to-kill and median
   kill time from `progression`; the best kill from `history`
   `sort:"fastest"`. Track per-fight on top of that: key-ability shares,
   death grade, potion count. Improvement claims cite this, with dates.
2. **Same-spec player in the same run.** The gold standard when present —
   same fight, same buffs. Use `compare`; diff ability tables and curves and
   name the gap's components (a missing damage source = talent/gear; equal
   avg-hit but half the casts = resource flow; fewer peaks = cooldown usage).
   When the gap smells like build, pull `loadout` for both players on that
   segment — ilvl, tier count, trinkets, and hero tree name the gear/talent
   share of the gap in hard numbers before any rotation lecture.
3. **Other DPS in the same run.** In a 5-man, flag <80% of the other DPS's
   mean on boss segments. In a raid, compare against the DPS median, and
   normalize for time-alive before judging.
4. **External numbers** (archon.gg / mythicstats / wow.gg via research agent).
   Sanity bands only — whole-dungeon averages run lower than in-fight meters.

## Live-session reporting policy

- **Batch mode during progression**: on a boss the group is learning, skip
  per-wipe reports. Speak only for: kills, pulls ≥3 minutes, a NEW death
  mechanic, or a change in a previously-flagged behavior. Deliver a boss
  summary when it dies. The user is mid-raid — every message competes with
  the game.
- Trash/run-back segments: skip **narrating** them unless they show real
  group-wide combat — but always probe them for deaths (check #5), and fold
  those into the run's death count. Silence about a trash pull must never
  become a missing death.
- **Never name the dungeon or raid from a mob name.** Mob names invite
  false matches ("Row Rat" is not Murder Row) and a wrong dungeon call
  sends the player a loot brief for a zone they are not in. Read the zone
  from the log before naming it:
  `grep -aE 'ZONE_CHANGE|MAP_CHANGE|CHALLENGE_MODE_START|CHALLENGE_MODE_END' "$log" | tail`
  A key is live only after a `CHALLENGE_MODE_START` with no matching `_END`.
  `CHALLENGE_MODE_END,<id>,<completed>,<level>,<ms>` is also the game's own
  authoritative timing for the run — prefer it over any derived duration.
  Long "trash" segments in an open-world zone are the daemon spanning world
  activity between keys; they are not pulls.
- Deliver kill reviews promptly (between-pulls is when they're read), lead
  with the verdict, keep to ≤3 findings, and always name what *improved* —
  reinforcement is how fixes stick. A terminal notification on kills and
  major findings only.
- Track and *close the loop* on prior findings: "Demonbolt 4.2 → 6.2 across
  the night" lands harder than any single-pull number.

## The evidence hierarchy (learned the hard way)

A coaching claim is only as good as its evidence class:

1. **The player's own logs** — measured. Findings here are solid. This
   level includes the `loadout` MCP tool's per-encounter gear and talents
   (COMBATANT_INFO): what was actually worn and talented in the graded
   fight, outranking any SimC paste or player recollection of it.
2. **Node-level meta data** — murlok.io top-50 talent pick rates, archon.gg
   parse aggregation, MythicSim rankings. Trustworthy for "what the meta
   actually does".
3. **Guide prose** — rotation text, "cast X on cooldown", ability-share
   percentages quoted in guides. **Unreliable as evidence of talent selection
   or magnitudes.** Real failure: guides said "cast Summon Doomguard on
   cooldown" while node data showed 0% of top players talented it — the
   player lost a raid night's worth of confidence to that claim before it was
   retracted. Never tell the player to change talents/gear on guide prose
   alone; verify at level 1 or 2 first, and label unverified bands as soft.

When a research-derived claim is contradicted by the player's own tree, bags,
or logs, the player's data wins — retract explicitly, in plain words, and
record the correction so it isn't re-made.
