# Third-party notices

## Calendar reference

The committed `calendar_data.lua` contains a generated table based on **lunar-python1.4.8** by6tail, MIT licensed. Its complete MIT notice is embedded in that file. Upstream: https://github.com/6tail/lunar-python . Pinned source archive SHA256: `3aa11cc73c25e70ddf0ba5bdac7398c03acc9491a3aa512a91c9642973b669d6`.

The reference package is installed only for development; the game uses the included offline table and Lua implementation. `requirements-dev.txt` pins its version and source hash.

## Local tooling and game integration

Sharp is a development-only dependency resolved by `package.json`, under its upstream license. Balatro, Lovely and Steamodded are user-installed dependencies, not bundled here. Native callback tests read a user's locally generated Lovely dumps; these dumps and the game binaries must not be published.

No blanket open-source license for the user's original mod code or artwork is added by this synchronization. Rights to third-party projects remain with their owners.
