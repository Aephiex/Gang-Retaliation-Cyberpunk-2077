module GangRetaliation

public class GRRewards extends ScriptableSystem {
    private persistent let m_ids: array<ItemID>;
    private persistent let m_nemesisIds: array<Int32>;
    private persistent let m_given: array<Int32>;
    private persistent let m_levels: array<Int32>;
    private persistent let m_stashed: array<Int32>;
    private persistent let m_stElement: array<Int32>;
    private persistent let m_stBonus: array<Float>;
    private persistent let m_stDamage: array<Float>;
    private persistent let m_stQuality: array<Int32>;
    private persistent let m_stPlus: array<Int32>;

    private let m_nameIds: array<Int32>;
    private let m_names: array<String>;

    private let m_pvElement: Int32;
    private let m_pvBonus: Int32;
    private let m_fusedIndex: Int32;

    private let m_oIds: array<ItemID>;
    private let m_oNemesis: array<Int32>;
    private let m_oGangs: array<String>;
    private let m_oElements: array<Int32>;
    private let m_oBonus: array<Int32>;
    private let m_oBonusF: array<Float>;
    private let m_oLevels: array<Int32>;
    private let m_oDamage: array<Float>;
    private let m_oTiers: array<String>;
    private let m_oEquipped: array<Bool>;
    private let m_oStashed: array<Bool>;

    public static func Get(gi: GameInstance) -> ref<GRRewards> {
        return GameInstance.GetScriptableSystemsContainer(gi).Get(n"GangRetaliation.GRRewards") as GRRewards;
    }

    public func GetRegisteredCount() -> Int32 {
        return ArraySize(this.m_ids);
    }

    private func OnRestored(saveVersion: Int32, gameVersion: Int32) {
        GRLog("Recompensas: partida restaurada, " + IntToString(ArraySize(this.m_ids)) + " arma(s) registrada(s), "
            + IntToString(ArraySize(this.m_given)) + " Jefe(s) que ya dieron arma");
    }

    public func ClearNames() -> Void {
        ArrayClear(this.m_nameIds);
        ArrayClear(this.m_names);
    }

    public func AddName(nemesisId: Int32, name: String) -> Void {
        let i: Int32 = 0;
        while i < ArraySize(this.m_nameIds) {
            if this.m_nameIds[i] == nemesisId && i < ArraySize(this.m_names) {
                this.m_names[i] = name;
                return;
            }
            i += 1;
        }
        if ArraySize(this.m_nameIds) != ArraySize(this.m_names) {
            this.ClearNames();
        }
        ArrayPush(this.m_nameIds, nemesisId);
        ArrayPush(this.m_names, name);
    }

    public func HasGiven(nemesisId: Int32) -> Bool {
        return ArrayContains(this.m_given, nemesisId);
    }

    public func GetCustomName(id: ItemID) -> String {
        let count: Int32 = ArraySize(this.m_ids);
        let i: Int32 = 0;
        while i < count {
            if this.m_ids[i] == id {
                if i < ArraySize(this.m_nemesisIds) {
                    return this.NameForNemesis(this.m_nemesisIds[i], id);
                }
                return "";
            }
            i += 1;
        }
        return "";
    }

    public func GiveBossWeapon(nemesisId: Int32, gang: String, traitsCsv: String, escapes: Int32, force: Bool) -> String {
        if nemesisId <= 0 {
            return "";
        }
        if !force && ArrayContains(this.m_given, nemesisId) {
            return "";
        }
        let recordID: TweakDBID = this.WeaponForGang(gang);
        if !TDBID.IsValid(recordID) {
            GRLog("Recompensas: arma de Jefe #" + IntToString(nemesisId) + " sin arma para la banda \"" + gang + "\"");
            return "";
        }
        let gi: GameInstance = this.GetGameInstance();
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        if !IsDefined(player) {
            GRLog("Recompensas: arma de Jefe #" + IntToString(nemesisId) + " cancelada, no hay jugador");
            return "";
        }
        let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(gi);
        let stats: ref<StatsSystem> = GameInstance.GetStatsSystem(gi);
        let id: ItemID = ItemID.FromTDBID(recordID);
        let given: Bool = ts.GiveItem(player, id, 1);
        let data: wref<gameItemData> = ts.GetItemData(player, id);
        if !IsDefined(data) {
            GRLog("Recompensas: arma de Jefe #" + IntToString(nemesisId) + " cancelada, GiveItem=" + this.BoolText(given)
                + " pero no hay itemData para " + this.DescribeId(id));
            return "";
        }
        let objID: StatsObjectID = data.GetStatsObjectID();

        let element: Int32 = this.RollElement(nemesisId, traitsCsv);
        let pct: Int32 = this.RollBonus(nemesisId, escapes);
        let bonusPct: Float = Cast<Float>(pct);

        let ok: Bool = stats.AddSavedModifier(objID, RPGManager.CreateStatModifier(gamedataStatType.IsItemIconic, gameStatModifierType.Additive, 1.0));

        let playerLevel: Float = stats.GetStatValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatType.PowerLevel);
        stats.RemoveAllModifiers(objID, gamedataStatType.PowerLevel, true);
        if !stats.AddSavedModifier(objID, RPGManager.CreateStatModifier(gamedataStatType.PowerLevel, gameStatModifierType.Additive, playerLevel)) {
            ok = false;
        }

        let baseName: String = this.BaseDamageName(data, stats);
        let baseValue: Float = this.BaseDamage(data, stats);
        let bonus: Float = baseValue * bonusPct / 100.0;
        if !stats.AddSavedModifier(objID, RPGManager.CreateStatModifier(this.ElementStat(element), gameStatModifierType.Additive, bonus)) {
            ok = false;
        }

        if !stats.AddSavedModifier(objID, RPGManager.CreateStatModifier(this.ElementRateStat(element), gameStatModifierType.Additive, bonusPct)) {
            ok = false;
        }

        this.SyncLists();
        ArrayPush(this.m_ids, id);
        ArrayPush(this.m_nemesisIds, nemesisId);
        ArrayPush(this.m_levels, 1);
        this.PushStashEntry();
        if !ArrayContains(this.m_given, nemesisId) {
            ArrayPush(this.m_given, nemesisId);
        }

        let name: String = this.GetCustomName(id);
        if StrLen(name) == 0 {
            name = this.WeaponBaseName(id);
        }
        GRLog("Recompensas: arma de Jefe #" + IntToString(nemesisId) + " (" + gang + ") \"" + name + "\" " + this.DescribeId(id)
            + " elemento=" + this.ElementName(element) + " bono=" + IntToString(pct) + "% (+" + FloatToStringPrec(bonus, 2) + " sobre " + baseName + "="
            + FloatToStringPrec(baseValue, 2) + ") " + this.ElementRateName(element) + "=+" + IntToString(pct) + " escapes=" + IntToString(escapes)
            + " rasgos=\"" + traitsCsv + "\" forzada=" + this.BoolText(force) + " modificadores OK=" + this.BoolText(ok)
            + " | DESPUES " + this.DescribeStats(data, stats));
        return name;
    }

    public func Fuse(mainIndex: Int32, copyIndex: Int32, keepElement: Int32) -> Bool {
        this.m_fusedIndex = -1;
        if !this.OwnedValid(mainIndex) || !this.OwnedValid(copyIndex) {
            GRLog("Recompensas: Aumento cancelado (indices fuera de la foto: " + IntToString(mainIndex) + " y " + IntToString(copyIndex)
                + " de " + IntToString(ArraySize(this.m_oIds)) + ")");
            return false;
        }
        let mainId: ItemID = this.m_oIds[mainIndex];
        let copyId: ItemID = this.m_oIds[copyIndex];
        if mainIndex == copyIndex || mainId == copyId {
            GRLog("Recompensas: Aumento cancelado (el arma y la copia son la misma) " + this.DescribeId(mainId));
            return false;
        }
        let gang: String = this.GangForRecord(ItemID.GetTDBID(mainId));
        let copyGang: String = this.GangForRecord(ItemID.GetTDBID(copyId));
        if StrLen(gang) == 0 || NotEquals(gang, copyGang) {
            GRLog("Recompensas: Aumento cancelado (no son de la misma banda: \"" + gang + "\" y \"" + copyGang + "\")");
            return false;
        }
        let gi: GameInstance = this.GetGameInstance();
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        if !IsDefined(player) {
            GRLog("Recompensas: Aumento cancelado (no hay jugador)");
            return false;
        }
        let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(gi);
        let stats: ref<StatsSystem> = GameInstance.GetStatsSystem(gi);
        let mainData: wref<gameItemData> = ts.GetItemData(player, mainId);
        let copyData: wref<gameItemData> = ts.GetItemData(player, copyId);
        if !IsDefined(mainData) || !IsDefined(copyData) || !ts.HasItem(player, mainId) || !ts.HasItem(player, copyId) {
            GRLog("Recompensas: Aumento cancelado (V no tiene las dos armas) arma " + this.DescribeId(mainId) + " copia " + this.DescribeId(copyId));
            return false;
        }
        let equipment: ref<EquipmentSystemPlayerData> = EquipmentSystem.GetData(player);
        if IsDefined(equipment) && equipment.IsEquipped(copyId) {
            GRLog("Recompensas: Aumento cancelado (la copia esta equipada) " + this.DescribeId(copyId));
            return false;
        }
        this.SyncLists();
        let mainReg: Int32 = this.RegistryIndex(mainId);
        let copyReg: Int32 = this.RegistryIndex(copyId);
        if mainReg < 0 || copyReg < 0 {
            GRLog("Recompensas: Aumento cancelado (arma sin registrar) arma " + this.DescribeId(mainId) + " copia " + this.DescribeId(copyId));
            return false;
        }
        let mainElement: Int32 = this.WeaponElement(mainData, stats);
        let copyElement: Int32 = this.WeaponElement(copyData, stats);
        if keepElement < 0 || keepElement > 2 || (keepElement != mainElement && keepElement != copyElement) {
            GRLog("Recompensas: Aumento cancelado (el elemento " + IntToString(keepElement) + " no es el de ninguna de las dos: arma="
                + this.ElementLabel(mainElement) + " copia=" + this.ElementLabel(copyElement) + ")");
            return false;
        }
        let oldLevel: Int32 = this.LevelAt(mainReg);
        let copyLevel: Int32 = this.LevelAt(copyReg);
        let oldBonus: Float = this.WeaponBonus(mainData, stats, mainElement);
        let copyBonus: Float = this.WeaponBonus(copyData, stats, copyElement);
        if this.IsMaxed(oldLevel, oldBonus) {
            GRLog("Recompensas: Aumento cancelado (al tope) " + this.DescribeId(mainId) + " nivel=" + IntToString(oldLevel)
                + " bono=" + FloatToStringPrec(oldBonus, 1) + "%");
            return false;
        }
        let newLevel: Int32 = this.FusedLevel(oldLevel, copyLevel);
        let newBonus: Float = this.FusedBonus(oldBonus, copyBonus);
        let before: String = this.DescribeStats(mainData, stats);
        let copyText: String = this.DescribeId(copyId) + " nivel=" + IntToString(copyLevel) + " elemento=" + this.ElementLabel(copyElement)
            + " bono=" + FloatToStringPrec(copyBonus, 1) + "%";

        let removed: Bool = ts.RemoveItem(player, copyId, 1);
        if ts.HasItem(player, copyId) {
            GRLog("Recompensas: Aumento ERROR, no se pudo destruir la copia (RemoveItem=" + this.BoolText(removed) + "): sigue registrada y el arma no cambia. "
                + copyText);
            return false;
        }
        ArrayErase(this.m_ids, copyReg);
        ArrayErase(this.m_nemesisIds, copyReg);
        ArrayErase(this.m_levels, copyReg);
        this.EraseStashEntry(copyReg);
        if copyReg < mainReg {
            mainReg -= 1;
        }

        let objID: StatsObjectID = mainData.GetStatsObjectID();
        let ok: Bool = true;
        let physBefore: Float = this.ReadStat(mainData, stats, gamedataStatType.PhysicalDamage);
        if newLevel > oldLevel {
            if !stats.AddSavedModifier(objID, RPGManager.CreateStatModifier(gamedataStatType.PhysicalDamage, gameStatModifierType.AdditiveMultiplier,
                0.05 * Cast<Float>(newLevel - oldLevel))) {
                ok = false;
            }
        }
        let physAfter: Float = this.ReadStat(mainData, stats, gamedataStatType.PhysicalDamage);

        let baseName: String = this.BaseDamageName(mainData, stats);
        let baseValue: Float = this.BaseDamage(mainData, stats);
        let newDamage: Float = baseValue * newBonus / 100.0;
        if mainElement >= 0 && mainElement != keepElement {
            if !this.AddDifference(mainData, stats, this.ElementStat(mainElement), 0.0) {
                ok = false;
            }
            if !this.AddDifference(mainData, stats, this.ElementRateStat(mainElement), 0.0) {
                ok = false;
            }
        }
        if !this.AddDifference(mainData, stats, this.ElementStat(keepElement), newDamage) {
            ok = false;
        }
        if !this.AddDifference(mainData, stats, this.ElementRateStat(keepElement), newBonus) {
            ok = false;
        }
        this.m_levels[mainReg] = newLevel;

        GRLog("Recompensas: Aumento (" + gang + ") \"" + this.GetCustomName(mainId) + "\" " + this.DescribeId(mainId)
            + " | ANTES nivel=" + IntToString(oldLevel) + " elemento=" + this.ElementLabel(mainElement) + " bono=" + FloatToStringPrec(oldBonus, 1) + "%"
            + " | COPIA destruida " + copyText + " RemoveItem=" + this.BoolText(removed)
            + " | DESPUES nivel=" + IntToString(newLevel) + " elemento=" + this.ElementLabel(keepElement) + " bono=" + FloatToStringPrec(newBonus, 1) + "%"
            + " (dano elemental " + FloatToStringPrec(newDamage, 2) + " sobre " + baseName + "=" + FloatToStringPrec(baseValue, 2)
            + ", PhysicalDamage " + FloatToStringPrec(physBefore, 2) + " -> " + FloatToStringPrec(physAfter, 2) + ")"
            + " modificadores OK=" + this.BoolText(ok) + " quedan registradas=" + IntToString(ArraySize(this.m_ids))
            + " | ANTES " + before + " | DESPUES " + this.DescribeStats(mainData, stats));
        if newLevel > oldLevel && physBefore > 0.0 {
            let expected: Float = physBefore * (1.0 + 0.05 * Cast<Float>(newLevel - 1)) / (1.0 + 0.05 * Cast<Float>(oldLevel - 1));
            if AbsF(physAfter - expected) > expected * 0.01 {
                GRLog("Recompensas: Aumento AVISO, PhysicalDamage esperado " + FloatToStringPrec(expected, 2) + " y quedo en "
                    + FloatToStringPrec(physAfter, 2) + " (revisar AdditiveMultiplier)");
            }
        }

        this.Snapshot();
        let i: Int32 = 0;
        while i < ArraySize(this.m_oIds) {
            if this.m_oIds[i] == mainId {
                this.m_fusedIndex = i;
            }
            i += 1;
        }
        return true;
    }

    public func GetFusedIndex() -> Int32 {
        return this.m_fusedIndex;
    }

    public func FusedBonus(mainBonus: Float, copyBonus: Float) -> Float {
        return MinF(60.0, Cast<Float>(RoundF(MaxF(mainBonus, copyBonus) * 11.0)) / 10.0);
    }

    public func FusedLevel(mainLevel: Int32, copyLevel: Int32) -> Int32 {
        return Min(5, Max(mainLevel, copyLevel) + 1);
    }

    private func AddDifference(data: wref<gameItemData>, stats: ref<StatsSystem>, stat: gamedataStatType, target: Float) -> Bool {
        let difference: Float = target - this.ReadStat(data, stats, stat);
        if AbsF(difference) < 0.0001 {
            return true;
        }
        return stats.AddSavedModifier(data.GetStatsObjectID(), RPGManager.CreateStatModifier(stat, gameStatModifierType.Additive, difference));
    }

    private func RegistryIndex(id: ItemID) -> Int32 {
        let i: Int32 = 0;
        while i < ArraySize(this.m_ids) {
            if this.m_ids[i] == id {
                return i;
            }
            i += 1;
        }
        return -1;
    }

    private func LevelAt(index: Int32) -> Int32 {
        if index < 0 || index >= ArraySize(this.m_levels) {
            return 1;
        }
        return Min(5, Max(1, this.m_levels[index]));
    }

    private func IsMaxed(level: Int32, bonus: Float) -> Bool {
        return level >= 5 && bonus >= 59.95;
    }

    private func WeaponElement(data: wref<gameItemData>, stats: ref<StatsSystem>) -> Int32 {
        let element: Int32 = -1;
        let best: Float = 0.0;
        let e: Int32 = 0;
        while e < 3 {
            let value: Float = this.ReadStat(data, stats, this.ElementStat(e));
            if value > best {
                best = value;
                element = e;
            }
            e += 1;
        }
        return element;
    }

    private func WeaponBonus(data: wref<gameItemData>, stats: ref<StatsSystem>, element: Int32) -> Float {
        if element < 0 {
            return 0.0;
        }
        return this.ReadStat(data, stats, this.ElementRateStat(element));
    }

    private func BaseDamage(data: wref<gameItemData>, stats: ref<StatsSystem>) -> Float {
        let value: Float = this.ReadStat(data, stats, gamedataStatType.PhysicalDamage);
        if value <= 0.0 {
            value = this.ReadStat(data, stats, gamedataStatType.EffectiveDamagePerHit);
        }
        return value;
    }

    private func BaseDamageName(data: wref<gameItemData>, stats: ref<StatsSystem>) -> String {
        if this.ReadStat(data, stats, gamedataStatType.PhysicalDamage) <= 0.0 {
            return "EffectiveDamagePerHit";
        }
        return "PhysicalDamage";
    }

    private func SeedFor(nemesisId: Int32) -> Int32 {
        return ((nemesisId % 100000) * 7919 + 104729) % 1000003;
    }

    private func RollElement(nemesisId: Int32, traitsCsv: String) -> Int32 {
        return this.PickElement(traitsCsv, this.SeedFor(nemesisId) / 21);
    }

    private func RollBonus(nemesisId: Int32, escapes: Int32) -> Int32 {
        let pct: Int32 = 20 + (this.SeedFor(nemesisId) % 21) + 2 * Max(escapes, 0);
        if pct > 60 {
            pct = 60;
        }
        return pct;
    }

    public func PreviewBossWeapon(nemesisId: Int32, gang: String, traitsCsv: String, escapes: Int32) -> Bool {
        this.m_pvElement = -1;
        this.m_pvBonus = 0;
        if nemesisId <= 0 || !TDBID.IsValid(this.WeaponForGang(gang)) {
            return false;
        }
        this.m_pvElement = this.RollElement(nemesisId, traitsCsv);
        this.m_pvBonus = this.RollBonus(nemesisId, escapes);
        return true;
    }

    public func GetPreviewElement() -> Int32 {
        return this.m_pvElement;
    }

    public func GetPreviewBonus() -> Int32 {
        return this.m_pvBonus;
    }

    public func GetGangWeaponBaseName(gang: String) -> String {
        return this.RecordBaseName(this.WeaponForGang(gang));
    }

    public func GetGangWeaponType(gang: String) -> String {
        let record: ref<Item_Record> = TweakDBInterface.GetItemRecord(this.WeaponForGang(gang));
        if !IsDefined(record) || !IsDefined(record.ItemType()) {
            return "";
        }
        return GetLocalizedText(UIItemsHelper.GetItemTypeKey(record.ItemType().Type()));
    }

    public func GetBossWeaponName(boss: String, gang: String) -> String {
        return this.FormatName(boss, this.GetGangWeaponBaseName(gang));
    }

    public func Snapshot() -> Void {
        ArrayClear(this.m_oIds);
        ArrayClear(this.m_oNemesis);
        ArrayClear(this.m_oGangs);
        ArrayClear(this.m_oElements);
        ArrayClear(this.m_oBonus);
        ArrayClear(this.m_oBonusF);
        ArrayClear(this.m_oLevels);
        ArrayClear(this.m_oDamage);
        ArrayClear(this.m_oTiers);
        ArrayClear(this.m_oEquipped);
        ArrayClear(this.m_oStashed);
        let gi: GameInstance = this.GetGameInstance();
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        if !IsDefined(player) {
            return;
        }
        let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(gi);
        let stats: ref<StatsSystem> = GameInstance.GetStatsSystem(gi);
        let equipment: ref<EquipmentSystemPlayerData> = EquipmentSystem.GetData(player);
        let i: Int32 = 0;
        while i < ArraySize(this.m_ids) {
            let id: ItemID = this.m_ids[i];
            let data: wref<gameItemData> = ts.GetItemData(player, id);
            if IsDefined(data) && ts.HasItem(player, id) {
                let element: Int32 = this.WeaponElement(data, stats);
                let bonus: Float = this.WeaponBonus(data, stats, element);
                let tier: String = GetLocalizedText(UIItemsHelper.QualityToTierString(RPGManager.GetItemQuality(data)));
                let plus: Int32 = RoundF(RPGManager.GetItemPlus(data));
                while plus > 0 {
                    tier += "+";
                    plus -= 1;
                }
                ArrayPush(this.m_oIds, id);
                ArrayPush(this.m_oNemesis, i < ArraySize(this.m_nemesisIds) ? this.m_nemesisIds[i] : 0);
                ArrayPush(this.m_oGangs, this.GangForRecord(ItemID.GetTDBID(id)));
                ArrayPush(this.m_oElements, element);
                ArrayPush(this.m_oBonus, RoundF(bonus));
                ArrayPush(this.m_oBonusF, bonus);
                ArrayPush(this.m_oLevels, this.LevelAt(i));
                ArrayPush(this.m_oDamage, this.ReadStat(data, stats, gamedataStatType.EffectiveDamagePerHit));
                ArrayPush(this.m_oTiers, tier);
                ArrayPush(this.m_oEquipped, IsDefined(equipment) && equipment.IsEquipped(id));
                ArrayPush(this.m_oStashed, false);
                if this.StashKindAt(i) > 0 {
                    this.m_stashed[i] = 0;
                    GRLog("Recompensas: alijo, V volvio a tener #" + IntToString(i) + " " + this.DescribeId(id) + ", se borra la marca de alijo");
                }
            } else {
                let kind: Int32 = this.StashKindAt(i);
                if kind > 0 && i < ArraySize(this.m_stElement) && i < ArraySize(this.m_stBonus) && i < ArraySize(this.m_stDamage)
                    && i < ArraySize(this.m_stQuality) && i < ArraySize(this.m_stPlus) {
                    let cachedElement: Int32 = this.m_stElement[i] - 1;
                    let cachedBonus: Float = this.m_stBonus[i];
                    let cachedTier: String = GetLocalizedText(UIItemsHelper.QualityToTierString(IntEnum<gamedataQuality>(this.m_stQuality[i])));
                    let cachedPlus: Int32 = this.m_stPlus[i];
                    while cachedPlus > 0 {
                        cachedTier += "+";
                        cachedPlus -= 1;
                    }
                    ArrayPush(this.m_oIds, id);
                    ArrayPush(this.m_oNemesis, i < ArraySize(this.m_nemesisIds) ? this.m_nemesisIds[i] : 0);
                    ArrayPush(this.m_oGangs, this.GangForRecord(ItemID.GetTDBID(id)));
                    ArrayPush(this.m_oElements, cachedElement);
                    ArrayPush(this.m_oBonus, RoundF(cachedBonus));
                    ArrayPush(this.m_oBonusF, cachedBonus);
                    ArrayPush(this.m_oLevels, this.LevelAt(i));
                    ArrayPush(this.m_oDamage, this.m_stDamage[i]);
                    ArrayPush(this.m_oTiers, cachedTier);
                    ArrayPush(this.m_oEquipped, false);
                    ArrayPush(this.m_oStashed, true);
                    GRLog("Recompensas: alijo, #" + IntToString(i) + " " + this.DescribeId(id) + " sale por cache (" + this.StashKindName(kind)
                        + ") elemento=" + this.ElementLabel(cachedElement) + " bono=" + FloatToStringPrec(cachedBonus, 1) + "% dano="
                        + FloatToStringPrec(this.m_stDamage[i], 1) + " calidad=" + cachedTier);
                }
            }
            i += 1;
        }
    }

    public func GetOwnedCount() -> Int32 {
        return ArraySize(this.m_oIds);
    }

    private func OwnedValid(index: Int32) -> Bool {
        return index >= 0 && index < ArraySize(this.m_oIds);
    }

    public func GetOwnedGang(index: Int32) -> String {
        return this.OwnedValid(index) ? this.m_oGangs[index] : "";
    }

    public func GetOwnedName(index: Int32) -> String {
        if !this.OwnedValid(index) {
            return "";
        }
        let id: ItemID = this.m_oIds[index];
        let name: String = this.GetCustomName(id);
        return StrLen(name) > 0 ? name : this.WeaponBaseName(id);
    }

    public func GetOwnedBaseName(index: Int32) -> String {
        return this.OwnedValid(index) ? this.WeaponBaseName(this.m_oIds[index]) : "";
    }

    public func GetOwnedRecord(index: Int32) -> TweakDBID {
        return this.OwnedValid(index) ? ItemID.GetTDBID(this.m_oIds[index]) : TDBID.None();
    }

    public func GetOwnedElement(index: Int32) -> Int32 {
        return this.OwnedValid(index) ? this.m_oElements[index] : -1;
    }

    public func GetOwnedBonus(index: Int32) -> Int32 {
        return this.OwnedValid(index) ? this.m_oBonus[index] : 0;
    }

    public func GetOwnedBonusF(index: Int32) -> Float {
        return this.OwnedValid(index) ? this.m_oBonusF[index] : 0.0;
    }

    public func GetOwnedLevel(index: Int32) -> Int32 {
        return this.OwnedValid(index) ? this.m_oLevels[index] : 1;
    }

    public func IsOwnedMaxed(index: Int32) -> Bool {
        return this.OwnedValid(index) && this.IsMaxed(this.m_oLevels[index], this.m_oBonusF[index]);
    }

    public func GetOwnedDamage(index: Int32) -> Float {
        return this.OwnedValid(index) ? this.m_oDamage[index] : 0.0;
    }

    public func GetOwnedTier(index: Int32) -> String {
        return this.OwnedValid(index) ? this.m_oTiers[index] : "";
    }

    public func IsOwnedEquipped(index: Int32) -> Bool {
        return this.OwnedValid(index) && this.m_oEquipped[index];
    }

    public func GetOwnedBossName(index: Int32) -> String {
        if !this.OwnedValid(index) {
            return "";
        }
        let nemesisId: Int32 = this.m_oNemesis[index];
        let i: Int32 = 0;
        while i < ArraySize(this.m_nameIds) {
            if this.m_nameIds[i] == nemesisId && nemesisId > 0 && i < ArraySize(this.m_names) {
                return this.m_names[i];
            }
            i += 1;
        }
        return "";
    }

    public func GetOwnedIconAspect(index: Int32) -> Float {
        return this.OwnedValid(index) ? this.IconAspect(ItemID.GetTDBID(this.m_oIds[index])) : 2.5;
    }

    private func IconAspect(recordID: TweakDBID) -> Float {
        if recordID == t"Items.Preset_Carnage_Default" {
            return 320.0 / 76.0;
        }
        if recordID == t"Items.Preset_Katana_Default" {
            return 320.0 / 31.0;
        }
        if recordID == t"Items.Preset_Overture_Default" {
            return 320.0 / 153.0;
        }
        if recordID == t"Items.Preset_Copperhead_Military" {
            return 320.0 / 90.0;
        }
        if recordID == t"Items.Preset_Hammer_Default" {
            return 320.0 / 91.0;
        }
        if recordID == t"Items.Preset_Yukimura_Default" {
            return 273.0 / 160.0;
        }
        if recordID == t"Items.Preset_Tactician_Default" {
            return 320.0 / 53.0;
        }
        if recordID == t"Items.Preset_Saratoga_Default" {
            return 320.0 / 149.0;
        }
        if recordID == t"Items.Preset_Ajax_Default" {
            return 320.0 / 119.0;
        }
        return 2.5;
    }

    private func GangForRecord(recordID: TweakDBID) -> String {
        let gangs: array<String> = ["Maelstrom", "TygerClaws", "Valentinos", "SixthStreet", "Animals", "VoodooBoys", "Wraiths", "Scavengers", "Barghest"];
        let i: Int32 = 0;
        while i < ArraySize(gangs) {
            if this.WeaponForGang(gangs[i]) == recordID {
                return gangs[i];
            }
            i += 1;
        }
        return "";
    }

    public func DebugReport() -> Void {
        let gi: GameInstance = this.GetGameInstance();
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        let count: Int32 = ArraySize(this.m_ids);
        let givenText: String = "";
        let g: Int32 = 0;
        while g < ArraySize(this.m_given) {
            if g > 0 {
                givenText += ",";
            }
            givenText += IntToString(this.m_given[g]);
            g += 1;
        }
        GRLog("Recompensas: reporte, " + IntToString(count) + " arma(s) registrada(s), Jefes que ya dieron arma=[" + givenText
            + "], nombres de Jefe en memoria=" + IntToString(ArraySize(this.m_names)));
        if !IsDefined(player) {
            GRLog("Recompensas: reporte cancelado, no hay jugador");
            return;
        }
        let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(gi);
        let stats: ref<StatsSystem> = GameInstance.GetStatsSystem(gi);
        let i: Int32 = 0;
        while i < count {
            let id: ItemID = this.m_ids[i];
            let nemesisId: Int32 = 0;
            if i < ArraySize(this.m_nemesisIds) {
                nemesisId = this.m_nemesisIds[i];
            }
            let has: Bool = ts.HasItem(player, id);
            let data: wref<gameItemData> = ts.GetItemData(player, id);
            let line: String = "Recompensas: reporte #" + IntToString(i) + " Jefe #" + IntToString(nemesisId) + " \"" + this.GetCustomName(id) + "\" "
                + this.DescribeId(id) + " nivel=" + IntToString(this.LevelAt(i)) + " V la tiene=" + this.BoolText(has) + " cantidad=" + IntToString(ts.GetItemQuantity(player, id));
            if IsDefined(data) {
                line += " | " + this.DescribeStats(data, stats);
            } else {
                line += " | sin itemData";
            }
            GRLog(line);
            i += 1;
        }
    }

    public func DebugRemoveLast() -> Void {
        let gi: GameInstance = this.GetGameInstance();
        this.SyncLists();
        let count: Int32 = ArraySize(this.m_ids);
        if count == 0 {
            GRLog("Recompensas: quitar, no hay armas registradas");
            return;
        }
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        if !IsDefined(player) {
            GRLog("Recompensas: quitar cancelado, no hay jugador");
            return;
        }
        let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(gi);
        let last: Int32 = count - 1;
        let id: ItemID = this.m_ids[last];
        let nemesisId: Int32 = this.m_nemesisIds[last];
        let hadIt: Bool = ts.HasItem(player, id);
        let removed: Bool = ts.RemoveItem(player, id, 1);
        let stillHas: Bool = ts.HasItem(player, id);
        let unregistered: Bool = !stillHas;
        if unregistered {
            ArrayErase(this.m_ids, last);
            ArrayErase(this.m_nemesisIds, last);
            ArrayErase(this.m_levels, last);
            this.EraseStashEntry(last);
        }
        GRLog("Recompensas: quitar Jefe #" + IntToString(nemesisId) + " " + this.DescribeId(id) + " V la tenia=" + this.BoolText(hadIt)
            + " RemoveItem=" + this.BoolText(removed) + " V la sigue teniendo=" + this.BoolText(stillHas)
            + " sacada del registro=" + this.BoolText(unregistered) + " (quedan " + IntToString(ArraySize(this.m_ids)) + ")");
    }

    private func SyncLists() -> Void {
        while ArraySize(this.m_nemesisIds) < ArraySize(this.m_ids) {
            ArrayPush(this.m_nemesisIds, 0);
        }
        while ArraySize(this.m_nemesisIds) > ArraySize(this.m_ids) {
            ArrayPop(this.m_nemesisIds);
        }
        while ArraySize(this.m_levels) < ArraySize(this.m_ids) {
            ArrayPush(this.m_levels, 0);
        }
        while ArraySize(this.m_levels) > ArraySize(this.m_ids) {
            ArrayPop(this.m_levels);
        }
        this.SyncStashLists();
    }

    private func SyncStashLists() -> Void {
        let count: Int32 = ArraySize(this.m_ids);
        let ok: Bool = ArraySize(this.m_stashed) == count && ArraySize(this.m_stElement) == count && ArraySize(this.m_stBonus) == count
            && ArraySize(this.m_stDamage) == count && ArraySize(this.m_stQuality) == count && ArraySize(this.m_stPlus) == count;
        if ok {
            return;
        }
        while ArraySize(this.m_stashed) > count {
            ArrayPop(this.m_stashed);
        }
        while ArraySize(this.m_stElement) > count {
            ArrayPop(this.m_stElement);
        }
        while ArraySize(this.m_stBonus) > count {
            ArrayPop(this.m_stBonus);
        }
        while ArraySize(this.m_stDamage) > count {
            ArrayPop(this.m_stDamage);
        }
        while ArraySize(this.m_stQuality) > count {
            ArrayPop(this.m_stQuality);
        }
        while ArraySize(this.m_stPlus) > count {
            ArrayPop(this.m_stPlus);
        }
        while ArraySize(this.m_stashed) < count {
            ArrayPush(this.m_stashed, 0);
        }
        while ArraySize(this.m_stElement) < count {
            ArrayPush(this.m_stElement, 0);
        }
        while ArraySize(this.m_stBonus) < count {
            ArrayPush(this.m_stBonus, 0.0);
        }
        while ArraySize(this.m_stDamage) < count {
            ArrayPush(this.m_stDamage, 0.0);
        }
        while ArraySize(this.m_stQuality) < count {
            ArrayPush(this.m_stQuality, 0);
        }
        while ArraySize(this.m_stPlus) < count {
            ArrayPush(this.m_stPlus, 0);
        }
    }

    private func PushStashEntry() -> Void {
        ArrayPush(this.m_stashed, 0);
        ArrayPush(this.m_stElement, 0);
        ArrayPush(this.m_stBonus, 0.0);
        ArrayPush(this.m_stDamage, 0.0);
        ArrayPush(this.m_stQuality, 0);
        ArrayPush(this.m_stPlus, 0);
    }

    private func EraseStashEntry(index: Int32) -> Void {
        if index < 0 {
            return;
        }
        if index < ArraySize(this.m_stashed) {
            ArrayErase(this.m_stashed, index);
        }
        if index < ArraySize(this.m_stElement) {
            ArrayErase(this.m_stElement, index);
        }
        if index < ArraySize(this.m_stBonus) {
            ArrayErase(this.m_stBonus, index);
        }
        if index < ArraySize(this.m_stDamage) {
            ArrayErase(this.m_stDamage, index);
        }
        if index < ArraySize(this.m_stQuality) {
            ArrayErase(this.m_stQuality, index);
        }
        if index < ArraySize(this.m_stPlus) {
            ArrayErase(this.m_stPlus, index);
        }
    }

    private func StashKindAt(index: Int32) -> Int32 {
        if index < 0 || index >= ArraySize(this.m_stashed) {
            return 0;
        }
        return this.m_stashed[index];
    }

    private func StashKindName(kind: Int32) -> String {
        if kind == 2 {
            return "baul del auto";
        }
        return "alijo";
    }

    public func SyncStash(storage: ref<GameObject>, kind: Int32) -> Void {
        if !IsDefined(storage) || kind <= 0 {
            return;
        }
        let gi: GameInstance = this.GetGameInstance();
        let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(gi);
        let stats: ref<StatsSystem> = GameInstance.GetStatsSystem(gi);
        let player: ref<PlayerPuppet> = GetPlayer(gi);
        let items: array<wref<gameItemData>>;
        if !ts.GetItemList(storage, items) {
            GRLog("Recompensas: alijo, no se pudo leer la lista del " + this.StashKindName(kind) + " (GetItemList=false), no se cambia nada");
            return;
        }
        this.SyncLists();
        let found: Int32 = 0;
        let removed: Int32 = 0;
        let idsText: String = "";
        let itemCount: Int32 = ArraySize(items);
        let i: Int32 = 0;
        while i < ArraySize(this.m_ids) {
            let id: ItemID = this.m_ids[i];
            let data: wref<gameItemData>;
            let k: Int32 = 0;
            while k < itemCount && !IsDefined(data) {
                let candidate: wref<gameItemData> = items[k];
                if IsDefined(candidate) && candidate.GetID() == id {
                    data = candidate;
                }
                k += 1;
            }
            if IsDefined(data) {
                let element: Int32 = this.WeaponElement(data, stats);
                this.m_stashed[i] = kind;
                this.m_stElement[i] = element + 1;
                this.m_stBonus[i] = this.WeaponBonus(data, stats, element);
                this.m_stDamage[i] = this.ReadStat(data, stats, gamedataStatType.EffectiveDamagePerHit);
                let quality: gamedataQuality = RPGManager.GetItemQuality(data);
                this.m_stQuality[i] = EnumInt(quality);
                this.m_stPlus[i] = RoundF(RPGManager.GetItemPlus(data));
                found += 1;
                if StrLen(idsText) > 0 {
                    idsText += ", ";
                }
                idsText += "#" + IntToString(i) + " " + this.DescribeId(id);
            } else {
                let mine: Bool = this.m_stashed[i] == kind || (this.m_stashed[i] > 0 && IsDefined(player) && ts.HasItem(player, id));
                if mine && this.m_stashed[i] > 0 {
                    this.m_stashed[i] = 0;
                    removed += 1;
                }
            }
            i += 1;
        }
        GRLog("Recompensas: alijo sincronizado (" + this.StashKindName(kind) + ", " + IntToString(itemCount) + " objetos), "
            + IntToString(found) + " de " + IntToString(ArraySize(this.m_ids)) + " arma(s) registrada(s) estan ahi"
            + (removed > 0 ? ", " + IntToString(removed) + " ya no estan" : "") + (found > 0 ? ": " + idsText : ""));
    }

    public func IsOwnedStashed(index: Int32) -> Bool {
        return this.OwnedValid(index) && this.m_oStashed[index];
    }

    private func WeaponForGang(gang: String) -> TweakDBID {
        if Equals(gang, "Maelstrom") {
            return t"Items.Preset_Carnage_Default";
        }
        if Equals(gang, "TygerClaws") {
            return t"Items.Preset_Katana_Default";
        }
        if Equals(gang, "Valentinos") {
            return t"Items.Preset_Overture_Default";
        }
        if Equals(gang, "SixthStreet") {
            return t"Items.Preset_Copperhead_Military";
        }
        if Equals(gang, "Animals") {
            return t"Items.Preset_Hammer_Default";
        }
        if Equals(gang, "VoodooBoys") {
            return t"Items.Preset_Yukimura_Default";
        }
        if Equals(gang, "Wraiths") {
            return t"Items.Preset_Tactician_Default";
        }
        if Equals(gang, "Scavengers") {
            return t"Items.Preset_Saratoga_Default";
        }
        if Equals(gang, "Barghest") {
            return t"Items.Preset_Ajax_Default";
        }
        return TDBID.None();
    }

    private func PickElement(traitsCsv: String, pick: Int32) -> Int32 {
        let options: array<Int32>;
        let keys: array<String> = StrSplit(traitsCsv, ",");
        let i: Int32 = 0;
        while i < ArraySize(keys) {
            let key: String = keys[i];
            if Equals(key, "insulated") && !ArrayContains(options, 0) {
                ArrayPush(options, 0);
            }
            if Equals(key, "fireproof") && !ArrayContains(options, 1) {
                ArrayPush(options, 1);
            }
            if Equals(key, "toxproof") && !ArrayContains(options, 2) {
                ArrayPush(options, 2);
            }
            i += 1;
        }
        if ArraySize(options) == 0 {
            ArrayPush(options, 0);
            ArrayPush(options, 1);
            ArrayPush(options, 2);
        }
        return options[pick % ArraySize(options)];
    }

    private func NameForNemesis(nemesisId: Int32, id: ItemID) -> String {
        if nemesisId <= 0 {
            return "";
        }
        let i: Int32 = 0;
        while i < ArraySize(this.m_nameIds) {
            if this.m_nameIds[i] == nemesisId {
                if i < ArraySize(this.m_names) && StrLen(this.m_names[i]) > 0 {
                    return this.FormatName(this.m_names[i], this.WeaponBaseName(id));
                }
                return "";
            }
            i += 1;
        }
        return "";
    }

    private func WeaponBaseName(id: ItemID) -> String {
        return this.RecordBaseName(ItemID.GetTDBID(id));
    }

    private func RecordBaseName(recordID: TweakDBID) -> String {
        let record: ref<Item_Record> = TweakDBInterface.GetItemRecord(recordID);
        if !IsDefined(record) {
            return "";
        }
        return GetLocalizedItemNameByCName(record.DisplayName());
    }

    private func FormatName(boss: String, weapon: String) -> String {
        let format: String = "";
        let core: ref<GRSystem> = GRSystem.Get(this.GetGameInstance());
        if IsDefined(core) {
            format = core.GetText("GR-WeaponName");
        }
        if !StrContains(format, "{weapon}") || !StrContains(format, "{boss}") {
            format = "{boss}'s {weapon}";
        }
        let withWeapon: String = StrReplace(format, "{weapon}", weapon);
        return StrReplace(withWeapon, "{boss}", boss);
    }

    private func ElementStat(element: Int32) -> gamedataStatType {
        if element == 1 {
            return gamedataStatType.ThermalDamage;
        }
        if element == 2 {
            return gamedataStatType.ChemicalDamage;
        }
        return gamedataStatType.ElectricDamage;
    }

    private func ElementName(element: Int32) -> String {
        if element == 1 {
            return "ThermalDamage";
        }
        if element == 2 {
            return "ChemicalDamage";
        }
        return "ElectricDamage";
    }

    private func ElementLabel(element: Int32) -> String {
        if element < 0 || element > 2 {
            return "ninguno";
        }
        return this.ElementName(element);
    }

    private func ElementRateStat(element: Int32) -> gamedataStatType {
        if element == 1 {
            return gamedataStatType.BurningApplicationRate;
        }
        if element == 2 {
            return gamedataStatType.PoisonedApplicationRate;
        }
        return gamedataStatType.ElectrocutedApplicationRate;
    }

    private func ElementRateName(element: Int32) -> String {
        if element == 1 {
            return "BurningApplicationRate";
        }
        if element == 2 {
            return "PoisonedApplicationRate";
        }
        return "ElectrocutedApplicationRate";
    }

    public func MakeTooltipStat(data: wref<gameItemData>) -> ref<GRElementStat> {
        if !IsDefined(data) || StrLen(this.GetCustomName(data.GetID())) == 0 {
            return null;
        }
        let stats: ref<StatsSystem> = GameInstance.GetStatsSystem(this.GetGameInstance());
        let element: Int32 = this.WeaponElement(data, stats);
        if element < 0 {
            return null;
        }
        let bonus: Float = this.WeaponBonus(data, stats, element);
        if bonus <= 0.0 {
            return null;
        }
        let label: String = this.ElementDamageLabel(element);
        let stat: ref<GRElementStat> = new GRElementStat();
        stat.element = element;
        stat.rateType = this.ElementRateStat(element);
        stat.Type = this.ElementPercentStat(element);
        stat.Value = bonus;
        stat.SetProperties(UIItemStatProperties.Make(label, 1, true, true, false, false, false, false, false, -1.0, false));
        GRLog("Recompensas: tooltip +" + FloatToStringPrec(bonus, 1) + "% " + this.ElementName(element) + " en " + this.DescribeId(data.GetID()));
        return stat;
    }

    private func ElementPercentStat(element: Int32) -> gamedataStatType {
        if element == 1 {
            return gamedataStatType.ThermalDamagePercentBonus;
        }
        if element == 2 {
            return gamedataStatType.ChemicalDamagePercentBonus;
        }
        return gamedataStatType.ElectricDamagePercentBonus;
    }

    private func ElementDamageLabel(element: Int32) -> String {
        let key: String = "GR-MenuDmg-" + IntToString(element);
        let text: String = "";
        let core: ref<GRSystem> = GRSystem.Get(this.GetGameInstance());
        if IsDefined(core) {
            text = core.GetText(key);
        }
        if StrLen(text) > 0 && !Equals(text, key) {
            return text;
        }
        if element == 1 {
            return "Thermal damage";
        }
        if element == 2 {
            return "Chemical damage";
        }
        return "Electrical damage";
    }

    private func BoolText(value: Bool) -> String {
        if value {
            return "true";
        }
        return "false";
    }

    private func DescribeId(id: ItemID) -> String {
        return "id=" + TDBID.ToStringDEBUG(ItemID.GetTDBID(id)) + " seed=" + ToString(ItemID.GetRngSeed(id)) + " hash=" + ToString(ItemID.GetCombinedHash(id));
    }

    private func ReadStat(data: wref<gameItemData>, stats: ref<StatsSystem>, stat: gamedataStatType) -> Float {
        let fromItem: Float = data.GetStatValueByType(stat);
        if fromItem > 0.0 {
            return fromItem;
        }
        return stats.GetStatValue(data.GetStatsObjectID(), stat);
    }

    private func DescribeStat(label: String, data: wref<gameItemData>, stats: ref<StatsSystem>, stat: gamedataStatType) -> String {
        return label + "=" + FloatToStringPrec(data.GetStatValueByType(stat), 2) + "/" + FloatToStringPrec(stats.GetStatValue(data.GetStatsObjectID(), stat), 2);
    }

    private func DescribeStats(data: wref<gameItemData>, stats: ref<StatsSystem>) -> String {
        return "stats item/sistema: " + this.DescribeStat("PowerLevel", data, stats, gamedataStatType.PowerLevel)
            + " " + this.DescribeStat("ItemLevel", data, stats, gamedataStatType.ItemLevel)
            + " " + this.DescribeStat("PhysicalDamage", data, stats, gamedataStatType.PhysicalDamage)
            + " " + this.DescribeStat("ElectricDamage", data, stats, gamedataStatType.ElectricDamage)
            + " " + this.DescribeStat("ThermalDamage", data, stats, gamedataStatType.ThermalDamage)
            + " " + this.DescribeStat("ChemicalDamage", data, stats, gamedataStatType.ChemicalDamage)
            + " " + this.DescribeStat("EffectiveDamagePerHit", data, stats, gamedataStatType.EffectiveDamagePerHit)
            + " " + this.DescribeStat("ElectrocutedApplicationRate", data, stats, gamedataStatType.ElectrocutedApplicationRate)
            + " " + this.DescribeStat("BurningApplicationRate", data, stats, gamedataStatType.BurningApplicationRate)
            + " " + this.DescribeStat("PoisonedApplicationRate", data, stats, gamedataStatType.PoisonedApplicationRate)
            + " IsItemIconic=" + this.BoolText(RPGManager.IsItemIconic(data));
    }
}

public func GRRewardCustomName(id: ItemID) -> String {
    if !ItemID.IsValid(id) {
        return "";
    }
    let container: ref<ScriptableSystemsContainer> = GameInstance.GetScriptableSystemsContainer(GetGameInstance());
    if !IsDefined(container) {
        return "";
    }
    let rewards: ref<GRRewards> = container.Get(n"GangRetaliation.GRRewards") as GRRewards;
    if !IsDefined(rewards) {
        return "";
    }
    return rewards.GetCustomName(id);
}

@wrapMethod(UIInventoryItem)
public final func GetName() -> String {
    let original: String = wrappedMethod();
    let custom: String = GRRewardCustomName(this.GetID());
    if StrLen(custom) > 0 {
        return custom;
    }
    return original;
}

@wrapMethod(UIItemsHelper)
public final static func GetItemName(itemRecord: ref<Item_Record>, itemData: wref<gameItemData>) -> String {
    let original: String = wrappedMethod(itemRecord, itemData);
    if !IsDefined(itemData) {
        return original;
    }
    let custom: String = GRRewardCustomName(itemData.GetID());
    if StrLen(custom) > 0 {
        return custom;
    }
    return original;
}

@wrapMethod(InventoryItemData)
public final static func GetName(const self: script_ref<InventoryItemData>) -> String {
    let original: String = wrappedMethod(self);
    let custom: String = GRRewardCustomName(InventoryItemData.GetID(self));
    if StrLen(custom) > 0 {
        return custom;
    }
    return original;
}

public class GRElementStat extends UIInventoryItemStat {
    public let element: Int32;
    public let rateType: gamedataStatType;
}

public func GRRewardElementStat(data: wref<gameItemData>) -> ref<GRElementStat> {
    if !IsDefined(data) {
        return null;
    }
    let container: ref<ScriptableSystemsContainer> = GameInstance.GetScriptableSystemsContainer(GetGameInstance());
    if !IsDefined(container) {
        return null;
    }
    let rewards: ref<GRRewards> = container.Get(n"GangRetaliation.GRRewards") as GRRewards;
    if !IsDefined(rewards) {
        return null;
    }
    return rewards.MakeTooltipStat(data);
}

public func GRElementColor(element: Int32) -> HDRColor {
    if element == 1 {
        return new HDRColor(1.0, 0.6, 0.239, 1.0);
    }
    if element == 2 {
        return new HDRColor(0.478, 0.851, 0.361, 1.0);
    }
    return new HDRColor(0.435, 0.659, 1.0, 1.0);
}

@addField(UIInventoryItemStatsManager)
private let m_grElementChecked: Bool;

@wrapMethod(UIInventoryItemStatsManager)
public final func SizeTooltipStats() -> Int32 {
    let size: Int32 = wrappedMethod();
    if this.m_grElementChecked {
        return size;
    }
    this.m_grElementChecked = true;
    let stat: ref<GRElementStat> = GRRewardElementStat(this.m_gameItemData);
    if !IsDefined(stat) {
        return size;
    }
    let at: Int32 = -1;
    let i: Int32 = 0;
    while i < size && i < ArraySize(this.TooltipStats) && at < 0 {
        if Equals(this.TooltipStats[i].Type, stat.rateType) {
            at = i;
        }
        i += 1;
    }
    if at < 0 {
        ArrayPush(this.TooltipStats, stat);
    } else {
        ArrayInsert(this.TooltipStats, at, stat);
    }
    return ArraySize(this.TooltipStats);
}

@wrapMethod(ItemTooltipStatController)
public final func SetData(data: wref<UIInventoryItemStat>) -> Void {
    wrappedMethod(data);
    let ours: wref<GRElementStat> = data as GRElementStat;
    if !IsDefined(ours) {
        return;
    }
    let color: HDRColor = GRElementColor(ours.element);
    let name: wref<inkWidget> = inkTextRef.Get(this.m_statName);
    if IsDefined(name) {
        name.UnbindProperty(n"tintColor");
        name.SetTintColor(color);
    }
    let value: wref<inkWidget> = inkTextRef.Get(this.m_statValue);
    if IsDefined(value) {
        value.UnbindProperty(n"tintColor");
        value.SetTintColor(color);
    }
}

@wrapMethod(FullscreenVendorGameController)
private final func RemoveBB() -> Void {
    if IsDefined(this.m_storageUserData) && IsDefined(this.m_storageUserData.storageObject) {
        let storage: ref<GameObject> = this.m_storageUserData.storageObject;
        let kind: Int32 = 0;
        if storage.IsPlayerStash() {
            kind = 1;
        } else {
            let vehicle: ref<VehicleObject> = storage as VehicleObject;
            if IsDefined(vehicle) && vehicle.IsPlayerVehicle() {
                kind = 2;
            }
        }
        if kind > 0 {
            let rewards: ref<GRRewards> = GRRewards.Get(storage.GetGame());
            if IsDefined(rewards) {
                rewards.SyncStash(storage, kind);
            }
        }
    }
    wrappedMethod();
}
