# Talents — decode, diff, render, and the per-encounter loadout store

The coach can now read and write the game's own talent import strings and
show the player a real tree. Everything keys off a **patch-versioned
dataset extracted from the local game files** (never guide prose): the
wowdps extractor's `~/.local/share/wowdps/talents.json`, regenerated once
per patch with wowdps' `tools/gen-talent-trees.sh`. In the evidence
hierarchy this dataset ranks with logs — it IS the client's data. Guides
and research agents still rank below it: they may argue a *choice* of
talents, never what a tree contains.

## The four MCP tools (shapes in `references/mcp-tools.md`)

- `loadout {segment_id, player}` — the build the player ACTUALLY ran in
  one fight, from the log's COMBATANT_INFO: named talent selections with
  hero tree and a ready-to-import string (raw node/entry/rank picks with a
  note when the dataset misses the spec; rank 0 = granted), plus equipped
  gear per slot (item_id, ilvl, enchants, gems, bonus_ids, `avg_ilvl`).
  Per-encounter by construction — query the segment you're grading, not
  one from earlier in the night. `logged: false` means the fight was
  outside an instance, not an error. Unlike the other three this one
  talks to the daemon.
- `decode_talents {string}` — the first thing to do with any `talents=`
  line or pasted string: spec, hero tree, and every selected node with
  ranks/choice picks, named. Non-empty `warnings` mean build drift (string
  from another patch) — say so before judging anything about the build.
- `encode_talents {spec_id, selections}` — mint a string the player can
  paste in-game. Only ever build selections from a decode or from the
  dataset's node ids; never hand-edit string text.
- `talent_tree {spec_id}` — the full tree when you need node ids, gate
  points, or choice alternatives. Large; prefer decode output when the
  question is about one build.

No daemon is needed for the string tools; they read the dataset file. Without a game
install, `scripts/fetch-talents-fallback.sh` snapshots an equivalent
dataset to `references/talents-fallback.json` (raidbots nodes + wago.tools
walk order); point `WOWDPS_TALENTS` at it for MCP use, and the render
script below finds it on its own.

## Rendering a tree for the player

```
scripts/render-talents.sh [-o out.html] <string> [compare-string]
```

Self-contained HTML into `~/Documents/wow-coach/` (the report home):
class/spec/hero panes with game icons, hover tooltips, rank badges, and —
with a second string — diff highlighting (blue = both, red = only primary,
orange = only compare, purple = rank/choice differs). Wowhead deep-link in
the footer as the cross-check. Render when *talking about* a build beats
listing talent names: reviewing a proposed change, comparing the player's
build to a peer's, or walking through a boss-specific swap. The page also
takes pasted strings directly, so one render serves a whole session.

## The per-encounter loadout store

```
scripts/loadouts.sh add  <character> <context> <encounter> <string> [--name X] [--notes ...]
scripts/loadouts.sh list <character> [context]
scripts/loadouts.sh get  <character> <name-or-encounter>
scripts/loadouts.sh rm   <character> <name-or-encounter>
```

`~/Documents/wow-coach/loadouts/<character>.json`, contexts `raid-boss`,
`mplus`, `pvp`, `delve`, `general`. Same-name adds replace — retuning is
the normal case. Each entry is stamped with the dataset's WoW build:
**flag a loadout from an older build before recommending it** (nodes move
between patches; the string may import incomplete).

Coaching flow that makes the store earn its keep:

1. **Intake**: pull `loadout` on the latest instance fight (and/or decode
   the SimC paste's active `talents=` line); offer to save the string
   under tonight's target (`raid-boss "Boss Name"`). When loadout and
   paste disagree, the loadout is what was actually played — the paste is
   stale.
2. **Pre-pull**: when the fight-watch shows a shopping-list boss
   approaching and the store holds a loadout for it, check what the
   player is actually on (`loadout` of the last pull's segment, falling
   back to the paste) against `get` — exact string compare, or
   decode-and-diff. A mismatch is a one-line pre-brief, same as loot
   calls: "you're on your M+ build; 'Ashen Warden' loadout is saved —
   swap before pull."
3. **Per-fight**: `loadout` is scoped to its segment, so a swap claim is
   verified by re-querying the next pull — the import string changes or
   it doesn't. A wipe on the wrong build is a finding the meter alone
   can't show.
4. **Post-session**: a talent finding that survived the rubric becomes an
   encoded string + a saved loadout + a rendered diff page, not prose.
   Never push a mid-raid respec on unverified claims (Conduct rules
   apply); loadout changes are between-fights or homework.
5. **Per-boss research**: hand research agents the *decoded* selections,
   not the raw string — preferring `loadout`'s named selections from the
   actual encounter — they compare intent (choice nodes, capstones)
   against published builds and cite disagreements node-by-node.

## Ground rules

- The dataset outranks guides on tree *structure*; player-verified facts
  (`references/game-facts-*.md`) outrank everything on *mechanics*.
- `loadout` output IS the log — level-1 evidence on what was worn and
  talented in that fight. It outranks a SimC paste, a saved store entry,
  and any "I swapped" claim; when they disagree, flag the drift and grade
  against the loadout.
- Decode warnings are findings, not noise: a string that no longer walks
  the tree cleanly is how "my build broke after the patch" looks.
- Re-run the extractor (or the fallback fetcher) on every game patch,
  same cadence as the sim TSVs; the `build` field tells you when it's
  stale.
