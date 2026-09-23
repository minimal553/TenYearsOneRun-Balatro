# 0.7.0 verification / 验收记录

Verified2026-09-23 on Balatro1.0.1o-FULL, Steamodded26.829.0, Lovely0.9.0 and LÖVE11.5. This is a development release with a known classification limitation, not a zero-defect or fate-prediction claim.

## Exact runtime and tests

27runtimefiles:17Lua/JSON and10PNG. The first frozen runtime was extracted from `TenYearsNineGrid-0.7.0-20260923-105940.zip`, SHA256 `EDB1F38DEDA58DF3E98F1225467698D7C61C34D0844B3942B312292044170161`. That intermediate archive was used for engine verification, not the final documentation bundle. The final ZIP hash may differ; exact runtime bytes are independently recorded in `docs/runtime-files.sha256`.

All11Lua suites passed. Nine counted suites total **2075 assertions**: UI101, presets1066, main/legacy109, cycles122, natal/fortune99, reward-version252, resume18, pattern cards140, pattern-to-starter168. Matching/classification additionally passed parity/validation,26categories,14special near-misses and12composites without contributing a printed count.

Native input/old-gift callback probes and all10PNG/all26cell checks also passed. These headless adapters do not replace the graphical evidence below. Seeded contract tests cover both reward-type branches, the0.5boundary, duplicate claims, full slots, saved copies and legacy effects.

## Actual engine

All runs used newly owned offscreen processes, private APPDATA/Mods, disabled Steam and synthetic inputs. No actual user game/save was loaded or controlled. Compatibility runs included DragonFantasyCity0.1.3 and TenYearsOneHand0.1.0 code/art defaults, not personal settings.

| Scenario | Evidence |
|---|---|
| Original Soul | All9previews; upper/upper start at300points; original c_soul in inventory; native use created j_DFC_asabith, rarity4; separate restart retained starter and Legendary.83+12events passed. The Legendary pool reflects installed mods. |
| Fixed Pluto | Lower/lower start at600points; c_pluto used natively; High Card level1→2; stage2and independent restart retained rank9and level2.81+12events passed. |
| Birthday/all9rewards | Native input, starter and real scoring; nine reward fixtures; ordinary Spectral, rank4second Tarot queued behind full slots, rank6two m_bonus cards added permanently/currenthand with two growth callbacks, lower random rewards, Pluto, save/restart.104+12events passed. |
| Old0.6promise | Restored an owned0.6preset9save and actually used its saved ticket: still stone, not Pluto, without reclassification.14events passed. |

Every run's27runtimefiles were hash-compared to the frozen candidate; all owned processes exited0. Native menu/reward images were visually checked. Explicit ante advancement and reward fixtures are lifecycle tests, not claims of a full eight-ante victory or every-card balance study.

## Persistence defect found and closed before release

Independent review rejected immediate save_run inside the PLAY_TAROT animation: it could save a transient STATE whose restore event would not survive restart. A QA observer reproduced this on the old candidate: an attempted save in native state6.

The corrected code locks the reward-type branch and claim, marks reward_dirty, then saves only after C.update passes its existing stable-state gate. Full inventory still saves the pending promise; repeated idle updates neither resave nor reroll. No global STATE or native lock is overwritten. Unit tests cover PLAY_TAROT, use/controller locks, STOP_USE, stable full-slot saving and continuation from the saved snapshot.

Final native runs used the same observer:3stable mod saves in Soul,3in Pluto,14in the matrix and1in old-ticket use; no unstable mod-save request. All independent restarts passed. Terminating before an ordinary save finishes can still roll back progress; no stronger crash-atomicity claim is made.

## Versions, privacy and limitations

New runs store reward_version=2; missing old versions mean1. Explicit ticket versions take precedence, and concrete queued effects are not reinterpreted. Card descriptions reflect their actual version.

User birth charts/screenshots, personal saves, tokens, machine logs, proprietary engine dumps, QA run folders and backups are excluded from Git/release packages. Included menu/Soul screenshots and fixed test dates are synthetic demonstration fixtures, not user profiles.

The officer-resource classifier issue remains open in KNOWN-ISSUES.md. Previous952056input coverage proves totality, not semantic correctness. Original classifier/artwork are unchanged by this reward update. No exhaustive third-party compatibility or win-rate claim is made.

## Reproduction

See docs/DEVELOPMENT.md and tools/runtime_qa/README.md. Use your own game installation. Native scenarios: preset1, preset9, cycle and legacy9; previous-version test paths are allowlisted.

The verified runtime was installed after game-closed preflight and a complete0.6backup. All27installed files match the native-tested candidate. All11Lua suites and10PNGchecks were rerun against the installed directory and passed. No user saves or other mods were modified. Remote commit and final downloadable archive checks remain separate publishing steps.
