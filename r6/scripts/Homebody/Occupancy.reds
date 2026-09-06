module Homebody

// The workspot system has no reservation query for world spots, and the
// probe run of 2026-09-06 sat the NPC on top of a resident. So a spot is
// treated as taken when any other puppet that is in a workspot stands
// within about a metre of it. The puppets are found with a targeting
// query around the roaming NPC.
public class Occupancy {
  public static func TakenPositions(self: ref<ScriptedPuppet>, radius: Float) -> array<Vector4> {
    let out: array<Vector4>;
    let gi: GameInstance = GetGameInstance();
    let wss: ref<WorkspotGameSystem> = GameInstance.GetWorkspotSystem(gi);
    let query: TargetSearchQuery = TSQ_NPC();
    query.searchFilter = TSF_Any(TSFMV.Obj_Puppet);
    query.maxDistance = radius;
    query.testedSet = TargetingSet.Complete;
    let parts: array<TS_TargetPartInfo>;
    GameInstance.GetTargetingSystem(gi).GetTargetParts(self, query, parts);
    let i: Int32 = 0;
    while i < ArraySize(parts) {
      let ent: wref<GameObject> = TS_TargetPartInfo.GetComponent(parts[i]).GetEntity() as GameObject;
      let other: ref<ScriptedPuppet> = ent as ScriptedPuppet;
      if IsDefined(other) && !Equals(other.GetEntityID(), self.GetEntityID()) && wss.IsActorInWorkspot(other) {
        ArrayPush(out, other.GetWorldPosition());
      };
      i += 1;
    };
    return out;
  }

  public static func Free(spots: array<ref<Spot>>, taken: array<Vector4>, tolerance: Float) -> array<ref<Spot>> {
    let out: array<ref<Spot>>;
    let s: ref<Spot>;
    for s in spots {
      let busy: Bool = false;
      let p: Vector4;
      for p in taken {
        if Vector4.Distance(p, s.position) <= tolerance { busy = true; };
      };
      if !busy { ArrayPush(out, s); };
    };
    return out;
  }
}
