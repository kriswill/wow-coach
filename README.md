# wow-coach

A [Claude Code](https://claude.ai/code) skill that turns the
[wowdps](https://github.com/kriswill/wowdps) damage meter into a live
between-pulls World of Warcraft performance coach: it pre-flights the
combat-log pipeline over the daemon's MCP server, mines a pasted SimC
export for free gear wins, launches patch-current research agents, watches
for fight completions in the background, and grades every kill or wipe
against a triage rubric with same-spec comparisons and trend tracking.

## Install

```sh
git clone https://github.com/kriswill/wow-coach
cd wow-coach && ./install.sh
```

`install.sh` symlinks `wow-coach/` into `~/.claude/skills/` (override the
config root with `CLAUDE_DIR`). Because it's a link, `git pull` updates the
live skill in place. Requires the wowdps daemon's MCP server for the live
coaching loop; the SimC-paste and sim-lookup parts work without it.

## Layout

- `wow-coach/SKILL.md` — the skill entry point: phases, guardrails, and the
  when-to-load table for everything below.
- `wow-coach/references/` — the coach's working knowledge: MCP tool shapes,
  the grading rubric, SimC-paste mining, research-agent briefs, gear
  intelligence, player-verified game facts, and two generated sim lookups
  (`trinket-sims.tsv`, `secondary-sims.tsv`) built from
  [bloodmallet](https://bloodmallet.com) data.
- `wow-coach/scripts/` — pre-flight and MCP helpers, the fight-watch
  monitor, and the bloodmallet fetchers that regenerate the sim lookups.
- `wow-coach/evals/` — trigger evals for the skill description.

## Refreshing sim data (once per game patch)

```sh
wow-coach/scripts/fetch-trinket-sims.sh      # trinket rankings, ilvl→DPS
wow-coach/scripts/fetch-secondary-sims.sh    # secondary-stat splits at 1/3/5 targets
```

Both stamp the sim date and SimC build into the TSV headers; specs missing
from the output have no bloodmallet chart for the current game build.
Commit the refreshed TSVs so the data is versioned per patch.
