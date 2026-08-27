#!/usr/bin/env bash
# Per-character talent-loadout store: the builds a player tunes per raid
# boss, M+ dungeon, pvp bracket, or delve, kept OUTSIDE the repo in
# ~/Documents/wow-coach/loadouts/<character>.json (personal data, same home
# as the skill's HTML reports).
#
#   scripts/loadouts.sh add <character> <context> <encounter> <string>
#                           [--name <label>] [--notes <text>]
#   scripts/loadouts.sh list <character> [context]
#   scripts/loadouts.sh get <character> <name-or-encounter>
#   scripts/loadouts.sh rm <character> <name-or-encounter>
#
# context: raid-boss | mplus | pvp | delve | general
# An add with the same name (default: the encounter) replaces the entry —
# retuning a boss build is the normal case. Strings get a shape check here
# (version-2 alphabet); full validation is the MCP decode_talents tool /
# the viewer, which have the tree data. The WoW build is stamped from the
# best available talent dataset so patch drift is visible later.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
dir="$HOME/Documents/wow-coach/loadouts"
usage() { sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 1; }

cmd="${1:-}"
char="${2:-}"
[ -n "$cmd" ] && [ -n "$char" ] || usage
file="$dir/$(echo "$char" | tr '[:upper:]' '[:lower:]').json"

build() {
    for cand in "${WOWDPS_TALENTS:-}" \
                "${XDG_DATA_HOME:-$HOME/.local/share}/wowdps/talents.json" \
                "$here/../references/talents-fallback.json"; do
        [ -n "$cand" ] && [ -s "$cand" ] && { jq -r .build "$cand"; return; }
    done
    echo "unknown"
}

case "$cmd" in
add)
    context="${3:-}" encounter="${4:-}" string="${5:-}"
    [ -n "$string" ] || usage
    shift 5
    name="$encounter" notes=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --name) name="$2"; shift 2 ;;
            --notes) notes="$2"; shift 2 ;;
            *) usage ;;
        esac
    done
    case "$context" in raid-boss|mplus|pvp|delve|general) ;; *)
        echo "context must be raid-boss|mplus|pvp|delve|general (got: $context)" >&2; exit 1 ;;
    esac
    printf '%s' "$string" | grep -Eq '^C[A-Za-z0-9+/]{20,}$' || {
        echo "not a talent import string (v2 strings are base64-alphabet and start with C)" >&2
        exit 1
    }
    mkdir -p "$dir"
    [ -s "$file" ] || printf '{"character": "%s", "loadouts": []}\n' "$char" > "$file"
    jq --arg name "$name" --arg context "$context" --arg encounter "$encounter" \
       --arg string "$string" --arg notes "$notes" \
       --arg build "$(build)" --arg saved "$(date +%Y-%m-%d)" \
       '.loadouts = ([.loadouts[] | select(.name != $name)] +
            [{name: $name, context: $context, encounter: $encounter,
              string: $string, build: $build, saved: $saved}
             + (if $notes == "" then {} else {notes: $notes} end)])' \
       "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    echo "saved '$name' ($context, $encounter) for $char [build $(build)] -> $file"
    ;;
list)
    context="${3:-}"
    [ -s "$file" ] || { echo "no loadouts for $char ($file)" >&2; exit 1; }
    jq -r --arg ctx "$context" \
       '.loadouts[] | select($ctx == "" or .context == $ctx) |
        "\(.name)\t\(.context)\t\(.encounter)\t\(.build)\t\(.saved)\(if .notes then "\t" + .notes else "" end)"' \
       "$file"
    ;;
get)
    name="${3:-}"
    [ -n "$name" ] || usage
    [ -s "$file" ] || { echo "no loadouts for $char ($file)" >&2; exit 1; }
    jq -e --arg n "$name" \
       'first(.loadouts[] | select(.name == $n or .encounter == $n)) // error("no loadout \($n)")' \
       "$file"
    ;;
rm)
    name="${3:-}"
    [ -n "$name" ] || usage
    [ -s "$file" ] || { echo "no loadouts for $char ($file)" >&2; exit 1; }
    jq --arg n "$name" '.loadouts = [.loadouts[] | select(.name != $n and .encounter != $n)]' \
       "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    echo "removed '$name' from $file"
    ;;
*)
    usage
    ;;
esac
