module Homebody

// Picks what an NPC does next: a weighted draw over the usable spots plus
// the phase's wander and idle weights. Pure: the caller draws the two 0..1
// rolls, so the tests are deterministic. Duration is mn + (mx - mn) * roll2.
public class Scheduler {
  // from inclusive, to exclusive; to below from wraps midnight; equal is all day.
  public static func HourInRange(from: Int32, to: Int32, hour: Int32) -> Bool {
    if from == to { return true; };
    if from < to { return hour >= from && hour < to; };
    return hour >= from || hour < to;
  }

  public static func PhaseFor(rules: ref<Rules>, hour: Int32) -> ref<Phase> {
    let p: ref<Phase>;
    for p in rules.phases {
      if Scheduler.HourInRange(p.from, p.to, hour) { return p; };
    };
    return null;
  }

  // An hour outside every phase weighs everything 1.
  private static func Weight(phase: ref<Phase>, activity: String) -> Float {
    if !IsDefined(phase) { return 1.0; };
    return phase.WeightOf(activity);
  }

  public static func Decide(spots: array<ref<Spot>>, hour: Int32, rules: ref<Rules>, now: Float,
      center: Vector4, manualAllowed: Bool, roll: Float, roll2: Float) -> ref<Decision> {
    let phase: ref<Phase> = Scheduler.PhaseFor(rules, hour);
    let weights: array<Float>;
    let total: Float = 0.0;
    let i: Int32 = 0;
    while i < ArraySize(spots) {
      let s: ref<Spot> = spots[i];
      let w: Float = Scheduler.Weight(phase, s.activity);
      // A native-failed spot stays usable when the manual path exists; an
      // unreachable spot never is.
      if s.unreachable || (s.nativeFailed && !manualAllowed) { w = 0.0; };
      if Equals(s.source, SpotSource.Manual) && !manualAllowed { w = 0.0; };
      if s.lastUsedAt > 0.0 && now - s.lastUsedAt < rules.cooldownSeconds { w = 0.0; };
      if w < 0.0 { w = 0.0; };
      ArrayPush(weights, w);
      total += w;
      i += 1;
    };
    let wanderW: Float = IsDefined(phase) ? phase.WeightOf("wander") : 0.0;
    let idleW: Float = IsDefined(phase) ? phase.WeightOf("idle") : 0.0;
    total += wanderW + idleW;
    let d: ref<Decision> = new Decision();
    if total <= 0.0 {
      d.kind = DecisionKind.Idle;
      d.duration = 10.0;
      d.why = "nothing weighs";
      return d;
    };
    let pick: Float = roll * total;
    let acc: Float = 0.0;
    i = 0;
    while i < ArraySize(spots) {
      acc += weights[i];
      if weights[i] > 0.0 && pick < acc {
        d.kind = DecisionKind.UseSpot;
        d.spot = spots[i];
        d.target = spots[i].position;
        let mn: Float;
        let mx: Float;
        rules.DurationRange(spots[i].activity, mn, mx);
        d.duration = mn + (mx - mn) * roll2;
        d.why = spots[i].activity + " weight " + FloatToStringPrec(weights[i], 1);
        return d;
      };
      i += 1;
    };
    acc += wanderW;
    if wanderW > 0.0 && pick < acc {
      d.kind = DecisionKind.Wander;
      let angle: Float = roll * 6.2831853;
      let dist: Float = MinF(rules.wanderRadius, rules.wanderRadius * roll2 * 2.0);
      d.target = new Vector4(center.X + CosF(angle) * dist, center.Y + SinF(angle) * dist, center.Z, 1.0);
      d.duration = 5.0;
      d.why = "wander";
      return d;
    };
    d.kind = DecisionKind.Idle;
    let imn: Float;
    let imx: Float;
    rules.DurationRange("idle", imn, imx);
    d.duration = imn + (imx - imn) * roll2;
    d.why = "idle";
    return d;
  }
}
