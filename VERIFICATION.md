# 0.6.0 verification / 验收记录

Verified on2026-09-20 against Balatro1.0.1o-FULL, Steamodded26.829.0, Lovely0.9.0 and LÖVE11.5. This is a development release with a known classification limitation, not a zero-defect claim.

## Exact runtime

The tested runtime has27files:17Lua/JSON and10PNG. The first frozen candidate was `TenYearsNineGrid-0.6.0-20260920-153940.zip`, SHA256 `D8D7DF74B70E93C32E2D63D4A03A342D174643C32A192BD2DF2DF38A2D0F17A0`. Each native QA run's private manifest was compared against that candidate, file by file. Final documentation may be packaged later; runtime identity is independently recorded in `docs/runtime-files.sha256`.

## Contract tests

All10Lua test files passed using the game's Lua5.1DLL. Eight counted suites total **1813 assertions**: presets1066, birthday/UI101, main/legacy109, cycles121, natal/fortunes90, resume18, pattern cards140, pattern-to-starter168. The matching and classifier suites additionally pass parity/validation and26categories/14special near-misses/12composites without contributing a printed assertion total.

- Native input helpers: actual digit0, cursor edits, Enter, letter rejection and four time spellings passed.
- Native old-gift callbacks: origin/select/skip/hand/deck/save contracts passed; these headless adapters are not graphical playthroughs.
- All10runtimePNG dimensions/alpha and all26occupied pattern cells passed.
- QA launcher and quit observer:10safety/behavior tests passed, including validated previous-version QA fixture paths.
- Pinned calendar table regeneration matched all3624transitions exactly. Calendar/classifier production code was not changed by0.6; previous952056classification inputs prove totality, not semantic correctness.

## Actual engine

All runs used newly owned offscreen game processes, private APPDATA/Mods, Steam disabled, and synthetic fixtures. Existing user games and saves were not controlled. DragonFantasyCity0.1.3 and TenYearsOneHand0.1.0 were included using code/art defaults only; personal configuration was not copied.

| Scenario | Result / evidence scope |
|---|---|
| preset1 | Mode page,3x3grid and all9previews; actual fixed upper/upper start; small blind300; two real Tarot rewards; ante2queue/delivery; save + independent-process reload.76+12events passed. |
| preset9 | Same9previews; actual lower/lower start; small blind600; one stone card added to permanent deck and current hand; ante2same rank; save/reload.76+12events passed. |
| Birthday | Birthday entry, native typing/matching, correct starter, actual scoring42, nine fortune fixtures, ante transition, save/reload.89+12events passed. |
| Previous0.5 save | Previously recorded synthetic QA save continued under0.6, oldpattern/card/54permanentcards/10hand/customback retained; no new selection or classification.11events passed. |

Preset runs made **zero calls to the birthday classifier**. Reloads likewise did not reclassify saved runs. Actual UI button elements were passed into preset callbacks, exercising stale-UIBox protection rather than bypassing it. Entry/grid/preview images were visually inspected at the native1024×640render size; buttons were present and unclipped.

Two QA-only failures were retained and investigated before rerunning: an unparenthesized Lua `gsub` return supplied an unintended base to `tonumber`; and an insufficient disk wait accepted an older ante2save before the native file worker finished. The probe now waits for serialized reward queues and card identities to match. Production logic was not changed to conceal these failures. The complete corrected preset1run and independent reload passed.

## Independent review

Specification review passed, followed by code-quality review with no unresolved critical/high production findings in this change. The reviewer independently reran contracts,10PNGchecks and27runtimehashes, and checked the native UIElement/UIBox ownership semantics. This review does not claim every third-party configuration or every26card full-run combination is covered.

## Privacy, limitations and local installation

All fixed birth inputs in tests are synthetic demonstration fixtures, not user profiles. User screenshots, user birth charts, saves, credentials, machine-specific logs, proprietary engine dumps and previous-version backup folders are excluded from Git. Only anonymous preset-menu screenshots are included.

The officer-resource matching defect remains open: see `KNOWN-ISSUES.md`. Real-world fortune/personal-outcome claims are not validated. The nine-grid tests and explicit ante advancement do not mean eight-ante gameplay balance or complete playthroughs were tested.

The verified0.6runtime was installed after game-closed preflight, with the previous0.5folder backed up. All27installed files match the exact tested candidate; all10Lua suites and10PNGchecks were rerun against the actual installed directory and passed. No user save or other mod was modified. This is not evidence of remote GitHub synchronization; remote commit/tree verification is a separate final step.
