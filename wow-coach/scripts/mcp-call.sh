#!/usr/bin/env bash
# One-shot call to a wowdps MCP tool. Prints the tool's JSON document on
# stdout; exits non-zero (with the error on stderr) on tool or transport
# failure. The daemon is spawned on demand by wowdps-mcp itself.
#
#   mcp-call.sh <tool> [json-arguments]
#   mcp-call.sh fight '{"segment_id":42}'
#
# Override binary discovery with $WOWDPS_MCP.
set -euo pipefail

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
reply=$(printf '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"%s","arguments":%s}}\n' "$tool" "$args" \
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
