module GangRetaliation

import Codeware.Localization.*


@if(ModuleExists("TheyWillRemember.Factions"))
import TheyWillRemember.Factions.*

@if(ModuleExists("DrugDealer.State"))
import DrugDealer.State.*

@if(ModuleExists("TheyWillRemember.Redemption"))
import TheyWillRemember.Retaliation

@if(ModuleExists("TheyWillRemember.Redemption"))
import TheyWillRemember.Redemption.RedemptionManager

public class GRTWRWatch extends ScriptableSystem {
    private let m_lastThreat: Int32;
    private persistent let m_seenPending: array<Int32>;
    private persistent let m_refusedUntil: array<Int32>;
    private let m_queuedText: String;
    private let m_queuedFirst: Int32;

    public static func Get(gi: GameInstance) -> ref<GRTWRWatch> {
        return GameInstance.GetScriptableSystemsContainer(gi).Get(n"GangRetaliation.GRTWRWatch") as GRTWRWatch;
    }

    private func GameSeconds() -> Int32 {
        return GameTime.GetSeconds(GameInstance.GetTimeSystem(this.GetGameInstance()).GetGameTime());
    }

    private func Ensure() {
        if ArraySize(this.m_seenPending) != 14 {
            ArrayResize(this.m_seenPending, 14);
        }
        if ArraySize(this.m_refusedUntil) != 14 {
            ArrayResize(this.m_refusedUntil, 14);
        }
    }

    private func FindLeader(gangKey: String) -> ref<GRMenuEntry> {
        let data: ref<GRMenuData> = GRMenuData.Get(this.GetGameInstance());
        if !IsDefined(data) {
            return null;
        }
        let best: ref<GRMenuEntry>;
        for entry in data.GetEntries() {
            if Equals(entry.gangKey, gangKey) && !entry.dead && entry.known && entry.rank >= 2 {
                if !IsDefined(best) || entry.rank > best.rank {
                    best = entry;
                }
            }
        }
        return best;
    }

    private func Text(key: String) -> String {
        return LocalizationSystem.GetInstance(this.GetGameInstance()).GetText(key);
    }

    private func Queue(text: String, firstSms: Int32) {
        this.m_queuedText = text;
        this.m_queuedFirst = firstSms;
    }

    private func FlushQueue() {
        if StrLen(this.m_queuedText) == 0 {
            return;
        }
        let det: ref<GRDetection> = GRDetection.Get(this.GetGameInstance());
        if !IsDefined(det) || !det.CanNotify() {
            return;
        }
        let phone: ref<GRPhone> = GRPhone.Get(this.GetGameInstance());
        if IsDefined(phone) {
            phone.SendTWR(this.m_queuedFirst, this.m_queuedText);
        }
        det.Notify(this.m_queuedText);
        this.m_queuedText = "";
    }

    public func Tick() {
        this.FlushQueue();
        let gi: GameInstance = this.GetGameInstance();
        let settings: ref<GRSettings> = GRSettings.Get(gi);
        if !IsDefined(settings) || !settings.enabled {
            return;
        }
        this.Ensure();
        this.CheckThreat();
        this.CheckRedemption();
    }

    private func CheckThreat() {
        let threat: Int32 = GRTWRWatch.TWRThreat(this.GetGameInstance());
        if threat + 1 == this.m_lastThreat {
            return;
        }
        this.m_lastThreat = threat + 1;
        if threat < 0 {
            return;
        }
        this.OnThreat(threat);
    }

    private func OnThreat(index: Int32) -> String {
        let gangKey: String = GRIntegrations.GangOfTWRIndex(index);
        if StrLen(gangKey) == 0 {
            return "";
        }
        let leader: ref<GRMenuEntry> = this.FindLeader(gangKey);
        if !IsDefined(leader) {
            GRLog("TWR: venganza de " + gangKey + " sin Jefe/Teniente que conozca a V, sin SMS");
            return "";
        }
        GRLog("TWR: venganza de " + gangKey + ", avisa " + leader.name);
        let text: String = StrReplace(StrReplace(this.Text("GR-MsgTWRThreat"), "%n", leader.name), "%g", leader.gang);
        this.Queue(text, 16);
        return leader.name;
    }

    private func OnRedemption(index: Int32) -> String {
        let gangKey: String = GRIntegrations.GangOfTWRIndex(index);
        let leader: ref<GRMenuEntry> = StrLen(gangKey) > 0 ? this.FindLeader(gangKey) : null;
        if !IsDefined(leader) {
            return "";
        }
        this.m_refusedUntil[index] = this.GameSeconds() + 3 * 86400;
        GRLog("TWR: V pago el perdon a " + gangKey + ", " + leader.name + " lo rechaza (emboscadas x0.5 por 3 dias)");
        let text: String = StrReplace(StrReplace(this.Text("GR-MsgTWRRefuse"), "%n", leader.name), "%g", leader.gang);
        this.Queue(text, 19);
        return leader.name;
    }

    public func Debug(action: Int32) -> String {
        this.Ensure();
        let candidates: array<Int32>;
        let all: array<Int32> = [0, 1, 2, 3, 4, 5, 6, 11, 12];
        for index in all {
            if IsDefined(this.FindLeader(GRIntegrations.GangOfTWRIndex(index))) {
                ArrayPush(candidates, index);
            }
        }
        if ArraySize(candidates) == 0 {
            return "no gang has a Boss/Lieutenant who knows V";
        }
        let pick: Int32 = candidates[RandRange(0, ArraySize(candidates))];
        let who: String = action == 0 ? this.OnThreat(pick) : this.OnRedemption(pick);
        return (action == 0 ? "TWR threat from " : "TWR payment refused by ") + who + " (" + GRIntegrations.GangOfTWRIndex(pick) + ")";
    }

    private func CheckRedemption() {
        let i: Int32 = 0;
        while i < 14 {
            let pending: Int32 = GRTWRWatch.TWRPending(this.GetGameInstance(), i);
            let seen: Int32 = this.m_seenPending[i];
            this.m_seenPending[i] = pending;
            if pending > 0 && seen == 0 {
                this.OnRedemption(i);
            }
            i += 1;
        }
    }

    public func GetRefusalFactor(gangs: String) -> Float {
        this.Ensure();
        let now: Int32 = this.GameSeconds();
        let list: array<String> = StrSplit(gangs, ",");
        for gang in list {
            let index: Int32 = GRIntegrations.TWRIndexOf(gang);
            if index >= 0 && index < 14 && now < this.m_refusedUntil[index] {
                return 0.5;
            }
        }
        return 1.0;
    }

    @if(ModuleExists("TheyWillRemember.Redemption"))
    private static func TWRThreat(gi: GameInstance) -> Int32 {
        let retaliation: ref<Retaliation> = Retaliation.GetInstance(gi);
        return IsDefined(retaliation) ? retaliation.GetCurrentThreat() : -1;
    }

    @if(!ModuleExists("TheyWillRemember.Redemption"))
    private static func TWRThreat(gi: GameInstance) -> Int32 {
        return -1;
    }

    @if(ModuleExists("TheyWillRemember.Redemption"))
    private static func TWRPending(gi: GameInstance, faction: Int32) -> Int32 {
        let redemption: ref<RedemptionManager> = RedemptionManager.GetInstance(gi);
        return IsDefined(redemption) ? redemption.GetPendingRedemption(faction) : 0;
    }

    @if(!ModuleExists("TheyWillRemember.Redemption"))
    private static func TWRPending(gi: GameInstance, faction: Int32) -> Int32 {
        return 0;
    }
}

public abstract class GRIntegrations {
    public static func SquadRange() -> Float { return 120.0; }

    private static func HasTag(id: EntityID, tag: CName) -> Bool {
        let des: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
        return IsDefined(des) && des.IsTagged(id, tag);
    }

    public static func IsDDSpawn(id: EntityID) -> Bool {
        return GRIntegrations.HasTag(id, n"DrugDealer.EntitySpawn");
    }

    public static func IsDDHostile(id: EntityID) -> Bool {
        return GRIntegrations.HasTag(id, n"DrugDealer.Hostile") || GRIntegrations.HasTag(id, n"DrugDealer.FootEnemy");
    }

    public static func IsDDAlly(id: EntityID) -> Bool {
        return GRIntegrations.IsDDSpawn(id) && !GRIntegrations.IsDDHostile(id);
    }

    private static func NearestGang(tag: CName, player: ref<PlayerPuppet>) -> String {
        let des: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
        if !IsDefined(des) || !IsDefined(player) {
            return "";
        }
        let best: String = "";
        let bestDistance: Float = GRIntegrations.SquadRange();
        let members: array<ref<Entity>> = des.GetTagged(tag);
        for member in members {
            let npc: ref<ScriptedPuppet> = member as ScriptedPuppet;
            if IsDefined(npc) && !GRDetection.IsNeutralized(npc) {
                let gang: String = GRDetection.GetGang(npc);
                let distance: Float = Vector4.Distance(npc.GetWorldPosition(), player.GetWorldPosition());
                if StrLen(gang) > 0 && distance < bestDistance {
                    best = gang;
                    bestDistance = distance;
                }
            }
        }
        return best;
    }

    public static func GetExternalSquad(gi: GameInstance) -> String {
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        let gang: String = GRIntegrations.NearestGang(n"TheyWillRemember.Squad", player);
        if StrLen(gang) > 0 {
            return "TWR|" + gang;
        }
        gang = GRIntegrations.NearestGang(n"DrugDealer.Hostile", player);
        if StrLen(gang) == 0 {
            gang = GRIntegrations.NearestGang(n"DrugDealer.FootEnemy", player);
        }
        if StrLen(gang) > 0 {
            return "DD|" + gang;
        }
        return "";
    }

    public static func IsDDJobActive(gi: GameInstance) -> Bool {
        let des: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
        if !IsDefined(des) {
            return false;
        }
        let tags: array<CName> = [n"DrugDealer.Hostile", n"DrugDealer.FootEnemy"];
        for tag in tags {
            let members: array<ref<Entity>> = des.GetTagged(tag);
            for member in members {
                let npc: ref<ScriptedPuppet> = member as ScriptedPuppet;
                if IsDefined(npc) && !GRDetection.IsNeutralized(npc) {
                    return true;
                }
            }
        }
        return false;
    }

    public static func GetHeatFactor(gi: GameInstance, gangs: String) -> Float {
        let factor: Float = GRIntegrations.TWRFactor(gi, gangs) * GRIntegrations.DDFactor(gi) * GRIntegrations.DDTurfFactor();
        let watch: ref<GRTWRWatch> = GRTWRWatch.Get(gi);
        let refusal: Float = IsDefined(watch) ? watch.GetRefusalFactor(gangs) : 1.0;
        return MinF(factor, 2.0) * refusal;
    }

    public static func GetFleePercent(base: Int32) -> Float {
        return MinF(Cast<Float>(base) + 0.15 * GRIntegrations.DDTerror(), 75.0);
    }

    public static func GetDDTurfState(districtKey: String) -> Int32 {
        return GRIntegrations.DDTurfStateOf(GRIntegrations.TopDistrictType(districtKey));
    }

    public static func GetDDTurfValue(districtKey: String) -> Int32 {
        return GRIntegrations.DDTurfValueOf(GRIntegrations.TopDistrictType(districtKey));
    }

    public static func GetDDLostTurfs(gang: String) -> String {
        let zones: array<gamedataDistrict> = [gamedataDistrict.Watson, gamedataDistrict.SantoDomingo, gamedataDistrict.Badlands,
            gamedataDistrict.Westbrook, gamedataDistrict.Heywood, gamedataDistrict.Pacifica];
        let result: String = "";
        for zone in zones {
            if GRIntegrations.DDTurfStateOf(zone) == 2 && StrContains("," + GRIntegrations.DDTurfGangs(zone) + ",", "," + gang + ",") {
                result += (StrLen(result) > 0 ? ", " : "") + GRIntegrations.ZoneName(zone);
            }
        }
        return result;
    }

    private static func DDTurfGangs(zone: gamedataDistrict) -> String {
        switch zone {
            case gamedataDistrict.Watson: return "Maelstrom,Scavengers,Animals";
            case gamedataDistrict.SantoDomingo: return "SixthStreet,Valentinos";
            case gamedataDistrict.Heywood: return "Valentinos,SixthStreet";
            case gamedataDistrict.Badlands: return "Wraiths";
            case gamedataDistrict.Westbrook: return "TygerClaws";
            case gamedataDistrict.Pacifica: return "VoodooBoys,Animals";
            default: return "";
        }
    }

    private static func ZoneName(zone: gamedataDistrict) -> String {
        switch zone {
            case gamedataDistrict.Watson: return "Watson";
            case gamedataDistrict.SantoDomingo: return "Santo Domingo";
            case gamedataDistrict.Heywood: return "Heywood";
            case gamedataDistrict.Badlands: return "Badlands";
            case gamedataDistrict.Westbrook: return "Westbrook";
            case gamedataDistrict.Pacifica: return "Pacifica";
            default: return "";
        }
    }

    private static func TopDistrictType(districtKey: String) -> gamedataDistrict {
        let records: array<ref<TweakDBRecord>> = TweakDBInterface.GetRecords(n"District");
        for record in records {
            let district: ref<District_Record> = record as District_Record;
            if IsDefined(district) && Equals(district.EnumName(), districtKey) {
                let top: wref<District_Record> = district;
                while IsDefined(top.ParentDistrict()) {
                    top = top.ParentDistrict();
                }
                return top.Type();
            }
        }
        return gamedataDistrict.Invalid;
    }

    public static func TWRIndexOf(gang: String) -> Int32 {
        switch gang {
            case "Maelstrom": return 0;
            case "TygerClaws": return 1;
            case "Animals": return 2;
            case "Scavengers": return 3;
            case "Valentinos": return 4;
            case "VoodooBoys": return 5;
            case "SixthStreet": return 6;
            case "Wraiths": return 11;
            case "Barghest": return 12;
            default: return -1;
        }
    }

    public static func GangOfTWRIndex(index: Int32) -> String {
        switch index {
            case 0: return "Maelstrom";
            case 1: return "TygerClaws";
            case 2: return "Animals";
            case 3: return "Scavengers";
            case 4: return "Valentinos";
            case 5: return "VoodooBoys";
            case 6: return "SixthStreet";
            case 11: return "Wraiths";
            case 12: return "Barghest";
            default: return "";
        }
    }

    @if(ModuleExists("TheyWillRemember.Factions"))
    private static func TWRFactor(gi: GameInstance, gangs: String) -> Float {
        let attitudes: ref<AttitudeManager> = AttitudeManager.GetInstance(gi);
        let kills: ref<KillCounts> = KillCounts.GetInstance(gi);
        if !IsDefined(attitudes) || !IsDefined(kills) {
            return 1.0;
        }
        let best: Float = 1.0;
        let list: array<String> = StrSplit(gangs, ",");
        for gang in list {
            let index: Int32 = GRIntegrations.TWRIndexOf(gang);
            if index >= 0 {
                let k: Float = Cast<Float>(kills.GetKillCountByIndex(index));
                let f: Float = 1.0 + 0.5 * k / (k + 20.0);
                if attitudes.IsFactionHostileByIndex(index) {
                    f += 0.5;
                }
                best = MaxF(best, f);
            }
        }
        return best;
    }

    @if(!ModuleExists("TheyWillRemember.Factions"))
    private static func TWRFactor(gi: GameInstance, gangs: String) -> Float {
        return 1.0;
    }

    @if(ModuleExists("DrugDealer.State"))
    private static func DDFactor(gi: GameInstance) -> Float {
        let state: ref<PlayerStateSystem> = PlayerStateSystem.Get();
        if !IsDefined(state) {
            return 1.0;
        }
        return 1.0 + 0.04 * Cast<Float>(EnumInt(state.GetRank()));
    }

    @if(!ModuleExists("DrugDealer.State"))
    private static func DDFactor(gi: GameInstance) -> Float {
        return 1.0;
    }

    @if(ModuleExists("DrugDealer.State"))
    private static func DDTurfFactor() -> Float {
        let turfs: ref<TurfControlSystem> = TurfControlSystem.Get();
        if !IsDefined(turfs) {
            return 1.0;
        }
        let turf: wref<Turf> = turfs.GetTurf(GetCurrentTurf());
        if !IsDefined(turf) {
            return 1.0;
        }
        if turf.IsControlled() {
            return 1.5;
        }
        if turf.IsContested() {
            return 1.25;
        }
        return 1.0;
    }

    @if(!ModuleExists("DrugDealer.State"))
    private static func DDTurfFactor() -> Float {
        return 1.0;
    }

    @if(ModuleExists("DrugDealer.State"))
    private static func DDTerror() -> Float {
        let terror: ref<TerrorSystem> = TerrorSystem.Get();
        return IsDefined(terror) ? terror.GetTerrorValue() : 0.0;
    }

    @if(!ModuleExists("DrugDealer.State"))
    private static func DDTerror() -> Float {
        return 0.0;
    }

    @if(ModuleExists("DrugDealer.State"))
    private static func DDTurfOf(zone: gamedataDistrict) -> wref<Turf> {
        let turfs: ref<TurfControlSystem> = TurfControlSystem.Get();
        if !IsDefined(turfs) {
            return null;
        }
        switch zone {
            case gamedataDistrict.Watson: return turfs.GetTurf(TurfLocation.Watson);
            case gamedataDistrict.SantoDomingo: return turfs.GetTurf(TurfLocation.SantoDomingo);
            case gamedataDistrict.Heywood: return turfs.GetTurf(TurfLocation.Heywood);
            case gamedataDistrict.Badlands: return turfs.GetTurf(TurfLocation.Badlands);
            case gamedataDistrict.Westbrook: return turfs.GetTurf(TurfLocation.Westbrook);
            case gamedataDistrict.Pacifica: return turfs.GetTurf(TurfLocation.Pacifica);
            default: return null;
        }
    }

    @if(ModuleExists("DrugDealer.State"))
    private static func DDTurfStateOf(zone: gamedataDistrict) -> Int32 {
        let turf: wref<Turf> = GRIntegrations.DDTurfOf(zone);
        if !IsDefined(turf) {
            return -1;
        }
        return EnumInt(turf.control);
    }

    @if(!ModuleExists("DrugDealer.State"))
    private static func DDTurfStateOf(zone: gamedataDistrict) -> Int32 {
        return -1;
    }

    @if(ModuleExists("DrugDealer.State"))
    private static func DDTurfValueOf(zone: gamedataDistrict) -> Int32 {
        let turf: wref<Turf> = GRIntegrations.DDTurfOf(zone);
        return IsDefined(turf) ? turf.controlValue : 0;
    }

    @if(!ModuleExists("DrugDealer.State"))
    private static func DDTurfValueOf(zone: gamedataDistrict) -> Int32 {
        return 0;
    }


    @if(ModuleExists("DrugDealer.State"))
    public static func GetDDDebugInfo(baseFlee: Int32) -> String {
        let info: String = "DD terror " + IntToString(Cast<Int32>(GRIntegrations.DDTerror()))
            + " -> flee " + IntToString(Cast<Int32>(GRIntegrations.GetFleePercent(baseFlee))) + "% (base " + IntToString(baseFlee) + "%)";
        let turfs: ref<TurfControlSystem> = TurfControlSystem.Get();
        let location: TurfLocation = GetCurrentTurf();
        let turf: wref<Turf> = IsDefined(turfs) ? turfs.GetTurf(location) : null;
        if !IsDefined(turf) {
            return info + " | zone: none";
        }
        let state: String = turf.IsControlled() ? "CONTROLLED by V" : (turf.IsContested() ? "contested" : "surrendered");
        return info + " | zone " + EnumValueToString("TurfLocation", Cast<Int64>(EnumInt(location))) + ": " + state
            + " " + IntToString(turf.controlValue) + "% (ambush x" + FloatToStringPrec(GRIntegrations.DDTurfFactor(), 2) + ")";
    }

    @if(!ModuleExists("DrugDealer.State"))
    public static func GetDDDebugInfo(baseFlee: Int32) -> String {
        return "Drug Dealer not installed";
    }

    @if(ModuleExists("DrugDealer.State"))
    private static func DebugSetTurf(turfs: ref<TurfControlSystem>, turf: wref<Turf>, value: Int32, control: TurfControl) {
        turf.controlValue = value;
        turf.control = control;
        turf.decayHoursAccumulated = 0;
        turf.lastDecayTimeSeconds = GetGameInstance().GetGameTime().seconds;
        turfs.RegisterMappins();
    }

    @if(ModuleExists("DrugDealer.State"))
    public static func DebugCaptureRandomTurf() -> String {
        let turfs: ref<TurfControlSystem> = TurfControlSystem.Get();
        if !IsDefined(turfs) {
            return "DD turf system not ready";
        }
        let all: array<TurfLocation> = [TurfLocation.Watson, TurfLocation.SantoDomingo, TurfLocation.Badlands,
            TurfLocation.Westbrook, TurfLocation.Heywood, TurfLocation.Pacifica];
        let free: array<TurfLocation>;
        for location in all {
            let turf: wref<Turf> = turfs.GetTurf(location);
            if IsDefined(turf) && !turf.IsControlled() {
                ArrayPush(free, location);
            }
        }
        if ArraySize(free) == 0 {
            return "every DD zone is already V's";
        }
        let pick: TurfLocation = free[RandRange(0, ArraySize(free))];
        GRIntegrations.DebugSetTurf(turfs, turfs.GetTurf(pick), 85, TurfControl.Controlled);
        return "DD zone captured: " + EnumValueToString("TurfLocation", Cast<Int64>(EnumInt(pick)));
    }

    @if(ModuleExists("DrugDealer.State"))
    public static func DebugContestCurrentTurf() -> String {
        let turfs: ref<TurfControlSystem> = TurfControlSystem.Get();
        let location: TurfLocation = GetCurrentTurf();
        let turf: wref<Turf> = IsDefined(turfs) ? turfs.GetTurf(location) : null;
        if !IsDefined(turf) {
            return "V is not in a DD zone";
        }
        GRIntegrations.DebugSetTurf(turfs, turf, 40, TurfControl.Constested);
        return "DD zone contested: " + EnumValueToString("TurfLocation", Cast<Int64>(EnumInt(location)));
    }

    @if(ModuleExists("DrugDealer.State"))
    public static func DebugSurrenderAllTurfs() -> String {
        let turfs: ref<TurfControlSystem> = TurfControlSystem.Get();
        if !IsDefined(turfs) {
            return "DD turf system not ready";
        }
        let all: array<TurfLocation> = [TurfLocation.Watson, TurfLocation.SantoDomingo, TurfLocation.Badlands,
            TurfLocation.Westbrook, TurfLocation.Heywood, TurfLocation.Pacifica, TurfLocation.CityCenter];
        for location in all {
            turfs.SurrenderTurf(location);
        }
        return "DD zones surrendered";
    }

    @if(ModuleExists("DrugDealer.State"))
    public static func DebugAddTerror() -> String {
        let terror: ref<TerrorSystem> = TerrorSystem.Get();
        if !IsDefined(terror) {
            return "DD terror system not ready";
        }
        terror.ModifyTerrorValue(25.0);
        terror.StartTickPolling();
        return "DD terror now " + IntToString(Cast<Int32>(terror.GetTerrorValue()));
    }

    @if(!ModuleExists("DrugDealer.State"))
    public static func DebugCaptureRandomTurf() -> String { return "Drug Dealer not installed"; }

    @if(!ModuleExists("DrugDealer.State"))
    public static func DebugContestCurrentTurf() -> String { return "Drug Dealer not installed"; }

    @if(!ModuleExists("DrugDealer.State"))
    public static func DebugSurrenderAllTurfs() -> String { return "Drug Dealer not installed"; }

    @if(!ModuleExists("DrugDealer.State"))
    public static func DebugAddTerror() -> String { return "Drug Dealer not installed"; }
}
