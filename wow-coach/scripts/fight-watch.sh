#!/usr/bin/env bash
# Emits one line per fight that completes, by polling the wowdps MCP
# list_fights tool. Designed to run under the Monitor tool: each stdout line
# becomes a notification. First poll is a silent baseline (only NEW
# completions are reported); a daemon restart (ids reset) re-baselines.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
SEEN=$(mktemp)
trap 'rm -f "$SEEN"' EXIT
baseline=1

while true; do
  doc=$("$here/mcp-call.sh" list_fights 2>/dev/null) || doc=""
  if [ -n "$doc" ]; then
    closed=$(jq -r '.fights[] | select(.live != true)
      | "\(.id)\t\(.kind)\t\(.name)\t\(.duration)\tresult=\(.result // "none")\(if .visit != null then " visit=\(.visit)" else "" end)"' \
      <<<"$doc" 2>/dev/null)
    if [ "$baseline" = 1 ]; then
      cut -f1 <<<"$closed" > "$SEEN"
      baseline=0
      echo "watching ($(grep -c . "$SEEN") fights already closed at start; source: $(jq -r .source <<<"$doc"))"
    else
      while IFS=$'\t' read -r id rest; do
        [ -n "$id" ] || continue
        if ! grep -qx "$id" "$SEEN"; then
          echo "$id" >> "$SEEN"
          printf 'FIGHT COMPLETE  id=%s  %s\n' "$id" "$(printf '%s' "$rest" | tr '\t' '  ')"
        fi
      done <<<"$closed"
      maxseen=$(sort -n "$SEEN" | tail -1)
      maxnow=$(jq -r '[.fights[].id] | max // 0' <<<"$doc")
      if [ -n "$maxseen" ] && [ "$maxnow" -lt "$maxseen" ] 2>/dev/null; then
        cut -f1 <<<"$closed" > "$SEEN"
        echo "daemon restarted; re-baselined"
      fi
    fi
  fi
  sleep 5
done
