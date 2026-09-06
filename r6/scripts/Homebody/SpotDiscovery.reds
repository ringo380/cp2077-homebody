module Homebody
import Codeware.*

public enum DiscoveryState {
  Idle = 0,
  LoadingWorld = 1,
  LoadingBlocks = 2,
  LoadingSectors = 3,
  Reading = 4,
  Done = 5,
  Failed = 6
}

// Finds the world AI spots inside a boundary. The streaming world resource
// lists its blocks, each block lists sectors with a bounding box, and each
// sector lists its nodes with a transform and a node reference. The world
// object the running game hands back reports no block refs, so the world is
// loaded again from the depot by path, and if that copy lists none either
// the single all-blocks resource is loaded directly. Everything loads
// through resource tokens that are polled on the tick rather than through
// callbacks, so a wrong callback signature cannot fail silently. Two sectors
// are read per tick to keep a hitch off the frame.
public class SpotDiscovery extends IScriptable {
  private let m_state: DiscoveryState;
  private let m_bounds: ref<Bounds>;
  private let m_worldToken: ref<ResourceToken>;
  private let m_blockTokens: array<ref<ResourceToken>>;
  private let m_sectorTokens: array<ref<ResourceToken>>;
  private let m_nextSector: Int32;
  private let m_spots: array<ref<Spot>>;
  private let m_sectorsRead: Int32;
  private let m_nodesSeen: Int32;
  private let m_label: String;

  // The cooked world and its block list. Night City is the only world the
  // game streams during play; both paths were verified against the base
  // archives.
  public static func WorldPath() -> String {
    return "base\\worlds\\03_night_city\\_compiled\\default\\03_night_city.streamingworld";
  }

  public static func AllBlocksPath() -> String {
    return "base\\worlds\\03_night_city\\_compiled\\default\\blocks\\all.streamingblock";
  }

  public func Start(bounds: ref<Bounds>, label: String) -> Void {
    this.m_bounds = bounds;
    this.m_label = label;
    ArrayClear(this.m_blockTokens);
    ArrayClear(this.m_sectorTokens);
    ArrayClear(this.m_spots);
    this.m_nextSector = 0;
    this.m_sectorsRead = 0;
    this.m_nodesSeen = 0;
    let depot: ref<ResourceDepot> = GameInstance.GetResourceDepot();
    if !IsDefined(depot) {
      this.Fail("no ResourceDepot");
      return;
    };
    this.m_worldToken = depot.LoadResource(ResRef.FromString(SpotDiscovery.WorldPath()));
    if !IsDefined(this.m_worldToken) {
      this.Fail("LoadResource returned no token for the streaming world");
      return;
    };
    this.m_state = DiscoveryState.LoadingWorld;
  }

  public func Tick() -> Void {
    if Equals(this.m_state, DiscoveryState.LoadingWorld) { this.TickWorld(); return; };
    if Equals(this.m_state, DiscoveryState.LoadingBlocks) { this.TickBlocks(); return; };
    if Equals(this.m_state, DiscoveryState.LoadingSectors) { this.TickSectors(); return; };
    if Equals(this.m_state, DiscoveryState.Reading) { this.TickRead(); return; };
  }

  public func IsDone() -> Bool { return Equals(this.m_state, DiscoveryState.Done); }
  public func IsFailed() -> Bool { return Equals(this.m_state, DiscoveryState.Failed); }
  public func IsBusy() -> Bool {
    return !this.IsDone() && !this.IsFailed() && !Equals(this.m_state, DiscoveryState.Idle);
  }
  public func GetSpots() -> array<ref<Spot>> { return this.m_spots; }

  private func Fail(why: String) -> Void {
    HomebodyLog.Warn(this.m_label + " discovery failed: " + why);
    this.m_state = DiscoveryState.Failed;
  }

  private func AllFinished(tokens: array<ref<ResourceToken>>) -> Bool {
    let t: ref<ResourceToken>;
    for t in tokens {
      if !t.IsFinished() { return false; };
    };
    return true;
  }

  private func TickWorld() -> Void {
    if !this.m_worldToken.IsFinished() { return; };
    let depot: ref<ResourceDepot> = GameInstance.GetResourceDepot();
    let fromWorld: Int32 = 0;
    if this.m_worldToken.IsLoaded() {
      let world: ref<worldStreamingWorld> = this.m_worldToken.GetResource() as worldStreamingWorld;
      if IsDefined(world) {
        let blocks: array<ResourceRef> = world.blockRefs;
        let i: Int32 = 0;
        while i < ArraySize(blocks) {
          let r: ResourceRef = blocks[i];
          let path: ResRef = ResourceRef.GetPath(r);
          let tok: ref<ResourceToken> = depot.LoadResource(path);
          if IsDefined(tok) {
            ArrayPush(this.m_blockTokens, tok);
            fromWorld += 1;
          };
          i += 1;
        };
      };
    } else {
      HomebodyLog.Warn(this.m_label + " discovery: streaming world failed to load from " + SpotDiscovery.WorldPath());
    };
    if fromWorld == 0 {
      let tok: ref<ResourceToken> = depot.LoadResource(ResRef.FromString(SpotDiscovery.AllBlocksPath()));
      if IsDefined(tok) { ArrayPush(this.m_blockTokens, tok); };
    };
    HomebodyLog.Info(this.m_label + " discovery: " + IntToString(ArraySize(this.m_blockTokens)) + " streaming blocks ("
      + IntToString(fromWorld) + " from the world resource)");
    if ArraySize(this.m_blockTokens) == 0 {
      this.Fail("no streaming blocks could be requested");
      return;
    };
    this.m_state = DiscoveryState.LoadingBlocks;
  }

  // Furniture lives in exterior and interior sectors. Quest sectors are
  // numerous and carry world-sized boxes, so a small boundary intersects
  // thousands of them; navigation sectors hold navmesh only. Both are skipped.
  private func WantsCategory(c: worldStreamingSectorCategory) -> Bool {
    return Equals(c, worldStreamingSectorCategory.Exterior) || Equals(c, worldStreamingSectorCategory.Interior);
  }

  private static func BoxExtent(b: Box) -> Float {
    let x: Float = b.Max.X - b.Min.X;
    let y: Float = b.Max.Y - b.Min.Y;
    let z: Float = b.Max.Z - b.Min.Z;
    return MaxF(x, MaxF(y, z));
  }

  private func TickBlocks() -> Void {
    if !this.AllFinished(this.m_blockTokens) { return; };
    let depot: ref<ResourceDepot> = GameInstance.GetResourceDepot();
    let matched: Int32 = 0;
    let total: Int32 = 0;
    let skipped: Int32 = 0;
    let huge: Int32 = 0;
    let byCategory: array<Int32>;
    let byLevel: array<Int32>;
    let k: Int32 = 0;
    while k < 8 { ArrayPush(byCategory, 0); ArrayPush(byLevel, 0); k += 1; };
    let bi: Int32 = 0;
    while bi < ArraySize(this.m_blockTokens) {
      let bt: ref<ResourceToken> = this.m_blockTokens[bi];
      if bt.IsLoaded() {
        let block: ref<worldStreamingBlock> = bt.GetResource() as worldStreamingBlock;
        if IsDefined(block) {
          let descs: array<worldStreamingSectorDescriptor> = block.descriptors;
          let di: Int32 = 0;
          while di < ArraySize(descs) {
            let d: worldStreamingSectorDescriptor = descs[di];
            total += 1;
            if this.m_bounds.IntersectsBox(d.streamingBox) {
              let cat: Int32 = EnumInt(d.category);
              let lvl: Int32 = Cast<Int32>(d.level);
              if cat >= 0 && cat < 8 { byCategory[cat] += 1; };
              if lvl >= 0 && lvl < 8 { byLevel[lvl] += 1; };
              if SpotDiscovery.BoxExtent(d.streamingBox) > 400.0 { huge += 1; };
              if this.WantsCategory(d.category) {
                let aref: ResourceAsyncRef = d.data;
                let path: ResRef = ResourceAsyncRef.GetPath(aref);
                let st: ref<ResourceToken> = depot.LoadResource(path);
                if IsDefined(st) {
                  ArrayPush(this.m_sectorTokens, st);
                  matched += 1;
                };
              } else {
                skipped += 1;
              };
            };
            di += 1;
          };
        } else {
          HomebodyLog.Warn(this.m_label + " discovery: block loaded but is not a worldStreamingBlock: " + ResRef.ToString(bt.GetPath()));
        };
      } else {
        HomebodyLog.Warn(this.m_label + " discovery: block failed to load: " + ResRef.ToString(bt.GetPath()));
      };
      bi += 1;
    };
    HomebodyLog.Info(this.m_label + " discovery: " + IntToString(matched) + " of " + IntToString(total) + " sectors intersect the boundary ("
      + IntToString(skipped) + " skipped by category, " + IntToString(huge) + " with a box over 400 m)");
    HomebodyLog.Info(this.m_label + " discovery: intersecting sectors by category (Exterior Interior Quest Navigation AlwaysLoaded ...) "
      + SpotDiscovery.Counts(byCategory) + "; by level " + SpotDiscovery.Counts(byLevel));
    if matched == 0 {
      this.m_state = DiscoveryState.Done;
      return;
    };
    this.m_state = DiscoveryState.LoadingSectors;
  }

  private func TickSectors() -> Void {
    if !this.AllFinished(this.m_sectorTokens) { return; };
    this.m_nextSector = 0;
    this.m_state = DiscoveryState.Reading;
  }

  private func TickRead() -> Void {
    let budget: Int32 = 2;
    while budget > 0 && this.m_nextSector < ArraySize(this.m_sectorTokens) {
      let st: ref<ResourceToken> = this.m_sectorTokens[this.m_nextSector];
      this.m_nextSector += 1;
      budget -= 1;
      if !st.IsLoaded() {
        HomebodyLog.Warn(this.m_label + " discovery: sector failed to load: " + ResRef.ToString(st.GetPath()));
      } else {
        let sector: ref<worldStreamingSector> = st.GetResource() as worldStreamingSector;
        if IsDefined(sector) { this.ReadSector(sector); };
      };
    };
    if this.m_nextSector >= ArraySize(this.m_sectorTokens) {
      HomebodyLog.Info(this.m_label + " discovery done: " + IntToString(ArraySize(this.m_spots)) + " spots in "
        + IntToString(this.m_sectorsRead) + " sectors, " + IntToString(this.m_nodesSeen) + " nodes seen");
      this.m_state = DiscoveryState.Done;
    };
  }

  private func ReadSector(sector: ref<worldStreamingSector>) -> Void {
    this.m_sectorsRead += 1;
    let count: Int32 = sector.GetNodeSetupCount();
    let i: Int32 = 0;
    while i < count {
      let setup: ref<WorldNodeSetupWrapper> = sector.GetNodeSetup(i);
      i += 1;
      this.m_nodesSeen += 1;
      let node: ref<worldNode> = IsDefined(setup) ? setup.GetNode() : null;
      let spotNode: ref<worldAISpotNode> = node as worldAISpotNode;
      if IsDefined(spotNode) {
        let pos: Vector4 = setup.GetPosition();
        if this.m_bounds.Contains(pos) {
          let action: ref<AIActionSpot> = spotNode.spot as AIActionSpot;
          if IsDefined(action) {
            let s: ref<Spot> = new Spot();
            s.nodeRef = setup.GetNodeRef();
            let gid: GlobalNodeID = setup.GetGlobalNodeID();
            s.nodeKey = ToString(gid.hash);
            s.position = pos;
            let q: Quaternion = setup.GetOrientation();
            let e: EulerAngles = Quaternion.ToEulerAngles(q);
            s.yaw = e.Yaw;
            let res: ResourceAsyncRef = action.resource;
            let path: ResRef = ResourceAsyncRef.GetPath(res);
            s.workspotPath = ResRef.ToString(path);
            s.markings = spotNode.markings;
            s.isInfinite = spotNode.isWorkspotInfinite;
            s.source = SpotSource.Discovered;
            let cls: ref<ActivityClassifier> = ActivityClassifier.Get();
            s.activity = IsDefined(cls) ? cls.Classify(s.markings, s.workspotPath) : "idle";
            ArrayPush(this.m_spots, s);
          };
        };
      };
    };
  }

  private static func Counts(v: array<Int32>) -> String {
    let out: String = "";
    let i: Int32 = 0;
    while i < ArraySize(v) {
      out += (i > 0 ? " " : "") + IntToString(v[i]);
      i += 1;
    };
    return out;
  }

  public static func Describe(s: ref<Spot>) -> String {
    let marks: String = "";
    let m: CName;
    for m in s.markings {
      marks += NameToString(m) + " ";
    };
    return s.nodeKey + " at (" + FloatToStringPrec(s.position.X, 1) + ", " + FloatToStringPrec(s.position.Y, 1)
      + ", " + FloatToStringPrec(s.position.Z, 1) + ") yaw " + FloatToStringPrec(s.yaw, 0)
      + " " + s.activity + " " + (s.isInfinite ? "infinite " : "finite ") + "[" + marks + "] " + s.workspotPath;
  }
}
