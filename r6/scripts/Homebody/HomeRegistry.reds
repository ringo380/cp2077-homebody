module Homebody
import RedFileSystem.*
import RedData.Json.*

public class HomebodyConfig extends IScriptable {
  public let runSelfTest: Bool = true;
  public let debug: Bool = false;
  public let tickSeconds: Float = 0.5;
  public let nativeTimeoutSeconds: Float = 25.0;
  public let moveTimeoutSeconds: Float = 40.0;
  public let lostGraceSeconds: Float = 10.0;
  public let boundaryMargin: Float = 2.0;
  public let allowOffNavmeshHops: Bool = false;
  public let deviceEntity: String = "base\\spawner\\workspot_device.ent";
  public let deviceComponent: String = "workspot";
  public let manualPathAvailable: Bool = false;
}

// One block of the day: activities and their relative weights between two
// hours. from == to means the whole day.
public class Phase extends IScriptable {
  public let from: Int32;
  public let to: Int32;
  public let activities: array<String>;
  public let weights: array<Float>;

  public func WeightOf(activity: String) -> Float {
    let i: Int32 = 0;
    while i < ArraySize(this.activities) {
      if Equals(this.activities[i], activity) { return this.weights[i]; };
      i += 1;
    };
    return 0.0;
  }
}

public class Rules extends IScriptable {
  public let name: String;
  public let phases: array<ref<Phase>>;
  public let durationActivities: array<String>;
  public let durationMin: array<Float>;
  public let durationMax: array<Float>;
  public let defaultMin: Float = 20.0;
  public let defaultMax: Float = 60.0;
  public let cooldownSeconds: Float = 90.0;
  public let wanderRadius: Float = 4.0;

  public func DurationRange(activity: String, out mn: Float, out mx: Float) -> Void {
    let i: Int32 = 0;
    while i < ArraySize(this.durationActivities) {
      if Equals(this.durationActivities[i], activity) {
        mn = this.durationMin[i];
        mx = this.durationMax[i];
        return;
      };
      i += 1;
    };
    mn = this.defaultMin;
    mx = this.defaultMax;
  }

  // Used when no rules file loads: one all-day phase, wander only.
  public static func Default() -> ref<Rules> {
    let r: ref<Rules> = new Rules();
    r.name = "builtin";
    let p: ref<Phase> = new Phase();
    p.from = 0;
    p.to = 0;
    ArrayPush(p.activities, "wander");
    ArrayPush(p.weights, 1.0);
    ArrayPush(r.phases, p);
    return r;
  }
}

public class Home extends IScriptable {
  public let id: String;
  public let bounds: ref<Bounds>;
  public let spawnRecord: String;
  public let spawnAppearance: String;
  // Defaults to the boundary center, which in an apartment is often inside
  // a table; homes that spawn should set it.
  public let spawnPosition: Vector4;
  public let hasSpawn: Bool;
  public let exclude: array<String>;
  public let retagKeys: array<String>;
  public let retagValues: array<String>;
  public let extraSpots: array<ref<Spot>>;
  public let rulesName: String = "default";
}

// Reads config.json, every home.<id>.json and every rules.<name>.json from
// the mod's storage. A bad file is skipped with a warning naming the file
// and the field; the rest still load.
public class HomeRegistry extends IScriptable {
  private let m_homes: array<ref<Home>>;
  private let m_rules: array<ref<Rules>>;
  private let m_config: ref<HomebodyConfig>;

  public func GetHomes() -> array<ref<Home>> { return this.m_homes; }
  public func GetConfig() -> ref<HomebodyConfig> {
    if !IsDefined(this.m_config) { this.m_config = new HomebodyConfig(); };
    return this.m_config;
  }

  public func FindHome(id: String) -> ref<Home> {
    let h: ref<Home>;
    for h in this.m_homes {
      if Equals(h.id, id) { return h; };
    };
    return null;
  }

  public func FindRules(name: String) -> ref<Rules> {
    let r: ref<Rules>;
    for r in this.m_rules {
      if Equals(r.name, name) { return r; };
    };
    return null;
  }

  public func Load(storage: ref<FileSystemStorage>) -> Void {
    ArrayClear(this.m_homes);
    ArrayClear(this.m_rules);
    this.m_config = new HomebodyConfig();
    if !IsDefined(storage) {
      HomebodyLog.Error("registry: no storage; using built-in defaults");
      let d: ref<Rules> = Rules.Default();
      d.name = "default";
      ArrayPush(this.m_rules, d);
      return;
    };
    if Equals(storage.IsFile("config.json"), FileSystemStatus.True) {
      let cf: ref<File> = storage.GetFile("config.json");
      let croot: ref<JsonVariant> = cf.ReadAsJson();
      this.m_config = HomeRegistry.ParseConfig(croot);
    } else {
      HomebodyLog.Warn("registry: config.json missing; using defaults");
    };
    let files: array<ref<File>> = storage.GetFiles();
    let f: ref<File>;
    for f in files {
      let name: String = f.GetFilename();
      if StrBeginsWith(name, "home.") && StrEndsWith(name, ".json") {
        let root: ref<JsonVariant> = f.ReadAsJson();
        let h: ref<Home> = HomeRegistry.ParseHome(root, name);
        if IsDefined(h) {
          if IsDefined(this.FindHome(h.id)) {
            HomebodyLog.Warn(name + ": duplicate id " + h.id + "; skipped");
          } else {
            ArrayPush(this.m_homes, h);
          };
        };
      } else {
        if StrBeginsWith(name, "rules.") && StrEndsWith(name, ".json") {
          let rname: String = StrMid(name, 6, StrLen(name) - 11);
          let rroot: ref<JsonVariant> = f.ReadAsJson();
          let r: ref<Rules> = HomeRegistry.ParseRules(rroot, rname);
          if IsDefined(r) { ArrayPush(this.m_rules, r); };
        };
      };
    };
    if !IsDefined(this.FindRules("default")) {
      HomebodyLog.Warn("registry: rules.default.json missing or invalid; built-in default in use");
      let d: ref<Rules> = Rules.Default();
      d.name = "default";
      ArrayPush(this.m_rules, d);
    };
    HomebodyLog.Info("registry: " + IntToString(ArraySize(this.m_homes)) + " homes, "
      + IntToString(ArraySize(this.m_rules)) + " rules");
  }

  public static func ParseConfig(root: ref<JsonVariant>) -> ref<HomebodyConfig> {
    let c: ref<HomebodyConfig> = new HomebodyConfig();
    if !IsDefined(root) || !root.IsObject() {
      HomebodyLog.Warn("config.json is not a JSON object; defaults in use");
      return c;
    };
    let o: ref<JsonObject> = root as JsonObject;
    if o.HasKey("runSelfTest") { c.runSelfTest = o.GetKeyBool("runSelfTest"); };
    if o.HasKey("debug") { c.debug = o.GetKeyBool("debug"); };
    if o.HasKey("tickSeconds") { c.tickSeconds = HomeRegistry.NumOf(o.GetKey("tickSeconds")); };
    if o.HasKey("nativeTimeoutSeconds") { c.nativeTimeoutSeconds = HomeRegistry.NumOf(o.GetKey("nativeTimeoutSeconds")); };
    if o.HasKey("moveTimeoutSeconds") { c.moveTimeoutSeconds = HomeRegistry.NumOf(o.GetKey("moveTimeoutSeconds")); };
    if o.HasKey("lostGraceSeconds") { c.lostGraceSeconds = HomeRegistry.NumOf(o.GetKey("lostGraceSeconds")); };
    if o.HasKey("boundaryMargin") { c.boundaryMargin = HomeRegistry.NumOf(o.GetKey("boundaryMargin")); };
    if o.HasKey("allowOffNavmeshHops") { c.allowOffNavmeshHops = o.GetKeyBool("allowOffNavmeshHops"); };
    if o.HasKey("deviceEntity") { c.deviceEntity = o.GetKeyString("deviceEntity"); };
    if o.HasKey("deviceComponent") { c.deviceComponent = o.GetKeyString("deviceComponent"); };
    if c.tickSeconds < 0.2 {
      HomebodyLog.Warn("config tickSeconds below 0.2; using 0.2");
      c.tickSeconds = 0.2;
    };
    return c;
  }

  // JSON numbers arrive as Int64, Uint64, or Double depending on how they
  // were written; modders write 12 as often as 12.0. Anything else is 0.
  public static func NumOf(v: ref<JsonVariant>) -> Float {
    if !IsDefined(v) { return 0.0; };
    if v.IsDouble() { return Cast<Float>(v.GetDouble()); };
    if v.IsInt64() { return Cast<Float>(v.GetInt64()); };
    if v.IsUint64() { return Cast<Float>(v.GetUint64()); };
    return 0.0;
  }

  // [x, y, z] to Vector4; ok is false on any shape problem.
  public static func ParseVec(v: ref<JsonVariant>, out ok: Bool) -> Vector4 {
    ok = false;
    let zero: Vector4 = new Vector4(0.0, 0.0, 0.0, 1.0);
    if !IsDefined(v) || !v.IsArray() { return zero; };
    let a: ref<JsonArray> = v as JsonArray;
    if a.GetSize() != 3u { return zero; };
    ok = true;
    return new Vector4(HomeRegistry.NumOf(a.GetItem(0u)), HomeRegistry.NumOf(a.GetItem(1u)),
      HomeRegistry.NumOf(a.GetItem(2u)), 1.0);
  }

  public static func ParseHome(root: ref<JsonVariant>, fileName: String) -> ref<Home> {
    if !IsDefined(root) || !root.IsObject() {
      HomebodyLog.Warn(fileName + ": not a JSON object; skipped");
      return null;
    };
    let o: ref<JsonObject> = root as JsonObject;
    let h: ref<Home> = new Home();
    if !o.HasKey("id") {
      HomebodyLog.Warn(fileName + ": missing id; skipped");
      return null;
    };
    h.id = o.GetKeyString("id");
    if StrLen(h.id) == 0 {
      HomebodyLog.Warn(fileName + ": empty id; skipped");
      return null;
    };
    let bv: ref<JsonVariant> = o.GetKey("bounds");
    if !IsDefined(bv) || !bv.IsObject() {
      HomebodyLog.Warn(fileName + ": missing bounds; skipped");
      return null;
    };
    let bo: ref<JsonObject> = bv as JsonObject;
    let ok: Bool;
    if bo.HasKey("center") {
      let c: Vector4 = HomeRegistry.ParseVec(bo.GetKey("center"), ok);
      if !ok {
        HomebodyLog.Warn(fileName + ": bounds.center must be [x, y, z]; skipped");
        return null;
      };
      let r: Float = bo.HasKey("radius") ? HomeRegistry.NumOf(bo.GetKey("radius")) : 10.0;
      if r <= 0.0 {
        HomebodyLog.Warn(fileName + ": bounds.radius must be above 0; skipped");
        return null;
      };
      h.bounds = Bounds.Sphere(c, r);
    } else {
      let mn: Vector4 = HomeRegistry.ParseVec(bo.GetKey("min"), ok);
      if !ok {
        HomebodyLog.Warn(fileName + ": bounds needs center+radius or min+max; skipped");
        return null;
      };
      let mx: Vector4 = HomeRegistry.ParseVec(bo.GetKey("max"), ok);
      if !ok {
        HomebodyLog.Warn(fileName + ": bounds.max must be [x, y, z]; skipped");
        return null;
      };
      h.bounds = Bounds.BoxOf(mn, mx);
    };
    h.spawnPosition = h.bounds.Center();
    let sv: ref<JsonVariant> = o.GetKey("spawn");
    if IsDefined(sv) && sv.IsObject() {
      let so: ref<JsonObject> = sv as JsonObject;
      h.spawnRecord = so.HasKey("record") ? so.GetKeyString("record") : "";
      h.spawnAppearance = so.HasKey("appearance") ? so.GetKeyString("appearance") : "";
      h.hasSpawn = StrLen(h.spawnRecord) > 0;
      if so.HasKey("position") {
        let sp: Vector4 = HomeRegistry.ParseVec(so.GetKey("position"), ok);
        if ok {
          h.spawnPosition = sp;
        } else {
          HomebodyLog.Warn(fileName + ": spawn.position must be [x, y, z]; using the boundary center");
        };
      };
      if !h.hasSpawn { HomebodyLog.Warn(fileName + ": spawn.record empty; home is attach-only"); };
    };
    let ev: ref<JsonVariant> = o.GetKey("exclude");
    if IsDefined(ev) && ev.IsArray() {
      let ea: ref<JsonArray> = ev as JsonArray;
      let i: Uint32 = 0u;
      while i < ea.GetSize() {
        ArrayPush(h.exclude, ea.GetItemString(i));
        i += 1u;
      };
    };
    let rv: ref<JsonVariant> = o.GetKey("retag");
    if IsDefined(rv) && rv.IsObject() {
      let ro: ref<JsonObject> = rv as JsonObject;
      let keys: array<String> = ro.GetKeys();
      let k: String;
      for k in keys {
        ArrayPush(h.retagKeys, k);
        ArrayPush(h.retagValues, ro.GetKeyString(k));
      };
    };
    let xv: ref<JsonVariant> = o.GetKey("extraSpots");
    if IsDefined(xv) && xv.IsArray() {
      let xa: ref<JsonArray> = xv as JsonArray;
      let j: Uint32 = 0u;
      while j < xa.GetSize() {
        let item: ref<JsonVariant> = xa.GetItem(j);
        j += 1u;
        if IsDefined(item) && item.IsObject() {
          let io: ref<JsonObject> = item as JsonObject;
          let s: ref<Spot> = new Spot();
          s.position = HomeRegistry.ParseVec(io.GetKey("position"), ok);
          if ok && io.HasKey("workspot") && io.HasKey("activity") {
            s.yaw = io.HasKey("yaw") ? HomeRegistry.NumOf(io.GetKey("yaw")) : 0.0;
            s.workspotPath = io.GetKeyString("workspot");
            s.activity = io.GetKeyString("activity");
            s.source = SpotSource.Manual;
            s.isInfinite = true;
            s.nodeKey = "manual-" + IntToString(ArraySize(h.extraSpots));
            ArrayPush(h.extraSpots, s);
          } else {
            HomebodyLog.Warn(fileName + ": extraSpots[" + IntToString(Cast<Int32>(j) - 1)
              + "] needs position, workspot, activity; skipped");
          };
        };
      };
    };
    if o.HasKey("rules") { h.rulesName = o.GetKeyString("rules"); };
    if StrLen(h.rulesName) == 0 { h.rulesName = "default"; };
    return h;
  }

  public static func ParseRules(root: ref<JsonVariant>, name: String) -> ref<Rules> {
    if !IsDefined(root) || !root.IsObject() {
      HomebodyLog.Warn("rules." + name + ".json: not a JSON object; skipped");
      return null;
    };
    let o: ref<JsonObject> = root as JsonObject;
    let r: ref<Rules> = new Rules();
    r.name = name;
    let pv: ref<JsonVariant> = o.GetKey("phases");
    if IsDefined(pv) && pv.IsArray() {
      let pa: ref<JsonArray> = pv as JsonArray;
      let i: Uint32 = 0u;
      while i < pa.GetSize() {
        let item: ref<JsonVariant> = pa.GetItem(i);
        i += 1u;
        if IsDefined(item) && item.IsObject() {
          let po: ref<JsonObject> = item as JsonObject;
          let p: ref<Phase> = new Phase();
          p.from = po.HasKey("from") ? Cast<Int32>(HomeRegistry.NumOf(po.GetKey("from"))) : 0;
          p.to = po.HasKey("to") ? Cast<Int32>(HomeRegistry.NumOf(po.GetKey("to"))) : 0;
          let wv: ref<JsonVariant> = po.GetKey("weights");
          if IsDefined(wv) && wv.IsObject() {
            let wo: ref<JsonObject> = wv as JsonObject;
            let keys: array<String> = wo.GetKeys();
            let k: String;
            for k in keys {
              ArrayPush(p.activities, k);
              ArrayPush(p.weights, HomeRegistry.NumOf(wo.GetKey(k)));
            };
          };
          ArrayPush(r.phases, p);
        };
      };
    };
    if ArraySize(r.phases) == 0 {
      HomebodyLog.Warn("rules." + name + ".json: no phases; built-in all-day phase in use");
      let d: ref<Rules> = Rules.Default();
      r.phases = d.phases;
    };
    let dv: ref<JsonVariant> = o.GetKey("duration");
    if IsDefined(dv) && dv.IsObject() {
      let dobj: ref<JsonObject> = dv as JsonObject;
      let dkeys: array<String> = dobj.GetKeys();
      let dk: String;
      for dk in dkeys {
        let range: ref<JsonVariant> = dobj.GetKey(dk);
        if IsDefined(range) && range.IsArray() {
          let ra: ref<JsonArray> = range as JsonArray;
          if ra.GetSize() == 2u {
            let mn: Float = HomeRegistry.NumOf(ra.GetItem(0u));
            let mx: Float = HomeRegistry.NumOf(ra.GetItem(1u));
            if mx < mn { mx = mn; };
            if Equals(dk, "default") {
              r.defaultMin = mn;
              r.defaultMax = mx;
            } else {
              ArrayPush(r.durationActivities, dk);
              ArrayPush(r.durationMin, mn);
              ArrayPush(r.durationMax, mx);
            };
          };
        };
      };
    };
    if o.HasKey("cooldownSeconds") { r.cooldownSeconds = HomeRegistry.NumOf(o.GetKey("cooldownSeconds")); };
    if o.HasKey("wanderRadius") { r.wanderRadius = HomeRegistry.NumOf(o.GetKey("wanderRadius")); };
    return r;
  }
}
