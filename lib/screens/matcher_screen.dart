import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../movie.dart';
import '../utils/group_matching_handler.dart';
import '../utils/movie_loader.dart';
import '../models/user_profile.dart';
import '../utils/themed_notifications.dart';
import '../utils/user_profile_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'match_celebration_screen.dart';
import '../utils/tmdb_api.dart';
import '../widgets/mood_selection_widget.dart';
import '../models/session_models.dart';
import '../services/session_service.dart';
import '../main_navigation.dart';
import '../utils/debug_loader.dart';
import '../utils/completed_session.dart';
import '../utils/session_manager.dart';
import '../utils/unified_session_manager.dart';
import '../models/matching_models.dart';
import '../widgets/matcher/main_content_widget.dart';
import '../widgets/matcher/session_hub_widget.dart';
import '../widgets/matcher/session_banner_widget.dart';
import '../widgets/matcher/collaborative_header_widget.dart';
import '../utils/matcher_group_intergration.dart';
import '../utils/mood_engine_bridge.dart';

class MatcherScreen extends StatefulWidget {
  final List<Movie> allMovies;
  final UserProfile currentUser;
  final List<UserProfile> friendIds;
  final bool showTutorial;
  final UserProfile? selectedFriend;
  final MatchingMode mode;
  final String? sessionId;

  const MatcherScreen({
    super.key,
    required this.allMovies,
    required this.currentUser,
    required this.friendIds,
    this.sessionId,
    this.showTutorial = false,
    this.selectedFriend,
    this.mode = MatchingMode.solo,
  });

  @override
  State<MatcherScreen> createState() => _MatcherScreenState();
}

class _MatcherScreenState extends State<MatcherScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late List<Movie> sessionPool = [];
  final Set<String> currentUserLikes = {};
  MatchingMode currentMode = MatchingMode.solo;
  UserProfile? selectedFriend;
  List<UserProfile> selectedGroup = [];
  final Map<String, Set<String>> groupLikes = {};
  bool _showTutorial = false;
  int _tutorialPage = 0;
  final PageController _tutorialPageController = PageController();
  late List<Movie> movieDatabase = [];
  final Set<String> currentSessionMovieIds = {};
  bool _isLoadingSession = false;
  late List<Movie> _basePool = [];
  late List<Movie> _dynamicPool = [];
  int _swipeCount = 0;
  bool _isRefreshingPool = false;
  SessionContext? currentSessionContext;
  List<CurrentMood> selectedMoods = [];
  bool _showMoodSelectionModal = false;
  bool _isReadyToSwipe = false;
  SwipeSession? currentSession;
  StreamSubscription<SwipeSession>? sessionSubscription;
  bool isWaitingForFriend = false;
  bool isInCollaborativeMode = false;
  Set<String> sessionPassedMovieIds = {};
  Timer? _sessionTimer;
  bool _hasStartedSession = false;
  String? get sessionId => widget.sessionId;
  bool _useSmartOrdering = true;  // Enable/disable smart session flow
  CurrentMood? _lastSessionMood;  // Track last mood for reordering
  int _sessionSwipeCount = 0;     // Track swipes in current session
  
  @override
void initState() {
  super.initState();
  
  // Register callback for direct session joining
  MainNavigation.setSessionCallback(_startCollaborativeSession);
  
  // ✅ NEW: Register callback for starting session listener after joining
  MainNavigation.setSessionListenerCallback(_startSessionListener);
  
  currentMode = widget.mode;
  selectedFriend = widget.selectedFriend;
  _initializeApp();
  _startSessionTimer();

  WidgetsBinding.instance.addObserver(this);

  _checkTutorialStatus();
}

  Future<void> _checkTutorialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final tutorialSeen = prefs.getBool('tutorial_seen') ?? false;
    
    // Only show tutorial if it hasn't been seen AND this is the first time opening the matcher
    if (!tutorialSeen && widget.showTutorial) {
      setState(() {
        _showTutorial = true;
      });
    }
  }

  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (SessionManager.shouldAutoEnd()) {
        _autoEndSession();
      }
    });
  }

    // NEW: Auto-end session due to inactivity
  void _endSession() async {
    if (SessionManager.hasActiveSession) {
      final completedSession = SessionManager.endSession();
      if (completedSession != null) {
        widget.currentUser.addCompletedSession(completedSession);
        await UserProfileStorage.saveProfile(widget.currentUser);
        
        // Save to Firestore
        try {
          await FirebaseFirestore.instance.collection('swipeSessions').add({
            ...completedSession.toJson(),
            'participantIds': [widget.currentUser.uid],
            'createdAt': FieldValue.serverTimestamp(),
          });
          DebugLogger.log("✅ Solo session saved to Firestore");
        } catch (e) {
          DebugLogger.log("⚠️ Error saving solo session to Firestore: $e");
        }
        
        _showSessionSummary(completedSession);
      }
      
      setState(() {
        _hasStartedSession = false;
        // This setState will trigger SessionHubWidget.didUpdateWidget
        // and refresh the session history automatically
      });
    }
  }

  void _autoEndSession() async {
    if (SessionManager.hasActiveSession) {
      final completedSession = SessionManager.endSession();
      if (completedSession != null) {
        widget.currentUser.addCompletedSession(completedSession);
        await UserProfileStorage.saveProfile(widget.currentUser);
        
        try {
          await FirebaseFirestore.instance.collection('swipeSessions').add({
            ...completedSession.toJson(),
            'participantIds': [widget.currentUser.uid],
            'createdAt': FieldValue.serverTimestamp(),
          });
          DebugLogger.log("✅ Auto-ended solo session saved to Firestore");
        } catch (e) {
          DebugLogger.log("⚠️ Error saving auto-ended session to Firestore: $e");
        }
        
        ThemedNotifications.showInfo(context, 'Session ended due to inactivity', icon: "⏰");
      }
      
      setState(() {
        _hasStartedSession = false;
        // This triggers refresh in SessionHubWidget
      });
    }
  }

  // NEW: Show session summary dialog
  void _showSessionSummary(CompletedSession session) {
    final isSolo = session.type == SessionType.solo;
    final count = isSolo ? session.likedMovieIds.length : session.matchedMovieIds.length;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F1F1F),
        title: Text(
          "Session Complete! 🎉",
          style: TextStyle(color: Colors.white, fontSize: 18.sp),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              session.funTitle,
              style: TextStyle(
                color: const Color(0xFFE5A00D),
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              isSolo 
                  ? "You liked $count movie${count == 1 ? '' : 's'}"
                  : "You made $count match${count == 1 ? '' : 'es'}",
              style: TextStyle(color: Colors.white70, fontSize: 14.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              "Duration: ${_formatDuration(session.duration)}",
              style: TextStyle(color: Colors.white70, fontSize: 14.sp),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              "Great!",
              style: TextStyle(color: const Color(0xFFE5A00D)),
            ),
          ),
        ],
      ),
    );
  }

  // NEW: Format duration helper
  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return "${duration.inHours}h ${duration.inMinutes % 60}m";
    } else {
      return "${duration.inMinutes}m";
    }
  }

  void _startSessionIfNeeded() {
    if (isInCollaborativeMode) {
        DebugLogger.log("🚫 Skipping solo session start - in collaborative mode");
        return;
    }

    if (!_hasStartedSession && !SessionManager.hasActiveSession) {
      final sessionType = currentMode == MatchingMode.solo 
          ? SessionType.solo
          : currentMode == MatchingMode.friend 
              ? SessionType.friend 
              : SessionType.group;
      
      final participantNames = <String>["You"];
      if (sessionType == SessionType.friend && selectedFriend != null) {
        participantNames.add(selectedFriend!.name);
      } else if (sessionType == SessionType.group) {
        participantNames.addAll(selectedGroup.map((f) => f.name));
      }
      
      SessionManager.startSession(
        type: sessionType,
        participantNames: participantNames,
        mood: selectedMoods.isNotEmpty ? selectedMoods.first.displayName : null,
      );
      
      setState(() {
        _hasStartedSession = true;
      });
    }
  }

  // NEW: Start popular movies session
  void _startPopularMoviesSession() async {
    DebugLogger.log("🔥 Starting popular movies session");
    
    setState(() {
      _isLoadingSession = true;
      _isReadyToSwipe = true;
      selectedMoods.clear(); // Clear any existing moods
      currentSessionContext = null; // Clear mood context
    });

    try {
      final popularMovies = await TMDBApi.getPopularMovies();
      
      if (popularMovies.isEmpty) {
        _showErrorAndReset("Failed to load popular movies. Please check your internet connection.");
        return;
      }

      // Filter out movies the user has already seen
      final seenMovieIds = <String>{
        ...widget.currentUser.likedMovieIds,
        ...widget.currentUser.passedMovieIds,
      };

      final unseenMovies = popularMovies
          .where((movie) => !seenMovieIds.contains(movie.id))
          .toList();

      if (unseenMovies.isEmpty) {
        _showErrorAndReset("You've seen all the popular movies! Try selecting a mood instead.");
        return;
      }

      setState(() {
        sessionPool = unseenMovies;
        currentSessionMovieIds.clear();
        currentSessionMovieIds.addAll(sessionPool.map((m) => m.id));
      });

      DebugLogger.log("🎬 Loaded ${sessionPool.length} popular movies");

    } catch (e) {
      DebugLogger.log("❌ Error loading popular movies: $e");
      _showErrorAndReset("Failed to load popular movies. Please try again.");
    } finally {
      setState(() => _isLoadingSession = false);
    }
  }

  // NEW: Show error and reset to selection state
  void _showErrorAndReset(String message) {
    ThemedNotifications.showError(context, message);

    
    setState(() {
      _isLoadingSession = false;
      _isReadyToSwipe = false;
      sessionPool.clear();
      currentSessionMovieIds.clear();
    });
  }

  // Show mood picker modal
  void _showMoodPicker() {
    // ✅ FIXED: Determine correct context based on current mode
    MoodSelectionContext moodContext;
    int groupSize = 1;
    
    switch (currentMode) {
      case MatchingMode.solo:
        moodContext = MoodSelectionContext.solo;
        groupSize = 1;
        break;
      case MatchingMode.friend:
        moodContext = selectedFriend != null 
            ? MoodSelectionContext.friendInvite 
            : MoodSelectionContext.solo; // Fallback if no friend selected
        groupSize = 2;
        break;
      case MatchingMode.group:
        moodContext = selectedGroup.isNotEmpty 
            ? MoodSelectionContext.groupInvite 
            : MoodSelectionContext.solo; // Fallback if no group selected
        groupSize = selectedGroup.length + 1;
        break;
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows full height control
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.90,
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20.r),
            topRight: Radius.circular(20.r),
          ),
        ),
        child: Stack(
          children: [
            // Main mood selection widget (includes the ONE drag indicator)
            MoodSelectionWidget(
              onMoodsSelected: (moods) {
                Navigator.pop(context); // Close the bottom sheet
                _onMoodSelected(moods); // ✅ PRESERVED: Use existing mood selection logic
              },
              isGroupMode: currentMode != MatchingMode.solo,
              groupSize: groupSize,
              moodContext: moodContext, // ✅ FIXED: Use correct context for button text
            ),
            
            // Close button positioned over the mood widget
            Positioned(
              top: 16.h,
              right: 16.w,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 18.sp,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Reset to selection state
  void _resetToSelection() {
    setState(() {
      _isReadyToSwipe = false;
      selectedMoods.clear();
      currentSessionContext = null;
      sessionPool.clear();
      sessionPassedMovieIds.clear();
    });
  }

  // Helper methods for button states
  bool _canStartSession() {
    switch (currentMode) {
      case MatchingMode.solo:
        return true;
      case MatchingMode.friend:
        return selectedFriend != null;
      case MatchingMode.group:
        return selectedGroup.isNotEmpty;
    }
  }

  void _onMoodSelected(List<CurrentMood> moods) async {
    DebugLogger.log("🔍 DEBUG: _onMoodSelected called with ${moods.length} mood(s)");
    
    // Check if this is a mood change (for existing sessions)
    if (_lastSessionMood != null && moods.isNotEmpty) {
      final newMood = moods.first;
      if (_lastSessionMood != newMood) {
        final wouldReorder = SmartSessionFlow.shouldReorderVsRegenerate(
          previousMood: _lastSessionMood!,
          newMood: newMood,
          swipeCount: _sessionSwipeCount,
        );
        
        if (wouldReorder) {
          DebugLogger.log("🔄 Mood change detected - will reorder session");
        } else {
          DebugLogger.log("🆕 Mood change detected - will regenerate session");
        }
      }
    }
    
    setState(() {
      selectedMoods = moods;
      _showMoodSelectionModal = false;
      _isLoadingSession = true;
      _isReadyToSwipe = true;
    });

    // Create session context based on selected moods
    if (moods.length == 1) {
      currentSessionContext = SessionContext(
        moods: moods.first,
        groupMemberIds: currentMode == MatchingMode.group 
            ? selectedGroup.map((f) => f.uid).toList()
            : currentMode == MatchingMode.friend && selectedFriend != null
                ? [selectedFriend!.uid]
                : [],
      );
    } else {
      currentSessionContext = _createBlendedSessionContext(moods);
    }

    // For collaborative sessions, send mood change request instead of direct generation
    if (isInCollaborativeMode && currentSession != null) {
      final isHost = currentSession!.hostId == widget.currentUser.uid;
      DebugLogger.log("🔍 DEBUG: isHost: $isHost");
      
      // If session already has different mood, send mood change request
      if (currentSession!.hasMoodSelected && 
          currentSession!.selectedMoodId != moods.first.toString().split('.').last) {
        
        await _sendMoodChangeRequest(requestedMood: moods.first);
        setState(() => _isLoadingSession = false);
        return;
      }
      
      // Otherwise, generate collaborative session normally
      await _generateCollaborativeSession();
    } else {
      // Solo/local sessions
      if (moods.length == 1) {
        await _generateMoodBasedSession();
      } else {
        await _generateBlendedMoodSession();
      }
    }
  }

  SessionContext _createBlendedSessionContext(List<CurrentMood> moods) {
    // Combine all preferred genres and vibes from selected moods
    final Set<String> combinedGenres = {};
    final Set<String> combinedVibes = {};
    
    for (final mood in moods) {
      combinedGenres.addAll(mood.preferredGenres);
      combinedVibes.addAll(mood.preferredVibes);
    }
    
    DebugLogger.log("🎭 Blending ${moods.length} moods: ${moods.map((m) => m.displayName).join(' + ')}");
    DebugLogger.log("   Combined genres: ${combinedGenres.join(', ')}");
    DebugLogger.log("   Combined vibes: ${combinedVibes.join(', ')}");
    
    // Create a temporary mood with combined preferences
    // We'll use the first mood as the base and add combined preferences
    return SessionContext(
      moods: selectedMoods.first, // Base mood for the session context
      groupMemberIds: currentMode == MatchingMode.group 
          ? selectedGroup.map((f) => f.uid).toList()
          : currentMode == MatchingMode.friend && selectedFriend != null
              ? [selectedFriend!.uid]
              : [],
    );
  }

  Future<void> _generateBlendedMoodSession() async {
    if (movieDatabase.isEmpty || selectedMoods.isEmpty) {
      _showErrorAndReset("Movie database not loaded. Please try again.");
      return;
    }
    
    final seenMovieIds = <String>{
      ...widget.currentUser.likedMovieIds,
      ...widget.currentUser.passedMovieIds,
      ...currentSessionMovieIds,
    };
    
    try {
      DebugLogger.log("🎭 Generating PURE blended mood session for: ${selectedMoods.map((m) => m.displayName).join(' + ')}");
      
      final blendedMovies = await MoodBasedLearningEngine.generateBlendedMoodSession(
        user: widget.currentUser,
        movieDatabase: movieDatabase,
        selectedMoods: selectedMoods,
        seenMovieIds: seenMovieIds,
        sessionPassedMovieIds: sessionPassedMovieIds,
        sessionSize: 30,
      );
      
      if (blendedMovies.isEmpty) {
        _showErrorAndReset("No movies found for this mood combination. Try a different mood.");
        return;
      }
      
      setState(() {
        sessionPool.clear();
        sessionPool.addAll(blendedMovies);
        _isLoadingSession = false;
      });
      
      currentSessionMovieIds.clear();
      currentSessionMovieIds.addAll(sessionPool.map((m) => m.id));
      
      DebugLogger.log("🎬 Generated ${sessionPool.length} pure blended mood movies");
      
    } catch (e) {
      DebugLogger.log("❌ Error generating blended mood session: $e");
      _showErrorAndReset("Failed to generate movies for this mood. Please try again.");
    }
  }

  @override
  void didUpdateWidget(MatcherScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check if the mode parameter has changed
    if (oldWidget.mode != widget.mode) {
      DebugLogger.log("🔄 Mode changed from ${oldWidget.mode} to ${widget.mode}");
      
      setState(() {
        currentMode = widget.mode;
        
        // Reset session state when mode changes
        _resetToSelection();
        
        // Clear selections when switching away from those modes
        if (currentMode != MatchingMode.friend) {
          selectedFriend = null;
        }
        if (currentMode != MatchingMode.group) {
          selectedGroup.clear();
          groupLikes.clear();
        }
      });
      
      // Regenerate session if needed
      if (currentMode == MatchingMode.solo) {
        _initializeApp();
      }
    }
    
    // Check if selectedFriend parameter has changed
    if (oldWidget.selectedFriend != widget.selectedFriend) {
      DebugLogger.log("🔄 Selected friend changed from ${oldWidget.selectedFriend?.name} to ${widget.selectedFriend?.name}");
      
      setState(() {
        selectedFriend = widget.selectedFriend;
      });
    }
  }

  Future<void> _generateMoodBasedSession() async {
    if (movieDatabase.isEmpty || currentSessionContext == null) {
      _showErrorAndReset("Movie database not loaded. Please try again.");
      return;
    }
    
    final seenMovieIds = <String>{
      ...widget.currentUser.likedMovieIds,
      ...widget.currentUser.passedMovieIds,
      ...currentSessionMovieIds,
    };
    
    try {
      DebugLogger.log("🎭 Generating mood-based session: ${selectedMoods.first.displayName}");
      DebugLogger.log("🎯 Using smart ordering: $_useSmartOrdering");
      
      // Check if this is a mood change that should trigger reordering
      final shouldReorder = _shouldReorderForMoodChange(selectedMoods.first);
      
      if (shouldReorder) {
        DebugLogger.log("🔄 Detected mood change - will reorder existing session");
      } else {
        DebugLogger.log("🆕 Generating fresh session");
        // Reset session tracking for fresh start
        MoodBasedLearningEngine.resetSessionTracking();
      }
      
      if (currentMode == MatchingMode.solo) {
        // Solo mood session with smart ordering
        sessionPool = await MoodBasedLearningEngine.generateMoodBasedSession(
          user: widget.currentUser,
          movieDatabase: movieDatabase,
          sessionContext: currentSessionContext!,
          seenMovieIds: seenMovieIds,
          sessionPassedMovieIds: sessionPassedMovieIds,
          sessionSize: 30,
          useSmartOrdering: _useSmartOrdering,  // NEW PARAMETER
        );
      } else {
        // Friend/Group mood session - everyone gets same pool
        final groupMembers = currentMode == MatchingMode.friend && selectedFriend != null
            ? [widget.currentUser, selectedFriend!]
            : currentMode == MatchingMode.group
                ? [widget.currentUser, ...selectedGroup]
                : [widget.currentUser];

        sessionPool = await MoodBasedLearningEngine.generateGroupSession(
          groupMembers: groupMembers,
          movieDatabase: movieDatabase,
          sessionContext: currentSessionContext!,
          seenMovieIds: seenMovieIds,
          sessionSize: 25,
          useSmartOrdering: _useSmartOrdering,  // NEW PARAMETER
        );
      }

      // Update tracking variables
      _lastSessionMood = selectedMoods.first;
      _sessionSwipeCount = 0;
      
      // Log session analytics if using smart ordering
      if (_useSmartOrdering) {
        final analytics = SmartSessionFlow.getSessionAnalytics(sessionPool);
        DebugLogger.log("📊 Session Analytics: $analytics");
      }

      if (sessionPool.isEmpty) {
        _showErrorAndReset("No movies found for this mood. Try a different mood.");
        return;
      }
      
      setState(() {
        _isLoadingSession = false;
      });
      
      currentSessionMovieIds.clear();
      currentSessionMovieIds.addAll(sessionPool.map((m) => m.id));
      
      DebugLogger.log("🎬 Generated ${sessionPool.length} enhanced mood movies");
      DebugLogger.log("   Sample: ${sessionPool.take(3).map((m) => '${m.title} (${m.voteCount ?? 0} votes)').join(', ')}");
      
    } catch (e) {
      DebugLogger.log("❌ Error generating mood session: $e");
      _showErrorAndReset("Failed to generate movies for this mood. Please try again.");
    }
  }

  bool _shouldReorderForMoodChange(CurrentMood newMood) {
    if (_lastSessionMood == null) return false;
    
    return SmartSessionFlow.shouldReorderVsRegenerate(
      previousMood: _lastSessionMood!,
      newMood: newMood,
      swipeCount: _sessionSwipeCount,
    );
  }

  Future<void> _initializeApp() async {
    setState(() => _isLoadingSession = true);
    
    try {
      // Load movie database
      movieDatabase = await MovieDatabaseLoader.loadMovieDatabase();
      
      if (movieDatabase.isEmpty) {
        _showErrorAndReset("Failed to load movie database. Please check your internet connection.");
        return;
      }
      
      // Check if we should show the "Learning your taste..." banner
      if (!widget.currentUser.hasSeenMatcher) {
        widget.currentUser.hasSeenMatcher = true;
        await UserProfileStorage.saveProfile(widget.currentUser);

      }
    } catch (e) {
      DebugLogger.log("❌ Error initializing app: $e");
      _showErrorAndReset("Failed to initialize the app. Please try again.");
    } finally {
      setState(() => _isLoadingSession = false);
    }
  }

  // Add this method to your _MatcherScreenState class
  

  /// Loading state for when generating sessions
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFFE5A00D)),
          SizedBox(height: 16.h),
          Text(
            "Generating personalized recommendations...",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16.sp,
            ),
          ),
        ],
      ),
    );
  }
  /// Handles movie likes across all matching modes.
  /// 
  /// **Group Matching Architecture:**
  /// - Solo mode: No matching, just records likes
  /// - Friend mode: Simple 2-person matching (if friend also liked the movie)
  /// - Group mode (collaborative): Uses GroupMatchingHandler via MatcherGroupIntegration
  ///   - All active participants must like the same movie for a match
  ///   - Handles real-time Firebase coordination
  ///   - Shows match celebration when all participants agree
  /// 
  /// The group matching logic is centralized in:
  /// - `GroupMatchingHandler`: Core business logic for group matching
  /// - `MatcherGroupIntegration`: Integration layer for UI coordination  
  /// - This method: Orchestrates the flow and handles UI updates
  
  void likeMovie(Movie movie) async {
    _startSessionIfNeeded();
    _trackSwipe(movie.id, true);
    SessionManager.addLikedMovie(movie.id);

    if (isInCollaborativeMode && currentSession != null) {
      try {
        await GroupMatchingHandler.markUserAsActive(
          currentSession!.sessionId,
          widget.currentUser.uid,
        );
        DebugLogger.log("✅ Marked user as active in session: ${currentSession!.sessionId}");
      } catch (e) {
        DebugLogger.log("⚠️ Failed to mark user as active: $e");
      }
    }
    
    // Track with timestamp and session type
    final sessionType = currentMode == MatchingMode.solo 
        ? "solo" 
        : currentMode == MatchingMode.friend 
            ? "friend" 
            : "group";
            
    widget.currentUser.recentLikes.add(MovieLike(
      movieId: movie.id,
      likedAt: DateTime.now(),
      sessionType: sessionType,
    ));
    
    // Keep only last 50 likes to prevent unlimited growth
    if (widget.currentUser.recentLikes.length > 50) {
      widget.currentUser.recentLikes.removeRange(
        0, 
        widget.currentUser.recentLikes.length - 50
      );
    }
    
    // ✅ KEEP: Add to personal likes
    setState(() {
      widget.currentUser.addLikedMovie(movie);
    });

    try {
      await UserProfileStorage.saveProfile(widget.currentUser);
    } catch (e) {
      DebugLogger.log("⚠️ Error saving user profile: $e");
    }

    // 🎯 CLEAN MATCHING LOGIC
    if (currentMode == MatchingMode.solo) {
      // Solo mode - no matching needed
      DebugLogger.log("✅ Solo like recorded - session will complete when ended");
      
    } else if (currentMode == MatchingMode.friend && 
              selectedFriend?.likedMovieIds.contains(movie.id) == true) {
      // Friend mode - keep existing simple logic (works fine for 2 people)
      DebugLogger.log("🎉 Friend match detected!");
      SessionManager.addMatchedMovie(movie.id);
      
      // ✅ FIXED: In session-based system, matches are tracked in sessions
      // No need to add to user profile - just add to cache for immediate display
      setState(() {
        widget.currentUser.loadMoviesIntoCache([movie]);
      });
      
      // Save the updated profile (personal likes only)
      try {
        await UserProfileStorage.saveProfile(widget.currentUser);
      } catch (e) {
        DebugLogger.log("⚠️ Error saving profile: $e");
      }
      
      await _markSessionAsCompleted(movie: movie);
      _showMatchCelebration(movie);
      
    } else if (currentMode == MatchingMode.group && isInCollaborativeMode && currentSession != null) {
      // 🆕 NEW: Enhanced group mode - ALL active participants must match
      DebugLogger.log("🔍 Processing group like for: ${movie.title}");
      
      try {
        final isMatch = await MatcherGroupIntegration.handleGroupLike(
          context: context,
          movie: movie,
          currentUser: widget.currentUser,
          currentSession: currentSession,
          isInCollaborativeMode: isInCollaborativeMode,
          onShowMatchCelebration: _showMatchCelebration,
        );
        
        if (isMatch) {
          DebugLogger.log("🎉 Group match created for: ${movie.title}");
          SessionManager.addMatchedMovie(movie.id);
          
          // ✅ FIXED: In session-based system, matches are tracked in sessions
          // Just add to cache for immediate display
          setState(() {
            widget.currentUser.loadMoviesIntoCache([movie]);
          });
          
          // Save the updated profile (personal likes only)
          try {
            await UserProfileStorage.saveProfile(widget.currentUser);
          } catch (e) {
            DebugLogger.log("⚠️ Error saving profile: $e");
          }
          
          await _markSessionAsCompleted(movie: movie);
          
        } else {
          DebugLogger.log("⏳ Group like recorded, waiting for more participants");
        }
      } catch (e) {
        DebugLogger.log("❌ Error in group matching: $e");
        // For group mode, we now rely entirely on the new system
        // If it fails, we just log the error and continue
      }
      
    } else if (currentMode == MatchingMode.group) {
      // Group mode but not collaborative - this shouldn't happen in new system
      DebugLogger.log("⚠️ Group mode without collaborative session - check setup");
      
    } else {
      // Just a regular like with no matching needed
      DebugLogger.log("✅ Like recorded in ${currentMode.name} mode");
    }
  }

  // 🔄 PRESERVED: Your exact _markSessionAsCompleted method
  Future<void> _markSessionAsCompleted({required Movie movie}) async {
    try {
      await FirebaseFirestore.instance
          .collection('swipeSessions')
          .doc(widget.sessionId)
          .update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      // ✅ If it's a group session, also update the group's matched movies
      if (currentMode == MatchingMode.group &&
          currentSession?.groupId != null &&
          movie.id.isNotEmpty) {
        final groupId = currentSession!.groupId!;
        await FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .update({
          'matchMovieIds': FieldValue.arrayUnion([movie.id])
        });
        DebugLogger.log("✅ Added match to group doc: $groupId -> ${movie.id}");
      }


      DebugLogger.log("✅ Session marked as completed");

      // ✅ FIXED: Don't end session yet - just record the match and create a snapshot
      // Users can continue swiping after a match in collaborative mode
      
      if (SessionManager.currentSession != null) {
        // Create a snapshot of current session state (but don't end session)
        final currentSessionSnapshot = CompletedSession(
          id: widget.sessionId ?? DateTime.now().millisecondsSinceEpoch.toString(),
          startTime: SessionManager.currentSession!.startTime,
          endTime: DateTime.now(), // Snapshot time
          type: currentMode == MatchingMode.friend ? SessionType.friend : SessionType.group,
          participantNames: [
            widget.currentUser.name,
            if (selectedFriend != null) selectedFriend!.name,
            if (selectedGroup.isNotEmpty) ...selectedGroup.map((f) => f.name),
          ],
          likedMovieIds: SessionManager.currentSession!.likedMovieIds, // ✅ Session-specific likes
          matchedMovieIds: [...SessionManager.currentSession!.matchedMovieIds, movie.id], // Add this match
          mood: selectedMoods.isNotEmpty ? selectedMoods.first.displayName : null,
        );

        widget.currentUser.sessionHistory.add(currentSessionSnapshot);
        await UserProfileStorage.saveProfile(widget.currentUser);
        
        DebugLogger.log("✅ Match recorded - session snapshot saved with ${currentSessionSnapshot.likedMovieIds.length} session likes");
        DebugLogger.log("   Session continues - users can keep swiping");
      } else {
        DebugLogger.log("⚠️ No active session found when trying to mark as completed");
      }

    } catch (e) {
      DebugLogger.log("❌ Failed to mark session as completed: $e");
    }
  }

  // 🔄 PRESERVED: Your exact passMovie method
  void passMovie(Movie movie) {
    _startSessionIfNeeded();
    _trackSwipe(movie.id, false);
    SessionManager.recordActivity();
    // Save profile
    UserProfileStorage.saveProfile(widget.currentUser);
  }

  void _showMatchCelebration(Movie matchedMovie) {
    DebugLogger.log("🔍 ===========================================");
    DebugLogger.log("🔍 _showMatchCelebration DEBUG START");
    DebugLogger.log("🔍 ===========================================");
    DebugLogger.log("🔍 isInCollaborativeMode: $isInCollaborativeMode");
    DebugLogger.log("🔍 currentSession == null: ${currentSession == null}");
    
    if (currentSession != null) {
      DebugLogger.log("🔍 ✅ currentSession EXISTS!");
      DebugLogger.log("🔍 currentSession.sessionId: ${currentSession!.sessionId}");
      DebugLogger.log("🔍 currentSession.status: ${currentSession!.status}");
      DebugLogger.log("🔍 currentSession.matches: ${currentSession!.matches}");
      DebugLogger.log("🔍 currentSession.participantNames: ${currentSession!.participantNames}");
    } else {
      DebugLogger.log("🔍 ❌ currentSession is NULL - this should NOT happen!");
    }
    
    // Get friend name
    String? friendName;
    if (isInCollaborativeMode && currentSession != null) {
      final friendNames = currentSession!.participantNames
          .where((name) => name != widget.currentUser.name)
          .toList();
      friendName = friendNames.isNotEmpty ? friendNames.first : null;
    }
    
    DebugLogger.log("🔍 About to create MatchCelebrationScreen...");
    DebugLogger.log("🔍 Passing currentSession: ${currentSession?.sessionId}");
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          DebugLogger.log("🔍 MatchCelebrationScreen builder called");
          DebugLogger.log("🔍 In builder - currentSession: ${currentSession?.sessionId}");
          
          return MatchCelebrationScreen(
            movie: matchedMovie,
            currentUser: widget.currentUser,
            matchedName: friendName,
            allMatchedUsers: currentSession?.participantNames,
            currentSession: currentSession,
          );
        },
      ),
    ).then((_) {
      DebugLogger.log("🔍 Returned from MatchCelebrationScreen");
    });
    
    DebugLogger.log("🔍 ===========================================");
    DebugLogger.log("🔍 _showMatchCelebration DEBUG END");
    DebugLogger.log("🔍 ===========================================");
  }

  Future<void> _markTutorialSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_seen', true);
  }

  // Add adaptive pool refresh
  Future<void> _adaptSessionPool() async {
    if (_isRefreshingPool || currentSessionContext == null) return;
    
    setState(() => _isRefreshingPool = true);
    
    try {
      final seenMovieIds = <String>{
        ...widget.currentUser.likedMovieIds,
        ...widget.currentUser.passedMovieIds,
        ...currentSessionMovieIds,
      };
      
      DebugLogger.log("🔄 Adapting session pool (smart: $_useSmartOrdering)");
      
      // Generate more movies using enhanced engine
      final moreMovies = await MoodBasedLearningEngine.generateMoodBasedSession(
        user: widget.currentUser,
        movieDatabase: movieDatabase,
        sessionContext: currentSessionContext!,
        seenMovieIds: seenMovieIds,
        sessionPassedMovieIds: sessionPassedMovieIds,
        sessionSize: 10,
        useSmartOrdering: _useSmartOrdering,
      );
      
      if (moreMovies.isNotEmpty) {
        setState(() {
          sessionPool.addAll(moreMovies);
          _isRefreshingPool = false;
        });
        
        currentSessionMovieIds.addAll(moreMovies.map((m) => m.id));
        
        DebugLogger.log("✅ Added ${moreMovies.length} more movies to session");
        DebugLogger.log("   New total: ${sessionPool.length} movies");
      } else {
        DebugLogger.log("⚠️ No additional movies found for current mood");
        setState(() => _isRefreshingPool = false);
      }
      
    } catch (e) {
      DebugLogger.log("❌ Error adapting session pool: $e");
      setState(() => _isRefreshingPool = false);
    }
  }

  void _trackSwipe(String movieId, bool isLike) {
    _sessionSwipeCount++;
    
    // Track in the mood engine
    MoodBasedLearningEngine.recordSwipe(
      movieId: movieId,
      isLike: isLike,
    );
    
    DebugLogger.log("👆 Swipe ${_sessionSwipeCount}: ${isLike ? 'LIKE' : 'PASS'} - ${movieId}");
    
    // Log session health periodically
    if (_sessionSwipeCount % 5 == 0) {
      final health = MoodBasedLearningEngine.getSessionHealthScore();
      DebugLogger.log("💚 Session Health: ${(health * 100).toStringAsFixed(1)}%");
      
      // Suggest mood change if session health is low
      if (health < 0.4 && _sessionSwipeCount > 15) {
        DebugLogger.log("⚠️ Low session health - user might want to change mood");
        // You could show a UI hint here if desired
      }
    }
  }

  // Add pool refresh when running low
  Future<void> _refreshPoolIfNeeded() async {
    if (_isRefreshingPool) return;
    
    setState(() => _isRefreshingPool = true);
    
    try {
      final remainingInBase = _basePool.length - _dynamicPool.length;
      
      if (remainingInBase > 0) {
        // Add more from base pool
        final nextBatch = _basePool
            .skip(_dynamicPool.length)
            .take(10)
            .toList();
        
        setState(() {
          sessionPool.addAll(nextBatch);
          _dynamicPool.addAll(nextBatch);
        });
      } else {
        // Generate completely new movies
        await _adaptSessionPool();
      }
    } finally {
      setState(() => _isRefreshingPool = false);
    }
  }

  // Add visual indicator for pool refresh
  Widget _buildPoolRefreshIndicator() {
    if (!_isRefreshingPool) return const SizedBox.shrink();
    
    return Positioned(
      top: 100.h,
      right: 16.w,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: const Color(0xFFE5A00D),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12.w,
              height: 12.w,
              child: CircularProgressIndicator(
                strokeWidth: 2.w,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              'Finding new picks...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Handle mode change
  void _switchMode(MatchingMode mode) {
    setState(() {
      currentMode = mode;
      _resetToSelection(); // Reset session when switching modes
      
      // Clear selections when switching away from those modes
      if (mode != MatchingMode.friend) {
        selectedFriend = null;
      }
      if (mode != MatchingMode.group) {
        selectedGroup.clear();
        groupLikes.clear();
      }
    });
  }

  // Add method to select a friend
  void _selectFriend(UserProfile friend) {
    setState(() {
      selectedFriend = friend;
      currentMode = MatchingMode.friend;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    DebugLogger.log("🔍 BUILD: _hasStartedSession = $_hasStartedSession");
    DebugLogger.log("🔍 BUILD: SessionManager.hasActiveSession = ${SessionManager.hasActiveSession}");
    DebugLogger.log("🔍 BUILD: sessionPool.length = ${sessionPool.length}");
    DebugLogger.log("🔍 BUILD: _isReadyToSwipe = $_isReadyToSwipe");

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      // Use AppBar matching friends_screen style
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        title: Text(
          _getAppBarTitle(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24.sp,
            letterSpacing: 0.5,
          ),
        ),
        // Add live indicator as an action if in collaborative mode
        actions: [
          if (isInCollaborativeMode)
            Padding(
              padding: EdgeInsets.only(right: 16.w),
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.5),
                      width: 1.w,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6.w,
                        height: 6.h,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        "LIVE",
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF121212),
              const Color(0xFF0A0A0A),
            ],
          ),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                // Mode selection section matching friends_screen style
                _buildThemedModeSelection(),
                
                // Collaborative header (only when in collaborative mode)
                CollaborativeHeaderWidget(
                  isInCollaborativeMode: isInCollaborativeMode,
                  currentSession: currentSession,
                  isReadyToSwipe: _isReadyToSwipe,
                  isWaitingForFriend: isWaitingForFriend,
                  currentUser: widget.currentUser,
                  selectedMoods: selectedMoods,
                  onRequestMoodChange: _requestMoodChange,
                  onUpdateState: _updateStateFromWidget,
                ),

                // Group session status (only when in group collaborative mode)
                //_buildGroupSessionStatus(),

                // Smart banner (when ready to swipe)
                if (_isReadyToSwipe) SessionBannerWidget(
                  showMoodSelectionModal: _showMoodSelectionModal,
                  selectedMoods: selectedMoods,
                  isInCollaborativeMode: isInCollaborativeMode,
                  isReadyToSwipe: _isReadyToSwipe,
                  currentSession: currentSession,
                  currentUser: widget.currentUser,
                  onShowMoodSelection: () {
                    setState(() {
                      _showMoodSelectionModal = true;
                    });
                  },
                  onRequestMoodChange: _requestMoodChange,
                  onRefreshMood: () {
                    setState(() {
                      _showMoodSelectionModal = true;
                      selectedMoods.clear();
                      currentSessionContext = null;
                    });
                  },
                  onUpdateState: _updateStateFromWidget,
                  onShowSnackBar: (String message) {
                    if (message.contains('Failed') || message.contains('Error')) {
                      ThemedNotifications.showError(context, message);
                    } else if (message.contains('everyone') || message.contains('waiting')) {
                      ThemedNotifications.showWaiting(context, message);
                    } else {
                      ThemedNotifications.showSuccess(context, message);
                    }
                  },
                ),

                // Main content area
                Expanded(
                  child: _isLoadingSession 
                      ? _buildLoadingState()
                      : _isReadyToSwipe 
                          ? _buildMainContent()
                          : SessionHubWidget(
                              currentMode: currentMode,
                              isInCollaborativeMode: isInCollaborativeMode,
                              selectedFriend: selectedFriend,
                              selectedGroup: selectedGroup,
                              isWaitingForFriend: isWaitingForFriend,
                              currentSession: currentSession,
                              currentUser: widget.currentUser,
                              hasStartedSession: _hasStartedSession,
                              friendIds: widget.friendIds,
                              onEndSession: _endSession,
                              onStartPopularMovies: _startPopularMoviesSession,
                              onShowMoodPicker: _showMoodPicker,
                              onGroupSelected: (selectedGroup) {
                                setState(() {
                                  this.selectedGroup = selectedGroup;
                                  _initializeApp();
                                });
                              },
                              onSessionCreated: _startCollaborativeSession,
                              canStartSession: _canStartSession,
                              formatDuration: _formatDuration,
                            ),
                ),
              ],
            ),
            
            // Overlays
            if (_isReadyToSwipe) _buildPoolRefreshIndicator(),
            _buildTutorialOverlay(),
          ],
        ),
      ),
    );
  }

  // NEW: Add this method to match your friends_screen theme
  Widget _buildThemedModeSelection() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1F1F1F),
            const Color(0xFF1F1F1F).withValues(alpha: 0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 16.h),
        child: Container(
          height: 60.h, // Fixed compact height
          padding: EdgeInsets.all(4.r),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF2A2A2A),
                const Color(0xFF1F1F1F),
              ],
            ),
            border: Border.all(
              color: const Color(0xFFE5A00D).withValues(alpha: 0.2),
              width: 1.w,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12.r,
                offset: Offset(0, 4.h),
              ),
              BoxShadow(
                color: const Color(0xFFE5A00D).withValues(alpha: 0.1),
                blurRadius: 20.r,
                offset: Offset(0, 8.h),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildThemedModeButton(
                  "Solo", 
                  Icons.person_outline,
                  Icons.person,
                  currentMode == MatchingMode.solo,
                  () => _switchMode(MatchingMode.solo),
                ),
              ),
              Expanded(
                child: _buildThemedModeButton(
                  "Friend",
                  Icons.people_outline,
                  Icons.people,
                  currentMode == MatchingMode.friend,
                  () => _switchMode(MatchingMode.friend),
                ),
              ),
              Expanded(
                child: _buildThemedModeButton(
                  "Group",
                  Icons.groups_outlined,
                  Icons.groups,
                  currentMode == MatchingMode.group,
                  () => _switchMode(MatchingMode.group),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // NEW: Add this method for themed mode buttons
  Widget _buildThemedModeButton(
    String title, 
    IconData outlineIcon,
    IconData filledIcon,
    bool isSelected, 
    VoidCallback onTap
  ) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: isSelected ? 1.0 : 0.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.98 + (0.02 * value),
          child: Container(
            margin: EdgeInsets.all(2.r),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.r),
              gradient: isSelected 
                  ? LinearGradient(
                      colors: [const Color(0xFFE5A00D), Colors.orange.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              boxShadow: isSelected 
                  ? [
                      BoxShadow(
                        color: const Color(0xFFE5A00D).withValues(alpha: 0.4),
                        blurRadius: 8.r,
                        offset: Offset(0, 2.h),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12.r),
                splashColor: const Color(0xFFE5A00D).withValues(alpha: 0.2),
                child: Container(
                  height: double.infinity,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          isSelected ? filledIcon : outlineIcon,
                          key: ValueKey('${title}_$isSelected'),
                          color: isSelected 
                              ? Colors.white 
                              : Colors.white.withValues(alpha: 0.7),
                          size: 18.sp,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          color: isSelected 
                              ? Colors.white 
                              : Colors.white.withValues(alpha: 0.7),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 13.sp,
                          letterSpacing: 0.3,
                        ),
                        child: Text(title),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  String _getAppBarTitle() {
    if (isInCollaborativeMode && currentSession != null) {
      // Check if this is a group session with a group name
      if (currentSession!.participantNames.length > 2) {
        // ✅ ADD THIS: Check if there's a group name in the session
        if (currentSession!.groupName != null && currentSession!.groupName!.isNotEmpty) {
          return "Swiping with ${currentSession!.groupName}";
        } else {
          // Fallback: use participant names
          final friendNames = currentSession!.participantNames
              .where((name) => name != widget.currentUser.name)
              .toList();
          if (friendNames.length <= 2) {
            return "Swiping with ${friendNames.join(", ")}";
          } else {
            return "Swiping with ${friendNames.take(2).join(", ")} +${friendNames.length - 2}";
          }
        }
      } else {
        // Friend session (2 participants) - keep existing logic
        final friendNames = currentSession!.participantNames
            .where((name) => name != widget.currentUser.name)
            .toList();
        
        if (friendNames.isNotEmpty) {
          return "Swiping with ${friendNames.first}";
        } else {
          return "Collaborative Session";
        }
      }
    }
    
    switch (currentMode) {
      case MatchingMode.solo:
        return "Find Your Movies";
      case MatchingMode.friend:
        return selectedFriend != null 
            ? "Swiping with ${selectedFriend!.name}"
            : "Friend Mode";
      case MatchingMode.group:
        if (selectedGroup.isNotEmpty) {
          // Check if there's a stored group name for local groups
          // For now, we'll use participant names as fallback
          if (selectedGroup.length == 1) {
            return "Swiping with ${selectedGroup.first.name}";
          } else {
            final groupMembers = selectedGroup.map((user) => user.name).toList();
            if (groupMembers.length <= 2) {
              return "Swiping with ${groupMembers.join(", ")}";
            } else {
              return "Swiping with ${groupMembers.take(2).join(", ")} +${groupMembers.length - 2}";
            }
          }
        } else {
          return "Group Mode";
        }
    }
  }

  Widget _buildMainContent() {
    return MainContentWidget(
      hasStartedSession: _hasStartedSession,
      sessionPool: sessionPool,
      currentMode: currentMode,
      selectedFriend: selectedFriend,
      isInCollaborativeMode: isInCollaborativeMode,
      currentUser: widget.currentUser,
      friendIds: widget.friendIds,
      selectedGroup: selectedGroup,
      currentSession: currentSession,
      currentSessionContext: currentSessionContext,
      selectedMoods: selectedMoods,
      sessionPassedMovieIds: sessionPassedMovieIds,
      currentSessionMovieIds: currentSessionMovieIds,
      swipeCount: _swipeCount,
      movieDatabase: movieDatabase,
      isRefreshingPool: _isRefreshingPool,
      basePool: _basePool,
      dynamicPool: _dynamicPool,
      groupLikes: groupLikes,
      onStartPopularMovies: _startPopularMoviesSession,
      onShowMoodPicker: _showMoodPicker,
      onSwitchMode: _switchMode,
      onInitializeApp: _initializeApp,
      onShowMatchCelebration: _showMatchCelebration,
      onLikeMovie: likeMovie,
      onPassMovie: passMovie,
      onRefreshPoolIfNeeded: _refreshPoolIfNeeded,
      onAddMoreMoviesToSession: (sessionId, movieIds) => _addMoreMoviesToSession(),
      onSelectFriend: _selectFriend,
      onAdaptSessionPool: _adaptSessionPool,
      onUpdateState: _updateStateFromWidget,
    );
  }

  void _updateStateFromWidget(Map<String, dynamic> updates) {
  setState(() {
    updates.forEach((key, value) {
      switch (key) {
        case 'hasStartedSession':
          _hasStartedSession = value;
          break;
        case 'isReadyToSwipe':
          _isReadyToSwipe = value;
          break;
        case 'selectedMoods':
          selectedMoods = value;
          break;
        case 'sessionPool':
          sessionPool = value;
          break;
        case 'currentSessionContext':
          currentSessionContext = value;
          break;
        case 'swipeCount':
          _swipeCount = value;
          break;
        case 'userLikedMovies':
          widget.currentUser.likedMovies = Set<Movie>.from(value);
          break;
        case 'userLikedMovieIds':
          widget.currentUser.likedMovieIds = Set<String>.from(value);
          break;
        case 'userPassedMovieIds':
          widget.currentUser.passedMovieIds = Set<String>.from(value);
          break;
        case 'sessionPassedMovieIds':
          sessionPassedMovieIds = Set<String>.from(value);
          break;
        // Add other cases as needed
      }
    });
  });
}

  Widget _buildTutorialOverlay() {
    final tutorialPages = [
      {
        'title': 'Solo Mode',
        'description': 'Swipe right on movies you like, left on ones you don\'t. Browse popular trending movies or choose a mood for personalized recommendations!',
        'icon': Icons.person,
        'color': const Color(0xFFE5A00D), // Golden
      },
      {
        'title': 'Friend Mode',
        'description': 'Swipe together with friends! When both you and your friend like the same movie, it\'s a match. Perfect for finding movies to watch together.',
        'icon': Icons.people,
        'color': const Color(0xFFE5A00D), // Golden
      },
      {
        'title': 'Group Mode',
        'description': 'Swipe with your group! When EVERYONE likes the same film, it\'s a match. Great for group movie nights and finding something everyone will enjoy.',
        'icon': Icons.groups,
        'color': const Color(0xFFE5A00D), // Golden
      },
    ];

    return _showTutorial
        ? Container(
            color: Colors.black.withAlpha((255 * 0.85).round()),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Page indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    tutorialPages.length,
                    (index) => Container(
                      margin: EdgeInsets.symmetric(horizontal: 4.w),
                      width: 10.w,
                      height: 10.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _tutorialPage == index
                            ? const Color(0xFFE5A00D)
                            : Colors.grey,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 24.h),
                
                // Swipeable content
                Expanded(
                  child: PageView.builder(
                    controller: _tutorialPageController,
                    itemCount: tutorialPages.length,
                    onPageChanged: (index) {
                      setState(() {
                        _tutorialPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final page = tutorialPages[index];
                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32.w),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Icon
                            Container(
                              padding: EdgeInsets.all(24.r),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: page['color'] as Color,
                                boxShadow: [
                                  BoxShadow(
                                    color: (page['color'] as Color).withAlpha((255 * 0.3).round()),
                                    blurRadius: 20.r,
                                    spreadRadius: 5.r,
                                  ),
                                ],
                              ),
                              child: Icon(
                                page['icon'] as IconData,
                                color: Colors.white,
                                size: 64.sp,
                              ),
                            ),
                            SizedBox(height: 40.h),
                            
                            // Title
                            Text(
                              page['title'] as String,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 24.h),
                            
                            // Description
                            Text(
                              page['description'] as String,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16.sp,
                                height: 1.5,
                              ),
                            ),
                            
                            // Swipe hint
                            if (index < tutorialPages.length - 1)
                              Padding(
                                padding: EdgeInsets.only(top: 40.h),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Swipe right for next",
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 14.sp,
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Icon(
                                      Icons.arrow_forward,
                                      color: Colors.white54,
                                      size: 16.sp,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 32.h),
                
                // Got it button
                ElevatedButton(
                  onPressed: () async {
                    await _markTutorialSeen();
                    setState(() {
                      _showTutorial = false;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5A00D),
                    padding: EdgeInsets.symmetric(
                      horizontal: 32.w,
                      vertical: 12.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.r),
                    ),
                  ),
                  child: Text(
                    "Got it!",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                SizedBox(height: 40.h),
              ],
            ),
          )
        : const SizedBox.shrink();
  }

  Future<void> _loadNewMoviesFromSession(SwipeSession updatedSession) async {
    try {
      final currentMovieIds = sessionPool.map((m) => m.id).toSet();
      final newMovieIds = updatedSession.moviePool
          .where((id) => !currentMovieIds.contains(id))
          .toList();
      
      if (newMovieIds.isEmpty) {
        DebugLogger.log("📥 FRIEND: No new movies to load");
        return;
      }
      
      DebugLogger.log("📥 FRIEND: Loading ${newMovieIds.length} new movies from host");
      
      final newMovies = <Movie>[];
      
      // Load new movies from local database only
      for (final movieId in newMovieIds) {
        try {
          final movie = movieDatabase.firstWhere((m) => m.id == movieId);
          newMovies.add(movie);
        } catch (e) {
          DebugLogger.log("⚠️ FRIEND: Skipping new movie ID: $movieId (not in local database)");
          // Just skip missing movies - both users should have same database
        }
      }
      
      setState(() {
        sessionPool.addAll(newMovies);
        currentSessionMovieIds.addAll(newMovies.map((m) => m.id));
      });
      
      DebugLogger.log("✅ FRIEND: Added ${newMovies.length} new movies to pool (total: ${sessionPool.length})");
      
    } catch (e) {
      DebugLogger.log("❌ Error loading new movies from session: $e");
    }
  }

  void _startCollaborativeSession(SwipeSession session) {

    if (SessionManager.hasActiveSession) {
      DebugLogger.log("🔄 Ending solo session before starting collaborative session");
      SessionManager.endSession();
      setState(() {
        _hasStartedSession = false;
      });
    }

    DebugLogger.log("🤝 Starting collaborative session: ${session.sessionId}");
    DebugLogger.log("   Status: ${session.status}");
    DebugLogger.log("   Participants: ${session.participantNames}");
    DebugLogger.log("   Is host: ${session.hostId == widget.currentUser.uid}");
    DebugLogger.log("   Invite Type: ${session.inviteType}");
    DebugLogger.log("   Group Name: ${session.groupName}");
    
    // ✅ FIXED: Properly determine if this is a group session
    final isGroupSession = session.inviteType == InvitationType.group || 
                          session.groupName != null ||
                          session.participantNames.length > 2;
    
    DebugLogger.log("🔍 Group Detection Debug:");
    DebugLogger.log("   session.inviteType: ${session.inviteType}");
    DebugLogger.log("   session.groupName: ${session.groupName}");
    DebugLogger.log("   session.participantNames.length: ${session.participantNames.length}");
    DebugLogger.log("   isGroupSession result: $isGroupSession");
    
    DebugLogger.log("🎯 Detected session type: ${isGroupSession ? 'GROUP' : 'FRIEND'}");
    
    // ✅ NEW: Check if current user is already in the session
    final currentUserId = widget.currentUser.uid;
    final isAlreadyInSession = session.participantIds.contains(currentUserId);
    
    DebugLogger.log("👤 User already in session: $isAlreadyInSession");
    
    setState(() {
      currentSession = session;
      isWaitingForFriend = session.status == SessionStatus.created;
      isInCollaborativeMode = true;
      // ✅ FIXED: Use proper group detection instead of just participant count
      currentMode = isGroupSession ? MatchingMode.group : MatchingMode.friend;
      
      // Reset session state
      _isReadyToSwipe = false;
      selectedMoods.clear();
      sessionPool.clear();
    });

     UnifiedSessionManager.setActiveCollaborativeSession(session);

    DebugLogger.log("🎯 Collaborative session started successfully");
    
    // Show success message to user
    ThemedNotifications.showSuccess(
      context, 
      session.hostId == widget.currentUser.uid 
          ? 'Session created! Waiting for friends...'
          : 'Successfully joined ${session.hostName}\'s session!',
      icon: "🎬"
    );
  }

  // ✅ NEW: Separate method for starting session listener
  void _startSessionListener(String sessionId) {
    // Cancel any existing listener
    sessionSubscription?.cancel();
    
    // Start listening to session updates
    sessionSubscription = SessionService.watchSession(sessionId).listen(
      (updatedSession) {
        DebugLogger.log("📡 Session update received:");
        DebugLogger.log("   Status: ${updatedSession.status}");
        DebugLogger.log("   Participants: ${updatedSession.participantNames}");
        DebugLogger.log("   Movie pool size: ${updatedSession.moviePool.length}");
        DebugLogger.log("   Current local pool size: ${sessionPool.length}");
        
        // NEW: Check if session was cancelled by someone
        if (updatedSession.status == SessionStatus.cancelled) {
          final cancelledBy = updatedSession.cancelledBy ?? "someone";
          
          DebugLogger.log("🚫 Session was cancelled by: $cancelledBy");
          
          // If someone else cancelled it, show notification and reset UI
          if (cancelledBy != widget.currentUser.name) {
            ThemedNotifications.showInfo(context, '$cancelledBy ended the session', icon: "🚪");
          }
          
          // Reset UI for this user too
          _endCollaborativeSessionWithReset();
          return; // Don't process any other updates
        }
        
        // ✅ FIXED: Don't show match celebration for completed sessions
        if (updatedSession.status == SessionStatus.completed) {
          DebugLogger.log("🏁 Session completed - not triggering match celebration");
          return; // Don't process match celebration for completed sessions
        }
        
        // Track previous matches to detect new ones
        final previousMatches = currentSession?.matches ?? [];
        
        // Track previous movie count to detect new movies added
        final previousMovieCount = currentSession?.moviePool.length ?? 0;
        final newMovieCount = updatedSession.moviePool.length;
        
        setState(() {
          currentSession = updatedSession;
          isWaitingForFriend = updatedSession.status == SessionStatus.created;
        });
        
        // If friend and host added new movies, reload them
        final isHost = updatedSession.hostId == widget.currentUser.uid;
        if (!isHost && newMovieCount > previousMovieCount && sessionPool.isNotEmpty) {
          DebugLogger.log("📥 FRIEND: Host added new movies (${previousMovieCount} → ${newMovieCount}), reloading...");
          _loadNewMoviesFromSession(updatedSession);
        }
        
        // When session becomes active, check for existing mood first
        if (updatedSession.status == SessionStatus.active && sessionPool.isEmpty && !_isReadyToSwipe) {
          DebugLogger.log("🎬 Session is now active - generating collaborative movie pool");
          
          // Check if movies were already generated
          final isHost = updatedSession.hostId == widget.currentUser.uid;
          if (isHost && updatedSession.moviePool.isNotEmpty) {
            DebugLogger.log("🔄 HOST: Movies already exist in session, loading them instead of regenerating");
            _generateCollaborativeSession(); // This will now load existing movies
            return;
          }
          
          // Check if we're a friend and host has now set up movies
          if (!isHost && updatedSession.moviePool.isNotEmpty && sessionPool.isEmpty) {
            DebugLogger.log("📥 FRIEND: Host has now provided movie pool, loading movies...");
            _generateCollaborativeSession(); // Retry loading now that movies are available
            return;
          }
          
          // Check if session already has a mood set by host
          if (updatedSession.hasMoodSelected && selectedMoods.isEmpty) {
            DebugLogger.log("🎭 Session has host's mood: ${updatedSession.selectedMoodName}");
            
            // Find the corresponding CurrentMood enum value
            CurrentMood? sessionMood;
            try {
              sessionMood = CurrentMood.values.firstWhere(
                (mood) => mood.toString().split('.').last == updatedSession.selectedMoodId
              );
            } catch (e) {
              DebugLogger.log("⚠️ Could not find matching mood enum for: ${updatedSession.selectedMoodId}");
              sessionMood = CurrentMood.pureComedy; // Fallback
            }
            
            // Auto-apply the host's mood and generate session
            setState(() {
              selectedMoods = [sessionMood!];
            });
            
            DebugLogger.log("✅ Auto-applied host's mood: ${sessionMood.displayName}");
            _generateCollaborativeSession();
            
          } else if (selectedMoods.isEmpty) {
            // No mood in session and no local moods - show mood selection
            DebugLogger.log("🔍 No mood set anywhere, showing mood selection");
            setState(() {
              _showMoodSelectionModal = true;
            });
          } else {
            // Moods already selected locally, generate the session directly
            DebugLogger.log("🔍 Using locally selected moods");
            _generateCollaborativeSession();
          }
        }
        
        // ✅ FIXED: Only show match celebration for active sessions with new matches
        if (updatedSession.status == SessionStatus.active) {
          // Check for new matches and show match screen
          final newMatches = updatedSession.matches.where(
            (movieId) => !previousMatches.contains(movieId)
          ).toList();
          
          if (newMatches.isNotEmpty) {
            DebugLogger.log("🎉 New matches detected in active session: ${newMatches.length}");
            for (final movieId in newMatches) {
              _handleSessionMatch(movieId);
            }
          }
        }
      },
      onError: (error) {
        DebugLogger.log("❌ Session stream error: $error");
        _endCollaborativeSessionWithReset(); // Updated to use the new reset method
      },
    );
  }

  void _handleSessionMatch(String movieId) {    
    if (currentSession == null) {
      return;
    }

    if (UnifiedSessionManager.activeCollaborativeSession != null) {
      if (!UnifiedSessionManager.activeCollaborativeSession!.matches.contains(movieId)) {
        UnifiedSessionManager.activeCollaborativeSession!.matches.add(movieId);
        DebugLogger.log("✅ Updated local session with match: $movieId");
        DebugLogger.log("   Local session now has ${UnifiedSessionManager.activeCollaborativeSession!.matches.length} matches");
      }
    }
      
    // Find the movie object from our session pool
    Movie? matchedMovie;
    try {
      matchedMovie = sessionPool.firstWhere((movie) => movie.id == movieId);
    } catch (e) {
      // If movie not found in current pool, try to find it in the database
      try {
        matchedMovie = movieDatabase.firstWhere((movie) => movie.id == movieId);
      } catch (e2) {
        // Create a placeholder movie as last resort
        matchedMovie = Movie(
          id: movieId,
          title: "Matched Movie",
          posterUrl: "",
          overview: "You both liked this movie!",
          cast: [],
          genres: [],
          tags: [],
          releaseDate: DateTime.now().toIso8601String().split('T')[0],
        );
      }
    }
        
    // Get friend names
    final friendNames = currentSession!.participantNames
        .where((name) => name != widget.currentUser.name)
        .toList();
    
    DebugLogger.log("👥 Friend names for match: $friendNames");
    
    // Show the match screen
    try {
      Navigator.push(
        context,
        PageRouteBuilder(
          opaque: false,
          barrierDismissible: false,
          pageBuilder: (context, animation, secondaryAnimation) {
            DebugLogger.log("🎬 MatchCelebrationScreen widget created successfully");
            return MatchCelebrationScreen(
              movie: matchedMovie!,
              currentUser: widget.currentUser,
              matchedName: friendNames.isNotEmpty ? friendNames.join(", ") : "Your friend",
              allMatchedUsers: currentSession?.participantIds,
              currentSession: currentSession,  // ✅ ADD THIS LINE - THE FIX!
              onContinueSearching: () {
                // User wants to keep swiping in collaborative mode
                DebugLogger.log("🔄 User wants to continue collaborative searching");
              },
            );
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
      DebugLogger.log("✅ Match screen navigation completed");
    } catch (e) {
      DebugLogger.log("❌ ERROR showing match screen: $e");
    }
  }

  Future<void> _endCollaborativeSessionWithReset() async {
    if (currentSession == null) return;
    
    try {
      
      // ✅ FIXED: Properly save completed session to history
      final sessionId = currentSession!.sessionId;
      
      // End the collaborative session in Firestore with proper completion
      await UnifiedSessionManager.endSessionProperly(
        sessionType: currentSession!.participantNames.length > 2 
            ? SessionType.group 
            : SessionType.friend,
        sessionId: sessionId,
        userProfile: widget.currentUser,
      );
      
      DebugLogger.log("✅ Session properly ended and saved to history: $sessionId");
      
    } catch (e) {
      DebugLogger.log("❌ Error ending session properly: $e");
    }
    
    // Clear from unified session manager
    UnifiedSessionManager.clearActiveCollaborativeSession();
    
    // Reset UI state
    setState(() {
      currentSession = null;
      isWaitingForFriend = false;
      isInCollaborativeMode = false;
      currentMode = MatchingMode.solo;
      _isReadyToSwipe = false;
      _isLoadingSession = false;
      _hasStartedSession = false;
      sessionPool.clear();
      currentSessionMovieIds.clear();
      selectedMoods.clear();
      currentSessionContext = null;
      sessionPassedMovieIds.clear();
      _swipeCount = 0;
      selectedFriend = null;
      selectedGroup.clear();
      groupLikes.clear();
    });
    
    DebugLogger.log("✅ Collaborative session ended and UI reset");
}


  Future<void> _generateCollaborativeSession() async {
    DebugLogger.log("🔍 DEBUG: _generateCollaborativeSession called");
    DebugLogger.log("🔍 DEBUG: currentSession null? ${currentSession == null}");
    
    if (currentSession == null) {
      DebugLogger.log("❌ DEBUG: currentSession is null, returning");
      return;
    }

    // Check if we're the host or a friend
    final isHost = currentSession!.hostId == widget.currentUser.uid;
    DebugLogger.log("🔍 DEBUG: isHost: $isHost");

    setState(() {
      _isLoadingSession = true;
    });
    DebugLogger.log("🔍 DEBUG: Set _isLoadingSession = true");

    try {
      // Check if session already has a mood set by the host
      if (currentSession!.hasMoodSelected) {
        DebugLogger.log("🎭 Session already has mood set by host: ${currentSession!.selectedMoodName}");
        
        // Find the corresponding CurrentMood enum value
        CurrentMood? sessionMood;
        try {
          sessionMood = CurrentMood.values.firstWhere(
            (mood) => mood.toString().split('.').last == currentSession!.selectedMoodId
          );
        } catch (e) {
          DebugLogger.log("⚠️ Could not find matching mood enum for: ${currentSession!.selectedMoodId}");
          sessionMood = CurrentMood.pureComedy; // Fallback to a regular mood
        }
        
        // Auto-apply the host's mood to this user
        setState(() {
          selectedMoods = [sessionMood!];
          _showMoodSelectionModal = false;
        });
        
        // Create session context with the host's mood
        currentSessionContext = SessionContext(
          moods: sessionMood,
          groupMemberIds: currentSession!.participantIds,
        );
        
        DebugLogger.log("✅ Applied host's mood: ${sessionMood.displayName}");
        
      } else {
        // No mood set yet - show mood selection
        if (selectedMoods.isEmpty) {
          DebugLogger.log("🔍 DEBUG: No mood set in session and no local moods selected, showing mood selection");
          setState(() {
            _showMoodSelectionModal = true;
            _isLoadingSession = false;
          });
          return;
        }
      }
      
      DebugLogger.log("🔍 DEBUG: Selected moods: ${selectedMoods.map((m) => m.displayName).join(', ')}");

      List<Movie> collaborativePool = [];

      // Host generates, Friend loads EXACTLY the same pool
      if (isHost) {
        DebugLogger.log("👑 HOST: Generating movie pool for session");
        
        // Check if movies already exist in the session
        if (currentSession!.moviePool.isNotEmpty) {
          DebugLogger.log("🔄 HOST: Movies already exist in session, loading existing pool instead of regenerating");
          
          // Load existing movies from the session
          for (final movieId in currentSession!.moviePool) {
            try {
              final movie = movieDatabase.firstWhere((m) => m.id == movieId);
              collaborativePool.add(movie);
            } catch (e) {
              DebugLogger.log("⚠️ HOST: Movie with ID: $movieId not found in local database");
              // For host, if movies are missing from local DB, 
              // they might be from a previous session that used TMDB movies
              // We'll skip this for now to maintain consistency
            }
          }
          
          DebugLogger.log("✅ HOST: Loaded ${collaborativePool.length} existing movies from session");
          
        } else {
          // Generate new movie pool for the session
          final seenMovieIds = <String>{
            ...widget.currentUser.likedMovieIds,
            ...widget.currentUser.passedMovieIds,
            ...currentSessionMovieIds,
          };

          // Check if we have a movie database
          if (movieDatabase.isEmpty) {
            DebugLogger.log("⚠️ Movie database is empty, using popular movies");
            collaborativePool = await TMDBApi.getPopularMovies();
          } else {
            // Generate based on mood
            if (selectedMoods.length == 1) {
              // Regular mood-based session
              final context = SessionContext(
                moods: selectedMoods.first,
                groupMemberIds: currentSession!.participantIds,
              );
              try {
                collaborativePool = await MoodBasedLearningEngine.generateMoodBasedSession(
                  user: widget.currentUser,
                  movieDatabase: movieDatabase,
                  sessionContext: context,
                  seenMovieIds: seenMovieIds,
                  sessionSize: 30,
                  sessionPassedMovieIds: sessionPassedMovieIds,
                );
              } catch (e) {
                DebugLogger.log("❌ Error in generateMoodBasedSession: $e");
                collaborativePool = await TMDBApi.getPopularMovies();
              }
            } else {
              // Multi-mood session
              try {
                collaborativePool = await MoodBasedLearningEngine.generateBlendedMoodSession(
                  user: widget.currentUser,
                  movieDatabase: movieDatabase,
                  selectedMoods: selectedMoods,
                  seenMovieIds: seenMovieIds,
                  sessionPassedMovieIds: sessionPassedMovieIds,
                  sessionSize: 30,
                );
              } catch (e) {
                DebugLogger.log("❌ Error in generateBlendedMoodSession: $e");
                collaborativePool = await TMDBApi.getPopularMovies();
              }
            }
          }

          // Ensure we have movies
          if (collaborativePool.isEmpty) {
            DebugLogger.log("⚠️ Collaborative pool is empty, using popular movies");
            collaborativePool = await TMDBApi.getPopularMovies();
          }

          DebugLogger.log("🎬 HOST: Generated ${collaborativePool.length} movies for collaborative session");

          // HOST: Save movie pool to Firestore for friends to load
          try {
            await SessionService.startSession(
              currentSession!.sessionId,
              selectedMoodIds: selectedMoods.map((m) => m.toString().split('.').last).toList(),
              moviePool: collaborativePool.map((m) => m.id).toList(),
            );
            DebugLogger.log("✅ HOST: Saved movie pool to Firestore");
          } catch (e) {
            DebugLogger.log("⚠️ Could not save movie pool to Firestore: $e");
          }
        }

      } else {
        // FRIEND: Wait for host to generate movies, then load exact same pool
        DebugLogger.log("👥 FRIEND: Loading movie pool from host");
        
        if (currentSession!.moviePool.isNotEmpty) {
          DebugLogger.log("📥 FRIEND: Found ${currentSession!.moviePool.length} movie IDs in session");
          
          // Load movies from local database only (both users have same database)
          for (final movieId in currentSession!.moviePool) {
            try {
              final movie = movieDatabase.firstWhere((m) => m.id == movieId);
              collaborativePool.add(movie);
            } catch (e) {
              DebugLogger.log("⚠️ FRIEND: Skipping movie ID: $movieId (not in local database)");
              // Just skip missing movies - both users should have same database
            }
          }
          
          DebugLogger.log("✅ FRIEND: Loaded ${collaborativePool.length} movies from local database");
          
          // Verify first movie matches what host should have
          if (collaborativePool.isNotEmpty) {
            DebugLogger.log("🔍 FRIEND: First movie will be: ${collaborativePool.first.title}");
          }
          
        } else {
          DebugLogger.log("⏳ FRIEND: Waiting for host to generate movie pool...");
          setState(() {
            _isLoadingSession = false;
          });
          return; // Stay on loading screen until host generates movies
        }
      }

      // Update state and mark ready to swipe
      setState(() {
        sessionPool = List.from(collaborativePool);
        currentSessionMovieIds.clear();
        currentSessionMovieIds.addAll(sessionPool.map((m) => m.id));
        _isReadyToSwipe = true;
      });
      
      DebugLogger.log("🔍 DEBUG: Set _isReadyToSwipe = true, sessionPool.length = ${sessionPool.length}");
      if (sessionPool.isNotEmpty) {
        DebugLogger.log("🎬 First movie: ${sessionPool.first.title}");
      }

    } catch (e) {
      DebugLogger.log("❌ ERROR in _generateCollaborativeSession: $e");
      DebugLogger.log("❌ Stack trace: ${StackTrace.current}");
      
      // For collaborative sessions, try a simple fallback
      if (isHost) {
        // Host can fall back to popular movies
        try {
          final fallbackMovies = await TMDBApi.getPopularMovies();
          setState(() {
            sessionPool = fallbackMovies;
            _isReadyToSwipe = true;
          });
          
          // Save fallback movies to session
          await SessionService.startSession(
            currentSession!.sessionId,
            selectedMoodIds: selectedMoods.map((m) => m.toString().split('.').last).toList(),
            moviePool: fallbackMovies.map((m) => m.id).toList(),
          );
          DebugLogger.log("✅ HOST: Used fallback movies and saved to session");
        } catch (fallbackError) {
          DebugLogger.log("❌ Even fallback failed: $fallbackError");
          _showErrorAndReset("Failed to load movies. Please check your internet connection.");
        }
      } else {
        // Friend should wait for host, don't show error immediately
        DebugLogger.log("⏳ FRIEND: Error loading, will wait for host to retry...");
        setState(() {
          _isLoadingSession = false;
        });
      }
      
    } finally {
      setState(() {
        _isLoadingSession = false;
      });
      DebugLogger.log("🔍 DEBUG: Set _isLoadingSession = false");
    }
  }


  // Method to add more movies when running low
  Future<void> _addMoreMoviesToSession() async {
    if (currentSession == null || !isInCollaborativeMode) return;
    
    final isHost = currentSession!.hostId == widget.currentUser.uid;
    
    // Only host can add more movies
    if (!isHost) {
      DebugLogger.log("👥 FRIEND: Not host, cannot add more movies");
      return;
    }
    
    DebugLogger.log("👑 HOST: Adding more movies to session");
    
    try {
      final seenMovieIds = <String>{
        ...widget.currentUser.likedMovieIds,
        ...widget.currentUser.passedMovieIds,
        ...currentSessionMovieIds,
        ...sessionPassedMovieIds, // Include session-level passed movies
      };

      List<Movie> newMovies = [];

      // Generate more movies using the same mood context
      if (selectedMoods.length == 1) {
          // Regular mood-based session
          newMovies = await MoodBasedLearningEngine.generateMoodBasedSession(
            user: widget.currentUser,
            movieDatabase: movieDatabase,
            sessionContext: currentSessionContext!,
            seenMovieIds: seenMovieIds,
            sessionPassedMovieIds: sessionPassedMovieIds,
            sessionSize: 20,
          );
      } else {
        // Blended mood session - use existing logic
        newMovies = await MoodBasedLearningEngine.generateBlendedMoodSession(
          user: widget.currentUser,
          movieDatabase: movieDatabase,
          selectedMoods: selectedMoods,
          seenMovieIds: seenMovieIds,
          sessionPassedMovieIds: sessionPassedMovieIds,
          sessionSize: 20,
        );
      }

      if (newMovies.isNotEmpty) {
        // Add new movies to Firestore session
        final currentMoviePool = currentSession!.moviePool;
        final newMovieIds = newMovies.map((m) => m.id).toList();
        final updatedMoviePool = [...currentMoviePool, ...newMovieIds];
        DebugLogger.log("🔍 Movie pool updated: ${updatedMoviePool.length} movies");

        await SessionService.addMoviesToSession(
          currentSession!.sessionId,
          newMovieIds,
        );

        // Update local state
        setState(() {
          sessionPool.addAll(newMovies);
          currentSessionMovieIds.addAll(newMovieIds);
        });

        DebugLogger.log("✅ HOST: Added ${newMovies.length} new movies to session");
      }

    } catch (e) {
      DebugLogger.log("❌ Error adding more movies to session: $e");
    }
  }
  
  void _requestMoodChange() {
    setState(() {
      _showMoodSelectionModal = true;
    });
  }

  // Send mood change request to other participants
  Future<void> _sendMoodChangeRequest({required CurrentMood requestedMood}) async {
    if (currentSession == null) return;
    
    try {
      await SessionService.sendMoodChangeRequest(
        sessionId: currentSession!.sessionId,
        fromUserId: widget.currentUser.uid,
        fromUserName: widget.currentUser.name,
        requestedMoodId: requestedMood.toString().split('.').last,
        requestedMoodName: requestedMood.displayName,
      );
      
      // Show confirmation to the requester
      ThemedNotifications.showWaiting(context, 'Mood change request sent to other participants', icon: "🎭");
      
    } catch (e) {
      DebugLogger.log("❌ Error sending mood change request: $e");
      ThemedNotifications.showError(context, 'Failed to send mood change request');
    }
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    
    MainNavigation.clearSessionCallback();
    WidgetsBinding.instance.removeObserver(this);

    if (SessionManager.hasActiveSession) {
      final completedSession = SessionManager.endSession();
      if (completedSession != null) {
        widget.currentUser.addCompletedSession(completedSession);
        
        // ✅ Use unawaited for fire-and-forget operations in dispose
        unawaited(UserProfileStorage.saveProfile(widget.currentUser).catchError((e) {
          DebugLogger.log("⚠️ Error saving profile during dispose: $e");
          return; // This satisfies the return requirement but is ignored
        }));
        
        unawaited(FirebaseFirestore.instance.collection('swipeSessions').add({
          ...completedSession.toJson(),
          'participantIds': [widget.currentUser.uid],
          'createdAt': FieldValue.serverTimestamp(),
        }).catchError((e) {
          DebugLogger.log("⚠️ Error saving session during dispose: $e");
          return FirebaseFirestore.instance.collection('swipeSessions').doc(); // Return dummy doc
        }));
      }
    }
    
    sessionSubscription?.cancel();
    _tutorialPageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Check session state when app/screen becomes active
      _checkSessionStateOnResume();
    }
  }

  void _checkSessionStateOnResume() {
    DebugLogger.log("🔄 Checking session state on screen resume");
    DebugLogger.log("   _hasStartedSession: $_hasStartedSession");
    DebugLogger.log("   SessionManager.hasActiveSession: ${SessionManager.hasActiveSession}");
    
    if (_hasStartedSession && !SessionManager.hasActiveSession && !isInCollaborativeMode) {
      DebugLogger.log("🔄 Session was ended externally - force reset");
      
      setState(() {
        _hasStartedSession = false;
        _isReadyToSwipe = false;
        selectedMoods.clear();
        currentSessionContext = null;
        sessionPool.clear();
        sessionPassedMovieIds.clear();
        currentSessionMovieIds.clear();
        _swipeCount = 0;
        _isLoadingSession = false;
      });
    }
  }
}