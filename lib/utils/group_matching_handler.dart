import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/debug_loader.dart';

class GroupMatchingHandler {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if a movie is a group match (all active participants liked it)
  static Future<bool> checkForGroupMatch({
    required String sessionId,
    required String movieId,
    required String userId,
  }) async {
    try {
      DebugLogger.log("🔍 Checking group match for movie: $movieId in session: $sessionId");
      
      // Get current session data
      final sessionDoc = await _firestore
          .collection('swipeSessions')
          .doc(sessionId)
          .get();
      
      if (!sessionDoc.exists) {
        DebugLogger.log("❌ Session not found: $sessionId");
        return false;
      }
      
      final sessionData = sessionDoc.data() as Map<String, dynamic>;
      final participantIds = List<String>.from(sessionData['participantIds'] ?? []);
      final activeParticipants = List<String>.from(sessionData['activeParticipants'] ?? []);
      
      DebugLogger.log("👥 Total participants: ${participantIds.length}");
      DebugLogger.log("✅ Active participants: ${activeParticipants.length}");
      DebugLogger.log("🎯 Active IDs: $activeParticipants");
      
      // If no active participants recorded yet, consider all participants as active
      final participantsToCheck = activeParticipants.isEmpty ? participantIds : activeParticipants;
      
      if (participantsToCheck.length < 2) {
        DebugLogger.log("⚠️ Not enough active participants for group matching");
        return false;
      }
      
      // First, record this user's like
      await _recordUserLike(sessionId, userId, movieId);
      
      // Get all likes for this movie in this session
      final likesSnapshot = await _firestore
          .collection('swipeSessions')
          .doc(sessionId)
          .collection('likes')
          .where('movieId', isEqualTo: movieId)
          .get();
      
      final usersWhoLiked = likesSnapshot.docs
          .map((doc) => doc.data()['userId'] as String)
          .toSet();
      
      DebugLogger.log("❤️ Users who liked this movie: $usersWhoLiked");
      DebugLogger.log("🎯 Checking against active participants: $participantsToCheck");
      
      // Check if ALL active participants have liked this movie
      final allActiveLiked = participantsToCheck.every((participantId) => 
          usersWhoLiked.contains(participantId));
      
      if (allActiveLiked) {
        DebugLogger.log("🎉 GROUP MATCH! All ${participantsToCheck.length} active participants liked: $movieId");
        
        // Record the match
        await _recordGroupMatch(sessionId, movieId, participantsToCheck);
        
        return true;
      } else {
        final stillNeeded = participantsToCheck.where((id) => !usersWhoLiked.contains(id)).toList();
        DebugLogger.log("⏳ Waiting for more likes. Still need: $stillNeeded");
        return false;
      }
      
    } catch (e) {
      DebugLogger.log("❌ Error checking group match: $e");
      return false;
    }
  }

  /// Record a user's like for a movie in a session
  static Future<void> _recordUserLike(String sessionId, String userId, String movieId) async {
    try {
      await _firestore
          .collection('swipeSessions')
          .doc(sessionId)
          .collection('likes')
          .doc('${userId}_$movieId')
          .set({
        'userId': userId,
        'movieId': movieId,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': DateTime.now().toIso8601String(),
      });
      
      DebugLogger.log("✅ Recorded like: $userId → $movieId");
    } catch (e) {
      DebugLogger.log("❌ Error recording like: $e");
    }
  }

  /// Record a group match when all active participants have liked a movie
  static Future<void> _recordGroupMatch(String sessionId, String movieId, List<String> participantIds) async {
    try {
      // Add to session's matches array
      await _firestore
          .collection('swipeSessions')
          .doc(sessionId)
          .update({
        'matches': FieldValue.arrayUnion([movieId]),
        'lastMatchAt': FieldValue.serverTimestamp(),
        'totalMatches': FieldValue.increment(1),
      });

      // Also record match under the group's document if available
      try {
        final sessionSnap = await _firestore
            .collection('swipeSessions')
            .doc(sessionId)
            .get();

        final groupId = sessionSnap.data()?['groupId'] as String?;
        if (groupId != null && groupId.isNotEmpty) {
          await _firestore
              .collection('groups')
              .doc(groupId)
              .update({
            'matchMovieIds': FieldValue.arrayUnion([movieId]),
            'totalMatches': FieldValue.increment(1),
            'lastActivityDate': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        DebugLogger.log("❌ Error updating group match list: $e");
      }

      // Record detailed match info
      await _firestore
          .collection('swipeSessions')
          .doc(sessionId)
          .collection('matches')
          .doc(movieId)
          .set({
        'movieId': movieId,
        'participantIds': participantIds,
        'matchedAt': FieldValue.serverTimestamp(),
        'createdAt': DateTime.now().toIso8601String(),
        'matchType': 'group',
      });
      
      DebugLogger.log("🎉 Group match recorded: $movieId with participants: $participantIds");
    } catch (e) {
      DebugLogger.log("❌ Error recording group match: $e");
    }
  }

  /// Mark a user as active in the session (they're actually swiping)
  static Future<void> markUserAsActive(String sessionId, String userId) async {
    try {
      await _firestore
          .collection('swipeSessions')
          .doc(sessionId)
          .update({
        'activeParticipants': FieldValue.arrayUnion([userId]),
        'lastActivityAt': FieldValue.serverTimestamp(),
      });
      
      DebugLogger.log("✅ Marked user as active: $userId in session: $sessionId");
    } catch (e) {
      DebugLogger.log("❌ Error marking user as active: $e");
    }
  }

  /// Get active participants count for a session
  static Future<int> getActiveParticipantsCount(String sessionId) async {
    try {
      final sessionDoc = await _firestore
          .collection('swipeSessions')
          .doc(sessionId)
          .get();
      
      if (!sessionDoc.exists) return 0;
      
      final sessionData = sessionDoc.data() as Map<String, dynamic>;
      final activeParticipants = List<String>.from(sessionData['activeParticipants'] ?? []);
      
      return activeParticipants.length;
    } catch (e) {
      DebugLogger.log("❌ Error getting active participants count: $e");
      return 0;
    }
  }

  /// Check if session has minimum participants to start matching
  static Future<bool> canStartMatching(String sessionId) async {
    final activeCount = await getActiveParticipantsCount(sessionId);
    return activeCount >= 2;
  }

  /// Get session statistics for display
  static Future<Map<String, dynamic>> getSessionStats(String sessionId) async {
    try {
      final sessionDoc = await _firestore
          .collection('swipeSessions')
          .doc(sessionId)
          .get();
      
      if (!sessionDoc.exists) {
        return {
          'totalParticipants': 0,
          'activeParticipants': 0,
          'totalMatches': 0,
          'canMatch': false,
        };
      }
      
      final sessionData = sessionDoc.data() as Map<String, dynamic>;
      final participantIds = List<String>.from(sessionData['participantIds'] ?? []);
      final activeParticipants = List<String>.from(sessionData['activeParticipants'] ?? []);
      final matches = List<String>.from(sessionData['matches'] ?? []);
      
      return {
        'totalParticipants': participantIds.length,
        'activeParticipants': activeParticipants.length,
        'totalMatches': matches.length,
        'canMatch': activeParticipants.length >= 2,
        'participantIds': participantIds,
        'activeParticipantIds': activeParticipants,
        'matches': matches,
      };
    } catch (e) {
      DebugLogger.log("❌ Error getting session stats: $e");
      return {
        'totalParticipants': 0,
        'activeParticipants': 0,
        'totalMatches': 0,
        'canMatch': false,
      };
    }
  }

  /// Clean up inactive participants (optional - for sessions that run too long)
  static Future<void> cleanupInactiveParticipants(String sessionId, Duration inactivityThreshold) async {
    try {
      // Get all likes from the last [inactivityThreshold] period
      final cutoffTime = DateTime.now().subtract(inactivityThreshold);
      
      final recentLikesSnapshot = await _firestore
          .collection('swipeSessions')
          .doc(sessionId)
          .collection('likes')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(cutoffTime))
          .get();
      
      final recentlyActiveUsers = recentLikesSnapshot.docs
          .map((doc) => doc.data()['userId'] as String)
          .toSet()
          .toList();
      
      // Update active participants to only recently active users
      await _firestore
          .collection('swipeSessions')
          .doc(sessionId)
          .update({
        'activeParticipants': recentlyActiveUsers,
        'lastCleanupAt': FieldValue.serverTimestamp(),
      });
      
      DebugLogger.log("🧹 Cleaned up inactive participants. Active now: $recentlyActiveUsers");
    } catch (e) {
      DebugLogger.log("❌ Error cleaning up inactive participants: $e");
    }
  }
}