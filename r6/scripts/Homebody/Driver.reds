module Homebody
import Codeware.*

// Carries out one Decision on one puppet. The native path sends the
// engine's own use-workspot command by node reference, which is how crowd
// citizens take a bench; it was proven on 2026-09-06. The manual path walks
// the NPC to the spot, spawns a workspot device entity there and plays the
// spot's workspot in it, and is what authored spots and native-failed spots
// use. Stages: 0 idle, 1 native moving, 2 native in spot, 3 native
// exiting, 4 manual moving, 5 manual device spawning, 6 manual in spot,
// 7 wandering. Every transition logs with the label the controller set.
public class Driver extends IScriptable {
  private let m_cfg: ref<HomebodyConfig>;
  private let m_label: String;
  private let m_decision: ref<Decision>;
  private let m_stage: Int32;
  private let m_stageAt: Float;
  private let m_useCmd: ref<AIUseWorkspotCommand>;
  private let m_moveCmd: ref<AIMoveToCommand>;
  private let m_deviceId: EntityID;
  private let m_manualRetry: Bool;
  private let m_hopTried: Bool;

  public func Init(cfg: ref<HomebodyConfig>, label: String) -> Void {
    this.m_cfg = cfg;
    this.m_label = label;
  }

  public func Label() -> String { return this.m_label; }
  public func IsUsingSpot() -> Bool { return this.m_stage == 2 || this.m_stage == 3 || this.m_stage == 6; }
  // True in every stage where finding the NPC in a workspot is expected,
  // including the approach: the native command seats the NPC before the
  // driver's next tick sees it.
  public func ExpectsWorkspot() -> Bool { return this.m_stage >= 1 && this.m_stage <= 6; }
  public func IsActive() -> Bool { return this.m_stage != 0; }
  public func Stage() -> Int32 { return this.m_stage; }
  public func CurrentDecision() -> ref<Decision> { return this.m_decision; }

  private func Result(outcome: DriverOutcome, reason: String) -> ref<DriverResult> {
    let r: ref<DriverResult> = new DriverResult();
    r.outcome = outcome;
    r.reason = reason;
    return r;
  }

  private func Enter(stage: Int32, now: Float) -> Void {
    this.m_stage = stage;
    this.m_stageAt = now;
  }

  public func Start(d: ref<Decision>, puppet: ref<ScriptedPuppet>, now: Float) -> Bool {
    this.m_decision = d;
    this.m_manualRetry = false;
    this.m_hopTried = false;
    let ai: ref<AIHumanComponent> = puppet.GetAIControllerComponent();
    if !IsDefined(ai) {
      HomebodyLog.Warn(this.m_label + " has no AI component; cannot drive");
      return false;
    };
    if Equals(d.kind, DecisionKind.Idle) {
      this.Enter(0, now);
      return true;
    };
    if Equals(d.kind, DecisionKind.Wander) {
      this.SendMove(ai, d.target, 0.5, false);
      this.Enter(7, now);
      HomebodyLog.Info(this.m_label + " wanders " + FloatToStringPrec(Vector4.Distance(puppet.GetWorldPosition(), d.target), 1) + " m");
      return true;
    };
    if Equals(d.spot.source, SpotSource.Manual) || d.spot.nativeFailed {
      return this.StartManual(ai, puppet, now);
    };
    let gref: GlobalNodeRef = ResolveNodeRef(d.spot.nodeRef, Cast<GlobalNodeRef>(GlobalNodeID.GetRoot()));
    if !GlobalNodeRef.IsDefined(gref) {
      HomebodyLog.Warn(this.m_label + " spot " + d.spot.nodeKey + " does not resolve (sector not streamed?); manual path");
      return this.StartManual(ai, puppet, now);
    };
    let cmd: ref<AIUseWorkspotCommand> = new AIUseWorkspotCommand();
    cmd.workspotNode = d.spot.nodeRef;
    cmd.moveToWorkspot = true;
    cmd.movementType = moveMovementType.Walk;
    cmd.continueInCombat = false;
    let sent: Bool = ai.SendCommand(cmd);
    this.m_useCmd = cmd;
    this.Enter(1, now);
    HomebodyLog.Info(this.m_label + " native use " + d.spot.activity + " " + d.spot.nodeKey + " for "
      + FloatToStringPrec(d.duration, 0) + " s (sent " + (sent ? "true" : "false") + ")");
    return true;
  }

  private func SendMove(ai: ref<AIHumanComponent>, target: Vector4, stopAt: Float, offNavmesh: Bool) -> Void {
    let cmd: ref<AIMoveToCommand> = new AIMoveToCommand();
    let ps: AIPositionSpec;
    let wp: WorldPosition;
    WorldPosition.SetVector4(wp, target);
    AIPositionSpec.SetWorldPosition(ps, wp);
    cmd.movementTarget = ps;
    cmd.movementType = moveMovementType.Walk;
    cmd.ignoreNavigation = offNavmesh;
    cmd.useStart = true;
    cmd.useStop = true;
    cmd.desiredDistanceFromTarget = stopAt;
    cmd.finishWhenDestinationReached = true;
    ai.SendCommand(cmd);
    this.m_moveCmd = cmd;
  }

  private func StartManual(ai: ref<AIHumanComponent>, puppet: ref<ScriptedPuppet>, now: Float) -> Bool {
    if !this.m_cfg.manualPathAvailable {
      HomebodyLog.Warn(this.m_label + " manual path unavailable for " + this.m_decision.spot.nodeKey);
      return false;
    };
    this.SendMove(ai, this.m_decision.spot.position, 0.4, false);
    this.Enter(4, now);
    HomebodyLog.Info(this.m_label + " manual walk to " + this.m_decision.spot.activity + " " + this.m_decision.spot.nodeKey);
    return true;
  }

  private func EndOne(ai: ref<AIHumanComponent>, cmd: ref<AICommand>) -> Void {
    if !IsDefined(cmd) { return; };
    if Equals(ai.GetCommandState(cmd), AICommandState.Executing) {
      ai.StopExecutingCommand(cmd, true);
    } else {
      ai.CancelCommand(cmd);
    };
  }

  // Ends whichever command is live. The move must be stopped before any
  // workspot play; with it still executing the play destroys the entity.
  private func EndCommands(ai: ref<AIHumanComponent>) -> Void {
    this.EndOne(ai, this.m_moveCmd);
    this.m_moveCmd = null;
    this.EndOne(ai, this.m_useCmd);
    this.m_useCmd = null;
  }

  private func DeleteDevice() -> Void {
    if !EntityID.IsDefined(this.m_deviceId) { return; };
    let sys: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
    if IsDefined(sys) { sys.DeleteEntity(this.m_deviceId); };
    let none: EntityID;
    this.m_deviceId = none;
  }

  public func Stop(puppet: ref<ScriptedPuppet>, why: String) -> Void {
    if this.m_stage == 0 { return; };
    let gi: GameInstance = GetGameInstance();
    let ai: ref<AIHumanComponent> = IsDefined(puppet) ? puppet.GetAIControllerComponent() : null;
    let wss: ref<WorkspotGameSystem> = GameInstance.GetWorkspotSystem(gi);
    if IsDefined(ai) { this.EndCommands(ai); };
    if IsDefined(puppet) && IsDefined(wss) && wss.IsActorInWorkspot(puppet) {
      if this.m_stage == 6 { wss.StopInDevice(puppet); } else { wss.SendFastExitSignal(puppet); };
    };
    this.DeleteDevice();
    HomebodyLog.Info(this.m_label + " stopped (" + why + ")");
    this.m_stage = 0;
  }

  public func Tick(puppet: ref<ScriptedPuppet>, now: Float) -> ref<DriverResult> {
    if this.m_stage == 0 { return this.Result(DriverOutcome.Done, "idle"); };
    let gi: GameInstance = GetGameInstance();
    let ai: ref<AIHumanComponent> = puppet.GetAIControllerComponent();
    let wss: ref<WorkspotGameSystem> = GameInstance.GetWorkspotSystem(gi);
    let elapsed: Float = now - this.m_stageAt;
    let inSpot: Bool = wss.IsActorInWorkspot(puppet);
    let d: ref<Decision> = this.m_decision;
    if this.m_stage == 1 {
      if inSpot {
        this.Enter(2, now);
        d.spot.lastUsedAt = now;
        HomebodyLog.Info(this.m_label + " in spot " + d.spot.nodeKey + " after " + FloatToStringPrec(elapsed, 1) + " s");
        return this.Result(DriverOutcome.Running, "");
      };
      let st: AICommandState = ai.GetCommandState(this.m_useCmd);
      let ended: Bool = Equals(st, AICommandState.Failure) || Equals(st, AICommandState.Cancelled) || Equals(st, AICommandState.Interrupted);
      if ended || elapsed > this.m_cfg.nativeTimeoutSeconds {
        HomebodyLog.Warn(this.m_label + " native path failed for " + d.spot.nodeKey + " (state " + IntToString(EnumInt(st))
          + ", " + FloatToStringPrec(elapsed, 0) + " s); marking native-failed");
        d.spot.nativeFailed = true;
        this.EndCommands(ai);
        if this.m_cfg.manualPathAvailable && !this.m_manualRetry {
          this.m_manualRetry = true;
          if this.StartManual(ai, puppet, now) { return this.Result(DriverOutcome.Running, ""); };
        };
        this.m_stage = 0;
        return this.Result(DriverOutcome.Failed, "nativeTimeout");
      };
      return this.Result(DriverOutcome.Running, "");
    };
    if this.m_stage == 2 {
      if !inSpot {
        HomebodyLog.Info(this.m_label + " left spot " + d.spot.nodeKey + " on its own after " + FloatToStringPrec(elapsed, 0) + " s");
        this.EndCommands(ai);
        this.m_stage = 0;
        return this.Result(DriverOutcome.Done, "finite");
      };
      if elapsed >= d.duration {
        wss.SendFastExitSignal(puppet);
        this.Enter(3, now);
      };
      return this.Result(DriverOutcome.Running, "");
    };
    if this.m_stage == 3 {
      if !inSpot || elapsed > 15.0 {
        if inSpot { wss.StopNpcInWorkspot(puppet); };
        this.EndCommands(ai);
        this.m_stage = 0;
        return this.Result(DriverOutcome.Done, "native");
      };
      return this.Result(DriverOutcome.Running, "");
    };
    if this.m_stage == 4 {
      let dist: Float = Vector4.Distance(puppet.GetWorldPosition(), d.spot.position);
      let st: AICommandState = ai.GetCommandState(this.m_moveCmd);
      let arrived: Bool = dist <= 0.9 || Equals(st, AICommandState.Success);
      if arrived {
        this.EndCommands(ai);
        return this.SpawnDevice(now);
      };
      if Equals(st, AICommandState.Failure) || elapsed > this.m_cfg.moveTimeoutSeconds {
        if this.m_cfg.allowOffNavmeshHops && !this.m_hopTried && dist <= 6.0 {
          this.m_hopTried = true;
          this.EndCommands(ai);
          this.SendMove(ai, d.spot.position, 0.4, true);
          this.Enter(4, now);
          HomebodyLog.Info(this.m_label + " off-navmesh hop of " + FloatToStringPrec(dist, 1) + " m to " + d.spot.nodeKey);
          return this.Result(DriverOutcome.Running, "");
        };
        HomebodyLog.Warn(this.m_label + " cannot reach " + d.spot.nodeKey + " (" + FloatToStringPrec(dist, 1) + " m left after "
          + FloatToStringPrec(elapsed, 0) + " s); marking unreachable");
        d.spot.unreachable = true;
        this.EndCommands(ai);
        this.m_stage = 0;
        return this.Result(DriverOutcome.Failed, "unreachable");
      };
      return this.Result(DriverOutcome.Running, "");
    };
    if this.m_stage == 5 {
      let sys: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
      if IsDefined(sys) && sys.IsSpawned(this.m_deviceId) {
        let device: ref<GameObject> = sys.GetEntity(this.m_deviceId) as GameObject;
        let comp: CName = StringToName(this.m_cfg.deviceComponent);
        if !IsDefined(device) || !IsDefined(device.FindComponentByName(comp)) {
          HomebodyLog.Warn(this.m_label + " device entity lacks component " + this.m_cfg.deviceComponent + "; manual path disabled");
          this.m_cfg.manualPathAvailable = false;
          this.DeleteDevice();
          this.m_stage = 0;
          return this.Result(DriverOutcome.Failed, "deviceComponent");
        };
        // workspotResource is a Codeware-added ResourceAsyncRef: copy, set
        // the path, write back. If the device plays its baked animation
        // instead of the spot's, this write did not take; see the findings.
        let wsc: ref<WorkspotResourceComponent> = device.FindComponentByName(comp) as WorkspotResourceComponent;
        if IsDefined(wsc) {
          let res: ResourceAsyncRef = wsc.workspotResource;
          ResourceAsyncRef.SetPath(res, ResRef.FromString(d.spot.workspotPath));
          wsc.workspotResource = res;
        };
        wss.PlayInDeviceSimple(device, puppet, false, comp, n"", n"", 0.0, WorkspotSlidingBehaviour.PlayAtResourcePosition);
        this.Enter(6, now);
        d.spot.lastUsedAt = now;
        HomebodyLog.Info(this.m_label + " manual play " + d.spot.workspotPath);
        return this.Result(DriverOutcome.Running, "");
      };
      if elapsed > 10.0 {
        HomebodyLog.Warn(this.m_label + " device entity did not spawn in 10 s");
        this.DeleteDevice();
        this.m_stage = 0;
        return this.Result(DriverOutcome.Failed, "deviceSpawn");
      };
      return this.Result(DriverOutcome.Running, "");
    };
    if this.m_stage == 6 {
      if elapsed >= d.duration || (!inSpot && elapsed > 3.0) {
        if inSpot { wss.StopInDevice(puppet); };
        this.DeleteDevice();
        this.m_stage = 0;
        return this.Result(DriverOutcome.Done, "manual");
      };
      return this.Result(DriverOutcome.Running, "");
    };
    if this.m_stage == 7 {
      let dist: Float = Vector4.Distance(puppet.GetWorldPosition(), d.target);
      let st: AICommandState = ai.GetCommandState(this.m_moveCmd);
      if dist <= 1.0 || Equals(st, AICommandState.Success) || Equals(st, AICommandState.Failure) || elapsed > this.m_cfg.moveTimeoutSeconds {
        this.EndCommands(ai);
        this.m_stage = 0;
        return this.Result(DriverOutcome.Done, "wander");
      };
      return this.Result(DriverOutcome.Running, "");
    };
    return this.Result(DriverOutcome.Done, "unknown stage");
  }

  private func SpawnDevice(now: Float) -> ref<DriverResult> {
    let sys: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
    if !IsDefined(sys) {
      this.m_stage = 0;
      return this.Result(DriverOutcome.Failed, "noDynamicEntitySystem");
    };
    let d: ref<Decision> = this.m_decision;
    let spec: ref<DynamicEntitySpec> = new DynamicEntitySpec();
    spec.templatePath = ResRef.FromString(this.m_cfg.deviceEntity);
    spec.position = d.spot.position;
    let e: EulerAngles;
    e.Yaw = d.spot.yaw;
    spec.orientation = EulerAngles.ToQuat(e);
    let tags: array<CName>;
    ArrayPush(tags, n"Homebody");
    ArrayPush(tags, n"Homebody.device");
    spec.tags = tags;
    this.m_deviceId = sys.CreateEntity(spec);
    if !EntityID.IsDefined(this.m_deviceId) {
      HomebodyLog.Warn(this.m_label + " device entity CreateEntity returned no id");
      this.m_stage = 0;
      return this.Result(DriverOutcome.Failed, "deviceCreate");
    };
    this.Enter(5, now);
    return this.Result(DriverOutcome.Running, "");
  }
}
