// Create this file: lib/utils/debug_logger.dart

class DebugLogger {
  // Set this to false to disable ALL debug logs instantly
  static const bool _debugEnabled = true; // Change to false for production
  
  static void log(String message, [String? tag]) {
    if (_debugEnabled) {
      final prefix = tag != null ? "[$tag] " : "";
      print("$prefix$message");
    }
  }
  
  static void logError(String message, [Object? error]) {
    if (_debugEnabled) {
      print("❌ ERROR: $message");
      if (error != null) print("   Details: $error");
    }
  }
  
  static void logSuccess(String message) {
    if (_debugEnabled) {
      print("✅ SUCCESS: $message");
    }
  }
  
  static void logWarning(String message) {
    if (_debugEnabled) {
      print("⚠️ WARNING: $message");
    }
  }
  
  static void logInfo(String message) {
    if (_debugEnabled) {
      print("ℹ️ INFO: $message");
    }
  }
}