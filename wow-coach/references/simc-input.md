# Mining a SimC addon export

The paste is a full machine-readable character: equipped gear, bags,
currencies, professions, and every saved talent loadout. Mine it before any
research runs — several high-value findings need no web at all.

## Free wins to scan for (each was a real finding)

1. **Missing enchants** — an equipped slot line with no `enchant_id=` where
   the slot is enchantable. The slot list is EXPANSION-DEPENDENT — verify it
   against a current-patch enchant guide before flagging (in Midnight 12.1,
   back and wrist have no enchants; confirmed in-game 2026-08-26). The addon
   sometimes also comments `<Enchant: Missing>`.
2. **Never-filled slots** — `slot_high_watermarks=` entries of the form
   `slot:equipped:bag`; a leading `0` (e.g. `14:0:298`) means that slot has
   *never* held an item. Cross-check `### Gear from Bags` for a filler (an
   empty off-hand with three off-hands in bags actually happened).
3. **Bag upgrades** — bag items whose ilvl beats the equipped piece in the
   same slot. Flag straight upgrades; caveat tier/set pieces.
4. **Unspent catalyst charges** — `catalyst_currencies=`; charges banked
   while the character lacks tier-set bonuses is routinely the single biggest
   passive gap to same-spec peers (verify by looking for tier-proc damage
   sources in a peer's breakdown).
5. **Upgrade currencies** — `upgrade_currencies=` for crest/valor equivalents
   sitting unused against low-ilvl equipped slots.
6. **Saved loadouts** — the commented `# Saved Loadout:` talent strings, plus
   the active `talents=` line. Decode them with the `decode_talents` MCP
   tool (see `references/talents.md`): spec, hero tree, every node with
   ranks and choice picks. Never fabricate or hand-edit a talent string by
   text surgery — mint one only through `encode_talents`, and warn when the
   source's game build differs from the player's.
7. **Tier set audit** — pieces sharing a set-style name across slots (e.g.
   "Abyssal Immolator's …" on chest/head/hands/legs) are the tier set. Count
   equipped vs in-bags: set bonuses usually dwarf a 10–20 ilvl deficit, so
   banked tier + no bonus is a finding — though spending catalyst charges on
   *high*-ilvl non-tier pieces beats equipping low-ilvl bag tier when both
   are options. Verify the bonus is live later via tier-proc damage sources
   in the logs.
8. **Active loadout sanity** — compare the active `talents=` string against
   the saved loadouts (exact match first, else decode both and diff the
   selections); a player raiding on their "M+" loadout (or vice versa) is
   the cheapest DPS fix on any list. The saved-loadout store
   (`scripts/loadouts.sh`, see `references/talents.md`) may already name
   the right build for tonight's target.
9. **Trinket sanity vs sims** — look up both equipped trinkets (and any
   trinkets in `### Gear from Bags`) in `references/trinket-sims.tsv`
   (usage notes in `references/gear-intel.md` §5): grep the class+spec, read
   each trinket's DPS at its actual ilvl, and flag when a bagged trinket
   out-sims an equipped one at the ilvls the player owns. No web needed —
   the file is local sim data; check its header date is current-patch.
10. **Identity facts** — level, race, spec, professions (an alchemist has no
   excuse on potions), `# WoW <version>` (pin research to this patch).

## Cross-checks against the logs

- Trinkets in the paste vs `trinket_proc`/`trinket_use` marks in breakdowns:
  a looted-but-unequipped trinket shows up as the OLD trinket's procs still
  firing. Same for any "I equipped it" claim — the logs are the receipt.
- Max HP in death recaps (`health_after.max`) should match the paste's
  health — confirms you're reading the right character.
- A talent/build change claim is verified by a new damage-source name
  appearing (or an old one vanishing) in the next pull's breakdown.
