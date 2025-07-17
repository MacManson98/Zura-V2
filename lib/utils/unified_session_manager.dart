// File: lib/utils/unified_session_manager.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'completed_session.dart';
import '../models/user_profile.dart';
import '../models/session_models.dart';
import '../utils/user_profile_storage.dart';
import '../utils/session_manager.dart';
import '../services/session_service.dart';
import '../services/user_service.dart';
import '../utils/debug_loader.dart';
class UnifiedSessionManager {
  // ✅ NEW: Track active collaborative sessions globally
  static SwipeSession? _activeCollaborativeSession;
  
  // =============== ACTIVE SESSION TRACKING ===============
  
  /// Check if there's any active session (solo or collaborative)
  static bool get hasActiveSession => 
      SessionManager.hasActiveSession || _activeCollaborativeSession != null;
  
  /// Check specifically for active collaborative session
  static bool get hasActiveCollaborativeSession => _activeCollaborativeSession != null;
  
  /// Check specifically for active solo session
  static bool get hasActiveSoloSession => SessionManager.hasActiveSession;
  
  /// Set the current active collaborative session
  static void setActiveCollaborativeSession(SwipeSession session) {
    _activeCollaborativeSession = session;
    DebugLogger.log("🤝 Active collaborative session set: ${session.sessionId}");
  }
  
  /// Clear the current active collaborative session
  static void clearActiveCollaborativeSession() {
    _activeCollaborativeSession = null;
    DebugLogger.log("🤝 Active collaborative session cleared");
  }
  
  /// Get the current active collaborative session
  static SwipeSession? get activeCollaborativeSession => _activeCollaborativeSession;
  
  /// Get any active session formatted for display (both solo and collaborative)
  /// Get any active session formatted for display (both solo and collaborative)
  static CompletedSession? getActiveSessionForDisplay() {
    // Check for active solo session first
    if (SessionManager.hasActiveSession && SessionManager.currentSession != null) {
      final activeSession = SessionManager.currentSession!;
      return CompletedSession(
        id: "active_solo_${activeSession.id}",
        startTime: activeSession.startTime,
        endTime: DateTime.now(),
        type: activeSession.type,
        participantNames: activeSession.participantNames,
        likedMovieIds: activeSession.likedMovieIds,
        matchedMovieIds: activeSession.matchedMovieIds,
        mood: activeSession.mood,
        groupName: null,
      );
    }
    
    // Check for active collaborative session
    if (_activeCollaborativeSession != null) {
      final session = _activeCollaborativeSession!;
      
      // Determine session type based on participant count
      SessionType sessionType = SessionType.friend;
      if (session.participantNames.length > 2) {
        sessionType = SessionType.group;
      }
      
      return CompletedSession(
        id: "active_collaborative_${session.sessionId}",
        startTime: session.startedAt ?? session.createdAt,
        endTime: DateTime.now(),
        type: sessionType,
        participantNames: session.participantNames,
        likedMovieIds: [],
        matchedMovieIds: session.matches, // ✅ FIX: Use session.matches instead of empty list
        mood: session.selectedMoodName.isNotEmpty ? session.selectedMoodName : null,
        groupName: session.groupName,
      );
    }
    
    return null;
  }

  // =============== SESSION LIFECYCLE MANAGEMENT ===============

  /// Start a session in the appropriate storage
  static Future<void> startSessionProperly({
    required SessionType sessionType,
    required List<String> participantNames,
    String? mood,
    String? sessionId,
    SwipeSession? collaborativeSession,
  }) async {
    try {
      if (sessionType == SessionType.solo) {
        // Solo session: Start local session tracking
        SessionManager.startSession(
          type: sessionType,
          participantNames: participantNames,
          mood: mood,
        );
        DebugLogger.log("✅ Solo session started in local storage");
      } else {
        // Collaborative session: Track it globally
        if (collaborativeSession != null) {
          setActiveCollaborativeSession(collaborativeSession);
        }
        DebugLogger.log("✅ Collaborative session tracked globally: $sessionId");
      }
    } catch (e) {
      DebugLogger.log("❌ Error starting session properly: $e");
    }
  }

  /// End a session and store it in the appropriate location
  static Future<void> endSessionProperly({
    required SessionType sessionType,
    String? sessionId,
    required UserProfile userProfile,
    CompletedSession? localSession,
  }) async {
    try {
      if (sessionType == SessionType.solo) {
        // Solo session: Save to local storage only
        final completedSession = localSession ?? SessionManager.endSession();
        if (completedSession != null) {
          userProfile.addCompletedSession(completedSession);
          await UserProfileStorage.saveProfile(userProfile);
          DebugLogger.log("✅ Solo session saved to local storage");
        }
      } else {
        // Collaborative session: Mark as completed in Firestore only
        if (sessionId != null) {
          await SessionService.endSession(sessionId);
          DebugLogger.log("✅ Collaborative session marked completed in Firestore");
        }
        // Clear the active collaborative session
        clearActiveCollaborativeSession();
      }
    } catch (e) {
      DebugLogger.log("❌ Error ending session properly: $e");
    }
  }

  /// Delete a session from the appropriate storage
  static Future<void> deleteSessionProperly({
    required CompletedSession session,
    required UserProfile userProfile,
  }) async {
    try {
      // Check if it's an active session
      if (session.id.startsWith("active_")) {
        if (session.id.startsWith("active_solo_")) {
          // End active solo session
          SessionManager.endSession();
          DebugLogger.log("✅ Active solo session ended");
        } else if (session.id.startsWith("active_collaborative_")) {
          // End active collaborative session
          clearActiveCollaborativeSession();
          DebugLogger.log("✅ Active collaborative session ended");
        }
        return;
      }
      
      if (session.type == SessionType.solo) {
        // Solo session: Remove from local storage
        userProfile.sessionHistory.removeWhere((s) => s.id == session.id);
        await UserProfileStorage.saveProfile(userProfile);
        DebugLogger.log("✅ Solo session deleted from local storage");
      } else {
        // Collaborative session: Delete from Firestore
        await FirebaseFirestore.instance
            .collection('swipeSessions')
            .doc(session.id)
            .delete();
        DebugLogger.log("✅ Collaborative session deleted from Firestore");
      }
    } catch (e) {
      DebugLogger.log("❌ Error deleting session properly: $e");
    }
  }

  // =============== SESSION RETRIEVAL ===============

  /// Get all sessions for display purposes (includes active sessions)
  static Future<List<CompletedSession>> getAllSessionsForDisplay(UserProfile userProfile) async {
    try {
      // Get solo sessions from local storage
      final soloSessions = userProfile.sessionHistory
          .where((session) => session.type == SessionType.solo)
          .toList();
      
      // Get collaborative sessions from Firestore
      final userService = UserService();
      final collaborativeSessions = await userService.loadCollaborativeSessionsForDisplay(userProfile.uid);
      
      // Combine all completed sessions
      final allSessions = [...soloSessions, ...collaborativeSessions];
      
      // ✅ Add active session if it exists
      final activeSession = getActiveSessionForDisplay();
      if (activeSession != null) {
        allSessions.insert(0, activeSession); // Add at the beginning (most recent)
      }
      
      // Sort by date (most recent first)
      allSessions.sort((a, b) {
        final aTime = a.startTime;
        final bTime = b.startTime;
        return bTime.compareTo(aTime);
      });
      
      DebugLogger.log("📊 Loaded ${soloSessions.length} solo + ${collaborativeSessions.length} collaborative + ${activeSession != null ? 1 : 0} active sessions");
      
      return allSessions;
    } catch (e) {
      DebugLogger.log("❌ Error loading sessions for display: $e");
      
      // Fallback to solo sessions only
      final sessions = userProfile.sessionHistory
          .where((session) => session.type == SessionType.solo)
          .toList();
      
      // Still try to add active session
      final activeSession = getActiveSessionForDisplay();
      if (activeSession != null) {
        sessions.insert(0, activeSession);
      }
      
      return sessions;
    }
  }
}