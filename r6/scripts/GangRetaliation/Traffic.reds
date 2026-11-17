module GangRetaliation

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


@addField(NPCPuppet)
public let m_grTrafficHitAt: Float;

@addField(NPCPuppet)
public let m_grRoadkillLogged: Bool;

@addField(NPCPuppet)
public let m_grRoadfallLogged: Bool;

public class GRRoadkill extends DelayCallback {
    public let gi: GameInstance;
    public let victimID: EntityID;
    public let driverID: EntityID;
    public let fall: Bool;

    public static func Window() -> Float { return 5.0; }

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

    public static func BlockFall(evt: ref<gameRagdollHitEvent>) -> Bool {
        if !IsDefined(evt) || !IsDefined(evt.attackComputed) {
            return false;
        }
        let npc: ref<NPCPuppet> = evt.target as NPCPuppet;
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
