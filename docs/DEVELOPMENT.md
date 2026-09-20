# Development / 开发与复验

The game only needs `mod/TenYearsNineGrid`. Python and Node are development tools, not game dependencies. Proprietary Balatro binaries, generated engine dumps and save files are intentionally not in Git.

## Lua contracts (Windows)

Use the `lua51.dll` from your own Balatro installation. Set its absolute path explicitly if your Steam library differs from the optional local default:

```powershell
$env:BALATRO_LUA_DLL = 'D:/SteamLibrary/steamapps/common/Balatro/lua51.dll'
python -S -B tests/run_lua_tests.py test_presets.lua
python -S -B tests/run_lua_tests.py test_birth_ui.lua
python -S -B tests/run_lua_tests.py test_pattern_start.lua
python -S -B tests/run_lua_tests.py test_pattern_jokers.lua
python -S -B tests/run_lua_tests.py test_patterns.lua
```

`TYG_TEST_MOD_DIR` can point the same tests at an unpacked package or installed copy. Tests use the native Lua runtime but are not a graphical playthrough.

## Calendar reference and frozen data

```powershell
python -m pip install --target vendor --no-deps --require-hashes -r requirements-dev.txt
python -m pip download --dest vendor/_sources --no-deps --no-binary=:all: --require-hashes -r requirements-dev.txt
python -S -B tools/generate_calendar_data.py --check
python -S -B -m unittest discover -s tests -p test_calendar.py -v
python -S -B -m unittest discover -s tests -p test_pattern_coverage.py -v
python -S -B -m unittest discover -s tests -p test_pattern_exhaustive.py -v
```

The generator verifies/embeds the pinned upstream archive hash and license. These tests assess consistency and coverage, not the semantic truth of fortune-telling. See `KNOWN-ISSUES.md`.

## Artwork

```powershell
npm install --ignore-scripts
npm run test:assets
```

Runtime atlases at1x/2x are committed. The selected high-resolution originals and generation prompts, when included, live in `assets/concept`. `npm run build:assets` mechanically exports these with nearest-neighbor sampling; it does not generate new art. Original/selected-version provenance is in `docs/ASSETS.md`.

## Actual-engine QA

See `tools/runtime_qa/README.md`. The launcher requires your own game and Steamodded and confines generated data to `qa-runs/`. It disables Steam for its own process, uses synthetic fixtures, and never controls a user's already-running game. Do not commit that folder: it contains proprietary engine dumps and test saves.

## Packaging and conservative local upgrades

`tools/package.ps1` packages the27allowed runtime files, checks unpacked hashes and runs contracts. It also needs local Lovely dumps for the native callback probes. First install: manually copy `mod/TenYearsNineGrid` into the user's Mods directory while the game is closed.

For an upgrade, `tools/install.ps1 -PackageDir <verified-new-mod> -PreviousPackageDir <verified-old-mod>` requires the previous verified runtime as a baseline. It refuses a running game or externally modified files, backs up the old folder, and verifies copied hashes. Never substitute a personal-save path for either argument.
