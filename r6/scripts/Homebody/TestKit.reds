module Homebody

// A minimal assertion collector. Each assertion records one PASS or FAIL
// line; Report() prints them with a summary line the acceptance steps grep.
public class HomebodyTest extends IScriptable {
  private let m_passed: Int32;
  private let m_failed: Int32;
  private let m_lines: array<String>;

  public func AssertEqS(actual: String, expected: String, label: String) -> Void {
    if Equals(actual, expected) {
      this.Pass(label);
    } else {
      this.Fail(label + " | expected=\"" + expected + "\" actual=\"" + actual + "\"");
    };
  }

  public func AssertEqI(actual: Int32, expected: Int32, label: String) -> Void {
    if actual == expected {
      this.Pass(label);
    } else {
      this.Fail(label + " | expected=" + IntToString(expected) + " actual=" + IntToString(actual));
    };
  }

  public func AssertEqF(actual: Float, expected: Float, tolerance: Float, label: String) -> Void {
    if AbsF(actual - expected) <= tolerance {
      this.Pass(label);
    } else {
      this.Fail(label + " | expected=" + FloatToString(expected) + " actual=" + FloatToString(actual));
    };
  }

  public func AssertTrue(actual: Bool, label: String) -> Void {
    if actual {
      this.Pass(label);
    } else {
      this.Fail(label + " | expected true");
    };
  }

  private func Pass(label: String) -> Void {
    this.m_passed += 1;
    ArrayPush(this.m_lines, "PASS " + label);
  }

  private func Fail(label: String) -> Void {
    this.m_failed += 1;
    ArrayPush(this.m_lines, "FAIL " + label);
  }

  public func Report() -> String {
    let out: String = "";
    let line: String;
    for line in this.m_lines {
      out += line + "\n";
    };
    out += "---\npassed=" + IntToString(this.m_passed) + " failed=" + IntToString(this.m_failed) + "\n";
    return out;
  }

  public func FailedCount() -> Int32 {
    return this.m_failed;
  }
}
