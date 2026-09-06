module Homebody

// Names an activity for a spot from its markings and workspot path. Rules
// are ordered substring matches on lowercased text: specific words come
// before generic ones, so watch_tv_sit is tv and toilet_sit is toilet. Sit
// paths carry their recline angle as lean0 or lean180 and a bench can be
// sit_bench_lean_left, so sit comes before the lean rules and those are
// anchored on wall_lean and leaning. Markings are checked before the path;
// an unmatched spot is idle. Consumers add rules through AddRule and they
// live on the storage service, so they survive a save reload.
public class ActivityClassifier extends IScriptable {
  private let m_match: array<String>;
  private let m_activity: array<String>;

  public func InstallDefaults() -> Void {
    ArrayClear(this.m_match);
    ArrayClear(this.m_activity);
    this.AddRule("toilet", "toilet");
    this.AddRule("shower", "shower");
    this.AddRule("sleep", "sleep");
    this.AddRule("bed", "sleep");
    this.AddRule("tv", "tv");
    this.AddRule("radio", "radio");
    this.AddRule("dance", "dance");
    this.AddRule("phone", "phone");
    this.AddRule("smok", "smoke");
    this.AddRule("cigarette", "smoke");
    this.AddRule("cook", "cook");
    this.AddRule("stove", "cook");
    this.AddRule("kitchen", "cook");
    this.AddRule("drink", "drink");
    this.AddRule("bar_", "drink");
    this.AddRule("sit", "sit");
    this.AddRule("couch", "sit");
    this.AddRule("chair", "sit");
    this.AddRule("bench", "sit");
    this.AddRule("wall_lean", "lean");
    this.AddRule("leaning", "lean");
    this.AddRule("stand", "stand");
  }

  public func AddRule(match: String, activity: String) -> Void {
    ArrayPush(this.m_match, StrLower(match));
    ArrayPush(this.m_activity, activity);
  }

  public func Classify(markings: array<CName>, path: String) -> String {
    let m: CName;
    for m in markings {
      let text: String = StrLower(NameToString(m));
      let hit: String = this.Lookup(text);
      if !Equals(hit, "") { return hit; };
    };
    let hit2: String = this.Lookup(StrLower(path));
    if !Equals(hit2, "") { return hit2; };
    return "idle";
  }

  private func Lookup(text: String) -> String {
    let i: Int32 = 0;
    while i < ArraySize(this.m_match) {
      if StrContains(text, this.m_match[i]) { return this.m_activity[i]; };
      i += 1;
    };
    return "";
  }

  public static func Get() -> ref<ActivityClassifier> {
    let svc: ref<HomebodyStorageService> = HomebodyStorageService.Get();
    return IsDefined(svc) ? svc.GetClassifier() : null;
  }
}
