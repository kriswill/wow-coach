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
| `loadout` | `{"segment_id":N, "player":"name"}` | the player's ACTUAL build from the log's COMBATANT_INFO: `spec_id`, `talents` (named selections + `import_string` + `hero_tree` when the dataset knows the spec; raw `picks` with a `note` otherwise — rank 0 = granted node), and `gear.items` (slot, item_id, ilvl, enchants, gems, bonus_ids) with `gear.avg_ilvl`. Scoped to that fight — builds change between encounters, so query the segment you're grading. Omit segment_id for the live/most recent fight. `logged: false` when no COMBATANT_INFO fired (only logged inside instances) — not an error |
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
