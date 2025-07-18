// lib/utils/matcher_integration.dart
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../models/friend_group.dart';
import '../utils/completed_session.dart';
import '../utils/unified_session_manager.dart';
import '../screens/matcher_screen_v2.dart';
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
        builder: (context) => MatcherScreenV2(
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

// lib/widgets/enhanced_context_cta.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/user_profile.dart';
import '../utils/matcher_integration.dart';
import '../widgets/context_aware_cta.dart';

/// Enhanced CTA widgets specifically for matcher integration
class MatcherCTAWidget extends StatelessWidget {
  final UserProfile userProfile;
  final String? contextMessage;
  
  const MatcherCTAWidget({
    super.key,
    required this.userProfile,
    this.contextMessage,
  });

  @override
  Widget build(BuildContext context) {
    return ContextAwareCTA(
      title: 'Start Discovering',
      subtitle: contextMessage ?? 'Find your next favorite movie',
      icon: Icons.movie,
      onPressed: () => MatcherIntegration.startSoloMatching(
        context: context,
        userProfile: userProfile,
      ),
      isPrimary: true,
    );
  }
}

class FriendMatchCTAWidget extends StatelessWidget {
  final UserProfile userProfile;
  final UserProfile friend;
  final bool isOnline;
  
  const FriendMatchCTAWidget({
    super.key,
    required this.userProfile,
    required this.friend,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    return ContextAwareCTA(
      title: 'Match with ${friend.name}',
      subtitle: isOnline ? 'Online now' : 'Send invitation',
      icon: Icons.people,
      onPressed: () => MatcherIntegration.startFriendMatching(
        context: context,
        userProfile: userProfile,
        friend: friend,
      ),
      isPrimary: isOnline,
      badge: isOnline ? 'ONLINE' : null,
    );
  }
}

class GroupMatchCTAWidget extends StatelessWidget {
  final UserProfile userProfile;
  final List<UserProfile> group;
  final String? groupName;
  
  const GroupMatchCTAWidget({
    super.key,
    required this.userProfile,
    required this.group,
    this.groupName,
  });

  @override
  Widget build(BuildContext context) {
    return ContextAwareCTA(
      title: 'Start Group Session',
      subtitle: groupName ?? '${group.length} members',
      icon: Icons.group,
      onPressed: () => MatcherIntegration.startGroupMatching(
        context: context,
        userProfile: userProfile,
        group: group,
      ),
    );
  }
}

class ContinueSessionCTAWidget extends StatelessWidget {
  final UserProfile userProfile;
  
  const ContinueSessionCTAWidget({
    super.key,
    required this.userProfile,
  });

  @override
  Widget build(BuildContext context) {
    return ContextAwareCTA(
      title: 'Continue Session',
      subtitle: 'Pick up where you left off',
      icon: Icons.play_arrow,
      onPressed: () => MatcherIntegration.continueActiveSession(
        context: context,
        userProfile: userProfile,
      ),
      isPrimary: true,
      badge: 'ACTIVE',
    );
  }
}