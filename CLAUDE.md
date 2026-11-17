# Gang Retaliation (our changes) - instructions for AI assistants

Read `NOTES.md` first: it holds the context, design decisions, verified facts, open items and pitfalls.
Then `README.md` (layout) and `CHANGELOG.md`.

- This folder is the source of truth for the mod's in-game files (`archive/`, `r6/`, `bin/`). The author is NovaAntonsito; do not publish or share anything without the maintainer's go-ahead.
- Test by copying changed files into `H:\SteamLibrary\steamapps\common\Cyberpunk 2077` at the same relative paths. Never overwrite `bin/.../GangRetaliation/modules/names.lua` there (it is the Expanded Names mod's file). Vortex updates overwrite edited game files, so keep edits here too.
- Release with `python -I build/build_release.py` after bumping `VERSION`, `CHANGELOG.md` and `README.md`; never hand-build the zip.
- After changing scripts, check `r6/logs/redscript_rCURRENT.log` in the game folder. Mark new findings in `NOTES.md` as verified / from code / idea.
- Log text from the mod (`GRLog`) is in Spanish; player-facing text is localized in `Localization.reds` (English and Spanish).
