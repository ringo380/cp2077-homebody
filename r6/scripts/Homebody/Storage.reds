module Homebody
import RedFileSystem.*
import Codeware.*

// RedFileSystem grants a mod's storage once per process. A ScriptableSystem's
// OnAttach runs once per session, so a save reload would call GetStorage a
// second time and revoke it. ScriptableService.OnLoad runs once at script
// load, which is the lifetime the grant has.
public class HomebodyStorageService extends ScriptableService {
  private let m_storage: ref<FileSystemStorage>;

  private cb func OnLoad() -> Void {
    this.m_storage = FileSystem.GetStorage("Homebody");
    HomebodyTrace(this.m_storage, "svc-00-storage");
    if !IsDefined(this.m_storage) {
      HomebodyLog.Error("storage Homebody was not granted; no homes will load");
    };
  }

  public func GetStorage() -> ref<FileSystemStorage> {
    return this.m_storage;
  }

  public static func Get() -> ref<HomebodyStorageService> {
    return GameInstance.GetScriptableServiceContainer()
      .GetService(n"Homebody.HomebodyStorageService") as HomebodyStorageService;
  }
}
