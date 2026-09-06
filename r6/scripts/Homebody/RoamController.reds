module Homebody
import Codeware.*

public enum RoamState {
  Discovering = 0,
  Idle = 1,
  Moving = 2,
  InSpot = 3,
  Paused = 4,
  Lost = 5
}

// One roaming NPC in one home. Waits for the home's discovery, then loops
// decide, drive, idle. Pauses while the NPC is in a scene, in combat, in a
// workspot the driver did not start, or paused through the API, and is
// lost when the entity is gone for longer than the grace period or dead.
public class RoamController extends IScriptable {
  private let m_entityId: EntityID;
  private let m_home: ref<Home>;
  private let m_rules: ref<Rules>;
  private let m_cfg: ref<HomebodyConfig>;
  private let m_spots: array<ref<Spot>>;
  private let m_driver: ref<Driver>;
  private let m_state: RoamState;
  private let m_pauseReason: String;
  private let m_userPaused: Bool;
  private let m_lostSince: Float;
  private let m_label: String;
  private let m_idleUntil: Float;

  public func Init(entityId: EntityID, home: ref<Home>, rules: ref<Rules>, cfg: ref<HomebodyConfig>) -> Void {
    this.m_entityId = entityId;
    this.m_home = home;
    this.m_rules = rules;
    this.m_cfg = cfg;
    this.m_label = home.id + "/" + EntityID.ToDebugString(entityId);
    this.m_driver = new Driver();
    this.m_driver.Init(cfg, this.m_label);
    this.m_state = RoamState.Discovering;
    this.m_lostSince = -1.0;
  }

  public func SetSpots(spots: array<ref<Spot>>) -> Void {
    this.m_spots = spots;
    if Equals(this.m_state, RoamState.Discovering) {
      this.m_state = RoamState.Idle;
      HomebodyLog.Info(this.m_label + " has " + IntToString(ArraySize(spots)) + " spots");
    };
  }

  public func EntityId() -> EntityID { return this.m_entityId; }
  public func IsLost() -> Bool { return Equals(this.m_state, RoamState.Lost); }
  public func HomeId() -> String { return this.m_home.id; }
  public func SetRules(r: ref<Rules>) -> Void { this.m_rules = r; }
  public func Label() -> String { return this.m_label; }

  public func GetState() -> CName {
    if Equals(this.m_state, RoamState.Discovering) { return n"Discovering"; };
    if Equals(this.m_state, RoamState.Idle) { return n"Idle"; };
    if Equals(this.m_state, RoamState.Moving) { return n"Moving"; };
    if Equals(this.m_state, RoamState.InSpot) { return n"InSpot"; };
    if Equals(this.m_state, RoamState.Paused) { return n"Paused"; };
    return n"Lost";
  }

  public func Describe() -> String {
    let d: ref<Decision> = this.m_driver.CurrentDecision();
    let doing: String = IsDefined(d) && this.m_driver.IsActive() ? d.why : "nothing";
    return this.m_label + " " + NameToString(this.GetState()) + " " + doing
      + (Equals(this.m_state, RoamState.Paused) ? " (" + this.m_pauseReason + ")" : "");
  }

  private func Puppet() -> ref<ScriptedPuppet> {
    let gi: GameInstance = GetGameInstance();
    let sys: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
    if IsDefined(sys) && sys.IsManaged(this.m_entityId) {
      return sys.GetEntity(this.m_entityId) as ScriptedPuppet;
    };
    return GameInstance.FindEntityByID(gi, this.m_entityId) as ScriptedPuppet;
  }

  public func Pause(why: String) -> Void {
    this.m_userPaused = true;
    this.EnterPaused(why);
  }

  public func Resume() -> Void {
    this.m_userPaused = false;
  }

  private func EnterPaused(why: String) -> Void {
    if !Equals(this.m_state, RoamState.Paused) {
      let p: ref<ScriptedPuppet> = this.Puppet();
      this.m_driver.Stop(p, "paused: " + why);
      HomebodyLog.Info(this.m_label + " paused (" + why + ")");
    };
    this.m_pauseReason = why;
    this.m_state = RoamState.Paused;
  }

  public func Shutdown() -> Void {
    let p: ref<ScriptedPuppet> = this.Puppet();
    this.m_driver.Stop(p, "detach");
    this.m_state = RoamState.Lost;
  }

  // Returns a non-empty reason when the NPC must not be driven right now.
  // A workspot counts as foreign only when the driver is in no stage that
  // expects one; the native command puts the NPC in the spot a tick or two
  // before the driver sees it.
  private func Interruption(puppet: ref<ScriptedPuppet>) -> String {
    if this.m_userPaused { return "api"; };
    let gi: GameInstance = GetGameInstance();
    if ScriptedPuppet.IsDefeated(puppet) || puppet.IsDead() { return "dead"; };
    let npc: ref<NPCPuppet> = puppet as NPCPuppet;
    if IsDefined(npc) && NPCPuppet.IsInCombat(npc) { return "combat"; };
    let scene: ref<SceneSystemInterface> = GameInstance.GetSceneSystem(gi).GetScriptInterface();
    if IsDefined(scene) && scene.IsEntityInScene(this.m_entityId) { return "scene"; };
    let wss: ref<WorkspotGameSystem> = GameInstance.GetWorkspotSystem(gi);
    if wss.IsActorInWorkspot(puppet) && !this.m_driver.ExpectsWorkspot() { return "foreign workspot"; };
    return "";
  }

  public func Tick(now: Float, hour: Int32) -> Void {
    if Equals(this.m_state, RoamState.Lost) { return; };
    let puppet: ref<ScriptedPuppet> = this.Puppet();
    if !IsDefined(puppet) {
      if this.m_lostSince < 0.0 { this.m_lostSince = now; };
      if now - this.m_lostSince > this.m_cfg.lostGraceSeconds {
        HomebodyLog.Warn(this.m_label + " entity gone for " + FloatToStringPrec(this.m_cfg.lostGraceSeconds, 0) + " s; controller lost");
        this.m_state = RoamState.Lost;
      };
      return;
    };
    this.m_lostSince = -1.0;
    if Equals(this.m_state, RoamState.Discovering) { return; };
    let why: String = this.Interruption(puppet);
    if Equals(why, "dead") {
      HomebodyLog.Info(this.m_label + " is dead; controller lost");
      this.m_driver.Stop(puppet, "dead");
      this.m_state = RoamState.Lost;
      return;
    };
    if !Equals(why, "") {
      this.EnterPaused(why);
      return;
    };
    if Equals(this.m_state, RoamState.Paused) {
      HomebodyLog.Info(this.m_label + " resumed after " + this.m_pauseReason);
      this.m_state = RoamState.Idle;
      this.m_idleUntil = now + 1.0;
      return;
    };
    if Equals(this.m_state, RoamState.Idle) {
      if now < this.m_idleUntil { return; };
      this.Decide(puppet, now, hour);
      return;
    };
    let r: ref<DriverResult> = this.m_driver.Tick(puppet, now);
    if Equals(r.outcome, DriverOutcome.Running) {
      this.m_state = this.m_driver.IsUsingSpot() ? RoamState.InSpot : RoamState.Moving;
      return;
    };
    if Equals(r.outcome, DriverOutcome.Failed) {
      HomebodyLog.Info(this.m_label + " decision failed: " + r.reason);
    };
    this.m_state = RoamState.Idle;
    this.m_idleUntil = now + 2.0;
  }

  private func Decide(puppet: ref<ScriptedPuppet>, now: Float, hour: Int32) -> Void {
    let pos: Vector4 = puppet.GetWorldPosition();
    let center: Vector4 = this.m_home.bounds.Center();
    let d: ref<Decision>;
    if !this.m_home.bounds.Contains(pos) && Vector4.Distance(pos, center) > this.m_home.bounds.radius + this.m_cfg.boundaryMargin {
      d = new Decision();
      d.kind = DecisionKind.Wander;
      d.target = center;
      d.duration = 5.0;
      d.why = "outside boundary";
      HomebodyLog.Info(this.m_label + " outside the home boundary; walking back");
    } else {
      let taken: array<Vector4> = Occupancy.TakenPositions(puppet, this.m_home.bounds.radius + this.m_cfg.boundaryMargin + 5.0);
      let free: array<ref<Spot>> = Occupancy.Free(this.m_spots, taken, 1.0);
      if this.m_cfg.debug && ArraySize(free) < ArraySize(this.m_spots) {
        HomebodyLog.Info(this.m_label + " skips " + IntToString(ArraySize(this.m_spots) - ArraySize(free)) + " occupied spots");
      };
      d = Scheduler.Decide(free, hour, this.m_rules, now, center, this.m_cfg.manualPathAvailable, RandF(), RandF());
    };
    if Equals(d.kind, DecisionKind.Idle) {
      this.m_idleUntil = now + d.duration;
      if this.m_cfg.debug { HomebodyLog.Info(this.m_label + " idles " + FloatToStringPrec(d.duration, 0) + " s (" + d.why + ")"); };
      return;
    };
    if this.m_driver.Start(d, puppet, now) {
      this.m_state = RoamState.Moving;
    } else {
      this.m_idleUntil = now + 5.0;
    };
  }
}
