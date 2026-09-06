module Homebody

public enum SpotSource {
  Discovered = 0,
  Manual = 1
}

// One usable place in a home: a baked world AI spot found by discovery, or
// an authored extra spot from the home file.
public class Spot extends IScriptable {
  public let nodeRef: NodeRef;
  public let nodeKey: String;
  public let position: Vector4;
  public let yaw: Float;
  public let workspotPath: String;
  public let markings: array<CName>;
  public let activity: String;
  public let source: SpotSource;
  public let isInfinite: Bool;
  public let lastUsedAt: Float;
  public let unreachable: Bool;
  public let nativeFailed: Bool;
}

// A home boundary: a sphere (radius > 0) or an axis-aligned box.
public class Bounds extends IScriptable {
  public let center: Vector4;
  public let radius: Float;
  public let min: Vector4;
  public let max: Vector4;
  public let isBox: Bool;

  public static func Sphere(c: Vector4, r: Float) -> ref<Bounds> {
    let b: ref<Bounds> = new Bounds();
    b.center = c;
    b.radius = r;
    b.isBox = false;
    return b;
  }

  public static func BoxOf(mn: Vector4, mx: Vector4) -> ref<Bounds> {
    let b: ref<Bounds> = new Bounds();
    b.min = mn;
    b.max = mx;
    b.isBox = true;
    b.center = new Vector4((mn.X + mx.X) * 0.5, (mn.Y + mx.Y) * 0.5, (mn.Z + mx.Z) * 0.5, 1.0);
    b.radius = Vector4.Distance(b.center, mx);
    return b;
  }

  public func Center() -> Vector4 {
    return this.center;
  }

  public func Contains(p: Vector4) -> Bool {
    if this.isBox {
      return p.X >= this.min.X && p.X <= this.max.X
        && p.Y >= this.min.Y && p.Y <= this.max.Y
        && p.Z >= this.min.Z && p.Z <= this.max.Z;
    };
    return Vector4.Distance(p, this.center) <= this.radius;
  }

  // True when the sector box can hold any point of this boundary: clamp
  // the center into the box and test the clamped point.
  public func IntersectsBox(b: Box) -> Bool {
    let cx: Float = ClampF(this.center.X, b.Min.X, b.Max.X);
    let cy: Float = ClampF(this.center.Y, b.Min.Y, b.Max.Y);
    let cz: Float = ClampF(this.center.Z, b.Min.Z, b.Max.Z);
    let nearest: Vector4 = new Vector4(cx, cy, cz, 1.0);
    return Vector4.Distance(nearest, this.center) <= this.radius;
  }
}

public enum DecisionKind {
  Idle = 0,
  UseSpot = 1,
  Wander = 2
}

public class Decision extends IScriptable {
  public let kind: DecisionKind;
  public let spot: ref<Spot>;
  public let target: Vector4;
  public let duration: Float;
  public let why: String;
}

public enum DriverOutcome {
  Running = 0,
  Done = 1,
  Failed = 2,
  Interrupted = 3
}

public class DriverResult extends IScriptable {
  public let outcome: DriverOutcome;
  public let reason: String;
}
