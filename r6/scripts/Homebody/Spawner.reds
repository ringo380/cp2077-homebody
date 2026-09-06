module Homebody
import Codeware.*

public class SpawnedBody extends IScriptable {
  public let homeId: String;
  public let entityId: EntityID;
  public let spawnedAt: Float;
  public let attached: Bool;
}

// Spawns each home's resident when the player comes within spawnMeters of
// the home and removes it beyond despawnMeters. Nothing is persisted: a
// session end removes every body and every workspot device. Homes without
// a spawn record are attach-only and ignored here.
public class Spawner extends IScriptable {
  private let m_system: wref<HomebodySystem>;
  private let m_bodies: array<ref<SpawnedBody>>;
  private let m_spawnMeters: Float = 40.0;
  private let m_despawnMeters: Float = 70.0;

  public func Init(system: wref<HomebodySystem>) -> Void {
    this.m_system = system;
  }

  public func SetRange(spawnMeters: Float, despawnMeters: Float) -> Void {
    this.m_spawnMeters = spawnMeters;
    this.m_despawnMeters = MaxF(despawnMeters, spawnMeters + 5.0);
  }

  private func Find(homeId: String) -> ref<SpawnedBody> {
    let b: ref<SpawnedBody>;
    for b in this.m_bodies {
      if Equals(b.homeId, homeId) { return b; };
    };
    return null;
  }

  public func Count() -> Int32 {
    return ArraySize(this.m_bodies);
  }

  public func Tick(homes: array<ref<Home>>, playerPos: Vector4, now: Float) -> Void {
    let sys: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
    if !IsDefined(sys) || !sys.IsReady() { return; };
    let h: ref<Home>;
    for h in homes {
      if h.hasSpawn {
        let dist: Float = Vector4.Distance(playerPos, h.bounds.Center());
        let b: ref<SpawnedBody> = this.Find(h.id);
        if !IsDefined(b) {
          if dist <= this.m_spawnMeters { this.Spawn(sys, h, now); };
        } else {
          if dist > this.m_despawnMeters {
            this.Despawn(sys, b, "range");
          } else {
            if !b.attached && sys.IsSpawned(b.entityId) {
              b.attached = this.m_system.Attach(b.entityId, h.id, "");
              if !b.attached { this.Despawn(sys, b, "attach failed"); };
            } else {
              if !b.attached && now - b.spawnedAt > 20.0 {
                this.Despawn(sys, b, "never spawned");
              };
            };
          };
        };
      };
    };
  }

  private func Spawn(sys: ref<DynamicEntitySystem>, h: ref<Home>, now: Float) -> Void {
    let spec: ref<DynamicEntitySpec> = new DynamicEntitySpec();
    spec.recordID = TDBID.Create(h.spawnRecord);
    if StrLen(h.spawnAppearance) > 0 { spec.appearanceName = StringToName(h.spawnAppearance); };
    spec.position = h.spawnPosition;
    let e: EulerAngles;
    spec.orientation = EulerAngles.ToQuat(e);
    spec.persistState = false;
    spec.persistSpawn = false;
    spec.alwaysSpawned = false;
    spec.spawnInView = true;
    let tags: array<CName>;
    ArrayPush(tags, n"Homebody");
    ArrayPush(tags, StringToName("Homebody." + h.id));
    spec.tags = tags;
    let id: EntityID = sys.CreateEntity(spec);
    if !EntityID.IsDefined(id) {
      HomebodyLog.Warn(h.id + ": CreateEntity returned no id for " + h.spawnRecord);
      return;
    };
    let b: ref<SpawnedBody> = new SpawnedBody();
    b.homeId = h.id;
    b.entityId = id;
    b.spawnedAt = now;
    ArrayPush(this.m_bodies, b);
    HomebodyLog.Info(h.id + ": spawned " + h.spawnRecord + " " + EntityID.ToDebugString(id));
  }

  private func Despawn(sys: ref<DynamicEntitySystem>, b: ref<SpawnedBody>, why: String) -> Void {
    if b.attached { this.m_system.Detach(b.entityId); };
    sys.DeleteEntity(b.entityId);
    HomebodyLog.Info(b.homeId + ": despawned (" + why + ")");
    let i: Int32 = 0;
    while i < ArraySize(this.m_bodies) {
      if Equals(this.m_bodies[i].entityId, b.entityId) {
        ArrayErase(this.m_bodies, i);
      } else {
        i += 1;
      };
    };
  }

  public func DespawnAll() -> Void {
    let sys: ref<DynamicEntitySystem> = GameInstance.GetDynamicEntitySystem();
    let i: Int32 = ArraySize(this.m_bodies) - 1;
    while i >= 0 {
      if IsDefined(sys) { this.Despawn(sys, this.m_bodies[i], "session end"); };
      i -= 1;
    };
    ArrayClear(this.m_bodies);
    if IsDefined(sys) { sys.DeleteTagged(n"Homebody.device"); };
  }
}
