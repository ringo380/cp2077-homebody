module Homebody
import RedFileSystem.*
import Codeware.*

// One tick of the system. gen must match the system's current generation
// or this callback belongs to a detached session and does nothing.
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
    if cfg.runSelfTest {
      HomebodyLog.Info("self-test
" + HomebodyRunSelfTests());
    };
    HomebodyLog.Info("attached (gen " + IntToString(this.m_gen) + ")");
  }

  public func ProbeSpots(radius: Float) -> String {
    return this.m_probe.StartSpots(radius);
  }

  public func ProbeUse(record: String, index: Int32) -> String {
    return this.m_probe.StartUse(record, index);
  }

  public func ProbeCleanup() -> String {
    return this.m_probe.Cleanup();
  }

  public func GetRegistry() -> ref<HomeRegistry> {
    return this.m_registry;
  }

  public func ListHomes() -> String {
    let out: String = "";
    let h: ref<Home>;
    let homes: array<ref<Home>> = this.m_registry.GetHomes();
    for h in homes {
      out += h.id + " rules=" + h.rulesName + (h.hasSpawn ? " spawn=" + h.spawnRecord : " attach-only") + "
";
    };
    return out;
  }

  private func OnDetach() -> Void {
    this.m_gen += 1;
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
    this.m_probe.Tick();
    this.Schedule();
  }
}
