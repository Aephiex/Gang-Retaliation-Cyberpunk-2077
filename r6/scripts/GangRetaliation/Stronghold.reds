module GangRetaliation

// Guaridas fijas, una por banda (sitios probados en el juego). Lua pasa quienes viven en cada una
// (Nemesis vivos de la banda, Jefe primero) y los guardias. Ocupada = tiene al menos un Nemesis vivo:
// solo esas salen en el mapa y solo esas se generan. Una sola activa a la vez (GRSpawner tiene un solo
// grupo de guarida): al acercarse V (<70 m, SpawnDistance) a la ocupada mas cercana aparecen en sus puestos; si V
// se aleja (>250 m) sin combate, desaparecen.
// No aparecen todos de golpe: cada puesto espera a tener el suelo cargado debajo y a que V no lo este mirando
// (FillPosts). Antes aparecian todos con V a 120 m y quedaban flotando y sin reaccionar (bug de Nexus, 1.4.0).
// Las muertes de Nemesis van por el camino normal de GRSpawner (MarkDead -> processDeaths en Lua).
//
// Guaridas automaticas: cada banda con candidatos en GRStrongholdCandidates (POI Outpost/GangWatch del juego) elige
// sola donde vive; la posicion sale del mappin del POI en runtime (ScanMappins). La eleccion se guarda en la partida
// (m_chosen + posicion). Se elige al empezar si la banda no esta localizada (AutoChoose), al tomar la guarida (se
// muda y el intel vuelve a 0) y si la revalidacion al acercarse falla sin estar localizada (Revalidate). VoodooBoys
// y Barghest no tienen candidatos: siguen en su sitio fijo. Sin candidato valido: sitio fijo.
public class GRStronghold extends ScriptableSystem {
    // Sitios (arrays paralelos, un indice por guarida). m_sitePos = donde esta ahora; m_siteFixed = el sitio fijo.
    private let m_siteGangs: array<String>;
    private let m_sitePos: array<Vector4>;
    private let m_siteFixed: array<Vector4>;
    // Ultimo "sin candidato valido" logueado por sitio (no repetirlo en cada reintento).
    private let m_siteChoiceLog: array<String>;

    // Eleccion por banda, paralelo a GRIntelSystem.Gangs(): indice del candidato + 1 (0 = sitio fijo) y su posicion.
    private persistent let m_chosen: array<Int32>;
    private persistent let m_chosenX: array<Float>;
    private persistent let m_chosenY: array<Float>;
    private persistent let m_chosenZ: array<Float>;
    private let m_gangList: array<String>;

    // Candidatos: copia de GRStrongholdCandidates (una sola vez) + lo que se sabe de cada uno en esta sesion.
    private let m_candLoaded: Bool;
    private let m_candCount: Int32;
    private let m_candGangs: array<String>;
    private let m_candIds: array<String>;
    private let m_candVariants: array<Int32>;
    private let m_candHashes: array<Uint32>;
    // Plan B: hash que da el journal para el path de cada candidato (0 = el journal no tiene esa entrada).
    private let m_candJournalHashes: array<Uint32>;
    private let m_candJournalDone: Bool;
    private let m_journalFound: Int32;
    private let m_journalSame: Int32;
    private let m_journalExample: String;
    private let m_candPos: array<Vector4>;
    private let m_candKnown: array<Bool>;
    // Fallo los puestos en la revalidacion: no se vuelve a elegir en esta sesion.
    private let m_candBad: array<Bool>;
    private let m_candFound: Int32;

    // Ultimo escaneo de mappins: posiciones de mision y de zona segura, y numeros para el log.
    private let m_questPos: array<Vector4>;
    private let m_safePos: array<Vector4>;
    private let m_ticks: Int32;
    private let m_scanTick: Int32;
    private let m_scanDone: Bool;
    private let m_scanTries: Int32;
    private let m_scanLogged: Bool;
    private let m_scanTotal: Int32;
    private let m_scanVariant: Int32;
    private let m_scanPoi: Int32;
    private let m_scanStatic: Int32;
    private let m_scanJournal: Int32;
    private let m_scanUnmatched: Int32;
    private let m_scanSecure: Int32;
    private let m_scanExample: String;
    // Ticks hasta el proximo intento de elegir (bandas que quedaron sin candidato valido).
    private let m_choiceWait: Int32;

    // Revalidacion de la visita en curso: sitio + 1 (0 = ninguna), puestos ya validados, chequeo de cerca hecho.
    private let m_visitSite: Int32;
    private let m_visitPosts: Bool;
    private let m_visitNear: Bool;
    private let m_visitTries: Int32;
    private let m_siteMembers: array<Int32>;
    private let m_siteGuards: array<String>;
    private let m_siteMappins: array<NewMappinID>;
    private let m_siteHasMappin: array<Bool>;
    // Marca de cada mappin (va en su scriptData): se guarda aca para que no se libere mientras el mappin exista.
    private let m_siteMarks: array<ref<GRStrongholdMappinData>>;

    // Miembros de todas las guaridas (arrays paralelos; m_memberSites = indice del sitio donde viven).
    private let m_memberSites: array<Int32>;
    private let m_ids: array<Int32>;
    private let m_records: array<String>;
    private let m_appearances: array<String>;
    private let m_speakers: array<String>;

    private let m_active: Bool;
    private let m_activeSite: Int32;
    // Centro de la guarida activa: al tomarla el sitio se muda (m_sitePos cambia) pero los cuerpos siguen aca.
    private let m_activePos: Vector4;
    private let m_cleared: Bool;

    // Puestos de la guarida activa que todavia no aparecieron (ver FillPosts). m_populating = quedan pendientes.
    private let m_pending: array<ref<GRPendingPost>>;
    private let m_populating: Bool;
    // Ya se aviso a Lua ("spawned:") y se marco como localizada: al aparecer el primero.
    private let m_announced: Bool;
    private let m_fillTicks: Int32;
    private let m_placed: Int32;
    private let m_failed: Int32;
    // Para el resumen del log: esperaron suelo / aparecieron sin suelo / esperaron a que V no mire / aparecieron a
    // la vista / se bajaron al suelo.
    private let m_fillStats: array<Int32>;

    // Para Lua, con la banda: "spawned:Animals", "cleared:Animals", "left:Animals".
    private let m_events: array<String>;

    // Filtro "GUARIDAS" del mapa grande (ver los wrappers de WorldMapMenuGameController, mas abajo).
    // m_mapFilterSeeded: ya se prendio una vez en esta partida (despues manda la casilla del jugador).
    private persistent let m_mapFilterSeeded: Bool;
    // Lo ultimo que aviso el mapa: el filtro rapido es PERSONALIZADA / la casilla GUARIDAS esta marcada.
    private let m_mapCustom: Bool;
    private let m_mapFilterOn: Bool;

    public static func Get(gi: GameInstance) -> ref<GRStronghold> {
        return GameInstance.GetScriptableSystemsContainer(gi).Get(n"GangRetaliation.GRStronghold") as GRStronghold;
    }

    // Valor del enum nativo que usa la casilla GUARIDAS. El enum no se puede ampliar: se toma uno que el juego
    // define pero no usa en ningun grupo de filtro (record WorldMap.RelicDeviceFilter, sin grupo). Drug Dealer hace
    // lo mismo con VehicleForSaleFilter. Tiene que coincidir con filterType en r6/tweaks/GangRetaliation/intel.yaml.
    public static func MapFilter() -> gamedataWorldMapFilter {
        return gamedataWorldMapFilter.RelicDeviceFilter;
    }

    public func IsMapFilterSeeded() -> Bool { return this.m_mapFilterSeeded; }
    public func IsMapCustom() -> Bool { return this.m_mapCustom; }
    public func IsMapFilterOn() -> Bool { return this.m_mapFilterOn; }

    public func MarkMapFilterSeeded() {
        this.m_mapFilterSeeded = true;
        GRLog("Mapa: filtro GUARIDAS prendido por primera vez en esta partida");
    }

    // Lo llama el mapa grande (hilo de UI) al abrirse, al cambiar el filtro rapido y al marcar la casilla.
    public func SetMapFilter(custom: Bool, on: Bool) {
        let changed: Bool = (custom && !this.m_mapCustom) || (!custom && this.m_mapCustom)
            || (on && !this.m_mapFilterOn) || (!on && this.m_mapFilterOn);
        this.m_mapCustom = custom;
        this.m_mapFilterOn = on;
        if changed {
            let customText: String = custom ? "si" : "no";
            let onText: String = on ? "marcada" : "sin marcar";
            GRLog("Mapa: filtro rapido PERSONALIZADA = " + customText + ", casilla GUARIDAS = " + onText);
        }
    }

    // V tiene que estar a menos de esto del centro (en planta) para que la guarida empiece a aparecer. Eran 120 m:
    // mas lejos que cualquier emboscada a pie (30-70 m), que son las que funcionan bien.
    public static func SpawnDistance() -> Float { return 70.0; }
    // Un puesto que V tiene a la vista aparece igual si V ya esta a menos de esto, o tras SightWait segundos.
    public static func ForcedDistance() -> Float { return 45.0; }
    public static func SightWait() -> Int32 { return 8; }
    // Segundos que un puesto espera a que cargue el suelo debajo antes de aparecer igual.
    public static func GroundWait() -> Int32 { return 10; }
    // Segundos que se reintenta un puesto sin sitio en el navmesh antes de darlo por perdido.
    public static func SpotWait() -> Int32 { return 5; }
    // Guaridas automaticas: V a menos de esto = empieza la visita y se revalida el sitio (termina a mas de 200 m).
    public static func CheckDistance() -> Float { return 150.0; }
    // Puestos validos (de 20, TestSite) que necesita un sitio para servir de guarida.
    public static func MinPosts() -> Int32 { return 14; }

    private func OnDetach() {
        let i: Int32 = 0;
        while i < ArraySize(this.m_siteGangs) {
            this.RemoveSiteMappin(i);
            i += 1;
        }
    }

    // Coordenadas de data/site_candidates.json (todas con 20 puestos validos, salvo TygerClaws con 17).
    private func EnsureSites() {
        if ArraySize(this.m_siteGangs) > 0 {
            return;
        }
        this.AddSite("Animals", -2405.2426757813, -2084.2224121094, 9.0001068115234);
        // Dogtown solo existe con Phantom Liberty.
        if IsEP1() {
            this.AddSite("Barghest", -1825.90527, -2639.56909, 40.3169174);
        }
        this.AddSite("Maelstrom", -1183.3427734375, 1302.7615966797, 18.575248718262);
        this.AddSite("Scavengers", -860.226562, 2793.70581, 38.5733261);
        this.AddSite("SixthStreet", 63.618316650391, -1828.0014648438, -10.104141235352);
        this.AddSite("TygerClaws", -361.50540161133, 557.77117919922, 31.197227478027);
        this.AddSite("Valentinos", -823.60107421875, -388.01766967773, 8.1999969482422);
        this.AddSite("VoodooBoys", -1964.0188, -1952.28345, 18.1248322);
        this.AddSite("Wraiths", 4025.73438, 6.36502838, 118.74411);
        this.ApplyChoices();
    }

    private func AddSite(gang: String, x: Float, y: Float, z: Float) {
        let none: NewMappinID;
        ArrayPush(this.m_siteGangs, gang);
        ArrayPush(this.m_sitePos, new Vector4(x, y, z, 1.0));
        ArrayPush(this.m_siteFixed, new Vector4(x, y, z, 1.0));
        ArrayPush(this.m_siteChoiceLog, "");
        ArrayPush(this.m_siteMembers, 0);
        ArrayPush(this.m_siteGuards, "");
        ArrayPush(this.m_siteMappins, none);
        ArrayPush(this.m_siteHasMappin, false);
        ArrayPush(this.m_siteMarks, null);
    }

    private func FindSite(gang: String) -> Int32 {
        this.EnsureSites();
        let i: Int32 = 0;
        while i < ArraySize(this.m_siteGangs) {
            if Equals(this.m_siteGangs[i], gang) {
                return i;
            }
            i += 1;
        }
        return -1;
    }

    private func IsValidSite(site: Int32) -> Bool {
        this.EnsureSites();
        return site >= 0 && site < ArraySize(this.m_siteGangs);
    }

    private func RemoveSiteMappin(site: Int32) {
        if this.m_siteHasMappin[site] {
            GameInstance.GetMappinSystem(this.GetGameInstance()).UnregisterMappin(this.m_siteMappins[site]);
            this.m_siteHasMappin[site] = false;
            this.m_siteMarks[site] = null;
        }
    }

    // En el mapa solo las ocupadas y localizadas (intel de la banda al 100 %): se quita al quedar sin Nemesis y vuelve
    // sola cuando la banda tiene otra vez. Con "Debug log" prendido salen todas las ocupadas (el intel no cambia).
    // Corre en cada Tick (1 s): si el ajuste cambia en pleno juego, el mapa se pone al dia solo.
    private func RefreshMappins() {
        let intel: ref<GRIntelSystem> = GRIntelSystem.Get(this.GetGameInstance());
        let settings: ref<GRSettings> = GRSettings.Get(this.GetGameInstance());
        let debugAll: Bool = IsDefined(settings) && settings.debugLog;
        let i: Int32 = 0;
        while i < ArraySize(this.m_siteGangs) {
            let located: Bool = !IsDefined(intel) || intel.IsLocated(this.m_siteGangs[i]);
            let occupied: Bool = this.m_siteMembers[i] > 0 && (located || debugAll);
            if occupied && !this.m_siteHasMappin[i] {
                let data: MappinData;
                // OutpostVariant decide color y tipo de tooltip; el icono, el titulo y el filtro del mapa (casilla
                // GUARIDAS en vez de ESCANER NCPD) los cambian los wrappers de abajo, que reconocen el mappin por
                // esta marca.
                let mark: ref<GRStrongholdMappinData> = new GRStrongholdMappinData();
                mark.gang = this.m_siteGangs[i];
                this.m_siteMarks[i] = mark;
                data.mappinType = t"Mappins.DefaultStaticMappin";
                data.variant = gamedataMappinVariant.OutpostVariant;
                data.active = true;
                data.scriptData = mark;
                this.m_siteMappins[i] = GameInstance.GetMappinSystem(this.GetGameInstance()).RegisterMappin(data, this.m_sitePos[i]);
                this.m_siteHasMappin[i] = true;
                if located {
                    GRLog("Guarida (" + this.m_siteGangs[i] + "): ocupada y localizada, en el mapa");
                } else {
                    GRLog("Guarida (" + this.m_siteGangs[i] + "): visible por debug (intel " + IntToString(intel.GetIntel(this.m_siteGangs[i])) + "%)");
                }
            } else if !occupied && this.m_siteHasMappin[i] {
                this.RemoveSiteMappin(i);
                GRLog("Guarida (" + this.m_siteGangs[i] + "): vacia o sin localizar, fuera del mapa");
            }
            i += 1;
        }
    }

    private func MarkLocated(gang: String, reason: String) {
        let intel: ref<GRIntelSystem> = GRIntelSystem.Get(this.GetGameInstance());
        if IsDefined(intel) {
            intel.MarkLocated(gang, reason);
        }
    }

    // --- Datos desde Lua (ClearMembers una vez, luego AddMember/SetGuards por banda) ---

    public func ClearMembers() {
        this.EnsureSites();
        ArrayClear(this.m_memberSites);
        ArrayClear(this.m_ids);
        ArrayClear(this.m_records);
        ArrayClear(this.m_appearances);
        ArrayClear(this.m_speakers);
        let i: Int32 = 0;
        while i < ArraySize(this.m_siteGangs) {
            this.m_siteMembers[i] = 0;
            this.m_siteGuards[i] = "";
            i += 1;
        }
    }

    // Lua los pasa en orden (Jefe primero). Bandas sin guarida (o Barghest sin Phantom Liberty): se ignoran.
    public func AddMember(gang: String, nemesisId: Int32, recordID: String, appearance: String, speaker: String) {
        let site: Int32 = this.FindSite(gang);
        if site < 0 || this.m_siteMembers[site] >= 20 {
            return;
        }
        ArrayPush(this.m_memberSites, site);
        ArrayPush(this.m_ids, nemesisId);
        ArrayPush(this.m_records, recordID);
        ArrayPush(this.m_appearances, appearance);
        ArrayPush(this.m_speakers, speaker);
        this.m_siteMembers[site] = this.m_siteMembers[site] + 1;
    }

    // records: TweakDBIDs de los guardias separados por coma.
    public func SetGuards(gang: String, records: String) {
        let site: Int32 = this.FindSite(gang);
        if site >= 0 {
            this.m_siteGuards[site] = records;
        }
    }

    public func TakeEvent() -> String {
        if ArraySize(this.m_events) == 0 {
            return "";
        }
        let first: String = this.m_events[0];
        ArrayErase(this.m_events, 0);
        return first;
    }

    // --- Lectura (debug en vivo: REDnode solo deja llamar Get/Is/Has) ---

    public func HasSite(gang: String) -> Bool {
        return this.FindSite(gang) >= 0;
    }

    public func GetSiteCount() -> Int32 {
        this.EnsureSites();
        return ArraySize(this.m_siteGangs);
    }

    public func GetSiteGang(site: Int32) -> String {
        if !this.IsValidSite(site) {
            return "";
        }
        return this.m_siteGangs[site];
    }

    public func GetSiteMemberCount(site: Int32) -> Int32 {
        if !this.IsValidSite(site) {
            return 0;
        }
        return this.m_siteMembers[site];
    }

    public func GetSitePosition(site: Int32) -> Vector4 {
        if !this.IsValidSite(site) {
            return Vector4.EmptyVector();
        }
        return this.m_sitePos[site];
    }

    public func IsSiteOccupied(site: Int32) -> Bool {
        return this.GetSiteMemberCount(site) > 0;
    }

    public func IsActive() -> Bool {
        return this.m_active;
    }

    public func GetActiveGang() -> String {
        if !this.m_active {
            return "";
        }
        return this.GetSiteGang(this.m_activeSite);
    }

    // Indice de la guarida mas cercana a V (ocupada o no); -1 sin jugador.
    public func GetNearestSite() -> Int32 {
        return this.FindNearest(false);
    }

    public func GetNearestGang() -> String {
        return this.GetSiteGang(this.FindNearest(false));
    }

    public func GetNearestDistance() -> Float {
        return this.GetSiteDistance(this.FindNearest(false));
    }

    // Distancia de V a esa guarida (en planta); -1 si no hay jugador o el indice no existe.
    public func GetSiteDistance(site: Int32) -> Float {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !this.IsValidSite(site) || !IsDefined(player) {
            return -1.0;
        }
        let pos: Vector4 = player.GetWorldPosition();
        return Vector4.Distance2D(pos, this.m_sitePos[site]);
    }

    // Dev: una linea para el panel de CET.
    public func GetNearestInfo() -> String {
        let site: Int32 = this.FindNearest(false);
        if site < 0 {
            return "Stronghold: no sites";
        }
        let inside: Int32 = this.m_siteMembers[site];
        let info: String = "Nearest stronghold: " + this.m_siteGangs[site] + ", " + IntToString(Cast<Int32>(this.GetSiteDistance(site)))
            + " m, " + IntToString(inside) + " inside";
        if inside == 0 {
            info += " (nobody alive: off the map, won't spawn)";
        }
        if this.m_active {
            if this.m_activeSite == site {
                info += " (active)";
            } else {
                info += " | active: " + this.m_siteGangs[this.m_activeSite];
            }
        }
        return info;
    }

    private func FindNearest(occupiedOnly: Bool) -> Int32 {
        this.EnsureSites();
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) {
            return -1;
        }
        let pos: Vector4 = player.GetWorldPosition();
        let best: Int32 = -1;
        let bestDistance: Float = 0.0;
        let i: Int32 = 0;
        while i < ArraySize(this.m_siteGangs) {
            if !occupiedOnly || this.m_siteMembers[i] > 0 {
                let distance: Float = Vector4.Distance2D(pos, this.m_sitePos[i]);
                if best < 0 || distance < bestDistance {
                    best = i;
                    bestDistance = distance;
                }
            }
            i += 1;
        }
        return best;
    }

    // --- Dev ---

    // Dev: los recoge y vuelven a aparecer en el proximo tick si V sigue a menos de SpawnDistance.
    public func Respawn() {
        if this.m_active {
            GRSpawner.Get(this.GetGameInstance()).DespawnAll();
            this.m_active = false;
            this.StopPopulating();
        }
    }

    // Dev: lleva a V a la guarida de esa banda. false si la banda no tiene (Barghest sin Phantom Liberty).
    public func DevTeleport(gang: String) -> Bool {
        let site: Int32 = this.FindSite(gang);
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if site < 0 || !IsDefined(player) {
            return false;
        }
        let pos: Vector4 = this.m_sitePos[site];
        pos.Z += 0.5;
        GameInstance.GetTeleportationFacility(this.GetGameInstance()).Teleport(player, pos, Vector4.ToRotation(player.GetWorldForward()));
        return true;
    }

    // Dev: cuantos de los 20 puestos de una guarida llena entran en ese punto (sin generar a nadie).
    public func TestSite(x: Float, y: Float, z: Float) -> Int32 {
        let spawner: ref<GRSpawner> = GRSpawner.Get(this.GetGameInstance());
        let center: Vector4 = new Vector4(x, y, z, 1.0);
        let ok: Int32 = 0;
        let i: Int32 = 0;
        while i < 20 {
            let radius: Float = 0.0;
            let angle: Float = 0.0;
            if i >= 1 && i < 5 {
                radius = 5.0;
                angle = Cast<Float>(i) * 2.1;
            } else if i >= 5 && i < 13 {
                radius = 10.0;
                angle = 2.0 * Pi() * Cast<Float>(i - 5) / 8.0;
            } else if i >= 13 {
                radius = 17.0;
                angle = 2.0 * Pi() * Cast<Float>(i - 13) / 7.0 + 0.4;
            }
            if !Vector4.IsZero(this.FindPost(spawner, center, angle, radius)) {
                ok += 1;
            }
            i += 1;
        }
        return ok;
    }

    // --- Guaridas automaticas ---

    // Lugar de la banda en los arrays guardados (orden de GRIntelSystem.Gangs(), el mismo del intel).
    private func GangSlot(gang: String) -> Int32 {
        if ArraySize(this.m_gangList) == 0 {
            let gangs: array<String> = GRIntelSystem.Gangs();
            this.m_gangList = gangs;
        }
        let i: Int32 = 0;
        while i < ArraySize(this.m_gangList) {
            if Equals(this.m_gangList[i], gang) {
                return i;
            }
            i += 1;
        }
        return -1;
    }

    // Un lugar por banda antes de leer o escribir la eleccion (partidas viejas: arrays vacios = sitio fijo).
    private func EnsureChoices() {
        this.GangSlot("");
        let count: Int32 = ArraySize(this.m_gangList);
        while ArraySize(this.m_chosen) < count {
            ArrayPush(this.m_chosen, 0);
        }
        while ArraySize(this.m_chosenX) < count {
            ArrayPush(this.m_chosenX, 0.0);
        }
        while ArraySize(this.m_chosenY) < count {
            ArrayPush(this.m_chosenY, 0.0);
        }
        while ArraySize(this.m_chosenZ) < count {
            ArrayPush(this.m_chosenZ, 0.0);
        }
    }

    // Copia los arrays de GRStrongholdCandidates una sola vez (son funciones: cada llamada arma el array entero).
    private func EnsureCandidates() {
        if this.m_candLoaded {
            return;
        }
        this.m_candLoaded = true;
        let gangs: array<String> = GRStrongholdCandidates.Gangs();
        let ids: array<String> = GRStrongholdCandidates.Ids();
        let variants: array<Int32> = GRStrongholdCandidates.Variants();
        let hashes: array<Uint32> = GRStrongholdCandidates.JournalHashes();
        this.m_candGangs = gangs;
        this.m_candIds = ids;
        this.m_candVariants = variants;
        this.m_candHashes = hashes;
        this.m_candCount = Min(Min(ArraySize(gangs), ArraySize(ids)), Min(ArraySize(variants), ArraySize(hashes)));
        let i: Int32 = 0;
        while i < this.m_candCount {
            ArrayPush(this.m_candPos, Vector4.EmptyVector());
            ArrayPush(this.m_candKnown, false);
            ArrayPush(this.m_candBad, false);
            i += 1;
        }
    }

    // Plan B del hash: el que da el journal para el path de cada candidato. De paso cuenta cuantos coinciden con el
    // hash estatico del archivo generado (eso confirma o refuta el Murmur3 offline).
    private func EnsureJournalHashes() {
        if this.m_candJournalDone {
            return;
        }
        let journal: ref<JournalManager> = GameInstance.GetJournalManager(this.GetGameInstance());
        if !IsDefined(journal) {
            return;
        }
        this.m_candJournalDone = true;
        let paths: array<String> = GRStrongholdCandidates.Paths();
        let i: Int32 = 0;
        while i < this.m_candCount {
            let hash: Uint32 = 0u;
            if i < ArraySize(paths) {
                let entry: wref<JournalEntry> = journal.GetEntryByString(paths[i], "gameJournalPointOfInterestMappin");
                if IsDefined(entry) {
                    hash = Cast<Uint32>(journal.GetEntryHash(entry));
                    this.m_journalFound += 1;
                    if hash == this.m_candHashes[i] {
                        this.m_journalSame += 1;
                    } else if StrLen(this.m_journalExample) == 0 {
                        this.m_journalExample = this.m_candIds[i] + ": estatico " + ToString(this.m_candHashes[i]) + ", journal " + ToString(hash);
                    }
                }
            }
            ArrayPush(this.m_candJournalHashes, hash);
            i += 1;
        }
    }

    // Candidato con ese hash de journal: primero el hash estatico, despues el del journal (plan B). -1 = ninguno.
    private func FindCandidate(hash: Uint32, out byJournal: Bool) -> Int32 {
        byJournal = false;
        let i: Int32 = 0;
        while i < this.m_candCount {
            if this.m_candHashes[i] == hash {
                return i;
            }
            i += 1;
        }
        i = 0;
        while i < ArraySize(this.m_candJournalHashes) {
            if this.m_candJournalHashes[i] == hash && hash != 0u {
                byJournal = true;
                return i;
            }
            i += 1;
        }
        return -1;
    }

    // Variantes donde V esta a salvo o hace compras: departamentos, fixers, tiendas y servicios, puntos de entrega.
    private func IsSafeVariant(variant: gamedataMappinVariant) -> Bool {
        return Equals(variant, gamedataMappinVariant.ApartmentVariant)
            || Equals(variant, gamedataMappinVariant.Zzz05_ApartmentToPurchaseVariant)
            || Equals(variant, gamedataMappinVariant.FixerVariant)
            || Equals(variant, gamedataMappinVariant.DropboxVariant)
            || Equals(variant, gamedataMappinVariant.ServicePointBarVariant)
            || Equals(variant, gamedataMappinVariant.ServicePointClothesVariant)
            || Equals(variant, gamedataMappinVariant.ServicePointDropPointVariant)
            || Equals(variant, gamedataMappinVariant.ServicePointFoodVariant)
            || Equals(variant, gamedataMappinVariant.ServicePointGunsVariant)
            || Equals(variant, gamedataMappinVariant.ServicePointJunkVariant)
            || Equals(variant, gamedataMappinVariant.ServicePointMedsVariant)
            || Equals(variant, gamedataMappinVariant.ServicePointMeleeTrainerVariant)
            || Equals(variant, gamedataMappinVariant.ServicePointNetTrainerVariant)
            || Equals(variant, gamedataMappinVariant.ServicePointProstituteVariant)
            || Equals(variant, gamedataMappinVariant.ServicePointRipperdocVariant)
            || Equals(variant, gamedataMappinVariant.ServicePointTechVariant)
            || Equals(variant, gamedataMappinVariant.Zzz14_ServicePointBlackMarketVariant)
            || Equals(variant, gamedataMappinVariant.Zzz21_ServicePointGlamdocVariant);
    }

    // Recorre los mappins del mapa una vez: posicion de cada candidato (POI Outpost/GangWatch cuyo hash de journal es
    // el de un candidato) y posiciones de mision y de zona segura para los filtros. Solo cuando hace falta (primer
    // escaneo, al elegir, al empezar una visita) y como mucho una vez cada 5 ticks: son miles de mappins.
    private func ScanMappins() {
        this.EnsureCandidates();
        if this.m_scanDone && this.m_ticks - this.m_scanTick < 5 {
            return;
        }
        let system: ref<MappinSystem> = GameInstance.GetMappinSystem(this.GetGameInstance());
        if !IsDefined(system) {
            return;
        }
        this.m_scanDone = true;
        this.m_scanTick = this.m_ticks;
        this.EnsureJournalHashes();
        let all: array<ref<IMappin>>;
        system.GetMappins(gamemappinsMappinTargetType.Map, all);
        ArrayClear(this.m_questPos);
        ArrayClear(this.m_safePos);
        this.m_scanTotal = ArraySize(all);
        this.m_scanVariant = 0;
        this.m_scanPoi = 0;
        this.m_scanStatic = 0;
        this.m_scanJournal = 0;
        this.m_scanUnmatched = 0;
        this.m_scanSecure = 0;
        let i: Int32 = 0;
        while i < ArraySize(all) {
            let mappin: ref<IMappin> = all[i];
            if IsDefined(mappin) {
                let variant: gamedataMappinVariant = mappin.GetVariant();
                if mappin.IsQuestMappin() || mappin.IsQuestAreaMappin() {
                    ArrayPush(this.m_questPos, mappin.GetWorldPosition());
                } else if this.IsSafeVariant(variant) {
                    ArrayPush(this.m_safePos, mappin.GetWorldPosition());
                } else if Equals(variant, gamedataMappinVariant.OutpostVariant) || Equals(variant, gamedataMappinVariant.GangWatchVariant) {
                    this.m_scanVariant += 1;
                    // Los mappins de guarida del mod tambien son OutpostVariant, pero no son PointOfInterestMappin.
                    let poi: ref<PointOfInterestMappin> = mappin as PointOfInterestMappin;
                    if IsDefined(poi) {
                        this.m_scanPoi += 1;
                        let hash: Uint32 = poi.GetJournalPathHash();
                        let byJournal: Bool = false;
                        let cand: Int32 = this.FindCandidate(hash, byJournal);
                        if cand >= 0 {
                            let pos: Vector4 = poi.GetWorldPosition();
                            pos.W = 1.0;
                            this.m_candPos[cand] = pos;
                            this.m_candKnown[cand] = true;
                            if byJournal {
                                this.m_scanJournal += 1;
                            } else {
                                this.m_scanStatic += 1;
                            }
                            if poi.IsInsideSecurityAreaTrigger() {
                                this.m_scanSecure += 1;
                            }
                        } else {
                            this.m_scanUnmatched += 1;
                            if StrLen(this.m_scanExample) == 0 {
                                this.m_scanExample = ToString(hash);
                            }
                        }
                    }
                }
            }
            i += 1;
        }
        this.m_candFound = 0;
        i = 0;
        while i < this.m_candCount {
            if this.m_candKnown[i] {
                this.m_candFound += 1;
            }
            i += 1;
        }
    }

    // Una vez por sesion: lo que encontro el primer escaneo. Confirma o refuta el hash estatico y si los POI sin
    // descubrir aparecen en GetMappins.
    private func LogScan() {
        GRLog("Guaridas auto: escaneo de mappins (Map): " + IntToString(this.m_scanTotal) + " mappins, " + IntToString(this.m_scanVariant)
            + " outpost/gangwatch (" + IntToString(this.m_scanPoi) + " son POI) | candidatos con posicion " + IntToString(this.m_candFound) + "/"
            + IntToString(this.m_candCount) + " (por hash estatico " + IntToString(this.m_scanStatic) + ", por plan B journal "
            + IntToString(this.m_scanJournal) + ") | POI sin candidato " + IntToString(this.m_scanUnmatched)
            + (StrLen(this.m_scanExample) > 0 ? " (ej. hash " + this.m_scanExample + ")" : "") + " | candidatos dentro de area de seguridad "
            + IntToString(this.m_scanSecure) + " | mappins de mision " + IntToString(ArraySize(this.m_questPos)) + ", de zona segura "
            + IntToString(ArraySize(this.m_safePos)));
        GRLog("Guaridas auto: hash estatico vs journal: " + IntToString(this.m_journalSame) + " iguales de " + IntToString(this.m_journalFound)
            + " paths que el journal conoce (de " + IntToString(this.m_candCount) + " candidatos)"
            + (StrLen(this.m_journalExample) > 0 ? " | distinto, ej. " + this.m_journalExample : ""));
        let line: String = "";
        let g: Int32 = 0;
        while g < ArraySize(this.m_gangList) {
            let total: Int32 = 0;
            let known: Int32 = 0;
            let i: Int32 = 0;
            while i < this.m_candCount {
                if Equals(this.m_candGangs[i], this.m_gangList[g]) {
                    total += 1;
                    if this.m_candKnown[i] {
                        known += 1;
                    }
                }
                i += 1;
            }
            if StrLen(line) > 0 {
                line += ", ";
            }
            line += this.m_gangList[g] + " " + IntToString(known) + "/" + IntToString(total);
            g += 1;
        }
        GRLog("Guaridas auto: candidatos con posicion por banda: " + line);
        if this.m_scanPoi == 0 {
            // Para saber si el problema es el tipo de lista: cuantos mappins dan las otras dos.
            let system: ref<MappinSystem> = GameInstance.GetMappinSystem(this.GetGameInstance());
            let world: array<ref<IMappin>>;
            let minimap: array<ref<IMappin>>;
            system.GetMappins(gamemappinsMappinTargetType.World, world);
            system.GetMappins(gamemappinsMappinTargetType.Minimap, minimap);
            GRLog("Guaridas auto: ningun POI outpost/gangwatch en GetMappins(Map) (" + IntToString(this.m_scanVariant)
                + " mappins de esas variantes en total): los POI sin descubrir no aparecen o no son PointOfInterestMappin. Otras listas: World "
                + IntToString(ArraySize(world)) + ", Minimap " + IntToString(ArraySize(minimap)) + " mappins. Todas las bandas siguen en el sitio fijo");
        }
    }

    // Eleccion guardada de ese sitio: indice del candidato + 1 (0 = sitio fijo).
    private func GetChosen(site: Int32) -> Int32 {
        let slot: Int32 = this.GangSlot(this.m_siteGangs[site]);
        if slot < 0 || slot >= ArraySize(this.m_chosen) {
            return 0;
        }
        return this.m_chosen[slot];
    }

    // Nombre del lugar donde esta ahora: el ma_id del candidato o "sitio fijo".
    private func SiteLabel(site: Int32) -> String {
        let chosen: Int32 = this.GetChosen(site);
        if chosen <= 0 || chosen > this.m_candCount {
            return "sitio fijo";
        }
        return this.m_candIds[chosen - 1];
    }

    // Al crear los sitios: los que tienen eleccion guardada en la partida van a esa posicion.
    private func ApplyChoices() {
        this.EnsureCandidates();
        this.EnsureChoices();
        let i: Int32 = 0;
        while i < ArraySize(this.m_siteGangs) {
            let slot: Int32 = this.GangSlot(this.m_siteGangs[i]);
            if slot >= 0 && this.m_chosen[slot] > 0 {
                let cand: Int32 = this.m_chosen[slot] - 1;
                let x: Float = this.m_chosenX[slot];
                let y: Float = this.m_chosenY[slot];
                // El indice tiene que seguir siendo de esta banda (el archivo de candidatos se regenera).
                if cand < this.m_candCount && Equals(this.m_candGangs[cand], this.m_siteGangs[i]) && (AbsF(x) > 0.01 || AbsF(y) > 0.01) {
                    this.m_sitePos[i] = new Vector4(x, y, this.m_chosenZ[slot], 1.0);
                    GRLog("Guarida (" + this.m_siteGangs[i] + "): en " + this.m_candIds[cand] + " (eleccion guardada en la partida)");
                } else {
                    this.m_chosen[slot] = 0;
                    GRLog("Guarida (" + this.m_siteGangs[i] + "): eleccion guardada invalida (candidato " + IntToString(cand) + "), vuelve al sitio fijo");
                }
            }
            i += 1;
        }
    }

    // Hay un mappin de mision (mission = true) o de zona segura (false) del ultimo escaneo a menos de radius, en planta.
    private func IsNearMappin(mission: Bool, pos: Vector4, radius: Float) -> Bool {
        let count: Int32 = mission ? ArraySize(this.m_questPos) : ArraySize(this.m_safePos);
        let i: Int32 = 0;
        while i < count {
            let other: Vector4 = mission ? this.m_questPos[i] : this.m_safePos[i];
            if Vector4.Distance2D(pos, other) < radius {
                return true;
            }
            i += 1;
        }
        return false;
    }

    // A menos de radius de la guarida actual de otra banda.
    private func IsNearOtherSite(site: Int32, pos: Vector4, radius: Float) -> Bool {
        let i: Int32 = 0;
        while i < ArraySize(this.m_sitePos) {
            if i != site && Vector4.Distance2D(pos, this.m_sitePos[i]) < radius {
                return true;
            }
            i += 1;
        }
        return false;
    }

    // Candidato para ese sitio, o -1 si ninguno pasa. Filtros: de esa banda, con posicion conocida, a 200 m o mas de V,
    // a 400 m o mas de las otras guaridas y de avoid (la recien tomada), sin zona segura a menos de 60 m ni mappin de
    // mision a menos de 150 m. Entre los validos, al azar, primero los outpost (variante 0) y si no hay, gangwatch.
    // Usa las listas del ultimo ScanMappins: llamarlo antes.
    private func ChooseCandidate(site: Int32, exclude: Int32, avoid: Vector4, useAvoid: Bool, out discarded: String) -> Int32 {
        let gang: String = this.m_siteGangs[site];
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        let hasPlayer: Bool = IsDefined(player);
        let playerPos: Vector4;
        if hasPlayer {
            playerPos = player.GetWorldPosition();
        }
        let outposts: array<Int32>;
        let watches: array<Int32>;
        let nMission: Int32 = 0;
        let nSafe: Int32 = 0;
        let nOther: Int32 = 0;
        let nPlayer: Int32 = 0;
        let nNoPos: Int32 = 0;
        let nBad: Int32 = 0;
        let i: Int32 = 0;
        while i < this.m_candCount {
            if i != exclude && Equals(this.m_candGangs[i], gang) {
                let pos: Vector4 = this.m_candPos[i];
                if !this.m_candKnown[i] {
                    nNoPos += 1;
                } else if this.m_candBad[i] {
                    nBad += 1;
                } else if hasPlayer && Vector4.Distance2D(pos, playerPos) < 200.0 {
                    nPlayer += 1;
                } else if this.IsNearOtherSite(site, pos, 400.0) || (useAvoid && Vector4.Distance2D(pos, avoid) < 400.0) {
                    nOther += 1;
                } else if this.IsNearMappin(false, pos, 60.0) {
                    nSafe += 1;
                } else if this.IsNearMappin(true, pos, 150.0) {
                    nMission += 1;
                } else if this.m_candVariants[i] == 0 {
                    ArrayPush(outposts, i);
                } else {
                    ArrayPush(watches, i);
                }
            }
            i += 1;
        }
        discarded = "descartados: mision " + IntToString(nMission) + ", zona segura " + IntToString(nSafe) + ", cerca de otra "
            + IntToString(nOther) + ", cerca de V " + IntToString(nPlayer) + " | sin posicion " + IntToString(nNoPos) + ", sin puestos "
            + IntToString(nBad) + " | validos: " + IntToString(ArraySize(outposts)) + " outpost, " + IntToString(ArraySize(watches)) + " gangwatch";
        let count: Int32 = ArraySize(outposts);
        if count > 0 {
            return outposts[Min(RandRange(0, count), count - 1)];
        }
        count = ArraySize(watches);
        if count > 0 {
            return watches[Min(RandRange(0, count), count - 1)];
        }
        return -1;
    }

    // Pone el sitio en ese candidato (-1 = sitio fijo) y lo guarda en la partida. El mappin se quita: RefreshMappins lo
    // vuelve a registrar en la posicion nueva si corresponde (ocupada y localizada, o debug).
    private func MoveSite(site: Int32, cand: Int32) {
        this.EnsureChoices();
        let slot: Int32 = this.GangSlot(this.m_siteGangs[site]);
        if slot < 0 {
            return;
        }
        if cand >= 0 {
            let pos: Vector4 = this.m_candPos[cand];
            this.m_chosen[slot] = cand + 1;
            this.m_chosenX[slot] = pos.X;
            this.m_chosenY[slot] = pos.Y;
            this.m_chosenZ[slot] = pos.Z;
            this.m_sitePos[site] = pos;
        } else {
            this.m_chosen[slot] = 0;
            this.m_chosenX[slot] = 0.0;
            this.m_chosenY[slot] = 0.0;
            this.m_chosenZ[slot] = 0.0;
            this.m_sitePos[site] = this.m_siteFixed[site];
        }
        this.m_siteChoiceLog[site] = "";
        this.RemoveSiteMappin(site);
        if this.m_visitSite == site + 1 {
            this.m_visitSite = 0;
        }
    }

    private func LogChosen(site: Int32, cand: Int32, discarded: String) {
        GRLog("Guarida (" + this.m_siteGangs[site] + "): elegida " + this.m_candIds[cand] + " (" + (this.m_candVariants[cand] == 0 ? "outpost" : "gangwatch")
            + ") a " + IntToString(Cast<Int32>(this.GetSiteDistance(site))) + " m de V | " + discarded);
    }

    // Muda la guarida a otro candidato, lejos de donde esta ahora; si ninguno pasa los filtros, al sitio fijo.
    // false = no se movio (ya estaba en el sitio fijo y no hay candidato valido).
    private func Relocate(site: Int32, reason: String) -> Bool {
        let gang: String = this.m_siteGangs[site];
        let current: Int32 = this.GetChosen(site) - 1;
        let oldPos: Vector4 = this.m_sitePos[site];
        let oldLabel: String = this.SiteLabel(site);
        this.ScanMappins();
        let discarded: String;
        let cand: Int32 = this.ChooseCandidate(site, current, oldPos, true, discarded);
        if cand < 0 && current < 0 {
            GRLog("Guarida (" + gang + "): no se muda (" + reason + "), sin candidato valido: sigue en el sitio fijo | " + discarded);
            return false;
        }
        this.MoveSite(site, cand);
        if cand >= 0 {
            this.LogChosen(site, cand, discarded);
        } else {
            GRLog("Guarida (" + gang + "): sin candidato valido, vuelve al sitio fijo | " + discarded);
        }
        GRLog("Guarida (" + gang + "): se muda de " + oldLabel + " a " + this.SiteLabel(site) + " (" + reason + ")");
        return true;
    }

    // Cada tick: primer escaneo (a los 3 s y cada 5 s hasta que aparezcan candidatos, 6 intentos) y despues las
    // elecciones pendientes.
    private func TickCandidates() {
        this.m_ticks += 1;
        if !this.m_scanLogged {
            if this.m_ticks < 3 || (this.m_ticks - 3) % 5 != 0 {
                return;
            }
            this.ScanMappins();
            this.m_scanTries += 1;
            if this.m_candFound > 0 || this.m_scanTries >= 6 {
                this.m_scanLogged = true;
                this.LogScan();
            }
            return;
        }
        if this.m_choiceWait > 0 {
            this.m_choiceWait -= 1;
            return;
        }
        this.AutoChoose();
    }

    // Bandas sin eleccion y sin localizar: eligen guarida. Una ya localizada en el sitio fijo se respeta hasta que la
    // tomen. No se elige con V cerca del sitio actual ni con la guarida activa. Las que quedan sin candidato valido
    // reintentan cada 60 s (cada intento escanea los mappins).
    private func AutoChoose() {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) {
            return;
        }
        let intel: ref<GRIntelSystem> = GRIntelSystem.Get(this.GetGameInstance());
        if !IsDefined(intel) {
            return;
        }
        let none: Vector4;
        let pending: Bool = false;
        let scanned: Bool = false;
        let i: Int32 = 0;
        while i < ArraySize(this.m_siteGangs) {
            let gang: String = this.m_siteGangs[i];
            if this.GetChosen(i) == 0 && !intel.IsLocated(gang) && this.HasCandidates(gang) {
                let busy: Bool = (this.m_active && this.m_activeSite == i) || this.GetSiteDistance(i) < 250.0;
                if busy {
                    pending = true;
                } else {
                    if !scanned {
                        this.ScanMappins();
                        scanned = true;
                    }
                    let discarded: String;
                    let cand: Int32 = this.ChooseCandidate(i, -1, none, false, discarded);
                    if cand >= 0 {
                        this.MoveSite(i, cand);
                        this.LogChosen(i, cand, discarded);
                    } else {
                        pending = true;
                        if NotEquals(this.m_siteChoiceLog[i], discarded) {
                            this.m_siteChoiceLog[i] = discarded;
                            GRLog("Guarida (" + gang + "): sin candidato valido, sigue en el sitio fijo (reintenta cada 60 s) | " + discarded);
                        }
                    }
                }
            }
            i += 1;
        }
        if pending {
            this.m_choiceWait = 60;
        }
    }

    private func HasCandidates(gang: String) -> Bool {
        let i: Int32 = 0;
        while i < this.m_candCount {
            if Equals(this.m_candGangs[i], gang) {
                return true;
            }
            i += 1;
        }
        return false;
    }

    // Policias de la NCPD en pie a menos de radius del punto (en planta). Busca entre los NPC cargados alrededor de V.
    private func CountPoliceNear(pos: Vector4, radius: Float) -> Int32 {
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) {
            return 0;
        }
        let query: TargetSearchQuery;
        query.testedSet = TargetingSet.Complete;
        query.searchFilter = TSF_NPC();
        query.maxDistance = Vector4.Distance(player.GetWorldPosition(), pos) + radius;
        query.filterObjectByDistance = true;
        query.includeSecondaryTargets = false;
        query.ignoreInstigator = true;
        let parts: array<TS_TargetPartInfo>;
        GameInstance.GetTargetingSystem(this.GetGameInstance()).GetTargetParts(player, query, parts);
        let seen: array<EntityID>;
        let i: Int32 = 0;
        while i < ArraySize(parts) {
            let component: wref<TargetingComponent> = TS_TargetPartInfo.GetComponent(parts[i]);
            if IsDefined(component) {
                let npc: ref<ScriptedPuppet> = component.GetEntity() as ScriptedPuppet;
                if IsDefined(npc) && !GRDetection.IsNeutralized(npc) && Vector4.Distance2D(npc.GetWorldPosition(), pos) < radius
                    && !ArrayContains(seen, npc.GetEntityID()) {
                    let record: wref<Character_Record> = npc.GetRecord();
                    if IsDefined(record) && IsDefined(record.Affiliation()) && Equals(record.Affiliation().Type(), gamedataAffiliation.NCPD) {
                        ArrayPush(seen, npc.GetEntityID());
                    }
                }
            }
            i += 1;
        }
        return ArraySize(seen);
    }

    // Revalida el sitio cuando V se acerca. near = false: al empezar la visita (CheckDistance); near = true: justo antes
    // de poblar (SpawnDistance). Devuelve 0 = seguir, 1 = esperar un tick mas, 2 = la guarida se mudo.
    // - Mision (solo de lejos): objetivo seguido cerca de V o mappin de mision a menos de 150 m del sitio.
    // - Puestos: TestSite >= MinPosts. De lejos el navmesh puede no estar cargado: un mal resultado ahi no decide, se
    //   repite de cerca, y de cerca se reintenta SpotWait ticks (igual que los puestos al poblar). En el ultimo intento
    //   prueba con el centro bajado al navmesh (el mappin de un POI puede estar por encima del suelo).
    // - NCPD a menos de 50 m (entre los NPC que haya cargados).
    // Si falla y la banda no esta localizada, se muda en silencio. Si esta localizada no se toca: V la esta buscando.
    private func Revalidate(spawner: ref<GRSpawner>, site: Int32, near: Bool) -> Int32 {
        let gang: String = this.m_siteGangs[site];
        let pos: Vector4 = this.m_sitePos[site];
        let where: String = near ? "de cerca" : "de lejos";
        let reason: String = "";
        let badPosts: Bool = false;
        if !near {
            this.ScanMappins();
            if spawner.IsQuestObjectiveNearby() {
                reason = "objetivo de mision seguido a menos de 150 m de V";
            } else if this.IsNearMappin(true, pos, 150.0) {
                reason = "mappin de mision a menos de 150 m";
            }
        }
        let postsText: String = "ya validados";
        if StrLen(reason) == 0 && !this.m_visitPosts {
            let nav: ref<NavigationSystem> = GameInstance.GetNavigationSystem(this.GetGameInstance());
            let streamed: Bool = nav.IsNavmeshStreamedInLocation(pos, 2.0);
            let posts: Int32 = this.TestSite(pos.X, pos.Y, pos.Z);
            postsText = IntToString(posts) + "/20 (navmesh " + (streamed ? "cargado" : "sin cargar") + ")";
            if posts >= GRStronghold.MinPosts() {
                this.m_visitPosts = true;
            } else if near {
                this.m_visitTries += 1;
                if this.m_visitTries < GRStronghold.SpotWait() {
                    return 1;
                }
                let snapped: Vector4 = nav.GetNearestNavmeshPointBelowOnlyHumanNavmesh(pos + new Vector4(0.0, 0.0, 2.0, 0.0), 3.0, 6);
                let retry: Int32 = 0;
                if !Vector4.IsZero(snapped) && Vector4.Distance(snapped, pos) > 0.5 {
                    retry = this.TestSite(snapped.X, snapped.Y, snapped.Z);
                }
                if retry >= GRStronghold.MinPosts() {
                    snapped.W = 1.0;
                    GRLog("Guarida (" + gang + "): centro de " + this.SiteLabel(site) + " ajustado al navmesh (" + IntToString(posts) + " -> "
                        + IntToString(retry) + " puestos; Z " + FloatToStringPrec(pos.Z, 2) + " -> " + FloatToStringPrec(snapped.Z, 2) + ", "
                        + FloatToStringPrec(Vector4.Distance2D(snapped, pos), 1) + " m en planta)");
                    this.SetSitePosition(site, snapped);
                    pos = snapped;
                    postsText = IntToString(retry) + "/20 (centro ajustado)";
                    this.m_visitPosts = true;
                } else {
                    reason = "solo " + IntToString(posts) + " de 20 puestos (navmesh " + (streamed ? "cargado" : "sin cargar") + ")";
                    badPosts = true;
                }
            } else {
                postsText += ", se repite de cerca";
            }
        }
        if StrLen(reason) == 0 {
            let police: Int32 = this.CountPoliceNear(pos, 50.0);
            if police > 0 {
                reason = IntToString(police) + " NCPD a menos de 50 m";
            }
        }
        if StrLen(reason) == 0 {
            GRLog("Guarida (" + gang + "): revalidada " + where + " (" + this.SiteLabel(site) + ", V a "
                + IntToString(Cast<Int32>(this.GetSiteDistance(site))) + " m): sin mision, sin NCPD, puestos " + postsText);
            return 0;
        }
        let intel: ref<GRIntelSystem> = GRIntelSystem.Get(this.GetGameInstance());
        if !IsDefined(intel) || intel.IsLocated(gang) {
            GRLog("Guarida (" + gang + "): falla la revalidacion " + where + " (" + reason + ") pero ya esta localizada: no se muda");
            return 0;
        }
        let current: Int32 = this.GetChosen(site) - 1;
        if badPosts && current >= 0 && current < this.m_candCount {
            this.m_candBad[current] = true;
        }
        GRLog("Guarida (" + gang + "): falla la revalidacion " + where + " de " + this.SiteLabel(site) + " (" + reason + "), se muda en silencio");
        if this.Relocate(site, "revalidacion") {
            return 2;
        }
        return 0;
    }

    // Corrige la posicion del sitio (centro ajustado al navmesh) y la guarda si es un candidato elegido.
    private func SetSitePosition(site: Int32, pos: Vector4) {
        this.m_sitePos[site] = pos;
        let slot: Int32 = this.GangSlot(this.m_siteGangs[site]);
        if slot >= 0 && slot < ArraySize(this.m_chosen) && this.m_chosen[slot] > 0 {
            this.m_chosenX[slot] = pos.X;
            this.m_chosenY[slot] = pos.Y;
            this.m_chosenZ[slot] = pos.Z;
        }
        this.RemoveSiteMappin(site);
    }

    // Dev (consola CET): fuerza la mudanza de la guarida de esa banda, igual que si la hubieran tomado (intel a 0).
    // print(Game.GetScriptableSystemsContainer():Get("GangRetaliation.GRStronghold"):DevMove("Maelstrom"))
    public func DevMove(gang: String) -> String {
        let site: Int32 = this.FindSite(gang);
        if site < 0 {
            return "No stronghold for " + gang;
        }
        let from: String = this.SiteLabel(site);
        if !this.Relocate(site, "dev") {
            return gang + ": no valid candidate, stays at " + from + " (see log)";
        }
        let intel: ref<GRIntelSystem> = GRIntelSystem.Get(this.GetGameInstance());
        if IsDefined(intel) {
            intel.ResetIntel(gang, "mudanza dev");
        }
        return gang + ": " + from + " -> " + this.SiteLabel(site) + ", " + IntToString(Cast<Int32>(this.GetSiteDistance(site))) + " m from V";
    }

    // Dev: donde esta la guarida de esa banda (candidato o sitio fijo), posicion y distancia a V.
    public func GetSiteInfo(gang: String) -> String {
        let site: Int32 = this.FindSite(gang);
        if site < 0 {
            return "No stronghold for " + gang;
        }
        let pos: Vector4 = this.m_sitePos[site];
        return gang + ": " + this.SiteLabel(site) + " @ " + FloatToStringPrec(pos.X, 1) + ", " + FloatToStringPrec(pos.Y, 1) + ", "
            + FloatToStringPrec(pos.Z, 1) + " | " + IntToString(Cast<Int32>(this.GetSiteDistance(site))) + " m from V, "
            + IntToString(this.m_siteMembers[site]) + " inside | candidates with position " + IntToString(this.m_candFound) + "/"
            + IntToString(this.m_candCount);
    }

    // --- Tick (1 s, desde Lua, hilo principal) ---

    public func Tick() {
        this.EnsureSites();
        this.TickCandidates();
        this.RefreshMappins();
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) {
            return;
        }
        let spawner: ref<GRSpawner> = GRSpawner.Get(this.GetGameInstance());

        if this.m_active {
            if !spawner.IsStrongholdActive() {
                this.m_active = false;
                this.StopPopulating();
                return;
            }
            let gang: String = this.m_siteGangs[this.m_activeSite];
            if this.m_populating {
                this.FillPosts(spawner, player);
                if !this.m_active {
                    return;
                }
            }
            // Mientras queden puestos por aparecer no esta tomada (al principio no hay nadie en pie).
            if !this.m_populating && !this.m_cleared && spawner.CountStanding() == 0 {
                this.m_cleared = true;
                ArrayPush(this.m_events, "cleared:" + gang);
                GRLog("Guarida (" + gang + "): tomada");
                // La banda se muda a otro candidato y hay que volver a encontrarla (intel a 0). Si no tiene adonde
                // ir (sin candidatos o ninguno valido estando ya en el sitio fijo) queda localizada, como antes.
                if this.Relocate(this.m_activeSite, "tomada") {
                    let intel: ref<GRIntelSystem> = GRIntelSystem.Get(this.GetGameInstance());
                    if IsDefined(intel) {
                        intel.ResetIntel(gang, "guarida tomada, la banda se muda");
                    }
                } else {
                    this.MarkLocated(gang, "guarida tomada");
                }
            }
            // Contra m_activePos: tras la mudanza m_sitePos ya es el sitio nuevo y los cuerpos siguen en el viejo.
            if Vector4.Distance2D(player.GetWorldPosition(), this.m_activePos) > 250.0 && !player.IsInCombat() {
                spawner.DespawnAll();
                this.m_active = false;
                this.StopPopulating();
                ArrayPush(this.m_events, "left:" + gang);
                GRLog("Guarida (" + gang + "): V se fue, se recogen");
            }
            return;
        }

        // Ninguna activa: la ocupada mas cercana.
        let site: Int32 = this.FindNearest(true);
        if site < 0 {
            this.m_visitSite = 0;
            return;
        }
        let distance: Float = this.GetSiteDistance(site);
        // Visita = V entra a menos de CheckDistance; termina cuando se aleja a mas de 200 m. Al empezar se revalida
        // el sitio de lejos (mision, NCPD, puestos si el navmesh ya esta).
        if this.m_visitSite != site + 1 {
            this.m_visitSite = 0;
            if distance > GRStronghold.CheckDistance() {
                return;
            }
            this.m_visitSite = site + 1;
            this.m_visitPosts = false;
            this.m_visitNear = false;
            this.m_visitTries = 0;
            if this.Revalidate(spawner, site, false) == 2 {
                return;
            }
        } else if distance > 200.0 {
            this.m_visitSite = 0;
            return;
        }
        // Aparecen si V esta a menos de SpawnDistance.
        if distance > GRStronghold.SpawnDistance() {
            return;
        }
        let blocker: String = spawner.GetAmbushBlocker();
        if StrLen(blocker) > 0 {
            return;
        }
        // Revalidacion de cerca, justo antes de poblar: aca el navmesh ya esta cargado (0 sigue, 1 esperar, 2 se mudo).
        if !this.m_visitNear {
            if this.Revalidate(spawner, site, true) != 0 {
                return;
            }
            this.m_visitNear = true;
        }
        this.BeginPopulate(spawner, player, site);
    }

    private func StopPopulating() {
        ArrayClear(this.m_pending);
        this.m_populating = false;
    }

    // Arma la lista de puestos de la guarida y la deja activa; los NPC van apareciendo en FillPosts (el primer
    // intento es ya mismo, los demas uno por tick). Los datos de cada miembro se copian al puesto: Lua puede
    // rehacer la lista de miembros (ClearMembers/AddMember) mientras quedan pendientes.
    private func BeginPopulate(spawner: ref<GRSpawner>, player: ref<PlayerPuppet>, site: Int32) {
        let gang: String = this.m_siteGangs[site];
        ArrayClear(this.m_pending);
        // Jefe en el centro, el resto a 4-6 m; guardias en dos anillos: 8 a 8-12 m, el resto a 14-20 m.
        let slot: Int32 = 0;
        let i: Int32 = 0;
        while i < ArraySize(this.m_ids) {
            if this.m_memberSites[i] == site {
                let member: ref<GRPendingPost> = new GRPendingPost();
                member.nemesisId = this.m_ids[i];
                member.record = this.m_records[i];
                member.appearance = this.m_appearances[i];
                member.speaker = this.m_speakers[i];
                member.angle = Cast<Float>(slot) * 2.1;
                member.radius = slot == 0 ? 0.0 : RandRangeF(4.0, 6.0);
                ArrayPush(this.m_pending, member);
                slot += 1;
            }
            i += 1;
        }
        let guards: array<String>;
        let records: String = this.m_siteGuards[site];
        if StrLen(records) > 0 {
            guards = StrSplit(records, ",");
        }
        let count: Int32 = ArraySize(guards);
        let inner: Int32 = Min(count, 8);
        i = 0;
        while i < count {
            let outer: Bool = i >= inner;
            let ring: Int32 = outer ? count - inner : inner;
            let ringSlot: Int32 = outer ? i - inner : i;
            let guard: ref<GRPendingPost> = new GRPendingPost();
            guard.record = guards[i];
            guard.angle = 2.0 * Pi() * Cast<Float>(ringSlot) / Cast<Float>(Max(ring, 1)) + (outer ? 0.4 : 0.0) + RandRangeF(-0.2, 0.2);
            guard.radius = outer ? RandRangeF(14.0, 20.0) : RandRangeF(8.0, 12.0);
            ArrayPush(this.m_pending, guard);
            i += 1;
        }
        if ArraySize(this.m_pending) == 0 {
            return;
        }
        spawner.BeginStronghold();
        this.m_active = true;
        this.m_activeSite = site;
        this.m_activePos = this.m_sitePos[site];
        this.m_cleared = false;
        this.m_populating = true;
        this.m_announced = false;
        this.m_fillTicks = 0;
        this.m_placed = 0;
        this.m_failed = 0;
        this.m_fillStats = [0, 0, 0, 0, 0];
        GRLog("Guarida (" + gang + "): V a " + IntToString(Cast<Int32>(this.GetSiteDistance(site))) + " m, "
            + IntToString(ArraySize(this.m_pending)) + " puestos por ocupar");
        this.FillPosts(spawner, player);
    }

    // Una vez por tick mientras queden puestos pendientes. Cada puesto aparece cuando:
    // - tiene sitio en el navmesh (se reintenta SpotWait segundos; si no, se pierde, como antes);
    // - hay suelo cargado debajo (GRSpawner.GroundBelow). Sin colision el NPC queda flotando a la altura del
    //   navmesh. Tras GroundWait segundos aparece igual: nunca peor que antes;
    // - V no lo tiene a la vista, salvo que ya este a menos de ForcedDistance o hayan pasado SightWait segundos
    //   (mejor verlo aparecer a lo lejos que entrar a una guarida vacia).
    // Si el navmesh quedo por encima del suelo real, aparece a la altura del suelo.
    private func FillPosts(spawner: ref<GRSpawner>, player: ref<PlayerPuppet>) {
        let gang: String = this.m_siteGangs[this.m_activeSite];
        let center: Vector4 = this.m_activePos;
        let playerPos: Vector4 = player.GetWorldPosition();
        this.m_fillTicks += 1;
        let spawnedNow: Int32 = 0;
        let waitSpot: Int32 = 0;
        let waitGround: Int32 = 0;
        let waitSight: Int32 = 0;
        let i: Int32 = 0;
        while i < ArraySize(this.m_pending) {
            let post: ref<GRPendingPost> = this.m_pending[i];
            let done: Bool = false;
            post.waited += 1;
            if !post.hasPos {
                let found: Vector4 = this.FindPost(spawner, center, post.angle, post.radius);
                if !Vector4.IsZero(found) {
                    post.pos = found;
                    post.hasPos = true;
                    // Las esperas de suelo y de vista cuentan desde que el puesto tiene sitio.
                    post.waited = 1;
                } else if post.waited >= GRStronghold.SpotWait() {
                    this.m_failed += 1;
                    done = true;
                } else {
                    waitSpot += 1;
                }
            }
            if post.hasPos {
                let groundZ: Float = 0.0;
                let ground: Bool = spawner.GroundBelow(post.pos, groundZ);
                let seen: Bool = spawner.IsPostSeen(player, post.pos);
                let groundOk: Bool = ground || post.waited > GRStronghold.GroundWait();
                let sightOk: Bool = !seen || Vector4.Distance(playerPos, post.pos) < GRStronghold.ForcedDistance() || post.waited > GRStronghold.SightWait();
                if !groundOk {
                    post.waitedGround = true;
                    waitGround += 1;
                } else if !sightOk {
                    post.waitedSight = true;
                    waitSight += 1;
                } else {
                    let spawnPos: Vector4 = post.pos;
                    // Hasta 3 m hacia abajo, o un escalon (0.4 m) hacia arriba; mas arriba seria un obstaculo.
                    let drop: Float = ground ? post.pos.Z - groundZ : 0.0;
                    let snap: Bool = ground && drop > -0.4 && AbsF(drop) > 0.05;
                    if snap {
                        spawnPos.Z = groundZ;
                    }
                    if spawner.SpawnPosted(post.nemesisId, post.record, post.appearance, spawnPos, center, post.speaker) {
                        this.m_placed += 1;
                        spawnedNow += 1;
                        if snap {
                            this.m_fillStats[4] += 1;
                            if AbsF(drop) > 0.3 {
                                GRLog("Guarida (" + gang + "): puesto con el navmesh a " + FloatToStringPrec(drop, 2) + " m del suelo real (Z "
                                    + FloatToStringPrec(post.pos.Z, 2) + " -> " + FloatToStringPrec(groundZ, 2) + "): aparece en el suelo");
                            }
                        }
                        if post.waitedGround {
                            this.m_fillStats[0] += 1;
                            if !ground {
                                this.m_fillStats[1] += 1;
                            }
                        }
                        if post.waitedSight {
                            this.m_fillStats[2] += 1;
                            if seen {
                                this.m_fillStats[3] += 1;
                            }
                        }
                        done = true;
                    } else if post.waited > GRStronghold.GroundWait() {
                        // El sistema de entidades no estuvo listo en todo este tiempo.
                        this.m_failed += 1;
                        done = true;
                    }
                }
            }
            if done {
                ArrayErase(this.m_pending, i);
            } else {
                i += 1;
            }
        }
        if this.m_placed > 0 && !this.m_announced {
            this.m_announced = true;
            ArrayPush(this.m_events, "spawned:" + gang);
            // V llego a la guarida sin el intel completo: ya la encontro, queda en el mapa.
            this.MarkLocated(gang, "V llego a la guarida");
        }
        if this.m_fillTicks == 1 {
            GRLog("Guarida (" + gang + "): primer intento, " + IntToString(spawnedNow) + " aparecen, " + IntToString(waitGround)
                + " esperan suelo, " + IntToString(waitSight) + " esperan a que V no mire, " + IntToString(waitSpot) + " sin sitio todavia");
        }
        if ArraySize(this.m_pending) > 0 {
            return;
        }
        this.m_populating = false;
        if this.m_placed == 0 {
            spawner.DespawnAll();
            this.m_active = false;
            GRLog("Guarida (" + gang + "): sin puestos validos en el navmesh");
            return;
        }
        GRLog("Guarida (" + gang + "): " + IntToString(this.m_placed) + " en sus puestos, " + IntToString(this.m_failed) + " sin sitio, en "
            + IntToString(this.m_fillTicks) + " s | esperaron suelo " + IntToString(this.m_fillStats[0]) + " (" + IntToString(this.m_fillStats[1])
            + " aparecieron sin suelo) | esperaron a que V no mire " + IntToString(this.m_fillStats[2]) + " (" + IntToString(this.m_fillStats[3])
            + " aparecieron a la vista) | bajados al suelo " + IntToString(this.m_fillStats[4]));
    }

    // Si el puesto no sirve, prueba mas cerca y girando un poco.
    private func FindPost(spawner: ref<GRSpawner>, center: Vector4, angle: Float, radius: Float) -> Vector4 {
        let tries: array<Float> = [1.0, 0.7, 0.4];
        for scale in tries {
            let pos: Vector4 = spawner.PostSpot(center, angle + (1.0 - scale), radius * scale);
            if !Vector4.IsZero(pos) {
                return pos;
            }
        }
        return Vector4.EmptyVector();
    }
}

// Puesto de la guarida activa que todavia no aparecio (GRStronghold.FillPosts).
public class GRPendingPost {
    // 0 = guardia.
    public let nemesisId: Int32;
    public let record: String;
    public let appearance: String;
    public let speaker: String;
    public let angle: Float;
    public let radius: Float;
    // Sitio elegido en el navmesh (hasPos = ya lo tiene).
    public let pos: Vector4;
    public let hasPos: Bool;
    // Ticks (segundos) esperando: primero sitio; despues, suelo y que V no mire.
    public let waited: Int32;
    public let waitedGround: Bool;
    public let waitedSight: Bool;
}

// -----------------------------------------------------------------------------
// Icono de guarida en el mapa. Ninguna variante del juego usa la parte "devil_horns" de mappin_icons.inkatlas, asi
// que el mappin se registra como OutpostVariant y lleva esta marca en su scriptData. Los controladores de icono
// (mapa grande, minimapa y marcador en el mundo) la leen con GetScriptData y solo entonces cambian la parte: los
// demas marcadores del juego no se tocan y no hay busquedas en listas. Los tres widgets ya usan ese atlas.
// -----------------------------------------------------------------------------
public class GRStrongholdMappinData extends MappinScriptData {
    public let gang: String;
    // Ya se aviso en el log (una vez por mappin y vista, no en cada actualizacion).
    private let m_loggedMap: Bool;
    private let m_loggedMinimap: Bool;
    private let m_loggedWorld: Bool;
    private let m_loggedTooltip: Bool;
    // Ultimo estado del filtro del mapa que se aviso en el log: 0 = ninguno, 1 = visible, 2 = oculta.
    private let m_loggedFilter: Int32;

    public static func IconPart() -> CName {
        return n"devil_horns";
    }

    public func LogFilter(shown: Bool) -> Void {
        let state: Int32 = shown ? 1 : 2;
        if this.m_loggedFilter == state {
            return;
        }
        this.m_loggedFilter = state;
        let what: String = shown ? "visible" : "oculta";
        GRLog("Guarida (" + this.gang + "): " + what + " en el mapa por la casilla GUARIDAS");
    }

    public static func ViewMap() -> Int32 { return 0; }
    public static func ViewMinimap() -> Int32 { return 1; }
    public static func ViewWorld() -> Int32 { return 2; }
    public static func ViewTooltip() -> Int32 { return 3; }

    // La marca si el mappin es una guarida nuestra; null en cualquier otro marcador.
    public static func Of(mappin: wref<IMappin>) -> wref<GRStrongholdMappinData> {
        if !IsDefined(mappin) {
            return null;
        }
        return mappin.GetScriptData() as GRStrongholdMappinData;
    }

    public func LogOnce(view: Int32) -> Void {
        let what: String;
        if view == GRStrongholdMappinData.ViewMap() {
            if this.m_loggedMap {
                return;
            }
            this.m_loggedMap = true;
            what = "icono devil_horns en el mapa grande";
        } else if view == GRStrongholdMappinData.ViewMinimap() {
            if this.m_loggedMinimap {
                return;
            }
            this.m_loggedMinimap = true;
            what = "icono devil_horns en el minimapa";
        } else if view == GRStrongholdMappinData.ViewWorld() {
            if this.m_loggedWorld {
                return;
            }
            this.m_loggedWorld = true;
            what = "icono devil_horns en el marcador del mundo";
        } else {
            if this.m_loggedTooltip {
                return;
            }
            this.m_loggedTooltip = true;
            what = "titulo propio en el tooltip del mapa";
        }
        GRLog("Guarida (" + this.gang + "): " + what);
    }
}

// Marca del icono de intel: va en el scriptData del mappin que GRIntelSystem cuelga de cada pandillero inconsciente
// al que se le pueden extraer datos. Mismo truco que la guarida: la variante (HuntForPsychoVariant) decide donde se
// ve y el color; la parte "download" del atlas la ponen los wrappers de abajo.
public class GRIntelMappinData extends MappinScriptData {
    // Para el log: banda, rango y record del NPC.
    public let label: String;
    private let m_loggedMap: Bool;
    private let m_loggedMinimap: Bool;
    private let m_loggedWorld: Bool;
    private let m_loggedFilter: Bool;

    public static func IconPart() -> CName {
        return n"download";
    }

    public func LogFilter() -> Void {
        if this.m_loggedFilter {
            return;
        }
        this.m_loggedFilter = true;
        GRLog("Intel: icono visible en el mapa con filtro PERSONALIZADA (no depende de CIBERPSICOPATA), " + this.label);
    }

    public func LogOnce(view: Int32) -> Void {
        let what: String;
        if view == GRStrongholdMappinData.ViewMap() {
            if this.m_loggedMap {
                return;
            }
            this.m_loggedMap = true;
            what = "el mapa grande";
        } else if view == GRStrongholdMappinData.ViewMinimap() {
            if this.m_loggedMinimap {
                return;
            }
            this.m_loggedMinimap = true;
            what = "el minimapa";
        } else {
            if this.m_loggedWorld {
                return;
            }
            this.m_loggedWorld = true;
            what = "el marcador del mundo";
        }
        GRLog("Intel: icono download dibujado en " + what + ", " + this.label);
    }
}

// Va despues del UpdateIcon del juego (que pone el icono de la variante): lo pisa solo en los mappins del mod, que se
// reconocen por la marca de su scriptData (una sola lectura por actualizacion; los demas marcadores no se tocan).
public func GRApplyMappinIcon(mappin: wref<IMappin>, icon: inkImageRef, view: Int32) -> Void {
    if !IsDefined(mappin) {
        return;
    }
    let data: wref<MappinScriptData> = mappin.GetScriptData();
    if !IsDefined(data) {
        return;
    }
    let stronghold: wref<GRStrongholdMappinData> = data as GRStrongholdMappinData;
    if IsDefined(stronghold) {
        inkImageRef.SetTexturePart(icon, GRStrongholdMappinData.IconPart());
        stronghold.LogOnce(view);
        return;
    }
    let intel: wref<GRIntelMappinData> = data as GRIntelMappinData;
    if IsDefined(intel) {
        inkImageRef.SetTexturePart(icon, GRIntelMappinData.IconPart());
        intel.LogOnce(view);
    }
}

// Map filter fix by RedFalcon (Gang Retaliation History), 1.4.6. Thanks!
// Map filter crash fix: the filter code must never call GetScriptData() on a controller's mappin outside the
// vanilla bind path (the native mappin can already be freed while its widget is still in the spawn container).
// The script data is cached here, where the mappin is known to be alive, and the filter code only reads the cache.
@addField(BaseWorldMapMappinController)
private let m_grStronghold: ref<GRStrongholdMappinData>;

@addField(BaseWorldMapMappinController)
private let m_grIntel: ref<GRIntelMappinData>;

@addMethod(BaseWorldMapMappinController)
public func GRCacheMappinData() -> Void {
    this.m_grStronghold = null;
    this.m_grIntel = null;
    let mappin: wref<IMappin> = this.GetMappin();
    if !IsDefined(mappin) {
        return;
    }
    let data: wref<MappinScriptData> = mappin.GetScriptData();
    if !IsDefined(data) {
        return;
    }
    this.m_grStronghold = data as GRStrongholdMappinData;
    this.m_grIntel = data as GRIntelMappinData;
}

// Mapa grande. Un grupo de marcadores (varios juntos con el zoom alejado) conserva el icono del juego.
@wrapMethod(BaseWorldMapMappinController)
protected func UpdateIcon() -> Void {
    wrappedMethod();
    if !this.IsCollection() {
        this.GRCacheMappinData();
        GRApplyMappinIcon(this.GetMappin(), this.iconWidget, GRStrongholdMappinData.ViewMap());
    } else {
        this.m_grStronghold = null;
        this.m_grIntel = null;
    }
}

// Minimapa.
@wrapMethod(MinimapPOIMappinController)
protected final func UpdateIcon() -> Void {
    wrappedMethod();
    GRApplyMappinIcon(this.GetMappin(), this.iconWidget, GRStrongholdMappinData.ViewMinimap());
}

// Marcador flotante en el mundo.
@wrapMethod(QuestMappinController)
protected func UpdateIcon() -> Void {
    wrappedMethod();
    GRApplyMappinIcon(this.GetMappin(), this.iconWidget, GRStrongholdMappinData.ViewWorld());
}

// Tooltip del mapa grande: OutpostVariant usa el de la NCPD ("Presunta actividad del crimen organizado"). Ese widget
// solo muestra el titulo (no tiene texto de descripcion enlazado): se cambia por "Guarida (<banda>)".
@wrapMethod(WorldMapPoliceTooltipController)
public func SetData(const data: script_ref<WorldMapTooltipData>, menu: ref<WorldMapMenuGameController>) -> Void {
    wrappedMethod(data, menu);
    if !IsDefined(menu) || Deref(data).isCollection {
        return;
    }
    let mark: wref<GRStrongholdMappinData> = GRStrongholdMappinData.Of(Deref(data).mappin);
    let player: wref<GameObject> = menu.GetPlayer();
    if !IsDefined(mark) || !IsDefined(player) {
        return;
    }
    let core: ref<GRSystem> = GRSystem.Get(player.GetGame());
    if !IsDefined(core) {
        return;
    }
    let title: String = StrReplace(core.GetText("GR-StrongholdMapTitle"), "{gang}", GRIntelSystem.GangLabel(mark.gang));
    inkTextRef.SetText(this.m_titleText, title);
    mark.LogOnce(GRStrongholdMappinData.ViewTooltip());
}

// -----------------------------------------------------------------------------
// Filtro "GUARIDAS" del mapa grande (lista del filtro rapido PERSONALIZADA).
// - La casilla es un MappinUIFilterGroup_Record propio (WorldMap.GRStrongholdFilterGroup, intel.yaml) agregado a
//   WorldMap.WorldMapCustomFiltersList; el juego arma la lista desde ese record y guarda la casilla en su mascara de
//   filtros (Has/Set/ClearCustomFilter) con el valor de GRStronghold.MapFilter().
// - El juego decide que marcador entra en cada filtro por su variante (lista "mappins" del grupo): las guaridas son
//   OutpostVariant (grupo ESCANER NCPD) y el icono de intel HuntForPsychoVariant (grupo CIBERPSICOPATA). No se les
//   cambia la variante (de ella salen color, tooltip, minimapa y marcador del mundo): el grupo propio no tiene
//   variantes y la visibilidad de los marcadores del mod se decide aca, por la marca de su scriptData.
// - El controlador de cada marcador calcula si se ve en PlayHideShowAnim con inCustomFilter (lo pone el motor). El
//   wrapper lo pisa solo durante esa llamada y solo en los marcadores del mod: guarida = casilla GUARIDAS; intel =
//   siempre visible. Solo con el filtro rapido PERSONALIZADA: con TODO, CURROS, etc. decide el juego, igual que antes.
// - El menu del mapa avisa a GRStronghold el estado (filtro rapido + casilla) y reaplica los marcadores del mod.
// -----------------------------------------------------------------------------

// 0 = decide el juego (no es del mod, o el filtro rapido no es PERSONALIZADA); 1 = se ve; 2 = oculto.
public func GRMapFilterState(stronghold: wref<GRStrongholdMappinData>, intel: wref<GRIntelMappinData>) -> Int32 {
    if !IsDefined(stronghold) && !IsDefined(intel) {
        return 0;
    }
    let system: ref<GRStronghold> = GRStronghold.Get(GetGameInstance());
    if !IsDefined(system) || !system.IsMapCustom() {
        return 0;
    }
    if IsDefined(intel) {
        intel.LogFilter();
        return 1;
    }
    let shown: Bool = system.IsMapFilterOn();
    stronghold.LogFilter(shown);
    return shown ? 1 : 2;
}

// Sin filtro activo (TODO), en el mapa de viaje rapido o en un grupo de marcadores no se toca nada.
@wrapMethod(BaseWorldMapMappinController)
private final func PlayHideShowAnim() -> Void {
    if this.isFastTravelEnabled || this.IsCollection() {
        wrappedMethod();
        return;
    }
    // PROTOTYPE: when GUARIDAS is the only box checked, the game sees no real filter and reports hasCustomFilter=false
    // for our markers, which used to skip this override (strongholds stayed hidden). Our own markers now go through it anyway.
    let ours: Bool = IsDefined(this.m_grStronghold) || IsDefined(this.m_grIntel);
    if !ours {
        // PROTOTYPE: GUARIDAS is the only box checked (the game reports no other active filter, so it would show
        // everything): hide every other marker, as any real filter would.
        let sys: ref<GRStronghold> = GRStronghold.Get(GetGameInstance());
        if !this.hasCustomFilter && IsDefined(sys) && sys.IsMapCustom() && sys.IsMapFilterOn() {
            let prevIn: Bool = this.inCustomFilter;
            this.hasCustomFilter = true;
            this.inCustomFilter = false;
            wrappedMethod();
            this.inCustomFilter = prevIn;
            this.hasCustomFilter = false;
        } else {
            wrappedMethod();
        }
        return;
    }
    let state: Int32 = GRMapFilterState(this.m_grStronghold, this.m_grIntel);
    if state == 0 {
        wrappedMethod();
        return;
    }
    let savedHas: Bool = this.hasCustomFilter;
    if state == 2 && !savedHas {
        // PROTOTYPE: GUARIDAS unchecked AND the game reports no other active filter = nothing selected, so the map
        // shows everything; our markers must show too instead of being hidden.
        state = 1;
    }
    // Se devuelve el valor del motor al terminar: los campos son suyos.
    let saved: Bool = this.inCustomFilter;
    this.hasCustomFilter = true;
    this.inCustomFilter = state == 1;
    wrappedMethod();
    this.inCustomFilter = saved;
    this.hasCustomFilter = savedHas;
}

// Reaplica el filtro en este marcador si es del mod. true = era del mod.
@addMethod(BaseWorldMapMappinController)
public func GRReplayMapFilter() -> Bool {
    if this.IsCollection() {
        return false;
    }
    if !IsDefined(this.m_grStronghold) && !IsDefined(this.m_grIntel) {
        return false;
    }
    this.PlayHideShowAnim();
    return true;
}

// Para el motor los marcadores del mod no cambian cuando se toca la casilla GUARIDAS (el grupo no tiene variantes) y
// no esta comprobado que les avise (OnFiltersChanged): se reaplican a mano despues de cada cambio de filtro.
@addMethod(WorldMapMenuGameController)
private func GRRefreshMapFilter(reason: String) -> Void {
    let container: wref<inkCompoundWidget> = this.GetSpawnContainer();
    if !IsDefined(container) {
        return;
    }
    let count: Int32 = container.GetNumChildren();
    let refreshed: Int32 = 0;
    let i: Int32 = 0;
    while i < count {
        let widget: wref<inkWidget> = container.GetWidgetByIndex(i);
        if IsDefined(widget) {
            let controller: wref<BaseWorldMapMappinController> = widget.GetController() as BaseWorldMapMappinController;
            if IsDefined(controller) && controller.GRReplayMapFilter() {
                refreshed += 1;
            }
        }
        i += 1;
    }
    if count > 0 {
        GRLog("Mapa: filtro reaplicado (" + reason + ") en " + IntToString(refreshed) + " marcadores del mod, de "
            + IntToString(count) + " en el mapa");
    }
}

// Al abrir el mapa: la primera vez en cada partida se marca la casilla GUARIDAS (despues manda el jugador; el juego
// guarda la mascara en el perfil al cerrar el mapa, salvo en el mapa de viaje rapido: ahi no se marca nada).
@wrapMethod(WorldMapMenuGameController)
protected cb func OnInitialize() -> Bool {
    let result: Bool = wrappedMethod();
    let system: ref<GRStronghold> = GRStronghold.Get(GetGameInstance());
    if IsDefined(system) {
        let filter: gamedataWorldMapFilter = GRStronghold.MapFilter();
        if !system.IsMapFilterSeeded() && !this.IsFastTravelEnabled() {
            this.SetCustomFilter(filter);
            system.MarkMapFilterSeeded();
        }
        system.SetMapFilter(Equals(this.GetQuickFilter(), gamedataWorldMapFilter.CustomFilter), this.HasCustomFilter(filter));
    }
    return result;
}

// Cambio de filtro rapido (TODO / CURROS / PUNTOS DE SERVICIO / PERSONALIZADA).
@wrapMethod(WorldMapMenuGameController)
protected cb func OnQuickFilterChanged(filterGroup: wref<MappinUIFilterGroup_Record>) -> Bool {
    let system: ref<GRStronghold> = GRStronghold.Get(GetGameInstance());
    if IsDefined(system) && IsDefined(filterGroup) {
        let filterType: wref<WorldMapFilter_Record> = filterGroup.FilterType();
        let custom: Bool = IsDefined(filterType) && Equals(filterType.Type(), gamedataWorldMapFilter.CustomFilter);
        system.SetMapFilter(custom, this.HasCustomFilter(GRStronghold.MapFilter()));
    }
    let result: Bool = wrappedMethod(filterGroup);
    this.GRRefreshMapFilter("filtro rapido");
    return result;
}

// Casilla marcada o desmarcada (raton, teclado o mando: todos pasan por aca).
@wrapMethod(WorldMapMenuGameController)
private final func UpdateCustomFilter(filter: gamedataWorldMapFilter, enable: Bool) -> Void {
    let ours: Bool = Equals(filter, GRStronghold.MapFilter());
    if ours {
        let system: ref<GRStronghold> = GRStronghold.Get(GetGameInstance());
        if IsDefined(system) {
            system.SetMapFilter(system.IsMapCustom(), enable);
        }
    }
    wrappedMethod(filter, enable);
    if ours {
        this.GRRefreshMapFilter("casilla GUARIDAS");
    }
}

// -----------------------------------------------------------------------------
// Intel: V le extrae datos a un pandillero tirado (accion "Extraer datos", r6/tweaks/GangRetaliation/intel.yaml).
// - Elegibles: los Nemesis siempre; de los pandilleros comunes, uno al azar por combate (GRDetection avisa).
// - Al bajar de su linea de huida quedan inconscientes (en vez de huir) y con el estado GangRetaliation.IntelTarget,
//   que es el prereq de la accion. Si mueren de un golpe, no hay intel.
// - La extraccion dura 3 s (barra del HUD del juego, cable colgando); se corta si V se aleja o el NPC muere.
// - Al terminar suma intel a la banda (comun 5, Soldado 10, Teniente 25, Jefe 50; tope 100). Al 100 % la guarida
//   sale en el mapa (GRStronghold.RefreshMappins).
// -----------------------------------------------------------------------------
public class GRIntelSystem extends ScriptableSystem {
    // % de intel por banda, paralelo a Gangs(). Partidas viejas: vacio = 0 en todas.
    private persistent let m_values: array<Int32>;

    // Moneda de cada Nemesis en este combate (se tira una sola vez): true = huye, false = cae para extraer.
    private let m_coinIds: array<EntityID>;
    private let m_coinFlee: array<Bool>;

    // Combate actual (GRDetection lo vacia con ResetFight): pandilleros comunes vistos y el elegido.
    private let m_fightSeen: array<EntityID>;
    private let m_fightChosen: EntityID;
    private let m_hasChosen: Bool;
    // El elegido ya cayo: no se elige otro en este combate.
    private let m_chosenUsed: Bool;

    // Extraccion en curso (una sola a la vez).
    private let m_active: Bool;
    private let m_target: EntityID;
    private let m_gang: String;
    private let m_rank: Int32;
    private let m_start: Float;

    // Icono sobre cada cuerpo extraible (arrays paralelos, uno por NPC). La marca del scriptData se guarda aca para
    // que no se libere mientras el mappin exista. No se guardan en la partida: al cargar empiezan vacios.
    private let m_markIds: array<EntityID>;
    private let m_markMappins: array<NewMappinID>;
    private let m_markData: array<ref<GRIntelMappinData>>;
    // Ya hay una revision de iconos agendada (GRIntelCall.Marks, una por segundo mientras quede alguno).
    private let m_markPolling: Bool;

    public static func Get(gi: GameInstance) -> ref<GRIntelSystem> {
        return GameInstance.GetScriptableSystemsContainer(gi).Get(n"GangRetaliation.GRIntelSystem") as GRIntelSystem;
    }

    // Fin de la sesion (salir al menu, cargar otra partida): no quedan mappins colgados de NPC que ya no estan.
    private func OnDetach() {
        let count: Int32 = ArraySize(this.m_markIds);
        let i: Int32 = 0;
        while i < count {
            GameInstance.GetMappinSystem(this.GetGameInstance()).UnregisterMappin(this.m_markMappins[i]);
            i += 1;
        }
        ArrayClear(this.m_markIds);
        ArrayClear(this.m_markMappins);
        ArrayClear(this.m_markData);
        this.m_markPolling = false;
        if count > 0 {
            GRLog("Intel: " + IntToString(count) + " iconos quitados (fin de la sesion)");
        }
    }

    // Slot de UI de los NPC (hueso Spine3, el pecho): sigue al cuerpo aunque caiga en ragdoll. El juego cuelga ahi el
    // icono de botin de los cuerpos, 0.16 m arriba; este va mas alto para no taparlo.
    public static func MarkHeight() -> Float {
        return 0.55;
    }

    public static func Gangs() -> array<String> {
        return ["Maelstrom", "TygerClaws", "Valentinos", "SixthStreet", "Animals", "VoodooBoys", "Wraiths", "Scavengers", "Barghest"];
    }

    public static func TargetEffect() -> TweakDBID {
        return t"GangRetaliation.IntelTarget";
    }

    public static func ActionID() -> TweakDBID {
        return t"Takedown.GRExtractData";
    }

    public static func Duration() -> Float {
        return 3.0;
    }

    public static func MaxDistance() -> Float {
        return 4.0;
    }

    // Intel que da cada rango (0 = pandillero comun).
    public static func AmountFor(rank: Int32) -> Int32 {
        if rank >= 3 {
            return 50;
        }
        if rank == 2 {
            return 25;
        }
        if rank == 1 {
            return 10;
        }
        return 5;
    }

    public static func RankName(rank: Int32) -> String {
        if rank >= 3 {
            return "Jefe";
        }
        if rank == 2 {
            return "Teniente";
        }
        if rank == 1 {
            return "Soldado";
        }
        return "comun";
    }

    // Los mismos nombres que usa CET (names.lua).
    public static func GangLabel(gang: String) -> String {
        if Equals(gang, "TygerClaws") {
            return "Tyger Claws";
        }
        if Equals(gang, "SixthStreet") {
            return "6th Street";
        }
        if Equals(gang, "VoodooBoys") {
            return "Voodoo Boys";
        }
        if Equals(gang, "Scavengers") {
            return "Scavs";
        }
        return gang;
    }

    private func GangIndex(gang: String) -> Int32 {
        let gangs: array<String> = GRIntelSystem.Gangs();
        let i: Int32 = 0;
        while i < ArraySize(gangs) {
            if Equals(gangs[i], gang) {
                return i;
            }
            i += 1;
        }
        return -1;
    }

    public func GetIntel(gang: String) -> Int32 {
        let index: Int32 = this.GangIndex(gang);
        if index < 0 || index >= ArraySize(this.m_values) {
            return 0;
        }
        return this.m_values[index];
    }

    public func IsLocated(gang: String) -> Bool {
        return this.GetIntel(gang) >= 100;
    }

    // Un lugar por banda antes de escribir. La lista va a una variable: ArraySize(GRIntelSystem.Gangs()) sobre el
    // resultado de la funcion daba 0, nunca se rellenaba y cada escritura caia fuera del array (el intel no se sumaba).
    private func EnsureValues() {
        let gangs: array<String> = GRIntelSystem.Gangs();
        let count: Int32 = ArraySize(gangs);
        while ArraySize(this.m_values) < count {
            ArrayPush(this.m_values, 0);
        }
    }

    // Suma intel (tope 100). Avisa el nuevo % y, al llegar a 100, que la guarida quedo localizada.
    public func AddIntel(gang: String, amount: Int32, reason: String) -> Int32 {
        let index: Int32 = this.GangIndex(gang);
        if index < 0 || amount <= 0 {
            return 0;
        }
        this.EnsureValues();
        if index >= ArraySize(this.m_values) {
            GRLog("Intel: ERROR, " + gang + " sin lugar en la lista (" + IntToString(ArraySize(this.m_values)) + " valores)");
            return 0;
        }
        let before: Int32 = this.m_values[index];
        let after: Int32 = Min(100, before + amount);
        this.m_values[index] = after;
        GRLog("Intel: " + gang + " +" + IntToString(after - before) + "% = " + IntToString(after) + "% (" + reason + ")");
        this.Notify(this.Format(this.Text("GR-IntelGained"), gang, after));
        if before < 100 && after >= 100 {
            GRLog("Intel: guarida de " + gang + " localizada");
            this.Notify(this.Format(this.Text("GR-IntelLocated"), gang, after));
        }
        return after;
    }

    // La guarida ya se encontro (V llego a ella o la tomo): queda en el mapa aunque falte intel. Sin aviso.
    public func MarkLocated(gang: String, reason: String) {
        let index: Int32 = this.GangIndex(gang);
        if index < 0 || this.IsLocated(gang) {
            return;
        }
        this.EnsureValues();
        this.m_values[index] = 100;
        GRLog("Intel: guarida de " + gang + " localizada (" + reason + ")");
    }

    // La banda se mudo de guarida (GRStronghold.Relocate): hay que volver a encontrarla. Sin aviso al jugador.
    public func ResetIntel(gang: String, reason: String) {
        let index: Int32 = this.GangIndex(gang);
        if index < 0 {
            return;
        }
        this.EnsureValues();
        if index >= ArraySize(this.m_values) {
            return;
        }
        let before: Int32 = this.m_values[index];
        this.m_values[index] = 0;
        GRLog("Intel: " + gang + " " + IntToString(before) + "% -> 0% (" + reason + ")");
    }

    // --- Combate (lo llama GRDetection en el hilo principal) ---

    public func OnFightReset() {
        ArrayClear(this.m_coinIds);
        ArrayClear(this.m_coinFlee);
        ArrayClear(this.m_fightSeen);
        this.m_hasChosen = false;
        this.m_chosenUsed = false;
    }

    // Pandillero comun que entra a la pelea: el k-esimo pasa a ser el elegido con probabilidad 1/k (uno al azar
    // entre todos los del combate, sin saber cuantos van a ser).
    public func NoteCombatant(npc: ref<ScriptedPuppet>) {
        if !IsDefined(npc) || this.m_chosenUsed || StrLen(GRDetection.GetGang(npc)) == 0 || this.NemesisRank(npc) > 0 {
            return;
        }
        let id: EntityID = npc.GetEntityID();
        for seen in this.m_fightSeen {
            if seen == id {
                return;
            }
        }
        ArrayPush(this.m_fightSeen, id);
        if RandRange(0, ArraySize(this.m_fightSeen)) == 0 {
            this.m_fightChosen = id;
            this.m_hasChosen = true;
        }
    }

    // Si es elegible y bajo de su linea de huida, queda inconsciente y marcado para extraer. True si lo tiro.
    public func TryKnockOut(npc: ref<ScriptedPuppet>, health: Float, threshold: Float) -> Bool {
        if !IsDefined(npc) || npc.IsDead() || GRDetection.IsNeutralized(npc) || health <= 0.0 || health > threshold {
            return false;
        }
        let gang: String = GRDetection.GetGang(npc);
        let rank: Int32 = this.NemesisRank(npc);
        if StrLen(gang) == 0 || this.GangIndex(gang) < 0 {
            return false;
        }
        if rank == 0 {
            if !this.m_hasChosen || this.m_chosenUsed || this.m_fightChosen != npc.GetEntityID() {
                return false;
            }
            this.m_chosenUsed = true;
        } else {
            // Nemesis: mitad y mitad, una sola moneda por Nemesis y por combate. "Huye" deja la huida de siempre.
            if this.FleeCoin(npc) {
                return false;
            }
        }
        StatusEffectHelper.ApplyStatusEffect(npc, GRIntelSystem.TargetEffect());
        StatusEffectHelper.ApplyStatusEffect(npc, t"BaseStatusEffect.Unconscious");
        GRLog("Intel: " + gang + " inconsciente para extraer (" + GRIntelSystem.RankName(rank) + ", vida " + IntToString(RoundF(health))
            + "% <= " + IntToString(RoundF(threshold)) + "%) " + TDBID.ToStringDEBUG(npc.GetRecordID()));
        this.AddMark(npc, gang, rank);
        return true;
    }

    // --- Icono sobre el cuerpo extraible (todo en el hilo principal: llega por GRDetectionCall / GRIntelCall) ---

    private func MarkIndex(id: EntityID) -> Int32 {
        let i: Int32 = 0;
        while i < ArraySize(this.m_markIds) {
            if this.m_markIds[i] == id {
                return i;
            }
            i += 1;
        }
        return -1;
    }

    // Mappin que sigue al NPC. HuntForPsychoVariant + DefaultStaticMappin es lo que ya usa el marcador de Nemesis: se
    // ve en el mundo y en el minimapa y no esta en la lista de la NCPD que el minimapa oculta (OutpostVariant si).
    private func AddMark(npc: ref<ScriptedPuppet>, gang: String, rank: Int32) {
        let id: EntityID = npc.GetEntityID();
        if this.MarkIndex(id) >= 0 {
            return;
        }
        let mark: ref<GRIntelMappinData> = new GRIntelMappinData();
        mark.label = gang + " (" + GRIntelSystem.RankName(rank) + ") " + TDBID.ToStringDEBUG(npc.GetRecordID());
        let data: MappinData;
        data.mappinType = t"Mappins.DefaultStaticMappin";
        data.variant = gamedataMappinVariant.HuntForPsychoVariant;
        data.active = true;
        data.visibleThroughWalls = true;
        data.scriptData = mark;
        let mappin: NewMappinID = GameInstance.GetMappinSystem(this.GetGameInstance()).RegisterMappinWithObject(data, npc,
            npc.GetRoleMappinSlotName(), new Vector3(0.0, 0.0, GRIntelSystem.MarkHeight()));
        ArrayPush(this.m_markIds, id);
        ArrayPush(this.m_markMappins, mappin);
        ArrayPush(this.m_markData, mark);
        GRLog("Intel: icono puesto, " + mark.label);
        if !this.m_markPolling {
            this.m_markPolling = true;
            GRIntelCall.Send(this.GetGameInstance(), GRIntelCall.Marks(), id, 1.0);
        }
    }

    private func RemoveMarkAt(index: Int32, reason: String) {
        GameInstance.GetMappinSystem(this.GetGameInstance()).UnregisterMappin(this.m_markMappins[index]);
        GRLog("Intel: icono quitado (" + reason + "), " + this.m_markData[index].label);
        ArrayErase(this.m_markIds, index);
        ArrayErase(this.m_markMappins, index);
        ArrayErase(this.m_markData, index);
    }

    private func RemoveMark(id: EntityID, reason: String) {
        let index: Int32 = this.MarkIndex(id);
        if index >= 0 {
            this.RemoveMarkAt(index, reason);
        }
    }

    // Lo llama GRDetection cuando muere cualquier NPC (ya en el hilo principal).
    public func OnNPCDeath(id: EntityID) {
        this.RemoveMark(id, "el NPC murio");
    }

    // Por que el NPC ya no lleva icono ("" = lo sigue llevando).
    private func MarkGoneReason(id: EntityID) -> String {
        let npc: ref<ScriptedPuppet> = GameInstance.FindEntityByID(this.GetGameInstance(), id) as ScriptedPuppet;
        if !IsDefined(npc) {
            return "el NPC se descargo";
        }
        if npc.IsDead() {
            return "el NPC murio";
        }
        if !ScriptedPuppet.IsUnconscious(npc) {
            return "el NPC se levanto";
        }
        if !StatusEffectSystem.ObjectHasStatusEffect(npc, GRIntelSystem.TargetEffect()) {
            return "ya no es extraible";
        }
        return "";
    }

    // Revision de los iconos (GRIntelCall.Marks, una por segundo mientras quede alguno): cubre lo que no avisa nadie
    // (el cuerpo se descarga, el NPC se levanta, pierde el estado IntelTarget).
    public func OnMarksTick() {
        this.m_markPolling = false;
        let i: Int32 = ArraySize(this.m_markIds) - 1;
        while i >= 0 {
            let reason: String = this.MarkGoneReason(this.m_markIds[i]);
            if StrLen(reason) > 0 {
                this.RemoveMarkAt(i, reason);
            }
            i -= 1;
        }
        if ArraySize(this.m_markIds) > 0 {
            this.m_markPolling = true;
            GRIntelCall.Send(this.GetGameInstance(), GRIntelCall.Marks(), this.m_markIds[0], 1.0);
        }
    }

    // True = huye. Se tira la primera vez que baja de su linea de huida en este combate y despues se respeta.
    private func FleeCoin(npc: ref<ScriptedPuppet>) -> Bool {
        let id: EntityID = npc.GetEntityID();
        let i: Int32 = 0;
        while i < ArraySize(this.m_coinIds) {
            if this.m_coinIds[i] == id {
                return this.m_coinFlee[i];
            }
            i += 1;
        }
        let flee: Bool = RandRange(0, 2) == 0;
        ArrayPush(this.m_coinIds, id);
        ArrayPush(this.m_coinFlee, flee);
        let name: String = "";
        let spawner: ref<GRSpawner> = GRSpawner.Get(this.GetGameInstance());
        if IsDefined(spawner) {
            name = spawner.GetNemesisLabel(id);
        }
        if StrLen(name) == 0 {
            name = TDBID.ToStringDEBUG(npc.GetRecordID());
        }
        GRLog("Intel: " + name + " moneda -> " + (flee ? "huye" : "inconsciente"));
        return flee;
    }

    private func NemesisRank(npc: ref<ScriptedPuppet>) -> Int32 {
        let spawner: ref<GRSpawner> = GRSpawner.Get(this.GetGameInstance());
        if !IsDefined(spawner) || spawner.GetNemesisId(npc.GetEntityID()) <= 0 {
            return 0;
        }
        return Max(1, spawner.GetNemesisRank(npc.GetEntityID()));
    }

    // --- Extraccion ---

    private func Now() -> Float {
        return EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGameInstance()));
    }

    // V eligio "Extraer datos" (llega por GRIntelCall, ya en el hilo principal; el juego lo manda muchas veces).
    public func OnExtractRequested(id: EntityID) {
        if this.m_active {
            return;
        }
        let npc: ref<ScriptedPuppet> = GameInstance.FindEntityByID(this.GetGameInstance(), id) as ScriptedPuppet;
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(npc) || !IsDefined(player) || npc.IsDead() || !ScriptedPuppet.IsUnconscious(npc)
            || !StatusEffectSystem.ObjectHasStatusEffect(npc, GRIntelSystem.TargetEffect()) {
            return;
        }
        this.m_active = true;
        this.m_target = id;
        this.m_gang = GRDetection.GetGang(npc);
        this.m_rank = this.NemesisRank(npc);
        this.m_start = this.Now();
        let bar: ref<IBlackboard> = this.ProgressBar();
        let defs = GetAllBlackboardDefs();
        bar.SetString(defs.UI_HUDProgressBar.Header, this.Text("GR-IntelExtracting"), true);
        bar.SetString(defs.UI_HUDProgressBar.BottomText, this.Format(this.Text("GR-IntelBottom"), this.m_gang, this.GetIntel(this.m_gang)), true);
        bar.SetString(defs.UI_HUDProgressBar.CompletedText, this.Text("GR-IntelDone"), true);
        bar.SetString(defs.UI_HUDProgressBar.FailedText, this.Text("GR-IntelFailed"), true);
        bar.SetFloat(defs.UI_HUDProgressBar.Progress, 0.0, true);
        bar.SetBool(defs.UI_HUDProgressBar.Active, true, true);
        GRLog("Intel: extraccion empezada, " + this.m_gang + " (" + GRIntelSystem.RankName(this.m_rank) + ") " + TDBID.ToStringDEBUG(npc.GetRecordID()));
        GRIntelCall.Send(this.GetGameInstance(), GRIntelCall.Tick(), id, 0.1);
    }

    public func OnTick() {
        if !this.m_active {
            return;
        }
        let npc: ref<ScriptedPuppet> = GameInstance.FindEntityByID(this.GetGameInstance(), this.m_target) as ScriptedPuppet;
        let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
        if !IsDefined(player) || player.IsDead() {
            this.Stop(false, "V muerto o sin jugador");
            return;
        }
        if !IsDefined(npc) || npc.IsDead() {
            this.Stop(false, "el NPC murio o se descargo");
            this.RemoveMark(this.m_target, "el NPC murio o se descargo");
            return;
        }
        if !ScriptedPuppet.IsUnconscious(npc) {
            this.Stop(false, "el NPC se levanto");
            this.RemoveMark(this.m_target, "el NPC se levanto");
            return;
        }
        let distance: Float = Vector4.Distance(player.GetWorldPosition(), npc.GetWorldPosition());
        if distance > GRIntelSystem.MaxDistance() {
            this.Stop(false, "V se alejo (" + FloatToStringPrec(distance, 1) + " m)");
            return;
        }
        let progress: Float = (this.Now() - this.m_start) / GRIntelSystem.Duration();
        this.ProgressBar().SetFloat(GetAllBlackboardDefs().UI_HUDProgressBar.Progress, MinF(1.0, progress), true);
        if progress >= 1.0 {
            StatusEffectHelper.RemoveStatusEffect(npc, GRIntelSystem.TargetEffect());
            this.RemoveMark(this.m_target, "datos extraidos");
            let gang: String = this.m_gang;
            let rank: Int32 = this.m_rank;
            this.Stop(true, "");
            this.AddIntel(gang, GRIntelSystem.AmountFor(rank), GRIntelSystem.RankName(rank));
            return;
        }
        GRIntelCall.Send(this.GetGameInstance(), GRIntelCall.Tick(), this.m_target, 0.1);
    }

    // Cierra la barra (sin cable). El NPC queda inconsciente en el piso; si se corto, V puede volver a intentarlo.
    private func Stop(done: Bool, reason: String) {
        this.m_active = false;
        let bar: ref<IBlackboard> = this.ProgressBar();
        if done {
            bar.SetFloat(GetAllBlackboardDefs().UI_HUDProgressBar.Progress, 1.0, true);
        }
        bar.SetBool(GetAllBlackboardDefs().UI_HUDProgressBar.Active, false, true);
        if !done {
            GRLog("Intel: extraccion cancelada, " + reason);
        }
    }

    private func ProgressBar() -> ref<IBlackboard> {
        return GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().UI_HUDProgressBar);
    }

    private func Text(key: String) -> String {
        let core: ref<GRSystem> = GRSystem.Get(this.GetGameInstance());
        return IsDefined(core) ? core.GetText(key) : key;
    }

    private func Format(text: String, gang: String, value: Int32) -> String {
        return StrReplace(StrReplace(text, "{gang}", GRIntelSystem.GangLabel(gang)), "{pct}", IntToString(value));
    }

    private func Notify(text: String) {
        let det: ref<GRDetection> = GRDetection.Get(this.GetGameInstance());
        if IsDefined(det) {
            det.Notify(text);
        }
    }
}

// El juego completa la accion en hilos de trabajo, y muchas veces seguidas: aca solo se agenda; GRIntelSystem la
// procesa en el hilo principal y se queda con la primera.
public class GRIntelCall extends DelayCallback {
    public let gi: GameInstance;
    public let kind: Int32;
    public let entityID: EntityID;

    public static func Extract() -> Int32 { return 0; }
    public static func Tick() -> Int32 { return 1; }
    // Revision de los iconos de intel (entityID no se usa).
    public static func Marks() -> Int32 { return 2; }

    public static func Send(gi: GameInstance, kind: Int32, id: EntityID, delay: Float) {
        let call: ref<GRIntelCall> = new GRIntelCall();
        call.gi = gi;
        call.kind = kind;
        call.entityID = id;
        GameInstance.GetDelaySystem(gi).DelayCallback(call, delay, false);
    }

    public func Call() -> Void {
        let intel: ref<GRIntelSystem> = GRIntelSystem.Get(this.gi);
        if !IsDefined(intel) {
            return;
        }
        if this.kind == GRIntelCall.Extract() {
            intel.OnExtractRequested(this.entityID);
            return;
        }
        if this.kind == GRIntelCall.Marks() {
            intel.OnMarksTick();
            return;
        }
        intel.OnTick();
    }
}

// La accion no esta en ningun record Character.*: se suma a los NPC inconscientes marcados para intel. Solo se
// consultan estados del NPC (nativo): esto puede correr fuera del hilo principal.
@wrapMethod(ScriptedPuppetPS)
public final const func GetValidChoices(const actions: script_ref<array<wref<ObjectAction_Record>>>, const context: script_ref<GetActionsContext>,
        objectActionsCallbackController: wref<gameObjectActionsCallbackController>, checkPlayerQuickHackList: Bool, choices: script_ref<array<InteractionChoice>>) -> Void {
    wrappedMethod(actions, context, objectActionsCallbackController, checkPlayerQuickHackList, choices);
    if NotEquals(Deref(context).requestType, gamedeviceRequestType.Direct) {
        return;
    }
    let owner: wref<ScriptedPuppet> = this.GetOwnerEntity();
    if !IsDefined(owner) || owner.IsDead() || !ScriptedPuppet.IsUnconscious(owner) {
        return;
    }
    // "Extraer datos" mientras tenga IntelTarget. Sin TweakXL (o sin el .yaml) no hay record: nada.
    let extra: array<wref<ObjectAction_Record>>;
    if StatusEffectSystem.ObjectHasStatusEffect(owner, GRIntelSystem.TargetEffect()) {
        let extract: wref<ObjectAction_Record> = TweakDBInterface.GetObjectActionRecord(GRIntelSystem.ActionID());
        if IsDefined(extract) {
            ArrayPush(extra, extract);
        }
    }
    if ArraySize(extra) > 0 {
        wrappedMethod(extra, context, objectActionsCallbackController, checkPlayerQuickHackList, choices);
    }
}

// "Extraer datos" no tiene subida (activationTime vacio): el juego la completa enseguida. Solo se agenda.
@wrapMethod(BaseScriptableAction)
public func CompleteAction(gameInstance: GameInstance) -> Void {
    wrappedMethod(gameInstance);
    if this.GetObjectActionID() == GRIntelSystem.ActionID() {
        GRIntelCall.Send(gameInstance, GRIntelCall.Extract(), this.GetRequesterID(), 0.0);
    }
}
