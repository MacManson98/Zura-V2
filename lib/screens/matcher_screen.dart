// lib/screens/matcher_screen.dart - FIXED VERSION
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../movie.dart';
import '../models/user_profile.dart';
import '../models/session_models.dart';
import '../utils/user_profile_storage.dart';
import '../utils/debug_loader.dart';
import '../utils/session_manager.dart';
import '../utils/unified_session_manager.dart';
import '../utils/movie_loader.dart';
import '../utils/tmdb_api.dart';
import '../utils/matcher_group_intergration.dart';
import '../utils/mood_engine_bridge.dart';
import '../services/session_service.dart';
import 'match_celebration_screen.dart';
import '../utils/completed_session.dart';

enum MatchingContext {
  solo,
  continueSession,
  friendInvite,
  groupInvite,
  joinSession,
}

class MatcherScreen extends StatefulWidget {
  final UserProfile userProfile;
  final MatchingContext context;
  final String? sessionId;
  final UserProfile? targetFriend;
  final List<UserProfile>? targetGroup;
  final String? contextMessage;
  
  const MatcherScreen({
    super.key,
    required this.userProfile,
    required this.context,
    this.sessionId,
    this.targetFriend,
    this.targetGroup,
    this.contextMessage,
  });

  @override
  State<MatcherScreen> createState() => _MatcherScreenState();
}

class _MatcherScreenState extends State<MatcherScreen> 
    with TickerProviderStateMixin, WidgetsBindingObserver {
  
  // ========================================
  // CORE STATE
  // ========================================
  List<Movie> _sessionPool = [];
  List<Movie> _movieDatabase = [];
  bool _isLoading = true;
  bool _isMatching = false;
  
  SwipeSession? _currentSession;
  StreamSubscription<SwipeSession>? _sessionSubscription;
  bool _isCollaborative = false;
  
  final List<CurrentMood> _selectedMoods = [];
  
  String _statusMessage = '';
  
  Timer? _sessionTimer;
  int _swipeCount = 0;

  // ========================================
  // UI ANIMATION STATE
  // ========================================
  late AnimationController _cardAnimationController;
  late AnimationController _buttonAnimationController;
  late Animation<double> _cardScaleAnimation;
  late Animation<Offset> _cardSlideAnimation;
  
  bool _isDragging = false;
  double _dragPosition = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupAnimations();
    _initializeScreen();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _sessionSubscription?.cancel();
    _cardAnimationController.dispose();
    _buttonAnimationController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setupAnimations() {
    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _buttonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _cardScaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.elasticOut,
    ));
    
    _cardSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeOut,
    ));
  }

  // ========================================
  // INITIALIZATION METHODS
  // ========================================
  
  Future<void> _initializeScreen() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading your personalized experience...';
    });

    try {
      _movieDatabase = await MovieDatabaseLoader.loadMovieDatabase();
      
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
        case MatchingContext.solo:           // ✅ Make sure this line exists
          await _setupSoloSession();         // ✅ This calls _setupSoloSession
          break;
        // No default case needed
      }
      
      setState(() {
        _isLoading = false;
      });
      
      _cardAnimationController.forward();
      
    } catch (e) {
      DebugLogger.log("❌ Error initializing screen: $e");
      setState(() {
        _statusMessage = 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _resumeActiveSession() async {
    final activeSession = UnifiedSessionManager.getActiveSessionForDisplay();
    if (activeSession != null && activeSession.type != SessionType.solo) {
      // ✅ FIXED: Use correct SessionType values (solo, friend, group)
      final collaborativeSession = await SessionService.getSession(activeSession.id);
      if (collaborativeSession != null) {
        _currentSession = collaborativeSession;
        _isCollaborative = true;
        _startSessionListener();
      }
    }
    await _loadSessionData();
  }

  Future<void> _setupFriendSession() async {
    if (widget.targetFriend == null) return;
    
    setState(() {
      _statusMessage = 'Creating session with ${widget.targetFriend!.name}...';
    });
    
    try {
      // ✅ FIXED: Use correct method signature that exists
      final session = await SessionService.createCollaborativeSession(
        hostName: widget.userProfile.name,
        participantIds: [widget.targetFriend!.uid],
        participantNames: [widget.targetFriend!.name],
      );
      
      _currentSession = session;
      _isCollaborative = true;
      _startSessionListener();
      
      await _generateMoviesAsHost();
      
      setState(() {
        _statusMessage = 'Session created! Waiting for ${widget.targetFriend!.name}...';
      });
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
      _statusMessage = 'Creating group session...';
    });
    
    try {
      final session = await SessionService.createCollaborativeSession(
        hostName: widget.userProfile.name,
        participantIds: widget.targetGroup!.map((user) => user.uid).toList(),
        participantNames: widget.targetGroup!.map((user) => user.name).toList(),
      );
      
      _currentSession = session;
      _isCollaborative = true;
      _startSessionListener();
      
      await _generateMoviesAsHost();
      
      setState(() {
        _statusMessage = 'Group session created!';
      });
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
    await _loadSoloSessionData();
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
    });
    
    _sessionSubscription?.cancel();
    UnifiedSessionManager.clearActiveCollaborativeSession();
  }

  Future<void> _startMatching() async {
    setState(() {
      _isMatching = true;
      _statusMessage = '';
    });

    try {
      await _loadSessionData();
      _cardAnimationController.forward();
    } catch (e) {
      DebugLogger.log("❌ Error starting matching: $e");
      setState(() {
        _statusMessage = 'Failed to start matching. Please try again.';
        _isMatching = false;
      });
    }
  }

  Future<void> _loadSessionData() async {
    if (_isCollaborative && _currentSession != null) {
      await _loadCollaborativeSessionData();
    } else {
      await _loadSoloSessionData();
    }
  }

  Future<void> _loadCollaborativeSessionData() async {
    if (_currentSession == null) return;
    
    try {
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
        await _generateCollaborativeMovies();
      }
      
    } catch (e) {
      DebugLogger.log("❌ Error loading collaborative session data: $e");
      rethrow; // ✅ FIXED: Use rethrow instead of throw e
    }
  }

  Future<void> _generateCollaborativeMovies() async {
    if (_currentSession == null) return;
    
    final isHost = _currentSession!.hostId == widget.userProfile.uid;
    
    if (isHost) {
      await _generateMoviesAsHost();
    } else {
      setState(() {
        _statusMessage = 'Waiting for host to prepare movies...';
      });
    }
  }

  Future<void> _generateMoviesAsHost() async {
    try {
      final movies = await TMDBApi.getPopularMovies();
      
      if (movies.isNotEmpty) {
        setState(() {
          _sessionPool = movies;
        });
        
        await SessionService.startSession(
          _currentSession!.sessionId,
          selectedMoodIds: [],
          moviePool: movies.map((m) => m.id).toList(),
        );
      }
    } catch (e) {
      DebugLogger.log("❌ Error generating movies as host: $e");
      rethrow; // ✅ FIXED: Use rethrow instead of throw e
    }
  }

  Future<void> _loadSoloSessionData() async {
    try {
      final movies = await TMDBApi.getPopularMovies();
      
      if (movies.isNotEmpty) {
        setState(() {
          _sessionPool = movies;
        });
      }
    } catch (e) {
      DebugLogger.log("❌ Error loading solo session data: $e");
      rethrow; // ✅ FIXED: Use rethrow instead of throw e
    }
  }

  // ========================================
  // MOVIE INTERACTION METHODS
  // ========================================
  void _likeMovie(Movie movie) {
    _trackSwipe(movie.id, true);
    
    widget.userProfile.addLikedMovie(movie);
    UserProfileStorage.saveProfile(widget.userProfile);
    
    if (_isCollaborative && _currentSession != null) {
      _handleCollaborativeLike(movie);
    } else {
      _handleSoloLike(movie);
    }
    
    _moveToNextMovie();
  }

  void _passMovie(Movie movie) {
    _trackSwipe(movie.id, false);
    
    widget.userProfile.addPassedMovie(movie);
    UserProfileStorage.saveProfile(widget.userProfile);
    
    _moveToNextMovie();
  }

  void _handleCollaborativeLike(Movie movie) {
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
      
      _cardAnimationController.reset();
      _cardAnimationController.forward();
    }
    
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
    
    MoodBasedLearningEngine.recordSwipe(
      movieId: movieId,
      isLike: isLike,
    );
    
    DebugLogger.log("👆 Swipe $_swipeCount: ${isLike ? 'LIKE' : 'PASS'} - $movieId");
  }

  // ========================================
  // UI BUILD METHODS
  // ========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: _isLoading ? _buildLoadingState() : _buildMainContent(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF121212),
            Color(0xFF1F1F1F),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80.w,
              height: 80.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFE5A00D),
                    const Color(0xFFE5A00D).withValues(alpha: 0.6), // ✅ FIXED: withValues
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.movie,
                  size: 40.sp,
                  color: Colors.black,
                ),
              ),
            ),
            SizedBox(height: 32.h),
            Text(
              _statusMessage,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            SizedBox(
              width: 40.w,
              height: 40.w,
              child: const CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color(0xFFE5A00D),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: _sessionPool.isEmpty ? _buildEmptyState() : _buildSwipeInterface(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20.w),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 20.sp,
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getContextTitle(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_statusMessage.isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      Text(
                        _statusMessage,
                        style: TextStyle(
                          color: const Color(0xFFE5A00D),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_isCollaborative) _buildSessionIndicator(),
            ],
          ),
          if (_isCollaborative && _currentSession != null) ...[
            SizedBox(height: 16.h),
            _buildParticipantsBar(),
          ],
        ],
      ),
    );
  }

  String _getContextTitle() {
    switch (widget.context) {
      case MatchingContext.solo:
        return 'Discover Movies';
      case MatchingContext.friendInvite:
        return 'Match with ${widget.targetFriend?.name ?? 'Friend'}';
      case MatchingContext.groupInvite:
        return 'Group Matching';
      case MatchingContext.continueSession:
        return 'Continue Session';
      case MatchingContext.joinSession:
        return 'Join Session';
    }
  }

  Widget _buildSessionIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.withValues(alpha: 0.2), // ✅ FIXED: withValues
            Colors.green.withValues(alpha: 0.1), // ✅ FIXED: withValues
          ],
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.4), // ✅ FIXED: withValues
          width: 1.w,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8.w,
            height: 8.w,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            'LIVE',
            style: TextStyle(
              color: Colors.green,
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsBar() {
    final participants = _currentSession?.participantNames ?? [];
    
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: const Color(0xFFE5A00D).withValues(alpha: 0.2), // ✅ FIXED: withValues
          width: 1.w,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session Participants',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            children: participants.map((name) => Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: name == widget.userProfile.name 
                    ? const Color(0xFFE5A00D).withValues(alpha: 0.2) // ✅ FIXED: withValues
                    : Colors.grey.withValues(alpha: 0.2), // ✅ FIXED: withValues
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(
                name,
                style: TextStyle(
                  color: name == widget.userProfile.name 
                      ? const Color(0xFFE5A00D)
                      : Colors.white70,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeInterface() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: _buildCardStack(),
          ),
        ),
        _buildActionButtons(),
        SizedBox(height: 20.h),
      ],
    );
  }

  Widget _buildCardStack() {
    return SizedBox(
      width: 320.w,
      height: 500.h,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Back card (next movie)
          if (_sessionPool.length > 1)
            Positioned(
              child: Transform.scale(
                scale: 0.95,
                child: Opacity(
                  opacity: 0.5,
                  child: _buildMovieCard(_sessionPool[1], isBackCard: true),
                ),
              ),
            ),
          
          // Front card (current movie)
          AnimatedBuilder(
            animation: _cardAnimationController,
            builder: (context, child) => Transform.translate(
              offset: _cardSlideAnimation.value,
              child: Transform.scale(
                scale: _cardScaleAnimation.value,
                child: GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: Transform.rotate(
                    angle: _dragPosition * 0.1,
                    child: _buildMovieCard(_sessionPool.first),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovieCard(Movie movie, {bool isBackCard = false}) {
    return Container(
      width: 320.w,
      height: 500.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: isBackCard ? [] : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3), // ✅ FIXED: withValues
            blurRadius: 20.r,
            offset: Offset(0, 10.h),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Movie poster
            movie.posterUrl.isNotEmpty
                ? Image.network(
                    movie.posterUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildPlaceholderPoster(),
                  )
                : _buildPlaceholderPoster(),
            
            // Gradient overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 200.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.8), // ✅ FIXED: withValues
                    ],
                  ),
                ),
              ),
            ),
            
            // Movie info
            Positioned(
              bottom: 20.h,
              left: 20.w,
              right: 20.w,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Icon(
                        Icons.star,
                        color: const Color(0xFFE5A00D),
                        size: 16.sp,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '${movie.rating}/10',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Text(
                        movie.releaseYear.toString(), // ✅ FIXED: Convert int to String
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                  ),
                  if (movie.overview.isNotEmpty) ...[
                    SizedBox(height: 12.h),
                    Text(
                      movie.overview,
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 13.sp,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            
            // Swipe indication overlay
            if (_isDragging && !isBackCard)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20.r),
                    color: _dragPosition > 50 
                        ? Colors.green.withValues(alpha: 0.3) // ✅ FIXED: withValues
                        : _dragPosition < -50
                            ? Colors.red.withValues(alpha: 0.3) // ✅ FIXED: withValues
                            : Colors.transparent,
                  ),
                  child: Center(
                    child: _dragPosition > 50
                        ? Icon(
                            Icons.favorite,
                            color: Colors.green,
                            size: 80.sp,
                          )
                        : _dragPosition < -50
                            ? Icon(
                                Icons.close,
                                color: Colors.red,
                                size: 80.sp,
                              )
                            : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderPoster() {
    return Container(
      color: const Color(0xFF2A2A2A),
      child: Center(
        child: Icon(
          Icons.movie,
          size: 80.sp,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 40.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Pass button
          AnimatedBuilder(
            animation: _buttonAnimationController,
            builder: (context, child) => GestureDetector(
              onTapDown: (_) => _buttonAnimationController.forward(),
              onTapUp: (_) => _buttonAnimationController.reverse(),
              onTapCancel: () => _buttonAnimationController.reverse(),
              onTap: () => _passMovie(_sessionPool.first),
              child: Transform.scale(
                scale: 1.0 - (_buttonAnimationController.value * 0.1),
                child: Container(
                  width: 60.w,
                  height: 60.w,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1), // ✅ FIXED: withValues
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.red,
                      width: 2.w,
                    ),
                  ),
                  child: Icon(
                    Icons.close,
                    color: Colors.red,
                    size: 28.sp,
                  ),
                ),
              ),
            ),
          ),
          
          // Like button
          AnimatedBuilder(
            animation: _buttonAnimationController,
            builder: (context, child) => GestureDetector(
              onTapDown: (_) => _buttonAnimationController.forward(),
              onTapUp: (_) => _buttonAnimationController.reverse(),
              onTapCancel: () => _buttonAnimationController.reverse(),
              onTap: () => _likeMovie(_sessionPool.first),
              child: Transform.scale(
                scale: 1.0 - (_buttonAnimationController.value * 0.1),
                child: Container(
                  width: 60.w,
                  height: 60.w,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1), // ✅ FIXED: withValues
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.green,
                      width: 2.w,
                    ),
                  ),
                  child: Icon(
                    Icons.favorite,
                    color: Colors.green,
                    size: 28.sp,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100.w,
            height: 100.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2A2A2A),
              border: Border.all(
                color: Colors.grey[800]!,
                width: 2.w,
              ),
            ),
            child: Icon(
              Icons.movie_creation_outlined,
              size: 48.sp,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'No More Movies',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            'You\'ve seen all available movies.\nTry changing your preferences.',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14.sp,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32.h),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE5A00D),
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25.r),
              ),
            ),
            child: Text(
              'Back to Matching',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // GESTURE HANDLING
  // ========================================

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragPosition += details.delta.dx;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_dragPosition.abs() > 100) {
      // Trigger swipe action
      if (_dragPosition > 0) {
        _likeMovie(_sessionPool.first);
      } else {
        _passMovie(_sessionPool.first);
      }
    }
    
    setState(() {
      _isDragging = false;
      _dragPosition = 0.0;
    });
  }
}