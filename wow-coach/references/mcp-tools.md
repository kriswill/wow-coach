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
| `breakdown` | `{"segment_id":N, "player":"name"}` | one player's per-ability rows (`amount`, `share_pct`, `hits`, `crit_pct`, `avg_hit`), per-target rows, and `timeline` (per-10s `dps` array + `marks`: trinket_use/trinket_proc/consumable/external_buff with `at_secs`). `"view":"deaths"` swaps in the death recap (`death_recap` rows with `health_after`) |
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
log files. Six tools read it. **Ids here are stable strings**
(`<fnv64>-<start_ms>`), not `list_fights`' per-run integers — cache them
freely, cite them in reports, and prefer them for anything that must
outlive a daemon restart.

| Tool | Args | Gives you |
|---|---|---|
| `history` | `{"player":"X","kind":"encounter"\|"key"\|"arena"\|"overall","encounter":3455,"difficulty":14\|"Heroic","since_utc_ms":N,"sort":"newest"\|"fastest"\|"owner_dps","limit":N,"after_id":"…","players":"me"\|"none"\|"all"}` (all optional) | cards: `id`, `kind`, `name`, `encounter{id,difficulty,difficulty_name,group_size}` (keys: `instance{…,key_level,completed}` + `keystone_pars_ms[par,+2,+3]`), `date`, `start_utc_ms`, `duration`/`duration_ms`, `result`, `official_ms`, `build`, `owner`, `pinned`, `best_pct`, `roster_size`, and — default `players:"me"` — a **`me` block**: `{name, spec, role, dps, hps, deaths, rank_dps, dps_count, dps_median, dps_share}` = the owner's rank among DPS-role players, how many there were, their true median, and share of all friendly damage. `players:"all"` restores the roster (each row with `role` and one `me:true`); `"none"` drops both (cheapest poll). Header: `count`, `total` (matches before limit), `next_after_id` (pass back as `after_id` to page; a bogus cursor restarts). `sort:"fastest"` is kills only; with `limit:1` it is the best kill |
| `progression` | `{"encounter":3455,"difficulty":14\|"Heroic"}` | `pulls`, `kills`, `first_kill` and `best_kill` as references `{id, date, start_utc_ms, duration, duration_ms, best_pct}`, `nights[]` (default `bucket:"utc"` = UTC days, so a US evening raid lands on the NEXT date and can straddle two rows — **always pass `"bucket":"local"`** (optional `cutover_hour`, default 6) so an evening is one night; rows carry `night_local` = the evening's date, `date` (UTC) and `day_utc_ms`; `pulls`, `kill` bool, `kills` count, `best_pct` = the night's LOWEST remaining boss health, 0 on a kill night), `median_kill` / `median_kill_ms` |
| `regrade_fights` | `{"fight_id":"…"}`, `{"encounter":N,"difficulty":D}` or `{"kind":"key"}` | re-parses stored cards from their logs after a ruling change (R16 boss health), same id, pins and annotations kept; answers `{queued}` — poll `status.history.importing` to 0, then re-read. An ABORTED key (no END) is re-clocked as combat time to its last hit, so its `duration_ms` and `me.dps` can change; completed keys and boss pulls never move |
| `trend` | `{"player":"X","view":"damage"\|"healing","bucket":"day"\|"week" (omit = per fight),"local":true (day/week buckets by the log's local day from `cutover_hour`, points carry `date_local` — use it for raid nights),"spec":"Demonology","encounter":N,"difficulty":N,"since_utc_ms":N,"limit":N}` | `points[]`: `date`, `fight_id`, `per_sec`, `amount`, `duration_ms`, `fights` — the player's own trend line, the rubric's benchmark #1 as numbers |
| `stored_fight` | `{"fight_id":"…"}` / `+ "player":"X"` / `+ "view":"deaths"` / on a KEY `+ "boss":"The Hoardmonger"\|0` (a member boss parsed from the log on demand, same shapes, nothing stored; key cards list `bosses[]` — regrade a pre-2026-09-03 key by id once to fill it) | exactly `fight`'s rows, `breakdown`'s by_ability/by_target/timeline, or the death recap — every live recipe below works on it unchanged. Every answer says `tier: "card"\|"rows"\|"details"` and `available_views[]`. Breakdowns/timelines exist only in the **details tier**: kills, the fastest kill, the owner's best per (encounter, difficulty, spec), and pinned fights — 10 per (encounter, difficulty) by default, older ones are demoted to card+rows. Asking past the tier is a tool error, never a partial document: `no stored fight <id>` (evicted / never closed / a keystone's member boss — the key's Σ is the record), `details demoted by retention (tier rows) — pin kills you want to keep drillable`, `no death recap for <guid> — they did not die in it`, `only the card survives` |
| `pin_fight` | `{"fight_id":"…","pinned":true}` | protects a fight's details from retention (release with `false`) |
| `history_sql` | `{"query":"select … where x = ?","params":[…]}` | DuckDB over views `fights`, `players`, `rows`, `details`, `loadouts`, `annotations` → `{columns, rows}`. Read-only. For anything the fixed tools don't shape |

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
(the `me` block carries rank, DPS-role median and share, so no roster and
no jq role list is needed):
```sh
mcp-call.sh history '{"player":"Tranq","kind":"encounter","limit":15}' | jq -r \
  '.fights[] | "\(.date) \(.name) \(.encounter.difficulty_name) \(.duration) \(.result) me=\(.me.dps|floor) r\(.me.rank_dps)/\(.me.dps_count) med=\(.me.dps_median|floor) \(.me.dps_share)%"'
mcp-call.sh trend '{"player":"Tranq","bucket":"day","local":true,"limit":10}' | jq -r '.points[] | "\(.date_local) fights=\(.fights) \(.per_sec|floor)"'
```

Boss summary numbers (pulls-to-kill, first and best kill, median kill):
```sh
mcp-call.sh progression '{"encounter":3455,"difficulty":"Heroic","bucket":"local"}' | jq -c '{pulls,kills,first:.first_kill.date,best:(.best_kill|"\(.date) \(.duration) \(.id)"),median_kill,nights:(.nights|map("\(.night_local) \(.pulls)p \(.kills)k best=\(.best_pct)"))}'
```

The grade line for a just-closed kill straight off its card (rank among
DPS specs, true median, share) — the rubric's "vs the fight" read:
```sh
mcp-call.sh history '{"kind":"encounter","limit":1}' | jq -r \
  '.fights[0] | "\(.name) \(.encounter.difficulty_name) \(.duration) \(.result): \(.me.dps|floor) r\(.me.rank_dps)/\(.me.dps_count) = \((.me.dps/.me.dps_median*100)|floor)% of median, \(.me.dps_share)% share"'
```
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
