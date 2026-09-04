# Verified game facts — Midnight 12.1, Season 2

Game-mechanic facts verified during coaching sessions for WoW **Midnight 12.1, Season 2** (Aug 2026). These correct stale assumptions; each was either confirmed in-game by the player or settled from their own logs.

- **Enchant slots: back and wrist have NO enchants in Midnight** (player-confirmed in-game, 2026-08-26). Head, shoulders, chest, legs, feet, rings, weapon DO (all seen with enchant_ids in the player's exports). Never flag back/wrist as missing enchants.
- **Catalyst (S2): currency is "Venomblight Manaflux", CurrencyID 3465, cap 1/8, accrues every two weeks** (tooltip screenshot). Also earnable from M+/raid/delves/rated PvP after the Catalyst Unbound feat. The SimC export's other catalyst_currencies entries (2813/3269/3116/3378) are OLD seasons — do not count them as charges.
- **Catalyst output INHERITS the base item's secondary stats** (tooltip: "will inherit the secondary stats of the original equipment"). Old-season tier pieces are ineligible (transmog-only conversion); non-tier-slot conversion grants no set bonus. → A charge is only worth spending on a good-stat base, and only as the piece that completes a bonus.
- **Summon Demonic Tyrant: 60s cooldown observed** (observed min recast intervals in the player's logs, 2026-08-26) — settles the 60-vs-90s guide conflict for that build.
- **Grimoire: Felguard no longer exists in 12.1** — replaced by Grimoire: Imp Lord / Fel Ravager (2-min CD, grants an extra Spell Lock/Singe Magic use). Never grade or query the old spell.
- **Demo tier set = "Damned Necrolyte's Shattered Restraints" (set 2066)**: 2pc +10% Wild Imp / +20% Implosion; 4pc 20% imp self-implode at 350%/315% (buffed 2026-08-15). No published sim numbers for the bonuses as of Aug 2026.
- S2 M+ pool: Murder Row, Altar of Fangs, Den of Nalorakk, The Blinding Vale, Voidscar Arena, King's Rest, Temple of Sethraliss, Ruby Life Pools. Murder Row timer 34 min.

**Why:** these facts invalidated four coaching findings in one night (wrist/back enchants, "8 banked charges", catalyze-the-helm, Grimoire counts); re-deriving them from guides gets them wrong.
**How to apply:** treat as ground truth for 12.1 sessions; these outrank guide prose AND research-agent output when they conflict. Re-verify on patch change, and append new player-confirmed facts here (dated) rather than in session notes. Character-specific state stays in memory (tranq-performance-coaching).
