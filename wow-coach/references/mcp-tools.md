# wowdps MCP tools — cheat sheet

All calls go through `scripts/mcp-call.sh <tool> '<json-args>'`, which prints the
tool's JSON document on stdout. The daemon is spawned on demand. Two ids name
a fight: the integer `segment_id` from `list_fights` is **per daemon run**
(never cache it), and the string `history_id` on every closed row is the
history store's **stable id** (`<log>-<start_ms>`) — cache and cite that
one. `fight`, `breakdown`, `compare` and `loadout` accept either
`segment_id` or `fight_id` (the stable id) for anything in the tailed log;
an older night's id is a tool error that says to use `stored_fight`.

| Tool | Args | Gives you |
|---|---|---|
| `status` | `{}` | daemon source, `game_running`, `fight_active`, overlay state |
| `list_fights` | `{}` | every segment: `id`, `history_id` (stable; null while live), `kind` (encounter/trash/overall/key), `name`, `encounter{id,difficulty,difficulty_name,group_size}`, `duration_ms`, `result` (kill/wipe/win/loss/null), `live`, `visit`, keystone pars |
| `fight` | `{"segment_id":N, "view":"damage", "top":N}` | per-player meter rows: `player`, `class`, `spec`, `role`, `amount`, `per_sec`, `share_pct`, `crit_pct`, `events`, overkill/overheal; header `fight.encounter{id,difficulty,difficulty_name,group_size}`. Views: damage, healing, interrupts, crowd_control, dispels, deaths. Omit segment_id for the live fight |
| `breakdown` | `{"segment_id":N, "player":"name"}` | one player's per-ability rows (`amount`, `share_pct`, `hits`, `crit_pct`, `avg_hit`), per-target rows, and `timeline` (per-10s `dps` array + `marks`: trinket_use/trinket_proc/consumable/external_buff and, from PROTO_VERSION 24 (role-pivots-7, R18), active_mitigation/defensive/support_buff/cooldown — role spans carry `caster` (a guid; resolve it against a `history {"players":"all"}` card's `players[].key` or a drill's own `player.key` — meter rows carry no key) and `active_secs`; `"view":"taken"` + `player` makes `timeline` the damage TAKEN series — live at 1 s; a stored fight (PROTO_VERSION 25, `role-pivots-8`, step 4b) answers the same drill from its rows tier on a 10 s grid, `bucket_secs: 10`, marks included — with `at_secs`). `"view":"deaths"` swaps in the death recap (`death_recap` rows with `health_after`) |
| `compare` | `{"segment_id":N, "a":"name", "b":"name"}` | two players side by side: totals, per-ability tables, both timelines on one clock |
| `loadout` | `{"segment_id":N, "player":"name"}` or `{"fight_id":"<stable id>", "player":"name"}` (a stored fight from any night answers from the store's loadouts tier; header `fight{id,history_id,name}`) | the player's ACTUAL build from the log's COMBATANT_INFO: `spec_id`, `talents` (named selections + `import_string` + `hero_tree` when the dataset knows the spec; raw `picks` with a `note` otherwise — rank 0 = granted node), and `gear.items` (slot, item_id, ilvl, enchants, gems, bonus_ids) with `gear.avg_ilvl`. Scoped to that fight — builds change between encounters, so query the segment you're grading. Omit segment_id for the live/most recent fight. `logged: false` when no COMBATANT_INFO fired (only logged inside instances) — not an error |
| `talent_tree` | `{"spec_id":266}` | one spec's talent tree from local game data: nodes (position, type, ranks, gates, costs), choice entries with spell id/name/icon, hero subtrees, and `node_order` (large output — prefer decode/diff over dumping it) |
| `decode_talents` | `{"string":"C…"}` | an import string decoded: spec, class, hero tree, every selected node with ranks/choice picks and spell names, plus `warnings` on build drift |
| `encode_talents` | `{"spec_id":N, "selections":[{"node_id":N, "ranks":N, "choice_index":N, "granted":true}]}` | a fresh import string (zero tree hash; the game validates on import). Feed it a decode's selections to round-trip |

The talent tools read `~/.local/share/wowdps/talents.json` (regenerate once
per patch with wowdps' `tools/gen-talent-trees.sh`), never the daemon; a
missing-dataset error names the fix. See `references/talents.md` for the
coaching workflow around them.

Player args accept a display name, case-insensitive prefix ("Tranq" matches
"Tranqlock-Realm-US"), or GUID; a miss lists who was actually in the fight.

`loadout` is ground truth for what was actually equipped/talented IN that
fight — when it disagrees with a SimC paste, the paste is stale; grade
against the loadout and flag the drift. An "unknown tool: loadout" error
means `mcp-call.sh` found a pre-loadout wowdps-mcp binary — rebuild it
(`cargo build --release -p wowdps-mcp` in the wowdps repo) or point
`$WOWDPS_MCP` at a build that lists it.

## Response-shape traps (each one has produced a wrong answer)

- **`history` returns its rows under `.fights`, not `.cards`.** A `.cards[]`
  jq filter yields empty output, which reads exactly like "this player has
  no history" — on 2026-09-06 that briefly looked like the player's 158
  stored fights did not exist. When a history query comes back empty,
  dump the raw envelope (`| head -c 400`) before concluding anything;
  `count` / `total` in the header tell you immediately whether the store
  actually matched.
- **A player-name miss is a tool error, not an empty result.** `history`
  answers `no stored fight has a player named "X"` — that means the NAME is
  wrong (an alt, a different character), not that the store is empty. Get
  the exact name from a `fight` roster.
- **Bosses inside keystones have no trend line.** They are never stored as
  pulls of their own — the key's Σ is the stored unit — so `trend` with
  `encounter: <boss>, difficulty: 8` returns a measure and zero points.
  That is expected, not a bug. Critically: **never compare a boss's in-fight
  DPS against a key-overall DPS number.** They are different measures (one
  fight vs the whole run including trash), and doing so manufactures a
  collapse that is not there. Benchmark a boss-in-key against the fight's
  own DPS-role median instead, and say benchmark #1 is unavailable.

## Recipes proven in practice

What did they actually wear? (ilvl, hero tree, trinkets in one line):
```sh
mcp-call.sh loadout '{"segment_id":N,"player":"X"}' | jq -r \
  '"ilvl=\(.gear.avg_ilvl // "?") hero=\(.talents.hero_tree.name // "?") trinkets=\([.gear.items[]|select(.slot//""|test("trinket"))|.item_id]|join("/"))"'
```

Fight roster with ranks, and the DPS-role median for the "vs the fight" read:
```sh
mcp-call.sh fight '{"segment_id":44}' | jq -r '.rows[] | "\(.rank) \(.player) \(.spec)/\(.role) \(.per_sec) \(.share_pct)%"'
mcp-call.sh fight '{"segment_id":44}' | jq -r '[.rows[]|select(.role=="dps")|.per_sec]|sort| if length%2==0 then (.[length/2-1]+.[length/2])/2 else .[length/2|floor] end'
```

Did the player survive? (empty recap = survived):
```sh
mcp-call.sh breakdown '{"segment_id":44,"player":"Tranq","view":"deaths"}' \
  | jq -r 'if (.death_recap|length)==0 then "SURVIVED" else (.death_recap[:5][] | "\(.name) \(.amount) hp=\(.health_after.current // "?")") end'
```
Death recaps read newest-first: the first row is the killing blow.

Cheap "anything changed?" probe (one line):
```sh
mcp-call.sh breakdown '{"segment_id":N,"player":"X"}' | jq -r \
  '"alive_buckets=\(.timeline.dps|length) potions=\([.timeline.marks[]|select(.label|test("Potion|Potential"))]|length)"'
```

Ability-presence check (e.g. is a cooldown being pressed at all?):
```sh
mcp-call.sh breakdown '{"segment_id":N,"player":"X"}' \
  | jq -r '[.by_ability[].name | select(test("Doomguard|Infernal"))] | length'
```

## Reading the timeline

- `dps` is bucketed per 10 s; `length × 10s` ≈ how long the player was alive
  and contributing — an array much shorter than the fight means an early death.
- Burst cadence: count pronounced peaks; for a 1-minute-cooldown spec they
  should land ~every 60 s. Compare the same fight's curves between players
  before blaming an individual — shared valleys are fight mechanics.
- `marks` timestamps let you check opener alignment (lust/PI/potion inside the
  first ~10 s) and potion cadence (5-min CD → expect a re-use).

## The history store (fights that persist across logins)

Since wowdps `feat!: the history store` (2026-09-02) every closed raid boss,
arena match and keystone run's overall is written to
`~/.local/share/wowdps/history/v1/` and survives daemon restarts and new
log files. Eight tools read it (seven fixed ones plus `history_sql`). **Ids here are stable strings**
(`<fnv64>-<start_ms>`), not `list_fights`' per-run integers — cache them
freely, cite them in reports, and prefer them for anything that must
outlive a daemon restart.

| Tool | Args | Gives you |
|---|---|---|
| `history` | `{"player":"X","kind":"encounter"\|"key"\|"arena"\|"overall","encounter":3455,"difficulty":14\|"Heroic","since_utc_ms":N,"sort":"newest"\|"fastest"\|"owner_dps","limit":N,"after_id":"…","players":"me"\|"none"\|"all"}` (all optional) | cards: `id`, `kind`, `name`, `encounter{id,difficulty,difficulty_name,group_size}` (keys: `instance{…,key_level,completed}` + `keystone_pars_ms[par,+2,+3]`), `date`, `start_utc_ms`, `duration`/`duration_ms`, `result`, `official_ms`, `build`, `owner`, `pinned`, `best_pct`, `roster_size`, and — default `players:"me"` — a **`me` block**: `{name, spec, role, dps, hps, deaths, overheal, absorbed, support_given, support_received, effective_dps, healed_received, self_healed, support, rank_dps, dps_count, dps_median, dps_share, rank, rank_measure, rank_count, rank_median, rank_share}` — two grades side by side. The **legacy block** (`rank_dps` / `dps_count` / `dps_median` / `dps_excluded` / `dps_share`) ranks RAW `dps` among DPS-role players: it is the block an Augmentation Evoker's buffs inflate — the players it buffs read high, the Evoker itself reads low. The **generic block** (`rank` / `rank_measure` / `rank_count` / `rank_median` / `rank_excluded` / `rank_share`) ranks the subject by its role's measure: `effective_dps` for a DPS player (R19: `damage − support_received + support_given` per second, the Evoker's contribution credited back to it; equal to `dps` on any fight without an Augmentation), `hps` for a healer, `null` for a tank. `support: true` marks a support spec (Augmentation). `overheal` / `absorbed` are the healer's efficiency pair; `self_healed` / `healed_received` the tank's own vs external healing (a tank subject also gets `tank_pair[]` carrying both). **PROTO_VERSION 25** (`role-pivots-8`, R18 step 4b) adds to every `me` / `peer` / roster row: `am_uptime_pct` (active-mitigation uptime as a % of the fight — a card written before 4b reads 0 until `regrade_fights`, like `mitigated_pct`), `externals_given: {count, secs}` and `externals_received: {count, secs}` (spans cast by someone else on the player, or by the player on others); `tank_pair[].am_uptime_pct` (the co-tank AM comparison in one line); and a **`healers[]`** block on a HEALER subject — the fight's friendly healers by `hps` desc, the subject included, each `{name, key, spec, hps, overheal_pct, externals_given{count, secs}}` with `overheal_pct = overheal × 100 / (healing + overheal)`. Prefer the generic block for every grade line; quote `rank_dps` only to show how far an Aug moved the raw meter. `players:"all"` restores the roster (each row with `role`, the same scalars, and one `me:true`); `"none"` drops both (cheapest poll). Header: `count`, `total` (matches before limit), `next_after_id` (pass back as `after_id` to page; a bogus cursor restarts). `sort:"fastest"` is kills only; with `limit:1` it is the best kill. **PROTO_VERSION 26** (`role-pivots-9`, R20 step 5) adds to every `me` / `peer` / roster row: `absorb_wasted` (what came off the player's shields unused — `null` when no closed shield had an observable waste, and on a pre-5 card until `regrade_fights`), `shields_unknown` (the caveat: shields whose applied amount the log never gave — pre-pull ones and those still up at the end) and `absorb_efficiency_pct` (`absorbed × 100 / (absorbed + absorb_wasted)`, `null` exactly when `absorb_wasted` is — NEVER read a null as 0 %); `healers[]` entries gain `absorb_efficiency_pct` and `shields_unknown` (quote the efficiency only when `shields_unknown` is small next to the shield count in `stored_fight.shields[]`) |
| `progression` | `{"encounter":3455,"difficulty":14\|"Heroic"}` | `pulls`, `kills`, `first_kill` and `best_kill` as references `{id, date, start_utc_ms, duration, duration_ms, best_pct}`, `nights[]` (default `bucket:"utc"` = UTC days, so a US evening raid lands on the NEXT date and can straddle two rows — **always pass `"bucket":"local"`** (optional `cutover_hour`, default 6) so an evening is one night; rows carry `night_local` = the evening's date, `date` (UTC) and `day_utc_ms`; `pulls`, `kill` bool, `kills` count, `best_pct` = the night's LOWEST remaining boss health, 0 on a kill night), `median_kill` / `median_kill_ms` |
| `role_night` (**PROTO_VERSION 26**, `role-pivots-9`) | `{"encounter":3455,"difficulty":14\|"Heroic","night":<day_utc_ms>` OR `"date":"YYYY-MM-DD"` (one required; `night` is exactly what `progression`'s `nights[].day_utc_ms` printed, `date` matches that night's `date` or `night_local` — same `bucket`\|`local`\|`cutover_hour` as the `progression` call, or the night will not match)`}` | ONE NIGHT of ONE BOSS as a role roster — every player's non-aborted pulls that night folded into one row: `night` (progression's row: `date`, `night_local`, `day_utc_ms`, `pulls`, `kill`, `kills`, `best_pct`), `owner` (guid or null), `tanks[]` (side by side, the daemon's order), `healers[]` (ranked by hps), `dps[]` (ranked by effective_dps), each `{name, key, spec, role, me, pulls, measure, rank_measure, best, taken, dtps, am_uptime_pct, overheal_pct, absorb_efficiency_pct, externals_given}` — `measure` is the MEAN of the per-pull role measure named by `rank_measure` (`mitigated_pct` tank \/ `hps` healer \/ `effective_dps` dps), `best` the best single pull, `absorb_efficiency_pct` a RATIO OF SUMS over the pulls with a known waste (`null` when none had one), `externals_given` a span count; `me: true` on the owner's row; a specless player lands in `unknown_role[]` (present only then). A fixed daemon question over the card index; `wowdps history role-night` answers it from SQL. Use it for "how did the healers do tonight" instead of paging `history` per player
| `regrade_fights` | `{"fight_id":"…"}`, `{"encounter":N,"difficulty":D}` or `{"kind":"key"}` | re-parses stored cards from their logs after a ruling change (R16 boss health), same id, pins and annotations kept; answers `{queued}` — poll `status.history.importing` to 0, then re-read. An ABORTED key (no END) is re-clocked as combat time to its last hit, so its `duration_ms` and `me.dps` can change; completed keys and boss pulls never move |
| `trend` (**versioned**: `measure` dps\|hps\|dtps\|mitigated_pct needs PROTO_VERSION 22 (PR #17, `role-pivots-3`); `effective_dps`, the `me` scalars, `support`, `tank_pair.self_healed/healed_received` and `stored_fight.support` need PROTO_VERSION 23 (`role-pivots-5`); `measure: am_uptime` (value filed as `am_uptime_pct`; never a default — a tank still defaults to `mitigated_pct`; pre-4b cards read 0 until `regrade_fights`), the row's `am_uptime_pct` / `externals_given` / `externals_received`, `tank_pair.am_uptime_pct`, `healers[]` and `stored_fight.uptime[]` need PROTO_VERSION 25 (`role-pivots-8`); `measure: absorb_efficiency` (value filed as `absorb_efficiency_pct`; never a default — a healer still defaults to `hps`; a fight whose waste was unknown contributes NO point and a pre-5 card is unknown until `regrade_fights`, so the line can be shorter than the fight list), the row's `absorb_wasted` / `shields_unknown` / `absorb_efficiency_pct`, `healers[].absorb_efficiency_pct`, `stored_fight.shields[]` and the `role_night` tool need PROTO_VERSION 26 (`role-pivots-9`); on `main` (v20) `measure` is ignored, echoes `null`, and points carry `per_sec` only under `"view":"damage"\|"healing"` — check `status` before relying on either) | `{"player":"X","measure":"dps"\|"effective_dps"\|"hps"\|"dtps"\|"mitigated_pct"\|"am_uptime"\|"absorb_efficiency" (omit = by the player's role: tank → mitigated_pct, healer → hps, else **`effective_dps`** — `dps` is the raw line, still reachable by name; the two are equal on fights without an Augmentation, so a plain DPS player's trend no longer jumps with whether an Evoker was in the raid; `"view":"damage"\|"healing"` still accepted as an alias for dps\|hps),"bucket":"day"\|"week" (omit = per fight),"local":true (day/week buckets by the log's local day from `cutover_hour`, points carry `date_local` — use it for raid nights),"spec":"Demonology","encounter":N,"difficulty":N,"since_utc_ms":N,"limit":N}` | `measure` echoed; `points[]`: `date`, `fight_id`, `per_sec` (alias) and the same value under the measure's own name (`dps` / `effective_dps` / `hps` / `dtps` / `mitigated_pct`, and `am_uptime_pct` for `am_uptime`, `absorb_efficiency_pct` for `absorb_efficiency`), `amount` (effective damage under effective_dps; taken or mitigated for the tank measures, absorbed for absorb_efficiency), `duration_ms`, `fights` (a day/week bucket is a MEAN of per-fight values, pcts included) — the player's own trend line, the rubric's benchmark #1 as numbers |
| `stored_fight` | `{"fight_id":"…"}` / `+ "player":"X"` / `+ "view":"deaths"` / on a KEY `+ "boss":"The Hoardmonger"\|0` (a member boss parsed from the log on demand, same shapes, nothing stored; key cards list `bosses[]` — regrade a pre-2026-09-03 key by id once to fill it) | exactly `fight`'s rows, `breakdown`'s by_ability/by_target/timeline, or the death recap — every live recipe below works on it unchanged. With `player`, a **`support`** block (rows tier, so every stored fight has it) when that player gave or received Augmentation support: `given{damage,healing}` (shares credited to them as the supporter), `received{damage,healing}` (shares of their own hits/heals credited to a supporter), `targets[]` (`name`, `key`, `spec`, `damage`, `healing`, `lines` — whom an Evoker's shares landed on; empty for a buffed player); the key is absent when there was no support. With `player`, from PROTO_VERSION 25, an **`uptime[]`** block (rows tier — every stored fight, kill or wipe; absent when empty, and empty on a pre-4b record until `regrade_fights`): one entry per (target, spell, caster) — `{target, spell, name, kind, caster, count, secs}`, `kind` one of `active_mitigation` / `defensive` / `external` / `support_buff` / `cooldown` / `trinket_use` / `trinket_proc` / `consumable`, `target` and `caster` guids (resolve against `.fight.players[].key`) — BOTH halves: auras on the drilled player (`target` = them) and the ones they cast on others (`caster` = them); a self-cast appears once. `view:"taken"` + `player` also carries `timeline` on a 10 s grid with marks (see `breakdown`). With `player`, from PROTO_VERSION 26, a **`shields[]`** block (rows tier; absent when the player cast no shield, and on a pre-5 record until `regrade_fights`): one row per absorb spell they cast — `{spell, name, applied, consumed, wasted, count, unknown}`, consumed desc; `applied = consumed + wasted` on a row whose shields were all known, `unknown` counts the shields whose applied size the log never gave (pre-pull ones, and those still up at the end fold in with `consumed` and `count` only), Σ `consumed` = the player's `absorbed` exactly. Every answer says `tier: "card"\|"rows"\|"details"` and `available_views[]`. Breakdowns/timelines exist only in the **details tier**: kills, the fastest kill, the owner's best per (encounter, difficulty, spec), and pinned fights — 10 per (encounter, difficulty) by default, older ones are demoted to card+rows. Asking past the tier is a tool error, never a partial document: `no stored fight <id>` (evicted / never closed / a keystone's member boss — the key's Σ is the record), `details demoted by retention (tier rows) — pin kills you want to keep drillable`, `no death recap for <guid> — they did not die in it`, `only the card survives` |
| `pin_fight` | `{"fight_id":"…","pinned":true}` | protects a fight's details from retention (release with `false`) |
| `history_sql` | `{"query":"select … where x = ?","params":[…]}` | DuckDB over views `fights`, `players` (+ `role`, `support`, the tank/healer/support scalars and `effective_dps_sql`, which always exists and equals `dps` on older cards), `role_ranks` (the `me` grader in SQL), `rows`, `details`, `loadouts`, `annotations`, and the probed views `taken`, `mitigation`, `taken_spells`, `taken_sources`, `support`, `support_targets`, from PROTO_VERSION 26 `shields` (fight × `guid` × `spell_id`, `label`, `applied`, `consumed`, `wasted`, `count`, `unknown`) with `players.absorb_wasted` / `shields_unknown` / `absorb_efficiency_sql` (recomputed 0..1 ratio, NULL when the waste is unknown or the card is pre-5 — never 0), and, from PROTO_VERSION 25, `uptime` (fight × target `guid` × `spell_id`, `label`, `kind` by name, `src` = the caster, `count`, `total_ms`) and `coarse` (fight × `guid` × `taken10` / `heal10` 10 s bucket lists + `marks`) with `players.am_uptime_ms` / `externals_*` / `am_uptime_pct_sql` (always present, 0 on older cards) — present only when the files carry them (`views` lists them; a store written before the role-pivots PRs needs `regrade_fights` to gain them) → `{columns, rows}`. Read-only. For anything the fixed tools don't shape; recipes in the repo's `docs/history-queries.md` (absorb efficiency by boss, the per-spell shield drill); `wowdps history role-night` is the `role_night` question from SQL |

**Difficulty** — since wowdps `1e3c0a5` (2026-09-03) every encounter row
(`list_fights`, the `fight` header of `fight`/`breakdown`/`compare`/
`loadout`, and history cards) carries
`encounter: {id, difficulty, difficulty_name, group_size}`:
`14` Normal · `15` Heroic · `16` Mythic · `17` LFR · `8` Mythic Keystone
(boss inside a key) · `23` Mythic dungeon · `208` Delve. **`best_pct`** on a
wipe is the lowest remaining health among bosses still standing (R16: a
boss parked at 1 HP is down, add packs never count, a kill is 0) — lower is
closer; quote it as "got the last altar to 37 %". The `difficulty`
argument of `history`/`progression`/`trend` accepts the id or the name
(case-insensitive; `"M+"` works). Key cards carry `instance: {map_id,
difficulty, difficulty_name, key_level, completed}` instead, and bosses
inside keys are never pulls of their own — the key's Σ is the stored unit.
A Normal-vs-Heroic mix-up produced a wrong "same boss, same raid" trend
read on 2026-09-02 — read `difficulty_name` before comparing pulls. On a
pre-fix daemon the field is `null` on live rows: fall back to the newest
history card. **Pins**: `pin_fight` flags live on the card and were wiped
by a store re-import on 2026-09-03 (reported) — re-check `pinned` on the
receipts at the start of a session and re-pin if needed.

### Recipes

The just-closed fight's stable id + difficulty (run right after a
`FIGHT COMPLETE` line; the watcher already prints the stable id, encounter
and difficulty on that line — this is the fallback):
```sh
mcp-call.sh history '{"kind":"encounter","limit":1}' | jq -r \
  '.fights[0] | "\(.id) \(.name) enc=\(.encounter.id) diff=\(.encounter.difficulty) \(.duration) \(.result)"'
```

The player's own prior pulls on this boss at this difficulty (benchmark #1):
```sh
mcp-call.sh trend '{"player":"Tranq","encounter":3455,"difficulty":14,"limit":8}' | jq -r \
  '.points[] | "\(.date) \(.per_sec|floor) \(.duration_ms/1000|floor)s \(.fight_id)"'
```

Session intake in two calls — last session's bosses and the per-day line
(the `me` block carries rank, same-role median and share, so no roster and
no jq role list is needed; the generic `rank` block is graded by
`effective_dps` — read that, and keep `dps` / `rank_dps` for "what the raw
meter showed": the raw block is the one an Augmentation's buffs inflate):
```sh
mcp-call.sh history '{"player":"Tranq","kind":"encounter","limit":15}' | jq -r \
  '.fights[] | "\(.date) \(.name) \(.encounter.difficulty_name) \(.duration) \(.result) me=\(.me.effective_dps|floor) (raw \(.me.dps|floor)) r\(.me.rank)/\(.me.rank_count) med=\(.me.rank_median|floor) \(.me.rank_share)%"'
mcp-call.sh trend '{"player":"Tranq","bucket":"day","local":true,"limit":10}' | jq -r '.points[] | "\(.date_local) fights=\(.fights) \(.per_sec|floor)"'
```
(The trend's `per_sec` is `effective_dps` for a DPS player by default —
pass `"measure":"dps"` for the raw line.)

Boss summary numbers (pulls-to-kill, first and best kill, median kill):
```sh
mcp-call.sh progression '{"encounter":3455,"difficulty":"Heroic","bucket":"local"}' | jq -c '{pulls,kills,first:.first_kill.date,best:(.best_kill|"\(.date) \(.duration) \(.id)"),median_kill,nights:(.nights|map("\(.night_local) \(.pulls)p \(.kills)k best=\(.best_pct)"))}'
```

The grade line for a just-closed kill straight off its card (rank among
the same role by its measure — `effective_dps` for DPS, `hps` for a healer
— true median, share) — the rubric's "vs the fight" read:
```sh
mcp-call.sh history '{"kind":"encounter","limit":1}' | jq -r \
  '.fights[0] | "\(.name) \(.encounter.difficulty_name) \(.duration) \(.result): \(.me[.me.rank_measure]|floor) \(.me.rank_measure) r\(.me.rank)/\(.me.rank_count) = \((.me[.me.rank_measure]/.me.rank_median*100)|floor)% of median, \(.me.rank_share)% share (raw dps \(.me.dps|floor) r\(.me.rank_dps)/\(.me.dps_count))"'
```
When `me.support` is true (an Augmentation) the raw `dps` / `rank_dps` pair
understates the player and the buffed peers' raw pair overstates them —
grade on the generic block only, and use `stored_fight {player}`'s
`support.targets[]` to say whose damage the Evoker's shares became.
Live `fight` / `compare` rows carry `role` (`dps`/`healer`/`tank`) since
2026-09-03, so a DPS-only ranking on a live segment is
`[.rows[]|select(.role=="dps")]` — never a hand-kept healer/tank spec
list. `players:"<name>"` on `history` returns that player's row as `peer`
in the `me` shape (rank, count, median) — the cheap way to follow a
same-spec peer across nights.

An M+ run from the store: the key's Σ, then each boss by name (the coach's
per-boss grade — rank among the four others, share, deaths, potion marks):
```sh
K=<key id>   # from `history kind:"key"`; `regrade_fights {fight_id}` once if `bosses` is null
mcp-call.sh stored_fight "{\"fight_id\":\"$K\"}" | jq -r '.fight.bosses[] | "\(.name) \(.duration) \(.result)"'
mcp-call.sh stored_fight "{\"fight_id\":\"$K\",\"boss\":\"The Hoardmonger\",\"player\":\"Tranq\"}" | jq -r '"rank=\([.rows[]|select(.player|test("^Tranq"))][0].rank) potions=\([.timeline.marks[]|select(.label|test("Potion|Potential"))]|length) buckets=\(.timeline.dps|length)"'
```

Yesterday's breakdown, same shape as live (details tier only):
```sh
mcp-call.sh stored_fight '{"fight_id":"<id>","player":"Tranq"}' | jq -r '"buckets=\(.timeline.dps|length) potions=\([.timeline.marks[]|select(.label|test("Potion|Potential"))]|length)"'
```

Who did I give externals to, and for how long (PROTO_VERSION 25; `uptime[]`
carries both halves, so keep the `caster == me` side and resolve the
target guid against the rows; the `me` row's `externals_given.count` is
the same list's length, `externals_given.secs` its `secs` sum):
```sh
mcp-call.sh stored_fight '{"fight_id":"<id>","player":"Tranq"}' | jq -r \
  '. as $d | ($d.fight.players | map({key: .key, value: .name}) | from_entries) as $who
   | $d.player.key as $me
   | [$d.uptime[]? | select(.kind=="external" and .caster==$me)]
   | sort_by(-.secs)[] | "\($who[.target] // .target) \(.name) x\(.count) \(.secs)s"'
```
The mirror question — what a tank received and from whom — is the same
filter with `.target==$me`, resolving `.caster` instead; and a tank's AM
uptime is `.uptime[] | select(.kind=="active_mitigation")` (per spell) or,
in one number, the `me` row's `am_uptime_pct` / `tank_pair[].am_uptime_pct`.

Healers tonight (PROTO_VERSION 26): one boss, one night, every healer's
mean HPS over their pulls, overheal, externals and shield efficiency —
take `night` from `progression`'s `nights[].day_utc_ms` (same `bucket`)
or pass the `date` it printed; `date` also matches `night_local`:
```sh
mcp-call.sh role_night '{"encounter":3455,"difficulty":"Heroic","bucket":"local","date":"2026-09-02"}' | jq -r '
  "\(.night.night_local) \(.night.pulls)p \(.night.kills)k best=\(.night.best_pct)",
  (.healers[] | "\(if .me then "*" else " " end)\(.name) \(.spec) \(.pulls)p hps=\(.measure|floor) best=\(.best|floor) oh=\(.overheal_pct)% abs=\(.absorb_efficiency_pct // "?")% ext=\(.externals_given)")'
```
The same document's `tanks[]` is the co-tank split for the night
(`measure` = mean `mitigated_pct`, `taken`, `dtps`, `am_uptime_pct`) and
`dps[]` the role ranking by mean `effective_dps`; `.tanks[], .healers[],
.dps[] | select(.me)` is the owner's line.

**`shields_unknown` and a null efficiency** (R20): the log gives a shield's
size on APPLIED and what remained on REMOVED, so waste is known only for a
shield seen end to end. `absorb_efficiency_pct` is `null` when NO closed
shield of the fight had an observable waste — a pre-pull shield, a Disc
whose shields were all still up at the kill, a card written before step 5
(`regrade_fights` fills it in). `shields_unknown` counts the shields whose
APPLIED size was never seen (pre-pull ones, and those still up at the
end); their consumption still counts, their waste does not, so an
efficiency next to a large `shields_unknown` is a lower bound on waste,
not a grade. Say "unknown", never "0 %", and cite `stored_fight {player}`'s
`shields[]` (`unknown` per spell, `applied = consumed + wasted` only on a
row with `unknown` 0) when the number decides a finding.

Pin the receipts at wrap-up (best kill per boss, any fight a finding cites):
```sh
mcp-call.sh pin_fight '{"fight_id":"<id>","pinned":true}'
```

Ad hoc — every kill of a boss with the owner's DPS, oldest first. Bind
values with `params` (`?` placeholders, scalars only); never splice a
literal into the query:
```sh
mcp-call.sh history_sql '{"query":"select f.start_utc_ms, f.duration_ms, f.encounter.difficulty as d, p.dps from fights f join players p on p.fight_id=f.id where f.encounter.id=? and f.success and p.name like ? order by 1","params":[3455,"Tranqster%"]}'
```
(`fights.success` is the kill flag on encounters and the TIMED verdict on
keys (null without par timers) — there is no `result` column on the view; `encounter` is a struct — `f.encounter.id` / `f.encounter.difficulty`;
`fights.owner` is as written on disk and can be null on older files while
`history` names the owner at answer time. Proven output 2026-09-02:
Vashnik kills 45.9k → 88.4k → 105.0k → 127.0k, the last one Heroic — the
encounter id is shared across difficulties, so bind the difficulty too
when the line must be one difficulty.)

Owner note: `players[].name` is the display name; `player` args accept the
usual prefix. Cards carry `owner: null` today — filter by `player`, not by
owner.
