#!/usr/bin/env bash
# Pull bloodmallet's secondary-stat distribution sims for every class/spec
# across the 1/3/5-target casting profiles and flatten the best
# distributions into one TSV lookup for stat-mix review.
#
#   scripts/fetch-secondary-sims.sh
#
# Output: references/secondary-sims.tsv. Re-run per patch.
set -euo pipefail

top=15   # distributions kept per spec/profile (the optimal plateau)
root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/references/secondary-sims.tsv"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

styles=(castingpatchwerk:1 castingpatchwerk3:3 castingpatchwerk5:5)
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
  printf '# columns: class\tspec\ttargets\trank\tcrit_haste_mastery_vers\tdps  (%% of the secondary budget; rank 0 = budget:<rating> with the grid-worst dps for range)\n'
  for cs in "${specs[@]}"; do
    class="${cs%/*}" spec="${cs#*/}"
    for st in "${styles[@]}"; do
      style="${st%:*}" targets="${st#*:}"
      url="https://bloodmallet.com/chart/get/secondary_distributions/$style/$class/$spec"
      if ! curl -sf "$url" -o "$tmp/j" || ! jq -e '.data' "$tmp/j" >/dev/null 2>&1; then
        echo "skip $cs $style (no data)" >&2
        continue
      fi
      [ -n "$meta" ] || meta="$(jq -r '"# bloodmallet secondary-stat sims | targets column = castingpatchwerk/-3/-5 profile | simmed \(.metadata.timestamp[:16]) | SimC \(.metadata.SimulationCraft) | tier \(.simc_settings.tier)"' "$tmp/j")"
      jq -r --arg c "$class" --arg s "$spec" --arg t "$targets" --argjson top "$top" '
        (.simc_settings.tier) as $tier
        | .data[$tier] as $d
        | ([$c, $s, $t, "0", "budget:\(.secondary_sum)", ($d | [.[]] | min | tostring)] | @tsv),
          (.sorted_data_keys[$tier][:$top]
           | to_entries[]
           | [$c, $s, $t, (.key + 1 | tostring), .value, ($d[.value] | tostring)]
           | @tsv)
      ' "$tmp/j"
      sleep 1
    done
  done
} > "$tmp/body"

{ echo "$meta"; printf '# fetched %s by fetch-secondary-sims.sh\n' "$(date -u +%F)"; cat "$tmp/body"; } > "$out"
echo "wrote $out ($(grep -vc '^#' "$out") rows, $(grep -v '^#' "$out" | cut -f1,2 | sort -u | wc -l) specs)"
