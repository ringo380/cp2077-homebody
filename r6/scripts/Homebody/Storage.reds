module Homebody
import RedFileSystem.*
import Codeware.*

// RedFileSystem grants a mod's storage once per process. A ScriptableSystem's
// OnAttach runs once per session, so a save reload would call GetStorage a
// second time and revoke it. ScriptableService.OnLoad runs once at script
// load, which is the lifetime the grant has.
public class HomebodyStorageService extends ScriptableService {
  private let m_storage: ref<FileSystemStorage>;
  private let m_classifier: ref<ActivityClassifier>;
  private let m_furniture: ref<FurnitureRules>;

  private cb func OnLoad() -> Void {
    this.m_classifier = new ActivityClassifier();
    this.m_classifier.InstallDefaults();
    this.m_furniture = new FurnitureRules();
    this.m_furniture.InstallDefaults();
    this.m_storage = FileSystem.GetStorage("Homebody");
    HomebodyTrace(this.m_storage, "svc-00-storage");
    if !IsDefined(this.m_storage) {
      HomebodyLog.Error("storage Homebody was not granted; no homes will load");
    };
  }

  public func GetStorage() -> ref<FileSystemStorage> {
    return this.m_storage;
  }

  public func GetClassifier() -> ref<ActivityClassifier> {
    return this.m_classifier;
  }

  public func GetFurniture() -> ref<FurnitureRules> {
    return this.m_furniture;
  }

  public static func Get() -> ref<HomebodyStorageService> {
    return GameInstance.GetScriptableServiceContainer()
      .GetService(n"Homebody.HomebodyStorageService") as HomebodyStorageService;
  }
}
