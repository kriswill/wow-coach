# Research agents — what to launch and how to keep them honest

Launch these as background general-purpose agents at session start (parallel,
while pre-flight and SimC mining proceed). Your training data lags the live
patch: agents must web-search and be told to trust the web over memory.

## Agent 1 — spec performance reference

For the player's class/spec (and hero tree), request: current priority in
brief; expected top damage sources and rough shares in the player's content
type; cooldown cadences per minute; common measurable mistakes ranked by
cost; current "good DPS" bands for the content level. Sources to name:
maxroll.gg, icy-veins.com, method.gg, murlok.io, archon.gg, mythicsim.com,
wowhead. Require inline source citations. Also request one-paragraph
summaries of the class's other specs (players swap).

## Agent 2 — log-analysis benchmarks

Community thresholds for grading: active-time bars, CD-count formulas, burst
alignment windows, death-analysis criteria (including the class's defensive
kit with cooldowns), group-share expectations for the content type,
consumable discipline norms. Ask for quantified rules, not vibes.

## Agent 3 — gear intelligence

Builds the session's BiS map, boss shopping list, crafting guidance, and
per-spec stat priorities. Scope and output format live in
`references/gear-intel.md` — read it before writing this agent's prompt.
Request: (a) BiS/near-BiS per slot for the active spec, each item keyed by
its drop source; (b) crafted-gear recommendations with stat choices;
(c) stat priority + soft caps for EVERY spec of the class, with murlok-style
top-player stat averages for calibration; (d) item-page stats for any bag
items you name (from the SimC paste) so the bag audit can run. Sources:
mythicsim.com, murlok.io, archon.gg, method.gg, wowhead loot tables +
item pages, maxroll/icy-veins for crafting.

## Per-boss talent loadouts (when the player shares loadouts or a raid target)

Ask the agent for the guide-published per-boss build recommendations AND the
node-level reality (archon.gg per-boss talent trees, murlok top-player
builds). The player's side of the comparison comes from the `loadout` MCP
tool on the actual encounter segment (named selections + hero tree — what
was really run on that boss), falling back to their saved loadouts by *name
and intent* (players often keep boss-named loadouts); hand the agent the
decoded/named selections, never raw strings, and flag only differences
confirmed at node level. Export strings must be captured verbatim from a rendered guide
page — an agent that cannot extract one must say so, never reconstruct.

## The honesty rules (bake them into every prompt)

- **Node-level pick rates and parse tables outrank guide prose.** Rotation
  text describes buttons *if talented*; it is not evidence a talent is meta.
  Any "ability X is core / missing" claim must cite murlok/archon-style
  pick-rate or parse data before it reaches the player.
- Require the agent to flag which claims are sourced vs inferred, and to
  say "could not extract" rather than reconstruct strings/numbers.
- Percentages scraped from prose are soft; label them as bands, prefer
  trend-vs-self in actual coaching.
- When two agents (or an agent and the player's own data) disagree, resolve
  with a dedicated verification agent pointed at node-level sources — and if
  the original claim was wrong, retract it explicitly and update the
  session's rubric notes so it stays retracted.
