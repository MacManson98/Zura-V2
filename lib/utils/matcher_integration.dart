// lib/utils/matcher_integration.dart
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../utils/unified_session_manager.dart';
import '../screens/matcher_screen.dart';
import '../utils/debug_loader.dart';

/// Integration layer between MatchTabScreen and MatcherScreenV2
/// Handles context translation and navigation logic
class MatcherIntegration {
  
  /// Navigate to matcher screen with appropriate context
  static Future<void> navigateToMatcher({
    required BuildContext context,
    required UserProfile userProfile,
    String? contextMessage,
    UserProfile? targetFriend,
    List<UserProfile>? targetGroup,
    String? sessionId,
  }) async {
    
    final matchingContext = _determineContext(
      userProfile: userProfile,
      targetFriend: targetFriend,
      targetGroup: targetGroup,
      sessionId: sessionId,
    );
    
    DebugLogger.log("🎯 Navigating to matcher with context: ${matchingContext.name}");
    
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => MatcherScreen(
          userProfile: userProfile,
          context: matchingContext,
          sessionId: sessionId,
          targetFriend: targetFriend,
          targetGroup: targetGroup,
          contextMessage: contextMessage,
        ),
      ),
    );
    
    // Handle result if needed
    if (result == true) {
      DebugLogger.log("✅ Matcher session completed successfully");
    }
  }
  
  /// Determine the appropriate matching context
  static MatchingContext _determineContext({
    required UserProfile userProfile,
    UserProfile? targetFriend,
    List<UserProfile>? targetGroup,
    String? sessionId,
  }) {
    // Check for active session first
    final activeSession = UnifiedSessionManager.getActiveSessionForDisplay();
    if (activeSession != null) {
      return MatchingContext.continueSession;
    }
    
    // Check for session join
    if (sessionId != null) {
      return MatchingContext.joinSession;
    }
    
    // Check for friend invite
    if (targetFriend != null) {
      return MatchingContext.friendInvite;
    }
    
    // Check for group invite
    if (targetGroup != null && targetGroup.isNotEmpty) {
      return MatchingContext.groupInvite;
    }
    
    // Default to solo
    return MatchingContext.solo;
  }
  
  /// Quick navigation for solo matching
  static Future<void> startSoloMatching({
    required BuildContext context,
    required UserProfile userProfile,
  }) async {
    await navigateToMatcher(
      context: context,
      userProfile: userProfile,
      contextMessage: 'Ready to discover movies!',
    );
  }
  
  /// Quick navigation for friend matching
  static Future<void> startFriendMatching({
    required BuildContext context,
    required UserProfile userProfile,
    required UserProfile friend,
  }) async {
    await navigateToMatcher(
      context: context,
      userProfile: userProfile,
      targetFriend: friend,
      contextMessage: 'Starting session with ${friend.name}',
    );
  }
  
  /// Quick navigation for group matching
  static Future<void> startGroupMatching({
    required BuildContext context,
    required UserProfile userProfile,
    required List<UserProfile> group,
  }) async {
    await navigateToMatcher(
      context: context,
      userProfile: userProfile,
      targetGroup: group,
      contextMessage: 'Starting group session',
    );
  }
  
  /// Continue active session
  static Future<void> continueActiveSession({
    required BuildContext context,
    required UserProfile userProfile,
  }) async {
    final activeSession = UnifiedSessionManager.getActiveSessionForDisplay();
    if (activeSession == null) {
      DebugLogger.log("❌ No active session to continue");
      return;
    }
    
    await navigateToMatcher(
      context: context,
      userProfile: userProfile,
      contextMessage: 'Continuing your ${activeSession.type.name} session',
    );
  }
  
  /// Join session by ID
  static Future<void> joinSession({
    required BuildContext context,
    required UserProfile userProfile,
    required String sessionId,
  }) async {
    await navigateToMatcher(
      context: context,
      userProfile: userProfile,
      sessionId: sessionId,
      contextMessage: 'Joining session...',
    );
  }
}