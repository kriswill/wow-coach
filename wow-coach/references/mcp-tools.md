# wowdps MCP tools — cheat sheet

All calls go through `scripts/mcp-call.sh <tool> '<json-args>'`, which prints the
tool's JSON document on stdout. The daemon is spawned on demand; segment ids are
**per daemon run** — never cache them across sessions, always re-list.

| Tool | Args | Gives you |
|---|---|---|
| `status` | `{}` | daemon source, `game_running`, `fight_active`, overlay state |
| `list_fights` | `{}` | every segment: `id`, `kind` (encounter/trash/overall), `name`, `duration_ms`, `result` (kill/wipe/win/loss/null), `live`, `visit`, keystone pars |
| `fight` | `{"segment_id":N, "view":"damage", "top":N}` | per-player meter rows: `player`, `class`, `spec`, `amount`, `per_sec`, `share_pct`, `crit_pct`, `events`, overkill/overheal. Views: damage, healing, interrupts, crowd_control, dispels, deaths. Omit segment_id for the live fight |
| `breakdown` | `{"segment_id":N, "player":"name"}` | one player's per-ability rows (`amount`, `share_pct`, `hits`, `crit_pct`, `avg_hit`), per-target rows, and `timeline` (per-10s `dps` array + `marks`: trinket_use/trinket_proc/consumable/external_buff with `at_secs`). `"view":"deaths"` swaps in the death recap (`death_recap` rows with `health_after`) |
| `compare` | `{"segment_id":N, "a":"name", "b":"name"}` | two players side by side: totals, per-ability tables, both timelines on one clock |

Player args accept a display name, case-insensitive prefix ("Tranq" matches
"Tranqlock-Realm-US"), or GUID; a miss lists who was actually in the fight.

## Recipes proven in practice

Fight roster with ranks:
```sh
mcp-call.sh fight '{"segment_id":44}' | jq -r '.rows[] | "\(.rank) \(.player) \(.spec) \(.per_sec) \(.share_pct)%"'
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
