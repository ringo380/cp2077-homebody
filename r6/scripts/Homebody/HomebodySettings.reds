module Homebody

// Mod Settings page. Optional: without Mod Settings installed the class
// still exists with its defaults and nothing registers.
public class HomebodySettings extends ScriptableSystem {
  @runtimeProperty("ModSettings.mod", "Homebody")
  @runtimeProperty("ModSettings.category", "General")
  @runtimeProperty("ModSettings.category.order", "0")
  @runtimeProperty("ModSettings.displayName", "Enabled")
  @runtimeProperty("ModSettings.description", "Residents follow their routines. Off pauses every attached NPC.")
  public let enabled: Bool = true;

  @runtimeProperty("ModSettings.mod", "Homebody")
  @runtimeProperty("ModSettings.category", "General")
  @runtimeProperty("ModSettings.category.order", "0")
  @runtimeProperty("ModSettings.displayName", "Debug logging")
  @runtimeProperty("ModSettings.description", "Log every decision to the game log.")
  public let debug: Bool = false;

  @runtimeProperty("ModSettings.mod", "Homebody")
  @runtimeProperty("ModSettings.category", "Timing")
  @runtimeProperty("ModSettings.category.order", "1")
  @runtimeProperty("ModSettings.displayName", "Native workspot timeout")
  @runtimeProperty("ModSettings.description", "Seconds to wait for the engine to seat the NPC before falling back.")
  @runtimeProperty("ModSettings.step", "1.0")
  @runtimeProperty("ModSettings.min", "5.0")
  @runtimeProperty("ModSettings.max", "90.0")
  public let nativeTimeoutSeconds: Float = 25.0;

  @runtimeProperty("ModSettings.mod", "Homebody")
  @runtimeProperty("ModSettings.category", "Timing")
  @runtimeProperty("ModSettings.category.order", "1")
  @runtimeProperty("ModSettings.displayName", "Move timeout")
  @runtimeProperty("ModSettings.description", "Seconds a walk may take before the spot is marked unreachable.")
  @runtimeProperty("ModSettings.step", "1.0")
  @runtimeProperty("ModSettings.min", "5.0")
  @runtimeProperty("ModSettings.max", "120.0")
  public let moveTimeoutSeconds: Float = 40.0;

  public static func Get(game: GameInstance) -> ref<HomebodySettings> {
    return GameInstance.GetScriptableSystemsContainer(game).Get(n"Homebody.HomebodySettings") as HomebodySettings;
  }

  private func OnAttach() -> Void {
    this.RegisterWithModSettings();
  }

  private func OnDetach() -> Void {
    this.UnregisterFromModSettings();
  }

  @if(ModuleExists("ModSettingsModule"))
  private func RegisterWithModSettings() -> Void {
    ModSettings.RegisterListenerToClass(this);
  }

  @if(!ModuleExists("ModSettingsModule"))
  private func RegisterWithModSettings() -> Void {}

  @if(ModuleExists("ModSettingsModule"))
  private func UnregisterFromModSettings() -> Void {
    ModSettings.UnregisterListenerToClass(this);
  }

  @if(!ModuleExists("ModSettingsModule"))
  private func UnregisterFromModSettings() -> Void {}
}
