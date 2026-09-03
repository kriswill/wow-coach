#!/usr/bin/env bash
# wow-coach pre-flight: is the pipeline ready to coach?
# Prints one OK/WARN/FAIL line per check; exits non-zero if any FAIL.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
fail=0

say() { printf '%-4s %s\n' "$1" "$2"; }

command -v jq >/dev/null && say OK "jq present" || { say FAIL "jq missing"; fail=1; }

status=$("$here/mcp-call.sh" status 2>&1)
if [ $? -ne 0 ]; then
  say FAIL "wowdps daemon/mcp unreachable: $status"
  exit 1
fi
say OK "daemon running (spawned on demand if needed)"

src=$(jq -r '.source // "none"' <<<"$status")
game=$(jq -r '.game_running' <<<"$status")
active=$(jq -r '.fight_active' <<<"$status")

if [ "$src" = "none" ] || [ "$src" = "null" ]; then
  say FAIL "daemon has no log source — no combat log to read (enable advanced combat logging in-game, check logs_dir in ~/.config/wowdps/config.toml)"
  fail=1
else
  say OK "following: $src"
fi

if [ "$game" = "true" ]; then
  say OK "game process detected"
else
  say WARN "game not running — historical analysis only, live monitoring will idle"
fi

if [ "$active" = "true" ]; then
  say OK "a fight is happening right now"
else
  say WARN "no live fight (normal between pulls; note: the game flushes log writes in multi-minute bursts, so a quiet log is NOT evidence logging is off — trust game_running, not mtime)"
fi

fights=$("$here/mcp-call.sh" list_fights 2>/dev/null | jq '.fights | length' 2>/dev/null || echo 0)
if [ "${fights:-0}" -gt 0 ]; then
  say OK "$fights fights indexed in the current log"
else
  say WARN "log has no fights yet — if the player has been in combat, combat logging is probably OFF in-game (/combatlog)"
fi

# History store (fights that persist across logins). Coaching without it
# falls back to memory for the trend line; an error blocks nothing but
# every "vs your own prior pulls" claim, so surface it loudly.
henabled=$(jq -r '.history.enabled // "absent"' <<<"$status")
hfights=$(jq -r '.history.fights // 0' <<<"$status")
himporting=$(jq -r '.history.importing // 0' <<<"$status")
herror=$(jq -r '.history.error // empty' <<<"$status")
if [ "$henabled" = "absent" ]; then
  say WARN "history store not reported by this daemon (pre-history build?) — trend/progression tools unavailable, memory is the only baseline"
elif [ "$henabled" != "true" ]; then
  say WARN "history store disabled (history_* keys in ~/.config/wowdps/config.toml) — no cross-session trend"
elif [ -n "$herror" ]; then
  say FAIL "history store error: $herror"
  fail=1
else
  extra=""; [ "$himporting" -gt 0 ] 2>/dev/null && extra=" (still importing $himporting older logs — early trend calls may be incomplete)"
  say OK "history store: $hfights fights held across logins$extra"
fi

exit $fail
