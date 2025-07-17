// File: lib/screens/match_celebration_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:math' as math;
import '../models/user_profile.dart';
import '../movie.dart';
import '../utils/themed_notifications.dart';
import '../utils/user_profile_storage.dart';
import '../models/session_models.dart';
import '../utils/debug_loader.dart';
import 'watch_options_screen.dart';
import 'multi_match_carousel_screen.dart';

class MatchCelebrationScreen extends StatefulWidget {
  final Movie movie;
  final UserProfile currentUser;
  final String? matchedName;
  final List<String>? allMatchedUsers;
  final VoidCallback? onContinueSearching;
  final SwipeSession? currentSession;
  
  const MatchCelebrationScreen({
    super.key,
    required this.movie,
    required this.currentUser,
    this.matchedName,
    this.allMatchedUsers,
    this.onContinueSearching,
    this.currentSession,
  });

  @override
  State<MatchCelebrationScreen> createState() => _MatchCelebrationScreenState();
}

class _MatchCelebrationScreenState extends State<MatchCelebrationScreen>
    with TickerProviderStateMixin {
  
  // Genre-based color themes for better readability
  late final MovieTheme _theme;
  
  // Simplified animations
  late final AnimationController _celebrationController;
  late final AnimationController _pulseController;
  late final AnimationController _confettiController;
  
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _slideUpAnimation;
  late final Animation<double> _pulseAnimation;
  
  final List<ConfettiParticle> _particles = [];

  @override
  void initState() {
    super.initState();
    _initializeTheme();
    _initializeAnimations();
    _generateParticles();
    _saveMatchAutomatically();
    
    DebugLogger.log("🎯 ===========================================");
    DebugLogger.log("🎯 MatchCelebrationScreen initState");
    DebugLogger.log("🎯 ===========================================");
    DebugLogger.log("🎯 widget.matchedName: ${widget.matchedName}");
    DebugLogger.log("🎯 widget.allMatchedUsers: ${widget.allMatchedUsers}");
    DebugLogger.log("🎯 widget.currentSession == null: ${widget.currentSession == null}");
    
    if (widget.currentSession != null) {
      DebugLogger.log("🎯 ✅ widget.currentSession EXISTS!");
      DebugLogger.log("🎯 widget.currentSession.sessionId: ${widget.currentSession!.sessionId}");
      DebugLogger.log("🎯 widget.currentSession.matches: ${widget.currentSession!.matches}");
    } else {
      DebugLogger.log("🎯 ❌ widget.currentSession is NULL!");
    }
    DebugLogger.log("🎯 ===========================================");
  }

  void _initializeTheme() {
    _theme = MovieTheme.fromGenres(widget.movie.genres, widget.movie.title);
  }

  void _initializeAnimations() {
    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _celebrationController, curve: Curves.elasticOut),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _celebrationController, curve: const Interval(0.2, 1.0)),
    );
    
    _slideUpAnimation = Tween<double>(begin: 80.0, end: 0.0).animate(
      CurvedAnimation(parent: _celebrationController, curve: const Interval(0.4, 1.0, curve: Curves.easeOut)),
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Start animations
    _celebrationController.forward();
    _pulseController.repeat(reverse: true);
    
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _confettiController.forward();
    });
  }

  void _generateParticles() {
    final random = math.Random();
    for (int i = 0; i < 40; i++) {
      _particles.add(ConfettiParticle(
        color: _theme.confettiColors[random.nextInt(_theme.confettiColors.length)],
        size: random.nextDouble() * 8.r + 3.r,
        position: Offset(
          random.nextDouble() * 300.w - 150.w,
          random.nextDouble() * -80.h - 40.h,
        ),
        velocity: Offset(
          (random.nextDouble() - 0.5) * 100.w,
          random.nextDouble() * 200.h + 80.h,
        ),
        rotationSpeed: (random.nextDouble() - 0.5) * 4.0,
      ));
    }
  }


Future<void> _saveMatchAutomatically() async {
  try {
    // ✅ NEW: In the session-based system, matches are saved automatically 
    // when the session completes. This method now just ensures the movie
    // is in the user's cache for immediate display.
    
    DebugLogger.log("🎬 Match celebration: ${widget.movie.title}");
    DebugLogger.log("👥 Matched with: ${widget.matchedName ?? 'Unknown user'}");
    
    // Add the movie to user's cache for immediate access
    widget.currentUser.loadMoviesIntoCache([widget.movie]);
    
    // The actual match recording happens in the session system:
    // 1. Active collaborative sessions track matches in real-time
    // 2. When session ends, matches are saved to swipeSessions collection
    // 3. Friend profiles query swipeSessions directly for match history
    
    // Optional: Save user profile to update any cached data
    await UserProfileStorage.saveProfile(widget.currentUser);
    
    DebugLogger.log("✅ Match processing completed (session-based)");
    
  } catch (e) {
    DebugLogger.log("❌ Error processing match: $e");
  }
}

  @override
  void dispose() {
    _celebrationController.dispose();
    _pulseController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: _theme.backgroundGradient,
        ),
        child: Stack(
          children: [
            // Confetti animation
            AnimatedBuilder(
              animation: _confettiController,
              builder: (context, child) {
                for (var particle in _particles) {
                  particle.update(_confettiController.value);
                }
                return CustomPaint(
                  size: Size.infinite,
                  painter: ConfettiPainter(particles: _particles),
                );
              },
            ),
            
            // Main content
            SafeArea(
              child: AnimatedBuilder(
                animation: _celebrationController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Column(
                      children: [
                        // Top celebration header
                        Padding(
                          padding: EdgeInsets.only(top: 40.h, bottom: 30.h),
                          child: Transform.scale(
                            scale: _scaleAnimation.value,
                            child: _buildMatchHeader(),
                          ),
                        ),
                        
                        // User connection display
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32.w),
                          child: Transform.translate(
                            offset: Offset(0, _slideUpAnimation.value),
                            child: _buildUserConnection(),
                          ),
                        ),
                        
                        SizedBox(height: 50.h),
                        
                        // Movie poster hero - give it more space
                        Expanded(
                          flex: 4, // Increased from 3 to 4 for more space
                          child: Transform.translate(
                            offset: Offset(0, _slideUpAnimation.value),
                            child: _buildMovieHero(),
                          ),
                        ),
                        
                        // Action buttons with optimized spacing
                        Padding(
                          padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 20.h), // Reduced top and bottom padding
                          child: Transform.translate(
                            offset: Offset(0, _slideUpAnimation.value),
                            child: _buildActionButtons(),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchHeader() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _theme.primaryColor,
                  _theme.primaryColor.withValues(alpha: 0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(50.r),
              boxShadow: [
                BoxShadow(
                  color: _theme.primaryColor.withValues(alpha: 0.4),
                  blurRadius: 20.r,
                  spreadRadius: 4.r,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite, color: Colors.white, size: 24.sp),
                SizedBox(width: 12.w),
                Text(
                  "IT'S A MATCH!",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(width: 12.w),
                Icon(Icons.favorite, color: Colors.white, size: 24.sp),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserConnection() {
    return Row(
      children: [
        Expanded(child: _buildUserAvatar("You", widget.currentUser.name)),
        
        Expanded(
          flex: 2,
          child: Column(
            children: [
              // Connection line with heart
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 4.h,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_theme.primaryColor, _theme.accentColor],
                      ),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.4),
                          blurRadius: 8.r,
                          spreadRadius: 2.r,
                        ),
                      ],
                    ),
                    child: Icon(Icons.favorite, color: Colors.white, size: 16.sp),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                "both loved",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        
        Expanded(child: _buildUserAvatar(
          widget.allMatchedUsers?.length != null && widget.allMatchedUsers!.length > 1 
              ? "Group" 
              : (widget.matchedName ?? "Friend"),
          widget.matchedName ?? "Friend"
        )),
      ],
    );
  }

  Widget _buildUserAvatar(String label, String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : label[0].toUpperCase();
    
    return Column(
      children: [
        Container(
          width: 60.w,
          height: 60.h,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_theme.accentColor, _theme.accentColor.withValues(alpha: 0.8)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _theme.accentColor.withValues(alpha: 0.3),
                blurRadius: 12.r,
                spreadRadius: 2.r,
              ),
            ],
          ),
          child: Center(
            child: Text(
              initial,
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildMovieHero() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        children: [
          // Movie poster with better constraints
          Expanded(
            flex: 3, // Reduced from 4 to 3 to leave more room
            child: Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 160.w, // Reduced max width
                  maxHeight: 240.h, // Reduced max height further
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24.r),
                  boxShadow: [
                    BoxShadow(
                      color: _theme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 30.r,
                      spreadRadius: 8.r,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20.r,
                      spreadRadius: 4.r,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24.r),
                  child: AspectRatio(
                    aspectRatio: 2/3, // Standard movie poster ratio
                    child: Image.network(
                      widget.movie.posterUrl,
                      fit: BoxFit.cover, // Use cover to fill the container properly
                      errorBuilder: (context, error, stackTrace) => Container(
                        decoration: BoxDecoration(
                          gradient: _theme.backgroundGradient,
                        ),
                        child: Icon(Icons.movie, size: 60.sp, color: Colors.white54),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Spacing between poster and text
          SizedBox(height: 12.h), // Reduced from 20.h
          
          // Movie title and basic info
          Expanded(
            flex: 2, // Increased from 1 to 2 for better balance
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  widget.movie.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20.sp, // Reduced from 24.sp
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                SizedBox(height: 8.h), // Reduced from 12.h
                
                // Quick movie info in a more compact row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.movie.rating != null) ...[
                      Icon(Icons.star, color: Colors.amber, size: 16.sp),
                      SizedBox(width: 4.w),
                      Text(
                        widget.movie.rating!.toStringAsFixed(1),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    
                    if (widget.movie.releaseDate != null) ...[
                      if (widget.movie.rating != null) ...[
                        SizedBox(width: 12.w),
                        Container(
                          width: 3.w,
                          height: 3.h,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 12.w),
                      ],
                      Text(
                        _getYearFromDate(widget.movie.releaseDate!),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                
                if (widget.movie.genres.isNotEmpty) ...[
                  SizedBox(height: 6.h), // Reduced from 8.h
                  Text(
                    widget.movie.genres.take(3).join(" • "),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final isCollaborative = widget.matchedName != null || 
                          (widget.allMatchedUsers != null && 
                            widget.allMatchedUsers!.length > 1);
    
    // Determine match count for this session
    int sessionMatchCount = 1; // Current match
    if (isCollaborative && widget.currentSession != null) {
      sessionMatchCount = widget.currentSession!.matches.length;
    }
    
    // Determine if this is the first match in the session
    final isFirstMatch = sessionMatchCount == 1;
    
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              if (isCollaborative) {
                if (isFirstMatch) {
                  // First match - show where to watch
                  _navigateToWatchOptions();
                } else {
                  // Multiple matches - show session overview
                  _handleCollaborativeSessionEnd();
                }
              } else {
                // Solo session - always show where to watch
                _navigateToWatchOptions();
              }
            },
            icon: Icon(
              isCollaborative 
                  ? (isFirstMatch ? Icons.play_arrow : Icons.group)
                  : Icons.play_arrow, 
              size: 24.sp
            ),
            label: Text(
              _getPrimaryButtonText(isCollaborative, isFirstMatch),
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _theme.primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              elevation: 8,
              shadowColor: _theme.primaryColor.withValues(alpha: 0.4),
            ),
          ),
        ),
        
        SizedBox(height: 16.h),
        
        // Secondary action: Continue Searching
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              if (widget.onContinueSearching != null) {
                widget.onContinueSearching!();
              }
              Navigator.pop(context);
            },
            icon: Icon(Icons.add, size: 20.sp),
            label: Text(
              "Continue finding tonight!",
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.4), width: 2.w),
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              backgroundColor: Colors.white.withValues(alpha: 0.1),
            ),
          ),
        ),
      ],
    );
  }

  String _getPrimaryButtonText(bool isCollaborative, bool isFirstMatch) {
    if (!isCollaborative) {
      return "See Where to Watch";
    }
    
    if (isFirstMatch) {
      return "See Where to Watch";
    } else {
      return "See Our Matches";
    }
  }

  void _navigateToWatchOptions() {
    Navigator.pop(context); // Close celebration screen
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WatchOptionsScreen(
          movie: widget.movie,
          currentUser: widget.currentUser,
          matchedName: widget.matchedName,
          allMatchedUsers: widget.allMatchedUsers,
          onContinueSession: widget.onContinueSearching,
        ),
      ),
    );
  }

  void _handleCollaborativeSessionEnd() {

    DebugLogger.log("🎬 ===========================================");
    DebugLogger.log("🎬 BUTTON PRESSED - See Our Matches");
    DebugLogger.log("🎬 ===========================================");
    DebugLogger.log("🎬 widget.currentSession == null: ${widget.currentSession == null}");
    
    if (widget.currentSession != null) {
      DebugLogger.log("🎬 ✅ widget.currentSession EXISTS at button press!");
      DebugLogger.log("🎬 widget.currentSession.sessionId: ${widget.currentSession!.sessionId}");
    } else {
      DebugLogger.log("🎬 ❌ widget.currentSession is NULL at button press!");
      DebugLogger.log("🎬 This means the session was lost between screen creation and button press");
    }
    DebugLogger.log("🎬 ===========================================");

    debugSessionInfo();
    DebugLogger.log("🎬 Collaborative session end triggered");
    DebugLogger.log("Current session: ${widget.currentSession?.sessionId}");
    
    if (widget.currentSession == null) {
      DebugLogger.log("❌ No current session found");
      Navigator.pop(context);
      ThemedNotifications.showError(context, 'No active session found!');
      return;
    }
    
    // Close celebration screen
    Navigator.pop(context);
    
    DebugLogger.log("🎬 Navigating to MultiMatchCarouselScreen...");
    
    // Navigate to the session overview screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultiMatchCarouselScreen(
          session: widget.currentSession!,
          currentUser: widget.currentUser,
        ),
      ),
    ).then((_) {
      DebugLogger.log("🎬 Returned from MultiMatchCarouselScreen");
    }).catchError((error) {
      DebugLogger.log("❌ Navigation error: $error");
    });
  }

  void debugSessionInfo() {
    DebugLogger.log("=== SESSION DEBUG INFO ===");
    DebugLogger.log("matchedName: ${widget.matchedName}");
    DebugLogger.log("allMatchedUsers: ${widget.allMatchedUsers}");
    DebugLogger.log("currentSession: ${widget.currentSession?.sessionId}");
    DebugLogger.log("currentSession matches: ${widget.currentSession?.matches}");
    DebugLogger.log("==========================");
  }


  String _getYearFromDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return date.year.toString();
    } catch (e) {
      return dateString;
    }
  }
}

// Movie theme based on genres
class MovieTheme {
  final Color primaryColor;
  final Color accentColor;
  final Gradient backgroundGradient;
  final List<Color> confettiColors;

  MovieTheme({
    required this.primaryColor,
    required this.accentColor,
    required this.backgroundGradient,
    required this.confettiColors,
  });

  factory MovieTheme.fromGenres(List<String> genres, String title) {
    final titleLower = title.toLowerCase();
    
    // Special movie themes
    if (titleLower.contains('matrix')) {
      return MovieTheme(
        primaryColor: const Color(0xFF00FF41),
        accentColor: const Color(0xFF00DD30),
        backgroundGradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF001100),
            const Color(0xFF000800),
            Colors.black,
          ],
        ),
        confettiColors: [
          const Color(0xFF00FF41),
          const Color(0xFF00DD30),
          const Color(0xFF00BB20),
          Colors.white,
        ],
      );
    }
    
    // Genre-based themes
    if (genres.contains('Horror') || genres.contains('Thriller')) {
      return MovieTheme(
        primaryColor: const Color(0xFFDC3545),
        accentColor: const Color(0xFFFF6B6B),
        backgroundGradient: LinearGradient(
          colors: [
            const Color(0xFF2C0000),
            const Color(0xFF1A0000),
            Colors.black,
          ],
        ),
        confettiColors: [
          const Color(0xFFDC3545),
          const Color(0xFFFF6B6B),
          const Color(0xFFFFD700),
          Colors.white,
        ],
      );
    } else if (genres.contains('Sci-Fi')) {
      return MovieTheme(
        primaryColor: const Color(0xFF007BFF),
        accentColor: const Color(0xFF40E0D0),
        backgroundGradient: LinearGradient(
          colors: [
            const Color(0xFF001122),
            const Color(0xFF000B1A),
            Colors.black,
          ],
        ),
        confettiColors: [
          const Color(0xFF007BFF),
          const Color(0xFF40E0D0),
          const Color(0xFF00FFFF),
          Colors.white,
        ],
      );
    } else if (genres.contains('Romance')) {
      return MovieTheme(
        primaryColor: const Color(0xFFE91E63),
        accentColor: const Color(0xFFFF69B4),
        backgroundGradient: LinearGradient(
          colors: [
            const Color(0xFF330022),
            const Color(0xFF1A0011),
            Colors.black,
          ],
        ),
        confettiColors: [
          const Color(0xFFE91E63),
          const Color(0xFFFF69B4),
          const Color(0xFFFFD700),
          Colors.white,
        ],
      );
    } else if (genres.contains('Comedy')) {
      return MovieTheme(
        primaryColor: const Color(0xFFFFC107),
        accentColor: const Color(0xFFFF9800),
        backgroundGradient: LinearGradient(
          colors: [
            const Color(0xFF332200),
            const Color(0xFF1A1100),
            Colors.black,
          ],
        ),
        confettiColors: [
          const Color(0xFFFFC107),
          const Color(0xFFFF9800),
          const Color(0xFFFFD700),
          Colors.white,
        ],
      );
    } else if (genres.contains('Action')) {
      return MovieTheme(
        primaryColor: const Color(0xFFFF6600),
        accentColor: const Color(0xFFFF8C42),
        backgroundGradient: LinearGradient(
          colors: [
            const Color(0xFF331100),
            const Color(0xFF1A0800),
            Colors.black,
          ],
        ),
        confettiColors: [
          const Color(0xFFFF6600),
          const Color(0xFFFF8C42),
          const Color(0xFFFFD700),
          Colors.white,
        ],
      );
    }
    
    // Default theme
    return MovieTheme(
      primaryColor: const Color(0xFF6C5CE7),
      accentColor: const Color(0xFF74B9FF),
      backgroundGradient: LinearGradient(
        colors: [
          const Color(0xFF2D2B47),
          const Color(0xFF1A1A2E),
          Colors.black,
        ],
      ),
      confettiColors: [
        const Color(0xFF6C5CE7),
        const Color(0xFF74B9FF),
        const Color(0xFFFFD700),
        Colors.white,
      ],
    );
  }
}

// Simplified confetti particle
class ConfettiParticle {
  Color color;
  double size;
  Offset position;
  Offset velocity;
  double rotationSpeed;
  double rotation = 0;
  double life = 1.0;
  
  ConfettiParticle({
    required this.color,
    required this.size,
    required this.position,
    required this.velocity,
    required this.rotationSpeed,
  });
  
  void update(double dt) {
    position = Offset(
      position.dx + velocity.dx * dt,
      position.dy + velocity.dy * dt,
    );
    
    velocity = Offset(
      velocity.dx * 0.98,
      velocity.dy + 300 * dt,
    );
    
    rotation += rotationSpeed * dt;
    life -= dt * 0.3;
    
    if (position.dy > 1000 || life <= 0) {
      final random = math.Random();
      position = Offset(
        random.nextDouble() * 300 - 150,
        random.nextDouble() * -60 - 30,
      );
      velocity = Offset(
        (random.nextDouble() - 0.5) * 100,
        random.nextDouble() * 200 + 80,
      );
      life = 1.0;
    }
  }
}

class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;
  
  ConfettiPainter({required this.particles});
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    for (var particle in particles) {
      final paint = Paint()
        ..color = particle.color.withValues(alpha: particle.life)
        ..style = PaintingStyle.fill;
      
      final position = center + particle.position;
      
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(particle.rotation);
      
      // Draw simple shapes
      if (particle.hashCode % 2 == 0) {
        canvas.drawCircle(Offset.zero, particle.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: particle.size, height: particle.size * 0.6),
          paint,
        );
      }
      
      canvas.restore();
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}