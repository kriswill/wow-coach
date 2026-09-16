#!/usr/bin/env bash
# Identify WHICH RAID TEAM the player is with tonight, by roster overlap
# against their own past nights. The combat log carries NO guild field —
# no event has one, COMBATANT_INFO included — so "same guild" is inferred
# from who is standing in the raid, not read from the log.
#
#   raid-team.sh <player> [nights-of-history]
#
# Prints one line per past night: the overlap with the CURRENT (newest)
# roster, and a verdict. Overlap is |shared| / |smaller roster| so a 26-man
# night and a 20-man night still compare sensibly.
#
#   SAME TEAM   >= 60%   the regular group
#   MIXED       30-59%   the regular group with heavy fill, or a merge
#   DIFFERENT   <  30%   another team / a pug
#
# Why this and not the character: a character usually raids with one team,
# but "usually" is exactly the assumption that produces a wrong statement.
# Verify, then say it.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
mcp="$here/mcp-call.sh"
player="${1:?usage: raid-team.sh <player> [nights]}"
nights="${2:-6}"

raw=$("$mcp" history "{\"player\":\"$player\",\"kind\":\"encounter\",\"limit\":200,\"players\":\"all\"}")

jq -r --argjson n "$nights" '
  # one entry per fight: the night (local-ish: shift UTC back 8h so a US
  # evening is one night) and its roster as a sorted name list
  [ .fights[]
    | { night: ((.start_utc_ms - 28800000) / 86400000 | floor)
      , date:  .date[0:10]
      , names: [.players[].name]
      }
  ]
  | group_by(.night)
  | map({ night: .[0].night
        , date:  .[0].date
        , fights: length
        , roster: ( map(.names) | add | unique )
        })
  | sort_by(.night) | reverse
  | .[0:$n]
  | . as $all
  | $all[0] as $now
  | "TONIGHT  \($now.date)  \($now.roster|length) players, \($now.fights) fights"
  , ""
  , ( $all[1:][]
      | ( [ .roster[] | select( . as $x | $now.roster | index($x) ) ] | length ) as $shared
      | ( [ (.roster|length), ($now.roster|length) ] | min ) as $base
      | (($shared * 100 / $base) | floor) as $pct
      | "\(.date)  \(.roster|length)p  shared=\($shared)  overlap=\($pct)%  "
        + (if $pct >= 60 then "SAME TEAM"
           elif $pct >= 30 then "MIXED"
           else "DIFFERENT TEAM" end)
    )
' <<<"$raw"
