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

public func HomebodyRunSelfTests() -> String {
  let t: ref<HomebodyTest> = new HomebodyTest();
  t.AssertEqI(1, 1, "harness/smoke");
  HomebodyClassifierTests(t);
  HomebodyRegistryTests(t);
  return t.Report();
}
