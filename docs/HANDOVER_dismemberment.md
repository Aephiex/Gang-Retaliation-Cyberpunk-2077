# Handover: dismemberment / "beheaded Nemesis came back" investigation

Written 2026-11-17 for whoever continues this (VS Code Claude, Nova, or the user). Everything below comes from reading code and mod sources.

**Update 2026-11-17 (later the same day):** the user reported a clean repro (dev-mode spawn all Nemesis, kill all with decapitation: none reported "For good this time", some returned on Day+1). The user is now a co-author on this mod and asked to go ahead and fix this directly rather than wait. Implemented the fix described below; not yet confirmed in game by the user. Status: **deployed to the game folder for testing, not yet verified, not released.**

## 0. The fix implemented

- `Spawner.reds`: added `m_headRemovedIds: array<EntityID>` and a public `MarkHeadRemoved(id: EntityID)` method on `GRSpawner`. `RecordDeath` now checks this list before/after `DeathKind` and forces `kind = "confirmed"` (bypassing both the limb-count check and the cause-downgrade) whenever the NPC's id is in the list. The id is consumed (removed) once the death is recorded. `DeathKind` also now logs the flesh/cyber limb counts via `GRLog` on every death for diagnosis.
- `init.lua`: added `getSpawner()` and an `Observe("gameDismembermentComponent", "DoDismemberment", ...)` hook (wrapped in `pcall`, degrades to inactive + prints a message if the class/method name is wrong). It logs `bodyPart`/`woundType`/`strength`/`isCritical` via `debugLog` (needs the mod's debugLog setting on to see it), and if `tostring(bodyPart):lower()` contains `"head"`, it calls `spawner:MarkHeadRemoved(entity:GetEntityID())`.
- **Still unverified:** the real `bodyPart` value/type coming out of CET for a head dismemberment (this was always the open question in section 4 below — the `:lower():find("head")` check is a guess at the format, not a confirmed match). If the hook never matches, `debugLog` output (enable the setting) will show what `bodyPart` actually looks like so the match string can be corrected.
- Compile-checked clean with `build/build_release.py` (pre-flight; version bump not done since this isn't a release yet). Deployed Spawner.reds + init.lua into the game folder for testing. Not yet copied into `Distribution/` or built into a release zip.
- **Verified in game 2026-11-17** via the `scripting.log`: every `HEAD (1)` dismemberment logged by the new hook was immediately followed by "Decapitacion detectada"; no arm/leg/body/hole dismemberment ever matched. Still need a decapitation on an actual tracked Nemesis (not just a random enemy) to see the `RecordDeath`/"For good this time" path fire end to end.
- **Deliberate design call, not a bug:** `headRemoved` forces `kind = "confirmed"` unconditionally in `RecordDeath`, even overriding a `"knockout"` result from `DeathKind` (i.e. even if some other mod, e.g. one that lets NPCs survive dismemberment, keeps the NPC technically alive/unconscious after losing their head). The user's call: "head removed is dead dead" — no exceptions, regardless of what other mods do to keep the body moving. Do not add a guard that skips the override for a `"knockout"` case; that was considered and explicitly rejected.

## 1. The problem (original)

The user saw Nemesis that had been "truly killed" (beheaded) come back later. The mod's intent is that a confirmed kill is permanent. The user also wants to discuss new rules about dismemberment (section 5).

## 2. How death is classified today

All in `r6/scripts/GangRetaliation/Spawner.reds`:

- `RecordDeath(nemesisId, npc)` (~line 452) calls `DeathKind`, then looks up the cause with `TakeLastHit`.
  - If the cause is not `"v"` but `KilledByPlayer(npc)` is true (grapple, ForceKill/Unconscious instigator, vehicle V hit), the cause is promoted to `"v"`.
  - **If kind is `"confirmed"` but cause is not `"v"`, kind is downgraded to `"normal"`.**
- `DeathKind` (~line 495) returns, in order:
  1. `"knockout"`: NPC not dead but unconscious or defeated.
  2. `"confirmed"`: the NPC id is in `m_finisherIds` (set by `RecordPlayerHit`: a headshot flag or an explosion by V; cleared by `RecordHitBy` whenever the last hit source is not V).
  3. `"confirmed"`: `GetDismembermentComponent().GetDismemberedLimbCount()` has `fleshDismemberments + cyberDismemberments > 0`.
  4. otherwise `"normal"`.
- Lua side: `hierarchy.lua` `resolveDeath` decides whether the Nemesis returns, and `revive` brings it back "rebuilt with chrome" (renown +3, traits, `CyberLooks.apply`). The return chance is the `returnChancePercent` setting (default 40). `"confirmed"` means no return chance.

Injuries are not tracked per body part anywhere. `n.health` is stored when a Nemesis escapes but is not used when spawning. "Wounded" exists only as the message `GR-MsgEscaped` and the origin label `GR-Origin-escaped`.

## 3. Suspects for the "beheaded but came back" cases

None confirmed. Ranked by how plausible they look from the code:

1. **The cause downgrade.** A beheading by something that is not recorded as V (companion, explosion chain, status effect, a hit whose source was not tagged) turns "confirmed" into "normal", which is eligible for the 40% return roll.
2. **Head removal may not be counted by `GetDismemberedLimbCount()`.** It may count only limbs, or the head may be counted under another field. Not checked.
3. **The headshot flag only covers V's own flagged hits.** A headshot from another source, or one that did not pass through `RecordPlayerHit`, never reaches `m_finisherIds`.
4. **Timing:** the dismember count might be read before the dismemberment is applied, or after the component is torn down (`IsDefined` guard returns "normal").
5. **Gore Runner / dismemberment settings.** See section 4: if a gore mod lets wounded NPCs be dismembered after the fact, ordering with `RecordDeath` could differ from vanilla.

## 4. Hook options for telling head from limb

- The game class is `gameDismembermentComponent`. In CET `Reflection.GetClass("DismembermentComponent")` returns nil; use the RTTI name.
- Method seen in the Gore Runner mod: `DoDismemberment(bodyPart, woundType, strength, isCritical)`. Gore Runner branches on `bodyPart` ("head", body, left/right arm/leg) and `woundType` ("clean"/"coarse").
- **Unverified:** the real argument types and enum values. A quick CET probe would settle it:
  ```lua
  Observe("gameDismembermentComponent", "DoDismemberment", function(self, bodyPart, woundType, strength, isCritical)
      print("DISMEMBER", tostring(bodyPart), tostring(woundType), tostring(strength), tostring(isCritical))
  end)
  ```
  (If `Observe` rejects the class name, try the redscript-visible name `DismembermentComponent` or wrap the method in redscript on the vanilla class; remember annotations only work on vanilla classes.)
- Gore Runner sets `AIGeneralSettings.E3_AllowDismembermentOnWounded = true`, which is probably what allows dismembering wounded NPCs (unconfirmed).
- Gore Runner is a blood/gore visuals mod, not part of our stack. Only its code was read, for hints.

## 5. Proposed rules (to discuss with Nova, nothing decided)

- Dismembered but alive Nemesis return "rebuilt with chrome" (the existing `revive` look).
- Dead with missing limbs: a percentage chance to return enhanced.
- Head removal stays permanent (the true kill).

Open design questions: where the percentages live (new Mod Settings entries?), whether limb count scales the chance, and whether "knockout" plus dismemberment should differ from a clean kill.

## 6. Suggested next steps, in order

1. **Add diagnostic logging first** (already listed in NOTES.md section 5): in `RecordDeath`, log the `DeathKind` result, the limb counts (flesh and cyber), whether the id was in `m_finisherIds`, and the cause before and after the downgrade. Ship it in a test build so the user can get a "beheaded but came back" case with a log line attached.
2. Run the CET probe above on a few kills (headshot, arm, leg, explosion) to learn the real `bodyPart` / `woundType` values and whether head removal fires `DoDismemberment` at all.
3. Compare the log with the probe output to pick which suspect in section 3 is real.
4. Only then decide the fix, and only after the user's talk with Nova settles the rules in section 5.

Build and compile-check with `build/build_release.py` (see NOTES.md section 2). Remember to update `CHANGELOG.md`, the version in the script and README together.

## 7. Related, but a separate topic

Stashed weapons vanishing from the Arsenal is a different bug with the same "wait for Nova" status. See NOTES.md section 5.

## 8. Where to look

- `r6/scripts/GangRetaliation/Spawner.reds`: `RecordDeath`, `KilledByPlayer`, `DeathKind`, `RecordHitBy`, `RecordPlayerHit`, `GetDeathKind` (~line 2225).
- Lua: `hierarchy.lua` (`resolveDeath`, `revive`), `CyberLooks.apply`, the `returnChancePercent` setting.
- `NOTES.md` sections 5, 6 and 8 (and `NOTES.es.md`).
