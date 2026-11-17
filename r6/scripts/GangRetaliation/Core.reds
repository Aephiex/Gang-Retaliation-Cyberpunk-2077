module GangRetaliation

import Codeware.Localization.*

public func GRLog(msg: String) {
    FTLog("[GangRetaliation] " + msg);
}

public class GRSystem extends ScriptableSystem {
    private persistent let m_campaignId: Int32;

    private let m_sessionToken: Int32;

    private let m_restoredSeen: Bool;

    public static func Get(gi: GameInstance) -> ref<GRSystem> {
        return GameInstance.GetScriptableSystemsContainer(gi).Get(n"GangRetaliation.GRSystem") as GRSystem;
    }

    private func OnAttach() {
        this.m_sessionToken = RandRange(1, 999999999);
        GRLog("Sistema cargado");
    }

    public func GetSessionToken() -> Int32 {
        return this.m_sessionToken;
    }

    private func OnRestored(saveVersion: Int32, gameVersion: Int32) {
        this.m_restoredSeen = true;
        let saved: Int32 = this.m_campaignId;
        let fact: Int32 = this.ReadCampaignFact();
        let source: String = "persistente";
        if saved == 0 {
            this.GenerateCampaignId("OnRestored, la partida no traia id");
            source = fact > 0 ? "fact" : "nueva";
        } else {
            if fact != saved {
                source = fact > 0 ? "persistente, el fact decia otro" : "persistente, sin fact todavia";
            }
        }
        this.WriteCampaignFact();
        let rewardsText: String = "?";
        let rewards: ref<GRRewards> = GRRewards.Get(this.GetGameInstance());
        if IsDefined(rewards) {
            rewardsText = IntToString(rewards.GetRegisteredCount());
        }
        GRLog("Partida restaurada: campana " + IntToString(saved) + " fact " + IntToString(fact) + " rewards=" + rewardsText
            + " -> usa " + IntToString(this.m_campaignId) + " (" + source + ")");
    }

    private func OnPlayerAttach(request: ref<PlayerAttachRequest>) {
        if !this.IsInGame() {
            return;
        }
        if this.m_campaignId == 0 {
            if !this.WasRestored() {
                this.GenerateCampaignId("OnPlayerAttach, partida nueva");
            } else {
                if !this.m_restoredSeen {
                    this.GenerateCampaignId("OnPlayerAttach, partida cargada sin OnRestored");
                }
            }
        }
        this.WriteCampaignFact();
    }

    private func ReadCampaignFact() -> Int32 {
        let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
        if !IsDefined(quests) {
            return 0;
        }
        return quests.GetFact(n"gr_campaign_id");
    }

    private func WriteCampaignFact() {
        if this.m_campaignId == 0 {
            return;
        }
        let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGameInstance());
        if IsDefined(quests) && quests.GetFact(n"gr_campaign_id") != this.m_campaignId {
            quests.SetFact(n"gr_campaign_id", this.m_campaignId);
        }
    }

    public func IsInGame() -> Bool {
        let requests: wref<inkISystemRequestsHandler> = GameInstance.GetSystemRequestsHandler();
        return IsDefined(requests) && !requests.IsPreGame();
    }

    private func GenerateCampaignId(source: String) {
        if this.m_campaignId != 0 {
            return;
        }
        let fact: Int32 = this.ReadCampaignFact();
        if fact > 0 {
            this.m_campaignId = fact;
            GRLog("Campana recuperada del fact: " + IntToString(fact) + " (" + source + ")");
        } else {
            this.m_campaignId = RandRange(100000, 999999999);
            GRLog("Nueva campana: " + IntToString(this.m_campaignId) + " (" + source + ")");
            this.WriteCampaignFact();
        }
    }

    public func GetCampaignId() -> Int32 {
        return this.m_campaignId;
    }

    public func GetText(key: String) -> String {
        return LocalizationSystem.GetInstance(this.GetGameInstance()).GetText(key);
    }
}
