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

  public func GetSpots() -> array<ref<Spot>> {
    if !IsDefined(this.m_discovery) || !this.m_discovery.IsDone() {
      let none: array<ref<Spot>>;
      return none;
    };
    return this.m_discovery.GetSpots();
  }
}
