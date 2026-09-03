#!/usr/bin/env bash
# Emits one line per fight that completes. Designed to run under the Monitor
# tool: each stdout line becomes a notification.
#
# Two streams, both baselined silently on the first poll, both keyed on the
# history store's STABLE ids (`<log>-<start_ms>`), which survive daemon
# restarts and log rollovers — no per-run integer ids, no name+duration
# matching, no re-baselining:
#   FIGHT COMPLETE  id=<stable id>  <kind> <name>  enc=<id> diff=<n>  <m:ss>  result=<kill|wipe|win|loss>
#     — bosses, keystone overalls and arenas from the history store, gated on
#       start_utc_ms > the newest start seen so far (a time cursor): after a
#       restart the store re-imports older logs for minutes and the newest-N
#       window fills with weeks-old fights.
#   TRASH COMPLETE  id=<stable id>  <name>  <m:ss>
#     — trash stretches from the live segment list (not stored), keyed on the
#       `history_id` the daemon computes for every closed row (wowdps
#       2026-09-03). Kept only so the loot pre-brief can see which boss is
#       next.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
HSEEN=$(mktemp); TSEEN=$(mktemp)
trap 'rm -f "$HSEEN" "$TSEEN"' EXIT
baseline=1
cursor=0

while true; do
  hist=$("$here/mcp-call.sh" history '{"limit":40,"sort":"newest","players":"none"}' 2>/dev/null) || hist=""
  live=$("$here/mcp-call.sh" list_fights 2>/dev/null) || live=""

  # A daemon mid-restart answers with no source or an empty list: treat it
  # as "no data this poll".
  if [ -z "$live" ] || [ "$(jq -r '.source // "null"' <<<"$live")" = "null" ] || [ "$(jq -r '.fights|length' <<<"$live")" = "0" ]; then
    sleep 5; continue
  fi

  if [ "$baseline" = 1 ]; then
    jq -r '.fights[]?.id' <<<"$hist" > "$HSEEN"
    cursor=$(jq -r '[.fights[]?.start_utc_ms] | max // 0' <<<"$hist")
    jq -r '.fights[] | select(.live != true and .kind=="trash" and .history_id != null) | .history_id' <<<"$live" > "$TSEEN"
    hstat=$(jq -c '.history // {}' <<<"$("$here/mcp-call.sh" status 2>/dev/null)")
    baseline=0
    echo "watching (history: $(jq -r '.fights // "?"' <<<"$hstat") fights stored, $(jq -r '.importing // 0' <<<"$hstat") importing, cursor=$cursor; live: $(jq -r '.fights|length' <<<"$live") segments, $(grep -c . "$TSEEN") trash baselined; source: $(jq -r .source <<<"$live"))"
    sleep 5; continue
  fi

  # Stored fights newer than the cursor, oldest-new first.
  if [ -n "$hist" ]; then
    newmax=$(jq -r --argjson c "$cursor" '[.fights[]? | select(.start_utc_ms > $c) | .start_utc_ms] | max // 0' <<<"$hist")
    jq -r --argjson c "$cursor" '.fights[] | select(.start_utc_ms > $c)
      | "\(.id)\t\(.kind)\t\(.name)\t\(.encounter.id // "-")\t\(.encounter.difficulty // "-")\t\(.duration)\t\(.result // "none")"' <<<"$hist" \
      | tac | while IFS=$'\t' read -r id kind name enc diff dur res; do
          [ -n "$id" ] || continue
          grep -qxF "$id" "$HSEEN" && continue
          echo "$id" >> "$HSEEN"
          printf 'FIGHT COMPLETE  id=%s  %s %s  enc=%s diff=%s  %s  result=%s\n' "$id" "$kind" "$name" "$enc" "$diff" "$dur" "$res"
        done
    if [ "$newmax" -gt "$cursor" ] 2>/dev/null; then cursor=$newmax; fi
  fi

  # Live trash, keyed on the daemon-computed stable id.
  jq -r '.fights[] | select(.live != true and .kind=="trash" and .history_id != null) | "\(.history_id)\t\(.name)\t\(.duration)"' <<<"$live" \
    | while IFS=$'\t' read -r hid name dur; do
        [ -n "$hid" ] || continue
        grep -qxF "$hid" "$TSEEN" && continue
        echo "$hid" >> "$TSEEN"
        printf 'TRASH COMPLETE  id=%s  %s  %s\n' "$hid" "$name" "$dur"
      done
  sleep 5
done
