module Homebody
import RedData.Json.*

// Self-tests, run once at attach when config.runSelfTest is true. They
// use no game state, so a FAIL line is a defect in the pure code.

public func HomebodyClassifierTests(t: ref<HomebodyTest>) -> Void {
  let c: ref<ActivityClassifier> = new ActivityClassifier();
  c.InstallDefaults();
  let none: array<CName>;
  t.AssertEqS(c.Classify(none, "base\\animations\\workspots\\sit_couch_lean0.workspot"), "sit", "cls/sit-couch-path");
  t.AssertEqS(c.Classify(none, "base\\x\\stand_smoke_cigarette.workspot"), "smoke", "cls/smoke-path");
  t.AssertEqS(c.Classify(none, "base\\x\\stand_wall_lean180.workspot"), "lean", "cls/lean-before-stand");
  t.AssertEqS(c.Classify(none, "base\\x\\cooking_stove.workspot"), "cook", "cls/cook-path");
  t.AssertEqS(c.Classify(none, "base\\x\\watch_tv_sit.workspot"), "tv", "cls/tv-before-sit");
  t.AssertEqS(c.Classify(none, "base\\x\\toilet_sit.workspot"), "toilet", "cls/toilet-before-sit");
  t.AssertEqS(c.Classify(none, "base\\x\\shower.workspot"), "shower", "cls/shower");
  t.AssertEqS(c.Classify(none, "base\\x\\bed_sleep.workspot"), "sleep", "cls/sleep");
  t.AssertEqS(c.Classify(none, "base\\x\\dance_club.workspot"), "dance", "cls/dance");
  t.AssertEqS(c.Classify(none, "base\\x\\phone_call.workspot"), "phone", "cls/phone");
  t.AssertEqS(c.Classify(none, "base\\x\\drink_bar.workspot"), "drink", "cls/drink");
  t.AssertEqS(c.Classify(none, "base\\x\\mystery.workspot"), "idle", "cls/unknown-is-idle");
  // Paths seen in the Downtown apartment corridor on 2026-09-06.
  t.AssertEqS(c.Classify(none, "base\\workspots\\common\\chair\\generic__sit_chair_lean_front_cigarette__smoke__01.workspot"), "smoke", "cls/real-smoke");
  t.AssertEqS(c.Classify(none, "base\\workspots\\common\\chair\\generic__sit_chair_bottle_small__drink__01.workspot"), "drink", "cls/real-drink");
  t.AssertEqS(c.Classify(none, "base\\workspots\\common\\bench\\generic__sit_bench_lean_left__caress__01.workspot"), "sit", "cls/real-bench-lean-is-sit");
  t.AssertEqS(c.Classify(none, "base\\workspots\\common\\chair\\generic__sit_chair_tablet__read__01.workspot"), "sit", "cls/real-read-is-sit");
  let corridor: array<CName>;
  ArrayPush(corridor, n"dlc6_apart_cct_dtn_ws_corridor_night");
  t.AssertEqS(c.Classify(corridor, "base\\workspots\\archetype\\corpo\\corpo__sit_chair__sit_around_devastated__01.workspot"), "sit", "cls/real-marking-no-rule-word");
  let marks: array<CName>;
  ArrayPush(marks, n"Sit");
  t.AssertEqS(c.Classify(marks, "base\\x\\mystery.workspot"), "sit", "cls/marking-wins");
  c.AddRule("mystery", "radio");
  t.AssertEqS(c.Classify(none, "base\\x\\mystery.workspot"), "radio", "cls/added-rule");
}

public func HomebodyRegistryTests(t: ref<HomebodyTest>) -> Void {
  // Bare integers on purpose: radius 5 and from 23 prove the integer branch
  // of NumOf, and a wrong branch shows as a failed assertion, not a zero.
  let home: ref<Home> = HomeRegistry.ParseHome(ParseJson(
    "{\"id\":\"t\",\"bounds\":{\"center\":[1,2,3],\"radius\":5},\"spawn\":{\"record\":\"Character.NurseFemale\"},\"exclude\":[\"42\"],\"retag\":{\"7\":\"tv\"},\"extraSpots\":[{\"position\":[1,1,1],\"yaw\":90,\"workspot\":\"x.workspot\",\"activity\":\"sit\"}],\"rules\":\"night\"}"), "test");
  t.AssertTrue(IsDefined(home), "reg/home-parses");
  if IsDefined(home) {
    t.AssertEqS(home.id, "t", "reg/id");
    t.AssertEqF(home.bounds.radius, 5.0, 0.001, "reg/radius");
    t.AssertTrue(home.bounds.Contains(new Vector4(1.0, 2.0, 7.9, 1.0)), "reg/contains-inside");
    t.AssertTrue(!home.bounds.Contains(new Vector4(1.0, 2.0, 8.1, 1.0)), "reg/contains-outside");
    t.AssertTrue(home.hasSpawn, "reg/has-spawn");
    t.AssertEqF(home.spawnPosition.Y, 2.0, 0.001, "reg/spawn-defaults-to-center");
    t.AssertEqI(ArraySize(home.exclude), 1, "reg/exclude-count");
    t.AssertEqS(home.retagValues[0], "tv", "reg/retag-value");
    t.AssertEqI(ArraySize(home.extraSpots), 1, "reg/extra-count");
    t.AssertEqS(home.extraSpots[0].activity, "sit", "reg/extra-activity");
    t.AssertEqF(home.extraSpots[0].yaw, 90.0, 0.001, "reg/extra-yaw");
    t.AssertEqS(home.rulesName, "night", "reg/rules-name");
  };
  let bad: ref<Home> = HomeRegistry.ParseHome(ParseJson("{\"id\":\"nobounds\"}"), "bad");
  t.AssertTrue(!IsDefined(bad), "reg/missing-bounds-skipped");
  let boxHome: ref<Home> = HomeRegistry.ParseHome(ParseJson(
    "{\"id\":\"b\",\"bounds\":{\"min\":[0,0,0],\"max\":[10,10,10]}}"), "box");
  t.AssertTrue(IsDefined(boxHome), "reg/box-home-parses");
  if IsDefined(boxHome) {
    t.AssertTrue(boxHome.bounds.Contains(new Vector4(5.0, 5.0, 5.0, 1.0)), "reg/box-contains");
    t.AssertTrue(!boxHome.hasSpawn, "reg/box-attach-only");
  };
  let rules: ref<Rules> = HomeRegistry.ParseRules(ParseJson(
    "{\"phases\":[{\"from\":23,\"to\":6,\"weights\":{\"sleep\":5}}],\"duration\":{\"sit\":[40,120],\"default\":[5,9]},\"cooldownSeconds\":30,\"wanderRadius\":2}"), "t");
  t.AssertTrue(IsDefined(rules), "reg/rules-parse");
  if IsDefined(rules) {
    t.AssertEqI(rules.phases[0].from, 23, "reg/phase-from");
    t.AssertEqI(rules.phases[0].to, 6, "reg/phase-to");
    t.AssertEqF(rules.phases[0].WeightOf("sleep"), 5.0, 0.001, "reg/weight");
    t.AssertEqF(rules.phases[0].WeightOf("sit"), 0.0, 0.001, "reg/weight-absent");
    let mn: Float;
    let mx: Float;
    rules.DurationRange("sit", mn, mx);
    t.AssertEqF(mx, 120.0, 0.001, "reg/duration-sit");
    rules.DurationRange("tv", mn, mx);
    t.AssertEqF(mn, 5.0, 0.001, "reg/duration-default");
    t.AssertEqF(rules.cooldownSeconds, 30.0, 0.001, "reg/cooldown");
    t.AssertEqF(rules.wanderRadius, 2.0, 0.001, "reg/wander-radius");
  };
  let box: ref<Bounds> = Bounds.BoxOf(new Vector4(0.0, 0.0, 0.0, 1.0), new Vector4(10.0, 10.0, 10.0, 1.0));
  t.AssertTrue(box.Contains(new Vector4(5.0, 5.0, 5.0, 1.0)), "bounds/box-inside");
  t.AssertTrue(!box.Contains(new Vector4(11.0, 5.0, 5.0, 1.0)), "bounds/box-outside");
  let sb: Box;
  sb.Min = new Vector4(20.0, 20.0, 0.0, 1.0);
  sb.Max = new Vector4(30.0, 30.0, 10.0, 1.0);
  let sphere: ref<Bounds> = Bounds.Sphere(new Vector4(18.0, 25.0, 5.0, 1.0), 3.0);
  t.AssertTrue(sphere.IntersectsBox(sb), "bounds/sphere-touches-box");
  let far: ref<Bounds> = Bounds.Sphere(new Vector4(0.0, 0.0, 0.0, 1.0), 3.0);
  t.AssertTrue(!far.IntersectsBox(sb), "bounds/sphere-misses-box");
}

public func HomebodySpot(key: String, activity: String, x: Float) -> ref<Spot> {
  let s: ref<Spot> = new Spot();
  s.nodeKey = key;
  s.activity = activity;
  s.position = new Vector4(x, 0.0, 0.0, 1.0);
  s.source = SpotSource.Discovered;
  s.isInfinite = true;
  return s;
}

public func HomebodySchedulerTests(t: ref<HomebodyTest>) -> Void {
  t.AssertTrue(Scheduler.HourInRange(6, 10, 6), "sch/range-start");
  t.AssertTrue(!Scheduler.HourInRange(6, 10, 10), "sch/range-end-exclusive");
  t.AssertTrue(Scheduler.HourInRange(23, 6, 2), "sch/range-wraps");
  t.AssertTrue(Scheduler.HourInRange(23, 6, 23), "sch/range-wrap-start");
  t.AssertTrue(!Scheduler.HourInRange(23, 6, 12), "sch/range-wrap-outside");
  t.AssertTrue(Scheduler.HourInRange(0, 0, 15), "sch/range-equal-all-day");

  let rules: ref<Rules> = HomeRegistry.ParseRules(ParseJson(
    "{\"phases\":[{\"from\":6,\"to\":12,\"weights\":{\"sit\":2,\"smoke\":1}},{\"from\":12,\"to\":6,\"weights\":{\"sleep\":1}}],\"duration\":{\"sit\":[10,20],\"default\":[5,5]},\"cooldownSeconds\":100,\"wanderRadius\":3}"), "t");
  let spots: array<ref<Spot>>;
  ArrayPush(spots, HomebodySpot("a", "sit", 1.0));
  ArrayPush(spots, HomebodySpot("b", "smoke", 2.0));
  ArrayPush(spots, HomebodySpot("c", "sleep", 3.0));
  let center: Vector4 = new Vector4(0.0, 0.0, 0.0, 1.0);

  // Morning: sit weighs 2, smoke 1, sleep 0. roll 0.1 lands on sit, 0.9 on smoke.
  let d1: ref<Decision> = Scheduler.Decide(spots, 8, rules, 1000.0, center, true, 0.1, 0.5);
  t.AssertTrue(Equals(d1.kind, DecisionKind.UseSpot), "sch/morning-uses-spot");
  t.AssertEqS(d1.spot.nodeKey, "a", "sch/morning-low-roll-sit");
  t.AssertEqF(d1.duration, 15.0, 0.001, "sch/duration-midpoint-of-range");
  let d2: ref<Decision> = Scheduler.Decide(spots, 8, rules, 1000.0, center, true, 0.9, 0.5);
  t.AssertEqS(d2.spot.nodeKey, "b", "sch/morning-high-roll-smoke");

  // Night: only sleep has weight.
  let d3: ref<Decision> = Scheduler.Decide(spots, 2, rules, 1000.0, center, true, 0.5, 0.5);
  t.AssertEqS(d3.spot.nodeKey, "c", "sch/night-sleep");
  t.AssertEqF(d3.duration, 5.0, 0.001, "sch/default-duration");

  // Cooldown: a just-used spot weighs zero.
  spots[0].lastUsedAt = 950.0;
  let d4: ref<Decision> = Scheduler.Decide(spots, 8, rules, 1000.0, center, true, 0.1, 0.5);
  t.AssertEqS(d4.spot.nodeKey, "b", "sch/cooldown-skips-recent");
  spots[0].lastUsedAt = 0.0;

  // Unreachable spots are skipped; native-failed ones only without the manual path.
  spots[0].unreachable = true;
  let d5: ref<Decision> = Scheduler.Decide(spots, 8, rules, 1000.0, center, true, 0.1, 0.5);
  t.AssertEqS(d5.spot.nodeKey, "b", "sch/unreachable-skipped");
  spots[0].unreachable = false;
  spots[0].nativeFailed = true;
  let d5b: ref<Decision> = Scheduler.Decide(spots, 8, rules, 1000.0, center, false, 0.1, 0.5);
  t.AssertEqS(d5b.spot.nodeKey, "b", "sch/native-failed-skipped-without-manual");
  let d5c: ref<Decision> = Scheduler.Decide(spots, 8, rules, 1000.0, center, true, 0.1, 0.5);
  t.AssertEqS(d5c.spot.nodeKey, "a", "sch/native-failed-kept-with-manual");
  spots[0].nativeFailed = false;

  // Manual spots need the manual path.
  spots[1].source = SpotSource.Manual;
  let d6: ref<Decision> = Scheduler.Decide(spots, 8, rules, 1000.0, center, false, 0.9, 0.5);
  t.AssertEqS(d6.spot.nodeKey, "a", "sch/manual-needs-manual-path");
  spots[1].source = SpotSource.Discovered;

  // Nothing weighs: wander when the phase allows it, else idle.
  let empty: array<ref<Spot>>;
  let d7: ref<Decision> = Scheduler.Decide(empty, 8, rules, 1000.0, center, true, 0.5, 0.5);
  t.AssertTrue(Equals(d7.kind, DecisionKind.Idle), "sch/no-spots-idle");
  let wr: ref<Rules> = HomeRegistry.ParseRules(ParseJson(
    "{\"phases\":[{\"from\":0,\"to\":0,\"weights\":{\"wander\":1}}],\"wanderRadius\":3}"), "w");
  let d8: ref<Decision> = Scheduler.Decide(empty, 8, wr, 1000.0, center, true, 0.5, 0.25);
  t.AssertTrue(Equals(d8.kind, DecisionKind.Wander), "sch/wander-when-weighted");
  t.AssertTrue(Vector4.Distance(d8.target, center) <= 3.001, "sch/wander-within-radius");
  let d8b: ref<Decision> = Scheduler.Decide(empty, 8, wr, 1000.0, center, true, 0.5, 0.9);
  t.AssertEqF(Vector4.Distance(d8b.target, center), 3.0, 0.01, "sch/wander-capped-at-radius");

  // Hour outside every phase: everything weighs 1.
  let gap: ref<Rules> = HomeRegistry.ParseRules(ParseJson("{\"phases\":[{\"from\":1,\"to\":2,\"weights\":{\"sit\":1}}]}"), "g");
  let d9: ref<Decision> = Scheduler.Decide(spots, 12, gap, 1000.0, center, true, 0.99, 0.5);
  t.AssertTrue(Equals(d9.kind, DecisionKind.UseSpot), "sch/gap-hour-all-weigh-one");
  t.AssertEqS(d9.spot.nodeKey, "c", "sch/gap-hour-high-roll-last");
}

public func HomebodyRunSelfTests() -> String {
  let t: ref<HomebodyTest> = new HomebodyTest();
  t.AssertEqI(1, 1, "harness/smoke");
  HomebodyClassifierTests(t);
  HomebodyRegistryTests(t);
  HomebodySchedulerTests(t);
  return t.Report();
}
