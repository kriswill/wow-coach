#!/usr/bin/env bash
# Render a talent import string (optionally diffed against a second one) as a
# self-contained HTML page from the talent-viewer template.
#
#   scripts/render-talents.sh [-o out.html] <import-string> [compare-string]
#
# The talent dataset comes from, in order: $WOWDPS_TALENTS, the wowdps
# per-machine cache ($XDG_DATA_HOME/wowdps/talents.json — regenerate per
# patch with wowdps' tools/gen-talent-trees.sh), or this skill's
# references/talents-fallback.json snapshot (refresh with
# scripts/fetch-talents-fallback.sh when there is no game install).
# Output defaults into ~/Documents/wow-coach/ per the skill's report
# convention. The page itself decodes the strings, draws the tree panes,
# and diffs — this script only splices dataset + strings into the template.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
out=""
if [ "${1:-}" = "-o" ]; then
    out="$2"
    shift 2
fi
[ $# -ge 1 ] || { echo "usage: render-talents.sh [-o out.html] <import-string> [compare-string]" >&2; exit 1; }
primary="$1"
compare="${2:-}"
[ -n "$out" ] || {
    mkdir -p "$HOME/Documents/wow-coach"
    out="$HOME/Documents/wow-coach/talents-$(date +%Y-%m-%d-%H%M%S).html"
}

dataset=""
for cand in "${WOWDPS_TALENTS:-}" \
            "${XDG_DATA_HOME:-$HOME/.local/share}/wowdps/talents.json" \
            "$here/../references/talents-fallback.json"; do
    [ -n "$cand" ] && [ -s "$cand" ] && { dataset="$cand"; break; }
done
[ -n "$dataset" ] || {
    echo "no talent dataset: generate ~/.local/share/wowdps/talents.json with wowdps'" >&2
    echo "tools/gen-talent-trees.sh, or snapshot a fallback with scripts/fetch-talents-fallback.sh" >&2
    exit 1
}

# Both strings must be plain import strings (base64 alphabet) — they land
# inside a <script> block verbatim.
for s in "$primary" $compare; do
    printf '%s' "$s" | grep -Eq '^[A-Za-z0-9+/]+$' \
        || { echo "not a talent import string: $s" >&2; exit 1; }
done

loadouts=$(jq -cn --arg a "$primary" --arg b "$compare" \
    '[{string: $a}] + (if $b == "" then [] else [{string: $b}] end)')

awk -v data_file="$dataset" -v loadouts="$loadouts" '
    /\/\*__TALENTS_JSON__\*\// {
        printf "const DATA = ";
        while ((getline line < data_file) > 0) print line;
        print ";";
        next
    }
    /\/\*__LOADOUTS__\*\// { print "const LOADOUTS = " loadouts ";"; next }
    { print }
' "$here/../references/talent-viewer.html" > "$out"

echo "wrote $out (dataset: $dataset, build $(jq -r .build "$dataset"))"
