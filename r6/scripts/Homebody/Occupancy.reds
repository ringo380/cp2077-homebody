module Homebody

// The workspot system has no reservation query for world spots, and the
// probe run of 2026-09-06 sat the NPC on top of a resident. So a spot is
// treated as taken when any other puppet that is in a workspot stands
// within about a metre of it. The puppets are found with a targeting
// query around the roaming NPC.
public class Occupancy {
  // raw receives the number of puppets the query returned before the
  // workspot filter, so the debug log can tell a blind query from a filter
  // that drops seated crowd residents.
  public static func TakenPositions(self: ref<ScriptedPuppet>, radius: Float, out raw: Int32) -> array<Vector4> {
    let out: array<Vector4>;
    raw = 0;
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
      if IsDefined(other) && !Equals(other.GetEntityID(), self.GetEntityID()) { raw += 1; };
      if IsDefined(other) && !Equals(other.GetEntityID(), self.GetEntityID()) && wss.IsActorInWorkspot(other) {
        ArrayPush(out, other.GetWorldPosition());
      };
      i += 1;
    };
    return out;
  }

  // For the debug log: each spot with a seated puppet within three metres
  // and how far away that puppet is, so a miss by the tolerance shows.
  public static func Nearest(spots: array<ref<Spot>>, taken: array<Vector4>) -> String {
    let out: String = "";
    let s: ref<Spot>;
    for s in spots {
      let best: Float = 999.0;
      let p: Vector4;
      for p in taken {
        let dist: Float = Vector4.Distance(p, s.position);
        if dist < best { best = dist; };
      };
      if best <= 3.0 { out += "; " + s.nodeKey + " has one " + FloatToStringPrec(best, 2) + " m away"; };
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
