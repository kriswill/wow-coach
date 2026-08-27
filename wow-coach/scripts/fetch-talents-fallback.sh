#!/usr/bin/env bash
# Snapshot Raidbots' live talent dataset as the NO-GAME-INSTALL fallback for
# the talent viewer and loadout tooling, converted to the same schema the
# wowdps extractor emits ($XDG_DATA_HOME/wowdps/talents.json).
#
#   scripts/fetch-talents-fallback.sh
#
# Output: references/talents-fallback.json. The primary source is always the
# local-install extraction (wowdps tools/gen-talent-trees.sh) — this
# snapshot exists so SimC-paste decoding and tree rendering still work on a
# machine without the game. Raidbots regenerates the file daily from SimC's
# extraction tools; re-run once per patch. The file carries no build id, so
# the snapshot date stands in for one.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
out="$here/../references/talents-fallback.json"

# Raidbots' per-spec node union can MISS tree nodes (verified: two Druid
# class nodes absent), and the import-string walk covers every TraitNode row
# of the tree — a wrong nodeOrder scrambles every bit after the gap. So the
# authoritative walk order comes from wago.tools' TraitNode export instead:
# tree id -> all node ids, ascending.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
curl -sfL -A wow-coach-talents "https://wago.tools/db2/TraitNode/csv" |
    awk -F, 'NR>1 { ids[$2] = ids[$2] "," $1 } END {
        printf "{"
        sep = ""
        for (t in ids) { printf "%s\"%s\":[%s]", sep, t, substr(ids[t], 2); sep = "," }
        printf "}"
    }' |
    jq 'map_values(sort)' > "$work/orders.json"

curl -sfL -A wow-coach-talents "https://www.raidbots.com/static/data/live/talents.json" |
jq --arg date "$(date +%Y-%m-%d)" --slurpfile order_docs "$work/orders.json" '
  ($order_docs[0]) as $orders |
  # One raidbots entry per SPEC; group into one tree per class. Node costs
  # are absent there, so synthesize the class/spec currency split the viewer
  # panes key on (class pane = first currency, spec pane = second).
  def conv_entry: {
    id, definitionId, spellId, name, icon,
    maxRanks: (.maxRanks // 1)
  } + (if .traitSubTreeId then {subTreeId: .traitSubTreeId} else {} end);
  def conv_node(cur): {
    id, type, posX, posY,
    maxRanks: (.maxRanks // 1),
    next: (.next // []), prev: (.prev // []),
    entries: [(.entries // [])[] | conv_entry]
  }
  + (if .reqPoints then {reqPoints} else {} end)
  + (if .freeNode then {granted: true} else {} end)
  + (if .subTreeId then {subTreeId} else {costs: [{currency: cur, amount: 1}]} end);

  {
    build: ("raidbots-live-" + $date),
    format: 1,
    trees: [
      group_by(.classId)[] |
      {
        treeId: .[0].traitTreeId,
        classId: .[0].classId,
        className: (.[0].className | gsub(" "; "")),
        specs: [.[] | {specId, name: .specName, role: 0}],
        currencies: [{index: 1, id: 1}, {index: 2, id: 2}],
        subTrees: (
          [.[] as $s | ($s.subTreeNodes // [])[] | (.entries // [])[] |
            {id: .traitSubTreeId, name, spec: $s.specId}] |
          group_by(.id) | map({id: .[0].id, name: .[0].name,
                               specs: ([.[].spec] | unique)})
        ),
        nodes: (
          (
            [.[] | (.classNodes // [])[] | conv_node(1)] +
            # A spec node carries the specs whose tree half shows it.
            ([.[] as $s | ($s.specNodes // [])[] | conv_node(2) +
              {visibleFor: [$s.specId]}] |
             group_by(.id) |
             map(.[0] + {visibleFor: ([.[].visibleFor[0]] | unique)})) +
            [.[] | (.heroNodes // [])[] | conv_node(0)] +
            [.[] | (.subTreeNodes // [])[] | conv_node(0) | .type = "subtree"]
          ) | group_by(.id) | map(.[0]) | sort_by(.id)
        )
      } |
      # Prefer the complete TraitNode walk order; the raidbots union is only
      # the last resort if wago ever drops the tree.
      . + {nodeOrder: ($orders[.treeId | tostring] // [.nodes[].id])}
    ]
  }
' > "$out.part"
mv "$out.part" "$out"

jq -r '"\(.build): \(.trees | length) trees, \([.trees[].specs | length] | add) specs, \([.trees[].nodes | length] | add) nodes"' "$out"
