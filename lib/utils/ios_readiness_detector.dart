// File: lib/utils/ios_readiness_detector.dart
import 'package:Zura/utils/debug_loader.dart' show DebugLogger;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class IOSReadinessDetector {
  static bool _isReady = false;
  static bool get isReady => _isReady;
  
  /// Actually test if iOS file system is ready by trying to access SharedPreferences
  static Future<bool> waitForIOSReadiness() async {
    if (!kIsWeb && Platform.isIOS) {
      if (kDebugMode) {
        DebugLogger.log("🔍 Testing iOS file system readiness...");
      }
      
      // Test up to 30 times (30 seconds max) with exponential backoff
      for (int attempt = 1; attempt <= 30; attempt++) {
        try {
          // Try to actually access the file system
          await SharedPreferences.getInstance();
          
          // If we can get preferences without error, iOS is ready
          _isReady = true;
          if (kDebugMode) {
            DebugLogger.log("✅ iOS file system ready after ${attempt * 100}ms");
          }
          return true;
        } catch (e) {
          if (kDebugMode) {
            DebugLogger.log("⏳ iOS not ready (attempt $attempt): ${e.toString().substring(0, 50)}...");
          }
          
          // Exponential backoff: 100ms, 200ms, 300ms, etc.
          await Future.delayed(Duration(milliseconds: 100 * attempt));
        }
      }
      
      // If we get here, iOS never became ready - something is wrong
      if (kDebugMode) {
        DebugLogger.log("❌ iOS file system never became ready after 30 attempts");
      }
      return false;
    } else {
      // Android is always ready
      _isReady = true;
      return true;
    }
  }
  
  /// Quick test without waiting
  static Future<bool> testReadiness() async {
    if (!kIsWeb && Platform.isIOS) {
      try {
        await SharedPreferences.getInstance();
        _isReady = true;
        return true;
      } catch (e) {
        _isReady = false;
        return false;
      }
    } else {
      _isReady = true;
      return true;
    }
  }
}