module Homebody
import RedFileSystem.*

// FTLog is the only logging family that resolves from the base script
// bundle without extra declarations. CET's gamelog sink flushes late, so
// HomebodyTrace exists as the crash breadcrumb: IsFile on a missing path
// makes RedFileSystem's own logger write a millisecond-stamped line to
// red4ext/logs/redfilesystem-*.log immediately.
public class HomebodyLog {
  public static func Info(msg: String) -> Void {
    FTLog("[Homebody] " + msg);
  }

  public static func Warn(msg: String) -> Void {
    FTLogWarning("[Homebody] " + msg);
  }

  public static func Error(msg: String) -> Void {
    FTLogError("[Homebody] " + msg);
  }
}

public func HomebodyTrace(storage: ref<FileSystemStorage>, step: String) -> Void {
  if IsDefined(storage) {
    storage.IsFile("trace-" + step);
  };
}
