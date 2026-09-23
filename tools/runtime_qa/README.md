# Isolated real-engine QA

For the current release's verification scope, see the project `VERIFICATION.md`.
Machine-specific old reviews and actual run directories are not published.

Run from the repository root:

```powershell
python -B -m unittest discover -s tests/runtime_qa -v
python -B tools/runtime_qa/launch.py --scenario smoke
python -B tools/runtime_qa/launch.py --scenario cycle
python -B tools/runtime_qa/launch.py --scenario combo
python -B tools/runtime_qa/launch.py --scenario preset1
python -B tools/runtime_qa/launch.py --scenario preset9
```

Each invocation creates a new `qa-runs/<timestamp-id>/` and never reuses or deletes
an existing run. It copies Steamodded, the current production mod and QA-only
Lovely patches there. The installed executable and production mod are read-only.
The subprocess gets private `APPDATA`, `LOCALAPPDATA` and `LOVELY_MOD_DIR` values;
the parent environment remains unchanged. A `conf.lua` injection asserts the real
save and mod paths before `Game:start_up` first reads settings. The native Steam
initialization branch is disabled only in this private test's in-memory patch.
An earlier bootstrap `require` guard blocks `luasteam` even if that branch patch
stops matching; an attempted load fails the run. Expected paths are transmitted
as ASCII hex because Lua 5.1's narrow Windows `os.getenv` cannot reliably return
Chinese paths in the same UTF-8 encoding as LÖVE.

The launcher records its own process handle/PID and only terminates that owned
process on timeout. It never discovers, focuses, closes or kills an existing game.
The QA window is placed offscreen, with muted audio. The actual game draws its
normal screen and `love.graphics.captureScreenshot` captures the rendered frame.
The native `love.update`, `love.draw`, event manager, UI and card implementations
remain in use. Screenshot completion is required before a passing report.

Evidence is retained as `launch.json`, `process-output-<phase>.log`, private Lovely
logs and `userdata/Balatro/runtime-qa-result-<phase>.json` plus PNGs. The manifest records
production-mod file hashes, so concurrent edits do not make an old pass evidence
for a newer version. A smoke pass proves isolated engine loading and rendering;
it does not prove the fortune/ante lifecycle or full gameplay.

The `cycle` scenario runs a second, newly owned process after the first saves and
exits. It selects the birthday route and types synthetic `20050412` / `030` through the actual native input
helpers, changes the preview to decade six, starts through production callbacks,
and verifies the saved run nevertheless starts at decade one. It selects the
native small blind, uses the rank-two fortune through `G.FUNCS.use_card`, and
checks one ordinary Spectral, no booster, unchanged hand and deck identity.
Real `ease_ante(1)` tests target scaling, a full consumable inventory tests pending
fortune delivery, and native selling frees one slot. All nine fortunes are then
granted explicitly as QA fixtures with `qa_fixture_rank_N` claim IDs, and used
through native `G.FUNCS.use_card`. These are distinguished from normal per-ante
grants. Rank four starts with another inventory card, forcing the second Tarot to
queue until the blocker is natively sold. Rank-six enhanced playing rewards verify
actual hand, permanent playing-card list, deck capacity and exactly two
`playing_card_added` contexts. A normal non-face card is played through native
highlight/play functions: the natal Joker's unaltered scoring result is observed,
one hand is spent, chips increase, and the draw phase refills one card. The actual
blind threshold must equal its displayed integer. The save worker must write the expected run
before exit. The second process continues that save and checks duplicate rewards,
hand retention and absence of a new birthday prompt.

It does not simulate beating eight antes, or prove every dedicated Joker's live
scoring behavior. Source contract tests cover the broader Joker branch matrix.

Compatibility can add the user's two currently enabled content mods:

```powershell
python -B tools/runtime_qa/launch.py --scenario cycle --extra-mod "$env:APPDATA/Balatro/Mods/DragonFantasyCity" --extra-mod "$env:APPDATA/Balatro/Mods/TenYearsOneHand"
```

`--extra-mod` is repeatable, but only these reviewed names are accepted. An explicit
file allowlist copies their code/art/manifest. TenYearsOneHand's personal
`config.lua` and any profile files are neither opened nor copied; its code falls
back to built-in defaults. Expected extra mod IDs must actually load in the test
engine. `launch.json` records every copied extra file hash and the omission.

For a focused resume regression, `--scenario reload --seed-qa-run <run-id>` starts
a new private run from five explicit synthetic save files inside a previously
recorded project QA run. Absolute paths and traversal are rejected. This never
loads the user's actual save. The resume gate checks the restored Back center,
Back atlas, and actual GPU texture identity on every playing-card back, as well as
the saved gameplay state. A populated atlas registry alone is not acceptance.

The authorized previous-version fixture syntax is `v0.4-dev:<owned-qa-run-id>`
or `v0.5-dev:<owned-qa-run-id>` or `v0.6-dev:<owned-qa-run-id>`.
It resolves only inside that sibling development project's recorded `qa-runs/`;
it is not an arbitrary file/path option. Resume also observes the classifier and
requires zero new classifications of saved patterns.

`combo` types a real-calendar synthetic witness (1901-09-08 18:00 male), verifies
the actual card's composite, then selects only visible natural hands through the
native poker evaluator and play callbacks. It must really win the small blind,
observe the $1 Joker cashout row, cash out natively, save and restart. No score,
game state or deck ordering is assigned to force a win.

The QA-only `love.quit` observer delegates to the original callback and preserves
all return values. It logs the status, trace and native cancellation decision.
An uncompleted scenario which really quits writes a failed report, so exit code 0
alone is never mistaken for a pass. The observer never issues or vetoes a quit.

Official implementation references:

- [Lovely 0.9.0 mod directory and log selection](https://github.com/ethangreen-dev/lovely-injector/blob/v0.9.0/crates/lovely-core/src/lib.rs#L99)
- [Lovely patch syntax](https://github.com/ethangreen-dev/lovely-injector/blob/v0.9.0/README.md)
- [LÖVE 11.5 Windows APPDATA handling](https://github.com/love2d/love/blob/11.5/src/modules/filesystem/physfs/Filesystem.cpp#L512)
- [LÖVE fused-game identity selection](https://github.com/love2d/love/blob/11.5/src/modules/love/boot.lua#L72)
- [Frame-end screenshot capture](https://www.love2d.org/wiki/love.graphics.captureScreenshot)

No private saved birth information is read or copied. Tests use fresh profiles.

`preset1` and `preset9` exercise the new entry menu, rendered3x3grid and all9
preview choices, then start the selected best/worst fixed challenge. They verify
the real General Pattern starter, actual blind threshold and fortune use,
advance one ante through the native function, save and restart in an independent
owned process. Version0.7also actually uses the original Soul to create a
Legendary in preset1, and actually uses Pluto to upgrade High Card in preset9.
The classifier must never be called for a preset, and saved
`mode`/`preset_id` plus all8fixed-stage grades must survive reload. The explicit
ante transition is a lifecycle fixture, not a claim that all8antes were beaten.

`legacy9` restores an owned0.6preset9fixture and actually uses its saved old
rank9ticket: it must still add a stone playing card, not the new Pluto reward.
The driver observes save requests originating from `cycles.lua` and rejects any
request during a non-idle state, including the transient PLAY_TAROT animation.
This observation does not alter saves, state or the original callback behavior.
