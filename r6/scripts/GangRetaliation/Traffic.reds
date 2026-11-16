module GangRetaliation

// Vehiculos cargados alrededor de V (trafico y estacionados), para generar el auto de una emboscada
// pegado a uno que ya esta en la calle (idea de They Will Remember). TWR los encuentra con una entidad
// detectora propia (.ent); aca Codeware nos avisa cada vez que carga un vehiculo.
// El aviso puede llegar desde otro hilo: la lista se toca siempre con el candado.
public class GRTraffic extends ScriptableSystem {
    private let m_vehicles: array<wref<VehicleObject>>;
    private let m_lock: RWLock;

    public static func Get(gi: GameInstance) -> ref<GRTraffic> {
        return GameInstance.GetScriptableSystemsContainer(gi).Get(n"GangRetaliation.GRTraffic") as GRTraffic;
    }

    private func OnAttach() {
        let handler = GameInstance.GetCallbackSystem().RegisterCallback(n"Entity/Attached", this, n"OnVehicleAttached");
        if IsDefined(handler) {
            handler.AddTarget(EntityTarget.Type(n"vehicleBaseObject"));
        }
    }

    private func OnDetach() {
        GameInstance.GetCallbackSystem().UnregisterCallback(n"Entity/Attached", this);
    }

    private cb func OnVehicleAttached(event: ref<EntityLifecycleEvent>) {
        let vehicle: ref<VehicleObject> = event.GetEntity() as VehicleObject;
        if !IsDefined(vehicle) {
            return;
        }
        let prof: ref<GRProfiler> = GRProfiler.Get(vehicle.GetGame());
        if IsDefined(prof) {
            prof.vehicles += 1;
        }
        RWLock.Acquire(this.m_lock);
        // Los descargados quedan como wref vacias: se limpian aca para que la lista no crezca sin fin.
        if ArraySize(this.m_vehicles) > 120 {
            let alive: array<wref<VehicleObject>>;
            for v in this.m_vehicles {
                if IsDefined(v) {
                    ArrayPush(alive, v);
                }
            }
            this.m_vehicles = alive;
        }
        ArrayPush(this.m_vehicles, vehicle);
        RWLock.Release(this.m_lock);
    }

    public func GRProfState() -> String {
        RWLock.AcquireShared(this.m_lock);
        let n: Int32 = ArraySize(this.m_vehicles);
        RWLock.ReleaseShared(this.m_lock);
        return "trafficList=" + IntToString(n);
    }

    // Copia (mezclada) de los vehiculos que siguen cargados.
    public func GetVehicles() -> array<ref<VehicleObject>> {
        let result: array<ref<VehicleObject>>;
        RWLock.AcquireShared(this.m_lock);
        for v in this.m_vehicles {
            if IsDefined(v) {
                ArrayPush(result, v);
            }
        }
        RWLock.ReleaseShared(this.m_lock);
        let i: Int32 = ArraySize(result) - 1;
        while i > 0 {
            let j: Int32 = RandRange(0, i + 1);
            let tmp: ref<VehicleObject> = result[i];
            result[i] = result[j];
            result[j] = tmp;
            i -= 1;
        }
        return result;
    }
}

// --- Atropellos ---
// Un Nemesis no muere atropellado por el trafico (pedido en Nexus): no recibe dano de un vehiculo que no
// maneja V (trafico, aliados, NCPD, auto sin conductor) ni de la caida que le sigue. Si lo atropella V
// (al volante, por control remoto o con el hackeo de acelerar), todo cuenta normal.
// El juego reparte ese dano en dos golpes: el del vehiculo (gameVehicleHitEvent, que ademas marca al NPC
// para morir) y el del ragdoll al rodar por el suelo (gameRagdollHitEvent, unos 0.3 s despues y sin decir
// que fue un vehiculo). Por eso se anota en el NPC cuando lo toco un vehiculo ajeno.

// Momento (reloj del juego) del ultimo contacto con un vehiculo ajeno en movimiento; 0 = ninguno.
@addField(NPCPuppet)
public let m_grTrafficHitAt: Float;

// Ya se escribio en el log el atropello evitado de este NPC (golpe del vehiculo / caida posterior).
@addField(NPCPuppet)
public let m_grRoadkillLogged: Bool;

@addField(NPCPuppet)
public let m_grRoadfallLogged: Bool;

// Los hooks corren en hilos del motor (eventos del NPC y pipeline de dano): solo leen las listas del
// spawner, como GRTraits.OnHit. El log se arma en el hilo principal (esta misma clase, agendada).
public class GRRoadkill extends DelayCallback {
    public let gi: GameInstance;
    public let victimID: EntityID;
    public let driverID: EntityID;
    public let fall: Bool;

    // Segundos que vale la marca: lo que tarda en dejar de rodar despues del golpe.
    public static func Window() -> Float { return 5.0; }

    // Por debajo de esta velocidad (m/s) el vehiculo no atropella: un auto estacionado contra el que cae
    // el NPC no cuenta (si no, V perderia el dano de caida de casi todas las peleas en la calle).
    public static func MinSpeed() -> Float { return 1.0; }

    public static func IsNemesis(npc: ref<NPCPuppet>) -> Bool {
        if !IsDefined(npc) {
            return false;
        }
        let spawner: ref<GRSpawner> = GRSpawner.Get(npc.GetGame());
        if !IsDefined(spawner) || !spawner.HasOwnSpawns() {
            return false;
        }
        return spawner.GetNemesisId(npc.GetEntityID()) > 0;
    }

    public static func DrivenByV(vehicle: ref<VehicleObject>, instigator: wref<GameObject>) -> Bool {
        if IsDefined(instigator) && instigator.IsPlayer() {
            return true;
        }
        return IsDefined(vehicle) && (vehicle.IsPlayerDriver() || vehicle.IsVehicleRemoteControlled() || vehicle.IsVehicleAccelerateQuickhackActive());
    }

    private static func Now(gi: GameInstance) -> Float {
        return EngineTime.ToFloat(GameInstance.GetSimTime(gi));
    }

    // El ragdoll del NPC toco un vehiculo. Manda el ultimo que lo toco: el de V borra la marca.
    public static func OnVehicleContact(npc: ref<NPCPuppet>, vehicle: ref<VehicleObject>) {
        if Vector4.Length(vehicle.GetLinearVelocity()) < GRRoadkill.MinSpeed() || !GRRoadkill.IsNemesis(npc) {
            return;
        }
        if GRRoadkill.DrivenByV(vehicle, null) {
            npc.m_grTrafficHitAt = 0.0;
        } else {
            npc.m_grTrafficHitAt = GRRoadkill.Now(npc.GetGame());
        }
    }

    // true = golpe de un vehiculo que no maneja V contra un Nemesis: queda en 0 y no se procesa.
    public static func BlockVehicleHit(evt: ref<gameVehicleHitEvent>) -> Bool {
        if !IsDefined(evt) || !IsDefined(evt.attackData) || !IsDefined(evt.attackComputed) {
            return false;
        }
        let npc: ref<NPCPuppet> = evt.target as NPCPuppet;
        if !GRRoadkill.IsNemesis(npc) {
            return false;
        }
        let instigator: wref<GameObject> = evt.attackData.GetInstigator();
        if GRRoadkill.DrivenByV(evt.attackData.GetSource() as VehicleObject, instigator) {
            npc.m_grTrafficHitAt = 0.0;
            return false;
        }
        if Vector4.Length(evt.vehicleVelocity) >= GRRoadkill.MinSpeed() {
            npc.m_grTrafficHitAt = GRRoadkill.Now(npc.GetGame());
        }
        evt.attackComputed.SetAttackValue(0.0);
        if !npc.m_grRoadkillLogged {
            npc.m_grRoadkillLogged = true;
            let driverID: EntityID;
            if IsDefined(instigator) {
                driverID = instigator.GetEntityID();
            }
            GRRoadkill.Send(npc, driverID, false);
        }
        return true;
    }

    // true = dano de ragdoll (rodar, caer) de un Nemesis al que acaba de tocar un vehiculo ajeno.
    public static func BlockFall(evt: ref<gameRagdollHitEvent>) -> Bool {
        if !IsDefined(evt) || !IsDefined(evt.attackComputed) {
            return false;
        }
        let npc: ref<NPCPuppet> = evt.target as NPCPuppet;
        // La marca solo se le pone a un Nemesis: no hace falta volver a buscarlo en el spawner.
        if !IsDefined(npc) || npc.m_grTrafficHitAt <= 0.0 || GRRoadkill.Now(npc.GetGame()) - npc.m_grTrafficHitAt > GRRoadkill.Window() {
            return false;
        }
        evt.attackComputed.SetAttackValue(0.0);
        if !npc.m_grRoadfallLogged {
            npc.m_grRoadfallLogged = true;
            let nobody: EntityID;
            GRRoadkill.Send(npc, nobody, true);
        }
        return true;
    }

    private static func Send(npc: ref<NPCPuppet>, driverID: EntityID, fall: Bool) {
        let call: ref<GRRoadkill> = new GRRoadkill();
        call.gi = npc.GetGame();
        call.victimID = npc.GetEntityID();
        call.driverID = driverID;
        call.fall = fall;
        GameInstance.GetDelaySystem(call.gi).DelayCallback(call, 0.0, false);
    }

    // Hilo principal: una linea por Nemesis y por tipo de golpe (un atropello manda varios).
    public func Call() -> Void {
        let spawner: ref<GRSpawner> = GRSpawner.Get(this.gi);
        if !IsDefined(spawner) {
            return;
        }
        let text: String = "Atropello evitado: " + spawner.GetNemesisLabel(this.victimID)
            + " (rango " + IntToString(spawner.GetNemesisRank(this.victimID)) + ")";
        if this.fall {
            GRLog(text + " sin dano de la caida tras el golpe de un vehiculo que no manejaba V");
            return;
        }
        let who: String = "nadie (vehiculo sin conductor)";
        let driver: ref<GameObject> = GameInstance.FindEntityByID(this.gi, this.driverID) as GameObject;
        if IsDefined(driver) {
            let victim: ref<ScriptedPuppet> = GameInstance.FindEntityByID(this.gi, this.victimID) as ScriptedPuppet;
            let puppet: ref<ScriptedPuppet> = driver as ScriptedPuppet;
            who = "un NPC (" + GRTraits.HitSource(driver, victim);
            if IsDefined(puppet) {
                who += ", " + TDBID.ToStringDEBUG(puppet.GetRecordID());
            }
            who += ")";
        } else {
            if EntityID.IsDefined(this.driverID) {
                who = "un NPC que ya no esta cargado";
            }
        }
        GRLog(text + " sin dano del vehiculo; manejaba " + who);
    }
}

@wrapMethod(NPCPuppet)
protected cb func OnRagdollImpactEvent(evt: ref<RagdollImpactEvent>) -> Bool {
    if IsDefined(evt) {
        let vehicle: ref<VehicleObject> = evt.otherEntity as VehicleObject;
        if IsDefined(vehicle) {
            GRRoadkill.OnVehicleContact(this, vehicle);
        }
    }
    return wrappedMethod(evt);
}

// Sin llamar al original: ademas del dano, ahi el juego marca al NPC para morir (MarkForDeath).
@wrapMethod(DamageSystem)
private final func ProcessVehicleHit(hitEvent: ref<gameHitEvent>) -> Void {
    if GRRoadkill.BlockVehicleHit(hitEvent as gameVehicleHitEvent) {
        return;
    }
    wrappedMethod(hitEvent);
}

@wrapMethod(DamageSystem)
private final func ProcessRagdollHit(hitEvent: ref<gameHitEvent>) -> Void {
    if GRRoadkill.BlockFall(hitEvent as gameRagdollHitEvent) {
        return;
    }
    wrappedMethod(hitEvent);
}
