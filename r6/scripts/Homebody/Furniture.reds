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
    this.AddRule("mattress", "sleep", "base\\workspots\\common\\bed\\generic__lie_bed_lean_left__lie_around__01.workspot");
    this.AddRule("bed", "sleep", "base\\workspots\\common\\bed\\generic__lie_double_bed__sleep__01.workspot");
    this.AddRule("bed", "sleep", "base\\workspots\\common\\bed\\generic__lie_double_bed__sleep__02.workspot");
    this.AddRule("bed", "sleep", "base\\workspots\\common\\bed\\generic__lie_double_bed__sleep__03.workspot");
    this.AddRule("bed", "sleep", "base\\workspots\\common\\bed\\generic__lie_double_bed__lie_around__01.workspot");
    this.AddRule("sink", "wash", "base\\workspots\\common\\high_sink\\generic__stand_high_sink___wash_hands__01.workspot");
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
    };
    return out;
  }

  public static func Get() -> ref<FurnitureRules> {
    let svc: ref<HomebodyStorageService> = HomebodyStorageService.Get();
    return IsDefined(svc) ? svc.GetFurniture() : null;
  }
}
