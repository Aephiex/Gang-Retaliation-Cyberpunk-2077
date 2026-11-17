module GangRetaliation

@wrapMethod(PreventionSystem)
private final func CalculateCrimeScoreForNPC(request: ref<PreventionDamageRequest>) -> Void {
    let spawner: ref<GRSpawner> = GRSpawner.Get(this.GetGameInstance());
    if IsDefined(spawner) && (spawner.IsPoliceImmune() || spawner.IsAmbushActive()) {
        return;
    }
    wrappedMethod(request);
}
