module Homebody

// Turns furniture the game placed no AI spot on into spots. Discovery reads
// every entity node and mesh node inside the boundary and names its entity
// template or mesh (base\...\couch_a.ent, ...\sofa_b.mesh); a rule matches
// a word in that file name and gives the activity and the vanilla workspots
// to play there. A player apartment's couch and bed are static meshes. The
// spot sits at the node's own position and facing and uses the manual
// path, so entSpawner
// is needed, and a home's exclude and retag entries apply to it by its
// furniture-<hash> key. Player apartments are where this matters: their
// couches and beds carry no NPC workspot at all (2026-09-06 census).
//
// The workspot paths are vanilla resources listed by entSpawner's
// paths_workspot.txt; each rule picks one by the node hash so the same
// couch always plays the same animation.
public class FurnitureRule extends IScriptable {
  public let match: String;
  public let activity: String;
  public let workspots: array<String>;
  // Where the seat is relative to the mesh pivot: forward along the
  // node's facing, and up from the floor the NPC walked in on. A chair's
  // pivot is its seat; a sofa's is its centre, 0.6 m down and half a
  // cushion back (2026-09-13 run).
  public let forward: Float;
  public let up: Float;
}

public class FurnitureRules extends IScriptable {
  private let m_rules: array<ref<FurnitureRule>>;
  private let m_skip: array<String>;

  public func InstallDefaults() -> Void {
    ArrayClear(this.m_rules);
    ArrayClear(this.m_skip);
    // Words that name something near or on furniture rather than the
    // furniture itself: a bedside lamp, a couch pillow, a proxy mesh.
    this.AddSkip("lamp");
    this.AddSkip("pillow");
    this.AddSkip("duvet");
    this.AddSkip("blanket");
    this.AddSkip("sheet");
    this.AddSkip("curtain");
    this.AddSkip("rug");
    this.AddSkip("carpet");
    this.AddSkip("frame");
    this.AddSkip("proxy");
    this.AddSkip("decal");
    this.AddSkip("light");
    this.AddSkip("fx");
    this.AddSkip("_lod");
    this.AddSkip("table");
    this.AddSkip("shelf");
    this.AddSkip("cabinet");
    this.AddSkip("wardrobe");
    this.AddSkip("closet");
    this.AddSkip("wheelchair");
    this.AddSkip("cushion");
    this.AddSkip("cover");
    this.AddSkip("leg");
    this.AddSkip("_bedroom");
    this.AddSkip("_bedside");
    this.AddRule("couch", "sit", "base\\workspots\\common\\couch\\generic__sit_couch__sit_around__01.workspot");
    this.AddRule("couch", "sit", "base\\workspots\\common\\couch\\generic__sit_couch__sit_around__02.workspot");
    this.AddRule("couch", "sit", "base\\workspots\\common\\couch\\generic__sit_couch__sit_around__03.workspot");
    this.AddRule("couch", "sit", "base\\workspots\\common\\couch\\generic__sit_couch_tablet__read__01.workspot");
    this.AddRule("couch", "sit", "base\\workspots\\common\\couch\\generic__sit_couch_tv__watch__01.workspot");
    this.AddRule("sofa", "sit", "base\\workspots\\common\\couch\\generic__sit_couch__sit_around__01.workspot");
    this.AddRule("sofa", "sit", "base\\workspots\\common\\couch\\generic__sit_couch_tv__watch__01.workspot");
    this.AddRule("armchair", "sit", "base\\workspots\\common\\chair\\generic__sit_chair_lean_back__sit_around__03.workspot");
    this.AddRule("chair", "sit", "base\\workspots\\common\\chair\\generic__sit_chair__sit_around__01.workspot");
    this.AddRule("chair", "sit", "base\\workspots\\common\\chair\\generic__sit_chair__sit_around__02.workspot");
    this.AddRule("chair", "sit", "base\\workspots\\common\\chair\\generic__sit_chair_tablet__read__01.workspot");
    this.AddRule("stool", "sit", "base\\workspots\\common\\chair\\generic__sit_chair__sit_around__04.workspot");
    this.AddRule("bed", "sleep", "base\\workspots\\common\\bed\\generic__lie_double_bed__sleep__01.workspot");
    this.AddRule("bed", "sleep", "base\\workspots\\common\\bed\\generic__lie_double_bed__sleep__02.workspot");
    this.AddRule("bed", "sleep", "base\\workspots\\common\\bed\\generic__lie_double_bed__sleep__03.workspot");
    this.AddRule("bed", "sleep", "base\\workspots\\common\\bed\\generic__lie_double_bed__lie_around__01.workspot");
    this.AddRule("mattress", "sleep", "base\\workspots\\common\\bed\\generic__lie_bed_lean_left__lie_around__01.workspot");
    this.AddRule("sink", "wash", "base\\workspots\\common\\high_sink\\generic__stand_high_sink___wash_hands__01.workspot");
    this.SetOffset("couch", "sit", 0.45, 0.0);
    this.SetOffset("sofa", "sit", 0.45, 0.0);
  }

  // Sets the seat offset of the rule for match and activity, if any.
  public func SetOffset(match: String, activity: String, forward: Float, up: Float) -> Bool {
    let m: String = StrLower(match);
    let r: ref<FurnitureRule>;
    for r in this.m_rules {
      if Equals(r.match, m) && Equals(r.activity, activity) {
        r.forward = forward;
        r.up = up;
        return true;
      };
    };
    return false;
  }

  public func AddSkip(word: String) -> Void {
    ArrayPush(this.m_skip, StrLower(word));
  }

  // Adds a workspot to the rule for match and activity, creating the rule
  // if there is none. Rules match in the order they were added.
  public func AddRule(match: String, activity: String, workspot: String) -> Void {
    let m: String = StrLower(match);
    let r: ref<FurnitureRule>;
    for r in this.m_rules {
      if Equals(r.match, m) && Equals(r.activity, activity) {
        ArrayPush(r.workspots, workspot);
        return;
      };
    };
    let n: ref<FurnitureRule> = new FurnitureRule();
    n.match = m;
    n.activity = activity;
    ArrayPush(n.workspots, workspot);
    ArrayPush(this.m_rules, n);
  }

  // The rule for an entity template path, or null. Only the file name is
  // matched, so a folder called bedroom does not make every prop a bed.
  public func Match(templatePath: String) -> ref<FurnitureRule> {
    let name: String = StrLower(FurnitureRules.FileName(templatePath));
    let w: String;
    for w in this.m_skip {
      if StrContains(name, w) { return null; };
    };
    let r: ref<FurnitureRule>;
    for r in this.m_rules {
      if StrContains(name, r.match) { return r; };
    };
    return null;
  }

  // The rule's place in the list; a lower rank wins when two pieces of
  // furniture share a position.
  public func Rank(rule: ref<FurnitureRule>) -> Int32 {
    let i: Int32 = 0;
    while i < ArraySize(this.m_rules) {
      if Equals(this.m_rules[i], rule) { return i; };
      i += 1;
    };
    return 1000;
  }

  // One of the rule's workspots, chosen by a hash so it is stable per
  // piece of furniture.
  public static func Pick(rule: ref<FurnitureRule>, hash: Uint64) -> String {
    let n: Int32 = ArraySize(rule.workspots);
    if n == 0 { return ""; };
    let i: Int32 = Cast<Int32>(hash % Cast<Uint64>(n));
    if i < 0 { i = -i; };
    return rule.workspots[i];
  }

  public static func FileName(path: String) -> String {
    let parts: array<String> = StrSplit(path, "\\");
    let n: Int32 = ArraySize(parts);
    return n > 0 ? parts[n - 1] : path;
  }

  public func Describe() -> String {
    let out: String = "";
    let r: ref<FurnitureRule>;
    for r in this.m_rules {
      out += (Equals(out, "") ? "" : ", ") + r.match + " -> " + r.activity + " (" + IntToString(ArraySize(r.workspots)) + ")";
      if r.forward != 0.0 || r.up != 0.0 {
        out += " offset " + FloatToStringPrec(r.forward, 2) + "/" + FloatToStringPrec(r.up, 2);
      };
    };
    return out;
  }

  public static func Get() -> ref<FurnitureRules> {
    let svc: ref<HomebodyStorageService> = HomebodyStorageService.Get();
    return IsDefined(svc) ? svc.GetFurniture() : null;
  }
}
