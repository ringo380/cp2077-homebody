module Homebody
import RedFileSystem.*
import Codeware.*

// One tick of the system. gen must match the system's current generation
// or this callback belongs to a retired chain and does nothing.
public class HomebodyTickCallback extends DelayCallback {
  public let system: wref<HomebodySystem>;
  public let gen: Int32;

  public func Call() -> Void {
    if !IsDefined(this.system) { return; };
    this.system.RunTick(this.gen);
  }
}

public class HomebodySystem extends ScriptableSystem {
  private let m_gen: Int32;
  private let m_storage: ref<FileSystemStorage>;
  private let m_ticks: Int32;
  private let m_tickSeconds: Float = 0.5;
  private let m_probe: ref<HomebodyProbe>;
  private let m_registry: ref<HomeRegistry>;
  private let m_controllers: array<ref<RoamController>>;
  private let m_discoveries: array<ref<SpotDiscovery>>;
  private let m_discoveryHomes: array<String>;
  private let m_spawner: ref<Spawner>;

  public static func Get(gi: GameInstance) -> ref<HomebodySystem> {
    return GameInstance.GetScriptableSystemsContainer(gi)
      .Get(n"Homebody.HomebodySystem") as HomebodySystem;
  }

  private func OnAttach() -> Void {
    this.m_gen += 1;
    this.m_ticks = 0;
    let svc: ref<HomebodyStorageService> = HomebodyStorageService.Get();
    this.m_storage = IsDefined(svc) ? svc.GetStorage() : null;
    HomebodyTrace(this.m_storage, "sys-00-attach");
    this.m_registry = new HomeRegistry();
    this.m_registry.Load(this.m_storage);
    let cfg: ref<HomebodyConfig> = this.m_registry.GetConfig();
    this.m_tickSeconds = cfg.tickSeconds;
    let depot: ref<ResourceDepot> = GameInstance.GetResourceDepot();
    cfg.manualPathAvailable = IsDefined(depot) && depot.ResourceExists(ResRef.FromString(cfg.deviceEntity));
    if !cfg.manualPathAvailable {
      HomebodyLog.Warn("device entity " + cfg.deviceEntity + " not found; manual path and extraSpots disabled");
    };
    this.m_probe = new HomebodyProbe();
    this.m_spawner = new Spawner();
    this.m_spawner.Init(this);
    this.m_spawner.SetRange(cfg.spawnMeters, cfg.despawnMeters);
    if cfg.runSelfTest {
      HomebodyLog.Info("self-test\n" + HomebodyRunSelfTests());
    };
    HomebodyLog.Info("attached (gen " + IntToString(this.m_gen) + ")");
  }

  // A new session streams different sectors, so discovery starts over.
  private func OnDetach() -> Void {
    this.m_gen += 1;
    if IsDefined(this.m_spawner) { this.m_spawner.DespawnAll(); };
    let c: ref<RoamController>;
    for c in this.m_controllers { c.Shutdown(); };
    ArrayClear(this.m_controllers);
    ArrayClear(this.m_discoveries);
    ArrayClear(this.m_discoveryHomes);
    HomebodyLog.Info("detached");
  }

  // The player attaches again on every save load without the system
  // detaching, so bumping the generation here retires the chain already
  // running before a new one starts.
  private func OnPlayerAttach(request: ref<PlayerAttachRequest>) -> Void {
    this.m_gen += 1;
    this.m_ticks = 0;
    HomebodyLog.Info("player attached; tick chain starts (gen " + IntToString(this.m_gen) + ")");
    this.Schedule();
  }

  public func GetStorage() -> ref<FileSystemStorage> {
    return this.m_storage;
  }

  public func GetRegistry() -> ref<HomeRegistry> {
    return this.m_registry;
  }

  public func Now() -> Float {
    return EngineTime.ToFloat(GameInstance.GetEngineTime(GetGameInstance()));
  }

  private func Schedule() -> Void {
    let cb: ref<HomebodyTickCallback> = new HomebodyTickCallback();
    cb.system = this;
    cb.gen = this.m_gen;
    GameInstance.GetDelaySystem(GetGameInstance()).DelayCallback(cb, this.m_tickSeconds, false);
  }

  public func RunTick(gen: Int32) -> Void {
    if gen != this.m_gen { return; };
    this.m_ticks += 1;
    if this.m_ticks == 1 || this.m_ticks % 120 == 0 {
      HomebodyLog.Info("tick " + IntToString(this.m_ticks));
    };
    let gi: GameInstance = GetGameInstance();
    let now: Float = this.Now();
    let hour: Int32 = GameTime.Hours(GameInstance.GetTimeSystem(gi).GetGameTime());
    this.ApplySettings(gi);
    this.m_probe.Tick();
    let d: ref<SpotDiscovery>;
    for d in this.m_discoveries { d.Tick(); };
    let i: Int32 = 0;
    while i < ArraySize(this.m_controllers) {
      let c: ref<RoamController> = this.m_controllers[i];
      if Equals(c.GetState(), n"Discovering") {
        let home: ref<Home> = this.m_registry.FindHome(c.HomeId());
        if IsDefined(home) && this.IsDiscoveryReady(home) { c.SetSpots(this.SpotsFor(home)); };
      };
      c.Tick(now, hour);
      if c.IsLost() {
        ArrayErase(this.m_controllers, i);
      } else {
        i += 1;
      };
    };
    let player: ref<PlayerPuppet> = GetPlayer(gi);
    if IsDefined(player) { this.m_spawner.Tick(this.m_registry.GetHomes(), player.GetWorldPosition(), now); };
    this.Schedule();
  }

  // The Mod Settings page wins over config.json for the values it shows.
  // Pause on an already paused controller only updates the reason and
  // Resume on a running one only clears the flag, so this is safe per tick.
  private func ApplySettings(gi: GameInstance) -> Void {
    let st: ref<HomebodySettings> = HomebodySettings.Get(gi);
    if !IsDefined(st) { return; };
    let cfg: ref<HomebodyConfig> = this.m_registry.GetConfig();
    cfg.debug = st.debug || cfg.debug;
    cfg.nativeTimeoutSeconds = st.nativeTimeoutSeconds;
    cfg.moveTimeoutSeconds = st.moveTimeoutSeconds;
    let c: ref<RoamController>;
    for c in this.m_controllers {
      if st.enabled { c.Resume(); } else { c.Pause("disabled"); };
    };
  }

  // Probe entry points, reached from the CET console through the bridge.
  public func ProbeSpots(radius: Float) -> String {
    return this.m_probe.StartSpots(radius);
  }

  public func ProbeStatus() -> String {
    return this.m_probe.Status();
  }

  public func ProbeListing() -> String {
    return this.m_probe.Listing();
  }

  public func ProbeUse(record: String, index: Int32) -> String {
    return this.m_probe.StartUse(record, index);
  }

  public func ProbeCleanup() -> String {
    return this.m_probe.Cleanup();
  }

  public func AttachProbe(record: String, homeId: String) -> String {
    let msg: String = this.m_probe.SpawnOnly(record);
    let id: EntityID = this.m_probe.ProbeEntityId();
    if !EntityID.IsDefined(id) { return msg; };
    return this.Attach(id, homeId, "") ? "attached probe NPC to " + homeId : "attach failed; see log";
  }

  public func ListHomes() -> String {
    let out: String = "";
    let h: ref<Home>;
    let homes: array<ref<Home>> = this.m_registry.GetHomes();
    for h in homes {
      out += h.id + " rules=" + h.rulesName + (h.hasSpawn ? " spawn=" + h.spawnRecord : " attach-only") + "\n";
    };
    return out;
  }

  public func ListControllers() -> String {
    let out: String = "";
    let c: ref<RoamController>;
    for c in this.m_controllers {
      out += c.Describe() + "\n";
    };
    return StrLen(out) == 0 ? "no NPCs attached\n" : out;
  }

  // Discovery is one pass per home per session, shared by every NPC in it.
  private func EnsureDiscovery(home: ref<Home>) -> ref<SpotDiscovery> {
    let i: Int32 = 0;
    while i < ArraySize(this.m_discoveryHomes) {
      if Equals(this.m_discoveryHomes[i], home.id) { return this.m_discoveries[i]; };
      i += 1;
    };
    let d: ref<SpotDiscovery> = new SpotDiscovery();
    d.verbose = this.m_registry.GetConfig().debug;
    d.Start(home.bounds, home.id);
    ArrayPush(this.m_discoveries, d);
    ArrayPush(this.m_discoveryHomes, home.id);
    return d;
  }

  public func IsDiscoveryReady(home: ref<Home>) -> Bool {
    let d: ref<SpotDiscovery> = this.EnsureDiscovery(home);
    return d.IsDone() || d.IsFailed();
  }

  // Discovered spots after exclude and retag, then the home's manual spots.
  public func SpotsFor(home: ref<Home>) -> array<ref<Spot>> {
    let out: array<ref<Spot>>;
    let d: ref<SpotDiscovery> = this.EnsureDiscovery(home);
    if !d.IsDone() && !d.IsFailed() { return out; };
    let found: array<ref<Spot>> = d.GetSpots();
    let cfg: ref<HomebodyConfig> = this.m_registry.GetConfig();
    if cfg.furnitureSpots && cfg.manualPathAvailable {
      let f: ref<Spot>;
      let furniture: array<ref<Spot>> = d.GetFurnitureSpots();
      for f in furniture { ArrayPush(found, f); };
    };
    let s: ref<Spot>;
    for s in found {
      let excluded: Bool = false;
      let ex: String;
      for ex in home.exclude {
        if Equals(ex, s.nodeKey) { excluded = true; };
      };
      if !excluded {
        let i: Int32 = 0;
        while i < ArraySize(home.retagKeys) {
          if Equals(home.retagKeys[i], s.nodeKey) { s.activity = home.retagValues[i]; };
          i += 1;
        };
        ArrayPush(out, s);
      };
    };
    let m: ref<Spot>;
    for m in home.extraSpots {
      ArrayPush(out, m);
    };
    return out;
  }

  private func FindController(id: EntityID) -> ref<RoamController> {
    let c: ref<RoamController>;
    for c in this.m_controllers {
      if Equals(c.EntityId(), id) { return c; };
    };
    return null;
  }

  public func Attach(entityId: EntityID, homeId: String, rulesName: String) -> Bool {
    if !IsDefined(this.m_registry) {
      HomebodyLog.Warn("attach: system not ready");
      return false;
    };
    let home: ref<Home> = this.m_registry.FindHome(homeId);
    if !IsDefined(home) {
      HomebodyLog.Warn("attach: unknown home " + homeId);
      return false;
    };
    if IsDefined(this.FindController(entityId)) {
      HomebodyLog.Warn("attach: " + EntityID.ToDebugString(entityId) + " is already attached");
      return false;
    };
    let rname: String = StrLen(rulesName) > 0 ? rulesName : home.rulesName;
    let rules: ref<Rules> = this.m_registry.FindRules(rname);
    if !IsDefined(rules) {
      HomebodyLog.Warn("attach: rules " + rname + " not found for " + homeId + "; default in use");
      rules = this.m_registry.FindRules("default");
    };
    let c: ref<RoamController> = new RoamController();
    c.Init(entityId, home, rules, this.m_registry.GetConfig());
    ArrayPush(this.m_controllers, c);
    this.EnsureDiscovery(home);
    HomebodyLog.Info("attached " + EntityID.ToDebugString(entityId) + " to " + homeId + " (rules " + rname + ")");
    return true;
  }

  public func Detach(entityId: EntityID) -> Void {
    let i: Int32 = 0;
    while i < ArraySize(this.m_controllers) {
      if Equals(this.m_controllers[i].EntityId(), entityId) {
        this.m_controllers[i].Shutdown();
        ArrayErase(this.m_controllers, i);
        HomebodyLog.Info("detached " + EntityID.ToDebugString(entityId));
        return;
      };
      i += 1;
    };
  }

  public func Pause(entityId: EntityID, why: String) -> Bool {
    let c: ref<RoamController> = this.FindController(entityId);
    if !IsDefined(c) { return false; };
    c.Pause(StrLen(why) > 0 ? why : "api");
    return true;
  }

  public func Resume(entityId: EntityID) -> Bool {
    let c: ref<RoamController> = this.FindController(entityId);
    if !IsDefined(c) { return false; };
    c.Resume();
    return true;
  }

  public func GetState(entityId: EntityID) -> CName {
    let c: ref<RoamController> = this.FindController(entityId);
    return IsDefined(c) ? c.GetState() : n"Detached";
  }

  public func IsAttached(entityId: EntityID) -> Bool {
    return IsDefined(this.FindController(entityId));
  }

  public func SetRules(entityId: EntityID, rulesName: String) -> Bool {
    let c: ref<RoamController> = this.FindController(entityId);
    let r: ref<Rules> = this.m_registry.FindRules(rulesName);
    if !IsDefined(c) || !IsDefined(r) { return false; };
    c.SetRules(r);
    return true;
  }

  // Writes every spot of a home to the log with its node key, which is
  // what exclude and retag entries name.
  public func DumpSpots(homeId: String) -> String {
    let home: ref<Home> = this.m_registry.FindHome(homeId);
    if !IsDefined(home) { return "unknown home " + homeId; };
    if !this.IsDiscoveryReady(home) { return "discovery for " + homeId + " still running; ask again"; };
    let spots: array<ref<Spot>> = this.SpotsFor(home);
    let s: ref<Spot>;
    for s in spots {
      HomebodyLog.Info("spot " + homeId + " " + SpotDiscovery.Describe(s));
    };
    return IntToString(ArraySize(spots)) + " spots for " + homeId + " written to the log";
  }

  public func AddClassifierRule(match: String, activity: String) -> Void {
    let cls: ref<ActivityClassifier> = ActivityClassifier.Get();
    if IsDefined(cls) { cls.AddRule(match, activity); };
  }

  // A furniture rule: a word in an entity template's file name, the
  // activity, and a vanilla workspot to play at that entity. Takes effect
  // on the next discovery (Rescan).
  public func AddFurnitureRule(match: String, activity: String, workspot: String) -> Void {
    let rules: ref<FurnitureRules> = FurnitureRules.Get();
    if IsDefined(rules) { rules.AddRule(match, activity, workspot); };
  }

  public func SetFurnitureOffset(match: String, activity: String, forward: Float, up: Float) -> Bool {
    let rules: ref<FurnitureRules> = FurnitureRules.Get();
    return IsDefined(rules) ? rules.SetOffset(match, activity, forward, up) : false;
  }

  public func FurnitureRulesText() -> String {
    let rules: ref<FurnitureRules> = FurnitureRules.Get();
    return IsDefined(rules) ? rules.Describe() : "";
  }

  // Drops a home's discovery so the next tick runs it again, for use after
  // AddClassifierRule or when sectors have streamed in since.
  public func Rescan(homeId: String) -> Bool {
    let i: Int32 = 0;
    while i < ArraySize(this.m_discoveryHomes) {
      if Equals(this.m_discoveryHomes[i], homeId) {
        ArrayErase(this.m_discoveryHomes, i);
        ArrayErase(this.m_discoveries, i);
        return true;
      };
      i += 1;
    };
    return false;
  }
}
