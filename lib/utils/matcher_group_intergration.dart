// File: lib/utils/matcher_group_integration.dart
// Integration helper for group matching in matcher_screen.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/session_models.dart';
import '../models/user_profile.dart';
import '../movie.dart';
import '../utils/group_matching_handler.dart';
import '../utils/debug_loader.dart';
import '../screens/multi_match_carousel_screen.dart';
import 'unified_session_manager.dart';
import 'session_manager.dart';

class MatcherGroupIntegration {
  
  /// Handle a like in group mode - check if it creates a group match
  static Future<bool> handleGroupLike({
    required BuildContext context,
    required Movie movie,
    required UserProfile currentUser,
    required SwipeSession? currentSession,
    required bool isInCollaborativeMode,
    required Function(Movie) onShowMatchCelebration,
  }) async {
    if (!isInCollaborativeMode || currentSession == null) {
      DebugLogger.log("🚫 Not in collaborative mode or no session - skipping group match check");
      return false;
    }

    try {
      DebugLogger.log("🔍 Checking for group match...");
      DebugLogger.log("   Movie: ${movie.title}");
      DebugLogger.log("   Session: ${currentSession.sessionId}");
      DebugLogger.log("   User: ${currentUser.name}");

      // ✅ DEBUG: Check session state BEFORE match check
      DebugLogger.log("🔍 BEFORE MATCH CHECK:");
      DebugLogger.log("   UnifiedSessionManager.activeCollaborativeSession: ${UnifiedSessionManager.activeCollaborativeSession?.sessionId ?? 'null'}");
      DebugLogger.log("   Current session matches: ${UnifiedSessionManager.activeCollaborativeSession?.matches ?? []}");
      DebugLogger.log("   Current session ID matches: ${currentSession.sessionId}");

      // Mark user as active (they're swiping)
      await GroupMatchingHandler.markUserAsActive(
        currentSession.sessionId,
        currentUser.uid,
      );

      // Check if this creates a group match
      final isGroupMatch = await GroupMatchingHandler.checkForGroupMatch(
        sessionId: currentSession.sessionId,
        movieId: movie.id,
        userId: currentUser.uid,
      );

      if (isGroupMatch) {
        DebugLogger.log("🎉 GROUP MATCH DETECTED!");

        // ✅ STEP 1: Add movie to active session (in-memory)
        if (UnifiedSessionManager.activeCollaborativeSession != null) {
          if (!UnifiedSessionManager.activeCollaborativeSession!.matches.contains(movie.id)) {
            UnifiedSessionManager.activeCollaborativeSession!.matches.add(movie.id);
          }
        }

        // ✅ STEP 2: Also update the Firestore group doc
        try {
          final sessionSnapshot = await FirebaseFirestore.instance
              .collection('swipeSessions')
              .doc(currentSession.sessionId)
              .get();

          final sessionData = sessionSnapshot.data();
          final groupId = sessionData?['groupId'];

          if (groupId != null) {
            await FirebaseFirestore.instance
                .collection('groups')
                .doc(groupId)
                .update({
              'matchMovieIds': FieldValue.arrayUnion([movie.id])
            });
            DebugLogger.log("✅ Synced group match to Firestore group: $groupId → ${movie.id}");
          } else {
            DebugLogger.log("⚠️ No groupId found in session – cannot update group matches.");
          }
        } catch (e) {
          DebugLogger.log("❌ Failed to sync match to group doc: $e");
        }

        // ✅ STEP 3: Continue normal match handling
        SessionManager.addMatchedMovie(movie.id);
        onShowMatchCelebration(movie);
        return true;
      }

      // Not a group match
      return false;

    } catch (e) {
      DebugLogger.log("❌ Error handling group like: $e");
      return false;
    }
  }


  /// Check if session can start matching (minimum participants)
  static Future<bool> canStartGroupMatching(String sessionId) async {
    return await GroupMatchingHandler.canStartMatching(sessionId);
  }

  /// Handle navigation to multi-match carousel for group sessions
  static void navigateToGroupMatches({
    required BuildContext context,
    required SwipeSession session,
    required UserProfile currentUser,
  }) {
    DebugLogger.log("🎬 Navigating to group matches screen");
    DebugLogger.log("   Session: ${session.sessionId}");
    DebugLogger.log("   Matches: ${session.matches.length}");
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultiMatchCarouselScreen(
          session: session,
          currentUser: currentUser,
          onContinueSearching: () {
            // User wants to continue swiping after viewing matches
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  /// Show group session status widget (can be used in UI)
  static Widget buildGroupStatusWidget({
    required Map<String, dynamic> sessionStats,
    required VoidCallback onRefresh,
  }) {
    final totalParticipants = sessionStats['totalParticipants'] ?? 0;
    final activeParticipants = sessionStats['activeParticipants'] ?? 0;
    final totalMatches = sessionStats['totalMatches'] ?? 0;
    final canMatch = sessionStats['canMatch'] ?? false;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: canMatch 
            ? Colors.green.withValues(alpha: 0.2)
            : Colors.orange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: canMatch 
              ? Colors.green.withValues(alpha: 0.5)
              : Colors.orange.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            canMatch ? Icons.group : Icons.hourglass_empty,
            size: 14,
            color: canMatch ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 6),
          Text(
            canMatch 
                ? "$activeParticipants/$totalParticipants active • $totalMatches matches"
                : "Waiting for participants ($activeParticipants/$totalParticipants)",
            style: TextStyle(
              color: canMatch ? Colors.green : Colors.orange,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRefresh,
            child: Icon(
              Icons.refresh,
              size: 12,
              color: canMatch ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  /// Generate helpful status messages for group sessions
  static String getGroupStatusMessage(Map<String, dynamic> sessionStats) {
    final totalParticipants = sessionStats['totalParticipants'] ?? 0;
    final activeParticipants = sessionStats['activeParticipants'] ?? 0;
    final canMatch = sessionStats['canMatch'] ?? false;
    
    if (totalParticipants == 0) {
      return "No participants in session";
    }
    
    if (activeParticipants == 0) {
      return "Waiting for participants to start swiping";
    }
    
    if (!canMatch) {
      return "Need at least 2 active participants to match";
    }
    
    if (activeParticipants == totalParticipants) {
      return "All $activeParticipants participants are active!";
    } else {
      return "$activeParticipants of $totalParticipants participants are active";
    }
  }

  /// Check if current user should show "see our matches" vs "where to watch"
  static bool shouldShowGroupMatches(SwipeSession? session) {
    if (session == null) return false;
    
    // Show group matches if session has multiple matches
    return session.matches.length > 1;
  }

  /// Handle cleanup of inactive participants (call periodically)
  static Future<void> cleanupInactiveParticipants(
    String sessionId, {
    Duration inactivityThreshold = const Duration(minutes: 5),
  }) async {
    await GroupMatchingHandler.cleanupInactiveParticipants(
      sessionId,
      inactivityThreshold,
    );
  }

    static Timer startGroupStatsMonitoring({
    required String sessionId,
    required Function(Map<String, dynamic>) onStatsUpdate,
    required VoidCallback onError,
    Duration interval = const Duration(seconds: 3),
  }) {
    DebugLogger.log("📊 Starting group stats monitoring for session: $sessionId");
    
    return Timer.periodic(interval, (timer) async {
      try {
        final stats = await GroupMatchingHandler.getSessionStats(sessionId);
        onStatsUpdate(stats);
        
        // Log stats for debugging
        final activeCount = stats['activeParticipants'] ?? 0;
        final totalCount = stats['totalParticipants'] ?? 0;
        final matchCount = stats['totalMatches'] ?? 0;
        DebugLogger.log("📊 Group stats: $activeCount/$totalCount active, $matchCount matches");
        
      } catch (e) {
        DebugLogger.log("❌ Error in group stats monitoring: $e");
        onError();
        timer.cancel();
      }
    });
  }

  /// Get current group session status
  /// Get current group session status
static Future<Map<String, dynamic>> getGroupSessionStatus(String sessionId) async {
  try {
    final sessionDoc = await FirebaseFirestore.instance
        .collection('swipeSessions')
        .doc(sessionId)
        .get();
    
    if (!sessionDoc.exists) {
      return {
        'activeParticipants': 0,
        'totalParticipants': 0,
        'totalMatches': 0,
      };
    }
    
    final data = sessionDoc.data()!;
    
    // ✅ ADD DEBUG LOGGING
    DebugLogger.log("🔍 DEBUG SESSION DATA:");
    DebugLogger.log("   Session ID: $sessionId");
    DebugLogger.log("   Matches: ${data['matches'] ?? []}");
    DebugLogger.log("   Status: ${data['status']}");
    DebugLogger.log("   Participants: ${data['participantNames'] ?? []}");
    DebugLogger.log("   Created: ${data['createdAt']}");
    
    return await GroupMatchingHandler.getSessionStats(sessionId);
    
  } catch (e) {
    DebugLogger.log("❌ Error getting group session status: $e");
    return {
      'activeParticipants': 0,
      'totalParticipants': 0,
      'totalMatches': 0,
    };
  }
}
}