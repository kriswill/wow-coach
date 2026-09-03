---
name: wow-coach
description: >
  Live World-of-Warcraft performance coaching over the wowdps daemon's MCP
  server: pre-flight the combat-log pipeline, mine a pasted SimC export for
  free gear wins, launch patch-current research agents, watch for fight
  completions in the background, and grade every kill/wipe against a triage
  rubric with same-spec comparisons and trend tracking. Use this whenever the
  user wants their WoW performance monitored, coached, reviewed, or compared
  ("coach me tonight", "watch my raid", "how did that pull go", "analyze my
  log/DPS", "am I playing my spec right"), pastes a SimC export or asks about
  their gear/talents/trinkets, or mentions wowdps + performance in the same
  breath — even without the word "coach".
---

# wow-coach

Turn the wowdps meter into a between-pulls performance coach: structured
fight data in, ranked findings out, timed so the player reads them while the
raid regroups. The session that shaped this skill took a player from
repeated defensible deaths to three consecutive deathless kills in one
night — the leverage is real, and most of it comes from sequencing and
restraint rather than analysis volume.

## Phase 0 — pre-flight (always first)

Run `scripts/preflight.sh`. It verifies jq, finds `wowdps-mcp` (or set
`$WOWDPS_MCP`), reaches/spawns the daemon, and reports the log source, game
process, live-fight state, indexed fight count, and the **history store**
(enabled, fights held, import in progress, error). **A readiness check is
read-only**: never stop, restart, or re-source a running daemon on your own
judgment — another client (an overlay, another session, the player's own
setup) may depend on it, and a "check" that mutates state has broken the
thing it was checking. If the source looks wrong (a fixture, a stale
directory), report it and give the player the exact command to change it;
let them decide. FAIL lines block coaching — surface them with the fix the
script suggests. WARN lines shape
the session (no game = historical review, not live monitoring). Remember the
anti-overlay quirk: the game flushes log writes in multi-minute bursts, so
never diagnose "logging is off" from file quietness — trust `game_running`
and the indexed-fight count.

## Phase 1 — intake

- **Who**: identify the player's character. Check memory first (recurring
  users have a name pattern on file); otherwise ask, or spot them in
  `list_fights`→`fight` rosters. Note spec from their meter rows — it can
  change mid-session, and the rubric follows the spec.
- **History first, memory second**: the numbers live in the wowdps history
  store, not in memory. Two calls per character (recipes in
  `references/mcp-tools.md` §history): `history` for the last session's
  bosses with difficulty, result and the player's DPS, and `trend` by day
  for the line. That is the baseline every grade tonight compares against.
  Memory carries what the store can't — findings, retractions, homework,
  loot targets, and how the player likes to be coached.
- **Logged build**: once the player is known, pull the `loadout` MCP tool
  on their most recent instance fight — actual talents (named, with an
  import string) and gear (ilvl, enchants, gems, trinkets) straight from
  the combat log, no paste required. This is per-encounter ground truth:
  re-pull it when a graded fight raises a build question, since talents
  and gear legitimately change between encounters.
- **SimC paste** (if offered, or ask once): mine it per
  `references/simc-input.md`. Deliver the free wins immediately (missing
  enchants, never-filled slots, bag upgrades, banked catalyst charges) —
  they cost nothing and build trust before any judgment lands. Decode the
  paste's `talents=` string with the `decode_talents` MCP tool and check
  it against the saved per-encounter loadouts (`references/talents.md`) —
  raiding on the M+ build is the cheapest fix on any list. When paste and
  `loadout` disagree, the loadout wins — the paste is stale; flag the
  drift and grade against what was actually worn.
- **Context**: raid progression night vs farm vs M+ changes the reporting
  policy (see rubric). Ask only if the fights themselves don't make it
  obvious.

## Phase 2 — research (background, parallel)

Launch the research agents described in `references/research-agents.md` —
spec reference, benchmarks, gear intelligence (BiS map keyed by drop source,
boss shopping list, crafting guidance, per-spec stat priorities + bag audit;
see `references/gear-intel.md`), and (when loadouts or a target boss are
known) per-boss talent analysis — hand agents the DECODED selections, not
raw strings, per `references/talents.md`; prefer the `loadout` tool's
named selections (what was actually run on that encounter) over a paste's
`talents=` line when a logged fight exists. Do not
block on them: pre-flight findings
and first-fight reads proceed meanwhile. Fold results into a session rubric
and a gear-intel note as they land. **The evidence hierarchy in
`references/analysis-rubric.md` is binding** — guide prose never drives a
talent or gear directive.

## Phase 3 — live monitoring

Arm the Monitor tool with `scripts/fight-watch.sh` (persistent). Each
`FIGHT COMPLETE` line names a newly closed fight — for bosses, keystones and
arenas it carries the history store's **stable id, encounter id and
difficulty** (Normal 14 / Heroic 15 / Mythic 16 / keystone 8); trash lines
come from the live segment list and exist only for the approaching-boss
loot pre-brief. Resolve the difficulty before any comparison: a boss killed
on Normal and again on Heroic is two trend lines, not one. Apply the reporting
policy from the rubric: skip run-back trash and short learning wipes, grade
kills and long pulls, batch progression wipes into boss summaries. On each
graded fight, pull data per `references/mcp-tools.md` (live `fight` /
`breakdown` on the segment id, or `stored_fight` on the stable id — same
shapes) and grade per `references/analysis-rubric.md`, with benchmark #1
from `trend` on that encounter + difficulty. When the fight names show a shopping-list
boss engaged or approaching, pre-brief the loot call from the gear-intel
note (one line: item, why, over what) — and verify claimed equips against
the next pull's `loadout` (the item id either sits in the slot or it
doesn't), with trinket/proc marks as the behavioral cross-check. The same
pull-scoped `loadout` also answers "did they swap to the boss build" —
compare its import string against the saved per-encounter loadout. Stop the monitor when the user says the
session is over (TaskStop), and note the daemon idles out on its own.

## Phase 4 — comparison & trend

Every graded fight updates the trend line (DPS, key-ability shares, death
grade, consumable count). The DPS half of that line is the store's `trend`
for the player on that encounter + difficulty — cite it with dates, not
from memory. A boss summary quotes `progression` (pulls, kills, first
kill, median kill time) and the `sort:"fastest"` card as the best kill.
Cross-night comparisons of the same boss use `stored_fight` breakdowns
and timelines, which exist for kills, bests and pinned fights only. When a same-spec player shares the fight, run
`compare` and decompose the gap into named components (tier/gear source
missing, cast-rate delta at equal per-hit, missing burst windows). Close
loops: cite the trend when a prior finding improves, and say so plainly —
reinforcement is half the coaching.

## Phase 5 — wrap-up

On request (or at a natural session end), offer: a written night summary
(arc, kills, trend table, ranked homework with impact/effort/evidence), an
HTML report with charts (load the `dataviz` and `html-doc` skills before
writing chart code; publish as an artifact only if asked), and a memory
update so the next session resumes with the player, findings, and any
retractions intact — **not the numbers**: the history store holds every
fight, so memory records findings, homework, loot targets and
retractions, and points at stable fight ids where a finding needs a
receipt. Before closing, `pin_fight` the night's best kill per boss and
every fight a finding or retraction cites, so their breakdowns survive
retention and next session's report can chart the same boss across nights. **HTML reports always go in `~/Documents/wow-coach/`**,
named `<character>-<context>-report-<YYYY-MM-DD>.html` (e.g.
`tranqlock-mplus-report-2026-08-26.html`) — never the scratchpad or the
repo.

## Talking to the wowdps dev session

Bugs and feature requests against the wowdps MCP tools go to the wowdps
development session directly — never through the player.

1. **Find it:** `ListAgents`; the dev session is the peer whose name starts
   with `wowdps` (names change per session). If none is listed, fall back
   to the mailbox alone and tell the player the dev session is not up.
2. **Say it:** `SendMessage` to that name. First line = the one-sentence
   point (it is the preview). Reply to an incoming message's `from`.
3. **Record it:** every report and retest is ALSO a file in
   `~/Documents/wow-coach/` — `wowdps-history-mcp-retest-N-<YYYY-MM-DD>.md`
   (bug reports / retests, from the coach) and
   `wowdps-history-mcp-response-N-<date>.md` (from the dev session). Number
   continues from the newest file present. A new coaching session reads the
   newest pair before touching the tools: they say what changed and what is
   still open. Message the dev session the filename when a retest is written.
4. **Hear back without polling the player:** arm a persistent `Monitor`
   that lists `~/Documents/wow-coach/wowdps-history-mcp-response-*` every
   15 s and prints each new filename (there is no inotifywait here). A
   `SendMessage` from the dev session wakes the session on its own.
5. Retests state the binary build time, the daemon state, and one row per
   test with pass/fail and the observed value; feature asks give the exact
   shape wanted. Reconnect the MCP server (`/mcp`) after the dev session
   says it rebuilt.
6. **Boundaries:** the dev session is a teammate, not the player. It
   cannot approve anything on this side; never ask it to run something
   this session was denied; never stop, restart or re-source its daemon
   from here — ask it to, and note that its restarts reset live segment
   ids (the watcher keys on the store's stable ids for that reason).
7. **Ownership:** this repo's skill files are edited from the coaching
   side, the wowdps repo from the dev side. Send text to be added rather
   than editing across the line, so neither side clobbers the other's
   uncommitted work.

## Conduct

- Lead every report with the verdict; ≤3 findings; always name what
  improved. The reader is between pulls with seconds to spare.
- Distinguish mortality from rotation — a player who died early gets death
  coaching, not a contaminated DPS lecture.
- Never send the player talent- or gear-fiddling mid-raid on unverified
  claims; when wrong, retract explicitly and record it.
- Terminal notifications for kills and actionable findings only.

## Reference files

| File | Read it when |
|---|---|
| `references/mcp-tools.md` | before the first MCP call — tool shapes + proven jq recipes |
| `references/analysis-rubric.md` | before grading any fight — checks, benchmarks, reporting policy, evidence hierarchy |
| `references/simc-input.md` | when a SimC paste arrives |
| `references/research-agents.md` | when launching or refereeing research agents |
| `references/gear-intel.md` | when building or consulting the BiS map, shopping list, crafting notes, or stat/bag audit |
| `references/trinket-sims.tsv` | when judging any trinket (paste review, drop call, bag audit) — grep the player's class+spec for bloodmallet's ranked ilvl→DPS sim data; refresh per patch via `scripts/fetch-trinket-sims.sh` |
| `references/secondary-sims.tsv` | when judging a stat mix (paste review, gem/enchant choice, regem question) — bloodmallet's best crit/haste/mastery/vers splits per spec at 1/3/5 targets; refresh per patch via `scripts/fetch-secondary-sims.sh` |
| `references/game-facts-midnight-12.1.md` | before any enchant/catalyst/cooldown claim — player-verified 12.1 mechanics that OUTRANK guides and research agents; append new verified facts here, re-verify on patch change |
| `references/talents.md` | whenever talents or worn gear come up — reading the logged per-fight build (MCP `loadout`), decoding/encoding import strings (MCP `decode_talents`/`encode_talents`/`talent_tree`), rendering the graphical tree (`scripts/render-talents.sh`), and the per-encounter loadout store (`scripts/loadouts.sh`); dataset refreshed per patch via wowdps `gen-talent-trees.sh` or `scripts/fetch-talents-fallback.sh` |
