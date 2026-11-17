# Changelog (map filter / stronghold / intel work)

Changes on top of NovaAntonsito's Gang Retaliation 1.4.6.

## 1.4.8

- Map filter checkbox renamed to **GANG RETALIATION** (English and Spanish). It now controls both stronghold and intel markers.
- Intel markers (knocked-out gang members you can extract data from) no longer use the Cyberpunk "cyberpsycho" marker, so no skull icon. They use the same hidden marker variant as strongholds and the `codex_glossary` icon.
- Hovering an intel marker on the map shows "<gang> intel target" and a short description (English and Spanish).
- Intel markers are restored after loading a save (the extract prompt was already saved on the NPC, the map marker was not).
- Log messages and `intel.yaml` comments updated to match.

## 1.4.7

- Fixed the crash when cycling map filters with Q/E (cause: the filter code called `GetScriptData()` on marker widgets the game had already freed).
- Strongholds use their own marker variant (`CPO_PingDoorVariant`), so the game filters them itself; the old hide/show/replay code was removed. Compatible with Map Icons Framework.
- Stronghold map tooltip: title "Stronghold (<gang>)", description, and a gang banner image at the bottom (new `GangRetaliationBanners.archive`).
- New setting "Stronghold map banner" (on by default) to show or hide the banner.
