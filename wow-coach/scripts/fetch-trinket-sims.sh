#!/usr/bin/env bash
# Pull bloodmallet's trinket sim rankings for every class/spec and flatten
# them into one TSV lookup the coach can grep while reviewing a SimC paste.
#
#   scripts/fetch-trinket-sims.sh [fight_style]     (default castingpatchwerk3)
#
# Output: references/trinket-sims.tsv next to this script's skill root.
# Re-run per patch / when the header's sim timestamp looks stale.
set -euo pipefail

style="${1:-castingpatchwerk3}"
root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/references/trinket-sims.tsv"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

specs=(
  death_knight/blood death_knight/frost death_knight/unholy
  demon_hunter/havoc demon_hunter/vengeance
  druid/balance druid/feral druid/guardian
  evoker/devastation evoker/augmentation
  hunter/beast_mastery hunter/marksmanship hunter/survival
  mage/arcane mage/fire mage/frost
  monk/brewmaster monk/windwalker
  paladin/protection paladin/retribution
  priest/shadow
  rogue/assassination rogue/outlaw rogue/subtlety
  shaman/elemental shaman/enhancement
  warlock/affliction warlock/demonology warlock/destruction
  warrior/arms warrior/fury warrior/protection
)

meta=""
{
  printf '# columns: class\tspec\trank\ttrinket\titem_id\tilvl:dps,... (rank 0 = passive baseline, min ilvl only)\n'
  for cs in "${specs[@]}"; do
    class="${cs%/*}" spec="${cs#*/}"
    url="https://bloodmallet.com/chart/get/trinkets/$style/$class/$spec"
    if ! curl -sf "$url" -o "$tmp/j" || ! jq -e '.data' "$tmp/j" >/dev/null 2>&1; then
      echo "skip $cs (no data)" >&2
      continue
    fi
    [ -n "$meta" ] || meta="$(jq -r '"# bloodmallet trinket sims | fight_style=\(.simc_settings.fight_style) | simmed \(.metadata.timestamp[:16]) | SimC \(.metadata.SimulationCraft) | tier \(.simc_settings.tier)"' "$tmp/j")"
    jq -r --arg c "$class" --arg s "$spec" '
      (.data.baseline as $b
       | [$c, $s, "0", "baseline", "-",
          ($b | to_entries | map("\(.key):\(.value)") | join(","))]
       | @tsv),
      (.item_ids as $ids | .data as $d
       | [.sorted_data_keys[] | select(. != "baseline")]
       | to_entries[]
       | [$c, $s, (.key + 1 | tostring), .value, ($ids[.value] // "-" | tostring),
          ($d[.value] | to_entries | sort_by(.key | tonumber) | map("\(.key):\(.value)") | join(","))]
       | @tsv)
    ' "$tmp/j"
    sleep 1
  done
} > "$tmp/body"

{ echo "$meta"; printf '# fetched %s by fetch-trinket-sims.sh\n' "$(date -u +%F)"; cat "$tmp/body"; } > "$out"
echo "wrote $out ($(grep -vc '^#' "$out") rows, $(grep -v '^#' "$out" | cut -f1,2 | sort -u | wc -l) specs)"
