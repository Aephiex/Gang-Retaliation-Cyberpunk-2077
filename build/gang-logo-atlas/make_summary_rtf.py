"""Write GR-stronghold-changes-summary.rtf (the summary of the map filter / stronghold work)."""
BS = chr(92)  # backslash


def esc(s):
    out = []
    for ch in s:
        o = ord(ch)
        if ch in (BS, "{", "}"):
            out.append(BS + ch)
        elif o > 127:
            out.append(BS + "u%d?" % (o if o < 32768 else o - 65536))
        else:
            out.append(ch)
    return "".join(out)


def cw(word):
    """RTF control word followed by a space."""
    return BS + word + " "


body = []


def h1(t):
    body.append("{" + cw("pard") + cw("sa200") + cw("b") + cw("fs36") + esc(t) + cw("b0") + cw("par") + "}")


def h2(t):
    body.append("{" + cw("pard") + cw("sb240") + cw("sa80") + cw("b") + cw("fs28") + esc(t) + cw("b0") + cw("par") + "}")


def p(t):
    body.append("{" + cw("pard") + cw("sa120") + cw("fs22") + esc(t) + cw("par") + "}")


def bl(t, bold=None):
    txt = (cw("b") + esc(bold) + cw("b0") if bold else "") + esc(t)
    body.append("{" + cw("pard") + cw("fi-280") + cw("li560") + cw("sa60") + cw("fs22") + cw("bullet") + cw("tab") + txt + cw("par") + "}")


h1("Gang Retaliation 1.4.5 / 1.4.6 " + chr(0x2013) + " map filter crash and stronghold work: summary")
h2("The problem")
p("Players crashed when cycling map filters with Q/E on Gang Retaliation 1.4.5. It was reproduced here, and the Advanced Crash Reporter pointed at GRReplayMapFilter.")
h2("The cause")
p("After every filter change the mod looped over all the map's marker widgets and called GetScriptData() on each marker. Some of those markers had already been freed by the game, so the native call faulted. Marmur Bank was not needed to reproduce it.")
h2("What we changed")
bl(" Cached the marker data when the icon is bound, so the filter code never touches a freed marker. This stopped the crash but left bugs, such as the checkbox doing nothing when only Strongholds was checked.", "First fix (Stronghold.reds):")
bl(" Replaying every marker crashed with Icon Framework on, and re-running the quick-filter handler only reloaded the filter list.", "Failed experiments:")
bl(" Following Icon Framework's approach, strongholds now use their own marker variant (CPO_PingDoorVariant), so the game filters them itself. All the hide, show and replay code was deleted, which removes the crash path.", "Final design:")
bl(" New variant, marker definition and filter group, with the group added to the zoom-level lists. Nothing checked shows strongholds with everything else; Strongholds only shows just them; Strongholds plus another category shows both, and unchecking either hides just that one.", "Data (intel.yaml):")
bl(" The world marker keeps the profile the game used for outposts. The tooltip has the title \"Stronghold (gang)\", the description \"Clear the stronghold to scatter and weaken the gang.\" (with a Spanish version), and a 680 x 288 gang banner at the bottom, built the way Virtual Atelier does its tooltip picture.", "In-world marker and tooltip (Stronghold.reds, Localization.reds):")
bl(" Nine 1360 x 575 banners were made, laid out as a 2048 x 1024 half-size sheet, imported as a texture and built into gangretaliation" + BS + "gui" + BS + "stronghold_banners.inkatlas in WolvenKit.", "Banners (new archive):")
bl(" \"Stronghold map banner\", on by default, requested by Nova, with English and Spanish text (Settings.reds, Localization.reds).", "Setting:")
h2("Things found along the way")
bl(" WolvenKit's install wrote the banner archive over the mod's own GangRetaliation.archive, removing the NEMESIS menu, journal and localization files. The original was restored and the banners moved to GangRetaliationBanners.archive.", "Overwritten archive:")
bl(" Its staging copy was still stock 1.4.6, so it was updated to match.", "Vortex was stale:")
h2("Files")
bl(" Gang Retaliation 1.4.6-test (stronghold filter + banner).zip", "Package:")
bl(" GR-1.4.6-stronghold-filter-and-banner.diff, against stock 1.4.6.", "Diff:")
bl(" GR-backup-before-test-install, GR-1.4.5-mapfilter-backup and GR-1.4.6-stock-backup.", "Backups:")
h2("Verified in game")
bl(" Icons work with Icon Framework enabled.", "Icon Framework:")
bl(" All nine gang banners were checked.", "Banners:")
bl(" Strongholds filter correctly, the tooltip and banner toggle work, and Q/E cycling no longer crashes.", "Filter, tooltip and toggle:")
h2("Not verified")
bl(" The icons on NPCs after downloading intel now follow the game's Jobs checkbox instead of being forced visible. This was not re-checked after the change.", "Intel icons on NPCs:")

head = "{" + BS + "rtf1" + BS + "ansi" + BS + "ansicpg1252" + BS + "deff0{" + BS + "fonttbl{" + BS + "f0" + BS + "fswiss Calibri;}}\n" + BS + "viewkind4" + BS + "uc1 " + BS + "f0 \n"
rtf = head + "\n".join(body) + "\n}"
path = r"H:\OneDrive\Coding\Workspaces\GR-stronghold-changes-summary.rtf"
with open(path, "w", encoding="ascii") as f:
    f.write(rtf)
print(len(rtf), "chars written")
