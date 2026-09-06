module Homebody
import Codeware.*

// Debug entry points. ProbeSpots runs discovery around the player and logs
// every spot found; the consumer sample exposes it on the CET console.
public class HomebodyProbe extends IScriptable {
  private let m_discovery: ref<SpotDiscovery>;
  private let m_reported: Bool;

  public func StartSpots(radius: Float) -> String {
    let player: ref<PlayerPuppet> = GetPlayer(GetGameInstance());
    if !IsDefined(player) { return "no player"; };
    let at: Vector4 = player.GetWorldPosition();
    this.m_discovery = new SpotDiscovery();
    this.m_reported = false;
    this.m_discovery.Start(Bounds.Sphere(at, radius), "probe");
    return "probing " + FloatToStringPrec(radius, 1) + " m around (" + FloatToStringPrec(at.X, 1) + ", "
      + FloatToStringPrec(at.Y, 1) + ", " + FloatToStringPrec(at.Z, 1) + ")";
  }

  public func Tick() -> Void {
    this.TickUse();
    if !IsDefined(this.m_discovery) { return; };
    this.m_discovery.Tick();
    if this.m_reported { return; };
    if this.m_discovery.IsFailed() {
      this.m_reported = true;
      return;
    };
    if this.m_discovery.IsDone() {
      this.m_reported = true;
      let spots: array<ref<Spot>> = this.m_discovery.GetSpots();
      let s: ref<Spot>;
      for s in spots {
        HomebodyLog.Info("probe spot " + SpotDiscovery.Describe(s));
      };
      HomebodyLog.Info("probe: " + IntToString(ArraySize(spots)) + " spots listed");
    };
  }

  // The native command probe: spawn one NPC beside the player and send it
  // to a discovered spot with AIUseWorkspotCommand, logging every command
  // state change. Stages: 0 none, 1 spawning, 2 commanded, 3 in spot,
  // 4 exiting, 5 finished.
  private let m_npcId: EntityID;
  private let m_cmd: ref<AIUseWorkspotCommand>;
  private let m_useSpot: ref<Spot>;
  private let m_useStart: Float;
  private let m_useStage: Int32;
  private let m_lastState: Int32;

  public func StartUse(record: String, index: Int32) -> String {
    let spots: array<ref<Spot>> = this.GetSpots();
    if ArraySize(spots) == 0 { return "no spots; run Probe first and wait for 'spots listed'"; };
    if index < 0 || index >= ArraySize(spots) { return "index out of range 0.." + IntToString(ArraySize(spots) - 1); };
    this.m_useSpot = spots[index];
    let gref: GlobalNodeRef = ResolveNodeRef(this.m_useSpot.nodeRef, Cast<GlobalNodeRef>(GlobalNodeID.GetRoot()));
    if !GlobalNodeRef.IsDefined(gref) {
      return "spot " + this.m_useSpot.nodeKey + " does not resolve; is its sector streamed in?";
    };
    let msg: String = this.SpawnOnly(record);
    if !EntityID.IsDefined(this.m_npcId) { return msg; };
    this.m_useStage = 1;
    this.m_lastState = -1;
    HomebodyLog.Info("probe use: spawning " + record + " for spot " + this.m_useSpot.nodeKey);
    return "spawning " + record + " for spot " + IntToString(index) + "; watch the log";
  }

  // Spawns the probe NPC beside the player without a command. Returns the
  // reason on failure; on success m_npcId is set.
  public func SpawnOnly(record: String) -> String {
    let none: EntityID;
    this.m_npcId = none;
    let sys: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
    if !IsDefined(sys) || !sys.IsReady() { return "dynamic entity system not ready"; };
    let player: ref<PlayerPuppet> = GetPlayer(GetGameInstance());
    if !IsDefined(player) { return "no player"; };
    let at: Vector4 = player.GetWorldPosition();
    let spec: ref<DynamicEntitySpec> = new DynamicEntitySpec();
    spec.recordID = TDBID.Create(record);
    spec.position = new Vector4(at.X + 1.5, at.Y + 1.5, at.Z, 1.0);
    spec.orientation = player.GetWorldOrientation();
    spec.persistState = false;
    spec.persistSpawn = false;
    spec.alwaysSpawned = false;
    spec.spawnInView = true;
    let tags: array<CName>;
    ArrayPush(tags, n"Homebody");
    ArrayPush(tags, n"Homebody.probe");
    spec.tags = tags;
    this.m_npcId = sys.CreateEntity(spec);
    if !EntityID.IsDefined(this.m_npcId) { return "CreateEntity returned no id for " + record; };
    this.m_useStage = 0;
    this.m_useStart = EngineTime.ToFloat(GameInstance.GetEngineTime(GetGameInstance()));
    return "spawned " + record;
  }

  public func ProbeEntityId() -> EntityID {
    return this.m_npcId;
  }

  private func Puppet() -> ref<ScriptedPuppet> {
    let sys: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
    if !IsDefined(sys) || !EntityID.IsDefined(this.m_npcId) { return null; };
    return sys.GetEntity(this.m_npcId) as ScriptedPuppet;
  }

  private func TickUse() -> Void {
    if this.m_useStage == 0 || this.m_useStage == 5 { return; };
    let gi: GameInstance = GetGameInstance();
    let now: Float = EngineTime.ToFloat(GameInstance.GetEngineTime(gi));
    let sys: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
    if this.m_useStage == 1 {
      if IsDefined(sys) && sys.IsSpawned(this.m_npcId) {
        let spawned: ref<ScriptedPuppet> = this.Puppet();
        let ai: ref<AIHumanComponent> = IsDefined(spawned) ? spawned.GetAIControllerComponent() : null;
        if !IsDefined(ai) {
          HomebodyLog.Warn("probe use: spawned entity has no AI component; giving up");
          this.m_useStage = 5;
          return;
        };
        let cmd: ref<AIUseWorkspotCommand> = new AIUseWorkspotCommand();
        cmd.workspotNode = this.m_useSpot.nodeRef;
        cmd.moveToWorkspot = true;
        cmd.movementType = moveMovementType.Walk;
        cmd.continueInCombat = false;
        let sent: Bool = ai.SendCommand(cmd);
        this.m_cmd = cmd;
        this.m_useStage = 2;
        this.m_useStart = now;
        HomebodyLog.Info("probe use: SendCommand(AIUseWorkspotCommand) returned " + (sent ? "true" : "false")
          + " for " + this.m_useSpot.nodeKey);
      } else {
        if now - this.m_useStart > 20.0 {
          HomebodyLog.Warn("probe use: NPC did not spawn within 20 s");
          this.m_useStage = 5;
        };
      };
      return;
    };
    let puppet: ref<ScriptedPuppet> = this.Puppet();
    if !IsDefined(puppet) {
      HomebodyLog.Warn("probe use: puppet handle lost");
      this.m_useStage = 5;
      return;
    };
    let ai: ref<AIHumanComponent> = puppet.GetAIControllerComponent();
    let wss: ref<WorkspotGameSystem> = GameInstance.GetWorkspotSystem(gi);
    let state: Int32 = EnumInt(ai.GetCommandState(this.m_cmd));
    let inSpot: Bool = wss.IsActorInWorkspot(puppet);
    let elapsed: Float = now - this.m_useStart;
    if state != this.m_lastState {
      this.m_lastState = state;
      HomebodyLog.Info("probe use: command state " + IntToString(state)
        + " (0 NotExecuting 1 Enqueued 2 Executing 3 Cancelled 4 Interrupted 5 Success 6 Failure), inWorkspot "
        + (inSpot ? "true" : "false") + ", active " + (ai.IsCommandActive(n"AIUseWorkspotCommand") ? "true" : "false"));
    };
    if this.m_useStage == 2 {
      if inSpot {
        this.m_useStage = 3;
        this.m_useStart = now;
        HomebodyLog.Info("probe use: NPC is in the workspot after " + FloatToStringPrec(elapsed, 1) + " s");
      } else {
        if elapsed > 40.0 {
          HomebodyLog.Warn("probe use: not in a workspot after 40 s; native path failed for " + this.m_useSpot.nodeKey);
          ai.CancelCommand(this.m_cmd);
          this.m_useStage = 5;
        };
      };
      return;
    };
    if this.m_useStage == 3 {
      if elapsed > 20.0 {
        wss.SendFastExitSignal(puppet);
        this.m_useStage = 4;
        this.m_useStart = now;
        HomebodyLog.Info("probe use: sent fast exit after 20 s in the spot");
      };
      return;
    };
    if this.m_useStage == 4 {
      if !inSpot {
        HomebodyLog.Info("probe use: NPC left the workspot after " + FloatToStringPrec(elapsed, 1) + " s; native path proven");
        this.m_useStage = 5;
      } else {
        if elapsed > 15.0 {
          HomebodyLog.Warn("probe use: still in the workspot 15 s after fast exit; trying StopNpcInWorkspot");
          wss.StopNpcInWorkspot(puppet);
          this.m_useStage = 5;
        };
      };
    };
  }

  public func Cleanup() -> String {
    let sys: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
    if IsDefined(sys) { sys.DeleteTagged(n"Homebody.probe"); };
    this.m_useStage = 0;
    let none: EntityID;
    this.m_npcId = none;
    return "probe NPCs removed";
  }

  public func GetSpots() -> array<ref<Spot>> {
    if !IsDefined(this.m_discovery) || !this.m_discovery.IsDone() {
      let none: array<ref<Spot>>;
      return none;
    };
    return this.m_discovery.GetSpots();
  }
}
