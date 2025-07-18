// lib/screens/matcher_screen_v2.dart
import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../movie.dart';
import '../models/user_profile.dart';
import '../models/session_models.dart';
import '../models/matching_models.dart';
import '../utils/themed_notifications.dart';
import '../utils/user_profile_storage.dart';
import '../utils/debug_loader.dart';
import '../utils/session_manager.dart';
import '../utils/unified_session_manager.dart';
import '../utils/movie_loader.dart';
import '../utils/tmdb_api.dart';
import '../utils/group_matching_handler.dart';
import '../utils/matcher_group_intergration.dart';
import '../utils/mood_engine_bridge.dart';
import '../services/session_service.dart';
import '../widgets/context_aware_cta.dart';
import '../widgets/inline_notification_card.dart';
import '../widgets/mood_selection_widget.dart';
import 'match_celebration_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MatchingContext {
  solo,
  continueSession,
  friendInvite,
  groupInvite,
  joinSession,
}

class MatcherScreenV2 extends StatefulWidget {
  final UserProfile userProfile;
  final MatchingContext context;
  final String? sessionId;
  final UserProfile? targetFriend;
  final List<UserProfile>? targetGroup;
  final String? contextMessage;
  
  const MatcherScreenV2({
    super.key,
    required this.userProfile,
    required this.context,
    this.sessionId,
    this.targetFriend,
    this.targetGroup,
    this.contextMessage,
  });

  @override
  State<MatcherScreenV2> createState() => _MatcherScreenV2State();
}

class _MatcherScreenV2State extends State<MatcherScreenV2> 
    with TickerProviderStateMixin, WidgetsBindingObserver {
  
  // Core matching state
  List<Movie> _sessionPool = [];
  List<Movie> _movieDatabase = [];
  bool _isLoading = true;
  bool _isMatching = false;
  
  // Session management
  SwipeSession? _currentSession;
  StreamSubscription<SwipeSession>? _sessionSubscription;
  bool _isCollaborative = false;
  
  // Mood and context
  List<CurrentMood> _selectedMoods = [];
  SessionContext? _sessionContext;
  
  // UI state
  bool _showMoodSelection = false;
  String _statusMessage = '';
  
  // Business logic preserved
  Timer? _sessionTimer;
  Set<String> _currentSessionMovieIds = {};
  Set<String> _sessionPassedMovieIds = {};
  int _swipeCount = 0;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeScreen();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _sessionSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading your personalized experience...';
    });

    try {
      // Load movie database
      _movieDatabase = await MovieDatabaseLoader.loadMovieDatabase();
      
      // Handle different contexts
      switch (widget.context) {
        case MatchingContext.continueSession:
          await _resumeActiveSession();
          break;
        case MatchingContext.friendInvite:
          await _setupFriendSession();
          break;
        case MatchingContext.groupInvite:
          await _setupGroupSession();
          break;
        case MatchingContext.joinSession:
          await _joinExistingSession();
          break;
        case MatchingContext.solo:
        default:
          await _setupSoloSession();
          break;
      }
      
    } catch (e) {
      DebugLogger.log("❌ Error initializing screen: $e");
      setState(() {
        _statusMessage = 'Something went wrong. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resumeActiveSession() async {
    final activeSession = UnifiedSessionManager.getActiveSessionForDisplay();
    if (activeSession != null) {
      setState(() {
        _statusMessage = 'Resuming your ${activeSession.type.name} session...';
      });
      
      // Load session data and continue
      await _loadSessionData();
    }
  }

  Future<void> _setupFriendSession() async {
    if (widget.targetFriend == null) return;
    
    setState(() {
      _statusMessage = 'Setting up session with ${widget.targetFriend!.name}...';
    });
    
    try {
      // Create collaborative session
      final session = await SessionService.createSession(
        hostId: widget.userProfile.uid,
        hostName: widget.userProfile.name,
        inviteType: InvitationType.friend,
        invitedUserIds: [widget.targetFriend!.uid],
        invitedUserNames: [widget.targetFriend!.name],
      );
      
      if (session != null) {
        _currentSession = session;
        _isCollaborative = true;
        _startSessionListener();
        
        setState(() {
          _statusMessage = 'Waiting for ${widget.targetFriend!.name} to join...';
        });
      }
    } catch (e) {
      DebugLogger.log("❌ Error setting up friend session: $e");
      setState(() {
        _statusMessage = 'Failed to create session. Please try again.';
      });
    }
  }

  Future<void> _setupGroupSession() async {
    if (widget.targetGroup == null || widget.targetGroup!.isEmpty) return;
    
    setState(() {
      _statusMessage = 'Setting up group session...';
    });
    
    try {
      final session = await SessionService.createSession(
        hostId: widget.userProfile.uid,
        hostName: widget.userProfile.name,
        inviteType: InvitationType.group,
        invitedUserIds: widget.targetGroup!.map((u) => u.uid).toList(),
        invitedUserNames: widget.targetGroup!.map((u) => u.name).toList(),
      );
      
      if (session != null) {
        _currentSession = session;
        _isCollaborative = true;
        _startSessionListener();
        
        setState(() {
          _statusMessage = 'Waiting for group members to join...';
        });
      }
    } catch (e) {
      DebugLogger.log("❌ Error setting up group session: $e");
      setState(() {
        _statusMessage = 'Failed to create group session. Please try again.';
      });
    }
  }

  Future<void> _joinExistingSession() async {
    if (widget.sessionId == null) return;
    
    setState(() {
      _statusMessage = 'Joining session...';
    });
    
    try {
      final session = await SessionService.acceptInvitation(
        widget.sessionId!,
        widget.userProfile.name,
      );
      
      if (session != null) {
        _currentSession = session;
        _isCollaborative = true;
        _startSessionListener();
        
        setState(() {
          _statusMessage = 'Joined session successfully!';
        });
      }
    } catch (e) {
      DebugLogger.log("❌ Error joining session: $e");
      setState(() {
        _statusMessage = 'Failed to join session. Please try again.';
      });
    }
  }

  Future<void> _setupSoloSession() async {
    setState(() {
      _statusMessage = 'Ready to discover movies!';
      _isMatching = false;
    });
  }

  void _startSessionListener() {
    if (_currentSession == null) return;
    
    _sessionSubscription?.cancel();
    _sessionSubscription = SessionService.watchSession(_currentSession!.sessionId).listen(
      (updatedSession) {
        setState(() {
          _currentSession = updatedSession;
        });
        
        _handleSessionUpdate(updatedSession);
      },
      onError: (error) {
        DebugLogger.log("❌ Session listener error: $error");
        _handleSessionError();
      },
    );
  }

  void _handleSessionUpdate(SwipeSession session) {
    switch (session.status) {
      case SessionStatus.active:
        if (!_isMatching) {
          _startMatching();
        }
        break;
      case SessionStatus.cancelled:
        _handleSessionCancellation(session);
        break;
      case SessionStatus.completed:
        _handleSessionCompletion(session);
        break;
      default:
        break;
    }
  }

  void _handleSessionCancellation(SwipeSession session) {
    final cancelledBy = session.cancelledBy ?? "someone";
    if (cancelledBy != widget.userProfile.name) {
      setState(() {
        _statusMessage = '$cancelledBy ended the session';
      });
    }
    _resetToStart();
  }

  void _handleSessionCompletion(SwipeSession session) {
    setState(() {
      _statusMessage = 'Session completed!';
    });
    _resetToStart();
  }

  void _handleSessionError() {
    setState(() {
      _statusMessage = 'Connection lost. Please try again.';
    });
    _resetToStart();
  }

  void _resetToStart() {
    setState(() {
      _isMatching = false;
      _isCollaborative = false;
      _currentSession = null;
      _sessionPool.clear();
      _selectedMoods.clear();
      _sessionContext = null;
    });
    
    _sessionSubscription?.cancel();
    UnifiedSessionManager.clearActiveCollaborativeSession();
  }

  Future<void> _startMatching() async {
    setState(() {
      _isMatching = true;
      _statusMessage = 'Starting your matching session...';
    });

    try {
      await _loadSessionData();
      
      setState(() {
        _statusMessage = '';
      });
      
    } catch (e) {
      DebugLogger.log("❌ Error starting matching: $e");
      setState(() {
        _statusMessage = 'Failed to start matching. Please try again.';
        _isMatching = false;
      });
    }
  }

  Future<void> _loadSessionData() async {
    // For collaborative sessions, load from session data
    if (_isCollaborative && _currentSession != null) {
      await _loadCollaborativeSessionData();
    } else {
      // For solo sessions, generate new data
      await _loadSoloSessionData();
    }
  }

  Future<void> _loadCollaborativeSessionData() async {
    if (_currentSession == null) return;
    
    try {
      // Check if session has existing movies
      if (_currentSession!.moviePool.isNotEmpty) {
        final movies = <Movie>[];
        for (final movieId in _currentSession!.moviePool) {
          try {
            final movie = _movieDatabase.firstWhere((m) => m.id == movieId);
            movies.add(movie);
          } catch (e) {
            DebugLogger.log("⚠️ Movie not found in database: $movieId");
          }
        }
        
        setState(() {
          _sessionPool = movies;
        });
      } else {
        // Need to generate movies for session
        await _generateCollaborativeMovies();
      }
      
    } catch (e) {
      DebugLogger.log("❌ Error loading collaborative session data: $e");
      throw e;
    }
  }

  Future<void> _generateCollaborativeMovies() async {
    if (_currentSession == null) return;
    
    final isHost = _currentSession!.hostId == widget.userProfile.uid;
    
    if (isHost) {
      // Host generates movies
      await _generateMoviesAsHost();
    } else {
      // Friend waits for host to generate
      setState(() {
        _statusMessage = 'Waiting for host to prepare movies...';
      });
    }
  }

  Future<void> _generateMoviesAsHost() async {
    try {
      // Use popular movies as default for collaborative sessions
      final movies = await TMDBApi.getPopularMovies();
      
      if (movies.isNotEmpty) {
        setState(() {
          _sessionPool = movies;
        });
        
        // Save to session for other participants
        await SessionService.startSession(
          _currentSession!.sessionId,
          selectedMoodIds: [],
          moviePool: movies.map((m) => m.id).toList(),
        );
      }
    } catch (e) {
      DebugLogger.log("❌ Error generating movies as host: $e");
      throw e;
    }
  }

  Future<void> _loadSoloSessionData() async {
    try {
      // Load popular movies for solo sessions
      final movies = await TMDBApi.getPopularMovies();
      
      if (movies.isNotEmpty) {
        setState(() {
          _sessionPool = movies;
        });
      }
    } catch (e) {
      DebugLogger.log("❌ Error loading solo session data: $e");
      throw e;
    }
  }

  // Preserved business logic for movie interactions
  void _likeMovie(Movie movie) {
    _trackSwipe(movie.id, true);
    
    // Add to user's likes
    widget.userProfile.addLikedMovie(movie);
    UserProfileStorage.saveProfile(widget.userProfile);
    
    // Handle matching logic
    if (_isCollaborative && _currentSession != null) {
      _handleCollaborativeLike(movie);
    } else {
      _handleSoloLike(movie);
    }
    
    // Move to next movie
    _moveToNextMovie();
  }

  void _passMovie(Movie movie) {
    _trackSwipe(movie.id, false);
    
    // Add to user's passed movies
    widget.userProfile.addPassedMovie(movie);
    UserProfileStorage.saveProfile(widget.userProfile);
    
    // Move to next movie
    _moveToNextMovie();
  }

  void _handleCollaborativeLike(Movie movie) {
    // Implement collaborative matching logic
    // This preserves your existing business logic
    if (_currentSession != null) {
      MatcherGroupIntegration.handleGroupLike(
        context: context,
        movie: movie,
        currentUser: widget.userProfile,
        currentSession: _currentSession,
        isInCollaborativeMode: _isCollaborative,
        onShowMatchCelebration: _showMatchCelebration,
      );
    }
  }

  void _handleSoloLike(Movie movie) {
    // Solo matching logic - just record the like
    SessionManager.addLikedMovie(movie.id);
  }

  void _showMatchCelebration(Movie movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MatchCelebrationScreen(
          movie: movie,
          currentUser: widget.userProfile,
          matchedName: _getMatchedName(),
          currentSession: _currentSession,
        ),
      ),
    );
  }

  String? _getMatchedName() {
    if (_currentSession == null) return null;
    
    final otherParticipants = _currentSession!.participantNames
        .where((name) => name != widget.userProfile.name)
        .toList();
    
    return otherParticipants.isNotEmpty ? otherParticipants.first : null;
  }

  void _moveToNextMovie() {
    if (_sessionPool.isNotEmpty) {
      setState(() {
        _sessionPool.removeAt(0);
      });
    }
    
    // Load more movies if running low
    if (_sessionPool.length < 5) {
      _loadMoreMovies();
    }
  }

  Future<void> _loadMoreMovies() async {
    try {
      final moreMovies = await TMDBApi.getPopularMovies();
      setState(() {
        _sessionPool.addAll(moreMovies.take(10));
      });
    } catch (e) {
      DebugLogger.log("❌ Error loading more movies: $e");
    }
  }

  void _trackSwipe(String movieId, bool isLike) {
    _swipeCount++;
    
    // Preserve your existing tracking logic
    MoodBasedLearningEngine.recordSwipe(
      movieId: movieId,
      isLike: isLike,
    );
    
    DebugLogger.log("👆 Swipe $_swipeCount: ${isLike ? 'LIKE' : 'PASS'} - $movieId");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: _buildAppBar(),
      body: _isLoading ? _buildLoadingState() : _buildMainContent(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1F1F1F),
      elevation: 0,
      title: Text(
        _getAppBarTitle(),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20.sp,
          letterSpacing: 0.5,
        ),
      ),
      actions: [
        if (_isCollaborative)
          Padding(
            padding: EdgeInsets.only(right: 16.w),
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.5),
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
    );
  }

  String _getAppBarTitle() {
    if (_isCollaborative && _currentSession != null) {
      final otherParticipants = _currentSession!.participantNames
          .where((name) => name != widget.userProfile.name)
          .toList();
      
      if (otherParticipants.isNotEmpty) {
        return "Matching with ${otherParticipants.join(", ")}";
      }
    }
    
    return "Discover Movies";
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFFE5A00D)),
          ),
          SizedBox(height: 24.h),
          Text(
            _statusMessage,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16.sp,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Container(
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
      child: Column(
        children: [
          // Status message
          if (_statusMessage.isNotEmpty)
            InlineNotificationCard(
              type: InlineNotificationType.info,
              title: 'Session Status',
              message: _statusMessage,
            ),
          
          // Main content area
          Expanded(
            child: _isMatching 
                ? _buildMatchingInterface()
                : _buildStartInterface(),
          ),
        ],
      ),
    );
  }

  Widget _buildStartInterface() {
    return Padding(
      padding: EdgeInsets.all(20.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Context-aware quick start
          ContextAwareCTA(
            title: _getStartTitle(),
            subtitle: _getStartSubtitle(),
            icon: Icons.play_arrow,
            onPressed: _startMatching,
            isPrimary: true,
          ),
          
          SizedBox(height: 16.h),
          
          // Mood selection option
          ContextAwareCTA(
            title: 'Choose Your Mood',
            subtitle: 'Get personalized recommendations',
            icon: Icons.mood,
            onPressed: _showMoodSelection,
          ),
          
          SizedBox(height: 16.h),
          
          // Session info if collaborative
          if (_isCollaborative && _currentSession != null)
            _buildSessionInfo(),
        ],
      ),
    );
  }

  String _getStartTitle() {
    switch (widget.context) {
      case MatchingContext.friendInvite:
        return 'Start Matching with Friend';
      case MatchingContext.groupInvite:
        return 'Start Group Matching';
      case MatchingContext.continueSession:
        return 'Continue Session';
      default:
        return 'Start Discovering';
    }
  }

  String _getStartSubtitle() {
    switch (widget.context) {
      case MatchingContext.friendInvite:
        return 'Find movies you both will love';
      case MatchingContext.groupInvite:
        return 'Find movies for everyone';
      case MatchingContext.continueSession:
        return 'Pick up where you left off';
      default:
        return 'Discover your next favorite movie';
    }
  }

  Widget _buildSessionInfo() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: const Color(0xFFE5A00D).withOpacity(0.3),
          width: 1.w,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session Details',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Participants: ${_currentSession!.participantNames.join(", ")}',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14.sp,
            ),
          ),
          Text(
            'Status: ${_currentSession!.status.name}',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchingInterface() {
    if (_sessionPool.isEmpty) {
      return _buildNoMoviesState();
    }
    
    return Column(
      children: [
        // Movie cards
        Expanded(
          child: Center(
            child: _buildMovieCard(_sessionPool.first),
          ),
        ),
        
        // Action buttons
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildNoMoviesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.movie_outlined,
            size: 64.sp,
            color: Colors.grey[600],
          ),
          SizedBox(height: 16.h),
          Text(
            'No more movies',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Try adjusting your preferences or check back later',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14.sp,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMovieCard(Movie movie) {
    return Container(
      width: 300.w,
      height: 450.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20.r,
            offset: Offset(0, 10.h),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Movie poster
            movie.posterUrl.isNotEmpty
                ? Image.network(
                    movie.posterUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildMoviePlaceholder(),
                  )
                : _buildMoviePlaceholder(),
            
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
            ),
            
            // Movie info
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      movie.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8.h),
                    if (movie.genres.isNotEmpty)
                      Text(
                        movie.genres.take(3).join(" • "),
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14.sp,
                        ),
                      ),
                    if (movie.overview.isNotEmpty) ...[
                      SizedBox(height: 8.h),
                      Text(
                        movie.overview,
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12.sp,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoviePlaceholder() {
    return Container(
      color: const Color(0xFF2A2A2A),
      child: Center(
        child: Icon(
          Icons.movie,
          size: 64.sp,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: EdgeInsets.all(20.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Pass button
          GestureDetector(
            onTap: () => _passMovie(_sessionPool.first),
            child: Container(
              width: 64.w,
              height: 64.w,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(32.r),
                border: Border.all(
                  color: Colors.red,
                  width: 2.w,
                ),
              ),
              child: Icon(
                Icons.close,
                color: Colors.red,
                size: 32.sp,
              ),
            ),
          ),
          
          // Like button
          GestureDetector(
            onTap: () => _likeMovie(_sessionPool.first),
            child: Container(
              width: 64.w,
              height: 64.w,
              decoration: BoxDecoration(
                color: const Color(0xFFE5A00D).withOpacity(0.1),
                borderRadius: BorderRadius.circular(32.r),
                border: Border.all(
                  color: const Color(0xFFE5A00D),
                  width: 2.w,
                ),
              ),
              child: Icon(
                Icons.favorite,
                color: const Color(0xFFE5A00D),
                size: 32.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMoodSelection() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
        child: MoodSelectionWidget(
          onMoodsSelected: (moods) {
            Navigator.pop(context);
            setState(() {
              _selectedMoods = moods;
            });
            _generateMoodBasedMovies();
          },
          isGroupMode: _isCollaborative,
          groupSize: _isCollaborative ? 2 : 1,
          moodContext: _isCollaborative 
              ? MoodSelectionContext.friendInvite 
              : MoodSelectionContext.solo,
        ),
      ),
    );
  }

  Future<void> _generateMoodBasedMovies() async {
    if (_selectedMoods.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _statusMessage = 'Generating personalized recommendations...';
    });
    
    try {
      // Create session context
      _sessionContext = SessionContext(
        moods: _selectedMoods.first,
        groupMemberIds: _isCollaborative 
            ? [widget.userProfile.uid] 
            : [],
      );
      
      // Generate mood-based movies
      final seenMovieIds = <String>{
        ...widget.userProfile.likedMovieIds,
        ...widget.userProfile.passedMovieIds,
      };
      
      final moodMovies = await MoodBasedLearningEngine.generateMoodBasedSession(
        user: widget.userProfile,
        movieDatabase: _movieDatabase,
        sessionContext: _sessionContext!,
        seenMovieIds: seenMovieIds,
        sessionPassedMovieIds: _sessionPassedMovieIds,
        sessionSize: 30,
      );
      
      setState(() {
        _sessionPool = moodMovies;
        _isMatching = true;
        _statusMessage = '';
      });
      
    } catch (e) {
      DebugLogger.log("❌ Error generating mood-based movies: $e");
      setState(() {
        _statusMessage = 'Failed to generate recommendations. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}