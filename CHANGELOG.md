# Changelog

## 0.7.0 — Soul at the top / 九档新奖励

- Rank1: original Soul; ranks2/3: one random Spectral; ranks4/5: two Tarot.
- Rank6: one seeded50/50choice between two Mult playing cards and two Bonus playing cards.
- Ranks7/8: one seeded50/50choice between random Tarot and random Planet; rank9: fixed Pluto.
- Original consumable behavior is retained; Soul requires an empty Joker slot when used and creates a Legendary through the game's native implementation.
- New runs use reward table2. Older saved runs, tickets and pending promises retain table1; descriptions follow the actual ticket version.
- Detailed Chinese/English guide and a reproducible downloadable development package complete the publishing workflow.
- Officer-resource classifier limitation remains open and is not disguised as fixed.

## 0.6.0 — Two ways to start / 双入口

- Added nine birthday-free presets: natal upper/middle/lower x fortune upper/middle/lower. Preview the target and reward before confirmation.
- Presets use the same General Pattern starter and keep selected tiers across8antes; no fictional birth chart or calendar is generated.
- Retained native birthday matching and dynamic decade progression,26pattern cards and12single composite traits.
- Added mode switching and stale-page-click protection while preserving seed/stake, cancel, held-R, quick restart and Continue behavior.
- Saved mode and preset identity; previous-run snapshots are not reclassified.
- Added per-preset tests and isolated engine scenarios, plus project-friendly development instructions and asset sources.
- **Not fixed:** officer-resource relationship recognition remains too restrictive. See `KNOWN-ISSUES.md`.

## 0.5.0 — Pattern coverage / 格局覆盖

Expanded five starter templates to26categories plus optional composite effects. This increased assignment coverage, but did not establish semantic classification accuracy; the subsequent officer-resource report demonstrates that distinction.
