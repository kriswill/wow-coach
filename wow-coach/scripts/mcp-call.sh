#!/usr/bin/env bash
# One-shot call to a wowdps MCP tool. Prints the tool's JSON document on
# stdout; exits non-zero (with the error on stderr) on tool or transport
# failure. The daemon is spawned on demand by wowdps-mcp itself — except on
# a host running the wowdps-dev systemd user unit, see unit_gate.
#
#   mcp-call.sh <tool> [json-arguments]
#   mcp-call.sh fight '{"segment_id":42}'
#   mcp-call.sh --gate        # just the unit check: exit 0 = safe to call
#
# Override binary discovery with $WOWDPS_MCP.
set -euo pipefail

# Where the wowdps-dev unit is installed it owns the daemon, and wowdps-mcp's
# ensure_daemon would SPAWN a stray, non-lingering daemon whenever the socket
# is missing — mid unit restart, that stray wins the socket race and the unit
# loses it (2026-09-28, reported by the wowdps dev session). So on such a
# host, call only while the unit is active AND its socket is listening, and
# otherwise exit 3 without ever starting wowdps-mcp. No unit installed = the
# old on-demand spawn. WOWDPS_NO_UNIT_GATE=1 skips the check.
unit_gate() {
  [ -n "${WOWDPS_NO_UNIT_GATE:-}" ] && return 0
  systemctl --user cat wowdps-dev.service >/dev/null 2>&1 || return 0
  if ! systemctl --user is-active --quiet wowdps-dev; then
    echo "mcp-call.sh: wowdps-dev unit not active — not calling (it would spawn a stray daemon). Start it: systemctl --user start wowdps-dev" >&2
    return 3
  fi
  # A stale socket FILE survives a restart (wowdps-v34.sock did), so ask
  # for a listening socket, not a path.
  local dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/wowdps"
  if command -v ss >/dev/null; then
    ss -xlH 2>/dev/null | grep -qF "$dir/wowdps-v" && return 0
  elif compgen -G "$dir/wowdps-v*.sock" >/dev/null; then
    return 0
  fi
  echo "mcp-call.sh: wowdps-dev is active but its socket is not listening yet — not calling (it would spawn a stray daemon)" >&2
  return 3
}

if [ "${1:-}" = "--gate" ]; then
  rc=0; unit_gate || rc=$?; exit "$rc"
fi
unit_gate || exit $?

tool="${1:?usage: mcp-call.sh <tool> [json-args]}"
args="${2:-{\}}"

find_mcp() {
  if [ -n "${WOWDPS_MCP:-}" ]; then echo "$WOWDPS_MCP"; return; fi
  if command -v wowdps-mcp >/dev/null; then echo "wowdps-mcp"; return; fi
  for d in "$HOME"/src/github/*/wowdps "$HOME"/src/*/wowdps; do
    for p in "$d/target/release/wowdps-mcp" "$d/target/debug/wowdps-mcp"; do
      [ -x "$p" ] && { echo "$p"; return; }
    done
  done
  echo "mcp-call.sh: no wowdps-mcp binary found (set \$WOWDPS_MCP or build it: cargo build -p wowdps-mcp)" >&2
  return 1
}

MCP=$(find_mcp)
# Modern-era MCP (2026-07-28): stateless, no initialize handshake; every
# request names its protocol revision in params._meta.
meta='{"io.modelcontextprotocol/protocolVersion":"2026-07-28"}'
reply=$(printf '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"%s","arguments":%s,"_meta":%s}}\n' "$tool" "$args" "$meta" \
  | timeout "${MCP_TIMEOUT:-25}" "$MCP")

if [ -z "$reply" ]; then
  echo "mcp-call.sh: no reply from $MCP (daemon unreachable?)" >&2
  exit 1
fi
if jq -e '.result.isError == true' <<<"$reply" >/dev/null 2>&1; then
  jq -r '.result.content[0].text' <<<"$reply" >&2
  exit 2
fi
jq -r '.result.content[0].text' <<<"$reply"
