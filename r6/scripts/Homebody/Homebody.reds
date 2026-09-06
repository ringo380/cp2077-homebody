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
    HomebodyLog.Info("attached (gen " + IntToString(this.m_gen) + ")");
  }

  private func OnDetach() -> Void {
    this.m_gen += 1;
    HomebodyLog.Info("detached");
  }

  private func OnPlayerAttach(request: ref<PlayerAttachRequest>) -> Void {
    HomebodyLog.Info("player attached; tick chain starts");
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
    this.Schedule();
  }
}
